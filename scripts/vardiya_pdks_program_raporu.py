# -*- coding: utf-8 -*-
"""VARDİYA YÖNET — PDKS PROGRAM RAPORU (şube bazlı, formüllü Excel).

Elle çalıştırılan "Vardiya Yonet → Pdks Aktar → Excel Aktar" çıktısının SQL'den
yeniden üretimi. Kaynak dosya: `Fsm Kisi Tarih Birlestirme Formulleri Standart cc.xlsx`
sayfa "Vardiya Yönet Program Raporu" (FSM, 31.08–13.09.2026).

KURALLAR ÖLÇÜLDÜ, TAHMİN EDİLMEDİ (2026-09-15, FSM 595 satır üzerinde):
  1) Personel Giriş = plana 10 dk TOLERANS, ÇİFT YÖNLÜ:
         giris = plan + sign(kart-plan) * max(0, |kart-plan| - 10)
     Yani erken gelen plandan önce sayılmaz, geç gelenin ilk 10 dk'sı affedilir.
     Ölçüm: 521/521 satır (izin günü plan=0 dahil).
  2) Personel Çıkış = HAM PDKS çıkışı. Tolerans YOK (521/521 birebir).
  3) Personel Çalışma = (çıkış - giriş) - mola;  mola TOOL tablosu:
         brüt >= 7:30 → 60 dk · 4:30..7:29 → 45 dk · 2:30..4:29 → 15 dk · altı 0
     ⚠ Bu tablo Excel'deki "Mola Saatleri" sayfasından FARKLIDIR (orası brüt 8:30
     eşiğiyle 60 dk verir). Fark 7:30–8:30 bandında 15 dk'dır ve KASITLIDIR:
     M kolonu programın molası, Z kolonu Excel'in molası. İkisi ayrı ölçüdür.
     ⚠ 45 dk bandının ALT sınırı (2:30–4:29 arası) veride gözlenmedi → ÇIKARIM.
  4) Durum — HAM PDKS saatiyle karar verilir, toleranslı saatle DEĞİL (595/595):
         izin & okutma var → "İzin Günü Çalışılmış"
         izin & okutma yok → "İzinli"
         okutma yok        → "Devamsız"
         kartGiriş > planBaşlama VEYA kartÇıkış < planBitiş
                           → "Geç girilmiş ve/veya erken çıkılmış"
         aksi              → "Normal Çalışma"

R:AE = Excel formül katmanı (orijinalle birebir). T/U "Yönetici Onaylı Giriş/Çıkış"
ELLE doldurulan kolonlardır — veriden türetilemez, BOŞ bırakılır. Formül zaten
`IF(T=0,R,T)` ile toleranslı saate düşer; yönetici düzeltmesi girildiğinde devreye
girer. FSM dosyasında bu kolonlar dolu; oradaki değerler bu depodaki hiçbir
kaynaktan üretilemiyor (ölçüldü) — uydurmak yerine boş bırakıldı.

⚠ pyodbc (pymssql DEĞİL): DerinSIS varchar CP1254, pymssql Türkçe'yi bozuyor.
⚠ OPENQUERY tarih literali ISO 'YYYYMMDD' (linked server kuralı).
⚠ TC köprüsü: vrd.VardiyaDetay.SicilNo (11 hane TC) = PDKS TPerInd.PIn_SteuerNr,
   COLLATE Turkish_CI_AS zorunlu. 11 TC iki kez kayıtlı → PersNr tekilleştirilir.

Kullanım:
    python scripts/vardiya_pdks_program_raporu.py --sube ÖZLÜCE
    python scripts/vardiya_pdks_program_raporu.py --sube FSM --dogrula "D:/Downloads/....xlsx"
"""
from __future__ import annotations

import argparse
import datetime as dt
import io
import os
import re
import sys

import pyodbc
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BASLIKLAR = [
    "Şube", "SicilNo", "PDKS No", "Personel", "Bölüm", "Görev", "Tarih",
    "Vardiya Tanım", "Personel Giriş", "Personel Çıkış", "PDKS Giris", "PDKS Çıkış",
    "Personel Çalışma", "Vardiya Tanım Çalışma", "Durum", "EksikSaat", "FazlaSaat",
    "Toleranslı Giriş", "Toleranslı Çıkış", "Yönetici Onaylı  Giriş",
    "Yönetici Onaylı  Çıkış", "Giriş", "Çıkış", "Brüt Çalışma Saati", "Mola Saati",
    "Net Çalışma Saati\nGerçekleşen", "Net Çalışma Saati Olması Gereken",
    "EksikSaat", "FazlaSaat", "İzin Durumu", "Hafta",
    # ── GMY isteği 15.09.2026: "haftalık izin kullanmıyorsa ona mesai vermek gerek"
    "Haftalık Çalışılan Gün", "Hafta Tatili (HFT.İZİN) Gün", "Hafta Tatili Kullanılmadı",
    # ── ÖNLEM 16.09.2026: "Devamsız" ÜÇ FARKLI ŞEYİ aynı etiketle gösteriyordu.
    #    Orijinal "Durum" kolonu ARACIN çıktısıyla birebir kalsın diye DOKUNULMADI;
    #    denetim ayrı kolona yazılır.
    "Ölçüm Notu",
]

TOLERANS_DK = 10

# Programın mola tablosu — brüt dakika eşiği → düşülen mola (ölçüldü)
MOLA_TABLOSU = [(450, 60), (270, 45), (150, 15)]


def env_oku(yol: str) -> dict[str, str]:
    """`.env` dosyasını okur. Kimlik YALNIZ burada durur (tek kimlik yolu)."""
    if not os.path.exists(yol):
        sys.exit(f".env bulunamadi: {yol}")
    env: dict[str, str] = {}
    with open(yol, encoding="utf-8") as f:
        for ln in f:
            if ln.lstrip().startswith("#"):
                continue
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
            if m:
                env[m.group(1)] = m.group(2).strip().strip('"')
    return env


def baglan(env: dict[str, str]) -> pyodbc.Connection:
    host, port = env["MSSQL_HOST"], env.get("MSSQL_PORT", "1433")
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
        sys.exit("Gecersiz MSSQL_HOST/MSSQL_PORT (.env)")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 900
    return cn


