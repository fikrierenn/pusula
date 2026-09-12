/* ============================================================================
   dbo.frm = ERP'NİN TEK TARAF (PARTY) MASTER'I · mekanID = frmID   (2026-09-12)
   DB: DerinSISBkm (profil: erp)

   YÖNTEM DEĞİŞİKLİĞİ: şema süpürmesi boyut sırasına göre gidiyordu (ilişkisiz
   tablolar yan yana düşüyordu). Kullanıcı uyardı. Modül dışarıdan TAHMİN EDİLMEDİ,
   FK grafiğinden TÜRETİLDİ: 418 FK · 348 düğüm · 44 bileşen; en çok referans alan
   çapa `dbo.frm` (46 tablo). Modül = hub + FK komşuluğu.

   ⚠ SÜREÇ HATASI (kayda geçsin): sorgulara başlamadan önce sema'ya BAKMADIM
     (kendi Fact-Force Gate kuralım). Ölçtüklerimin çoğu zaten yazılıydı
     (`codes:frm.frmTip` tam lookup ile · `codes:mekanID` liste ile ·
     `urn.KDVs` kod olduğu). Yine de değerli çıktı — çünkü YAZILI OLANIN
     BAYATLADIĞINI gösterdi (aşağıda blok 5).
   ============================================================================ */

/* 1) FK GRAFİĞİ — modülleri türetmek için ham kenar listesi */
SELECT sp.name+'.'+op.name AS cocuk, sr.name+'.'+orf.name AS ebeveyn,
       cp.name AS cocuk_kolon, cr.name AS ebeveyn_kolon
FROM   DerinSISBkm.sys.foreign_keys fk
JOIN   DerinSISBkm.sys.foreign_key_columns fkc ON fkc.constraint_object_id=fk.object_id
JOIN   DerinSISBkm.sys.objects op  ON op.object_id  = fk.parent_object_id
JOIN   DerinSISBkm.sys.schemas sp  ON sp.schema_id  = op.schema_id
JOIN   DerinSISBkm.sys.objects orf ON orf.object_id = fk.referenced_object_id
JOIN   DerinSISBkm.sys.schemas sr  ON sr.schema_id  = orf.schema_id
JOIN   DerinSISBkm.sys.columns cp  ON cp.object_id=fkc.parent_object_id     AND cp.column_id=fkc.parent_column_id
JOIN   DerinSISBkm.sys.columns cr  ON cr.object_id=fkc.referenced_object_id AND cr.column_id=fkc.referenced_column_id
ORDER BY cocuk;
/* Ölçüm: 423 kenar · 348 düğüm · 44 bağlı bileşen.
   En büyük bileşen 226 tablo / 14 ŞEMA → ⇒ ŞEMA MODÜL DEĞİLDİR (kullanıcının sorusu).
   Hub'lar (kaç tablo referans veriyor): frm 46 · urn 22 · drn1 19 · posMagaza 14 ·
   mhsSirket 10 · SayimKullanici 9 · personel 6 · fat 5 · irs 5.
   856 tablonun 508'i grafik DIŞINDA — ve o küme rastgele değil: ön-agrega / log /
   temp-yedek / `bkm.*` rapor tabloları (api_log 1,82 milyar · OneriSiparis 225M ·
   tmpSATISLAR 21,6M · StokAyBakiyeMekanBazli 29,2M). */

/* 2) frm KOMŞULUĞU — `frm` neyin master'ı? */
/* frmID'ye referans veren 46 tablo arasında ŞUNLAR VAR (kolon adlarına dikkat):
     car.cGdrMerkez · dmb.dmbGiderMerkez     → GİDER MERKEZİ
     drn1.insMekan · irsTsh.eMekan           → MEKAN
     posHsp.hspMgzID · mhs.mhsEntPos.mepMekanID → MAĞAZA
     posOdeme.odemeBanka · posOdemeBanka.odmBnkBankaID → BANKA
     fat.eFirma · irs.eFirma · sip.eFirma · urn.stkFirma → TEDARİKÇİ
   ⇒ `frm` tek bir "taraf" (party) tablosudur; rol `frmTip` ile ayrılır. */

