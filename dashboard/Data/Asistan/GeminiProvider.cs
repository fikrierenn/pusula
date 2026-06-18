using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// Gemini (Google) sağlayıcı — raw REST generateContent + function-calling (plan-20). Bağımlılık yok (HttpClient).
/// .env GEMINI_API_KEY + GEMINI_MODEL. Veri Google'a gider → PII-maske AsistanAraclar'da (ham müşteri verisi göndermez).
/// </summary>
public sealed class GeminiProvider : ILlmProvider
{
    private readonly IHttpClientFactory _http;
    private readonly ILogger<GeminiProvider> _log;
    private readonly string? _key;
    private readonly string _model;

    public GeminiProvider(IHttpClientFactory http, ILogger<GeminiProvider> log)
    {
        _http = http; _log = log;
        var env = Db.LoadEnvStatic();
        _key = env.GetValueOrDefault("GEMINI_API_KEY");
        _model = env.GetValueOrDefault("GEMINI_MODEL") ?? "gemini-2.0-flash";
        if (string.IsNullOrWhiteSpace(_key)) log.LogWarning("GEMINI_API_KEY yok — asistan LLM devre dışı");
    }

    public bool Hazir => !string.IsNullOrWhiteSpace(_key);

    public async Task<LlmYanit> UretAsync(string sistemTalimat, IReadOnlyList<LlmTur> gecmis,
        IReadOnlyList<LlmArac> araclar, CancellationToken ct = default)
    {
        if (!Hazir) throw new InvalidOperationException("GEMINI_API_KEY yapılandırılmamış.");

        // ── İstek gövdesi (Gemini v1beta generateContent) ──
        var contents = new JsonArray();
        foreach (var t in gecmis)
            contents.Add(TuruJson(t));

        var body = new JsonObject
        {
            ["contents"] = contents,
            ["systemInstruction"] = new JsonObject { ["parts"] = new JsonArray { new JsonObject { ["text"] = sistemTalimat } } },
        };
        if (araclar.Count > 0)
        {
            var decls = new JsonArray();
            foreach (var a in araclar)
                decls.Add(new JsonObject
                {
                    ["name"] = a.Ad,
                    ["description"] = a.Aciklama,
                    ["parameters"] = JsonNode.Parse(JsonSerializer.Serialize(a.ParametreSema)),
                });
            body["tools"] = new JsonArray { new JsonObject { ["functionDeclarations"] = decls } };
        }

        var cli = _http.CreateClient();
        cli.Timeout = TimeSpan.FromSeconds(60);
        var url = $"https://generativelanguage.googleapis.com/v1beta/models/{_model}:generateContent?key={_key}";
        using var resp = await cli.PostAsync(url,
            new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"), ct);
        var json = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
        {
            _log.LogError("Gemini HTTP {Code}: {Body}", (int)resp.StatusCode, json.Length > 300 ? json[..300] : json);
            throw new HttpRequestException($"Gemini hata {(int)resp.StatusCode}");
        }

        // ── Yanıt çözümle: parts[] → text + functionCall ──
        using var doc = JsonDocument.Parse(json);
        var parts = doc.RootElement.GetProperty("candidates")[0].GetProperty("content").GetProperty("parts");
        var sb = new StringBuilder();
        var cagrilar = new List<LlmAracCagri>();
        foreach (var p in parts.EnumerateArray())
        {
            if (p.TryGetProperty("text", out var txt)) sb.Append(txt.GetString());
            if (p.TryGetProperty("functionCall", out var fc))
            {
                var ad = fc.GetProperty("name").GetString()!;
                var args = fc.TryGetProperty("args", out var a) ? a.Clone() : default;
                cagrilar.Add(new LlmAracCagri(ad, args));
            }
        }
        return new LlmYanit(sb.Length > 0 ? sb.ToString() : null, cagrilar);
    }

    // Bir turu Gemini content JSON'una çevir.
    private static JsonObject TuruJson(LlmTur t)
    {
        var parts = new JsonArray();
        if (t.AracSonuc is { } sonuc)
        {
            // tool turu → functionResponse
            parts.Add(new JsonObject
            {
                ["functionResponse"] = new JsonObject
                {
                    ["name"] = sonuc.Ad,
                    ["response"] = new JsonObject { ["sonuc"] = JsonNode.Parse(sonuc.IcerikJson) ?? sonuc.IcerikJson },
                },
            });
            return new JsonObject { ["role"] = "function", ["parts"] = parts };
        }
        if (t.AracCagrilari is { Count: > 0 } cagrilar)
        {
            foreach (var c in cagrilar)
                parts.Add(new JsonObject
                {
                    ["functionCall"] = new JsonObject { ["name"] = c.Ad, ["args"] = JsonNode.Parse(c.Argumanlar.GetRawText()) },
                });
        }
        if (t.Metin is not null) parts.Add(new JsonObject { ["text"] = t.Metin });
        return new JsonObject { ["role"] = t.Rol == "model" ? "model" : "user", ["parts"] = parts };
    }
}
