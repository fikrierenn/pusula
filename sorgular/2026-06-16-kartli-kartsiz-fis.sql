/* ============================================================
   2026-06-16 — Sadakat kartı etkisi: Kartlı vs Kartsız FİŞ (B-102)
   Soru: kartsız fiş neden bu kadar az görünüyor? (panel 5.627 kartsız gösteriyordu)
   Bulgu: eski sorgu CustomersId>0 şartı + belge(1,2,3,6,7,8) → Sınav(8) ciroyu "Kartsız"a katıyor (266M)
          + anonim (CustomersId=0 yürü-gel) fişleri atıyor. DOĞRU: perakende(1,3), anonim DAHİL, sepet/fiş.
   Sonuç: Kartlı 474.615 fiş / 320,2M ₺ / sepet 675₺ · Kartsız 529.428 fiş / 285,6M ₺ / sepet 539₺.
   DB: EncoreMerkez + DerinCrm.Customer (kart no)
   İlgili: kural sql-server-conventions.md § MÜŞTERİ RAPORLARI FİŞ BAZLI; SadakatQueries.GetKartliAsync
   ============================================================ */

-- Perakende fiş (1) + iade (3), son 12 ay, iç-kart hariç (isim Mağaza/Kumbara + tel 599/699).
-- Kartlı = CustomersId>0 AND CardNumber dolu. Kartsız = geri kalan TÜM fiş (anonim CustomersId=0 dahil).
SELECT
    CASE WHEN s.CustomersId > 0 AND ISNULL(c.CardNumber,'') <> '' THEN 'Kartlı' ELSE 'Kartsız' END AS Tip,
    COUNT(*) AS Fis,
    COUNT(DISTINCT CASE WHEN s.CustomersId > 0 THEN s.CustomersId END) AS TanimliMusteri,
    SUM(CASE WHEN s.DocumentsTypeId = 3
        THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
        ELSE   s.GrossTotal - s.DiscountTotal - s.VatTotal END) AS NetCiro,
    CAST(SUM(CASE WHEN s.DocumentsTypeId = 3
        THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
        ELSE   s.GrossTotal - s.DiscountTotal - s.VatTotal END)
        / NULLIF(COUNT(*),0) AS decimal(12,0)) AS SepetFisBasi
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
LEFT JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id = s.CustomersId
WHERE s.DocumentsTypeId IN (1,3)
  AND s.Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date))
  AND (s.CustomersId = 0 OR s.CustomersId NOT IN (
        SELECT Id FROM DerinCrm.dbo.Customer WITH(NOLOCK)
        WHERE Name LIKE '%Mağaza%' OR Name LIKE '%Kumbara%'
           OR ISNULL(PhoneNumber,'') LIKE '599%' OR ISNULL(PhoneNumber,'') LIKE '699%'))
GROUP BY CASE WHEN s.CustomersId > 0 AND ISNULL(c.CardNumber,'') <> '' THEN 'Kartlı' ELSE 'Kartsız' END;
-- Sepet kartlı(675) > kartsız(539) → sadakat kartı sahibi daha çok harcıyor.
