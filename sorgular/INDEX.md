# EncoreMerkez SQL Query Library

Extracted from: encore-merkez-analiz-raporu.html

---

## 🎯 GM RAPOR SİSTEMİ (08.06.2026 — tek harita)

> İş haritası (KPI + neden): [`../docs/rapor-katalogu.md`](../docs/rapor-katalogu.md) · Skill: `/gm-rapor` · Plan: [`../plans/05-envanter-verim-kpi.md`](../plans/05-envanter-verim-kpi.md)
> Dosyalar 7 klasöre dağılmış ama mantıksal set burada. Tümü MCP-doğrulandı.

### Günlük Pano (G0-G7)
| ID | Rapor | Dosya |
|---|---|---|
| G0 | Birleşik günlük toplam (fiziksel+online) | `00-gunluk-pano/10_00b_birlesik-gunluk-toplam.sql` |
| G1 | Günlük GM panosu (net+UPT+WoW+YoY+MTD) | `00-gunluk-pano/10_00_gunluk-gm-panosu.sql` |
| G2 | Ödeme mix (kasa mutabakat) | `02-odeme/gunluk-odeme-mix.sql` |
| G3 | İade kontrolü | `05-iade/gunluk-iade.sql` |
| G4 | Kategori mix (mağaza kırılımlı) | `04-urun/gunluk-kategori-magaza.sql` |
| G5 | Saat bazlı yoğunluk | `06-operasyon/gunluk-saat-bazli.sql` |
| G6 | Anomali bayrağı | `06-operasyon/gunluk-anomali.sql` |
| G7 | E-ticaret kanal (JOKER) | `09-eticaret/gunluk-eticaret-kanal.sql` |

### Envanter Verim (E1-E6)
| ID | Rapor | Dosya |
|---|---|---|
| E1 | Envanter snapshot özet (Sınav hariç) | `08-envanter/envanter-snapshot-ozet.sql` |
| E4+E6 | Devir hızı + Sell-through | `08-envanter/envanter-verim-devir-sellthrough.sql` |
| E5 | GMROI (SSMS, karzarar bağımlı) | `08-envanter/e5-gmroi.sql` |

### Merchandising
| ID | Rapor | Dosya |
|---|---|---|
| A5 | ABC analizi (Pareto 80/20) | `04-urun/abc-analizi.sql` |

> **Açık iş (TODO):** Bu 12 dosyayı fiziksel `sorgular/gm-rapor/` klasörüne taşımak — referans güncellemesi gerektirir (skill/katalog/plan/INDEX), Tier 3 plan-first. Şimdilik bu harita yeterli.

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
