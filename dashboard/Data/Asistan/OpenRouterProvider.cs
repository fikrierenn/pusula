using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// OpenRouter sağlayıcı — OpenAI-uyumlu chat/completions + function-calling (plan-21 birincil, 18.06 kullanıcı kararı).
/// Varsayılan model `nex-agi/nex-n2-pro:free` (262K context, free). Tek key ile 28+ ücretsiz model.
/// Free-tier: 20 istek/dk · 50/gün (kredisiz) → 1000/gün ($10 tek seferlik). .env OPENROUTER_API_KEY + OPENROUTER_MODEL.
/// </summary>
public sealed class OpenRouterProvider : ILlmProvider
{
    private readonly IHttpClientFactory _http;
    private readonly ILogger<OpenRouterProvider> _log;
    private readonly string? _key;
    private readonly IReadOnlyList<string> _modeller;   // iç-rotasyon: 429'da sıradaki free model (dayanıklılık)

    public OpenRouterProvider(IHttpClientFactory http, ILogger<OpenRouterProvider> log)
    {
        _http = http; _log = log;
        var env = Db.LoadEnvStatic();
        _key = env.GetValueOrDefault("OPENROUTER_API_KEY");
        // OPENROUTER_MODELS (virgüllü) öncelikli; yoksa tekil OPENROUTER_MODEL; yoksa varsayılan.
        var liste = (env.GetValueOrDefault("OPENROUTER_MODELS") ?? env.GetValueOrDefault("OPENROUTER_MODEL") ?? "nex-agi/nex-n2-pro:free")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Distinct().ToList();
        _modeller = liste.Count > 0 ? liste : ["nex-agi/nex-n2-pro:free"];
        if (string.IsNullOrWhiteSpace(_key)) log.LogWarning("OPENROUTER_API_KEY yok — OpenRouter devre dışı");
    }

    public bool Hazir => !string.IsNullOrWhiteSpace(_key);

    public async Task<LlmYanit> UretAsync(string sistemTalimat, IReadOnlyList<LlmTur> gecmis,
        IReadOnlyList<LlmArac> araclar, CancellationToken ct = default)
    {
        if (!Hazir) throw new InvalidOperationException("OPENROUTER_API_KEY yapılandırılmamış.");
        // İç-rotasyon: model-A 429/503 → model-B (aynı 50/gün havuzu ama anlık rate-limit'i atlatır). Hepsi tükenirse fırlat → Gemini.
        for (int i = 0; i < _modeller.Count; i++)
        {
            try { return await UretBirAsync(_modeller[i], sistemTalimat, gecmis, araclar, ct); }
            catch (HttpRequestException ex) when (KotaHatasi(ex) && i < _modeller.Count - 1)
            {
                _log.LogWarning("OpenRouter {Model} kota/429 — sıradaki modele: {Sonraki}", _modeller[i], _modeller[i + 1]);
            }
        }
        throw new HttpRequestException($"Tüm OpenRouter modelleri tükendi ({_modeller.Count}).");
    }

    // 429/503 (kota/yoğun) veya 404 (model-ID yanlış/kaldırılmış) → sıradaki modele geç. Diğer hatalar (401 key) fırlar.
    private static bool KotaHatasi(HttpRequestException ex) =>
        ex.StatusCode is System.Net.HttpStatusCode.TooManyRequests or System.Net.HttpStatusCode.ServiceUnavailable or System.Net.HttpStatusCode.NotFound;

    private async Task<LlmYanit> UretBirAsync(string model, string sistemTalimat, IReadOnlyList<LlmTur> gecmis,
        IReadOnlyList<LlmArac> araclar, CancellationToken ct)
    {
        var messages = new JsonArray { new JsonObject { ["role"] = "system", ["content"] = sistemTalimat } };
        int callSeq = 0;
        foreach (var t in gecmis) messages.Add(TuruJson(t, ref callSeq));

        var body = new JsonObject { ["model"] = model, ["messages"] = messages };
        if (araclar.Count > 0)
        {
            var tools = new JsonArray();
            foreach (var a in araclar)
                tools.Add(new JsonObject
                {
                    ["type"] = "function",
                    ["function"] = new JsonObject
                    {
                        ["name"] = a.Ad,
                        ["description"] = a.Aciklama,
                        ["parameters"] = JsonNode.Parse(JsonSerializer.Serialize(a.ParametreSema)),
                    },
                });
            body["tools"] = tools;
        }

        var cli = _http.CreateClient();
        cli.Timeout = TimeSpan.FromSeconds(90);
        using var req = new HttpRequestMessage(HttpMethod.Post, "https://openrouter.ai/api/v1/chat/completions")
        {
            Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        req.Headers.Add("Authorization", $"Bearer {_key}");
        req.Headers.Add("HTTP-Referer", "https://bkm.local/asistan");   // OpenRouter sıralama (opsiyonel)
        req.Headers.Add("X-Title", "BKM Asistan");
        using var resp = await cli.SendAsync(req, ct);
        var json = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
        {
            _log.LogError("OpenRouter {Model} HTTP {Code}: {Body}", model, (int)resp.StatusCode, json.Length > 300 ? json[..300] : json);
            throw new HttpRequestException($"OpenRouter hata {(int)resp.StatusCode}", null, resp.StatusCode);
        }

        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("choices", out var choices) || choices.GetArrayLength() == 0)
            throw new HttpRequestException("OpenRouter boş yanıt (choices yok).");
        var msg = choices[0].GetProperty("message");
        string? metin = msg.TryGetProperty("content", out var c) && c.ValueKind == JsonValueKind.String ? c.GetString() : null;
        var cagrilar = new List<LlmAracCagri>();
        if (msg.TryGetProperty("tool_calls", out var tc) && tc.ValueKind == JsonValueKind.Array)
            foreach (var call in tc.EnumerateArray())
            {
                var fn = call.GetProperty("function");
                var ad = fn.GetProperty("name").GetString()!;
                var argStr = fn.TryGetProperty("arguments", out var a) ? a.GetString() ?? "{}" : "{}";
                var id = call.TryGetProperty("id", out var i) ? i.GetString() : null;
                using var argDoc = JsonDocument.Parse(string.IsNullOrWhiteSpace(argStr) ? "{}" : argStr);
                cagrilar.Add(new LlmAracCagri(ad, argDoc.RootElement.Clone(), id));
            }
        return new LlmYanit(string.IsNullOrEmpty(metin) ? null : metin, cagrilar);
    }

    private static JsonObject TuruJson(LlmTur t, ref int callSeq)
    {
        if (t.AracSonuc is { } sonuc)
            return new JsonObject
            {
                ["role"] = "tool",
                ["tool_call_id"] = sonuc.Id ?? $"call_{callSeq}",
                ["content"] = sonuc.IcerikJson,
            };
        if (t.AracCagrilari is { Count: > 0 } cagrilar)
        {
            var arr = new JsonArray();
            foreach (var cg in cagrilar)
            {
                var id = cg.Id ?? $"call_{callSeq++}";
                arr.Add(new JsonObject
                {
                    ["id"] = id,
                    ["type"] = "function",
                    ["function"] = new JsonObject { ["name"] = cg.Ad, ["arguments"] = cg.Argumanlar.GetRawText() },
                });
            }
            return new JsonObject { ["role"] = "assistant", ["content"] = t.Metin, ["tool_calls"] = arr };
        }
        return new JsonObject { ["role"] = t.Rol == "model" ? "assistant" : "user", ["content"] = t.Metin ?? "" };
    }
}
