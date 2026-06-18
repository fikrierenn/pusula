using System.Text.Json;
using System.Text.RegularExpressions;
using Dapper;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// Asistan araçları (plan-20 Faz-1): sql_sorgu (salt-okuma + PII maske), sema_oku, ornek_sql_bul (golden-record),
/// gorev_* (GorevService). LLM tool-use ile çağrılır; AsistanService loop çalıştırır.
/// </summary>
public sealed class AsistanAraclar(Db db, GorevService gorev, IHostEnvironment env, ILogger<AsistanAraclar> log)
{
    private const int SatirLimit = 60;
    private string RepoKok => BulRepoKok();

    /// <summary>LLM'e sunulan araç tanımları (JSON Schema parametreli).</summary>
    public IReadOnlyList<LlmArac> Tanimlar() =>
    [
        new("sql_sorgu",
            "BKM SQL Server'da SALT-OKUMA (SELECT) sorgusu çalıştırır, sonucu döndürür. Ciro/stok/kargo/müşteri sayısı vb. veri sorularında kullan. Sorgu sema kurallarına uymalı (KDV-hariç net, iade-netleme). Yazma/DDL YASAK.",
            new { type = "object", properties = new { sql = new { type = "string", description = "Tek SELECT/WITH sorgusu (DMY tarih, NOLOCK)." } }, required = new[] { "sql" } }),
        new("sema_oku",
            "Semantik katmanı (sema/*.yaml) okur — doğru tablo/join/kod/metrik için. SQL yazmadan ÖNCE ilgili sema'yı oku. dosya: entities|bridges|codes|metrics (boş=hepsi özet).",
            new { type = "object", properties = new { dosya = new { type = "string", description = "entities|bridges|codes|metrics veya boş" } } }),
        new("ornek_sql_bul",
            "Arşivlenmiş örnek SQL'lerde (sorgular/) konuya benzer sorgu arar — golden-record few-shot. SQL yazmadan önce benzer doğrulanmış örnek bul.",
            new { type = "object", properties = new { konu = new { type = "string", description = "Aranan konu/anahtar kelime (ör. 'kargo iade', 'kategori ciro')" } }, required = new[] { "konu" } }),
        new("gorev_ekle",
            "Yeni görev/yapılacak oluşturur. baslik zorunlu, atanan opsiyonel.",
            new { type = "object", properties = new { baslik = new { type = "string" }, aciklama = new { type = "string" }, atanan = new { type = "string" } }, required = new[] { "baslik" } }),
        new("gorev_listele",
            "Açık görevleri listeler (kapatılmamış).",
            new { type = "object", properties = new { } }),
    ];

    /// <summary>Araç çağrısını çalıştır → JSON sonuç (tool turuna geri beslenir).</summary>
    public async Task<string> CalistirAsync(string ad, JsonElement args, CancellationToken ct = default)
    {
        try
        {
            return ad switch
            {
                "sql_sorgu"     => await SqlSorgu(Arg(args, "sql"), ct),
                "sema_oku"      => SemaOku(Arg(args, "dosya")),
                "ornek_sql_bul" => OrnekSqlBul(Arg(args, "konu")),
                "gorev_ekle"    => GorevEkle(Arg(args, "baslik"), Arg(args, "aciklama"), Arg(args, "atanan")),
                "gorev_listele" => GorevListele(),
                _ => Hata($"Bilinmeyen araç: {ad}"),
            };
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Araç hatası: {Ad}", ad);
            return Hata($"{ad} çalıştırılamadı: {ex.Message}");
        }
    }

    // ── sql_sorgu: guard → çalıştır → PII maske → satır limit ──
    private async Task<string> SqlSorgu(string? sql, CancellationToken ct)
    {
        var (ok, sebep) = SaltOkumaGuard.Dogrula(sql);
        if (!ok) return Hata($"Sorgu reddedildi (güvenlik): {sebep}");

        await using var conn = await db.OpenAsync();
        var rows = (await conn.QueryAsync(sql!, commandTimeout: 30)).Cast<IDictionary<string, object>>().Take(SatirLimit).ToList();
        var maskeli = rows.Select(r => r.ToDictionary(kv => kv.Key, kv => (object?)Maskele(kv.Key, kv.Value))).ToList();
        return JsonSerializer.Serialize(new { satir = maskeli.Count, limit = SatirLimit, veri = maskeli });
    }

