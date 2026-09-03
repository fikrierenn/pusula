# -*- coding: utf-8 -*-
"""Slaytlar: donem is hacmi · kisi basi (hizali pencere) · dort yillik seyir ·
bolum kirilimi · magaza performansi · kategori buyumesi · takvim kaymasi."""
# ⚠ Yildiz import BILINCLI: palet + cizim yardimcilarinin TAMAMI kullaniliyor ve
#   `bin`/`yzd` gibi bicim yardimcilari sunum_ortak'ta tanimli (tek kaynak).
from sunum_ortak import *          # noqa: F401,F403

def slayt_is_hacmi(C):
    """Donem is hacmi — adet · ciro · kadro."""
    # ================================================================= 8 IS HACMI
    s = add("Yalnızca Başlık"); setph(s, 0, "Dönem İş Hacmi")
    kpi(s, 0.6, 1.5, 3.9, "ELLEÇLENEN ÜRÜN", yzd(C.d_adet), "%s → %s adet" % (bin(C.adet25), bin(C.adet26)),
        YESIL, 32, ikon="package")
    kpi(s, 4.68, 1.5, 3.9, "CİRO · KDV DAHİL", yzd(C.d_ciro),
        "%s → %s milyon TL" % (bin(C.kd25 / 1e6, 1), bin(C.kd26 / 1e6, 1)), YESIL, 32, ikon="layers")
    kpi(s, 8.75, 1.5, 3.9, "KADRO · 3 MAĞAZA", yzd(C.d_kadro),
        "%d → %d kişi (sezonluk dahil)" % (C.kadro25, C.kadro26), MGREY, 32, ikon="users")

    cift_bar(s, 0.6, 3.5, 6.1, 2.15, ["Ürün adedi (bin)", "Ciro (milyon TL)", "Kadro (kişi)"],
             (C.adet25 / 1000, C.kd25 / 1e6, C.kadro25), (C.adet26 / 1000, C.kd26 / 1e6, C.kadro26))
    rrect(s, 7.0, 3.7, 5.65, 2.0, LGREY, RED, lw=1.5)
    tb(s, 7.25, 3.85, 5.2, 1.75,
       [("Neden adet sayıyoruz?", 14, True, DRED),
        ("Adet, fiyat artışından etkilenmez. Kasadan geçen, rafa dizilen, depodan çıkan gerçek "
         "mal miktarını gösterir. Ciroya zam karışır, adede karışmaz.", 12, False, INK)], sp=1.15)
    tb(s, 0.6, 5.72, 12.05, 0.32,
       [("Kaynak: DerinSIS mağaza satışı · Sınav hariç · iadeler düşülmüş · KDV dahil.", 10, False, MGREY)])
    dipnot(s, C.DIP_POS)
    sig(s)


def slayt_kisi_basi(C):
    """Personel basina is hacmi — okul-hizali pencere."""
    # ================================================================= 9 KISI BASI MAGAZA
    s = add("Yalnızca Başlık"); setph(s, 0, "Personel Başına İş Hacmi — Okul-Hizalı Pencere")
    kats, s1, s2 = [], [], []
    for ad in ("Özlüce", "İst. Yolu", "FSM"):
        m = C.mag[ad]
        kats.append(ad); s1.append(m["adet25"] / m["kadro25"]); s2.append(m["adet26"] / m["kadro26"])
    cift_bar(s, 0.6, 1.6, 6.3, 3.9, kats, tuple(s1), tuple(s2))
    y = 1.75
    for ad, a, b in zip(kats, s1, s2):
        card(s, 7.2, y, 5.45, 1.15, RED)
        tb(s, 7.45, y + 0.12, 3.0, 0.35, [(ad, 13, True, CHAR)])
        tb(s, 7.45, y + 0.5, 3.05, 0.5,
           [("%s → %s adet/kişi" % (bin(a), bin(b)), 12.5, False, INK)])
        tb(s, 10.7, y + 0.12, 1.85, 0.5, [(yzd(b / a - 1), 17, True, YESIL)], align=PP_ALIGN.RIGHT)
        y += 1.3
    tb(s, 0.6, 5.68, 12.05, 0.34,
       [("Kişi = 31 Ağustos'ta o mağazada çalışan tüm personel (sezonluk dahil). Kadrosu en çok "
         "büyüyen mağazada bile kişi başına iş arttı (İst. Yolu %d → %d kişi)."
         % (C.mag["İst. Yolu"]["kadro25"], C.mag["İst. Yolu"]["kadro26"]), 9.5, False, GREY)])
    dipnot(s, C.DIP_POS)
    sig(s)


