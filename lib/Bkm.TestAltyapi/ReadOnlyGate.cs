namespace Bkm.TestAltyapi;

public sealed record ReadOnlyGateResult(bool Passed, string? Reason);

/// <summary>
/// Canlı ERP'ye gidecek SQL için sözdizimi kapısı (FR-015, R1): yalnız tek bir SELECT ya da WITH...SELECT geçer.
/// Fonksiyon/görünüm içindeki yan etkiyi görmez; ikinci savunma işlem geri alma ve salt-okuma oturumudur.
/// </summary>
public static class ReadOnlyGate
{
    // K-r1-1: tam kelime, her konumda; dize, yorum ve tanımlayıcı gövdesi taranmaz.
    private static readonly HashSet<string> s_forbiddenWords = new(StringComparer.Ordinal)
    {
        "INSERT", "UPDATE", "DELETE", "MERGE", "EXEC", "EXECUTE", "DROP", "ALTER", "CREATE", "TRUNCATE",
        "GRANT", "REVOKE", "DENY", "INTO", "SET", "USE", "DBCC", "BACKUP", "RESTORE", "KILL", "SHUTDOWN",
        "OPENROWSET", "OPENDATASOURCE", "BULK",
        "COMMIT", "ROLLBACK", "SAVE", "BEGIN", "DECLARE", "WRITETEXT", "UPDATETEXT", "READTEXT",
        "DISABLE", "ENABLE", "SEND", "RECEIVE", "WAITFOR", "RECONFIGURE", "CHECKPOINT", "OPENQUERY",
        "TABLOCKX", "TABLOCK", "XLOCK", "UPDLOCK", "HOLDLOCK", "PAGLOCK",
    };

    public static ReadOnlyGateResult Check(string sql)
    {
        if (string.IsNullOrWhiteSpace(sql))
        {
            return Reject("boş girdi");
        }

        if (!SqlScanner.Scan(sql, out List<Token> tokens, out string? scanError))
        {
            return Reject(scanError!);
        }

        string? forbidden = FirstForbidden(tokens);
        if (forbidden is not null)
        {
            return Reject(forbidden);
        }

        string? structure = StructureError(tokens);
        return (structure is null) ? new ReadOnlyGateResult(true, null) : Reject(structure);
    }

    private static ReadOnlyGateResult Reject(string reason)
    {
        return new ReadOnlyGateResult(false, reason);
    }

    private static string? FirstForbidden(List<Token> tokens)
    {
        for (int i = 0; i < tokens.Count; i++)
        {
            Token token = tokens[i];
            if (token.Kind != TokenKind.Word)
            {
                continue;
            }

            if (s_forbiddenWords.Contains(token.Text))
            {
                return $"yasak kelime: {token.Text} (konum {token.Position})";
            }

            // FETCH NEXT ... meşru; yalnız NEXT VALUE FOR (dizi üretimi, yazma) yasak.
            bool nextValue = (token.Text == "NEXT") && IsWord(tokens, i + 1, "VALUE");
            if (nextValue)
            {
                return $"yasak kelime: NEXT VALUE (konum {token.Position})";
            }
        }

        return null;
    }

    private static string? StructureError(List<Token> tokens)
    {
        int start = 0;
        while ((start < tokens.Count) && (tokens[start].Kind == TokenKind.Semicolon))
        {
            start++;
        }

        if (start >= tokens.Count)
        {
            return "ilk anlamlı kelime yok";
        }

        Token first = tokens[start];
        if (first.Kind != TokenKind.Word)
        {
            return $"tanınmayan ilk simge (konum {first.Position})";
        }

        if ((first.Text != "SELECT") && (first.Text != "WITH"))
        {
            return $"tanınmayan ilk kelime: {first.Text}";
        }

        if ((first.Text == "WITH") && !SelectFollowsCtes(tokens, start + 1))
        {
            return "WITH sonrası SELECT yok";
        }

        return HasSecondStatement(tokens, start) ? "birden çok ifade" : null;
    }

    // Biçim: ad [(sütunlar)] AS (...) [, ad ... ] SELECT.
    private static bool SelectFollowsCtes(List<Token> tokens, int from)
    {
        int i = from;
        while (true)
        {
            if (!IsKind(tokens, i, TokenKind.Word))
            {
                return false;
            }

            i++;
            if (IsKind(tokens, i, TokenKind.LeftParen))
            {
                i = SkipBalancedGroup(tokens, i);
            }

            if (!IsWord(tokens, i, "AS"))
            {
                return false;
            }

            i++;
            if (!IsKind(tokens, i, TokenKind.LeftParen))
            {
                return false;
            }

            i = SkipBalancedGroup(tokens, i);
            if (i < 0)
            {
                return false;
            }

            if (IsKind(tokens, i, TokenKind.Other) && (tokens[i].Text == ","))
            {
                i++;
                continue;
            }

            return IsWord(tokens, i, "SELECT");
        }
    }

    private static bool IsWord(List<Token> tokens, int i, string word)
    {
        return IsKind(tokens, i, TokenKind.Word) && (tokens[i].Text == word);
    }

    private static bool IsKind(List<Token> tokens, int i, TokenKind kind)
    {
        return (i >= 0) && (i < tokens.Count) && (tokens[i].Kind == kind);
    }

    // Açılış parantezinden eşleşen kapanışın ardındaki indeksi verir; dengesizse -1.
    private static int SkipBalancedGroup(List<Token> tokens, int open)
    {
        int depth = 0;
        for (int i = open; i < tokens.Count; i++)
        {
            if (tokens[i].Kind == TokenKind.LeftParen)
            {
                depth++;
            }
            else if (tokens[i].Kind == TokenKind.RightParen)
            {
                depth--;
                if (depth == 0)
                {
                    return i + 1;
                }
            }
        }

        return -1;
    }

    // İlk ';' sonrasında yalnız başka ';' kalabilir.
    private static bool HasSecondStatement(List<Token> tokens, int start)
    {
        int separator = tokens.FindIndex(start, t => t.Kind == TokenKind.Semicolon);
        return (separator >= 0) && tokens.Skip(separator).Any(t => t.Kind != TokenKind.Semicolon);
    }
}
