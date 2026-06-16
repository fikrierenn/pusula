---
name: gm-rapor
description: Genel Müdür rapor panosu. "günlük rapor", "dün ne oldu", "GM panosu", "haftalık özet", "envanter durumu", "stok raporu", "bugünkü rapor", "kargo", "bekleyen sipariş", "hedef gerçekleşen", "kampanya raporu", "kafe satış" gibi ifadelerde veya /gm-rapor çağrısında devreye girer. sorgular/gm-rapor/KATALOG.md'deki raporları MCP üzerinden çalıştırıp Türkçe formatlı özet basar. Mod: günlük (G) / haftalık (P) / envanter (E) / e-ticaret-lojistik (L) / mağaza hedef-kampanya (M) / kafe (K). Anomali bayraklarını otomatik işaretler.
allowed-tools: Read, Bash, Grep, Glob, mcp__sqlserver__sql_query
user-invocable: true
model: inherit
---

# GM Rapor Skill

## Amaç
Genel Müdür gözüyle "her gün" + "her Pazartesi" + "envanter" raporlarını tek komutla çalıştırıp Türkçe özet basar. Kaynak haritası: [`sorgular/gm-rapor/KATALOG.md`](../../../sorgular/gm-rapor/KATALOG.md).

## Modlar

| Tetik | Mod | Çalışan |
|---|---|---|
| "günlük", "dün ne oldu", "bugünkü rapor", argümansız | **GÜNLÜK** | G1 (zorunlu) + G2/G3 (anomali varsa drill) |
| "haftalık", "pazartesi", "hafta özeti" | **HAFTALIK** | P1 mevcut brief'i göster + P2/P4 drill |
| "envanter", "stok", "depo değeri" | **ENVANTER** | E1 snapshot + E2 anomali |
| "kargo", "lojistik", "bekleyen sipariş", "kargo firma" | **E-TİCARET/LOJİSTİK** | L1 kargo firma + L2 günlük çıkış + L3 bekleyen |
| "hedef", "gerçekleşme", "kampanya raporu", "mağaza kategori hedef" | **MAĞAZA** | M1 hedef/gerçekleşen + M2 kampanya |
| "kafe", "kafe satış", "günlük kafe" | **KAFE** | K1 xlsx parse (DB yok) |
| "tam", "full", "hepsi" | **TÜM** | Günlük + Envanter anomali bir arada |

## ÖNEMLİ — MCP CTE limiti

`mcp__sqlserver__sql_query` CTE'leri auto-TOP wrap edip kırıyor (`WITH...` parantezlenince syntax hatası). Bu skill **CTE'siz, tek-SELECT, ORDER BY'sız** MCP-hazır bloklar kullanır. Tam `.sql` dosyaları (CTE'li, DECLARE'li) SSMS içindir.

---

## GÜNLÜK MOD

### Adım 0 — Birleşik toplam (G0, ÖNCE göster)
GERÇEK günlük resim fiziksel + online. `gm-rapor/gunluk/G0-birlesik-toplam.sql`. E-ticaret (JOKER, ISO tarih) genelde cironun **%50+**'si — yalnız fizikseli göstermek yanıltıcı. İki kaynak MCP'de ayrı çalıştırılıp toplanır (cross-source).

### Adım 1 — Gün belirle
Argümanda tarih yoksa **dün** = `CAST(DATEADD(DAY,-1,GETDATE()) AS date)`. Kullanıcı "5 Haziran" derse `CONVERT(date,'05.06.2026',104)`. E-ticaret tarafı ISO `'YYYYMMDD'` (JOKER linked server).

### Adım 2 — G1 mağaza panosu (MCP-hazır, dün için)
```sql
SELECT MG.mekanID,
    CASE MG.mekanID WHEN 1 THEN 'FSM' WHEN 4477 THEN 'Ozluce' WHEN 4478 THEN 'IstYolu' END AS Magaza,
    CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS decimal(18,2)) AS NetCiro,
    SUM(IIF(s.DocumentsTypeId=3,-1,1)) AS Fis,
    SUM(IIF(s.DocumentsTypeId=3,1,0)) AS IadeFis,
    CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal-s.VatTotal))
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

WoW + MTD hedef için aynı pattern'i geçen hafta aynı gün ve ay-başı→gün aralığıyla 2 kez daha çalıştır, veya tam tablo `sorgular/gm-rapor/gunluk/G1-gm-panosu.sql`'i SSMS'te aç.

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
  AND KTGR3 NOT IN (N'Sınav Okulları', N'Dergi')   -- hayalet stok hariç (her zaman)
GROUP BY [Maliyet Tipi];
```
`database: DerinSISBkm` parametresi ver. Doğrulama (08.06, Sınav hariç): Ort.Maliyet toplam 1.198M ₺.

### Adım 2 — Anomali bayrağı (E2)
- **Sınav Okulları artık ENVANTER DIŞI** (sorguda filtreli) — İst.Yolu'ndaki ±sahte değer (ÜstFiyat −190M / Ort.Maliyet +149M) temizlendi. Retail envanteri değil, Sınav Okulu operasyonu.
- GM'e **Ort.Maliyet** bazını birincil göster, ÜstFiyat'ı ikincil.
- Başka kategori negatif/aşırı çıkarsa raporla (yeni anomali): `sorgular/tum_stoklar_anomali_taramasi.md`.

### Adım 3 — Drill
- Kategori bazlı: E1 sorgusundaki yorumlu kategori bloğu (`gm-rapor/envanter/E1-snapshot-ozet.sql`).
- Canlı/anlık (gece snapshot değil): `sorgular/envanter_raporu_job_sorgusu.sql` (ağır, SSMS).