# =============================================================================
# HAM ÖLÇÜM
# =============================================================================

# Vardiya planı: haftalık başlık × kişi × 7 gün kolonu → kişi-gün (UNPIVOT).
# `Tarih` haftanın PAZARTESİ'sidir; gün ofseti CROSS APPLY ile açılır.
# VardiyaId = 0 → o gün vardiya atanmamış (SIFIR SENTİNEL, NULL değil) → satır yok.
SQL_PLAN = """
SELECT  s.SubeAd,
        LTRIM(RTRIM(vd.SicilNo))                  AS SicilNo,
        vd.Personel, vd.Bolum, vd.Gorev,
        CONVERT(date, DATEADD(day, g.ofs, v.Tarih)) AS Tarih,
        g.VardiyaId,
        vz.Aciklama                               AS VardiyaTanim,
        vz.Baslama, vz.Bitis,
        vz.ToplamCalismaDk, vz.Izin
FROM        BKM.vrd.Vardiya       v
INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo    = v.SubeNo
INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
CROSS APPLY (VALUES (0, vd.Pazartesi), (1, vd.Sali), (2, vd.Carsamba),
                    (3, vd.Persembe), (4, vd.Cuma), (5, vd.Cumartesi),
                    (6, vd.Pazar)) AS g(ofs, VardiyaId)
LEFT  JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
WHERE   s.SubeAd = ?
    AND g.VardiyaId <> 0
    AND DATEADD(day, g.ofs, v.Tarih) >= ?
    AND DATEADD(day, g.ofs, v.Tarih) <= ?
ORDER BY DATEADD(day, g.ofs, v.Tarih), vd.Personel
"""

# TC → PersNr sözlüğü. AYRI çekilir: kişi o gün kart basmasa da "PDKS No" dolu olmalı
# (ölçüldü — araç izinli/devamsız günlerde de PersNr yazıyor). 11 TC iki kez kayıtlı,
# MIN(PersNr) ile tekilleştirilir; yoksa fan-out.
# ⚠ MÜKERRER TC: 11 TC iki PersNr taşıyor (yeniden işe giriş). Doğru kayıt ÖLÇÜLDÜ
# (2026-09-15): 11'inin 11'inde tam BİRİ `Per_ZeitAktiv = 1` ve kart okumaları da
# onda. MIN/MAX tahmini değil, bu süzgeç kullanılır.
# ⚠ GEREKÇE DÜZELTİLDİ 16.09.2026: `Per_ZeitAktiv` "personel aktif mi" DEĞİL,
#   "PDKS zaman takibi açık mı" demektir. Mükerrer TC'de doğru kaydı seçmek için
#   çalışır (okumalar o kayıtta), ama kişinin işte olup olmadığını SÖYLEMEZ —
#   müdürlerde 0'dır ve onlar çalışmaktadır (Zirve bordrosuyla doğrulandı).
SQL_TC = """
SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.PersNr, x.Aktif
FROM OPENQUERY([PDKS], '
    SELECT i.PIn_SteuerNr AS TC, i.PIn_PersNr AS PersNr,
           ISNULL(p.Per_ZeitAktiv, 0) AS Aktif
    FROM TPerInd i
    LEFT JOIN TPerTab p ON p.Per_PersNr = i.PIn_PersNr
    WHERE i.PIn_SteuerNr <> ''''
') x
"""

# HAM OKUTMA (TZeiBuf) — "Devamsız" etiketini DENETLEMEK için.
# ⚠ `TTagZei` giriş+çıkış ÇİFTİ ister; kişi tek okutma yaptıysa orada satır
#   OLUŞMAZ ve rapor "Devamsız" der. Ham okutmada ise görünür — 15.09'da GÖZDE
#   EKİM tam bu yüzden yanlış etiketlendi (22:20'de okutması vardı).
SQL_HAM_OKUTMA = """
SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.Gun, x.Okutma
FROM OPENQUERY([PDKS], '
    SELECT  i.PIn_SteuerNr                        AS TC,
            CONVERT(char(8), b.ZBu_ErfDatum, 112) AS Gun,
            COUNT(*)                              AS Okutma
    FROM        TZeiBuf b
    INNER JOIN  TPerInd i ON i.PIn_PersNr = b.ZBu_PersNr
    WHERE   b.ZBu_ErfDatum >= ''{bas}'' AND b.ZBu_ErfDatum <= ''{bit}''
        AND ISNULL(b.ZBu_Storniert, 0) = 0
        AND i.PIn_SteuerNr <> ''''
    GROUP BY i.PIn_SteuerNr, CONVERT(char(8), b.ZBu_ErfDatum, 112)
') x
"""

# Şube → PDKS grup eşlemesi. ⚠ Per_Grp2 TEK BAŞINA YETMEZ: "FSM" hem mağazanın
# hem FSM KAFE'nin Per_Grp2'sidir; ayıran Per_Grp1 (MAĞAZALAR / KAFELER).
SQL_SUBE_GRP = """
SELECT x.Per_Grp1, x.Per_Grp2
FROM OPENQUERY([PDKS], 'SELECT SubeNo, SubeAd, Per_Grp1, Per_Grp2 FROM bkm.SubeListe') x
WHERE x.SubeAd COLLATE Turkish_CI_AS = ? AND x.Per_Grp2 IS NOT NULL
"""

