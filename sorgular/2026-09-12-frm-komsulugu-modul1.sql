/* ============================================================================
   MODÜL 1 — `dbo.frm` FK KOMŞULUĞU (48 tablo)            (2026-09-12)
   DB: DerinSISBkm (profil: erp)

   Modül dışarıdan tahmin EDİLMEDİ, FK grafiğinden TÜRETİLDİ (bkz.
   sorgular/2026-09-12-frm-mekan-taraf-master.sql blok 1). `dbo.frm` en büyük çapa:
   46 tablo ona referans veriyor.

   ⭐ MODÜLÜN EN ÖNEMLİ ÖLÇÜMÜ BİR TABLO DEĞİL, BİR ORAN:
     46 referanslık dev çapanın komşuluğunun 15'i TAMAMEN BOŞ, 18'i minik lookup.
     "Çok referans alan tablo = çok kullanılan alt sistem" ÇIKARIMI YANLIŞ ÇIKTI.
     FK sayısı ERP SATICISININ kurduğu yapıyı ölçer, BKM'nin KULLANDIĞI yapıyı değil.
   ============================================================================ */

/* 1) KOMŞULUĞUN TOPLU ÖLÇÜMÜ — satır · kolon · PK · şema değişim tarihi */
SELECT s.name+'.'+o.name AS tablo,
       MAX(CASE WHEN p.index_id IN (0,1) THEN p.rows END) AS satir,
       (SELECT COUNT(*) FROM DerinSISBkm.sys.columns c WHERE c.object_id=o.object_id) AS kolon,
       ISNULL(STUFF((SELECT ', '+cc.name FROM DerinSISBkm.sys.indexes ix
              JOIN DerinSISBkm.sys.index_columns ixc ON ixc.object_id=ix.object_id AND ixc.index_id=ix.index_id
              JOIN DerinSISBkm.sys.columns cc ON cc.object_id=ix.object_id AND cc.column_id=ixc.column_id
              WHERE ix.object_id=o.object_id AND ix.is_primary_key=1
              ORDER BY ixc.key_ordinal FOR XML PATH('')),1,2,''),'YOK') AS pk,
       CONVERT(varchar(10),o.modify_date,120) AS degisim
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id=o.schema_id
JOIN   DerinSISBkm.sys.partitions p ON p.object_id=o.object_id
WHERE  s.name+'.'+o.name IN ('dbo.carMtbkt','dbo.carOdemePlanAyr','dbo.carOdemePlanOdemeIptalSatir',
       'dbo.carSatOde','dbo.drn2arac','dbo.frmBnk','dbo.frmButce','dbo.frmDrm','dbo.frmGrp1',
       'dbo.frmGrp2','dbo.frmGrp3','dbo.frmGrp4','dbo.frmGrp5','dbo.frmKent','dbo.frmMgzKtlm',
       'dbo.frmMrk','dbo.frmOdmYon','dbo.frmOzt','dbo.frmSzlm','dbo.frmUlke','dbo.frmYetkili',
       'dbo.hspTurAlt','dbo.irsTsh','dbo.ith','dbo.posHsp','dbo.posMagazaKiraFirmalar',
       'dbo.posOdeme','dbo.posOdemeBanka','dbo.sakMrk','dbo.satBldrm','dbo.sipTakip',
       'depo.sozlesme','dmb.dmb','mhs.mhsEntFrm','mhs.mhsEntPos','mhs.mhsEntPosKsyr',
       'mhs.mhsEntPosOdm','prj.projeFrm')
GROUP BY s.name,o.name,o.object_id,o.modify_date ORDER BY satir DESC;
/* ÖLÇÜM — gerçekten DOLU olan yalnız 7 tablo:
     frmMrk 162.690 · mhsEntFrm 116.966 · sakMrk 14.230 · posHsp 5.783 ·
     frmYetkili 2.379 · frmSzlm 732 · mhsEntPosOdm 396
   SIFIR SATIRLI 15 TABLO (kolon sayılarıyla):
     irsTsh 15 · ith 19 (İTHALAT) · carSatOde 9 · carMtbkt 13 (cari MUTABAKAT) ·
     carOdemePlanAyr 37 · carOdemePlanOdemeIptalSatir 6 · frmOzt 24 · frmMgzKtlm 3 ·
     satBldrm 15 · sipTakip 8 (SİPARİŞ TAKİP) · drn2arac 8 · posMagazaKiraFirmalar 4 ·
     depo.sozlesme 15 · dmb.dmb 22 (DEMİRBAŞ) · prj.projeFrm 2
   ⇒ İthalat · cari mutabakat · demirbaş alt sistemleri ŞEMADA KURULU AMA BOŞ.
     Bunlara dayanan bir rapor HATA VERMEZ, sessizce boş döner — ve boş dönmek
     "hareket yok" diye okunur. */

