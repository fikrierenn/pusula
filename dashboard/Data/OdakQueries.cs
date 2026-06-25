using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// ODAK stok-satış paneli (B-122) — dünkü Excel raporunun panel hali + usulsüz sipariş tespiti.
/// SALT-OKUMA (Db.OpenAsync, DerinSISBkm/201 + OPENQUERY ODAKJOKER). 3-parçalı isim ZORUNLU (app master katalog).
/// "ODAK stok" = kanonik ent.odak_depo_Stok (e-tic fulfillment); mağaza rafı stokSonAltDepo_vw; transit mekan dahil DEĞİL.
/// </summary>
public sealed class OdakQueries(Db db)
{
    // OPENQUERY içine gömülen ISO tarih (son 12 ay) — server-side hesaplanır, kullanıcı girdisi DEĞİL (injection yok).
    private static string Iso12() => DateTime.Today.AddYears(-1).ToString("yyyyMMdd");

    /// <summary>ODAK stoklu kategoriler (seçici) — stok adedine göre.</summary>
    public async Task<IReadOnlyList<OdakKategori>> GetKategorilerAsync()
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<OdakKategori>("""
            SELECT k.ktgrAd AS Kategori,
                   COUNT(DISTINCT o.stkID) AS Cesit,
                   CAST(SUM(o.StokMiktar) AS int) AS StokAdet
            FROM DerinSISBkm.ent.odak_depo_Stok o
            JOIN DerinSISBkm.dbo.urn u ON u.stkID = o.stkID
            JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID
            WHERE o.StokMiktar > 0
              AND k.ktgrAd NOT IN (N'Sınav Okulları', N'Hediye Çeki', N'Etkinlik', N'Zkargo', N'KARGO')
            GROUP BY k.ktgrAd
            HAVING COUNT(DISTINCT o.stkID) > 0
            ORDER BY SUM(o.StokMiktar) DESC
            """);
        return rows.ToList();
    }

    /// <summary>Marka/yayınevi özeti (seçili kategori) — şube satış bazlı devir (e-tic paydaya dahil değil, journal kararı).</summary>
    public async Task<IReadOnlyList<OdakMarkaOzet>> GetMarkaOzetAsync(string kategori)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<OdakMarkaOzet>("""
            WITH stk AS (
                SELECT u.urnMrkID, COUNT(DISTINCT o.stkID) AS Cesit, SUM(o.StokMiktar) AS Stok
                FROM DerinSISBkm.ent.odak_depo_Stok o
                JOIN DerinSISBkm.dbo.urn u ON u.stkID = o.stkID
                JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID AND k.ktgrAd = @kategori
                WHERE o.StokMiktar > 0
                GROUP BY u.urnMrkID
            ),
            sat AS (
                SELECT u.urnMrkID,
                       -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) AS SatisAdet,
                       SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN WHEN h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS NetCiro
                FROM DerinSISBkm.dbo.irsHrk h
                JOIN DerinSISBkm.dbo.urn u ON u.stkID = h.ehstkID
                JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID AND k.ktgrAd = @kategori
                WHERE h.ehTrhS >= DATEADD(YEAR,-1,GETDATE()) AND h.ehMekan IN (1,4477,4478)
                  AND h.ehAltDepo = 0 AND h.ehTip IN (4,100,3,5,101)
                GROUP BY u.urnMrkID
            )
            SELECT ISNULL(m.mrkAd, N'-') AS Marka,
                   stk.Cesit AS Cesit,
                   CAST(stk.Stok AS int) AS StokAdet,
                   CAST(ISNULL(sat.SatisAdet,0) AS int) AS YilSatis,
                   CAST(ISNULL(sat.NetCiro,0) AS decimal(18,0)) AS YilCiro,
                   CASE WHEN stk.Stok > 0 THEN CAST(1.0 * ISNULL(sat.SatisAdet,0) / stk.Stok AS decimal(10,2)) END AS Devir
            FROM stk
            LEFT JOIN DerinSISBkm.dbo.urnMrk m ON m.mrkID = stk.urnMrkID
            LEFT JOIN sat ON sat.urnMrkID = stk.urnMrkID
            WHERE stk.Stok > 0
            ORDER BY stk.Stok DESC
            """, new { kategori });
        return rows.ToList();
    }

    /// <summary>Ürün tam döküm (seçili kategori, sayfalı). marka (tam) + ara (yazar/ürün LIKE) filtresi. E-ticaret OPENQUERY dahil.</summary>
    public async Task<OdakSayfa<OdakUrun>> GetUrunlerAsync(string kategori, string? marka, string? ara, int offset, int take)
    {
        await using var conn = await db.OpenAsync();
        var araLike = string.IsNullOrWhiteSpace(ara) ? null : "%" + ara.Trim() + "%";
        marka = string.IsNullOrWhiteSpace(marka) ? null : marka;
        var sql = $"""
            WITH ecom AS (
                SELECT DERINSIS_ID AS stkID, Qty FROM OPENQUERY(ODAKJOKER, '
                    SELECT i.DERINSIS_ID, SUM(d.QUANTITY) AS Qty FROM JOKER.dbo.J_ORDER_DETAILS d
                    JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
                    WHERE o.ORDERDATE >= ''{Iso12()}'' AND i.DERINSIS_ID > 0 GROUP BY i.DERINSIS_ID')
            ),
            mgz AS (
                SELECT v.ehstkID sID,
                    SUM(CASE WHEN v.ehMekan=1 THEN v.stok ELSE 0 END) Fsm,
                    SUM(CASE WHEN v.ehMekan=4477 THEN v.stok ELSE 0 END) Ozl,
                    SUM(CASE WHEN v.ehMekan=4478 THEN v.stok ELSE 0 END) Ist,
                    SUM(CASE WHEN v.ehMekan=12 THEN v.stok ELSE 0 END) Mrkz
                FROM DerinSISBkm.dbo.stokSonAltDepo_vw v
                JOIN DerinSISBkm.dbo.urn u2 ON u2.stkID = v.ehstkID
                JOIN DerinSISBkm.dbo.urnKtgr2 k2 ON k2.ktgrID = u2.urnKtgr2ID AND k2.ktgrAd = @kategori
                WHERE v.ehAltDepo = 0 AND v.ehMekan IN (1,4477,4478,12)
                GROUP BY v.ehstkID
            ),
            sat AS (
                SELECT h.ehstkID sID,
                    -SUM(CASE WHEN h.ehMekan=1    THEN h.ehAdetN ELSE 0 END) sFsm,
                    -SUM(CASE WHEN h.ehMekan=4477 THEN h.ehAdetN ELSE 0 END) sOzl,
                    -SUM(CASE WHEN h.ehMekan=4478 THEN h.ehAdetN ELSE 0 END) sIst
                FROM DerinSISBkm.dbo.irsHrk h
                JOIN DerinSISBkm.dbo.urn u2 ON u2.stkID = h.ehstkID
                JOIN DerinSISBkm.dbo.urnKtgr2 k2 ON k2.ktgrID = u2.urnKtgr2ID AND k2.ktgrAd = @kategori
                WHERE h.ehTrhS >= DATEADD(YEAR,-1,GETDATE()) AND h.ehMekan IN (1,4477,4478)
                  AND h.ehAltDepo = 0 AND h.ehTip IN (4,100)
                GROUP BY h.ehstkID
            )
            SELECT
                CAST(u.stkID AS int) AS StkID,
                ISNULL(m.mrkAd, N'-') AS Marka,
                LTRIM(RTRIM(ub.Yazar)) AS Yazar,
                u.stkKod AS Kod, u.stkAd AS Urun,
                CAST(ISNULL(mgz.Fsm,0) AS int) AS StokFsm, CAST(ISNULL(mgz.Ozl,0) AS int) AS StokOzl, CAST(ISNULL(mgz.Ist,0) AS int) AS StokIst,
                CAST(ISNULL(mgz.Mrkz,0) AS int) AS StokMrkz, CAST(ISNULL(o.StokMiktar,0) AS int) AS StokOdak,
                CAST(ISNULL(mgz.Fsm,0)+ISNULL(mgz.Ozl,0)+ISNULL(mgz.Ist,0)+ISNULL(mgz.Mrkz,0)+ISNULL(o.StokMiktar,0) AS int) AS StokToplam,
                CAST(ISNULL(sat.sFsm,0) AS int) AS SatisFsm, CAST(ISNULL(sat.sOzl,0) AS int) AS SatisOzl, CAST(ISNULL(sat.sIst,0) AS int) AS SatisIst,
                CAST(ISNULL(ecom.Qty,0) AS int) AS EcomSiparis,
                CAST(ISNULL(sat.sFsm,0)+ISNULL(sat.sOzl,0)+ISNULL(sat.sIst,0)+ISNULL(ecom.Qty,0) AS int) AS SatisToplam,
                CAST(ub.SonAlis AS decimal(18,2)) AS Maliyet,
                CAST(ub.SatisFiyat AS decimal(18,2)) AS Fiyat,
                CASE WHEN (ISNULL(sat.sFsm,0)+ISNULL(sat.sOzl,0)+ISNULL(sat.sIst,0)+ISNULL(ecom.Qty,0)) > 0
                     THEN CAST((ISNULL(mgz.Fsm,0)+ISNULL(mgz.Ozl,0)+ISNULL(mgz.Ist,0)+ISNULL(mgz.Mrkz,0)+ISNULL(o.StokMiktar,0))
                          / ((ISNULL(sat.sFsm,0)+ISNULL(sat.sOzl,0)+ISNULL(sat.sIst,0)+ISNULL(ecom.Qty,0))/12.0) AS decimal(10,1)) END AS AyKapsam,
                COUNT(*) OVER() AS ToplamSatir
            FROM DerinSISBkm.dbo.urn u
            JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID AND k.ktgrAd = @kategori
            LEFT JOIN DerinSISBkm.ent.odak_depo_Stok o ON o.stkID = u.stkID
            LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub ON ub.stkID = u.stkID
            LEFT JOIN DerinSISBkm.dbo.urnMrk m ON m.mrkID = u.urnMrkID
            LEFT JOIN mgz ON mgz.sID = u.stkID
            LEFT JOIN sat ON sat.sID = u.stkID
            LEFT JOIN ecom ON ecom.stkID = u.stkID
            WHERE u.urnTip = 0
              AND (ISNULL(o.StokMiktar,0) > 0 OR ISNULL(mgz.Fsm,0)+ISNULL(mgz.Ozl,0)+ISNULL(mgz.Ist,0)+ISNULL(mgz.Mrkz,0) > 0)
              AND (@marka IS NULL OR ISNULL(m.mrkAd, N'-') = @marka)
              AND (@araLike IS NULL OR u.stkAd LIKE @araLike OR ub.Yazar LIKE @araLike)
            ORDER BY StokToplam DESC
            OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY
            """;
        var rows = (await conn.QueryAsync<OdakUrunRow>(sql, new { kategori, marka, araLike, offset, take })).ToList();
        var toplam = rows.Count > 0 ? rows[0].ToplamSatir : 0;
        var satirlar = rows.Select(r => new OdakUrun(r.StkID, r.Marka, r.Yazar, r.Kod, r.Urun,
            r.StokFsm, r.StokOzl, r.StokIst, r.StokMrkz, r.StokOdak, r.StokToplam,
            r.SatisFsm, r.SatisOzl, r.SatisIst, r.EcomSiparis, r.SatisToplam,
            r.Maliyet, r.Fiyat, r.AyKapsam)).ToList();
        return new OdakSayfa<OdakUrun>(satirlar, toplam);
    }

    /// <summary>Usulsüz sipariş (seçili kategori, sayfalı): ODAK stoğu yüksek (≥6 ay kapsam) veya satışsız OLDUĞU HALDE
    /// son 1 yılda ≥2 farklı cariden alım yapılmış ürünler. CariSayisi/AyKapsam'a göre sıralı (en şüpheli üstte).</summary>
    public async Task<OdakSayfa<OdakUsulsuz>> GetUsulsuzAsync(string kategori, int offset, int take)
    {
        await using var conn = await db.OpenAsync();
        var sql = $"""
            WITH ecom AS (
                SELECT DERINSIS_ID AS stkID, Qty FROM OPENQUERY(ODAKJOKER, '
                    SELECT i.DERINSIS_ID, SUM(d.QUANTITY) AS Qty FROM JOKER.dbo.J_ORDER_DETAILS d
                    JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
                    WHERE o.ORDERDATE >= ''{Iso12()}'' AND i.DERINSIS_ID > 0 GROUP BY i.DERINSIS_ID')
            ),
            sat AS (
                SELECT h.ehstkID sID, -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) AS Adet
                FROM DerinSISBkm.dbo.irsHrk h
                JOIN DerinSISBkm.dbo.urn u2 ON u2.stkID = h.ehstkID
                JOIN DerinSISBkm.dbo.urnKtgr2 k2 ON k2.ktgrID = u2.urnKtgr2ID AND k2.ktgrAd = @kategori
                WHERE h.ehTrhS >= DATEADD(YEAR,-1,GETDATE()) AND h.ehMekan IN (1,4477,4478)
                  AND h.ehAltDepo = 0 AND h.ehTip IN (4,100)
                GROUP BY h.ehstkID
            ),
            alis AS (
                SELECT fa.ehstkID sID,
                    COUNT(DISTINCT f.eFirma) AS CariSayisi,
                    COUNT(DISTINCT f.eID) AS FaturaSayisi,
                    SUM(fa.ehAdetN) AS AlisAdet,
                    SUM(fa.ehTutarN) AS AlisTutar
                FROM DerinSISBkm.dbo.fatAyr fa
                JOIN DerinSISBkm.dbo.fat f ON f.eID = fa.ehID AND f.eTip = 0 AND f.eDurum <> 2
                JOIN DerinSISBkm.dbo.urn u2 ON u2.stkID = fa.ehstkID
                JOIN DerinSISBkm.dbo.urnKtgr2 k2 ON k2.ktgrID = u2.urnKtgr2ID AND k2.ktgrAd = @kategori
                WHERE f.eTarih >= DATEADD(YEAR,-1,GETDATE())
                GROUP BY fa.ehstkID
                HAVING COUNT(DISTINCT f.eFirma) >= 2
            )
            SELECT
                CAST(u.stkID AS int) AS StkID,
                ISNULL(m.mrkAd, N'-') AS Marka,
                u.stkKod AS Kod, u.stkAd AS Urun,
                CAST(o.StokMiktar AS int) AS OdakStok,
                CAST(ISNULL(sat.Adet,0) AS int) AS YilSatis,
                CASE WHEN ISNULL(sat.Adet,0) + ISNULL(ecom.Qty,0) > 0
                     THEN CAST(o.StokMiktar / ((ISNULL(sat.Adet,0)+ISNULL(ecom.Qty,0))/12.0) AS decimal(10,1)) END AS AyKapsam,
                CAST(alis.CariSayisi AS int) AS CariSayisi,
                CAST(alis.FaturaSayisi AS int) AS FaturaSayisi,
                CAST(alis.AlisAdet AS int) AS AlisAdet,
                CAST(alis.AlisTutar AS decimal(18,0)) AS AlisTutar,
                COUNT(*) OVER() AS ToplamSatir
            FROM alis
            JOIN DerinSISBkm.ent.odak_depo_Stok o ON o.stkID = alis.sID AND o.StokMiktar > 0
            JOIN DerinSISBkm.dbo.urn u ON u.stkID = alis.sID
            LEFT JOIN DerinSISBkm.dbo.urnMrk m ON m.mrkID = u.urnMrkID
            LEFT JOIN sat ON sat.sID = alis.sID
            LEFT JOIN ecom ON ecom.stkID = alis.sID
            WHERE (ISNULL(sat.Adet,0) + ISNULL(ecom.Qty,0) = 0)                                        -- hiç satmıyor ama stok+alım var
               OR (o.StokMiktar / ((ISNULL(sat.Adet,0)+ISNULL(ecom.Qty,0))/12.0) >= 6.0)              -- ya da stok ≥6 aylık satışa yetiyor
            ORDER BY alis.CariSayisi DESC, o.StokMiktar DESC
            OFFSET @offset ROWS FETCH NEXT @take ROWS ONLY
            """;
        var rows = (await conn.QueryAsync<OdakUsulsuzRow>(sql, new { kategori, offset, take })).ToList();
        var toplam = rows.Count > 0 ? rows[0].ToplamSatir : 0;
        var satirlar = rows.Select(r => new OdakUsulsuz(r.StkID, r.Marka, r.Kod, r.Urun,
            r.OdakStok, r.YilSatis, r.AyKapsam, r.CariSayisi, r.FaturaSayisi, r.AlisAdet, r.AlisTutar)).ToList();
        return new OdakSayfa<OdakUsulsuz>(satirlar, toplam);
    }

    /// <summary>Usulsüz drill: bir ürünün son 1 yıl cari bazlı alış kırılımı (modal).</summary>
    public async Task<IReadOnlyList<OdakUsulsuzCari>> GetUsulsuzCarilerAsync(int stkID)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<OdakUsulsuzCari>("""
            SELECT CAST(ISNULL(f.eFirma,0) AS int) AS CariId,
                   ISNULL(fr.frmKod, N'-') AS CariKod,
                   ISNULL(fr.frmAd, N'(tanımsız)') AS CariAd,
                   COUNT(DISTINCT f.eID) AS FaturaSayisi,
                   CAST(SUM(fa.ehAdetN) AS decimal(18,2)) AS AlisAdet,
                   CAST(SUM(fa.ehTutarN) AS decimal(18,2)) AS AlisTutar,
                   CONVERT(varchar(10), MAX(f.eTarih), 104) AS SonAlis
            FROM DerinSISBkm.dbo.fatAyr fa
            JOIN DerinSISBkm.dbo.fat f ON f.eID = fa.ehID AND f.eTip = 0 AND f.eDurum <> 2
            LEFT JOIN DerinSISBkm.dbo.frm fr ON fr.frmID = f.eFirma
            WHERE fa.ehstkID = @stkID AND f.eTarih >= DATEADD(YEAR,-1,GETDATE())
            GROUP BY f.eFirma, fr.frmKod, fr.frmAd
            ORDER BY SUM(fa.ehTutarN) DESC
            """, new { stkID });
        return rows.ToList();
    }

    /// <summary>Bir cari × ürün için fatura listesi (cari satırına tıklayınca) — eID ile /fatura drill.</summary>
    public async Task<IReadOnlyList<OdakCariFatura>> GetCariFaturalarAsync(int stkID, int cariId)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<OdakCariFatura>("""
            SELECT CAST(f.eID AS int) AS EID,
                   CAST(f.eNo AS varchar(50)) AS EvrakNo,
                   CONVERT(varchar(10), f.eTarihS, 104) AS Tarih,
                   CAST(SUM(fa.ehAdetN) AS decimal(18,2)) AS Adet,
                   CAST(SUM(fa.ehTutarN) AS decimal(18,2)) AS Tutar
            FROM DerinSISBkm.dbo.fat f
            JOIN DerinSISBkm.dbo.fatAyr fa ON fa.ehID = f.eID AND fa.ehstkID = @stkID
            WHERE f.eFirma = @cariId AND f.eTip = 0 AND f.eDurum <> 2
              AND f.eTarih >= DATEADD(YEAR,-1,GETDATE())
            GROUP BY f.eID, f.eNo, f.eTarihS
            ORDER BY f.eTarihS DESC
            """, new { stkID, cariId });
        return rows.ToList();
    }

    // Dapper map'leme için düz row (COUNT OVER ToplamSatir ekli) — modele dönüştürülür.
    private sealed record OdakUrunRow(int StkID, string Marka, string? Yazar, string Kod, string Urun,
        int StokFsm, int StokOzl, int StokIst, int StokMrkz, int StokOdak, int StokToplam,
        int SatisFsm, int SatisOzl, int SatisIst, int EcomSiparis, int SatisToplam,
        decimal? Maliyet, decimal? Fiyat, decimal? AyKapsam, int ToplamSatir);

    private sealed record OdakUsulsuzRow(int StkID, string Marka, string Kod, string Urun,
        int OdakStok, int YilSatis, decimal? AyKapsam, int CariSayisi, int FaturaSayisi, int AlisAdet, decimal AlisTutar, int ToplamSatir);
}
