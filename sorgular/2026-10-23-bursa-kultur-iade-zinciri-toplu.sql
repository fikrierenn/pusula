-- ork:hedef-db DerinSISBkm
-- Bursa Kültür iade zinciri — ürün ürün kontrol (tetik: BİZİM iade faturamız)
-- Çalıştırma: SSMS, 192.168.40.201, DerinSISBkm. KIBO'ya linked server [192.168.40.140] ile gider (salt okuma).
-- Zincir: fat.eTip=2 (Alış İade, eFirma=56)  →  KIBO tumbelgeler.fattakipno = fat.eNo (belgekod 3 = Alış)
--         →  aynı barkodun iade tarihinden SONRA KIBO'daki hareketleri:
--            belgekod 2 = Alış İade (tedarikçiye) · 1 = Satış (BKM'ye geri satış ayrı) · 27 = perakende fiş
-- KIBO: BKM carisi skod 1417 (+ eski 1412). Satırda lngcarikod 0 olabilir → cari BAŞLIKTAN alınır.
--       stokinout.stok_kod = barkod (urnBrkd.urnBarkod, urnBrkdOnce=0). 106 = 27'nin aynası, sayılmaz.
-- Tedarikçi iadesi = fatura tarihinden SONRAKİ İLK Alış İade belgesi (kullanıcı kuralı 23.10.2026); adet o belgedeki.
-- ⚠ Eşleşme ÜRÜN + TARİH bazlıdır (KIBO iadesi bizim belgemize bağlanamaz). Aynı ürün birden çok iademizde
--   geçiyorsa aynı ilk iade her birinde görünür — o satırlar ayrıca okunmalı.
-- Kanıt / tek fatura örnekleri: sorgular/2026-10-23-bursa-kultur-iade-zinciri.sql

SET NOCOUNT ON;

DECLARE @Bas date = CONVERT(date, '01.01.2024', 104);
DECLARE @Bit date = CONVERT(date, '31.12.2026', 104);
DECLARE @FaturaNo varchar(30) = NULL;   -- tek fatura için: 'IEF2025000000680'

IF OBJECT_ID('tempdb..#iade') IS NOT NULL DROP TABLE #iade;
IF OBJECT_ID('tempdb..#kibo_bas') IS NOT NULL DROP TABLE #kibo_bas;
IF OBJECT_ID('tempdb..#kibo_hrk') IS NOT NULL DROP TABLE #kibo_hrk;

-- 1) Bizim iade satırlarımız (fatura + barkod düzeyine toplanmış)
SELECT f.eNo, f.eTarih, f.eMekan, a.ehStkID AS stkID,
       CAST(b.urnBarkod AS varchar(50)) AS barkod, u.stkAd,
       SUM(-a.ehAdetN) AS bizim_adet, SUM(a.ehTutarN) AS bizim_tutarN
INTO #iade
FROM dbo.fat f
JOIN dbo.fatAyr a ON a.ehID = f.eID
JOIN dbo.urn u ON u.stkID = a.ehStkID
LEFT JOIN dbo.urnBrkd b ON b.urnBrkdStkID = a.ehStkID AND b.urnBrkdOnce = 0
WHERE f.eFirma = 56 AND f.eTip = 2 AND f.eDurum <> 2
  AND f.eTarih >= @Bas AND f.eTarih < DATEADD(DAY, 1, @Bit)
  AND (@FaturaNo IS NULL OR f.eNo = @FaturaNo)
GROUP BY f.eNo, f.eTarih, f.eMekan, a.ehStkID, b.urnBarkod, u.stkAd;

