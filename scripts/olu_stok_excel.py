"""
ÖLÜ STOK ÜRÜN DÖKÜMÜ — KANONİK maliyet sistemi (gece job 'MaliyetRaporu-Ceren' ile aynı).
Maliyet = COALESCE(son 5 alış faturası SUM(ehTutarN)/SUM(ehAdetN), BKM_STOKLAR_MALIYETLI.ORT_ALIS, 0)
Stok = CANLI: 3 mağaza (irsHrk ehAltDepo=0) + Merkez/WMS depo (depo.paletUrnTnm). Odak HARİÇ.
Değer = stok × Ort.Maliyet (ENVANTER_RAPORU 'Ort.Maliyet' ile mutabık → 358M/122M tabanı).
Ölü = son 90g hiç satış yok (irsHrk ehTip 4/100). Çıktı: briefings/olu-stok.xlsx
Kullanım: python olu_stok_excel.py [--sadece-olu]
"""
import sys, os, json
from pathlib import Path
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pymssql
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.table import Table, TableStyleInfo

R = Path(__file__).resolve().parent.parent
KIRMIZI = "E30622"
MEKANLAR = "1,4477,4478"  # FSM=1, Özlüce=4477, İstanbul Yolu=4478 — LokasyonConfig.Subeler ile senkron
SADECE_OLU = "--sadece-olu" in sys.argv
# --kategori "Kitap" → bkm.UrunBilgi.Kategori3 filtresi (yoksa tüm kategoriler).
KATEGORI = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--kategori=")), None)
if KATEGORI is None and "--kategori" in sys.argv:
    i = sys.argv.index("--kategori")
    if i + 1 < len(sys.argv):
        KATEGORI = sys.argv[i + 1]
_slug = "".join(c for c in (KATEGORI or "tumu").lower() if c.isalnum())
OUT = R / "briefings" / f"olu-stok-{_slug}.xlsx"

HEADERS = [
    "stkID", "Kod", "Ürün", "Kategori", "Marka/Yayınevi",
    "Mağaza Stok", "Merkez Depo", "Toplam Adet",
    "Ort.Maliyet ₺", "Kilitli Değer ₺",
    "S90 Satış", "Son Satış", "Listede (gün)",
]
INT_COLS = {0, 5, 6, 7, 10, 12}
FLOAT_COLS = {8, 9}

