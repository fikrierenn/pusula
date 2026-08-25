/* =============================================================================
   HEDIYE CEKI — URUN KARLILIGI + INDIRIM ORANI + INDIRIM TAVANI
   Tarih: 25.08.2026 · DB: EncoreMerkez (+ DerinSISBkm.bkm.UrunBilgi koprusu)
   Soru: Musteri hediye ceki alirken nominal uzerinden indirim istiyor.
         Cekin harcandigi sepetin marji ve mevcut indirim orani ne?
         Verilebilecek indirim tavani nedir?

   BULGU OZETI v2 (Agu-2025 -> Tem-2026, 12 ay) — v1 IKI HATA DUZELTILDI:
     (H1) Maliyet UrunBilgi.SonAlis ile hesaplanmisti -> KANONIK = fat5 (son 5 alis faturasi).
          Marj %27,3 -> %32,4 (fark 5,1 pp; tek fatura enflasyonda maliyeti yukari ceker).
     (H2) Cek satisi YALNIZ POS'tan sayilmisti -> cekler DerinSIS SATIS FATURASI ile de satiliyor
          ve ASIL KANAL ORASI. v1'deki "1,19 M TL yukumluluk acigi" bulgusu GECERSIZ.

   · KANAL (irsHrk, KDV-haric net): Satis faturasi (ehTip 1) 1.750.480 TL = %54,7 ·
     POS Satis (100) 1.124.278 = %35,2 · Magaza Satis (4) 323.550 = %10,1
     -> brut 3.198.307 · iade (3+5+101) 137.379 -> NET SATILAN 3.060.928
     Kanal disi: Diger Giris (88) 2.219.570 = cek basimi/stok girisi (SATIS DEGIL) ·
     Diger Cikis+Sirket Ici (89+98) 122.000 = imha/merkeze iade/kisiye hediye (16 kayit notu okundu)
   · FATURA KANALINDA INDIRIM ZATEN VAR: brut 1.842.370 · indirim 91.890 = %4,99 ORTALAMA
     AMA KURALSIZ: %15 (INALLAR OTOMOTIV 240K, GONYE 144K, INALLAR SIGORTA 96K) ·
     %5 (ULUDAG ONKOLOJI 150K, BTSO 105K) · %4,15 (OSKIM 172K) ·
     %0 (HPA 250K, EPSAN 227,5K = EN BUYUK IKI DIS ALICI!) · %0 Bursa Kultur Merkezi (grup-ici)
     -> indirim ile hacim arasinda ILISKI YOK, hatta TERS. Politika yok, pazarlik var.
   · KULLANIM: 2.589.048 TL / 4.450 hareket · %100 IsGiftCard=true
     GERI DONUSUM/IADE CEKLERI KAPSAM DISI (ayri odeme tipi: IADE CEKI = PaymentTypesId 10,
     15,1 M TL / 35.590 hareket). Hediye cekinde hic IsRefundVoucher YOK.
   · BAKIYE: 3.060.928 - 2.589.048 = +471.880 TL kullanilmamis (pozitif, normal)
   · HC'li sepet: 2.855 fis · brut 4.629.239 · indirim 836.856 -> %18,08
     Kontrol (normal fis): 1.140.639 fis · %18,83 -> HC sepetinde ISTISMAR YOK; sepet 2,05x buyuk
   · HC SEPETI MARJI (fat5): %32,4 · kapsama %99
     Kirtasiye %45,3 · Hediyelik %44,8 · Hobi-Oyuncak %37,0 · Egitim-Sinav %24,7 ·
     Cocuk %14,7 · Edebiyat %14,3  -> cekin nereye harcandigi sonucu IKIYE KATLIYOR
   · KALDIRAC COKUYOR: <=100 TL 10,66x · 251-500 1,94x · 501-1000 1,47x ·
     1001-2500 1,22x · 2500+ 1,14x (ort 1,54x)
     -> Indirim isteyen toplu alici, kaldiracin EN AZ oldugu dilim
   · KIRILMA (brut kar=0) = kaldirac x 0,917 x marj:
     2500+ karma sepet %33,9 · 2500+ KITAP sepeti %15,2 <- BAGLAYICI KISIT
     -> BUGUN VERILEN %15 TAM KIRILMA NOKTASINDA (kitap senaryosunda sifir kar)
   · v4 BAREM ANALIZI — SONUC DEGISTI: cek dilimi x ortalama sepet x marj (blok 16)
     Barem   Fis  OrtCek  OrtSepet Kaldirac Marj%  Kar/fis  Kar/1TLcek  Kitap%
     <=100   275      61       655   10,66x  28,2      176      2,858     22,9
     101-250 465     186       737    3,96x  28,8      200      1,076     25,4
     251-500 788     448       870    1,94x  29,4      237      0,529     32,0
     501-1K  786     907     1.329    1,47x  31,1      379      0,418     27,0
     1-2,5K  382   1.815     2.221    1,22x  35,6      714      0,393     15,8
     2,5K+   159   3.813     4.344    1,14x  37,4    1.463      0,384      9,2
     -> KALDIRAC duserken MARJ YUKSELIYOR (kitap payi %23 -> %9). Buyuk cek KIRTASIYE/OYUNCAK aliyor.
     -> v3'teki "kitap senaryosu baglayici, kirilma %15,2" TEZI CURUDU.
        Gercek mix ile kirilma: 2,5K+ %38,4 · 1-2,5K %39,3 · 501-1K %41,8 · 251-500 %52,9
     -> ONERI: tavan %15 kademeli (<2.500 %0 · 2.500-24.999 %8 · 25.000-99.999 %12 · 100.000+ %15)
        %15'te en zayif baremde 0,234 TL/TL kalir (marjin %61'i).
     -> IZLEME: barem-6 kitap payi %9,2'den %25'e cikarsa kirilma ~%25'e iner, tavan daralir.
   · v5 INDIRIM vs BONUS (cek fazlasi) — blok 18
     Musteri esdegerligi: b = x/(1-x) -> %15 indirim = %17,65 bonus.
     AYNI KUPURDE bonus = indirim (BIREBIR AYNI): 1 TL nakit basina 0,283 vs 0,283.
     Avantaj YALNIZ kupur kucultmeden dogar. BASILI kupur (yuvarlak) oranlari:
       50/100 TL: kaldirac 4,75x · marj %28,2 · kar/1TL-cek 1,228  (! sadece 28 fis/2.500 TL)
       200 TL   : 3,30x · %28,8 · 0,872        500 TL: 1,86x · %29,4 · 0,501
       1.000 TL : 1,45x · %31,1 · 0,414        2.500+: 1,14x · %37,4 · 0,391
     -> 50/100 TL'de kar/1TL = 1,228 > 1 => BONUS ARTTIKCA KAR ARTAR, kirilma YOK.
     %15 senaryosu 1 TL nakit basina: indirim 0,283 · bonus 50/100 0,431 (+%52) ·
       bonus 200 0,368 · bonus 500 0,303 · bonus ayni kupur 0,283
     480.000 TL olcegi: indirim 115.667 TL kar · bonus(50/100) 204.106 TL (+88.439, +%76)
     Ek avantaj: %15 bonus musteri gozuyle %13,04 indirim (1,96 puan tasarruf, ayni headline);
       bonus maliyeti KOSULLU (kullanilmazsa 0) vs indirim nakdi KESIN; nakit +72.000 TL bugun.
     ⚠ ARBITRAJ: 10 adet 100 TL cek tek fiste harcanirsa sepet 2.500+ barem'e doner,
       kar/1TL 1,228 -> 0,391 COKER ve avantaj SIFIRLANIR.
       ZORUNLU KURAL: tek fiste EN FAZLA 1 BONUS CEK (POS'ta zorlanmali).
     ⚠ §7'deki 10,66x kaldirac BONUS TASARIMINDA KULLANILAMAZ — o 247 fislik KISMI BAKIYE
       ARTIGI davranisi (musteri zaten alisveristeydi). Basili kupur gercegi 4,75x.
   · v4 GRUP KONSOLIDASYONU: INALLAR OTOMOTIV + INALLAR SIGORTA + GONYE OTOMOTIV = AYNI GRUP
     (kullanici teyidi + ucu de Ovaakca Cesmebasi/Istanbul Cad. adresinde).
     Konsolide: 480.000 TL brut / 72.000 TL indirim = %15 -> EN BUYUK ALICI (%26 brut payi)
     ve indirim butcesinin %78,4'u BU GRUPTA (konsantrasyon).
     ⚠ frm.frmBagID + frmGrup1..5 HEPSINDE 0 -> ERP'de grup alani VAR ama KULLANILMIYOR;
       musteri grup haritasi olmadan her analiz elle konsolide etmek zorunda.
     ⚠ VN oneki GRUP KANITI DEGIL (CETIN ELEKTRIK 2450383237 / CETIN PROJE 2450012214 ayni onek
       ama farkli adres -> "teyit bekliyor"). Kanit = ortak adres + kullanici teyidi.
   · v3 COZULDU — fatAyr eTip=4 TUTARSIZLIGI: ehTutarN MAGAZA SATISINDA BESLENMIYOR.
     Sistematik + 4 YILLIK + KOTULESIYOR: net=0 satir orani 2023 %65,4 · 2024 %63,7 ·
     2025 %72,5 · 2026 %76,8. Diger tum eTip'lerde <=%0,28 (Oca-2026 kontrol).
     Buyukluk: 2025'te ehTutar 67,8 M - indirim 2,9 M = beklenen 64,9 M, okunan ehTutarN 12,7 M
     -> ~52 M TL EKSIK OKUMA. KURAL: eTip=4'te ehTutarN KULLANMA -> irsHrk (ehTip=4) veya
     ehTutar - ehIndirim. ehIndirim de eTip=4'te cogunlukla 0.
   · v3 COZULDU — GERI DONUSUM CEKLERI: kasada IADE SEBEBI olarak isliyor.
     `RefundReasons.Id=12 'Geri Dönüşüm'` (Type=0 iade sebebi, olusturma 21.07.2025).
     Urun: `stkID 583160 'Geri Dönüşüm Kağıt Madde Alımı'` (KatAna 'Tanımsız'/Kategori3 'Genel').
     Hacim 12 ay: sebep-bazli 10.850 fis / 368.269 kg / 1.923.399 TL · SKU-bazli 1.686.349 TL.
     Karsiliginda verilen cek = IADE CEKI (tip 10): 10.679 hareket / 1.733.514 TL. Tip 11'de HIC YOK.
     ⚠ HEDIYE CEKLI SEPETTE GERI DONUSUM = SIFIR (hem sebep hem SKU bazli kanitlandi)
       -> marj %32,4 ve kaldirac rakamlari ETKILENMEDI. Yalniz KONTROL GRUBU kirliydi:
       indirim orani %18,83 -> %18,74 (geri donusum haric), HC %18,08 -> %18,07, sepet 2,03x.
     AYIKLAMA KURALI: `sp.RefundReasonId <> 12 AND p.Code <> '583160'` (IKISI BIRDEN —
     SKU 416 satirda yanlis sebep koduyla (4/5/1/2) ve 12 satirda DocType=1 ile de gecmis).
   · ACIK: FIFO (BKMMaliyet) capraz mutabakati YAPILAMADI (MCP izin listesinde degil).

   KURALLAR: SalesProducts IsValid=1 · DocumentsTypeId 1/3 (perakende fis, iade ters isaret)
             indirim = DiscountTotalDirect (Campaign alt kume, TOPLAMA) · net = KDV-haric
             kopru = Products.Code (int) = urn.stkID (stkKod/barkod DEGIL)
             EncoreMerkez compat 110 -> TRY_CONVERT/IIF/STRING_AGG/JSON_VALUE YOK
============================================================================= */

