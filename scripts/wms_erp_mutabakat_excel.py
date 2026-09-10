# -*- coding: utf-8 -*-
"""MERKEZ DEPO WMS ↔ ERP TAM MUTABAKATI → Excel. SALT-OKUMA.

Kullanıcı isteği 09.09.2026: "bu belli paletteki ürünleri yapıyor, tüm ürünleri yapan
bir şey yapmamız lazım" + "aman tablolara dokunma sakın".

⚠⚠ BU SCRIPT HİÇBİR TABLOYA YAZMAZ. Yalnız SELECT + Excel. Sayım emri/irsaliye/düzeltme
ÜRETMEZ. (erp-write-policy: DerinSIS native tablo yazımı MUTLAK YASAK; kullanıcı ayrıca
açıkça "tablolara dokunma" dedi.) Eşitleme kararı ve uygulaması insanda.

── ÖLÇÜLEN TABLO (2026-09-09, ürün düzeyi, tüm evren) ─────────────────────────
  Durum                                   Çeşit      WMS        ERP     |Fark|
  ikisi de boş (kapsam dışı)            390.514        0          0          0
  MUTABIK (>0)                           17.960  2.203.025  2.203.025        0
  ERP defteri NEGATİF (bozuk)             3.011      3.019 -4.244.015  4.247.034
  ERP var / WMS yok (defter kalıntısı)    9.230          0  1.997.663  1.997.663
  ERP fazla (miktar farkı)                4.574  1.378.174  1.639.408    261.234
  WMS fazla (miktar farkı)                  754    402.565    391.747     10.818
  WMS var / ERP tam sıfır (HAYALET)         244        738          0        738

⚠ İYİ HABER: 17.960 çeşit TAM MUTABIK (fark 0). Eşitleme mekanizması çalışıyor —
`paletDegistir ve günlük wms irsaliye onay` job'u WMS sayım/düzeltme irsaliyelerini
(eTip 16/90/99) gece onaylıyor. Son 30 günde merkez depoda eTip 16 "Stok EKLE"
+273.602 · eTip 90 "Ürün SAY" −183.054 · eTip 99 "Sayım" −8.599 adet.

⚠ AMA O JOB BİR ONAY MEKANİZMASI, KARŞILAŞTIRMA DEĞİL: WMS'te işlem yapılmışsa ERP'ye
taşır. ERP'de satış olup WMS'e yansımadığında fark KALICI olur — hayalet sınıfı bu.

⚠ ÖNCEKİ RAKAM DÜZELTMESİ: bu oturumda önce "349 çeşit / 3.757 adet hayalet" ölçülmüştü;
o ölçüt `ERP <= 0` idi ve ERP'si NEGATİF olanları da içine alıyordu. Ayrıştırıldı:
gerçek hayalet (ERP tam 0) 244 çeşit / 738 adet · ERP negatif 3.011 çeşit / −4,24M adet
(ayrı ve çok daha büyük sorun). "≤ 0" ile "= 0" aynı şey değil.

⚠ KAPSAM: WMS tarafı `adrsAlanTipID IN (0,1)` (RAF + GİRİŞ). ÇIKIŞ ALANI (538.614 adet /
12.071 çeşit) merkez stoğuna GİRMEZ — sevke hazırlanmış mal; ayrı kolonda gösterilir.

⚠ pyodbc (pymssql DEĞİL): DerinSIS varchar CP1254, pymssql Türkçe'yi bozuyor.

Kullanım:
    python scripts/wms_erp_mutabakat_excel.py [--min-fark 1] [--cikti yol.xlsx]
"""
from __future__ import annotations

import argparse
import datetime as dt
import io
import os
import re
import sys

import pyodbc
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def env_oku(yol: str) -> dict[str, str]:
    if not os.path.exists(yol):
        sys.exit(f".env bulunamadi: {yol}")
    env: dict[str, str] = {}
    with open(yol, encoding="utf-8") as f:
        for ln in f:
            if ln.lstrip().startswith("#"):
                continue
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
            if m:
                env[m.group(1)] = m.group(2).strip().strip('"')
    return env


def baglan(env: dict[str, str]) -> pyodbc.Connection:
    host, port = env["MSSQL_HOST"], env.get("MSSQL_PORT", "1433")
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
        sys.exit("Gecersiz MSSQL_HOST/MSSQL_PORT (.env)")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 1800
    return cn


