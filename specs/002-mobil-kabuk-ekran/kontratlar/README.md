# Kontratlar — 002 Telefon kabuğu ve ekranlar

SP, API ucu ve 5xxxx hata kodu yok. HTTP tarafında tek değişiklikler: eski adreslerde 302, HTML yanıtında `Cache-Control: no-store`.

| Dosya | Kapsam |
|---|---|
| `kabuk.md` | Alt menü, sekme panelleri, rozet, oturum, PWA (manifest, service worker, çevrimdışı), bağlantı kopması |
| `telefon-kapisi.md` | 001 kapısı: veri yapısı, anahtarlar, açma ve geri alma, testler |
| `bugun.md` | Bugün sayfası ve dokuz kart |
| `ekranlar.md` | A, B, C ekranlarının telefon sözleşmesi; Ayarlar/Eşikler; birleşmeler |
| `yonlendirmeler.md` | Altı eski adres |
| `olcum.md` | 375/44/16/ipucu/kapı ölçümü |

## AC → bileşen → test

| AC | Bileşen | Test (dosya) | Dalga |
|---|---|---|---|
| AC-0.1, 0.2, SC-006 | `TelefonKapisi`, `MobilSekmePaneli` | `Bagimlilik_*`, `KapananMaddeler_HepsiKabulSonucundaTuttu` (telefon-kapisi) · Kapı ölçümü (olcum) | 1 |
| AC-0.3, SC-005 | Ortak çekirdek metotlar, `data-gosterge` | `Gosterge_375ve1280_AyniDeger` (ekranlar) | 1–2 |
| AC-0.4 | `BugunKart.Not`, B özetleri | Playwright: not göstergenin yanında (ekranlar) | 2 |
| AC-0.5, 6.2, SC-001, SC-001a | Sayfa düzenleri | Taşma ölçümü (olcum) | 1–2 |
| AC-0.6, SC-002 | Ortak bileşenler, sayfalar | Dokunma ölçümü (olcum) · `TiklanabilirOge_*` (ekranlar) | 1–2 |
| AC-0.7 | Sayfalar | İpucu ölçümü (olcum) | 1–2 |
| AC-0.8 | `app.tailwind.css`, sayfalar | 16 px ölçümü (olcum) | 1 |
| AC-0.9, 5.8 | `GorunumSaglayici` + çizim kuralı (plan K2) | `BEkrani_1280_BolumEksiksiz`, masaüstü önce/sonra (ekranlar) | 1–2 |
| AC-0.10 | Sayfalar, `KullaniciMesajlari` (001) | `HataMetni_*`, `Ekran_VeriKaynagiYok_GenelMesaj` (ekranlar) | 1–2 |
| AC-1.1–1.3, SC-003 | Manifest, ikonlar, `App.razor` | `Manifest_KurulumAlanlariTam` + cihazda elle (kabuk, olcum § 7) | 1 |
| AC-1.4–1.8, SC-004 | `MainLayout`, `NavRegistry`, `MobilSekmePaneli`, `GorevService.Ozet` | `AltMenu_*`, `Hedef_BugundenIkiDokunusta`, `Rozet_*`, `NavRegistry_*`, `GorevOzet_*` (kabuk) | 1 |
| AC-1.9 | Kimlik doğrulama (değişmez) | `KokIstek_OturumYok_GiriseYonlenirRakamYok` (kabuk) | 1 |
| AC-1.10, FR-011 | Service worker, `offline.html`, `no-store` | `Cevrimdisi_*`, `HtmlYaniti_NoStoreTasir` (kabuk) | 1 |
| AC-1.11 | `ReconnectModal` | `BaglantiKoptu_UyariGorunurVeDurur` (kabuk) | 1 |
| AC-2.1, 2.2 | `CariRisk` (düzen), hesap 001 ek maddesinde | Playwright (ekranlar); kapı `001:cari-risk` | 1 (düzen), 3 (açılış) |
| AC-2.3, 2.4 | `Gorevler`, `GorevService` | `GorevOzet_*`, `GorevSil_OnaySorar` | 1 |
| AC-2.5–2.7 | `Asistan`, `AsistanGirisCubugu`, `GeniusBellek` | Playwright (sekme) + cihazda elle (klavye) | 1 |
| AC-3.1–3.5 | `Muhasebe`, `GelirTablosu`, `Mizan` + çekirdek özetler | `MuhasebeKontrolOzeti_*`, `GelirTablosu_Ozetle_*`, Playwright | 1 (3.1, 3.2, 3.5), 2 (3.3, 3.4) |
| AC-4.1–4.17, FR-003, FR-008, FR-009 | `Bugun`, `BugunKart`, kartlar, `BugunRenk`, `UyariKurallari`, `OkulHizaliKiyas` | `BugunRenk_*`, `UyariKurallari_*`, `Bugun_375_*` (bugun) | 1 (4.2, 4.11, 4.12, 4.14, 4.15, 4.17), 2 (kalan) |
| AC-5.1–5.8 | Satış paneli, B ekranları | Kapı ölçümü, `BEkrani_*` (ekranlar) | 2 (Toplam 1) |
| AC-6.1–6.7, FR-003a, FR-003b | Diğer paneli, Operasyon, Envanter, Vardiya, Ayarlar, Eşikler, C ekranları | Kapı ölçümü, `Ayarlar_*`, `Vardiya_*`, taşma (ekranlar, olcum) | 1–2 |
| AC-7.1–7.4, FR-010, SC-007 | `EskiAdres`, `EskiAdresler`, birleşen alt bileşenler | `EskiAdresler_Hedef`, `EskiAdres_GetIstegi_302VeHedef`, `BirlesenGosterge_HedefteAyniDeger` (yonlendirmeler) | 1 (`/v2`, `/bellek`), 2 |
| FR-005, FR-012, FR-013 | Kart ve özetler yalnız çekirdek metotları çağırır; yeni hesap yok, yazma yok | İnceleme + `Gosterge_375ve1280_AyniDeger` | 1–2 |
| SC-008 | `start_url ?kaynak=uygulama` + günlük | ÇIKARIM ölçüt: 10 iş günü günlük sayımı (004'teki günlük hedefinden) | 3 |