/* ---------------------------------------------------------------------------
   1) ODEME TIPLERI — HEDIYE CEKI = PaymentTypesId 11 (IADE CEKI = 10, ayri)
--------------------------------------------------------------------------- */
SELECT pt.Id, pt.Name, COUNT(sp.Id) AS Hareket, SUM(sp.Amount) AS Tutar
FROM EncoreMerkez.dbo.PaymentTypes pt
LEFT JOIN EncoreMerkez.dbo.SalesPayments sp
       ON sp.PaymentTypesId = pt.Id AND sp.IsChangeAmount = 0
      AND sp.SalesId IN (SELECT Id FROM EncoreMerkez.dbo.Sales
                         WHERE Date >= '20250801' AND Date < '20260801'
                           AND DocumentsTypeId IN (1,2,3,6,7,8))
GROUP BY pt.Id, pt.Name
ORDER BY Tutar DESC;

/* ---------------------------------------------------------------------------
   2) SATILAN CEK (aylik) — urnKtgr2.ktgrAd = N'Hediye Çeki' · KDV = 0 (avans)
      Kupurler: 50 / 100 / 200 / 500 / 750 / 1000 TL · satis Tem-2025'te basladi
--------------------------------------------------------------------------- */
SELECT CONVERT(varchar(7), s.Date, 126)                                  AS Ay,
       COUNT(DISTINCT s.Id)                                              AS Fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) AS Adet,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice+sp.DiscountTotalDirect)
                ELSE (sp.TotalPrice+sp.DiscountTotalDirect) END)         AS Brut,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.DiscountTotalDirect
                ELSE sp.DiscountTotalDirect END)                         AS Indirim,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.TotalPrice ELSE sp.TotalPrice END) AS Odenen
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p       ON p.Id = sp.ProductsId
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= '20250801' AND s.Date < '20260801'
  AND ISNUMERIC(p.Code) = 1
  AND CONVERT(int, p.Code) IN (SELECT u.stkID
                               FROM DerinSISBkm.dbo.urn u
                               JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID
                               WHERE k.ktgrAd = N'Hediye Çeki')
