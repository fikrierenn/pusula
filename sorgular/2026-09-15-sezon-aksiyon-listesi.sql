/* ═══════════════════════════════════════════════════════════════════════════════
   SEZON SİPARİŞ LİSTESİ — SSMS'te çalışan tam sorgu
   GMY 15.09.2026: "bana sql sorgusunu da verir misin"

   Panelin (/sezon-aksiyon) ve Excel scriptinin
   (scripts/sezon_aksiyon_listesi_excel.py) AYNI iş mantığı — üç emitter tek çekirdek.

   ── YÖNTEM: SEZON PAYI ────────────────────────────────────────────────────────
   GMY 15.09.2026 verbatim:
     "toplam sezon da satılacak miktarı da yazalım bir yere, şu ana kadar satılanı
      çıkartıp ihtiyacı bulalım, depoda o kadar varsa sorun yok yoksa sipariş lazım"
     "sezonda satılan 3235, 44 günde % kaçı satılmış, o yüzde bizim için;
      17416 adet, kalanı bul"

     ORAN          = geçen sezon OKUL ÖNCESİ satılan ÷ geçen SEZON TOPLAMI
     TAHMİN        = bu sezon OKUL ÖNCESİ satılan ÷ ORAN
     KALAN İHTİYAÇ = TAHMİN − bu sezon BUGÜNE KADAR satılan
     SİPARİŞ       = şubelerin toplam eksiği − merkez depo stoğu

   ⚠ BÜYÜME PARAMETRESİ YOK. Büyümeyi ürünün bu yılki kendi hacmi taşır; oran
     yalnız "sezonun neresindeyiz" sorusunu yanıtlar. Alıcının çevirebileceği
     bir kadran kalmadı (satinalma-danisman: "tek kadran, iki savunma" sorunu).

   ⚠ ZİNCİR ŞUBE DÜZEYİNDE KURULUR. Ürün düzeyinde ayrı bir hesap YAPILMAZ;
     ürün satırı şubelerin toplamıdır. ÖLÇÜLDÜ 15.09.2026 (Kırtasiye, 20.218
     çeşit): iki ayrı hesap varken şube eksikleri toplamı ile sipariş adedi
     4.922 çeşitte (%24,3) uyuşmuyordu, toplam fark 133.594 adet. Ayrıca şube
     payı GEÇEN yıldan alınıyordu; bu yılın dağılımıyla medyan mutlak sapma
     0,390 ve ürünlerin %53,9'unda EN ÇOK SATAN ŞUBE değişmişti.

   ⚠ PENCERE OKUL AÇILIŞINA HİZALI, takvime değil. ÖLÇÜLDÜ 15.09.2026: takvim
     hizasıyla Kırtasiye sezon tahmini 521.262, açılış hizasıyla 643.912 (%23,5
     fark). Sebep: 01.08–13.09.2025 penceresi okul açılışından (08.09.2025)
     SONRAKİ 6 günü içeriyor, 2026'nınki içermiyor (okul 14.09.2026) → oran
     şişip talebi eksik ölçüyordu. Pencereler EŞİT UZUNLUKTA ve açılıştan bir
     gün önce biter.
     Okul açılışı: 11.09.2023 · 09.09.2024 · 08.09.2025 · 14.09.2026.

   ⚠ BACKTEST (ölçüldü 15.09.2026): 2024 oranıyla 2025 sezonu tahmin edildi ve
     gerçekleşenle karşılaştırıldı — Kırtasiye 1.445 çeşit, medyan mutlak hata
     %16,3, medyan yanlılık +%2,1 (yansız). ⚠ O yılda okul kayması 1 gündü
     (09.09.2024 → 08.09.2025); bu yıl 6 gün. Backtest bu riski SINAYAMAZ.

   ⚠ SANSÜR: geçen sezon stoksuz kalan üründe payda kesilir, oran 1'e yaklaşır,
     talep EKSİK ölçülür. ÖLÇÜLDÜ: stoksuz kalanların oran medyanı 0,821 ·
     stoğu olanların 0,588 (Kırtasiye, 42 vs 3.988 çeşit). Bayrak kolonda
     GÖRÜNÜR. Kategori oranına düşürme denendi ve backtest'te KÖTÜLEŞTİ
     (%18,5 → %48,5), o yüzden UYGULANMADI — örneklem 10 çeşit, açık soru.

   ── BEŞ DURUM ─────────────────────────────────────────────────────────────────
     1 SİPARİŞ VER    şube eksikleri merkez depodan karşılanamıyor
     4 DEPODAN GÖNDER toplam yetiyor ama bir şubenin rafı boş; sipariş GEREKMİYOR
     2 FAZLA VAR      elde, kalan ihtiyacı + sezon dışı talebi de aşıyor
     5 ÖLÜ STOK       iki sezondur satmıyor ama stoğu duruyor (erit/iade)
     0 YETERLİ        geri kalan

   ── SINIRLAR (rakamı kullanmadan önce oku) ────────────────────────────────────
     · Açık sipariş DÜŞÜLMEZ. ERP'de "kapalı" durumu (sip.eDurum=2) 24.02.2025'ten
       beri hiç yazılmıyor; kapatılmamış alış siparişinin %86,4'ü bir yıldan eski.
     · SİPARİŞ ₺ satış fiyatıyla, FAZLA/ÖLÜ ₺ maliyetle — TOPLANMAZ. Siparişteki
       tutar kaybedilen CİRODUR, kaybedilen KÂR DEĞİL; marj oranı ölçülmedi.
     · Maliyeti yok/şüpheli (TMS 2: 0 < maliyet ≤ satış fiyatı) satırlar adet
       olarak sayılır, paraya girmez → fazla/ölü tutarı ALT SINIRDIR.
     · Depo stoğu WMS kaynaklı; ERP defteriyle çelişebilir (hayalet stok).
     · Alıcı (satınalmacı) boyutu veride YOK — bu bir GÖREV listesidir, kişiye
       atıf DEĞİLDİR.
     · Ürünün "sezon payı" (sezon satışı ÷ yıllık satış) düşükse ürün sezonluk
       değildir ve yöntem o satırda zayıftır. ÖLÇÜLDÜ (Kırtasiye): medyan 0,500;
       %38,7'si 0,40 altında ve sipariş tutarının %28,7'si o ürünlerden geliyor.
   ═══════════════════════════════════════════════════════════════════════════════ */

