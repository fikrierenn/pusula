-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Spec 001 F0 taban ölçümü: 1001 etkisi, KR-4 eşdeğerliği, e-tic satır iptali, Sequence tekilliği,
              Sınav iadesi kanal farkı, satış analizi kesim farkı, Sınav kalemsiz sipariş, JOKER erişimi,
              merkez depo geçmiş ay okuma envanteri.
   AC       : SC-002 (kanıt) · girdi: KR-1, KR-2, KR-4, H6, H8, H9, H13
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026); E: son 90 gün; B, G, J: dönemsiz
   Tolerans : birebir (sayım) · ≤ 1,00 TL (tutar)
   Önce     : (taban ölçümü; panel değeri yok)
   Sonra    : —
   Bağımsız : aşağıdaki blok sonuçları
   Ölçüm    : 03.10.2026 · sqlcli --profile erp --read-only (D: tools/sq.sh --joker) · salt-okuma
   Dondurma : c223b41
   Hedef-db (blok bazlı): A, B, C, E, F, F2 EncoreMerkez (A, C, F, F2 DerinSISBkm.posMagaza köprüsü) · D, I JOKER (doğrudan,
              bash tools/sq.sh --joker) · G, J, J2 DerinSISBkm · H BKM + EncoreMerkez
   SSMS     : DECLARE @BasTarih date = CONVERT(DATE, '01.09.2026', 104), @BitTarih date = CONVERT(DATE, '01.10.2026', 104);

   SONUÇLAR (satır sayısı = bloğun döndürdüğü satır)
   A  (16 satır)  Eylül 2026 belge tipi × 1001 dışlaması. FSM: tip 1 = 42.774, tip 3 = 1.518 / 1001 hariç 947
                  (referansla BİREBİR). Özlüce 4477: tip 3 = 1.926 / 1001 hariç 1.167. İst.Yolu 4478: tip 3 = 1.512 / 990;
                  tip 1 = 31.489 / 31.488 (1 satış fişi 1001 taşıyor); tip 8 = 5.466. Sapma yok.
   B  (4 satır)   Tüm zaman 1001: tip 3 = 15.423 belge (referans 15.421, +2), satır net 2.459.437,96 (referans 2.459.358,26);
                  tip 1 = 62 · tip 2 = 1 · tip 6 = 2 (referansla aynı). Sapma: iade +2 belge, +79,70 TL — referanstan
                  sonra yeni iade geldi (ÇIKARIM: canlı veri büyüyor); düzeltilmedi.
   C  (1 satır)   KR-4: A (HediyeCekiQueries tanımı: IsValid = 1 VE (RefundReasonId = 12 VEYA Code = '583160')) = 1.889 belge,
                  B (barkod 1001, IsValid'e bakmaz) = 1.853 belge; yalnız A'da 36, yalnız B'de 0, ikisinde 1.853.
                  IsValid = 1 eklenince sonuç değişmedi (düzeltme turu 1, yeniden koşuldu). Sonuç: eşdeğer değil (36/1.889 belge).
                  36 belgenin sebebi "583160'ı 1001'siz taşıyor" DEĞİL: sebep kodu 12 başka ürün satırlarına girilmiş.
                  Panelin A tanımı 1001 tanımından fazla dışlıyor; B'yi kapsadığı için daha güvenli sayılmaz (KR-4 girdisi).
   D  (1 satır)   KR-2 (JOKER, Eylül 2026, başlık STATUS NOT IN 1001,1006,1007,3000,4000): 113.710 sipariş; satır STATUS 2004/2005/2010
                  tutarı 1.648.346,07 TL, adet 5.939, tüm satır netinin %1,35'i (tüm satır net 121.911.116,36 TL).
                  %1,35 > %0,5 → KR-2 ayrı karar gerekir.
                  Referans 121.955.096,47 TL ile fark −43.980,11 TL tanım farkı DEĞİL: panel eticSql (dashboard/Data/Queries.cs:53-59)
                  D ile aynı tanım ve bugün 113.710 sipariş / 121.911.116,36 TL verir. Denetleyici ölçümü: 02.10'dan bu yana
                  21 sipariş durum değiştirdi → kapalı Eylül e-tic neti hâlâ kayıyor (R2 girdisi).
   E  (1 satır)   Son 90 günde incelenen 1.768.128 (SalesId, Sequence) çifti / 1.768.128 geçerli kalem satırı; tekrarlı çift = 0
                  (beklenen 0). Nüfus > 0, "bakamadım" değil. Nüfus 0 olsaydı sonuç "bakamadım" okunurdu.
   F  (3 satır)   İst.Yolu Eylül 2026 iade (tip 3, KDV hariç net): LinkedDocumentId > 0 ve bağlı belge tip 8 = 182 iade,
                  5.290.096,33 TL; bağlı belge tip ≠ 8 = 767 iade, 869.440,06 TL; LinkedDocumentId = 0 = 563 iade, 165.801,79 TL.
                  Toplam 1.512 iade (A ile aynı). Sınav iadesi kanal farkı: 182 iade / 5.290.096,33 TL.
   F2 (2 satır)   Diğer mağazalarda tip 8'e bağlı iade: FSM 1 (190,83 TL) + Özlüce 3 (1.630,27 TL) = 4 adet / 1.821,10 TL (ihmal).
   G  (1 satır)   SatisAnaliziTaban son Kesim = 15.09.2026 (276.378 ürün); tablodaki tek zaman damgası MAX(Uretim) = 16.09.2026 16:48:38
                  (ÇIKARIM: üretim zamanı). Merkez depo kolonu (MerkezStok) toplamı 3.098.445; canlı WMS (alan 0+1, aynı stkID
                  kümesi, 03.10.2026 23:39) 2.830.868. Fark −267.577 adet (−%8,64). MerkezStok üretim anında canlı WMS'ten dolar
                  (SatisAnaliziTabanService.cs:171-176): fark tamamen zaman kayması, veri hatası değil. Ürün başına tek satır
                  (SezonYil tek değer 2025, satır = ürün sayısı).
   H  (1 satır)   BKM.snv, dönem Eylül 2026 tarihli siparişlerden seçilir (DonemId sabiti yok): 5.401 sipariş, 3 farklı DonemId
                  (en küçük −8, en büyük 8). Kalemsiz (SiparisDetay'siz) sipariş = 0, net KDV hariç 0,00 TL.
                  H9: kalemsiz durumu gerekmiyor (nüfus 5.401 > 0; boş küme değil).
   I  (1 satır)   JOKER SELECT 1 AS Bagli = 1 (bash tools/sq.sh --joker); doğrudan bağlantı çalışıyor.
   J  (1 + 4 satır) StokAyBakiyeMekanBazli, ehMekan = 12: yalnız Kaynak = 'WMS', tek Donem 31.08.2026 (25.190 satır, 4.249.866 adet).
                  Son 6 dönem penceresinde başka dönem yok. Kaynak = 'irsHrk' yalnız mekân 1, 4477, 4478 (64 dönem, 31.05.2021–31.08.2026);
                  irsHrk kaynağında mekân 12 satırı yok (J2).
                  Panel okuma envanteri (kodda, sınıf/metot):
                  1) OdakQueries.cs GetUrunlerAsync — Kaynak 'WMS', mekân 12, Donem = MAX(Donem) (son ay-sonu görüntüsü)
                  2) RefQueries.Envanter.cs GetKategoriCesitAsync — Kaynak 'WMS', mekân 12, Donem = MAX(Donem)
                  3) SatinalmaQueries.cs GetAnalizAsync (#bal) — Kaynak 'irsHrk', mekân kısıtı yok (veride 1/4477/4478), geçmiş 12 ay
                  4) SatinalmaQueries.UrunDetay.cs GetSubeSezonAsync — Kaynak 'irsHrk', mekân 1/4477/4478, geçen sezon pencere
                  5) SatisAnaliziTabanService.cs (snb) — Kaynak süzgeci YOK, mekân 1/4477/4478, Donem = geçen sezon Eylül/Ekim ay sonları
                  (Görev özeti altı yer diyor; kodda beş yer bulundu — grep: StokAyBakiyeMekanBazli, dashboard/**/*.cs.)
                  Sonuç: geçmiş ay merkez depo bakiyesini ekranda gösteren yer: yok (Donem parametreli mekân 12 okuması yok;
                  1 ve 2 numaralı yerler MAX(Donem) ile 31.08.2026 görüntüsünü 'bugünkü' merkez stok olarak gösteriyor — KB-1 girdisi:
                  görüntü tarihi ekranda yazılmıyor).