GROUP BY CONVERT(varchar(7), s.Date, 126)
ORDER BY Ay;

/* ---------------------------------------------------------------------------
   3) KULLANILAN CEK — yuvarlak (gercek cek) vs kusurlu tutar (promo/kismi)
      %94 yuvarlak -> kullanim agirlikli olarak SATILAN cek, promo kodu degil
--------------------------------------------------------------------------- */
SELECT CASE WHEN pt.Amount % 50 = 0 THEN 'Yuvarlak (50 kati)' ELSE 'Kusurlu tutar' END AS TutarTipi,
       COUNT(*) AS Hareket, SUM(pt.Amount) AS Tutar,
       AVG(pt.Amount) AS OrtTutar, MAX(pt.Amount) AS EnBuyuk
FROM EncoreMerkez.dbo.SalesPayments pt
JOIN EncoreMerkez.dbo.Sales s ON s.Id = pt.SalesId
WHERE pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
  AND s.DocumentsTypeId IN (1,2,6,7,8)
  AND s.Date >= '20250801' AND s.Date < '20260801'
GROUP BY CASE WHEN pt.Amount % 50 = 0 THEN 'Yuvarlak (50 kati)' ELSE 'Kusurlu tutar' END;

/* Cek kodu SalesPayments.Info JSON'unda: GiftCardCode / IsGiftCard / IsRefundVoucher.
   compat 110 -> JSON_VALUE YOK, string ile cikarilir (bazi satirlarda kod bos -> guard sart) */
SELECT TOP 20 pt.Id, pt.SalesId, pt.Amount, pt.Info
FROM EncoreMerkez.dbo.SalesPayments pt
WHERE pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0;

/* ---------------------------------------------------------------------------
   4) SATILAN vs KULLANILAN (yillik) — ! SUPERSEDED, blok 9 kullan
      Bu blok cek satisini YALNIZ POS'tan sayar -> hacmi ~3 kat eksik gosterir ve
      yanlis "yukumluluk acigi" uretir. Kanal toplami icin BLOK 9 (irsHrk) esastir.
      NOT: Encore go-live 11.07.2025 -> 2024 kullanimi bu DB'de YOK (eski POS).
--------------------------------------------------------------------------- */
SELECT YEAR(s.Date) AS Yil, COUNT(DISTINCT s.Id) AS Fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.TotalPrice ELSE sp.TotalPrice END) AS SatilanCek
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p       ON p.Id = sp.ProductsId
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date >= '20230101'
  AND ISNUMERIC(p.Code) = 1
  AND CONVERT(int, p.Code) IN (SELECT u.stkID FROM DerinSISBkm.dbo.urn u
                               JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID
                               WHERE k.ktgrAd = N'Hediye Çeki')
GROUP BY YEAR(s.Date) ORDER BY Yil;

SELECT YEAR(s.Date) AS Yil, COUNT(DISTINCT s.Id) AS Fis, SUM(pt.Amount) AS KullanilanCek
FROM EncoreMerkez.dbo.SalesPayments pt
JOIN EncoreMerkez.dbo.Sales s ON s.Id = pt.SalesId
WHERE pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
  AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.Date >= '20230101'
GROUP BY YEAR(s.Date) ORDER BY Yil;

/* ---------------------------------------------------------------------------
   5) INDIRIM ORANI — HC'li sepet vs normal sepet (KONTROL GRUBU)
      Sales ustu toplam kullanilir (hizli, kalem join'i gerekmez)
--------------------------------------------------------------------------- */
SELECT CASE WHEN hc.SalesId IS NULL THEN 'Normal' ELSE 'HediyeCekli' END AS Grup,
       COUNT(*) AS Fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END)   AS Brut,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.DiscountTotal ELSE s.DiscountTotal END) AS Indirim,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                ELSE (s.GrossTotal-s.DiscountTotal-s.VatTotal) END)                  AS NetKdvHaric
FROM EncoreMerkez.dbo.Sales s
LEFT JOIN (SELECT DISTINCT SalesId FROM EncoreMerkez.dbo.SalesPayments
           WHERE PaymentTypesId = 11 AND IsChangeAmount = 0) hc ON hc.SalesId = s.Id
WHERE s.DocumentsTypeId IN (1,3) AND s.Date >= '20250801' AND s.Date < '20260801'
GROUP BY CASE WHEN hc.SalesId IS NULL THEN 'Normal' ELSE 'HediyeCekli' END;

/* ---------------------------------------------------------------------------
   6) HC SEPETI MARJI — ! SUPERSEDED, blok 12 kullan (kanonik fat5)
      maliyet = bkm.UrunBilgi.SonAlis (TEK son alis) -> marj %27,3; fat5 ile %32,4.
      SonAlis enflasyonda maliyeti yukari ceker. Blok 12 kanoniktir.
      NOT: kapsama ayri raporlanir (SonAlis=0 -> maliyet yok, net'ten dusulmez)
      N'Hediye Çeki' kategorisi ANALIZDEN CIKAR (stok degil, avans)
      ! Tum perakendeye ayni sorguyu 12 ay icin kosarsan MCP 30s timeout — aylik bol
--------------------------------------------------------------------------- */
SELECT ub.KatAna,
       COUNT(*) AS Satir,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) AS Adet,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice+sp.DiscountTotalDirect)
                ELSE (sp.TotalPrice+sp.DiscountTotalDirect) END)             AS Brut,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.DiscountTotalDirect
                ELSE sp.DiscountTotalDirect END)                             AS Indirim,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice-sp.VatTotal)
                ELSE (sp.TotalPrice-sp.VatTotal) END)                        AS Net,
       SUM(CASE WHEN ub.SonAlis > 0
                THEN (CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice-sp.VatTotal)
                           ELSE (sp.TotalPrice-sp.VatTotal) END) ELSE 0 END) AS NetKapsanan,
       SUM(CASE WHEN ub.SonAlis > 0
                THEN CONVERT(decimal(19,4),
                     (CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) * ub.SonAlis)
                ELSE 0 END)                                                  AS Maliyet
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p       ON p.Id = sp.ProductsId
JOIN DerinSISBkm.bkm.UrunBilgi ub      ON ub.stkID = CONVERT(int, p.Code)
WHERE s.DocumentsTypeId IN (1,3)
  AND s.Date >= '20250801' AND s.Date < '20260801'
  AND ISNUMERIC(p.Code) = 1
  AND s.Id IN (SELECT SalesId FROM EncoreMerkez.dbo.SalesPayments
               WHERE PaymentTypesId = 11 AND IsChangeAmount = 0)
