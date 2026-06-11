#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys

# Ensure openpyxl is installed
try:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.table import Table, TableStyleInfo
except ImportError:
    print("Installing openpyxl...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "openpyxl", "-q"])
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.table import Table, TableStyleInfo

# Raw data
raw_data = [
    ["2025-07", "3Al2Ode", 5313, 1411.90, 338.39, 1073.51, 7.1, 24.0, 7501427, 1797859, 5703568],
    ["2025-07", "DigerKampanya", 7940, 604.25, 127.82, 476.43, 3.8, 21.2, 4797728, 1014876, 3782853],
    ["2025-07", "Kampanyasiz", 9407, 374.85, 0, 374.85, 2.2, 0, 3526169, 0, 3526169],
    ["2025-08", "3Al2Ode", 16231, 1640.68, 380.62, 1260.06, 7.9, 23.2, 26629950, 6177898, 20452052],
    ["2025-08", "DigerKampanya", 23485, 939.02, 157.75, 781.27, 5.5, 16.8, 22052787, 3704678, 18348109],
    ["2025-08", "Kampanyasiz", 28652, 436.60, 0, 436.60, 2.4, 0, 12509517, 0, 12509517],
    ["2025-09", "3Al2Ode", 33930, 1923.79, 438.66, 1485.13, 8.5, 22.8, 65274123, 14883571, 50390552],
    ["2025-09", "DigerKampanya", 42360, 1191.56, 199.60, 991.95, 7.3, 16.8, 50474397, 8455224, 42019173],
    ["2025-09", "Kampanyasiz", 42189, 527.15, 0, 527.15, 2.9, 0, 22240070, 0, 22240070],
    ["2025-10", "3Al2Ode", 27865, 1583.22, 384.49, 1198.73, 7.3, 24.3, 44116376, 10713720, 33402656],
    ["2025-10", "DigerKampanya", 37391, 701.43, 122.31, 579.13, 4.5, 17.4, 26227227, 4573110, 21654117],
    ["2025-10", "Kampanyasiz", 40168, 385.81, 0, 385.81, 2.3, 0, 15497054, 0, 15497054],
    ["2025-11", "3Al2Ode", 22300, 1494.93, 363.58, 1131.35, 7.2, 24.3, 33337040, 8107865, 25229175],
    ["2025-11", "DigerKampanya", 33948, 652.98, 125.13, 527.85, 4.4, 19.2, 22167441, 4247918, 17919523],
    ["2025-11", "Kampanyasiz", 37982, 366.85, 0, 366.85, 2.3, 0, 13933840, 0, 13933840],
    ["2025-12", "3Al2Ode", 21692, 1509.59, 357.31, 1152.28, 7.0, 23.7, 32746018, 7750732, 24995286],
    ["2025-12", "DigerKampanya", 39289, 728.24, 144.99, 583.25, 4.4, 19.9, 28611745, 5696522, 22915223],
    ["2025-12", "Kampanyasiz", 41137, 409.49, 0, 409.49, 2.4, 0, 16845153, 0, 16845153],
    ["2026-01", "3Al2Ode", 25900, 1582.14, 376.81, 1205.33, 7.4, 23.8, 40977343, 9759274, 31218069],
    ["2026-01", "DigerKampanya", 42463, 683.67, 141.61, 542.06, 4.3, 20.7, 29030682, 6013094, 23017587],
    ["2026-01", "Kampanyasiz", 39075, 409.59, 0, 409.59, 2.3, 0, 16004580, 0, 16004580],
    ["2026-02", "3Al2Ode", 20602, 1577.80, 380.45, 1197.34, 7.0, 24.1, 32505735, 7838084, 24667651],
    ["2026-02", "DigerKampanya", 36909, 694.20, 146.15, 548.05, 4.3, 21.1, 25622219, 5394407, 20227812],
    ["2026-02", "Kampanyasiz", 33700, 432.59, 0, 432.59, 2.4, 0, 14578266, 0, 14578266],
    ["2026-03", "3Al2Ode", 20958, 1613.42, 393.21, 1220.21, 7.1, 24.4, 33814101, 8240945, 25573156],
    ["2026-03", "DigerKampanya", 41089, 692.83, 146.87, 545.95, 4.4, 21.2, 28467587, 6034844, 22432743],
    ["2026-03", "Kampanyasiz", 32812, 439.46, 0, 439.46, 2.3, 0, 14419463, 0, 14419463],
    ["2026-04", "3Al2Ode", 8467, 1597.58, 388.38, 1209.20, 7.1, 24.3, 13526737, 3288430, 10238307],
    ["2026-04", "DigerKampanya", 18073, 680.27, 144.95, 535.32, 4.4, 21.3, 12294594, 2619727, 9674867],
    ["2026-04", "Kampanyasiz", 14230, 427.84, 0, 427.84, 2.3, 0, 6088197, 0, 6088197],
]

# Create workbook
wb = Workbook()
wb.remove(wb.active)

# =====================================================
# SHEET 1: Veri (Raw Data)
# =====================================================
ws_veri = wb.create_sheet("Veri", 0)
ws_veri.sheet_properties.tabColor = "0070C0"

headers_veri = ["Ay", "Grup", "FisSayisi", "OrtBrutSepet", "OrtIndirimTutar", "OrtNetSepet",
                "OrtUrunAdet", "IndirimOrani", "ToplamBrutCiro", "ToplamIndirim", "ToplamNetCiro"]

ws_veri.append(headers_veri)

for row_data in raw_data:
    ws_veri.append(row_data)

# Format headers
header_fill = PatternFill(start_color="1E293B", end_color="1E293B", fill_type="solid")
header_font = Font(bold=True, color="FFFFFF", size=11)

for col_num, header in enumerate(headers_veri, 1):
    cell = ws_veri.cell(row=1, column=col_num)
    cell.fill = header_fill
    cell.font = header_font
    cell.alignment = Alignment(horizontal="center", vertical="center")

# Format data cells
thin_border = Border(
    left=Side(style='thin'),
    right=Side(style='thin'),
    top=Side(style='thin'),
    bottom=Side(style='thin')
)

for row_num in range(2, len(raw_data) + 2):
    fill = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid") if row_num % 2 == 0 else PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")

    for col_num in range(1, len(headers_veri) + 1):
        cell = ws_veri.cell(row=row_num, column=col_num)
        cell.border = thin_border
        cell.fill = fill

        if col_num == 1:
            cell.alignment = Alignment(horizontal="center")
        elif col_num == 2:
            cell.alignment = Alignment(horizontal="left")
        elif col_num in [3, 9, 10, 11]:
            cell.number_format = '#,##0'
            cell.alignment = Alignment(horizontal="right")
        elif col_num in [4, 5, 6, 7]:
            cell.number_format = '#,##0.00'
            cell.alignment = Alignment(horizontal="right")
        elif col_num == 8:
            cell.number_format = '0.0'
            cell.alignment = Alignment(horizontal="right")

