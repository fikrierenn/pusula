---
name: gm-rapor
description: Genel Müdür rapor panosu. "günlük rapor", "dün ne oldu", "GM panosu", "haftalık özet", "envanter durumu", "stok raporu", "bugünkü rapor" gibi ifadelerde veya /gm-rapor çağrısında devreye girer. docs/rapor-katalogu.md'deki raporları MCP üzerinden çalıştırıp Türkçe formatlı özet basar. Mod: günlük (G1-G7) / haftalık (P1-P8) / envanter (E1-E3). Anomali bayraklarını otomatik işaretler.
allowed-tools: Read, Bash, Grep, Glob, mcp__sqlserver__sql_query
user-invocable: true
model: inherit
---

# GM Rapor Skill

## Amaç
Genel Müdür gözüyle "her gün" + "her Pazartesi" + "envanter" raporlarını tek komutla çalıştırıp Türkçe özet basar. Kaynak haritası: [`docs/rapor-katalogu.md`](../../../docs/rapor-katalogu.md).

## Modlar

| Tetik | Mod | Çalışan |
|---|---|---|
| "günlük", "dün ne oldu", "bugünkü rapor", argümansız | **GÜNLÜK** | G1 (zorunlu) + G2/G3 (anomali varsa drill) |
| "haftalık", "pazartesi", "hafta özeti" | **HAFTALIK** | P1 mevcut brief'i göster + P2/P4 drill |
| "envanter", "stok", "depo değeri" | **ENVANTER** | E1 snapshot + E2 anomali |
| "tam", "full", "hepsi" | **TÜM** | Günlük + Envanter anomali bir arada |

## ÖNEMLİ — MCP CTE limiti

`mcp__sqlserver__sql_query` CTE'leri auto-TOP wrap edip kırıyor (`WITH...` parantezlenince syntax hatası). Bu skill **CTE'siz, tek-SELECT, ORDER BY'sız** MCP-hazır bloklar kullanır. Tam `.sql` dosyaları (CTE'li, DECLARE'li) SSMS içindir.

---

## GÜNLÜK MOD

### Adım 1 — Gün belirle
Argümanda tarih yoksa **dün** = `CAST(DATEADD(DAY,-1,GETDATE()) AS date)`. Kullanıcı "5 Haziran" derse `CONVERT(date,'05.06.2026',104)`.

### Adım 2 — G1 mağaza panosu (MCP-hazır, dün için)
```sql
SELECT MG.mekanID,
    CASE MG.mekanID WHEN 1 THEN 'FSM' WHEN 4477 THEN 'Ozluce' WHEN 4478 THEN 'IstYolu' END AS Magaza,
    CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) AS decimal(18,2)) AS NetCiro,
    SUM(IIF(s.DocumentsTypeId=3,-1,1)) AS Fis,
    SUM(IIF(s.DocumentsTypeId=3,1,0)) AS IadeFis,
    CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal))
       / NULLIF(SUM(IIF(s.DocumentsTypeId=3,-1,1)),0) AS decimal(18,2)) AS SepetOrt
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK) ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK) ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
WHERE s.Date>=CAST('YYYYMMDD' AS date) AND s.Date<CAST('YYYYMMDD+1' AS date) AND spb.Id IS NULL
GROUP BY MG.mekanID;
```
`YYYYMMDD` = hedef gün, `YYYYMMDD+1` = ertesi gün (ISO literal, ör. `'20260607'` / `'20260608'`).

WoW + MTD hedef için aynı pattern'i geçen hafta aynı gün ve ay-başı→gün aralığıyla 2 kez daha çalıştır, veya tam tablo `sorgular/00-gunluk-pano/10_00_gunluk-gm-panosu.sql`'i SSMS'te aç.

### Adım 3 — Çıktı formatı (Türkçe)
```
BKM GÜNLÜK PANO — DD.MM.YYYY (Gün)
─────────────────────────────────
Mağaza      Net Ciro      Fiş    Sepet   WoW
Özlüce      X TL          N      Y TL    +%Z
FSM         ...
İst.Yolu    ...
TOPLAM      ... TL        ...    ... TL  %...
MTD gerçekleşme: %... (hedef ... TL)
```
Bin ayracı nokta, ondalık virgül (TR). Yüzde virgüllü.

### Adım 4 — Anomali bayrağı
Şu durumda **G2/G3'e drill** + uyar:
- Bir mağaza WoW < -%20 → "X mağaza geçen haftaya göre düştü"
- İade fiş / toplam fiş > %5 → G3 (`05-iade/10_14_iade-analizi.sql`)
- Sepet ort bir mağazada diğerlerinin yarısı → kategori karışım sinyali (B-08)

---

## HAFTALIK MOD

### Adım 1 — Son brief'i göster
```bash
ls -t briefings/*/brief.txt | head -1
```
Oku, özetini bas. Brief otomatik (Pzt 09:00, `scripts/generate_brief.py`) — yeniden üretme, mevcut olanı göster.

