-- ork:hedef-db DerinSISBkm
-- ork:compat 150
/* Soru     : Kategori marjı ve ABC sınıflaması iadeyi düşüp yalnız üç mağazanın perakende cirosunu mu kullanıyor
              (merkez depo toptanı girmeden, kasa ile ERP aynı toplamda mı)?
   AC       : AC-7.1, AC-7.2, AC-7.3 · Spec 001 · H07
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç); mağaza mekanID 1 FSM · 4477 Özlüce · 4478 İst.Yolu
   UYARI    : muhasebe açık dönem — maliyet (ehMaliyet) Eylül için değişebilir; ciro kasa tabanlı.
              Bu dosyanın ciro blokları (A, B, C) maliyetten bağımsızdır; Smm yalnız ONCE-MARJ bloklarında vardır.
   Tolerans : tutar ≤ 1 TL
   Önce     : (04.10.2026, erp profili, --read-only; panel gövdeleri RefQueries.Envanter.cs :446 GetMarjAsync ve RefQueries.cs :115
              tAbc, dosya dışı: T-011 ölçümü; tek fark: son 30 gün / geçen ay yerine @Bas, @Bit; bloklar ONCE-MARJ, ONCE-MARJ-3,
              ONCE-MARJ-FSM, ONCE-ABC)
              ONCE-MARJ (panel eMekan 12,1,4478,4477; 17 kategori): Ciro 299.654.877,95 · Smm 111.202.823,89 · görüntü süzgeci
              (%5-95) sonrası Ciro 234.422.407,20
              ONCE-MARJ-3 (merkez depo çıkınca; 3 mağaza): Ciro 219.445.530,95 · Smm 111.202.823,89 (depo ile AYNI) · görüntü
              sonrası 219.419.869,81
              ONCE-MARJ-FSM (yalnız FSM; 15 kategori): Ciro 42.171.532,10 · Smm 25.758.900,94 · görüntü sonrası 42.163.255,48
              ONCE-ABC (panel tAbc, 1001 hariç, iade YOK, mağaza süzgeci YOK): A 1.162 ürün 382.671.344 · B 10.826 / 71.752.124 ·
              C 46.836 / 23.918.337
                (toplam 478.341.805)
   Sonra    : yok (düzeltme T-049, T-050 sonrası ölçülür)
   Bağımsız : (04.10.2026)
              A kanonik şube cirosu (irsHrk 100 − 101 + 4 − 5, 3 mağaza, ehAltDepo 0): 470.550.331,25 (T-001 02.10 ölçümüyle
              470.550.33x tuttu)
                A1 bileşenler: FSM 45.878.567,81 · Özlüce 59.157.462,22 · İst.Yolu 374.224.884,89
              B pozitif net ürün cirolarının toplamı (Encore, 3 mağaza, tip 1,2,3,6,7,8, iade negatif, 1001 hariç): 469.956.103,68
              · 58.600 ürün
              B1 bağımsız ABC (B'nin ürün netleri): A 1.151 ürün 375.946.851,57 · B 10.805 / 70.510.849,98 · C 46.644 /
              23.498.402,13 (Σ = B)
              C Encore başlık neti (GrossTotal − DiscountTotal − VatTotal, iade negatif, 3 mağaza): 469.631.399,98
                = Σ kalem net (TotalPrice − VatTotal; 1001 dahil, HAVING'siz) 469.631.399,98 (kaynak içi kimlik; fark 0,00)
              A ↔ Encore mutabakatı: A − C = +918.931,27 (%0,20). İade tarafı birebir: ehTip 101 = Encore tip 3 (1.097.636,30 ·
                1.287.609,19 · 6.325.338,18). Fark satış tarafında: ERP − Encore FSM +216.549,91 · Özlüce +164.934,61 · İst.Yolu
                +537.446,75 (mağaza × gün ve eTip 4/5 kullanıcı kırılımı: H07-marj-abc-ek.sql GUN, KISI).
   Fark     : (Önce − Bağımsız, ölçüldü 04.10.2026)
              Marj ciro: panel 299,65M (merkez depo dahil) ↔ A 470,55M. İki ayrı sapma: (1) merkez depo toptanı panelde var:
                irsAyr mekan 12, eTip 1: 4.959 satır, 82.609.479,97 ciro, irsAyr.ehAdetN toplamı 0 (4.959/4.959; irsAyr.ehAdet ve
                irsHrk.ehAdetN −327.868 dolu; ek dosya D, D_HRK) → depo ciroyu şişirir, Smm'ye katkısı 0,00 (ONCE-MARJ ve ONCE-MARJ-3 Smm
                aynı). (2) maliyeti bilinmeyen ürün satırı WHERE COALESCE(...) IS NOT NULL ile ciro dahil düşüyor: 3 mağaza irsAyr
                cirosu 479,57M iken panel 219,45M (%45,8; ek dosya M).
                İade yok: panel yalnız eTip 1,4,100 (iade 5, 101 hiç girmez; Eylül iade net 8,40M, ek dosya B_NEG).
              ABC: panel 478.341.805 ↔ B 469.956.103,68; fark 8.385.701,47 (ek dosya ABC_FARK) = (a) panel iadeyi düşmüyor
                8.403.221,07 + (b) mağaza süzgeci etkisi 0,00 (bugün) + (c) HAVING −17.519,60. Sınıf ürün sayısı 1.162/10.826/46.836 ↔
                1.151/10.805/46.644.
              B ↔ C: B − C = +324.703,70 = +307.184,10 (1001 dışlaması; 1001 kalemlerinin net toplamı −307.184,10) + 17.519,60
                (iade sonrası net ≤ 0 kalan 344 ürün HAVING'le atılır; ek dosya B_NEG).
   Nüfus    : (blok N, 04.10.2026) irsHrk kanonik satır 409.979 · irsHrk 101 satırı 11.586 · merkez depo toptan belgesi (irs eTip
              1, eMekan 12)
              215 · Encore iade belgesi 4.956 · Encore iade kalemi (IsValid 1) 14.965. B ürün nüfusu 58.600.
   Aynı kaynak — neden: A ve panel marjı aynı kaynaktan (irsHrk / irs, DerinSISBkm) kurulur; bu yüzden A panelin 'bağımsız' kanıtı DEĞİL,
              tanım kimliğidir. Bağımsız taraf Encore'dır (B, C): A ↔ C mutabakatı kaynaklar arası ölçülmüş tek kıyas.
              B ile C aynı Encore kalemlerinden kurulur: B ↔ C 'kaynak içi' kimliktir, bağımsız DEĞİL.
   Başka ne olabilir: (1) A − C = +918.931 farkı gün içi aktarım değil: Eylül kapalı. İade birebir, fark satış tarafında. ERP'de eTip 4
              ve 5
              belgelerinin tamamı elle girilmiş (gKisi ≠ 31; 31 yalnız 100/101); ERP 100 − 101 Encore'nin altında, elle 4 − 5 farkı
              kapatıp aşıyor (ek dosya GUN, KISI). Mekanizma (fatura çift kaydı, tarih kayması) kanıtlanmadı: ÇIKARIM, açık soru.
              (2) Marj ciro/Smm tabanı: panel ehTutar − ehIndirim (irsAyr, KDV durumu ölçülmedi), A ehTutarN (KDV hariç); iki
              tanım aynı soruya cevap vermeyebilir. (3) ABC panel iadeyi hiç düşmüyor; B iadeyi negatif sayar ve 1001'i dışlar.
              (4) Smm Eylül için muhasebe açık dönem nedeniyle değişebilir; A, B, C etkilenmez.
   Kapsam   : A = irsHrk ehTip 100 − 101 + 4 − 5, üç mağaza, ehAltDepo = 0, ehTutarN. B = Encore kalem net (TotalPrice − VatTotal,
              KDV hariç), ürün bazlı, iade negatif, HAVING SUM > 0, 1001 hariç (panel ABC :118 ile aynı kural).
   Dondurma : 39702ee
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; bloklar GO'suz, @Bas/@Bit literal; A, A1 --profile erp; B, C, B1 encore.
   Bloklar  : A kanonik şube cirosu · A1 mağaza × tip kırılımı · B pozitif net ürün cirolarının toplamı · B1 sınıf bazlı bağımsız ABC
              · C Encore başlık neti (A ↔ Encore mutabakatı) · ONCE-MARJ, ONCE-MARJ-3, ONCE-MARJ-FSM (panel marjı)
              · ONCE-ABC (panel ABC) · N nüfus. Ara ölçümler (GUN, KISI, D, M, B_NEG, ABC_FARK): H07-marj-abc-ek.sql.
              Boş nüfus 'bakamadım'dır, 'temiz' değil.
*/

