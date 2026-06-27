using System.Text.Json;
using System.Text.RegularExpressions;
using Dapper;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// Asistan araçları (plan-20 Faz-1): sql_sorgu (salt-okuma + PII maske), sema_oku, ornek_sql_bul (golden-record),
/// gorev_* (GorevService), sabah_brifingi (MIMBAL entegrasyonu). LLM tool-use ile çağrılır; AsistanService loop çalıştırır.
/// </summary>
public sealed class AsistanAraclar(Db db, GorevService gorev, TakvimMailAraclar takvimMail, AsistanBellekService bellek, GorusmeService gorusme, SabahService sabah, IHostEnvironment env, ILogger<AsistanAraclar> log)
{
    private const int SatirLimit = 60;
    private string RepoKok => BulRepoKok();

    /// <summary>LLM'e sunulan araç tanımları (JSON Schema parametreli).</summary>
    public IReadOnlyList<LlmArac> Tanimlar() =>
    [
        new("sql_sorgu",
            "BKM SQL Server'da SALT-OKUMA (SELECT) sorgusu çalıştırır, sonucu döndürür. Ciro/stok/kargo/müşteri sayısı vb. veri sorularında kullan. Sorgu sema kurallarına uymalı (KDV-hariç net, iade-netleme). Yazma/DDL YASAK.",
            new { type = "object", properties = new { sql = new { type = "string", description = "Tek SELECT/WITH sorgusu (DMY tarih, NOLOCK)." } }, required = new[] { "sql" } }),
        new("sema_oku",
            "Semantik katmanı (sema/*.yaml) okur — doğru tablo/join/kod/metrik için. SQL yazmadan ÖNCE ilgili sema'yı oku. dosya: entities|bridges|codes|metrics (boş=hepsi özet).",
            new { type = "object", properties = new { dosya = new { type = "string", description = "entities|bridges|codes|metrics veya boş" } } }),
        new("ornek_sql_bul",
            "Arşivlenmiş örnek SQL'lerde (sorgular/) konuya benzer sorgu arar — golden-record few-shot. SQL yazmadan önce benzer doğrulanmış örnek bul.",
            new { type = "object", properties = new { konu = new { type = "string", description = "Aranan konu/anahtar kelime (ör. 'kargo iade', 'kategori ciro')" } }, required = new[] { "konu" } }),
        new("gorev_taslak_oner",
            "Kullanıcının söylediği iş/not/fikri yapılandırılmış GÖREV TASLAĞINA çevirip ONAYA sunar (otomatik KAYDETMEZ — kullanıcı Kaydet/Ata/Düzelt ile onaylar). Kullanıcı bir yapılacak/hatırlatma/proje söyleyince çağır.",
            new { type = "object", properties = new {
                baslik = new { type = "string", description = "Net, aksiyon-odaklı başlık" },
                aciklama = new { type = "string", description = "2-3 cümle somut açıklama" },
                oncelik = new { type = "string", description = "Düşük | Orta | Yüksek" },
                atanan = new { type = "string", description = "Önerilen sorumlu (rol/kişi)" },
                bitti = new { type = "string", description = "Bitti sayılır: ölçülebilir kriter" },
                son_tarih = new { type = "string", description = "Son tarih dd.MM.yyyy (kullanıcı 'cuma'ya kadar' derse BUGÜN bağlamından çöz; yoksa boş)" },
                acik_soru = new { type = "string", description = "Eksik/belirsiz bilgi varsa soru; yoksa boş" },
            }, required = new[] { "baslik" } }),
        new("gorev_listele",
            "Açık görevleri listeler (kapatılmamış).",
            new { type = "object", properties = new { } }),
        new("secenek_sun",
            "Kullanıcıya NETLEŞTİRME sorusu sorarken AÇIK/SONLU seçenekler varsa (online mı yüz yüze mi, evet/hayır, A/B/C) düz metin yerine bunu kullan — kullanıcı tıklayıp seçer (az yazma). Serbest cevap gerekiyorsa (e-posta, isim, tarih) KULLANMA, normal sor.",
            new { type = "object", properties = new {
                soru = new { type = "string", description = "Kısa netleştirme sorusu" },
                secenekler = new { type = "array", items = new { type = "string" }, description = "2-5 tıklanır seçenek" },
            }, required = new[] { "soru", "secenekler" } }),
        new("bellek_yaz",
            "Kullanıcının KALICI tercih/kural/düzeltmesini ya da sık tekrarlanan gerçeği belleğe yazar (oturumlar arası kalır). READ YOK — bellek zaten prompt başında. Kullan: 'bundan sonra şöyle yap', kullanıcı seni düzeltince, veya aynı şeyi 2.+ kez sorunca. PII/finansal rakam YAZMA — sadece tercih/davranış/sabit gerçek.",
            new { type = "object", properties = new {
                action = new { type = "string", description = "ekle | degistir | sil" },
                tip = new { type = "string", description = "tercih (davranış/kural) | gercek (sabit bilgi)" },
                icerik = new { type = "string", description = "Tek satır, kısa, kalıcı ifade (ekle/degistir için)" },
                eslesme = new { type = "string", description = "degistir/sil için: değişecek mevcut girdinin bir kısmı (substring)" },
            }, required = new[] { "action" } }),
        new("gecmis_ara",
            "Geçmiş konuşmalarda konu/terim arar (token yükü olmadan — bellek değil, arşiv). 'geçen ay ne demiştik', 'X hakkında daha önce ne konuştuk'. Belleğe sorma (bellek zaten yukarıda).",
            new { type = "object", properties = new {
                terim = new { type = "string", description = "Aranacak anahtar kelime" },
                adet = new { type = "integer", description = "Kaç sonuç (varsayılan 6)" },
            }, required = new[] { "terim" } }),
        // ── Faz-2: Google Takvim + Gmail ──
        new("takvim_listele",
            "Kullanıcının Google Takvim'indeki yaklaşan etkinlikleri listeler (okuma). 'bu hafta ne var', 'yarın programım' gibi.",
            new { type = "object", properties = new { gun_sayisi = new { type = "integer", description = "Kaç günü göster (varsayılan 7)" } } }),
        new("takvim_etkinlik_oner",
            "Toplantı/etkinlik OLUŞTURMA önerisi hazırlar ve ONAYA sunar (otomatik OLUŞTURMAZ — kullanıcı Onayla der). 'cuma 14:00 toplantı ayarla' gibi. Zamanları ISO yaz: yyyy-MM-ddTHH:mm.",
            new { type = "object", properties = new {
                baslik = new { type = "string", description = "Etkinlik başlığı" },
                baslangic = new { type = "string", description = "Başlangıç: yyyy-MM-ddTHH:mm (yerel saat)" },
                bitis = new { type = "string", description = "Bitiş: yyyy-MM-ddTHH:mm (boşsa +1 saat)" },
                tur = new { type = "string", description = "online (Google Meet linki) | yuzyuze (konum). Kullanıcıya SOR, uydurma." },
                katilimcilar = new { type = "string", description = "Davetli e-postaları, virgülle (opsiyonel)" },
                aciklama = new { type = "string", description = "Açıklama (opsiyonel)" },
                konum = new { type = "string", description = "Konum — yüz yüzeyse zorunlu (opsiyonel)" },
            }, required = new[] { "baslik", "baslangic" } }),
        new("mail_ozet",
            "Gmail gelen kutusunu okuyup özet döndürür (okuma). 'bugünkü mailler', 'X'ten gelen var mı'. sorgu = Gmail arama (boş=son 7 gün inbox).",
            new { type = "object", properties = new {
                sorgu = new { type = "string", description = "Gmail arama sorgusu (ör. 'from:x@y.com', 'is:unread'); boş=son 7 gün" },
                adet = new { type = "integer", description = "Kaç mail (varsayılan 8)" },
            } }),
        new("mail_taslak_oner",
            "Mail GÖNDERME taslağı hazırlar ve ONAYA sunar (otomatik GÖNDERMEZ — kullanıcı Gönder der). Gövdeye müşteri verisi/PII gömme. 'X'e şu konuda yaz' gibi.",
            new { type = "object", properties = new {
                kime = new { type = "string", description = "Alıcı e-posta" },
                konu = new { type = "string", description = "Konu" },
                govde = new { type = "string", description = "Mail gövdesi (Türkçe, nazik)" },
            }, required = new[] { "kime", "govde" } }),
        new("sabah_brifingi",
            "Bugünün Sabah Dikkat Listesini üretir: dünkü mağaza cirosu (WoW + MTD hedef) + stockout kategori özeti. 'Bugün ne var', 'sabah brifingi', 'dünkü ciro' gibi ifadelerde kullan.",
            new { type = "object", properties = new { } }),
    ];

