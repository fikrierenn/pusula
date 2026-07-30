/*
  Soru:  E-ticaret (JOKER) kredi kartı siparişlerinde iptal/iade DETAY + özet — sipariş + satır bazında.
  DB:    DerinSISBkm üzerinden ODAKJOKER.JOKER linked server. Tarih literali: YYYYMMDD ISO (linked'de DMY sessiz yanlış).
  Grain: SATIR (J_ORDER_DETAILS) — gerçek iptal/iade katmanı. Header (J_ORDERS.STATUS) kısmi iptali KAÇIRIR
         (ör. TS110730641852: header 1005 "Kargoya Verildi" ama 1 kalem 2004 "Baskısı Bulunamıyor" = fiili iptal).
  Kodlar (J_ORDER_DETAILS.STATUS → J_ORDER_STATUS.LOGICALREF=NAME):
         2005 = Ürün İptal Edildi      (müşteri/operasyon iptali)
         2010 = Ürün İade Geldi        (teslimat sonrası iade)
         2004 = Ürünün Baskısı Bulunamıyor (tedarik edilemedi = fiili iptal, ayrı kategori)
         2009 = Ürün Kargoya Verildi (normal) · 4xxx = Odak operasyon ara aşama
  Ödeme: PAYDEFREF -13=iyzico/kart · -3=Kapıda Ödeme · -1=Havale. Taksitli = -13 AND SERVICEPRICE>0 (KESİN ayrım).
         ⚠ FAİZSİZ TAKSİT YOK (kullanıcı teyit 2026-07-30) → her taksitte vade farkı var → SERVICEPRICE>0 = KESİN taksitli,
           SERVICEPRICE=0 = KESİN tek çekim (peşin). Proxy DEĞİL, tam ayrım — peşine sızma yok.
         (SERVICEPRICE = kart tarafında VADE FARKI.) Taksit SAYISI JOKER'de yazılı değil, ama taksitli/peşin ayrımı kesin.
         Kademe = vade farkı oranı (10,44/13,52/16,29/19,62/31,14/38,33) — taksit adedi proxy'si.
  Köprü: J_ORDER_DETAILS.ORDERREF = J_ORDERS.ORDERID (LOGICALREF DEĞİL). Ürün: d.ITEMREF = J_ITEMS.LOGICALREF.

  ⚠ İKİ PARASAL TABAN (sql-denetci bulgu #1 — "ikisi de" kararı):
     • BRÜT / TAHSİLAT (KDV+kargo+vade farkı DAHİL) = müşterinin ödediği / geri aldığı gerçek NAKİT.
         ürün = d.SELLINGPRICE · sipariş = o.TOTALPRICE. İade/nakit-etki analizinin doğru tabanı.
     • NET CİRO (KDV-hariç, kargo+vade farkı HARİÇ) = plan-16 canonical ciro; CFO net-ciro ile kıyaslanabilir.
         ürün = d.SELLINGPRICEWITHOUTVAT. (Kitap %0 KDV → ürün brüt=net; fark kırtasiye/oyuncak %20 + kargo/VF %20.)
     "Ciro" kelimesi NET içindir; müşteri-nakit için "Tahsilat/Brüt" kolonları kullanılır.

  ⚠ sql-denetci bulgu #2 (0-sepet sızıntısı): tüm satırı hediye-çeki (SELLINGPRICE=0) olan siparişte prorate paydası 0
     → vade farkı/kargo payı NULL → toplamdan sessiz düşer (~%0,014). Aggregate bloklarda SifirSepetSiparis kolonu ile GÖRÜNÜR kılındı.
  ⚠ sql-denetci bulgu #3 (guard): SERVICEPRICE-bazlı Taksitli/Tek-Çekim ayrımı SADECE kart (-13) için geçerli.
     @paydef=-13 dışına çıkma (COD SERVICEPRICE = COD bedeli, vade farkı değil). Tüm-ödeme için PAYDEFREF-bazlı blok kullan.
*/

