# -*- coding: utf-8 -*-
"""SEZONUN KALANI (Eylul-Ekim) TAHMINI — kullanici istegi 03.09.2026.

2026 sezonu (Tem-Eki) henuz tamamlanmadi: ciro 02.09'a kadar var, bordro Temmuz'a kadar
kosmus. Sezonun kalani UC ayri modelle tahmin edilir ve HER BIRI ETIKETLENIR:

  1) CIRO — gun bazli OKUL-HIZALI model. 2025'in gunluk cirosu okul acilisina gore
     ofsetlenir (acilis 08.09.2025 -> 14.09.2026, 6 gun kayma), 2026 takvimine tasinir ve
     hizali pencerede OLCULEN buyume orani (g_ciro) uygulanir. 2026'nin GERCEKLESEN gunleri
     tahminle DEGISTIRILMEZ.
  2) FTE — sezon SEKLI 2025'ten, SEVIYE 2026'dan: FTE(2026, ay) = FTE(2026, taban ay) x
     [FTE(2025, ay) / FTE(2025, taban ay)]. Taban ay = son tam bordro ayi (Temmuz).
  3) MALIYET — tahmini FTE x 2026'nin FTE BASINA maliyeti (taban aydan; ucret seviyesi sabit
     varsayimi -> asgari ucret/zam olursa ALT SINIR).

VARSAYIMLAR (cikti dosyalarinda aynen yazilir):
  * sezon sekli yil-uzeri ayni (talep dagilimi degismedi)
  * okul acilisi disinda takvim etkisi yok (bayram/tatil kaymasi modellenmedi)
  * ucret seviyesi taban aydan sonra degismiyor -> maliyet tahmini ALT SINIR
  * kadro kompozisyonu (kadrolu/sezonluk) 2025 seklini izler
"""
import datetime as _dt
import sys

from verimlilik_ortak import AY_AD_KISA, CARI, OKUL_ACILIS, ONCEKI, SEZON_AYLAR


def _tarih(s):
    return _dt.date(int(s[:4]), int(s[4:6]), int(s[6:8]))


def _dmy(s):
    """ISO 'YYYYMMDD' -> yerel 'dd.MM.yyyy' (proje tarih kurali)."""
    return _tarih(s).strftime("%d.%m.%Y")