    /// <summary>secenek_sun argümanları → (soru, seçenek listesi). UI tıklanır butonlar gösterir.</summary>
    public (string Soru, List<string> Secenekler) SecenekKur(JsonElement args)
    {
        var soru = Arg(args, "soru") ?? "Hangisi?";
        var liste = new List<string>();
        if (args.ValueKind == JsonValueKind.Object && args.TryGetProperty("secenekler", out var s) && s.ValueKind == JsonValueKind.Array)
            foreach (var e in s.EnumerateArray())
            {
                var v = e.ValueKind == JsonValueKind.String ? e.GetString() : e.ToString();
                if (!string.IsNullOrWhiteSpace(v)) liste.Add(v!.Trim());
            }
        return (soru, liste);
    }

    /// <summary>Onay-bekleyen aksiyon önerisi (görev/etkinlik/mail) → AsistanOneri (UI onay kartı + onayda çalıştırılacak veri).</summary>
    public AsistanOneri OneriKur(string ad, JsonElement args) => ad switch
    {
        "takvim_etkinlik_oner" => new("etkinlik", EtkinlikOzet(args), args),
        "mail_taslak_oner"     => new("mail", MailOzetKart(args), args),
        _                       => new("gorev", TaslakKur(args), args),
    };

    private static string EtkinlikOzet(JsonElement a)
    {
        var sb = new System.Text.StringBuilder();
        sb.Append("📅 ").Append(Arg(a, "baslik") ?? "Etkinlik").Append('\n');
        sb.Append("🕒 ").Append(Arg(a, "baslangic") ?? "—");
        var bit = Arg(a, "bitis"); if (!string.IsNullOrWhiteSpace(bit)) sb.Append(" → ").Append(bit);
        var yuzyuze = string.Equals(Arg(a, "tur"), "yuzyuze", StringComparison.OrdinalIgnoreCase);
        sb.Append(yuzyuze ? "\n🏢 Yüz yüze" : "\n💻 Online (Meet linki eklenecek)");
        var kat = Arg(a, "katilimcilar"); if (!string.IsNullOrWhiteSpace(kat)) sb.Append("\n👥 ").Append(kat);
        var kon = Arg(a, "konum"); if (!string.IsNullOrWhiteSpace(kon)) sb.Append("\n📍 ").Append(kon);
        var ack = Arg(a, "aciklama"); if (!string.IsNullOrWhiteSpace(ack)) sb.Append("\n📝 ").Append(ack);
        return sb.ToString();
    }

