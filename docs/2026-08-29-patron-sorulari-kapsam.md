# Patron Soruları — Kapsam Matrisi (25 soru)

**Tarih:** 29.08.2026 · **Kaynak çerçeve:** "Patron Soruları — Tüm Departmanlar" (6 departman × 4-5 soru + 1 kapanış)
**Amaç:** her sorunun bugün cevaplanıp cevaplanamadığını, cevaplanıyorsa NEREDEN, cevaplanmıyorsa NEDEN olmadığını tek yerde tutmak.
**Kullanım:** `plans/37-patron-sorulari-paneli.md` → `PatronSorulariRegistry.cs` bu tablodan türetilir. **Tek kaynak burasıdır** — registry ile bu belge ayrışırsa belge doğrudur.

## Rozet anlamı

| Rozet | Anlam |
|---|---|
| ✅ | Canlı dashboard sayfasında cevaplanıyor |
| 🟡 | Bir yönü var, sorunun tamamını cevaplamıyor (eksik kısım kolonda yazılı) |
| ❌ | Veri/ekran yok — boşluk |
| ⬜ | Kapsam dışı (BKM'de bu iş yok) — boşluk sayılmaz, skoru bozmaz |

**Skor:** ✅ 9 · 🟡 8 · ❌ 7 · ⬜ 1 = 25

## Doğrulama yöntemi

Atamalar hafızadan değil **canlı kaynaktan** yapıldı: `dashboard/Components/Pages/*.razor` içindeki başlık/kart etiketleri (`<h1..h3>`, `card-title`, KPI etiketleri) ve `dashboard/Data/*Queries.cs` dosya envanteri tarandı (29.08.2026). Bir sorunun ✅ sayılması için o sayfada karşılık gelen **isimli bir kart/bölüm** bulunması şart tutuldu. "Sorgusu var ama ekranı yok" → 🟡.

---

## 1 — Her departmana önce (kesişen blok)

| ID | Soru | Durum | Kaynak | Kanıt / eksik |
|---|---|---|---|---|
| PS-1.1 | Hedef neydi? | ✅ | `/tahmin` · `/magazalar` | "Mağaza Bazlı Tahmin", "Hedef (MTD)" kartı |
| PS-1.2 | Gerçekleşen ne oldu? | ✅ | `/` · `/toplam` · `/magazalar` | KPI bandı + "TOPLAM — Kategoriler" |
| PS-1.3 | Fark neden oluştu? | 🟡 | `/tahmin` | "Hesap Adımları" + "Bileşen Kırılımı" var. **Eksik: fiyat × miktar × mix variance ayrıştırması** — farkın kaynağı sayısal olarak bölünmüyor |
| PS-1.4 | Para ve nakit etkisi ne? | ❌ | — | Gelir tablosu (tahakkuk) var, **nakit yok**. → plan-38 |
| PS-1.5 | Kim, ne zamana kadar düzeltecek? | ✅ | `/gorevler` | Görev + son tarih + açık görev rozeti |

> Bu blok departmana özel değil; panelde her departman bloğunun başında tekrar eder. Danışman: ilgili departmanınki.

## 2 — Satış ve pazarlama · danışman `satis-danisman`

| ID | Soru | Durum | Kaynak | Kanıt / eksik |
|---|---|---|---|---|
| PS-2.1 | Hangi müşteri ve ürün gerçekten kazandırıyor? | 🟡 | `/sadakat` · `/musteri` · `/envanter` | Müşteri tarafı tam: "Müşteri Konsantrasyonu — Pareto", "Müşteri Segmenti (RFM)", "Kohort Retention". Ürün tarafı **kategori/marka/tedarikçi** seviyesinde ("Kategori Brüt Marj", "Tedarikçi/Yayınevi Performans"). **Eksik: SKU bazlı kâr** |
| PS-2.2 | İndirim katkı payını ne kadar düşürüyor? | 🟡 | `/operasyon` · `/hediye-ceki` | "İndirim Kaynağı" dağılımı + çek baremli kârlılık ("İndirim mi, çek fazlası mı?"). **Eksik: indirim → marj erozyonu köprüsü** (kategori üstü, tüm indirim türleri birlikte) |
| PS-2.3 | Teklifler satışa neden dönmüyor? | ⬜ | — | **Kapsam dışı** (GMY kararı 29.08): BKM perakende, B2B teklif süreci yok. Görünür kalır ki tekrar sorulmasın |
| PS-2.4 | Hangi alacağın tahsilatı riskli? | ✅ | `/cari-risk` | "Vadesi Geçen (toplam)" + "Limit Aşan Cari" + net bakiye |

## 3 — Satın alma ve stok · danışman `satinalma-danisman`

| ID | Soru | Durum | Kaynak | Kanıt / eksik |
|---|---|---|---|---|
| PS-3.1 | Doğru fiyat ve vadeyle mi alıyoruz? | 🟡 | `/satinalma/analiz` | Fiyat tarafı tam: "Fiyat Sapması" sekmesi (`SatinalmaQueries.FiyatSapma`), 3 adalet filtresi. **Eksik: vade ekseni** — iade/ödeme koşulu analizi yok (B-150 `frmIadeKural` anlamı muhasebeden bekleniyor) |
| PS-3.2 | Stok kaç gün bekliyor? | ✅ | `/envanter` | "Kategori Devir Hızı" + ölü stok listesinde "gün listede" |
| PS-3.3 | Hangi mal yavaşlıyor veya değer kaybediyor? | ✅ | `/envanter` · `/baskisi-yok` · `/bulunurluk` | "Ölü Sermaye — Kilitli Stok", "Marka Alış-Satış Dengesi", baskısı yok listesi |
| PS-3.4 | Alternatif tedarikçimiz var mı? | ❌ | — | Tedarikçi ↔ ürün alternatif matrisi yok; tek-yayınevi bağımlılığı ölçülmüyor. → Tier-2 |

## 4 — Operasyon (perakendede: mağaza + depo + kafe + lojistik) · danışman `operasyon-danisman`

> Çerçevedeki "Üretim ve Operasyon" başlığı BKM'de üretim olmadığı için mağaza/depo/kafe/lojistik olarak okunur.

| ID | Soru | Durum | Kaynak | Kanıt / eksik |
|---|---|---|---|---|
| PS-4.1 | Kapasitenin ne kadarı kullanılıyor? | ✅ | `/operasyon` | "İşgücü Verimi — ₺/Çalışılan Saat (SPLH)", "Depo Toplama Verimi", "Kayıp İşgücü Potansiyeli", "Bekleyen Sipariş — Doluluk" |
| PS-4.2 | Fire ve yeniden işleme neden arttı? | ❌ | — | **Tek başlık, 3 alt-kalem** (GMY kararı 29.08): (a) kayıp-kaçak / sayım farkı, (b) iade edilemez / yayınevine dönmeyen stok, (c) kafe zayi. Üçünün de veri kaynağı **belirsiz** → önce keşif (DerinSIS sayım/imha hareket tipi var mı, kafe zayi nerede kayıtlı) |
| PS-4.3 | Birim maliyet neden değişti? | ✅ | `/satinalma/analiz` · `/envanter` | Alış fiyat sapması + kanonik maliyet şelalesi (son 5 alış faturası). ⚠ Fiyat/mix/fire ayrıştırması yorumda yapılır |
| PS-4.4 | Teslimat nerede gecikiyor? | ✅ | `/eticaret` | "Bekleyen Gün — Kargoya Çıkmamış", "Günlük Kargo Çıkışı (sipariş → kargoya teslim gün)", "Kargo Performansı" firma bazlı |

## 5 — Finans, muhasebe ve vergi · danışman `finans-nakit-danisman`

> **En zayıf blok.** 4 sorunun 2'si tamamen boş, 2'si yarım. plan-38'in gerekçesi budur.

| ID | Soru | Durum | Kaynak | Kanıt / eksik |
|---|---|---|---|---|
| PS-5.1 | 13 haftada en düşük nakit ne zaman? | ❌ | — | Haftalık nakit projeksiyonu yok. Gereken ve **bugün olmayan** veri: banka hareketi, kredi/leasing taksit takvimi, tedarikçi vade dağılımı, POS valör günü, vergi/SGK ödeme takvimi. → plan-38 |
| PS-5.2 | Borç taksiti faaliyet nakdini karşılıyor mu (DSCR)? | ❌ | — | Borç servisi takvimi veride yok; faaliyet nakdi de türetilmiyor (işletme sermayesi değişimi hesaplanmıyor). → plan-38 |
| PS-5.3 | KDV ve vergi için para ayrıldı mı? | 🟡 | `/mizan` | Kesin mizan hesapları görülebiliyor. **Eksik: karşılık görünümü** (ödenecek vergi vs ayrılan para). ⚠ Kitap %0 KDV → satış KDV'si yok, **girdi KDV'si devreden** olarak birikir; bu ayrı okunmalı |
| PS-5.4 | Banka, POS, stok ve kayıtlar tutarlı mı? | 🟡 | `/muhasebe` · `/operasyon` | Kapanış-sonrası müdahale denetimi + "Ödeme Grubu" mutabakatı var. **Eksik: banka mutabakatı** (banka hareketi otomatik akmıyor; POS valör + komisyon netleşmesi yok) |

## 6 — İK, bilgi teknolojileri ve lojistik

> Şemada tek kutu ama **üç ayrı disiplin** — üç ayrı danışmana bağlanır (GMY itirazı 29.08).

| ID | Soru | Durum | Kaynak | Danışman | Kanıt / eksik |
|---|---|---|---|---|---|
| PS-6.1 | Pozisyonun şirkete katkısı ve maliyeti ne? | 🟡 | `/trafik` · `scripts/beyaz_yaka_maas_excel.py` | `ik-danisman` | Kasiyer verimi + PDKS var; maaş dökümü **script**, ekran yok. ⚠ Ücret birimi tuzağı: GÜNLÜK (kadronun ~%99) vs AYLIK karıştırılırsa 30× hata. Çıktı kişisel veri → git'e girmez (B-161 maskeleme modları açık) |
| PS-6.2 | Tek kişiye bağımlı iş var mı? | ❌ | — | `ik-danisman` (kişi) + `bt-risk-danisman` (sistem/bilgi) | Bus-factor envanteri yok. İki yarısı ayrı: kim yapabilir listesi (İK) · SQL job/ERP parametresi bilgisi kimde (BT) |
| PS-6.3 | Veri ve sistem kesintisi riski ne? | ❌ | — | `bt-risk-danisman` | RTO/RPO ölçülmemiş, geri yükleme testi kaydı yok. ⚠ Yoğunlaşma: 192.168.40.201 tek sunucuda DerinSISBkm + EncoreMerkez + BKM + DerinCrm; gece job'ları sessiz başarısız olursa dashboard bayat veri gösterir |
| PS-6.4 | Sevkiyat ve teslimat maliyeti neden değişti? | 🟡 | `/eticaret` | `operasyon-danisman` | Kargo firma dağılımı + COD iade maliyeti + kapıda bedel var. **Eksik: birim kargo maliyet trendi** (desi/mesafe/firma mix ayrıştırılmış) |

## Kapanış sorusu

| ID | Soru | Nasıl |
|---|---|---|
| PS-0 | **"Sen olsan ne yapardın?"** | Panelde her departman bloğunun altında buton → o bloğun canlı rakamları + rozet durumları ilgili **danışman rolüyle** Genius'a (`/asistan`) beslenir, üç aksiyon önerisi döner. Genel LLM değil: danışmanın davranış sözleşmesi (overclaim yasak · confound · perverse-incentive) sistem promptuna girer |

---

## Boşluk envanteri (7 ❌) → nereye bağlanıyor

| ID | Boşluk | Bağlandığı iş |
|---|---|---|
| PS-1.4 · PS-5.1 · PS-5.2 | Nakit etkisi · 13-hafta nakit · DSCR | **plan-38 (nakit bloğu)** — şartnamesini `finans-nakit-danisman` üretir |
| PS-6.2 · PS-6.3 | Bus-factor · sistem kesinti riski | **plan-39 (İK/BT)** |
| PS-3.4 | Alternatif tedarikçi | Tier-2 |
| PS-4.2 | Fire & kayıp (3 alt-kalem) | Tier-2 **keşif** işi — veri kaynağı doğrulanmadan analiz tasarlanmaz (fact-force gate) |

## 🟡'lerin eksik yarısı (8) — küçük işler

| ID | Eksik | Boyut |
|---|---|---|
| PS-1.3 | Fiyat × miktar × mix variance ayrıştırması | Tier-2 |
| PS-2.1 | SKU bazlı kâr | Tier-2 (FIFO maliyet katmanı `D:\Dev\fifo`'da hazır, dashboard'a bağlanmamış) |
| PS-2.2 | İndirim → marj erozyonu köprüsü | Tier-2 |
| PS-3.1 | Alım vade ekseni | B-150 cevabı bekliyor (muhasebe) |
| PS-5.3 | Vergi karşılığı görünümü | plan-38 içinde |
| PS-5.4 | Banka mutabakatı | plan-38 içinde |
| PS-6.1 | Pozisyon maliyet-katkı ekranı | plan-39 içinde (+ B-161 maskeleme) |
| PS-6.4 | Birim kargo maliyet trendi | Tier-2 |

## Güncelleme disiplini

1. Bir boşluk kapatıldığında (ekran/veri geldi) **önce bu belge**, sonra `PatronSorulariRegistry.cs` güncellenir.
2. Rozet değişikliği kanıtsız yapılmaz — hangi sayfada hangi kartın karşıladığı yazılır.
3. Registry'de bu belgede olmayan soru bulunmaz; sayım her zaman 25.
4. Bu belge bayatlarsa panel yalan söyler ("veri yok" derken ekran yapılmış olur) — plan-37 risk tablosundaki birinci risk budur.

## İlişkili
- `plans/37-patron-sorulari-paneli.md` — paneli üreten plan
- `.claude/skills/{satis,satinalma,operasyon,finans-nakit,ik,bt-risk}-danisman/SKILL.md` — 6 departman danışmanı
- `TODO.md` B-150 (iade/vade kodu) · B-161 (maaş maskeleme)
