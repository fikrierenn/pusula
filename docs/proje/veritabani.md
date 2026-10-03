# Veritabanı haritası — dashboard'ın dokunduğu veriler

> Tür: proje tanıtımı (veritabanı, başvuru) · Kaynak commit: `d5cf345` · İzlenen yollar: `dashboard/Data/**`, `lib/Bkm.Shared/Data/Db.cs`, `sqlcli.json`, `sema/*.yaml`, `.claude/rules/erp-write-policy.md`, `.claude/rules/sql-server-conventions.md` · Son doğrulama: 03.10.2026 (/tanit; compat/collation/şema sayıları `sqlcli --read-only` ile bu oturumda ölçüldü, veri satırı çekilmedi)

## Semantik katman durumu

- **Kök: yerel sema** — pusula'nın kendi `sema/` dizini kanonik (`bridges.yaml` 78 köprü, `codes.yaml`, `entities.yaml`, `metrics.yaml`, `queries.yaml` 15 sorgu, `degismezler.json`). `config/orkestra.json` **yok**.
- `./ork sema denetle` → **KOŞAMADI** ("`sema` aracı bulunamadı" — `sema` CLI bu makinede kurulu değil). `ork sema temellendir` de aynı sebeple koşulamadı.
- Yedek ölçüm: `python tools/sema_denetim.py` → 545 kayıt · **KIRIK 0** · UYARI 606 (bilinmeyen_alan 197, confidence_yok 143, zorunlu_alan 141, gecersiz_deger 13, db_nesnesi_pk_ister 5 …).
- Bu doküman sema içeriğini kopyalamaz; nesne başına **işaretçi** verir (`bridges:<id>`, `entities:<ad>`, `codes:<ad>`).

## Sunucular ve veritabanları (ölçüldü)

Komut: `SELECT name, compatibility_level, collation_name FROM sys.databases` (her sunucuda).

| Sunucu (bağlantı) | DB | Compat | Collation | Dashboard erişimi |
|---|---|---|---|---|
| 192.168.40.201 (`@@SERVERNAME`=RDSTEST, SQL 15.0.2110.4; `Db.OpenAsync`, katalog `master`) | **DerinSISBkm** | 150 | Turkish_CI_AS | ana ERP — okuma; yazma yalnız `bkm.Fin_AyKapanis`, `bkm.SatisAnaliziTaban` |
| ″ | **EncoreMerkez** | **110** | Turkish_CI_AS | POS — okuma |
| ″ | EncoreMerkezCrm / EncoreMerkezLog | 110 | Turkish_CI_AS | kullanılmıyor |
| ″ | **BKM** (`snv` şeması — Sınav Okulları) | 150 | Turkish_CI_AS | okuma |
| ″ | **BKMDATA** (`Hedef`, `OdakUrunDurum`, `ODAK_FATURA`) | 150 | Turkish_CI_AS | okuma |
| ″ | **DerinCrm** (`Customer`) | 150 | Turkish_CI_AS | okuma |
| ″ | INTER_BOS (eski kasa) | 150 | Turkish_CI_AS | dashboard'da kullanılmıyor (grep 0) |
| ″ | PUAN | 100 | Turkish_CI_AS | kullanılmıyor |
| 192.168.40.70 (`Db.OpenJokerAsync`, `tools/sq.sh --joker`) | **JOKER** | 150 | Turkish_CI_AS | e-ticaret — okuma |
| 192.168.40.25\ZRVSQL2008 (SQL 12.0.6179.1; `Db.OpenZirveAsync`) | **BKM_GENEL** | **100** | Turkish_CI_AS | İK/bordro — okuma (3 çağrı, `Data/KadroQueries.cs:111,137,149`) |
| `PANEL_DB_HOST` (kurala göre BT-FIKRI\SQLEXPRESS) | **BkmPanel** | **ölçülemedi** | ölçülemedi | app-local durum, yazma serbest (`dbo.Panel*`) |

Panel notu: `sqlcli --profile panel` bu makineden **error 26** veriyor (sunucu/örnek bulunamadı). Bu makinenin (SANAL-FIKRI) varsayılan örneğinde de bir `BkmPanel` var (compat 160, Turkish_CI_AS) ama yalnız bkm-magaza tablolarını taşıyor (`PanelStore*`, `PanelPurchase*`, `zz_old_*`; 12 tablo) — dashboard'ın kullandığı `PanelKullanici/PanelGorev/…` orada **yok**. Yani dashboard'ın panel DB'si bu oturumda ölçülemedi.

### Linked server'lar (192.168.40.201, ölçüldü `sys.servers`)

