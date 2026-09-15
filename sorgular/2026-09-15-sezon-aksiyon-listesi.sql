/* ═══════════════════════════════════════════════════════════════════════════════
   SEZON AKSİYON LİSTESİ — SSMS'te çalışan tam sorgu
   GMY 15.09.2026: "bana sql sorgusunu da verir misin"

   Panelin (/sezon-aksiyon) ve Excel scriptinin
   (scripts/sezon_aksiyon_listesi_excel.py) AYNI iş mantığı — üç emitter tek çekirdek.

   ── HESAP ──────────────────────────────────────────────────────────────────────
     KALAN sezon talebi = İKİ TABANIN BÜYÜĞÜ
       (1) GEÇEN YIL tabanı  = geçen yılın KALAN sezon dilimi × oran
       (2) BU YIL HIZ tabanı = bu yılın gerçekleşen günlük hızı × kalan gün

     İhtiyaç MAĞAZA BAZLI hesaplanır (her mağaza kendi ihtiyacıyla kıyaslanır):
       eksik     = Σ max(0, mağaza ihtiyacı − mağaza stoğu)
       fazla     = Σ max(0, mağaza stoğu − mağaza ihtiyacı)
       TAŞINACAK = min(eksik, fazla + depo)     ← ÖNCE eldeki taşınır
       SATIN AL  = eksik − taşınacak            ← ANCAK kalanı sipariş edilir

     Tutar = AÇIK'ta satış fiyatıyla (kaçacak ciro), FAZLA'da maliyetle (bağlı sermaye).
     İKİSİ TOPLANMAZ — farklı taban.

   ── NEDEN İKİ TABAN (GMY 15.09.2026, ölçülmüş vaka) ───────────────────────────
     Geçen yıl tabanı SAĞDAN SANSÜRLÜDÜR: ürün geçen yıl tükendiyse gözlenen satış
     talebi değil, RAFIN BİTTİĞİ YERİ gösterir.

     Mopak Fotokopi Kağıdı 80 Gr A4 Rekort (stkID 21454) — ÖLÇÜLDÜ:
       geçen yıl kalan dilim (14.09–31.10.2025)  ...........    15 adet
       bu yıl aynı pencerede (01.08–13.09.2026)  ........... 1.791 adet (6,18×)
       geçen yıl ay sonu stoğu 30.09.25 FSM 5 / Özlüce 10 / İst.Yolu 0
                               31.10.25 FSM 3 / Özlüce  2 / İst.Yolu 0
       ardından Kas-2025 → Tem-2026 DOKUZ AY sıfır satış, sıfır stok.
     Tek tabanla model "FAZLA 4.527 adet / 529.503 ₺" diyordu. Doğrusu: depodan
     mağazalara 1.152 adet TAŞI. Sansür bayrağı da yakalamıyordu — ay sonu toplamı
     15 ve 5, yani "sıfır değil".

     ⚠ TERSİ DE VAR: Ekim'de satan ürün 13 Eylül'de hâlâ 0 hızdadır. Bu yüzden hız
       tabanı da TEK BAŞINA kullanılmaz; ikisinin büyüğü alınır.

     ÖLÇÜLDÜ (kesim 13.09.2026, tüm evren): bugün FAZLA/SEZONU BİTTİ etiketi alacak
     6.016 çeşitte (160.145 adet stok) hız tabanı stoğun YETMEYECEĞİNİ söylüyor —
     toplam 177.083 adet.

   ── BÜYÜME ORANI ──────────────────────────────────────────────────────────────
     Varsayılan: KATEGORİ BAZLI ÖLÇÜLEN (aynı 44 gün, iki yıl). Elle düz oran girmek
     İSTİSNADIR (@buyume). satinalma-danisman 15.09.2026: "tek kadran hem AÇIK'ı
     büyütüp hem FAZLA'yı küçültüyor — bir parametre, iki savunma."
     ⚠ Kategori tabanı < 2.000 adetse oran oynak → 1,0 alınır. Büyüme UYDURULMAZ.

   ── BEŞ SINIF ─────────────────────────────────────────────────────────────────
     1 AÇIK          satın al   — eksik, eldeki fazla + depo ile kapanmıyor
     4 TRANSFER      taşı       — eksik var ama elden kapanıyor, sipariş GEREKMİYOR
     2 FAZLA         erit       — elde > talep
     3 SEZONU BİTTİ  iade/sakla — geçen yıl kalan dilimde hiç satmamış VE bu yıl da
                                  hız tabanı 0; stoğu duruyor
     0 DENGE         eylem yok

   ── ÜÇ PENCERE ────────────────────────────────────────────────────────────────
     1) AYNI PENCERE (kıyas)  geçen 01.08.2025–13.09.2025 · bu 01.08.2026–13.09.2026
        GMY: "okul açılışına takılma, rapor 01/08'den başlasın".
        Geçen yılın penceresi bu yılınkinin ay/gün AYNASIDIR → uzunluk her zaman EŞİT.
        ⚠ Farklı uzunlukta iki pencere SAHTE büyüme üretir ve hata vermez.
     2) SEZON AYLARI (bağlam) Ağustos · Eylül · Ekim — ayrı kolon.
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
     · AÇIK bir ALT SINIRDIR: geçen yıl tükenmiş ürünlerde gerçek talep daha büyüktür.
       Hız tabanı bunu KISMEN kapatır, tamamen değil (ürün bu yıl da tükenmiş olabilir).
     · FAZLA tutarı ALT SINIR — maliyeti yok/şüpheli (TMS 2: 0 < maliyet ≤ satış fiyatı)
       satırlar adet olarak sayılır, paraya girmez.
     · Depo stoğu WMS kaynaklı; ERP defteriyle çelişebilir (hayalet stok).
     · Tek gün fotoğrafı. Alıcı (satınalmacı) boyutu veride YOK — kişiye atıf DEĞİLDİR.
     · AÇIK ₺ satış fiyatıyla, FAZLA ₺ maliyetle: AÇIK'ta kaybedilen MARJDIR, ciro değil.
     Bkz. sorgular/2026-09-15-ayni-pencere-ve-yanlis-alarm.sql
   ═══════════════════════════════════════════════════════════════════════════════ */

