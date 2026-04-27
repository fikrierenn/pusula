# 03 — Ciro Raporu Standart Filtreleri

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)

## Varsayılan Filtre Seti (perakende + B2B)

```sql
WHERE H.ehMekan   IN (1, 4477, 4478)         -- FSM, Özlüce, İst.Yolu
  AND H.ehTip     IN (4, 5, 100, 101)        -- 4=Mağaza Satış, 100=POS Satış, 5=Mağaza İade, 101=POS İade
  AND H.ehAltDepo = 0                         -- WMS iç transferleri hariç
  AND U.Kategori3 <> N'Genel'                 -- Çöp kovası (muhasebe hesap kodları, demirbaş)
  AND H.ehstkID   <> 583160                   -- Geri Dönüşüm Kağıt (hammadde alımı, satış değil)
```

- **Genel kategorisi:** 88 SKU, muhasebe hesap kodları + tanımsız ürünler. Temizlik projesi ayrı.
- **stkID 583160:** Gider pusulasıyla hammadde alımı.

## Template Sorgular

- `D:\Belgelerim\sql\sorgular\5_CIRO_KATEGORI_MART2026.sql` — aylık kategori
- `D:\Belgelerim\sql\sorgular\6_CIRO_MAGAZA_KATEGORI_MART2026.sql` — mağaza × kategori çapraz

## Bilinen Ciro Anomalileri

### Sınav Okulları Mart 2026 %19,21 iade tutarı
Anormal değil. **3 öğrenci kaydını iptal etti**, paketler geri döndü. Sezon dışı (sınav işi yaz/güz) olduğu için tek olay kategoriye büyük oranda yansıdı. Kök sebep yok, normal operasyon.

## MaliyetRaporu-Ceren Job

- SQL Agent Job, her gün 00:05'te çalışır
- `bkm.ENVANTER_RAPORU`'nu doldurur
- Mevcut filtre: `WHERE U.urnKtgr2ID NOT IN (11,25,23,9,5,6) AND urnTip=0`
- Envanter distorsiyonu için önerilen ek filtre: [`06-envanter-bulgular.md`](06-envanter-bulgular.md)
- Orijinal SQL: [`../sorgular/envanter_raporu_job_sorgusu.sql`](../sorgular/envanter_raporu_job_sorgusu.sql)

## Sınav / Perakende Ayrımı

`irsHrk`'ya kolon eklemeden Sınav ↔ Retail ayrıştırması için POS köprüsü kullan → [`04-kanal-koprusu.md`](04-kanal-koprusu.md)
