/* =====================================================================
   ZİRVE (BKM_GENEL) SEMANTİK KATMAN SÜPÜRMESİ — 1. PARTİ: YÜZEY + HUB
   Sunucu : 192.168.40.25\ZRVSQL2008  ·  sqlcli --profile zirve (pyodbc)
   Tarih  : 2026-09-12
   Amaç   : DerinSIS'te kullanılan "yüzey ölç → FK grafiği → hub → modül"
            yöntemini Zirve'ye uygulamak.
   SONUÇ  : YÖNTEM KIRILDI — Zirve'de FK grafiği YOK (387 tabloda 4 FK).
            Hub, FK'dan değil KOLON ADI YAKINSAMASINDAN türetildi.
   SALT-OKUMA. Zirve'ye yazma MUTLAK YASAK (erp-write-policy.md).
   ===================================================================== */

-- ---------------------------------------------------------------------
-- BLOK 0 — Motor kimliği
-- ÖLÇÜLDÜ: SQL Server 2014 SP3-GDR 12.0.6179.1, Express Edition, Intel X86
--          (32-bit). Sunucu ADI "ZRVSQL2008" ama motor 2008 DEĞİL.
--          BKM_GENEL compatibility_level = 100 (SQL 2008 davranışı) →
--          TRY_CONVERT/IIF/STRING_AGG YOK. Sema'daki "SQL2008" notu
--          SONUÇ olarak doğru, GEREKÇE olarak yanlıştı (motor değil compat).
-- ---------------------------------------------------------------------
SELECT DB_NAME() AS db, @@VERSION AS surum, SERVERPROPERTY('ProductVersion') AS pv;

SELECT name, compatibility_level, state_desc, recovery_model_desc,
       CONVERT(varchar(10), create_date, 104) AS olusturma
FROM sys.databases WHERE database_id > 4 ORDER BY name;
-- ÖLÇÜLDÜ: 125 kullanıcı veritabanı. Zirve deseni = <FİRMA>_GENEL (personel/bordro)
--          + <FİRMA>_<YIL> + <FİRMA>_<YIL>T (mali yıl).
--          Firmalar: BKM · BKM_2 · BKM_HEYKEL · BURSA_KÜLTÜR_MERKEZİ ·
--          ASİYE_BİNGÖLBALİ · KUTBETTİN_BİNGÖLBALİ (09-10.09.2026 açılmış, 3 günlük)
--          · POINT · SİMÜL/SİMÜLASYON/SİMÜLATÖR/SIMUL22 (test kopyaları) · zirvegenel.

-- ---------------------------------------------------------------------
-- BLOK 1 — Erişim sınırı (KAPSAM: ölçemediğimi yazıyorum)
-- ÖLÇÜLDÜ: login = rapor_readonly. BKM_GENEL DIŞINDAKİ 124 DB'ye erişim YOK:
--   The server principal "rapor_readonly" is not able to access the
--   database "BKM_2026" under the current security context.
-- ⇒ Mali-yıl DB'leri (muhasebe/beyanname tarafı) BU KİMLİKLE ÖLÇÜLEMEZ.
--   Bu "veri yok" DEĞİL, "bakamadım" — sessizlik kanıt değil.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS n FROM BKM_2026.sys.tables;   -- HATA verir (yukarıdaki mesaj)

-- ---------------------------------------------------------------------
-- BLOK 2 — Tablo yüzeyi
-- ÖLÇÜLDÜ: tek şema dbo. 387 tablo · 135 DOLU · 252 BOŞ · 198.767 satır.
--          (Bağımsız ikinci ölçüm — pusula-05 oturumu — birebir aynı.)
-- ---------------------------------------------------------------------
SELECT s.name AS sema, t.name AS tablo,
       SUM(CASE WHEN p.index_id IN (0,1) THEN p.rows ELSE 0 END) AS satir
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id
GROUP BY s.name, t.name
ORDER BY satir DESC;