/* 3) ★ frmTip — CANLI DAĞILIM (lookup dbo.frmTipTnm; sema'da zaten kayıtlı) */
SELECT frmTip AS tip, COUNT_BIG(*) AS firma, MIN(frmAd) AS ilk, MAX(frmAd) AS son
FROM   DerinSISBkm.dbo.frm WITH(NOLOCK) GROUP BY frmTip ORDER BY firma DESC;
/* 50.582 satır. 1 Müşteri 24.508 · 9 Sevk Adresi 21.933 · 0 Firma 2.661 ·
   6 Çalışan 771 · 5 Banka-Kasa 361 · 7 Gider 252 · 8 Hizmet 52 ·
   10 Gider Merkezi 32 · 3 DEPO 7 · **2 MAĞAZA 4** · 4 Ofis 1.
   Ayırt edici gözlem (VN doluluğu): tip 6 → 771/771 VN BOŞ + frmKod kullanıcı adı
   ("aydin.ozcan") ⇒ personel. tip 9 → VN dolu + frmKod "<VN>s<id>" biçiminde
   ⇒ e-belgeden OTOMATİK açılmış cari. */

/* 4) ★ mekanID = frmID — DOĞRULAMA */
SELECT frmID, frmAd, frmTip, frmDurum FROM DerinSISBkm.dbo.frm WITH(NOLOCK)
WHERE  frmID IN (1,12,4477,4478);
/* 1 FSM Mğz (tip 2) · 12 Merkez Depo (tip 3) · 4477 ÖZLÜCE Mğz (2) · 4478 İST YOLU Mğz (2)
   ⇒ Repo'nun her yerde kullandığı mekanID'ler `frm`in PK'sıdır. */

/* 5) ★★ İKİ KANONİK KAYNAK ÖZDEŞ Mİ + SEMA'NIN LİSTESİ BAYAT MI */
WITH pm AS (SELECT mekanID, mekanAd, mekanTip FROM DerinSISBkm.dbo.posMagaza WITH(NOLOCK)),
     fr AS (SELECT frmID, frmAd, frmTip, frmDurum FROM DerinSISBkm.dbo.frm WITH(NOLOCK)
            WHERE frmTip IN (2,3,4)),
     lg AS (SELECT ehMekan, COUNT_BIG(*) AS satir FROM DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
            WHERE ehTrhS >= '20240101' GROUP BY ehMekan)
SELECT COALESCE(pm.mekanID, fr.frmID, lg.ehMekan) AS mekan,
       COALESCE(pm.mekanAd, fr.frmAd)             AS ad,
       CASE WHEN pm.mekanID IS NULL THEN 'YOK' ELSE CONVERT(varchar(3),pm.mekanTip) END AS posMagaza,
       CASE WHEN fr.frmID  IS NULL THEN 'YOK' ELSE CONVERT(varchar(3),fr.frmTip)   END AS frmTip,
       fr.frmDurum AS durum, ISNULL(lg.satir,0) AS defter_satir
FROM   pm FULL OUTER JOIN fr ON fr.frmID   = pm.mekanID
          FULL OUTER JOIN lg ON lg.ehMekan = COALESCE(pm.mekanID, fr.frmID)
ORDER BY defter_satir DESC, mekan;
/* ⭐ BİREBİR ÖZDEŞ: 12 satır, iki tarafta da tek başına kalan YOK.
   `mekanTip` ↔ `frmTip` aynı bölünme, kaymış numara: 0↔2 Mağaza · 1↔3 Depo · 2↔4 Ofis.

   mekan   ad                      posMagaza frmTip durum   defter_satir (son 24 ay)
   12      Merkez Depo                 1       3      0        7.089.599
   4477    ÖZLÜCE Mğz                  0       2      0        3.718.447
   1       FSM Mğz                     0       2      0        2.783.570
   4478    İST YOLU Mğz                0       2      0        2.722.707
   4480    İade Deposu (ODAK)          1       3      1          124.327   ← 50,0M ₺
   26142   İPTAL-Transfer Deposu       1       3      1            5.421
   60398   HEYKEL TRANSFER             1       3      1            2.187
   31359   HASARLI DEPO                1       3      0              437
   14      Merkez Ofis                 2       4      0              249
   4479    Eticaret                    0       2      0                0   ← tanımlı, kullanılmamış
   4835    Depo(Özlüce)                1       3      1                0
   55375   sorunlu iade                1       3      1                0

   ⚠⚠ SEMA'NIN KENDİ LİSTESİ BAYATMIŞ: `codes:mekanID` 8 değer yazıyordu, canlıda 12.
     Eksik olanlar: 4479 Eticaret · 31359 HASARLI DEPO · 14 Merkez Ofis · 55375 sorunlu iade.
     Bu, "liste elle yazılmaz, kural yazılır" kuralının SEMA'NIN KENDİSİNDEKİ ihlaliydi.
     Kayıt artık kümeyi `lookup`tan okuyor; liste `ornek_degerler` olarak duruyor. */