*/

-- blok: A
DECLARE @BasTarih DATE = CONVERT(DATE, '01.09.2026', 104), @BitTarih DATE = CONVERT(DATE, '01.10.2026', 104);
WITH gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
    WHERE sp.BarcodeNo = '1001'
)

SELECT
    mg.mekanID AS mekan_id,
    s.DocumentsTypeId AS belge_tipi,
    COUNT(*) AS belge,
    SUM(CASE WHEN gd.SalesId IS NULL THEN 1 ELSE 0 END) AS belge_1001_haric
FROM EncoreMerkez.dbo.Sales AS s
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    LEFT JOIN
        gd
        ON s.Id = gd.SalesId
WHERE
    mg.mekanID IN (1, 4477, 4478)
    AND s.[Date] >= @BasTarih
    AND s.[Date] < @BitTarih
GROUP BY mg.mekanID, s.DocumentsTypeId
ORDER BY mg.mekanID, s.DocumentsTypeId;

-- blok: B
SELECT
    s.DocumentsTypeId AS belge_tipi,
    COUNT(DISTINCT s.Id) AS belge_1001,
    SUM(sp.TotalPrice - sp.VatTotal) AS satir_net_haric,
    SUM(CASE WHEN sp.IsValid = 0 THEN 1 ELSE 0 END) AS gecersiz_satir
