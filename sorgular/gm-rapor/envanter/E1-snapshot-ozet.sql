-- =====================================================================
-- 08.01 — ENVANTER SNAPSHOT ÖZET (mağaza + depo, gece job çıktısından)
-- Amaç: GM tek bakış — toplam envanter değeri, mağaza/depo kırılımı,
--        İki maliyet bazı (ÜstFiyat vs Ort.Maliyet) + hayalet negatif bayrağı.
-- Kaynak: DerinSISBkm.bkm.ENVANTER_RAPORU (gece 00:05 MaliyetRaporu-Ceren job doldurur)
-- NOT: Canlı stok hesabı DEĞİL — gece snapshot'ı. Anlık için envanter_raporu_job_sorgusu.sql.
-- ANOMALİ / FİLTRE: Sınav Okulları (urnKtgr2ID=19, süreli yayın paketleri) ENVANTER DIŞI.
--   Paket koduyla giriş + parça koduyla çıkış → İst.Yolu'nda her iki bazı bozuyordu:
--   ÜstFiyat -190M sahte negatif, Ort.Maliyet +149M sahte pozitif. Retail envanteri değil,
--   Sınav Okulu operasyonu. Detay: sorgular/tum_stoklar_anomali_taramasi.md
-- DOĞRULAMA (08.06.2026, Sınav Okulları HARİÇ):
--   Ort.Maliyet Toplam 1.198,2M ₺ · İst.Yolu 70,1M ₺
--   ÜstFiyat   Toplam 3.152,6M ₺ · İst.Yolu 179,1M ₺  (sahte negatif gitti)
-- =====================================================================
SELECT
    [Maliyet Tipi]                                                                  AS [Maliyet Bazı],
    CAST(SUM([FSM Stok Maliyet])           AS decimal(18,2))                        AS [FSM ₺],
    CAST(SUM([Özlüce Stok Maliyet])        AS decimal(18,2))                        AS [Özlüce ₺],
    CAST(SUM([İst.Yolu Stok Maliyet])      AS decimal(18,2))                        AS [İst.Yolu ₺],
    CAST(SUM([Merkez Depo Stok Maliyet])   AS decimal(18,2))                        AS [WMS Depo ₺],
    CAST(SUM([Odak Depo Stok Maliyet])     AS decimal(18,2))                        AS [Odak Depo ₺],
    CAST(SUM([FSM Stok Maliyet] + [Özlüce Stok Maliyet] + [İst.Yolu Stok Maliyet]
           + [Merkez Depo Stok Maliyet] + [Odak Depo Stok Maliyet]) AS decimal(18,2)) AS [TOPLAM ₺]
FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
WHERE Tarih = (SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU)
  AND KTGR3 <> N'Sınav Okulları'   -- hayalet stok hariç
GROUP BY [Maliyet Tipi];

-- ---------------------------------------------------------------------
-- Kategori bazlı (Ort.Maliyet) — en değerli 20 kategori
-- ---------------------------------------------------------------------
-- SELECT TOP 20 KTGR3,
--     CAST(SUM([FSM Stok Maliyet]+[Özlüce Stok Maliyet]+[İst.Yolu Stok Maliyet]
--            +[Merkez Depo Stok Maliyet]+[Odak Depo Stok Maliyet]) AS decimal(18,2)) AS Toplam_TL
-- FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
-- WHERE Tarih = (SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU)
--   AND [Maliyet Tipi] = 'Ort.Maliyet'
--   AND KTGR3 <> N'Sınav Okulları'
-- GROUP BY KTGR3 ORDER BY Toplam_TL DESC;
