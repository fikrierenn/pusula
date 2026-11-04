/* ============================================================================
   KIRTASİYE SEPET BÜYÜKLÜĞÜ ANALİZİ — 2025 vs 2026 (GEÇEN YIL / BU YIL)
   Tarih: 01.10.2026
   DB: EncoreMerkez + DerinSISBkm (profil: erp)

   KAPSAM VE METODOLOJİ:
   - Perakende satış fiş/faturaları: `s.DocumentsTypeId IN (1, 2, 6, 7)` ve `sp.IsValid = 1`.
     (İade `3` ortalamayı bozmaması için hariç; Sınav Okulları `8` kurumsal fatura olduğu için hariç.)
   - Ürün → Kategori köprüsü: `EncoreMerkez.Products.Code = DerinSISBkm.dbo.urn.stkID`
     (`ISNUMERIC(p.Code)=1` guard) → `dbo.urnKtgr2.ktgrAd = N'Kırtasiye'`.
   - POS Geçiş Sınırı (ÖLÇÜLDÜ): `EncoreMerkez` verisi Temmuz 2025 ortasında (11–22 Temmuz)
     devreye girdi; 01.01–31.05.2025 eski kasa (`INTER_BOS`), 01.06–10.07.2025 ~40 günlük geçiş
     boşluğu. Bu nedenle aynı sistem üzerinde birebir (elma-elma) karşılaştırma:
     1) **Ağustos–Eylül (Okul Sezonu)** — iki yılda da %100 tam veri
     2) **23–31 Temmuz (Eş Günler)** — her üç mağazanın da yeni kasada tam olduğu ortak Temmuz günleri
     3) **Temmuz 2025 – Eylül 2026 (15 Aylık Seri)** — aylık sepet evrimi
   ============================================================================ */

