using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Sınav Okulları paneli — plan-35 B-155. Salt-okuma (erp-write-policy.md).
/// Çekirdek sorgular <c>sorgular/2026-08-19-sinav-*.sql</c> (7 dosya, canlı doğrulanmış);
/// bu sınıf dashboard EMITTER'ıdır — iş mantığı burada ÇOĞALTILMAZ (emitter-ayrimi.md).
///
/// ZORUNLU KURALLAR (2026-08-19 keşif dersleri):
/// • <b>3-parçalı isim</b> — <c>Db.OpenAsync()</c> varsayılan katalog master; 2-parçalı isim Err 208.
/// • <b>KDV hariç = TotalPrice − VatTotal</b> — TotalPrice KDV DAHİL ve indirim sonrasıdır.
/// • <b>İade sign'ı</b> — <c>DocumentsTypeId=3</c> negatif; her tutar kolonunda uygulanır.
/// • <b>@donemId PARAMETRE</b> — hardcode 8 dönem 7'nin 8.998 fişini görünmez yapar.
/// • <b>SiparisDetay fan-out</b> — (SiparisId, StokId) çoklu satır riski → <c>OUTER APPLY TOP 1</c>.
/// • <b>FE→Siparis dönem filtresi EXISTS ile</b> — JOIN fan-out yapabilir.
/// • <b>DISTINCT Sales.Id</b> — FE'de aynı InvoiceNo birden çok satırda olabilir (9338 satır / 9319 fiş).
/// • <b>Tutar kaynağı SinavUrun.Fiyat</b> — <c>SiparisDetay.BirimFiyat</c> pratikte NULL.
/// </summary>
public sealed class SinavQueries(Db db, ILogger<SinavQueries> logger)
{
    /// <summary>İst.Yolu mağazası — Sınav Okulları operasyonu Ağu-2024'te FSM'den buraya taşındı.</summary>
    private const int MekanIstYolu = 4478;

    // SATIŞ tarafı FE üstünden, İADE tarafı Sales.LinkedDocumentId üstünden.
    // Gerekçe: FE tablosu kısmi iadeleri kaydetmiyor (%43 kayıp) → iadeyi FE'den sayarsak
    // net ciro olduğundan yüksek çıkar. Dönem 8 kanıtı: FE 5 iade / LinkedDocumentId 6 iade.
    // Fis CTE'de type 3 HARİÇ tutulur, yoksa FE-içi iadeler iki kez sayılır.
    private const string FisCte = """
        WITH Fis AS (
            SELECT DISTINCT S.Id, S.GrossTotal, S.DiscountTotal, S.VatTotal
            FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
                 JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
            WHERE S.DocumentsTypeId <> 3
              AND EXISTS (SELECT 1 FROM BKM.snv.Siparis sip WITH(NOLOCK)
                          WHERE sip.SiparisKod = FE.SiparisKod
                            AND (@donemId IS NULL OR sip.DonemId = @donemId))
        ),
        Iade AS (
            SELECT DISTINCT I.Id, I.GrossTotal, I.DiscountTotal, I.VatTotal
            FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)
                 JOIN EncoreMerkez.dbo.Sales O WITH(NOLOCK)
                      ON O.Id = I.LinkedDocumentId AND O.DocumentsTypeId = 8
                 JOIN BKM.snv.SinavSiparisFisEncore FEO WITH(NOLOCK) ON FEO.InvoiceNo = O.DocumentNo
            WHERE I.DocumentsTypeId = 3
              AND EXISTS (SELECT 1 FROM BKM.snv.Siparis sip WITH(NOLOCK)
                          WHERE sip.SiparisKod = FEO.SiparisKod
                            AND (@donemId IS NULL OR sip.DonemId = @donemId))
        )
        """;

