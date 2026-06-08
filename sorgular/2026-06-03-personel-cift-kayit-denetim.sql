/* ============================================================================
   Personel Çift Kayıt Denetimi (Özet Rapor güvenlik kontrolü)
   ----------------------------------------------------------------------------
   Amaç : Departman bazlı headcount özet raporunda (Rapor 1) çift sayımı
          önlemek. Bir personelin AYNI snapshot tarihinde birden fazla
          AKTİF kaydı varsa (eski kayıt çıkış verilmeden yeni yere açılmışsa),
          o kişi iki departmanda birden sayılır ve genel toplam ŞİŞER.

   Mantık: Temiz transfer = eski kayıt kapanır (Ict dolu), yeni kayıt açılır.
           Bu sorgu 0 satır döndürürse özet rapor güvenlidir.
           Satır dönerse: ilgili TC'lerin transfer kaydı elden düzeltilmeli
           (eski kayda çıkış tarihi girilmeli).

   Sunucu : zirve  |  View: dbo.vw_PersonelDepartman
   Tarih  : 03.06.2026
   Not    : Yerel tarih = DMY (CONVERT 104). yyyy-MM-dd KULLANMA.
   ============================================================================ */

DECLARE @GirilenTarih   DATE = '2026-06-01';                       -- bu yıl snapshot
DECLARE @OncekiYilTarih DATE = DATEADD(YEAR, -1, @GirilenTarih);   -- geçen yıl snapshot

/* --- Çift aktif kayıt taşıyan TC'ler (her iki dönem için) --- */
WITH CiftKayit AS (
    SELECT 'Bu_Yil' AS Donem, d.Vatno
    FROM dbo.vw_PersonelDepartman d
    WHERE (d.Ict >= @GirilenTarih OR d.Ict IS NULL)
      AND d.Igt <= @GirilenTarih
    GROUP BY d.Vatno
    HAVING COUNT(*) > 1
    UNION ALL
    SELECT 'Gecen_Yil' AS Donem, d.Vatno
    FROM dbo.vw_PersonelDepartman d
    WHERE (d.Ict >= @OncekiYilTarih OR d.Ict IS NULL)
      AND d.Igt <= @OncekiYilTarih
    GROUP BY d.Vatno
    HAVING COUNT(*) > 1
)
SELECT
    ck.Donem,
    d.Vatno              AS [Tc Kimlik No],
    d.AdSoyad            AS [Ad Soyad],
    d.Lokasyon,
    d.AltLokasyon        AS [Alt Lokasyon],
    d.Departman,
    d.Unvan,
    CONVERT(varchar, d.Igt, 104) AS [İşe Giriş],
    CONVERT(varchar, d.Ict, 104) AS [İşten Çıkış]
FROM CiftKayit ck
JOIN dbo.vw_PersonelDepartman d
     ON d.Vatno = ck.Vatno
    AND (
            (ck.Donem = 'Bu_Yil'
                 AND (d.Ict >= @GirilenTarih   OR d.Ict IS NULL) AND d.Igt <= @GirilenTarih)
         OR (ck.Donem = 'Gecen_Yil'
                 AND (d.Ict >= @OncekiYilTarih OR d.Ict IS NULL) AND d.Igt <= @OncekiYilTarih)
        )
ORDER BY ck.Donem, d.Vatno, d.Igt;
