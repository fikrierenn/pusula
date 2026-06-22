using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// Z.ai (BigModel) sağlayıcı — OpenAI-uyumlu chat/completions + function-calling (plan-26, 22.06).
/// Free GLM-Flash (glm-4.7-flash / glm-4.5-flash) için. OpenRouterProvider'ın klonu; fark: base-URL api.z.ai,
/// OpenRouter-özel header yok. .env ZAI_API_KEY + ZAI_MODELS (virgüllü; iç-rotasyon 429/404'te sıradaki model).
/// </summary>
public sealed class ZaiProvider : ILlmProvider
{
    private const string Endpoint = "https://api.z.ai/api/paas/v4/chat/completions";
    private readonly IHttpClientFactory _http;
    private readonly ILogger<ZaiProvider> _log;
    private readonly string? _key;
    private readonly IReadOnlyList<string> _modeller;   // iç-rotasyon: 429/404'te sıradaki model

    public ZaiProvider(IHttpClientFactory http, ILogger<ZaiProvider> log)
    {
        _http = http; _log = log;
        var env = Db.LoadEnvStatic();
        _key = env.GetValueOrDefault("ZAI_API_KEY");
        var liste = (env.GetValueOrDefault("ZAI_MODELS") ?? env.GetValueOrDefault("ZAI_MODEL") ?? "glm-4.7-flash,glm-4.5-flash")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Distinct().ToList();
        _modeller = liste.Count > 0 ? liste : ["glm-4.7-flash"];
        if (string.IsNullOrWhiteSpace(_key)) log.LogWarning("ZAI_API_KEY yok — Z.ai devre dışı");
    }

    public bool Hazir => !string.IsNullOrWhiteSpace(_key);

    public async Task<LlmYanit> UretAsync(string sistemTalimat, IReadOnlyList<LlmTur> gecmis,
        IReadOnlyList<LlmArac> araclar, CancellationToken ct = default)
    {
        if (!Hazir) throw new InvalidOperationException("ZAI_API_KEY yapılandırılmamış.");
        for (int i = 0; i < _modeller.Count; i++)
        {
            try { return await UretBirAsync(_modeller[i], sistemTalimat, gecmis, araclar, ct); }
            catch (HttpRequestException ex) when (KotaHatasi(ex) && i < _modeller.Count - 1)
            {
                _log.LogWarning("Z.ai {Model} kota/429 — sıradaki modele: {Sonraki}", _modeller[i], _modeller[i + 1]);
            }
        }
        throw new HttpRequestException($"Tüm Z.ai modelleri tükendi ({_modeller.Count}).");
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

        // GLM-Flash reasoning modeli — "thinking" açıkken token bütçesini reasoning_content'e harcayıp content'i boş bırakır
        // (4.7-flash 800 token'ı tamamen reasoning'e yakıp finish:length döndü). Chat asistanı reasoning istemez → kapat.
        var body = new JsonObject { ["model"] = model, ["messages"] = messages, ["thinking"] = new JsonObject { ["type"] = "disabled" } };
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
        using var req = new HttpRequestMessage(HttpMethod.Post, Endpoint)
        {
            Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        req.Headers.Add("Authorization", $"Bearer {_key}");
        using var resp = await cli.SendAsync(req, ct);
        var json = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
        {
            _log.LogError("Z.ai {Model} HTTP {Code}: {Body}", model, (int)resp.StatusCode, json.Length > 300 ? json[..300] : json);
            throw new HttpRequestException($"Z.ai hata {(int)resp.StatusCode}", null, resp.StatusCode);
        }

        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("choices", out var choices) || choices.GetArrayLength() == 0)
            throw new HttpRequestException("Z.ai boş yanıt (choices yok).");
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
