-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Kasiyer tablosu ve kategori karması, mağaza netiyle aynı kapsamı (mağaza, belge tipi, 1001) kullanıyor mu?
   AC       : D-2 · Spec 001 · KR-1 (1001 fiş dışlaması) · FR-006
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç)
   Tolerans : ≤ 1,00 TL (Σ kasiyer net = Σ mağaza net)
   Önce     : (04.10.2026; panel gövdeleri D2-kasiyer-once.sql dosyasında, sqlfluff 20.000 bayt sınırı için ayrıldı)
              ONCE-MAG Net: FSM 44.666.847,33 · Özlüce 57.819.343,91 · İst.Yolu 367.452.392,84
              ONCE-KAS (1001 DAHİL, ad bazlı) Σ Net: 44.564.381 (8 satır) · 57.704.918 (14) · 367.362.101 (13)
              ONCE-SAAT: 14 saat · Fiş 124.402 · Net 469.631.399 · ONCE-KAT: 18 kategori · Σ Ciro 469.924.828
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : (04.10.2026) M2 ERP (100 − 101 + 4 − 5): 44.780.931,51 · 57.869.853,03 · 367.899.546,71 (Encore'dan +%0,26 · +%0,09 · +%0,12);
              ERP ayrı sistemdir (kasadan saatlik aktarım); tanım farkı var, eşitlik KANITI DEĞİL, fark bu dosyada açıklanmadı.
   Kaynak içi kimlik (bağımsız DEĞİL, aynı Encore Sales başlığı): (04.10.2026)
              A Σ kasiyer net: FSM 44.666.847,33 (8 kasiyer) · Özlüce 57.819.343,91 (14) · İst.Yolu 367.452.392,84 (15).
              M mağaza neti: üç mağazada A ile birebir (fark 0,00); Σ 469.938.584,08.
              S saat: 14 saat · Fiş 126.253 · Net 469.938.584,08 (= M toplamı).
              K kapsam dışı belge yok: Eylül 134.314 belgenin tamamı üç mağazaya bağlı (N ile aynı).
              G 1001 fişleri: Fiş 571 · 759 · 523; işaretli başlık neti FSM −102.465,73 · Özlüce −114.425,49 · İst.Yolu −90.292,88
                (Σ −307.184,10); 1001 kalemi 573 · 760 · 536; 1001 dışı geçerli kalem 0 · 0 · 0.
              B kategori karması: BaşlıkNet = KalemNet (fark 0,00, üç mağaza); KategoriKapsamNet 44.664.857,36 · 57.808.407,22
                · 367.451.563,69 (Σ 469.924.828,27); kategoriye girmeyen kalem 1.989,97 · 10.936,69 · 829,15 (Σ 13.755,81).
   Taban 1  : AC değerlendirme tabanı = panel ↔ ERP: panel mağaza neti (Encore, 1001 HARİÇ, ONCE-MAG = M) ↔ ERP M2:
              ERP − panel +114.084,18 · +50.509,12 · +447.153,87 (Encore'a göre +%0,26 · +%0,09 · +%0,12).
   Taban 2  : AYNI kapsam: Encore 1001 DAHİL (M + G: 44.564.381,60 · 57.704.918,42 · 367.362.099,96) ↔ ERP M2:
              ERP − Encore +216.549,91 · +164.934,61 · +537.446,75 (Encore'a göre +%0,49 · +%0,29 · +%0,15); yalnız kasa ↔ ERP
              farkını gösterir, AC buradan değerlendirilmez. İki taban arasındaki fark 1001 fişlerinin işaretli netidir (G).
   Fark     : (Önce − Bağımsız, ölçüldü 04.10.2026)
              Kasiyer: panel − kanonik = −102.466 · −114.426 · −90.292 (yuvarlama dahil) = G'deki 1001 fişlerinin işaretli neti.
              Saat: Net −307.185 (= G Σ −307.184,10), Fiş −1.851 (1.853 fişin 1.852'si iade).
              Kategori: panel Σ 469.924.828 = B KategoriKapsamNet Σ (fark 0,27); mağaza netinden 13.755,81 TL eksik.
              Y (ölçüldü): eksik tek ürün, Products.Id 800625 / Code 1670694 (81 kalem, 13.755,81 TL); urn/urnKtgr2'de eşleşmesi yok.
              U (ölçüldü): İst.Yolu'nda aynı adı taşıyan UsersId çiftleri: 68 (29 belge) + 70 (4.870); 9 (108) + 10 (35).
              Panel ad bazlı gruplayıp 15 kimliği 13 satıra indirir (belge sayıları 1001 hariç; panelde 1001 dahil).
              Test notu: A ↔ M yapı gereği 0,00 (kaynak içi, kanıt DEĞİL); ayırt edici olan ONCE-KAS ↔ kanonik sapmasıdır.
   Aynı kaynak — neden: Kasiyer ve kalem düzeyi yalnız Encore'da var; ERP'de POS özet belgedir. Σ kasiyer = Σ mağaza aynı
              Sales başlığından kurulur (kaynak içi, bağımsız DEĞİL): sınadığı kapsam eşitliğidir. Kalem toplamı (blok B) da
              kaynak içi kimliktir. Bağımsız yön yalnız ERP defteri (blok M2; tanım farkı var, eşitlik KANITI DEĞİL).
   Fiş tanımı: blok S Fiş = tip 1,2,3,6,7,8 işaretli (iade −1), 1001 hariç (Home biçimi); bu H05-fis.sql fişi DEĞİLDİR
              (H05: yalnız tip 1, 1001 yok; iade ayrı). 126.253 ile H05 sayıları karşılaştırılmaz.
   Başka ne olabilir: (1) Mağaza yolu (s.StoresId ↔ Pos.StoreId): K Net'i 44.564.381,60 = ONCE-KAS 44.564.381, yol aynı.
              (2) İade formülü (panel ABS(Discount)): aynı net ifadesi 1001 dahil kümede panelle aynı, etki yok.
              (3) Mağaza kümesi dışı belge: K'da 0. (4) Kasiyer satırı 13 ↔ 15: ad çakışması, U'da ölçüldü.
              (5) Kategori eksiği: tek ürün, Y'de ölçüldü. (6) M2 farkının kaynağı ölçülmedi; ERP eşitliği iddia edilmez.
   Kapsam   : Mağaza = Pos -> Stores -> posMagaza (1, 4477, 4478). Belge tipi 1,2,3,6,7,8; iade negatif. Net = GrossTotal −
              DiscountTotal − VatTotal (KDV hariç). 1001 fişi bütünüyle dışarıda (KR-1). Kasiyer = Sales.UsersId (ad yok).
   Dondurma : 18c2ce0
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; DECLARE'siz, literalle, --profile encore.
   Bloklar  : A kasiyer neti (MekanId, KasiyerNet) · M mağaza neti · M2 ERP · B kategori karması · K kapsam dışı belge
              · G 1001 fişleri · S saat · N nüfus. U (ad çakışması) ve Y (kategoriye bağlanmayan ürün): D2-kasiyer-ek.sql;
              ONCE blokları: D2-kasiyer-once.sql. Boş nüfus 'bakamadım'dır.
*/

-- blok: A  (kasiyer neti mağazaya toplanmış; arayüz (MekanId, KasiyerNet))
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

Kas AS (
    SELECT
        mg.mekanID,
        s.UsersId,
        SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal)) AS net
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
        AND gd.SalesId IS NULL
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
    GROUP BY mg.mekanID, s.UsersId
)

SELECT
    k.mekanID AS [MekanId],
    COUNT(*) AS KasiyerSayisi,
    CONVERT(DECIMAL(18, 2), SUM(k.net)) AS KasiyerNet
FROM Kas AS k
GROUP BY k.mekanID
ORDER BY k.mekanID;
GO

-- blok: M  (mağaza neti, kasiyer boyutu yok; Ana sayfa kartı kapsamı; A ile fark 0 beklenir)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    mg.mekanID AS [MekanId],
    CONVERT(DECIMAL(18, 2), SUM(
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal)
    )) AS MagazaNet
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
    AND NOT EXISTS (
        SELECT 1
        FROM EncoreMerkez.dbo.SalesProducts AS sb   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
        WHERE sb.SalesId = s.Id AND sb.BarcodeNo = '1001'
    )
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
GROUP BY mg.mekanID
ORDER BY mg.mekanID;
GO

-- blok: M2  (referans: ERP defteri 100 − 101 + 4 − 5; tanım ve aktarım farkı nedeniyle eşitlik beklenmez)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    h.ehMekan AS MekanId,
    CONVERT(DECIMAL(18, 2), SUM(
        CASE
            WHEN h.ehTip IN (100, 4) THEN h.ehTutarN
            WHEN h.ehTip IN (101, 5) THEN -h.ehTutarN
            ELSE 0
        END
    )) AS ErpNet
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

-- blok: B  (kategori karması: başlık net ↔ kalem net ↔ kategoriye eşleşen kalem net; ürün kodu T-014 kuralı)
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

Fisler AS (
    SELECT
        s.Id,
        mg.mekanID,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END AS isaret,
        s.GrossTotal - s.DiscountTotal - s.VatTotal AS baslik_net
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
        AND gd.SalesId IS NULL
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
),

Kalem AS (
    SELECT
        f.mekanID,
        f.isaret * (sp.TotalPrice - sp.VatTotal) AS kalem_net,
        CASE
            WHEN
                pr.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9
                AND EXISTS (
                    SELECT 1
                    FROM DerinSISBkm.dbo.urn AS u
                        INNER JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
                            ON u.urnKtgr2ID = kt.ktgrID
                    WHERE u.stkID = CASE
                        WHEN pr.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9
                            THEN CONVERT(INT, pr.Code)
                    END
                )
                THEN 1
            ELSE 0
        END AS kategoriye_girer
    FROM Fisler AS f
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON f.Id = sp.SalesId
        INNER JOIN EncoreMerkez.dbo.Products AS pr
            ON sp.ProductsId = pr.Id
    WHERE sp.IsValid = 1
),

BaslikNet AS (
    SELECT
        f.mekanID,
        SUM(f.isaret * f.baslik_net) AS baslik_net
    FROM Fisler AS f
    GROUP BY f.mekanID
),

KalemNet AS (
    SELECT
        k.mekanID,
        SUM(k.kalem_net) AS kalem_net,
        SUM(CASE WHEN k.kategoriye_girer = 1 THEN k.kalem_net ELSE 0 END) AS kategori_kapsam_net
    FROM Kalem AS k
    GROUP BY k.mekanID
)

SELECT
    b.mekanID AS [MekanId],
    CONVERT(DECIMAL(18, 2), b.baslik_net) AS BaslikNet,
    CONVERT(DECIMAL(18, 2), kn.kalem_net) AS KalemNet,
    CONVERT(DECIMAL(18, 2), kn.kategori_kapsam_net) AS KategoriKapsamNet,
    CONVERT(DECIMAL(18, 2), b.baslik_net - kn.kalem_net) AS BaslikMinusKalem,
    CONVERT(DECIMAL(18, 2), kn.kalem_net - kn.kategori_kapsam_net) AS KategoriyeGirmeyenKalem
FROM BaslikNet AS b
    INNER JOIN KalemNet AS kn
        ON b.mekanID = kn.mekanID
ORDER BY b.mekanID;
/* tsqllint-enable non-sargable */
GO

-- blok: K  (mağaza kümesi dışı belge: üç mağazaya bağlanmayan Eylül belgeleri; panel kasiyer ve kategori sorgusu sayar)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    ISNULL(mg.mekanID, 0) AS MekanId,
    CASE WHEN mg.mekanID IN (1, 4477, 4478) THEN 1 ELSE 0 END AS KapsamIci,
    COUNT(*) AS Belge,
    CONVERT(DECIMAL(18, 2), SUM(
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal)
    )) AS Net
