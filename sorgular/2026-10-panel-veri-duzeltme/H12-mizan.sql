-- ork:hedef-db DerinSISBkm
-- ork:compat 150
/* Soru     : Mizan nakit göstergesi alınan çeki (101) dışarıda tutuyor mu ve KDV pozisyonu
              devreden KDV'yi (190) içeriyor mu? (Haziran 2026 kümülatif, Ocak-Haziran)
   AC       : AC-12.1, AC-12.2, AC-12.3 · Spec 001 · H12
   Dönem    : @SirketId = 6 (takvim yılı 2026, YilOffset 2020), @AyBas = 1, @Ay = 6.
              Doğrulama dönemi Haziran 2026: son muhasebe kapanışı (İnsan onayı 12).
   Tolerans : ≤ 1,00 TL
   Önce     : MizanQueries.GetSonucAsync gövdesi aynen koşuldu (blok ONCE, 04.10.2026):
              Nakit = 100+101+102+108 = 470.606.973,36 TL (101 DAHİL; 101 = 381.560.000,00);
              KdvNet = 391 − 191 = 0,00 TL (190 HARİÇ; 190 = 56.060.357,14).
   Sonra    : yok (düzeltme T-062/T-063 sonrası ölçülür)
   Bağımsız : A (Nakit 100+102+108) = 89.046.973,36 TL · B (AlinanCek 101) = 381.560.000,00 TL ·
              C (KdvNet 391 − 191 − 190) = -56.060.357,14 TL (eksi = devreden KDV).
              Fark: Nakit 381.560.000,00 (=101); KdvNet -56.060.357,14 (=190).
              Kayıt düzeyinde ayrı yol: mutlak fiş tutarı ve fisBA işaretiyle okunur
              (panelin -tutar/tutar kuralını kullanmaz).
   Kaynak içi kimlik (BAĞIMSIZ DEĞİL): D = mhsMizan_vw ile fiş satırı toplamı. İkisi de
              mhs.mhsFis'ten türer; fark 0 çıkması kaynağın kendi içinde tutarlı olduğunu gösterir,
              panelin doğruluğunu bağımsız kanıtlamaz.
   Aynı kaynak — neden: evet. Panel de kanonik sorgu da DerinSISBkm.mhs fiş satırlarını okur;
              muhasebe mizanının başka bir bağımsız kaynağı yok. Bağımsızlık yalnız yazım yolundan
              gelir (hesap kodu LEFT(…,3), mutlak tutar + fisBA işareti, tarih aralığı, ağaç yok).
   Açılış fişi: şirket 6 fisAd = 'Açılış' (blok ACILIS, 01.01.2026): 100 359.055,89 · 101 215.546.624,25 · 102 14.772.861,52 ·
              108 9.003.159,84 · 190 4.851.259,87 (391 ve 191 açılışta yok); hepsi A, B, C kümülatif sonuçlarına dahildir.
   101 Alınan Çek: 381.560.000,00 yalnız DEFTERDEN (blok ALT101: tek alt hesap 101.10.001 Portföydeki Çekler, 1.469 satır, 764 borç ·
              705 alacak). Çek modülüyle mutabakat bu dosyada YOK; portföyde bu kadar çek olduğu ÇIKARIM, ölçülmedi.
   KDV formülü: 391 − 191 − 190 yalnız devreden KDV durumunu modelliyor (blok KDV_AY: 391 ve 191 her ay borç = alacak, ayrı ayrı
              mahsupla sıfırlanıyor; 190'da 56.060.357,14 birikmiş). Ödenecek KDV çıkan ayda tutar 360 hesabında olur ve bu formüle
              girmez; Haziran 360 alt hesapları blok KDV360'ta (KDV'ye ait yalnız tevkifat −89.552,61).
   Başka ne olabilir: (1) Kapanış fişi: açık yılda yok (şirket 6 fisAd 'Kapanış' 0; blok E kapanis_satiri 0). Kapalı yılda sınandı
              (blok KAPANIS_2025, şirket 5: kapanış satırları 100 · 101 · 102 · 108 · 190 için dahil bakiye 0,00, hariç bakiye sıfırdan
              farklı, yani süzgeç gerekli ve çalışıyor). (2) 391 ve 191 aylık devirle sıfırlanıyor; KDV pozisyonu 190'da birikiyor.
              (3) 101 bakiyesi Ocak-Haziran her ayda pozitif; verilen çek 103 hesabındadır (bakiye negatif) ve bu dosyada okunmaz.
              Haziran ay hareketi 101'de alacak ağırlıklı (−26.900.000,00) olabilir, kümülatif bakiye değil.
              (4) Blok D iki yönlü (FULL OUTER JOIN): yalnız görünümde olan hesap da fark olarak çıkar.
   Kapsam   : fisSirketID = @SirketId; ay aralığı @AyBas..@Ay; "Kapanış" bilanço fişi hariç.
   Dondurma : 18c2ce0
   SSMS     : her blok kendi DECLARE'ini taşır, GO ile ayrılır.
   Komut    : sqlcli query --profile erp --read-only --max-rows 100000 "<tek blok>" (depo kökünden).
   Bloklar  : A (Nakit) · B (AlinanCek) · C (KdvNet) · D (kaynak içi kimlik) · E (nüfus) · ONCE (panel gövdesi)
              · ACILIS · ALT101 · KDV_AY · KDV360 · KAPANIS_2025
   AC-12.x  : nüfus E: her hesap grubunda satır > 0 (0 ise KOŞAMADI).
*/

