# 05 — E-ticaret (ODAKJOKER.JOKER Linked Server)

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)

BKM Kitap online satışı JOKER platformunda. `sqlserver` üzerinden `ODAKJOKER.JOKER` linked server ile erişim. Sorgu örnekleri: [`../sorgular/00-README.md`](../sorgular/00-README.md)

---

## Kritik Standartlar — DEĞİŞMEZ

1. **Tarih literali:** `YYYYMMDD` ISO (örn `'20260406'`). Linked server'da DMY sessiz yanlış eşleşme yapıyor. Yerel ERP sorgularında DMY zorunluluğu devam eder.
2. **Müşteri eşlemesi:** `J_ORDERS.CLIENTREF → J_ORDER_CLIENTS.LOGICALREF → CUSTOMERREF`. **`J_ORDER_CLIENTS` kurumsal standart — `J_CLCARD` DEĞİL.** İkisi birebir senkron (13,26 M satır) ama J_ORDER_CLIENTS kullan.
3. **CLIENTREF tek başına müşteri sayımı için kullanma** — her sipariş yeni cari doğurabiliyor. Unique için `CUSTOMERREF` + `CUSTOMERREF > 0` (0/NULL = misafir).
4. **Ürün eşlemesi:** `J_ORDER_DETAILS.ITEMREF = J_ITEMS.LOGICALREF` (%100). Eski `BARCODE = CODE` string-join yanlış.
5. **Kanonik barkod:** `J_ITEMSBARCODE` (866K barkod / 842K ürün).
6. **Kategori:** `J_ITEMS.GROUPCODE` veya `DERINSIS_LOGOGRUP` (%99,3 dolu). `ANAKATEGORI` %33 — kullanma.
7. **Kanal:** `J_ORDERS.APPLICATION` ∈ `'Mobil Uygulama (Android)'`, `'Mobil Uygulama (iOS)'`, `'Mobil Site'`, `'Web Sitesi'`.
8. **İptal/iade:** `J_ORDER_STATUS` — 1006/1007.
9. **Hafta (ISO Pzt-Paz):** `DATEDIFF(DAY, '20251229', CAST(ORDERDATE AS date))/7 + 1`. Baseline 2025-12-29 Pzt = 2026 H01.

## Temel Tablolar

- `J_ORDERS` — Sipariş başlık (LOGICALREF, ORDERCODE, ORDERDATE, CLIENTREF, APPLICATION, TOTALPRICE, STATUS)
- `J_ORDER_DETAILS` — Sipariş satır (ITEMREF, QUANTITY, SELLINGPRICE, IPTALNO)
- `J_ORDER_CLIENTS` — **Master müşteri (STANDART)** (LOGICALREF, CUSTOMERREF, CMAIL, CPHONE, CCITY, CTOWN)
- `J_CLCARD` — J_ORDER_CLIENTS senkronu (kullanma)
- `J_ITEMS` — Ürün master (LOGICALREF, CODE, NAME, GROUPCODE, DERINSIS_LOGOGRUP)
- `J_ITEMSBARCODE` — Kanonik barkod eşlemesi
- `J_ORDER_STATUS` — Durum geçmişi
- `J_ORDER_DELIVERY_ADDRESS` — Teslimat (DPHONE; şehir kolon adları henüz teyit değil)

## H15 Önemli Bulgular (6–12 Nis 2026)

- 18.459 sipariş · 78.503 adet · 17,13 M ₺ ciro · ort sepet 938 ₺
- Kanal: Mobil Site %43 · **App %41,6 (Android 4.805 + iOS 2.867) → ciro %49,7** · Web %15
- App ort sepet **1.110 ₺** (Mobil Site 890 ₺ · +%25)
- iOS premium: 5000+ ₺ sepet diliminde iOS payı %53 (genelde %37)
- 90 gün App frekans: 79K tek-sipariş (%76) · 22K 2-3 (%21) · 362 kişi 7+ sipariş (süper kullanıcı 52)
- **Echo of Silence vakası:** "Senin Sessizliğin" (İkinci Adam Yay.) H15 Top 1, 50+ adet tek-siparişler, manipülasyon şüphesi.
- **YoY:** H15 sipariş −%25,8, adet −%21,2, ciro +%1,5 (enflasyon korumalı hacim daralması)

