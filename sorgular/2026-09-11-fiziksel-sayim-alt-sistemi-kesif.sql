/* ============================================================================
   FİZİKSEL SAYIM ALT SİSTEMİ — KEŞİF  (2026-09-11)
   DB: DerinSISBkm (profil: erp)

   NEDEN: `sql-server-conventions.md` § "WMS DE MUTLAK DOĞRU DEĞİL" diyor ki WMS ile
   defter çelişirse sayı ŞÜPHELİdir ve "fiziksel sayım yapılmadan karara dayanak
   alınmaz". Ama o fiziksel sayımın NEREDE durduğu sema'da hiç yoktu. `sema kapsam`
   öğrenme kuyruğunda `sID` adı `depo.sayım` tablosuna çıktı, oradan tüm alt sistem.

   BULGU ÖZETİ:
     · 36 sayım objesi var. CANLI olanlar:
         bkm.SayimLog            13.420.242   (raf+ürün düzeyi iz, ADET YOK)
         depo.sayımAyr            6.716.315
         bkm.SayimEmirDetaylari   2.099.062
         bkm.SayimEmirBaslik         49.907   (2023-07-20 → 2026-09-11, 4 mekan)
         bkm.SayimBaslik              5.671
         depo.sayım                     773   (2021-07-01 → 2026-01-13)
         depo.sayimAnlik                  0
     · bkm.SayimEmirBaslik: Kesinlesti 15.087 · Tamamlandi 49.366 · İptal 35.021 (%70)
       ⚠ %70 iptal ARIZA DEĞİL — emirleri otomatik üreten/kapatan job'lar var.
     · TUZAK: depo.sayım'da `sTamam` durum alanı DEĞİL (773 kaydın hepsinde 0);
       gerçek durum `sDurum` (761→1, 12→0). Alternatif açıklama ölçülerek elendi.
     · Tablo adı Türkçe ı ile: depo.[sayım] · depo.[sayımAyr]. ASCII `sayim` BAŞKA
       tablolardır (depo.sayimAnlik, depo.sayimIslemeLogu).
     · KULLANICI (2026-09-11): "mağaza sayımlarını bizim yazdığımız yapı yönetiyor,
       depo sayımı içinde eksik fazla vs için sayım emri oluşturan job var."
       → bkm.Sayim* ailesi app-owned ama BU DEPO YAZMAZ; buradan SALT-OKUMA.
   ============================================================================ */

/* 1) Sayım ile ilgili tüm objeler — LİSTE ELLE YAZILMAZ, sys'ten gelir */
SELECT s.name AS sema, t.name AS tablo, t.type_desc
FROM sys.objects t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.type IN ('U','V')
  AND (t.name LIKE '%ay_m%')          -- Türkçe ı için tek-karakter joker
ORDER BY s.name, t.name;

/* 2) Hangisi CANLI — nüfus ölçümü (0 satır "temiz" değil, "bakılacak şey yok") */
SELECT 'bkm.SayimEmirBaslik'    AS obje, COUNT_BIG(*) AS satir FROM DerinSISBkm.bkm.SayimEmirBaslik    WITH(NOLOCK)
UNION ALL SELECT 'bkm.SayimEmirDetaylari', COUNT_BIG(*) FROM DerinSISBkm.bkm.SayimEmirDetaylari WITH(NOLOCK)
UNION ALL SELECT 'bkm.SayimLog',           COUNT_BIG(*) FROM DerinSISBkm.bkm.SayimLog            WITH(NOLOCK)
UNION ALL SELECT 'bkm.SayimBaslik',        COUNT_BIG(*) FROM DerinSISBkm.bkm.SayimBaslik         WITH(NOLOCK)
UNION ALL SELECT 'bkm.WMSSayimTalep',      COUNT_BIG(*) FROM DerinSISBkm.bkm.WMSSayimTalep       WITH(NOLOCK)
UNION ALL SELECT 'bkm.DepoSayimBaslik',    COUNT_BIG(*) FROM DerinSISBkm.bkm.DepoSayimBaslik     WITH(NOLOCK)
UNION ALL SELECT 'depo.sayim(TR)',         COUNT_BIG(*) FROM DerinSISBkm.depo.[sayım]            WITH(NOLOCK)
UNION ALL SELECT 'depo.sayimAyr(TR)',      COUNT_BIG(*) FROM DerinSISBkm.depo.[sayımAyr]         WITH(NOLOCK)
UNION ALL SELECT 'depo.sayimAnlik',        COUNT_BIG(*) FROM DerinSISBkm.depo.sayimAnlik         WITH(NOLOCK);

