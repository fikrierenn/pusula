# -*- coding: utf-8 -*-
"""Slaytlar: yontem/itirazlar · iyilestirme alani (tutunma) · kapanis."""
# ⚠ Yildiz import BILINCLI: palet + cizim yardimcilarinin TAMAMI kullaniliyor ve
#   `bin`/`yzd` gibi bicim yardimcilari sunum_ortak'ta tanimli (tek kaynak).
from sunum_ortak import *          # noqa: F401,F403

def _maliyet_itiraz(C):
    """Itiraz slaytindaki maliyet cevabi — rakamlar cekirdekten, ondalik ayraci sayilarda."""
    if not C.v.get("maliyet"):
        return "Bordro verisi bu üretimde yok."
    a_ = C.v["maliyet"]["pos"]["%d" % (ONCEKI % 100)]
    b_ = C.v["maliyet"]["pos"]["%d" % (CARI % 100)]
    pn = (b_["maliyet_ciro_orani"] - a_["maliyet_ciro_orani"]) * 100
    return ("Maliyet %s artmıştır; artışın ana kaynağı kişi başına ücret (%s), kadro artışı değil. "
            "Cironun içindeki personel yükü ise %s puan %s: %%%s → %%%s."
            % (yzd(b_["maliyet"] / a_["maliyet"] - 1),
               yzd(b_["kisi_ay_basi_maliyet"] / a_["kisi_ay_basi_maliyet"] - 1),
               ("%.2f" % abs(pn)).replace(".", ","),
               "GERİLEMİŞTİR" if pn < 0 else "YÜKSELMİŞTİR",
               ("%.2f" % (a_["maliyet_ciro_orani"] * 100)).replace(".", ","),
               ("%.2f" % (b_["maliyet_ciro_orani"] * 100)).replace(".", ",")))

def slayt_itirazlar(C):
    """Yontem ve aciklamalar — itirazlar + veriye dayali cevaplar."""
    # ================================================================= 13 ITIRAZLAR
    s = add("Yalnızca Başlık"); setph(s, 0, "Yöntem ve Açıklamalar")
    itiraz = [
        ("Büyüme kurumsal kanaldan mı geldi?",
         "Tersi: Sınav Okulları küçüldü. Ocak–Ağustos cirosu %s → %s milyon TL (%s). Mağaza tarafı %s büyüdü — "
         "büyümenin tamamı raftan geldi."
         % (bin(C.oa["sinav"]["kdvdahil25"] / 1e6, 1), bin(C.oa["sinav"]["kdvdahil26"] / 1e6, 1),
            yzd(C.d_sinav), yzd(C.d_mag_oa))),
        ("Ciro artışı enflasyon kaynaklı mı?",
         "Kısmen doğru: eşleşen ürünlerde fiyat endeksi +%%19,8. Bu yüzden savunma ciroya değil ADEDE "
         "dayanıyor: ürün adedi %s ve adet fiyattan etkilenmez." % yzd(C.d_adet)),
        ("Kasa sistemi değişti, karşılaştırma geçerli mi?",
         "Bu yüzden ölçüm POS'tan değil ERP'den (DerinSIS) alındı — iki yılda da aynı kaynak, aynı belge tipi. "
         "Temmuz 2025 kasa geçişi ölçüye girmiyor."),
        ("Sezonluk personel erken mi alındı?",
         "Hayır: takvim ölçüsünde %s alımı ortalama %s gün DAHA GEÇ; Temmuz ve öncesi alım %d kişiden "
         "%d'ye indi. Artış 1–14 Ağustos'ta ve o iki haftada ürün adedi %s büyüdü — alım işi takip etti."
         % (CARI, ("%.1f" % (C.al[str(CARI)]["ort_yil_gunu"] - C.al[str(ONCEKI)]["ort_yil_gunu"]))
            .replace(".", ","), C.al[str(ONCEKI)]["temmuz_ve_oncesi"], C.al[str(CARI)]["temmuz_ve_oncesi"],
            yzd(C.v["agustos_yarim"]["1"]["adet26"] / C.v["agustos_yarim"]["1"]["adet25"] - 1))),
        ("Personel maliyeti çok mu arttı?", _maliyet_itiraz(C)),
        ("Ağustos ayında ivme düşüşü var mı?",
         "Takvim etkisi: okullar 2025'te 8 Eylül, 2026'da 14 Eylül açıldı — sezon 6 gün geriye kaydı. "
         "Açılışa hizalanınca haftalık büyüme %65–79 bandında düz seyrediyor."),
    ]
    # kart yuksekligi kart SAYISINA gore otomatik: alt sinir y6.00 (dipnot/logo bandi serbest kalsin)
    ust, alt_sinir = 1.45, 6.00
    adim = (alt_sinir - ust) / len(itiraz)
    kh = adim - 0.10
    punto_bas = 12.5 if len(itiraz) <= 4 else 11.5
    punto_cev = 11 if len(itiraz) <= 4 else 9.5
    y = ust
    for i, (bas, cev) in enumerate(itiraz):
        card(s, 0.6, y, 12.05, kh, RED)
        s.shapes.add_picture(os.path.join(ICOR, "circle-check.png"), Inches(0.85), Inches(y + 0.14),
                             Inches(0.28), Inches(0.28))
        tb(s, 1.25, y + 0.07, 11.0, 0.32, [(bas, punto_bas, True, DRED)])
        tb(s, 1.25, y + 0.38, 11.0, kh - 0.42, [(cev, punto_cev, False, INK)], sp=1.06)
        y += adim
    dipnot(s, C.DIP_OCA_AGU + " (kurumsal/mağaza kıyası) · hizalı dönem: %s" % C.DONEM_POS)
    sig(s)


