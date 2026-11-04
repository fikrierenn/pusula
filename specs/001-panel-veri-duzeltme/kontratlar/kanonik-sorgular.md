# Kanonik sorgular ve testler — izlenebilirlik tablosu

Klasör: `sorgular/2026-10-panel-veri-duzeltme/`. Her dosya:

```sql
-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : <tek cümle>
   AC       : AC-x.y
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026)
   Tolerans : birebir | ≤ 1,00 TL
   Önce     : <panel değeri, gg.aa.yyyy ölçümü>
   Sonra    : <panel değeri, düzeltme sonrası>
   Bağımsız : <bu sorgunun değeri>
   SSMS     : DECLARE @Bas date = CONVERT(date, '01.09.2026', 104), @Bit date = CONVERT(date, '01.10.2026', 104);
*/
SELECT …   -- parametreli tek ifade; panel kodundan BAĞIMSIZ yazılır (Data/Tanimlar kullanılmaz)
```

Bağımsızlık kuralı: kanonik sorgu proje kural setinden (`sql-server-conventions.md`, `sema/`) yazılır, panel sorgusundan kopyalanmaz. Aynı ifadeye çıkması serbesttir; kopyalanması değildir. Mümkünse **farklı yoldan** ölçülür (ör. merkez depo canlı WMS'te, fiş sayısı belge tablosundan; ciro `irsHrk` ile Encore'dan).

Test sınıfı adları `tests/GmDashboard.Tests/Kanonik/<Hikaye>Tests.cs`. Test adı biçimi `Metot_Senaryo_Beklenen`.

