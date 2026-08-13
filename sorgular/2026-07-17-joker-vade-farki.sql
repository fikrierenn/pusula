/*
  Soru:  JOKER'de kredi kartı taksitli + vade farkı olan sipariş var mı? Nerede tutuluyor?
  DB:    DerinSISBkm üzerinden ODAKJOKER.JOKER linked server (tarih literali: YYYYMMDD ISO)
  Bulgu: J_ORDERS.SERVICEPRICE ÇİFT ANLAMLI —
           PAYDEFREF=-3  (Kapıda Ödeme) -> COD hizmet bedeli   (8.167/8.167 dolu, 693.378 TL)
           PAYDEFREF=-13 (iyzico/kart)  -> VADE FARKI           (4.266/135.803 dolu, 981.754 TL)
         JOKER API karsiligi: Payment.LateChargeAmount (COD ayri alan: Shipment.CashOnDeliveryAmount = 0).
         Vade farki TARIFELI: %10,44 / %13,52 / %16,29 / %19,62 / %31,14 / %38,33
         (taban = satir toplami + CARGOPRICE - VOUCHERVALUE; oran sepetten BAGIMSIZ sabit).
         Taksit sayisi HICBIR YERDE YOK: JOKER'de taksit kolonu yok, API InstallmentCount beslenmiyor (hep 1).
         Kademe -> taksit eslemesi iyzico panelinden dogrulanacak.
  Sema:  sema/entities.yaml -> ODAKJOKER.JOKER.dbo.J_ORDERS · docs/05-eticaret-joker.md
*/

-- 1) Taksit/vade kolonu var mi? (tum JOKER DB kolon taramasi) -> SONUC: 0 eslesme (TMPOZET.FARK haric, ilgisiz)
SELECT o.name AS tbl, c.name AS col, ty.name AS tip
FROM ODAKJOKER.JOKER.sys.columns c
    JOIN ODAKJOKER.JOKER.sys.objects o ON o.object_id = c.object_id
    JOIN ODAKJOKER.JOKER.sys.types ty ON ty.user_type_id = c.user_type_id
WHERE o.type = 'U'
  AND (c.name LIKE '%TAKSIT%' OR c.name LIKE '%INSTALLMENT%' OR c.name LIKE '%VADE%'
       OR c.name LIKE '%KOMISYON%' OR c.name LIKE '%COMMISSION%' OR c.name LIKE '%INTEREST%');

-- 2) ANA KANIT: SERVICEPRICE odeme tipine gore doluluk
--    -3 %100 dolu (COD bedeli, beklenen) AMA -13 de dolu (4.266 siparis) -> COD DEGIL, vade farki
SELECT o.PAYDEFREF, p.NAME AS odemeAd,
       COUNT(*)                                              AS siparisAdet,
       SUM(CASE WHEN o.SERVICEPRICE > 0 THEN 1 ELSE 0 END)   AS servisDoluAdet,
       SUM(o.SERVICEPRICE)                                   AS servisToplam
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
    LEFT JOIN ODAKJOKER.JOKER.dbo.J_ORDER_PAY_TYPES p ON p.ID = o.PAYDEFREF
WHERE o.ORDERDATE >= '20260601'
GROUP BY o.PAYDEFREF, p.NAME
ORDER BY siparisAdet DESC;

