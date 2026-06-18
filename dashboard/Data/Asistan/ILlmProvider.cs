using System.Text.Json;

namespace GmDashboard.Data.Asistan;

/// <summary>LLM sağlayıcı soyutlaması (plan-20) — model-agnostik. Bugün Gemini; Claude/OpenAI/yerel tek satır değişir.</summary>
public interface ILlmProvider
{
    bool Hazir { get; }
    /// <summary>Tool-use turu: geçmiş + araçlar → ya metin ya araç-çağrıları. Loop AsistanService'te.</summary>
    Task<LlmYanit> UretAsync(string sistemTalimat, IReadOnlyList<LlmTur> gecmis, IReadOnlyList<LlmArac> araclar, CancellationToken ct = default);
}

/// <summary>Bir araç tanımı (LLM'e sunulan yetenek). ParametreSema = JSON Schema (object).</summary>
public sealed record LlmArac(string Ad, string Aciklama, object ParametreSema);

/// <summary>Sohbet turu. Rol: "user" | "model" | "tool". AracCagri (model→çağrı) veya AracSonuc (tool→sonuç) opsiyonel.</summary>
public sealed record LlmTur(string Rol, string? Metin = null,
    IReadOnlyList<LlmAracCagri>? AracCagrilari = null, LlmAracSonuc? AracSonuc = null);

/// <summary>LLM'in istediği araç çağrısı. Id: OpenAI/Groq tool_call_id (Gemini'de null — name-based).</summary>
public sealed record LlmAracCagri(string Ad, JsonElement Argumanlar, string? Id = null);

/// <summary>Araç çalıştırma sonucu (tool turu olarak geri beslenir). Id = eşleşen çağrının tool_call_id'si.</summary>
public sealed record LlmAracSonuc(string Ad, string IcerikJson, string? Id = null);

/// <summary>LLM tur çıktısı: metin VE/VEYA araç çağrıları (Gemini ikisini birden verebilir).</summary>
public sealed record LlmYanit(string? Metin, IReadOnlyList<LlmAracCagri> AracCagrilari)
{
    public bool AracIstiyor => AracCagrilari.Count > 0;
}
