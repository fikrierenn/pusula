namespace GmDashboard.Data.Asistan;

/// <summary>
/// Birincil (Gemini) → yedek (Groq) geçişli sağlayıcı (plan-20). Birincil 429/quota/hata verirse yedeğe düşer.
/// Gemini free-tier RPD (20/gün) dolunca Groq (cömert) devralır. İkisi de yoksa hata.
/// </summary>
public sealed class FallbackLlmProvider(GeminiProvider birincil, GroqProvider yedek, ILogger<FallbackLlmProvider> log) : ILlmProvider
{
    public bool Hazir => birincil.Hazir || yedek.Hazir;

    public async Task<LlmYanit> UretAsync(string sistemTalimat, IReadOnlyList<LlmTur> gecmis,
        IReadOnlyList<LlmArac> araclar, CancellationToken ct = default)
    {
        if (birincil.Hazir)
        {
            try { return await birincil.UretAsync(sistemTalimat, gecmis, araclar, ct); }
            catch (Exception ex) when (yedek.Hazir)
            {
                log.LogWarning(ex, "Gemini başarısız (muhtemelen quota/429) — Groq yedeğe geçiliyor");
            }
        }
        if (!yedek.Hazir) throw new InvalidOperationException("LLM sağlayıcı yok (GEMINI_API_KEY/GROQ_API_KEY yapılandırılmamış).");
        return await yedek.UretAsync(sistemTalimat, gecmis, araclar, ct);
    }
}
