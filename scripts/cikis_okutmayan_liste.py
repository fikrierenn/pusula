# -*- coding: utf-8 -*-
"""ÇIKIŞTA KART OKUTMAYAN PERSONEL — mağaza bazlı liste.

GMY isteği 16.09.2026: "mağaza bazlı giriş yapıp çıkışta kart okutmayan
personel listesi".

⚠⚠ KAYNAK SEÇİMİ SONUCU BELİRLİYOR — ÖLÇÜLDÜ (2026-09-16):

  `TTagZei` (İŞLENMİŞ günlük kayıt) ile bakılırsa cevap **SIFIR** çıkıyor:
  17.08–15.09 arasında beş mağazada "girişi var, çıkışı yok" kişi-gün sayısı
  TAM 0. Çünkü TTagZei işlenmiş tablodur ve eksik çıkışı KAPATIR (gün sonu
  otomatik kapanış / İK düzeltmesi). Yani orada bakan "kimse çıkışını
  okutmuyor değil" sonucuna varır ve YANILIR.

  `TZeiBuf` (HAM kart okutma) ile bakılırsa gerçek görünür: kişi-gün başına
  okutma sayısı TEK ise ikinci okutma (çıkış) hiç yapılmamıştır.
  Ölçüm: ortalama okutma 1,95–1,98 (yani normal gün = 2 okutma: giriş + çıkış;
  mola için ayrıca basılmıyor), tek-okutmalı kişi-gün 161.

  ⇒ Bu rapor HAM okutmadan (TZeiBuf) üretilir. TTagZei'den üretilemez.

⚠ "Çıkış okutmadı" ≠ "kaçtı". Meşru sebepler: terminal arızası, kart
  unutma, mesai sonrası başka kapıdan çıkma, yönetici izniyle erken çıkış.
  Liste bir DAVRANIŞ ÖLÇÜMÜDÜR, disiplin kararı değildir.

⚠ MÜDÜR / MÜDÜR YRD. RAPORA GİRMEZ (GMY kararı 16.09.2026: "müd md yrd
  gelmesin gerek yok"). Bu kadro kart basmıyor; her gün "okutmadı" satırı
  üretip listeyi gürültüye boğuyordu. Süzgeç `vd.Gorev NOT LIKE '%MÜDÜR%'`
  ve hem listeye hem ÖZETTEKİ "gereken" sayısına uygulanır — yalnız listeden
  çıkarsaydı "gelmeyen" sayısı olduğundan yüksek kalırdı.
  Ölçüldü: mağazalarda bu desene uyan tam iki ünvan var — MAĞAZA MÜDÜRÜ (4
  kişi) ve MAĞAZA MÜDÜR YRD. (7 kişi); başka görev yanlışlıkla elenmiyor.

⚠ `ZBu_Storniert` (iptal edilmiş okutma) hariç tutulur.
⚠ `ZBu_Benutzer` BKM'de HEP NULL (sema: pdks_kart_okutma) — yani elle
  girilmiş sahte okutma yok, ham veri temiz.

Kullanım:
    python scripts/cikis_okutmayan_liste.py [--bas 17.08.2026] [--bit 15.09.2026]
"""
from __future__ import annotations

import argparse
import collections
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
KIRMIZI = PatternFill("solid", fgColor="E30622")
BASLIK_YAZI = Font(bold=True, color="FFFFFF", size=10)
GUN_AD = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]


def env_oku(yol: str) -> dict[str, str]:
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
        "TrustServerCertificate=yes;Timeout=30", timeout=30)
    cn.timeout = 900
    return cn


# HAM OKUTMA — kişi × gün × okutma sayısı + o günün tek okutma saati.
# Okutma sayısı 1 → çıkış hiç basılmamış.
SQL_HAM = """
SELECT  x.Sube COLLATE Turkish_CI_AS AS Sube, x.Sicil,
        x.Personel COLLATE Turkish_CI_AS AS Personel,
        x.Bolum COLLATE Turkish_CI_AS AS Bolum,
        x.Gorev COLLATE Turkish_CI_AS AS Gorev,
        x.Gun, x.Okutma, x.IlkOkutma, x.SonOkutma
FROM OPENQUERY([PDKS], '
    SELECT  LTRIM(RTRIM(p.Per_Grp2))                                  AS Sube,
            p.Per_PersNr                                              AS Sicil,
            LTRIM(RTRIM(p.Per_Vorname)) + '' '' + LTRIM(RTRIM(p.Per_Name)) AS Personel,
            LTRIM(RTRIM(p.Per_Grp3))                                  AS Bolum,
            LTRIM(RTRIM(p.Per_Grp4))                                  AS Gorev,
            CONVERT(char(8), b.ZBu_ErfDatum, 112)                     AS Gun,
            COUNT(*)                                                  AS Okutma,
            CONVERT(char(5), MIN(b.ZBu_ErfZeit), 108)                 AS IlkOkutma,
            CONVERT(char(5), MAX(b.ZBu_ErfZeit), 108)                 AS SonOkutma
    FROM        TZeiBuf b
    INNER JOIN  TPerTab p ON p.Per_PersNr = b.ZBu_PersNr
    WHERE   b.ZBu_ErfDatum >= ''{bas}'' AND b.ZBu_ErfDatum <= ''{bit}''
        AND ISNULL(b.ZBu_Storniert, 0) = 0
        AND LTRIM(RTRIM(p.Per_Grp1)) = ''MAĞAZALAR''
    GROUP BY LTRIM(RTRIM(p.Per_Grp2)), p.Per_PersNr, p.Per_Vorname, p.Per_Name,
             LTRIM(RTRIM(p.Per_Grp3)), LTRIM(RTRIM(p.Per_Grp4)),
             CONVERT(char(8), b.ZBu_ErfDatum, 112)
') x
"""


# PLAN — kişi-gün vardiya tanımı. Köprü: PDKS PersNr → TPerInd.PIn_SteuerNr (TC)
# → BKM.vrd.VardiyaDetay.SicilNo. Geniş biçim (Pazartesi..Pazar) UNPIVOT edilir.
# ⚠ Köprü kapsamı sınırlı (sema: TPerInd.kapsam_sinirlamasi). Vardiyası
#   bulunamayan satır "—" kalır ve sayısı raporlanır — "vardiyası yok" DEĞİL,
#   "eşleşmedi" demektir.
SQL_PLAN = """
SELECT  i.PersNr,
        CONVERT(char(8), DATEADD(day, g.ofs, v.Tarih), 112) AS Gun,
        vz.Aciklama                       AS VardiyaTanim,
        CONVERT(char(5), vz.Baslama, 108) AS PlanBas,
        CONVERT(char(5), vz.Bitis, 108)   AS PlanBit,
        vz.Izin
FROM        BKM.vrd.Vardiya       v
INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
CROSS APPLY (VALUES (0, vd.Pazartesi), (1, vd.Sali), (2, vd.Carsamba),
                    (3, vd.Persembe), (4, vd.Cuma), (5, vd.Cumartesi),
                    (6, vd.Pazar)) AS g(ofs, VardiyaId)
INNER JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
INNER JOIN  (SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.PersNr
             FROM OPENQUERY([PDKS], '
                 SELECT PIn_SteuerNr AS TC, MIN(PIn_PersNr) AS PersNr
                 FROM TPerInd
                 WHERE PIn_SteuerNr <> ''''
                 GROUP BY PIn_SteuerNr') x) i
        ON i.TC = LTRIM(RTRIM(vd.SicilNo)) COLLATE Turkish_CI_AS
WHERE   g.VardiyaId <> 0
    AND DATEADD(day, g.ofs, v.Tarih) >= ? AND DATEADD(day, g.ofs, v.Tarih) <= ?
"""


