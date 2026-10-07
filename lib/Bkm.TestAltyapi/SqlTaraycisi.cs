using System.Text;

namespace Bkm.TestAltyapi;

internal enum SimgeTuru
{
    Kelime,
    Dize,
    NoktaliVirgul,
    SolParantez,
    SagParantez,
    Diger,
}

internal readonly record struct Simge(SimgeTuru Tur, string Metin, int Konum);

/// <summary>
/// T-SQL metnini dize, yorum ve tanımlayıcı gövdelerinden arındırılmış simge listesine çevirir.
/// Kapanmamış dize/yorum/tanımlayıcı hata sayılır (tanınmayan her şey reddedilir).
/// </summary>
internal static class SqlTaraycisi
{
    public static bool Tara(string sql, out List<Simge> simgeler, out string? hata)
    {
        simgeler = [];
        hata = null;
        int konum = 0;
        int parantezDerinligi = 0;
        int openQueryDerinligi = -1;
        bool openQueryBekliyor = false;

        while (konum < sql.Length)
        {
            char c = sql[konum];

            if (char.IsWhiteSpace(c))
            {
                konum++;
            }
            else if ((c == '-') && SonrakiMi(sql, konum, '-'))
            {
                konum = SatirYorumunuAtla(sql, konum);
            }
            else if ((c == '/') && SonrakiMi(sql, konum, '*'))
            {
                konum = BlokYorumunuAtla(sql, konum);
                if (konum < 0)
                {
                    hata = "kapanmamış blok yorum";
                    return false;
                }
            }
            else if (c == '\'')
            {
                int bas = konum;
                konum = KapaliBolumuAtla(sql, konum, '\'', out string icerik);
                if (konum < 0)
                {
                    hata = "kapanmamış dize";
                    return false;
                }

                if (openQueryDerinligi >= 0)
                {
                    simgeler.Add(new Simge(SimgeTuru.Dize, icerik, bas));
                }
                else
                {
                    simgeler.Add(new Simge(SimgeTuru.Dize, string.Empty, bas));
                }
            }
            else if ((c == '[') || (c == '"'))
            {
                konum = KapaliBolumuAtla(sql, konum, c == '[' ? ']' : '"', out _);
                if (konum < 0)
                {
                    hata = "kapanmamış tanımlayıcı";
                    return false;
                }
            }
            else if (KelimeBaslangici(c))
            {
                int bas = konum;
                while ((konum < sql.Length) && KelimeParcasi(sql[konum]))
                {
                    konum++;
                }

                string kelime = sql[bas..konum].ToUpperInvariant();

                // N'...' ön eki dizenin parçasıdır, ayrı kelime değil.
                bool unicodeOnEki = (kelime == "N") && (konum < sql.Length) && (sql[konum] == '\'');
                if (!unicodeOnEki)
                {
                    simgeler.Add(new Simge(SimgeTuru.Kelime, kelime, bas));
                    openQueryBekliyor = openQueryBekliyor || (kelime == "OPENQUERY");
                }
            }
            else
            {
                SimgeTuru tur = c switch
                {
                    ';' => SimgeTuru.NoktaliVirgul,
                    '(' => SimgeTuru.SolParantez,
                    ')' => SimgeTuru.SagParantez,
                    _ => SimgeTuru.Diger,
                };
                simgeler.Add(new Simge(tur, c.ToString(), konum));

                if (tur == SimgeTuru.SolParantez)
                {
                    if (openQueryBekliyor)
                    {
                        openQueryDerinligi = parantezDerinligi;
                        openQueryBekliyor = false;
                    }

                    parantezDerinligi++;
                }
                else if (tur == SimgeTuru.SagParantez)
                {
                    parantezDerinligi = Math.Max(0, parantezDerinligi - 1);
                    if (parantezDerinligi == openQueryDerinligi)
                    {
                        openQueryDerinligi = -1;
                    }
                }

                konum++;
            }
        }

        return true;
    }

    private static bool SonrakiMi(string sql, int konum, char beklenen)
    {
        return ((konum + 1) < sql.Length) && (sql[konum + 1] == beklenen);
    }

    private static bool KelimeBaslangici(char c)
    {
        return char.IsLetterOrDigit(c) || (c == '_') || (c == '@') || (c == '#');
    }

    private static bool KelimeParcasi(char c)
    {
        return KelimeBaslangici(c) || (c == '$');
    }

    private static int SatirYorumunuAtla(string sql, int konum)
    {
        int satirSonu = sql.IndexOf('\n', konum);
        return (satirSonu < 0) ? sql.Length : (satirSonu + 1);
    }

    // T-SQL blok yorumları iç içe sayılır; kapanmamışsa -1 döner.
    private static int BlokYorumunuAtla(string sql, int konum)
    {
        int derinlik = 0;
        int i = konum;
        while (i < sql.Length)
        {
            if ((sql[i] == '/') && SonrakiMi(sql, i, '*'))
            {
                derinlik++;
                i += 2;
            }
            else if ((sql[i] == '*') && SonrakiMi(sql, i, '/'))
            {
                derinlik--;
                i += 2;
                if (derinlik == 0)
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
    private static int KapaliBolumuAtla(string sql, int konum, char kapanis, out string icerik)
    {
        StringBuilder birikim = new();
        int i = konum + 1;
        while (i < sql.Length)
        {
            if (sql[i] != kapanis)
            {
                birikim.Append(sql[i]);
                i++;
            }
            else if (SonrakiMi(sql, i, kapanis))
            {
                birikim.Append(kapanis);
                i += 2;
            }
            else
            {
                icerik = birikim.ToString();
                return i + 1;
            }
        }

        icerik = string.Empty;
        return -1;
    }
}
