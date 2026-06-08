/* ============================================================================
   HEADCOUNT HAREKET KÖPRÜSÜ (Bridge)
   ----------------------------------------------------------------------------
   Sunucu : zirve  |  View: dbo.vw_PersonelDepartman
   Tarih  : 03.06.2026  |  Yerel tarih = DMY (CONVERT 104)

   Ne yapar: Her ay için  Dönem Başı + Giren − Çıkan = Dönem Sonu  köprüsünü
             kurar. Özet rapordaki "headcount neden değişti" sorusunun cevabı.

   Tanımlar:
     Dönem Başı = ay başından ÖNCE girmiş ve ay başında hâlâ aktif olanlar
     Giren      = o ay içinde işe girenler (Igt o ayda)
     Çıkan      = o ay içinde çıkanlar (Ict o ayda)
     Dönem Sonu = Dönem Başı + Giren − Çıkan  (kontrol: anlık sayımla eşleşmeli)
   Not: Aynı kişinin iç transferi (çıkış+giriş aynı ay) hem Giren hem Çıkan
        sayılır; net etki 0. Firma/lokasyon kırılımı istenirse GROUP BY'a eklenir.
   ============================================================================ */

DECLARE @Bas DATE = '2025-06-01';   -- ilk ay (ayın 1'i)
DECLARE @AySayisi INT = 13;         -- kaç ay listelensin

;WITH Aylar AS (
    SELECT @Bas AS AyBasi, 1 AS n
    UNION ALL
    SELECT DATEADD(MONTH, 1, AyBasi), n + 1 FROM Aylar WHERE n < @AySayisi
),
Hesap AS (
    SELECT
        a.AyBasi,
        DonemBasi = (SELECT COUNT(*) FROM dbo.vw_PersonelDepartman p
                       WHERE p.Igt < a.AyBasi
                         AND (p.Ict IS NULL OR p.Ict >= a.AyBasi)),
        Giren     = (SELECT COUNT(*) FROM dbo.vw_PersonelDepartman p
                       WHERE p.Igt >= a.AyBasi
                         AND p.Igt < DATEADD(MONTH,1,a.AyBasi)),
        Cikan     = (SELECT COUNT(*) FROM dbo.vw_PersonelDepartman p
                       WHERE p.Ict >= a.AyBasi
                         AND p.Ict < DATEADD(MONTH,1,a.AyBasi))
    FROM Aylar a
)
SELECT
    CONVERT(varchar(7), AyBasi, 126)        AS Ay,
    DonemBasi                                AS [Dönem Başı],
    Giren                                    AS [Giren (+)],
    Cikan                                    AS [Çıkan (-)],
    DonemBasi + Giren - Cikan                AS [Dönem Sonu],
    Giren - Cikan                            AS [Net Değişim]
FROM Hesap
ORDER BY AyBasi
OPTION (MAXRECURSION 1000);
