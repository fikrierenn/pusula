using System.Text.Json;

namespace GmDashboard.Data.Asistan;

/// <summary>Onay bekleyen dış-aksiyon önerisi. Tip: "gorev" | "etkinlik" | "mail". Ozet=karta basılacak metin, Veri=onayda çalıştırılacak argümanlar.</summary>
public sealed record AsistanOneri(string Tip, string Ozet, JsonElement Veri);

/// <summary>Asistan cevabı: metin + araç izi + (varsa) onay önerisi + (varsa) tıklanır seçenekler (netleştirme).</summary>
public sealed record AsistanCevap(string Metin, IReadOnlyList<string> AracIzi, AsistanOneri? Oneri = null, IReadOnlyList<string>? Secenekler = null);

/// <summary>
/// BKM-Asistan tool-use loop (plan-20 Faz-1). Tek akış: kullanıcı mesajı → LLM (Gemini→Groq) niyeti+bağlamı yönetir.
/// İş/not → `gorev_taslak_oner` (onaya sunulur, otomatik kaydetmez). Veri sorusu → sema/sql araçları. learn-claude-code loop deseni.
/// </summary>
public sealed class AsistanService(ILlmProvider llm, AsistanAraclar araclar, AsistanBellekService bellek, ILogger<AsistanService> log)
{
    private const int MaxTur = 6;

    public bool Hazir => llm.Hazir;

    /// <summary>
    /// Araçsız tek-seferlik metin üretimi (pano özetleri/yorumları — Home/Sadakat). Cloud zinciri (OpenRouter→Gemini→Groq).
    /// Yerel qwen'den daha derin yorum. Cloud tümü düşerse fırlar — çağıran sayfa AI-siz özetiyle degrade olur.
    /// </summary>
    public async Task<string> MetinUretAsync(string sistemTalimat, string kullaniciIcerik, CancellationToken ct = default)
    {
        if (!llm.Hazir) throw new InvalidOperationException("LLM yapılandırılmamış.");
        var gecmis = new List<LlmTur> { new("user", kullaniciIcerik) };
        var y = await llm.UretAsync(sistemTalimat, gecmis, [], ct);
        return (y.Metin ?? "").Trim();
    }

