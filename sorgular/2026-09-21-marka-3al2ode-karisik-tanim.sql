/* =====================================================================================
   3 AL 2 ÖDE TANIMLI KİTABI OLAN, AMA 3 AL 2 ÖDE DIŞINDA DA TANIMI BULUNAN MARKALAR
   -------------------------------------------------------------------------------------
   Soru (GMY, 21.09.2026): "3 al 2 öde kampanyasında kitabı tanımlı olan ama aynı zamanda
   3 al 2 öde dışında tanım bulunan markaların listesi".
   DB: DerinSISBkm (+ blok 0'da EncoreMerkez çapraz doğrulama)

   BULGU ÖZETİ (ölçüldü 21.09.2026):
     · Kampanya üyeliği ÜRÜN KARTINDA: dbo.urn.kod4ID -> dbo.urnkod4.kod4Ad; kod4ID=1
       = '3 AL 2 ÖDE' (430.749 ürün, urnTip=0). Kartta alanın adı "Reyon" görünür.
     · Marka seviyesinde flag VAR ama BOŞ: dbo.urnMrk.mrkUcalikiOde -> 10.306/10.306 NULL.
       "Marka 3al2öde'de tanımlı mı" sorusu ürün kartından TÜRETİLİR, kolondan değil.
     · KİTAP kapsamı, TÜM DURUMLAR: 8.435 markanın 6.047'sinde 3 AL 2 ÖDE kitabı var;
       3.143-3.145'i karışık · 2.050 yalnız 3al2öde · 854 yalnızca Tanımsız ile karışık.
       (Aralık verilmesinin sebebi: katalog gün içinde etiketleniyor, sayı oynuyor.)
     · KİTAP kapsamı, YALNIZ AKTİF (bu dosyadaki bloklar): 4.195 markanın 3.167'sinde
       3 AL 2 ÖDE kitabı var; **1.155'i karışık** · 935'i yalnız 3al2öde ·
       her iki tarafı >=10 kitap olan 215 marka. TÜM ÜRÜN + aktif: karışık 1.216.
     · Karışığın ezici çoğunluğu "Kampanya Dışı" ile karışık (akademik/hukuk yayınevleri).

   KAPSAM KARARLARI:
     · "Tanım" = kod4ID NOT IN (0,1). Tanımsız (0) ayrı sayılır; tanımsızlık tanım değil.
     · KİTAP = KatAna LIKE '%Kitap%' + 'Eğitim - Sınavlara Hazırlık - Okula Yardımcı',
       'Kitap Aksesuarları' HARİÇ (adında "Kitap" geçer ama kitap değildir — LIKE tuzağı).
     · urnTip=0 (1=gider/hizmet, 2=demirbaş hariç).
     · ÜRÜN DURUMU (GMY 21.09.2026 "pasif veya tükendi olanları devre dışı bırak"):
       dbo.urn.kod1ID (lookup dbo.urnKod1: 0=Pasif, 1=Aktif, 2=Tükendi). AKTİF süzgeciyle
       kitap kapsamında karışık marka 3.145 -> 1.155'e iner (tüm ürün: 3.273 -> 1.216).
       ⚠ dbo.urn.urnDurum AYRI bir kolondur (kayıt bayrağı: 813.054'ü 1, 26.332'si 0) ve
       ürün durumu DEĞİLDİR. Çapraz ölçüm: kod1=Aktif & urnDurum=0 olan 112 ürün var.

   SINIR: kod4ID ANLIK durumdur. Geçmiş için bkm.urnkod4log. Katalog 06.05.2026 ve
   12.05.2026'da toplu yeniden etiketlendi -> o tarihten öncesiyle kıyas kırılır.

   Üreten script: scripts/marka_3al2ode_karisik_excel.py
   ===================================================================================== */

