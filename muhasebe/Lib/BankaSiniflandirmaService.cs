using System.Globalization;
using System.Text;
using Dapper;

namespace Muhasebe.Lib;

/// <summary>Bir banka ekstresi satırı için sınıflandırma önerisi.</summary>
public sealed record BankaOneri(
    string Aciklama, string Yon, string Kademe,          // Kademe: "AUTO" | "ISTISNA" | "YOK"
    int? CariId, string? CariAd, string? CariKod,
    double Guven, int Kanit,                              // Guven=agree (0..1), Kanit=support
    IReadOnlyList<BankaAday> Adaylar,
    bool Ogrenildi = false);                              // öğrenilen-index'ten geldi (Şule onayı/düzeltmesi)

public sealed record BankaAday(int CariId, string CariAd, string CariKod, int Adet, double Pay);

/// <summary>Cari kart (banka hesabı seçimi + arama sonucu). Kod = GL hesap (102.10.x / 320.10.x).</summary>
public sealed record BankaHesap(int Id, string Ad, string Kod);

/// <summary>
/// Banka ekstresi (DerinSISBkm.dbo.car cTip=122) satır → karşı-cari (cKodKarsi) sınıflandırıcı.
/// İki kaynak: (1) 807K geçmiş (perspektif kilitli, salt-okuma) + (2) ÖĞRENİLEN (bkm.BankaOgrenme —
/// Şule onay/düzeltme, ÖNCELİKLİ). Öğrenme yazması yalnız app-owned bkm.BankaOgrenme'ye (erp-write-policy).
/// Operasyon noktası: agree≥%97 & n≥5 → AUTO (%99,6 doğru, %70 kapsam). Öğrenilen = her zaman AUTO.
/// </summary>
public sealed class BankaSiniflandirmaService
{
    private const double AutoGuven = 0.97;
    private const int AutoKanit = 5;

    private readonly Db _db;
    private readonly ILogger<BankaSiniflandirmaService> _log;
    private static readonly CultureInfo Tr = new("tr-TR");

    // key = yön(0/1) + "|" + normAçıklama  →  cariId → adet
    private Dictionary<string, Dictionary<int, int>> _index = new();
    private Dictionary<int, (string ad, string kod)> _cariAd = new();
    // Öğrenilen (Şule) — ÖNCELİKLİ. key → cariId → adet. Mutasyon _ogrKilit ile.
    private readonly Dictionary<string, Dictionary<int, int>> _ogrenilen = new();
    private readonly object _ogrKilit = new();

    private readonly SemaphoreSlim _yukKilit = new(1, 1);
    private volatile bool _yuklu;
    public DateTime? SonYukleme { get; private set; }
    public int IndexAnahtarSayisi => _index.Count;
    public int CariSayisi => _cariAd.Count;
    public int OgrenilenSayisi { get { lock (_ogrKilit) return _ogrenilen.Count; } }

    // Şirketin kendi banka hesapları (cKod tarafı, frmTip=5, ekstresi işlenen). Dropdown için.
    private IReadOnlyList<BankaHesap> _bankaHesaplari = [];
    public IReadOnlyList<BankaHesap> BankaHesaplari => _bankaHesaplari;

    public BankaSiniflandirmaService(Db db, ILogger<BankaSiniflandirmaService> log)
    {
        _db = db; _log = log;
    }

    /// <summary>Metni eşleştirme için normalize et: tr-TR büyük harf, sadece harf/rakam, tek boşluk.</summary>
    public static string Normalize(string s)
    {
        s = s.ToUpper(Tr);
        var sb = new StringBuilder(s.Length);
        bool bosluk = false;
        foreach (var ch in s)
        {
            if (char.IsLetterOrDigit(ch)) { sb.Append(ch); bosluk = false; }
            else if (!bosluk) { sb.Append(' '); bosluk = true; }
        }
        return sb.ToString().Trim();
    }