# PLANSIZ AMA KART BASAN (kullanıcı isteği 15.09.2026): hafta içinde işe yeni giren
# personel vardiya planına işlenmemiş olabilir; kart bastıysa raporda GÖRÜNMELİ.
# Kapsam PDKS tarafından (Per_Grp1+Per_Grp2) çizilir, plandan değil.
SQL_PDKS_SUBE = """
SELECT  x.TC COLLATE Turkish_CI_AS AS TC, x.PersNr, x.Ad, x.Gun,
        x.Giris, x.Cikis, x.KayitSayisi, x.Mazeret
FROM OPENQUERY([PDKS], '
    SELECT  ISNULL(i.PIn_SteuerNr, '''')                  AS TC,
            p.Per_PersNr                                  AS PersNr,
            LTRIM(RTRIM(p.Per_Vorname)) + '' '' + LTRIM(RTRIM(p.Per_Name)) AS Ad,
            CONVERT(char(8), l.TLe_Datum, 112)            AS Gun,
            MIN(l.TLe_VonZeit)                            AS Giris,
            MAX(l.TLe_BisZeit)                            AS Cikis,
            COUNT(*)                                      AS KayitSayisi,
            MIN(l.TLe_AbwArt)                             AS Mazeret
    FROM        TPerTab p
    INNER JOIN  TTagLes l ON l.TLe_PersNr = p.Per_PersNr
    LEFT  JOIN  TPerInd i ON i.PIn_PersNr = p.Per_PersNr
    WHERE   l.TLe_Datum >= ''{bas}'' AND l.TLe_Datum <= ''{bit}''
        AND l.TLe_BeginnKz = 0
        AND LTRIM(RTRIM(p.Per_Grp1)) = ''{grp1}''
        AND LTRIM(RTRIM(p.Per_Grp2)) = ''{grp2}''
    GROUP BY i.PIn_SteuerNr, p.Per_PersNr, p.Per_Vorname, p.Per_Name,
             CONVERT(char(8), l.TLe_Datum, 112)
') x
"""

# PDKS fiili: TC → PersNr → TTagLes günlük özet.
# TLe_BeginnKz = 0 → günün İLK satırı (gün özeti). Kayıt sayısı ayrıca sayılır.
SQL_PDKS = """
SELECT  x.TC COLLATE Turkish_CI_AS AS TC,
        x.PersNr, x.Gun, x.Giris, x.Cikis, x.KayitSayisi, x.Mazeret
FROM OPENQUERY([PDKS], '
    SELECT  i.PIn_SteuerNr                        AS TC,
            MIN(i.PIn_PersNr)                     AS PersNr,
            CONVERT(char(8), l.TLe_Datum, 112)    AS Gun,
            MIN(l.TLe_VonZeit)                    AS Giris,
            MAX(l.TLe_BisZeit)                    AS Cikis,
            COUNT(*)                              AS KayitSayisi,
            MIN(l.TLe_AbwArt)                     AS Mazeret
    FROM        TPerInd i
    INNER JOIN  TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
    WHERE   l.TLe_Datum >= ''{bas}''
        AND l.TLe_Datum <= ''{bit}''
        AND l.TLe_BeginnKz = 0
        AND i.PIn_SteuerNr <> ''''
    GROUP BY i.PIn_SteuerNr, CONVERT(char(8), l.TLe_Datum, 112)
') x
"""


def dk_to_hhmm(d: int | None) -> str | None:
    if d is None:
        return None
    return f"{d // 60:02d}:{d % 60:02d}"


def saat_to_dk(v) -> int | None:
    """datetime/time/str → gün içi dakika."""
    if v is None:
        return None
    if isinstance(v, (dt.datetime, dt.time)):
        return v.hour * 60 + v.minute
    if isinstance(v, str) and ":" in v:
        p = v.split(":")
        return int(p[0]) * 60 + int(p[1])
    return None


def mola_dk(brut: int) -> int:
    for esik, mola in MOLA_TABLOSU:
        if brut >= esik:
            return mola
    return 0


def toleransli_giris(plan_bas: int | None, kart_giris: int) -> int:
    """Plana 10 dk tolerans, çift yönlü (ölçüldü: 521/521)."""
    if plan_bas is None:
        plan_bas = 0
    fark = kart_giris - plan_bas
    if abs(fark) <= TOLERANS_DK:
        return plan_bas
    return plan_bas + (fark - TOLERANS_DK if fark > 0 else fark + TOLERANS_DK)


def satir_uret(plan: dict, pdks: dict | None, persnr: int | None,
               ham_okutma: int | None = None) -> list:
    """Bir kişi-gün için A..O kolonlarını üretir. Hiçbir kural burada icat edilmez."""
    izin = bool(plan["Izin"])
    plan_bas = saat_to_dk(plan["Baslama"])
    plan_bit = saat_to_dk(plan["Bitis"])
    plan_dk = plan["ToplamCalismaDk"] or 0

    kart_g = saat_to_dk(pdks["Giris"]) if pdks else None
    kart_c = saat_to_dk(pdks["Cikis"]) if pdks else None
    varsa = kart_g is not None and kart_c is not None

    if varsa:
        giris = toleransli_giris(plan_bas if not izin else 0, kart_g)
        cikis = kart_c                     # çıkışta tolerans YOK (ölçüldü)
        brut = cikis - giris
        calisma = brut - mola_dk(brut)
    else:
        giris = cikis = None
        calisma = 0

    if plan.get("Plansiz"):
        # Kullanıcı isteği 15.09.2026: plana işlenmemiş ama kart basmış kişi.
        # ⚠ Bu durum kodu ARACIN çıktısında YOKTUR — bizim eklediğimiz beşinci koddur.
        durum = "Vardiya Tanımsız Çalışma"
    elif izin:
        durum = "İzin Günü Çalışılmış" if varsa else "İzinli"
    elif not varsa:
        durum = "Devamsız"
    elif (plan_bas is not None and kart_g > plan_bas) or \
         (plan_bit is not None and kart_c < plan_bit):
        durum = "Geç girilmiş ve/veya erken çıkılmış"
    else:
        durum = "Normal Çalışma"

    return [
        plan["SubeAd"], plan["SicilNo"], persnr,
        plan["Personel"], plan["Bolum"], plan["Gorev"],
        plan["Tarih"].strftime("%d.%m.%Y"),
        plan["VardiyaTanim"],
        dk_to_hhmm(giris), dk_to_hhmm(cikis),
        dk_to_hhmm(kart_g), dk_to_hhmm(kart_c),
        dk_to_hhmm(calisma), dk_to_hhmm(0 if izin else plan_dk),
        durum,
        olcum_notu(durum, persnr, ham_okutma),
    ]