def slayt_dort_yil(C):
    """Dort yillik seyir — Oca-Agu adet / kadrolu."""
    # ================================================================= 10 4 YILLIK TREND
    # K-16: bu slayt Oca-Agu adedini KADROLU'ya bolerken onceki slayt hizali-pencere adedini TUM
    #   kadroya boluyor — iki farkli olcek. Basliklarda ve etiketlerde olcu ADIYLA yazilir.
    s = add("Yalnızca Başlık")
    setph(s, 0, "Dört Yıllık Seyir — Ocak-Ağustos Adedi / Kadrolu")
    cd = CategoryChartData(); cd.categories = [str(y_["yil"]) for y_ in C.v["yillar"]]
    cd.add_series("Oca-Ağu adet ÷ kadrolu", tuple(y_["adet"] / y_["kadrolu"] for y_ in C.v["yillar"]))
    lc = s.shapes.add_chart(XL_CHART_TYPE.LINE_MARKERS, Inches(0.6), Inches(1.6),
                            Inches(7.2), Inches(3.9), cd).chart
    lc.has_title = False; lc.has_legend = False
    lc.font.size = Pt(11); lc.font.name = "Calibri"
    lc.plots[0].has_data_labels = True
    lc.plots[0].data_labels.number_format_is_linked = False
    lc.plots[0].data_labels.number_format = '#,##0'
    lc.plots[0].data_labels.font.size = Pt(10)
    ser = lc.series[0]; ser.format.line.color.rgb = RED; ser.format.line.width = Pt(2.5)
    ser.smooth = False
    # marka: varsayilan mavi baklava isaretci YASAK -> kirmizi daire
    ser.marker.style = XL_MARKER_STYLE.CIRCLE
    ser.marker.size = 7
    ser.marker.format.fill.solid(); ser.marker.format.fill.fore_color.rgb = RED
    ser.marker.format.line.color.rgb = WHITE

    # K-10: bu ucu ONCE elle yazilmisti (60 -> 91, +%11, +%28,8). JSON yenilenince bayatlardi;
    #   artik v["yillar"]'dan turetilir.
    _yl = {y_["yil"]: y_ for y_ in C.v["yillar"]}
    _yrs = sorted(_yl)
    _atl_o, _atl_y = max(zip(_yrs, _yrs[1:]),
                         key=lambda p: _yl[p[1]]["kadrolu"] - _yl[p[0]]["kadrolu"])
    _kb = {y_: _yl[y_]["adet"] / _yl[y_]["kadrolu"] for y_ in _yrs}
    notlar = [("%d'te kadro atladı" % _atl_y,
               "Kadrolu %d → %d. Adet yalnız %s arttı → kişi başı iş %s."
               % (_yl[_atl_o]["kadrolu"], _yl[_atl_y]["kadrolu"],
                  yzd(_yl[_atl_y]["adet"] / _yl[_atl_o]["adet"] - 1),
                  "düştü" if _kb[_atl_y] < _kb[_atl_o] else "arttı"), DRED),
              ("Ama %d 'norm' değil" % _atl_o,
               "O yıl FSM kasada 0, Özlüce kasada 1 kişi vardı — eksik kadroyla çalışma.", GREY),
              ("%d → %d toparlanma" % (_atl_y, _yrs[-1]),
               "Kişi başı iş %s arttı; bu yıl kadro büyürken verim de arttı."
               % yzd(_kb[_yrs[-1]] / _kb[_atl_y] - 1), RED)]
    y = 1.75
    for h, d, col in notlar:
        card(s, 8.1, y, 4.55, 1.2, col)
        tb(s, 8.35, y + 0.12, 4.05, 0.35, [(h, 12.5, True, CHAR)])
        tb(s, 8.35, y + 0.48, 4.05, 0.7, [(d, 10.5, False, GREY)])
        y += 1.35
    tb(s, 0.6, 5.65, 12.05, 0.5,
       [("Ölçü: Ocak–Ağustos ürün adedi ÷ kadrolu personel (sezonluk hariç). Diğer slayttaki "
         "ölçüyle seviyeler değil, yönler karşılaştırılır.", 10, False, MGREY)])
    dipnot(s, C.DIP_OCA_AGU + " · Kadro her yıl 31 Ağustos günü sayılır · Sınav Okulları satışı adede "
              "girmiyor; o işe bakan personel kadroda kalıyor. Etki her yıl aynı yönde, "
              "karşılaştırma geçerli.")
    sig(s)


