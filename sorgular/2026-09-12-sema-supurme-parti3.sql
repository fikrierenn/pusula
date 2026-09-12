/* ============================================================================
   ŞEMA SÜPÜRMESİ — 3. PARTİ  (2026-09-12)
   DB: DerinSISBkm (profil: erp)
   Kuyruk: 403 iş tablosu · parti 1: 9 · parti 2: 10 · bu parti 10 → kalan 374.

   ⚠ BU PARTİNİN BULGUSU: veritabanının EN BÜYÜK objesi bir iş tablosu değil,
     silinmeyen bir ENTEGRASYON LOGU — 1,82 milyar satır / 213 GB / HEAP.
   ============================================================================ */

/* 1) KOLON + PK dökümü (10 tablo) — Türkçe ı'lı ad LIKE ile yakalanır */
SELECT s.name+'.'+o.name AS tablo, c.column_id, c.name AS kolon, ty.name AS tip,
       c.is_nullable, CASE WHEN ic.key_ordinal IS NOT NULL THEN ic.key_ordinal ELSE 0 END AS pk
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
JOIN   DerinSISBkm.sys.columns c ON c.object_id = o.object_id
JOIN   DerinSISBkm.sys.types  ty ON ty.user_type_id = c.user_type_id
LEFT JOIN DerinSISBkm.sys.indexes i ON i.object_id = o.object_id AND i.is_primary_key = 1
LEFT JOIN DerinSISBkm.sys.index_columns ic ON ic.object_id = o.object_id
       AND ic.index_id = i.index_id AND ic.column_id = c.column_id
WHERE  s.name+'.'+o.name IN ('ent.api_log','ent.fiyat_tarihce','eftr.efatFirma','ist.istAyr',
                             'drs.derinus2_palet','bkm.Enf_OrtakUrunler','dbo.fatFFOzet',
                             'depo.emirTrh','dbo.urnBrkd')
    OR (s.name='depo' AND o.name LIKE 'say%mAyr')
ORDER BY tablo, c.column_id;

/* 2) BOYUT + İNDEKS
   ⚠ TUZAK: `sys.partitions` ile `sys.allocation_units` JOIN'lenince satır sayısı
     ŞİŞER — LOB/ROW_OVERFLOW birimi olan tabloda her partition 3 kez sayılır.
     `total_pages` doğru toplanır, `rows` DEĞİL. api_log'da 1,82 milyar → 5,45 milyar
     göründü. Satır sayısı AYRI okunur (blok 2b). */
SELECT s.name+'.'+o.name AS tablo,
       CONVERT(decimal(10,1), SUM(a.total_pages)*8.0/1024/1024) AS gb,
       (SELECT COUNT(*) FROM DerinSISBkm.sys.indexes ix
         WHERE ix.object_id=o.object_id AND ix.index_id>0) AS idx_sayisi
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id=o.schema_id
JOIN   DerinSISBkm.sys.partitions p ON p.object_id=o.object_id
JOIN   DerinSISBkm.sys.allocation_units a ON a.container_id=p.partition_id
WHERE  s.name+'.'+o.name IN ('ent.api_log','dbo.urnBrkd','ist.istAyr')
    OR (s.name='depo' AND o.name LIKE 'say%mAyr')
GROUP BY s.name, o.name, o.object_id;

/* 2b) SATIR SAYISI — index_id 0/1 (heap ya da kümelenmiş), allocation JOIN'siz */
SELECT s.name+'.'+o.name AS tablo, p.rows AS satir, p.index_id
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id=o.schema_id
JOIN   DerinSISBkm.sys.partitions p ON p.object_id=o.object_id AND p.index_id IN (0,1)
WHERE  s.name='ent' AND o.name='api_log';
/* Ölçüm: 1.816.513.551 satır · 213,4 GB · index_id 0 = HEAP (kümelenmiş indeks YOK).
   Tek indeks: ktarihdesc (ktarih) → tarih aralığı ucuz, başka her erişim 213 GB. */

/* ============================================================================
   3) ★ ent.api_log — NEDİR, NE KADAR HIZLI BÜYÜR
   ============================================================================ */
SELECT CONVERT(varchar(19),MIN(ktarih),120) AS ilk,
       CONVERT(varchar(19),MAX(ktarih),120) AS son
FROM   DerinSISBkm.ent.api_log WITH(NOLOCK);
/* 2024-05-15 00:06:38 .. 2026-09-12 11:37:17 — BUDAMA HİÇ YAPILMAMIŞ. */