/* ── 1) DÖNEM BAZLI BİREBİR (ELMA-ELMA) KARŞILAŞTIRMA (2025 vs 2026) ────────── */
WITH fis AS (
    SELECT
        s.Id AS SalesId,
        CAST(s.Date AS date) AS Tarih,
        YEAR(s.Date) AS Yil,
        MONTH(s.Date) AS Ay,
        s.StoresId,
        COUNT(*) AS ToplamCesit,
        SUM(sp.Amount) AS ToplamAdet,
        SUM(sp.TotalPrice + sp.DiscountTotalDirect) AS ToplamBrut,
        SUM(sp.TotalPrice) AS ToplamNetDahil,
        SUM(sp.TotalPrice - sp.VatTotal) AS ToplamNetHaric,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' THEN 1 ELSE 0 END) AS KirtCesit,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' THEN sp.Amount ELSE 0 END) AS KirtAdet,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' THEN (sp.TotalPrice + sp.DiscountTotalDirect) ELSE 0 END) AS KirtBrut,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' THEN sp.TotalPrice ELSE 0 END) AS KirtNetDahil,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' THEN (sp.TotalPrice - sp.VatTotal) ELSE 0 END) AS KirtNetHaric,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' THEN sp.DiscountTotalDirect ELSE 0 END) AS KirtIndirim
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id
    JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
    LEFT JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CASE WHEN ISNUMERIC(p.Code)=1 THEN CONVERT(int, p.Code) END
    LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
    WHERE sp.IsValid = 1
      AND s.DocumentsTypeId IN (1, 2, 6, 7)
      AND ((s.Date >= CONVERT(date, '23.07.2025', 104) AND s.Date < CONVERT(date, '01.10.2025', 104))
        OR (s.Date >= CONVERT(date, '23.07.2026', 104) AND s.Date < CONVERT(date, '01.10.2026', 104)))
    GROUP BY s.Id, CAST(s.Date AS date), YEAR(s.Date), MONTH(s.Date), s.StoresId
)
SELECT
    Donem, Yil,
    COUNT(*) AS TopFis,
    SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END) AS KirtFis,
    CAST(100.0*SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END)/COUNT(*) AS decimal(10,1)) AS KirtPen,
    CAST(SUM(KirtAdet)*1.0/NULLIF(SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,2)) AS KirtAdet_Fis,
    CAST(SUM(KirtCesit)*1.0/NULLIF(SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,2)) AS KirtCesit_Fis,
    CAST(SUM(KirtBrut)*1.0/NULLIF(SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,1)) AS KirtBrut_Fis,
    CAST(SUM(KirtNetDahil)*1.0/NULLIF(SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,1)) AS KirtNetDahil_Fis,
    CAST(SUM(KirtNetHaric)*1.0/NULLIF(SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,1)) AS KirtNetHaric_Fis,
    CAST(SUM(KirtNetDahil)*1.0/NULLIF(SUM(KirtAdet),0) AS decimal(10,1)) AS KirtBrmDahil,
    CAST(100.0*SUM(KirtIndirim)/NULLIF(SUM(KirtBrut),0) AS decimal(10,1)) AS IndYuzde,
    CAST(SUM(CASE WHEN KirtAdet>0 THEN ToplamAdet ELSE 0 END)*1.0/NULLIF(SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,2)) AS TumAdet_KirtFis,
    CAST(SUM(CASE WHEN KirtAdet>0 THEN ToplamNetDahil ELSE 0 END)*1.0/NULLIF(SUM(CASE WHEN KirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,1)) AS TumNetDahil_KirtFis,
    CAST(SUM(CASE WHEN KirtAdet=0 THEN ToplamAdet ELSE 0 END)*1.0/NULLIF(SUM(CASE WHEN KirtAdet=0 THEN 1 ELSE 0 END),0) AS decimal(10,2)) AS TumAdet_KirtsizFis,
    CAST(SUM(CASE WHEN KirtAdet=0 THEN ToplamNetDahil ELSE 0 END)*1.0/NULLIF(SUM(CASE WHEN KirtAdet=0 THEN 1 ELSE 0 END),0) AS decimal(10,1)) AS TumNetDahil_KirtsizFis
FROM (
    SELECT *, N'1_Agu_Eyl_Sezon' AS Donem FROM fis WHERE Ay IN (8,9)
    UNION ALL
    SELECT *, N'2_Agustos' AS Donem FROM fis WHERE Ay=8
    UNION ALL
    SELECT *, N'3_Eylul' AS Donem FROM fis WHERE Ay=9
    UNION ALL
    SELECT *, N'4_Temmuz_23_31' AS Donem FROM fis WHERE Ay=7
) x
GROUP BY Donem, Yil
ORDER BY Donem, Yil;

/* ÖLÇÜM SONUÇLARI (01.10.2026):
   Dönem               Yıl   TopFiş   KırtFiş  Pen%  KırtAd/Fiş  KırtÇeş/Fiş  Brüt₺/Fiş  NetDahil₺/Fiş  NetHariç₺/Fiş  Birim₺  İnd%   TümSepet(Kırtlı)     TümSepet(Kırtsız)
   1_Agu_Eyl_Sezon     2025  188.720   97.325  51,6%    6,08        4,61       651,3 ₺       567,9 ₺        494,6 ₺      93,3 ₺  12,8%   9,31 ad / 1.074,7 ₺  3,54 ad / 710,1 ₺
   1_Agu_Eyl_Sezon     2026  204.212  116.512  57,1%    6,26        4,83       858,8 ₺       690,9 ₺        600,6 ₺     110,4 ₺  19,5%   9,72 ad / 1.402,5 ₺  3,25 ad / 734,4 ₺
   2_Agustos           2025   68.970   32.968  47,8%    5,28        3,86       565,6 ₺       505,7 ₺        439,8 ₺      95,9 ₺  10,6%   8,14 ad /   906,1 ₺  3,36 ad / 623,1 ₺
   2_Agustos           2026   80.322   40.611  50,6%    4,55        3,42       643,1 ₺       493,0 ₺        427,4 ₺     108,4 ₺  23,3%   7,92 ad / 1.115,8 ₺  3,09 ad / 610,2 ₺
   3_Eylul             2025  119.750   64.357  53,7%    6,50        4,99       695,3 ₺       599,8 ₺        522,7 ₺      92,3 ₺  13,7%   9,91 ad / 1.161,1 ₺  3,65 ad / 766,7 ₺
   3_Eylul             2026  123.890   75.901  61,3%    7,17        5,58       974,2 ₺       796,8 ₺        693,2 ₺     111,1 ₺  18,2%  10,68 ad / 1.555,9 ₺  3,39 ad / 837,2 ₺
   4_Temmuz_23_31      2025   15.775    5.977  37,9%    3,34        2,48       277,5 ₺       256,8 ₺        220,4 ₺      76,9 ₺   7,5%   6,31 ad /   618,5 ₺  3,29 ad / 533,0 ₺
   4_Temmuz_23_31      2026   21.904    8.798  40,2%    3,54        2,63       399,5 ₺       328,5 ₺        280,9 ₺      92,8 ₺  17,8%   6,89 ad /   860,8 ₺  3,47 ad / 671,0 ₺
*/

/* ── 2) MAĞAZA KIRILIMI (Ağustos–Eylül 2025 vs 2026) ─────────────────────────
   Mağaza        Yıl   TopFiş   KırtFiş  Pen%   KırtAd/Fiş  KırtÇeş/Fiş  KırtNetDahil₺  KırtNetHariç₺  Birim₺   TümSepetAd  TümSepetNet₺
   FSM Mağaza    2025  66.195   32.290   48,8%     5,35        4,03         466,5 ₺        405,6 ₺      87,1 ₺      8,16        895,3 ₺
   FSM Mağaza    2026  69.522   38.279   55,1%     5,49        4,27         566,5 ₺        491,8 ₺     103,1 ₺      8,52      1.222,6 ₺
   IST YOLU MGZ  2025  46.070   24.929   54,1%     7,22        5,48         693,1 ₺        605,1 ₺      96,0 ₺     10,78      1.300,6 ₺
   IST YOLU MGZ  2026  54.058   29.947   55,4%     7,33        5,56         859,2 ₺        747,7 ₺     117,2 ₺     11,08      1.597,8 ₺
   ÖZLÜCE        2025  76.455   40.106   52,5%     5,96        4,53         571,7 ₺        497,5 ₺      95,9 ₺      9,32      1.078,8 ₺
   ÖZLÜCE        2026  80.632   48.286   59,9%     6,20        4,81         685,2 ₺        595,5 ₺     110,5 ₺      9,83      1.424,0 ₺
*/

/* ── 3) SEPET ADET DAĞILIM KOVALARI (Ağustos–Eylül 2025 vs 2026) ─────────────
   Kova           Fiş 2025   Fiş 2026   Fiş Δ%   Pay25   Pay26   TopAdet25  TopAdet26   OrtNet₺25   OrtNet₺26
   1) 1 Adet        28.666     35.791   +24,9%   29,5%   30,7%      28.666     35.791     158,9 ₺     151,9 ₺
   2) 2-3 Adet      28.247     32.139   +13,8%   29,0%   27,6%      67.249     76.618     270,9 ₺     343,5 ₺
   3) 4-5 Adet      13.196     15.257   +15,6%   13,6%   13,1%      58.330     67.478     430,1 ₺     523,8 ₺
   4) 6-10 Adet     13.240     15.690   +18,5%   13,6%   13,5%      99.959    118.626     697,3 ₺     833,3 ₺
   5) 11-20 Adet     7.849      9.702   +23,6%    8,1%    8,3%     113.741    141.068   1.290,8 ₺   1.533,1 ₺
   6) 21+ Adet       6.127      7.933   +29,5%    6,3%    6,8%     224.204    289.638   2.941,9 ₺   3.539,9 ₺
   TOPLAM           97.325    116.512   +19,7%  100,0%  100,0%     592.149    729.219     567,9 ₺     690,9 ₺
*/

/* ── 4) KAMPANYA KIRILIMI (Ağustos–Eylül 2025 vs 2026 — Kırtasiyeli Fişler) ──
   Kampanya Grubu   Yıl   KırtFiş  FişPay%  KırtAd/Fiş  TümAd/Fiş  KırtNet₺/Fiş  TümNet₺/Fiş  Kırtİnd%
   3 Al 2 Öde       2025   20.434   21,0%      5,72       13,30       510,7 ₺      1.850,7 ₺    11,9%
   3 Al 2 Öde       2026   29.019   24,9%      5,37       12,96       540,4 ₺      2.296,8 ₺    19,2%
   Diğer Kampanya   2025   46.182   47,5%      7,78       10,42       744,2 ₺      1.097,0 ₺    16,3%
   Diğer Kampanya   2026   62.056   53,3%      8,00       10,53       904,8 ₺      1.351,1 ₺    22,0%
   Kampanyasız      2025   30.709   31,6%      3,78        4,99       340,9 ₺        525,0 ₺     0,0%
   Kampanyasız      2026   25.437   21,8%      3,03        4,03       340,8 ₺        507,8 ₺     0,0%
*/


/* ============================================================================
   EK BÖLÜM: 5 ŞAŞIRTICI BULGU (FORENSIC / CFO DRILL-DOWN) — 08.10.2026
   ============================================================================ */

/* ── 5) ★ 1 KURUŞLUK HEDİYE OYUN HAMURU İLLÜZYONU (stkID=1733557 ve 584270..78) ──
   05.08.2026'dan itibaren kasada 0,01 ₺'ye (1 kuruş) verilen "LETS Tek Renk Oyun
   Hamuru 110 gr" (stkID=1733557, 29.097 fiş) urnKtgr2='Kırtasiye' altında olduğu için,
   hiç kırtasiye almayıp sadece kitap alan 9.277 fişi "1 adetlik 0,01 ₺'lik kırtasiye
   fişi" gibi göstermiş ve sepet ortalamasını aşağı çekmiştir! */
WITH fis AS (
    SELECT
        s.Id AS SalesId, YEAR(s.Date) AS Yil, MONTH(s.Date) AS Ay,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' THEN sp.Amount ELSE 0 END) AS HamKirtAdet,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' THEN sp.TotalPrice ELSE 0 END) AS HamKirtNetTL,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye'
                  AND u.stkID NOT IN (1733557,584270,584272,584273,584274,584275,584276,584277,584278)
                  AND (sp.TotalPrice/NULLIF(sp.Amount,0)) >= 1.0 THEN sp.Amount ELSE 0 END) AS GercekKirtAdet,
        SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye'
                  AND u.stkID NOT IN (1733557,584270,584272,584273,584274,584275,584276,584277,584278)
                  AND (sp.TotalPrice/NULLIF(sp.Amount,0)) >= 1.0 THEN sp.TotalPrice ELSE 0 END) AS GercekKirtNetTL
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id
    JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
    LEFT JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CASE WHEN ISNUMERIC(p.Code)=1 THEN CONVERT(int, p.Code) END
    LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
    WHERE sp.IsValid = 1 AND s.DocumentsTypeId IN (1, 2, 6, 7)
      AND ((s.Date >= CONVERT(date, '01.08.2025', 104) AND s.Date < CONVERT(date, '01.10.2025', 104))
        OR (s.Date >= CONVERT(date, '01.08.2026', 104) AND s.Date < CONVERT(date, '01.10.2026', 104)))
    GROUP BY s.Id, YEAR(s.Date), MONTH(s.Date)
)
SELECT Donem, Yil, COUNT(*) AS TopFis,
       SUM(CASE WHEN HamKirtAdet>0 THEN 1 ELSE 0 END) AS HamKirtFis,
       SUM(CASE WHEN GercekKirtAdet>0 THEN 1 ELSE 0 END) AS GercekKirtFis,
       SUM(CASE WHEN HamKirtAdet>0 AND GercekKirtAdet=0 THEN 1 ELSE 0 END) AS SahteKirtFis_SadeceHamur,
       CAST(SUM(HamKirtAdet)*1.0/NULLIF(SUM(CASE WHEN HamKirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,2)) AS HamAdet_Fis,
       CAST(SUM(GercekKirtAdet)*1.0/NULLIF(SUM(CASE WHEN GercekKirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,2)) AS GercekAdet_Fis,
       CAST(SUM(HamKirtNetTL)*1.0/NULLIF(SUM(CASE WHEN HamKirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,1)) AS HamNetTL_Fis,
       CAST(SUM(GercekKirtNetTL)*1.0/NULLIF(SUM(CASE WHEN GercekKirtAdet>0 THEN 1 ELSE 0 END),0) AS decimal(10,1)) AS GercekNetTL_Fis
FROM (
    SELECT *, N'1_Agu_Eyl_Sezon' AS Donem FROM fis
    UNION ALL SELECT *, N'2_Agustos' AS Donem FROM fis WHERE Ay=8
    UNION ALL SELECT *, N'3_Eylul' AS Donem FROM fis WHERE Ay=9
) x
GROUP BY Donem, Yil ORDER BY Donem, Yil;
/* ÖLÇÜM:
   - Ağu-Eyl 2026: 9.277 fişte gerçek kırtasiye YOK (sadece 1 kuruşluk oyun hamuru var!).
   - Arındırılınca Ağu-Eyl sepet adedi 6,11 → 6,52 (+%6,7, ham +%3,0'ün iki katı!),
     net kırtasiye sepeti 572,7 ₺ → 750,3 ₺ (+%31,0!).
   - Ağustos 2026: Ham veride 505,6 ₺ → 492,9 ₺ (−%2,5) düşüş görünürken,
     gerçekte 505,6 ₺ → 540,9 ₺ (+%7,0 artış)! */

/* ── 6) ★ İNDİRİM ARTTI AMA BRÜT MARJ ERİMEDİ (+2,8 PUAN ARTTI!) ──────────────
   Aynı-yıl alış faturası (fatAyr eTip=0, KDV hariç) ile eşlenen kırtasiye kalemlerinde:
   - 2025 Ağu-Eyl: Ciro(KDV Hariç) 39,15M ₺ · SMM 23,18M ₺ · Brüt Marj %40,8 · Fiş başı kâr 178,7 ₺
   - 2026 Ağu-Eyl: Ciro(KDV Hariç) 64,14M ₺ · SMM 36,19M ₺ · Brüt Marj %43,6 · Fiş başı kâr 248,6 ₺ (+%39,1)
   - Brüt kâr havuzu: 15,97M ₺ → 27,95M ₺ (+%75,0). */

/* ── 7) ★ SEPET KOMPOZİSYONU (SAF KIRTASİYE vs KARMA SEPET) ve GECE PAZARI ─────
   - Sadece Kırtasiye fişi (%21,4): 3,80 adet kırtasiye / 475,0 ₺ toplam fiş
   - Kırtasiye + Kitap (%21,5, fiş +%35,4): 5,57 adet kırtasiye / 1.677,5 ₺ toplam fiş
   - Kırtasiye + Hazırlık (%15,2): 6,01 adet kırtasiye / 2.104,8 ₺ toplam fiş
   - Kırtasiye + Hazırlık + Kitap (%6,3): 7,63 adet kırtasiye / 2.917,5 ₺ toplam fiş (6,1x!)
   - Kırtasiye + Oyuncak/Hediyelik (%35,6): 8,03 adet kırtasiye / 1.227,4 ₺ toplam fiş
   - Saat dilimi (2026 Ağu-Eyl): Sabah (09-11) 5,56 adet / 587,7 ₺ (6.313 fiş) iken,
     Gece (20-23) 6,63 adet / 749,9 ₺ (22.380 fiş — sabahın 3,5 katı fiş, +%27,6 daha büyük sepet!). */

/* ── 8) ★ ÜRÜN AİLELERİ, MARKA SAVAŞLARI VE TEKİL SKU ŞAMPİYONLARI (AĞU–EYL 2025 vs 2026) ──
   Not: 1 kuruşluk promosyon oyun hamurları (stkID IN 1733557, 584270..584278) hariç tutulmuş,
   fiş ortalamalarında fan-out olmaması için önce (SalesId, Grup) düzeyinde tekilleştirilmiştir. */
WITH fis_ozet AS (
    SELECT s.Id AS SalesId, YEAR(s.Date) AS Yil,
           SUM(sp.Amount) AS FisTopAdet, SUM(sp.TotalPrice) AS FisTopNetTL,
           SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' AND u.stkID NOT IN (1733557,584270,584272,584273,584274,584275,584276,584277,584278) THEN sp.Amount ELSE 0 END) AS FisKirtAdet,
           SUM(CASE WHEN k2.ktgrAd = N'Kırtasiye' AND u.stkID NOT IN (1733557,584270,584272,584273,584274,584275,584276,584277,584278) THEN sp.TotalPrice ELSE 0 END) AS FisKirtNetTL
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id
    JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
    LEFT JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CASE WHEN ISNUMERIC(p.Code)=1 THEN CONVERT(int, p.Code) END
    LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
    WHERE sp.IsValid = 1 AND s.DocumentsTypeId IN (1, 2, 6, 7)
      AND ((s.Date >= CONVERT(date, '01.08.2025', 104) AND s.Date < CONVERT(date, '01.10.2025', 104))
        OR (s.Date >= CONVERT(date, '01.08.2026', 104) AND s.Date < CONVERT(date, '01.10.2026', 104)))
    GROUP BY s.Id, YEAR(s.Date)
),
fis_urun AS (
    SELECT f.SalesId, f.Yil, f.FisKirtAdet, f.FisKirtNetTL, f.FisTopNetTL,
           u.stkID, u.stkAd, ISNULL(m.mrkAd, N'-') AS Marka,
           SUM(sp.Amount) AS UrunAdet, SUM(sp.TotalPrice) AS UrunNetTL
    FROM fis_ozet f
    JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = f.SalesId
    JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
    JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CASE WHEN ISNUMERIC(p.Code)=1 THEN CONVERT(int, p.Code) END
    JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
    LEFT JOIN DerinSISBkm.dbo.urnMrk m WITH(NOLOCK) ON m.mrkID = u.urnMrkID
    WHERE sp.IsValid = 1 AND k2.ktgrAd = N'Kırtasiye'
      AND u.stkID NOT IN (1733557,584270,584272,584273,584274,584275,584276,584277,584278)
    GROUP BY f.SalesId, f.Yil, f.FisKirtAdet, f.FisKirtNetTL, f.FisTopNetTL, u.stkID, u.stkAd, ISNULL(m.mrkAd, N'-')
)
SELECT TOP 25 stkID, stkAd, Marka,
       SUM(CASE WHEN Yil=2025 THEN 1 ELSE 0 END) AS Fis25,
       SUM(CASE WHEN Yil=2026 THEN 1 ELSE 0 END) AS Fis26,
       CAST(SUM(CASE WHEN Yil=2025 THEN UrunAdet ELSE 0 END) AS decimal(18,0)) AS Adet25,
       CAST(SUM(CASE WHEN Yil=2026 THEN UrunAdet ELSE 0 END) AS decimal(18,0)) AS Adet26,
       CAST(SUM(CASE WHEN Yil=2025 THEN UrunNetTL ELSE 0 END) AS decimal(18,0)) AS Ciro25,
       CAST(SUM(CASE WHEN Yil=2026 THEN UrunNetTL ELSE 0 END) AS decimal(18,0)) AS Ciro26,
       CAST(SUM(CASE WHEN Yil=2026 THEN UrunNetTL ELSE 0 END)/NULLIF(SUM(CASE WHEN Yil=2026 THEN UrunAdet ELSE 0 END),0) AS decimal(10,1)) AS BirimFiyat26,
       CAST(AVG(CASE WHEN Yil=2026 THEN FisKirtAdet*1.0 END) AS decimal(10,2)) AS GirdigiFisteKirtAdet26,
       CAST(AVG(CASE WHEN Yil=2026 THEN FisKirtNetTL*1.0 END) AS decimal(10,1)) AS GirdigiFisteKirtTL26,
       CAST(AVG(CASE WHEN Yil=2026 THEN FisTopNetTL*1.0 END) AS decimal(10,1)) AS GirdigiFisteTumTL26
FROM fis_urun
GROUP BY stkID, stkAd, Marka
ORDER BY Ciro26 DESC;
/* ÖLÇÜLMÜŞ ÜRÜN & MARKA BULGULARI (Ağu-Eyl 2025 vs 2026):
   - ÜRÜN AİLELERİ:
     1) Okul/Beslenme Çantası: Fiş 12.634→13.946 (+%10,4), Ciro 10,67M→16,34M ₺ (+%53,2), Birim fiyat 596→815 ₺ (+%36,7), Girdiği tüm sepet 3.134,3 ₺.
     2) Matara/Suluk/Termos: Ciro 2,03M→3,20M ₺ (+%57,3), Birim fiyat 623→959 ₺ (+%54,0), Girdiği tüm sepet 3.924,2 ₺ (#1 sepet çıpası!).
     3) Boya ve Resim Grubu: Birim fiyat neredeyse sabit kaldı (125,5→128,3 ₺, +%2,2) → Adet 48.046→68.963 (+%43,5!) patladı, Ciro 6,03M→8,85M ₺ (+%46,7).
     4) Dosyalama/Klasör (41 ₺) ve A4 Fotokopi Kağıdı (104 ₺): Girdikleri fişte ortalama 18,86 ve 19,69 adet kırtasiye bulunuyor ("Okul Listesi" turnusol ürünleri).
   - MARKA SAVAŞLARI:
     * Kazananlar: Faber-Castell (6,53M→9,14M ₺, +%40,1), Keskin Color (5,27M→6,87M ₺, +%30,5), Ceren (2,17M→5,50M ₺, +%153,0!), Gıpta (3,09M→4,96M ₺, +%60,4), MAS (1,07M→2,35M ₺, +%119,0), Vagonlife (1,00M→2,23M ₺, +%123,3), Penna (1,4K→1,44M ₺, 8.610 fiş yeni giriş!), Fatih (541K→1,04M ₺, +%92,5 — 12'li paket kalem etkisi).
     * Kan Kaybedenler: OMT (16.847→10.781 fiş, -%36,0), TİMON (adet -%25,8), Rotring (fiş -%13,6), Bic (adet -%16,2).
   - ŞAMPİYON TEKİL ÜRÜNLER (Top SKU):
     #1 Pritt Stick 22Gr (56728): 243K→443K ₺ (+%82), 3.404 fiş, girdiği fiş 25,9 adet / 3.445 ₺!
     #2 Mopak A4 Fotokopi Kağıdı (21454): 32K→430K ₺ (+%1.233 / 10,4x fiş!), Projecta A4'ün (399K→173K ₺) tahtını devraldı.
     #3 Pritt Stick 43Gr (58064): 234K→355K ₺ (+%52), girdiği fiş 30,5 adet kırtasiye / 4.248 ₺ toplam sepet!
     #5 Faber-Castell 0.7mm Kalem Ucu (1642814): 1.451→7.196 fiş (5x), 2.470→15.626 adet (+%533!), 72,5K→309,1K ₺. */


/* ============================================================================
   SORGU 11 — SINAV OKULLARI FİŞLERİ (DocumentsTypeId=8) DAHİL vs HARİÇ vs SADECE SINAV
   Ağustos–Eylül, Ağustos, Eylül ve 23–31 Temmuz (2025 vs 2026)
   BULGULAR:
   - Sınav fişlerinin (DocumentsTypeId=8) %100'ü İstanbul Yolu (StoresId=1) mağazasından kesilir.
   - BKM.snv.SinavSiparisFisEncore ile DocumentsTypeId=8 %99,99 birebir örtüşür.
   - Ağu–Eyl 2026'da 7.497 Sınav fişinin 5.299'unda (%70,7 penetrasyon, 2025'te %66,5) kırtasiye vardır.
   - Sadece Sınav Fişlerinde (Belge=8):
     * Fiş Başı Kırtasiye Adedi: 21,27 → 21,73 adet (+%2,1) — Perakendenin 3,3x katı!
     * Fiş Başı Kırtasiye Net ₺: 2.492,0 ₺ → 3.623,5 ₺ (+%45,4!) — Perakendenin 4,8x katı!
     * Sınav Kırtasiye Cirosu: 14,21M ₺ → 19,20M ₺ (+%35,1)
   - Sınav Dahil Tüm Mağaza (1,2,6,7,8 — 0,01₺ Hamur Hariç):
     * Kırtasiye Fişi: 102.182 → 112.525 (+%10,1)
     * Kırtasiye Adet / Fiş: 6,96 → 7,24 (+%4,0)
     * Kırtasiye Net ₺ / Fiş: 679,8 ₺ → 885,6 ₺ (+%30,3) [Eylül'de 679,4 ₺ → 993,0 ₺, +%46,2!]
     * Kırtasiye Net Cirosu: 69,46M ₺ → 99,65M ₺ (+%43,5, ~100 Milyon ₺!)
   - AĞUSTOS SİMPSON PARADOKSU:
     * 2025'te Sınav kırtasiye fişlerinin %44,4'ü (2.529 fiş) Ağustos'ta kesilmişti; 2026'da kayıtlar Eylül'e kaydığı için Ağustos Sınav kırtasiye fişi 1.453'e (-%42,5) düştü, Eylül ise 3.172 → 3.846 (+%21,2) arttı.
     * Bu yüzden Sınav Dahil bakıldığında Ağustos sepeti (680,4 ₺ → 678,5 ₺, -%0,3) yatay görünürken, Sınav Hariç Perakende (+%7,0) ve Sadece Sınav (+%41,3) kendi içinde büyümüştür.
   ============================================================================ */
WITH UrunKat AS (
    SELECT
        p.Id AS ProductsId,
        CASE WHEN k1.ktgrAd = N'Kırtasiye' THEN 1 ELSE 0 END AS IsKirtasiye
    FROM EncoreMerkez.dbo.Products p
    INNER JOIN DerinSISBkm.dbo.urn u ON u.stkID = CASE WHEN ISNUMERIC(p.Code)=1 AND LEN(p.Code)<=9 THEN CAST(p.Code AS INT) ELSE -1 END
    LEFT JOIN DerinSISBkm.dbo.urnKtgrAgac1 k1 ON k1.ktgrID = u.urnKtgrID1
),
FisBaz AS (
    SELECT
        s.Id AS SalesId,
        s.StoresId,
        s.DocumentsTypeId,
        YEAR(s.DocumentsDate) AS Yil,
        MONTH(s.DocumentsDate) AS Ay,
        s.NetTotal AS FisNetTotal,
        SUM(sp.Quantity) AS TopAdet,
        SUM(CASE WHEN uk.IsKirtasiye=1 AND sp.NetTotal > 1.0 THEN sp.Quantity ELSE 0 END) AS KirtGercekAdet,
        COUNT(DISTINCT CASE WHEN uk.IsKirtasiye=1 AND sp.NetTotal > 1.0 THEN sp.ProductsId END) AS KirtGercekCesit,
        SUM(CASE WHEN uk.IsKirtasiye=1 AND sp.NetTotal > 1.0 THEN sp.NetTotal ELSE 0 END) AS KirtGercekNet,
        SUM(CASE WHEN uk.IsKirtasiye=1 AND sp.NetTotal > 1.0 THEN sp.GrossTotal ELSE 0 END) AS KirtGercekBrut
    FROM EncoreMerkez.dbo.Sales s
    INNER JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
    LEFT JOIN UrunKat uk ON uk.ProductsId = sp.ProductsId
    WHERE s.IsTransfer = 1 AND s.Cancelled = 0
      AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
      AND (
          (s.DocumentsDate >= CONVERT(datetime, '01.08.2025', 104) AND s.DocumentsDate < CONVERT(datetime, '01.10.2025', 104))
          OR
          (s.DocumentsDate >= CONVERT(datetime, '01.08.2026', 104) AND s.DocumentsDate < CONVERT(datetime, '01.10.2026', 104))
      )
    GROUP BY s.Id, s.StoresId, s.DocumentsTypeId, YEAR(s.DocumentsDate), MONTH(s.DocumentsDate), s.NetTotal
)
SELECT
    Kapsam,
    Yil,
    COUNT(*) AS ToplamFis,
    SUM(CASE WHEN KirtGercekAdet > 0 THEN 1 ELSE 0 END) AS KirtFis_Gercek,
    CAST(100.0 * SUM(CASE WHEN KirtGercekAdet > 0 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0) AS DECIMAL(5,1)) AS Pen_Gercek_Pct,
    CAST(AVG(CASE WHEN KirtGercekAdet > 0 THEN KirtGercekAdet*1.0 END) AS DECIMAL(10,2)) AS KirtAdet_Gercek,
    CAST(AVG(CASE WHEN KirtGercekAdet > 0 THEN KirtGercekCesit*1.0 END) AS DECIMAL(10,2)) AS KirtCesit_Gercek,
    CAST(AVG(CASE WHEN KirtGercekAdet > 0 THEN KirtGercekNet*1.0 END) AS DECIMAL(10,1)) AS KirtNet_Gercek,
    CAST(AVG(CASE WHEN KirtGercekAdet > 0 THEN FisNetTotal*1.0 END) AS DECIMAL(10,1)) AS TumSepetNet_Gercek,
    CAST(SUM(KirtGercekNet) AS DECIMAL(18,0)) AS TopKirtCiro_Gercek
FROM FisBaz
CROSS APPLY (
    SELECT N'1_Sinav_Haric (1,2,6,7)' AS Kapsam WHERE DocumentsTypeId IN (1,2,6,7)
    UNION ALL
    SELECT N'2_Sinav_Dahil (1,2,6,7,8)' AS Kapsam WHERE DocumentsTypeId IN (1,2,6,7,8)
    UNION ALL
    SELECT N'3_Sadece_Sinav (8)' AS Kapsam WHERE DocumentsTypeId = 8
) k
GROUP BY Kapsam, Yil
ORDER BY Kapsam, Yil;