# ÖZET — vardiyada olması gereken (plan) × kart basan (fiili), şube bazlı.
# ⚠ Şube adı iki sistemde FARKLI yazılıyor ("İST. YOLU" ↔ "İST.YOLU"). Eşleme
#   ELLE YAZILMAZ: PDKS `bkm.SubeListe` hem SubeAd hem Per_Grp2 taşır, oradan
#   canlı okunur (bridges:pdks-sube-bolum).
# ⚠ Kapsam MAĞAZALAR — kafeler ve Genel Müdürlük bu raporun dışında.
SQL_OZET_PLAN = """
SELECT  m.Grp2 COLLATE Turkish_CI_AS AS Sube,
        CONVERT(char(8), DATEADD(day, g.ofs, v.Tarih), 112) AS Gun,
        COUNT(*)                                        AS PlanliKisi,
        SUM(CASE WHEN vz.Izin = 1 THEN 1 ELSE 0 END)    AS Izinli,
        SUM(CASE WHEN vz.Izin = 0 THEN 1 ELSE 0 END)    AS Gereken
FROM        BKM.vrd.Vardiya       v
INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo     = v.SubeNo
INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
CROSS APPLY (VALUES (0, vd.Pazartesi), (1, vd.Sali), (2, vd.Carsamba),
                    (3, vd.Persembe), (4, vd.Cuma), (5, vd.Cumartesi),
                    (6, vd.Pazar)) AS g(ofs, VardiyaId)
INNER JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
INNER JOIN  (SELECT x.SubeAd COLLATE Turkish_CI_AS AS SubeAd,
                    x.Per_Grp2 COLLATE Turkish_CI_AS AS Grp2
             FROM OPENQUERY([PDKS], '
                 SELECT DISTINCT SubeAd, Per_Grp2
                 FROM bkm.SubeListe
                 WHERE LTRIM(RTRIM(Per_Grp1)) = ''MAĞAZALAR''
                   AND Per_Grp2 IS NOT NULL') x) m
        ON m.SubeAd = s.SubeAd COLLATE Turkish_CI_AS
WHERE   g.VardiyaId <> 0
    AND DATEADD(day, g.ofs, v.Tarih) >= ? AND DATEADD(day, g.ofs, v.Tarih) <= ?
    AND vd.Gorev NOT LIKE '%MÜDÜR%'      -- GMY 16.09: müdür/müdür yrd. RAPORA GİRMEZ
-- Grain ŞUBE × GÜN. Şube toplamı Python'da bu satırlardan toplanır (aditif) —
-- iki ayrı sorgu yazılmaz, tek çekirdek (emitter-ayrimi.md).
GROUP BY m.Grp2, DATEADD(day, g.ofs, v.Tarih)
"""


# VARDİYADA OLUP HİÇ OKUTMA YAPMAYAN — GMY 16.09: "vardiyada olup hiç kart
# okutmayan da var sanki". Doğru, ve ÖLÇÜLÜNCE İKİ AYRI ŞEY ÇIKTI:
#   · `Son30Okutma` NULL  → kişinin TC'si PDKS'te YOK / 30 günde sıfır okutma.
#     15.09'da bu 12 kişiydi ve 11'i MAĞAZA MÜDÜRÜ / MÜDÜR YRD. — yönetici
#     kadrosu kart basmıyor. Bunlar DEVAMSIZ DEĞİL, ÖLÇÜLEMEYEN kadrodur.
#   · `Son30Okutma` > 0   → normalde kart basıyor ama o gün basmamış (17 kişi).
#     Gerçek "gelmedi" adayı budur.
# İkisini tek "gelmeyen" sayısında toplamak yanıltıcıdır; ayrı raporlanır.
SQL_GELMEYEN = """
SELECT  m.Grp2 COLLATE Turkish_CI_AS   AS Sube,
        LTRIM(RTRIM(vd.SicilNo)) COLLATE Turkish_CI_AS AS TC,
        vd.Personel COLLATE Turkish_CI_AS AS Personel,
        vd.Gorev COLLATE Turkish_CI_AS AS Gorev,
        vz.Aciklama COLLATE Turkish_CI_AS AS VardiyaTanim,
        CONVERT(char(8), DATEADD(day, g.ofs, v.Tarih), 112) AS Gun,
        o.OkutmaGunu                   AS Son30Okutma
FROM        BKM.vrd.Vardiya       v
INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo     = v.SubeNo
INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
CROSS APPLY (VALUES (0, vd.Pazartesi), (1, vd.Sali), (2, vd.Carsamba),
                    (3, vd.Persembe), (4, vd.Cuma), (5, vd.Cumartesi),
                    (6, vd.Pazar)) AS g(ofs, VardiyaId)
INNER JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
INNER JOIN  (SELECT x.SubeAd COLLATE Turkish_CI_AS AS SubeAd,
                    x.Per_Grp2 COLLATE Turkish_CI_AS AS Grp2
             FROM OPENQUERY([PDKS], '
                 SELECT DISTINCT SubeAd, Per_Grp2 FROM bkm.SubeListe
                 WHERE LTRIM(RTRIM(Per_Grp1)) = ''MAĞAZALAR''
                   AND Per_Grp2 IS NOT NULL') x) m
        ON m.SubeAd = s.SubeAd COLLATE Turkish_CI_AS
LEFT  JOIN  (SELECT y.TC COLLATE Turkish_CI_AS AS TC, y.Gun
             FROM OPENQUERY([PDKS], '
                 SELECT DISTINCT i.PIn_SteuerNr AS TC,
                        CONVERT(char(8), b.ZBu_ErfDatum, 112) AS Gun
                 FROM TZeiBuf b
                 INNER JOIN TPerInd i ON i.PIn_PersNr = b.ZBu_PersNr
                 WHERE b.ZBu_ErfDatum >= ''{bas}'' AND b.ZBu_ErfDatum <= ''{bit}''
                   AND ISNULL(b.ZBu_Storniert, 0) = 0
                   AND i.PIn_SteuerNr <> ''''') y) gun_okutma
        ON gun_okutma.TC = LTRIM(RTRIM(vd.SicilNo)) COLLATE Turkish_CI_AS
       AND gun_okutma.Gun = CONVERT(char(8), DATEADD(day, g.ofs, v.Tarih), 112)
LEFT  JOIN  (SELECT z.TC COLLATE Turkish_CI_AS AS TC, z.OkutmaGunu
             FROM OPENQUERY([PDKS], '
                 SELECT i.PIn_SteuerNr AS TC,
                        COUNT(DISTINCT b.ZBu_ErfDatum) AS OkutmaGunu
                 FROM TZeiBuf b
                 INNER JOIN TPerInd i ON i.PIn_PersNr = b.ZBu_PersNr
                 WHERE b.ZBu_ErfDatum >= ''{ref}'' AND b.ZBu_ErfDatum <= ''{bit}''
                   AND ISNULL(b.ZBu_Storniert, 0) = 0
                   AND i.PIn_SteuerNr <> ''''
                 GROUP BY i.PIn_SteuerNr') z) o
        ON o.TC = LTRIM(RTRIM(vd.SicilNo)) COLLATE Turkish_CI_AS
WHERE   g.VardiyaId <> 0 AND vz.Izin = 0
    AND DATEADD(day, g.ofs, v.Tarih) >= ? AND DATEADD(day, g.ofs, v.Tarih) <= ?
    AND gun_okutma.TC IS NULL
    AND vd.Gorev NOT LIKE '%MÜDÜR%'      -- GMY 16.09: müdür/müdür yrd. RAPORA GİRMEZ
"""