# ── ORTAK TABAN: her ürün için WMS toplamı + ERP defter neti (mekan 12) ────────
# ⚠ FULL OUTER JOIN şart: tek taraflılar (yalnız WMS'te / yalnız defterde) kaybolmasın.
TABAN = """
WITH wms AS (
    SELECT stkID,
           SUM(CASE WHEN adrsAlanTipID IN (0,1) THEN Stok ELSE 0 END) AS W,
           SUM(CASE WHEN adrsAlanTipID = 2      THEN Stok ELSE 0 END) AS Cikis
    FROM depo.stok_adres_palet_vw WITH (NOLOCK)
    GROUP BY stkID
),
erp AS (
    SELECT ehstkID AS stkID, SUM(ehAdetN) AS E,
           MAX(CASE WHEN ehTip = 1 THEN ehTrhS END) AS SonSatis
    FROM dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan = 12
    GROUP BY ehstkID
),
b AS (
    SELECT ISNULL(w.stkID, e.stkID) AS stkID,
           CONVERT(int, ISNULL(w.W, 0))     AS W,
           CONVERT(int, ISNULL(w.Cikis, 0)) AS Cikis,
           CONVERT(int, ISNULL(e.E, 0))     AS E,
           e.SonSatis
    FROM wms w FULL OUTER JOIN erp e ON e.stkID = w.stkID
)
"""

SINIF = """
    CASE
        WHEN b.W = 0 AND b.E = 0 THEN '0-ikisi de boş'
        WHEN b.E < 0             THEN '1-ERP defteri NEGATİF (bozuk)'
        WHEN b.W = b.E           THEN '2-MUTABIK'
        WHEN b.W > 0 AND b.E = 0 THEN '3-WMS var / ERP tam sıfır (HAYALET)'
        WHEN b.W = 0 AND b.E > 0 THEN '4-ERP var / WMS yok (defter kalıntısı)'
        WHEN b.W > b.E           THEN '5-WMS fazla (miktar farkı)'
        ELSE                          '6-ERP fazla (miktar farkı)'
    END
"""

SQL_OZET = TABAN + f"""
SELECT {SINIF} AS Durum, COUNT(*) AS Cesit,
       CONVERT(bigint, SUM(b.W)) AS WmsAdet,
       CONVERT(bigint, SUM(b.E)) AS ErpAdet,
       CONVERT(bigint, SUM(ABS(b.W - b.E))) AS MutlakFark,
       CONVERT(decimal(18,2), SUM(ABS(b.W - b.E) * ISNULL(u.fiyatS, 0))) AS FarkEtiketTutar
FROM b
LEFT JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = b.stkID
GROUP BY {SINIF}
ORDER BY 1
"""

SQL_DETAY = TABAN + f"""
SELECT b.stkID,
       LEFT(ISNULL(u.stkAd, '(ad yok)'), 70) AS Urun,
       ISNULL(ub.Kategori3, '-')  AS Kategori3,
       ISNULL(ub.mrkAd, '-')      AS Marka,
       {SINIF} AS Durum,
       b.W AS WmsStok, b.E AS ErpDefter, (b.W - b.E) AS Fark, b.Cikis AS CikisAlani,
       b.SonSatis AS MerkezSonSatis,
       CONVERT(decimal(18,2), ISNULL(u.fiyatS, 0)) AS SatisFiyat,
       CONVERT(decimal(18,2), ABS(b.W - b.E) * ISNULL(u.fiyatS, 0)) AS FarkEtiketTutar,
       (SELECT COUNT(*) FROM depo.paletIcHrk pi WITH (NOLOCK)
        WHERE pi.piStkID = b.stkID AND pi.piIrsID = 0) AS BelgesizHareket
FROM b
LEFT JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = b.stkID
LEFT JOIN bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = b.stkID
WHERE ABS(b.W - b.E) >= ?
  AND NOT (b.W = 0 AND b.E = 0)
ORDER BY ABS(b.W - b.E) * ISNULL(u.fiyatS, 0) DESC
"""


