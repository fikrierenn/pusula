USE DerinSISBkm;
GO

-- =============================================================
-- bkm.UrunIskontoYuzdeElliKampanya_vw
-- Her ürün için %50 kampanyasında uygulanacak geri dönüş iskonto oranını döndürür.
-- Öncelik: Verilmeyen (0) > Barkod özel > Marka geneli > Yok (0)
-- =============================================================

CREATE OR ALTER VIEW bkm.UrunIskontoYuzdeElliKampanya_vw AS
SELECT
    u.stkID,
    u.BarkodAna,
    u.mrkID,
    u.mrkAd,
    CASE
        WHEN v.Anahtar IS NOT NULL THEN 0           -- Verilmeyen → iskonto YOK
        WHEN b.Oran     IS NOT NULL THEN b.Oran      -- Barkod özel
        WHEN m.Oran     IS NOT NULL THEN m.Oran      -- Marka geneli
        ELSE 0                                        -- Liste dışı
    END AS GeriDonusOran,
    CASE
        WHEN v.Anahtar IS NOT NULL THEN N'Verilmeyen'
        WHEN b.Oran     IS NOT NULL THEN N'BarkodOzel'
        WHEN m.Oran     IS NOT NULL THEN N'MarkaGenel'
        ELSE                              N'Yok'
    END AS IskontoKaynak
FROM bkm.urunbilgi u
LEFT JOIN bkm.IskontoTanimYuzdeElliKampanya v
       ON v.Tip = 'Verilmeyen'
      AND v.Anahtar = u.BarkodAna COLLATE Turkish_CI_AS
LEFT JOIN bkm.IskontoTanimYuzdeElliKampanya b
       ON b.Tip = 'Barkod'
      AND b.Anahtar = u.BarkodAna COLLATE Turkish_CI_AS
LEFT JOIN bkm.IskontoTanimYuzdeElliKampanya m
       ON m.Tip = 'Marka'
      AND m.Anahtar = CAST(u.mrkID AS NVARCHAR(20)) COLLATE Turkish_CI_AS;
GO

-- =============================================================
-- Doğrulama sorguları
-- =============================================================

-- 1) Dağılım: kaç ürün hangi kaynaktan iskonto alıyor
SELECT
    IskontoKaynak,
    COUNT(*) AS UrunSayisi,
    MIN(GeriDonusOran) AS MinOran,
    MAX(GeriDonusOran) AS MaxOran
FROM bkm.UrunIskontoYuzdeElliKampanya_vw
GROUP BY IskontoKaynak
ORDER BY UrunSayisi DESC;

-- 2) Büyüdüm Ben! kontrolü (stkID = 1712364)
SELECT * FROM bkm.UrunIskontoYuzdeElliKampanya_vw WHERE stkID = 1712364;

-- 3) Verilmeyen örnekleri (marka indirimde ama bu barkodlar dahil değil)
SELECT TOP 20 stkID, BarkodAna, mrkAd, GeriDonusOran, IskontoKaynak
FROM bkm.UrunIskontoYuzdeElliKampanya_vw
WHERE IskontoKaynak = N'Verilmeyen';