-- blok: A  (Nakit = borç bakiyesi 100 + 102 + 108)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
SELECT CAST(SUM(CASE WHEN f.fisBA = 1 THEN ABS(f.fisTutar) ELSE -ABS(f.fisTutar) END) AS decimal(18, 2)) AS Nakit
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
WHERE
    f.fisSirketID = @SirketId
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) IN ('100', '102', '108')
    AND NOT EXISTS (
        SELECT 1
        FROM DerinSISBkm.mhs.mhsFisBaslik AS k
        WHERE
            k.fisbID = f.fisID
            AND k.fisbSirketID = f.fisSirketID
            AND k.fisAd = N'Kapanış'
    );
GO

-- blok: B  (AlinanCek = borç bakiyesi 101)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
SELECT CAST(SUM(CASE WHEN f.fisBA = 1 THEN ABS(f.fisTutar) ELSE -ABS(f.fisTutar) END) AS decimal(18, 2)) AS AlinanCek
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
WHERE
    f.fisSirketID = @SirketId
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) = '101'
    AND NOT EXISTS (
        SELECT 1
        FROM DerinSISBkm.mhs.mhsFisBaslik AS k
        WHERE
            k.fisbID = f.fisID
            AND k.fisbSirketID = f.fisSirketID
            AND k.fisAd = N'Kapanış'
    );
GO

-- blok: C  (KdvNet = 391 alacak bakiyesi − 191 borç bakiyesi − 190 borç bakiyesi)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
SELECT CAST(SUM(CASE WHEN f.fisBA = 1 THEN -ABS(f.fisTutar) ELSE ABS(f.fisTutar) END) AS decimal(18, 2)) AS KdvNet
-- 391 alacak bakiyesi (alacak − borç) ile 191/190 borç bakiyesinin (borç − alacak) çıkarılması:
-- üç hesapta da alacak satırı +, borç satırı −
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
WHERE
    f.fisSirketID = @SirketId
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) IN ('391', '191', '190')
    AND NOT EXISTS (
        SELECT 1
        FROM DerinSISBkm.mhs.mhsFisBaslik AS k
        WHERE
            k.fisbID = f.fisID
            AND k.fisbSirketID = f.fisSirketID
            AND k.fisAd = N'Kapanış'
    );
GO