def olcum_notu(durum: str, persnr, ham_okutma: int | None) -> str:
    """"Devamsız" etiketinin DENETİMİ (16.09.2026 önlemi).

    Bu oturumda iki kez yanıltıcı oldu, ikisi ayrı sebepten:
      · PDKS'te TC kaydı olmayan kişi (müdür kadrosu) "Devamsız" göründü —
        aslında ÖLÇÜLEMİYOR.
      · Tek okutma yapan kişi (GÖZDE EKİM, 22:20) "Devamsız" göründü, çünkü
        TTagZei giriş+çıkış ÇİFTİ ister ve orada satır oluşmamış.
    Not AYRI kolona yazılır; "Durum" aracın çıktısıyla birebir kalır.
    """
    if durum != "Devamsız":
        return ""
    if persnr is None:
        return "PDKS kaydı yok — ölçülemiyor (devamsız DEĞİL)"
    if ham_okutma:
        return f"HAM OKUTMA VAR ({ham_okutma} kez) — giriş/çıkış çifti oluşmamış"
    return "Ham okutma da yok"


def veri_cek(cn, sube: str, bas: dt.date, bit: dt.date) -> list[list]:
    cur = cn.cursor()
    cur.execute(SQL_PLAN, sube, bas, bit)
    kol = [c[0] for c in cur.description]
    plan_satir = [dict(zip(kol, r)) for r in cur.fetchall()]
    if not plan_satir:
        sys.exit(f"KOŞAMADI: '{sube}' şubesi için {bas}–{bit} aralığında plan satırı YOK.")

    # TC → PersNr. Mükerrer TC'de AKTİF kayıt kazanır (ölçüldü, tahmin değil).
    cur.execute(SQL_HAM_OKUTMA.format(bas=bas.strftime("%Y%m%d"), bit=bit.strftime("%Y%m%d")))
    ham_okutma = {(str(r[0]).strip(), str(r[1])): int(r[2]) for r in cur.fetchall()}

    cur.execute(SQL_TC)
    tc_persnr: dict[str, tuple[int, int]] = {}
    for tc, persnr, aktif in cur.fetchall():
        tc = str(tc).strip()
        aktif, persnr = int(aktif or 0), int(persnr)
        onceki = tc_persnr.get(tc)
        if onceki is None or (aktif, persnr) > onceki:
            tc_persnr[tc] = (aktif, persnr)
    tc_aktif = {k: bool(v[0]) for k, v in tc_persnr.items()}
    tc_persnr = {k: v[1] for k, v in tc_persnr.items()}

    cur.execute(SQL_PDKS.format(bas=bas.strftime("%Y%m%d"), bit=bit.strftime("%Y%m%d")))
    kol = [c[0] for c in cur.description]
    pdks = {}
    for r in cur.fetchall():
        d = dict(zip(kol, r))
        pdks[(str(d["TC"]).strip(), str(d["Gun"]))] = d
    if not pdks:
        sys.exit("KOŞAMADI: PDKS tarafı BOŞ döndü — okuma gerçekten yok mu, "
                 "yoksa linked server mı düştü? Boş nüfus 'ihlal yok' demek değildir.")

    print(f"  plan kişi-gün : {len(plan_satir)}")
    print(f"  PDKS kişi-gün : {len(pdks)} (tüm şubeler)")

    satirlar = []
    eslesmeyen = set()
    planli_anahtar = set()
    kisi_bilgi: dict[str, tuple] = {}     # TC → (Personel, Bölüm, Görev) — plandan
    for p in plan_satir:
        anahtar = (p["SicilNo"], p["Tarih"].strftime("%Y%m%d"))
        planli_anahtar.add(anahtar)
        kisi_bilgi.setdefault(p["SicilNo"], (p["Personel"], p["Bolum"], p["Gorev"]))
        pn = tc_persnr.get(p["SicilNo"])
        if pn is None:
            eslesmeyen.add(p["SicilNo"])
        pk = pdks.get(anahtar)
        # ⚠⚠ DÜZELTİLDİ 16.09.2026 — ÖNCEKİ YORUM YANLIŞTI.
        # `Per_ZeitAktiv = 0` "İŞTEN AYRILDI" DEMEK DEĞİL; "PDKS zaman takibi
        # KAPALI" demek. Mağaza müdürü / müdür yardımcısı kart basmadığı için
        # bu bayrak onlarda 0'dır ve KİŞİ AKTİF ÇALIŞMAKTADIR.
        # Zirve bordrosuyla doğrulandı (BKM_GENEL, vw_PuanBil): RESUL ÇİL
        # 2026'nın 1-8. aylarında, MERT SARGIN 7-8-9'da, NECMETTİN ÇELİK 1-8'de
        # bordroda — hepsi çalışıyor.
        # Bu satırlar ÖNCE rapordan düşürülüyordu; artık düşürülmüyor, aksi
        # halde kadronun bir bölümü sessizce görünmez oluyordu.
        satirlar.append(satir_uret(
            p, pk, pn, ham_okutma.get((p["SicilNo"], p["Tarih"].strftime("%Y%m%d")))))
    if eslesmeyen:
        print(f"  ⚠ PDKS'te TC'si HİÇ bulunmayan kişi: {len(eslesmeyen)} "
              f"— bunların günleri 'Devamsız' görünür, gelmedikleri için DEĞİL.")

    satirlar += plansiz_satirlar(cur, sube, bas, bit, planli_anahtar, kisi_bilgi)
    cur.close()
    satirlar.sort(key=lambda s: (dt.datetime.strptime(s[6], "%d.%m.%Y"), str(s[3] or "")))
    return satirlar


