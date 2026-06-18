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

    // ── Akıllı prompt (asistan POC ile birebir). public: AsistanService bulut taslak (Gemini→Groq) için aynı format/few-shot'u kullanır. ──
    public const string TaslakSistem = """
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

    public const string TaslakOrnekUser = "özlüce vitrin yenilensin ramazan teması bütçe ayrılsın";
    public const string TaslakOrnekAsistan = """
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
            $"<|im_start|>system\n{TaslakSistem}<|im_end|>\n" +
            $"<|im_start|>user\n{TaslakOrnekUser}<|im_end|>\n<|im_start|>assistant\n{TaslakOrnekAsistan}<|im_end|>\n" +
            $"<|im_start|>user\n{userNote}<|im_end|>\n<|im_start|>assistant\n";

        return await Infer(prompt, maxTokens: 400, temp: 0.5f);
    }

    /// <summary>
    /// CFO panosu verisinden 2-3 cümlelik Türkçe günlük özet üret (akıcı paragraf, madde yok).
    /// veriOzet = anahtar:değer satırları (ciro, WoW, mağaza trendleri, iade). Model uydurmaz, sadece veriyi yorumlar.
    /// </summary>
    public async Task<string> GunOzetiUret(string veriOzet)
    {
        await EnsureLoaded();
        if (_executor is null)
            throw new InvalidOperationException(_loadError ?? "Model yüklenemedi.");

        const string sys = """
Sen BKM Kitap'ın (kitap+kırtasiye perakende + e-ticaret, 3 mağaza: FSM/Özlüce/İst.Yolu) CFO asistanısın.
Sana günlük pano verisi verilir. Görevin: 2-3 cümlelik AKICI Türkçe özet yaz.
KESİN KURALLAR:
- SADECE verideki sayıları kullan, hiçbir rakam UYDURMA, toplama/çıkarma YAPMA.
- Yönü ASLA ters çevirme: veride "ARTIŞ" yazan arttı, "DÜŞÜŞ" yazan düştü demektir. Bunu karıştırma.
- En dikkat çeken artışı/düşüşü ve online kanalın gücünü vurgula.
- Madde işareti/başlık YOK, tek akıcı paragraf. Kısa, net, yönetici diliyle.
- Sayıları verideki biçimiyle yaz (₺ ve % ile). Veride olmayan metrik EKLEME.
""";
        const string exUser = "Dönem: Dün (12.06.2026)\nToplam ciro: 4.200.000 ₺ (önceki güne göre %5,0 ARTIŞ)\nMağaza cirosu: 1.800.000 ₺ · Online ciro: 2.400.000 ₺ (online payı %57)\nMağaza trendleri (önceki güne göre):\n  - Özlüce: 900.000 ₺, %8,0 ARTIŞ\n  - FSM: 600.000 ₺, %3,0 DÜŞÜŞ\n  - İst.Yolu: 300.000 ₺, %15,0 DÜŞÜŞ\nİade: 30.000 ₺ (ciroya oran %0,7)";
        const string exAssistant = "Dün ciro 4.200.000 ₺ ile önceki güne göre %5,0 arttı; online kanal 2.400.000 ₺ ve %57 payla büyümeyi taşıyor. İst.Yolu %15,0 düşüşle dikkat çekiyor, Özlüce %8,0 artışla öne çıkıyor. İade oranı %0,7 ile sağlıklı seviyede.";

        var prompt =
            $"<|im_start|>system\n{sys}<|im_end|>\n" +
            $"<|im_start|>user\n{exUser}<|im_end|>\n<|im_start|>assistant\n{exAssistant}<|im_end|>\n" +
            $"<|im_start|>user\n{veriOzet}<|im_end|>\n<|im_start|>assistant\n";

        return await Infer(prompt, maxTokens: 220, temp: 0.4f);
    }

    /// <summary>
    /// Müşteri sadakat panosu verisinden 3-4 cümlelik Türkçe yorum + 1 somut aksiyon üret.
    /// veriOzet = anahtar:değer satırları (tekrar alış, Pareto konsantrasyon, kart etkisi, RFM geçiş, win-back).
    /// Model uydurmaz, sadece veriyi yorumlar (GunOzetiUret ile aynı disiplin).
    /// </summary>
    public async Task<string> SadakatYorumUret(string veriOzet)
    {
        await EnsureLoaded();
        if (_executor is null)
            throw new InvalidOperationException(_loadError ?? "Model yüklenemedi.");

        const string sys = """
Sen BKM Kitap'ın (kitap+kırtasiye perakende + e-ticaret, 3 mağaza) CFO asistanısın.
Sana müşteri SADAKAT panosu verisi verilir. Görevin: 3-4 cümlelik AKICI Türkçe yorum + sonda 1 somut aksiyon.
KESİN KURALLAR:
- SADECE verideki sayıları kullan, hiçbir rakam UYDURMA, hesap YAPMA.
- Pareto konsantrasyonu yüksekse (az müşteri çok ciro) bağımlılık riskini vurgula.
- Tekrar alış oranı düşükse ilk alışı ikinciye çevirme fırsatını söyle.
- Win-back potansiyelini ₺ ile vurgula (geri kazanılabilir ciro).
- Madde işareti/başlık YOK, tek akıcı paragraf, yönetici dili. Sayıları verideki biçimiyle (₺/%) yaz.
""";
        const string exUser = "Tekrar alış oranı: %38,0 (Frq>1, 90.000 müşteri / 237.000)\n2. alışa ortalama süre: 95 gün\nMüşteri konsantrasyonu: ilk %10 müşteri cironun %62,0'ını, ilk %20 %78,0'ini yapıyor\nSadakat kartı: Kartlı ATV 2.100 ₺ vs Kartsız ATV 5.400 ₺\nWin-back: 200 müşteri, toplam 1.250.000 ₺ geri kazanılabilir (90g+ hareketsiz)";
        const string exAssistant = "Müşteri tabanı dar bir çekirdeğe bağımlı: ilk %20 müşteri cironun %78,0'ini taşıyor, bu da konsantrasyon riski demek. Tekrar alış oranı %38,0 ve ikinci alış ortalama 95 gün sürüyor — ilk alışı ikinciye çevirecek hatırlatma/kampanya alanı geniş. Kartsız müşterinin ATV'si (5.400 ₺) kartlıdan yüksek; kurumsal/toptan ağırlığı gösteriyor. Aksiyon: 1.250.000 ₺'lik win-back listesindeki 200 hareketsiz müşteriye kişisel teklifle dönüş kampanyası başlat.";

        var prompt =
            $"<|im_start|>system\n{sys}<|im_end|>\n" +
            $"<|im_start|>user\n{exUser}<|im_end|>\n<|im_start|>assistant\n{exAssistant}<|im_end|>\n" +
            $"<|im_start|>user\n{veriOzet}<|im_end|>\n<|im_start|>assistant\n";

        return await Infer(prompt, maxTokens: 260, temp: 0.4f);
    }

    /// <summary>Ortak ChatML inference döngüsü (M-10 DRY) — seri (SemaphoreSlim), ChatML token temizliği. Çağıran _executor'ı null-check eder + prompt/maxTokens/temp verir.</summary>
    private async Task<string> Infer(string prompt, int maxTokens, float temp)
    {
        var inf = new InferenceParams
        {
            MaxTokens = maxTokens,
            AntiPrompts = ["<|im_end|>", "<|im_start|>"],
            SamplingPipeline = new DefaultSamplingPipeline { Temperature = temp },
        };
        await _sem.WaitAsync();
        try
        {
            var sb = new StringBuilder();
            await foreach (var tok in _executor!.InferAsync(prompt, inf))
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