-- ------------------------------------------------------------------ 0) KASA ÇAPRAZ TEYİT
-- POS'ta 3AL2ÖDE = Campaign Id 1 (3 al -> 2 öde), IsActive=0; kampanyalı son satış kalemi
-- 06.02.2026. Ürün kapsamı Encore'da TUTULMUYOR (CampaignProduct'ta Id=1 için satır yok) —
-- kapsam ERP kartından gelir. Etiket ile kasa tutuyor ama NÜFUS KÜÇÜK: Oca–Şub 2026'da
-- 17 kalem, 17'sinin de kod4Ad'ı '3 AL 2 ÖDE'. Küçük nüfus "doğrulandı" demek değildir.
SELECT k.kod4Ad, COUNT(*) AS Kalem
FROM EncoreMerkez.dbo.SalesProductCampaigns spc
JOIN EncoreMerkez.dbo.Sales s          ON s.Id = spc.SalesId
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = spc.SalesId
                                      AND sp.Sequence = spc.ProductSequence
                                      AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products p       ON p.Id = sp.ProductsId AND ISNUMERIC(p.Code) = 1
JOIN DerinSISBkm.dbo.urn u             ON u.stkID = CONVERT(int, p.Code)
JOIN DerinSISBkm.dbo.urnkod4 k         ON k.kod4ID = u.kod4ID
WHERE spc.CampaignId = 1 AND s.Date >= '20260101' AND s.Date < '20260207'
GROUP BY k.kod4Ad
ORDER BY COUNT(*) DESC;

-- -------------------------------------------------- 0b) MARKA FLAG'İ GERÇEKTEN BOŞ MU
-- "mrkUcalikiOde güncel olmayabilir" -> kısmen dolu değil, TAMAMEN boş (10.306 NULL).
SELECT mrkUcalikiOde, COUNT(*) AS MarkaSayisi
FROM dbo.urnMrk
GROUP BY mrkUcalikiOde;

-- -------------------------------------------------- 0c) DURUM: hangi kolon? (kod1 vs urnDurum)
-- "pasif/tükendi" sorusu kod1ID'den yanıtlanır; urnDurum ayrı bir kayıt bayrağıdır.
SELECT u.urnDurum, k.kod1Ad, COUNT(*) AS n
FROM dbo.urn u
LEFT JOIN dbo.urnKod1 k ON k.kod1ID = u.kod1ID
WHERE u.urnTip = 0
GROUP BY u.urnDurum, k.kod1Ad
ORDER BY COUNT(*) DESC;

-- --------------------------------------------------------------- 1) KAMPANYA ETİKETLERİ
SELECT k.kod4ID, k.kod4Ad, COUNT(u.stkID) AS UrunSayisi
FROM dbo.urnkod4 k
LEFT JOIN dbo.urn u ON u.kod4ID = k.kod4ID AND u.urnTip = 0
GROUP BY k.kod4ID, k.kod4Ad
ORDER BY COUNT(u.stkID) DESC;

-- ------------------------------------------------------------------- 2) BÜYÜKLÜK ÖLÇÜMÜ
WITH kapsam AS (
    SELECT u.urnMrkID, u.kod4ID
    FROM dbo.urn u
    JOIN bkm.UrunBilgi b ON b.stkID = u.stkID
    WHERE u.urnTip = 0
      AND u.kod1ID = 1                 -- YALNIZ AKTİF (0=Pasif, 2=Tükendi hariç)
      AND (b.KatAna LIKE N'%Kitap%' OR b.KatAna = N'Eğitim - Sınavlara Hazırlık - Okula Yardımcı')
      AND b.KatAna <> N'Kitap Aksesuarları'
), marka AS (
    SELECT urnMrkID,
           SUM(CASE WHEN kod4ID = 1 THEN 1 ELSE 0 END)          AS UcAlIkiOde,
           SUM(CASE WHEN kod4ID NOT IN (0,1) THEN 1 ELSE 0 END) AS DigerTanimli,
           SUM(CASE WHEN kod4ID = 0 THEN 1 ELSE 0 END)          AS Tanimsiz
    FROM kapsam GROUP BY urnMrkID
)
SELECT COUNT(*)                                                                  AS MarkaToplam,
       SUM(CASE WHEN UcAlIkiOde > 0 THEN 1 ELSE 0 END)                           AS UcAlIkiOdeVar,
       SUM(CASE WHEN UcAlIkiOde > 0 AND DigerTanimli > 0 THEN 1 ELSE 0 END)      AS Karisik,
       SUM(CASE WHEN UcAlIkiOde > 0 AND DigerTanimli = 0
                 AND Tanimsiz > 0 THEN 1 ELSE 0 END)                             AS SadeceTanimsizIle,
       SUM(CASE WHEN UcAlIkiOde > 0 AND DigerTanimli = 0
                 AND Tanimsiz = 0 THEN 1 ELSE 0 END)                             AS SadeceUcAlIkiOde
