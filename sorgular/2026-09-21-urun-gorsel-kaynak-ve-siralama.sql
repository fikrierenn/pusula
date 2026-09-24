/*
  Ürün görseli — İKİ KAYNAK, HANGİSİ BİRİNCİL? + çoklu görsel sıralaması
  DB: DerinSISBkm + DerinSISBkmWeb (192.168.40.201)
  Tarih: 21.09.2026 · Bağlam: plan-50 mağaza ürün-bulma uygulaması

  NEDEN ÖLÇÜLDÜ: Uygulama kapağı T-Soft CDN'inden alıyordu ve mağazada bazı kitapların
  kapağı görünmüyordu. GMY: "bunu erp içindeki blob resimden yapacaktık."

  BULGULAR
  (1) DB BLOB 714.691 ürünü kapsıyor, CDN 441.215 → DB %62 daha fazla. CDN ayrıca
      internet ister; mağaza ağı yerel. ⇒ BLOB birincil, CDN yedek yapıldı.
  (2) ⚠ Sema'da "web.urnWeb BOŞ (0 satır)" yazıyordu ve YANLIŞTI: iddia
      DerinSISBkm.web.urnWeb'e bakmış (gerçekten 0), oysa doğrusu
      DerinSISBkmWeb.web.urnWeb (752.498). Tek harflik veritabanı adı farkı.
  (3) ⚠⚠ urnWebOnce bir BAYRAK DEĞİL, SIRA numarası (1→717.058 · 0→30.656 · 2→2.840 …
      20→1). Kapak = ORDER BY urnWebOnce, urnWebID (ARTAN). Uygulamada DESC yazılıydı →
      21.845 çok görselli üründe kapak yerine SON görsel gösteriliyordu; hata sessizdi
      çünkü dönen şey geçerli bir JPEG.
*/

-- ── 1. Kaynak kapsaması: DB BLOB vs T-Soft CDN ───────────────────────────────
SELECT Kaynak = 'DB BLOB (DerinSISBkmWeb.web.urnWeb)', Urun = COUNT(*)
FROM (SELECT DISTINCT w.urnWebBilgiID
      FROM DerinSISBkmWeb.web.urnWeb w WITH (NOLOCK)
      WHERE w.urnWebResim IS NOT NULL) a
UNION ALL
SELECT 'CDN (DerinSISBkm.ent.tsoft_urun.ImageUrl)', COUNT(*)
FROM (SELECT DISTINCT t.stkid
      FROM DerinSISBkm.ent.tsoft_urun t WITH (NOLOCK)
      WHERE t.ImageUrl IS NOT NULL AND t.ImageUrl <> '') b;
-- 2026-09-21: DB BLOB 714.691 · CDN 441.215

-- ── 2. "web.urnWeb boş" iddiasının çürütülmesi — AYNI AD, BAŞKA VERİTABANI ───
SELECT Nerede = 'DerinSISBkm.web.urnWeb',
       Satir  = (SELECT COUNT(*) FROM DerinSISBkm.web.urnWeb WITH (NOLOCK))
UNION ALL
SELECT 'DerinSISBkmWeb.web.urnWeb',
       (SELECT COUNT(*) FROM DerinSISBkmWeb.web.urnWeb WITH (NOLOCK));
-- 2026-09-21: 0  ·  752.498

-- ── 3. urnWebOnce DAĞILIMI — bayrak mı, sıra mı? ─────────────────────────────
SELECT TOP 20 OnceDegeri = w.urnWebOnce, Satir = COUNT(*)
FROM DerinSISBkmWeb.web.urnWeb w WITH (NOLOCK)
GROUP BY w.urnWebOnce
ORDER BY COUNT(*) DESC;
-- 2026-09-21: 1→717.058 · 0→30.656 · 2→2.840 · 3→1.377 · 4→396 · 5→88 … 20→1
-- ⇒ 0/1 bayrağı DEĞİL. İki konvansiyon: tek görselli çoğunlukla 1, çok görselli 0'dan başlar.

-- ── 4. Kaç ürün çok görselli ─────────────────────────────────────────────────
SELECT Grup  = CASE WHEN n = 1 THEN '1 resim' ELSE '2+ resim' END,
       Urun  = COUNT(*),
       Resim = SUM(n)
FROM (SELECT w.urnWebBilgiID, n = COUNT(*)
      FROM DerinSISBkmWeb.web.urnWeb w WITH (NOLOCK)
      WHERE w.urnWebResim IS NOT NULL
      GROUP BY w.urnWebBilgiID) t
GROUP BY CASE WHEN n = 1 THEN '1 resim' ELSE '2+ resim' END;
-- 2026-09-21: 1 resim → 692.846 ürün · 2+ resim → 21.845 ürün / 59.653 görsel (en çok 18)

-- ── 5. SIRALAMANIN KANITI — tek üründe görseller ─────────────────────────────
-- stkID 1738434 "Stanley The Legendary Food Jar + Spork 0.4L Rose Quartz" (4 görsel).
-- Görseller dışarı alınıp GÖZLE bakıldı: Once=0 temiz ürün fotoğrafı (KAPAK),
-- Once=3 üstü "THE LEGENDARY FOOD JAR + SPORK" yazılı tanıtım görseli.
-- ⇒ ARTAN sıra doğru; DESC kapak yerine tanıtım görselini seçiyordu.
SELECT w.urnWebID, w.urnWebOnce, Bayt = DATALENGTH(w.urnWebResim), u.stkAd
FROM DerinSISBkmWeb.web.urnWeb w WITH (NOLOCK)
JOIN DerinSISBkm.dbo.urn u ON u.stkID = w.urnWebBilgiID
WHERE w.urnWebBilgiID = 1738434 AND w.urnWebResim IS NOT NULL
ORDER BY w.urnWebOnce, w.urnWebID;
-- 2026-09-21: (4523977, 0, 12.084) · (4523978, 1, 17.850) · (4523979, 2, 12.528) · (4523980, 3, 12.862)

-- ── 6. KANONİK KAPAK SORGUSU (uygulamanın kullandığı) ────────────────────────
-- @sira 0 tabanlı: 0 = kapak.
DECLARE @stokId int = 1738434, @sira int = 0;
SELECT w.urnWebResim
FROM DerinSISBkmWeb.web.urnWeb AS w WITH (NOLOCK)
WHERE w.urnWebBilgiID = @stokId AND w.urnWebResim IS NOT NULL
ORDER BY w.urnWebOnce, w.urnWebID
OFFSET @sira ROWS FETCH NEXT 1 ROWS ONLY;
