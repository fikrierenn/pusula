/* =============================================================================
   HEDIYE CEKI URETIM/YASAM-DONGUSU YAPISI — HANGI VT, HANGI TABLO?
   Tarih: 27.08.2026 · Soru: "hediye ceklerini otomatik ureten/olusturan yapi
   hangi veritabaninda?" + "Inallar'a kirtasiyede de gecerli %15 yapmisiz — nerede?"

   ── CEVAP 1: URETIM YAPISI = DerinCrm.cmp (CRM kampanya sistemi) ───────────────
   Hediye ceki motoru DerinSIS'te veya EncoreMerkez'de DEGIL; ayri CRM veritabaninda:

     DerinCrm.cmp.GiftCardHeader        2 satir  → CEK TANIMI (sablon/parti)
     DerinCrm.cmp.GiftCard         16.115 satir  → tek tek uretilen cekler
     DerinCrm.cmp.GiftCardTransaction 9.934      → kullanim hareketleri
     DerinCrm.cmp.CouponToBeCreated       0      → otomatik uretim KUYRUGU (bos)
     DerinCrm.cmp.CampaignCoupon*         0      → kupon motoru (KULLANILMIYOR)
     DerinCrm.dbo._AktarılacakHediyeKartları 8.266 → Encore gecisinde goc kaynagi

   KANIT (blok 4): POS'ta harcanan cek kodlarinin TAMAMI cmp.GiftCard.Code'da var;
   EncoreMerkezCrm.dbo.GiftCard'da YOK. Yani POS yalnizca TUKETIR, kayit CRM'de.

   ⚠ EncoreMerkezCrm.dbo.GiftCard (22.022) = TAMAMI TypeId 3 = IADE CEKI
     (8,6 M TL kalan). Hediye cekiyle KARISTIRMA — ayri tablo, ayri enstruman.
     EncoreMerkezCrm.dbo.GiftCardTypes: 1 Kart · 2 Hediye Çeki · 3 İade Çeki

   ── URETIM NASIL OLUYOR? ──────────────────────────────────────────────────────
   DB'de GiftCard ureten SP / trigger / job YOK (blok 6 taramasi bos dondu)
   -> uretim UYGULAMA KATMANINDA (DerinCrm CRM servisi/web). DB sadece kayit tutar.
   ActivatedAt hicbir kayitta dolu DEGIL -> aktivasyon alani kullanilmiyor;
   yasam dongusu Status ile yurur: 100 = kullanilabilir · 200 = tukenmis (Amount 0).
   Ilgili job: IADE_CEK_DERINSIS_AKTAR (ENABLED) — IADE cekini DerinSIS'e aktarir.

   ── CEVAP 2: INALLAR %15 SISTEMDE KURAL OLARAK YOK ────────────────────────────
   Arandi ve BULUNAMADI (negatif kanit, blok 5+7):
     · DerinCrm.cmp.Campaign / CampaignLine / CampaignSegment / CampaignStore
       / CampaignScale / CampaignCustomer* → HEPSI 0 SATIR (motor kullanilmiyor)
     · DerinCrm.cmp.GiftCardHeader → yalniz 2 tanim:
         1 "GEÇİŞ TOPLU HEDİYE KARTLARI" (11.07.2025-31.12.2026)
         2 "BURFAS İNDİRİM ÇEKİ" (03.09-01.10.2025, ErpCode BURFAS)
       INALLAR tanimi YOK
     · EncoreMerkez.dbo.Campaign (26 kayit) → INALLAR yok, %15 yok
     · DerinSISBkm.dbo.frm.frmEkIndIlkAlim / frmEkIndYeniMgz / frmEkIndOzl
       → INALLAR/GONYE (24922, 56291, 56292) dahil hepsi 0
     · Kategori kisit tablolari (CampaignLineExclude vb.) → 0 satir
   SONUC: %15 fatura satirinda ELLE indirim olarak giriliyor
     (fatAyr.ehIndirim; 2026-08-25 olcumu 36.000 + 21.600 + 14.400 = 72.000 TL
      uzerinden brut 480.000 TL = tam %15).
   "Kirtasiyede de gecerli" ifadesinin sistemde KARSILIGI YOK: cek kullaniminda
   kategori kisiti hic tanimli degil -> cekler ZATEN her kategoride geciyor.
   Yani bu bir sistem ayari degil, OPERASYONEL/SOZLU mutabakat; POS zorlamiyor.

   ── CEVAP 3: CEK <-> MUSTERI BAGI SUNUCUDA HIC YOK (blok 8-11) ────────────────
   Soru: "Inallar'a verilen ceklerin numaralarini bul" -> BULUNAMAZ, cunku kayit YOK.
   TARANAN YERLER (hepsi negatif):
     · DerinCrm.cmp.GiftCard      : CustomerId=0 · UniqueAcquisitionId/ActivationInfo/
                                    History/ValidationCode/VendorDocNumber HEPSI BOS ·
                                    CreatedBy hep 1 (sistem/goc)
     · DerinSISBkm.dbo.fatAyr     : seri/kod alani YOK. ehNot serbest metin
                                    ("160 ADET 500 TL HEDIYE CEKI"). ehStrID = stok
                                    hareket ID, seri takip DEGIL
     · DerinSISBkm.dbo.irs.eNot   : Inallar'in 11 irsaliyesinde HEPSI BOS
     · Seri takip tablolari       : symSeri / mstr / mstrP / etkKareBarkod = 0 SATIR
     · Kolon adi taramasi         : DerinSISBkm + BKM + BKMDATA + DerinCrm'de
                                    hediye-ceki<->musteri kolonu YOK (yalniz carCek.cekNo
                                    = BANKA ceki, alakasiz)
     · DerinCrm.dbo._AktarılacakHediyeKartları : yalniz Code/Amount/ValidThru
     · DerinCrmOutbox             : TUM tablolar 0 satir (kullanilmiyor)
     · EncoreMerkezLog.job.*      : Hangfire; InvocationData'da Gift/Hediye/Coupon YOK
     · BKMLOG.dbo.Log (7,29 M)    : 26.08-03.09.2025 penceresinde ne cek kodu
                                    ne 'hediye' gecmiyor
   -> Cek TESLIM izi yalnizca FATURA SATIRINDA (adet + tutar + serbest not). Fiziksel
      kupurlerin hangi seri araliginin kime verildigi HICBIR YERDE tutulmuyor.

   ✅ AMA HARCAMA TARAFI ZENGIN IZLI (blok 12): cmp.GiftCardTransaction ->
      StoreCode (M01/M02/M03) + PosCode + CashierCode + CustomerId/CustomerCardNumber
      + **SalesId = Sales.PosDocumentId** (Info JSON parse'a TEMIZ alternatif kopru).
      ⚠ SUM(Amount) CIFT SAYAR: durum akisi 100->50->200 her adimda ayni Amount ile
        yeni satir yazar. 29.08.2025 partisinde SUM=198.500 TL cikiyor ama parti
        nominali 160.000 TL, gercek harcama 97.500 TL -> tuzak kendini ele veriyor.
        Olcumde COUNT(DISTINCT GiftCardId) veya SalesPayments.Amount kullan.
      ⚠ Status=50 YALNIZ bu tabloda (gecici ara durum); cmp.GiftCard 100/200 tutar
        -> kumulatif acik bakiye Status=100 ile DOGRU (5.194.172 TL teyit edildi).
      Kimlik izi ZAYIF: partide 397 hareketin 322'si (%81) KARTSIZ, 23 farkli
      sadakat karti -> 'cekleri kim kullandi' da tam cevaplanmiyor.

   TEK IZLENEBILIR PARMAK IZI: uretim gunu + kupur + ADET ESITLIGI.
   Inallar grubu cek alimlari — CARI (car) uzerinden TAM liste (blok 13):
     11.04.2023       200 TL x  51 adet =  10.200 TL / indirim YOK (%0)  ← fat eTip=1'de YOK!
     09-16.09.2024  1.000 TL x 165 adet = 165.000 TL brut / 24.750 ind (%15)
     29.08.2025       500 TL x 320 adet = 160.000 TL brut / 24.000 ind (%15)
     01.09.2025       500 TL x 640 adet = 320.000 TL brut / 48.000 ind (%15)
     TOPLAM 655.400 TL brut / 96.750 TL indirim = %14,76 ortalama
   ⚠⚠ METODOLOJI HATASI DUZELTMESI: `fat eTip=1` filtresi 2023 alimini KACIRIR
      (o kayit cFatTip=4 = POS/fis tarafi). Cek alim tarihcesi icin CARI (car) taramasi
      daha kapsayici: cNot LIKE '%HEDIYE CEKI%' + cKod bazli.
   ⚠ POLITIKA BASLANGICI 2024: 2023'te %0, 2024-2025'te %15. "En az 2 yildir %15"
      ifadesi dogru ama %15 oncesinde indirimsiz donem VAR.
   Parti eslesmesi:
     29.08.2025 · 500 TL · uretilen 320 == INALLAR 320 (160+64+96)  ✔ TEK ADAY, izlenebilir
     01.09.2025 · 500 TL · uretilen 1.545 vs INALLAR 640            ✘ ayirt edilemez
     26.08.2025 · 1.000 TL · uretilen 320 vs INALLAR 165 (2024)     ✘ eslesmiyor (goc)

   29.08.2025 PARTISI — KIRTASIYE KONTROLU SONUCU (320 cek / 160.000 TL nominal):
     196 cek tukenmis · kalan 55.000 TL · 195 odeme / 84 FIS · cekle odenen 97.500 TL
     Sepet brut 151.123 · indirim %15,1 · net 113.202 · KALDIRAC 1,32x
     ** KIRTASIYE %87,8 brut / %87,4 net — 84 fisin 82'sinde kirtasiye, 1.738 adet **
     ** KITAP yalniz %9,0 ** (barem-6'nin %9,2'siyle birebir capraz dogrulama)
     Agirlikli marj %42,6 · brut kar 48.204 TL
     KAR / 1 TL CEK = 0,494  ->  KIRILMA NOKTASI %49,4
     %15 indirim: 14.625 TL verildi -> NET KATKI 33.579 TL (marjin %70'i korunuyor)
   -> "Kirtasiyede de gecerli olsun" karari FIILEN calisiyor; kirtasiye ayni zamanda
      EN YUKSEK MARJLI kategori (%45,3). Kitap-agirlikli tavan riski (rapor v3 tezi)
      bu partide GERCEKLESMEDI — %15 fazlasiyla guvenli.
   ⚠ Bu bir CIKARIM, kesin atif DEGIL: parti eslesmesi (ayni gun + ayni kupur +
      tam adet 320=320) guclu ama sistemde cek<->musteri bagi olmadigi icin %100 degil.

   ── BILANCO NOTU (panelden farkli, daha genis) ────────────────────────────────
   Gercek acik cek bakiyesi (tum zaman, Status=100): 5.194.172 TL
     basili kupur 4.791.362 (8.562 adet) + sistem-uretimi 402.810 (2.842 adet)
   Dashboard paneli 471.880 TL gosteriyor cunku o YALNIZ 12 aylik pencerede
   satilan-eksi-kullanilan farki. Kumulatif yukumluluk CRM'den okunur.
   ⚠ BURFAS (HeaderId 2) tek kart 5.000.000 TL nominal / 4.889.165 TL kalan —
     havuz/kontor karti gorunumunde; gercek musteri borcu sayilmadan once teyit.
============================================================================= */