    // Kova/attach için TEK fiş kümesi: satış FE'den + iade LinkedDocumentId'den, işaretli.
    // KPI ile aynı kapsam → kova toplamı KPI net cirosuna BİREBİR eşit olur (sayfada iki farklı
    // "ciro" çıkmasın). Yalnız FE'ye dayanmak FE-dışı kısmi iadeyi kaçırır: dönem 8'de 9.228,00 ₺ fark.
    private const string FisSetCte = """
        WITH FisSet AS (
            SELECT DISTINCT S.Id, FE.SiparisKod, CONVERT(int, 1) AS Isaret
            FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
                 JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
            WHERE S.DocumentsTypeId <> 3
              AND EXISTS (SELECT 1 FROM BKM.snv.Siparis sip WITH(NOLOCK)
                          WHERE sip.SiparisKod = FE.SiparisKod
                            AND (@donemId IS NULL OR sip.DonemId = @donemId))
            UNION
            SELECT DISTINCT I.Id, FEO.SiparisKod, CONVERT(int, -1) AS Isaret
            FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)
                 JOIN EncoreMerkez.dbo.Sales O WITH(NOLOCK)
                      ON O.Id = I.LinkedDocumentId AND O.DocumentsTypeId = 8
                 JOIN BKM.snv.SinavSiparisFisEncore FEO WITH(NOLOCK) ON FEO.InvoiceNo = O.DocumentNo
            WHERE I.DocumentsTypeId = 3
              AND EXISTS (SELECT 1 FROM BKM.snv.Siparis sip WITH(NOLOCK)
                          WHERE sip.SiparisKod = FEO.SiparisKod
                            AND (@donemId IS NULL OR sip.DonemId = @donemId))
        ),
        Kalemler AS (
            SELECT F.Id, F.Isaret,
                   CASE WHEN sd.StokId IS NOT NULL    THEN 'PAKET'
                        WHEN U.urnKtgr2ID IN (13, 18) THEN 'KIYAFET'
                        ELSE                               'YAN' END AS Kova,
                   SP.Amount                          * F.Isaret AS Adet,
                   SP.TotalPrice                      * F.Isaret AS NetKdvDahil,
                   SP.VatTotal                        * F.Isaret AS Kdv,
                  (SP.TotalPrice - SP.VatTotal)       * F.Isaret AS NetKdvHaric
            FROM FisSet F
                 JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = F.Id AND SP.IsValid = 1
                 JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
                 LEFT JOIN DerinSISBkm.dbo.urn U        WITH(NOLOCK) ON U.stkID = PR.Code
                 OUTER APPLY (
                    SELECT TOP 1 sd2.StokId
                    FROM BKM.snv.Siparis sip2 WITH(NOLOCK)
                         JOIN BKM.snv.SiparisDetay sd2 WITH(NOLOCK) ON sd2.SiparisId = sip2.SiparisId
                    WHERE sip2.SiparisKod = F.SiparisKod
                      AND sd2.StokId = U.stkID
                      AND (@donemId IS NULL OR sip2.DonemId = @donemId)) sd
        )
        """;

    /// <summary>Dönem listesi (dropdown). Sipariş sayısı + tarih aralığı ile.</summary>
    public async Task<IReadOnlyList<SinavDonem>> GetDonemlerAsync()
    {
        const string sql = """
            SELECT sip.DonemId, COUNT(*) AS Siparis,
                   MIN(sip.Tarih) AS Ilk, MAX(sip.Tarih) AS Son
            FROM BKM.snv.Siparis sip WITH(NOLOCK)
            WHERE sip.DonemId IS NOT NULL
            GROUP BY sip.DonemId
            ORDER BY sip.DonemId DESC;
            """;
        await using var c = await db.OpenAsync();
        return (await c.QueryAsync<SinavDonem>(sql)).AsList();
    }