column_widths = [10, 15, 12, 15, 15, 15, 12, 12, 14, 14, 14]
for idx, width in enumerate(column_widths, 1):
    ws_veri.column_dimensions[get_column_letter(idx)].width = width

ws_veri.freeze_panes = "A2"

tab = Table(displayName="VeriTable", ref=f"A1:K{len(raw_data)+1}")
style = TableStyleInfo(name="TableStyleMedium2", showFirstColumn=False,
                       showLastColumn=False, showRowStripes=True, showColumnStripes=False)
tab.tableStyleInfo = style
ws_veri.add_table(tab)

# =====================================================
# SHEET 2: Özet (Summary/Pivot)
# =====================================================
ws_ozet = wb.create_sheet("Özet", 1)
ws_ozet.sheet_properties.tabColor = "00B050"

ozet_headers = [
    "Ay",
    "3AL2ÖDE Fiş", "Diğer Fiş", "Kampanyasız Fiş", "Toplam Fiş",
    "3AL2ÖDE Ort.Brüt", "Diğer Ort.Brüt", "K.sız Ort.Brüt",
    "3AL2ÖDE Ort.Net", "Diğer Ort.Net", "K.sız Ort.Net",
    "3AL2ÖDE Ürün", "Diğer Ürün", "K.sız Ürün",
    "3AL2ÖDE İnd%", "Diğer İnd%",
    "3AL2ÖDE BrütCiro", "Diğer BrütCiro", "K.sız BrütCiro", "Toplam BrütCiro",
    "3AL2ÖDE NetCiro", "Diğer NetCiro", "K.sız NetCiro", "Toplam NetCiro",
    "3AL2ÖDE Pay%"
]

ws_ozet.append(ozet_headers)

for col_num, header in enumerate(ozet_headers, 1):
    cell = ws_ozet.cell(row=1, column=col_num)
    cell.fill = header_fill
    cell.font = header_font
    cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)

# Get unique months
months = []
for row_data in raw_data:
    if row_data[0] not in months:
        months.append(row_data[0])

