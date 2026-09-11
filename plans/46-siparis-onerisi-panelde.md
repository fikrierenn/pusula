# plan-46 — Sipariş Önerisi Panelde (hesap çekirdeği C#'a)

> **Durum:** onaylandı (kullanıcı: *"plan yaz ve panele ekle"*, 11.09.2026) · **Tier 3**
> (3+ dosya · kullanıcı-görünür · yeni KPI kartı + liste kolonu + filtre)

## 1. Problem

Sipariş miktarı hesabı bugün **yalnız Python'da** (`scripts/siparis_onerisi_excel.py`).
Panel (`/satis-analizi`) neyin eksik olduğunu gösteriyor ama **ne kadar sipariş verileceğini
göstermiyor**. Kullanıcı 10-11.09'da bu hesabı üç kez düzeltti (kohort · sezon hızı · yıl
oranı) ve hepsi Excel tarafında kaldı; panelde karşılığı yok → aynı soru panelde sorulduğunda
cevap yok, Excel'i ayrıca koşmak gerekiyor.

TODO **B-171(a)** bunu "hesap koda girmedi" diye açık tutuyor.

## 2. Kapsam

**YAPILACAK**
1. `SatisAnaliziQueries.Siparis.cs` (yeni partial) — sipariş çekirdeği SQL sabitleri:
   kapak · sezon penceresi · kategori yıl oranı · emniyet · tavan · öneri.
2. KPI: **Sipariş İhtiyacı** kartı (çeşit + maliyet) + karşı-metrik **ACİL — rafta yok**.
   Yeni grup başlığı: `SATINALMA`.
3. Liste kolonları (kolon seçicide, varsayılan kapalı): `Kapak` · `Öneri adet` · `Hız tabanı`.
4. Durum filtresi: **Sipariş ihtiyacı** · **Sipariş — ACİL**.
5. Excel emitter (`SatisAnaliziQueries.Excel.cs`) aynı kolonları taşır (biçim tek yerde:
   `SatisAnaliziHucre`).
6. Python emitter'ı **aynı ölçüte** hizala (kohort = öneri > 0).

**YAPILMAYACAK (bu planda)**
- Tedarikçi kolonu panelde → alım köprüsü (`irs`/`frm`) 275K satırlık listede pahalı; Excel
  emitter'ında ZATEN var (4. sayfa TEDARİKÇİ ÖZET). Panelde istenirse ayrı iş, **ölçülerek**.
- SBA/TSB tahmini (B-171(a)'nın kalan yarısı) — 365g/sezon hızı vekil kalır.
- Sipariş YAZMA. Panel salt-okur; ERP'ye sipariş yazılmaz (`erp-write-policy`).

## 3. Hesap (tek tanım — Python ile BİREBİR aynı olmak zorunda)

```
win          = LeadTime + 30                       (gözden geçirme aralığı 30 gün)
düz kapak    = (Satis365 / 365) × win
sezon talebi = (Ay1×fAğu + Ay2×fEyl + Ay3×fEki) × kategoriOranı
               f = pencerenin o aya düşen gün payı; pencere [kesim, kesim+win)
kapak        = max(düz kapak, sezon talebi)
emniyet      = z × √(CV² / SatanAy) × kapak,  tavan: kapak (düz) · 0,25×kapak (sezon)
öneri        = ceil(kapak + emniyet − ToplamStok),  ≥ 0
tavan        = kategoriEşiği × SezonToplam − ToplamStok   (Kırtasiye 2× · diğer 3×)
z            = 1,65 (Kırtasiye/Elektronik) · 1,04 (diğer)
KOHORT       = öneri > 0  (tek tanım; "stok = 0" DEĞİL)
```

**Neden böyle — üçü de ölçüldü (11.09.2026):**
- Kohort `ToplamStok = 0` iken gerçek ihtiyacın **~1/13'ünü** görüyordu (Kırtasiye: 796 vs
  1.687 çeşit / 14.528 adet).
- Düz 365g hızı sezon ürününde talebi **4 kat** az sayıyordu (285 çeşit, 50 günlük pencere:
  7.257 vs 29.057 adet; zirve **eylül**, `Satis365` penceresi onu dışarıda bırakıyor).
  Bağımsız doğrulama: Maxx Mx-616 → Eyl-2025 **1.617** · Eki-2025 20 · son365 **484**.
