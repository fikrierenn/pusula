/* ===========================================================================
   HEDIYE CEKI — MEVCUT DURUM MUTABAKATI (kac verildi / kac kullanildi)
   Tarih: 28.08.2026 · DB: master (3-parcali isim, cross-db)
   Rapor: docs/2026-08-28-hediye-ceki-mevcut-durum.md

   ZINCIR: PUAN.dbo.Siparis -> PUAN.dbo.CekListesi (barcode)
           -> DerinCrm.cmp.GiftCard (bakiye/durum)

   ⚠ ZORUNLU FILTRE: cl.isCancel=0 AND cl.isWrite=1
     isWrite=0 = siparis girilmis ama BASILMAMIS. Filtresiz nominal siser.
     Kanit (blok 4): vadesi gecmis kalan isWrite=1 -> 583.500 TL,
     isWrite=0 -> 10.000 TL (ENDERUN, 100 cek). Ilk olcum 593.500 CIKMISTI = HATA.

   ⚠ COLLATE: PUAN = Turkish_CS_AS, DerinCrm = Turkish_CI_AS
     -> g.Code = cl.barcode COLLATE Turkish_CI_AS  (yoksa collation conflict)

   ⚠ HARCAMA OLCUMU: g.OriginalAmount - g.Amount kullan.
     cmp.GiftCardTransaction'da SUM(Amount) CIFT SAYAR (100->50->200 durum
     akisi her adimda ayni Amount ile satir yazar).

   ANA BULGU: 16.832 cek / 7.276.174 TL basilmis; 4.374.370 TL'si (%60) CRM'de
     KAYITLI DEGIL -> harcanip harcanmadigi BILINMIYOR. Izlenebilir 2.901.804
     TL'nin 1.673.750 TL'si (%57,7) harcanmis, 1.228.054 TL acik.
=========================================================================== */

/* ---------------------------------------------------------------------------
   1) GENEL TOPLAM — tek satir ozet
--------------------------------------------------------------------------- */
SELECT COUNT(DISTINCT sp.id)         AS Siparis,
       COUNT(DISTINCT sp.FirmaIsmi)  AS Firma,
       COUNT(cl.id)                  AS BasilanCek,
       SUM(cl.cekTutari)             AS Nominal,
       SUM(CASE WHEN g.Id IS NULL THEN 1 ELSE 0 END)             AS CrmdeYokAdet,
       SUM(CASE WHEN g.Id IS NULL THEN cl.cekTutari ELSE 0 END)  AS CrmdeYokTutar,
       ISNULL(SUM(g.OriginalAmount - g.Amount), 0)               AS Harcanan,
       ISNULL(SUM(g.Amount), 0)                                  AS Kalan,
       SUM(CASE WHEN g.Status = 200 THEN 1 ELSE 0 END)           AS TukenmisCek,
       SUM(CASE WHEN g.Status = 100 AND sp.expireDate < GETDATE()
                THEN g.Amount ELSE 0 END)                        AS VadesiGecmisKalan
FROM PUAN.dbo.Siparis sp WITH(NOLOCK)
JOIN PUAN.dbo.CekListesi cl WITH(NOLOCK)
     ON cl.siparisId = sp.id AND cl.isCancel = 0 AND cl.isWrite = 1
LEFT JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
     ON g.Code = cl.barcode COLLATE Turkish_CI_AS;
/* SONUC 28.08.2026:
   237 siparis · 51 firma · 16.832 cek · 7.276.174 TL nominal
   CRM'de yok: 10.824 cek / 4.374.370 TL  (%60 — IZLENEMIYOR)
   Harcanan 1.673.750 · Kalan 1.228.054 · Tukenmis 2.431 cek
   Vadesi gecmis kalan 583.500 TL                                            */


