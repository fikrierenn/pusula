namespace Bkm.TestAltyapi;

public sealed record SaltOkumaSonucu(bool Gecti, string? Neden);

/// <summary>
/// Canlı ERP'ye gidecek SQL için sözdizimi kapısı (FR-015, R1): yalnız tek bir SELECT ya da WITH...SELECT geçer.
/// Fonksiyon/prosedür içindeki yan etkiyi görmez; ikinci savunma işlem geri alma ve salt-okuma oturumudur.
/// </summary>
public static class SaltOkumaKapisi
{
    private static readonly HashSet<string> s_yasakKelimeler = new(StringComparer.Ordinal)
    {
        "INSERT", "UPDATE", "DELETE", "MERGE", "EXEC", "EXECUTE", "DROP", "ALTER", "CREATE", "TRUNCATE",
        "GRANT", "REVOKE", "DENY", "INTO", "SET", "USE", "DBCC", "BACKUP", "RESTORE", "KILL", "SHUTDOWN",
        "OPENROWSET", "OPENDATASOURCE", "BULK",
    };

    public static SaltOkumaSonucu Denetle(string sql)
    {
        if (string.IsNullOrWhiteSpace(sql))
        {
            return Ret("boş girdi");
        }

        if (!SqlTaraycisi.Tara(sql, out List<Simge> simgeler, out string? taramaHatasi))
        {
            return Ret(taramaHatasi!);
        }

        string? yasak = IlkYasakNedeni(simgeler);
        if (yasak is not null)
        {
            return Ret(yasak);
        }

        string? yapi = YapiHatasi(simgeler);
        return (yapi is null) ? new SaltOkumaSonucu(true, null) : Ret(yapi);
    }

    private static SaltOkumaSonucu Ret(string neden)
    {
        return new SaltOkumaSonucu(false, neden);
    }

    private static string? IlkYasakNedeni(List<Simge> simgeler)
    {
        foreach (Simge simge in simgeler)
        {
            if ((simge.Tur == SimgeTuru.Kelime) && s_yasakKelimeler.Contains(simge.Metin))
            {
                return $"yasak kelime: {simge.Metin} (konum {simge.Konum})";
            }

            if ((simge.Tur == SimgeTuru.Dize) && (simge.Metin.Length > 0))
            {
                string? icerikNedeni = OpenQueryDizesiNedeni(simge);
                if (icerikNedeni is not null)
                {
                    return icerikNedeni;
                }
            }
        }

        return null;
    }

    // Yalnız OPENQUERY argümanı olan dizeler içerik taşır (tarayıcı diğerlerini boşaltır).
    private static string? OpenQueryDizesiNedeni(Simge dize)
    {
        if (!SqlTaraycisi.Tara(dize.Metin, out List<Simge> ic, out _))
        {
            return $"OPENQUERY dizesi çözümlenemedi (konum {dize.Konum})";
        }

        int sira = ic.FindIndex(s => (s.Tur == SimgeTuru.Kelime) && s_yasakKelimeler.Contains(s.Metin));
        return (sira >= 0)
            ? $"OPENQUERY dizesinde yazma kelimesi: {ic[sira].Metin} (konum {dize.Konum})"
            : null;
    }

    private static string? YapiHatasi(List<Simge> simgeler)
    {
        int bas = 0;
        while ((bas < simgeler.Count) && (simgeler[bas].Tur == SimgeTuru.NoktaliVirgul))
        {
            bas++;
        }

        if (bas >= simgeler.Count)
        {
            return "ilk anlamlı kelime yok";
        }

        Simge ilk = simgeler[bas];
        if (ilk.Tur != SimgeTuru.Kelime)
        {
            return $"tanınmayan ilk simge (konum {ilk.Konum})";
        }

        if ((ilk.Metin != "SELECT") && (ilk.Metin != "WITH"))
        {
            return $"tanınmayan ilk kelime: {ilk.Metin}";
        }

        if ((ilk.Metin == "WITH") && !CteSonrasiSelectMi(simgeler, bas + 1))
        {
            return "WITH sonrası SELECT yok";
        }

        return IkinciIfadeVarMi(simgeler, bas) ? "birden çok ifade" : null;
    }

    // Biçim: ad [(sütunlar)] AS (...) [, ad ... ] SELECT.
    private static bool CteSonrasiSelectMi(List<Simge> simgeler, int baslangic)
    {
        int i = baslangic;
        while (true)
        {
            if (!KelimeMi(simgeler, i))
            {
                return false;
            }

            i++;
            if (SimgeMi(simgeler, i, SimgeTuru.SolParantez))
            {
                i = DengeliGrubuAtla(simgeler, i);
            }

            if ((i < 0) || !KelimeMi(simgeler, i) || (simgeler[i].Metin != "AS"))
            {
                return false;
            }

            i++;
            if (!SimgeMi(simgeler, i, SimgeTuru.SolParantez))
            {
                return false;
            }

            i = DengeliGrubuAtla(simgeler, i);
            if (i < 0)
            {
                return false;
            }

            if ((i < simgeler.Count) && (simgeler[i].Tur == SimgeTuru.Diger) && (simgeler[i].Metin == ","))
            {
                i++;
                continue;
            }

            return KelimeMi(simgeler, i) && (simgeler[i].Metin == "SELECT");
        }
    }

    private static bool KelimeMi(List<Simge> simgeler, int i)
    {
        return SimgeMi(simgeler, i, SimgeTuru.Kelime);
    }

    private static bool SimgeMi(List<Simge> simgeler, int i, SimgeTuru tur)
    {
        return (i >= 0) && (i < simgeler.Count) && (simgeler[i].Tur == tur);
    }

    // Açılış parantezinden eşleşen kapanışın ardındaki indeksi verir; dengesizse -1.
    private static int DengeliGrubuAtla(List<Simge> simgeler, int acilis)
    {
        int derinlik = 0;
        for (int i = acilis; i < simgeler.Count; i++)
        {
            if (simgeler[i].Tur == SimgeTuru.SolParantez)
            {
                derinlik++;
            }
            else if (simgeler[i].Tur == SimgeTuru.SagParantez)
            {
                derinlik--;
                if (derinlik == 0)
                {
                    return i + 1;
                }
            }
        }

        return -1;
    }

    // İlk ';' sonrasında yalnız başka ';' kalabilir.
    private static bool IkinciIfadeVarMi(List<Simge> simgeler, int bas)
    {
        int ayirici = simgeler.FindIndex(bas, s => s.Tur == SimgeTuru.NoktaliVirgul);
        return (ayirici >= 0) && simgeler.Skip(ayirici).Any(s => s.Tur != SimgeTuru.NoktaliVirgul);
    }
}
