using LLama;
using LLama.Common;
using LLama.Sampling;
using Telegram.Bot;
using Telegram.Bot.Polling;
using Telegram.Bot.Types;
using Telegram.Bot.Types.Enums;

// ── BKM-Asistan POC ── Telegram'a not yaz → yerel LLM (LLamaSharp) görev taslağına çevirir ──
// Gizlilik: model app-içi (LLamaSharp/llama.cpp), veri hiçbir yere gitmez.

// 1. Config (repo kökü .env — dashboard ile aynı kaynak)
var env = LoadEnv();
var token = env.GetValueOrDefault("TELEGRAM_BOT_TOKEN") ?? throw new("TELEGRAM_BOT_TOKEN .env'de yok (BotFather → /newbot)");
var modelPath = env.GetValueOrDefault("LLM_MODEL_PATH") ?? throw new("LLM_MODEL_PATH .env'de yok (GGUF model dosyası)");
var allowedUser = long.TryParse(env.GetValueOrDefault("TELEGRAM_USER_ID"), out var uid) ? uid : 0; // tek-kullanıcı whitelist (0=herkes, POC)
var gpuLayers = int.TryParse(env.GetValueOrDefault("LLM_GPU_LAYERS"), out var g) ? g : 0; // CUDA backend varsa >0

if (!File.Exists(modelPath)) throw new($"Model bulunamadı: {modelPath}\nİndir: huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF → qwen2.5-3b-instruct-q4_k_m.gguf");

// 2. Yerel LLM yükle (bir kez — ağır)
Console.WriteLine($"Model yükleniyor: {Path.GetFileName(modelPath)} ...");
var mp = new ModelParams(modelPath) { ContextSize = 4096, GpuLayerCount = gpuLayers };
using var weights = LLamaWeights.LoadFromFile(mp);
var executor = new StatelessExecutor(weights, mp);
Console.WriteLine("Model hazır.");

const string SYSTEM = """
Sen BKM Kitap CFO'sunun asistanısın. Kullanıcı sana kısa, dağınık bir not/fikir yazar.
Görevin: bu notu NET bir GÖREV TASLAĞINA dönüştür. Şu formatta Türkçe yanıtla:

📋 Başlık: <kısa, net>
📝 Açıklama: <notu genişlet, net cümleler>
⚡ Öncelik: <Düşük/Orta/Yüksek>
✅ Kabul kriteri: <bittiğini nasıl anlarız>
❓ Açık sorular: <varsa, yoksa "yok">

Kısa ve öz ol. Uydurma detay ekleme; notta olmayan bilgiyi "❓ Açık sorular" altına yaz.
""";

// 3. Telegram bot
var bot = new TelegramBotClient(token);
var me = await bot.GetMe();
Console.WriteLine($"Bot çalışıyor: @{me.Username}. Telegram'dan not yaz.");

using var cts = new CancellationTokenSource();
bot.StartReceiving(HandleUpdate, HandleError,
    new ReceiverOptions { AllowedUpdates = [UpdateType.Message] }, cts.Token);

Console.WriteLine("Durdurmak için Ctrl+C.");
await Task.Delay(-1, cts.Token);

async Task HandleUpdate(ITelegramBotClient c, Update update, CancellationToken ct)
{
    if (update.Message is not { Text: { } text } msg) return;
    var chatId = msg.Chat.Id;
    if (allowedUser != 0 && msg.From?.Id != allowedUser)
    {
        await c.SendMessage(chatId, "Yetkisiz kullanıcı.", cancellationToken: ct);
        return;
    }
    if (text.StartsWith('/'))
    {
        await c.SendMessage(chatId, "Bana bir not/fikir yaz, görev taslağına çevireyim.\nÖrnek: \"özlüce vitrin yenilensin ramazan teması bütçe ayrılsın\"", cancellationToken: ct);
        return;
    }

    await c.SendChatAction(chatId, ChatAction.Typing, cancellationToken: ct);
    try
    {
        var reply = await Infer(text, ct);
        await c.SendMessage(chatId, reply, cancellationToken: ct);
    }
    catch (Exception ex)
    {
        await c.SendMessage(chatId, $"Hata: {ex.Message}", cancellationToken: ct);
    }
}

Task HandleError(ITelegramBotClient c, Exception ex, HandleErrorSource src, CancellationToken ct)
{
    Console.WriteLine($"[telegram] {ex.Message}");
    return Task.CompletedTask;
}

// 4. Inference — qwen2.5 ChatML formatı
async Task<string> Infer(string userNote, CancellationToken ct)
{
    var prompt = $"<|im_start|>system\n{SYSTEM}<|im_end|>\n<|im_start|>user\n{userNote}<|im_end|>\n<|im_start|>assistant\n";
    var inf = new InferenceParams
    {
        MaxTokens = 512,
        AntiPrompts = ["<|im_end|>", "<|im_start|>"],
        SamplingPipeline = new DefaultSamplingPipeline { Temperature = 0.4f },
    };
    var sb = new System.Text.StringBuilder();
    await foreach (var tok in executor.InferAsync(prompt, inf, ct))
        sb.Append(tok);
    return sb.ToString().Replace("<|im_end|>", "").Trim();
}

// .env parser (repo kökü — dashboard/Db.cs ile aynı mantık)
static Dictionary<string, string> LoadEnv()
{
    var dir = new DirectoryInfo(AppContext.BaseDirectory);
    while (dir is not null && !File.Exists(Path.Combine(dir.FullName, ".env"))) dir = dir.Parent;
    var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
    var path = dir is null ? null : Path.Combine(dir.FullName, ".env");
    if (path is null || !File.Exists(path)) return map;
    foreach (var raw in File.ReadAllLines(path))
    {
        var line = raw.Trim();
        if (line.Length == 0 || line.StartsWith('#') || !line.Contains('=')) continue;
        var i = line.IndexOf('=');
        var k = line[..i].Trim();
        var v = line[(i + 1)..].Trim().Trim('"');
        if (v.Length > 0) map[k] = v;
    }
    return map;
}
