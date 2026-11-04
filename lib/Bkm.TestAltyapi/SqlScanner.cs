using System.Text;

namespace Bkm.TestAltyapi;

internal enum TokenKind
{
    Word,
    Literal,
    Semicolon,
    LeftParen,
    RightParen,
    Other,
}

internal readonly record struct Token(TokenKind Kind, string Text, int Position);

/// <summary>
/// T-SQL metnini dize, yorum ve tanımlayıcı gövdelerinden arındırılmış simge listesine çevirir.
/// Kapanmamış dize/yorum/tanımlayıcı hata sayılır (tanınmayan her şey reddedilir).
/// </summary>
internal static class SqlScanner
{
    public static bool Scan(string sql, out List<Token> tokens, out string? error)
    {
        tokens = [];
        error = null;
        int position = 0;

        while (position < sql.Length)
        {
            char c = sql[position];

            if (char.IsWhiteSpace(c))
            {
                position++;
            }
            else if ((c == '-') && NextIs(sql, position, '-'))
            {
                position = SkipLineComment(sql, position);
            }
            else if ((c == '/') && NextIs(sql, position, '*'))
            {
                position = SkipBlockComment(sql, position);
                if (position < 0)
                {
                    error = "kapanmamış blok yorum";
                    return false;
                }
            }
            else if (c == '\'')
            {
                int start = position;
                position = SkipQuoted(sql, position, '\'');
                if (position < 0)
                {
                    error = "kapanmamış dize";
                    return false;
                }

                tokens.Add(new Token(TokenKind.Literal, string.Empty, start));
            }
            else if ((c == '[') || (c == '"'))
            {
                position = SkipQuoted(sql, position, c == '[' ? ']' : '"');
                if (position < 0)
                {
                    error = "kapanmamış tanımlayıcı";
                    return false;
                }
            }
            else if (IsWordStart(c))
            {
                int start = position;
                while ((position < sql.Length) && IsWordPart(sql[position]))
                {
                    position++;
                }

                string word = sql[start..position].ToUpperInvariant();

                // N'...' ön eki dizenin parçasıdır, ayrı kelime değil.
                bool unicodePrefix = (word == "N") && (position < sql.Length) && (sql[position] == '\'');
                if (!unicodePrefix)
                {
                    tokens.Add(new Token(TokenKind.Word, word, start));
                }
            }
            else
            {
                TokenKind kind = c switch
                {
                    ';' => TokenKind.Semicolon,
                    '(' => TokenKind.LeftParen,
                    ')' => TokenKind.RightParen,
                    _ => TokenKind.Other,
                };
                tokens.Add(new Token(kind, c.ToString(), position));
                position++;
            }
        }

        return true;
    }

    private static bool NextIs(string sql, int position, char expected)
    {
        return ((position + 1) < sql.Length) && (sql[position + 1] == expected);
    }

    private static bool IsWordStart(char c)
    {
        return char.IsLetterOrDigit(c) || (c == '_') || (c == '@') || (c == '#');
    }

    private static bool IsWordPart(char c)
    {
        return IsWordStart(c) || (c == '$');
    }

    // Satır yorumu \n, \r, U+0085, U+2028 ya da U+2029 ile biter (K-r1-2).
    private static int SkipLineComment(string sql, int position)
    {
        int end = sql.AsSpan(position).IndexOfAny("\n\r\u0085\u2028\u2029");
        return (end < 0) ? sql.Length : (position + end + 1);
    }

    // T-SQL blok yorumları iç içe sayılır; kapanmamışsa -1 döner.
    private static int SkipBlockComment(string sql, int position)
    {
        int depth = 0;
        int i = position;
        while (i < sql.Length)
        {
            if ((sql[i] == '/') && NextIs(sql, i, '*'))
            {
                depth++;
                i += 2;
            }
            else if ((sql[i] == '*') && NextIs(sql, i, '/'))
            {
                depth--;
                i += 2;
                if (depth == 0)
                {
                    return i;
                }
            }
            else
            {
                i++;
            }
        }

        return -1;
    }

    // Açılış karakterinden sonra kapanışı bulur; ikiye katlanmış kapanış kaçıştır. Kapanmamışsa -1.
    private static int SkipQuoted(string sql, int position, char closing)
    {
        int i = position + 1;
        while (i < sql.Length)
        {
            if (sql[i] != closing)
            {
                i++;
            }
            else if (NextIs(sql, i, closing))
            {
                i += 2;
            }
            else
            {
                return i + 1;
            }
        }

        return -1;
    }
}