    private static string MailOzetKart(JsonElement a)
    {
        var sb = new System.Text.StringBuilder();
        sb.Append("✉️ Kime: ").Append(Arg(a, "kime") ?? "—").Append('\n');
        sb.Append("Konu: ").Append(Arg(a, "konu") ?? "(konu yok)").Append("\n\n");
        sb.Append(Arg(a, "govde") ?? "");
        return sb.ToString();
    }

    /// <summary>gorev_taslak_oner argümanlarını GorevService.Kaydet'in beklediği 📋/📝/⚡/👤 metnine çevirir (onaya sunulur).</summary>
    public string TaslakKur(JsonElement args)
    {
        string baslik = Arg(args, "baslik") ?? "Görev";
        string aciklama = Arg(args, "aciklama") ?? "";
        string oncelik = Arg(args, "oncelik") ?? "Orta";
        string? atanan = Arg(args, "atanan");
        string? bitti = Arg(args, "bitti");
        string? acikSoru = Arg(args, "acik_soru");
        var sb = new System.Text.StringBuilder();
        sb.Append("📋 ").Append(baslik.Trim()).Append('\n');
        if (!string.IsNullOrWhiteSpace(aciklama)) sb.Append("📝 ").Append(aciklama.Trim()).Append('\n');
        sb.Append("⚡ Öncelik: ").Append(oncelik.Trim()).Append('\n');
        sb.Append("👤 Önerilen sorumlu: ").Append(string.IsNullOrWhiteSpace(atanan) ? "—" : atanan.Trim()).Append('\n');
        var sonTarih = Arg(args, "son_tarih");
        if (!string.IsNullOrWhiteSpace(sonTarih)) sb.Append("📅 Son tarih: ").Append(sonTarih.Trim()).Append('\n');
        if (!string.IsNullOrWhiteSpace(bitti)) sb.Append("✅ Bitti sayılır: ").Append(bitti.Trim()).Append('\n');
        sb.Append("❓ ").Append(string.IsNullOrWhiteSpace(acikSoru) ? "—" : acikSoru.Trim());
        return sb.ToString();
    }

