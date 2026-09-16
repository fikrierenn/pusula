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

# OKUL AÇILIŞI — pencere buna hizalanır, takvime DEĞİL.
# ÖLÇÜLDÜ 15.09.2026: takvim hizasıyla Kırtasiye sezon tahmini 521.262, açılış
# hizasıyla 643.912 (%23,5 fark). Sebep: geçen yılın takvim penceresi okul
# açılışından SONRAKİ 6 günü içeriyor, bu yılınki içermiyor → pay şişiyor.
OKUL_ACILIS = {
    2023: dt.date(2023, 9, 11),
    2024: dt.date(2024, 9, 9),
    2025: dt.date(2025, 9, 8),
    2026: dt.date(2026, 9, 14),
}

SQL = f"""
-- ═══ SEZON PAYI YÖNTEMİ (GMY 15.09.2026) ═══════════════════════════════════
-- GMY verbatim: "sezonda satılan 3235, 44 günde % kaçı satılmış, o yüzde bizim
--   için; 17416 adet, kalanı bul" + "depoda o kadar varsa sorun yok yoksa sipariş".
--
--   PAY           = geçen yıl OKUL ÖNCESİ penceresi ÷ geçen SEZON TOPLAMI
--   TOPLAM SEZON  = bu yıl OKUL ÖNCESİ penceresi ÷ PAY
--   KALAN İHTİYAÇ = TOPLAM SEZON − bu yıl ŞU ANA KADAR satılan
--   SONUÇ         = kalan ihtiyaç ≤ mağaza + depo ? "sorun yok" : "SİPARİŞ"
--
-- ⚠ BÜYÜME PARAMETRESİ YOK. Büyümeyi ürünün bu yılki kendi hacmi taşıyor; pay
--   yalnız "sezonun neresindeyiz" sorusunu cevaplıyor. Alıcının çevirebileceği
--   bir kadran kalmadı (satinalma-danisman: "tek kadran, iki savunma" sorunu).
--
-- ⚠ PENCERE OKUL AÇILIŞINA HİZALI, takvime değil. ÖLÇÜLDÜ 15.09.2026:
--   takvim hizasıyla Kırtasiye sezon tahmini 521.262, açılış hizasıyla 643.912
--   (%23,5 fark). Sebep: 01.08–13.09.2025 penceresi okul açılışından (08.09.2025)
--   SONRAKİ 6 günü içeriyor, 2026'nınki içermiyor (okul 14.09.2026) → pay şişip
--   talebi eksik ölçüyordu. Pencereler EŞİT UZUNLUKTA ve açılıştan bir gün önce biter.
--
-- ⚠ BACKTEST (ölçüldü 15.09.2026): 2024 payıyla 2025 sezonu tahmin edildi,
--   gerçekleşenle karşılaştırıldı — Kırtasiye 1.445 çeşit, medyan mutlak hata
--   %16,3, medyan yanlılık +%2,1 (yansız). ⚠ O yılda okul kayması 1 gündü
--   (09.09.2024→08.09.2025); bu yıl 6 gün. Backtest bu riski SINAYAMAZ.
--
-- ⚠ SANSÜR: geçen sezon stoksuz kalan üründe payda kesilir, pay 1'e yaklaşır,
--   talep EKSİK ölçülür. ÖLÇÜLDÜ: stoksuz kalanların pay medyanı 0,821 · stoğu
--   olanların 0,588 (Kırtasiye, 42 vs 3.988 çeşit). Bayrak kolonda GÖRÜNÜR.
--   Kategori payına düşürme denendi ve backtest'te KÖTÜLEŞTİ (%18,5 → %48,5),
--   o yüzden UYGULANMADI — örneklem 10 çeşit, açık soru olarak duruyor.
WITH gp AS (   -- GEÇEN yıl OKUL ÖNCESİ penceresi (pay'ın PAYI)
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
gps AS (       -- aynı pencere, MAĞAZA BAZLI
    -- ⚠ 'Top' AYRILMIŞ SÖZCÜK, takma ad olamaz (SQL 156) — üç mağaza ayrı kolon.
    SELECT h.ehstkID AS stkID,
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
bp AS (        -- BU yıl OKUL ÖNCESİ penceresi — gp ile EŞİT UZUNLUKTA
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
bps AS (       -- aynı pencere, MAĞAZA BAZLI
    SELECT h.ehstkID AS stkID,
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
bt AS (        -- BU yıl SEZON BAŞINDAN BUGÜNE — "şu ana kadar satılan"
    -- ⚠ Tahminden ÇIKARILAN budur, hizalı pencere DEĞİL: tahmin TÜM sezonu
    --   söyler, ondan sezon başından beri satılan HER ŞEY düşülür.
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
bts AS (       -- aynı, MAĞAZA BAZLI
    SELECT h.ehstkID AS stkID,
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
sn AS (        -- SANSÜR BAYRAĞI: geçen sezonun ay sonlarında mağaza stoğu 0 mıydı
    -- ⚠ AY SONU fotoğrafı; dilim içinde tükenip dolanı kaçırır → ALT SINIR.
    SELECT b.stkID,
           Eyl = SUM(CASE WHEN b.Donem = ? THEN b.Stok ELSE 0 END),
           Eki = SUM(CASE WHEN b.Donem = ? THEN b.Stok ELSE 0 END)
    FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b WITH (NOLOCK)
    WHERE b.ehMekan IN (1,4477,4478) AND b.Donem IN (?, ?)
    GROUP BY b.stkID
),
kb AS (        -- ALT KATEGORİ (Kat2) PAYI — ürünün kendi ölçümü zayıfsa yedek
    -- GMY 16.09.2026: "geçen sezon kareli defter A marka, bu sene almadık, B aldık."
    -- ÖLÇÜLDÜ (Defterler grubu): bu sezonun satışının %16'sı geçen sezon HİÇ
    --   satmamış üründen geliyor. Dağılım çok eşitsiz — Butik Defterler %46
    --   (2.040 çeşit satmıştı, bu sezon 1.564, ortak yalnız 1.036), Fihrist %99;
    --   buna karşılık Çizgili Defter %5, Kareli Defter %4, Defter/Kitap Kabı %0.
    -- Yani SKU dönen yerde taban ÜRÜNDE değil ALT KATEGORİDE durur. Yedek oran
    -- Kategori3 yerine Kat2'den alınır: Butik Defter'e Kırtasiye ortalaması
    -- (0,505) uygulamak, o alt kategorinin kendi eğrisini görmezden gelmekti.
    SELECT Kat = tt.Kat2,
           Pencere = SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < ? THEN -h.ehAdetN ELSE 0 END),
           Sezon   = SUM(-h.ehAdetN)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.bkm.SatisAnaliziTaban tt WITH (NOLOCK)
         ON tt.stkID = h.ehstkID AND tt.Kesim = ? AND tt.SezonYil = ?
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
      AND tt.Kat2 IS NOT NULL
    GROUP BY tt.Kat2
),
kb3 AS (       -- Kat2 boşsa ANA KATEGORİ (Kategori3) payına düşülür
    SELECT Kat = u.Kategori3,
           Pencere = SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < ? THEN -h.ehAdetN ELSE 0 END),
           Sezon   = SUM(-h.ehAdetN)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK) ON u.stkID = h.ehstkID
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY u.Kategori3
),
gd AS (        -- GEÇEN yılın SEZON DIŞI dilimi (yalnız "gelecek sezona kalır mı")
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
yl AS (        -- YILLIK 365 gün — bağlam, karar vermez
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
)
SELECT t.stkAd                                       AS [Ürün],
       t.Kategori3                                   AS [Kategori],
       {YOL}                                         AS [Kategori yolu],
       -- Taban kolonunun adi 'Yayinevi' ama kaynagi UrunBilgi.mrkAd, yani MARKA.
       t.Yayinevi                                    AS [Marka],
       -- stkKod barkod DEGILDIR; ikisi ayri alandir.
       u.stkKod                                      AS [Stok kodu],
       t.BarkodAna                                   AS [Barkod],
       -- ── GECEN SEZONUN OLCUMU (payin paydasi ve payi) ──────────────────
       t.SezonToplam                                 AS [Gecen sezon toplam satilan],
       t.SezonFsm                                    AS [Gecen sezon FSM satilan],
       t.SezonOzl                                    AS [Gecen sezon Ozluce satilan],
       t.SezonIst                                    AS [Gecen sezon IstYolu satilan],
       CONVERT(int, ISNULL(gp.Adet, 0))              AS [Gecen sezon okul oncesi satilan],
       CONVERT(int, ISNULL(gps.Fsm, 0))              AS [Gecen sezon FSM okul oncesi],
       CONVERT(int, ISNULL(gps.Ozl, 0))              AS [Gecen sezon Ozluce okul oncesi],
       CONVERT(int, ISNULL(gps.Ist, 0))              AS [Gecen sezon IstYolu okul oncesi],
       CASE WHEN ISNULL(sn.Eyl, 0) <= 0 OR ISNULL(sn.Eki, 0) <= 0
            THEN N'EVET' ELSE N'HAYIR' END           AS [Gecen sezon stogu bitti mi],
       -- Kategori ortalamasi: urunun kendi olcumu zayifsa formul buna duser.
       CONVERT(decimal(6,4), ISNULL(
            CASE WHEN ISNULL(kb.Sezon, 0) > 0 AND CONVERT(float, kb.Pencere) / kb.Sezon
                      BETWEEN 0.05 AND 1.0
                 THEN CONVERT(float, kb.Pencere) / kb.Sezon END,
            CASE WHEN ISNULL(kb3.Sezon, 0) > 0
                 THEN CONVERT(float, kb3.Pencere) / kb3.Sezon END))
                                                     AS [Kategori ortalama oran],
       ISNULL(t.Kat2, t.Kategori3)                   AS [Oranin alindigi alt kategori],
       -- ── BU SEZONUN OLCUMU ─────────────────────────────────────────────
       CONVERT(int, ISNULL(bp.Adet, 0))              AS [Bu sezon okul oncesi satilan],
       CONVERT(int, ISNULL(bps.Fsm, 0))              AS [Bu sezon FSM okul oncesi],
       CONVERT(int, ISNULL(bps.Ozl, 0))              AS [Bu sezon Ozluce okul oncesi],
       CONVERT(int, ISNULL(bps.Ist, 0))              AS [Bu sezon IstYolu okul oncesi],
       CONVERT(int, ISNULL(bt.Adet, 0))              AS [Bu sezon bugune kadar satilan],
       CONVERT(int, ISNULL(bts.Fsm, 0))              AS [Bu sezon FSM satilan],
       CONVERT(int, ISNULL(bts.Ozl, 0))              AS [Bu sezon Ozluce satilan],
       CONVERT(int, ISNULL(bts.Ist, 0))              AS [Bu sezon IstYolu satilan],
       -- ── STOK ──────────────────────────────────────────────────────────
       t.StokFsm AS [FSM stok], t.StokOzl AS [Ozluce stok], t.StokIst AS [IstYolu stok],
       t.MerkezStok                                  AS [Merkez depo stok],
       t.OdakStok                                    AS [Tedarikcide bulunan],
       -- ── BAGLAM ────────────────────────────────────────────────────────
       CONVERT(int, CASE WHEN ISNULL(gd.Adet, 0) > 0 THEN gd.Adet ELSE 0 END)
                                                     AS [Gecen yil sezon disi satilan],
       CONVERT(int, ISNULL(yl.Adet, 0))              AS [Gecen yil toplam satilan],
       -- 4 hane: 2 haneye yuvarlayip carpinca toplam sapiyordu (olculdu).
       CONVERT(decimal(18,4), t.SatisFiyat)          AS [Satis fiyati],
       CONVERT(decimal(18,4), CASE WHEN {MALIYET_GECERLI}
            THEN t.BirimMaliyet END)                 AS [Birim maliyet]
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID
LEFT JOIN gp  ON gp.stkID  = t.stkID
LEFT JOIN gps ON gps.stkID = t.stkID
LEFT JOIN bp  ON bp.stkID  = t.stkID
LEFT JOIN bps ON bps.stkID = t.stkID
LEFT JOIN bt  ON bt.stkID  = t.stkID
LEFT JOIN bts ON bts.stkID = t.stkID
LEFT JOIN sn  ON sn.stkID  = t.stkID
LEFT JOIN kb  ON kb.Kat    = t.Kat2
LEFT JOIN kb3 ON kb3.Kat   = t.Kategori3
LEFT JOIN gd  ON gd.stkID  = t.stkID
LEFT JOIN yl  ON yl.stkID  = t.stkID
-- Asagidaki hesaplar YALNIZ --durum suzgeci icindir. Ekrandaki sayilar Excel
-- formullerinden gelir; ikisi AYNI zinciri uygular.
--
-- ZINCIR SUBE DUZEYINDE KURULUR (GMY 15.09.2026 itirazi uzerine olculdu):
--   urun duzeyinde bir hesap, sube duzeyinde baska bir hesap vardi ve ikisi
--   celisiyordu. OLCULDU (Kirtasiye 20.218 cesit): sube eksikleri toplami ile
--   siparis adedi 4.922 cesitte (%24,3) uyusmuyordu, toplam fark 133.594 adet.
--   Ayrica sube payi GECEN yildan aliniyordu: bu yilin dagilimiyla medyan
--   mutlak sapma 0,390 ve urunlerin %53,9'unda EN COK SATAN SUBE degismisti.
--   Cozum: her sube kendi orani, kendi tahmini, kendi eksigi. Urun toplami
--   subelerin toplamidir; iki sayi celisemez.
CROSS APPLY (SELECT Kat = ISNULL(
        CASE WHEN ISNULL(kb.Sezon, 0) > 0 AND CONVERT(float, kb.Pencere) / kb.Sezon
                  BETWEEN 0.05 AND 1.0
             THEN CONVERT(float, kb.Pencere) / kb.Sezon END,
        CASE WHEN ISNULL(kb3.Sezon, 0) > 0
             THEN CONVERT(float, kb3.Pencere) / kb3.Sezon END)) k0
CROSS APPLY (SELECT Kat = ISNULL(CASE WHEN k0.Kat BETWEEN 0.05 AND 1.0
                                      THEN k0.Kat END, 0.60)) kk
-- Sube orani: o subenin kendi olcumu zayifsa (30 adet alti ya da 0,05-1,00
-- disi) kategori ortalamasina duser. Urun orani bir ARA ADIM degildir artik.
CROSS APPLY (SELECT
        OrF = CASE WHEN t.SezonFsm >= 30 AND ISNULL(gps.Fsm,0) >= 30
                    AND CONVERT(float, gps.Fsm) / t.SezonFsm BETWEEN 0.05 AND 1.0
                   THEN CONVERT(float, gps.Fsm) / t.SezonFsm ELSE kk.Kat END,
        OrO = CASE WHEN t.SezonOzl >= 30 AND ISNULL(gps.Ozl,0) >= 30
                    AND CONVERT(float, gps.Ozl) / t.SezonOzl BETWEEN 0.05 AND 1.0
                   THEN CONVERT(float, gps.Ozl) / t.SezonOzl ELSE kk.Kat END,
        OrI = CASE WHEN t.SezonIst >= 30 AND ISNULL(gps.Ist,0) >= 30
                    AND CONVERT(float, gps.Ist) / t.SezonIst BETWEEN 0.05 AND 1.0
                   THEN CONVERT(float, gps.Ist) / t.SezonIst ELSE kk.Kat END) po
CROSS APPLY (SELECT
        TahF = CONVERT(int, CEILING(ISNULL(bps.Fsm,0) / po.OrF)),
        TahO = CONVERT(int, CEILING(ISNULL(bps.Ozl,0) / po.OrO)),
        TahI = CONVERT(int, CEILING(ISNULL(bps.Ist,0) / po.OrI))) th
CROSS APPLY (SELECT
        KalF = CASE WHEN th.TahF > ISNULL(bts.Fsm,0)
                    THEN th.TahF - CONVERT(int, ISNULL(bts.Fsm,0)) ELSE 0 END,
        KalO = CASE WHEN th.TahO > ISNULL(bts.Ozl,0)
                    THEN th.TahO - CONVERT(int, ISNULL(bts.Ozl,0)) ELSE 0 END,
        KalI = CASE WHEN th.TahI > ISNULL(bts.Ist,0)
                    THEN th.TahI - CONVERT(int, ISNULL(bts.Ist,0)) ELSE 0 END) kl
CROSS APPLY (SELECT
        Eksik = CASE WHEN kl.KalF > t.StokFsm THEN kl.KalF - t.StokFsm ELSE 0 END
              + CASE WHEN kl.KalO > t.StokOzl THEN kl.KalO - t.StokOzl ELSE 0 END
              + CASE WHEN kl.KalI > t.StokIst THEN kl.KalI - t.StokIst ELSE 0 END,
        Kalan = kl.KalF + kl.KalO + kl.KalI,
        DisT  = CONVERT(int, CASE WHEN ISNULL(gd.Adet,0) > 0 THEN gd.Adet ELSE 0 END)) s
CROSS APPLY (SELECT
        Siparis = CASE WHEN s.Eksik > t.MerkezStok THEN s.Eksik - t.MerkezStok ELSE 0 END,
        Fazla   = t.MagazaStok + t.MerkezStok - s.Kalan - s.DisT) x
CROSS APPLY (SELECT Sinif = CASE
        -- OLU STOK: iki sezondur satmiyor ama stogu duruyor. Siparis analizinin
        -- konusu degil; karar "erit / iade". OLCULDU (Defterler): 3.356 cesit,
        -- 33.582 adet, 1.012.992 TL maliyet.
        WHEN t.SezonToplam <= 0 AND ISNULL(bt.Adet, 0) <= 0
             AND t.MagazaStok + t.MerkezStok > 0 THEN 5   -- olu stok
        WHEN x.Siparis > 0   THEN 1   -- siparis ver
        WHEN s.Eksik > 0     THEN 4   -- depodan gonder
        WHEN x.Fazla > 0     THEN 2   -- fazla var
        ELSE 0 END) g
WHERE t.Kesim = ? AND t.SezonYil = ?
  -- KAPSAM (GMY 16.09.2026 itirazi uzerine genisletildi): eski sart "geçen
  -- sezon fiilen satmış" idi ve BU SEZON SATAN 1.061 çeşidi dışarıda bırakıyordu
  -- (Defterler grubunda ölçüldü: 681'i 2026'da açılmış yeni ürün, 380'i eski ama
  -- geçen sezon satmamış; ikisi birlikte bu sezon 11.852 adet satmış). Onların
  -- oranı alt kategoriden gelir. Ayrıca iki sezondur satmayan stoklu ürünler de
  -- girer; onlar ÖLÜ STOK olarak ayrı sınıflanır.
  AND (t.SezonToplam > 0 OR ISNULL(bt.Adet, 0) > 0
       OR t.MagazaStok + t.MerkezStok > 0)
  -- DEFTER GÜVENİLİR: negatif stok fiziksel durum değil, defter hatasıdır.
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
  AND (? IS NULL OR t.Kategori3 = ?)
  -- URUN GRUBU (Kat1): 'Defterler', 'Kalemler ve Yazi Gerecleri' gibi alt kirilim.
  AND (? IS NULL OR t.Kat1 = ?)
  AND (? = 0 OR g.Sinif = 1)                -- yalnız SİPARİŞ
  AND (? = 0 OR g.Sinif = 2)                -- yalnız ERİT
  AND (? = 0 OR g.Sinif = 4)                -- yalnız TAŞI
  AND (? = 0 OR g.Sinif = 5)                -- yalnız ÖLÜ STOK
-- SIRALAMA PARAYA GÖRE: sipariş satırında kaçacak ciro, ötekinde bağlı sermaye.
ORDER BY CASE WHEN g.Sinif = 1 THEN x.Siparis * t.SatisFiyat
              WHEN g.Sinif = 2 THEN x.Fazla * ISNULL(t.BirimMaliyet, 0)
              ELSE 0 END DESC,
         ISNULL(bt.Adet, 0) DESC, t.stkID
"""

