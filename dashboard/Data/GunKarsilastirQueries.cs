using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// GÜN KARŞILAŞTIRMA — iki günü mağaza bazında yan yana koyar (ciro + müşteri sayısı).
///
/// Doğuş sebebi 12.09.2026 (GMY isteği): <i>"geçen yıl okul açılışı öncesi hafta sonu mağaza
/// bazlı cumartesi pazar cirosu lazım, bugün de İstanbul Yolu Sınav ve Sınav hariç ciro"</i>
/// → ardından <i>"aynısını altına müşteri sayısı olarak yap"</i> · <i>"iade hiç düşme"</i>
/// · <i>"bunu gmdashboard'a ekler misin"</i>.
/// Excel ikizi: <c>scripts/hafta_sonu_magaza_ciro_excel.py</c> (aynı iş mantığı, aynı süzgeçler).
///
/// ═══ KAYNAK: EncoreMerkez (KASA), ERP DEĞİL ════════════════════════════════════
/// Kanal ayrımı (Sınav) YALNIZ belge tipinden yapılabilir ve o EncoreMerkez'dedir.
/// DerinSIS <c>irsHrk</c>'da <c>eTip 100</c> günlük ÖZET belgedir, belge-bazlı ayrım YAPILAMAZ
/// (<c>sql-server-conventions.md</c> § KANAL AYRACI).
/// ⚠ 3-parçalı isim zorunlu: app <c>master</c> bağlamında açılıyor.
///
/// ═══ CİRO TABANI — PROJENİN VARSAYILANINDAN İKİ SAPMA (ikisi de GMY direktifi) ══
/// 1. <b>KDV DAHİL</b> (<c>GrossTotal − DiscountTotal</c>). Panel ve öteki raporlar CFO
///    direktifiyle (plan-16) KDV HARİÇ çalışır → bu bölümün rakamı ötekilerle TUTMAZ.
///    KDV hariç karşılığı da dönülüyor ki kıyas mümkün olsun.
/// 2. <b>İADE KAYNAĞINA YAZILIR</b> (<i>"iadeyi düşsen iyi olur ama ilgili yerden düşmen
///    lazım"</i>). Sınav iadesi Sınav'dan, perakende iadesi perakendeden düşülür; kanalı
///    çözülemeyen iade HİÇBİR yerden düşülmez ve ayrı gösterilir. Ayrıntı: <c>Sql</c> özeti.
/// Ekranda ikisi de YAZILI — okuyan hangi tabanda olduğunu görmeden rakamı kullanmasın.
///
/// ═══ SAAT KESİMİ — kapanmamış günü tam günle kıyaslama ═════════════════════════
/// Bugün seçiliyken tam günle kıyas YANILTIR. <paramref name="kesimDk"/> verilirse iki gün de
/// aynı dakikaya kadar toplanır. ÖLÇÜLDÜ 12.09.2026 (İst.Yolu): günün %88,4'ü (Sınav) /
/// %81,2'si (perakende) 20:10'dan önce gerçekleşmiş, mağaza 22:35'te kapanmış.
///
/// ⚠ MÜŞTERİ SAYISI = FİŞ SAYISI (tip 1). <b>Tekil müşteri DEĞİL</b>: kartsız satışta
/// <c>CustomersId = 0</c> (anonim sentinel) ve tekil sayım kartsızın tamamını tek müşteriye
/// indirir (<c>sql-server-conventions.md</c> § SIFIR SENTINEL).
///
/// ⚠ İade kanalının <b>tutarca %3,7'si çözülemiyor</b> — o kısım hiçbir kanaldan düşülmez,
/// <c>IadeBelirsiz</c> alanında durur ve ekranda gösterilir. Sessizce perakendeye yazmak tam
/// da düzeltilen hatadır. (Belge SAYISININ yarısı çözülemiyor ama materyalite TUTARLA okunur.)
///
/// ⚠ Kasa→ERP aktarımı SAATTE BİR (sema <c>entities:kasa_erp_aktarim_tazeligi</c>) — gün içinde
/// ERP eksiktir. Bu bölüm KASA tarafından okuduğu için gün içi doğru sayıyı gösterir.
/// </summary>
public sealed class GunKarsilastirQueries(Db db)
{
    /// <summary>
    /// Belge tipleri: 1 Fiş · 2 Fatura · 3 İade(−) · 6 Personel Fiş · 7 Personel Fatura · 8 Sınav.
    ///
    /// ⭐ İADE KAYNAĞINA YAZILIR (GMY direktifi 12.09.2026: <i>"iadeyi düşsen iyi olur ama
    /// İLGİLİ YERDEN düşmen lazım"</i>). İade belgesi kanal taşımaz; kanalı <b>bağlı belgenin
    /// tipinden</b> okuyoruz (<c>LinkedDocumentId → Sales.DocumentsTypeId</c>).
    ///
    /// ÖLÇÜLDÜ (İst.Yolu, 06-07.09.2025 + 12.09.2026) — iade tutarının dağılımı:
    ///   kaynak tip 8 (Sınav)  31 belge · <b>967.472 ₺</b>  ← iadenin %90'ı
    ///   kaynak tip 1 (Fiş)    44 belge ·    62.794 ₺
    ///   kaynak tip 2 (Fatura)  2 belge ·     4.885 ₺
    ///   kaynağı YOK           95 belge ·    39.267 ₺  ← tutarın yalnız %3,7'si
    /// ⇒ Tüm iadeyi perakendeden düşmek perakende cirosunu <b>1,07M ₺</b> eksiltiyordu;
    ///   günlük perakende ~1,5M olduğu için bu devasa bir sapmaydı.
    /// ⚠ Belge SAYISININ yarısı çözülemiyor ama TUTARIN %96,3'ü çözülüyor — "yarısı boş"
    ///   ifadesi para açısından yanıltıcıdır, materyalite belge değil tutar üzerinden okunur.
    ///
    /// Kaynağı çözülemeyen iade HİÇBİR kanaldan düşülmez; <c>IadeBelirsiz</c> alanında ayrı
    /// durur ve ekranda gösterilir (sessizce perakendeye yazmak tam da düzeltilen hatadır).
    /// </summary>
    private const string Sql = """
        WITH b AS (
            SELECT st.Name AS Magaza, s.DocumentsTypeId AS Tip,
                   (s.GrossTotal - s.DiscountTotal)              AS Dahil,
                   (s.GrossTotal - s.DiscountTotal - s.VatTotal) AS Haric,
                   CASE WHEN s.DocumentsTypeId = 8 THEN 'S'
                        WHEN s.DocumentsTypeId <> 3 THEN 'P'
                        -- ⚠ Sınav iadesi ancak KAYNAK BELGE AYNI MAĞAZADAYSA Sınav'dan düşülür.
                        -- GMY kararı 12.09.2026: "Özlüce'de kesilirse Özlüce normal ciro olmalı".
                        -- Ölçüldü: Özlüce'de kaynağı Sınav olan iade var (06.09 −2.651 ₺).
                        WHEN o.DocumentsTypeId = 8 AND o.StoresId = s.StoresId THEN 'S'
                        WHEN o.Id IS NULL          THEN 'X'
                        ELSE 'P' END AS Kanal
            FROM EncoreMerkez.dbo.Sales s WITH (NOLOCK)
            JOIN EncoreMerkez.dbo.Stores st WITH (NOLOCK) ON st.Id = s.StoresId
            LEFT JOIN EncoreMerkez.dbo.Sales o WITH (NOLOCK)
                   ON o.Id = s.LinkedDocumentId AND s.LinkedDocumentId > 0
            WHERE s.Date >= @bas AND s.Date < @bit
              AND s.DocumentsTypeId IN (1,2,3,6,7,8)
              AND DATEPART(HOUR, s.Date) * 60 + DATEPART(MINUTE, s.Date) < @kesimDk
        )
        SELECT Magaza,
               SUM(CASE WHEN Tip = 1 THEN 1 ELSE 0 END) AS Fis,
               SUM(CASE WHEN Tip = 8 THEN 1 ELSE 0 END) AS SinavBelge,
               SUM(CASE WHEN Tip = 3 THEN 1 ELSE 0 END) AS IadeBelge,
               CONVERT(decimal(18,2), SUM(CASE WHEN Kanal <> 'P' THEN 0
                    WHEN Tip = 3 THEN -Dahil ELSE Dahil END))            AS PerakendeDahil,
               CONVERT(decimal(18,2), SUM(CASE WHEN Kanal <> 'S' THEN 0
                    WHEN Tip = 3 THEN -Dahil ELSE Dahil END))            AS SinavDahil,
               CONVERT(decimal(18,2), SUM(CASE WHEN Kanal <> 'P' THEN 0
                    WHEN Tip = 3 THEN -Haric ELSE Haric END))            AS PerakendeHaric,
               CONVERT(decimal(18,2), SUM(CASE WHEN Kanal <> 'S' THEN 0
                    WHEN Tip = 3 THEN -Haric ELSE Haric END))            AS SinavHaric,
               CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 3 AND Kanal = 'P'
                    THEN Dahil ELSE 0 END))                              AS IadePerakende,
               CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 3 AND Kanal = 'S'
                    THEN Dahil ELSE 0 END))                              AS IadeSinav,
               CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 3 AND Kanal = 'X'
                    THEN Dahil ELSE 0 END))                              AS IadeBelirsiz
        FROM b GROUP BY Magaza ORDER BY Magaza
        """;