def plansiz_satirlar(cur, sube, bas, bit, planli_anahtar, kisi_bilgi) -> list[list]:
    """Plana işlenmemiş ama kart basmış kişi-günler (kullanıcı isteği 15.09.2026).

    Kapsam PDKS tarafından çizilir: Per_Grp1 + Per_Grp2. Şube adı doğrudan OPENQUERY
    literaline gömüldüğü için whitelist guard var (injection).
    """
    cur.execute(SQL_SUBE_GRP, sube)
    gruplar = [(str(a).strip(), str(b).strip()) for a, b in cur.fetchall()]
    if not gruplar:
        print(f"  ⚠ KOŞAMADI (kısmi): '{sube}' PDKS bkm.SubeListe'de yok → plansız "
              f"kart okutmaları TARANAMADI. Rapor yalnız planlı satırları içeriyor.")
        return []

    ek: list[list] = []
    for grp1, grp2 in gruplar:
        if not re.fullmatch(r"[0-9A-Za-zÇĞİÖŞÜçğıöşü .\-]+", grp1 + grp2):
            print(f"  ⚠ atlandı (beklenmedik grup adı): {grp1!r}/{grp2!r}")
            continue
        cur.execute(SQL_PDKS_SUBE.format(bas=bas.strftime("%Y%m%d"),
                                         bit=bit.strftime("%Y%m%d"),
                                         grp1=grp1, grp2=grp2))
        kol = [c[0] for c in cur.description]
        for r in cur.fetchall():
            d = dict(zip(kol, r))
            tc = str(d["TC"] or "").strip()
            gun = str(d["Gun"])
            if (tc, gun) in planli_anahtar:
                continue
            ad, bolum, gorev = kisi_bilgi.get(tc, (d["Ad"], None, None))
            sahte_plan = {
                "SubeAd": sube, "SicilNo": tc, "Personel": ad,
                "Bolum": bolum, "Gorev": gorev,
                "Tarih": dt.datetime.strptime(gun, "%Y%m%d").date(),
                "VardiyaTanim": None, "Baslama": None, "Bitis": None,
                "ToplamCalismaDk": 0, "Izin": 0, "Plansiz": True,
            }
            ek.append(satir_uret(sahte_plan, d, d["PersNr"], None))
    if ek:
        kisi = len({s[1] for s in ek})
        print(f"  + plansız ama kart basmış: {len(ek)} kişi-gün / {kisi} kişi "
              f"(durum: 'Vardiya Tanımsız Çalışma')")
    return ek


# =============================================================================
# EXCEL — R:AE formül katmanı orijinalle birebir
# =============================================================================
# Şube başına "olması gereken net çalışma" — AA kolonunun VLOOKUP tabanı.
# ⚠ ŞUBEDEN ŞUBEYE DEĞİŞİR (ölçüldü 2026-09-15): GENEL MÜDÜRLÜK 09:00 (540 dk),
# diğer sekiz şube 07:30 (450 dk). Tek sabit kullanılırsa GM'nin TÜM kadrosu
# günde 1,5 saat "fazla mesai" görünür. Değer elle yazılmaz, plandan ölçülür.
SQL_NET_GEREKEN = """
SELECT  s.SubeAd, vz.ToplamCalismaDk, COUNT(*) AS KisiGun
FROM        BKM.vrd.Vardiya       v
INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo     = v.SubeNo
INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
CROSS APPLY (VALUES (vd.Pazartesi), (vd.Sali), (vd.Carsamba), (vd.Persembe),
                    (vd.Cuma), (vd.Cumartesi), (vd.Pazar)) AS g(Vid)
INNER JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.Vid
WHERE   v.Tarih >= DATEADD(day, -6, ?) AND v.Tarih <= ?
    AND vz.Izin = 0 AND g.Vid <> 0 AND vz.ToplamCalismaDk > 0
GROUP BY s.SubeAd, vz.ToplamCalismaDk
"""


def net_gereken_olc(cur, bas: dt.date, bit: dt.date) -> dict[str, str]:
    """Şube → en yaygın plan süresi (mod). Elle liste yazılmaz, ölçülür."""
    cur.execute(SQL_NET_GEREKEN, bas, bit)
    sayac: dict[str, dict[int, int]] = {}
    for sube, dk, n in cur.fetchall():
        sayac.setdefault(str(sube).strip(), {})[int(dk)] = int(n)
    sonuc = {}
    for sube, dagilim in sayac.items():
        dk = max(dagilim, key=lambda k: dagilim[k])
        sapan = sum(v for k, v in dagilim.items() if k != dk)
        sonuc[sube] = f"{dk // 60:02d}:{dk % 60:02d}"
        if sapan:
            print(f"    {sube:16s} {sonuc[sube]}  (bu süre {dagilim[dk]} kişi-gün; "
                  f"{sapan} kişi-gün BAŞKA süre planlanmış → AA kolonu onlarda "
                  f"şube standardını gösterir, kişinin kendi planını DEĞİL)")
        else:
            print(f"    {sube:16s} {sonuc[sube]}  ({dagilim[dk]} kişi-gün, sapma yok)")
    return sonuc