# ── SAYFA DÜZENİ ──────────────────────────────────────────────────────────────
# Türetilen her kolon FORMÜLDÜR; ham girdiler SQL'den gelir. Büyüme TEK HÜCREDE
# (B2) — değiştirilince tüm liste yeniden hesaplanır.
#   (ad, tip)  tip: "ham" = SQL kolonu · "f" = Excel formülü
DUZEN: list[tuple[str, str]] = [
    ("Ürün",                              "ham"),
    ("Kategori",                          "ham"),
    ("Kategori yolu",                     "ham"),
    ("Marka",                             "ham"),
    ("Stok kodu",                         "ham"),
    ("Barkod",                            "ham"),
    # GENEL OLCUM — aciklayici; hesap SUBE duzeyinde yapilir
    ("Gecen sezon toplam satilan",        "ham"),
    ("Gecen sezon okul oncesi satilan",   "ham"),
    ("Kategori ortalama oran",            "ham"),
    ("Gecen yil toplam satilan",          "ham"),
    ("Sezon payi",                        "f"),
    ("Gecen sezon stogu bitti mi",        "ham"),
    ("Bu sezon okul oncesi satilan",      "ham"),
    ("Bu sezon bugune kadar satilan",     "ham"),
    # FSM subesi — kendi orani, kendi tahmini, kendi eksigi
    ("Gecen sezon FSM satilan",          "ham"),
    ("Gecen sezon FSM okul oncesi",      "ham"),
    ("FSM kullanilan oran",              "f"),
    ("Bu sezon FSM okul oncesi",         "ham"),
    ("Bu sezon FSM satilan",             "ham"),
    ("FSM bu sezon toplam satacak",      "f"),
    ("FSM sezonun kalaninda satacak",    "f"),
    ("FSM stok",                         "ham"),
    ("FSM eksik adet",                   "f"),
    # Ozluce subesi — kendi orani, kendi tahmini, kendi eksigi
    ("Gecen sezon Ozluce satilan",          "ham"),
    ("Gecen sezon Ozluce okul oncesi",      "ham"),
    ("Ozluce kullanilan oran",              "f"),
    ("Bu sezon Ozluce okul oncesi",         "ham"),
    ("Bu sezon Ozluce satilan",             "ham"),
    ("Ozluce bu sezon toplam satacak",      "f"),
    ("Ozluce sezonun kalaninda satacak",    "f"),
    ("Ozluce stok",                         "ham"),
    ("Ozluce eksik adet",                   "f"),
    # IstYolu subesi — kendi orani, kendi tahmini, kendi eksigi
    ("Gecen sezon IstYolu satilan",          "ham"),
    ("Gecen sezon IstYolu okul oncesi",      "ham"),
    ("IstYolu kullanilan oran",              "f"),
    ("Bu sezon IstYolu okul oncesi",         "ham"),
    ("Bu sezon IstYolu satilan",             "ham"),
    ("IstYolu bu sezon toplam satacak",      "f"),
    ("IstYolu sezonun kalaninda satacak",    "f"),
    ("IstYolu stok",                         "ham"),
    ("IstYolu eksik adet",                   "f"),
    # TOPLAMLAR — subelerin toplamidir, ayri bir hesap DEGILDIR
    ("Bu sezon toplam satilacak",         "f"),
    ("Sezonun kalaninda satilacak",       "f"),
    ("Subelerde toplam eksik adet",       "f"),
    ("Magazalarda toplam stok",           "f"),
    ("Merkez depo stok",                  "ham"),
    ("Magaza ve depo toplam stok",        "f"),
    # SONUC
    ("Durum",                             "f"),
    ("Siparis verilecek adet",            "f"),
    ("Siparis nereden karsilanir",        "f"),
    ("Tedarikcide bulunan",               "ham"),
    # BAGLAM
    ("Gecen yil sezon disi satilan",      "ham"),
    ("Gelecek sezona kalacak",            "f"),
    # PARA
    ("Satis fiyati",                      "ham"),
    ("Birim maliyet",                     "ham"),
    ("Tutar",                             "f"),
    ("Siparis tutari",                    "f"),
    ("Fazla stok tutari",                 "f"),
]