SELECT COUNT_BIG(*) AS son7gun
FROM   DerinSISBkm.ent.api_log WITH(NOLOCK)
WHERE  ktarih >= DATEADD(DAY,-7,GETDATE());
/* 22.213.810 → ~3,17M satır/gün ≈ 37 satır/saniye, kesintisiz. */

SELECT api_entegrasyon_tip AS tip, api_durum AS durum, COUNT_BIG(*) AS adet,
       COUNT(DISTINCT stkid) AS urun, AVG(DATALENGTH(api_cevap)) AS ort_cevap_bayt
FROM   DerinSISBkm.ent.api_log WITH(NOLOCK)
WHERE  ktarih >= DATEADD(DAY,-1,GETDATE())
GROUP BY api_entegrasyon_tip, api_durum ORDER BY adet DESC;
/* tip 5/durum 2 → 3.552.672 (%99,5) · tip 5/3 7.879 · tip 2/3 4.246 · tip 2/2 3.234
   tip 1/2 3.165 · tip 1/3 584 · tip 3/2 215 · tip 3/3 3
   ⭐ COUNT(DISTINCT stkid) = 0 HER GRUPTA → stkid her satırda NULL. */

SELECT COUNT_BIG(*) AS satir,
       SUM(CASE WHEN stkid IS NULL THEN 1 ELSE 0 END)         AS stkid_null,
       SUM(CASE WHEN tsoft_urun_id IS NULL THEN 1 ELSE 0 END) AS tsoft_null,
       COUNT(DISTINCT barkod) AS tekil_barkod,
       SUM(CASE WHEN barkod='' THEN 1 ELSE 0 END) AS barkod_bos
FROM   DerinSISBkm.ent.api_log WITH(NOLOCK)
WHERE  ktarih >= DATEADD(DAY,-1,GETDATE());
/* 3.571.998 satır · stkid_null 3.571.998 · tsoft_null 3.571.998 · tekil barkod 72.245
   ⇒ İKİ ÜRÜN-KİMLİK KOLONU VAR, İKİSİ DE BOŞ. Ürün anahtarı yalnız barkod.
   ⇒ 3,55M push / 72.245 barkod = ürün başına ~49 push/gün. */

SELECT TOP 5 stkid, tsoft_urun_id, api_entegrasyon_tip, api_durum,
       LEFT(api_cevap,60) AS cevap, barkod, CONVERT(varchar(19),ktarih,120) AS ktrh
FROM   DerinSISBkm.ent.api_log WITH(NOLOCK)
WHERE  ktarih >= DATEADD(HOUR,-2,GETDATE()) AND api_entegrasyon_tip=5;
/* Hepsi: "Ürün stoğu başarıyla güncellendi! - 999999" ⇒ T-Soft STOK PUSH LOGU. */

SELECT TOP 8 api_entegrasyon_tip AS tip, LEFT(api_cevap,70) AS cevap, COUNT_BIG(*) AS adet
FROM   DerinSISBkm.ent.api_log WITH(NOLOCK)
WHERE  ktarih >= DATEADD(DAY,-1,GETDATE()) AND api_durum=3
GROUP BY api_entegrasyon_tip, LEFT(api_cevap,70) ORDER BY adet DESC;
/* HATALAR (günde 12.712 = %0,36):
     "ProductCode sistemde bulunamadı!"        11.629  ← T-Soft'ta olmayan ürüne push
     "Geçersiz token, lütfen giriş yapın!"        495  ← KİMLİK DOĞRULAMA HATASI
     "DefaultCategoryCode boş bırakılamaz!"        84
     "ProductName min 2 karakter olmalıdır!"      ~83
   ⇒ %99,64'ü "başarılı" gürültüsü; ASIL BİLGİ olan %0,36 hata bunun içinde gömülü.
     Hatayı gören bir uyarı mekanizması YOK (kod erişimi 0 dosya). */

/* ============================================================================
   4) ★ depo.sayımAyr — EBEVEYN KİM? İKİ HİPOTEZ, İKİSİ DE ÇÜRÜTÜLDÜ, ÜÇÜNCÜ TUTTU
   ============================================================================ */
/* 4a) HİPOTEZ A (ÇÜRÜTÜLDÜ): spID → depo.sayım.sID */
SELECT COUNT_BIG(*) AS ayr_satir, COUNT(DISTINCT a.spID) AS ayr_baslik,
       SUM(CASE WHEN h.sID IS NULL THEN 1 ELSE 0 END) AS oksuz_satir
FROM   DerinSISBkm.depo.sayımAyr a WITH(NOLOCK)
LEFT JOIN DerinSISBkm.depo.sayım h WITH(NOLOCK) ON h.sID = a.spID;
/* 6.716.315 satırın 6.716.315'i öksüz → "tablo ölü/kopuk" denebilirdi. DEMEDİK. */

