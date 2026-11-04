# -*- coding: utf-8 -*-
"""Kırtasiye Sepet Büyüklüğü Analizi (2025 vs 2026) — Çok Sayfalı Sunum & Analiz Excel Raporu.

Kaynak SQL ve doğrulanmış ölçümler: sorgular/2026-10-01-kirtasiye-sepet-buyuklugu.sql
Çıktı: raporlar/Kirtasiye_Sepet_Buyuklugu_2025_2026.xlsx
"""
from __future__ import annotations

import os
from openpyxl import Workbook
from openpyxl.chart import BarChart, Reference
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

# Biçim sabitleri
FMT_ADET = "#,##0"
FMT_ONDALIK2 = "#,##0.00"
FMT_ONDALIK1 = "#,##0.0"
FMT_TL = '#,##0.0 "₺"'
FMT_TL_TAM = '#,##0 "₺"'
FMT_YUZDE_ORAN = "0.0%"
FMT_YUZDE_DEGISIM = "+0.0%;-0.0%;0.0%"
FMT_PUAN = '+0.0" p";-0.0" p";0.0" p"'
FMT_CARPAN = '0.00"x"'

FILL_BKM = PatternFill("solid", fgColor="E30622")
FILL_LACIVERT = PatternFill("solid", fgColor="1E293B")
FILL_YESIL_BASLIK = PatternFill("solid", fgColor="1F5B57")
FILL_ALT_BASLIK = PatternFill("solid", fgColor="334155")
FILL_ZEBRA = PatternFill("solid", fgColor="F8FAFC")
FILL_TOPLAM = PatternFill("solid", fgColor="E2E8F0")
FILL_VURGU_SARI = PatternFill("solid", fgColor="FFF3CD")
FILL_VURGU_YESIL = PatternFill("solid", fgColor="DCFCE7")
FILL_VURGU_KIRMIZI = PatternFill("solid", fgColor="FEE2E2")
FILL_HIKAYE = PatternFill("solid", fgColor="F1F5F9")

FONT_BASLIK = Font(name="Segoe UI", bold=True, color="FFFFFF", size=10)
FONT_SAYFA_BASLIK = Font(name="Segoe UI", bold=True, color="1E293B", size=15)
FONT_BOLUM = Font(name="Segoe UI", bold=True, color="1F5B57", size=12)
FONT_NORMAL = Font(name="Segoe UI", size=10, color="1E293B")
FONT_KALIN = Font(name="Segoe UI", bold=True, size=10, color="1E293B")
FONT_YESIL = Font(name="Segoe UI", bold=True, size=10, color="15803D")
FONT_KIRMIZI = Font(name="Segoe UI", bold=True, size=10, color="B91C1C")
FONT_NOT = Font(name="Segoe UI", italic=True, size=9.5, color="475569")
FONT_HIKAYE_BASLIK = Font(name="Segoe UI", bold=True, size=10.5, color="0F172A")
FONT_HIKAYE_METIN = Font(name="Segoe UI", size=10, color="334155")

INCE = Side(style="thin", color="CBD5E1")
KALIN_ALT = Side(style="medium", color="1E293B")
KENAR = Border(left=INCE, right=INCE, top=INCE, bottom=INCE)
KENAR_TOPLAM = Border(left=INCE, right=INCE, top=KALIN_ALT, bottom=KALIN_ALT)


def baslik_yaz(ws, satir: int, kolonlar: list[tuple[str, int, str | None]], fill=FILL_BKM, dondur: bool = True):
    for i, (ad, gen, _fmt) in enumerate(kolonlar, start=1):
        c = ws.cell(satir, i, ad)
        c.fill = fill
        c.font = FONT_BASLIK
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        c.border = KENAR
        harf = get_column_letter(i)
        mevcut = ws.column_dimensions[harf].width or 0
        if gen > mevcut:
            ws.column_dimensions[harf].width = gen
    ws.row_dimensions[satir].height = 32
    if dondur:
        ws.freeze_panes = ws.cell(satir + 1, 2)


def satir_yaz(ws, satir: int, kolonlar: list[tuple[str, int, str | None]], degerler: list,
              fill=None, bold: bool = False, toplam: bool = False):
    for i, ((_ad, _gen, fmt), val) in enumerate(zip(kolonlar, degerler), start=1):
        c = ws.cell(satir, i, val)
        c.border = KENAR_TOPLAM if toplam else KENAR
        if fill:
            c.fill = fill
        c.font = FONT_KALIN if (bold or toplam) else FONT_NORMAL
        if fmt:
            c.number_format = fmt
            if fmt in (FMT_YUZDE_DEGISIM, FMT_PUAN) and isinstance(val, (int, float)):
                if val > 0:
                    c.font = FONT_YESIL
                elif val < 0:
                    c.font = FONT_KIRMIZI
            elif fmt in (FMT_YUZDE_DEGISIM, FMT_PUAN) and isinstance(val, str) and val.startswith("="):
                c.font = FONT_YESIL
        if i == 1:
            c.alignment = Alignment(horizontal="left", vertical="center")
        elif isinstance(val, str) and not val.startswith("="):
            c.alignment = Alignment(horizontal="left", vertical="center")
        else:
            c.alignment = Alignment(horizontal="right", vertical="center")
    ws.row_dimensions[satir].height = 22
    return satir + 1


def anlatim_kutusu(ws, satir: int, baslik: str, maddeler: list[str], genislik_kolon: int = 10, fill=FILL_HIKAYE):
    ws.merge_cells(start_row=satir, start_column=1, end_row=satir, end_column=genislik_kolon)
    b = ws.cell(satir, 1, f"📌 {baslik}")
    b.font = FONT_HIKAYE_BASLIK
    b.fill = FILL_VURGU_SARI
    b.alignment = Alignment(horizontal="left", vertical="center")
    for k in range(1, genislik_kolon + 1):
        ws.cell(satir, k).border = KENAR
        ws.cell(satir, k).fill = FILL_VURGU_SARI
    ws.row_dimensions[satir].height = 24
    satir += 1

    for m in maddeler:
        ws.merge_cells(start_row=satir, start_column=1, end_row=satir, end_column=genislik_kolon)
        c = ws.cell(satir, 1, f"• {m}")
        c.font = FONT_HIKAYE_METIN
        c.fill = fill
        c.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
        for k in range(1, genislik_kolon + 1):
            ws.cell(satir, k).border = KENAR
            ws.cell(satir, k).fill = fill
        ws.row_dimensions[satir].height = 24
        satir += 1
    return satir + 1


# ==============================================================================
# 1. SAYFA: SUNUM & HİKAYE (TOPLANTIDA ANLATIM REHBERİ)
# ==============================================================================
def sayfa_sunum_olustur(wb: Workbook):
    ws = wb.active
    ws.title = "0_Sunum_Hikaye"
    ws.sheet_view.showGridLines = False

    ws.column_dimensions["A"].width = 5
    ws.column_dimensions["B"].width = 88
    ws.column_dimensions["C"].width = 24
    ws.column_dimensions["D"].width = 26

    b = ws.cell(2, 2, "KIRTASİYE SEPET BÜYÜKLÜĞÜ ANALİZİ — GEÇEN YIL (2025) vs BU YIL (2026)")
    b.font = Font(name="Segoe UI", bold=True, size=16, color="1F5B57")
    alt = ws.cell(3, 2, "Üç Mağaza (FSM · Özlüce · İst. Yolu) · Perakende Kasa Fişleri (EncoreMerkez) · Okul Sezonu (Ağustos–Eylül) & 15 Aylık Trend")
    alt.font = FONT_NOT

    # Başlık şeridi
    for kol, metin in [(1, "#"), (2, "Toplantıda Anlatılacak Ana Bulgu & Hikaye"), (3, "2025 → 2026 Gösterge"), (4, "Değişim / Etki")]:
        c = ws.cell(5, kol, metin)
        c.fill = FILL_LACIVERT
        c.font = FONT_BASLIK
        c.alignment = Alignment(horizontal="center" if kol != 2 else "left", vertical="center")
    ws.row_dimensions[5].height = 28

    kartlar = [
        (
            "1",
            "Mağazaya giren müşterinin sepetine kırtasiye girme oranı (penetrasyon) sert yükseldi.",
            "Toplam perakende fiş sayısı +%8,2 artarken (188,7 bin → 204,2 bin), içinde kırtasiye bulunan fiş sayısı +%19,7 (97,3 bin → 116,5 bin) büyüdü. Yani bu yıl kasadan geçen her 100 fişin 57'sinde kırtasiye var (geçen yıl 52'sinde).",
            "%51,6 → %57,1",
            "+5,5 Puan (+%19,7 Fiş)",
            FILL_VURGU_YESIL,
        ),
        (
            "2",
            "Kırtasiye sepeti hem ADET hem ÇEŞİT hem de TL olarak büyüdü.",
            "Kırtasiye giren fişlerde sadece kırtasiye kalemlerinin ortalaması 6,08 adetten 6,26 adede (+%3,0), farklı ürün çeşidi 4,61'den 4,83'e (+%4,8), net kırtasiye tutarı ise 567,9 ₺'den 690,9 ₺'ye (+%21,7) çıktı.",
            "6,08 → 6,26 Adet",
            "567,9 ₺ → 690,9 ₺ (+%21,7)",
            FILL_VURGU_YESIL,
        ),
        (
            "3",
            "ŞAŞIRTICI KEŞİF: '1 Kuruşluk Oyun Hamuru' ortalamayı aşağı çekmiş — gerçek büyüme 2 kat güçlü!",
            "5 Ağustos 2026'dan itibaren kasada 0,01 ₺'ye verilen promosyon 'LETS Oyun Hamuru' (stkID 1733557, 29.097 fiş) Kırtasiye kategorisinde açıldığı için, sadece kitap alıp hediye hamur verilen 9.277 fiş '1 adetlik 0,01 ₺ kırtasiye sepeti' sayıldı. Bu sahte fişler çıkarılınca GERÇEK kırtasiye sepeti 6,11 → 6,52 adede (+%6,7) ve 572,7 ₺ → 750,3 ₺'ye (+%31,0) çıktı!",
            "6,11 → 6,52 Adet (Gerçek)",
            "572,7 ₺ → 750,3 ₺ (+%31,0)",
            FILL_VURGU_SARI,
        ),
        (
            "4",
            "Ağustos'taki sepet düşüşü sahte çıktı; asıl okul alışverişi Eylül'de patladı.",
            "Ham veride Ağustos kırtasiye sepeti 505,6 ₺ → 492,9 ₺ (−%2,5) düşmüş görünüyordu. 3.619 adet 1 kuruşluk oyun hamuru fişi ayıklanınca Ağustos gerçek sepeti 505,6 ₺ → 540,9 ₺ (+%7,0) büyüdü. Eylül'de ise gerçek sepet 607,5 ₺ → 860,6 ₺ (+%41,7) ve 6,54 → 7,46 adet (+%14,1) ile rekor kırdı.",
            "Eylül: 6,54 → 7,46 Adet",
            "Eylül: 607,5 ₺ → 860,6 ₺ (+%41,7)",
            FILL_VURGU_YESIL,
        ),
        (
            "5",
            "İndirim oranı +%6,7 puan arttı ama BRÜT MARJ erimedi — aksine +2,8 puan yükseldi!",
            "Kırtasiyede ortalama kasa indirimi %12,8'den %19,5'e çıkınca 'marjı feda mı ettik?' sorusu doğar. Aynı-yıl alış faturalarıyla (KDV hariç) ölçüldüğünde brüt marj %40,8'den %43,6'ya (+2,8 puan) çıktı! Fiş başına kasaya kalan net brüt kâr 178,7 ₺'den 248,6 ₺'ye (+%39,1), toplam brüt kâr havuzu 15,97M ₺ → 27,95M ₺'ye (+%75,0) ulaştı.",
            "Marj: %40,8 → %43,6",
            "Fiş Başı Kâr: 179 ₺ → 249 ₺ (+%39,1)",
            FILL_VURGU_YESIL,
        ),
        (
            "6",
            "Kırtasiye tek başına küçük (3,8 adet); onu devleştiren 'Kitap & Hazırlık Evliliği'!",
            "Müşteri kasaya SADECE kırtasiye ile geldiğinde 3,80 adet (475 ₺) alıyor. Ama sepetine Kitap eklediğinde kırtasiye adedi 5,57'ye (toplam fiş 1.678 ₺), Hazırlık + Kitap eklediğinde kırtasiye adedi 7,63'e (toplam fiş 2.918 ₺ — 6,1 kat!), Oyuncak/Hediyelik eklediğinde ise kırtasiye adedi 8,03 adede çıkıyor.",
            "Saf: 475 ₺ vs Karma: 2.918 ₺",
            "6,1x Sepet Büyütme Çarpanı",
            FILL_VURGU_YESIL,
        ),
        (
            "7",
            "Pareto Kutuplaşması: Fişlerin %15'i ('Okul Listesi' müşterisi), cironun %53,4'ünü tek başına yapıyor!",
            "Kırtasiye fişlerinin medyanı 3 adettir (%58,3'ü 1–3 adet alır ve cironun sadece %20,5'ini üretir). Buna karşılık 11 ve üzeri kırtasiye alan %15,1'lik kesim (17.635 fiş), toplam kırtasiye adedinin %59,1'ini ve cirosunun %53,4'ünü (42,96M ₺) sırtlıyor. 21+ adetlik dev sepetler bu yıl +%29,5 ile en hızlı büyüyen grup oldu.",
            "%15,1 Fiş = %53,4 Ciro",
            "21+ Adet Sepet: +%29,5 Büyüme",
            FILL_VURGU_SARI,
        ),
        (
            "8",
            "'Gece Pazarı' Etkisi: En büyük kırtasiye sepeti akşam 20:00'den sonra kasadan geçiyor!",
            "Sabah 09:00–12:00 arasında kırtasiye sepeti 5,56 adet / 587,7 ₺ (6.313 fiş) iken, akşam 20:00–23:00 arasında (iş çıkışı ailece okul alışverişi) 22.380 fiş kesiliyor (sabahın 3,5 katı!) ve sepet 6,63 adede / 749,9 ₺'ye (+%27,6 daha büyük) çıkıyor.",
            "Sabah 588 ₺ → Gece 750 ₺",
            "Gece Fiş Hacmi Sabahın 3,5 Katı",
            FILL_VURGU_YESIL,
        ),
    ]

    s = 6
    for no, baslik, aciklama, gosterge, etki, vurgu_fill in kartlar:
        ws.merge_cells(start_row=s, start_column=1, end_row=s + 1, end_column=1)
        n = ws.cell(s, 1, no)
        n.font = Font(name="Segoe UI", bold=True, size=12, color="FFFFFF")
        n.fill = FILL_YESIL_BASLIK
        n.alignment = Alignment(horizontal="center", vertical="center")
        ws.cell(s, 1).border = KENAR
        ws.cell(s + 1, 1).border = KENAR

        t = ws.cell(s, 2, baslik)
        t.font = Font(name="Segoe UI", bold=True, size=11, color="0F172A")
        t.fill = vurgu_fill
        t.alignment = Alignment(horizontal="left", vertical="center")
        t.border = KENAR

        g = ws.cell(s, 3, gosterge)
        g.font = Font(name="Segoe UI", bold=True, size=11, color="1E293B")
        g.fill = vurgu_fill
        g.alignment = Alignment(horizontal="center", vertical="center")
        g.border = KENAR

        e = ws.cell(s, 4, etki)
        e.font = Font(name="Segoe UI", bold=True, size=11, color="15803D")
        e.fill = vurgu_fill
        e.alignment = Alignment(horizontal="center", vertical="center")
        e.border = KENAR
        ws.row_dimensions[s].height = 24

        s += 1
        ws.merge_cells(start_row=s, start_column=2, end_row=s, end_column=4)
        a = ws.cell(s, 2, aciklama)
        a.font = Font(name="Segoe UI", size=10, color="334155")
        a.fill = FILL_ZEBRA
        a.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
        for k in range(2, 5):
            ws.cell(s, k).border = KENAR
            ws.cell(s, k).fill = FILL_ZEBRA
        ws.row_dimensions[s].height = 38
        s += 2

    # Tek Cümlelik Toplantı Özeti Kutusu
    ws.merge_cells(start_row=s, start_column=1, end_row=s, end_column=4)
    oz = ws.cell(
        s, 1,
        "🎯 TEK CÜMLELİK TOPLANTI ÖZETİ: Kırtasiyede bu sezon hem müşteri sayısı (+%19,7 fiş) hem sepet büyüklüğü "
        "(gerçek sepette 6,11 → 6,52 adet ve 573 ₺ → 750 ₺, +%31) hem de brüt marj (%40,8 → %43,6) aynı anda büyüdü; "
        "büyümeyi 11+ ürünlük 'okul listesi' sepetleri (+%26) ve 'Kitap + Kırtasiye' çapraz satışı (+%35) sürükledi."
    )
    oz.font = Font(name="Segoe UI", bold=True, size=11, color="1F5B57")
    oz.fill = FILL_VURGU_SARI
    oz.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
    for k in range(1, 5):
        ws.cell(s, k).border = KENAR_TOPLAM
        ws.cell(s, k).fill = FILL_VURGU_SARI
    ws.row_dimensions[s].height = 42


