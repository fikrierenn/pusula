/* ═══════════════════════════════════════════════════════════════════════════════
   SEZON SİPARİŞ LİSTESİ — SSMS'te çalışan tam sorgu (TABANDAN okur)
   GMY 17.09.2026: "bana hem veriyi verecek sql ver, kendim bir şeyler yapacağım"

   Panelin (/sezon-aksiyon) ve Excel scriptinin
   (scripts/sezon_aksiyon_listesi_excel.py --sade) AYNI iş mantığı.

   ── BU DOSYA İLE ESKİSİNİN FARKI ──────────────────────────────────────────────
   sorgular/2026-09-15-sezon-aksiyon-listesi.sql pencereleri CANLI hesaplıyor
   (sekiz CTE + on LEFT JOIN, tüm evrende 36,6 s — ölçüldü 16.09.2026).
   Bu dosya aynı girdileri bkm.SatisAnaliziTaban'a yazılmış hâliyle OKUR (5,1 s).
   Sonuç BİREBİR AYNI; ölçüldü 16.09.2026 (kesim 15.09, Defterler, 7.800 çeşit):
     SİPARİŞ VER 727 / 13.398 / 2.187.680 ₺ · DEPODAN GÖNDER 476 / 21.192 ·
     FAZLA VAR 2.148 / 268.311 / 10.657.567 ₺ · ÖLÜ STOK 3.607 / 46.577 /
     2.684.213 ₺ · YETERLİ 842.
   ⚠ Eski dosya SİLİNMEDİ: taban kolonları bir kesim için doldurulmamışsa
     (aşağıdaki kapı patlar) tek çalışan sürüm odur.

   ── YÖNTEM: SEZON PAYI ────────────────────────────────────────────────────────
     ORAN          = geçen sezon OKUL ÖNCESİ satılan ÷ geçen SEZON TOPLAMI
     TAHMİN        = bu sezon OKUL ÖNCESİ satılan ÷ ORAN
     KALAN İHTİYAÇ = TAHMİN − bu sezon BUGÜNE KADAR satılan
     SİPARİŞ       = şubelerin toplam eksiği − merkez depo stoğu

   ⚠ BÜYÜME PARAMETRESİ YOK. Hacmi ürünün bu sezonki kendi satışı taşır; oran
     yalnız "sezonun neresindeyiz" sorusunu yanıtlar.

   ⚠ ZİNCİR ŞUBE DÜZEYİNDE KURULUR; ürün satırı üç şubenin TOPLAMIDIR. Ürün
     düzeyinde (okul öncesi ÷ pay) diye YENİDEN KURULAMAZ — iki sonuç tutmaz.
     ÖLÇÜLDÜ (Kırtasiye, 20.218 çeşit): ayrı hesap varken şube eksikleri toplamı
     ile sipariş adedi 4.922 çeşitte uyuşmuyordu, fark 133.594 adet.

   ⚠ PENCERE OKUL AÇILIŞINA HİZALI, takvime değil (11.09.2023 · 09.09.2024 ·
     08.09.2025 · 14.09.2026). Takvim hizasıyla Kırtasiye sezon tahmini 521.262,
     açılış hizasıyla 643.912 — %23,5 fark. Pencereler EŞİT uzunlukta.
     Tanım C# tarafında: GmDashboard.Models.SezonAksiyonFiltre.OkulAcilis.

   ⚠ SANSÜR: geçen sezon stoğu bitmiş üründe gözlenen satış gerçek talebin
     ALTINDADIR; oran 1'e yaklaşır, talep EKSİK ölçülür. Bayrak kolonda GÖRÜNÜR
     (SansurluMu), düzeltme UYGULANMADI — kategori oranına düşürmek backtest'i
     %18,5 → %48,5 kötüleştiriyordu.

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
       tutar kaybedilen CİRODUR, kaybedilen KÂR DEĞİL (marj ölçülmedi).
     · Maliyeti yok/şüpheli (TMS 2: 0 < maliyet ≤ satış fiyatı) satır adet olarak
       sayılır, paraya girmez → fazla/ölü tutarı ALT SINIRDIR.
     · Depo stoğu WMS kaynaklı; ERP defteriyle çelişebilir (hayalet stok).
     · Alıcı (satınalmacı) boyutu veride YOK — GÖREV listesidir, kişiye atıf değil.
   ═══════════════════════════════════════════════════════════════════════════════ */

