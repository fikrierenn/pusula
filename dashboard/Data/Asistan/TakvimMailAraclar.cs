using System.Text;
using System.Text.Json;
using Google.Apis.Calendar.v3;
using Google.Apis.Calendar.v3.Data;
using Google.Apis.Gmail.v1;
using Google.Apis.Services;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// BKM-Asistan Faz-2 (plan-21) — Google Takvim + Gmail araç implementasyonu. GoogleAuthService'ten UserCredential alır.
/// OKUMA araçları doğrudan (takvim_listele/mail_ozet). DIŞ-AKSİYON (etkinlik oluştur / mail gönder) yalnız CFO onayından sonra çağrılır.
/// </summary>
public sealed class TakvimMailAraclar(GoogleAuthService gauth, ILogger<TakvimMailAraclar> log)
{
    private const string AppAdi = "BKM Asistan";
    private const string TimeZone = "Europe/Istanbul";

    public bool Bagli => gauth.Yapilandirilmis;

    private async Task<CalendarService?> CalAsync(CancellationToken ct)
    {
        var cred = await gauth.KimlikAsync(ct);
        return cred is null ? null : new CalendarService(new BaseClientService.Initializer { HttpClientInitializer = cred, ApplicationName = AppAdi });
    }

    private async Task<GmailService?> GmailAsync(CancellationToken ct)
    {
        var cred = await gauth.KimlikAsync(ct);
        return cred is null ? null : new GmailService(new BaseClientService.Initializer { HttpClientInitializer = cred, ApplicationName = AppAdi });
    }

    // ── OKUMA: yaklaşan etkinlikler ──
    public async Task<string> TakvimListele(int gun, CancellationToken ct = default)
    {
        var svc = await CalAsync(ct);
        if (svc is null) return Hata("Google bağlı değil — önce Asistan'da 'Google'a bağlan'.");
        var req = svc.Events.List("primary");
        req.TimeMinDateTimeOffset = DateTimeOffset.Now;
        req.TimeMaxDateTimeOffset = DateTimeOffset.Now.AddDays(Math.Clamp(gun <= 0 ? 7 : gun, 1, 60));
        req.SingleEvents = true;
        req.OrderBy = EventsResource.ListRequest.OrderByEnum.StartTime;
        req.MaxResults = 25;
        var items = (await req.ExecuteAsync(ct)).Items ?? [];
        var liste = items.Select(e => new
        {
            baslik = e.Summary,
            baslangic = e.Start?.DateTimeDateTimeOffset?.ToString("dd.MM.yyyy HH:mm") ?? e.Start?.Date,
            bitis = e.End?.DateTimeDateTimeOffset?.ToString("HH:mm") ?? e.End?.Date,
            konum = e.Location,
        });
        return JsonSerializer.Serialize(new { etkinlik = liste });
    }

    // ── OKUMA: gelen kutusu özeti (konu/kimden/snippet) ──
    public async Task<string> MailOzet(string? sorgu, int adet, CancellationToken ct = default)
    {
        var svc = await GmailAsync(ct);
        if (svc is null) return Hata("Google bağlı değil — önce Asistan'da 'Google'a bağlan'.");
        var liste = svc.Users.Messages.List("me");
        liste.Q = string.IsNullOrWhiteSpace(sorgu) ? "in:inbox newer_than:7d" : sorgu;
        liste.MaxResults = Math.Clamp(adet <= 0 ? 8 : adet, 1, 20);
        var ids = (await liste.ExecuteAsync(ct)).Messages ?? [];
        var ozetler = new List<object>();
        foreach (var m in ids)
        {
            var get = svc.Users.Messages.Get("me", m.Id);
            get.Format = UsersResource.MessagesResource.GetRequest.FormatEnum.Metadata;
            get.MetadataHeaders = new Google.Apis.Util.Repeatable<string>(new[] { "From", "Subject", "Date" });
            var msg = await get.ExecuteAsync(ct);
            var h = msg.Payload?.Headers ?? [];
            ozetler.Add(new
            {
                kimden = Maskele(h.FirstOrDefault(x => x.Name == "From")?.Value),
                konu = h.FirstOrDefault(x => x.Name == "Subject")?.Value,
                tarih = h.FirstOrDefault(x => x.Name == "Date")?.Value,
                onizleme = msg.Snippet,
            });
        }
        return JsonSerializer.Serialize(new { mail = ozetler });
    }

