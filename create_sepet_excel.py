#!/usr/bin/env python3
"""
Sepet Buyuklugu Etkisi - SQL Server Baglantili Excel Rapor Uretici
================================================================
Kullanim:  python create_sepet_excel.py
Gerekli:   pip install pyodbc openpyxl

SQL Server'a baglanir, veriyi taze ceker, formullu+grafikli Excel olusturur.
"""

import sys, os, datetime

# ── Auto-install ──────────────────────────────────────────────
def ensure(pkg, imp=None):
    try:
        __import__(imp or pkg)
    except ImportError:
        import subprocess
        subprocess.run([sys.executable, "-m", "pip", "install", "-q", pkg], check=True)

ensure("pyodbc")
ensure("openpyxl")

import pyodbc
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side, numbers
from openpyxl.utils import get_column_letter
from openpyxl.chart import LineChart, BarChart, Reference
from openpyxl.chart.series import DataPoint
from openpyxl.chart.label import DataLabelList

# ══════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════
SQL_SERVER   = "192.168.40.201"
SQL_DATABASE = "EncoreMerkez"
SQL_USER     = ""        # bos birakirsan Windows Auth
SQL_PASS     = ""
OUTPUT_DIR   = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE  = os.path.join(OUTPUT_DIR, "sepet-buyuklugu-etkisi.xlsx")

QUERY = """\
;WITH cte_3al2ode AS (
    SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns WHERE CampaignId IN (1, 12)
),
cte_any_campaign AS (
    SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns
)
SELECT
    CONVERT(varchar(7), s.Date, 126) AS Ay,
    CASE
        WHEN c3.SalesId IS NOT NULL THEN '3Al2Ode'
        WHEN ca.SalesId IS NOT NULL THEN 'DigerKampanya'
        ELSE 'Kampanyasiz'
    END AS Grup,
    COUNT(*) AS FisSayisi,
    CAST(AVG(s.GrossTotal) AS decimal(18,2)) AS OrtBrutSepet,
    CAST(AVG(ABS(s.DiscountTotal)) AS decimal(18,2)) AS OrtIndirimTutar,
    CAST(AVG(s.GrossTotal - ABS(s.DiscountTotal)) AS decimal(18,2)) AS OrtNetSepet,
    CAST(AVG(CAST(s.LineCount AS decimal)) AS decimal(18,1)) AS OrtUrunAdet,
    CASE WHEN SUM(s.GrossTotal) > 0
         THEN CAST(SUM(ABS(s.DiscountTotal)) * 100.0 / SUM(s.GrossTotal) AS decimal(5,1))
         ELSE 0 END AS IndirimOrani,
    CAST(SUM(s.GrossTotal) AS decimal(18,2)) AS ToplamBrutCiro,
    CAST(SUM(ABS(s.DiscountTotal)) AS decimal(18,2)) AS ToplamIndirim,
    CAST(SUM(s.GrossTotal - ABS(s.DiscountTotal)) AS decimal(18,2)) AS ToplamNetCiro
FROM dbo.Sales s
LEFT JOIN cte_3al2ode c3 ON s.Id = c3.SalesId
LEFT JOIN cte_any_campaign ca ON s.Id = ca.SalesId
WHERE s.DocumentsTypeId IN (1,2)
GROUP BY CONVERT(varchar(7), s.Date, 126),
    CASE
        WHEN c3.SalesId IS NOT NULL THEN '3Al2Ode'
        WHEN ca.SalesId IS NOT NULL THEN 'DigerKampanya'
        ELSE 'Kampanyasiz'
    END
ORDER BY Ay, Grup
"""

# ══════════════════════════════════════════════════════════════
# COLORS & STYLES
# ══════════════════════════════════════════════════════════════
DARK   = "1E293B"
BLUE   = "3B82F6"
AMBER  = "F59E0B"
GRAY   = "64748B"
GREEN  = "22C55E"
WHITE  = "FFFFFF"
LTBLUE = "DBEAFE"
LTAMBER= "FEF3C7"
LTGRAY = "F1F5F9"
LTGREEN= "DCFCE7"
ROW_ALT= "F8FAFC"

