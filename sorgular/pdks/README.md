# PDKS (GecoTime) — Tablo Yapısı ve Rapor Mantığı

**Sistem:** GecoTime (Alman üretimi PDKS yazılımı)
**Sunucu:** `192.168.40.66\SQLEXPRESS` — MCP: `mcp__sqlserver-express__*`
**Veritabanı:** `wtimserv` (compat 110)
**Son güncelleme:** 15 Nisan 2026

## Almanca kısaltma sözlüğü

| Kısaltma | Almanca | Türkçe |
|---|---|---|
| Per | Personal | Personel |
| Tag | Tag | Gün |
| Zei | Zeit | Zaman |
| Les | Leser | (Kart) Okuyucu |
| Mod | Modell | Model / Şablon |
| Sal | Saldo | Bakiye |
| Abw | Abwesenheit | Devamsızlık |
| Sch | Schicht | Vardiya |
| Loh | Lohn | Ücret |
| Zug | Zugang | Erişim (geçiş izni) |
| Kst | Kostenstelle | Masraf merkezi |
| Grp | Gruppe | Grup |
| Fei | Feiertag | Resmi tatil |
| Bed | Bedarf | İhtiyaç (vardiya) |
| Bez | Bezeichnung | Tanım / açıklama |
| Nr | Nummer | Numara |
| Ang | Anstellung | İstihdam |
| Sum | Summe | Toplam |
| Nrm | Norm | Normlanmış |
| Buf | Buffer | Terminal buffer |

## Veri hacmine göre kritik tablolar

| Tablo | Satır | İçerik |
|---|---|---|
| `TPerTab` | 3.158 | Personel master (+ Grup0–9, TagMod, SchMod, bio/pinkod) |
| `TPerAng` | 1.537 | Aktif istihdam kayıtları |
| `TTagZei` | 2,14 M | Günlük zaman kayıtları (detay satırlar) |
| `TTagMoS` | 1,09 M | Günlük vardiya modeli eşleşmesi |
| `TTagLes` | **529 K** | **Günlük kart okutma özeti — rapor ana kaynağı** |
| `TSumZei` | 854 K | Toplam süre özeti |
| `TLohTab` | 158 K | Ücret / bordro aktarım |
| `TNrmAbw` | 457 K | Normlanmış devamsızlıklar |
| `TZeiBuf` | 116 K | Terminal buffer (ham okutma, henüz işlenmemiş) |
| `TPerHist` | 1,3 M | Personel değişiklik geçmişi |
| `TWorkflowHist` | 42 K | İzin/onay akışı |
| `TModPla` | 6 K | Vardiya planlamaları |
| `TLesTab` | 10 | Terminal (okuyucu) listesi |
| `TFeiTab` | 41 | Resmi tatil takvimi |
| `TAbwArt` | 16 | Devamsızlık/mazeret türleri |
| `bkm.SubeListe` | 24 | BKM özelleştirmesi — lokasyon listesi |

## Rapor veri akışı (fiziksel sıra)

```
TZeiBuf  →  TTagLes  →  TTagZei  →  TSumZei  →  TLohTab
(ham)      (gün özet)   (detay)    (özet)     (bordro)
```

- **Ham okutma** terminalden `TZeiBuf`'a düşer.
- İşlendikten sonra gün başına bir satır `TTagLes`'e yazılır (ilk giriş — son çıkış + brüt süre).
- Detay satırlar (pause, fazla mesai vb.) `TTagZei`'ye kırılır.
- Aylık özetler `TSumZei`'de, bordroya aktarım `TLohTab`'da.

## Günlük PDKS raporu için tablo yapısı

### `dbo.TTagLes` — günlük özet (ana tablo)

