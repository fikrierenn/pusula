namespace GmDashboard.Models;

/// <summary>Kadro paneli (plan-38) modelleri. Tamamı TOPLULAŞTIRILMIŞ — kişi satırı YOK (KVKK).</summary>

/// <summary>Şube × grup kadro sayımı, iki kesim (taban + kesim tarihi), iki yıl.</summary>
public sealed record KadroSubeGrup(
    string Sube,
    string Grup,          // SEZONLUK · ENGELLI · ETKINLIK · DIGER KADROLU
    int TabanOnceki,      // önceki yıl taban (ör. 30.06.2025)
    int TabanCari,        // cari yıl taban (ör. 30.06.2026)
    int KesimOnceki,      // önceki yıl kesim (ör. 31.08.2025)
    int KesimCari);       // cari yıl kesim (ör. 31.08.2026)

/// <summary>Kesim özeti: sezonluk / kadrolu / toplam, iki yıl + taban.</summary>
public sealed record KadroOzet(
    int TabanKadroluOnceki, int TabanKadroluCari,
    int KesimSezonlukOnceki, int KesimSezonlukCari,
    int KesimKadroluOnceki, int KesimKadroluCari)
{
    public int TabanFark => TabanKadroluCari - TabanKadroluOnceki;
    public int SezonIciOnceki => KesimKadroluOnceki - TabanKadroluOnceki;
    public int SezonIciCari => KesimKadroluCari - TabanKadroluCari;
    public int SezonlukFark => KesimSezonlukCari - KesimSezonlukOnceki;
    public int ToplamOnceki => KesimSezonlukOnceki + KesimKadroluOnceki;
    public int ToplamCari => KesimSezonlukCari + KesimKadroluCari;
}

/// <summary>Mağaza iş hacmi (EncoreMerkez POS, perakende fiş) — kadro ile kıyas için.</summary>
public sealed record KadroIsHacmi(
    int StoresId,
    string Magaza,
    int FisOnceki, int FisCari,
    int KalemOnceki, int KalemCari,
    decimal AdetOnceki, decimal AdetCari,
    decimal NetOnceki, decimal NetCari)
{
    private static decimal? Deg(decimal onceki, decimal cari) => onceki == 0 ? null : cari / onceki - 1m;
    public decimal? FisDegisim => Deg(FisOnceki, FisCari);
    public decimal? AdetDegisim => Deg(AdetOnceki, AdetCari);
    public decimal? NetDegisim => Deg(NetOnceki, NetCari);
    public decimal? SepetAdetOnceki => FisOnceki == 0 ? null : AdetOnceki / FisOnceki;
    public decimal? SepetAdetCari => FisCari == 0 ? null : AdetCari / FisCari;
}

/// <summary>Kohort tutunma (eşit kıdem): alınan / risk / kalan — segment × yıl.</summary>
public sealed record KadroTutunma(
    string Segment,       // SEZONLUK · KADROLU
    int Yil,
    int Alinan,
    int KesimeKadarAyrilan,
    int Risk14, int Kalan14,
    int Risk30, int Kalan30)
{
    public decimal? Tutunma14 => Risk14 == 0 ? null : (decimal)Kalan14 / Risk14;
    public decimal? Tutunma30 => Risk30 == 0 ? null : (decimal)Kalan30 / Risk30;
}
