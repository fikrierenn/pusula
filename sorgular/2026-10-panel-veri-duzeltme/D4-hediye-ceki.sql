-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Hediye çeki barem tablosunda brüt, indirim ve net aynı KDV tabanında mı (brüt − indirim = net)?
   AC       : D-4 · Spec 001 · FR-006 · KR-4 (geri dönüşüm tanımı farkı ayrı satırda)
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç)
   Tolerans : tutar ≤ 1,00 TL (K: başlık ↔ kalem indirimi; panel Net ↔ NetKdvDahil farkı = KDV)
   Karar    : KDV TABANI: barem tablosunda Brüt, İndirim ve Net aynı KDV DAHİL tabanda gösterilir (TotalPrice bazlı, blok A);
              panelin bugünkü KDV HARİÇ Net'i (TotalPrice − VatTotal) ayrı "KDV hariç" kolon olarak kalır (spec D-4 · FR-006 ·
              tasks T-072). Tek tabanda "Brüt − İndirim = Net" tutar; karışık tabanda fark KDV'dir (ONCE ↔ A, Fark satırı).
   Önce     : (04.10.2026, sqlcli encore profili, --read-only; panel GetBaremKalemAsync gövdesi aynen, dilim bazlı dış toplam)
              ONCE (Brut · Indirim · Net KDV HARİÇ · Brut − Indirim − Net):
                Dilim 2: 4.096,40 · 839,80 · 2.991,56 · 265,04
                Dilim 3: 81.601,84 · 15.858,59 · 61.293,15 · 4.450,10
                Dilim 4: 237.404,58 · 51.169,48 · 170.723,30 · 15.511,80
                Dilim 5: 410.245,74 · 69.907,01 · 302.988,35 · 37.350,38
                Dilim 6: 928.662,36 · 184.975,10 · 666.507,84 · 77.179,42
              Dilim 1 (≤ 100 TL) satırı yok (panelde de kanonikte de; blok D: ≤ 100 TL çek tahsilatlı fiş 0, en küçük çek 200,00).
              Σ (Brut − Indirim − Net) = 134.756,74 (hepsi > 1 TL).
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Kanonik  : (04.10.2026; kaynak içi) A (Brut · Indirim · NetKdvDahil;
              Brut = TotalPrice + Direct + Indirect, Indirim = Direct + Indirect):
                2: 4.096,40 · 839,80 · 3.256,60 / 3: 81.609,84 · 15.866,59 · 65.743,25 / 4: 237.422,58 · 51.187,48 · 186.235,10
                / 5: 412.457,74 · 72.119,01 · 340.338,73 / 6: 928.741,96 · 185.054,70 · 743.687,26 (NetKdvDahil Σ 1.339.260,94).
              A'daki Brut − Indirim − NetKdvDahil = 0,00 kolonu TANIM GEREĞİ (kanıt DEĞİL). Ayırt edici kimlik: panel Net
                (TotalPrice − VatTotal) ↔ NetKdvDahil (TotalPrice) farkı = KDV: 265,04 · 4.450,10 · 15.511,80 · 37.350,38 · 77.179,42
                (Σ 134.756,74).
              K kimlik (Eylül, IsValid = 1 kalem, belge tipi × çek ödemeli, 10 satır): Σ başlık DiscountTotal = Σ kalem (Direct +
                Indirect), IndirimFarki 0,00 her satırda; Σ (GrossTotal − DiscountTotal) = Σ TotalPrice, NetFarki 0,00 her satırda.
              Σ Direct + Σ Indirect = Σ DiscountTotal (Eylül, K'nın KalemDirect ve KalemIndirect kolonlarının toplamı:
                42.886.966,22 + 10.853.128,37 = 53.740.094,59 = Σ BaslikIndirim; tip ve çek ödemesi bazında 10 satır).
                "DiscountTotalDirect = TOPLAM" kuralı kalem düzeyinde yanlış (ölçüldü): toplam = Direct + Indirect.
              B KR-4 etkisi: kanonik 1001 fiş dışlaması ↔ panel kalem dışlaması, her dilimde Fark 0,00; yalnız-birinde-dışlanan fiş 0 · 0.
                Eylül çek nüfusunda 0; genel 36 belge farkı (T-001 C) kapsam dışı.
              E kategori dışlaması: UrunBilgi.KatAna ↔ urnKtgr2.ktgrAd aynı küme (50 kalem, 85.500,00 TL; çapraz satır yok).
   Fark     : (Önce − Bağımsız, ölçüldü 04.10.2026)
              Panel Brut ve Indirim KDV DAHİL, Net KDV HARİÇ (TotalPrice − VatTotal): aynı satırda iki taban. Brut − Indirim − Net
              farkı = KDV (ONCE Net + KDV = A NetKdvDahil, beş dilimde kuruşuna). Panel Indirim yalnız Direct: eksik indirim
              dilim 3 · 4 · 5 · 6'da 8,00 · 18,00 · 2.212,00 · 79,60 (Σ 2.317,60; Brut aynı tutarda düşük). KR-4 etkisi 0.
   Aynı kaynak — neden: Kalem düzeyi indirim ve KDV yalnız Encore'da var; ERP'de POS özet belgedir. Kanıt kaynak içidir
              (bağımsız DEĞİL): kalem tabanı ↔ başlık tabanı kimliği (blok K) iki ayrı tablodan (SalesProducts, Sales) kurulur;
              kategori dışlaması urn/urnKtgr2'den (panel UrunBilgi.KatAna kullanır, eşdeğerlik blok E'de ölçülür).
   Başka ne olabilir: (1) Fark KR-4 dışlamasından: ölçüldü, B'de 0 (çek ödemeli fişte 1001 ve sebep 12 yok).
              (2) Fark kategori dışlamasından (KatAna ↔ ktgrAd): ölçüldü, E'de aynı küme.
              (3) Fark KDV'den: ONCE Net + KDV'nin A ile kuruşuna eşit çıkması bunu doğruluyor (fark VatTotal'dır).
              (4) Dilim 1 yok: D'de ölçüldü, ≤ 100 TL çek tahsilatlı fiş yok (nüfus 458 fiş, en küçük çek 200,00).
              (5) Kalem indirimi yalnız Direct sanılırsa Indirim eksik kalır: K'da Direct + Indirect = başlık DiscountTotal.
   Kapsam   : Hediye çeki ödemeli fişler (PaymentTypesId = 11, IsChangeAmount = 0; tip 10 iade çeki DEĞİL), belge tipi 1 ve 3
              (iade negatif), mağaza süzgeci yok (panelle aynı). Kalem: IsValid = 1, çek ürünü hariç, 1001 fişi bütünüyle hariç (KR-1).
              Dilim = fişteki toplam çek tahsilatı: ≤100 · ≤250 · ≤500 · ≤1000 · ≤2500 · üstü (1..6).
              Taban: Indirim = Direct + Indirect, Brut = TotalPrice + Indirim, NetKdvDahil = TotalPrice (KDV DAHİL).
              Ürün kodu T-014 kuralı (yalnız rakam, 1-9 hane).
   Dondurma : 18c2ce0
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; bloklar GO'suz ve DECLARE'siz, @Bas/@Bit literalle değiştirilerek
              --profile encore ile koşuldu (SSMS DECLARE + GO esas). --max-rows 1000.
   Bloklar  : A dilim × Brut/Indirim/NetKdvDahil (arayüz) · B geri dönüşüm tanımı etkisi (kanonik 1001 ↔ panel kalem dışlaması)
              · E kategori dışlaması eşdeğerliği (UrunBilgi.KatAna ↔ urnKtgr2) · K kimlik: kalem ↔ başlık (tip bazlı;
              KalemDirect ve KalemIndirect ayrı kolon)
              · D dilim 1 ölçümü
              · N nüfus · ONCE (panel gövdesi): D4-hediye-ceki-once.sql. Boş nüfus 'bakamadım'dır, 'temiz' değil.
*/

-- blok: A  (dilim × Brut, Indirim, NetKdvDahil; kanonik; aynı KDV tabanı)
-- KDV tabanı KARARI (başlık, Karar satırı): üç kolon da KDV DAHİL (TotalPrice bazlı); KDV hariç net bu blokta yok.
/* tsqllint-disable non-sargable */
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
        INNER JOIN EncoreMerkez.dbo.Sales AS sg
            ON sp.SalesId = sg.Id
    WHERE
        sp.BarcodeNo = '1001'
        AND sg.[Date] >= @Bas
        AND sg.[Date] < @Bit
),

