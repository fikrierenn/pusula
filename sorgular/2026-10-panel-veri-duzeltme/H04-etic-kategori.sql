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
              düşürülür (ji.DERINSIS_LOGOGRUP IS NOT NULL). Blok ONCE (panel SQL'i bu dosyada yok; ONCE onun eşdeğer yeniden
              kuruluşudur, panelin kendi çıktısı değil: ÇIKARIM; panel değeri dosya dışı: T-008 ölçümü, defter).
              Referans 02.10.2026: ana 126.329.033,57 TL / 117.884 sipariş (süzgeçsiz).
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : (kaynak içi; ayrı gruplama ve ayrı CTE, aynı J_ORDERS/J_ORDER_DETAILS kaynağı)
              A↔B KAPISI = YALNIZ fan-out/kategori kırılımı kaybı kontrolü: Σ A.net_ciro (kategorisi NULL satır DAHİL) =
              B.net_ciro (fark ≤ 1,00 TL), Σ A.adet = B.adet. Her ikisi de AYNI başlık STATUS listesini kullandığı için bu kapı
              STATUS listesini sınamaz. A.siparis toplamı B.siparis'ten büyük olabilir (çok kategorili sipariş) — kapı değil.
              TÜMLEYEN KOL (blok C): süzgeçsiz toplam − dışlanan kodlar (1001, 1006, 1007, 3000, 4000) = B.net_ciro ve B.adet;
              STATUS listesi bu kolda listeden bağımsız çıkarımla sınanır. AC-4.2 sipariş birebirliği yalnız B.siparis'ten
              okunur (A.siparis toplamı sipariş sayısı değildir).
   Referans : ana net güncel (T-001 D / T-002 Koşu 1, 03.10.2026 23:42): 121.911.116,36 TL / 113.710 sipariş
              (02.10.2026: 121.955.096,47 / 113.731 — 21 sipariş durum değiştirdi, kapalı ay hâlâ kayıyor).
              Her ikisi de başlıkta; ölçüm saati aşağıda blok sonuçlarıyla birlikte.
   Aynı kaynak — neden: EVET (kaynak içi kimlik). A, B ve C aynı J_ORDERS/J_ORDER_DETAILS kaynağından kurulur çünkü
              kapı tam da "kırılım toplamı ana ciroya eşit mi" sorusudur; kaynak bağımsız değil, yalnız gruplama ve CTE ayrıdır.
              Ana ciro ayrıca T-001 blok D ve 00-kayma-olcumu blok A ile karşılaştırılır (o da aynı kaynak, kaynak içi).
   Başka ne olabilir: (1) kategori toplamı ana cirodan küçükse sebep J_ITEMS'ta karşılığı olmayan ya da LOGOGRUP'u boş
              satırlar olabilir (panel bunları düşürüyor) — bu yüzden NULL kategori satırı tutulur. ÖLÇÜLDÜ: Önce − B farkının
              asıl kaynağı STATUS süzgeci; NULL kategori etkisi blok C kolonlarında (kategorisiz_*) ayrı görülür:
              04.10.2026 22:05 koşusu: kategorisiz (LOGOGRUP NULL ya da J_ITEMS eşleşmesiz) satır tutarı 0,00 TL hem süzgeçsiz hem
              kural kapsamında. Yani 'panel NULL kategoriyi düşürüyor' gerekçesi bu ayda ÇÜRÜK: bilinmeyen kategori NULL değil
              'Tanımsız' etiketli satırdır ve ONCE onu zaten tutar. Önce − B farkı tamamen STATUS (blok C: süzgeçsiz 126.328.958,17 −
              dışlanan 4.417.841,81 = tümleyen 121.911.116,36 = B.net_ciro; tümleyen adet 531.731 = B.adet).
              (2) Satır net_tutar kolonu SELLINGPRICEWITHOUTVAT (birim KDV hariç) × QUANTITY; kolon farkı değil süzgeç farkı aranır.
              (3) Kapalı ay durum değişiminden dolayı kayar (02.10 → 03.10: −21 sipariş); ölçüm saati olmadan kıyas yapılmaz.
   Koşu 2   : 04.10.2026 22:05 (blok C eklendi; B 113.710 sipariş · 121.911.116,36 TL · 531.731 adet, değişmedi;
              ONCE Σ net 126.328.958,17 = C süzgeçsiz toplam)
   Koşu 1   : 04.10.2026 01:10 (bash tools/sq.sh --joker, literal tarihli blok)
              B    : 113.710 sipariş · 121.911.116,36 TL · 531.731 adet (T-001 D / 03.10 23:42 ile birebir)
              A    : 12 kategori satırı, NULL kategori satırı YOK (bilinmeyen = 'Tanımsız' 1.282 sipariş / 470.969,58 TL);
                     Σ net_ciro = 121.911.116,36 · Σ adet = 531.731 → A↔B KAPISI GEÇTİ (fark 0,00 TL, 0 adet)
                     Kitap 57.674.121,56 · Çocuk Kitabı 31.162.940,83 · Hazırlık 19.309.865,27 ·
                     Akademi 10.368.573,83 · Kırtasiye 2.572.666,98
              ONCE : 12 satır; Σ net_ciro = 126.328.958,17 TL (02.10 referansı 126.329.033,57; −75,40 TL kayma)
                     Önce − Sonra = 4.417.841,81 TL (panelin fazla saydığı iptal/iade sipariş cirosu)
   Dondurma : 18c2ce0
   SSMS     : her blok kendi @BasIso.. VARCHAR(8) tarih bildirimini taşır ('20260901' / '20261001', ISO, JOKER).
              Bloklar GO ile ayrılır. sq.sh DECLARE koşmaz: koşuda @BasIso/@BitIso literal yazılır.
   Komut    : bash tools/sq.sh --joker --max-rows 100000 "<tek blok, literal tarihli>" (depo kökünden).
   Bloklar  : A (Kategori, Siparis, NetCiro, Adet) · B (Siparis, NetCiro) · C tümleyen (tum_net, dislanan_net, tumleyen_net,
              tumleyen_adet, kategorisiz_tum_net, kategorisiz_kural_net; tek satır) · ONCE (Kategori, Siparis, NetCiro, Adet)
   Nüfus    : A satır > 0 ve Σ siparis > 0; B Siparis > 0; C tum_net > 0; ONCE satır > 0. Sıfır ise KOŞAMADI (kapı yeşil sayılmaz).
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

