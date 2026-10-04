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
   Başka ne olabilir: (1) Kapanış fişi: açık yılda yok (blok E kapanis_satiri 0); varsa hariç tutulur (panel gibi).
              (2) 391 ve 191 aylık devirle sıfırlanıyor (bakiye 0,00); KDV pozisyonu 190'da birikiyor. (3) 101 bakiyesi negatif olabilir
              (verilen çek ters yön); işaret blok B'de borç-pozitif okunur.
   Kapsam   : fisSirketID = @SirketId; ay aralığı @AyBas..@Ay; "Kapanış" bilanço fişi hariç.
   Dondurma : bc98d56
   SSMS     : her blok kendi DECLARE'ini taşır, GO ile ayrılır.
   Komut    : sqlcli query --profile erp --read-only --max-rows 100000 "<tek blok>" (depo kökünden).
   Bloklar  : A (Nakit) · B (AlinanCek) · C (KdvNet) · D (kaynak içi kimlik) · E (nüfus) · ONCE (panel gövdesi)
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
    fc.ana_hesap,
    CAST(fc.fis_bakiye AS decimal(18, 2)) AS fis_bakiye,
    CAST(gc.gorunum_bakiye AS decimal(18, 2)) AS gorunum_bakiye,
    CAST(ISNULL(gc.gorunum_bakiye, 0) - fc.fis_bakiye AS decimal(18, 2)) AS fark
FROM FisCTE AS fc
    LEFT JOIN GorunumCTE AS gc
        ON fc.ana_hesap = gc.ana_hesap
ORDER BY fc.ana_hesap;
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
