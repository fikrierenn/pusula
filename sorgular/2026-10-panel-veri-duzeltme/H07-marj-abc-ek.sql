-- ork:hedef-db DerinSISBkm
-- ork:compat 150
/* Soru     : H07-marj-abc.sql başlığındaki A − C farkı, merkez depo 'adet 0', maliyetsiz satır, ABC farkı ve B − C ayrışması
              hangi ölçümden geliyor? Ana dosya: H07-marj-abc.sql (20 KB sınırı nedeniyle ara ölçümler burada).
   AC       : AC-7.1, AC-7.2, AC-7.3 · Spec 001 · H07 · T-019 düzeltme geçişi
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç); mekanID 1 FSM · 4477 Özlüce · 4478 İst.Yolu
   UYARI    : muhasebe açık dönem — maliyet Eylül için değişebilir; M bloğu maliyetsiz ciro taşır, diğerleri maliyetten bağımsız.
   Tolerans : tutar ≤ 1 TL
   Önce     : yok (ara ölçüm dosyası; panel gövdeleri H07-marj-abc.sql ONCE-* bloklarında)
   Sonra    : yok
   Bağımsız : (04.10.2026, ölçüldü)
              GUN A − C (ERP irsHrk 100 − 101 + 4 − 5 ↔ Encore tüm tipler, mağaza × gün, 90 satır): aylık Σ FSM +216.549,91 ·
                Özlüce +164.934,61 · İst.Yolu +537.446,75 (= ana dosya A − C; gün satırları GUN bloğunda).
              KISI eTip 4 ve 5 belgelerinin tamamı elle girilmiş: gKisi = 31 (POS aktarım kullanıcısı) yalnız eTip 100 ve 101'de
                (Eylül 3 mağaza 90 belge); eTip 4 ve 5'te hiçbir belgede yok. ERP eTip 4 − 5: FSM 832.462,15 − 50.608,65 = 781.853,50 ·
                Özlüce 1.196.767,55 − 12.948,26 = 1.183.819,29 · İst.Yolu 54.717.112,53 − 230.775,09 = 54.486.337,44.
                ERP 100 − 101 tek başına Encore tüm tiplerin altında (FSM −565.303,59: 43.999.078,01 ↔ 44.564.381,60); elle girilen
                4 − 5 farkı kapatır ve aşar (kalan = yukarıdaki +216.549,91 · +164.934,61 · +537.446,75).
                Örnek FSM 01.09: ERP eTip 4 belgesi 2.334,48 · 8.932,00 · 6.661,61 ↔ Encore tip 2 (fatura) 2.334,49 · 8.932,01 ·
                6.661,62 (kuruş farkı; ÖRNEK, tam eşleşme ölçülmedi). Eski başlıktaki 'Sınav faturaları ERP'de fazla' cümlesi
                Özlüce ve FSM'de desteklenmiyor (Sınav 0). Gün düzeyinde kalan fark (FSM 0,46 TL, Özlüce 1,05 TL; İst.Yolu 19.09 ↔
                21.09 tarih kayması): dosya dışı: T-011 sql-inceleyici ölçümü, bu dosyada yeniden üretilmedi.
              D merkez depo (irsAyr eTip 1, eMekan 12): 4.959 satır, ciro (ehTutar − ehIndirim) 82.609.479,97; irsAyr.ehAdetN toplamı
                0,00 (4.959 satırın 4.959'u 0); irsAyr.ehAdet −327.868 ve irsHrk.ehAdetN −327.868 dolu (D_HRK 4.890 satır). 'Adet 0'
                yalnız irsAyr.ehAdetN için doğrudur.
              M 3 mağaza irsAyr cirosu (eTip 1,4,100): 479.566.626,92 (398.087 satır); maliyeti bilinen kısım 219,45M
                (ana dosya ONCE-MARJ-3, %45,8): panelin COALESCE süzgeci farkı ortaya çıkarır.
              B_NEG Encore iade (tip 3, 1001 hariç, 3 mağaza) net 8.403.221,07 (KDV hariç; ana dosyadaki 8,70M GrossTotal tabanlıydı);
                1001 kalemleri net −307.184,10; iade sonrası net ≤ 0 olan 344 ürünün toplamı −17.519,60.
              ABC_FARK panel 478.341.805,15 = 3 mağazaya daraltılmış panel 478.341.805,15 (mağaza süzgeci etkisi (b) 0,00);
                iade düşülünce 469.938.584,08 (iade etkisi (a) 8.403.221,07); HAVING (c) +17.519,60 → B 469.956.103,68.
                Toplam fark 8.385.701,47 = 8.403.221,07 − 17.519,60. B − C = 324.703,70 = 307.184,10 + 17.519,60.
   Nüfus    : yok (H07-marj-abc.sql blok N geçerli; GUN 90 satır dönmelidir).
   Aynı kaynak — neden: GUN ve KISI, A tarafını Encore ile karşılaştırır (iki bağımsız kaynak). D, M, B_NEG, ABC_FARK ana
              dosyadaki panel gövdelerinin kırılımıdır (kaynak içi kimlik, bağımsız kanıt değil).
   Başka ne olabilir: (1) A − C farkı tek mekanizmadan gelmeyebilir (fatura çift kaydı, tarih kayması, personel fişi);
              mekanizma kanıtlanmadı, ÇIKARIM. (2) Maliyetsiz satırlar yeni ürün olabilir.
   Kapsam   : A = irsHrk ehTip 100 − 101 + 4 − 5, ehAltDepo = 0, ehTutarN; Encore = Sales net (Gross − Discount − Vat), iade negatif.
   Dondurma : (denetleyici ekler)
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; literal tarihle koşuldu; hepsi --profile erp (aynı sunucuda Encore da okunur).
   Bloklar  : GUN gün × mağaza A − C · KISI eTip 4/5 kullanıcı kırılımı · D merkez depo adet · M 3 mağaza ciro
              · B_NEG iade, 1001, net ≤ 0 ürün · ABC_FARK panel ↔ B ayrışması
*/