GROUP BY ub.KatAna
ORDER BY Brut DESC;

/* 6b) KALIBRASYON — ayni yontem, tum perakende, Oca-2026 (FIFO %35,4 ile kiyas) */
SELECT COUNT(*) AS Satir,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice-sp.VatTotal)
                ELSE (sp.TotalPrice-sp.VatTotal) END)                        AS Net,
       SUM(CASE WHEN ub.SonAlis > 0
                THEN (CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice-sp.VatTotal)
                           ELSE (sp.TotalPrice-sp.VatTotal) END) ELSE 0 END) AS NetKapsanan,
       SUM(CASE WHEN ub.SonAlis > 0
                THEN CONVERT(decimal(19,4),
                     (CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) * ub.SonAlis)
                ELSE 0 END)                                                  AS Maliyet
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p       ON p.Id = sp.ProductsId
JOIN DerinSISBkm.bkm.UrunBilgi ub      ON ub.stkID = CONVERT(int, p.Code)
WHERE s.DocumentsTypeId IN (1,3)
  AND s.Date >= '20260101' AND s.Date < '20260201'
  AND ISNUMERIC(p.Code) = 1;

/* ---------------------------------------------------------------------------
   7) KALDIRAC (uplift) — cek dilimi x sepet · ASIL BULGU
      Kaldirac = SepetOdenen / HcOdenen. Dilim buyudukce 10,66x -> 1,14x
--------------------------------------------------------------------------- */
SELECT CASE WHEN hc.HcTutar <=  100 THEN '1) <=100'
            WHEN hc.HcTutar <=  250 THEN '2) 101-250'
            WHEN hc.HcTutar <=  500 THEN '3) 251-500'
            WHEN hc.HcTutar <= 1000 THEN '4) 501-1000'
            WHEN hc.HcTutar <= 2500 THEN '5) 1001-2500'
            ELSE '6) 2500+' END                     AS Dilim,
       COUNT(*)                                     AS Fis,
       SUM(hc.HcTutar)                              AS HcOdenen,
       SUM(s.GrossTotal - s.DiscountTotal)          AS SepetOdenen,
       SUM(s.GrossTotal)                            AS SepetBrut,
       SUM(s.DiscountTotal)                         AS SepetIndirim
FROM EncoreMerkez.dbo.Sales s
JOIN (SELECT SalesId, SUM(Amount) AS HcTutar
      FROM EncoreMerkez.dbo.SalesPayments
      WHERE PaymentTypesId = 11 AND IsChangeAmount = 0
      GROUP BY SalesId) hc ON hc.SalesId = s.Id
WHERE s.DocumentsTypeId = 1 AND s.Date >= '20250801' AND s.Date < '20260801'
GROUP BY CASE WHEN hc.HcTutar <=  100 THEN '1) <=100'
              WHEN hc.HcTutar <=  250 THEN '2) 101-250'
              WHEN hc.HcTutar <=  500 THEN '3) 251-500'
              WHEN hc.HcTutar <= 1000 THEN '4) 501-1000'
              WHEN hc.HcTutar <= 2500 THEN '5) 1001-2500'
              ELSE '6) 2500+' END
ORDER BY Dilim;

/* ---------------------------------------------------------------------------
   8) CEK ALICILARI — kurumsal/toplu talep kimden geliyor
      CustomersId=0 = anonim (kart okutmadan) -> satilan cekin ~%51'i
--------------------------------------------------------------------------- */
SELECT s.CustomersId, MAX(c.Name) AS Musteri, COUNT(DISTINCT s.Id) AS Fis,
       SUM(sp.TotalPrice) AS SatilanCek
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p       ON p.Id = sp.ProductsId
LEFT JOIN DerinCrm.dbo.Customer c      ON c.Id = s.CustomersId
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= '20250801' AND s.Date < '20260801'
  AND ISNUMERIC(p.Code) = 1
  AND CONVERT(int, p.Code) IN (SELECT u.stkID FROM DerinSISBkm.dbo.urn u
                               JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID
                               WHERE k.ktgrAd = N'Hediye Çeki')
GROUP BY s.CustomersId
ORDER BY SatilanCek DESC;


/* ===========================================================================
   v2 EKLERI — KANAL, FATURA INDIRIMI, fat5 MALIYET, GERI DONUSUM AYRIMI
=========================================================================== */

/* ---------------------------------------------------------------------------
   9) CEK SATISI TUM KANALLAR — irsHrk KANONIK (POS-only olcum ~3 kat eksik!)
      ehTip: 1 Satis(fatura) · 4 Magaza Satis · 100 POS Satis · iade 3/5/101
             88 Diger Giris = cek basimi/stok girisi (SATIS DEGIL)
             89/98 = imha / merkeze iade / kisiye hediye (bedelsiz)
--------------------------------------------------------------------------- */
SELECT h.ehTip, t.tipAD, COUNT(*) AS Satir,
       SUM(h.ehAdetN) AS Adet, SUM(h.ehTutarN) AS TutarNet
FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
JOIN DerinSISBkm.dbo.irsTip_vw t ON t.tipID = h.ehTip
WHERE h.ehTrhS >= '20250801' AND h.ehTrhS < '20260801'
  AND h.ehstkID IN (SELECT u.stkID FROM DerinSISBkm.dbo.urn u
                    JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID
                    WHERE k.ktgrAd = N'Hediye Çeki')
GROUP BY h.ehTip, t.tipAD
ORDER BY TutarNet DESC;

/* 9b) Cek SKU envanteri — hangi kupurler var, hangisi hareket gormus
      NOT: 'Hediye Çeki' kategorisinde GERI DONUSUM CEKI SKU'su YOK (tarandi). */
SELECT u.stkID, u.stkKod, u.stkAd, u.fiyatS,
       SUM(CASE WHEN h.ehTip IN (1,4,100) THEN h.ehTutarN ELSE 0 END) AS SatisNet,
       SUM(CASE WHEN h.ehTip IN (3,5,101) THEN h.ehTutarN ELSE 0 END) AS IadeNet,
       SUM(CASE WHEN h.ehTip  =  88       THEN h.ehTutarN ELSE 0 END) AS DigerGiris,
       SUM(CASE WHEN h.ehTip IN (89,98)   THEN h.ehTutarN ELSE 0 END) AS BedelsizCikis
FROM DerinSISBkm.dbo.urn u
JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID
LEFT JOIN DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
       ON h.ehstkID = u.stkID AND h.ehTrhS >= '20250801' AND h.ehTrhS < '20260801'
