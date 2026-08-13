using GmDashboard.Data;
using GmDashboard.Data.Asistan;

namespace GmDashboard;

/// <summary>
/// Özellik-bazlı DI kaydı (B-121). Program.cs şişmesin + yeni servis kendi grubuna eklenir → Program.cs hunk-split biter
/// (monolit "konular karışıyor" kademe-1). Lifetime'lar eski Program.cs ile birebir (Scoped/Singleton korunur).
/// </summary>
public static class ServiceRegistration
{
    /// <summary>Veri erişim + ERP/mizan sorgu servisleri (DerinSISBkm/EncoreMerkez/JOKER salt-okuma + Fin_AyKapanis).</summary>
    public static IServiceCollection AddBkmVeri(this IServiceCollection s)
    {
        s.AddSingleton<Db>();
        s.AddScoped<Queries>();
        s.AddScoped<MagazaQueries>();
        s.AddScoped<RefQueries>();
        s.AddScoped<EticQueries>();
        s.AddScoped<SadakatQueries>();
        s.AddScoped<MuhasebeQueries>();   // B-117 kontrol paneli (forensic)
        s.AddScoped<MizanQueries>();      // B-118 mizan/finans (plan-25)
        s.AddScoped<GiderMizanQueries>(); // B-128 gider merkezi dağılımlı mizan + fiş/fatura drill
        s.AddScoped<GelirTabloQueries>(); // B-129 ayrıntılı gelir tablosu (7xx dahil tam P&L)
        s.AddScoped<OdakQueries>();       // B-122 ODAK stok-satış + usulsüz sipariş
        s.AddScoped<FinansQueries>();     // B-124 cari bakiye / risk özeti
        s.AddScoped<TrafikQueries>();    // B-127 FSM trafik & kasiyer analizi
        s.AddScoped<SatinalmaQueries>(); // plan-32 satınalma raporları (hesap-sorma; DINAMIK emitter)
        s.AddSingleton<SabahService>();   // MIMBAL sabah brifingi (G1+E8)
        return s;
    }

    /// <summary>App-local durum/servis: görev/tahmin/takvim/iç-kart/ayar (BkmPanel+JSON) + forecast + UI state.</summary>
    public static IServiceCollection AddBkmDurum(this IServiceCollection s)
    {
        s.AddSingleton<GorevService>();        // SQLite görev deposu (asistan.db)
        s.AddSingleton<TahminKayitService>();  // JSON tahmin kaydı plan-14
        s.AddSingleton<TakvimService>();       // tatil API cache + okul JSON plan-14
        s.AddSingleton<IcKartService>();       // elle işaretli iç/mağaza kartları plan-16
        s.AddSingleton<AyarService>();         // iş eşiği ayarları (PanelAyar) — devir/stockout/risk/hariç-marka
        s.AddScoped<ForecastOkuService>();     // forecast çıktısı okur plan-15
        s.AddScoped<ForecastService>();        // forecast tetikler (python run.py) B-109
        s.AddScoped<NotifState>();             // bildirim merkezi (Home üretir, MainLayout okur)
        s.AddScoped<PerfState>();              // sayfa yükleme süresi
        return s;
    }

    /// <summary>BKM-Asistan LLM zinciri (Z.ai→OpenRouter→Gemini→Groq) + araç/bellek/OAuth (plan-21/26).</summary>
    public static IServiceCollection AddBkmAsistan(this IServiceCollection s)
    {
        s.AddSingleton<ZaiProvider>();          // Z.ai free GLM-Flash (plan-26 birincil)
        s.AddSingleton<OpenRouterProvider>();
        s.AddSingleton<GeminiProvider>();
        s.AddSingleton<GroqProvider>();
        s.AddSingleton<FallbackLlmProvider>();
        s.AddSingleton<ILlmProvider>(sp => sp.GetRequiredService<FallbackLlmProvider>());
        s.AddSingleton<GoogleAuthService>();    // Faz-2 OAuth (Gmail+Takvim)
        s.AddSingleton<GorusmeService>();       // görüşme kalıcılığı
        s.AddSingleton<AsistanBellekService>(); // öğrenen katman (plan-22)
        s.AddSingleton<TakvimMailAraclar>();    // Faz-2 Calendar+Gmail araç
        s.AddSingleton<AsistanAraclar>();       // sql_sorgu/sema_oku/ornek_sql_bul/gorev_*
        s.AddSingleton<AsistanService>();       // tool-use loop
        return s;
    }
}
