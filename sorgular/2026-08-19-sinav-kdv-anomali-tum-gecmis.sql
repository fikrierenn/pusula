/* =====================================================================
   2026-08-19 · TÜM GEÇMİŞ Sınav fişlerinde KDV anomali taraması
   Kapsam: BKM.snv.SinavSiparisFisEncore → Sales/SalesProducts (IsValid=1)
           29.07.2025 – 18.08.2026 · 9.319 fiş · 240.176 satır
           Ciro (KDV dahil) 430.928.644,93 ₺ · KDV 3.961.095,24 ₺
   DB    : master bağlamı (3-parçalı isim)

   6 TEST — SONUÇ
   T1 KDV aritmetiği (VatTotal = TotalPrice*p/(100+p))     → 0 / 240.176 SAPMA (TEMİZ)
   T2 Oran>0 ama VatTotal=0                                → 192 satır, TOPLAM 1,33 ₺ (yuvarlama, önemsiz)
   T3 Oran=0 ama VatTotal<>0                               → 0 (TEMİZ)
   T4 Header ↔ satır mutabakatı (KDV + net)                → 0 / 9.319 SAPMA (TEMİZ)
   T5 Geçersiz KDV oranı                                   → YOK (sadece 0/1/10/20)
   T6 POS oranı ↔ ERP urn.KDVs oranı UYUMSUZ               → **92 satır / 36 ürün / 38.937,02 ₺
                                                              → EKSİK kesilen KDV 4.015,75 ₺** (BULGU)
   T7 Aynı ürün AYNI GÜN farklı oran                       → 0 (TEMİZ)
   T8 Aynı ürün zaman içinde oran değişimi                 → 2 ürün (%0↔%10, POS'ta sonradan düzeltilmiş)

   T6 YOĞUNLAŞMASI: 87/92 satır Ağu–Eyl 2025 (okul sezonu açılışı).
   Profil: yeni açılan Disney/çanta/matara/oyuncak kartları POS'a KDV'siz
   girilmiş, ERP'de doğru oran (%10/%20) tanımlı. Kart sonradan düzeltilmiş
   (2026'da yalnız 4 satır kaldı) → sistematik hata değil, ürün-kartı açılış
   hatası. Yine de mali müşavire bildirilmeli (KDV eksik beyan).

   KDV kod ↔ oran tablosu: DerinSISBkm.dbo.kdvYuzde_vw
   (ilkKDVID 1→%0 · 2→%1 · 3→%8 · 4→%18 · 6→%10 · 7→%20)
   ⚠ urn.KDVs bir KODdur, yüzde DEĞİL — SP.VatPercent ile doğrudan
   karşılaştırmak TÜM satırları uyumsuz gösterir.
   ===================================================================== */

-- ---------------------------------------------------------------------
-- T1-T3 · Satır içi KDV aritmetiği + sıfır tutarsızlıkları
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS TumSatir,
       SUM(CASE WHEN ABS(SP.VatTotal - ROUND(CONVERT(decimal(19,6),SP.TotalPrice)*SP.VatPercent/(100.0+SP.VatPercent),2)) > 0.02
                THEN 1 ELSE 0 END) AS T1_AritmetikSapan,
       SUM(CASE WHEN SP.VatPercent > 0 AND SP.VatTotal = 0  THEN 1 ELSE 0 END) AS T2_OranVarKdvSifir,
       SUM(CASE WHEN SP.VatPercent = 0 AND SP.VatTotal <> 0 THEN 1 ELSE 0 END) AS T3_OranSifirKdvVar,
       CAST(SUM(CASE WHEN SP.VatPercent > 0 AND SP.VatTotal = 0 THEN SP.TotalPrice ELSE 0 END) AS decimal(18,2)) AS T2_Tutar
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1;

