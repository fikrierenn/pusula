/* ============================================================
   2026-06-16 — Kumbara = indirim TİPİ keşfi (EncoreMerkez)
   Soru: "Kumbara" nedir? (müşteri kartı değil, indirim tipi)
   Bulgu: RefundReasons Id=17 "Okul Kumbara Projesi İndirimi" (Type=1 indirim).
          RefundReasons çift görevli: Type=0 iade sebebi (SalesProducts.RefundReasonId'de kullanılır),
          Type=1 manuel indirim tipi (HİÇBİR işlem kolonuna bağlanmıyor — sema/codes.yaml § RefundReasons.Type).
   DB: EncoreMerkez (192.168.40.201)
   İlgili: sema/codes.yaml (encore.RefundReasons.Type, encore.SalesProductCampaigns.Source)
   ============================================================ */

-- 1) İndirim/iade sebep listesi — Kumbara burada (Id=17, Type=1)
SELECT Id, Name, Type, IsDeleted, Created
FROM EncoreMerkez.dbo.RefundReasons
ORDER BY Type, Id;
-- Type=0: iade sebebi (Hasarlı Ürün, Müşteri Memnuniyetsizliği, Geri Dönüşüm...)
-- Type=1: MANUEL İNDİRİM TİPİ (Personel, BSE, Anlaşmalı Kurum, 3Al2Öde, Bkm Kart, Sınav Koleji, Okul Kumbara Projesi=17)

-- 2) SalesProducts.RefundReasonId kullanımı → SADECE Type=0 çıkar (Type=1 hiç bağlanmıyor)
SELECT sp.RefundReasonId, rr.Name, rr.Type, COUNT(*) AS SatirAdet
FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
JOIN EncoreMerkez.dbo.RefundReasons rr ON rr.Id = sp.RefundReasonId
WHERE sp.IsValid = 1 AND sp.RefundReasonId > 0
GROUP BY sp.RefundReasonId, rr.Name, rr.Type
ORDER BY SatirAdet DESC;
-- Type=1 (Kumbara dahil) BURADA YOK → manuel indirim sebebi işleme yazılmıyor.
-- PriceChangeReasonId hep 0; Sales.RefundReasonId hiç kullanılmamış (ayrı kontrol).

-- 3) İndirim KAYNAK kırılımı — SalesProductCampaigns.Source (kampanya/manuel/legacy/kupon)
--    2026 penceresi (1 Oca–16 Haz). Source: 0=kampanya, 1=manuel(adsız), 2=legacy, 3=kupon.
SELECT spc.Source,
       COUNT(*) AS Adet,
       SUM(spc.TotalDiscount) AS ToplamIndirim
FROM EncoreMerkez.dbo.SalesProductCampaigns spc WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = spc.SalesId
WHERE s.Date >= '20260101' AND s.Date < '20260616'
GROUP BY spc.Source;
-- 2026: 0(kampanya) −74,3M %83 · 1(manuel) −8,6M %10 · 2(legacy) −6,2M %7 · 3 yok.
-- NOT: Kumbara indirim tutarı tek tek AYRIŞTIRILAMAZ (manuel Source=1 adsız). Otomatik POS raporu var,
--      işlem-bağı tablosu kullanıcıda — bulununca sema güncellenecek (status: teyit bekliyor).