# Kolon GIZLENMEZ (GMY 15.09.2026: "alanlari gizleme"). --durum yalnizca
# SATIR suzer; her dosyada butun kolonlar durur.
MOD_KOLON: dict[str, list[str]] = {}


PARA = {"Satış fiyatı", "Birim maliyet"}


def parametre_sirasi_denetle(sql: str, etiketler: list[str]) -> None:
    """SQL'deki ? sirasi ile verilen etiket sirasini karsilastirir.

    ⚠ NEDEN VAR (15.09.2026, olculdu): `kb` CTE'si SQL'de `gd`/`kd`'den ONCE
    tanimliydi ama parametreleri SONRA veriliyordu. pyodbc SAYIYI dogrular,
    SIRAYI dogrulamaz -> hata YOK, rakam YANLIS. Mevsim katsayisi 0,9167
    cikti (dogrusu 0,5464) ve bu ancak katsayi EKRANA konuldugu icin farkedildi.
    Kolon gorunur olmasaydi liste sessizce yanlis siparis ettirecekti.

    Etiket = o parametrenin ait oldugu CTE/APPLY adi. SQL'den CTE sirasi ve her
    CTE'deki ? sayisi cikarilir; etiket listesiyle BIREBIR tutmali.
    """
    import re as _re
    # CTE gövdeleri: "ad AS (" ile baslar, bir sonraki CTE'ye kadar surer.
    # ⚠ YORUMLARDAKİ SORU İŞARETİ PARAMETRE DEĞİLDİR. Türkçe yorumlar soru cümlesi
    #   taşıyor ("...mağaza stoğu 0 mı?") ve ham sayım onu parametre sanıyordu —
    #   kapı ikinci koşuda bunu bildirdi. Yorum karakterleri KONUM KORUNARAK
    #   boşluğa çevrilir; silinirse ofsetler kayar.
    temiz = list(sql)
    for m in _re.finditer(r"--[^\n]*", sql):
        for k in range(m.start(), m.end()):
            temiz[k] = " "
    temiz_sql = "".join(temiz)
    # ⚠ İLK CTE "WITH gh AS (" olarak yazılır — satır başı deseni onu KAÇIRIR.
    #   Kapı ilk koşuda tam bu eksiği bildirdi (kırılabilirliği böyle kanıtlandı).
    bas = [(m.group(1), m.start())
           for m in _re.finditer(r"^(?:WITH\s+)?(\w+) AS \(", temiz_sql, _re.M)]
    # ⚠ SON CTE'nin gövdesi dosya sonuna KADAR sürmez: ana SELECT ve CROSS
    #   APPLY'ların parametrelerini yutardı (ölçüldü: 47 karşı 32). Son CTE
    #   "\n)\n" ile kapanır — orada durulur.
    _kapanis = temiz_sql.find("\n)\n", bas[-1][1]) if bas else -1
    _cte_sonu = _kapanis + 2 if _kapanis >= 0 else len(temiz_sql)
    beklenen: list[str] = []
    for i, (ad, konum) in enumerate(bas):
        son = bas[i + 1][1] if i + 1 < len(bas) else _cte_sonu
        beklenen += [ad] * temiz_sql.count("?", konum, son)
    verilen = etiketler[:len(beklenen)]
    if verilen != beklenen:
        for i, (b, v) in enumerate(zip(beklenen, verilen)):
            if b != v:
                kosamadi(f"Parametre sirasi kaydi: {i + 1}. parametre SQL'de "
                         f"'{b}' CTE'sine ait, kodda '{v}' etiketli. "
                         f"SQL sirasi: {' '.join(dict.fromkeys(beklenen))}")
        kosamadi(f"Parametre sayisi uyusmuyor: SQL {len(beklenen)}, kod {len(verilen)}")


