/* ═══════════════════════════════════════════════════════════════════════════════
   SEZON AKSİYON LİSTESİ — SSMS'te çalışan tam sorgu
   GMY 15.09.2026: "bana sql sorgusunu da verir misin"

   Panelin (/sezon-aksiyon) ve Excel scriptinin
   (scripts/sezon_aksiyon_listesi_excel.py) AYNI iş mantığı.

   ── HESAP ──────────────────────────────────────────────────────────────────────
     Geçen sezon TAMAMI = Ağustos + Eylül + Ekim  (GMY: "sezon 8 9 10 ayrı olsun")
     ⚠ AÇIK'IN TABANI TÜM SEZON DEĞİL, **KALAN SEZON**'dur (GMY 15.09.2026:
       "açık sadece sezonu geçirmek için gerekli olan değil mi"). Sezonun geçen
       günlerinin malı ZATEN SATILDI; tüm sezonu istemek açığı şişirir.
       ÖLÇÜLDÜ: tüm sezonla AÇIK 254.733.925 ₺ · kalan sezonla 106.946.260 ₺ → 2,4 KAT.
     Kalan sezon talebi = CEILING(geçen yılın KALAN dilimi × (1 + büyüme))
     Elde      = FSM + Özlüce + İst.Yolu + Depo(merkez)
     AÇIK      = Satılacak − Elde   (pozitifse)  → sipariş / transfer
     FAZLA     = Elde − Satılacak   (pozitifse)  → indirim / iade / transfer
     Tutar     = AÇIK'ta satış fiyatıyla (kaçacak ciro), FAZLA'da maliyetle (bağlı sermaye)

   ── ÜÇ PENCERE ────────────────────────────────────────────────────────────────
     1) AYNI PENCERE (kıyas)  geçen 01.08.2025–13.09.2025 · bu 01.08.2026–13.09.2026
        GMY: "okul açılışına takılma, rapor 01/08'den başlasın".
        Geçen yılın penceresi bu yılınkinin ay/gün AYNASIDIR → uzunluk her zaman EŞİT.
        ⚠ Farklı uzunlukta iki pencere SAHTE büyüme üretir ve hata vermez.
     2) SEZON AYLARI (taban)  Ağustos · Eylül · Ekim — ayrı kolon, toplamı Satılacak'ın tabanı
        SEZON DIŞI = Yıllık − Sezon (Kas–Tem). GMY: "ayrıca sezon dışı ... toplam satış".
     3) YILLIK (bağlam)       01.08.2025–31.07.2026, 365 gün. GMY: "01/08/2025-31/07/2026
        arası olsun 365 gün". Geçen sezonu TAM İÇERİR, bu sezona TAŞMAZ.
        ⚠ Eski "365 günde satılan" [kesim−364, kesim] idi ve geçen sezonun başını
          KAÇIRIYORDU (bir üründe 365g=33 iken sezon=652 görünüyordu) — kaldırıldı.

   ⚠ BEYAN — TAKVİM HİZASI: okul açılışı yıldan yıla kayıyor (08.09.2025 → 14.09.2026,
     altı gün). Ölçüldü: Hazırlık Kitapları büyümesi takvimle 0,727 ("%27 küçüldü"),
     okula hizalı 1,104 ("%10 büyüdü") — aynı veri, zıt sonuç. Takvim yönü GMY kararıyla
     bilinçli seçildi; sayı okunurken bu bilinmeli.

   ── SINIRLAR (rakamı kullanmadan önce oku) ────────────────────────────────────
     · Açık sipariş DÜŞÜLMEZ. ERP'de "kapalı" durumu (sip.eDurum=2) 24.02.2025'ten beri
       hiç yazılmıyor; kapatılmamış alış siparişi adedinin %86,4'ü bir yıldan eski.
     · FAZLA tutarı ALT SINIR — maliyeti yok/şüpheli (TMS 2: 0 < maliyet ≤ satış fiyatı)
       satırlar adet olarak sayılır, paraya girmez.
     · Depo stoğu WMS kaynaklı; ERP defteriyle çelişebilir (hayalet stok).
     · Tek gün fotoğrafı. Alıcı (satınalmacı) boyutu veride YOK — kişiye atıf değildir.
     · "Bu sezon aynı dönem = 0" satırlarda eksik olan STOK DEĞİL TALEP olabilir: AÇIK
       listesinin 10.865 ürününde mal RAFTA duruyor ve 44 günde hiç satmamış (40,4M ₺).
       Bkz. sorgular/2026-09-15-ayni-pencere-ve-yanlis-alarm.sql
   ═══════════════════════════════════════════════════════════════════════════════ */

