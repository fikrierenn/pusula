# Ortak tanımlar — `dashboard/Data/Tanimlar/`

Tek kaynak ilkesi (`emitter-ayrimi.md`): bir tanım SQL'de **bir yerde** yazılır, panelin her sorgusu onu kullanır. Emsal: `IcKartFiltre` (`Data/IcKartService.cs:11`). Parçalar sabit metindir; kullanıcı girdisi içermez. Takma ad alan metotlar yalnız kod içi sabit takma adla çağrılır (`"s"`, `"sp"`).

Namespace: `GmDashboard.Data.Tanimlar`. Hepsi `public static class`.

## 1. `FisTanimi`

Kanonik fiş (spec FR-005, kullanıcı kararı 03.10.2026): **yalnız perakende satış fişi (`DocumentsTypeId = 1`), geri dönüşüm (1001) satırı taşıyan belge hariç.** İade, fatura, personel ve Sınav Okulları belgesi fiş sayılmaz. İade ayrı sayılır.

```csharp
public static class FisTanimi
{
    // Belge tipi kümeleri (sema codes: EncoreMerkez.Sales.DocumentsTypeId)
    public const string MagazaBelgeleri = "1,2,3,6,7,8";   // mağaza neti kapsamı (değişmedi)
    public const int SatisFisi = 1;
    public const int Iade = 3;
    public const int SinavOkullari = 8;

    /// WHERE için anti-join: 1001 satırı taşıyan belgeyi tamamen dışlar.
    /// Mevcut davranışla aynı: 1001 satırının IsValid değerine bakmaz (SC-006 paritesi).
    public static string GeriDonusumHaricJoin(string sales);   // "LEFT JOIN (SELECT DISTINCT gd0.SalesId FROM EncoreMerkez.dbo.SalesProducts gd0 WITH(NOLOCK) WHERE gd0.BarcodeNo = '1001') gd ON gd.SalesId = {sales}.Id"
    public const string GeriDonusumHaricKosul = "gd.SalesId IS NULL";

    /// Aggregate içinde kullanılabilen ifadeler (alt sorgu içermez; GeriDonusumHaricJoin gerektirir).
    public static string FisSayisi(string sales);    // "COUNT(CASE WHEN {sales}.DocumentsTypeId = 1 AND gd.SalesId IS NULL THEN 1 END)"
    public static string IadeSayisi(string sales);   // "COUNT(CASE WHEN {sales}.DocumentsTypeId = 3 AND gd.SalesId IS NULL THEN 1 END)"   ← İnsan onayı 1
    public static string NetKdvHaric(string sales);  // "(CASE WHEN {sales}.DocumentsTypeId = 3 THEN -1 ELSE 1 END * ({sales}.GrossTotal - {sales}.DiscountTotal - {sales}.VatTotal))"
    public static string IadeKdvHaric(string sales); // "(CASE WHEN {sales}.DocumentsTypeId = 3 THEN {sales}.GrossTotal - {sales}.DiscountTotal - {sales}.VatTotal ELSE 0 END)"

    /// Kanal ayracı (perakende / Sınav). İade, bağlı olduğu belgenin kanalına yazılır.
    /// Emsal: GunKarsilastirQueries (LinkedDocumentId > 0, sıfır sentinel).
    public static string KanalJoin(string sales);    // "LEFT JOIN EncoreMerkez.dbo.Sales kn WITH(NOLOCK) ON kn.Id = {sales}.LinkedDocumentId AND {sales}.LinkedDocumentId > 0"
    public static string SinavMi(string sales);      // "({sales}.DocumentsTypeId = 8 OR ({sales}.DocumentsTypeId = 3 AND kn.DocumentsTypeId = 8))"   ← İnsan onayı 4
}
```