    /// <summary>Sezon KPI şeridi — ciro / sipariş / sepet / iade / kısmi. Tutarlar KDV hariç.</summary>
    public async Task<SinavSezonKpi> GetSezonKpiAsync(int? donemId)
    {
        var sql = $"""
            {FisCte},
            Kalem AS (
                SELECT sip.SiparisId,
                       CONVERT(int, ISNULL(sip.Odendi,0)) AS Flag,
                       SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0) = 1 THEN 1 ELSE 0 END) AS Odenmis,
                       SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0) = 0
                                 AND ISNULL(sd.Iptal,0) = 0 THEN 1 ELSE 0 END)          AS Odenmemis
                FROM BKM.snv.Siparis sip WITH(NOLOCK)
                     JOIN BKM.snv.SiparisDetay sd WITH(NOLOCK) ON sd.SiparisId = sip.SiparisId
                WHERE (@donemId IS NULL OR sip.DonemId = @donemId)
                GROUP BY sip.SiparisId, CONVERT(int, ISNULL(sip.Odendi,0))
            )
            SELECT
                (SELECT COUNT(*) FROM BKM.snv.Siparis s2 WITH(NOLOCK)
                 WHERE (@donemId IS NULL OR s2.DonemId = @donemId))                          AS Siparis,
                (SELECT COUNT(*) FROM Fis)                                                   AS SatisFis,
                (SELECT COUNT(*) FROM Iade)                                                  AS IadeFis,
                (SELECT ISNULL(SUM(GrossTotal),0)    FROM Fis)                               AS BrutKdvDahil,
                (SELECT ISNULL(SUM(DiscountTotal),0) FROM Fis)                               AS Indirim,
                  (SELECT ISNULL(SUM(GrossTotal - DiscountTotal),0) FROM Fis)
                - (SELECT ISNULL(SUM(GrossTotal - DiscountTotal),0) FROM Iade)               AS NetKdvDahil,
                  (SELECT ISNULL(SUM(VatTotal),0) FROM Fis)
                - (SELECT ISNULL(SUM(VatTotal),0) FROM Iade)                                 AS Kdv,
                  (SELECT ISNULL(SUM(GrossTotal - DiscountTotal - VatTotal),0) FROM Fis)
                - (SELECT ISNULL(SUM(GrossTotal - DiscountTotal - VatTotal),0) FROM Iade)    AS NetKdvHaric,
                (SELECT ISNULL(SUM(GrossTotal - DiscountTotal - VatTotal),0) FROM Iade)      AS IadeKdvHaric,
                (SELECT COUNT(*) FROM Kalem WHERE Odenmis > 0 AND Odenmemis > 0)             AS KismiSiparis,
                (SELECT COUNT(*) FROM Kalem
                 WHERE (Flag = 1 AND Odenmemis > 0)
                    OR (Flag = 0 AND Odenmemis = 0 AND Odenmis > 0))                         AS CeliskiSiparis;
            """;
        await using var c = await db.OpenAsync();
        var kpi = await c.QuerySingleAsync<SinavSezonKpi>(new CommandDefinition(sql, new { donemId }));
        logger.LogInformation("Sınav KPI (dönem {D}): {S} sipariş · net {N:N0} ₺ KDV hariç · {K} kısmi · {C} çelişki",
            donemId?.ToString() ?? "TÜM", kpi.Siparis, kpi.NetKdvHaric, kpi.KismiSiparis, kpi.CeliskiSiparis);
        return kpi;
    }