def slayt_bolum_kirilimi(C):
    """Bolum bazinda kadro degisimi."""
    # ================================================================= 12 BOLUM KIRILIMI
    s = add("Yalnızca Başlık"); setph(s, 0, "Bölüm Bazında Kadro Değişimi")
    ilk5 = C.buyuyen[:5]
    cd = CategoryChartData()
    cd.categories = [tr_title(b["bolum"]) for b in ilk5] + [tr_title(b["bolum"]) for b in C.sabit]
    cd.add_series("kadrolu değişim (kişi)",
                  tuple([b["kadrolu26"] - b["kadrolu25"] for b in ilk5] + [0 for _ in C.sabit]))
    bc = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(1.6),
                            Inches(7.2), Inches(3.6), cd).chart
    bc.has_title = False; bc.has_legend = False
    bc.font.size = Pt(10.5); bc.font.name = "Calibri"
    bc.plots[0].has_data_labels = True; bc.plots[0].gap_width = 60
    bc.plots[0].data_labels.number_format_is_linked = False
    bc.plots[0].data_labels.number_format = '+0;-0;0'
    bc.series[0].format.fill.solid(); bc.series[0].format.fill.fore_color.rgb = RED
    bc.plots[0].vary_by_categories = False

    card(s, 8.1, 1.6, 4.55, 1.75, MGREY)
    tb(s, 8.35, 1.72, 4.05, 0.35, [("KADROSU DEĞİŞMEYEN BÖLÜMLER", 10.5, True, GREY)])
    tb(s, 8.35, 2.08, 4.05, 1.2,
       [("  ·  ".join("%s +0" % tr_title(b["bolum"]) for b in C.sabit) or "—", 13, True, CHAR),
        ("Bu %d bölümde kadro değişimi sıfırdır." % len(C.sabit), 10.5, False, GREY)], sp=1.15)
    card(s, 8.1, 3.5, 4.55, 1.7, RED)
    tb(s, 8.35, 3.62, 4.05, 0.35, [("KADROSU ARTAN BÖLÜMLER", 10.5, True, GREY)])
    tb(s, 8.35, 3.98, 4.05, 1.15,
       [("  ·  ".join("%s %+d" % (tr_title(b["bolum"]), b["kadrolu26"] - b["kadrolu25"]) for b in ilk5),
         12, True, DRED)], sp=1.15)
    rrect(s, 0.6, 5.28, 12.05, 0.72, LGREY, RED, lw=1.5)
    tb(s, 0.9, 5.28, 11.5, 0.72,
       [("31 Ağustos'ta kadrolu %+d kişilik artışın tamamı satış ve kasa bölümlerinde; "
         "yönetim kadrosunda değişim yoktur." % C.kesim_fark, 13.5, True, DRED)],
       anchor=MSO_ANCHOR.MIDDLE)
    dipnot(s, C.DIP_BES)
    sig(s)