-- Uzak tarafa süzgeci LİTERAL liste olarak göndermek için (yerel #tablo ile join uzağa itilmez → tüm tablo çekilir)
DECLARE @FaturaListe nvarchar(max) = STUFF((
    SELECT DISTINCT ',''' + REPLACE(eNo, '''', '''''') + '''' FROM #iade FOR XML PATH(''), TYPE
).value('.', 'nvarchar(max)'), 1, 1, '');
DECLARE @BarkodListe nvarchar(max) = STUFF((
    SELECT DISTINCT ',''' + REPLACE(barkod, '''', '''''') + '''' FROM #iade WHERE barkod IS NOT NULL FOR XML PATH(''), TYPE
).value('.', 'nvarchar(max)'), 1, 1, '');

IF @FaturaListe IS NULL
BEGIN
    SELECT 'Seçilen aralıkta Bursa Kültür''e iade faturası yok.' AS bilgi;
    RETURN;
END;

CREATE TABLE #kibo_bas (fattakipno varchar(50), belgeno int, belgekod int, tarih datetime, lngcarikod int);
CREATE TABLE #kibo_hrk (stok_kod varchar(50), duz_tarih datetime, belge_kod int, belge_no int,
                        cari int, firma varchar(200), in_miktar decimal(18,4), out_miktar decimal(18,4));

-- 2) KIBO'da bizim iade faturamızın kaydı
DECLARE @sql nvarchar(max) = N'
INSERT INTO #kibo_bas (fattakipno, belgeno, belgekod, tarih, lngcarikod)
SELECT t.fattakipno, t.belgeno, t.belgekod, t.tarih, t.lngcarikod
FROM [192.168.40.140].kibobkm.dbo.tumbelgeler t
WHERE t.fattakipno IN (' + @FaturaListe + N');';
EXEC sys.sp_executesql @sql;

-- 3) Aynı barkodların KIBO hareketleri (alış, alış iade, satış, perakende)
SET @sql = N'
INSERT INTO #kibo_hrk (stok_kod, duz_tarih, belge_kod, belge_no, cari, firma, in_miktar, out_miktar)
SELECT s.stok_kod, s.duz_tarih, s.belge_kod, s.belge_no,
       CASE WHEN s.belge_kod = 27 THEN 0 ELSE t.lngcarikod END, c.firma, s.in_miktar, s.out_miktar
FROM [192.168.40.140].kibobkm.dbo.stokinout s
LEFT JOIN [192.168.40.140].kibobkm.dbo.tumbelgeler t ON t.belgeno = s.belge_no AND t.belgekod = s.belge_kod
LEFT JOIN [192.168.40.140].kibobkm.dbo.cari c ON c.skod = t.lngcarikod
WHERE s.stok_kod IN (' + @BarkodListe + N')
  AND s.belge_kod IN (1, 2, 3, 27);';
EXEC sys.sp_executesql @sql;

