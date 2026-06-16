using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>Sadakat / müşteri tutma sorguları — /sadakat sayfası (Faz 3).</summary>
public sealed class SadakatQueries(Db db, IcKartService icKart)
{
    /// <summary>Win-back listesi — son 365g aktif ama son 90g yok, frekans≥3, ciro≥500. Aksiyon listesi.</summary>
    public async Task<IReadOnlyList<WinBackRow>> GetWinBackAsync()
    {
        await using var conn = await db.OpenAsync();
        var icIds = icKart.Idler();
        var icF = IcKartFiltre.Sql("s.CustomersId", icIds.Length > 0);   // tek kanonik iç-kart filtresi (plan-18)
        var rows = await conn.QueryAsync<WinBackRow>($"""
            SELECT TOP 200
                LTRIM(c.Name)        AS Ad,
                c.PhoneNumber        AS Tel,
                c.CardNumber         AS Kart,
                COUNT(s.Id)          AS Frq,
                SUM(CASE WHEN s.DocumentsTypeId=3
                    THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                    ELSE   s.GrossTotal-s.DiscountTotal-s.VatTotal END) AS ToplCiro,
                DATEDIFF(DAY, MAX(s.Date), GETDATE()) AS GunIdle
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id = s.CustomersId
            WHERE s.DocumentsTypeId IN (1,3)
              AND s.CustomersId > 0{icF}
              AND s.Date >= DATEADD(DAY,-365,CAST(GETDATE() AS date))
              AND s.Date < DATEADD(DAY,-90,CAST(GETDATE() AS date))
            GROUP BY c.Name, c.PhoneNumber, c.CardNumber
            HAVING COUNT(s.Id) >= 3
               AND SUM(CASE WHEN s.DocumentsTypeId=3
                   THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                   ELSE   s.GrossTotal-s.DiscountTotal-s.VatTotal END) >= 500
            ORDER BY ToplCiro DESC
            """, new { icIds }, commandTimeout: 30);
        return rows.ToList();
    }

    /// <summary>Pareto dilim tablosu — son 12 ay, 10 dilim (%10'ar), hangisi ne kadar ciro tutuyor.</summary>
    public async Task<IReadOnlyList<ParetoRow>> GetParetoAsync()
    {
        await using var conn = await db.OpenAsync();
        var icIds = icKart.Idler();
        var icF = IcKartFiltre.Sql("s.CustomersId", icIds.Length > 0);   // tek kanonik iç-kart filtresi (plan-18)
        var rows = await conn.QueryAsync<ParetoRow>($"""
            SELECT TOP 10
                CAST(dilim.dilim AS int) AS Dilim,
                COUNT(*)      AS MusteriSayisi,
                SUM(dilim.Mon) AS ToplamCiro
            FROM (
                SELECT s.CustomersId,
                    SUM(CASE WHEN s.DocumentsTypeId=3
                        THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                        ELSE   s.GrossTotal-s.DiscountTotal-s.VatTotal END) AS Mon,
                    NTILE(10) OVER (ORDER BY
                        SUM(CASE WHEN s.DocumentsTypeId=3
                            THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                            ELSE   s.GrossTotal-s.DiscountTotal-s.VatTotal END) DESC) AS dilim
                FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                WHERE s.DocumentsTypeId IN (1,3) AND s.CustomersId > 0{icF}
                  AND s.Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date))
                GROUP BY s.CustomersId
            ) dilim
            GROUP BY dilim.dilim
            ORDER BY dilim.dilim
            """, new { icIds }, commandTimeout: 30);
        return rows.ToList();
    }

