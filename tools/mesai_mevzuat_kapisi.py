# -*- coding: utf-8 -*-
"""MESAİ MEVZUAT KAPISI — `bkm.Vrd_KisiGun` üzerinde koşan denetim.

`.claude/skills/ik-danisman/SKILL.md` § Mesai Mevzuat Kapısı'nın koşulabilir hâli.
Yazılı kural, çiğneyeni yakalayan bir koşum olmadan kural değildir
(`.claude/rules/test-discipline.md` § yazılı kural ≠ uygulanan kural).

ÇIKIŞ KODU
    0 — kapı geçti (sert sınır aşımı yok)
    1 — KIRIK (en az bir sert sınır aşıldı)
    2 — KOŞAMADI (nüfus boş / bağlanılamadı) — **yeşil DEĞİL**

⚠ NÜFUS SIFIRSA "GEÇTİ" DEĞİL "BAKAMADIM". Kesim boşsa her kapı 0 ihlal döndürür ve
  ekranda kusursuz görünür. Bu yüzden nüfus ayrıca ölçülür ve boşsa çıkış 2'dir
  (`.claude/rules/olctum-mu-cikardim-mi.md`).

⚠ ÜÇ TUZAK (üçü de 17.09.2026'da yaşandı, ölçümle yakalandı):
  1. Gece çalışması "gün dönümü olan satır" DEĞİLDİR — 20:00–06:00 penceresinde geçen
     süredir. Yanlış tanımla 14 gün ihlal çıkmıştı, doğrusu 1 gün (14 kat şişik).
  2. Haftalık 45 saati aşmak İHLAL DEĞİLDİR — fazla çalışmadır, meşrudur. Bu kapı
     onu yalnız BİLGİ olarak sayar, kırmızı vermez.
  3. Çıkış okutmasını unutan kişi 17–20 saat çalışmış görünür. Bu satırlar denetimden
     ÇIKARILIR ve ayrı sayılır; yoksa sahte ihlal üretip gerçeği gürültüye gömer.

Kullanım:
    python tools/mesai_mevzuat_kapisi.py
    python tools/mesai_mevzuat_kapisi.py --kesim-bit 16.09.2026
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import io
import re
import sys

import pyodbc

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

DEV_SUNUCU = r"BT-FIKRI\SQLEXPRESS"
DEV_VERITABANI = "BkmPanel"

# Sert sınırlar — 4857 sayılı İş Kanunu. Değerler burada TEK YERDE; iki kapı aynı
# eşiği ayrı ayrı yazarsa biri güncellenip öteki bayatlar.
GUNLUK_TAVAN_DK = 11 * 60           # m.63 / m.41 — günlük 11 saat
GECE_TAVAN_DK = 7 * 60 + 30         # m.69 — gece çalışması 7,5 saat
GECE_BAS_DK, GECE_BIT_DK = 20 * 60, 30 * 60   # 20:00 → ertesi 06:00
HAFTALIK_NORMAL_DK = 45 * 60        # m.63 — normal çalışma sınırı (BİLGİ, ihlal değil)
GUNLUK_BRUT_TAVAN_DK = 12 * 60      # m.68 — 24 saatte kesintisiz 12 saat dinlenme

# ⭐ 11 SAAT NEYE UYGULANIR — ARAŞTIRILDI 17.09.2026, artık varsayım değil:
#   m.63 tavanı ÇALIŞMA SÜRESİNE uygulanır ve m.68 uyarınca **ara dinlenmeler
#   çalışma süresinden SAYILMAZ** → 11 saat NET'tir (mola hariç).
#   m.68 ayrıca "24 saat içinde kesintisiz 12 saat dinlenme" esasını kurar →
#   işyerinde geçen BRÜT süre 12 saati aşmamalıdır. İki ayrı kapı, ikisi de sert.
#   ⚠ m.68'in mola süreleri ASGARİDİR (≤4 sa → 15 dk · 4-7,5 sa → 30 dk ·
#     >7,5 sa → 60 dk). İşveren DAHA UZUN mola veriyorsa gerçek çalışma daha
#     kısadır — ama o zaman verilen molanın BELGELİ olması gerekir, yoksa
#     düşülen süre denetimde kabul görmez.


def baglan() -> pyodbc.Connection:
    if not re.fullmatch(r"[A-Za-z0-9._\\\-]+", DEV_SUNUCU):
        sys.exit("Gecersiz sunucu adi")
    return pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={DEV_SUNUCU};Database={DEV_VERITABANI};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;Login Timeout=10",
        timeout=180,
    )


def gece_kesisim_dk(giris: int | None, cikis: int | None) -> int:
    """[giriş, çıkış] aralığının 20:00–06:00 penceresiyle kesişimi (dakika).

    Çıkış 1440'ı aşabilir (gün dönümü), bu yüzden pencere iki gün için taranır.
    """
    if giris is None or cikis is None or cikis <= giris:
        return 0
    return sum(max(0, min(cikis, GECE_BIT_DK + k * 1440)
                   - max(giris, GECE_BAS_DK + k * 1440))
               for k in (0, 1))


def sure(dk: int) -> str:
    return f"{dk // 60}:{abs(dk) % 60:02d}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kesim-bit", default=None,
                    help="Denetlenecek kesimin bitiş günü (dd.MM.yyyy). "
                         "Verilmezse en son kesim.")
    ap.add_argument("--liste", type=int, default=10, help="Örnek satır sayısı")
    a = ap.parse_args()

    try:
        cn = baglan()
    except pyodbc.Error as e:
        print(f"KOŞAMADI: bağlanılamadı — {str(e).splitlines()[0][:160]}")
        return 2

    try:
        cur = cn.cursor()
        if a.kesim_bit:
            bit = dt.datetime.strptime(a.kesim_bit, "%d.%m.%Y").date()
        else:
            cur.execute("SELECT MAX(KesimBit) FROM bkm.Vrd_KisiGun")
            bit = cur.fetchone()[0]
        if bit is None:
            print("KOŞAMADI: bkm.Vrd_KisiGun BOŞ — hiçbir kesim yazılmamış. "
                  "Boş nüfus 'ihlal yok' demek DEĞİLDİR.")
            return 2

        cur.execute("""
            SELECT Personel, SicilNo, Sube, Tarih, VardiyaTanim,
                   CalismaDk, GirisDk, CikisDk, Izin, Durum, OlcumNotu
            FROM   bkm.Vrd_KisiGun
            WHERE  KesimBit = ?""", bit)
        satir = cur.fetchall()
        cur.close()
    finally:
        cn.close()

    if not satir:
        print(f"KOŞAMADI: {bit:%d.%m.%Y} kesiminde satır YOK.")
        return 2

    supheli = [r for r in satir
               if r.OlcumNotu and "ŞÜPHELİ" in r.OlcumNotu]
    olculebilir = [r for r in satir
                   if not (r.OlcumNotu and "ŞÜPHELİ" in r.OlcumNotu)]

    print(f"KESİM {bit:%d.%m.%Y} · {len(satir)} kişi-gün "
          f"({len(supheli)} satır ŞÜPHELİ okutma nedeniyle denetim DIŞI)")
    print()

    # ── KAPI 1 — günlük 11 saat (m.63/m.41) ──────────────────────────────
    g1 = [r for r in olculebilir if (r.CalismaDk or 0) > GUNLUK_TAVAN_DK]
    # ── KAPI 2 — gece 7,5 saat (m.69) ────────────────────────────────────
    g2 = [(r, gece_kesisim_dk(r.GirisDk, r.CikisDk)) for r in olculebilir]
    g2 = [(r, n) for r, n in g2 if n > GECE_TAVAN_DK]
    # ── KAPI 2b — günlük brüt 12 saat (m.68, 24 saatte 12 saat dinlenme) ──
    g2b = [r for r in olculebilir
           if r.GirisDk is not None and r.CikisDk is not None
           and (r.CikisDk - r.GirisDk) > GUNLUK_BRUT_TAVAN_DK]
    # ── KAPI 3 — hafta tatili: 7 günlük dilimde hiç dinlenme yok ─────────
    #    Yaklaşım: ISO haftasında 7 gün kaydı olan ve hiçbirinde izin/çalışmama
    #    bulunmayan kişi. "Kesintisiz 24 saat" tam ölçümü vardiya saatlerini de
    #    gerektirir; bu kapı ALT SINIR verir ve öyle beyan edilir.
    hafta = collections.defaultdict(list)
    for r in olculebilir:
        hafta[(r.SicilNo, r.Tarih.isocalendar()[1])].append(r)
    g3 = [(k, v) for k, v in hafta.items()
          if len({x.Tarih for x in v}) >= 7
          and not any(x.Izin or (x.CalismaDk or 0) == 0 for x in v)]
    # ── BİLGİ — haftalık 45 saat üstü (İHLAL DEĞİL) ──────────────────────
    h45 = [(k, sum(x.CalismaDk or 0 for x in v)) for k, v in hafta.items()]
    h45 = [(k, t) for k, t in h45 if t > HAFTALIK_NORMAL_DK]

    kirik = 0
    print(f"KAPI 1 · günlük 11 saat (m.63/m.41)      : {len(g1)} gün")
    for r in sorted(g1, key=lambda x: -(x.CalismaDk or 0))[:a.liste]:
        print(f"    {str(r.Personel)[:26]:28s} {r.Tarih:%d.%m.%Y}  "
              f"{sure(r.CalismaDk)}  ({r.Sube})")
    kirik += 1 if g1 else 0

    print(f"KAPI 2 · gece 20:00-06:00 / 7,5 saat (m.69): {len(g2)} gün")
    for r, n in sorted(g2, key=lambda x: -x[1])[:a.liste]:
        print(f"    {str(r.Personel)[:26]:28s} {r.Tarih:%d.%m.%Y}  "
              f"gece {sure(n)}  (vardiya {r.VardiyaTanim})")
    kirik += 1 if g2 else 0

    print(f"KAPI 2b· günlük brüt 12 saat (m.68)      : {len(g2b)} gün "
          f"(24 saatte kesintisiz 12 saat dinlenme)")
    for r in sorted(g2b, key=lambda x: -(x.CikisDk - x.GirisDk))[:a.liste]:
        print(f"    {str(r.Personel)[:26]:28s} {r.Tarih:%d.%m.%Y}  "
              f"brüt {sure(r.CikisDk - r.GirisDk)}  ({r.Sube})")
    kirik += 1 if g2b else 0

    print(f"KAPI 3 · hafta tatili kullanılmamış       : {len(g3)} kişi-hafta "
          f"(ALT SINIR — kesintisiz 24 saat tam ölçümü değil)")
    for (sicil, hf), v in sorted(g3, key=lambda x: -sum(
            y.CalismaDk or 0 for y in x[1]))[:a.liste]:
        print(f"    {str(v[0].Personel)[:26]:28s} hafta {hf}  "
              f"{len({x.Tarih for x in v})} gün  "
              f"{sure(sum(x.CalismaDk or 0 for x in v))}")
    kirik += 1 if g3 else 0

    print()
    print(f"BİLGİ  · haftalık 45 saat üstü            : {len(h45)} kişi-hafta "
          f"— İHLAL DEĞİL, fazla çalışmadır (sınır yıllık 270 saat + muvafakat)")
    print(f"BİLGİ  · yıllık 270 saat                  : bu pencereden ÖLÇÜLEMEZ "
          f"(yıllıklandırma ÇIKARIM olur)")

    if supheli:
        print()
        print(f"⚠ DENETİM DIŞI {len(supheli)} satır — çıkış okutması eksik olabilir, "
              f"denetime girseydi SAHTE ihlal üretirdi:")
        for r in supheli[:a.liste]:
            print(f"    {str(r.Personel)[:26]:28s} {r.Tarih:%d.%m.%Y}  "
                  f"{sure(r.CalismaDk or 0)}")

    print()
    if kirik:
        print(f"KIRIK — {kirik} sert kapıda aşım var. Yorum `ik-danisman`, "
              f"mevzuat metni `turkiye-is-mevzuati`. Kimse 'ihlal' diye "
              f"ETİKETLENMEZ; bunlar teyit edilecek SORULARDIR.")
        return 1
    print("GEÇTİ — sert sınır aşımı yok.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