WHERE k.ktgrAd = N'Hediye Çeki'
GROUP BY u.stkID, u.stkKod, u.stkAd, u.fiyatS
ORDER BY SatisNet DESC;

/* 9c) Bedelsiz cikislarin NOTU — geri donusum mu, imha mi? (16 kayit tek tek okundu)
      Sonuc: imha / merkeze iade / kisiye hediye. Geri donusum DEGIL. */
SELECT h.ehTip, t.tipAD, h.ehTrhS, u.stkAd, h.ehAdetN, h.ehTutarN, h.ehMekan, i.eNot
FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
JOIN DerinSISBkm.dbo.irsTip_vw t ON t.tipID = h.ehTip
JOIN DerinSISBkm.dbo.urn u ON u.stkID = h.ehstkID
LEFT JOIN DerinSISBkm.dbo.irs i WITH(NOLOCK) ON i.eID = h.ehID
WHERE h.ehTrhS >= '20250801' AND h.ehTrhS < '20260801' AND h.ehTip IN (89,98)
  AND h.ehstkID IN (SELECT u2.stkID FROM DerinSISBkm.dbo.urn u2
                    JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u2.urnKtgr2ID
                    WHERE k.ktgrAd = N'Hediye Çeki');

/* ---------------------------------------------------------------------------
   10) FATURA KANALINDA MEVCUT INDIRIM — asil karar bulgusu
       ehTutarN = ehTutar - ehIndirim. Musteri bazinda oran KURALSIZ (%0..%15).
       ! fatAyr eTip=4 satirlarinda ehTutar/ehTutarN tutarsiz -> kanal toplami irsHrk'den
--------------------------------------------------------------------------- */
SELECT f.eFirma, c.frmAd, COUNT(DISTINCT f.eID) AS Fatura,
       SUM(ABS(fa.ehAdetN)) AS Adet, SUM(fa.ehTutar) AS Brut,
       SUM(fa.ehIndirim) AS Indirim, SUM(fa.ehTutarN) AS Net,
       CAST(100.0*SUM(fa.ehIndirim)/NULLIF(SUM(fa.ehTutar),0) AS decimal(9,2)) AS IndirimYuzde
FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON f.eID = fa.ehID
LEFT JOIN DerinSISBkm.dbo.frm c WITH(NOLOCK) ON c.frmID = f.eFirma
WHERE f.eDurum <> 2 AND f.eTip = 1
  AND f.eTarih >= '20250801' AND f.eTarih < '20260801'
  AND fa.ehStkID IN (SELECT u.stkID FROM DerinSISBkm.dbo.urn u
                     JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID
                     WHERE k.ktgrAd = N'Hediye Çeki')
GROUP BY f.eFirma, c.frmAd
ORDER BY Net DESC;

/* ---------------------------------------------------------------------------
   11) GERI DONUSUM / IADE CEKI AYRIMI — kapsam disi oldugunun KANITI
       PaymentTypesId 11 (HEDIYE CEKI) = %100 IsGiftCard=true, hic IsRefundVoucher YOK
       PaymentTypesId 10 (IADE CEKI)   = 15,1 M TL — geri donusum/iade cekleri BURADA
       compat 110 -> JSON_VALUE YOK, LIKE ile bayrak okunur
--------------------------------------------------------------------------- */
SELECT pt.PaymentTypesId,
       CASE WHEN pt.Info LIKE '%"IsRefundVoucher":true%' THEN 'IsRefundVoucher=true'
            WHEN pt.Info LIKE '%"IsGiftCard":true%'      THEN 'IsGiftCard=true'
            ELSE 'diger/bos' END AS Bayrak,
       COUNT(*) AS Hareket, SUM(pt.Amount) AS Tutar
FROM EncoreMerkez.dbo.SalesPayments pt
JOIN EncoreMerkez.dbo.Sales s ON s.Id = pt.SalesId
WHERE pt.PaymentTypesId IN (10,11) AND pt.IsChangeAmount = 0
  AND s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= '20250801' AND s.Date < '20260801'
GROUP BY pt.PaymentTypesId,
       CASE WHEN pt.Info LIKE '%"IsRefundVoucher":true%' THEN 'IsRefundVoucher=true'
            WHEN pt.Info LIKE '%"IsGiftCard":true%'      THEN 'IsGiftCard=true'
            ELSE 'diger/bos' END;

/* ---------------------------------------------------------------------------
   12) HC SEPETI MARJI — KANONIK fat5 MALIYET (blok 6'nin SonAlis surumunun YERINE)
       fat5 = son 5 alis faturasi SUM(ehTutarN)/SUM(ehAdetN), DerinSIS + ODAK UNION
       (sema/metrics.yaml -> birim_maliyet.MLYT)
       PERF: OUTER APPLY once stkID'ye AGGREGATE edilir (satir-basi fat5 = timeout riski).
             24K satir -> ~9K stkID -> canli 14,3s. Satir bazinda kosarsan 30s asar.
       Tarih cipasi: pencere sonu literal ('20260801'). Satis-tarihi-bazli cipa
             (f.eTarih <= satis tarihi) daha dogru ama korelasyon maliyeti yuksek.
--------------------------------------------------------------------------- */
SELECT ub.KatAna,
       SUM(agg.Satir)   AS Satir,
       SUM(agg.Adet)    AS Adet,
       SUM(agg.Brut)    AS Brut,
       SUM(agg.Indirim) AS Indirim,
       SUM(agg.Net)     AS Net,
       SUM(CASE WHEN MLYT.MALIYET > 0 THEN agg.Net ELSE 0 END) AS NetKapsanan,
       SUM(CASE WHEN MLYT.MALIYET > 0
                THEN CONVERT(decimal(19,4), agg.Adet * MLYT.MALIYET) ELSE 0 END) AS Maliyet
