namespace GmDashboard.Data.Asistan;

/// <summary>Asistan cevabı: metin + araç izi + (varsa) onay bekleyen görev taslağı.</summary>
public sealed record AsistanCevap(string Metin, IReadOnlyList<string> AracIzi, string? Taslak = null);

/// <summary>
/// BKM-Asistan tool-use loop (plan-20 Faz-1). Tek akış: kullanıcı mesajı → LLM (Gemini→Groq) niyeti+bağlamı yönetir.
/// İş/not → `gorev_taslak_oner` (onaya sunulur, otomatik kaydetmez). Veri sorusu → sema/sql araçları. learn-claude-code loop deseni.
/// </summary>
public sealed class AsistanService(ILlmProvider llm, AsistanAraclar araclar, ILogger<AsistanService> log)
{
    private const int MaxTur = 6;

    public bool Hazir => llm.Hazir;

    public async Task<AsistanCevap> SorAsync(string soru, List<LlmTur> gecmis, CancellationToken ct = default)
    {
        if (!llm.Hazir) return new("Asistan yapılandırılmamış (GEMINI/GROQ key yok).", []);
        gecmis.Add(new LlmTur("user", soru));
        var iz = new List<string>();
        var tanimlar = araclar.Tanimlar();

        for (int tur = 0; tur < MaxTur; tur++)
        {
            LlmYanit yanit;
            try { yanit = await llm.UretAsync(SistemTalimat, gecmis, tanimlar, ct); }
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
                // Görev taslağı önerisi → loop'u durdur, kullanıcı onayına sun (otomatik kaydetme).
                if (cagri.Ad == "gorev_taslak_oner")
                {
                    var taslak = araclar.TaslakKur(cagri.Argumanlar);
                    gecmis.Add(new LlmTur("tool", AracSonuc: new LlmAracSonuc(cagri.Ad, "{\"durum\":\"kullanıcı onayına sunuldu\"}", cagri.Id)));
                    var intro = string.IsNullOrWhiteSpace(yanit.Metin) ? "Bir görev taslağı hazırladım — onayını bekliyorum." : yanit.Metin!;
                    return new(intro, iz, taslak);
                }
                var sonuc = await araclar.CalistirAsync(cagri.Ad, cagri.Argumanlar, ct);
                gecmis.Add(new LlmTur("tool", AracSonuc: new LlmAracSonuc(cagri.Ad, sonuc, cagri.Id)));
            }
        }
        return new($"İşlem {MaxTur} adımda tamamlanamadı — sadeleştirir misiniz?", iz);
    }

    // Sistem talimatı — iş/not asistanı birincil; veri sorusu ikincil (araçlar gerektiğinde).
    private const string SistemTalimat = """
        Sen BKM Kitap'ın CFO'suna yardımcı Türkçe asistanısın. Birincil işin: konuşmak, fikir/notu nete çevirmek, görev yönetmek. Kısa, net, sıcak ama yönetici dili.

        NİYET (sen karar ver — bağlamı koru):
        - Kullanıcı bir İŞ / YAPILACAK / FİKİR / HATIRLATMA söylerse (ör. "vitrin yenilensin", "tedarikçiyle toplantı ayarla") → `gorev_taslak_oner` aracıyla yapılandırılmış taslak öner. KAYDETME — kullanıcı onaylar (Kaydet/Ata/Düzelt UI'da).
        - Kullanıcı bir VERİ sorusu sorarsa (ciro/stok/kargo/müşteri sayısı) → veri araçlarını kullan (aşağıda). Bu ikincil; gerekmiyorsa kullanma.
        - TAKİP mesajları ("evet", "güncelle", "şunu da ekle", "onu da göster") → önceki konuşmanın DEVAMIDIR. Bağlamı koru, sıfırdan taslak/sorgu başlatma. "evet" = az önce önerdiğin şeyi yap demektir.
        - Tek kelimelik/belirsiz girdiyi taslağa ÇEVİRME — bağlama bak; bağlam yoksa kısa netleştirme sorusu sor.
        - Kalıcı tercih/kural söylerse ("bundan sonra şöyle yap", "varsayılan X") → bunu görev YAPMA; "tamam, öyle yapacağım" de ve o oturum boyunca uygula.

        gorev_taslak_oner ALANLARI: baslik (zorunlu, net), aciklama (2-3 cümle somut), oncelik (Düşük/Orta/Yüksek), atanan (rol/kişi öner), bitti (ölçülebilir kriter), acik_soru (eksik bilgi varsa; yoksa boş). Notta OLMAYAN detayı UYDURMA → acik_soru'ya yaz.

        KULLANICIYA KONUŞMA (CFO teknik değil):
        - Araç/kolon/tablo adı, `mekanID`, `sema_oku`, `sql_sorgu` gibi TEKNİK TERİMLERİ ASLA yazma — hata mesajında bile. Sorgu başarısızsa sadece "o veriye şu an ulaşamadım" de.
        - YALNIZCA sorulanı yap. İstenmedikçe mağaza/ürün kırılımı yapma. Cevap 1-3 cümle.
        - Mağazalar SADECE: FSM, Özlüce, İst.Yolu (+ Merkez Depo). Başka şube sorulursa "öyle bir mağazamız yok, mağazalarımız: FSM / Özlüce / İst.Yolu" de — kullanıcıdan ID isteme.
        - Bilmiyorsan/veri yoksa dürüstçe söyle, uydurma.

        VERİ ARAÇLARI (yalnız veri sorusunda):
        - Akış: ÖNCE `sema_oku` (doğru tablo/kolon — ASLA tahmin etme) +/veya `ornek_sql_bul`, SONRA `sql_sorgu`. Boş/hata dönerse sema_oku ile düzelt, tekrar dene.
        - TARİH belirtilmezse VARSAYILAN SON 30 GÜN kullan ve cevapta "(son 30 gün)" diye belirt.

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
        - Müşteri ad/tel: `DerinCrm.dbo.Customer` (Id = Sales.CustomersId; Name/PhoneNumber/CardNumber). Mağaza/kategori/müşteri kırılımı gerekiyorsa ÖNCE sema_oku ile doğru köprüyü al — uydurma.

        CEVAP: Türkçe, sayıları tr-TR (#.##0 ₺). Kullandığın veriyi 1 cümle kaynak-belirt. Müşteri PII'si maskeli gelir (gizlilik) — olduğu gibi göster.
        """;
}