# Gece job ile birebir maliyet şelalesi + canlı stok, ürün-grain. Tek batch (GO yok → pymssql).
SQL = r"""
SET NOCOUNT ON;
DECLARE @tarih DATETIME = GETDATE();

CREATE TABLE #WMS (stkID INT, stok DECIMAL(18,4));
INSERT INTO #WMS
SELECT pUStkID, SUM(pUAdetN)
FROM depo.paletUrnTnm WITH(NOLOCK)
  JOIN depo.paletTnm WITH(NOLOCK) ON paletTnm.pID=paletUrnTnm.pUID
  JOIN depo.adres   WITH(NOLOCK) ON pSonPozID=adrsID
WHERE pUAdetN>0 AND adrsAd NOT IN ('CK01') AND pUID NOT IN ('42560','20353')
GROUP BY pUStkID;

;WITH URUNLER AS (
  SELECT u.stkID
  FROM urnKategori_vw u
  /*KATFILTRE*/
  WHERE u.urnKtgr2ID NOT IN (11,25,23,9,5,6) AND u.urnTip=0 AND u.stkKod NOT LIKE '%.%'
    AND u.stkID NOT IN (81809,77328,200772,84642,59337,65462,64515,56761,22390,60318,128118,1644512)
),
VERI AS (
  SELECT stk.ehstkID AS stkID, SUM(CONVERT(FLOAT,stk.ehAdetN)) AS mag, CONVERT(FLOAT,0) AS wms
  FROM dbo.irsHrk stk WITH(NOLOCK)
  JOIN URUNLER u ON u.stkID=stk.ehstkID
  WHERE stk.ehTrhS<=@tarih AND stk.ehAltDepo=0 AND stk.ehMekan IN ({MEKANLAR})
  GROUP BY stk.ehstkID
  UNION ALL
  SELECT s.stkID, 0, SUM(s.stok) FROM #WMS s JOIN URUNLER u ON u.stkID=s.stkID GROUP BY s.stkID
)
-- Önce stoğu olanları süz (net>0), maliyet şelalesi sadece kalanlara çalışsın.
SELECT stkID, SUM(mag) AS MagStok, SUM(wms) AS WmsStok
INTO #ST FROM VERI GROUP BY stkID HAVING SUM(mag)+SUM(wms) > 0;
CREATE UNIQUE CLUSTERED INDEX IX_ST ON #ST(stkID);

SELECT s.stkID, CAST(COALESCE(MLYT.MALIYET, m.ORT_ALIS, 0) AS decimal(18,4)) AS brmMaliyet
INTO #M FROM #ST s
OUTER APPLY (
   SELECT CONVERT(money, SUM(b.ehTutarN)/SUM(b.ehAdetN)) AS MALIYET
   FROM (SELECT TOP 5 ehAdetN, ehTutarN
         FROM dbo.fatAyr fa WITH(NOLOCK) JOIN dbo.fat f WITH(NOLOCK)
           ON fa.ehID=f.eID AND f.eTarih<=@tarih AND f.eTip=0 AND f.eDurum<>2
         WHERE fa.ehstkID=s.stkID AND fa.ehAdetN<>0 ORDER BY f.eTarih DESC) b
   HAVING SUM(b.ehAdetN)<>0
) MLYT
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI m WITH(NOLOCK) ON m.STKID=s.stkID;
CREATE UNIQUE CLUSTERED INDEX IX_M ON #M(stkID);

SELECT s.stkID AS stkID, u.stkKod AS Kod, CAST(u.stkAd AS nvarchar(120)) AS Urun,
       CAST(ISNULL(k.ktgrAd,'—') AS nvarchar(40)) AS Kategori,
       CAST(ISNULL(mrk.mrkAd,'') AS nvarchar(60)) AS Marka,
       CAST(s.MagStok AS int) AS MagStok, CAST(s.WmsStok AS int) AS WmsStok,
       CAST(s.MagStok+s.WmsStok AS int) AS Toplam,
       CAST(m.brmMaliyet AS decimal(18,2)) AS OrtMaliyet,
       CAST((s.MagStok+s.WmsStok)*m.brmMaliyet AS decimal(18,0)) AS Kilitli,
       ISNULL(sat.S90,0) AS S90, sat.SonSatis,
       DATEDIFF(DAY,u.gTarih,GETDATE()) AS YasGun
FROM #ST s
JOIN dbo.urn u WITH(NOLOCK) ON u.stkID=s.stkID
LEFT JOIN dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID=u.urnKtgr2ID
LEFT JOIN dbo.urnMrk mrk WITH(NOLOCK) ON mrk.mrkID=u.urnMrkID
JOIN #M m ON m.stkID=s.stkID
OUTER APPLY (SELECT CAST(-SUM(CASE WHEN h2.ehTip IN (4,100) THEN h2.ehAdetN ELSE 0 END) AS int) AS S90,
                    MAX(CASE WHEN h2.ehTip IN (4,100) THEN h2.ehTrhS END) AS SonSatis
             FROM dbo.irsHrk h2 WITH(NOLOCK)
             WHERE h2.ehstkID=s.stkID AND h2.ehMekan IN ({MEKANLAR}) AND h2.ehAltDepo=0
               AND h2.ehTrhS>=DATEADD(DAY,-90,GETDATE())) sat
WHERE (s.MagStok+s.WmsStok)*m.brmMaliyet > 0 /*EXTRA*/;

DROP TABLE #WMS; DROP TABLE #ST; DROP TABLE #M;
"""


def cfg():
    e = R / ".env"
    if e.exists():
        for l in e.read_text(encoding="utf-8").splitlines():
            if "=" in l and not l.strip().startswith("#"):
                k, v = l.split("=", 1); os.environ.setdefault(k.strip(), v.strip())
    return dict(server=os.environ["MSSQL_HOST"], user=os.environ.get("MSSQL_USER", "sa"),
                password=os.environ.get("MSSQL_PASSWORD", ""))


