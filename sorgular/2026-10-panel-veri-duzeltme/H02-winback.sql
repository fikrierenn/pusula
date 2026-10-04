-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Win-back listesinde son 90 günde fiş kesmiş müşteri var mı? Sıklık yalnız satış fişi mi sayıyor?
   AC       : AC-2.1, AC-2.2, AC-2.3, AC-2.4 · Spec 001 · H02
   Dönem    : @Bugun parametresi (gün başı). Aday penceresi [@Bugun-365, @Bugun); hareketsizlik penceresi [@Bugun-90, @Bugun)
              Ölçüm günü 04.10.2026 (bitiş hariç)
   Tolerans : müşteri kümesi birebir (liste kümesi ve kesişim sayısı); Frq ve GunIdle birebir
   Önce     : GetWinBackAsync SQL'i (SadakatQueries.cs), @Bugun = 04.10.2026, TOP 200 ve elle liste olmadan.
              Dosya dışı: T-006 ölçümü (defter, 04.10.2026); panel SQL'i bu dosyada yok, blok olarak yeniden koşulamaz.
              ÇIKARIM etiketi: değerler panel SQL'inin kendisinden değil, müşteri kimliği önce toplanıp ad/telefon/kart ile
              gruplanan EŞDEĞER biçimden alındı (ham biçim 500 sn'de zaman aşımına düştü; panel komut zaman aşımı 30 sn):
              liste 51.821 satır · son 90 günde satış fişi olan satır 22.832 (%44,1) · çok kimlikli satır 0
   Sonra    : yok (düzeltme T-033 sonrası ölçülür)
   Bağımsız : (kaynak içi; yöntem bağımsız, 04.10.2026, sqlcli encore profili, --read-only)
              A 88.634 müşteri · B 276.949 · C 274.336 · D 200 (tekil)
              · N aday 274.541 · eşik geçen 65.110 · eşik geçen ve son 90 günde fişli 36.906 · CRM kaydı olmayan 0
              · iç kart kuralı (isim/telefon) ile dışlanan 3 · kanonik liste tam uzunluk 28.201;
              D ∩ A = 0 · D'de GunIdle en az 91 · Frq en az 3
              F1001: pencerede 1001 kalemli satış fişi 9 (9 müşteri) · eşik geçen 65.110 (N ile aynı) ·
              1001 fişleri Frq'dan çıkarılırsa eşik geçen 65.109 (1 müşteri düşer)
   Blok kapsamı: A–D ve N bu dosyadadır; A kesişim sınaması, B tüm zaman son satış, C yalnız satış fişi sıklığı,
              D kanonik TOP 200 liste, N nüfus, F1001 1001 etkisi. Hepsi AYNI kaynaktan (Sales); bağımsız kanıt değil.
   Fiş tanımı: Frq = Sales.DocumentsTypeId = 1 fişleri; 1001 (geri dönüşüm) kalemi taşıyan fişler DAHİL (W-05: H05 ve
              00-taban D2 'fiş' tanımından farklıdır, orada 1001 ayrı ele alınır). Etki blok F1001'de ölçülür: 9 fiş / 9 müşteri,
              eşik kümesinde 1 müşterilik fark; tanım değişikliği gerekmez, ama 'fiş' kelimesi bu dosyada 1001 dahil anlamındadır.
   Panel farkları (dosya dışı: T-006 ölçümü, defter): (1) ToplCiro penceresi panelde kanonikten farklıdır, 10 müşteri eşik
              kararında ayrışır; (2) elle iç kart listesi (PanelIcKart) kanonikte yok, T-033 testi @IcIds'i iki tarafa da verir;
              (3) SonSatis kanonikte datetime (gün başı), kontrat date: T-033 DateOnly'ye çevirir.
   Aynı kaynak — neden: müşteri bağı (Sales.CustomersId = DerinCrm.Customer.Id) yalnız Encore/DerinCrm'de var, ERP'de
              karşılığı yok; kaynak bağımsız değil, yöntem bağımsız (panel müşteriyi ad/telefon/kart ile gruplar ve
              90 gün dışlamasını yalnız tarih penceresine bırakır; burada müşteri CustomersId ile gruplanır, 90 günde
              fişi olan müşteri NOT EXISTS ile ayrıca elenir).
   Başka ne olabilir: (1) aynı kişinin birden çok CustomersId'si olabilir (kart yenileme); küme CustomersId düzeyindedir,
              kişi düzeyi değil. (2) DerinCrm.Customer satırı olmayan müşteri listeye alınmaz (ad/telefon yok, aranamaz);
              panel de INNER JOIN ile aynısını yapıyor; etkisi blok N'de ayrı sayılır. (3) @Bugun gün başı olduğundan
              bugünkü fişler pencerelerin dışında; gün içi koşuda 90 gün içindeki bugünkü fiş dışlamayı etkilemez.
              (4) İade belgesi sıklığı artırmaz (AC-2.3) ama ToplCiro'ya negatif girer; yalnız iadesi olup fişi olmayan müşteri
              Frq = 0 olduğundan zaten listeye giremez. (5) Elle işaretli iç kart listesi uygulanmadı (aşağıya bak).
   İç kart  : isim (Mağaza/Kumbara) + telefon 599/699 öneki (IcKartFiltre kuralı, sql-server-conventions § müşteri raporları).
              Elle liste okunamadı: BkmPanel dbo.PanelIcKart bu makinede yok / sunucuya bağlanılamadı (sqlcli panel
              profili: 'Sunucu bulunamadı') — etkisi: liste küçük, panel tarafında da aynı liste uygulanır.
              Etki ölçümü (isim+telefon kuralıyla dışlanan müşteri) blok N'de ayrı sütundadır.
   Kapsam   : Satış fişi = Sales.DocumentsTypeId = 1; müşteri = Sales.CustomersId > 0; ToplCiro DocumentsTypeId IN (1,3),
              net = GrossTotal − DiscountTotal − VatTotal (KDV hariç), iade (3) negatif; Frq >= 3 ve ToplCiro >= 500.
   Dondurma : 47e7030
   SSMS     : DECLARE @Bugun datetime = CONVERT(datetime, '04.10.2026', 104);
   Komut    : sqlcli --param ISO tarih ister; bloklar GO'suz ve DECLARE'siz, literal tarihle koşuldu (SSMS DECLARE + GO esas).
   Not      : iç kart süzgeci NOT (... NULL olabilir ...) değil, pozitif ISNULL biçimindedir (c.Name NULL ise satır düşmez; bugün 0).
   Bloklar  : A son 90 günde satış fişi olan müşteriler (MusteriId) · B tüm zaman son satış fişi (MusteriId, SonSatis)
              · C pencerede satış fişi sayısı (MusteriId, Frq) · D kanonik liste TOP 200 (MusteriId)
              · F1001 1001 kalemli satış fişi etkisi (tek satır) · N nüfus sayıları (tek satır)
   Nüfus    : boş nüfus 'bakamadım'dır, 'temiz' değil; blok N her koşuda beklenen büyüklükte dönmelidir.
*/

-- blok: A  (son 90 günde satış fişi olan müşteriler)
DECLARE @Bugun datetime = CONVERT(datetime, '04.10.2026', 104);  -- DMY

SELECT s.CustomersId AS MusteriId
FROM EncoreMerkez.dbo.Sales AS s
WHERE
    s.DocumentsTypeId = 1
    AND s.CustomersId > 0
    AND s.[Date] >= DATEADD(DAY, -90, @Bugun)
    AND s.[Date] < @Bugun
GROUP BY s.CustomersId
ORDER BY s.CustomersId;
GO

-- blok: B  (tüm zaman son satış fişi tarihi; @Bugun'den önceki fişler)
DECLARE @Bugun datetime = CONVERT(datetime, '04.10.2026', 104);  -- DMY

SELECT
    s.CustomersId AS MusteriId,
    DATEADD(DAY, DATEDIFF(DAY, 0, MAX(s.[Date])), 0) AS SonSatis
FROM EncoreMerkez.dbo.Sales AS s
WHERE
    s.DocumentsTypeId = 1
    AND s.CustomersId > 0
    AND s.[Date] < @Bugun
GROUP BY s.CustomersId
ORDER BY s.CustomersId;
GO

-- blok: C  (son 365 günde satış fişi sayısı; iade belgesi sayılmaz)
DECLARE @Bugun datetime = CONVERT(datetime, '04.10.2026', 104);  -- DMY

SELECT
    s.CustomersId AS MusteriId,
    COUNT(*) AS Frq
FROM EncoreMerkez.dbo.Sales AS s
WHERE
    s.DocumentsTypeId = 1
    AND s.CustomersId > 0
    AND s.[Date] >= DATEADD(DAY, -365, @Bugun)
    AND s.[Date] < @Bugun
GROUP BY s.CustomersId
ORDER BY s.CustomersId;
GO

-- blok: D  (kanonik win-back listesi, TOP 200)
DECLARE @Bugun datetime = CONVERT(datetime, '04.10.2026', 104);  -- DMY

WITH Aday AS (
    SELECT
        s.CustomersId AS musteri_id,
        SUM(CASE WHEN s.DocumentsTypeId = 1 THEN 1 ELSE 0 END) AS frq,
        SUM(CASE
            WHEN s.DocumentsTypeId = 3
                THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
            ELSE (s.GrossTotal - s.DiscountTotal - s.VatTotal)
        END) AS topl_ciro
    FROM EncoreMerkez.dbo.Sales AS s
    WHERE
        s.DocumentsTypeId IN (1, 3)
        AND s.CustomersId > 0
        AND s.[Date] >= DATEADD(DAY, -365, @Bugun)
        AND s.[Date] < @Bugun
    GROUP BY s.CustomersId
)

SELECT TOP 200 a.musteri_id AS MusteriId
FROM Aday AS a
    INNER JOIN DerinCrm.dbo.Customer AS c
        ON a.musteri_id = c.Id
WHERE
    a.frq >= 3
    AND a.topl_ciro >= 500
    AND NOT EXISTS (
        SELECT 1
        FROM EncoreMerkez.dbo.Sales AS s90
        WHERE
            s90.CustomersId = a.musteri_id
            AND s90.DocumentsTypeId = 1
            AND s90.[Date] >= DATEADD(DAY, -90, @Bugun)
            AND s90.[Date] < @Bugun
    )
    AND ISNULL(c.Name, N'') NOT LIKE N'%Mağaza%' COLLATE Turkish_CI_AS
    AND ISNULL(c.Name, N'') NOT LIKE N'%Kumbara%' COLLATE Turkish_CI_AS
    AND ISNULL(c.PhoneNumber, '') NOT LIKE '599%'
    AND ISNULL(c.PhoneNumber, '') NOT LIKE '699%'
ORDER BY a.topl_ciro DESC, a.musteri_id ASC;
GO

-- blok: F1001  (Frq'ya giren satış fişlerinden 1001 (geri dönüşüm) kalemi taşıyanlar; Frq 1001'siz olsaydı eşik kümesi kaç kişi küçülür)
DECLARE @Bugun datetime = CONVERT(datetime, '04.10.2026', 104);  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId AS satis_id
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B, 00-taban-olcumu blok A ile aynı)
    WHERE sp.BarcodeNo = '1001'
),

