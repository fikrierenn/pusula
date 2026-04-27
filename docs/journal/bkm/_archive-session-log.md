# BKM Kitap — Session Log (Arşiv)

> Bu dosya, eski `SESSION_LOG.md`'nin tam kopyasıdır. 27 Nisan 2026'da multi-project journal yapısına geçildi; bu noktadan sonra her oturum `docs/journal/<proje>/YYYY-MM-DD.md`'ye yazılır.
>
> Aşağıdaki içerik tarihli journal dosyalarına da parçalanmıştır:
> - 2026-04-12.md (Session 1) · 2026-04-13.md (Session 2)
> - 2026-04-14.md (Session 4 başlangıç) · 2026-04-15.md (Session 3 + 4 ortası)
> - 2026-04-20.md (Session 5 başlangıç) · 2026-04-21.md (Session 5 devam)

---

## Session 1 — MCP Server Kurulumu (Nisan 2026)

### Yapılanlar
- SQL Server MCP sunucusu kuruldu (Node.js/TypeScript)
- Claude Desktop config ayarlandı — 6 veritabanına erişim: master, EncoreMerkez, DerinSISBkm, DerinSISBkmCrm, DerinSISBkmWeb, BKMDATA
- 3 yeni discovery tool eklendi: sql_search_columns, sql_relationships, sql_sample_data
- BKM Kitap operasyon ve data skill dosyaları oluşturuldu

### Öğrenilenler
- SQL Server'ın compatibility level 110 (SQL 2012) ile çalıştığı keşfedildi
- STRING_AGG, TRIM, IIF, TRY_CONVERT fonksiyonları çalışmıyor

---

## Session 2 — EncoreMerkez Keşfi + Kampanya Analizi (13 Nisan 2026)

### Yapılanlar
- EncoreMerkez veritabanı tam tarandı (8 şema, 196 obje, 145 FK ilişki)
- `skills/encore-merkez/SKILL.md` oluşturuldu
- `sql_describe_table` bug fix: STRING_AGG → STUFF+FOR XML PATH
- Kapsamlı analiz raporu: `encore-merkez-analiz-raporu.html` (10 bölüm, 22 SQL)

### Öğrenilen Kritik Bilgiler
- Campaign tablosunda IsDeleted YOK
- 3 AL 2 ÖDE: Id=1 (eski), Id=12 (aktif)
- TotalDiscount negatif → ABS()
- CampaignId=NULL kayıtlar: 389.4M ₺ indirim
- Ödeme: %85 kart (Anadolubank %32), %15 nakit
- Eylül 2025 rekor: 138M ₺ (okul sezonu)
- Kampanyalı sepet 2x (7.2 vs 3.5 ürün)

### Kararlar
- CTE > subselect (Fikri tercihi)
- 3AL2ÖDE kırılımı (BrutCiro/Indirim/NetCiro/UrunSayisi) standart
- Tarih: dd.MM.yyyy

### Açık Konular
- [ ] DerinSISBkm taraması
- [ ] Haftalık otomatik rapor
- [ ] CampaignId=NULL araştırması
- [ ] Rapor onay bekliyor

---

## Session 3 — İkinci SQL Server Bağlantısı (15 Nisan 2026)

### Yapılanlar
- `192.168.40.66\SQLEXPRESS` için ikinci MCP entry: `sqlserver-express`.
- Aynı binary iki ayrı env vars ile.
- `CLAUDE.md` "Veritabanı Bağlantısı" iki alt başlık.
- `sorgular/SESSION.md` MCP sunucu seçim kuralı.

### Öğrenilen Kritik Bilgiler
- Aynı MCP binary iki kez register edilebilir.
- Named instance port problemi: SQLEXPRESS dinamik port. Çözüm: TCP/IP IPAll TCP Port=1433 sabitle.
- Config: `%APPDATA%\Claude\claude_desktop_config.json`
- Tool prefix = MCP entry adı: `mcp__sqlserver__...`, `mcp__sqlserver-express__...`
- Restart şart.

### Kararlar
- Default = `sqlserver` (201).
- "Express'te", "66'da" → `sqlserver-express`.
- Belirsizse sor.

### Açık Konular
- [ ] Express kullanım amacı `[DOLDUR]` alanı.
- [ ] Express DB listesi, ALLOWED_DATABASES.
- [ ] Cross-server sorgu ihtiyacı.

---

## Session 4 — E-ticaret Trend Raporu + Grok + Mobil App Baremli (14-15 Nisan 2026)

### Yapılanlar
- `BKM-Eticaret-Yonetim-Sunumu.html` revize: "Patron" çıktı, "6 karar" başlığı, ONAY/KAYNAK/KARAR/SAHİPLİK/YÖN etiketleri, Metodoloji slide kaldırıldı, sonuç sertleştirildi, Grok slide eklendi.
- `BKM-Eticaret-Trend-Raporu.{md,html}` § 10b: Grok/X harmanlama (enemies-to-lovers, Grangé, yerli romantik, Wattpad→basılı, rakip boşluğu).
- `BKM-Mobil-App-Baremli-Rapor.{md,html}`: 3 barem (sıklık 90 gün CUSTOMERREF, sepet H15, 15 hafta seyir). H15 App: 7.672 sipariş, 8.51M ₺, sepet 1.110 ₺. iOS 5000+ %53 premium.
- `sorgular/00-README.md` 8 değişmez kural.
- `sorgular/2026-04-14-mobil-app-baremli-rapor.sql` kanonik (J_ORDER_CLIENTS).
- `CLAUDE.md` "E-ticaret (ODAKJOKER.JOKER)" bölümü.

