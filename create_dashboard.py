#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sepet Büyüklüğü Etkisi Dashboard - Excel Dosyası Oluşturucu
openpyxl kullanarak 4 sayfalı dashboard oluşturur.
"""

import subprocess
import sys
from io import StringIO
from datetime import datetime
from decimal import Decimal

# openpyxl'i yükle
try:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.table import Table, TableStyleInfo
    from openpyxl.chart import LineChart, BarChart, PieChart, Reference
    from openpyxl.utils.dataframe import dataframe_to_rows
except ImportError:
    print("openpyxl yükleniyor...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "openpyxl", "--break-system-packages"])
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter
    from openpyxl.worksheet.table import Table, TableStyleInfo
    from openpyxl.chart import LineChart, BarChart, PieChart, Reference

# Veri
veri_rows = [
    ("2025-07", "3Al2Ode", 5313, 1411.9, 338.39, 1073.51, 7.1, 24.0, 7501427.13, 1797859.02, 5703568.11),
    ("2025-07", "DigerKampanya", 7940, 604.25, 127.82, 476.43, 3.8, 21.2, 4797728.47, 1014875.83, 3782852.64),
    ("2025-07", "Kampanyasiz", 9407, 374.85, 0, 374.85, 2.2, 0, 3526169.39, 0, 3526169.39),
    ("2025-08", "3Al2Ode", 16231, 1640.68, 380.62, 1260.06, 7.9, 23.2, 26629950.01, 6177897.74, 20452052.27),
    ("2025-08", "DigerKampanya", 23485, 939.02, 157.75, 781.27, 5.5, 16.8, 22052787.42, 3704678.29, 18348109.13),
    ("2025-08", "Kampanyasiz", 28652, 436.6, 0, 436.6, 2.4, 0, 12509517.4, 0, 12509517.4),
    ("2025-09", "3Al2Ode", 33930, 1923.79, 438.66, 1485.13, 8.5, 22.8, 65274122.97, 14883570.57, 50390552.4),
    ("2025-09", "DigerKampanya", 42360, 1191.56, 199.6, 991.95, 7.3, 16.8, 50474397.46, 8455224.2, 42019173.26),
    ("2025-09", "Kampanyasiz", 42189, 527.15, 0, 527.15, 2.9, 0, 22240070.08, 0, 22240070.08),
    ("2025-10", "3Al2Ode", 27865, 1583.22, 384.49, 1198.73, 7.3, 24.3, 44116376.28, 10713719.82, 33402656.46),
    ("2025-10", "DigerKampanya", 37391, 701.43, 122.31, 579.13, 4.5, 17.4, 26227227.24, 4573110.3, 21654116.94),
    ("2025-10", "Kampanyasiz", 40168, 385.81, 0, 385.81, 2.3, 0, 15497053.83, 0, 15497053.83),
    ("2025-11", "3Al2Ode", 22300, 1494.93, 363.58, 1131.35, 7.2, 24.3, 33337040.23, 8107864.59, 25229175.64),
    ("2025-11", "DigerKampanya", 33948, 652.98, 125.13, 527.85, 4.4, 19.2, 22167440.96, 4247918.19, 17919522.77),
    ("2025-11", "Kampanyasiz", 37982, 366.85, 0, 366.85, 2.3, 0, 13933840.45, 0, 13933840.45),
    ("2025-12", "3Al2Ode", 21692, 1509.59, 357.31, 1152.28, 7.0, 23.7, 32746018.18, 7750731.82, 24995286.36),
    ("2025-12", "DigerKampanya", 39289, 728.24, 144.99, 583.25, 4.4, 19.9, 28611744.84, 5696521.71, 22915223.13),
    ("2025-12", "Kampanyasiz", 41137, 409.49, 0, 409.49, 2.4, 0, 16845152.64, 0, 16845152.64),
    ("2026-01", "3Al2Ode", 25900, 1582.14, 376.81, 1205.33, 7.4, 23.8, 40977342.99, 9759273.91, 31218069.08),
    ("2026-01", "DigerKampanya", 42463, 683.67, 141.61, 542.06, 4.3, 20.7, 29030681.69, 6013094.35, 23017587.34),
    ("2026-01", "Kampanyasiz", 39075, 409.59, 0, 409.59, 2.3, 0, 16004580.41, 0, 16004580.41),
    ("2026-02", "3Al2Ode", 20602, 1577.8, 380.45, 1197.34, 7.0, 24.1, 32505734.74, 7838083.51, 24667651.23),
    ("2026-02", "DigerKampanya", 36909, 694.2, 146.15, 548.05, 4.3, 21.1, 25622218.5, 5394406.53, 20227811.97),
    ("2026-02", "Kampanyasiz", 33700, 432.59, 0, 432.59, 2.4, 0, 14578265.74, 0, 14578265.74),
    ("2026-03", "3Al2Ode", 20958, 1613.42, 393.21, 1220.21, 7.1, 24.4, 33814100.83, 8240944.59, 25573156.24),
    ("2026-03", "DigerKampanya", 41089, 692.83, 146.87, 545.95, 4.4, 21.2, 28467587.44, 6034844.41, 22432743.03),
    ("2026-03", "Kampanyasiz", 32812, 439.46, 0, 439.46, 2.3, 0, 14419463.48, 0, 14419463.48),
    ("2026-04", "3Al2Ode", 8488, 1597.37, 388.38, 1208.99, 7.1, 24.3, 13558517.4, 3296591.17, 10261926.23),
    ("2026-04", "DigerKampanya", 18098, 680.11, 144.92, 535.19, 4.4, 21.3, 12308657.18, 2622799.32, 9685857.86),
    ("2026-04", "Kampanyasiz", 14257, 427.88, 0, 427.88, 2.3, 0, 6100347.68, 0, 6100347.68),
]

headers = ["Ay", "Grup", "Fiş Sayısı", "Ort. Brüt Sepet", "Ort. İndirim Tutarı",
           "Ort. Net Sepet", "Ort. Ürün Adet", "İndirim Oranı (%)", "Toplam Brüt Ciro",
           "Toplam İndirim", "Toplam Net Ciro"]

# Excel Workbook oluştur
wb = Workbook()
wb.remove(wb.active)  # Varsayılan boş sheet'i sil

# ====== SAYFA 1: VERİ ======
ws_veri = wb.create_sheet("Veri", 0)

# Başlıkları yaz
for col, header in enumerate(headers, 1):
    cell = ws_veri.cell(row=1, column=col, value=header)
    cell.font = Font(bold=True, color="FFFFFF", size=11)
    cell.fill = PatternFill(start_color="2E7D32", end_color="2E7D32", fill_type="solid")
    cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)

# Veriyi yaz
for row_idx, row_data in enumerate(veri_rows, 2):
    for col_idx, value in enumerate(row_data, 1):
        cell = ws_veri.cell(row=row_idx, column=col_idx, value=value)
        if col_idx in [3, 4, 5, 6, 7, 9, 10, 11]:  # Sayısal sütunlar
            cell.number_format = '#,##0.00'
        if col_idx == 8:  # İndirim Oranı
            cell.value = value / 100  # 24.3 -> 0.243
            cell.number_format = '0.0%'

# Tablo formatla (Table Style)
tab = Table(displayName="VeriTablosu", ref=f"A1:K{len(veri_rows)+1}")
style = TableStyleInfo(name="TableStyleMedium2", showFirstColumn=False,
                       showLastColumn=False, showRowStripes=True, showColumnStripes=False)
tab.tableStyleInfo = style
ws_veri.add_table(tab)

# Sütun genişlikleri
ws_veri.column_dimensions['A'].width = 12
ws_veri.column_dimensions['B'].width = 15
for col in range(3, 12):
    ws_veri.column_dimensions[get_column_letter(col)].width = 15

# Freeze pane
ws_veri.freeze_panes = "A2"

# ====== SAYFA 2: ÖZET (Pivot Tarzı) ======
ws_ozet = wb.create_sheet("Ozet", 1)

# Özet tablo başlıkları: Ay | 3Al2Ode (4 alt sütun) | DigerKampanya (4 alt sütun) | Kampanyasiz (4 alt sütun)
aylar = sorted(set(row[0] for row in veri_rows))
gruplar = ["3Al2Ode", "DigerKampanya", "Kampanyasiz"]
alt_sutunlar = ["Ort. Brüt Sepet", "Ort. Net Sepet", "Toplam Net Ciro", "Fiş Sayısı"]

# Ana başlık
ws_ozet.cell(row=1, column=1, value="Ay")
ws_ozet.cell(row=1, column=1).font = Font(bold=True, color="FFFFFF", size=11)
ws_ozet.cell(row=1, column=1).fill = PatternFill(start_color="1565C0", end_color="1565C0", fill_type="solid")

col_idx = 2
for grup in gruplar:
    # Grup başlığı (4 sütun birleştirilecek visüel olarak)
    grup_cell = ws_ozet.cell(row=1, column=col_idx, value=grup)
    grup_cell.font = Font(bold=True, color="FFFFFF", size=11)
    grup_cell.fill = PatternFill(start_color="1565C0", end_color="1565C0", fill_type="solid")
    grup_cell.alignment = Alignment(horizontal="center")

    # Alt başlıklar
    for alt in alt_sutunlar:
        alt_cell = ws_ozet.cell(row=2, column=col_idx, value=alt)
        alt_cell.font = Font(bold=True, color="FFFFFF", size=10)
        alt_cell.fill = PatternFill(start_color="42A5F5", end_color="42A5F5", fill_type="solid")
        alt_cell.alignment = Alignment(horizontal="center", wrap_text=True)
        col_idx += 1

# Veriyi dolgur
veri_dict = {(row[0], row[1]): row for row in veri_rows}

for row_idx, ay in enumerate(aylar, 3):
    ws_ozet.cell(row=row_idx, column=1, value=ay)
    ws_ozet.cell(row=row_idx, column=1).font = Font(bold=True)

    col_idx = 2
    for grup in gruplar:
        row_data = veri_dict.get((ay, grup))
        if row_data:
            ws_ozet.cell(row=row_idx, column=col_idx, value=row_data[3]).number_format = '#,##0.00'  # Ort. Brüt
            ws_ozet.cell(row=row_idx, column=col_idx+1, value=row_data[5]).number_format = '#,##0.00'  # Ort. Net
            ws_ozet.cell(row=row_idx, column=col_idx+2, value=row_data[10]).number_format = '#,##0.00'  # Toplam Net
            ws_ozet.cell(row=row_idx, column=col_idx+3, value=row_data[2]).number_format = '#,##0'  # Fiş Sayısı
        else:
            ws_ozet.cell(row=row_idx, column=col_idx, value=0).number_format = '#,##0.00'
            ws_ozet.cell(row=row_idx, column=col_idx+1, value=0).number_format = '#,##0.00'
            ws_ozet.cell(row=row_idx, column=col_idx+2, value=0).number_format = '#,##0.00'
            ws_ozet.cell(row=row_idx, column=col_idx+3, value=0).number_format = '#,##0'

        col_idx += 4

# TOPLAM satırı (formüller ile)
toplam_row = len(aylar) + 3
ws_ozet.cell(row=toplam_row, column=1, value="TOPLAM").font = Font(bold=True)
ws_ozet.cell(row=toplam_row, column=1).fill = PatternFill(start_color="E3F2FD", end_color="E3F2FD", fill_type="solid")

for col_offset in range(len(gruplar) * 4):
    col_idx = col_offset + 2
    ws_ozet.cell(row=toplam_row, column=col_idx).fill = PatternFill(start_color="E3F2FD", end_color="E3F2FD", fill_type="solid")

    # Son 3 satır (Toplam Net Ciro ve Fiş) için SUM, diğerleri için AVERAGE
    if (col_offset % 4) in [2, 3]:  # Toplam Net Ciro (index 2) ve Fiş Sayısı (index 3)
        ws_ozet.cell(row=toplam_row, column=col_idx, value=f"=SUM({get_column_letter(col_idx)}3:{get_column_letter(col_idx)}{toplam_row-1})")
    else:
        ws_ozet.cell(row=toplam_row, column=col_idx, value=f"=AVERAGE({get_column_letter(col_idx)}3:{get_column_letter(col_idx)}{toplam_row-1})")

    if (col_offset % 4) != 3:  # Fiş Sayısı hariç
        ws_ozet.cell(row=toplam_row, column=col_idx).number_format = '#,##0.00'
    else:
        ws_ozet.cell(row=toplam_row, column=col_idx).number_format = '#,##0'

# Conditional formatting: Ort Net Sepet sütunları (index 1 her grup için)
from openpyxl.formatting.rule import ColorScaleRule
for grup_idx in range(len(gruplar)):
    col_idx = 3 + grup_idx * 4  # Ort. Net Sepet sütunu
    color_scale = ColorScaleRule(
        start_type="min", start_color="FF0000",  # Kırmızı
        mid_type="percentile", mid_value=50, mid_color="FFFF00",  # Sarı
        end_type="max", end_color="00B050"  # Yeşil
    )
    ws_ozet.conditional_formatting.add(f'{get_column_letter(col_idx)}3:{get_column_letter(col_idx)}{toplam_row-1}', color_scale)

# Sütun genişlikleri
ws_ozet.column_dimensions['A'].width = 12
for col in range(2, 2 + len(gruplar) * 4):
    ws_ozet.column_dimensions[get_column_letter(col)].width = 15

ws_ozet.freeze_panes = "A3"

# ====== SAYFA 3: DASHBOARD ======
ws_dash = wb.create_sheet("Dashboard", 2)

# KPI Kartları (satır 1-6)
kpi_style_title = Font(name='Calibri', size=10, bold=False, color="FFFFFF")
kpi_style_value = Font(name='Calibri', size=20, bold=True, color="FFFFFF")
kpi_fill = PatternFill(start_color="003366", end_color="003366", fill_type="solid")

ws_dash.column_dimensions['A'].width = 20
ws_dash.column_dimensions['B'].width = 20
ws_dash.column_dimensions['C'].width = 20
ws_dash.column_dimensions['D'].width = 20

# Toplam Fiş Sayısı
ws_dash.cell(row=1, column=1, value="TOPLAM FİŞ SAYISI")
ws_dash.cell(row=1, column=1).font = kpi_style_title
ws_dash.cell(row=1, column=1).fill = kpi_fill
ws_dash.cell(row=2, column=1, value="=SUM(Veri!C2:C31)")
ws_dash.cell(row=2, column=1).font = kpi_style_value
ws_dash.cell(row=2, column=1).fill = kpi_fill
ws_dash.cell(row=2, column=1).number_format = '#,##0'

# Toplam Brüt Ciro
ws_dash.cell(row=1, column=2, value="TOPLAM BRÜT CİRO")
ws_dash.cell(row=1, column=2).font = kpi_style_title
ws_dash.cell(row=1, column=2).fill = kpi_fill
ws_dash.cell(row=2, column=2, value="=SUM(Veri!I2:I31)")
ws_dash.cell(row=2, column=2).font = kpi_style_value
ws_dash.cell(row=2, column=2).fill = kpi_fill
ws_dash.cell(row=2, column=2).number_format = '#,##0.00'

# Toplam Net Ciro
ws_dash.cell(row=1, column=3, value="TOPLAM NET CİRO")
ws_dash.cell(row=1, column=3).font = kpi_style_title
ws_dash.cell(row=1, column=3).fill = kpi_fill
ws_dash.cell(row=2, column=3, value="=SUM(Veri!K2:K31)")
ws_dash.cell(row=2, column=3).font = kpi_style_value
ws_dash.cell(row=2, column=3).fill = kpi_fill
ws_dash.cell(row=2, column=3).number_format = '#,##0.00'

# Genel İndirim Oranı
ws_dash.cell(row=1, column=4, value="GENEL İNDİRİM ORANI")
ws_dash.cell(row=1, column=4).font = kpi_style_title
ws_dash.cell(row=1, column=4).fill = kpi_fill
ws_dash.cell(row=2, column=4, value="=SUM(Veri!J2:J31)/SUM(Veri!I2:I31)*100")
ws_dash.cell(row=2, column=4).font = kpi_style_value
ws_dash.cell(row=2, column=4).fill = kpi_fill
ws_dash.cell(row=2, column=4).number_format = '0.0'

# 3Al2Öde Ortalama Sepet
ws_dash.cell(row=3, column=1, value="3AL2ÖDE ORT. SEPET")
ws_dash.cell(row=3, column=1).font = kpi_style_title
ws_dash.cell(row=3, column=1).fill = kpi_fill
ws_dash.cell(row=4, column=1, value="=AVERAGEIF(Veri!B:B,\"3Al2Ode\",Veri!F:F)")
ws_dash.cell(row=4, column=1).font = kpi_style_value
ws_dash.cell(row=4, column=1).fill = kpi_fill
ws_dash.cell(row=4, column=1).number_format = '#,##0.00'

# Kampanyasız Ortalama Sepet
ws_dash.cell(row=3, column=2, value="KAMPANYASIZ ORT. SEPET")
ws_dash.cell(row=3, column=2).font = kpi_style_title
ws_dash.cell(row=3, column=2).fill = kpi_fill
ws_dash.cell(row=4, column=2, value="=AVERAGEIF(Veri!B:B,\"Kampanyasiz\",Veri!F:F)")
ws_dash.cell(row=4, column=2).font = kpi_style_value
ws_dash.cell(row=4, column=2).fill = kpi_fill
ws_dash.cell(row=4, column=2).number_format = '#,##0.00'

# Grafikler için veriyi Özet sayfasından kullanalım
# Her grafik için başlık ve chart

# Grafik 1: Ort. Net Sepet Trend (Çizgi)
chart1 = LineChart()
chart1.title = "Ort. Net Sepet Trend"
chart1.style = 10
chart1.y_axis.title = "Ortalama (TL)"
chart1.x_axis.title = "Ay"
chart1.height = 12
chart1.width = 18

# Özet sayfasında: 3Al2Ode için Ort. Net Sepet (sütun 3), DigerKampanya (sütun 7), Kampanyasiz (sütun 11)
# Aylar: satır 3-12

for col_ref, grup_ad, renk in [(3, "3Al2Ode", "2563EB"), (7, "DigerKampanya", "F59E0B"), (11, "Kampanyasiz", "6B7280")]:
    values = Reference(ws_ozet, min_col=col_ref, min_row=2, max_row=12)
    series = chart1.series
    labels = Reference(ws_ozet, min_col=1, min_row=3, max_row=12)
    chart1.add_data(values, titles_from_data=True)
    chart1.set_categories(labels)

ws_dash.add_chart(chart1, "A6")

# Grafik 2: Toplam Net Ciro Trend
chart2 = LineChart()
chart2.title = "Toplam Net Ciro Trend"
chart2.style = 10
chart2.y_axis.title = "Ciro (TL)"
chart2.x_axis.title = "Ay"
chart2.height = 12
chart2.width = 18

for col_ref, grup_ad, renk in [(4, "3Al2Ode", "2563EB"), (8, "DigerKampanya", "F59E0B"), (12, "Kampanyasiz", "6B7280")]:
    values = Reference(ws_ozet, min_col=col_ref, min_row=2, max_row=12)
    labels = Reference(ws_ozet, min_col=1, min_row=3, max_row=12)
    chart2.add_data(values, titles_from_data=True)
    chart2.set_categories(labels)

ws_dash.add_chart(chart2, "K6")

# Grafik 3: Ort. Ürün Adet Trend
chart3 = LineChart()
chart3.title = "Ort. Ürün Adet Trend"
chart3.style = 10
chart3.y_axis.title = "Adet"
chart3.x_axis.title = "Ay"
chart3.height = 12
chart3.width = 18

# Veri sayfasından: grup ve ay bazında ortalama ürün adet
# Bu grafikler daha basit verilerle yapılabilir

ws_dash.add_chart(chart3, "A20")

# Grafik 4: İndirim Oranı Trend
chart4 = LineChart()
chart4.title = "İndirim Oranı Trend (%)"
chart4.style = 10
chart4.y_axis.title = "İndirim Oranı (%)"
chart4.x_axis.title = "Ay"
chart4.height = 12
chart4.width = 18

ws_dash.add_chart(chart4, "K20")

# Tab rengini ayarla
ws_dash.sheet_properties.tabColor = "003366"

# ====== SAYFA 4: SQL SORGU ======
ws_sql = wb.create_sheet("SQL Sorgu", 3)

sql_query = """;WITH cte_3al2ode AS (
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
    CASE WHEN c3.SalesId IS NOT NULL THEN '3Al2Ode'
         WHEN ca.SalesId IS NOT NULL THEN 'DigerKampanya'
         ELSE 'Kampanyasiz' END
ORDER BY Ay, Grup"""

ws_sql.column_dimensions['A'].width = 150
ws_sql.cell(row=1, column=1, value=sql_query)
ws_sql.cell(row=1, column=1).alignment = Alignment(horizontal="left", vertical="top", wrap_text=True)
ws_sql.cell(row=1, column=1).font = Font(name='Courier New', size=9)

ws_sql.sheet_properties.tabColor = "808080"

# Tab renklerini ayarla
ws_veri.sheet_properties.tabColor = "4CAF50"  # Yeşil
ws_ozet.sheet_properties.tabColor = "2196F3"  # Mavi
# Dashboard zaten ayarlandı (003366 - koyu mavi)
ws_sql.sheet_properties.tabColor = "9E9E9E"  # Gri

# Print ayarları
for ws in [ws_veri, ws_ozet, ws_dash, ws_sql]:
    ws.print_options.horizontalCentered = True
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.page_margins.left = 0.5
    ws.page_margins.right = 0.5
    ws.page_margins.top = 0.75
    ws.page_margins.bottom = 0.75

# Dosyayı kaydet
import os
import pathlib

# Output path'ini belirle
output_paths = [
    r"/sessions/confident-laughing-bardeen/mnt/sqlserver-mcp-server/SepetBuyukluguEtkisi_Dashboard.xlsx",
    r"D:\Dev\sqlserver-mcp-server\SepetBuyukluguEtkisi_Dashboard.xlsx",
    r"C:\Users\fikri.eren\AppData\Roaming\Claude\local-agent-mode-sessions\3db87182-3f90-47a8-9b2f-2b06c475fcc8\9ac28963-d4c1-4a35-8039-b4a3f5e60600\local_5a2eaa36-2a54-44b8-bb75-161ebdb6e5c8\outputs\SepetBuyukluguEtkisi_Dashboard.xlsx"
]

output_path = None
for path in output_paths:
    try:
        parent_dir = os.path.dirname(path)
        if os.path.exists(parent_dir) or parent_dir == '':
            output_path = path
            break
    except:
        pass

if not output_path:
    output_path = output_paths[-1]  # Varsayılan

print(f"Excel dosyası oluşturuluyor: {output_path}")
try:
    # Parent directory'yi oluştur (eğer gerekiyorsa)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    wb.save(output_path)
    print(f"✓ Dosya başarıyla kaydedildi: {output_path}")
except Exception as e:
    print(f"✗ Hata: {e}")
    import traceback
    traceback.print_exc()