DECLARE @kesim    date  = '2026-09-13',   -- taban kesimi (bkm.SatisAnaliziTaban)
        @sezonYil int   = 2025,           -- geçen sezon yılı
        @kategori nvarchar(100) = NULL,   -- Kategori3, ör. N'Kırtasiye'
        @grup     nvarchar(100) = NULL,   -- Kat1 (ürün grubu), ör. N'Defterler'
        @durum    varchar(10)   = NULL;   -- siparis · depodan · fazla · olu

/* ── OKUL AÇILIŞI ───────────────────────────────────────────────────────────
   Pencere buna hizalanır; takvime hizalamak oranı bozar (yukarıda ölçüldü). */
DECLARE @acilis TABLE (Yil int PRIMARY KEY, Trh date);
INSERT INTO @acilis VALUES (2023,'20230911'),(2024,'20240909'),
                           (2025,'20250908'),(2026,'20260914');

DECLARE @gAcilis date = (SELECT Trh FROM @acilis WHERE Yil = @sezonYil),
        @bAcilis date = (SELECT Trh FROM @acilis WHERE Yil = YEAR(@kesim));
IF @gAcilis IS NULL OR @bAcilis IS NULL
BEGIN
    RAISERROR('Okul acilis tarihi tanimsiz - pencere kurulamaz.', 16, 1);
    RETURN;
END;

