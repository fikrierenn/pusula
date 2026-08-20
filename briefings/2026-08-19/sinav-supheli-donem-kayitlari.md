# Sınav — Şüpheli Dönem Kayıtları (temizlik listesi)

**Tarih:** 20.08.2026 · **Kapsam:** `BKM.snv.Siparis` · `DonemId IN (1, −7, −8)` — 29 sipariş
**Neden:** `/sinav` panelinin dönem dropdown'ında görünüyorlar (plan-35 QA madde 1)

> **Ciro etkisi SIFIR.** 29 siparişin **hiçbirinde net ciro yok** (hepsi 0 ₺). Panel rakamlarını bozmuyorlar; yalnız dropdown'ı kirletiyorlar. Silme değil, **dönem düzeltmesi / dropdown filtresi** kararı.

---

## 1 · Kök sebep: `snv.Donem` tablosunda yalnız 6 dönem tanımlı

| DonemId | DonemAciklama | İşlem başlama | Yarıyıl |
|---|---|---|---|
| 1 | 2021-2022 | 01.08.2021 | 01.02.2022 |
| 4 | 2022-2023 | 01.08.2022 | 01.02.2023 |
| 5 | 2023-2024 | 01.08.2023 | 01.02.2024 |
| 6 | 2024-2025 | 01.08.2024 | 01.02.2025 |
| 7 | 2025-2026 | 01.06.2025 | 01.01.2026 |
| 8 | 2026-2027 | 16.07.2026 | 01.01.2027 |

**Sonuç:**
- **−7 ve −8 TANIMSIZ** → `snv.Donem`'de karşılığı yok, orphan `DonemId`. (Dönem 2 ve 3 de tanımsız ama sipariş yok.)
- **Dönem 1 = 2021-2022** ama içindeki siparişlerin tarihi **2023-2024** → yanlış dönem atanmış, olması gereken 5 veya 6.

---

## 2 · Dönem 1 — 13 sipariş (yanlış dönem atanmış)

Tanım 2021-2022, ama kayıtlar 2023-08 ve 2024-08 tarihli. **Hiçbirinde fiş yok.**

| # | SiparisId | Sipariş Kod | Tarih | Kampüs | Sınıf | Kalem | Ödenmiş | Fiş | Olması gereken |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1322 | 3812023013496 | 16.08.2023 | DEMİRCİ | 1 | 8 | 7 | 0 | Dönem 5 |
| 2 | 1323 | 3812023013502 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 3 | 1324 | 3812023013519 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 4 | 1325 | 3812023013526 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 5 | 1326 | 3812023013533 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 6 | 1327 | 3812023013540 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 7 | 1328 | 3812023013557 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 8 | 1329 | 3812023013564 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 9 | 1330 | 3812023013571 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 10 | 1331 | 3812023013588 | 16.08.2023 | DEMİRCİ | 1 | 7 | 0 | 0 | Dönem 5 |
| 11 | 10133 | 3812024101635 | 14.08.2024 | DOĞU | 11.EA | 14 | 0 | 0 | Dönem 6 |
| 12 | 12654 | 3812024127055 | 29.08.2024 | MKP | 4 | 11 | 0 | 0 | Dönem 6 |
| 13 | 13170 | 3812024132455 | 31.08.2024 | İHSANİYE | 11. EA İHS | 15 | 0 | 0 | Dönem 6 |

**Desen:** 1-10 aynı gün, ardışık `SiparisId` (1322-1331) ve ardışık `OgrenciId` (263-272) → tek seferlik **toplu giriş**, dönem alanı boş/yanlış bırakılmış. Kalanlar tek tek.

---

## 3 · Dönem −7 — 15 sipariş (2'si açık TEST, 7'si BOŞ)