def excel_yaz(satirlar: list[list], cikti: str, net_gereken: dict[str, str]):
    wb = Workbook()

    ws = wb.active
    ws.title = "Vardiya Yönet Program Raporu"
    ws.append(BASLIKLAR)
    for c in range(1, len(BASLIKLAR) + 1):
        h = ws.cell(1, c)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = PatternFill("solid", fgColor="E30622")
        h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    ws.freeze_panes = "A2"

    son = len(satirlar) + 1          # SUMIFS aralıkları için son satır
    for i, s in enumerate(satirlar, start=2):
        # ⚠ KOLON SIRASI: satir_uret 16 eleman döner (A..O veri + "Ölçüm Notu").
        #   Ölçüm Notu araç kolonlarının ARASINA giremez, yoksa P'den itibaren
        #   tüm formüller bir kolon kayar (16.09'da tam bu oldu ve Excel'de
        #   "Ölçüm Notu" başlığının altında formül metni göründü).
        #   Doğrusu: ilk 15 veri → formüller → Ölçüm Notu EN SONA.
        ws.append(s[:15] + [
            f"=IF(M{i}>N{i},0,N{i}-M{i})",                  # P EksikSaat
            f"=IF(M{i}>N{i},M{i}-N{i},0)",                  # Q FazlaSaat
            f"=+I{i}",                                      # R Toleranslı Giriş
            f"=+J{i}",                                      # S Toleranslı Çıkış
            None,                                           # T Yönetici Onaylı Giriş (ELLE)
            None,                                           # U Yönetici Onaylı Çıkış (ELLE)
            f'=IF(T{i}=0,R{i},T{i})',                    # V Giriş
            f'=IF(U{i}=0,S{i},U{i})',                    # W Çıkış
            f"=+W{i}-V{i}",                                 # X Brüt
            (f"=IF(X{i}>'Mola Saatleri'!$C$3,'Mola Saatleri'!$B$3,"
             f"IF(X{i}>'Mola Saatleri'!$C$4,'Mola Saatleri'!$B$4,"
             f"IF(X{i}>'Mola Saatleri'!$C$5,'Mola Saatleri'!$B$5,TIME(0,0,0))))"),  # Y Mola
            f"=+X{i}-Y{i}",                                 # Z Net gerçekleşen
            (f'=IF(OR(H{i}="HFT.İZİN",H{i}="ÖZEL DURUM",H{i}="YILLIK İZİN"),0,'
             f"VLOOKUP(A{i},'Mola Saatleri'!$E:$F,2,0))"),  # AA Net olması gereken
            f"=IF(Z{i}<AA{i},AA{i}-Z{i},0)",                # AB EksikSaat
            f"=IF(Z{i}>AA{i},Z{i}-AA{i},0)",                # AC FazlaSaat
            f'=IF(OR(O{i}="İZİNLİ",O{i}="DEVAMSIZ"),0,1)',  # AD İzin Durumu
            f"=WEEKNUM(G{i},2)",                            # AE Hafta
            # ── Hafta tatili (GMY 15.09.2026) — kişi = SicilNo, isim DEĞİL
            f"=SUMIFS($AD$2:$AD${son},$B$2:$B${son},$B{i},$AE$2:$AE${son},$AE{i})",
            f'=COUNTIFS($B$2:$B${son},$B{i},$AE$2:$AE${son},$AE{i},'
            f'$H$2:$H${son},"HFT.İZİN")',
            f"=IF(AND(AG{i}=0,AF{i}>=7),1,0)",
            s[15] if len(s) > 15 else "",                   # AI Ölçüm Notu
        ])

    for c, w in enumerate([14, 13, 9, 24, 18, 24, 11, 15] + [11] * 11 + [13] * 12, start=1):
        ws.column_dimensions[get_column_letter(c)].width = w
    for c in range(16, 30):                       # P..AC süre kolonları
        for r in range(2, len(satirlar) + 2):
            ws.cell(r, c).number_format = "[h]:mm"

    # T/U = ELLE girilen "Yönetici Onaylı" kolonları. Boş bırakılır; bir değer
    # yazıldığı anda V/W formülü (`IF(T=0,R,T)`) toleranslı saat yerine ONU alır
    # ve X→Z→AB/AC zinciri kendiliğinden yeniden hesaplanır (Excel'de ÖLÇÜLDÜ).
    # Sarı zemin + hh:mm formatı: yazılan "13:32" metin değil SAAT olarak girsin.
    elle = PatternFill("solid", fgColor="FFF3C4")
    for c in (20, 21):
        ws.cell(1, c).comment = None
        for r in range(2, len(satirlar) + 2):
            h = ws.cell(r, c)
            h.number_format = "hh:mm"
            h.fill = elle

    # ── Mola Saatleri (formüllerin dayandığı parametre sayfası) ──
    mola = wb.create_sheet("Mola Saatleri")
    # ⚠ SAATLER GERÇEK ZAMAN DEĞERİ OLMALI, METİN DEĞİL. Metin yazılırsa Excel
    # onu HER SAYIDAN BÜYÜK sayar: AA (VLOOKUP ile gelen "olması gereken") metin
    # olunca `IF(Z<AA,...)` hep TRUE döner ve EksikSaat/FazlaSaat YER DEĞİŞTİRİR —
    # hata vermez, sayı yanlış çıkar. Excel'de ölçülerek yakalandı (2026-09-15).
    def sa(metin: str) -> dt.time:
        s, d = metin.split(":")
        return dt.time(int(s), int(d))

    mola["A1"], mola["B1"], mola["C1"] = "Net Çalışma Saatlerine Göre", "Mola", "Brüt Süre"
    mola["A2"], mola["B2"], mola["C2"] = sa("07:30"), sa("01:30"), "Üstü"
    mola["A3"], mola["B3"], mola["C3"] = sa("07:30"), sa("01:00"), "=+A3+B3"
    mola["A4"], mola["B4"], mola["C4"] = sa("04:00"), sa("00:45"), "=+A4+B4"
    mola["A5"], mola["B5"], mola["C5"] = sa("02:00"), sa("00:15"), "=+A5+B5"
    # Her şube kendi satırını alır — AA'daki VLOOKUP şube adıyla buraya bakar.
    for i, (sb, sure) in enumerate(sorted(net_gereken.items()), start=2):
        mola.cell(i, 5).value = sb
        mola.cell(i, 6).value = sa(sure)
        mola.cell(i, 6).number_format = "[h]:mm"
    for adr in ("A2", "A3", "A4", "A5", "B2", "B3", "B4", "B5", "C3", "C4", "C5"):
        mola[adr].number_format = "[h]:mm"
    mola["E1"] = "Şube"
    mola["F1"] = "Net Çalışma Saati Olması Gereken"
    mola.column_dimensions["A"].width = 26
    mola.column_dimensions["E"].width = 16
    mola.column_dimensions["F"].width = 30

    ozet_sayfalari(wb, satirlar)
    wb.save(cikti)
    return cikti


