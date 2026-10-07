using Bkm.TestAltyapi;

namespace GmDashboard.Tests.Altyapi;

// Kanonik arşiv + koruma girdileri + kırmızı-kip sahte klasörü kapıdan geçmeli (R1, FR-015).
// Birim testidir (DB yok): `Tur` Trait'i bilerek yok (K-karar-5), mesai içi komutta görünür.
[Trait("AC", "FR-015")]
[Trait("AC", "R1")]
public class KanonikDosyaKapisiTests
{
    public static IEnumerable<object[]> TumBloklar()
    {
        return KanonikBlokOkuyucu.Satirlar("Kanonik", Path.Combine("Koruma", "Eski"), Path.Combine("Altyapi", "Sahte"));
    }

    [Theory]
    [MemberData(nameof(TumBloklar))]
    public void KanonikDosyalar_Hepsi_SaltOkumaKapisindanGecer(string dosya, string blok, string govde)
    {
        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(govde);

        Assert.True(sonuc.Gecti, $"{dosya} blok {blok}: {sonuc.Neden}");
    }

    [Fact]
    public void KanonikDosyalar_Nufus_BosDegil()
    {
        var kanonik = KanonikBlokOkuyucu.Dosyalar("Kanonik").ToList();
        var bloklar = kanonik.SelectMany(d => KanonikBlokOkuyucu.Bol(d.Dosya, d.Metin)).ToList();

        Assert.True(kanonik.Count > 0, "KOŞAMADI: kanonik dosya bulunamadı");
        Assert.True(bloklar.Count >= kanonik.Count, "KOŞAMADI: blok bulunamadı");
    }

    [Fact]
    public void KanonikDosyalar_BlokIsareti_SatirOrtasindaBolmez()
    {
        var bloklar = KanonikBlokOkuyucu.Bol("bellek.sql", "SELECT 1 AS a -- blok: x");

        Assert.Single(bloklar);
        Assert.True(SaltOkumaKapisi.Denetle(bloklar[0].Govde).Gecti);
    }

    [Fact]
    public void KanonikDosyalar_BaslikYorumu_KapiyaGirenIfadeOlmaz()
    {
        string metin = "-- ork:hedef-db EncoreMerkez\n/* Soru: x */\n-- blok: A\nSELECT 1 AS a\nGO\n";

        var bloklar = KanonikBlokOkuyucu.Bol("bellek.sql", metin);

        Assert.Single(bloklar);
        Assert.True(SaltOkumaKapisi.Denetle(bloklar[0].Govde).Gecti);
    }

    [Fact]
    public void KanonikDosyalar_Blok_GoSatiriAyiklanir()
    {
        var bloklar = KanonikBlokOkuyucu.Bol("bellek.sql", "-- blok: A\nSELECT 1\nGO\n-- blok: B\nSELECT 2");

        Assert.Equal(2, bloklar.Count);
        Assert.All(bloklar, b => Assert.True(SaltOkumaKapisi.Denetle(b.Govde).Gecti));
    }

    [Fact]
    public void KanonikDosyalar_Blok_DeclareOnEkiAyiklanir()
    {
        string metin = "-- blok: A\nDECLARE @Bas date = CONVERT(date, '01.09.2026', 104), @Bit date = CONVERT(date, '01.10.2026', 104);\nSELECT @Bas AS b";

        var bloklar = KanonikBlokOkuyucu.Bol("bellek.sql", metin);

        Assert.DoesNotContain("DECLARE", bloklar[0].Govde, StringComparison.OrdinalIgnoreCase);
        Assert.True(SaltOkumaKapisi.Denetle(bloklar[0].Govde).Gecti);
    }

    [Fact]
    public void KanonikDosyalar_Blok_OrtadakiDeclareReddedilir()
    {
        var bloklar = KanonikBlokOkuyucu.Bol("bellek.sql", "-- blok: A\nSELECT 1;\nDECLARE @x int = 1;\nSELECT @x");

        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(bloklar[0].Govde);

        Assert.False(sonuc.Gecti);
    }

    [Fact]
    public void KanonikDosyalar_Blok_UpdateIceren_Reddedilir()
    {
        var bloklar = KanonikBlokOkuyucu.Bol("sahte.sql", "-- blok: A\nSELECT 1 AS a\nUPDATE dbo.x SET a=1");

        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(bloklar[0].Govde);

        Assert.False(sonuc.Gecti);
        Assert.Contains("UPDATE", sonuc.Neden, StringComparison.OrdinalIgnoreCase);
    }
}
