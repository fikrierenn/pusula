# BKM Kitap — SQL Sorgu Arşivi

**Konum:** `D:\Dev\sqlserver-mcp-server\sorgular\`
**Kaynak:** ODAKJOKER.JOKER linked server
**Güncellendi:** 14 Nisan 2026 · Fikri Eren

---

## Klasör disiplini

Her analiz/rapor için ayrı `.sql` dosyası. Dosya adı **tarih + analiz-adı** kalıbıyla: `YYYY-MM-DD-<analiz-adi>.sql`. Böylece kronolojik sıralama + arama kolaylığı aynı anda sağlanıyor.

---

## Sorgu standartları (değişmez kurallar)

1. **Tarih formatı:** Linked server çağrılarında tarih literalleri `YYYYMMDD` ISO formatında (örn `'20260406'`). Yerel DMY formatı (`'06.04.2026'`) sessiz yanlış eşleşme yapıyor — kullanma.
2. **Hafta tanımı:** ISO Pzt–Paz. `DATEDIFF(DAY, '<Pzt-baseline>', tarih) / 7` yaklaşımı — DATEFIRST bağımsız.
3. **Müşteri eşlemesi:** `J_ORDERS.CLIENTREF → J_ORDER_CLIENTS.LOGICALREF → CUSTOMERREF`. **J_CLCARD ile birebir aynı sonucu veriyor**, ikisi de senkron ama kurumsal standart J_ORDER_CLIENTS.
4. **Ürün eşlemesi:** `J_ORDER_DETAILS.ITEMREF = J_ITEMS.LOGICALREF` (referans-key, %100 eşleşme). Eski `BARCODE = CODE` string-join yanlış — kullanma.
5. **Kanonik barkod:** `J_ITEMSBARCODE` (866K barkod / 842K ürün). Alternate-ISBN senaryolarında devreye girer; normal satışta ITEMREF zaten kapsıyor.
6. **Kategori:** `J_ITEMS.GROUPCODE` ve `DERINSIS_LOGOGRUP` (%99,3 dolu). `ANAKATEGORI` %33 dolu — kullanma.
7. **Kanal:** `J_ORDERS.APPLICATION` değerleri: `'Mobil Uygulama (Android)'`, `'Mobil Uygulama (iOS)'`, `'Mobil Site'`, `'Web Sitesi'`.
8. **Sipariş durum:** `J_ORDER_STATUS` üzerinden 1006/1007 kodları iptal/iade.

---

## Dosya dizini

| Dosya | İçerik | Tarih |
|---|---|---|
| `2026-04-14-mobil-app-baremli-rapor.sql` | Mobil App kullanım baremleri (sıklık, sepet, 15 haftalık seyir) | 14 Nis 2026 |
| `00-README.md` | Bu dosya · standartlar + dizin | — |

---

## Açık arşiv işleri

Önceki oturumda (E-ticaret Trend Raporu H15) çalıştırılan sorgular henüz arşivlenmedi: haftalık ciro/adet (15 hafta ISO), günlük nabız, Top 20 organik, kanal kırılımı, kategori, yayınevi, sipariş durum, Echo of Silence forensic, YoY 2025 karşılaştırma, J_ITEMSBARCODE keşif. Raporun metodoloji bölümünde özetli ama tam SQL'leri ayrı dosyalara çıkartılacak.
