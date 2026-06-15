using System.Text;
using Dapper;
using LLama;
using LLama.Common;
using LLama.Sampling;
using Microsoft.Data.Sqlite;
using Telegram.Bot;
using Telegram.Bot.Polling;
using Telegram.Bot.Types;
using Telegram.Bot.Types.Enums;

// ── BKM-Asistan POC ── Telegram not → yerel LLM görev taslağı → ONAYLA → SQLite'a kaydet/ata ──
// Gizlilik: model app-içi (LLamaSharp), veri makineden çıkmaz. Görevler asistan.db (SQLite).

var env = LoadEnv();
var token = env.GetValueOrDefault("TELEGRAM_BOT_TOKEN") ?? throw new("TELEGRAM_BOT_TOKEN .env'de yok");
var modelPath = env.GetValueOrDefault("LLM_MODEL_PATH") ?? throw new("LLM_MODEL_PATH .env'de yok");
var gpuLayers = int.TryParse(env.GetValueOrDefault("LLM_GPU_LAYERS"), out var g) ? g : 0;
var allowedUser = long.TryParse(env.GetValueOrDefault("TELEGRAM_USER_ID"), out var uid) ? uid : 0;
if (!File.Exists(modelPath)) throw new($"Model yok: {modelPath}");

// ── SQLite (görev + kişi) ──
var dbPath = Path.Combine(AppContext.BaseDirectory, "asistan.db");
var connStr = $"Data Source={dbPath}";
using (var c = new SqliteConnection(connStr))
{
    c.Open();
    c.Execute("""
        CREATE TABLE IF NOT EXISTS gorevler(
          id INTEGER PRIMARY KEY AUTOINCREMENT, baslik TEXT, aciklama TEXT,
          oncelik TEXT, atanan TEXT, durum TEXT DEFAULT 'Açık', olusturma TEXT);
        CREATE TABLE IF NOT EXISTS kisiler(ad TEXT PRIMARY KEY, iletisim TEXT);
        """);
}

// ── Yerel LLM ──
Console.WriteLine($"Model yükleniyor: {Path.GetFileName(modelPath)} ...");
var mp = new ModelParams(modelPath) { ContextSize = 4096, GpuLayerCount = gpuLayers };
using var weights = LLamaWeights.LoadFromFile(mp);
var executor = new StatelessExecutor(weights, mp);
Console.WriteLine("Model hazır.");