/* ---------------------------------------------------------------------------
   1) TUM VERITABANLARINDA CEK/KART TABLOSU TARAMASI
      MCP database= parametresi izin listesiyle sinirli AMA 3-PARCALI isim
      her VT'ye erisir -> master baglaminda cross-db sys taramasi yapilir.
--------------------------------------------------------------------------- */
SELECT TOP 80 name AS Veritabani, CONVERT(varchar(10), create_date, 104) AS Olusma
FROM sys.databases WHERE state_desc = 'ONLINE';

SELECT 'DerinCrm' AS Db, s.name AS Sema, t.name AS Tablo, p.rows AS Satir
FROM DerinCrm.sys.tables t
JOIN DerinCrm.sys.schemas s ON s.schema_id = t.schema_id
JOIN DerinCrm.sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE t.name LIKE '%Gift%' OR t.name LIKE '%Hediy%' OR t.name LIKE '%Kupon%'
   OR t.name LIKE '%Coupon%' OR t.name LIKE '%Voucher%' OR t.name LIKE '%Card%'
UNION ALL
SELECT 'EncoreMerkezCrm', s.name, t.name, p.rows
FROM EncoreMerkezCrm.sys.tables t
JOIN EncoreMerkezCrm.sys.schemas s ON s.schema_id = t.schema_id
JOIN EncoreMerkezCrm.sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE t.name LIKE '%Gift%' OR t.name LIKE '%Card%'
ORDER BY Db, Satir DESC;

