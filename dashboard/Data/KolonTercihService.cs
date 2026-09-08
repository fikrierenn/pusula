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
    /// Kullanıcının seçtiği kolon anahtarları + NE DÜŞTÜĞÜ.
    ///
    /// ⚠ SESSİZ DÜŞÜRME YOK (ölçüldü 09.09.2026, Solum karşı-sorusu üzerine):
    /// kayıtlı bir anahtar artık hiçbir kolona karşılık gelmiyorsa (kolon kaldırılmış /
    /// yeniden adlandırılmış) atılır — ama HANGİSİ atıldı çağırana bildirilir ve ekranda
    /// söylenir. Yoksa kullanıcı "kolonum kayboldu" der ve sebebi görünmez olur; bu tam olarak
    /// error-handling.md § "fallback sessiz olmasın" vakası (ve kendi çip kuralımızın aynası).
    ///
    /// Ölçülen iki hal:
    ///   · 5 anahtar (3 geçerli + 2 olmayan) → 3 kolon kalıyor, 2'si düşüyor.
    ///   · Hepsi geçersiz → varsayılan kümeye dönülüyor (tablo kolonsuz çizilmiyor).
    /// </summary>
    public async Task<KolonTercihSonuc> OkuAsync(string kullanici, string ekran)
    {
        if (!_tabloHazir) return KolonTercihSonuc.Varsayilan();
        try
        {
            await using var c = _db.OpenPanel();
            var ham = await c.ExecuteScalarAsync<string?>(
                "SELECT Kolonlar FROM dbo.PanelKolonTercih WHERE Kullanici = @k AND Ekran = @e",
                new { k = kullanici, e = ekran });
            if (string.IsNullOrWhiteSpace(ham)) return KolonTercihSonuc.Varsayilan();

            var anahtarlar = ham.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var secili = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var dusen = new List<string>();
            foreach (var a in anahtarlar)
            {
                if (SatisAnaliziKolonlar.Bul(a) is not null) secili.Add(a);
                else dusen.Add(a);
            }

            if (dusen.Count > 0)
                _log.LogWarning("Kolon tercihinde tanınmayan anahtar düştü ({Kullanici}/{Ekran}): {Dusen}",
                    kullanici, ekran, string.Join(", ", dusen));

            // Hepsi geçersizse tercih boş kalmasın — tablo kolonsuz çizilmez.
            return secili.Count > 0
                ? new KolonTercihSonuc(secili, dusen, false)
                : new KolonTercihSonuc(SatisAnaliziKolonlar.VarsayilanAnahtarlar, dusen, true);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Kolon tercihi okunamadı ({Kullanici}/{Ekran}) — varsayılan kullanılıyor",
                kullanici, ekran);
            return KolonTercihSonuc.Varsayilan();
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

/// <summary>
/// Kolon tercihi okuma sonucu. <paramref name="DusenAnahtarlar"/> boş değilse ekranda söylenir
/// (sessiz düşürme yasak). <paramref name="VarsayilanaDondu"/> = kayıt tamamen geçersizdi.
/// </summary>
public sealed record KolonTercihSonuc(
    IReadOnlySet<string> Secili, IReadOnlyList<string> DusenAnahtarlar, bool VarsayilanaDondu)
{
    public static KolonTercihSonuc Varsayilan() =>
        new(SatisAnaliziKolonlar.VarsayilanAnahtarlar, [], false);
}