-- blok: D  (kaynak içi kimlik: mhsMizan_vw ↔ fiş satırı; ikisi de mhsFis'ten türer, bağımsız değil)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
WITH FisCTE AS (
    SELECT
        LEFT(h.hspKod, 3) AS ana_hesap,
        SUM(CASE WHEN f.fisBA = 1 THEN ABS(f.fisTutar) ELSE -ABS(f.fisTutar) END) AS fis_bakiye
    FROM DerinSISBkm.mhs.mhsFis AS f
        INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
            ON
                f.fisHspID = h.hspID
                AND f.fisSirketID = h.hspSirketID
    WHERE
        f.fisSirketID = @SirketId
        AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
        AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
        AND LEFT(h.hspKod, 3) IN ('100', '101', '102', '108', '190', '191', '391')
    GROUP BY LEFT(h.hspKod, 3)
),

GorunumCTE AS (
    SELECT
        LEFT(v.hspKod, 3) AS ana_hesap,
        SUM(v.Borc - v.Alacak) AS gorunum_bakiye
    FROM DerinSISBkm.mhs.mhsMizan_vw AS v
    WHERE
        v.fisSirketID = @SirketId
        AND v.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
        AND v.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
        AND LEFT(v.hspKod, 3) IN ('100', '101', '102', '108', '190', '191', '391')
    GROUP BY LEFT(v.hspKod, 3)
)

SELECT
    ISNULL(fc.ana_hesap, gc.ana_hesap) AS ana_hesap,
    CAST(fc.fis_bakiye AS decimal(18, 2)) AS fis_bakiye,
    CAST(gc.gorunum_bakiye AS decimal(18, 2)) AS gorunum_bakiye,
    CAST(ISNULL(gc.gorunum_bakiye, 0) - ISNULL(fc.fis_bakiye, 0) AS decimal(18, 2)) AS fark
FROM FisCTE AS fc
    FULL OUTER JOIN GorunumCTE AS gc
        ON fc.ana_hesap = gc.ana_hesap
ORDER BY ISNULL(fc.ana_hesap, gc.ana_hesap);
GO

-- blok: E  (nüfus: hesap grubu başına fiş satırı + Kapanış fişi sayısı)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
SELECT
    LEFT(h.hspKod, 3) AS ana_hesap,
    COUNT(*) AS satir_sayisi,
    SUM(CASE WHEN k.fisbID IS NOT NULL THEN 1 ELSE 0 END) AS kapanis_satiri
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
    LEFT JOIN DerinSISBkm.mhs.mhsFisBaslik AS k
        ON
            f.fisID = k.fisbID
            AND f.fisSirketID = k.fisbSirketID
            AND k.fisAd = N'Kapanış'
WHERE
    f.fisSirketID = @SirketId
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) IN ('100', '101', '102', '108', '190', '191', '391')
GROUP BY LEFT(h.hspKod, 3)
ORDER BY LEFT(h.hspKod, 3);
GO

-- blok: ONCE  (panel gövdesi aynen: MizanQueries.GetSonucAsync leaf sorgusu + 3 haneli toplama + OzetHesapla)
SET NOCOUNT ON;
DECLARE @sirketId int = 6, @ay int = 6, @ayBas int = 1;
WITH Leaf AS (
    SELECT
        h.hspKod AS hsp_kod,
        h.hspAd AS hsp_ad,
        CAST(SUM(CASE WHEN ff.fisBA = 1 THEN -ff.fisTutar ELSE 0 END) AS decimal(18, 2)) AS Borc,
        CAST(SUM(CASE WHEN ff.fisBA = 0 THEN ff.fisTutar ELSE 0 END) AS decimal(18, 2)) AS Alacak
    FROM DerinSISBkm.mhs.mhsFis AS ff
        INNER JOIN DerinSISBkm.mhs.mhsHsp AS h ON ff.fisHspID = h.hspID AND ff.fisSirketID = h.hspSirketID
    WHERE
        ff.fisSirketID = @sirketId
        -- ork:izin QRY-005 panel gövdesi aynen (ÖNCE ölçümü)
        AND MONTH(ff.fisTarih) BETWEEN @ayBas AND @ay   -- tsqllint-disable-line non-sargable   
        AND NOT EXISTS (
            SELECT 1 FROM DerinSISBkm.mhs.mhsFisBaslik AS k
            WHERE k.fisbID = ff.fisID AND k.fisbSirketID = ff.fisSirketID AND k.fisAd = N'Kapanış'
        )
    GROUP BY h.hspKod, h.hspAd
    HAVING
        SUM(CASE WHEN ff.fisBA = 1 THEN -ff.fisTutar ELSE 0 END) <> 0
        OR SUM(CASE WHEN ff.fisBA = 0 THEN ff.fisTutar ELSE 0 END) <> 0
),