Sözleşme:
- `FisSayisi` + `IadeSayisi` ile yazılan sorguda `GeriDonusumHaricJoin` zorunludur; join yoksa `gd` takma adı çözülmez ve sorgu derleme anında değil **çalışma anında** hata verir. Kanonik testler bunu yakalar.
- `NetKdvHaric` değeri mağaza neti ile aynıdır (`Queries.cs` storeSql). SC-006 koruma testi bunu sınar.
- `MagazaBelgeleri` net kapsamıdır; fiş sayımında kullanılmaz.
- Ölçüm (03.10.2026, tüm zaman): 1001 satırı 15.421 iade, 62 satış fişi (47'si geçersiz satır), 1 fatura, 2 personel belgesinde. Kanonik fiş sayımı 1001 dışlamasından pratikte etkilenmez. İade sayısı etkilenir: FSM Eylül 2026'da 1.518 → 947.

## 2. `EticDurum`

```csharp
public static class EticDurum
{
    /// sema codes: joker.J_ORDERS.STATUS.net_iptal_iade
    public const string SiparisIptalIade = "1001,1006,1007,3000,4000";
    /// sema codes: joker.J_ORDER_DETAILS.STATUS.net_iptal_iade
    public const string SatirIptalIade = "2004,2005,2010";
}
```

Sözleşme (İnsan onayı 2):
- **Ciro ve sipariş sayısı** (Ana sayfa, kategori karması, kategori detayı, yıllık grafik): `o.STATUS NOT IN (SiparisIptalIade)`. Ana e-ticaret cirosunun bugünkü kuralıdır (SC-006).
- **Adet ve talep** (ODAK e-ticaret talep kolonu): `o.STATUS NOT IN (SiparisIptalIade) AND d.STATUS NOT IN (SatirIptalIade)`.
- Kod listesi sema'da değişirse C# sabiti aynı commit'te güncellenir. `sema/degismezler.json: cod-durum-kodlari-duruyor` ilgili kodları korur.
- F0 (c) ölçümü: geçerli başlıklı Eylül 2026 siparişlerinde satır iptal/iade tutarı. Sonuç `H04-etic-kategori.sql` başlığına yazılır.

## 3. `MerkezDepoStok`

Kural (`sql-server-conventions.md` § merkez depo; kullanıcı kararı 03.10.2026): bugün = canlı WMS; geçmiş ay = ay sonu görüntüsü, tarihli.

```csharp
public static class MerkezDepoStok
{
    /// CTE gövdesi. Kolonlar: stkID int, Merkez int.
    public const string CanliCte = """
        SELECT d.stkID, CONVERT(int, SUM(d.Stok)) AS Merkez
        FROM DerinSISBkm.depo.stok_adres_palet_vw d WITH(NOLOCK)
        WHERE d.adrsAlanTipID IN (0, 1)
        GROUP BY d.stkID
        """;

    /// Ay sonu görüntüsü. @Donem zorunlu parametre; MAX(Donem) yedeği YOK (AC-8.4).
    public const string AySonuCte = """
        SELECT b.stkID, CONVERT(int, SUM(b.Stok)) AS Merkez
        FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b WITH(NOLOCK)
        WHERE b.Kaynak = 'WMS' AND b.ehMekan = 12 AND b.Donem = @Donem
        GROUP BY b.stkID
        """;

    /// Görüntü var mı? Yoksa çağıran "Bu ay için stok görüntüsü yok." gösterir.
    public const string AySonuVarMiSql =
        "SELECT CASE WHEN EXISTS (SELECT 1 FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli WITH(NOLOCK) WHERE Kaynak = 'WMS' AND ehMekan = 12 AND Donem = @Donem) THEN 1 ELSE 0 END";
}
```

Sözleşme:
- Bugünkü stoğu gösteren her ekran `CanliCte`'yi kullanır: ODAK, kategori çeşit, ölü stok depo bileşeni, tedarikçi karnesi, satınalma. Satış analizi kesim tabanından okur (İnsan onayı 3).
- `paletUrnTnm` + elle dışlama listesi (`CK01`, `42560`, `20353`) dokunulan sorgulardan kaldırılır (`olctum-mu-cikardim-mi.md` § liste elle yazılmaz).
- `ERP defteri (stokSonAltDepo_vw) mekan 12` merkez depo için kullanılmaz. Mağaza stokları bugünkü kaynağında kalır (AC-3.4).
- Canlı WMS'e bağlanılamazsa `AySonuCte`'ye **geçilmez**; hata yukarı fırlar ve ekran hata mesajını gösterir.

## 4. `DuzeltmeNotlari` ve `DuzeltmeNotu.razor`

```csharp
public static class DuzeltmeNotlari
{
    public const int GorunurGun = 30;
    /// Gösterge anahtarı → yayına alma tarihi. Anahtarlar: bkz. ekranlar.md § değişen göstergeler.
    public static IReadOnlyDictionary<string, DateOnly> YayinTarihleri { get; }
    /// bugun - yayin <= 30 gün ise "Hesap düzeltildi (gg.aa)" döner; değilse null. Anahtar yoksa null.
    public static string? NotMetni(string gostergeAnahtari, DateOnly bugun);
}
```

```razor
@* Components/Shared/DuzeltmeNotu.razor *@
@inject TimeProvider Saat
[Parameter, EditorRequired] public string Anahtar { get; set; }
@* NotMetni null değilse: <span class="badge badge-ghost badge-sm">Hesap düzeltildi (05.10)</span> *@
```

Sözleşme:
- Gün sayımı: `bugun.DayNumber - yayin.DayNumber <= 30` → görünür (AC-0.1); 31 ve sonrası → görünmez (AC-0.2). Bugün `TimeProvider.GetLocalNow()`'dan alınır. `DateTime.Now`/`Today` kullanılmaz.
- Tarih biçimi `dd.MM` (Türkçe, gg.aa).
- Yayın tarihi F6'da (yayına alma commit'inde) yazılır. Anahtar sözlükte yoksa not çıkmaz.