-- blok: A  (kanonik şube cirosu: irsHrk 100 − 101 + 4 − 5, üç mağaza, ehAltDepo = 0)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    CONVERT(DECIMAL(18, 2), ISNULL(SUM(
        CASE
            WHEN h.ehTip IN (100, 4) THEN h.ehTutarN
            WHEN h.ehTip IN (101, 5) THEN -h.ehTutarN
            ELSE 0
        END
    ), 0)) AS Ciro
FROM DerinSISBkm.dbo.irsHrk AS h
WHERE
    h.ehTip IN (100, 101, 4, 5)
    AND h.ehMekan IN (1, 4477, 4478)
    AND h.ehAltDepo = 0
    AND h.ehTrhS >= @Bas
    AND h.ehTrhS < @Bit;
GO

-- blok: A1  (mağaza × tip kırılımı; A'nın bileşenleri)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    h.ehMekan AS Mekan,
    h.ehTip AS Tip,
    COUNT(*) AS Satir,
    CONVERT(DECIMAL(18, 2), SUM(h.ehTutarN)) AS Tutar
FROM DerinSISBkm.dbo.irsHrk AS h
WHERE
    h.ehTip IN (100, 101, 4, 5)
    AND h.ehMekan IN (1, 4477, 4478)
    AND h.ehAltDepo = 0
    AND h.ehTrhS >= @Bas
    AND h.ehTrhS < @Bit
GROUP BY h.ehMekan, h.ehTip
ORDER BY h.ehMekan, h.ehTip;
GO

-- blok: B  (Encore: pozitif net ürün cirolarının toplamı; KDV hariç, iade negatif, 1001 hariç, üç mağaza)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Urun AS (
    SELECT
        sp.ProductsId,
        SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal)) AS net
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON sp.SalesId = s.Id
        INNER JOIN EncoreMerkez.dbo.Pos AS p
            ON s.PosId = p.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON p.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
    WHERE
        sp.IsValid = 1
        AND sp.BarcodeNo <> '1001'
        AND mg.mekanID IN (1, 4477, 4478)
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
    GROUP BY sp.ProductsId
    HAVING SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal)) > 0
)