/* Her iki yıl da "açılıştan bir gün önce" biter, uzunluk KÜÇÜK olana eşitlenir. */
DECLARE @gPenSon date = DATEADD(DAY, -1, @gAcilis),
        @bPenSon date = CASE WHEN @kesim < DATEADD(DAY, -1, @bAcilis)
                             THEN @kesim ELSE DATEADD(DAY, -1, @bAcilis) END;
DECLARE @penGun int = 1 + CASE
        WHEN DATEDIFF(DAY, DATEFROMPARTS(@sezonYil, 8, 1), @gPenSon)
           < DATEDIFF(DAY, DATEFROMPARTS(YEAR(@kesim), 8, 1), @bPenSon)
        THEN DATEDIFF(DAY, DATEFROMPARTS(@sezonYil, 8, 1), @gPenSon)
        ELSE DATEDIFF(DAY, DATEFROMPARTS(YEAR(@kesim), 8, 1), @bPenSon) END;
IF @penGun < 14
BEGIN
    RAISERROR('Okul oncesi pencere cok kisa - oran guvenilmez.', 16, 1);
    RETURN;
END;

DECLARE @gpBas date = DATEADD(DAY, -(@penGun - 1), @gPenSon),
        @bpBas date = DATEADD(DAY, -(@penGun - 1), @bPenSon),
        -- Geçen SEZONUN TAMAMI (oranın paydası)
        @gsBas date = DATEFROMPARTS(@sezonYil, 8, 1),
        @gsSon date = DATEFROMPARTS(@sezonYil, 10, 31),
        -- Bu sezon başından bugüne ("şu ana kadar satılan")
        @btBas date = DATEFROMPARTS(YEAR(@kesim), 8, 1),
        -- Geçen yılın SEZON DIŞI dilimi (yalnız "gelecek sezona kalır mı")
        @gdBas date = DATEFROMPARTS(@sezonYil, 11, 1),
        @gdSon date = DATEFROMPARTS(@sezonYil + 1, 7, 31),
        -- Yıllık 365 gün (bağlam)
        @yBas  date = DATEFROMPARTS(@sezonYil, 8, 1),
        @ySon  date = DATEADD(DAY, -1, DATEFROMPARTS(@sezonYil + 1, 8, 1)),
        -- Sansür bayrağı: geçen sezonun son iki ay sonu
        @snEyl date = EOMONTH(DATEFROMPARTS(@sezonYil, 9, 1)),
        @snEki date = EOMONTH(DATEFROMPARTS(@sezonYil, 10, 1));

/* ⚠ ÜST SINIR DIŞLAYICI ve GECE YARISI. "<= son gün 23:59:59.9999999" YAZILMAZ:
   SQL `datetime` 3,33 ms çözünürlüklü, o değer ERTESİ GÜNE yuvarlanır ve
   pencereyi bir gün uzatır (ölçüldü 15.09.2026, panelde 20 adetlik sapma). */

