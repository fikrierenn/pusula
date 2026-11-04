/* ork:hedef-db EncoreMerkez
   ork:compat 110
   Soru     : T-074 sema kayıtlarına giren iki ölçümün kanıtı (spec 001; sql-inceleyici/gorev-inceleyici
              "arşivde kanıt yok" bulgusu, 04.10.2026).
              (A) SalesProductCampaigns: DistributedAmount ile TotalDiscount eşitliği aynı / ters işaret dağılımı.
              (B) Products.Code → urn.stkID: canlı ürün eşleşmesi ve BIN2 dönüşüm kuralına uymayan kod.
   Dönem    : A — Sales.[Date] Eylül 2026 (01.09.2026 dahil, 01.10.2026 hariç). B — tüm zaman, canlı ürün.
   SSMS     : bloklar ayrı koşulur (GO). sqlcli --read-only DECLARE kabul etmez; literal tarihle koşuldu.
   Sonuç    : koşu 04.10.2026 (sqlcli --profile encore --read-only, literal tarihle)
              A: spc_satir 547.423 · ayni_isaret_esit 228.297 · ters_isaret_esit 0 · esit_degil 319.126
              B: canli_urun 819.730 · eslesen 818.389 (%99,84) · oksuz 1.341 · kurala_uymayan 0
*/

-- blok: A
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
SELECT
    COUNT(*) AS spc_satir,
    SUM(CASE WHEN spc.DistributedAmount = spc.TotalDiscount THEN 1 ELSE 0 END) AS ayni_isaret_esit,
    SUM(CASE WHEN spc.DistributedAmount = -spc.TotalDiscount AND spc.TotalDiscount <> 0 THEN 1 ELSE 0 END) AS ters_isaret_esit,
    SUM(CASE
        WHEN
            spc.DistributedAmount <> spc.TotalDiscount
            AND NOT (spc.DistributedAmount = -spc.TotalDiscount AND spc.TotalDiscount <> 0) THEN 1
        ELSE 0
    END) AS esit_degil
FROM EncoreMerkez.dbo.SalesProductCampaigns AS spc
    INNER JOIN EncoreMerkez.dbo.Sales AS s ON spc.SalesId = s.Id
WHERE s.[Date] >= @Bas AND s.[Date] < @Bit;
GO

-- blok: B
SELECT
    COUNT(*) AS canli_urun,
    SUM(CASE WHEN u.stkID IS NOT NULL THEN 1 ELSE 0 END) AS eslesen,
    SUM(CASE WHEN u.stkID IS NULL THEN 1 ELSE 0 END) AS oksuz,
    SUM(CASE
        WHEN
            NOT (p.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(p.Code) BETWEEN 1 AND 9)
            OR p.Code IS NULL THEN 1
        ELSE 0
    END) AS kurala_uymayan
/* tsqllint-disable non-sargable */  -- tam tablo sayımı; dönüşüm kuralının kendisi ölçülüyor
FROM EncoreMerkez.dbo.Products AS p
    LEFT JOIN DerinSISBkm.dbo.urn AS u
        ON u.stkID = CASE
            WHEN
                p.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%'
                AND LEN(p.Code) BETWEEN 1 AND 9 THEN CONVERT(INT, p.Code)
        END
WHERE NOT (p.IsDeleted = 1 AND p.IsActive = 0);
/* tsqllint-enable non-sargable */
GO
