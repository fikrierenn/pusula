-- Bursa Kültür iade zinciri: BKM (DerinSIS) -> Bursa Kültür (KIBO) -> asıl tedarikçi
-- DB: DerinSISBkm (192.168.40.201) + KIBO = [192.168.40.140].kibobkm (linked server, Bursa Kültür'ün canlı KIBO'su)
-- Bulgu (23.10.2026, ölçüldü):
--   * Bizim alış iade faturamız (fat.eTip=2, eFirma=56) KIBO'ya ALIŞ faturası (belgekod=3) olarak girilir.
--   * Bağ = fat.eNo  <->  tumbelgeler.fattakipno (= einvoice_id). KIBO'da BKM carisi skod=1417 (VKN 1270120858).
--   * KIBO belgekod: 1=Satış Faturası · 2=Alış İade Faturası · 3=Alış Faturası (aciklama alanından).
--   * stokinout.stok_kod = barkod (urnBrkd.urnBarkod, urnBrkdOnce=0). Satırda lngcarikod 0 olabilir -> cari başlıktan.
--   * SURA.kibobkm ŞURA firmasıdır, Bursa Kültür DEĞİL (kullanıcı: ara katman, iptal).
--   * Cross-server OUTER APPLY (fat x tumbelgeler) 120 sn'yi aştı -> iki tarafı ayrı çek, yerelde eşle.
-- Örnek: IEF2026000002413 (17.10.2026, İst.Yolu, 12 adet LGS Türkçe Soru Kütüphanesi, 1.043,40 TL)
--   KIBO belgeno 55069868, belgekod 3, 12 adet, net 1.043,40 -> ürün/adet/tutar birebir.
--   Sonrasında bu ürün için KIBO'da Alış İade (2) YOK -> tedarikçiye iade edilmemiş (23.10 itibarıyla).

-- 1) Bizim iade faturamızın satırları
SELECT f.eNo, f.eTarih, f.eMekan, a.ehStkID, u.stkAd, b.urnBarkod,
       -a.ehAdetN AS adet, a.ehTutar, a.ehIndirim, a.ehTutarN
FROM DerinSISBkm.dbo.fat f
JOIN DerinSISBkm.dbo.fatAyr a ON a.ehID = f.eID
JOIN DerinSISBkm.dbo.urn u ON u.stkID = a.ehStkID
LEFT JOIN DerinSISBkm.dbo.urnBrkd b ON b.urnBrkdStkID = a.ehStkID AND b.urnBrkdOnce = 0
WHERE f.eNo = 'IEF2026000002413';

-- 2) KIBO'daki karşılığı (başlık)
SELECT belgeno, tarih, belgekod, lngcarikod, borctl, alacaktl, kdvtutar, fattakipno, einvoice_id
FROM [192.168.40.140].kibobkm.dbo.tumbelgeler
WHERE fattakipno = 'IEF2026000002413';

-- 3) KIBO satırları
SELECT s.stok_kod, s.in_miktar, s.out_miktar, s.birim_fiyat, s.iskonto, s.net_tutar
FROM [192.168.40.140].kibobkm.dbo.stokinout s
WHERE s.belge_kod = 3 AND s.belge_no = 55069868;

-- 4) Ürünün KIBO'daki alış / alış iade geçmişi (cari başlıktan)
SELECT s.belge_kod, t.lngcarikod, c.firma, COUNT(*) satir,
       SUM(s.in_miktar) giris, SUM(s.out_miktar) cikis, MIN(s.duz_tarih) ilk, MAX(s.duz_tarih) son
FROM [192.168.40.140].kibobkm.dbo.stokinout s
JOIN [192.168.40.140].kibobkm.dbo.tumbelgeler t ON t.belgeno = s.belge_no AND t.belgekod = s.belge_kod
LEFT JOIN [192.168.40.140].kibobkm.dbo.cari c ON c.skod = t.lngcarikod
WHERE s.stok_kod = '9786057806000' AND s.belge_kod IN (2, 3)
GROUP BY s.belge_kod, t.lngcarikod, c.firma
ORDER BY s.belge_kod, son;