| # | SiparisId | Sipariş Kod | Tarih | Kampüs | Sınıf | Kalem | Fiş | Not |
|---|---|---|---|---|---|---|---|---|
| 1 | 18852 | 3812025190621 | 21.07.2025 | **deneme okul1** | **TEST 21.06sınıfı** | 3 | 2 | TEST — fişi var (satış+iade, net 0) |
| 2 | 18853 | 3812025190638 | 30.07.2025 | **deneme okul1** | **TEST 21.06sınıfı** | 5 | 0 | TEST |
| 3 | 18854 | 3812025190645 | 31.07.2025 | BALAT | 2 | **0** | 0 | boş sipariş |
| 4 | 18856 | 3812025190669 | 06.08.2025 | DEMİRCİ | BÇU 5 | 8 | 2 | fişi var (net 0) |
| 5 | 19011 | 3812025192212 | 16.08.2025 | DEMİRCİ | 11.FEN | **0** | 0 | boş sipariş |
| 6 | 19176 | 3812025193868 | 18.08.2025 | DOĞU | 12.FEN | **0** | 0 | boş sipariş |
| 7 | 19252 | 3812025194629 | 19.08.2025 | BADEMLİ | 7. SINIF | **0** | 0 | boş sipariş |
| 8 | 19593 | 3812025198030 | 23.08.2025 | BALAT | 6. SINIF BALAT | **0** | 0 | boş · `Odendi=1` |
| 9 | 19594 | 3812025198047 | 23.08.2025 | BALAT | 6. SINIF BALAT | **0** | 0 | boş · aynı öğrenci (7143) ikinci kayıt |
| 10 | 19771 | 3812025199815 | 23.08.2025 | BALAT | 7. SINIF BALAT | **0** | 0 | boş · `Odendi=1` |
| 11 | 19798 | 3812025200085 | 24.08.2025 | BALAT | 5. SINIF BALAT | **0** | 0 | boş · `Odendi=1` |
| 12 | 20033 | 3812025202430 | 24.08.2025 | BALAT | 5. SINIF BALAT | **0** | 0 | boş · `Odendi=1` · öğrenci 7093 |
| 13 | 20035 | 3812025202454 | 24.08.2025 | BALAT | 5. SINIF NİLÜFER | 15 | 0 | aynı öğrenci (7093) ikinci kayıt, farklı sınıf |
| 14 | 22864 | 3812025230747 | 02.09.2025 | İHSANİYE | 12.FEN | 28 | 0 | fiş yok |
| 15 | 24151 | 3812025243617 | 05.09.2025 | GEMLİK | 4 | 7 | 0 | fiş yok |

**Desen:** tarihler 07-09/2025 → **dönem 7 (2025-2026) olmalı**. 7 sipariş tamamen boş (kalem yok). 5'inde `Odendi=1` ama kalem/fiş yok → bayrak anlamsız. 2 mükerrer öğrenci (7093, 7143) çift kayıt.

---

## 4 · Dönem −8 — 1 sipariş

| SiparisId | Sipariş Kod | Tarih | Kampüs | Sınıf | Kalem | Ödenmiş | Fiş |
|---|---|---|---|---|---|---|---|
| 27924 | 3812026281342 | **18.08.2026** | KUZEY | 1 | 4 | 0 | 0 |

Bugünün sezonuna ait (dönem 8 = 16.07.2026+) ama `DonemId = −8` girilmiş. **Tek kayıt, taze** → giriş ekranında dönem yanlış seçilmiş olabilir. Bu hâlâ oluşabiliyor demek ki — kaynak kontrolü gerekiyor.

---

## 5 · YAN BULGU — `snv.Okul`'da 24 test kaydı + 2 canlı çöp

41 okul kaydının **24'ü `Aktif=0` ve adı "Test ..." ile başlıyor** (Test DEMİRCİ, Test kübranın okulu, Test 08.06.2023 …). Bunlar zararsız (Aktif=0).

**Ama `Aktif=1` olan 17 kaydın 2'si canlı çöp:**

| OkulId | OkulAd | İlçe | Aktif | SinavKampusId |
|---|---|---|---|---|
| **56** | **deneme okul1** | Harmancık | **1** | NULL |
| **57** | **bkm sınıf** | Büyükorhan | **1** | NULL |

Gerçek kampüsler 42-55 arası (14 kampüs, `SinavKampusId` DOLU) + 58 NİLÜFER B.Ç.Ü (`SinavKampusId` NULL ama gerçek — BÇÜ ayrı program).

**Ayırt edici kural:** gerçek kampüs = `Aktif = 1 AND OkulAd NOT LIKE 'Test%' AND OkulId NOT IN (56, 57)`.
`SinavKampusId IS NOT NULL` tek başına yetmiyor — 58'i de dışlar.

> **Sema düzeltmesi:** `sema/entities.yaml` → `BKM.snv.Okul` kaydında "10 aktif kampüs" yazmıştım; **yanlış**. Doğrusu: 14 gerçek kampüs + NİLÜFER B.Ç.Ü. Benim listem yalnızca dönem 8'de siparişi olan 10 kampüsü içeriyordu. Düzeltildi.