/* ---------------------------------------------------------------------------
   2) FIRMA BAZINDA — kac verildi / kac kullanildi
      HAVING ile kucuk kayitlar elenir (23 firma < 10.000 TL, toplam 64.630)
--------------------------------------------------------------------------- */
SELECT sp.FirmaIsmi,
       COUNT(cl.id)      AS BasilanCek,
       SUM(cl.cekTutari) AS Nominal,
       SUM(CASE WHEN g.Id IS NULL THEN cl.cekTutari ELSE 0 END) AS CrmdeYokTutar,
       ISNULL(SUM(g.OriginalAmount - g.Amount), 0)              AS Harcanan,
       ISNULL(SUM(g.Amount), 0)                                 AS Kalan,
       MIN(CONVERT(varchar(10), sp.addDate, 104))    AS IlkSiparis,
       MAX(CONVERT(varchar(10), sp.expireDate, 104)) AS SonVade
FROM PUAN.dbo.Siparis sp WITH(NOLOCK)
JOIN PUAN.dbo.CekListesi cl WITH(NOLOCK)
     ON cl.siparisId = sp.id AND cl.isCancel = 0 AND cl.isWrite = 1
LEFT JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
     ON g.Code = cl.barcode COLLATE Turkish_CI_AS
GROUP BY sp.FirmaIsmi
HAVING SUM(cl.cekTutari) >= 10000
ORDER BY SUM(cl.cekTutari) DESC;
/* SEGMENT (nominal TL):
     Kendi magaza (BKMKitap*)      3.018.340  (%41 — perakende hediye karti)
     Test (COP KAYIT)              1.128.954  (%16 — bkz. blok 3)
     Grup-ici (Bursa Kultur Mrk.)    524.350  (%7)
     Dis kurumsal musteri          2.604.530  (%36)

   DIS MUSTERI UCLARI (kullanim = Harcanan / (Nominal - CrmdeYok)):
     YUKSEK: YILDIRIM BELEDIYESI %86 · EPSAN %74 · Tredin %73 · OSKIM %72
     SIFIRA YAKIN: IBRAS %6 (200 cek/150.000, sadece 5.250 kullanilmis)
                   HPA %6 · GURBUZ HOCA %0 (72.000 duruyor) · BORCELIK %0
     -> Bu firmalar cekleri almis ama calisanlarina DAGITMAMIS.

   ⚠ MUKERRER ISIM (ayni firma, farkli yazim — elle birlestirilmeli):
     HPA PLASTIK / hpa · OSKIM (2) · BTSO (2) · Ahi Hasan (2) · INALLAR (5+)
     FirmaIsmi SERBEST METIN, ERP cari (frmID) bagi YOK.                     */


/* ---------------------------------------------------------------------------
   3) "Test" FIRMASI — 100.000 TL gercek cek + 1.000.000 TL'lik tek cek
--------------------------------------------------------------------------- */
SELECT sp.id,
       CONVERT(varchar(10), sp.addDate, 104)    AS Tarih,
       CONVERT(varchar(10), sp.expireDate, 104) AS Vade,
       COUNT(cl.id)      AS Cek,
       MAX(cl.cekTutari) AS Kupur,
       SUM(cl.cekTutari) AS Nominal,
       SUM(CASE WHEN g.Id IS NULL THEN 1 ELSE 0 END)  AS CrmdeYok,
       SUM(CASE WHEN g.Status = 200 THEN 1 ELSE 0 END) AS Tukenmis,
       ISNULL(SUM(g.OriginalAmount - g.Amount), 0)    AS Harcanan,
       ISNULL(SUM(g.Amount), 0)                       AS Kalan
FROM PUAN.dbo.Siparis sp WITH(NOLOCK)
JOIN PUAN.dbo.CekListesi cl WITH(NOLOCK)
     ON cl.siparisId = sp.id AND cl.isCancel = 0
LEFT JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
     ON g.Code = cl.barcode COLLATE Turkish_CI_AS
WHERE sp.FirmaIsmi LIKE '%Test%'
GROUP BY sp.id, CONVERT(varchar(10), sp.addDate, 104),
         CONVERT(varchar(10), sp.expireDate, 104);
