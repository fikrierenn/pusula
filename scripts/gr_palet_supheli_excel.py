# -*- coding: utf-8 -*-
"""GR (GİRİŞ ALANI) PALETLERİNDE BEKLEYEN ŞÜPHELİ ÜRÜNLER → Excel.

Kullanıcı isteği 09.09.2026: "tüm gr paletlerinde bekleyen bu tarz şüpheli ürünlerin
listesini excel olarak çeker misin".

ŞÜPHE ÖLÇÜTÜ (ölçüldü, tek vaka değil): WMS hücresel stokta GİRİŞ ALANI'nda mal var
ama ERP merkez defteri (mekan 12) net bakiyesi <= 0. Yani ERP'ye göre o mal yok.

MEKANİZMA (stkID 248104 uçtan uca izlendi):
  23.02.2026  İst.Yolu -> merkez transfer  +1  (irsaliye 7121400, WMS'e de işlendi)
  22.05.2026  MERKEZ SATIŞ                -1  (belge 7135278) -- WMS'te KARŞILIĞI YOK
  10.07.2026  elle palet taşıması: raf 44711 -> GR01 37250, piIrsID=0 (BELGESİZ)
  Sonuç: ERP defteri 0, WMS 1 adet -> ekranda/raporda hayalet stok.

ÖLÇEK (2026-09-09, kesim 08.09.2026):
  · GİRİŞ ALANI toplam: 4.753 satır / 4.352 çeşit / 182.313 adet
  · Bunlardan ŞÜPHELİ (defter <= 0): 234 satır
  · Tüm alanlar dahil hayalet: 349 çeşit / 3.757 adet; 261'inde merkez satışı var,
    342'sinde belgesiz palet hareketi var
  · Kitap tarafında yığılı: Akademi 84 çeşidin 76'sı (%90), Kitap 127'nin 77'si (%61);
    Kırtasiye %0,9, Oyuncak %0,8 -- merkez depo kitap tutmuyor

⚠ BU LİSTE SAYIM EMRİDİR, MUHASEBE KAYDI DEĞİL. "ERP'ye göre yok" demek "fiilen yok"
demek değildir; ters yön de var (defterde 9.146 çeşit / 1.996.995 adet pozitif ama
WMS'te yok). Karar fiziksel sayımla verilir.

⚠ pyodbc kullanılıyor (pymssql DEĞİL): DerinSIS varchar kolonları CP1254; pymssql
Türkçe'yi bozuyor (coding-discipline § rapor scripti).

Kullanım:
    python scripts/gr_palet_supheli_excel.py [--tum-alanlar] [--cikti yol.xlsx]

    --tum-alanlar : yalnız GİRİŞ ALANI değil, tüm alan tiplerini tara (RAF + ÇIKIŞ dahil)
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

# ⚠ Windows konsolu cp1254; '₺' basmak UnicodeEncodeError veriyor (sema_degismez.py'de de
# olmuştu). Çıktı UTF-8'e sarılır — yoksa dosya yazıldığı hâlde script hata vermiş görünür.
if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def env_oku(yol: str) -> dict[str, str]:
    """`.env` dosyasını okur. Kimlik YALNIZ burada durur (dört sözleşme: tek kimlik yolu)."""
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
    # ODBC connection-string'e env degeri gomulurken whitelist guard (injection)
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
        sys.exit("Gecersiz MSSQL_HOST/MSSQL_PORT (.env)")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 900
    return cn


# ⚠ Alan tipi süzgeci parametre DEĞİL, iki sabit metin: SQL'e kullanıcı girdisi gömülmez.
SQL = """
WITH defter AS (
    SELECT h.ehstkID AS stkID, SUM(h.ehAdetN) AS Net
    FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan = 12
    GROUP BY h.ehstkID
),
son_satis AS (   -- merkezden en son ne zaman/hangi belgeyle satılmış (hayaletin sebebi)
    SELECT h.ehstkID AS stkID, MAX(h.ehTrhS) AS SonSatis,
           MAX(CONVERT(varchar(30), h.ehID)) AS SonSatisBelge
    FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan = 12 AND h.ehTip = 1
    GROUP BY h.ehstkID
)
SELECT
    d.stkID,
    LEFT(ISNULL(u.stkAd, '(ad yok)'), 80)          AS UrunAd,
    ISNULL(ub.Kategori3, '(kategori yok)')          AS Kategori,
    ISNULL(a.alanTipAd, CONVERT(varchar(20), d.adrsAlanTipID)) AS AlanTipi,
    d.adrsAd                                        AS Adres,
    d.PaletID,
    CONVERT(int, d.Stok)                            AS WmsAdet,
    CONVERT(int, ISNULL(df.Net, 0))                 AS DefterNet,
    (SELECT MAX(pi.pikTarih) FROM depo.paletIcHrk pi WITH (NOLOCK)
     WHERE pi.piStkID = d.stkID AND pi.piİlkID = d.PaletID AND pi.pGC = 0) AS PaleteKonuldu,
    (SELECT COUNT(*) FROM depo.paletIcHrk pi2 WITH (NOLOCK)
     WHERE pi2.piStkID = d.stkID AND pi2.piIrsID = 0)                       AS BelgesizHareket,
    ss.SonSatis                                     AS MerkezSonSatis,
    ss.SonSatisBelge                                AS MerkezSonSatisBelge,
    CONVERT(decimal(18,2), ISNULL(u.fiyatS, 0))     AS SatisFiyat,
    CONVERT(decimal(18,2), CONVERT(int, d.Stok) * ISNULL(u.fiyatS, 0)) AS EtiketTutar
