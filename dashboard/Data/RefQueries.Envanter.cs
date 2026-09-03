using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

// RefQueries partial (M-13 file-size split) — envanter/ürün/ops/marj/marka/hediye-çeki sorguları.
// Müşteri/RFM + drill RefQueries.cs'te. Aynı sınıf (partial) → DI + çağıran DEĞİŞMEZ. Primary-ctor (db/logger/icKart) + EXC const paylaşılır.
public sealed partial class RefQueries
{
    /// <summary>Kategori → ürün drill. Satış/Ciro = SEÇİLİ DÖNEM + mağaza (mekanId=0 → 3 mağaza toplam).
    /// KAYNAK: EncoreMerkez POS (kategori kartı/katSql ile AYNI → kart=drill tutarlı). Ciro = KDV DAHİL net
    /// (IIF DocType=3 iade negatif). Bakiye = güncel stok (irsHrk tüm geçmiş ehAdetN, mağaza bazlı).
    /// (14.06 mutabakat: irsHrk KDV-hariç olduğu için drill irsHrk'den EncoreMerkez'e alındı — sema encore_irshrk_mutabakat.)</summary>
    /// <param name="olusSort">true = ölü stok sıralaması (stok/S90 oranı büyük önce); false = satış miktarı büyük önce.</param>
    public async Task<IReadOnlyList<UrunRow>> GetUrunlerAsync(string kategori, int mekanId, DateOnly start, DateOnly endExcl, bool olusSort = false)
    {
        await using var conn = await db.OpenAsync();
        // Bakiye mekan=0: 3 mağaza (FSM/Özl/İst) + merkez depo. ODAK hesaba dahil değil.
        // S30/S90/S360 = bugünden geriye trailing pencere (dönemden bağımsız).
        var having = olusSort
            ? "ISNULL(MAX(stk.Fsm),0)+ISNULL(MAX(stk.Ozl),0)+ISNULL(MAX(stk.Ist),0)+ISNULL(MAX(wms.Depo),0) > 0 AND DATEDIFF(DAY, MAX(u.gTarih), GETDATE()) >= 90"
            : "SUM(CASE WHEN s.Date>=@start AND s.Date<@end THEN sg.v*sp.Amount ELSE 0 END)>0";
        var orderBy = olusSort
            ? "CASE WHEN SUM(CASE WHEN s.Date>=@d90 THEN sg.v*sp.Amount ELSE 0 END)=0 THEN 999999 ELSE CAST(ISNULL(MAX(stk.Fsm),0)+ISNULL(MAX(stk.Ozl),0)+ISNULL(MAX(stk.Ist),0)+ISNULL(MAX(wms.Depo),0) AS float)/SUM(CASE WHEN s.Date>=@d90 THEN sg.v*sp.Amount ELSE 0 END) END DESC"
            : "Satis DESC";
        var sql = $"""
            SELECT TOP 100 u.stkID AS StkId, u.stkKod AS Kod, CAST(u.stkAd AS nvarchar(80)) AS Ad,
                CAST(SUM(CASE WHEN s.Date>=@start AND s.Date<@end THEN sg.v*sp.Amount ELSE 0 END) AS int) AS Satis,
                CAST(SUM(CASE WHEN s.Date>=@start AND s.Date<@end THEN sg.v*(sp.TotalPrice-sp.VatTotal) ELSE 0 END) AS decimal(18,0)) AS Ciro,
                CAST(CASE @mekan WHEN 1 THEN ISNULL(MAX(stk.Fsm),0) WHEN 4477 THEN ISNULL(MAX(stk.Ozl),0) WHEN 4478 THEN ISNULL(MAX(stk.Ist),0)
                     ELSE ISNULL(MAX(stk.Fsm),0)+ISNULL(MAX(stk.Ozl),0)+ISNULL(MAX(stk.Ist),0)+ISNULL(MAX(wms.Depo),0) END AS int) AS Bakiye,
                CAST(SUM(CASE WHEN s.Date>=@d30 THEN sg.v*sp.Amount ELSE 0 END) AS int) AS S30,
                CAST(SUM(CASE WHEN s.Date>=@d90 THEN sg.v*sp.Amount ELSE 0 END) AS int) AS S90,
                CAST(SUM(CASE WHEN s.Date>=@d360 THEN sg.v*sp.Amount ELSE 0 END) AS int) AS S360,
                CAST(ISNULL(MAX(stk.Fsm),0) AS int) AS StokFsm,
                CAST(ISNULL(MAX(stk.Ozl),0) AS int) AS StokOzl,
                CAST(ISNULL(MAX(stk.Ist),0) AS int) AS StokIst,
                CAST(ISNULL(MAX(wms.Depo),0) AS int) AS StokDepo,
                CAST(ISNULL(MAX(od.StokMiktar),0) AS int) AS StokOdak,
                CAST(DATEDIFF(DAY, MAX(u.gTarih), GETDATE()) AS int) AS YasGun
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            CROSS APPLY (SELECT CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END AS v) sg
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
            JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=CONVERT(int,pr.Code)
            JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID=u.urnKtgr2ID AND k.ktgrAd=@kat
            LEFT JOIN (SELECT v.ehstkID AS sID,
                           SUM(CASE WHEN v.ehMekan=1 THEN v.stok ELSE 0 END) AS Fsm,
                           SUM(CASE WHEN v.ehMekan=4477 THEN v.stok ELSE 0 END) AS Ozl,
                           SUM(CASE WHEN v.ehMekan=4478 THEN v.stok ELSE 0 END) AS Ist
                       FROM DerinSISBkm.dbo.stokSonAltDepo_vw v
                       WHERE v.ehAltDepo=0 AND v.ehMekan IN ({LokasyonConfig.Subeler})
                       GROUP BY v.ehstkID) stk ON stk.sID=u.stkID
            LEFT JOIN (SELECT pu.pUStkID AS sID, SUM(pu.pUAdetN) AS Depo
                       FROM DerinSISBkm.depo.paletUrnTnm pu
                         JOIN DerinSISBkm.depo.paletTnm pt ON pt.pID=pu.pUID
                         JOIN DerinSISBkm.depo.adres a ON a.adrsID=pt.pSonPozID
                       WHERE pu.pUAdetN>0 AND a.adrsAd NOT IN ('CK01') AND pu.pUID NOT IN ('42560','20353')
                       GROUP BY pu.pUStkID) wms ON wms.sID=u.stkID
            LEFT JOIN DerinSISBkm.ent.odak_depo_Stok od WITH(NOLOCK) ON od.stkID=u.stkID
            WHERE MG.mekanID IN ({LokasyonConfig.Subeler}) AND (@mekan=0 OR MG.mekanID=@mekan)
                AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(pr.Code)=1
                AND s.Date>=@minDate AND s.Date<@maxDate
            GROUP BY u.stkID, u.stkKod, CAST(u.stkAd AS nvarchar(80))
            HAVING {having}
            ORDER BY {orderBy};
            """;
        var today = DateTime.Today;
        var pStart = start.ToDateTime(TimeOnly.MinValue);
        var pEnd = endExcl.ToDateTime(TimeOnly.MinValue);
        var d90 = today.AddDays(-90);
        var d360 = today.AddDays(-360);
        var tom = today.AddDays(1);
        // Ölü stok modu sadece S90 + güncel stok ister → 360g yerine 90g tara (POS scan 4× küçülür).
        var lower = olusSort ? d90 : d360;
        return (await conn.QueryAsync<UrunRow>(sql, new
        {
            kat = kategori,
            mekan = mekanId,
            start = pStart,
            end = pEnd,
            d30 = today.AddDays(-30),
            d90,
            d360,
            minDate = pStart < lower ? pStart : lower,   // ölü stok: 90g, normal: dönem + trailing 360g
            maxDate = pEnd > tom ? pEnd : tom,
        })).ToList();
    }

