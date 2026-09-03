# -*- coding: utf-8 -*-
"""Sunum BAGLAMI: cekirdek JSON'undan turetilmis oranlar + kapsam/donem dipnot metinleri.

`hesapla(v)` -> SimpleNamespace. Slayt fonksiyonlari bu nesneyi SALT-OKUR (`C.d_adet` gibi).
HESAP BURADA BITER: slayt modullerinde yeni metrik turetilmez (emitter-ayrimi kurali).
"""
import sys
from types import SimpleNamespace

from sunum_ortak import CARI, ONCEKI


def hesapla(v):
    """Turetilmis buyuklukler + dipnot metinleri; eksik cekirdek blogunda ANLASILIR hata."""
    mag = {m["ad"]: m for m in v["magaza"]}
    k5 = v["kadro_5magaza"]
    gun = v["meta"]["gun"]
    POS_SUBE = {"İST. YOLU": "İst. Yolu", "ÖZLÜCE": "Özlüce", "FSM": "FSM"}

    # K-19: toplamlar CEKIRDEKTE hesaplanir (emitter-ayrimi); burada yeniden SUM edilmez.
    if "toplam" not in v:
        sys.exit("VERİ ESKİ: JSON'da «toplam» bloğu yok. scripts/verimlilik_excel.py --cek ile yeniden üret.")
    tpl_ = v["toplam"]
    adet25, adet26 = tpl_["adet25"], tpl_["adet26"]
    kh25, kh26 = tpl_["kdvharic25"], tpl_["kdvharic26"]
    kd25, kd26 = tpl_["kdvdahil25"], tpl_["kdvdahil26"]
    kadro25, kadro26 = tpl_["kadro25"], tpl_["kadro26"]

    d_adet = adet26 / adet25 - 1
    d_ciro = kd26 / kd25 - 1
    d_kadro = kadro26 / kadro25 - 1
    kb25, kb26 = adet25 / kadro25, adet26 / kadro26
    d_kb = kb26 / kb25 - 1
    kat = d_adet / d_kadro
    taban_fark = k5["kadrolu_taban26"] - k5["kadrolu_taban25"]
    # K-15: bolum grafigi 31.08 KESIM deltalarini gosterir; altindaki cumle taban (30.06) farkini
    #   yaziyordu. Bugun ikisi de ayni ciktigi icin tutuyordu — olcuyu grafigin kaynagiyla esitle.
    kesim_fark = k5["kadrolu_kesim26"] - k5["kadrolu_kesim25"]
    sezon_ici_26 = k5["kadrolu_kesim26"] - k5["kadrolu_taban26"]
    sezon_ici_25 = k5["kadrolu_kesim25"] - k5["kadrolu_taban25"]
    oa = v["ocak_agustos"]
    d_sinav = oa["sinav"]["kdvdahil26"] / oa["sinav"]["kdvdahil25"] - 1
    d_mag_oa = oa["magaza"]["kdvdahil26"] / oa["magaza"]["kdvdahil25"] - 1

    bolum = sorted(v["bolum"], key=lambda b: b["kadrolu26"] - b["kadrolu25"], reverse=True)
    buyuyen = [b for b in bolum if b["kadrolu26"] - b["kadrolu25"] > 0]
    sabit = [b for b in bolum if b["kadrolu26"] - b["kadrolu25"] == 0
             and b["bolum"] in ("MAĞAZA", "MAL KABUL", "İDARİ İŞLER")]

    PT = v["meta"]["pencere_tarih"]
    DONEM_POS = ("%d: %s – %s · %d: %s – %s (her iki yıl %d gün, okul dönemine göre eşleşen "
                 "günler)" % (ONCEKI, PT[str(ONCEKI)][0][:5], PT[str(ONCEKI)][1],
                              CARI, PT[str(CARI)][0][:5], PT[str(CARI)][1], gun))
    DONEM_OCA_AGU = "1 Ocak – 31 Ağustos (her iki yıl)"
    POS_ADLARI = "FSM · Özlüce · İst. Yolu"
    BES_ADLARI = "FSM · Özlüce · İst. Yolu · Heykel · Şura"
    DIP_POS = ("* Mağazalar: %s (Heykel ve Şura'nın kasa verisi bu sistemde yok) · %s"
               % (POS_ADLARI, DONEM_POS))
    DIP_OCA_AGU = "* Mağazalar: %s · %s" % (POS_ADLARI, DONEM_OCA_AGU)
    DIP_BES = ("* Beş mağazanın tamamı: %s · Rakamlar 30 Haziran ve 31 Ağustos günü çalışan "
               "kişi sayısıdır." % BES_ADLARI)
    DIP_KARMA = ("* Kadro: beş mağaza (%s), 30 Haziran ve 31 Ağustos günü · Satış rakamları: "
                 "%s · %s" % (BES_ADLARI, POS_ADLARI, DONEM_POS))

    # cekirdek bloklarina kisayol (slaytlar arasinda paylasilir; yoksa None -> slayt atlanir)
    nrm = nrm0 = v.get("norm")
    mal = v.get("maliyet")
    fm = v.get("fazla_mesai")
    al = v.get("sezonluk_alim")
    ay2 = v.get("agustos_yarim")
    ky = v.get("kayma")

    yerel = dict(locals())
    yerel["v"] = v
    return SimpleNamespace(**yerel)
