# -*- coding: utf-8 -*-
"""Excel: Sunum (patrona gosterilen tek sayfa) + Ozet sayfalari."""
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from verimlilik_ortak import CARI, MEKAN, ONCEKI
from verimlilik_xlsx_ortak import (ADET, ADET1, BASLIK, BASLIK_YAZI, BOLUM_YAZI, GRI,
                                   INCE, KAT, KENAR, NOT_YAZI, TL, VURGU, YESIL_YAZI,
                                   YUZDE, _basliklar, _notlar, _yaz)

# --------------------------------------------------- Sunum (patrona gosterilen)
def sayfa_sunum(wb, veri):
    """PATRONA GOSTERILEN sayfa — ilk sirada. Tek ekran, dumduz Turkce, jargon yok.

    Rakamlar Ozet sayfasindan FORMULLE gelir (tek kaynak): Ozet'te ham rakam degisirse burasi da doner.
    Teknik bloklar (kapsam etiketleri, kopru kontrolu, mutabakat) arkadaki sayfalarda kalir.
    """
    ws = wb.create_sheet("Sunum", 0)
    ws.column_dimensions["A"].width = 4
    ws.column_dimensions["B"].width = 82
    ws.column_dimensions["C"].width = 26
    ws.sheet_view.showGridLines = False

    b = ws.cell(2, 2, "Sezon 2026 — kadro mu büyüdü, iş mi büyüdü?")
    b.font = Font(bold=True, size=16, color="1F5B57")
    ws.cell(3, 2, "Beş mağaza kadrosu · üç POS mağazası iş hacmi · 2025 ile aynı takvim dönemi").font = NOT_YAZI

    # ⚠ Ozet referanslari SABIT satir numarasiyla yazilmisti; blok buyuyunce sessizce yanlis
    #   hucreyi okuyordu ve "kaç kat" hucresi CIRO oranini (6,0x) gosteriyordu (metin 2,9x diyor).
    #   Artik sayfa_ozet'in dondurdugu indeks sozlugu kullanilir.
    ix = getattr(wb["Ozet"], "_indeks", {})

    def _oz(anahtar, kolon="E"):
        satir = ix.get(anahtar)
        return ("='Ozet'!%s%d" % (kolon, satir)) if satir else None

    satirlar = [
        ("1", "Kadro farkı sezon başlamadan ÖNCE oluştu.",
         "30 Haziran'da kadrolu personel 139'dan 153'e çıkmıştı.", _oz("taban_b", "D"), "+0 kişi;-0 kişi"),
        ("2", "Sezon boyunca kadro büyümedi, KÜÇÜLDÜ.",
         "1 Temmuz – 31 Ağustos: kadrolu 153 → 149. Geçen yıl da aynı yönde (−4).",
         _oz("sezon_ici_b", "C"), "+0 kişi;-0 kişi"),
        ("3", "Sezonluk personel geçen yıldan AZ.",
         "31 Ağustos'ta çalışan sezonluk: 65 → 62 kişi.", _oz("sezonluk_b", "D"), "+0 kişi;-0 kişi"),
        ("4", "Aynı dönemde elleçlenen ürün adedi arttı.",
         "Adet enflasyondan etkilenmez — fiilen kasadan geçen, rafa dizilen mal.",
         _oz("adet"), "+0,0%"),
        ("5", "Ciro arttı.",
         "KDV dahil, iadeler düşülmüş.", _oz("kdvharic"), "+0,0%"),
        ("6", "KİŞİ BAŞINA düşen iş de arttı.",
         "Kişi başı ürün adedi ve günlük adet birlikte yükseldi.", _oz("adet_kisi"), "+0,0%"),
        ("7", "İş hacmi, kadronun yaklaşık 3 KATI hızla büyüdü.",
         "Ürün adedi ÷ kadro büyümesi (ciro oranı değil).", _oz("kat_adet", "B"), "0,0\"x\""),
        ("8", "Artış yönetimde değil, RAFIN ÖNÜNDE.",
         "Yönetim · Mal Kabul · İdari İşler kadrosu değişmedi; artış satış ve kasa reyonlarında.",
         None, None),
        ("9", "Büyüme kurumsaldan gelmedi, mağazadan geldi.",
         "Sınav Okulları Ocak–Ağustos cirosu küçüldü; mağaza tarafı büyüdü.",
         "='Oca-Agu'!G4", "+0,0%"),
    ]

    s = 5
    for no, baslik, aciklama, formul, fmt in satirlar:
        n = ws.cell(s, 1, no)
        n.font = Font(bold=True, size=11, color="FFFFFF")
        n.fill = PatternFill("solid", fgColor="1F5B57")
        n.alignment = Alignment(horizontal="center", vertical="center")
        t = ws.cell(s, 2, baslik)
        t.font = Font(bold=True, size=11.5)
        t.alignment = Alignment(vertical="center")
        if formul:
            c = ws.cell(s, 3, formul)
            c.number_format = fmt
            c.font = Font(bold=True, size=14, color="1F7A4D")
            c.alignment = Alignment(horizontal="right", vertical="center")
        s += 1
        a = ws.cell(s, 2, aciklama)
        a.font = Font(size=10, color="444444")
        a.alignment = Alignment(wrap_text=True, vertical="top")
        ws.row_dimensions[s].height = 26
        s += 1

    s += 1
    k = ws.cell(s, 2, "TEK CÜMLE: Kadro farkı 1 Temmuz'dan önce kurulmuştu; sezon içinde kadro küçülürken "
                      "iş hacmi %35 büyüdü, kişi başına düşen iş %21 arttı.")
    k.font = Font(bold=True, size=11, color="1F5B57")
    k.alignment = Alignment(wrap_text=True, vertical="center")
    ws.cell(s, 1).fill = PatternFill("solid", fgColor="FFF3CD")
    ws.row_dimensions[s].height = 34
    s += 2

    ws.cell(s, 2, "Rakamların kaynağı ve kontrolü: Ozet · Magaza · Kadro · Bolum · Yillar · Oca-Agu · Yontem "
                  "sayfaları. Kadro = Zirve İK (İK'nın kendi karşılaştırma raporuyla birebir), iş hacmi = "
                  "DerinSIS mağaza satışı (Sınav hariç).").font = NOT_YAZI
    ws.cell(s, 2).alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[s].height = 28
    return ws


