# -*- coding: utf-8 -*-
"""Slaytlar: kapak · norma gore durum · kadro akisi · bes magaza tablosu."""
# ⚠ Yildiz import BILINCLI: palet + cizim yardimcilarinin TAMAMI kullaniliyor ve
#   `bin`/`yzd` gibi bicim yardimcilari sunum_ortak'ta tanimli (tek kaynak).
from sunum_ortak import *          # noqa: F401,F403

def slayt_kapak(C):
    """Kapak — deste basligi + donem tanimi."""
    # ================================================================= 1 KAPAK
    s = add("Başlık Slaydı")
    setph(s, 0, "Kadro ve İş Hacmi Değerlendirmesi")
    setph(s, 1, "Sezon 2026 · Mağazalar · kadro 30.06 ve 31.08 · iş hacmi %s – %s ile %s – %s"
                % (C.PT[str(ONCEKI)][0], C.PT[str(ONCEKI)][1], C.PT[str(CARI)][0], C.PT[str(CARI)][1]))


def slayt_norma_gore_durum(C):
    """ILK MESAJ: norma gore durum (norm vs operasyonel kadro)."""
    # ================================================================= 2 NORMA GORE DURUM (ILK MESAJ)
    # Norm sunumun OMURGASI: patron "fazla eleman aldiniz" derken sirketin kendi norm tablosuna gore
    # EKSIK calisiliyor. Bu yuzden kapaktan hemen sonra gelir; sonraki slaytlar bu cerceveye baglanir.
    nrm0 = C.v.get("norm")
    if nrm0:
        s = add("Yalnızca Başlık"); setph(s, 0, "Yönetici Özeti — Norma Göre Durum")
        tp0 = nrm0["toplam"]
        fark0 = tp0["toplam_kesim26"] - tp0["norm_toplam"]

        kpi(s, 0.6, 1.5, 3.9, "NORM · KADRO + SEZON", "%d" % tp0["norm_toplam"],
            "kadrolu %d + sezonluk %d · %s tarihli norm" % (tp0["norm"], tp0["norm_sezonluk"], nrm0["tarih"]),
            MGREY, 34, ikon="users")
        kpi(s, 4.68, 1.5, 3.9, "GERÇEK · 31 AĞUSTOS",
            "%d" % (tp0["kadrolu_kesim26"] - sum(a.get("etkinlik", 0) + a.get("engelli", 0)
                                                 for a in nrm0.get("ayrik", {}).values())
                    + tp0["sezonluk_kesim26"]),
            "engelli ve etkinlik sayılmadı", MGREY, 34, ikon="users")
        ayr0 = nrm0.get("ayrik", {})
        dis0 = sum(a.get("etkinlik", 0) + a.get("engelli", 0) for a in ayr0.values())
        kad_ops0 = tp0["kadrolu_kesim26"] - dis0
        fark0 = (kad_ops0 + tp0["sezonluk_kesim26"]) - tp0["norm_toplam"]
        kpi(s, 8.75, 1.5, 3.9, "NORM İLE FARK", "%+d kişi" % fark0,
            "kadrolu %+d · sezonluk %+d"
            % (kad_ops0 - tp0["norm"], tp0["sezonluk_kesim26"] - tp0["norm_sezonluk"]),
            DRED, 28, ikon="alert-triangle")

        rrect(s, 0.6, 3.62, 12.05, 0.82, LGREY, RED, lw=2)
        tb(s, 0.9, 3.62, 11.5, 0.82,
           [("31 Ağustos'ta çalışan personel %d kişi; norm tablosundaki karşılığı %d kişi. "
             "Aradaki fark %d kişi." % (kad_ops0 + tp0["sezonluk_kesim26"], tp0["norm_toplam"],
                                        abs(fark0)), 15, True, DRED)], align=PP_ALIGN.CENTER,
           anchor=MSO_ANCHOR.MIDDLE)

        card(s, 0.6, 4.52, 12.05, 1.22, RED, ikon="package")
        tb(s, 0.95, 4.64, 6.0, 0.3, [("AYNI DÖNEMDE YAPILAN İŞ · ÜÇ MAĞAZA", 9.5, True, GREY)])
        tb(s, 0.95, 4.98, 11.2, 0.68,
           [("ürün adedi %s (%s → %s) · ciro %s"
             % (yzd(C.d_adet), bin(C.adet25), bin(C.adet26), yzd(C.d_ciro)), 14, True, DRED)])
        tb(s, 0.6, 5.82, 12.05, 0.26,
           [("Fark sezondan önce oluştu: 30 Haziran'da %d → %d (%+d). Sezon içinde kadrolu %+d kişi. "
             "Personel başına iş %s."
             % (C.k5["kadrolu_taban25"], C.k5["kadrolu_taban26"], C.taban_fark, C.sezon_ici_26, yzd(C.d_kb)),
             9.5, False, GREY)])

        dipnot(s, "* Norm, engelli dışındaki personeli sayar (yönetim kararı). Etkinlik kadrosu da norm "
                  "dışı; gerçek rakamdan düşüldü (engelli %d, etkinlik %d kişi). İK kaydında "
                  "kadrolu %d + sezonluk %d = %d kişi var. Norm tablosu: BKMKİTAP Mağaza Kadro ve Sezon "
                  "Takip Tablosu, %s · Dört mağaza (Şura yok) · Satış: üç POS mağazası."
               % (sum(a.get("engelli", 0) for a in ayr0.values()),
                  sum(a.get("etkinlik", 0) for a in ayr0.values()),
                  tp0["kadrolu_kesim26"], tp0["sezonluk_kesim26"], tp0["toplam_kesim26"], nrm0["tarih"]))
        sig(s)