def get_data():
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"],
                           database="DerinSISBkm", charset="UTF-8", login_timeout=20, timeout=600)
    cur = conn.cursor(as_dict=True)
    # SADECE_OLU: dead = son 90g satış yok. WHERE'e NOT EXISTS ekle.
    extra = ("" if not SADECE_OLU else
             f" AND NOT EXISTS (SELECT 1 FROM dbo.irsHrk h3 WITH(NOLOCK) WHERE h3.ehstkID=s.stkID "
             f"AND h3.ehTip IN (4,100) AND h3.ehMekan IN ({MEKANLAR}) AND h3.ehAltDepo=0 "
             f"AND h3.ehTrhS>=DATEADD(DAY,-90,GETDATE()))")
    katf = ("JOIN bkm.UrunBilgi ub WITH(NOLOCK) ON ub.stkID=u.stkID AND ub.Kategori3=N'%s'"
            % KATEGORI.replace("'", "''")) if KATEGORI else ""
    cur.execute(SQL.replace("{MEKANLAR}", MEKANLAR).replace("/*KATFILTRE*/", katf).replace("/*EXTRA*/", extra))
    rows = cur.fetchall()
    cur.close(); conn.close()
    rows.sort(key=lambda r: float(r["Kilitli"] or 0), reverse=True)
    return rows


def build(rows):
    wb = Workbook(); ws = wb.active; ws.title = "Ölü Stok"
    red = PatternFill("solid", fgColor=KIRMIZI); white = Font(color="FFFFFF", bold=True, size=11)
    thin = Border(*[Side(style="thin", color="E2E8F0")] * 4)
    center = Alignment(horizontal="center", vertical="center", wrap_text=True)

    for ci, h in enumerate(HEADERS, 1):
        c = ws.cell(1, ci, h); c.fill = red; c.font = white; c.alignment = center; c.border = thin
    ws.freeze_panes = "A2"

    for ri, r in enumerate(rows, 2):
        vals = [r["stkID"], r["Kod"], r["Urun"], r["Kategori"], r["Marka"],
                r["MagStok"], r["WmsStok"], r["Toplam"],
                float(r["OrtMaliyet"] or 0), float(r["Kilitli"] or 0),
                r["S90"], r["SonSatis"].strftime("%d.%m.%Y") if r.get("SonSatis") else "—",
                r["YasGun"]]
        for ci, v in enumerate(vals):
            c = ws.cell(ri, ci + 1, v); c.border = thin
            if ci in FLOAT_COLS: c.number_format = "#,##0.00"
            elif ci in INT_COLS: c.number_format = "#,##0"
            if ci == 10 and (r["S90"] or 0) == 0:
                c.font = Font(color=KIRMIZI, bold=True)

    last = len(rows) + 1
    ref = "A1:%s%d" % (get_column_letter(len(HEADERS)), last)
    tbl = Table(displayName="OluStok", ref=ref)
    tbl.tableStyleInfo = TableStyleInfo(name="TableStyleLight1", showRowStripes=True)
    ws.add_table(tbl)

    widths = [9, 16, 44, 22, 26, 11, 11, 11, 12, 15, 10, 12, 12]
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w

    toplam = sum(float(r["Kilitli"] or 0) for r in rows)
    olu = sum(float(r["Kilitli"] or 0) for r in rows if (r["S90"] or 0) == 0)
    oluC = sum(1 for r in rows if (r["S90"] or 0) == 0)
    print(f"Kategori3 filtresi: {KATEGORI or 'TÜMÜ'}")
    print("Maliyet: gece job 'MaliyetRaporu-Ceren' şelalesi (son5 fatura→ORT_ALIS). Stok: canlı 3 mağaza + WMS depo.")
    print(f"{len(rows):,} SKU · kilitli {toplam:,.0f} TL")
    print(f"  S90=0 (gerçek ölü): {oluC:,} SKU · {olu:,.0f} TL")
    OUT.parent.mkdir(exist_ok=True)
    wb.save(OUT)
    print(f"Yazıldı: {OUT}")


if __name__ == "__main__":
    build(get_data())
