using System.Globalization;
using Xunit;

namespace Bkm.TestAltyapi;

/// <summary>Panel rakamı ile kanonik rakam karşılaştırma toleransları.</summary>
public static class Tolerance
{
    /// <summary>Tutar için mutlak tolerans (TL).</summary>
    public const decimal Amount = 1.00m;

    /// <summary>Oran için göreli tolerans.</summary>
    public const decimal Ratio = 0.003m;

    private static readonly CultureInfo s_turkish = CultureInfo.GetCultureInfo("tr-TR");

    /// <summary>Tutarlar tolerans içinde eşit değilse test hatası verir.</summary>
    public static void AmountEqual(decimal panel, decimal canonical, string label)
    {
        decimal difference = Math.Abs(panel - canonical);
        if (difference > Amount)
        {
            Assert.Fail(
                $"{label}: panel {Format(panel)} ≠ kanonik {Format(canonical)} (fark {Format(difference)}, izin {Format(Amount)}).");
        }
    }

    /// <summary>Panel değeri kanonik değerin göreli toleransı içinde değilse test hatası verir.</summary>
    public static void RatioWithin(decimal panel, decimal canonical, string label)
    {
        if (canonical == 0m)
        {
            if (panel != 0m)
            {
                Assert.Fail($"{label}: panel {Format(panel)} ≠ kanonik {Format(canonical)} (kanonik sıfır, oran hesaplanamaz).");
            }

            return;
        }

        decimal ratio = Math.Abs(panel - canonical) / Math.Abs(canonical);
        if (ratio > Ratio)
        {
            Assert.Fail(
                $"{label}: panel {Format(panel)} ≠ kanonik {Format(canonical)} (oran {ratio.ToString("P2", s_turkish)}, izin {Ratio.ToString("P2", s_turkish)}).");
        }
    }

    private static string Format(decimal value)
    {
        return value.ToString("N2", s_turkish);
    }
}