def ayir(n: float, para: bool = False) -> str:
    s = f"{n:,.0f}".replace(",", ".")
    return f"{s} ₺" if para else s


def satir_sonuc(r, ix):
    """LISTE formulunun Python karsiligi. Ayni ham kolonlardan, ayni sirayla.

    Bu blok daha once formulu ikinci kez kurmus ve sessizce ayrismisti. Artik
    girdiler SQL'den gelen HAM kolonlardir; tekrar eden tek sey aritmetiktir.
    """
    import math
    kat = float(r[ix["Kategori ortalama oran"]] or 0)
    kat = kat if 0.05 <= kat <= 1.0 else 0.6
    kalan_top = eksik_top = tahmin_top = 0
    for su in ("FSM", "Ozluce", "IstYolu"):
        gs = r[ix[f"Gecen sezon {su} satilan"]] or 0
        go = r[ix[f"Gecen sezon {su} okul oncesi"]] or 0
        oran = go / gs if gs > 0 else 0.0
        if not (gs >= 30 and go >= 30 and 0.05 <= oran <= 1.0):
            oran = kat
        bo = r[ix[f"Bu sezon {su} okul oncesi"]] or 0
        tahmin = math.ceil(bo / oran) if oran > 0 else 0
        kalan = max(0, tahmin - (r[ix[f"Bu sezon {su} satilan"]] or 0))
        tahmin_top += tahmin
        kalan_top += kalan
        eksik_top += max(0, kalan - (r[ix[f"{su} stok"]] or 0))
    depo = r[ix["Merkez depo stok"]] or 0
    magaza = sum(r[ix[f"{su} stok"]] or 0 for su in ("FSM", "Ozluce", "IstYolu"))
    siparis = max(0, eksik_top - depo)
    fazla = magaza + depo - kalan_top - (r[ix["Gecen yil sezon disi satilan"]] or 0)
    if ((r[ix["Gecen sezon toplam satilan"]] or 0) <= 0
            and (r[ix["Bu sezon bugune kadar satilan"]] or 0) <= 0
            and magaza + depo > 0):
        return "ÖLÜ STOK", magaza + depo, fazla
    if siparis > 0:
        return "SİPARİŞ VER", siparis, fazla
    if eksik_top > 0:
        return "DEPODAN GÖNDER", eksik_top, fazla
    if fazla > 0:
        return "FAZLA VAR", fazla, fazla
    return "YETERLİ", 0, fazla