    /// <summary>Ödeme sağlık kartı — TAM / KISMİ / HİÇ dağılımı + flag denetimi.</summary>
    public async Task<IReadOnlyList<SinavOdemeDurum>> GetOdemeDurumAsync(int? donemId)
    {
        const string sql = """
            SELECT T.Durum,
                   COUNT(*)                                              AS Siparis,
                   SUM(T.Kalem)                                          AS Kalem,
                   SUM(T.Odenmemis)                                      AS OdenmemisKalem,
                   SUM(CASE WHEN T.Flag = 1 THEN 1 ELSE 0 END)           AS FlagOdendi,
                   CONVERT(decimal(18,2), ISNULL(SUM(T.NetKdvHaric),0))  AS NetKdvHaric
            FROM (
                SELECT sip.SiparisId,
                       CONVERT(int, ISNULL(sip.Odendi,0)) AS Flag,
                       K.Kalem, K.Odenmis, K.Odenmemis,
                       CASE WHEN K.Odenmis   = 0 THEN 'HIC_ODENMEDI'
                            WHEN K.Odenmemis = 0 THEN 'TAM_ODENDI'
                            ELSE                      'KISMI_ODENDI' END AS Durum,
                       X.NetKdvHaric
                FROM BKM.snv.Siparis sip WITH(NOLOCK)
                     CROSS APPLY (
                        SELECT COUNT(*) AS Kalem,
                               SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0) = 1 THEN 1 ELSE 0 END) AS Odenmis,
                               SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0) = 0
                                         AND ISNULL(sd.Iptal,0) = 0 THEN 1 ELSE 0 END)          AS Odenmemis
                        FROM BKM.snv.SiparisDetay sd WITH(NOLOCK)
                        WHERE sd.SiparisId = sip.SiparisId) K
                     OUTER APPLY (
                        SELECT SUM(CASE WHEN S.DocumentsTypeId = 3
                                        THEN -(S.GrossTotal - S.DiscountTotal - S.VatTotal)
                                        ELSE  (S.GrossTotal - S.DiscountTotal - S.VatTotal) END) AS NetKdvHaric
                        FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
                             JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
                        WHERE FE.SiparisKod = sip.SiparisKod) X
                WHERE (@donemId IS NULL OR sip.DonemId = @donemId)
                  AND K.Kalem > 0
            ) T
            GROUP BY T.Durum;
            """;
        await using var c = await db.OpenAsync();
        return (await c.QueryAsync<SinavOdemeDurum>(new CommandDefinition(sql, new { donemId }))).AsList();
    }