    /// <summary>Araç çağrısını çalıştır → JSON sonuç (tool turuna geri beslenir).</summary>
    public async Task<string> CalistirAsync(string ad, JsonElement args, CancellationToken ct = default)
    {
        try
        {
            return ad switch
            {
                "sql_sorgu"      => await SqlSorgu(Arg(args, "sql"), ct),
                "sema_oku"       => SemaOku(Arg(args, "dosya")),
                "ornek_sql_bul"  => OrnekSqlBul(Arg(args, "konu")),
                "gorev_listele"  => GorevListele(),
                "takvim_listele" => await takvimMail.TakvimListele(ArgInt(args, "gun_sayisi"), ct),
                "mail_ozet"      => await takvimMail.MailOzet(Arg(args, "sorgu"), ArgInt(args, "adet"), ct),
                "bellek_yaz"     => BellekYaz(args),
                "gecmis_ara"     => GecmisAra(Arg(args, "terim"), ArgInt(args, "adet")),
                "sabah_brifingi" => await SabahBrifingi(ct),
                _ => Hata($"Bilinmeyen araç: {ad}"),
            };
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Araç hatası: {Ad}", ad);
            return Hata($"{ad} çalıştırılamadı: {ex.Message}");
        }
    }

    // ── sql_sorgu: guard → çalıştır → PII maske → satır limit ──
    private async Task<string> SqlSorgu(string? sql, CancellationToken ct)
    {
        var (ok, sebep) = SaltOkumaGuard.Dogrula(sql);
        if (!ok) { log.LogWarning("Asistan sql_sorgu REDDEDİLDİ ({Sebep}): {Sql}", sebep, Kisalt(sql ?? "", 400)); return Hata($"Sorgu reddedildi (güvenlik): {sebep}"); }

        log.LogInformation("Asistan sql_sorgu çalıştırılıyor: {Sql}", Kisalt(sql!, 600));
        await using var conn = await db.OpenAsync();
        var rows = (await conn.QueryAsync(sql!, commandTimeout: 30)).Cast<IDictionary<string, object>>().Take(SatirLimit).ToList();
        var maskeli = rows.Select(r => r.ToDictionary(kv => kv.Key, kv => (object?)Maskele(kv.Key, kv.Value))).ToList();
        log.LogInformation("Asistan sql_sorgu sonuç: {Satir} satır", maskeli.Count);
        return JsonSerializer.Serialize(new { satir = maskeli.Count, limit = SatirLimit, veri = maskeli });
    }