/* 3) Kolon dökümü — elle yazılmaz */
SELECT t.name AS tablo, c.column_id, c.name AS kolon, ty.name AS tip, c.is_nullable
FROM sys.columns c
JOIN sys.objects t  ON t.object_id  = c.object_id
JOIN sys.schemas s  ON s.schema_id  = t.schema_id
JOIN sys.types   ty ON ty.user_type_id = c.user_type_id
WHERE (s.name = 'bkm'  AND t.name IN ('SayimEmirBaslik','SayimLog'))
   OR (s.name = 'depo' AND t.name = N'sayım')
ORDER BY s.name, t.name, c.column_id;

/* 4) Emir kapsamı + bayrak dağılımı (İPTAL oranını yorumlamadan ÖNCE job'lara bak) */
SELECT MIN(SayimTarihi) AS ilk, MAX(SayimTarihi) AS son, COUNT(*) AS emir,
       SUM(CASE WHEN Kesinlesti = 1 THEN 1 ELSE 0 END) AS kesinlesen,
       SUM(CASE WHEN Tamamlandi = 1 THEN 1 ELSE 0 END) AS tamamlanan,
       SUM(CASE WHEN Iptal      = 1 THEN 1 ELSE 0 END) AS iptal,
       COUNT(DISTINCT MekanId) AS mekan
FROM DerinSISBkm.bkm.SayimEmirBaslik WITH(NOLOCK);

/* 5) depo.sayım TUZAĞI — sTamam durum alanı DEĞİL, sDurum'dur */
SELECT CAST(sDurum AS int) AS sDurum, CAST(sTamam AS int) AS sTamam,
       COUNT(*) AS adet, MIN(kTarih) AS ilk, MAX(kTarih) AS son
FROM DerinSISBkm.depo.[sayım] WITH(NOLOCK)
GROUP BY sDurum, sTamam
ORDER BY sDurum, sTamam;

/* 6) SAYIM JOB'LARI — "geçmiş yok" ile "hiç koşmadı" AYNI DEĞİL.
      sysjobhistory temizlenmiş olabilir; kalıcı alan sysjobservers.last_run_date. */
SELECT j.name AS job, j.enabled, js.last_run_date, js.last_run_outcome,
       CASE js.last_run_outcome WHEN 0 THEN 'basarisiz' WHEN 1 THEN 'basarili'
                                WHEN 3 THEN 'iptal'     WHEN 5 THEN 'bilinmiyor' END AS sonuc
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobservers js ON js.job_id = j.job_id
WHERE j.name LIKE '%ay_m%' OR j.name LIKE '%Sayim%'
ORDER BY j.name;
/* Ölçüm 2026-09-11:
     ReyonSayimiDuzenle                        enabled=1  son 20260911  basarili
     SayimOtoKapatma                           enabled=1  son 20260911  basarili
     WMS-GunlukSayimEmiri                      enabled=1  son 20260911  basarili
     Depo Iptal Emir Satırlarına Sayım oluştur enabled=0  son 0         HİÇ KOŞMAMIŞ
   İlk üçü canlı; dördüncüsü KAPALI ve hiç koşmamış (adı gereği farklı bir iş:
   iptal edilen emir satırları için sayım). Depo tarafını besleyen canlı job
   `WMS-GunlukSayimEmiri`. */