Aday AS (
    SELECT
        s.CustomersId AS musteri_id,
        SUM(CASE WHEN s.DocumentsTypeId = 1 THEN 1 ELSE 0 END) AS frq,
        SUM(CASE WHEN s.DocumentsTypeId = 1 AND gd.satis_id IS NOT NULL THEN 1 ELSE 0 END) AS frq_1001,
        SUM(CASE
            WHEN s.DocumentsTypeId = 3
                THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
            ELSE (s.GrossTotal - s.DiscountTotal - s.VatTotal)
        END) AS topl_ciro
    FROM EncoreMerkez.dbo.Sales AS s
        LEFT JOIN Gd AS gd
            ON s.Id = gd.satis_id
    WHERE
        s.DocumentsTypeId IN (1, 3)
        AND s.CustomersId > 0
        AND s.[Date] >= DATEADD(DAY, -365, @Bugun)
        AND s.[Date] < @Bugun
    GROUP BY s.CustomersId
)

SELECT
    SUM(a.frq_1001) AS fis_1001_pencerede,
    SUM(CASE WHEN a.frq_1001 > 0 THEN 1 ELSE 0 END) AS musteri_1001_fisli,
    SUM(CASE WHEN a.frq >= 3 AND a.topl_ciro >= 500 THEN 1 ELSE 0 END) AS esik_gecen,
    SUM(CASE WHEN a.frq - a.frq_1001 >= 3 AND a.topl_ciro >= 500 THEN 1 ELSE 0 END) AS esik_gecen_1001_fissiz_frq,
    SUM(CASE WHEN a.frq >= 3 AND a.topl_ciro >= 500 AND a.frq - a.frq_1001 < 3 THEN 1 ELSE 0 END) AS esikten_dusen
