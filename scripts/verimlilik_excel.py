# -*- coding: utf-8 -*-
"""Kisi basi is hacmi + kadro/norm/maliyet savunmasi -> Excel (CLI girisi).

VERIYI KENDI CEKER (elle rakam YOK):
  hacim  -> DerinSIS irs/irsAyr eTip=100, Sinav haric (cekirdek: sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql blok 11)
  kadro  -> Zirve BKM_GENEL.dbo.vw_PersonelDepartman, as-of Igt<=T AND (Ict IS NULL OR Ict>=T)
  maliyet-> Zirve BKM_GENEL.dbo.vw_PuanBil (bordro), Bt+Isskk+Iisk
Pencere OKUL ACILISINA HIZALI: gun ofseti -69..-14 (her iki yil 56 gun). Takvim-tarihli kiyas yaniltir.
Oranlarin hepsi Excel FORMULU olarak yazilir (patron ham rakamdan dogrulayabilsin).

Modul haritasi (plan-39 / K-20): verimlilik_ortak (sabit+baglanti) · verimlilik_cek*
(veri cekirdegi) · verimlilik_xlsx* (emitter). Bu dosya yalniz CLI.

Sayfalar: Sunum (patrona) · Ozet · Magaza · Kadro · Bolum · Kategori · Aylik · Yillar · Oca-Agu ·
Norm · Maliyet · Yontem [+ Personel: --kisi]
Kullanim:
  python scripts/verimlilik_excel.py --cek <veri.json> <cikti.xlsx>   # DB'den ceker, ikisini de yazar
  python scripts/verimlilik_excel.py <veri.json> <cikti.xlsx>         # mevcut json'dan sadece Excel
  python scripts/verimlilik_excel.py --cek --kisi <veri.json> <KISILI.xlsx>   # + personel listesi (KVKK: gitignore'da)
"""
import json
import sys
from pathlib import Path

from openpyxl import Workbook

from verimlilik_cek import cek
from verimlilik_ortak import _env, kapat_baglantilar
from verimlilik_xlsx_hacim import (sayfa_aylik, sayfa_kategori, sayfa_magaza, sayfa_oca_agu,
                                   sayfa_yillar)
from verimlilik_xlsx_kadro import (sayfa_bolum, sayfa_kadro, sayfa_maliyet, sayfa_norm,
                                   sayfa_personel, sayfa_yontem)
from verimlilik_xlsx_ozet import sayfa_ozet, sayfa_sunum

def main(argv):
    cek_mod = "--cek" in argv
    kisi_mod = "--kisi" in argv
    args = [a for a in argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        print(__doc__)
        return 2
    veri_yolu, cikti = Path(args[0]), Path(args[1])

    if cek_mod:
        try:
            veri = cek(_env(), kisi=kisi_mod)
        finally:
            kapat_baglantilar()   # K-17: mutabakat sys.exit'inde bile baglantilar kapanir
        veri_yolu.parent.mkdir(parents=True, exist_ok=True)
        # KVKK: kisi-duzeyi satirlar PAYLASILAN json'a YAZILMAZ (o dosya git'te izleniyor).
        # Ayri *KISILI*.json dosyasina gider; gitignore o deseni yakalar.
        paylasilan = {k: val for k, val in veri.items() if k != "personel"}
        veri_yolu.write_text(json.dumps(paylasilan, ensure_ascii=False, indent=2), encoding="utf-8")
        print("Veri yazıldı: %s (toplulaştırılmış)" % veri_yolu, flush=True)
        if veri.get("personel"):
            kisi_yolu = veri_yolu.with_name(veri_yolu.stem + "-KISILI.json")
            kisi_yolu.write_text(json.dumps({"personel": veri["personel"]}, ensure_ascii=False, indent=2),
                                 encoding="utf-8")
            print("Kişi listesi ayrı dosyada: %s (gitignore)" % kisi_yolu, flush=True)
    else:
        veri = json.loads(veri_yolu.read_text(encoding="utf-8"))

    wb = Workbook()
    sayfa_ozet(wb, veri)
    sayfa_magaza(wb, veri)
    sayfa_kadro(wb, veri)
    sayfa_bolum(wb, veri)
    sayfa_kategori(wb, veri)
    sayfa_aylik(wb, veri)
    sayfa_yillar(wb, veri)
    sayfa_oca_agu(wb, veri)
    sayfa_norm(wb, veri)
    sayfa_maliyet(wb, veri)
    sayfa_yontem(wb, veri)
    if veri.get("personel"):
        sayfa_personel(wb, veri)
    sayfa_sunum(wb, veri)   # EN SONDA: index 0'a girer, capraz-sayfa formulleri hedeflerini bulur
    # cikti yukarida cozuldu
    cikti.parent.mkdir(parents=True, exist_ok=True)
    try:
        wb.save(cikti)
    except PermissionError:
        sys.exit("Dosya açık görünüyor, kaydedilemedi. Excel'de kapatıp tekrar çalıştır: %s" % cikti)
    print("Yazildi: %s (%d sayfa)" % (cikti, len(wb.worksheets)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
