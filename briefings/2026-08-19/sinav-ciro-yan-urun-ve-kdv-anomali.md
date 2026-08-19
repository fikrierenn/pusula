# Sınav Cirosu — Yan Ürün Ayrımı + Tüm Geçmiş KDV Anomali Analizi

**Hazırlık:** 19.08.2026 · **Kaynak:** BKM.snv.SinavSiparisFisEncore → EncoreMerkez.Sales/SalesProducts (IsValid=1) + DerinSISBkm.urn
**SQL:** [`sorgular/2026-08-19-sinav-yan-urun-atif.sql`](../../sorgular/2026-08-19-sinav-yan-urun-atif.sql) · [`sorgular/2026-08-19-sinav-kdv-anomali-tum-gecmis.sql`](../../sorgular/2026-08-19-sinav-kdv-anomali-tum-gecmis.sql) · [`sorgular/2026-08-19-sinav-encore-kdv-denetim.sql`](../../sorgular/2026-08-19-sinav-encore-kdv-denetim.sql)

---

## 1 · Mevcut sorgu ile farklar

| # | Konu | Mevcut sorgu | Yeni sorgu | Etki (18.08.2026) |
|---|---|---|---|---|
| 1 | Tutar | `TotalPrice` = **KDV DAHİL**, adı `NetTutar` | `TotalPrice − VatTotal` = KDV hariç, ayrı kolon | 1.233.850,51 → **1.211.490,57** (−22.359,94) |
| 2 | Kıyafet | `urnKtgr2ID NOT IN (13,18)` ile sessizce düşüyor | 3. kova olarak raporlanıyor | +38.949,83 dahil / +35.408,92 hariç |
| 3 | İade | ana sorguda `IIF(...=3,-1,1)` var, **kıyafet sorgusunda YOK** | her iki blokta sign uygulanıyor | kıyafet bloğunda 20.301,60 ₺ şişme |
| 4 | Kapsam | kıyafet sorgusu `SinavSiparisFisEncore`'a bağlı değil | Sınav kapsamı zorunlu | 87.457,10 ₺ perakende sızması |
| 5 | Yan ürün | ayrım yok, hepsi tek "sınav cirosu" | `SiparisDetay` bağıyla Paket / Kıyafet / Yan | Paket %90,7 · Kıyafet %2,9 · Yan %6,4 |
| 6 | Fan-out | `LEFT JOIN SiparisDetay` (SiparisId+StokId) | `OUTER APPLY TOP 1` | 18.08'de fark yok, geniş pencerede N× şişme riski kapandı |
| 7 | Tarih | `between '18.08.2026' and '18.08.2026 23:59'` | `>= CONVERT(...,104) AND < ertesi gün` | 23:59:00–23:59:59 kaybı + DATEFORMAT bağımlılığı |
| 8 | İndirim | `DiscountTotalDirect` (kısmi) | Direct + Indirect | 5.981,79 → 39.212,79 (gün) |
| 9 | Ürün join | `U.stkID = PR.Code` (varchar↔int) | aynı — `Products.Code` 865.729 kayıtta %100 sayısal, risk yok | yalnız index-seek kaybı (perf) |

---

## 2 · Sınav paketi vs Yan ürün — ayraç tanımı

**Kategori ayracı ÇALIŞMAZ.** `Çocuk Kitabı` ve `Hazırlık Kitapları` hem sipariş kapsamında hem sipariş dışında görünüyor. Doğru ayraç **sipariş kapsamı**:

- **PAKET** = satırın ürünü o siparişin `BKM.snv.SiparisDetay`'ında **VAR** (okulun ısmarladığı set)
- **KIYAFET** = siparişte yok + kategori 13/18 (zorunlu üniforma — isteğe bağlı sepet büyütme değil, ayrı kova)
- **YAN ÜRÜN** = siparişte yok + kıyafet değil (kasada eklenen ek satış)

Kanıt: `SiparisDetay` (DonemId=8) yalnız **Sınav Okulları (88 ürün) + Hazırlık Kitapları (66) + Çocuk Kitabı (13) + Kitap (9)** içeriyor. **Kıyafet ve kırtasiye sipariş kapsamında HİÇ YOK** → tanımı gereği sipariş dışı.

