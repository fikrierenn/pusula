/* =====================================================================================
   3 AL 2 ÖDE AFİŞ KAPSAMI — kampanya kategoriyle anlatılabilir mi?      16.10.2026
   -------------------------------------------------------------------------------------
   Soru (GMY): Reklam Kurulu durdurma cezası (2026/3490) sonrası afişe kapsam yazılacak.
   Hariç kitap çok; kampanya kapsamı kategori/reyon adıyla anlatılabilir mi?
   DB: DerinSISBkm (profil: erp) — salt okuma.

   Bilinen (sema + 2026-09-21-marka-3al2ode-karisik-tanim.sql):
     · Kampanya üyeliği ÜRÜN KARTINDA: urn.kod4ID → urnkod4.kod4Ad (kartta adı "Reyon").
       kod4ID=1 = '3 AL 2 ÖDE'. Kategori/marka düzeyinde kural YOK (urnMrk.mrkUcalikiOde boş).
     · Gerçek raf/reyon AYRI şema: ryn.*  — kod4 ile karıştırılmaz.
     · Ürün durumu kod1ID (1=Aktif). Mağaza stoğu stokSon_vw mekan 1/4477/4478.

   Okuma: kategori satırında Pay3al2 ≈ %100 veya ≈ %0 ise o kategori afişte ADIYLA
   yazılabilir. Arada kalan (karışık) kategoriler afiş–kasa uyuşmazlığı riskidir:
   müşteri kategoriye bakıp kampanyalı sanar, kasada indirim çıkmaz.
   SONUÇ: ÇALIŞTIRILMADI (bulut oturumundan ERP'ye erişim yok). Koşunca buraya yaz.
   ===================================================================================== */

-- 1) Kategori bazında kampanya karışıklığı (aktif + mağazada stoğu olan ürün)
WITH stoklu AS (
    SELECT s.ehstkID AS stkID, SUM(s.stok) AS Stok
    FROM dbo.stokSon_vw s
    WHERE s.ehMekan IN (1, 4477, 4478) AND s.stok > 0
    GROUP BY s.ehstkID
), kapsam AS (
    SELECT b.KatAna, b.Kategori3, u.kod4ID, st.Stok
    FROM dbo.urn u
    JOIN stoklu st        ON st.stkID = u.stkID
    JOIN bkm.UrunBilgi b  ON b.stkID = u.stkID
    WHERE u.urnTip = 0 AND u.kod1ID = 1
)
SELECT KatAna, Kategori3,
       COUNT(*)                                             AS UrunStoklu,
       SUM(CASE WHEN kod4ID = 1 THEN 1 ELSE 0 END)          AS UcAlIkiOde,
       SUM(CASE WHEN kod4ID = 0 THEN 1 ELSE 0 END)          AS Tanimsiz,
       SUM(CASE WHEN kod4ID NOT IN (0, 1) THEN 1 ELSE 0 END) AS DigerEtiket,
       CONVERT(decimal(5,1), 100.0 * SUM(CASE WHEN kod4ID = 1 THEN 1 ELSE 0 END) / COUNT(*)) AS Pay3al2,
       CASE WHEN 100.0 * SUM(CASE WHEN kod4ID = 1 THEN 1 ELSE 0 END) / COUNT(*) >= 98 THEN 'TEMIZ-DAHIL'
            WHEN 100.0 * SUM(CASE WHEN kod4ID = 1 THEN 1 ELSE 0 END) / COUNT(*) <= 2  THEN 'TEMIZ-HARIC'
            ELSE 'KARISIK' END                               AS Durum
FROM kapsam
GROUP BY KatAna, Kategori3
ORDER BY CASE WHEN 100.0 * SUM(CASE WHEN kod4ID = 1 THEN 1 ELSE 0 END) / COUNT(*) BETWEEN 2 AND 98 THEN 0 ELSE 1 END,
         COUNT(*) DESC;

-- 2) Özet: stoklu aktif ürünlerin kaçı temiz / karışık kategoride
WITH stoklu AS (
    SELECT s.ehstkID AS stkID
    FROM dbo.stokSon_vw s
    WHERE s.ehMekan IN (1, 4477, 4478) AND s.stok > 0
    GROUP BY s.ehstkID
), kat AS (
    SELECT b.KatAna, b.Kategori3, COUNT(*) AS n,
           100.0 * SUM(CASE WHEN u.kod4ID = 1 THEN 1 ELSE 0 END) / COUNT(*) AS pay
    FROM dbo.urn u
    JOIN stoklu st       ON st.stkID = u.stkID
    JOIN bkm.UrunBilgi b ON b.stkID = u.stkID
    WHERE u.urnTip = 0 AND u.kod1ID = 1
    GROUP BY b.KatAna, b.Kategori3
)
SELECT CASE WHEN pay >= 98 THEN 'TEMIZ-DAHIL' WHEN pay <= 2 THEN 'TEMIZ-HARIC' ELSE 'KARISIK' END AS Durum,
       COUNT(*) AS KategoriSayisi, SUM(n) AS UrunSayisi
FROM kat
GROUP BY CASE WHEN pay >= 98 THEN 'TEMIZ-DAHIL' WHEN pay <= 2 THEN 'TEMIZ-HARIC' ELSE 'KARISIK' END;

-- 3) Cezaya konu vaka: "yabancı dil" geçen kategorilerde etiket dağılımı
SELECT b.KatAna, b.Kategori3, k.kod4Ad, COUNT(*) AS Urun
FROM dbo.urn u
JOIN bkm.UrunBilgi b ON b.stkID = u.stkID
JOIN dbo.urnkod4 k   ON k.kod4ID = u.kod4ID
WHERE u.urnTip = 0 AND u.kod1ID = 1
  AND (b.KatAna LIKE N'%Yabancı%' OR b.Kategori3 LIKE N'%Yabancı%'
       OR b.KatAna LIKE N'%İngilizce%' OR b.Kategori3 LIKE N'%İngilizce%')
GROUP BY b.KatAna, b.Kategori3, k.kod4Ad
ORDER BY b.KatAna, b.Kategori3, COUNT(*) DESC;
