namespace GmDashboard.Data.Asistan;

/// <summary>Asistan cevabı: metin + hangi araçlar kullanıldı (şeffaflık/debug).</summary>
public sealed record AsistanCevap(string Metin, IReadOnlyList<string> AracIzi);

/// <summary>
/// BKM-Asistan tool-use loop (plan-20 Faz-1). Soru → LLM (Gemini/Groq) → araç çağrıları (sql/sema/görev) → cevap.
/// learn-claude-code loop deseni: araç-istedikçe çalıştır+geri besle, metin gelince dur. Max tur sınırı.
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
        - Veri sorusu (ciro/stok/kargo/müşteri) → ÖNCE `sema_oku` (doğru tablo/join/kod) ve/veya `ornek_sql_bul` (benzer doğrulanmış örnek), SONRA `sql_sorgu`.
        - Görev/yapılacak → `gorev_ekle` / `gorev_listele`.
        - Emin değilsen uydurma — netleştirme sorusu sor.

        SQL KURALLARI (yanlış rakam = yanlış CFO kararı — dikkat):
        - SALT-OKUMA: yalnız SELECT/WITH. Yazma/DDL YOK.
        - Tarih DMY: CONVERT(date,'01.04.2026',104) veya yyyyMMdd. yyyy-MM-dd KULLANMA.
        - Net ciro KDV-HARİÇ; iade NETLENMİŞ (ehTip 3,5,101 düşülür / DocumentsTypeId=3 negatif).
        - WITH(NOLOCK) kullan. Mekan: FSM=1, Özlüce=4477, İst.Yolu=4478, Merkez Depo=12.
        - urn.stkKod BARKOD DEĞİL — eşleşme stkID üstünden.
        - Doğru join/kod için sema'ya güven; emin değilsen sema_oku.

        CEVAP: Türkçe, sayıları tr-TR (#.##0 ₺). Kullandığın veriyi 1 cümle kaynak-belirt. Müşteri PII'si maskeli gelir (gizlilik) — olduğu gibi göster.
        """;
}
