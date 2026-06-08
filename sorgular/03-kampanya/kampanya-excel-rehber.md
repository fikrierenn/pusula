# 📊 Kampanya Master Excel — Kurulum Rehberi (TEK SORGU versiyonu)

**Tarih:** 11.05.2026
**Veri kaynağı:** [`kampanya-master-tek-sorgu.sql`](kampanya-master-tek-sorgu.sql)

> **Yenilik:** Artık 4 sorgu + DÜŞEYARA değil — TEK sorguyla 35 kolonlu master tablo, doğrudan Excel'e yapıştırılır. Segment kolonu (A_SafStokTahliyesi, B_BuyukKazanc, ...) SQL içinde hesaplanır.

---

## ✅ Adım 1 — SSMS'te SQL'i Çalıştır

1. SSMS'te `kampanya-master-tek-sorgu.sql` dosyasını aç.
2. Tüm scripti seç (Ctrl+A) → F5 (çalıştırma süresi: 30-90 sn).
3. Son SELECT result olarak gelir (~15.000 satır × 35 kolon).
4. Result grid'i seç (Ctrl+A) → sağ tık → **"Copy with Headers"**.
5. Excel'de `Urun_Master` sheet'inin A1 hücresine yapıştır.

> **SSMS Ayarı:** Tools → Options → Query Results → Results to Grid → "Include column headers when copying" işaretli olmalı.
> **Yetki:** Temp table (CREATE) yetkisi gerekli — varsayılan kullanıcı için açık olmalı.

## ✅ Adım 2 — Excel Sheet Yapısı

| # | Sheet | İçerik |
|---|---|---|
| 1 | `Parametreler` | Tarih + filtre referansı |
| 2 | `Urun_Master` | **SQL sonucu yapıştırılır** (35 kolon, ~15K satır) |
| 3 | `Segment_Ozet` | A-F segment dağılımı (ÇOKETOPLA) |
| 4 | `Yayinevi_Ozet` | Yayınevi bazlı performans |
| 5 | `Kategori_Ozet` | Kategori bazlı (4 kategori) |
| 6 | `Yazar_Ozet` | Yazar bazlı (top N) |
| 7 | `Top_StokTahliyesi` | EkstraCiro azalan |
| 8 | `Top_MarjErozyonu` | EkstraAdet artan (en negatif) |
| 9 | `Dashboard` | KPI özet |

## ✅ Adım 3 — `Parametreler` Sheet

| A | B |
|---|---|
| **Parametre** | **Değer** |
| Kampanya Başlangıç | 07.05.2026 |
| Kampanya Bitiş (dahil) | 10.05.2026 |
| Kampanya Gün Sayısı | 4 |
| Yıllık Baseline Başlangıç | 07.05.2025 |
| Yıllık Baseline Bitiş | 07.05.2026 |
| Yıllık Gün Sayısı | 365 |
| Mağazalar | FSM (1), Özlüce (4477), İst.Yolu (4478) |
| Kategoriler | Kitap, Çocuk Kitabı, Akademi, Hazırlık Kitapları |
| İndirim Oranı (varsayım) | %50 |
| Multiplier Eşik (kar) | 2.00 |
| Yeni Satış Eşik (kar) | %50 |

## ✅ Adım 4 — `Urun_Master` Kolon Haritası (35 kolon)

Tüm kolonlar SQL'den hazır gelir, **hiç formül yok**.

| Kolon | Alan | Açıklama |
|---|---|---|
| A | stkID | Ürün ID |
| B | stkAd | Ürün adı |
| C | Yayinevi | mrkAd |
| D | Yazar | Yazar adı |
| E | Kategori | Kategori3 |
| F | Reyon | ReyonAd |
| G | KampAdet | 4 günlük net adet |
| H | KampTutar | 4 günlük net tutar |
| I-L | Ad_07-10 | Günlük adet (4 gün) |
| M-O | Ad_FSM/Ozluce/IstYolu | Mağaza bazlı adet |
| P | BirimSatisFiyat | KampTutar / KampAdet |
| Q | YilAdet | 365 günlük net adet |
| R | YilTutar | 365 günlük net tutar |
| S | BeklenenAdet | YilAdet × 4/365 |
| T | EkstraAdet | KampAdet − BeklenenAdet |
| U | **EkstraCiro** | EkstraAdet × BirimSatisFiyat |
| V | **Multiplier** | KampAdet / BeklenenAdet (yıllık 0 ise NULL) |
| W | **Segment** | A_SafStokTahliyesi / B_BuyukKazanc / C_OrtaKazanc / D_SinirToreni / E_KismiKayip / F_BuyukKayip |
| X-AB | Stok_FSM/Ozluce/IstYolu/MerkezDepo/Toplam | Güncel stok |
| AC-AF | StokOnceKamp_* | Kampanya öncesi stok (mağaza + toplam) |
| AG | SonAlisTarih | Son alış faturası tarihi |
| AH | SonAlisAdet | Son alış adedi |
| AI | GunSayisiAlisBeri | Bugünden kaç gün önce |