/* 1b) cmp semasinin tamami — kampanya motoru hangi tablolari KULLANIYOR?
      (0 satirli tablolar = ozellik kapali; Campaign* hepsi 0) */
SELECT s.name AS Sema, t.name AS Tablo, p.rows AS Satir
FROM DerinCrm.sys.tables t
JOIN DerinCrm.sys.schemas s ON s.schema_id = t.schema_id
JOIN DerinCrm.sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE s.name = 'cmp'
ORDER BY p.rows DESC;

/* ---------------------------------------------------------------------------
   2) CEK TANIMLARI (uretim sablonu) — GiftCardHeader
      Type/Usage/SpendType kod anlamlari HENUZ COZULMEDI (teyit bekliyor).
      ErpCode 'BURFAS' -> ERP tarafi eslesme alani.
--------------------------------------------------------------------------- */
SELECT Id, Name, CONVERT(varchar(10), [Begin], 104) AS Baslangic,
       CONVERT(varchar(10), [End], 104) AS Bitis,
       Type, Usage, SpendType, IsEnabled, HasRemainder, IsDigitalCard,
       MinBasketAmount, ErpCode, ActivatedCardTtl, IsHeaderDominant,
       UseForInstantCards, UseAsCoupon, CampaignId, Details
FROM DerinCrm.cmp.GiftCardHeader;

/* ---------------------------------------------------------------------------
   3) URETILEN CEKLER — durum / kod tipi / bakiye
      Status 100 = kullanilabilir · 200 = tukenmis (Amount 0)
      Kod tipi: '2141…' 13 hane = BASILI KUPUR barkodu
                15 hane alfanumerik = SISTEM URETIMI (ör. KESCWJ1UZ0U6O7X)
--------------------------------------------------------------------------- */
SELECT g.HeaderId, g.Status,
       CASE WHEN g.Code LIKE '2141%' AND LEN(g.Code) = 13 THEN 'basili-kupur'
            WHEN LEN(g.Code) = 15 THEN 'sistem-uretimi'
            ELSE 'diger len=' + CONVERT(varchar, LEN(g.Code)) END AS KodTipi,
       CASE WHEN g.ActivatedAt IS NULL THEN 'aktivasyon YOK' ELSE 'aktive' END AS Aktivasyon,
       COUNT(*) AS Adet, SUM(g.OriginalAmount) AS Nominal, SUM(g.Amount) AS Kalan
FROM DerinCrm.cmp.GiftCard g WITH(NOLOCK)
GROUP BY g.HeaderId, g.Status,
       CASE WHEN g.Code LIKE '2141%' AND LEN(g.Code) = 13 THEN 'basili-kupur'
            WHEN LEN(g.Code) = 15 THEN 'sistem-uretimi'
            ELSE 'diger len=' + CONVERT(varchar, LEN(g.Code)) END,
       CASE WHEN g.ActivatedAt IS NULL THEN 'aktivasyon YOK' ELSE 'aktive' END
ORDER BY g.HeaderId, g.Status;

