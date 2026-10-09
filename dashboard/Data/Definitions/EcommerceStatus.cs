namespace GmDashboard.Data.Definitions;

/// <summary>
/// E-commerce status lists excluded from net revenue (order and line cancel/return).
/// </summary>
public static class EcommerceStatus
{
    public const string OrderCancelReturn = "1001,1006,1007,3000,4000";

    public const string LineCancelReturn = "2004,2005,2010";
}