Hc AS (
    SELECT
        pt.SalesId,
        SUM(pt.Amount) AS hc_tutar
    FROM EncoreMerkez.dbo.SalesPayments AS pt
        INNER JOIN EncoreMerkez.dbo.Sales AS sh
            ON pt.SalesId = sh.Id
    WHERE
        pt.PaymentTypesId = 11
        AND pt.IsChangeAmount = 0
        AND sh.[Date] >= @Bas
        AND sh.[Date] < @Bit
    GROUP BY pt.SalesId
),

Fisler AS (
    SELECT
        s.Id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END AS isaret,
        CASE
            WHEN h.hc_tutar <= 100 THEN 1
            WHEN h.hc_tutar <= 250 THEN 2
            WHEN h.hc_tutar <= 500 THEN 3
            WHEN h.hc_tutar <= 1000 THEN 4
            WHEN h.hc_tutar <= 2500 THEN 5
            ELSE 6
        END AS dilim
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN Hc AS h
            ON s.Id = h.SalesId
        LEFT JOIN Gd AS gd
            ON s.Id = gd.SalesId
    WHERE
        s.DocumentsTypeId IN (1, 3)
        AND gd.SalesId IS NULL
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
),

Dilimler AS (
    SELECT
        f.dilim AS dilim_kodu,
        SUM(f.isaret * (sp.TotalPrice + sp.DiscountTotalDirect + sp.DiscountTotalIndirect)) AS brut,
        SUM(f.isaret * (sp.DiscountTotalDirect + sp.DiscountTotalIndirect)) AS indirim,
        SUM(f.isaret * sp.TotalPrice) AS net_kdv_dahil
    FROM Fisler AS f
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON f.Id = sp.SalesId
        INNER JOIN EncoreMerkez.dbo.Products AS pr
            ON sp.ProductsId = pr.Id
        INNER JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN pr.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9
                    THEN CONVERT(INT, pr.Code)
            END
        INNER JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
            ON u.urnKtgr2ID = kt.ktgrID
    WHERE
        sp.IsValid = 1
        AND kt.ktgrAd <> N'Hediye Çeki'
    GROUP BY f.dilim
)