USE DerinSISBkm;
GO

DECLARE @kesim    date          = '2026-09-15',  -- taban kesimi
        @sezonYil smallint      = 2025,          -- geçen sezon yılı
        @kategori nvarchar(100) = NULL,          -- Kategori3, ör. N'Kırtasiye'
        @grup     nvarchar(100) = N'Defterler',  -- Kat1 (ürün grubu), NULL = hepsi
        @durum    varchar(10)   = NULL;          -- siparis · depodan · fazla · olu

/* ── KAPI: sezon payı girdileri o kesim için yazılmış mı ────────────────────
   ⚠ Yazılmamışsa kolonlar NULL gelir. ISNULL(...,0) ile devam etmek her ürünü
     "talebi yok" gösterir ve liste sessizce "sipariş yok" der — hata vermeden.
     Bu yüzden sorgu KOŞMAZ. Doldurma: panelde Satış Analizi → "Tabanı yenile". */
IF NOT EXISTS (SELECT 1 FROM bkm.SatisAnaliziTaban
               WHERE Kesim = @kesim AND SezonYil = @sezonYil)
BEGIN
    RAISERROR('KOSAMADI: bu kesim/sezon icin taban satiri YOK.', 16, 1);
    RETURN;
END;

DECLARE @eksik int = (SELECT COUNT(*) FROM bkm.SatisAnaliziTaban
                      WHERE Kesim = @kesim AND SezonYil = @sezonYil
                        AND OncesiGecenFsm IS NULL);
IF @eksik > 0
BEGIN
    RAISERROR('KOSAMADI: %d urunde sezon payi girdileri yazilmamis. Taban bu kolonlar eklenmeden doldurulmus; once "Tabani yenile".', 16, 1, @eksik);
    RETURN;
END;