-- ---------------------------------------------------------------------
-- BLOK 3 — FK grafiği: YÖNTEMİN KIRILDIĞI YER
-- ÖLÇÜLDÜ: sys.foreign_keys = 4 (DÖRT). Hepsi çevresel:
--   tbDamgaVergisiDeftereBagliTaraf → tbDamgaVergisiDuzenlenenKagit
--   tbDamgaVergisiDuzenlenenKagit   → tbDamgaVergisi
--   tbDamgaVergisiDeftereBagliTur   → tbDamgaVergisiDuzenlenenKagit
--   tbKDV1IstisnaKodDetay           → tbKDV1IstisnaKod
-- Bağlı bileşen = 2 küçük ada; personel/bordro çekirdeğinde SIFIR FK.
-- ⇒ "Hub'ı FK grafiğinden türet" adımı Zirve'de KOŞAMAZ. İlişkiler
--   BEYAN EDİLMEMİŞ, kolon adı konvansiyonuyla taşınıyor.
-- Ayrıca: PK 178 / UQ 4 / index 219 / view 11 / SP 8 / fn 6 / trigger 8.
-- ---------------------------------------------------------------------
SELECT fk.name AS fk,
       OBJECT_NAME(fk.parent_object_id)     AS cocuk,
       COL_NAME(fkc.parent_object_id,     fkc.parent_column_id)     AS cocuk_kol,
       OBJECT_NAME(fk.referenced_object_id) AS ebeveyn,
       COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS ebeveyn_kol
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id;

-- ---------------------------------------------------------------------
-- BLOK 4 — YEDEK YÖNTEM: kolon adı yakınsaması (yalnız DOLU tablolar)
-- ÖLÇÜLDÜ (ilk sıralar): Arti 68 tablo · Ayindex 34 · Cyili 30 · Sube 29 ·
--   Yil 28 · ID 28 · Personelno 17 (112.295 satır = DB'nin %56,5'i) ·
--   Ay 16 · TCKimlikNo 12 · Firmakodu 9 · Fsk 7.
-- ⇒ HUB = Personelno; dönem ekseni = (Yil | Cyili) × (Ayindex | Ay).
-- ---------------------------------------------------------------------
SELECT TOP 40 c.name AS kolon,
       COUNT(DISTINCT t.object_id) AS tablo_sayisi,
       SUM(p.rows) AS toplam_satir
FROM sys.columns c
JOIN sys.tables t ON t.object_id = c.object_id
JOIN (SELECT object_id, SUM(rows) AS rows FROM sys.partitions
      WHERE index_id IN (0,1) GROUP BY object_id) p ON p.object_id = t.object_id
WHERE p.rows > 0
GROUP BY c.name
HAVING COUNT(DISTINCT t.object_id) >= 5
ORDER BY COUNT(DISTINCT t.object_id) DESC, SUM(p.rows) DESC;

-- ---------------------------------------------------------------------
-- BLOK 5 — Arti HUB MU? — ALTERNATİF AÇIKLAMA ÖLÇÜLDÜ VE ELENDİ
-- Arti 68 tabloda NOT NULL → çapraz bağ sanılabilirdi.
-- ÖLÇÜLDÜ: sys.identity_columns'ta Arti = IDENTITY(1,1).
-- ⇒ TABLO-İÇİ SATIR SAYACI, çapraz anahtar DEĞİL. Hub hipotezi elendi.
--   (Yan bulgu: per_k_bil MAX(Arti)=94.775 ama 31.978 satır → ağır silme trafiği.)
-- ---------------------------------------------------------------------
SELECT TOP 12 OBJECT_NAME(ic.object_id) AS tablo, ic.name AS kolon,
       ic.seed_value, ic.increment_value
FROM sys.identity_columns ic WHERE ic.name = 'Arti';

-- ---------------------------------------------------------------------
-- BLOK 6 — Personelno modülü (hub komşuluğu) + tazelik
-- ÖLÇÜLDÜ (satır · tekil kişi · dönem):
--   puanbil            27.931 · 3.559 · 2014-08..2026-09   (137 kolon)
--   muhSGKBildirimleri 24.265 ·   —   · Cyili 2018..2026    (57 kolon)
--   perkbil            21.837 · 3.237 · 2015-09..2026-09   (kesinti KALEMİ)
--   perobil            12.422 · 1.472 · 2016-03..2026-09   (ödeme KALEMİ)
--   izin                9.693 · 1.976
--   avans               6.774 · perbilgi 3.578 (188 kolon) · Ssk_tesvik 1.763
--   kidemt 1.512 · perodeme 1.461 · Kidemihbar 259 · icra 151
-- ---------------------------------------------------------------------
SELECT t.name AS tablo, p.rows AS satir, COUNT(*) AS kolon_sayisi
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN (SELECT object_id, SUM(rows) AS rows FROM sys.partitions
      WHERE index_id IN (0,1) GROUP BY object_id) p ON p.object_id = t.object_id
WHERE p.rows > 0
  AND EXISTS (SELECT 1 FROM sys.columns c2
              WHERE c2.object_id = t.object_id AND c2.name = 'Personelno')
GROUP BY t.name, p.rows
ORDER BY p.rows DESC;