### Segment Mantığı (W kolonu)

| Segment | Koşul | Anlamı |
|---|---|---|
| **A_SafStokTahliyesi** | YilAdet = 0 | Yıl boyu hiç satmadı, kampanyada sattık → %100 yeni |
| **B_BuyukKazanc** | KampAdet ≥ 5×Beklenen | Multiplier 5+ — büyük kazanç |
| **C_OrtaKazanc** | KampAdet ≥ 2×Beklenen | Multiplier 2-5 — eşiği geçti, kazanç |
| **D_SinirToreni** | KampAdet ≥ 1.5×Beklenen | Sınırda — %50 indirimde zar zor |
| **E_KismiKayip** | KampAdet ≥ Beklenen | Yıllık seviyede satıyor — indirim kaybı |
| **F_BuyukKayip** | KampAdet < Beklenen | Beklenenden bile az sattı → ürün stok/kapsama sorunu |

## ✅ Adım 5 — `Segment_Ozet` Sheet

### Header (A1:F1)
```
Segment | UrunSayisi | KampAdet | KampTutar | EkstraAdet | YeniSatisYuzde
```

### A kolonu — 6 segment elle yaz (alfabetik sırala)
```
A_SafStokTahliyesi
B_BuyukKazanc
C_OrtaKazanc
D_SinirToreni
E_KismiKayip
F_BuyukKayip
```

### Formüller (A2 = "A_SafStokTahliyesi" satırı)
```excel
B2: =ÇOKEĞERSAY(Urun_Master!W:W;A2)
C2: =ÇOKETOPLA(Urun_Master!G:G;Urun_Master!W:W;A2)
D2: =ÇOKETOPLA(Urun_Master!H:H;Urun_Master!W:W;A2)
E2: =ÇOKETOPLA(Urun_Master!T:T;Urun_Master!W:W;A2)
F2: =EĞERHATA(E2/C2*100;0)
```

B2:F2'yi seç → kopyala → B3:F7 aralığına yapıştır.

## ✅ Adım 6 — `Yayinevi_Ozet` Sheet

### Header (A1:I1)
```
Yayinevi | UrunCesidi | KampAdet | KampTutar | YilTutar | EkstraAdet | YeniSatisYuzde | Multiplier | Hukum
```

### A kolonu nasıl doldurulur

- **Excel 365:** `A2: =SIRALA(BENZERSİZ(Urun_Master!C2:C15001))` (dinamik dizi)
- **Klasik Excel:** Urun_Master!C kolonunu kopyala → Veri → "Yinelenenleri Kaldır" → buraya yapıştır

### Formüller (A2 yayınevi adı yapıştırıldıysa, B2:I2)
```excel
B2: =ÇOKEĞERSAY(Urun_Master!C:C;A2)
C2: =ÇOKETOPLA(Urun_Master!G:G;Urun_Master!C:C;A2)
D2: =ÇOKETOPLA(Urun_Master!H:H;Urun_Master!C:C;A2)
E2: =ÇOKETOPLA(Urun_Master!R:R;Urun_Master!C:C;A2)
F2: =ÇOKETOPLA(Urun_Master!T:T;Urun_Master!C:C;A2)
G2: =EĞERHATA(F2/C2*100;0)
H2: =EĞERHATA(C2/ÇOKETOPLA(Urun_Master!S:S;Urun_Master!C:C;A2);"")
I2: =EĞER(H2="";"YENI";EĞER(H2>=2;"KAZANDI";EĞER(H2>=1.5;"SINIRDA";"KAYBETTI")))
```

D kolonuna göre azalan sırala (KampTutar).

## ✅ Adım 7 — `Kategori_Ozet` Sheet

A kolonuna 4 kategoriyi elle yaz: `Kitap`, `Çocuk Kitabı`, `Akademi`, `Hazırlık Kitapları`.

```excel
B2: =ÇOKEĞERSAY(Urun_Master!E:E;A2)
C2: =ÇOKETOPLA(Urun_Master!G:G;Urun_Master!E:E;A2)
D2: =ÇOKETOPLA(Urun_Master!H:H;Urun_Master!E:E;A2)
E2: =ÇOKETOPLA(Urun_Master!R:R;Urun_Master!E:E;A2)
F2: =ÇOKETOPLA(Urun_Master!T:T;Urun_Master!E:E;A2)
G2: =F2/C2*100
H2: =EĞERHATA(C2/ÇOKETOPLA(Urun_Master!S:S;Urun_Master!E:E;A2);"")
```

## ✅ Adım 8 — `Top_StokTahliyesi` Sheet (Excel 365)

```excel
A1: =SIRALA(FİLTRE(Urun_Master!A2:AI15001;Urun_Master!U2:U15001>0);21;-1)
```