------------------------------------------------------------------------------------------------------
-- BLOK 1 — DETAY (satır bazında iptal/iade + dağıtılmış vade farkı/kargo + iade mantığı + sipariş bağlamı)
------------------------------------------------------------------------------------------------------
DECLARE @bas date = '20260701';      -- dönem başı (dahil)
DECLARE @bit date = '20260801';      -- dönem sonu (HARİÇ — bir sonraki ayın 1'i)
DECLARE @paydef int = -13;           -- -13 kart(iyzico). SERVICEPRICE-ayrımı guard: -13 dışına çıkma (bkz başlık #3)
DECLARE @sadeceTaksitli bit = 1;     -- 1=yalnız TAKSİTLİ sipariş (SERVICEPRICE>0) · 0=tümü
DECLARE @sadeceProblemli bit = 0;    -- 0=TÜM satır/sipariş (taksitli olup iptalsiz de gelir) · 1=yalnız iptal/iade içeren sipariş

WITH tumSatir AS (
    SELECT
        o.ORDERCODE,
        CAST(o.ORDERDATE AS date)                    AS SiparisTarih,
        o.APPLICATION                                AS Kanal,
        p.NAME                                       AS OdemeTipi,
        CASE WHEN o.SERVICEPRICE > 0 THEN 'Taksitli' ELSE 'Pesin' END AS OdemeGrup,
        o.SERVICEPRICE                               AS SiparisVadeFarki,   -- sipariş TOPLAM vade farkı (tüm ürünler için alınır)
        o.CARGOPRICE                                 AS SiparisKargo,       -- sipariş TOPLAM kargo (tüm ürünler için alınır)
        CAST(ROUND(10000.0 * o.SERVICEPRICE
              / NULLIF(o.TOTALPRICE - o.SERVICEPRICE, 0), 0) AS int) AS VadeFarkiOran4,  -- x100=% (kademe; payda kargo dahil ~yaklaşık)
        o.TOTALPRICE                                 AS SiparisToplam,      -- BRÜT (KDV+kargo+VF dahil)
        i.NAME                                       AS Urun,
        d.QUANTITY                                   AS Adet,
        d.SELLINGPRICE                               AS BirimFiyatBrut,     -- KDV-dahil birim
        d.SELLINGPRICEWITHOUTVAT                      AS BirimFiyatNet,      -- KDV-hariç birim
        d.QUANTITY * d.SELLINGPRICE                  AS SatirTutar,         -- BRÜT ürün (KDV-dahil)
        d.QUANTITY * d.SELLINGPRICEWITHOUTVAT         AS SatirTutarNet,      -- NET ürün (KDV-hariç = ciro)
        SUM(d.QUANTITY * d.SELLINGPRICE) OVER (PARTITION BY o.ORDERID) AS SiparisSepet,  -- tüm satır BRÜT toplamı (dağıtım tabanı)
        MAX(CASE WHEN d.STATUS NOT IN (2004, 2005) THEN 1 ELSE 0 END) OVER (PARTITION BY o.ORDERID) AS SiparisSevkVar,  -- sevk edilen ürün var mı? (kargo iade koşulu)
        COUNT(*) OVER (PARTITION BY o.ORDERID)                                                AS SiparisKalemAdet,      -- siparişin TOPLAM kalem sayısı (bağlam)
        SUM(CASE WHEN d.STATUS IN (2004,2005,2010) THEN 1 ELSE 0 END) OVER (PARTITION BY o.ORDERID) AS SiparisProblemliAdet,  -- iptal+iade+baskısıyok kalem
        SUM(CASE WHEN d.STATUS NOT IN (2004,2005,2010) THEN 1 ELSE 0 END) OVER (PARTITION BY o.ORDERID) AS SiparisNormalAdet,  -- teslim/normal kalem
        d.STATUS                                     AS SatirDurumKod,
        s.NAME                                       AS SatirDurum,
        CASE d.STATUS WHEN 2005 THEN 'IPTAL' WHEN 2010 THEN 'IADE'
                      WHEN 2004 THEN 'BASKISI-YOK' ELSE 'NORMAL' END AS Kategori,
        LTRIM(RTRIM(d.IPTALSEBEP))                   AS IptalSebep,
        d.IPTALTARIH                                 AS IptalTarih,
        d.IADESEBEPNO                                AS IadeSebepNo,
        LTRIM(RTRIM(d.IADEACIKLAMA))                 AS IadeAciklama,
        d.IADEMIKTAR                                 AS IadeMiktar,
        d.IADETALEPTARIH                             AS IadeTalepTarih
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
        JOIN ODAKJOKER.JOKER.dbo.J_ORDER_DETAILS d ON d.ORDERREF = o.ORDERID
        LEFT JOIN ODAKJOKER.JOKER.dbo.J_ORDER_PAY_TYPES p ON p.ID = o.PAYDEFREF
        LEFT JOIN ODAKJOKER.JOKER.dbo.J_ORDER_STATUS s ON s.LOGICALREF = d.STATUS
        LEFT JOIN ODAKJOKER.JOKER.dbo.J_ITEMS i ON i.LOGICALREF = d.ITEMREF
    WHERE o.ORDERDATE >= @bas
      AND o.ORDERDATE <  @bit
      AND (@paydef IS NULL OR o.PAYDEFREF = @paydef)
      AND (@sadeceTaksitli = 0 OR o.SERVICEPRICE > 0)   -- taksitli = SERVICEPRICE>0 (faizsiz taksit yok → kesin)
      AND NOT EXISTS (SELECT 1 FROM ODAKJOKER.JOKER.dbo.J_ORDERS b WHERE b.BASEORDERID = o.ORDERID)  -- türemiş varsa asılı çıkar (çift-sayım)
      -- ⚠ status filtresi BURADA YOK: vade farkı/kargo dağıtımı sipariş GENELİ (tüm satırlar) üzerinden hesaplanır
), oranli AS (
    SELECT *,
        -- Vade farkı + kargo TÜM ÜRÜNLER için alınır → her satıra BRÜT ürün tutarı oranında DAĞITILIR (tek ürüne YAZMA).
        -- Doğrulama TS110730641852: 259,35→VF 118,30 · 213,85→VF 97,54 · toplam 215,84 = sipariş vade farkı ✓
        CAST(SiparisVadeFarki * SatirTutar / NULLIF(SiparisSepet, 0) AS money) AS VadeFarkiPayi,
        CAST(SiparisKargo     * SatirTutar / NULLIF(SiparisSepet, 0) AS money) AS KargoPayi
    FROM tumSatir
)
SELECT ORDERCODE, SiparisTarih, Kanal, OdemeTipi, OdemeGrup, VadeFarkiOran4,
       Urun, Adet, BirimFiyatBrut, BirimFiyatNet,
       SatirTutar        AS SatirTutarBrut,   -- KDV-dahil ürün (nakit)
       SatirTutarNet,                         -- KDV-hariç ürün (ciro)
       VadeFarkiPayi, KargoPayi,              -- bu ÜRÜNÜN payına düşen komisyon / kargo (dağıtılmış, BRÜT)
       -- İADE MANTIĞI — SADECE problemli (iptal/iade/baskısıyok) satırda dolu; NORMAL/teslim satırda 0.
       --   (Bu guard sayesinde WHERE filtresi kaldırılıp TÜM sipariş satırları görüntülense bile teslim satırında iade=0.)
       CASE WHEN Kategori <> 'NORMAL' THEN SatirTutar ELSE 0 END        AS IadeUrunBrut,   -- ürün bedeli (KDV-dahil) iade
       CASE WHEN Kategori <> 'NORMAL' THEN SatirTutarNet ELSE 0 END     AS IadeUrunNet,    -- aynı, KDV-hariç (ciro-kaybı)
       CASE WHEN Kategori <> 'NORMAL' THEN VadeFarkiPayi ELSE 0 END     AS IadeVadeFarki,  -- vade farkı payı iade
       CASE WHEN Kategori <> 'NORMAL' AND SiparisSevkVar = 0 THEN KargoPayi ELSE 0 END AS IadeKargo,  -- kargo: sadece komple iptalde
       CASE WHEN Kategori <> 'NORMAL'
            THEN SatirTutar + VadeFarkiPayi + CASE WHEN SiparisSevkVar = 0 THEN KargoPayi ELSE 0 END
            ELSE 0 END                                                   AS IadeToplamBrut,  -- toplam geri nakit (yalnız problemli)
       CASE WHEN SiparisSevkVar = 0 THEN 'Komple Iptal' ELSE 'Kismi' END AS IptalTipi,  -- siparişin tamamı mı iptal, yoksa bazı kalem mi?
       SiparisKalemAdet, SiparisProblemliAdet, SiparisNormalAdet,       -- SİPARİŞ BAĞLAMI: bu iptal, N kalemin kaçı? (ör. 21 kalem / 1 iptal / 20 teslim)
       SiparisVadeFarki, SiparisKargo, SiparisToplam, SiparisSevkVar,   -- sipariş geneli (referans, BRÜT)
       SatirDurum, Kategori, IptalSebep, IptalTarih, IadeSebepNo, IadeAciklama, IadeMiktar, IadeTalepTarih
FROM oranli
WHERE (@sadeceProblemli = 0 OR SiparisProblemliAdet > 0)   -- 0=tüm sipariş (taksitli olup iptalsiz DAHİL) · 1=yalnız iptal/iade içeren
--   İnce ayar (istenirse el ile):
--     · yalnız problemli SATIR (kısa liste):  AND Kategori IN ('IPTAL','IADE','BASKISI-YOK')
ORDER BY SiparisTarih DESC, ORDERCODE, Kategori DESC, Urun;
-- Kullanım: tek sipariş → WHERE'e AND ORDERCODE='...' · tüm ödeme → @paydef=NULL (SERVICEPRICE-ayrımı için -13 önerilir)


------------------------------------------------------------------------------------------------------
-- BLOK 2 — TAM ÖZET (Tek Çekim vs Taksitli) — normal dahil, oranlı, iade mantıklı, BRÜT + NET
--   Siparis/ProblemliSiparis = distinct sipariş · Brüt=nakit (KDV+kargo+VF) · NetCiro=ürün KDV-hariç (plan-16)
--   SifirSepetSiparis = prorate paydası 0 olan (hediye-çeki) sipariş sayısı — vade farkı/kargo payı bu satırlarda düşer (görünür kılındı)
------------------------------------------------------------------------------------------------------
DECLARE @t_bas date = '20260701', @t_bit date = '20260801';
DECLARE @t_paydef int = -13;   -- ⚠ SERVICEPRICE-bazlı grup → -13 dışına çıkma (bulgu #3)

SELECT
    x.grup                                                              AS Grup,
    COUNT(DISTINCT x.ORDERID)                                           AS Siparis,
    COUNT(DISTINCT CASE WHEN x.prob = 1 THEN x.ORDERID END)             AS ProblemliSiparis,
    COUNT(DISTINCT CASE WHEN x.SiparisSepet = 0 THEN x.ORDERID END)     AS SifirSepetSiparis,   -- prorate sızıntısı görünür (bulgu #2)
    COUNT(*)                                                            AS ToplamKalem,
    SUM(x.SatirTutar)                                                   AS ToplamUrunBrut,       -- KDV-dahil ürün
    SUM(x.SatirTutarNet)                                               AS ToplamUrunNet,        -- KDV-hariç ürün = NET CİRO
    SUM(x.vfPayi)                                                       AS AlinanVadeFarki,
    SUM(x.kargoPayi)                                                    AS AlinanKargo,
    SUM(x.SatirTutar) + SUM(x.vfPayi) + SUM(x.kargoPayi)               AS BrutTahsilat,         -- müşteri nakit (KDV+kargo+VF)
    SUM(x.SatirTutarNet)                                               AS NetCiro,              -- plan-16 CFO-kıyas (=ToplamUrunNet)
    SUM(x.prob)                                                         AS ProblemliKalem,
    SUM(CASE WHEN x.prob = 1 THEN x.SatirTutar ELSE 0 END)             AS IadeUrunBrut,
    SUM(CASE WHEN x.prob = 1 THEN x.SatirTutarNet ELSE 0 END)          AS IadeUrunNet,
    SUM(CASE WHEN x.prob = 1 THEN x.vfPayi ELSE 0 END)                 AS IadeVadeFarki,
    SUM(CASE WHEN x.prob = 1 AND x.sevkVar = 0 THEN x.kargoPayi ELSE 0 END) AS IadeKargo,
    SUM(CASE WHEN x.prob = 1 THEN x.SatirTutar + x.vfPayi ELSE 0 END)
        + SUM(CASE WHEN x.prob = 1 AND x.sevkVar = 0 THEN x.kargoPayi ELSE 0 END) AS IadeToplamBrut,
    SUM(CASE WHEN x.prob = 1 THEN x.SatirTutarNet ELSE 0 END)          AS IadeCiroKaybiNet   -- KDV-hariç ürün ciro kaybı
FROM (
    SELECT
        o.ORDERID,
        CASE WHEN o.SERVICEPRICE > 0 THEN 'Taksitli' ELSE 'Tek Cekim' END AS grup,
        CASE WHEN d.STATUS IN (2004, 2005, 2010) THEN 1 ELSE 0 END        AS prob,
        d.QUANTITY * d.SELLINGPRICE                                       AS SatirTutar,
        d.QUANTITY * d.SELLINGPRICEWITHOUTVAT                              AS SatirTutarNet,
        SUM(d.QUANTITY * d.SELLINGPRICE) OVER (PARTITION BY o.ORDERID)     AS SiparisSepet,
        CAST(o.SERVICEPRICE * (d.QUANTITY * d.SELLINGPRICE)
             / NULLIF(SUM(d.QUANTITY * d.SELLINGPRICE) OVER (PARTITION BY o.ORDERID), 0) AS money) AS vfPayi,
        CAST(o.CARGOPRICE * (d.QUANTITY * d.SELLINGPRICE)
             / NULLIF(SUM(d.QUANTITY * d.SELLINGPRICE) OVER (PARTITION BY o.ORDERID), 0) AS money) AS kargoPayi,
        MAX(CASE WHEN d.STATUS NOT IN (2004, 2005) THEN 1 ELSE 0 END) OVER (PARTITION BY o.ORDERID) AS sevkVar
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
        JOIN ODAKJOKER.JOKER.dbo.J_ORDER_DETAILS d ON d.ORDERREF = o.ORDERID
    WHERE o.ORDERDATE >= @t_bas
      AND o.ORDERDATE <  @t_bit
      AND (@t_paydef IS NULL OR o.PAYDEFREF = @t_paydef)
      AND NOT EXISTS (SELECT 1 FROM ODAKJOKER.JOKER.dbo.J_ORDERS b WHERE b.BASEORDERID = o.ORDERID)  -- türemiş varsa asılı çıkar
) x
GROUP BY x.grup;
-- Oranlar: ProblemliKalem/ToplamKalem · IadeToplamBrut/BrutTahsilat · NetKalanCiro = NetCiro - IadeCiroKaybiNet.


------------------------------------------------------------------------------------------------------
-- BLOK 3 — TÜM ÖDEME TİPLERİ — grup PAYDEFREF bazlı (COD'yi taksitliye KARIŞTIRMAZ). BRÜT + NET.
--   ⚠ SERVICEPRICE çift anlamlı: -13 kart→VADE FARKI · -3 kapıda→COD BEDELİ. Grup PAYDEFREF'e göre (SERVICEPRICE'a göre DEĞİL).
--   ServisBedeli: kart-taksitli→vade farkı, kapıda→COD bedeli (satır grubu homojen → anlam net).
--   Not: Kapıda iptalinde COD bedeli zaten tahsil edilmez (teslimde ödenir) → IadeServis potansiyel kayıp, gerçek geri-ödeme değil.
------------------------------------------------------------------------------------------------------
DECLARE @a_bas date = '20260701', @a_bit date = '20260801';

SELECT
    x.grup                                                              AS OdemeTipi,
    COUNT(DISTINCT x.ORDERID)                                           AS Siparis,
    COUNT(DISTINCT CASE WHEN x.prob = 1 THEN x.ORDERID END)             AS ProblemliSiparis,
    COUNT(DISTINCT CASE WHEN x.SiparisSepet = 0 THEN x.ORDERID END)     AS SifirSepetSiparis,
    COUNT(*)                                                            AS ToplamKalem,
    SUM(x.SatirTutar)                                                   AS ToplamUrunBrut,
    SUM(x.SatirTutarNet)                                               AS ToplamUrunNet,
    SUM(x.servisPayi)                                                   AS ServisBedeli,   -- VF (kart) / COD (kapıda)
    SUM(x.kargoPayi)                                                    AS AlinanKargo,
    SUM(x.SatirTutar) + SUM(x.servisPayi) + SUM(x.kargoPayi)           AS BrutTahsilat,   -- müşteri nakit
    SUM(x.SatirTutarNet)                                               AS NetCiro,        -- plan-16 CFO-kıyas
    SUM(x.prob)                                                         AS ProblemliKalem,
    SUM(CASE WHEN x.prob = 1 THEN x.SatirTutar ELSE 0 END)             AS IadeUrunBrut,
    SUM(CASE WHEN x.prob = 1 THEN x.SatirTutarNet ELSE 0 END)          AS IadeUrunNet,
    SUM(CASE WHEN x.prob = 1 THEN x.servisPayi ELSE 0 END)             AS IadeServis,
    SUM(CASE WHEN x.prob = 1 AND x.sevkVar = 0 THEN x.kargoPayi ELSE 0 END) AS IadeKargo
FROM (
    SELECT
        o.ORDERID,
        CASE WHEN o.PAYDEFREF = -13 AND o.SERVICEPRICE > 0 THEN 'Kart-Taksitli'
             WHEN o.PAYDEFREF = -13 THEN 'Kart-Tek Cekim'
             WHEN o.PAYDEFREF = -3  THEN 'Kapida Odeme'
             WHEN o.PAYDEFREF = -1  THEN 'Havale/EFT'
             ELSE 'Diger(' + CAST(o.PAYDEFREF AS varchar) + ')' END      AS grup,
        CASE WHEN d.STATUS IN (2004, 2005, 2010) THEN 1 ELSE 0 END        AS prob,
        d.QUANTITY * d.SELLINGPRICE                                       AS SatirTutar,
        d.QUANTITY * d.SELLINGPRICEWITHOUTVAT                              AS SatirTutarNet,
        SUM(d.QUANTITY * d.SELLINGPRICE) OVER (PARTITION BY o.ORDERID)     AS SiparisSepet,
        CAST(o.SERVICEPRICE * (d.QUANTITY * d.SELLINGPRICE)
             / NULLIF(SUM(d.QUANTITY * d.SELLINGPRICE) OVER (PARTITION BY o.ORDERID), 0) AS money) AS servisPayi,
        CAST(o.CARGOPRICE * (d.QUANTITY * d.SELLINGPRICE)
             / NULLIF(SUM(d.QUANTITY * d.SELLINGPRICE) OVER (PARTITION BY o.ORDERID), 0) AS money) AS kargoPayi,
        MAX(CASE WHEN d.STATUS NOT IN (2004, 2005) THEN 1 ELSE 0 END) OVER (PARTITION BY o.ORDERID) AS sevkVar
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
        JOIN ODAKJOKER.JOKER.dbo.J_ORDER_DETAILS d ON d.ORDERREF = o.ORDERID
    WHERE o.ORDERDATE >= @a_bas
      AND o.ORDERDATE <  @a_bit
      AND NOT EXISTS (SELECT 1 FROM ODAKJOKER.JOKER.dbo.J_ORDERS b WHERE b.BASEORDERID = o.ORDERID)  -- türemiş varsa asılı çıkar
) x
GROUP BY x.grup;


------------------------------------------------------------------------------------------------------
-- BLOK 4 — GELİR / KOMİSYON / KARGO (SİPARİŞ grain, detay join YOK → BRÜT tahsilat).
--   ⚠ SERVICEPRICE/CARGOPRICE sipariş başlığında; detay join edilirse çoğalır → AYRI sorgu, düz J_ORDERS.
--   NET CİRO burada YOK (ürün KDV-hariç satır-bazlı gerekir → Blok 2/3'te). Bu blok müşteri-nakit (BRÜT) gelir kalemleri.
--   Not: Komisyon = alınan vade farkı (BRÜT tahsil; kısmi iptalde iade edilen kısım JOKER'de netleşmez — iyzico ekstresinde).
------------------------------------------------------------------------------------------------------
DECLARE @g_bas date = '20260701', @g_bit date = '20260801';
DECLARE @g_paydef int = -13;   -- ⚠ SERVICEPRICE-bazlı grup → -13 dışına çıkma

SELECT
    CASE WHEN o.SERVICEPRICE > 0 THEN 'Taksitli' ELSE 'Tek Cekim' END  AS Grup,
    COUNT(*)                        AS Siparis,
    SUM(o.TOTALPRICE)               AS BrutTahsilat,             -- KDV+kargo+VF dahil (müşteri nakit, NET ciro DEĞİL)
    SUM(o.PRICEWITHOUTVAT)          AS ToplamKdvHaric,           -- KDV-hariç (kargo/VF dahil olabilir — saf ciro değil, referans)
    SUM(o.SERVICEPRICE)             AS AlinanKomisyon_VadeFarki,
    SUM(o.CARGOPRICE)               AS AlinanKargo,
    SUM(o.VOUCHERVALUE)             AS HediyeCekiKullanilan
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
WHERE o.ORDERDATE >= @g_bas
  AND o.ORDERDATE <  @g_bit
  AND (@g_paydef IS NULL OR o.PAYDEFREF = @g_paydef)
  AND NOT EXISTS (SELECT 1 FROM ODAKJOKER.JOKER.dbo.J_ORDERS b WHERE b.BASEORDERID = o.ORDERID)  -- türemiş varsa asılı çıkar
GROUP BY CASE WHEN o.SERVICEPRICE > 0 THEN 'Taksitli' ELSE 'Tek Cekim' END;


------------------------------------------------------------------------------------------------------
-- BLOK 5 — SİPARİŞ TİPİ: KOMPLE İPTAL vs KISMİ vs TEMİZ (SİPARİŞ grain). BRÜT + NET.
--   Kalem-bazlı rapor "5 iptal kalem"in tek komple-iptal mi 5 ayrı kısmi mi olduğunu gizler; bu blok ayırır.
--   Komple İptal = hiç sevk yok (tüm satır 2004/2005) → tüm sipariş bedeli geri (kargo dahil).
--   Kısmi = ≥1 problemli + ≥1 sevk → kargo tutulur. Temiz = problemli yok. (Tümü-iade 2010 → 'Kısmi', sevk olmuş.)
------------------------------------------------------------------------------------------------------
DECLARE @k_bas date = '20260701', @k_bit date = '20260801';
DECLARE @k_paydef int = -13;

SELECT
    CASE WHEN x.sevkVar = 0 THEN '1-Komple Iptal'
         WHEN x.hasProblem = 1 THEN '2-Kismi (bazi kalem iptal/iade)'
         ELSE '3-Temiz' END                    AS SiparisTipi,
    COUNT(*)                                    AS Siparis,
    SUM(x.TOTALPRICE)                           AS BrutTahsilat,   -- KDV+kargo+VF dahil (nakit)
    SUM(x.UrunNet)                              AS NetCiro         -- KDV-hariç ürün (plan-16 ciro)
FROM (
    SELECT o.ORDERID,
        MAX(o.TOTALPRICE)                                                AS TOTALPRICE,
        SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT)                        AS UrunNet,
        MAX(CASE WHEN d.STATUS NOT IN (2004, 2005) THEN 1 ELSE 0 END)    AS sevkVar,
        MAX(CASE WHEN d.STATUS IN (2004, 2005, 2010) THEN 1 ELSE 0 END)  AS hasProblem
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
        JOIN ODAKJOKER.JOKER.dbo.J_ORDER_DETAILS d ON d.ORDERREF = o.ORDERID
    WHERE o.ORDERDATE >= @k_bas
      AND o.ORDERDATE <  @k_bit
      AND (@k_paydef IS NULL OR o.PAYDEFREF = @k_paydef)
      AND NOT EXISTS (SELECT 1 FROM ODAKJOKER.JOKER.dbo.J_ORDERS b WHERE b.BASEORDERID = o.ORDERID)  -- türemiş varsa asılı çıkar
    GROUP BY o.ORDERID
) x
GROUP BY CASE WHEN x.sevkVar = 0 THEN '1-Komple Iptal'
              WHEN x.hasProblem = 1 THEN '2-Kismi (bazi kalem iptal/iade)'
              ELSE '3-Temiz' END;