`ODAKJOKER` → 192.168.40.70 · `JOKER` → 192.168.40.50 · `ZIRVE` → 192.168.40.25\ZRVSQL2008 · `PDKS` → 192.168.40.66\sqlexpress · `INTER` → 192.168.40.201 · `LOOPBACK` → DERIN-DB.bkm.local · `LOGO`, `KITAPSEPETI`, `SURA`, `ERP12`, `SAP_1`, `TESTENCORE`, `192.168.40.140`.
Dashboard'da linked server kullanımı: `ODAKJOKER.JOKER.dbo.J_ORDERS` 2 yer (`OdakQueries`, OPENQUERY); geri kalan JOKER erişimi doğrudan bağlantıyla (`bridges:joker-direct-conn`).

## Şemalar (DerinSISBkm, ölçüldü — tablo/view/SP/fonksiyon sayısı)

`dbo` 411/200/357/160 · `bkm` 116/64/118/22 (app-owned) · `depo` (WMS) 96/21/84/24 · `mhs` (muhasebe) 17/15/50/10 · `ent` (entegrasyon) 20/39/41/3 · `iky` 24/7/145/0 · `kmpy` 10/7/23/0 · `web` 26/0/20/0 · `sil` **17 tablo** (silinen belge arşivi, aşağıya bak) · diğer küçük şemalar (b2b, b2c, eftr, earsv, ryn, prj …).
EncoreMerkez: `dbo` 163 · `tmp` 58 · `crm` 22 · `job` 11 nesne (U+V+P).
**`src.*` şeması/view'ı YOK** (iki DB'de de) — Orkestra RUN-006'nın varsaydığı katman bu projede bulunmuyor.

## Dashboard'ın kullandığı ana nesneler ve sema işaretçileri

Sayılar `dashboard/Data` + `Components` içindeki 3-parçalı ad geçişleridir (ölçüldü, grep).