# ==============================================================================
# 2. SAYFA: DÖNEM KIYAS (HAM VERİ vs GERÇEK KIRTASİYE + ÇAPRAZ SEPET)
# ==============================================================================
def sayfa_donem_kiyas(wb: Workbook):
    ws = wb.create_sheet("1_Donem_Kiyas")
    ws.cell(1, 1, "DÖNEM BAZLI BİREBİR (ELMA-ELMA) KARŞILAŞTIRMA — 2025 vs 2026").font = FONT_SAYFA_BASLIK
    ws.cell(2, 1, "Tablo 1A: Ham Kasa Verisi · Tablo 1B: 1 Kuruşluk Hediye Oyun Hamuru Arındırılmış GERÇEK Kırtasiye Sepeti · Tablo 1C: Kırtasiyeli vs Kırtasiyesiz Toplam Sepet").font = FONT_NOT

    # TABLO 1A: HAM VERİ
    ws.cell(4, 1, "TABLO 1A — HAM KASA VERİSİ İLE KIRTASİYE ALT-SEPETİ (Sadece Fişin İçindeki Kırtasiye Kalemleri)").font = FONT_BOLUM
    kol1 = [
        ("Dönem", 26, None),
        ("Yıl", 8, None),
        ("Toplam Perakende Fiş", 16, FMT_ADET),
        ("Kırtasiye İçeren Fiş", 16, FMT_ADET),
        ("Kırtasiye Penetrasyonu", 15, FMT_YUZDE_ORAN),
        ("Kırt. Adet / Fiş", 14, FMT_ONDALIK2),
        ("Kırt. Çeşit / Fiş", 14, FMT_ONDALIK2),
        ("Brüt Kırt. / Fiş (₺)", 16, FMT_TL),
        ("Net Kırt. / Fiş (KDV Dahil)", 18, FMT_TL),
        ("Net Kırt. / Fiş (KDV Hariç)", 18, FMT_TL),
        ("Net Birim Fiyat (KDV Dahil)", 16, FMT_TL),
        ("Kasa İndirim Oranı", 15, FMT_YUZDE_ORAN),
    ]
    baslik_yaz(ws, 5, kol1, fill=FILL_BKM, dondur=True)

    ham_veri = [
        ("Ağustos–Eylül (Okul Sezonu)", 2025, 188720, 97325, 0.5157, 6.08, 4.61, 651.3, 567.9, 494.6, 93.3, 0.128),
        ("Ağustos–Eylül (Okul Sezonu)", 2026, 204212, 116512, 0.5705, 6.26, 4.83, 858.8, 690.9, 600.6, 110.4, 0.195),
        ("Ağustos–Eylül Değişim (YoY)", "Δ%", "=(C7-C6)/C6", "=(D7-D6)/D6", "=E7-E6", "=(F7-F6)/F6", "=(G7-G6)/G6", "=(H7-H6)/H6", "=(I7-I6)/I6", "=(J7-J6)/J6", "=(K7-K6)/K6", "=L7-L6"),
        ("Ağustos", 2025, 68970, 32968, 0.4780, 5.28, 3.86, 565.6, 505.7, 439.8, 95.9, 0.106),
        ("Ağustos", 2026, 80322, 40611, 0.5056, 4.55, 3.42, 643.1, 493.0, 427.4, 108.4, 0.233),
        ("Ağustos Değişim (YoY)", "Δ%", "=(C10-C9)/C9", "=(D10-D9)/D9", "=E10-E9", "=(F10-F9)/F9", "=(G10-G9)/G9", "=(H10-H9)/H9", "=(I10-I9)/I9", "=(J10-J9)/J9", "=(K10-K9)/K9", "=L10-L9"),
        ("Eylül", 2025, 119750, 64357, 0.5374, 6.50, 4.99, 695.3, 599.8, 522.7, 92.3, 0.137),
        ("Eylül", 2026, 123890, 75901, 0.6126, 7.17, 5.58, 974.2, 796.8, 693.2, 111.1, 0.182),
        ("Eylül Değişim (YoY)", "Δ%", "=(C13-C12)/C12", "=(D13-D12)/D12", "=E13-E12", "=(F13-F12)/F12", "=(G13-G12)/G12", "=(H13-H12)/H12", "=(I13-I12)/I12", "=(J13-J12)/J12", "=(K13-K12)/K12", "=L13-L12"),
        ("23–31 Temmuz (Eş Günler)", 2025, 15775, 5977, 0.3789, 3.34, 2.48, 277.5, 256.8, 220.4, 76.9, 0.075),
        ("23–31 Temmuz (Eş Günler)", 2026, 21904, 8798, 0.4017, 3.54, 2.63, 399.5, 328.5, 280.9, 92.8, 0.178),
        ("23–31 Temmuz Değişim (YoY)", "Δ%", "=(C16-C15)/C15", "=(D16-D15)/D15", "=E16-E15", "=(F16-F15)/F15", "=(G16-G15)/G15", "=(H16-H15)/H15", "=(I16-I15)/I15", "=(J16-J15)/J15", "=(K16-K15)/K15", "=L16-L15"),
    ]

    kol1_degisim = [
        ("Dönem", 26, None), ("Yıl", 8, None),
        ("TopFis", 16, FMT_YUZDE_DEGISIM), ("KirtFis", 16, FMT_YUZDE_DEGISIM),
        ("Pen", 15, FMT_YUZDE_DEGISIM), ("Adet", 14, FMT_YUZDE_DEGISIM),
        ("Cesit", 14, FMT_YUZDE_DEGISIM), ("Brut", 16, FMT_YUZDE_DEGISIM),
        ("NetD", 18, FMT_YUZDE_DEGISIM), ("NetH", 18, FMT_YUZDE_DEGISIM),
        ("Brm", 16, FMT_YUZDE_DEGISIM), ("Ind", 15, FMT_YUZDE_DEGISIM),
    ]

    s = 6
    for row in ham_veri:
        is_delta = row[1] == "Δ%"
        s = satir_yaz(
            ws, s,
            kol1_degisim if is_delta else kol1,
            list(row),
            fill=FILL_TOPLAM if is_delta else (FILL_ZEBRA if row[1] == 2026 else None),
            bold=is_delta or row[1] == 2026,
            toplam=is_delta,
        )

    # TABLO 1B: 1 KURUŞLUK OYUN HAMURU ARINDIRILMIŞ GERÇEK SEPET
    s += 1
    ws.cell(s, 1, "TABLO 1B — '1 KURUŞLUK HEDİYE OYUN HAMURU' (stkID=1733557) ARINDIRILMIŞ GERÇEK KIRTASİYE SEPETİ").font = FONT_BOLUM
    s += 1
    kol2 = [
        ("Dönem", 26, None),
        ("Yıl", 8, None),
        ("Ham Kırtasiye Fişi", 16, FMT_ADET),
        ("Sahte Kırt. Fişi (Sadece 0,01₺ Hamur)", 22, FMT_ADET),
        ("GERÇEK Kırtasiye Fişi", 18, FMT_ADET),
        ("Gerçek Penetrasyon", 16, FMT_YUZDE_ORAN),
        ("Ham Adet / Fiş", 14, FMT_ONDALIK2),
        ("GERÇEK Adet / Fiş", 16, FMT_ONDALIK2),
        ("Ham Net ₺ / Fiş", 16, FMT_TL),
        ("GERÇEK Net ₺ / Fiş (KDV Dahil)", 20, FMT_TL),
    ]
    baslik_yaz(ws, s, kol2, fill=FILL_YESIL_BASLIK, dondur=False)
    s += 1

    gercek_veri = [
        ("Ağustos–Eylül (Okul Sezonu)", 2025, 97325, 844, 96481, 0.511, 6.08, 6.11, 567.8, 572.7),
        ("Ağustos–Eylül (Okul Sezonu)", 2026, 116503, 9277, 107226, 0.525, 6.26, 6.52, 690.8, 750.3),
        ("Ağustos–Eylül Gerçek Değişim", "Δ%", "=(C22-C21)/C21", "=(D22-D21)/D21", "=(E22-E21)/E21", "=F22-F21", "=(G22-G21)/G21", "=(H22-H21)/H21", "=(I22-I21)/I21", "=(J22-J21)/J21"),
        ("Ağustos", 2025, 32968, 2, 32966, 0.478, 5.28, 5.27, 505.6, 505.6),
        ("Ağustos", 2026, 40605, 3619, 36986, 0.460, 4.55, 4.74, 492.9, 540.9),
        ("Ağustos Gerçek Değişim", "Δ%", "=(C25-C24)/C24", "=(D25-D24)/D24", "=(E25-E24)/E24", "=F25-F24", "=(G25-G24)/G24", "=(H25-H24)/H24", "=(I25-I24)/I24", "=(J25-J24)/J24"),
        ("Eylül", 2025, 64357, 842, 63515, 0.530, 6.50, 6.54, 599.7, 607.5),
        ("Eylül", 2026, 75898, 5658, 70240, 0.567, 7.17, 7.46, 796.7, 860.6),
        ("Eylül Gerçek Değişim", "Δ%", "=(C28-C27)/C27", "=(D28-D27)/D27", "=(E28-E27)/E27", "=F28-F27", "=(G28-G27)/G27", "=(H28-H27)/H27", "=(I28-I27)/I27", "=(J28-J27)/J27"),
    ]
    kol2_deg = [
        ("Dönem", 26, None), ("Yıl", 8, None),
        ("HamF", 16, FMT_YUZDE_DEGISIM), ("SahteF", 22, FMT_YUZDE_DEGISIM),
        ("GercF", 18, FMT_YUZDE_DEGISIM), ("GercP", 16, FMT_YUZDE_DEGISIM),
        ("HamA", 14, FMT_YUZDE_DEGISIM), ("GercA", 16, FMT_YUZDE_DEGISIM),
        ("HamT", 16, FMT_YUZDE_DEGISIM), ("GercT", 20, FMT_YUZDE_DEGISIM),
    ]
    for row in gercek_veri:
        is_delta = row[1] == "Δ%"
        s = satir_yaz(
            ws, s,
            kol2_deg if is_delta else kol2,
            list(row),
            fill=FILL_VURGU_SARI if is_delta else (FILL_ZEBRA if row[1] == 2026 else None),
            bold=is_delta or row[1] == 2026,
            toplam=is_delta,
        )

    # TABLO 1C: KIRTASİYELİ FİŞ vs KIRTASİYESİZ FİŞ TOPLAM SEPET BÜYÜKLÜĞÜ
    s += 1
    ws.cell(s, 1, "TABLO 1C — KIRTASİYE İÇEREN FİŞİN TÜM SEPETİ vs KIRTASİYE İÇERMEYEN FİŞİN TÜM SEPETİ").font = FONT_BOLUM
    s += 1
    kol3 = [
        ("Dönem", 26, None),
        ("Yıl", 8, None),
        ("Kırtasiyeli Fiş: Tüm Sepet Adet", 20, FMT_ONDALIK2),
        ("Kırtasiyesiz Fiş: Tüm Sepet Adet", 20, FMT_ONDALIK2),
        ("Sepet Adet Çarpanı (Kırtlı/Kırtsız)", 22, FMT_CARPAN),
        ("Kırtasiyeli Fiş: Tüm Sepet Net ₺", 20, FMT_TL),
        ("Kırtasiyesiz Fiş: Tüm Sepet Net ₺", 20, FMT_TL),
        ("Sepet Tutar Çarpanı (Kırtlı/Kırtsız)", 22, FMT_CARPAN),
    ]
    baslik_yaz(ws, s, kol3, fill=FILL_ALT_BASLIK, dondur=False)
    s += 1
    capraz_veri = [
        ("Ağustos–Eylül (Okul Sezonu)", 2025, 9.31, 3.54, "=C33/D33", 1074.7, 710.1, "=F33/G33"),
        ("Ağustos–Eylül (Okul Sezonu)", 2026, 9.72, 3.25, "=C34/D34", 1402.5, 734.4, "=F34/G34"),
        ("Ağustos", 2025, 8.14, 3.36, "=C35/D35", 906.1, 623.1, "=F35/G35"),
        ("Ağustos", 2026, 7.92, 3.09, "=C36/D36", 1115.8, 610.2, "=F36/G36"),
        ("Eylül", 2025, 9.91, 3.65, "=C37/D37", 1161.1, 766.7, "=F37/G37"),
        ("Eylül", 2026, 10.68, 3.39, "=C38/D38", 1555.9, 837.2, "=F38/G38"),
    ]
    for row in capraz_veri:
        s = satir_yaz(ws, s, kol3, list(row), fill=FILL_VURGU_YESIL if row[1] == 2026 else None, bold=row[1] == 2026)

    s += 1
    anlatim_kutusu(
        ws, s,
        "Bu Sayfayı Toplantıda Nasıl Anlatabilirsiniz?",
        [
            "1) 'Kırtasiye sepeti büyüdü mü?' → Evet: Okul sezonunda (Ağustos–Eylül) fiş başı kırtasiye adedi 6,08'den 6,26'ya (+%3,0), 1 kuruşluk hediye oyun hamuru fişleri temizlendiğinde ise 6,11'den 6,52 adede (+%6,7) çıktı.",
            "2) 'Ağustos'ta neden düşüş görünüyordu?' → 5 Ağustos 2026'da başlayan 0,01 ₺'lik LETS Oyun Hamuru promosyonu yüzünden! Sadece kitap alıp 1 kuruşa hediye oyun hamuru verilen 3.619 fiş '0,01 ₺'lik kırtasiye sepeti' sayıldığı için ortalamayı aşağı çekti. O fişler ayıklanınca Ağustos kırtasiye sepeti 505,6 ₺'den 540,9 ₺'ye (+%7,0) büyüdü.",
            "3) 'Kırtasiye mağaza için neden kritik?' → Tablo 1C'de görüldüğü gibi, içine 1 tane bile kırtasiye giren fişin toplam büyüklüğü 9,72 adet ve 1.402,5 ₺ iken, kırtasiye girmeyen fiş 3,25 adet ve 734,4 ₺'de kalıyor (Adette 3,0 kat, tutarda 1,9 kat fark!).",
        ],
        genislik_kolon=10,
    )


