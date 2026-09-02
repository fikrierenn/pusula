# -*- coding: utf-8 -*-
"""Patron sunumu -> Excel (emitter): 1 OZET + 1 DETAY sayfasi.

Cekirdek (kohort/censoring/is-hacmi mantigi):
  sorgular/2026-09-02-sezon-personel-kohort-magaza.sql
  sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql
Bu script SADECE bicimlendirir (.claude/rules/emitter-ayrimi.md); tum oran/degisim
Excel FORMULU olarak yazilir -> hesap tek kaynakta kalir, hucre denetlenebilir.

⚠ KISISEL VERI YOK: yalnizca toplulastirilmis sayi -> paylasima uygun.

Kullanim:
    python scripts/patron_ozet_excel.py <veri.json> <cikti.xlsx>
"""
import json
import sys
from pathlib import Path

from openpyxl import Workbook
from openpyxl.chart import BarChart, Reference
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

YUZDE = "0.0%"
ADET = "#,##0"
ADET1 = "#,##0.0"
TL = '#,##0\\ "₺"'
TLM = '#,##0.0\\ "M₺"'
KIRMIZI = "E30622"
BASLIK_DOLGU = PatternFill("solid", fgColor=KIRMIZI)
BASLIK_YAZI = Font(bold=True, color="FFFFFF", size=10)
VURGU_DOLGU = PatternFill("solid", fgColor="F2F2F2")
INCE = Side(style="thin", color="D9D9D9")
KENAR = Border(left=INCE, right=INCE, top=INCE, bottom=INCE)
NOT_YAZI = Font(italic=True, size=9, color="666666")
H1 = Font(bold=True, size=16)
H2 = Font(bold=True, size=11, color="1F5B57")


def _tablo_basligi(ws, satir, kolonlar, ilk_kol=1):
    for i, (baslik, genislik, _f) in enumerate(kolonlar):
        k = ilk_kol + i
        h = ws.cell(satir, k, baslik)
        h.fill = BASLIK_DOLGU
        h.font = BASLIK_YAZI
        h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        h.border = KENAR
        ws.column_dimensions[get_column_letter(k)].width = genislik
    ws.row_dimensions[satir].height = 30


def _yaz(ws, satir, degerler, kolonlar, ilk_kol=1, kalin=False, dolgu=None):
    for i, d in enumerate(degerler):
        h = ws.cell(satir, ilk_kol + i, d)
        h.border = KENAR
        fmt = kolonlar[i][2]
        if fmt:
            h.number_format = fmt
        if kalin:
            h.font = Font(bold=True)
        if dolgu:
            h.fill = dolgu


