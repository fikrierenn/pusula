-- ork:hedef-db DerinSISBkm
-- ork:compat 150
/* Soru     : Üç mağazanın Eylül ciro toplamı, kanonik şube cirosuna (ERP irsHrk 100 − 101 + 4 − 5) yakın mı?
   AC       : AC-13.3 · Spec 001 · H13 · T-011 (kanonik formül)
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç); mekanID 1 FSM · 4477 Özlüce · 4478 İst.Yolu
   Çıktı    : (MekanId int, Ciro decimal) — blok A; parametre @Bas, @Bit
   Tolerans : AC-13.3 |fark| ≤ %0,30 (Tolerans.Oran 0.003m)
   Önce     : (04.10.2026, sqlcli encore profili, --read-only; panel storeSql Queries.cs :25-36 aynen, blok ONCE)
              FSM 44.666.847,33 · Özlüce 57.819.343,91 · İst.Yolu 367.452.392,84; toplam 469.938.584,08
   Sonra    : yok (düzeltme T-040, T-045 sonrası ölçülür)
   Bağımsız : (04.10.2026) A kanonik şube cirosu (irsHrk, ehAltDepo 0, ehTutarN): FSM 44.780.931,51 · Özlüce 57.869.853,03 ·
              İst.Yolu 367.899.546,71; toplam 470.550.331,25 (T-011 ve H07 A ile aynı).
              A1 bileşenler (tip: satır / tutar): FSM 4: 2.349 / 832.462,15 · 5: 108 / 50.608,65 · 100: 104.809 / 45.096.714,31 ·
              101: 2.997 / 1.097.636,30 · Özlüce 4: 4.791 / 1.196.767,55 · 5: 30 / 12.948,26 · 100: 136.754 / 57.973.642,93 ·
              101: 3.806 / 1.287.609,19 · İst.Yolu 4: 27.887 / 54.717.112,53 · 5: 172 / 230.775,09 · 100: 121.493 / 319.738.547,45 ·
              101: 4.783 / 6.325.338,18.
              C Encore başlık neti 1001 DAHİL: 44.564.381,60 · 57.704.918,42 · 367.362.099,96 (toplam 469.631.399,98);
              1001 HARİÇ (panel tanımı): 44.666.847,33 · 57.819.343,91 · 367.452.392,84 = ONCE ile birebir.
   Fark     : (Önce − Bağımsız, ölçüldü 04.10.2026) panel − kanonik = −611.747,17 = −%0,130 (02.10 ölçümü −%0,13 ile aynı);
              AC-13.3 eşiği %0,30 içinde. İki parça: M mutabakatı kanonik − Encore başlık neti (1001 dahil) = +918.931,27
              (FSM +216.549,91 · Özlüce +164.934,61 · İst.Yolu +537.446,75); 1001 belgelerinin dışlanması paneli Encore
              başlığından +307.184,10 yukarı çeker (469.938.584,08 − 469.631.399,98). Panel − kanonik = 307.184,10 − 918.931,27
              = −611.747,17. (02.10 notundaki "fark geri dönüşüm fişlerinin dışlanmasından" ifadesi eksikti: dışlama farkı
              küçültüyor, açan ERP'nin kasadan fazla olmasıdır.)
              Kaynak (dosya dışı: defter.md T-011 sql-inceleyici ölçümü, ertelendi → T-019; bu dosyada ölçülmedi — ÇIKARIM):
              ERP'de elle girilmiş eTip 4 − eTip 5; İst.Yolu'nda 19.09 ↔ 21.09 tarih kayması.
   Nüfus    : (blok N, 04.10.2026) irsHrk kanonik satır 409.979 · Encore mağaza neti belgesi (tip 1,2,3,6,7,8, tüm mağaza) 134.314.
              Nüfus > 0; 0 olsaydı sonuç 'bakamadım' okunurdu.
   Aynı kaynak — neden: Panel (Encore) ile kanonik (irsHrk) farklı sistemlerdir: kasa ve ERP. İki kaynak bağımsızdır; ERP kasadan
              saatlik aktarımla beslenir (sql-server-conventions § KASA → ERP AKTARIMI), Eylül kapalıdır. Kanonik tanım H07 A ile
              aynı sorgudur (tanım kimliği, ayrı kanıt değil).
   Başka ne olabilir: (1) Fark gün içi aktarım değil: kapalı günlerde kasa ve ERP kuruşu kuruşuna tutar,
              aktarım saatliktir (sql-server-conventions § KASA → ERP AKTARIMI); Eylül kapalı. (2) Fark KDV tabanı
              değil: iki taraf da KDV hariç; iade tarafı
              ehTip 101 = Encore tip 3 (1001 dahil) üç mağazada birebir (A1 101 satırı = H06 C1). (3) Fark satış tarafında;
              kaynağı (elle girilmiş eTip 4/5) bu dosyada ölçülmedi — T-011 bulgusudur, ÇIKARIM olarak taşınır. (4) Kasa mutabakatında
              100−101 tek başına yetmez, eTip 4 eklenmeli (sema codes/metrics MEKAN_CIRO_MUTABAKAT_FORMULU): kanonik formül Sınav
              faturasını da taşır, panel Net tip 8'i içerir; iki taraf aynı kapsamda.
   Kapsam   : A = irsHrk ehTip 100 − 101 + 4 − 5, ehMekan IN (1,4477,4478), ehAltDepo = 0, ehTutarN (KDV hariç). C ve ONCE =
              Encore Sales tip 1,2,3,6,7,8, iade negatif, GrossTotal − DiscountTotal − VatTotal; ONCE 1001 barkodlu belge hariç.
   Dondurma : 01b8381
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; bloklar GO'suz ve DECLARE'siz, @Bas/@Bit literalle değiştirilerek
              koşuldu (SSMS DECLARE + GO esas); hepsi --profile encore (DerinSISBkm üç parçalı ad), --max-rows 1000.
   Bloklar  : A kanonik şube cirosu · A1 mağaza × tip kırılımı · C Encore başlık neti (1001 dahil/hariç) · M kanonik − Encore
              mutabakatı · ONCE panel gövdesi · N nüfus. Boş nüfus 'bakamadım'dır, 'temiz' değil.
*/