# ==============================================================================
# 3. SAYFA: MAĞAZA KIRILIMI (FSM · ÖZLÜCE · İST. YOLU)
# ==============================================================================
def sayfa_magaza_kirilimi(wb: Workbook):
    ws = wb.create_sheet("2_Magaza_Kirilimi")
    ws.cell(1, 1, "MAĞAZA BAZLI KIRTASİYE SEPET BÜYÜKLÜĞÜ (AĞUSTOS–EYLÜL 2025 vs 2026)").font = FONT_SAYFA_BASLIK
    ws.cell(2, 1, "Üç mağazanın tamamında hem kırtasiye penetrasyonu hem fiş başı kırtasiye adedi hem de TL sepet büyüklüğü artmıştır.").font = FONT_NOT

    kol = [
        ("Mağaza", 22, None),
        ("Yıl", 8, None),
        ("Toplam Perakende Fiş", 16, FMT_ADET),
        ("Kırtasiye İçeren Fiş", 16, FMT_ADET),
        ("Kırtasiye Penetrasyonu", 16, FMT_YUZDE_ORAN),
        ("Kırt. Adet / Fiş", 14, FMT_ONDALIK2),
        ("Kırt. Çeşit / Fiş", 14, FMT_ONDALIK2),
        ("Net Kırt. / Fiş (KDV Dahil)", 18, FMT_TL),
        ("Net Kırt. / Fiş (KDV Hariç)", 18, FMT_TL),
        ("Kırt. Birim Fiyat (KDV Dahil)", 16, FMT_TL),
        ("Kırtlı Fişin Tüm Sepet Adedi", 18, FMT_ONDALIK2),
        ("Kırtlı Fişin Tüm Sepet Net ₺", 18, FMT_TL),
    ]
    baslik_yaz(ws, 4, kol, fill=FILL_BKM, dondur=True)

    kol_deg = [
        ("Mağaza", 22, None), ("Yıl", 8, None),
        ("TopF", 16, FMT_YUZDE_DEGISIM), ("KirtF", 16, FMT_YUZDE_DEGISIM),
        ("Pen", 16, FMT_YUZDE_DEGISIM), ("Adet", 14, FMT_YUZDE_DEGISIM),
        ("Cesit", 14, FMT_YUZDE_DEGISIM), ("NetD", 18, FMT_YUZDE_DEGISIM),
        ("NetH", 18, FMT_YUZDE_DEGISIM), ("Brm", 16, FMT_YUZDE_DEGISIM),
        ("TumA", 18, FMT_YUZDE_DEGISIM), ("TumT", 18, FMT_YUZDE_DEGISIM),
    ]

    veriler = [
        ("FSM Mağaza", 2025, 66195, 32290, 0.4878, 5.35, 4.03, 466.5, 405.6, 87.1, 8.16, 895.3),
        ("FSM Mağaza", 2026, 69522, 38279, 0.5506, 5.49, 4.27, 566.5, 491.8, 103.1, 8.52, 1222.6),
        ("FSM Değişim (YoY)", "Δ%", "=(C6-C5)/C5", "=(D6-D5)/D5", "=E6-E5", "=(F6-F5)/F5", "=(G6-G5)/G5", "=(H6-H5)/H5", "=(I6-I5)/I5", "=(J6-J5)/J5", "=(K6-K5)/K5", "=(L6-L5)/L5"),
        ("Özlüce Mağaza", 2025, 76455, 40106, 0.5246, 5.96, 4.53, 571.7, 497.5, 95.9, 9.32, 1078.8),
        ("Özlüce Mağaza", 2026, 80632, 48286, 0.5988, 6.20, 4.81, 685.2, 595.5, 110.5, 9.83, 1424.0),
        ("Özlüce Değişim (YoY)", "Δ%", "=(C9-C8)/C8", "=(D9-D8)/D8", "=E9-E8", "=(F9-F8)/F8", "=(G9-G8)/G8", "=(H9-H8)/H8", "=(I9-I8)/I8", "=(J9-J8)/J8", "=(K9-K8)/K8", "=(L9-L8)/L8"),
        ("İstanbul Yolu Mağaza", 2025, 46070, 24929, 0.5411, 7.22, 5.48, 693.1, 605.1, 96.0, 10.78, 1300.6),
        ("İstanbul Yolu Mağaza", 2026, 54058, 29947, 0.5540, 7.33, 5.56, 859.2, 747.7, 117.2, 11.08, 1597.8),
        ("İst. Yolu Değişim (YoY)", "Δ%", "=(C12-C11)/C11", "=(D12-D11)/D11", "=E12-E11", "=(F12-F11)/F11", "=(G12-G11)/G11", "=(H12-H11)/H11", "=(I12-I11)/I11", "=(J12-J11)/J11", "=(K12-K11)/K11", "=(L12-L11)/L11"),
        ("3 MAĞAZA TOPLAM / ORT.", 2025, 188720, 97325, 0.5157, 6.08, 4.61, 567.9, 494.6, 93.3, 9.31, 1074.7),
        ("3 MAĞAZA TOPLAM / ORT.", 2026, 204212, 116512, 0.5705, 6.26, 4.83, 690.9, 600.6, 110.4, 9.72, 1402.5),
        ("TOPLAM DEĞİŞİM (YoY)", "Δ%", "=(C15-C14)/C14", "=(D15-D14)/D14", "=E15-E14", "=(F15-F14)/F14", "=(G15-G14)/G14", "=(H15-H14)/H14", "=(I15-I14)/I14", "=(J15-J14)/J14", "=(K15-K14)/K14", "=(L15-L14)/L14"),
    ]

    s = 5
    for row in veriler:
        is_delta = row[1] == "Δ%"
        is_top = str(row[0]).startswith("3 MAĞAZA") or str(row[0]).startswith("TOPLAM")
        s = satir_yaz(
            ws, s,
            kol_deg if is_delta else kol,
            list(row),
            fill=FILL_VURGU_SARI if (is_delta and is_top) else (FILL_TOPLAM if is_delta else (FILL_ZEBRA if row[1] == 2026 else None)),
            bold=is_delta or is_top or row[1] == 2026,
            toplam=is_delta,
        )

    s += 1
    ws.cell(s, 1, "TABLO 2B — SINAV OKULLARI FİŞLERİ (DocumentsTypeId=8) DAHİL vs HARİÇ vs SADECE SINAV KARŞILAŞTIRMASI (Ağu–Eyl, 0,01₺ Hamur Hariç)").font = FONT_BOLUM
    s += 1
    kol_snv = [
        ("Kapsam / Kanal", 28, None),
        ("Yıl", 8, None),
        ("Toplam Fiş", 14, FMT_ADET),
        ("Kırtasiye Fişi", 14, FMT_ADET),
        ("Kırt. Penetrasyonu", 16, FMT_YUZDE_ORAN),
        ("Kırt. Adet / Fiş", 14, FMT_ONDALIK2),
        ("Kırt. Çeşit / Fiş", 14, FMT_ONDALIK2),
        ("Net Kırt. / Fiş (₺)", 16, FMT_TL),
        ("Kırtlı Fiş Tüm Sepet (₺)", 20, FMT_TL),
        ("Kırtasiye Net Ciro (₺)", 18, FMT_TL_TAM),
        ("İndirim Oranı", 14, FMT_YUZDE_ORAN),
        ("Kanal Özelliği", 28, None),
    ]
    kol_snv_deg = [
        ("Kapsam / Kanal", 28, None), ("Yıl", 8, None),
        ("TopF", 14, FMT_YUZDE_DEGISIM), ("KirtF", 14, FMT_YUZDE_DEGISIM),
        ("Pen", 16, FMT_YUZDE_DEGISIM), ("Adet", 14, FMT_YUZDE_DEGISIM),
        ("Cesit", 14, FMT_YUZDE_DEGISIM), ("NetK", 16, FMT_YUZDE_DEGISIM),
        ("TumT", 20, FMT_YUZDE_DEGISIM), ("Ciro", 18, FMT_YUZDE_DEGISIM),
        ("Ind", 14, FMT_YUZDE_DEGISIM), ("Not", 28, None),
    ]
    baslik_yaz(ws, s, kol_snv, fill=FILL_YESIL_BASLIK, dondur=False)
    s += 1

    snv_veriler = [
        ("Perakende (Sınav Hariç — 1,2,6,7)", 2025, 188720, 96481, 0.5112, 6.11, 4.63, 572.7, 1069.9, 55253874, 0.128, "3 Mağaza Normal Perakende"),
        ("Perakende (Sınav Hariç — 1,2,6,7)", 2026, 204212, 107226, 0.5251, 6.52, 5.05, 750.3, 1352.5, 80452328, 0.195, "3 Mağaza Normal Perakende"),
        ("Perakende Değişim (YoY)", "Δ%", -0.0821, 0.1114, 0.0138, 0.0671, 0.0907, 0.3101, 0.2641, 0.4560, 0.067, "Saf Perakende Sepet +%31,0"),
        ("Sadece Sınav Fişleri (Belge=8)", 2025, 8572, 5701, 0.6651, 21.27, 18.02, 2492.0, 45786.7, 14207160, 0.001, "%100 İstanbul Yolu Mağaza"),
        ("Sadece Sınav Fişleri (Belge=8)", 2026, 7497, 5299, 0.7068, 21.73, 19.34, 3623.5, 60009.0, 19200786, 0.000, "%100 İstanbul Yolu Mağaza"),
        ("Sadece Sınav Değişim (YoY)", "Δ%", -0.1254, -0.0705, 0.0417, 0.0216, 0.0733, 0.4541, 0.3106, 0.3515, -0.001, "Perakendenin 4,8x Katı Sepet!"),
        ("TÜM MAĞAZA (Sınav Dahil — 1..8)", 2025, 197292, 102182, 0.5179, 6.96, 5.38, 679.8, 3564.8, 69461034, 0.105, "Sınav Payı: %20,5 Ciro"),
        ("TÜM MAĞAZA (Sınav Dahil — 1..8)", 2026, 211709, 112525, 0.5315, 7.24, 5.72, 885.6, 4114.8, 99653114, 0.163, "Sınav Payı: %19,3 Ciro (~100M ₺)"),
        ("TÜM MAĞAZA DEĞİŞİM (YoY)", "Δ%", 0.0731, 0.1012, 0.0136, 0.0402, 0.0632, 0.3027, 0.1543, 0.4347, 0.058, "Toplam Kırtasiye ~100M ₺ (+%43,5)"),
        ("İst. Yolu (Sınav Hariç Perakende)", 2025, 46070, 24912, 0.5407, 7.22, 5.48, 693.6, 1300.5, 17278947, 0.125, "İst. Yolu Saf Perakende"),
        ("İst. Yolu (Sınav Hariç Perakende)", 2026, 54058, 28725, 0.5314, 7.51, 5.71, 895.0, 1574.1, 25708670, 0.189, "İst. Yolu Saf Perakende (+%29,0 ₺/Fiş)"),
        ("İst. Yolu (Sınav Dahil Toplam)", 2025, 54642, 30613, 0.5602, 9.84, 7.82, 1028.5, 9585.2, 31486107, 0.075, "İst. Yolu Kırtasiyesinin %45,1'i Sınav"),
        ("İst. Yolu (Sınav Dahil Toplam)", 2026, 61555, 34024, 0.5527, 9.72, 7.83, 1320.0, 10675.4, 44909456, 0.119, "İst. Yolu Kırtasiyesinin %42,8'i Sınav"),
    ]
    # Düzeltme: Perakende YoY Toplam Fiş +(204212-188720)/188720 = +0.0821
    snv_veriler[2] = ("Perakende Değişim (YoY)", "Δ%", 0.0821, 0.1114, 0.0138, 0.0671, 0.0907, 0.3101, 0.2641, 0.4560, 0.067, "Saf Perakende Sepet +%31,0")

    for row in snv_veriler:
        is_delta = row[1] == "Δ%"
        is_top = str(row[0]).startswith("TÜM MAĞAZA")
        s = satir_yaz(
            ws, s,
            kol_snv_deg if is_delta else kol_snv,
            list(row),
            fill=FILL_VURGU_SARI if (is_delta and is_top) else (FILL_TOPLAM if is_delta else (FILL_VURGU_YESIL if row[1] == 2026 else None)),
            bold=is_delta or is_top or row[1] == 2026,
            toplam=is_delta,
        )

    # TABLO 2C: SINAV FİŞLERİNDE EN ÇOK SATILAN TOP 12 KIRTASİYE ÜRÜNÜ
    s += 1
    ws.cell(s, 1, "TABLO 2C — SINAV FİŞLERİNDE (DocumentsTypeId=8) EN ÇOK CİRO YAPAN TOP 12 KIRTASİYE ÜRÜNÜ (Ağustos–Eylül 2026)").font = FONT_BOLUM
    s += 1
    kol_snv_sku = [
        ("Sıra", 6, FMT_ADET),
        ("Stok Kodu", 12, None),
        ("Ürün Adı (Sınav Paketlerinin İçindeki Kırtasiye Ürünleri)", 44, None),
        ("Alt Kategori (ktgr3)", 20, None),
        ("Sınav Fiş Sayısı", 16, FMT_ADET),
        ("Sınav Penetrasyonu", 16, FMT_YUZDE_ORAN),
        ("Satılan Adet", 14, FMT_ADET),
        ("Net Birim Fiyat (₺)", 16, FMT_TL),
        ("2025 Sınav Ciro (₺)", 16, FMT_TL_TAM),
        ("2026 Sınav Ciro (₺)", 16, FMT_TL_TAM),
        ("YoY Ciro Δ%", 14, FMT_YUZDE_DEGISIM),
        ("Sınav Sepetindeki Rolü", 26, None),
    ]
    baslik_yaz(ws, s, kol_snv_sku, fill=FILL_ALT_BASLIK, dondur=False)
    s += 1

    snv_skular = [
        (1, "1731872", "Lets Başlangıç Okul Seti 6 Yaş", "Kırtasiye Seti", 360, 360/5299, 362, 2296.9, 557120, 831484, (831484-557120)/557120, "Anaokulu Hazır Kırtasiye Paketi"),
        (2, "1733082", "Let's Fırça Uçlu Keçeli Kalem 12 Renk", "Keçeli Kalem", 1605, 1605/5299, 1647, 425.1, 412350, 700099, (700099-412350)/412350, "Her 3 Sınav Fişinin 1'inde Var"),
        (3, "1731871", "Lets Başlangıç Okul Seti 5 Yaş", "Kırtasiye Seti", 274, 274/5299, 274, 2495.1, 468900, 683666, (683666-468900)/468900, "Anaokulu Hazır Kırtasiye Paketi"),
        (4, "1718236", "Let's Jumbo Boyama Kalemi 12 Renk", "Kuru Boya Kalemi", 1528, 1528/5299, 1564, 424.9, 489120, 664517, (664517-489120)/489120, "Standart Okul Listesi Boyası"),
        (5, "317618", "BuBu Eva Simli 50x70 10 Renk", "Sanatsal Malzeme", 827, 827/5299, 868, 742.0, 401250, 644016, (644016-401250)/401250, "El İşi / Etkinlik Paketi"),
        (6, "9870", "Ve-Ge Fotokopi Kağıdı A4 500'lü", "Fotokopi Kağıdı", 3133, 3133/5299, 3691, 150.0, 498600, 553581, (553581-498600)/498600, "%59,1 Penetrasyon (Rekor!)"),
        (7, "54929", "Play-Doh Pastel Boya Çantalı 24 Renk", "Pastel Boya", 1536, 1536/5299, 1569, 340.1, 385400, 533639, (533639-385400)/385400, "Standart Okul Listesi Pasteli"),
        (8, "1604865", "Keskin Color 50x70 10'lu Rulo Fon Kartonu", "Fon Kartonu", 1862, 1862/5299, 2376, 199.7, 356800, 474439, (474439-356800)/356800, "%35,1 Penetrasyon · Kağıt"),
        (9, "1719471", "Laminasyon Filmi A4 25'li Paket", "Dosyalama / Sarf", 1412, 1412/5299, 1465, 286.4, 295400, 419548, (419548-295400)/295400, "A3 ile Birlikte 810K ₺ Ciro!"),
        (10, "1731870", "Lets Başlangıç Okul Seti 3-4 Yaş", "Kırtasiye Seti", 199, 199/5299, 199, 2081.3, 284500, 414185, (414185-284500)/284500, "Kreş/Anaokulu Hazır Set"),
        (11, "1719472", "Laminasyon Filmi A3 15'li Paket", "Dosyalama / Sarf", 1358, 1358/5299, 1409, 277.1, 276100, 390497, (390497-276100)/276100, "Okul Etkinlik Kaplama Sarfı"),
        (12, "1524903", "Play-Doh Oyun Hamuru 4'lü Klasik", "Oyun Hamuru", 1485, 1485/5299, 1532, 241.2, 268900, 369518, (369518-268900)/268900, "Sınav Listesi Oyun Hamuru"),
    ]
    for row in snv_skular:
        s = satir_yaz(ws, s, kol_snv_sku, list(row), fill=FILL_VURGU_SARI if row[0] in (1, 6) else (FILL_ZEBRA if row[0] % 2 == 0 else None), bold=row[0] in (1, 6))

    s += 1
    anlatim_kutusu(
        ws, s,
        "Mağaza Farklılıkları & Sınav Fişleri (DocumentsTypeId=8) Ne Söylüyor?",
        [
            "• SINAV FİŞLERİ NEDEN AYRI İZLENMELİ? Sınav Okulları fişlerinin %100'ü İstanbul Yolu mağazasından kesiliyor (2026 Ağu–Eyl: 7.497 fişin 5.299'unda kırtasiye var = %70,7 penetrasyon!). Bir Sınav fişinin içinde ortalama 21,73 adet ve 3.623,5 ₺ kırtasiye (perakendenin 4,8 katı!), tüm fişte ise kitap paketiyle birlikte 60.009 ₺ var.",
            "• 100 MİLYON ₺ BARAJI: Sınav fişleri dahil edildiğinde BKM'nin 3 mağaza kırtasiye cirosu 2025'te 69,46 Milyon ₺'den 2026'da 99,65 Milyon ₺'ye (+%43,5) ulaşıyor! Sınav fişleri tek başına 19,20 Milyon ₺ (+%35,1) kırtasiye cirosu üretiyor.",
            "• AĞUSTOS TAKVİM KAYMASI (SİMPSON PARADOKSU): 2025'te Sınav fişlerinin %44'ü Ağustos'ta kesilmişti; 2026'da kayıtlar Eylül'e kayınca Ağustos Sınav kırtasiye fişi 2.529'dan 1.453'e (-%42,5) düştü, Eylül ise +%21,2 arttı. Bu yüzden Sınav Dahil bakınca Ağustos sepeti yatay (-%0,3) gibi yanıltıyor; oysa Sınav Hariç Perakende (+%7,0) ve Sadece Sınav (+%41,3) kendi içinde büyüdü!",
            "• SINAV FİŞİNDE NE SATILIYOR? Sınav kırtasiye fişlerinin %59,1'inde (3.133 fiş) A4 Fotokopi Kağıdı, 833 fişte ise tanesi 2.081–2.495 ₺ olan 'Lets Başlangıç Okul Seti (3-4, 5, 6 Yaş)' var (sadece bu 3 set 1,93 Milyon ₺ ciro yapıyor).",
        ],
        genislik_kolon=12,
    )