/* 2) ★ mhs.mhsEntFrm — CARİ → MUHASEBE HESABI (fan-out tuzağı) */
SELECT COUNT_BIG(*) AS satir, COUNT(DISTINCT mefFrmID) AS firma,
       COUNT(DISTINCT mefSirketID) AS sirket, COUNT(DISTINCT mefHesap) AS hesap,
       SUM(CASE WHEN mefHesap IS NULL OR mefHesap='' THEN 1 ELSE 0 END) AS hesap_bos
FROM   DerinSISBkm.mhs.mhsEntFrm WITH(NOLOCK);
/* 116.966 satır · 27.772 cari · 6 şirket · 3.626 hesap · 2.331 BOŞ hesap */

SELECT TOP 8 LEFT(mefHesap,3) AS onek, COUNT_BIG(*) AS adet
FROM   DerinSISBkm.mhs.mhsEntFrm WITH(NOLOCK)
GROUP BY LEFT(mefHesap,3) ORDER BY adet DESC;
/* 120 → 99.777 (müşteri) · 320 → 11.721 (satıcı) · '' → 2.331 · 300 645 · 770 354 ·
   760 350 · 102 349 · 740 348 */

SELECT kac AS hesap_sayisi, COUNT_BIG(*) AS firma FROM (
    SELECT mefFrmID, COUNT(DISTINCT mefHesap) AS kac
    FROM DerinSISBkm.mhs.mhsEntFrm WITH(NOLOCK) GROUP BY mefFrmID) z
GROUP BY kac ORDER BY firma DESC;
/* 1 hesap → 27.348 firma · 2 hesap → 423 · 3 hesap → 1
   ⚠⚠ 424 firma birden çok hesaplı. `JOIN ... ON mefFrmID = frmID` TEK BAŞINA FAN-OUT
     yapar; anahtar `(mefSirketID, mefFrmID)`. */

/* 3) ★ dbo.posHsp — MAĞAZA-GÜN KASA DEVRİ (canlı sinyal çıktı) */
SELECT COUNT_BIG(*) AS satir, COUNT(DISTINCT hspMgzID) AS mekan,
       CONVERT(varchar(10),MIN(hspTarih),120) AS ilk,
       CONVERT(varchar(10),MAX(hspTarih),120) AS son,
       SUM(CASE WHEN hspTamam=1 THEN 1 ELSE 0 END) AS tamam
FROM   DerinSISBkm.dbo.posHsp WITH(NOLOCK);
/* 5.783 satır · 3 mekan · 2021-05-24 .. 2026-09-05 · tamam 5.782 */

SELECT hspMgzID AS mekan, CONVERT(varchar(10),hspTarih,120) AS gun,
       CONVERT(decimal(18,2),hspDevir) AS devir, hspTamam
FROM   DerinSISBkm.dbo.posHsp WITH(NOLOCK) WHERE hspTamam <> 1;
/* ⚠ TEK AÇIK GÜN: mekan 4478 (İst.Yolu) · 2026-09-05 · devir 280.263,44 ₺ · hspTamam=0
   Bir haftadır kapatılmamış kasa günü. Bunu gören bir uyarı YOK.
   (ÖLÇÜMDÜR — sebebi araştırılmadı.) */

/* 4) ★ dbo.frmMrk — hiç doldurulmayan kolon deseninin dördüncü örneği */
SELECT COUNT_BIG(*) AS satir, COUNT(DISTINCT frmMrkFirmaID) AS firma,
       COUNT(DISTINCT frmMrkMarkaID) AS marka,
       SUM(CASE WHEN frmMrkCPYuzde > 0 THEN 1 ELSE 0 END) AS cp_dolu,
       CONVERT(decimal(10,2),MAX(frmMrkCPYuzde)) AS cp_max
FROM   DerinSISBkm.dbo.frmMrk WITH(NOLOCK);
/* 162.690 · 2.725 firma · 10.150 marka · **cp_dolu 0** · cp_max 0,00
   ⇒ `frmMrkCPYuzde` (ciro primi %) HİÇ DOLDURULMAMIŞ. Tedarikçi ciro primi buradan
     hesaplanamaz. Aynı desen: urnBrkd.urnBrkdAltStkId · istAyr.sevkAdet ·
     api_log.stkid/tsoft_urun_id · MalKabulTanim.MiktarSiparis. */