-- 5) Ocak örneği: IEF2026000000176 (17.01.2026, FSM, 315 adet Tuval Boyama Seti Yeni Model, 3033030003663)
--    KIBO belgeno 55065962 alış (3), 315 adet -> birebir. KIBO stok_no 738141.
--    Bulgu: ürünün KIBO'da HİÇBİR tedarikçiden alışı yok (giriş 943 = yalnız BKM belgeleri; çıkış 13.610).
--    Aynı 315 adet 10.02.2026'da BEF2026000000127 (mekan 60398 Heykel Transfer, eTip=1) ile Bursa Kültür'e geri satılmış.
--    IFF2026000000010 (eTip=10 İade Fark Faturası, 120 adet) KIBO'da alış (3) olarak 120 adet STOK girişiyle işlenmiş.
SELECT s.belge_kod, CASE WHEN s.belge_kod = 27 THEN 0 ELSE t.lngcarikod END AS cari, c.firma,
       YEAR(s.duz_tarih) * 100 + MONTH(s.duz_tarih) AS ay, COUNT(*) AS satir,
       SUM(s.in_miktar) AS giris, SUM(s.out_miktar) AS cikis
FROM [192.168.40.140].kibobkm.dbo.stokinout s
LEFT JOIN [192.168.40.140].kibobkm.dbo.tumbelgeler t ON t.belgeno = s.belge_no AND t.belgekod = s.belge_kod
LEFT JOIN [192.168.40.140].kibobkm.dbo.cari c ON c.skod = t.lngcarikod
WHERE s.stok_no = 738141 AND s.belge_kod <> 106   -- 106 = 27'nin aynası (aynı adet/tutar)
GROUP BY s.belge_kod, CASE WHEN s.belge_kod = 27 THEN 0 ELSE t.lngcarikod END, c.firma,
         YEAR(s.duz_tarih) * 100 + MONTH(s.duz_tarih)
ORDER BY ay, s.belge_kod;

-- 6) Ürün ürün kontrol — tetik BİZİM iademiz: IEF2025000000680 (17.06.2025, merkez depo, 36 ürün, 15.000 adet, 75.000 TL)
--    KIBO belgeno 55062833 (alış, 83.220 TL KDV dahil). 36/36 ürün adet birebir.
--    17.06.2025 sonrası: tedarikçiye (KARGI BASIM, cari 4449) alış iade = 0 · BKM'ye geri satış = 1 adet ·
--    perakende = 6.204 adet · KIBO kalan bakiye ≈168.494 adet (36 ürün).
--    Kaynak: tedarikçi KARGI BASIM 201.300 adet (30.05–05.10.2023), POİNT 5.702 adet (2024-2026).
--    Adım 1: bizim satırlar (fat.eNo) → barkod listesi. Adım 2: aşağıdaki KIBO sorgusu IN (<barkodlar>) ile.
--    (Cross-server tek sorgu yavaş; iki tarafı ayrı çekip yerelde eşleştir.)
SELECT s.stok_kod,
       SUM(CASE WHEN s.belge_kod = 3 AND s.belge_no = 55062833 THEN s.in_miktar ELSE 0 END) AS kibo_giris,
       SUM(CASE WHEN s.duz_tarih >= '20250617' AND s.belge_kod = 2 AND t.lngcarikod NOT IN (1417, 1412) THEN s.out_miktar ELSE 0 END) AS tedarikciye_iade,
       SUM(CASE WHEN s.duz_tarih >= '20250617' AND s.belge_kod = 1 AND t.lngcarikod IN (1417, 1412) THEN s.out_miktar ELSE 0 END) AS bkm_ya_geri_satis,
       SUM(CASE WHEN s.duz_tarih >= '20250617' AND s.belge_kod = 27 THEN s.out_miktar ELSE 0 END) AS perakende
FROM [192.168.40.140].kibobkm.dbo.stokinout s
LEFT JOIN [192.168.40.140].kibobkm.dbo.tumbelgeler t ON t.belgeno = s.belge_no AND t.belgekod = s.belge_kod
WHERE s.stok_kod IN ('8698987180901' /* , ... 36 barkod */)
GROUP BY s.stok_kod;

