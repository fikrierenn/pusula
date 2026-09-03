# plan 41 — `bkm.IrsTipGrupMap` doldurma önerisi (ONAY BEKLİYOR, yazma yapılmadı)

**Durum:** öneri · **Tarih:** 03.09.2026 · **Karar:** kullanıcı ("önce öneri getir, sonra karar")
**Kapsam:** `DerinSISBkm.bkm.IrsTipGrupMap` (app-owned `bkm` şeması, **şu an 0 satır**)

## Problem

Raporlarda hareket tipi listeleri **elle** yazılı: `ehTip IN (4,100)` satış, `IN (5,101)` iade,
`IN (0,10)` alış… Aynı liste `dashboard/Data/OdakQueries.cs`, `RefQueries.Envanter.cs`,
`scripts/olu_stok_excel.py`, `scripts/cok_satan_*.py` ve arşiv SQL'lerinde tekrarlanıyor.
Bugün ölçüldü: **kod kümesi 34, sema'da 20 belgeliydi** — 8 kod hiç yazılmamıştı
(88 Diğer Giriş 364K hareket dahil). Tek kaynak olmadığı için bir kod eklendiğinde
hangi raporun güncellendiği takip edilemiyor.

`bkm.IrsTipGrupMap` bu iş için **zaten tasarlanmış** (21 kolon: `TipId` · `AnaGrupKodu` ·
`SatisPaydaMi` · `AlisMi` · `SatisMi` · `TransferMi` · `SirketIciMi` · `SayimMi` ·
`DuzeltmeMi` · `DigerGirisMi` · `DigerCikisMi` · `ImhaBozukMi` · `OzetHesabaDahilMi` ·
`AktifMi` …) ama **hiç doldurulmamış**.

## ÖLÇÜLDÜ — 34 kodun canlı davranışı (2026-09-03, `dbo.irsHrk` tüm zaman)

`ort_adet` işareti giriş(+)/çıkış(−) demektir; boş hareket = kod tanımlı ama kullanılmamış.

| Kod | Ad | Hareket | Ort adet | Net adet |
|---|---|---:|---:|---:|
| 0 | Alış | 1.458.421 | +21,9 | +31.983.007 |
| 1 | Satış | 31.193.033 | −1,4 | −44.066.121 |
| 2 | Alış İade | 154.928 | −14,4 | −2.224.161 |
| 3 | Satış İade | 510.578 | +1,5 | +758.771 |
| 4 | Mağaza Satış | 245.743 | −3,8 | −927.173 |
| 5 | Mağaza Satış İade | 2.634 | +6,4 | +16.890 |
| 6 | Hizmet | 0 | — | — |
| 7 | Gider | 0 | — | — |
| 8 | Mağaza Mağaza | 113.142 | 0,0 | −902 |
| 9 | Mağaza Depo | 1.356.363 | −0,8 | −1.114.853 |
| 10 | Yerel Alım | 2.370.431 | +7,2 | +16.979.774 |
| 11 | Depo Depo | 4.196.550 | −0,1 | −309.858 |
| 12 | Alış Mağaza İade | 145.366 | −4,0 | −587.067 |
| 13 | Depo Mağaza | 984.403 | −0,1 | −98.983 |
| 14 | İade ve İmha | 1 | −1,0 | −1 |
| 15 | Örnek Alımı | 0 | — | — |
| 16 | **Stok EKLE** | 1.002.914 | **+459,0** | **+460.295.776** |
| 17 | Merkezi Düzeltme | 1.750 | +3,5 | +6.129 |
| 18 | Mağaza İçi İşlemler | 12 | 0,0 | 0 |
| 86 | Ürün Değişim | 0 | — | — |
| 88 | Diğer Giriş | 364.226 | +67,2 | +24.487.328 |
| 89 | Diğer Çıkış | 28.935 | −1.408,4 | −40.752.649 |
| 90 | **Ürün SAY** | 160.257 | **−2.843,6** | **−455.710.798** |
| 91 | Rakipten Ürün Alış | 0 | — | — |
| 92 | Boş Paket Çıkışı | 2.963 | −1,6 | −4.796 |
| 93 | Müşteriden Bozuk İade | 0 | — | — |
| 94 | SKT Nedeniyle | 0 | — | — |
| 95 | Dönüşüm | 570 | −238,8 | −136.107 |
| 96 | Bozuk Ürün | 31.749 | −1,8 | −57.116 |
| 97 | Devir | 0 | — | — |
| 98 | Şirket İçi Kullanım | 8.667 | −12,8 | −110.885 |
| 99 | Sayım | 2.865.110 | +12,3 | +35.316.706 |
| 100 | POS Satış | 11.636.851 | −1,9 | −22.604.208 |
| 101 | POS Satış İade | 216.873 | +9,5 | +2.069.857 |

**Ölçümün en önemli çıktısı:** `16 Stok EKLE` (+460,3M) ile `90 Ürün SAY` (−455,7M)
neredeyse birbirini götürüyor ve ikisi de satış hacminin (−44M) **on katı**. Yani tip
filtresi olmayan her "toplam hareket" toplamı bu çiftin gürültüsüne boğulur —
`OzetHesabaDahilMi` bayrağının varlık sebebi tam bu.

## ÖNERİ — grup ataması

