/* =====================================================================
   2026-08-19 · Sınav siparişi ÖDENDİ/ÖDENMEDİ takibi + ping-pong senaryosu
   DB : master bağlamı (3-parçalı) · Kapsam DonemId 7-8 (Encore dönemi)

   SENARYO (kullanıcı tarifi, canlı doğrulandı):
     satış fişi -> Odendi=1 · iade -> Odendi=0 · yeni fiş -> Odendi=1 · iade -> 0 ...
   Aynı SiparisKod üzerinde satış/iade dizisi tekrarlanabiliyor.

   *** TEMEL SORUN ***
   snv.Siparis.Odendi bit = YALNIZ ANLIK DURUM, TARİHÇE TUTMAZ.
   GuncellemeTarih tek alan, üzerine yazılıyor — 5 hareketli siparişte NULL
   bile olabiliyor (3812025229833). Yani "ne zaman ödendi/ödenmedi oldu"
   sorusu Odendi/GuncellemeTarih'ten CEVAPLANAMAZ.
   ÇÖZÜM: durumu OLAY DEFTERİNDEN TÜRET (blok 1-2). Flag yalnız kontrol amaçlı.

   *** GRUPLAMA ANAHTARI = SiparisKod ***
   Yeniden kesilen satış fişinin LinkedDocumentId'si 0 (öncekiyle bağlı DEĞİL).
   Zincir yalnız iade -> orijinal satış yönünde kurulu. Bu yüzden bir siparişin
   tüm hareketleri ancak SiparisKod ile bir araya gelir.

   *** FE.InvoiceTotal TOPLAMAYIN ***
   İade satırında da POZİTİF yazılı. 3812025229833'te 5 FE kaydı x 50.348 =
   251.740 çıkar; gerçek net 50.348. Tutar daima Sales'ten, iade sign'lı.

   CANLI ÖLÇÜM (DonemId 7-8, 9.006 sipariş):
     iade yok        -> 8.837 sipariş
     1 iade          ->   167 sipariş
     2 iade          ->     2 sipariş
   ÇELİŞKİ (flag vs türetilmiş): 24 sipariş
     · FIŞ YOK ama Odendi=1                     -> 15 sipariş (yanlış "ödendi")
     · Net POZİTİF ama Odendi=0                 ->  8 sipariş / 305.874,18 ₺ (yanlış "ödenmedi")
     · Net SIFIR (tam iade) ama Odendi=1        ->  1 sipariş (yanlış "ödendi")

   *** İADE ≠ EKONOMİK İADE (ciro etkisi) ***
   Ping-pong'un çoğu aynı gün / aynı Z / dakikalar içinde = KASA DÜZELTMESİ.
   Örn. 3812025229833 (Z 30, 02.09.2025):
     14:10 SATIŞ 121854  +50.348
     14:11 İADE  121861  -50.348  (link 121854)
     14:14 SATIŞ 121883  +50.348
     14:16 İADE  121895  -50.348  (link 121883)
     14:19 SATIŞ 121916  +50.348
     => net 50.348 · brüt satış 151.044 · 3 satış fişi
   Rapor "brüt satış" ve "fiş sayısı" verirse ŞİŞER. Sınav tip-8 fiş sayısı
   9.154 iken gerçek sipariş 9.006. Ciro daima NET (iade sign'lı) okunmalı,
   fiş sayısı DISTINCT SiparisKod ile verilmeli.
   ===================================================================== */

DECLARE @Donem1 int = 7, @Donem2 int = 8;