FROM EncoreMerkez.dbo.Sales AS s
    LEFT JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    LEFT JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    LEFT JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
WHERE
    s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
GROUP BY ISNULL(mg.mekanID, 0), CASE WHEN mg.mekanID IN (1, 4477, 4478) THEN 1 ELSE 0 END
ORDER BY ISNULL(mg.mekanID, 0);
GO

-- blok: G  (1001 fişleri: fiş, 1001 kalemi, 1001 dışı geçerli kalem, işaretli başlık neti)
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

Fis AS (
    SELECT
        s.Id,
        mg.mekanID,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal) AS baslik_net
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN Gd AS gd
            ON s.Id = gd.SalesId
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
),

Kalem AS (
    SELECT
        sk.SalesId,
        SUM(CASE WHEN sk.BarcodeNo = '1001' THEN 1 ELSE 0 END) AS bin_bir_kalem,
        SUM(CASE WHEN sk.BarcodeNo <> '1001' AND sk.IsValid = 1 THEN 1 ELSE 0 END) AS diger_gecerli_kalem
    FROM EncoreMerkez.dbo.SalesProducts AS sk
        INNER JOIN Gd AS gk
            ON sk.SalesId = gk.SalesId
    GROUP BY sk.SalesId
)

SELECT
    f.mekanID AS [MekanId],
    COUNT(*) AS Fis,
    CONVERT(DECIMAL(18, 2), SUM(f.baslik_net)) AS BinBirFisNet,
    SUM(ISNULL(k.bin_bir_kalem, 0)) AS BinBirKalem,
    SUM(ISNULL(k.diger_gecerli_kalem, 0)) AS BinBirDisiGecerliKalem
