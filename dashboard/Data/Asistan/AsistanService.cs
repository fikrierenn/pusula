namespace GmDashboard.Data.Asistan;

/// <summary>Asistan cevabı: metin + hangi araçlar kullanıldı (şeffaflık/debug).</summary>
public sealed record AsistanCevap(string Metin, IReadOnlyList<string> AracIzi);

/// <summary>
/// BKM-Asistan tool-use loop (plan-20 Faz-1). Soru → LLM (Gemini/Groq) → araç çağrıları (sql/sema/görev) → cevap.
/// learn-claude-code loop deseni: araç-istedikçe çalıştır+geri besle, metin gelince dur. Max tur sınırı.
/// </summary>
public sealed class AsistanService(ILlmProvider llm, AsistanAraclar araclar, LlmService yerel, ILogger<AsistanService> log)
{
    private const int MaxTur = 6;

    public bool Hazir => llm.Hazir;

    /// <summary>
    /// Nottan görev taslağı üret — bulut birincil (Gemini→Groq, FallbackLlmProvider), yerel qwen EN SON fallback (18.06 kullanıcı kararı).
    /// Format LlmService.TaslakSistem ile aynı (📋/📝/⚡/👤 — GorevService.Kaydet parse eder). duzeltme verilirse revize.
    /// </summary>
    public async Task<string> TaslakUretAsync(string not, string? duzeltme = null, CancellationToken ct = default)
    {
        var userNote = string.IsNullOrWhiteSpace(duzeltme)
            ? not
            : $"{not}\n\n[Kullanıcı düzeltmesi: {duzeltme}] — bu düzeltmeyi uygulayıp taslağı yeniden yaz.";

        if (llm.Hazir)
        {
            try
            {
                var gecmis = new List<LlmTur>
                {
                    new("user", LlmService.TaslakOrnekUser),
                    new("model", LlmService.TaslakOrnekAsistan),
                    new("user", userNote),
                };
                var y = await llm.UretAsync(LlmService.TaslakSistem, gecmis, [], ct);   // araçsız → düz metin
                if (!string.IsNullOrWhiteSpace(y.Metin)) return y.Metin.Trim();
                log.LogWarning("Bulut taslak boş döndü — yerel qwen'e düşülüyor");
            }
            catch (Exception ex) { log.LogWarning(ex, "Bulut taslak başarısız (quota/hata) — yerel qwen fallback"); }
        }
        // EN SON fallback: yerel qwen (offline/quota-bitmiş senaryo)
        return await yerel.TaslakUret(not, duzeltme);
    }

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
                var sonuc = await araclar.CalistirAsync(cagri.Ad, cagri.Argumanlar, ct);
                gecmis.Add(new LlmTur("tool", AracSonuc: new LlmAracSonuc(cagri.Ad, sonuc, cagri.Id)));
            }
        }
        return new($"İşlem {MaxTur} adımda tamamlanamadı — soruyu sadeleştirir misiniz?", iz);
    }

    // Sistem talimatı — sema kuralları gömülü (yanlış rakam önleme). Detay sema_oku/ornek_sql_bul araçlarıyla.
    private const string SistemTalimat = """
        Sen BKM Kitap'ın CFO'suna yardımcı Türkçe veri asistanısın. Kısa, net, sayı-odaklı cevap ver.

        ARAÇLAR:
        - Veri sorusu (ciro/stok/kargo/müşteri) → ZORUNLU akış: ÖNCE `sema_oku` (doğru tablo/kolon/join — kolon adını ASLA tahmin etme) +/veya `ornek_sql_bul`, SONRA `sql_sorgu`. Kolon uydurmak = yanlış/boş sonuç = yanlış CFO kararı.
        - Görev/yapılacak → `gorev_ekle` / `gorev_listele`.
        - Emin değilsen uydurma — netleştirme sorusu sor. `sql_sorgu` boş/hatalı dönerse kolon adlarını sema_oku ile doğrula, düzelt, tekrar dene.

        SQL KURALLARI (yanlış rakam = yanlış CFO kararı — dikkat):
        - SALT-OKUMA: yalnız SELECT/WITH. Yazma/DDL YOK.
        - Tarih DMY: CONVERT(date,'01.04.2026',104) veya yyyyMMdd. yyyy-MM-dd KULLANMA.
        - WITH(NOLOCK) kullan. Mekan: FSM=1, Özlüce=4477, İst.Yolu=4478, Merkez Depo=12.
        - urn.stkKod BARKOD DEĞİL — eşleşme stkID üstünden.

        POS CİRO ŞEMASI (EncoreMerkez — en sık sorulan; ezbere DEĞİL bunu kullan, 18.06 doğrulandı):
        - Tablo `dbo.Sales` (header). Tarih kolonu = `Date` (datetime) — `SaleDate` YOK. Filtre: `CONVERT(date, Date) = 'yyyyMMdd'`.
        - Net ciro KDV-HARİÇ = `GrossTotal - DiscountTotal - VatTotal` (header indirim kolonu `DiscountTotal`; `DiscountTotalDirect` Sales'te YOK, o SalesProducts kalem-düzeyinde).
        - Belge: `DocumentsTypeId IN (1,2,3,6,7,8)`. İade=3 NEGATİF: `SUM(CASE WHEN DocumentsTypeId=3 THEN -(GrossTotal-DiscountTotal-VatTotal) ELSE (GrossTotal-DiscountTotal-VatTotal) END)`.
        - Sales'te `IsValid` YOK (o `SalesProducts`'ta — kalem sorgusunda `IsValid=1` zorunlu). Mağaza kırılımı gerekiyorsa sema_oku ile mekan/Stores köprüsünü al.

        CEVAP: Türkçe, sayıları tr-TR (#.##0 ₺). Kullandığın veriyi 1 cümle kaynak-belirt. Müşteri PII'si maskeli gelir (gizlilik) — olduğu gibi göster.
        """;
}
