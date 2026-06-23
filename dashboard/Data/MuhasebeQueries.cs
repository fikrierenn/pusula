using System.Data;
using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Muhasebe / Kontrol paneli (B-117) — Fikri'nin `bkm.sp_KapanisMudahaleKontrol_v2` SP'sini sarar.
/// Özet → tıkla → detay drill. Kapanış-sonrası müdahale (CAR+FAT+MHS), severity + forensic + isim (drn1).
/// Bağlantı: mevcut Db.OpenAsync (DerinSISBkm, 201) — SP orada, yeni bağlantı yok.
/// SP deploy edilmemişse sorgu hata verir → çağıran sayfa banner gösterir (sessiz değil).
/// </summary>
public sealed class MuhasebeQueries(Db db, ILogger<MuhasebeQueries> logger)
{
    const string Sp = "DerinSISBkm.bkm.sp_KapanisMudahaleKontrol_v2";

    // Dapper map'leme için düz record (8+ elemanlı ValueTuple nested Rest → Dapper 8. elemanı map edemez, tutar boş kalır).
    private sealed record YevmiyeQ(int YevmiyeNo, string Tarih, string FisAd, string HspKod, string HspAd, string? Aciklama, decimal Borc, decimal Alacak);
    private sealed record FaturaQ(string EvrakNo, string Tarih, int Tip, string? Not, string? CariKod, string? CariAd, string Kod, string Urun, string? MasrafMerkezi, decimal Adet, decimal Tutar, decimal Kdv);

    /// <summary>Özet: dönem×kaynak×gider (adet/tutar/maxgün/risk). yil/ay null → tüm kapanmış dönemler.</summary>
    public async Task<IReadOnlyList<KontrolOzetRow>> GetOzetAsync(int? yil, int? ay, string kaynak, bool sadeceGider)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<KontrolOzetRow>(Sp, new
        {
            Yil = yil, Ay = ay, Kaynak = kaynak, SadeceGider = sadeceGider,
            Mod = "OZET", GiderKod = (string?)null, Top = 5000,
        }, commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    /// <summary>Detay drill: belirli dönem + kaynak (+ gider kodu) için evrak listesi, RiskSkor sıralı.</summary>
    public async Task<IReadOnlyList<KontrolDetayRow>> GetDetayAsync(int yil, int ay, string kaynak, string? giderKod, bool sadeceGider)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<KontrolDetayRow>(Sp, new
        {
            Yil = yil, Ay = ay, Kaynak = kaynak, SadeceGider = sadeceGider,
            Mod = "DETAY", GiderKod = giderKod, Top = 5000,
        }, commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    /// <summary>Yevmiye fişi detayı (DETAY evrak drill) — fisbID + sirketID ile satırlar. MHS evrak = yevmiye fişi.</summary>
    public async Task<YevmiyeFis?> GetYevmiyeFisAsync(int fisId, int sirketId)
    {
        await using var conn = await db.OpenAsync();
        var rows = (await conn.QueryAsync<YevmiyeQ>("""
            SELECT CAST(b.yevmiyeNo AS int) AS YevmiyeNo,
                   CONVERT(varchar(10), b.fisTarih, 104) AS Tarih,
                   CAST(b.fisAd AS nvarchar(200)) AS FisAd,
                   h.hspKod AS HspKod, CAST(h.hspAd AS nvarchar(80)) AS HspAd,
                   CAST(ff.fisAciklama AS nvarchar(160)) AS Aciklama,
                   CAST(CASE WHEN ff.fisTutar < 0 THEN -ff.fisTutar ELSE 0 END AS decimal(18,2)) AS Borc,
                   CAST(CASE WHEN ff.fisTutar > 0 THEN  ff.fisTutar ELSE 0 END AS decimal(18,2)) AS Alacak
            FROM DerinSISBkm.mhs.mhsFisBaslik b
            JOIN DerinSISBkm.mhs.mhsFis ff ON ff.fisID = b.fisbID AND ff.fisSirketID = b.fisbSirketID
            JOIN DerinSISBkm.mhs.mhsHsp h ON h.hspID = ff.fisHspID AND h.hspSirketID = ff.fisSirketID
            WHERE b.fisbID = @fisId AND b.fisbSirketID = @sirketId
            ORDER BY ff.fsID
            """, new { fisId, sirketId })).ToList();
        if (rows.Count == 0) return null;
        var satirlar = rows.Select(r => new YevmiyeFisSatir(r.HspKod, r.HspAd, r.Aciklama, r.Borc, r.Alacak)).ToList();
        return new YevmiyeFis(rows[0].YevmiyeNo, rows[0].Tarih, rows[0].FisAd, satirlar);
    }

    /// <summary>Gider/masraf faturası detayı (DETAY FAT evrak drill) — eID ile satırlar (urn ürün/gider kalemi).</summary>
    public async Task<Fatura?> GetFaturaAsync(int faturaId)
    {
        await using var conn = await db.OpenAsync();
        var rows = (await conn.QueryAsync<FaturaQ>("""
            SELECT CAST(f.eNo AS varchar(50)) AS EvrakNo,
                   CONVERT(varchar(10), f.eTarihS, 104) AS Tarih,
                   CAST(f.eTip AS int) AS Tip, CAST(f.eNot AS nvarchar(200)) AS [Not],
                   CAST(fr.frmKod AS varchar(40)) AS CariKod, CAST(fr.frmAd AS nvarchar(120)) AS CariAd,
                   CAST(ISNULL(u.stkKod, '') AS nvarchar(50)) AS Kod,
                   CAST(ISNULL(u.stkAd, '(tanımsız)') AS nvarchar(90)) AS Urun,
                   CAST(LTRIM(REPLACE(REPLACE(gm.frmAd, N'G - ', N''), N' Gider Merkezi', N'')) AS nvarchar(60)) AS MasrafMerkezi,
                   CAST(a.ehAdetN AS decimal(18,2)) AS Adet,
                   CAST(a.ehTutar AS decimal(18,2)) AS Tutar,
                   CAST(ISNULL(a.ehTutarKDV,0) AS decimal(18,2)) AS Kdv
            FROM DerinSISBkm.dbo.fat f
            JOIN DerinSISBkm.dbo.fatAyr a ON a.ehID = f.eID
            LEFT JOIN DerinSISBkm.dbo.frm fr ON fr.frmID = f.eFirma
            LEFT JOIN DerinSISBkm.dbo.frm gm ON gm.frmID = a.fGdrMerkez
            LEFT JOIN DerinSISBkm.dbo.urn u ON u.stkID = a.ehStkID
            WHERE f.eID = @faturaId
            ORDER BY a.ehID
            """, new { faturaId })).ToList();
        if (rows.Count == 0) return null;
        var satirlar = rows.Select(r => new FaturaSatir(r.Kod, r.Urun, r.MasrafMerkezi, r.Adet, r.Tutar, r.Kdv)).ToList();
        return new Fatura(rows[0].EvrakNo, rows[0].Tarih, rows[0].Tip, rows[0].Not, rows[0].CariKod, rows[0].CariAd, satirlar);
    }

    /// <summary>Kapanmış dönem listesi (seçici için). Fin_AyKapanis — en yeni önce.</summary>
    public async Task<IReadOnlyList<(int Yil, int Ay, string Kapanis)>> GetDonemlerAsync()
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<(int Yil, int Ay, string Kapanis)>("""
            SELECT TOP 60 CAST(DonemYil AS int) AS Yil, CAST(DonemAy AS int) AS Ay, CONVERT(varchar(10), KapanisDT, 104) AS Kapanis
            FROM DerinSISBkm.bkm.Fin_AyKapanis ORDER BY DonemYil DESC, DonemAy DESC
            """);
        return rows.ToList();
    }

    // ── Ayarlar: Fin_AyKapanis yönetimi (B-117/d) — ay kapanış tarihleri ekle/güncelle/sil ──

    /// <summary>Tüm kapanış kayıtları (yönetim listesi), en yeni önce.</summary>
    public async Task<IReadOnlyList<KapanisDonem>> GetKapanisListAsync()
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<KapanisDonem>("""
            SELECT TOP 200 CAST(DonemYil AS int) AS DonemYil, CAST(DonemAy AS int) AS DonemAy, KapanisDT, Aciklama, KayitDT
            FROM DerinSISBkm.bkm.Fin_AyKapanis ORDER BY DonemYil DESC, DonemAy DESC
            """);
        return rows.ToList();
    }

