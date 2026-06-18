using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// Groq sağlayıcı — OpenAI-uyumlu chat/completions + function-calling (plan-20 fallback). Llama 70B, cömert free-tier.
/// Gemini RPD (free 20/gün) dolunca FallbackLlmProvider buna geçer. .env GROQ_API_KEY + GROQ_MODEL.
/// </summary>
public sealed class GroqProvider : ILlmProvider
{
    private readonly IHttpClientFactory _http;
    private readonly ILogger<GroqProvider> _log;
    private readonly string? _key;
    private readonly string _model;

    public GroqProvider(IHttpClientFactory http, ILogger<GroqProvider> log)
    {
        _http = http; _log = log;
        var env = Db.LoadEnvStatic();
        _key = env.GetValueOrDefault("GROQ_API_KEY");
        _model = env.GetValueOrDefault("GROQ_MODEL") ?? "llama-3.3-70b-versatile";
        if (string.IsNullOrWhiteSpace(_key)) log.LogWarning("GROQ_API_KEY yok — Groq fallback devre dışı");
    }

    public bool Hazir => !string.IsNullOrWhiteSpace(_key);

    public async Task<LlmYanit> UretAsync(string sistemTalimat, IReadOnlyList<LlmTur> gecmis,
        IReadOnlyList<LlmArac> araclar, CancellationToken ct = default)
    {
        if (!Hazir) throw new InvalidOperationException("GROQ_API_KEY yapılandırılmamış.");

        var messages = new JsonArray { new JsonObject { ["role"] = "system", ["content"] = sistemTalimat } };
        int callSeq = 0;
        foreach (var t in gecmis) messages.Add(TuruJson(t, ref callSeq));

        var body = new JsonObject { ["model"] = _model, ["messages"] = messages };
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
        cli.Timeout = TimeSpan.FromSeconds(60);
        using var req = new HttpRequestMessage(HttpMethod.Post, "https://api.groq.com/openai/v1/chat/completions")
        {
            Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        req.Headers.Add("Authorization", $"Bearer {_key}");
        using var resp = await cli.SendAsync(req, ct);
        var json = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
        {
            _log.LogError("Groq HTTP {Code}: {Body}", (int)resp.StatusCode, json.Length > 300 ? json[..300] : json);
            throw new HttpRequestException($"Groq hata {(int)resp.StatusCode}");
        }

        using var doc = JsonDocument.Parse(json);
        var msg = doc.RootElement.GetProperty("choices")[0].GetProperty("message");
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
