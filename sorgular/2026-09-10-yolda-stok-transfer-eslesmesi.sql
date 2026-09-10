/* ═══════════════════════════════════════════════════════════════════════════════
   YOLDA STOK — depo çıkışı ile mağaza girişinin EŞLEŞMEYEN kısmı      10.09.2026

   SORU: Transfer irsaliyesi depodan çıkmış ama mağaza kabul etmemişse mal
   hiçbir mekanda görünmüyor. Panel toplamında ne kadar eksik var?

   NEDEN SORULDU: stkID 1739183 (Maxx MX-617 Tahta Kalem Seti) incelemesinde
   İst.Yolu'na 08.09'da çıkan 480 ve FSM'ye 09.09'da çıkan 240 adedin ALIM
   bacağı hiç yoktu → 720 adet ne depoda ne mağazada. `satinalma-danisman`
   kurulu bunu KPI kartı adayı (madde E) olarak işaretledi.

   YÖNTEM: Eşleştirme anahtarı `irs.eNo` + `stkID`. Çıkış bacağı mekan 12'de
   negatif (ehTip 13 "Depo Mağaza"), alım bacağı mağaza mekanında pozitif.
   ⚠ ehTip 13 iki bacakta da AYNI (yön ehMekan + işaretle ayrılıyor).

   BULGU (kesim 09.09.2026, son 120 gün):
     eşleşmeyen satır  2.389
     çeşit             1.869
     yolda adet       53.602
     hiç giriş yok     2.389  ← hepsi; kısmi kabul YOK
     en eski çıkış    08.09.2026 (2 gün)
     14 günden eski        0

   YORUM: 120 günlük pencerede yalnız son 2 günün transferleri eşleşmemiş →
   mağaza kabulü normalde ~2 günde tamamlanıyor. Bu bir yönetim problemi değil,
   ZAMANLAMA ARTEFAKTI. ⇒ KPI kartı YAPILMADI; panel bandında beyan edildi.
   Aynı bulgu "Mağazalar Arası Transfer" kartındaki 14 günlük `SonGiris`
   muhafızının YETERLİ olduğunu kanıtlıyor (14 > 2).

   ⚠ Eşleştirme anahtarının doğruluğunun kanıtı: eNo+stkID yanlış olsaydı 120
   günün TAMAMI eşleşmemiş görünürdü. Yalnız son 2 gün çıkması anahtarın
   tuttuğunu gösteriyor (elenen alternatif açıklama).

   İlgili: sema/entities.yaml → irsHrk_zaman_kolonlari · TODO B-170
   ═══════════════════════════════════════════════════════════════════════════════ */

WITH cik AS (
    SELECT i.eNo, h.ehstkID AS stkID,
           CONVERT(int, -SUM(h.ehAdetN)) AS Cikis, MIN(h.ehTrhS) AS Tarih
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
    WHERE h.ehMekan = 12 AND h.ehTip = 13
      AND h.ehTrhS >= DATEADD(DAY, -120, CONVERT(date, '20260909'))
    GROUP BY i.eNo, h.ehstkID
),
gir AS (
    SELECT i.eNo, h.ehstkID AS stkID, CONVERT(int, SUM(h.ehAdetN)) AS Giris
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
    WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip = 13
      AND h.ehTrhS >= DATEADD(DAY, -120, CONVERT(date, '20260909'))
    GROUP BY i.eNo, h.ehstkID
)
SELECT COUNT(*) AS EslesmeyenSatir, COUNT(DISTINCT c.stkID) AS Cesit,
       CONVERT(bigint, SUM(c.Cikis - ISNULL(g.Giris, 0))) AS YoldaAdet,
       SUM(CASE WHEN g.eNo IS NULL THEN 1 ELSE 0 END) AS HicGirisYok,
       CONVERT(varchar(10), MIN(c.Tarih), 104) AS EnEski,
       SUM(CASE WHEN c.Tarih < DATEADD(DAY, -14, CONVERT(date, '20260909'))
                THEN 1 ELSE 0 END) AS OnDortGundenEski
FROM cik c
LEFT JOIN gir g ON g.eNo = c.eNo AND g.stkID = c.stkID
WHERE c.Cikis - ISNULL(g.Giris, 0) > 0;

-- Ürün dökümü (en çok yolda olanlar) — operasyon takibi isterse
SELECT TOP 30 c.stkID, LEFT(ISNULL(u.stkAd, '-'), 45) AS Urun, c.eNo,
       CONVERT(varchar(10), c.Tarih, 104) AS Cikis,
       DATEDIFF(DAY, c.Tarih, CONVERT(date, '20260909')) AS KacGun,
       c.Cikis AS CikanAdet, ISNULL(g.Giris, 0) AS KabulEdilen,
       c.Cikis - ISNULL(g.Giris, 0) AS Yolda
FROM cik c
LEFT JOIN gir g ON g.eNo = c.eNo AND g.stkID = c.stkID
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = c.stkID
WHERE c.Cikis - ISNULL(g.Giris, 0) > 0
ORDER BY c.Cikis - ISNULL(g.Giris, 0) DESC;