SELECT
    d.dilim_kodu AS Dilim,
    CONVERT(DECIMAL(18, 2), d.brut) AS Brut,
    CONVERT(DECIMAL(18, 2), d.indirim) AS Indirim,
    CONVERT(DECIMAL(18, 2), d.net_kdv_dahil) AS NetKdvDahil,
    CONVERT(DECIMAL(18, 2), d.brut - d.indirim - d.net_kdv_dahil) AS BrutEksiIndirimEksiNet
FROM Dilimler AS d
ORDER BY d.dilim_kodu;
/* tsqllint-enable non-sargable */
GO

-- blok: B  (KR-4 etkisi: kanonik 1001 fiş dışlaması ↔ panel kalem dışlaması; dilim bazlı fark)
/* tsqllint-disable non-sargable */
-- panel kuralı: RefundReasonId <> 12 VE Code <> '583160' olan kalem kalır
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
        INNER JOIN EncoreMerkez.dbo.Sales AS sg
            ON sp.SalesId = sg.Id
    WHERE
        sp.BarcodeNo = '1001'
        AND sg.[Date] >= @Bas
        AND sg.[Date] < @Bit
),

Hc AS (
    SELECT
        pt.SalesId,
        SUM(pt.Amount) AS hc_tutar
    FROM EncoreMerkez.dbo.SalesPayments AS pt
        INNER JOIN EncoreMerkez.dbo.Sales AS sh
            ON pt.SalesId = sh.Id
    WHERE
        pt.PaymentTypesId = 11
        AND pt.IsChangeAmount = 0
        AND sh.[Date] >= @Bas
        AND sh.[Date] < @Bit
    GROUP BY pt.SalesId
),

Satirlar AS (
    SELECT
        s.Id,
        CASE
            WHEN h.hc_tutar <= 100 THEN 1
            WHEN h.hc_tutar <= 250 THEN 2
            WHEN h.hc_tutar <= 500 THEN 3
            WHEN h.hc_tutar <= 1000 THEN 4
            WHEN h.hc_tutar <= 2500 THEN 5
            ELSE 6
        END AS dilim,
        CASE WHEN gd.SalesId IS NULL THEN 0 ELSE 1 END AS bin_bir_fisi,
        CASE WHEN sp.RefundReasonId = 12 OR pr.Code = '583160' THEN 1 ELSE 0 END AS panel_dislar,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice AS net_kdv_dahil
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN Hc AS h
            ON s.Id = h.SalesId
        LEFT JOIN Gd AS gd
            ON s.Id = gd.SalesId
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON s.Id = sp.SalesId
        INNER JOIN EncoreMerkez.dbo.Products AS pr
            ON sp.ProductsId = pr.Id
        INNER JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN pr.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9
                    THEN CONVERT(INT, pr.Code)
            END
        INNER JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
            ON u.urnKtgr2ID = kt.ktgrID
    WHERE
        s.DocumentsTypeId IN (1, 3)
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND sp.IsValid = 1
        AND kt.ktgrAd <> N'Hediye Çeki'
),