FROM marka;

-- ------------------------------------------------- 3) ASIL LİSTE (aktif · kitap: 1.155)
WITH kapsam AS (
    SELECT u.urnMrkID, u.kod4ID
    FROM dbo.urn u
    JOIN bkm.UrunBilgi b ON b.stkID = u.stkID
    WHERE u.urnTip = 0
      AND u.kod1ID = 1                 -- YALNIZ AKTİF (0=Pasif, 2=Tükendi hariç)
      AND (b.KatAna LIKE N'%Kitap%' OR b.KatAna = N'Eğitim - Sınavlara Hazırlık - Okula Yardımcı')
      AND b.KatAna <> N'Kitap Aksesuarları'
), marka AS (
    SELECT urnMrkID,
           SUM(CASE WHEN kod4ID = 1 THEN 1 ELSE 0 END)          AS UcAlIkiOde,
           SUM(CASE WHEN kod4ID NOT IN (0,1) THEN 1 ELSE 0 END) AS DigerTanimli,
           SUM(CASE WHEN kod4ID = 0 THEN 1 ELSE 0 END)          AS Tanimsiz,
           COUNT(*)                                             AS Toplam
    FROM kapsam GROUP BY urnMrkID
)
SELECT m.urnMrkID AS MarkaID,
       ISNULL(mk.mrkAd, '(marka yok)') AS Marka,
       m.UcAlIkiOde, m.DigerTanimli, m.Tanimsiz, m.Toplam,
       CONVERT(decimal(5,1), 100.0 * m.DigerTanimli / NULLIF(m.Toplam,0)) AS DigerTanimliYuzde,
       STUFF((
           SELECT ', ' + x.kod4Ad + ' (' + CONVERT(varchar(12), x.Adet) + ')'
           FROM (SELECT k2.kod4Ad, COUNT(*) AS Adet
                 FROM kapsam c2
                 JOIN dbo.urnkod4 k2 ON k2.kod4ID = c2.kod4ID
                 WHERE c2.urnMrkID = m.urnMrkID AND c2.kod4ID NOT IN (0,1)
                 GROUP BY k2.kod4Ad) x
           ORDER BY x.Adet DESC
           FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 2, '') AS DigerTanimlar
FROM marka m
LEFT JOIN dbo.urnMrk mk ON mk.mrkID = m.urnMrkID
WHERE m.UcAlIkiOde > 0 AND m.DigerTanimli > 0
ORDER BY m.DigerTanimli DESC, m.Toplam DESC;

/* =====================================================================================
   EK BLOK (GMY sorusu 23.09.2026): "kaç üründe 3 al 2 öde tanımlı ve kaç adetin stoğu var"
   -------------------------------------------------------------------------------------
   ÖLÇÜLDÜ 23.09.2026:
     · 3 AL 2 ÖDE etiketli ürün (urnTip=0): 431.824
       Aktif 197.228 · Pasif 156.249 · Tükendi 78.347
     · ÜÇ MAĞAZA (defter, stokSon_vw, stok>0): 154.039 çeşit / 850.752 adet
       Aktif 113.059 / 726.128 · Tükendi 28.233 / 93.849 · Pasif 12.747 / 30.775
       ⇒ aktif 3al2öde ürünlerinin %57,3'ünün mağazada stoğu var.
     · MERKEZ DEPO = WMS (sql-server-conventions § MERKEZ DEPO): RAF+GİRİŞ 117 çeşit /
       606 adet (ÇIKIŞ alanı ayrıca 43 çeşit / 1.106). Merkez depo 3al2öde ürünü
       neredeyse hiç tutmuyor — depodaki hacim "Kampanya Dışı"nda (16.165 çeşit / 2,83M).
       ⚠ ERP defteri aynı mekan için 2.097 çeşit / 25.887 adet diyor; KULLANILMAZ.
     ⚠⚠ MEKAN SEÇİMİ KAPSAM KARARIDIR: defterde 3al2öde stoğu taşıyan 8 mekan var ve
       en büyüğü SATILABİLİR DEĞİL -> 26142 "İptal-Transfer Deposu" (frmDurum=1 pasif)
       43.478 çeşit / 472.704 adet. Ayrıca 4480 İade Deposu (ODAK) 982 ·
       31359 HASARLI ÜRÜN DEPO 7 · 60398 HEYKEL TRANSFER 286.
       Bunları toplayan bir "stok" rakamı satılabilir stoğu %55 şişirir.
   ===================================================================================== */

-- E1) Etiketli ürün sayısı, durum kırılımlı
SELECT k.kod1Ad AS Durum, COUNT(*) AS Urun
FROM dbo.urn u
LEFT JOIN dbo.urnKod1 k ON k.kod1ID = u.kod1ID
WHERE u.urnTip = 0 AND u.kod4ID = 1
GROUP BY k.kod1Ad
ORDER BY COUNT(*) DESC;