-- ---------------------------------------------------------------------
-- T4 · Fiş header ↔ satır mutabakatı
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS Fis,
       SUM(CASE WHEN ABS(S.VatTotal - X.SatirKdv) > 0.02 THEN 1 ELSE 0 END) AS KdvSapan,
       SUM(CASE WHEN ABS((S.GrossTotal - S.DiscountTotal) - X.SatirTP) > 0.02 THEN 1 ELSE 0 END) AS NetSapan,
       CAST(SUM(ABS(S.VatTotal - X.SatirKdv)) AS decimal(18,2)) AS ToplamKdvFark
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     CROSS APPLY (SELECT ISNULL(SUM(SP.VatTotal),0) AS SatirKdv, ISNULL(SUM(SP.TotalPrice),0) AS SatirTP
                  FROM EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK)
                  WHERE SP.SalesId = S.Id AND SP.IsValid = 1) X;

-- ---------------------------------------------------------------------
-- T6 · ANA BULGU — POS oranı ↔ ERP oranı uyumsuz (ürün listesi)
-- ---------------------------------------------------------------------
SELECT PR.Code AS StkID, PR.Name AS Urun, k2.ktgrAd AS Kategori,
       SP.VatPercent AS PosOran, kv.kdvYuzdesi AS ErpOran,
       COUNT(*) AS Satir,
       CAST(SUM(SP.TotalPrice) AS decimal(18,2)) AS TutarKdvDahil,
       CAST(SUM(SP.VatTotal)   AS decimal(18,2)) AS KesilenKdv,
       CAST(SUM(ROUND(CONVERT(decimal(19,6),SP.TotalPrice)*kv.kdvYuzdesi/(100.0+kv.kdvYuzdesi),2))
            - SUM(SP.VatTotal) AS decimal(18,2)) AS EksikKdv,
       MIN(CAST(S.Date AS date)) AS IlkSatis, MAX(CAST(S.Date AS date)) AS SonSatis
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
     JOIN DerinSISBkm.dbo.urn U             WITH(NOLOCK) ON U.stkID = PR.Code
     LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2  WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
     JOIN DerinSISBkm.dbo.kdvYuzde_vw kv    WITH(NOLOCK) ON kv.ilkKDVID = U.KDVs
WHERE SP.VatPercent <> kv.kdvYuzdesi
GROUP BY PR.Code, PR.Name, k2.ktgrAd, SP.VatPercent, kv.kdvYuzdesi
ORDER BY EksikKdv DESC;

-- ---------------------------------------------------------------------
-- T6b · Aylık dağılım (yoğunlaşma testi)
-- ---------------------------------------------------------------------
SELECT YEAR(S.Date) AS Yil, MONTH(S.Date) AS Ay, COUNT(*) AS SapanSatir,
       CAST(SUM(SP.TotalPrice) AS decimal(18,2)) AS TutarKdvDahil,
       CAST(SUM(ROUND(CONVERT(decimal(19,6),SP.TotalPrice)*kv.kdvYuzdesi/(100.0+kv.kdvYuzdesi),2))
            - SUM(SP.VatTotal) AS decimal(18,2)) AS EksikKdv
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
     JOIN DerinSISBkm.dbo.urn U             WITH(NOLOCK) ON U.stkID = PR.Code
     JOIN DerinSISBkm.dbo.kdvYuzde_vw kv    WITH(NOLOCK) ON kv.ilkKDVID = U.KDVs
WHERE SP.VatPercent <> kv.kdvYuzdesi
GROUP BY YEAR(S.Date), MONTH(S.Date)
ORDER BY Yil, Ay;

-- ---------------------------------------------------------------------
-- T7-T8 · Aynı ürün farklı oran (gün içi / zaman içi)
-- ---------------------------------------------------------------------
SELECT PR.Code, PR.Name, COUNT(DISTINCT SP.VatPercent) AS FarkliOran,
       MIN(SP.VatPercent) AS MinOran, MAX(SP.VatPercent) AS MaxOran, COUNT(*) AS Satir,
       MIN(CAST(S.Date AS date)) AS IlkGun, MAX(CAST(S.Date AS date)) AS SonGun
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
GROUP BY PR.Code, PR.Name
HAVING COUNT(DISTINCT SP.VatPercent) > 1
ORDER BY Satir DESC;
-- T7 (gün kırılımlı aynı sorgu, GROUP BY'a CAST(S.Date AS date) ekle) → 0 satır