hdr_font = Font(name="Segoe UI", bold=True, color=WHITE, size=10)
hdr_fill = PatternFill(start_color=DARK, end_color=DARK, fill_type="solid")
hdr_align= Alignment(horizontal="center", vertical="center", wrap_text=True)
thin_border = Border(
    left=Side(style="thin", color="CBD5E1"),
    right=Side(style="thin", color="CBD5E1"),
    top=Side(style="thin", color="CBD5E1"),
    bottom=Side(style="thin", color="CBD5E1"),
)
data_font = Font(name="Segoe UI", size=10)
alt_fill  = PatternFill(start_color=ROW_ALT, end_color=ROW_ALT, fill_type="solid")

def style_header(ws, row, ncols):
    for c in range(1, ncols + 1):
        cell = ws.cell(row=row, column=c)
        cell.font = hdr_font
        cell.fill = hdr_fill
        cell.alignment = hdr_align
        cell.border = thin_border

def style_data(ws, start_row, end_row, ncols):
    for r in range(start_row, end_row + 1):
        for c in range(1, ncols + 1):
            cell = ws.cell(row=r, column=c)
            cell.font = data_font
            cell.border = thin_border
            cell.alignment = Alignment(horizontal="right" if c > 1 else "left", vertical="center")
            if (r - start_row) % 2 == 1:
                cell.fill = alt_fill

def auto_width(ws, ncols, extra=3):
    for c in range(1, ncols + 1):
        max_len = 0
        col_letter = get_column_letter(c)
        for row in ws.iter_rows(min_col=c, max_col=c, values_only=False):
            for cell in row:
                if cell.value:
                    max_len = max(max_len, len(str(cell.value)))
        ws.column_dimensions[col_letter].width = min(max_len + extra, 22)

# ══════════════════════════════════════════════════════════════
# SQL CONNECTION
# ══════════════════════════════════════════════════════════════
def fetch_data():
    print(f"[*] SQL Server'a baglaniyor: {SQL_SERVER}/{SQL_DATABASE} ...")

    # ODBC driver bul
    drivers = [d for d in pyodbc.drivers() if "SQL Server" in d]
    if not drivers:
        print("[!] ODBC SQL Server driver bulunamadi!")
        print("    Yuklenmis driver'lar:", pyodbc.drivers())
        sys.exit(1)
    driver = drivers[-1]  # en yeni versiyonu sec
    print(f"    Driver: {driver}")

    if SQL_USER:
        conn_str = f"DRIVER={{{driver}}};SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};UID={SQL_USER};PWD={SQL_PASS}"
    else:
        conn_str = f"DRIVER={{{driver}}};SERVER={SQL_SERVER};DATABASE={SQL_DATABASE};Trusted_Connection=yes"

    conn = pyodbc.connect(conn_str, timeout=30)
    cursor = conn.cursor()

    print("[*] Sorgu calistiriliyor ...")
    cursor.execute(QUERY)
    columns = [desc[0] for desc in cursor.description]
    rows = cursor.fetchall()

    conn.close()
    print(f"[+] {len(rows)} satir cekildi.")
    return columns, [list(r) for r in rows]