# ZİRVE BORDRO — "bu kişi hâlâ çalışıyor mu?" (GMY isteği 16.09.2026)
# ⚠ AYRI SUNUCU: BKM_GENEL @ ZIRVE_HOST. ERP'den linked server YOK, ayrı
#   pyodbc bağlantısı açılır (sema: zirve köprüleri not_measurable).
# ⭐ KÖPRÜ: `vw_PersonelDepartman.Vatno` = TC KİMLİK = `vrd.VardiyaDetay.SicilNo`.
#   Doğrudan bağlanır; ad-soyad eşleştirmesine GEREK YOK (o yol mükerrer isimde
#   yanılır — "MERT SARGIN" Zirve'de 6 ayrı Personelno taşıyor).
# ⚠ `Ict` = işten çıkış tarihi. NULL → çalışıyor. Dolu → ayrılmış.
# ⚠ `perbilgi.Personelno` int ama `vw_PuanBil.Personelno` varchar ve firma ekli
#   ('889-BKM'). O view'a Personelno filtresi verilemiyor (içeride int'e çevirme
#   patlıyor); bu rapor `vw_PersonelDepartman` kullandığı için o tuzağa girmez.
SQL_ZIRVE = """
SELECT  LTRIM(RTRIM(Vatno))   AS TC,
        AdSoyad, Lokasyon, Unvan, Kadro,
        CONVERT(varchar(10), Igt, 104) AS IseGiris,
        CONVERT(varchar(10), Ict, 104) AS Cikis
FROM    dbo.vw_PersonelDepartman
WHERE   Vatno IS NOT NULL AND LTRIM(RTRIM(Vatno)) <> ''
"""


def zirve_baglan(env: dict[str, str]):
    """Zirve (bordro) bağlantısı. Kimlik .env'de; yoksa None döner ve rapor
    Zirve kolonları olmadan üretilir — sessizce boş geçmez, uyarı basar."""
    host = env.get("ZIRVE_HOST")
    if not host or not env.get("ZIRVE_USER"):
        return None
    if not re.fullmatch(r"[A-Za-z0-9._\\\-]+", host):
        print("  ⚠ ZIRVE_HOST beklenmedik biçimde — Zirve atlandı.")
        return None
    try:
        cn = pyodbc.connect(
            "Driver={ODBC Driver 18 for SQL Server};"
            f"Server={host};Database={env.get('ZIRVE_DATABASE', 'BKM_GENEL')};"
            f"UID={env['ZIRVE_USER']};PWD={env['ZIRVE_PASSWORD']};"
            "TrustServerCertificate=yes;Timeout=30", timeout=30)
        cn.timeout = 300
        return cn
    except Exception as e:
        print(f"  ⚠ Zirve'ye bağlanılamadı ({type(e).__name__}) — Zirve kolonları boş.")
        return None


def ayrilmis_mi(cikis, gun) -> bool:
    """O GÜN itibarıyla işten ayrılmış mı? (bordro çıkış tarihi < o gün)

    Çıkış tarihinin VARLIĞINA bakmak yetmez: 20.09'da ayrılan biri 16.09
    raporunda hâlâ çalışıyordu. Kıyas tabanı (geçmiş 14 gün) ile bugünün
    sayısı AYNI ölçütle kurulmalı, yoksa taban şişer ve kapı körelir.
    """
    if not cikis:
        return False
    try:
        c = dt.datetime.strptime(str(cikis).strip(), "%d.%m.%Y").date()
        g = dt.datetime.strptime(str(gun), "%Y%m%d").date()
    except (ValueError, TypeError):
        return bool(cikis)      # tarih okunamadıysa eski davranış (muhafazakâr)
    return c < g


def dk(hhmm) -> int | None:
    """'HH:MM' → gün içi dakika."""
    if not hhmm:
        return None
    t = str(hhmm).strip()
    if ":" not in t:
        return None
    h, m = t.split(":")[:2]
    return int(h) * 60 + int(m)


