# -*- coding: utf-8 -*-
"""VARDİYA — hesaplanan kişi-günü ve elle girilen veriyi SQL tablolarına yazar.

`eksik_fazla_takip_raporu.py --sql-yaz` bunu çağırır. Excel emitter'ı değişmez;
tablo ikinci bir çıktıdır (`emitter-ayrimi.md`: tek çekirdek, çok çıktı).

⚠ DEV. Hedef yerel `BkmPanel` (`BT-FIKRI\\SQLEXPRESS`). Prod'a (`DerinSISBkm`)
  yazma YOK — `.claude/rules/erp-write-policy.md`.

Yazma kuralları:
  · `bkm.Vrd_KisiGun`  — kesim bazlı: aynı kesim yeniden koşarsa SİLİNİR + yazılır.
  · `bkm.Vrd_Devir`    — dönem bazlı; DOLU dönemin üzerine YAZILMAZ (dondurulmuş
                          kayıt). Üzerine yazmak için açık `--devir-tazele` gerekir.
  · `bkm.Vrd_Onay` / `Vrd_MagazaGeriDonus` — elle girilen taraf; bu modül yalnız
                          İLK TOHUMLAMA yapar ve var olan satıra DOKUNMAZ.
"""
from __future__ import annotations

import datetime as dt
import re
import sys

import pyodbc

DEV_SUNUCU = r"BT-FIKRI\SQLEXPRESS"
DEV_VERITABANI = "BkmPanel"


def baglan() -> pyodbc.Connection:
    if not re.fullmatch(r"[A-Za-z0-9._\\\-]+", DEV_SUNUCU):
        sys.exit("Gecersiz sunucu adi")
    return pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={DEV_SUNUCU};Database={DEV_VERITABANI};"
        "Trusted_Connection=yes;TrustServerCertificate=yes;Login Timeout=10",
        timeout=300,
    )


def _dk(deger) -> int | None:
    """Süre → dakika. Süre tabloda DAKİKA tutulur; `time` 24 saati aşamıyor ve
    gece mesaisinde çıkış ertesi güne sarkabiliyor.

    ⚠ ÜÇ AYRI TİP GELİYOR, üçü de ele alınmalı:
      · `'07:30'` / `'-2:07'` — çekirdeğin ürettiği metin
      · `timedelta` — Excel devir sayfasından okunan süre. 24 saati AŞABİLİR ve
        `str()` onu `'12 days, 20:00:00'` diye yazar; metin olarak ayrıştırmaya
        kalkmak patlar (ölçüldü 17.09.2026).
      · `time` / `datetime` — Excel'in gün-içi saat hücresi
    """
    if deger is None or deger == "":
        return None
    if isinstance(deger, dt.timedelta):
        return round(deger.total_seconds() / 60)
    if isinstance(deger, (dt.datetime, dt.time)):
        return deger.hour * 60 + deger.minute
    s = str(deger).strip()
    if not re.fullmatch(r"-?\d{1,3}:\d{2}(:\d{2})?", s):
        return None
    eksi = s.startswith("-")
    p = s.lstrip("-").split(":")
    d = int(p[0]) * 60 + int(p[1])
    return -d if eksi else d