-- blok: C  (tümleyen kol: süzgeçsiz toplam − dışlanan STATUS kodları = B; STATUS listesini A'dan bağımsız sınar)
-- ork:izin RUN-007 JOKER J_ORDERS/J_ORDER_DETAILS/J_ITEMS'ta soft-delete kolonu yok; iptal STATUS ile süzülür
-- ork:izin RUN-001 JOKER tarihi ISO yyyyMMdd (RUN-002)
DECLARE @BasIso4 VARCHAR(8) = '20260901', @BitIso4 VARCHAR(8) = '20261001';   -- ISO (JOKER)
WITH Tum AS (
    SELECT
        o.ORDERID AS siparis_id,
        o.STATUS AS siparis_durum,
        ji.DERINSIS_LOGOGRUP AS kategori,
        d.QUANTITY AS adet,
        d.QUANTITY * d.SELLINGPRICEWITHOUTVAT AS net_tutar
    FROM JOKER.dbo.J_ORDERS AS o
        INNER JOIN JOKER.dbo.J_ORDER_DETAILS AS d
            ON o.ORDERID = d.ORDERREF
        LEFT JOIN JOKER.dbo.J_ITEMS AS ji
            ON d.ITEMREF = ji.LOGICALREF
    WHERE
        o.ORDERDATE >= @BasIso4
        AND o.ORDERDATE < @BitIso4
)

SELECT
    SUM(t.net_tutar) AS tum_net,
    SUM(CASE WHEN t.siparis_durum IN (1001, 1006, 1007, 3000, 4000) THEN t.net_tutar ELSE 0 END) AS dislanan_net,
    SUM(t.net_tutar)
    - SUM(CASE WHEN t.siparis_durum IN (1001, 1006, 1007, 3000, 4000) THEN t.net_tutar ELSE 0 END) AS tumleyen_net,
    CAST(SUM(t.adet) AS INT)
    - CAST(SUM(CASE WHEN t.siparis_durum IN (1001, 1006, 1007, 3000, 4000) THEN t.adet ELSE 0 END) AS INT) AS tumleyen_adet,
    SUM(CASE WHEN t.kategori IS NULL THEN t.net_tutar ELSE 0 END) AS kategorisiz_tum_net,
    SUM(CASE WHEN t.kategori IS NULL AND t.siparis_durum NOT IN (1001, 1006, 1007, 3000, 4000) THEN t.net_tutar ELSE 0 END)
        AS kategorisiz_kural_net
FROM Tum AS t;
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
