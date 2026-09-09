/* ═══════════════════════════════════════════════════════════════════════════════
   KDV TABANI — marj hesabı için satış ve maliyet aynı tabanda mı?           09.09.2026
   DB: DerinSISBkm + EncoreMerkez

   SORU: Ürün drill'ine marj eklenecek. Satış fiyatı ve alış maliyeti aynı KDV
   tabanında mı, değilse hangisi dahil hangisi hariç?

   BULGU: İkisi FARKLI tabanda —
     · fatAyr.ehTutarN  KDV HARİÇ (KDV ayrı kolonda: ehTutarKDV)
     · urn.fiyatS       KDV DAHİL (KDV fiyatın İÇİNDEN çıkıyor, üstüne eklenmiyor)
   Düzeltilmeden hesaplanan marj, %20 KDV'li üründe ~17 puan şişik çıkıyordu.

   Sema: codes.yaml urn.KDVs · bridges.yaml urn-kdv-oran · metrics.yaml marj_kdv_tabani
   ═══════════════════════════════════════════════════════════════════════════════ */

-- ── 1) ALIŞ TARAFI: fatAyr KDV içeriyor mu? ───────────────────────────────────
-- Beklenti: ehTutarKDV ayrı kolonda duruyorsa ehTutarN KDV HARİÇ demektir.
SELECT TOP 5 fa.ehAdetN, fa.ehTutar, fa.ehIndirim, fa.ehTutarN,
       fa.ehKDV, fa.ehTutarKDV,
       CONVERT(decimal(6,2), fa.ehTutarKDV * 100.0 / NULLIF(fa.ehTutarN, 0)) AS ImaEdilenOran
FROM dbo.fatAyr fa WITH (NOLOCK)
JOIN dbo.fat f WITH (NOLOCK) ON f.eID = fa.ehID
WHERE fa.ehstkID = 1672852 AND f.eTip = 0 AND f.eDurum <> 2
ORDER BY f.eTarih DESC;
-- SONUÇ: ehTutarN 12.501,00 · ehTutarKDV 2.500,20 → ImaEdilenOran tam 20,00
--         → ehTutarN KDV HARİÇ. ehKDV=7 bir KOD (oran değil).

-- ── 2) KOD → ORAN sözlüğü ─────────────────────────────────────────────────────
SELECT * FROM dbo.kdvYuzde_vw ORDER BY kdvYuzdesi;
-- SONUÇ: 1→%0 · 2→%1 · 3→%8 · 6→%10 · 4→%18 · 7→%20  (6 kod)

-- ── 3) SATIŞ TARAFI: fiyatS KDV DAHİL mi? ─────────────────────────────────────
-- Ayrım testi: KDV fiyatın İÇİNDEN mi çıkıyor (iç yüzde) yoksa ÜSTÜNE mi ekleniyor?
--   iç yüzde  → VatTotal = TotalPrice × oran / (100 + oran)
--   üst yüzde → VatTotal = TotalPrice × oran / 100
-- Hangisi tutuyorsa taban odur. Tolerans satır adediyle ölçekli (kuruş yuvarlaması).
SELECT sp.VatPercent,
       COUNT(*) AS Satir,
       SUM(CASE WHEN ABS(sp.VatTotal - sp.TotalPrice * sp.VatPercent
                                       / (100.0 + sp.VatPercent)) <= 0.02 * sp.Amount + 0.02
                THEN 1 ELSE 0 END) AS IcYuzde_KDV_DAHIL,
       SUM(CASE WHEN ABS(sp.VatTotal - sp.TotalPrice * sp.VatPercent / 100.0)
                     <= 0.02 * sp.Amount + 0.02
                THEN 1 ELSE 0 END) AS UstYuzde_KDV_HARIC
FROM EncoreMerkez.dbo.SalesProducts sp WITH (NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH (NOLOCK) ON s.Id = sp.SalesId
WHERE sp.IsValid = 1 AND s.Date >= '20260901' AND s.DocumentsTypeId IN (1, 2)
GROUP BY sp.VatPercent
ORDER BY 2 DESC;
-- SONUÇ: %20 → 89.888/89.888 iç yüzde · %10 → 39.426/39.426 iç yüzde
--         (üst yüzde yalnız %0 ve %1'de tutuyor, orada ikisi zaten aynı)
--         → TotalPrice KDV DAHİL. Tek satır kontrolü: 199,00 fiyatta VatTotal 33,17
--           (199/1,2 = 165,83; 199−165,83 = 33,17). Üst yüzde olsaydı 39,80 olurdu.

-- ── 4) TotalPrice = urn.fiyatS mi? (zinciri kapatan halka) ────────────────────
SELECT TOP 8 sp.Amount, sp.TotalPrice, sp.VatTotal, sp.VatPercent, sp.DiscountTotalDirect,
       CONVERT(decimal(18,4), sp.TotalPrice / NULLIF(sp.Amount, 0)) AS BirimTotalPrice
FROM EncoreMerkez.dbo.SalesProducts sp WITH (NOLOCK)
JOIN EncoreMerkez.dbo.Products p WITH (NOLOCK) ON p.Id = sp.ProductsId
WHERE sp.IsValid = 1 AND ISNUMERIC(p.Code) = 1 AND CONVERT(int, p.Code) = 1672852
  AND sp.DiscountTotalDirect = 0
ORDER BY sp.Id DESC;
-- SONUÇ: BirimTotalPrice 199,0000 = urn.fiyatS 199,0000 → zincir kapandı.

-- ── 5) urn.KDVs haritası POS VatPercent ile tutuyor mu? (ÇAPRAZ DOĞRULAMA) ────
SELECT COUNT(*) AS Kesisen,
       SUM(CASE WHEN x.UrnOran = x.PosOran THEN 1 ELSE 0 END) AS Uyusan,
       SUM(CASE WHEN x.UrnOran <> x.PosOran THEN 1 ELSE 0 END) AS Sapan