    // PII maske: müşteri adı/telefon/kart kolonları → Claude/Groq'a maskeli gider (plan-20 KVKK).
    private static object? Maskele(string kolon, object? deger)
    {
        if (deger is null) return null;
        var k = kolon.ToLowerInvariant();
        bool pii = k.Contains("ad") && (k.Contains("musteri") || k.Contains("isim") || k == "ad" || k == "name")
                   || k.Contains("name") || k.Contains("telefon") || k.Contains("phone") || k.Contains("cep")
                   || k.Contains("gsm") || k.Contains("kart") || k.Contains("card") || k.Contains("tckn") || k.Contains("mail");
        if (!pii) return deger;
        var s = deger.ToString() ?? "";
        return s.Length <= 2 ? "***" : s[..1] + new string('*', Math.Min(s.Length - 1, 6));
    }

    private string SemaOku(string? dosya)
    {
        var dir = Path.Combine(RepoKok, "sema");
        var hedef = string.IsNullOrWhiteSpace(dosya) ? null : $"{dosya.Trim()}.yaml";
        try
        {
            if (hedef is not null && File.Exists(Path.Combine(dir, hedef)))
                return JsonSerializer.Serialize(new { dosya = hedef, icerik = Kisalt(File.ReadAllText(Path.Combine(dir, hedef)), 6000) });
            // hepsi → her dosya kırpılmış (LLM token bütçesi/TPM koruması — tam dosya için dosya adı belirt)
            var ozet = new[] { "entities", "codes", "bridges", "metrics" }
                .Where(f => File.Exists(Path.Combine(dir, $"{f}.yaml")))
                .ToDictionary(f => f, f => Kisalt(File.ReadAllText(Path.Combine(dir, $"{f}.yaml")), 2200));
            return JsonSerializer.Serialize(new { sema = ozet, not = "Kırpıldı — tam içerik için dosya:entities|codes|bridges|metrics belirt." });
        }
        catch (Exception ex) { return Hata($"sema okunamadı: {ex.Message}"); }
    }

    // Golden-record: arşiv SQL'lerde konu ara (dosya adı + içerik), ilk birkaçı döndür (few-shot).
    private string OrnekSqlBul(string? konu)
    {
        if (string.IsNullOrWhiteSpace(konu)) return Hata("konu boş");
        var dir = Path.Combine(RepoKok, "sorgular");
        if (!Directory.Exists(dir)) return JsonSerializer.Serialize(new { bulunan = Array.Empty<string>() });
        var kelimeler = konu.ToLowerInvariant().Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var eslesen = Directory.EnumerateFiles(dir, "*.sql", SearchOption.AllDirectories)
            .Select(f => new { f, t = File.ReadAllText(f).ToLowerInvariant() })
            .Select(x => new { x.f, skor = kelimeler.Count(w => Path.GetFileName(x.f).ToLowerInvariant().Contains(w) || x.t.Contains(w)) })
            .Where(x => x.skor > 0).OrderByDescending(x => x.skor).Take(3).ToList();
        var ornekler = eslesen.Select(x => new { dosya = Path.GetFileName(x.f), sql = Kisalt(File.ReadAllText(x.f), 1500) }).ToList();
        return JsonSerializer.Serialize(new { bulunan = ornekler });
    }

    private string GorevListele()
    {
        var liste = gorev.Listele(acikOnly: true).Select(g => new { g.Id, g.Baslik, g.Oncelik, g.Atanan, g.Durum });
        return JsonSerializer.Serialize(new { gorevler = liste });
    }

