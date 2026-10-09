namespace GmDashboard.Data.Definitions;

/// <summary>
/// Store net definition: document types, recycling exclusion and VAT-exclusive net/return expressions.
/// </summary>
public static class ReceiptDefinition
{
    public const string StoreDocumentTypes = "1,2,3,6,7,8";

    public const int SalesReceipt = 1;

    public const int Return = 3;

    public const int ExamSchools = 8;

    public const string ExcludeRecyclingCondition = "gd.SalesId IS NULL";

    public static string ExcludeRecyclingJoin(string sales)
    {
        throw new NotImplementedException();
    }

    public static string NetExVat(string sales)
    {
        throw new NotImplementedException();
    }

    public static string ReturnExVat(string sales)
    {
        throw new NotImplementedException();
    }
}