/* SONUC — 13 siparista cek basilmis, IKIYE AYRILIR:
   (a) GERCEK TEST (onemsiz): 1730 (5 cek x 2 TL) · 1541 (2 x 2 TL)
   (b) GERCEK PARA — hepsi 24.05.2025 AYNI GUN, vade 31.12.2026 (HALA AKTIF):
         1531:  50 cek x 1.000 =  50.000 · harcanan 26.000 · kalan 24.000
         1532: 100 cek x   250 =  25.000 · harcanan  9.000 · kalan 16.000
         1533: 100 cek x   250 =  25.000 · harcanan 11.750 · kalan 13.250
         TOPLAM 250 cek / 100.000 TL · 46.750 harcanmis · 53.250 ACIK
       Yetkili alani 'dasdas asd as das dasd as d', tel 5468668812.
       -> 100.000 TL'lik gercek parti "Test" adina basilmis, KIME VERILDIGI YOK.
   (c) 1243 (26.07.2023): TEK CEK, 1.000.000 TL nominal. CRM'e hic aktarilmamis,
       vade 31.12.2024 dolmus, harcanmamis. Test segmentinin 1 M TL'si bu.      */

-- 3b) Test ceklerinin harcama izi (magaza/kasiyer/fis)
SELECT g.Code, g.OriginalAmount AS Kupur, g.Amount AS Kalan, g.Status,
       sp.id AS SiparisId,
       tr.StoreCode, tr.PosCode, tr.CashierCode,
       CONVERT(varchar(19), tr.Date, 120) AS HarcamaTarih,
       tr.SalesId, tr.Amount AS HarcananTutar
FROM PUAN.dbo.Siparis sp WITH(NOLOCK)
JOIN PUAN.dbo.CekListesi cl WITH(NOLOCK)
     ON cl.siparisId = sp.id AND cl.isCancel = 0
JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
     ON g.Code = cl.barcode COLLATE Turkish_CI_AS
LEFT JOIN DerinCrm.cmp.GiftCardTransaction tr WITH(NOLOCK) ON tr.GiftCardId = g.Id
WHERE sp.FirmaIsmi LIKE '%Test%' AND g.OriginalAmount > g.Amount
ORDER BY tr.Date;
/* M01/M02, 2026-04 ile 2026-07 arasi, kasiyer 144/218/223/229.
   ⚠ Her cek 2 satir (durum akisi) — SUM(tr.Amount) CIFT SAYAR.               */


/* ---------------------------------------------------------------------------
   4) VADESI GECMIS + BAKIYELI — isWrite ayrimi (593.500 vs 583.500 dersi)
--------------------------------------------------------------------------- */
SELECT cl.isWrite,
       COUNT(*)                     AS Cek,
       SUM(g.Amount)                AS VadesiGecmisKalan,
       COUNT(DISTINCT sp.FirmaIsmi) AS Firma
FROM PUAN.dbo.Siparis sp WITH(NOLOCK)
JOIN PUAN.dbo.CekListesi cl WITH(NOLOCK)
     ON cl.siparisId = sp.id AND cl.isCancel = 0
JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
     ON g.Code = cl.barcode COLLATE Turkish_CI_AS
WHERE g.Status = 100 AND g.Amount > 0 AND sp.expireDate < GETDATE()
GROUP BY cl.isWrite;
/* SONUC: isWrite=1 -> 1.494 cek / 583.500 TL / 24 firma  ← DOGRU
          isWrite=0 ->   100 cek /  10.000 TL /  1 firma  ← BASILMAMIS, sayma
   Ilk olcumde isWrite filtresi yoktu -> 593.500 TL yanlis rakam uretildi.    */

-- 4b) Vadesi gecmis kalan — firma bazinda
SELECT sp.FirmaIsmi,
       COUNT(*)      AS Cek,
       SUM(g.Amount) AS VadesiGecmisKalan,
       MAX(CONVERT(varchar(10), sp.expireDate, 104)) AS SonVade
FROM PUAN.dbo.Siparis sp WITH(NOLOCK)
JOIN PUAN.dbo.CekListesi cl WITH(NOLOCK)
     ON cl.siparisId = sp.id AND cl.isCancel = 0 AND cl.isWrite = 1
JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
     ON g.Code = cl.barcode COLLATE Turkish_CI_AS