    /// <summary>
    /// İki günü mağaza bazında getirir. <paramref name="kesimDk"/> null ise gün tamamı
    /// (1440). Kapanmamış gün seçiliyse çağıran tarafın kesim vermesi beklenir.
    /// </summary>
    public async Task<GunKarsilastirSonuc> GetirAsync(
        DateOnly gun, DateOnly kiyasGun, int? kesimDk = null, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync();
        var dk = kesimDk ?? 24 * 60;

        async Task<IReadOnlyList<GunMagazaSatir>> Cek(DateOnly g)
        {
            var p = new DynamicParameters();
            p.Add("bas", g.ToDateTime(TimeOnly.MinValue));
            p.Add("bit", g.AddDays(1).ToDateTime(TimeOnly.MinValue));
            p.Add("kesimDk", dk);
            var r = await conn.QueryAsync<GunMagazaSatir>(
                new CommandDefinition(Sql, p, commandTimeout: 120, cancellationToken: ct));
            return r.ToList();
        }

        return new GunKarsilastirSonuc(gun, kiyasGun, dk, await Cek(gun), await Cek(kiyasGun));
    }

    /// <summary>
    /// Kapanmamış gün için kesim dakikası = ŞU ANKİ saat. Gün geçmişteyse null (tam gün).
    /// ⚠ Sunucu saati kullanılıyor; kasa ile aynı makinede değil ama aynı yerel saat dilimi.
    /// </summary>
    public static int? BugunIcinKesim(DateOnly gun)
        => gun == DateOnly.FromDateTime(DateTime.Now)
            ? DateTime.Now.Hour * 60 + DateTime.Now.Minute
            : null;
}