    // bellek_yaz → AsistanBellekService.Yaz. LimitAsildi'de mevcut girdileri ekle (LLM aynı turda konsolide etsin).
    private string BellekYaz(JsonElement args)
    {
        var sonuc = bellek.Yaz(Arg(args, "action") ?? "", Arg(args, "icerik"), Arg(args, "tip") ?? "tercih", Arg(args, "eslesme"));
        if (sonuc.Durum == BellekSonucDurum.LimitAsildi)
        {
            var tip = string.Equals(Arg(args, "tip"), "gercek", StringComparison.OrdinalIgnoreCase) ? "gercek" : "tercih";
            var mevcut = bellek.Listele().Where(b => b.Tip == tip).Select(b => b.Icerik).ToList();
            return JsonSerializer.Serialize(new { durum = "limit_asildi", mesaj = sonuc.Mesaj, mevcut });
        }
        return JsonSerializer.Serialize(new { durum = sonuc.Durum.ToString(), mesaj = sonuc.Mesaj });
    }

    private string GecmisAra(string? terim, int adet)
    {
        if (string.IsNullOrWhiteSpace(terim)) return Hata("terim boş");
        var bulunan = gorusme.Ara(terim, adet <= 0 ? 6 : adet).Select(g => new { g.Baslik, g.Guncelleme, g.Parca });
        return JsonSerializer.Serialize(new { bulunan });
    }

    private static string Hata(string m) => JsonSerializer.Serialize(new { hata = m });
    private static string Kisalt(string s, int n) => s.Length <= n ? s : s[..n] + "…";
    private static string? Arg(JsonElement a, string ad) =>
        a.ValueKind == JsonValueKind.Object && a.TryGetProperty(ad, out var v) && v.ValueKind != JsonValueKind.Null ? v.ToString() : null;
    private static int ArgInt(JsonElement a, string ad) =>
        a.ValueKind == JsonValueKind.Object && a.TryGetProperty(ad, out var v) && v.ValueKind == JsonValueKind.Number && v.TryGetInt32(out var n) ? n
        : int.TryParse(Arg(a, ad), out var p) ? p : 0;

    private async Task<string> SabahBrifingi(CancellationToken ct)
    {
        var veri = await sabah.GetAsync();
        if (veri.Hata is not null) return Hata($"Veri alınamadı: {veri.Hata}");
        return JsonSerializer.Serialize(new {
            tarih    = veri.Tarih.ToString("dd.MM.yyyy"),
            magazalar = veri.Magazalar.Select(m => new {
                m.Ad, net = (long)m.Net, m.Fis,
                wowYuzde = veri.ToplamWow > 0 ? Math.Round((m.Net - m.Wow) / m.Wow * 100, 1) : 0,
                mtdYuzde = m.Hedef > 0 ? Math.Round(m.Mtd / m.Hedef * 100, 1) : 0,
                mtdNet   = (long)m.Mtd, hedef = (long)m.Hedef,
            }),
            toplamNet    = (long)veri.ToplamNet,
            toplamWowYuzde = veri.ToplamWow > 0 ? Math.Round((veri.ToplamNet - veri.ToplamWow) / veri.ToplamWow * 100, 1) : 0,
            mtdYuzde  = veri.ToplamHedef > 0 ? Math.Round(veri.ToplamMtd / veri.ToplamHedef * 100, 1) : 0,
            stockout  = veri.Stockout,
            uyari     = "Elektronik=spot-mal artefaktı riski; Akademi/Hazırlık/SınavKıyafet=sezon-dışı; sahaf zaten hariç.",
        });
    }

    private string BulRepoKok()
    {
        var d = new DirectoryInfo(env.ContentRootPath);
        while (d is not null && !Directory.Exists(Path.Combine(d.FullName, "sema"))) d = d.Parent;
        return d?.FullName ?? env.ContentRootPath;
    }
}