/* 7) SAYIM PROSEDÜRLERİ — kullanıcı: "bkm şemasında hem tablo hem SP'ler var".
      Şifreli mi diye BAKMADAN "yok" deme: NULL definition üç sebepten olur
      (WITH ENCRYPTION · yanlış şema · VIEW DEFINITION izni). Şemadan bağımsız sor. */
SELECT s.name AS sema, o.name AS ad, o.type_desc,
       CONVERT(varchar(10), o.modify_date, 120) AS degisim,
       CASE WHEN m.definition IS NULL THEN 'OKUNAMIYOR' ELSE 'okunur' END AS tanim
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
WHERE o.type IN ('P','FN','IF','TF')
  AND (o.name LIKE '%ay_m%' OR o.name LIKE '%Sayim%')
ORDER BY s.name, o.name;
/* Ölçüm 2026-09-11: 19 obje (bkm 14 · depo 3 · dbo 2), HİÇBİRİ şifreli değil.
   ⚠ İKİ YAZIM BİR ARADA: `bkm.SayımEksiStokGetir` ve `depo.[sayım]` Türkçe ı ile;
   `bkm.Sayim*` ailesi ve `depo.sayimAnlik` ASCII. Tahmin edilemez — sys'ten okunur.
   ⚠ YAZMA YOLU SP'DİR: bu depo sayım tablolarına YAZMAZ (erp-write-policy izin
   listesinde yoklar ve olmamalılar); yazan taraf BKM'nin kendi uygulamasıdır. */

/* ============================================================================
   8) SP'LERİ ÇALIŞTIR — ama ÖNCE TANIMLARINI OKU.
      Bir SP'yi "adı GETİR/VERENLER, demek ki okur" diye çalıştırmak varsayımdır.
      İkisi de `sys.sql_modules`ten okundu: yalnız `#temp` tabloya yazıp DROP
      ediyorlar, gerçek tabloya dokunmuyorlar → salt-okuma DOĞRULANDI, sonra koştu.
      ⚠ `SayimYapilipEksiStokVerenler` AĞIR: 120 sn zaman aşımına düştü,
        `--timeout 900` ile koştu (irsHrk 59M satır + pencere fonksiyonu).
      ⚠ `--max-rows` EXEC'e UYGULANMAZ (server-side TOP sarmalanamıyor) — dönen
        satır sayısı kesilmemiştir, ama bunu varsayma, say.
   ============================================================================ */
EXEC dbo.SayimYapilipEksiStokVerenler;               -- 9.628 satır (2026-09-11)
EXEC bkm.[SayımEksiStokGetir] @MekanId = 1;          --   137 ürün
EXEC bkm.[SayımEksiStokGetir] @MekanId = 4477;       --   116 ürün
EXEC bkm.[SayımEksiStokGetir] @MekanId = 4478;       --   165 ürün
EXEC bkm.[SayımEksiStokGetir] @MekanId = 12;         -- 1.552 ürün  ← DEPO

/* 9) HÜKÜM: mağaza eksisi GEÇİCİ, depo eksisi KALICI.
      SP #1 İLK negatif günü işaretler, ertesi gün düzeleni de sayar — yani ŞÜPHE
      listesidir, kayıp listesi değil. Kalıcı olanı ölçmek için AYNI KAPSAMDA
      (ehTip=99 sayımı olan çiftler) GÜNCEL bakiye hesaplanır. */
WITH sayilan AS (
    SELECT DISTINCT ih.ehstkID AS StkID, ih.ehMekan AS mekanID
    FROM   dbo.irsHrk ih WITH(NOLOCK)
    WHERE  ih.ehTip = 99                     -- 99 = Sayım
      AND  ih.hrkTarih >= '20220531'
      AND  ih.ehMekan IN (1, 4477, 4478)
), bakiye AS (
    SELECT h.ehstkID, h.ehMekan, SUM(h.ehAdetN) AS Bakiye
    FROM   dbo.irsHrk h WITH(NOLOCK)
    JOIN   sayilan s ON s.StkID = h.ehstkID AND s.mekanID = h.ehMekan
    GROUP BY h.ehstkID, h.ehMekan
)
SELECT COUNT(*)                                              AS sayilan_cift,
       SUM(CASE WHEN Bakiye <  0 THEN 1      ELSE 0 END)     AS hala_negatif,
       SUM(CASE WHEN Bakiye <  0 THEN Bakiye ELSE 0 END)     AS negatif_adet,
       SUM(CASE WHEN Bakiye =  0 THEN 1      ELSE 0 END)     AS sifir,
       SUM(CASE WHEN Bakiye >  0 THEN 1      ELSE 0 END)     AS pozitif