WITH gp AS (   -- geçen sezon OKUL ÖNCESİ (oranın PAYI)
    SELECT h.ehstkID AS stkID, Adet = -SUM(h.ehAdetN)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= @gpBas AND h.ehTrhS < DATEADD(DAY, 1, @gPenSon)
    GROUP BY h.ehstkID
),
gps AS (       -- aynı pencere, ŞUBE BAZLI
    -- ⚠ 'Top' AYRILMIŞ SÖZCÜK, takma ad olamaz (SQL 156) — üç şube ayrı kolon.
    SELECT h.ehstkID AS stkID,
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= @gpBas AND h.ehTrhS < DATEADD(DAY, 1, @gPenSon)
    GROUP BY h.ehstkID
),
bps AS (       -- bu sezon OKUL ÖNCESİ, ŞUBE BAZLI — gp ile EŞİT UZUNLUKTA
    SELECT h.ehstkID AS stkID,
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= @bpBas AND h.ehTrhS < DATEADD(DAY, 1, @bPenSon)
    GROUP BY h.ehstkID
),
bt AS (        -- bu sezon SEZON BAŞINDAN BUGÜNE ("şu ana kadar satılan")
    -- ⚠ Tahminden ÇIKARILAN budur, hizalı pencere DEĞİL: tahmin TÜM sezonu
    --   söyler, ondan sezon başından beri satılan HER ŞEY düşülür.
    SELECT h.ehstkID AS stkID, Adet = -SUM(h.ehAdetN),
           Fsm = -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END),
           Ozl = -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END),
           Ist = -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= @btBas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
    GROUP BY h.ehstkID
),
sn AS (        -- SANSÜR BAYRAĞI: geçen sezonun ay sonlarında şube stoğu 0 mıydı
    -- ⚠ AY SONU fotoğrafı; dilim içinde tükenip dolanı KAÇIRIR → ALT SINIR.
    SELECT b.stkID,
           Eyl = SUM(CASE WHEN b.Donem = @snEyl THEN b.Stok ELSE 0 END),
           Eki = SUM(CASE WHEN b.Donem = @snEki THEN b.Stok ELSE 0 END)
    FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b WITH (NOLOCK)
    WHERE b.ehMekan IN (1,4477,4478) AND b.Donem IN (@snEyl, @snEki)
    GROUP BY b.stkID
),
kb AS (        -- ALT KATEGORİ (Kat2) ORANI — şubenin kendi ölçümü zayıfsa yedek
    -- GMY 16.09.2026: "geçen sezon kareli defter A marka, bu sene almadık, B aldık."
    -- ÖLÇÜLDÜ (Defterler): bu sezonun satışının %16'sı geçen sezon HİÇ satmamış
    --   üründen geliyor; Butik Defterler'de %46 (2.040 çeşit satmıştı, bu sezon
    --   1.564, ortak yalnız 1.036), buna karşılık Kareli Defter %4.
    -- SKU dönen yerde taban ÜRÜNDE değil ALT KATEGORİDE durur.
    SELECT Kat = tt.Kat2,
           Pencere = SUM(CASE WHEN h.ehTrhS >= @gpBas
                               AND h.ehTrhS < DATEADD(DAY,1,@gPenSon)
                              THEN -h.ehAdetN ELSE 0 END),
           Sezon   = SUM(-h.ehAdetN)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.bkm.SatisAnaliziTaban tt WITH (NOLOCK)
         ON tt.stkID = h.ehstkID AND tt.Kesim = @kesim AND tt.SezonYil = @sezonYil
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= @gsBas AND h.ehTrhS < DATEADD(DAY, 1, @gsSon)
      AND tt.Kat2 IS NOT NULL
    GROUP BY tt.Kat2
),
kb3 AS (       -- Kat2 boşsa ANA KATEGORİ (Kategori3) oranına düşülür
    SELECT Kat = u.Kategori3,
           Pencere = SUM(CASE WHEN h.ehTrhS >= @gpBas
                               AND h.ehTrhS < DATEADD(DAY,1,@gPenSon)
                              THEN -h.ehAdetN ELSE 0 END),
           Sezon   = SUM(-h.ehAdetN)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK) ON u.stkID = h.ehstkID
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= @gsBas AND h.ehTrhS < DATEADD(DAY, 1, @gsSon)
    GROUP BY u.Kategori3
),
gd AS (        -- geçen yılın SEZON DIŞI dilimi
    -- ⚠ SİPARİŞ TETİKLEMEZ. GMY 15.09.2026: "kritik olan bizim için sezonda
    --   yoka düşmemek; sezon sonrası sipariş verilebilir, sorun değil."
    SELECT h.ehstkID AS stkID, Adet = -SUM(h.ehAdetN)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= @gdBas AND h.ehTrhS < DATEADD(DAY, 1, @gdSon)
    GROUP BY h.ehstkID
),
yl AS (        -- YILLIK 365 gün — bağlam, karar vermez
    SELECT h.ehstkID AS stkID, Adet = -SUM(h.ehAdetN)
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= @yBas AND h.ehTrhS < DATEADD(DAY, 1, @ySon)
    GROUP BY h.ehstkID
)
SELECT t.stkAd                                AS [Ürün],
       t.Kategori3                            AS [Kategori],
       ISNULL(t.Kat1, N'')                    AS [Ürün grubu],
       ISNULL(t.Kat2, N'')                    AS [Alt kategori],
       t.Yayinevi                             AS [Marka],
       u.stkKod                               AS [Stok kodu],   -- ⚠ BARKOD DEĞİL
       t.BarkodAna                            AS [Barkod],
       -- ── GEÇEN SEZONUN ÖLÇÜMÜ ────────────────────────────────────────────
       t.SezonToplam                          AS [Geçen sezon toplam satılan],
       CONVERT(int, ISNULL(gp.Adet, 0))       AS [Geçen sezon okul öncesi satılan],
       CASE WHEN ISNULL(sn.Eyl,0) <= 0 OR ISNULL(sn.Eki,0) <= 0
            THEN N'EVET' ELSE N'HAYIR' END    AS [Geçen sezon stoğu bitti mi],
       CONVERT(decimal(6,4), kk.Kat)          AS [Alt kategori ortalama oranı],
       ISNULL(t.Kat2, t.Kategori3)            AS [Oranın alındığı kırılım],
       -- Ürünün sezon payı: düşükse ürün sezonluk DEĞİLDİR, yöntem orada zayıftır.
       CONVERT(decimal(6,3), CASE WHEN ISNULL(yl.Adet,0) > 0
            THEN CONVERT(float, t.SezonToplam) / yl.Adet END) AS [Ürünün sezon payı],
       -- ── BU SEZONUN ÖLÇÜMÜ ───────────────────────────────────────────────
       CONVERT(int, ISNULL(bps.Fsm,0) + ISNULL(bps.Ozl,0) + ISNULL(bps.Ist,0))
                                              AS [Bu sezon okul öncesi satılan],
       CONVERT(int, ISNULL(bt.Adet, 0))       AS [Bu sezon bugüne kadar satılan],
       -- ── ŞUBE BAZLI ZİNCİR (ürün satırı bunların TOPLAMIDIR) ─────────────
       CONVERT(decimal(6,4), po.OrF)          AS [FSM kullanılan oran],
       th.TahF                                AS [FSM bu sezon toplam satacak],
       kl.KalF                                AS [FSM sezonun kalanında satacak],
       t.StokFsm                              AS [FSM stok],
       CASE WHEN kl.KalF > t.StokFsm THEN kl.KalF - t.StokFsm ELSE 0 END
                                              AS [FSM eksik],
       CONVERT(decimal(6,4), po.OrO)          AS [Özlüce kullanılan oran],
       th.TahO                                AS [Özlüce bu sezon toplam satacak],
       kl.KalO                                AS [Özlüce sezonun kalanında satacak],
       t.StokOzl                              AS [Özlüce stok],
       CASE WHEN kl.KalO > t.StokOzl THEN kl.KalO - t.StokOzl ELSE 0 END
                                              AS [Özlüce eksik],
       CONVERT(decimal(6,4), po.OrI)          AS [İst.Yolu kullanılan oran],
       th.TahI                                AS [İst.Yolu bu sezon toplam satacak],
       kl.KalI                                AS [İst.Yolu sezonun kalanında satacak],
       t.StokIst                              AS [İst.Yolu stok],
       CASE WHEN kl.KalI > t.StokIst THEN kl.KalI - t.StokIst ELSE 0 END
                                              AS [İst.Yolu eksik],
       -- ── TOPLAMLAR ───────────────────────────────────────────────────────
       th.TahF + th.TahO + th.TahI            AS [Bu sezon toplam satılacak],
       s.Kalan                                AS [Sezonun kalanında satılacak],
       s.Eksik                                AS [Şubelerde toplam eksik],
       t.MagazaStok                           AS [Mağazalarda toplam stok],
       t.MerkezStok                           AS [Merkez depo stok],
       t.MagazaStok + t.MerkezStok            AS [Mağaza ve depo toplam stok],
       -- ── SONUÇ ───────────────────────────────────────────────────────────
       CASE g.Sinif WHEN 1 THEN N'SİPARİŞ VER' WHEN 4 THEN N'DEPODAN GÖNDER'
                    WHEN 2 THEN N'FAZLA VAR'   WHEN 5 THEN N'ÖLÜ STOK'
                    ELSE N'YETERLİ' END        AS [Durum],
       x.Siparis                              AS [Sipariş verilecek adet],
       CASE WHEN x.Siparis = 0 THEN N''
            WHEN t.OdakStok >= x.Siparis THEN N'Tedarikçide var'
            ELSE N'Yeni alım gerekiyor' END    AS [Sipariş nereden karşılanır],
       t.OdakStok                             AS [Tedarikçide bulunan],
       -- ── BAĞLAM ──────────────────────────────────────────────────────────
       s.DisT                                 AS [Geçen yıl sezon dışı satılan],
       CONVERT(int, ISNULL(yl.Adet, 0))       AS [Geçen yıl toplam satılan],
       x.Fazla                                AS [Gelecek sezona kalacak],
       -- ── PARA ────────────────────────────────────────────────────────────
       -- ⚠ 4 HANE: 2 haneye yuvarlayıp çarpınca toplam sapıyordu (ölçüldü).
       CONVERT(decimal(18,4), t.SatisFiyat)   AS [Satış fiyatı],
       CONVERT(decimal(18,4), CASE WHEN t.BirimMaliyet > 0
                                    AND t.BirimMaliyet <= t.SatisFiyat
            THEN t.BirimMaliyet END)          AS [Birim maliyet],
       -- SİPARİŞ'te satış fiyatıyla (kaçacak CİRO), FAZLA/ÖLÜ'de maliyetle
       -- (bağlı sermaye). İKİSİ TOPLANMAZ.
       CONVERT(decimal(18,2), CASE
            WHEN x.Siparis > 0 THEN x.Siparis * t.SatisFiyat
            WHEN g.Sinif IN (2,5) AND t.BirimMaliyet > 0
                 AND t.BirimMaliyet <= t.SatisFiyat
            THEN CASE WHEN g.Sinif = 5 THEN t.MagazaStok + t.MerkezStok
                      ELSE x.Fazla END * t.BirimMaliyet END) AS [Tutar]
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID   -- stkKod için
LEFT JOIN gp  ON gp.stkID  = t.stkID
LEFT JOIN gps ON gps.stkID = t.stkID
LEFT JOIN bps ON bps.stkID = t.stkID
LEFT JOIN bt  ON bt.stkID  = t.stkID
LEFT JOIN sn  ON sn.stkID  = t.stkID
LEFT JOIN kb  ON kb.Kat    = t.Kat2
LEFT JOIN kb3 ON kb3.Kat   = t.Kategori3
LEFT JOIN gd  ON gd.stkID  = t.stkID
LEFT JOIN yl  ON yl.stkID  = t.stkID
-- Yedek oran: önce Kat2, yoksa Kategori3, o da yoksa 0,60.
CROSS APPLY (SELECT Kat = ISNULL(
        CASE WHEN ISNULL(kb.Sezon,0) > 0
              AND CONVERT(float, kb.Pencere) / kb.Sezon BETWEEN 0.05 AND 1.0
             THEN CONVERT(float, kb.Pencere) / kb.Sezon END,
        CASE WHEN ISNULL(kb3.Sezon,0) > 0
             THEN CONVERT(float, kb3.Pencere) / kb3.Sezon END)) k0