    /// <summary>Geçmiş index'i (ERP salt-okuma) + öğrenilen (bkm.BankaOgrenme) yükle. İlk Classify'da tembel.</summary>
    public async Task YukleAsync(bool zorla = false)
    {
        if (_yuklu && !zorla) return;
        await _yukKilit.WaitAsync();
        try
        {
            if (_yuklu && !zorla) return;
            var yeniIndex = new Dictionary<string, Dictionary<int, int>>();
            var kullanilanCari = new HashSet<int>();
            var statementBanks = new HashSet<int>();   // ekstresi işlenen kendi banka hesapları (cKod)

            await using var cn = await _db.OpenAsync();
            // Perspektif kilidi: banka hesabı frmID'leri (frmTip=5). Yalnız cKod=banka satırları → cKodKarsi=gerçek cari.
            var bankaSet = new HashSet<int>();
            using (var cmd = cn.CreateCommand())
            {
                cmd.CommandText = "SELECT frmID FROM dbo.frm WHERE frmTip=5";
                cmd.CommandTimeout = 60;
                await using var rb = await cmd.ExecuteReaderAsync();
                while (await rb.ReadAsync()) bankaSet.Add(rb.GetInt32(0));
            }
            // ~807K satır — ham reader.
            using (var cmd = cn.CreateCommand())
            {
                cmd.CommandText = "SELECT cBA, cNot, cKodKarsi, cKod FROM dbo.car WHERE cTip=122 AND cKodKarsi>0";
                cmd.CommandTimeout = 300;
                await using var r = await cmd.ExecuteReaderAsync();
                while (await r.ReadAsync())
                {
                    var cKod = r.GetInt32(3);
                    if (!bankaSet.Contains(cKod)) continue;   // perspektif kilidi
                    statementBanks.Add(cKod);
                    var ba = r.GetByte(0);
                    var not = r.IsDBNull(1) ? "" : r.GetString(1);
                    var cari = r.GetInt32(2);
                    var norm = Normalize(not);
                    if (norm.Length == 0) continue;
                    var key = ba + "|" + norm;
                    if (!yeniIndex.TryGetValue(key, out var m)) { m = new(); yeniIndex[key] = m; }
                    m[cari] = m.GetValueOrDefault(cari) + 1;
                    kullanilanCari.Add(cari);
                }
            }

            // Öğrenilen kayıtları da yükle (cari adları için id topla).
            var ogr = (await cn.QueryAsync<(byte Yon, string AciklamaNorm, int CariId)>(
                "SELECT Yon, AciklamaNorm, CariId FROM bkm.BankaOgrenme")).ToList();
            foreach (var o in ogr) kullanilanCari.Add(o.CariId);
            foreach (var b in statementBanks) kullanilanCari.Add(b);   // banka hesap adları için

            // Aday cari ad/kod (index + öğrenilen'de geçenler).
            var yeniAd = new Dictionary<int, (string, string)>(kullanilanCari.Count);
            using (var cmd = cn.CreateCommand())
            {
                cmd.CommandText = "SELECT frmID, frmAd, frmKod FROM dbo.frm";
                cmd.CommandTimeout = 120;
                await using var r = await cmd.ExecuteReaderAsync();
                while (await r.ReadAsync())
                {
                    var id = r.GetInt32(0);
                    if (!kullanilanCari.Contains(id)) continue;
                    yeniAd[id] = (r.IsDBNull(1) ? "" : r.GetString(1), r.IsDBNull(2) ? "" : r.GetString(2));
                }
            }

            // Dropdown: yalnız SON 12 AY ekstresi işlenen kendi banka hesapları (aktif). frmKod=GL alt-hesap (102.10.x).
            _bankaHesaplari = (await cn.QueryAsync<BankaHesap>(
                @"SELECT DISTINCT c.cKod AS Id, f.frmAd AS Ad, f.frmKod AS Kod
                  FROM dbo.car c JOIN dbo.frm f ON f.frmID = c.cKod
                  WHERE c.cTip = 122 AND f.frmTip = 5 AND c.cTarih >= DATEADD(month, -12, GETDATE())"))
                .OrderBy(h => h.Ad, StringComparer.Create(Tr, false))
                .ToList();
            _index = yeniIndex;
            _cariAd = yeniAd;
            lock (_ogrKilit)
            {
                _ogrenilen.Clear();
                foreach (var o in ogr) OgrenilenEkleIc(o.Yon, o.AciklamaNorm, o.CariId);
            }
            _yuklu = true;
            SonYukleme = DateTime.Now;
            _log.LogInformation("Index yüklendi: {Anahtar} anahtar, {Cari} cari, {Ogr} öğrenilen anahtar",
                yeniIndex.Count, yeniAd.Count, OgrenilenSayisi);
        }
        finally { _yukKilit.Release(); }
    }

    // _ogrenilen'e (bellek) ekle — kilit ÇAĞIRAN tarafından tutulur.
    private void OgrenilenEkleIc(int ba, string norm, int cari)
    {
        var key = ba + "|" + norm;
        if (!_ogrenilen.TryGetValue(key, out var m)) { m = new(); _ogrenilen[key] = m; }
        m[cari] = m.GetValueOrDefault(cari) + 1;
    }

    /// <summary>Tek satırı sınıflandır. ba: 1=giden/ödeme, 0=gelen/tahsilat. Öğrenilen ÖNCELİKLİ.</summary>
    public async Task<BankaOneri> ClassifyAsync(int ba, string aciklama)
    {
        if (!_yuklu) await YukleAsync();
        var yonAd = ba == 1 ? "Giden (ödeme)" : "Gelen (tahsilat)";
        var norm = Normalize(aciklama);
        if (norm.Length == 0)
            return new BankaOneri(aciklama, yonAd, "YOK", null, null, null, 0, 0, []);
        var key = ba + "|" + norm;

        // 1) ÖĞRENİLEN önce — Şule onayı/düzeltmesi geçmişi ezer.
        Dictionary<int, int>? ogrM = null;
        lock (_ogrKilit) { if (_ogrenilen.TryGetValue(key, out var mm)) ogrM = new(mm); }
        if (ogrM is { Count: > 0 })
            return Karar(aciklama, yonAd, ogrM, ogrenildi: true);

        // 2) Geçmiş index.
        _index.TryGetValue(key, out var m);
        if (m is null || m.Count == 0)
            return new BankaOneri(aciklama, yonAd, "YOK", null, null, null, 0, 0, []);
        return Karar(aciklama, yonAd, m, ogrenildi: false);
    }

    private BankaOneri Karar(string aciklama, string yonAd, Dictionary<int, int> m, bool ogrenildi)
    {
        int toplam = m.Values.Sum();
        var adaylar = m.OrderByDescending(kv => kv.Value).Take(3).Select(kv =>
        {
            var (ad, kod) = _cariAd.GetValueOrDefault(kv.Key, ("(bilinmiyor)", ""));
            return new BankaAday(kv.Key, ad, kod, kv.Value, (double)kv.Value / toplam);
        }).ToList();
        var enIyi = adaylar[0];
        double guven = enIyi.Pay;
        // Öğrenilen = her zaman AUTO (insan öğretti). Geçmiş = eşik.
        string kademe = ogrenildi || (guven >= AutoGuven && toplam >= AutoKanit) ? "AUTO" : "ISTISNA";
        return new BankaOneri(aciklama, yonAd, kademe, enIyi.CariId, enIyi.CariAd, enIyi.CariKod, guven, toplam, adaylar, ogrenildi);
    }

    /// <summary>Çok satırlı toplu sınıflandırma (bir açıklama/satır, aynı yön).</summary>
    public async Task<IReadOnlyList<BankaOneri>> ClassifyBatchAsync(int ba, IEnumerable<string> satirlar)
    {
        if (!_yuklu) await YukleAsync();
        var sonuc = new List<BankaOneri>();
        foreach (var s in satirlar)
        {
            var t = s.Trim();
            if (t.Length == 0) continue;
            sonuc.Add(await ClassifyAsync(ba, t));
        }
        return sonuc;
    }

    /// <summary>Cari arama (İstisna düzeltmesi için isimle/kodla bul). TOP 12.</summary>
    public async Task<IReadOnlyList<BankaHesap>> CariAraAsync(string? q)
    {
        q = q?.Trim() ?? "";
        if (q.Length < 2) return [];
        await using var cn = await _db.OpenAsync();
        var rows = await cn.QueryAsync<BankaHesap>(
            "SELECT TOP 12 frmID AS Id, frmAd AS Ad, frmKod AS Kod FROM dbo.frm WHERE frmAd LIKE @p OR frmKod LIKE @p ORDER BY frmAd",
            new { p = "%" + q + "%" });
        return rows.ToList();
    }

    /// <summary>
    /// ÖĞRET: Şule onayı ('onay') veya düzeltmesi ('duzeltme'). bkm.BankaOgrenme'ye yazar + belleğe
    /// anında ekler (o an öğrenir). Yalnız app-owned bkm tablosu — DerinSIS native'e dokunmaz.
    /// </summary>
    public async Task OgrenmeKaydet(int ba, string aciklama, int cariId, string kaynak, string? kim)
    {
        var norm = Normalize(aciklama);
        if (norm.Length == 0 || cariId <= 0) return;

        await using var cn = await _db.OpenAsync();
        // Cari adı bellekte yoksa çek (öneride göstermek için).
        if (!_cariAd.ContainsKey(cariId))
        {
            var ad = await cn.QueryFirstOrDefaultAsync<(string Ad, string Kod)>(
                "SELECT frmAd AS Ad, frmKod AS Kod FROM dbo.frm WHERE frmID=@id", new { id = cariId });
            if (ad.Ad is not null) _cariAd[cariId] = (ad.Ad, ad.Kod ?? "");
        }
        await cn.ExecuteAsync(
            "INSERT INTO bkm.BankaOgrenme (Yon, AciklamaNorm, Aciklama, CariId, Kaynak, Kim) " +
            "VALUES (@ba, @norm, @aciklama, @cariId, @kaynak, @kim)",
            new { ba = (byte)ba, norm, aciklama = aciklama.Length > 200 ? aciklama[..200] : aciklama, cariId, kaynak, kim });

        lock (_ogrKilit) OgrenilenEkleIc(ba, norm, cariId);
        _log.LogInformation("Öğrenildi ({Kaynak}): '{Norm}' yön={Ba} → cari {Cari} ({Kim})", kaynak, norm, ba, cariId, kim);
    }
}