    /// <summary>Eksik kalem tahsilat listesi. Tutar <c>SinavUrun.Fiyat</c>, stok İst.Yolu (tedarik/tahsilat ayrımı).
    /// KVKK: öğrenci ADI/TELEFONU çekilmez — kampüs + sınıf + SiparisKod ile aksiyon alınır.</summary>
    public async Task<IReadOnlyList<SinavEksikKalem>> GetEksikKalemAsync(int? donemId, bool kismiSadece = true, int top = 500)
    {
        var sql = $"""
            SELECT TOP (@top)
                   sip.SiparisKod, sip.Tarih AS SiparisTarih,
                   ISNULL(ok.OkulAd,'')  AS Kampus,
                   ISNULL(ok.Ilce,'')    AS Ilce,
                   ISNULL(sn.SinifAd,'') AS Sinif,
                   ISNULL(sip.OgrenciId,0) AS OgrenciId,
                   K.Kalem, K.Odenmis AS OdenmisKalem, K.Odenmemis AS OdenmemisKalem,
                   ISNULL(sd.StokId,0)   AS StokId,
                   ISNULL(su.StokAd, ISNULL(U.stkAd,'')) AS Urun,
                   ISNULL(su.Kategori, ISNULL(k2.ktgrAd,'')) AS Kategori,
                   ISNULL(sd.Adet,0)     AS Adet,
                   CONVERT(decimal(18,2), ISNULL(su.Fiyat,0))  AS BirimFiyat,
                   CONVERT(decimal(18,2), ISNULL(st.stok,0))   AS StokIstYolu
            FROM BKM.snv.Siparis sip WITH(NOLOCK)
                 JOIN BKM.snv.SiparisDetay sd WITH(NOLOCK) ON sd.SiparisId = sip.SiparisId
                 CROSS APPLY (
                    SELECT COUNT(*) AS Kalem,
                           SUM(CASE WHEN ISNULL(sd2.OdemesiYapildi,0) = 1 THEN 1 ELSE 0 END) AS Odenmis,
                           SUM(CASE WHEN ISNULL(sd2.OdemesiYapildi,0) = 0
                                     AND ISNULL(sd2.Iptal,0) = 0 THEN 1 ELSE 0 END)          AS Odenmemis
                    FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                    WHERE sd2.SiparisId = sip.SiparisId) K
                 LEFT JOIN BKM.snv.Okul ok         WITH(NOLOCK) ON ok.OkulId  = sip.OkulId
                 LEFT JOIN BKM.snv.Sinif sn        WITH(NOLOCK) ON sn.SinifId = sip.SinifId
                 LEFT JOIN BKM.snv.SinavUrun su    WITH(NOLOCK) ON su.StokId  = sd.StokId
                 LEFT JOIN DerinSISBkm.dbo.urn U   WITH(NOLOCK) ON U.stkID    = sd.StokId
                 LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
                 LEFT JOIN DerinSISBkm.dbo.stokSon_vw st WITH(NOLOCK)
                        ON st.ehstkID = sd.StokId AND st.ehMekan = {MekanIstYolu}
            WHERE (@donemId IS NULL OR sip.DonemId = @donemId)
              AND ISNULL(sd.OdemesiYapildi,0) = 0
              AND ISNULL(sd.Iptal,0) = 0
              AND (@kismiSadece = 0 OR K.Odenmis > 0)
            ORDER BY (ISNULL(sd.Adet,0) * ISNULL(su.Fiyat,0)) DESC, sip.SiparisKod;
            """;
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<SinavEksikKalem>(
            new CommandDefinition(sql, new { donemId, kismiSadece = kismiSadece ? 1 : 0, top }))).AsList();
        logger.LogInformation("Sınav eksik kalem (dönem {D}): {N} kalem · {T:N2} ₺",
            donemId?.ToString() ?? "TÜM", rows.Count, rows.Sum(r => r.Tutar));
        return rows;
    }

    /// <summary>Sepet kovası — Paket / Kıyafet / Yan. Ayraç sipariş kapsamı (SiparisDetay), kategori değil.</summary>
    public async Task<IReadOnlyList<SinavKova>> GetKovaAsync(int? donemId)
    {
        var sql = $"""
            {FisSetCte}
            SELECT Kova,
                   COUNT(*)                                                AS Satir,
                   CONVERT(decimal(18,2), SUM(Adet))                       AS Adet,
                   CONVERT(decimal(18,2), SUM(NetKdvDahil))                AS NetKdvDahil,
                   CONVERT(decimal(18,2), SUM(Kdv))                        AS Kdv,
                   CONVERT(decimal(18,2), SUM(NetKdvHaric))                AS NetKdvHaric,
                   CONVERT(decimal(12,2), 100.0 * SUM(NetKdvHaric)
                           / NULLIF(SUM(SUM(NetKdvHaric)) OVER (), 0))     AS PayYuzde
            FROM Kalemler
            GROUP BY Kova;
            """;
        await using var c = await db.OpenAsync();
        return (await c.QueryAsync<SinavKova>(new CommandDefinition(sql, new { donemId }))).AsList();
    }

    /// <summary>Yan ürün attach özeti — kaç fişte sipariş dışı ürün eklenmiş, fiş başı ek ciro.</summary>
    public async Task<SinavAttach> GetAttachAsync(int? donemId)
    {
        var sql = $"""
            {FisSetCte}
            SELECT COUNT(*)                                                 AS Fis,
                   SUM(CASE WHEN T.Yan     > 0.02 THEN 1 ELSE 0 END)        AS YanUrunluFis,
                   SUM(CASE WHEN T.Kiyafet > 0.02 THEN 1 ELSE 0 END)        AS KiyafetliFis,
                   CONVERT(decimal(18,2), ISNULL(SUM(T.Yan),0))             AS YanKdvHaric,
                   CONVERT(decimal(18,2), ISNULL(SUM(T.Kiyafet),0))         AS KiyafetKdvHaric,
                   CONVERT(decimal(18,2), ISNULL(SUM(T.Toplam),0))          AS ToplamKdvHaric
            FROM (
                SELECT Id,
                       SUM(CASE WHEN Kova = 'YAN'     THEN NetKdvHaric ELSE 0 END) AS Yan,
                       SUM(CASE WHEN Kova = 'KIYAFET' THEN NetKdvHaric ELSE 0 END) AS Kiyafet,
                       SUM(NetKdvHaric)                                            AS Toplam
                FROM Kalemler
                GROUP BY Id
            ) T;
            """;
        await using var c = await db.OpenAsync();
        return await c.QuerySingleAsync<SinavAttach>(new CommandDefinition(sql, new { donemId }));
    }

    /// <summary>İade radarı — <c>Sales.LinkedDocumentId</c> zinciri. FE tablosu kısmi iadeleri kaçırır,
    /// bu yüzden köprü LinkedDocumentId. Kasa düzeltmesi / gerçek iade ayrımı modelde hesaplanır.</summary>
    public async Task<IReadOnlyList<SinavIade>> GetIadeAsync(int? donemId, int top = 300)
    {
        const string sql = """
            SELECT TOP (@top)
                   I.Id                                       AS IadeFisId,
                   I.Date                                     AS IadeTarih,
                   I.DocumentNo                               AS IadeBelgeNo,
                   ISNULL(I.ClosureNo,'')                     AS Zno,
                   ISNULL(PSI.SerialNumber,'')                AS Kasa,
                   I.StoresId                                 AS Magaza,
                   O.Id                                       AS OrijinalFisId,
                   O.Date                                     AS OrijinalTarih,
                   ISNULL(O.ClosureNo,'')                     AS Zno_Orijinal,
                   ISNULL(FEO.SiparisKod,'')                  AS SiparisKod,
                   DATEDIFF(day, O.Date, I.Date)              AS GunFarki,
                   CASE WHEN FEI.InvoiceNo IS NOT NULL THEN 'FE içinde' ELSE 'FE dışında' END AS FeDurumu,
                   CONVERT(decimal(18,2), I.GrossTotal - I.DiscountTotal - I.VatTotal) AS IadeKdvHaric,
                   CONVERT(decimal(18,2), O.GrossTotal - O.DiscountTotal)              AS OrijinalKdvDahil,
                   CASE WHEN ABS((I.GrossTotal - I.DiscountTotal)
                               - (O.GrossTotal - O.DiscountTotal)) < 0.02
                        THEN 'TAM' ELSE 'KISMİ' END           AS IadeTipi
            FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)
                 JOIN EncoreMerkez.dbo.Sales O WITH(NOLOCK)
                      ON O.Id = I.LinkedDocumentId AND O.DocumentsTypeId = 8
                 LEFT JOIN EncoreMerkez.dbo.Pos PSI WITH(NOLOCK) ON PSI.Id = I.PosId
                 LEFT JOIN BKM.snv.SinavSiparisFisEncore FEI WITH(NOLOCK) ON FEI.InvoiceNo = I.DocumentNo
                 LEFT JOIN BKM.snv.SinavSiparisFisEncore FEO WITH(NOLOCK) ON FEO.InvoiceNo = O.DocumentNo
            WHERE I.DocumentsTypeId = 3
              AND (@donemId IS NULL
                   OR EXISTS (SELECT 1 FROM BKM.snv.Siparis sip WITH(NOLOCK)
                              WHERE sip.SiparisKod = FEO.SiparisKod AND sip.DonemId = @donemId))
            ORDER BY I.Date DESC;
            """;
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<SinavIade>(new CommandDefinition(sql, new { donemId, top }))).AsList();
        logger.LogInformation("Sınav iade (dönem {D}): {N} iade fişi · {T:N2} ₺ KDV hariç",
            donemId?.ToString() ?? "TÜM", rows.Count, rows.Sum(r => r.IadeKdvHaric));
        return rows;
    }
}