SELECT
    /* ═══ KARAR — alıcının yapacağı iş ═══════════════════════════════════════ */
    [Ürün]                = t.stkAd,
    [Ürün grubu]          = ISNULL(t.Kat1, N''),
    [Alt kategori]        = ISNULL(t.Kat2, N''),
    [Marka]               = t.Yayinevi,
    [Stok kodu]           = u.stkKod,           -- ⚠ BARKOD DEĞİL
    [Barkod]              = t.BarkodAna,
    [NE YAPMALI]          = CASE g.Sinif WHEN 1 THEN N'SİPARİŞ VER'
                                         WHEN 4 THEN N'DEPODAN GÖNDER'
                                         WHEN 2 THEN N'FAZLA VAR'
                                         WHEN 5 THEN N'ÖLÜ STOK'
                                         ELSE N'YETERLİ' END,
    -- Eyleme konu miktar: siparişte alınacak · depodan gönderilecek ·
    -- fazla/ölüde eritilecek. TUTARI de AYNI miktarın parasıdır.
    [KAÇ ADET]            = e.Adet,
    -- ⚠ İKİ TABAN: siparişte SATIŞ FİYATI (kaçacak ciro), fazla/ölüde MALİYET
    --   (bağlı sermaye). TOPLANMAZ. Maliyeti yoksa NULL kalır (0 yazmak
    --   "bedava" demek olurdu) → fazla/ölü toplamı ALT SINIRDIR.
    [TUTARI]              = CONVERT(decimal(18,2),
        CASE WHEN g.Sinif = 1 THEN e.Adet * t.SatisFiyat
             WHEN g.Sinif IN (2,5) AND t.BirimMaliyet > 0
                  AND t.BirimMaliyet <= t.SatisFiyat THEN e.Adet * t.BirimMaliyet END),
    [NEREDEN GELİR]       = CASE WHEN g.Sinif <> 1 THEN N''
                                 WHEN t.OdakStok >= e.Adet THEN N'Tedarikçide hazır var'
                                 ELSE N'Tedarikçiye sipariş açılacak' END,

    /* ═══ İSPAT — kararın her adımı, cümledeki sırayla ═══════════════════════ */
    [Geçen sezon kaç adet sattı]                = t.SezonToplam,
    [Bunun kaçı okul açılmadan önce satıldı]    = h.GecTop,
    [Okul açılmadan önce satılan pay]           = CONVERT(decimal(6,3),
        CASE WHEN t.SezonToplam > 0
             THEN CONVERT(float, h.GecTop) / t.SezonToplam END),
    -- Şubenin kendi ölçümü zayıfsa (geçen sezon < 30 adet) bu oran kullanılır:
    -- önce Kat2 (alt kategori), yoksa Kategori3, o da yoksa 0,60.
    [Yedek oran (alt kategori ortalaması)]      = kk.Kat,
    [Oranın alındığı kırılım]                   = ISNULL(t.Kat2, t.Kategori3),
    -- ⚠ Geçen sezon stoğu bitmişse gözlenen satış TALEP DEĞİL, rafın bittiği yer.
    [Geçen sezon stoğu bitti mi]                = CASE WHEN t.SansurluMu = 1
                                                       THEN N'EVET' ELSE N'HAYIR' END,
    [Bu sezon okul açılmadan önce kaç sattı]    = h.BuTop,
    [Bu sezon toplam kaç satacak]               = th.TahF + th.TahO + th.TahI,
    [Bu sezon bugüne kadar kaç sattı]           = h.BugTop,
    [Sezonun kalanında kaç satacak]             = s.Kalan,

    /* ── ŞUBE ZİNCİRİ — "toplam nereden geldi" sorusunun tek yeri ─────────── */
    [FSM: kullanılan oran]          = CONVERT(decimal(6,4), po.OrF),
    [FSM: toplam satacak]           = th.TahF,
    [FSM: kalanında satacak]        = kl.KalF,
    [FSM: stok]                     = t.StokFsm,
    [FSM: eksik]                    = CASE WHEN kl.KalF > t.StokFsm
                                           THEN kl.KalF - t.StokFsm ELSE 0 END,
    [Özlüce: kullanılan oran]       = CONVERT(decimal(6,4), po.OrO),
    [Özlüce: toplam satacak]        = th.TahO,
    [Özlüce: kalanında satacak]     = kl.KalO,
    [Özlüce: stok]                  = t.StokOzl,
    [Özlüce: eksik]                 = CASE WHEN kl.KalO > t.StokOzl
                                           THEN kl.KalO - t.StokOzl ELSE 0 END,
    [İst.Yolu: kullanılan oran]     = CONVERT(decimal(6,4), po.OrI),
    [İst.Yolu: toplam satacak]      = th.TahI,
    [İst.Yolu: kalanında satacak]   = kl.KalI,
    [İst.Yolu: stok]                = t.StokIst,
    [İst.Yolu: eksik]               = CASE WHEN kl.KalI > t.StokIst
                                           THEN kl.KalI - t.StokIst ELSE 0 END,

    [Üç şubede toplam eksik]        = s.Eksik,
    [Mağazalardaki stok]            = t.MagazaStok,
    [Merkez depodaki stok]          = t.MerkezStok,
    [Mağaza ve depo toplam]         = t.MagazaStok + t.MerkezStok,
    [Sipariş edilecek adet]         = x.Siparis,
    [Tedarikçide bulunan]           = t.OdakStok,   -- ⚠ BİZİM stoğumuz DEĞİL
    [Gelecek sezona kalacak]        = x.Fazla,
    -- ⚠ "gelecek sezona kalır" TEK BAŞINA YANILTIR: 5.150 adedi olup bu sezon
    --   6 adet satacak ürün "gelecek sezon" değil, 858 sezon boyunca satar.
    [Stok kaç sezonluk]             = CONVERT(decimal(10,1),
        CASE WHEN th.TahF + th.TahO + th.TahI > 0
             THEN CONVERT(float, t.MagazaStok + t.MerkezStok)
                  / (th.TahF + th.TahO + th.TahI) END),

    /* ── BAĞLAM ──────────────────────────────────────────────────────────── */
    [Geçen yıl sezon dışında satılan] = s.DisT,      -- sipariş TETİKLEMEZ
    [Geçen yıl toplam satılan]        = ISNULL(t.YillikAdet, 0),
    -- Ürünün sezon payı düşükse ürün sezonluk DEĞİLDİR, yöntem orada zayıftır.
    [Ürünün sezon payı]               = CONVERT(decimal(6,3),
        CASE WHEN ISNULL(t.YillikAdet,0) > 0
             THEN CONVERT(float, t.SezonToplam) / t.YillikAdet END),
    [Satış fiyatı]                    = CONVERT(decimal(18,4), t.SatisFiyat),
    [Birim maliyet]                   = CONVERT(decimal(18,4),
        CASE WHEN t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat
             THEN t.BirimMaliyet END),

    /* ═══ NEDEN — hesabın tamamı tek cümlede ═════════════════════════════════
       ⚠ FORMAT() KULLANILMADI: CLR tabanlı ve 266K satırda yavaş. Binlik ayırıcı
         money numarasıyla veriliyor (style 1 → '1,953.00'), sonra Türkçe yazıma
         çevriliyor. Aynı hüner n() içinde. */
    [NEDEN] =
        CASE WHEN t.SezonToplam <= 0 AND h.BugTop <= 0
                  AND t.MagazaStok + t.MerkezStok > 0
        THEN N'İki sezondur satmadı: geçen sezon ' + n.Gs + N', bu sezon ' + n.Bug
           + N' adet. Buna rağmen mağazalarda ' + n.Mag + N', merkez depoda '
           + n.Depo + N' adet duruyor (toplam ' + n.Elde
           + N' adet). Bu bir sipariş konusu değil; eritme ya da iade konusudur.'
        ELSE
            CASE WHEN t.SezonToplam > 0
                 THEN N'Geçen sezon ' + n.Gs + N' adet sattı; bunun ' + n.Gec
                    + N' adedi (%' + n.Pay + N') okul açılmadan önceydi. '
                 ELSE N'Geçen sezon hiç satmadı; bu yüzden oran ürünün kendisinden '
                    + N'değil, alt kategori ortalamasından alındı. ' END
          + N'Bu sezon okul açılmadan önce ' + n.Bu + N' sattı; aynı oranla sezonun '
          + N'tamamında ' + n.Tah + N' satar (hesap üç şube için AYRI yapıldı, bu '
          + N'rakam onların toplamıdır). Bugüne kadar ' + n.Bug + N' sattı, demek '
          + N'sezonun kalanında ' + n.Kal + N' satacak. Mağazalarda ' + n.Mag
          + N' adet var, ' + n.Eksik + N' adet eksik. Merkez depoda ' + n.Depo
          + N' adet var → '
          + CASE WHEN g.Sinif = 1 THEN n.Sip + N' adet SİPARİŞ EDİLECEK.'
                 WHEN g.Sinif = 4 THEN N'eksik depodan karşılanır, sipariş gerekmez.'
                 WHEN g.Sinif = 2 THEN N'sipariş gerekmiyor; elde ' + n.Elde
                      + N' adet var, bu sezon ' + n.Tah + N' satacak → yaklaşık '
                      + n.Sezonluk + N' sezonluk stok. Bu bir eritme/iade konusudur.'
                 ELSE N'stok yeterli.' END
        END

