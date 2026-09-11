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

/* ============================================================================
   12-16) 2026 ARTIŞININ SEBEBİ — üç makul açıklama SIRAYLA elendi, sonra bulundu.
   ============================================================================ */

/* 12) PAYDA — "daha çok saydık" mı? HAYIR, sayım DÜŞTÜ. */
SELECT FORMAT(h.ehTrhS,'yyyy-MM') AS ay, COUNT_BIG(*) AS sayim_hareketi,
       COUNT(DISTINCT h.ehstkID) AS sayilan_urun
FROM   dbo.irsHrk h WITH(NOLOCK)
WHERE  h.ehTip = 99 AND h.ehMekan IN (1,4477,4478) AND h.ehTrhS >= '20250101'
GROUP BY FORMAT(h.ehTrhS,'yyyy-MM') ORDER BY ay;
/* 2025-08 2.105 · 2025-09 1.655  vs  2026-08 1.924 · 2026-09 489 → payda ARTMADI. */

/* 13) SEZON — şekli açıklıyor, seviyeyi açıklamıyor (satış hacmiyle normalize et) */
SELECT FORMAT(h.ehTrhS,'yyyy-MM') AS ay, CONVERT(bigint,SUM(ABS(h.ehAdetN))) AS satis_adet
FROM   dbo.irsHrk h WITH(NOLOCK)
WHERE  h.ehTip IN (100,4) AND h.ehMekan IN (1,4477,4478) AND h.ehTrhS >= '20250101'
GROUP BY FORMAT(h.ehTrhS,'yyyy-MM') ORDER BY ay;
/* 100K satışta negatif: 2025-08 6,5 · 2026-08 32,0 · 2025-09 9,1 · 2026-09 62,5. */

/* 14) ehTip=4 (Sınav toplu satış) mı? HAYIR — 2025'te DAHA yüksekti, hazard düşüktü. */
SELECT FORMAT(h.ehTrhS,'yyyy-MM') AS ay, h.ehMekan, COUNT_BIG(*) AS hrk,
       CONVERT(bigint,SUM(ABS(h.ehAdetN))) AS adet
FROM   dbo.irsHrk h WITH(NOLOCK)
WHERE  h.ehTip = 4 AND h.ehMekan IN (1,4477,4478) AND h.ehTrhS >= '20250601'
GROUP BY FORMAT(h.ehTrhS,'yyyy-MM'), h.ehMekan ORDER BY ay, h.ehMekan;
/* İst.Yolu 2025-08 11.751 hrk · 2025-09 22.667  >  2026-08 8.603 · 2026-09 16.242. */

/* 15) ★ SEBEP — `ehTip=99` NET DÜZELTME YÖNÜ. Ağustos 2026 bandın 16 KATI. */
SELECT FORMAT(h.ehTrhS,'yyyy-MM') AS ay, COUNT_BIG(*) AS hrk,
       CONVERT(bigint,SUM(h.ehAdetN)) AS net_duzeltme,
       CONVERT(bigint,SUM(CASE WHEN h.ehAdetN < 0 THEN h.ehAdetN ELSE 0 END)) AS eksilten
FROM   dbo.irsHrk h WITH(NOLOCK)
WHERE  h.ehTip = 99 AND h.ehMekan IN (1,4477,4478) AND h.ehTrhS >= '20250601'
GROUP BY FORMAT(h.ehTrhS,'yyyy-MM') ORDER BY ay;
/* Her ay ±40K bandında; 2026-08 = -641.898. 2025-08 ise +9.976 (dengi YOK). */

/* 15b) Tek gün, tek mağaza */
SELECT CONVERT(varchar(10),h.ehTrhS,120) AS gun, h.ehMekan, COUNT_BIG(*) AS hrk,
       CONVERT(bigint,SUM(h.ehAdetN)) AS net, COUNT(DISTINCT h.ehstkID) AS urun
FROM   dbo.irsHrk h WITH(NOLOCK)
WHERE  h.ehTip = 99 AND h.ehMekan IN (1,4477,4478)
  AND  h.ehTrhS >= '20260801' AND h.ehTrhS < '20260901'
GROUP BY CONVERT(varchar(10),h.ehTrhS,120), h.ehMekan
ORDER BY net;
/* 01.08.2026 · mekan 4478 (İst.Yolu) · 396 hareket · -652.451 adet · 396 ürün. */

/* 15c) Ne düşüldü — %94'ü Sınav */
SELECT ISNULL(ub.KatAna, N'(yok)') AS kat_ana, COUNT(*) AS urun,
       CONVERT(bigint,SUM(h.ehAdetN)) AS net_adet
FROM   dbo.irsHrk h WITH(NOLOCK)
LEFT JOIN bkm.UrunBilgi ub WITH(NOLOCK) ON ub.StkID = h.ehstkID
WHERE  h.ehTip = 99 AND h.ehMekan = 4478
  AND  h.ehTrhS >= '20260801' AND h.ehTrhS < '20260802'
GROUP BY ub.KatAna ORDER BY net_adet;
/* Sınav Okul Malzemeleri -330.879 · Sınavlara Hazırlık Kitapları -281.163 ·
   Eğitim-Sınavlara Hazırlık -22.007  → -634.049 / -652.451 = %94. */

/* 16) SEBEBİN KAPSAMI — her şeyi açıklamıyor, açıklamadığı yer YAZILIR. */
WITH duzeltme AS (
    SELECT DISTINCT h.ehstkID AS stkID
    FROM   dbo.irsHrk h WITH(NOLOCK)
    WHERE  h.ehTip = 99 AND h.ehMekan = 4478
      AND  h.ehTrhS >= '20260801' AND h.ehTrhS < '20260802'
), bak AS (
    SELECT h.ehstkID AS stkID, SUM(h.ehAdetN) AS Bakiye
    FROM   dbo.irsHrk h WITH(NOLOCK) WHERE h.ehMekan = 4478 GROUP BY h.ehstkID
)
SELECT (SELECT COUNT(*) FROM duzeltme)                          AS duzeltilen_urun,
       SUM(CASE WHEN b.Bakiye < 0 THEN 1 ELSE 0 END)            AS bunlardan_negatif,
       CONVERT(bigint,SUM(CASE WHEN b.Bakiye<0 THEN b.Bakiye ELSE 0 END)) AS negatif_adet