FROM EncoreMerkez.dbo.SalesProducts AS sp
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON sp.SalesId = s.Id
WHERE sp.BarcodeNo = '1001'
GROUP BY s.DocumentsTypeId
ORDER BY s.DocumentsTypeId;

-- blok: C
DECLARE @BasTarih DATE = CONVERT(DATE, '01.09.2026', 104), @BitTarih DATE = CONVERT(DATE, '01.10.2026', 104);
WITH Kume AS (
    SELECT s.Id AS satis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS p
            ON s.PosId = p.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON p.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    WHERE
        mg.mekanID IN (1, 4477, 4478)
        AND s.[Date] >= @BasTarih
        AND s.[Date] < @BitTarih
),

KumeA AS   -- HediyeCekiQueries tanımı: yalnız geçerli kalem (IsValid = 1), RefundReasonId = 12 VEYA Code = '583160'
(
    SELECT DISTINCT sp.SalesId AS satis_id
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN Kume AS k
            ON sp.SalesId = k.satis_id
        INNER JOIN EncoreMerkez.dbo.Products AS pr
            ON sp.ProductsId = pr.Id
    WHERE
        sp.IsValid = 1
        AND (sp.RefundReasonId = 12 OR pr.Code = '583160')
),

KumeB AS   -- 1001 barkod tanımı
(
    SELECT DISTINCT sp.SalesId AS satis_id
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN Kume AS k
            ON sp.SalesId = k.satis_id
    WHERE sp.BarcodeNo = '1001'
)

SELECT
    (SELECT COUNT(*) FROM KumeA) AS toplam_a,
    (SELECT COUNT(*) FROM KumeB) AS toplam_b,
    (
        SELECT COUNT(*) FROM KumeA AS a
        WHERE NOT EXISTS (
            SELECT 1 FROM KumeB AS b
            WHERE b.satis_id = a.satis_id
        )
    ) AS yalniz_a,
    (
        SELECT COUNT(*) FROM KumeB AS b
        WHERE NOT EXISTS (
            SELECT 1 FROM KumeA AS a
            WHERE a.satis_id = b.satis_id
        )
    ) AS yalniz_b,
    (
        SELECT COUNT(*) FROM KumeA AS a
        WHERE EXISTS (
            SELECT 1 FROM KumeB AS b
            WHERE b.satis_id = a.satis_id
        )
    ) AS ikisinde;

-- blok: D
-- ork:hedef-db JOKER
-- JOKER doğrudan bağlantı (ODAKJOKER değil); tarih ISO
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso VARCHAR(8) = '20260901', @BitIso VARCHAR(8) = '20261001';   -- ISO (JOKER)
WITH Baslik AS (
    SELECT o.ORDERID AS siparis_id
    FROM JOKER.dbo.J_ORDERS AS o
    WHERE
        o.ORDERDATE >= @BasIso
        AND o.ORDERDATE < @BitIso
        AND o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000)
),

Satir AS (
    SELECT
        d.STATUS AS satir_durum,
        d.QUANTITY AS adet,
        d.QUANTITY * d.SELLINGPRICEWITHOUTVAT AS net_tutar
    FROM JOKER.dbo.J_ORDER_DETAILS AS d
        INNER JOIN Baslik AS b
            ON d.ORDERREF = b.siparis_id
)

SELECT
    (SELECT COUNT(*) FROM Baslik) AS siparis_sayisi,
    SUM(CASE WHEN sa.satir_durum IN (2004, 2005, 2010) THEN sa.net_tutar ELSE 0 END) AS satir_iptal_tutar,
    SUM(CASE WHEN sa.satir_durum IN (2004, 2005, 2010) THEN sa.adet ELSE 0 END) AS satir_iptal_adet,
    SUM(sa.net_tutar) AS tum_satir_net,
    SUM(CASE WHEN sa.satir_durum NOT IN (2004, 2005, 2010) THEN sa.net_tutar ELSE 0 END) AS ana_net_iptal_haric,
    100.0 * SUM(CASE WHEN sa.satir_durum IN (2004, 2005, 2010) THEN sa.net_tutar ELSE 0 END)
    / NULLIF(SUM(sa.net_tutar), 0) AS yuzde_tum_net
