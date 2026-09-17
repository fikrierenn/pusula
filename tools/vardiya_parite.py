# -*- coding: utf-8 -*-
"""VARDİYA PARİTE KAPISI — SP çıktısı ↔ Python çıktısı, kişi-gün bazında.

Plan 47 Faz 1'in BİTİŞ ÖLÇÜTÜ. Aynı hesabın iki uygulaması (Python çekirdeği ve
`bkm.sp_Vrd_KisiGunDoldur`) **sessizce ayrışmasın** diye koşar.

    referans : bkm.Vrd_ParitePython   (Python'un yazdığı kesim, dondurulmuş)
    aday     : bkm.Vrd_KisiGun        (SP'nin yazdığı aynı kesim)

ÇIKIŞ KODU
    0 — parite tuttu (beyan edilen bilinen farklar dışında sıfır)
    1 — KIRIK (beklenmeyen fark var)
    2 — KOŞAMADI (taraflardan biri boş / bağlanılamadı) — **yeşil DEĞİL**

⚠ NÜFUS SIFIRSA "TUTTU" DEĞİL "BAKAMADIM". İki taraf da boşsa fark 0 çıkar ve
  ekranda kusursuz görünür (`.claude/rules/olctum-mu-cikardim-mi.md`).

BİLİNEN VE BEYAN EDİLEN FARK
  `Bolum` / `Gorev`: Python bunları plandan dolduramadığı satırlarda **Zirve**
  personel kaydından tamamlıyor (TC köprüsü). SP Zirve'ye erişmiyor — ayrı
  sunucu, DEV'de ikinci bir linked server yok. Bu fark GİZLENMEZ, sayılır ve
  ayrı raporlanır; hesaba giren hiçbir kolonu etkilemez.

Kullanım:
    python tools/vardiya_parite.py
    python tools/vardiya_parite.py --ornek 20
"""
from __future__ import annotations

import argparse
import collections
import io
import re
import sys

import pyodbc

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

DEV_SUNUCU = r"BT-FIKRI\SQLEXPRESS"
DEV_VERITABANI = "BkmPanel"

# Hesaba giren kolonlar — bunlarda TEK fark bile KIRIK sayılır.
HESAP_KOLON = [
    "VardiyaTanim", "PlanBaslamaDk", "PlanBitisDk", "PlanCalismaDk",
    "KartGirisDk", "KartCikisDk", "GirisDk", "CikisDk", "BrutDk", "MolaDk",
    "CalismaDk", "Durum", "Izin", "GunDonumu", "SayimDisi", "PdksNo",
]
# Beyan edilen fark (yukarıdaki not) — sayılır, kırmızı vermez.
BEYAN_KOLON = ["Bolum", "Gorev"]
# Serbest metin: ifade farkı hesabı etkilemez, ayrıca raporlanır.
METIN_KOLON = ["OlcumNotu", "MazeretTipi", "KayitSayisi"]

ANAHTAR = ["Sube", "SicilNo", "Tarih", "Personel"]


def baglan() -> pyodbc.Connection:
    if not re.fullmatch(r"[A-Za-z0-9._\\\-]+", DEV_SUNUCU):
        sys.exit("Gecersiz sunucu adi")
    return pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={DEV_SUNUCU};Database={DEV_VERITABANI};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;Login Timeout=10",
        timeout=300,
    )