DECLARE @kesim    date  = '2026-09-13',   -- taban kesimi (bkm.SatisAnaliziTaban)
        @sezonYil int   = 2025,           -- geçen sezon yılı
        @buyume   float = 0.20,           -- büyüme varsayımı
        @durum    varchar(10) = NULL;     -- NULL=hepsi · 'acik' · 'fazla'

-- ── PENCERELER — bu yılınki seçilir, geçen yılınki AYNALANIR (uzunluk eşit kalır) ──
DECLARE @bBas date = DATEFROMPARTS(YEAR(@kesim), 8, 1),                  -- bu yıl: 1 Ağustos
        @bSon date = @kesim;                                             -- bu yıl: kesim
-- Pencere sezon sonunu (31 Ekim) aşmaz.
IF @bSon > DATEFROMPARTS(YEAR(@kesim), 10, 31) SET @bSon = DATEFROMPARTS(YEAR(@kesim), 10, 31);

DECLARE @yilFarki int  = YEAR(@kesim) - @sezonYil;
DECLARE @gBas date = DATEADD(YEAR, -@yilFarki, @bBas),                   -- geçen yıl aynası
        @gSon date = DATEADD(YEAR, -@yilFarki, @bSon);

-- KALAN sezon dilimi: bu yıl kesimin ERTESİ günü – 31.10; geçen yıl AYNASI (gün sayısı eşit).
DECLARE @kBas date = DATEADD(DAY, 1, @bSon),
        @kSon date = DATEFROMPARTS(YEAR(@bSon), 10, 31);
DECLARE @gkBas date = DATEADD(YEAR, -@yilFarki, @kBas),
        @gkSon date = DATEADD(YEAR, -@yilFarki, @kSon);

IF @kBas > @kSon
BEGIN
    RAISERROR('Sezon bitmis - kalan talep yok.', 16, 1);
    RETURN;
END;

-- YILLIK: sezon başından bir sonraki sezon başının bir gün öncesine (365 gün).
DECLARE @yBas date = DATEFROMPARTS(@sezonYil, 8, 1),
        @ySon date = DATEADD(DAY, -1, DATEFROMPARTS(@sezonYil + 1, 8, 1));

-- ⚠ EŞİT UZUNLUK KAPISI: iki pencere eşit değilse kıyas SAHTEdir — koşmadan dur.
IF DATEDIFF(DAY, @bBas, @bSon) <> DATEDIFF(DAY, @gBas, @gSon)
BEGIN
    RAISERROR('Pencereler esit uzunlukta degil - kiyas gecersiz.', 16, 1);
    RETURN;
END;

