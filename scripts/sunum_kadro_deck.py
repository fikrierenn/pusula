# -*- coding: utf-8 -*-
"""Sezon 2026 kadro savunmasi -> BKM Kitap kurumsal sunumu (.pptx) — CLI girisi.

Cekirdek veri: briefings/sezon-kadro-20260902/verimlilik-veri.json (canli DB'den uretilir —
scripts/verimlilik_excel.py --cek). Bu dosya EMITTER: hesap YAPMAZ, veriyi okur ve slayta doker.

Modul haritasi (plan-40 / K-23): sunum_ortak (palet + sablon + cizim) · sunum_baglam (turetilmis
buyuklukler) · sunum_slayt_* (tema bazli slaytlar). SLAYT SIRASI YALNIZ BURADA durur.

Marka: bkm-sunum skill sabitleri — sablon C:\\Users\\fikri.eren\\Desktop\\Sunum.pptx,
arka plan (kirmizi ikon-desenli bant + bkmkitap logosu) orijinal slaytlardan KOPYALANIR.
Palet yalniz kirmizi + gri (navy/teal/gokkusagi YASAK).

⚠ ICERIK KURALI: "1 Temmuz oncesi yonetim bende degildi" ifadesi YAZILMAZ. Yalniz TARIH CERCEVESI
kullanilir (taban 30.06 vs sezon 01.07-31.08) — rakam kendi hikayesini anlatir.
⚠ KVKK: kisi adi / personel no / ucret YOK; tum rakamlar toplulastirilmis.

Kullanim: python scripts/sunum_kadro_deck.py [cikti.pptx]
Varsayilan cikti: briefings/sezon-kadro-20260902/sunum-kadro-sezon2026.pptx
"""
import json
import sys
from pathlib import Path

import sunum_ortak
from sunum_baglam import hesapla
from sunum_slayt_hacim import (slayt_bolum_kirilimi, slayt_dort_yil, slayt_is_hacmi,
                               slayt_kategori, slayt_kisi_basi, slayt_magaza_performans,
                               slayt_takvim_kaymasi)
from sunum_slayt_kadro import (slayt_bes_magaza, slayt_kadro_akisi, slayt_kapak,
                               slayt_norma_gore_durum)
from sunum_slayt_kapanis import slayt_itirazlar, slayt_iyilestirme, slayt_kapanis
from sunum_slayt_maliyet import (slayt_aylik_kadro_maliyet, slayt_maliyet_ve_fazla_mesai,
                                slayt_sezon_tahmini, slayt_sezonluk_alim)
from sunum_slayt_norm import slayt_norm_acigi_bolum, slayt_norm_detay

KOK = Path(__file__).resolve().parent.parent
VERI = KOK / "briefings" / "sezon-kadro-20260902" / "verimlilik-veri.json"
TPL = r"C:\Users\fikri.eren\Desktop\Sunum.pptx"
OUT = sys.argv[1] if len(sys.argv) > 1 else str(
    KOK / "briefings" / "sezon-kadro-20260902" / "sunum-kadro-sezon2026.pptx")

# SLAYT SIRASI — destenin anlatim sirasi YALNIZ burada okunur
SIRA = [slayt_kapak, slayt_norma_gore_durum, slayt_kadro_akisi, slayt_bes_magaza,
        slayt_is_hacmi, slayt_kisi_basi, slayt_dort_yil, slayt_bolum_kirilimi,
        slayt_magaza_performans, slayt_kategori, slayt_takvim_kaymasi,
        slayt_norm_detay, slayt_norm_acigi_bolum,
        slayt_maliyet_ve_fazla_mesai, slayt_aylik_kadro_maliyet, slayt_sezon_tahmini,
        slayt_sezonluk_alim,
        slayt_itirazlar, slayt_iyilestirme, slayt_kapanis]


def main():
    pr = sunum_ortak.ac(TPL)
    C = hesapla(json.loads(VERI.read_text(encoding="utf-8")))
    for slayt in SIRA:
        slayt(C)
    try:
        pr.save(OUT)
    except PermissionError:
        sys.exit("Dosya açık görünüyor, kaydedilemedi. PowerPoint'te kapatıp tekrar çalıştır: %s"
                 % OUT)
    print("Yazildi: %s (%d slayt)" % (OUT, len(pr.slides._sldIdLst)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
