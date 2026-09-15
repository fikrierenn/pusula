# -*- coding: utf-8 -*-
"""SEZON AKSİYON LİSTESİ — sade, tek sayfa, satınalma ile paylaşılacak.

GMY 14.09.2026: "365 günde satılan, sezonda satılan, sezon büyümesi %20, satılacak
miktar, mağaza+depo stok, açık, fazla — daha basit, satınalma ile paylaşıp aksiyon
alınacak liste".

Satılacak miktar = sezonda satılan × (1 + büyüme)     [büyüme varsayılan %20, sabit]
Toplam stok      = mağaza + depo(merkez)
AÇIK             = satılacak − toplam stok   (pozitifse)
FAZLA            = toplam stok − satılacak   (pozitifse)

Kapsam: geçen sezon (Ağu–Eki) satmış · defter güvenilir (negatif stok / fiyat 0 dışarıda).

Kullanım:
    python scripts/sezon_aksiyon_listesi_excel.py [--kesim 2026-09-13] [--sezon 2025]
        [--buyume 0.20] [--durum acik|fazla|bitti] [--kategori Kırtasiye]
Çıkış: 0 dosya yazıldı · 2 KOŞAMADI.
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
LACI = PatternFill("solid", fgColor="1F3864")
SARI = PatternFill("solid", fgColor="FFF2CC")   # FORMÜL hücresi — göz ayırsın


def kosamadi(mesaj: str) -> None:
    print(f"KOSAMADI: {mesaj}", file=sys.stderr)
    raise SystemExit(2)


def env_oku(yol: str) -> dict[str, str]:
    if not os.path.exists(yol):
        kosamadi(f".env bulunamadi: {yol}")
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
    host, port = env.get("MSSQL_HOST", ""), env.get("MSSQL_PORT", "1433")
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
        kosamadi("Gecersiz MSSQL_HOST/MSSQL_PORT (.env)")
    for a in ("MSSQL_USER", "MSSQL_PASSWORD"):
        if not env.get(a):
            kosamadi(f"{a} .env'de yok — sessizce bos sifreyle baglanilmaz")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 900
    return cn


YOL = ("STUFF(ISNULL(N' > ' + NULLIF(t.Kategori1, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat1, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat2, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat3, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat4, N''), N''), 1, 3, N'')")

MALIYET_GECERLI = "(t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat)"

SQL = f"""
-- ⚠ TÜRETİLEN KOLONLAR SQL'DE HESAPLANMAZ — Excel'de FORMÜL olarak kurulur
--   (GMY: "formüllü olsun ne nerden geliyor gözüksün"). Buradan yalnız HAM girdiler gelir.
WITH gh AS (   -- GEÇEN yılın penceresi — BU yılınkinin ay/gün AYNASI
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
bh AS (        -- BU yılın penceresi — gün sayısı gh ile BİREBİR aynı (aynalama garantisi)
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
gk AS (        -- GEÇEN yılın KALAN sezon dilimi: (kesim aynası + 1) – 31.10.<sezon>
    -- GMY 15.09.2026: "açık sadece sezonu geçirmek için gerekli olan değil mi".
    -- ⚠ Sezonun geçen günleri ZATEN SATILDI; tüm sezon talebini istemek açığı
    --   ŞİŞİRİR. Ölçüldü: tüm sezon 254,7M ₺ · kalan sezon 106,9M ₺ → 2,4 KAT.
    -- Bu yılın kalanı ile geçen yılın kalanı AYNI gün sayısıdır (takvim aynası).
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
gks AS (       -- GEÇEN yılın kalan dilimi, MAĞAZA BAZLI — transfer kararı için
    -- satinalma-danisman 15.09.2026: "AÇIK, satınalma ile transferi karıştırıyor.
    --   Talep TOPLAM eldeye göre ölçülüyor; mağaza kolonları duruyor ama HESABA
    --   GİRMİYOR. FSM'de stok var, İst.Yolu'nda yok → tabloda görünmez."
    -- ⚠ 'Top' AYRILMIŞ SÖZCÜK — alias 'Tum' (ölçüldü: 'Top' takma adı SQL 156 verdi).
    SELECT h.ehstkID AS stkID,
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
sn AS (        -- SANSÜR BAYRAĞI: geçen yıl KALAN dilimin ay sonlarında mağaza stoğu 0 mı?
    -- satinalma-danisman 15.09.2026: "bugün AÇIK olan ürünler büyük olasılıkla geçen yıl
    --   da aynı dilimde tükenenler. O zaman gk SAĞDAN SANSÜRLÜDÜR: gerçek talebi değil,
    --   raf bitene kadarki satışı gösterir. Formül en çok satanları EKSİK sipariş ettirir."
    -- ÖLÇÜLDÜ 15.09.2026: AÇIK'taki 17.062 ürünün 2.920'si (%17,1) böyle; 977'sinde iki ay
    --   sonu da sıfır. Bu satırların AÇIK tutarı 5,16M ₺ (toplamın %6,6'sı).
    -- ⚠ VEKİL SINIRI: AY SONU fotoğrafı. Dilim içinde tükenip sonra dolan ürünü KAÇIRIR →
    --   2.920 bir ALT SINIRDIR, gerçek sansür daha yaygın olabilir.
    SELECT b.stkID,
           Eyl = SUM(CASE WHEN b.Donem = ? THEN b.Stok ELSE 0 END),
           Eki = SUM(CASE WHEN b.Donem = ? THEN b.Stok ELSE 0 END)
    FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b WITH (NOLOCK)
    WHERE b.ehMekan IN (1,4477,4478) AND b.Donem IN (?, ?)
    GROUP BY b.stkID
),
kb AS (        -- KATEGORİ BÜYÜMESİ — ÖLÇÜLEN, elle yazılmayan
    -- satinalma-danisman kararı 15.09.2026: "büyüme alıcının yazacağı bir kutu OLMAZ.
    --   Tek kadran hem AÇIK'ı büyütüp 'sipariş vermeliyim' dedirtiyor, hem FAZLA'yı
    --   küçültüp 'fazla stoğum yok' dedirtiyor. Tek parametre, iki savunma."
    -- ⚠ TABAN EŞİĞİ: geçen yıl 2.000 adedin altındaki kategoride oran oynak
    --   (Akademi 7.540 adetle 2,255 çıkıyor). Altındakiler GENEL orana düşer.
    SELECT u.Kategori3 AS Kat,
           SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < ? THEN -h.ehAdetN ELSE 0 END) AS Gecen,
           SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < ? THEN -h.ehAdetN ELSE 0 END) AS Bu
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK) ON u.stkID = h.ehstkID
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY u.Kategori3
),
yl AS (        -- YILLIK: sezon yılı 01.08.<sezon> – 31.07.<sezon+1> (365 gün)
    -- GMY kararı 15.09.2026: "01/08/2025-31/07/2026 arası olsun 365 gün".
    -- ⚠ Eski "365 günde satılan" [kesim−364, kesim] idi ve geçen sezonun başını
    --   KAÇIRIYORDU. Bu pencere geçen sezonu (Ağu–Eki) TAM İÇERİR ve bu sezona TAŞMAZ.
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
)
SELECT t.stkAd                                       AS [Ürün],
       t.Kategori3                                   AS [Kategori],
       {YOL}                                         AS [Kategori yolu],
       -- ⚠ stkKod BARKOD DEĞİLDİR (sql-server-conventions) — ikisi ayrı alan.
       --   Tabanda yalnız BarkodAna var; stkKod ürün master'ından okunur.
       -- ⚠ Taban kolonu 'Yayinevi' ama kaynağı UrunBilgi.mrkAd = MARKA.
       t.Yayinevi                                    AS [Marka / Yayınevi],
       u.stkKod                                      AS [Stok kodu],
       t.BarkodAna                                   AS [Barkod],
       CONVERT(int, ISNULL(gh.Adet, 0))              AS [Geçen yıl aynı dönem],
       CONVERT(int, ISNULL(bh.Adet, 0))              AS [Bu yıl 01.08–bugün],
       -- SEZON AYLARI AYRI (GMY 15.09.2026: "sezon 8 9 10 ayrı olsun").
       -- Taban Ay1/Ay2/Ay3 = geçen sezonun Ağu/Eyl/Eki'si; toplamları SezonToplam.
       t.Ay1                                         AS [Ağustos],
       t.Ay2                                         AS [Eylül],
       t.Ay3                                         AS [Ekim],
       CONVERT(int, ISNULL(gk.Adet, 0))              AS [Geçen yıl kalan dönem],
       CASE WHEN ISNULL(sn.Eyl, 0) <= 0 OR ISNULL(sn.Eki, 0) <= 0
            THEN N'EVET' ELSE N'' END                AS [Geçen yıl stoksuz kaldı],
       -- ÖLÇÜLEN kategori büyümesi (taban < 2.000 ise NULL → genel orana düşer)
       CONVERT(decimal(6,3), CASE WHEN kb.Gecen >= 2000
            THEN CONVERT(float, kb.Bu) / kb.Gecen END) AS [Kategori büyümesi],
       -- SATIRA FİİLEN UYGULANAN oran — formül bunu çarpar, gizli sabit YOK.
       -- ⚠ 4 HANE ve SQL de AYNI yuvarlanmış oranı kullanır: GÖSTERİLEN oran,
       --   ÇARPILAN oranın AYNISI olmalı (birim maliyette de aynı ilke).
       CONVERT(decimal(7,4), o.Oran)                 AS [Uygulanan büyüme],
       CONVERT(int, ISNULL(yl.Adet, 0))              AS [Yıllık toplam],
       -- BOŞ RAF: mağazanın stoğu 0 ama geçen yıl AYNI dilimde orada satmış.
       --   Toplam stok yeterliyse eylem SİPARİŞ değil TRANSFER'dir.
       (CASE WHEN t.StokFsm = 0 AND ISNULL(gks.Fsm,0) > 0 THEN 1 ELSE 0 END
      + CASE WHEN t.StokOzl = 0 AND ISNULL(gks.Ozl,0) > 0 THEN 1 ELSE 0 END
      + CASE WHEN t.StokIst = 0 AND ISNULL(gks.Ist,0) > 0 THEN 1 ELSE 0 END) AS [Boş raf],
       CONVERT(int,
         CASE WHEN t.StokFsm = 0 AND ISNULL(gks.Fsm,0) > 0 THEN CEILING(gks.Fsm * o.Oran) ELSE 0 END
       + CASE WHEN t.StokOzl = 0 AND ISNULL(gks.Ozl,0) > 0 THEN CEILING(gks.Ozl * o.Oran) ELSE 0 END
       + CASE WHEN t.StokIst = 0 AND ISNULL(gks.Ist,0) > 0 THEN CEILING(gks.Ist * o.Oran) ELSE 0 END)
                                                     AS [Transfer adet],
       t.StokFsm                                     AS [FSM],
       t.StokOzl                                  AS [Özlüce],
       t.StokIst                                     AS [İst.Yolu],
       t.MerkezStok                                  AS [Depo],
       -- ⚠ 4 HANE: 2 haneye yuvarlayıp sonra çarpınca toplam 313 ₺ sapıyordu
       --   (ölçüldü 15.09.2026). Excel'de GÖRÜNEN sayı, çarpılan sayı olmalı.
       CONVERT(decimal(18,4), t.SatisFiyat)          AS [Satış fiyatı],
       CONVERT(decimal(18,4), CASE WHEN {MALIYET_GECERLI}
            THEN t.BirimMaliyet END)                 AS [Birim maliyet]
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID
LEFT JOIN gh ON gh.stkID = t.stkID
LEFT JOIN bh ON bh.stkID = t.stkID
LEFT JOIN gk ON gk.stkID = t.stkID
LEFT JOIN gks ON gks.stkID = t.stkID
LEFT JOIN sn ON sn.stkID = t.stkID
LEFT JOIN kb ON kb.Kat = t.Kategori3
LEFT JOIN yl ON yl.stkID = t.stkID
-- ⚠ TABAN KALAN SEZON (gk), TÜM SEZON DEĞİL. Excel formülü zaten gk'dan hesaplıyordu
--   ama BURASI hâlâ t.SezonToplam kullanıyordu → SÜZME ve SIRALAMA eski tabana göre
--   yapılıyordu (düzeltildi 15.09.2026). Değerler doğru, seçim yanlıştı: sessiz sapma.
-- ⚠ NEGATİF TALEP OLMAZ: gk negatifse (iade > satış) sıfıra kırpılır.
-- ORAN: ? > 0 ise ELLE verilen düz oran; 0 ise ÖLÇÜLEN kategori büyümesi
-- (kategori tabanı < 2.000 ise 1,0 — büyüme UYDURULMAZ).
CROSS APPLY (SELECT Oran = CONVERT(decimal(7,4), CASE WHEN ? > 0 THEN ?
                  ELSE ISNULL(CASE WHEN kb.Gecen >= 2000
                       THEN CONVERT(float, kb.Bu) / kb.Gecen END, 1.0) END)) o
CROSS APPLY (SELECT Satilacak = CASE WHEN ISNULL(gk.Adet, 0) > 0
                        THEN CONVERT(int, CEILING(gk.Adet * o.Oran)) ELSE 0 END,
                    Elde      = t.MagazaStok + t.MerkezStok) s
-- SINIF ÖNCELİĞİ: sezonu bitti > açık > TRANSFER > fazla > denge.
-- TRANSFER, FAZLA'yı EZER: toplam fazla ama bir raf boşsa eylem "erit" değil "taşı".
CROSS APPLY (SELECT Sinif = CASE
        WHEN ISNULL(gk.Adet, 0) <= 0 THEN CASE WHEN t.MagazaStok + t.MerkezStok > 0
                                               THEN 3 ELSE 0 END   -- 3 SEZONU BİTTİ
        WHEN s.Satilacak > s.Elde THEN 1                           -- 1 AÇIK (satınalma)
        WHEN (CASE WHEN t.StokFsm = 0 AND ISNULL(gks.Fsm,0) > 0 THEN 1 ELSE 0 END
            + CASE WHEN t.StokOzl = 0 AND ISNULL(gks.Ozl,0) > 0 THEN 1 ELSE 0 END
            + CASE WHEN t.StokIst = 0 AND ISNULL(gks.Ist,0) > 0 THEN 1 ELSE 0 END) > 0
             THEN 4                                                -- 4 TRANSFER
        WHEN s.Elde > s.Satilacak THEN 2                           -- 2 FAZLA
        ELSE 0 END) g
WHERE t.Kesim = ? AND t.SezonYil = ?
  AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
  AND (? IS NULL OR t.Kategori3 = ?)       -- kategori süzgeci
  AND (? = 0 OR g.Sinif = 1)               -- yalnız AÇIK
  AND (? = 0 OR g.Sinif = 2)               -- yalnız FAZLA
  AND (? = 0 OR g.Sinif = 3)               -- yalnız SEZONU BİTTİ
  AND (? = 0 OR g.Sinif = 4)               -- yalnız TRANSFER
-- SIRALAMA MANTIĞI: PARAYA GÖRE, en büyük etkiden başlayarak.
--   AÇIK satırda kaçacak ciro (eksik adet × satış fiyatı) — en çok ciro kaçıran üstte.
--   FAZLA/SEZONU BİTTİ satırda bağlı sermaye (fazla adet × maliyet).
--   İkinci anahtar: aynı tutarda, bu sezon HAREKETLİ olan üstte (talebi kanıtlı).
ORDER BY CASE WHEN g.Sinif = 1 THEN (s.Satilacak - s.Elde) * t.SatisFiyat
              ELSE (s.Elde - s.Satilacak) * ISNULL(t.BirimMaliyet, 0) END DESC,
         ISNULL(bh.Adet, 0) DESC, t.stkID
"""

# ── SAYFA DÜZENİ ──────────────────────────────────────────────────────────────
# Türetilen her kolon FORMÜLDÜR; ham girdiler SQL'den gelir. Büyüme TEK HÜCREDE
# (B2) — değiştirilince tüm liste yeniden hesaplanır.
#   (ad, tip)  tip: "ham" = SQL kolonu · "f" = Excel formülü
DUZEN: list[tuple[str, str]] = [
    ("Ürün",                   "ham"),
    ("Kategori",               "ham"),
    ("Kategori yolu",          "ham"),
    ("Marka / Yayınevi",       "ham"),
    ("Stok kodu",              "ham"),
    ("Barkod",                 "ham"),
    ("Geçen yıl aynı dönem",   "ham"),   # 01.08 – kesimin ay/günü, GEÇEN yıl
    ("Bu yıl 01.08–bugün",     "ham"),   # AYNI pencere, BU yıl
    ("Değişim",                "f"),     # =Bu/Geçen  (aynı pencere → kıyaslanabilir)
    ("Ağustos",                "ham"),   # geçen sezon
    ("Eylül",                  "ham"),
    ("Ekim",                   "ham"),
    ("Geçen sezon TAMAMI",     "f"),     # =Ağustos+Eylül+Ekim (toplandığı GÖRÜNSÜN)
    ("Geçen yıl kalan dönem",  "ham"),
    ("Geçen yıl stoksuz kaldı", "ham"),   # sansür bayrağı → AÇIK ALT SINIR
    ("Kategori büyümesi",      "ham"),   # ÖLÇÜLEN (taban<2.000 ise boş)
    ("Uygulanan büyüme",       "ham"),   # satıra fiilen uygulanan oran   # kalan sezon diliminin GEÇEN yılki karşılığı
    ("Yıllık toplam",          "ham"),   # 01.08.<sezon> – 31.07.<sezon+1>, 365 gün (HER ŞEY)
    ("Sezon dışı",             "f"),     # =Yıllık toplam − Geçen sezon TAMAMI (Kas–Tem)
    ("Kalan sezon talebi",     "f"),     # =CEILING(Geçen yıl kalan dönem × (1+büyüme); 1)
    ("Boş raf",                "ham"),   # kaç mağazanın rafı boş (geçen yıl satmışken)
    ("Transfer adet",          "ham"),   # o boş raflara taşınacak adet
    ("FSM",                    "ham"),
    ("Özlüce",                 "ham"),
    ("İst.Yolu",               "ham"),
    ("Mağaza toplam",          "f"),     # =FSM+Özlüce+İst.Yolu
    ("Depo",                   "ham"),
    ("Toplam stok",            "f"),     # =Mağaza toplam+Depo
    ("AÇIK",                   "f"),     # =MAX(0; Kalan sezon talebi−Toplam stok)
    ("FAZLA",                  "f"),     # =MAX(0; Toplam stok−Kalan sezon talebi)
    ("Satış fiyatı",           "ham"),
    ("Birim maliyet",          "ham"),
    ("Tutar",                  "f"),
    ("Durum",                  "f"),   # pivot bu alanla AÇIK/FAZLA sayabiliyor
    # ── PİVOT YARDIMCILARI — LİSTE'de GİZLİ. Tek "Tutar" kolonuyla pivot, Durum'u
    #    kolon alanı yapmak zorunda kalıyordu ve 17 kolona yayılıp okunmaz oluyordu.
    #    Ayrı iki kolonla pivot düz ve okunur; LİSTE ise tek Tutar ile sade kalıyor.
    ("AÇIK ₺",                 "f"),
    ("FAZLA ₺",                "f"),
    ("Sezonu bitti ₺",         "f"),
]


# ══ AKSİYONA GÖRE GÖRÜNÜR KOLONLAR (satinalma-danisman kararı 15.09.2026) ═══════
# Danışman: "sorun kolon sayısı değil, tek tabloya ÜÇ AYRI KARARI sığdırmanız.
#   Rapor aksiyona göre bölünür, her aksiyon yalnız kendi kolonlarını görür."
#
# ⚠ KOLON SİLİNMİYOR, GİZLENİYOR. Formüller kolon HARFİNDEN gider; silmek zinciri
#   kırardı. Gizli kolon Excel'de tek hamlede geri açılır — veri kaybı yok.
#
# NEDEN bu ayrım (danışman gerekçesi):
#   · AÇIK listesi bir SİPARİŞ kararıdır. "Yıllık toplam"/"Sezon dışı" burada işe
#     yaramaz; karar "kalan sezonda ne kadar lazım" sorusudur.
#   · FAZLA listesi bir ERİTME kararıdır ve orada "Sezon dışı" KRİTİKTİR: sezon dışı
#     büyükse mal ölü değil, sezon sonrası satar → indirim yapma. Sıfıra yakınsa kilitli.
#   · Ağustos/Eylül/Ekim ayrı ayrı hiçbir kararı değiştirmiyor — faz bilgisi zaten
#     "Geçen yıl kalan" içinde. Ürün profili drill'ine ait, aksiyon listesine değil.
#   · "Sezon toplam" = "Geçen yıl aynı dönem" + "Geçen yıl kalan"; artık tabanın da
#     değil → saf tekrar.
KIMLIK = ["Ürün", "Kategori", "Kategori yolu", "Marka / Yayınevi", "Stok kodu", "Barkod"]
STOK = ["FSM", "Özlüce", "İst.Yolu", "Mağaza toplam", "Depo", "Toplam stok"]

MOD_KOLON: dict[str, list[str]] = {
    # SİPARİŞ kararı
    "acik": KIMLIK + ["Geçen yıl aynı dönem", "Bu yıl 01.08–bugün", "Değişim",
                      "Geçen yıl kalan dönem", "Geçen yıl stoksuz kaldı", "Uygulanan büyüme",
                      "Kalan sezon talebi"] + STOK
                   + ["Boş raf", "AÇIK", "Satış fiyatı", "Tutar", "Durum"],
    # ERİTME kararı — "Sezon dışı" burada belirleyici
    "fazla": KIMLIK + ["Bu yıl 01.08–bugün", "Yıllık toplam", "Sezon dışı",
                       "Uygulanan büyüme", "Kalan sezon talebi"] + STOK
                    + ["FAZLA", "Birim maliyet", "Tutar", "Durum"],
    # TRANSFER kararı — satınalma DEĞİL, mal zaten elde
    "transfer": KIMLIK + ["Bu yıl 01.08–bugün", "Geçen yıl kalan dönem",
                          "Boş raf", "Transfer adet"] + STOK
                       + ["Satış fiyatı", "Durum"],
    # İADE / gelecek sezon kararı
    "bitti": KIMLIK + ["Bu yıl 01.08–bugün", "Geçen yıl kalan dönem", "Yıllık toplam",
                       "Sezon dışı"] + STOK
                    + ["FAZLA", "Birim maliyet", "Tutar", "Durum"],
}

PARA = {"Satış fiyatı", "Birim maliyet"}


def ayir(n: float, para: bool = False) -> str:
    s = f"{n:,.0f}".replace(",", ".")
    return f"{s} ₺" if para else s


def pivot_kur(yol: str, kolon_sayisi: int, son_satir: int) -> str:
    """
    MARKA sayfasını GERÇEK PivotTable'a çevirir (Excel COM).

    GMY 15.09.2026: "marka sayfasını pivot tablo kullanarak veriden oluşturabilir miyiz".

    ⚠ NEDEN COM: openpyxl pivot tabloyu OKUR/KOPYALAR ama SIFIRDAN KURAMAZ (ölçüldü —
      openpyxl 3.1.2'de pivot.table modülü var, kurma API'si yok). xlsxwriter'da da yok.
      Excel COM 16.0 bu makinede mevcut (ölçüldü), o yüzden gerçek pivot kurulabiliyor.

    ⚠ PIVOT'UN KAZANCI: LİSTE'deki B2 büyümesi değiştirilip dosya kaydedilince pivot
      YENİDEN HESAPLANIR (RefreshOnFileOpen + sağ tık > Yenile). Önceki "değer" sayfası
      bayatlıyordu; canlı uyarı koymak zorunda kalmıştık. Pivot o sorunu KÖKTEN çözer.

    ⚠ SESSİZ BAŞARISIZLIK YASAK: Excel yoksa/meşgulse pivot KURULMAZ ve bu DÖNÜŞ
      DEĞERİNDE SÖYLENİR; dosya yine geçerli (değer tabanlı MARKA sayfası durur).
    """
    try:
        import win32com.client as win32
        import pythoncom
    except ImportError:
        return "KURULMADI — pywin32 yok (deger tabanli MARKA sayfasi duruyor)"

    son_kolon = get_column_letter(kolon_sayisi)
    pythoncom.CoInitialize()
    xl = None
    try:
        xl = win32.gencache.EnsureDispatch("Excel.Application")
        xl.Visible = False
        xl.DisplayAlerts = False
        wb = xl.Workbooks.Open(os.path.abspath(yol))
        try:
            liste = wb.Worksheets("LİSTE")
            # Eski DEĞER tabanlı MARKA sayfası gider; yerine pivot gelir.
            for ws in list(wb.Worksheets):
                if ws.Name == "MARKA":
                    ws.Delete()
            pws = wb.Worksheets.Add(After=liste)
            pws.Name = "MARKA"

            kaynak = f"LİSTE!$A$3:${son_kolon}${son_satir}"     # 3. satır = başlık
            cache = wb.PivotCaches().Create(SourceType=1, SourceData=kaynak)  # xlDatabase
            pt = cache.CreatePivotTable(TableDestination=pws.Range("A3"),
                                        TableName="MarkaPivot")
            pt.PivotFields("Marka / Yayınevi").Orientation = 1      # xlRowField
            # ⚠ Durum KOLON ALANI YAPILMADI: 4 değer × 3 durum = 17 kolona yayılıp
            #   okunmaz oluyordu (ölçüldü). Ayrı "AÇIK ₺"/"FAZLA ₺" alanlarıyla düz kalıyor.
            # ⚠ VERİ ALANI ADI, KAYNAK ALAN ADIYLA AYNI OLAMAZ — Excel 0x800A03EC verir
            #   (ölçüldü 15.09.2026: "AÇIK ₺" data field'ı aynı adlı sütunla çakıştı).
            #   Bu yüzden başlıklar "… toplam" ile ayrıldı.
            # ⚠ BİÇİM DİZGİSİ YEREL AYIRAÇLA OKUNUYOR: Türkçe Excel'de "#,##0" yazınca
            #   "," DECIMAL sayılıyor ve 21688 → "21688,0" görünüyordu (ölçüldü).
            #   Ayıraçları Excel'in kendisine sorup dizgiyi ona göre kuruyoruz.
            # ⚠ Application.International ERKEN BAĞLAMADA DEMET döner, çağrılabilir DEĞİL
            #   (ölçüldü: xl.International(4) → TypeError 'tuple' object is not callable).
            #   Hem demet hem çağrı biçimi denenir; ikisi de olmazsa Türkçe varsayılana düşer
            #   ve bu SESSİZ DEĞİL — biçim yine de okunur çıkar.
            def ayirac(sira: int, varsayilan: str) -> str:
                try:
                    return str(xl.International[sira - 1])
                except Exception:
                    try:
                        return str(xl.International(sira))
                    except Exception:
                        return varsayilan

            bicim_hata: list[str] = []
            binlik = ayirac(4, ".")            # xlThousandsSeparator
            tamsayi = f"#{binlik}##0"
            para = f'#{binlik}##0 "₺"'
            cf = pt.AddDataField(pt.PivotFields("Ürün"), "Çeşit", -4112)   # xlCount
            for alan, ad, bicim in (("AÇIK", "AÇIK adet", tamsayi),
                                    ("AÇIK ₺", "AÇIK toplam ₺", para),
                                    ("FAZLA", "FAZLA adet", tamsayi),
                                    ("FAZLA ₺", "FAZLA toplam ₺", para),
                                    # ⚠ Ad çakışması BÜYÜK/küçük harfe DUYARSIZ: "SEZONU BİTTİ ₺" ile kaynak
                                    #   kolon "Sezonu bitti ₺" Excel için AYNI addır → 0x800A03EC.
                                    ("Sezonu bitti ₺", "SEZONU BİTTİ toplam ₺", para)):
                f = pt.AddDataField(pt.PivotFields(alan), ad, -4157)  # xlSum
                # ⚠ BİÇİM İSTEĞE BAĞLI: yerel biçim dizgisi reddedilebiliyor (0x800A03EC).
                #   Pivot'un KENDİSİ biçimden önemli — biçim tutmazsa pivot yine kurulur,
                #   sayı ham görünür. Sessiz değil: aşağıda bicim_hata sayılıp döndürülür.
                try:
                    f.NumberFormat = bicim
                except Exception:
                    bicim_hata.append(ad)
            try:
                cf.NumberFormat = tamsayi
            except Exception:
                bicim_hata.append("Çeşit")
            pt.RowAxisLayout(1)                                       # tablo düzeni
            # AÇIK tutarına göre büyükten küçüğe — alıcı en büyük açıktan başlasın.
            try:
                pt.PivotFields("Marka / Yayınevi").AutoSort(2, "AÇIK toplam ₺")  # xlDescending
            except Exception:
                pass   # sıralama kurulamazsa pivot yine geçerli; alfabetik kalır
            # Kaydedilince yeniden hesapla — büyüme değişirse pivot bayatlamasın.
            pt.PivotCache().RefreshOnFileOpen = True

            pws.Range("A1").Value = (
                "MARKA PİVOTU — kaynak LİSTE sayfası. LİSTE'de B2 büyümesini değiştirip "
                "kaydettikten sonra pivota sağ tık > Yenile (dosya yeniden açılınca "
                "kendiliğinden yenilenir). ⚠ ₺ sütunu AÇIK'ta satış fiyatı, FAZLA'da "
                "maliyettir — İKİSİ TOPLANMAZ, o yüzden Durum kırılımı ayrık duruyor.")
            pws.Range("A1").Font.Italic = True
            pws.Columns("A").ColumnWidth = 34
            wb.Save()
            ek = (f" · biçim uygulanamadı: {", ".join(bicim_hata)}"
                  if bicim_hata else "")
            return f"KURULDU — MarkaPivot ({kaynak}){ek}"
        finally:
            wb.Close(SaveChanges=False)
    except Exception as ex:                       # noqa: BLE001 — sebebi DÖNÜŞTE yazılıyor
        # ⚠ SESSİZ HATA YASAK: yalnız tipi değil, HANGİ SATIRDA patladığı da söylenir.
        #   Tek satırlık "KURULAMADI" mesajı teşhis ettirmiyordu (üç tur kaybedildi).
        import traceback
        iz = traceback.extract_tb(ex.__traceback__)
        yer = f"{iz[-1].lineno}: {iz[-1].line}" if iz else "?"
        return (f"KURULAMADI ({type(ex).__name__}: {ex}) @ satir {yer} "
                "— deger tabanli MARKA sayfasi duruyor")
    finally:
        if xl is not None:
            try:
                xl.Quit()
            except Exception:
                pass
        pythoncom.CoUninitialize()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kesim", default=None)
    ap.add_argument("--sezon", type=int, default=2025)
    # ⚠ VARSAYILAN ARTIK ÖLÇÜM. --buyume verilirse DÜZ oran uygulanır ve bu,
    #   raporun yüzüne "ELLE GİRİLDİ" diye yazılır (danışman şartı).
    ap.add_argument("--buyume", type=float, default=None,
                    help="ELLE duz buyume (or. 0.20). Verilmezse kategori bazli OLCULUR")
    ap.add_argument("--durum", choices=["acik", "fazla", "bitti", "transfer"],
                    default=None,
                    help="acik(satinalma) / transfer / fazla / bitti")
    ap.add_argument("--kategori", default=None,
                    help="tek Kategori3 (or. Kirtasiye) — bos ise hepsi")
    # PENCERE — GMY kararı 15.09.2026: "okul açılışına takılma, rapor 01/08'den başlasın,
    # sezon 8 9 10 olsun". Sen BU yılın penceresini verirsin; GEÇEN yılınki aynı ay/güne
    # OTOMATİK aynalanır → iki pencere her zaman EŞİT uzunlukta, bozulamaz.
    # ⚠ BEYAN: bu TAKVİM hizalamasıdır, okul hizalaması DEĞİL. Okul açılışı kayıyor
    #   (08.09.2025 → 14.09.2026) ve ölçüldüğünde bazı kategorilerde YÖNÜ çeviriyor
    #   (Hazırlık Kitapları takvimle 0,727 · okula hizalı 1,104). Karar bilerek takvim yönünde.
    ap.add_argument("--pencere-bas", default=None,
                    help="bu yilin pencere basi (vars. 01.08.<kesim yili>)")
    ap.add_argument("--pencere-son", default=None,
                    help="bu yilin pencere sonu, DAHIL (vars. kesim; sezon sonu 31.10'u asmaz)")
    ap.add_argument("--pivot", action=argparse.BooleanOptionalAction, default=True,
                    help="MARKA sayfasini GERCEK PivotTable yap (Excel COM gerekir)")
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()

    # SQL'e giden oran: elle verildiyse (1+x), verilmediyse 0 → ölçüm kullanılır.
    buyume_sql = (1.0 + a.buyume) if a.buyume is not None else 0.0
    yalniz_acik = 1 if a.durum == "acik" else 0
    yalniz_fazla = 1 if a.durum == "fazla" else 0
    yalniz_bitti = 1 if a.durum == "bitti" else 0
    yalniz_transfer = 1 if a.durum == "transfer" else 0
    kategori = a.kategori.strip() if a.kategori and a.kategori.strip() else None
    SEZON_BAS_AY, SEZON_SON_AY = 8, 10          # GMY: "sezon 8 9 10 olsun"

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        cur = cn.cursor()
        if a.kesim:
            kesim = dt.date.fromisoformat(a.kesim)
        else:
            cur.execute("SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban")
            r = cur.fetchone()
            if not r or not r[0]:
                kosamadi("Taban BOS — kesim okunamadi (sessizlik kanit degil)")
            kesim = r[0] if isinstance(r[0], dt.date) else dt.date.fromisoformat(str(r[0])[:10])

        # ── PENCERE: bu yıl seçilir, geçen yıl AYNALANIR ────────────────────
        try:
            b_bas = (dt.date.fromisoformat(a.pencere_bas) if a.pencere_bas
                     else dt.date(kesim.year, SEZON_BAS_AY, 1))
            b_son = dt.date.fromisoformat(a.pencere_son) if a.pencere_son else kesim
        except ValueError as ex:
            kosamadi(f"Gecersiz pencere tarihi: {ex}")
        # Sezon sonunu (31 Ekim) aşma.
        sezon_sonu = dt.date(b_son.year, SEZON_SON_AY, 31)
        if b_son > sezon_sonu:
            b_son = sezon_sonu
        if b_son < b_bas:
            kosamadi(f"Pencere sonu ({b_son}) basindan ({b_bas}) once olamaz")

        def aynala(d: dt.date, yil: int) -> dt.date:
            """Ay/günü başka yıla taşı. 29 Şubat gibi olmayan güne düşerse bir gün geri al."""
            try:
                return d.replace(year=yil)
            except ValueError:
                return d.replace(year=yil, day=d.day - 1)

        # KALAN sezon dilimi: bu yıl kesimin ERTESİ günü – 31.10; geçen yıl AYNASI.
        # ⚠ AÇIK'ın tabanı budur, tüm sezon DEĞİL (GMY 15.09.2026). Geçen günlerin malı
        #   zaten satıldı; tüm sezonu istemek açığı 2,4 kat şişiriyordu (254,7M → 106,9M ₺).
        sezon_sonu_bu = dt.date(b_son.year, SEZON_SON_AY, 31)
        gk_bas_bu, gk_son_bu = b_son + dt.timedelta(days=1), sezon_sonu_bu
        if gk_bas_bu > gk_son_bu:
            kosamadi(f"Sezon bitmis ({b_son} > {sezon_sonu_bu}) — kalan talep yok")

        # YILLIK pencere: sezon başından bir sonraki sezon başının bir gün öncesine.
        y_bas = dt.date(a.sezon, SEZON_BAS_AY, 1)
        y_son = dt.date(a.sezon + 1, SEZON_BAS_AY, 1) - dt.timedelta(days=1)

        yil_farki = kesim.year - a.sezon
        g_bas, g_son = aynala(b_bas, b_bas.year - yil_farki), aynala(b_son, b_son.year - yil_farki)
        gk_bas = aynala(gk_bas_bu, gk_bas_bu.year - yil_farki)
        gk_son = aynala(gk_son_bu, gk_son_bu.year - yil_farki)
        # SANSÜR bayrağı: geçen yılın KALAN dilimi İÇİNDEKİ ay sonları (ay-sonu snapshot
        # tablosu yalnız ay sonlarını tutar). Dilim başının ayının sonu + dilim sonunun ayı.
        def ay_sonu(d: dt.date) -> dt.date:
            ilk_sonraki = dt.date(d.year + (d.month == 12), (d.month % 12) + 1, 1)
            return ilk_sonraki - dt.timedelta(days=1)

        sn_eyl, sn_eki = ay_sonu(gk_bas), ay_sonu(gk_son)
        # ⚠ EŞİT UZUNLUK ZORUNLU: farklı uzunlukta iki pencere SAHTE büyüme üretir ve
        #   hata vermez. Bugün ölçülen 44/45 gün sapmasının sınıfı budur.
        if (b_son - b_bas).days != (g_son - g_bas).days:
            kosamadi(f"Pencereler esit uzunlukta degil: bu {(b_son - b_bas).days + 1} gun, "
                     f"gecen {(g_son - g_bas).days + 1} gun")

        # Sıra SQL'deki ? sırasıdır; biri değişirse ikisi birden değişir.
        # ⚠ Üst sınır DIŞLAYICI (son + 1 gün, gece yarısı) — "23:59:59" yazılmaz.
        cur.execute(SQL,
                    g_bas, g_son + dt.timedelta(days=1),   # gh — GEÇEN yıl
                    b_bas, b_son + dt.timedelta(days=1),   # bh — BU yıl
                    gk_bas, gk_son + dt.timedelta(days=1),  # gk — GEÇEN yılın KALAN dilimi
                    gk_bas, gk_son + dt.timedelta(days=1),  # gks — aynı dilim, MAĞAZA bazlı
                    sn_eyl, sn_eki, sn_eyl, sn_eki,        # sn — sansür bayrağı ay sonları
                    g_bas, g_son + dt.timedelta(days=1),   # kb — geçen yıl 44 gün
                    b_bas, b_son + dt.timedelta(days=1),   # kb — bu yıl 44 gün
                    g_bas, b_son + dt.timedelta(days=1),   # kb — tarama aralığı
                    y_bas, y_son + dt.timedelta(days=1),   # yl — YILLIK 365 gün
                    buyume_sql, buyume_sql,                # CROSS APPLY oran (elle / 0=ölçüm)
                    kesim, a.sezon, kategori, kategori,
                    yalniz_acik, yalniz_fazla, yalniz_bitti, yalniz_transfer)
        bas = [d[0] for d in cur.description]
        sat = [list(x) for x in cur.fetchall()]
    finally:
        cn.close()

    if not sat:
        kosamadi(f"Liste BOS dondu (kesim {kesim}, sezon {a.sezon})")

    ix = {b: i for i, b in enumerate(bas)}
    for ad, tip in DUZEN:
        if tip == "ham" and ad not in ix:
            kosamadi(f"Ham kolon '{ad}' sorgudan gelmedi — DUZEN ile SQL ayrismis")

    # ══ FORMÜLLÜ TEK SAYFA ════════════════════════════════════════════════════
    # GMY 15.09.2026: "formüllü olsun ne nerden geliyor gözüksün" + "mağaza bazlı
    # stoklarda olmalı" + "katana kısmı da olmalı".
    #
    # Türetilen HİÇBİR sayı dosyaya hazır yazılmaz — hepsi hücre formülüdür ve
    # kaynak hücreye bakar. Büyüme TEK hücrede (B2): değiştirilince 85 bin satır
    # yeniden hesaplanır. "Bu rakam nereden geliyor?" sorusu hücreye tıklayarak
    # cevaplanır; bize sormaya gerek kalmaz.
    #
    # ⚠ Özet/toplam satırı YOK (GMY: "özete gerek yok"). Toplam isteyen kolonu
    #   seçer, Excel durum çubuğunda görür.
    kolonlar = [ad for ad, _ in DUZEN]
    K = {ad: get_column_letter(j) for j, (ad, _) in enumerate(DUZEN, start=1)}

    # ── BAŞLIKTA TARİH (GMY 15.09.2026: "kolonların içinde tarihler de olsun kafa
    #    karışmasın"). İÇ ANAHTAR değişmez — yalnız GÖRÜNEN ad tarihlenir; formüller
    #    K[anahtar] ile kolon harfinden gider, bu yüzden ad değişimi hiçbir şeyi kırmaz.
    ay_adi = {8: "Ağustos", 9: "Eylül", 10: "Ekim"}
    GOSTER = {
        "Geçen yıl aynı dönem": f"Geçen yıl\n{g_bas:%d.%m.%y}–{g_son:%d.%m.%y}",
        "Bu yıl 01.08–bugün":   f"Bu yıl\n{b_bas:%d.%m.%y}–{b_son:%d.%m.%y}",
        "Değişim":              "Değişim\n(bu ÷ geçen)",
        "Ağustos":              f"{ay_adi[8]} {a.sezon}",
        "Eylül":                f"{ay_adi[9]} {a.sezon}",
        "Ekim":                 f"{ay_adi[10]} {a.sezon}",
        "Geçen sezon TAMAMI":   f"Sezon toplam\n01.08.{a.sezon % 100:02d}–31.10.{a.sezon % 100:02d}",
        "Yıllık toplam":        f"Yıllık toplam\n{y_bas:%d.%m.%y}–{y_son:%d.%m.%y}",
        "Sezon dışı":           f"Sezon dışı\n01.11.{a.sezon % 100:02d}–{y_son:%d.%m.%y}",
        "Geçen yıl kalan dönem": f"Geçen yıl kalan\n{gk_bas:%d.%m.%y}–{gk_son:%d.%m.%y}",
        "Geçen yıl stoksuz kaldı": f"Geçen yıl stoksuz\n(talep EKSİK ölçüldü)",
        "Kategori büyümesi":    f"Kategori büyümesi\n(ölçülen, 44 gün)",
        "Uygulanan büyüme":     f"Uygulanan büyüme\n(bu satıra)",
        "Kalan sezon talebi":   f"KALAN sezon talebi\n{gk_bas_bu:%d.%m.%y}–{gk_son_bu:%d.%m.%y}",
        "Boş raf":              f"Boş raf\n(mağaza sayısı)",
        "Transfer adet":        f"Transfer adet\n{gk_bas_bu:%d.%m.%y}–{gk_son_bu:%d.%m.%y}",
        "FSM":                  f"FSM\n{kesim:%d.%m.%y}",
        "Özlüce":               f"Özlüce\n{kesim:%d.%m.%y}",
        "İst.Yolu":             f"İst.Yolu\n{kesim:%d.%m.%y}",
        "Mağaza toplam":        f"Mağaza toplam\n{kesim:%d.%m.%y}",
        "Depo":                 f"Depo\n{kesim:%d.%m.%y}",
        "Toplam stok":          f"Toplam stok\n{kesim:%d.%m.%y}",
        "Tutar":                "Tutar\n(AÇIK'ta fiyat, FAZLA'da maliyet)",
    }
    BAS_SATIR = 4                      # 1 not · 2 büyüme · 3 başlık · 4+ veri

    wb = Workbook()
    ws = wb.active
    ws.title = "LİSTE"

    # ⚠ SÜZGEÇ DOSYANIN YÜZÜNDE YAZAR. Yazmazsa açan kişi "tamamı mı, süzülmüş mü"
    #   ayırt edemez — GMY 15.09.2026'da tam bu oldu ("excelde tamamı var").
    suzgec = []
    if kategori:
        suzgec.append(f"KATEGORİ: {kategori}")
    if a.durum:
        suzgec.append({"acik": "YALNIZ AÇIK (eksik olanlar)",
                       "fazla": "YALNIZ FAZLA",
                       "bitti": "YALNIZ SEZONU BİTTİ"}[a.durum])
    suzgec_metni = (" ⚠ SÜZÜLMÜŞ — " + " · ".join(suzgec) + " ⚠ · "
                    if suzgec else "SÜZGEÇ YOK (tüm evren) · ")
    # Gizlenen kolon SESSİZ kalmaz: kaç tane ve nasıl geri açılacağı yazılır.
    gizli_not = ""
    if a.durum in MOD_KOLON:
        kac = len([ad for ad, _ in DUZEN if ad not in set(MOD_KOLON[a.durum])])
        gizli_not = (f"Bu aksiyonun kararını değiştirmeyen {kac} kolon GİZLENDİ "
                     "(silinmedi — tüm sayfayı seçip 'Sütunları Göster' ile açılır) · ")

    ust = (suzgec_metni + gizli_not
           + f"Kesim {kesim:%d.%m.%Y} · sezon {a.sezon} (Ağu–Eki) · "
           f"AYNI PENCERE: geçen {g_bas:%d.%m.%Y}–{g_son:%d.%m.%Y} · "
           f"bu {b_bas:%d.%m.%Y}–{b_son:%d.%m.%Y} ({(b_son - b_bas).days + 1} gün, eşit) · "
           f"YILLIK toplam {y_bas:%d.%m.%Y}–{y_son:%d.%m.%Y} ({(y_son - y_bas).days + 1} gün, "
           "HER ŞEY dahil) · Sezon dışı = yıllık − sezon (Kas–Tem; iade fazlaysa EKSİ olur, "
           "29 çeşitte öyle) · "
           f"KALAN SEZON {gk_bas_bu:%d.%m.%y}–{gk_son_bu:%d.%m.%y} (geçen yıl karşılığı {gk_bas:%d.%m.%y}–{gk_son:%d.%m.%y}) — AÇIK/FAZLA bunun üzerinden; sezonun GEÇEN günleri zaten satıldı · "
           "DURUM dört sınıf: AÇIK · FAZLA · SEZONU BİTTİ (geçen yıl kalan dilimde hiç satmamış → bu sezon talebi yok) · DENGE · "
           "SARI kolonlar FORMÜLDÜR (hücreye tıkla, hesabı gör) · "
           "Tutar: AÇIK'ta satış fiyatı, FAZLA'da maliyet — ikisi toplanmaz · "
           "Açık sipariş DÜŞÜLMEDİ (ERP'de kapatma alanı 24.02.2025'ten beri yazılmıyor) · "
           "Birim maliyeti olmayan üründe Tutar boş kalır (para ALT SINIR) · "
           "depo stoğu WMS'ten · tek gün fotoğrafı · "
           "⚠ TAKVİM hizası — okul açılışı kayıyor (08.09.2025→14.09.2026), bu pencere onu görmez")
    ws.cell(1, 1, ust).font = Font(italic=True, size=9, color="555555")
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(kolonlar))
    ws.cell(1, 1).alignment = Alignment(wrap_text=True, vertical="center")
    ws.row_dimensions[1].height = 32

    # ── BÜYÜME: tek hücre, tüm sayfanın girdisi ──────────────────────────────
    # ⚠ TEK BÜYÜME KADRANI KALDIRILDI (danışman kararı 15.09.2026). Oran artık her
    #   satırda "Uygulanan büyüme" kolonunda ve kategori bazlı ÖLÇÜLDÜ. Tek kutu,
    #   alıcının aynı hamleyle hem siparişi haklı çıkarıp hem fazlasını silmesine
    #   izin veriyordu.
    ws.cell(2, 1, "Büyüme:").font = Font(bold=True, size=10)
    bh = ws.cell(2, 2, ("ELLE GİRİLDİ %{:g}".format(a.buyume * 100)
                        if a.buyume is not None
                        else "KATEGORİ BAZLI ÖLÇÜLDÜ (aynı 44 gün, iki yıl)"))
    bh.font = Font(bold=True, size=11, color=("C00000" if a.buyume is not None else "1F3864"))
    bh.fill = SARI
    if suzgec:
        sh = ws.cell(2, 5, "SÜZÜLMÜŞ RAPOR: " + " · ".join(suzgec))
        sh.font = Font(bold=True, color="C00000", size=11)
    ws.cell(2, 4, "oran satır bazlı: 'Uygulanan büyüme' kolonunu değiştir → o satırın "
                  "talebi, AÇIK/FAZLA ve Tutar yeniden hesaplanır"
            ).font = Font(italic=True, size=9, color="555555")

    for j, ad in enumerate(kolonlar, start=1):
        h = ws.cell(3, j, GOSTER.get(ad, ad))
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    ws.row_dimensions[3].height = 40

    for i, r in enumerate(sat, start=BAS_SATIR):
        for j, (ad, tip) in enumerate(DUZEN, start=1):
            if tip == "ham":
                v = r[ix[ad]]
                c = ws.cell(i, j, v)
                if ad in PARA:
                    c.number_format = '#,##0.0000 "₺"'
                elif isinstance(v, int):
                    c.number_format = "#,##0"
                continue

            # ── FORMÜL — kaynağı hücreden okur, sabit gömmez ─────────────────
            f = {
                "Geçen sezon TAMAMI": (f'={K["Ağustos"]}{i}+{K["Eylül"]}{i}+{K["Ekim"]}{i}'),
                # ⚠ AÇIK'ın tabanı TÜM SEZON DEĞİL, KALAN sezondur (GMY 15.09.2026).
                #   Geçen günlerin malı zaten satıldı; tüm sezonu istemek açığı 2,4 kat şişiriyordu.
                # ⚠ MAX(0;…) ŞART: geçen yıl kalan dilimde iade satıştan fazlaysa "Geçen yıl
                #   kalan" NEGATİF olur ve talep eksiye düşerdi. Negatif talep anlamsızdır;
                #   dahası stoğu SIFIR olan ürünü "fazla" göstererek hayalet üretiyordu
                #   (ölçüldü 15.09.2026: 27 üründe negatif, 4'ü stoksuz, 29 adet hayalet fazla).
                # ⚠ ORAN ARTIK SATIRDAN GELİYOR, tek hücreden DEĞİL. Danışman:
                #   "tek kadran hem AÇIK'ı büyütüp hem FAZLA'yı küçültüyor — bir
                #   parametre, iki savunma." Oran kategori bazlı ÖLÇÜLDÜ ve kolonda.
                "Kalan sezon talebi": (f'=MAX(0,CEILING({K["Geçen yıl kalan dönem"]}{i}'
                                      f'*{K["Uygulanan büyüme"]}{i},1))'),
                # AYNI PENCERE olduğu için bu oran kıyaslanabilir. Geçen yıl 0 ise
                # bölme yapılmaz (BOŞ) — "sonsuz büyüme" uydurmak olurdu.
                "Değişim": (f'=IF({K["Geçen yıl aynı dönem"]}{i}>0,'
                            f'{K["Bu yıl 01.08–bugün"]}{i}/{K["Geçen yıl aynı dönem"]}{i},"")'),
                # SEZON DIŞI = yıllık − sezon → Kasım–Temmuz net satışı.
                # ⚠ EKSİ ÇIKABİLİR ve bu GERÇEKTİR: o aylarda iade satıştan fazlaysa net
                #   negatiftir (ölçüldü: 85.274 çeşidin 29'u; stkID 1545705 Haz-2026'da
                #   13 adet iade). Sıfıra kırpılmıyor — kırpmak iadeyi gizlemek olurdu.
                "Sezon dışı": (f'={K["Yıllık toplam"]}{i}-{K["Geçen sezon TAMAMI"]}{i}'),
                "Mağaza toplam": f'={K["FSM"]}{i}+{K["Özlüce"]}{i}+{K["İst.Yolu"]}{i}',
                "Toplam stok":   f'={K["Mağaza toplam"]}{i}+{K["Depo"]}{i}',
                "AÇIK":          f'=MAX(0,{K["Kalan sezon talebi"]}{i}-{K["Toplam stok"]}{i})',
                "FAZLA":         f'=MAX(0,{K["Toplam stok"]}{i}-{K["Kalan sezon talebi"]}{i})',
                # AÇIK varsa satış fiyatıyla, FAZLA varsa maliyetle. Maliyet boşsa
                # BOŞ bırakılır — 0 yazmak "fazlası bedava" demek olurdu.
                "Tutar": (f'=IF({K["AÇIK"]}{i}>0,{K["AÇIK"]}{i}*{K["Satış fiyatı"]}{i},'
                          f'IF(AND({K["FAZLA"]}{i}>0,{K["Birim maliyet"]}{i}<>""),'
                          f'{K["FAZLA"]}{i}*{K["Birim maliyet"]}{i},""))'),
                # Metin alan: PivotTable AÇIK/FAZLA ürününü bununla SAYAR (koşullu sayım yok).
                # ⚠ DÖRT SINIF (GMY 15.09.2026: "kalan sezonda satış olmayanları da ayrı göster").
                #   Geçen yıl kalan dilimde HİÇ satmamış ürünün bu sezon talebi YOK; stoğu
                #   "fazla" ama EYLEMİ farklı: indirimle dönmez, iade/gelecek sezon konusudur.
                #   Ölçüldü: 19.940 çeşit · 215.955 adet · 20,6M ₺ maliyet. FAZLA'nın içindeydi
                #   ve 128,8M ₺'nin 20,6M'sini tek başına oluşturuyordu.
                # BEŞ SINIF. TRANSFER, FAZLA'yı EZER: toplam fazla olsa bile bir raf
                # boşsa eylem "erit" değil "taşı" — sipariş de gerekmez.
                "Durum": (f'=IF({K["Geçen yıl kalan dönem"]}{i}<=0,'
                          f'IF({K["Toplam stok"]}{i}>0,"SEZONU BİTTİ","DENGE"),'
                          f'IF({K["AÇIK"]}{i}>0,"AÇIK",'
                          f'IF({K["Boş raf"]}{i}>0,"TRANSFER",'
                          f'IF({K["FAZLA"]}{i}>0,"FAZLA","DENGE"))))'),
                "AÇIK ₺":  f'=IF({K["Durum"]}{i}="AÇIK",{K["Tutar"]}{i},0)',
                "FAZLA ₺": (f'=IF({K["Durum"]}{i}="FAZLA",'
                            f'IF({K["Tutar"]}{i}="",0,{K["Tutar"]}{i}),0)'),
                "Sezonu bitti ₺": (f'=IF({K["Durum"]}{i}="SEZONU BİTTİ",'
                                   f'IF({K["Tutar"]}{i}="",0,{K["Tutar"]}{i}),0)'),
            }[ad]
            c = ws.cell(i, j, f)
            c.fill = SARI
            c.number_format = ('#,##0.00 "₺"' if ad in ("Tutar", "AÇIK ₺", "FAZLA ₺",
                                                                        "Sezonu bitti ₺")
                               else "0.00" if ad == "Değişim"
                               else "General" if ad == "Durum" else "#,##0")

    genis = {"Ürün": 45, "Yıllık toplam": 13, "Sezon dışı": 12, "Durum": 10, "Kategori yolu": 40, "Kategori": 18, "Barkod": 15, "Stok kodu": 13, "Marka / Yayınevi": 22}
    for j, ad in enumerate(kolonlar, start=1):
        gor = GOSTER.get(ad, ad)
        en_uzun = max((len(p) for p in gor.split("\n")), default=len(ad))
        ws.column_dimensions[get_column_letter(j)].width = genis.get(ad, max(en_uzun + 2, 11))
    # Pivot yardımcıları HER ZAMAN gizli.
    gizlenecek = {"AÇIK ₺", "FAZLA ₺", "Sezonu bitti ₺"}
    # Aksiyon seçiliyse o aksiyonun görmediği kolonlar da gizlenir (SİLİNMEZ).
    if a.durum in MOD_KOLON:
        gorunur = set(MOD_KOLON[a.durum])
        gizlenecek |= {ad for ad, _ in DUZEN if ad not in gorunur}
    for gizli in gizlenecek:
        ws.column_dimensions[K[gizli]].hidden = True

    ws.freeze_panes = f"E{BAS_SATIR}"
    ws.auto_filter.ref = f"A3:{get_column_letter(len(kolonlar))}{len(sat) + BAS_SATIR - 1}"

    # ══ MARKA ÖZETİ ═══════════════════════════════════════════════════════════
    # GMY 15.09.2026: "marka bazlı özet sayfası da yapalım formüllü excel için".
    #
    # ⚠ NEDEN FORMÜL DEĞİL, DEĞER: ölçüldü — kohortta 2.636 ayrı marka var ve liste
    #   85.274 satır. Marka başına SUMIFS/COUNTIFS (7 formül) yazılsaydı Excel her
    #   yeniden hesapta 2.636 × 7 × 85.274 ≈ 1,6 milyar hücre karşılaştırması yapardı.
    #   (Excel'de SÜRE ÖLÇÜLMEDİ — bu bir ÇIKARIM; ama risk alınmadı.)
    #
    # ⚠ DEĞER OLUNCA BAYATLAMA RİSKİ DOĞAR: LİSTE'de B2 büyümesi değişirse bu sayfa
    #   ESKİ büyümeye göre kalır ve sessizce yanlış olur. O yüzden sayfada B2'yi izleyen
    #   TEK CANLI FORMÜL var: büyüme değişirse kırmızı uyarı çıkar. Sessiz bayatlama yok.
    mws = wb.create_sheet("MARKA")

    marka: dict[str, list] = {}
    import math as _m
    for r in sat:
        ad = (r[ix["Marka / Yayınevi"]] or "(marka yok)").strip() or "(marka yok)"
        satilacak = max(0, _m.ceil((r[ix["Geçen yıl kalan dönem"]] or 0)
                                   * float(r[ix["Uygulanan büyüme"]] or 1)))
        elde = ((r[ix["FSM"]] or 0) + (r[ix["Özlüce"]] or 0)
                + (r[ix["İst.Yolu"]] or 0) + (r[ix["Depo"]] or 0))
        g = marka.setdefault(ad, [0, 0, 0, 0.0, 0, 0, 0.0, 0, 0])
        g[0] += 1                                   # çeşit
        if satilacak > elde:
            g[1] += 1                               # AÇIK ürün
            g[2] += satilacak - elde                # AÇIK adet
            g[3] += (satilacak - elde) * float(r[ix["Satış fiyatı"]] or 0)
        elif elde > satilacak:
            g[4] += 1                               # FAZLA ürün
            g[5] += elde - satilacak                # FAZLA adet
            mal = r[ix["Birim maliyet"]]
            if mal is not None:
                g[6] += (elde - satilacak) * float(mal)
        g[7] += r[ix["Geçen yıl aynı dönem"]] or 0
        g[8] += r[ix["Bu yıl 01.08–bugün"]] or 0

    mbas = ["Marka / Yayınevi", "Çeşit", "AÇIK ürün", "AÇIK adet", "AÇIK ₺",
            "FAZLA ürün", "FAZLA adet", "FAZLA ₺",
            f"Geçen yıl\n{g_bas:%d.%m.%y}–{g_son:%d.%m.%y}",
            f"Bu yıl\n{b_bas:%d.%m.%y}–{b_son:%d.%m.%y}", "Değişim"]

    mnot = (f"Marka bazlı özet · kesim {kesim:%d.%m.%Y} · oran "
            + ("ELLE %{:g}".format(a.buyume * 100) if a.buyume is not None
               else "KATEGORİ BAZLI ÖLÇÜLDÜ") + " · "
            f"{len(marka):,} marka".replace(",", ".") + " · "
            "Tutarlar LİSTE ile aynı tabandan: AÇIK satış fiyatıyla, FAZLA maliyetle — "
            "İKİSİ TOPLANMAZ. Değişim = bu dönem ÷ geçen dönem (aynı pencere).")
    mws.cell(1, 1, mnot).font = Font(italic=True, size=9, color="555555")
    mws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(mbas))
    mws.cell(1, 1).alignment = Alignment(wrap_text=True, vertical="center")
    mws.row_dimensions[1].height = 30

    # TEK CANLI FORMÜL — LİSTE!B2 değişirse bu sayfanın bayatladığını SÖYLER.
    # Tek kadran kalktığı için eski "B2 değişti mi" tuzak-formülü anlamsızlaştı;
    # oran artık satır bazlı. Yerine sabit uyarı: LİSTE'de oran değişirse bu özet bayat.
    uyari = mws.cell(2, 1, "⚠ Bu özet üretim anındaki oranlarla hesaplandı. LİSTE'de "
                           "'Uygulanan büyüme' değiştirilirse burası GÜNCELLENMEZ.")
    uyari.font = Font(bold=True, color="C00000", size=10)
    mws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=len(mbas))

    for j, b in enumerate(mbas, start=1):
        h = mws.cell(3, j, b)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    mws.row_dimensions[3].height = 40

    for i, (ad, g) in enumerate(sorted(marka.items(), key=lambda x: -x[1][3]), start=4):
        # Değişim: geçen dönem 0 ise oran YOK — sonsuz büyüme uydurulmaz.
        deg = (g[8] / g[7]) if g[7] > 0 else None
        for j, v in enumerate([ad, g[0], g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8], deg],
                              start=1):
            c = mws.cell(i, j, v)
            if j in (5, 8):
                c.number_format = '#,##0 "₺"'
            elif j == 11:
                c.number_format = "0.00"
            elif j > 1:
                c.number_format = "#,##0"

    mgenis = {"Marka / Yayınevi": 34}
    for j, b in enumerate(mbas, start=1):
        mws.column_dimensions[get_column_letter(j)].width = mgenis.get(b, max(len(b) + 2, 12))
    mws.freeze_panes = "B4"
    mws.auto_filter.ref = f"A3:{get_column_letter(len(mbas))}{len(marka) + 3}"

    # ── Konsol özeti — Excel'in hesaplayacağının AYNISI, Python'da ────────────
    #    (dosyada formül olduğu için openpyxl değer okuyamaz; kontrol burada)
    cesit = len(sat)
    acik_c = acik_a = fazla_c = fazla_a = malsiz = bitti_c = bitti_a = 0
    trans_c = trans_a = 0
    trans_tl = 0.0
    acik_tl = fazla_tl = bitti_tl = 0.0
    import math
    for r in sat:
        satilacak = max(0, math.ceil((r[ix["Geçen yıl kalan dönem"]] or 0)
                                     * float(r[ix["Uygulanan büyüme"]] or 1)))
        elde = ((r[ix["FSM"]] or 0) + (r[ix["Özlüce"]] or 0)
                + (r[ix["İst.Yolu"]] or 0) + (r[ix["Depo"]] or 0))
        bos_raf = r[ix["Boş raf"]] or 0
        bitti = (r[ix["Geçen yıl kalan dönem"]] or 0) <= 0
        if not bitti and satilacak > elde:
            acik_c += 1
            acik_a += satilacak - elde
            acik_tl += (satilacak - elde) * float(r[ix["Satış fiyatı"]] or 0)
        elif not bitti and bos_raf > 0:
            trans_c += 1
            trans_a += r[ix["Transfer adet"]] or 0
            trans_tl += (r[ix["Transfer adet"]] or 0) * float(r[ix["Satış fiyatı"]] or 0)
        elif elde > satilacak:
            m = r[ix["Birim maliyet"]]
            if bitti:
                bitti_c += 1
                bitti_a += elde - satilacak
            else:
                fazla_c += 1
                fazla_a += elde - satilacak
            if m is None:
                malsiz += 1
            elif bitti:
                bitti_tl += (elde - satilacak) * float(m)
            else:
                fazla_tl += (elde - satilacak) * float(m)

    # Dosya adı: Türkçe harfler DÜŞÜRÜLMEZ, karşılığına ÇEVRİLİR — "Krtasiye" gibi
    # okunmaz ad üretmesin (ı ve ş sessizce siliniyordu).
    TR = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")
    ek = ("-" + a.durum if a.durum else "")
    if kategori:
        ek += "-" + re.sub(r"[^A-Za-z0-9]+", "", kategori.translate(TR))
    cikti = a.cikti or os.path.join(
        KOK, "raporlar", f"sezon-aksiyon-listesi-{kesim:%Y%m%d}{ek}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)

    if a.pivot:
        pivot_durum = pivot_kur(cikti, len(kolonlar), len(sat) + BAS_SATIR - 1)
        print(f"  PIVOT: {pivot_durum}")

    print(f"YAZILDI: {cikti}")
    print(f"  cesit {ayir(cesit)}")
    print(f"  ACIK  {ayir(acik_c)} urun · {ayir(acik_a)} adet · {ayir(acik_tl)} TL")
    print(f"  FAZLA {ayir(fazla_c)} urun · {ayir(fazla_a)} adet · {ayir(fazla_tl)} TL")
    print(f"  TRANSFER {ayir(trans_c)} urun · {ayir(trans_a)} adet · {ayir(trans_tl)} TL")
    print(f"  SEZONU BITTI {ayir(bitti_c)} urun · {ayir(bitti_a)} adet · {ayir(bitti_tl)} TL")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