-- ---------------------------------------------------------------------
-- 1) OLAY DEFTERİ — SiparisKod bazında sıralı hareketler + yürüyen bakiye
--    Ping-pong'u gözle görmek ve "hangi anda ödendi/ödenmedi" demek için.
-- ---------------------------------------------------------------------
WITH Olay AS (
    SELECT FE.SiparisKod, sip.SiparisId, sip.DonemId,
           CONVERT(int, ISNULL(sip.Odendi,0)) AS OdendiFlag,
           sip.GuncellemeTarih,
           S.Id AS FisId, S.Date AS Tarih, S.DocumentsTypeId,
           DT.Name AS BelgeTip, S.DocumentNo, S.ReceiptNo AS FisNo,
           S.ClosureNo AS Zno, PS.SerialNumber AS Kasa, S.LinkedDocumentId,
           CASE WHEN S.DocumentsTypeId = 3
                THEN -(S.GrossTotal - S.DiscountTotal)
                ELSE  (S.GrossTotal - S.DiscountTotal) END AS HareketKdvDahil,
           CASE WHEN S.DocumentsTypeId = 3
                THEN -(S.GrossTotal - S.DiscountTotal - S.VatTotal)
                ELSE  (S.GrossTotal - S.DiscountTotal - S.VatTotal) END AS HareketKdvHaric
    FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
         JOIN EncoreMerkez.dbo.Sales S      WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
         JOIN EncoreMerkez.dbo.Documents DT WITH(NOLOCK) ON DT.Id = S.DocumentsTypeId
         LEFT JOIN EncoreMerkez.dbo.Pos PS  WITH(NOLOCK) ON PS.Id = S.PosId
         LEFT JOIN BKM.snv.Siparis sip      WITH(NOLOCK) ON sip.SiparisKod = FE.SiparisKod
    WHERE sip.DonemId IN (@Donem1, @Donem2)
)
SELECT SiparisKod, SiparisId, DonemId, OdendiFlag, GuncellemeTarih,
       ROW_NUMBER() OVER (PARTITION BY SiparisKod ORDER BY Tarih, FisId) AS Sira,
       Tarih, BelgeTip, FisId, DocumentNo, FisNo, Zno, Kasa, LinkedDocumentId,
       CAST(HareketKdvDahil AS decimal(18,2)) AS HareketKdvDahil,
       CAST(SUM(HareketKdvDahil) OVER (PARTITION BY SiparisKod
             ORDER BY Tarih, FisId ROWS UNBOUNDED PRECEDING) AS decimal(18,2)) AS YuruyenBakiye,
       CASE WHEN SUM(HareketKdvDahil) OVER (PARTITION BY SiparisKod
                     ORDER BY Tarih, FisId ROWS UNBOUNDED PRECEDING) > 0.02
            THEN 'ODENDI' ELSE 'ODENMEDI' END AS OHandekiDurum
FROM Olay
ORDER BY SiparisKod, Tarih, FisId;

-- ---------------------------------------------------------------------
-- 2) SİPARİŞ DURUM ÖZETİ — türetilmiş ödendi/ödenmedi (KANONİK)
--    Bu blok "ödendi mi" sorusunun tek doğru kaynağı.
-- ---------------------------------------------------------------------
SELECT sip.SiparisKod, sip.SiparisId, sip.DonemId, sip.Tarih AS SiparisTarih,
       CONVERT(int, ISNULL(sip.Odendi,0))                AS OdendiFlag,
       ISNULL(X.SatisFis,0)                              AS SatisFis,
       ISNULL(X.IadeFis,0)                               AS IadeFis,
       X.IlkHareket, X.SonHareket,
       CASE WHEN X.SonTip = 3 THEN 'IADE' WHEN X.SonTip IS NULL THEN NULL ELSE 'SATIS' END AS SonHareketTipi,
       CAST(ISNULL(X.NetKdvDahil,0) AS decimal(18,2))     AS NetKdvDahil,
       CAST(ISNULL(X.NetKdvHaric,0) AS decimal(18,2))     AS NetKdvHaric,
       CAST(ISNULL(X.BrutSatis,0)   AS decimal(18,2))     AS BrutSatis,   -- şişik değer, kıyas için
       -- TÜRETİLMİŞ DURUM
       CASE WHEN X.SatisFis IS NULL           THEN 'ODENMEDI_FIS_YOK'
            WHEN X.NetKdvDahil >  0.02        THEN 'ODENDI'
            WHEN X.NetKdvDahil < -0.02        THEN 'FAZLA_IADE'          -- veri hatası
            ELSE                                   'ODENMEDI_TAM_IADE' END AS TuretilmisDurum,
       CASE WHEN X.IadeFis >= 2 THEN 'PING_PONG' WHEN X.IadeFis = 1 THEN 'TEK_IADE' ELSE '' END AS Desen