def slayt_kadro_akisi(C):
    """Kadro farkinin OLUSUM DONEMI (taban 30.06 vs sezon ici)."""
    # ================================================================= 5 KADRO AKISI
    s = add("Yalnızca Başlık"); setph(s, 0, "Kadro Farkının Oluşum Dönemi")
    akis = [("2025 tabanı", "%d" % C.k5["kadrolu_taban25"], "30 Haziran 2025", MGREY),
            ("Sezon öncesi eklenen", "%+d" % C.taban_fark, "1 Temmuz'dan önce", RED),
            ("2026 tabanı", "%d" % C.k5["kadrolu_taban26"], "30 Haziran 2026", MGREY),
            ("Sezon içi değişim", "%+d" % C.sezon_ici_26, "1 Tem – 31 Ağu", DRED),
            ("31 Ağustos 2026", "%d" % C.k5["kadrolu_kesim26"], "sezon zirvesi", MGREY)]
    for i, (h, deger, alt, col) in enumerate(akis):
        x = 0.6 + i * 2.44
        card(s, x, 1.55, 2.28, 1.9, col)
        tb(s, x + 0.16, 1.68, 2.0, 0.5, [(h, 10.5, True, GREY)])
        tb(s, x + 0.16, 2.15, 2.0, 0.7, [(deger, 30, True, col)])
        tb(s, x + 0.16, 2.92, 2.0, 0.4, [(alt, 9.5, False, MGREY)])
        if i < 4:
            tb(s, x + 2.28, 2.2, 0.16, 0.4, [("›", 20, True, MGREY)], align=PP_ALIGN.CENTER)

    cift_bar(s, 0.6, 3.7, 6.1, 2.05, ["Taban 30.06", "Kesim 31.08"],
             (C.k5["kadrolu_taban25"], C.k5["kadrolu_kesim25"]),
             (C.k5["kadrolu_taban26"], C.k5["kadrolu_kesim26"]), sifirdan=True)
    rrect(s, 7.0, 3.8, 5.65, 1.75, LGREY, RED, lw=1.5)
    tb(s, 7.25, 3.92, 5.2, 1.55,
       [("Sezon döneminde kadrolu personel artmadı", 15, True, DRED),
        ("Kadrolu personel %d → %d (%+d). Geçen yıl da aynı yönde (%+d). Sezonda alınan kadrolu "
         "personel ayrılanların yerine geldi, kadroyu büyütmedi."
         % (C.k5["kadrolu_taban26"], C.k5["kadrolu_kesim26"], C.sezon_ici_26, C.sezon_ici_25), 12, False, INK)], sp=1.15)
    dipnot(s, C.DIP_BES)
    sig(s)


