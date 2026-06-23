using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Mizan / likidite dashboard (B-118, plan-25) — DerinSISBkm.mhs kesin mizan, Excel hiyerarşisi (ana→alt→en alt).
/// Kaynak: mhs.mhsFis (satır) + mhs.mhsHsp (ad). Mevcut Db.OpenAsync (master → 3-parçalı isim). Yeni bağlantı yok.
/// Kapanmış yıl: "Kapanış" bilanço fişi (her yılda tek, max yevmiye) HARİÇ → gerçek bakiye (kesin mizan).
/// Açık yılda Kapanış yok → etkisiz, tek mantık. İşaret: fisBA=0=Alacak/1=Borç, Bakiye=Borç−Alacak (view tanımı + 23.06 doğrulama).
/// </summary>
public sealed class MizanQueries(Db db, ILogger<MizanQueries> logger)
{
    public const int YilOffset = 2020;   // fisSirketID + 2020 = takvim yılı

    private sealed record LeafRow(string HspKod, string HspAd, decimal Borc, decimal Alacak);

    /// <summary>Seçici için mevcut dönemler (şirket-yıl), en yeni önce.</summary>
    public async Task<IReadOnlyList<(int SirketId, int Yil)>> GetDonemlerAsync()
    {
        await using var conn = await db.OpenAsync();
        var ids = await conn.QueryAsync<int>(
            "SELECT DISTINCT hspSirketID FROM DerinSISBkm.mhs.mhsHsp ORDER BY hspSirketID DESC");
        return ids.Select(s => (s, s + YilOffset)).ToList();
    }

    /// <summary>Tek yükleme: özet kartlar + tam mizan ağacı. Kapanış fişi hariç (kesin mizan).</summary>
    public async Task<MizanSonuc> GetSonucAsync(int sirketId)
    {
        await using var conn = await db.OpenAsync();
        // Leaf bakiyeler — fiş satırından, "Kapanış" bilanço fişi HARİÇ (NOT EXISTS → açık yılda etkisiz).
        var leafler = (await conn.QueryAsync<LeafRow>("""
            SELECT h.hspKod AS HspKod, h.hspAd AS HspAd,
                   CAST(SUM(CASE WHEN ff.fisBA=1 THEN -ff.fisTutar ELSE 0 END) AS decimal(18,2)) AS Borc,
                   CAST(SUM(CASE WHEN ff.fisBA=0 THEN  ff.fisTutar ELSE 0 END) AS decimal(18,2)) AS Alacak
            FROM DerinSISBkm.mhs.mhsFis ff
            JOIN DerinSISBkm.mhs.mhsHsp h ON h.hspID = ff.fisHspID AND h.hspSirketID = ff.fisSirketID
            WHERE ff.fisSirketID = @sirketId
              AND NOT EXISTS (SELECT 1 FROM DerinSISBkm.mhs.mhsFisBaslik k
                              WHERE k.fisbID = ff.fisID AND k.fisbSirketID = ff.fisSirketID AND k.fisAd = N'Kapanış')
            GROUP BY h.hspKod, h.hspAd
            HAVING SUM(CASE WHEN ff.fisBA=1 THEN -ff.fisTutar ELSE 0 END) <> 0
                OR SUM(CASE WHEN ff.fisBA=0 THEN  ff.fisTutar ELSE 0 END) <> 0
            """, new { sirketId })).ToList();

        // Ara seviye (100.10) adları için tam hesap-adı sözlüğü.
        var adlar = (await conn.QueryAsync<(string Kod, string Ad)>(
            "SELECT hspKod, hspAd FROM DerinSISBkm.mhs.mhsHsp WHERE hspSirketID = @sirketId", new { sirketId }))
            .GroupBy(x => x.Kod).ToDictionary(g => g.Key, g => g.First().Ad, StringComparer.Ordinal);

        var agac = AgacKur(leafler, adlar);
        // Özet için 3-haneli ana hesap bakiyeleri (ağaçtan topla).
        var ucHane = new Dictionary<string, decimal>(StringComparer.Ordinal);
        void Topla(MizanNode n)
        {
            if (n.Kod.Length == 3 && !n.Kod.Contains('.')) ucHane[n.Kod] = n.Bakiye;
            foreach (var c in n.Cocuklar) Topla(c);
        }
        foreach (var k in agac) Topla(k);
        logger.LogInformation("Mizan ağacı (sirket {S}): {Kok} sınıf, {Leaf} leaf", sirketId, agac.Count, leafler.Count);
        return new MizanSonuc(OzetHesapla(ucHane, agac), agac);
    }