FROM   bakiye;
/* Ölçüm 2026-09-11: 448.396 çift · pozitif 253.397 · sıfır 194.624 ·
   HÂLÂ NEGATİF 375 (−19.546 adet). Yani 9.628'in %96'sı kendini düzeltmiş. */

/* 10) DEPO — aynı SP süzgeciyle, WMS karşılığı ile birlikte */
WITH eksi AS (
    SELECT stk.ehstkID AS StokId, SUM(stk.ehAdetN) AS Defter
    FROM   dbo.irsHrk stk WITH(NOLOCK)
    JOIN   dbo.urn u WITH(NOLOCK) ON u.stkID = stk.ehstkID
    WHERE  u.stkAd NOT LIKE N'Sınav okulları'
      AND  stk.ehTrhS <= CONVERT(DATE, GETDATE()-1)
      AND  stk.ehAltDepo = 0
      AND  stk.ehMekan   = 12
      AND  u.urnKtgrID  <> 78
      AND  u.stkID NOT IN (SELECT su.StokId FROM bkm.SINAV_URUN su)
      AND  u.urnTip = 0 AND u.satisTur = 0
    GROUP BY stk.ehstkID
    HAVING SUM(stk.ehAdetN) < 0
), wms AS (
    SELECT v.stkID, SUM(v.Stok) AS WmsStok
    FROM   DerinSISBkm.depo.stok_adres_palet_vw v WITH(NOLOCK)
    GROUP BY v.stkID
)
SELECT COUNT(*)                                                AS urun,
       SUM(e.Defter)                                           AS defter_toplam_adet,
       SUM(CASE WHEN w.WmsStok > 0 THEN 1 ELSE 0 END)          AS wms_de_POZITIF_hayalet,
       SUM(CASE WHEN w.stkID IS NULL THEN 1 ELSE 0 END)        AS wms_de_HIC_YOK,
       SUM(CASE WHEN w.WmsStok > 0 THEN w.WmsStok ELSE 0 END)  AS hayalet_adet
FROM   eksi e
LEFT JOIN wms w ON w.stkID = e.StokId;
/* Ölçüm 2026-09-11: 1.555 ürün · −4.243.276 adet · WMS'te hiç yok 1.403 (%90) ·
   WMS'te pozitif 152 (7.517 adet). Depo negatifi mağazanın 217 KATI. */

/* 11) GEÇİCİ NEGATİF TUZAĞI — 03.08.2026 İst.Yolu kümesi (dört kitap −597..−600).
      "600'er adet eksik" MAKUL ama YANLIŞ okuma olurdu. */
SELECT CONVERT(varchar(10), h.ehTrhS, 120) AS tarih, h.ehstkID, h.ehTip, t.tipAd,
       h.ehAdetN, h.hrkID
FROM   dbo.irsHrk h WITH(NOLOCK)
LEFT JOIN dbo.irsTip_vw t ON t.tipID = h.ehTip
WHERE  h.ehMekan = 4478
  AND  h.ehstkID IN (645931, 140494, 140093, 142859)
  AND  h.ehTrhS >= '20260701'
ORDER BY h.ehstkID, h.ehTrhS;
/* Ölçüm: 03.08 `ehTip=95 Dönüşüm −600` · 04.08 `ehTip=10 Yerel Alım +600`.
   Borç bir gün ÖNCE, alacak bir gün SONRA → tek günlük çift-kayıt gecikmesi.
   ⚠ Ama geneli açıklamaz: ehTip=95 2025'ten beri yalnız 81 kayıt / 74 ürün. */
