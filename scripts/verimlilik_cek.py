# -*- coding: utf-8 -*-
"""Veri cekirdegi ORKESTRASYONU — tek dogruluk kaynagi (emitter'lar bunu okur).

Blok modulleri: cek_hacim (DerinSIS) · cek_kadro/cek_tutunma/mutabakat + cek_norm + cek_maliyet
(Zirve). Bu dosya yalnizca siralama, toplamlar ve meta yazar; SORGU ICERMEZ.
"""
from verimlilik_cek_hacim import cek_hacim
from verimlilik_cek_tahmin import cek_tahmin
from verimlilik_cek_kadro import cek_kadro, cek_tutunma, mutabakat
from verimlilik_cek_maliyet import cek_maliyet
from verimlilik_cek_norm import cek_norm
from verimlilik_ortak import (CARI, NOTLAR, OFSET_BAS, OFSET_SON, OKUL_ACILIS, ONCEKI,
                              _cn, _kapat)


def cek(env, kisi=False):
    """Tum rakamlari canli ceker. Elle girilen sayi YOK."""
    veri = {"meta": {}, "magaza": [], "yillar": [], "notlar": NOTLAR}

    erp = _cn(env, "erp")
    hacim, yil_adet, ciro_ay, gunluk = cek_hacim(erp.cursor(), veri)
    _kapat(erp)

    zrv = _cn(env, "zirve")
    zc = zrv.cursor()
    print("Zirve: kadro as-of sayımları...", flush=True)
    cek_kadro(zc, veri, hacim, yil_adet, kisi=kisi)
    cek_norm(zc, veri)
    cek_tutunma(zc, veri)
    cek_maliyet(zc, veri, ciro_ay)
    cek_tahmin(veri, gunluk, ciro_ay)     # sezonun kalani (Eyl-Eki) tahmini
    mutabakat(veri)
    _kapat(zrv)

    # K-19: emitter'lar (Excel + sunum) toplamlari AYRI AYRI SUM ediyordu (emitter-ayrimi
    #   kurali: hesap cekirdekte). Tek kaynak burada.
    veri["toplam"] = {}
    for alan in ("adet", "kdvharic", "kdvdahil", "kadro"):
        for yil in (ONCEKI, CARI):
            ek = yil % 100
            veri["toplam"]["%s%d" % (alan, ek)] = sum(m["%s%d" % (alan, ek)] for m in veri["magaza"])

    veri["meta"].update({
        "baslik": "Kişi başı iş hacmi — sezon %d vs %d" % (CARI, ONCEKI),
        "kesim": "otomatik (veri sonu, okul-hizalı pencerede)",
        "cekirdek_sql": "sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql (blok 11)",
        "kadro_kaynak": "Zirve BKM_GENEL.dbo.vw_PersonelDepartman — as-of Igt <= T AND (Ict IS NULL OR Ict >= T), "
                        "sp_PersonelKarsilastirma_Ozet ile birebir",
        "hacim_kaynak": "DerinSIS irs/irsAyr eTip=100 (POS satışı), Sınav Okulları/Kıyafet hariç, iade netlenmiş",
        "pencere": "Okul açılışına hizalı — %s: %s – %s · %s: %s – %s (her iki yıl %d gün; açılış %s ve %s, "
                   "gün ofseti %d..%d)"
                   % (ONCEKI, veri["meta"]["pencere_tarih"][str(ONCEKI)][0],
                      veri["meta"]["pencere_tarih"][str(ONCEKI)][1],
                      CARI, veri["meta"]["pencere_tarih"][str(CARI)][0],
                      veri["meta"]["pencere_tarih"][str(CARI)][1],
                      veri["meta"]["gun"], OKUL_ACILIS[ONCEKI], OKUL_ACILIS[CARI],
                      OFSET_BAS, OFSET_SON),
    })
    return veri