| Nesne | Geçiş | Rol | Sema |
|---|---|---|---|
| EncoreMerkez.dbo.Sales | 81 | fiş başlığı | `entities:EncoreMerkez.dbo.Sales`, `codes:encore.Sales.DocumentsTypeId`, `bridges:sales-customer-name`, `bridges:sales-iade-linked`, `bridges:sales-users-kasiyer` |
| EncoreMerkez.dbo.SalesProducts | 31 | fiş kalemi | `entities:EncoreMerkez.dbo.SalesProducts` (filter `IsValid=1`), `bridges:salesproducts-products`, `codes:encore.SalesProducts.BarcodeNo_1001` |
| EncoreMerkez.dbo.Pos / Stores | 27 / 31 | kasa → mağaza | `bridges:stores-posmagaza` |
| EncoreMerkez.dbo.Products | 12 | POS ürün | `bridges:products-code-stkid` |
| EncoreMerkez.dbo.SalesProductCampaigns | 7 | kampanya/indirim | `bridges:salescampaign-sales`, `bridges:encore-kampanya-kalem`, `codes:encore.SalesProductCampaigns.Source` |
| EncoreMerkez.dbo.SalesPayments / PaymentTypes | 6 / 2 | ödeme | `codes:encore_odeme_grup` |
| DerinSISBkm.dbo.irsHrk | 61 | stok/satış hareket defteri | `entities:dbo.irsHrk`, `codes:irsHrk.ehTip`, `bridges:irshrk-stk`, `bridges:irshrk-mekan`, `bridges:irshrk-pos-encore` |
| DerinSISBkm.dbo.urn / urnKtgr2 / urnMrk / urnBrkd / urnKDV | 44 / 31 / 8 / 2 / 2 | ürün master | `entities:dbo.urn`, `codes:urn.urnTip`, `bridges:urnbrkd-barkod`, `bridges:urn-kdv-oran` |
| DerinSISBkm.dbo.posMagaza / frm | 25 / 17 | mekan / taraf master | `codes:mekanID`, `codes:posMagaza.mekanTip`, `codes:frm.frmTip`, `entities:dbo.frm` |
| DerinSISBkm.dbo.fat / fatAyr / irs / irsAyr | 20 / 18 / 6 / 3 | fatura / irsaliye | `entities:dbo.fat`, `codes:fat.eTip`, `bridges:fat-fatayr`, `bridges:fat-firma`, `bridges:irs-irsayr` |
| DerinSISBkm.bkm.UrunBilgi | 15 | ürün özet (kategori/marka) | `entities:bkm.UrunBilgi` |
| DerinSISBkm.bkm.ENVANTER_RAPORU | 12 | envanter özeti | **sema'da yalnız 1 geçiş, entity kaydı yok** → aday |
| DerinSISBkm.dbo.stokSonAltDepo_vw / stokSon_vw | 6 / 3 | mağaza stok bakiyesi | `bridges:stoksonaltdepo-stk` (merkez depo için KULLANILMAZ) |
| DerinSISBkm.depo.stok_adres_palet_vw (+ paletTnm, paletIcHrk, adres, adresAlanTip) | 5 | WMS hücresel stok | `bridges:wms-depo-stok`, `bridges:palet-urn-adres`, `codes:depo.adres.adrsAlanTipID`, `codes:depo.paletIcHrk.pHrkTip` |
| DerinSISBkm.bkm.StokAyBakiyeMekanBazli | 7 | ay-sonu stok snapshot | `entities:bkm.StokAyBakiyeMekanBazli` |
| DerinSISBkm.bkm.SatisAnaliziTaban | 8 | ön-agrega (panel yazar) | `entities:bkm.SatisAnaliziTaban` |
| DerinSISBkm.bkm.BulunurlukOzet / BulunurlukKayip | 3 / 4 | OSA ön-agrega (SQL job yazar) | `entities:bkm.BulunurlukOzet`, `entities:bkm.BulunurlukKayip` |
| DerinSISBkm.mhs.mhsFis / mhsFisBaslik / mhsHsp / mhsAnaHsp | 6 / 7 / 11 / 2 | muhasebe | `entities:mhs.mhsFis`, `bridges:mhsfis-mhsfisbaslik`, `bridges:mhsfis-hsp`, `bridges:hesap-usthesap` |
| DerinSISBkm.bkm.Fin_AyKapanis | 5 | ay kapanış tarihleri (panel yazar) | `entities:bkm.Fin_AyKapanis`, `bridges:evrak-finaykapanis` |
| DerinSISBkm.ent.odak_depo_Stok | 8 | ODAK fulfillment deposu (merkez depo DEĞİL) | `entities:ent.odak_depo_Stok` |
| DerinSISBkm.dbo.sip / sipAyr | 2 / 2 | satınalma siparişi | `entities:dbo.sip`, `codes:sip.eTip`, `codes:sip.eDurum` (kapatma alanı ölü) |
| DerinCrm.dbo.Customer | 9 | müşteri adı | `bridges:sales-customer-name` |
| BKM.snv.Siparis / SiparisDetay / SinavSiparisFisEncore … | 12 / 5 / 8 | Sınav Okulları | `bridges:sinav-fis-encore`, `bridges:siparisdetay-sales` |
| BKMDATA.dbo.Hedef | 5 | satış hedefi | `bridges:hedef-kategori` |
| JOKER.dbo.J_ORDERS / J_ORDER_DETAILS / J_ITEMS / J_ORDER_CLIENTS / J_CARGO | 34 / 22 / 16 / 4 / 3 | e-ticaret | `entities:ODAKJOKER.JOKER.dbo.J_ORDERS`, `entities:…J_ORDER_DETAILS`, `codes:joker.J_ORDERS.STATUS`, `codes:joker.J_ORDER_DETAILS.STATUS`, `bridges:orderdetails-orders`, `bridges:orderdetails-items`, `bridges:items-derinsis`, `bridges:orders-client` |
| BKM_GENEL.dbo.vw_PersonelDepartman | 3 | kadro | `entities:BKM_GENEL.dbo.vw_PersonelDepartman`, `codes:vw_PersonelDepartman.Kadro` |
| BkmPanel.dbo.Panel* (Takvim 12, Gorev 10, AsistanBellek 9, Kullanici 7, AsistanGorusme 7, TahminKayit 6, IcKart 6, GoogleToken 5, KolonTercih 3, Forecast 3, Ayar 3) | — | app-local durum | sema'da yok (app-owned; ölçülemedi) |

## Soft-delete / geçerlilik kolonu — tablo bazında (RUN-007 için)

Ölçüm: `sys.columns` (adı `Is%`, `%Delete%`, `%Valid%`, `%Active%`, `%Durum%`, `%Iptal%` olanlar). Dashboard'da kullanım: grep.

