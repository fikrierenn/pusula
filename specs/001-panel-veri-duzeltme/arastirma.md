# Araştırma — 001 Panel veri düzeltmeleri

Yalnız bu plan için gerçekten araştırılan ya da ölçülen konular. Ölçümler canlı ERP'de (192.168.40.201), `sqlcli --profile erp`, salt-okuma, 03.10.2026. Etiketler `olctum-mu-cikardim-mi.md` kuralına göredir. Bu sorgular F0'da `sorgular/2026-10-panel-veri-duzeltme/00-taban-olcumu.sql`'e arşivlenir (`semantic-layer.md` § ikiz yükümlülük).

## 1. "Geri dönüşüm fişi" fiilen iade belgesidir (ÖLÇÜLDÜ)

Soru: spec'in "geri dönüşüm (1001) fişi hariç" tanımı fiş sayısını ve iade sayısını nasıl etkiler?

```sql
-- FSM, Eylül 2026, belge tipi × 1001 dışlaması
SELECT s.DocumentsTypeId AS tip, COUNT(*) AS belge,
       SUM(CASE WHEN gd.SalesId IS NULL THEN 1 ELSE 0 END) AS belge_1001_haric
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza mg ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
LEFT JOIN (SELECT DISTINCT SalesId FROM EncoreMerkez.dbo.SalesProducts WITH(NOLOCK) WHERE BarcodeNo = '1001') gd ON gd.SalesId = s.Id
WHERE mg.mekanID = 1 AND s.Date >= @a AND s.Date < @b      -- @a=2026-09-01, @b=2026-10-01
GROUP BY s.DocumentsTypeId;
```

| Tip | Belge | 1001 hariç |
|---|--:|--:|
| 1 satış fişi | 42.774 | 42.774 |
| 2 fatura | 244 | 244 |
| 3 iade | 1.518 | **947** |
| 6 personel fişi | 232 | 232 |
| 7 personel faturası | 8 | 8 |

- Ana sayfanın bugünkü "fiş" değeri 42.311 = (42.774 + 244 + 232 + 8) − 947 ile birebir tutuyor. Denetimdeki 42.311 bu formülden geliyor.
- Kanonik fiş (yalnız tip 1, 1001 hariç) = **42.774**. 1001 dışlaması satış fişini etkilemiyor.
- İade sayısı 1001 dışlamasıyla **947**, dışlamasız 1.518. Spec AC-5.4 1.518 diyor. Bu çelişki İnsan onayı 1'dir.

Tüm zaman, 1001 satırının belge tipine dağılımı:

```sql
SELECT s.DocumentsTypeId AS tip, COUNT(DISTINCT s.Id) AS belge_1001,
       SUM(sp.TotalPrice - sp.VatTotal) AS satir_net_haric,
       SUM(CASE WHEN sp.IsValid = 0 THEN 1 ELSE 0 END) AS gecersiz_satir
FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = sp.SalesId
WHERE sp.BarcodeNo = '1001'
GROUP BY s.DocumentsTypeId;
```

| Tip | Belge | Satır net (KDV hariç) | Geçersiz satır |
|---|--:|--:|--:|
| 3 iade | 15.421 | 2.459.358,26 | 38 |
| 1 satış | 62 | 15.331,52 | 47 |
| 6 personel | 2 | 125,80 | 2 |
| 2 fatura | 1 | 220,00 | 1 |

Sonuç: 1001 satırı neredeyse yalnız iade belgesinde. Satış fişindeki 62 belgenin satırlarının çoğu geçersiz (iptal edilmiş). Mevcut kod 1001 tespitinde `IsValid`'e bakmıyor. Parite (SC-006) için bu korunur; değişmez `geri-donusum-1001-satis-fisinde-gecerli-yok` bu durumu izler.

Başka ne olabilir: 1001 bir "iade" değil, geri dönüşüm alımı (müşteriden ürün alıp indirim vermek) kasada iade belgesiyle kaydediliyor olabilir. Belge tipinin iade olması işin doğasını değiştirmez; kapsam sorusu yine GMY'nindir. Bu yorum **ÇIKARIM**dır.

Ek bulgu (kod okuması): `HediyeCekiQueries.cs:58` geri dönüşümü başka bir tanımla dışlıyor (`RefundReasonId <> 12 AND Code <> '583160'`). İki tanımın eşdeğerliği ölçülmedi; F0 (b).

## 2. Kalem toplamı ile başlık toplamının eşitliği (ÖLÇÜLDÜ)

Eylül 2026, üç mağaza, Encore kalem tabanı (`SalesProducts.IsValid = 1`, `BarcodeNo <> '1001'`, tip 1,2,3,6,7,8, iade −):

| Mağaza | Kalem `TotalPrice − VatTotal` | Kalem `TotalPrice` (KDV dahil) | Belge 8 (KDV hariç) |
|---|--:|--:|--:|
| FSM (1) | 44.666.847 | 47.288.245 | 0 |
| Özlüce (4477) | 57.819.344 | 61.987.788 | 0 |
| İst.Yolu (4478) | 367.452.393 | 373.925.281 | 330.349.209 |

Kalem tabanlı KDV hariç net, Ana sayfanın başlık tabanlı netiyle aynı (FSM 44.666.847,33; `sql-bulgulari.md` spot ölçümü). Perakende/Sınav ayrımı (H13) kalem tabanında ya da başlık tabanında yapılabilir. Toplam değişmez.

## 3. Hedef tabanı (H13) (ÖLÇÜLDÜ, kısmi)