| Kolon | Tip | Anlam |
|---|---|---|
| `TLe_PersNr` | int | Personel sicil no (FK → `TPerTab.Per_PersNr`) |
| `TLe_Datum` | datetime | Gün (saat=00:00) |
| `TLe_BeginnKz` | int | Satır sıra kodu (0 = günün ilk satırı) |
| `TLe_VonZeit` | datetime | İlk giriş (tam datetime, saat kısmı alınır) |
| `TLe_BisZeit` | datetime | Son çıkış |
| `TLe_IstZeit` | decimal(18,2) | Brüt süre (ondalık saat — `10.07` = 10 saat 07 dakika, ondalık saat değil) |
| `TLe_AbwArt` | nvarchar(10) | Mazeret kodu (FK → `TAbwArt.Abw_AbwArt`) |
| `TLe_TagMod` | nvarchar(10) | Gün modeli (o güne ait, `Per_TagMod`'u override edebilir) |
| `TLe_LesNrKo` / `TLe_LesNrGe` | int | Giriş / çıkış okuyucu no (FK → `TLesTab`) |

> **Not:** `TLe_IstZeit` değeri "ondalık saat" değil, **"saat.dakika"** kozmetik görünüm olarak Excel'e yansıtılır. Arka planda saf decimal — 10.07 = 10 saat + 7 dakika olarak okunur (0.07 * 100 = 7 dk). Gerçek "ondalık saat" olan `TZe_IstZeit` farklıdır.

### `dbo.TPerTab` — personel master (gerekli kolonlar)

| Kolon | Anlam |
|---|---|
| `Per_PersNr` | Sicil no (PK) |
| `Per_Name` | Soyad |
| `Per_Vorname` | Ad |
| `Per_Grp0..Per_Grp5` | Hiyerarşik grup (0=Şirket, 1=Yerleşke, 2=Bölüm, 3=Alt bölüm, 4=Takım, 5=Detay) |
| `Per_TagMod` | Varsayılan gün modeli (ör. `830-1` = 08:30–17:30 bir saat mola) |
| `Per_ZeitAktiv` | Aktif mi (1/0) — pasif personeli elemek için filtre |

### `dbo.TAbwArt` — mazeret lookup

| Kolon | Anlam |
|---|---|
| `Abw_AbwArt` | Kod (PK) |
| `Abw_AbwArtBez` | Tam metin (ör. "Yıllık İzin", "Rapor") |
| `Abw_AbwArtKurzBez` | Kısa metin (ör. "YI", "R") |

## Rapor filtre mantığı

Örnek raporda (14.04.2026 — MALİ İŞLER ekranı) 11 satır var. Filtrenin `Per_Grp2 = 'MALİ İŞLER VE YÖNETİM SİSTEMLERİ'` olduğu anlaşılıyor. Alternatifler:

- **Departman bazlı:** `Per_Grp2` veya `Per_Grp3` üzerinden.
- **Şube bazlı:** `bkm.SubeListe.SubeNo` üzerinden (BKM özelleştirmesi).
- **Elle sicil listesi:** Yönetim özel listesi.

Parametreleştirilmiş versiyonu `pdks_gunluk_rapor.sql` içinde (`@Grup1`, `@Grup2` değişkenleri).

## Kontrol (14.04.2026 doğrulaması)

Orijinal Excel raporundaki 10/11 satır birebir eşleşti (saatler + brüt süre). Uyumsuzluk:

- **Ekstra (DB'de var, Excel'de yok):** 343 — ATİLLA KONUK (FİNANS).
- **Eksik (Excel'de var, DB'de farklı):** 693 / 2798 — Per_Grp2 değeri "İNSAN KAYNAKLARI" olarak kayıtlı, Excel çekildiği anda farklı olmuş olabilir.

İhtimaller: (a) Raporun filtresi Grup2 değil, elle seçilmiş sicil listesi. (b) Grup2 değerleri sonradan güncellenmiş. (c) `bkm.SubeListe` üzerinden farklı bir filtre var.

## Bağlantı (güncel — 15.04.2026)

İki MCP paralel kullanmaya gerek yok. Her şey 201 → BKM üzerinden, cross-server için OPENQUERY:

```
mcp__sqlserver__sql_query
  database = BKM
  query    = SELECT ... FROM vrd.XXX ... LEFT JOIN OPENQUERY([PDKS], '...inner sql...') ...
```

Kurallar:
- Dış sorguda tarih → `CONVERT(datetime, '13.04.2026', 104)` (DMY).
- OPENQUERY **içinde** tarih → `'20260415'` (YYYYMMDD ISO).
- String join cross-db → `COLLATE Turkish_CI_AS`.
- MCP otomatik TOP sarması var → subquery'de `ORDER BY` kullanmak için dıştaki SELECT'e `TOP N` koy.

## Mola Mantığı (15.04.2026 eklendi — KRİTİK)

`TTagZei` segment incelemesinden doğrulanan davranış:

| Mola türü | Otomatik kırılıyor mu? | Neden |
|---|---|---|
| Yemek (60 dk) | ✅ Evet | Kişi 12:00 çıkış, 13:00 giriş okutuyor → boşluk segmenti ayırır |
| Çay 15+15 dk | ❌ Hayır | Kart okutulmuyor, sistem göremiyor → brüt içinde kalır |
| Fazla mesai | ✅ Ayrı etiket (`FM1`) | `TZe_ZeitArt = 'FM1'` segmentinde |

**Fazla mesai hesabı — DOĞRU yöntem:**
- ❌ YANLIŞ: `TLe_IstZeit − plan` (çay molalarını karıştırır, datetime aritmetiği patlar)
- ✅ DOĞRU: `TTagZei` üzerinde `TZe_ZeitArt = 'FM1'` segmentlerinin `DATEDIFF(MINUTE, VonZeit, BisZeit)` toplamı
- Bkz. `pdks_fazla_mesai_fm1.sql`

**Net çalışma süresi:** `TZe_ZeitArt = 'NCAL'` segmentlerinin toplamı.

## vrd Şeması (BKM, 15.04.2026 eklendi)

- **Vardiya**: `VardiyaNo (PK)`, `SubeNo`, `Tarih` (haftanın Pazartesi'si), `BitisTarih` (genelde NULL), `Kesin`.
- **VardiyaDetay**: `Id`, `VardiyaNo`, `SicilNo` (TC 11 hane), `Bolum`, `Gorev`, `Personel`, `PartTime`, `ToplamCalismaDk`, `Pazartesi..Pazar` (7 int kolon).
- **VardiyaZaman**: `VardiyaId (PK)`, `Aciklama`, `Baslama`, `Bitis`, `MolaSureDk`, `ToplamCalismaDk`, `Dinlenme1Baslama/Bitis`, `Dinlenme2Baslama/Bitis`, `YemekBaslama/Bitis`, `Izin`.
- **SubeListe**: `SubeNo (PK)`, `SubeAd`, `GrupNo`. 9 şube var, 15.04.2026 itibariyle 7'si aktif vardiyalı.

**Özel gün kodları** (VardiyaDetay.Pazartesi..Pazar kolonlarında VardiyaId yerine):

| Kod | Anlam | Izin flag |
|---|---|---|
| 51 | Hafta izni | ✓ |
| 52 | Ücretsiz izin | ✓ |
| 53 | Ücretli izin | ✓ |
| 55 | Resmi tatil | ✓ |
| 58 | Yıllık izin | ✓ |
| 62 | **Güvenlik** (23:00-07:30 gece vardiyası) | ✗ çalışma! |
| 63 | Rapor | ✓ |
| 73 | Mesai izni | ✓ |
| 100 | **Özel durum** (plan belirsiz slot) | ✗ |

⚠ **Filtre düzeltmesi:** Eski sorgularda `NOT IN (51,52,53,55,58,62,63,73)` yanlıştı — 62 güvenlik bir çalışma vardiyası. Doğrusu: **`vz.Izin = 0`** (join ile) veya `NOT IN (51,52,53,55,58,63,73)`.

⚠ **Kod 100 "ÖZEL DURUM":** `Izin=0`, saat 00:00-00:00. Resmi izin değil ama çalışma saati de tanımsız. 3 kişi kullanıyor: EMRE KALFA, HATİCE KÜBRA BOZDOĞAN, ZEYNEP İÇEL. İK'ya ne anlama geldiği sorulmalı.

## Yönetici Kadro (Kart Basmayan)

Vardiya planında var, `TPerInd`'de TC eşleşmesi yok → PDKS'e bilerek tanımlanmamış. "Gelmedi" sayılmamalılar. 15.04.2026 tespit: 6 kişi (ENVER CAN, MEHMET KELEŞ, MUHAMMED ENES KILIÇ, RECEP ÖZCAN, EREN BORAN, ABDURRAHMAN UĞURLU). Detay: [`pdks_yonetici_listesi.md`](pdks_yonetici_listesi.md). İleride genişleyecekse kalıcı `bkm.YoneticiKadro` tablosu tutulmalı.

**Köprü (TC Kimlik):**
```
vrd.VardiyaDetay.SicilNo  COLLATE Turkish_CI_AS
  = TPerInd.PIn_SteuerNr  COLLATE Turkish_CI_AS
    → TPerInd.PIn_PersNr = TTagLes.TLe_PersNr
```

## Sorgu Katalogu

| Dosya | Açıklama |
|---|---|
| `pdks_gunluk_rapor.sql` | Parametrik günlük rapor (ilk sürüm — wtimserv'e doğrudan, Grup1/Grup2 filtreli) |
| `pdks_fazla_mesai_fm1.sql` | **Fazla mesai TOP N — FM1 segment tabanlı (DOĞRU yöntem)** |
| `pdks_vardiya_plan_fiili.sql` | Gün bazlı plan-fiili kişi listesi (vrd + GecoTime birleşik) |
| `pdks_sube_ozet.sql` | Şube bazlı günlük özet (Plan/Geldi/Gelmedi/İzinli) |
| `pdks_ttagzei_segment_ornek.sql` | Segment inceleme — mola kırma doğrulaması referansı |
| `pdks_vrd_tablo_kesfi.sql` | vrd şeması kolon listesi (referans) |
| `pdks_vardiyazaman_katalog.sql` | **VardiyaZaman tam katalog + kod sözlüğü (62/100 uyarıları)** |
| `pdks_izinli_liste.sql` | **Bugün normalde izinli olanlar (vz.Izin=1)** |
| `pdks_yonetici_listesi.md` | **Kart basmayan yönetici kadro — plan-fiili eşleşmesinde istisna** |
| `pdks_view_tasarimi.md` | **View/iTVF tasarım notları — gün kolonu dinamik eşleşme (UNPIVOT)** |
| `sp_PdksPano.sql` | **Dashboard tek SP — 7 result set, UNPIVOT dinamik gün, tarih parametrik** |

## Pano Dosyaları

- `D:\Dev\sqlserver-mcp-server\BKM-PDKS-Pano.html` — **Birleşik pano**: 4 sekme (Özet · Mağaza/Vardiya · Tüm Kadro · Mesai & Sapma). Drill-down modal.
- `D:\Dev\sqlserver-mcp-server\BKM-PDKS-Yonetim-Panosu.html` — eski sürüm (sadece kadro bazlı).
- `D:\Dev\sqlserver-mcp-server\BKM-PDKS-Vardiya-Panosu.html` — eski sürüm (sadece plan-fiili).

## Sonraki Adımlar

- **`vrd.VardiyaDetayGun_vw` view'ını oluştur** (UNPIVOT — 7 gün kolonunu satıra çevirir, tarih bazlı dinamik eşleşme). Detay: [`pdks_view_tasarimi.md`](pdks_view_tasarimi.md).
- `vrd.VardiyaZaman_vw` — `IzinMi`, `OzelDurumMu`, `NetCalismaDk` hesaplı kolonlar.
- `bkm.sp_PdksPlanFiili_Liste @Tarih` — OPENQUERY içeren stored procedure (view/iTVF OPENQUERY'yi kaldırmaz).
- Mevcut tüm `pdks_*.sql` sorgularındaki `NOT IN (51,52,...,62,...,73)` filtresini **`vz.Izin = 0 AND vd.Carsamba <> 100`** (veya `NOT IN (51,52,53,55,58,63,73)`) şeklinde güncelle.
- Panodaki `D` dizisine `yonetici` flag'i ekle (6 TC için) → "gelmedi" sayımından düş.
- `bkm.YoneticiKadro (TC, Unvan, SubeNo, Aktif)` tablosu tasarımı.
- Kod 100 (ÖZEL DURUM) iş kuralının İK ile netleştirilmesi.
- `vrd.VardiyaZaman.MolaSureDk` üzerinden plan net süre hesabı.
- `TTagZei` NCAL toplamı ile gerçek net çalışma karşılaştırması (brüt yerine).
- Stored procedure serisi: `bkm.sp_PdksPano_Ozet/Bolum/Anlik/Trend/GecKalma/FazlaMesai`.
- `bkm.PdksPlanFiili_vw` view tasarımı.
- Dashboard'ın reporthub'a taşınması (ReportCatalog entry + SP + ParamSchemaJson).