FROM bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID      -- yalnız stkKod için

/* ── Ham girdiler tek yerde adlandırılır ───────────────────────────────────── */
CROSS APPLY (SELECT GecF = ISNULL(t.OncesiGecenFsm,0), GecO = ISNULL(t.OncesiGecenOzl,0),
                    GecI = ISNULL(t.OncesiGecenIst,0),
                    BuF  = ISNULL(t.OncesiBuFsm,0),     BuO = ISNULL(t.OncesiBuOzl,0),
                    BuI  = ISNULL(t.OncesiBuIst,0),
                    BugF = ISNULL(t.BuguneFsm,0),       BugO = ISNULL(t.BuguneOzl,0),
                    BugI = ISNULL(t.BuguneIst,0)) h0
CROSS APPLY (SELECT GecF = h0.GecF, GecO = h0.GecO, GecI = h0.GecI,
                    BuF = h0.BuF, BuO = h0.BuO, BuI = h0.BuI,
                    BugF = h0.BugF, BugO = h0.BugO, BugI = h0.BugI,
                    GecTop = h0.GecF + h0.GecO + h0.GecI,
                    BuTop  = h0.BuF  + h0.BuO  + h0.BuI,
                    BugTop = h0.BugF + h0.BugO + h0.BugI) h
/* ⚠ decimal(6,4) olarak SAKLANIR ve bu hâliyle çarpılır: GÖSTERİLEN oran =
     ÇARPILAN oran. Tam hassasiyetle çarpılırsa Excel emitter'ıyla ayrışır —
     ÖLÇÜLDÜ: "depodan gönder" adedi 22.445 ↔ 22.442. */