WHERE g.Status = 100 AND g.Amount > 0 AND sp.expireDate < GETDATE()
GROUP BY sp.FirmaIsmi
ORDER BY SUM(g.Amount) DESC;
/* 24 firma, TAMAMININ vadesi 31.12.2025, hicbiri kismen bile kullanilmamis.
   SEGMENT:  Dis musteri 269.350 · Kendi magaza 239.700 · Grup-ici 83.450
             · Test 1.000   = 583.500 TL
   Dis ilk 5: IBRAS 75.750 · INALLAR 49.000 · EPSAN 40.750 · HPA 25.500
              · MEDICABIL 21.000  (toplamin %79'u)
   -> Dis musteri 269.350 TL tahsil edilmis, mal verilmemis, vade dolmus.
      Gelir yazilip yazilmayacagi MUHASEBEYE sorulmali.                       */


/* ---------------------------------------------------------------------------
   5) FIRMA x VERILIS AYI x SKT — verilen / kullanilan / kalan / izlenmeyen
      Kendi magaza (BKMKitap*) + grup-ici (Kultur Merkezi) haric -> 67 satir
      Ay formati DMY uyumlu: RIGHT(...,104),7) = 'MM.yyyy'
--------------------------------------------------------------------------- */
SELECT sp.FirmaIsmi,
       RIGHT(CONVERT(varchar(10), sp.addDate, 104), 7) AS Ay,
       CONVERT(varchar(10), sp.expireDate, 104)        AS SKT,
       COUNT(cl.id)      AS Cek,
       SUM(cl.cekTutari) AS Verilen,
       SUM(CASE WHEN g.Id IS NULL THEN cl.cekTutari ELSE 0 END) AS Izlenmeyen,
       ISNULL(SUM(g.OriginalAmount - g.Amount), 0)              AS Kullanilan,
       ISNULL(SUM(g.Amount), 0)                                 AS Kalan
FROM PUAN.dbo.Siparis sp WITH(NOLOCK)
JOIN PUAN.dbo.CekListesi cl WITH(NOLOCK)
     ON cl.siparisId = sp.id AND cl.isCancel = 0 AND cl.isWrite = 1
LEFT JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
     ON g.Code = cl.barcode COLLATE Turkish_CI_AS
WHERE sp.FirmaIsmi NOT LIKE 'BKMKitap%'
  AND sp.FirmaIsmi NOT LIKE '%KULTUR MERKEZ%'   -- canlida: '%KÜLTÜR MERKEZ%'
GROUP BY sp.FirmaIsmi,
         RIGHT(CONVERT(varchar(10), sp.addDate, 104), 7),
         CONVERT(varchar(10), sp.expireDate, 104)
ORDER BY MAX(sp.addDate) DESC;
/* SKT BAZLI OZET (28.08.2026):
     SKT          Verilen     Kullanilan   Kalan      Izlenmeyen   Kullanim*
     31.12.2026   1.158.980     725.400    366.454       67.126      %66
     31.12.2025   1.011.204      44.800    260.350      706.054      %15
     31.12.2024   1.447.700           0          0    1.447.700      olcelemez
     31.12.2023     111.600           0          0      111.600      olcelemez
     * izlenebilir kisim uzerinden

   OKUMA:
   - 2025 partileri: hacim buyudu + kullanim %66 + izlenebilirlik %94
     (CRM entegrasyonu 2025'te oturdu).
   - 2024 partileri KULLANILMADAN YANDI: izlenebilir kisimda %14,7 kullanim.
     Cekler musterinin elinde kaldi (IBRAS 150.000 verilmis / 5.250 kullanilmis).
   - 2022-2023 = 1.559.300 TL kara kutu; 1.000.000'i tek 'Test' cekidir (07.2023),
     o dusulunce gercek tutar 559.300 TL.

   ⚠ DIKKAT: blok 2'deki HAVING >= 10000 kesmesi 4.000 TL'lik bir BKMKitap
     siparisini disarida birakiyor -> segment toplaminda kendi magaza 3.022.340
     (3.018.340 DEGIL), dis kurumsal 2.600.530.
   ⚠ Vadesi gecmis DIS MUSTERI kalani 259.350 TL (269.350 DEGIL — ENDERUN'un
     100 cekli / 10.000 TL'lik satiri isWrite=0, basilmamis).                  */