# ------------------------------------------------------------------ Ozet
def sayfa_ozet(wb, veri):
    """Kapsam ETIKETLI ozet + KOPRU kontrolu.

    ⚠ 02.09.2026 kullanici uyarisi: onceki surumde iki kapsam (3 POS magazasi vs 5 magaza) ve iki tarih
    (30.06 taban vs 31.08 kesim) etiketsiz yan yana duruyordu -> "rakamlar birbiriyle tutmuyor" goruntusu.
    Simdi her blok kapsamini yaziyor, altta KOPRU blogu aritmetigi formulle ispatliyor (kontrol = 0).
    """
    ws = wb.active
    ws.title = "Ozet"
    mag = veri["magaza"]
    gun = veri["meta"]["gun"]
    k5 = veri["kadro_5magaza"]
    POS = {"İST. YOLU", "ÖZLÜCE", "FSM"}

    # 3 POS magazasinin kadrolu/sezonluk ayrimi — magaza_kadro'dan (ayni kaynak, ayni as-of konvansiyonu)
    pos_kadrolu = {y: sum(m["kadrolu_kesim%d" % (y % 100)] for m in veri["magaza_kadro"] if m["sube"] in POS)
                   for y in (ONCEKI, CARI)}
    pos_sezonluk = {y: sum(m["sezonluk_kesim%d" % (y % 100)] for m in veri["magaza_kadro"] if m["sube"] in POS)
                    for y in (ONCEKI, CARI)}
    disi = {y: (k5["kadrolu_kesim%d" % (y % 100)] - pos_kadrolu[y]
                + k5["sezonluk_kesim%d" % (y % 100)] - pos_sezonluk[y]) for y in (ONCEKI, CARI)}

    kolonlar = [("Olcu", 44, None), ("%d" % ONCEKI, 16, None), ("%d" % CARI, 16, None),
                ("Fark", 15, None), ("Degisim", 11, YUZDE)]
    ws.cell(1, 1, "Ayni kadro, daha cok is — kapsamlar AYRI etiketli, altta kopru kontrolu").font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    def blok(s, metin):
        c = ws.cell(s, 1, metin)
        c.font = Font(bold=True, size=10, color="FFFFFF")
        for k in range(1, 6):
            ws.cell(s, k).fill = PatternFill("solid", fgColor="1F5B57")
        return s + 1

    def satir(s, etiket, v25, v26, fmt, oran=True, vurgu=False):
        ws.cell(s, 1, "   " + etiket).border = KENAR
        for kol, v in ((2, v25), (3, v26)):
            h = ws.cell(s, kol, v)
            h.number_format = fmt
            h.border = KENAR
            if vurgu:
                h.fill = GRI
                h.font = Font(bold=True)
        f = ws.cell(s, 4, "=C%d-B%d" % (s, s))
        f.number_format = "+#,##0;-#,##0;0" if fmt in (ADET, TL) else fmt
        f.border = KENAR
        if vurgu:
            f.fill = VURGU
            f.font = Font(bold=True)
        if oran:
            d = ws.cell(s, 5, '=IF(B%d=0,"",C%d/B%d-1)' % (s, s, s))
            d.number_format = YUZDE
            d.border = KENAR
        return s + 1

    # ---------------- KAPSAM A — uc POS magazasi
    s = blok(4, "KAPSAM A — UC POS MAGAZASI (FSM · Ozluce · Ist. Yolu) · is hacmi YALNIZ burada olculebilir")
    r_kad_a = s
    s = satir(s, "Kadrolu — 31.08", pos_kadrolu[ONCEKI], pos_kadrolu[CARI], ADET)
    r_sez_a = s
    s = satir(s, "Sezonluk — 31.08", pos_sezonluk[ONCEKI], pos_sezonluk[CARI], ADET)
    r_toplam_a = s
    ws.cell(s, 1, "= TOPLAM KADRO — 31.08 (kisi)").font = Font(bold=True)
    ws.cell(s, 1).border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d+%s%d" % (h, r_kad_a, h, r_sez_a))
        c.number_format = ADET
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    f = ws.cell(s, 4, "=C%d-B%d" % (s, s)); f.number_format = "+#,##0;-#,##0;0"; f.border = KENAR; f.fill = GRI
    d = ws.cell(s, 5, "=C%d/B%d-1" % (s, s)); d.number_format = YUZDE; d.border = KENAR; d.fill = GRI
    s += 1
    r_adet = s
    s = satir(s, "Urun adedi (elleclenen) — %d gun" % gun,
              sum(m["adet%d" % (ONCEKI % 100)] for m in mag),
              sum(m["adet%d" % (CARI % 100)] for m in mag), ADET)
    r_kh = s
    s = satir(s, "Ciro — KDV haric (TL)",
              sum(m["kdvharic%d" % (ONCEKI % 100)] for m in mag),
              sum(m["kdvharic%d" % (CARI % 100)] for m in mag), TL)
    s = satir(s, "Ciro — KDV dahil (TL)",
              sum(m["kdvdahil%d" % (ONCEKI % 100)] for m in mag),
              sum(m["kdvdahil%d" % (CARI % 100)] for m in mag), TL)
    s += 1

    # ---------------- KISI BASI (kapsam A)
    s = blok(s, "KISI BASI — asil olcu · kapsam A toplam kadrosuna bolunur (satir %d)" % r_toplam_a)
    r_adet_kisi = s      # ilk kisi-basi satiri (indeks sozlugu icin)
    for etiket, fmt, f25, f26 in [
        ("Urun adedi / kisi", ADET, "=B%d/B%d" % (r_adet, r_toplam_a), "=C%d/C%d" % (r_adet, r_toplam_a)),
        ("Urun adedi / kisi / gun", ADET1, "=B%d/B%d/%d" % (r_adet, r_toplam_a, gun), "=C%d/C%d/%d" % (r_adet, r_toplam_a, gun)),
        ("Ciro (KDV haric) / kisi (TL)", TL, "=B%d/B%d" % (r_kh, r_toplam_a), "=C%d/C%d" % (r_kh, r_toplam_a)),
    ]:
        ws.cell(s, 1, "   " + etiket).border = KENAR
        for kol, f in ((2, f25), (3, f26)):
            c = ws.cell(s, kol, f)
            c.number_format = fmt
            c.border = KENAR
            c.fill = GRI
        fk = ws.cell(s, 4, "=C%d-B%d" % (s, s)); fk.number_format = fmt; fk.border = KENAR; fk.fill = GRI
        dd = ws.cell(s, 5, "=C%d/B%d-1" % (s, s)); dd.number_format = YUZDE; dd.border = KENAR
        dd.fill = GRI; dd.font = YESIL_YAZI
        s += 1
    r_kat_adet = s       # "kac kat" (ADET ÷ kadro) satiri — Sunum sayfasi BURAYI referans alir
    ws.cell(s, 1, "   Is buyumesi kadro buyumesinin kac kati (adet ÷ kadro)").border = KENAR
    kat = ws.cell(s, 2, "=E%d/E%d" % (r_adet, r_toplam_a))
    kat.number_format = KAT; kat.fill = VURGU; kat.border = KENAR; kat.font = Font(bold=True, size=12)
    ws.cell(s, 3, "adet degisimi ÷ kadro degisimi").font = NOT_YAZI
    s += 1
    ws.cell(s, 1, "   ayni oran ciro ile (ciro ÷ kadro)").border = KENAR
    kat2 = ws.cell(s, 2, "=E%d/E%d" % (r_kh, r_toplam_a))
    kat2.number_format = KAT; kat2.border = KENAR
    s += 2

    # ---------------- KAPSAM B — bes magaza
    s = blok(s, "KAPSAM B — BES MAGAZA (+ Heykel, Sura: POS raporlamasinda YOK -> is hacmi olculemez)")
    r_taban_b = s
    s = satir(s, "Kadrolu — TABAN 30.06 (sezon oncesi kurulu kadro)",
              k5["kadrolu_taban%d" % (ONCEKI % 100)], k5["kadrolu_taban%d" % (CARI % 100)], ADET, vurgu=True)
    r_kesim_b = s
    s = satir(s, "Kadrolu — KESIM 31.08", k5["kadrolu_kesim%d" % (ONCEKI % 100)],
              k5["kadrolu_kesim%d" % (CARI % 100)], ADET)
    r_sezon_ici_b = s    # sezon ici degisim satiri (Sunum referansi)
    ws.cell(s, 1, "   Sezon ici kadrolu degisim (kesim - taban)").border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d-%s%d" % (h, r_kesim_b, h, r_taban_b))
        c.number_format = "+0;-0;0"
        c.border = KENAR
        c.fill = VURGU
        c.font = Font(bold=True)
    ws.cell(s, 4, "iki yilda da -4: sezon icinde kadro BUYUMEDI").font = NOT_YAZI
    s += 1
    r_sez_b = s          # sezonluk 31.08 satiri (Sunum referansi)
    s = satir(s, "Sezonluk — 31.08", k5["sezonluk_kesim%d" % (ONCEKI % 100)],
              k5["sezonluk_kesim%d" % (CARI % 100)], ADET)
    r_toplam_b = s
    s = satir(s, "= Toplam kadro — 31.08", k5["toplam_kesim%d" % (ONCEKI % 100)],
              k5["toplam_kesim%d" % (CARI % 100)], ADET)
    s += 1

    # ---------------- KOPRU
    s = blok(s, "KOPRU — A ile B nasil bagli (KONTROL satiri 0 olmali)")
    r_k1 = s
    ws.cell(s, 1, "   Kapsam A toplam kadro (31.08)").border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d" % (h, r_toplam_a))
        c.number_format = ADET
        c.border = KENAR
    s += 1
    r_k2 = s
    s = satir(s, "+ Heykel + Sura (kadrolu + sezonluk)", disi[ONCEKI], disi[CARI], ADET, oran=False)
    r_k3 = s
    ws.cell(s, 1, "   = Kapsam B toplam kadro (hesap)").border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d+%s%d" % (h, r_k1, h, r_k2))
        c.number_format = ADET
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    s += 1
    ws.cell(s, 1, "   KONTROL: hesap - B blogundaki toplam (0 OLMALI)").font = Font(bold=True)
    ws.cell(s, 1).border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d-%s%d" % (h, r_k3, h, r_toplam_b))
        c.number_format = "0"
        c.border = KENAR
        c.fill = VURGU
        c.font = Font(bold=True)
    s += 2

    # ⚠ Sunum sayfasi bu satir numaralarina SABIT referansla bagliydi; blok buyudugunde sessizce
    #   yanlis hucreyi okuyordu (silent-failure-hunter bulgusu 2). Artik indeksler DONDURULUR.
    ws._indeks = {"kadro_a": r_toplam_a, "adet": r_adet, "kdvharic": r_kh,
                  "adet_kisi": r_adet_kisi, "kat_adet": r_kat_adet,
                  "taban_b": r_taban_b, "kesim_b": r_kesim_b,
                  "sezon_ici_b": r_sezon_ici_b, "sezonluk_b": r_sez_b}
    _notlar(ws, [
        "NEDEN IKI KAPSAM: is hacmi (adet/ciro) yalniz POS raporlamasi olan UC magazada olculebilir;",
        "   kadro hareketi ise bes magazanin tamaminda anlamli. Karismasin diye bloklar ayri + kopru var.",
        "NEDEN IKI TARIH: 30.06 = sezon baslamadan onceki kurulu kadro (+14 farki BURADA olustu),",
        "   31.08 = sezon zirvesindeki fiili kadro. Ayni yilin iki farkli gunu; birbirinin yerine gecmez.",
        "Kadrolu = Kadro <> 'SEZONLUK' · Sezonluk = Kadro = 'SEZONLUK' · Toplam = ikisinin toplami.",
        "Tum yuzde / oran / kopru satirlari Excel FORMULU — ham rakami degistir, hepsi kendini gunceller.",
    ], s)
    return ws