def ozet_sayfalari(wb, satirlar: list[list]) -> None:
    """Orijinal dosyanın iki özet sayfasının FORMÜLLÜ karşılığı.

    Orijinalde bu sayfalar PivotTable'dır ("Yönetici Özeti - Toplam" pivotunun
    yanına elle `=IF(D>E,D-E,0)` netleştirme kolonları yazılmış). Burada pivot
    yerine SUMIFS/COUNTIFS kuruldu: T/U "Yönetici Onaylı" hücrelerine saat
    girildiğinde özetler KENDİLİĞİNDEN güncellenir — pivot yenilemek gerekmez.

    ⚠ Kişi kimliği SicilNo (TC), isim DEĞİL: aynı isim iki bölümde görünebiliyor
    (orijinal dosyada RECEP KALAT hem AKADEMİ hem KÜLTÜR satırında var).
    """
    n = len(satirlar) + 1                       # ana sayfadaki son satır
    A = "'Vardiya Yönet Program Raporu'!"       # ana sayfa referans öneki
    def rng(k):                                 # tam kolon değil, sınırlı aralık
        return f"{A}${k}$2:${k}${n}"

    baslik_font = Font(bold=True, color="FFFFFF", size=10)
    baslik_dolgu = PatternFill("solid", fgColor="E30622")

    def basliklandir(ws, kolonlar, genislikler):
        ws.append(kolonlar)
        for c in range(1, len(kolonlar) + 1):
            h = ws.cell(1, c)
            h.font, h.fill = baslik_font, baslik_dolgu
            h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        for c, w in enumerate(genislikler, start=1):
            ws.column_dimensions[get_column_letter(c)].width = w
        ws.freeze_panes = "A2"

    # ── 1. HAFTALIK ÇALIŞMA GÜN SAYISI (kişi × hafta) ────────────────────────
    # GMY isteği: "haftalık izin kullanmıyorsa ona mesai vermek gerek — HFT.İZİN
    # tanımı olmadığında 7 gün çalıştı ise". Bayrak burada kurulur; saat/TL
    # karşılığı BİLEREK hesaplanmaz (şirket kuralı, ölçüm değil).
    hafta_sayfa = wb.create_sheet("Haftalık Çalışma Gün Sayısı")
    basliklandir(hafta_sayfa,
                 ["Şube", "Bölüm", "Görev", "Personel", "SicilNo", "Hafta",
                  "Çalışılan Gün", "Hafta Tatili (HFT.İZİN) Gün",
                  "HAFTA TATİLİ KULLANILMADI", "Net Çalışma (hafta)"],
                 [16, 18, 24, 24, 13, 8, 13, 16, 16, 16])

    kisi_hafta: dict[tuple, list] = {}
    for s in satirlar:
        h = dt.datetime.strptime(s[6], "%d.%m.%Y").date().isocalendar()[1]
        kisi_hafta.setdefault((s[1], h), [s[0], s[4], s[5], s[3], s[1], h])
    for i, anahtar in enumerate(sorted(kisi_hafta, key=lambda k: (kisi_hafta[k][0],
                                                                 kisi_hafta[k][3], k[1])), start=2):
        hafta_sayfa.append(kisi_hafta[anahtar] + [
            f"=SUMIFS({rng('AD')},{rng('B')},$E{i},{rng('AE')},$F{i})",
            f'=COUNTIFS({rng("B")},$E{i},{rng("AE")},$F{i},{rng("H")},"HFT.İZİN")',
            f"=IF(AND(H{i}=0,G{i}>=7),1,0)",
            f"=SUMIFS({rng('Z')},{rng('B')},$E{i},{rng('AE')},$F{i})",
        ])
        hafta_sayfa.cell(i, 10).number_format = "[h]:mm"
    hs_son = len(kisi_hafta) + 1

    # ── 2. YÖNETİCİ ÖZETİ (kişi bazında, eksik/fazla NETLEŞTİRİLMİŞ) ─────────
    # F/G netleştirme mantığı orijinal dosyadan birebir: =IF(D>E,D-E,0) / =IF(E>D,E-D,0)
    ozet = wb.create_sheet("Yönetici Özeti")
    basliklandir(ozet,
                 ["Şube", "Bölüm", "Görev", "Personel", "SicilNo",
                  "Toplam EksikSaat", "Toplam FazlaSaat", "NET Eksik", "NET Fazla",
                  "Hafta Tatilsiz Hafta", "Çalışılan Gün", "Devamsız Gün"],
                 [16, 18, 24, 24, 13, 15, 15, 13, 13, 16, 13, 13])

    kisi: dict[str, list] = {}
    for s in satirlar:
        kisi.setdefault(s[1], [s[0], s[4], s[5], s[3], s[1]])
    for i, tc in enumerate(sorted(kisi, key=lambda t: (kisi[t][0], kisi[t][3])), start=2):
        ozet.append(kisi[tc] + [
            f"=SUMIFS({rng('AB')},{rng('B')},$E{i})",
            f"=SUMIFS({rng('AC')},{rng('B')},$E{i})",
            f"=IF(F{i}>G{i},F{i}-G{i},0)",
            f"=IF(G{i}>F{i},G{i}-F{i},0)",
            f"=SUMIFS('Haftalık Çalışma Gün Sayısı'!$I$2:$I${hs_son},"
            f"'Haftalık Çalışma Gün Sayısı'!$E$2:$E${hs_son},$E{i})",
            f"=SUMIFS({rng('AD')},{rng('B')},$E{i})",
            f'=COUNTIFS({rng("B")},$E{i},{rng("O")},"Devamsız")',
        ])
        for c in (6, 7, 8, 9):
            ozet.cell(i, c).number_format = "[h]:mm"

    # ── 3. GÜNLÜK EKSİK VE FAZLA (kişi × gün matrisi) ────────────────────────
    # Orijinalin düzeni birebir: her gün İKİ kolon (Eksik | Fazla), tarih ikisinin
    # de üstünde tekrar eder. Orijinal pivot; bu SUMIFS — T/U girilince canlı.
    # ⚠ Kişi eşleşmesi SicilNo ile; tarih ölçütü ana sayfadaki METİN tarihle
    #   (dd.MM.yyyy) eşleşir — başlık hücresi doğrudan ölçüt olarak kullanılır,
    #   böylece formülde gizli literal kalmaz.
    gunluk = wb.create_sheet("Günlük Eksik ve Fazla")
    gunler = sorted({s[6] for s in satirlar},
                    key=lambda t: dt.datetime.strptime(t, "%d.%m.%Y"))

    sabit = ["Şube", "Bölüm", "Görev", "Personel", "SicilNo"]
    for c, ad in enumerate(sabit, start=1):
        gunluk.cell(2, c).value = ad
    for j, gun in enumerate(gunler):
        c = len(sabit) + 1 + j * 2
        gunluk.cell(1, c).value = gun            # tarih ÇİFT kolonda da yazılı
        gunluk.cell(1, c + 1).value = gun        # (orijinal düzen)
        gunluk.cell(2, c).value = "Toplam EksikSaat"
        gunluk.cell(2, c + 1).value = "Toplam FazlaSaat"
    tc_eksik = len(sabit) + 1 + len(gunler) * 2
    gunluk.cell(2, tc_eksik).value = "TOPLAM Eksik"
    gunluk.cell(2, tc_eksik + 1).value = "TOPLAM Fazla"

    for c in range(1, tc_eksik + 2):
        for r in (1, 2):
            h = gunluk.cell(r, c)
            h.font, h.fill = baslik_font, baslik_dolgu
            h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    gunluk.freeze_panes = "F3"
    for c, w in enumerate([16, 18, 22, 22, 13], start=1):
        gunluk.column_dimensions[get_column_letter(c)].width = w
    for c in range(6, tc_eksik + 2):
        gunluk.column_dimensions[get_column_letter(c)].width = 11

    for i, tc in enumerate(sorted(kisi, key=lambda t: (kisi[t][0], kisi[t][3])), start=3):
        for c, v in enumerate(kisi[tc], start=1):
            gunluk.cell(i, c).value = v
        for j in range(len(gunler)):
            c = len(sabit) + 1 + j * 2
            gl = get_column_letter(c)
            for k, kol in enumerate(("AB", "AC")):
                h = gunluk.cell(i, c + k)
                h.value = (f"=SUMIFS({rng(kol)},{rng('B')},$E{i},"
                           f"{rng('G')},{gl}$1)")
                h.number_format = "[h]:mm"
        for k, kol in enumerate(("AB", "AC")):
            h = gunluk.cell(i, tc_eksik + k)
            h.value = f"=SUMIFS({rng(kol)},{rng('B')},$E{i})"
            h.number_format = "[h]:mm"
            h.font = Font(bold=True)