/* 3b) ACIK CEK BAKIYESI (kumulatif bilanco yukumlulugu) */
SELECT COUNT(*) AS AcikCek, SUM(g.Amount) AS AcikBakiye, SUM(g.OriginalAmount) AS Nominal
FROM DerinCrm.cmp.GiftCard g WITH(NOLOCK)
WHERE g.Status = 100 AND g.HeaderId = 1;

/* ---------------------------------------------------------------------------
   4) KANIT: POS'ta harcanan kod NEREDE kayitli?
      compat 110 -> JSON_VALUE YOK; Info'dan CHARINDEX/SUBSTRING ile cikarilir
      (bazi satirlarda kod bos -> length guard ZORUNLU, yoksa
       "Invalid length parameter passed to the LEFT or SUBSTRING function").
      SONUC: hepsi DerinCrm.cmp'de VAR, EncoreMerkezCrm'de YOK.
--------------------------------------------------------------------------- */
SELECT TOP 20
       pt.Amount,
       SUBSTRING(pt.Info, CHARINDEX('"GiftCardCode":"', pt.Info) + 16,
                 CHARINDEX('","GiftCardType"', pt.Info)
                 - CHARINDEX('"GiftCardCode":"', pt.Info) - 16) AS Kod,
       CASE WHEN EXISTS (SELECT 1 FROM DerinCrm.cmp.GiftCard g WITH(NOLOCK)
                         WHERE g.Code = SUBSTRING(pt.Info, CHARINDEX('"GiftCardCode":"', pt.Info) + 16,
                               CHARINDEX('","GiftCardType"', pt.Info)
                               - CHARINDEX('"GiftCardCode":"', pt.Info) - 16))
            THEN 'DerinCrm.cmp VAR' ELSE 'yok' END AS DerinCrm,
       CASE WHEN EXISTS (SELECT 1 FROM EncoreMerkezCrm.dbo.GiftCard e WITH(NOLOCK)
                         WHERE e.Code = SUBSTRING(pt.Info, CHARINDEX('"GiftCardCode":"', pt.Info) + 16,
                               CHARINDEX('","GiftCardType"', pt.Info)
                               - CHARINDEX('"GiftCardCode":"', pt.Info) - 16))
            THEN 'EncoreCrm VAR' ELSE 'yok' END AS EncoreCrm
FROM EncoreMerkez.dbo.SalesPayments pt WITH(NOLOCK)
WHERE pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
  AND CHARINDEX('"GiftCardCode":"', pt.Info) > 0
  AND CHARINDEX('","GiftCardType"', pt.Info) > CHARINDEX('"GiftCardCode":"', pt.Info) + 16;

/* 4b) EncoreMerkezCrm.GiftCard = TAMAMI IADE CEKI (TypeId 3) — ayri enstruman */
SELECT g.TypeId, COUNT(*) AS Adet, SUM(g.Amount) AS Kalan,
       SUM(CASE WHEN g.IsSpend = 1 THEN 1 ELSE 0 END) AS Harcanan
FROM EncoreMerkezCrm.dbo.GiftCard g WITH(NOLOCK)
GROUP BY g.TypeId;

SELECT Id, Name FROM EncoreMerkezCrm.dbo.GiftCardTypes;

/* ---------------------------------------------------------------------------
   5) INALLAR %15 ARAMASI — NEGATIF KANIT
      (a) POS kampanya motoru: 26 kayit, INALLAR/%15 yok
--------------------------------------------------------------------------- */
SELECT Id, Name, CONVERT(varchar(10), BeginDate, 104) AS Bas,
       CONVERT(varchar(10), EndDate, 104) AS Bitis,
       CampaignTypeId, MainDiscountType, ExecutionType, ExecutionValue,
       SpendType, GiftCardType, IsActive, IsForCustomersOnly,
       RequiresCouponsToRun, ValidForAllStores
FROM EncoreMerkez.dbo.Campaign;

/* (b) ERP musteri karti ek-indirim alanlari: INALLAR/GONYE dahil HEPSI 0 */
SELECT frmID, frmAd, frmEkIndIlkAlim, frmEkIndYeniMgz, frmEkIndOzl,
       frmFiyatTur, frmHesapTur, frmKomisyon, frmPiyasaMarj
FROM DerinSISBkm.dbo.frm WITH(NOLOCK)
WHERE frmID IN (24922, 56291, 56292, 46000, 392, 2485);

/* (c) %15 nerede? -> fatura satirinda ELLE (fatAyr.ehIndirim) */
SELECT f.eFirma, c.frmAd, COUNT(DISTINCT f.eID) AS Fatura,
       SUM(fa.ehTutar) AS Brut, SUM(fa.ehIndirim) AS Indirim,
       CAST(100.0 * SUM(fa.ehIndirim) / NULLIF(SUM(fa.ehTutar), 0) AS decimal(9,2)) AS Oran
FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON f.eID = fa.ehID
LEFT JOIN DerinSISBkm.dbo.frm c WITH(NOLOCK) ON c.frmID = f.eFirma
WHERE f.eDurum <> 2 AND f.eTip = 1 AND f.eFirma IN (24922, 56291, 56292)
  AND fa.ehStkID IN (SELECT u.stkID FROM DerinSISBkm.dbo.urn u WITH(NOLOCK)
                     JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID = u.urnKtgr2ID
                     WHERE k.ktgrAd = N'Hediye Çeki')
GROUP BY f.eFirma, c.frmAd;

