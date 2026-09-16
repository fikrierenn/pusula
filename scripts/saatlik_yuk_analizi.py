# -*- coding: utf-8 -*-
"""SAATLİK YÜK ANALİZİ — kart basan personel × vardiya planı × fiş yoğunluğu.

GMY isteği 15.09.2026: "personel kart basma, vardiya, fiş müşteri yoğunluğu ile
bir analiz" + "saatlikte bakılabilir".

SORU: hangi saatte kaç kişi İÇERİDE, o saatte kaç müşteri var, ve bu ikisi
birbirini tutuyor mu? Plan (vardiya) ile fiili (kart) nerede ayrışıyor?

ÜÇ KAYNAK, ÜÇ AYRI GRAIN — hepsi mağaza × gün × saat'e indirgenir:
  1. FİŞ      EncoreMerkez.Sales (DocumentsTypeId=1, perakende fiş)
  2. FİİLİ    PDKS TTagZei — kart basan personelin gün içi aralığı
  3. PLAN     BKM.vrd — vardiya planındaki saat aralığı

KAPSAM (ölçüldü, seçim DEĞİL kısıt):
  · POS fişi YALNIZ 3 mağazada var: FSM · ÖZLÜCE · İST.YOLU.
    HEYKEL, ŞURA, üç KAFE ve GENEL MÜDÜRLÜK EncoreMerkez'de YOK → analiz dışı.
  · PDKS tarafında `Per_Grp1 = 'MAĞAZALAR'` ZORUNLU: kafe personeli aynı
    `Per_Grp2`yi (ör. 'FSM') paylaşır, süzülmezse mağaza kadrosuna eklenir
    (bridges:pdks-sube-bolum.grp2_tek_basina_yetmez).

PDKS SAATLİK SAYIM — KABUL EDİLEN MANTIK (sema: pdks_saatlik_personel):
  1) Kişi-gün aralığı = MIN(giriş) → MAX(son dolu saat). Öğle molası segmenti
     satır kırar; segment-bazlı saymak mola saatinde SAHTE DÜŞÜŞ üretir.
  2) Çıkış dakikası > 0 ise o saat DAHİL (18:30 → 18), tam saatte çıktıysa hariç.
  3) Ortalama = toplam kişi-saat / o haftagününün ÇALIŞILAN gün sayısı
     (boş saat 0 olarak paya girer; sadece-dolu-güne bölmek uç saatleri şişirir).

⚠ YÜK GÖSTERGESİ NE DEĞİLDİR: "fiş / personel" tüm mağaza kadrosunu paydaya alır
  (kasiyer + satış danışmanı + reyon şefi + temizlik). Fiş yalnız kasada kesilir.
  Yani bu oran "kasiyer verimi" DEĞİL, mağaza genelinde müşteri-başına-insan
  yoğunluğudur. Kasa yükü ayrı ölçülmek istenirse görev bazlı süzgeç gerekir.

⚠ FİŞ ≠ MÜŞTERİ SAYISI. Bir müşteri iki fiş kesebilir, bir fiş iki kişiye
  hizmet olabilir. Kapı sayıcı verisi olmadığı için fiş, müşteri yoğunluğunun
  VEKİLİDİR — üst sınır değil, tahmin. (Kapı sayıcı entegrasyonu: B-127.)

⚠ pyodbc (pymssql DEĞİL): DerinSIS varchar CP1254, pymssql Türkçe'yi bozuyor.
⚠ OPENQUERY tarih literali ISO 'YYYYMMDD'.

Kullanım:
    python scripts/saatlik_yuk_analizi.py [--bas 17.08.2026] [--bit 13.09.2026]
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

# Üç sistem mağazayı ÜÇ FARKLI ADLA yazıyor. Eşleme kaçınılmaz; her satır
# ölçümle doğrulandı (fiş sayısı + kadro büyüklüğü mertebesi tutuyor).
MAGAZALAR = [
    # (rapor adı, EncoreMerkez Stores.Id, PDKS Per_Grp2, BKM.vrd SubeAd)
    ("FSM",       2, "FSM",       "FSM"),
    ("ÖZLÜCE",    3, "ÖZLÜCE",    "ÖZLÜCE"),
    ("İST. YOLU", 1, "İST.YOLU",  "İST. YOLU"),
]
GUN_AD = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
SAATLER = list(range(9, 23))          # mağaza açık saatleri (ölçüldü: 09–22)

KIRMIZI = PatternFill("solid", fgColor="E30622")
GRI = PatternFill("solid", fgColor="EFEFEF")
BASLIK_YAZI = Font(bold=True, color="FFFFFF", size=10)


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


# =============================================================================
# 1) FİŞ — saatlik müşteri yoğunluğu vekili
#    Net ciro = GrossTotal − DiscountTotal − VatTotal (KDV-hariç, kanonik).
#    İade (3) HARİÇ: "o saatte kaç müşteri vardı" sorusunda iade bir gelme değil.
# =============================================================================
SQL_FIS = """
SELECT  s.StoresId,
        CONVERT(date, s.Date)                               AS Gun,
        DATEPART(hour, s.Date)                              AS Saat,
        SUM(CASE WHEN s.DocumentsTypeId = 1 THEN 1 ELSE 0 END)   AS Fis,
        SUM(CASE WHEN s.DocumentsTypeId = 1
                 THEN s.GrossTotal - s.DiscountTotal - s.VatTotal ELSE 0 END) AS NetCiro,
        SUM(CASE WHEN s.DocumentsTypeId = 8 THEN 1 ELSE 0 END)   AS Sinav,
        SUM(CASE WHEN s.DocumentsTypeId = 8
                 THEN s.GrossTotal - s.DiscountTotal - s.VatTotal ELSE 0 END) AS SinavCiro