SELECT
    CONVERT(DECIMAL(18, 2), ISNULL(SUM(u.net), 0)) AS Ciro,
    COUNT(*) AS UrunSayisi
FROM Urun AS u;
GO

-- blok: B1  (bağımsız ABC: B'nin ürün netleri üzerinde kümülatif pay; sınıf başına adet ve ciro)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Urun AS (
    SELECT
        sp.ProductsId,
        SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal)) AS net
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON sp.SalesId = s.Id
        INNER JOIN EncoreMerkez.dbo.Pos AS p
            ON s.PosId = p.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON p.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
    WHERE
        sp.IsValid = 1
        AND sp.BarcodeNo <> '1001'
        AND mg.mekanID IN (1, 4477, 4478)
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
    GROUP BY sp.ProductsId
    HAVING SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal)) > 0
),

Kumulatif AS (
    SELECT
        u.net,
        100.0 * SUM(u.net) OVER (ORDER BY u.net DESC, u.ProductsId ASC ROWS UNBOUNDED PRECEDING) / SUM(u.net) OVER () AS kp
    FROM Urun AS u
)

SELECT
    CASE WHEN k.kp <= 80 THEN 'A' WHEN k.kp <= 95 THEN 'B' ELSE 'C' END AS Sinif,
    COUNT(*) AS Adet,
    CONVERT(DECIMAL(18, 2), SUM(k.net)) AS Ciro
