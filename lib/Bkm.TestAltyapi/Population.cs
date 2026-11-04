using Xunit;

namespace Bkm.TestAltyapi;

/// <summary>Nüfus sıfırsa "geçti" değil "KOŞAMADI" der.</summary>
public static class Population
{
    /// <summary>Nüfus 1'den küçükse test KOŞAMADI hatasıyla biter.</summary>
    public static void AtLeast(int n, string reason)
    {
        if (n < 1)
        {
            Assert.Fail("KOŞAMADI: nüfus 0 — " + reason);
        }
    }
}
