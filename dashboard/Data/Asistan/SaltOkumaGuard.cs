using System.Text.RegularExpressions;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// Asistan SQL güvenliği (plan-20) — yalnızca SELECT/WITH okuma. CFO asistanı asla yazmaz.
/// Yasak: INSERT/UPDATE/DELETE/DROP/ALTER/EXEC/MERGE/TRUNCATE/GRANT/CREATE + multi-statement + sp_/xp_.
/// Db zaten ALLOW_WRITE=false ama bu ikinci savunma (asistan-üretilen SQL doğrudan çalışır → guard tek kapı).
/// </summary>
public static class SaltOkumaGuard
{
    // Yasak anahtar kelimeler (kelime-sınırlı; yorum/string içinde değil — basit ama katı).
    private static readonly string[] Yasak =
    {
        "INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "TRUNCATE", "MERGE",
        "EXEC", "EXECUTE", "GRANT", "REVOKE", "CREATE", "INTO", "BACKUP", "RESTORE",
    };

    /// <summary>SQL salt-okuma mı? Değilse (false, sebep). Geçerliyse (true, null).</summary>
    public static (bool Ok, string? Sebep) Dogrula(string? sql)
    {
        if (string.IsNullOrWhiteSpace(sql)) return (false, "Boş sorgu.");
        var s = sql.Trim();

        // Çoklu statement engeli: ortada ';' (sondaki tek ';' serbest).
        var govde = s.TrimEnd(';', ' ', '\t', '\r', '\n');
        if (govde.Contains(';')) return (false, "Çoklu statement yasak (tek SELECT).");

        // SELECT veya WITH (CTE) ile başlamalı.
        var bas = govde.TrimStart('(', ' ', '\t', '\r', '\n');
        if (!bas.StartsWith("SELECT", StringComparison.OrdinalIgnoreCase) &&
            !bas.StartsWith("WITH", StringComparison.OrdinalIgnoreCase))
            return (false, "Yalnızca SELECT/WITH (okuma) sorgusu çalıştırılır.");

        // Yasak keyword (kelime sınırı — SUM içindeki 'INTO' gibi yanlış-pozitifi önle).
        foreach (var k in Yasak)
            if (Regex.IsMatch(govde, $@"\b{k}\b", RegexOptions.IgnoreCase))
                return (false, $"Yazma/DDL anahtar kelimesi yasak: {k}. Asistan yalnızca okuma yapar.");

        // sp_/xp_ stored proc çağrısı.
        if (Regex.IsMatch(govde, @"\b(sp_|xp_)\w+", RegexOptions.IgnoreCase))
            return (false, "Stored procedure çağrısı yasak.");

        return (true, null);
    }
}
