# K1 — Günlük Kafe Satış Raporu (DIŞ KAYNAK — xlsx)

> **Kafe ayrı POS sistemidir.** EncoreMerkez'de yalnız 3 retail mağaza var
> (M01/M02/M03) ve "Kafe Hammede" kategorisi cüzi (FSM MTD ~19K ₺), oysa
> kafe xlsx'inde FSM günlük ciro ~80-120K ₺. → Kafe verisi erişilebilir
> DB'lerden **üretilemez**; kaynak yalnız bu Excel dosyasıdır.

**Kaynak dosya:** `D:\Temp\GÜNLÜK KAFE SATIŞ RAPORU.xlsx`
**Şubeler:** FSM · İstanbulyolu · Özlüce (3 kafe, retail mağazalarla aynı lokasyon)
**Tarih:** `Belge tarihi` kolonu, ISO `YYYY-MM-DD` (xlsx içi).

## Sayfa (sheet) yapısı

| Sheet | İçerik | Önemli kolonlar (şube başına tekrarlı) |
|---|---|---|
| **Kasa Satış Raporu** | Günlük şube özeti | Belge tarihi · Ciro · Müşteri Sayısı · Sepet Ciro · Satılan Miktar |
| **Kategori Satış Raporu** | Kategori → ürün × şube + TOPLAM | Kategori Adı · AD (ürün) · Ciro · Satılan Miktar |
| **Kasa İptalleri** | Gün × iptal türü × şube | fiş durum (diğer/fiş/satır iptal) · iptal tarihi · şube tutarları |
| **İptal Süresi Analizi** | Geç iptal denetimi | İptal Tarihi · ID · İptal Sebebi · personel/masa/POS bölüm |
| **Ödeme Tipi Raporu** | Gün × ödeme tipi × şube | Toplam Ciro · Sodexho · Ticket · Metropol · SetCard |

## Doğrulanan rakamlar (01-10 Haziran 2026, "Kasa Satış Raporu" Total satırı)

| Şube | Ciro (10 gün) | Müşteri | Sepet Ort. | Satılan Miktar |
|---|---|---|---|---|
| FSM | 934.522 ₺ | 2.248 | 415,71 ₺ | 6.729,5 |
| İstanbulyolu | 718.034 ₺ | 1.731 | 414,81 ₺ | 5.715,5 |
| Özlüce | 1.180.628 ₺ | 3.082 | 383,07 ₺ | — |

Örnek gün (01.06.2026): FSM 82.724 ₺/209 müşteri · İst.Yolu 45.919 ₺/134 · Özlüce 90.053 ₺/237.

## Parse notu (gm-rapor skill için)

- Dosya `openpyxl` / `pandas` ile okunur (`data_only=True`).
- Karakter: xlsx hücreleri Türkçe (UTF-8) — terminal cp857 çıktısında bozuk görünebilir, dosya içeriği sağlam.
- Şube kolonları **yatay gruplu** (her şube için 4 kolon bloğu); başlık 2-3. satırda.
- Toplam satırı: "Total" / "Toplam" anahtarıyla yakala.
- Henüz DB'ye bağlanamıyor → skill bu dosyayı **doğrudan parse edip** GM özetine ekler
  (B-21 kapsamı: kafe haftalık brief'e dahil edilecek).

## Açık iş
- Kafe POS sisteminin DB erişimi araştırılmalı (ayrı sunucu/Express olabilir) →
  bağlanırsa SQL'e taşınır; o güne dek xlsx kanonik kaynak.
