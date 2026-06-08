"""
BKM Kitap - 2026 Müdür İzin Değerlendirmesi -> biçimli .xlsx üretir.
Çalıştırma:
    pip install openpyxl
    python build_izin_xlsx.py
Çıktı: BKM_Izin_Degerlendirme_2026.xlsx (3 sayfa + bar grafik)
"""
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.chart import BarChart, Reference
from openpyxl.utils import get_column_letter

NAVY="1F3864"; GREEN="16A34A"
hdr_fill=PatternFill("solid",fgColor=NAVY)
hdr_font=Font(name="Calibri",bold=True,color="FFFFFF",size=11)
dip_fill=PatternFill("solid",fgColor="DCFCE7")
peak_fill=PatternFill("solid",fgColor="FEE2E2")
ramp_fill=PatternFill("solid",fgColor="FEF3C7")
warn_fill=PatternFill("solid",fgColor="FFFBEB")
thin=Side(style="thin",color="D9D9D9"); bd=Border(thin,thin,thin,thin)
NF="#,##0"; right=Alignment(horizontal="right"); center=Alignment(horizontal="center")
wrap=Alignment(wrap_text=True,vertical="top")

wb=Workbook()

# ============ Sheet 1: Değerlendirme ============
ws=wb.active; ws.title="Değerlendirme"
ws.merge_cells("A1:E1")
ws["A1"]="BKM Kitap — Mağaza Müdürü İzin Planı Değerlendirmesi (2026 Yaz)"
ws["A1"].font=Font(bold=True,size=15,color=NAVY)
ws.merge_cells("A2:E2")
ws["A2"]="Yıl bütünü mevsimsellik analizi · Net ciro = satış − iade (KDV dahil) · Kaynak: DerinSISBkm.posOzetMagazaGun"
ws["A2"].font=Font(italic=True,size=9,color="808080")
ws.merge_cells("A4:E4")
ws["A4"]="KARAR: YEŞİL — Zamanlama doğru, plan onaylanabilir"
ws["A4"].font=Font(bold=True,size=13,color="FFFFFF")
ws["A4"].fill=PatternFill("solid",fgColor=GREEN); ws["A4"].alignment=center
ws.row_dimensions[4].height=24
ws.merge_cells("A6:E8")
ws["A6"]=("Üç müdürün tüm yıllık izni Haziran–erken Ağustos'a yerleştirilmiş. İki yıllık gerçek veri, "
          "bu pencerenin yılın en sakin çeyreği olduğunu (Mayıs–Temmuz dipte), zirvenin ise Eylül (okula dönüş) "
          "ve güçlü 4. çeyrek olduğunu gösteriyor. İzinler dibe oturmuş, zirveler tam kadro; izinler kademeli "
          "(hiçbir hafta iki müdür birlikte değil). 10 Ağustos sonrası üç müdür de sahada.")
ws["A6"].alignment=wrap

r=10
for c,h in enumerate(["Müdür / Mağaza","İzin tarihleri","Net gün","Mağazanın kritik ayı","Değerlendirme"],1):
    cc=ws.cell(r,c,h); cc.fill=hdr_fill; cc.font=hdr_font; cc.border=bd; cc.alignment=center
rows=[
 ("Erkal · İst.Yolu","8–19 Tem",10,"Eylül (yılın #1 olayı)","Optimal — en dipte izin, tüm zirvede sahada"),
 ("Abdurrahman · Özlüce","8–14 Haz, 20–31 Tem",16,"Eylül / geç Ağustos","İyi — iki blok da dipte, Ağu–Eyl sahada"),
 ("Resul · FSM","17–21 Haz, 1–7 Tem, 1–9 Ağu",18,"Eylül (en hafif mağaza)","İyi — 10 Ağu'da döner, Q4 sahada"),
]
for i,(a,b,c,d,e) in enumerate(rows,1):
    rr=r+i
    ws.cell(rr,1,a).font=Font(bold=True)
    ws.cell(rr,2,b); ws.cell(rr,3,c).alignment=center; ws.cell(rr,4,d); ws.cell(rr,5,e)
    for c2 in range(1,6):
        ws.cell(rr,c2).border=bd
        if c2 in (4,5): ws.cell(rr,c2).alignment=wrap

