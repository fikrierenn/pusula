# -*- coding: utf-8 -*-
"""VARDİYA PARAMETRELERİ — JSON → SQL tabloları (TEK YÖN).

`vardiya/vardiya_parametreleri.json` düzenleme yüzeyidir; `bkm.Vrd_*` parametre
tabloları ondan ÜRETİLİR. Ters yön YOKTUR — tabloda elle yapılan değişiklik bir
sonraki yüklemede kaybolur.

Neden JSON kaynak kalıyor: politika değişikliği (çalışma saati, mola eşiği, rapor
dışı tutulan kadro) git diff'inde GÖRÜNMELİ. Tabloya taşınsaydı kim ne zaman
değiştirdi izlenemezdi. Tablolar yalnız SP'nin okuyabilmesi için var.

⚠ DEV. Hedef yerel `BkmPanel` (`BT-FIKRI\\SQLEXPRESS`). Prod'a (`DerinSISBkm`)
  yazma YOK — `.claude/rules/erp-write-policy.md`.

Kullanım:
    python scripts/vardiya_parametre_yukle.py
    python scripts/vardiya_parametre_yukle.py --kuru    # yalnız ne yazılacağını göster
"""
from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys

import pyodbc

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PARAMETRE_YOLU = os.path.join(KOK, "vardiya", "vardiya_parametreleri.json")

# DEV hedefi. Prod'a terfi edilirse BURASI değişir, nesne adları DEĞİŞMEZ.
DEV_SUNUCU = r"BT-FIKRI\SQLEXPRESS"
DEV_VERITABANI = "BkmPanel"


def dk(metin: str | None) -> int | None:
    """'07:30' → 450. Süreler tabloda DAKİKA tutulur; `time` 24 saati aşamıyor ve
    gece mesaisinde çıkış ertesi güne sarkabiliyor (ölçüldü)."""
    if not metin:
        return None
    p = str(metin).split(":")
    return int(p[0]) * 60 + int(p[1])