/* 4b) HİPOTEZ B (ÇÜRÜTÜLDÜ): saID başlık mı? */
SELECT (SELECT COUNT_BIG(*) FROM DerinSISBkm.depo.sayım WITH(NOLOCK))          AS sayim_satir,
       (SELECT MAX(sID)     FROM DerinSISBkm.depo.sayım WITH(NOLOCK))          AS sayim_max_sID,
       (SELECT COUNT(DISTINCT saID) FROM DerinSISBkm.depo.sayımAyr WITH(NOLOCK)) AS ayr_tekil_saID,
       (SELECT MAX(saID)    FROM DerinSISBkm.depo.sayımAyr WITH(NOLOCK))       AS ayr_max_saID;
/* sayım 773 satır (sID max 1772) · saID 6.716.315 TEKİL (max 6.750.456)
   ⇒ saID BAŞLIK DEĞİL, SATIR KİMLİĞİ. sayım.sID ile join edilirse 773 satır
     SAHTE eşleşir (düşük id çakışması) — tam olarak "makul ama yanlış" sınıfı. */

/* 4c) ★ HİPOTEZ C (TUTTU): spID → depo.paletTnm.pID */
SELECT COUNT(*) AS spID_paletTnm_oksuz
FROM   DerinSISBkm.depo.sayımAyr a WITH(NOLOCK)
WHERE  NOT EXISTS (SELECT 1 FROM DerinSISBkm.depo.paletTnm p WITH(NOLOCK) WHERE p.pID = a.spID);
/* ÖKSÜZ 0 (6,7M satırda). ⇒ GRAIN = palet × ürün. */

SELECT CONVERT(varchar(10),MIN(p.pkTarih),120) AS palet_ilk,
       CONVERT(varchar(10),MAX(p.pkTarih),120) AS palet_son,
       COUNT(DISTINCT a.spID) AS palet, COUNT(DISTINCT a.spStkID) AS urun,
       COUNT(DISTINCT a.termID) AS terminal,
       CONVERT(decimal(18,0), SUM(a.sAdet)) AS toplam_adet
FROM   DerinSISBkm.depo.sayımAyr a WITH(NOLOCK)
JOIN   DerinSISBkm.depo.paletTnm p WITH(NOLOCK) ON p.pID = a.spID;
/* 2021-06-30 .. 2021-08-04 · 3.708 palet · 185.255 ürün · 2 terminal · 33.921.282 adet
   ⇒ TEK BİR KAMPANYA (beş hafta, 2021 yazı). Ondan beri ölü.
   ⇒ 6,7M satır · SIFIR İNDEKS · bugünün sayımı bkm.Sayim* alt sisteminde. */

/* ============================================================================
   5) ★ dbo.urnBrkd — KANONİK BARKOD KÖPRÜSÜNÜN ÖLÇÜLMEMİŞ YARISI
   ============================================================================ */
SELECT COUNT_BIG(*) AS satir, COUNT(DISTINCT urnBrkdStkID) AS urun,
       SUM(CASE WHEN urnBrkdOnce=0 THEN 1 ELSE 0 END)    AS once0,
       SUM(CASE WHEN urnBrkdAltStkId>0 THEN 1 ELSE 0 END) AS alt_urun,
       SUM(CASE WHEN u.stkID IS NULL THEN 1 ELSE 0 END)   AS oksuz
FROM   DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = b.urnBrkdStkID;
/* 894.994 satır · 837.547 ürün · once0 837.547 · alt_urun 0 · öksüz 0 */

SELECT kac AS once0_sayisi, COUNT_BIG(*) AS urun_adedi FROM (
    SELECT urnBrkdStkID, SUM(CASE WHEN urnBrkdOnce=0 THEN 1 ELSE 0 END) AS kac
    FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK) GROUP BY urnBrkdStkID) z
GROUP BY kac ORDER BY urun_adedi DESC;
/* TEK GRUP: 1 → 837.547 ürün. 0 veya 2+ olan ürün YOK.
   ⇒ WHERE urnBrkdOnce=0 ÜRÜN BAŞINA TEK SATIR SEÇER — fan-out riski YOKTUR.
     CLAUDE.md'nin kanonik barkod join'inin dayandığı varsayım ARTIK ÖLÇÜLDÜ. */

/* 5b) KIRILABİLİRLİK KANITI — paylaşılan dosyaya DOKUNMADAN, iki hatalı formül
       doğrudan koşuldu. Kapı kırmızıya dönebiliyor. */