current_row = 2
for month in months:
    month_rows = [idx for idx, row in enumerate(raw_data) if row[0] == month]

    ws_ozet.cell(row=current_row, column=1).value = month

    veri_row_3al = month_rows[0] + 2
    veri_row_diger = month_rows[1] + 2
    veri_row_kamp = month_rows[2] + 2

    # Fiş Sayıları
    ws_ozet.cell(row=current_row, column=2).value = f"=Veri!C{veri_row_3al}"
    ws_ozet.cell(row=current_row, column=3).value = f"=Veri!C{veri_row_diger}"
    ws_ozet.cell(row=current_row, column=4).value = f"=Veri!C{veri_row_kamp}"
    ws_ozet.cell(row=current_row, column=5).value = f"=B{current_row}+C{current_row}+D{current_row}"

    # Ort.Brüt Sepet
    ws_ozet.cell(row=current_row, column=6).value = f"=Veri!D{veri_row_3al}"
    ws_ozet.cell(row=current_row, column=7).value = f"=Veri!D{veri_row_diger}"
    ws_ozet.cell(row=current_row, column=8).value = f"=Veri!D{veri_row_kamp}"

    # Ort.Net Sepet
    ws_ozet.cell(row=current_row, column=9).value = f"=Veri!F{veri_row_3al}"
    ws_ozet.cell(row=current_row, column=10).value = f"=Veri!F{veri_row_diger}"
    ws_ozet.cell(row=current_row, column=11).value = f"=Veri!F{veri_row_kamp}"

    # Ürün Adedi
    ws_ozet.cell(row=current_row, column=12).value = f"=Veri!G{veri_row_3al}"
    ws_ozet.cell(row=current_row, column=13).value = f"=Veri!G{veri_row_diger}"
    ws_ozet.cell(row=current_row, column=14).value = f"=Veri!G{veri_row_kamp}"

    # İndirim Oranı
    ws_ozet.cell(row=current_row, column=15).value = f"=Veri!H{veri_row_3al}"
    ws_ozet.cell(row=current_row, column=16).value = f"=Veri!H{veri_row_diger}"

    # Brüt Ciro
    ws_ozet.cell(row=current_row, column=17).value = f"=Veri!I{veri_row_3al}"
    ws_ozet.cell(row=current_row, column=18).value = f"=Veri!I{veri_row_diger}"
    ws_ozet.cell(row=current_row, column=19).value = f"=Veri!I{veri_row_kamp}"
    ws_ozet.cell(row=current_row, column=20).value = f"=Q{current_row}+R{current_row}+S{current_row}"

    # Net Ciro
    ws_ozet.cell(row=current_row, column=21).value = f"=Veri!K{veri_row_3al}"
    ws_ozet.cell(row=current_row, column=22).value = f"=Veri!K{veri_row_diger}"
    ws_ozet.cell(row=current_row, column=23).value = f"=Veri!K{veri_row_kamp}"
    ws_ozet.cell(row=current_row, column=24).value = f"=U{current_row}+V{current_row}+W{current_row}"

    # 3AL2ÖDE Pay%
    ws_ozet.cell(row=current_row, column=25).value = f"=Q{current_row}/T{current_row}"

    current_row += 1

# Add TOTALS row
total_row = current_row
ws_ozet.cell(row=total_row, column=1).value = "TOPLAM"
ws_ozet.cell(row=total_row, column=1).font = Font(bold=True)

for col_num in range(2, 26):
    cell = ws_ozet.cell(row=total_row, column=col_num)
    col_letter = get_column_letter(col_num)
    if col_num in [2, 3, 4, 5]:
        cell.value = f"=SUM({col_letter}2:{col_letter}{total_row-1})"
    elif col_num in [15, 16, 25]:
        cell.value = f"=AVERAGE({col_letter}2:{col_letter}{total_row-1})"
    elif col_num in [20, 24]:
        cell.value = f"=SUM({col_letter}2:{col_letter}{total_row-1})"
    else:
        cell.value = f"=AVERAGE({col_letter}2:{col_letter}{total_row-1})"

    cell.font = Font(bold=True)
    cell.fill = PatternFill(start_color="E2E8F0", end_color="E2E8F0", fill_type="solid")