-- ⚠ 4 HANEYE YUVARLANIP ÖYLE ÇARPILIR: bu oran Excel'e decimal(6,4) olarak
-- yazılıyor ve orada 4 haneyle çarpılıyor. SQL tam hassasiyetle çarparsa iki
-- emitter ayrışır — ÖLÇÜLDÜ 16.09.2026: Defterler'de "depodan gönder" adedi
-- SQL'de 22.445, Excel'de 22.442 çıkıyordu. GÖSTERİLEN oran = ÇARPILAN oran.
CROSS APPLY (SELECT Kat = CONVERT(float, CONVERT(decimal(6,4),
        ISNULL(CASE WHEN k0.Kat BETWEEN 0.05 AND 1.0 THEN k0.Kat END, 0.60)))) kk
-- ⚠ TABAN EŞİĞİ 30 ADET: 1 adetten 3'e çıkan şube "oranım 0,33" demesin.
-- ⚠ ALT SINIR 0,05: payda sıfıra yaklaşırsa bölme tahmini sonsuza götürür.
-- ⚠ ÜST SINIR 1,00: oran 1'i geçemez (iade fazlası negatif kalan üretirdi).
CROSS APPLY (SELECT
        OrF = CASE WHEN t.SezonFsm >= 30 AND ISNULL(gps.Fsm,0) >= 30
                    AND CONVERT(float, gps.Fsm) / t.SezonFsm BETWEEN 0.05 AND 1.0
                   THEN CONVERT(float, gps.Fsm) / t.SezonFsm ELSE kk.Kat END,
        OrO = CASE WHEN t.SezonOzl >= 30 AND ISNULL(gps.Ozl,0) >= 30
                    AND CONVERT(float, gps.Ozl) / t.SezonOzl BETWEEN 0.05 AND 1.0
                   THEN CONVERT(float, gps.Ozl) / t.SezonOzl ELSE kk.Kat END,
        OrI = CASE WHEN t.SezonIst >= 30 AND ISNULL(gps.Ist,0) >= 30
                    AND CONVERT(float, gps.Ist) / t.SezonIst BETWEEN 0.05 AND 1.0
                   THEN CONVERT(float, gps.Ist) / t.SezonIst ELSE kk.Kat END) po