# ==============================================================================
# 4. SAYFA: SEPET KOMPOZİSYONU ("EVLİLİK TABLOSU") & SAAT DİLİMİ ("GECE PAZARI")
# ==============================================================================
def sayfa_kompozisyon_ve_saat(wb: Workbook):
    ws = wb.create_sheet("3_Sepet_Kompozisyon_Saat")
    ws.cell(1, 1, "SEPET KOMPOZİSYONU (ÇAPRAZ SATIŞ EVLİLİĞİ) VE SAAT DİLİMİ ANALİZİ").font = FONT_SAYFA_BASLIK
    ws.cell(2, 1, "Kırtasiye tek başına alındığında küçük bir sepettir (3,80 adet); yanına Kitap/Hazırlık/Oyuncak girdiğinde kırtasiyenin kendi adedi bile 2 katına çıkar!").font = FONT_NOT

    # TABLO 3A: SEPET KOMPOZİSYONU
    ws.cell(4, 1, "TABLO 3A — KIRTASİYE FİŞLERİNİN KATEGORİ KOMPOZİSYONU (AĞUSTOS–EYLÜL 2025 vs 2026)").font = FONT_BOLUM
    kol_a = [
        ("Sepet Kompozisyonu (Fişte Ne Var?)", 34, None),
        ("Fiş 2025", 13, FMT_ADET),
        ("Fiş 2026", 13, FMT_ADET),
        ("Fiş Artışı (YoY)", 15, FMT_YUZDE_DEGISIM),
        ("2026 Fiş Payı", 14, FMT_YUZDE_ORAN),
        ("2025 Kırt. Adet/Fiş", 16, FMT_ONDALIK2),
        ("2026 Kırt. Adet/Fiş", 16, FMT_ONDALIK2),
        ("2026 Tüm Sepet Adet/Fiş", 18, FMT_ONDALIK2),
        ("2026 Kırt. Net ₺/Fiş", 18, FMT_TL),
        ("2026 Tüm Fiş Net ₺", 18, FMT_TL),
        ("Saf Kırtasiyeye Göre Çarpan", 20, FMT_CARPAN),
    ]
    baslik_yaz(ws, 5, kol_a, fill=FILL_BKM, dondur=True)

    komp_veri = [
        ("1) Sadece Kırtasiye (Saf Kırtasiye Fişi)", 23368, 24952, "=(C6-B6)/B6", 0.214, 3.39, 3.80, 3.80, 474.9, 475.0, "=J6/$J$6"),
        ("2) Kırtasiye + Kitap / Çocuk Kitabı", 18534, 25098, "=(C7-B7)/B7", 0.215, 5.35, 5.57, 11.60, 583.0, 1677.5, "=J7/$J$6"),
        ("3) Kırtasiye + Hazırlık Kitabı", 15200, 17690, "=(C8-B8)/B8", 0.152, 6.36, 6.01, 10.69, 591.8, 2104.8, "=J8/$J$6"),
        ("4) Kırtasiye + Hazırlık + Kitap (Tam Okul Paketi)", 6769, 7312, "=(C9-B9)/B9", 0.063, 7.41, 7.63, 16.12, 798.2, 2917.5, "=J9/$J$6"),
        ("5) Kırtasiye + Oyuncak / Hediyelik / Diğer", 33454, 41451, "=(C10-B10)/B10", 0.356, 7.98, 8.03, 10.61, 909.4, 1227.4, "=J10/$J$6"),
        ("TOPLAM / ORTALAMA KIRTASİYELİ FİŞ", 97325, 116503, "=(C11-B11)/B11", 1.000, 6.08, 6.26, 9.72, 690.9, 1402.5, "=J11/$J$6"),
    ]
    s = 6
    for idx, row in enumerate(komp_veri):
        is_top = idx == len(komp_veri) - 1
        fill = FILL_TOPLAM if is_top else (FILL_VURGU_YESIL if idx in (1, 3, 4) else None)
        s = satir_yaz(ws, s, kol_a, list(row), fill=fill, bold=is_top or idx in (1, 3), toplam=is_top)

    # TABLO 3B: SAAT DİLİMİ ("GECE PAZARI")
    s += 2
    ws.cell(s, 1, "TABLO 3B — GÜNÜN SAAT DİLİMLERİNE GÖRE KIRTASİYE SEPET BÜYÜKLÜĞÜ ('GECE PAZARI' ETKİSİ)").font = FONT_BOLUM
    s += 1
    kol_b = [
        ("Saat Dilimi", 34, None),
        ("2025 Kırt. Fişi", 14, FMT_ADET),
        ("2026 Kırt. Fişi", 14, FMT_ADET),
        ("Fiş Artışı (YoY)", 15, FMT_YUZDE_DEGISIM),
        ("2026 Fiş Payı", 14, FMT_YUZDE_ORAN),
        ("2025 Kırt. Adet/Fiş", 16, FMT_ONDALIK2),
        ("2026 Kırt. Adet/Fiş", 16, FMT_ONDALIK2),
        ("2025 Kırt. Net ₺/Fiş", 18, FMT_TL),
        ("2026 Kırt. Net ₺/Fiş", 18, FMT_TL),
        ("2026 Tüm Fiş Net ₺", 18, FMT_TL),
        ("Sabaha Göre Kırt. ₺ Farkı", 20, FMT_YUZDE_DEGISIM),
    ]
    baslik_yaz(ws, s, kol_b, fill=FILL_YESIL_BASLIK, dondur=False)
    s += 1
    ilk_saat_satir = s
    saat_veri = [
        ("1) Sabah (09:00 – 11:59)", 5425, 6313, f"=(C{s}-B{s})/B{s}", 6313 / 116503, 5.76, 5.56, 519.6, 587.7, 1277.0, 0.0),
        ("2) Öğle (12:00 – 16:59)", 40233, 48976, f"=(C{s+1}-B{s+1})/B{s+1}", 48976 / 116503, 6.09, 6.30, 567.6, 691.8, 1408.4, f"=(I{s+1}-$I${ilk_saat_satir})/$I${ilk_saat_satir}"),
        ("3) Akşamüstü (17:00 – 19:59)", 32499, 38834, f"=(C{s+2}-B{s+2})/B{s+2}", 38834 / 116503, 5.90, 6.11, 552.7, 672.3, 1384.6, f"=(I{s+2}-$I${ilk_saat_satir})/$I${ilk_saat_satir}"),
        ("4) Gece (20:00 – 23:00) ★ ZİRVE SEPET", 19168, 22380, f"=(C{s+3}-B{s+3})/B{s+3}", 22380 / 116503, 6.47, 6.63, 607.5, 749.9, 1456.0, f"=(I{s+3}-$I${ilk_saat_satir})/$I${ilk_saat_satir}"),
    ]
    for idx, row in enumerate(saat_veri):
        s = satir_yaz(ws, s, kol_b, list(row), fill=FILL_VURGU_SARI if idx == 3 else (FILL_ZEBRA if idx % 2 == 1 else None), bold=idx == 3)

    s += 1
    anlatim_kutusu(
        ws, s,
        "Bu İki Tablodan Çıkan Operasyonel ve Ticari Kararlar",
        [
            "• Çapraz Yerleşim (Cross-Merchandising) Fırsatı: 'Kırtasiye + Kitap' içeren fiş sayısı bu yıl +%35,4 patladı (18.534 → 25.098 fiş) ve fiş tutarı 475 ₺'den 1.677,5 ₺'ye (3,5 katına) çıkıyor. Kitap ve hazırlık reyonlarının çıkış koridoruna konulacak seçili kırtasiye paketleri doğrudan sepeti büyütür.",
            "• Gece Vardiyası (20:00–23:00) Kasa Planlaması: Sabah 09:00–12:00 arasında 6.313 kırtasiye fişi kesilirken, akşam 20:00'den sonra 22.380 fiş (sabahın 3,5 katı!) kesiliyor ve her bir fiş sabahtan +%27,6 daha büyük (6,63 adet / 749,9 ₺ kırtasiye, toplam fiş 1.456 ₺). İş çıkışı ailece gelen 'büyük okul sepeti' müşterisi için akşam 20:00–22:30 arası tam kasa kapasitesi şarttır.",
        ],
        genislik_kolon=11,
    )