```sql
SELECT h.mekanId, CAST(SUM(h.hedef) AS decimal(18,0)) AS hedef, COUNT(*) AS satir,
       CAST(SUM(CASE WHEN h.ktgId IN (0,255) THEN h.hedef ELSE 0 END) AS decimal(18,0)) AS sentinel_hedef
FROM BKMDATA.dbo.Hedef h WITH(NOLOCK)
WHERE h.tarih >= @a AND h.tarih < @b
GROUP BY h.mekanId;

SELECT TOP 12 h.mekanId, h.ktgId, CAST(k.ktgrAd AS nvarchar(40)) AS ktg, CAST(SUM(h.hedef) AS decimal(18,0)) AS hedef
FROM BKMDATA.dbo.Hedef h WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = h.ktgId
WHERE h.tarih >= @a AND h.tarih < @b AND h.mekanId = 4478
GROUP BY h.mekanId, h.ktgId, CAST(k.ktgrAd AS nvarchar(40))
ORDER BY SUM(h.hedef) DESC;
```

| Mekân | Eylül 2026 hedef (TL) | Gerçekleşen KDV hariç | Oran | Gerçekleşen KDV dahil | Oran |
|---|--:|--:|--:|--:|--:|
| FSM | 62.468.688 | 44.666.847 | 1,40 | 47.288.245 | 1,32 |
| Özlüce | 72.326.638 | 57.819.344 | 1,25 | 61.987.788 | 1,17 |
| İst.Yolu | 396.112.330 | 367.452.393 | 1,08 | 373.925.281 | 1,06 |
| Merkez depo (12) | 179.322.679 | — | — | — | — |

İst.Yolu hedefinin kategori dağılımı (ilk 4): Sınav Okulları (ktgId 19) 295.318.919 · Kırtasiye 39.908.955 · Hazırlık Kitapları 29.792.425 · Sınav Kıyafet 11.192.086.

Sonuçlar:
- Hedef ürün kategorisi (urnKtgr2) düzeyindedir ve Sınav kategorisini içerir (ÖLÇÜLDÜ). Gerçekleşen tarafı ürün bazlı kurulmalıdır (`sql-server-conventions.md` § kanal ayracı).
- Ölçülen üç mağazada Eylül'de sentinel (`ktgId 0/255`) hedef yok. Listede 129999, 439108 … gibi mekân dışı kimlikler var; tamamı sentinel. Ana sayfa yalnız 1/4477/4478'i okuduğu için etkilemez.
- Tek ay KDV tabanını ayırmıyor. Hedef bir hedeftir, gerçekleşen değildir; oranın 1'den uzak olması taban hatası kanıtı sayılmaz. F0'da kategori × KDV oranı yöntemi uygulanır (plan K-C).

## 4. .NET 10'da `WebApplicationFactory` ve `Program` sınıfı (KAYNAK)

Soru: hata ekranı testi için `public partial class Program { }` eklemek gerekir mi?

.NET 10'da üst düzey ifadelerle yazılmış uygulamalarda `Program` sınıfını bir kaynak üretici `public` yapıyor. `WebApplicationFactory<Program>` için ek bildirim ya da `InternalsVisibleTo` gerekmez; gereksiz bildirim için ASP0027 çözümleyicisi var. Plan bu nedenle `Program.cs`'e dokunmaz.

Kaynaklar: [Safia Abdalla, ".NET 10 ships"](https://blog.safia.rocks/2025/11/10/aspnetcore-ten/) · [Steven Giesel, "No more public partial class Program in .NET 10"](https://steven-giesel.com/blogPost/9c156006-3e54-45b9-8e0c-ea933e005983) · [dotnet/aspnetcore PR 58199](https://github.com/dotnet/aspnetcore/pull/58199)

## 5. `TimeProvider` DI kaydı (KAYNAK)

Soru: `DuzeltmeNotu` ve win-back için `TimeProvider` enjekte edilebilir mi, kayıt gerekir mi?

ASP.NET Core `TimeProvider`'ı varsayılan olarak kaydetmiyor. `builder.Services.AddSingleton(TimeProvider.System)` gerekir. Testte `TimeProvider`'dan türeyen küçük bir sınıf (`GetUtcNow` override) yeter; `Microsoft.Extensions.TimeProvider.Testing` paketi gerekmez.

Kaynaklar: [Microsoft Learn, "What is the TimeProvider class"](https://learn.microsoft.com/en-us/dotnet/standard/datetime/timeprovider-overview) · [NimblePros, ".NET 8 Finally Gives Us A Time Abstraction"](https://blog.nimblepros.com/blogs/finally-an-abstraction-for-time-in-net/)

## 6. Kod okumasıyla doğrulanan noktalar (ÖLÇÜLDÜ: dosya ve satır)

- `BKM_ENV_DOSYA` ortam değişkeni `.env` yolunu değiştirir (`lib/Bkm.Shared/Data/Db.cs:208-212`). Hata ekranı testi sırsız geçici `.env` ile çalışabilir.
- Development ortamında yetkilendirme anonim (`dashboard/Program.cs:32-37`). Hata testi oturum açmadan sayfa HTML'ini alabilir.
- `IcKartFiltre` (`Data/IcKartService.cs:11-30`) tek kaynak SQL parçası emsalidir, `SqlCols` biçimi aggregate içi kullanım içindir.
- `GunKarsilastirQueries.cs:80-100` perakende/Sınav ayrımını iadeyi bağlı belgenin kanalına yazarak yapıyor; H13 için emsal.
- `SatisAnaliziUrun.razor:1071` `Geri()` her zaman `/satis-analizi?{geri}` kuruyor; `SezonAksiyon.razor:629` `geri=/sezon-aksiyon` veriyor, sonuç geçersiz adres (H11).