def slayt_bes_magaza(C):
    """Magaza bazinda kadro — bes magaza."""
    # ================================================================= 6 BES MAGAZA TABLOSU
    s = add("Yalnızca Başlık"); setph(s, 0, "Mağaza Bazında Kadro")
    basliklar = ["Mağaza",
                 "Kadrolu 30.06\n2025", "Kadrolu 30.06\n2026",
                 "Kadrolu 31.08\n2025", "Kadrolu 31.08\n2026",
                 "Sezon içi\n2025", "Sezon içi\n2026",
                 "Sezonluk 31.08\n2025", "Sezonluk 31.08\n2026",
                 "GENEL TOPLAM" + chr(10) + "31.08 · 2025", "GENEL TOPLAM" + chr(10) + "31.08 · 2026"]
    satirlar = [basliklar]
    for m in C.v["magaza_kadro"]:
        satirlar.append([tr_title(m["sube"]),
                         str(m["kadrolu_taban25"]), str(m["kadrolu_taban26"]),
                         str(m["kadrolu_kesim25"]), str(m["kadrolu_kesim26"]),
                         "%+d" % (m["kadrolu_kesim25"] - m["kadrolu_taban25"]),
                         "%+d" % (m["kadrolu_kesim26"] - m["kadrolu_taban26"]),
                         str(m["sezonluk_kesim25"]), str(m["sezonluk_kesim26"]),
                         str(m["kadrolu_kesim25"] + m["sezonluk_kesim25"]),
                         str(m["kadrolu_kesim26"] + m["sezonluk_kesim26"])])
    satirlar.append(["TOPLAM",
                     str(C.k5["kadrolu_taban25"]), str(C.k5["kadrolu_taban26"]),
                     str(C.k5["kadrolu_kesim25"]), str(C.k5["kadrolu_kesim26"]),
                     "%+d" % C.sezon_ici_25, "%+d" % C.sezon_ici_26,
                     str(C.k5["sezonluk_kesim25"]), str(C.k5["sezonluk_kesim26"]),
                     str(C.k5["toplam_kesim25"]), str(C.k5["toplam_kesim26"])])
    t = s.shapes.add_table(len(satirlar), 11, Inches(0.6), Inches(1.55), Inches(12.05), Inches(3.3)).table
    for w, gen in zip(range(11), (1.55, 1.1, 1.1, 1.1, 1.1, 0.92, 0.92, 1.1, 1.1, 1.03, 1.03)):
        t.columns[w].width = Inches(gen)
    t.rows[0].height = Inches(0.55)
    for r, row in enumerate(satirlar):
        for c, val in enumerate(row):
            cell = t.cell(r, c); cell.text = val
            son_satir = (r == len(satirlar) - 1)
            for para in cell.text_frame.paragraphs:
                para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
                for run in para.runs:
                    run.font.size = Pt(8.5 if r == 0 else 10.5)
                    run.font.name = "Calibri"
                    run.font.bold = (r == 0 or son_satir or c in (5, 6, 9, 10))
                    run.font.color.rgb = WHITE if r == 0 else (DRED if c in (5, 6, 9, 10) else INK)
            cell.fill.solid()
            if r == 0:
                cell.fill.fore_color.rgb = RED
            elif son_satir:
                cell.fill.fore_color.rgb = LGREY
            elif c in (9, 10):
                cell.fill.fore_color.rgb = RGBColor(0xFD, 0xF2, 0xF3)   # genel toplam kolonu vurgusu
            else:
                cell.fill.fore_color.rgb = WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA)
    pos_kadrolu = {y_: sum(m["kadrolu_kesim%d" % (y_ % 100)] for m in C.v["magaza_kadro"]
                           if m["sube"] in C.POS_SUBE) for y_ in (2025, 2026)}
    pos_sezonluk = {y_: sum(m["sezonluk_kesim%d" % (y_ % 100)] for m in C.v["magaza_kadro"]
                            if m["sube"] in C.POS_SUBE) for y_ in (2025, 2026)}
    rrect(s, 0.6, 4.95, 12.05, 0.75, LGREY, RED, lw=1.5)
    tb(s, 0.85, 4.95, 11.6, 0.75,
       [("İŞ HACMİ KAPSAMI — üç POS mağazası (FSM · Özlüce · İst. Yolu): kadrolu %d → %d · sezonluk %d → %d · "
         "toplam %d → %d kişi. Diğer slaytlardaki %d → %d rakamı budur."
         % (pos_kadrolu[2025], pos_kadrolu[2026], pos_sezonluk[2025], pos_sezonluk[2026],
            pos_kadrolu[2025] + pos_sezonluk[2025], pos_kadrolu[2026] + pos_sezonluk[2026],
            pos_kadrolu[2025] + pos_sezonluk[2025], pos_kadrolu[2026] + pos_sezonluk[2026]),
         11.5, True, DRED)], anchor=MSO_ANCHOR.MIDDLE)
    tb(s, 0.6, 5.78, 12.05, 0.3,
       [("Kadrolu = sezonluk olmayan personel. Sezon içi değişim, 30 Haziran ile 31 Ağustos "
         "arasındaki fark: %+d ve %+d — iki yıl da azalış." % (C.sezon_ici_25, C.sezon_ici_26), 10, False, GREY)], sp=1.15)
    dipnot(s, C.DIP_BES + " İş hacmi kapsamı üç POS mağazasıdır (%s)." % C.POS_ADLARI)
    sig(s)