/* 6) ★ ÜÇ-MAĞAZA SÜZGECİNİN BEDELİ */
SELECT COUNT_BIG(*) AS satir, CONVERT(decimal(18,0),SUM(ehTutarN)) AS tutar
FROM   DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
WHERE  ehTrhS >= DATEADD(MONTH,-24,GETDATE()) AND ehMekan NOT IN (1,4477,4478,12);
/* 125.247 satır / 53.602.886 ₺ — `ehMekan IN (1,4477,4478,12)` bunu SESSİZCE düşürür.
   Üç mağaza + merkez depo bir KAPSAM SEÇİMİDİR, mekan kümesi değil. */

/* 7) DEĞİŞMEZ + KIRILABİLİRLİK KANITI (paylaşılan dosyaya dokunmadan koşuldu) */
SELECT 'dogru' AS formul,
       (SELECT COUNT_BIG(*) FROM (SELECT mekanID AS id FROM DerinSISBkm.dbo.posMagaza WITH(NOLOCK)
          EXCEPT SELECT frmID FROM DerinSISBkm.dbo.frm WITH(NOLOCK) WHERE frmTip IN (2,3,4)) a)
     + (SELECT COUNT_BIG(*) FROM (SELECT frmID AS id FROM DerinSISBkm.dbo.frm WITH(NOLOCK) WHERE frmTip IN (2,3,4)
          EXCEPT SELECT mekanID FROM DerinSISBkm.dbo.posMagaza WITH(NOLOCK)) b)
     + (SELECT COUNT_BIG(*) FROM (SELECT DISTINCT ehMekan AS id FROM DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
            WHERE ehTrhS >= DATEADD(MONTH,-24,GETDATE())
          EXCEPT SELECT mekanID FROM DerinSISBkm.dbo.posMagaza WITH(NOLOCK)) c) AS ihlal;
/*   doğru formül                                0
     HATA 1 — `frmTip IN (2,3)` (ofis unutulur)  1
     HATA 2 — sema'nın eski 8'li listesi küme    4
   Değişmez: `mekan-kumesi-posmagaza-frm-ozdes` (47.) */

/* ============================================================================
   8) YAN BULGU — `urnKDV` 11 KOD, EŞLEME BİREBİR DEĞİL
   (dün yazdığım kural satırı elle 4 kodluk liste taşıyordu ve EKSİKTİ)
   ============================================================================ */
SELECT kdvID, kdvYuzde FROM DerinSISBkm.dbo.urnKDV WITH(NOLOCK) ORDER BY kdvID;
/* 1→%0 · 2→%1 · 3→%8 · 4→%18 · 5→%18 · 6→%10 · 7→%20 · 8→%20 · 9→%1 · 10→%10 · 11→%20
   ⇒ ÇOKTAN BİRE: {4,5}→18 · {7,8,11}→20 · {2,9}→1 · {6,10}→10.
   Elle `CASE` yazmak bugünün POS'unda (yalnız 1/2/6/7) tesadüfen çalışır. */

SELECT eArsvPosKdv AS kod, COUNT_BIG(*) AS adet,
       CONVERT(decimal(10,4), AVG(eArsvPosKdvTutar/NULLIF(eArsvPosTutar-eArsvPosKdvTutar,0))) AS gercek_oran
FROM   DerinSISBkm.earsv.eArsvPosSatisDetaylari WITH(NOLOCK)
WHERE  eArsvPosTutar > 0 GROUP BY eArsvPosKdv ORDER BY adet DESC;
/* 1→732.683 (%0) · 7→221.109 (0,1896) · **4→158.895 (0,1630)** · 6→144.408 (0,0954)
   · **3→115.589 (0,0788)** · 2→3.785 (0,0099)
   ⇒ GEÇMİŞ VERİDE kod 3 (%8) ve 4 (%18) GERÇEKTEN VAR — 274.484 satır.
     Dört kodluk elle CASE bunları sessizce yanlış hesaplar.
   ⇒ KURAL: her zaman `JOIN dbo.urnKDV k ON k.kdvID = <kod>`; oranı elle yazma.
     (`dbo.kdvYuzde_vw` de kullanılmaz — her orana ait yalnız ilk kodu döndürür.) */