# ==============================================================================
# 5. SAYFA: ADET KOVALARI (PARETO) & KAMPANYA KIRILIMI
# ==============================================================================
def sayfa_kovalar_ve_kampanya(wb: Workbook):
    ws = wb.create_sheet("4_Kovalar_ve_Kampanya")
    ws.cell(1, 1, "SEPET ADET KOVALARI (PARETO DAĞILIMI) VE KAMPANYA ETKİSİ (AĞUSTOS–EYLÜL)").font = FONT_SAYFA_BASLIK
    ws.cell(2, 1, "Kırtasiye fişlerinin medyanı 3 adettir; ancak 11+ adetlik %15,1'lik 'Okul Listesi' müşterisi toplam kırtasiye cirosunun %53,4'ünü tek başına üretir!").font = FONT_NOT

    # TABLO 4A: SEPET ADET KOVALARI
    ws.cell(4, 1, "TABLO 4A — KIRTASİYE SEPET BÜYÜKLÜĞÜ ADET KOVALARI (AĞUSTOS–EYLÜL 2025 vs 2026)").font = FONT_BOLUM
    kol_k = [
        ("Sepetteki Kırtasiye Adet Kovası", 28, None),
        ("Fiş 2025", 13, FMT_ADET),
        ("Fiş 2026", 13, FMT_ADET),
        ("Fiş Artışı (YoY)", 15, FMT_YUZDE_DEGISIM),
        ("2026 Fiş Payı", 14, FMT_YUZDE_ORAN),
        ("2025 Top. Kırt. Adet", 17, FMT_ADET),
        ("2026 Top. Kırt. Adet", 17, FMT_ADET),
        ("2026 Adet Payı", 14, FMT_YUZDE_ORAN),
        ("2026 Kırt. Net Ciro (₺)", 19, FMT_TL_TAM),
        ("2026 Ciro Payı", 14, FMT_YUZDE_ORAN),
        ("2025 Ort. Kırt. ₺/Fiş", 17, FMT_TL),
        ("2026 Ort. Kırt. ₺/Fiş", 17, FMT_TL),
    ]
    baslik_yaz(ws, 5, kol_k, fill=FILL_BKM, dondur=True)

    kova_veri = [
        ("1) 1 Adet Kırtasiye", 28666, 35791, "=(C6-B6)/B6", "=C6/$C$12", 28666, 35791, "=G6/$G$12", 5437830, "=I6/$I$12", 158.9, 151.9),
        ("2) 2–3 Adet Kırtasiye (Medyan Kova)", 28247, 32139, "=(C7-B7)/B7", "=C7/$C$12", 67249, 76618, "=G7/$G$12", 11038380, "=I7/$I$12", 270.9, 343.5),
        ("3) 4–5 Adet Kırtasiye", 13196, 15257, "=(C8-B8)/B8", "=C8/$C$12", 58330, 67478, "=G8/$G$12", 7991449, "=I8/$I$12", 430.1, 523.8),
        ("4) 6–10 Adet Kırtasiye", 13240, 15690, "=(C9-B9)/B9", "=C9/$C$12", 99959, 118626, "=G9/$G$12", 13074440, "=I9/$I$12", 697.3, 833.3),
        ("5) 11–20 Adet (Okul Listesi)", 7849, 9702, "=(C10-B10)/B10", "=C10/$C$12", 113741, 141068, "=G10/$G$12", 14873952, "=I10/$I$12", 1290.8, 1533.1),
        ("6) 21+ Adet (Tam Okul Listesi ★)", 6127, 7933, "=(C11-B11)/B11", "=C11/$C$12", 224204, 289638, "=G11/$G$12", 28082296, "=I11/$I$12", 2941.9, 3539.9),
        ("TOPLAM KIRTASİYELİ FİŞ", 97325, 116512, "=(C12-B12)/B12", 1.0, 592149, 729219, 1.0, 80498347, 1.0, 567.9, 690.9),
    ]
    s = 6
    for idx, row in enumerate(kova_veri):
        is_top = idx == len(kova_veri) - 1
        fill = FILL_TOPLAM if is_top else (FILL_VURGU_YESIL if idx in (4, 5) else (FILL_VURGU_SARI if idx == 0 else None))
        s = satir_yaz(ws, s, kol_k, list(row), fill=fill, bold=is_top or idx in (4, 5), toplam=is_top)

    # TABLO 4B: KAMPANYA KIRILIMI
    s += 2
    ws.cell(s, 1, "TABLO 4B — KAMPANYA GRUBUNA GÖRE KIRTASİYE SEPET BÜYÜKLÜĞÜ (AĞUSTOS–EYLÜL 2025 vs 2026)").font = FONT_BOLUM
    s += 1
    kol_c = [
        ("Kampanya Grubu", 28, None),
        ("Yıl", 8, None),
        ("Kırtasiye Fişi", 15, FMT_ADET),
        ("Fiş Payı", 13, FMT_YUZDE_ORAN),
        ("Kırt. Adet / Fiş", 15, FMT_ONDALIK2),
        ("Tüm Sepet Adet / Fiş", 18, FMT_ONDALIK2),
        ("Kırt. Net ₺ / Fiş", 17, FMT_TL),
        ("Tüm Sepet Net ₺ / Fiş", 19, FMT_TL),
        ("Kırtasiye İndirim Oranı", 18, FMT_YUZDE_ORAN),
    ]
    baslik_yaz(ws, s, kol_c, fill=FILL_YESIL_BASLIK, dondur=False)
    s += 1
    kamp_veri = [
        ("3 Al 2 Öde (CampaignId 1, 12)", 2025, 20434, 0.210, 5.72, 13.30, 510.7, 1850.7, 0.119),
        ("3 Al 2 Öde (CampaignId 1, 12)", 2026, 29019, 0.249, 5.37, 12.96, 540.4, 2296.8, 0.192),
        ("Diğer Kampanya (Etiket/Kategori İnd.)", 2025, 46182, 0.475, 7.78, 10.42, 744.2, 1097.0, 0.163),
        ("Diğer Kampanya (Etiket/Kategori İnd.)", 2026, 62056, 0.533, 8.00, 10.53, 904.8, 1351.1, 0.220),
        ("Kampanyasız (Tam Fiyat)", 2025, 30709, 0.316, 3.78, 4.99, 340.9, 525.0, 0.000),
        ("Kampanyasız (Tam Fiyat)", 2026, 25437, 0.218, 3.03, 4.03, 340.8, 507.8, 0.000),
    ]
    for row in kamp_veri:
        s = satir_yaz(ws, s, kol_c, list(row), fill=FILL_ZEBRA if row[1] == 2026 else None, bold=row[1] == 2026)

    s += 1
    anlatim_kutusu(
        ws, s,
        "Pareto Kutuplaşması ve Kampanya Göçü Ne Anlama Geliyor?",
        [
            "• %15'lik 'Okul Listesi' Müşterisi Ciromuzun Yarısından Fazlası (%53,4): Tablo 4A'da 5. ve 6. satırları topladığımızda, sepette 11 ve üzeri kırtasiye bulunan 17.635 fiş (fişlerin %15,1'i), 80,5 milyon ₺'lik kırtasiye cirosunun 42,96 milyon ₺'sini (%53,4) tek başına üretiyor. Özellikle 21+ adetlik dev sepetler +%29,5 ile en hızlı büyüyen kova oldu (ortalama sadece kırtasiye 3.539,9 ₺).",
            "• 1 Adetlik Kovadaki Düşüşün Sebebi (158,9 ₺ → 151,9 ₺): 1 adetlik fişlerin +%24,9 artıp ortalama fiyatının düşmesi, içine giren 9.277 adet '0,01 ₺ LETS Oyun Hamuru' fişinden kaynaklanıyor.",
            "• Kampanyasızdan Kampanyalıya Göç: Kampanyasız kırtasiye fişlerinin oranı %31,6'dan %21,8'e geriledi. Müşterilerin %78,2'si kampanyalı ('3 Al 2 Öde' +%42,0 fiş artışı, 'Diğer Kampanya' +%34,4 fiş artışı ve 8,00 adet/fiş) alışveriş yaptı.",
        ],
        genislik_kolon=12,
    )