def onceki_is_gunu(bugun: dt.date) -> tuple[dt.date, dt.date]:
    """Günlük rutin penceresi — HİÇBİR GÜN ATLANMAZ.

    Salı–Cuma koşumu  → yalnız dün.
    Pazartesi koşumu  → Cuma + Cumartesi + Pazar (3 gün), yoksa hafta sonu kaybolur.
    Hafta sonu koşumu → yine dün (rutin hafta içi ama elle koşulabilir).
    """
    if bugun.weekday() == 0:                       # Pazartesi
        return bugun - dt.timedelta(days=3), bugun - dt.timedelta(days=1)
    return bugun - dt.timedelta(days=1), bugun - dt.timedelta(days=1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bas", default="17.08.2026")
    ap.add_argument("--bit", default="15.09.2026")
    ap.add_argument("--cikti", default=None)
    ap.add_argument("--gunluk", action="store_true",
                    help="Günlük rutin: önceki iş günü/günleri (Pazartesi 3 gün)")
    ap.add_argument("--html", default=None, help="Mail gövdesi HTML dosyası yolu")
    a = ap.parse_args()
    if a.gunluk:
        bas, bit = onceki_is_gunu(dt.date.today())
    else:
        bas = dt.datetime.strptime(a.bas, "%d.%m.%Y").date()
        bit = dt.datetime.strptime(a.bit, "%d.%m.%Y").date()
    print(f"ÇIKIŞ OKUTMAYAN · {bas:%d.%m.%Y} – {bit:%d.%m.%Y}")

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        cur = cn.cursor()
        cur.execute(SQL_HAM.format(bas=bas.strftime("%Y%m%d"), bit=bit.strftime("%Y%m%d")))
        kol = [c[0] for c in cur.description]
        satir = [dict(zip(kol, r)) for r in cur.fetchall()]

        cur.execute(SQL_PLAN, bas, bit)
        kolp = [c[0] for c in cur.description]
        plan: dict[tuple, dict] = {}
        for r in cur.fetchall():
            d = dict(zip(kolp, r))
            plan[(int(d["PersNr"]), str(d["Gun"]))] = d

        cur.execute(SQL_GELMEYEN.format(bas=bas.strftime("%Y%m%d"),
                                        bit=bit.strftime("%Y%m%d"),
                                        ref=(bas - dt.timedelta(days=29)).strftime("%Y%m%d")),
                    bas, bit)
        kolg = [c[0] for c in cur.description]
        gelmeyenler = [dict(zip(kolg, r)) for r in cur.fetchall()]

        cur.execute(SQL_OZET_PLAN, bas, bit)
        kolo = [c[0] for c in cur.description]
        plan_gun = [dict(zip(kolo, r)) for r in cur.fetchall()]
        # Sorgu grain'i ŞUBE × GÜN; şube özeti buradan TOPLANIR (ikinci sorgu yok).
        ozet_plan: dict[str, dict] = {}
        for d in plan_gun:
            sb = str(d["Sube"]).strip()
            t = ozet_plan.setdefault(sb, {"Sube": sb, "PlanliKisi": 0,
                                          "Izinli": 0, "Gereken": 0})
            for k in ("PlanliKisi", "Izinli", "Gereken"):
                t[k] += int(d[k] or 0)
        cur.close()
    finally:
        cn.close()

    # ── ZİRVE: kişi hâlâ çalışıyor mu? ──
    zirve: dict[str, dict] = {}
    zcn = zirve_baglan(env)
    if zcn is not None:
        try:
            zc = zcn.cursor()
            zc.execute(SQL_ZIRVE)
            kz = [c[0] for c in zc.description]
            # ⚠ MÜKERRER KAYIT: aynı TC Zirve'de birden çok satır taşıyabilir
            #   (yeniden işe giriş — "MERT SARGIN" 6 kayıt). Son satırı almak
            #   YANLIŞ: eski ÇIKIŞLI kayıt kazanırsa kişi "ayrılmış" görünür
            #   ama 25 gün kart basmış olur (ölçüldü 16.09, bu tuzağa düşüldü).
            #   Kural: ÇIKIŞI OLMAYAN kayıt öncelikli; hepsi çıkışlıysa EN SON
            #   işe giriş tarihli seçilir.
            for r in zc.fetchall():
                d = dict(zip(kz, r))
                tc = str(d["TC"]).strip()
                onceki = zirve.get(tc)
                if onceki is None:
                    zirve[tc] = d
                    continue
                if not d["Cikis"] and onceki["Cikis"]:
                    zirve[tc] = d
                elif bool(d["Cikis"]) == bool(onceki["Cikis"]):
                    def _g(x):
                        try:
                            return dt.datetime.strptime(str(x or "01.01.1900"),
                                                        "%d.%m.%Y")
                        except ValueError:
                            return dt.datetime(1900, 1, 1)
                    if _g(d["IseGiris"]) > _g(onceki["IseGiris"]):
                        zirve[tc] = d
            zc.close()
        finally:
            zcn.close()
        print(f"  Zirve kaydı      : {len(zirve)} kişi (TC ile)")

    if not satir:
        sys.exit("KOŞAMADI: ham okutma BOŞ döndü — dönem gerçekten boş mu, "
                 "yoksa linked server mı düştü?")

    tekil = [s for s in satir if int(s["Okutma"]) == 1]

    # ── TEK OKUTMA GİRİŞ Mİ ÇIKIŞ MI? ────────────────────────────────────────
    # GMY "giriş yapıp çıkışta okutmayan" dedi ama tek okutma TERSİ de olabilir:
    # sabah basmayı unutup akşam basan. Plan saatiyle kıyaslayarak ayrılır:
    # okutma plana YAKIN ucu hangisiyse o basılmış demektir.
    # Vardiya eşleşmeyen satır "—" kalır; UYDURULMAZ.
    for s in tekil:
        p = plan.get((int(s["Sicil"]), str(s["Gun"])))
        s["VardiyaTanim"] = p["VardiyaTanim"] if p else None
        s["PlanBas"] = p["PlanBas"] if p else None
        s["PlanBit"] = p["PlanBit"] if p else None
        s["Izin"] = (p and p["Izin"]) and 1 or 0
        o, pb, pt = dk(s["IlkOkutma"]), dk(s["PlanBas"] if p else None), dk(s["PlanBit"] if p else None)
        if p is None:
            s["Tip"] = "— (vardiya eşleşmedi)"
            s["Sapma"] = None
        elif p["Izin"]:
            s["Tip"] = "İZİN günü okutma"
            s["Sapma"] = None
        elif o is None or pb is None or pt is None:
            s["Tip"] = "— (plan saati yok)"
            s["Sapma"] = None
        elif abs(o - pb) <= abs(o - pt):
            s["Tip"] = "ÇIKIŞ okutulmamış"
            s["Sapma"] = o - pb            # + geç geldi, − erken geldi
        else:
            s["Tip"] = "GİRİŞ okutulmamış"
            s["Sapma"] = o - pt            # + geç çıktı, − erken çıktı
    # ── ÖZET: vardiya tanımında olup gelmeyen ───────────────────────────────
    # "Gereken" = plana vardiya yazılmış ve İZİN OLMAYAN kişi-gün.
    # "Gelen"   = o gün en az bir kart okutması olan kişi-gün (ham okutma).
    # ⚠ "Gelmeyen" DEVAMSIZ DEMEK DEĞİL: kart basmayan kadro (yönetici, bazı
    #   görevler) ve TC'si PDKS'e girilmemiş personel de buraya düşer.
    gelen = collections.Counter()
    for x in satir:
        gelen[str(x["Sube"]).strip()] += 1
    ozet_satir = []
    for sb in sorted(set(ozet_plan) | set(gelen)):
        pl = ozet_plan.get(sb)
        ger = int(pl["Gereken"]) if pl else None
        izn = int(pl["Izinli"]) if pl else None
        gl = gelen.get(sb, 0)
        ozet_satir.append({
            "Sube": sb, "Gereken": ger, "Izinli": izn, "Gelen": gl,
            # ⚠ "Gelmeyen" ÇIKARMA İLE HESAPLANMAZ. `Gereken` plan tarafından,
            #   `Gelen` PDKS tarafından gelir ve NÜFUSLARI AYNI DEĞİLDİR: planı
            #   olmadığı hâlde kart basan kişi (yeni giren, plansız çalışan)
            #   "gelen"e girer ama "gereken"de yoktur. Çıkarma yapılınca ŞURA'da
            #   -1 çıktı (ölçüldü 16.09) — negatif "gelmeyen" saçmadır.
            #   Doğrusu: plan var + o gün okutma yok satırlarını SAYMAK.
            "Gelmeyen": 0,             # aşağıda gelmeyenler listesinden doldurulur
            "EksikOkutma": 0,
        })

    tip_say = collections.Counter(s["Tip"] for s in tekil)
    print("  tek okutma kırılımı:")
    for t, n in tip_say.most_common():
        print(f"    {t:26s} {n:3d}")
    print(f"  kişi-gün (ham okutma) : {len(satir)}")
    print(f"  tek okutmalı (çıkışsız): {len(tekil)}  (%{len(tekil)/len(satir)*100:.2f})")

    # kişi bazlı özet
    kisi: dict[int, dict] = {}
    for s in satir:
        k = kisi.setdefault(int(s["Sicil"]), {
            "Sube": s["Sube"], "Personel": s["Personel"], "Bolum": s["Bolum"],
            "Gorev": s["Gorev"], "gun": 0, "cikissiz": 0, "tarihler": []})
        k["gun"] += 1
        if int(s["Okutma"]) == 1:
            k["cikissiz"] += 1
            k["tarihler"].append(dt.datetime.strptime(str(s["Gun"]), "%Y%m%d").date())

    liste = sorted([v for v in kisi.values() if v["cikissiz"] > 0],
                   key=lambda v: (-v["cikissiz"], v["Sube"]))
    print(f"  kişi sayısı            : {len(liste)}")
    print()
    sube = collections.Counter()
    for v in liste:
        sube[v["Sube"]] += v["cikissiz"]
    # ŞUBE ORANI — ham sayı yanıltır (büyük mağazada çok kişi-gün var),
    # kişi-gün tabanına bölünür.
    sube_gun = collections.Counter()
    for x in satir:
        sube_gun[x["Sube"]] += 1
    for o in ozet_satir:
        o["EksikOkutma"] = sube.get(o["Sube"], 0)
    # ── GELMEYENLERİ ÜÇE AYIR (Zirve bordrosuyla) ───────────────────────────
    # Tek "gelmeyen" sayısı üç farklı durumu gizliyordu:
    #   AYRILMIŞ         → Zirve'de çıkış tarihi var; plan temizlenmemiş.
    #   KART BASMIYOR    → çalışıyor ama 30 günde hiç okutması yok (müdür vb).
    #   GELMEDİ          → normalde basıyor, o gün basmamış. Gerçek aday budur.
    # Sınıflandırma ŞUBE ÖZETİNDEN ÖNCE yapılır: "Gelmeyen" kolonu yalnız
    # devamsızlık adaylarını saymalı (17.09.2026 — GMY kararı).
    # ⚠⚠ ZİRVE YOKSA RAPOR ÜRETİLMEZ (22.09.2026 — GMY: "çıkışı yapılanların kart
    #    basmasını bekleme, yoksa yalancı çoban durumuna düşer").
    #    Zirve bağlanamazsa `zirve` boş kalır, `ayrilmis_mi` herkese False döner ve
    #    AYRILMIŞ personel sessizce "GELMEDİ" diye raporlanır — rapor yine de
    #    gider, kimse farkı göremez. Boş nüfus "ihlal yok" değil "bakamadım"dır.
    if not zirve:
        sys.exit("KOŞAMADI: Zirve bordrosu okunamadı — işten ayrılmış personel "
                 "ayıklanamaz, rapor GÜVENİLİR DEĞİL. Mail atılmadı.")

    for x in gelmeyenler:
        tc = str(x.get("TC") or "").strip()
        z = zirve.get(tc)
        x["Unvan"] = z["Unvan"] if z else None
        x["Kadro"] = z["Kadro"] if z else None
        x["Cikis"] = z["Cikis"] if z else None
        son30 = x.get("Son30Okutma")
        if z is None:
            # Bordroda karşılığı yok → çalışıyor mu AYRILMIŞ mı BİLİNMİYOR.
            # "GELMEDİ" demek burada bir ÇIKARIM olurdu; ayrı sınıf, devamsızlık
            # sayısına girmez.
            x["Sinif"] = "BORDRODA BULUNAMADI (teyit gerek)"
        elif ayrilmis_mi(z["Cikis"], x["Gun"]):
            x["Sinif"] = "AYRILMIŞ (plan temizlenmemiş)"
        elif not son30:
            x["Sinif"] = "KART BASMIYOR (30 günde sıfır okutma)"
        else:
            x["Sinif"] = "GELMEDİ (normalde basıyor)"
    sinif_say = collections.Counter(x["Sinif"] for x in gelmeyenler)

    # ── İŞTEN AYRILANLAR DEVRE DIŞI (17.09.2026 — GMY direktifi) ────────────
    # Ayrılmış personel vardiya planında duruyor ve her gün "gelmedi" diye
    # sayılıyordu. Devamsızlık tablosundan ÇIKARILIR — ama SESSİZCE SİLİNMEZ:
    # ayrı bir "plan temizlenmeli" bloğuna düşer. Silinirse plan hiç
    # temizlenmez ve şube sayıları sessizce şişmeye devam eder.
    ayrilmis = [x for x in gelmeyenler if x["Sinif"].startswith("AYRILMIŞ")]
    gelmeyenler = [x for x in gelmeyenler if not x["Sinif"].startswith("AYRILMIŞ")]

    gelmeyen_sube = collections.Counter(
        str(x["Sube"]).strip() for x in gelmeyenler
        if x["Sinif"].startswith("GELMEDİ"))
    for o in ozet_satir:
        o["Gelmeyen"] = gelmeyen_sube.get(o["Sube"], 0)

    # ── ŞUBE × GÜN MATRİSİ (GMY isteği 22.09.2026) ──────────────────────────
    # Çok günlük (telafi) raporda şube özeti günleri topluyordu; ŞURA'da
    # "gereken 28 / kart basan 58" gibi tuhaflıklar hangi günden geldiği
    # görünmediği için okunamıyordu.
    # ⚠ Hücre tanımları ŞUBE ÖZETİYLE AYNI KAYNAKTAN sayılır (ayrı bir tanım
    #   yazılmaz): Gereken = plan_gun · Gelen = ham okutma · Gelmedi = yalnız
    #   "GELMEDİ" sınıfı (ayrılmış ve kart basmayan hariç) · Eksik = tek okutma.
    #   Satır toplamları şube özetiyle birebir tutmalı.
    m_ger = {(str(d["Sube"]).strip(), str(d["Gun"])): int(d["Gereken"] or 0)
             for d in plan_gun}
    m_gelen = collections.Counter(
        (str(x["Sube"]).strip(), str(x["Gun"])) for x in satir)
    m_gelmedi = collections.Counter(
        (str(x["Sube"]).strip(), str(x["Gun"])) for x in gelmeyenler
        if x["Sinif"].startswith("GELMEDİ"))
    m_eksik = collections.Counter(
        (str(s["Sube"]).strip(), str(s["Gun"])) for s in tekil)
    matris_gunler = sorted({g for _, g in
                            set(m_ger) | set(m_gelen) | set(m_gelmedi) | set(m_eksik)})
    matris_subeler = sorted({s for s, _ in
                             set(m_ger) | set(m_gelen) | set(m_gelmedi) | set(m_eksik)})
    matris = {"gunler": matris_gunler, "subeler": matris_subeler,
              "ger": m_ger, "gelen": m_gelen, "gelmedi": m_gelmedi,
              "eksik": m_eksik}

    # ── ÖNLEM: SIRADIŞI GÜN KAPISI (16.09.2026) ─────────────────────────────
    # 15.09'da İST.YOLU'da devamsız 12'ye fırladı (önceki 7 gün 3-5) ve bu
    # rapora BAKAN biri fark edene kadar sessiz kaldı. Kapı: "GELMEDİ" sayısı
    # şubenin kendi son-14-gün bandını aşarsa mail başında UYARI çıkar.
    # ⚠ Eşik veriden türetilir (ortalama + 2 standart sapma), elle yazılmaz;
    #   ve bu bir ALARM değil BAKMA ÇAĞRISIDIR — sebebi rapor bilmez.
    uyarilar: list[str] = []
    try:
        ref_bas = bas - dt.timedelta(days=14)
        cn2 = baglan(env)
        c2 = cn2.cursor()
        c2.execute(SQL_GELMEYEN.format(bas=ref_bas.strftime("%Y%m%d"),
                                       bit=(bas - dt.timedelta(days=1)).strftime("%Y%m%d"),
                                       ref=ref_bas.strftime("%Y%m%d")),
                   ref_bas, bas - dt.timedelta(days=1))
        kk = [c[0] for c in c2.description]
        gecmis = [dict(zip(kk, r)) for r in c2.fetchall()]
        c2.close(); cn2.close()
        # Taban BUGÜNKÜ ÖLÇÜTLE aynı olmalı: "normalde basan" + o gün henüz
        # ayrılmamış. Ayrılmış kişiyi tabanda sayıp bugün saymamak tabanı
        # şişirir ve kapıyı körleştirir (asimetrik kıyas).
        gun_sube = collections.Counter(
            (str(x["Sube"]).strip(), str(x["Gun"])) for x in gecmis
            if x.get("Son30Okutma")
            and not ayrilmis_mi(
                (zirve.get(str(x.get("TC") or "").strip()) or {}).get("Cikis"),
                x["Gun"]))
        import statistics
        for sb in {o["Sube"] for o in ozet_satir}:
            seri = [n for (s2, _), n in gun_sube.items() if s2 == sb]
            bugun = sum(1 for x in gelmeyenler
                        if str(x["Sube"]).strip() == sb and x["Sinif"].startswith("GELMEDİ"))
            if len(seri) >= 5:
                ort = statistics.mean(seri)
                sap = statistics.pstdev(seri) or 1.0
                if bugun > ort + 2 * sap and bugun >= 3:
                    uyarilar.append(
                        f"{sb}: bugün {bugun} kişi gelmemiş — son 14 günün "
                        f"ortalaması {ort:.1f}. Sebebi sorulmalı.")
    except Exception as e:
        uyarilar.append(f"(sıradışı gün kapısı KOŞAMADI: {type(e).__name__} — "
                        f"yeşil sayılmaz, elle bakılmalı)")
    for u in uyarilar:
        print(f"  ⚠ {u}")
    print(f"\n  VARDİYADA OLUP KART OKUTMAYAN: {len(gelmeyenler)} kişi-gün")
    for k, n in sinif_say.most_common():
        if k.startswith("AYRILMIŞ"):
            continue
        print(f"    {k:40s} {n:3d}")
    if ayrilmis:
        kisi_ayr = {str(x["Personel"]) for x in ayrilmis}
        print(f"\n  ⚠ PLAN TEMİZLENMELİ: {len(kisi_ayr)} ayrılmış personel hâlâ "
              f"vardiya planında ({len(ayrilmis)} kişi-gün) — rapordan çıkarıldı")
        for x in sorted(ayrilmis, key=lambda x: (str(x["Sube"]), str(x["Personel"]))):
            c = x.get("Cikis")
            print(f"    {str(x['Sube']):10s}{str(x['Personel']):26s}"
                  f"çıkış {c if c else '—'}")

    print(f"\n{'ŞUBE':10s}{'GEREKEN':>9s}{'İZİNLİ':>8s}{'GELEN':>7s}"
          f"{'GELMEYEN':>10s}{'EKSİK OKUTMA':>14s}")
    for o in ozet_satir:
        g = "—" if o["Gereken"] is None else str(o["Gereken"])
        i = "—" if o["Izinli"] is None else str(o["Izinli"])
        gm = "—" if o["Gelmeyen"] is None else str(o["Gelmeyen"])
        print(f"{o['Sube']:10s}{g:>9s}{i:>8s}{o['Gelen']:>7d}{gm:>10s}"
              f"{o['EksikOkutma']:>14d}")

    print(f"\n{'ŞUBE':10s}{'ÇIKIŞSIZ':>9s}{'KİŞİ-GÜN':>10s}{'ORAN':>8s}")
    for s, n in sube.most_common():
        print(f"{s:10s}{n:>9d}{sube_gun[s]:>10d}{n / sube_gun[s] * 100:>7.1f}%")

    print(f"\n{'ŞUBE':10s}{'SİCİL':>7s}  {'PERSONEL':26s}{'GÖREV':24s}"
          f"{'GÜN':>5s}{'ÇIKIŞSIZ':>9s}{'ORAN':>7s}")
    for v in liste[:25]:
        sicil = next(k for k, val in kisi.items() if val is v)
        print(f"{v['Sube']:10s}{sicil:>7d}  {str(v['Personel'])[:25]:26s}"
              f"{str(v['Gorev'])[:25]:26s}{v['gun']:>5d}{v['cikissiz']:>9d}"
              f"{v['cikissiz']/v['gun']*100:>6.0f}%")

    # ── EXCEL ──
    wb = Workbook()
    ws = wb.active
    ws.title = "Kişi Özeti"

    def basliklandir(w, kolonlar, genislikler):
        w.append(kolonlar)
        for c in range(1, len(kolonlar) + 1):
            h = w.cell(1, c)
            h.font, h.fill = BASLIK_YAZI, KIRMIZI
            h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        for c, wd in enumerate(genislikler, start=1):
            w.column_dimensions[get_column_letter(c)].width = wd
        w.freeze_panes = "A2"

    tip_kisi = collections.defaultdict(collections.Counter)
    for s in tekil:
        tip_kisi[int(s["Sicil"])][s["Tip"]] += 1
    basliklandir(ws, ["Şube", "Sicil", "Personel", "Bölüm", "Görev",
                      "Kart bastığı gün", "Tek okutmalı gün", "Oran %",
                      "ÇIKIŞ okutulmamış", "GİRİŞ okutulmamış", "İzin günü",
                      "Vardiya eşleşmedi"],
                 [12, 8, 26, 20, 24, 16, 16, 9, 17, 17, 11, 16])
    for sicil, v in sorted(kisi.items(), key=lambda kv: (-kv[1]["cikissiz"], kv[1]["Sube"])):
        if v["cikissiz"] == 0:
            continue
        t = tip_kisi[sicil]
        ws.append([v["Sube"], sicil, v["Personel"], v["Bolum"], v["Gorev"],
                   v["gun"], v["cikissiz"], round(v["cikissiz"] / v["gun"] * 100, 1),
                   t["ÇIKIŞ okutulmamış"], t["GİRİŞ okutulmamış"],
                   t["İZİN günü okutma"],
                   t["— (vardiya eşleşmedi)"] + t["— (plan saati yok)"]])

    ws2 = wb.create_sheet("Gün Detayı")
    basliklandir(ws2, ["Şube", "Sicil", "Personel", "Görev", "Tarih", "Gün",
                       "Vardiya Tanım", "Plan Başlama", "Plan Bitiş",
                       "Tek okutma saati", "Eksik olan", "Sapma (dk)"],
                 [12, 8, 26, 24, 12, 11, 15, 12, 11, 15, 22, 11])
    for s in sorted(tekil, key=lambda s: (str(s["Sube"]), str(s["Gun"]))):
        g = dt.datetime.strptime(str(s["Gun"]), "%Y%m%d").date()
        ws2.append([s["Sube"], int(s["Sicil"]), s["Personel"], s["Gorev"],
                    g.strftime("%d.%m.%Y"), GUN_AD[g.weekday()],
                    s.get("VardiyaTanim") or "—", s.get("PlanBas") or "—",
                    s.get("PlanBit") or "—", s["IlkOkutma"],
                    s.get("Tip"), s.get("Sapma")])

    ws3 = wb.create_sheet("Okutma Yapmayan")
    basliklandir(ws3, ["Şube", "Personel", "Görev (plan)", "Ünvan (bordro)",
                       "Kadro", "Tarih", "Gün", "Vardiya", "Son 30g okutma günü",
                       "Sınıf", "Bordro çıkış"],
                 [12, 26, 24, 24, 12, 12, 11, 15, 19, 34, 13])
    # Excel TAM kayıttır: ayrılmışlar mailden çıkarıldı ama arşivde kalır.
    for x in sorted(gelmeyenler + ayrilmis,
                    key=lambda x: (str(x["Sinif"]), str(x["Sube"]),
                                   str(x["Personel"]))):
        g = dt.datetime.strptime(str(x["Gun"]), "%Y%m%d").date()
        ws3.append([x["Sube"], x["Personel"], x["Gorev"], x.get("Unvan") or "—",
                    x.get("Kadro") or "—", g.strftime("%d.%m.%Y"),
                    GUN_AD[g.weekday()], x["VardiyaTanim"],
                    x.get("Son30Okutma") if x.get("Son30Okutma") else 0,
                    x["Sinif"], x.get("Cikis") or ""])

    cikti = a.cikti or os.path.join(
        KOK, "ciktilar", f"Cikis_Okutmayan_{bas:%Y%m%d}_{bit:%Y%m%d}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)
    print(f"\nYAZILDI: {cikti}")

    if a.html:
        with open(a.html, "w", encoding="utf-8") as f:
            f.write(html_govde(tekil, bas, bit, sube, sube_gun, cikti, ozet_satir,
                               gelmeyenler, uyarilar, ayrilmis, matris))
        print(f"HTML  : {a.html}")
    return 0


def html_govde(tekil, bas, bit, sube, sube_gun, xlsx_yol, ozet_satir, gelmeyenler,
               uyarilar, ayrilmis=(), matris=None) -> str:
    """Mail gövdesi. Ek dosya GÖNDERİLEMİYOR (IMAP save_draft ek desteklemiyor),
    o yüzden liste gövdeye gömülür; Excel yolu ayrıca yazılır."""
    donem = (f"{bas:%d.%m.%Y}" if bas == bit else f"{bas:%d.%m.%Y} – {bit:%d.%m.%Y}")
    uyari_blok = ("" if not uyarilar else
        '<div style="background:#FFF3C4;border-left:4px solid #E30622;padding:10px 14px;'
        'margin:14px 0;font-size:13px"><b>Dikkat çeken gün</b><ul style="margin:6px 0 0 18px">'
        + "".join(f"<li>{u}</li>" for u in uyarilar) + "</ul></div>")
    st = ("border-collapse:collapse;font:13px/1.45 Segoe UI,Arial,sans-serif;"
          "border:1px solid #d0d0d0")
    th = ("background:#E30622;color:#fff;padding:6px 9px;text-align:left;"
          "border:1px solid #d0d0d0;font-weight:600")
    td = "padding:5px 9px;border:1px solid #e3e3e3"

    # ⚠ HÜCRE STİLİ ÜRETİM ANINDA YAZILIR. Daha önce satırlar stilsiz kurulup
    #   sonradan `.replace("<td", ...)` ile boyanıyordu; hizalı hücrelerde bu
    #   İKİNCİ bir style özniteliği ve kapanmamış tırnak üretti (bozuk HTML,
    #   özet tablosu dağıldı — 16.09.2026 GMY bildirdi). Kör string replace
    #   yerine tek yardımcı: hizayı parametre al, stili burada birleştir.
    def h(icerik, hiza: str = "", kalin: bool = False) -> str:
        stil = td + (f";text-align:{hiza}" if hiza else "")
        ic = f"<b>{icerik}</b>" if kalin else icerik
        return f"<td style=\"{stil}\">{ic}</td>"

    def _s(x):
        return "—" if x is None else str(x)

    sat = []
    for s in sorted(tekil, key=lambda s: (str(s["Sube"]), str(s["Gun"]),
                                          str(s["Personel"]))):
        g = dt.datetime.strptime(str(s["Gun"]), "%Y%m%d").date()
        sapma = s.get("Sapma")
        sat.append(
            "<tr>" + h(s["Sube"]) + h(s["Personel"]) + h(s["Gorev"] or "—")
            + h(f"{g:%d.%m.%Y} {GUN_AD[g.weekday()]}")
            + h(s.get("VardiyaTanim") or "—")
            + h(s["IlkOkutma"], "center")
            + h(s.get("Tip") or "—", kalin=True)
            + h("" if sapma is None else f"{sapma:+d} dk", "right")
            + "</tr>")

    # Tarih kolonu ZORUNLU: çok günlük (telafi) raporda hangi gün gelinmediği
    # görünmüyordu — 22.09.2026 GMY bildirdi ("toplu mail gelince hangi gün
    # olduğu belirsiz"). Tek günlük raporda da gün adı bilgi taşır (Cuma/Pazar).
    def _gun_hucre(x):
        g = dt.datetime.strptime(str(x["Gun"]), "%Y%m%d").date()
        return h(f"{g:%d.%m.%Y} {GUN_AD[g.weekday()]}")

    gelmeyen_sat = "".join(
        "<tr>" + h(x["Sube"]) + _gun_hucre(x) + h(x["Personel"])
        + h(x.get("Unvan") or x.get("Gorev") or "—")
        + h(x["VardiyaTanim"])
        + h(x.get("Son30Okutma") or 0, "right")
        + h(x["Sinif"], kalin=x["Sinif"].startswith("GELMEDİ")) + "</tr>"
        for x in sorted(gelmeyenler, key=lambda x: (str(x["Sinif"]), str(x["Gun"]),
                                                    str(x["Sube"]),
                                                    str(x["Personel"]))))

    # İşten ayrılmış olup planda duranlar devamsızlık tablosundan çıkarıldı;
    # burada İK aksiyonu olarak ayrıca listelenir (sessizce düşürülmez).
    if ayrilmis:
        kisi_ayr = sorted({(str(x["Sube"]), str(x["Personel"]),
                            str(x.get("Cikis") or "—")) for x in ayrilmis})
        ayrilmis_blok = (
            '<h3 style="margin:18px 0 6px">Plan temizlenmeli — işten ayrılmış '
            'personel vardiya planında</h3>'
            f'<p style="margin:0 0 6px;font-size:13px;color:#666">Bu kişiler işten '
            f'ayrılmış ancak vardiya planından çıkarılmamış. Devamsızlık '
            f'sayılarına <b>dahil edilmedi</b>. Planın güncellenmesi gerekiyor.</p>'
            f'<table style="{st}">'
            f'<tr><th style="{th}">Şube</th><th style="{th}">Personel</th>'
            f'<th style="{th}">Bordro çıkış tarihi</th></tr>'
            + "".join("<tr>" + h(s) + h(p) + h(c) + "</tr>" for s, p, c in kisi_ayr)
            + "</table>")
    else:
        ayrilmis_blok = ""

    # Çok günlük (telafi) raporda şube özeti günleri topluyor; hangi günün ağır
    # olduğu kaybolur. Gün kırılımı yalnız bas != bit iken gösterilir — iki sayı
    # da eldeki listelerden türer, yeni sorgu yok.
    if bas != bit and matris:
        gunler, subeler = matris["gunler"], matris["subeler"]
        bas_hucre = "".join(
            f'<th style="{th}">'
            f'{dt.datetime.strptime(g, "%Y%m%d").date():%d.%m}<br>'
            f'<span style="font-weight:400;font-size:11px">'
            f'{GUN_AD[dt.datetime.strptime(g, "%Y%m%d").date().weekday()]}</span></th>'
            for g in gunler)
        mat_sat = []
        for sb in subeler:
            hc = []
            for g in gunler:
                k = (sb, g)
                gm = matris["gelmedi"].get(k, 0)
                ek = matris["eksik"].get(k, 0)
                ger = matris["ger"].get(k, 0)
                gel = matris["gelen"].get(k, 0)
                # Gelmedi kalın (ana sinyal); altına plan/basan küçük gri —
                # "gereken 28 / basan 58" gibi plan-gerçek sapması gün bazında
                # görünsün diye.
                hc.append(
                    f'<td style="{td};text-align:center">'
                    f'<span style="font-weight:700">{gm}</span>'
                    f'<span style="color:#888"> / {ek}</span><br>'
                    f'<span style="font-size:11px;color:#999">{ger}·{gel}</span></td>')
            mat_sat.append("<tr>" + h(sb, kalin=True) + "".join(hc) + "</tr>")
        gun_blok = (
            '<h3 style="margin:18px 0 6px">Şube × gün</h3>'
            f'<p style="margin:0 0 6px;font-size:12px;color:#666">Hücre: '
            f'<b>gelmedi</b> / eksik okutma &nbsp;·&nbsp; alt satır: '
            f'vardiyada olması gereken · kart basan</p>'
            f'<table style="{st}">'
            f'<tr><th style="{th}">Şube</th>{bas_hucre}</tr>'
            + "".join(mat_sat) + "</table>")
    else:
        gun_blok = ""

    ozet = "".join(
        "<tr>" + h(o["Sube"]) + h(_s(o["Gereken"]), "right")
        + h(_s(o["Izinli"]), "right") + h(o["Gelen"], "right")
        + h(_s(o["Gelmeyen"]), "right", kalin=True)
        + h(o["EksikOkutma"], "right") + "</tr>"
        for o in ozet_satir)
    return f"""<div style="font:14px/1.5 Segoe UI,Arial,sans-serif;color:#222">
<p>Merhaba,</p>
<p><b>{donem}</b> döneminde kart okutması eksik kalan personel listesi aşağıdadır.
Toplam <b>{len(tekil)} kişi-gün</b>.</p>

{uyari_blok}
{gun_blok}
<h3 style="margin:18px 0 6px">Şube özeti</h3>
<table style="{st}">
<tr><th style="{th}">Şube</th><th style="{th}">Vardiyada olması gereken</th>
<th style="{th}">İzinli</th><th style="{th}">Kart basan</th>
<th style="{th}">Gelmedi</th><th style="{th}">Eksik okutma</th></tr>
{ozet}
</table>

<h3 style="margin:18px 0 6px">Vardiyada olup kart okutmayan</h3>
<table style="{st}">
<tr><th style="{th}">Şube</th><th style="{th}">Tarih</th><th style="{th}">Personel</th>
<th style="{th}">Ünvan</th>
<th style="{th}">Vardiya</th><th style="{th}">Son 30g okutma</th>
<th style="{th}">Durum</th></tr>
{gelmeyen_sat}
</table>

{ayrilmis_blok}

<h3 style="margin:18px 0 6px">Kart okutması eksik kalanlar (tek okutma)</h3>
<table style="{st}">
<tr><th style="{th}">Şube</th><th style="{th}">Personel</th><th style="{th}">Görev</th>
<th style="{th}">Tarih</th><th style="{th}">Vardiya</th><th style="{th}">Okutma</th>
<th style="{th}">Eksik olan</th><th style="{th}">Sapma</th></tr>
{"".join(sat)}
</table>

<p style="margin-top:18px;font-size:12px;color:#666">
<b>Nasıl ölçülüyor:</b> PDKS ham kart okutmasında (TZeiBuf) bir kişi-günde tek
okutma varsa ikinci okutma hiç yapılmamıştır. Okutma saati vardiya planının
başına mı bitişine mi yakın diye bakılarak eksik olanın giriş mi çıkış mı
olduğu ayrılır.<br>
<b>Dikkat:</b> &quot;Okutmadı&quot; tek başına devamsızlık veya kaçma anlamına gelmez —
terminal arızası, kart unutma, başka kapıdan çıkma ve yönetici izniyle erken
çıkış aynı satırı üretir. Liste bir hatırlatma listesidir.<br>
&quot;Vardiya eşleşmedi&quot; satırları personelin TC kimlik bilgisi PDKS'te kayıtlı
olmadığı için plana bağlanamamıştır; vardiyası yok anlamına gelmez.<br>
Excel: {os.path.basename(xlsx_yol)}
</p></div>"""


if __name__ == "__main__":
    sys.exit(main())