def sayfa_ozet(wb, veri):
    po = veri["patron_ozet"]
    ws = wb.create_sheet("Ozet")
    ws.column_dimensions["A"].width = 3
    ws.sheet_view.showGridLines = False

    ws["B2"] = "KADRO MU BUYUDU, IS MI BUYUDU"
    ws["B2"].font = H1
    ws["B3"] = po["tez"]
    ws["B3"].font = Font(size=11)
    ws.merge_cells("B3:J3")
    ws["B3"].alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[3].height = 32
    ws["B4"] = po["donem_tanimi"]
    ws["B4"].font = NOT_YAZI

    # --- 1) Fark nerede olustu (akis)
    ws["B6"] = "1 · FARK NEREDE OLUSTU — magazalarda kadrolu personel"
    ws["B6"].font = H2
    kol_akis = [("Adim", 34, None), ("2026", 10, "0"), ("2025 ayni akis", 15, "0")]
    _tablo_basligi(ws, 7, kol_akis, ilk_kol=2)
    akis26 = po["akis"]
    akis25 = {a["adim"]: a["deger"] for a in po["akis25"]}
    esles = {"2025 tabani (30.06.2025)": "2025 tabani (30.06.2025)",
             "Sezon ici degisim (1 Tem - 31 Agu)": "Sezon ici degisim"}
    s = 8
    for a in akis26:
        karsilik = akis25.get(esles.get(a["adim"], ""), None)
        vurgu = VURGU_DOLGU if a["adim"].startswith(("1 Temmuz oncesi", "Sezon ici")) else None
        _yaz(ws, s, [a["adim"], a["deger"], karsilik], kol_akis, ilk_kol=2, dolgu=vurgu)
        s += 1
    ws.cell(s, 2, "Arti olan tek adim 1 Temmuz oncesi; sezon adimi eksi. Gecen yil da ayni yon (-1).").font = NOT_YAZI

    gr = BarChart()
    gr.type = "col"
    gr.title = "Kadrolu personel akisi (2026)"
    gr.y_axis.title = "Kisi"
    gr.height, gr.width = 7.5, 17
    gr.add_data(Reference(ws, min_col=3, min_row=7, max_row=12), titles_from_data=True)
    gr.set_categories(Reference(ws, min_col=2, min_row=8, max_row=12))
    ws.add_chart(gr, "G6")

    # --- 2) Magaza kirilimi (iki yil tam)
    bas = s + 3
    ws.cell(bas, 2, "2 · MAGAZA KIRILIMI — kadro (kisi) ve is hacmi (degisim)").font = H2
    kol_mag = [
        ("Magaza", 14, None),
        ("Sezonluk 25", 11, "0"), ("Sezonluk 26", 11, "0"), ("Sezonluk Δ", 11, "0"),
        ("Kadrolu taban 25\n(30.06)", 13, "0"), ("Kadrolu taban 26\n(30.06)", 13, "0"),
        ("Kadrolu 31.08.25", 13, "0"), ("Kadrolu 31.08.26", 13, "0"),
        ("Sezon ici 25", 11, "0"), ("Sezon ici 26", 11, "0"),
        ("Urun adedi Δ", 12, YUZDE), ("Ciro Δ", 10, YUZDE),
    ]
    _tablo_basligi(ws, bas + 1, kol_mag, ilk_kol=2)
    hacim = {r["magaza"]: r for r in veri["magaza_is_hacmi"]["satirlar"]}
    detay_toplam = 6 + len(veri["magaza_is_hacmi"]["satirlar"])   # Detay sayfasi TOPLAM satiri
    ilk_satir = bas + 2
    s = ilk_satir
    for r in po["magaza"]:
        h = hacim.get(r["magaza"])
        if h:
            adet_d = (h["adet26"] / h["adet25"] - 1) if h["adet25"] else None
            ciro_d = (h["net26"] / h["net25"] - 1) if h["net25"] else None
        else:
            adet_d = ciro_d = None
        _yaz(ws, s, [
            r["magaza"], r["sez25"], r["sez26"], f"=D{s}-C{s}",
            r["taban25"], r["taban26"], r["kad25"], r["kad26"],
            r["ici25"], r["ici26"],
            adet_d if adet_d is not None else "POS yok",
            ciro_d if ciro_d is not None else "POS yok",
        ], kol_mag, ilk_kol=2)
        s += 1
    son_veri = s - 1
    _yaz(ws, s, [
        "MAGAZALAR",
        f"=SUM(C{ilk_satir}:C{son_veri})", f"=SUM(D{ilk_satir}:D{son_veri})", f"=D{s}-C{s}",
        f"=SUM(F{ilk_satir}:F{son_veri})", f"=SUM(G{ilk_satir}:G{son_veri})",
        f"=SUM(H{ilk_satir}:H{son_veri})", f"=SUM(I{ilk_satir}:I{son_veri})",
        f"=SUM(J{ilk_satir}:J{son_veri})", f"=SUM(K{ilk_satir}:K{son_veri})",
        f"=Detay!M{detay_toplam}", f"=Detay!P{detay_toplam}",
    ], kol_mag, ilk_kol=2, kalin=True, dolgu=VURGU_DOLGU)
    toplam_satir = s
    ws.cell(toplam_satir + 1, 2, po["pencere_notu"]).font = NOT_YAZI
    ws.cell(toplam_satir + 2, 2,
            "Heykel ve Sura EncoreMerkez POS'unda yok -> is hacmi kolonlari bos; "
            "toplam yuzdeler uc POS magazasinin toplami (Detay sayfasi).").font = NOT_YAZI

    # --- 3) Itirazlar
    bas = toplam_satir + 4
    ws.cell(bas, 2, "3 · UC ITIRAZ, UC CEVAP").font = H2
    kol_itiraz = [("Itiraz", 34, None), ("Cevap", 110, None)]
    _tablo_basligi(ws, bas + 1, kol_itiraz, ilk_kol=2)
    s = bas + 2
    for it in po["itirazlar"]:
        _yaz(ws, s, [it["soru"], it["cevap"]], kol_itiraz, ilk_kol=2)
        ws.cell(s, 3).alignment = Alignment(wrap_text=True, vertical="top")
        ws.row_dimensions[s].height = 34
        s += 1

    # --- 4) Zayif nokta
    ws.cell(s + 1, 2, "4 · DUZELTMEMIZ GEREKEN TARAF").font = H2
    z = ws.cell(s + 2, 2, po["zayif"])
    z.font = Font(size=10)
    z.alignment = Alignment(wrap_text=True, vertical="top")
    ws.merge_cells(start_row=s + 2, start_column=2, end_row=s + 3, end_column=11)
    ws.cell(s + 2, 2).fill = VURGU_DOLGU
    return ws