    // ── DIŞ-AKSİYON (CFO onayı sonrası): etkinlik oluştur + davet ──
    public async Task<(bool Ok, string Mesaj)> EtkinlikOlustur(JsonElement veri, CancellationToken ct = default)
    {
        var svc = await CalAsync(ct);
        if (svc is null) return (false, "Google bağlı değil.");
        if (!DateTimeOffset.TryParse(Str(veri, "baslangic"), out var bas))
            return (false, "Başlangıç zamanı anlaşılamadı.");
        if (!DateTimeOffset.TryParse(Str(veri, "bitis"), out var bit)) bit = bas.AddHours(1);
        var katilimcilar = (Str(veri, "katilimcilar") ?? "")
            .Split(new[] { ',', ';', ' ' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(x => x.Contains('@')).Select(x => new EventAttendee { Email = x }).ToList();
        var ev = new Event
        {
            Summary = Str(veri, "baslik"),
            Description = Str(veri, "aciklama"),
            Location = Str(veri, "konum"),
            Start = new EventDateTime { DateTimeDateTimeOffset = bas, TimeZone = TimeZone },
            End = new EventDateTime { DateTimeDateTimeOffset = bit, TimeZone = TimeZone },
            Attendees = katilimcilar.Count > 0 ? katilimcilar : null,
        };
        try
        {
            var req = svc.Events.Insert(ev, "primary");
            req.SendUpdates = EventsResource.InsertRequest.SendUpdatesEnum.All;   // davet gönder
            var sonuc = await req.ExecuteAsync(ct);
            return (true, $"Etkinlik oluşturuldu: {sonuc.Summary} ({bas:dd.MM.yyyy HH:mm})" + (katilimcilar.Count > 0 ? $", {katilimcilar.Count} davet gönderildi" : ""));
        }
        catch (Exception ex) { log.LogError(ex, "Etkinlik oluşturulamadı"); return (false, "Etkinlik oluşturulamadı."); }
    }

    // ── DIŞ-AKSİYON (CFO onayı sonrası): mail gönder VEYA taslağa kaydet ──
    public async Task<(bool Ok, string Mesaj)> MailGonder(JsonElement veri, bool taslakOnly, CancellationToken ct = default)
    {
        var svc = await GmailAsync(ct);
        if (svc is null) return (false, "Google bağlı değil.");
        var kime = Str(veri, "kime"); var konu = Str(veri, "konu") ?? "(konu yok)"; var govde = Str(veri, "govde") ?? "";
        if (string.IsNullOrWhiteSpace(kime) || !kime.Contains('@')) return (false, "Geçerli alıcı adresi yok.");
        var raw = MimeKur(kime!, konu, govde);
        try
        {
            if (taslakOnly)
            {
                await svc.Users.Drafts.Create(new Google.Apis.Gmail.v1.Data.Draft { Message = new Google.Apis.Gmail.v1.Data.Message { Raw = raw } }, "me").ExecuteAsync(ct);
                return (true, $"Taslak kaydedildi ({kime}). Gmail'den gönderebilirsiniz.");
            }
            await svc.Users.Messages.Send(new Google.Apis.Gmail.v1.Data.Message { Raw = raw }, "me").ExecuteAsync(ct);
            return (true, $"Mail gönderildi: {kime}");
        }
        catch (Exception ex) { log.LogError(ex, "Mail gönderilemedi"); return (false, "Mail gönderilemedi."); }
    }

    // RFC822 MIME → base64url (UTF-8 gövde + RFC2047 konu).
    private static string MimeKur(string kime, string konu, string govde)
    {
        var konuEnc = "=?UTF-8?B?" + Convert.ToBase64String(Encoding.UTF8.GetBytes(konu)) + "?=";
        var mime = $"To: {kime}\r\nSubject: {konuEnc}\r\nContent-Type: text/plain; charset=UTF-8\r\nContent-Transfer-Encoding: 8bit\r\n\r\n{govde}";
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(mime)).Replace('+', '-').Replace('/', '_').TrimEnd('=');
    }

    // Gönderen adresinde isim varsa hafif maske (PII — LLM'e tam ad-soyad gitmesin). Adres domaini kalır.
    private static string? Maskele(string? from)
    {
        if (string.IsNullOrWhiteSpace(from)) return from;
        var i = from.IndexOf('<');
        if (i > 0) { var ad = from[..i].Trim().Trim('"'); return (ad.Length > 1 ? ad[..1] + "***" : "***") + " " + from[i..]; }
        return from;
    }

    private static string? Str(JsonElement e, string ad) =>
        e.ValueKind == JsonValueKind.Object && e.TryGetProperty(ad, out var v) && v.ValueKind != JsonValueKind.Null ? v.ToString() : null;
    private static string Hata(string m) => JsonSerializer.Serialize(new { hata = m });
}
