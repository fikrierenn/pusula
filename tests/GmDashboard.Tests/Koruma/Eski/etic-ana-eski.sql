/* DONDURULMUS KOPYA (karakterizasyon girdisi) - DEGISTIRME.
   Kaynak: dashboard/Data/Queries.cs:54-59 (eticSql), commit d5cf345; HEAD'deki metinle ayni.
   Spec 001 SC-006 (koruma testleri). Hedef: JOKER (dogrudan). Parametre: @giso, @g2iso (yyyyMMdd string, bitis haric).
   Uretir: (Sip int, Ciro decimal)
   Eylul 2026 (@giso='20260901', @g2iso='20261001'), olculdu 04.10.2026:
     Sip 113.710   Ciro 121.911.116,36 (T-002 03.10 degeriyle ayni, kayma yok)
   Salt-okuma. Paneldeki metin birebir; bicim kapilari bilincli kapali. */
-- ork:hedef-db JOKER
-- ork:compat 150
-- noqa: disable=all
/* tsqllint-disable */
-- SSMS: DECLARE @giso varchar(8) = '20260901', @g2iso varchar(8) = '20261001';
SELECT SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN 1 ELSE 0 END) AS Sip,
       SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN ISNULL(det.net,0) ELSE 0 END) AS Ciro
FROM dbo.J_ORDERS o
CROSS APPLY (SELECT SUM(d.QUANTITY*d.SELLINGPRICEWITHOUTVAT) AS net
             FROM dbo.J_ORDER_DETAILS d WHERE d.ORDERREF=o.ORDERID) det
WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso;