FROM Aday AS a;
GO

-- blok: N  (nüfus: aday ve eleme sayıları; tek satır)
DECLARE @Bugun datetime = CONVERT(datetime, '04.10.2026', 104);  -- DMY

WITH Aday AS (
    SELECT
        s.CustomersId AS musteri_id,
        SUM(CASE WHEN s.DocumentsTypeId = 1 THEN 1 ELSE 0 END) AS frq,
        SUM(CASE
            WHEN s.DocumentsTypeId = 3
                THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
            ELSE (s.GrossTotal - s.DiscountTotal - s.VatTotal)
        END) AS topl_ciro
    FROM EncoreMerkez.dbo.Sales AS s
    WHERE
        s.DocumentsTypeId IN (1, 3)
        AND s.CustomersId > 0
        AND s.[Date] >= DATEADD(DAY, -365, @Bugun)
        AND s.[Date] < @Bugun
    GROUP BY s.CustomersId
),

Esikli AS (
    SELECT a.musteri_id
    FROM Aday AS a
    WHERE
        a.frq >= 3
        AND a.topl_ciro >= 500
),

Son90 AS (
    SELECT DISTINCT s.CustomersId AS musteri_id
    FROM EncoreMerkez.dbo.Sales AS s
    WHERE
        s.DocumentsTypeId = 1
        AND s.CustomersId > 0
        AND s.[Date] >= DATEADD(DAY, -90, @Bugun)
        AND s.[Date] < @Bugun
)

