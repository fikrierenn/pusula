/* ═══════════════════════════════════════════════════════════════════════════════
   SEZON AKSİYON LİSTESİ — SSMS'te çalışan tam sorgu
   GMY 15.09.2026: "bana sql sorgusunu da verir misin"

   Bu sorgu, panelin (/sezon-aksiyon) ve Excel scriptinin
   (scripts/sezon_aksiyon_listesi_excel.py) AYNI iş mantığıdır.

   HESAP
     Satılacak = CEILING(geçen sezon TAMAMI × (1 + büyüme))
     Elde      = FSM + Özlüce + İst.Yolu + Depo(merkez)
     AÇIK      = Satılacak − Elde   (pozitifse)  → sipariş / transfer
     FAZLA     = Elde − Satılacak   (pozitifse)  → indirim / iade / transfer
     Tutar     = AÇIK'ta satış fiyatıyla (kaçacak ciro), FAZLA'da maliyetle (bağlı sermaye)

   ⚠ AYNI PENCERE: geçen ve bu sezonun satışı, OKUL AÇILIŞINDAN GERİYE aynı gün sayısı
     kadar ölçülür. Takvim günüyle hizalamak YANILTIR — açılış 08.09.2025 → 14.09.2026,
     altı gün kaydı. Ölçüldü: Hazırlık Kitapları büyümesi takvimle 0,727 ("%27 küçüldü"),
     okula hizalı 1,104 ("%10 büyüdü") — ZIT sonuç.

   ⚠ Eski "365 günde satılan" kolonu KALDIRILDI: penceresi [kesim−364, kesim] idi ve
     geçen sezonun 1 Ağu–13 Eyl kısmını (365 günden eski) KAÇIRIYORDU; sezon kolonuyla
     iç içe geçmediği için okuyanı yanıltıyordu.

   SINIRLAR (rakamı kullanmadan önce oku)
     · Açık sipariş DÜŞÜLMEZ. ERP'de "kapalı" durumu (sip.eDurum=2) 24.02.2025'ten beri
       hiç yazılmıyor; kapatılmamış alış siparişi adedinin %86,4'ü bir yıldan eski.
     · FAZLA tutarı ALT SINIR — maliyeti yok/şüpheli (TMS 2: 0 < maliyet ≤ satış fiyatı)
       satırlar adet olarak sayılır, paraya girmez.
     · Depo stoğu WMS kaynaklı; ERP defteriyle çelişebilir (hayalet stok).
     · Tek gün fotoğrafı. Alıcı (satınalmacı) boyutu veride YOK — kişiye atıf değildir.
     · "Bu sezon aynı dönem = 0" olan satırlarda eksik olan STOK DEĞİL TALEP olabilir:
       ölçüldü, AÇIK listesinin 10.865 ürününde mal RAFTA duruyor ve 44 günde hiç
       satmamış (40,4M ₺). Bkz. sorgular/2026-09-15-ayni-pencere-ve-yanlis-alarm.sql
   ═══════════════════════════════════════════════════════════════════════════════ */

DECLARE @kesim        date  = '2026-09-13',   -- taban kesimi (bkm.SatisAnaliziTaban)
        @sezonYil     int   = 2025,           -- geçen sezon yılı
        @buyume       float = 0.20,           -- %20 büyüme varsayımı
        @acilisBu     date  = '2026-09-14',   -- bu yılki okul açılışı
        @acilisGecen  date  = '2025-09-08',   -- geçen yılki okul açılışı
        @hizaliGun    int   = 44,             -- açılıştan geriye kaç gün (İKİ YIL İÇİN DE AYNI)
        @durum        varchar(10) = NULL;     -- NULL=hepsi · 'acik' · 'fazla'

WITH gh AS (   -- GEÇEN yılın penceresi
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)               -- FSM · Özlüce · İst.Yolu
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)          -- satış(1,4,100) − iade(3,5,101)
      AND h.ehTrhS >= DATEADD(DAY, -@hizaliGun, @acilisGecen)
      AND h.ehTrhS <  @acilisGecen
    GROUP BY h.ehstkID
),
bh AS (        -- BU yılın penceresi — gün sayısı gh ile BİREBİR aynı
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= DATEADD(DAY, -@hizaliGun, @acilisBu)
      AND h.ehTrhS <  @acilisBu
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

       CONVERT(int, ISNULL(gh.Adet, 0))                AS [Geçen sezon aynı dönem],
       CONVERT(int, ISNULL(bh.Adet, 0))                AS [Bu sezon aynı dönem],
       -- Geçen yıl 0 ise oran YOK (NULL) — "sonsuz büyüme" uydurulmaz.
       CONVERT(decimal(10,2), CASE WHEN ISNULL(gh.Adet, 0) > 0
            THEN CONVERT(float, ISNULL(bh.Adet, 0)) / gh.Adet END)      AS [Değişim],

       t.SezonToplam                                   AS [Geçen sezon TAMAMI],
       s.Satilacak                                     AS [Satılacak],

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
CROSS APPLY (SELECT Satilacak = CONVERT(int, CEILING(t.SezonToplam * (1.0 + @buyume))),
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
     AÇIK   31.187 ürün ·   810.638 adet · 254.733.925 ₺ (satış fiyatıyla)
     FAZLA  47.619 ürün · 2.700.360 adet ·  97.379.080 ₺ (maliyetle)
     DENGE   6.468 ürün
   Panel ve Excel emitter'ı bu sorguyla BİREBİR aynı sonucu veriyor.
   ───────────────────────────────────────────────────────────────────────────── */


-- ══ KONTROL: yukarıdaki listenin toplamı ════════════════════════════════════
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
CROSS APPLY (SELECT Satilacak = CONVERT(int, CEILING(t.SezonToplam * (1.0 + @buyume))),
                    Elde      = t.MagazaStok + t.MerkezStok) s
WHERE t.Kesim = @kesim AND t.SezonYil = @sezonYil AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0;