CROSS APPLY (SELECT Kat = CONVERT(float, ISNULL(t.YedekOran, 0.60))) kk
/* ⚠ TABAN EŞİĞİ 30 ADET: 1 adetten 3'e çıkan şube "oranım 0,33" demesin.
   ⚠ ALT SINIR 0,05: payda sıfıra yaklaşırsa bölme tahmini sonsuza götürür.
   ⚠ ÜST SINIR 1,00: oran 1'i geçemez (iade fazlası negatif kalan üretirdi). */
CROSS APPLY (SELECT
    OrF = CASE WHEN t.SezonFsm >= 30 AND h.GecF >= 30
                AND CONVERT(float, h.GecF) / t.SezonFsm BETWEEN 0.05 AND 1.0
               THEN CONVERT(float, h.GecF) / t.SezonFsm ELSE kk.Kat END,
    OrO = CASE WHEN t.SezonOzl >= 30 AND h.GecO >= 30
                AND CONVERT(float, h.GecO) / t.SezonOzl BETWEEN 0.05 AND 1.0
               THEN CONVERT(float, h.GecO) / t.SezonOzl ELSE kk.Kat END,
    OrI = CASE WHEN t.SezonIst >= 30 AND h.GecI >= 30
                AND CONVERT(float, h.GecI) / t.SezonIst BETWEEN 0.05 AND 1.0
               THEN CONVERT(float, h.GecI) / t.SezonIst ELSE kk.Kat END) po
CROSS APPLY (SELECT TahF = CONVERT(int, CEILING(h.BuF / po.OrF)),
                    TahO = CONVERT(int, CEILING(h.BuO / po.OrO)),
                    TahI = CONVERT(int, CEILING(h.BuI / po.OrI))) th
/* KALAN = tahmin − şu ana kadar satılan. Eksi olamaz: tahmin aşılmışsa
   "eksi ihtiyaç" değil, ihtiyaç YOK demektir. */
CROSS APPLY (SELECT KalF = CASE WHEN th.TahF > h.BugF THEN th.TahF - h.BugF ELSE 0 END,
                    KalO = CASE WHEN th.TahO > h.BugO THEN th.TahO - h.BugO ELSE 0 END,
                    KalI = CASE WHEN th.TahI > h.BugI THEN th.TahI - h.BugI ELSE 0 END) kl