-- 7) KIBO keşfi (23.10.2026) — sunucu/veritabanı ve belge tipleri
--    [192.168.40.140]: kibobkm (CANLI, tfirma='bkmnet') · kibobkm0609/2014/2017 arşiv · GOPLUS* KULLANILMIYOR (kullanıcı).
--    SURA.kibobkm = ŞURA firması (iptal ara katman). 201'deki KIBO = yalnız ürün ana verisi.
SELECT name, create_date FROM [192.168.40.140].master.sys.databases ORDER BY name;
SELECT firma_name FROM [192.168.40.140].kibobkm.dbo.tfirma;
SELECT t.belgekod, COUNT(*) AS belge, MAX(t.aciklama) AS ornek_aciklama, SUM(t.borctl) AS borc, SUM(t.alacaktl) AS alacak
FROM [192.168.40.140].kibobkm.dbo.tumbelgeler t WHERE t.tarih >= '20250101' GROUP BY t.belgekod ORDER BY t.belgekod;
SELECT s.belge_kod, s.belgetip, s.ambar_kod, COUNT(*) AS satir, SUM(s.in_miktar) AS giris, SUM(s.out_miktar) AS cikis
FROM [192.168.40.140].kibobkm.dbo.stokinout s WHERE s.duz_tarih >= '20250101' GROUP BY s.belge_kod, s.belgetip, s.ambar_kod ORDER BY s.belge_kod;
SELECT belgekod, COUNT(*) AS n, MAX(aciklama) AS ornek FROM [192.168.40.140].kibobkm.dbo.tstockfiss GROUP BY belgekod ORDER BY belgekod;
SELECT * FROM [192.168.40.140].kibobkm.dbo.ambar;     -- 0 MERKEZ · 1 BKM ALTIPARMAK · 2 ŞURA · 3 DEPO · 4 FSM (2025+ hepsi 0)
-- Perakende (27) uç satırlar: barkod fiyat alanına okutulmuş
SELECT TOP 5 s.duz_tarih, s.belge_no, s.stok_kod, s.out_miktar, s.birim_fiyat, s.net_tutar
FROM [192.168.40.140].kibobkm.dbo.stokinout s WHERE s.belge_kod = 27 ORDER BY s.net_tutar DESC;
-- Stok bakiyesi güvenilmez: 547.785 ürünün 119.112'si eksi
SELECT COUNT(*) AS stok, SUM(CASE WHEN smiktar < 0 THEN 1 ELSE 0 END) AS negatif,
       SUM(CASE WHEN smiktar < 0 THEN smiktar END) AS neg_adet, SUM(CASE WHEN smiktar > 0 THEN smiktar END) AS poz_adet
FROM [192.168.40.140].kibobkm.dbo.stok;
SELECT l.stck_stok_stokno, l.stck_ambar_kod, l.stck_ambar_stok, st.smiktar
FROM [192.168.40.140].kibobkm.dbo.tstockloc l JOIN [192.168.40.140].kibobkm.dbo.stok st ON st.stokno = l.stck_stok_stokno
WHERE l.stck_stok_stokno IN (738141, 557315);

-- 8) Ters yön + barkod köprüsü (2026): KIBO'daki BKM belgeleri DerinSIS'te var mı, hangi eTip?
--    Sonuç: belgekod 1 633/648 (eTip 0) · 2 25/25 (eTip 0:19, 3:6) · 3 871/873 (eTip 1:401 2:69 4:93 6:178 7:7 8:34 10:85 0:4)
--    Barkod: 7.734 farklı → Once=0 ile 7.679, yalnız ek barkod 43, eşleşmeyen 12.
SET NOCOUNT ON;
IF OBJECT_ID('tempdb..#k') IS NOT NULL DROP TABLE #k;
SELECT t.belgekod, CAST(t.fattakipno AS varchar(50)) AS no, t.tarih
INTO #k FROM [192.168.40.140].kibobkm.dbo.tumbelgeler t
WHERE t.lngcarikod IN (1417, 1412) AND t.tarih >= '20260101' AND t.belgekod IN (1, 2, 3);
SELECT k.belgekod, f.eTip, COUNT(*) AS n
FROM #k k JOIN dbo.fat f ON f.eNo = k.no COLLATE Turkish_CI_AS AND f.eDurum <> 2 AND f.eFirma = 56
GROUP BY k.belgekod, f.eTip ORDER BY 1, 2;
IF OBJECT_ID('tempdb..#kb') IS NOT NULL DROP TABLE #kb;
SELECT DISTINCT CAST(s.stok_kod AS varchar(50)) AS brk INTO #kb
FROM [192.168.40.140].kibobkm.dbo.stokinout s
JOIN [192.168.40.140].kibobkm.dbo.tumbelgeler t ON t.belgeno = s.belge_no AND t.belgekod = s.belge_kod
WHERE s.duz_tarih >= '20260101' AND s.belge_kod = 3 AND t.lngcarikod = 1417;
SELECT COUNT(*) AS kibo_barkod,
       SUM(CASE WHEN b.urnBrkdStkID IS NOT NULL THEN 1 ELSE 0 END) AS once0_esles,
       SUM(CASE WHEN b.urnBrkdStkID IS NULL AND e.urnBarkod IS NOT NULL THEN 1 ELSE 0 END) AS yalniz_ek_barkod
FROM #kb k
LEFT JOIN dbo.urnBrkd b ON b.urnBarkod = k.brk COLLATE Turkish_CI_AS AND b.urnBrkdOnce = 0
LEFT JOIN (SELECT DISTINCT urnBarkod FROM dbo.urnBrkd WHERE urnBrkdOnce <> 0) e ON e.urnBarkod = k.brk COLLATE Turkish_CI_AS;