FROM    EncoreMerkez.dbo.Sales s
WHERE   s.Date >= ? AND s.Date < DATEADD(day, 1, CAST(? AS datetime))
    AND s.DocumentsTypeId IN (1, 8)
    AND s.StoresId IN (1, 2, 3)
GROUP BY s.StoresId, CONVERT(date, s.Date), DATEPART(hour, s.Date)
"""

# =============================================================================
# 1b) KALEM — fiş SAYISI iş yükünü eksik ölçer (GMY uyarısı 15.09.2026):
#     1 kalemlik fiş ile 20 kalemlik fiş aynı iş değil. Kalem sayısı okutma,
#     paketleme ve reyon yükünün daha iyi vekili.
#     ⚠ `IsValid = 1` ZORUNLU (sql-server-conventions) — iptal satırlar sayılmaz.
#     ⚠ `Sales.LineCount` KULLANILMAZ (güvenilmez), kalem SAYILIR.
# =============================================================================
SQL_KALEM = """
SELECT  s.StoresId,
        CONVERT(date, s.Date)   AS Gun,
        DATEPART(hour, s.Date)  AS Saat,
        COUNT(*)                AS Kalem,
        SUM(sp.Amount)          AS Adet
FROM        EncoreMerkez.dbo.Sales         s
INNER JOIN  EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
WHERE   s.Date >= ? AND s.Date < DATEADD(day, 1, CAST(? AS datetime))
    AND s.DocumentsTypeId = 1
    AND s.StoresId IN (1, 2, 3)
