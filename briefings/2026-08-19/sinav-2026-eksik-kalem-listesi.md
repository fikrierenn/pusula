# Sınav 2026 (Dönem 8) — Kısmi Sipariş Eksik Kalem Listesi

**Kapsam:** DonemId 8 · 22.07.2026 – 19.08.2026 · **35 kısmi sipariş / 55 eksik kalem**
**Kaynak:** `BKM.snv.SiparisDetay` (`OdemesiYapildi = 0`, `Iptal = 0`) · sipariş kalem sayısı > ödenmiş > 0
**SQL:** [`sorgular/2026-08-19-sinav-odeme-kismi-model.sql`](../../sorgular/2026-08-19-sinav-odeme-kismi-model.sql) blok 3
**Hazırlık:** 19.08.2026

> **35 siparişin TAMAMINDA `Siparis.Odendi = 1`** — panelde "ödendi" görünüyorlar.
> **KVKK:** bu listede öğrenci adı/telefonu YOK (repo'ya kişisel veri yazılmadı).
> İsim gerekiyorsa dosya sonundaki sorguyu çalıştırın — `snv.Ogrenci.OgrenciAdSoyad`.

---

## 1 · Dönem 8 genel durum

| Kalem durumu | Sipariş | Kalem | Ödenmemiş kalem | `Odendi=1` | İadeli | Net ciro (KDV hariç) |
|---|---|---|---|---|---|---|
| TAM ÖDENDİ | 294 | 2.672 | 0 | 294 ✓ | 4 | 16.114.766,85 |
| **KISMİ ÖDENDİ** | **35** | 427 | **55** | **35 ✗** | 1 | 1.908.386,07 |
| HİÇ ÖDENMEDİ | 28 | 315 | 315 | 0 ✓ | 0 | 0 |
| **Toplam** | **357** | 3.414 | 370 | 329 | 5 | 18.023.152,92 |

---

## 2 · ÖNEMLİ OKUMA — bu bir tahsilat açığı DEĞİL, teslim/tedarik açığı olabilir

55 kalemin **tamamında** aynı desen:

| Alan | Değer |
|---|---|
| `KasaAdet` | 0 (hiç kasadan geçmemiş) |
| `FisId` | NULL (hiçbir fişe bağlanmamış) |
| `Alindi` | 0 |
| `Hazirlandi` | 0 |
| `OkulTeslimat` | 0 |

Yani bu kalemler ödenmemiş **ve** hazırlanmamış — sipariş listesinde duruyor ama hiç işleme girmemiş.

**Ve tekrar eden ürün deseni sistematik:** aynı ürün aynı sınıfın onlarca siparişinde eksik. Veli-veli bağımsız karar olsaydı dağınık olurdu.

| Ürün | StkID | Kategori | Eksik sipariş | Hangi sınıf |
|---|---|---|---|---|
| Duyun Sesimi | 227386 | Sınav Okulları | **8** | BÇU 6 |
| Doğanın Düzeni 4 Kitap Set | 1733774 | Hazırlık Kitapları | **8** | 2. sınıf |
| MOMO | 136080 | Çocuk Kitabı | **8** | 8. sınıf |
| Bir Aile Macerası - Çikolata Meselesi | 1589604 | Çocuk Kitabı | 6 | 4. sınıf |
| Fen Köyü Hikaye Serisi (10 Kitap) | 295880 | Çocuk Kitabı | 5 | 4. sınıf |
| Koleksiyon Kitaplar - 10 Kitap | 1533367 | Çocuk Kitabı | 4 | 4. sınıf |
| Gençler İçin Nutuk (Söylev) | 149304 | Çocuk Kitabı | 3 | 8. sınıf |
| BÇÜ COSMOLAND 36-48 AY EĞİTİM SETİ (2 KİTAP) | 1546676 | Sınav Okulları | 2 | BÇU 3-4 |
| Universal Goals Level 2 | 1666596 | Sınav Okulları | 2 | 3. sınıf |
| Victory 8 Avenger Words | 1549085 | Sınav Okulları | 1 | 8. sınıf |
| Victory 8 Worksheets | 1549088 | Hazırlık Kitapları | 1 | 8. sınıf |
| Victory 8 True Success Test Book (New Ed.) | 1667796 | Hazırlık Kitapları | 1 | 8. sınıf |
| Öykü Denizi (10 Kitap Takım) | 136621 | Çocuk Kitabı | 1 | 2. sınıf |
| Laklak Hikaye Serisi 10 Kitap | 255995 | Çocuk Kitabı | 1 | 2. sınıf |
| Kendine Yardımcı Ol 4 Kitap Set | 1733773 | Hazırlık Kitapları | 1 | 3. sınıf |
| Çook Tatlı Az Tuzlu Hikayeler | 1679694 | Çocuk Kitabı | 1 | 3. sınıf |
| 3. Sınıf Matematik Hikayeleri | 1655968 | Çocuk Kitabı | 1 | 3. sınıf |
| Cabi'nin Kulesi | 1574032 | Çocuk Kitabı | 1 | 8. sınıf |

**Sorulacak soru:** bu ürünler stokta yok mu, sınıf listesinden sonradan çıkarıldı mı, yoksa gerçekten veli almadı mı? Cevap "stok yok / sonra gelecek" ise bu bir **tedarik açığı**, "ödenmedi" değil.

---

## 3 · 55 eksik kalem — tam liste

Kampüsler: 42 DEMİRCİ · 43 MKP · 44 DOĞU (Kestel) · 45 ÖZLÜCE · 46 GEMLİK · 47 KUZEY · 48 BADEMLİ · 49 BALAT · 52 İNEGÖL · 58 NİLÜFER B.Ç.Ü

| # | Sipariş Kod | Tarih | Kampüs | Sınıf | Öğr.Id | Kalem | Ödenmiş | **Eksik** | Eksik ürün | Kategori |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 3812026278076 | 24.07 | DEMİRCİ | BÇU 6 | 11435 | 9 | 8 | 1 | Duyun Sesimi | Sınav Okulları |
| 2 | 3812026278113 | 25.07 | MKP | BÇU 6 | 11505 | 9 | 8 | 1 | Duyun Sesimi | Sınav Okulları |
| 3 | 3812026278151 | 26.07 | KUZEY | BÇU 6 | 14361 | 9 | 8 | 1 | Duyun Sesimi | Sınav Okulları |
| 4 | 3812026278168 | 26.07 | BALAT | BÇU 6 | 11184 | 9 | 8 | 1 | Duyun Sesimi | Sınav Okulları |
| 5 | 3812026278175 | 26.07 | KUZEY | BÇU 6 | 14362 | 9 | 8 | 1 | Duyun Sesimi | Sınav Okulları |
| 6 | 3812026278236 | 28.07 | ÖZLÜCE | BÇU 6 | 10649 | 9 | 8 | 1 | Duyun Sesimi | Sınav Okulları |
| 7 | 3812026278243 | 29.07 | DOĞU | BÇU 6 | 11421 | 9 | 8 | 1 | Duyun Sesimi | Sınav Okulları |
| 8 | 3812026279066 | 10.08 | DEMİRCİ | 2 | 128 | 4 | 3 | 1 | Doğanın Düzeni 4 Kitap Set | Hazırlık |
| 9 | 3812026279103 | 11.08 | GEMLİK | 2 | 10847 | 4 | 3 | 1 | Doğanın Düzeni 4 Kitap Set | Hazırlık |
| 10 | 3812026279141 | 11.08 | DEMİRCİ | 4 NİLÜFER | 10897 | 8 | 5 | **3** | Bir Aile Macerası · Koleksiyon Kitaplar 10 · Fen Köyü Hikaye 10 | Çocuk Kitabı |
| 11 | 3812026279172 | 11.08 | GEMLİK | 4 | 4479 | 6 | 4 | **2** | Fen Köyü Hikaye 10 · Bir Aile Macerası | Çocuk Kitabı |
| 12 | 3812026279264 | 11.08 | MKP | 4 | 1427 | 6 | 3 | **3** | Fen Köyü Hikaye 10 · Koleksiyon Kitaplar 10 · Bir Aile Macerası | Çocuk Kitabı |
| 13 | 3812026279639 | 13.08 | BADEMLİ | 4 | 6272 | 6 | 3 | **3** | Fen Köyü Hikaye 10 · Koleksiyon Kitaplar 10 · Bir Aile Macerası | Çocuk Kitabı |
| 14 | 3812026279646 | 13.08 | DEMİRCİ | 2 | 9929 | 4 | 1 | **3** | Doğanın Düzeni 4 Kitap · Öykü Denizi 10 Kitap · Laklak Hikaye 10 | Hazırlık + Çocuk |
| 15 | 3812026279660 | 13.08 | DOĞU | 3 | 8501 | 5 | 1 | **4** | Kendine Yardımcı Ol 4 Kitap · Çook Tatlı Az Tuzlu · 3.Sınıf Matematik Hikayeleri · Universal Goals L2 | Hazırlık + Çocuk + Sınav |
| 16 | 3812026279851 | 14.08 | KUZEY | 2 | 12469 | 4 | 3 | 1 | Doğanın Düzeni 4 Kitap Set | Hazırlık |
| 17 | 3812026280086 | 15.08 | GEMLİK | 8 | 4711 | 29 | 28 | 1 | MOMO | Çocuk Kitabı |
| 18 | 3812026280093 | 15.08 | MKP | 2 | 8962 | 4 | 3 | 1 | Doğanın Düzeni 4 Kitap Set | Hazırlık |
| 19 | 3812026280253 | 15.08 | NİLÜFER B.Ç.Ü | BÇU 3-4 | 14419 | 7 | 6 | 1 | BÇÜ COSMOLAND 36-48 AY (2 Kitap) | Sınav Okulları |
| 20 | 3812026280321 | 15.08 | DOĞU | 8 | 2477 | 29 | 27 | **2** | MOMO · Gençler İçin Nutuk | Çocuk Kitabı |
| 21 | 3812026280369 | 15.08 | DEMİRCİ | 8 | 663 | 29 | 27 | **2** | MOMO · Gençler İçin Nutuk | Çocuk Kitabı |
| 22 | 3812026280390 | 15.08 | ÖZLÜCE | 8 | 3699 | 29 | 28 | 1 | MOMO | Çocuk Kitabı |
| 23 | 3812026280451 | 16.08 | DOĞU | BÇU 3-4 | 14424 | 7 | 6 | 1 | BÇÜ COSMOLAND 36-48 AY (2 Kitap) | Sınav Okulları |
| 24 | 3812026280604 | 16.08 | İNEGÖL | 4 | 8092 | 6 | 3 | **3** | Fen Köyü Hikaye 10 · Koleksiyon Kitaplar 10 · Bir Aile Macerası | Çocuk Kitabı |
| 25 | 3812026280635 | 16.08 | DEMİRCİ | 8 | 647 | 29 | 28 | 1 | Cabi'nin Kulesi | Çocuk Kitabı |
| 26 | 3812026280673 | 16.08 | DEMİRCİ | 8 | 7574 | 29 | 28 | 1 | MOMO | Çocuk Kitabı |
| 27 | 3812026280840 | 16.08 | ÖZLÜCE | 8 | 3708 | 29 | 25 | **4** | Victory 8 Avenger Words · Victory 8 Worksheets · Victory 8 True Success Test · MOMO | Sınav + Hazırlık + Çocuk |
| 28 | 3812026280871 | 17.08 | DOĞU | 2 | 13797 | 4 | 3 | 1 | Doğanın Düzeni 4 Kitap Set | Hazırlık |
| 29 | 3812026280888 | 17.08 | BADEMLİ | 8 | 6458 | 29 | 28 | 1 | MOMO | Çocuk Kitabı |
| 30 | 3812026280918 | 17.08 | BALAT | 2 | 6807 | 4 | 3 | 1 | Doğanın Düzeni 4 Kitap Set | Hazırlık |
| 31 | 3812026280932 | 17.08 | DEMİRCİ | 8 | 13229 | 29 | 27 | **2** | MOMO · Gençler İçin Nutuk | Çocuk Kitabı |
| 32 | 3812026281014 | 17.08 | MKP | 2 | 1285 | 4 | 3 | 1 | Doğanın Düzeni 4 Kitap Set | Hazırlık |
| 33 | 3812026281281 | 18.08 | DOĞU | 4 | 8872 | 6 | 5 | 1 | Bir Aile Macerası | Çocuk Kitabı |
| 34 | 3812026281335 | 18.08 | DOĞU | BÇU 6 | 14455 | 9 | 8 | 1 | Duyun Sesimi | Sınav Okulları |
| 35 | 3812026281571 | 19.08 | DOĞU | 3 | 1969 | 5 | 4 | 1 | Universal Goals Level 2 | Sınav Okulları |

**Kampüs dağılımı:** DEMİRCİ 8 · DOĞU 7 · MKP 4 · ÖZLÜCE 3 · KUZEY 3 · BADEMLİ 3 · GEMLİK 3 · BALAT 2 · İNEGÖL 1 · NİLÜFER B.Ç.Ü 1

**Sınıf dağılımı:** 8. sınıf 8 · BÇU 6 → 8 · 2. sınıf 8 · 4. sınıf 5 · 3. sınıf 2 · BÇU 3-4 → 2 · 4 NİLÜFER 1

---

## 4 · Tutar neden yok

`snv.SiparisDetay.BirimFiyat` pratikte NULL — dönem 7-8'de 112.499 ödenmiş kalemin toplam "beklenen tutarı" yalnız **599 ₺** çıkıyor. Bu yüzden eksik kalemin TL karşılığı bu tablodan hesaplanamıyor; yalnız **kalem sayısı** verilebilir.

Ödenmiş kalemlerin tutarı ise kalem-fiş köprüsünden gelir:
```
SiparisDetay.FisId       = EncoreMerkez.Sales.DocumentNo
SiparisDetay.FisIdSiraNo = EncoreMerkez.SalesProducts.Sequence
```
Eksik kalemler için TL isterseniz güncel satış fiyat listesinden tahmin edilmesi gerekir (ayrı iş).

---

## 5 · İsim eklemek için sorgu (repo'ya yazılmadı — KVKK)

```sql
DECLARE @Donem int = 8;

SELECT sip.SiparisKod, sip.Tarih AS SiparisTarih,
       ok.OkulAd AS Kampus, ok.Ilce, sn.SinifAd AS Sinif,
       og.OgrenciAdSoyad, og.OgrenciTelefon,
       K.Kalem, K.OdenmisKalem, K.OdenmemisKalem,
       sd.StokId, U.stkAd AS EksikUrun, k2.ktgrAd AS Kategori, sd.Adet,
       CONVERT(int, ISNULL(sip.Odendi,0)) AS OdendiFlag
FROM BKM.snv.Siparis sip WITH(NOLOCK)
     JOIN BKM.snv.SiparisDetay sd WITH(NOLOCK) ON sd.SiparisId = sip.SiparisId
     CROSS APPLY (SELECT COUNT(*) AS Kalem,
                         SUM(CASE WHEN ISNULL(sd2.OdemesiYapildi,0)=1 THEN 1 ELSE 0 END) AS OdenmisKalem,
                         SUM(CASE WHEN ISNULL(sd2.OdemesiYapildi,0)=0
                                   AND ISNULL(sd2.Iptal,0)=0 THEN 1 ELSE 0 END)          AS OdenmemisKalem
                  FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                  WHERE sd2.SiparisId = sip.SiparisId) K
     LEFT JOIN BKM.snv.Ogrenci og WITH(NOLOCK) ON og.OgrenciId = sip.OgrenciId
     LEFT JOIN BKM.snv.Okul ok    WITH(NOLOCK) ON ok.OkulId    = sip.OkulId
     LEFT JOIN BKM.snv.Sinif sn   WITH(NOLOCK) ON sn.SinifId   = sip.SinifId
     LEFT JOIN DerinSISBkm.dbo.urn U       WITH(NOLOCK) ON U.stkID   = sd.StokId
     LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
WHERE sip.DonemId = @Donem
  AND ISNULL(sd.OdemesiYapildi,0) = 0
  AND ISNULL(sd.Iptal,0) = 0
  AND K.OdenmisKalem > 0            -- kısmi (hiç ödenmemişleri hariç tut)
ORDER BY sip.Tarih, sip.SiparisKod, sd.StokId;
```

`AND K.OdenmisKalem > 0` satırını kaldırırsanız **28 "hiç ödenmedi" sipariş / 315 kalem** de listeye girer (toplam 63 sipariş / 370 kalem).


---

## 6 · STOK KONTROLÜ — soru cevaplandı (19.08.2026, `dbo.stokSon_vw`)

**Sonuç: 55 kalemin 46'sı stok varken ödenmemiş → operasyon/tahsilat açığı. Yalnız 9 kalem gerçek tedarik açığı.**

### Tedarik açığı — İst.Yolu'nda stok NEGATİF (2 ürün / 9 kalem)

| StkID | Ürün | İst.Yolu | FSM | Özlüce | Eksik kalem | Yorum |
|---|---|---|---|---|---|---|
| **227386** | **Duyun Sesimi** | **−23** | 0 | 0 | **8** | Hiçbir mağazada stok YOK. 8 BÇU-6 siparişinin tamamı bu yüzden eksik → **gerçek tedarik açığı**, tahsilat sorunu değil. |
| **1574032** | **Cabi'nin Kulesi** | **−17** | 6 | 1 | **1** | İst.Yolu negatif ama FSM'de 6 + Özlüce'de 1 var → **transferle çözülür**. |

### Operasyon açığı — stok BOL ama kasadan geçmemiş (16 ürün / 46 kalem)

| StkID | Ürün | İst.Yolu stok | Eksik kalem |
|---|---|---|---|
| 1589604 | Bir Aile Macerası - Çikolata Meselesi | 728 | 6 |
| 1533367 | Koleksiyon Kitaplar - 10 Kitap | 612 | 4 |
| 136080 | MOMO | 569 | 8 |
| 1733774 | Doğanın Düzeni 4 Kitap Set | 567 | 8 |
| 1655968 | 3. Sınıf Matematik Hikayeleri | 557 | 1 |
| 1733773 | Kendine Yardımcı Ol 4 Kitap Set | 557 | 1 |
| 1666596 | Universal Goals Level 2 | 537 | 2 |
| 295880 | Fen Köyü Hikaye Serisi (10 Kitap) | 522 | 5 |
| 1549088 | Victory 8 Worksheets | 481 | 1 |
| 149304 | Gençler İçin Nutuk (Söylev) | 479 | 3 |
| 1679694 | Çook Tatlı Az Tuzlu Hikayeler | 465 | 1 |
| 1667796 | Victory 8 True Success Test Book | 462 | 1 |
| 1549085 | Victory 8 Avenger Words | 453 | 1 |
| 255995 | Laklak Hikaye Serisi 10 Kitap | 444 | 1 |
| 136621 | Öykü Denizi (10 Kitap Takım) | 412 | 1 |
| 1546676 | BÇÜ COSMOLAND 36-48 AY (2 Kitap) | 290 | 1 |

Bu 46 kalemde ürün rafta duruyor, öğrenci sipariş etmiş, **kasadan hiç geçmemiş** (`KasaAdet=0`, `FisId` NULL, `Hazirlandi=0`) ama sipariş `Odendi=1`. Yani ya tahsil edilmedi ya kasada atlandı.

### Yan bulgu — negatif depo bakiyeleri (ilgisiz, ayrı iş)

| Ürün | İptal-Transfer Deposu | İade Deposu (ODAK) |
|---|---|---|
| MOMO | **−1.195** | −153 |
| Cabi'nin Kulesi | — | **−139** |
| Öykü Denizi | — | −85 |
| Gençler İçin Nutuk | +252 | −15 |

İptal-Transfer ve İade deposunda büyük negatif bakiyeler var. Bu, mağaza stoklarını etkilemiyor ama toplam stok rakamını bozuyor (MOMO ana mekanlarda +627, tüm mekan toplamı −721). Ayrı inceleme konusu.

### Aksiyon

1. **Duyun Sesimi (227386)** — 8 öğrencinin kitabı yok, stok da yok. Tedarik/baskı durumu sorulacak. Sipariş `Odendi=1` görünüyor ama kitap teslim edilemez.
2. **Cabi'nin Kulesi (1574032)** — FSM/Özlüce'den 1 adet transfer.
3. **46 kalem** — kampüs bazlı kontrol: ürün rafta, neden kasadan geçmedi? En yoğun MOMO (8) · Doğanın Düzeni (8) · Bir Aile Macerası (6) · Fen Köyü (5).


---

## 7 · SINIF LİSTESİ KONTROLÜ — hayır, çıkarılmamış (19.08.2026)

**Soru:** bu ürünler sınıf listesinden çıkarıldı mı?
**Cevap: HAYIR.** 18 ürünün tamamı dönem 8 sınıf listesinde KAYITLI ve aktif.

### `snv.SinifKitap` (DonemId = 8) — hepsi kayıtlı

22 kayıt bulundu, eksik ürün yok. Her ürün doğru sınıfa bağlı:

| StokId | Ürün (SinavUrun adı) | Sınıf | `FisteGoster` |
|---|---|---|---|
| 227386 | P4C 6 YAŞ DÜŞÜNME KUTUSU VE HİKAYE VE MATERYAL SET | BÇU 6 | 0 |
| 1733774 | Doğanın Düzeni 4 Kitap Set | 2 | 0 |
| 136621 | Öykü Denizi (10 Kitap Takım) | 2 | 0 |
| 255995 | Laklak Hikaye Serisi 10 Kitap | 2 | 0 |
| 1733773 | Kendine Yardımcı Ol 4 Kitap Set | 3 | 0 |
| 1679694 | Çook Tatlı Az Tuzlu Hikayeler | 3 | 0 |
| 1655968 | 3. Sınıf Matematik Hikayeleri | 3 | 0 |
| 1666596 | Universal Goals Level 2 | 3 | 0 |
| 295880 | Fen Köyü Hikaye Serisi (10 Kitap) | 4 + 4 NİLÜFER | 0 |
| 1533367 | Koleksiyon Kitaplar - 10 Kitap | 4 + 4 NİLÜFER | 0 |
| 1589604 | Bir Aile Macerası - Çikolata Meselesi | 4 + 4 NİLÜFER | 0 |
| 136080 | MOMO | 8 (+ **TEST 21.06sınıfı**) | 0 (test kaydında 1) |
| 149304 | Gençler İçin Nutuk (Söylev) | 8 | 0 |
| 1574032 | Cabi'nin Kulesi | 8 | 0 |
| 1549085 | Victory 8 Avenger Words | 8 | 0 |
| 1549088 | Victory 8 Worksheets | 8 | 0 |
| 1667796 | Victory 8 True Success Test Book (New Ed.) | 8 | 0 |
| 1546676 | BÇÜ 3-4 YAŞ COSMOLAND EĞİTİM SETİ İNGİLİZCE | BÇU 3-4 | 0 |

### `snv.SinavUrun` — 18/18 ürün aktif, iki dönem de geçerli

Hepsinde `Aktif = 1` · `BirinciDonem = 1` · `IkinciDonem = 1` · `TeslimDonem = 0` · `Kdv = 0`.
Yalnız Cabi'nin Kulesi'nde `OkulTeslim = 1`, gerisi 0.

→ "Sonraki döneme bırakıldı" veya "pasife alındı" açıklaması **geçersiz**.

### `FisteGoster` hipotezi ÇÜRÜDÜ

18 ürünün hepsinde `FisteGoster = 0` olması "fişte gösterilmiyor, o yüzden ödenmiyor" gibi durdu. Dönem 8'in tamamına bakınca korelasyon YOK:

| `FisteGoster` | `OdemesiYapildi` | Kalem | Sipariş |
|---|---|---|---|
| 0 | 0 | 236 | 64 |
| **0** | **1** | **1.947** | **329** |
| 1 | 0 | 163 | 12 |
| 1 | 1 | 1.097 | 49 |

`FisteGoster = 0` olan 2.183 kalemin **1.947'si ödenmiş**. Yani bu bayrak ödeme davranışını açıklamıyor — dönem 8'de baskın (varsayılan) değer.

### Yan bulgu — canlıda TEST verisi

`SinifKitap`'ta MOMO için `SinifId 39 = "TEST 21.06sınıfı"` kaydı duruyor (`FisteGoster = 1`). Canlı sınıf listesinde test sınıfı var; temizlenmeli.

### Yan bulgu — ürün adları iki sistemde FARKLI (aynı StokId)

| StokId | `urn.stkAd` (DerinSIS) | `SinavUrun.StokAd` (BKM) |
|---|---|---|
| 227386 | Duyun Sesimi | **P4C 6 YAŞ DÜŞÜNME KUTUSU VE HİKAYE VE MATERYAL SET** |
| 1546676 | BÇÜ COSMOLAND 36-48 AY EĞİTİM SETİ (2 KİTAP SET) | BÇÜ 3-4 YAŞ COSMOLAND EĞİTİM SETİ İNGİLİZCE |

Aynı ürün iki sistemde farklı isimle duruyor → rapor hangi kaynaktan isim çekerse farklı görünür. 227386 vakası ciddi: "Duyun Sesimi" bir kitap adı, gerçek ürün 3.950 ₺'lik bir eğitim seti.

---

## 8 · EKSİK TUTAR — hesaplandı (§4'ün kısıtı kalktı)

`snv.SiparisDetay.BirimFiyat` NULL ama **`snv.SinavUrun.Fiyat` DOLU**. Eksik kalemlerin TL karşılığı:

| StokId | Ürün | Birim Fiyat | Eksik kalem | **Eksik tutar** |
|---|---|---|---|---|
| **227386** | **P4C 6 YAŞ DÜŞÜNME KUTUSU (a.k.a. "Duyun Sesimi")** | **3.950,00** | **8** | **31.600,00** |
| 1546676 | BÇÜ 3-4 YAŞ COSMOLAND EĞİTİM SETİ | 3.750,00 | 2 | 7.500,00 |
| 1533367 | Koleksiyon Kitaplar - 10 Kitap | 1.500,00 | 4 | 6.000,00 |
| 1666596 | Universal Goals Level 2 | 2.300,00 | 2 | 4.600,00 |
| 1733774 | Doğanın Düzeni 4 Kitap Set | 500,00 | 8 | 4.000,00 |
| 136080 | MOMO | 440,00 | 8 | 3.520,00 |
| 295880 | Fen Köyü Hikaye Serisi (10 Kitap) | 459,00 | 5 | 2.295,00 |
| 1589604 | Bir Aile Macerası - Çikolata Meselesi | 150,00 | 6 | 900,00 |
| 149304 | Gençler İçin Nutuk (Söylev) | 200,00 | 3 | 600,00 |
| 1667796 | Victory 8 True Success Test Book | 540,00 | 1 | 540,00 |
| 1549085 | Victory 8 Avenger Words | 480,00 | 1 | 480,00 |
| 1549088 | Victory 8 Worksheets | 450,00 | 1 | 450,00 |
| 136621 | Öykü Denizi (10 Kitap Takım) | 449,90 | 1 | 449,90 |
| 1679694 | Çook Tatlı Az Tuzlu Hikayeler | 409,00 | 1 | 409,00 |
| 255995 | Laklak Hikaye Serisi 10 Kitap | 329,00 | 1 | 329,00 |
| 1655968 | 3. Sınıf Matematik Hikayeleri | 300,00 | 1 | 300,00 |
| 1733773 | Kendine Yardımcı Ol 4 Kitap Set | 300,00 | 1 | 300,00 |
| 1574032 | Cabi'nin Kulesi | 249,00 | 1 | 249,00 |
| **TOPLAM** | | | **55** | **64.521,90** |

`SinavUrun.Kdv = 0` → tutarlar KDV'siz (kitap/set, %0 KDV).

**Tek ürün (227386) toplamın %49'u.** Ve bu, stoğu negatif (−23) olan ürün → yani en büyük eksik hem tahsil edilmemiş hem tedarik edilemiyor.

### Nihai bölüşüm (dönem 8, 35 kısmi sipariş / 55 kalem / 64.521,90 ₺)

| Sebep | Kalem | Tutar | Ne yapılacak |
|---|---|---|---|
| **Stok yok** (227386 −23 · 1574032 −17) | 9 | **31.849,00** | Tedarik / transfer |
| **Stok var, kasadan geçmemiş** | 46 | **32.672,90** | Tahsilat / kasa kontrolü |