FROM depo.stok_adres_palet_vw d WITH (NOLOCK)
LEFT JOIN dbo.urn u  WITH (NOLOCK) ON u.stkID = d.stkID
-- Kategori KANONIK kaynak: bkm.UrunBilgi.Kategori3 (sql-server-conventions § kanal ayraci)
LEFT JOIN bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = d.stkID
LEFT JOIN depo.adresAlanTip a ON a.alanTipID = d.adrsAlanTipID
LEFT JOIN defter df ON df.stkID = d.stkID
LEFT JOIN son_satis ss ON ss.stkID = d.stkID
WHERE d.Stok <> 0
  AND ISNULL(df.Net, 0) <= 0          -- ERP defterine gore bu mal YOK
  {ALAN}
ORDER BY d.adrsAlanTipID, ISNULL(ub.Kategori3, ''), d.stkID
"""

BASLIKLAR = [
    ("stkID", 10), ("Ürün", 46), ("Kategori", 18), ("Alan tipi", 14),
    ("Adres", 12), ("Palet", 10), ("WMS adet", 10), ("ERP defter", 11),
    ("Palete konuldu", 15), ("Belgesiz hareket", 16),
    ("Merkez son satış", 16), ("Satış belgesi", 14),
    ("Satış fiyatı", 12), ("Etiket tutarı", 14),
]


def main() -> None:
    ap = argparse.ArgumentParser(description="GR paletlerinde bekleyen şüpheli ürünler → Excel")
    ap.add_argument("--tum-alanlar", action="store_true",
                    help="Yalnız GİRİŞ ALANI değil, tüm alan tiplerini tara")
    ap.add_argument("--cikti", default=None, help="Çıktı yolu (.xlsx)")
    arg = ap.parse_args()

    alan_sart = "" if arg.tum_alanlar else "AND d.adrsAlanTipID = 1"
    sql = SQL.replace("{ALAN}", alan_sart)

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        with cn.cursor() as cur:
            cur.execute(sql)
            satirlar = cur.fetchall()
    finally:
        cn.close()

    if not satirlar:
        print("Şüpheli satır YOK — hiçbir üründe 'WMS var / ERP defteri ≤ 0' durumu bulunamadı.")
        return

    kapsam = "tüm alanlar" if arg.tum_alanlar else "GİRİŞ ALANI (GR)"
    wb = Workbook()
    ws = wb.active
    ws.title = "Şüpheli Stok"

    # Başlık bandı — ölçüt ve sınır ÇIKTIDA yazılı olmalı (rapor tek başına dolaşıma girer)
    ws["A1"] = (f"WMS'te var, ERP merkez defterinde YOK — {kapsam} · "
                f"kesim {dt.date.today().strftime('%d.%m.%Y')}")
    ws["A1"].font = Font(bold=True, size=12)
    ws["A2"] = ("Ölçüt: WMS hücresel stok > 0 ANCAK ERP merkez defteri (mekan 12) net ≤ 0. "
                "Sebep genellikle satışın ERP'de kesilip WMS'ten düşülmemesi.")
    ws["A3"] = ("BU LİSTE SAYIM EMRİDİR, muhasebe kaydı değildir — 'ERP'ye göre yok' fiilen yok "
                "demek değil. Ters yön de var: defterde pozitif ama WMS'te olmayan 9.146 çeşit.")
    for r in (2, 3):
        ws[f"A{r}"].font = Font(size=9, italic=True)

    bas_satir = 5
    sari = PatternFill("solid", fgColor="FFF3CD")
    for j, (ad, gen) in enumerate(BASLIKLAR, start=1):
        h = ws.cell(row=bas_satir, column=j, value=ad)
        h.font = Font(bold=True)
        h.fill = sari
        h.alignment = Alignment(horizontal="center", wrap_text=True)
        ws.column_dimensions[get_column_letter(j)].width = gen

    toplam_adet = 0
    toplam_tutar = 0.0
    for i, s in enumerate(satirlar, start=bas_satir + 1):
        for j, v in enumerate(s, start=1):
            hucre = ws.cell(row=i, column=j, value=v)
            if isinstance(v, dt.datetime):
                hucre.number_format = "DD.MM.YYYY"
            elif j in (7, 8, 10):
                hucre.number_format = "#,##0"
            elif j in (13, 14):
                hucre.number_format = "#,##0.00"
        toplam_adet += int(s[6] or 0)
        toplam_tutar += float(s[13] or 0)

    son = bas_satir + len(satirlar) + 1
    ws.cell(row=son, column=2, value=f"TOPLAM — {len(satirlar):,} satır").font = Font(bold=True)
    ws.cell(row=son, column=7, value=toplam_adet).font = Font(bold=True)
    ws.cell(row=son, column=7).number_format = "#,##0"
    ws.cell(row=son, column=14, value=toplam_tutar).font = Font(bold=True)
    ws.cell(row=son, column=14).number_format = "#,##0.00"

    ws.freeze_panes = ws.cell(row=bas_satir + 1, column=1)
    ws.auto_filter.ref = f"A{bas_satir}:N{bas_satir + len(satirlar)}"

    ek = "tum-alanlar" if arg.tum_alanlar else "gr"
    yol = arg.cikti or os.path.join(
        KOK, f"GR Palet Supheli Stok {ek} {dt.date.today():%Y-%m-%d}.xlsx")
    wb.save(yol)
    print(f"{len(satirlar):,} satır · {toplam_adet:,} adet · {toplam_tutar:,.2f} ₺ etiket")
    print(f"Yazildi: {yol}")


if __name__ == "__main__":
    main()
