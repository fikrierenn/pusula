/* ============================================================================
   `urn.piyasaMarj` NE? — "HEDEF MARJ" SANILDI, **WEB İNDİRİM ORANI** ÇIKTI
   (2026-09-12) · DB: DerinSISBkm (profil: erp)

   ⚠ BU DOSYA BİR DÜZELTME KAYDIDIR. Aynı gün iki hata yapıldı, ikisi de ölçümle
     yakalandı ve ikisi de burada yazılı.
   ============================================================================ */

/* ── 1) İLK HATA: KOLONUN ADINDAN ANLAM ÇIKARMAK ───────────────────────────────
   `urn.piyasaMarj` adı "piyasa marjı" diyor. HEDEF MARJ sanıldı ve üstüne bir
   metrik kuruldu. `stkKod`u barkod sanma vakasının aynı sınıfı.
   Önce tanım testi yapılmalıydı — YAPILMADI, sonra yapıldı (blok 4). */

/* ── 2) İKİNCİ HATA: KAPSAM UYUŞMAZLIĞI ────────────────────────────────────────
   İlk ölçüm hedefi MAĞAZA satışıyla karşılaştırdı: `SatisAnaliziTaban.PosNet /
   PosAdet` kasa (EncoreMerkez) verisidir.
   Kullanıcı düzeltti: "hedef marj sadece web için, mağaza için değil".
   ⇒ `olctum-mu-cikardim-mi.md` § kapsam eşleşmesi: "bu ölçümün süzgeci, koddaki
     süzgecin AYNISI mı?" — değildi. */

/* ── 3) ÜÇÜNCÜ TUZAK: KOLON LİSTESİ SESSİZCE KESİLDİ ───────────────────────────
   `ent.tsoft_urun` ilk dökümde `--max-rows 40` ile çekildi, 40 kolon döndü ve
   "fiyat kolonu yok" sanıldı. TABLO 85 KOLON. */
SELECT COUNT(*) AS kolon_sayisi
FROM   DerinSISBkm.sys.columns c
JOIN   DerinSISBkm.sys.objects o ON o.object_id = c.object_id
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
WHERE  s.name = 'ent' AND o.name = 'tsoft_urun';
/* 85. Fiyat kolonları 66-69'da ve KDV HARİÇ HAZIR:
     fiyat_liste_kdvdahil · fiyat_liste_kdvharic · fiyat_net_kdvdahil · fiyat_net_kdvharic
   (`sql-server-conventions.md` § --max-rows sessiz keser — aynı gün ikinci kez.) */

/* ── 4) ★★★ KİMLİK TESTİ — piyasaMarj GERÇEKTE NE? ────────────────────────────
   Hipotez: web_net = web_liste × (1 − piyasaMarj/100), yani piyasaMarj İNDİRİM ORANI. */
WITH t AS (
    SELECT u.piyasaMarj,
           ts.fiyat_liste_kdvharic AS liste,
           ts.fiyat_net_kdvharic   AS net,
           100.0*(ts.fiyat_liste_kdvharic - ts.fiyat_net_kdvharic)
                 / NULLIF(ts.fiyat_liste_kdvharic,0) AS gercek_indirim
    FROM   DerinSISBkm.ent.tsoft_urun ts WITH(NOLOCK)
    JOIN   DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = ts.stkid
    WHERE  u.piyasaMarj > 0 AND ts.satis_durum = 1
      AND  ts.fiyat_net_kdvharic > 0 AND ts.fiyat_liste_kdvharic > 0
)
SELECT COUNT_BIG(*) AS urun,
       CONVERT(decimal(10,2), AVG(piyasaMarj))                        AS ort_piyasaMarj,
       CONVERT(decimal(10,2), AVG(gercek_indirim))                    AS ort_gercek_indirim,
       CONVERT(decimal(10,2), AVG(ABS(piyasaMarj - gercek_indirim)))  AS ort_mutlak_sapma,
       SUM(CASE WHEN ABS(piyasaMarj - gercek_indirim) < 0.5 THEN 1 ELSE 0 END) AS TAM_ESLESEN,
       SUM(CASE WHEN ABS(piyasaMarj - gercek_indirim) < 2.0 THEN 1 ELSE 0 END) AS yakin_2puan
FROM t;
/* 320.611 ürün · ort piyasaMarj 28,00 · ort gerçek indirim 28,80 ·
   **ORTALAMA MUTLAK SAPMA 0,23 PUAN** · TAM EŞLEŞEN 317.971 (**%99,2**)
   ⇒ `urn.piyasaMarj` BİR HEDEF DEĞİL, UYGULANAN WEB İNDİRİM ORANI.
     Web net fiyatı doğrudan bundan türetiliyor. KANITLANDI. */