CROSS APPLY (SELECT
        TahF = CONVERT(int, CEILING(ISNULL(bps.Fsm,0) / po.OrF)),
        TahO = CONVERT(int, CEILING(ISNULL(bps.Ozl,0) / po.OrO)),
        TahI = CONVERT(int, CEILING(ISNULL(bps.Ist,0) / po.OrI))) th
-- KALAN = tahmin − şu ana kadar satılan. Eksi olamaz: tahmin aşılmışsa
-- "eksi ihtiyaç" değil, ihtiyaç YOK demektir.
CROSS APPLY (SELECT
        KalF = CASE WHEN th.TahF > ISNULL(bt.Fsm,0)
                    THEN th.TahF - CONVERT(int, ISNULL(bt.Fsm,0)) ELSE 0 END,
        KalO = CASE WHEN th.TahO > ISNULL(bt.Ozl,0)
                    THEN th.TahO - CONVERT(int, ISNULL(bt.Ozl,0)) ELSE 0 END,
        KalI = CASE WHEN th.TahI > ISNULL(bt.Ist,0)
                    THEN th.TahI - CONVERT(int, ISNULL(bt.Ist,0)) ELSE 0 END) kl
CROSS APPLY (SELECT
        Eksik = CASE WHEN kl.KalF > t.StokFsm THEN kl.KalF - t.StokFsm ELSE 0 END
              + CASE WHEN kl.KalO > t.StokOzl THEN kl.KalO - t.StokOzl ELSE 0 END
              + CASE WHEN kl.KalI > t.StokIst THEN kl.KalI - t.StokIst ELSE 0 END,
        Kalan = kl.KalF + kl.KalO + kl.KalI,
        DisT  = CONVERT(int, CASE WHEN ISNULL(gd.Adet,0) > 0 THEN gd.Adet ELSE 0 END)) s
