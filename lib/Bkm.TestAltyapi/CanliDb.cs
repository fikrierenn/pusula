using Bkm.Shared.Data;

namespace Bkm.TestAltyapi;

public enum Hedef
{
    Erp,
    Joker,
}

public static class CanliDb
{
    public static Db PanelDb()
    {
        throw new NotImplementedException();
    }

    public static Task<IReadOnlyList<T>> SorguAsync<T>(
        Hedef hedef,
        string sql,
        object? param = null,
        CancellationToken ct = default)
    {
        throw new NotImplementedException();
    }

    public static Task<T> TekDegerAsync<T>(
        Hedef hedef,
        string sql,
        object? param = null,
        CancellationToken ct = default)
    {
        throw new NotImplementedException();
    }
}