SELECT 'dogru  (Once=0)' AS formul, COUNT_BIG(*) AS ihlal FROM (
    SELECT urnBrkdStkID FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK)
    GROUP BY urnBrkdStkID HAVING SUM(CASE WHEN urnBrkdOnce=0 THEN 1 ELSE 0 END) <> 1) a
UNION ALL
SELECT 'HATA 1 (Once=1 birincil sanilir)', COUNT_BIG(*) FROM (
    SELECT urnBrkdStkID FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK)
    GROUP BY urnBrkdStkID HAVING SUM(CASE WHEN urnBrkdOnce=1 THEN 1 ELSE 0 END) <> 1) b
UNION ALL
SELECT 'HATA 2 (suzgec hic kullanilmaz)', COUNT_BIG(*) FROM (
    SELECT urnBrkdStkID FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK)
    GROUP BY urnBrkdStkID HAVING COUNT(*) <> 1) c;
/*   doğru formül                         0
     HATA 1 (Once=1 birincil sanılırsa)  828.413
     HATA 2 (süzgeç hiç kullanılmazsa)    10.428  ← çok-barkodlu ürün sayısı;
                                                    süzgeçsiz JOIN GERÇEKTEN fan-out yapar
   Değişmez: urnbrkd-birincil-barkod-tekil (sema/degismezler.json, 46.) */

/* ============================================================================
   6) DİĞER ALTI TABLO — grain ve tazelik
   ============================================================================ */
SELECT 'ent.fiyat_tarihce' AS t, CONVERT(varchar(10),MIN(tarih),120) AS ilk,
       CONVERT(varchar(10),MAX(tarih),120) AS son, COUNT_BIG(*) AS satir
FROM   DerinSISBkm.ent.fiyat_tarihce WITH(NOLOCK)
UNION ALL SELECT 'eftr.efatFirma', CONVERT(varchar(10),MIN(KatilimTarihi),120),
       CONVERT(varchar(10),MAX(KatilimTarihi),120), COUNT_BIG(*) FROM DerinSISBkm.eftr.efatFirma WITH(NOLOCK)
UNION ALL SELECT 'depo.emirTrh', CONVERT(varchar(10),MIN(tarih),120),
       CONVERT(varchar(10),MAX(tarih),120), COUNT_BIG(*) FROM DerinSISBkm.depo.emirTrh WITH(NOLOCK)
UNION ALL SELECT 'dbo.fatFFOzet', CONVERT(varchar(10),MIN(feTarih),120),
       CONVERT(varchar(10),MAX(feTarih),120), COUNT_BIG(*) FROM DerinSISBkm.dbo.fatFFOzet WITH(NOLOCK)
UNION ALL SELECT 'bkm.Enf_OrtakUrunler', CONVERT(varchar(10),MIN(SecilenAy),120),
       CONVERT(varchar(10),MAX(SecilenAy),120), COUNT_BIG(*) FROM DerinSISBkm.bkm.Enf_OrtakUrunler WITH(NOLOCK);
/* ent.fiyat_tarihce   2022-02-01 .. 2023-12-25  DONMUŞ (halefi fiyat_tarihce_tsoft)
   eftr.efatFirma      2010-01-01 .. 2026-09-11  CANLI
   depo.emirTrh        2021-07-01 .. 2026-09-12  CANLI
   dbo.fatFFOzet       2021-06-01 .. 2022-06-18  DONMUŞ (8 indeksle terk edilmiş)
   bkm.Enf_OrtakUrunler 2024-01-01 .. 2026-08-01 CANLI (aylık) */

SELECT COUNT_BIG(*) AS satir, COUNT(DISTINCT ehID) AS baslik,
       SUM(CASE WHEN ehSipID>0 THEN 1 ELSE 0 END) AS siparise_bagli,
       COUNT(DISTINCT ehFirma) AS firma, COUNT(DISTINCT ehStkID) AS urun,
       SUM(CASE WHEN sevkAdet IS NULL THEN 1 ELSE 0 END) AS sevk_null
FROM   DerinSISBkm.ist.istAyr WITH(NOLOCK);
/* 1.907.254 · 82.061 başlık · 1.142.888 siparişe bağlı (%59,9) · 345 tedarikçi
   · 186.573 ürün · ⚠ sevk_null = 1.907.254 → sevkAdet HER SATIRDA NULL.
     "kalan = sipAdet - sevkAdet" SESSİZCE NULL döner. */

SELECT COUNT_BIG(*) AS mukerrer_anahtar FROM (
    SELECT ehID, ehSira FROM DerinSISBkm.ist.istAyr WITH(NOLOCK)
    GROUP BY ehID, ehSira HAVING COUNT(*)>1) z;
