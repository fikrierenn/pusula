# -*- coding: utf-8 -*-
"""Slaytlar: personel maliyeti / ciro orani + fazla mesai yasal siniri · sezonluk alim.

Maliyet = Zirve bordro (vw_PuanBil) Bt + Isskk + Iisk. Yasal cerceve 4857 s.K. m.41."""
# ⚠ Yildiz import BILINCLI: palet + cizim yardimcilarinin TAMAMI kullaniliyor ve
#   `bin`/`yzd` gibi bicim yardimcilari sunum_ortak'ta tanimli (tek kaynak).
from sunum_ortak import *          # noqa: F401,F403

def slayt_maliyet_ve_fazla_mesai(C):
    """Personel maliyeti/ciro orani + «kadro alinmasaydi» fazla mesai siniri."""
    # ================================================================= PERSONEL MALIYETI / CIRO
    mal = C.v.get("maliyet")
    fm = C.v.get("fazla_mesai")

    if mal and fm:
        mp25, mp26 = mal["pos"]["%d" % (ONCEKI % 100)], mal["pos"]["%d" % (CARI % 100)]
        puan = (mp26["maliyet_ciro_orani"] - mp25["maliyet_ciro_orani"]) * 100

        s = add("Yalnızca Başlık"); setph(s, 0, "Personel Maliyeti ve Ciro Oranı")
        kpi(s, 0.6, 1.5, 3.9, "PERSONEL MALİYETİ / CİRO",
            "%%%s → %%%s" % (("%.2f" % (mp25["maliyet_ciro_orani"] * 100)).replace(".", ","),
                             ("%.2f" % (mp26["maliyet_ciro_orani"] * 100)).replace(".", ",")),
            "%s puan %s" % (("%.2f" % abs(puan)).replace(".", ","),
                            "azaldı" if puan < 0 else "arttı"),
            DRED if puan > 0 else YESIL, 22, ikon="layers")
        kpi(s, 4.68, 1.5, 3.9, "KİŞİ-AY BAŞINA CİRO",
            yzd(mp26["kisi_ay_basi_ciro"] / mp25["kisi_ay_basi_ciro"] - 1),
            "%s → %s bin TL" % (bin(mp25["kisi_ay_basi_ciro"] / 1000),
                                bin(mp26["kisi_ay_basi_ciro"] / 1000)), YESIL, 30, ikon="package")
        kpi(s, 8.75, 1.5, 3.9, "KİŞİ-AY BAŞINA MALİYET",
            yzd(mp26["kisi_ay_basi_maliyet"] / mp25["kisi_ay_basi_maliyet"] - 1),
            "%s → %s bin TL (ücret artışı)" % (bin(mp25["kisi_ay_basi_maliyet"] / 1000),
                                               bin(mp26["kisi_ay_basi_maliyet"] / 1000)),
            MGREY, 30, ikon="users")

        satir = [["Ölçü", "%d" % ONCEKI, "%d" % CARI, "Değişim"],
                 ["Kişi-ay (bordro)", bin(mp25["kisi_ay"]), bin(mp26["kisi_ay"]),
                  yzd(mp26["kisi_ay"] / mp25["kisi_ay"] - 1)],
                 ["Brüt ücret", "%s M TL" % bin(mp25["brut"] / 1e6, 1),
                  "%s M TL" % bin(mp26["brut"] / 1e6, 1), yzd(mp26["brut"] / mp25["brut"] - 1)],
                 ["İşveren SGK + işsizlik payı",
                  "%s M TL" % bin((mp25["isveren_sgk"] + mp25["isveren_issizlik"]) / 1e6, 1),
                  "%s M TL" % bin((mp26["isveren_sgk"] + mp26["isveren_issizlik"]) / 1e6, 1),
                  yzd((mp26["isveren_sgk"] + mp26["isveren_issizlik"])
                      / (mp25["isveren_sgk"] + mp25["isveren_issizlik"]) - 1)],
                 ["PERSONEL MALİYETİ (brüt işveren)", "%s M TL" % bin(mp25["maliyet"] / 1e6, 1),
                  "%s M TL" % bin(mp26["maliyet"] / 1e6, 1), yzd(mp26["maliyet"] / mp25["maliyet"] - 1)],
                 ["Ciro (KDV hariç)", "%s M TL" % bin(mp25["ciro_kdvharic"] / 1e6, 1),
                  "%s M TL" % bin(mp26["ciro_kdvharic"] / 1e6, 1),
                  yzd(mp26["ciro_kdvharic"] / mp25["ciro_kdvharic"] - 1)]]
        t = s.shapes.add_table(len(satir), 4, Inches(0.6), Inches(3.75), Inches(7.9), Inches(1.9)).table
        for i, gen in enumerate((3.1, 1.6, 1.6, 1.6)):
            t.columns[i].width = Inches(gen)
        for r_ in t.rows:
            r_.height = Inches(0.24)
        for r, row in enumerate(satir):
            for c, val in enumerate(row):
                cell = t.cell(r, c); cell.text = val
                kalin = (r == 0 or "MALİYETİ" in satir[r][0])
                for para in cell.text_frame.paragraphs:
                    para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
                    for run in para.runs:
                        run.font.size = Pt(9.5 if r else 8.5); run.font.name = "Calibri"
                        run.font.bold = kalin or c == 3
                        run.font.color.rgb = WHITE if r == 0 else (DRED if c == 3 else INK)
                cell.fill.solid()
                cell.fill.fore_color.rgb = RED if r == 0 else (
                    LGREY if kalin else (WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA)))

        # ⚠ ondalik ayraci YALNIZ sayilarda degistirilir (cumleye replace uygulanirsa noktalar virgul olur)
        o25 = ("%.2f" % (mp25["maliyet_ciro_orani"] * 100)).replace(".", ",")
        o26 = ("%.2f" % (mp26["maliyet_ciro_orani"] * 100)).replace(".", ",")
        puan_s = ("%.2f" % abs(puan)).replace(".", ",")

        rrect(s, 8.7, 3.75, 3.95, 1.9, LGREY, RED, lw=1.5)
        tb(s, 8.95, 3.87, 3.5, 1.7,
           [("Maliyet arttı, yükü azaldı", 12.5, True, DRED),
            ("Personel maliyeti %s artmıştır; artışın ana kaynağı kişi başına ücret (%s). Buna karşın "
             "cironun içindeki personel yükü %s puan gerilemiştir: %%%s → %%%s."
             % (yzd(mp26["maliyet"] / mp25["maliyet"] - 1),
                yzd(mp26["kisi_ay_basi_maliyet"] / mp25["kisi_ay_basi_maliyet"] - 1),
                puan_s, o25, o26), 10, False, INK)], sp=1.12)

        dipnot(s, "* Kaynak: Zirve bordro (vw_PuanBil) — maliyet = brüt toplam + işveren SGK hissesi + "
                  "işveren işsizlik payı · Dönem: %s (Ağustos bordrosu henüz işlenmediği için son tam "
                  "bordro ayı esas) · Kapsam: üç POS mağazası · Ciro KDV HARİÇ ve Sınav DAHİL (o satışı "
                  "da aynı mağaza personeli yapar) · Kıdem karşılığı ve yan haklar hariç."
               % mal["pencere"])
        sig(s)

        # ============================================================= FAZLA MESAI / YASAL SINIR
        s = add("Yalnızca Başlık"); setph(s, 0, "Kadro Alınmasaydı: Fazla Mesai Sınırı")
        fi, kv = fm["fiili"], fm["kadro_artmasaydi"]
        kpi(s, 0.6, 1.5, 3.9, "FİİLİ FAZLA MESAİ · %d" % CARI,
            "%s sa/yıl" % bin(fi["kisi_basi_yillik26"]), "kişi başına · yasal sınır %d sa"
            % int(fm["yasal_yillik_sinir_saat"]), MGREY, 26, ikon="workflow")
        kpi(s, 4.68, 1.5, 3.9, "KADRO ARTMASAYDI", "%s sa/yıl" % bin(kv["kisi_basi_yillik_saat"]),
            "aynı iş, %d kişi-ay eksik kapasite" % kv["eksik_kisi_ay"], DRED, 26, ikon="alert-triangle")
        kpi(s, 8.75, 1.5, 3.9, "YASAL ÜST SINIR", "%d sa/yıl" % int(fm["yasal_yillik_sinir_saat"]),
            "4857 s.K. m.41 · kişi başına", DRED, 26, ikon="shield-check")

        cd = CategoryChartData(); cd.categories = ["Kişi başına yıllık fazla mesai (saat)"]
        cd.add_series("%d fiili" % ONCEKI, (fi["kisi_basi_yillik25"],))
        cd.add_series("%d fiili" % CARI, (fi["kisi_basi_yillik26"],))
        cd.add_series("Kadro artmasaydı", (kv["kisi_basi_yillik_saat"],))
        cd.add_series("Yasal sınır", (fm["yasal_yillik_sinir_saat"],))
        ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(3.7),
                                Inches(6.3), Inches(2.25), cd).chart
        ch.has_title = False
        ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.TOP
        ch.legend.include_in_layout = False
        ch.font.size = Pt(9.5); ch.font.name = "Calibri"
        ch.plots[0].gap_width = 80; ch.plots[0].has_data_labels = True
        ch.plots[0].data_labels.number_format_is_linked = False
        ch.plots[0].data_labels.number_format = '#,##0'
        ch.plots[0].data_labels.font.size = Pt(9)
        for i, col in enumerate((MGREY, RED, DRED, RGBColor(0x4A, 0x4A, 0x4A))):
            ch.series[i].format.fill.solid(); ch.series[i].format.fill.fore_color.rgb = col

        rrect(s, 7.1, 3.7, 5.55, 1.95, LGREY, RED, lw=1.5)
        tb(s, 7.35, 3.82, 5.05, 1.78,
           [("Alım tercih değil, zorunluluktu", 12.5, True, DRED),
            ("Kadro %d seviyesinde kalsaydı aynı işi çıkarmak için %s saat ek fazla mesai gerekirdi; "
             "kişi başına yıllık %s saate çıkardı ve %d saatlik yasal sınır AŞILIRDI. Fiili fazla mesai "
             "%s saat/yıl ile sınırın içindedir; ancak sınır hızında çalışan kişi-ay sayısı %d'den "
             "%d'ye yükselmiştir — kadro hâlâ dar."
             % (ONCEKI, bin(kv["ek_fm_saat"]), bin(kv["kisi_basi_yillik_saat"]),
                int(fm["yasal_yillik_sinir_saat"]), bin(fi["kisi_basi_yillik26"]),
                fi["sinir_hizinda_kisi_ay25"], fi["sinir_hizinda_kisi_ay26"]), 10, False, INK)],
           sp=1.12)

        dipnot(s, "* Kaynak: Zirve bordro fazla mesai saatleri (fm1+fm2+fm3) · Dönem: %s · Kapsam: üç "
                  "POS mağazası · VARSAYIM: işgücü ihtiyacı kişi sayısıyla doğru orantılıdır ve eksik "
                  "kapasite ancak fazla mesaiyle kapanır; kişi-ay başına normal çalışma %d saat "
                  "(45 sa/hafta) · Yasal çerçeve 4857 s.K. m.41 (yıllık %d saat)."
               % (mal["pencere"], int(fm["ay_normal_saat"]), int(fm["yasal_yillik_sinir_saat"])))
        sig(s)