def sayfa_detay(wb, veri):
    """Detay soru gelirse bakilacak sayfa: is hacminin tum rakamlari."""
    h = veri["magaza_is_hacmi"]
    ws = wb.create_sheet("Detay")
    ws.sheet_view.showGridLines = False
    ws["A1"] = "DETAY — ARTAN IS HACMI (1 Temmuz – 31 Agustos, her iki yil ayni pencere)"
    ws["A1"].font = H1
    ws["A2"] = h["pencere"]
    ws["A2"].font = NOT_YAZI
    ws["A3"] = f"Kadro: {h['kadro_tanimi']} · Kaynak: {h['kaynak']}"
    ws["A3"].font = NOT_YAZI

    kolonlar = [
        ("Magaza", 14, None),
        ("Kadro 25", 9, "0"), ("Kadro 26", 9, "0"), ("Kadro Δ", 9, YUZDE),
        ("Fis 25", 11, ADET), ("Fis 26", 11, ADET), ("Fis Δ", 9, YUZDE),
        ("Kalem 25", 11, ADET), ("Kalem 26", 11, ADET), ("Kalem Δ", 9, YUZDE),
        ("Urun adedi 25", 13, ADET), ("Urun adedi 26", 13, ADET), ("Adet Δ", 9, YUZDE),
        ("Net ciro 25", 15, TL), ("Net ciro 26", 15, TL), ("Ciro Δ", 9, YUZDE),
        ("Adet/kisi 25", 12, ADET), ("Adet/kisi 26", 12, ADET), ("Adet/kisi Δ", 11, YUZDE),
        ("Fis/kisi 25", 11, ADET), ("Fis/kisi 26", 11, ADET),
        ("Ciro/kisi 25", 14, TL), ("Ciro/kisi 26", 14, TL),
        ("Sepet adet 25", 12, ADET1), ("Sepet adet 26", 12, ADET1),
        ("Sepet tutar 25", 13, TL), ("Sepet tutar 26", 13, TL),
        ("Birim fiyat 25", 13, TL), ("Birim fiyat 26", 13, TL),
        ("Iade belge 25", 12, ADET), ("Iade belge 26", 12, ADET),
        ("Sinav belge 25", 12, ADET), ("Sinav belge 26", 12, ADET),
        ("Sinav ciro 25", 15, TL), ("Sinav ciro 26", 15, TL),
    ]
    _tablo_basligi(ws, 5, kolonlar)
    ws.freeze_panes = "B6"

    def d(a, b, s):
        return f'=IF({a}{s}=0,"",{b}{s}/{a}{s}-1)'

    def o(pay, bol, s):
        return f'=IF({bol}{s}=0,"",{pay}{s}/{bol}{s})'

    ilk = 6
    s = ilk
    for r in h["satirlar"]:
        _yaz(ws, s, [
            r["magaza"],
            r["kadro25"], r["kadro26"], d("B", "C", s),
            r["fis25"], r["fis26"], d("E", "F", s),
            r["kalem25"], r["kalem26"], d("H", "I", s),
            r["adet25"], r["adet26"], d("K", "L", s),
            r["net25"], r["net26"], d("N", "O", s),
            o("K", "B", s), o("L", "C", s), d("Q", "R", s),
            o("E", "B", s), o("F", "C", s),
            o("N", "B", s), o("O", "C", s),
            o("K", "E", s), o("L", "F", s),
            o("N", "E", s), o("O", "F", s),
            o("N", "K", s), o("O", "L", s),
            r["iade25"], r["iade26"],
            r["sinav_belge25"], r["sinav_belge26"],
            r["sinav_net25"], r["sinav_net26"],
        ], kolonlar, kalin=False)
        s += 1
    son = s - 1
    t = s
    satir = ["UC MAGAZA"]
    for i in range(1, len(kolonlar)):
        kol = get_column_letter(1 + i)
        baslik = kolonlar[i][0]
        if "Δ" in baslik:
            onceki = get_column_letter(i - 1)
            simdi = get_column_letter(i)
            satir.append(f'=IF({onceki}{t}=0,"",{simdi}{t}/{onceki}{t}-1)')
        elif "/kisi" in baslik or "Sepet" in baslik or "Birim" in baslik:
            satir.append(None)      # oran: asagida ayrica yazilir
        else:
            satir.append(f"=SUM({kol}{ilk}:{kol}{son})")
    _yaz(ws, t, satir, kolonlar, kalin=True, dolgu=VURGU_DOLGU)
    # toplam satirinda oranlari dogru formulle yaz
    for hedef, formul in [
        ("Q", f"=K{t}/B{t}"), ("R", f"=L{t}/C{t}"), ("S", f'=IF(Q{t}=0,"",R{t}/Q{t}-1)'),
        ("T", f"=E{t}/B{t}"), ("U", f"=F{t}/C{t}"),
        ("V", f"=N{t}/B{t}"), ("W", f"=O{t}/C{t}"),
        ("X", f"=K{t}/E{t}"), ("Y", f"=L{t}/F{t}"),
        ("Z", f"=N{t}/E{t}"), ("AA", f"=O{t}/F{t}"),
        ("AB", f"=N{t}/K{t}"), ("AC", f"=O{t}/L{t}"),
    ]:
        hucre = ws[f"{hedef}{t}"]
        hucre.value = formul
        hucre.font = Font(bold=True)
        hucre.fill = VURGU_DOLGU
        hucre.border = KENAR

    gr = BarChart()
    gr.type = "col"
    gr.title = "Urun adedi — magaza bazli (1 Tem – 31 Agu)"
    gr.y_axis.title = "Adet"
    gr.height, gr.width = 8, 18
    gr.add_data(Reference(ws, min_col=11, max_col=12, min_row=5, max_row=son), titles_from_data=True)
    gr.set_categories(Reference(ws, min_col=1, min_row=ilk, max_row=son))
    ws.add_chart(gr, f"A{t + 3}")

    gr2 = BarChart()
    gr2.type = "col"
    gr2.title = "Kisi basi urun adedi"
    gr2.y_axis.title = "Adet / kisi"
    gr2.height, gr2.width = 8, 18
    gr2.add_data(Reference(ws, min_col=17, max_col=18, min_row=5, max_row=son), titles_from_data=True)
    gr2.set_categories(Reference(ws, min_col=1, min_row=ilk, max_row=son))
    ws.add_chart(gr2, f"L{t + 3}")

    n = t + 20
    notlar = [
        "OLCUT KATMANLARI: fis = islem sayisi · kalem/urun adedi = fiziksel ellecleme · net ciro = KDV haric, iadeler dusulmus.",
        "Ciro fiyat artisindan sisebilir (birim fiyat +%18); URUN ADEDI sismez -> kadro savunmasinda birincil olcut adet.",
        "Sinav Okullari (belge tipi 8) kurumsal kanaldir: 2026'da belge 3.457 -> 2.056, ciro 156,3M -> 121,8M TL. "
        "Toplam ciroyu asagi ceken kalem budur; magaza is yukunu azaltmaz.",
        "Iade belgesi de is yuku uretir: uc magazada 4.167 -> 6.824 adet.",
        h["not"],
        "Cekirdek SQL: sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql (blok 10) · "
        "kadro: sorgular/2026-09-02-sezon-personel-kohort-magaza.sql",
    ]
    for i, txt in enumerate(notlar):
        c = ws.cell(n + i, 1, txt)
        c.font = NOT_YAZI
        c.alignment = Alignment(wrap_text=True, vertical="top")
    return ws


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    veri = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    wb = Workbook()
    wb.remove(wb.active)
    sayfa_ozet(wb, veri)
    sayfa_detay(wb, veri)
    cikti = Path(argv[2])
    cikti.parent.mkdir(parents=True, exist_ok=True)
    wb.save(cikti)
    print(f"yazildi: {cikti} ({len(wb.sheetnames)} sayfa: {', '.join(wb.sheetnames)}) — kisisel veri YOK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