CROSS APPLY (SELECT
    Eksik = CASE WHEN kl.KalF > t.StokFsm THEN kl.KalF - t.StokFsm ELSE 0 END
          + CASE WHEN kl.KalO > t.StokOzl THEN kl.KalO - t.StokOzl ELSE 0 END
          + CASE WHEN kl.KalI > t.StokIst THEN kl.KalI - t.StokIst ELSE 0 END,
    Kalan = kl.KalF + kl.KalO + kl.KalI,
    DisT  = ISNULL(t.SezonDisiAdet, 0)) s
/* SİPARİŞ = şubelerin toplam eksiği − merkez depo. Mağazalar arası aktarma
   VARSAYILMAZ. GMY: "mağazalar arası değil; depoda veya ODAK'ta varsa mümkün,
   diğer türlü hayal." */
CROSS APPLY (SELECT
    Siparis = CASE WHEN s.Eksik > t.MerkezStok THEN s.Eksik - t.MerkezStok ELSE 0 END,
    Fazla   = t.MagazaStok + t.MerkezStok - s.Kalan - s.DisT) x
CROSS APPLY (SELECT Sinif = CASE
    WHEN t.SezonToplam <= 0 AND h.BugTop <= 0
         AND t.MagazaStok + t.MerkezStok > 0 THEN 5    -- ÖLÜ STOK
    WHEN x.Siparis > 0 THEN 1                          -- SİPARİŞ VER
    WHEN s.Eksik   > 0 THEN 4                          -- DEPODAN GÖNDER
    WHEN x.Fazla   > 0 THEN 2                          -- FAZLA VAR
    ELSE 0 END) g
/* Eyleme konu miktar — her durumda o durumun miktarı.
   ⚠ Yalnız sipariş adedi gösterilirse fazla/ölü satırında 0 yazar ama yanındaki
     TUTARI dolu olur ve satır ÇELİŞKİLİ okunur (GMY 17.09.2026 bunu yakaladı). */
CROSS APPLY (SELECT Adet = CASE g.Sinif WHEN 1 THEN x.Siparis
                                        WHEN 4 THEN s.Eksik
                                        WHEN 2 THEN x.Fazla
                                        WHEN 5 THEN t.MagazaStok + t.MerkezStok
                                        ELSE 0 END) e
/* Cümlede kullanılan sayıların Türkçe yazımı (1.953 · %31). */
CROSS APPLY (SELECT
    Gs   = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, t.SezonToplam), 1), '.00',''), ',', '.'),
    Gec  = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, h.GecTop), 1), '.00',''), ',', '.'),
    Bu   = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, h.BuTop), 1), '.00',''), ',', '.'),
    Bug  = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, h.BugTop), 1), '.00',''), ',', '.'),
    Tah  = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, th.TahF+th.TahO+th.TahI), 1), '.00',''), ',', '.'),
    Kal  = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, s.Kalan), 1), '.00',''), ',', '.'),
    Mag  = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, t.MagazaStok), 1), '.00',''), ',', '.'),
    Depo = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, t.MerkezStok), 1), '.00',''), ',', '.'),
    Elde = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, t.MagazaStok+t.MerkezStok), 1), '.00',''), ',', '.'),
    Eksik= REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, s.Eksik), 1), '.00',''), ',', '.'),
    Sip  = REPLACE(REPLACE(CONVERT(varchar(30), CONVERT(money, x.Siparis), 1), '.00',''), ',', '.'),
    Pay  = CONVERT(varchar(10), CASE WHEN t.SezonToplam > 0
                THEN CONVERT(int, ROUND(100.0 * h.GecTop / t.SezonToplam, 0)) ELSE 0 END),
    Sezonluk = CONVERT(varchar(20), CASE WHEN th.TahF+th.TahO+th.TahI > 0
                THEN CONVERT(int, ROUND(1.0 * (t.MagazaStok + t.MerkezStok)
                     / (th.TahF+th.TahO+th.TahI), 0)) ELSE 0 END)) n

