# -*- coding: utf-8 -*-
"""
ODAK stok x sube/e-ticaret satis degerlendirme -> Excel (urun bazli, tam dokum).
Kaynak: bkm.UrunBilgi + ent.odak_depo_Stok + stokSonAltDepo_vw + irsHrk + OPENQUERY(ODAKJOKER).
Kolon: marka/yazar, FSM/Ozluce/IstYolu/MerkezDepo/ODAK stok, sube+e-tic satis, maliyet/ust fiyat.
Kullanim: python scripts/export_odak_stok.py "Hazırlık Kitapları"
SQL kaynagi (insan-okunur): sorgular/2026-06-23-odak-stok-sube-satis-degerlendirme.sql (DRILL 3).
"""
import os, sys, re, datetime
import pyodbc
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

CAT = sys.argv[1] if len(sys.argv) > 1 else "Hazırlık Kitapları"

# .env oku (literal sir gomulmez; runtime'da okunur)
ENV = {}
with open(os.path.join(os.path.dirname(__file__), "..", ".env"), encoding="utf-8") as f:
    for ln in f:
        m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
        if m and not ln.lstrip().startswith("#"):
            ENV[m.group(1)] = m.group(2).strip().strip('"')

# pyodbc + ODBC Driver 18 -> varchar (CP1254) dogru Unicode (pymssql yanlis decode: ı->ý).
host = ENV["MSSQL_HOST"]; port = ENV.get("MSSQL_PORT", "1433")
if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
    sys.exit("Gecersiz host/port (.env)")
cn = pyodbc.connect(
    f"Driver={{ODBC Driver 18 for SQL Server}};Server={host},{port};Database=DerinSISBkm;"
    f"UID={ENV['MSSQL_USER']};PWD={ENV['MSSQL_PASSWORD']};TrustServerCertificate=yes;Timeout=20",
    timeout=20)
cn.timeout = 300

iso12 = (datetime.date.today() - datetime.timedelta(days=365)).strftime("%Y%m%d")