/* ---------------------------------------------------------------------------
   6) URETIM MEKANIZMASI TARAMASI — SP/trigger/job
      DerinCrm'de GiftCard SP/trigger YOK -> uretim uygulama katmaninda.
--------------------------------------------------------------------------- */
SELECT s.name AS Sema, o.name AS Nesne, o.type_desc AS Tur
FROM DerinCrm.sys.objects o
JOIN DerinCrm.sys.schemas s ON s.schema_id = o.schema_id
WHERE o.type IN ('P','FN','TF','IF','TR','V')
  AND (o.name LIKE '%Gift%' OR o.name LIKE '%Hediy%' OR o.name LIKE '%Coupon%');

SELECT j.name AS Job, CASE WHEN j.enabled = 1 THEN 'ENABLED' ELSE 'disabled' END AS Durum
FROM msdb.dbo.sysjobs j
WHERE j.name LIKE '%Gift%' OR j.name LIKE '%Hediy%' OR j.name LIKE '%Cek%'
   OR j.name LIKE '%Kart%' OR j.name LIKE '%Aktar%';

/* ---------------------------------------------------------------------------
   7) KATEGORI KISITI VAR MI? — YOK (cek her kategoride geciyor)
      Kisit tasiyabilecek tablolar bos: CampaignLine / CampaignLineExclude /
      CampaignProduct(cmp) / CampaignSegment / CampaignStore
--------------------------------------------------------------------------- */
SELECT s.name AS Sema, t.name AS Tablo, p.rows AS Satir
FROM DerinCrm.sys.tables t
JOIN DerinCrm.sys.schemas s ON s.schema_id = t.schema_id
JOIN DerinCrm.sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE s.name = 'cmp' AND t.name LIKE '%Line%' OR (s.name = 'cmp' AND t.name LIKE '%Exclude%');


/* ---------------------------------------------------------------------------
   8) INALLAR GRUBU CEK ALIMLARI — fatura satiri detayi
      Cek NO yok; ehNot serbest metin. ehStrID = stok hareket ID (seri takip DEGIL).
      2024 satirlari 12 aylik pencerede gorunmez -> politika en az 2 yillik.
--------------------------------------------------------------------------- */
SELECT f.eID, CONVERT(varchar(10), f.eTarih, 104) AS Tarih, f.eNo, f.eFirma, c.frmAd,
       fa.ehStkID, u.stkAd, u.fiyatS AS Kupur, fa.ehAdetN AS Adet,
       fa.ehTutar AS Brut, fa.ehIndirim AS Indirim, fa.ehTutarN AS Net,
       CAST(100.0 * fa.ehIndirim / NULLIF(fa.ehTutar, 0) AS decimal(9,2)) AS IndOran,
       fa.ehStrID, ISNULL(fa.ehNot, '') AS SatirNotu, fa.ehIrsID
FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON f.eID = fa.ehID
JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = fa.ehStkID
LEFT JOIN DerinSISBkm.dbo.frm c WITH(NOLOCK) ON c.frmID = f.eFirma
WHERE f.eDurum <> 2 AND f.eTip = 1
  AND f.eFirma IN (24922, 56291, 56292)
  AND fa.ehStkID IN (SELECT u2.stkID FROM DerinSISBkm.dbo.urn u2 WITH(NOLOCK)
                     JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID = u2.urnKtgr2ID
                     WHERE k.ktgrAd = N'Hediye Çeki')
ORDER BY f.eTarih, f.eFirma;

/* 8b) Irsaliye notu da BOS (cek seri araligi orada da yok) */
SELECT i.eID, CONVERT(varchar(10), i.eTarih, 104) AS Tarih, i.eFirma, i.eNo,
       ISNULL(i.eNot, '') AS IrsNot
FROM DerinSISBkm.dbo.irs i WITH(NOLOCK)
WHERE i.eID IN (6538391, 6557031, 6558310, 7091238, 7091698, 6557198,
                7091240, 7091702, 6557209, 7091239, 7091701);

/* ---------------------------------------------------------------------------
   9) PARTI ESLESMESI + IZLEME ALANLARI BOS MU?
--------------------------------------------------------------------------- */
SELECT CONVERT(varchar(10), g.CreatedAt, 104) AS OlusmaGun, g.OriginalAmount AS Kupur,
       g.Status, COUNT(*) AS Adet, SUM(g.OriginalAmount) AS Nominal, SUM(g.Amount) AS Kalan,
       MIN(g.Code) AS IlkKod, MAX(g.Code) AS SonKod
FROM DerinCrm.cmp.GiftCard g WITH(NOLOCK)
WHERE g.OriginalAmount IN (500, 1000)
  AND CONVERT(date, g.CreatedAt) IN ('20250826', '20250829', '20250901')
GROUP BY CONVERT(varchar(10), g.CreatedAt, 104), g.OriginalAmount, g.Status
ORDER BY OlusmaGun, Kupur, g.Status;

SELECT CONVERT(varchar(10), g.CreatedAt, 104) AS Gun, g.OriginalAmount AS Kupur,
       CASE WHEN ISNULL(g.UniqueAcquisitionId,'') = '' THEN 'BOS' ELSE 'DOLU' END AS Parti,
       CASE WHEN ISNULL(g.ActivationInfo,'')      = '' THEN 'BOS' ELSE 'DOLU' END AS AktBilgi,
       CASE WHEN ISNULL(g.History,'')             = '' THEN 'BOS' ELSE 'DOLU' END AS Gecmis,
       CASE WHEN ISNULL(g.ValidationCode,'')      = '' THEN 'BOS' ELSE 'DOLU' END AS DogKod,
       g.CreatedBy, COUNT(*) AS Adet
