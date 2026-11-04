using System.Text.RegularExpressions;
using Bkm.TestAltyapi;
using GmDashboard.Data.Definitions;

namespace GmDashboard.Tests.Unit;

// E-ticaret durum listesi (T-026): sabitler sema/codes.yaml kaydıyla eşit kalır. Birim testidir; Trait'siz.
public class EcommerceStatusTests
{
    private const string RegistryPath = "sema/codes.yaml";

    [Fact]
    public void EcommerceStatus_OrderCancelReturn_MatchesRegistryCodes()
    {
        // Arrange
        int[] expected = ReadRegistryList("joker.J_ORDERS.STATUS");

        // Act
        int[] actual = ParseCodes(EcommerceStatus.OrderCancelReturn);

        // Assert
        Assert.Equal(expected, actual);
    }

    [Fact]
    public void EcommerceStatus_LineCancelReturn_MatchesRegistryCodes()
    {
        // Arrange
        int[] expected = ReadRegistryList("joker.J_ORDER_DETAILS.STATUS");

        // Act
        int[] actual = ParseCodes(EcommerceStatus.LineCancelReturn);

        // Assert
        Assert.Equal(expected, actual);
    }

    [Fact]
    public void EcommerceStatus_OrderCancelReturn_ExcludesWarehousePreparationStages()
    {
        // Act
        int[] codes = ParseCodes(EcommerceStatus.OrderCancelReturn);

        // Assert
        Assert.NotEmpty(codes);
        Assert.DoesNotContain(3004, codes);
        Assert.DoesNotContain(3006, codes);
    }

    [Fact]
    public void EcommerceStatus_Constants_AreCommaSeparatedWithoutSpaces()
    {
        // Assert
        Assert.Matches(@"^\d+(,\d+)*$", EcommerceStatus.OrderCancelReturn);
        Assert.Matches(@"^\d+(,\d+)*$", EcommerceStatus.LineCancelReturn);
    }

    private static int[] ParseCodes(string commaSeparated)
    {
        return commaSeparated
            .Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries)
            .Select(code => int.Parse(code, System.Globalization.CultureInfo.InvariantCulture))
            .Order()
            .ToArray();
    }

    private static int[] ReadRegistryList(string recordKey)
    {
        string yaml = SourceFile.Read(RegistryPath);
        string pattern = @"^  " + Regex.Escape(recordKey) + @":(?:(?!^  \S)[\s\S])*?^\s+net_iptal_iade:\s*\[([^\]]*)\]";
        Match match = Regex.Match(yaml, pattern, RegexOptions.Multiline);

        Assert.True(match.Success, $"KOŞAMADI: {RegistryPath} içinde '{recordKey}' kaydı ya da net_iptal_iade alanı bulunamadı");
        return ParseCodes(match.Groups[1].Value);
    }
}