def kisi_gun_yaz(satirlar: list[list], bas: dt.date, bit: dt.date,
                 sayim_bas: dt.date) -> int:
    """Kesimi siler ve yeniden yazar (idempotent)."""
    kayit = []
    for s in satirlar:
        ek = s[16] if len(s) > 16 else {}
        tarih = ek.get("Tarih")
        if tarih is None:
            continue
        notu = s[15] if len(s) > 15 else None
        giris, cikis = _dk(s[8]), _dk(s[9])
        gun_donumu = bool(notu and "GÜN DÖNÜMÜ" in notu)
        # Gösterim gün-içi saat; hesap +24 saatle yapıldığı için çıkışı geri aç.
        if gun_donumu and giris is not None and cikis is not None and cikis < giris:
            cikis += 24 * 60
        brut = (cikis - giris) if (giris is not None and cikis is not None) else None
        calisma = _dk(s[12])
        kayit.append((
            bas, bit, sayim_bas, s[0], str(s[1] or ""), s[2], s[3], s[4], s[5],
            tarih, s[7], _dk(ek.get("Baslama")), _dk(ek.get("Bitis")), _dk(s[13]),
            _dk(s[10]), _dk(s[11]), giris, cikis, brut,
            (brut - calisma) if (brut is not None and calisma is not None) else None,
            calisma, s[14], 1 if ek.get("Izin") else 0, 1 if gun_donumu else 0,
            1 if tarih < sayim_bas else 0,
            ek.get("KayitSayisi"), ek.get("Mazeret"), notu or None,
        ))

    cn = baglan()
    try:
        cur = cn.cursor()
        cur.fast_executemany = True
        cur.execute("DELETE FROM bkm.Vrd_KisiGun WHERE KesimBas=? AND KesimBit=?",
                    bas, bit)
        silinen = cur.rowcount
        cur.executemany("""
            INSERT INTO bkm.Vrd_KisiGun
              (KesimBas,KesimBit,SayimBas,Sube,SicilNo,PdksNo,Personel,Bolum,Gorev,
               Tarih,VardiyaTanim,PlanBaslamaDk,PlanBitisDk,PlanCalismaDk,
               KartGirisDk,KartCikisDk,GirisDk,CikisDk,BrutDk,MolaDk,CalismaDk,
               Durum,Izin,GunDonumu,SayimDisi,KayitSayisi,MazeretTipi,OlcumNotu)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            kayit)
        cn.commit()
        # Yazılanı GERİ OKU — "INSERT hata vermedi" ile "satır orada" aynı şey değil.
        cur.execute("SELECT COUNT(*) FROM bkm.Vrd_KisiGun WHERE KesimBas=? AND KesimBit=?",
                    bas, bit)
        n = cur.fetchone()[0]
        if n != len(kayit):
            sys.exit(f"KIRIK: Vrd_KisiGun → {n} satır, beklenen {len(kayit)}")
        print(f"  ✓ bkm.Vrd_KisiGun  {n} satır (önceki kesimden silinen {silinen})")
        cur.close()
    finally:
        cn.close()
    return len(kayit)


def devir_yaz(devir: list[list], donem: str, tazele: bool = False) -> int:
    """Devir DONDURULMUŞ kayıttır — dolu dönemin üzerine yazılmaz.

    Gerekçe ölçüldü (17.09.2026): PDKS geçmişe dönük düzeltiliyor, kapanışta ödenen
    rakam sonradan yeniden sorgulanarak bulunamıyor.
    """
    if not devir:
        return 0
    cn = baglan()
    try:
        cur = cn.cursor()
        cur.execute("SELECT COUNT(*) FROM bkm.Vrd_Devir WHERE Donem=?", donem)
        mevcut = cur.fetchone()[0]
        if mevcut and not tazele:
            print(f"  · bkm.Vrd_Devir  {donem} zaten dolu ({mevcut} satır) — "
                  f"DONDURULMUŞ kayıt, üzerine yazılmadı.")
            return 0
        if mevcut:
            cur.execute("DELETE FROM bkm.Vrd_Devir WHERE Donem=?", donem)
            print(f"  ⚠ bkm.Vrd_Devir  {donem} TAZELENDİ — dondurulmuş kayıt silindi.")
        # ⚠ AYNI KİŞİ BİRDEN ÇOK DEVİR SATIRI TAŞIYABİLİYOR — ölçüldü (17.09.2026):
        #   Ağustos devir sayfasının 189 satırında 3 TC İKİ KEZ geçiyor (aynı şube,
        #   aynı bölüm, farklı bakiye). Excel bu satırların hepsini ana sayfaya
        #   ekleyip TOPLUYOR; tablo da aynı davranışı korur, yoksa iki çıktı ayrışır.
        #   Ama SESSİZ KALINMAZ: hangi kişide kaç satır olduğu yazılır — mükerrer
        #   giriş hatası mı, kasıtlı iki kalem mi, İK'nın kararı.
        birlesik: dict[str, list] = {}
        mukerrer: dict[str, int] = {}
        for d in devir:
            tc = str(d[1] or "").strip()
            e, f = _dk(d[7]) or 0, _dk(d[8]) or 0
            if tc in birlesik:
                birlesik[tc][6] += e
                birlesik[tc][7] += f
                mukerrer[tc] = mukerrer.get(tc, 1) + 1
            else:
                birlesik[tc] = [donem, tc, d[0], d[3], d[4], d[5], e, f]
        if mukerrer:
            print(f"  ⚠ Devir sayfasında {len(mukerrer)} kişi BİRDEN ÇOK satır "
                  f"taşıyor — Excel'le aynı şekilde TOPLANDI, teyit gerekir:")
            for tc, n in mukerrer.items():
                k = birlesik[tc]
                print(f"       {str(k[3])[:26]:28s} {n} satır → eksik "
                      f"{k[6] // 60}:{k[6] % 60:02d} · fazla {k[7] // 60}:{k[7] % 60:02d}")
        kayit = [tuple(v[0:2] + v[2:8]) for v in birsel] if False else \
                [(v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7])
                 for v in birlesik.values()]
        cur.fast_executemany = True
        cur.executemany("""
            INSERT INTO bkm.Vrd_Devir
              (Donem,SicilNo,Sube,Personel,Bolum,Gorev,EksikDk,FazlaDk)
            VALUES (?,?,?,?,?,?,?,?)""", kayit)
        cn.commit()
        print(f"  ✓ bkm.Vrd_Devir  {len(kayit)} satır ({donem})")
        cur.close()
        return len(kayit)
    finally:
        cn.close()