FROM BKM.snv.Siparis sip WITH(NOLOCK)
     OUTER APPLY (
        SELECT SUM(CASE WHEN S.DocumentsTypeId = 3 THEN 1 ELSE 0 END)                  AS IadeFis,
               SUM(CASE WHEN S.DocumentsTypeId <> 3 THEN 1 ELSE 0 END)                 AS SatisFis,
               SUM(CASE WHEN S.DocumentsTypeId <> 3 THEN S.GrossTotal-S.DiscountTotal ELSE 0 END) AS BrutSatis,
               SUM(CASE WHEN S.DocumentsTypeId = 3
                        THEN -(S.GrossTotal-S.DiscountTotal)
                        ELSE  (S.GrossTotal-S.DiscountTotal) END)                      AS NetKdvDahil,
               SUM(CASE WHEN S.DocumentsTypeId = 3
                        THEN -(S.GrossTotal-S.DiscountTotal-S.VatTotal)
                        ELSE  (S.GrossTotal-S.DiscountTotal-S.VatTotal) END)           AS NetKdvHaric,
               MIN(S.Date) AS IlkHareket, MAX(S.Date) AS SonHareket,
               MAX(CASE WHEN S.Date = Son.SonTarih THEN S.DocumentsTypeId END)          AS SonTip
        FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
             JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
             CROSS APPLY (SELECT MAX(S9.Date) AS SonTarih
                          FROM BKM.snv.SinavSiparisFisEncore FE9 WITH(NOLOCK)
                               JOIN EncoreMerkez.dbo.Sales S9 WITH(NOLOCK) ON S9.DocumentNo = FE9.InvoiceNo
                          WHERE FE9.SiparisKod = sip.SiparisKod) Son
        WHERE FE.SiparisKod = sip.SiparisKod) X
WHERE sip.DonemId IN (@Donem1, @Donem2)
ORDER BY sip.SiparisKod;

-- ---------------------------------------------------------------------
-- 3) ÇELİŞKİ LİSTESİ — flag ile türetilmiş durum uyuşmuyor (24 sipariş)
--    Operasyona düzeltme listesi olarak verilir.
-- ---------------------------------------------------------------------
SELECT T.* FROM (
    SELECT sip.SiparisKod, sip.SiparisId, sip.DonemId,
           CONVERT(int, ISNULL(sip.Odendi,0)) AS OdendiFlag, sip.GuncellemeTarih,
           X.SatisFis, X.IadeFis, X.SonHareket,
           CAST(X.NetKdvDahil AS decimal(18,2)) AS NetKdvDahil,
           CASE WHEN X.SatisFis IS NULL    THEN 'ODENMEDI_FIS_YOK'
                WHEN X.NetKdvDahil > 0.02  THEN 'ODENDI'
                ELSE                            'ODENMEDI_TAM_IADE' END AS TuretilmisDurum
    FROM BKM.snv.Siparis sip WITH(NOLOCK)
         OUTER APPLY (SELECT SUM(CASE WHEN S.DocumentsTypeId=3 THEN 1 ELSE 0 END) AS IadeFis,
                             SUM(CASE WHEN S.DocumentsTypeId<>3 THEN 1 ELSE 0 END) AS SatisFis,
                             SUM(CASE WHEN S.DocumentsTypeId=3 THEN -(S.GrossTotal-S.DiscountTotal)
                                      ELSE (S.GrossTotal-S.DiscountTotal) END) AS NetKdvDahil,
                             MAX(S.Date) AS SonHareket
                      FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
                           JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
                      WHERE FE.SiparisKod = sip.SiparisKod) X
    WHERE sip.DonemId IN (@Donem1, @Donem2)
) T
WHERE (T.SatisFis IS NULL AND T.OdendiFlag = 1)                                  -- fiş yok ama ödendi
   OR (T.NetKdvDahil >  0.02 AND T.OdendiFlag = 0)                               -- net pozitif ama ödenmedi
   OR (T.SatisFis IS NOT NULL AND T.NetKdvDahil <= 0.02 AND T.OdendiFlag = 1)    -- tam iade ama ödendi