FROM Satir AS sa;

-- blok: E
DECLARE @Bugun DATE = CONVERT(DATE, '03.10.2026', 104);
WITH Cift AS (
    SELECT
        sp.SalesId,
        sp.[Sequence],
        COUNT(*) AS satir
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON sp.SalesId = s.Id
    WHERE
        sp.IsValid = 1
        AND s.[Date] >= DATEADD(DAY, -90, @Bugun)
    GROUP BY sp.SalesId, sp.[Sequence]
)

SELECT
    COUNT(*) AS incelenen_cift,
    SUM(c.satir) AS incelenen_kalem_satiri,   -- nüfus: 0 ise sonuç "bakamadım"
    SUM(CASE WHEN c.satir > 1 THEN 1 ELSE 0 END) AS tekrarli_cift,
    SUM(CASE WHEN c.satir > 1 THEN c.satir ELSE 0 END) AS tekrarli_satir
FROM Cift AS c;

-- blok: F
DECLARE @BasTarih DATE = CONVERT(DATE, '01.09.2026', 104), @BitTarih DATE = CONVERT(DATE, '01.10.2026', 104);
SELECT
    CASE
        WHEN i.LinkedDocumentId = 0 THEN 'bagsiz'
        WHEN o.Id IS NULL THEN 'bagli_belge_yok'
        WHEN o.DocumentsTypeId = 8 THEN 'bagli_sinav'
        ELSE 'bagli_diger'
    END AS iade_grubu,
    COUNT(*) AS iade_sayisi,
    SUM(i.GrossTotal - i.DiscountTotal - i.VatTotal) AS net_kdv_haric
FROM EncoreMerkez.dbo.Sales AS i
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON i.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    LEFT JOIN EncoreMerkez.dbo.Sales AS o
        ON
            i.LinkedDocumentId = o.Id
            AND i.LinkedDocumentId > 0
WHERE
    mg.mekanID = 4478
    AND i.DocumentsTypeId = 3
    AND i.[Date] >= @BasTarih
    AND i.[Date] < @BitTarih
GROUP BY
    CASE
        WHEN i.LinkedDocumentId = 0 THEN 'bagsiz'
        WHEN o.Id IS NULL THEN 'bagli_belge_yok'
        WHEN o.DocumentsTypeId = 8 THEN 'bagli_sinav'
        ELSE 'bagli_diger'
    END
ORDER BY iade_grubu;

-- blok: F2
DECLARE @BasTarih DATE = CONVERT(DATE, '01.09.2026', 104), @BitTarih DATE = CONVERT(DATE, '01.10.2026', 104);
SELECT
    mg.mekanID AS mekan_id,
    COUNT(*) AS iade_sayisi,
    SUM(i.GrossTotal - i.DiscountTotal - i.VatTotal) AS net_kdv_haric
FROM EncoreMerkez.dbo.Sales AS i
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON i.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    INNER JOIN EncoreMerkez.dbo.Sales AS o
        ON i.LinkedDocumentId = o.Id
WHERE
    mg.mekanID IN (1, 4477)
    AND i.DocumentsTypeId = 3
    AND i.LinkedDocumentId > 0
    AND o.DocumentsTypeId = 8
    AND i.[Date] >= @BasTarih
    AND i.[Date] < @BitTarih
GROUP BY mg.mekanID
ORDER BY mg.mekanID ASC;

-- blok: G
WITH Son AS (
    SELECT MAX(t.Kesim) AS kesim
    FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t
),

Taban AS   -- anahtar (Kesim, SezonYil, stkID): ürün başına tek değer için MAX
(
    SELECT
        t.stkID,
        MAX(t.MerkezStok) AS merkez_stok
    FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t
        INNER JOIN Son AS sn
            ON t.Kesim = sn.kesim
    GROUP BY t.stkID
),

Canli AS (
    SELECT
        w.stkID,
        SUM(w.Stok) AS stok
    FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
    WHERE w.adrsAlanTipID IN (0, 1)
    GROUP BY w.stkID
)