    public async Task<AsistanCevap> SorAsync(string soru, List<LlmTur> gecmis, CancellationToken ct = default)
    {
        if (!llm.Hazir) return new("Asistan yapılandırılmamış (GEMINI/GROQ key yok).", []);
        gecmis.Add(new LlmTur("user", soru));
        var iz = new List<string>();
        var tanimlar = araclar.Tanimlar();
        // Tarih bağlamı — LLM bugünü bilmez; "yarın/bu hafta" doğru çözümlenir (yerel saat, tek-makine TR).
        var simdi = DateTime.Now;
        var tarihBag = $"BUGÜN: {simdi:dd.MM.yyyy} {simdi.ToString("dddd", new System.Globalization.CultureInfo("tr-TR"))}, saat {simdi:HH:mm}. 'yarın/bu hafta/gelecek ...' bunu baz al; etkinlik zamanını yyyy-MM-ddTHH:mm yaz.\n\n";
        // Bellek snapshot'ı tur başında BİR KEZ donar (Hermes FROZEN — aynı çağrı içi bellek_yaz prompt'u değiştirmez, sonraki SorAsync'te yansır).
        var snap = bellek.Aktif ? bellek.Snapshot() : null;
        var bellekBag = snap is { ToplamChar: > 0 } && !string.IsNullOrWhiteSpace(snap.Metin) ? snap.Metin + "\n\n" : "";
        var sistem = tarihBag + bellekBag + SistemTalimat;

        for (int tur = 0; tur < MaxTur; tur++)
        {
            LlmYanit yanit;
            try { yanit = await llm.UretAsync(sistem, gecmis, tanimlar, ct); }
            catch (Exception ex)
            {
                log.LogError(ex, "Asistan LLM hatası");
                return new("Üzgünüm, şu an cevap üretemedim (LLM erişim hatası). Tekrar dener misiniz?", iz);
            }

            if (!yanit.AracIstiyor)
            {
                gecmis.Add(new LlmTur("model", yanit.Metin));
                return new(yanit.Metin ?? "(boş cevap)", iz);
            }

            gecmis.Add(new LlmTur("model", yanit.Metin, yanit.AracCagrilari));
            foreach (var cagri in yanit.AracCagrilari)
            {
                iz.Add(cagri.Ad);
                // Netleştirme sorusu (tıklanır seçenekler) → loop'u durdur, kullanıcıya butonlu soru sun.
                if (cagri.Ad == "secenek_sun")
                {
                    var (netSoru, secenekler) = araclar.SecenekKur(cagri.Argumanlar);
                    gecmis.Add(new LlmTur("tool", AracSonuc: new LlmAracSonuc(cagri.Ad, "{\"durum\":\"kullanıcıya soruldu\"}", cagri.Id)));
                    return new(string.IsNullOrWhiteSpace(yanit.Metin) ? netSoru : yanit.Metin!, iz, Secenekler: secenekler);
                }
                // Dış-aksiyon önerisi (görev/etkinlik/mail) → loop'u durdur, kullanıcı onayına sun (otomatik YAPMA).
                if (cagri.Ad is "gorev_taslak_oner" or "takvim_etkinlik_oner" or "mail_taslak_oner")
                {
                    var oneri = araclar.OneriKur(cagri.Ad, cagri.Argumanlar);
                    gecmis.Add(new LlmTur("tool", AracSonuc: new LlmAracSonuc(cagri.Ad, "{\"durum\":\"kullanıcı onayına sunuldu\"}", cagri.Id)));
                    var intro = string.IsNullOrWhiteSpace(yanit.Metin) ? OneriIntro(oneri.Tip) : yanit.Metin!;
                    return new(intro, iz, oneri);
                }
                var sonuc = await araclar.CalistirAsync(cagri.Ad, cagri.Argumanlar, ct);
                gecmis.Add(new LlmTur("tool", AracSonuc: new LlmAracSonuc(cagri.Ad, sonuc, cagri.Id)));
            }
        }
        return new($"İşlem {MaxTur} adımda tamamlanamadı — sadeleştirir misiniz?", iz);
    }

    private static string OneriIntro(string tip) => tip switch
    {
        "etkinlik" => "Bir takvim etkinliği hazırladım — onayını bekliyorum.",
        "mail"     => "Bir mail taslağı hazırladım — onayını bekliyorum.",
        _          => "Bir görev taslağı hazırladım — onayını bekliyorum.",
    };