FROM Fis AS f
    LEFT JOIN Kalem AS k
        ON f.Id = k.SalesId
GROUP BY f.mekanID
ORDER BY f.mekanID;
GO

-- blok: S  (saat yoğunluğu kanonik; tek satır özet: saat sayısı, fiş, net)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Saatler AS (
    SELECT
        DATEPART(HOUR, s.[Date]) AS saat,
        SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END) AS fis,
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
        AND NOT EXISTS (
            SELECT 1
            FROM EncoreMerkez.dbo.SalesProducts AS sb   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
            WHERE sb.SalesId = s.Id AND sb.BarcodeNo = '1001'
        )
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
    GROUP BY DATEPART(HOUR, s.[Date])
)

SELECT
    COUNT(*) AS SaatSayisi,
    SUM(sa.fis) AS Fis,
    CONVERT(DECIMAL(18, 2), SUM(sa.net)) AS Net
FROM Saatler AS sa;
GO

-- blok: N  (nüfus: tek satır; Eylül 2026)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS belge_eylul_tum,
    (
        SELECT COUNT(DISTINCT s.UsersId)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS kasiyer_eylul_tum,
    (
        SELECT COUNT(DISTINCT sp.SalesId)
        FROM EncoreMerkez.dbo.SalesProducts AS sp
            INNER JOIN EncoreMerkez.dbo.Sales AS s ON sp.SalesId = s.Id
        WHERE sp.BarcodeNo = '1001' AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS bin_bir_fis_eylul,
    (
        SELECT COUNT(*)
        FROM DerinSISBkm.dbo.irsHrk AS h
        WHERE h.ehTip IN (100, 101, 4, 5) AND h.ehMekan IN (1, 4477, 4478) AND h.ehAltDepo = 0 AND h.ehTrhS >= @Bas AND h.ehTrhS < @Bit
    ) AS irs_satir_eylul_uc_magaza;