UcHane AS (
    SELECT
        LEFT(l.hsp_kod, CASE WHEN CHARINDEX('.', l.hsp_kod) = 0 THEN LEN(l.hsp_kod) ELSE CHARINDEX('.', l.hsp_kod) - 1 END) AS ana,
        SUM(l.Borc - l.Alacak) AS bakiye
    FROM Leaf AS l
    GROUP BY LEFT(l.hsp_kod, CASE WHEN CHARINDEX('.', l.hsp_kod) = 0 THEN LEN(l.hsp_kod) ELSE CHARINDEX('.', l.hsp_kod) - 1 END)
)

SELECT
    CAST(SUM(CASE WHEN u.ana IN ('100', '101', '102', '108') THEN u.bakiye ELSE 0 END) AS decimal(18, 2)) AS NakitPanel,
    CAST(SUM(CASE WHEN u.ana = '101' THEN u.bakiye ELSE 0 END) AS decimal(18, 2)) AS Panel101,
    CAST(SUM(CASE
        WHEN u.ana = '391' THEN -u.bakiye
        WHEN u.ana = '191' THEN -u.bakiye ELSE 0
    END) AS decimal(18, 2)) AS KdvNetPanel,
    CAST(SUM(CASE WHEN u.ana = '190' THEN u.bakiye ELSE 0 END) AS decimal(18, 2)) AS Panel190
FROM UcHane AS u;
GO

-- blok: ACILIS  (açılış fişi tutarları: şirket 6 yılbaşı, ana hesap başına borç − alacak; kümülatif sonuca dahildir)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
SELECT
    LEFT(h.hspKod, 3) AS ana_hesap,
    COUNT(*) AS satir_sayisi,
    CAST(SUM(CASE WHEN f.fisBA = 1 THEN ABS(f.fisTutar) ELSE -ABS(f.fisTutar) END) AS decimal(18, 2)) AS acilis_bakiye
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
    INNER JOIN DerinSISBkm.mhs.mhsFisBaslik AS k
        ON
            f.fisID = k.fisbID
            AND f.fisSirketID = k.fisbSirketID
WHERE
    f.fisSirketID = @SirketId
    AND k.fisAd = N'Açılış'
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) IN ('100', '101', '102', '108', '190', '191', '391')
GROUP BY LEFT(h.hspKod, 3)
ORDER BY LEFT(h.hspKod, 3);
GO

-- blok: ALT101  (101 alt hesap kırılımı: tek alt hesap mı; borç ve alacak satırı; çek modülü ile mutabakat yok)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
SELECT
    h.hspKod AS hesap_kodu,
    COUNT(*) AS satir_sayisi,
    SUM(CASE WHEN f.fisBA = 1 THEN 1 ELSE 0 END) AS borc_satiri,
    SUM(CASE WHEN f.fisBA = 0 THEN 1 ELSE 0 END) AS alacak_satiri,
    CAST(SUM(CASE WHEN f.fisBA = 1 THEN ABS(f.fisTutar) ELSE -ABS(f.fisTutar) END) AS decimal(18, 2)) AS bakiye
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
WHERE
    f.fisSirketID = @SirketId
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) IN ('101', '103')
    AND NOT EXISTS (
        SELECT 1
        FROM DerinSISBkm.mhs.mhsFisBaslik AS k
        WHERE
            k.fisbID = f.fisID
            AND k.fisbSirketID = f.fisSirketID
            AND k.fisAd = N'Kapanış'
    )
GROUP BY h.hspKod
ORDER BY h.hspKod;
GO