r2=r+5
ws.cell(r2,1,"Yıl bütününde iki dikkat noktası").font=Font(bold=True,color=NAVY,size=11)
ws.merge_cells(start_row=r2+1,start_column=1,end_row=r2+2,end_column=5)
ws.cell(r2+1,1,("1 · Acil durum tamponu yok. Tüm izin erken Ağustos'ta bitiyor; Ağustos ortası–Aralık (yoğun yarı) "
                "boyunca kimsenin kalan izni yok. Eylül–Aralık'ta bir müdür hastalanırsa yedek de kalmaz → yazılı "
                "vekil müdür / yedekleme planı şart."))
ws.cell(r2+1,1).alignment=wrap; ws.cell(r2+1,1).fill=warn_fill
ws.merge_cells(start_row=r2+3,start_column=1,end_row=r2+4,end_column=5)
ws.cell(r2+3,1,("2 · Mayıs kullanılmıyor. Mayıs da dip ay; istenirse Haziran yükünü hafifletmek için bir blok "
                "Mayıs'a çekilebilir. Zorunlu değil, sadece esneklik."))
ws.cell(r2+3,1).alignment=wrap; ws.cell(r2+3,1).fill=warn_fill
ws.column_dimensions["A"].width=22; ws.column_dimensions["B"].width=22
ws.column_dimensions["C"].width=9; ws.column_dimensions["D"].width=20; ws.column_dimensions["E"].width=40

# ============ Sheet 2: Yıllık Ciro ============
ws2=wb.create_sheet("Yıllık Ciro")
ws2.merge_cells("A1:G1")
ws2["A1"]="Aylık Net Ciro — Mağaza Bazlı (₺)"
ws2["A1"].font=Font(bold=True,size=13,color=NAVY)
for c,h in enumerate(["Ay","ÖZLÜCE 2025","FSM 2025","İST YOLU 2025","Toplam 2025","Toplam 2024","Karakter"],1):
    cc=ws2.cell(3,c,h); cc.fill=hdr_fill; cc.font=hdr_font; cc.border=bd; cc.alignment=center
aylar=["Ocak","Şubat","Mart","Nisan","Mayıs","Haziran","Temmuz","Ağustos","Eylül","Ekim","Kasım","Aralık"]
d2025=[(19895220.75,12937733.87,11332760.16),(17501605.11,11988576.86,10766790.17),
 (16730022.49,10465433.20,7629112.65),(17598614.60,11561566.31,10112399.61),
 (15177934.13,9345720.17,6944974.72),(15975843.63,9242011.47,7539947.44),
 (14399107.07,9334933.84,8243026.94),(21716210.28,12827512.83,154196543.09),
 (45953361.35,35310356.31,232856149.32),(29606792.11,22178301.29,21161046.04),
 (24836202.83,17125959.92,15200401.75),(29467286.45,18961278.77,15693064.33)]
t2024=[25823220.50,26187975.43,23232364.41,20994563.08,19974294.51,18482610.32,
       19300651.55,131053859.54,209181990.92,50369375.08,35941145.00,43135459.90]
karakter=["Orta-yüksek","Orta","Düşük-orta","Orta","DİP","DİP","DİP","Ramp","ZİRVE","Yüksek","Yüksek","Yüksek"]
for i in range(12):
    rr=4+i
    ws2.cell(rr,1,aylar[i]).font=Font(bold=True)
    ws2.cell(rr,2,d2025[i][0]); ws2.cell(rr,3,d2025[i][1]); ws2.cell(rr,4,d2025[i][2])
    ws2.cell(rr,5,f"=SUM(B{rr}:D{rr})"); ws2.cell(rr,6,t2024[i]); ws2.cell(rr,7,karakter[i]).alignment=center
    for c in range(2,7): ws2.cell(rr,c).number_format=NF; ws2.cell(rr,c).alignment=right
    for c in range(1,8): ws2.cell(rr,c).border=bd
    f = dip_fill if karakter[i]=="DİP" else peak_fill if karakter[i]=="ZİRVE" else ramp_fill if karakter[i]=="Ramp" else None
    if f: ws2.cell(rr,7).fill=f; ws2.cell(rr,7).font=Font(bold=True)