/* ---------------------------------------------------------------------------
   6) INALLAR — cek ne CIRO ne KAR getirdi (perakende fis bazli)
      Taban: DocumentsTypeId = 1 (231 fis). Tip 8 (Sinav) AYIKLANDI — bkz. not.
      Maliyet: fat5 kanonik (sema birim_maliyet.MLYT), kapsama %98,1.

   ⚠ SalesProducts.TotalPrice INDIRIM SONRASI:
        Net  = TotalPrice - VatTotal
        Brut = TotalPrice - VatTotal + DiscountTotalDirect
      'TotalPrice - DiscountTotalDirect - VatTotal' indirimi IKI KEZ duser.

   ⚠ Tip 8 (Sinav Okullari) 3 fiste yalniz 4.500 TL cek kullanilmis ama
     90.368 TL net ciro var -> dahil edilirse kaldirac 1,24x yerine 1,53x,
     kirilma %46,5 yerine %54,9 gorunur. Cek analizinde taban = tip 1.

   ⚠ 3 fis iki Inallar sirketinde birden sayiliyor (her ikisinin cekleri ayni
     fiste kullanilmis) -> firma bazinda 238, tekil 235, perakende 231.
--------------------------------------------------------------------------- */

-- 6a) Fis/ciro tabani (baslik seviyesi, belge tipi kirilimli)
SELECT s.DocumentsTypeId AS Tip, COUNT(*) AS Fis,
       SUM(s.GrossTotal)   AS Brut,
       SUM(s.DiscountTotal) AS Indirim,
       SUM(s.VatTotal)      AS Kdv,
       SUM(s.GrossTotal - s.DiscountTotal - s.VatTotal) AS Net
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Id IN (
      SELECT s2.Id
      FROM PUAN.dbo.Siparis pv WITH(NOLOCK)
      JOIN PUAN.dbo.CekListesi cl WITH(NOLOCK)
           ON cl.siparisId = pv.id AND cl.isCancel = 0 AND cl.isWrite = 1
      JOIN DerinCrm.cmp.GiftCard g WITH(NOLOCK)
           ON g.Code = cl.barcode COLLATE Turkish_CI_AS
      JOIN DerinCrm.cmp.GiftCardTransaction tr WITH(NOLOCK)
           ON tr.GiftCardId = g.Id AND tr.SalesId <> ''
      JOIN EncoreMerkez.dbo.Sales s2 WITH(NOLOCK)
           ON s2.PosDocumentId = TRY_CONVERT(bigint, tr.SalesId)
      WHERE pv.FirmaIsmi LIKE '%NALLAR%')
GROUP BY s.DocumentsTypeId;
/* Tip 1: 231 fis · brut 444.326,10 · ind 70.379,51 · kdv 43.223,64 · net 330.722,95
   Tip 2:   1 fis · net   1.272,50
   Tip 8:   3 fis · net  90.368,32   <- AYIKLA                                */

-- 6b) Odeme kirilimi -> kaldirac (musteri cekin ustune ne koydu?)
SELECT pt.Id, pt.Name, COUNT(*) AS Hareket, SUM(pay.Amount) AS Tutar
FROM EncoreMerkez.dbo.SalesPayments pay WITH(NOLOCK)
JOIN EncoreMerkez.dbo.PaymentTypes pt WITH(NOLOCK) ON pt.Id = pay.PaymentTypesId
WHERE pay.IsChangeAmount = 0
  AND pay.SalesId IN ( /* ... ayni alt sorgu ... */ )
GROUP BY pt.Id, pt.Name;
/* TUM tipler: HEDIYE CEKI 306.000 · kart 154.637 · nakit 8.937 · iade ceki 108
   Tip 1'e dusen cek: 300.500  (tip 8: 4.500 · tip 2: 1.000)
   Tip 1 tahsilat (KDV dahil) = 444.326,10 - 70.379,51 = 373.946,59
   -> musteri ilave odemesi 73.446,59 · KALDIRAC 1,24x                         */