# Format Özet cells
for row_num in range(2, total_row + 1):
    fill = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid") if row_num % 2 == 0 else PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")

    for col_num in range(1, 26):
        cell = ws_ozet.cell(row=row_num, column=col_num)
        if row_num < total_row:
            cell.fill = fill
        cell.border = thin_border

        if col_num == 1:
            cell.alignment = Alignment(horizontal="center")
        elif col_num in [2, 3, 4, 5]:
            cell.number_format = '#,##0'
            cell.alignment = Alignment(horizontal="right")
        elif col_num in [6, 7, 8, 9, 10, 11]:
            cell.number_format = '#,##0.00'
            cell.alignment = Alignment(horizontal="right")
        elif col_num in [12, 13, 14]:
            cell.number_format = '#,##0.0'
            cell.alignment = Alignment(horizontal="right")
        elif col_num in [15, 16, 25]:
            cell.number_format = '0.0'
            cell.alignment = Alignment(horizontal="right")
        elif col_num in [17, 18, 19, 20, 21, 22, 23, 24]:
            cell.number_format = '#,##0'
            cell.alignment = Alignment(horizontal="right")

ozet_widths = [10, 12, 12, 12, 12, 14, 14, 14, 14, 14, 14, 12, 12, 12, 11, 11, 14, 14, 14, 14, 14, 14, 14, 14, 12]
for idx, width in enumerate(ozet_widths, 1):
    ws_ozet.column_dimensions[get_column_letter(idx)].width = width

ws_ozet.freeze_panes = "A2"

# =====================================================
# SHEET 3: Dashboard
# =====================================================
ws_dash = wb.create_sheet("Dashboard", 2)
ws_dash.sheet_properties.tabColor = "ED7D31"

# Title
ws_dash.merge_cells("A1:L2")
title_cell = ws_dash["A1"]
title_cell.value = "Sepet Büyüklüğü Etkisi — BKM Kitap"
title_cell.font = Font(bold=True, size=18, color="FFFFFF")
title_cell.fill = PatternFill(start_color="1E3A8A", end_color="1E3A8A", fill_type="solid")
title_cell.alignment = Alignment(horizontal="center", vertical="center")
ws_dash.row_dimensions[1].height = 28

# KPI boxes
kpi_data = [
    ("3AL2ÖDE Ort. Brüt Sepet", f"=AVERAGE(Özet!F2:F{total_row-1})"),
    ("Diğer Kamp. Ort. Brüt Sepet", f"=AVERAGE(Özet!G2:G{total_row-1})"),
    ("Kampanyasız Ort. Brüt Sepet", f"=AVERAGE(Özet!H2:H{total_row-1})"),
    ("Sepet Çarpanı (3AL2ÖDE / K.sız)", f"=E4/E6"),
    ("Ürün Çarpanı", f"=AVERAGE(Özet!L2:L{total_row-1})/AVERAGE(Özet!N2:N{total_row-1})"),
    ("Net Sepet Çarpanı", f"=AVERAGE(Özet!I2:I{total_row-1})/AVERAGE(Özet!K2:K{total_row-1})"),
]

kpi_fill = PatternFill(start_color="EFF6FF", end_color="EFF6FF", fill_type="solid")
kpi_border = Border(
    left=Side(style='medium', color='3B82F6'),
    right=Side(style='medium', color='3B82F6'),
    top=Side(style='medium', color='3B82F6'),
    bottom=Side(style='medium', color='3B82F6')
)

for idx, (label, formula) in enumerate(kpi_data):
    row = 4 + idx
    ws_dash.merge_cells(f"A{row}:B{row}")
    label_cell = ws_dash[f"A{row}"]
    label_cell.value = label
    label_cell.font = Font(bold=True, size=11)
    label_cell.alignment = Alignment(horizontal="left", vertical="center")
    label_cell.fill = kpi_fill
    label_cell.border = kpi_border
    ws_dash.row_dimensions[row].height = 22

    ws_dash.merge_cells(f"C{row}:E{row}")
    value_cell = ws_dash[f"C{row}"]
    value_cell.value = formula
    value_cell.font = Font(bold=True, size=14, color="1E3A8A")
    value_cell.number_format = '#,##0.00'
    value_cell.alignment = Alignment(horizontal="right", vertical="center")
    value_cell.fill = kpi_fill
    value_cell.border = kpi_border

ws_dash["A12"].value = "Trendler ve Analizler — Özet sayfasından oluşturulabilir"
ws_dash["A12"].font = Font(italic=True, color="666666")

# Set column widths
for col in range(1, 13):
    ws_dash.column_dimensions[get_column_letter(col)].width = 12

# Save
output_path = r"D:\Dev\pusula\sepet-buyuklugu-etkisi.xlsx"
wb.save(output_path)

print(f"Excel file created successfully!")
print(f"Saved to: {output_path}")
print(f"File exists: {os.path.exists(output_path)}")
