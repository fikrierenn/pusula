# `mhs.mhsKapanis` — Yıl Sonu Kapanış SP'si Analizi

> **Kaynak:** [`11-mhsKapanis-kaynak.sql`](./11-mhsKapanis-kaynak.sql)
> **Bağlam:** [`07-mhs-objeleri.md`](./07-mhs-objeleri.md) #2 — Yapısal İşlemler

---

## 1. Tek Cümle Özeti

Bir mali şirketin (yılın) **tüm hesap bakiyelerini sıfırlayan tek bir
mahsup fişi üretir.** Her hesabın yıl-içi toplam `fisTutar`'ını **tersine
çevirip** kapanış fişine yazar — böylece her hesabın matematiksel bakiyesi
0 olur.

⚠️ **Bu klasik TDHP yıl-sonu kapanışı DEĞİL.** Gelir ve gider hesaplarının
690 → 691 → 692 → 590/591 zinciriyle dönem net karına yansıtılması bu SP'de
yok. BKM bu zinciri ayrıca manuel mahsupla yapıyor olmalı (mali müşavir
disiplini).

---

## 2. Parametreler

| Parametre | Tip | Anlam |
|---|---|---|
| `@sirketID` | tinyint | Hangi mali yıl/şirket kapatılacak |
| `@giderMerkezli` | tinyint | **0 = GM kırılımsız** (her hesap tek satır), **1 = GM bazında** ayrı kapanış satırı |
| `@kKisi` | int | İşlem yapan kullanıcı (gKisi/kKisi/oKisi'ye yazılır) |

**Pratik kullanım:**
```sql
DECLARE @yeniFisID int
EXEC @yeniFisID = mhs.mhsKapanis
       @sirketID      = 5,    -- 2025 yılı kapatılıyor
       @giderMerkezli = 1,    -- GM bazlı kapanış (yönetim raporu için faydalı)
       @kKisi         = 999
```

---

## 3. Akış (7 Adım)

```
1. Yevmiye no ve son fiş tarihini çek (max+1, MAX)
2. Tarihi 31/12/<yıl> olarak ayarla — string concatenation!
3. TL hijyen UPDATE — fisDvzID=1 ise fisTutarDvz=0
4. mhsFisBaslik'e Kapanış master fişi insert et (entTip=0, fisTip=2 Mahsup)
5. drn2'ye audit yaz — islem=14 (KAPANIŞ — yeni kod)
6. Bakiyesi 0 olmayan her hesap için, ters tutarla detay satır insert
   (GM kırılımı parametreye göre)
7. mhsSirket.sirketSonFisID güncelle
RETURN @fisID
```

---

## 4. Detay Insert — Kalbi

```sql
INSERT INTO mhs.mhsFis (...)
SELECT
       @fisID, @sirketID, @yevmiyeNo, @tarih, 2,
       (CASE WHEN SUM(fisTutar) > 0 THEN 1 ELSE 0 END) AS TersBA,
       -1 * SUM(fisTutar) AS TersTutar,
       0,                                          -- fisEntID
       fisHspID,
       'Kapanış',
       @giderMerkezli * fisGdrMerkez,              -- ŞIK: 0 veya GM
       fisDvzID,
       -1 * SUM(fisTutarDvz)
FROM   mhs.mhsFis
WHERE  fisSirketID = @sirketID
   AND fisHspID IN (
        SELECT fisHspID FROM mhs.mhsFis
        WHERE fisSirketID = @sirketID
        GROUP BY fisHspID HAVING SUM(fisTutar) <> 0
   )
GROUP BY fisHspID, @giderMerkezli * fisGdrMerkez, fisDvzID
HAVING SUM(fisTutar) <> 0
```

### Mantık

- **`-1 * SUM(fisTutar)`** — yıl içi toplam bakiyenin tersi. Borç bakiyesi
  varsa (negatif toplam) kapanış satırı pozitif (Alacak), tam tersi.
- **`fisHspID` ortak** — her hesabın bakiyesi kendi karşıtıyla kapatılıyor.
  Karşı taraf yok (klasik kapanış aksine).
- **`@giderMerkezli * fisGdrMerkez`** — şık binary trick:
  - `@giderMerkezli=0` → her satırda GM = 0 (toplama)
  - `@giderMerkezli=1` → orijinal GM korunur (GM kırılımlı kapanış)
- **`fisDvzID` GROUP BY'da** — döviz bazında ayrı kapanış satırı. Aynı
  hesap birden fazla dövizde varsa her döviz için ayrı satır.
- **HAVING + IN** çift kontrol — bakiyesi 0 hesaplar atlanır.

### Denge garanti mi?

Evet — **mahsup kuralı gereği** yıl içi tüm fisTutar toplamı 0 olmalı
(her mahsup fişi dengeli). Toplamın tersi de 0 → kapanış fişinin
tüm satırlarının toplamı 0 → fiş dengeli.

⚠️ **Eğer yıl içinde dengesiz fiş varsa** (kontrol edilmiyor), kapanış
fişi de dengesiz olur — ve bu sessiz bir veri sorununa neden olur.
[`07-mhs-objeleri.md`](./07-mhs-objeleri.md) #4'teki `mhsFisKontrolBakiye_vw`
view'ı bu kontrol için var olabilir.

---

## 5. Kritik Bulgular

### 5.1 ⚠️ TRANSACTION YOK

`mhsFis_sil` ve `mhsFis_cikar` BEGIN TRAN + TRY/CATCH kullanıyor. Bu SP
**yalın INSERT/UPDATE**. Yarı kalmış kapanış riski:
- Master oluştu ama detay başarısız → kapanış fişi boş kalır
- Detay tamamlandı ama mhsSirket güncellemesi başarısız → "kapatıldı"
  bilgisi eksik

**Öneri:** Bu SP'yi BEGIN TRANSACTION + TRY/CATCH ile sarmalamak
operasyonel güvenlik için kritik. Mevcut hâli production'a uygun değil.

### 5.2 ⚠️ TARİH STRING CONCATENATION

```sql
SET @tarih = '31/12/' + CAST(YEAR(@tarih) AS varchar(4))
```

Bu satır SQL Server'ın session language ayarına bağlı. Türkçe instance'ta
DMY (`104` style) parse eder ve doğru çalışır. Ama:
- İngilizce session language ayarındaki bir kullanıcı bu SP'yi çalıştırırsa
  `'31/12/2025'` → MM/DD parse → **hata veya yanlış tarih**
- `SET LANGUAGE` yerel ayara bağımlılık gizli risk

**Daha güvenli:**
```sql
SET @tarih = DATEFROMPARTS(YEAR(@tarih), 12, 31)
-- veya
SET @tarih = CONVERT(smalldatetime, '31.12.' + CAST(YEAR(@tarih) AS varchar(4)), 104)
```

DerinSIS sözleşmesinde DMY zaten standart ([`sql-server-conventions.md`](../../.claude/rules/sql-server-conventions.md))
ama `'/'` ayraçlı string concat eskimiş bir kalıp.

### 5.3 ⚠️ EKSİK KAPANIŞ — TDHP zinciri yok

Klasik Türk muhasebe yıl-sonu kapanışı:

```
Adım A: 6xx → 690 yansıtması
   690 Borç ← (600+602+...) Alacak  ──> gelirler
   690 Borç ← (610+611+612) Borç    ──> iade düzeltmeleri
   690 Alacak ← (620+621+622) Borç  ──> COGS
   690 Alacak ← (630+631+632+...) Borç ──> faaliyet giderleri
   ...
Adım B: 690 → 691 → 692 (vergi karşılığı düşülerek dönem net karı)
Adım C: 692 → 590 (dönem net karı)
Adım D: 590 → 570 (geçmiş yıllar karı, ertesi yıl)
```

`mhsKapanis` bu zincirin **HİÇBİRİNİ** yapmıyor. Sadece her hesabı tek
satırda ters tutarla sıfırlıyor — sanki tüm hesaplar kayıp, hiçbir bakiye
sonraki yıla aktarılmıyor gibi.

**Pratik anlamı:**
- BKM'de 6xx ve 7xx hesapların yansıtması ya **manuel mahsup** ile yapılıyor
  (mali müşavir kontrol)
- Veya **`cariIsle_oto`** SP'si bu işi otomatize ediyor (henüz analiz edilmedi)
- Veya BKM bu kapanış SP'sini hiç kullanmıyor — mali yıl atlama UI'dan
  başka bir şekilde yapılıyor

**Doğrulama sorgusu** — son kapatılan dönemde 690 hareketi var mı?
```sql
SELECT m.fisTarih, m.yevmiyeNo, h.hspKod, m.fisTutar, m.fisAciklama
FROM   mhs.mhsFis m
JOIN   mhs.mhsHsp h ON h.hspID = m.fisHspID
WHERE  m.fisSirketID = 5            -- 2025
  AND  h.hspKod LIKE '690.%'
ORDER BY m.fisTarih DESC
```

Eğer 690 hareketi varsa BKM klasik kapanışı UI'dan/manuel yapıyor demektir.
Yoksa kapanış zinciri eksik — ciddi bir mali risk.

### 5.4 drn2 İslem Kodu Sözlüğü — DÜZELTİLDİ

⚠️ **İlk taslakta "islem=14 = Kapanış" yazılmıştı, YANLIŞ çıktı.**
Canlı drn2 sorgusu ([`15-drn2-audit-sozlugu.md`](./15-drn2-audit-sozlugu.md))
gösterdi ki:

| islem | İşlem | SP |
|---:|---|---|
| 2 | Kaydet | mhsFisB_ekle (insert) |
| 3 | Değiştir | mhsFisB_ekle (update) |
| 4 | Sil / Çıkar | mhsFis_sil / mhsFis_cikar (text'ten ayrılır) |
| 5 | Onay | mhsFis_onay (@onay=1) |
| 6 | Onay kaldır | mhsFis_onay (@onay=0) |
| **14** | **Sistemli muhasebe operasyonu (çok-amaçlı)** | mhsKapanis + mhsSirala + Yıl başı açılış |

**islem=14 ne ifade etmiyor:** Sadece "Kapanış" değil. UI'da "yıl atlama
wizard'ı" benzeri büyük operasyonların ortak kodu. Ayırt etmek için
`islemNot` text formatı kullanılır:

- `'Kapanış fişi oluşturuldu. Şirket no:X'` → mhsKapanis
- `'Sıralama yapıldı. Şirket no:X'` → mhsSirala (yeni keşif, encrypted SP)
- `'1 dd/MM/yyyy [0] kaydedildi'` → Yıl başı açılış (kaynak SP belirsiz)

7-13 ve 15+ kodları ne için kullanılıyor — henüz canlı veri görülmedi.

### 5.5 TL Hijyen UPDATE — ipucu veriyor

```sql
UPDATE mhs.mhsFis
   SET fisTutarDvz = 0
 WHERE fisDvzID    = 1 AND fisSirketID = @sirketID
```

Bu satır **yıl boyunca veri kalitesi sorunu** olduğunu söylüyor. TL kayıtlarda
fisTutarDvz değerinin 0'dan farklı olabildiği biliniyor (yoksa neden temizleyesin?).

**Olası sebepler:**
- mhsFis_ekle SP'si fisDvzID/fisTutarDvz parametrelerini almıyor
  (bkz. [`05-CRUD-onay-akisi.md`](./05-CRUD-onay-akisi.md) #6)
- Direkt INSERT ile dövizli hesap için TL kayıt eklenirken fisTutarDvz
  yanlış doldurulmuş olabilir
- Bazı entegrasyon SP'leri (mhsEnt_*) bu alanı yanlış set ediyor olabilir

→ Uygulamanın bu hijyen UPDATE'i yıl-sonunda yapması, root cause'un
düzeltilmediğini gösteriyor.

### 5.6 GM Kırılımı Şıklığı

`@giderMerkezli * fisGdrMerkez` ifadesi binary toggle olarak çalışıyor:
- 0 × X = 0 → GM bilgisi atılır, hesap bazında tek satır
- 1 × X = X → GM korunur, hesap × GM bazında ayrı satır

Bu pattern kapanış sonrası rapor seçimine esneklik veriyor:
- "Sadece hesap bazında P&L mı istersin?" → @giderMerkezli=0
- "GM bazında detaylı P&L?" → @giderMerkezli=1

GM bazlı kapanış sonra `mhsGelirTabloGiderMerkeziDetayli` SP'siyle
yönetim raporlarını besliyor olmalı.

---

## 6. mhsKapanis Çağrılma Senaryosu (Olasılıkla)

UI'dan büyük olasılıkla bir "Yıl Sonu Kapanış" wizard'ı:

```
1. Kullanıcı: "2025 yılını kapat" butonuna basar
2. Sistem ön kontrol:
   - Tüm fişler onaylı mı? (mhsFisBaslik.fisOnay = 1?)
   - Dengesiz fiş var mı? (mhsFisKontrolBakiye_vw)
   - Orphan entegrasyon var mı? (mhsEntCiftFat_vw, mhsEntSilFat_vw)
3. Kullanıcı onaylar
4. EXEC mhs.mhsKapanis @sirketID=5, @giderMerkezli=1, @kKisi=...
5. mhsSirket.sirketSonFisID güncellendi → kapanış işaretli
6. Yeni mali yıl açılır (sirketID=6 zaten mevcutsa veya yeni şirket eklenir)
7. (?) Açılış fişi otomatik üretiliyor mu? mhsAcilis SP'si var mı? — KEŞFEDİLECEK
```

→ Sıradaki keşif: **`mhsAcilis`** veya benzeri bir SP var mı? Açılış olmadan
yeni yıl başlayamaz — varlık/borç/özkaynak hesapları açılış bakiyesi gerektirir.

---

## 7. Açık Sorular ve Sıradaki Tur

1. **mhsAcilis SP'si var mı?** Yıl-sonu kapanış sonrası ertesi yıla
   bakiye taşınması nasıl yapılıyor? Bu SP'nin kardeşi olmalı.
2. **Klasik 690 zinciri kim yapıyor?** BKM'nin son 4 yılı (2021-2024)
   kapatılmış — bu kayıtların 690/691/692/590 hesap hareketlerine bakıp
   şunu belirleyebiliriz: manuel mi otomatik mi?
3. **`cariIsle_oto` mhsKapanis ile ilişkili mi?** İsmi "cari" ama yıl-sonu
   yansıtmasının bir parçası olabilir.
4. **mhsKapanis BKM'de hiç çalıştırıldı mı?** drn2'de `islem=14 + izProgID=55`
   araması:
   ```sql
   SELECT izTrh, izKisi, islemNot
   FROM   dbo.drn2
   WHERE  izProgID = 55 AND islem = 14
   ORDER BY izID DESC
   ```
5. **mhsSirket.sirketSonFisID** — kapatılmış şirketlerde dolu olmalı.
   Hangileri kapatılmış, hangileri açık? Belirleyici kontrol.

---

## 8. Yıl Sonu Kapanış Risk Listesi (BKM için)

| Risk | Seviye | Önlem |
|---|:--:|---|
| Transaction yok → yarı kapanış | YÜKSEK | SP'yi BEGIN TRAN + TRY/CATCH ile yeniden derle |
| Tarih string concat → language bağımlılığı | ORTA | DATEFROMPARTS kullan |
| Klasik 690 zinciri eksik | YÜKSEK | Manuel disiplini netleştir veya otomatik SP geliştir |
| Dengesiz fiş kontrolü yok | YÜKSEK | Pre-flight `mhsFisKontrolBakiye_vw` zorunlu |
| Onaysız fiş kapanışa dahil olur | ORTA | `WHERE fisOnay=1` ile filtrele |
| Yıl içi UPDATE'ler kapanışı kirletir | DÜŞÜK | TL hijyen UPDATE'i bütün yıla yayılır, sıralama tarihi koruması yok |
| `sirketSonFisID` referansı silinen fişle bozulabilir | DÜŞÜK | mhsSirket'teki bağı periyodik kontrol et |