### Adım 4 — Verim KPI (E4 Devir + E6 Sell-through)
Kullanıcı "devir", "sell-through", "ölü stok", "verim" derse → `gm-rapor/envanter/E4-E6-devir-sellthrough.sql` (kategori bazlı, aylık). MCP'de de çalışır (derived table, CTE değil). `@AyBas`/`@AySon` ay sınırı ver.
- **Devir (adet bazlı)** = Satılan / Ort. stok adet ×12. Düşük (Kitap ~1,5x) = derin katalog; yüksek (Dergi ~8,5x) = hızlı tüketim. **Enflasyondan etkilenmez.**
- **Sell-through** = Satılan / (Açılış stok + Gelen). Düşük = yavaş eriyen → clearance adayı.
- Hareket tipi: satış 4/100, gelen 10 (alış)+13 (depo transfer). Sınav Okulları hayalet hariç.
- **E5 GMROI** henüz yok (karzarar COGS gerekli, SSMS) — sorulursa "Plan 05 E5 bekliyor" de.

---

## E-TİCARET / LOJİSTİK MOD (L)

Kaynak: `ODAKJOKER.JOKER` linked server — tarih **ISO `'YYYYMMDD'`**, NET filtre `STATUS NOT IN (1001,1006,1007,3000,4000)` (3004/3006 normal aşama). Tüm L sorguları MCP-uyumlu (TOP + ORDER BY), `eticaret/L*.sql`.

- **L1 Kargo firma** (`eticaret/L1-kargo-firma-performans.sql`): firma × paket × ort. çıkış günü (ORDERDATE→SENDDATE) × ort. teslim günü (SENDDATE→CARGODELIVERYDATE). Teslim edilmişler (her iki tarih dolu).
- **L2 Günlük çıkış** (`eticaret/L2-gunluk-kargo-cikis.sql`): SENDDATE günü × paket × kitap (`J_ORDER_DETAILS.ORDERREF=ORDERID`, SUM QUANTITY) × tutar (QUANTITY×SELLINGPRICE).
- **L3 Bekleyen** (`eticaret/L3-bekleyen-siparis.sql`, **anlık — tarih filtresi yok**): il (`J_ORDER_CLIENTS.CCITY`) × bekleyen × toplanma(1000) × önsipariş-hazırlanan(3001/3003/3004) × temin(3006). SENDDATE NULL.

Çıktı: TR sayı formatı. L3'te "Temin bekleyen yüksek → tedarik baskısı" uyar.

---

## MAĞAZA MOD (M) — hedef/kampanya

Net: EncoreMerkez Sales → `Products.Code=urn.stkID` → kategori. Mağaza: `posMagaza.mekanKod=Stores.Code`. MCP'de tek mağaza/tek SELECT bloğu, 3-mağaza birleşik SSMS.

- **M1 Hedef/Gerçekleşen** (`magaza/M1-hedef-gerceklesen.sql`): hedef `BKMDATA.dbo.Hedef` (ay=SUM hedef), köprü `Hedef.ktgId=urnKtgr2.ktgrID=urn.urnKtgrID2`. MTD net vs ay hedefi × gerçekleşme %. Haziran hedef: FSM 14,25M/Özlüce 23,5M/İst.Yolu 13M.
- **M2 Kampanya** (`magaza/M2-kampanya-magaza.sql`): `SalesProductCampaigns` × mağaza/kampanya × gün sayısı × indirim (SUM −TotalDiscount) × fiş. CampaignName='' = manuel set indirimi.

---

## KAFE MOD (K)

Kaynak **xlsx** (`D:\Temp\GÜNLÜK KAFE SATIŞ RAPORU.xlsx`) — kafe ayrı POS, erişilebilir DB'de YOK. Dosyayı Bash + python (openpyxl/pandas, `data_only=True`) ile parse et, "Kasa Satış Raporu" + "Kategori Satış Raporu" sheet'lerinden özet bas. Yapı + doğrulanan rakamlar: `kafe/K1-gunluk-kafe-KAYNAK.md`. 3 şube: FSM/İstanbulyolu/Özlüce. Şube kolonları yatay gruplu; "Total/Toplam" satırını yakala. (B-21: kafe haftalık brief'e dahil edilecek.)

---

## Kaynak Sorgu Haritası
Tüm eşleşmeler [`sorgular/gm-rapor/KATALOG.md`](../../../sorgular/gm-rapor/KATALOG.md)'de. Rapor ID (G1/P4/E1...) → `.sql` dosyası.

## Dikkat
1. MCP'de CTE çalışmaz — yukarıdaki tek-SELECT blokları kullan. Tam analiz SSMS'te `.sql` dosyası.
2. Sayı formatı TR (1.234.567,89). Mağaza adları: FSM / Özlüce / İst.Yolu.
3. Kapsam: 3 fiziksel Bursa mağazası (G/P/M/E) + e-ticaret/lojistik (L, JOKER) + kafe (K, xlsx). Heykel + haftalık brief'e kafe/kitapsepeti entegrasyonu hâlâ B-21.
4. Envanter: Ort.Maliyet birincil, ÜstFiyat hayalet negatif içerir.
5. Geri dönüşüm fişi (BarcodeNo='1001') hariç tutulur.
6. "Bitti" demeden önce sayıyı bilinen referansla kıyasla (brief satırı / önceki gün).

## İlişkili Dosyalar
- `sorgular/gm-rapor/KATALOG.md` — rapor → sorgu haritası
- `sorgular/gm-rapor/gunluk/G1-gm-panosu.sql` — G1 tam (SSMS)
- `sorgular/gm-rapor/envanter/E1-snapshot-ozet.sql` — E1 tam
- `scripts/generate_brief.py` — P1 haftalık otomatik
- `.claude/rules/sql-server-conventions.md` — T-SQL kuralları