FROM   duzeltme d JOIN bak b ON b.stkID = d.stkID;
/* 396 üründen 32'si bugün negatif (-7.857). İst.Yolu'nun TÜM negatifi 237 ürün
   / -18.620 adet → olay ADEDİN %42,2'sini, ÜRÜN SAYISININ %13,5'ini açıklıyor.
   ⚠ AÇIK SORU: FSM (13) ve Özlüce (14) de Ağustos'ta kendi seviyelerinin üstüne
   çıktı; 01.08 olayı İst.Yolu'na özgü olduğu için ONLARI AÇIKLAMAZ. Ölçülmedi. */

/* ============================================================================
   17-19) FSM ve ÖZLÜCE'DEKİ ARTIŞ — gerçek mi, sebebi ne?
   ============================================================================ */

/* 17) Mağaza bazlı payda + düzeltme yönü. FSM/Özlüce'de TOPLU DÜŞÜM YOK. */
SELECT FORMAT(h.ehTrhS,'yyyy-MM') AS ay, h.ehMekan,
       COUNT(DISTINCT h.ehstkID) AS sayilan_urun,
       CONVERT(bigint,SUM(h.ehAdetN)) AS net_duzeltme
FROM   dbo.irsHrk h WITH(NOLOCK)
WHERE  h.ehTip = 99 AND h.ehMekan IN (1,4477,4478) AND h.ehTrhS >= '20250101'
GROUP BY FORMAT(h.ehTrhS,'yyyy-MM'), h.ehMekan
ORDER BY ay, h.ehMekan;
/* 2026-08 net: FSM +3.103 · Özlüce +7.310 · İst.Yolu -652.311.
   Wilson %95 GA ile Ağu+Eyl hazard: FSM %0,34[0,15-0,80]->%3,42[2,29-5,08] ·
   Özlüce %0,12[0,03-0,45]->%4,27[2,91-6,22] · İst.Yolu %0,00->%7,23[5,92-8,80].
   Üç aralık da AYRIK → artış üç mağazada da GERÇEK. */

/* 18) Kategori karışımı FSM/Özlüce'yi açıklamıyor (Sınav payı ~sabit) */
SELECT LEFT(FORMAT(h.ehTrhS,'yyyy'),4) AS yil, h.ehMekan,
       CASE WHEN ISNULL(ub.KatAna,N'') LIKE N'Sınav%'
              OR ISNULL(ub.KatAna,N'') LIKE N'Eğitim%' THEN N'SINAV/EGITIM'
            ELSE N'diger' END AS grup,
       COUNT(DISTINCT h.ehstkID) AS urun
FROM   dbo.irsHrk h WITH(NOLOCK)
LEFT JOIN bkm.UrunBilgi ub WITH(NOLOCK) ON ub.StkID = h.ehstkID
WHERE  h.ehTip = 99 AND h.ehMekan IN (1,4477,4478)
  AND ((h.ehTrhS >= '20250801' AND h.ehTrhS < '20251001')
    OR (h.ehTrhS >= '20260801' AND h.ehTrhS < '20261001'))
GROUP BY LEFT(FORMAT(h.ehTrhS,'yyyy'),4), h.ehMekan,
         CASE WHEN ISNULL(ub.KatAna,N'') LIKE N'Sınav%'
                OR ISNULL(ub.KatAna,N'') LIKE N'Eğitim%' THEN N'SINAV/EGITIM'
              ELSE N'diger' END;
/* Sınav payı: FSM %7,5->%6,7 · Özlüce %8,0->%9,8 · İst.Yolu %8,9->%37,6. */

/* 19) ★ SAYIM TİPİ HİPOTEZİ — ÖLÇÜM ÇÜRÜTTÜ.
       FSM/Özlüce'de `Reyon Ayrıştırma` büyümüştü; "hedefli sayıma geçildi, o yüzden
       daha çok negatif çıkıyor" diye düşündüm. Aynı ayın emirlerini tipe göre
       karşılaştırınca (yaş otomatik eşit) tam tersi çıktı: o tip EN TEMİZ. */
WITH emir AS (
    SELECT b.SayimTipId, b.MekanId, d.StokId
    FROM   DerinSISBkm.bkm.SayimEmirBaslik   b WITH(NOLOCK)
    JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
           ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
    WHERE  b.SayimTarihi >= '20260801' AND b.SayimTarihi < '20260910'
      AND  b.MekanId IN (1,4477,4478) AND ISNULL(d.Iptal,0) = 0
    GROUP BY b.SayimTipId, b.MekanId, d.StokId
), bak AS (
    SELECT h.ehstkID AS StokId, h.ehMekan AS MekanId, SUM(h.ehAdetN) AS Bakiye
    FROM   dbo.irsHrk h WITH(NOLOCK) WHERE h.ehMekan IN (1,4477,4478)
    GROUP BY h.ehstkID, h.ehMekan
)
SELECT e.SayimTipId, COUNT(*) AS sayilan_cift,
       SUM(CASE WHEN b.Bakiye < 0 THEN 1 ELSE 0 END) AS negatif
FROM   emir e
LEFT JOIN bak b ON b.StokId = e.StokId AND b.MekanId = e.MekanId
GROUP BY e.SayimTipId ORDER BY e.SayimTipId;
/* Ölçüm (Wilson %95): EksiStok %8,89[4,57-16,57] (tanımı gereği negatif seçer) ·
   Liste %6,71[5,24-8,56] (879 çift, hacimce en büyük) · Serbest %2,13 ·
   MgzKontrol %1,59 · ReyonAyristir %0,38[0,07-2,15] · Reyon %0,00.
   ⇒ Bileşim kayması YANLIŞ YÖNDE: büyüyen tip en temiz olan. Hipotez ELENDİ.
   ⇒ FSM/Özlüce artışının sebebi AÇIK SORU. 2025 tarafı yaş-eşitli kıyaslanamadığı
     için tip bazlı oranlar BİRLİKTELİKTİR, neden değildir. */