SELECT
    (SELECT COUNT(*) FROM Aday) AS aday_musteri_365,
    (SELECT COUNT(*) FROM Esikli) AS esik_gecen_365,
    (SELECT COUNT(*) FROM Esikli AS e INNER JOIN Son90 AS z ON e.musteri_id = z.musteri_id) AS esik_gecen_son90_fisli,
    (
        SELECT COUNT(*) FROM Esikli AS e
        WHERE NOT EXISTS (
            SELECT 1 FROM DerinCrm.dbo.Customer AS c
            WHERE c.Id = e.musteri_id
        )
    )
        AS esik_gecen_crm_kaydi_yok,
    (
        SELECT COUNT(*)
        FROM Esikli AS e
            INNER JOIN DerinCrm.dbo.Customer AS c ON e.musteri_id = c.Id
        WHERE
            NOT EXISTS (
                SELECT 1 FROM Son90 AS z
                WHERE z.musteri_id = e.musteri_id
            )
            AND (
                ISNULL(c.Name, N'') LIKE N'%Mağaza%' COLLATE Turkish_CI_AS
                OR ISNULL(c.Name, N'') LIKE N'%Kumbara%' COLLATE Turkish_CI_AS
                OR ISNULL(c.PhoneNumber, '') LIKE '599%'
                OR ISNULL(c.PhoneNumber, '') LIKE '699%'
            )
    ) AS ic_kart_kurali_ile_dislanan,
    (
        SELECT COUNT(*)
        FROM Esikli AS e
            INNER JOIN DerinCrm.dbo.Customer AS c ON e.musteri_id = c.Id
        WHERE
            NOT EXISTS (
                SELECT 1 FROM Son90 AS z
                WHERE z.musteri_id = e.musteri_id
            )
            AND ISNULL(c.Name, N'') NOT LIKE N'%Mağaza%' COLLATE Turkish_CI_AS
            AND ISNULL(c.Name, N'') NOT LIKE N'%Kumbara%' COLLATE Turkish_CI_AS
            AND ISNULL(c.PhoneNumber, '') NOT LIKE '599%'
            AND ISNULL(c.PhoneNumber, '') NOT LIKE '699%'
    ) AS kanonik_liste_tam_uzunluk;
