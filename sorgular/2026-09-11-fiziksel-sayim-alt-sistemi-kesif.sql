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
