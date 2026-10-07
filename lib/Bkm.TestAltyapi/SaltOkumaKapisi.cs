namespace Bkm.TestAltyapi;

public sealed record SaltOkumaSonucu(bool Gecti, string? Neden);

public static class SaltOkumaKapisi
{
    public static SaltOkumaSonucu Denetle(string sql)
    {
        throw new NotImplementedException();
    }
}