FROM (
    SELECT CONVERT(int, p.Code) AS stkID, COUNT(*) AS Satir,
           SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) AS Adet,
           SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice+sp.DiscountTotalDirect)
                    ELSE (sp.TotalPrice+sp.DiscountTotalDirect) END)             AS Brut,
           SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.DiscountTotalDirect
                    ELSE sp.DiscountTotalDirect END)                             AS Indirim,
           SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice-sp.VatTotal)
                    ELSE (sp.TotalPrice-sp.VatTotal) END)                        AS Net
    FROM EncoreMerkez.dbo.Sales s
    JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
    JOIN EncoreMerkez.dbo.Products p       ON p.Id = sp.ProductsId
    WHERE s.DocumentsTypeId IN (1,3)
      AND s.Date >= '20250801' AND s.Date < '20260801'
      AND ISNUMERIC(p.Code) = 1
      AND s.Id IN (SELECT SalesId FROM EncoreMerkez.dbo.SalesPayments
                   WHERE PaymentTypesId = 11 AND IsChangeAmount = 0)
    GROUP BY CONVERT(int, p.Code)
) agg
JOIN DerinSISBkm.bkm.UrunBilgi ub ON ub.stkID = agg.stkID
OUTER APPLY (
    SELECT CONVERT(money, SUM(b.tutar)/NULLIF(SUM(b.adet),0)) AS MALIYET
    FROM (
        SELECT TOP 5 ML.adet, ML.tutar
        FROM (
            SELECT TOP 5 f.eTarih AS trh, fa.ehAdetN AS adet, fa.ehTutarN AS tutar
            FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK)
                 ON fa.ehID = f.eID AND f.eTip = 0 AND f.eDurum <> 2
                AND f.eTarih < '20260801'
                AND (f.eFirma <> 9525 OR f.eTarih >= '20220901')
            WHERE fa.ehStkID = agg.stkID AND fa.ehAdetN <> 0
            ORDER BY f.eTarih DESC
            UNION ALL
            SELECT TOP 5 o.TARIH, o.ADET, o.NET * o.ADET
            FROM BKMDATA..ODAK_FATURA o WITH(NOLOCK)
            WHERE o.STKID = agg.stkID AND o.TARIH < '20260801' AND o.ADET <> 0
            ORDER BY o.TARIH DESC
        ) ML
        ORDER BY ML.trh DESC
    ) b
    HAVING SUM(b.adet) <> 0
) MLYT
GROUP BY ub.KatAna
ORDER BY Brut DESC;


/* ===========================================================================
   v3 EKLERI — fatAyr eTip=4 TUTARSIZLIGI + GERI DONUSUM AYIKLAMASI
=========================================================================== */

/* ---------------------------------------------------------------------------
   13) fatAyr eTip=4 (Magaza Satis) -> ehTutarN BESLENMIYOR (genel tuzak, cek-ozel DEGIL)
       (a) tip kiyasi: eTip=4'te net=0 orani %79,9; diger tiplerde <=%0,28
       (b) yil kiyasi: 2023 %65,4 -> 2026 %76,8 (sistematik + kotulesiyor)
       KURAL: eTip=4'te ehTutarN KULLANMA. irsHrk (ehTip=4) veya ehTutar-ehIndirim kullan.
--------------------------------------------------------------------------- */
SELECT f.eTip, COUNT(*) AS Satir,
       SUM(fa.ehTutar) AS Brut, SUM(fa.ehIndirim) AS Indirim, SUM(fa.ehTutarN) AS Net,
       SUM(CASE WHEN fa.ehTutarN = 0 AND fa.ehTutar <> 0 THEN 1 ELSE 0 END) AS NetSifirSatir,
       CAST(100.0*SUM(CASE WHEN fa.ehTutarN = 0 AND fa.ehTutar <> 0 THEN 1 ELSE 0 END)
            / COUNT(*) AS decimal(9,2)) AS NetSifirYuzde
FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON f.eID = fa.ehID
WHERE f.eDurum <> 2 AND f.eTarih >= '20260101' AND f.eTarih < '20260201'
GROUP BY f.eTip
ORDER BY f.eTip;

SELECT YEAR(f.eTarih) AS Yil, COUNT(*) AS Satir,
       SUM(fa.ehTutar) AS Brut, SUM(fa.ehIndirim) AS Indirim, SUM(fa.ehTutarN) AS Net,
       SUM(CASE WHEN fa.ehTutarN = 0 AND fa.ehTutar <> 0 THEN 1 ELSE 0 END) AS NetSifirSatir,
       CAST(100.0*SUM(CASE WHEN fa.ehTutarN = 0 AND fa.ehTutar <> 0 THEN 1 ELSE 0 END)
            / COUNT(*) AS decimal(9,2)) AS NetSifirYuzde
FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON f.eID = fa.ehID
WHERE f.eDurum <> 2 AND f.eTip = 4 AND f.eTarih >= '20230101'
GROUP BY YEAR(f.eTarih)
ORDER BY Yil;

/* 13c) Satir detayi — ehTutar dolu, ehIndirim 0, ehTutarN 0 (hediye ceki ornegi) */
SELECT f.eID, f.eTip, f.eTarih, f.eFirma, c.frmAd, fa.ehstkID, u.stkAd,
       fa.ehAdetN, fa.ehTutar, fa.ehIndirim, fa.ehTutarN, fa.ehKDV
FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON f.eID = fa.ehID
JOIN DerinSISBkm.dbo.urn u ON u.stkID = fa.ehstkID
LEFT JOIN DerinSISBkm.dbo.frm c WITH(NOLOCK) ON c.frmID = f.eFirma
WHERE f.eDurum <> 2 AND f.eTip = 4
  AND f.eTarih >= '20250801' AND f.eTarih < '20260801'
  AND fa.ehstkID IN (SELECT u2.stkID FROM DerinSISBkm.dbo.urn u2
                     JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u2.urnKtgr2ID
                     WHERE k.ktgrAd = N'Hediye Çeki')
ORDER BY f.eTarih;

/* ---------------------------------------------------------------------------
   14) GERI DONUSUM CEKLERI — kasada IADE SEBEBI olarak isliyor, HEDIYE CEKI DEGIL
       (a) sebep katalogu: RefundReasons.Id=12 'Geri Dönüşüm' (Type=0 iade sebebi)
           Type 0 = iade sebebi · Type 1 = indirim sebebi
       (b) hacim: sebep bazli · (c) urun: stkID 583160
       (d) karsiliginda verilen cek = IADE CEKI (tip 10), tip 11'de HIC YOK
--------------------------------------------------------------------------- */
SELECT Id, Name, Type, Created FROM EncoreMerkez.dbo.RefundReasons WHERE IsDeleted = 0 ORDER BY Type, Id;

SELECT sp.RefundReasonId, r.Name AS Sebep, s.DocumentsTypeId,
       COUNT(*) AS Satir, COUNT(DISTINCT s.Id) AS Fis,
       SUM(sp.Amount) AS Adet, SUM(sp.TotalPrice) AS Tutar
FROM EncoreMerkez.dbo.SalesProducts sp
JOIN EncoreMerkez.dbo.Sales s ON s.Id = sp.SalesId
LEFT JOIN EncoreMerkez.dbo.RefundReasons r ON r.Id = sp.RefundReasonId
WHERE sp.IsValid = 1 AND sp.RefundReasonId <> 0
  AND s.Date >= '20250801' AND s.Date < '20260801'
GROUP BY sp.RefundReasonId, r.Name, s.DocumentsTypeId
ORDER BY Tutar DESC;