| Tablo | Kolon | Dashboard filtreliyor mu |
|---|---|---|
| EncoreMerkez.dbo.SalesProducts | `IsValid` bit | **evet**, 24 geçiş `IsValid=1` / 31 SalesProducts geçişi; denetimde 1 eksik (`MagazaQueries.cs:96`) |
| EncoreMerkez.dbo.Sales | **yok** (`IsCancelled` yalnız `tmp.sales`'te; `dbo.Sales`'te `CancelledLineCount`) | — (iptal satır düzeyinde `IsValid`) |
| EncoreMerkez.dbo.Products | `IsDeleted`, `IsActive` | hayır (0 geçiş) |
| EncoreMerkez.dbo.Stores / Pos / Users / PaymentTypes / RefundReasons | `IsDeleted` (+ `IsActive` Pos/Users/PaymentTypes) | hayır |
| EncoreMerkez.dbo.Campaign | `IsActive` (IsDeleted YOK) | — |
| DerinSISBkm (dbo.irsHrk, fat, fatAyr, irs, sip, urn, frm, posMagaza, mhs.mhsFis) | **soft-delete kolonu yok.** Durum kolonları: `fat/irs/sip.eDurum`, `sipAyr.ehDurum`, `urn.urnDurum`, `frm.frmDurum`, `posMagaza.mekanDurum` | `eDurum<>2` 19 geçiş / 9 dosya (fatura/sipariş sorguları); `urnDurum/frmDurum` 0 geçiş |
| DerinSISBkm `sil.*` (17 tablo: sip 1,98M · efatArsv 1,67M · irs 1,44M · fat 1,06M · mhsFis 0,78M satır …) | silinen belgelerin arşivi | — |
| JOKER.dbo.J_ORDERS | `ACTIVE` int (0: 10.565 · 1: 4.796.069 sipariş) + `STATUS` | `ACTIVE` **hayır** (0 geçiş); `STATUS` kısmen (denetimde tutarsızlık, `EticQueries.cs:251`) |
| JOKER.dbo.J_ORDER_DETAILS | `STATUS` (satır iptal/iade 2004/2005/2010) | kısmen (`OdakQueries.cs:87` eksik) |
| JOKER.dbo.J_ITEMS | `ISACTIVE` smallint | hayır |

ÇIKARIM (kısmen ölçüldü): DerinSIS **fiziksel siler ve arşive kopyalar** — `sys.sql_modules` içinde `INTO sil.` geçen tek modül `dbo.irs_sil` (ölçüldü); diğer belge tipleri için arşivleme yolu ölçülmedi. Bu yüzden DerinSIS okumalarında "IsValid" eşdeğeri yoktur; RUN-007 burada uygulanamaz.

## Para kolonlarının tipleri (ölçüldü, `sys.columns`)

| Kaynak | Kolonlar | Tip |
|---|---|---|
| EncoreMerkez.dbo.Sales | GrossTotal, DiscountTotal, VatTotal | `decimal(18,2)` |
| EncoreMerkez.dbo.SalesProducts | TotalPrice, VatTotal, DiscountTotalDirect, DiscountTotalCampaign | `decimal(18,2)`; `Amount` (adet) `decimal(18,3)` |
| DerinSISBkm.dbo.irsHrk | ehTutarN, ehTutarOzl | `decimal(15,3)` |
| DerinSISBkm.dbo.fatAyr | ehTutar, ehTutarN, ehTutarKDV … | `decimal(15,2)`; `ehMaliyet` `decimal(15,3)` |
| DerinSISBkm.dbo.urn / bkm.UrunBilgi | fiyatA, fiyatS…S4 / SatisFiyat, OzelWebFiyat | `decimal(15,4)` |
| DerinSISBkm.mhs.mhsFis | fisTutar / fisTutarDvz | `decimal(15,2)` / `decimal(20,4)` |
| JOKER J_ORDERS / J_ORDER_DETAILS | TOTALPRICE, CARGOPRICE, SERVICEPRICE, SELLINGPRICE … | **`money`** |

Hiçbiri Orkestra RUN-005'in `DECIMAL(18,4)` standardında değil (legacy, değiştirilemez). C# tarafı `decimal` (Models'de 320 geçiş); `double` 17 geçiş yalnız oran/skor için (ör. `Models/RefModels.cs:146`).

## Bilinen tuzaklar (sema/kurallarda kayıtlı — işaret)

EncoreMerkez compat 110 (`STRING_AGG/TRIM/IIF/TRY_CONVERT` yok) · `Sales.LineCount` güvenilmez · indirimde yalnız `DiscountTotalDirect` · merkez depo stoğu WMS'ten (`.claude/rules/sql-server-conventions.md` § MERKEZ DEPO) · şube cirosu `eTip 100−101+4−5` · sıfır sentinel (`> 0`, `IS NOT NULL` değil) · dashboard bağlantısı `master`'da açılır → 3-parçalı ad zorunlu.