def pivot_kur(yol: str, kolon_sayisi: int, son_satir: int,
              alanlar: list[tuple[str, str, bool]]) -> str:
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
            pt.PivotFields("Marka").Orientation = 1      # xlRowField
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
            # ⚠ PivotFields GÖRÜNEN başlıkla eşleşir, iç anahtarla DEĞİL. Başlıklar
            #   tarihlendiği/çok satırlı olduğu için iç anahtar geçilirse
            #   "PivotFields yöntemi başarısız" (0x800A03EC) alınır — ölçüldü 15.09.2026.
            #   Bu yüzden görünen adlar dışarıdan (GOSTER çözülmüş hâliyle) gelir.
            for alan, ad, paralimi in alanlar:
                bicim = para if paralimi else tamsayi
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
            # EKSİK tutarına göre büyükten küçüğe — alıcı en büyük açıktan başlasın.
            try:
                pt.PivotFields("Marka").AutoSort(2, "Siparis tutari TL")  # xlDescending
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
    ap.add_argument("--grup", default=None,
                    help="urun grubu (Kat1), ornek: Defterler")
    ap.add_argument("--durum", choices=["siparis", "depodan", "fazla", "olu"], default=None,
                    help="siparis (yeni alim gerekiyor) / depodan (merkez depo karsiliyor) "
                         "/ fazla (gelecek sezona artik kaliyor)")
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
    # İKİ EKSEN: DURUM (ne durumda) · KAYNAK (nereden çözülür).
    # satinalma-danisman 15.09.2026: dosya KAYNAĞA göre bölünür, çünkü dosyayı
    # alan KİŞİ değişiyor (depo/lojistik · satınalmacı-düşük risk · satınalmacı-asıl iş).
    # ÇAPRAZ EYLEM süzgeçleri (SQL: 1=AL · 2=ERİT · 4=TAŞI · 5=BEKLE)
    # SQL sinifi: 1 = siparis · 2 = fazla · 4 = depodan gonder
    yalniz_acik = 1 if a.durum == "siparis" else 0
    yalniz_fazla = 1 if a.durum == "fazla" else 0
    yalniz_bitti = 1 if a.durum == "depodan" else 0
    yalniz_olu = 1 if a.durum == "olu" else 0
    yalniz_depo = 0
    yalniz_odak = 0
    yalniz_ted = 0
    kategori = a.kategori.strip() if a.kategori and a.kategori.strip() else None
    grup = a.grup.strip() if a.grup and a.grup.strip() else None
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
        # BU YILIN sezon disi penceresi — yalniz BASLIK icin (olcum gecen yildan).
        gd_bas_bu = dt.date(sezon_sonu_bu.year, 11, 1)
        gd_son_bu = dt.date(sezon_sonu_bu.year + 1, 7, 31)
        if gk_bas_bu > gk_son_bu:
            kosamadi(f"Sezon bitmis ({b_son} > {sezon_sonu_bu}) — kalan talep yok")

        # YILLIK pencere: sezon başından bir sonraki sezon başının bir gün öncesine.
        y_bas = dt.date(a.sezon, SEZON_BAS_AY, 1)
        y_son = dt.date(a.sezon + 1, SEZON_BAS_AY, 1) - dt.timedelta(days=1)

        yil_farki = kesim.year - a.sezon
        g_bas, g_son = aynala(b_bas, b_bas.year - yil_farki), aynala(b_son, b_son.year - yil_farki)
        gk_bas = aynala(gk_bas_bu, gk_bas_bu.year - yil_farki)
        gk_son = aynala(gk_son_bu, gk_son_bu.year - yil_farki)

        # HIZ TABANI için gün sayıları. SQL'de hesaplanmaz — tek kaynak burası.
        # ⚠ Gün sayısı KAPSAYICI (her iki uç dahil): 01.08–13.09 = 44 gün.
        # ── OKUL-HİZALI PENCERELER (pay'ın payı) ────────────────────────
        # Her iki yıl da "açılıştan bir gün önce" biter ve EŞİT UZUNLUKTADIR.
        # Uzunluk = iki yılın okul-öncesi gün sayısının KÜÇÜĞÜ.
        if a.sezon not in OKUL_ACILIS or kesim.year not in OKUL_ACILIS:
            kosamadi(f"Okul acilis tarihi tanimsiz: {a.sezon} / {kesim.year}")
        g_acilis, b_acilis = OKUL_ACILIS[a.sezon], OKUL_ACILIS[kesim.year]
        g_pen_son = g_acilis - dt.timedelta(days=1)
        b_pen_son = min(kesim, b_acilis - dt.timedelta(days=1))
        pen_gun = min((g_pen_son - dt.date(a.sezon, 8, 1)).days,
                      (b_pen_son - dt.date(kesim.year, 8, 1)).days) + 1
        if pen_gun < 14:
            kosamadi(f"Okul oncesi pencere cok kisa: {pen_gun} gun")
        gp_bas = g_pen_son - dt.timedelta(days=pen_gun - 1)
        bp_bas = b_pen_son - dt.timedelta(days=pen_gun - 1)
        # SEZON: geçen yılın TAMAMI (pay'ın paydası) + bu yılın şimdiye kadarı
        gs_bas, gs_son = dt.date(a.sezon, 8, 1), dt.date(a.sezon, 10, 31)
        bt_bas, bt_son = dt.date(kesim.year, 8, 1), kesim
        # SEZON DIŞI (yalnız "gelecek sezona kalır mı" sorusu)
        gd_bas, gd_son = dt.date(a.sezon, 11, 1), dt.date(a.sezon + 1, 7, 31)

        # SANSÜR BAYRAĞI: geçen SEZONUN ay sonları (snapshot yalnız ay sonu tutar).
        # Eylül ve Ekim sonu — sezonun son iki ayı. Ürün o ay sonlarında sıfır
        # stoktaysa PAY şüphelidir (payda kesilmiş, pay 1'e yaklaşmış).
        sn_eyl = dt.date(a.sezon, 9, 30)
        sn_eki = dt.date(a.sezon, 10, 31)
        # ⚠ EŞİT UZUNLUK ZORUNLU: farklı uzunlukta iki pencere SAHTE büyüme üretir ve
        #   hata vermez. Bugün ölçülen 44/45 gün sapmasının sınıfı budur.
        if (b_son - b_bas).days != (g_son - g_bas).days:
            kosamadi(f"Pencereler esit uzunlukta degil: bu {(b_son - b_bas).days + 1} gun, "
                     f"gecen {(g_son - g_bas).days + 1} gun")

        # Sıra SQL'deki ? sırasıdır; biri değişirse ikisi birden değişir.
        # ⚠ Üst sınır DIŞLAYICI (son + 1 gün, gece yarısı) — "23:59:59" yazılmaz.
        # ⚠ SIRA = SQL'DEKI CTE SIRASI. Etiketler kapidan gecer (bkz.
        #   parametre_sirasi_denetle): kayma sessiz degil, KOSAMADI ile patlar.
        # ⚠ SIRA = SQL'DEKİ CTE SIRASI. Kapıdan geçer (parametre_sirasi_denetle):
        #   kayma sessiz değil, KOŞAMADI ile patlar.
        _gun = dt.timedelta(days=1)
        _p: list[tuple[str, object]] = [
            ("gp", gp_bas), ("gp", g_pen_son + _gun),
            ("gps", gp_bas), ("gps", g_pen_son + _gun),
            ("bp", bp_bas), ("bp", b_pen_son + _gun),
            ("bps", bp_bas), ("bps", b_pen_son + _gun),
            ("bt", bt_bas), ("bt", bt_son + _gun),
            ("bts", bt_bas), ("bts", bt_son + _gun),
            ("sn", sn_eyl), ("sn", sn_eki), ("sn", sn_eyl), ("sn", sn_eki),
            ("kb", gp_bas), ("kb", g_pen_son + _gun),
            ("kb", kesim), ("kb", a.sezon),
            ("kb", gs_bas), ("kb", gs_son + _gun),
            ("kb3", gp_bas), ("kb3", g_pen_son + _gun),
            ("kb3", gs_bas), ("kb3", gs_son + _gun),
            ("gd", gd_bas), ("gd", gd_son + _gun),
            ("yl", y_bas), ("yl", y_son + _gun),
        ]
        parametre_sirasi_denetle(SQL, [e for e, _ in _p])
        cur.execute(SQL, *[v for _, v in _p],
                    kesim, a.sezon, kategori, kategori, grup, grup,
                    yalniz_acik, yalniz_fazla, yalniz_bitti, yalniz_olu)
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
    # Baslikta satir kirilimi — f-string icinde ters bolu olamaz, sabit kullanilir.
    NL = chr(10)
    GOSTER = {
        "Gecen sezon toplam satilan":
            f"Geçen sezon toplam satılan adet{NL}(01.08-31.10.{a.sezon})",
        "Gecen sezon okul oncesi satilan":
            f"Geçen sezon okul açılmadan önce satılan adet{NL}({gp_bas:%d.%m.%Y} - {g_pen_son:%d.%m.%Y}, {pen_gun} gün)",
        "Kategori ortalama oran":
            f"Kategori ortalaması{NL}(şubenin kendi ölçümü zayıfsa bu oran kullanılır)",
        "Gecen yil toplam satilan":
            f"Geçen yıl toplam satılan adet{NL}({y_bas:%d.%m.%Y} - {y_son:%d.%m.%Y})",
        "Sezon payi":
            f"Ürünün sezon payı{NL}(geçen sezon satılan / geçen yıl toplam satılan; düşükse ürün sezonluk değildir)",
        "Gecen sezon stogu bitti mi":
            f"Geçen sezon stoğu bitmiş miydi{NL}(bittiyse geçen sezon satışı gerçek talebin altındadır)",
        "Bu sezon okul oncesi satilan":
            f"Bu sezon okul açılmadan önce satılan adet{NL}({bp_bas:%d.%m.%Y} - {b_pen_son:%d.%m.%Y}, {pen_gun} gün)",
        "Bu sezon bugune kadar satilan":
            f"Bu sezon bugüne kadar satılan adet{NL}({bt_bas:%d.%m.%Y} - {bt_son:%d.%m.%Y})",
        "Bu sezon toplam satilacak":
            f"Bu sezon toplam kaç adet satılacak{NL}(üç şubenin tahmininin toplamı)",
        "Sezonun kalaninda satilacak":
            f"Sezonun kalanında kaç adet satılacak{NL}(üç şubenin kalanının toplamı)",
        "Subelerde toplam eksik adet":
            f"Şubelerde toplam eksik adet{NL}(her şubenin kendi eksiğinin toplamı)",
        "Magazalarda toplam stok": f"Mağazalarda toplam stok{NL}({kesim:%d.%m.%Y})",
        "Merkez depo stok":  f"Merkez depoda stok{NL}({kesim:%d.%m.%Y})",
        "Magaza ve depo toplam stok":
            f"Elimizdeki toplam stok{NL}(mağazalar artı merkez depo, {kesim:%d.%m.%Y})",
        "Durum":
            f"Durum{NL}(şube eksikleri merkez depodan karşılanamıyorsa sipariş gerekir)",
        "Siparis verilecek adet":
            f"Sipariş verilecek adet{NL}(şubelerde toplam eksik eksi merkez depo stoğu)",
        "Siparis nereden karsilanir":
            f"Sipariş nereden karşılanır{NL}(tedarikçide varsa ondan, yoksa yeni alım)",
        "Tedarikcide bulunan":
            f"Tedarikçide bulunan adet{NL}(bizim stoğumuz değil, anlık tedarikçi stoğu)",
        "Gecen yil sezon disi satilan":
            f"Geçen yıl sezon dışında satılan adet{NL}({gd_bas:%d.%m.%Y} - {gd_son:%d.%m.%Y})",
        "Gelecek sezona kalacak":
            f"Gelecek sezona kalacak adet{NL}(elimizdeki eksi sezonun kalanı eksi sezon dışı talep)",
        "Satis fiyati":  "Satış fiyatı",
        "Birim maliyet": "Birim maliyet",
        "Tutar":
            f"Tutar{NL}(sipariş satırında satış fiyatıyla, fazla satırında maliyetle)",
        "Siparis tutari":    "Sipariş tutarı",
        "Fazla stok tutari": "Fazla stok tutarı",
        "Gecen sezon FSM satilan":
            f"FSM: geçen sezon satılan adet{NL}(01.08-31.10.{a.sezon})",
        "Gecen sezon FSM okul oncesi":
            f"FSM: geçen sezon okul açılmadan önce satılan adet",
        "FSM kullanilan oran":
            f"FSM: kullanılan oran{NL}(okul öncesi satılan / sezon toplamı; 30 adedin altındaysa kategori ortalaması)",
        "Bu sezon FSM okul oncesi":
            f"FSM: bu sezon okul açılmadan önce satılan adet",
        "Bu sezon FSM satilan":
            f"FSM: bu sezon bugüne kadar satılan adet",
        "FSM bu sezon toplam satacak":
            f"FSM: bu sezon toplam kaç adet satacak{NL}(okul öncesi satılan / kullanılan oran)",
        "FSM sezonun kalaninda satacak":
            f"FSM: sezonun kalanında kaç adet satacak",
        "FSM stok":  f"FSM: stok{NL}({kesim:%d.%m.%Y})",
        "FSM eksik adet":
            f"FSM: eksik adet{NL}(satacağı miktar eksi stoğu)",
        "Gecen sezon Ozluce satilan":
            f"Özlüce: geçen sezon satılan adet{NL}(01.08-31.10.{a.sezon})",
        "Gecen sezon Ozluce okul oncesi":
            f"Özlüce: geçen sezon okul açılmadan önce satılan adet",
        "Ozluce kullanilan oran":
            f"Özlüce: kullanılan oran{NL}(okul öncesi satılan / sezon toplamı; 30 adedin altındaysa kategori ortalaması)",
        "Bu sezon Ozluce okul oncesi":
            f"Özlüce: bu sezon okul açılmadan önce satılan adet",
        "Bu sezon Ozluce satilan":
            f"Özlüce: bu sezon bugüne kadar satılan adet",
        "Ozluce bu sezon toplam satacak":
            f"Özlüce: bu sezon toplam kaç adet satacak{NL}(okul öncesi satılan / kullanılan oran)",
        "Ozluce sezonun kalaninda satacak":
            f"Özlüce: sezonun kalanında kaç adet satacak",
        "Ozluce stok":  f"Özlüce: stok{NL}({kesim:%d.%m.%Y})",
        "Ozluce eksik adet":
            f"Özlüce: eksik adet{NL}(satacağı miktar eksi stoğu)",
        "Gecen sezon IstYolu satilan":
            f"İstanbul Yolu: geçen sezon satılan adet{NL}(01.08-31.10.{a.sezon})",
        "Gecen sezon IstYolu okul oncesi":
            f"İstanbul Yolu: geçen sezon okul açılmadan önce satılan adet",
        "IstYolu kullanilan oran":
            f"İstanbul Yolu: kullanılan oran{NL}(okul öncesi satılan / sezon toplamı; 30 adedin altındaysa kategori ortalaması)",
        "Bu sezon IstYolu okul oncesi":
            f"İstanbul Yolu: bu sezon okul açılmadan önce satılan adet",
        "Bu sezon IstYolu satilan":
            f"İstanbul Yolu: bu sezon bugüne kadar satılan adet",
        "IstYolu bu sezon toplam satacak":
            f"İstanbul Yolu: bu sezon toplam kaç adet satacak{NL}(okul öncesi satılan / kullanılan oran)",
        "IstYolu sezonun kalaninda satacak":
            f"İstanbul Yolu: sezonun kalanında kaç adet satacak",
        "IstYolu stok":  f"İstanbul Yolu: stok{NL}({kesim:%d.%m.%Y})",
        "IstYolu eksik adet":
            f"İstanbul Yolu: eksik adet{NL}(satacağı miktar eksi stoğu)",
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
    if grup:
        suzgec.append(f"ÜRÜN GRUBU: {grup}")
    if a.durum:
        suzgec.append({
            "siparis": "YALNIZ SIPARIS GEREKENLER "
                       "(subelerin eksigi merkez depodan karsilanamiyor)",
            "depodan": "YALNIZ MERKEZ DEPODAN GONDERILECEKLER (siparis gerekmiyor)",
            "fazla": "YALNIZ FAZLA STOK (gelecek sezona artik kaliyor)",
            "olu": "YALNIZ OLU STOK (iki sezondur satmiyor, stogu duruyor)"}[a.durum])
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
                # Urunun sezonluk olup olmadigi. Dusukse "sezonun yuzde kaci
                # okul oncesinde satildi" sorusu o satirda zayif temellidir.
                # OLCULDU (Kirtasiye): medyan 0,500; %38,7 urunde 0,40 alti ve
                # siparis tutarinin %28,7'si o urunlerden geliyor.
                "Sezon payi": (
                    f'=IF({K["Gecen yil toplam satilan"]}{i}>0,'
                    f'{K["Gecen sezon toplam satilan"]}{i}'
                    f'/{K["Gecen yil toplam satilan"]}{i},"")'),
                # TOPLAMLAR subelerin toplamidir; ayri bir hesap yapilmaz.
                # Boylece urun satiri ile sube satirlari CELISEMEZ.
                "Bu sezon toplam satilacak": (
                    f'={K["FSM bu sezon toplam satacak"]}{i}'
                    f'+{K["Ozluce bu sezon toplam satacak"]}{i}'
                    f'+{K["IstYolu bu sezon toplam satacak"]}{i}'),
                "Sezonun kalaninda satilacak": (
                    f'={K["FSM sezonun kalaninda satacak"]}{i}'
                    f'+{K["Ozluce sezonun kalaninda satacak"]}{i}'
                    f'+{K["IstYolu sezonun kalaninda satacak"]}{i}'),
                "Subelerde toplam eksik adet": (
                    f'={K["FSM eksik adet"]}{i}+{K["Ozluce eksik adet"]}{i}'
                    f'+{K["IstYolu eksik adet"]}{i}'),
                "Magazalarda toplam stok": (
                    f'={K["FSM stok"]}{i}+{K["Ozluce stok"]}{i}+{K["IstYolu stok"]}{i}'),
                "Magaza ve depo toplam stok": (
                    f'={K["Magazalarda toplam stok"]}{i}+{K["Merkez depo stok"]}{i}'),
                # Siparis = subelerin toplam eksigi eksi merkez depo stogu.
                # Once depodan gonderilir, ancak yetmeyen kismi siparis edilir.
                "Siparis verilecek adet": (
                    f'=MAX(0,{K["Subelerde toplam eksik adet"]}{i}'
                    f'-{K["Merkez depo stok"]}{i})'),
                # OLU STOK once bakilir: iki sezondur satmayan urun "fazla" degil,
                # olu stoktur ve karari farklidir (erit / iade, siparis konusu degil).
                "Durum": (
                    f'=IF(AND({K["Gecen sezon toplam satilan"]}{i}<=0,'
                    f'{K["Bu sezon bugune kadar satilan"]}{i}<=0,'
                    f'{K["Magaza ve depo toplam stok"]}{i}>0),"ÖLÜ STOK",'
                    f'IF({K["Siparis verilecek adet"]}{i}>0,"SİPARİŞ VER",'
                    f'IF({K["Subelerde toplam eksik adet"]}{i}>0,"DEPODAN GÖNDER",'
                    f'IF({K["Gelecek sezona kalacak"]}{i}>0,"FAZLA VAR","YETERLİ"))))'),
                "Siparis nereden karsilanir": (
                    f'=IF({K["Siparis verilecek adet"]}{i}=0,"",'
                    f'IF({K["Tedarikcide bulunan"]}{i}'
                    f'>={K["Siparis verilecek adet"]}{i},'
                    f'"Tedarikçide var","Yeni alım gerekiyor"))'),
                # Gelecek sezona kalacak. Eksi olabilir ve sorun degildir:
                # sezon bittikten sonra yeniden siparis verilebilir.
                "Gelecek sezona kalacak": (
                    f'={K["Magaza ve depo toplam stok"]}{i}'
                    f'-{K["Sezonun kalaninda satilacak"]}{i}'
                    f'-{K["Gecen yil sezon disi satilan"]}{i}'),
                # Siparis satirinda satis fiyatiyla, fazla satirinda maliyetle.
                # Iki tutar farkli tabandadir, TOPLANMAZ.
                "Tutar": (
                    f'=IF({K["Siparis verilecek adet"]}{i}>0,'
                    f'{K["Siparis verilecek adet"]}{i}*{K["Satis fiyati"]}{i},'
                    f'IF(AND({K["Gelecek sezona kalacak"]}{i}>0,'
                    f'{K["Birim maliyet"]}{i}<>""),'
                    f'{K["Gelecek sezona kalacak"]}{i}*{K["Birim maliyet"]}{i},""))'),
                "Siparis tutari": (
                    f'=IF({K["Durum"]}{i}="SİPARİŞ VER",{K["Tutar"]}{i},0)'),
                "Fazla stok tutari": (
                    f'=IF({K["Durum"]}{i}="FAZLA VAR",'
                    f'IF({K["Tutar"]}{i}="",0,{K["Tutar"]}{i}),0)'),
                # FSM: kendi orani, kendi tahmini, kendi eksigi.
                # ⚠ BOLME AND() ICINE KONMAZ: Excel AND'i KISA DEVRE YAPMAZ,
                # butun argumanlari hesaplar. Subenin gecen sezon satisi 0 olunca
                # "okul oncesi / sezon" #DIV/0! veriyor ve TUM ZINCIR patliyordu
                # (olculdu 16.09.2026: Defterler grubunda 6.605 satir hatali).
                # Bolme, paydanin >= 30 oldugu IC IF'e tasindi.
                "FSM kullanilan oran": (
                    f'=IF(AND({K["Gecen sezon FSM satilan"]}{i}>=30,'
                    f'{K["Gecen sezon FSM okul oncesi"]}{i}>=30),'
                    f'IF(AND({K["Gecen sezon FSM okul oncesi"]}{i}'
                    f'/{K["Gecen sezon FSM satilan"]}{i}>=0.05,'
                    f'{K["Gecen sezon FSM okul oncesi"]}{i}'
                    f'/{K["Gecen sezon FSM satilan"]}{i}<=1),'
                    f'{K["Gecen sezon FSM okul oncesi"]}{i}'
                    f'/{K["Gecen sezon FSM satilan"]}{i},'
                    f'IF({K["Kategori ortalama oran"]}{i}>0,'
                    f'{K["Kategori ortalama oran"]}{i},0.6)),'
                    f'IF({K["Kategori ortalama oran"]}{i}>0,'
                    f'{K["Kategori ortalama oran"]}{i},0.6))'),
                "FSM bu sezon toplam satacak": (
                    f'=IF({K["FSM kullanilan oran"]}{i}>0,'
                    f'CEILING({K["Bu sezon FSM okul oncesi"]}{i}'
                    f'/{K["FSM kullanilan oran"]}{i},1),0)'),
                "FSM sezonun kalaninda satacak": (
                    f'=MAX(0,{K["FSM bu sezon toplam satacak"]}{i}'
                    f'-{K["Bu sezon FSM satilan"]}{i})'),
                "FSM eksik adet": (
                    f'=MAX(0,{K["FSM sezonun kalaninda satacak"]}{i}'
                    f'-{K["FSM stok"]}{i})'),
                # Ozluce: kendi orani, kendi tahmini, kendi eksigi.
                # ⚠ BOLME AND() ICINE KONMAZ: Excel AND'i KISA DEVRE YAPMAZ,
                # butun argumanlari hesaplar. Subenin gecen sezon satisi 0 olunca
                # "okul oncesi / sezon" #DIV/0! veriyor ve TUM ZINCIR patliyordu
                # (olculdu 16.09.2026: Defterler grubunda 6.605 satir hatali).
                # Bolme, paydanin >= 30 oldugu IC IF'e tasindi.
                "Ozluce kullanilan oran": (
                    f'=IF(AND({K["Gecen sezon Ozluce satilan"]}{i}>=30,'
                    f'{K["Gecen sezon Ozluce okul oncesi"]}{i}>=30),'
                    f'IF(AND({K["Gecen sezon Ozluce okul oncesi"]}{i}'
                    f'/{K["Gecen sezon Ozluce satilan"]}{i}>=0.05,'
                    f'{K["Gecen sezon Ozluce okul oncesi"]}{i}'
                    f'/{K["Gecen sezon Ozluce satilan"]}{i}<=1),'
                    f'{K["Gecen sezon Ozluce okul oncesi"]}{i}'
                    f'/{K["Gecen sezon Ozluce satilan"]}{i},'
                    f'IF({K["Kategori ortalama oran"]}{i}>0,'
                    f'{K["Kategori ortalama oran"]}{i},0.6)),'
                    f'IF({K["Kategori ortalama oran"]}{i}>0,'
                    f'{K["Kategori ortalama oran"]}{i},0.6))'),
                "Ozluce bu sezon toplam satacak": (
                    f'=IF({K["Ozluce kullanilan oran"]}{i}>0,'
                    f'CEILING({K["Bu sezon Ozluce okul oncesi"]}{i}'
                    f'/{K["Ozluce kullanilan oran"]}{i},1),0)'),
                "Ozluce sezonun kalaninda satacak": (
                    f'=MAX(0,{K["Ozluce bu sezon toplam satacak"]}{i}'
                    f'-{K["Bu sezon Ozluce satilan"]}{i})'),
                "Ozluce eksik adet": (
                    f'=MAX(0,{K["Ozluce sezonun kalaninda satacak"]}{i}'
                    f'-{K["Ozluce stok"]}{i})'),
                # IstYolu: kendi orani, kendi tahmini, kendi eksigi.
                # ⚠ BOLME AND() ICINE KONMAZ: Excel AND'i KISA DEVRE YAPMAZ,
                # butun argumanlari hesaplar. Subenin gecen sezon satisi 0 olunca
                # "okul oncesi / sezon" #DIV/0! veriyor ve TUM ZINCIR patliyordu
                # (olculdu 16.09.2026: Defterler grubunda 6.605 satir hatali).
                # Bolme, paydanin >= 30 oldugu IC IF'e tasindi.
                "IstYolu kullanilan oran": (
                    f'=IF(AND({K["Gecen sezon IstYolu satilan"]}{i}>=30,'
                    f'{K["Gecen sezon IstYolu okul oncesi"]}{i}>=30),'
                    f'IF(AND({K["Gecen sezon IstYolu okul oncesi"]}{i}'
                    f'/{K["Gecen sezon IstYolu satilan"]}{i}>=0.05,'
                    f'{K["Gecen sezon IstYolu okul oncesi"]}{i}'
                    f'/{K["Gecen sezon IstYolu satilan"]}{i}<=1),'
                    f'{K["Gecen sezon IstYolu okul oncesi"]}{i}'
                    f'/{K["Gecen sezon IstYolu satilan"]}{i},'
                    f'IF({K["Kategori ortalama oran"]}{i}>0,'
                    f'{K["Kategori ortalama oran"]}{i},0.6)),'
                    f'IF({K["Kategori ortalama oran"]}{i}>0,'
                    f'{K["Kategori ortalama oran"]}{i},0.6))'),
                "IstYolu bu sezon toplam satacak": (
                    f'=IF({K["IstYolu kullanilan oran"]}{i}>0,'
                    f'CEILING({K["Bu sezon IstYolu okul oncesi"]}{i}'
                    f'/{K["IstYolu kullanilan oran"]}{i},1),0)'),
                "IstYolu sezonun kalaninda satacak": (
                    f'=MAX(0,{K["IstYolu bu sezon toplam satacak"]}{i}'
                    f'-{K["Bu sezon IstYolu satilan"]}{i})'),
                "IstYolu eksik adet": (
                    f'=MAX(0,{K["IstYolu sezonun kalaninda satacak"]}{i}'
                    f'-{K["IstYolu stok"]}{i})'),
            }[ad]
            c = ws.cell(i, j, f)
            c.fill = SARI
            c.number_format = (
                '#,##0.00 "₺"' if ad in ("Tutar", "Siparis tutari", "Fazla stok tutari")
                else "0.000" if "oran" in ad.lower()
                else "General" if ad in ("Durum", "Siparis nereden karsilanir")
                else "#,##0")

    genis = {"Ürün": 45, "Yıllık toplam": 13, "Sezon dışı": 12, "Durum": 10, "Kategori yolu": 40, "Kategori": 18, "Barkod": 15, "Stok kodu": 13, "Marka / Yayınevi": 22}
    for j, ad in enumerate(kolonlar, start=1):
        gor = GOSTER.get(ad, ad)
        en_uzun = max((len(p) for p in gor.split("\n")), default=len(ad))
        ws.column_dimensions[get_column_letter(j)].width = genis.get(ad, max(en_uzun + 2, 11))
    # GMY 15.09.2026: "alanlari gizleme". Hicbir kolon gizlenmez; --durum
    # yalnizca SATIR suzer. Okuyan her sayiyi ve her ara adimi gorur.
    # ── SONUÇ KOLONU RENKLİ (GMY: "en aptal bile anlamalı") ─────────────
    # ⚠ Koşullu biçimlendirme, sabit renk DEĞİL: kullanıcı büyümeyi/filtreyi
    #   değiştirip yeniden hesaplarsa renk de kendiliğinden takip eder.
    from openpyxl.formatting.rule import CellIsRule
    _son = K["Durum"]
    _ar = f"{_son}{BAS_SATIR}:{_son}{len(sat) + BAS_SATIR - 1}"
    for _deger, _zemin, _yazi in (("SİPARİŞ VER", "FFC7CE", "9C0006"),
                                  ("DEPODAN GÖNDER", "FFEB9C", "9C6500"),
                                  ("FAZLA VAR", "D9D9D9", "404040"),
                                  ("YETERLİ", "C6EFCE", "006100")):
        ws.conditional_formatting.add(_ar, CellIsRule(
            operator="equal", formula=[f'"{_deger}"'],
            fill=PatternFill("solid", bgColor=_zemin),
            font=Font(bold=True, color=_yazi)))

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
    for r in sat:
        ad = (r[ix["Marka"]] or "(marka yok)").strip() or "(marka yok)"
        sonuc, adet, _ = satir_sonuc(r, ix)
        # [cesit, SIPARIS urun/adet/TL, DEPODAN urun/adet,
        #  FAZLA urun/adet/TL, OLU STOK urun/adet/TL]
        # ⚠ FAZLA ile OLU STOK AYRI kovada: ikisinin karari farklidir. Ayni
        #   kovaya konursa marka ozeti "bu markada 5.000 fazla var" der ve
        #   fazlanin ne kadari iki sezondur hic satmayan mal, gorunmez.
        g = marka.setdefault(ad, [0, 0, 0, 0.0, 0, 0, 0, 0, 0.0, 0, 0, 0.0])
        g[0] += 1
        mal = r[ix["Birim maliyet"]]
        if sonuc == "SİPARİŞ VER":
            g[1] += 1
            g[2] += adet
            g[3] += adet * float(r[ix["Satis fiyati"]] or 0)
        elif sonuc == "DEPODAN GÖNDER":
            g[4] += 1
            g[5] += adet
        elif sonuc == "FAZLA VAR":
            g[6] += 1
            g[7] += adet
            if mal is not None:
                g[8] += adet * float(mal)
        elif sonuc == "ÖLÜ STOK":
            g[9] += 1
            g[10] += adet
            if mal is not None:
                g[11] += adet * float(mal)

    mbas = ["Marka", "Çeşit",
            "SİPARİŞ ürün", "SİPARİŞ adet", "SİPARİŞ ₺",
            "DEPODAN GÖNDER ürün", "DEPODAN GÖNDER adet",
            "FAZLA ürün", "FAZLA adet", "FAZLA ₺",
            "ÖLÜ STOK ürün", "ÖLÜ STOK adet", "ÖLÜ STOK ₺"]

    mnot = (f"Marka bazlı özet · kesim {kesim:%d.%m.%Y} · oran "
            + ("ELLE %{:g}".format(a.buyume * 100) if a.buyume is not None
               else "KATEGORİ BAZLI ÖLÇÜLDÜ") + " · "
            f"{len(marka):,} marka".replace(",", ".") + " · "
            "AL = raf sezonu çıkarmıyor VE toplam yıl sonuna yetmiyor (satış fiyatı) · "
            "TAŞI = raf eksik ama DEPODA var, sipariş gerekmiyor · "
            "ERİT = gelecek sezona artık kalıyor (maliyet). ÜÇ TUTAR TOPLANMAZ.")
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

    # AL tutarina gore buyukten kucuge — alici en buyuk siparisten baslasin.
    for i, (ad, g) in enumerate(sorted(marka.items(), key=lambda x: -x[1][3]), start=4):
        for j, v in enumerate([ad] + g, start=1):
            c = mws.cell(i, j, v)
            c.number_format = ('#,##0 "₺"' if j in (5, 10, 13)
                               else "#,##0" if j > 1 else "General")

    mgenis = {"Marka": 34}
    for j, b in enumerate(mbas, start=1):
        mws.column_dimensions[get_column_letter(j)].width = mgenis.get(b, max(len(b) + 2, 12))
    mws.freeze_panes = "B4"
    mws.auto_filter.ref = f"A3:{get_column_letter(len(mbas))}{len(marka) + 3}"

    # ── Konsol özeti — Excel'in hesaplayacağının AYNISI, Python'da ────────────
    #    (dosyada formül olduğu için openpyxl değer okuyamaz; kontrol burada)
    cesit = len(sat)
    say: dict[str, list] = {e: [0, 0, 0.0] for e in
                            ("SİPARİŞ VER", "DEPODAN GÖNDER", "FAZLA VAR",
                             "ÖLÜ STOK", "YETERLİ")}
    odak_c = ted_c = 0
    malsiz = 0
    for r in sat:
        sonuc, adet, _ = satir_sonuc(r, ix)
        g = say[sonuc]
        g[0] += 1
        g[1] += adet
        if sonuc == "SİPARİŞ VER":
            g[2] += adet * float(r[ix["Satis fiyati"]] or 0)
            if (r[ix["Tedarikcide bulunan"]] or 0) >= adet:
                odak_c += 1
            else:
                ted_c += 1
        elif sonuc in ("FAZLA VAR", "ÖLÜ STOK"):
            mal = r[ix["Birim maliyet"]]
            if mal is None:
                malsiz += 1
            else:
                g[2] += adet * float(mal)

    # Dosya adı: Türkçe harfler DÜŞÜRÜLMEZ, karşılığına ÇEVRİLİR — "Krtasiye" gibi
    # okunmaz ad üretmesin (ı ve ş sessizce siliniyordu).
    TR = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")
    ek = ("-" + a.durum if a.durum else "")
    if kategori:
        ek += "-" + re.sub(r"[^A-Za-z0-9]+", "", kategori.translate(TR))
    if grup:
        ek += "-" + re.sub(r"[^A-Za-z0-9]+", "", grup.translate(TR))
    cikti = a.cikti or os.path.join(
        KOK, "raporlar", f"sezon-aksiyon-listesi-{kesim:%Y%m%d}{ek}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)

    if a.pivot:
        # Pivot alanları GÖRÜNEN başlıkla verilir (GOSTER çözülmüş).
        # ⚠ PivotFields GÖRÜNEN başlıkla eşleşir, iç anahtarla DEĞİL.
        # PivotFields GORUNEN baslikla eslesir, ic anahtarla degil.
        _pv = [(GOSTER.get(k, k), a, p) for k, a, p in (
            ("Siparis verilecek adet",      "Siparis adet", False),
            ("Subelerde toplam eksik adet", "Subelerde eksik adet", False),
            ("Siparis tutari",              "Siparis tutari TL", True),
            ("Fazla stok tutari",           "Fazla stok tutari TL", True),
        ) if k in K]
        pivot_durum = pivot_kur(cikti, len(kolonlar), len(sat) + BAS_SATIR - 1, _pv)
        print(f"  PIVOT: {pivot_durum}")

    print(f"YAZILDI: {cikti}")
    print(f"  cesit {ayir(cesit)}")
    for e, aciklama in (("SİPARİŞ VER", "sezonun kalani elimizdekini asiyor (satis fiyati)"),
                        ("DEPODAN GÖNDER", "toplam yetiyor ama bir subenin rafi bos"),
                        ("FAZLA VAR", "gelecek sezona artik kaliyor (maliyet)"),
                        ("ÖLÜ STOK", "iki sezondur satmiyor, stogu duruyor (maliyet)"),
                        ("YETERLİ", "")):
        g = say[e]
        tl = f" · {ayir(g[2])} TL" if g[2] else ""
        ad = f" · {ayir(g[1])} adet" if g[1] else ""
        print(f"  {e:<16}{ayir(g[0]):>7} urun{ad}{tl}   {aciklama}")
    print(f"  siparisin ODAK'tan gelebileni {ayir(odak_c)} urun · "
          f"tedarikciye gidecek {ayir(ted_c)} urun")
    print(f"  maliyeti yok/supheli (paraya girmeyen): {ayir(malsiz)} cesit")



if __name__ == "__main__":
    raise SystemExit(main())