/* ============================================================================
   20-23) `SayimTipId = 1 Liste Sayımı` NE DEMEK
   ============================================================================ */

/* 20) Tip sözlüğü — LİSTE ELLE YAZILMAZ */
SELECT * FROM DerinSISBkm.bkm.SayimTip ORDER BY SayimTipId;
/* 1 Liste · 2 Reyon · 3 Serbest · 4 Eksi Stok · 5 Mağaza Kontrol · 6 Birleştirilmiş ·
   7 Emir Birleştirme · 8 Reyon Düzeltme · 9 Reyon Birleştirme ·
   10 Sayım Reyon Ayrıştırma · 11 Genel Raf · 14 Kontrol · 15 Çok Satan */

/* 21) YAPISAL PARMAK İZİ — tipi adından değil DAVRANIŞINDAN tanı */
SELECT b.SayimTipId,
       COUNT(DISTINCT b.SayimEmirBaslikId)                     AS emir,
       COUNT(*)                                                AS satir,
       SUM(CASE WHEN ISNULL(d.RafNo,N'')=N'' THEN 1 ELSE 0 END) AS rafsiz_satir,
       COUNT(DISTINCT NULLIF(d.RafNo,N''))                     AS raf_cesidi,
       SUM(CASE WHEN ISNULL(d.SayimDuzeltmeNedenId,0)>0 THEN 1 ELSE 0 END) AS neden_yazili
FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
       ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
WHERE  b.SayimTarihi >= '20260101' AND b.MekanId IN (1,4477,4478)
GROUP BY b.SayimTipId ORDER BY satir DESC;
/* Liste  : 41,4 satır/emir · %60,8 RAFSIZ · %34,4 nedenli  → hedefli DÜZELTME
   Reyon  : 27,2 satır/emir · %0,0  rafsız · %0,5  nedenli  → sistematik RAF SÜPÜRME
   Serbest: %100 rafsız, hiç raf yok                        → serbest/ad-hoc
   Yani Liste bir sayım YÖNTEMİ değil, bir DÜZELTME KANALI. */

/* 22) ★ DÜZELTME NEDENİ — sistemin KENDİ beyanı, benim çıkarımım değil */
SELECT * FROM DerinSISBkm.bkm.SayimDuzeltmeNedenleri;
SELECT d.SayimDuzeltmeNedenId, COUNT(*) AS satir,
       CONVERT(bigint, SUM(CONVERT(bigint,ISNULL(d.Miktar,0))
                         - CONVERT(bigint,ISNULL(d.MiktarEski,0)))) AS net
FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
       ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
WHERE  b.SayimTipId = 1 AND b.MekanId IN (1,4477,4478)
  AND  b.SayimTarihi >= '20260101' AND ISNULL(d.SayimDuzeltmeNedenId,0) > 0
GROUP BY d.SayimDuzeltmeNedenId ORDER BY satir DESC;
/* 2 Mal Giriş Hatası  2.050 satır / net -642.711  ← 01.08 olayının KENDİ ETİKETİ
   3 Sayım Hatası(Önceki Dönem) 394 / +1.460 · 4 LOGO Stok Aktarımı 234 / -12.310
   5 Kayıp-Çalıntı 75 / -544 · 1 Kasiyer Hatası 18 / +35
   ⇒ Olay hatalı MAL KABULÜNÜN geri alınmasıdır. KAYIP/ÇALINTI DEĞİLDİR
     (o kod toplamda 75 satır / -544 adet). */

/* 23) Tipin kendisi riskli mi? HAYIR — olay ayrılınca İST.YOLU'NA ÖZGÜ kalıyor */
WITH emir AS (
    SELECT b.MekanId, d.StokId,
           CASE WHEN b.MekanId = 4478 AND b.SayimTarihi >= '20260801'
                                      AND b.SayimTarihi <  '20260802' THEN 1 ELSE 0 END AS olay
    FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
    JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
           ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
    WHERE  b.SayimTipId = 1 AND b.MekanId IN (1,4477,4478)
      AND  b.SayimTarihi >= '20260801' AND b.SayimTarihi < '20260910'
      AND  ISNULL(d.Iptal,0) = 0
    GROUP BY b.MekanId, d.StokId,
             CASE WHEN b.MekanId = 4478 AND b.SayimTarihi >= '20260801'
                                        AND b.SayimTarihi <  '20260802' THEN 1 ELSE 0 END
), bak AS (
    SELECT h.ehstkID AS StokId, h.ehMekan AS MekanId, SUM(h.ehAdetN) AS Bakiye
    FROM   dbo.irsHrk h WITH(NOLOCK) WHERE h.ehMekan IN (1,4477,4478)
    GROUP BY h.ehstkID, h.ehMekan
)
SELECT e.olay, e.MekanId, COUNT(*) AS cift,
       SUM(CASE WHEN b.Bakiye < 0 THEN 1 ELSE 0 END) AS negatif
FROM   emir e LEFT JOIN bak b ON b.StokId = e.StokId AND b.MekanId = e.MekanId
GROUP BY e.olay, e.MekanId ORDER BY e.olay, e.MekanId;
/* Olay hariç: İst.Yolu 27/447 = %6,04 [4,18-8,65] · FSM 0/16 · Özlüce 0/31.
   FSM/Özlüce örneklemi çok küçük (GA %0-19 / %0-11) → KANIT YOK, ve zaten Liste'yi
   Ağu-Eyl'de neredeyse hiç kullanmamışlar. ⇒ Liste, FSM/Özlüce artışını AÇIKLAMAZ. */

/* ============================================================================
   24-27) DÜZELTME NEDENİ GÜVENİLİR Mİ — rastgele mi seçiliyor, kontrol ediliyor mu?
   Kullanıcı sorusu (2026-09-11): "nedenlerin doğruluğunu da test etmek lazım".
   ============================================================================ */