FROM (
    SELECT CONVERT(int, p.Code) AS stkID,
           MAX(k.kdvYuzdesi) AS UrnOran,
           MAX(CONVERT(int, sp.VatPercent)) AS PosOran
    FROM EncoreMerkez.dbo.SalesProducts sp WITH (NOLOCK)
    JOIN EncoreMerkez.dbo.Sales s WITH (NOLOCK) ON s.Id = sp.SalesId
    JOIN EncoreMerkez.dbo.Products p WITH (NOLOCK) ON p.Id = sp.ProductsId
    JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = CONVERT(int, p.Code)
    JOIN DerinSISBkm.dbo.kdvYuzde_vw k ON k.ilkKDVID = u.KDVs
    WHERE sp.IsValid = 1 AND s.Date >= '20260901' AND ISNUMERIC(p.Code) = 1
    GROUP BY CONVERT(int, p.Code)
) x;
-- SONUÇ: 29.912 üründe 29.912 uyuşma, 0 sapma → köprü güvenilir (confidence 0.99).

-- ── 6) urn.KDVs kod kümesinin CANLI dağılımı (liste elle yazılmaz) ────────────
SELECT k.kdvYuzdesi AS Oran, COUNT(*) AS Urun
FROM dbo.urn u WITH (NOLOCK)
JOIN dbo.kdvYuzde_vw k ON k.ilkKDVID = u.KDVs
GROUP BY k.kdvYuzdesi
ORDER BY 2 DESC;
-- SONUÇ: %0 699.013 · %20 112.738 · %10 31.145 · %1 1.086 · %18 16 · %8 9
--   → Ağustos'taki sema kaydında %8 ve %18 YOKTU; kod kümesi 4 → 6 değere tamamlandı.

-- ── 7) UYGULAMA: iki yönlü marj (drill ekranındaki hesap) ─────────────────────
-- Maliyet = son 5 alış faturasının ağırlıklı birimi (kanonik MLYT, KDV hariç)
SELECT m.stkID, u.stkAd, u.fiyatS AS EtiketFiyat, k.kdvYuzdesi AS Oran,
       CONVERT(decimal(18,2), u.fiyatS / (1 + k.kdvYuzdesi / 100.0)) AS NetSatis,
       CONVERT(decimal(18,2), m.BirimMaliyet)                       AS BirimMaliyet,
       CONVERT(decimal(18,2), u.fiyatS / (1 + k.kdvYuzdesi / 100.0) - m.BirimMaliyet) AS BirimKar,
       CONVERT(decimal(6,1), (u.fiyatS / (1 + k.kdvYuzdesi / 100.0) - m.BirimMaliyet)
               * 100.0 / NULLIF(u.fiyatS / (1 + k.kdvYuzdesi / 100.0), 0)) AS BrutMarjYuzde,
       CONVERT(decimal(8,1), (u.fiyatS / (1 + k.kdvYuzdesi / 100.0) - m.BirimMaliyet)
               * 100.0 / NULLIF(m.BirimMaliyet, 0))                        AS MarkupYuzde
FROM (
    SELECT x.stkID, SUM(x.tutar) / NULLIF(SUM(x.adet), 0) AS BirimMaliyet
    FROM (
        SELECT fa.ehstkID AS stkID, f.eID,
               SUM(fa.ehAdetN) AS adet, SUM(fa.ehTutarN) AS tutar,
               ROW_NUMBER() OVER (PARTITION BY fa.ehstkID
                                  ORDER BY f.eTarih DESC, f.eID DESC) AS sira
        FROM dbo.fatAyr fa WITH (NOLOCK)
        JOIN dbo.fat f WITH (NOLOCK) ON f.eID = fa.ehID
        WHERE f.eTip = 0 AND f.eDurum <> 2 AND fa.ehstkID IN (1672852, 1723863)
        GROUP BY fa.ehstkID, f.eID, f.eTarih
    ) x
    WHERE x.sira <= 5
    GROUP BY x.stkID
) m
JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = m.stkID
JOIN dbo.kdvYuzde_vw k ON k.ilkKDVID = u.KDVs;
-- SONUÇ 1672852: etiket 199 · oran %20 · net 165,83 · maliyet 43,55 · kâr 122,29
--                 → brüt marj %73,7 · markup %280,8
--   Bağıntı denetimi: markup = marj/(1−marj) → 0,737/0,263 = 2,808 ✓
--
-- ⚠ SINIR: bu LİSTE marjıdır. Kampanya/3al2öde indirimi, iade, sezon-sonu fiyatı ve
--   sonradan gelen ciro primi İÇİNDE YOK — alıcıya hesap sorarken tek başına kullanılmaz.