    /// <summary>Leaf bakiyelerden Excel hiyerarşisi: 1-haneli sınıf → 2 grup → 3 ana hesap → alt (100.10) → en alt.
    /// Alt-toplamlar her ataya biriktirilir. Üst grup adları Tek Düzen (TekDuzenHesap.Grup/Ad), alt hesaplar mhsHsp.</summary>
    private static List<MizanNode> AgacKur(IReadOnlyList<LeafRow> leafler, IReadOnlyDictionary<string, string> adlar)
    {
        var map = new Dictionary<string, MizanNode>(StringComparer.Ordinal);
        var kokler = new List<MizanNode>();
        foreach (var r in leafler)
        {
            var segs = r.HspKod.Split('.');
            var s0 = segs[0];                                  // 3-haneli ana (örn "100")
            var paths = new List<string>();
            if (s0.Length >= 1) paths.Add(s0[..1]);            // 1-haneli sınıf ("1")
            if (s0.Length >= 2) paths.Add(s0[..2]);            // 2-haneli grup ("10")
            paths.Add(s0);                                     // 3-haneli ana ("100")
            for (int i = 1; i < segs.Length; i++) paths.Add(paths[^1] + "." + segs[i]);   // alt + en alt

            MizanNode? ust = null;
            for (int lvl = 0; lvl < paths.Count; lvl++)
            {
                var pk = paths[lvl];
                if (!map.TryGetValue(pk, out var node))
                {
                    string ad = !pk.Contains('.') && pk.Length <= 2 ? TekDuzenHesap.GrupVeya(pk)   // 1-2 hane grup
                              : !pk.Contains('.') ? TekDuzenHesap.AdVeya(pk)                        // 3 hane ana
                              : pk == r.HspKod ? r.HspAd                                            // leaf
                              : adlar.TryGetValue(pk, out var a) ? a : pk;                          // ara alt
                    node = new MizanNode { Kod = pk, Ad = ad, Seviye = lvl + 1 };
                    map[pk] = node;
                    if (ust is null) kokler.Add(node); else ust.Cocuklar.Add(node);
                }
                node.Borc += r.Borc; node.Alacak += r.Alacak;
                ust = node;
            }
        }
        Sirala(kokler);
        return kokler;
    }

    private static void Sirala(List<MizanNode> ns)
    {
        ns.Sort((a, b) => string.CompareOrdinal(a.Kod, b.Kod));
        foreach (var n in ns) Sirala(n.Cocuklar);
    }

    /// <summary>Özet kartlar — 3-haneli ana hesap bakiyelerinden. Varlık borç-pozitif, yükümlülük alacak-pozitif.</summary>
    private static MizanOzet OzetHesapla(IReadOnlyDictionary<string, decimal> k, IReadOnlyList<MizanNode> kokler)
    {
        decimal Borc(params string[] kods) => kods.Sum(c => k.GetValueOrDefault(c));        // borç bakiyesi (varlık)
        decimal Alacak(params string[] kods) => kods.Sum(c => -k.GetValueOrDefault(c));      // alacak bakiyesi (kaynak)
        var kdvInd = Borc("191"); var kdvHes = Alacak("391");
        return new MizanOzet(
            Nakit: Borc("100", "101", "102", "108"),
            VerilenCek: Alacak("103"),
            Alicilar: Borc("120"),
            Saticilar: Alacak("320"),
            KdvIndirilecek: kdvInd, KdvHesaplanan: kdvHes, KdvNet: kdvHes - kdvInd,
            ToplamBorc: kokler.Sum(n => n.Borc),
            ToplamAlacak: kokler.Sum(n => n.Alacak));
    }
}