SELECT
    (SELECT sn.kesim FROM Son AS sn) AS kesim_tarihi,
    (
        SELECT MAX(t2.Uretim)
        FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t2
            INNER JOIN Son AS sn2
                ON t2.Kesim = sn2.kesim
    ) AS taban_uretim_zamani,   -- tablodaki tek zaman damgası (Uretim); MerkezStok üretim anında canlı WMS'ten dolar
    GETDATE() AS sorgu_zamani,
    (SELECT COUNT(*) FROM Taban) AS urun_sayisi,
    SUM(tbn.merkez_stok) AS taban_merkez_adet,
    SUM(ISNULL(c.stok, 0)) AS canli_wms_adet,
    SUM(ISNULL(c.stok, 0)) - SUM(tbn.merkez_stok) AS fark_adet,
    100.0 * (SUM(ISNULL(c.stok, 0)) - SUM(tbn.merkez_stok)) / NULLIF(SUM(tbn.merkez_stok), 0) AS fark_yuzde
FROM Taban AS tbn
    LEFT JOIN Canli AS c
        ON tbn.stkID = c.stkID;

-- blok: H
DECLARE @BasTarih DATE = CONVERT(DATE, '01.09.2026', 104), @BitTarih DATE = CONVERT(DATE, '01.10.2026', 104);   -- dönem sipariş tarihinden
WITH Siparis AS (
    SELECT
        sip.SiparisId,
        sip.SiparisKod
    FROM BKM.snv.Siparis AS sip
    WHERE
        sip.Tarih >= @BasTarih
        AND sip.Tarih < @BitTarih
        AND NOT EXISTS (
            SELECT 1 FROM BKM.snv.SiparisDetay AS sd
            WHERE sd.SiparisId = sip.SiparisId
        )
),

Fis AS (
    SELECT DISTINCT
        si.SiparisKod,
        s.Id AS satis_id,
        s.DocumentsTypeId,
        s.GrossTotal,
        s.DiscountTotal,
        s.VatTotal
    FROM Siparis AS si
        INNER JOIN BKM.snv.SinavSiparisFisEncore AS fe
            ON si.SiparisKod = fe.SiparisKod
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON fe.InvoiceNo = s.DocumentNo
)

SELECT
    (
        SELECT COUNT(*) FROM BKM.snv.Siparis AS x
        WHERE x.Tarih >= @BasTarih AND x.Tarih < @BitTarih
    ) AS eylul_siparis,
    (
        SELECT COUNT(DISTINCT x.DonemId) FROM BKM.snv.Siparis AS x
        WHERE x.Tarih >= @BasTarih AND x.Tarih < @BitTarih
    ) AS donem_sayisi,
    (
        SELECT MIN(x.DonemId) FROM BKM.snv.Siparis AS x
        WHERE x.Tarih >= @BasTarih AND x.Tarih < @BitTarih
    ) AS min_donem_id,
    (
        SELECT MAX(x.DonemId) FROM BKM.snv.Siparis AS x
        WHERE x.Tarih >= @BasTarih AND x.Tarih < @BitTarih
    ) AS maks_donem_id,
    (SELECT COUNT(*) FROM Siparis) AS kalemsiz_siparis,
    (SELECT COUNT(DISTINCT f2.SiparisKod) FROM Fis AS f2) AS fisli_kalemsiz_siparis,
    ISNULL(SUM(CASE
        WHEN f.DocumentsTypeId = 3
            THEN -(f.GrossTotal - f.DiscountTotal - f.VatTotal)
        ELSE (f.GrossTotal - f.DiscountTotal - f.VatTotal)
    END), 0) AS kalemsiz_net_kdv_haric
FROM Fis AS f;

-- blok: I
-- JOKER doğrudan bağlantı testi: bash tools/sq.sh --joker "SELECT 1 AS Bagli"
SELECT 1 AS Bagli;

-- blok: J
DECLARE
    @SonDonemAltSinir DATE
    = (
        SELECT DATEADD(MONTH, -6, MAX(x.Donem))
        FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS x
        WHERE x.ehMekan = 12
    );
SELECT TOP (12)
    b.Donem AS donem_tarihi,
    b.Kaynak AS kaynak_adi,
    COUNT(*) AS satir,
    SUM(CONVERT(BIGINT, b.Stok)) AS stok_toplam
FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
WHERE
    b.ehMekan = 12
    AND b.Donem >= @SonDonemAltSinir
GROUP BY b.Donem, b.Kaynak
ORDER BY b.Donem DESC, b.Kaynak ASC;

-- blok: J2
SELECT
    b.Kaynak AS kaynak_adi,
    b.ehMekan AS mekan_id,
    COUNT(DISTINCT b.Donem) AS donem_sayisi,
    MIN(b.Donem) AS ilk_donem,
    MAX(b.Donem) AS son_donem
FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
GROUP BY b.Kaynak, b.ehMekan
ORDER BY b.Kaynak, b.ehMekan;