/* 5) KÜÇÜK LOOKUP'LARIN TAM DÖKÜMÜ (elle yazma — buradan oku) */
SELECT 'frmDrm' AS t, CONVERT(varchar(40),frmDrmID) AS id, CONVERT(varchar(60),frmDrmAd) AS ad
FROM   DerinSISBkm.dbo.frmDrm WITH(NOLOCK)
UNION ALL SELECT 'frmOdmYon', CONVERT(varchar(40),frmOdmID), CONVERT(varchar(60),frmOdmAd) FROM DerinSISBkm.dbo.frmOdmYon WITH(NOLOCK)
UNION ALL SELECT 'frmGrp1', CONVERT(varchar(40),frmGrp1ID), CONVERT(varchar(60),frmGrp1Ad) FROM DerinSISBkm.dbo.frmGrp1 WITH(NOLOCK)
UNION ALL SELECT 'frmGrp5', CONVERT(varchar(40),frmGrp5ID), CONVERT(varchar(60),frmGrp5Ad) FROM DerinSISBkm.dbo.frmGrp5 WITH(NOLOCK)
UNION ALL SELECT 'frmUlke', CONVERT(varchar(40),ulkeID), CONVERT(varchar(60),ulkeAd) FROM DerinSISBkm.dbo.frmUlke WITH(NOLOCK);
/* frmDrm  0 Etkin · 1 Etkin Değil · 2 Geçici Kapalı · 3 Onaysız · **4 Kara Liste**
     ⚠ "0=aktif, 1=pasif" diye İKİ DEĞERLİ SANMAK EKSİK — bu sema'da aynı gün yapıldı
       ve düzeltildi. Canlıda 0→50.528 · 1→56 · 2→3; 3 ve 4 BOŞ (kara liste kurulmuş,
       işletilmiyor).
   frmOdmYon 0 Çek · 1 Nakit · 2 EFT
     ⚠ `0` "boş/varsayılan" DEĞİL, "Çek" demek — ve canlıda %99,8'i 0.
       Gerçekten çek mi, yoksa doldurulmayıp varsayılana mı düşüyor: ÖLÇÜLMEDİ.
   frmGrp1 0 Genel · 1 Aktif  (canlıda TAMAMI 0 → ayrım üretmiyor; Grp2/3/4 de aynı)
   frmUlke 90 Türkiye — TEK SATIR, canlıda hepsi 90 → yurtdışı tedarikçi bu kolondan
       AYRILAMAZ (kardeş `dbo.ith` de boş). */

/* 6) ★★ frmGrp5 "Grup Şirketi" — KURAL GİBİ DURAN BAYRAK, ÖLÇÜLDÜ VE REDDEDİLDİ */
SELECT frmID, frmAd, frmTip, frmDurum FROM DerinSISBkm.dbo.frm WITH(NOLOCK)
WHERE  frmGrup5 = 1 ORDER BY frmID;
/* YALNIZ 4 KAYIT: 56 BURSA KÜLTÜR MERKEZİ · 171 ASİYE BİNGÖLBALİ (şahıs!) ·
   9525 ODAK KİTAP-POİNT · 38093 BURSA KÜLTÜR MERKEZİ (ikinci kart) */

SELECT f.frmID, f.frmAd, f.frmGrup5 AS grup5_bayragi
FROM   DerinSISBkm.dbo.frm f WITH(NOLOCK)
WHERE  f.frmID IN (9525,22100,56,38093,4841,23842,58,9339,4694,7950,50582) ORDER BY f.frmID;
/* `bridges.yaml`ın ELLE tuttuğu 11 ilişkili taraftan bayraklı olan yalnız 3:
   56 ✓ · 9525 ✓ · 38093 ✓ — bayraksız 8: 58 · 4694 · 4841 · 7950 · 9339 · 22100 ·
   23842 · 50582.
   ⇒ Bayrağa geçen biri o 8'i SESSİZCE KAYBEDER (ilişkili-taraf fiyat kıyası bozulur).
   ⇒ "Liste yerine kural bul" arayışının ÖLÇÜLEREK REDDEDİLDİĞİ vaka: kural-şeklinde
     bir kolon VAR ama BAKIMI YAPILMIYOR. Elle liste bugün hâlâ daha doğru kaynak —
     ve bu artık BEYAN EDİLMİŞ bir tercih, unutulmuş bir eksiklik değil. */

