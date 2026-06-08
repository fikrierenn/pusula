-- =====================================================================
-- C1 — RFM MÜŞTERİ SEGMENTASYONU (OMNICHANNEL: e-ticaret + yazarkasa)
-- Amaç: Müşterileri Recency/Frequency/Monetary ile segmentle — kim şampiyon,
--        kim kayıp, kimi reaktive et. Pazarlama/CRM önceliği.
-- İKİ AYRI MÜŞTERİ EVRENİ (kimlik sistemleri farklı, birleştirilemez):
--   BLOK A — E-ticaret: ODAKJOKER.JOKER, J_ORDER_CLIENTS.CUSTOMERREF (>0), ISO tarih.
--   BLOK B — Yazarkasa: EncoreMerkez.Sales.CustomersId (>0), sadakat kartı (%50 penetrasyon).
--   ⚠️ JOKER CUSTOMERREF ≠ EncoreMerkez CustomersId — aynı kişi iki evrende eşleşmez (kimlik köprüsü yok).
-- Pencere: son 365 gün.
-- DOĞRULAMA (08.06.2026):
--   E-ticaret: Şampiyon 8.923 (11K ₺, 9,2 sip.) · Kayıp 335.512 (353M, reaktivasyon).
--   Yazarkasa: Şampiyon 4.082 (12.6K ₺, 19,9 fiş!) · Sadık 21.347 · Kayıp 20.010 (850 ₺).
-- KARAKTER: Yazarkasa yüksek frekans (haftada bir), e-ticaret yüksek sepet.
-- ⚠️ Yazarkasa: sadece DocumentsTypeId=1 (perakende fiş) — fatura(2)/sınav(8)/personel kurumsal
--   tek-seferlik dev alımları HARİÇ (Kayıp segmentini şişiriyordu). E-ticaret: brüt TOTALPRICE.
-- NOT: MCP-safe (CTE'siz). İki blok ayrı çalıştırılır. ISO/DMY dikkat.
-- =====================================================================

-- ============ BLOK A — E-TİCARET (JOKER) ============
SELECT N'E-TİCARET' AS Kanal, seg.Segment,
    COUNT(*)                                          AS [Müşteri],
    CAST(SUM(c.Monetary) AS decimal(18,0))            AS [Toplam Ciro ₺],
    CAST(AVG(c.Monetary) AS decimal(18,0))            AS [Ort. Müşteri ₺],
    CAST(AVG(c.Frequency*1.0) AS decimal(10,1))       AS [Ort. Sipariş]
FROM (
    SELECT oc.CUSTOMERREF,
        DATEDIFF(DAY, MAX(o.ORDERDATE), CONVERT(date, CONVERT(varchar(8),GETDATE(),112))) AS RecencyGun,
        COUNT(*) AS Frequency, SUM(o.TOTALPRICE) AS Monetary
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
    JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF = o.CLIENTREF
    WHERE o.ORDERDATE >= CONVERT(varchar(8), DATEADD(DAY,-365,GETDATE()), 112) AND oc.CUSTOMERREF > 0
    GROUP BY oc.CUSTOMERREF
) c
CROSS APPLY (SELECT CASE
    WHEN c.Frequency >= 5 AND c.RecencyGun <= 30  THEN N'1-Şampiyon'
    WHEN c.Frequency >= 3 AND c.RecencyGun <= 90  THEN N'2-Sadık'
    WHEN c.Frequency <= 2 AND c.RecencyGun <= 30  THEN N'3-Yeni/Gelişen'
    WHEN c.RecencyGun BETWEEN 91 AND 180          THEN N'4-Risk Altında'
    WHEN c.RecencyGun > 180                       THEN N'5-Kayıp (180+ gün)'
    ELSE N'6-Diğer' END AS Segment) seg
GROUP BY seg.Segment;

-- ============ BLOK B — YAZARKASA (EncoreMerkez, sadakat kartı) ============
-- Eşik farkı: yazarkasa frekansı yüksek → Şampiyon >=8 fiş (e-ticaret >=5 sipariş).
DECLARE @Bugun date = CAST(CONVERT(varchar(8),GETDATE(),112) AS date);
DECLARE @Bas   date = DATEADD(DAY,-365,@Bugun);

SELECT N'YAZARKASA' AS Kanal, seg.Segment,
    COUNT(*)                                          AS [Müşteri],
    CAST(SUM(c.Monetary) AS decimal(18,0))            AS [Toplam Ciro ₺],
    CAST(AVG(c.Monetary) AS decimal(18,0))            AS [Ort. Müşteri ₺],
    CAST(AVG(c.Frequency*1.0) AS decimal(10,1))       AS [Ort. Fiş]
FROM (
    SELECT s.CustomersId,
        DATEDIFF(DAY, MAX(s.Date), @Bugun) AS RecencyGun,
        COUNT(*) AS Frequency, SUM(s.GrossTotal - s.DiscountTotal) AS Monetary
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    WHERE s.DocumentsTypeId = 1 AND s.CustomersId > 0
      AND s.Date >= @Bas AND s.Date < DATEADD(DAY,1,@Bugun)
    GROUP BY s.CustomersId
) c
CROSS APPLY (SELECT CASE
    WHEN c.Frequency >= 8 AND c.RecencyGun <= 30  THEN N'1-Şampiyon'
    WHEN c.Frequency >= 4 AND c.RecencyGun <= 90  THEN N'2-Sadık'
    WHEN c.Frequency <= 2 AND c.RecencyGun <= 30  THEN N'3-Yeni/Gelişen'
    WHEN c.RecencyGun BETWEEN 91 AND 180          THEN N'4-Risk Altında'
    WHEN c.RecencyGun > 180                       THEN N'5-Kayıp (180+ gün)'
    ELSE N'6-Diğer' END AS Segment) seg
GROUP BY seg.Segment;