-- 6c) Kategori x maliyet (fat5) — perakende fis
SELECT d.KatAna, SUM(d.Net) AS Net, SUM(d.Brut) AS Brut, SUM(d.Adet) AS Adet,
       SUM(CASE WHEN MLYT.Birim > 0 THEN d.Net ELSE 0 END)             AS NetKapsanan,
       SUM(CASE WHEN MLYT.Birim > 0 THEN d.Adet * MLYT.Birim ELSE 0 END) AS Maliyet
FROM (
    SELECT ISNULL(ub.KatAna, N'Tanimsiz') AS KatAna,
           CONVERT(int, p.Code) AS StkID,
           SUM(sp2.TotalPrice - sp2.VatTotal)                              AS Net,
           SUM(sp2.TotalPrice - sp2.VatTotal + sp2.DiscountTotalDirect)    AS Brut,
           SUM(sp2.Amount)                                                 AS Adet
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.SalesProducts sp2 WITH(NOLOCK)
         ON sp2.SalesId = s.Id AND sp2.IsValid = 1
    JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp2.ProductsId
    LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub WITH(NOLOCK)
         ON ub.stkID = CONVERT(int, p.Code)
    WHERE ISNUMERIC(p.Code) = 1
      AND s.DocumentsTypeId = 1
      AND ISNULL(ub.KatAna, N'') <> N'Hediye Çeki'   -- cek SKU'su avans, stok degil
      AND s.Id IN ( /* ... ayni alt sorgu ... */ )
    GROUP BY ISNULL(ub.KatAna, N'Tanimsiz'), CONVERT(int, p.Code)
) d
OUTER APPLY (   -- fat5 kanonik birim maliyet
    SELECT CONVERT(money, SUM(b.tut) / NULLIF(SUM(b.adt), 0)) AS Birim
    FROM (
        SELECT TOP 5 ML.tut, ML.adt FROM (
            SELECT TOP 5 f.eTarih AS trh, fa.ehTutarN AS tut, fa.ehAdetN AS adt
            FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK)
                 ON fa.ehID = f.eID AND f.eTip = 0 AND f.eDurum <> 2
                AND f.eTarih < '20260828'
                AND (f.eFirma <> 9525 OR f.eTarih >= '20220901')
            WHERE fa.ehStkID = d.StkID AND fa.ehAdetN <> 0
            ORDER BY f.eTarih DESC
            UNION ALL
            SELECT TOP 5 o.TARIH, o.NET * o.ADET, o.ADET
            FROM BKMDATA..ODAK_FATURA o WITH(NOLOCK)
            WHERE o.STKID = d.StkID AND o.TARIH < '20260828' AND o.ADET <> 0
            ORDER BY o.TARIH DESC
        ) ML ORDER BY ML.trh DESC
    ) b HAVING SUM(b.adt) <> 0
) MLYT
GROUP BY d.KatAna;
/* SONUC (231 perakende fis):
     Brut 401.060,26 · Indirim 70.337,31 (%17,5) · NET CIRO 330.722,95
     Kapsanan net 324.442,53 (%98,1) · Maliyet 184.685,47
     BRUT KAR 139.757,06 · MARJ %43,1

   KATEGORI:
     Kirtasiye  284.736,76  %86,1 pay · marj %45,8 · kar 129.079,03
     Kitap (11)  29.869,75  %9,0  pay · marj %18,8 · kar   5.231,76
     Diger       16.116,44  %4,9  pay · marj %36,2 · kar   5.446,27
     -> kirtasiye disi sizma %13,9; sizan kismin buyugu KITAP ve orada
        marj kirtasiyenin yarisindan az -> sizma = kural ihlali + kar kaybi.

   EKONOMI:
     Cek harcanan (tip 1)            300.500
     Kar / 1 TL cek                    0,465  -> KIRILMA INDIRIMI %46,5
     Gercek indirim %14,76 -> maliyet  44.354
     NET KATKI                         95.403   (marjin %68'i korunuyor)

   KULLANILMAYAN KISIM (ayri hikaye):
     Basilan 672.000 - harcanan 300.500 = 371.500 nominal kullanilmadi.
     Karsiliginda 316.667 TL nakit tahsil edildi, mal verilmedi.
     49.000'i vadesi dolarak yandi -> tahsil edilen ~41.767 TL TAM KAR.
     ~216.500 hala acik (31.12.2026).                                          */