def cek_tahmin(veri, gunluk, ciro_ay):
    """Sezonun kalani icin ciro + FTE + maliyet tahmini. veri['maliyet'] DOLU olmali."""
    mal = veri.get("maliyet")
    kayma = veri.get("kayma") or {}
    if not mal or not mal.get("ay"):
        return
    sz = mal["sezon"]
    if sz.get("tam_mi"):
        veri["tahmin"] = {"gerek_yok": True,
                          "not": "Sezon tamamlandi — tahmine gerek yok, gercek rakamlar kullanilir."}
        return

    g_ciro = (kayma.get("hizali_buyume") or {}).get("ciro")
    if g_ciro is None:
        sys.exit("TAHMİN İÇİN BÜYÜME ORANI YOK: kayma.hizali_buyume.ciro üretilmemiş.")
    # son tam gun: kayma blogundaki "dd.mm.yyyy" metninden ayristirilir
    stg = (kayma.get("hizali_buyume") or {}).get("son_tam_gun")
    if not stg:
        sys.exit("TAHMİN İÇİN SON TAM GÜN YOK (kayma.hizali_buyume.son_tam_gun).")
    d_, m_, y_ = (int(x) for x in stg.split("."))
    son_tam = _dt.date(y_, m_, d_)

    acilis25 = _tarih(OKUL_ACILIS[ONCEKI])
    acilis26 = _tarih(OKUL_ACILIS[CARI])

    # ---- 1) CIRO: gerceklesen + hizali tahmin
    ciro_tahmin = {}          # ay -> {"gerceklesen":x, "tahmin":y, "toplam":z, "tahmin_gun":n}
    for ay_ in SEZON_AYLAR:
        ilk = _dt.date(CARI, ay_, 1)
        son = (_dt.date(CARI + (ay_ == 12), (ay_ % 12) + 1, 1) - _dt.timedelta(days=1))
        gercek, tahmin, tg = 0.0, 0.0, 0
        gun = ilk
        while gun <= son:
            if gun <= son_tam:
                gercek += gunluk.get((CARI, gun.isoformat()), 0.0)
            else:
                esles = acilis25 + (gun - acilis26)      # okul-hizali karsilik
                tahmin += gunluk.get((ONCEKI, esles.isoformat()), 0.0) * (1 + g_ciro)
                tg += 1
            gun += _dt.timedelta(days=1)
        ciro_tahmin[ay_] = {"gerceklesen": gercek, "tahmin": tahmin, "toplam": gercek + tahmin,
                            "tahmin_gun": tg,
                            # ⚠ CIRO tipi ile FTE/MALIYET tipi AYRIDIR: Agustos cirosu GERCEK
                            #   (ay kapandi) ama bordrosu kosmadigi icin maliyeti TAHMIN.
                            "tip": ("gerçek" if tg == 0 else
                                    ("tahmin" if gercek == 0 else "kısmi")),
                            "gecen_yil": ciro_ay.get((ONCEKI, ay_), (0.0, 0.0))[0]}

    # ---- 2) FTE: sezon sekli 2025'ten, seviye 2026'dan (taban = son tam bordro ayi)
    taban_ay = mal["pencere_ay"]
    ay_ind = {r["ay"]: r for r in mal["ay"]}
    ek25, ek26 = "%d" % (ONCEKI % 100), "%d" % (CARI % 100)
    taban25 = ay_ind[taban_ay]["fte" + ek25]
    taban26 = ay_ind[taban_ay]["fte" + ek26]
    if taban25 <= 0:
        sys.exit("TAHMİN TABANI BOŞ: %d yılında %s ayı FTE'si 0." % (ONCEKI, AY_AD_KISA[taban_ay]))
    seviye = taban26 / taban25

    fte_tahmin = {}
    for ay_ in SEZON_AYLAR:
        r = ay_ind.get(ay_)
        if not r:
            continue
        if r.get("kiyas_mumkun"):
            fte_tahmin[ay_] = {"deger": r["fte" + ek26], "tip": "gerçek",
                               "kadrolu": r["kadrolu_fte" + ek26],
                               "sezonluk": r["sezonluk_fte" + ek26],
                               "gecen_yil": r["fte" + ek25]}
        else:
            fte_tahmin[ay_] = {"deger": r["fte" + ek25] * seviye, "tip": "tahmin",
                               "kadrolu": r["kadrolu_fte" + ek25] * seviye,
                               "sezonluk": r["sezonluk_fte" + ek25] * seviye,
                               "gecen_yil": r["fte" + ek25]}

    # ---- 3) MALIYET: FTE x taban ayin FTE basina maliyeti
    fte_basi = 0.0
    taban_satir = ay_ind[taban_ay]
    if taban_satir["fte" + ek26]:
        fte_basi = taban_satir["maliyet" + ek26] / taban_satir["fte" + ek26]
    mal_tahmin = {ay_: {"deger": (ay_ind[ay_]["maliyet" + ek26]
                                  if ay_ind[ay_].get("kiyas_mumkun")
                                  else fte_tahmin[ay_]["deger"] * fte_basi),
                        "tip": "gerçek" if ay_ind[ay_].get("kiyas_mumkun") else "tahmin",
                        "gecen_yil": ay_ind[ay_]["maliyet" + ek25]}
                  for ay_ in SEZON_AYLAR if ay_ in ay_ind}

    sezon_ciro = sum(d["toplam"] for d in ciro_tahmin.values())
    sezon_ciro25 = sum(d["gecen_yil"] for d in ciro_tahmin.values())
    sezon_mal = sum(d["deger"] for d in mal_tahmin.values())
    sezon_mal25 = sum(d["gecen_yil"] for d in mal_tahmin.values())
    sezon_fte = sum(d["deger"] for d in fte_tahmin.values())
    sezon_fte25 = sum(d["gecen_yil"] for d in fte_tahmin.values())

    veri["tahmin"] = {
        "yontem": "okul-hizalı gün eşleme (ciro) + sezon şekli×seviye (FTE) + FTE başına maliyet",
        "son_gercek_gun": son_tam.strftime("%d.%m.%Y"),
        "taban_ay": taban_ay,
        "taban_ay_ad": AY_AD_KISA[taban_ay],
        "buyume_orani_ciro": g_ciro,
        "fte_seviye_katsayisi": seviye,
        "fte_basi_maliyet_taban": fte_basi,
        "acilis": {"%d" % ONCEKI: _dmy(OKUL_ACILIS[ONCEKI]),
                   "%d" % CARI: _dmy(OKUL_ACILIS[CARI])},
        "ay": [{"ay": ay_, "ad": AY_AD_KISA[ay_],
                "ciro_gerceklesen": ciro_tahmin[ay_]["gerceklesen"],
                "ciro_tahmin": ciro_tahmin[ay_]["tahmin"],
                "ciro_toplam": ciro_tahmin[ay_]["toplam"],
                "ciro_tahmin_gun": ciro_tahmin[ay_]["tahmin_gun"],
                "ciro_gecen_yil": ciro_tahmin[ay_]["gecen_yil"],
                "ciro_tip": ciro_tahmin[ay_]["tip"],
                "fte": fte_tahmin[ay_]["deger"], "fte_tip": fte_tahmin[ay_]["tip"],
                "fte_kadrolu": fte_tahmin[ay_]["kadrolu"],
                "fte_sezonluk": fte_tahmin[ay_]["sezonluk"],
                "fte_gecen_yil": fte_tahmin[ay_]["gecen_yil"],
                "maliyet": mal_tahmin[ay_]["deger"], "maliyet_tip": mal_tahmin[ay_]["tip"],
                "maliyet_gecen_yil": mal_tahmin[ay_]["gecen_yil"]}
               for ay_ in SEZON_AYLAR if ay_ in fte_tahmin],
        "sezon_toplam": {
            "ciro": sezon_ciro, "ciro_gecen_yil": sezon_ciro25,
            "maliyet": sezon_mal, "maliyet_gecen_yil": sezon_mal25,
            "fte": sezon_fte, "fte_gecen_yil": sezon_fte25,
            "maliyet_ciro_orani": (sezon_mal / sezon_ciro) if sezon_ciro else None,
            "maliyet_ciro_orani_gecen_yil": (sezon_mal25 / sezon_ciro25) if sezon_ciro25 else None,
            "fte_basi_ciro": (sezon_ciro / sezon_fte) if sezon_fte else None,
            "fte_basi_ciro_gecen_yil": (sezon_ciro25 / sezon_fte25) if sezon_fte25 else None},
        "kayma_notu": (
            "⚠ TAKVİM AYI KIYASI KAYMAYI YANSITIR: okul %s'de değil %s'te açıldı — %d'te Ağustos "
            "sonunda gerçekleşen yoğunluk %d'da Eylül başına düştü. Bu yüzden Ağustos %s, Eylül "
            "%s görünür; ay ay okumak yanıltır, SEZON TOPLAMI (veya Ağustos+Eylül birlikte) esas "
            "alınır."
            % (_dmy(OKUL_ACILIS[ONCEKI]), _dmy(OKUL_ACILIS[CARI]), ONCEKI, CARI,
               ("%+.0f%%" % ((ciro_tahmin[8]["toplam"] / ciro_tahmin[8]["gecen_yil"] - 1) * 100))
               if ciro_tahmin.get(8, {}).get("gecen_yil") else "—",
               ("%+.0f%%" % ((ciro_tahmin[9]["toplam"] / ciro_tahmin[9]["gecen_yil"] - 1) * 100))
               if ciro_tahmin.get(9, {}).get("gecen_yil") else "—")),
        "birlesik_agu_eyl": {
            "ciro": sum(ciro_tahmin[a_]["toplam"] for a_ in (8, 9) if a_ in ciro_tahmin),
            "ciro_gecen_yil": sum(ciro_tahmin[a_]["gecen_yil"] for a_ in (8, 9)
                                  if a_ in ciro_tahmin),
            "fte": sum(fte_tahmin[a_]["deger"] for a_ in (8, 9) if a_ in fte_tahmin),
            "fte_gecen_yil": sum(fte_tahmin[a_]["gecen_yil"] for a_ in (8, 9) if a_ in fte_tahmin),
            "maliyet": sum(mal_tahmin[a_]["deger"] for a_ in (8, 9) if a_ in mal_tahmin)},
        "varsayimlar": [
            "Sezon şekli yıl üzerinden aynı: %d'in gün-bazlı satış dağılımı okul açılışına "
            "hizalanarak %d takvimine taşındı (açılış %s → %s)."
            % (ONCEKI, CARI, _dmy(OKUL_ACILIS[ONCEKI]), _dmy(OKUL_ACILIS[CARI])),
            "Seviye: hizalı pencerede ÖLÇÜLEN ciro büyümesi (%%%.1f) uygulandı — ayrı bir "
            "büyüme varsayımı yapılmadı." % (g_ciro * 100),
            "FTE: sezon şekli 2025'ten, seviye 2026'nın %s ayından (katsayı %.3f)."
            % (AY_AD_KISA[taban_ay], seviye),
            "Maliyet: tahmini FTE × 2026 %s ayının FTE başına maliyeti (%s ₺). Ücret seviyesi "
            "sabit varsayıldı → zam/asgari ücret artışı olursa maliyet tahmini ALT SINIRDIR."
            % (AY_AD_KISA[taban_ay], format(int(fte_basi), ",").replace(",", ".")),
            "Gerçekleşen günler tahminle değiştirilmedi: %s tarihine kadar gerçek veri, "
            "sonrası tahmindir." % son_tam.strftime("%d.%m.%Y"),
            "Bayram/tatil kayması ve mağaza açılış-kapanışı modellenmedi.",
        ]}