/* 24) TEST B — YÖN TUTARLILIĞI. Kayıp-Çalıntı stok ARTIRAMAZ. */
SELECT d.SayimDuzeltmeNedenId AS neden, COUNT(*) AS satir,
       SUM(CASE WHEN d.Miktar < d.MiktarEski THEN 1 ELSE 0 END) AS azaltan,
       SUM(CASE WHEN d.Miktar > d.MiktarEski THEN 1 ELSE 0 END) AS artiran,
       SUM(CASE WHEN d.Miktar = d.MiktarEski THEN 1 ELSE 0 END) AS degismeyen
FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
       ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
WHERE  b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
  AND  ISNULL(d.SayimDuzeltmeNedenId,0) > 0
GROUP BY d.SayimDuzeltmeNedenId ORDER BY satir DESC;
/* ÇELİŞKİ: Kayıp-Çalıntı 1.144 satırın 85'i stoğu ARTIRMIŞ. Ayrıca beş nedende
   toplam ~5.000 satırda Miktar = MiktarEski (hiçbir şeyi değiştirmeyen "düzeltme"). */

/* 25) TEST C — kullanıcı ayrımı. OLUMLU: kimse tek koda saplanmıyor. */
SELECT d.OlusturanKullaniciId AS kul, COUNT(*) AS satir,
       COUNT(DISTINCT d.SayimDuzeltmeNedenId) AS neden_cesidi
FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
       ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
WHERE  b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
  AND  ISNULL(d.SayimDuzeltmeNedenId,0) > 0
GROUP BY d.OlusturanKullaniciId HAVING COUNT(*) >= 200 ORDER BY satir DESC;
/* 60 kullanıcı: 28'i 5 neden · 17'si 4 · 13'ü 3 · 2'si 2 · TEK kod kullanan YOK. */

/* 26) ★ TEST D — NEDEN GERÇEKLE ÖRTÜŞÜYOR MU.
   ⚠ `SUM(CASE WHEN EXISTS(...))` SQL Server'da YASAK (aggregate içinde alt sorgu).
     Bayrak önce OUTER APPLY ile türetilir, SONRA toplanır. (Bu tuzağa bu oturumda
     4. kez düşüldü — sql-server-conventions § Aggregate + Kolon Gotcha.) */
WITH sat AS (
    SELECT b.MekanId, b.SayimTarihi, d.StokId, d.SayimDuzeltmeNedenId AS neden
    FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
    JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
           ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
    WHERE  b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
      AND  ISNULL(d.SayimDuzeltmeNedenId,0) > 0 AND ISNULL(d.Iptal,0) = 0
), bayrak AS (
    SELECT s.neden,
           CASE WHEN g.v IS NULL THEN 0 ELSE 1 END AS giris,
           CASE WHEN k.v IS NULL THEN 0 ELSE 1 END AS satis
    FROM   sat s
    OUTER APPLY (SELECT TOP 1 1 AS v FROM dbo.irsHrk h WITH(NOLOCK)
                 WHERE h.ehstkID = s.StokId AND h.ehMekan = s.MekanId
                   AND h.ehTip IN (10,12,13)              -- mal girişi
                   AND h.ehTrhS <  s.SayimTarihi
                   AND h.ehTrhS >= DATEADD(DAY,-30,s.SayimTarihi)) g
    OUTER APPLY (SELECT TOP 1 1 AS v FROM dbo.irsHrk h WITH(NOLOCK)
                 WHERE h.ehstkID = s.StokId AND h.ehMekan = s.MekanId
                   AND h.ehTip IN (100,4)                 -- satış
                   AND h.ehTrhS <  s.SayimTarihi
                   AND h.ehTrhS >= DATEADD(DAY,-30,s.SayimTarihi)) k
)
SELECT neden, COUNT(*) AS satir, SUM(giris) AS mal_girisi_var, SUM(satis) AS satis_var
FROM   bayrak GROUP BY neden ORDER BY neden;
/* Kasiyer Hatası  522 · giriş %14,9 · SATIŞ %62,3   ← gerçeği İZLİYOR
   Mal Giriş Hatası 70.584 · giriş %16,6            ← AYIRT ETMİYOR
   Sayım Hatası     29.387 · giriş %16,8            ← aynı oran
   Kayıp-Çalıntı     1.143 · giriş %19,2            ← DAHA YÜKSEK
   LOGO Aktarım      1.930 · giriş %4,2 · satış %9,1 ← ayrı duruyor (beklenir)
   ⇒ Baskın kod `Mal Giriş Hatası` gerçek bir mal girişini ÖNGÖRMÜYOR. */

/* 27) 01.08 OLAYININ ETİKETİ DOĞRULANIYOR MU — HAYIR */
WITH sat AS (
    SELECT DISTINCT d.StokId
    FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
    JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
           ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
    WHERE  b.MekanId = 4478 AND b.SayimTarihi >= '20260801'
      AND  b.SayimTarihi < '20260802' AND ISNULL(d.Iptal,0) = 0
)
SELECT COUNT(*) AS urun,
       SUM(CASE WHEN g30.v  IS NULL THEN 0 ELSE 1 END) AS giris_30g,
       SUM(CASE WHEN g180.v IS NULL THEN 0 ELSE 1 END) AS giris_180g
FROM   sat s
OUTER APPLY (SELECT TOP 1 1 AS v FROM dbo.irsHrk h WITH(NOLOCK)
             WHERE h.ehstkID=s.StokId AND h.ehMekan=4478 AND h.ehTip IN (10,12,13)
               AND h.ehTrhS < '20260801' AND h.ehTrhS >= '20260702') g30
OUTER APPLY (SELECT TOP 1 1 AS v FROM dbo.irsHrk h WITH(NOLOCK)
             WHERE h.ehstkID=s.StokId AND h.ehMekan=4478 AND h.ehTip IN (10,12,13)
               AND h.ehTrhS < '20260801' AND h.ehTrhS >= '20260201') g180;
/* 413 ürün · önceki 30 günde mal girişi olan 3 (%0,7) · 6 ayda 247 (%59,8).
   ⇒ 166 ürün (%40,2) o mağazada 6 AYDA HİÇ mal girişi görmemiş, ama stoğu
     "Mal Giriş Hatası" diye düşülmüş. ETİKET BİR İDDİADIR, KANIT DEĞİL. */

/* ============================================================================
   28-29) `Kayıp-Çalıntı` etiketli ama stoğu ARTIRAN 85 satır — tek tek incelendi.
   ============================================================================ */