def slayt_magaza_performans(C):
    """Magaza performans karsilastirmasi."""
    # ================================================================= 12c MAGAZA PERFORMANS
    s = add("Yalnızca Başlık"); setph(s, 0, "Mağaza Performans Karşılaştırması")
    perf = [["Mağaza", "Kadro 31.08", "Kadro Δ", "Ürün adedi Δ", "Ciro Δ", "Adet/kişi Δ", "İş ÷ kadro"]]
    for ad in ("Özlüce", "İst. Yolu", "FSM"):
        m = C.mag[ad]
        dk = m["kadro26"] / m["kadro25"] - 1
        da = m["adet26"] / m["adet25"] - 1
        dc = m["kdvdahil26"] / m["kdvdahil25"] - 1
        dkb = (m["adet26"] / m["kadro26"]) / (m["adet25"] / m["kadro25"]) - 1
        perf.append([ad, "%d → %d" % (m["kadro25"], m["kadro26"]), yzd(dk), yzd(da), yzd(dc), yzd(dkb),
                     ("%.1f" % (da / dk)).replace(".", ",") + "x"])
    perf.append(["TOPLAM", "%d → %d" % (C.kadro25, C.kadro26), yzd(C.d_kadro), yzd(C.d_adet), yzd(C.d_ciro),
                 yzd(C.d_kb), ("%.1f" % C.kat).replace(".", ",") + "x"])

    # K-10: "en cok kadro ekleyen magazada dahi oran X kat" cumlesi elle yaziliydi (2,2) — turetilir.
    _en_kadro = max(("Özlüce", "İst. Yolu", "FSM"),
                    key=lambda a: C.mag[a]["kadro26"] / C.mag[a]["kadro25"] - 1)
    _m = C.mag[_en_kadro]
    _en_kadro_oran = ("%.1f" % ((_m["adet26"] / _m["adet25"] - 1)
                                / (_m["kadro26"] / _m["kadro25"] - 1))).replace(".", ",")

    t = s.shapes.add_table(len(perf), 7, Inches(0.6), Inches(1.5), Inches(12.05), Inches(1.9)).table
    for i, gen in enumerate((2.2, 1.9, 1.5, 1.85, 1.5, 1.7, 1.4)):
        t.columns[i].width = Inches(gen)
    for r, row in enumerate(perf):
        for c, val in enumerate(row):
            cell = t.cell(r, c); cell.text = val
            son = (r == len(perf) - 1)
            for para in cell.text_frame.paragraphs:
                para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
                for run in para.runs:
                    run.font.size = Pt(11.5); run.font.name = "Calibri"
                    run.font.bold = (r == 0 or son or c == 6)
                    run.font.color.rgb = WHITE if r == 0 else (YESIL if c in (3, 4, 5) and r > 0 else INK)
            cell.fill.solid()
            cell.fill.fore_color.rgb = RED if r == 0 else (LGREY if son else WHITE)

    kats2 = ["Özlüce", "İst. Yolu", "FSM"]
    cift_bar(s, 0.6, 3.6, 6.1, 2.3, kats2,
             tuple(0.0 for _ in kats2), tuple(0.0 for _ in kats2))  # yer tutucu, altta degistirilir
    s.shapes[-1]._element.getparent().remove(s.shapes[-1]._element)  # yer tutucuyu kaldir
    cd = CategoryChartData(); cd.categories = kats2
    cd.add_series("kadro Δ%", tuple((C.mag[a]["kadro26"] / C.mag[a]["kadro25"] - 1) * 100 for a in kats2))
    cd.add_series("ürün adedi Δ%", tuple((C.mag[a]["adet26"] / C.mag[a]["adet25"] - 1) * 100 for a in kats2))
    cd.add_series("ciro Δ%", tuple((C.mag[a]["kdvdahil26"] / C.mag[a]["kdvdahil25"] - 1) * 100 for a in kats2))
    ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(3.6),
                            Inches(7.4), Inches(2.35), cd).chart
    ch.has_title = False
    ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.TOP; ch.legend.include_in_layout = False
    ch.font.size = Pt(9.5); ch.font.name = "Calibri"
    ch.plots[0].gap_width = 60; ch.plots[0].has_data_labels = True
    ch.plots[0].data_labels.number_format_is_linked = False
    ch.plots[0].data_labels.number_format = '0"%"'
    ch.plots[0].data_labels.font.size = Pt(8.5)
    for i, col in enumerate((MGREY, RED, RGBColor(0x7A, 0x10, 0x20))):
        ch.series[i].format.fill.solid(); ch.series[i].format.fill.fore_color.rgb = col

    rrect(s, 8.2, 3.8, 4.45, 1.95, LGREY, RED, lw=1.5)
    tb(s, 8.45, 3.95, 4.0, 1.7,
       [("Değerlendirme", 13.5, True, DRED),
        ("Üç mağazada da iş, kadrodan daha hızlı arttı. En çok kadro alan "
         "%s mağazasında bile iş artışı kadronun %s katı." % (_en_kadro, _en_kadro_oran), 11.5, False, INK)], sp=1.15)
    dipnot(s, C.DIP_POS)
    sig(s)