SQL = f"""
WITH ecom AS (
  SELECT DERINSIS_ID AS stkID, Qty FROM OPENQUERY(ODAKJOKER, '
    SELECT i.DERINSIS_ID, SUM(d.QUANTITY) AS Qty FROM JOKER.dbo.J_ORDER_DETAILS d
    JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
    WHERE o.ORDERDATE >= ''{iso12}'' AND i.DERINSIS_ID > 0 GROUP BY i.DERINSIS_ID')
),
-- MERKEZ DEPO WMS snapshot'indan (K-37): stokSonAltDepo_vw mekan 12 defteri bozuk
-- (poz 6,23M / neg -4,24M / net 1,99M; WMS 4,25M). Magaza rafi view'da dogru.
depo AS (SELECT b.stkID sID, SUM(CONVERT(int, b.Stok)) Mrkz
  FROM bkm.StokAyBakiyeMekanBazli b WITH(NOLOCK)
  WHERE b.Kaynak='WMS' AND b.ehMekan=12
    AND b.Donem=(SELECT MAX(Donem) FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK) WHERE Kaynak='WMS')
  GROUP BY b.stkID),
mgz AS (SELECT v.ehstkID sID,
    SUM(CASE WHEN v.ehMekan=1 THEN v.stok ELSE 0 END) Fsm, SUM(CASE WHEN v.ehMekan=4477 THEN v.stok ELSE 0 END) Ozl,
    SUM(CASE WHEN v.ehMekan=4478 THEN v.stok ELSE 0 END) Ist
  FROM dbo.stokSonAltDepo_vw v WHERE v.ehAltDepo=0 AND v.ehMekan IN (1,4477,4478) GROUP BY v.ehstkID),
sat AS (SELECT h.ehstkID sID,
    -SUM(CASE WHEN h.ehMekan=1 AND h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) sFsm,
    -SUM(CASE WHEN h.ehMekan=4477 AND h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) sOzl,
    -SUM(CASE WHEN h.ehMekan=4478 AND h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) sIst
  FROM dbo.irsHrk h WHERE h.ehTrhS>=DATEADD(YEAR,-1,GETDATE()) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100) GROUP BY h.ehstkID)
SELECT
  ub.mrkAd AS Yayinevi, LTRIM(RTRIM(ub.Yazar)) AS Yazar, ub.stkKod AS Kod, ub.stkAd AS Urun,
  ISNULL(mgz.Fsm,0) AS [Stok FSM], ISNULL(mgz.Ozl,0) AS [Stok Ozluce], ISNULL(mgz.Ist,0) AS [Stok IstYolu],
  ISNULL(mgz.Mrkz,0) AS [Stok MerkezDepo], ISNULL(o.StokMiktar,0) AS [Stok ODAK],
  ISNULL(mgz.Fsm,0)+ISNULL(mgz.Ozl,0)+ISNULL(mgz.Ist,0)+ISNULL(mgz.Mrkz,0)+ISNULL(o.StokMiktar,0) AS [Stok Toplam],
  ISNULL(sat.sFsm,0) AS [Satis FSM], ISNULL(sat.sOzl,0) AS [Satis Ozluce], ISNULL(sat.sIst,0) AS [Satis IstYolu],
  ISNULL(ecom.Qty,0) AS [Satis Eticaret],
  ISNULL(sat.sFsm,0)+ISNULL(sat.sOzl,0)+ISNULL(sat.sIst,0)+ISNULL(ecom.Qty,0) AS [Satis Toplam],
  CAST(ub.SonAlis AS decimal(18,2)) AS [Maliyet Birim], CAST(ub.SatisFiyat AS decimal(18,2)) AS [Ust Fiyat],
  CASE WHEN (ISNULL(sat.sFsm,0)+ISNULL(sat.sOzl,0)+ISNULL(sat.sIst,0)+ISNULL(ecom.Qty,0))>0
       THEN CAST((ISNULL(o.StokMiktar,0)+ISNULL(mgz.Fsm,0)+ISNULL(mgz.Ozl,0)+ISNULL(mgz.Ist,0)+ISNULL(mgz.Mrkz,0))
                 /((ISNULL(sat.sFsm,0)+ISNULL(sat.sOzl,0)+ISNULL(sat.sIst,0)+ISNULL(ecom.Qty,0))/12.0) AS decimal(10,1)) END AS [Ay Kapsam]
FROM bkm.UrunBilgi ub
LEFT JOIN ent.odak_depo_Stok o ON o.stkID=ub.stkID
LEFT JOIN mgz ON mgz.sID=ub.stkID
LEFT JOIN sat ON sat.sID=ub.stkID
LEFT JOIN ecom ON ecom.stkID=ub.stkID
WHERE ub.Kategori3=? AND ub.urnTip=0
  AND (ISNULL(o.StokMiktar,0)>0 OR ISNULL(mgz.Fsm,0)+ISNULL(mgz.Ozl,0)+ISNULL(mgz.Ist,0)+ISNULL(mgz.Mrkz,0)>0)
ORDER BY [Stok Toplam] DESC
"""

cur = cn.cursor()
cur.execute(SQL, (CAT,))
cols = [d[0] for d in cur.description]
rows = cur.fetchall()
cn.close()

wb = openpyxl.Workbook()
ws = wb.active
ws.title = "ODAK Stok-Satis"
hdr_fill = PatternFill("solid", fgColor="C00000")
hdr_font = Font(bold=True, color="FFFFFF")
ws.append(cols)
for c in range(1, len(cols) + 1):
    cell = ws.cell(1, c); cell.fill = hdr_fill; cell.font = hdr_font
    cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
for r in rows:
    ws.append(list(r))

# kolon genislik + sayi formati
widths = {"Yayinevi": 22, "Yazar": 20, "Kod": 16, "Urun": 46}
for i, name in enumerate(cols, 1):
    L = get_column_letter(i)
    ws.column_dimensions[L].width = widths.get(name, 12)
    if name in ("Maliyet Birim", "Ust Fiyat", "Ay Kapsam"):
        for r in range(2, len(rows) + 2):
            ws.cell(r, i).number_format = "#,##0.0"
    elif name.startswith("Stok") or name.startswith("Satis"):
        for r in range(2, len(rows) + 2):
            ws.cell(r, i).number_format = "#,##0"

ws.freeze_panes = "E2"
ws.auto_filter.ref = f"A1:{get_column_letter(len(cols))}{len(rows)+1}"

out = os.path.join(os.path.dirname(__file__), "..", "raporlar")
os.makedirs(out, exist_ok=True)
slug = re.sub(r"[^a-z0-9]+", "-", CAT.lower().replace("ı","i").replace("ş","s").replace("ğ","g").replace("ü","u").replace("ö","o").replace("ç","c")).strip("-")
fn = os.path.join(out, f"{datetime.date.today():%Y-%m-%d}-odak-stok-{slug}.xlsx")
wb.save(fn)
print(f"OK {len(rows)} satir -> {os.path.abspath(fn)}")
