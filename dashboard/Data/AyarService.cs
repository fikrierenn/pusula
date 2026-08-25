using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// İş eşiği ayarları — key-value (PanelAyar, BkmPanel app-local; ERP'ye yazılmaz, bkz. erp-write-policy.md).
/// Hardcode 1,5/3 devir · %5 stockout · 100/200/300 risk · hariç-marka listesi buradan okunur (CFO tunelar).
/// Singleton: bellekte cache, Kaydet sonrası Yenile. Panel DB kapalıysa varsayılanlarla çalışır (sessiz değil, log).
/// </summary>
public sealed class AyarService
{
    private readonly Db _db;
    private readonly ILogger<AyarService> _log;
    private PanelAyarlar _cache = new();

    public AyarService(Db db, ILogger<AyarService> log)
    {
        _db = db; _log = log;
        if (!db.PanelEnabled) { log.LogWarning("Panel DB kapalı — ayarlar varsayılanla çalışır"); return; }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelAyar')
                CREATE TABLE dbo.PanelAyar (Anahtar nvarchar(60) PRIMARY KEY, Deger nvarchar(400) NOT NULL, Guncelleme datetime NOT NULL);
                """);
        }
        catch (Exception ex) { log.LogError(ex, "PanelAyar tablo oluşturma hatası"); }
        Yenile();
    }

    /// <summary>Güncel ayarlar (bellekteki cache). Tüketiciler bunu okur.</summary>
    public PanelAyarlar Deger => _cache;

    /// <summary>DB'den oku → cache. Parse hatası/eksik anahtar = varsayılan (record default).</summary>
    public void Yenile()
    {
        if (!_db.PanelEnabled) return;
        try
        {
            using var c = _db.OpenPanel();
            var map = c.Query<(string Anahtar, string Deger)>("SELECT Anahtar, Deger FROM dbo.PanelAyar")
                       .ToDictionary(x => x.Anahtar, x => x.Deger, StringComparer.OrdinalIgnoreCase);
            var d = new PanelAyarlar();
            _cache = new PanelAyarlar(
                DevirOlu: Dec(map, "devir_olu", d.DevirOlu),
                DevirSaglikli: Dec(map, "devir_saglikli", d.DevirSaglikli),
                StokYoklukHedef: Dec(map, "stok_yokluk_hedef", d.StokYoklukHedef),
                RiskDusuk: Int(map, "risk_dusuk", d.RiskDusuk),
                RiskOrta: Int(map, "risk_orta", d.RiskOrta),
                RiskYuksek: Int(map, "risk_yuksek", d.RiskYuksek),
                HaricMarkalar: IntList(map, "haric_markalar"),
                SatinFazlaAy: Int(map, "satin_fazla_ay", d.SatinFazlaAy),
                SatinMaterialite: Int(map, "satin_materialite", d.SatinMaterialite),
                SatinMinKoli: Int(map, "satin_min_koli", d.SatinMinKoli),
                SatinMinStok: Int(map, "satin_min_stok", d.SatinMinStok),
                SatinSezonMinTaban: Int(map, "satin_sezon_min", d.SatinSezonMinTaban),
                SatinRetailCap: Int(map, "satin_retail_cap", d.SatinRetailCap),
                SatinIadeKurallari: Str(map, "satin_iade_kurallari"),
                SatinAliciHaric: Str(map, "satin_alici_haric"),
                SatinAliciBirlestir: Str(map, "satin_alici_birlestir"),
                SatinRatchetAy: Int(map, "satin_ratchet_ay", d.SatinRatchetAy),
                SatinIliskiliTaraf: Str(map, "satin_iliskili_taraf"),
                SatinAlimciInsIds: Str(map, "satin_alimci"),
                SatinAtifBaslangic: Str(map, "satin_atif_baslangic"),
                MusteriGruplari: Str(map, "musteri_gruplari"));
        }
        catch (Exception ex) { _log.LogError(ex, "Ayarlar okunamadı — varsayılanla devam"); }
    }

    /// <summary>Ayarları kaydet (upsert tüm anahtarlar) + cache yenile. Aralık guard çağıran tarafta (UI).</summary>
    public async Task KaydetAsync(PanelAyarlar a)
    {
        if (!_db.PanelEnabled) throw new InvalidOperationException("Panel DB kapalı — ayar kaydedilemez.");
        var satirlar = new (string K, string V)[]
        {
            ("devir_olu", a.DevirOlu.ToString(System.Globalization.CultureInfo.InvariantCulture)),
            ("devir_saglikli", a.DevirSaglikli.ToString(System.Globalization.CultureInfo.InvariantCulture)),
            ("stok_yokluk_hedef", a.StokYoklukHedef.ToString(System.Globalization.CultureInfo.InvariantCulture)),
            ("risk_dusuk", a.RiskDusuk.ToString()),
            ("risk_orta", a.RiskOrta.ToString()),
            ("risk_yuksek", a.RiskYuksek.ToString()),
            ("haric_markalar", string.Join(",", a.HaricMarkalarEtkin)),
            ("satin_fazla_ay", a.SatinFazlaAy.ToString()),
            ("satin_materialite", a.SatinMaterialite.ToString()),
            ("satin_min_koli", a.SatinMinKoli.ToString()),
            ("satin_min_stok", a.SatinMinStok.ToString()),
            ("satin_sezon_min", a.SatinSezonMinTaban.ToString()),
            ("satin_retail_cap", a.SatinRetailCap.ToString()),
            ("satin_iade_kurallari", string.Join(",", a.IadeKuralKodlari)),
            ("satin_alici_haric", string.Join(",", a.AliciHaricEtkin)),
            ("satin_alici_birlestir", string.Join(";", a.AliciBirlestirMap.Select(kv => $"{kv.Value}={kv.Key}"))),
            ("satin_ratchet_ay", a.SatinRatchetAy.ToString()),
            ("satin_iliskili_taraf", string.Join(",", a.IliskiliTarafIds)),
            ("satin_alimci", string.Join(",", a.AlimciInsIds)),
            ("satin_atif_baslangic", a.AtifBaslangicEtkin),
            // Boş bırakılırsa varsayılan grup haritası yazılır (Kaydet sonrası harita kaybolmasın).
            ("musteri_gruplari", string.IsNullOrWhiteSpace(a.MusteriGruplari)
                ? PanelAyarlar.VarsayilanMusteriGrup : a.MusteriGruplari!),
        };
        await using var c = await _db.OpenPanelAsync()!;
        foreach (var (k, v) in satirlar)
            await c.ExecuteAsync("""
                MERGE dbo.PanelAyar AS t USING (SELECT @k AS Anahtar) AS s ON t.Anahtar = s.Anahtar
                WHEN MATCHED THEN UPDATE SET Deger = @v, Guncelleme = SYSDATETIME()
                WHEN NOT MATCHED THEN INSERT (Anahtar, Deger, Guncelleme) VALUES (@k, @v, SYSDATETIME());
                """, new { k, v });
        _log.LogInformation("Ayarlar kaydedildi (devir {Olu}/{Sag}, risk {Rd}/{Ro}/{Ry})", a.DevirOlu, a.DevirSaglikli, a.RiskDusuk, a.RiskOrta, a.RiskYuksek);
        Yenile();
    }

    static decimal Dec(IDictionary<string, string> m, string k, decimal def) =>
        m.TryGetValue(k, out var v) && decimal.TryParse(v, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out var d) ? d : def;
    static string? Str(IDictionary<string, string> m, string k) =>
        m.TryGetValue(k, out var v) && !string.IsNullOrWhiteSpace(v) ? v : null;
    static int Int(IDictionary<string, string> m, string k, int def) =>
        m.TryGetValue(k, out var v) && int.TryParse(v, out var n) ? n : def;
    static IReadOnlyList<int>? IntList(IDictionary<string, string> m, string k) =>
        m.TryGetValue(k, out var v) && !string.IsNullOrWhiteSpace(v)
            ? v.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
               .Select(s => int.TryParse(s, out var n) ? n : (int?)null).Where(n => n.HasValue).Select(n => n!.Value).ToArray()
            : null;
}