# ══════════════════════════════════════════════════════════════
# SHEET 1: VERI (Raw Data)
# ══════════════════════════════════════════════════════════════
def create_veri_sheet(wb, columns, data):
    ws = wb.active
    ws.title = "Veri"
    ws.sheet_properties.tabColor = BLUE

    # Basliklar
    extra_cols = ["FisPayi", "BrutCiroPayi", "SepetCarpani", "NetSepetCarpani", "UrunCarpani"]
    all_cols = columns + extra_cols
    for c, name in enumerate(all_cols, 1):
        ws.cell(row=1, column=c, value=name)
    style_header(ws, 1, len(all_cols))

    # Veri
    for r, row in enumerate(data, 2):
        for c, val in enumerate(row, 1):
            cell = ws.cell(row=r, column=c, value=val)

    n = len(data) + 1  # son veri satiri

    # Formul kolonlari (L-P)
    # Her 3 satir bir ay grubu: satir 2-4 = ay1, 5-7 = ay2 ...
    # Kampanyasiz her grubun 3. satiri
    for r in range(2, n + 1):
        row_idx = r - 2  # 0-based
        grp_start = (row_idx // 3) * 3 + 2  # grubun ilk satiri
        ksz_row = grp_start + 2  # Kampanyasiz satiri

        # L: Fis Payi = FisSayisi / (ayni ay toplam fis)
        ws.cell(row=r, column=12, value=f"=C{r}/(C{grp_start}+C{grp_start+1}+C{grp_start+2})")

        # M: Brut Ciro Payi
        ws.cell(row=r, column=13, value=f"=I{r}/(I{grp_start}+I{grp_start+1}+I{grp_start+2})")

        # N: Sepet Carpani (Brut Sepet / Kampanyasiz Brut Sepet)
        ws.cell(row=r, column=14, value=f"=IF(D{ksz_row}>0,D{r}/D{ksz_row},0)")

        # O: Net Sepet Carpani
        ws.cell(row=r, column=15, value=f"=IF(F{ksz_row}>0,F{r}/F{ksz_row},0)")

        # P: Urun Carpani
        ws.cell(row=r, column=16, value=f"=IF(G{ksz_row}>0,G{r}/G{ksz_row},0)")

    style_data(ws, 2, n, len(all_cols))

    # Sayi formatlari
    for r in range(2, n + 1):
        ws.cell(row=r, column=3).number_format = '#,##0'       # FisSayisi
        ws.cell(row=r, column=4).number_format = '#,##0.00'    # OrtBrutSepet
        ws.cell(row=r, column=5).number_format = '#,##0.00'    # OrtIndirimTutar
        ws.cell(row=r, column=6).number_format = '#,##0.00'    # OrtNetSepet
        ws.cell(row=r, column=7).number_format = '0.0'         # OrtUrunAdet
        ws.cell(row=r, column=8).number_format = '0.0'         # IndirimOrani (%)
        ws.cell(row=r, column=9).number_format = '#,##0'       # ToplamBrutCiro
        ws.cell(row=r, column=10).number_format = '#,##0'      # ToplamIndirim
        ws.cell(row=r, column=11).number_format = '#,##0'      # ToplamNetCiro
        ws.cell(row=r, column=12).number_format = '0.0%'       # FisPayi
        ws.cell(row=r, column=13).number_format = '0.0%'       # CiroPayi
        ws.cell(row=r, column=14).number_format = '0.0x'       # SepetCarpani
        ws.cell(row=r, column=15).number_format = '0.0x'       # NetSepetCarpani
        ws.cell(row=r, column=16).number_format = '0.0x'       # UrunCarpani

    auto_width(ws, len(all_cols))
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = f"A1:{get_column_letter(len(all_cols))}{n}"

    return n  # son satir

# ══════════════════════════════════════════════════════════════
# SHEET 2: OZET (Summary Pivot)
# ══════════════════════════════════════════════════════════════
def create_ozet_sheet(wb, data, veri_last_row):
    ws = wb.create_sheet("Ozet")
    ws.sheet_properties.tabColor = "16A34A"

    headers = [
        "Ay",
        "3AL2ODE Fis", "Diger Fis", "Ksiz Fis", "Toplam Fis",
        "3AL2ODE Ort.Brut", "Diger Ort.Brut", "Ksiz Ort.Brut",
        "3AL2ODE Ort.Net", "Diger Ort.Net", "Ksiz Ort.Net",
        "3AL2ODE Urun", "Diger Urun", "Ksiz Urun",
        "3AL2ODE Ind%", "Diger Ind%",
        "3AL2ODE BrutCiro", "Diger BrutCiro", "Ksiz BrutCiro", "Toplam BrutCiro",
        "3AL2ODE NetCiro", "Diger NetCiro", "Ksiz NetCiro", "Toplam NetCiro",
        "3AL2ODE CiroPay%"
    ]

    for c, h in enumerate(headers, 1):
        ws.cell(row=1, column=c, value=h)
    style_header(ws, 1, len(headers))

    # Aylar
    months = sorted(set(r[0] for r in data))
    month_labels = {
        "2025-07": "Tem 25", "2025-08": "Agu 25", "2025-09": "Eyl 25",
        "2025-10": "Eki 25", "2025-11": "Kas 25", "2025-12": "Ara 25",
        "2026-01": "Oca 26", "2026-02": "Sub 26", "2026-03": "Mar 26",
        "2026-04": "Nis 26", "2026-05": "May 26", "2026-06": "Haz 26",
        "2026-07": "Tem 26", "2026-08": "Agu 26", "2026-09": "Eyl 26",
        "2026-10": "Eki 26", "2026-11": "Kas 26", "2026-12": "Ara 26",
    }

    for i, m in enumerate(months):
        r = i + 2
        vr = i * 3 + 2  # Veri sheet'teki satir (3al=vr, diger=vr+1, ksiz=vr+2)

        ws.cell(row=r, column=1, value=month_labels.get(m, m))

        # Fis sayilari (Veri!C kolonu)
        ws.cell(row=r, column=2, value=f"=Veri!C{vr}")          # 3AL
        ws.cell(row=r, column=3, value=f"=Veri!C{vr+1}")        # Diger
        ws.cell(row=r, column=4, value=f"=Veri!C{vr+2}")        # Ksiz
        ws.cell(row=r, column=5, value=f"=B{r}+C{r}+D{r}")      # Toplam

        # Ort Brut Sepet (Veri!D)
        ws.cell(row=r, column=6, value=f"=Veri!D{vr}")
        ws.cell(row=r, column=7, value=f"=Veri!D{vr+1}")
        ws.cell(row=r, column=8, value=f"=Veri!D{vr+2}")

        # Ort Net Sepet (Veri!F)
        ws.cell(row=r, column=9, value=f"=Veri!F{vr}")
        ws.cell(row=r, column=10, value=f"=Veri!F{vr+1}")
        ws.cell(row=r, column=11, value=f"=Veri!F{vr+2}")

        # Ort Urun (Veri!G)
        ws.cell(row=r, column=12, value=f"=Veri!G{vr}")
        ws.cell(row=r, column=13, value=f"=Veri!G{vr+1}")
        ws.cell(row=r, column=14, value=f"=Veri!G{vr+2}")

        # Indirim Orani (Veri!H)
        ws.cell(row=r, column=15, value=f"=Veri!H{vr}/100")
        ws.cell(row=r, column=16, value=f"=Veri!H{vr+1}/100")

        # Brut Ciro (Veri!I)
        ws.cell(row=r, column=17, value=f"=Veri!I{vr}")
        ws.cell(row=r, column=18, value=f"=Veri!I{vr+1}")
        ws.cell(row=r, column=19, value=f"=Veri!I{vr+2}")
        ws.cell(row=r, column=20, value=f"=Q{r}+R{r}+S{r}")

        # Net Ciro (Veri!K)
        ws.cell(row=r, column=21, value=f"=Veri!K{vr}")
        ws.cell(row=r, column=22, value=f"=Veri!K{vr+1}")
        ws.cell(row=r, column=23, value=f"=Veri!K{vr+2}")
        ws.cell(row=r, column=24, value=f"=U{r}+V{r}+W{r}")

        # 3AL2ODE Ciro Payi
        ws.cell(row=r, column=25, value=f"=IF(T{r}>0,Q{r}/T{r},0)")

    last = len(months) + 1
    tot  = last + 1

    # TOPLAM satiri
    ws.cell(row=tot, column=1, value="TOPLAM")
    ws.cell(row=tot, column=1).font = Font(name="Segoe UI", bold=True, size=10)

    for c in [2,3,4,5, 17,18,19,20, 21,22,23,24]:  # SUM kolonlari
        col_l = get_column_letter(c)
        ws.cell(row=tot, column=c, value=f"=SUM({col_l}2:{col_l}{last})")

    for c in [6,7,8, 9,10,11, 12,13,14, 15,16]:  # AVERAGE kolonlari
        col_l = get_column_letter(c)
        ws.cell(row=tot, column=c, value=f"=AVERAGE({col_l}2:{col_l}{last})")

    ws.cell(row=tot, column=25, value=f"=IF(T{tot}>0,Q{tot}/T{tot},0)")

    style_data(ws, 2, tot, len(headers))

    # Toplam satiri kalin
    for c in range(1, len(headers) + 1):
        ws.cell(row=tot, column=c).font = Font(name="Segoe UI", bold=True, size=10)
        ws.cell(row=tot, column=c).fill = PatternFill(start_color="E2E8F0", end_color="E2E8F0", fill_type="solid")

    # Sayi formatlari
    for r in range(2, tot + 1):
        for c in [2,3,4,5]:
            ws.cell(row=r, column=c).number_format = '#,##0'
        for c in [6,7,8,9,10,11]:
            ws.cell(row=r, column=c).number_format = '#,##0.00'
        for c in [12,13,14]:
            ws.cell(row=r, column=c).number_format = '0.0'
        for c in [15,16,25]:
            ws.cell(row=r, column=c).number_format = '0.0%'
        for c in [17,18,19,20,21,22,23,24]:
            ws.cell(row=r, column=c).number_format = '#,##0'

    auto_width(ws, len(headers))
    ws.freeze_panes = "B2"

    return len(months), tot

# ══════════════════════════════════════════════════════════════
# SHEET 3: DASHBOARD
# ══════════════════════════════════════════════════════════════
def create_dashboard(wb, num_months, ozet_last_row):
    ws = wb.create_sheet("Dashboard")
    ws.sheet_properties.tabColor = "EA580C"
    oz = num_months + 1  # ozet son veri satiri

    # ── Baslik ──
    ws.merge_cells("A1:L2")
    title_cell = ws.cell(row=1, column=1, value="Sepet Buyuklugu Etkisi — BKM Kitap")
    title_cell.font = Font(name="Segoe UI", bold=True, size=20, color=WHITE)
    title_cell.fill = PatternFill(start_color=DARK, end_color=DARK, fill_type="solid")
    title_cell.alignment = Alignment(horizontal="center", vertical="center")

    ws.merge_cells("A3:L3")
    sub_cell = ws.cell(row=3, column=1, value=f"SQL Server'dan yenilenen veri • Son guncelleme: {datetime.datetime.now().strftime('%d.%m.%Y %H:%M')}")
    sub_cell.font = Font(name="Segoe UI", size=10, color=GRAY, italic=True)
    sub_cell.alignment = Alignment(horizontal="center")

    # ── KPI KUTULARI ──
    kpi_defs = [
        ("A5:B7",  "3AL2ODE\nOrt. Brut Sepet",    f"=Ozet!F{ozet_last_row}",  '#,##0 "TL"', LTBLUE, BLUE),
        ("C5:D7",  "Diger Kamp.\nOrt. Brut Sepet", f"=Ozet!G{ozet_last_row}",  '#,##0 "TL"', LTAMBER, AMBER),
        ("E5:F7",  "Kampanyasiz\nOrt. Brut Sepet",  f"=Ozet!H{ozet_last_row}",  '#,##0 "TL"', LTGRAY, GRAY),
        ("G5:H7",  "3AL2ODE\nOrt. Net Sepet",      f"=Ozet!I{ozet_last_row}",  '#,##0 "TL"', LTBLUE, BLUE),
        ("I5:J7",  "Brut Sepet\nCarpani",           f"=Ozet!F{ozet_last_row}/Ozet!H{ozet_last_row}", '0.0"x"', LTGREEN, GREEN),
        ("K5:L7",  "Urun/Fis\nCarpani",             f"=Ozet!L{ozet_last_row}/Ozet!N{ozet_last_row}", '0.0"x"', LTGREEN, GREEN),
    ]

    for merge_range, label, formula, fmt, bg_color, border_color in kpi_defs:
        ws.merge_cells(merge_range)
        top_left = merge_range.split(":")[0]
        r, c = int(top_left[1:]), ord(top_left[0]) - 64

        # Label satiri (ustte)
        ws.cell(row=r, column=c, value=label)
        ws.cell(row=r, column=c).font = Font(name="Segoe UI", size=9, color=GRAY)
        ws.cell(row=r, column=c).alignment = Alignment(horizontal="center", vertical="top", wrap_text=True)
        ws.cell(row=r, column=c).fill = PatternFill(start_color=bg_color, end_color=bg_color, fill_type="solid")

        # Deger satiri (altta)
        ws.cell(row=r+1, column=c, value=formula if not formula.startswith("=") else None)
        if formula.startswith("="):
            ws.cell(row=r+1, column=c, value=formula)
        ws.cell(row=r+1, column=c).font = Font(name="Segoe UI", bold=True, size=18, color=border_color)
        ws.cell(row=r+1, column=c).number_format = fmt
        ws.cell(row=r+1, column=c).alignment = Alignment(horizontal="center", vertical="center")
        ws.cell(row=r+1, column=c).fill = PatternFill(start_color=bg_color, end_color=bg_color, fill_type="solid")

    # ── GRAFIKLER ──
    ozet_ws = wb["Ozet"]

    # Grafik 1: Ort. Brut Sepet Trendi (satir 9)
    ch1 = LineChart()
    ch1.title = "Ortalama Brut Sepet Trendi (TL)"
    ch1.style = 10
    ch1.width = 28
    ch1.height = 14
    ch1.y_axis.title = "TL"
    cats = Reference(ozet_ws, min_col=1, min_row=2, max_row=oz)
    for col, name, color in [(6, "3AL2ODE", BLUE), (7, "Diger Kamp.", AMBER), (8, "Kampanyasiz", GRAY)]:
        vals = Reference(ozet_ws, min_col=col, min_row=1, max_row=oz)
        ch1.add_data(vals, titles_from_data=True)
    ch1.set_categories(cats)
    for i, color in enumerate([BLUE, AMBER, GRAY]):
        ch1.series[i].graphicalProperties.line.solidFill = color
        ch1.series[i].graphicalProperties.line.width = 25000
    ws.add_chart(ch1, "A9")

    # Grafik 2: Ort. Urun Adedi Trendi (satir 9, sag)
    ch2 = LineChart()
    ch2.title = "Ortalama Urun Adedi / Fis"
    ch2.style = 10
    ch2.width = 28
    ch2.height = 14
    ch2.y_axis.title = "Adet"
    for col in [12, 13, 14]:
        vals = Reference(ozet_ws, min_col=col, min_row=1, max_row=oz)
        ch2.add_data(vals, titles_from_data=True)
    ch2.set_categories(cats)
    for i, color in enumerate([BLUE, AMBER, GRAY]):
        ch2.series[i].graphicalProperties.line.solidFill = color
        ch2.series[i].graphicalProperties.line.width = 25000
    ws.add_chart(ch2, "G9")

    # Grafik 3: Stacked Bar - Net Ciro (satir 26)
    ch3 = BarChart()
    ch3.type = "col"
    ch3.grouping = "stacked"
    ch3.title = "Aylik Toplam Net Ciro (TL)"
    ch3.style = 10
    ch3.width = 28
    ch3.height = 14
    ch3.y_axis.title = "TL"
    for col in [21, 22, 23]:
        vals = Reference(ozet_ws, min_col=col, min_row=1, max_row=oz)
        ch3.add_data(vals, titles_from_data=True)
    ch3.set_categories(cats)
    for i, color in enumerate([BLUE, AMBER, GRAY]):
        ch3.series[i].graphicalProperties.solidFill = color
    ws.add_chart(ch3, "A26")

    # Grafik 4: Indirim Orani Trendi (satir 26, sag)
    ch4 = LineChart()
    ch4.title = "Indirim Orani Trendi (%)"
    ch4.style = 10
    ch4.width = 28
    ch4.height = 14
    ch4.y_axis.title = "%"
    ch4.y_axis.numFmt = '0.0%'
    for col in [15, 16]:
        vals = Reference(ozet_ws, min_col=col, min_row=1, max_row=oz)
        ch4.add_data(vals, titles_from_data=True)
    ch4.set_categories(cats)
    for i, color in enumerate([BLUE, AMBER]):
        ch4.series[i].graphicalProperties.line.solidFill = color
        ch4.series[i].graphicalProperties.line.width = 25000
    ws.add_chart(ch4, "G26")

    # Grafik 5: 3AL2ODE Brut/Indirim/Net Breakdown (satir 43)
    ch5 = BarChart()
    ch5.type = "col"
    ch5.grouping = "stacked"
    ch5.title = "3AL2ODE — Brut Ciro vs Indirim (TL)"
    ch5.style = 10
    ch5.width = 56
    ch5.height = 14
    # Net ciro
    net_vals = Reference(ozet_ws, min_col=21, min_row=1, max_row=oz)
    ch5.add_data(net_vals, titles_from_data=True)
    ch5.series[0].graphicalProperties.solidFill = BLUE
    # Indirim (brut - net = toplam indirim). Hesapla: BrutCiro - NetCiro
    # Bunun icin Ozet'e ek kolon ekleyelim veya ciro farkini kullanalim
    # Basit yol: ToplamIndirim = Veri'den cekilebilir ama Ozet'te yok
    # Ozet'e ekleyelim: Q - U = Indirim
    ch5.set_categories(cats)
    ws.add_chart(ch5, "A43")

    # Grafik 6: Fis Sayisi (satir 43, sag taraf yerine 60)
    ch6 = BarChart()
    ch6.type = "col"
    ch6.grouping = "stacked"
    ch6.title = "Aylik Fis Sayisi Dagilimi"
    ch6.style = 10
    ch6.width = 56
    ch6.height = 14
    for col in [2, 3, 4]:
        vals = Reference(ozet_ws, min_col=col, min_row=1, max_row=oz)
        ch6.add_data(vals, titles_from_data=True)
    ch6.set_categories(cats)
    for i, color in enumerate([BLUE, AMBER, GRAY]):
        ch6.series[i].graphicalProperties.solidFill = color
    ws.add_chart(ch6, "A60")

    # Kolon genislikleri
    for c in range(1, 13):
        ws.column_dimensions[get_column_letter(c)].width = 14

# ══════════════════════════════════════════════════════════════
# SHEET 4: BILGI (Connection info + SQL)
# ══════════════════════════════════════════════════════════════
def create_bilgi_sheet(wb):
    ws = wb.create_sheet("SQL Sorgu")
    ws.sheet_properties.tabColor = "A855F7"

    info = [
        ["Veri Kaynagi", f"{SQL_SERVER} / {SQL_DATABASE}"],
        ["Olusturma Tarihi", datetime.datetime.now().strftime("%d.%m.%Y %H:%M")],
        ["Yenileme Komutu", f"python {os.path.basename(__file__)}"],
        ["", ""],
        ["SQL Sorgusu:", ""],
    ]
    for r, (k, v) in enumerate(info, 1):
        ws.cell(row=r, column=1, value=k).font = Font(name="Segoe UI", bold=True, size=10)
        ws.cell(row=r, column=2, value=v).font = Font(name="Segoe UI", size=10)

    # SQL sorgusu
    for r, line in enumerate(QUERY.strip().split("\n"), 7):
        ws.cell(row=r, column=1, value=line).font = Font(name="Consolas", size=9, color="334155")

    ws.column_dimensions["A"].width = 60
    ws.column_dimensions["B"].width = 50

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════
def main():
    print("=" * 60)
    print("  Sepet Buyuklugu Etkisi — Excel Rapor Uretici")
    print("=" * 60)

    # Veri cek
    columns, data = fetch_data()

    if not data:
        print("[!] Veri bulunamadi!")
        sys.exit(1)

    # Excel olustur
    print("[*] Excel olusturuluyor ...")
    wb = Workbook()

    veri_last = create_veri_sheet(wb, columns, data)
    print(f"    [+] Veri sayfasi: {len(data)} satir")

    num_months, ozet_last = create_ozet_sheet(wb, data, veri_last)
    print(f"    [+] Ozet sayfasi: {num_months} ay")

    create_dashboard(wb, num_months, ozet_last)
    print("    [+] Dashboard sayfasi: 6 KPI + 6 grafik")

    create_bilgi_sheet(wb)
    print("    [+] SQL Sorgu sayfasi")

    # Kaydet
    wb.save(OUTPUT_FILE)
    print(f"\n[+] TAMAMLANDI: {OUTPUT_FILE}")
    print(f"    Boyut: {os.path.getsize(OUTPUT_FILE) / 1024:.0f} KB")
    print(f"    Yenilemek icin tekrar calistirin: python {os.path.basename(__file__)}")

if __name__ == "__main__":
    main()