FROM DerinCrm.cmp.GiftCard g WITH(NOLOCK)
WHERE g.OriginalAmount IN (500, 1000)
  AND CONVERT(date, g.CreatedAt) IN ('20250826', '20250829', '20250901')
GROUP BY CONVERT(varchar(10), g.CreatedAt, 104), g.OriginalAmount,
         CASE WHEN ISNULL(g.UniqueAcquisitionId,'') = '' THEN 'BOS' ELSE 'DOLU' END,
         CASE WHEN ISNULL(g.ActivationInfo,'')      = '' THEN 'BOS' ELSE 'DOLU' END,
         CASE WHEN ISNULL(g.History,'')             = '' THEN 'BOS' ELSE 'DOLU' END,
         CASE WHEN ISNULL(g.ValidationCode,'')      = '' THEN 'BOS' ELSE 'DOLU' END,
         g.CreatedBy;

/* ---------------------------------------------------------------------------
   10) PARTININ HARCANDIGI FISLER + KATEGORI KIRILIMI  ← ASIL SORU
       Info->kod cikarma: compat 110, length guard ZORUNLU.
       SONUC: KIRTASIYE %87,8 · kitap %9,0 · kaldirac 1,32x · marj %42,6
--------------------------------------------------------------------------- */
SELECT COUNT(*) AS PartiCek,
       SUM(CASE WHEN g.Status = 200 THEN 1 ELSE 0 END) AS Tukenmis,
       SUM(g.OriginalAmount) AS Nominal, SUM(g.Amount) AS Kalan,
       COUNT(hc.SalesId) AS EslesenOdeme, COUNT(DISTINCT hc.SalesId) AS Fis,
       SUM(hc.Amount) AS CekleOdenen
FROM DerinCrm.cmp.GiftCard g WITH(NOLOCK)
LEFT JOIN (
    SELECT pt.SalesId, pt.Amount,
           SUBSTRING(pt.Info, CHARINDEX('"GiftCardCode":"', pt.Info) + 16,
                     CHARINDEX('","GiftCardType"', pt.Info)
                     - CHARINDEX('"GiftCardCode":"', pt.Info) - 16) AS Kod
    FROM EncoreMerkez.dbo.SalesPayments pt WITH(NOLOCK)
    WHERE pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
      AND CHARINDEX('"GiftCardCode":"', pt.Info) > 0
      AND CHARINDEX('","GiftCardType"', pt.Info) > CHARINDEX('"GiftCardCode":"', pt.Info) + 16
) hc ON hc.Kod = g.Code
WHERE g.OriginalAmount = 500 AND CONVERT(date, g.CreatedAt) = '20250829';

SELECT ub.KatAna,
       COUNT(DISTINCT s.Id) AS Fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) AS Adet,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice+sp.DiscountTotalDirect)
                ELSE (sp.TotalPrice+sp.DiscountTotalDirect) END) AS Brut,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.DiscountTotalDirect
                ELSE sp.DiscountTotalDirect END) AS Indirim,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice-sp.VatTotal)
                ELSE (sp.TotalPrice-sp.VatTotal) END) AS Net
FROM (
    SELECT DISTINCT pt.SalesId
    FROM EncoreMerkez.dbo.SalesPayments pt WITH(NOLOCK)
    JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
         ON g.Code = SUBSTRING(pt.Info, CHARINDEX('"GiftCardCode":"', pt.Info) + 16,
                               CHARINDEX('","GiftCardType"', pt.Info)
                               - CHARINDEX('"GiftCardCode":"', pt.Info) - 16)
        AND g.OriginalAmount = 500 AND CONVERT(date, g.CreatedAt) = '20250829'
    WHERE pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
      AND CHARINDEX('"GiftCardCode":"', pt.Info) > 0
      AND CHARINDEX('","GiftCardType"', pt.Info) > CHARINDEX('"GiftCardCode":"', pt.Info) + 16
) f
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = f.SalesId
JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
JOIN DerinSISBkm.bkm.UrunBilgi ub WITH(NOLOCK) ON ub.stkID = CONVERT(int, p.Code)
WHERE s.DocumentsTypeId IN (1, 3) AND ISNUMERIC(p.Code) = 1
  AND sp.RefundReasonId <> 12 AND p.Code <> '583160'
  AND ub.KatAna <> N'Hediye Çeki'
GROUP BY ub.KatAna
ORDER BY Brut DESC;

/* ---------------------------------------------------------------------------
   11) BAG NEREDE DEGIL — negatif kanit sorgulari (tekrar uretilebilirlik)
--------------------------------------------------------------------------- */
-- Seri takip tablolari BOS
SELECT s.name AS Sema, t.name AS Tablo, p.rows AS Satir
FROM DerinSISBkm.sys.tables t
JOIN DerinSISBkm.sys.schemas s ON s.schema_id = t.schema_id
JOIN DerinSISBkm.sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE t.name LIKE '%Str%' OR t.name LIKE '%Seri%' OR t.name LIKE '%Barkod%';