def sayfa(ws, bant, basliklar, satirlar, para=(), tarih=()):
    for i, t in enumerate(bant, start=1):
        ws.cell(row=i, column=1, value=t).font = Font(
            bold=(i == 1), size=12 if i == 1 else 9, italic=(i > 1))
    bas = len(bant) + 2
    sari = PatternFill("solid", fgColor="FFF3CD")
    for j, (ad, gen) in enumerate(basliklar, start=1):
        h = ws.cell(row=bas, column=j, value=ad)
        h.font = Font(bold=True)
        h.fill = sari
        h.alignment = Alignment(horizontal="center", wrap_text=True)
        ws.column_dimensions[get_column_letter(j)].width = gen
    for i, s in enumerate(satirlar, start=bas + 1):
        for j, v in enumerate(s, start=1):
            c = ws.cell(row=i, column=j, value=v)
            if j in tarih:
                c.number_format = "DD.MM.YYYY"
            elif j in para:
                c.number_format = "#,##0.00"
    ws.freeze_panes = ws.cell(row=bas + 1, column=1)
    if satirlar:
        ws.auto_filter.ref = f"A{bas}:{get_column_letter(len(basliklar))}{bas + len(satirlar)}"


def main() -> None:
    ap = argparse.ArgumentParser(description="Merkez depo WMS↔ERP tam mutabakatı (SALT-OKUMA)")
    ap.add_argument("--min-fark", type=int, default=1,
                    help="Detay sayfasına girecek en küçük |fark| (varsayılan 1)")
    ap.add_argument("--cikti", default=None)
    arg = ap.parse_args()

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        with cn.cursor() as cur:
            cur.execute(SQL_OZET)
            ozet = cur.fetchall()
            cur.execute(SQL_DETAY, arg.min_fark)
            detay = cur.fetchall()
    finally:
        cn.close()

    wb = Workbook()
    ws = wb.active
    ws.title = "Ozet"
    sayfa(ws,
          [f"Merkez depo WMS ↔ ERP defteri mutabakatı — ÜRÜN DÜZEYİ, TÜM EVREN · "
           f"{dt.date.today():%d.%m.%Y}",
           "WMS = depo.stok_adres_palet_vw (adrsAlanTipID 0 RAF + 1 GİRİŞ). "
           "ERP = irsHrk mekan 12 net bakiye. FULL OUTER JOIN — tek taraflılar dahil.",
           "⚠ ÇIKIŞ ALANI (tip 2) merkez stoğuna GİRMEZ (sevke hazır mal); ayrı kolonda.",
           "⚠ BU RAPOR HİÇBİR TABLOYA YAZMAZ. Eşitleme kararı ve uygulaması insanda."],
          [("Durum", 40), ("Çeşit", 12), ("WMS adet", 14), ("ERP adet", 14),
           ("|Fark| adet", 14), ("|Fark| etiket ₺", 18)],
          ozet, para=(6,))

    ws2 = wb.create_sheet("Detay")
    sayfa(ws2,
          [f"Uyumsuz ürünler — |fark| ≥ {arg.min_fark} · {len(detay):,} satır",
           "En büyük etiket tutarı üstte. 'Belgesiz hareket' = depo.paletIcHrk'da piIrsID=0 "
           "olan elle taşıma sayısı (hayalet vakalarında 342/349'da vardı).",
           "⚠ SAYIM EMRİ DEĞİL, İZLEME LİSTESİ: 'ERP'ye göre yok' fiilen yok demek değil. "
           "Ters yön daha büyük — 9.230 çeşit defterde var WMS'te yok.",
           "⚠ ERP defteri NEGATİF olan 3.011 çeşit ayrı bir sorun (−4,24M adet): merkez "
           "stoğunun WMS'ten okunma sebebi bu. Sayıma verilmez, defter düzeltmesi ister."],
          [("stkID", 10), ("Ürün", 46), ("Kategori3", 16), ("Marka", 18), ("Durum", 34),
           ("WMS stok", 11), ("ERP defter", 12), ("Fark", 10), ("Çıkış alanı", 12),
           ("Merkez son satış", 16), ("Satış fiyatı", 12), ("|Fark| etiket ₺", 15),
           ("Belgesiz hareket", 15)],
          detay, para=(11, 12), tarih=(10,))

    yol = arg.cikti or os.path.join(
        KOK, f"WMS-ERP Mutabakat {dt.date.today():%Y-%m-%d}.xlsx")
    wb.save(yol)
    for r in ozet:
        print(f"  {r[0]:<40} {r[1]:>8,} çeşit · |fark| {r[4]:>12,} adet")
    print(f"Detay: {len(detay):,} satır · Yazildi: {yol}")


if __name__ == "__main__":
    main()