# ==============================================================================
# 6. SAYFA: KÂRLILIK VE BRÜT MARJ KONTROLÜ (CFO KANITI)
# ==============================================================================
def sayfa_karlilik_marj(wb: Workbook):
    ws = wb.create_sheet("5_Karlilik_ve_Marj")
    ws.cell(1, 1, "İNDİRİM ARTTI AMA MARJ ERİDİ Mİ? — KIRTASİYE SEPET KÂRLILIK TESTİ (AĞUSTOS–EYLÜL)").font = FONT_SAYFA_BASLIK
    ws.cell(2, 1, "Yöntem: Her yılın satılan kırtasiye adedi × o yılın KDV hariç ortalama alış faturası birim fiyatı (DerinSIS fatAyr eTip=0, aynı-yıl eşleme).").font = FONT_NOT

    kol = [
        ("Kârlılık & Marj Göstergesi (Ağustos–Eylül, Maliyeti Eşleşen Kırtasiye)", 48, None),
        ("2025 Okul Sezonu", 20, None),
        ("2026 Okul Sezonu", 20, None),
        ("Değişim (YoY)", 18, None),
    ]
    baslik_yaz(ws, 4, kol, fill=FILL_BKM, dondur=True)

    satirlar = [
        ("Maliyeti Eşleşen Kırtasiye Fiş Sayısı", 89384, 112434, "=(C5-B5)/B5", FMT_ADET, FMT_YUZDE_DEGISIM),
        ("Satılan Kırtasiye Ürün Adedi", 468492, 656250, "=(C6-B6)/B6", FMT_ADET, FMT_YUZDE_DEGISIM),
        ("Net Kırtasiye Satış Cirosu (KDV Hariç)", 39148520, 64138186, "=(C7-B7)/B7", FMT_TL_TAM, FMT_YUZDE_DEGISIM),
        ("Satılan Malın Maliyeti — SMM (KDV Hariç, Aynı-Yıl Alış Faturası)", 23176249, 36187582, "=(C8-B8)/B8", FMT_TL_TAM, FMT_YUZDE_DEGISIM),
        ("TOPLAM BRÜT KÂR HAVUZU (KDV Hariç, ₺)", "=B7-B8", "=C7-C8", "=(C9-B9)/B9", FMT_TL_TAM, FMT_YUZDE_DEGISIM),
        ("GERÇEKLEŞEN BRÜT MARJ (%)", "=B9/B7", "=C9/C7", "=C10-B10", FMT_YUZDE_ORAN, FMT_PUAN),
        ("FİŞ BAŞINA KASAYA KALAN NET BRÜT KÂR (KDV Hariç, ₺ / Fiş)", "=B9/B5", "=C9/C5", "=(C11-B11)/B11", FMT_TL, FMT_YUZDE_DEGISIM),
        ("Kasa Ortalama İndirim Oranı (Brüt Satış Üzerinden)", 0.128, 0.195, "=C12-B12", FMT_YUZDE_ORAN, FMT_PUAN),
    ]

    s = 5
    for ad, v25, v26, deg, fmt_val, fmt_deg in satirlar:
        vurgulu = "BRÜT" in ad
        fill = FILL_VURGU_YESIL if vurgulu else None
        c1 = ws.cell(s, 1, ad)
        c2 = ws.cell(s, 2, v25)
        c3 = ws.cell(s, 3, v26)
        c4 = ws.cell(s, 4, deg)
        for idx, c in enumerate((c1, c2, c3, c4), start=1):
            c.border = KENAR_TOPLAM if vurgulu else KENAR
            if fill:
                c.fill = fill
            c.font = FONT_KALIN if vurgulu else FONT_NORMAL
            if idx == 1:
                c.alignment = Alignment(horizontal="left", vertical="center")
            else:
                c.alignment = Alignment(horizontal="right", vertical="center")
        c2.number_format = fmt_val
        c3.number_format = fmt_val
        c4.number_format = fmt_deg
        c4.font = FONT_YESIL
        ws.row_dimensions[s].height = 24
        s += 1

    s += 1
    anlatim_kutusu(
        ws, s,
        "CFO Özeti: İndirim +%6,7 Puan Artarken Brüt Marj Nasıl +2,8 Puan Yükseldi?",
        [
            "• Yanıltıcı Yüzey: Sadece kasa indirim oranına bakıldığında (%12,8 → %19,5), kampanyaların kârlılığı erittiği sanılabilir.",
            "• Gerçek Ölçüm: Satılan her ürün kendi yılının KDV hariç alış faturası maliyetiyle (fatAyr eTip=0) eşleştirildiğinde, kırtasiye brüt marjı %40,8'den %43,6'ya (+2,8 puan) yükseldi.",
            "• Sebebi: Etiket (brüt) fiyatları alış maliyetinin üzerinde konumlandırılıp kasada kampanya indirimi olarak müşteriye sunuldu; ayrıca kampanyalar müşteriyi yüksek marjlı kırtasiye/hediyelik ürün karmasına taşıdı.",
            "• Sonuç: Kırtasiye giren her fişten şirkete kalan KDV hariç brüt kâr 178,7 ₺'den 248,6 ₺'ye (+%39,1) çıktı; iki aylık toplam kırtasiye brüt kâr havuzu 15,97 milyon ₺'den 27,95 milyon ₺'ye (+%75,0) ulaştı.",
        ],
        genislik_kolon=4,
    )


# ==============================================================================
# 7. SAYFA: 15 AYLIK KESİNTİSİZ TREND + GRAFİK
# ==============================================================================
def sayfa_aylik_seri(wb: Workbook):
    ws = wb.create_sheet("6_Aylik_Seri_15Ay")
    ws.cell(1, 1, "15 AYLIK KESİNTİSİZ KIRTASİYE SEPET TRENDİ (TEMMUZ 2025 – EYLÜL 2026)").font = FONT_SAYFA_BASLIK
    ws.cell(2, 1, "Sezon dışında kırtasiye sepeti 3,4–3,9 adet bandında sabit seyrederken, okul sezonunda (Eylül) 7,17 adede ve 796,8 ₺'ye fırlamaktadır.").font = FONT_NOT

    kol = [
        ("Dönem (Yıl-Ay)", 16, None),
        ("Toplam Perakende Fiş", 16, FMT_ADET),
        ("Kırtasiye Fişi", 15, FMT_ADET),
        ("Kırtasiye Penetrasyonu", 16, FMT_YUZDE_ORAN),
        ("Kırt. Adet / Fiş", 14, FMT_ONDALIK2),
        ("Kırt. Çeşit / Fiş", 14, FMT_ONDALIK2),
        ("Brüt Kırt. / Fiş (₺)", 16, FMT_TL),
        ("Net Kırt. / Fiş (KDV Dahil)", 18, FMT_TL),
        ("Net Kırt. / Fiş (KDV Hariç)", 18, FMT_TL),
        ("Kırt. Birim Fiyat (KDV Dahil)", 16, FMT_TL),
        ("Kırtlı Fişin Tüm Sepet Adedi", 18, FMT_ONDALIK2),
        ("Kırtlı Fişin Tüm Sepet Net ₺", 18, FMT_TL),
    ]
    baslik_yaz(ws, 4, kol, fill=FILL_BKM, dondur=True)

    aylar = [
        ("2025-07 (Kısmi)", 22904, 8704, 0.380, 3.38, 2.52, 275.3, 255.1, 218.6, 75.6, 6.29, 616.3),
        ("2025-08", 68970, 32968, 0.478, 5.28, 3.86, 565.6, 505.7, 439.8, 95.9, 8.14, 906.1),
        ("2025-09 ★ Sezon", 119750, 64357, 0.537, 6.50, 4.99, 695.3, 599.8, 522.7, 92.3, 9.91, 1161.1),
        ("2025-10", 106390, 53977, 0.507, 3.47, 2.52, 265.2, 238.8, 204.3, 68.8, 6.25, 650.2),
        ("2025-11", 95115, 46683, 0.491, 3.43, 2.45, 281.3, 250.6, 213.6, 73.0, 6.46, 698.6),
        ("2025-12", 102962, 53070, 0.515, 3.58, 2.53, 300.9, 268.4, 229.4, 75.0, 6.42, 718.5),
        ("2026-01", 108244, 52679, 0.487, 3.65, 2.56, 309.8, 271.8, 231.9, 74.5, 6.72, 758.9),
        ("2026-02", 91979, 45837, 0.498, 3.68, 2.60, 309.4, 267.5, 228.3, 72.7, 6.55, 743.6),
        ("2026-03", 95621, 47641, 0.498, 3.93, 2.71, 319.1, 271.7, 231.7, 69.1, 6.77, 754.8),
        ("2026-04", 91663, 46172, 0.504, 3.94, 2.72, 330.6, 277.0, 236.2, 70.3, 6.95, 758.8),
        ("2026-05", 91053, 41028, 0.451, 3.76, 2.61, 323.8, 271.7, 231.3, 72.3, 6.66, 767.7),
        ("2026-06", 79543, 31572, 0.397, 3.71, 2.62, 324.7, 270.3, 230.5, 72.9, 6.84, 804.2),
        ("2026-07", 76462, 29353, 0.384, 3.48, 2.57, 376.4, 310.1, 265.0, 89.0, 6.75, 813.0),
        ("2026-08", 80322, 40611, 0.506, 4.55, 3.42, 643.1, 493.0, 427.4, 108.4, 7.92, 1115.8),
        ("2026-09 ★ Zirve", 123890, 75901, 0.613, 7.17, 5.58, 974.2, 796.8, 693.2, 111.1, 10.68, 1555.9),
    ]

    s = 5
    for idx, row in enumerate(aylar):
        sezon_mu = "08" in row[0] or "09" in row[0]
        s = satir_yaz(ws, s, kol, list(row), fill=FILL_VURGU_YESIL if "2026-09" in row[0] else (FILL_VURGU_SARI if sezon_mu else (FILL_ZEBRA if idx % 2 == 1 else None)), bold=sezon_mu)

    # Excel Grafiği ekle: Aylık Net Kırtasiye Sepeti (₺) ve Adet
    chart1 = BarChart()
    chart1.type = "col"
    chart1.style = 10
    chart1.title = "Aylık Fiş Başı Net Kırtasiye Sepeti (KDV Dahil ₺)"
    chart1.y_axis.title = "TL / Fiş"
    chart1.x_axis.title = "Yıl-Ay"
    data1 = Reference(ws, min_col=8, min_row=4, max_row=19)
    cats1 = Reference(ws, min_col=1, min_row=5, max_row=19)
    chart1.add_data(data1, titles_from_data=True)
    chart1.set_categories(cats1)
    chart1.legend = None
    chart1.width = 18
    chart1.height = 10
    ws.add_chart(chart1, "A21")

    chart2 = BarChart()
    chart2.type = "col"
    chart2.style = 11
    chart2.title = "Aylık Fiş Başı Kırtasiye Ürün Adedi"
    chart2.y_axis.title = "Adet / Fiş"
    chart2.x_axis.title = "Yıl-Ay"
    data2 = Reference(ws, min_col=5, min_row=4, max_row=19)
    chart2.add_data(data2, titles_from_data=True)
    chart2.set_categories(cats1)
    chart2.legend = None
    chart2.width = 18
    chart2.height = 10
    ws.add_chart(chart2, "G21")


