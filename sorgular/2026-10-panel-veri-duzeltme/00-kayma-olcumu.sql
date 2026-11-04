-- ork:hedef-db JOKER
-- ork:compat 150
/* Soru     : E-ticaret Eylül 2026 kapalı dönem neti kayıyor mu? Sipariş sayısı ve net ciro, bugünkü STATUS dağılımı.
   AC       : SC-006 (girdi) · R2: Koşu 1 + 7 takvim günü sonra T-003 aynı sorguyu tekrar koşar
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026), JOKER ORDERDATE
   Tolerans : birebir (sayım) · ≤ 1,00 TL (tutar)
   Önce     : referans 02.10.2026: 113.731 sipariş · 121.955.096,47 TL
   Sonra    : T-003 Koşu 2
   Bağımsız : (kaynak içi kimlik, bağımsız kanıt değil: A ve B aynı J_ORDERS kaynağından)
              blok B sipariş toplamı (hariç tutulan durumlar dışı) = blok A sipariş sayısı
   Kural    : satır iptali (2004/2005/2010) ciro ve sipariş sayısına UYGULANMAZ, yalnız ODAK talebine uygulanır
              (denetleyici kararı KR-2; H04-odak-talep.sql). Başlık süzgeci 1001, 1006, 1007, 3000, 4000 (A bloğu).
   Aynı kaynak — neden: EVET. A ve B aynı J_ORDERS tablosundan okur; amaç ham sayımın iki yönden (başlık kuralı / durum dağılımı)
              tutarlılığıdır, kaynak bağımsızlığı değildir. Kayma kendisi (zamanla değişim) Koşu 1 ↔ Koşu 2 ile ölçülür.
   Başka ne olabilir: (1) kapalı dönemde durum geçişi kural İÇİ kodlar arasındaysa (1005/3004/3006) sipariş ve ciro sabit kalır,
              kayma görünmez; ciroyu oynatan geçiş kural DIŞI koda (1001/1006/1007/3000/4000) olandır. (2) ORDERDATE değişmişse
              sipariş dönem dışına kayar; bu blokta ORDERDATE yeniden yazımı ayrıca izlenmez (ÇIKARIM: yazılmıyor).
              (3) A tarih değişkenleri @BasIso/@BitIso, B ise @BasIso2/@BitIso2: iki bloğun dönemi aynıdır (aynı literal).
              Koşu: bloklar tarih literal'i ile sq.sh'ten koşuldu (sq.sh DECLARE taşımaz); SSMS'te bloklar kendi DECLARE'iyle çalışır.
   Dondurma : 18c2ce0
   SSMS     : JOKER tarihi ISO yyyyMMdd string; bloklar kendi @BasIso/@BitIso bildirimini taşır (aşağıda).

   Koşu 1: 03.10.2026 23:42 · Sip=113.710 · Ciro=121.911.116,36
   (T-001 blok D ile aynı: 113.710 / 121.911.116,36 TL. 02.10 referansına göre −21 sipariş, −43.980,11 TL.)

   Koşu 1 B (STATUS, tüm Eylül siparişleri): 1001 = 3.401 · 1005 = 103.800 · 1006 = 773 · 3004 = 5.820 · 3006 = 4.090
              Kural kapsamı (1001/1006 hariç; 1007, 3000, 4000 Eylül’de yok): 103.800 + 5.820 + 4.090 = 113.710 (A ile birebir).
   Koşu 2: 04.10.2026 22:10 (aynı bloklar; T-019 yeniden ölçümü) · Sip=113.710 · Ciro=121.911.116,36 (Koşu 1 ile aynı)
   Koşu 2 B : 1001 = 3.401 · 1005 = 107.488 · 1006 = 773 · 3004 = 2.721 · 3006 = 3.501; kural kapsamı 107.488 + 2.721 + 3.501
              = 113.710 (A ile birebir). Dağılım kaydı (1005 +3.688; 3004 −3.099; 3006 −589) kural içinde kalan kodlar arasındadır,
              toplam değişmedi (ÇIKARIM: durum ilerlemesi; sipariş bazında izlenmedi).
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
