-- ork:hedef-db JOKER
-- ork:compat 150
/* Soru     : ODAK talebi (e-ticaret satış adedi) iptal edilmiş sipariş ve satırları sayıyor mu?
   AC       : AC-4.3 · Spec 001 · H04 · KR-2 (satır iptal kuralı YALNIZ ODAK talebine)
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026), JOKER ORDERDATE.
              Panel penceresi: OdakQueries.cs `ecom` CTE = ORDERDATE >= Iso12() (bugün − 1 yıl, ÜST SINIR YOK;
              Iso12 = DateTime.Today.AddYears(-1).ToString("yyyyMMdd")). Kanonik ölçüm Eylül 2026'ya sabitlenir;
              düzeltmenin değeri pencereden değil süzgeçten gelir, bu yüzden tek ay karşılaştırılır.
   Tolerans : adet birebir
   Kural    : başlık o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000)
              kaynak: sema/codes.yaml joker.J_ORDERS.STATUS.net_iptal_iade
              satır  d.STATUS NOT IN (2004, 2005, 2010)
              kaynak: sema/codes.yaml joker.J_ORDER_DETAILS.STATUS.net_iptal_iade (okundu 04.10.2026)
   Önce     : OdakQueries.cs ecom CTE (satır ~83): J_ORDERS ⋈ J_ORDER_DETAILS ⋈ J_ITEMS, DERINSIS_ID > 0,
              STATUS süzgeci YOK, SUM(QUANTITY) GROUP BY DERINSIS_ID. Blok ONCE.
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : B = A toplamı (satır sayısı hariç) ve B ≤ ONCE toplamı; fark = iptal/iade satır ve başlık adedi.
   Aynı kaynak — neden: değil. ONCE panelin mantığıdır; A başlık + satır STATUS kuralı ekler. Aynı tablolardan
              okunmaları bilinçli: ölçülen şey süzgeç farkının kendisi.
   Başka ne olabilir: (1) ONCE − A farkı iptalden değil, DERINSIS_ID ≤ 0 ürünlerin farklı ele alınmasından
              olabilir; ikisinde de DERINSIS_ID > 0 şartı aynı, fark yalnız STATUS.
              (2) 2004 "tedarik edilemedi" müşteri iptali değil operasyon kaybıdır; yine de talep sayılmaz.
              (3) Başlık süzgeci satır süzgecini kapsıyorsa blok B (yalnız başlık) ile A arasındaki fark satır iptalidir.
   Koşu 1   : 04.10.2026 01:10 (bash tools/sq.sh --joker, literal tarihli blok)
              A    : 68.806 ürün · Σ adet = 525.792
              B    : Σ adet = 531.731 (yalnız başlık kuralı)
              ONCE : 70.393 ürün · Σ adet = 548.515 (panel mantığı)
              Kapı : B − A = 5.939 = satır iptali 2004 (2.940) + 2005 (2.520) + 2010 (479) ✓ (ayrı sorguyla ölçüldü)
                     ONCE − B = 16.784 = başlık iptal/iade siparişlerinin adedi
   Dondurma : 1103192
   SSMS     : -- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso VARCHAR(8) = '20260901', @BitIso VARCHAR(8) = '20261001';  -- ISO (JOKER)
              Bloklar GO ile ayrılır. sq.sh DECLARE koşmaz: koşuda tarihler literal yazılır.
   Komut    : bash tools/sq.sh --joker --max-rows 100000 "<tek blok, literal tarihli>" (depo kökünden).
   Bloklar  : A (StkId, Adet) · B (Adet) yalnız başlık kuralı · ONCE (StkId, Adet) panel mantığı
   Nüfus    : A satır > 0; B ve ONCE Adet > 0. Sıfır ise KOŞAMADI.
*/

-- blok: A  (ODAK talebi, başlık + satır STATUS kuralıyla)
-- ork:izin RUN-007 JOKER J_ORDERS/J_ORDER_DETAILS'ta soft-delete kolonu yok; iptal STATUS ile süzülür
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso VARCHAR(8) = '20260901', @BitIso VARCHAR(8) = '20261001';   -- ISO (JOKER)
SELECT
    ji.DERINSIS_ID AS stk_id,
    CAST(SUM(d.QUANTITY) AS INT) AS adet
FROM JOKER.dbo.J_ORDER_DETAILS AS d
    INNER JOIN JOKER.dbo.J_ORDERS AS o
        ON d.ORDERREF = o.ORDERID
    INNER JOIN JOKER.dbo.J_ITEMS AS ji
        ON d.ITEMREF = ji.LOGICALREF
WHERE
    o.ORDERDATE >= @BasIso
    AND o.ORDERDATE < @BitIso
    AND ji.DERINSIS_ID > 0
    AND o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000)
    AND d.STATUS NOT IN (2004, 2005, 2010)
GROUP BY ji.DERINSIS_ID
ORDER BY ji.DERINSIS_ID;
GO

-- blok: B  (yalnız başlık kuralı; satır iptali düşülmemiş toplam adet)
-- ork:izin RUN-007 JOKER J_ORDERS/J_ORDER_DETAILS'ta soft-delete kolonu yok; iptal STATUS ile süzülür
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso2 VARCHAR(8) = '20260901', @BitIso2 VARCHAR(8) = '20261001';   -- ISO (JOKER)
SELECT CAST(SUM(d.QUANTITY) AS INT) AS adet
FROM JOKER.dbo.J_ORDER_DETAILS AS d
    INNER JOIN JOKER.dbo.J_ORDERS AS o
        ON d.ORDERREF = o.ORDERID
    INNER JOIN JOKER.dbo.J_ITEMS AS ji
        ON d.ITEMREF = ji.LOGICALREF
WHERE
    o.ORDERDATE >= @BasIso2
    AND o.ORDERDATE < @BitIso2
    AND ji.DERINSIS_ID > 0
    AND o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000);
GO

-- blok: ONCE  (panelin bugünkü mantığı: STATUS süzgeci yok)
-- ork:izin RUN-007 JOKER J_ORDERS/J_ORDER_DETAILS'ta soft-delete kolonu yok
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso3 VARCHAR(8) = '20260901', @BitIso3 VARCHAR(8) = '20261001';   -- ISO (JOKER)
SELECT
    ji.DERINSIS_ID AS stk_id,
    CAST(SUM(d.QUANTITY) AS INT) AS adet
FROM JOKER.dbo.J_ORDER_DETAILS AS d
    INNER JOIN JOKER.dbo.J_ORDERS AS o
        ON d.ORDERREF = o.ORDERID
    INNER JOIN JOKER.dbo.J_ITEMS AS ji
        ON d.ITEMREF = ji.LOGICALREF
WHERE
    o.ORDERDATE >= @BasIso3
    AND o.ORDERDATE < @BitIso3
    AND ji.DERINSIS_ID > 0
GROUP BY ji.DERINSIS_ID
ORDER BY ji.DERINSIS_ID;
GO
