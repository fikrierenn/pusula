# Veri modeli — 001 Panel veri düzeltmeleri

**Özet:** Yeni ya da değişen tablo, kolon, view, fonksiyon, SP, tip, indeks veya SQL Agent job **yoktur**. Migration yoktur. **Veri kaybı: yok.** Spec FR-015 ve `erp-write-policy.md` gereği ERP, POS ve e-ticaret veritabanlarına yazılmaz. Bu spec kapsamında app-owned `bkm.*` tablolarına da yazılmaz.

## 1. Okunan kaynaklar (değişmez, salt-okuma)

| Nesne | Veritabanı (compat) | Bu spec'te kullanımı | sema |
|---|---|---|---|
| `EncoreMerkez.dbo.Sales` | EncoreMerkez (110) | Fiş/iade sayımı, mağaza neti, kanal ayracı (`LinkedDocumentId > 0`) | `entities` |
| `EncoreMerkez.dbo.SalesProducts` | EncoreMerkez (110) | `IsValid = 1`, 1001 barkodu, kalem tutarı | `entities`, `codes` |
| `EncoreMerkez.dbo.SalesProductCampaigns` | EncoreMerkez (110) | Kampanya yükü (H6), Kumbara/manuel köprüsü (H1) | `bridges:salescampaign-sales` |
| `EncoreMerkez.dbo.RefundReasons` | EncoreMerkez (110) | Kumbara (Id 17) ve manuel indirim sebepleri (`Type = 1`) | — |
| `EncoreMerkez.dbo.Pos` / `Stores` / `Products` | EncoreMerkez (110) | Mağaza köprüsü, `Products.Code` = `urn.stkID` | `sql-server-conventions.md` § köprü |
| `DerinSISBkm.dbo.posMagaza` | DerinSISBkm (150) | Mağaza kümesi | `codes:mekanID` |
| `DerinSISBkm.dbo.irsHrk`, `irs`, `irsAyr`, `urn`, `urnKtgr2`, `urnMrk`, `stokSonAltDepo_vw` | DerinSISBkm (150) | Kanonik şube cirosu (100 − 101 + 4 − 5), marj, tedarikçi karnesi mağaza stoğu | `metrics:MEKAN_CIRO_MUTABAKAT_FORMULU` |
| `DerinSISBkm.depo.stok_adres_palet_vw` | DerinSISBkm (150) | Canlı merkez depo stoğu, `adrsAlanTipID IN (0,1)` | `entities`, değişmez `wms-hucresel-stok-kaynagi-ayakta` |
| `DerinSISBkm.bkm.StokAyBakiyeMekanBazli` | DerinSISBkm (150) | Yalnız **geçmiş ay** merkez depo bakiyesi (`Kaynak='WMS'`, `ehMekan=12`, açık `@Donem`) | `entities` |
| `DerinSISBkm.mhs.*` (mizan) | DerinSISBkm (150) | Nakit, alınan çek, KDV pozisyonu (H12) | `metrics` mizan |
| `BKM.snv.SinavSiparisFisEncore`, `snv.Siparis`, `snv.SiparisDetay` | BKM (150) | Sınav ödeme sağlık kartı (H9) | `entities:BKM.snv.*` |
| `BKMDATA.dbo.Hedef` | BKMDATA (150) | Hedef tabanı ölçümü (H13) | `entities`, `bridges:hedef-kategori` |
| `DerinCrm.dbo.Customer` | DerinCrm (150) | Win-back, kartlı/kartsız | `sql-server-conventions.md` § müşteri |
| `JOKER.dbo.J_ORDERS`, `J_ORDER_DETAILS`, `J_ITEMS` | JOKER (150) doğrudan; ODAK sayfasında `ODAKJOKER` OPENQUERY | Kategori karması (H4), ODAK talebi (H4) | `codes:joker.J_ORDERS.STATUS`, `joker.J_ORDER_DETAILS.STATUS` |

Standart kolonlar (`IsValid`, `OlusturmaTarihi` …): yeni tablo olmadığı için uygulanmaz. Kaynak tablolardaki soft-delete karşılığı yalnız `SalesProducts.IsValid`'dir (`desenler.md` § RUN-007).

## 2. "Hesap düzeltildi (gg.aa)" notunun kalıcılığı

