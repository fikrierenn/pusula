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
