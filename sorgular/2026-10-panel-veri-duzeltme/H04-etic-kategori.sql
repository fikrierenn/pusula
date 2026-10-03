-- ork:hedef-db JOKER
-- ork:compat 150
/* Soru     : E-ticaret kategori kırılımının toplamı, iptal/iade siparişleri düşülmüş ana cirodan farklı mı?
   AC       : AC-4.1, AC-4.2 · Spec 001 · H04 · KR-2 (kategori ve ana ciro SİPARİŞ başlık STATUS kuralıyla)
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026), JOKER ORDERDATE
   Tolerans : sayı birebir · tutar ≤ 1,00 TL (Tolerans.Tutar)
   Kural    : başlık o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000)
              kaynak: sema/codes.yaml joker.J_ORDERS.STATUS.net_iptal_iade (okundu 04.10.2026).
              Satır iptali (2004/2005/2010) ciroya UYGULANMAZ, yalnız ODAK talebine (H04-odak-talep.sql).
   Önce     : EticQueries.GetEticKategoriAsync (satır ~251) mantığı: STATUS süzgeci YOK, kategorisi NULL satır
              düşürülür (ji.DERINSIS_LOGOGRUP IS NOT NULL). Blok ONCE.
              Referans 02.10.2026: ana 126.329.033,57 TL / 117.884 sipariş (süzgeçsiz).
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : A↔B KAPISI: Σ A.net_ciro (kategorisi NULL satır DAHİL) = B.net_ciro (fark ≤ 1,00 TL),
              Σ A.adet = B.adet. A.siparis toplamı B.siparis'ten büyük olabilir (çok kategorili sipariş) — kapı değil.
   Referans : ana net güncel (T-001 D / T-002 Koşu 1, 03.10.2026 23:42): 121.911.116,36 TL / 113.710 sipariş
              (02.10.2026: 121.955.096,47 / 113.731 — 21 sipariş durum değiştirdi, kapalı ay hâlâ kayıyor).
              Her ikisi de başlıkta; ölçüm saati aşağıda blok sonuçlarıyla birlikte.
   Aynı kaynak — neden: değil. A ve B aynı J_ORDERS/J_ORDER_DETAILS kaynağından kurulur çünkü kapı tam da
              "kırılım toplamı ana ciroya eşit mi" sorusudur; bağımsızlık A↔B eşitliğinin kendisiyle (farklı
              gruplama, ayrı CTE) sağlanır; ana ciro ayrıca T-001 blok D ile birebir karşılaştırılır.
   Başka ne olabilir: (1) kategori toplamı ana cirodan küçükse sebep süzgeç değil, J_ITEMS'ta karşılığı olmayan
              ya da LOGOGRUP'u boş satırlardır (panel bunları düşürüyordu) — bu yüzden NULL kategori satırı tutulur.
              (2) Satır net_tutar kolonu SELLINGPRICEWITHOUTVAT (birim KDV hariç) × QUANTITY; kolon farkı değil süzgeç farkı aranır.
              (3) Kapalı ay durum değişiminden dolayı kayar (02.10 → 03.10: −21 sipariş); ölçüm saati olmadan kıyas yapılmaz.
   Koşu 1   : 04.10.2026 01:10 (bash tools/sq.sh --joker, literal tarihli blok)
              B    : 113.710 sipariş · 121.911.116,36 TL · 531.731 adet (T-001 D / 03.10 23:42 ile birebir)
              A    : 12 kategori satırı, NULL kategori satırı YOK (bilinmeyen = 'Tanımsız' 1.282 sipariş / 470.969,58 TL);
                     Σ net_ciro = 121.911.116,36 · Σ adet = 531.731 → A↔B KAPISI GEÇTİ (fark 0,00 TL, 0 adet)
                     Kitap 57.674.121,56 · Çocuk Kitabı 31.162.940,83 · Hazırlık 19.309.865,27 ·
                     Akademi 10.368.573,83 · Kırtasiye 2.572.666,98
              ONCE : 12 satır; Σ net_ciro = 126.328.958,17 TL (02.10 referansı 126.329.033,57; −75,40 TL kayma)
                     Önce − Sonra = 4.417.841,81 TL (panelin fazla saydığı iptal/iade sipariş cirosu)
   Dondurma : 1103192
   SSMS     : -- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso VARCHAR(8) = '20260901', @BitIso VARCHAR(8) = '20261001';  -- ISO (JOKER)
              Bloklar GO ile ayrılır. sq.sh DECLARE koşmaz: koşuda @BasIso/@BitIso literal yazılır.
   Komut    : bash tools/sq.sh --joker --max-rows 100000 "<tek blok, literal tarihli>" (depo kökünden).
   Bloklar  : A (Kategori, Siparis, NetCiro, Adet) · B (Siparis, NetCiro) · ONCE (Kategori, Siparis, NetCiro, Adet)
   Nüfus    : A satır > 0 ve Σ siparis > 0; B Siparis > 0; ONCE satır > 0. Sıfır ise KOŞAMADI (kapı yeşil sayılmaz).
*/