def slayt_kategori(C):
    """Kategori buyumesi ve ilgili bolum kadrosu."""
    # ================================================================= 12d KATEGORI x BOLUM ESLESME
    s = add("Yalnızca Başlık"); setph(s, 0, "Kategori Büyümesi ve İlgili Bölüm Kadrosu")
    ESLES = {"Hazırlık Kitapları": "YARDIMCI KİTAP", "Kırtasiye": "KIRTASİYE", "Kitap": "KÜLTÜR",
             "Çocuk Kitabı": "ÇOCUK", "Oyuncak": "OYUNCAK", "Akademi": "AKADEMİ"}
    kadro_delta = {b["bolum"]: b["kadrolu26"] - b["kadrolu25"] for b in C.v["bolum"]}
    kat_veri = [k for k in C.v["kategori"] if k["kategori"] in ESLES]
    kat_veri.sort(key=lambda k: -kadro_delta.get(ESLES[k["kategori"]], 0))
    # K-13: tabloda YALNIZ bolum eslesmesi olan kategoriler var; geri kalanlar (Genel, Hediyelik,
    #   Kisisel Bakim...) gorunmuyordu -> "kadro en hizli buyuyene gitti" iddiasi denetlenemiyordu.
    #   Kalanlar tek "DIGER" satirinda toplanir + kapsam yuzdesi dipnota yazilir.
    _dis = [k for k in C.v["kategori"] if k["kategori"] not in ESLES]
    _tum25 = sum(k["adet25"] for k in C.v["kategori"]) or 1
    _tum26 = sum(k["adet26"] for k in C.v["kategori"]) or 1
    _kaps26 = sum(k["adet26"] for k in kat_veri)
    _kapsam_yzd = ("%%%.0f" % (100.0 * _kaps26 / _tum26))

    NL = chr(10)
    satir = [["Kategori", "Bakan bölüm", "Ürün adedi 2025 → 2026",
              "SEZON" + NL + "adet Δ", "SEZON" + NL + "ciro Δ",
              "OCA-AĞU" + NL + "adet Δ", "OCA-AĞU" + NL + "ciro Δ",
              "Bölüm" + NL + "kadro Δ"]]
    for k in kat_veri:
        b = ESLES[k["kategori"]]
        oa_adet = yzd(k["oa_adet26"] / k["oa_adet25"] - 1) if k.get("oa_adet25") else "—"
        oa_ciro = yzd(k["oa_ciro26"] / k["oa_ciro25"] - 1) if k.get("oa_ciro25") else "—"
        satir.append([k["kategori"], tr_title(b),
                      "%s → %s" % (bin(k["adet25"]), bin(k["adet26"])),
                      yzd(k["adet26"] / k["adet25"] - 1),
                      yzd(k["ciro26"] / k["ciro25"] - 1),
                      oa_adet, oa_ciro,
                      "%+d kişi" % kadro_delta.get(b, 0)])
    if _dis:
        _d25, _d26 = sum(k["adet25"] for k in _dis), sum(k["adet26"] for k in _dis)
        _dc25, _dc26 = sum(k["ciro25"] for k in _dis), sum(k["ciro26"] for k in _dis)
        _doa25, _doa26 = (sum(k.get("oa_adet25") or 0 for k in _dis),
                          sum(k.get("oa_adet26") or 0 for k in _dis))
        _doc25, _doc26 = (sum(k.get("oa_ciro25") or 0 for k in _dis),
                          sum(k.get("oa_ciro26") or 0 for k in _dis))
        satir.append(["DİĞER (%d kategori)" % len(_dis), "bölüm eşleşmesi yok",
                      "%s → %s" % (bin(_d25), bin(_d26)),
                      yzd(_d26 / _d25 - 1) if _d25 else "—",
                      yzd(_dc26 / _dc25 - 1) if _dc25 else "—",
                      yzd(_doa26 / _doa25 - 1) if _doa25 else "—",
                      yzd(_doc26 / _doc25 - 1) if _doc25 else "—", "—"])
    t = s.shapes.add_table(len(satir), 8, Inches(0.6), Inches(1.5), Inches(12.05), Inches(2.7)).table
    for i, gen in enumerate((2.15, 1.75, 2.35, 1.2, 1.15, 1.25, 1.15, 1.05)):
        t.columns[i].width = Inches(gen)
    t.rows[0].height = Inches(0.5)
    for r, row in enumerate(satir):
        for c, val in enumerate(row):
            cell = t.cell(r, c); cell.text = val
            for para in cell.text_frame.paragraphs:
                para.alignment = PP_ALIGN.LEFT if c <= 1 else PP_ALIGN.CENTER
                for run in para.runs:
                    run.font.size = Pt(11.5); run.font.name = "Calibri"
                    run.font.bold = (r == 0 or c in (3, 4, 5))
                    run.font.color.rgb = WHITE if r == 0 else (DRED if c in (3, 4) else INK)
            cell.fill.solid()
            cell.fill.fore_color.rgb = RED if r == 0 else (LGREY if r % 2 == 0 else WHITE)

    kats3 = [k["kategori"] for k in kat_veri]
    # tek seri: adet buyumesi (kadro Δ tabloda — ayni grafikte olcek farki cubuklari yok ediyordu)
    cd = CategoryChartData(); cd.categories = kats3
    cd.add_series("ürün adedi Δ%", tuple((k["adet26"] / k["adet25"] - 1) * 100 for k in kat_veri))
    ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(4.62),
                            Inches(7.4), Inches(1.42), cd).chart
    ch.has_title = False; ch.has_legend = False
    ch.font.size = Pt(9); ch.font.name = "Calibri"
    ch.plots[0].gap_width = 70; ch.plots[0].has_data_labels = True
    ch.plots[0].vary_by_categories = False
    ch.plots[0].data_labels.number_format_is_linked = False
    ch.plots[0].data_labels.number_format = '0"%"'
    ch.plots[0].data_labels.font.size = Pt(8.5)
    ch.series[0].format.fill.solid(); ch.series[0].format.fill.fore_color.rgb = RED
    tb(s, 0.6, 4.34, 7.4, 0.26, [("Ürün adedi büyümesi (%) — kategori bazında", 10, True, GREY)])

    rrect(s, 8.2, 4.42, 4.45, 1.62, LGREY, RED, lw=1.5)
    tb(s, 8.45, 4.5, 4.0, 1.48,
       [("Değerlendirme", 13.5, True, DRED),
        ("Kadro, satışı en hızlı artan kategorilere gitti. SEZON kolonları okul dönemini, "
         "OCA-AĞU kolonları yılın tamamını gösterir; sıralama ikisinde de aynı. DİĞER satırı, "
         "tek bir reyona bağlanamayan kategorilerin toplamı.", 10, False, INK)], sp=1.12)
    dipnot(s, C.DIP_POS + " · OCA-AĞU kolonları 1 Ocak – 31 Ağustos · Reyona bağlanabilen %d "
              "kategori ayrı satırda (satışın %s'i); kalan %d kategori DİĞER satırında."
              % (len(kat_veri), _kapsam_yzd, len(_dis)))