/* 28) 85 satırın kendisi. Önce "taban etkisi mi" diye bak: MiktarEski 0/negatif ise
       artış yapay olabilir (çelişki değil). */
SELECT b.MekanId, CONVERT(varchar(10),b.SayimTarihi,120) AS tarih, b.SayimTipId,
       d.StokId, d.MiktarEski, d.Miktar, (d.Miktar - d.MiktarEski) AS fark,
       ISNULL(d.RafNo,N'') AS raf, d.OlusturanKullaniciId AS kul,
       CONVERT(int,ISNULL(d.Onay,0)) AS onay, CONVERT(int,ISNULL(d.Iptal,0)) AS iptal,
       ISNULL(d.GirisMiktar,-1) AS giris, ISNULL(d.CikisMiktar,-1) AS cikis
FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
       ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
WHERE  b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
  AND  d.SayimDuzeltmeNedenId = 5 AND d.Miktar > d.MiktarEski
ORDER BY (d.Miktar - d.MiktarEski) DESC;
/* 85 satır · toplam +447 adet · hepsi Onay=1, Iptal=0.
   MiktarEski: 70 pozitif · 12 sıfır · 3 NEGATİF (−41→0, −5→0 = imkânsız bakiye
   düzeltmesi, meşru). ⇒ "taban etkisi" açıklaması yalnız 15 satırı kapsıyor.
   YIĞILMA: 81 Özlüce · 68 adet 2025-05 · 68 tek kullanıcı (1605) ·
            67 `tip 9 Reyon Birleştirme` · raflar CO-12xx. */

/* 29) ★ AYNI İŞLEMİN TAMAMI — artan satırlar bir NET KAYIP işleminin içinde mi? */
SELECT CONVERT(varchar(10),b.SayimTarihi,120) AS tarih, b.SayimTipId,
       d.OlusturanKullaniciId AS kul, COUNT(*) AS satir,
       SUM(CASE WHEN d.Miktar > d.MiktarEski THEN 1 ELSE 0 END) AS artiran,
       SUM(CASE WHEN d.Miktar < d.MiktarEski THEN 1 ELSE 0 END) AS azaltan,
       CONVERT(bigint, SUM(CONVERT(bigint,d.Miktar) - CONVERT(bigint,d.MiktarEski))) AS net,
       COUNT(DISTINCT d.RafNo) AS raf
FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
       ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
WHERE  b.MekanId = 4477 AND b.SayimTarihi >= '20250501' AND b.SayimTarihi < '20250601'
  AND  d.SayimDuzeltmeNedenId = 5
GROUP BY CONVERT(varchar(10),b.SayimTarihi,120), b.SayimTipId, d.OlusturanKullaniciId
ORDER BY satir DESC;
/* 13.05.2025 · tip 9 · kul 1605 · 403 satır / 81 raf · 332 düşüş / 67 artış ·
   NET -498. ⇒ Artışlar, net KAYIP veren bir raf birleştirmesinin içindeki
   "yanlış rafta bulunmuş mal" satırları. Etiket İŞLEM düzeyinde seçilmiş, 403
   satırın hepsine miras kalmış — TEST A'daki tek-nedenli emir bulgusunun mekanizması.
   KALAN GERÇEK AYKIRI: 31.05.2025 · tip 3 Serbest · tek satır · stkID 63968 ·
   865 -> 1081 (+216), birleştirme bağlamı YOK.
   ⇒ PRATİK SONUÇ: `Kayıp-Çalıntı` satırları TOPLANARAK kayıp çıkarılamaz. */

/* ============================================================================
   30-32) TEK KALAN AYKIRI: stkID 63968, 31.05.2025 Özlüce +216 "Kayıp-Çalıntı"
   ============================================================================ */

/* 30) Ürün kim? */
SELECT u.stkID, u.stkAd, u.stkKod, u.urnTip, u.satisTur, u.urnKtgrID,
       ISNULL(ub.KatAna,N'(yok)') AS kat_ana, ISNULL(ub.Kategori3,N'(yok)') AS kat3,
       ISNULL(ub.SatisFiyat,0) AS satis_fiyat
FROM   dbo.urn u WITH(NOLOCK)
LEFT JOIN bkm.UrunBilgi ub WITH(NOLOCK) ON ub.StkID = u.stkID
WHERE  u.stkID = 63968;
/* "Hot Wheels Tekli Arabalar" · Oyuncak · 139 ₺ · stkKod 074299057854.
   TEK KODA ÇOK MODEL bağlayan JENERİK/TOPLU SKU — fiziksel sayımı tasarımı gereği zor. */

/* 31) Bu SKU için TÜM sayım emri satırları — neden kodları birbirinin yerine mi? */
SELECT CONVERT(varchar(10),b.SayimTarihi,120) AS tarih, b.SayimTipId, b.MekanId,
       d.MiktarEski, d.Miktar, (d.Miktar - d.MiktarEski) AS fark,
       ISNULL(d.SayimDuzeltmeNedenId,0) AS neden, d.OlusturanKullaniciId AS kul
FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
       ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
WHERE  d.StokId = 63968 AND b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
ORDER BY b.SayimTarihi;
/* 54 satır · 9+ kullanıcı · DÖRT KODUN HEPSİ birbirinin yerine kullanılmış:
   Kayıp-Çalıntı 18 · Mal Giriş Hatası 17 · Sayım Hatası 13 · nedensiz 6.
   Aynı büyüklükteki eksilmeler (-2/-3/-5/-22/-33) farklı günlerde farklı kodlarla.
   ⚠ Üç adet "0 -> büyük" satırı NEDENSİZ: 2025-08-05 Özlüce 0->556 ·
     2026-05-24 FSM 0->1134 · 2026-06-22 İst.Yolu 0->896 (rebaseline gibi). */

/* 32) ★ DEFTERDEN DOĞRULAMA — +216 hayalet ekleme mi, düzeltme mi? */
SELECT CONVERT(varchar(10),h.ehTrhS,120) AS tarih, h.ehTip, t.tipAd,
       CONVERT(int,h.ehAdetN) AS adet