### Öğrenilen Kritik Bilgiler
- Linked server tarih: `YYYYMMDD` ISO. DMY sessiz hata.
- Müşteri zinciri: J_ORDERS.CLIENTREF → J_ORDER_CLIENTS.LOGICALREF → CUSTOMERREF.
- J_ORDER_CLIENTS = J_CLCARD birebir (13.26M satır). Standart: J_ORDER_CLIENTS.
- ISO hafta: `DATEDIFF(DAY, '20251229', CAST(... AS date))/7+1`.
- Kanal: `'Mobil Uygulama (Android/iOS)'`, `'Mobil Site'`, `'Web Sitesi'`.
- CUSTOMERREF=0/NULL = misafir.

### Kararlar
- `sorgular/` dosya adı: `YYYY-MM-DD-<analiz>.sql`.
- Müşteri join: J_ORDER_CLIENTS.
- Linked server tarih: ISO.
- Yönetim sunumunda metodoloji yok.

### Açık Konular
- [ ] Önceki trend SQL'leri arşive.
- [ ] Grok cross-check (timeout sorunu).
- [ ] Eski J_CLCARD versiyonu deprecated.

---

## Session 5 — IsValid/LineCount Keşfi + Veri Doğrulama + Araçlar (20-21 Nisan 2026)

### Yapılanlar
- IsValid keşfi + 7 SQL düzeltmesi.
- İndirim kolon ilişkisi.
- SsmsExcelExporter (C# WinForms + ClosedXML, 2 hotkey).
- Nisan 2026 kampanya HTML raporu.
- `docs/08-pos-encore.md` Alan İlişkileri.

### Öğrenilen Kritik Bilgiler
- SalesProducts.IsValid = false → iptal. Sales header zaten hariç tutar.
- Sales.LineCount GÜVENİLMEZ → CROSS APPLY (WHERE IsValid=1).
- DiscountTotalDirect = toplam, Campaign = alt küme. Sadece Direct kullan.
- Doğrulama (IsValid=1):
  - SUM(TotalPrice) = GrossTotal - ABS(DiscountTotal) ✓
  - SUM(DiscountTotalDirect) = ABS(DiscountTotal) ✓
- 3Al2Öde Nisan 2026: 12.836 fiş, 20.57M brüt, 15.56M net, sepet 1.602 ₺, 6.9 ürün.
- SSMS 22 extension yok.
- EncoreMerkez ProductGroupCode yok.

### Kararlar
- SalesProducts: WHERE IsValid=1 standart.
- LineCount → CROSS APPLY pattern.
- İndirim: sadece DiscountTotalDirect.

### Açık Konular
- [ ] SsmsExcelExporter build & test.
- [ ] CampaignId=NULL araştırması.
- [ ] Ürün maliyet/marj.
- [ ] EncoreMerkez ↔ DerinSIS urn mapping.

---

## Dosya Haritası

| Dosya | Açıklama | Session |
|---|---|---|
| `skills/encore-merkez/SKILL.md` | EncoreMerkez DB şema | S2 |
| `skills/bkm-kitap-operasyon/SKILL.md` | BKM operasyon | S1 |
| `skills/bkm-kitap-data/SKILL.md` | BKM data | S1 |
| `encore-merkez-analiz-raporu.html` | Analiz raporu (22 SQL) | S2 |
| `src/tools/schema.ts` | bug fix (SQL 2012 compat) | S2 |
| `BKM-Eticaret-Yonetim-Sunumu.html` | Yönetim sunumu (Grok) | S4 |
| `BKM-Eticaret-Trend-Raporu.{md,html}` | H15 trend + §10b Grok | S4 |
| `BKM-Mobil-App-Baremli-Rapor.{md,html}` | 3 barem | S4 |
| `sorgular/00-README.md` | Sorgu standartları | S4 |
| `sorgular/2026-04-14-mobil-app-baremli-rapor.sql` | Kanonik mobil app SQL | S4 |
| `sorgular/03-kampanya/SsmsExcelExporter/` | SSMS → Excel | S5 |
| `sorgular/03-kampanya/3al2ode-kampanya-raporu-nisan2026.html` | Nisan kampanya | S5 |
| `sorgular/03-kampanya/fis_detay_dogrulama.sql` | IsValid fix | S5 |
| `docs/08-pos-encore.md` | Alan İlişkileri | S5 |

---

## Fikri'nin Tercihleri

- CTE tercih, subselect kullanmaz
- Brüt/indirim/net üçlüsü her zaman birlikte
- Ürün sayısı her zaman dahil
- Çalıştırılabilir + kampanya kırılımlı sorgu
- Tarih: dd.MM.yyyy (DMY)