def slayt_takvim_kaymasi(C):
    """Takvim kaymasi: Agustos ve Eylul."""
    # ================================================================= TAKVIM KAYMASI
    ky = C.v.get("kayma")
    if ky:
        s = add("Yalnızca Başlık"); setph(s, 0, "Takvim Kayması: Ağustos ve Eylül")
        h = ky["hizali_buyume"]
        dg = ky["eylul_dalga_beklentisi"]
        ay_adet_d = ky["y26_agu_tam"]["adet"] / ky["y25_agu_tam"]["adet"] - 1

        kpi(s, 0.6, 1.5, 3.9, "AĞUSTOS · GERÇEK", yzd(ay_adet_d),
            "%s → %s adet" % (bin(ky["y25_agu_tam"]["adet"]), bin(ky["y26_agu_tam"]["adet"])),
            MGREY, 30, ikon="workflow")
        kpi(s, 4.68, 1.5, 3.9, "AĞUSTOS · KAYMASIZ", bin(ky["agustos_kaymasiz_tahmin"]["adet"]),
            "adet tahmini · %s M TL" % bin(ky["agustos_kaymasiz_tahmin"]["ciro"] / 1e6, 1), DRED, 26,
            ikon="rocket")
        kpi(s, 8.75, 1.5, 3.9, "EYLÜL'E KAYAN", bin(ky["eylule_kayan"]["adet"]),
            "adet · %s M TL" % bin(ky["eylule_kayan"]["ciro"] / 1e6, 1), DRED, 26, ikon="workflow")

        cd = CategoryChartData(); cd.categories = ["Ağustos (adet, bin)"]
        cd.add_series("2025 gerçekleşen", (ky["y25_agu_tam"]["adet"] / 1000,))
        cd.add_series("2026 gerçekleşen", (ky["y26_agu_tam"]["adet"] / 1000,))
        cd.add_series("2026 kayma olmasaydı", (ky["agustos_kaymasiz_tahmin"]["adet"] / 1000,))
        ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(3.5),
                                Inches(6.1), Inches(2.35), cd).chart
        ch.has_title = False
        ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.TOP; ch.legend.include_in_layout = False
        ch.font.size = Pt(9.5); ch.font.name = "Calibri"
        ch.plots[0].gap_width = 80; ch.plots[0].has_data_labels = True
        ch.plots[0].data_labels.number_format_is_linked = False
        ch.plots[0].data_labels.number_format = '#,##0'
        ch.plots[0].data_labels.font.size = Pt(9)
        for i, col in enumerate((MGREY, RED, RGBColor(0x7A, 0x10, 0x20))):
            ch.series[i].format.fill.solid(); ch.series[i].format.fill.fore_color.rgb = col

        rrect(s, 7.0, 3.6, 5.65, 2.15, LGREY, RED, lw=1.5)
        tb(s, 7.25, 3.72, 5.2, 1.95,
           [("Eylül'de beklenen dalga", 13.5, True, DRED),
            ("Geçen yıl okul öncesi alış dalgası %s arasındaydı: %s adet, %s milyon TL. Bu yıl aynı "
             "dalga %s arasına düşüyor. Aynı büyüme oranıyla %s adet, %s milyon TL bekliyoruz."
             % (dg["pencere_2025"], bin(dg["adet_2025"]), bin(dg["ciro_2025"] / 1e6, 1),
                dg["pencere_2026"], bin(dg["adet_2026_tahmin"]), bin(dg["ciro_2026_tahmin"] / 1e6, 1)),
             11, False, INK)], sp=1.15)

        dipnot(s, "* Kapsam: üç POS mağazası — %s · Hizalı pencere %s ile %s (%d gün; bugün hariç, son tam "
                  "gün %s) · Tahmin yöntemi: hizalı büyüme %s, talep kaybı olmadığı varsayımıyla."
               % (C.POS_ADLARI, h["pencere_2025"], h["pencere_2026"], h["gun"], h["son_tam_gun"],
                  yzd(h["adet"])))
        sig(s)