// Akıllı prompt — few-shot örnek + BKM bağlamı. /no_think: Qwen3 düşünme modunu kapat (hızlı+temiz).
const string SYSTEM = """
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

// Örnek (few-shot) — kalite için
const string EX_USER = "özlüce vitrin yenilensin ramazan teması bütçe ayrılsın";
const string EX_ASSISTANT = """
📋 Özlüce vitrin yenileme — Ramazan teması
📝 Özlüce mağaza vitrini Ramazan konseptiyle yenilenecek. Tema kurgusu, malzeme ve montaj için bütçe ayrılmalı. Ramazan öncesi (en geç 2 hafta önce) tamamlanmalı.
⚡ Öncelik: Orta (sezonsal, tarihe bağlı)
👤 Önerilen sorumlu: Mağaza müdürü + Görsel düzenleme
✅ Bitti sayılır: Vitrin kurulmuş, onaylanmış, fotoğraf paylaşılmış
❓ Bütçe üst sınırı ne? Hangi tarihte hazır olmalı?
""";

// Onay bekleyen taslak (chatId → taslak metni)
var pending = new Dictionary<long, string>();

var bot = new TelegramBotClient(token);
var me = await bot.GetMe();
Console.WriteLine($"Bot çalışıyor: @{me.Username}");

using var cts = new CancellationTokenSource();
bot.StartReceiving(HandleUpdate, HandleError,
    new ReceiverOptions { AllowedUpdates = [UpdateType.Message] }, cts.Token);
Console.WriteLine("Durdurmak için Ctrl+C.");
await Task.Delay(-1, cts.Token);

async Task HandleUpdate(ITelegramBotClient c, Update update, CancellationToken ct)
{
    if (update.Message is not { Text: { } text } msg) return;
    var chatId = msg.Chat.Id;
    if (allowedUser != 0 && msg.From?.Id != allowedUser) { await c.SendMessage(chatId, "Yetkisiz.", cancellationToken: ct); return; }
    text = text.Trim();
    var low = text.ToLowerInvariant();

    try
    {
        // ── Komutlar ──
        if (low is "/start" or "/yardim" or "/help")
        {
            await c.SendMessage(chatId,
                "Bana not yaz → görev taslağı çıkarırım. Sonra:\n" +
                "• *kaydet* → görevi kaydet\n• *<isim>'e at* → kişiye ata + kaydet\n• *düzelt: ...* → revize et\n• *iptal*\n\n" +
                "/gorevler — açık görevler\n/kapat <no> — görevi kapat",
                parseMode: ParseMode.Markdown, cancellationToken: ct);
            return;
        }
        if (low is "/gorevler")
        {
            using var db = new SqliteConnection(connStr);
            var rows = db.Query("SELECT id,baslik,oncelik,atanan,durum FROM gorevler WHERE durum<>'Kapalı' ORDER BY id DESC LIMIT 20");
            var sb = new StringBuilder("📋 Açık görevler:\n");
            int n = 0;
            foreach (var r in rows) { n++; sb.Append($"#{r.id} {r.baslik} · {r.oncelik}{(string.IsNullOrEmpty((string?)r.atanan) ? "" : " → " + r.atanan)}\n"); }
            await c.SendMessage(chatId, n == 0 ? "Açık görev yok." : sb.ToString(), cancellationToken: ct);
            return;
        }
        if (low.StartsWith("/kapat"))
        {
            if (int.TryParse(low.Replace("/kapat", "").Trim(), out var gid))
            {
                using var db = new SqliteConnection(connStr);
                var aff = db.Execute("UPDATE gorevler SET durum='Kapalı' WHERE id=@gid", new { gid });
                await c.SendMessage(chatId, aff > 0 ? $"✅ #{gid} kapatıldı." : $"#{gid} bulunamadı.", cancellationToken: ct);
            }
            return;
        }

        // ── Onay aksiyonları (taslak bekliyorsa) ──
        if (pending.TryGetValue(chatId, out var taslak))
        {
            if (low is "kaydet" or "evet" or "ok" or "onayla")
            {
                var id = SaveTask(taslak, null);
                pending.Remove(chatId);
                await c.SendMessage(chatId, $"✅ Görev #{id} kaydedildi.", cancellationToken: ct);
                return;
            }
            if (low is "iptal" or "vazgeç" or "hayır")
            {
                pending.Remove(chatId);
                await c.SendMessage(chatId, "İptal edildi.", cancellationToken: ct);
                return;
            }
            // "<isim>'e at" / "<isim>e at" / "ata <isim>"
            var atanan = ParseAssignee(text);
            if (atanan is not null)
            {
                var id = SaveTask(taslak, atanan);
                pending.Remove(chatId);
                await c.SendMessage(chatId, $"✅ Görev #{id} kaydedildi ve *{atanan}*'a atandı.\n(Not: gerçek bildirim sonraki sürümde — şimdilik kayıt.)", parseMode: ParseMode.Markdown, cancellationToken: ct);
                return;
            }
            if (low.StartsWith("düzelt") || low.StartsWith("revize"))
            {
                var ek = text.Length > 7 ? text[(text.IndexOf(':') + 1)..].Trim() : "";
                await c.SendChatAction(chatId, ChatAction.Typing, cancellationToken: ct);
                var yeni = await Infer($"{pending[chatId]}\n\n[Kullanıcı düzeltmesi: {ek}] — bu düzeltmeyi uygulayıp taslağı yeniden yaz.", ct);
                pending[chatId] = yeni;
                await c.SendMessage(chatId, yeni + "\n\n— *kaydet* · *<isim>'e at* · *düzelt: ...* · *iptal*", parseMode: ParseMode.Markdown, cancellationToken: ct);
                return;
            }
            // taslak beklerken yeni not → eskisini bırak, yeni taslak üret (aşağı düş)
        }

        // ── Yeni not → taslak üret ──
        await c.SendChatAction(chatId, ChatAction.Typing, cancellationToken: ct);
        var draft = await Infer(text, ct);
        pending[chatId] = draft;
        await c.SendMessage(chatId, draft + "\n\n— *kaydet* · *<isim>'e at* · *düzelt: ...* · *iptal*", parseMode: ParseMode.Markdown, cancellationToken: ct);
    }
    catch (Exception ex)
    {
        await c.SendMessage(chatId, $"Hata: {ex.Message}", cancellationToken: ct);
    }
}

Task HandleError(ITelegramBotClient c, Exception ex, HandleErrorSource src, CancellationToken ct)
{ Console.WriteLine($"[tg] {ex.Message}"); return Task.CompletedTask; }

// Atama komutu yakala: "X'e at", "X'a at", "Xe at", "ata X", "X kişisine at"
static string? ParseAssignee(string text)
{
    var t = System.Text.RegularExpressions.Regex.Replace(text.Trim(), @"^(kaydet|onayla)\s+", "", System.Text.RegularExpressions.RegexOptions.IgnoreCase).Trim();
    var low = t.ToLowerInvariant();

    var Rx = System.Text.RegularExpressions.RegexOptions.IgnoreCase;
    // "ata Murat"
    var m = System.Text.RegularExpressions.Regex.Match(t, @"^ata\s+(.+)$", Rx);
    if (m.Success) return Clean(m.Groups[1].Value);
    // EN SAĞLAM: apostrof + ek + at → "Murat'a at", "Emre'ye at" → apostrof öncesi isim
    m = System.Text.RegularExpressions.Regex.Match(t, @"^(.+?)['’]\w*\s+at$", Rx);
    if (m.Success) return Clean(m.Groups[1].Value);
    // apostrofsuz son çare: "X at" (tek-iki kelime isim + at)
    m = System.Text.RegularExpressions.Regex.Match(t, @"^(\S+)\s+at$", Rx);
    if (m.Success && !m.Groups[1].Value.Equals("kaydet", StringComparison.OrdinalIgnoreCase)) return Clean(m.Groups[1].Value);

    return null;

    static string? Clean(string s)
    {
        s = s.Replace("'", "").Replace("’", "").Trim();
        if (s.Length is < 2 or > 40 || s.Contains('\n')) return null;
        return char.ToUpper(s[0]) + s[1..];
    }
}

// SQLite görev kaydı (taslak metninden başlık/açıklama/öncelik ayıkla)
long SaveTask(string draft, string? atanan)
{
    var lines = draft.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    string baslik = "", oncelik = "Orta";
    var aciklama = new StringBuilder();
    foreach (var l in lines)
    {
        if (l.StartsWith("📋")) baslik = l[2..].Trim();
        else if (l.StartsWith("📝")) aciklama.Append(l[2..].Trim());
        else if (l.StartsWith("⚡")) oncelik = l.Contains("Yüksek") ? "Yüksek" : l.Contains("Düşük") ? "Düşük" : "Orta";
    }
    if (baslik.Length == 0) baslik = lines.FirstOrDefault() ?? "Görev";
    using var db = new SqliteConnection(connStr);
    db.Open();
    db.Execute("INSERT INTO gorevler(baslik,aciklama,oncelik,atanan,olusturma) VALUES(@baslik,@aciklama,@oncelik,@atanan,@t)",
        new { baslik, aciklama = aciklama.ToString(), oncelik, atanan, t = DateTime.Now.ToString("dd.MM.yyyy HH:mm") });
    return db.ExecuteScalar<long>("SELECT last_insert_rowid()");
}

async Task<string> Infer(string userNote, CancellationToken ct)
{
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
    var sb = new StringBuilder();
    await foreach (var tok in executor.InferAsync(prompt, inf, ct)) sb.Append(tok);
    return sb.ToString().Replace("<|im_end|>", "").Replace("<think>", "").Replace("</think>", "").Trim();
}

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
        map[line[..i].Trim()] = line[(i + 1)..].Trim().Trim('"');
    }
    return map;
}