def slayt_iyilestirme(C):
    """Iyilestirme alani — kohort tutunma (canli olcum)."""
    # ================================================================= 14 DUZELTILECEK
    s = add("Yalnızca Başlık"); setph(s, 0, "İyileştirme Alanı")
    # ⚠ Rakamlar JSON'dan (canlı ölçüm) gelir — python-reviewer 02.09: önce hardcode yazılıydı,
    #   hiçbir sorgudan gelmiyordu ve denetçi de görmüyordu; sessizce bayatlayacak KPI'ydı.
    tt = C.v.get("tutunma", {})


    def _t(seg, yil):
        d_ = tt.get(seg, {}).get(str(yil), {})
        o = d_.get("oran14")
        return {"oran": ("%%%.1f" % (o * 100)).replace(".", ",") if o is not None else "—",
                "alinan": d_.get("alinan", 0), "ayrilan": d_.get("ayrilan", 0),
                "kalan": d_.get("kalan14", 0), "risk": d_.get("risk14", 0)}


    kad25, kad26 = _t("KADROLU", ONCEKI), _t("KADROLU", CARI)
    sez25, sez26 = _t("SEZONLUK", ONCEKI), _t("SEZONLUK", CARI)

    card(s, 0.6, 1.5, 5.9, 2.5, DRED, ikon="alert-triangle")
    tb(s, 0.85, 1.62, 5.0, 0.36, [("KADROLU ALIMDA KALMA ORANI", 10, True, GREY)])
    tb(s, 0.85, 2.02, 5.4, 0.86, [("%s → %s" % (kad25["oran"], kad26["oran"]), 30, True, DRED)])
    tb(s, 0.85, 2.92, 5.4, 0.95,
       [("İlk 14 günü tamamlama oranı (%d/%d → %d/%d). %d alımdan %d'si kesim tarihine kadar "
         "ayrılmıştır (önceki yıl %d alımdan %d). Aynı pozisyonun iki kez doldurulması maliyet "
         "yaratmaktadır." % (kad25["kalan"], kad25["risk"], kad26["kalan"], kad26["risk"],
                             kad26["alinan"], kad26["ayrilan"], kad25["alinan"], kad25["ayrilan"]),
         10.5, False, INK)], sp=1.1)

    card(s, 6.75, 1.5, 5.9, 2.5, MGREY, ikon="users")
    tb(s, 7.0, 1.62, 5.0, 0.36, [("SEZONLUK KADRODA KALMA ORANI", 10, True, GREY)])
    tb(s, 7.0, 2.02, 5.4, 0.86, [("%s → %s" % (sez25["oran"], sez26["oran"]), 30, True, MGREY)])
    tb(s, 7.0, 2.92, 5.4, 0.95,
       [("Sezonluk kadroda kalma oranı yükselmiştir (%d/%d → %d/%d). Sorun sezonluk alımda değil, "
         "kadrolu alımın ilk haftasındadır."
         % (sez25["kalan"], sez25["risk"], sez26["kalan"], sez26["risk"]), 10.5, False, INK)], sp=1.1)


    rrect(s, 0.6, 4.2, 12.05, 1.75, LGREY, RED, lw=1.5)
    tb(s, 0.9, 4.35, 11.5, 1.5,
       [("Planlanan Aksiyonlar", 13.5, True, DRED),
        ("• En bozuk üç nokta: Özlüce, Heykel, Merkez Depo → ilk hafta karşılama protokolü.\n"
         "• İdari İşler pozisyonunda ücret–vardiya revizyonu.\n"
         "• Ölçüt: gelecek sezon Eylül öncesi kayıp %20'den %12'ye (2025 seviyesi).", 12, False, INK)], sp=1.25)
    dipnot(s, C.DIP_BES + " Tutunma ölçümü mağaza kadrosu üzerinden yapılmıştır.")
    sig(s)


def slayt_kapanis(C):
    """Kapanis — ana mesajin tekrari."""
    # ================================================================= 15 KAPANIS
    s = add("Başlık Slaydı")
    setph(s, 0, "Sonuç")
    setph(s, 1, "Norma göre %+d kişi · kadrolu %s · ürün adedi %s · personel başına iş %s"
                % ((lambda nn: (nn["toplam"]["kadrolu_kesim26"]
                                - sum(a.get("engelli", 0) + a.get("etkinlik", 0)
                                      for a in nn.get("ayrik", {}).values())
                                + nn["toplam"]["sezonluk_kesim26"]) - nn["toplam"]["norm_toplam"])(C.v["norm"])
                   if C.v.get("norm") else 0,
                   ("−%d" % abs(C.sezon_ici_26)) if C.sezon_ici_26 < 0 else "+%d" % C.sezon_ici_26,
                   yzd(C.d_adet), yzd(C.d_kb)))
