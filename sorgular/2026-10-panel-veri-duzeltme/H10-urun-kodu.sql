-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Bozuk ürün kodu (sayısal olmayan, 10+ haneli, boşluklu, Unicode rakam) dönüşümde hata verip
              ekranı çökertiyor mu? Güvenli ifade bu on bir örnekte NULL mı dönüyor?
   AC       : AC-10.3 · Spec 001 · H10
   Dönem    : yok (sabit değerli tablo + Products tablo taraması)
   Tolerans : sayı birebir
   Önce     : RefQueries.Envanter.cs:65 ve :219 ISNUMERIC(Code)=1 koruması + CONVERT(int, Code) kullanıyor.
              ISNUMERIC('2147483648')=1 ve CONVERT(int, N'2147483648') taşma hatası verir; ÖLÇÜLDÜ 04.10.2026:
              `sqlcli query --profile encore --read-only "SELECT CONVERT(int, N'2147483648')"` → "tamsayı
              sütununda taşma oluştu". ONCE bloğundaki TasmaVar sütunu ise TÜRETMEDİR (decimal karşılaştırması),
              CONVERT(int) koşmaz. Ayrıca Turkish_CI_AS altında [0-9] aralığı ², １２ (tam genişlik), ٣ ile
              eşleşir ve CONVERT(int, N'²') "dönüştürülürken işlem başarısız oldu" ile patlar (aynı gün, aynı
              komutla ölçüldü); bkz. ONCE_UNICODE (CONVERT koşmaz, yalnız LIKE sonucu).
   Sonra    : yok (düzeltme sonrası ölçülür; güvenli ifade blok A'da)
   Bağımsız : yok. Beklenen değerler elle yazıldı (kontrat AC-10.3); ifade sonucunu kendi içinde doğrular,
              kaynak dışı kanıt değildir. Blok B ayrı bir ölçümdür (Products tablo taraması).
   Aynı kaynak — neden: A ve ONCE aynı sabit kodları kullanır; bilerek: aynı girdide eski ve yeni ifadeyi
              yan yana göstermek için. B gerçek veriyi taradığı için ayrı kaynaktır.
   Başka ne olabilir: (1) B = 0 (02.10.2026 özet, 04.10.2026 yeniden ölçüldü): bugünkü veride bozuk kod yok;
              çökme riski gelecekteki bir kayıttan gelir. (2) ' 123' için CONVERT(int) hata vermez (123 döner);
              NULL beklenmesi kuralın katı olmasından kaynaklanır. (3) LEN sondaki boşluğu saymaz; '123 ' kodu
              NOT LIKE '%[^0-9]%' ile elenir. (4) CASE içinde LIKE ve LEN koşulu yanlışsa CONVERT'in
              değerlendirilmemesi bu SQL Server sürümünde ÖLÇÜLDÜ; resmi bir garanti değildir (derleyici
              ifade sırasını değiştirebilir). Kural bu yüzden CONVERT'i yalnız CASE'in THEN dalına koyar.
   Kapsam   : A/ONCE sabit kodlar; B = EncoreMerkez.dbo.Products tüm satırlar (IsValid kolonu yok).
   Dondurma : bc98d56
   SSMS     : her blok kendi DECLARE'ini taşır, GO ile ayrılır.
   Komut    : sqlcli query --profile encore --read-only --max-rows 100000 "<tek blok>" (depo kökünden).
   Bloklar  : A (Kod, Beklenen, Sonuc, Eslesti) · B (SayisalOlmayan) · ONCE (Kod, IsNumeric, TasmaVar)
              · ONCE_UNICODE (Kod, EskiKuralGecer, YeniKuralGecer)
   AC-10.3  : A on bir satır ve hepsinde Eslesti = 1; B değeri başlıkta.
*/

-- blok: A  (güvenli dönüşüm ifadesi, ikili collation, sabit değerli tablo)
WITH Girdi AS (
    SELECT
        v.Kod,
        v.Beklenen
    FROM (
        VALUES
        (N'123', 123),
        (N'999999999', 999999999),
        (N'12a', NULL),
        (N'', NULL),
        (N' 123', NULL),
        (N'-5', NULL),
        (N'2147483648', NULL),
        (N'0123456789', NULL),
        (N'²', NULL),
        (N'１２', NULL),
        (N'٣', NULL)
    ) AS v (Kod, Beklenen)
),

Hesap AS (
    SELECT
        g.Kod,
        g.Beklenen,
        CASE
            WHEN g.Kod COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(g.Kod) BETWEEN 1 AND 9
                THEN CONVERT(int, g.Kod)
        END AS Sonuc
    FROM Girdi AS g
)

SELECT
    h.Kod,
    h.Beklenen,
    h.Sonuc,
    CASE
        WHEN h.Sonuc = h.Beklenen THEN 1
        WHEN h.Beklenen IS NULL AND h.Sonuc IS NULL THEN 1
        ELSE 0
    END AS Eslesti
FROM Hesap AS h;
GO

-- blok: B  (Products içinde güvenli koşulu sağlamayan kayıt sayısı, pozitif yazım)
-- tam tablo taraması zaten gerekli (sayım); LEN kasıtlı
/* tsqllint-disable non-sargable */
SELECT
    COUNT(*) AS Satir,
    SUM(
        CASE
            WHEN p.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(p.Code) BETWEEN 1 AND 9 THEN 0
            ELSE 1
        END
    ) AS SayisalOlmayan
FROM EncoreMerkez.dbo.Products AS p;
/* tsqllint-enable non-sargable */
GO

-- blok: ONCE  (düzeltme öncesi: panel koruması ISNUMERIC(Code)=1 sekiz örnekte ne döndürür)
-- TasmaVar = 1 TÜRETMEDİR (decimal karşılaştırması): korumayı geçer ama değer int sınırını aşar.
SELECT
    v.Kod,
    ISNUMERIC(v.Kod) AS [IsNumeric],
    CASE
        WHEN ISNUMERIC(v.Kod) = 1 AND ABS(CONVERT(decimal(38, 0), v.Kod)) > 2147483647 THEN 1
        ELSE 0
    END AS TasmaVar
FROM (
    VALUES
    (N'123'),
    (N'999999999'),
    (N'12a'),
    (N''),
    (N' 123'),
    (N'-5'),
    (N'2147483648'),
    (N'0123456789')
) AS v (Kod);
GO

-- blok: ONCE_UNICODE  (eski kural varsayılan collation'da, yeni kural ikili collation'da; CONVERT koşmaz)
-- EskiKuralGecer = 1 ise eski kural bu kodu "sayı" sanıp CONVERT(int)'e gönderirdi (hata verir).
SELECT
    v.Kod,
    CASE
        WHEN v.Kod NOT LIKE '%[^0-9]%' AND LEN(v.Kod) BETWEEN 1 AND 9 THEN 1
        ELSE 0
    END AS EskiKuralGecer,
    CASE
        WHEN v.Kod COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(v.Kod) BETWEEN 1 AND 9 THEN 1
        ELSE 0
    END AS YeniKuralGecer
FROM (
    VALUES
    (N'²'),
    (N'１２'),
    (N'٣')
) AS v (Kod);