FROM Kumulatif AS k
GROUP BY CASE WHEN k.kp <= 80 THEN 'A' WHEN k.kp <= 95 THEN 'B' ELSE 'C' END
ORDER BY Sinif;
GO

-- blok: C  (Encore başlık neti: GrossTotal − DiscountTotal − VatTotal, iade negatif, üç mağaza; A ↔ Encore mutabakatı)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    CONVERT(DECIMAL(18, 2), ISNULL(SUM(
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal)
    ), 0)) AS Net
FROM EncoreMerkez.dbo.Sales AS s
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
WHERE
    mg.mekanID IN (1, 4477, 4478)
    AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit;
GO

-- noqa: disable=all
/* tsqllint-disable */
-- blok: ONCE-MARJ  (panel GetMarjAsync :446 aynen; tek fark: son 30 gün yerine @Bas/@Bit; eMekan 12,1,4478,4477 = panel; sarmal toplam)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT COUNT(*) AS KategoriSayisi, SUM(x.Ciro) AS Ciro, SUM(x.Smm) AS Smm,
       SUM(CASE WHEN x.MarjPct >= 5 AND x.MarjPct <= 95 THEN x.Ciro END) AS CiroGoruntu
FROM (
SELECT s.Kat AS Kategori,
    SUM(s.Ciro)                                            AS Ciro,
    SUM(s.Adet * COALESCE(mlyt.M5, ml.ORT_ALIS))           AS Smm,
    CAST((SUM(s.Ciro) - SUM(s.Adet * COALESCE(mlyt.M5, ml.ORT_ALIS)))
        * 100.0 / NULLIF(SUM(s.Ciro), 0) AS decimal(5,1))  AS MarjPct
FROM (
    SELECT a.ehStkID AS stkID, CAST(k2.ktgrAd AS nvarchar(50)) AS Kat,
           SUM(a.ehTutar - a.ehIndirim) AS Ciro, SUM(ABS(a.ehAdetN)) AS Adet
    FROM DerinSISBkm.dbo.irs i WITH(NOLOCK)
    JOIN DerinSISBkm.dbo.irsAyr a WITH(NOLOCK) ON a.ehID = i.eID
    JOIN DerinSISBkm.dbo.urn u  WITH(NOLOCK) ON u.stkID = a.ehStkID
    JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
    WHERE i.eTip IN (1,4,100)
      AND i.eTarih >= @Bas
      AND i.eTarih < @Bit
      AND i.eMekan IN (12,1,4478,4477)
    GROUP BY a.ehStkID, CAST(k2.ktgrAd AS nvarchar(50))
) s
OUTER APPLY (
    SELECT CONVERT(money, SUM(b.ehTutarN)/SUM(b.ehAdetN)) AS M5
    FROM (SELECT TOP 5 fa.ehAdetN, fa.ehTutarN
          FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID AND f.eTip=0 AND f.eDurum<>2
          WHERE fa.ehStkID=s.stkID AND fa.ehAdetN<>0 ORDER BY f.eTarih DESC) b
    HAVING SUM(b.ehAdetN)<>0
) mlyt
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml WITH(NOLOCK) ON ml.STKID = s.stkID
WHERE COALESCE(mlyt.M5, ml.ORT_ALIS) IS NOT NULL
GROUP BY s.Kat
HAVING SUM(s.Ciro) > 0
) x;
GO