-- ---------------------------------------------------------------------
-- BLOK 7 — SESSİZ JOIN TUZAĞI: mesai tablosu hub'ı Perno diye yazıyor
-- ÖLÇÜLDÜ: dbo.mesai (19.076 satır, DB'nin 6. büyüğü) Personelno TAŞIMAZ.
--   Kişi anahtarı = Perno (int). Grain = kişi × GÜN (Yil + Ay + Gun) —
--   puanbil'in kişi × AY grain'inden FARKLI.
--   Dönem 2014-09..2026-09 (CANLI). Tekil Perno 3.046.
--   Öksüz (perbilgi'de karşılığı yok) = 29 satır / 19.076 = %0,15.
-- ⇒ Fazla mesai GÜNLÜK detayı burada; sema bugün yalnız vw_PuanBil'in
--   AYLIK fm1/fm2/fm3 toplamını biliyor.
-- ⚠ 1fm/2fm/3fm kolon adları RAKAMLA BAŞLAR → köşeli parantez şart.
-- ---------------------------------------------------------------------
SELECT MIN(Yil*100+Ay) AS ilk, MAX(Yil*100+Ay) AS son,
       COUNT(*) AS satir, COUNT(DISTINCT Perno) AS tekil_perno
FROM dbo.mesai;

SELECT COUNT(*) AS oksuz_satir
FROM dbo.mesai m
WHERE NOT EXISTS (SELECT 1 FROM dbo.perbilgi p WHERE p.Personelno = m.Perno);

-- ---------------------------------------------------------------------
-- BLOK 8 — VIEW TANIMLARI OKUNAMIYOR (ve sebebi ŞİFRELİ DEĞİL)
-- ÖLÇÜLDÜ: 11 view'ın 11'inde sys.sql_modules.definition = NULL.
--   OBJECTPROPERTY(...,'IsEncrypted') = 0  → şifreli DEĞİL
--   HAS_PERMS_BY_NAME(...,'VIEW DEFINITION') = 0 → İZİN YOK
-- ⇒ "NULL = şifreli" kestirmesi burada YANLIŞ olurdu (sql-server-conventions
--   § OBJECT_DEFINITION dersinin Zirve ikizi). View iç mantığı bu kimlikle
--   OKUNAMAZ; şekli yalnız VERİDEN türetilebilir.
-- ---------------------------------------------------------------------
SELECT s.name AS sema, o.name AS obj,
       CASE WHEN m.definition IS NULL THEN 'NULL' ELSE 'OK' END AS tanim,
       OBJECTPROPERTY(o.object_id, 'IsEncrypted') AS sifreli,
       HAS_PERMS_BY_NAME(s.name + '.' + o.name, 'OBJECT', 'VIEW DEFINITION') AS izin_var
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
WHERE o.type = 'V';

-- ---------------------------------------------------------------------
-- BLOK 9 — ⭐ VIEW, TABANINDAN BÜYÜK: vw_PuanBil ÜÇ FİRMAYI BİRLEŞTİRİYOR
-- ÖLÇÜLDÜ: vw_PuanBil 34.397 satır · dbo.puanbil 27.931 satır (view %23 BÜYÜK).
--   Firma kırılımı (view'ın KENDİ Firma kolonu — sonek ayrıştırmaya gerek yok):
--     BKM_GENEL             27.931  (3.559 kişi)  2014..2026
--     BURSA_KÜLTÜR_MERKEZİ   5.056  (  350 kişi)  2014..2026
--     ASİYE_BİNGÖLBALİ       1.410  (  101 kişi)  2014..2026
--   Aritmetik KAPANIYOR: BKM_GENEL dilimi = 27.931 = dbo.puanbil satırı, BİREBİR.
-- ⇒ dbo.puanbil YALNIZ BKM_GENEL firmasıdır; vw_PuanBil ÜÇ FİRMA birleşimidir.
--   View, bizim kimliğimizin OKUYAMADIĞI diğer firma DB'lerini sahiplik
--   zinciriyle okuyor (BLOK 1'deki erişim reddine rağmen satır dönüyor).
--   Sema bugün "ham tablo dbo.puanbil (27,6K)" diyerek view'ı onun izdüşümü
--   sanıyor — KAPSAM %18,8 DAR yazılmış.
-- ⚠ Yan bulgu: BKM_GENEL diliminde 3 satırın Personelno'sunda tire YOK →
--   yaygın LIKE %-BKM firma süzgeci bu 3 satırı SESSİZCE düşürür.
-- ---------------------------------------------------------------------
SELECT ISNULL(Firma, '(NULL)') AS firma, COUNT(*) AS satir,
       COUNT(DISTINCT Personelno) AS kisi,
       SUM(CASE WHEN CHARINDEX('-', ISNULL(Personelno, '')) = 0 THEN 1 ELSE 0 END) AS soneksiz,
       MIN(Yil) AS ilk_yil, MAX(Yil) AS son_yil
FROM dbo.vw_PuanBil GROUP BY Firma ORDER BY COUNT(*) DESC;

SELECT ISNULL(Firma, '(NULL)') AS firma, COUNT(*) AS satir,
       SUM(CASE WHEN Ict IS NULL THEN 1 ELSE 0 END) AS aktif,
       COUNT(DISTINCT Lokasyon) AS lokasyon
FROM dbo.vw_PersonelDepartman GROUP BY Firma ORDER BY COUNT(*) DESC;
-- ÖLÇÜLDÜ: vw_PersonelDepartman 1.296 satır · aktif 291+46+20 = 357.
--   (Sema'daki aktif 341 = 2026-08-29 ölçümü — kadro büyümüş, çelişki değil.)

-- ---------------------------------------------------------------------
-- BLOK 10 — AD ÇİFTLERİ: hangisi canlı? (tanım okunamadığı için SATIRDAN)
-- ÖLÇÜLDÜ:
--   vw_PerKBil 19.933 | perkbil 21.837 | per_k_bil 31.978 | wPerkbil 20.016
--   vw_PerOBil  9.123 | perobil 12.422 | per_o_bil 21.194
--   vw_PuanBil 34.397 | puanbil 27.931
--   vw_PersonelDepartman 1.296 | vw_PersonelDepartmanEski 1.296 (AYNI sayı!)
--   personeler 337 | mevcut_personeller 4.080 | personelIstenAyrilanlar 10
--   MagazaPersoneller 357
-- ⚠ per_k_bil / per_o_bil KİŞİ ANAHTARI TAŞIMAZ (Personelno/Perno YOK) ve
--   tarih kolonu da yok. per_k_bil: 31.978 satır ama yalnız 9 tekil Kesintiadi,
--   Tutar DOLU olan 2.297 (%7,2), Py dolu 8 satır. Yani BORDRO VERİSİ DEĞİL —
--   ekran/şablon artığı görünümünde. perkbil (Personelno+Yil+Ayindex+Fsk)
--   gerçek kalem tablosu. İkisini karıştırmak bordroyu 1,5 katına çıkarır.
-- ⚠ vw_PersonelDepartman ile Eski AYNI satır sayısını veriyor → farklı olup
--   olmadıkları SATIR SAYISIYLA AYIRT EDİLEMEZ (açık soru).
-- ---------------------------------------------------------------------
SELECT 'vw_PerKBil' AS obj, COUNT(*) AS satir FROM dbo.vw_PerKBil
UNION ALL SELECT 'perkbil',                  COUNT(*) FROM dbo.perkbil
UNION ALL SELECT 'per_k_bil',                COUNT(*) FROM dbo.per_k_bil
UNION ALL SELECT 'wPerkbil',                 COUNT(*) FROM dbo.wPerkbil
UNION ALL SELECT 'vw_PerOBil',               COUNT(*) FROM dbo.vw_PerOBil
UNION ALL SELECT 'perobil',                  COUNT(*) FROM dbo.perobil
UNION ALL SELECT 'per_o_bil',                COUNT(*) FROM dbo.per_o_bil
UNION ALL SELECT 'vw_PuanBil',               COUNT(*) FROM dbo.vw_PuanBil
UNION ALL SELECT 'puanbil',                  COUNT(*) FROM dbo.puanbil
UNION ALL SELECT 'vw_PersonelDepartman',     COUNT(*) FROM dbo.vw_PersonelDepartman
UNION ALL SELECT 'vw_PersonelDepartmanEski', COUNT(*) FROM dbo.vw_PersonelDepartmanEski
UNION ALL SELECT 'perbilgi',                 COUNT(*) FROM dbo.perbilgi
UNION ALL SELECT 'personeler',               COUNT(*) FROM dbo.personeler
UNION ALL SELECT 'mevcut_personeller',       COUNT(*) FROM dbo.mevcut_personeller
UNION ALL SELECT 'personelIstenAyrilanlar',  COUNT(*) FROM dbo.personelIstenAyrilanlar
UNION ALL SELECT 'MagazaPersoneller',        COUNT(*) FROM dbo.MagazaPersoneller;

-- ---------------------------------------------------------------------
-- BLOK 11 — Kolon yeri düzeltmesi
-- ÖLÇÜLDÜ: Kadro kolonu vw_PuanBil'de YOK (Err: Invalid column name Kadro,
--   Adi, Soyadi). Kadro/AdSoyad/Lokasyon/Departman/Unvan/Ucret/Firma =
--   vw_PersonelDepartman (24 kolon). Maliyet (Bt/Isskk/Iisk) + Primgunu +
--   fm1..fm3 = vw_PuanBil (40 kolon). İkisi AYRI view; görev brifinginde
--   birleşik anlatılmıştı.
-- ---------------------------------------------------------------------
SELECT o.name AS obj, c.column_id AS s, c.name AS kolon
FROM sys.objects o JOIN sys.columns c ON c.object_id = o.object_id
WHERE o.name IN ('vw_PuanBil', 'vw_PersonelDepartman')
ORDER BY o.name, c.column_id;

-- =====================================================================
-- 2. PARTİ — DEĞİŞMEZ NÜFUSLARI · KİMLİK · ÖKSÜZ · ÖLÜ KOLON (2026-09-12)
-- =====================================================================

-- ---------------------------------------------------------------------
-- BLOK 12 — Kadro etiket kümesi × FİRMA
-- ÖLÇÜLDÜ: etiket sözlüğü FİRMAYA GÖRE DEĞİŞİYOR. Marjinal etiketlerin
--   TAMAMI BKM_GENEL'de:
--     BKM_GENEL  KADRO 875 · SEZONLUK 212 · NULL 8 · '' 3 · STAJYER 2 ·
--                PART-TIME 1 · PART TIME 1 · KISMİ 1
--     BURSA_KÜLTÜR_MERKEZİ  KADRO 78 · SEZONLUK 67
--     ASİYE_BİNGÖLBALİ      KADRO 23 · SEZONLUK 23 · NULL 2
-- ⚠ `PART-TIME` ile `PART TIME` AYRI iki değer (tire farkı) — veri girişi varyantı.
-- ⚠ ARAÇ TUZAĞI (yaşandı): sqlcli çıktısı UTF-8; python stdin'i cp1252 ile
--   çözerse `KISMİ` → `KISMÄ°` görünür ve "DB'de mojibake var" SANILIR. DB TEMİZ.
--   Boru her zaman `sys.stdin.buffer.read().decode('utf-8')` ile okunmalı.
-- ---------------------------------------------------------------------
SELECT ISNULL(Firma, '(NULL)') AS firma, ISNULL(Kadro, N'(NULL)') AS kadro,
       COUNT(*) AS satir,
       SUM(CASE WHEN Lokasyon LIKE 'MA%' THEN 1 ELSE 0 END) AS ma,
       SUM(CASE WHEN Ict IS NULL THEN 1 ELSE 0 END) AS aktif
FROM dbo.vw_PersonelDepartman
GROUP BY Firma, Kadro ORDER BY Firma, COUNT(*) DESC;

-- ---------------------------------------------------------------------
-- BLOK 13 — ⭐ MEVCUT KAPININ DELİĞİ: `sezonluk-etiketi-duruyor`
-- Kapı `min 1`. Nüfus ÜÇ FİRMA olduğu için tek firmanın etiketi kaybolsa
-- kapı YEŞİL kalıyordu. KARŞI-OLGU DOĞRUDAN KOŞULDU (paylaşılan dosya
-- BOZULMADAN — hatalı formül çalıştırıldı, kayıt değiştirilmedi):
--   eski formül · tüm firmalar        = 257  (yeşil)
--   eski formül · BKM yeniden adlandı =  90  (HÂLÂ YEŞİL ← DELİK)
--   yeni formül · firma bazında MIN   =  23  (yeşil, doğru)
--   yeni formül · BKM yeniden adlandı =   0  (KIRMIZI ← kapı artık çalışıyor)
-- Kayıt SİLİNMEDİ, SQL'i firma-bazlı MIN'e çevrildi.
-- ---------------------------------------------------------------------
SELECT MIN(n) AS yeni_kapi FROM (
  SELECT Firma, SUM(CASE WHEN Kadro = N'SEZONLUK' THEN 1 ELSE 0 END) AS n
  FROM dbo.vw_PersonelDepartman WHERE Lokasyon LIKE 'MA%' GROUP BY Firma) t;

-- karşı-olgu: BKM_GENEL etiketi yeniden adlandırılmış varsayımı
SELECT MIN(n) AS karsi_olgu FROM (
  SELECT Firma, SUM(CASE WHEN Kadro = N'SEZONLUK' AND Firma <> 'BKM_GENEL' THEN 1 ELSE 0 END) AS n
  FROM dbo.vw_PersonelDepartman WHERE Lokasyon LIKE 'MA%' GROUP BY Firma) t;

-- Diğer dört kapının GÜNCEL değeri + nüfusu (tüm firmalar vs yalnız BKM):
--   kadro-etiket-kumesi-kapali  ihlal 0 · nüfus 1.296 (BKM 1.103)
--   primgunu-30-tavani          ihlal 0 · nüfus 34.397 (BKM 27.931)
--   puanbil-kisi-ay-tekilligi   ihlal 0 · nüfus  8.176 (BKM  5.761)
--   maliyet-kolonlari-duruyor   3 (sys.columns — firmadan bağımsız)
-- ⇒ Üçünde de nüfus GENİŞLEMİŞ, bu kapıları GÜÇLENDİRİR (delik yok).
--   Delik yalnız `min` karşılaştırması kullanan kapıdaydı: geniş nüfus,
--   "en az bir tane" eşiğini başka firmanın satırıyla karşılayabiliyordu.

-- ---------------------------------------------------------------------
-- BLOK 14 — vw_PuanBil → vw_PersonelDepartman ÖKSÜZ (%58,4)
-- ÖLÇÜLDÜ: 20.072 / 34.394 öksüz. Sağ uç TEKİL (1.296 = 1.296) → fan-out YOK.
--   Ters yön: kadro view'ında olup bordroda hiç görünmeyen 35 kişi.
--   Tekil kişi: bordro 4.010 · kadro view 1.296 → 2.749 kişi sağda YOK.
-- ⚠ Sema "join 1:1 ölçüldü (fan-out yok)" diyordu — DOĞRU ama EKSİK:
--   fan-out ölçülmüş, ÖKSÜZ HİÇ ÖLÇÜLMEMİŞTİ. Tekillik ≠ kapsam.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS oksuz FROM dbo.vw_PuanBil b
WHERE b.Personelno IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.vw_PersonelDepartman p WHERE p.Personelno = b.Personelno);

-- ---------------------------------------------------------------------
-- BLOK 15 — ⭐ ÖKSÜZÜN SEBEBİ: KADRO VIEW'I BİR "AYRILAN PENCERESİ"
-- ÖLÇÜLDÜ: öksüzler YALNIZ 2014-2023'te; 2024/2025/2026'da SIFIR.
--   2014:120 · 2015:735 · 2016:578 · 2017:450 · 2018:1.344 · 2019:1.891 ·
--   2020:3.242 · 2021:6.744 · 2022:3.660 · 2023:1.308
-- KURAL ÖLÇÜLDÜ: MIN(Ict) = 03.01.2024 · Ict < 2024-01-01 olan satır = 0 ·
--   Ict NULL (aktif) = 357 · MIN(Igt) = 03.01.2009 (giriş 2009'a gidiyor).
--   ⇒ Süzgeç GİRİŞ tarihinde değil ÇIKIŞ tarihinde: view = hâlâ çalışanlar
--     + 01.01.2024'ten SONRA ayrılanlar.
--   ⇒ Bu köprüyle INNER JOIN yazan her sorgu geçmişi SESSİZCE 2024'e kırpar.
-- ⚠ AS-OF TUZAĞI: aktif 357'nin 1'inin giriş tarihi GELECEKTE (14.09.2026,
--   ölçüm günü 12.09.2026). `Ict IS NULL` tek başına "bugün çalışıyor" demek
--   değil; as-of sayım `Igt <= @tarih` de ister.
-- ---------------------------------------------------------------------
SELECT b.Yil, COUNT(*) AS oksuz FROM dbo.vw_PuanBil b
WHERE b.Personelno IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.vw_PersonelDepartman p WHERE p.Personelno = b.Personelno)
GROUP BY b.Yil ORDER BY b.Yil;

SELECT CONVERT(varchar(10), MIN(Ict), 104) AS min_cikis,
       COUNT(CASE WHEN Ict < '20240101' THEN 1 END) AS cikis_2024_oncesi,
       COUNT(CASE WHEN Ict IS NULL THEN 1 END) AS aktif,
       CONVERT(varchar(10), MIN(Igt), 104) AS min_giris,
       CONVERT(varchar(10), MAX(Igt), 104) AS max_giris,
       COUNT(CASE WHEN Igt > GETDATE() THEN 1 END) AS gelecek_tarihli_giris
FROM dbo.vw_PersonelDepartman;

-- ---------------------------------------------------------------------
-- BLOK 16 — ⭐ NULL-ANAHTARLI ÇÖP SATIRLAR (DB genelinde bir desen)
-- ÖLÇÜLDÜ, ÖKSÜZ SAYISI İLE BİREBİR EŞİT:
--   perkbil  öksüz 1.821 / 21.837 (%8,3)  · NULL anahtar 1.821  → eşit
--   perobil  öksüz 2.981 / 12.422 (%24,0) · NULL anahtar 2.981  → eşit
--   puanbil  NULL anahtarlı 3 satır (Primgunu 0, Bt 0)
--   mesai    NULL anahtar 0
-- ⇒ Bu köprülerin öksüz oranı VERİ KALİTESİ SORUNU DEĞİL, tamamen çöp satır.
--   Anahtarı dolu satırlarda öksüz 0.
-- ⚠ İKİNCİ ETKİ: `GROUP BY Personelno,Yil,Ayindex HAVING COUNT(*)>1` denetimi
--   puanbil'deki 3 NULL satırı SAHTE MÜKERRER diye raporlar (yaşandı — "1 mükerrer
--   kişi-ay" bulundu, incelenince üçü de tamamen NULL anahtarlı çöp çıktı).
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS perkbil_oksuz FROM dbo.perkbil k
WHERE NOT EXISTS (SELECT 1 FROM dbo.puanbil b
                  WHERE b.Personelno = k.Personelno AND b.Yil = k.Yil AND b.Ayindex = k.Ayindex);
SELECT COUNT(*) AS perkbil_null_anahtar FROM dbo.perkbil
WHERE Yil IS NULL OR Ayindex IS NULL OR Personelno IS NULL;
-- (perobil için aynısı; mesai'de 0)

-- ---------------------------------------------------------------------
-- BLOK 17 — ⭐ Personelno KİŞİ DEĞİL, ÇALIŞMA DÖNEMİ
-- ÖLÇÜLDÜ: 1.296 Personelno ↔ yalnız 1.162 tekil TC kimlik (Vatno).
--   113 kimlik birden çok Personelno taşıyor · bir kişide en fazla 4.
--   Vatno boş satır YOK.
--   Naif ad-bazlı ayrım YETMEZ: 1.159 tekil AdSoyad, 116 ad çok-Personelno'lu;
--   ayrımı yapan Vatno (113 vaka). 109 vaka aynı firma (yeniden işe alım),
--   7 vaka firmalar arası (grup içi transfer).
-- ✅ AS-OF GÜVENLİ: aktif Personelno 357 = aktif Vatno 357 (aynı anda iki
--   dönem aktif olan kimse yok) → bugünkü kadro sayımı şişmiyor.
-- ⇒ Ama "kaç kişi çalıştı / devir / kıdem" soruları Vatno ile sayılmalı;
--   Personelno ile sayan %10,3 fazla sayar ve kıdemi ikiye böler.
-- Bu, codes:urn.kod2ID "aynı kişi iki kodda" tuzağının İK ikizidir.
-- ---------------------------------------------------------------------
SELECT COUNT(DISTINCT Personelno) AS pno, COUNT(DISTINCT Vatno) AS kisi,
       COUNT(DISTINCT AdSoyad) AS ad
FROM dbo.vw_PersonelDepartman;

SELECT COUNT(*) AS ayni_kimlik_cok_pno FROM (
  SELECT Vatno FROM dbo.vw_PersonelDepartman
  GROUP BY Vatno HAVING COUNT(DISTINCT Personelno) > 1) t;

-- ---------------------------------------------------------------------
-- BLOK 18 — Aynı kişi aynı ayda İKİ bordro satırı: FTE şişiyor mu?
-- ÖLÇÜLDÜ: 13 kişi-ay (7'si mağaza). Firma kırılımı: 10 aynı firma
--   (yeniden işe alım) · 3 firmalar arası (transfer).
-- ✅ prim günü toplamı 31'i AŞAN vaka 0 (max 31, min 4) → ay iki dönem
--   arasında BÖLÜNÜYOR, FTE = SUM(Primgunu)/30 ŞİŞMİYOR.
-- ⚠ Mevcut kapı `puanbil-kisi-ay-tekilligi` bunu GÖREMEZ: Personelno ile
--   gruplar, bu vakada Personelno'lar FARKLIDIR. Yeni kapı
--   `zirve-kisi-ay-prim-31-tavani` Vatno ile gruplar.
-- ---------------------------------------------------------------------
SELECT t.firma_sayisi, COUNT(*) AS vaka,
       SUM(CASE WHEN t.prim_toplam > 31 THEN 1 ELSE 0 END) AS prim31_asan,
       MAX(t.prim_toplam) AS max_prim, MIN(t.prim_toplam) AS min_prim
FROM (SELECT p.Vatno, b.Yil, b.Ayindex,
             COUNT(DISTINCT b.Firma) AS firma_sayisi,
             SUM(CONVERT(int, ISNULL(b.Primgunu, 0))) AS prim_toplam
      FROM dbo.vw_PuanBil b
      JOIN dbo.vw_PersonelDepartman p ON p.Personelno = b.Personelno
      GROUP BY p.Vatno, b.Yil, b.Ayindex
      HAVING COUNT(DISTINCT b.Personelno) > 1) t
GROUP BY t.firma_sayisi;

-- ---------------------------------------------------------------------
-- BLOK 19 — YENİ KAPILARIN KIRILABİLİRLİK KANITI
-- Üçü de: gerçek değer 0 (yeşil), karşı-olgu ≠ 0 (kırmızı).
-- Karşı-olgu HATALI FORMÜL DOĞRUDAN KOŞULARAK üretildi — paylaşılan dosya
-- bozulmadı (paralel oturum yanlış alarm almasın).
--   zirve-aktif-kadroda-personelno-kisiye-esit : 0   · karşı-olgu (aktif süzgeci yok) 134
--   zirve-kisi-ay-prim-31-tavani               : 0   · karşı-olgu (eşik 25)        12.327
--   zirve-vw-puanbil-bkm-dilimi-tabana-esit    : 0   · karşı-olgu (firma süzgeci yok) 6.466
-- Nüfuslar: 357 · 14.309 kişi-ay · 27.931.
-- ---------------------------------------------------------------------
SELECT (SELECT COUNT(DISTINCT Personelno) FROM dbo.vw_PersonelDepartman WHERE Ict IS NULL)
     - (SELECT COUNT(DISTINCT Vatno)      FROM dbo.vw_PersonelDepartman WHERE Ict IS NULL) AS kapi_2;

SELECT COUNT(*) AS kapi_3 FROM (
  SELECT p.Vatno, b.Yil, b.Ayindex FROM dbo.vw_PuanBil b
  JOIN dbo.vw_PersonelDepartman p ON p.Personelno = b.Personelno
  GROUP BY p.Vatno, b.Yil, b.Ayindex
  HAVING SUM(CONVERT(int, ISNULL(b.Primgunu, 0))) > 31) t;

SELECT ABS((SELECT COUNT(*) FROM dbo.vw_PuanBil WHERE Firma = 'BKM_GENEL')
         - (SELECT COUNT(*) FROM dbo.puanbil)) AS kapi_4;

-- ---------------------------------------------------------------------
-- BLOK 20 — perbilgi 188 KOLON: kaçı bilgi taşıyor?
-- Kolon listesi sys.columns'tan ÜRETİLDİ (elle yazılmadı; "liste elle yazılmaz").
-- ÖLÇÜLDÜ (3.578 satır): 20 kolon 0 tekil (tamamen boş) · 42 kolon 1 tekil ·
--   44 kolon 2-3 tekil · geri kalan 82. ⇒ ÖLÜ KOLON 62/188 = %33,0.
-- Tamamen boş olanlar: Firmakodu · Ozelsig · Gelirindirim · Sskindirim ·
--   Malulluk · Hastaliknormal · Hastalikcirak · Arti · Askerlikbittar ·
--   Maasyuzdesi · S_1 · S_2 · Agi_dahil_haric · NakilGidilenIsYeri ·
--   girisRefNo · cikisRefNo · BES_CikisTarihi · SporDali ·
--   SaglikSigortasiVergiIndirimi · UcusDalisOrani
-- ⚠ `Firmakodu` kolon-adı yakınsamasında 9 tabloda görünüp ANAHTAR ADAYI
--   sanılmıştı — perbilgi'de ÖLÜ.
-- ⚠ `Arti` burada 0 tekil (hepsi NULL) → Arti HER tabloda IDENTITY DEĞİL.
-- Bu, DerinSIS'te altı kez çıkan "tanımlı ama hiç doldurulmayan kolon"
-- sınıfının Zirve karşılığıdır.
-- ---------------------------------------------------------------------
-- Üretim adımı (Python): sys.columns'tan kolon adları alınır, her biri için
--   COUNT(DISTINCT [kolon]) AS [kolon] üretilip tek SELECT'te birleştirilir.
SELECT c.name AS kolon, TYPE_NAME(c.user_type_id) AS tip
FROM sys.columns c WHERE c.object_id = OBJECT_ID('dbo.perbilgi') ORDER BY c.column_id;
-- → üretilen sorgu 8.343 karakter, 188 COUNT(DISTINCT ...) içerir.
