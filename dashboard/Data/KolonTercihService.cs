using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Kullanıcı başına görünür kolon kümesi (kullanıcı isteği 08.09.2026: "istediğim kolonları
/// ekleyip çıkartabilmem lazım").
///
/// TASARIM — Solum danışması (08.09.2026) ile netleşti:
///  · **ANAHTAR listesi** saklanır; indeks ya da bit maskesi DEĞİL. Gerekçe: indeks/maske bir
///    kolon eklendiği gün SESSİZCE kayar (yanlış kolon görünür); anahtar kayarsa kolon görünmez
///    olur — görünür hata. Anahtar aynı zamanda sıralama sözleşmesi.
///  · **Nerede:** BkmPanel (app-local, <c>dbo.Panel*</c>) — yazma izni ZATEN var, ERP'ye
///    dokunulmaz (erp-write-policy). localStorage DEĞİL: kullanıcı aynı paneli telefonda PWA ve
///    masaüstünde açıyor, tercih cihaza değil KİŞİYE bağlı olmalı.
///  · Kiracı kapsamı yok — tek şirket, tek kiracı (Solum'un çok-kiracılı alanı bizde gereksiz yüzey).
///
/// Panel DB kapalıysa (PanelEnabled=false) varsayılan kolon kümesiyle çalışır — sessiz değil,
/// uyarı loglanır (error-handling.md § sessiz fallback yasak).
/// </summary>
public sealed class KolonTercihService
{
    private readonly Db _db;
    private readonly ILogger<KolonTercihService> _log;
    private bool _tabloHazir;

    public KolonTercihService(Db db, ILogger<KolonTercihService> log)
    {
        _db = db; _log = log;
        if (!db.PanelEnabled)
        {
            log.LogWarning("Panel DB kapalı — kolon tercihleri kaydedilmez, varsayılan kolonlar kullanılır");
            return;
        }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'PanelKolonTercih')
                CREATE TABLE dbo.PanelKolonTercih (
                    Kullanici  nvarchar(80)  NOT NULL,
                    Ekran      nvarchar(40)  NOT NULL,
                    Kolonlar   nvarchar(2000) NOT NULL,
                    Guncelleme datetime NOT NULL,
                    CONSTRAINT PK_PanelKolonTercih PRIMARY KEY (Kullanici, Ekran));
                """);
            _tabloHazir = true;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "PanelKolonTercih tablo oluşturma hatası — varsayılan kolonlar kullanılacak");
        }
    }

    /// <summary>
    /// Kullanıcının seçtiği kolon anahtarları. Kayıt yoksa/bozuksa varsayılan küme döner.
    /// Bilinmeyen anahtarlar ATILIR (kolon kaldırılmışsa tercih onu taşımaya devam etmesin).
    /// </summary>
    public async Task<IReadOnlySet<string>> OkuAsync(string kullanici, string ekran)
    {
        if (!_tabloHazir) return SatisAnaliziKolonlar.VarsayilanAnahtarlar;
        try
        {
            await using var c = _db.OpenPanel();
            var ham = await c.ExecuteScalarAsync<string?>(
                "SELECT Kolonlar FROM dbo.PanelKolonTercih WHERE Kullanici = @k AND Ekran = @e",
                new { k = kullanici, e = ekran });
            if (string.IsNullOrWhiteSpace(ham)) return SatisAnaliziKolonlar.VarsayilanAnahtarlar;

            var secili = ham.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                            .Where(a => SatisAnaliziKolonlar.Bul(a) is not null)
                            .ToHashSet(StringComparer.OrdinalIgnoreCase);
            // Hepsi geçersizse tercih boş kalmasın — tablo kolonsuz çizilmez.
            return secili.Count > 0 ? secili : SatisAnaliziKolonlar.VarsayilanAnahtarlar;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Kolon tercihi okunamadı ({Kullanici}/{Ekran}) — varsayılan kullanılıyor",
                kullanici, ekran);
            return SatisAnaliziKolonlar.VarsayilanAnahtarlar;
        }
    }

    /// <summary>Seçili kolonları kaydeder. Boş küme kaydedilmez (tablo kolonsuz kalmasın).</summary>
    public async Task YazAsync(string kullanici, string ekran, IEnumerable<string> anahtarlar)
    {
        if (!_tabloHazir) return;
        var liste = anahtarlar.Where(a => SatisAnaliziKolonlar.Bul(a) is not null)
                              .Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        if (liste.Count == 0) return;
        try
        {
            await using var c = _db.OpenPanel();
            await c.ExecuteAsync("""
                MERGE dbo.PanelKolonTercih AS h
                USING (SELECT @k AS Kullanici, @e AS Ekran) AS y
                    ON h.Kullanici = y.Kullanici AND h.Ekran = y.Ekran
                WHEN MATCHED THEN UPDATE SET Kolonlar = @kol, Guncelleme = GETDATE()
                WHEN NOT MATCHED THEN INSERT (Kullanici, Ekran, Kolonlar, Guncelleme)
                     VALUES (@k, @e, @kol, GETDATE());
                """, new { k = kullanici, e = ekran, kol = string.Join(",", liste) });
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Kolon tercihi kaydedilemedi ({Kullanici}/{Ekran})", kullanici, ekran);
        }
    }
}