### Gün özeti (18.08.2026, KDV hariç)

| Kova | Satır | Adet | KDV dahil | **KDV hariç** | Pay |
|---|---|---|---|---|---|
| Sınav paketi | 251 | 251 | 1.104.785,55 | **1.098.902,37** | %90,7 |
| Kıyafet | 32 | 32 | 38.949,83 | **35.408,92** | %2,9 |
| Yan ürün | 438 | 608 | 90.115,13 | **77.179,28** | %6,4 |
| **TOPLAM** | **721** | | **1.233.850,51** | **1.211.490,57** | %100 |

### Ek ciro efekti

| Gösterge | Değer |
|---|---|
| Yan ürünlü fiş | **19 / 24 (%79)** |
| Kıyafetli fiş | 8 / 24 (%33) |
| Sipariş dışı toplam ek ciro (KDV hariç) | **112.588,20 ₺ (%9,3)** |
| Yan ürünlü fiş başına yan ciro | **4.062,07 ₺** |
| Ortalama sepet (KDV hariç) | 50.478,77 ₺ |
| Fiş başına yan ürün satırı | 19,6 |

### Yan ürün neyden geliyor (KDV hariç)

| Kategori | Kova | Satır | Adet | Tutar |
|---|---|---|---|---|
| Kırtasiye | YAN | 416 | 586 | 73.773,19 |
| Sınav Kıyafet | KIYAFET | 32 | 32 | 35.408,92 |
| Çocuk Kitabı | YAN | 11 | 11 | 1.923,93 |
| Hazırlık Kitapları | YAN | 2 | 2 | 939,73 |
| Kişisel Bakım | YAN | 4 | 4 | 226,82 |
| Hediyelik | YAN | 3 | 3 | 193,26 |
| Gıda | YAN | 2 | 2 | 122,35 |

**Okuma:** paket satışının yanında kırtasiye ek satışı 73,8 bin ₺ — Sınav fişlerinin %79'unda kırtasiye eklenmiş. Bu, Sınav operasyonunun mağazaya taşıdığı **ek ciro efekti**; paket cirosuyla karıştırılmamalı.

### Fiş bazlı (18.08.2026, KDV hariç, yan ürüne göre azalan)