-- 3) TARIFE KANITI: dogru taban ile oran ayrik kademelere oturur (surekli dagilim DEGIL)
--    Taban = satir toplami + CARGOPRICE - VOUCHERVALUE. Tepeler: 1044 / 1352 / 1629 / 1962 / 3114 / 3833 (x100 = %)
--    NOT: yanlis taban (sadece satir toplami) kullanilirsa oran %10-25 arasi surekli dagilir ve tarife GORUNMEZ.
WITH sip AS (
    SELECT o.ORDERCODE, o.ORDERDATE, o.APPLICATION, o.SERVICEPRICE, o.CARGOPRICE, o.VOUCHERVALUE, o.TOTALPRICE,
           ISNULL(d.satirToplam, 0) AS sepet
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
        OUTER APPLY (
            SELECT SUM(dt.QUANTITY * dt.SELLINGPRICE) AS satirToplam
            FROM ODAKJOKER.JOKER.dbo.J_ORDER_DETAILS dt
            WHERE dt.ORDERREF = o.ORDERID
        ) d
    WHERE o.ORDERDATE >= '20260701'
      AND o.PAYDEFREF = -13          -- iyzico/kart
      AND o.SERVICEPRICE > 0         -- vade farki dolu
), oranli AS (
    SELECT *,
           CAST(ROUND(10000.0 * SERVICEPRICE / NULLIF(sepet + CARGOPRICE - VOUCHERVALUE, 0), 0) AS int) AS oran4
    FROM sip
)
SELECT oran4, COUNT(*) AS siparisAdet, MIN(SERVICEPRICE) AS minVF, MAX(SERVICEPRICE) AS maxVF
FROM oranli
GROUP BY oran4
ORDER BY siparisAdet DESC;

-- 4) DOGRULAMA ORNEKLERI: her tarife kademesinden 2 guncel siparis (iyzico panelinde taksit sayisi bakilacak)
--    Sabitlik kaniti: %38,33 kademesinde sepet 390 TL ile 2.356 TL AYNI orani veriyor (6 kat fark, oran sabit).
WITH sip AS (
    SELECT o.ORDERCODE, o.ORDERDATE, o.APPLICATION, o.SERVICEPRICE, o.CARGOPRICE, o.VOUCHERVALUE, o.TOTALPRICE,
           ISNULL(d.satirToplam, 0) AS sepet
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
        OUTER APPLY (
            SELECT SUM(dt.QUANTITY * dt.SELLINGPRICE) AS satirToplam
            FROM ODAKJOKER.JOKER.dbo.J_ORDER_DETAILS dt
            WHERE dt.ORDERREF = o.ORDERID
        ) d
    WHERE o.ORDERDATE >= '20260710'
      AND o.PAYDEFREF = -13
      AND o.SERVICEPRICE > 0
), oranli AS (
    SELECT *,
           CAST(ROUND(10000.0 * SERVICEPRICE / NULLIF(sepet + CARGOPRICE - VOUCHERVALUE, 0), 0) AS int) AS oran4
    FROM sip
), siralı AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY oran4 ORDER BY ORDERDATE DESC) AS rn
    FROM oranli
    WHERE oran4 IN (1044, 1352, 1629, 1962, 3114, 3833)
)
SELECT oran4, ORDERCODE, ORDERDATE, APPLICATION, sepet, SERVICEPRICE AS vadeFarki, CARGOPRICE AS kargo, TOTALPRICE AS toplam
FROM siralı
WHERE rn <= 2
ORDER BY oran4, ORDERDATE DESC;

/*
  Elenen yanlis izler (tekrar aranmasin):
    - b2c.ayar.vadeFarkiStkID = 0  -> vade farki urunu TANIMSIZ; ayrica bu entegrasyon 2018'den olu (JOKER'e gecilmis).
        SELECT vadeFarkiStkID, vadeFarkiKdvID, endPoint, sonUrunAktarimTarih FROM DerinSISBkm.b2c.ayar;
    - urn stkID 303636 "Vade Farklari" (stkKod G-760.30.027, urnTip=1) -> GIDER carisi urunu (BKM'nin odedigi), musteri satiri degil.
    - J_ORDERS.PRICEWITHVAT -> her zaman 0 (olu kolon). Fark hesabinda payda olarak KULLANMA.
    - SIPARIS_ODEME_DURUM view -> ORDERDATE < '01/01/2022' filtreli (olu); tahsilEdilenTutar vade farki icermez.
    - TOTALPRICE - (satir toplami + kargo + servis) > 1 olan ~49 siparis (01-14 Tem) -> vade farki DEGIL, veri tutarsizligi
      (or. TS140730670160: 799 TL'lik satir toplamda iki kez, detayda bir kez).
*/