WHERE t.Kesim = @kesim AND t.SezonYil = @sezonYil
  /* KAPSAM: "geçen sezon fiilen satmış" şartı YOK — bu sezon satan ama geçen
     sezon tabanı olmayan ürünleri dışarıda bırakıyordu. ÖLÇÜLDÜ (Defterler):
     681'i 2026'da açılmış yeni ürün, 380'i eski ama geçen sezon satmamış;
     ikisi birlikte bu sezon 11.852 adet satmış. */
  AND (t.SezonToplam > 0 OR h.BugTop > 0 OR t.MagazaStok + t.MerkezStok > 0)
  /* DEFTER GÜVENİLİR: negatif stok fiziksel durum değil, defter hatasıdır. */
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
  AND (@kategori IS NULL OR t.Kategori3 = @kategori)
  AND (@grup     IS NULL OR t.Kat1      = @grup)
  AND (@durum    IS NULL
       OR (@durum = 'siparis' AND g.Sinif = 1)
       OR (@durum = 'depodan' AND g.Sinif = 4)
       OR (@durum = 'fazla'   AND g.Sinif = 2)
       OR (@durum = 'olu'     AND g.Sinif = 5))
/* SIRALAMA PARAYA GÖRE: sipariş satırında kaçacak ciro, ötekinde bağlı sermaye. */
ORDER BY CASE WHEN g.Sinif = 1 THEN x.Siparis * t.SatisFiyat
              WHEN g.Sinif IN (2,5) THEN e.Adet * ISNULL(t.BirimMaliyet, 0)
              ELSE 0 END DESC,
         h.BugTop DESC, t.stkID;
GO


/* ═══ ÖZET — yukarıdakinin aynısı, tek satırda ═══════════════════════════════
   Aynı DECLARE bloğuyla çalıştır (üstteki sorguyla aynı oturumda).
   ÖLÇÜLDÜ 16.09.2026 (kesim 15.09.2026, sezon 2025, grup Defterler):
     SİPARİŞ VER 727 · 13.398 adet · 2.187.680 ₺
     DEPODAN GÖNDER 476 · 21.192 adet
     FAZLA VAR 2.148 · 268.311 adet · 10.657.567 ₺
     ÖLÜ STOK 3.607 · 46.577 adet · 2.684.213 ₺
     YETERLİ 842 · maliyeti yok/şüpheli 2.205 çeşit
   ═════════════════════════════════════════════════════════════════════════════

SELECT [Durum]  = CASE g.Sinif WHEN 1 THEN N'SİPARİŞ VER' WHEN 4 THEN N'DEPODAN GÖNDER'
                               WHEN 2 THEN N'FAZLA VAR'   WHEN 5 THEN N'ÖLÜ STOK'
                               ELSE N'YETERLİ' END,
       [Çeşit]  = COUNT(*),
       [Adet]   = SUM(e.Adet),
       [Tutar]  = SUM(CASE WHEN g.Sinif = 1 THEN e.Adet * t.SatisFiyat
                           WHEN g.Sinif IN (2,5) AND t.BirimMaliyet > 0
                                AND t.BirimMaliyet <= t.SatisFiyat
                           THEN e.Adet * t.BirimMaliyet END),
       [Maliyeti yok] = SUM(CASE WHEN g.Sinif IN (2,5)
                                  AND NOT (t.BirimMaliyet > 0
                                           AND t.BirimMaliyet <= t.SatisFiyat)
                                 THEN 1 ELSE 0 END)
FROM ... (yukarıdaki FROM/APPLY/WHERE bloğunun aynısı) ...
GROUP BY g.Sinif;
*/
