/* ============================================================================
   PERSONEL DEVİR HIZI (TURNOVER) RAPORU
   ----------------------------------------------------------------------------
   Sunucu : zirve  |  View: dbo.vw_PersonelDepartman
   Tarih  : 03.06.2026  |  Yerel tarih = DMY (CONVERT 104)

   Ne yapar: Belirlenen dönemdeki işten çıkışları SGK çıkış koduna göre
             sınıflar, kıdem tazminatı doğuran çıkışları işaretler, gönüllü
             (istifa) / istemsiz ayrımı yapar ve devir oranını hesaplar.

   Devir oranı = Dönem çıkışları / Ortalama aktif personel
   (Ort. aktif = (dönem başı + dönem sonu aktif) / 2)

   SGK çıkış kodu eşlemesi: 01.04.2021 tarih 2021/9 SGK Genelgesi.
   Kıdem doğuran kodlar: 4,5,8,9,10,11,12,13,14,15,17,18,23,24,25,27,28,
                          31,32,33,34,35,40
   Kaynak: muhasebetr.com/sgk-isten-cikis-kodlari (teyit: SGK 2021/9)
   ============================================================================ */

DECLARE @Bas DATE = '2025-06-01';   -- dönem başlangıcı (dahil)
DECLARE @Bit DATE = '2026-06-01';   -- dönem bitişi (dahil)

/* --- SGK çıkış kodu sözlüğü --- */
WITH CikisKodu AS (
    SELECT * FROM (VALUES
        ('01','Deneme - işverence fesih','İstemsiz',0),
        ('02','Deneme - işçi feshi','Gönüllü',0),
        ('03','İstifa (işçi feshi)','Gönüllü',0),
        ('04','İşveren feshi (haklı sebep yok)','İstemsiz',1),
        ('05','Belirli süre bitişi','İstemsiz',1),
        ('08','Emeklilik / toptan ödeme','Emeklilik',1),
        ('09','Malulen emeklilik','Emeklilik',1),
        ('10','Ölüm','Diğer',1),
        ('11','İş kazası sonucu ölüm','Diğer',1),
        ('12','Askerlik','Gönüllü',1),
        ('13','Kadın işçinin evlenmesi','Gönüllü',1),
        ('15','Toplu işçi çıkarma','İstemsiz',1),
        ('17','İşyerinin kapanması','İstemsiz',1),
        ('18','İşin sona ermesi','İstemsiz',1),
        ('22','Diğer nedenler','Diğer',0),
        ('23','İşçi - zorunlu nedenle fesih','İşçi haklı',1),
        ('24','İşçi - sağlık nedeniyle fesih','İşçi haklı',1),
        ('25','İşçi - işveren ahlak/iyiniyet ihlali','İşçi haklı',1),
        ('48','Devamsızlık (işveren haklı fesih)','İstemsiz',0)
    ) k(Kod, Aciklama, Grup, KidemDogurur)
),
Cikislar AS (
    SELECT
        d.Vatno, d.AdSoyad, d.Firma, d.Lokasyon, d.AltLokasyon, d.Departman,
        LTRIM(RTRIM(d.IstenCikisKodu)) AS Kod,
        d.Ict
    FROM dbo.vw_PersonelDepartman d
    WHERE d.Ict >= @Bas AND d.Ict < DATEADD(DAY,1,@Bit)
)
SELECT
    ISNULL(ck.Grup,'(kodsuz)')      AS Grup,
    c.Kod                           AS CikisKodu,
    ISNULL(ck.Aciklama,'(tanımsız kod)') AS CikisNedeni,
    CASE WHEN ck.KidemDogurur=1 THEN 'EVET' ELSE 'Hayır' END AS KidemDogurur,
    COUNT(*)                        AS CikisAdedi
FROM Cikislar c
LEFT JOIN CikisKodu ck ON ck.Kod = c.Kod
GROUP BY ck.Grup, c.Kod, ck.Aciklama, ck.KidemDogurur
ORDER BY CikisAdedi DESC;

/* --- ÖZET: gönüllü vs istemsiz + devir oranı ---
   (Ayrı çalıştır: aktif personel anlık sayısına göre oran)            */
-- SELECT
--   (SELECT COUNT(*) FROM dbo.vw_PersonelDepartman d
--      WHERE (d.Ict IS NULL OR d.Ict >= @Bit) AND d.Igt < @Bit)        AS DonemSonuAktif,
--   (SELECT COUNT(*) FROM dbo.vw_PersonelDepartman d
--      WHERE d.Ict >= @Bas AND d.Ict < DATEADD(DAY,1,@Bit))            AS DonemCikis;