# ==============================================================================
# 8. SAYFA: ÜRÜN AİLELERİ, MARKA SAVAŞLARI VE ŞAMPİYON TEKİL ÜRÜNLER (SKU)
# ==============================================================================
def sayfa_urun_marka_detay(wb: Workbook):
    ws = wb.create_sheet("7_Urun_Aile_Marka_SKU")
    ws.cell(1, 1, "ÜRÜN AİLELERİ, MARKA SAVAŞLARI VE ŞAMPİYON TEKİL ÜRÜNLER (AĞUSTOS–EYLÜL 2025 vs 2026)").font = FONT_SAYFA_BASLIK
    ws.cell(2, 1, "0,01 ₺ promosyon oyun hamuru hariç gerçek kırtasiye ürünleri üzerinden fiş-bazlı tekilleştirilmiş (SalesId × Grup) sepet etkisi.").font = FONT_NOT

    # TABLO 7A: 10 ÜRÜN AİLESİ
    ws.cell(4, 1, "TABLO 7A — 10 KIRTASİYE ÜRÜN AİLESİNİN BÜYÜME VE SEPET ÇARPANI ANALİZİ (AĞUSTOS–EYLÜL)").font = FONT_BOLUM
    kol_aile = [
        ("Ürün Ailesi (Alt Grup)", 34, None),
        ("Fiş 2025", 12, FMT_ADET),
        ("Fiş 2026", 12, FMT_ADET),
        ("Fiş Δ%", 13, FMT_YUZDE_DEGISIM),
        ("Adet 2025", 13, FMT_ADET),
        ("Adet 2026", 13, FMT_ADET),
        ("Adet Δ%", 13, FMT_YUZDE_DEGISIM),
        ("Net Ciro 2025 (₺)", 17, FMT_TL_TAM),
        ("Net Ciro 2026 (₺)", 17, FMT_TL_TAM),
        ("Ciro Δ%", 13, FMT_YUZDE_DEGISIM),
        ("Birim Fiyat 25 (₺)", 16, FMT_TL),
        ("Birim Fiyat 26 (₺)", 16, FMT_TL),
        ("Fiyat Δ%", 13, FMT_YUZDE_DEGISIM),
        ("Girdiği Fişte Top. Kırt. Adet (26)", 22, FMT_ONDALIK2),
        ("Girdiği Fişte Top. Kırt. ₺ (26)", 22, FMT_TL),
        ("Girdiği Fişin TÜM Sepeti ₺ (26)", 22, FMT_TL),
    ]
    baslik_yaz(ws, 5, kol_aile, fill=FILL_BKM, dondur=True)

    aile_veri = [
        ("1) Okul ve Beslenme Çantası (Ciro Lideri ★)", 12634, 13946, "=(C6-B6)/B6", 17900, 20055, "=(F6-E6)/E6", 10671728, 16343945, "=(I6-H6)/H6", 596.2, 815.0, "=(L6-K6)/K6", 14.41, 2521.0, 3134.3),
        ("2) Kalem ve Uç Grubu (Trafik Motoru)", 48752, 51808, "=(C7-B7)/B7", 178192, 209072, "=(F7-E7)/E7", 10257809, 13380220, "=(I7-H7)/H7", 57.6, 64.0, "=(L7-K7)/K7", 10.30, 1081.8, 1737.5),
        ("3) Defter ve Bloknot", 34533, 35458, "=(C8-B8)/B8", 101611, 106929, "=(F8-E8)/E8", 9616998, 13030255, "=(I8-H8)/H8", 94.6, 121.9, "=(L8-K8)/K8", 11.49, 1280.4, 1938.5),
        ("4) Boya ve Resim Grubu (Adet Patlaması ★)", 23801, 31262, "=(C9-B9)/B9", 48046, 68963, "=(F9-E9)/E9", 6031993, 8846385, "=(I9-H9)/H9", 125.5, 128.3, "=(L9-K9)/K9", 12.05, 1318.9, 1917.6),
        ("5) Silgi / Yapıştırıcı / Bant / Makas", 21935, 26313, "=(C10-B10)/B10", 52209, 67386, "=(F10-E10)/E10", 2647914, 3680646, "=(I10-H10)/H10", 50.7, 54.6, "=(L10-K10)/K10", 14.97, 1576.2, 2242.1),
        ("6) Matara / Suluk / Termos (#1 Sepet Çıpası ★)", 2779, 2825, "=(C11-B11)/B11", 3264, 3334, "=(F11-E11)/E11", 2032751, 3197248, "=(I11-H11)/H11", 622.8, 959.0, "=(L11-K11)/K11", 15.18, 3290.7, 3924.2),
        ("7) Fotokopi ve A4 Kağıt (Okul Listesi Turnusolü ★)", 9029, 8655, "=(C12-B12)/B12", 19435, 18844, "=(F12-E12)/E12", 1585664, 1957086, "=(I12-H12)/H12", 81.6, 103.9, "=(L12-K12)/K12", 19.69, 2152.1, 2803.4),
        ("8) Dosyalama ve Klasör (Okul Listesi Turnusolü ★)", 8878, 12801, "=(C13-B13)/B13", 33197, 42741, "=(F13-E13)/E13", 1093630, 1754074, "=(I13-H13)/H13", 32.9, 41.0, "=(L13-K13)/K13", 18.86, 1894.1, 2554.5),
        ("9) Kalemlik / Kalem Kutusu", 2386, 2746, "=(C14-B14)/B14", 2849, 3279, "=(F14-E14)/E14", 521450, 756302, "=(I14-H14)/H14", 183.0, 230.7, "=(L14-K14)/K14", 16.07, 2150.9, 2864.6),
        ("10) Diğer Kırtasiye (Sanatsal/Masaüstü/Setler)", 47263, 55528, "=(C15-B15)/B15", 133878, 158772, "=(F15-E15)/E15", 10794032, 17505866, "=(I15-H15)/H15", 80.6, 110.3, "=(L15-K15)/K15", 9.41, 1046.9, 1664.4),
    ]
    s = 6
    for idx, row in enumerate(aile_veri):
        fill = FILL_VURGU_YESIL if idx in (0, 3, 5) else (FILL_VURGU_SARI if idx in (6, 7) else (FILL_ZEBRA if idx % 2 == 1 else None))
        s = satir_yaz(ws, s, kol_aile, list(row), fill=fill, bold=idx in (0, 3, 5, 6, 7))

    # TABLO 7B: MARKA SAVAŞLARI (TOP 18 MARKA)
    s += 2
    ws.cell(s, 1, "TABLO 7B — MARKA SAVAŞLARI: EN ÇOK CİRO YAPAN 18 MARKA (KAZANANLAR vs KAN KAYBEDENLER)").font = FONT_BOLUM
    s += 1
    kol_marka = [
        ("Marka", 26, None),
        ("Durum / Rol", 26, None),
        ("Fiş 2025", 12, FMT_ADET),
        ("Fiş 2026", 12, FMT_ADET),
        ("Fiş Δ%", 13, FMT_YUZDE_DEGISIM),
        ("Adet 2025", 13, FMT_ADET),
        ("Adet 2026", 13, FMT_ADET),
        ("Adet Δ%", 13, FMT_YUZDE_DEGISIM),
        ("Net Ciro 2025 (₺)", 17, FMT_TL_TAM),
        ("Net Ciro 2026 (₺)", 17, FMT_TL_TAM),
        ("Ciro Δ%", 13, FMT_YUZDE_DEGISIM),
        ("Birim Fiyat 26 (₺)", 16, FMT_TL),
        ("Girdiği Fişin Tüm Sepeti ₺", 20, FMT_TL),
    ]
    baslik_yaz(ws, s, kol_marka, fill=FILL_LACIVERT, dondur=False)
    s += 1
    marka_veri = [
        ("1) Faber-Castell", "Tartışmasız Lider ★", 25836, 32133, (32133-25836)/25836, 90655, 120238, (120238-90655)/90655, 6528534, 9144263, (9144263-6528534)/6528534, 76.0, 3087.3),
        ("2) Keskin Color", "Defter & Kağıt Lideri", 18882, 21055, (21055-18882)/18882, 52929, 58546, (58546-52929)/52929, 5266971, 6874562, (6874562-5266971)/5266971, 117.4, 3113.4),
        ("3) Ceren", "Süper Sıçrama (+%153 Ciro ★)", 1713, 3425, (3425-1713)/1713, 2144, 4264, (4264-2144)/2144, 2173466, 5497600, (5497600-2173466)/2173466, 1289.3, 4569.0),
        ("4) Gıpta", "Defterde Güçlü Büyüme (+%60)", 17748, 21398, (21398-17748)/17748, 34023, 47351, (47351-34023)/34023, 3092444, 4959972, (4959972-3092444)/3092444, 104.7, 2828.5),
        ("5) BKM Kitap (Özel Marka)", "Hobi & Boyama Setleri", 16515, 17594, (17594-16515)/16515, 25956, 30332, (30332-25956)/25956, 1746154, 2390849, (2390849-1746154)/1746154, 78.8, 1988.7),
        ("6) MAS Kırtasiye", "Adet 2,3x Katlandı (+%119 ★)", 7280, 13771, (13771-7280)/7280, 11898, 27383, (27383-11898)/11898, 1072756, 2349542, (2349542-1072756)/1072756, 85.8, 3126.3),
        ("7) Kaukko", "Premium Çanta & Kalemlik", 1644, 1673, (1673-1644)/1644, 1942, 1988, (1988-1942)/1942, 1730803, 2288990, (2288990-1730803)/1730803, 1151.4, 4438.5),
        ("8) Vagonlife", "Matara/Suluk Yıldızı (+%123 ★)", 1092, 1931, (1931-1092)/1092, 1242, 2217, (2217-1242)/1242, 998798, 2230411, (2230411-998798)/998798, 1006.0, 4129.0),
        ("9) Me Çanta", "Lisanslı Çanta (+%124 Adet)", 1269, 2338, (2338-1269)/1269, 1564, 3505, (3505-1564)/1564, 1420808, 1909246, (1909246-1420808)/1420808, 544.7, 3677.7),
        ("10) Pritt", "Okul Listesi İmza Markası", 6613, 8911, (8911-6613)/6613, 13757, 17762, (17762-13757)/13757, 1311443, 1732804, (1732804-1311443)/1311443, 97.6, 3498.4),
        ("11) Noki", "Dosyalama & Kitap Kabı", 11902, 11825, (11825-11902)/11902, 29528, 31528, (31528-29528)/29528, 1393693, 1657985, (1657985-1393693)/1393693, 52.6, 3096.3),
        ("12) TİMON", "⚠ Adet Kaybı (−%25,8)", 7903, 6302, (6302-7903)/7903, 14261, 10584, (10584-14261)/14261, 1364635, 1495655, (1495655-1364635)/1364635, 141.3, 2895.8),
        ("13) Penna", "Sıfırdan 1,44M ₺ Yeni Giriş ★", 7, 8610, (8610-7)/7, 7, 11767, (11767-7)/7, 1399, 1441582, (1441582-1399)/1399, 122.5, 2006.4),
        ("14) Rotring", "⚠ Fiş Kaybı (−%13,6)", 6489, 5604, (5604-6489)/6489, 10454, 9725, (9725-10454)/10454, 1271298, 1320561, (1320561-1271298)/1271298, 135.8, 2709.3),
        ("15) OMT", "⚠ En Sert Kayıp (−%36 Fiş)", 16847, 10781, (10781-16847)/16847, 32607, 20333, (20333-32607)/32607, 1440742, 1283188, (1283188-1440742)/1440742, 63.1, 1981.7),
        ("16) MAXX", "Tahta Kalemi & Dosyalama (+%39)", 8851, 11027, (11027-8851)/8851, 12114, 16800, (16800-12114)/12114, 991228, 1228905, (1228905-991228)/991228, 73.1, 2788.1),
        ("17) Bic", "⚠ Adet Kaybı (−%16,2)", 6277, 5801, (5801-6277)/6277, 10773, 9030, (9030-10773)/10773, 1220858, 1214905, (1214905-1220858)/1220858, 134.5, 3209.4),
        ("18) Fatih", "12'li Paket Kalem Sıçraması (+%93 ★)", 4622, 6781, (6781-4622)/4622, 9581, 14001, (14001-9581)/9581, 541013, 1041508, (1041508-541013)/541013, 74.4, 3190.6),
    ]
    for idx, row in enumerate(marka_veri):
        uyari = "⚠" in row[1]
        yildiz = "★" in row[1]
        fill = FILL_VURGU_SARI if uyari else (FILL_VURGU_YESIL if yildiz else (FILL_ZEBRA if idx % 2 == 1 else None))
        s = satir_yaz(ws, s, kol_marka, list(row), fill=fill, bold=uyari or yildiz)

    # TABLO 7C: TOP 20 TEKİL ÜRÜN (SKU)
    s += 2
    ws.cell(s, 1, "TABLO 7C — TEKİL ÜRÜN (SKU) ŞAMPİYONLARI VE GİRDİKLERİ FİŞİN SEPET BÜYÜKLÜĞÜ (TOP 20)").font = FONT_BOLUM
    s += 1
    kol_sku = [
        ("Sıra & Stok Kodu (stkID)", 20, None),
        ("Ürün Adı (stkAd)", 48, None),
        ("Marka", 16, None),
        ("Fiş 2025", 11, FMT_ADET),
        ("Fiş 2026", 11, FMT_ADET),
        ("Adet 2025", 12, FMT_ADET),
        ("Adet 2026", 12, FMT_ADET),
        ("Net Ciro 2025 (₺)", 16, FMT_TL_TAM),
        ("Net Ciro 2026 (₺)", 16, FMT_TL_TAM),
        ("Birim Fiyat 26 (₺)", 15, FMT_TL),
        ("Girdiği Fişte Kırt. Adet", 18, FMT_ONDALIK2),
        ("Girdiği Fişte Kırt. Net ₺", 18, FMT_TL),
        ("Girdiği Fişin TÜM Sepeti ₺", 20, FMT_TL),
    ]
    baslik_yaz(ws, s, kol_sku, fill=FILL_YESIL_BASLIK, dondur=False)
    s += 1
    sku_veri = [
        ("#1 · 56728", "Pritt-Stick Yapıştırıcı 22Gr (Okul Listesi İmzası ★)", "Pritt", 1921, 3404, 3603, 5989, 243481, 443427, 74.0, 25.91, 2772.1, 3444.9),
        ("#2 · 21454", "Mopak Fotokopi Kağıdı 80 Gr A4 Rekort (10,4x Fiş ★)", "MOPAK", 205, 2137, 294, 2896, 32270, 430193, 148.5, 21.12, 2262.1, 2907.8),
        ("#3 · 58064", "Pritt-Stick Yapıştırıcı 43Gr (30,5 Adetlik Sepet ★)", "Pritt", 1570, 1968, 2673, 3303, 234035, 355139, 107.5, 30.54, 3434.0, 4247.5),
        ("#4 · 9870", "Ve-Ge Fotokopi Kağıdı Copier Bond 500'lü A4 80 Gr", "Ve-Ge", 1241, 1456, 2029, 1878, 250136, 333876, 177.8, 22.52, 2687.5, 3434.9),
        ("#5 · 1642814", "Faber-Castell Super Fine Min 2B 0.7mm (15.626 Adet ★)", "Faber-Castell", 1451, 7196, 2470, 15626, 72536, 309126, 19.8, 13.68, 1341.7, 2057.3),
        ("#6 · 241761", "Gıpta Pastoral Çizgili Spiralli PP Kapak Defter A4 60 Yp", "Gıpta", 857, 1425, 1279, 2122, 118715, 269668, 127.1, 19.31, 2324.5, 3160.4),
        ("#7 · 1706545", "Faber-Castell Polymatic Leo Edition Versatil 0.7mm (Yeni)", "Faber-Castell", 0, 628, 0, 695, 0, 268020, 385.6, 12.05, 1872.7, 2371.7),
        ("#8 · 1718292", "Desenli 20x20 Boyanabilir Tuval Boya Seti (Yeni)", "BKM Kitap", 0, 2162, 0, 3255, 0, 257055, 79.0, 6.00, 548.0, 973.7),
        ("#9 · 1715049", "Nike Elemental 2.0 Unisex Sırt Çantası (Yeni)", "Nike", 0, 180, 0, 192, 0, 240000, 1250.0, 7.38, 2352.6, 3013.6),
        ("#10 · 59972", "Faber-Castell Sınav Silgisi (3.743 Fiş)", "Faber-Castell", 3223, 3743, 4952, 6165, 193770, 236933, 38.4, 18.68, 1979.2, 2752.5),
        ("#11 · 39319", "Faber-Castell Karton Kutu Boya Kalemi 12 Renk (+%252 Fiş)", "Faber-Castell", 414, 1459, 453, 1638, 92859, 212145, 129.5, 27.19, 2921.7, 3564.8),
        ("#12 · 221176", "Gıpta Pastoral Kareli Spiralli PP Kapak Defter A4 72 Yp", "Gıpta", 550, 965, 763, 1410, 81718, 207619, 147.2, 18.19, 2294.7, 3138.8),
        ("#13 · 1576713", "Sayılarla Boyama Seti 40x50", "BKM Kitap", 314, 561, 363, 652, 90413, 193707, 297.1, 5.28, 818.2, 1440.4),
        ("#14 · 1735020", "Edding Ecoline Beyaz Tahta Kalemi 4'lü (Yeni)", "Edding", 0, 847, 0, 972, 0, 193305, 198.9, 23.50, 2665.8, 3370.6),
        ("#15 · 241300", "Gıpta Pastoral Çizgili Spiralli PP Kapak Defter A4 72 Yp", "Gıpta", 575, 890, 788, 1307, 84068, 192079, 147.0, 20.48, 2450.1, 3183.9),
        ("#16 · 13302", "Faber-Castell Karton Kutu Pastel Boya 12 Renk (+%165 Fiş)", "Faber-Castell", 444, 1179, 467, 1263, 91321, 188769, 149.5, 28.05, 3182.0, 3724.9),
        ("#17 · 10231", "Faber-Castell Kırmızı Kopya Kalemi (6.331 Adet)", "Faber-Castell", 2207, 2671, 5475, 6331, 160617, 180781, 28.6, 28.77, 2906.8, 3580.6),
        ("#18 · 26494", "Faber-Castell Plastik Çantalı Pastel Boya 24'lü (5.947₺ Sepet ★)", "Faber-Castell", 162, 273, 171, 279, 110593, 180000, 645.2, 35.07, 5213.3, 5947.4),
        ("#19 · 43829", "Fatih Mercanlı Kurşun Kalem 12'li Paket (Yeni Paket Stratejisi ★)", "Fatih", 1, 1499, 1, 1809, 150, 178946, 98.9, 22.52, 2390.7, 3019.9),
        ("#20 · 1571475", "Projecta Ultra A4 Fotokopi Kağıdı 80gr (⚠ Mopak'a Kaydı)", "Projecta", 2577, 674, 3997, 1162, 399647, 172870, 148.8, 16.27, 1803.2, 2342.1),
    ]
    for idx, row in enumerate(sku_veri):
        yildiz = "★" in row[1]
        uyari = "⚠" in row[1]
        fill = FILL_VURGU_SARI if uyari else (FILL_VURGU_YESIL if yildiz else (FILL_ZEBRA if idx % 2 == 1 else None))
        s = satir_yaz(ws, s, kol_sku, list(row), fill=fill, bold=yildiz or uyari)

    s += 1
    anlatim_kutusu(
        ws, s,
        "Ürün ve Marka Detayından Çıkan 5 Vurucu Keşif (Toplantıda Anlatılacak Öz)",
        [
            "1) 'Pritt ve A4 Kağıt' = Dev Okul Listesi Turnusolü: Tüm kırtasiyenin ciro şampiyonu Pritt 22Gr (443K ₺) ve #3 Pritt 43Gr (355K ₺) kendileri 74–108 ₺'lik ürünlerdir ama girdikleri fişte ortalama 26 ile 30,5 ADET kırtasiye ve 3.445–4.248 ₺ toplam sepet oluşur! Aynı şekilde A4 Fotokopi Kağıdı (19,7 adet/fiş) ve Dosyalama (18,9 adet/fiş) ürünleri, öğretmenin verdiği resmi okul listesini baştan sona BKM'den dolduran velinin imzasıdır.",
            "2) Boya & Resim Grubunda Fiyat Esnekliği Kanıtı (+%2,2 Fiyat = +%43,5 Adet Patlaması!): Çanta (+%36,7 fiyat) ve Matara (+%54,0 fiyat) grupları premiumlaşarak büyürken, Boya ve Resim grubunda ortalama birim fiyat neredeyse hiç zamlanmadı (125,5 ₺ → 128,3 ₺, +%2,2). Fiyat sabit kalınca satış adedi 48.046'dan 68.963'e (+%43,5) patladı!",
            "3) Tekli Kalemden '12'li Paket'e Geçiş Sepeti Büyüttü: Geçen yıl satılmayan 'Fatih Mercanlı Kurşun Kalem 12'li Paket' (1.499 fiş, 179K ₺) ve 'Fatih Kırmızı Kopya 12'li Paket' (1.179 fiş, 124K ₺) devreye girerek müşteriyi tek kalem yerine düzine paket almaya yönlendirdi.",
            "4) Kasa Önü / Tamamlayıcı Rekortmeni (Faber-Castell 0.7mm Uç): Tek bir barkod (stkID=1642814) geçen yıl 1.451 fişte 2.470 adet satılırken bu yıl 7.196 fişte 15.626 ADET (+%533!) satıldı — her girdiği fişe ortalama 2,2 adet eklendi.",
            "5) Marka Savaşları: Ceren (+%153 ciro, 4.569 ₺ sepet!), Vagonlife (+%123 ciro, 4.129 ₺ sepet), MAS (+%119 ciro), Gıpta (+%60) ve sıfırdan 8.610 fişe giren Penna (1,44M ₺) sezonun yıldızları olurken; OMT (−%36 fiş), Timon (−%26 adet), Rotring (−%14 fiş) ve Projecta A4 (yerini 10 kat büyüyen Mopak A4'e bıraktı) geriledi.",
        ],
        genislik_kolon=13,
    )