WITH gh AS (   -- GEÇEN yılın penceresi
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)               -- FSM · Özlüce · İst.Yolu
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)          -- satış(1,4,100) − iade(3,5,101)
      -- ⚠ ÜST SINIR DIŞLAYICI ve GECE YARISI. "<= son gün 23:59:59.9999999" YAZILMAZ:
      --   SQL `datetime` 3,33 ms çözünürlüklü, o değer ERTESİ GÜNE yuvarlanıyor ve
      --   pencereyi bir gün uzatıyor (ölçüldü 15.09.2026, panelde 20 adetlik sapma).
      AND h.ehTrhS >= @gBas AND h.ehTrhS < DATEADD(DAY, 1, @gSon)
    GROUP BY h.ehstkID
),
bh AS (        -- BU yılın penceresi — gün sayısı gh ile BİREBİR aynı
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= @bBas AND h.ehTrhS < DATEADD(DAY, 1, @bSon)
    GROUP BY h.ehstkID
),
gk AS (        -- GEÇEN yılın KALAN sezon dilimi — AÇIK/FAZLA'nın TABANI
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= @gkBas AND h.ehTrhS < DATEADD(DAY, 1, @gkSon)
    GROUP BY h.ehstkID
),
yl AS (        -- YILLIK 365 gün: 01.08.<sezon> – 31.07.<sezon+1>
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= @yBas AND h.ehTrhS < DATEADD(DAY, 1, @ySon)
    GROUP BY h.ehstkID
)
SELECT t.stkAd                                         AS [Ürün],
       t.Kategori3                                     AS [Kategori],
       -- KATEGORİ YOLU: KatAna → Kat1 → Kat2 → Kat3 → Kat4, boş basamak ATLANIR.
       -- ⚠ Kategori3 AYRI bir sözlüktür (urnKtgr2.ktgrAd), bu yola GİRMEZ.
       STUFF(ISNULL(N' > ' + NULLIF(t.Kategori1, N''), N'')
           + ISNULL(N' > ' + NULLIF(t.Kat1, N''), N'')
           + ISNULL(N' > ' + NULLIF(t.Kat2, N''), N'')
           + ISNULL(N' > ' + NULLIF(t.Kat3, N''), N'')
           + ISNULL(N' > ' + NULLIF(t.Kat4, N''), N''), 1, 3, N'') AS [Kategori yolu],
       -- ⚠ Taban kolonunun adı 'Yayinevi' ama kaynağı UrunBilgi.mrkAd — yani MARKA.
       --   Kitapta yayınevi, kırtasiyede marka aynı alandan gelir.
       t.Yayinevi                                      AS [Marka / Yayınevi],
       u.stkKod                                        AS [Stok kodu],   -- ⚠ BARKOD DEĞİL
       t.BarkodAna                                     AS [Barkod],
       t.stkID                                         AS [stkID],

       -- ── AYNI PENCERE ─────────────────────────────────────────────────────
       CONVERT(int, ISNULL(gh.Adet, 0))                AS [Geçen yıl aynı dönem],
       CONVERT(int, ISNULL(bh.Adet, 0))                AS [Bu yıl 01.08-bugün],
       -- Geçen yıl 0 ise oran YOK (NULL) — "sonsuz büyüme" uydurulmaz.
       CONVERT(decimal(10,2), CASE WHEN ISNULL(gh.Adet, 0) > 0
            THEN CONVERT(float, ISNULL(bh.Adet, 0)) / gh.Adet END)      AS [Değişim],

       -- ── SEZON AYLARI + TOPLAM + YILLIK ───────────────────────────────────
       t.Ay1                                           AS [Ağustos],
       t.Ay2                                           AS [Eylül],
       t.Ay3                                           AS [Ekim],
       t.SezonToplam                                   AS [Sezon toplam],
       CONVERT(int, ISNULL(yl.Adet, 0))                AS [Yıllık toplam],
       -- SEZON DIŞI = yıllık − sezon → Kasım–Temmuz net satışı.
       -- ⚠ EKSİ ÇIKABİLİR ve bu GERÇEKTİR: o aylarda iade satıştan fazlaysa net negatiftir.
       --   ÖLÇÜLDÜ 15.09.2026: 85.274 çeşidin 29'unda öyle (stkID 1545705 — sezon 7 adet,
       --   Haz-2026'da 13 adet iade → yıllık −1, sezon dışı −8). Sıfıra KIRPILMIYOR;
       --   kırpmak iadeyi gizlemek olurdu.
       CONVERT(int, ISNULL(yl.Adet, 0) - t.SezonToplam) AS [Sezon dışı],
       CONVERT(int, ISNULL(gk.Adet, 0))                AS [Geçen yıl kalan dönem],
       s.Satilacak                                     AS [KALAN sezon talebi],

       -- ── STOK ─────────────────────────────────────────────────────────────
       t.StokFsm                                       AS [FSM],
       t.StokOzl                                       AS [Özlüce],
       t.StokIst                                       AS [İst.Yolu],
       t.MagazaStok                                    AS [Mağaza toplam],
       t.MerkezStok                                    AS [Depo],
       s.Elde                                          AS [Toplam stok],

       CONVERT(int, CASE WHEN s.Satilacak > s.Elde THEN s.Satilacak - s.Elde ELSE 0 END) AS [AÇIK],
       CONVERT(int, CASE WHEN s.Elde > s.Satilacak THEN s.Elde - s.Satilacak ELSE 0 END) AS [FAZLA],

       CONVERT(decimal(18,4), t.SatisFiyat)            AS [Satış fiyatı],
       CONVERT(decimal(18,4), CASE WHEN t.BirimMaliyet > 0
                                    AND t.BirimMaliyet <= t.SatisFiyat
            THEN t.BirimMaliyet END)                   AS [Birim maliyet],
       -- TEK tutar kolonu: AÇIK'ta satış fiyatı, FAZLA'da maliyet. İKİSİ TOPLANMAZ.
       CONVERT(decimal(18,2), CASE
            WHEN s.Satilacak > s.Elde THEN (s.Satilacak - s.Elde) * t.SatisFiyat
            WHEN s.Elde > s.Satilacak AND t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat
                 THEN (s.Elde - s.Satilacak) * t.BirimMaliyet END)      AS [Tutar],

       CASE WHEN s.Satilacak > s.Elde THEN N'AÇIK'
            WHEN s.Elde > s.Satilacak THEN N'FAZLA'
            ELSE N'DENGE' END                          AS [Durum]

FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID   -- stkKod için
LEFT JOIN gh ON gh.stkID = t.stkID
LEFT JOIN bh ON bh.stkID = t.stkID
LEFT JOIN gk ON gk.stkID = t.stkID
LEFT JOIN yl ON yl.stkID = t.stkID
-- ⚠ TABAN KALAN SEZON: gk (geçen yılın kalan dilimi), t.SezonToplam DEĞİL.
-- ⚠ NEGATİF TALEP OLMAZ: gk negatifse (iade > satış) sıfıra kırpılır. Kırpılmazsa
--   stoğu SIFIR olan ürün bile "fazla" görünür (ölçüldü: 27 negatif, 4'ü stoksuz).
CROSS APPLY (SELECT Satilacak = CASE WHEN ISNULL(gk.Adet, 0) > 0
                         THEN CONVERT(int, CEILING(gk.Adet * (1.0 + @buyume))) ELSE 0 END,
                    Elde      = t.MagazaStok + t.MerkezStok) s
WHERE t.Kesim = @kesim AND t.SezonYil = @sezonYil
  AND t.SezonToplam > 0                       -- geçen sezon FİİLEN satmış
  -- DEFTER GÜVENİLİR: negatif stok fiziksel durum değil, defter hatasıdır.
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
  AND (@durum IS NULL
       OR (@durum = 'acik'  AND s.Satilacak > s.Elde)
       OR (@durum = 'fazla' AND s.Elde > s.Satilacak))
ORDER BY CASE WHEN s.Satilacak > s.Elde THEN (s.Satilacak - s.Elde) * t.SatisFiyat
              ELSE (s.Elde - s.Satilacak) * ISNULL(t.BirimMaliyet, 0) END DESC;

/* ─────────────────────────────────────────────────────────────────────────────
   ÖLÇÜLDÜ (kesim 13.09.2026 · sezon 2025 · büyüme %20) — 85.274 çeşit
     AÇIK   18.368 ürün ·   313.858 adet · 106.946.260 ₺ (satış fiyatıyla)
     FAZLA  59.724 ürün · 3.247.379 adet · 128.831.137 ₺ (maliyetle)
   ⚠ Bu rakamlar KALAN sezon tabanlıdır. Tüm sezon tabanıyla AÇIK 254.733.925 ₺
     çıkıyordu (2,4 kat) — o rakam sezonun geçen günlerini de sipariş ettiriyordu.
   Panel, Excel emitter'ı ve Excel PivotTable'ı bu sorguyla BİREBİR aynı.
   ───────────────────────────────────────────────────────────────────────────── */


/* ═══════════════════════════════════════════════════════════════════════════════
   MARKA ÖZETİ — Excel'deki MARKA PivotTable'ının SQL karşılığı.
   Yukarıdaki DECLARE bloğu bu sorgu için de geçerlidir (aynı oturumda çalıştır).
   ═══════════════════════════════════════════════════════════════════════════════ */
SELECT ISNULL(t.Yayinevi, N'(marka yok)')                             AS [Marka / Yayınevi],
       COUNT(*)                                                       AS [Çeşit],
       CONVERT(bigint, SUM(CASE WHEN s.Satilacak > s.Elde
            THEN s.Satilacak - s.Elde ELSE 0 END))                    AS [AÇIK adet],
       CONVERT(decimal(18,2), SUM(CASE WHEN s.Satilacak > s.Elde
            THEN (s.Satilacak - s.Elde) * t.SatisFiyat ELSE 0 END))   AS [AÇIK toplam ₺],
       CONVERT(bigint, SUM(CASE WHEN s.Elde > s.Satilacak
            THEN s.Elde - s.Satilacak ELSE 0 END))                    AS [FAZLA adet],
       CONVERT(decimal(18,2), SUM(CASE WHEN s.Elde > s.Satilacak
            AND t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat
            THEN (s.Elde - s.Satilacak) * t.BirimMaliyet ELSE 0 END)) AS [FAZLA toplam ₺]
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN (SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
           FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
           WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
             AND h.ehTrhS >= @gkBas AND h.ehTrhS < DATEADD(DAY,1,@gkSon)
           GROUP BY h.ehstkID) gk ON gk.stkID = t.stkID
-- ⚠ NEGATİF TALEP OLMAZ: gk negatifse (iade > satış) sıfıra kırpılır. Kırpılmazsa
--   stoğu SIFIR olan ürün bile "fazla" görünür (ölçüldü: 27 negatif, 4'ü stoksuz).
CROSS APPLY (SELECT Satilacak = CASE WHEN ISNULL(gk.Adet, 0) > 0
                         THEN CONVERT(int, CEILING(gk.Adet * (1.0 + @buyume))) ELSE 0 END,
                    Elde      = t.MagazaStok + t.MerkezStok) s
WHERE t.Kesim = @kesim AND t.SezonYil = @sezonYil AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
GROUP BY t.Yayinevi
ORDER BY [AÇIK toplam ₺] DESC;

/* ÖLÇÜLDÜ: 2.634 marka. İlk beş (AÇIK toplam ₺):
     PARAF Yayınları        320 çeşit · 21.688 adet · 14.561.962 ₺ · FAZLA 785.368 ₺
     Fenomen Yayınları      149       · 18.378      ·  9.855.040 ₺ · FAZLA  41.859 ₺
     Yanıt Yayınları        190       · 10.877      ·  7.706.586 ₺ · FAZLA 348.744 ₺
     Strateji Yayınları      36       · 10.273      ·  6.660.346 ₺ · FAZLA 108.166 ₺
     Bilgi Sarmal Yay.      102       · 10.970      ·  5.238.156 ₺ · FAZLA  96.234 ₺
   Excel PivotTable'ının Genel Toplamı bu sorguyla birebir tuttu. */


/* ── KONTROL: listenin toplamı ──────────────────────────────────────────────── */
SELECT COUNT(*)                                                       AS Cesit,
       SUM(CASE WHEN s.Satilacak > s.Elde THEN 1 ELSE 0 END)          AS AcikUrun,
       CONVERT(bigint, SUM(CASE WHEN s.Satilacak > s.Elde
            THEN s.Satilacak - s.Elde ELSE 0 END))                    AS AcikAdet,
       CONVERT(decimal(18,0), SUM(CASE WHEN s.Satilacak > s.Elde
            THEN (s.Satilacak - s.Elde) * t.SatisFiyat ELSE 0 END))   AS AcikTL,
       SUM(CASE WHEN s.Elde > s.Satilacak THEN 1 ELSE 0 END)          AS FazlaUrun,
       CONVERT(bigint, SUM(CASE WHEN s.Elde > s.Satilacak
            THEN s.Elde - s.Satilacak ELSE 0 END))                    AS FazlaAdet,
       CONVERT(decimal(18,0), SUM(CASE WHEN s.Elde > s.Satilacak
            AND t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat
            THEN (s.Elde - s.Satilacak) * t.BirimMaliyet ELSE 0 END)) AS FazlaTL
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN (SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
           FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
           WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
             AND h.ehTrhS >= @gkBas AND h.ehTrhS < DATEADD(DAY,1,@gkSon)
           GROUP BY h.ehstkID) gk ON gk.stkID = t.stkID
-- ⚠ NEGATİF TALEP OLMAZ: gk negatifse (iade > satış) sıfıra kırpılır. Kırpılmazsa
--   stoğu SIFIR olan ürün bile "fazla" görünür (ölçüldü: 27 negatif, 4'ü stoksuz).
CROSS APPLY (SELECT Satilacak = CASE WHEN ISNULL(gk.Adet, 0) > 0
                         THEN CONVERT(int, CEILING(gk.Adet * (1.0 + @buyume))) ELSE 0 END,
                    Elde      = t.MagazaStok + t.MerkezStok) s
WHERE t.Kesim = @kesim AND t.SezonYil = @sezonYil AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0;