GROUP BY s.StoresId, CONVERT(date, s.Date), DATEPART(hour, s.Date)
"""

# =============================================================================
# 2) FİİLİ — PDKS kart okutma segmentleri (saat genişletmesi Python'da)
# =============================================================================
SQL_PDKS = """
SELECT x.Grp2 COLLATE Turkish_CI_AS AS Grp2, x.PersNr, x.Gun, x.Giris, x.Cikis
FROM OPENQUERY([PDKS], '
    SELECT  LTRIM(RTRIM(p.Per_Grp2))            AS Grp2,
            z.TZe_PersNr                        AS PersNr,
            CONVERT(char(8), z.TZe_Datum, 112)  AS Gun,
            MIN(z.TZe_VonZeit)                  AS Giris,
            MAX(z.TZe_BisZeit)                  AS Cikis
    FROM        TTagZei z
    INNER JOIN  TPerTab p ON p.Per_PersNr = z.TZe_PersNr
    WHERE   z.TZe_Datum >= ''{bas}'' AND z.TZe_Datum <= ''{bit}''
        AND LTRIM(RTRIM(p.Per_Grp1)) = ''MAĞAZALAR''
        AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL
    GROUP BY LTRIM(RTRIM(p.Per_Grp2)), z.TZe_PersNr, CONVERT(char(8), z.TZe_Datum, 112)
') x
"""

# =============================================================================
# 3) PLAN — vardiya planındaki saat aralığı (izin satırları hariç)
# =============================================================================
SQL_PLAN = """
SELECT  s.SubeAd,
        CONVERT(date, DATEADD(day, g.ofs, v.Tarih)) AS Gun,
        vz.Baslama, vz.Bitis
FROM        BKM.vrd.Vardiya       v
INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo     = v.SubeNo
INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
CROSS APPLY (VALUES (0, vd.Pazartesi), (1, vd.Sali), (2, vd.Carsamba),
                    (3, vd.Persembe), (4, vd.Cuma), (5, vd.Cumartesi),
                    (6, vd.Pazar)) AS g(ofs, VardiyaId)
INNER JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
WHERE   g.VardiyaId <> 0 AND vz.Izin = 0
    AND vz.Baslama IS NOT NULL AND vz.Bitis IS NOT NULL
    AND DATEADD(day, g.ofs, v.Tarih) >= ? AND DATEADD(day, g.ofs, v.Tarih) <= ?
"""


def saat_araligi(giris, cikis) -> range:
    """Kişi-gün aralığını SAAT kovalarına çevirir (sema kural 1 + 2).

    Çıkış dakikası > 0 ise o saat DAHİL (18:30 → 18); tam saatte çıktıysa hariç
    (18:00 → 17). Giriş taban alınır (10:30 → 10). Yoksa 18:30'a kadar çalışan
    saat 18'de hiç sayılmaz.
    """
    g = giris.hour
    s = cikis.hour if cikis.minute > 0 else cikis.hour - 1
    if s < g:
        s = g
    return range(g, s + 1)


def veri_cek(cn, bas: dt.date, bit: dt.date):
    cur = cn.cursor()
    iso = lambda d: d.strftime("%Y%m%d")

    # ── FİŞ ──
    cur.execute(SQL_FIS, bas, bit)
    fis: dict[tuple, list] = {}
    for sid, gun, saat, adet, ciro, sinav, sciro in cur.fetchall():
        fis[(int(sid), gun, int(saat))] = [int(adet), float(ciro or 0),
                                           int(sinav or 0), float(sciro or 0)]
    if not fis:
        sys.exit("KOŞAMADI: fiş tarafı BOŞ döndü — dönem gerçekten boş mu, "
                 "yoksa sorgu mu kapsamadı? Boş nüfus 'yoğunluk yok' demek değildir.")

    # ── KALEM ──
    cur.execute(SQL_KALEM, bas, bit)
    kalem: dict[tuple, list] = {}
    for sid, gun, saat, k, adet in cur.fetchall():
        kalem[(int(sid), gun, int(saat))] = [int(k), float(adet or 0)]

    # ── FİİLİ (PDKS) ──
    cur.execute(SQL_PDKS.format(bas=iso(bas), bit=iso(bit)))
    fiili: dict[tuple, set] = collections.defaultdict(set)
    kisi_gun = collections.Counter()
    for grp2, persnr, gun_s, giris, cikis in cur.fetchall():
        gun = dt.datetime.strptime(str(gun_s), "%Y%m%d").date()
        grp2 = str(grp2).strip()
        kisi_gun[grp2] += 1
        for h in saat_araligi(giris, cikis):
            fiili[(grp2, gun, h)].add(int(persnr))
    if not fiili:
        sys.exit("KOŞAMADI: PDKS tarafı BOŞ — linked server düşmüş olabilir.")

    # ── PLAN ──
    cur.execute(SQL_PLAN, bas, bit)
    plan = collections.Counter()
    for sube, gun, bas_s, bit_s in cur.fetchall():
        sube = str(sube).strip()
        s = bit_s.hour if bit_s.minute > 0 else bit_s.hour - 1
        for h in range(bas_s.hour, max(s, bas_s.hour) + 1):
            plan[(sube, gun, h)] += 1
    cur.close()

    print(f"  fiş hücresi   : {len(fis)}")
    print(f"  kalem hücresi : {len(kalem)}")
    print(f"  PDKS kişi-gün : {sum(kisi_gun.values())} "
          f"({' · '.join(f'{k}={v}' for k, v in sorted(kisi_gun.items()))})")
    print(f"  plan hücresi  : {len(plan)}")
    return fis, kalem, fiili, plan


def matris_kur(fis, kalem, fiili, plan, bas: dt.date, bit: dt.date):
    """Mağaza × gün × saat hücrelerini tek tabloya indirger."""
    gunler = [bas + dt.timedelta(days=i) for i in range((bit - bas).days + 1)]
    satirlar = []
    for ad, sid, grp2, sube in MAGAZALAR:
        for g in gunler:
            for h in SAATLER:
                f = fis.get((sid, g, h), [0, 0.0, 0, 0.0])
                kl = kalem.get((sid, g, h), [0, 0.0])
                satirlar.append({
                    "magaza": ad, "gun": g, "hg": g.weekday(), "saat": h,
                    "gun_tipi": "Hafta sonu" if g.weekday() >= 5 else "Hafta içi",
                    "fis": f[0], "ciro": f[1], "sinav": f[2], "sinav_ciro": f[3],
                    "kalem": kl[0], "adet": kl[1],
                    "fiili": len(fiili.get((grp2, g, h), ())),
                    "plan": plan.get((sube, g, h), 0),
                })
    return satirlar


# =============================================================================
# ANALİZ — "gereksiz personel var mı?" (GMY sorusu 15.09.2026)
#
# ÖLÇÜT SEÇİMİ BEYAN EDİLİR (olctum-mu-cikardim-mi § EŞİK TÜRETME):
# "Fazla personel" bir EŞİK seçimidir, veriden kendiliğinden çıkmaz. Burada
# referans = MAĞAZANIN KENDİ MEDYAN YÜKÜ (fiş/kişi-saat, açık saatler).
#   gereken_kişi(saat) = fiş(saat) / medyan_yük
#   atıl_kişi_saat     = MAX(0, fiili − gereken)
# Yani "her saat, bu mağazanın kendi olağan temposunda çalışsaydı" sorusu.
#
# NEDEN PİK REFERANSI DEĞİL: pik saati referans almak "her saat pik kadar
# verimli olmalı" demektir; pikte kuyruk ve bekleme vardır, o tempo sürdürülebilir
# değildir ve fazlalığı SİSTEMATİK OLARAK ABARTIR.
# NEDEN MEDYAN: yarısı üstünde yarısı altında; mağazanın kendi normu.
#
# BU SAYI BİR KADRO ÖNERİSİ DEĞİLDİR. Dört sebeple ÜST SINIRDIR:
#   1. Fiş, müşteri sayısının VEKİLİ. Kapı sayıcı verisi bu analizde yok.
#   2. Personel yalnız kasa açmıyor: mal kabul, raf, sayım, iade, temizlik,
#      etiketleme müşteri yokken yapılır — "boş saat" çoğu zaman DOLU saattir.
#   3. Açılış/kapanış hazırlığı müşterisiz geçer ve zorunludur.
#   4. Yasal mola ve vardiya devir örtüşmesi kişi-saate girer.
# =============================================================================
GUN_TIPLERI = ["Hafta içi", "Hafta sonu"]


def analiz(satirlar, olcu: str = "kalem", gun_tipi: str | None = None):
    """`olcu`: "kalem" (varsayılan) veya "fis".

    `gun_tipi`: None (tümü) · "Hafta içi" · "Hafta sonu".

    ⚠ HAFTA İÇİ / HAFTA SONU AYRI ÖLÇÜLÜR (GMY isteği 15.09.2026). Ölçüldü:
    hafta sonu kalem/gün hafta içinin 1,40-1,70 katı, ama kişi-saat yalnız
    1,09-1,21 katı → yük 1,26-1,46 kat. İkisini tek medyanda toplamak hafta
    sonunu "normal", hafta içini "fazla personelli" gösterir; bu bir ölçüm
    hatasıdır, bulgu değil.

    GMY uyarısı 15.09.2026: fiş SAYISI iş yükünü eksik ölçer — 1 kalemlik fişle
    20 kalemlik fiş aynı iş değildir. Varsayılan ölçü KALEM'e çevrildi; fiş
    bazlı sonuç da hesaplanıp yan yana raporlanıyor (ölçüt değişince yön
    değişiyor mu, görülsün diye).
    """
    import statistics
    magaza = collections.defaultdict(list)
    for s in satirlar:
        if gun_tipi and s["gun_tipi"] != gun_tipi:
            continue
        magaza[s["magaza"]].append(s)

    rapor = {}
    for ad, sat in magaza.items():
        dolu = [s for s in sat if s["fiili"] > 0 and s[olcu] > 0]
        yukler = [s[olcu] / s["fiili"] for s in dolu]
        medyan = statistics.median(yukler) if yukler else 0.0

        toplam_ks = sum(s["fiili"] for s in sat)
        toplam_fis = sum(s[olcu] for s in sat)
        atil = 0.0
        for s in sat:
            gereken = (s[olcu] / medyan) if medyan else 0.0
            s["gereken"] = gereken
            s["atil"] = max(0.0, s["fiili"] - gereken)
            atil += s["atil"]

        rapor[ad] = {
            "kisi_saat": toplam_ks, "fis": toplam_fis,
            "yuk": toplam_fis / toplam_ks if toplam_ks else 0,
            "medyan_yuk": medyan, "atil_kisi_saat": atil,
            "atil_pay": atil / toplam_ks if toplam_ks else 0,
            "plan_kisi_saat": sum(s["plan"] for s in sat),
            "olcu": olcu, "gun_tipi": gun_tipi or "Tümü",
            "gun_sayisi": len({x["gun"] for x in sat}),
            "kalem": sum(s.get("kalem", 0) for s in sat),
            "adet": sum(s.get("adet", 0.0) for s in sat),
            "fis_adet": sum(s["fis"] for s in sat),
            "sinav_belge": sum(s.get("sinav", 0) for s in sat),
            "sinav_ciro": sum(s.get("sinav_ciro", 0.0) for s in sat),
            "ciro": sum(s["ciro"] for s in sat),
        }
    return rapor


def saat_ozeti(satirlar, gun_tipi: str | None = None):
    kova = collections.defaultdict(lambda: {"fis": 0, "kalem": 0, "fiili": 0,
                                            "plan": 0, "atil": 0.0, "gun": set()})
    for s in satirlar:
        if gun_tipi and s["gun_tipi"] != gun_tipi:
            continue
        k = kova[(s["magaza"], s["saat"])]
        k["fis"] += s["fis"]
        k["kalem"] += s.get("kalem", 0)
        k["fiili"] += s["fiili"]
        k["plan"] += s["plan"]
        k["atil"] += s.get("atil", 0.0)
        k["gun"].add(s["gun"])
    return kova


def dagitim_sayfasi(wb, satirlar, basliklandir):
    """NÖTR YENİDEN DAĞITIM — kadro SABİT, saatler fiş payına göre dağıtılsa.

    gereken(saat) = toplam_kişi_saat × fiş_payı(saat)
    Kişi-saat toplamı DEĞİŞMEZ; yalnız saatler arasında kayar. Bu yüzden sonuç
    bir KADRO AZALTMA önerisi değildir — "aynı kadro, farklı saat" sorusudur.

    ⚠ 09:00 ve 22:00 HARİÇ: mağaza müşteriye kapalı, personel açılış/kapanış
      hazırlığı yapıyor. Fiş payı ~0 olduğu için bu saatler "tamamı fazla"
      görünür ve toplamı anlamsızca şişirir.
    """
    import collections
    ws = wb.create_sheet("Yeniden Dağıtım")
    basliklandir(ws, ["Mağaza", "Gün tipi", "Saat", "Ort. fiili personel",
                      "Ort. gereken (kalem payına göre)", "Fark (kişi)", "Durum",
                      "Kişi-saat farkı (dönem)"],
                 [14, 11, 8, 18, 27, 12, 10, 20])
    d = collections.defaultdict(lambda: {"fis": 0, "fiili": 0, "gun": set()})
    for s in satirlar:
        if s["saat"] < 10 or s["saat"] > 21:
            continue
        k = d[(s["magaza"], s["gun_tipi"], s["saat"])]
        k["fis"] += s.get("kalem", 0)          # ölçü KALEM (GMY 15.09.2026)
        k["fiili"] += s["fiili"]
        k["gun"].add(s["gun"])
    for ad, *_ in MAGAZALAR:
      for gt in GUN_TIPLERI:
        saatler = [(h, d[(ad, gt, h)]) for h in range(10, 22)]
        tf = sum(v["fis"] for _, v in saatler)
        tp = sum(v["fiili"] for _, v in saatler)
        for h, v in saatler:
            n = len(v["gun"]) or 1
            ger = tp * v["fis"] / tf if tf else 0
            fark = v["fiili"] - ger
            ws.append([ad, gt, f"{h:02d}:00", round(v["fiili"] / n, 1), round(ger / n, 1),
                       round(fark / n, 1), "FAZLA" if fark > 0 else "EKSİK",
                       round(fark, 0)])


def excel_yaz(satirlar, rapor, cikti):
    wb = Workbook()

    def basliklandir(ws, kolonlar, genislikler):
        ws.append(kolonlar)
        for c in range(1, len(kolonlar) + 1):
            h = ws.cell(1, c)
            h.font, h.fill = BASLIK_YAZI, KIRMIZI
            h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        for c, w in enumerate(genislikler, start=1):
            ws.column_dimensions[get_column_letter(c)].width = w
        ws.freeze_panes = "A2"

    ws = wb.active
    ws.title = "Mağaza Özeti"
    basliklandir(ws, ["Mağaza", "Gün tipi", "Gün", "Perakende fiş", "Kalem", "Kalem / fiş",
                      "Perakende net ciro", "SINAV belgesi", "SINAV net ciro",
                      "Kişi-saat (fiili)", "Kişi-saat (plan)", "Kalem / kişi-saat",
                      "Medyan yük (kalem)", "Atıl kişi-saat", "Atıl pay %",
                      "Fiili - Plan"],
                 [14, 11, 6, 13, 12, 11, 17, 13, 16, 15, 15, 16, 17, 13, 11, 12])
    for ad in [m[0] for m in MAGAZALAR]:
      for gt in GUN_TIPLERI + ["Tümü"]:
        r = rapor[gt][ad]
        ws.append([ad, gt, r["gun_sayisi"], r["fis_adet"], r["kalem"],
                   round(r["kalem"] / r["fis_adet"], 2) if r["fis_adet"] else None,
                   round(r["ciro"], 2), r["sinav_belge"], round(r["sinav_ciro"], 2),
                   r["kisi_saat"], r["plan_kisi_saat"],
                   round(r["yuk"], 2), round(r["medyan_yuk"], 2),
                   round(r["atil_kisi_saat"], 1), round(r["atil_pay"] * 100, 1),
                   r["kisi_saat"] - r["plan_kisi_saat"]])

    ws = wb.create_sheet("Saat Profili")
    basliklandir(ws, ["Mağaza", "Gün tipi", "Saat", "Gün sayısı", "Ort. fiş", "Ort. kalem",
                      "Ort. fiili personel", "Ort. planlı personel",
                      "Fiş / kişi", "Kalem / kişi", "Atıl kişi-saat (toplam)",
                      "Kalem payı %", "Personel payı %", "Kapsama endeksi"],
                 [14, 11, 7, 11, 10, 11, 17, 17, 11, 12, 19, 13, 15, 14])
    for gt in GUN_TIPLERI:
      kova = saat_ozeti(satirlar, gt)
      for ad in [m[0] for m in MAGAZALAR]:
        tk = sum(v["kalem"] for (m, _), v in kova.items() if m == ad)
        tp = sum(v["fiili"] for (m, _), v in kova.items() if m == ad)
        for h in SAATLER:
            v = kova[(ad, h)]
            n = len(v["gun"]) or 1
            kal_pay = v["kalem"] / tk if tk else 0
            per_pay = v["fiili"] / tp if tp else 0
            ws.append([ad, gt, f"{h:02d}:00", n, round(v["fis"] / n, 1),
                       round(v["kalem"] / n, 1),
                       round(v["fiili"] / n, 1), round(v["plan"] / n, 1),
                       round(v["fis"] / v["fiili"], 2) if v["fiili"] else None,
                       round(v["kalem"] / v["fiili"], 2) if v["fiili"] else None,
                       round(v["atil"], 1), round(kal_pay * 100, 1),
                       round(per_pay * 100, 1),
                       round(per_pay / kal_pay, 2) if kal_pay else None])

    ws = wb.create_sheet("Haftagünü x Saat")
    basliklandir(ws, ["Mağaza", "Gün", "Ölçü"] + [f"{h:02d}" for h in SAATLER],
                 [14, 12, 14] + [7] * len(SAATLER))
    hg = collections.defaultdict(lambda: {"fis": 0, "fiili": 0})
    for s in satirlar:
        k = hg[(s["magaza"], s["hg"], s["saat"])]
        k["fis"] += s.get("kalem", 0)
        k["fiili"] += s["fiili"]
    for ad in [m[0] for m in MAGAZALAR]:
        for g in range(7):
            for olcu in ("Kalem / kişi", "Ort. personel"):
                satir = [ad, GUN_AD[g], olcu]
                for h in SAATLER:
                    k = hg[(ad, g, h)]
                    gun_sayisi = len({s["gun"] for s in satirlar
                                      if s["magaza"] == ad and s["hg"] == g}) or 1
                    gun_sayisi = gun_sayisi // len(SAATLER) or 1
                    if olcu == "Kalem / kişi":
                        satir.append(round(k["fis"] / k["fiili"], 1) if k["fiili"] else None)
                    else:
                        satir.append(round(k["fiili"] / gun_sayisi, 1))
                ws.append(satir)

    dagitim_sayfasi(wb, satirlar, basliklandir)

    ws = wb.create_sheet("Ham Veri")
    basliklandir(ws, ["Mağaza", "Tarih", "Gün", "Gün tipi", "Saat", "Perakende fiş", "Kalem",
                      "Adet", "Net Ciro", "SINAV belgesi", "Fiili personel",
                      "Planlı personel", "Gereken (medyan kalem yükü)", "Atıl kişi-saat"],
                 [14, 12, 12, 11, 7, 13, 10, 10, 14, 13, 14, 15, 23, 14])
    for s in satirlar:
        ws.append([s["magaza"], s["gun"].strftime("%d.%m.%Y"), GUN_AD[s["hg"]],
                   s["gun_tipi"], f"{s['saat']:02d}:00", s["fis"], s.get("kalem", 0),
                   round(s.get("adet", 0.0), 1), round(s["ciro"], 2),
                   s.get("sinav", 0), s["fiili"], s["plan"],
                   round(s.get("gereken", 0), 2), round(s.get("atil", 0), 2)])

    wb.save(cikti)
    return cikti


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bas", default="17.08.2026")
    ap.add_argument("--bit", default="13.09.2026")
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()
    bas = dt.datetime.strptime(a.bas, "%d.%m.%Y").date()
    bit = dt.datetime.strptime(a.bit, "%d.%m.%Y").date()
    print(f"SAATLİK YÜK ANALİZİ · {bas:%d.%m.%Y} - {bit:%d.%m.%Y} "
          f"({(bit - bas).days + 1} gün)")

    cn = baglan(env_oku(os.path.join(KOK, ".env")))
    try:
        fis, kalem, fiili, plan = veri_cek(cn, bas, bit)
    finally:
        cn.close()

    satirlar = matris_kur(fis, kalem, fiili, plan, bas, bit)

    # ÖNCE fiş ölçüsüyle koş (kıyas için), SONRA kalem — satırlardaki
    # gereken/atıl alanları kalem ölçüsüyle kalır (varsayılan).
    # HAFTA İÇİ ve HAFTA SONU AYRI medyanla ölçülür — tek medyan hafta içini
    # haksız yere "fazla personelli" gösterir (ölçüldü: yük 1,26-1,46 kat fark).
    rapor = {gt: analiz(satirlar, "kalem", gt) for gt in GUN_TIPLERI}
    rapor["Tümü"] = analiz(satirlar, "kalem")     # satırlardaki atıl bu kalır

    print()
    print(f"{'MAĞAZA':12s}{'GÜN TİPİ':12s}{'GÜN':>4s}{'KALEM':>9s}{'KİŞİ-SAAT':>10s}"
          f"{'KALEM/KİŞİ':>11s}{'MEDYAN':>8s}{'ATIL K-S':>9s}{'ATIL %':>8s}")
    for ad in [m[0] for m in MAGAZALAR]:
        for gt in GUN_TIPLERI:
            r = rapor[gt][ad]
            print(f"{ad:12s}{gt:12s}{r['gun_sayisi']:>4d}{r['kalem']:>9d}"
                  f"{r['kisi_saat']:>10d}{r['yuk']:>11.2f}{r['medyan_yuk']:>8.2f}"
                  f"{r['atil_kisi_saat']:>9.0f}{r['atil_pay']*100:>7.1f}%")

    cikti = a.cikti or os.path.join(
        KOK, "ciktilar", f"Saatlik_Yuk_Analizi_{bas:%Y%m%d}_{bit:%Y%m%d}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    excel_yaz(satirlar, rapor, cikti)
    print(f"\nYAZILDI: {cikti}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
