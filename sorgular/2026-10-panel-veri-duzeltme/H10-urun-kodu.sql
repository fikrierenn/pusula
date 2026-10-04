-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Bozuk ürün kodu (sayısal olmayan, 10+ haneli, boşluklu) dönüşümde hata verip ekranı
              çökertiyor mu? Güvenli ifade bu sekiz örnekte NULL mı dönüyor?
   AC       : AC-10.3 · Spec 001 · H10
   Dönem    : yok (sabit değerli tablo + Products tablo taraması)
   Tolerans : sayı birebir
   Önce     : RefQueries.Envanter.cs:65 ve :219 ISNUMERIC(Code)=1 koruması + CONVERT(int, Code) kullanıyor.
              ISNUMERIC('-5')=1, ISNUMERIC(' 123')=1, ISNUMERIC('2147483648')=1; sonuncusunda CONVERT(int) taşar
              (Arithmetic overflow) ve sorgu patlar; bkz. blok ONCE (sekiz satır, ISNUMERIC ve taşma bayrağı).
   Sonra    : yok (düzeltme sonrası ölçülür; güvenli ifade blok A'da)
   Bağımsız : yok. Beklenen değerler elle yazıldı (kontrat AC-10.3); ifade sonucunu kendi içinde doğrular,
              kaynak dışı kanıt değildir. Blok B ayrı bir ölçümdür (Products tablo taraması).
   Aynı kaynak — neden: A ve ONCE aynı sabit sekiz kodu kullanır; bilerek: aynı girdide eski ve yeni ifadeyi
              yan yana göstermek için. B gerçek veriyi taradığı için ayrı kaynaktır.
   Başka ne olabilir: (1) 02.10.2026'da B = 0, yani bugünkü veride bozuk kod yok; çökme riski gelecekteki
              bir kayıttan gelir, bugünkü veriden değil. (2) ' 123' için CONVERT(int) hata vermez (123 döner);
              burada NULL beklenmesi kuralın katı olmasından kaynaklanır, çökme değil. (3) LEN sondaki boşluğu
              saymaz; '123 ' kodu NOT LIKE '%[^0-9]%' ile elenir, bu yüzden sorun çıkmaz.
   Ölçüm    : B = 0 (02.10.2026, denetleyici özeti); bu koşuda yeniden ölçüldü, bkz. T-014 raporu.
   Kapsam   : A/ONCE sabit sekiz kod; B = EncoreMerkez.dbo.Products tüm satırlar (IsValid kolonu yok).
   Dondurma : bc98d56
   SSMS     : her blok kendi DECLARE'ini taşır, GO ile ayrılır.
   Komut    : sqlcli query --profile encore --read-only --max-rows 100000 "<tek blok>" (depo kökünden).
   Bloklar  : A (Kod, Beklenen, Sonuc, Eslesti) · B (SayisalOlmayan) · ONCE (Kod, IsNumeric, TasmaVar)
   AC-10.3  : A sekiz satır ve hepsinde Eslesti = 1; B değeri başlıkta.
*/

-- blok: A  (güvenli dönüşüm ifadesi, sabit değerli tablo)
SELECT
    v.Kod,
    v.Beklenen,
    CASE
        WHEN v.Kod NOT LIKE '%[^0-9]%' AND LEN(v.Kod) BETWEEN 1 AND 9 THEN CONVERT(int, v.Kod)
    END AS Sonuc,
    CASE
        WHEN (CASE
            WHEN v.Kod NOT LIKE '%[^0-9]%' AND LEN(v.Kod) BETWEEN 1 AND 9 THEN CONVERT(int, v.Kod)
        END) = v.Beklenen THEN 1
        WHEN
            v.Beklenen IS NULL
            AND (CASE
                WHEN v.Kod NOT LIKE '%[^0-9]%' AND LEN(v.Kod) BETWEEN 1 AND 9 THEN CONVERT(int, v.Kod)
            END) IS NULL THEN 1
        ELSE 0
    END AS Eslesti
FROM (
    VALUES
    (N'123', 123),
    (N'999999999', 999999999),
    (N'12a', NULL),
    (N'', NULL),
    (N' 123', NULL),
    (N'-5', NULL),
    (N'2147483648', NULL),
    (N'0123456789', NULL)
) AS v (Kod, Beklenen);
GO

-- blok: B  (Products içinde güvenli koşulu sağlamayan kayıt sayısı)
SELECT COUNT(*) AS SayisalOlmayan
-- tam tablo taraması zaten gerekli (sayım); LEN kasıtlı
/* tsqllint-disable non-sargable */
FROM EncoreMerkez.dbo.Products AS p
WHERE
    NOT (p.Code NOT LIKE '%[^0-9]%' AND LEN(p.Code) BETWEEN 1 AND 9)
    OR p.Code IS NULL;
/* tsqllint-enable non-sargable */
GO

-- blok: ONCE  (düzeltme öncesi: panel koruması ISNUMERIC(Code)=1 sekiz örnekte ne döndürür)
-- TasmaVar = 1: korumayı geçer ama CONVERT(int) int sınırını aşar (panel burada patlar).
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