| Fiş Id | Belge | Z | Kasa | Sipariş Kod | Paket | Kıyafet | Yan ürün | Yan satır | Toplam | Sip.dışı % |
|---|---|---|---|---|---|---|---|---|---|---|
| 1254358 | 82 | 205 | 35 | …243 | 58.091,06 | 0,00 | 8.032,79 | 49 | 66.123,85 | %12,1 |
| 1255037 | 144 | 205 | 35 | …311 | 57.057,95 | 2.695,92 | 6.877,97 | 44 | 66.631,84 | %14,4 |
| 1255525 | 167 | 461 | 33 | …359 | 56.930,24 | 0,00 | 6.647,55 | 40 | 63.577,79 | %10,5 |
| 1253388 | 50 | 157 | 31 | …182 | 57.192,18 | 10.682,53 | 6.629,58 | 39 | 74.504,29 | %23,2 |
| 1254150 | 85 | 389 | 34 | …236 | 14.516,67 | 5.590,90 | 6.408,19 | 33 | 26.515,76 | %45,3 |
| 1254834 | 24 | 107 | 36 | …328 | 58.035,57 | 1.454,54 | 6.000,74 | 38 | 65.490,85 | %11,4 |
| 1254460 | 94 | 205 | 35 | …250 | 20.846,66 | 8.180,48 | 5.598,03 | 30 | 34.625,17 | %39,8 |
| 1253794 | 51 | 389 | 34 | …212 | 20.850,01 | 0,00 | 5.539,76 | 30 | 26.389,77 | %21,0 |
| 1255857 | 254 | 205 | 35 | …397 | 60.676,05 | 0,00 | 5.524,82 | 46 | 66.200,87 | %8,3 |
| 1253893 | 112 | 426 | 32 | …229 | 21.750,00 | 2.090,91 | 5.517,42 | 29 | 29.358,33 | %25,9 |
| 1254788 | 158 | 389 | 34 | …304 | 21.750,00 | 0,00 | 5.446,59 | 30 | 27.196,59 | %20,0 |
| 1253461 | 50 | 426 | 32 | …199 | 21.750,01 | 2.804,55 | 2.146,66 | 4 | 26.701,22 | %18,5 |
| 1255775 | 246 | 205 | 35 | …403 | 20.850,00 | 0,00 | 2.190,00 | 2 | 23.040,00 | %9,5 |
| 1254824 | 100 | 157 | 31 | …335 | 17.800,00 | 0,00 | 1.427,65 | 9 | 19.227,65 | %7,4 |
| 1255303 | 173 | 205 | 35 | …366 | 68.088,27 | 0,00 | 939,73 | 2 | 69.028,00 | %1,4 |
| 1253802 | 9 | 107 | 36 | …205 | 59.609,00 | 1.909,09 | 739,17 | 4 | 62.257,26 | %4,3 |
| 1255925 | 78 | 107 | 36 | …410 | 59.403,00 | 0,00 | 655,00 | 6 | 60.058,00 | %1,1 |
| 1255464 | 206 | 205 | 35 | …380 | 59.609,00 | 0,00 | 498,33 | 2 | 60.107,33 | %0,8 |
| 1254866 | 26 | 107 | 36 | …281 | 59.043,70 | 0,00 | 359,30 | 1 | 59.403,00 | %0,6 |
| 1253314 | 32 | 157 | 31 | …175 | 59.403,00 | 0,00 | 0,00 | 0 | 59.403,00 | %0 |
| 1254543 | 113 | 205 | 35 | …267 | 68.000,00 | 0,00 | 0,00 | 0 | 68.000,00 | %0 |
| 1254758 | 104 | 461 | 33 | …298 | 68.000,00 | 0,00 | 0,00 | 0 | 68.000,00 | %0 |
| 1254780 | 133 | 205 | 35 | …274 | 20.850,00 | 0,00 | 0,00 | 0 | 20.850,00 | %0 |
| 1255422 | 38 | 107 | 36 | …373 | 68.800,00 | 0,00 | 0,00 | 0 | 68.800,00 | %0 |

---

## 3 · Tüm geçmiş KDV anomali taraması

**Kapsam:** 29.07.2025 – 18.08.2026 · **9.319 fiş** · **240.176 satır** · ciro (KDV dahil) 430.928.644,93 ₺ · KDV 3.961.095,24 ₺

