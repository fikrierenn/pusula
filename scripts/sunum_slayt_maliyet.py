# -*- coding: utf-8 -*-
"""Slaytlar: personel maliyeti / ciro orani + fazla mesai yasal siniri · sezonluk alim.

Maliyet = Zirve bordro (vw_PuanBil) Bt + Isskk + Iisk. Yasal cerceve 4857 s.K. m.41."""
# ⚠ Yildiz import BILINCLI: palet + cizim yardimcilarinin TAMAMI kullaniliyor ve
#   `bin`/`yzd` gibi bicim yardimcilari sunum_ortak'ta tanimli (tek kaynak).
from sunum_ortak import *          # noqa: F401,F403

AY_ADLARI = {1: "Ocak", 2: "Şubat", 3: "Mart", 4: "Nisan", 5: "Mayıs", 6: "Haziran",
             7: "Temmuz", 8: "Ağustos", 9: "Eylül", 10: "Ekim", 11: "Kasım", 12: "Aralık"}

def slayt_maliyet_ve_fazla_mesai(C):
    """Personel maliyeti/ciro orani + «kadro alinmasaydi» fazla mesai siniri."""
    # ================================================================= PERSONEL MALIYETI / CIRO
    mal = C.v.get("maliyet")
    fm = C.v.get("fazla_mesai")

    if mal and fm:
        # ⚠ ESAS PENCERE SEZON (01.07-31.08): kadro sezonda artiyor, yil-geneli kumulatif pencere
        #   sezonu sulandirir (kullanici uyarisi 03.09.2026). Kumulatif referans olarak gosterilir.
        sz = mal["sezon"]
        mp25, mp26 = sz["pos"]["%d" % (ONCEKI % 100)], sz["pos"]["%d" % (CARI % 100)]
        ku25, ku26 = mal["pos"]["%d" % (ONCEKI % 100)], mal["pos"]["%d" % (CARI % 100)]
        puan = (mp26["maliyet_ciro_orani"] - mp25["maliyet_ciro_orani"]) * 100
        puan_ku = (ku26["maliyet_ciro_orani"] - ku25["maliyet_ciro_orani"]) * 100
        # KADROLU / SEZONLUK ayrimi (kullanici istegi 03.09)
        sg25k = sz["segment"]["KADROLU"]["%d" % (ONCEKI % 100)]
        sg26k = sz["segment"]["KADROLU"]["%d" % (CARI % 100)]
        sg25s = sz["segment"]["SEZONLUK"]["%d" % (ONCEKI % 100)]
        sg26s = sz["segment"]["SEZONLUK"]["%d" % (CARI % 100)]
        kk25 = mal["segment_kumulatif"]["KADROLU"]["%d" % (ONCEKI % 100)]
        kk26 = mal["segment_kumulatif"]["KADROLU"]["%d" % (CARI % 100)]
        ks25 = mal["segment_kumulatif"]["SEZONLUK"]["%d" % (ONCEKI % 100)]
        ks26 = mal["segment_kumulatif"]["SEZONLUK"]["%d" % (CARI % 100)]

        s = add("Yalnızca Başlık")
        setph(s, 0, "Personel Maliyeti ve Ciro Oranı — Sezonun Tamamlanan Kısmı (%s)"
              % sz["etiket"])
        kpi(s, 0.6, 1.5, 3.9, "PERSONEL MALİYETİ / CİRO",
            "%%%s → %%%s" % (("%.2f" % (mp25["maliyet_ciro_orani"] * 100)).replace(".", ","),
                             ("%.2f" % (mp26["maliyet_ciro_orani"] * 100)).replace(".", ",")),
            "%s puan %s" % (("%.2f" % abs(puan)).replace(".", ","),
                            "azaldı" if puan < 0 else "arttı"),
            DRED if puan > 0 else YESIL, 22, ikon="layers")
        kpi(s, 4.68, 1.5, 3.9, "FTE BAŞINA CİRO",
            yzd(mp26["fte_basi_ciro"] / mp25["fte_basi_ciro"] - 1),
            "%s → %s bin TL" % (bin(mp25["fte_basi_ciro"] / 1000),
                                bin(mp26["fte_basi_ciro"] / 1000)), YESIL, 30, ikon="package")
        kpi(s, 8.75, 1.5, 3.9, "FTE BAŞINA MALİYET",
            yzd(mp26["fte_basi_maliyet"] / mp25["fte_basi_maliyet"] - 1),
            "%s → %s bin TL (ücret artışı)" % (bin(mp25["fte_basi_maliyet"] / 1000),
                                               bin(mp26["fte_basi_maliyet"] / 1000)),
            MGREY, 30, ikon="users")

        satir = [["Ölçü", "SEZON %d" % ONCEKI, "SEZON %d" % CARI, "SEZON Δ", "Yıl geneli Δ"],
                 ["FTE (tam zaman eşdeğer)", bin(mp25["fte"], 1), bin(mp26["fte"], 1),
                  yzd(mp26["fte"] / mp25["fte"] - 1),
                  yzd(ku26["fte"] / ku25["fte"] - 1)],
                 ["  — kadrolu FTE", bin(sg25k["fte"], 1), bin(sg26k["fte"], 1),
                  yzd(sg26k["fte"] / sg25k["fte"] - 1) if sg25k["fte"] else "—",
                  yzd(kk26["fte"] / kk25["fte"] - 1) if kk25["fte"] else "—"],
                 ["  — sezonluk FTE", bin(sg25s["fte"], 1), bin(sg26s["fte"], 1),
                  yzd(sg26s["fte"] / sg25s["fte"] - 1) if sg25s["fte"] else "—",
                  yzd(ks26["fte"] / ks25["fte"] - 1) if ks25["fte"] else "—"],
                 ["  — bordro kaydı (bilgi)", bin(mp25["kisi_ay"]), bin(mp26["kisi_ay"]),
                  yzd(mp26["kisi_ay"] / mp25["kisi_ay"] - 1),
                  yzd(ku26["kisi_ay"] / ku25["kisi_ay"] - 1)],
                 ["Brüt ücret", "%s M TL" % bin(mp25["brut"] / 1e6, 1),
                  "%s M TL" % bin(mp26["brut"] / 1e6, 1), yzd(mp26["brut"] / mp25["brut"] - 1),
                  yzd(ku26["brut"] / ku25["brut"] - 1)],
                 ["İşveren SGK + işsizlik",
                  "%s M TL" % bin((mp25["isveren_sgk"] + mp25["isveren_issizlik"]) / 1e6, 1),
                  "%s M TL" % bin((mp26["isveren_sgk"] + mp26["isveren_issizlik"]) / 1e6, 1),
                  yzd((mp26["isveren_sgk"] + mp26["isveren_issizlik"])
                      / (mp25["isveren_sgk"] + mp25["isveren_issizlik"]) - 1),
                  yzd((ku26["isveren_sgk"] + ku26["isveren_issizlik"])
                      / (ku25["isveren_sgk"] + ku25["isveren_issizlik"]) - 1)],
                 ["PERSONEL MALİYETİ (brüt işveren)", "%s M TL" % bin(mp25["maliyet"] / 1e6, 1),
                  "%s M TL" % bin(mp26["maliyet"] / 1e6, 1),
                  yzd(mp26["maliyet"] / mp25["maliyet"] - 1),
                  yzd(ku26["maliyet"] / ku25["maliyet"] - 1)],
                 ["Ciro (KDV hariç)", "%s M TL" % bin(mp25["ciro_kdvharic"] / 1e6, 1),
                  "%s M TL" % bin(mp26["ciro_kdvharic"] / 1e6, 1),
                  yzd(mp26["ciro_kdvharic"] / mp25["ciro_kdvharic"] - 1),
                  yzd(ku26["ciro_kdvharic"] / ku25["ciro_kdvharic"] - 1)],
                 ["MALİYET / CİRO ORANI",
                  "%%%s" % ("%.2f" % (mp25["maliyet_ciro_orani"] * 100)).replace(".", ","),
                  "%%%s" % ("%.2f" % (mp26["maliyet_ciro_orani"] * 100)).replace(".", ","),
                  "%s puan" % ("%+.2f" % puan).replace(".", ","),
                  "%s puan" % ("%+.2f" % puan_ku).replace(".", ",")]]
        t = s.shapes.add_table(len(satir), 5, Inches(0.6), Inches(3.6), Inches(7.9),
                               Inches(2.05)).table
        for i, gen in enumerate((2.55, 1.35, 1.35, 1.3, 1.35)):
            t.columns[i].width = Inches(gen)
        for r_ in t.rows:
            r_.height = Inches(0.24)
        for r, row in enumerate(satir):
            for c, val in enumerate(row):
                cell = t.cell(r, c); cell.text = val
                kalin = (r == 0 or "MALİYETİ" in satir[r][0] or "ORANI" in satir[r][0])
                for para in cell.text_frame.paragraphs:
                    para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
                    for run in para.runs:
                        run.font.size = Pt(9.5 if r else 8.5); run.font.name = "Calibri"
                        run.font.bold = kalin or c == 3
                        run.font.color.rgb = WHITE if r == 0 else (
                            DRED if c == 3 else (MGREY if c == 4 else INK))
                cell.fill.solid()
                cell.fill.fore_color.rgb = RED if r == 0 else (
                    LGREY if kalin else (WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA)))

        # ⚠ ondalik ayraci YALNIZ sayilarda degistirilir (cumleye replace uygulanirsa noktalar virgul olur)
        o25 = ("%.2f" % (mp25["maliyet_ciro_orani"] * 100)).replace(".", ",")
        o26 = ("%.2f" % (mp26["maliyet_ciro_orani"] * 100)).replace(".", ",")
        puan_s = ("%.2f" % abs(puan)).replace(".", ",")

        rrect(s, 8.7, 3.6, 3.95, 2.05, LGREY, RED, lw=1.5)
        tb(s, 8.95, 3.72, 3.5, 1.9,
           [("Maliyet arttı, yükü azaldı", 12.5, True, DRED),
            ("Personel maliyeti %s artmıştır; artışın ana kaynağı FTE başına ücret (%s). Buna karşın "
             "cironun içindeki personel yükü %s puan gerilemiştir: %%%s → %%%s."
             % (yzd(mp26["maliyet"] / mp25["maliyet"] - 1),
                yzd(mp26["fte_basi_maliyet"] / mp25["fte_basi_maliyet"] - 1),
                puan_s, o25, o26), 9.5, False, INK),
            ("Sezon %s'dir; %d sezonu henüz tamamlanmadığı için kıyas %s ayı iledir. Yıl geneli "
             "(%s) oranı da %s puan gerilemiştir. Geçen yılın TAM sezonunda (%s) oran %%%s idi — "
             "sezonda ciro birkaç kat arttığı için oran doğal olarak çok düşüktür."
             % (sz["kural_etiket"], CARI, sz["etiket"], mal["pencere"],
                ("%+.2f" % puan_ku).replace(".", ","), sz["kural_etiket"],
                ("%.2f" % (sz["gecen_yil_tam"]["pos"]["maliyet_ciro_orani"] * 100))
                .replace(".", ",")), 8.5, False, MGREY)], sp=1.08)

        dipnot(s, "* Ölçü birimi FTE (tam zaman eşdeğer) = SGK prim günü ÷ 30 — ay içinde yarım "
                  "çalışan tam sayılmaz · Kaynak: Zirve bordro (vw_PuanBil) — maliyet = brüt toplam + işveren SGK "
                  "hissesi + işveren işsizlik payı · ESAS DÖNEM: %s · Yıl geneli referansı: %s · %s · "
                  "Kapsam: üç POS mağazası · Ciro KDV HARİÇ ve Sınav DAHİL (o satışı da aynı mağaza "
                  "personeli yapar) · Kıdem karşılığı ve yan haklar hariç → maliyet alt sınır · "
                  "KADROLU/SEZONLUK ayracı bugünkü Kadro alanıdır (tarihlenmiyor); sezonluk alımın "
                  "büyük kısmı Ağustos'ta olduğu için sezonluk ağırlığı Ağustos bordrosu işlenince "
                  "gerçek seviyesine çıkar."
               % (sz["etiket"], mal["pencere"],
                  sz.get("uyari", "Sezon penceresi tam (Temmuz + Ağustos)").replace("⚠ ", "")))
        sig(s)

        # ============================================================= FAZLA MESAI / YASAL SINIR
        s = add("Yalnızca Başlık")
        setph(s, 0, "Kadro Alınmasaydı: Fazla Mesai Sınırı — Sezon (%s)" % sz["etiket"])
        fi, kv = fm["fiili"], fm["kadro_artmasaydi"]
        kpi(s, 0.6, 1.5, 3.9, "FİİLİ · SEZON %d" % CARI,
            "%s sa/yıl" % bin(fi["kisi_basi_yillik26"]),
            "kişi başına (sezon hızı × 12) · yıl geneli %s sa"
            % bin(fm["kumulatif"]["kisi_basi_yillik26"]), MGREY, 26, ikon="workflow")
        kpi(s, 4.68, 1.5, 3.9, "KADRO ARTMASAYDI", "%s sa/yıl" % bin(kv["kisi_basi_yillik_saat"]),
            "aynı iş, %s FTE eksik kapasite" % bin(kv["eksik_fte"], 1), DRED, 26,
            ikon="alert-triangle")
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

        dipnot(s, "* Kaynak: Zirve bordro fazla mesai saatleri (fm1+fm2+fm3) · ESAS DÖNEM: %s "
                  "(sezon ayı) · yıl geneli referansı %s · Kapsam: üç POS mağazası · VARSAYIM: işgücü "
                  "ihtiyacı kişi sayısıyla doğru orantılıdır ve eksik kapasite ancak fazla mesaiyle "
                  "kapanır; kişi-ay başına normal çalışma %d saat (45 sa/hafta); yıllıklandırma = "
                  "sezon ayı hızı × 12 · Yasal çerçeve 4857 s.K. m.41 (yıllık %d saat)."
               % (sz["etiket"], mal["pencere"], int(fm["ay_normal_saat"]),
                  int(fm["yasal_yillik_sinir_saat"])))
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