FROM   dbo.irsHrk h WITH(NOLOCK)
LEFT JOIN dbo.irsTip_vw t ON t.tipID = h.ehTip
WHERE  h.ehstkID = 63968 AND h.ehMekan = 4477
  AND  h.ehTrhS >= '20250520' AND h.ehTrhS < '20250610'
ORDER BY h.ehTrhS, h.ehTip;
/* 29.05: `ehTip 13 Depo->Mağaza +288` VE AYNI GÜN `ehTip 99 Sayım -263`
   31.05: `ehTip 99 Sayım +216`      →  iki sayımın NETİ -47.
   ⇒ +216 bir hayalet ekleme DEĞİL; yoldaki 288 adetlik sevkiyat rafta görünmeden
     yapılmış bir sayımın geri alınmasıdır. Yanlış olan RAKAM değil ETİKET
     (doğrusu `Sayım Hatası` olurdu). */

/* ============================================================================
   33-36) JENERİK (TOPLU) SKU TESPİTİ — kaç tane var?
   ⚠ Eşikler (11 barkod · 40 sayım satırı) VERİDEN SEÇİLDİ. Bedeli beyan edilir:
     veriden türetilen kesim farkı ABARTIR (Altman & Royston 2006) — bu sayılar
     KOHORT SEÇİMİ içindir, etki ölçüsü değildir.
   ============================================================================ */

/* 33) ÖLÇÜT A — barkod toplayıcı. stkID başına kaç ayrı barkod?
   ⚠ `urnBrkdOnce=0` süzgeci KULLANILMAZ: o "birincil barkod" demek ve herkeste 1 verir
     (ilk denemede bu tuzağa düşüldü — sinyal tamamen kayboluyordu). */
WITH bk AS (
    SELECT urnBrkdStkID AS stkID, COUNT(DISTINCT urnBarkod) AS barkod
    FROM   dbo.urnBrkd WITH(NOLOCK) GROUP BY urnBrkdStkID
)
SELECT CASE WHEN barkod=1 THEN '1' WHEN barkod=2 THEN '2'
            WHEN barkod BETWEEN 3 AND 5 THEN '3-5'
            WHEN barkod BETWEEN 6 AND 10 THEN '6-10'
            WHEN barkod BETWEEN 11 AND 50 THEN '11-50' ELSE '50+' END AS bant,
       COUNT(*) AS urun, MAX(barkod) AS en_cok
FROM   bk
GROUP BY CASE WHEN barkod=1 THEN '1' WHEN barkod=2 THEN '2'
              WHEN barkod BETWEEN 3 AND 5 THEN '3-5'
              WHEN barkod BETWEEN 6 AND 10 THEN '6-10'
              WHEN barkod BETWEEN 11 AND 50 THEN '11-50' ELSE '50+' END
ORDER BY MIN(barkod);
/* 1->827.082 · 2->9.132 · 3-5->846 · 6-10->269 · 11-50->72 · 50+->109  => >=11: 181 urun.
   Uc: stkID 465253 "Sinav okullari" = 31.734 BARKOD tek stok kodu altinda. */

/* 34) ÖLÇÜT B — sürekli sayılan. Bant + "3+ farklı neden" sinyali */
WITH say AS (
    SELECT d.StokId, COUNT(*) AS satir,
           COUNT(DISTINCT NULLIF(d.SayimDuzeltmeNedenId,0)) AS neden_cesidi
    FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
    JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
           ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
    WHERE  b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
      AND  ISNULL(d.Iptal,0) = 0
    GROUP BY d.StokId
)
SELECT CASE WHEN satir=1 THEN '1' WHEN satir BETWEEN 2 AND 3 THEN '2-3'
            WHEN satir BETWEEN 4 AND 9 THEN '4-9'
            WHEN satir BETWEEN 10 AND 19 THEN '10-19'
            WHEN satir BETWEEN 20 AND 39 THEN '20-39' ELSE '40+' END AS bant,
       COUNT(*) AS urun,
       SUM(CASE WHEN neden_cesidi >= 3 THEN 1 ELSE 0 END) AS uc_farkli_neden
FROM   say
GROUP BY CASE WHEN satir=1 THEN '1' WHEN satir BETWEEN 2 AND 3 THEN '2-3'
              WHEN satir BETWEEN 4 AND 9 THEN '4-9'
              WHEN satir BETWEEN 10 AND 19 THEN '10-19'
              WHEN satir BETWEEN 20 AND 39 THEN '20-39' ELSE '40+' END
ORDER BY MIN(satir);
/* 40+ -> 349 urun. "3+ farkli neden" orani: <=19 %0,0-0,2 · 20-39 %3,4 · 40+ %11,7. */

/* 35) BİRLEŞİM + BAĞIMSIZ DOĞRULAMA (ad deseni ÖLÇÜTE GİRMEZ, yalnız sınama) */
WITH bk AS (SELECT urnBrkdStkID AS stkID, COUNT(DISTINCT urnBarkod) AS barkod
            FROM dbo.urnBrkd WITH(NOLOCK) GROUP BY urnBrkdStkID),
     say AS (SELECT d.StokId AS stkID, COUNT(*) AS satir
             FROM DerinSISBkm.bkm.SayimEmirBaslik b WITH(NOLOCK)
             JOIN DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
                  ON d.SayimEmirBaslikId=b.SayimEmirBaslikId
             WHERE b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
               AND ISNULL(d.Iptal,0)=0 GROUP BY d.StokId),
     ad AS (SELECT u.stkID,
                   CASE WHEN u.stkAd LIKE N'%Tekli%' OR u.stkAd LIKE N'%Çeşitli%'
                          OR u.stkAd LIKE N'%Karışık%' OR u.stkAd LIKE N'%Asorti%'
                          OR u.stkAd LIKE N'%Muhtelif%' OR u.stkAd LIKE N'%Modelleri%'
                          OR u.stkAd LIKE N'%Çeşitleri%' THEN 1 ELSE 0 END AS ad_deseni
            FROM dbo.urn u WITH(NOLOCK) WHERE u.urnTip = 0)
