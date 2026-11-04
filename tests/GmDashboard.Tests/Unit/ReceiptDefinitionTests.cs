using GmDashboard.Data.Definitions;

namespace GmDashboard.Tests.Unit;

// Fiş tanımı (T-025): takma ad doğru yere yazılır, sabitler sözleşmedeki değerde kalır. Birim testidir; Trait'siz.
public class ReceiptDefinitionTests
{
    [Fact]
    public void ReceiptDefinition_ExcludeRecyclingJoin_WritesAliasIntoOnCondition()
    {
        // Arrange
        const string alias = "x";

        // Act
        string join = ReceiptDefinition.ExcludeRecyclingJoin(alias);

        // Assert
        Assert.Contains("gd.SalesId = x.Id", join, StringComparison.Ordinal);
        Assert.DoesNotContain("{sales}", join, StringComparison.Ordinal);
    }

    [Fact]
    public void ReceiptDefinition_ExcludeRecyclingJoin_ReturnsExactText()
    {
        // Act
        string join = ReceiptDefinition.ExcludeRecyclingJoin("s");

        // Assert
        Assert.Equal(
            "LEFT JOIN (SELECT DISTINCT gd0.SalesId FROM EncoreMerkez.dbo.SalesProducts gd0 WITH(NOLOCK) WHERE gd0.BarcodeNo = '1001') gd ON gd.SalesId = s.Id",
            join);
    }

    [Fact]
    public void ReceiptDefinition_NetExVat_ReturnsExactText()
    {
        // Act
        string expression = ReceiptDefinition.NetExVat("s");

        // Assert
        Assert.Equal(
            "(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal))",
            expression);
    }

    [Fact]
    public void ReceiptDefinition_NetExVat_WritesAliasIntoEveryColumn()
    {
        // Act
        string expression = ReceiptDefinition.NetExVat("fs");

        // Assert
        Assert.Contains("fs.DocumentsTypeId", expression, StringComparison.Ordinal);
        Assert.Contains("fs.GrossTotal", expression, StringComparison.Ordinal);
        Assert.Contains("fs.DiscountTotal", expression, StringComparison.Ordinal);
        Assert.Contains("fs.VatTotal", expression, StringComparison.Ordinal);
        Assert.DoesNotContain("s.GrossTotal - s.", expression, StringComparison.Ordinal);
    }

    [Fact]
    public void ReceiptDefinition_ReturnExVat_ReturnsExactText()
    {
        // Act
        string expression = ReceiptDefinition.ReturnExVat("s");

        // Assert
        Assert.Equal(
            "(CASE WHEN s.DocumentsTypeId = 3 THEN s.GrossTotal - s.DiscountTotal - s.VatTotal ELSE 0 END)",
            expression);
    }

    [Fact]
    public void ReceiptDefinition_ReturnExVat_WritesAliasIntoEveryColumn()
    {
        // Act
        string expression = ReceiptDefinition.ReturnExVat("fs");

        // Assert
        Assert.Contains("fs.DocumentsTypeId", expression, StringComparison.Ordinal);
        Assert.Contains("fs.GrossTotal", expression, StringComparison.Ordinal);
        Assert.Contains("fs.DiscountTotal", expression, StringComparison.Ordinal);
        Assert.Contains("fs.VatTotal", expression, StringComparison.Ordinal);
        Assert.DoesNotContain("{sales}", expression, StringComparison.Ordinal);
    }

    [Fact]
    public void ReceiptDefinition_Constants_HoldContractValues()
    {
        // Assert
        Assert.Equal("1,2,3,6,7,8", ReceiptDefinition.StoreDocumentTypes);
        Assert.Equal(1, ReceiptDefinition.SalesReceipt);
        Assert.Equal(3, ReceiptDefinition.Return);
        Assert.Equal(8, ReceiptDefinition.ExamSchools);
        Assert.Equal("gd.SalesId IS NULL", ReceiptDefinition.ExcludeRecyclingCondition);
    }
}