-- E2) Mağaza stoğu (defter DOĞRU kaynak: mekan 1/4477/4478)
SELECT k.kod1Ad AS Durum, COUNT(DISTINCT s.ehstkID) AS Cesit, SUM(s.stok) AS Adet
FROM dbo.stokSon_vw s
JOIN dbo.urn u        ON u.stkID = s.ehstkID
LEFT JOIN dbo.urnKod1 k ON k.kod1ID = u.kod1ID
WHERE u.urnTip = 0 AND u.kod4ID = 1 AND s.ehMekan IN (1,4477,4478) AND s.stok > 0
GROUP BY k.kod1Ad
ORDER BY SUM(s.stok) DESC;

-- E3) Merkez depo = WMS (defter OKUNMAZ). Alan tipi: 0 RAF · 1 GİRİŞ · 2 ÇIKIŞ
SELECT w.adrsAlanTipID AS AlanTipi, COUNT(DISTINCT w.stkID) AS Cesit, SUM(w.Stok) AS Adet
FROM depo.stok_adres_palet_vw w
JOIN dbo.urn u ON u.stkID = w.stkID
WHERE u.urnTip = 0 AND u.kod4ID = 1 AND w.Stok > 0
GROUP BY w.adrsAlanTipID
ORDER BY w.adrsAlanTipID;

-- E4) MEKAN DÖKÜMÜ — "üç mağaza" bir KAPSAM SEÇİMİDİR, mekan kümesi değil
SELECT s.ehMekan, f.frmAd, f.frmDurum,
       COUNT(DISTINCT s.ehstkID) AS Cesit, SUM(s.stok) AS Adet
FROM dbo.stokSon_vw s
JOIN dbo.urn u   ON u.stkID = s.ehstkID
LEFT JOIN dbo.frm f ON f.frmID = s.ehMekan
WHERE u.urnTip = 0 AND u.kod4ID = 1 AND s.stok > 0
GROUP BY s.ehMekan, f.frmAd, f.frmDurum
ORDER BY SUM(s.stok) DESC;