/* 7) dbo.frmKent — `frm.il` PLAKA DEĞİL, TELEFON ALAN KODU */
SELECT 'il' AS kolon, CONVERT(varchar(20),il) AS deger, COUNT_BIG(*) AS firma
FROM   DerinSISBkm.dbo.frm WITH(NOLOCK) GROUP BY il HAVING COUNT_BIG(*) > 800;
/* 212 → 19.638 (İstanbul) · 312 → 4.455 (Ankara) · 224 → 6.756 (Bursa) ·
   232 → 2.879 (İzmir) · 242 → 1.440 · 262 → 1.240 · 322 → 1.030
   `dbo.frmKent` PK'sı zaten `alanKodu` (81 satır). `il=16` yazıp Bursa beklemek
   BOŞ döner. */

/* 8) KALAN DOLU TABLOLARIN TEKİLLİK ÖLÇÜMÜ */
SELECT 'posOdemeBanka' AS t, COUNT_BIG(*) AS satir, COUNT(DISTINCT odmBnkMagazaID) AS a,
       COUNT(DISTINCT odmBnkBankaID) AS b FROM DerinSISBkm.dbo.posOdemeBanka WITH(NOLOCK)
UNION ALL SELECT 'frmBnk', COUNT_BIG(*), COUNT(DISTINCT frmBnkFirmaID), COUNT(DISTINCT frmBnkSubeID) FROM DerinSISBkm.dbo.frmBnk WITH(NOLOCK)
UNION ALL SELECT 'sakMrk', COUNT_BIG(*), COUNT(DISTINCT skFrmID), 0 FROM DerinSISBkm.dbo.sakMrk WITH(NOLOCK)
UNION ALL SELECT 'frmYetkili', COUNT_BIG(*), COUNT(DISTINCT ytkFrm), 0 FROM DerinSISBkm.dbo.frmYetkili WITH(NOLOCK)
UNION ALL SELECT 'frmSzlm', COUNT_BIG(*), COUNT(DISTINCT frmSzlmFrmID), 0 FROM DerinSISBkm.dbo.frmSzlm WITH(NOLOCK);
/* posOdemeBanka 75 · 3 mağaza × 23 banka
     ⚠ HEM `odmBnkBankaID` HEM `odmBnkMagazaID` `frm.frmID`'ye bakar (banka frmTip=5,
       mağaza frmTip=2) — aynı tabloya İKİ AYRI ROLLE join.
   frmBnk 62 · 41 firma (carinin %0,08'i) · 51 şube — hesap no FİNANSAL VERİ, maskele
   sakMrk 14.230 · 261 firma — İÇERİK ÇÖZÜLMEDİ (beyan)
   frmYetkili 2.379 · 1.874 firma (%3,7) — KİŞİSEL VERİ, KVKK
   frmSzlm 732 · 418 firma · 50 kolon — satınalma adalet şartı için DOĞRUDAN İLGİLİ,
     İÇERİK ÇÖZÜLMEDİ (bir sonraki keşif adayı) */

/* ============================================================================
   MODÜL 1 ÖZETİ — dört ders
   1. FK SAYISI KULLANIMI ÖLÇMEZ. 46 referanslı çapanın komşuluğunun 15'i boş.
      Hub seçimi doğru başlangıç ama "büyük hub = büyük modül" ÇIKARIMDIR.
   2. TANIMLI AMA HİÇ DOLDURULMAYAN KOLON, şemanın en yaygın sessiz tuzağı —
      bu modülde `frmMrkCPYuzde` (162.690/162.690 sıfır) ile beşinci örneği.
   3. AYNI TABLOYA ÇOK ROLLÜ REFERANS: `frm` hem tedarikçi hem mağaza hem banka hem
      gider merkezi. `posOdemeBanka` tek satırda ikisini birden tutuyor. Rol daima
      `frmTip` ile daraltılır; daraltmadan yapılan sayım FARKLI TÜRLERİ TOPLAR.
   4. KURAL-ŞEKLİNDE AMA BAKIMSIZ KOLON (`frmGrup5`) elle listeden DAHA KÖTÜ olabilir.
      "Liste yerine kural" iyi bir refleks ama ÖLÇÜLMEDEN uygulanırsa kayıp üretir.
   ============================================================================ */