def oku(cur, tablo: str) -> dict:
    kolon = ANAHTAR + HESAP_KOLON + BEYAN_KOLON + METIN_KOLON
    cur.execute(f"SELECT {', '.join(kolon)} FROM bkm.{tablo}")
    d = {}
    for r in cur.fetchall():
        k = tuple(str(x) for x in r[:len(ANAHTAR)])
        d.setdefault(k, []).append(dict(zip(kolon, r)))
    return d


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ornek", type=int, default=8)
    a = ap.parse_args()

    try:
        cn = baglan()
    except pyodbc.Error as e:
        print(f"KOŞAMADI: bağlanılamadı — {str(e).splitlines()[0][:160]}")
        return 2
    try:
        cur = cn.cursor()
        for t in ("Vrd_ParitePython", "Vrd_KisiGun"):
            cur.execute(f"SELECT COUNT(*) FROM sys.tables t JOIN sys.schemas s "
                        f"ON s.schema_id=t.schema_id WHERE s.name='bkm' AND t.name=?", t)
            if cur.fetchone()[0] == 0:
                print(f"KOŞAMADI: bkm.{t} YOK.")
                return 2
        ref, aday = oku(cur, "Vrd_ParitePython"), oku(cur, "Vrd_KisiGun")
        cur.close()
    finally:
        cn.close()

    if not ref or not aday:
        print(f"KOŞAMADI: referans {len(ref)} · aday {len(aday)} kişi-gün — "
              f"boş nüfus 'parite tuttu' demek DEĞİLDİR.")
        return 2

    yalniz_ref = sorted(set(ref) - set(aday))
    yalniz_aday = sorted(set(aday) - set(ref))
    ortak = sorted(set(ref) & set(aday))

    print(f"referans (Python) {sum(len(v) for v in ref.values())} kişi-gün · "
          f"aday (SP) {sum(len(v) for v in aday.values())} kişi-gün")
    print(f"ortak anahtar {len(ortak)} · yalnız referansta {len(yalniz_ref)} · "
          f"yalnız adayda {len(yalniz_aday)}")

    hesap = collections.Counter()
    beyan = collections.Counter()
    metin = collections.Counter()
    ornekler = collections.defaultdict(list)
    for k in ortak:
        # Aynı anahtarda birden çok satır varsa (mükerrer) ilk ikisi kıyaslanır;
        # sayı farkı zaten yukarıda görünür.
        for r1, r2 in zip(ref[k], aday[k]):
            for kol in HESAP_KOLON:
                if r1[kol] != r2[kol]:
                    hesap[kol] += 1
                    if len(ornekler[kol]) < a.ornek:
                        ornekler[kol].append((k, r1[kol], r2[kol]))
            for kol in BEYAN_KOLON:
                if r1[kol] != r2[kol]:
                    beyan[kol] += 1
            for kol in METIN_KOLON:
                if r1[kol] != r2[kol]:
                    metin[kol] += 1
                    if len(ornekler[kol]) < a.ornek:
                        ornekler[kol].append((k, r1[kol], r2[kol]))

    print()
    print(f"HESAP KOLONLARI ({len(HESAP_KOLON)} kolon) — farklı hücre: "
          f"{sum(hesap.values())}")
    for kol, n in hesap.most_common():
        print(f"    {kol:16s} {n:6d}")
        for k, v1, v2 in ornekler[kol][:3]:
            print(f"        {k[3][:22]:24s} {k[2][:10]}  python={v1!r}  sp={v2!r}")

    if beyan:
        print(f"\nBEYAN EDİLEN FARK (Zirve'den tamamlanan Bölüm/Görev — "
              f"hesaba girmez): {sum(beyan.values())} hücre · {dict(beyan)}")
    if metin:
        print(f"\nMETİN/SAYAÇ FARKI (hesaba girmez): {sum(metin.values())} hücre")
        for kol, n in metin.most_common():
            print(f"    {kol:16s} {n:6d}")
            for k, v1, v2 in ornekler[kol][:2]:
                print(f"        {k[3][:22]:24s} {k[2][:10]}")
                print(f"          python={str(v1)[:70]!r}")
                print(f"          sp    ={str(v2)[:70]!r}")

    if yalniz_ref or yalniz_aday:
        print()
        print(f"⚠ ANAHTAR FARKI — referansta {len(yalniz_ref)}, adayda {len(yalniz_aday)}")
        for k in yalniz_ref[:a.ornek]:
            print(f"    yalnız python: {k[0]} · {k[3][:24]} · {k[2][:10]}")
        for k in yalniz_aday[:a.ornek]:
            print(f"    yalnız sp    : {k[0]} · {k[3][:24]} · {k[2][:10]}")

    print()
    if sum(hesap.values()) == 0 and not yalniz_ref and not yalniz_aday:
        print("PARİTE TUTTU — hesap kolonlarında 0 fark, anahtar kümesi aynı.")
        return 0
    print("KIRIK — parite tutmadı. Python emekli EDİLMEZ; fark kapanana kadar "
          "iki uygulama da korunur.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
