namespace Bkm.TestAltyapi;

/// <summary>Panel rakamı ile kanonik rakam karşılaştırma toleransları.</summary>
public static class Tolerance
{
    /// <summary>Tutar için mutlak tolerans (TL).</summary>
    public const decimal Amount = 1.00m;

    /// <summary>Oran için göreli tolerans.</summary>
    public const decimal Ratio = 0.003m;

    /// <summary>Tutarlar tolerans içinde eşit değilse test hatası verir.</summary>
    public static void AmountEqual(decimal panel, decimal canonical, string label)
    {
        throw new NotImplementedException();
    }

    /// <summary>Panel değeri kanonik değerin göreli toleransı içinde değilse test hatası verir.</summary>
    public static void RatioWithin(decimal panel, decimal canonical, string label)
    {
        throw new NotImplementedException();
    }
}