tr=16
ws2.cell(tr,1,"YIL TOPLAM").font=Font(bold=True,color="FFFFFF"); ws2.cell(tr,1).fill=hdr_fill
for c in (2,3,4,5,6):
    L=get_column_letter(c); cc=ws2.cell(tr,c,f"=SUM({L}4:{L}15)")
    cc.number_format=NF; cc.alignment=right; cc.font=Font(bold=True,color="FFFFFF"); cc.fill=hdr_fill
ws2.cell(tr,7).fill=hdr_fill
ws2.column_dimensions["A"].width=10
for L in ["B","C","D","E","F"]: ws2.column_dimensions[L].width=15
ws2.column_dimensions["G"].width=12
chart=BarChart(); chart.type="col"; chart.title="Aylık Toplam Ciro 2025 (₺) — Eylül zirvesi"
chart.y_axis.title="Net ciro"; chart.x_axis.title="Ay"; chart.height=8; chart.width=20
chart.add_data(Reference(ws2,min_col=5,min_row=3,max_row=15),titles_from_data=True)
chart.set_categories(Reference(ws2,min_col=1,min_row=4,max_row=15)); chart.legend=None
ws2.add_chart(chart,"I3")
ws2.merge_cells("A18:G18")
ws2["A18"]=("Not: İst.Yolu Ağu–Eyl rakamı okula dönüş toptan / ders kitabı (B2B) kanalını içerir. "
            "2024 ile şekil aynı; 2025 mutlak değerleri enflasyonla yüksektir.")
ws2["A18"].font=Font(italic=True,size=9,color="808080"); ws2["A18"].alignment=wrap

# ============ Sheet 3: İzin Detay ============
ws3=wb.create_sheet("İzin Detay")
ws3.merge_cells("A1:F1")
ws3["A1"]="İzin Blokları — Detay"; ws3["A1"].font=Font(bold=True,size=13,color=NAVY)
for c,h in enumerate(["Müdür","Mağaza","Başlangıç","Bitiş","Dönem","Değerlendirme"],1):
    cc=ws3.cell(3,c,h); cc.fill=hdr_fill; cc.font=hdr_font; cc.border=bd; cc.alignment=center
blocks=[
 ("Resul Çil","FSM","17.06.2026","21.06.2026","Dip","Sakin sezon - ideal"),
 ("Resul Çil","FSM","01.07.2026","07.07.2026","Dip","Sakin sezon - ideal"),
 ("Resul Çil","FSM","01.08.2026","09.08.2026","Ramp öncesi","10 Ağu'da döner; FSM en hafif mağaza"),
 ("Abdurrahman Uğurlu","Özlüce","08.06.2026","14.06.2026","Dip","Sakin sezon - ideal"),
 ("Abdurrahman Uğurlu","Özlüce","20.07.2026","31.07.2026","Dip","Sakin sezon; Ağustos tam sahada"),
 ("Erkal Güdenli","İst.Yolu","08.07.2026","19.07.2026","En dip","Optimal - Eylül zirvesinde sahada"),
]
for i,b in enumerate(blocks):
    rr=4+i
    for c,v in enumerate(b,1):
        cc=ws3.cell(rr,c,v); cc.border=bd
        if c==6: cc.alignment=wrap
    if b[4] in ("Dip","En dip"): ws3.cell(rr,5).fill=dip_fill
    elif b[4]=="Ramp öncesi": ws3.cell(rr,5).fill=ramp_fill
ws3.merge_cells("A11:F11")
ws3["A11"]=("Stagger: Hiçbir hafta iki müdür birlikte izinli değil. Temiz devir: Resul 7 Tem döner → Erkal 8 Tem başlar; "
            "Erkal 19 Tem döner → Abdurrahman 20 Tem başlar. Eylül zirvesi ve Q4'e hiç dokunulmuyor.")
ws3["A11"].font=Font(italic=True,size=10,color="374151"); ws3["A11"].alignment=wrap
ws3.row_dimensions[11].height=30
for L,w in [("A",20),("B",10),("C",13),("D",13),("E",12),("F",42)]:
    ws3.column_dimensions[L].width=w

wb.save("BKM_Izin_Degerlendirme_2026.xlsx")
print("OK -> BKM_Izin_Degerlendirme_2026.xlsx")
