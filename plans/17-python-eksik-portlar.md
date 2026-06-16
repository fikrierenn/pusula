# Plan-17 — Python Dashboard Eksik Özellik Portları (Blazor)

**Tarih:** 16.06.2026
**Tier:** 3 (çok-katman drill, yeni sorgu+model+UI, 5 özellik)
**Kaynak:** Eski `scripts/gm_dashboard.py` (silindi, git `1a6fb1a~1`). Gap analizi 16.06 (agent).
**Kapsam:** #3 (FSM dönüşüm) HARİÇ kullanıcı kararı. Kalan 5: fiş drill (#1+#2), lokasyon filtresi (#4), saat×ciro ikiz-eksen (#5), kavram sözlüğü (#6).

---

## WP-1: Müşteri → Fiş Listesi → Fiş İçeriği Drill (Katman 3+4) — EN KRİTİK

Python kaynak SQL (git 1a6fb1a~1):
- **HAR_YK** (yazarkasa müşteri→fiş): `Sales` by CustomersId → tarih, Id, kalem#, tutar. KDV-hariç: `GrossTotal-DiscountTotal-VatTotal`.
- **HAR_ET** (e-tic müşteri→sipariş): `J_ORDERS` by CUSTOMERREF → tarih, ORDERID, ORDERCODE, tutar. Direkt JOKER + detay `SELLINGPRICEWITHOUTVAT` (KDV+kargo-hariç).
- **FIS_YK** (fiş içeriği): `SalesProducts` by SalesId → ad/adet/birim/net. KDV-hariç (`TotalPrice-VatTotal`), IsValid=1, barkod≠1001.
- **FIS_ET** (sipariş içeriği): `J_ORDER_DETAILS` by ORDERREF → ad/adet/birim/net. `SELLINGPRICEWITHOUTVAT`.

Yapı:
- Model: `FisRow(Tarih, Ref, Kalem, Tutar)`, `FisIcerikRow(Ad, Adet, Birim, Net)`.
- `RefQueries.GetFislerAsync(kanal, id)` + `GetFisIcerikAsync(kanal, ref)`. ET = OpenJokerAsync (direkt).
- `Musteri.razor` modal: müşteri satırı tıkla → fiş listesi → fiş tıkla → içerik. Çok-katman modal navigasyon (geri butonu).
- İç-kart işaretle butonu korunur (mevcut Details).

## WP-2: Çoklu Lokasyon Envanter Filtresi (#4)

Python: 5 lokasyon (FSM 1 / Özlüce 4477 / İst.Yolu 4478 / Ana Depo 12 / ODAK) bağımsız toggle → envanter değeri + devir + ürün listesi seçili kombinasyona göre. SEL bitmask.
- `Envanter.razor`: lokasyon checkbox grubu → seçili mekan IN-list → RefQueries.GetInventoryAsync + GetUrunlerAsync mekan param (zaten var: `mekanId`; çoklu için `int[] mekanlar`).
- Ürün satış/ciro = seçili şubeler; stok = şubeler + Ana Depo (ODAK hariç) — Python `urunler_query_sql` mantığı.

## WP-3: Saat × Ciro İkiz-Eksen Grafik (#5)

Python: saat bazlı bar(Fiş) + line(Net ₺) çift eksen. Blazor'da sadece fiş var.
- `Operasyon.razor` saat yoğunluk grafiğine ikinci eksen (Net ₺ line). Sorgu zaten saat+net döndürüyor (HourBar.Net var) — sadece grafik ikinci seri.

## WP-4: Kavram Sözlüğü Paneli (#6)

Python: `<details>` açılır — Dönüşüm/SPLH/RFM/Devir/WoS/ABC/UPT açıklamaları. Statik metin.
- Ortak component `AppSozluk` veya Home/ilgili sayfa altına `<details>` accordion. Düşük efor.

---

## Sıra
WP-1 (fiş drill, en değerli) → WP-2 (lokasyon filtresi) → WP-3 (ikiz-eksen) → WP-4 (sözlük). Her WP build+smoke+commit.

## KDV Notu
Tüm tutarlar KDV-hariç (plan-16 tutarlı). Fiş içeriği net = KDV-hariç → fiş toplamı = müşteri Monetary (KDV-hariç) ile uyumlu. Birim = net/adet.

## Done Criteria
- [ ] Müşteri tıkla → fiş listesi → fiş tıkla → içerik (YK+ET), KDV-hariç, geri navigasyon
- [ ] Envanter lokasyon checkbox → değer/devir/ürün filtreli
- [ ] Operasyon saat grafiği fiş+ciro ikiz eksen
- [ ] Kavram sözlüğü accordion
- [ ] Her WP build+smoke; iç-kart butonu korunur

## Rollback
WP başına commit. Sorun → ilgili WP revert. Mevcut sayfalar dokunulan yer dışında etkilenmez.