> 21. kolon = U (EkstraCiro), `-1` = azalan. En çok ekstra ciro getiren ürünler.

**Klasik Excel için:** Urun_Master'da EkstraCiro (U) sütununa göre azalan sırala, top 50'yi kopyala.

## ✅ Adım 9 — `Top_MarjErozyonu` Sheet (Excel 365)

```excel
A1: =SIRALA(FİLTRE(Urun_Master!A2:AI15001;Urun_Master!W2:W15001="F_BuyukKayip");20;1)
```

> Sadece F_BuyukKayip segment, 20. kolon = T (EkstraAdet), `1` = artan (en negatifler önce).

## ✅ Adım 10 — `Dashboard` Sheet

| A (KPI) | B (Formül) |
|---|---|
| Kampanya Ürün Çeşit | `=BAĞ_DEĞ_DOLU_SAY(Urun_Master!A2:A15001)` |
| Kampanya Net Adet | `=TOPLA(Urun_Master!G:G)` |
| Kampanya Net Tutar | `=TOPLA(Urun_Master!H:H)` |
| Günlük Ortalama Tutar | `=B3/4` |
| Beklenen Baseline Adet (4 gün) | `=TOPLA(Urun_Master!S:S)` |
| Ekstra Adet (kampanyaya borçlu) | `=TOPLA(Urun_Master!T:T)` |
| Ekstra Ciro (kampanyaya borçlu) | `=TOPLA(Urun_Master!U:U)` |
| **Genel Multiplier** | `=B2/B5` |
| **Yeni Satış Yüzdesi** | `=B6/B2*100` |
| **Hüküm** | `=EĞER(B7>=2;"KAZANDI";EĞER(B7>=1.5;"SINIRDA";"KAYBETTI"))` |
| Saf Stok Tahliyesi Ürün (A) | `=ÇOKEĞERSAY(Urun_Master!W:W;"A_SafStokTahliyesi")` |
| Büyük Kazanç (B) | `=ÇOKEĞERSAY(Urun_Master!W:W;"B_BuyukKazanc")` |
| Marj Erozyonu Ürün (E+F) | `=ÇOKEĞERSAY(Urun_Master!W:W;"E_KismiKayip")+ÇOKEĞERSAY(Urun_Master!W:W;"F_BuyukKayip")` |
| F Segment Tutar (en kötü) | `=ÇOKETOPLA(Urun_Master!H:H;Urun_Master!W:W;"F_BuyukKayip")` |
| Toplam Stok (mağaza+depo) | `=TOPLA(Urun_Master!AB:AB)` |
| Kampanya Öncesi Mağaza Stoğu | `=TOPLA(Urun_Master!AF:AF)` |
| Son Alışta Az Geldi (<3 adet) | `=ÇOKEĞERSAY(Urun_Master!AH:AH;">0")-ÇOKEĞERSAY(Urun_Master!AH:AH;">=3")` |

## 🔄 Veri Güncelleme Akışı

Kampanya devam ettikçe:
1. SQL dosyasında **kampanya tarih aralığını** güncelle (örn. `< CONVERT(date,'12.05.2026',104)`)
2. SSMS'te scripti tekrar çalıştır (F5)
3. Result grid'i seç → Excel'de `Urun_Master` sheet'inin mevcut verisini sil → yeni sonucu yapıştır
4. Tüm özet sheet'ler otomatik güncellenir

## 🆘 Sık Sorulan Sorunlar

| Sorun | Çözüm |
|---|---|
| Sorgu timeout veriyor | SSMS'te Query → Query Options → Execution → "Execution time-out" → 300 sn yap |
| Temp table hata veriyor | Kullanıcının `CREATE TABLE` yetkisi tempdb'de açık olmalı |
| `BENZERSİZ`, `SIRALA`, `FİLTRE` çalışmıyor | Excel 365 gerekli; klasikse "Yinelenenleri Kaldır" + manuel sıralama |
| `#AD?` hatası | İngilizce Excel — bu rehber Türkçeye göre, formül adları farklı |
| Argüman ayracı `,` istiyor | Dosya → Seçenekler → Gelişmiş → "Sistem ayraçlarını kullan" kapalı olmalı |

## 💡 Türkçe ↔ İngilizce Formül Karşılığı

| Türkçe | İngilizce |
|---|---|
| `ÇOKETOPLA` | `SUMIFS` |
| `ÇOKEĞERSAY` | `COUNTIFS` |
| `BAĞ_DEĞ_DOLU_SAY` | `COUNTA` |
| `EĞERHATA` | `IFERROR` |
| `EĞER` | `IF` |
| `TOPLA` | `SUM` |
| `BENZERSİZ` | `UNIQUE` |
| `SIRALA` | `SORT` |
| `FİLTRE` | `FILTER` |
| Argüman ayracı `;` | Argüman ayracı `,` |
