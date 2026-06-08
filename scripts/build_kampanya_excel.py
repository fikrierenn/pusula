"""
Kampanya CSV -> Excel Workbook (v4 — Sadece adet karşılaştırması)
Kullanım (Windows):
    pip install openpyxl
    python build_kampanya_excel.py

v4 DEĞİŞİKLİKLERİ:
  • Para karşılaştırması KALDIRILDI (geçen yıl kampanyaları YilTutar'ı bozar)
  • Karşılaştırma SADECE ADET bazlı: BeklenenAdet vs KampAdet, FazlaAdet
  • Para kolonları (KampTutar, YilTutar) sadece REFERANS bilgi
  • 35 kolon (v3'te 37 idi)
"""
import csv
import os
import sys
from pathlib import Path
from datetime import datetime
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.worksheet.table import Table, TableStyleInfo

if os.name == "nt":
    BASE = Path(r"D:\Dev\sqlserver-mcp-server\briefings")
else:
    BASE = Path("/sessions/eloquent-magical-allen/mnt/sqlserver-mcp-server/briefings")

CSV_PATH = BASE / "Kampanya_Analiz_2026-05-11.csv"
OUT_PATH = BASE / "Kampanya_Analiz_2026-05-11.xlsx"

# 35 kolon
HEADERS = [
    "stkID", "stkAd", "Yayinevi", "Yazar", "Kategori", "Reyon",            # 0-5
    "KampAdet", "KampTutar",                                                # 6-7 (Tutar referans)
    "Ad_07", "Ad_08", "Ad_09", "Ad_10",                                     # 8-11
    "Ad_FSM", "Ad_Ozluce", "Ad_IstYolu",                                    # 12-14
    "BirimSatisFiyat",                                                      # 15
    "YilAdet", "YilTutar",                                                  # 16-17 (Tutar referans)
    "IlkSatisTarih", "AktifGun",                                            # 18-19
    "BeklenenAdet", "FazlaAdet", "Segment",                                 # 20-22
    "Stok_FSM", "Stok_Ozluce", "Stok_IstYolu", "Stok_MerkezDepo", "Stok_Toplam",  # 23-27
    "StokOnceKamp_FSM", "StokOnceKamp_Ozluce", "StokOnceKamp_IstYolu", "StokOnceKamp_Toplam",  # 28-31
    "SonAlisTarih", "SonAlisAdet", "GunSayisiAlisBeri",                     # 32-34
]
# Excel kolon harfleri:
#   U=BeklenenAdet  V=FazlaAdet  W=Segment

INT_COLS = {0, 6, 8, 9, 10, 11, 12, 13, 14, 16, 19, 23, 24, 25, 26, 27, 28, 29, 30, 31, 33, 34}
FLOAT_COLS = {7, 15, 17, 20, 21}
DATE_COLS = {18, 32}

HEADER_FONT = Font(bold=True, color="FFFFFF", size=11)
HEADER_FILL = PatternFill("solid", fgColor="305496")
HEADER_ALIGN = Alignment(horizontal="center", vertical="center", wrap_text=True)


def parse_num(s):
    if s is None or s == "" or s.upper() == "NULL":
        return None
    try:
        if "." in s:
            return float(s)
        return int(s)
    except ValueError:
        return s


def parse_date(s):
    if not s or s.upper() == "NULL":
        return None
    try:
        return datetime.strptime(s.split(".")[0], "%Y-%m-%d %H:%M:%S")
    except ValueError:
        try:
            return datetime.strptime(s, "%Y-%m-%d")
        except ValueError:
            return s


def style_header(ws, n_cols):
    for col in range(1, n_cols + 1):
        c = ws.cell(row=1, column=col)
        c.font = HEADER_FONT
        c.fill = HEADER_FILL
        c.alignment = HEADER_ALIGN
    ws.freeze_panes = "A2"
    ws.row_dimensions[1].height = 30


