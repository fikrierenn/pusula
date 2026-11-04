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

    private const string ExcludeRecyclingJoinTemplate = "LEFT JOIN (SELECT DISTINCT gd0.SalesId FROM EncoreMerkez.dbo.SalesProducts gd0 WITH(NOLOCK) WHERE gd0.BarcodeNo = '1001') gd ON gd.SalesId = {sales}.Id";

    // The sales parameter is a code-internal alias (such as "s"); user input never reaches the SQL fragment.
    public static string ExcludeRecyclingJoin(string sales)
    {
        return ExcludeRecyclingJoinTemplate.Replace("{sales}", sales, StringComparison.Ordinal);
    }

    public static string NetExVat(string sales)
    {
        return $"(CASE WHEN {sales}.DocumentsTypeId = 3 THEN -1 ELSE 1 END * ({sales}.GrossTotal - {sales}.DiscountTotal - {sales}.VatTotal))";
    }

    public static string ReturnExVat(string sales)
    {
        return $"(CASE WHEN {sales}.DocumentsTypeId = 3 THEN {sales}.GrossTotal - {sales}.DiscountTotal - {sales}.VatTotal ELSE 0 END)";
    }
}