-- Kolon adi taramasi: hediye-ceki<->musteri kolonu yok (carCek.cekNo = BANKA ceki)
SELECT 'DerinSISBkm' AS Db, s.name AS Sema, t.name AS Tablo, c.name AS Kolon, p.rows AS Satir
FROM DerinSISBkm.sys.columns c
JOIN DerinSISBkm.sys.tables t ON t.object_id = c.object_id
JOIN DerinSISBkm.sys.schemas s ON s.schema_id = t.schema_id
JOIN DerinSISBkm.sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
WHERE p.rows > 0 AND (c.name LIKE '%HediyeC%' OR c.name LIKE '%GiftCard%'
   OR c.name LIKE '%HediyeK%' OR c.name LIKE '%CekKod%' OR c.name LIKE '%CekNo%');

-- Hangfire job'larda gift uretimi YOK
SELECT TOP 20 j.Id, j.StateName, CONVERT(varchar(16), j.CreatedAt, 120) AS Olusma,
       LEFT(j.InvocationData, 200) AS Cagri
FROM EncoreMerkezLog.job.Job j WITH(NOLOCK)
WHERE j.InvocationData LIKE '%Gift%' OR j.InvocationData LIKE '%Hediy%'
   OR j.InvocationData LIKE '%Coupon%';

-- BKMLOG'da da iz yok (7,29 M satir; tarih penceresi ile daraltilir, ~15 s)
SELECT TOP 20 l.LogId, CONVERT(varchar(19), l.LogTarih, 120) AS Tarih, l.Kullanici,
       LEFT(l.Mesaj, 300) AS Mesaj
FROM BKMLOG.dbo.Log l WITH(NOLOCK)
WHERE l.LogTarih >= '20250826' AND l.LogTarih < '20250903'
  AND (l.Mesaj LIKE '%2141610259100%' OR l.Veri1 LIKE '%2141610259100%'
    OR l.Mesaj LIKE '%hediye%');


/* ---------------------------------------------------------------------------
   12) HARCAMA IZI — cmp.GiftCardTransaction (teslim degil ama zengin)
       SalesId = Sales.PosDocumentId  ->  Info JSON parse'a TEMIZ ALTERNATIF
       ⚠ SUM(Amount) CIFT SAYAR (100->50->200 her adim ayni Amount ile satir)
--------------------------------------------------------------------------- */
-- 12a) Islem tipi / durum akisi + hangi alanlar dolu
SELECT tr.TransactionType, tr.PreviousStatus, tr.Status, COUNT(*) AS Adet,
       SUM(CASE WHEN ISNULL(tr.StoreCode,'')   <> '' THEN 1 ELSE 0 END) AS StoreDolu,
       SUM(CASE WHEN ISNULL(tr.CashierCode,'') <> '' THEN 1 ELSE 0 END) AS KasiyerDolu,
       SUM(CASE WHEN ISNULL(tr.SalesId,'')     <> '' THEN 1 ELSE 0 END) AS SalesIdDolu,
       SUM(CASE WHEN ISNULL(tr.CustomerId,0)   <> 0  THEN 1 ELSE 0 END) AS MusteriDolu
FROM DerinCrm.cmp.GiftCardTransaction tr WITH(NOLOCK)
GROUP BY tr.TransactionType, tr.PreviousStatus, tr.Status
ORDER BY tr.TransactionType, tr.PreviousStatus;

-- 12b) SalesId gercekten PosDocumentId mi? (kopru dogrulama)
SELECT TOP 20 tr.Id, g.Code, tr.SalesId, tr.SalesAmount, tr.StoreCode, tr.PosCode,
       tr.CashierCode, tr.CustomerId, tr.CustomerCardNumber, tr.Amount,
       s.Id AS EncoreSalesId, s.PosDocumentId, CONVERT(varchar(10), s.Date, 104) AS FisTarih,
       s.GrossTotal, s.DiscountTotal
FROM DerinCrm.cmp.GiftCardTransaction tr WITH(NOLOCK)
JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK) ON g.Id = tr.GiftCardId
LEFT JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK)
       ON s.PosDocumentId = TRY_CONVERT(bigint, tr.SalesId)   -- ⚠ DerinCrm compat >= 130 ise TRY_CONVERT calisir
WHERE tr.TransactionType = 1;

-- 12c) Parti harcamasinin magaza/musteri dagilimi (kimlik izi ne kadar guclu?)
SELECT tr.StoreCode, COUNT(*) AS Hareket,
       COUNT(DISTINCT tr.GiftCardId) AS Cek,          -- DOGRU olcum birimi
       COUNT(DISTINCT tr.SalesId) AS Fis,
       COUNT(DISTINCT CASE WHEN ISNULL(tr.CustomerId,0) <> 0 THEN tr.CustomerId END) AS FarkliMusteri,
       SUM(CASE WHEN ISNULL(tr.CustomerId,0) = 0 THEN 1 ELSE 0 END) AS KartsizHareket,
       MIN(CONVERT(varchar(19), tr.Date, 120)) AS Ilk,
       MAX(CONVERT(varchar(19), tr.Date, 120)) AS Son
FROM DerinCrm.cmp.GiftCardTransaction tr WITH(NOLOCK)
JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK) ON g.Id = tr.GiftCardId
WHERE g.OriginalAmount = 500 AND CONVERT(date, g.CreatedAt) = '20250829'
GROUP BY tr.StoreCode;