def main():
    print(f"CSV: {CSV_PATH}")
    if not CSV_PATH.exists():
        print(f"HATA: CSV bulunamadi: {CSV_PATH}")
        sys.exit(1)

    rows = []
    with CSV_PATH.open("r", encoding="utf-8") as f:
        reader = csv.reader(f, delimiter=";")
        for row in reader:
            if not row or len(row) < 35:
                continue
            parsed = []
            for i, v in enumerate(row):
                if i in INT_COLS or i in FLOAT_COLS:
                    parsed.append(parse_num(v))
                elif i in DATE_COLS:
                    parsed.append(parse_date(v))
                else:
                    parsed.append(v)
            rows.append(parsed)
    n = len(rows)
    print(f"Satir sayisi: {n}")

    wb = Workbook()
    wb.remove(wb.active)

    # === Parametreler ===
    s_param = wb.create_sheet("Parametreler")
    params = [
        ("Parametre", "Deger"),
        ("Kampanya", "07-10 Mayis 2026 (4 gun)"),
        ("Yillik baseline", "07.05.2025 - 07.05.2026"),
        ("Magazalar", "FSM, Ozluce, Ist.Yolu"),
        ("Kategoriler", "Kitap, Cocuk Kitabi, Akademi, Hazirlik Kitaplari"),
        ("Yeni urun esigi", "30 gun aktif"),
        ("Toplam urun satiri", n),
        ("", ""),
        ("KARSILASTIRMA MANTIGI", ""),
        ("Karsilastirma turu", "SADECE ADET (para karsilastirmasi yok)"),
        ("Para neden yok?", "Gecen yil kampanyalari/indirimleri YilTutar'i bozar"),
        ("BeklenenAdet", "= YilAdet x 4 / Min(365, AktifGun)"),
        ("FazlaAdet", "= KampAdet - BeklenenAdet (somut fark)"),
        ("", ""),
        ("SEGMENT", ""),
        ("1_Yeni", "Aktif gun < 30, baseline yok"),
        ("2_YillikSatissiz", "Yillik 0 satildi"),
        ("3_BeklenendenFazla", "KampAdet > BeklenenAdet"),
        ("4_BeklenendenAz", "KampAdet <= BeklenenAdet"),
    ]
    for r in params:
        s_param.append(r)
    style_header(s_param, 2)
    s_param.column_dimensions["A"].width = 30
    s_param.column_dimensions["B"].width = 64

    # === Urun_Master ===
    s_um = wb.create_sheet("Urun_Master")
    s_um.append(HEADERS)
    for r in rows:
        s_um.append(r)
    style_header(s_um, len(HEADERS))
    widths = {
        "A": 8, "B": 50, "C": 24, "D": 22, "E": 16, "F": 14,
        "G": 9, "H": 12, "I": 7, "J": 7, "K": 7, "L": 7,
        "M": 8, "N": 9, "O": 9, "P": 12, "Q": 9, "R": 13,
        "S": 13, "T": 10,
        "U": 12, "V": 11, "W": 20,
        "X": 9, "Y": 10, "Z": 11, "AA": 13, "AB": 12,
        "AC": 14, "AD": 16, "AE": 16, "AF": 16,
        "AG": 17, "AH": 11, "AI": 12,
    }
    for col, w in widths.items():
        s_um.column_dimensions[col].width = w
    last_row = n + 1
    tbl = Table(displayName="UrunMaster", ref=f"A1:AI{last_row}")
    tbl.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    s_um.add_table(tbl)

    # === Segment_Ozet (adet bazli) ===
    s_seg = wb.create_sheet("Segment_Ozet")
    s_seg.append(["Segment", "UrunSayisi", "KampAdet",
                  "BeklenenAdet", "FazlaAdet", "FazlaAdet_Yuzde",
                  "KampTutar_Ref"])
    segments = ["Yeni Kitap", "YillikSatissiz", "OrtalamadanFazla", "OrtalamadanAz"]
    for i, seg in enumerate(segments, start=2):
        s_seg.cell(row=i, column=1, value=seg)
        s_seg.cell(row=i, column=2, value=f'=COUNTIFS(Urun_Master!W:W,A{i})')
        s_seg.cell(row=i, column=3, value=f'=SUMIFS(Urun_Master!G:G,Urun_Master!W:W,A{i})')
        s_seg.cell(row=i, column=4, value=f'=SUMIFS(Urun_Master!U:U,Urun_Master!W:W,A{i})')
        s_seg.cell(row=i, column=5, value=f'=SUMIFS(Urun_Master!V:V,Urun_Master!W:W,A{i})')
        s_seg.cell(row=i, column=6, value=f'=IFERROR(E{i}/C{i}*100,0)')
        s_seg.cell(row=i, column=7, value=f'=SUMIFS(Urun_Master!H:H,Urun_Master!W:W,A{i})')
    s_seg.cell(row=6, column=1, value="TOPLAM").font = Font(bold=True)
    for col_letter in ["B", "C", "D", "E", "G"]:
        s_seg.cell(row=6, column=ord(col_letter) - ord("A") + 1,
                   value=f"=SUM({col_letter}2:{col_letter}5)")
    s_seg.cell(row=6, column=6, value="=IFERROR(E6/C6*100,0)")
    style_header(s_seg, 7)
    for col, w in {"A": 22, "B": 12, "C": 12, "D": 13, "E": 12, "F": 16, "G": 16}.items():
        s_seg.column_dimensions[col].width = w
    s_seg.cell(row=8, column=1, value="Yorumlama").font = Font(bold=True)
    s_seg.cell(row=9, column=2, value="Yeni Kitap: < 30 gun aktif. Baseline yok, FazlaAdet = KampAdet (referans)")
    s_seg.cell(row=10, column=2, value="YillikSatissiz: Normalde 0 satiyordu, kampanyada satti — tum adet fazla")
    s_seg.cell(row=11, column=2, value="OrtalamadanFazla: Kampanyaya borclu adet — FazlaAdet pozitif")
    s_seg.cell(row=12, column=2, value="OrtalamadanAz: Beklenen kadar bile satmadi — FazlaAdet negatif")
    s_seg.cell(row=14, column=1, value="NOT").font = Font(bold=True)
    s_seg.cell(row=14, column=2, value="KampTutar_Ref: Sadece referans amacli. Para karsilastirmasi yapilmadi.")

    # === Yayinevi_Ozet (adet bazli) ===
    unique_yayinevi = sorted({r[2] for r in rows if r[2]})
    s_y = wb.create_sheet("Yayinevi_Ozet")
    s_y.append(["Yayinevi", "UrunCesidi", "KampAdet",
                "BeklenenAdet", "FazlaAdet", "FazlaAdet_Yuzde",
                "KampTutar_Ref", "YilAdet_Ref"])
    for i, y in enumerate(unique_yayinevi, start=2):
        s_y.cell(row=i, column=1, value=y)
        s_y.cell(row=i, column=2, value=f'=COUNTIFS(Urun_Master!C:C,A{i})')
        s_y.cell(row=i, column=3, value=f'=SUMIFS(Urun_Master!G:G,Urun_Master!C:C,A{i})')
        s_y.cell(row=i, column=4, value=f'=SUMIFS(Urun_Master!U:U,Urun_Master!C:C,A{i})')
        s_y.cell(row=i, column=5, value=f'=SUMIFS(Urun_Master!V:V,Urun_Master!C:C,A{i})')
        s_y.cell(row=i, column=6, value=f'=IFERROR(E{i}/C{i}*100,0)')
        s_y.cell(row=i, column=7, value=f'=SUMIFS(Urun_Master!H:H,Urun_Master!C:C,A{i})')
        s_y.cell(row=i, column=8, value=f'=SUMIFS(Urun_Master!Q:Q,Urun_Master!C:C,A{i})')
    style_header(s_y, 8)
    s_y.auto_filter.ref = f"A1:H{len(unique_yayinevi)+1}"
    for col, w in {"A": 32, "B": 12, "C": 11, "D": 13, "E": 12, "F": 16, "G": 14, "H": 12}.items():
        s_y.column_dimensions[col].width = w

    # === Kategori_Ozet ===
    s_k = wb.create_sheet("Kategori_Ozet")
    s_k.append(["Kategori", "UrunCesidi", "KampAdet",
                "BeklenenAdet", "FazlaAdet", "FazlaAdet_Yuzde", "KampTutar_Ref"])
    kategoriler = ["Kitap", "Çocuk Kitabı", "Akademi", "Hazırlık Kitapları"]
    for i, k in enumerate(kategoriler, start=2):
        s_k.cell(row=i, column=1, value=k)
        s_k.cell(row=i, column=2, value=f'=COUNTIFS(Urun_Master!E:E,A{i})')
        s_k.cell(row=i, column=3, value=f'=SUMIFS(Urun_Master!G:G,Urun_Master!E:E,A{i})')
        s_k.cell(row=i, column=4, value=f'=SUMIFS(Urun_Master!U:U,Urun_Master!E:E,A{i})')
        s_k.cell(row=i, column=5, value=f'=SUMIFS(Urun_Master!V:V,Urun_Master!E:E,A{i})')
        s_k.cell(row=i, column=6, value=f'=IFERROR(E{i}/C{i}*100,0)')
        s_k.cell(row=i, column=7, value=f'=SUMIFS(Urun_Master!H:H,Urun_Master!E:E,A{i})')
    style_header(s_k, 7)
    for col, w in {"A": 20, "B": 12, "C": 11, "D": 13, "E": 12, "F": 16, "G": 14}.items():
        s_k.column_dimensions[col].width = w

    # === Yazar_Ozet (top 100 KampAdet bazli) ===
    yazar_top = {}
    for r in rows:
        yazar = r[3]
        kampa = r[6] or 0
        yazar_top[yazar] = yazar_top.get(yazar, 0) + (kampa if isinstance(kampa, (int, float)) else 0)
    top_yazar = sorted(yazar_top.items(), key=lambda x: -x[1])[:100]
    s_yz = wb.create_sheet("Yazar_Ozet")
    s_yz.append(["Yazar", "UrunCesidi", "KampAdet",
                 "BeklenenAdet", "FazlaAdet", "FazlaAdet_Yuzde", "KampTutar_Ref"])
    for i, (yz, _) in enumerate(top_yazar, start=2):
        s_yz.cell(row=i, column=1, value=yz)
        s_yz.cell(row=i, column=2, value=f'=COUNTIFS(Urun_Master!D:D,A{i})')
        s_yz.cell(row=i, column=3, value=f'=SUMIFS(Urun_Master!G:G,Urun_Master!D:D,A{i})')
        s_yz.cell(row=i, column=4, value=f'=SUMIFS(Urun_Master!U:U,Urun_Master!D:D,A{i})')
        s_yz.cell(row=i, column=5, value=f'=SUMIFS(Urun_Master!V:V,Urun_Master!D:D,A{i})')
        s_yz.cell(row=i, column=6, value=f'=IFERROR(E{i}/C{i}*100,0)')
        s_yz.cell(row=i, column=7, value=f'=SUMIFS(Urun_Master!H:H,Urun_Master!D:D,A{i})')
    style_header(s_yz, 7)
    s_yz.auto_filter.ref = f"A1:G{len(top_yazar)+1}"
    for col, w in {"A": 28, "B": 12, "C": 11, "D": 13, "E": 12, "F": 16, "G": 14}.items():
        s_yz.column_dimensions[col].width = w

    # === Top_FazlaSatan (FazlaAdet > 0, en yüksekten) ===
    # row[21] = FazlaAdet
    rows_sorted_fazla = sorted(
        [r for r in rows if isinstance(r[21], (int, float)) and r[21] > 0],
        key=lambda x: -x[21]
    )
    s_top = wb.create_sheet("Top_FazlaSatan")
    s_top.append(["stkID", "stkAd", "Yayinevi", "Yazar", "Kategori",
                  "IlkSatisTarih", "AktifGun",
                  "KampAdet", "YilAdet",
                  "BeklenenAdet", "FazlaAdet",
                  "Segment", "Stok_Toplam", "KampTutar_Ref"])
    for r in rows_sorted_fazla[:100]:
        s_top.append([r[0], r[1], r[2], r[3], r[4],
                      r[18], r[19],
                      r[6], r[16],
                      r[20], r[21],
                      r[22], r[27], r[7]])
    style_header(s_top, 14)
    s_top.auto_filter.ref = f"A1:N{min(101, len(rows_sorted_fazla)+1)}"

    # === Top_AzSatan (FazlaAdet < 0, en negatiften) ===
    rows_sorted_az = sorted(
        [r for r in rows if isinstance(r[21], (int, float)) and r[21] < 0],
        key=lambda x: x[21]
    )
    s_me = wb.create_sheet("Top_AzSatan")
    s_me.append(["stkID", "stkAd", "Yayinevi", "Yazar", "Kategori",
                 "IlkSatisTarih", "AktifGun",
                 "KampAdet", "YilAdet",
                 "BeklenenAdet", "FazlaAdet",
                 "Stok_Toplam", "SonAlisTarih", "GunSayisiAlisBeri"])
    for r in rows_sorted_az[:100]:
        s_me.append([r[0], r[1], r[2], r[3], r[4],
                     r[18], r[19],
                     r[6], r[16],
                     r[20], r[21],
                     r[27], r[32], r[34]])
    style_header(s_me, 14)
    s_me.auto_filter.ref = f"A1:N{min(101, len(rows_sorted_az)+1)}"

    # === Yeni_Urunler ===
    new_segment = [r for r in rows if r[22] == "Yeni Kitap"]
    new_sorted = sorted(new_segment, key=lambda x: -(x[6] if isinstance(x[6], (int, float)) else 0))
    s_yu = wb.create_sheet("Yeni_Urunler")
    s_yu.append(["stkID", "stkAd", "Yayinevi", "Yazar", "Kategori",
                 "IlkSatisTarih", "AktifGun",
                 "KampAdet", "YilAdet", "Stok_Toplam"])
    for r in new_sorted[:300]:
        s_yu.append([r[0], r[1], r[2], r[3], r[4],
                     r[18], r[19], r[6], r[16], r[27]])
    style_header(s_yu, 10)
    s_yu.auto_filter.ref = f"A1:J{min(301, len(new_sorted)+1)}"

    # === Dashboard (adet bazli, para sadece referans) ===
    s_d = wb.create_sheet("Dashboard")
    dashboard = [
        ("KAMPANYA PERFORMANS DASHBOARD", None),
        ("Donem: 07-10 Mayis 2026 (4 gun)", None),
        ("", None),
        ("KAMPANYADA NE SATILDI?", None),
        ("Urun cesit", f"=COUNTA(Urun_Master!A2:A{last_row})"),
        ("Net adet", "=SUM(Urun_Master!G:G)"),
        ("Net tutar (referans)", "=SUM(Urun_Master!H:H)"),
        ("", None),
        ("NORMALDE 4 GUNDE NE SATACAKTI?", None),
        ("Beklenen adet (yeni urun haric)", "=SUM(Urun_Master!U:U)"),
        ("", None),
        ("FARK — KAMPANYANIN SOMUT ETKISI (ADET)", None),
        ("Fazla adet (toplam)", "=SUM(Urun_Master!V:V)"),
        ("Fark / Kampanya adet %", "=B13/B6*100"),
        ("", None),
        ("SEGMENT DAGILIMI", None),
        ("Yeni Kitap — urun sayisi", '=COUNTIF(Urun_Master!W:W,"Yeni Kitap")'),
        ("Yeni Kitap — kamp adet", '=SUMIF(Urun_Master!W:W,"Yeni Kitap",Urun_Master!G:G)'),
        ("YillikSatissiz — urun", '=COUNTIF(Urun_Master!W:W,"YillikSatissiz")'),
        ("YillikSatissiz — kamp adet", '=SUMIF(Urun_Master!W:W,"YillikSatissiz",Urun_Master!G:G)'),
        ("OrtalamadanFazla — urun", '=COUNTIF(Urun_Master!W:W,"OrtalamadanFazla")'),
        ("OrtalamadanFazla — kamp adet", '=SUMIF(Urun_Master!W:W,"OrtalamadanFazla",Urun_Master!G:G)'),
        ("OrtalamadanFazla — fazla adet", '=SUMIF(Urun_Master!W:W,"OrtalamadanFazla",Urun_Master!V:V)'),
        ("OrtalamadanAz — urun", '=COUNTIF(Urun_Master!W:W,"OrtalamadanAz")'),
        ("OrtalamadanAz — kamp adet", '=SUMIF(Urun_Master!W:W,"OrtalamadanAz",Urun_Master!G:G)'),
        ("OrtalamadanAz — fazla adet (negatif)", '=SUMIF(Urun_Master!W:W,"OrtalamadanAz",Urun_Master!V:V)'),
        ("", None),
        ("STOK DURUMU", None),
        ("Toplam guncel stok (4 lokasyon)", "=SUM(Urun_Master!AB:AB)"),
        ("Kampanya oncesi magaza stogu", "=SUM(Urun_Master!AF:AF)"),
        ("FSM stok", "=SUM(Urun_Master!X:X)"),
        ("Ozluce stok", "=SUM(Urun_Master!Y:Y)"),
        ("Ist.Yolu stok", "=SUM(Urun_Master!Z:Z)"),
        ("Merkez depo stok", "=SUM(Urun_Master!AA:AA)"),
        ("", None),
        ("NOT", "Para karsilastirmasi yapilmadi. Gecen yil 3 al 2 ode / %X indirim gibi"),
        ("", "kampanyalar oldugunda YilTutar zaten indirimli — para karsilastirmasi"),
        ("", "yaniltici olur. ADET karsilastirmasi temizdir."),
    ]
    for i, (label, val) in enumerate(dashboard, start=1):
        s_d.cell(row=i, column=1, value=label)
        if val is not None:
            s_d.cell(row=i, column=2, value=val)
        if label in ("KAMPANYADA NE SATILDI?", "NORMALDE 4 GUNDE NE SATACAKTI?",
                     "FARK — KAMPANYANIN SOMUT ETKISI (ADET)", "SEGMENT DAGILIMI", "STOK DURUMU"):
            s_d.cell(row=i, column=1).font = Font(bold=True, size=12, color="305496")
            s_d.cell(row=i, column=1).fill = PatternFill("solid", fgColor="DDEBF7")
        elif i == 1:
            s_d.cell(row=i, column=1).font = Font(bold=True, size=14)
        elif label == "NOT":
            s_d.cell(row=i, column=1).font = Font(bold=True, italic=True)
    s_d.column_dimensions["A"].width = 42
    s_d.column_dimensions["B"].width = 60
    s_d.freeze_panes = "A4"

    wb._sheets = [s_d, s_param, s_um, s_seg, s_y, s_k, s_yz, s_top, s_me, s_yu]

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    wb.save(OUT_PATH)
    print(f"OK -> {OUT_PATH}")
    print(f"  Urun_Master satir: {n}")
    print(f"  Yayinevi: {len(unique_yayinevi)}")
    print(f"  1_Yeni urun: {len(new_segment)}")
    print(f"  FazlaAdet > 0 urun: {len(rows_sorted_fazla)}")
    print(f"  FazlaAdet < 0 urun: {len(rows_sorted_az)}")


if __name__ == "__main__":
    main()