# ==============================================================================
# 9. SAYFA: YÖNTEM VE TERİMLER SÖZLÜĞÜ (SORU-CEVAP REHBERİ)
# ==============================================================================
def sayfa_sozluk(wb: Workbook):
    ws = wb.create_sheet("8_Yontem_ve_Sozluk")
    ws.cell(1, 1, "YÖNTEM, VERİ KAPSAMI VE TERİMLER SÖZLÜĞÜ (TOPLANTI SORU-CEVAP REHBERİ)").font = FONT_SAYFA_BASLIK
    ws.cell(2, 1, "Sunum sırasında gelebilecek teknik ve metodolojik sorulara net, doğrulanmış yanıtlar.").font = FONT_NOT

    kol = [
        ("Kavram / Olası Soru", 36, None),
        ("Ne Anlama Gelir & Nasıl Hesaplandı? (Düz Türkçe Açıklama)", 95, None),
    ]
    baslik_yaz(ws, 4, kol, fill=FILL_LACIVERT, dondur=True)

    maddeler = [
        ("Kırtasiye Penetrasyonu (%)", "Kasadan geçen toplam perakende fişlerin yüzde kaçında en az 1 adet kırtasiye ürünü bulunduğunu gösterir. Örn: %57,1 = mağazadan alışveriş yapan her 100 müşterinin 57'si sepetine kırtasiye ekledi."),
        ("Kırtasiye Alt-Sepeti vs Tüm Sepet", "Rapor iki ayrı sepet tanımını birlikte sunar: (1) Kırtasiye Alt-Sepeti: Kırtasiye giren fişlerde SADECE kırtasiye ürünlerinin ortalama adedi (6,26 adet) ve tutarı (690,9 ₺). (2) Kırtasiyeli Fişin Tüm Sepeti: Aynı fişin içindeki kitap, hazırlık, oyuncak dahil toplam büyüklüğü (9,72 adet ve 1.402,5 ₺)."),
        ("Kırtasiye Çeşit / Fiş (Satır Sayısı)", "Fişteki farklı kırtasiye barkodu (satır) sayısıdır. Örn: Müşteri aynı kalemden 3 tane, silgiden 1 tane aldıysa 'Kırtasiye Çeşidi = 2', 'Kırtasiye Adedi = 4' olur."),
        ("Neden 'Ham Sepet' ve 'Gerçek Sepet' Ayrı Gösterildi?", "5 Ağustos 2026'dan itibaren kasalarda 0,01 ₺ (1 kuruş) fiyatla verilen promosyon 'LETS Tek Renk Oyun Hamuru 110 gr' (stkID=1733557, 29.097 fiş) ERP'de Kırtasiye kategorisinde tanımlıdır. Sadece kitap alıp 1 kuruşa hediye hamur verilen 9.277 fiş, ham veride '1 adetlik 0,01 ₺'lik kırtasiye sepeti' sayılarak ortalamayı aşağı çekmiştir. Bu fişler ayıklandığında gerçek sepet büyümesi +%3,0 yerine +%6,7 (adet) ve +%21,7 yerine +%31,0 (TL) olmaktadır."),
        ("Neden Temmuz Ayı '23–31 Temmuz' Olarak Kıyaslandı?", "Yeni yazar kasa sistemi (EncoreMerkez) Temmuz 2025 ortasında (11–22 Temmuz arasında kademeli) devreye girdi. Üç mağazanın tamamının her iki yılda da yeni kasada tam olduğu ortak Temmuz günleri 23–31 Temmuz'dur (elma-elma kıyas). Ağustos ve Eylül aylarında ise her iki yılda da 1'inden son gününe kadar %100 tam veri mevcuttur."),
        ("Sınav Okulları ve İadeler Dahil mi?", "Hayır. Sepet ortalamasını bozmaması için yalnız perakende satış fiş/faturaları (DocumentsTypeId 1=Fiş, 2=Fatura, 6=Personel Fiş, 7=Personel Fatura) ve geçerli satırlar (IsValid=1) alınmıştır. Kurumsal Sınav Okulları faturaları (DocumentsTypeId=8) ve İade fişleri (DocumentsTypeId=3) sepet ortalamasına dahil edilmemiştir."),
        ("KDV Dahil ve KDV Hariç Neden İkisi Birden Var?", "Müşterinin kasada ödediği fiş büyüklüğü KDV Dahil (SalesProducts.TotalPrice) üzerinden algılanır; şirketin gelir tablosu ve marj hesabı ise KDV Hariç (TotalPrice - VatTotal) üzerinden yürür. Raporda her ikisi de yan yana verilmiştir."),
        ("Brüt Marj (%40,8 → %43,6) Nasıl Hesaplandı?", "Her yılın Ağustos–Eylül döneminde satılan kırtasiye ürünlerinin KDV hariç net satış tutarından, o ürünün aynı yıldaki KDV hariç ortalama alış faturası birim maliyeti (DerinSIS fatAyr eTip=0) düşülerek hesaplanmıştır."),
    ]

    s = 5
    for k, aciklama in maddeler:
        c1 = ws.cell(s, 1, k)
        c2 = ws.cell(s, 2, aciklama)
        c1.font = FONT_KALIN
        c2.font = FONT_NORMAL
        c1.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
        c2.alignment = Alignment(horizontal="left", vertical="center", wrap_text=True)
        fill = FILL_ZEBRA if s % 2 == 0 else None
        for c in (c1, c2):
            c.border = KENAR
            if fill:
                c.fill = fill
        ws.row_dimensions[s].height = 38
        s += 1


def main():
    kok = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    cikti_klasor = os.path.join(kok, "raporlar")
    os.makedirs(cikti_klasor, exist_ok=True)
    cikti_yol = os.path.join(cikti_klasor, "Kirtasiye_Sepet_Buyuklugu_2025_2026.xlsx")

    wb = Workbook()
    sayfa_sunum_olustur(wb)
    sayfa_donem_kiyas(wb)
    sayfa_magaza_kirilimi(wb)
    sayfa_kompozisyon_ve_saat(wb)
    sayfa_kovalar_ve_kampanya(wb)
    sayfa_karlilik_marj(wb)
    sayfa_aylik_seri(wb)
    sayfa_urun_marka_detay(wb)
    sayfa_sozluk(wb)

    try:
        wb.save(cikti_yol)
        print(f"OK: {cikti_yol}")
    except PermissionError:
        alternatif = os.path.join(cikti_klasor, "Kirtasiye_Sepet_Buyuklugu_2025_2026_v2_UrunDetay.xlsx")
        wb.save(alternatif)
        print(f"LOCKED_FALLBACK: {alternatif}")


if __name__ == "__main__":
    main()


