/* =====================================================================
   BKM Kitap — Mobil App Kullanım Baremli Rapor
   Tarih:       14 Nisan 2026
   Hazırlayan:  Fikri Eren
   Kaynak:      ODAKJOKER.JOKER linked server
   Dönem:       H15 = 6–12 Nis 2026 (ISO Pzt-Paz) · 90 gün = 15 Oca – 14 Nis
   Çıktı:       BKM-Mobil-App-Baremli-Rapor.{md,html}

   STANDARTLAR (00-README.md ile tutarlı):
   · Tarih literali YYYYMMDD ISO zorunlu (linked server)
   · Müşteri eşleme: J_ORDERS.CLIENTREF = J_ORDER_CLIENTS.LOGICALREF
                     → CUSTOMERREF (master müşteri)
   · Hafta: DATEDIFF(DAY, Pazartesi-baseline, tarih)/7 (DATEFIRST bağımsız)
   ===================================================================== */


/* ---------------------------------------------------------------------
   0.1  Keşif — H15 kanal dağılımı (APPLICATION değerlerini gör)
   --------------------------------------------------------------------- */
SELECT
    APPLICATION,
    COUNT(*)        AS Siparis,
    SUM(TOTALPRICE) AS Ciro
FROM ODAKJOKER.JOKER.dbo.J_ORDERS
WHERE ORDERDATE >= '20260406'
  AND ORDERDATE <  '20260413'
GROUP BY APPLICATION
ORDER BY Siparis DESC;


/* ---------------------------------------------------------------------
   0.2  Keşif — CLIENTREF gerçek müşteri mi? (max tekrar 3 → HAYIR,
        müşteri bazlı saymak için CUSTOMERREF'e inmeli)
   --------------------------------------------------------------------- */
SELECT TOP 5
    CLIENTREF,
    COUNT(*) AS N
FROM ODAKJOKER.JOKER.dbo.J_ORDERS
WHERE ORDERDATE >= '20260115'
GROUP BY CLIENTREF
ORDER BY N DESC;


/* ---------------------------------------------------------------------
   0.3  Keşif — J_ORDER_CLIENTS vs J_CLCARD senkron mu?
        Sonuç: AYNI. 13.262.580 satır, aynı LOGICALREF aralığı.
   --------------------------------------------------------------------- */
SELECT 'J_ORDER_CLIENTS' AS T, MIN(LOGICALREF) AS MinRef,
       MAX(LOGICALREF) AS MaxRef, COUNT(*) AS N
FROM ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS
UNION ALL
SELECT 'J_CLCARD', MIN(LOGICALREF), MAX(LOGICALREF), COUNT(*)
FROM ODAKJOKER.JOKER.dbo.J_CLCARD;

-- Aynı CLIENTREF her iki tabloda aynı CUSTOMERREF'i veriyor mu? (AYNI)
SELECT TOP 3
    o.CLIENTREF,
    oc.CUSTOMERREF AS OrderClientsRef,
    cl.CUSTOMERREF AS ClCardRef,
    CASE WHEN oc.CUSTOMERREF = cl.CUSTOMERREF THEN 'AYNI' ELSE 'FARKLI' END AS Kontrol
FROM ODAKJOKER.JOKER.dbo.J_ORDERS         o
LEFT JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF = o.CLIENTREF
LEFT JOIN ODAKJOKER.JOKER.dbo.J_CLCARD        cl ON cl.LOGICALREF = o.CLIENTREF
WHERE o.ORDERDATE >= '20260412';


/* =====================================================================
   1. KULLANICI SIKLIK BAREMI — App siparişleri (son 90 gün)
      CUSTOMERREF master müşteri ile tekilleştirilmiş.
   ===================================================================== */
WITH AppOrders AS (
    SELECT
        oc.CUSTOMERREF,
        o.TOTALPRICE
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS          o
    JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS   oc
      ON oc.LOGICALREF = o.CLIENTREF
    WHERE o.ORDERDATE   >= '20260115'
      AND o.ORDERDATE   <  '20260415'
      AND o.APPLICATION IN ('Mobil Uygulama (Android)',
                            'Mobil Uygulama (iOS)')
      AND oc.CUSTOMERREF IS NOT NULL
      AND oc.CUSTOMERREF > 0           -- 0 = misafir/tanımsız
),
PerCustomer AS (
    SELECT
        CUSTOMERREF,
        COUNT(*)        AS SiparisSayisi,
        SUM(TOTALPRICE) AS ToplamCiro
    FROM AppOrders
    GROUP BY CUSTOMERREF
),
Bareml AS (
    SELECT
        CASE
            WHEN SiparisSayisi = 1                THEN '1 | Tek sipariş'
            WHEN SiparisSayisi BETWEEN 2  AND 3   THEN '2 | 2-3 sipariş'
            WHEN SiparisSayisi BETWEEN 4  AND 6   THEN '3 | 4-6 sipariş'
            WHEN SiparisSayisi BETWEEN 7  AND 12  THEN '4 | 7-12 sipariş'
            ELSE                                       '5 | 13+ sipariş'
        END AS Barem,
        CUSTOMERREF, SiparisSayisi, ToplamCiro
    FROM PerCustomer
)
SELECT
    Barem,
    COUNT(*)                                              AS KullaniciSayisi,
    SUM(SiparisSayisi)                                    AS ToplamSiparis,
    CAST(SUM(ToplamCiro)                AS DECIMAL(18,2)) AS ToplamCiro,
    CAST(SUM(SiparisSayisi) * 1.0 / COUNT(*)
                                        AS DECIMAL(10,2)) AS OrtSiparis_Kullanici,
    CAST(SUM(ToplamCiro)  / SUM(SiparisSayisi)
                                        AS DECIMAL(10,2)) AS OrtSepet