Dilimler AS (
    SELECT
        sa.dilim AS dilim_kodu,
        SUM(CASE WHEN sa.bin_bir_fisi = 0 THEN sa.net_kdv_dahil ELSE 0 END) AS kanonik_net,
        SUM(CASE WHEN sa.panel_dislar = 0 THEN sa.net_kdv_dahil ELSE 0 END) AS panel_net,
        COUNT(DISTINCT CASE WHEN sa.bin_bir_fisi = 0 AND sa.panel_dislar = 1 THEN sa.Id END) AS yalniz_panel_fis,
        COUNT(DISTINCT CASE WHEN sa.bin_bir_fisi = 1 AND sa.panel_dislar = 0 THEN sa.Id END) AS yalniz_kanonik_fis
    FROM Satirlar AS sa
    GROUP BY sa.dilim
)

SELECT
    d.dilim_kodu AS Dilim,
    CONVERT(DECIMAL(18, 2), d.kanonik_net) AS KanonikNet,
    CONVERT(DECIMAL(18, 2), d.panel_net) AS PanelDislamaNet,
    CONVERT(DECIMAL(18, 2), d.kanonik_net - d.panel_net) AS Fark,
    d.yalniz_panel_fis AS YalnizPanelDislarFis,
    d.yalniz_kanonik_fis AS YalnizKanonikDislarFis
FROM Dilimler AS d
ORDER BY d.dilim_kodu;
/* tsqllint-enable non-sargable */
GO

-- blok: E  (kategori dışlaması eşdeğerliği: panel UrunBilgi.KatAna ↔ kanonik urnKtgr2.ktgrAd; çek ürünü kalem ve tutar)
/* tsqllint-disable non-sargable */
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    CASE WHEN kt.ktgrAd = N'Hediye Çeki' THEN 1 ELSE 0 END AS UrnKtgr2Cek,
    CASE WHEN ub.KatAna = N'Hediye Çeki' THEN 1 ELSE 0 END AS UrunBilgiCek,
    COUNT(*) AS Kalem,
    CONVERT(DECIMAL(18, 2), SUM(sp.TotalPrice)) AS ToplamTutar
FROM EncoreMerkez.dbo.Sales AS s
    INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
        ON s.Id = sp.SalesId
    INNER JOIN EncoreMerkez.dbo.Products AS pr
        ON sp.ProductsId = pr.Id
    INNER JOIN DerinSISBkm.dbo.urn AS u
        ON u.stkID = CASE
            WHEN pr.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9
                THEN CONVERT(INT, pr.Code)
        END
    INNER JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
        ON u.urnKtgr2ID = kt.ktgrID
    LEFT JOIN DerinSISBkm.bkm.UrunBilgi AS ub
        ON u.stkID = ub.stkID