-- SİPARİŞ = şubelerin toplam eksiği − merkez depo. Önce depodan gönderilir,
-- ancak yetmeyen kısmı sipariş edilir. GMY: "mağazalar arası değil, depoda
-- veya ODAK'ta varsa mümkün; diğer türlü hayal."
CROSS APPLY (SELECT
        Siparis = CASE WHEN s.Eksik > t.MerkezStok THEN s.Eksik - t.MerkezStok ELSE 0 END,
        Fazla   = t.MagazaStok + t.MerkezStok - s.Kalan - s.DisT) x
CROSS APPLY (SELECT Sinif = CASE
        WHEN t.SezonToplam <= 0 AND ISNULL(bt.Adet,0) <= 0
             AND t.MagazaStok + t.MerkezStok > 0 THEN 5   -- ÖLÜ STOK
        WHEN x.Siparis > 0 THEN 1                         -- SİPARİŞ VER
        WHEN s.Eksik   > 0 THEN 4                         -- DEPODAN GÖNDER
        WHEN x.Fazla   > 0 THEN 2                         -- FAZLA VAR
        ELSE 0 END) g
WHERE t.Kesim = @kesim AND t.SezonYil = @sezonYil
  -- KAPSAM: "geçen sezon fiilen satmış" şartı KALDIRILDI — bu sezon satan ama
  -- geçen sezon tabanı olmayan ürünleri dışarıda bırakıyordu. ÖLÇÜLDÜ
  -- (Defterler): 681'i 2026'da açılmış yeni ürün, 380'i eski ama geçen sezon
  -- satmamış; ikisi birlikte bu sezon 11.852 adet satmış.
  AND (t.SezonToplam > 0 OR ISNULL(bt.Adet,0) > 0
       OR t.MagazaStok + t.MerkezStok > 0)
  -- DEFTER GÜVENİLİR: negatif stok fiziksel durum değil, defter hatasıdır.
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
  AND (@kategori IS NULL OR t.Kategori3 = @kategori)
  AND (@grup     IS NULL OR t.Kat1      = @grup)
  AND (@durum    IS NULL
       OR (@durum = 'siparis' AND g.Sinif = 1)
       OR (@durum = 'depodan' AND g.Sinif = 4)
       OR (@durum = 'fazla'   AND g.Sinif = 2)
       OR (@durum = 'olu'     AND g.Sinif = 5))