FROM Bareml
GROUP BY Barem
ORDER BY Barem;


/* =====================================================================
   2. SEPET TUTARI BAREMI — H15 App siparişleri (6-12 Nis 2026)
      Android / iOS kırılımı ile birlikte.
   ===================================================================== */
WITH AppH15 AS (
    SELECT
        TOTALPRICE,
        APPLICATION
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS
    WHERE ORDERDATE >= '20260406'
      AND ORDERDATE <  '20260413'
      AND APPLICATION IN ('Mobil Uygulama (Android)',
                          'Mobil Uygulama (iOS)')
),
Bareml AS (
    SELECT
        CASE
            WHEN TOTALPRICE <  200   THEN '1 | 0-200 TL'
            WHEN TOTALPRICE <  500   THEN '2 | 200-500 TL'
            WHEN TOTALPRICE <  1000  THEN '3 | 500-1000 TL'
            WHEN TOTALPRICE <  2000  THEN '4 | 1000-2000 TL'
            WHEN TOTALPRICE <  5000  THEN '5 | 2000-5000 TL'
            ELSE                          '6 | 5000+ TL'
        END AS Barem,
        TOTALPRICE,
        APPLICATION
    FROM AppH15
)
SELECT
    Barem,
    COUNT(*)                                  AS SiparisSayisi,
    CAST(SUM(TOTALPRICE) AS DECIMAL(18,2))    AS ToplamCiro,
    CAST(AVG(TOTALPRICE) AS DECIMAL(10,2))    AS OrtSepet,
    SUM(CASE WHEN APPLICATION LIKE '%Android%' THEN 1 ELSE 0 END) AS Android,
    SUM(CASE WHEN APPLICATION LIKE '%iOS%'     THEN 1 ELSE 0 END) AS iOS
FROM Bareml
GROUP BY Barem
ORDER BY Barem;


/* =====================================================================
   3. 15 HAFTALIK APP SEYRI (ISO Pzt-Paz, 2026 H01-H15)
      ÖNEMLİ: CASE içi iç-içe >10 düzey SQL Server limiti.
              DATEDIFF/7 ile tek ifadede gruplanıyor.
      Baseline: 2025-12-29 Pazartesi = H01 başlangıcı.
   ===================================================================== */
SELECT
    (DATEDIFF(DAY, '20251229', CAST(ORDERDATE AS date)) / 7) + 1 AS Hafta,

    SUM(CASE WHEN APPLICATION = 'Mobil Uygulama (Android)' THEN 1 ELSE 0 END) AS Android,
    SUM(CASE WHEN APPLICATION = 'Mobil Uygulama (iOS)'     THEN 1 ELSE 0 END) AS iOS,
    SUM(CASE WHEN APPLICATION = 'Mobil Site'               THEN 1 ELSE 0 END) AS MobilSite,
    SUM(CASE WHEN APPLICATION = 'Web Sitesi'               THEN 1 ELSE 0 END) AS Web,
    COUNT(*)                                                                  AS Toplam,

    CAST(SUM(CASE WHEN APPLICATION IN ('Mobil Uygulama (Android)',
                                       'Mobil Uygulama (iOS)')
                  THEN TOTALPRICE ELSE 0 END)
         AS DECIMAL(18,0))                                                    AS App_Ciro
FROM ODAKJOKER.JOKER.dbo.J_ORDERS
WHERE ORDERDATE >= '20251229'
  AND ORDERDATE <  '20260413'
GROUP BY (DATEDIFF(DAY, '20251229', CAST(ORDERDATE AS date)) / 7) + 1
ORDER BY Hafta;


/* =====================================================================
   EK NOTLAR
   =====================================================================
   · J_ORDER_CLIENTS ile J_CLCARD birebir senkron (13,26 M satır, aynı
     LOGICALREF domain). Her ikisi de aynı CUSTOMERREF'i döndürüyor.
     Kurumsal standart olarak J_ORDER_CLIENTS tercih ediliyor.

   · CUSTOMERREF = 0 veya NULL kayıtlar "misafir/tanımsız" — master
     müşteri sayımından dışarıda bırakıldı (AppOrders CTE filtresi).

   · ORDERDATE filtresinde tarih literali YYYYMMDD formatında — linked
     server (MS OLEDB) için Türkçe yerel format sessiz yanlış eşleşme
     riski taşıyor. Tek güvenli format ISO.

   · DATEDIFF(DAY, '20251229', tarih)/7 yaklaşımı DATEFIRST ayarından
     bağımsız. 2025-12-29 Pazartesi baseline = ISO Hafta 1.

   · WITH (NOLOCK) kullanılmıyor — canlı OLTP'yi zorlamıyor. Cron
     otomasyonuna alınırsa NOLOCK eklenir.
   ===================================================================== */