-- blok: A  (kategori kırılımı, başlık STATUS kuralıyla; kategorisi bilinmeyen = NULL)
-- ork:izin RUN-007 JOKER J_ORDERS/J_ORDER_DETAILS/J_ITEMS'ta soft-delete kolonu yok; iptal STATUS ile süzülür
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso VARCHAR(8) = '20260901', @BitIso VARCHAR(8) = '20261001';   -- ISO (JOKER)
SELECT
    ji.DERINSIS_LOGOGRUP AS kategori,
    COUNT(DISTINCT o.ORDERID) AS siparis,
    SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT) AS net_ciro,
    CAST(SUM(d.QUANTITY) AS INT) AS adet
FROM JOKER.dbo.J_ORDERS AS o
    INNER JOIN JOKER.dbo.J_ORDER_DETAILS AS d
        ON o.ORDERID = d.ORDERREF
    LEFT JOIN JOKER.dbo.J_ITEMS AS ji
        ON d.ITEMREF = ji.LOGICALREF
WHERE
    o.ORDERDATE >= @BasIso
    AND o.ORDERDATE < @BitIso
    AND o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000)
GROUP BY ji.DERINSIS_LOGOGRUP
ORDER BY net_ciro DESC;
GO

-- blok: B  (ana ciro, kategori kırılımsız; 00-kayma-olcumu blok A ile aynı kural)
-- ork:izin RUN-007 JOKER J_ORDERS/J_ORDER_DETAILS'ta soft-delete kolonu yok; iptal STATUS ile süzülür
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso2 VARCHAR(8) = '20260901', @BitIso2 VARCHAR(8) = '20261001';   -- ISO (JOKER)
WITH Baslik AS (
    SELECT o.ORDERID AS siparis_id
    FROM JOKER.dbo.J_ORDERS AS o
    WHERE
        o.ORDERDATE >= @BasIso2
        AND o.ORDERDATE < @BitIso2
        AND o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000)
)

SELECT
    (SELECT COUNT(*) FROM Baslik) AS siparis,
    SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT) AS net_ciro,
    CAST(SUM(d.QUANTITY) AS INT) AS adet
FROM JOKER.dbo.J_ORDER_DETAILS AS d
    INNER JOIN Baslik AS b
        ON d.ORDERREF = b.siparis_id;
GO

-- blok: ONCE  (panelin bugünkü mantığı: STATUS süzgeci yok, kategorisi NULL düşer; yalnız 'önce' ölçümü)
-- ork:izin RUN-007 JOKER J_ORDERS/J_ORDER_DETAILS/J_ITEMS'ta soft-delete kolonu yok
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso3 VARCHAR(8) = '20260901', @BitIso3 VARCHAR(8) = '20261001';   -- ISO (JOKER)
SELECT
    ji.DERINSIS_LOGOGRUP AS kategori,
    COUNT(DISTINCT o.ORDERID) AS siparis,
    SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT) AS net_ciro,
    CAST(SUM(d.QUANTITY) AS INT) AS adet
FROM JOKER.dbo.J_ORDER_DETAILS AS d
    INNER JOIN JOKER.dbo.J_ORDERS AS o
        ON d.ORDERREF = o.ORDERID
    INNER JOIN JOKER.dbo.J_ITEMS AS ji
        ON d.ITEMREF = ji.LOGICALREF
WHERE
    o.ORDERDATE >= @BasIso3
    AND o.ORDERDATE < @BitIso3
    AND ji.DERINSIS_LOGOGRUP IS NOT NULL
GROUP BY ji.DERINSIS_LOGOGRUP
ORDER BY net_ciro DESC;
GO