-- SIRALAMA PARAYA GÖRE: sipariş satırında kaçacak ciro, ötekinde bağlı sermaye.
ORDER BY CASE WHEN g.Sinif = 1 THEN x.Siparis * t.SatisFiyat
              WHEN g.Sinif = 2 THEN x.Fazla   * ISNULL(t.BirimMaliyet, 0)
              WHEN g.Sinif = 5 THEN (t.MagazaStok + t.MerkezStok)
                                    * ISNULL(t.BirimMaliyet, 0)
              ELSE 0 END DESC,
         ISNULL(bt.Adet, 0) DESC, t.stkID;


/* ═══ KONTROL — Excel scriptinin konsol özetiyle BİREBİR tutmalı ═══════════════
   Yukarıdaki DECLARE bloğu bu sorgu için de geçerlidir (aynı oturumda çalıştır).
   Çalıştırmak için üstteki sorgunun tamamını buraya kopyalamak yerine, aynı
   oturumda #h'ye almak gerekir; pratikte Excel scripti bu özeti zaten basar:

     python scripts/sezon_aksiyon_listesi_excel.py --kesim 2026-09-13 \
            --sezon 2025 --grup "Defterler"

   ÖLÇÜLDÜ 16.09.2026 (Defterler, 7.784 çeşit):
     SİPARİŞ VER      703 ürün ·    13.221 adet ·  2.077.342 ₺ (satış fiyatı)
     DEPODAN GÖNDER   511 ürün ·    22.442 adet
     FAZLA VAR      2.141 ürün ·   270.308 adet · 10.805.472 ₺ (maliyet)
     ÖLÜ STOK       3.599 ürün ·    44.515 adet ·  2.643.632 ₺ (maliyet)
     YETERLİ          830 ürün
   Maliyeti yok/şüpheli 2.200 çeşit → fazla ve ölü tutarı ALT SINIRDIR.
   ═══════════════════════════════════════════════════════════════════════════ */
