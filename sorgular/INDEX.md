# EncoreMerkez SQL Query Library

Extracted from: encore-merkez-analiz-raporu.html

---

## 🎯 GM RAPOR SİSTEMİ → self-contained klasör: [`gm-rapor/`](gm-rapor/)

> Tüm GM raporları kendi modülünde toplandı (08.06.2026 reorg). Giriş + harita: [`gm-rapor/README.md`](gm-rapor/README.md) · İş haritası: [`gm-rapor/KATALOG.md`](gm-rapor/KATALOG.md) · Skill: `/gm-rapor` · Plan: [`../plans/05-envanter-verim-kpi.md`](../plans/05-envanter-verim-kpi.md)

| Set | Raporlar | Klasör |
|---|---|---|
| Günlük (G0-G7) | birleşik toplam, GM panosu, ödeme, iade, kategori, saat, anomali, e-ticaret | `gm-rapor/gunluk/` |
| Envanter (E1-E8) | snapshot, devir, weeks-of-supply, sell-through, GMROI, stockout | `gm-rapor/envanter/` |
| Merchandising (A5-A6) | ABC (Pareto 80/20), marka/yayınevi | `gm-rapor/merchandising/` |
| Müşteri (C1) | RFM omnichannel (e-ticaret + yazarkasa) | `gm-rapor/musteri/` |
| Operasyon (S1) | SPLH işgücü verimi (PDKS) | `gm-rapor/operasyon/` |

Tümü MCP-doğrulandı. Ortak bağımlılıklar (karzarar maliyet motoru, envanter job, brief otomasyon, conventions) GM klasöründe DEĞİL — `gm-rapor/README.md` § Ortak bağımlılıklar.

---

## 1. Cirolar (Queries 10.1-10.3)

- **10.01** → `01-ciro/10_01_gunluk-ciro-kampanya-kirilimi.sql`
- **10.02** → `01-ciro/10_02_aylik-ciro-trend.sql`
- **10.03** → `01-ciro/10_03_magaza-bazli-ciro.sql`

## 2. Ödeme Türleri (Query 10.4)

- **10.04** → `02-odeme/10_04_odeme-tipi-dagilimi.sql`

## 3. Kampanyalar (Queries 10.5-10.11, 10.22)

- **10.05** → `03-kampanya/10_05_tum-kampanyalar.sql`
- **10.06** → `03-kampanya/10_06_kampanya-tipi.sql`
- **10.07** → `03-kampanya/10_07_3al2ode-detay.sql`
- **10.08** → `03-kampanya/10_08_kampanya-aylik-trend.sql`
- **10.09** → `03-kampanya/10_09_magaza-kampanya.sql`
- **10.10** → `03-kampanya/10_10_sepet-karsilastirmasi.sql`
- **10.11** → `03-kampanya/10_11_kampanya-en-cok-satan.sql`
- **10.22** → `03-kampanya/10_22_kampanya-tanimlari.sql`

## 4. Ürünler (Queries 10.12-10.13, 10.21)

- **10.12** → `04-urun/10_12_kategori-bazli.sql`
- **10.13** → `04-urun/10_13_marka-bazli.sql`
- **10.21** → `04-urun/10_21_en-cok-satan.sql`

## 5. İadeler (Queries 10.14-10.15)

- **10.14** → `05-iade/10_14_iade-analizi.sql`
- **10.15** → `05-iade/10_15_campaignid-null.sql`

## 6. Operasyon (Queries 10.16-10.19)

- **10.16** → `06-operasyon/10_16_kasiyer.sql`
- **10.17** → `06-operasyon/10_17_saat-bazli.sql`
- **10.18** → `06-operasyon/10_18_gun-sonu.sql`
- **10.19** → `06-operasyon/10_19_fiyat-kontrol.sql`

## 7. Sistem (Query 10.20)

- **10.20** → `07-sistem/10_20_sistem-istatistikleri.sql`