    /// <summary>Ciro-vs-envanter scatter (cve port). Kategori: Mayıs irsHrk ciro vs ENVANTER_RAPORU 3 mağaza değer.</summary>
    public async Task<IReadOnlyList<CveRow>> GetCveAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        var ayBas = new DateOnly(dun.Year, dun.Month, 1).AddMonths(-1);
        var aySon = new DateOnly(dun.Year, dun.Month, 1);
        var p = new { ayBas = ayBas.ToDateTime(TimeOnly.MinValue), aySon = aySon.ToDateTime(TimeOnly.MinValue) };

        // Ciro (irsHrk, geçen ay, 3 mağaza) — envanterle aynı stkID kaynağı
        var ciro = (await conn.QueryAsync<(string K, decimal Ciro)>($"""
            SELECT CAST(k.ktgrAd AS nvarchar(50)) K,
                   CAST(SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN WHEN h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS decimal(18,0)) Ciro
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
            WHERE h.ehTrhS>=@ayBas AND h.ehTrhS<@aySon AND h.ehMekan IN ({LokasyonConfig.Subeler}) AND h.ehAltDepo=0 AND h.ehTip IN (4,100,3,5,101)
                  AND k.ktgrAd NOT IN {EXC}
            GROUP BY CAST(k.ktgrAd AS nvarchar(50));
            """, p)).ToDictionary(x => x.K, x => x.Ciro, StringComparer.OrdinalIgnoreCase);

        // Envanter değeri (son snapshot, 3 mağaza)
        var env = (await conn.QueryAsync<(string K, decimal V)>($"""
            SELECT CAST(KTGR3 AS nvarchar(50)) K,
                   CAST(SUM([FSM Stok Maliyet]+[Özlüce Stok Maliyet]+[İst.Yolu Stok Maliyet]) AS decimal(18,0)) V
            FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
            WHERE Tarih=(SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU) AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN {EXC}
            GROUP BY CAST(KTGR3 AS nvarchar(50));
            """)).ToList();