| Test | Sonuç |
|---|---|
| T1 · KDV aritmetiği `VatTotal = TotalPrice × p/(100+p)` | **0 / 240.176 sapma — TEMİZ** |
| T2 · Oran > 0 ama VatTotal = 0 | 192 satır, toplam **1,33 ₺** (yuvarlama, önemsiz) |
| T3 · Oran = 0 ama VatTotal ≠ 0 | 0 — TEMİZ |
| T4 · Fiş header ↔ satır (KDV + net) | **0 / 9.319 sapma — TEMİZ** |
| T5 · Geçersiz KDV oranı | YOK (yalnız %0 / %1 / %10 / %20) |
| T6 · **POS oranı ↔ ERP oranı uyumsuz** | **92 satır / 36 ürün / 38.937,02 ₺ → eksik KDV 4.015,75 ₺** |
| T7 · Aynı ürün aynı gün farklı oran | 0 — TEMİZ |
| T8 · Aynı ürün zaman içinde oran değişimi | 2 ürün (%0 ↔ %10, POS'ta sonradan düzeltilmiş) |

### T6 — tek gerçek bulgu

| POS oranı | ERP oranı | Satır | Ürün | Tutar (dahil) | Eksik/Fazla KDV |
|---|---|---|---|---|---|
| %0 | %10 | 61 | 20 | 32.087,89 | **eksik 2.917,09** |
| %0 | %20 | 29 | 16 | 6.623,93 | **eksik 1.103,96** |
| %1 | %10 | 1 | 1 | 75,00 | eksik 6,08 |
| %20 | %10 | 1 | 1 | 150,20 | fazla 11,38 |
| **Toplam** | | **92** | **36** | **38.937,02** | **net eksik 4.015,75** |

**Aylık dağılım** — %95 okul sezonu açılışında:

| Dönem | Sapan satır | Tutar | Eksik KDV |
|---|---|---|---|
| Ağu 2025 | 34 | 18.069,39 | 1.745,15 |
| Eyl 2025 | 53 | 19.619,37 | 2.071,16 |
| Eki 2025 | 1 | 952,80 | 158,80 |
| Oca 2026 | 2 | 191,46 | 31,92 |
| Nis 2026 | 1 | 29,00 | 2,64 |
| Ağu 2026 | 1 | 75,00 | 6,08 |

**Profil:** yeni açılan ürün kartları (Disney Spiderman/Stitch/Frozen çanta-matara-kalem serisi, dedektif oyunları) POS'a **KDV'siz** girilmiş; ERP'de doğru oran (%10/%20) tanımlıydı. Kartlar sonradan düzeltilmiş — 2026'da yalnız 4 satır kalmış. **Sistematik hata değil, ürün-kartı açılış hatası.**

En büyük 8 kalem:

| StkID | Ürün | Kategori | POS | ERP | Satır | Tutar | Eksik KDV |
|---|---|---|---|---|---|---|---|
| 1643226 | Disney Spiderman İlkokul Çantası Pls-Lx | Kırtasiye | 0 | 10 | 4 | 6.134,85 | 557,71 |
| 1643252 | Disney Stitch İlkokul Çantası Rox Hawaii | Kırtasiye | 0 | 10 | 2 | 3.436,75 | 312,43 |
| 1643227 | Disney Spiderman İlkokul Çantası Pls-Lx | Kırtasiye | 0 | 10 | 2 | 3.262,22 | 296,56 |
| 1643237 | Disney Spiderman Plastik Matara Frx-T | Kırtasiye | 0 | 20 | 6 | 1.644,50 | 274,07 |
| 1643229 | Disney Spiderman İlkokul Çantası Rox Eye | Kırtasiye | 0 | 10 | 2 | 2.980,12 | 270,92 |
| 1643236 | Disney Spiderman Plastik Matara Frx 500M | Kırtasiye | 0 | 20 | 5 | 1.495,00 | 249,15 |
| 1643241 | Disney Spiderman Sırt Çantası Deep Code | Kırtasiye | 0 | 10 | 1 | 2.429,70 | 220,88 |
| 1643240 | Disney Spiderman Sırt Çantası Deep Be Yo | Kırtasiye | 0 | 10 | 1 | 1.800,00 | 163,64 |

Tam 38 satırlık liste: SQL dosyası T6 bloğu.

### Ölçek

92 sapan satır / 240.176 = **%0,038** · 38.937 ₺ / 430,9M ₺ = **%0,009**. Muhasebe açısından maddi değil ama **KDV eksik beyanı** — mali müşavire bildirilmesi gerekir. Aynı ürünler perakende (Sınav dışı) fişlerde de satılmış olabilir; bu tarama yalnız Sınav fişlerini kapsıyor → **aynı kontrolü tüm POS satışında koşturmak gerekir.**

---

## Aksiyon önerisi

1. **Kıyafet bloğuna iade sign'ı ekle** — 20.301,60 ₺/gün mertebesinde şişme (en acil).
2. **Kıyafet bloğunu Sınav kapsamına bağla** (`SinavSiparisFisEncore` join) — perakende sızması bitsin.
3. **KDV-hariç kolonu** raporlara ekle; "NetTutar" adını "NetKdvDahil" yap.
4. **3 kova raporu** (Paket / Kıyafet / Yan ürün) standart hale gelsin — ek ciro efekti ölçülebilir olsun.
5. **T6 listesini** (36 ürün) mali müşavire ilet + aynı taramayı tüm POS satışına genişlet.