    /// <summary>RFM segment geçiş matrisi — 3-6 ay önceki segment → bugünkü segment (B-67).</summary>
    public async Task<IReadOnlyList<RfmGecisRow>> GetRfmGecisAsync()
    {
        await using var conn = await db.OpenAsync();
        var icIds = icKart.Idler();
        var f = IcKartFiltre.Sql("s.CustomersId", icIds.Length > 0);   // tek kanonik iç-kart filtresi (plan-18)
        // Kayan pencere (M-11): sabit tarih yerine bugüne göre. seg1 = bugün-3ay ankrajlı 12 ay, seg2 = bugün ankrajlı 12 ay.
        var rows = await conn.QueryAsync<RfmGecisRow>($"""
            DECLARE @bugun date = CAST(GETDATE() AS date);
            DECLARE @anchor1 date = DATEADD(MONTH,-3,@bugun);
            SELECT TOP 36 seg1.S AS EskiSeg, seg2.S AS YeniSeg, COUNT(*) AS Musteri
            FROM (
                SELECT s.CustomersId,
                    CAST(CASE WHEN COUNT(*)>=8 AND DATEDIFF(DAY,MAX(s.Date),@anchor1)<=30 THEN N'1-Şampiyon'
                         WHEN COUNT(*)>=4 AND DATEDIFF(DAY,MAX(s.Date),@anchor1)<=90 THEN N'2-Sadık'
                         WHEN COUNT(*)<=2 AND DATEDIFF(DAY,MAX(s.Date),@anchor1)<=30 THEN N'3-Yeni'
                         WHEN DATEDIFF(DAY,MAX(s.Date),@anchor1) BETWEEN 91 AND 180 THEN N'4-Risk'
                         WHEN DATEDIFF(DAY,MAX(s.Date),@anchor1)>180 THEN N'5-Kayıp'
                         ELSE N'6-Diğer' END AS nvarchar(20)) S
                FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                WHERE s.DocumentsTypeId = 1 AND s.CustomersId > 0{f}
                  AND s.Date >= DATEADD(MONTH,-12,@anchor1) AND s.Date < @anchor1
                GROUP BY s.CustomersId
            ) seg1
            JOIN (
                SELECT s.CustomersId,
                    CAST(CASE WHEN COUNT(*)>=8 AND DATEDIFF(DAY,MAX(s.Date),@bugun)<=30 THEN N'1-Şampiyon'
                         WHEN COUNT(*)>=4 AND DATEDIFF(DAY,MAX(s.Date),@bugun)<=90 THEN N'2-Sadık'
                         WHEN COUNT(*)<=2 AND DATEDIFF(DAY,MAX(s.Date),@bugun)<=30 THEN N'3-Yeni'
                         WHEN DATEDIFF(DAY,MAX(s.Date),@bugun) BETWEEN 91 AND 180 THEN N'4-Risk'
                         WHEN DATEDIFF(DAY,MAX(s.Date),@bugun)>180 THEN N'5-Kayıp'
                         ELSE N'6-Diğer' END AS nvarchar(20)) S
                FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                WHERE s.DocumentsTypeId = 1 AND s.CustomersId > 0{f}
                  AND s.Date >= DATEADD(MONTH,-12,@bugun) AND s.Date < DATEADD(DAY,1,@bugun)
                GROUP BY s.CustomersId
            ) seg2 ON seg2.CustomersId = seg1.CustomersId
            GROUP BY seg1.S, seg2.S
            ORDER BY Musteri DESC
            """, new { icIds }, commandTimeout: 30);
        return rows.ToList();
    }

