/* =====================================================================
   BKM Kitap — Mobil App Kullanım Baremli Rapor / SQL Sorguları
   Tarih:       14 Nisan 2026
   Hazırlayan:  Fikri Eren
   Kaynak:      ODAKJOKER.JOKER linked server
   Dönem:       H15 = 6–12 Nis 2026 (ISO Pzt-Paz) · 90 gün = 15 Oca – 14 Nis
   Not:         Linked server üzerinden YYYYMMDD ISO tarih formatı zorunlu.
                Normal yerel sorgularda DMY (dd.MM.yyyy / 103 / 104) tercih
                edilir; burada '20260406' formatı linked-server uyumu için.
   ===================================================================== */


/* ---------------------------------------------------------------------
   0. KEŞİF — J_ORDERS örnek satır (kolonları görmek için)
   --------------------------------------------------------------------- */
SELECT TOP 1 *
FROM ODAKJOKER.JOKER.dbo.J_ORDERS
WHERE ORDERDATE >= '20260101';


/* ---------------------------------------------------------------------
   0.1 H15 kanal dağılımı — APPLICATION değerleri
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
   0.2 CLIENTREF kontrol — her sipariş yeni CLIENTREF mi yaratıyor?
   --------------------------------------------------------------------- */
SELECT TOP 5
    CLIENTREF,
    COUNT(*) AS N
FROM ODAKJOKER.JOKER.dbo.J_ORDERS
WHERE ORDERDATE >= '20260115'
GROUP BY CLIENTREF
ORDER BY N DESC;
/* Sonuç: max 3. CLIENTREF = sipariş-sahibi cari kartı, master müşteri değil.
   Gerçek müşteri için J_CLCARD.CUSTOMERREF kullanılmalı.                    */


/* ---------------------------------------------------------------------
   0.3 Şema keşif — müşteri / mail / üye kolonları
   --------------------------------------------------------------------- */
SELECT TABLE_NAME, COLUMN_NAME
FROM ODAKJOKER.JOKER.INFORMATION_SCHEMA.COLUMNS
WHERE (COLUMN_NAME LIKE '%MAIL%'
    OR COLUMN_NAME LIKE '%MEMBER%'
    OR COLUMN_NAME LIKE '%USER%'
    OR COLUMN_NAME LIKE '%MUSTERI%'
    OR COLUMN_NAME LIKE '%CUSTOMER%'
    OR COLUMN_NAME LIKE '%PHONE%'
    OR COLUMN_NAME LIKE '%GSM%')
  AND TABLE_NAME LIKE 'J_%'
ORDER BY TABLE_NAME, COLUMN_NAME;
/* Kritik bulgu: J_CLCARD(CUSTOMERREF, CMAIL, CPHONE) master müşteridir.
   J_ORDERS.CLIENTREF = J_CLCARD.LOGICALREF (1-1).                            */


/* ---------------------------------------------------------------------
   0.4 CLIENTREF → CUSTOMERREF eşlemesini doğrula
   --------------------------------------------------------------------- */
SELECT TOP 5
    o.CLIENTREF,
    c.LOGICALREF,
    c.CUSTOMERREF,
    c.CMAIL
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
LEFT JOIN ODAKJOKER.JOKER.dbo.J_CLCARD c
       ON c.LOGICALREF = o.CLIENTREF
WHERE o.ORDERDATE >= '20260410';


/* =====================================================================
   1. KULLANICI SIKLIK BAREMI — App siparişleri (son 90 gün)
      CUSTOMERREF master müşteri bazlı, Android + iOS birleştirilmiş
   ===================================================================== */
WITH AppOrders AS (
    SELECT
        c.CUSTOMERREF,
        o.TOTALPRICE
    FROM ODAKJOKER.JOKER.dbo.J_ORDERS  o
    JOIN ODAKJOKER.JOKER.dbo.J_CLCARD  c
      ON c.LOGICALREF = o.CLIENTREF
    WHERE o.ORDERDATE  >= '20260115'
      AND o.ORDERDATE  <  '20260415'
      AND o.APPLICATION IN ('Mobil Uygulama (Android)',
                            'Mobil Uygulama (iOS)')
      AND c.CUSTOMERREF IS NOT NULL
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
            WHEN SiparisSayisi = 1                    THEN '1 | Tek sipariş'
            WHEN SiparisSayisi BETWEEN 2  AND 3       THEN '2 | 2-3 sipariş'
            WHEN SiparisSayisi BETWEEN 4  AND 6       THEN '3 | 4-6 sipariş'
            WHEN SiparisSayisi BETWEEN 7  AND 12      THEN '4 | 7-12 sipariş'
            ELSE                                            '5 | 13+ sipariş'
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
      Android / iOS kırılımı ile birlikte
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
      ÖNEMLİ: CASE içi iç içe >10 düzey SQL Server limiti.
              DATEDIFF/7 ile tek ifadede gruplanıyor.
      Baseline: 2025-12-29 (Pzt) = H01 başlangıcı
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
   EK NOTLAR (NEDEN BÖYLE?)
   =====================================================================
   · ORDERDATE filtresinde tarih literali YYYYMMDD formatında — linked
     server (MS OLEDB) için Türkçe yerel tarih formatında ('13.04.2026')
     hata ve sessiz yanlış eşleşme riski var. Tek güvenli format ISO.

   · CLIENTREF gerçek müşteri ID değil, sipariş-sahibi cari kartı.
     Her siparişte yeni kart açılabildiği için max tekrar 3 görüldü.
     Master müşteri için MUTLAKA J_CLCARD.CUSTOMERREF.

   · DATEFIRST önceki raporlarda Sunday-start veriyordu. ISO için
     DATEDIFF(DAY, <Pazartesi-baseline>, tarih)/7 yaklaşımı set-yönü
     bağımlılığı olmadan çalışıyor — DATEFIRST değişse de sonuç aynı.

   · J_ITEMSBARCODE bu barem analizinde kullanılmıyor (ürün barkod
     eşlemesi gerekmiyor). Top-SKU / kategori barem analizlerinde
     devreye girer.

   · WITH (NOLOCK) kullanılmıyor — linked server üzerinden default
     okuma hafif ve canlı OLTP'yi yormuyor. Eğer günlük cron'a
     alınacaksa NOLOCK tercih edilir.
   ===================================================================== */