    // Sistem talimatı — iş/not asistanı birincil; veri sorusu ikincil (araçlar gerektiğinde).
    private const string SistemTalimat = """
        Sen **Genius** — BKM Kitap CFO'sunun lambadan çıkmış akıl danışmanısın (hem "dahi" hem "cin"). Birincil işin: konuşmak, fikir/notu nete çevirmek, görev yönetmek. Kısa, net, hafif esprili ama işte ciddi; yönetici dili. Adın sorulursa "Genius" de.

        NİYET (sen karar ver — bağlamı koru):
        - Kullanıcı bir İŞ / YAPILACAK / FİKİR / HATIRLATMA söylerse (ör. "vitrin yenilensin", "tedarikçiyle toplantı ayarla") → `gorev_taslak_oner` aracıyla yapılandırılmış taslak öner. KAYDETME — kullanıcı onaylar (Kaydet/Ata/Düzelt UI'da).
        - Kullanıcı TAKVİM/TOPLANTI işi derse → "ne var/programım" = `takvim_listele` (oku); "ayarla/oluştur" = `takvim_etkinlik_oner` (ONAYA sunar, otomatik oluşturmaz).
          · Belirsizse SOR (uydurma): (a) ONLINE mı yüz yüze mi? (tur=online→Meet linki / tur=yuzyuze→konum iste), (b) "ekiple/X kişiyle" deyip e-posta verilmediyse "Kimleri davet edeyim? E-postaları?". Eksik bilgiyle öneri kurma, önce netleştir.
        - Kullanıcı MAİL işi derse → "gelen kutusu/özet/X'ten var mı" = `mail_ozet` (oku); "yaz/yanıtla/gönder" = `mail_taslak_oner` (ONAYA sunar, otomatik göndermez). Mail gövdesine müşteri verisi/PII GÖMME.
          · mail_ozet sonucunu KULLANICIYA GERÇEKTEN ÖZETLE — sadece "aldım" DEME. Her mail için: kimden + konu + 1 cümle ne hakkında. Madde madde, kısa, taranabilir.
        - Takvim/mail aracı "Google bağlı değil" derse → kullanıcıya "Asistan'da 'Google'a bağlan'a tıkla" de.
        - Kullanıcı bir VERİ sorusu sorarsa (ciro/stok/kargo/müşteri sayısı) → veri araçlarını kullan (aşağıda). Bu ikincil; gerekmiyorsa kullanma.
        - TAKİP mesajları ("evet", "güncelle", "şunu da ekle", "onu da göster") → önceki konuşmanın DEVAMIDIR. Bağlamı koru, sıfırdan taslak/sorgu başlatma. "evet" = az önce önerdiğin şeyi yap demektir.
        - Tek kelimelik/belirsiz girdiyi taslağa ÇEVİRME — bağlama bak; bağlam yoksa kısa netleştirme sorusu sor.
        - NETLEŞTİRME sorusunda AÇIK/SONLU seçenek varsa (online mı yüz yüze mi, evet/hayır) → düz metin yerine `secenek_sun` ile BUTONLU sor (kullanıcı tıklasın, yazmasın). Serbest cevap (e-posta/isim/tarih) gerekiyorsa normal sor.
        - Kalıcı tercih/kural/düzeltme söylerse ("bundan sonra şöyle yap", "varsayılan X", seni düzeltince) → `bellek_yaz` action=ekle ile KAYDET (görev YAPMA), sonra "tamam, aklımda" de. Aynı şeyi 2.+ kez sorarsa o gerçeği de belleğe yaz. Bellek PII/finansal rakam İÇERMEZ — sadece tercih/davranış/sabit gerçek (rakam her seferinde canlı SQL).
        - bellek_yaz "limit_asildi" dönerse → AYNI turda eski/çakışan girdiyi `bellek_yaz` action=sil veya degistir ile temizle, sonra tekrar ekle.
        - "geçen sefer/daha önce ne demiştik/konuşmuştuk" → `gecmis_ara` (belleğe sorma — bellek zaten yukarıda [GENIUS BELLEK] bloğunda). Bellek bloğundaki tercihleri HER cevapta uygula.

        gorev_taslak_oner ALANLARI: baslik (zorunlu, net), aciklama (2-3 cümle somut), oncelik (Düşük/Orta/Yüksek), atanan (rol/kişi öner), son_tarih (kullanıcı tarih derse dd.MM.yyyy çöz), bitti (ölçülebilir kriter), acik_soru (eksik bilgi varsa; yoksa boş). Notta OLMAYAN detayı UYDURMA → acik_soru'ya yaz.
        - HAM/KISA not gelirse ("vitrin loş", "tedarikçiyi ara") ham notu başlık yapma — ZENGİNLEŞTİR: aciklama'yı somutlaştır, mantıklı sorumlu öner, tarih ima varsa son_tarih çöz, eksikse acik_soru sor.

        KULLANICIYA KONUŞMA (CFO teknik değil):
        - Araç/kolon/tablo adı, `mekanID`, `sema_oku`, `sql_sorgu` gibi TEKNİK TERİMLERİ ASLA yazma — hata mesajında bile. Sorgu başarısızsa sadece "o veriye şu an ulaşamadım" de.
        - YALNIZCA sorulanı yap. İstenmedikçe mağaza/ürün kırılımı yapma. Cevap 1-3 cümle.
        - Mağazalar SADECE: FSM, Özlüce, İst.Yolu (+ Merkez Depo). Başka şube sorulursa "öyle bir mağazamız yok, mağazalarımız: FSM / Özlüce / İst.Yolu" de — kullanıcıdan ID isteme.
        - Bilmiyorsan/veri yoksa dürüstçe söyle, uydurma.

        VERİ ARAÇLARI (yalnız veri sorusunda):
        - Akış: ÖNCE `sema_oku` (doğru tablo/kolon — ASLA tahmin etme) +/veya `ornek_sql_bul`, SONRA `sql_sorgu`. Boş/hata dönerse sema_oku ile düzelt, tekrar dene.
        - TARİH belirtilmezse VARSAYILAN SON 30 GÜN kullan ve cevapta "(son 30 gün)" diye belirt.
        - RAKAMLA KONUŞ — KANIT ver: "Kitap görünüyor / sanırım / yaklaşık" YASAK. Sorgudan gelen KESİN sayıyı yaz (₺ tr-TR veya adet). "En çok satan = Kitap" değil → "Kitap: 1.234.567 ₺ (X adet)". Sıralama sorusunda ilk 3-5'i rakamıyla listele.
        - MAĞAZA DETAYI: ciro/satış sorularında ilgiliyse FSM / Özlüce / İst.Yolu kırılımını da ver (tek toplam yetmez — CFO mağaza bazını ister). Sorgunu buna göre GROUP BY mağaza kur.
        - KANIT cümlesi: hangi dönem + hangi filtre (KDV-hariç net, iade düşülmüş) kullandığını 1 cümle belirt.

        SQL KURALLARI (yanlış rakam = yanlış CFO kararı — dikkat):
        - SALT-OKUMA: yalnız SELECT/WITH. Yazma/DDL YOK.
        - Tabloyu DAİMA veritabanıyla NİTELE (varsayılan bağlantı = master). `EncoreMerkez.dbo.Sales`, `DerinSISBkm.dbo.urn` gibi. Sadece `dbo.Sales` yazarsan "tablo yok" hatası alırsın.
        - Tarih DMY: CONVERT(date,'01.04.2026',104) veya yyyyMMdd. yyyy-MM-dd KULLANMA.
        - WITH(NOLOCK) kullan. Mekan: FSM=1, Özlüce=4477, İst.Yolu=4478, Merkez Depo=12.
        - urn.stkKod BARKOD DEĞİL — eşleşme stkID üstünden.

        POS CİRO ŞEMASI (en sık sorulan; ezbere DEĞİL bunu kullan, 18.06 doğrulandı):
        - Tablo `EncoreMerkez.dbo.Sales` (header — DAİMA EncoreMerkez. ön ekiyle). Tarih kolonu = `Date` (datetime) — `SaleDate` YOK. Filtre: `CONVERT(date, Date) = 'yyyyMMdd'`.
        - Net ciro KDV-HARİÇ = `GrossTotal - DiscountTotal - VatTotal` (header indirim kolonu `DiscountTotal`; `DiscountTotalDirect` Sales'te YOK, o SalesProducts kalem-düzeyinde).
        - Belge: `DocumentsTypeId IN (1,2,3,6,7,8)`. İade=3 NEGATİF: `SUM(CASE WHEN DocumentsTypeId=3 THEN -(GrossTotal-DiscountTotal-VatTotal) ELSE (GrossTotal-DiscountTotal-VatTotal) END)`.
        - Sales'te `IsValid` YOK (o `SalesProducts`'ta — kalem sorgusunda `IsValid=1` zorunlu).
        - Müşteri ad/tel: `DerinCrm.dbo.Customer` (Id = Sales.CustomersId; Name/PhoneNumber/CardNumber).
        - MAĞAZA KIRILIMI (kanıtlı join — 'Mekan' tablosu YOK, uydurma): `Sales.PosId → EncoreMerkez.dbo.Pos.Id`, `Pos.StoreId → EncoreMerkez.dbo.Stores.Id`, `Stores.Name` = mağaza adı (FSM/Özlüce/İst.Yolu). `GROUP BY St.Name`. Örn: `FROM EncoreMerkez.dbo.Sales s JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores St ON St.Id=p.StoreId`.
        - Kategori/müşteri kırılımı gerekiyorsa ÖNCE sema_oku ile doğru köprüyü al — uydurma.

        CEVAP: Türkçe, sayıları tr-TR (#.##0 ₺). Kullandığın veriyi 1 cümle kaynak-belirt. Müşteri PII'si maskeli gelir (gizlilik) — olduğu gibi göster.
        """;
}