- "Geçen yıl kadar al" varsayımı ölçüldü: bu yıl/geçen yıl aynı pencere **Kırtasiye 0,82** ·
  Oyuncak 1,50 · Hediyelik 1,25 · Elektronik 0,88 → Kırtasiye'de birebir almak %18 fazla.
- Sezon sonunda emniyet TERS çalışır (fazlanın bedeli ölü stok) → %25 tavan.

## 4. Alternatifler (reddedildi)

| Alternatif | Neden reddedildi |
|---|---|
| **Python'u panelden çağır** (subprocess / ara tablo) | İki çalışma zamanı, iki hata yolu; panel isteği 5-10 s bekler. Hesap zaten saf aritmetik — SQL'de kalması doğal. |
| **Hesabı tabana yaz** (`SatisAnaliziTaban`'a Oneri kolonu) | Öneri **kesim tarihine ve o günkü pencereye** bağlı; tabana yazılırsa bayatlar ve "taban ne zaman kuruldu" sorusu rakamı belirsizleştirir. Taban ham ölçüm tutar, türev tutmaz. |
| **Ayrı "Sipariş" sayfası** | footprint-ladder: mevcut panel zaten kohort + liste + Excel taşıyor; yeni sayfa 6. basamak. Kart + kolon + filtre 1. basamak. |
| **Tedarikçi kolonunu da panele koy** | `irsHrk→irs→frm` join'i liste sorgusunda ölçülmeden eklenemez; Excel'de var. Ayrı iş. |

## 5. Riskler

| Risk | Karşılık |
|---|---|
| **İki emitter ayrışır** (Python ≠ panel) | Aynı formül; Python bu planda hizalanır. `sema/metrics.yaml → siparis_onerisi` tek tanım. İleride `panel_kolon_denetimi.py` kardeşi bir "formül dumanı" eklenebilir (TODO). |
| Kategori oranı sorgusu yavaşlatır | `irsHrk` 2 pencere × ~40 gün, `Kategori3` GROUP BY. **Ölçülecek**; 300 ms'yi aşarsa `IMemoryCache` (kesim başına) — panelde zaten cache altyapısı var. |
| Sezon dışı dönemde (Kas-Tem) sezon terimi 0 olur | Doğru davranış: pencere sezon aylarına değmiyorsa düz hız kalır. Ay1/Ay2/Ay3 yalnız Ağu/Eyl/Eki. |
| Öneri rakamı "emir" sanılır | Kart alt metni + kapsam bandı: **öneri, sipariş DEĞİL**; MOQ/koli yok, iade hakkı bilinmiyor, talep ALT SINIR. |

## 6. Adımlar

1. `SatisAnaliziQueries.Siparis.cs` — SQL sabitleri + `SiparisOran` ölçümü (cache'li).
2. `GetOzetAsync`'e 5 agrega (çeşit · adet · maliyet · ACİL çeşit/adet) + `SatisAnaliziKpi`.
3. `SatisAnaliziModels` — `SatisDurumFiltre.SiparisIhtiyaci` / `SiparisAcil` + 3 kolon tanımı.
4. `SatisAnaliziQueries.Liste.cs` — kolonlar SELECT'e (Dapper **POZİSYONEL SIRA**!) + filtre.
5. `SatisAnaliziHucre` — 3 kolonun değeri + ekran biçimi (tek yer).
6. `SatisAnalizi.razor` — SATINALMA grubu + kart + kapsam bandına iki satır.
7. Python emitter'ı kohort = öneri > 0'a hizala.
8. `sema/metrics.yaml` → `siparis_onerisi` + `sezon_penceresi_hizi` + `sezon_yil_orani`.

## 7. Done kriteri

- `dotnet build` 0 hata · `python tools/panel_kolon_denetimi.py` 0 kırık.
- Panelde kart görünür; tıklayınca liste o kohorta filtrelenir ve **çeşit sayısı karta eşit**.
- Panel kitapdışı öneri toplamı, Excel emitter'ının aynı kesimdeki toplamıyla **%1 içinde**
  (cross-source sweep; fark varsa sebebi yazılır).
- 375px taşma 0.

## 8. Rollback

Tek commit; `git revert`. Taban şeması DEĞİŞMİYOR (yeni kolon yok) → geri alma veri
taşımıyor, risk yok.