/* 0 → (ehID,ehSira) doğal anahtar TEKİL ama PK olarak tanımlı DEĞİL. */

SELECT 'emirTrh-emTrhID-mukerrer' AS olcum, COUNT_BIG(*) AS deger FROM (
    SELECT emTrhID FROM DerinSISBkm.depo.emirTrh WITH(NOLOCK) GROUP BY emTrhID HAVING COUNT(*)>1) a
UNION ALL SELECT 'derinus2_palet-drs2-cok-palet', COUNT_BIG(*) FROM (
    SELECT dpDrs2Id FROM DerinSISBkm.drs.derinus2_palet WITH(NOLOCK) GROUP BY dpDrs2Id HAVING COUNT(*)>1) b
UNION ALL SELECT 'Enf-Kaynak-kume', COUNT(DISTINCT Kaynak) FROM DerinSISBkm.bkm.Enf_OrtakUrunler WITH(NOLOCK);
/* emTrhID mükerrer 4.515  ⚠ adı kimlik gibi, TEKİL DEĞİL → JOIN anahtarı yapılırsa fan-out
   derinus2_palet 121.029 okuma birden çok palete bölünmüş → JOIN sonrası ÇİFT SAYAR
   Enf Kaynak = 2 (bkmkitapcom / Magazalar) */

SELECT 'Enf-Kaynak' AS k, Kaynak AS deger, COUNT_BIG(*) AS adet
FROM   DerinSISBkm.bkm.Enf_OrtakUrunler WITH(NOLOCK) GROUP BY Kaynak
UNION ALL SELECT 'efat-FirmaTipi', CONVERT(varchar(50),FirmaTipi), COUNT_BIG(*)
FROM   DerinSISBkm.eftr.efatFirma WITH(NOLOCK) GROUP BY FirmaTipi;
/* bkmkitapcom 916.738 · Magazalar 633.268 | FirmaTipi 1 → 2.295.563 (%96,5) · 0 → 82.684 */

SELECT COUNT_BIG(*) AS satir, COUNT(DISTINCT VergiNo) AS tekil_vergino,
       COUNT(DISTINCT Etiket) AS tekil_etiket
FROM   DerinSISBkm.eftr.efatFirma WITH(NOLOCK);
/* 2.378.247 · 2.188.856 · 1.471.101
   ⚠ AYNI VERGİ NO ÇOK SATIRDA (189.391 fark) → VergiNo ile JOIN FAN-OUT yapar. */

/* 7) KOD ERİŞİMİ (grep -rlw · dashboard+scripts+sorgular+tools)
     api_log 0 · sayımAyr 3 (üçü de bu deponun kendi keşif arşivi) · fiyat_tarihce 0
     efatFirma 0 · istAyr 0 · derinus2_palet 0 · Enf_OrtakUrunler 0 · fatFFOzet 0
     emirTrh 0 · urnBrkd 13 (dashboard 3 + arşiv 9 + sema özeti)
   ⚠ ERİŞİM ≠ DOĞRULUK — "kod tanıyor mu" der, doğru anlaşıldığını DEĞİL. */

/* ============================================================================
   PARTİ 3 ÖZETİ — üç tekrar eden desen (parti 1+2+3 birlikte)
   1. PK'SIZ BÜYÜK TABLO: api_log 1,82 MİLYAR · sayımAyr 6,7M (indeks bile yok) ·
      istAyr 1,9M (doğal anahtar tekil ama tanımsız) · emirTrh 1,38M (emTrhID
      TEKİL DEĞİL) · fatFFOzet 1,45M. sipAyr / SiparisOdemeDurum / OdakIrsaliyeDetay
      (parti 2) ile birlikte bu, şemanın EN YAYGIN yapısal açığı.
   2. TANIMLI AMA HİÇ DOLDURULMAYAN KOLON: api_log.stkid + api_log.tsoft_urun_id
      (%100 NULL) · istAyr.sevkAdet (%100 NULL) · urnBrkd.urnBrkdAltStkId (%100 sıfır).
      Adı bir şey vaat eder, NULL/0 döner, SQL hata vermez.
   3. DONMUŞ TABLO CANLI KARDEŞİNİN YANINDA DURUYOR: ent.fiyat_tarihce (2023'te sustu)
      ↔ ent.fiyat_tarihce_tsoft (canlı) · fatFFOzet (2022) · sayımAyr (2021) ·
      Rapor_IrsHrk_GunlukOzet + StokBakiyeGunluk (parti 2, 9 ay bayat).
      Hiçbirinde "bu tablo artık beslenmiyor" yazan bir işaret YOK.
   ============================================================================ */