def slayt_sezonluk_alim(C):
    """Sezonluk alim zamanlamasi («erken aldiniz» itirazinin testi)."""
    # ================================================================= SEZONLUK ALIM ZAMANLAMASI
    al = C.v.get("sezonluk_alim")
    ay2 = C.v.get("agustos_yarim")
    if al and ay2:
        s = add("Yalnızca Başlık"); setph(s, 0, "Sezonluk Alım Zamanlaması")
        a25, a26 = al[str(ONCEKI)], al[str(CARI)]
        gun_fark = a26["ort_yil_gunu"] - a25["ort_yil_gunu"]
        # K-10: asagidaki yorum kolonlari elle yazilmisti (+%25,1 / -%2,9 / "3 kisi") — turetilir.
        d_yarim1 = yzd(ay2["1"]["adet26"] / ay2["1"]["adet25"] - 1)
        d_yarim2 = yzd(ay2["2"]["adet26"] / ay2["2"]["adet25"] - 1)
        sez_kesim_fark = C.k5["sezonluk_kesim26"] - C.k5["sezonluk_kesim25"]

        kpi(s, 0.6, 1.5, 3.9, "ORTALAMA ALIM GÜNÜ",
            (("%.1f" % gun_fark).replace(".", ",") + " gün geç") if gun_fark > 0
            else (("%.1f" % abs(gun_fark)).replace(".", ",") + " gün erken"),
            "takvim ölçüsü · %d. → %d. gün" % (round(a25["ort_yil_gunu"]), round(a26["ort_yil_gunu"])),
            MGREY, 22, ikon="workflow")
        kpi(s, 4.68, 1.5, 3.9, "TEMMUZ VE ÖNCESİ ALIM", "%d → %d" % (a25["temmuz_ve_oncesi"], a26["temmuz_ve_oncesi"]),
            "gerçek erken alım azaldı", DRED, 30, ikon="users")
        kpi(s, 8.75, 1.5, 3.9, "1–14 AĞUSTOS İŞ HACMİ",
            yzd(ay2["1"]["adet26"] / ay2["1"]["adet25"] - 1),
            "%s → %s adet" % (bin(ay2["1"]["adet25"]), bin(ay2["1"]["adet26"])), DRED, 30, ikon="package")

        satir = [["Ölçü", "%d" % ONCEKI, "%d" % CARI, "Yorum"],
                 ["Ortalama alım günü (takvim)", "%d. gün" % round(a25["ort_yil_gunu"]),
                  "%d. gün" % round(a26["ort_yil_gunu"]),
                  "2026 alımı ortalama %s gün DAHA GEÇ" % ("%.1f" % gun_fark).replace(".", ",")],
                 ["Temmuz ve öncesi alınan", "%d kişi" % a25["temmuz_ve_oncesi"],
                  "%d kişi" % a26["temmuz_ve_oncesi"], "erken alım azaldı"],
                 ["Açılıştan 45+ gün önce alınan", "%d kişi" % a25["gun45_oncesi"],
                  "%d kişi" % a26["gun45_oncesi"], "çok erken alım azaldı"],
                 ["1–14 Ağustos alınan", "%d kişi" % a25["agustos_1_14"], "%d kişi" % a26["agustos_1_14"],
                  "artış bu iki haftada"],
                 ["1–14 Ağustos ürün adedi", bin(ay2["1"]["adet25"]), bin(ay2["1"]["adet26"]),
                  "iş %s büyüdü — alım işi takip etti" % yzd(ay2["1"]["adet26"] / ay2["1"]["adet25"] - 1)],
                 ["15–31 Ağustos ürün adedi", bin(ay2["2"]["adet25"]), bin(ay2["2"]["adet26"]),
                  "%s — dalga Eylül'e kaydı" % yzd(ay2["2"]["adet26"] / ay2["2"]["adet25"] - 1)],
                 ["31.08'de çalışan sezonluk", "%d kişi" % C.k5["sezonluk_kesim25"],
                  "%d kişi" % C.k5["sezonluk_kesim26"],
                  "kesimde %d kişi DAHA %s" % (abs(sez_kesim_fark),
                                               "AZ" if sez_kesim_fark < 0 else "FAZLA")],
                 ["   — Temmuz alımı", "%d kişi" % a25.get("aktif_donem", {}).get("2_temmuz", 0),
                  "%d kişi" % a26.get("aktif_donem", {}).get("2_temmuz", 0), "erken alım payı düştü"],
                 ["   — 1–14 Ağustos alımı", "%d kişi" % a25.get("aktif_donem", {}).get("3_agustos_1_14", 0),
                  "%d kişi" % a26.get("aktif_donem", {}).get("3_agustos_1_14", 0),
                  "iş %s büyüyen dönem" % d_yarim1],
                 ["   — 15–31 Ağustos alımı", "%d kişi" % a25.get("aktif_donem", {}).get("4_agustos_15_31", 0),
                  "%d kişi" % a26.get("aktif_donem", {}).get("4_agustos_15_31", 0),
                  "iş %s → alım azaltıldı" % d_yarim2],
                 ]  # NOT: "önceki yıldan devreden" satırı patron sunumuna KONULMADI — 2025 alımlı
                    #       tek kayıt hâlâ Kadro='SEZONLUK' görünüyor, veri düzeltmesi İK'da (02.09.2026).
        t = s.shapes.add_table(len(satir), 4, Inches(0.6), Inches(3.55), Inches(12.05), Inches(2.2)).table
        for i, gen in enumerate((3.6, 1.9, 1.9, 4.65)):
            t.columns[i].width = Inches(gen)
        for r_ in t.rows:
            r_.height = Inches(0.2)      # satir buyumesini sinirla (tablo dipnota/logoya binmesin)
        for r, row in enumerate(satir):
            for c, val in enumerate(row):
                cell = t.cell(r, c); cell.text = val
                for para in cell.text_frame.paragraphs:
                    para.alignment = PP_ALIGN.LEFT if c in (0, 3) else PP_ALIGN.CENTER
                    for run in para.runs:
                        run.font.size = Pt(8 if r == 0 else 9)
                        run.font.name = "Calibri"
                        run.font.bold = (r == 0 or c == 2)
                        run.font.color.rgb = WHITE if r == 0 else (DRED if c == 3 else INK)
                cell.fill.solid()
                cell.fill.fore_color.rgb = RED if r == 0 else (WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA))

        dipnot(s, "* İK'da düzeltme bekleyen 1 kayıt: 2025 girişli bir sezonluk personel çıkış tarihi "
                  "işlenmediği için 31.08'de aktif görünüyor; düzeltilince sezonluk 62 → 61 olur (rakamlar "
                  "İK'nın resmi kaydıyla birebir tutulsun diye şimdilik düzeltilmedi) · Kapsam: beş mağaza (%s) · Kohortlar okul açılışına göre AYNI ofsette kesildi "
                  "(T−12: 27.08.2025 ve 02.09.2026) · İş hacmi üç POS mağazası · ⚠ \"açılıştan kaç gün önce\" "
                  "ölçüsü açılış 6 gün kaydığı için 2026'yı mekanik olarak erken gösterir, takvim ölçüsü esastır."
               % C.BES_ADLARI)
        sig(s)