SELECT CASE WHEN ISNULL(bk.barkod,1) >= 11 THEN 1 ELSE 0 END AS barkod_toplayici,
       CASE WHEN ISNULL(say.satir,0) >= 40 THEN 1 ELSE 0 END AS surekli_sayilan,
       COUNT(*) AS urun, SUM(ad.ad_deseni) AS ad_deseni_uyan
FROM   ad
LEFT JOIN bk  ON bk.stkID  = ad.stkID
LEFT JOIN say ON say.stkID = ad.stkID
GROUP BY CASE WHEN ISNULL(bk.barkod,1) >= 11 THEN 1 ELSE 0 END,
         CASE WHEN ISNULL(say.satir,0) >= 40 THEN 1 ELSE 0 END;
/* KESISIM 1 · A-only 180 · B-only 348 · BIRLESIM 529 (837.760 icinde %0,06).
   Ad deseni: taban %0,48 · A %5,56 (Wilson [3,05-9,91]) · B %1,44 ([0,62-3,32]).
   Ikisi de tabanla AYRIK -> olcutler jenerik-adli urunu bagimsiz zenginlestiriyor. */

/* 36) ★ AĞIRLIK — küçük küme, devasa etki */
WITH bk AS (SELECT urnBrkdStkID AS stkID, COUNT(DISTINCT urnBarkod) AS barkod
            FROM dbo.urnBrkd WITH(NOLOCK) GROUP BY urnBrkdStkID),
     say AS (SELECT d.StokId AS stkID, COUNT(*) AS satir,
                    SUM(CASE WHEN ISNULL(d.SayimDuzeltmeNedenId,0)>0 THEN 1 ELSE 0 END) AS nedenli,
                    CONVERT(bigint,SUM(ABS(CONVERT(bigint,ISNULL(d.Miktar,0))
                                         - CONVERT(bigint,ISNULL(d.MiktarEski,0))))) AS mutlak_duzeltme
             FROM DerinSISBkm.bkm.SayimEmirBaslik b WITH(NOLOCK)
             JOIN DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
                  ON d.SayimEmirBaslikId=b.SayimEmirBaslikId
             WHERE b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
               AND ISNULL(d.Iptal,0)=0 GROUP BY d.StokId)
SELECT CASE WHEN ISNULL(bk.barkod,1) >= 11 OR say.satir >= 40
            THEN 'JENERIK ADAYI' ELSE 'diger' END AS sinif,
       COUNT(*) AS urun, SUM(say.satir) AS sayim_satiri,
       SUM(say.nedenli) AS nedenli_satir, SUM(say.mutlak_duzeltme) AS mutlak_duzeltme
FROM   say LEFT JOIN bk ON bk.stkID = say.stkID
GROUP BY CASE WHEN ISNULL(bk.barkod,1) >= 11 OR say.satir >= 40
              THEN 'JENERIK ADAYI' ELSE 'diger' END;
/* JENERIK ADAYI: 391 urun (%0,15) · sayim satiri 21.747 (%1,13) ·
   MUTLAK DUZELTME 81.308.298 (%94,50 — toplam 86.038.853).
   => Stok duzeltme BUYUKLUGUNU olcen her analiz once bu kumeyi ayirmali. */

/* ============================================================================
   37-40) KATEGORİ DÖKÜMÜ → ÖLÇÜT B ÇÜRÜDÜ + "%94,5" İDDİASI GERİ ÇEKİLDİ
   ============================================================================ */

/* 37) 529 adayın kategori dökümü — A ve B AYRI sütunda */
WITH bk AS (SELECT urnBrkdStkID AS stkID, COUNT(DISTINCT urnBarkod) AS barkod
            FROM dbo.urnBrkd WITH(NOLOCK) GROUP BY urnBrkdStkID),
     say AS (SELECT d.StokId AS stkID, COUNT(*) AS satir
             FROM DerinSISBkm.bkm.SayimEmirBaslik b WITH(NOLOCK)
             JOIN DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
                  ON d.SayimEmirBaslikId=b.SayimEmirBaslikId
             WHERE b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
               AND ISNULL(d.Iptal,0)=0 GROUP BY d.StokId)
SELECT ISNULL(ub.KatAna,N'(kategorisiz)') AS kat_ana, COUNT(*) AS urun,
       SUM(CASE WHEN ISNULL(bk.barkod,1) >= 11 THEN 1 ELSE 0 END) AS A_barkod,
       SUM(CASE WHEN ISNULL(say.satir,0) >= 40 THEN 1 ELSE 0 END) AS B_sayim
FROM   dbo.urn u WITH(NOLOCK)
LEFT JOIN bkm.UrunBilgi ub WITH(NOLOCK) ON ub.StkID = u.stkID
LEFT JOIN bk  ON bk.stkID  = u.stkID
LEFT JOIN say ON say.stkID = u.stkID
WHERE  u.urnTip = 0 AND (ISNULL(bk.barkod,1) >= 11 OR ISNULL(say.satir,0) >= 40)
GROUP BY ISNULL(ub.KatAna,N'(kategorisiz)') ORDER BY COUNT(*) DESC;
/* Supermarket 255 (A=1, B=255) · Sinav Okul Malzemeleri 102 (A=102, B=0) ·
   Hobi ve Oyuncak 59 (36/23) · Periyodik Yayin 42 (0/42) · Kirtasiye 33 (25/8) ·
   Hediyelik 21 (14/7) · Hediye Ceki 6 (0/6) · kalan 8 urun.
   => A ve B TAMAMEN FARKLI kategorilere dusuyor. Supermarket'te B supheli. */

