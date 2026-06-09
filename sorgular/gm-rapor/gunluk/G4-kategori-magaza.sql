-- =====================================================================
-- G4 — GÜNLÜK KATEGORİ MİX (mağaza kırılımlı) — merchandising drill
-- Amaç: Dün kategori dağılımı, mağaza bazlı. Hangi mağaza hangi kategoride zayıf?
-- Veritabanı: EncoreMerkez satış + DerinSIS kategori (KTGR3 = urnKtgr2.ktgrAd)
-- KATEGORİ KAYNAĞI (09.06 düzeltildi): Products.Code = urn.stkID köprüsü (stkKod≠barkod!).
--   SalesProducts.ProductsId → Products.Code (int) = urn.stkID → urnKtgr2.ktgrAd.
--   (Eski stkKod=BarcodeNo join YANLIŞTI — Oyuncak gibi kategorileri kaçırıyordu.)
-- Filtre: IsValid=1, geri dönüşüm (BarcodeNo='1001') + Sınav Okulları hayalet hariç.
-- NOT: SalesProducts.TotalPrice = satır net (kategori-eşleşen alt küme; G1 net ciroya eşit DEĞİL,
--      mix sinyali için kullanılır). Amount = adet.
-- DOĞRULAMA (07.06.2026): İst.Yolu Hazırlık Kit. 39,9k (FSM/Özlüce 78k'nın yarısı) →
--   İst.Yolu zayıflığı sınav-hazırlık + Oyuncak'ta; Çocuk Kitabı'nda güçlü (106k, en yüksek).
-- NOT: MCP-safe (CTE yok). Cross-db COLLATE Turkish_CI_AS gerekli.
-- =====================================================================
DECLARE @Gun date = CAST(DATEADD(DAY,-1,GETDATE()) AS date);
DECLARE @GunBitis date = DATEADD(DAY,1,@Gun);

SELECT
    CASE MG.mekanID WHEN 1 THEN N'FSM' WHEN 4477 THEN N'Özlüce' WHEN 4478 THEN N'İst.Yolu' END AS Magaza,
    CAST(ktg.ktgrAd AS nvarchar(40))               AS Kategori,
    CAST(SUM(sp.TotalPrice) AS decimal(18,0))      AS [Tutar ₺],
    CAST(SUM(sp.Amount)     AS decimal(18,0))      AS Adet
FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = sp.SalesId
JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
    ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id = sp.ProductsId
JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CONVERT(int, pr.Code)
JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID = u.urnKtgr2ID
WHERE sp.IsValid = 1 AND sp.BarcodeNo <> '1001' AND ISNUMERIC(pr.Code) = 1
  AND s.Date >= @Gun AND s.Date < @GunBitis
  AND ktg.ktgrAd <> N'Sınav Okulları'
GROUP BY MG.mekanID, CAST(ktg.ktgrAd AS nvarchar(40))
ORDER BY Magaza, [Tutar ₺] DESC;