-- blok: A  (kanonik şube cirosu: irsHrk 100 − 101 + 4 − 5, üç mağaza, ehAltDepo = 0, ehTutarN; mağaza başına)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    h.ehMekan AS MekanId,
    CONVERT(DECIMAL(18, 2), SUM(
        CASE
            WHEN h.ehTip IN (100, 4) THEN h.ehTutarN
            WHEN h.ehTip IN (101, 5) THEN -h.ehTutarN
            ELSE 0
        END
    )) AS Ciro
FROM DerinSISBkm.dbo.irsHrk AS h
WHERE
    h.ehTip IN (100, 101, 4, 5)
    AND h.ehMekan IN (1, 4477, 4478)
    AND h.ehAltDepo = 0
    AND h.ehTrhS >= @Bas
    AND h.ehTrhS < @Bit
GROUP BY h.ehMekan
ORDER BY h.ehMekan;
GO

-- blok: A1  (mağaza × tip kırılımı; A'nın bileşenleri)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    h.ehMekan AS MekanId,
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

-- blok: C  (Encore başlık neti, 1001 DAHİL ve 1001 HARİÇ yan yana; iade negatif; mağaza başına)
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
)

SELECT
    mg.mekanID AS [MekanId],
    CONVERT(DECIMAL(18, 2), SUM(
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal)
    )) AS NetBinBirDahil,
    CONVERT(DECIMAL(18, 2), SUM(
        CASE
            WHEN gd.SalesId IS NOT NULL THEN 0
            WHEN s.DocumentsTypeId = 3 THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
            ELSE s.GrossTotal - s.DiscountTotal - s.VatTotal
        END
    )) AS NetBinBirHaric
FROM EncoreMerkez.dbo.Sales AS s
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
    LEFT JOIN Gd AS gd
        ON s.Id = gd.SalesId
WHERE
    mg.mekanID IN (1, 4477, 4478)
    AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
GROUP BY mg.mekanID
ORDER BY mg.mekanID;
GO

-- blok: M  (mutabakat: kanonik ERP ciro − Encore başlık neti, mağaza başına ve toplam; aynı sunucu, tek sorgu)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Erp AS (
    SELECT
        h.ehMekan AS mekan_id,
        SUM(
            CASE
                WHEN h.ehTip IN (100, 4) THEN h.ehTutarN
                ELSE -h.ehTutarN
            END
        ) AS ciro
    FROM DerinSISBkm.dbo.irsHrk AS h
    WHERE
        h.ehTip IN (100, 101, 4, 5)
        AND h.ehMekan IN (1, 4477, 4478)
        AND h.ehAltDepo = 0
        AND h.ehTrhS >= @Bas
        AND h.ehTrhS < @Bit
    GROUP BY h.ehMekan
),

Enc AS (
    SELECT
        mg.mekanID AS mekan_id,
        SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal)) AS net
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
        AND s.[Date] < @Bit
    GROUP BY mg.mekanID
)

SELECT
    e.mekan_id AS MekanId,
    CONVERT(DECIMAL(18, 2), e.ciro) AS KanonikCiro,
    CONVERT(DECIMAL(18, 2), n.net) AS EncoreBaslikNet,
    CONVERT(DECIMAL(18, 2), e.ciro - n.net) AS Fark
FROM Erp AS e
    INNER JOIN Enc AS n
        ON e.mekan_id = n.mekan_id
UNION ALL
SELECT
    0 AS MekanId,
    CONVERT(DECIMAL(18, 2), SUM(e2.ciro)) AS KanonikCiro,
    CONVERT(DECIMAL(18, 2), SUM(n2.net)) AS EncoreBaslikNet,
    CONVERT(DECIMAL(18, 2), SUM(e2.ciro - n2.net)) AS Fark
FROM Erp AS e2
    INNER JOIN Enc AS n2
        ON e2.mekan_id = n2.mekan_id
ORDER BY MekanId;
GO

-- noqa: disable=all
/* tsqllint-disable */
-- blok: ONCE  (panel storeSql :25-36 aynen; @start → @Bas, @end → @Bit; panel gövdesi, biçim kurallarından muaf)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT MG.mekanID AS MekanId,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) AS Fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN (s.GrossTotal-s.DiscountTotal-s.VatTotal) ELSE 0 END) AS Iade
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=@Bas AND s.Date<@Bit
GROUP BY MG.mekanID;
GO
/* tsqllint-enable */
-- noqa: enable=all

-- blok: N  (nüfus: tek satır; Eylül 2026, üç mağaza)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    (
        SELECT COUNT(*)
        FROM DerinSISBkm.dbo.irsHrk AS h
        WHERE
            h.ehTip IN (100, 101, 4, 5)
            AND h.ehMekan IN (1, 4477, 4478)
            AND h.ehAltDepo = 0
            AND h.ehTrhS >= @Bas
            AND h.ehTrhS < @Bit
    ) AS irshrk_kanonik_satir,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS encore_magaza_neti_belge_tum_magaza;