def baglan() -> pyodbc.Connection:
    if not re.fullmatch(r"[A-Za-z0-9._\\\-]+", DEV_SUNUCU):
        sys.exit("Gecersiz sunucu adi")
    return pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={DEV_SUNUCU};Database={DEV_VERITABANI};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;Login Timeout=10",
        timeout=120,
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--parametre", default=PARAMETRE_YOLU)
    ap.add_argument("--kuru", action="store_true", help="yazma, yalnız göster")
    a = ap.parse_args()

    if not os.path.exists(a.parametre):
        sys.exit(f"KOŞAMADI: parametre dosyası yok: {a.parametre}")
    with open(a.parametre, encoding="utf-8") as f:
        cfg = json.load(f)

    # Yapı denetimi — eksik blok sessizce boş tablo yazmasın. Boş parametre
    # tablosu SP'de "kural yok" demek değil, "ölçemedim" demektir.
    for alan in ("subeler", "calisma_saatleri", "mola_net_tablosu",
                 "mola_brut_tablosu", "mola_arac_tablosu",
                 "mola_excel_tablosu"):
        if not isinstance(cfg.get(alan), list) or not cfg[alan]:
            sys.exit(f"KOŞAMADI: parametre dosyasında '{alan}' eksik veya boş.")

    sube = [(k["sube"], k["grup"], dk(k.get("calisma_saat"))) for k in cfg["subeler"]]
    calisma = [(k.get("grup") or "", k.get("sube") or "", k.get("bolum"),
                dk(k["saat"]), k.get("not"))
               for k in cfg["calisma_saatleri"]]
    mola = ([("net", dk(k["net_calisma_alt_sinir"]), dk(k["mola"]),
              1 if k.get("brut_ustu") else 0) for k in cfg["mola_net_tablosu"]]
            + [("brut", dk(k["brut_sure"]), dk(k["mola"]), 0)
               for k in cfg["mola_brut_tablosu"]]
            # ⚠ ÜÇÜNCÜ TABLO: aracın kendi molası. `Personel Çalışma` bunu kullanır,
            # Excel'in `Mola Saati` ötekini — fark KASITLI, iki ayrı ölçü. SP bu
            # satırları okur; hardcode edilirse Python ile SP sessizce ayrışır.
            + [("arac", dk(k["brut_alt_sinir"]), dk(k["mola"]), 0)
               for k in cfg["mola_arac_tablosu"]]
            # ⚠ DÖRDÜNCÜ TABLO: Excel'in `Mola Saati` (AA) ölçüsü. Eksik/Fazla Saat
            # BUNU kullanır, aracınkini değil — ikisi kasıtlı farklı.
            + [("excel", dk(k["brut_alt_sinir"]), dk(k["mola"]), 0)
               for k in cfg["mola_excel_tablosu"]])
    # ⚠ `kart_basmayan_gruplar` TABLOYA YAZILMAZ (GMY 17.09.2026). Hiçbir hesapta
    # kullanılmıyor — Excel'de yalnız etiket/süzgeç. Parametre tablosu ancak SP onu
    # OKUYORSA gerekçelidir; okumuyorsa bakım yükünden başka bir şey değildir.

    # Aynı anahtar iki kez gelirse PK patlar — sebebini SQL hatasından değil BURADAN
    # öğrenmek gerekir (`test-discipline` § tanı kendi sınırını söylesin).
    for ad, anahtarlar in (("subeler", [s[0] for s in sube]),
                           ("calisma_saatleri",
                            [(c[0], c[1], c[2] or "") for c in calisma]),
                           ("mola", [(m[0], m[1], m[2]) for m in mola]),):
        if len(anahtarlar) != len(set(anahtarlar)):
            yinelenen = sorted({x for x in anahtarlar
                                if anahtarlar.count(x) > 1})
            sys.exit(f"KOŞAMADI: '{ad}' bloğunda MÜKERRER anahtar: {yinelenen}")

    print(f"Kaynak : {os.path.relpath(a.parametre, KOK)}")
    print(f"Hedef  : {DEV_SUNUCU} · {DEV_VERITABANI} · şema bkm  (DEV)")
    print(f"  Vrd_Sube          {len(sube):4d}")
    print(f"  Vrd_CalismaSaati  {len(calisma):4d}"
          f"  ({sum(1 for c in calisma if c[4]):d} tanesi 'OTOMATİK EKLENDİ' damgalı)")
    print(f"  Vrd_Mola          {len(mola):4d}")
    if a.kuru:
        print("\n--kuru: hiçbir şey yazılmadı.")
        return 0

    cn = baglan()
    try:
        cur = cn.cursor()
        cur.fast_executemany = True
        # Truncate + reload: tek yön garantisi. Tabloda elle yapılmış değişiklik
        # KORUNMAZ — kasıtlı; kaynak JSON'dur.
        cur.execute("DELETE FROM bkm.Vrd_Sube")
        cur.executemany(
            "INSERT INTO bkm.Vrd_Sube (Sube, Grup, CalismaDk) VALUES (?,?,?)", sube)
        cur.execute("DELETE FROM bkm.Vrd_CalismaSaati")
        cur.executemany(
            "INSERT INTO bkm.Vrd_CalismaSaati (Grup, Sube, Bolum, CalismaDk, Not_) "
            "VALUES (?,?,?,?,?)", calisma)
        cur.execute("DELETE FROM bkm.Vrd_Mola")
        cur.executemany(
            "INSERT INTO bkm.Vrd_Mola (Tip, AltSinirDk, MolaDk, Ustu) "
            "VALUES (?,?,?,?)", mola)
        cn.commit()

        # Yazılanı GERİ OKU. "INSERT hata vermedi" ile "satır orada" aynı şey değil.
        for tablo, beklenen in (("Vrd_Sube", len(sube)),
                                ("Vrd_CalismaSaati", len(calisma)),
                                ("Vrd_Mola", len(mola))):
            cur.execute(f"SELECT COUNT(*) FROM bkm.{tablo}")
            n = cur.fetchone()[0]
            if n != beklenen:
                sys.exit(f"KIRIK: bkm.{tablo} → {n} satır, beklenen {beklenen}")
            print(f"  ✓ bkm.{tablo:18s} {n:4d} satır")
        cur.close()
    finally:
        cn.close()
    print("\nYÜKLENDİ (JSON → tablo, tek yön).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