        var rows = new List<CveRow>();
        foreach (var e in env)
        {
            var c = ciro.GetValueOrDefault(e.K, 0m);
            if (e.V > 0 || c > 0) rows.Add(new CveRow(e.K, c, e.V));
        }
        return rows.OrderByDescending(r => r.Ciro).ToList();
    }

    /// <summary>Operasyon ek: SPLH (PDKS OPENQUERY, son 30g) + COD (olgun 60g pencere).</summary>
    public async Task<OpsData> GetOpsAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        var d30 = dun.AddDays(-29).ToString("yyyyMMdd");
        var g2iso = dun.AddDays(1).ToString("yyyyMMdd");

        // SPLH — PDKS linked server düşerse boş liste (panel "veri yok" gösterir)
        var splh = new List<SplhRow>();
        try
        {
            var sql = $$"""
                SELECT lab.Magaza, cir.NetCiro, cir.Fis, lab.CalisilanSaat AS Saat, lab.Personel
                FROM (SELECT Magaza, CalisilanSaat, Personel FROM OPENQUERY([PDKS], '
                    SELECT LTRIM(RTRIM(p.Per_Grp2)) AS Magaza,
                      CAST(SUM(DATEDIFF(MINUTE, z.TZe_VonZeit, z.TZe_BisZeit))/60.0 AS decimal(18,1)) AS CalisilanSaat,
                      COUNT(DISTINCT z.TZe_PersNr) AS Personel
                    FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
                    WHERE z.TZe_Datum >= ''{{d30}}'' AND z.TZe_Datum <= ''{{g2iso}}''
                      AND p.Per_Grp1 = ''MAĞAZALAR'' AND LTRIM(RTRIM(p.Per_Grp2)) IN (''FSM'',''ÖZLÜCE'',''İST.YOLU'')
                      AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL
                    GROUP BY LTRIM(RTRIM(p.Per_Grp2))')) lab
                JOIN (SELECT CASE MG.mekanID WHEN 1 THEN N'FSM' WHEN 4477 THEN N'ÖZLÜCE' WHEN 4478 THEN N'İST.YOLU' END Magaza,
                    SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) NetCiro, SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) Fis
                  FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                  JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id=s.PosId
                  JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id=p.StoreId
                  JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK) ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
                  LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK) ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
                  WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>='{{d30}}' AND s.Date<'{{g2iso}}' AND spb.Id IS NULL
                  GROUP BY MG.mekanID) cir ON cir.Magaza COLLATE Turkish_CI_AS=lab.Magaza COLLATE Turkish_CI_AS;
                """;
            splh = (await conn.QueryAsync<SplhRow>(sql)).OrderByDescending(s => s.Saat > 0 ? s.NetCiro / s.Saat : 0).ToList();
        }
        catch (Exception ex) { logger.LogWarning(ex, "SPLH (PDKS OPENQUERY) alınamadı — işgücü paneli boş gösterilecek"); }  // B-85: sessiz değil

        // COD — olgun pencere (75→15 gün önce; son 15 gün kargo süreci bitmemiş hariç)
        var codB = dun.AddDays(-75).ToString("yyyyMMdd");
        var codE = dun.AddDays(-15).ToString("yyyyMMdd");
        var cod = (await conn.QueryAsync<CodRow>("""
            SELECT CASE WHEN o.PAYDEFREF=-3 THEN 'COD' ELSE 'Online' END AS Tip, COUNT(*) AS Siparis,
                   SUM(CASE WHEN o.CARGODELIVERYSTATUS=1 THEN 1 ELSE 0 END) AS Teslim,
                   SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END) AS Iade
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.PAYDEFREF IN (-3,-13) AND o.ORDERDATE>=@b AND o.ORDERDATE<@e
            GROUP BY CASE WHEN o.PAYDEFREF=-3 THEN 'COD' ELSE 'Online' END;
            """, new { b = codB, e = codE })).ToList();
        var zarar = await conn.ExecuteScalarAsync<decimal?>("""
            SELECT CAST(SUM(o.CARGOPRICE)*2 AS decimal(18,0)) FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.PAYDEFREF=-3 AND o.CARGODELIVERYSTATUS=2 AND o.ORDERDATE>=@b AND o.ORDERDATE<@e;
            """, new { b = codB, e = codE }) ?? 0m;

        return new OpsData(splh, cod, zarar);
    }

    /// <summary>Depo WMS anlık durum: bugün tamamlanan toplama + son 14g günlük trend.</summary>
    public async Task<DepoWmsData> GetDepoWmsAsync()
    {
        await using var conn = await db.OpenAsync();
        var bugun = await conn.QueryFirstOrDefaultAsync<DepoWmsBugun>("""
            SELECT COUNT(*) AS Islem, CAST(ISNULL(SUM(emAdetTop),0) AS int) AS Adet
            FROM DerinSISBkm.depo.emirAyr WITH(NOLOCK)
            WHERE emTamam=1 AND CAST(emTarih AS date)=CAST(GETDATE() AS date)
            HAVING COUNT(*) > 0
            """);
        var trend = (await conn.QueryAsync<DepoWmsTrend>("""
            SELECT CAST(emTarih AS date) AS Gun, COUNT(*) AS Islem, CAST(SUM(emAdetTop) AS int) AS Adet
            FROM DerinSISBkm.depo.emirAyr WITH(NOLOCK)
            WHERE emTamam=1 AND emTarih>=DATEADD(DAY,-13,CAST(GETDATE() AS date))
            GROUP BY CAST(emTarih AS date)
            """)).OrderBy(t => t.Gun).ToList();
        return new DepoWmsData(bugun?.Islem, bugun?.Adet, trend);
    }

    /// <summary>Hediye çeki yükümlülük özeti — son 12 ay aylık satılan (POS) vs kullanılan (ödeme).</summary>
    public async Task<HcOzet> GetHediyeCekiAsync()
    {
        await using var conn = await db.OpenAsync();
        var satilan = (await conn.QueryAsync<HcAyRaw>("""
            SELECT LEFT(CONVERT(varchar(10), s.Date, 23), 7) AS Ay,
                SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp2.TotalPrice-sp2.VatTotal) ELSE (sp2.TotalPrice-sp2.VatTotal) END) AS Tutar
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.SalesProducts sp2 WITH(NOLOCK) ON sp2.SalesId = s.Id AND sp2.IsValid=1
            JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp2.ProductsId
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CONVERT(int, p.Code)
            JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
            WHERE k2.ktgrAd = 'Hediye Çeki'
              AND s.DocumentsTypeId IN (1,2,3,6,7,8)
              AND s.Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date))
              AND ISNUMERIC(p.Code) = 1
            GROUP BY LEFT(CONVERT(varchar(10), s.Date, 23), 7)
            """)).ToDictionary(r => r.Ay, r => r.Tutar);

        var kullanilan = (await conn.QueryAsync<HcAyRaw>("""
            SELECT LEFT(CONVERT(varchar(10), s.Date, 23), 7) AS Ay,
                SUM(pt.Amount) AS Tutar
            FROM EncoreMerkez.dbo.SalesPayments pt WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = pt.SalesId
            WHERE pt.PaymentTypesId = 11
              AND pt.IsChangeAmount = 0
              AND s.DocumentsTypeId IN (1,2,6,7,8)
              AND s.Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date))
            GROUP BY LEFT(CONVERT(varchar(10), s.Date, 23), 7)
            """)).ToDictionary(r => r.Ay, r => r.Tutar);

        var aylar = satilan.Keys.Union(kullanilan.Keys)
            .OrderByDescending(a => a)
            .Select(a => new HcAyRow(a,
                satilan.GetValueOrDefault(a, 0),
                kullanilan.GetValueOrDefault(a, 0)))
            .ToList();

        return new HcOzet(
            aylar.Sum(a => a.SatilanTL),
            aylar.Sum(a => a.KullanilanTL),
            aylar);
    }

    // Ölü stok SQL şablonu: S90=0 + Bakiye>0 + YasGun>=90, tüm kategoriler, ort.maliyet × adet ≈ stok değeri
    // OFFSET/FETCH: SQL 2012+ (EncoreMerkez değil DerinSIS, compat 110 kısıtı yok)
    private string OluStokSql(string orderAndPage) => $"""
        SELECT u.stkID AS StkId, u.stkKod AS Kod, CAST(u.stkAd AS nvarchar(80)) AS Ad,
            CAST(k.ktgrAd AS nvarchar(50)) AS Kategori,
            CAST(ISNULL(stk.Fsm,0)+ISNULL(stk.Ozl,0)+ISNULL(stk.Ist,0)+ISNULL(wms.Depo,0) AS int) AS Bakiye,
            CAST(ISNULL(stk.Fsm,0) AS int) AS StokFsm,
            CAST(ISNULL(stk.Ozl,0) AS int) AS StokOzl,
            CAST(ISNULL(stk.Ist,0) AS int) AS StokIst,
            CAST(ISNULL(wms.Depo,0) AS int) AS StokDepo,
            CAST(COALESCE(fat5.Maliyet, ml.ORT_ALIS, CASE WHEN u.fiyatS > 0 THEN u.fiyatS * avgml.AvgCostOran END) AS decimal(18,2)) AS OrtMaliyet,
            CAST((ISNULL(stk.Fsm,0)+ISNULL(stk.Ozl,0)+ISNULL(stk.Ist,0)+ISNULL(wms.Depo,0)) * COALESCE(fat5.Maliyet, ml.ORT_ALIS, CASE WHEN u.fiyatS > 0 THEN u.fiyatS * avgml.AvgCostOran END) AS decimal(18,0)) AS StokTl,
            CAST(DATEDIFF(DAY, u.gTarih, GETDATE()) AS int) AS YasGun
        FROM DerinSISBkm.dbo.urn u WITH(NOLOCK)
        JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID=u.urnKtgr2ID
        LEFT JOIN (SELECT v.ehstkID AS sID,
                       SUM(CASE WHEN v.ehMekan=1    THEN v.stok ELSE 0 END) AS Fsm,
                       SUM(CASE WHEN v.ehMekan=4477  THEN v.stok ELSE 0 END) AS Ozl,
                       SUM(CASE WHEN v.ehMekan=4478  THEN v.stok ELSE 0 END) AS Ist
                   FROM DerinSISBkm.dbo.stokSonAltDepo_vw v
                   WHERE v.ehAltDepo=0 AND v.ehMekan IN ({LokasyonConfig.Subeler})
                   GROUP BY v.ehstkID) stk ON stk.sID=u.stkID
        LEFT JOIN (SELECT pu.pUStkID AS sID, SUM(pu.pUAdetN) AS Depo
                   FROM DerinSISBkm.depo.paletUrnTnm pu
                     JOIN DerinSISBkm.depo.paletTnm pt ON pt.pID=pu.pUID
                     JOIN DerinSISBkm.depo.adres a ON a.adrsID=pt.pSonPozID
                   WHERE pu.pUAdetN>0 AND a.adrsAd NOT IN ('CK01') AND pu.pUID NOT IN ('42560','20353')
                   GROUP BY pu.pUStkID) wms ON wms.sID=u.stkID
        LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml WITH(NOLOCK) ON ml.STKID=u.stkID
        LEFT JOIN (SELECT u2.urnKtgr2ID AS ktgrID,
                       AVG(CASE WHEN u2.fiyatS > 0 THEN ml2.ORT_ALIS / u2.fiyatS END) AS AvgCostOran
                   FROM Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml2 WITH(NOLOCK)
                   JOIN DerinSISBkm.dbo.urn u2 WITH(NOLOCK) ON u2.stkID=ml2.STKID
                   WHERE ml2.ORT_ALIS > 0 AND u2.fiyatS > 0 AND ml2.ORT_ALIS < u2.fiyatS
                   GROUP BY u2.urnKtgr2ID) avgml ON avgml.ktgrID=u.urnKtgr2ID
        OUTER APPLY (
            SELECT CONVERT(money, SUM(b.ehTutarN) / SUM(b.ehAdetN)) AS Maliyet
            FROM (
                SELECT TOP 5 fa.ehAdetN, fa.ehTutarN
                FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
                JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
                    AND f.eTip=0 AND f.eDurum<>2
                WHERE fa.ehstkID=u.stkID AND fa.ehAdetN<>0
                ORDER BY f.eTarih DESC
            ) b
            HAVING SUM(b.ehAdetN) <> 0
        ) fat5
        WHERE k.ktgrAd NOT IN {EXC}
          AND k.ktgrAd NOT IN (N'Sınav Okulları',N'Hediye Çeki',N'Etkinlik',N'Zkargo',N'KARGO')
          AND u.urnTip = 0
          AND u.stkID NOT IN (81809)
          AND DATEDIFF(DAY, u.gTarih, GETDATE()) >= 90
          AND (ISNULL(stk.Fsm,0)+ISNULL(stk.Ozl,0)+ISNULL(stk.Ist,0)+ISNULL(wms.Depo,0)) > 0
          AND COALESCE(fat5.Maliyet, ml.ORT_ALIS, CASE WHEN u.fiyatS > 0 THEN u.fiyatS * avgml.AvgCostOran END) > 0
          AND NOT EXISTS (
              SELECT 1 FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
              WHERE h.ehstkID=u.stkID AND h.ehTip IN (4,100) AND h.ehTrhS>=DATEADD(DAY,-90,GETDATE())
                AND h.ehMekan IN ({LokasyonConfig.Subeler}) AND h.ehAltDepo=0
          )
        {orderAndPage}
        """;

    /// <summary>Ölü stok ürün listesi sayfalı (S90=0, Bakiye>0, YasGun≥90). Stok ₺ büyük önce.</summary>
    public async Task<(IReadOnlyList<OluStokRow> Rows, int Toplam)> GetOluStokAsync(int offset, int limit = 50)
    {
        await using var conn = await db.OpenAsync();
        var sayfa = await conn.QueryAsync<OluStokRow>(OluStokSql($"ORDER BY StokTl DESC OFFSET {offset} ROWS FETCH NEXT {limit} ROWS ONLY"));
        var toplam = await conn.ExecuteScalarAsync<int>($"""
            SELECT COUNT(*) FROM DerinSISBkm.dbo.urn u WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID=u.urnKtgr2ID
            LEFT JOIN (SELECT v.ehstkID sID, SUM(v.stok) T FROM DerinSISBkm.dbo.stokSonAltDepo_vw v
                       WHERE v.ehAltDepo=0 AND v.ehMekan IN ({LokasyonConfig.Subeler}) GROUP BY v.ehstkID) stk ON stk.sID=u.stkID
            LEFT JOIN (SELECT pu.pUStkID sID, SUM(pu.pUAdetN) T FROM DerinSISBkm.depo.paletUrnTnm pu
                         JOIN DerinSISBkm.depo.paletTnm pt ON pt.pID=pu.pUID
                         JOIN DerinSISBkm.depo.adres a ON a.adrsID=pt.pSonPozID
                       WHERE pu.pUAdetN>0 AND a.adrsAd NOT IN ('CK01') AND pu.pUID NOT IN ('42560','20353')
                       GROUP BY pu.pUStkID) wms ON wms.sID=u.stkID
            LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml WITH(NOLOCK) ON ml.STKID=u.stkID
            LEFT JOIN (SELECT u2.urnKtgr2ID AS ktgrID,
                           AVG(CASE WHEN u2.fiyatS > 0 THEN ml2.ORT_ALIS / u2.fiyatS END) AS AvgCostOran
                       FROM Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml2 WITH(NOLOCK)
                       JOIN DerinSISBkm.dbo.urn u2 WITH(NOLOCK) ON u2.stkID=ml2.STKID
                       WHERE ml2.ORT_ALIS > 0 AND u2.fiyatS > 0 AND ml2.ORT_ALIS < u2.fiyatS
                       GROUP BY u2.urnKtgr2ID) avgml ON avgml.ktgrID=u.urnKtgr2ID
            OUTER APPLY (
                SELECT CONVERT(money, SUM(b.ehTutarN) / SUM(b.ehAdetN)) AS Maliyet
                FROM (
                    SELECT TOP 5 fa.ehAdetN, fa.ehTutarN
                    FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
                    JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
                        AND f.eTip=0 AND f.eDurum<>2
                    WHERE fa.ehstkID=u.stkID AND fa.ehAdetN<>0
                    ORDER BY f.eTarih DESC
                ) b
                HAVING SUM(b.ehAdetN) <> 0
            ) fat5
            WHERE k.ktgrAd NOT IN {EXC}
              AND k.ktgrAd NOT IN (N'Sınav Okulları',N'Hediye Çeki',N'Etkinlik',N'Zkargo',N'KARGO')
              AND u.urnTip = 0
              AND u.stkID NOT IN (81809)
              AND DATEDIFF(DAY, u.gTarih, GETDATE()) >= 90
              AND (ISNULL(stk.T,0)+ISNULL(wms.T,0)) > 0
              AND COALESCE(fat5.Maliyet, ml.ORT_ALIS, CASE WHEN u.fiyatS > 0 THEN u.fiyatS * avgml.AvgCostOran END) > 0
              AND NOT EXISTS (
                  SELECT 1 FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
                  WHERE h.ehstkID=u.stkID AND h.ehTip IN (4,100) AND h.ehTrhS>=DATEADD(DAY,-90,GETDATE())
                    AND h.ehMekan IN ({LokasyonConfig.Subeler}) AND h.ehAltDepo=0
              )
            """);
        return (sayfa.ToList(), toplam);
    }

    /// <summary>Ölü stok tam liste (Excel için — limit yok).</summary>
    public async Task<IEnumerable<OluStokRow>> GetOluStokTumAsync()
    {
        await using var conn = await db.OpenAsync();
        return await conn.QueryAsync<OluStokRow>(OluStokSql("ORDER BY StokTl DESC"), commandTimeout: 120);
    }

    /// <summary>Ürün stok hareket defteri — TEK birleşik liste, tarih sıralı, global yürüyen Kalan.
    /// gun>0 → tek "Devir" açılış satırı (başlangıç öncesi tüm-mekan net bakiye) + dönem hareketleri.
    /// gun=0 → devir yok, en baştan. mekan=0 → 3 şube + 12 depo birlikte; mekan seçiliyse o mekan defteri.</summary>
    public async Task<IReadOnlyList<StokHareketRow>> GetStokHareketAsync(int stkId, int gun = 30, int mekan = 0)
    {
        await using var conn = await db.OpenAsync();
        var bas = gun > 0 ? DateTime.Today.AddDays(-gun) : (DateTime?)null;

        // Devir: başlangıç öncesi TÜM-mekan (veya seçili mekan) net bakiyesi — tek değer.
        var devir = bas is null ? 0 : await conn.ExecuteScalarAsync<int?>($"""
            SELECT CAST(ISNULL(SUM(h.ehAdetN),0) AS int)
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            WHERE h.ehstkID=@stkId AND h.ehAltDepo=0 AND h.ehMekan IN ({LokasyonConfig.SubelerVeDepo})
              AND (@mekan=0 OR h.ehMekan=@mekan) AND h.ehTrhS < @bas
            """, new { stkId, mekan, bas }) ?? 0;

        // Dönem hareketleri: tarih sıralı, GLOBAL kümülatif (tüm liste boyunca tek yürüyen).
        var hrk = (await conn.QueryAsync<HareketRaw>($"""
            SELECT TOP 500
                CONVERT(varchar(10), H.ehTrhS, 104) AS Tarih,
                CAST(ISNULL(t.tipAD, CAST(H.ehTip AS nvarchar(10))) AS nvarchar(30)) AS Tip,
                CAST(ISNULL(f.frmAd, CAST(H.ehMekan AS nvarchar(10))) AS nvarchar(40)) AS Ad,
                CAST(ISNULL(ff.frmAd, '') AS nvarchar(50)) AS Firma,
                CAST(ISNULL(i.eNo, '') AS nvarchar(30)) AS Evrak,
                CAST(CASE WHEN H.ehAdetN > 0 THEN H.ehAdetN ELSE 0 END AS int) AS Giris,
                CAST(CASE WHEN H.ehAdetN < 0 THEN -H.ehAdetN ELSE 0 END AS int) AS Cikis,
                CAST(SUM(H.ehAdetN) OVER (ORDER BY H.ehTrhS, H.hrkID ROWS UNBOUNDED PRECEDING) AS int) AS DonemKum
            FROM DerinSISBkm.dbo.irsHrk H WITH(NOLOCK)
            LEFT JOIN DerinSISBkm.dbo.irs i WITH(NOLOCK) ON i.eID = H.ehID
            LEFT JOIN DerinSISBkm.dbo.frm ff WITH(NOLOCK) ON ff.frmID = i.eFirma
            LEFT JOIN DerinSISBkm.dbo.frm f WITH(NOLOCK) ON f.frmID = H.ehMekan
            LEFT JOIN DerinSISBkm.dbo.irsTip_vw t ON t.tipID = H.ehTip
            WHERE H.ehstkID=@stkId AND H.ehAltDepo=0 AND H.ehMekan IN ({LokasyonConfig.SubelerVeDepo})
              AND (@mekan=0 OR H.ehMekan=@mekan)
              AND (@gun=0 OR H.ehTrhS >= @bas)
            ORDER BY H.ehTrhS, H.hrkID
            """, new { stkId, mekan, gun, bas })).ToList();

        // Tek liste: Devir açılış satırı (varsa) + tarih sıralı hareketler. Kalan = devir + global kümülatif.
        var sonuc = new List<StokHareketRow>();
        if (bas is not null)
            sonuc.Add(new StokHareketRow("", "Devir", "", "", "", 0, 0, devir, IsDevir: true));
        foreach (var h in hrk)
            sonuc.Add(new StokHareketRow(h.Tarih, h.Tip, h.Ad, h.Firma, h.Evrak, h.Giris, h.Cikis, devir + h.DonemKum));
        return sonuc;
    }

    private record HareketRaw(string Tarih, string Tip, string Ad, string Firma, string Evrak, int Giris, int Cikis, int DonemKum);

    /// <summary>Ürün ara — barkod/stkKod (rakamsa exact, hızlı) veya ad (LIKE). urnTip=0, TOP 30. Bakiye = 3 şube+depo.</summary>
    public async Task<IReadOnlyList<UrunAraRow>> GetUrunAraAsync(string q)
    {
        q = (q ?? "").Trim();
        if (q.Length < 2) return [];
        // Barkod/kod modu: giriş tamamen rakam → index'li exact eşleşme. stkID önce alt-sorgudan toplanır
        // (OR EXISTS urn'u full tarıyordu, 5.8s → 0.14s). Metin → stkAd LIKE.
        var rakam = q.All(char.IsDigit);
        var filtre = rakam
            ? "u.stkID IN (SELECT stkID FROM DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE stkKod=@q UNION SELECT urnBrkdStkID FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK) WHERE urnBarkod=@q AND urnBrkdOnce=0)"
            : "u.stkAd LIKE @like";
        await using var conn = await db.OpenAsync();
        // Bakiye YOK (lazy) → arama hızlı; stok dağılımı/Kalan ürün seçilince defterde gelir.
        return (await conn.QueryAsync<UrunAraRow>($"""
            SELECT TOP 30 u.stkID AS StkId, u.stkKod AS Kod, CAST(u.stkAd AS nvarchar(80)) AS Ad,
                CAST(k.ktgrAd AS nvarchar(50)) AS Kategori
            FROM DerinSISBkm.dbo.urn u WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID=u.urnKtgr2ID
            WHERE u.urnTip=0 AND ({filtre})
            ORDER BY u.stkAd
            """, new { q, like = "%" + q + "%" })).ToList();
    }

    private record HcAyRaw(string Ay, decimal Tutar);
    private record DepoWmsBugun(int Islem, int Adet);

    /// <summary>Kategori brüt marj % — son 30g. KANONİK maliyet: son 5 alış faturası (satış tarihine kadar) → ORT_ALIS fallback (gece job şelalesi). ~CommandTimeout=60.</summary>
    public async Task<IReadOnlyList<MarjRow>> GetMarjAsync()
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<MarjRow>("""
            SELECT s.Kat AS Kategori,
                SUM(s.Ciro)                                            AS Ciro,
                SUM(s.Adet * COALESCE(mlyt.M5, ml.ORT_ALIS))           AS Smm,
                CAST((SUM(s.Ciro) - SUM(s.Adet * COALESCE(mlyt.M5, ml.ORT_ALIS)))
                    * 100.0 / NULLIF(SUM(s.Ciro), 0) AS decimal(5,1))  AS MarjPct
            FROM (
                -- Ürün-başı ön-agg: maliyet OUTER APPLY satır-başı yerine ürün-başı 1× çalışsın (40s→~10s).
                SELECT a.ehStkID AS stkID, CAST(k2.ktgrAd AS nvarchar(50)) AS Kat,
                       SUM(a.ehTutar - a.ehIndirim) AS Ciro, SUM(ABS(a.ehAdetN)) AS Adet
                FROM DerinSISBkm.dbo.irs i WITH(NOLOCK)
                JOIN DerinSISBkm.dbo.irsAyr a WITH(NOLOCK) ON a.ehID = i.eID
                JOIN DerinSISBkm.dbo.urn u  WITH(NOLOCK) ON u.stkID = a.ehStkID
                JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
                WHERE i.eTip IN (1,4,100)
                  AND i.eTarih >= DATEADD(DAY,-30,CAST(GETDATE() AS smalldatetime))
                  AND i.eMekan IN (12,1,4478,4477)
                GROUP BY a.ehStkID, CAST(k2.ktgrAd AS nvarchar(50))
            ) s
            OUTER APPLY (
                SELECT CONVERT(money, SUM(b.ehTutarN)/SUM(b.ehAdetN)) AS M5
                FROM (SELECT TOP 5 fa.ehAdetN, fa.ehTutarN
                      FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
                        JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID AND f.eTip=0 AND f.eDurum<>2
                      WHERE fa.ehStkID=s.stkID AND fa.ehAdetN<>0 ORDER BY f.eTarih DESC) b
                HAVING SUM(b.ehAdetN)<>0
            ) mlyt
            LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml WITH(NOLOCK) ON ml.STKID = s.stkID
            WHERE COALESCE(mlyt.M5, ml.ORT_ALIS) IS NOT NULL
            GROUP BY s.Kat
            HAVING SUM(s.Ciro) > 0
            """, commandTimeout: 60);
        // Maliyet kapsaması düşük kategorileri filtrele (SMM/Ciro < %5 veya > %95 = veri yok)
        return rows.Where(r => r.MarjPct is >= 5 and <= 95).OrderByDescending(r => r.MarjPct).ToList();
    }

    /// <summary>Marka alış-vs-satış dengesi — geçen tam ay, top-30 satış adedine göre.</summary>
    public async Task<IReadOnlyList<MarkaRotasyonRow>> GetMarkaRotasyonAsync(DateOnly ayBas, DateOnly ayBit)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<MarkaRotasyonRow>($"""
            SELECT TOP 30 m.mrkAd AS Marka,
                CAST(-SUM(CASE WHEN a.ehTip IN (4,100,3,5,101) THEN a.ehAdetN ELSE 0 END) AS int) AS SatisAdet,
                CAST(SUM(CASE WHEN a.ehTip IN (0,10)  THEN ABS(a.ehAdetN) ELSE 0 END) AS int) AS AlisAdet,
                SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehTutarN WHEN a.ehTip IN (3,5,101) THEN -a.ehTutarN ELSE 0 END) AS SatisCiro
            FROM DerinSISBkm.dbo.irsHrk a WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = a.ehstkID
            JOIN DerinSISBkm.dbo.urnMrk m WITH(NOLOCK) ON m.mrkID = u.urnMrkID
            WHERE a.ehTrhS >= @Bas AND a.ehTrhS < @Bit
              AND a.ehMekan IN ({LokasyonConfig.SubelerVeDepo})
            GROUP BY m.mrkAd
            HAVING SUM(CASE WHEN a.ehTip IN (4,100) THEN ABS(a.ehAdetN) ELSE 0 END) > 0
            ORDER BY SatisAdet DESC
            """, new
        {
            Bas = new DateTime(ayBas.Year, ayBas.Month, ayBas.Day),
            Bit = new DateTime(ayBit.Year, ayBit.Month, ayBit.Day),
        });
        return rows.ToList();
    }

    /// <summary>Tedarikçi/yayınevi performans scorecard (B-110) — son 12 ay marka bazlı:
    /// net ciro · iade oranı · stok devir hızı (yıllık satış adet / anlık stok adet) → "sipariş-kes" sinyali.
    /// İç-operasyon + ev-markası (Markasız/Sınav/BKM) hariç; satış adet ≥ 50 eşiği gürültü filtresi.
    /// Satış agregatı + stok agregatı AYRI derived-table, mrkID'de JOIN (satır-başı OUTER APPLY timeout tuzağından kaçınır).</summary>
    public async Task<IReadOnlyList<TedarikciPerfRow>> GetTedarikciPerformansAsync(DateOnly bas, IReadOnlyList<int> haricMrk)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<TedarikciPerfRow>($"""
            SELECT TOP 30 sv.Marka, sv.SatisAdet, sv.IadeAdet, sv.NetCiro, sv.SatisBrut, sv.IadeTutar,
                CAST(ISNULL(st.StokAdet, 0) AS int) AS StokAdet
            FROM (
                SELECT m.mrkID, m.mrkAd AS Marka,
                    CAST(-SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehAdetN ELSE 0 END) AS int) AS SatisAdet,
                    CAST(SUM(CASE WHEN a.ehTip IN (3,5,101) THEN a.ehAdetN ELSE 0 END) AS int) AS IadeAdet,
                    SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehTutarN WHEN a.ehTip IN (3,5,101) THEN -a.ehTutarN ELSE 0 END) AS NetCiro,
                    SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehTutarN ELSE 0 END) AS SatisBrut,
                    SUM(CASE WHEN a.ehTip IN (3,5,101) THEN a.ehTutarN ELSE 0 END) AS IadeTutar
                FROM DerinSISBkm.dbo.irsHrk a WITH(NOLOCK)
                JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = a.ehstkID
                JOIN DerinSISBkm.dbo.urnMrk m WITH(NOLOCK) ON m.mrkID = u.urnMrkID
                WHERE a.ehTrhS >= @Bas AND a.ehMekan IN ({LokasyonConfig.SubelerVeDepo})
                  AND m.mrkID NOT IN @haricMrk
                GROUP BY m.mrkID, m.mrkAd
                HAVING -SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehAdetN ELSE 0 END) >= 50
            ) sv
            LEFT JOIN (
                SELECT u2.urnMrkID, SUM(s.stok) AS StokAdet
                FROM DerinSISBkm.dbo.stokSonAltDepo_vw s WITH(NOLOCK)
                JOIN DerinSISBkm.dbo.urn u2 WITH(NOLOCK) ON u2.stkID = s.ehstkID
                WHERE s.ehAltDepo = 0 AND s.stok > 0 AND s.ehMekan IN ({LokasyonConfig.SubelerVeDepo})
                GROUP BY u2.urnMrkID
            ) st ON st.urnMrkID = sv.mrkID
            ORDER BY sv.NetCiro DESC
            """, new { Bas = new DateTime(bas.Year, bas.Month, bas.Day), haricMrk });
        return rows.ToList();
    }

    /// <summary>Kategori bazlı ÇEŞİT (distinct SKU) per mağaza — anlık, stok>0. Snapshot pre-aggregated çeşit veremiyor
    /// → canlı stokSonAltDepo_vw (~3s, COUNT DISTINCT). Toplam = mağazalar-arası distinct (per-store toplamı değil).</summary>
    public async Task<IReadOnlyList<KategoriCesitRow>> GetKategoriCesitAsync()
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<KategoriCesitRow>("""
            SELECT CAST(k.ktgrAd AS nvarchar(50)) AS Kategori,
                   COUNT(DISTINCT CASE WHEN s.ehMekan=1    AND s.stok>0 THEN s.ehstkID END) AS Fsm,
                   COUNT(DISTINCT CASE WHEN s.ehMekan=4477 AND s.stok>0 THEN s.ehstkID END) AS Ozluce,
                   COUNT(DISTINCT CASE WHEN s.ehMekan=4478 AND s.stok>0 THEN s.ehstkID END) AS IstYolu,
                   COUNT(DISTINCT CASE WHEN s.ehMekan=12   AND s.stok>0 THEN s.ehstkID END) AS Depo,
                   COUNT(DISTINCT CASE WHEN s.stok>0 THEN s.ehstkID END) AS Toplam
            FROM (
                -- Mağaza rafı: anlık view (doğru). MERKEZ DEPO: WMS ay-sonu snapshot (K-37) —
                -- view'ın mekan 12 defteri bozuk (poz 6,23M / neg −4,24M / net 1,99M vs WMS 4,25M).
                SELECT v.ehstkID, v.ehMekan, v.stok
                FROM DerinSISBkm.dbo.stokSonAltDepo_vw v WITH(NOLOCK)
                WHERE v.ehAltDepo = 0 AND v.ehMekan IN (1,4477,4478)
                UNION ALL
                SELECT b.stkID AS ehstkID, 12 AS ehMekan, CONVERT(int, b.Stok) AS stok
                FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b WITH(NOLOCK)
                WHERE b.Kaynak = 'WMS' AND b.ehMekan = 12
                  AND b.Donem = (SELECT MAX(Donem) FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli
                                 WITH(NOLOCK) WHERE Kaynak = 'WMS')
            ) s
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = s.ehstkID
            JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID = u.urnKtgr2ID
            WHERE 1 = 1
              AND k.ktgrAd NOT IN (N'Sınav Okulları', N'Hediye Çeki', N'Etkinlik', N'Zkargo', N'KARGO')
            GROUP BY CAST(k.ktgrAd AS nvarchar(50))
            """);
        return rows.ToList();
    }
}