## 5. `HedefTabani`

```csharp
public static class HedefTabani
{
    public const bool Teyitli = false;   // GMY teyidi gelince true (ayrı görev)
    public const string TeyitBekliyorNotu = "Hedef tabanı teyit bekliyor";
}
```

## 6. `GeriAdresi`

```csharp
public static class GeriAdresi
{
    /// geri == null/boş → "/satis-analizi"
    /// geri "/" ile başlıyor ve "//" ile başlamıyor, "\" içermiyor → olduğu gibi (yerel yol; ör. "/sezon-aksiyon")
    /// geri "/" ile başlamıyor → "/satis-analizi?" + geri (satış analizi filtre durumu)
    /// geri mutlak adres ("http:", "//", "\\") → "/satis-analizi" (açık yönlendirme reddi)
    public static string Coz(string? geri);
}
```

Negatif testler: `"//evil.example"`, `"http://evil.example"`, `"/\\evil.example"` → `"/satis-analizi"`.

## 7. `StokGostergeTanimlari`

Her ekranın kullandığı eşik **bu sınıftaki sabitten** okunur; açıklama metni aynı sabitten üretilir (AC-14.2 yapı gereği sağlanır). F0'da her ekranın bugünkü eşikleri koddan okunarak sabitlere aktarılır; değer değiştirilmez (tekilleştirme 003'te).

```csharp
public static class StokGostergeTanimlari
{
    // Örnek (gerçek değerler F0'da koddan okunur):
    public const int EnvanterOluStokGun = 90;          // RefQueries.Envanter OluStokSql
    public static string EnvanterOluStokMetni { get; }  // "Son 90 günde mağazalarda satılmamış, 90 günden eski ve stokta olan ürün. Stok mağazalar ve merkez depo (WMS) toplamıdır."
    // SatisAnalizi, SezonAksiyon, SatinalmaAnaliz için aynı kalıp
}
```

Metinler en fazla iki cümle, en fazla 15 kelimelik cümleler (`sunum-dili.md`).
