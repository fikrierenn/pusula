#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sepet Büyüklüğü Etkisi — Etkileşimli Excel Dashboard
Dropdown ile mağaza seçimi → KPI + 6 grafik otomatik güncellenir.
Yapı:
  1. Veri         — 120 satır ham data (TÜMÜ + 3 mağaza)
  2. ChartVeri    — Dinamik formüller (dropdown'a bağlı AVERAGEIFS/SUMIFS)
  3. Dashboard    — Dropdown + KPI kartları + 6 grafik (ChartVeri referanslı)
  4. SQL Sorgu    — Power Query için hazır SQL
"""

import sys, os

try:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter, column_index_from_string
    from openpyxl.worksheet.table import Table, TableStyleInfo
    from openpyxl.chart import LineChart, BarChart, PieChart, Reference
    from openpyxl.chart.series import DataPoint
    from openpyxl.chart.label import DataLabelList
    from openpyxl.worksheet.datavalidation import DataValidation
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "openpyxl", "-q"])
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
    from openpyxl.utils import get_column_letter, column_index_from_string
    from openpyxl.worksheet.table import Table, TableStyleInfo
    from openpyxl.chart import LineChart, BarChart, PieChart, Reference
    from openpyxl.chart.series import DataPoint
    from openpyxl.chart.label import DataLabelList
    from openpyxl.worksheet.datavalidation import DataValidation

# ============================================================
# RENKLER
# ============================================================
MAVI = "2563EB"; TURUNCU = "F59E0B"; GRI_RENK = "6B7280"
KPI_BG = "0D2137"; BASLIK_YESIL = "2E7D32"; BEYAZ = "FFFFFF"
CHART_COLORS = [MAVI, TURUNCU, GRI_RENK]
ACIK_GRI = "F5F5F5"; KOYU_MAVI = "1E3A5F"

# ============================================================
# VERİ
# ============================================================
ALL_DATA = [
    ("TÜMÜ","2025-07","3Al2Ode",5313,1411.90,338.39,1073.51,7.1,24.0,7501427.13,1797859.02,5703568.11),
    ("TÜMÜ","2025-07","DigerKampanya",7940,604.25,127.82,476.43,3.8,21.2,4797728.47,1014875.83,3782852.64),
    ("TÜMÜ","2025-07","Kampanyasiz",9407,374.85,0,374.85,2.2,0,3526169.39,0,3526169.39),
    ("TÜMÜ","2025-08","3Al2Ode",16231,1640.68,380.62,1260.06,7.9,23.2,26629950.01,6177897.74,20452052.27),
    ("TÜMÜ","2025-08","DigerKampanya",23485,939.02,157.75,781.27,5.5,16.8,22052787.42,3704678.29,18348109.13),
    ("TÜMÜ","2025-08","Kampanyasiz",28652,436.60,0,436.60,2.4,0,12509517.40,0,12509517.40),
    ("TÜMÜ","2025-09","3Al2Ode",33930,1923.79,438.66,1485.13,8.5,22.8,65274122.97,14883570.57,50390552.40),
    ("TÜMÜ","2025-09","DigerKampanya",42360,1191.56,199.60,991.95,7.3,16.8,50474397.46,8455224.20,42019173.26),
    ("TÜMÜ","2025-09","Kampanyasiz",42189,527.15,0,527.15,2.9,0,22240070.08,0,22240070.08),
    ("TÜMÜ","2025-10","3Al2Ode",27865,1583.22,384.49,1198.73,7.3,24.3,44116376.28,10713719.82,33402656.46),
    ("TÜMÜ","2025-10","DigerKampanya",37391,701.43,122.31,579.13,4.5,17.4,26227227.24,4573110.30,21654116.94),
    ("TÜMÜ","2025-10","Kampanyasiz",40168,385.81,0,385.81,2.3,0,15497053.83,0,15497053.83),
    ("TÜMÜ","2025-11","3Al2Ode",22300,1494.93,363.58,1131.35,7.2,24.3,33337040.23,8107864.59,25229175.64),
    ("TÜMÜ","2025-11","DigerKampanya",33948,652.98,125.13,527.85,4.4,19.2,22167440.96,4247918.19,17919522.77),
    ("TÜMÜ","2025-11","Kampanyasiz",37982,366.85,0,366.85,2.3,0,13933840.45,0,13933840.45),
    ("TÜMÜ","2025-12","3Al2Ode",21692,1509.59,357.31,1152.28,7.0,23.7,32746018.18,7750731.82,24995286.36),
    ("TÜMÜ","2025-12","DigerKampanya",39289,728.24,144.99,583.25,4.4,19.9,28611744.84,5696521.71,22915223.13),
    ("TÜMÜ","2025-12","Kampanyasiz",41137,409.49,0,409.49,2.4,0,16845152.64,0,16845152.64),
    ("TÜMÜ","2026-01","3Al2Ode",25900,1582.14,376.81,1205.33,7.4,23.8,40977342.99,9759273.91,31218069.08),
    ("TÜMÜ","2026-01","DigerKampanya",42463,683.67,141.61,542.06,4.3,20.7,29030681.69,6013094.35,23017587.34),
    ("TÜMÜ","2026-01","Kampanyasiz",39075,409.59,0,409.59,2.3,0,16004580.41,0,16004580.41),
    ("TÜMÜ","2026-02","3Al2Ode",20602,1577.80,380.45,1197.34,7.0,24.1,32505734.74,7838083.51,24667651.23),
    ("TÜMÜ","2026-02","DigerKampanya",36909,694.20,146.15,548.05,4.3,21.1,25622218.50,5394406.53,20227811.97),
    ("TÜMÜ","2026-02","Kampanyasiz",33700,432.59,0,432.59,2.4,0,14578265.74,0,14578265.74),
    ("TÜMÜ","2026-03","3Al2Ode",20958,1613.42,393.21,1220.21,7.1,24.4,33814100.83,8240944.59,25573156.24),
    ("TÜMÜ","2026-03","DigerKampanya",41089,692.83,146.87,545.95,4.4,21.2,28467587.44,6034844.41,22432743.03),
    ("TÜMÜ","2026-03","Kampanyasiz",32812,439.46,0,439.46,2.3,0,14419463.48,0,14419463.48),
    ("TÜMÜ","2026-04","3Al2Ode",8488,1597.37,388.38,1208.99,7.1,24.3,13558517.40,3296591.17,10261926.23),
    ("TÜMÜ","2026-04","DigerKampanya",18098,680.11,144.92,535.19,4.4,21.3,12308657.18,2622799.32,9685857.86),
    ("TÜMÜ","2026-04","Kampanyasiz",14257,427.88,0,427.88,2.3,0,6100347.68,0,6100347.68),
    ("FSM Mağaza","2025-07","3Al2Ode",1053,1281.66,318.37,963.29,6.3,24.8,1349589.55,335245.91,1014343.64),
    ("FSM Mağaza","2025-07","DigerKampanya",1889,489.76,115.11,374.66,3.3,23.5,925160.42,217435.66,707724.76),
    ("FSM Mağaza","2025-07","Kampanyasiz",2401,299.67,0,299.67,2.0,0,719509.48,0,719509.48),
    ("FSM Mağaza","2025-08","3Al2Ode",4720,1482.22,359.31,1122.91,7.1,24.2,6996079.19,1695954.57,5300124.62),
    ("FSM Mağaza","2025-08","DigerKampanya",8226,714.51,139.64,574.87,4.5,19.5,5877574.53,1148671.63,4728902.90),
    ("FSM Mağaza","2025-08","Kampanyasiz",9914,313.71,0,313.71,2.2,0,3110092.15,0,3110092.15),
    ("FSM Mağaza","2025-09","3Al2Ode",11596,1792.83,412.76,1380.07,7.7,23.0,20789649.05,4786372.90,16003276.15),
    ("FSM Mağaza","2025-09","DigerKampanya",14880,1003.91,169.71,834.19,6.4,16.9,14938152.70,2525339.59,12412813.11),
    ("FSM Mağaza","2025-09","Kampanyasiz",16512,480.65,0,480.65,2.6,0,7936414.57,0,7936414.57),
    ("FSM Mağaza","2025-10","3Al2Ode",8845,1514.19,368.48,1145.71,6.9,24.3,13393041.58,3259201.96,10133839.62),
    ("FSM Mağaza","2025-10","DigerKampanya",13107,609.30,115.43,493.86,4.1,18.9,7986033.14,1512949.17,6473083.97),
    ("FSM Mağaza","2025-10","Kampanyasiz",15508,379.35,0,379.35,2.2,0,5882971.68,0,5882971.68),
    ("FSM Mağaza","2025-11","3Al2Ode",6751,1388.82,342.88,1045.94,6.5,24.7,9375907.40,2314795.55,7061111.85),
    ("FSM Mağaza","2025-11","DigerKampanya",12286,565.66,116.92,448.73,4.0,20.7,6949665.35,1436519.75,5513145.60),
    ("FSM Mağaza","2025-11","Kampanyasiz",13881,347.11,0,347.11,2.2,0,4818217.90,0,4818217.90),
    ("FSM Mağaza","2025-12","3Al2Ode",6618,1417.13,348.54,1068.59,6.3,24.6,9378582.18,2306662.27,7071919.91),
    ("FSM Mağaza","2025-12","DigerKampanya",13633,649.19,145.76,503.43,3.9,22.5,8850460.01,1987211.20,6863248.81),
    ("FSM Mağaza","2025-12","Kampanyasiz",15172,353.96,0,353.96,2.2,0,5370309.37,0,5370309.37),
    ("FSM Mağaza","2026-01","3Al2Ode",7596,1437.21,352.97,1084.24,6.7,24.6,10917017.11,2681148.56,8235868.55),
    ("FSM Mağaza","2026-01","DigerKampanya",14516,624.16,141.93,482.23,3.9,22.7,9060270.77,2060208.79,7000061.98),
    ("FSM Mağaza","2026-01","Kampanyasiz",14022,345.64,0,345.64,2.1,0,4846576.89,0,4846576.89),
    ("FSM Mağaza","2026-02","3Al2Ode",6483,1479.68,362.96,1116.73,6.5,24.5,9592782.31,2353047.90,7239734.41),
    ("FSM Mağaza","2026-02","DigerKampanya",13632,637.29,147.67,489.62,3.9,23.2,8687559.39,2013078.12,6674481.27),
    ("FSM Mağaza","2026-02","Kampanyasiz",12799,366.01,0,366.01,2.1,0,4684563.88,0,4684563.88),
    ("FSM Mağaza","2026-03","3Al2Ode",6298,1476.38,371.17,1105.21,6.4,25.1,9298266.76,2337628.99,6960637.77),
    ("FSM Mağaza","2026-03","DigerKampanya",14640,623.17,144.89,478.28,4.0,23.3,9123175.03,2121204.14,7001970.89),
    ("FSM Mağaza","2026-03","Kampanyasiz",11863,381.39,0,381.39,2.1,0,4524390.12,0,4524390.12),
    ("FSM Mağaza","2026-04","3Al2Ode",2478,1535.38,388.19,1147.19,6.4,25.3,3804675.83,961940.45,2842735.38),
    ("FSM Mağaza","2026-04","DigerKampanya",5854,620.85,143.41,477.44,4.0,23.1,3634457.23,839537.23,2794920.00),
    ("FSM Mağaza","2026-04","Kampanyasiz",5061,374.61,0,374.61,2.1,0,1895879.56,0,1895879.56),
    ("IST YOLU MGZ","2025-07","3Al2Ode",2245,1459.39,351.66,1107.73,7.6,24.1,3276328.76,789478.08,2486850.68),
    ("IST YOLU MGZ","2025-07","DigerKampanya",3730,630.94,131.58,499.36,3.9,20.9,2353393.63,490790.72,1862602.91),
    ("IST YOLU MGZ","2025-07","Kampanyasiz",3536,402.24,0,402.24,2.2,0,1422328.92,0,1422328.92),
    ("IST YOLU MGZ","2025-08","3Al2Ode",4106,1787.59,396.46,1391.13,8.8,22.2,7339850.56,1627856.92,5711993.64),
    ("IST YOLU MGZ","2025-08","DigerKampanya",6292,1227.01,185.26,1041.76,6.1,15.1,7720370.60,1165638.90,6554731.70),
    ("IST YOLU MGZ","2025-08","Kampanyasiz",6570,645.73,0,645.73,2.7,0,4242449.78,0,4242449.78),
    ("IST YOLU MGZ","2025-09","3Al2Ode",8448,2078.73,469.40,1609.34,9.3,22.6,17561129.89,3965449.53,13595680.36),
    ("IST YOLU MGZ","2025-09","DigerKampanya",11094,1413.74,229.45,1184.28,8.6,16.2,15683993.46,2545563.70,13138429.76),
    ("IST YOLU MGZ","2025-09","Kampanyasiz",9375,635.60,0,635.60,3.0,0,5958724.90,0,5958724.90),
    ("IST YOLU MGZ","2025-10","3Al2Ode",7184,1627.73,393.69,1234.04,7.7,24.2,11693639.09,2828277.03,8865362.06),
    ("IST YOLU MGZ","2025-10","DigerKampanya",9653,737.57,131.10,606.47,4.6,17.8,7119775.68,1265509.23,5854266.45),
    ("IST YOLU MGZ","2025-10","Kampanyasiz",9053,392.11,0,392.11,2.3,0,3549768.62,0,3549768.62),
    ("IST YOLU MGZ","2025-11","3Al2Ode",5846,1550.10,377.78,1172.31,7.8,24.4,9061859.39,2208517.71,6853341.68),
    ("IST YOLU MGZ","2025-11","DigerKampanya",9048,673.91,132.04,541.87,4.4,19.6,6097545.59,1194690.66,4902854.93),
    ("IST YOLU MGZ","2025-11","Kampanyasiz",9026,336.60,0,336.60,2.3,0,3038112.58,0,3038112.58),
    ("IST YOLU MGZ","2025-12","3Al2Ode",5206,1569.66,368.24,1201.42,7.6,23.5,8171650.06,1917033.13,6254616.93),
    ("IST YOLU MGZ","2025-12","DigerKampanya",9916,726.42,143.91,582.50,4.5,19.8,7203154.82,1427037.89,5776116.93),
    ("IST YOLU MGZ","2025-12","Kampanyasiz",8873,398.55,0,398.55,2.4,0,3536347.28,0,3536347.28),
    ("IST YOLU MGZ","2026-01","3Al2Ode",7519,1626.63,390.15,1236.49,8.0,24.0,12230642.82,2933505.02,9297137.80),
    ("IST YOLU MGZ","2026-01","DigerKampanya",12356,662.04,143.86,518.18,4.4,21.7,8180194.04,1777523.72,6402670.32),
    ("IST YOLU MGZ","2026-01","Kampanyasiz",9777,376.59,0,376.59,2.2,0,3681917.03,0,3681917.03),
    ("IST YOLU MGZ","2026-02","3Al2Ode",5144,1660.04,406.90,1253.14,7.6,24.5,8539271.20,2093103.21,6446167.99),
    ("IST YOLU MGZ","2026-02","DigerKampanya",9990,703.52,146.14,557.38,4.5,20.8,7028196.88,1459976.39,5568220.49),
    ("IST YOLU MGZ","2026-02","Kampanyasiz",7487,438.34,0,438.34,2.4,0,3281876.15,0,3281876.15),
    ("IST YOLU MGZ","2026-03","3Al2Ode",5573,1688.14,417.30,1270.84,7.7,24.7,9408015.49,2325621.42,7082394.07),
    ("IST YOLU MGZ","2026-03","DigerKampanya",11349,697.68,148.42,549.27,4.5,21.3,7917990.61,1684378.25,6233612.36),
    ("IST YOLU MGZ","2026-03","Kampanyasiz",7469,430.88,0,430.88,2.2,0,3218239.75,0,3218239.75),
    ("IST YOLU MGZ","2026-04","3Al2Ode",2346,1565.75,382.66,1183.09,7.6,24.4,3673242.11,897718.11,2775524.00),
    ("IST YOLU MGZ","2026-04","DigerKampanya",5662,661.11,142.06,519.05,4.6,21.5,3743218.29,804371.33,2938846.96),
    ("IST YOLU MGZ","2026-04","Kampanyasiz",3259,393.40,0,393.40,2.2,0,1282106.29,0,1282106.29),
    ("ÖZLÜCE","2025-07","3Al2Ode",2015,1427.05,334.06,1092.99,7.0,23.4,2875508.82,673135.03,2202373.79),
    ("ÖZLÜCE","2025-07","DigerKampanya",2321,654.53,132.12,522.41,4.1,20.2,1519174.42,306649.45,1212524.97),
    ("ÖZLÜCE","2025-07","Kampanyasiz",3470,398.94,0,398.94,2.2,0,1384330.99,0,1384330.99),
    ("ÖZLÜCE","2025-08","3Al2Ode",7405,1660.23,385.43,1274.81,8.0,23.2,12294020.26,2854086.25,9439934.01),
    ("ÖZLÜCE","2025-08","DigerKampanya",8967,942.88,155.05,787.83,5.9,16.4,8454842.29,1390367.76,7064474.53),
    ("ÖZLÜCE","2025-08","Kampanyasiz",12168,423.81,0,423.81,2.5,0,5156975.47,0,5156975.47),
    ("ÖZLÜCE","2025-09","3Al2Ode",13886,1938.88,441.58,1497.31,8.6,22.8,26923344.03,6131748.14,20791595.89),
    ("ÖZLÜCE","2025-09","DigerKampanya",16386,1211.54,206.54,1005.00,7.1,17.0,19852251.30,3384320.91,16467930.39),
    ("ÖZLÜCE","2025-09","Kampanyasiz",16302,511.90,0,511.90,3.0,0,8344930.61,0,8344930.61),
    ("ÖZLÜCE","2025-10","3Al2Ode",11836,1607.78,390.86,1216.92,7.4,24.3,19029695.61,4626240.83,14403454.78),
    ("ÖZLÜCE","2025-10","DigerKampanya",14631,760.13,122.66,637.47,4.8,16.1,11121418.42,1794651.90,9326766.52),
    ("ÖZLÜCE","2025-10","Kampanyasiz",15607,388.56,0,388.56,2.5,0,6064313.53,0,6064313.53),
    ("ÖZLÜCE","2025-11","3Al2Ode",9703,1535.53,369.43,1166.11,7.2,24.1,14899273.44,3584551.33,11314722.11),
    ("ÖZLÜCE","2025-11","DigerKampanya",12614,723.02,128.17,594.86,4.8,17.7,9120230.02,1616707.78,7503522.24),
    ("ÖZLÜCE","2025-11","Kampanyasiz",15075,403.15,0,403.15,2.5,0,6077509.97,0,6077509.97),
    ("ÖZLÜCE","2025-12","3Al2Ode",9868,1539.91,357.42,1182.48,7.1,23.2,15195785.94,3527036.42,11668749.52),
    ("ÖZLÜCE","2025-12","DigerKampanya",15740,797.85,145.00,652.85,4.8,18.2,12558130.01,2282272.62,10275857.39),
    ("ÖZLÜCE","2025-12","Kampanyasiz",17092,464.46,0,464.46,2.7,0,7938495.99,0,7938495.99),
    ("ÖZLÜCE","2026-01","3Al2Ode",10785,1653.19,384.29,1268.90,7.5,23.2,17829683.06,4144620.33,13685062.73),
    ("ÖZLÜCE","2026-01","DigerKampanya",15591,756.22,139.53,616.69,4.7,18.5,11790216.88,2175361.84,9614855.04),
    ("ÖZLÜCE","2026-01","Kampanyasiz",15276,489.40,0,489.40,2.5,0,7476086.49,0,7476086.49),
    ("ÖZLÜCE","2026-02","3Al2Ode",8975,1601.52,377.93,1223.59,7.1,23.6,14373681.23,3391932.40,10981748.83),
    ("ÖZLÜCE","2026-02","DigerKampanya",13287,745.58,144.60,600.97,4.6,19.4,9906462.23,1921352.02,7985110.21),
    ("ÖZLÜCE","2026-02","Kampanyasiz",13414,492.90,0,492.90,2.6,0,6611825.71,0,6611825.71),
    ("ÖZLÜCE","2026-03","3Al2Ode",9087,1662.57,393.72,1268.86,7.3,23.7,15107818.58,3577694.18,11530124.40),
    ("ÖZLÜCE","2026-03","DigerKampanya",15100,756.72,147.63,609.08,4.7,19.5,11426421.80,2229262.02,9197159.78),
    ("ÖZLÜCE","2026-03","Kampanyasiz",13480,495.31,0,495.31,2.5,0,6676833.61,0,6676833.61),
    ("ÖZLÜCE","2026-04","3Al2Ode",3675,1659.74,392.25,1267.49,7.1,23.6,6099546.56,1441506.13,4658040.43),
    ("ÖZLÜCE","2026-04","DigerKampanya",6605,749.05,148.61,600.43,4.7,19.8,4947459.95,981597.86,3965862.09),
    ("ÖZLÜCE","2026-04","Kampanyasiz",5957,492.63,0,492.63,2.5,0,2934626.53,0,2934626.53),
]

HEADERS = ["Magaza","Ay","Grup","FisSayisi","OrtBrutSepet","OrtIndirimTutar",
           "OrtNetSepet","OrtUrunAdet","IndirimOrani","ToplamBrutCiro",
           "ToplamIndirim","ToplamNetCiro"]

AYLAR = ["2025-07","2025-08","2025-09","2025-10","2025-11","2025-12",
         "2026-01","2026-02","2026-03","2026-04"]
GRUPLAR = ["3Al2Ode","DigerKampanya","Kampanyasiz"]
GRUP_LABELS = ["3Al2Öde","Diğer Kampanya","Kampanyasız"]

# ============================================================
wb = Workbook()
wb.remove(wb.active)

# ============================================================
# SAYFA 1: VERİ (ham data — 120 satır)
# ============================================================
ws_veri = wb.create_sheet("Veri", 0)
ws_veri.sheet_properties.tabColor = "4CAF50"

for ci, h in enumerate(HEADERS, 1):
    c = ws_veri.cell(row=1, column=ci, value=h)
    c.font = Font(bold=True, color=BEYAZ, size=11)
    c.fill = PatternFill(start_color=BASLIK_YESIL, end_color=BASLIK_YESIL, fill_type="solid")
    c.alignment = Alignment(horizontal="center", vertical="center")

for ri, row in enumerate(ALL_DATA, 2):
    for ci, val in enumerate(row, 1):
        c = ws_veri.cell(row=ri, column=ci, value=val)
        if ci == 4: c.number_format = '#,##0'
        elif ci in (5,6,7,10,11,12): c.number_format = '#,##0.00'
        elif ci == 8: c.number_format = '0.0'
        elif ci == 9: c.number_format = '0.0'

last_veri = len(ALL_DATA) + 1
ws_veri.column_dimensions['A'].width = 15
ws_veri.column_dimensions['B'].width = 11
ws_veri.column_dimensions['C'].width = 16
for ci in range(4,13):
    ws_veri.column_dimensions[get_column_letter(ci)].width = 16
ws_veri.freeze_panes = "A2"

# Veri aralığı referans sabitleri
VR = f"Veri!$A$2:$A${last_veri}"  # Magaza
VB = f"Veri!$B$2:$B${last_veri}"  # Ay
VC = f"Veri!$C$2:$C${last_veri}"  # Grup
VD = f"Veri!$D$2:$D${last_veri}"  # FisSayisi
VE = f"Veri!$E$2:$E${last_veri}"  # OrtBrutSepet
VG = f"Veri!$G$2:$G${last_veri}"  # OrtNetSepet
VH = f"Veri!$H$2:$H${last_veri}"  # OrtUrunAdet
VI = f"Veri!$I$2:$I${last_veri}"  # IndirimOrani
VJ = f"Veri!$J$2:$J${last_veri}"  # ToplamBrutCiro
VK = f"Veri!$K$2:$K${last_veri}"  # ToplamIndirim
VL = f"Veri!$L$2:$L${last_veri}"  # ToplamNetCiro

# ============================================================
# SAYFA 2: ChartVeri (dropdown'a bağlı dinamik formüller)
# Grafiklerin veri kaynağı — dropdown değişince burası güncellenir
# ============================================================
ws_cv = wb.create_sheet("ChartVeri", 1)
ws_cv.sheet_properties.tabColor = "90CAF9"

# Dropdown hücresi referansı: Dashboard!$C$2
SEL = "Dashboard!$C$2"  # Seçili mağaza

# Başlıklar
cv_headers = ["Ay",
    "3Al2Öde Ort.Net","Diğer K. Ort.Net","Kampanyasız Ort.Net",
    "3Al2Öde Top.Net","Diğer K. Top.Net","Kampanyasız Top.Net",
    "3Al2Öde Fiş","Diğer K. Fiş","Kampanyasız Fiş",
    "3Al2Öde Ürt.Adet","Diğer K. Ürt.Adet","Kampanyasız Ürt.Adet",
    "3Al2Öde İnd%","Diğer K. İnd%","Kampanyasız İnd%",
    "3Al2Öde Ort.Brüt","Diğer K. Ort.Brüt","Kampanyasız Ort.Brüt"]

hdr_fill = PatternFill(start_color="1565C0", end_color="1565C0", fill_type="solid")
for ci, h in enumerate(cv_headers, 1):
    c = ws_cv.cell(row=1, column=ci, value=h)
    c.font = Font(bold=True, color=BEYAZ, size=9)
    c.fill = hdr_fill
    c.alignment = Alignment(horizontal="center", wrap_text=True)

# Formüller — her ay × her metrik × her grup
for ri, ay in enumerate(AYLAR, 2):
    ws_cv.cell(row=ri, column=1, value=ay).font = Font(bold=True)

    for gi, grup in enumerate(GRUPLAR):
        # AVERAGEIFS(değer, magaza_col, seçim, ay_col, ay, grup_col, grup)
        # OrtNetSepet (col 2,3,4)
        ws_cv.cell(row=ri, column=2+gi,
            value=f'=AVERAGEIFS({VG},{VR},{SEL},{VB},A{ri},{VC},"{grup}")').number_format = '#,##0.00'
        # ToplamNetCiro (col 5,6,7)
        ws_cv.cell(row=ri, column=5+gi,
            value=f'=SUMIFS({VL},{VR},{SEL},{VB},A{ri},{VC},"{grup}")').number_format = '#,##0'
        # FisSayisi (col 8,9,10)
        ws_cv.cell(row=ri, column=8+gi,
            value=f'=SUMIFS({VD},{VR},{SEL},{VB},A{ri},{VC},"{grup}")').number_format = '#,##0'
        # OrtUrunAdet (col 11,12,13)
        ws_cv.cell(row=ri, column=11+gi,
            value=f'=AVERAGEIFS({VH},{VR},{SEL},{VB},A{ri},{VC},"{grup}")').number_format = '0.0'
        # IndirimOrani (col 14,15,16)
        ws_cv.cell(row=ri, column=14+gi,
            value=f'=IFERROR(AVERAGEIFS({VI},{VR},{SEL},{VB},A{ri},{VC},"{grup}"),0)').number_format = '0.0'
        # OrtBrutSepet (col 17,18,19)
        ws_cv.cell(row=ri, column=17+gi,
            value=f'=AVERAGEIFS({VE},{VR},{SEL},{VB},A{ri},{VC},"{grup}")').number_format = '#,##0.00'

# TOPLAM satırı
tr = len(AYLAR) + 2
ws_cv.cell(row=tr, column=1, value="TOPLAM/ORT").font = Font(bold=True)
t_fill = PatternFill(start_color="E3F2FD", end_color="E3F2FD", fill_type="solid")
for ci in range(1, 20):
    ws_cv.cell(row=tr, column=ci).fill = t_fill

for gi, grup in enumerate(GRUPLAR):
    # OrtNet → AVERAGE
    cl = get_column_letter(2+gi)
    ws_cv.cell(row=tr, column=2+gi, value=f'=AVERAGE({cl}2:{cl}{tr-1})').number_format = '#,##0.00'
    # ToplamNet → SUM
    cl = get_column_letter(5+gi)
    ws_cv.cell(row=tr, column=5+gi, value=f'=SUM({cl}2:{cl}{tr-1})').number_format = '#,##0'
    # Fiş → SUM
    cl = get_column_letter(8+gi)
    ws_cv.cell(row=tr, column=8+gi, value=f'=SUM({cl}2:{cl}{tr-1})').number_format = '#,##0'
    # UrunAdet → AVERAGE
    cl = get_column_letter(11+gi)
    ws_cv.cell(row=tr, column=11+gi, value=f'=AVERAGE({cl}2:{cl}{tr-1})').number_format = '0.0'
    # IndOranı → AVERAGE
    cl = get_column_letter(14+gi)
    ws_cv.cell(row=tr, column=14+gi, value=f'=AVERAGE({cl}2:{cl}{tr-1})').number_format = '0.0'
    # OrtBrut → AVERAGE
    cl = get_column_letter(17+gi)
    ws_cv.cell(row=tr, column=17+gi, value=f'=AVERAGE({cl}2:{cl}{tr-1})').number_format = '#,##0.00'

# Pie verisi (son ay)
pie_r = tr + 2
ws_cv.cell(row=pie_r, column=1, value="Son Ay Net Ciro").font = Font(bold=True, size=9, color="999999")
for gi, label in enumerate(GRUP_LABELS):
    ws_cv.cell(row=pie_r+1+gi, column=1, value=label)
    # Son ay = row tr-1 (2026-04), toplam net ciro = col 5+gi
    src_col = get_column_letter(5+gi)
    ws_cv.cell(row=pie_r+1+gi, column=2,
        value=f'={src_col}{tr-1}').number_format = '#,##0'

ws_cv.column_dimensions['A'].width = 11
for ci in range(2, 20):
    ws_cv.column_dimensions[get_column_letter(ci)].width = 14

# ============================================================
# SAYFA 3: DASHBOARD
# ============================================================
ws_d = wb.create_sheet("Dashboard", 2)
ws_d.sheet_properties.tabColor = KPI_BG

for cl_letter in 'ABCDEFGHIJKLMNOPQR':
    ws_d.column_dimensions[cl_letter].width = 12
ws_d.row_dimensions[1].height = 8  # üst boşluk

# ----- DROPDOWN (Mağaza Seçici) -----
kpi_fill = PatternFill(start_color=KPI_BG, end_color=KPI_BG, fill_type="solid")
sel_fill = PatternFill(start_color="1565C0", end_color="1565C0", fill_type="solid")

# Row 2: "MAĞAZA SEÇ:" label + dropdown
ws_d.merge_cells("A2:B2")
lbl = ws_d.cell(row=2, column=1, value="MAĞAZA SEÇ:")
lbl.font = Font(bold=True, color=BEYAZ, size=14)
lbl.fill = sel_fill
lbl.alignment = Alignment(horizontal="right", vertical="center")
ws_d.cell(row=2, column=2).fill = sel_fill

ws_d.merge_cells("C2:E2")
dd = ws_d.cell(row=2, column=3, value="TÜMÜ")
dd.font = Font(bold=True, color="1565C0", size=16)
dd.fill = PatternFill(start_color="E3F2FD", end_color="E3F2FD", fill_type="solid")
dd.alignment = Alignment(horizontal="center", vertical="center")
ws_d.cell(row=2, column=4).fill = PatternFill(start_color="E3F2FD", end_color="E3F2FD", fill_type="solid")
ws_d.cell(row=2, column=5).fill = PatternFill(start_color="E3F2FD", end_color="E3F2FD", fill_type="solid")

# Border for dropdown
from openpyxl.styles import Border, Side
thick_border = Border(
    left=Side(style='medium', color="1565C0"),
    right=Side(style='medium', color="1565C0"),
    top=Side(style='medium', color="1565C0"),
    bottom=Side(style='medium', color="1565C0"))
for ci in range(3, 6):
    ws_d.cell(row=2, column=ci).border = thick_border

# Data Validation dropdown
dv = DataValidation(
    type="list",
    formula1='"TÜMÜ,FSM Mağaza,IST YOLU MGZ,ÖZLÜCE"',
    allow_blank=False
)
dv.prompt = "Mağaza seçin"
dv.promptTitle = "Mağaza Filtresi"
dv.error = "Listeden seçim yapın"
dv.errorTitle = "Geçersiz seçim"
ws_d.add_data_validation(dv)
dv.add("C2")

# Row 2 rest: dark background
for ci in range(6, 19):
    ws_d.cell(row=2, column=ci).fill = kpi_fill
for ci in range(1, 19):
    ws_d.cell(row=1, column=ci).fill = kpi_fill

# ----- KPI KARTLARI (Row 4-6) -----
kpi_t_font = Font(name='Calibri', size=9, bold=False, color=BEYAZ)
kpi_v_font = Font(name='Calibri', size=16, bold=True, color=BEYAZ)
kpi_center = Alignment(horizontal="center", vertical="center")

# KPI formüller — hepsi dropdown'a bağlı (SEL = Dashboard!$C$2)
kpis = [
    ("TOPLAM FİŞ SAYISI",
     f'=SUMPRODUCT(({VR}={SEL})*({VD}))',
     '#,##0', 'A', 'C'),
    ("TOPLAM BRÜT CİRO (₺)",
     f'=SUMPRODUCT(({VR}={SEL})*({VJ}))',
     '#,##0', 'D', 'F'),
    ("TOPLAM NET CİRO (₺)",
     f'=SUMPRODUCT(({VR}={SEL})*({VL}))',
     '#,##0', 'G', 'I'),
    ("GENEL İNDİRİM ORANI",
     f'=TEXT(IFERROR(SUMPRODUCT(({VR}={SEL})*({VK}))/SUMPRODUCT(({VR}={SEL})*({VJ}))*100,0),"0.0")&"%"',
     '@', 'J', 'L'),
    ("3AL2ÖDE ORT. NET SEPET (₺)",
     f'=AVERAGEIFS({VG},{VR},{SEL},{VC},"3Al2Ode")',
     '#,##0.00', 'M', 'O'),
    ("KAMPANYASIZ ORT. NET SEPET (₺)",
     f'=AVERAGEIFS({VG},{VR},{SEL},{VC},"Kampanyasiz")',
     '#,##0.00', 'P', 'R'),
]

# Row 3: spacing
for ci in range(1, 19):
    ws_d.cell(row=3, column=ci).fill = kpi_fill

for title, formula, fmt, cs, ce in kpis:
    c1 = column_index_from_string(cs)
    c2 = column_index_from_string(ce)
    # Title row 4
    ws_d.merge_cells(start_row=4, start_column=c1, end_row=4, end_column=c2)
    tc = ws_d.cell(row=4, column=c1, value=title)
    tc.font = kpi_t_font; tc.fill = kpi_fill; tc.alignment = kpi_center
    for ci in range(c1, c2+1):
        ws_d.cell(row=4, column=ci).fill = kpi_fill
    # Value row 5-6
    ws_d.merge_cells(start_row=5, start_column=c1, end_row=6, end_column=c2)
    vc = ws_d.cell(row=5, column=c1, value=formula)
    vc.font = kpi_v_font; vc.fill = kpi_fill; vc.alignment = kpi_center
    vc.number_format = fmt
    for ri in range(5, 7):
        for ci in range(c1, c2+1):
            ws_d.cell(row=ri, column=ci).fill = kpi_fill

# Row 7: spacing
for ci in range(1, 19):
    ws_d.cell(row=7, column=ci).fill = kpi_fill

# ----- VURUCU RAKAMLAR (Row 8-11) -----
vurucu_fill = PatternFill(start_color="1B5E20", end_color="1B5E20", fill_type="solid")  # koyu yeşil
vurucu_title_font = Font(name='Calibri', size=9, bold=False, color="A5D6A7")
vurucu_value_font = Font(name='Calibri', size=20, bold=True, color="69F0AE")
vurucu_sub_font = Font(name='Calibri', size=9, bold=False, color="C8E6C9")

# Row 8: arka plan
for ci in range(1, 19):
    for ri in range(8, 13):
        ws_d.cell(row=ri, column=ci).fill = vurucu_fill

# VURUCU 1: Sepet Lift Oranı (3Al2Öde vs Kampanyasız ort. net sepet farkı %)
ws_d.merge_cells("A8:C8")
ws_d.cell(row=8, column=1, value="SEPET LİFT ORANI").font = vurucu_title_font
ws_d.cell(row=8, column=1).alignment = kpi_center
ws_d.merge_cells("A9:C10")
# Formül: (3Al2Ode OrtNet - Kampanyasız OrtNet) / Kampanyasız OrtNet * 100
lift_f = (f'=TEXT(IFERROR((AVERAGEIFS({VG},{VR},{SEL},{VC},"3Al2Ode")'
          f'-AVERAGEIFS({VG},{VR},{SEL},{VC},"Kampanyasiz"))'
          f'/AVERAGEIFS({VG},{VR},{SEL},{VC},"Kampanyasiz")*100,0),"0")&"%"')
ws_d.cell(row=9, column=1, value=lift_f).font = Font(name='Calibri', size=28, bold=True, color="69F0AE")
ws_d.cell(row=9, column=1).alignment = kpi_center
ws_d.merge_cells("A11:C11")
ws_d.cell(row=11, column=1, value="3Al2Öde sepeti kampanyasıza göre büyütüyor").font = vurucu_sub_font
ws_d.cell(row=11, column=1).alignment = kpi_center

# VURUCU 2: Sepet Farkı (₺)
ws_d.merge_cells("D8:F8")
ws_d.cell(row=8, column=4, value="SEPET FARKI (₺)").font = vurucu_title_font
ws_d.cell(row=8, column=4).alignment = kpi_center
ws_d.merge_cells("D9:F10")
fark_f = (f'=AVERAGEIFS({VG},{VR},{SEL},{VC},"3Al2Ode")'
          f'-AVERAGEIFS({VG},{VR},{SEL},{VC},"Kampanyasiz")')
ws_d.cell(row=9, column=4, value=fark_f).font = Font(name='Calibri', size=28, bold=True, color="69F0AE")
ws_d.cell(row=9, column=4).alignment = kpi_center
ws_d.cell(row=9, column=4).number_format = '+#,##0;-#,##0'
ws_d.merge_cells("D11:F11")
ws_d.cell(row=11, column=4, value="3Al2Öde — Kampanyasız ort. net sepet farkı").font = vurucu_sub_font
ws_d.cell(row=11, column=4).alignment = kpi_center

# VURUCU 3: Ek Ürün Etkisi
ws_d.merge_cells("G8:I8")
ws_d.cell(row=8, column=7, value="EK ÜRÜN ETKİSİ").font = vurucu_title_font
ws_d.cell(row=8, column=7).alignment = kpi_center
ws_d.merge_cells("G9:I10")
urun_f = (f'=TEXT(AVERAGEIFS({VH},{VR},{SEL},{VC},"3Al2Ode")'
           f'-AVERAGEIFS({VH},{VR},{SEL},{VC},"Kampanyasiz"),"0.0")&" adet"')
ws_d.cell(row=9, column=7, value=urun_f).font = Font(name='Calibri', size=28, bold=True, color="69F0AE")
ws_d.cell(row=9, column=7).alignment = kpi_center
ws_d.merge_cells("G11:I11")
ws_d.cell(row=11, column=7, value="3Al2Öde ile sepete eklenen ekstra ürün").font = vurucu_sub_font
ws_d.cell(row=11, column=7).alignment = kpi_center

# VURUCU 4: 3Al2Öde Toplam Net Ciro Payı (%)
ws_d.merge_cells("J8:L8")
ws_d.cell(row=8, column=10, value="3AL2ÖDE CİRO PAYI").font = vurucu_title_font
ws_d.cell(row=8, column=10).alignment = kpi_center
ws_d.merge_cells("J9:L10")
pay_f = (f'=TEXT(IFERROR(SUMPRODUCT(({VR}={SEL})*({VC}="3Al2Ode")*({VL}))'
         f'/SUMPRODUCT(({VR}={SEL})*({VL}))*100,0),"0.0")&"%"')
ws_d.cell(row=9, column=10, value=pay_f).font = Font(name='Calibri', size=28, bold=True, color="69F0AE")
ws_d.cell(row=9, column=10).alignment = kpi_center
ws_d.merge_cells("J11:L11")
ws_d.cell(row=11, column=10, value="Toplam net ciro içindeki 3Al2Öde payı").font = vurucu_sub_font
ws_d.cell(row=11, column=10).alignment = kpi_center

# VURUCU 5: Kampanya Kaynaklı Ek Ciro
ws_d.merge_cells("M8:O8")
ws_d.cell(row=8, column=13, value="KAMPANYA EK CİROSU (₺)").font = vurucu_title_font
ws_d.cell(row=8, column=13).alignment = kpi_center
ws_d.merge_cells("M9:O10")
# Ek ciro = 3Al2Öde fişleri × (3Al2Öde ort net - Kampanyasız ort net)
ekciro_f = (f'=SUMPRODUCT(({VR}={SEL})*({VC}="3Al2Ode")*({VD}))'
            f'*(AVERAGEIFS({VG},{VR},{SEL},{VC},"3Al2Ode")'
            f'-AVERAGEIFS({VG},{VR},{SEL},{VC},"Kampanyasiz"))')
ws_d.cell(row=9, column=13, value=ekciro_f).font = Font(name='Calibri', size=20, bold=True, color="69F0AE")
ws_d.cell(row=9, column=13).alignment = kpi_center
ws_d.cell(row=9, column=13).number_format = '#,##0'
ws_d.merge_cells("M11:O11")
ws_d.cell(row=11, column=13, value="3Al2Öde'nin yarattığı tahmini ek gelir").font = vurucu_sub_font
ws_d.cell(row=11, column=13).alignment = kpi_center

# VURUCU 6: 3Al2Öde Fiş Penetrasyonu
ws_d.merge_cells("P8:R8")
ws_d.cell(row=8, column=16, value="3AL2ÖDE PENETRASYON").font = vurucu_title_font
ws_d.cell(row=8, column=16).alignment = kpi_center
ws_d.merge_cells("P9:R10")
pen_f = (f'=TEXT(IFERROR(SUMPRODUCT(({VR}={SEL})*({VC}="3Al2Ode")*({VD}))'
         f'/SUMPRODUCT(({VR}={SEL})*({VD}))*100,0),"0.0")&"%"')
ws_d.cell(row=9, column=16, value=pen_f).font = Font(name='Calibri', size=28, bold=True, color="69F0AE")
ws_d.cell(row=9, column=16).alignment = kpi_center
ws_d.merge_cells("P11:R11")
ws_d.cell(row=11, column=16, value="Toplam fişlerin ne kadarı 3Al2Öde").font = vurucu_sub_font
ws_d.cell(row=11, column=16).alignment = kpi_center

# Row 12-13: spacing before charts
for ci in range(1, 19):
    ws_d.cell(row=12, column=ci).fill = kpi_fill
    ws_d.cell(row=13, column=ci).fill = kpi_fill

# ----- GRAFİKLER (ChartVeri referanslı) -----
def make_line(title, cols, y_title, nfmt=None):
    ch = LineChart()
    ch.title = title; ch.y_axis.title = y_title; ch.x_axis.title = "Ay"
    ch.width = 18; ch.height = 12; ch.style = 10
    cats = Reference(ws_cv, min_col=1, min_row=2, max_row=1+len(AYLAR))
    for i, col_num in enumerate(cols):
        data = Reference(ws_cv, min_col=col_num, min_row=1, max_row=1+len(AYLAR))
        ch.add_data(data, titles_from_data=True)
        s = ch.series[i]
        s.graphicalProperties.line.solidFill = CHART_COLORS[i]
        s.graphicalProperties.line.width = 25000
    ch.set_categories(cats)
    if nfmt: ch.y_axis.numFmt = nfmt
    return ch

# 1) Ort Net Sepet
ws_d.add_chart(make_line("Ortalama Net Sepet Trend (₺)", [2,3,4], "₺", '#,##0'), "A15")

# 2) Toplam Net Ciro
ws_d.add_chart(make_line("Toplam Net Ciro Trend (₺)", [5,6,7], "₺", '#,##0'), "J15")

# 3) Ort Ürün Adet
ws_d.add_chart(make_line("Ortalama Ürün Adet Trend", [11,12,13], "Adet", '0.0'), "A31")

# 4) İndirim Oranı
ws_d.add_chart(make_line("İndirim Oranı Trend (%)", [14,15,16], "%", '0.0'), "J31")

# 5) Fiş Sayısı Bar
bar = BarChart()
bar.type = "col"; bar.title = "Aylık Fiş Sayısı Karşılaştırma"
bar.y_axis.title = "Fiş Sayısı"; bar.x_axis.title = "Ay"
bar.width = 18; bar.height = 12; bar.style = 10
cats = Reference(ws_cv, min_col=1, min_row=2, max_row=1+len(AYLAR))
for i, col_num in enumerate([8,9,10]):
    data = Reference(ws_cv, min_col=col_num, min_row=1, max_row=1+len(AYLAR))
    bar.add_data(data, titles_from_data=True)
    bar.series[i].graphicalProperties.solidFill = CHART_COLORS[i]
bar.set_categories(cats)
bar.y_axis.numFmt = '#,##0'
ws_d.add_chart(bar, "A47")

# 6) Pie — Son Ay
pie = PieChart()
pie.title = "Net Ciro Dağılımı — Son Ay"
pie.width = 16; pie.height = 12; pie.style = 10
labels = Reference(ws_cv, min_col=1, min_row=pie_r+1, max_row=pie_r+3)
data = Reference(ws_cv, min_col=2, min_row=pie_r, max_row=pie_r+3)
pie.add_data(data, titles_from_data=True)
pie.set_categories(labels)
for i, color in enumerate(CHART_COLORS):
    pt = DataPoint(idx=i)
    pt.graphicalProperties.solidFill = color
    pie.series[0].data_points.append(pt)
pie.dataLabels = DataLabelList()
pie.dataLabels.showPercent = True; pie.dataLabels.showCatName = True
ws_d.add_chart(pie, "J47")

# ============================================================
# SAYFA 4: SQL SORGU
# ============================================================
ws_sql = wb.create_sheet("SQL Sorgu", 3)
ws_sql.sheet_properties.tabColor = "9E9E9E"

sql_magaza = """;WITH cte_3al2ode AS (
    SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns WHERE CampaignId IN (1, 12)
),
cte_any_campaign AS (
    SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns
)
SELECT
    st.Name AS Magaza,
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
JOIN dbo.Stores st ON s.StoresId = st.Id
LEFT JOIN cte_3al2ode c3 ON s.Id = c3.SalesId
LEFT JOIN cte_any_campaign ca ON s.Id = ca.SalesId
WHERE s.DocumentsTypeId IN (1,2)
GROUP BY st.Name, CONVERT(varchar(7), s.Date, 126),
    CASE WHEN c3.SalesId IS NOT NULL THEN '3Al2Ode'
         WHEN ca.SalesId IS NOT NULL THEN 'DigerKampanya'
         ELSE 'Kampanyasiz' END
ORDER BY Magaza, Ay, Grup

-- NOT: Power Query icin 'TÜMÜ' satirlarini da eklemek isterseniz
-- UNION ALL ile magaza bazli sorgunun ustune genel toplami ekleyin:
-- SELECT 'TÜMÜ' AS Magaza, ... (ayni sorgu JOIN Stores olmadan)"""

ws_sql.cell(row=1, column=1, value="Power Query SQL Bağlantısı İçin Sorgu").font = Font(bold=True, size=12)
ws_sql.cell(row=2, column=1, value="Sunucu: 192.168.40.201  |  Veritabanı: EncoreMerkez").font = Font(size=10, color="666666")
ws_sql.cell(row=3, column=1, value="Bu sorguyu Power Query > Gelişmiş Seçenekler'e yapıştırın.").font = Font(size=10, color="999999")
ws_sql.cell(row=5, column=1, value=sql_magaza).font = Font(name='Consolas', size=9)
ws_sql.cell(row=5, column=1).alignment = Alignment(horizontal="left", vertical="top", wrap_text=True)
ws_sql.column_dimensions['A'].width = 120
ws_sql.row_dimensions[5].height = 500

# ============================================================
# PRINT & FINAL
# ============================================================
for ws in wb.worksheets:
    ws.print_options.horizontalCentered = True
    ws.page_setup.paperSize = ws.PAPERSIZE_A4
    ws.page_margins.left = 0.4; ws.page_margins.right = 0.4

# Dashboard aktif sayfa olsun
wb.active = wb.worksheets.index(ws_d)

output = os.path.join(os.path.dirname(os.path.abspath(__file__)), "SepetBuyukluguEtkisi_Dashboard.xlsx")
wb.save(output)
print(f"✅ Etkileşimli Dashboard oluşturuldu: {output}")
print(f"   📊 4 sayfa: Veri | ChartVeri (dinamik) | Dashboard | SQL Sorgu")
print(f"   🔽 Dashboard'da MAĞAZA SEÇ dropdown'u: TÜMÜ / FSM Mağaza / IST YOLU MGZ / ÖZLÜCE")
print(f"   📈 6 grafik + 6 KPI — dropdown değişince hepsi otomatik güncellenir")
print(f"   💡 Kullanım: Excel'de Dashboard sayfasını aç → C2 hücresindeki dropdown'dan mağaza seç")
