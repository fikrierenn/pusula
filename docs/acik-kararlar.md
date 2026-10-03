# Açık kararlar ve varsayılanlar

Orkestra akışında verilen proje kararları. Her satır: tarih, karar, gerekçe, kapsam.

## Kararlar

| No | Tarih | Karar | Gerekçe |
|---|---|---|---|
| K1 | 03.10.2026 | Orkestra kural kataloğu **yeni yazılan ve dokunulan kodda** uygulanır. Dokunulmayan eski kod borç olarak kalır. | `/tanit` 30 çelişki buldu (300+ satır 39 dosya, `ex.Message` ekranda 51 yer, `DateTime.Now` 117, katman yok). Hepsini birden düzeltmek kapsamı patlatır. |
| K2 | 03.10.2026 | `config/veritabanlari.json` `sys.databases` ölçümüyle yazıldı. ODAKJOKER uyumluluk seviyesi 110 değil 150. | SQL denetçisi bu dosyadan okuyor; yanlış değer gereksiz yasak üretiyordu. |
| K3 | 03.10.2026 | Semantik katman kaynağı deponun kendi `sema/` klasörü (`config/orkestra.json` → `"."`). | Kanonik sema pusula'da. `sema` CLI bu makinede kurulu değil; `ork sema denetle` kurulana kadar koşamaz. |
| K4 | 03.10.2026 | Geliştirmede BkmPanel bu makinenin (SANAL-FIKRI) yerel SQL Server'ına kurulur. | Mevcut panel veritabanına bu makineden erişilemiyor (error 26). Panel servisleri tabloları kendisi kurar. |
| K5 | 02.10.2026 | Dashboard BT-FIKRI'ye **git remote** ile taşınır ve orada **servis** olarak çalışır. | Kullanıcı kararı. Remote ve servis türü (Windows Service / IIS) henüz seçilmedi; BT-FIKRI 02.10'da erişilemiyordu. |
| K6 | 02.10.2026 | proje-kur'un .NET şablonları (`Directory.Build.props`, `Directory.Packages.props`, `global.json`, `.editorconfig`, `BannedSymbols.txt`) **alınmadı**. | Dashboard derlemesini `NU1504` ile kırdı. Dosyalar `.orkestra/ertelenen-dotnet-sablon/` altında; merkezi paket yönetimi ve uyarıyı hata sayma ayrı iş. |

| K7 | 03.10.2026 | Spec 001 (panel veri düzeltmeleri) ve planı onaylandı; 12 karar önerildiği gibi (`specs/001-panel-veri-duzeltme/plan.md` § Onay kaydı). | GMY onayı. |
| K8 | 03.10.2026 | K1 genişletmesi: dokunulan sorgularda `WITH(NOLOCK)` ve tek harfli tablo takma adları mevcut borç olarak kalır. | Davranış düzeltmesiyle biçim değişikliğini karıştırmamak (plan 001 R6). |

## Açık sorular

| No | Soru | Durum |
|---|---|---|
| S1 | Türkçe tanımlayıcı: katalog ile projenin `turkish-ui.md` kuralı çelişiyor (3.508 bulgu dondurulmuş). K1 gereği yeni kod İngilizce; eski bulgular borç. | K1 ile kapandı sayılır, teyit bekliyor |
| S2 | BT-FIKRI'de hangi remote (`origin` GitHub / `ayna`) ve hangi servis türü? | Açık |
| S3 | `sema` CLI kurulumu. | Açık |
| S4 | `OrkestraTest` test veritabanının gerçek adı ve yeri. | Açık |
| S5 | Test koşusu için yalnız `db_datareader` yetkili ayrı SQL login'i (192.168.40.201). DB yöneticisi açacak; açılana kadar R1 salt-okuma kapısı + ROLLBACK işlemi koruyor. | Açık — onaylandı, uygulama bekliyor |