/* 14c) Geri donusum URUNU + yanlis-sebep vakalari
       stkID 583160 = 'Geri Dönüşüm Kağıt Madde Alımı' (KatAna 'Tanımsız', Kategori3 'Genel')
       ! SKU 416 satirda YANLIS sebep koduyla (4/5/1/2), 12 satirda DocType=1 ile gecmis
       -> AYIKLAMA IKI KOSULLU: RefundReasonId <> 12 AND Products.Code <> '583160' */
SELECT CASE WHEN hc.SalesId IS NULL THEN 'Normal' ELSE 'HediyeCekli' END AS Grup,
       s.DocumentsTypeId, sp.RefundReasonId,
       COUNT(*) AS Satir, SUM(sp.Amount) AS Adet, SUM(sp.TotalPrice) AS Tutar
FROM EncoreMerkez.dbo.SalesProducts sp
JOIN EncoreMerkez.dbo.Sales s ON s.Id = sp.SalesId
JOIN EncoreMerkez.dbo.Products p ON p.Id = sp.ProductsId
LEFT JOIN (SELECT DISTINCT SalesId FROM EncoreMerkez.dbo.SalesPayments
           WHERE PaymentTypesId = 11 AND IsChangeAmount = 0) hc ON hc.SalesId = s.Id
WHERE sp.IsValid = 1 AND p.Code = '583160'
  AND s.Date >= '20250801' AND s.Date < '20260801'
GROUP BY CASE WHEN hc.SalesId IS NULL THEN 'Normal' ELSE 'HediyeCekli' END,
         s.DocumentsTypeId, sp.RefundReasonId;

/* 14d) Geri donusum fislerinin ODEME TIPI — cek IADE CEKI (10) olarak veriliyor */
SELECT pt.PaymentTypesId, ptn.Name AS OdemeTipi, COUNT(*) AS Hareket, SUM(pt.Amount) AS Tutar
FROM EncoreMerkez.dbo.SalesPayments pt
JOIN EncoreMerkez.dbo.PaymentTypes ptn ON ptn.Id = pt.PaymentTypesId
WHERE pt.IsChangeAmount = 0
  AND pt.SalesId IN (SELECT sp.SalesId FROM EncoreMerkez.dbo.SalesProducts sp
                     JOIN EncoreMerkez.dbo.Sales s ON s.Id = sp.SalesId
                     WHERE sp.IsValid = 1 AND sp.RefundReasonId = 12
                       AND s.Date >= '20250801' AND s.Date < '20260801')
GROUP BY pt.PaymentTypesId, ptn.Name
ORDER BY Tutar DESC;

/* ---------------------------------------------------------------------------
   15) INDIRIM ORANI KIYASI — GERI DONUSUM AYIKLANMIS (blok 5'in DUZELTILMIS hali)
       Sonuc: HC %18,07 · Normal %18,74 (once %18,08 / %18,83)
              sepet brut/fis 1.620,9 vs 797,6 = 2,03x
       Satir bazli (Sales ustu toplam yerine) — cunku ayiklama SATIR seviyesinde
--------------------------------------------------------------------------- */
SELECT CASE WHEN hc.SalesId IS NULL THEN 'Normal' ELSE 'HediyeCekli' END AS Grup,
       COUNT(DISTINCT s.Id) AS Fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice+sp.DiscountTotalDirect)
                ELSE (sp.TotalPrice+sp.DiscountTotalDirect) END) AS Brut,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.DiscountTotalDirect
                ELSE sp.DiscountTotalDirect END)                 AS Indirim,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice-sp.VatTotal)
                ELSE (sp.TotalPrice-sp.VatTotal) END)            AS Net
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p ON p.Id = sp.ProductsId
LEFT JOIN (SELECT DISTINCT SalesId FROM EncoreMerkez.dbo.SalesPayments
           WHERE PaymentTypesId = 11 AND IsChangeAmount = 0) hc ON hc.SalesId = s.Id
WHERE s.DocumentsTypeId IN (1,3)
  AND s.Date >= '20250801' AND s.Date < '20260801'
  AND sp.RefundReasonId <> 12          -- geri donusum sebebi
  AND p.Code <> '583160'               -- geri donusum urunu (yanlis-sebep vakalari)
GROUP BY CASE WHEN hc.SalesId IS NULL THEN 'Normal' ELSE 'HediyeCekli' END;


/* ===========================================================================
   v4 EKLERI — BAREMLI KARLILIK + MUSTERI GRUP KONSOLIDASYONU
=========================================================================== */

/* ---------------------------------------------------------------------------
   16) BAREMLI KARLILIK — cek dilimi x kategori net (marj disaridan uygulanir)
       Neden iki adim: dilim x stkID uzerinde fat5 OUTER APPLY MCP'de 30s ASTI
       (~9K stkID x 6 dilim = 54K APPLY). Cozum: dilim x KATEGORI net cek,
       kategori fat5 marjini (blok 12) disarida uygula (kategori-ici mix farki ihmal).
       Tam dogru surum icin sqlcli/SSMS'te blok 12'yi dilim kirilimiyla kos.
--------------------------------------------------------------------------- */
SELECT CASE WHEN hc.HcTutar <=  100 THEN '1) <=100'
            WHEN hc.HcTutar <=  250 THEN '2) 101-250'
            WHEN hc.HcTutar <=  500 THEN '3) 251-500'
            WHEN hc.HcTutar <= 1000 THEN '4) 501-1000'
            WHEN hc.HcTutar <= 2500 THEN '5) 1001-2500'
            ELSE '6) 2500+' END AS Dilim,
       ub.KatAna,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice+sp.DiscountTotalDirect)
                ELSE (sp.TotalPrice+sp.DiscountTotalDirect) END) AS Brut,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.DiscountTotalDirect
                ELSE sp.DiscountTotalDirect END)                 AS Indirim,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice-sp.VatTotal)
                ELSE (sp.TotalPrice-sp.VatTotal) END)            AS Net
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p       ON p.Id = sp.ProductsId
JOIN DerinSISBkm.bkm.UrunBilgi ub      ON ub.stkID = CONVERT(int, p.Code)
JOIN (SELECT SalesId, SUM(Amount) AS HcTutar
      FROM EncoreMerkez.dbo.SalesPayments
      WHERE PaymentTypesId = 11 AND IsChangeAmount = 0
      GROUP BY SalesId) hc ON hc.SalesId = s.Id
WHERE s.DocumentsTypeId IN (1,3)
  AND s.Date >= '20250801' AND s.Date < '20260801'
  AND ISNUMERIC(p.Code) = 1
  AND sp.RefundReasonId <> 12 AND p.Code <> '583160'   -- geri donusum haric
  AND ub.KatAna <> N'Hediye Çeki'                      -- avans, stok degil