| AC | Kanonik dosya | Parametre | Panel tarafı | İlişki | Test |
|---|---|---|---|---|---|
| AC-1.1 | `H01-kumbara-manuel.sql` blok A | `@Bas, @Bit` | `GetKumbaraAsync()` → `Ay = '2026-09'` satırları | Σ Brut = Σ fiş başına tekil `GrossTotal` (iade −), ≤ 1 TL | `GetKumbaraAsync_Eylul2026_BrutFisBasinaTekilKanonigeEsit` |
| AC-1.2 | aynı, blok B | aynı | `GetKumbaraAsync`, `GetManuelIndirimAsync` | Σ Indirim = Σ fiş başına `DiscountTotal`, ≤ 1 TL (her biri) | `GetManuelIndirimAsync_Eylul2026_IndirimKanonigeEsit` |
| AC-1.3 | aynı, blok C | aynı | aynı | İadeli kampanya varsa iade düşülmüş; nüfus = dönemdeki iadeli Kumbara/manuel fiş (0 ise KOŞAMADI) | `GetManuelIndirimAsync_IadeliKampanya_IadeDusulur` |
| AC-2.1 | `H02-winback.sql` blok A | `@Bugun` | `GetWinBackAsync(bugun)` | `MusteriId` ∩ son 90 gün satış fişi müşterileri = ∅ | `GetWinBackAsync_Bugun_Son90GunAlisverisYapanYok` |
| AC-2.2 | blok B | `@Bugun` | aynı | Her satır `GunIdle` = tüm zaman son satış fişinden gün, > 90 | `GetWinBackAsync_Bugun_GunIdleSonSatisFisindenVe90Ustu` |
| AC-2.3 | blok C | `@Bugun` | aynı | `Frq` = yalnız satış fişi sayısı | `GetWinBackAsync_IadeliMusteri_FrekansIadeSaymaz` |
| AC-2.4 | blok D | `@Bugun` | aynı | Liste `MusteriId` kümesi = kanonik TOP 200 (aynı sıralama) kümesi | `GetWinBackAsync_Bugun_KanonikListeyleAyniKume` |
| AC-3.1 | `H03-tedarikci-depo.sql` blok A | — (canlı) | `GetTedarikciPerformansAsync` | Her `MrkId` için `DepoStokAdet` = canlı WMS (alan 0+1) toplamı | `GetTedarikciPerformansAsync_HerMarka_DepoCanliWmsEsit` |
| AC-3.2 | blok B | — | aynı | Σ `DepoStokAdet` (dönen markalar) = aynı markaların bağımsız WMS toplamı | `GetTedarikciPerformansAsync_Toplam_WmsToplaminaEsit` |
| AC-3.3 | blok C | — | karne + `GetKategoriCesitAsync` | Aynı ürün için iki ekranın depo değeri aynı kaynaktan (ürün düzeyi örneklem: depo > 0 olan 20 ürün) | `MerkezDepo_KarneVeKategoriCesit_AyniKaynak` |
| AC-3.4 | blok D | — | aynı | `MagazaStokAdet` = düzeltme öncesi mağaza bileşeni formülü | `GetTedarikciPerformansAsync_MagazaStok_Degismez` |
| AC-4.1, 4.2 | `H04-etic-kategori.sql` | `@BasIso, @BitIso` (JOKER doğrudan) | `GetEticKategoriAsync` | Σ kategori + bilinmeyen = ana net (121.955.096,47 TL, ≤ 1 TL); sipariş sayısı: ana sipariş kümesi birebir (113.731) | `GetEticKategoriAsync_Eylul2026_AnaCiroyaEsit` |
| AC-4.3 | `H04-odak-talep.sql` | ISO tarih | `OdakQueries` `ecom` | Ürün başına adet = başlık + satır iptal/iade hariç bağımsız adet | `OdakEticTalep_Eylul2026_IptalIadeHaricAdeteEsit` |
| AC-5.1 | `H05-fis.sql` blok A | `@Bas, @Bit`, mekân 1 | `Queries.GetPeriodAsync` FSM `Fis`, `TrafikQueries.GetKpiAsync.Fis`, Σ ısı haritası günlük fiş, Σ personel `Fis` | Dördü eşit ve = belge tablosundan bağımsız sayım | `FisSayisi_FsmEylul2026_DortGostergeKanonigeEsit` |
| AC-5.2 | — | aynı | `TrafikKpi` | Dönüşüm ve sepet paydası `Fis` | `TrafikKpi_Donusum_KanonikFisKullanir` |
| AC-5.3 | `H05-fis.sql` blok B | son 12 ay (`@Bugun`) | `GetKartliAsync` | Σ `FisSayisi` = satış fişi sayısı; ciro (1,3) değişmez | `GetKartliAsync_FisSayisiIadeIcermez` |
| AC-5.4 | blok C | `@Bas, @Bit`, mekân 1 | `StoreRow.IadeSayisi`, `TrafikKpi.IadeSayisi`, `MagazaDetay.IadeSayisi` | Üçü eşit, bağımsız iade sayımına eşit (KR-1 onaylandı: 947) | `IadeSayisi_FsmEylul2026_KanonigeEsit` |
| AC-6.1 | `H06-magaza.sql` blok A | `@Bas, @Bit`, her mağaza | `GetDetayAsync.Kampanya` | İptal kaleme bağlı kampanya indirimi toplamda yok | `GetDetayAsync_IptalKalem_KampanyaIndirimineGirmez` |
| AC-6.2 | blok B | aynı | aynı | `Brut − Indirim` = Σ geçerli kampanyalı kalem `TotalPrice` (KDV dahil), ≤ 1 TL | `GetDetayAsync_Kampanya_BrutEksiIndirimNeteEsit` |
| AC-6.3 | blok C | aynı | `StoreCard.Iade` ↔ `MagazaDetay.Iade` | Eşit, ≤ 1 TL; KDV hariç indirim düşülmüş | `Iade_AnaSayfaVeMagazaDetay_AyniTaban` |
| AC-6.4 | blok D | İst.Yolu | `MagazaDetay.Upt`, `GetHeatmapAsync` | Kalem ve fiş yalnız kanonik fişten | `GetDetayAsync_IstYoluUpt_KanonikFisTabaninda` |
| AC-7.1, 7.2 | `H07-marj-abc.sql` blok A (`irsHrk`) | `@Bas, @Bit` | `GetMarjKategoriAsync` | Σ `Ciro` = kanonik şube cirosu (100−101+4−5, üç mağaza), ≤ 1 TL | `GetMarjKategoriAsync_Eylul2026_KanonikSubeCirosunaEsit` |
| AC-7.3 | blok B | `@Bas, @Bit` | ABC (`GetInventoryAsync`) | Σ sınıf cirosu = pozitif net ürün cirolarının bağımsız toplamı, ≤ 1 TL | `Abc_Eylul2026_IadeDusulmusCiroyaEsit` |
| AC-8.1, 8.2 | `H08-merkez-depo.sql` blok A | — | ODAK, kategori çeşit, ölü stok, satınalma depo değerleri | Aynı dakika içinde canlı WMS'e birebir; iki ekran arası eşit | `MerkezDepo_BugunEkranlar_CanliWmsEsit` |
| AC-8.3 | blok B | `@Donem` | geçmiş ay bakiyesi döndüren metot | Değer = o `Donem` görüntüsü; `GoruntuTarihi = @Donem` | `AySonuBakiye_Donem_GoruntuyeVeTarihineEsit` |
| AC-8.4 | — | olmayan `@Donem` | aynı | Sonuç boş, `GoruntuTarihi = null`; başka ay değeri yok | `AySonuBakiye_GoruntuYok_BaskaAyDonmez` |
| AC-9.1, 9.2 | `H09-sinav-odeme.sql` | `@DonemId` (Eylül 2026'yı kapsayan dönem) | `GetOdemeDurumAsync` ↔ `GetSezonKpiAsync` | Σ kart net = KPI net, ≤ 1 TL; fatura bir kez | `GetOdemeDurumAsync_Donem_KpiNetineEsit` |
| AC-10.1, 10.2 | — | erişilemez sunucu `.env` | Sabah, Envanter, Operasyon, Satınalma analiz, Eşikler, Vardiya HTML'i | HTML'de sunucu adı, `SqlException`, `Exception` metni yok; `VeriAlinamadi` var; günlükte ekran adı | `Ekran_VeriKaynagiYok_GenelMesajGosterirVeGunlugeYazar` (teori, 6 sayfa) |
| AC-10.3 | `H10-urun-kodu.sql` | — | dönüşüm ifadesi | Sayısal olmayan ve 10+ haneli kod için ifade `NULL` döner, hata vermez (sabit değerli `VALUES` tablosuyla) | `UrunKoduDonusumu_SayisalOlmayan_NullDoner` |
| AC-11.1, 11.2 | — | — | `GeriAdresi.Coz` | `/sezon-aksiyon` → aynı; `kesim=…` → `/satis-analizi?kesim=…`; dış adres reddi | `GeriAdresi_*` (birim) |
| AC-12.1–12.3 | `H12-mizan.sql` | `@SirketId, @Yil, @Ay` (kapanmış son ay) | `GetSonucAsync().Ozet` | Nakit = Σ(100,102,108); AlinanCek = 101; KDV = 391 − 191 − 190; ≤ 1 TL | `MizanOzet_KapanmisAy_HesapKumelerineEsit` + `OzetHesapla_*` (birim) |
| AC-13.1 | — | `@Bas, @Bit` | `StoreRow` | `NetPerakende + NetSinav = Net`, ≤ 1 TL | `GetPeriodAsync_Eylul2026_PerakendeArtiSinavToplamaEsit` |
| AC-13.2 | `H13-sinav-net.sql` | aynı | `StoreRow.NetSinav` | Bağımsız Sınav belgesi neti (iade, bağlı belge kanalıyla), ≤ 1 TL | `GetPeriodAsync_Eylul2026_SinavNetiKanonigeEsit` |
| AC-13.3 | `H13-sube-cirosu.sql` (`irsHrk`) | aynı | Σ `Net` (3 mağaza) | Kanonik şube cirosuna `|fark| ≤ %0,30` | `GetPeriodAsync_Eylul2026_ToplamKanonikSubeCirosunaYakin` |
| AC-13.4, 13.5 | — | `HedefTabani.Teyitli` | not mantığı | `false` → not var; `true` → not yok | `HedefNotu_*` (birim) |
| AC-14.1, 14.2 | — | — | `StokGostergeTanimlari` | Metin, SQL'e geçen sabitin değerini içerir; dört ekranda bileşen metni sabitten | `StokTanimMetni_*` (birim) |
| AC-0.1, 0.2 | — | sahte `TimeProvider` | `DuzeltmeNotlari.NotMetni` | 30. gün görünür, 31. gün görünmez, biçim `dd.MM` | `DuzeltmeNotu_*` (birim) |
| D-2 | `D2-kasiyer.sql` | `@Bas, @Bit` | `PeriodSummary.Kasiyer`, `Stores` | Σ kasiyer net = Σ mağaza net, ≤ 1 TL | `Kasiyer_Eylul2026_MagazaNetineEsit` |
| D-4 | `D4-hediye-ceki.sql` | `@Bas, @Bit` | `GetBaremKalemAsync` | Her satırda `Brut − Indirim = NetKdvDahil`, ≤ 1 TL | `GetBaremKalemAsync_Satir_BrutEksiIndirimNeteEsit` |
| SC-006 | `tests/GmDashboard.Tests/Koruma/Eski/*.sql` (dondurulmuş eski formül) | `@Bas, @Bit` | `GetPeriodAsync` 3 mağaza `Net`, e-tic `Sip`/`Ciro` | **Eski formül ↔ yeni formül** aynı anda koşulur: mağaza `Net` farkı ≤ 1 TL, e-tic `Sip` birebir, `Ciro` ≤ 1 TL. Sabit rakam yok; geç gelen iade/iptal iki tarafı birlikte etkiler (risk R2) | `Koruma_Eylul2026_EskiVeYeniFormulEsit` |

D-1, D-3, D-5 ve H14 metin değişiklikleridir; testleri birim düzeyindedir ya da ekran incelemesiyle kapanır (`kanit` dosyasında "ekran incelemesi" notu).

## Ortak test yardımcıları (`tests/GmDashboard.Tests/Altyapi/`)

- `CanliDb`: `Db`'yi `.env`'den kurar (`NullLogger<Db>`). Bağlantı açılamazsa `KOŞAMADI: …` mesajıyla `Assert.Fail`.
  - **Salt-okuma kapısı (risk R1):** her ifade çalıştırılmadan önce izin listesinden geçer (yalnız `SELECT` ve `WITH … SELECT`; dize ve yorum ayıklanarak taranır; tanınmayan reddedilir). Her ifade her zaman `ROLLBACK` edilen transaction içinde koşar. Yardımcıda `ExecuteAsync` yoktur. Kırılabilirlik `UPDATE` içeren sahte dosyayla kanıtlanır.
  - Bağlantı açılışında `SET LOCK_TIMEOUT 5000; SET DEADLOCK_PRIORITY LOW;` (risk R4).
- `HataEkraniKoleksiyonu`: `DisableParallelization = true`; `Db` `ConfigureTestServices` ile sahte sunucuya bağlanan örnekle değiştirilir; ilk adım `DataSource`'un sahte sunucu olduğunu doğrular (risk R5).
- `KanonikSorgu.Oku("H01-kumbara-manuel.sql", "A")`: dosyadaki `-- blok: A` işaretli ifadeyi döner.
- `Tolerans.Tutar = 1.00m`; `Tolerans.Oran = 0.003m` (AC-13.3).
- `Nufus.EnAz(int n, string neden)`: kanonik sonuç boşsa `KOŞAMADI`.
- `SahteSaat : TimeProvider` (`GetUtcNow` override; ek paket yok).
- Kişisel veri (müşteri adı, telefon) assert mesajına yazılmaz; yalnız kesişim ve fark **sayısı** yazılır (Madde 8).