WHERE
    sp.IsValid = 1
    AND s.DocumentsTypeId IN (1, 3)
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
    AND (kt.ktgrAd = N'Hediye Çeki' OR ub.KatAna = N'Hediye Çeki')   -- ork:izin QRY-011 LEFT JOIN bilinçli (UrunBilgi'siz çek ürünü kalır)
GROUP BY
    CASE WHEN kt.ktgrAd = N'Hediye Çeki' THEN 1 ELSE 0 END,
    CASE WHEN ub.KatAna = N'Hediye Çeki' THEN 1 ELSE 0 END
ORDER BY UrnKtgr2Cek, UrunBilgiCek;
/* tsqllint-enable non-sargable */
GO

-- blok: K  (kimlik: Σ kalem (Direct + Indirect) ↔ Σ başlık DiscountTotal; Σ TotalPrice ↔ Σ (GrossTotal − DiscountTotal))
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Kalem AS (
    SELECT
        sp.SalesId,
        SUM(sp.DiscountTotalDirect) AS kalem_direct,
        SUM(sp.DiscountTotalIndirect) AS kalem_indirect,
        SUM(sp.DiscountTotalDirect + sp.DiscountTotalIndirect) AS kalem_indirim,
        SUM(sp.TotalPrice) AS kalem_net
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN EncoreMerkez.dbo.Sales AS sk
            ON sp.SalesId = sk.Id
    WHERE
        sp.IsValid = 1
        AND sk.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND sk.[Date] >= @Bas
        AND sk.[Date] < @Bit
    GROUP BY sp.SalesId
),

Cek AS (
    SELECT DISTINCT pt.SalesId
    FROM EncoreMerkez.dbo.SalesPayments AS pt
        INNER JOIN EncoreMerkez.dbo.Sales AS sc
            ON pt.SalesId = sc.Id
    WHERE
        pt.PaymentTypesId = 11
        AND pt.IsChangeAmount = 0
        AND sc.[Date] >= @Bas
        AND sc.[Date] < @Bit
)

SELECT
    CASE WHEN c.SalesId IS NULL THEN 0 ELSE 1 END AS CekOdemeli,
    s.DocumentsTypeId AS BelgeTipi,
    COUNT(*) AS Belge,
    CONVERT(DECIMAL(18, 2), SUM(s.DiscountTotal)) AS BaslikIndirim,
    CONVERT(DECIMAL(18, 2), SUM(ISNULL(k.kalem_direct, 0))) AS KalemDirect,
    CONVERT(DECIMAL(18, 2), SUM(ISNULL(k.kalem_indirect, 0))) AS KalemIndirect,
    CONVERT(DECIMAL(18, 2), SUM(ISNULL(k.kalem_indirim, 0))) AS KalemIndirim,
    CONVERT(DECIMAL(18, 2), SUM(s.DiscountTotal) - SUM(ISNULL(k.kalem_indirim, 0))) AS IndirimFarki,
    CONVERT(DECIMAL(18, 2), SUM(s.GrossTotal - s.DiscountTotal)) AS BaslikNetKdvDahil,
    CONVERT(DECIMAL(18, 2), SUM(ISNULL(k.kalem_net, 0))) AS KalemNetKdvDahil,
    CONVERT(DECIMAL(18, 2), SUM(s.GrossTotal - s.DiscountTotal) - SUM(ISNULL(k.kalem_net, 0))) AS NetFarki
FROM EncoreMerkez.dbo.Sales AS s
    LEFT JOIN Kalem AS k
        ON s.Id = k.SalesId
    LEFT JOIN Cek AS c
        ON s.Id = c.SalesId
WHERE
    s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
GROUP BY CASE WHEN c.SalesId IS NULL THEN 0 ELSE 1 END, s.DocumentsTypeId
ORDER BY CekOdemeli, BelgeTipi;
GO

-- blok: D  (dilim 1 yokluğu: fiş başına çek tahsilatı ≤ 100 TL olan fiş sayısı ve en küçük tahsilat; 'satır yok' ↔ '0 TL' ayrımı)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Hc AS (
    SELECT
        pt.SalesId,
        SUM(pt.Amount) AS hc_tutar
    FROM EncoreMerkez.dbo.SalesPayments AS pt
        INNER JOIN EncoreMerkez.dbo.Sales AS sh
            ON pt.SalesId = sh.Id
    WHERE
        pt.PaymentTypesId = 11
        AND pt.IsChangeAmount = 0
        AND sh.DocumentsTypeId IN (1, 3)
        AND sh.[Date] >= @Bas
        AND sh.[Date] < @Bit
    GROUP BY pt.SalesId
)

SELECT
    COUNT(*) AS CekFis,
    SUM(CASE WHEN h.hc_tutar <= 100 THEN 1 ELSE 0 END) AS Dilim1Fis,
    SUM(CASE WHEN h.hc_tutar <= 0 THEN 1 ELSE 0 END) AS SifirVeEksiFis,
    CONVERT(DECIMAL(18, 2), MIN(h.hc_tutar)) AS EnKucukCek
FROM Hc AS h;
GO

-- blok: N  (nüfus: tek satır; Eylül 2026)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    (
        SELECT COUNT(DISTINCT pt.SalesId)
        FROM EncoreMerkez.dbo.SalesPayments AS pt
            INNER JOIN EncoreMerkez.dbo.Sales AS s ON pt.SalesId = s.Id
        WHERE
            pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
            AND s.DocumentsTypeId IN (1, 3) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS cek_odemeli_fis,
    (
        SELECT COUNT(DISTINCT sp.SalesId)
        FROM EncoreMerkez.dbo.SalesProducts AS sp
            INNER JOIN EncoreMerkez.dbo.Sales AS s ON sp.SalesId = s.Id
            INNER JOIN EncoreMerkez.dbo.SalesPayments AS pt ON s.Id = pt.SalesId
        WHERE
            sp.BarcodeNo = '1001'
            AND pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
            AND s.DocumentsTypeId IN (1, 3) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS cek_odemeli_bin_bir_fis,
    (
        SELECT COUNT(DISTINCT sp.SalesId)
        FROM EncoreMerkez.dbo.SalesProducts AS sp
            INNER JOIN EncoreMerkez.dbo.Sales AS s ON sp.SalesId = s.Id
            INNER JOIN EncoreMerkez.dbo.SalesPayments AS pt ON s.Id = pt.SalesId
        WHERE
            sp.RefundReasonId = 12
            AND pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
            AND s.DocumentsTypeId IN (1, 3) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS cek_odemeli_sebep_12_fis;