ORDER BY T.TuretilmisDurum, T.NetKdvDahil DESC;

-- ---------------------------------------------------------------------
-- 4) PING-PONG DESENİ — iade sayısı >= 1 olan siparişlerin profili
--    "Kasa düzeltmesi" mi "gerçek iade" mi ayrımı: aynı gün + aynı Z + kısa süre
-- ---------------------------------------------------------------------
SELECT T.SiparisKod, T.SiparisId, T.IadeFis, T.SatisFis,
       T.IlkHareket, T.SonHareket,
       DATEDIFF(minute, T.IlkHareket, T.SonHareket) AS SureDk,
       T.TekilZno, T.TekilGun,
       CASE WHEN T.TekilGun = 1 AND T.TekilZno = 1 AND DATEDIFF(minute,T.IlkHareket,T.SonHareket) <= 60
            THEN 'KASA_DUZELTMESI' ELSE 'GERCEK_IADE_SUPHESI' END AS Yorum,
       CAST(T.BrutSatis   AS decimal(18,2)) AS BrutSatis,
       CAST(T.NetKdvDahil AS decimal(18,2)) AS NetKdvDahil,
       CAST(T.BrutSatis - T.NetKdvDahil AS decimal(18,2)) AS SisenTutar
FROM (
    SELECT FE.SiparisKod, MAX(sip.SiparisId) AS SiparisId,
           SUM(CASE WHEN S.DocumentsTypeId=3 THEN 1 ELSE 0 END)  AS IadeFis,
           SUM(CASE WHEN S.DocumentsTypeId<>3 THEN 1 ELSE 0 END) AS SatisFis,
           MIN(S.Date) AS IlkHareket, MAX(S.Date) AS SonHareket,
           COUNT(DISTINCT S.ClosureNo)        AS TekilZno,
           COUNT(DISTINCT CAST(S.Date AS date)) AS TekilGun,
           SUM(CASE WHEN S.DocumentsTypeId<>3 THEN S.GrossTotal-S.DiscountTotal ELSE 0 END) AS BrutSatis,
           SUM(CASE WHEN S.DocumentsTypeId=3 THEN -(S.GrossTotal-S.DiscountTotal)
                    ELSE (S.GrossTotal-S.DiscountTotal) END) AS NetKdvDahil
    FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
         JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
         LEFT JOIN BKM.snv.Siparis sip WITH(NOLOCK) ON sip.SiparisKod = FE.SiparisKod
    WHERE sip.DonemId IN (@Donem1, @Donem2)
    GROUP BY FE.SiparisKod
    HAVING SUM(CASE WHEN S.DocumentsTypeId=3 THEN 1 ELSE 0 END) >= 1
) T
ORDER BY T.IadeFis DESC, T.SisenTutar DESC;

-- ---------------------------------------------------------------------
-- 5) ÖNERİ — kalıcı çözüm: durum değişim defteri
--    snv.Siparis.Odendi bit'i KORUNUR (uygulama okuyor) ama tarihçe için
--    ayrı app-owned tablo gerekir. ERP-yazma politikası: yeni bkm.* tablosu
--    yalnız kullanıcı onayıyla (bkz. .claude/rules/erp-write-policy.md).
--
--    CREATE TABLE bkm.SinavOdemeDurumLog (
--        Id            int identity primary key,
--        SiparisId     int          not null,
--        SiparisKod    varchar(40)  not null,
--        FisId         bigint       null,      -- EncoreMerkez.Sales.Id
--        Yon           varchar(6)   not null,  -- SATIS / IADE
--        Tutar         decimal(18,2) not null, -- iade negatif
--        YeniDurum     bit          not null,  -- hareket sonrası ödendi/ödenmedi
--        HareketTarih  datetime     not null,
--        KayitTarih    datetime     not null default(getdate())
--    );
--    Doldurma: blok 1 çıktısı geriye dönük yazılır, sonrası trigger/job ile.
--    Böylece "3 kez ödendi 2 kez iade" zinciri raporlanabilir hale gelir.
-- ---------------------------------------------------------------------