    /// <summary>Tekrar alış özeti — B-58 (Frq>1 oranı) + B-71 (ortalama 2. alış günü). Son 12 ay.</summary>
    public async Task<TekrarAlisOzet> GetTekrarAlisAsync()
    {
        await using var conn = await db.OpenAsync();
        var icIds = icKart.Idler();
        var fb = IcKartFiltre.Sql("CustomersId", icIds.Length > 0);       // çıplak alias (alt-sorgu) — plan-18
        var fs = IcKartFiltre.Sql("sal.CustomersId", icIds.Length > 0);   // sal alias
        var r = await conn.QuerySingleAsync<TekrarAlisOzet>($"""
            SELECT
                COUNT(DISTINCT s.CustomersId) AS ToplamMusteri,
                COUNT(DISTINCT CASE WHEN frq.Frq >= 2 THEN s.CustomersId END) AS TekrarMusteri,
                CAST(ISNULL(AVG(CAST(DATEDIFF(DAY, s.IlkTarih, ikinci.IkinciTarih) AS float)), 0) AS decimal(5,0)) AS OrtGun2Alis
            FROM (
                SELECT CustomersId, MIN(Date) AS IlkTarih
                FROM EncoreMerkez.dbo.Sales WITH(NOLOCK)
                WHERE DocumentsTypeId = 1 AND CustomersId > 0{fb}
                  AND Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date))
                GROUP BY CustomersId
            ) s
            LEFT JOIN (
                SELECT CustomersId, COUNT(*) AS Frq
                FROM EncoreMerkez.dbo.Sales WITH(NOLOCK)
                WHERE DocumentsTypeId = 1 AND CustomersId > 0{fb}
                  AND Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date))
                GROUP BY CustomersId
            ) frq ON frq.CustomersId = s.CustomersId
            LEFT JOIN (
                SELECT sal.CustomersId, MIN(sal.Date) AS IkinciTarih
                FROM EncoreMerkez.dbo.Sales sal WITH(NOLOCK)
                JOIN (
                    SELECT CustomersId, MIN(Date) AS IlkTarih
                    FROM EncoreMerkez.dbo.Sales WITH(NOLOCK)
                    WHERE DocumentsTypeId = 1 AND CustomersId > 0{fb}
                      AND Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date))
                    GROUP BY CustomersId
                ) ilk ON ilk.CustomersId = sal.CustomersId AND sal.Date > ilk.IlkTarih
                WHERE sal.DocumentsTypeId = 1 AND sal.CustomersId > 0{fs}
                GROUP BY sal.CustomersId
            ) ikinci ON ikinci.CustomersId = s.CustomersId
            """, new { icIds }, commandTimeout: 30);
        return r;
    }

    /// <summary>
    /// Sadakat kartı etkisi — kartlı vs kartsız FİŞ karşılaştırması (son 12 ay). B-102:
    /// SADECE perakende (Fiş=1 + iade=3) — Fatura/Sınav/Personel HARİÇ (Sınav 8 kartsızı 266M şişiriyordu).
    /// Kartsız = anonim (CustomersId=0) DAHİL — gerçek kartsız çoğunluk. Metrik: sepet/fiş (ATV per fiş).
    /// </summary>
    public async Task<IReadOnlyList<KartliRow>> GetKartliAsync()
    {
        await using var conn = await db.OpenAsync();
        var icIds = icKart.Idler();
        // icF: iç-kart (Mağaza/Kumbara/599/699/elle) hariç; CustomersId=0 anonim NOT IN'lerden GEÇER → kartsıza düşer.
        var icF = IcKartFiltre.Sql("s.CustomersId", icIds.Length > 0);
        var rows = await conn.QueryAsync<KartliRow>($"""
            SELECT TOP 2
                CASE WHEN s.CustomersId>0 AND ISNULL(c.CardNumber,'')<>'' THEN 'Kartlı' ELSE 'Kartsız' END AS Tip,
                COUNT(*) AS FisSayisi,
                COUNT(DISTINCT CASE WHEN s.CustomersId>0 THEN s.CustomersId END) AS Musteri,
                SUM(CASE WHEN s.DocumentsTypeId=3
                    THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                    ELSE   s.GrossTotal-s.DiscountTotal-s.VatTotal END) AS NetCiro,
                CAST(
                    SUM(CASE WHEN s.DocumentsTypeId=3
                        THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                        ELSE   s.GrossTotal-s.DiscountTotal-s.VatTotal END)
                    / NULLIF(COUNT(*), 0)
                AS decimal(12,0)) AS AtvFis
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            LEFT JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id = s.CustomersId
            WHERE s.DocumentsTypeId IN (1,3)
              AND s.Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date)){icF}
            GROUP BY CASE WHEN s.CustomersId>0 AND ISNULL(c.CardNumber,'')<>'' THEN 'Kartlı' ELSE 'Kartsız' END
            ORDER BY Tip
            """, new { icIds }, commandTimeout: 30);
        return rows.ToList();
    }
}
