/* ============================================================================
   BORDRO / NET ÜCRET MALİYET ÖZETİ
   ----------------------------------------------------------------------------
   Sunucu : zirve  |  View: dbo.vw_PersonelDepartman
   Tarih  : 03.06.2026  |  Yerel tarih = DMY (CONVERT 104)

   !!! UYARI: Ucret alanı NET'tir. Bu rapor NET ücret toplamını verir.
       İşveren toplam maliyeti (brüt + SGK işveren payı + işsizlik) DAHA
       YÜKSEKTİR. Brüt'e yaklaştırmak için @NetBrutKatsayi ve işveren
       maliyetine yaklaştırmak için @IsverenMaliyetKatsayi parametreleri
       kullanılır — ikisi de YMM/bordro ile teyit edilmeli. PrimTutari
       çoğunlukla boş olduğundan prim/giydirme dahil DEĞİLDİR.

   Aykırı değerler (Ucret <10K veya >150K) ayrı sütunda işaretlenir, ana
   toplama dahil edilmez ki firma/lokasyon maliyeti şişmesin.
   ============================================================================ */

DECLARE @NetBrutKatsayi        DECIMAL(5,3) = 1.400;  -- net→brüt (teyit et)
DECLARE @IsverenMaliyetKatsayi DECIMAL(5,3) = 1.225;  -- brüt→işveren maliyeti ~%22.5 (teyit et)
DECLARE @AltSinir DECIMAL(18,2) = 10000.00;
DECLARE @UstSinir DECIMAL(18,2) = 150000.00;

;WITH Veri AS (
    SELECT
        d.Firma, d.Lokasyon, d.AltLokasyon, d.Departman,
        CAST(d.Ucret AS DECIMAL(18,2)) AS NetUcret,
        CASE WHEN d.Ucret BETWEEN @AltSinir AND @UstSinir THEN 1 ELSE 0 END AS Normal
    FROM dbo.vw_PersonelDepartman d
    WHERE d.Ict IS NULL
)
SELECT
    Firma,
    Lokasyon,
    COUNT(*)                                                              AS Personel,
    SUM(CASE WHEN Normal=0 THEN 1 ELSE 0 END)                            AS AykiriHaric,
    CAST(SUM(CASE WHEN Normal=1 THEN NetUcret END) AS DECIMAL(18,2))     AS Aylik_Net_TL,
    CAST(SUM(CASE WHEN Normal=1 THEN NetUcret END) * @NetBrutKatsayi
         AS DECIMAL(18,2))                                                AS Aylik_Brut_TAHMIN_TL,
    CAST(SUM(CASE WHEN Normal=1 THEN NetUcret END)
         * @NetBrutKatsayi * @IsverenMaliyetKatsayi
         AS DECIMAL(18,2))                                                AS Aylik_IsverenMaliyet_TAHMIN_TL
FROM Veri
GROUP BY Firma, Lokasyon
ORDER BY Aylik_Net_TL DESC;