# =============================================================================
# DOĞRULAMA — üretilen A..O, orijinal FSM dosyasıyla hücre hücre karşılaştırılır
# =============================================================================
def dogrula(satirlar: list[list], kaynak: str) -> int:
    import openpyxl
    wb = openpyxl.load_workbook(kaynak, data_only=True)
    ws = wb["Vardiya Yönet Program Raporu"]

    bizim = {(s[1], s[6]): s for s in satirlar}
    fark = 0
    kontrol = 0
    yok = 0
    for r in range(2, ws.max_row + 1):
        tc = str(ws.cell(r, 2).value or "").strip()
        tarih = str(ws.cell(r, 7).value or "").strip()
        if not tc or "Devir" in tarih:
            continue
        b = bizim.get((tc, tarih))
        if b is None:
            yok += 1
            continue
        kontrol += 1
        for c, ad in ((8, "Vardiya Tanım"), (9, "Personel Giriş"), (10, "Personel Çıkış"),
                      (11, "PDKS Giriş"), (12, "PDKS Çıkış"), (13, "Personel Çalışma"),
                      (14, "Plan Çalışma"), (15, "Durum"), (3, "PDKS No")):
            o = ws.cell(r, c).value
            y = b[c - 1]
            if isinstance(o, dt.timedelta):
                o = f"{int(o.total_seconds()) // 3600:02d}:{int(o.total_seconds()) % 3600 // 60:02d}"
            if isinstance(o, (int, float)) and c == 3:
                o = int(o)
            if isinstance(y, (int, float)) and c == 3:
                y = int(y)
            o = None if o in ("", None) else o
            y = None if y in ("", None) else y
            if o != y:
                fark += 1
                if fark <= 25:
                    print(f"  FARK satır{r} {ad}: dosya={o!r} bizim={y!r}  ({b[3]} {tarih})")
    print(f"\nDOĞRULAMA: {kontrol} satır karşılaştırıldı · {fark} hücre farkı · "
          f"{yok} satır bizde yok")
    return fark


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sube", default="TUMU",
                    help="Şube adı (BKM.vrd.SubeListe.SubeAd) veya TUMU = tüm şubeler tek dosyada")
    ap.add_argument("--bas", default="31.08.2026", help="Başlangıç (dd.MM.yyyy)")
    ap.add_argument("--bit", default="13.09.2026", help="Bitiş (dd.MM.yyyy)")
    ap.add_argument("--cikti", default=None)
    ap.add_argument("--dogrula", default=None, help="Karşılaştırılacak orijinal xlsx")
    a = ap.parse_args()

    bas = dt.datetime.strptime(a.bas, "%d.%m.%Y").date()
    bit = dt.datetime.strptime(a.bit, "%d.%m.%Y").date()
    print(f"KAPSAM: {a.sube} · {bas:%d.%m.%Y} – {bit:%d.%m.%Y}")

    cn = baglan(env_oku(os.path.join(KOK, ".env")))
    try:
        cur = cn.cursor()
        print("  Olması gereken net çalışma (plandan ÖLÇÜLDÜ, elle yazılmadı):")
        net_gereken = net_gereken_olc(cur, bas, bit)
        cur.close()

        if a.sube.upper() in ("TUMU", "TÜMÜ", "HEPSI", "HEPSİ"):
            subeler = sorted(net_gereken)
        else:
            subeler = [a.sube]

        satirlar: list[list] = []
        for sb in subeler:
            print(f"-- {sb} --")
            satirlar += veri_cek(cn, sb, bas, bit)
    finally:
        cn.close()
    print(f"TOPLAM satır: {len(satirlar)} · {len(subeler)} şube")

    if a.dogrula:
        return 1 if dogrula(satirlar, a.dogrula) else 0

    satirlar.sort(key=lambda s: (str(s[0] or ""),
                                 dt.datetime.strptime(s[6], "%d.%m.%Y"), str(s[3] or "")))
    ad = "TUM_SUBELER" if len(subeler) > 1 else subeler[0].replace(" ", "_")
    cikti = a.cikti or os.path.join(
        KOK, "ciktilar", f"{ad}_Vardiya_PDKS_{bas:%Y%m%d}_{bit:%Y%m%d}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    excel_yaz(satirlar, cikti, {k: v for k, v in net_gereken.items() if k in subeler})
    print(f"\nYAZILDI: {cikti}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
