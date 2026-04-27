# 06 — Envanter Soruşturması Bulguları

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)
> **Master index:** [`../sorgular/SESSION.md`](../sorgular/SESSION.md)

## Problem

İst.Yolu envanter raporu **−54M TL** (negatif) → "imkansız".

## Kök Neden

Kategori3 = "Sınav Okulları" altındaki **22 süreli yayın paketi** İst.Yolu'nda **paket koduyla çıkış / parça koduyla giriş** yapıldığı için bakiye eksiye düşüyor. Tek başına etki: **−299.9M TL**.

### Bilateral Distorsiyon

- (a) Paket kodları → **−299,9M TL** (negatif hayalet)
- (b) Aynı kategorideki parça/modül kodları → **+30M TL** (pozitif hayalet)
- (c) Normal kitaplar (Duyun Sesimi, Options 1) → −2,8M TL + stkID duplikasyonu

**Net düzeltilebilir:** ~120 SKU, **~−268M TL**
**Düzelme sonrası beklenen envanter:** ~3,0 milyar TL (şu an 2,7 milyar)

## 10 Anomali Kategorisi

| # | Kategori | SKU | Tutar |
|---|---|---:|---:|
| A | Sınav paketi hayalet negatif | 22 | −299,9M |
| B | Sınav parça hayalet pozitif | 17 | +30,0M |
| C | stkID duplikasyonu (Options 1 vb) | 3 | nötr |
| D | Hazırlık Kitapları (6.Sınıf Yaz Tatil) | 1 | −199K |
| E | Fiyat hatası adayları (Mileo 1999, Yılbaşı 7990) | 11 | +4,3M |
| F | Ölü stok (Noki Tumbler vb) | 8 | +547K+ |
| G | WMS aşırı birikim (Note Defter 97K, Touch Marker 50K adet) | 14 | büyük |
| H | Duplikat stkID grupları (Note The Time 17 SKU, OBM Harry Potter 12) | ~22 | nötr |
| I | Mağaza dengesizliği | 17 | dağılım |
| J | Kategori hijyeni (Tanımsız 17.544 SKU, Akademi 116.550) | binlerce | yapısal |

## Önerilen Aksiyonlar

### 1. Job'a Exclude Ekle (en hızlı, tek satır)

```sql
AND NOT (U.urnKtgrID = 78 AND U.urnKtgr1ID = 5 AND U.urnKtgr2ID = 19)
```
→ İst.Yolu üst fiyatı **−53,6M → +182,2M TL** düzelir.

### 2. Yeni Kategori3 Aç

"Sınav Süreli Yayın" → 193 ürünü taşı (kalıcı çözüm).

### 3. stkID Duplikasyon Konsolidasyonu (IT'ye)

- Options 1 Student's Book: 1673526 ↔ 1668021
- Note The Time: 17 SKU
- OBM Harry Potter: 12 SKU

### 4. Fiziksel Sayım

- The Edd Duygulu Mini Not Defter — 97.178 adet
- Touch Marker — 49.696 adet
- Mileo Fon Kartonu — 1.999 TL fiyat doğrulaması

## Bekleyen İşler

- [ ] **Satış & Ciro Analizi** — kullanıcı seçti, bağlantı bloke etti
- [ ] Maliyet/Kâr analizi (FIFO yansıtma)
- [ ] Cari/müşteri segmentasyonu
- [ ] Tedarikçi performansı
- [ ] ERP genel sağlık check
- [ ] Job/Rapor mimarisi review

## Dosya Zinciri (`../sorgular/`)

1. `envanter_raporu_job_sorgusu.sql` — Orijinal job SQL
2. `envanter_raporu_analiz.md` — İlk analiz
3. `kontrol_gun_bazli_detay.sql` — Gün bazlı kontrol
4. `sorunlu_urunler_tutar_detay.md` — 22 paket, FSM/Özlüce/İstYolu kırılımı
5. `tum_stoklar_anomali_taramasi.md` — 3 anomali kümesi
6. `envanter_derin_analiz.md` — 11 bölümlü kapsamlı rapor
7. `urun_listesi_tespitler.md` — 10 bölümlü ürün-bazlı A-J