-- blok: ONCE-MARJ-3  (ONCE-MARJ ile aynı gövde; yalnız eMekan IN (1,4478,4477): merkez depo çıkarılınca ne kalıyor)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT COUNT(*) AS KategoriSayisi, SUM(x.Ciro) AS Ciro, SUM(x.Smm) AS Smm,
       SUM(CASE WHEN x.MarjPct >= 5 AND x.MarjPct <= 95 THEN x.Ciro END) AS CiroGoruntu
FROM (
SELECT s.Kat AS Kategori,
    SUM(s.Ciro)                                            AS Ciro,
    SUM(s.Adet * COALESCE(mlyt.M5, ml.ORT_ALIS))           AS Smm,
    CAST((SUM(s.Ciro) - SUM(s.Adet * COALESCE(mlyt.M5, ml.ORT_ALIS)))
        * 100.0 / NULLIF(SUM(s.Ciro), 0) AS decimal(5,1))  AS MarjPct
FROM (
    SELECT a.ehStkID AS stkID, CAST(k2.ktgrAd AS nvarchar(50)) AS Kat,
           SUM(a.ehTutar - a.ehIndirim) AS Ciro, SUM(ABS(a.ehAdetN)) AS Adet
    FROM DerinSISBkm.dbo.irs i WITH(NOLOCK)
    JOIN DerinSISBkm.dbo.irsAyr a WITH(NOLOCK) ON a.ehID = i.eID
    JOIN DerinSISBkm.dbo.urn u  WITH(NOLOCK) ON u.stkID = a.ehStkID
    JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
    WHERE i.eTip IN (1,4,100)
      AND i.eTarih >= @Bas
      AND i.eTarih < @Bit
      AND i.eMekan IN (1,4478,4477)
    GROUP BY a.ehStkID, CAST(k2.ktgrAd AS nvarchar(50))
) s
OUTER APPLY (
    SELECT CONVERT(money, SUM(b.ehTutarN)/SUM(b.ehAdetN)) AS M5
    FROM (SELECT TOP 5 fa.ehAdetN, fa.ehTutarN
          FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID AND f.eTip=0 AND f.eDurum<>2
          WHERE fa.ehStkID=s.stkID AND fa.ehAdetN<>0 ORDER BY f.eTarih DESC) b
    HAVING SUM(b.ehAdetN)<>0
) mlyt
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml WITH(NOLOCK) ON ml.STKID = s.stkID
WHERE COALESCE(mlyt.M5, ml.ORT_ALIS) IS NOT NULL
GROUP BY s.Kat
HAVING SUM(s.Ciro) > 0
) x;
GO