-- 4) Ürün ürün sonuç
WITH sonuc AS (
    SELECT i.eNo, i.eTarih, i.eMekan, i.stkID, i.barkod, i.stkAd, i.bizim_adet, i.bizim_tutarN,
           kb.belgeno AS kibo_belgeno,
           ISNULL(g.kibo_giris, 0) AS kibo_giris,
           ilk.ilk_iade_belgeno, ISNULL(ia.tedarikciye_iade, 0) AS tedarikciye_iade,
           ilk.ilk_tedarikci_iade, ilk.tedarikci_iade_firma,
           ISNULL(h.bkm_ye_geri_satis, 0) AS bkm_ye_geri_satis,
           ISNULL(h.baskasina_satis, 0) AS baskasina_satis,
           ISNULL(h.perakende, 0) AS perakende,
           ted.son_tedarikci, ted.son_alis
    FROM #iade i
    LEFT JOIN #kibo_bas kb ON kb.fattakipno = i.eNo COLLATE Turkish_CI_AS AND kb.belgekod = 3
    OUTER APPLY (
        SELECT SUM(k.in_miktar) AS kibo_giris
        FROM #kibo_hrk k
        WHERE k.belge_kod = 3 AND k.belge_no = kb.belgeno AND k.stok_kod = i.barkod COLLATE Turkish_CI_AS
    ) g
    OUTER APPLY (   -- fatura tarihinden SONRAKİ İLK tedarikçi iadesi (tek belge)
        SELECT TOP 1 k.belge_no AS ilk_iade_belgeno, k.duz_tarih AS ilk_tedarikci_iade, k.firma AS tedarikci_iade_firma
        FROM #kibo_hrk k
        WHERE k.stok_kod = i.barkod COLLATE Turkish_CI_AS
          AND k.duz_tarih >= i.eTarih
          AND k.belge_kod = 2 AND k.cari NOT IN (1417, 1412)
        ORDER BY k.duz_tarih, k.belge_no
    ) ilk
    OUTER APPLY (
        SELECT SUM(k.out_miktar) AS tedarikciye_iade
        FROM #kibo_hrk k
        WHERE k.belge_kod = 2 AND k.belge_no = ilk.ilk_iade_belgeno
          AND k.stok_kod = i.barkod COLLATE Turkish_CI_AS
    ) ia
    OUTER APPLY (
        SELECT SUM(CASE WHEN k.belge_kod = 1 AND k.cari IN (1417, 1412) THEN k.out_miktar ELSE 0 END) AS bkm_ye_geri_satis,
               SUM(CASE WHEN k.belge_kod = 1 AND k.cari NOT IN (1417, 1412) THEN k.out_miktar ELSE 0 END) AS baskasina_satis,
               SUM(CASE WHEN k.belge_kod = 27 THEN k.out_miktar ELSE 0 END) AS perakende
        FROM #kibo_hrk k
        WHERE k.stok_kod = i.barkod COLLATE Turkish_CI_AS
          AND k.duz_tarih >= i.eTarih
          AND NOT (k.belge_kod = 3 AND k.belge_no = kb.belgeno)
    ) h
    OUTER APPLY (
        SELECT TOP 1 k.firma AS son_tedarikci, k.duz_tarih AS son_alis
        FROM #kibo_hrk k
        WHERE k.stok_kod = i.barkod COLLATE Turkish_CI_AS
          AND k.belge_kod = 3 AND k.cari NOT IN (1417, 1412)
        ORDER BY k.duz_tarih DESC
    ) ted
)
SELECT eNo AS FaturaNo, CONVERT(varchar(10), eTarih, 104) AS FaturaTarihi, eMekan AS Mekan,
       stkID, barkod AS Barkod, stkAd AS Urun,
       bizim_adet AS BizimIadeAdet, bizim_tutarN AS BizimTutarKdvHaric,
       kibo_belgeno AS KiboBelgeNo, kibo_giris AS KiboGirisAdet,
       bizim_adet - kibo_giris AS GirisFarki,
       ilk_iade_belgeno AS IlkIadeKiboBelgeNo,
       CONVERT(varchar(10), ilk_tedarikci_iade, 104) AS IlkIadeTarihi, tedarikci_iade_firma AS IadeEdilenFirma,
       tedarikciye_iade AS IlkIadeAdet,
       DATEDIFF(DAY, eTarih, ilk_tedarikci_iade) AS IadeyeKadarGun,
       bkm_ye_geri_satis AS BkmyeGeriSatisAdet, baskasina_satis AS BaskasinaSatisAdet, perakende AS PerakendeAdet,
       son_tedarikci AS SonTedarikci, CONVERT(varchar(10), son_alis, 104) AS SonTedarikciAlis,
       CASE
           WHEN kibo_belgeno IS NULL THEN 'KIBO''ya GİRİLMEMİŞ'
           WHEN kibo_giris <> bizim_adet THEN 'GİRİŞ ADEDİ FARKLI'
           WHEN tedarikciye_iade >= bizim_adet THEN 'TEDARİKÇİYE İADE EDİLDİ'
           WHEN tedarikciye_iade > 0 THEN 'KISMEN İADE EDİLDİ'
           WHEN bkm_ye_geri_satis > 0 THEN 'BKM''YE GERİ SATILDI'
           ELSE 'BURSA KÜLTÜR''DE (iade yok)'
       END AS Durum,
       DATEDIFF(DAY, eTarih, GETDATE()) AS GecenGun
FROM sonuc
ORDER BY eTarih, eNo, bizim_tutarN DESC;