**Karar: kod sabiti.** `dashboard/Data/Tanimlar/DuzeltmeNotlari.cs` içinde gösterge anahtarı → yayın tarihi (`DateOnly`) sözlüğü.

| Seçenek | Değerlendirme |
|---|---|
| **Kod sabiti** (seçildi) | Tarih yayın commit'inde yazılır, git geçmişiyle izlenir. 30 gün sonra not kendiliğinden kaybolur (`TimeProvider` ile hesap). Veri tabanı, DDL ve yetki gerekmez. Birim testiyle sınanır |
| Panel tablosu `dbo.PanelDuzeltmeNotu` (BkmPanel) | Yeni tablo + DDL + yazma yolu ister; spec "yeni tablo yok" diyor. BkmPanel bu makineden erişilemiyor (K4). Ekrandan düzenleme ihtiyacı yok (spec § Yetki: "düzeltme tanımlarını ekrandan değiştirmek" yapılamaz) |
| ERP `bkm.*` tablosu | `erp-write-policy.md` gereği yasak |

Sözleşme: `kontratlar/ortak-tanimlar.md` § DuzeltmeNotlari. Önce/sonra değerleri ekranda tutulmaz; kanıt arşivinde ve journal'da durur (AC-0.2).

## 3. Hedef tabanı teyidi

**Karar: kod sabiti** `HedefTabani.Teyitli` (`bool`, 001'de `false`). Teyit gelince sabit `true` yapılır ve hedef karşılaştırmasının gerçekleşen tarafı teyit edilen tabana alınır (AC-13.5). Bu ayrı bir görev olur. Tablo yok.

## 4. Değişen uygulama modelleri (veritabanı değil)

Dapper konumsal kayıtlarında sıra sözleşmedir (`sql-server-conventions.md` § pozisyonel record). Yeni alanlar SQL `SELECT` listesinde ve kayıtta **aynı konuma, sona** eklenir. `python tools/panel_kolon_denetimi.py` her commit'te koşar.

| Kayıt | Değişiklik | Neden |
|---|---|---|
| `StoreRow` | `+ decimal NetPerakende, decimal NetSinav, int IadeSayisi` (sona) | H13, AC-5.4 |
| `StoreCard` | `+ decimal NetPerakende, decimal NetSinav, int IadeSayisi` | H13, AC-5.4 |
| `TrafikKpi` | `+ int IadeSayisi` | AC-5.4 |
| `KartliRow` | değişmez (alanların anlamı kanonikleşir) | AC-5.3 |
| `WinBackRow` | `+ long MusteriId` (sona) | AC-2.1, 2.4 küme karşılaştırması (ekranda gösterilmez) |
| `TedarikciPerfRow` | `+ int MrkId, int MagazaStokAdet, int DepoStokAdet` (sona); `StokAdet = MagazaStokAdet + DepoStokAdet` | AC-3.1, 3.2, 3.4 |
| `MarjRow` | `+ decimal CiroMaliyetli` (sona); `MarjPct` maliyeti bilinen ciroya göre | AC-7.1, 7.2 |
| `MagazaDetay` | anlam: `Iade` KDV hariç indirim düşülmüş; `IadeOran` aynı tabandan; `Fis` kanonik; `+ int IadeSayisi` (sona) | H6, AC-5.4 |
| `KumbaraAyRow` / `ManuelIndirimRow` | kolonlar aynı; değerler fiş başına tekil, iade sign'lı | H1 |
| `MizanOzet` | `Nakit` 101'siz; `+ decimal AlinanCek, decimal KdvDevreden` (sona); `KdvNet = KdvHesaplanan − KdvIndirilecek − KdvDevreden` | H12 |
| `OdakUrun` ve ODAK KPI kayıtları | `Mrkz` anlamı: canlı WMS; değer değişir, alan aynı | H8 |

Model değişiklikleri veri tabanına yazılmaz; geri alma `git revert` ile yapılır.

## 5. Migration ve geri alma

- Migration yok, geri alma betiği gerekmez.
- Geri alma: ilgili commit'lerin `git revert`'i. Eski rakam döner; ERP'de iz kalmaz.
- `sema/*.yaml` ve `sema/degismezler.json` değişiklikleri metin dosyasıdır; aynı yolla geri alınır.