    // PII maske: müşteri adı/telefon/kart kolonları → Claude/Groq'a maskeli gider (plan-20 KVKK).
    private static object? Maskele(string kolon, object? deger)
    {
        if (deger is null) return null;
        var k = kolon.ToLowerInvariant();
        bool pii = k.Contains("ad") && (k.Contains("musteri") || k.Contains("isim") || k == "ad" || k == "name")
                   || k.Contains("name") || k.Contains("telefon") || k.Contains("phone") || k.Contains("cep")
                   || k.Contains("gsm") || k.Contains("kart") || k.Contains("card") || k.Contains("tckn") || k.Contains("mail");
        if (!pii) return deger;
        var s = deger.ToString() ?? "";
        return s.Length <= 2 ? "***" : s[..1] + new string('*', Math.Min(s.Length - 1, 6));
    }

    private string SemaOku(string? dosya)
    {
        var dir = Path.Combine(RepoKok, "sema");
        var hedef = string.IsNullOrWhiteSpace(dosya) ? null : $"{dosya.Trim()}.yaml";
        try
        {
            if (hedef is not null && File.Exists(Path.Combine(dir, hedef)))
                return JsonSerializer.Serialize(new { dosya = hedef, icerik = File.ReadAllText(Path.Combine(dir, hedef)) });
            // hepsi → kısa liste + entities/codes (en kritik)
            var ozet = new[] { "entities", "codes", "bridges", "metrics" }
                .Where(f => File.Exists(Path.Combine(dir, $"{f}.yaml")))
                .ToDictionary(f => f, f => File.ReadAllText(Path.Combine(dir, $"{f}.yaml")));
            return JsonSerializer.Serialize(new { sema = ozet });
        }
        catch (Exception ex) { return Hata($"sema okunamadı: {ex.Message}"); }
    }

    // Golden-record: arşiv SQL'lerde konu ara (dosya adı + içerik), ilk birkaçı döndür (few-shot).
    private string OrnekSqlBul(string? konu)
    {
        if (string.IsNullOrWhiteSpace(konu)) return Hata("konu boş");
        var dir = Path.Combine(RepoKok, "sorgular");
        if (!Directory.Exists(dir)) return JsonSerializer.Serialize(new { bulunan = Array.Empty<string>() });
        var kelimeler = konu.ToLowerInvariant().Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var eslesen = Directory.EnumerateFiles(dir, "*.sql", SearchOption.AllDirectories)
            .Select(f => new { f, t = File.ReadAllText(f).ToLowerInvariant() })
            .Select(x => new { x.f, skor = kelimeler.Count(w => Path.GetFileName(x.f).ToLowerInvariant().Contains(w) || x.t.Contains(w)) })
            .Where(x => x.skor > 0).OrderByDescending(x => x.skor).Take(3).ToList();
        var ornekler = eslesen.Select(x => new { dosya = Path.GetFileName(x.f), sql = Kisalt(File.ReadAllText(x.f), 1500) }).ToList();
        return JsonSerializer.Serialize(new { bulunan = ornekler });
    }

    private string GorevEkle(string? baslik, string? aciklama, string? atanan)
    {
        if (string.IsNullOrWhiteSpace(baslik)) return Hata("baslik zorunlu");
        var taslak = $"📋{baslik}\n📝{aciklama}";
        var id = gorev.Kaydet(taslak, string.IsNullOrWhiteSpace(atanan) ? null : atanan);
        return JsonSerializer.Serialize(new { ok = id > 0, id, mesaj = id > 0 ? $"Görev #{id} oluşturuldu" : "Görev kaydedilemedi" });
    }

    private string GorevListele()
    {
        var liste = gorev.Listele(acikOnly: true).Select(g => new { g.Id, g.Baslik, g.Oncelik, g.Atanan, g.Durum });
        return JsonSerializer.Serialize(new { gorevler = liste });
    }

    private static string Hata(string m) => JsonSerializer.Serialize(new { hata = m });
    private static string Kisalt(string s, int n) => s.Length <= n ? s : s[..n] + "…";
    private static string? Arg(JsonElement a, string ad) =>
        a.ValueKind == JsonValueKind.Object && a.TryGetProperty(ad, out var v) && v.ValueKind != JsonValueKind.Null ? v.ToString() : null;

    private string BulRepoKok()
    {
        var d = new DirectoryInfo(env.ContentRootPath);
        while (d is not null && !Directory.Exists(Path.Combine(d.FullName, "sema"))) d = d.Parent;
        return d?.FullName ?? env.ContentRootPath;
    }
}