def slayt_aylik_kadro_maliyet(C):
    """AYLIK kirilim: kadro (kisi-ay) ve maliyet/ciro orani hangi ayda olustu.

    Kullanici uyarisi 03.09.2026: "kadro artis analizi yaptiysan aylik yapman gerekirdi."
    Kumulatif tek rakam artisin ZAMANINI gizler; sezon aylari ayri isaretlenir.
    """
    mal = C.v.get("maliyet")
    if not mal or not mal.get("ay"):
        return
    ay = mal["ay"]
    sz = mal["sezon"]
    kats = [r["ad"] + ("*" if r["sezon_mu"] else "") for r in ay]
    ek25, ek26 = "%d" % (ONCEKI % 100), "%d" % (CARI % 100)

    s = add("Yalnızca Başlık")
    setph(s, 0, "Aylık Kadro ve Personel Maliyeti")

    # ⚠ son KIYAS MUMKUN ay (Ekim degil): bordrosu kosmamis aylarda CARI yil verisi yok
    kiyas_aylar = [r for r in ay if r.get("kiyas_mumkun", True)]
    son = kiyas_aylar[-1]
    kpi(s, 0.6, 1.5, 3.9, "SEZON AYI KADRO (FTE)",
        "%s → %s" % (bin(son["fte%s" % ek25], 1), bin(son["fte%s" % ek26], 1)),
        "%s · %s · bordro kaydı %d → %d" % (son["ad"],
                                            yzd(son["fte%s" % ek26] / son["fte%s" % ek25] - 1),
                                            son["kisi_ay%s" % ek25], son["kisi_ay%s" % ek26]),
        RED, 26, ikon="users")
    kpi(s, 4.68, 1.5, 3.9, "SEZON AYI MALİYET/CİRO",
        "%%%s → %%%s" % (("%.1f" % (son["oran%s" % ek25] * 100)).replace(".", ","),
                         ("%.1f" % (son["oran%s" % ek26] * 100)).replace(".", ",")),
        "%s ayı · %s puan" % (son["ad"],
                              ("%+.1f" % ((son["oran%s" % ek26] - son["oran%s" % ek25]) * 100))
                              .replace(".", ",")), YESIL, 24, ikon="layers")
    art = [r for r in kiyas_aylar if r["fte%s" % ek26] > r["fte%s" % ek25]]
    kpi(s, 8.75, 1.5, 3.9, "SEZON AYI · KADROLU / SEZONLUK",
        "%s / %s" % (bin(son["kadrolu_fte%s" % ek26], 1), bin(son["sezonluk_fte%s" % ek26], 1)),
        "FTE · kadro artışı %d/%d ayda" % (len(art), len(kiyas_aylar)), MGREY, 24, ikon="workflow")

    cd = CategoryChartData(); cd.categories = kats
    cd.add_series("%d kadrolu" % ONCEKI, tuple(round(r["kadrolu_fte%s" % ek25], 1) for r in ay))
    cd.add_series("%d sezonluk" % ONCEKI,
                  tuple(round(r["sezonluk_fte%s" % ek25], 1) for r in ay))
    cd.add_series("%d kadrolu" % CARI,
                  tuple(round(r["kadrolu_fte%s" % ek26], 1) if r.get("kiyas_mumkun", True) else None
                        for r in ay))
    cd.add_series("%d sezonluk" % CARI,
                  tuple(round(r["sezonluk_fte%s" % ek26], 1) if r.get("kiyas_mumkun", True) else None
                        for r in ay))
    ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(3.85),
                            Inches(6.0), Inches(2.15), cd).chart
    ch.has_title = False
    ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.TOP
    ch.legend.include_in_layout = False
    ch.font.size = Pt(9); ch.font.name = "Calibri"
    ch.plots[0].gap_width = 60; ch.plots[0].has_data_labels = True
    ch.plots[0].data_labels.number_format_is_linked = False
    ch.plots[0].data_labels.number_format = '#,##0.0'
    ch.plots[0].data_labels.font.size = Pt(8)
    for i, col in enumerate((MGREY, RGBColor(0x7A, 0x10, 0x20), RED, DRED)):
        ch.series[i].format.fill.solid(); ch.series[i].format.fill.fore_color.rgb = col
    tb(s, 0.6, 3.6, 6.0, 0.24,
       [("Kadro — aylık FTE: kadrolu + sezonluk, iki yıl (%d sezonu Ağu–Eki'de dolacak)" % CARI,
         9.5, True, GREY)])

    cd2 = CategoryChartData(); cd2.categories = kats
    cd2.add_series("%d" % ONCEKI, tuple((r["oran%s" % ek25] or 0) * 100 for r in ay))
    cd2.add_series("%d" % CARI, tuple(((r["oran%s" % ek26] or 0) * 100)
                                      if r.get("kiyas_mumkun", True) else None for r in ay))
    ch2 = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(6.75), Inches(3.85),
                             Inches(5.9), Inches(2.15), cd2).chart
    ch2.has_title = False
    ch2.has_legend = True; ch2.legend.position = XL_LEGEND_POSITION.TOP
    ch2.legend.include_in_layout = False
    ch2.font.size = Pt(9); ch2.font.name = "Calibri"
    ch2.plots[0].gap_width = 60; ch2.plots[0].has_data_labels = True
    ch2.plots[0].data_labels.number_format_is_linked = False
    ch2.plots[0].data_labels.number_format = '0.0"%"'
    ch2.plots[0].data_labels.font.size = Pt(8)
    for i, col in enumerate((MGREY, RED)):
        ch2.series[i].format.fill.solid(); ch2.series[i].format.fill.fore_color.rgb = col
    tb(s, 6.75, 3.6, 5.9, 0.24,
       [("Personel maliyetinin ciro içindeki payı (%) — aylık", 9.5, True, GREY)])

    dipnot(s, "* Sezon = %s (Temmuz hazırlık; asıl hacim ve sezonluk kadro Ağustos–Ekim) · "
              "%d sezonunun boş ayları bordrosu henüz koşmadığı için çizilmemiştir · "
              "Ölçü FTE = SGK prim günü ÷ 30 (bordro kaydı sayılsaydı ay içinde 1 gün çalışan "
              "da 1 sayılırdı) · Kaynak: Zirve bordro (vw_PuanBil) aylık · ciro DerinSIS KDV hariç, Sınav dahil · "
              "Kapsam: üç POS mağazası · * işaretli ay = sezon ayı (%s) · %s · "
              "Bordro kaydı ve ortalama prim günü Excel «Maliyet» sayfasında."
           % (sz["kural_etiket"], CARI, sz["kural_etiket"],
              (", ".join(AY_ADLARI.get(a_, str(a_)) for a_ in sz["eksik_aylar"])
               + " bordrosu işlendiğinde tabloya eklenir") if sz["eksik_aylar"]
              else "tüm sezon ayları işlenmiş"))
    sig(s)


