/* ============================================================================
   KIDEM TAZMİNATI KARŞILIĞI — TAHMİN (dikkatli okunmalı)
   ----------------------------------------------------------------------------
   Sunucu : zirve  |  View: dbo.vw_PersonelDepartman
   Tarih  : 03.06.2026  |  Yerel tarih = DMY (CONVERT 104)

   !!! VERİ KALİTESİ UYARISI — RAKAM KESİN DEĞİL, TAHMİNDİR !!!
   1) vw_PersonelDepartman.Ucret alanı NET (267/268 kayıt). Kıdem tazminatı
      GİYDİRİLMİŞ BRÜT üzerinden hesaplanır. Bu sorgu net'i parametrik bir
      katsayı ile brüt'e yaklaştırır (@NetBrutKatsayi) — gerçek bordro brüt'ü
      değildir. Kesin karşılık için bordro/SGK brüt verisi gerekir.
   2) PrimTutari alanı çoğunlukla boş → giydirme (ikramiye/prim/yol/yemek)
      EKLENMEMİŞTİR; gerçek tazminat tabanı bundan YÜKSEK olur.
   3) 15 kayıtta Ucret < 10.000 (günlük/part-time şüphesi) ve 1 kayıtta
      > 150.000 (aykırı). Ana tahmin bunları HARİÇ tutar; ayrı listelenir.
   4) Kıdem tazminatı tavanı (@KidemTavani) elle güncellenmeli — 2026 dönem
      tavanını resmî kaynaktan (muhasebetr.com/kidem-tazminati-tavani) teyit et.

   Formül (kişi başı tahmin):
     KıdemYılı  = (bugün − işe giriş) / 365.25
     AylıkBrüt  ≈ NetÜcret × @NetBrutKatsayi
     TabanÜcret = MIN(AylıkBrüt, @KidemTavani)
     Tahmini Karşılık = KıdemYılı × TabanÜcret
   ============================================================================ */

DECLARE @NetBrutKatsayi DECIMAL(5,3) = 1.400;      -- net→brüt yaklaşık (YMM ile teyit et)
DECLARE @KidemTavani    DECIMAL(18,2) = 53000.00;  -- 2026 tavanı — GÜNCELLE/TEYİT ET
DECLARE @AltSinir       DECIMAL(18,2) = 10000.00;  -- bu altı aykırı (hariç)
DECLARE @UstSinir       DECIMAL(18,2) = 150000.00; -- bu üstü aykırı (hariç)

;WITH Aktif AS (
    SELECT
        d.Vatno, d.AdSoyad, d.Firma, d.Lokasyon, d.Departman,
        d.Igt,
        CAST(DATEDIFF(DAY, d.Igt, GETDATE()) / 365.25 AS DECIMAL(6,2)) AS KidemYili,
        CAST(d.Ucret AS DECIMAL(18,2)) AS NetUcret,
        CAST(d.Ucret * @NetBrutKatsayi AS DECIMAL(18,2)) AS AylikBrut,
        CASE WHEN d.Ucret BETWEEN @AltSinir AND @UstSinir THEN 1 ELSE 0 END AS Normal
    FROM dbo.vw_PersonelDepartman d
    WHERE d.Ict IS NULL
),
Hesap AS (
    SELECT *,
        CASE WHEN AylikBrut < @KidemTavani THEN AylikBrut ELSE @KidemTavani END AS TabanUcret
    FROM Aktif
)
SELECT
    Firma,
    SUM(CASE WHEN Normal=1 THEN 1 ELSE 0 END)                                    AS HesabaDahil,
    SUM(CASE WHEN Normal=0 THEN 1 ELSE 0 END)                                    AS AykiriHaric,
    CAST(SUM(CASE WHEN Normal=1 THEN KidemYili END) AS DECIMAL(12,1))            AS ToplamKidemYili,
    CAST(SUM(CASE WHEN Normal=1 THEN KidemYili * TabanUcret END) AS DECIMAL(18,2)) AS TahminiKarsilik_TL
FROM Hesap
GROUP BY Firma
ORDER BY TahminiKarsilik_TL DESC;

/* --- Hariç tutulan aykırı kayıtlar (elle incele) ---
SELECT d.Firma, d.AdSoyad, d.Ucret, CONVERT(varchar,d.Igt,104) AS Giris
FROM dbo.vw_PersonelDepartman d
WHERE d.Ict IS NULL AND (d.Ucret < 10000 OR d.Ucret > 150000)
ORDER BY d.Ucret;                                                              */
