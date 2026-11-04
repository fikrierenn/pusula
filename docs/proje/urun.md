# Ürün — BKM Yönetim Paneli (dashboard/)

> Tür: proje tanıtımı (ürün) · Kaynak commit: `d5cf345` · İzlenen yollar: `README.md`, `CLAUDE.md`, `dashboard/README.md`, `dashboard/Program.cs`, `dashboard/Models/NavRegistry.cs`, `dashboard/wwwroot/manifest.json`, `.orkestra/gm-denetim-2026-10-02.json` · Son doğrulama: 03.10.2026 (/tanit; çalışma ağacında dashboard dışı 2 değişik + 1 izlenmeyen dosya)

## Ne yapıyor

BKM Kitap'ın (kitap + kırtasiye + Sınav Okulları; 3 mağaza: FSM, Özlüce, İst.Yolu + merkez depo) **genel müdür yardımcısı için salt-okuma yönetim panosu**. ERP (DerinSIS), POS (EncoreMerkez), e-ticaret (JOKER), İK/bordro (Zirve) verisini tek yerde KPI, grafik ve tablolarla gösterir; büyük listeleri Excel'e döker; yerleşik bir LLM asistanı ("Genius") taşır.
Kanıt: `dashboard/README.md:1-3` ("Blazor Server (.NET 10) GM BI panosu + BKM-Asistan"), `CLAUDE.md` § Proje Kimliği, `manifest.json` description.

## Kimin için

- **Birincil kullanıcı:** Fikri Eren (BKM Kitap GMY; IT · İK · Muhasebe · Finans · Perakende). Tek kullanıcılı tasarım: ilk açılışta `/setup` tek kullanıcı oluşturur (`Program.cs:108-126`), oturum cookie'si 12 saat (`Program.cs:21-31`).
- **İkincil:** yönetim/patron soruları için çıktılar (Excel, `PatronSorulari` sayfası). Çok kullanıcılı rol/yetki modeli YOK (dashboard'da `[Authorize]` rol kullanımı 0; ÖLÇÜLDÜ grep).
- **Cihaz:** masaüstü + telefon (PWA, `manifest.json` `display: standalone`, `orientation: portrait-primary`; HTTP 5112 + HTTPS 5443 paralel, `Program.cs:65-66`).

## Ana iş akışları (menü grupları — `Models/NavRegistry.cs`)

| Grup | Sayfalar (route) | Ne sorusu |
|---|---|---|
| (üst) | `/` Genel Bakış, `/v2` (deneme) , `/sabah` | Günün özeti, sabah brifingi |
| YÖNETİM | `/patron-sorulari`, `/tahmin`, `/operasyon`, `/kadro`, `/vardiya` | Hedef tahmini, operasyon uyarıları, kadro/sezon personeli (Zirve), vardiya/mesai |
| SATIŞ | `/magazalar`, `/magaza/{id}`, `/toplam`, `/eticaret`, `/sinav`, `/trafik` | Mağaza cirosu/fiş/iade, kategori toplamı, e-ticaret kanalı, Sınav Okulları, trafik & kasiyer |
| MÜŞTERİ | `/musteri`, `/sadakat`, `/hediye-ceki` | RFM, kart oranı, win-back, hediye çeki kârlılığı |
| STOK & SATINALMA | `/satis-analizi` (+ `/satis-analizi/urun/{id}`), `/sezon-aksiyon`, `/envanter`, `/stok-hareket`, `/odak-stok`, `/bulunurluk`, `/baskisi-yok`, `/satinalma/analiz` (+ ürün detay) | Ürün bazlı satış/stok/marj, sezon sipariş listesi, ölü stok, bulunurluk (OSA), ODAK stok |
| FİNANS | `/muhasebe`, `/mizan`, `/gider-mizan`, `/gelir-tablosu`, `/cari-risk`, `/fatura`, `/yevmiye-fis` | Ay kapanışı kontrolü, mizan, gelir tablosu, cari risk |
| ASİSTAN | `/asistan`, `/gorevler`, `/bellek` | LLM asistanı (Z.ai → OpenRouter → Gemini → Groq zinciri), görev listesi, asistan belleği |
| SİSTEM | `/parametreler`, `/ayarlar` | İş eşikleri (devir/stockout/risk), ayarlar |

Toplam 41 `@page` (ÖLÇÜLDÜ: `grep -c '@page'` = 41); denetim dosyası 41 sayfa envanteri taşır (`.orkestra/gm-denetim-2026-10-02.json` → `pages`).

### Dışa aktarım uçları (circuit dışı, akışla)

- `GET /api/satis-analizi-excel` — 4 sayfalı Excel (Liste/Detay/Mağaza/Depo Adres + Bilgi) (`Program.cs:156-285`)
- `GET /api/sezon-aksiyon-excel` — sezon sipariş listesi (`Program.cs:293-404`)
- `GET /api/olustok-excel` — ölü stok (`Program.cs:406-429`)
Gerekçe kodda yazılı: büyük listede base64/JS yolu Blazor circuit'ini çökertiyordu (`Program.cs:149-152`).

### Tek meşru yazma akışları (ERP'ye)

- Ay kapanış tarihi girişi → `DerinSISBkm.bkm.Fin_AyKapanis` (`Data/MuhasebeQueries.cs:192` MERGE)
- Satış analizi ön-agregası → `DerinSISBkm.bkm.SatisAnaliziTaban` (`Data/SatisAnaliziTabanService.cs:112,127,437`)
Gerisi salt-okuma (`.claude/rules/erp-write-policy.md`). Panelin kendi durumu (kullanıcı, görev, ayar, tahmin, takvim, iç kart, asistan belleği) app-local `BkmPanel` veritabanında `dbo.Panel*` tablolarında.

## Bilinen durum (ön girdi — yeniden ölçülmedi)

`.orkestra/gm-denetim-2026-10-02.json`: 1 kritik (Kumbara/Manuel indirim fan-out, `RefQueries.cs:578/607`), 2 yüksek (`RefQueries.Envanter.cs:536` merkez stok ERP defterinden; `SadakatQueries.cs:10` win-back "son 90 gün yok" koşulu eksik), 14 orta/12 düşük bulgu; mobil yeniden yazım için plan taslağı ("Plan 52").

## Bilinmeyen

- Gerçek kullanıcı sayısı / panelin şirket içinde kimlerle paylaşıldığı: **bilinmiyor** (kodda tek kullanıcı varsayımı var).
- Üretim dağıtım hedefi: plan taslağında "BT-FIKRI makinesine dağıtım" geçiyor; bu makinede (SANAL-FIKRI) panel DB'si ulaşılamaz durumdaydı (bkz. `veritabani.md`).