def slayt_sezon_tahmini(C):
    """Sezonun kalani (Eyl-Eki) tahmini — okul-hizali gun esleme + FTE sekli/seviyesi.

    Kullanici istegi 03.09.2026. TAHMIN oldugu her yerde ETIKETLI; varsayimlar dipnotta.
    """
    th = C.v.get("tahmin")
    if not th or th.get("gerek_yok"):
        return
    t_ = th["sezon_toplam"]

    s = add("Yalnızca Başlık")
    setph(s, 0, "Sezonun Kalanı — Eylül–Ekim Tahmini")

    kpi(s, 0.6, 1.5, 3.9, "SEZON CİROSU (TAHMİN)",
        "%s M TL" % bin(t_["ciro"] / 1e6),
        "%d: %s M · %s" % (ONCEKI, bin(t_["ciro_gecen_yil"] / 1e6),
                           yzd(t_["ciro"] / t_["ciro_gecen_yil"] - 1)), DRED, 26, ikon="package")
    kpi(s, 4.68, 1.5, 3.9, "SEZON KADROSU (TAHMİN)",
        "%s FTE" % bin(t_["fte"], 1),
        "%d: %s FTE · %s" % (ONCEKI, bin(t_["fte_gecen_yil"], 1),
                             yzd(t_["fte"] / t_["fte_gecen_yil"] - 1)), MGREY, 26, ikon="users")
    kpi(s, 8.75, 1.5, 3.9, "SEZON MALİYET / CİRO",
        "%%%s" % ("%.2f" % (t_["maliyet_ciro_orani"] * 100)).replace(".", ","),
        "%d: %%%s · tahmini personel yükü"
        % (ONCEKI, ("%.2f" % (t_["maliyet_ciro_orani_gecen_yil"] * 100)).replace(".", ",")),
        YESIL, 26, ikon="layers")

    # ⚠ CIRO ve MALIYET tipi AYRI kolon: Agustos cirosu GERCEK (ay kapandi) ama bordrosu
    #   kosmadigi icin maliyeti TAHMIN. Tek "tip" kolonu bunu yanlis gosterirdi.
    satir = [["Ay", "Ciro", "Maliyet", "Ciro %d" % ONCEKI, "Ciro %d" % CARI, "Δ",
              "FTE %d" % CARI, "Maliyet %d" % CARI]]
    for r in th["ay"]:
        satir.append([r["ad"],
                      "gerçek" if r["ciro_tip"] == "gerçek" else r["ciro_tip"].upper(),
                      "gerçek" if r["maliyet_tip"] == "gerçek" else "TAHMİN",
                      "%s M" % bin(r["ciro_gecen_yil"] / 1e6, 1),
                      "%s M" % bin(r["ciro_toplam"] / 1e6, 1),
                      yzd(r["ciro_toplam"] / r["ciro_gecen_yil"] - 1) if r["ciro_gecen_yil"] else "—",
                      bin(r["fte"], 1),
                      "%s M" % bin(r["maliyet"] / 1e6, 1)])
    b_ = th["birlesik_agu_eyl"]
    satir.append(["Ağu+Eyl", "kayma", "nötr", "%s M" % bin(b_["ciro_gecen_yil"] / 1e6, 1),
                  "%s M" % bin(b_["ciro"] / 1e6, 1),
                  yzd(b_["ciro"] / b_["ciro_gecen_yil"] - 1) if b_["ciro_gecen_yil"] else "—",
                  bin(b_["fte"], 1), "%s M" % bin(b_["maliyet"] / 1e6, 1)])
    satir.append(["TOPLAM", "", "", "%s M" % bin(t_["ciro_gecen_yil"] / 1e6, 1),
                  "%s M" % bin(t_["ciro"] / 1e6, 1),
                  yzd(t_["ciro"] / t_["ciro_gecen_yil"] - 1),
                  bin(t_["fte"], 1), "%s M" % bin(t_["maliyet"] / 1e6, 1)])
    t = s.shapes.add_table(len(satir), 8, Inches(0.6), Inches(3.65), Inches(7.9),
                           Inches(1.75)).table
    for i, gen in enumerate((0.85, 0.85, 0.95, 1.15, 1.15, 0.85, 0.9, 1.2)):
        t.columns[i].width = Inches(gen)
    for r_ in t.rows:
        r_.height = Inches(0.22)
    for r, row in enumerate(satir):
        for c, val in enumerate(row):
            cell = t.cell(r, c); cell.text = val
            son_satir = (satir[r][0] in ("TOPLAM", "Ağu+Eyl"))
            tahmin_satir = any(x in ("TAHMİN", "KISMI", "TAHMIN") for x in satir[r][1:3])
            for para in cell.text_frame.paragraphs:
                para.alignment = PP_ALIGN.LEFT if c <= 1 else PP_ALIGN.CENTER
                for run in para.runs:
                    run.font.size = Pt(8.5 if r else 8)
                    run.font.name = "Calibri"
                    run.font.bold = (r == 0 or son_satir or (c in (1, 2) and tahmin_satir))
                    run.font.color.rgb = WHITE if r == 0 else (
                        DRED if (c in (1, 2) and tahmin_satir) else INK)
            cell.fill.solid()
            cell.fill.fore_color.rgb = RED if r == 0 else (
                LGREY if son_satir else (RGBColor(0xFF, 0xF6, 0xE6) if tahmin_satir else WHITE))

    cd = CategoryChartData(); cd.categories = [r["ad"] for r in th["ay"]]
    cd.add_series("%d gerçekleşen" % ONCEKI,
                  tuple(round(r["ciro_gecen_yil"] / 1e6, 1) for r in th["ay"]))
    cd.add_series("%d gerçekleşen" % CARI,
                  tuple(round(r["ciro_gerceklesen"] / 1e6, 1) for r in th["ay"]))
    cd.add_series("%d tahmin" % CARI,
                  tuple(round(r["ciro_tahmin"] / 1e6, 1) for r in th["ay"]))
    ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_STACKED, Inches(8.7), Inches(3.85),
                            Inches(3.95), Inches(2.1), cd).chart
    ch.has_title = False
    ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.TOP
    ch.legend.include_in_layout = False
    ch.font.size = Pt(8); ch.font.name = "Calibri"
    ch.plots[0].gap_width = 60
    for i, col in enumerate((MGREY, RED, RGBColor(0xE8, 0xA0, 0xA8))):
        ch.series[i].format.fill.solid(); ch.series[i].format.fill.fore_color.rgb = col
    tb(s, 8.7, 3.6, 3.95, 0.24, [("Ciro (M TL) — gerçekleşen + tahmin", 9, True, GREY)])

    tb(s, 0.6, 5.52, 7.9, 0.44, [(th["kayma_notu"].replace("⚠ ", ""), 8.5, False, DRED)],
       sp=1.05)

    dipnot(s, "* TAHMİN — %s tarihine kadar gerçek veri, sonrası model. Yöntem: %s · Büyüme "
              "oranı ayrıca varsayılmadı, okul-hizalı pencerede ÖLÇÜLEN %s ciro büyümesi "
              "uygulandı · Okul açılışı %s → %s (6 gün kayma gün eşlemesinde dikkate alındı) · "
              "Ücret seviyesi sabit varsayıldı → maliyet tahmini ALT SINIR · Kapsam: üç POS "
              "mağazası, ciro KDV hariç ve Sınav dahil."
           % (th["son_gercek_gun"], th["yontem"], yzd(th["buyume_orani_ciro"]),
              th["acilis"]["%d" % ONCEKI], th["acilis"]["%d" % CARI]))
    sig(s)