-- blok: GUN  (gün × mağaza: ERP 100−101, ERP 4−5, Encore tip 1+3, Encore tip 2+6+7+8, A − C)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Erp AS (
    SELECT
        h.ehMekan AS mekan,
        CONVERT(DATE, h.ehTrhS) AS gun,
        SUM(CASE WHEN h.ehTip = 100 THEN h.ehTutarN WHEN h.ehTip = 101 THEN -h.ehTutarN ELSE 0 END) AS e100_101,
        SUM(CASE WHEN h.ehTip = 4 THEN h.ehTutarN WHEN h.ehTip = 5 THEN -h.ehTutarN ELSE 0 END) AS e4_5
    FROM DerinSISBkm.dbo.irsHrk AS h
    WHERE
        h.ehTip IN (100, 101, 4, 5)
        AND h.ehMekan IN (1, 4477, 4478)
        AND h.ehAltDepo = 0
        AND h.ehTrhS >= @Bas
        AND h.ehTrhS < @Bit
    GROUP BY h.ehMekan, CONVERT(DATE, h.ehTrhS)
),

Enc AS (
    SELECT
        mg.mekanID AS mekan,
        CONVERT(DATE, s.[Date]) AS gun,
        SUM(CASE
            WHEN s.DocumentsTypeId = 3 THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
            WHEN s.DocumentsTypeId = 1 THEN (s.GrossTotal - s.DiscountTotal - s.VatTotal)
            ELSE 0
        END) AS enc_1_3,
        SUM(CASE
            WHEN s.DocumentsTypeId IN (2, 6, 7, 8) THEN (s.GrossTotal - s.DiscountTotal - s.VatTotal)
            ELSE 0
        END) AS enc_2678
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
    GROUP BY mg.mekanID, CONVERT(DATE, s.[Date])
)