-- blok: KDV_AY  (190, 191, 391 ay ay borç ve alacak: 391 ve 191 ayrı ayrı mahsupla sıfırlanıyor mu)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
SELECT
    LEFT(h.hspKod, 3) AS ana_hesap,
    MONTH(f.fisTarih) AS ay,
    CAST(SUM(CASE WHEN f.fisBA = 1 THEN ABS(f.fisTutar) ELSE 0 END) AS decimal(18, 2)) AS borc,
    CAST(SUM(CASE WHEN f.fisBA = 0 THEN ABS(f.fisTutar) ELSE 0 END) AS decimal(18, 2)) AS alacak
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
WHERE
    f.fisSirketID = @SirketId
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) IN ('190', '191', '391')
    AND NOT EXISTS (
        SELECT 1
        FROM DerinSISBkm.mhs.mhsFisBaslik AS k
        WHERE
            k.fisbID = f.fisID
            AND k.fisbSirketID = f.fisSirketID
            AND k.fisAd = N'Kapanış'
    )
GROUP BY LEFT(h.hspKod, 3), MONTH(f.fisTarih)
ORDER BY LEFT(h.hspKod, 3), MONTH(f.fisTarih);
GO

-- blok: KDV360  (360 alt hesaplar: ödenecek KDV bu formüle girmiyor; hangi alt hesaplar var, bakiyeleri)
SET NOCOUNT ON;
DECLARE @SirketId int = 6, @Ay int = 6, @AyBas int = 1;
SELECT
    h.hspKod AS hesap_kodu,
    COUNT(*) AS satir_sayisi,
    CAST(SUM(CASE WHEN f.fisBA = 0 THEN ABS(f.fisTutar) ELSE -ABS(f.fisTutar) END) AS decimal(18, 2)) AS alacak_bakiyesi
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
WHERE
    f.fisSirketID = @SirketId
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) = '360'
    AND NOT EXISTS (
        SELECT 1
        FROM DerinSISBkm.mhs.mhsFisBaslik AS k
        WHERE
            k.fisbID = f.fisID
            AND k.fisbSirketID = f.fisSirketID
            AND k.fisAd = N'Kapanış'
    )
GROUP BY h.hspKod
ORDER BY h.hspKod;
GO

-- blok: KAPANIS_2025  (kapanış süzgeci kapalı yılda sınanır: şirket 5 = 2025, Ocak-Aralık; kapanış satırı, dışlanınca bakiye)
SET NOCOUNT ON;
DECLARE @SirketId int = 5, @Ay int = 12, @AyBas int = 1;
SELECT
    LEFT(h.hspKod, 3) AS ana_hesap,
    COUNT(*) AS satir_sayisi,
    SUM(CASE WHEN k.fisbID IS NOT NULL THEN 1 ELSE 0 END) AS kapanis_satiri,
    CAST(SUM(
        CASE
            WHEN k.fisbID IS NULL THEN (CASE WHEN f.fisBA = 1 THEN ABS(f.fisTutar) ELSE -ABS(f.fisTutar) END)
            ELSE 0
        END
    ) AS decimal(18, 2)) AS kapanis_haric_bakiye,
    CAST(SUM(CASE WHEN f.fisBA = 1 THEN ABS(f.fisTutar) ELSE -ABS(f.fisTutar) END) AS decimal(18, 2)) AS kapanis_dahil_bakiye
FROM DerinSISBkm.mhs.mhsFis AS f
    INNER JOIN DerinSISBkm.mhs.mhsHsp AS h
        ON
            f.fisHspID = h.hspID
            AND f.fisSirketID = h.hspSirketID
    LEFT JOIN DerinSISBkm.mhs.mhsFisBaslik AS k
        ON
            f.fisID = k.fisbID
            AND f.fisSirketID = k.fisbSirketID
            AND k.fisAd = N'Kapanış'
WHERE
    f.fisSirketID = @SirketId
    AND f.fisTarih >= DATEFROMPARTS(@SirketId + 2020, @AyBas, 1)
    AND f.fisTarih < DATEADD(MONTH, 1, DATEFROMPARTS(@SirketId + 2020, @Ay, 1))
    AND LEFT(h.hspKod, 3) IN ('100', '101', '102', '108', '190', '191', '391')
GROUP BY LEFT(h.hspKod, 3)
ORDER BY LEFT(h.hspKod, 3);
GO