## 2026-06 Keşif — Sipariş Satır, Marka, Ödeme, Kargo, COD (KESİN)

- **Sipariş satır köprüsü:** `J_ORDER_DETAILS.ORDERREF = J_ORDERS.ORDERID` (**LOGICALREF DEĞİL** — ORDERID = "TS…" kodundaki sayı). Birim fiyat: `SELLINGPRICE` = birim NET, `SELLINGPRICEWITHOUTDISCOUNT` = birim brüt/liste. Satır net = `QUANTITY×SELLINGPRICE`; indirim = `QUANTITY×(WITHOUTDISCOUNT−SELLINGPRICE)`.
- **Marka/yayınevi:** `J_ITEMS.BRAND` (direkt — ayrı join gerekmez). DerinSIS kategori köprüsü: **`J_ITEMS.DERINSIS_ID = DerinSISBkm.urn.stkID`**.
- **Ödeme tipi:** `J_ORDER_PAY_TYPES` — `ID` (join: `PAYDEFREF = ID`, LOGICALREF değil), `NAME`. **Kapıda Ödeme ID=−3, iyzico ID=−13** (tüm online kart iyzico'da, %94), Havale/EFT=−1.
- **Kargo firma:** `J_CARGO` — `ID` (join: `CARGOREF = ID`), `CNAME`, `KAPIDAODEME` (bit). Firmalar: HEPSIJET, MNG, PTT KARGO, KARGOIST, Bir Günde Kargo.
- **Kargo durumu:** `J_ORDER_CARGO_STATUS` — `STATUS` (0=İşlem görmemiş,1=TESLİM EDİLDİ,2=İADE GELDİ,3=KAYIP,4=HAREKET GÖRÜYOR). Join: `cs.STATUS = o.CARGODELIVERYSTATUS`.
- **Teslimat ili:** `J_ORDERS.DELIVERYREF = J_ORDER_DELIVERY_ADDRESS.LOGICALREF` (ORDERCODE kolonu BOŞ) → `DCITY` (il, temiz "İstanbul"), `DTOWN` (ilçe).
- **Hediye çeki:** `J_ORDERS.VOUCHERCODE` dolu = kullanılmış; sistemde **satır indirimi** olarak yansır (SELLINGPRICE düşer; "1₺ kitap" çoğu bu).
- **Tutarlar:** `CARGOPRICE` ~81-90₺ müşteri kargo. `SERVICEPRICE` **çift anlamlı — `PAYDEFREF`'e göre okunur** (aşağıdaki bölüm).

### SERVICEPRICE = COD bedeli DEĞİL, kartta VADE FARKI (17.07.2026 keşif — KESİN)

`SERVICEPRICE` tek kolon, iki farklı şey taşıyor:

| `PAYDEFREF` | `SERVICEPRICE` anlamı | Haz+Tem 2026 |
|---|---|---|
| **−3** (Kapıda Ödeme) | COD hizmet bedeli | 8.167/8.167 dolu (%100) · 693.378 ₺ |
| **−13** (iyzico/kart) | **VADE FARKI** | 4.266/135.803 dolu (%3,1) · **981.754 ₺** |
| −1 (Havale/EFT) | — | 0 |

- **Kart tarafındaki tutar COD DEĞİL.** JOKER API'de iki alan ayrı: vade farkı = `Payment.LateChargeAmount`, kapıda ödeme = `Shipment.CashOnDeliveryAmount` (kart siparişlerinde 0). DB ikisini de `SERVICEPRICE`'a yazıyor. Ciro/maliyet raporunda ayrılmazsa vade farkı COD sanılır → yanlış sınıflama (kart tarafı COD'un üstünde, küçük kalem değil).
- **Tutar kimliği:** `TOTALPRICE = SUM(D.QUANTITY×D.SELLINGPRICE) + CARGOPRICE + SERVICEPRICE` — kuruşu kuruşuna kapanır (JOKER API ile 12 sipariş karşılaştırıldı).
- **Vade farkı tarifesi** (sabit oran, sepet büyüklüğünden bağımsız; taban = satır toplamı + `CARGOPRICE` − `VOUCHERVALUE`): **%10,44 · %13,52 · %16,29 · %19,62 · %31,14 · %38,33**. Tem-2026'da 1.331 sipariş bu 6 kademede. Kanıt: %38,33 kademesinde sepet 390 ₺ ile 2.356 ₺ aynı oranı veriyor (6 kat fark, oran sabit).
- ⚠ **Taksit sayısı hiçbir yerde yazılı değil.** JOKER'de taksit kolonu YOK (tüm DB taraması: `TAKSIT`/`INSTALLMENT`/`VADE`/`KOMISYON` → 0 eşleşme). API'nin `Payment.InstallmentCount` alanı beslenmiyor — vade farkı dolu siparişte bile `1` dönüyor. `BANK` (%94 boş), `TRANSACTIONID`, `ROUND`, `FIRM`, `ISLEM_ACIKLAMA` de boş. **Kademe→taksit eşlemesi iyzico panelinden doğrulanmayı bekliyor** (her kademeden örnek sipariş: `sorgular/2026-07-17-joker-vade-farki.sql`).
- Yanlış izler: `b2c.ayar.vadeFarkiStkID = 0` (tanımsız + entegrasyon 2018'den ölü). `urn` stkID 303636 "Vade Farkları" (`G-760.30.027`) = **gider** carisi ürünü (BKM'nin ödediği), müşteri satırı değil.

### COD (Kapıda Ödeme) ekonomisi
- COD = `PAYDEFREF=−3`. **SERVICEPRICE pass-through** (firmaya ödenir, kâr DEĞİL).
- Teslim: müşteri kargo + kapıda bedeli öder. İade (teslim edilmeyen): tahsilat yok, **2× kargo (götürme+geri getirme) BKM yutar** = gerçek COD maliyeti.
- COD iade ~%9-10 (online ~%0,5) — **coğrafya kaynaklı** (Doğu/GD %15-21, Batı %3-6), firma değil (İstanbul-içi PTT≈HEPSIJET). PTT/MNG her yere gider → genel oranı yüksek görünür.
- Rapor: `scripts/kapida_odeme_analiz.py` → `briefings/kapida-odeme-analiz.xlsx`.

## Rapor Çıktıları (root'ta)

- `BKM-Eticaret-Trend-Raporu.md/.html` — H15 tam rapor (13 bölüm + Grok harmanı §10b)
- `BKM-Eticaret-Yonetim-Sunumu.html` — Reveal.js yönetim sunumu
- `BKM-Mobil-App-Baremli-Rapor.md/.html` — App sıklık + sepet + 15 haftalık seyir
- `Grok-Sosyal-Dinleme-Raporu.md` — X/Twitter sosyal dinleme
- `BKM-Kitap-Trend-Endeksi-Sistem-Tasarimi.md` — trend endeksi sistem tasarımı
- `BKM-Pilot-Trend-Raporu.md` — pilot rapor

## Sorgu Arşivi Disiplini

- Format: `sorgular/YYYY-MM-DD-<analiz>.sql`
- Standartlar: [`../sorgular/00-README.md`](../sorgular/00-README.md)
- Kaydedilen: `2026-04-14-mobil-app-baremli-rapor.sql`
- **Açık iş:** H15 trend sorguları (haftalık ciro/adet, günlük nabız, Top 20, kanal, kategori, yayınevi, sipariş durum, Echo of Silence, YoY 2025, J_ITEMSBARCODE keşfi) henüz arşivlenmedi.