DECLARE @kesim    date  = '2026-09-13',   -- taban kesimi (bkm.SatisAnaliziTaban)
        @sezonYil int   = 2025,           -- geçen sezon yılı
        -- NULL = KATEGORİ BAZLI ÖLÇÜLEN oran (varsayılan, önerilen).
        -- Sayı verilirse düz oran UYGULANIR: 0.20 = %20 büyüme.
        @buyume   float = NULL,
        @durum    varchar(10) = NULL;     -- NULL=hepsi · acik · fazla · bitti · transfer

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

-- HIZ TABANI gün sayıları — KAPSAYICI (iki uç dahil): 01.08–13.09 = 44 gün.
DECLARE @pencereGun float = DATEDIFF(DAY, @bBas, @bSon) + 1,
        @kalanGun   float = DATEDIFF(DAY, @kBas, @kSon) + 1;

-- SANSÜR bayrağı ay sonları (snapshot tablosu YALNIZ ay sonlarını tutar).
DECLARE @snBas date = EOMONTH(@gkBas),
        @snSon date = EOMONTH(@gkSon);

-- ⚠ EŞİT UZUNLUK KAPISI: iki pencere eşit değilse kıyas SAHTEdir — koşmadan dur.
IF DATEDIFF(DAY, @bBas, @bSon) <> DATEDIFF(DAY, @gBas, @gSon)
BEGIN
    RAISERROR('Pencereler esit uzunlukta degil - kiyas gecersiz.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('tempdb..#h') IS NOT NULL DROP TABLE #h;

/* ═══════════════════════════════════════════════════════════════════════════════
   TEK HESAP ÇEKİRDEĞİ → #h
   Üç çıktı bloğu da BU tablodan okur. Aynı mantığı üç kez yazmak, birinin
   güncellenip ötekinin bayatlaması demekti (.claude/rules/emitter-ayrimi.md).
   ═══════════════════════════════════════════════════════════════════════════════ */
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
bhs AS (       -- BU yılın penceresi, MAĞAZA BAZLI → HIZ TABANI
    -- ⚠ 'Top' AYRILMIŞ SÖZCÜK, takma ad olamaz (SQL 156) — üç mağaza ayrı kolon.
    SELECT h.ehstkID AS stkID,
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= @bBas AND h.ehTrhS < DATEADD(DAY, 1, @bSon)
    GROUP BY h.ehstkID
),
gk AS (        -- GEÇEN yılın KALAN sezon dilimi → GEÇEN YIL TABANI
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= @gkBas AND h.ehTrhS < DATEADD(DAY, 1, @gkSon)
    GROUP BY h.ehstkID
),
gks AS (       -- Aynı dilim, MAĞAZA BAZLI — mağaza bazlı ihtiyaç için
    SELECT h.ehstkID AS stkID,
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= @gkBas AND h.ehTrhS < DATEADD(DAY, 1, @gkSon)
    GROUP BY h.ehstkID
),
sn AS (        -- SANSÜR BAYRAĞI: geçen yıl kalan dilimin AY SONLARINDA stok 0 muydu
    -- ⚠ AY SONU fotoğrafı — dilim içinde tükenip sonra dolanı KAÇIRIR → ALT SINIR.
    --   Mopak vakası tam bu kör noktadan geçti (ay sonu 15 ve 5, "sıfır değil").
    SELECT b.stkID,
           Bas = SUM(CASE WHEN b.Donem = @snBas THEN b.Stok ELSE 0 END),
           Son = SUM(CASE WHEN b.Donem = @snSon THEN b.Stok ELSE 0 END)
    FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b WITH (NOLOCK)
    WHERE b.ehMekan IN (1, 4477, 4478) AND b.Donem IN (@snBas, @snSon)
    GROUP BY b.stkID
),
kb AS (        -- KATEGORİ BÜYÜMESİ — ÖLÇÜLEN, elle yazılmayan
    SELECT u.Kategori3 AS Kat,
           Gecen = SUM(CASE WHEN h.ehTrhS >= @gBas AND h.ehTrhS < DATEADD(DAY,1,@gSon)
                            THEN -h.ehAdetN ELSE 0 END),
           Bu    = SUM(CASE WHEN h.ehTrhS >= @bBas AND h.ehTrhS < DATEADD(DAY,1,@bSon)
                            THEN -h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK) ON u.stkID = h.ehstkID
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= @gBas AND h.ehTrhS < DATEADD(DAY, 1, @bSon)
    GROUP BY u.Kategori3
),
yl AS (        -- YILLIK 365 gün: 01.08.<sezon> – 31.07.<sezon+1>
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= @yBas AND h.ehTrhS < DATEADD(DAY, 1, @ySon)
    GROUP BY h.ehstkID
)
SELECT t.stkID,
       t.stkAd, t.Kategori3, t.Kategori1, t.Kat1, t.Kat2, t.Kat3, t.Kat4,
       t.Yayinevi, u.stkKod, t.BarkodAna,
       GecenAyni    = CONVERT(int, ISNULL(gh.Adet, 0)),
       BuAyni       = CONVERT(int, ISNULL(bh.Adet, 0)),
       t.Ay1, t.Ay2, t.Ay3, t.SezonToplam,
       Yillik       = CONVERT(int, ISNULL(yl.Adet, 0)),
       GecenKalan   = CONVERT(int, ISNULL(gk.Adet, 0)),
       -- Geçen yıl kalan dilimde stok tükendiyse taban SANSÜRLÜ: AÇIK alt sınırdır.
       StoksuzKaldi = CONVERT(bit, CASE WHEN ISNULL(sn.Bas,0) <= 0 OR ISNULL(sn.Son,0) <= 0
                                        THEN 1 ELSE 0 END),
       -- Kategori tabanı < 2.000 adetse oran oynak → NULL (sonra 1,0'a düşer).
       KategoriBuyume = CONVERT(decimal(7,4), CASE WHEN kb.Gecen >= 2000
                             THEN CONVERT(float, kb.Bu) / kb.Gecen END),
       UygulananBuyume = o.Oran,
       GecenTabani = b.GecT,
       HizTabani   = b.HizT,
       s.Satilacak,
       t.StokFsm, t.StokOzl, t.StokIst, t.MagazaStok, t.MerkezStok,
       ToplamStok   = s.Elde,
       FsmIhtiyac = m.IhtF, OzlIhtiyac = m.IhtO, IstIhtiyac = m.IhtI,
       MagazaEksigi = m.Eksik, MagazaFazlasi = m.Fazla,
       r.TransferAdet,
       Acik  = r.SatinAl,
       Fazla = CONVERT(int, CASE WHEN s.Elde > s.Satilacak THEN s.Elde - s.Satilacak ELSE 0 END),
       t.SatisFiyat,
       BirimMaliyet = CONVERT(decimal(18,4), CASE WHEN t.BirimMaliyet > 0
                                                   AND t.BirimMaliyet <= t.SatisFiyat
                            THEN t.BirimMaliyet END),
       g.Sinif
INTO #h
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID   -- stkKod için
LEFT JOIN gh  ON gh.stkID  = t.stkID
LEFT JOIN bh  ON bh.stkID  = t.stkID
LEFT JOIN bhs ON bhs.stkID = t.stkID
LEFT JOIN gk  ON gk.stkID  = t.stkID
LEFT JOIN gks ON gks.stkID = t.stkID
LEFT JOIN sn  ON sn.stkID  = t.stkID
LEFT JOIN kb  ON kb.Kat    = t.Kategori3
LEFT JOIN yl  ON yl.stkID  = t.stkID
-- ORAN: @buyume verilmişse düz oran; NULL ise ÖLÇÜLEN kategori büyümesi.
-- ⚠ 4 HANEYE yuvarlanıp öyle çarpılır: GÖSTERİLEN oran = ÇARPILAN oran.
CROSS APPLY (SELECT Oran = CONVERT(decimal(7,4),
                 ISNULL(CASE WHEN @buyume IS NOT NULL THEN 1.0 + @buyume END,
                        ISNULL(CASE WHEN kb.Gecen >= 2000
                                    THEN CONVERT(float, kb.Bu) / kb.Gecen END, 1.0)))) o
-- ── İKİ TABAN ─────────────────────────────────────────────────────────────────
-- ⚠ NEGATİF TALEP OLMAZ: gk negatifse (iade > satış) sıfıra kırpılır. Kırpılmazsa
--   stoğu SIFIR olan ürün bile "fazla" görünür (ölçüldü: 27 negatif, 4'ü stoksuz).
CROSS APPLY (SELECT
        GecF = CEILING(CASE WHEN ISNULL(gks.Fsm,0) > 0 THEN gks.Fsm * o.Oran ELSE 0 END),
        GecO = CEILING(CASE WHEN ISNULL(gks.Ozl,0) > 0 THEN gks.Ozl * o.Oran ELSE 0 END),
        GecI = CEILING(CASE WHEN ISNULL(gks.Ist,0) > 0 THEN gks.Ist * o.Oran ELSE 0 END),
        HizF = CEILING(CASE WHEN ISNULL(bhs.Fsm,0) > 0 THEN bhs.Fsm / @pencereGun * @kalanGun ELSE 0 END),
        HizO = CEILING(CASE WHEN ISNULL(bhs.Ozl,0) > 0 THEN bhs.Ozl / @pencereGun * @kalanGun ELSE 0 END),
        HizI = CEILING(CASE WHEN ISNULL(bhs.Ist,0) > 0 THEN bhs.Ist / @pencereGun * @kalanGun ELSE 0 END),
        GecT = CONVERT(int, CEILING(CASE WHEN ISNULL(gk.Adet,0) > 0 THEN gk.Adet * o.Oran ELSE 0 END)),
        HizT = CONVERT(int, CEILING(CASE WHEN ISNULL(bh.Adet,0) > 0 THEN bh.Adet / @pencereGun * @kalanGun ELSE 0 END))) b
-- MAĞAZA BAZLI İHTİYAÇ = iki tabanın büyüğü, mağaza mağaza.
-- GMY 15.09.2026: "'var' dediğinde de 1 var zaten" — "stok = 0" ölçütü kabaydı;
-- ÖLÇÜLDÜ: taşınabilecek 113.923 adedin yalnız 13.304'ünü görüyordu.
CROSS APPLY (SELECT
        IhtF = CONVERT(int, CASE WHEN b.HizF > b.GecF THEN b.HizF ELSE b.GecF END),
        IhtO = CONVERT(int, CASE WHEN b.HizO > b.GecO THEN b.HizO ELSE b.GecO END),
        IhtI = CONVERT(int, CASE WHEN b.HizI > b.GecI THEN b.HizI ELSE b.GecI END)) m0
CROSS APPLY (SELECT IhtF = m0.IhtF, IhtO = m0.IhtO, IhtI = m0.IhtI,
        Eksik = CASE WHEN m0.IhtF > t.StokFsm THEN m0.IhtF - t.StokFsm ELSE 0 END
              + CASE WHEN m0.IhtO > t.StokOzl THEN m0.IhtO - t.StokOzl ELSE 0 END
              + CASE WHEN m0.IhtI > t.StokIst THEN m0.IhtI - t.StokIst ELSE 0 END,
        Fazla = CASE WHEN t.StokFsm > m0.IhtF THEN t.StokFsm - m0.IhtF ELSE 0 END
              + CASE WHEN t.StokOzl > m0.IhtO THEN t.StokOzl - m0.IhtO ELSE 0 END
              + CASE WHEN t.StokIst > m0.IhtI THEN t.StokIst - m0.IhtI ELSE 0 END) m
CROSS APPLY (SELECT Satilacak = CASE WHEN b.HizT > b.GecT THEN b.HizT ELSE b.GecT END,
                    Elde      = t.MagazaStok + t.MerkezStok) s
-- TAŞINACAK elde + depo ile SINIRLI; ancak kalanı satın alınır.
CROSS APPLY (SELECT
        TransferAdet = CASE WHEN m.Eksik < m.Fazla + t.MerkezStok
                            THEN m.Eksik ELSE m.Fazla + t.MerkezStok END,
        SatinAl      = CASE WHEN m.Eksik > m.Fazla + t.MerkezStok
                            THEN m.Eksik - (m.Fazla + t.MerkezStok) ELSE 0 END) r
-- SINIF ÖNCELİĞİ: sezonu bitti > açık > transfer > fazla > denge.
-- TRANSFER, FAZLA'yı EZER: toplam fazla olsa bile bir raf boşsa eylem "erit" değil "taşı".
CROSS APPLY (SELECT Sinif = CASE
        -- ⚠ HIZ TABANI SEZONU BİTTİ'Yİ EZER: geçen yıl kalan dilimde hiç satmamış
        --   olabilir ama BU YIL satıyorsa sezonu bitmemiştir. Aksi hâlde bu yılın
        --   en hızlı yeni ürünü "iade et" kutusuna düşerdi.
        WHEN ISNULL(gk.Adet, 0) <= 0 AND b.HizT <= 0
             THEN CASE WHEN t.MagazaStok + t.MerkezStok > 0 THEN 3 ELSE 0 END
        WHEN r.SatinAl > 0 THEN 1                                  -- 1 AÇIK (satın al)
        WHEN m.Eksik   > 0 THEN 4                                  -- 4 TRANSFER (taşı)
        WHEN s.Elde > s.Satilacak THEN 2                           -- 2 FAZLA
        ELSE 0 END) g
WHERE t.Kesim = @kesim AND t.SezonYil = @sezonYil
  AND t.SezonToplam > 0                       -- geçen sezon FİİLEN satmış
  -- DEFTER GÜVENİLİR: negatif stok fiziksel durum değil, defter hatasıdır.
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0;

CREATE CLUSTERED INDEX IX_h ON #h (Sinif, stkID);


/* ═══ BLOK 1 — AKSİYON LİSTESİ ════════════════════════════════════════════════ */
SELECT h.stkAd                                         AS [Ürün],
       h.Kategori3                                     AS [Kategori],
       -- KATEGORİ YOLU: KatAna → Kat1 → Kat2 → Kat3 → Kat4, boş basamak ATLANIR.
       -- ⚠ Kategori3 AYRI bir sözlüktür (urnKtgr2.ktgrAd), bu yola GİRMEZ.
       STUFF(ISNULL(N' > ' + NULLIF(h.Kategori1, N''), N'')
           + ISNULL(N' > ' + NULLIF(h.Kat1, N''), N'')
           + ISNULL(N' > ' + NULLIF(h.Kat2, N''), N'')
           + ISNULL(N' > ' + NULLIF(h.Kat3, N''), N'')
           + ISNULL(N' > ' + NULLIF(h.Kat4, N''), N''), 1, 3, N'') AS [Kategori yolu],
       -- ⚠ Taban kolonunun adı 'Yayinevi' ama kaynağı UrunBilgi.mrkAd — yani MARKA.
       h.Yayinevi                                      AS [Marka / Yayınevi],
       h.stkKod                                        AS [Stok kodu],   -- ⚠ BARKOD DEĞİL
       h.BarkodAna                                     AS [Barkod],
       h.stkID                                         AS [stkID],

       -- ── AYNI PENCERE ─────────────────────────────────────────────────────
       h.GecenAyni                                     AS [Geçen yıl aynı dönem],
       h.BuAyni                                        AS [Bu yıl 01.08-bugün],
       -- Geçen yıl 0 ise oran YOK (NULL) — "sonsuz büyüme" uydurulmaz.
       CONVERT(decimal(10,2), CASE WHEN h.GecenAyni > 0
            THEN CONVERT(float, h.BuAyni) / h.GecenAyni END)         AS [Değişim],

       -- ── SEZON AYLARI + TOPLAM + YILLIK ───────────────────────────────────
       h.Ay1 AS [Ağustos], h.Ay2 AS [Eylül], h.Ay3 AS [Ekim],
       h.SezonToplam                                   AS [Sezon toplam],
       h.Yillik                                        AS [Yıllık toplam],
       -- SEZON DIŞI = yıllık − sezon → Kasım–Temmuz net satışı.
       -- ⚠ EKSİ ÇIKABİLİR ve bu GERÇEKTİR: o aylarda iade satıştan fazlaysa net negatiftir.
       --   ÖLÇÜLDÜ 15.09.2026: 85.274 çeşidin 29'unda öyle (stkID 1545705 — sezon 7 adet,
       --   Haz-2026'da 13 adet iade → yıllık −1, sezon dışı −8). Sıfıra KIRPILMIYOR;
       --   kırpmak iadeyi gizlemek olurdu.
       h.Yillik - h.SezonToplam                        AS [Sezon dışı],
       h.GecenKalan                                    AS [Geçen yıl kalan dönem],
       CASE WHEN h.StoksuzKaldi = 1 THEN N'EVET' ELSE N'' END AS [Geçen yıl stoksuz kaldı],
       h.KategoriBuyume                                AS [Kategori büyümesi],
       h.UygulananBuyume                               AS [Uygulanan büyüme],

       -- ── İKİ TABAN — hangisinin bağladığı GÖRÜNÜR ─────────────────────────
       h.GecenTabani                                   AS [Geçen yıl tabanı],
       h.HizTabani                                     AS [Bu yıl hız tabanı],
       h.Satilacak                                     AS [KALAN sezon talebi],
       CASE WHEN h.HizTabani > h.GecenTabani THEN N'bu yıl hızı'
            WHEN h.GecenTabani > 0           THEN N'geçen yıl'
            ELSE N'—' END                              AS [Tabanı bağlayan],

       -- ── MAĞAZA BAZLI İHTİYAÇ ─────────────────────────────────────────────
       h.FsmIhtiyac AS [FSM ihtiyaç], h.OzlIhtiyac AS [Özlüce ihtiyaç],
       h.IstIhtiyac AS [İst.Yolu ihtiyaç],
       h.MagazaEksigi                                  AS [Mağaza eksiği],
       h.MagazaFazlasi                                 AS [Mağaza fazlası],
       h.TransferAdet                                  AS [TAŞINACAK],

       -- ── STOK ─────────────────────────────────────────────────────────────
       h.StokFsm AS [FSM], h.StokOzl AS [Özlüce], h.StokIst AS [İst.Yolu],
       h.MagazaStok AS [Mağaza toplam], h.MerkezStok AS [Depo],
       h.ToplamStok AS [Toplam stok],

       h.Acik                                          AS [AÇIK],
       h.Fazla                                         AS [FAZLA],

       CONVERT(decimal(18,4), h.SatisFiyat)            AS [Satış fiyatı],
       h.BirimMaliyet                                  AS [Birim maliyet],
       -- TEK tutar kolonu: AÇIK'ta satış fiyatı, FAZLA'da maliyet. İKİSİ TOPLANMAZ.
       CONVERT(decimal(18,2), CASE
            WHEN h.Acik  > 0 THEN h.Acik * h.SatisFiyat
            WHEN h.Fazla > 0 AND h.BirimMaliyet IS NOT NULL
                 THEN h.Fazla * h.BirimMaliyet END)    AS [Tutar],

       CASE h.Sinif WHEN 1 THEN N'AÇIK' WHEN 2 THEN N'FAZLA'
                    WHEN 3 THEN N'SEZONU BİTTİ' WHEN 4 THEN N'TRANSFER'
                    ELSE N'DENGE' END                  AS [Durum]
FROM #h h
WHERE @durum IS NULL
   OR (@durum = 'acik'     AND h.Sinif = 1)
   OR (@durum = 'fazla'    AND h.Sinif = 2)
   OR (@durum = 'bitti'    AND h.Sinif = 3)
   OR (@durum = 'transfer' AND h.Sinif = 4)
-- SIRALAMA PARAYA GÖRE: AÇIK'ta kaçacak ciro, ötekilerde bağlı sermaye.
-- İkinci anahtar: aynı tutarda bu sezon HAREKETLİ olan üstte (talebi kanıtlı).
ORDER BY CASE WHEN h.Sinif = 1 THEN h.Acik * h.SatisFiyat
              ELSE h.Fazla * ISNULL(h.BirimMaliyet, 0) END DESC,
         h.BuAyni DESC, h.stkID;


/* ═══ BLOK 2 — MARKA ÖZETİ (Excel'deki MARKA PivotTable'ının SQL karşılığı) ═══ */
SELECT ISNULL(h.Yayinevi, N'(marka yok)')                                     AS [Marka / Yayınevi],
       COUNT(*)                                                               AS [Çeşit],
       CONVERT(bigint, SUM(CASE WHEN h.Sinif = 1 THEN h.Acik ELSE 0 END))     AS [AÇIK adet],
       CONVERT(decimal(18,2), SUM(CASE WHEN h.Sinif = 1
            THEN h.Acik * h.SatisFiyat ELSE 0 END))                           AS [AÇIK toplam ₺],
       CONVERT(bigint, SUM(CASE WHEN h.Sinif = 4 THEN h.TransferAdet ELSE 0 END)) AS [TAŞINACAK adet],
       CONVERT(bigint, SUM(CASE WHEN h.Sinif = 2 THEN h.Fazla ELSE 0 END))    AS [FAZLA adet],
       CONVERT(decimal(18,2), SUM(CASE WHEN h.Sinif = 2 AND h.BirimMaliyet IS NOT NULL
            THEN h.Fazla * h.BirimMaliyet ELSE 0 END))                        AS [FAZLA toplam ₺],
       CONVERT(bigint, SUM(CASE WHEN h.Sinif = 3 THEN h.Fazla ELSE 0 END))    AS [SEZONU BİTTİ adet],
       CONVERT(decimal(18,2), SUM(CASE WHEN h.Sinif = 3 AND h.BirimMaliyet IS NOT NULL
            THEN h.Fazla * h.BirimMaliyet ELSE 0 END))                        AS [SEZONU BİTTİ ₺]
FROM #h h
GROUP BY h.Yayinevi
ORDER BY [AÇIK toplam ₺] DESC;


/* ═══ BLOK 3 — KONTROL: panelin dört kartıyla BİREBİR ═════════════════════════ */
SELECT Cesit = COUNT(*),
       AcikUrun  = SUM(CASE WHEN h.Sinif = 1 THEN 1 ELSE 0 END),
       AcikAdet  = CONVERT(bigint, SUM(CASE WHEN h.Sinif = 1 THEN h.Acik ELSE 0 END)),
       AcikTL    = CONVERT(decimal(18,0), SUM(CASE WHEN h.Sinif = 1
                        THEN h.Acik * h.SatisFiyat ELSE 0 END)),
       TransferUrun = SUM(CASE WHEN h.Sinif = 4 THEN 1 ELSE 0 END),
       TransferAdet = CONVERT(bigint, SUM(CASE WHEN h.Sinif = 4 THEN h.TransferAdet ELSE 0 END)),
       TransferTL   = CONVERT(decimal(18,0), SUM(CASE WHEN h.Sinif = 4
                        THEN h.TransferAdet * h.SatisFiyat ELSE 0 END)),
       FazlaUrun = SUM(CASE WHEN h.Sinif = 2 THEN 1 ELSE 0 END),
       FazlaAdet = CONVERT(bigint, SUM(CASE WHEN h.Sinif = 2 THEN h.Fazla ELSE 0 END)),
       FazlaTL   = CONVERT(decimal(18,0), SUM(CASE WHEN h.Sinif = 2
                        AND h.BirimMaliyet IS NOT NULL THEN h.Fazla * h.BirimMaliyet ELSE 0 END)),
       BittiUrun = SUM(CASE WHEN h.Sinif = 3 THEN 1 ELSE 0 END),
       BittiAdet = CONVERT(bigint, SUM(CASE WHEN h.Sinif = 3 THEN h.Fazla ELSE 0 END)),
       BittiTL   = CONVERT(decimal(18,0), SUM(CASE WHEN h.Sinif = 3
                        AND h.BirimMaliyet IS NOT NULL THEN h.Fazla * h.BirimMaliyet ELSE 0 END)),
       -- Maliyeti yok/şüpheli olduğu için PARAYA girmeyen satırlar (adet sayılır).
       MaliyetsizCesit = SUM(CASE WHEN h.Sinif IN (2,3) AND h.BirimMaliyet IS NULL
                                  THEN 1 ELSE 0 END),
       -- Talebi HANGİ taban bağladı — yeni modelin etkisi tek satırda.
       HizBagladi = SUM(CASE WHEN h.HizTabani > h.GecenTabani THEN 1 ELSE 0 END)
FROM #h h;

DROP TABLE #h;

/* ─────────────────────────────────────────────────────────────────────────────
   ⚠ ÖLÇÜM NOTU: aşağıdaki rakamlar TEK TABANLI (yalnız geçen yıl) sürümdendir.
     İki tabanlı sürümün rakamları BLOK 3 ile yeniden ölçülür; buraya ölçülmemiş
     sayı yazılmaz.
   Tek tabanlı sürüm (kesim 13.09.2026 · sezon 2025 · ölçülen kategori büyümesi):
     AÇIK          17.864 ürün ·   253.907 adet ·  82.091.332 ₺ (satış fiyatıyla)
     FAZLA         28.435 ürün · 2.232.298 adet ·  78.064.273 ₺ (maliyetle)
     TRANSFER      18.064 ürün ·    84.009 adet ·  18.170.771 ₺ (satış fiyatıyla)
     SEZONU BİTTİ  17.193 ürün ·   215.955 adet ·  20.593.740 ₺ (maliyetle)
   Panel, Excel emitter'ı ve Excel PivotTable'ı bu sorguyla AYNI mantığı kurar.
   ───────────────────────────────────────────────────────────────────────────── */