`AnaGrupKodu` (kaba grup) + bayraklar. **Etiketler ÇIKARIM'dır**: ad + işaret + hacimden
türetildi, İK/muhasebe teyidi yok. Onaydan önce tartışılacak satırlar ⚠ ile işaretli.

| Kod(lar) | AnaGrupKodu | Bayraklar | Gerekçe |
|---|---|---|---|
| 1, 4, 100 | `SATIS` | `SatisMi`, `SatisPaydaMi`, `OzetHesabaDahil` | çıkış(−); mevcut raporların satış tanımı (4/100 perakende, 1 sevk/fatura) |
| 3, 5, 101 | `IADE_MUSTERI` | `MusteriIadePayMi`, `OzetHesabaDahil` | giriş(+); satışın negatifi |
| 0, 10 | `ALIS` | `AlisMi`, `OzetHesabaDahil` | giriş(+); 10 Yerel Alım tedarikçi girişi |
| 2, 12 | `IADE_TEDARIKCI` | `AlisMi`=0, `OzetHesabaDahil` | çıkış(−); alışın negatifi |
| 8, 9, 11, 13 | `TRANSFER` | `TransferMi` | net ≈ 0 (kendi içinde kapanıyor); ciroya girmez |
| 16, 90, 99 | `SAYIM` | `SayimMi`, `OzetHesabaDahil`=**0** ⚠ | sayım düzeltme çifti; toplamı domine ediyor (yukarıdaki ölçüm) |
| 17 | `DUZELTME` | `DuzeltmeMi` | merkezi düzeltme, 1.750 hareket |
| 88 | `DIGER_GIRIS` | `DigerGirisMi` ⚠ | +24,5M giriş — **ne olduğu bilinmiyor**, İK/IT teyidi gerek |
| 89, 92 | `DIGER_CIKIS` | `DigerCikisMi` ⚠ | −40,8M çıkış; 89'un ort −1.408 olması toplu/parti çıkış işareti |
| 14, 94, 96 | `IMHA_BOZUK` | `ImhaBozukMi`, `BozukIadePayMi` (96) | 96 Bozuk Ürün 31.749 hareket; 14/94 kullanılmıyor |
| 93 | `IADE_BOZUK` | `BozukIadePayMi` | tanımlı ama kullanılmıyor |
| 95 | `DONUSUM` | `SirketIciMi`=0, `DuzeltmeMi` ⚠ | 570 hareket, ort −238,8; muhtemelen set/paket bozma |
| 98, 18 | `SIRKET_ICI` | `SirketIciMi` | şirket içi kullanım (−110.885) + mağaza içi işlem |
| 6, 7 | `HIZMET_GIDER` | hepsi 0, `OzetHesabaDahil`=0 | stok hareketi yok (fatura tarafı) |
| 15, 86, 91, 97 | ilgili grup | `AktifMi`=**0** | tanımlı, canlıda hiç kullanılmamış — silinmez, pasif işaretlenir |

## Açık sorular (onaydan önce)

1. **88 Diğer Giriş / 89 Diğer Çıkış nedir?** İkisi birlikte ±65M adet. İş anlamı
   bilinmeden `OzetHesabaDahilMi` kararı verilemez → **teyit gerekiyor** (IT/depo).
2. **16 + 90 çifti** gerçekten sayım mekanizması mı, yoksa WMS'in başka bir işlemi mi?
   Toplamı domine ettiği için yanlış bayrak tüm stok özetini bozar.
3. `SatisPaydaMi`'ya `1 Satış` (sevk/fatura) dahil mi? Bulunurluk/OSA oranlarında bugün
   yalnız 4/100 kullanılıyor; 1'i eklemek B2B'yi perakende paydasına karıştırır.
4. `95 Dönüşüm` set bozma mı, ürün değişimi mi (86 ayrı kod olduğu için belirsiz).

## Yazma izni

`bkm.IrsTipGrupMap` **app-owned** (`bkm` şeması Fikri'nin namespace'i) ama
`.claude/rules/erp-write-policy.md` izin listesinde **yok**. Doldurma kararı verilirse:
1. Bu plan onaylanır (yukarıdaki 4 soru cevaplanır),
2. `erp-write-policy.md` izin listesine `bkm.IrsTipGrupMap` eklenir,
3. Seed script `sorgular/` altına yazılır (idempotent `MERGE`, 34 satır),
4. Doldurulduktan sonra raporlar **kademeli** olarak bu tabloyu okumaya geçirilir
   (önce bir rapor + rakam mutabakatı; hepsini birden değiştirmek yasak),
5. `sema/codes.yaml` → `irsHrk.ehTip` kaydına "grup ataması `bkm.IrsTipGrupMap`'ten okunur"
   notu + değişmez: tablo satır sayısı = `dbo.irsTip_vw` kod sayısı (kod eklenince kırmızı).

## Done kriteri (doldurulursa)

- [ ] 34 satır yazıldı, `TipId` ↔ `irsTip_vw.tipID` birebir (değişmezle korunuyor)
- [ ] En az bir rapor tablodan okuyor ve **eski/yeni rakam birebir tutuyor**
- [ ] Açık soruların cevabı `Aciklama` kolonuna yazıldı (teyit kaynağı belirtilerek)
- [ ] Kalan raporlar için TODO maddesi açıldı

## Rollback

Tablo boşaltılır (`DELETE FROM bkm.IrsTipGrupMap`), raporlar elle listeye döner —
kademeli geçiş sayesinde her adım tek başına geri alınabilir.
