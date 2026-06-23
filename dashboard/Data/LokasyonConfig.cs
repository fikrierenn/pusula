using Dapper;

namespace GmDashboard.Data;

/// <summary>
/// BKM mağaza/lokasyon — `dbo.posMagaza`'dan DİNAMİK (startup'ta InitAsync). Hardcode = yalnız fallback (DB okunamazsa).
/// Şube = mekanTip=0 (mağaza) AND mekanDurum=0 (aktif) → yeni mağaza açılınca otomatik dahil. Depo = mekanMerkezDepo=1.
/// `Subeler`/`SubelerVeDepo` SQL'e `ehMekan IN (...)` olarak interpolasyon edilir — değerler yalnız int mekanID (injection güvenli).
/// </summary>
public static class LokasyonConfig
{
    // Fallback (posMagaza okunamazsa bilinen değerler). InitAsync DB'den günceller.
    public static string Subeler { get; private set; } = "1,4477,4478";
    public static string SubelerVeDepo { get; private set; } = "12,1,4478,4477";
    public static IReadOnlyDictionary<int, string> Mekan { get; private set; }
        = new Dictionary<int, string> { [1] = "FSM", [4477] = "Özlüce", [4478] = "İst.Yolu" };

    /// <summary>Startup'ta bir kez (Program.cs). posMagaza'dan şube/depo ID listesi + ad haritası. Hata → fallback (loglu).</summary>
    public static async Task InitAsync(Db db, ILogger log)
    {
        try
        {
            await using var conn = await db.OpenAsync();
            var rows = (await conn.QueryAsync<(int Id, string Ad, int Tip, int Durum, int MerkezDepo)>(
                "SELECT mekanID AS Id, mekanAd AS Ad, mekanTip AS Tip, mekanDurum AS Durum, mekanMerkezDepo AS MerkezDepo FROM DerinSISBkm.dbo.posMagaza"))
                .ToList();

            var sube = rows.Where(r => r.Tip == 0 && r.Durum == 0).Select(r => r.Id).ToList();
            if (sube.Count == 0) { log.LogWarning("posMagaza aktif mağaza döndürmedi — lokasyon hardcode fallback"); return; }

            var depo = rows.Where(r => r.MerkezDepo == 1).Select(r => r.Id);
            Subeler = string.Join(",", sube);
            SubelerVeDepo = string.Join(",", depo.Concat(sube).Distinct());
            Mekan = rows.Where(r => r.Tip == 0 && r.Durum == 0)
                        .ToDictionary(r => r.Id, r => Temizle(r.Ad));
            log.LogInformation("Lokasyon posMagaza'dan yüklendi: şube [{S}] · +depo [{SD}]", Subeler, SubelerVeDepo);
        }
        catch (Exception ex)
        {
            log.LogError(ex, "posMagaza okunamadı — lokasyon hardcode fallback ({S})", Subeler);
        }
    }

    // "FSM Mğz" → "FSM", "İST YOLU Mğz" → "İST YOLU". Ham posMagaza adındaki " Mğz" eki temizlenir.
    private static string Temizle(string ad) =>
        string.IsNullOrWhiteSpace(ad) ? ad : ad.Replace(" Mğz", "").Replace(" Mğz.", "").Trim();
}