/* ── 5) ÜRÜN KARTINDA WEB FİYATI HANGİ KOLON ─────────────────────────────────── */
SELECT COUNT_BIG(*) AS urun,
       SUM(CASE WHEN fiyatS  > 0 THEN 1 ELSE 0 END) AS fiyatS_dolu,
       SUM(CASE WHEN fiyatS1 > 0 THEN 1 ELSE 0 END) AS fiyatS1_dolu,
       SUM(CASE WHEN fiyatS2 > 0 THEN 1 ELSE 0 END) AS fiyatS2_dolu,
       SUM(CASE WHEN fiyatS3 > 0 THEN 1 ELSE 0 END) AS fiyatS3_dolu,
       SUM(CASE WHEN fiyatS4 > 0 THEN 1 ELSE 0 END) AS fiyatS4_dolu,
       CONVERT(decimal(10,3), AVG(CASE WHEN fiyatS>0 AND fiyatS2>0 THEN fiyatS2/fiyatS END)) AS S2_bolu_S
FROM   DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE urnTip = 0;
/* 837.997 ürün · fiyatS 837.396 · **fiyatS2 837.396** · fiyatS1 90 · fiyatS3 501 · fiyatS4 2.430
   S2/S = **0,758**
   ⇒ **`fiyatS` MAĞAZA fiyatı · `fiyatS2` WEB fiyatı.** Diğerleri pratikte boş. */

/* ── 6) WEB MARJI — doğru kaynak, doğru kapsam ────────────────────────────────── */
WITH t AS (
    SELECT b.Kategori3, u.piyasaMarj, b.BirimMaliyet,
           ts.fiyat_liste_kdvharic AS web_liste,
           ts.fiyat_net_kdvharic   AS web_net
    FROM   DerinSISBkm.bkm.SatisAnaliziTaban b WITH(NOLOCK)
    JOIN   DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = b.stkID
    JOIN   DerinSISBkm.ent.tsoft_urun ts WITH(NOLOCK) ON ts.stkid = b.stkID
    WHERE  b.Kesim = '20260911' AND u.piyasaMarj > 0
      AND  b.BirimMaliyet > 0 AND b.BirimMaliyet <= b.SatisFiyat      -- B-175 ön-şartı
      AND  b.MaliyetTarih >= DATEADD(MONTH,-6,GETDATE())              -- maliyet TAZE
      AND  ts.fiyat_net_kdvharic > 0 AND ts.satis_durum = 1
)
SELECT Kategori3, COUNT_BIG(*) AS urun,
       CONVERT(decimal(10,1), AVG(100.0*(web_liste-web_net)/NULLIF(web_liste,0))) AS web_indirim,
       CONVERT(decimal(10,1), AVG(100.0*(web_net-BirimMaliyet)/NULLIF(web_net,0))) AS WEB_MARJI
FROM t GROUP BY Kategori3 HAVING COUNT_BIG(*) >= 200 ORDER BY urun DESC;
/* kategori            ürün    web indirimi   WEB MARJI
   Kitap              25.914      %33,3        **%25,1**
   Çocuk Kitabı       20.402      %32,8        **%26,6**
   Akademi             4.046      %25,3        **%32,0**
   Hazırlık Kitapları  3.561      %25,3        **%34,7**
   Kırtasiye           3.074      %27,6        **%39,3**
   Oyuncak               561      %16,9        **%27,7**
   ⇒ İNDİRİM KİTAPTA EN AĞIR (%33,3 / %32,8); web marjı da orada en düşük (%25,1).
     Kırtasiyede indirim daha düşük, marj en yüksek (%39,3). */

/* ── 7) ⚠ MARJ SEVİYESİ MALİYETE BAĞLI — indirim ölçümü DEĞİL ────────────────── */
/* Maliyet yaşına göre "marj" (mağaza etiket fiyatı üstünden, son 6 ay dışı dahil):
     son 6 ay   73.260 ürün → 51,2
     6-18 ay    61.854      → 57,1
     18ay-3yıl  64.929      → 66,3
     3+ yıl     22.944      → 74,6
   ⇒ Maliyet eskidikçe "marj" büyüyor: ÖLÇÜM ARTEFAKTI İMZASI (enflasyonla değersizleşen
     eski maliyet). Bu yüzden tüm ölçümler YALNIZ son 6 aylık maliyetle yapıldı.
   ⇒ İNDİRİM ölçümü maliyetten TAMAMEN BAĞIMSIZ ve sağlamdır; MARJ SEVİYESİ değildir
     (`metrics:birim_maliyet` § ORT_ALIS_CURUDU sınırını devralır). */

/* ============================================================================
   DERS — AYNI GÜN ÜÇ TUZAK
   1. Kolonun ADINDAN anlam çıkarmak  → kimlik testiyle çürütüldü (%99,2 indirim oranı)
   2. Kapsam uyuşmazlığı (web hedefi ↔ mağaza satışı) → kullanıcı yakaladı
   3. `--max-rows` sessiz kesme → "fiyat kolonu yok" sanıldı, tablo 85 kolonmuş
   Üçü de "makul görünen ama yanlış" sınıfı; hiçbiri hata vermedi.
   ============================================================================ */