SELECT
    e.mekan AS MekanId,
    CONVERT(VARCHAR(10), e.gun, 104) AS Gun,
    CONVERT(DECIMAL(18, 2), e.e100_101) AS Erp_100_101,
    CONVERT(DECIMAL(18, 2), e.e4_5) AS Erp_4_5,
    CONVERT(DECIMAL(18, 2), ISNULL(n.enc_1_3, 0)) AS Enc_1_3,
    CONVERT(DECIMAL(18, 2), ISNULL(n.enc_2678, 0)) AS Enc_2678,
    CONVERT(DECIMAL(18, 2), e.e100_101 + e.e4_5 - ISNULL(n.enc_1_3, 0) - ISNULL(n.enc_2678, 0)) AS Fark
FROM Erp AS e
    LEFT JOIN Enc AS n
        ON e.mekan = n.mekan AND e.gun = n.gun
ORDER BY e.mekan, e.gun;
GO

-- blok: KISI  (eTip 4 ve 5 belgeleri: mağaza × giren kullanıcı; gKisi = 31 yalnız 100/101'de)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    i.eMekan AS Mekan,
    i.eTip AS Tip,
    i.gKisi AS KisiId,
    LTRIM(RTRIM(ISNULL(d.insAd, '') + ' ' + ISNULL(d.insSoyad, ''))) AS Kisi,
    COUNT(DISTINCT i.eID) AS Belge,
    CONVERT(DECIMAL(18, 2), SUM(h.ehTutarN)) AS Tutar
FROM DerinSISBkm.dbo.irs AS i
    INNER JOIN DerinSISBkm.dbo.irsHrk AS h
        ON i.eID = h.ehID
    LEFT JOIN DerinSISBkm.dbo.drn1 AS d
        ON i.gKisi = d.insID
WHERE
    h.ehTip IN (4, 5)
    AND h.ehMekan IN (1, 4477, 4478)
    AND h.ehAltDepo = 0
    AND h.ehTrhS >= @Bas
    AND h.ehTrhS < @Bit
GROUP BY i.eMekan, i.eTip, i.gKisi, LTRIM(RTRIM(ISNULL(d.insAd, '') + ' ' + ISNULL(d.insSoyad, '')))
ORDER BY i.eMekan ASC, i.eTip ASC, Tutar DESC;
GO

-- blok: D  (merkez depo toptanı, irsAyr eTip 1 eMekan 12: satır, ciro, üç adet kolonu)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    COUNT(*) AS Satir,
    CONVERT(DECIMAL(18, 2), SUM(a.ehTutar - a.ehIndirim)) AS Ciro,
    SUM(CASE WHEN a.ehAdetN = 0 THEN 1 ELSE 0 END) AS AdetN_Sifir_Satir,
    CONVERT(DECIMAL(18, 2), SUM(a.ehAdetN)) AS AyrAdetN,
    CONVERT(DECIMAL(18, 2), SUM(a.ehAdet)) AS AyrAdet
FROM DerinSISBkm.dbo.irs AS i
    INNER JOIN DerinSISBkm.dbo.irsAyr AS a
        ON i.eID = a.ehID
WHERE
    i.eTip = 1
    AND i.eMekan = 12
    AND i.eTarih >= @Bas
    AND i.eTarih < @Bit;
GO

-- blok: D_HRK  (aynı belgelerin irsHrk adedi; ehAdetN dolu mu)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    COUNT(*) AS HrkSatir,
    CONVERT(DECIMAL(18, 2), SUM(h.ehAdetN)) AS HrkAdetN,
    CONVERT(DECIMAL(18, 2), SUM(h.ehTutarN)) AS HrkTutarN
FROM DerinSISBkm.dbo.irs AS i
    INNER JOIN DerinSISBkm.dbo.irsHrk AS h
        ON i.eID = h.ehID
WHERE
    i.eTip = 1
    AND i.eMekan = 12
    AND i.eTarih >= @Bas
    AND i.eTarih < @Bit;
GO

-- blok: M  (3 mağaza irsAyr cirosu, eTip 1,4,100; panel kategori bağıyla; maliyeti bilinen kısım H07-marj-abc.sql ONCE-MARJ-3)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    CONVERT(DECIMAL(18, 2), SUM(a.ehTutar - a.ehIndirim)) AS Ciro3Magaza,
    COUNT(*) AS Satir,
    COUNT(DISTINCT a.ehStkID) AS Urun
FROM DerinSISBkm.dbo.irs AS i
    INNER JOIN DerinSISBkm.dbo.irsAyr AS a
        ON i.eID = a.ehID
    INNER JOIN DerinSISBkm.dbo.urn AS u
        ON a.ehStkID = u.stkID
    INNER JOIN DerinSISBkm.dbo.urnKtgr2 AS k2
        ON u.urnKtgr2ID = k2.ktgrID
WHERE
    i.eTip IN (1, 4, 100)
    AND i.eMekan IN (1, 4478, 4477)
    AND i.eTarih >= @Bas
    AND i.eTarih < @Bit;
GO

-- blok: B_NEG  (Encore: iade net, 1001 net, iade sonrası net ≤ 0 ürünlerin toplamı; 3 mağaza)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Kalem AS (
    SELECT
        sp.ProductsId,
        sp.BarcodeNo,
        s.DocumentsTypeId AS tip,
        (sp.TotalPrice - sp.VatTotal) AS net
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
        AND mg.mekanID IN (1, 4477, 4478)
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
),

Urun AS (
    SELECT
        k.ProductsId,
        SUM(CASE WHEN k.tip = 3 THEN -k.net ELSE k.net END) AS net
    FROM Kalem AS k
    WHERE k.BarcodeNo <> '1001'
    GROUP BY k.ProductsId
)

SELECT
    CONVERT(DECIMAL(18, 2), (
        SELECT SUM(k.net)
        FROM Kalem AS k
        WHERE
            k.tip = 3
            AND k.BarcodeNo <> '1001'
    )) AS IadeNet1001Haric,
    CONVERT(DECIMAL(18, 2), (
        SELECT SUM(CASE WHEN k.tip = 3 THEN -k.net ELSE k.net END)
        FROM Kalem AS k
        WHERE k.BarcodeNo = '1001'
    )) AS Bin1001Net,
    CONVERT(DECIMAL(18, 2), (
        SELECT SUM(u.net)
        FROM Urun AS u
        WHERE u.net <= 0
    )) AS NetEksiUrunToplam,
    (
        SELECT COUNT(*)
        FROM Urun AS u
        WHERE u.net <= 0
    ) AS NetEksiUrunSayisi;
GO

-- blok: ABC_FARK  (panel ABC toplamı ↔ B: mağaza süzgeci, iade, HAVING ayrı ayrı)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Panel0 AS (   -- panel kapsamı: mağaza süzgeci yok, tip 1,2,6,7,8, 1001 kalemi hariç, HAVING > 0
    SELECT
        sp.ProductsId,
        SUM(sp.TotalPrice - sp.VatTotal) AS net
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON sp.SalesId = s.Id
    WHERE
        sp.IsValid = 1
        AND sp.BarcodeNo <> '1001'
        AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
    GROUP BY sp.ProductsId
    HAVING SUM(sp.TotalPrice - sp.VatTotal) > 0
),

Panel1 AS (   -- aynı, yalnız üç mağaza
    SELECT
        sp.ProductsId,
        SUM(sp.TotalPrice - sp.VatTotal) AS net
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
        AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
    GROUP BY sp.ProductsId
    HAVING SUM(sp.TotalPrice - sp.VatTotal) > 0
),

Tum AS (   -- üç mağaza, iade negatif, HAVING yok
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
)

SELECT
    CONVERT(DECIMAL(18, 2), (SELECT SUM(x.net) FROM Panel0 AS x)) AS Panel,
    CONVERT(DECIMAL(18, 2), (SELECT SUM(x.net) FROM Panel1 AS x)) AS PanelUcMagaza,
    CONVERT(DECIMAL(18, 2), (SELECT SUM(x.net) FROM Tum AS x)) AS IadeliHavingsiz,
    CONVERT(DECIMAL(18, 2), (
        SELECT SUM(x.net)
        FROM Tum AS x
        WHERE x.net > 0
    )) AS B;
GO