    /// <summary>Ay kapanışı ekle/güncelle (PK = DonemYil+DonemAy). Parametreli + aralık guard. KayitDT server-side.</summary>
    public async Task UpsertKapanisAsync(int yil, int ay, DateTime kapanisDt, string? aciklama)
    {
        if (yil is < 2020 or > 2035) throw new ArgumentOutOfRangeException(nameof(yil), "Yıl 2020–2035 aralığında olmalı.");
        if (ay is < 1 or > 12) throw new ArgumentOutOfRangeException(nameof(ay), "Ay 1–12 aralığında olmalı.");
        await using var conn = await db.OpenAsync();
        // MERGE: aynı dönem varsa KapanisDT/Aciklama güncelle, yoksa ekle. Tek atomik ifade.
        const string sql = """
            MERGE DerinSISBkm.bkm.Fin_AyKapanis AS t
            USING (SELECT @yil AS DonemYil, @ay AS DonemAy) AS s
              ON t.DonemYil = s.DonemYil AND t.DonemAy = s.DonemAy
            WHEN MATCHED THEN UPDATE SET t.KapanisDT = @kapanisDt, t.Aciklama = @aciklama, t.KayitDT = SYSDATETIME()
            WHEN NOT MATCHED THEN
              INSERT (DonemYil, DonemAy, KapanisDT, Aciklama, KayitDT)
              VALUES (@yil, @ay, @kapanisDt, @aciklama, SYSDATETIME());
            """;
        var n = await conn.ExecuteAsync(sql, new { yil, ay, kapanisDt, aciklama });
        logger.LogInformation("Fin_AyKapanis upsert {Yil}-{Ay:00} → {Tarih:dd.MM.yyyy} ({N} satır)", yil, ay, kapanisDt, n);
    }

    /// <summary>Ay kapanışı sil (PK ile). UI onay ister.</summary>
    public async Task DeleteKapanisAsync(int yil, int ay)
    {
        await using var conn = await db.OpenAsync();
        var n = await conn.ExecuteAsync(
            "DELETE FROM DerinSISBkm.bkm.Fin_AyKapanis WHERE DonemYil = @yil AND DonemAy = @ay", new { yil, ay });
        logger.LogInformation("Fin_AyKapanis sil {Yil}-{Ay:00} ({N} satır)", yil, ay, n);
    }
}