-- 12d) Status=50 kalici mi? -> cmp.GiftCard'da YOK (yalniz 100/200) => acik bakiye
--      hesabi Status=100 ile DOGRU
SELECT g.HeaderId, g.Status, COUNT(*) AS Adet,
       SUM(g.OriginalAmount) AS Nominal, SUM(g.Amount) AS Kalan
FROM DerinCrm.cmp.GiftCard g WITH(NOLOCK)
GROUP BY g.HeaderId, g.Status;


/* ---------------------------------------------------------------------------
   13) CARI (car) TARAFI — "Inallar diye cari var mi?" + cek alim TARIHCESI
       ⚠ car taramasi fat eTip=1'den DAHA KAPSAYICI: 2023 alimi (cFatTip=4)
         yalniz burada gorunur. Cek alim gecmisi icin car esas alinmali.
--------------------------------------------------------------------------- */
-- 13a) Isim bazli cari arama: 6 kayit (3'u grup, 1 tedarikci, 1 alakasiz, 1 belirsiz)
SELECT frmID, frmKod, frmAd, frmTip, frmDurum, VN, VD, adres1,
       frmBagID, CONVERT(varchar(10), kTarih, 104) AS KayitTarihi
FROM DerinSISBkm.dbo.frm WITH(NOLOCK)
WHERE frmAd LIKE '%NALLAR%' OR frmAd LIKE '%GÖNYE%' OR frmAd LIKE '%GONYE%'
   OR frmAd2 LIKE '%NALLAR%' OR frmAd2 LIKE '%GÖNYE%';
/* SONUC:
   24922 İNALLAR OTOMOTİV  frmKod '4750606249'  ⚠ MUHASEBE HESAP KODU YOK (sadece VN)
   56291 İNALLAR SİGORTA   frmKod '120.10.İ021'  120 = ALICILAR ✔
   56292 GÖNYE OTOMOTİV    frmKod '120.10.G013'  120 = ALICILAR ✔
   2197  SALİH İNAL- İNALLAR TEMİZLİK  '320.10.S103'  320 = SATICILAR -> TEDARIKCI, grup DEGIL
   34694 İnallar Tarım     VN 4750554147 · 2 hareket / 98,35 TL (2022) · cek ALMAMIS · grup? belirsiz
   27257 Önallar sağ hiz   ALAKASIZ (isim benzerligi)                                        */

-- 13b) Cari ozet: hareket / borc / alacak / bakiye
SELECT c.cKod, f.frmAd, COUNT(*) AS Hareket,
       SUM(CASE WHEN c.cBA = 0 THEN c.cTutar ELSE 0 END) AS Borc,
       SUM(CASE WHEN c.cBA = 1 THEN c.cTutar ELSE 0 END) AS Alacak,
       SUM(c.cKalan) AS AcikKalan,
       MIN(c.cTarih) AS Ilk, MAX(c.cTarih) AS Son
FROM DerinSISBkm.dbo.car c WITH(NOLOCK)
JOIN DerinSISBkm.dbo.frm f WITH(NOLOCK) ON f.frmID = c.cKod
WHERE c.cKod IN (24922, 56291, 56292, 2197, 34694)
GROUP BY c.cKod, f.frmAd;
/* SONUC: TUM bakiyeler SIFIR (cKalan=0) -> tamami tahsil edilmis, acik risk yok */

-- 13c) Cek alim + odeme zinciri (cNot cek adedini yaziyor, NUMARA yok)
--      cTip 0 = fatura/borclandirma · 122 = tahsilat · 103/117/100 = diger
SELECT c.cID, c.cKod, f.frmAd, c.cTip, c.cBA, c.cTutar,
       CONVERT(varchar(10), c.cTarih, 104) AS Tarih, c.cEvrakNo,
       LTRIM(RTRIM(ISNULL(c.cNot, ''))) AS CariNot,
       c.cFatID, c.cFatTip, c.cKalan
FROM DerinSISBkm.dbo.car c WITH(NOLOCK)
JOIN DerinSISBkm.dbo.frm f WITH(NOLOCK) ON f.frmID = c.cKod
WHERE c.cKod IN (24922, 56291, 56292)
ORDER BY c.cTarih, c.cKod;
/* VADE BULGUSU (cek borcu -> tahsilat eslesmesi kurusu kurusuna):
   2024: cek 09-16.09 -> tahsilat 22.10 (24922: 121.550) ve 31.10 (56291: 5.950)
         => ~5 HAFTA VADE
   2025: cek 29.08 + 01.09 -> tahsilat 02.09 (24922: 204.000 · 56291: 81.600 · 56292: 122.400)
         => 1-4 GUN, neredeyse PESIN
   -> 2025'te tahsilat davranisi cok iyilesti; bonus/indirim gorusmesinde koz olarak
      kullanilabilir (nakit peşin + dusuk risk).                                     */

-- 13d) Cek alimini CARI uzerinden tara (fat eTip=1'den kapsayici)
SELECT c.cKod, f.frmAd, CONVERT(varchar(10), c.cTarih, 104) AS Tarih,
       c.cTutar, c.cFatTip, LTRIM(RTRIM(c.cNot)) AS CariNot
FROM DerinSISBkm.dbo.car c WITH(NOLOCK)
JOIN DerinSISBkm.dbo.frm f WITH(NOLOCK) ON f.frmID = c.cKod
WHERE c.cNot LIKE '%HED%YE%EK%' AND c.cKod IN (24922, 56291, 56292)
ORDER BY c.cTarih;
