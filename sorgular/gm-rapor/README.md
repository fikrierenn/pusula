# GM Rapor Sistemi — Kendi Kendine Yeten Modül

> Genel Müdür için günlük + aylık rapor seti. Bu klasör **self-contained**: sorgular + notlar + katalog burada.
> Skill: `/gm-rapor` · Kuruldu: 08.06.2026 · Tümü MCP-doğrulandı (07.06.2026 / Mayıs 2026).

## Klasör Yapısı

```
gm-rapor/
├── README.md          ← bu dosya (giriş + harita)
├── KATALOG.md         ← iş haritası (KPI sözlüğü + research bulguları + caveat)
├── gunluk/            ← her gün bakılan (G0-G7)
│   ├── G0-birlesik-toplam.sql       fiziksel + online toplam (online %61!)
│   ├── G1-gm-panosu.sql             net+UPT+WoW+YoY+MTD hedef, mağaza kırılımı
│   ├── G2-odeme-mix.sql             nakit/kart/çek — kasa mutabakat
│   ├── G3-iade.sql                  iade fiş/tutar/oran
│   ├── G4-kategori-magaza.sql       kategori mix, hangi mağaza nerede zayıf
│   ├── G5-saat-bazli.sql            saatlik yoğunluk — vardiya planı
│   ├── G6-anomali.sql               sıfır/neg fiyat + manuel indirim
│   └── G7-eticaret-kanal.sql        JOKER kanal (App/Mobil/Web), ISO tarih
├── envanter/          ← aylık verim (E1-E8)
│   ├── E1-snapshot-ozet.sql         envanter değeri (Sınav Okulları hariç)
│   ├── E4-E6-devir-sellthrough.sql  devir + weeks-of-supply (E7) + sell-through
│   ├── E5-gmroi.sql                 GMROI (SSMS, karzarar bağımlı)
│   └── E8-stockout.sql              stokta yokluk (SKU-level, <%5 hedef)
├── merchandising/
│   ├── A5-abc-analizi.sql           Pareto 80/20
│   └── A6-marka-yayinevi.sql        marka/yayınevi performansı (tedarikçi karnesi)
├── musteri/
│   └── C1-rfm-segmentasyon.sql      RFM omnichannel (e-ticaret JOKER + yazarkasa kart)
└── operasyon/
    └── S1-splh-isgucu-verimi.sql    SPLH (ciro/çalışılan saat, PDKS) + fiş/saat
```

## Kullanım

- **Günlük (sabah, dün kapanışı):** G0 → G1 → G2/G3, anomali varsa G4/G5/G6/G7 drill.
- **Aylık:** E1 envanter → E4-E6 devir/sell-through → E5 GMROI (SSMS) → A5 ABC.
- Skill `/gm-rapor` bunları otomatik çalıştırır + Türkçe formatlar.

## Ortak (paylaşılan) bağımlılıklar — bu klasörde DEĞİL

GM raporları bunlara dayanır ama bunlar GM'e özgü değil, paylaşılan:

| Bağımlılık | Yol | Ne için |
|---|---|---|
| Maliyet motoru (COGS) | `../04-karzarar/2026-05-07-karzarar-v7-prodparity.sql` | E5 GMROI payı (Marj_TL) |
| Envanter gece job | `../envanter_raporu_job_sorgusu.sql` | E1/E4-E6 kaynağı (bkm.ENVANTER_RAPORU doldurur) |
| Haftalık brief otomasyon | `../../scripts/generate_brief.py` | kanonik ciro pattern (G1 buradan türedi) |
| T-SQL kuralları | `../../.claude/rules/sql-server-conventions.md` | DMY/ISO, MCP CTE limiti, ehTip sözlüğü |
| Anomali analizi | `../tum_stoklar_anomali_taramasi.md` | Sınav Okulları hayalet detayı |

## Kritik Notlar (özet — detay KATALOG.md)

- **E-ticaret cironun %61'i** — yalnız fizikseli gösteren rapor yanıltıcı (G0 birleştirir).
- **Sınav Okulları (urnKtgr2ID=19)** tüm envanter raporlarından dışlandı (hayalet stok).
- **Adet-bazlı devir** birim maliyeti sadeleştirir → COGS gerekmez, enflasyondan bağımsız.
- **MCP CTE çalışmaz** — günlük sorgular CTE'siz; tam analiz SSMS.
- **E5 GMROI henüz SSMS'te doğrulanmadı** (pay=karzarar) — TODO B-26.

## Açık İşler (TODO.md)
B-26 (E5 SSMS doğrula) · B-27 (G1 12sn perf) · B-28 (RFM) · B-29 (birleşik haftalık) · B-32 (günlük mail).