---

## 6 · Karar seçenekleri

| # | Seçenek | Etki | Risk |
|---|---|---|---|
| **A** | **Dropdown'da yalnız `snv.Donem`'de tanımlı dönemleri göster** (1,4,5,6,7,8) | −7/−8 kaybolur; Dönem 1 kalır (tanımlı) | Yok — panel salt-okuma, veri değişmez |
| **B** | Dropdown'da yalnız **fişi olan** dönemleri göster (5,6,7,8) | Dönem 1 de kaybolur (0 fiş) | Yok |
| **C** | Şüpheli siparişlerin `DonemId`'sini **düzelt** (1→5/6, −7→7, −8→8) | Veri temizlenir, kalıcı çözüm | **ERP YAZMA** — `erp-write-policy.md` gereği `snv.*` yazma yetkim YOK, senin onayın + DB-admin gerekir |
| **D** | Hiçbir şey yapma, QA notunda kalsın | Dropdown kirli kalır | Kullanıcı yanlış dönem seçip boş panel görür |

**Önerim: B** (panel tarafı, sıfır risk, en temiz görünüm) + **C'yi ayrı iş olarak muhasebe/IT'ye ver** (29 kayıt düzeltme, ciro etkisi yok ama raporlama hijyeni).

`snv.Okul` 56/57 için de aynı ayrım: kampüs filtresi eklenecek yerlerde `OkulId NOT IN (56,57)`.

---

## Yeniden üretme sorgusu

```sql
-- Şüpheli dönem kayıtları (DonemId snv.Donem'de tanımsız VEYA tarih dönemle uyumsuz)
SELECT sip.DonemId, d.DonemAciklama, sip.SiparisId, sip.SiparisKod, sip.Tarih,
       ISNULL(ok.OkulAd,'(okul yok)') AS Kampus, ISNULL(sn.SinifAd,'(sınıf yok)') AS Sinif,
       sip.OgrenciId, CONVERT(int, ISNULL(sip.Odendi,0)) AS OdendiFlag,
       K.Kalem, K.Odenmis, ISNULL(X.Fis,0) AS Fis,
       CONVERT(decimal(18,2), ISNULL(X.NetKdvHaric,0)) AS NetKdvHaric
FROM BKM.snv.Siparis sip WITH(NOLOCK)
     LEFT JOIN BKM.snv.Donem d  WITH(NOLOCK) ON d.DonemId  = sip.DonemId
     LEFT JOIN BKM.snv.Okul ok  WITH(NOLOCK) ON ok.OkulId  = sip.OkulId
     LEFT JOIN BKM.snv.Sinif sn WITH(NOLOCK) ON sn.SinifId = sip.SinifId
     CROSS APPLY (SELECT COUNT(*) AS Kalem,
                         SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0)=1 THEN 1 ELSE 0 END) AS Odenmis
                  FROM BKM.snv.SiparisDetay sd WITH(NOLOCK)
                  WHERE sd.SiparisId = sip.SiparisId) K
     OUTER APPLY (SELECT COUNT(DISTINCT S.Id) AS Fis,
                         SUM(CASE WHEN S.DocumentsTypeId = 3
                                  THEN -(S.GrossTotal-S.DiscountTotal-S.VatTotal)
                                  ELSE  (S.GrossTotal-S.DiscountTotal-S.VatTotal) END) AS NetKdvHaric
                  FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
                       JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
                  WHERE FE.SiparisKod = sip.SiparisKod) X
WHERE d.DonemId IS NULL                                        -- tanımsız dönem (-7, -8)
   OR YEAR(sip.Tarih) < YEAR(d.IslemBaslamaTarih)              -- tarih dönemden ÖNCE
   OR YEAR(sip.Tarih) > YEAR(d.IslemBaslamaTarih) + 1          -- tarih dönemden SONRA
ORDER BY sip.DonemId, sip.Tarih, sip.SiparisId;

-- snv.Okul canlı çöp kayıtları
SELECT OkulId, OkulAd, Ilce, CONVERT(int, ISNULL(Aktif,0)) AS Aktif, SinavKampusId
FROM BKM.snv.Okul WITH(NOLOCK)
WHERE ISNULL(Aktif,0) = 1
  AND (OkulAd LIKE 'Test%' OR SinavKampusId IS NULL)
ORDER BY OkulId;
```