/* 38) ★ ÖLÇÜT B ÇÜRÜDÜ — Süpermarket'te B, satış desiliyle tırmanıyor */
WITH say AS (SELECT d.StokId AS stkID, COUNT(*) AS satir
             FROM DerinSISBkm.bkm.SayimEmirBaslik b WITH(NOLOCK)
             JOIN DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
                  ON d.SayimEmirBaslikId=b.SayimEmirBaslikId
             WHERE b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
               AND ISNULL(d.Iptal,0)=0 GROUP BY d.StokId),
     sat AS (SELECT h.ehstkID AS stkID, CONVERT(bigint,SUM(ABS(h.ehAdetN))) AS satis
             FROM dbo.irsHrk h WITH(NOLOCK)
             WHERE h.ehTip IN (100,4) AND h.ehMekan IN (1,4477,4478)
               AND h.ehTrhS >= '20250101' GROUP BY h.ehstkID),
     sup AS (SELECT u.stkID, ISNULL(sat.satis,0) AS satis, ISNULL(say.satir,0) AS sayim,
                    NTILE(10) OVER (ORDER BY ISNULL(sat.satis,0)) AS desil
             FROM dbo.urn u WITH(NOLOCK)
             JOIN bkm.UrunBilgi ub WITH(NOLOCK) ON ub.StkID = u.stkID
             LEFT JOIN sat ON sat.stkID = u.stkID
             LEFT JOIN say ON say.stkID = u.stkID
             WHERE u.urnTip = 0 AND ub.KatAna = N'Süpermarket' AND ISNULL(sat.satis,0) > 0)
SELECT desil, COUNT(*) AS urun, MIN(satis) AS min_satis, MAX(satis) AS max_satis,
       SUM(CASE WHEN sayim >= 40 THEN 1 ELSE 0 END) AS B_uyeligi,
       AVG(CONVERT(decimal(9,2),sayim)) AS ort_sayim
FROM   sup GROUP BY desil ORDER BY desil;
/* B uyeligi: desil 1 %0,0 · 4 %6,4 · 7 %23,9 · 10 %75,2. Ort sayim 2,9 -> 61,0.
   => B JENERIKLIGI DEGIL DEVIR HIZINI olcuyor. Jenerik olcutu YALNIZ A (181 urun). */

/* 39) ★ "%94,5" İDDİASI GERİ ÇEKİLDİ — A ve B ayrılınca ağırlık B'de, ve B'nin
       hacmi TEK ÜRÜNDE toplanıyor. */
WITH bk AS (SELECT urnBrkdStkID AS stkID, COUNT(DISTINCT urnBarkod) AS barkod
            FROM dbo.urnBrkd WITH(NOLOCK) GROUP BY urnBrkdStkID),
     say AS (SELECT d.StokId AS stkID, COUNT(*) AS satir,
                    CONVERT(bigint,SUM(ABS(CONVERT(bigint,ISNULL(d.Miktar,0))
                                         - CONVERT(bigint,ISNULL(d.MiktarEski,0))))) AS mutlak
             FROM DerinSISBkm.bkm.SayimEmirBaslik b WITH(NOLOCK)
             JOIN DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
                  ON d.SayimEmirBaslikId=b.SayimEmirBaslikId
             WHERE b.MekanId IN (1,4477,4478) AND b.SayimTarihi >= '20250101'
               AND ISNULL(d.Iptal,0)=0 GROUP BY d.StokId)
SELECT CASE WHEN ISNULL(bk.barkod,1) >= 11 THEN 'A barkod>=11'
            WHEN say.satir >= 40 THEN 'B sayim>=40' ELSE 'diger' END AS sinif,
       COUNT(*) AS urun, SUM(say.satir) AS sayim_satiri, SUM(say.mutlak) AS mutlak_duzeltme
FROM   say LEFT JOIN bk ON bk.stkID = say.stkID
GROUP BY CASE WHEN ISNULL(bk.barkod,1) >= 11 THEN 'A barkod>=11'
              WHEN say.satir >= 40 THEN 'B sayim>=40' ELSE 'diger' END;
/* B: 348 urun / 81.285.061 (%94,47) · diger: 264.713 / 4.730.555 · A: 43 / 23.237 (%0,03). */

/* 40) ★★ HACMIN KAYNAGI TEK SATIR — ve DEFTERE HIC GECMEMIS */
SELECT CONVERT(varchar(10),b.SayimTarihi,120) AS tarih, b.MekanId, b.SayimTipId,
       d.MiktarEski, d.Miktar, ISNULL(d.SayimDuzeltmeNedenId,0) AS neden,
       d.OlusturanKullaniciId AS olusturan,
       CONVERT(int,ISNULL(d.Onay,0)) AS onay, CONVERT(int,ISNULL(d.Iptal,0)) AS iptal
FROM   DerinSISBkm.bkm.SayimEmirBaslik    b WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.SayimEmirDetaylari d WITH(NOLOCK)
       ON d.SayimEmirBaslikId = b.SayimEmirBaslikId
WHERE  d.StokId = 194315
  AND  ABS(CONVERT(bigint,ISNULL(d.Miktar,0)) - CONVERT(bigint,ISNULL(d.MiktarEski,0))) > 10000;

SELECT h.ehMekan, CONVERT(bigint,SUM(h.ehAdetN)) AS bakiye,
       CONVERT(bigint,SUM(CASE WHEN h.ehTip = 99 THEN h.ehAdetN ELSE 0 END)) AS sayim_neti
FROM   dbo.irsHrk h WITH(NOLOCK) WHERE h.ehstkID = 194315 GROUP BY h.ehMekan;
/* 31.05.2026 · Ozluce · tip 3 Serbest · 0 -> 80.894.925 · NEDEN YOK · kul 1922 ·
   Onay=1 · Iptal=0.  stkID 194315 = "Vivident Storming Cilek" (sakiz, Supermarket).
   80,9 MILYON paket sakiz fiziksel olarak imkansiz -> miktar alanina barkod/uzun
   sayi girilmis VERI GIRISI HATASI.
   ⭐ DEFTERE GECMEMIS: irsHrk'da Ozluce ehTip=99 neti +44, bakiye 52.
   => Stok zarar gormemis; hata YALNIZ bkm.SayimEmirDetaylari'nda. AMA ONAYLI ve
      IPTALSIZ, yani o tabloyu TOPLAYAN her analiz zehirleniyor.
   => KURAL: SayimEmirDetaylari miktarlari toplanirken aykiri-deger korumasi ZORUNLU
      ve sonuc irsHrk ehTip=99 netiyle karsilastirilmali. `Onay=1 AND Iptal=0` olmasi
      satirin GERCEKLESTIGI anlamina GELMIYOR. */
