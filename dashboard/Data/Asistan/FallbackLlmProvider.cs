namespace GmDashboard.Data.Asistan;

/// <summary>
/// Çok-katmanlı sağlayıcı zinciri (plan-21, 18.06): OpenRouter (birincil) → Gemini → Groq.
/// Sıradaki Hazır sağlayıcı denenir; hata/quota verirse bir sonrakine düşülür (loglu, sessiz değil). Hepsi yoksa hata.
/// </summary>
public sealed class FallbackLlmProvider(
    OpenRouterProvider openRouter, GeminiProvider gemini, GroqProvider groq, ILogger<FallbackLlmProvider> log) : ILlmProvider
{
    // Öncelik sırası — OpenRouter birincil (Nex-N2-Pro free, function-calling, büyük context).
    private IEnumerable<(string Ad, ILlmProvider P)> Zincir =>
        [("OpenRouter", openRouter), ("Gemini", gemini), ("Groq", groq)];

    public bool Hazir => Zincir.Any(x => x.P.Hazir);

    public async Task<LlmYanit> UretAsync(string sistemTalimat, IReadOnlyList<LlmTur> gecmis,
        IReadOnlyList<LlmArac> araclar, CancellationToken ct = default)
    {
        var hazirlar = Zincir.Where(x => x.P.Hazir).ToList();
        if (hazirlar.Count == 0)
            throw new InvalidOperationException("LLM sağlayıcı yok (OPENROUTER/GEMINI/GROQ key yapılandırılmamış).");

        for (int i = 0; i < hazirlar.Count; i++)
        {
            var (ad, p) = hazirlar[i];
            try { return await p.UretAsync(sistemTalimat, gecmis, araclar, ct); }
            catch (Exception ex) when (i < hazirlar.Count - 1)
            {
                log.LogWarning(ex, "{Ad} başarısız (quota/hata) — sıradaki sağlayıcıya geçiliyor: {Sonraki}", ad, hazirlar[i + 1].Ad);
            }
        }
        // Son sağlayıcının hatası buraya düşer (yukarıdaki when i<last onu yakalamaz) — ama güvence için:
        throw new HttpRequestException("Tüm LLM sağlayıcıları başarısız.");
    }
}