### Adım 2 — Drill (istenirse)
- P2 kategori trend → `01-ciro/2026-05-08-ciro-magaza-kategori-aratoplamli.sql`
- P4 kâr/zarar marj → `04-karzarar/2026-05-07-karzarar-v7-prodparity.sql`
- P3 kampanya → `03-kampanya/10_07_3al2ode-detay.sql`

---

## ENVANTER MOD

### Adım 1 — E1 snapshot (MCP-hazır)
```sql
SELECT [Maliyet Tipi] AS Baz,
    CAST(SUM([FSM Stok Maliyet]) AS decimal(18,2)) AS FSM,
    CAST(SUM([Özlüce Stok Maliyet]) AS decimal(18,2)) AS Ozluce,
    CAST(SUM([İst.Yolu Stok Maliyet]) AS decimal(18,2)) AS IstYolu,
    CAST(SUM([Merkez Depo Stok Maliyet]) AS decimal(18,2)) AS WMS,
    CAST(SUM([Odak Depo Stok Maliyet]) AS decimal(18,2)) AS Odak,
    CAST(SUM([FSM Stok Maliyet]+[Özlüce Stok Maliyet]+[İst.Yolu Stok Maliyet]
           +[Merkez Depo Stok Maliyet]+[Odak Depo Stok Maliyet]) AS decimal(18,2)) AS Toplam
FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
WHERE Tarih=(SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU)
GROUP BY [Maliyet Tipi];
```
`database: DerinSISBkm` parametresi ver.

### Adım 2 — Anomali bayrağı (E2) — ZORUNLU uyarı
- **İst.Yolu ÜstFiyat negatifse** → "⚠️ İst.Yolu ÜstFiyat bazı hayalet negatif (Sınav Okulları süreli yayın paketleri, urnKtgr2ID=19). Gerçek envanter için **Ort.Maliyet** bazını kullan." Detay: `sorgular/tum_stoklar_anomali_taramasi.md`.
- GM'e **Ort.Maliyet** bazını birincil göster, ÜstFiyat'ı ikincil.

### Adım 3 — Drill
- Kategori bazlı: E1 sorgusundaki yorumlu kategori bloğu (`08-envanter/envanter-snapshot-ozet.sql`).
- Canlı/anlık (gece snapshot değil): `sorgular/envanter_raporu_job_sorgusu.sql` (ağır, SSMS).

### Adım 4 — Verim KPI (E4 Devir + E6 Sell-through)
Kullanıcı "devir", "sell-through", "ölü stok", "verim" derse → `08-envanter/envanter-verim-devir-sellthrough.sql` (kategori bazlı, aylık). MCP'de de çalışır (derived table, CTE değil). `@AyBas`/`@AySon` ay sınırı ver.
- **Devir (adet bazlı)** = Satılan / Ort. stok adet ×12. Düşük (Kitap ~1,5x) = derin katalog; yüksek (Dergi ~8,5x) = hızlı tüketim. **Enflasyondan etkilenmez.**
- **Sell-through** = Satılan / (Açılış stok + Gelen). Düşük = yavaş eriyen → clearance adayı.
- Hareket tipi: satış 4/100, gelen 10 (alış)+13 (depo transfer). Sınav Okulları hayalet hariç.
- **E5 GMROI** henüz yok (karzarar COGS gerekli, SSMS) — sorulursa "Plan 05 E5 bekliyor" de.

---

## Kaynak Sorgu Haritası
Tüm eşleşmeler [`docs/rapor-katalogu.md`](../../../docs/rapor-katalogu.md)'de. Rapor ID (G1/P4/E1...) → `.sql` dosyası.

## Dikkat
1. MCP'de CTE çalışmaz — yukarıdaki tek-SELECT blokları kullan. Tam analiz SSMS'te `.sql` dosyası.
2. Sayı formatı TR (1.234.567,89). Mağaza adları: FSM / Özlüce / İst.Yolu.
3. Kapsam: 3 fiziksel Bursa mağazası. E-ticaret/Heykel/kafe dahil değil (B-21).
4. Envanter: Ort.Maliyet birincil, ÜstFiyat hayalet negatif içerir.
5. Geri dönüşüm fişi (BarcodeNo='1001') hariç tutulur.
6. "Bitti" demeden önce sayıyı bilinen referansla kıyasla (brief satırı / önceki gün).

## İlişkili Dosyalar
- `docs/rapor-katalogu.md` — rapor → sorgu haritası
- `sorgular/00-gunluk-pano/10_00_gunluk-gm-panosu.sql` — G1 tam (SSMS)
- `sorgular/08-envanter/envanter-snapshot-ozet.sql` — E1 tam
- `scripts/generate_brief.py` — P1 haftalık otomatik
- `.claude/rules/sql-server-conventions.md` — T-SQL kuralları
