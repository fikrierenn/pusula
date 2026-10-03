-- ork:hedef-db JOKER
-- ork:compat 150
/* Soru     : E-ticaret Eylül 2026 kapalı dönem neti kayıyor mu? Sipariş sayısı ve net ciro, bugünkü STATUS dağılımı.
   AC       : SC-006 (girdi) · R2: Koşu 1 + 7 takvim günü sonra T-003 aynı sorguyu tekrar koşar
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026), JOKER ORDERDATE
   Tolerans : birebir (sayım) · ≤ 1,00 TL (tutar)
   Önce     : referans 02.10.2026: 113.731 sipariş · 121.955.096,47 TL
   Sonra    : T-003 Koşu 2
   Bağımsız : blok B sipariş toplamı (hariç tutulan durumlar dışı) = blok A sipariş sayısı
   Dondurma : ea58d7c
   SSMS     : DECLARE @BasTarih date = CONVERT(date, '01.09.2026', 104), @BitTarih date = CONVERT(date, '01.10.2026', 104);
              (JOKER tarihi ISO yyyyMMdd string, aşağıda)

   Koşu 1: 03.10.2026 23:42 · Sip=113.710 · Ciro=121.911.116,36
   (T-001 blok D ile aynı: 113.710 / 121.911.116,36 TL. 02.10 referansına göre −21 sipariş, −43.980,11 TL.)

   Koşu 1 B (STATUS, tüm Eylül siparişleri): 1001 = 3.401 · 1005 = 103.800 · 1006 = 773 · 3004 = 5.820 · 3006 = 4.090
              Kural kapsamı (1001/1006 hariç): 103.800 + 5.820 + 4.090 = 113.710 (A ile birebir).
   Komut    : bash tools/sq.sh --joker "<blok sorgusu>"
*/

-- blok: A
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
    SELECT d.QUANTITY * d.SELLINGPRICEWITHOUTVAT AS net_tutar
    FROM JOKER.dbo.J_ORDER_DETAILS AS d
        INNER JOIN Baslik AS b
            ON d.ORDERREF = b.siparis_id
)

SELECT
    (SELECT COUNT(*) FROM Baslik) AS siparis_sayisi,
    SUM(sa.net_tutar) AS net_ciro
FROM Satir AS sa;

-- blok: B
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso2 VARCHAR(8) = '20260901', @BitIso2 VARCHAR(8) = '20261001';   -- ISO (JOKER)
SELECT
    o.STATUS AS siparis_durum,
    COUNT(*) AS siparis_sayisi
FROM JOKER.dbo.J_ORDERS AS o
WHERE
    o.ORDERDATE >= @BasIso2
    AND o.ORDERDATE < @BitIso2
GROUP BY o.STATUS
ORDER BY o.STATUS;