-- blok: ONCE-MARJ-FSM  (ONCE-MARJ ile aynı gövde; yalnız eMekan = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT COUNT(*) AS KategoriSayisi, SUM(x.Ciro) AS Ciro, SUM(x.Smm) AS Smm,
       SUM(CASE WHEN x.MarjPct >= 5 AND x.MarjPct <= 95 THEN x.Ciro END) AS CiroGoruntu
FROM (
SELECT s.Kat AS Kategori,
    SUM(s.Ciro)                                            AS Ciro,
    SUM(s.Adet * COALESCE(mlyt.M5, ml.ORT_ALIS))           AS Smm,
    CAST((SUM(s.Ciro) - SUM(s.Adet * COALESCE(mlyt.M5, ml.ORT_ALIS)))
        * 100.0 / NULLIF(SUM(s.Ciro), 0) AS decimal(5,1))  AS MarjPct
FROM (
    SELECT a.ehStkID AS stkID, CAST(k2.ktgrAd AS nvarchar(50)) AS Kat,
           SUM(a.ehTutar - a.ehIndirim) AS Ciro, SUM(ABS(a.ehAdetN)) AS Adet
    FROM DerinSISBkm.dbo.irs i WITH(NOLOCK)
    JOIN DerinSISBkm.dbo.irsAyr a WITH(NOLOCK) ON a.ehID = i.eID
    JOIN DerinSISBkm.dbo.urn u  WITH(NOLOCK) ON u.stkID = a.ehStkID
    JOIN DerinSISBkm.dbo.urnKtgr2 k2 WITH(NOLOCK) ON k2.ktgrID = u.urnKtgr2ID
    WHERE i.eTip IN (1,4,100)
      AND i.eTarih >= @Bas
      AND i.eTarih < @Bit
      AND i.eMekan IN (1)
    GROUP BY a.ehStkID, CAST(k2.ktgrAd AS nvarchar(50))
) s
OUTER APPLY (
    SELECT CONVERT(money, SUM(b.ehTutarN)/SUM(b.ehAdetN)) AS M5
    FROM (SELECT TOP 5 fa.ehAdetN, fa.ehTutarN
          FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID AND f.eTip=0 AND f.eDurum<>2
          WHERE fa.ehStkID=s.stkID AND fa.ehAdetN<>0 ORDER BY f.eTarih DESC) b
    HAVING SUM(b.ehAdetN)<>0
) mlyt
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml WITH(NOLOCK) ON ml.STKID = s.stkID
WHERE COALESCE(mlyt.M5, ml.ORT_ALIS) IS NOT NULL
GROUP BY s.Kat
HAVING SUM(s.Ciro) > 0
) x;
GO

-- blok: ONCE-ABC  (panel tAbc RefQueries.cs :115 aynen; @ayBas → @Bas, @aySon → @Bit; iade yok, mağaza süzgeci yok)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT Sinif, COUNT(*) AS Adet, CAST(SUM(Ciro) AS decimal(18,0)) AS Ciro FROM (
  SELECT ProductsId, Ciro, 100.0*SUM(Ciro) OVER(ORDER BY Ciro DESC ROWS UNBOUNDED PRECEDING)/SUM(Ciro) OVER() KP FROM (
    SELECT sp.ProductsId, SUM(sp.TotalPrice-sp.VatTotal) Ciro FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId
    WHERE sp.IsValid=1 AND sp.BarcodeNo<>'1001' AND s.Date>=@Bas AND s.Date<@Bit AND s.DocumentsTypeId IN (1,2,6,7,8)
    GROUP BY sp.ProductsId HAVING SUM(sp.TotalPrice-sp.VatTotal)>0) p) r
CROSS APPLY (SELECT CASE WHEN KP<=80 THEN 'A' WHEN KP<=95 THEN 'B' ELSE 'C' END Sinif) x GROUP BY Sinif;
GO
/* tsqllint-enable */
-- noqa: enable=all

-- blok: N  (nüfus: tek satır; Eylül 2026)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    (
        SELECT COUNT(*)
        FROM DerinSISBkm.dbo.irsHrk AS h
        WHERE h.ehTip IN (100, 101, 4, 5) AND h.ehMekan IN (1, 4477, 4478) AND h.ehAltDepo = 0 AND h.ehTrhS >= @Bas AND h.ehTrhS < @Bit
    ) AS irshrk_kanonik_satir,
    (
        SELECT COUNT(*)
        FROM DerinSISBkm.dbo.irsHrk AS h
        WHERE h.ehTip = 101 AND h.ehMekan IN (1, 4477, 4478) AND h.ehAltDepo = 0 AND h.ehTrhS >= @Bas AND h.ehTrhS < @Bit
    ) AS irshrk_iade_satir,
    (
        SELECT COUNT(*)
        FROM DerinSISBkm.dbo.irs AS i
        WHERE i.eTip = 1 AND i.eMekan = 12 AND i.eTarih >= @Bas AND i.eTarih < @Bit
    ) AS merkez_depo_toptan_belge,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE s.DocumentsTypeId = 3 AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS encore_iade_belge,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.SalesProducts AS sp
            INNER JOIN EncoreMerkez.dbo.Sales AS s
                ON sp.SalesId = s.Id
        WHERE sp.IsValid = 1 AND s.DocumentsTypeId = 3 AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS encore_iade_kalem;
