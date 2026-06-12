using System.Text;
using LLama;
using LLama.Common;
using LLama.Sampling;

namespace GmDashboard.Data;

/// <summary>
/// Yerel LLM (LLamaSharp / qwen2.5-3b). Model bir kez yüklenir (lazy — ilk istekte).
/// Asistan POC (asistan/Program.cs) mantığı Blazor'a taşındı: few-shot prompt + ChatML inference.
/// ⚠️ StatelessExecutor thread-safe DEĞİL → SemaphoreSlim(1,1) ile seri inference.
/// </summary>
public sealed class LlmService : IAsyncDisposable
{
    private readonly string _modelPath;
    private readonly int _gpuLayers;
    private readonly SemaphoreSlim _sem = new(1, 1);

    private LLamaWeights? _weights;
    private StatelessExecutor? _executor;
    private bool _loaded;
    private string? _loadError;

    public LlmService()
    {
        var env = LoadEnv();
        _modelPath = env.GetValueOrDefault("LLM_MODEL_PATH") ?? "";
        _gpuLayers = int.TryParse(env.GetValueOrDefault("LLM_GPU_LAYERS"), out var g) ? g : 0;
    }

    /// <summary>Model henüz yüklendi mi (UI "yükleniyor" göstergesi için).</summary>
    public bool Loaded => _loaded;

    // ── Akıllı prompt (asistan POC ile birebir) ──
    private const string SYSTEM = """
Sen BKM Kitap'ın (kitap+kırtasiye perakende + e-ticaret, 3 mağaza: FSM/Özlüce/İst.Yolu) CFO asistanısın.
Kullanıcı kısa dağınık bir not yazar. Görevin: notu NET, AKSİYON ODAKLI bir görev taslağına çevir.
- Notta olmayan detayı UYDURMA — eksikse "Açık sorular"a yaz.
- Perakende/operasyon bağlamında SOMUT öneri ekle (bütçe, sorumlu öner, zaman).
- Kısa ve öz. Şu formatta SADECE Türkçe:

📋 <başlık>
📝 <2-3 cümle açıklama, somut>
⚡ Öncelik: <Düşük/Orta/Yüksek + 1 kelime gerekçe>
👤 Önerilen sorumlu: <rol/departman, notta kişi yoksa öner>
✅ Bitti sayılır: <ölçülebilir kriter>
❓ <açık soru veya "—">
""";

    private const string EX_USER = "özlüce vitrin yenilensin ramazan teması bütçe ayrılsın";
    private const string EX_ASSISTANT = """
📋 Özlüce vitrin yenileme — Ramazan teması
📝 Özlüce mağaza vitrini Ramazan konseptiyle yenilenecek. Tema kurgusu, malzeme ve montaj için bütçe ayrılmalı. Ramazan öncesi (en geç 2 hafta önce) tamamlanmalı.
⚡ Öncelik: Orta (sezonsal, tarihe bağlı)
👤 Önerilen sorumlu: Mağaza müdürü + Görsel düzenleme
✅ Bitti sayılır: Vitrin kurulmuş, onaylanmış, fotoğraf paylaşılmış
❓ Bütçe üst sınırı ne? Hangi tarihte hazır olmalı?
""";

    /// <summary>
    /// Nottan görev taslağı üret. duzeltme verilirse mevcut taslağı revize eder.
    /// Model yüklü değilse ilk çağrıda yükler (uzun, ~20sn).
    /// </summary>
    public async Task<string> TaslakUret(string not, string? duzeltme = null)
    {
        await EnsureLoaded();
        if (_executor is null)
            throw new InvalidOperationException(_loadError ?? "Model yüklenemedi.");

        var userNote = string.IsNullOrWhiteSpace(duzeltme)
            ? not
            : $"{not}\n\n[Kullanıcı düzeltmesi: {duzeltme}] — bu düzeltmeyi uygulayıp taslağı yeniden yaz.";

        var prompt =
            $"<|im_start|>system\n{SYSTEM}<|im_end|>\n" +
            $"<|im_start|>user\n{EX_USER}<|im_end|>\n<|im_start|>assistant\n{EX_ASSISTANT}<|im_end|>\n" +
            $"<|im_start|>user\n{userNote}<|im_end|>\n<|im_start|>assistant\n";

        var inf = new InferenceParams
        {
            MaxTokens = 400,
            AntiPrompts = ["<|im_end|>", "<|im_start|>"],
            SamplingPipeline = new DefaultSamplingPipeline { Temperature = 0.5f },
        };

        await _sem.WaitAsync();
        try
        {
            var sb = new StringBuilder();
            await foreach (var tok in _executor.InferAsync(prompt, inf))
                sb.Append(tok);
            return sb.ToString()
                .Replace("<|im_end|>", "").Replace("<|im_start|>", "")
                .Replace("<think>", "").Replace("</think>", "").Trim();
        }
        finally { _sem.Release(); }
    }

    private async Task EnsureLoaded()
    {
        if (_loaded) return;
        await _sem.WaitAsync();
        try
        {
            if (_loaded) return;
            if (string.IsNullOrWhiteSpace(_modelPath) || !File.Exists(_modelPath))
            {
                _loadError = $"Model dosyası bulunamadı: {_modelPath} (.env LLM_MODEL_PATH).";
                _loaded = true;  // tekrar denemeyi engelle — hata sabit
                return;
            }
            var mp = new ModelParams(_modelPath) { ContextSize = 4096, GpuLayerCount = _gpuLayers };
            _weights = LLamaWeights.LoadFromFile(mp);
            _executor = new StatelessExecutor(_weights, mp);
            _loaded = true;
        }
        finally { _sem.Release(); }
    }

    private static Dictionary<string, string> LoadEnv()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, ".env")))
            dir = dir.Parent;
        var path = dir is null ? null : Path.Combine(dir.FullName, ".env");
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (path is null || !File.Exists(path)) return map;
        foreach (var raw in File.ReadAllLines(path))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#') || !line.Contains('=')) continue;
            var i = line.IndexOf('=');
            map[line[..i].Trim()] = line[(i + 1)..].Trim().Trim('"');
        }
        return map;
    }

    public ValueTask DisposeAsync()
    {
        _weights?.Dispose();
        _sem.Dispose();
        return ValueTask.CompletedTask;
    }
}
