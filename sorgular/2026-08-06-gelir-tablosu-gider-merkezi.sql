/* ============================================================================
   AYRINTILI GELİR TABLOSU (Gider Merkezi) — DerinSISBkm
   Net Satış (60−61) → Faaliyet Gideri (740/760/770, kategori .YY) → Faaliyet Kârı
   → Finansman(780)+Komisyon(653/66) + Diğer(64/65/67) + KKEG(689/68) → Net Kâr.
   İşaret: signed fisTutar (gelir BA=0 →+, gider BA=1 →−). Net Kâr = tüm 6xx+7xx signed toplam.
   Kapanış fişi HARİÇ. Yıl = fisSirketID+2020. Merkez: @gdr (NULL=tüm merkez).

   ⚠️ SMM (satılan malın maliyeti) YOK: BKM COGS'u stok hareketiyle tutar, 62 hesabına yazmaz
      → 'Net Kâr' SMM-öncesi katkıdır, gerçek dip-kâr DEĞİL. (Kullanıcı şablonu da COGS'suz.)

   DOĞRULAMA (Haziran toplam): Net Satış 75,74M (ERP SP mhsGelirTabloGiderMerkeziDetayli 61x
   ile birebir) · Faaliyet Kârı 35,39M (%46,7) · Net Kâr 2,04M. ERP SP 6xx-only → 7xx opex'i
   göstermez; bu rapor tam P&L. Uygulama: dashboard /gelir-tablosu (GelirTabloQueries).
   ============================================================================ */
DECLARE @yil int = 2026, @ayBas int = 6, @ay int = 6, @gdr int = NULL;   -- @gdr=NULL: tüm merkez
DECLARE @sirket int = @yil - 2020;

SELECT
  CASE
    WHEN LEFT(h.hspKod,2) IN ('60','61') THEN 'A NET SATIŞLAR'
    WHEN LEFT(h.hspKod,3) IN ('740','760','770','750') THEN 'B Faaliyet Gideri .'+SUBSTRING(h.hspKod,5,2)
    WHEN LEFT(h.hspKod,3)='780' OR LEFT(h.hspKod,2)='66' OR LEFT(h.hspKod,3)='653' THEN 'C Finansman/Komisyon'
    WHEN LEFT(h.hspKod,3) IN ('689','680','681') THEN 'D KKEG/Olağandışı'
    WHEN LEFT(h.hspKod,2) IN ('64','67') THEN 'E Diğer Gelir'
    ELSE 'F Diğer Gider'
  END AS PLSatir,
  h.hspKod, CAST(MAX(h.hspAd) AS nvarchar(60)) hspAd,
  CAST(SUM(ff.fisTutar) AS decimal(18,2)) tutar   -- signed: gelir +, gider −
FROM DerinSISBkm.mhs.mhsFis ff
JOIN DerinSISBkm.mhs.mhsFisBaslik b ON b.fisbID=ff.fisID AND b.fisbSirketID=ff.fisSirketID
JOIN DerinSISBkm.mhs.mhsHsp h ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
WHERE ff.fisSirketID=@sirket AND MONTH(ff.fisTarih) BETWEEN @ayBas AND @ay
  AND ISNULL(b.fisAd,N'')<>N'Kapanış' AND LEFT(h.hspKod,1) IN ('6','7')
  AND (@gdr IS NULL OR ISNULL(ff.fisGdrMerkez,0)=@gdr)
GROUP BY
  CASE
    WHEN LEFT(h.hspKod,2) IN ('60','61') THEN 'A NET SATIŞLAR'
    WHEN LEFT(h.hspKod,3) IN ('740','760','770','750') THEN 'B Faaliyet Gideri .'+SUBSTRING(h.hspKod,5,2)
    WHEN LEFT(h.hspKod,3)='780' OR LEFT(h.hspKod,2)='66' OR LEFT(h.hspKod,3)='653' THEN 'C Finansman/Komisyon'
    WHEN LEFT(h.hspKod,3) IN ('689','680','681') THEN 'D KKEG/Olağandışı'
    WHEN LEFT(h.hspKod,2) IN ('64','67') THEN 'E Diğer Gelir'
    ELSE 'F Diğer Gider'
  END, h.hspKod
HAVING SUM(ff.fisTutar)<>0
ORDER BY PLSatir, tutar;
-- Net Kâr = SUM(tutar) tüm satır · Faaliyet Kârı = A + B satırları.