GROUP BY CASE WHEN hc.HcTutar <=  100 THEN '1) <=100'
              WHEN hc.HcTutar <=  250 THEN '2) 101-250'
              WHEN hc.HcTutar <=  500 THEN '3) 251-500'
              WHEN hc.HcTutar <= 1000 THEN '4) 501-1000'
              WHEN hc.HcTutar <= 2500 THEN '5) 1001-2500'
              ELSE '6) 2500+' END, ub.KatAna
ORDER BY Dilim, Net DESC;

/* 16b) Barem paydasi — fis / cek / sepet (kaldirac ve kar/fis icin) */
SELECT CASE WHEN hc.HcTutar <=  100 THEN '1) <=100'
            WHEN hc.HcTutar <=  250 THEN '2) 101-250'
            WHEN hc.HcTutar <=  500 THEN '3) 251-500'
            WHEN hc.HcTutar <= 1000 THEN '4) 501-1000'
            WHEN hc.HcTutar <= 2500 THEN '5) 1001-2500'
            ELSE '6) 2500+' END AS Dilim,
       COUNT(*) AS Fis, SUM(hc.HcTutar) AS HcOdenen, AVG(hc.HcTutar) AS OrtCek,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-s.DiscountTotal)
                ELSE (s.GrossTotal-s.DiscountTotal) END) AS SepetOdenen
FROM EncoreMerkez.dbo.Sales s
JOIN (SELECT SalesId, SUM(Amount) AS HcTutar
      FROM EncoreMerkez.dbo.SalesPayments
      WHERE PaymentTypesId = 11 AND IsChangeAmount = 0
      GROUP BY SalesId) hc ON hc.SalesId = s.Id
WHERE s.DocumentsTypeId IN (1,3) AND s.Date >= '20250801' AND s.Date < '20260801'
GROUP BY CASE WHEN hc.HcTutar <=  100 THEN '1) <=100'
              WHEN hc.HcTutar <=  250 THEN '2) 101-250'
              WHEN hc.HcTutar <=  500 THEN '3) 251-500'
              WHEN hc.HcTutar <= 1000 THEN '4) 501-1000'
              WHEN hc.HcTutar <= 2500 THEN '5) 1001-2500'
              ELSE '6) 2500+' END
ORDER BY Dilim;

/* ---------------------------------------------------------------------------
   17) MUSTERI GRUP KONSOLIDASYONU — ERP'de grup alani BOS
       frmBagID / frmGrup1..5 hepsinde 0 -> grup elle kurulur.
       Grup kaniti = ORTAK ADRES (+ kullanici teyidi). VN oneki KANIT DEGIL.
--------------------------------------------------------------------------- */
SELECT c.frmID, c.frmAd, c.frmBagID, c.frmGrup1, c.frmGrup2,
       c.VN, c.VD, c.adres1, c.tel1, c.telMobil, c.frmEposta
FROM DerinSISBkm.dbo.frm c WITH(NOLOCK)
WHERE c.frmID IN (24922, 56291, 56292)   -- INALLAR OTOMOTIV / INALLAR SIGORTA / GONYE OTOMOTIV
   OR c.frmID IN (44715, 61926)          -- CETIN ELEKTRIK / CETIN PROJE (teyit bekliyor)
   OR c.frmID IN (56, 171);              -- BURSA KULTUR MERKEZI / ASIYE BINGOLBALI (ayni is merkezi)


/* ---------------------------------------------------------------------------
   18) BASILI KUPUR vs KISMI BAKIYE — bonus tasariminin dayanagi
       Barem'i yuvarlak/kusurlu tutara gore ikiye ayirir.
       KRITIK: barem-1'in yuksek kaldiraci (10,66x) agirlikli olarak KISMI BAKIYE
       artigindan gelir (247 fis kusurlu / 28 fis yuvarlak) -> tasarimla URETILEMEZ.
       Bonus programi BASILI kupur ihrac eder -> gecerli oran YUVARLAK satirlar.
--------------------------------------------------------------------------- */
SELECT CASE WHEN hc.HcTutar <=  100 THEN '1) <=100'
            WHEN hc.HcTutar <=  250 THEN '2) 101-250'
            WHEN hc.HcTutar <=  500 THEN '3) 251-500'
            WHEN hc.HcTutar <= 1000 THEN '4) 501-1000'
            WHEN hc.HcTutar <= 2500 THEN '5) 1001-2500'
            ELSE '6) 2500+' END AS Dilim,
       CASE WHEN hc.HcTutar % 50 = 0 THEN 'Yuvarlak (basili kupur)'
            ELSE 'Kusurlu (kismi bakiye)' END AS TutarTipi,
       COUNT(*) AS Fis, SUM(hc.HcTutar) AS HcOdenen, AVG(hc.HcTutar) AS OrtCek,
       SUM(s.GrossTotal - s.DiscountTotal) AS SepetOdenen
FROM EncoreMerkez.dbo.Sales s
JOIN (SELECT SalesId, SUM(Amount) AS HcTutar
      FROM EncoreMerkez.dbo.SalesPayments
      WHERE PaymentTypesId = 11 AND IsChangeAmount = 0
      GROUP BY SalesId) hc ON hc.SalesId = s.Id
WHERE s.DocumentsTypeId = 1 AND s.Date >= '20250801' AND s.Date < '20260801'
GROUP BY CASE WHEN hc.HcTutar <=  100 THEN '1) <=100'
              WHEN hc.HcTutar <=  250 THEN '2) 101-250'
              WHEN hc.HcTutar <=  500 THEN '3) 251-500'
              WHEN hc.HcTutar <= 1000 THEN '4) 501-1000'
              WHEN hc.HcTutar <= 2500 THEN '5) 1001-2500'
              ELSE '6) 2500+' END,
         CASE WHEN hc.HcTutar % 50 = 0 THEN 'Yuvarlak (basili kupur)'
              ELSE 'Kusurlu (kismi bakiye)' END
ORDER BY Dilim, TutarTipi;

/* 18b) INDIRIM vs BONUS formulleri (SQL degil, hesap notu — tekrar uretilebilirlik icin)
   r  = o kupurun 1 TL cek yuzu basina brut kari = kaldirac x 0,917 x marj
   A) Indirim x, 1 TL NAKIT basina brut kar = (r - x) / (1 - x)
   B) Bonus  b, 1 TL NAKIT basina brut kar = r_ana + b x (r_bonus - 1)
      (bonus ayni kupurde ise r_bonus = r_ana -> B = r + b(r-1); b = x/(1-x) icin A = B)
   Musteri esdegerligi: b = x/(1-x)   ·   tersi: x = b/(1+b)
   r_bonus > 1 ise bonus arttikca kar ARTAR (kirilma yok) — 50/100 TL kupurde r = 1,228.
*/
