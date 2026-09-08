-- 2026-09-08 · "Satış Analizi 07.09.2026.xlsx" (Kübra Kulaksızoğlu) denetimi
-- Soru: rapordaki MerkezStok hangi kaynaktan? Satis_Toplam hangi pencere? Kapsam eksiği var mı?
-- DB: DerinSISBkm (profil erp)
-- Bulgu: MerkezStok = WMS raf+giriş (kural uyumlu) · Satis_Toplam = 08.09.2025-07.09.2026 (365g)
--        ama merkez depo çıkışı (mekan 12, 1,88M adet/yıl) ve e-ticaret sayılmıyor;
--        ürün evreni WMS'in 734K adedini (poşet+ıslak mendil) dışarıda bırakıyor.

-- 1) Merkez depo: rapordaki 3.273.105 hangi kaynağa denk geliyor?
SELECT 'WMS_raf0_giris1'        AS kaynak, SUM(Stok) AS adet, COUNT(DISTINCT stkID) AS cesit
FROM depo.stok_adres_palet_vw WHERE adrsAlanTipID IN (0,1)
UNION ALL SELECT 'WMS_hepsi_012', SUM(Stok), COUNT(DISTINCT stkID) FROM depo.stok_adres_palet_vw
UNION ALL SELECT 'WMS_raf0',      SUM(Stok), COUNT(DISTINCT stkID) FROM depo.stok_adres_palet_vw WHERE adrsAlanTipID=0
UNION ALL SELECT 'ERP_defter_m12_pozitif', SUM(CASE WHEN Stok>0 THEN Stok ELSE 0 END), COUNT(*) FROM dbo.stokSonAltDepo_vw WHERE ehMekan=12
UNION ALL SELECT 'ERP_defter_m12_net',     SUM(Stok), COUNT(*) FROM dbo.stokSonAltDepo_vw WHERE ehMekan=12;
-- Ölçüm 08.09.2026: WMS raf+giriş 3.984.356/23.665 çeşit · ERP defter net 1.987.795 (poz. 6.231.327)
-- Rapor 3.273.105/23.633 çeşit → çeşit sayısı WMS ile örtüşüyor, ERP defteriyle (426K) örtüşmüyor.

-- 2) Rapor evreninin kaçırdığı WMS ürünleri (top 30'un 12'si raporda yok = 733.817 adet)
SELECT TOP 30 stkID, SUM(Stok) AS rafgiris
FROM depo.stok_adres_palet_vw WHERE adrsAlanTipID IN (0,1)
GROUP BY stkID ORDER BY SUM(Stok) DESC;
-- Eksikler: BKM poşetleri (~367K, ambalaj — meşru) + ıslak mendil (~366K, SATILABİLİR ürün → kapsam kaybı)

-- 3) Satış penceresi: GunlukOrtalamaSatis = Satis_Toplam/365 → 365 günlük pencere
SELECT '2025-09-08..2026-09-07' AS pencere, -SUM(ehAdetN) AS net_adet FROM dbo.irsHrk
WHERE ehTip IN (1,3,4,5,100,101) AND ehMekan IN (1,4477,4478) AND ehTrhS >= '20250908' AND ehTrhS < '20260908'
UNION ALL SELECT '2025-09-01..2026-08-31', -SUM(ehAdetN) FROM dbo.irsHrk
WHERE ehTip IN (1,3,4,5,100,101) AND ehMekan IN (1,4477,4478) AND ehTrhS >= '20250901' AND ehTrhS < '20260901'
UNION ALL SELECT 'sezon2025_08_10', -SUM(ehAdetN) FROM dbo.irsHrk
WHERE ehTip IN (1,3,4,5,100,101) AND ehMekan IN (1,4477,4478) AND ehTrhS >= '20250801' AND ehTrhS < '20251101'
UNION ALL SELECT 'temmuz2025', -SUM(ehAdetN) FROM dbo.irsHrk
WHERE ehTip IN (1,3,4,5,100,101) AND ehMekan IN (1,4477,4478) AND ehTrhS >= '20250701' AND ehTrhS < '20250801';
-- 365g mağaza 5.642.012 vs rapor 5.153.973 (-%8,7 evren filtresi) · sezon 1.843.440 vs rapor 1.695.779 (-%8,0)
-- Temmuz 2025 sadece 192.382 adet → sezonu Ağu-Eki almak adet tarafında savunulabilir.

-- 4) Rapordaki Satis_* neyi SAYMIYOR: mekan × tip kırılımı
SELECT ehMekan, ehTip, -SUM(ehAdetN) AS net_adet, COUNT(*) AS satir
FROM dbo.irsHrk
WHERE ehTip IN (1,3,4,5,100,101) AND ehTrhS >= '20250908' AND ehTrhS < '20260908'
GROUP BY ehMekan, ehTip ORDER BY -SUM(ehAdetN) DESC;
-- mekan 12 / ehTip 1 = 1.903.462 adet (merkez depo çıkışı — toptan/e-tic sevk). Raporda YOK.
-- Sonuç: stok merkez depoyu SAYIYOR, satış merkez çıkışını SAYMIYOR → gün-stok şişiyor.

-- 5) Merkez depo çıkışı stkID bazında (düzeltilmiş devir için)
SELECT ehstkID AS stkID, -SUM(ehAdetN) AS adet FROM dbo.irsHrk
WHERE ehTip IN (1,3,5,101) AND ehMekan=12 AND ehTrhS >= '20250908' AND ehTrhS < '20260908'
GROUP BY ehstkID;
-- 1.883.926 adet / 17.810 çeşit; bunun %64,3'ü (1.211.010) rapor evrenine düşüyor.

-- 6) OdakStok kaynağı: ent.DEPOLARDAKISTOKLAR → ent.odak_depo_Stok
SELECT COUNT(*) AS satir, SUM(StokMiktar) AS adet FROM ent.odak_depo_Stok;  -- 496.708 / 7.294.239
SELECT LEFT(m.definition,2500) AS def FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id=m.object_id JOIN sys.schemas s ON s.schema_id=o.schema_id
WHERE s.name='ent' AND o.name='DEPOLARDAKISTOKLAR';
-- View: merkez = depo.paletUrnTnm (adrsAd CK01/iADE hariç, pUID<>42560) · FSM=mekan 4480 · OZL=mekan 4835
--       (DİKKAT: bu view FSM/ÖZL için 4480/4835 kullanıyor — mağaza mekanID 1/4477/4478 DEĞİL)
-- ent.odak_depo_Stok'ta TARİH/damga kolonu YOK → tazeliği ölçülemiyor (PK sadece stkID).

-- 7) Rapor evreni: 273.515 satır / urn urnTip=0 = 846.553 (%32)
SELECT COUNT(*) AS urn_hepsi, SUM(CASE WHEN urnTip=0 THEN 1 ELSE 0 END) AS urnTip0 FROM dbo.urn;

-- ══════════════════════════════════════════════════════════════════════════════
-- 8) "Merkez çıkışı neyle ölçülüyor" — kullanıcı sorusu üzerine derinleştirme
-- ══════════════════════════════════════════════════════════════════════════════

-- 8a) Kod kümesi ELLE YAZILMADI, lookup'tan okundu:
--     sqlcli lookup --profile erp dbo.irsTip_vw --count-from dbo.irsHrk.ehTip
-- Transferler AYRI kod: 8 Mağaza-Mağaza · 9 Mağaza-Depo · 11 Depo-Depo · 13 Depo-Mağaza
-- → ehTip=1 "Satış" sevk değil. (irsTip_vw 34 kod, ölçüm 08.09.2026)

-- 8b) Mekan 12'nin tüm hareket tipleri — sevk ile satışı ayır
SELECT ehTip,
       SUM(CASE WHEN ehAdetN<0 THEN -ehAdetN ELSE 0 END) AS cikis,
       SUM(CASE WHEN ehAdetN>0 THEN  ehAdetN ELSE 0 END) AS giris,
       COUNT(*) AS satir
FROM dbo.irsHrk
WHERE ehMekan=12 AND ehTrhS >= '20250908' AND ehTrhS < '20260908'
GROUP BY ehTip ORDER BY 2 DESC;
-- 89 Diğer Çıkış 40.073.573 / 88 Diğer Giriş 22.874.082 → WMS iç hareket gürültüsü,
--    mekan-12 defteri DENGELEMİYOR (giriş 30,08M vs çıkış 47,60M) = bilinen senkron sorunu.
-- 13 Depo-Mağaza 3.762.140 (mağazaya sevk — HARİÇ) · 1 Satış 1.903.462 (sayılan).

-- 8c) ehTip=1'in KARŞI TARAFI kim (irs.eFirma → frm.frmAd)
SELECT TOP 15 i.eFirma, f.frmAd, f.frmTip,
       -SUM(h.ehAdetN) AS adet, SUM(h.ehTutarN) AS tutar, COUNT(DISTINCT i.eID) AS belge
FROM dbo.irsHrk h
JOIN dbo.irs i ON i.eID = h.ehID
LEFT JOIN dbo.frm f ON f.frmID = i.eFirma
WHERE h.ehMekan=12 AND h.ehTip=1 AND h.ehTrhS >= '20250908' AND h.ehTrhS < '20260908'
GROUP BY i.eFirma, f.frmAd, f.frmTip
ORDER BY -SUM(h.ehAdetN) DESC;
-- 56 BURSA KÜLTÜR MERKEZİ KİTAP KIRTASİYE GIDA (frmTip=0) 1.375.700 ad / 34,55M ₺ / 443 belge  ← %72
--  9525 ODAK KİTAP-POİNT İNTERNET TEKNOLOJİLERİ           302.908 ad / 33,43M ₺ / 593 belge
--   120 SINAV BASIN YAYIN DAĞITIM                         110.100 ad /  1,87M ₺ / 1 belge (04.06.2026)
-- → merkez depo aynı zamanda toptan/grup-içi dağıtım deposu.

-- 8d) ÇİFT SAYIM TESTİ: firma 56'ya çıkan 1,38M mağazaya geri giriyor mu?
SELECT ehTip,
       SUM(CASE WHEN ehAdetN>0 THEN  ehAdetN ELSE 0 END) AS giris,
       SUM(CASE WHEN ehAdetN<0 THEN -ehAdetN ELSE 0 END) AS cikis
FROM dbo.irsHrk
WHERE ehMekan IN (1,4477,4478) AND ehTrhS >= '20250908' AND ehTrhS < '20260908'
GROUP BY ehTip ORDER BY 2 DESC;
-- Mağaza GİRİŞLERİ: 10 Yerel Alım 4.226.674 · 13 Depo-Mağaza 3.766.166 · 101 POS İade 441.508
--   → 1,38M'lik karşılık giriş YOK. irsHrk'da toplam 8 mekan var (aşağıdaki sorgu), hiçbirinde de yok.
-- SONUÇ: çift sayım değil; mal envanterden gerçekten çıkıyor.

SELECT TOP 15 ehMekan,
       SUM(CASE WHEN ehAdetN>0 THEN  ehAdetN ELSE 0 END) AS giris,
       SUM(CASE WHEN ehAdetN<0 THEN -ehAdetN ELSE 0 END) AS cikis, COUNT(*) AS satir
FROM dbo.irsHrk WHERE ehTrhS >= '20250908' AND ehTrhS < '20260908'
GROUP BY ehMekan ORDER BY 2 DESC;
-- Mekanlar: 12 · 4478 · 4477 · 1 · 60398 · 4480 · 14 · 31359 (hepsi bu).

-- ══════════════════════════════════════════════════════════════════════════════
-- 9) "Firma 56 ne, muhasebeden bak" — kimlik + muhasebe konumu (08.09.2026)
-- ══════════════════════════════════════════════════════════════════════════════

-- 9a) Kimlik: iki kart, aynı VN
SELECT frmID, frmKod, frmAd, frmAd2, frmTip, VD, VN, kTarih
FROM dbo.frm WHERE VN='1910376739';
--  56    320.10.B010     BURSA KÜLTÜR MERKEZİ KİTAP KIRTASİYE GIDA / SAN.TİC.LTD.ŞTİ  frmTip=0
-- 38093  1910376739      (aynı ünvan, tam yazım)                                       frmTip=1
-- ⇒ frmKod bir MUHASEBE HESAP KODU (320 = Satıcılar). VD SETBAŞI / Bursa.

-- 9b) Defterin sahibi kim (firma 56 değil!)
SELECT sirketID, sirketAd, sirketDonem FROM mhs.mhsSirket ORDER BY sirketID;
-- sirketID = MALİ YIL dönemi. 6='BKM Kitap Kırtasiye' (2026), 5=(2025), 4=(2024)…
-- ⇒ Defter 'BKM Kitap Kırtasiye'ye ait; firma 56 AYRI tüzel kişi (grup şirketi).

-- 9c) Muhasebe konumu: hangi hesaplarda duruyor
SELECT HspKod, HspAd, SirketID FROM mhs.mhsHesapPlani_vw
WHERE SirketID=6 AND HspAd LIKE '%Bursa Kültür%';
-- 320.10.B010  Bursa Kültür Merkezi Kitap Kırtasiye Gıda San.Ltd.  (320.10 = YURT İÇİ SATICILAR)
-- 159.10.B003  Bursa Kültür Merkezi Kitap Kırtasiye Gıda San.Ltd.  (159 = Verilen Sipariş Avansları)
-- ⚠ ALICI (120) kartı YOK — ama ona satış yapılıyor (bkz. 9e: 600.10.009'a yazılıyor).

-- 9d) Bakiye + hareket hacmi (2026, 8 ay)
SELECT hspKod, SUM(Borc) AS borc, SUM(Alacak) AS alacak, COUNT(*) AS satir
FROM mhs.mhsFis_vw WHERE fisSirketID=6 AND hspKod IN ('320.10.B010','159.10.B003')
GROUP BY hspKod;
-- 320.10.B010: borç 773.530.270,65 / alacak 799.014.878,16 / 1.601 satır → net borç 25,48M ₺
-- 159.10.B003: borç 556.644.260,79 / alacak 267.860.992,62 /     5 satır → net AVANS 288,78M ₺
-- ⚠ mizanda `hspKod LIKE '320.10.B010%'` ile 187 satır görünür (mhsMizan_vw ay-sonu özet);
--   fiş bazlı tam eşitlik 1.601 satır. Hacim kıyası fiş bazından yapılır.

-- 9e) Karşı hesaplar — 799M'in ne olduğunu bu söylüyor
SELECT TOP 12 k.hspKod, MAX(k.hspAd) AS hspAd, SUM(k.Borc) AS borc, SUM(k.Alacak) AS alacak, COUNT(*) AS satir
FROM mhs.mhsFis_vw k
WHERE k.fisSirketID=6
  AND k.fisID IN (SELECT fisID FROM mhs.mhsFis_vw WHERE fisSirketID=6 AND hspKod='320.10.B010')
  AND k.hspKod <> '320.10.B010'
GROUP BY k.hspKod ORDER BY SUM(k.Borc)+SUM(k.Alacak) DESC;
-- 102.10.* bankalar (Akbank/Alternatif/Halk/Şeker/Garanti/YapıKredi/İş) — ödemeler
-- 600.10.009 'Yurtiçi Satışlar %20' alacak 13.725.693,32 / 250 satır → satış GERÇEK hasılat
-- 320.10.B087 Beta Kitap · 320.10.P011 Promarka → aynı fişte başka satıcılar (toplu ödeme fişi;
--    bu tutarlar 320.10.B010'a AİT DEĞİL — fiş-ortaklığından geliyor, karıştırma).

-- 9f) Hacmin yarısı ticari değil: 320/159 virman
SELECT TOP 12 fisTarih, yevmiyeNo, fisTip, Borc, Alacak, fisAciklama
FROM mhs.mhsFis_vw WHERE fisSirketID=6 AND hspKod='320.10.B010'
ORDER BY ABS(Alacak)+ABS(Borc) DESC;
-- En büyükler: '320/159 HESAP VİRMAN' 288.783.268 (30.06.2026) · 202.548.584 (31.03.2026) + ters yönü
SELECT COUNT(*) AS satir, SUM(ABS(Borc)) AS borc_abs, SUM(ABS(Alacak)) AS alacak_abs
FROM mhs.mhsFis_vw WHERE fisSirketID=6 AND hspKod='320.10.B010' AND fisAciklama LIKE '%VİRMAN%';
-- 19 satır / 268,06M borç + 497,14M alacak = 765,2M ₺ → toplam hareketin %48,7'si SADECE VİRMAN.

-- 9g) Mal akışı iki yönlü mü (fatura bazında)
SELECT f.eTip, COUNT(DISTINCT f.eID) AS belge, SUM(a.ehAdetN) AS adet, SUM(a.ehTutarN) AS net_tutar
FROM dbo.fat f JOIN dbo.fatAyr a ON a.ehID=f.eID
WHERE f.eFirma=56 AND f.eTarih>='20250908' AND f.eTarih<'20260908'
GROUP BY f.eTip ORDER BY f.eTip;
-- 0 Alış      1.008 belge / +1.447.008 ad / 52.006.491 ₺
-- 1 Satış       498 belge / −1.384.130 ad / 35.816.677 ₺
-- 2 Alış İade    52 / −149.763 · 10 İade Fark Fat. 124 / −141.235 · 8 Fiyat Farkı 52 / −71.474
-- ⇒ NET +62.878 adet BİZE giriş. Tutarda alış > satış.

-- 9h) Aynı ürün mü gidip geliyor (saf döngü testi — DEĞİL)
SELECT COUNT(*) AS cesit_toplam,
       SUM(CASE WHEN alis>0 AND satis>0 THEN 1 ELSE 0 END) AS iki_yonlu_cesit,
       SUM(CASE WHEN alis>0 AND satis>0 THEN satis ELSE 0 END) AS iki_yonlu_satis_adet,
       SUM(satis) AS satis_adet, SUM(alis) AS alis_adet
FROM (SELECT a.ehStkID,
             SUM(CASE WHEN f.eTip=0 THEN  a.ehAdetN ELSE 0 END) AS alis,
             SUM(CASE WHEN f.eTip=1 THEN -a.ehAdetN ELSE 0 END) AS satis
      FROM dbo.fat f JOIN dbo.fatAyr a ON a.ehID=f.eID
      WHERE f.eFirma=56 AND f.eTip IN (0,1) AND f.eTarih>='20250908' AND f.eTarih<'20260908'
      GROUP BY a.ehStkID) t;
-- 11.093 çeşit; yalnız 1.368'i iki yönlü (400.266 ad = satışın %29'u) → %71 TEK YÖNLÜ çıkış.

-- SONUÇ: firma 56 = grup şirketi; ilişki hem ticari (iki yönlü mal) hem finansal (288,78M avans).
-- Sezon/alım analizinde bu çıkış TÜKETİCİ TALEBİ DEĞİL → ayrı gösterilir.
-- Grup-dışı merkez çıkışı ≈ ODAK 302.908 + SINAV 110.100 + diğer ≈ 528K adet (1,90M'in %28'i).

-- ══════════════════════════════════════════════════════════════════════════════
-- 10) TERS MÜHENDİSLİK — raporun 26 kolonu hangi kaynaktan geliyor
--     Üretici script: scripts/satis_analizi_excel.py
-- ══════════════════════════════════════════════════════════════════════════════

-- 10a) Metin/kategori/fiyat kolonları -> bkm.UrunBilgi
--      DİKKAT: Kategori1 = KatAna · Yayinevi = mrkAd (marka). FirmaAd DEĞİL
--      (FirmaAd = ana tedarikçi; stkID 101'de 'ODAK KİTAP-POİNT', raporda 'Edebiyat Dergisi Yayınları').
SELECT u.stkID, u.BarkodAna, u.stkAd, u.Yazar, u.mrkAd AS Yayinevi, u.FirmaAd,
       u.KatAna AS Kategori1, u.Kategori3, u.SatisFiyat
FROM bkm.UrunBilgi u WHERE u.stkID IN (101,103,1590653,1672852);
-- 4/4 birebir (mrkAd: 'Edebiyat Dergisi Yayınları' / 'The Edd' / 'Bricks Lego').

-- 10b) IlkGirisTarihi = ürünün ilk stok hareketi (UrunBilgi.gTarih DEĞİL)
SELECT u.stkID, u.gTarih, mn.ilk_hrk
FROM bkm.UrunBilgi u
OUTER APPLY (SELECT MIN(h.ehTrhS) AS ilk_hrk FROM dbo.irsHrk h WHERE h.ehstkID=u.stkID) mn
WHERE u.stkID IN (101,103,1590653,1672852);
-- Rapor 101 -> 2021-05-31 = MIN(ehTrhS). gTarih 2014-07-18 (eşleşmiyor) → gTarih değil.

-- 10c) Satış tanımı — SEZON AYLARIYLA test edilir (geçmiş-sabit, pencere belirsizliği yok)
--      Aday tip kümeleri karşılaştırıldı; kazanan (1,3,4,5,100,101):
--        irsHrk  (100,101)          29/75
--        irsHrk  (100,101,4,5)      73/75
--        irsHrk  (1,3,4,5,100,101)  75/75  ✔
--        Encore  (1,2,3)            23/75
--        Encore  (1,2,3,6,7,8)      63/75
SELECT h.ehstkID AS stkID, h.ehMekan,
       -SUM(CASE WHEN h.ehTrhS >= '20250801' AND h.ehTrhS < '20250901' THEN h.ehAdetN ELSE 0 END) AS Ay_2025_08,
       -SUM(CASE WHEN h.ehTrhS >= '20250901' AND h.ehTrhS < '20251001' THEN h.ehAdetN ELSE 0 END) AS Ay_2025_09,
       -SUM(CASE WHEN h.ehTrhS >= '20251001' AND h.ehTrhS < '20251101' THEN h.ehAdetN ELSE 0 END) AS Ay_2025_10
FROM dbo.irsHrk h
WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
  AND h.ehTrhS >= '20250801' AND h.ehTrhS < '20251101'
GROUP BY h.ehstkID, h.ehMekan;
-- ⇒ Satis_FSM/OZLUCE/ISTYOLU aynı tanımın mekan kırılımı; 365g pencere de bu tip kümesiyle.

-- 10d) Evren filtresi: Kategori3 12-değer listesi (LİSTE ELLE YAZILMADI — ölçüldü)
SELECT Kategori3, COUNT(*) AS cesit FROM bkm.UrunBilgi GROUP BY Kategori3 ORDER BY 2 DESC;
-- 22 değer var. Raporda olan 12: Kitap · Kırtasiye · Oyuncak · Çocuk Kitabı · Hazırlık Kitapları
--   · Akademi · Hediyelik · Elektronik · Dergi · Spor & Outdoor · Kafe Hammede · Zkargo
-- Hariç 10: Sınav Kayıt · Tanımsız · Sınav Okulları · Gıda · Sınav Kıyafet · Kişisel Bakım
--   · Genel · Etkinlik · Hediye Çeki · KARGO   (⚠ 'Zkargo' dahil ama 'KARGO' hariç — liste bu)
SELECT stkID, Kategori3 FROM bkm.UrunBilgi
WHERE Kategori3 NOT IN ('Kitap','Kırtasiye','Oyuncak','Çocuk Kitabı','Hazırlık Kitapları',
                        'Akademi','Hediyelik','Elektronik','Dergi','Spor & Outdoor',
                        'Kafe Hammede','Zkargo');
-- 59.826 çeşit döner; bunların **0'ı** rapordaki 273.515 stkID kümesinde → filtre kesin.
-- Kaçan satılabilir ürün: ıslak mendil ('Kişisel Bakım', WMS'te ~366K adet).

-- 10e) İkinci filtre: en az bir stok/satış/sezon/odak değeri sıfırdan farklı
--      (rapordaki "her yerde sıfır" satır sayısı = 0; ölçüldü)

-- 10f) NEDEN BİREBİR YENİDEN ÜRETİLEMEZ
--   · Stok kolonları ANLIK: stokSonAltDepo_vw ve depo.stok_adres_palet_vw geçmiş snapshot TUTMAZ.
--     (Aylık snapshot yalnız bkm.StokAyBakiyeMekanBazli'da, ay-sonu granülünde.)
--   · 365g pencere 07.09.2026 GÜN ORTASI kesilmiş (dosya damgası 12:32) → son gün kısmi.
--     En çok satan 25 üründe pencere taraması en iyi 3/25 tam eşleşme verdi; sapma ±%0,5
--     ve tip kümesinden DEĞİL pencereden geliyor (sezon ayları aynı tanımla 75/75 tutuyor).
--   · Sezon ayları geçmiş-sabit → her koşuda birebir aynı çıkar.

-- 10g) DÜZELTME — IlkGirisTarihi ilk tahminim YANLIŞTI (4/4 örnek yanılttı)
--      4 üründe MIN(ehTrhS) tuttu diye "tanım bu" dedim; 273.443 üründe test edilince %72,4.
--      Sapma TEK YÖNLÜ: benim MIN'im 75.435/75.435 vakada daha ERKEN → rapor daha DAR kümede
--      MIN alıyor (açılış/sayım kaydını dışarıda bırakıyor).
SELECT ehstkID AS stkID,
  MIN(CASE WHEN ehAdetN>0 AND ehMekan IN (1,4477,4478) THEN ehTrhS END)     AS B_giris_mgz,
  MIN(CASE WHEN ehMekan IN (1,4477,4478) THEN ehTrhS END)                  AS D_mgz_hepsi,
  MIN(CASE WHEN ehAdetN>0 THEN ehTrhS END)                                 AS F_giris_tum,
  MIN(CASE WHEN ehTip IN (0,10,13) AND ehMekan IN (1,4477,4478) THEN ehTrhS END) AS C_alis_depomag,
  MIN(CASE WHEN ehTip IN (0,10) AND ehMekan IN (1,4477,4478) THEN ehTrhS END)    AS A_alis_mgz,
  MIN(CASE WHEN ehTip IN (0,10) THEN ehTrhS END)                           AS E_alis_tum,
  MIN(ehTrhS)                                                              AS G_hepsi
FROM dbo.irsHrk GROUP BY ehstkID;
-- 400 ürünlük rastgele örnekte eşleşme (rapordaki değere karşı):
--   B_giris_mgz     399/400  %99,8  ✔ KAZANAN
--   D_mgz_hepsi     396/400  %99,0
--   F_giris_tum     306/400  %76,5
--   C_alis_depomag  224/400  %56,0
--   A_alis_mgz      164/400  %41,0
--   E_alis_tum      139/400  %34,8
--   G_hepsi         (273.443 üründe %72,4)
-- ⇒ IlkGirisTarihi = ürünün MAĞAZAYA ilk GİRİŞİ: MIN(ehTrhS) WHERE ehAdetN>0
--   AND ehMekan IN (1,4477,4478). Merkez depoya giriş ve açılış/sayım kaydı SAYILMAZ.
-- DERS (olctum-mu-cikardim-mi): 4 örnekte tutan bir eşleme "tanım" değildir; tüm
--   evrende ölçülmeden yazılmaz. Geçmiş-sabit kolonlarda %100 beklenir — %72 gördüğümde
--   bunu drift sanmak yerine tanım hatası olarak ele almak doğru çıktı.

-- 10h) DÜZELTME 2 — pencere BİR GÜN kaymıştı + mağaza stoğu CANLI view'dan alınmıştı
--      Kullanıcı uyarısı: "wms dışındakiler birebir olmalı". Haklı çıktı, iki hata bulundu.

-- (i) ehTrhS SAAT TAŞIMIYOR → pencere tam-gün, kısmi gün yok
SELECT COUNT(*) AS satir,
       SUM(CASE WHEN CONVERT(time, ehTrhS) <> '00:00:00' THEN 1 ELSE 0 END) AS saatli
FROM dbo.irsHrk WHERE ehTrhS >= '20260901';
-- 136.217 satırın 0'ı saatli → sınır günü tamamen içeride ya da tamamen dışarıda.

-- (ii) Satış penceresi: rapor tarihinin BİR GÜN ÖNCESİNE kadar
SELECT ehstkID AS stkID,
  -SUM(CASE WHEN ehTrhS>='20250907' AND ehTrhS<='20260906' THEN ehAdetN ELSE 0 END) AS w_0709_0609,
  -SUM(CASE WHEN ehTrhS>='20250908' AND ehTrhS<='20260906' THEN ehAdetN ELSE 0 END) AS w_0809_0609,
  -SUM(CASE WHEN ehTrhS>='20250908' AND ehTrhS<='20260907' THEN ehAdetN ELSE 0 END) AS w_0809_0709
FROM dbo.irsHrk
WHERE ehMekan IN (1,4477,4478) AND ehTip IN (1,3,4,5,100,101)
GROUP BY ehstkID;
-- 400 ürünlük örnek, rapordaki Satis_Toplam'a karşı tam eşleşme:
--   07.09.2025–06.09.2026  393/400  %98,2  ✔ (365 gün dahil)
--   08.09.2025–06.09.2026  369/400  %92,2
--   08.09.2025–07.09.2026  364/400  %91,0   <- benim ilk varsayımım
-- ⇒ 07.09.2026 tarihli raporu üretmek için: --bitis 2026-09-06

-- (iii) Mağaza stoğu: CANLI view yerine HAREKET DEFTERİNDEN as-of
--       stokSonAltDepo_vw ANLIK -> geçmiş tarih için yanlış; script tekrar-üretilebilir olmaz.
SELECT ehstkID AS stkID,
  SUM(CASE WHEN ehMekan=1    AND ehTrhS<='20260906' THEN ehAdetN ELSE 0 END) AS fsm06,
  SUM(CASE WHEN ehMekan=1    AND ehTrhS<='20260907' THEN ehAdetN ELSE 0 END) AS fsm07,
  SUM(CASE WHEN ehMekan=4477 AND ehTrhS<='20260906' THEN ehAdetN ELSE 0 END) AS ozl06,
  SUM(CASE WHEN ehMekan=4478 AND ehTrhS<='20260906' THEN ehAdetN ELSE 0 END) AS ist06
FROM dbo.irsHrk GROUP BY ehstkID;
-- 400 ürün, kesim 06.09: defter %99,2 (397/400) · canlı view %98,1. 07.09 kesimi %98,5.
-- Rapor değeri 06.09-sonu ile 07.09-sonu ARASINDA: FSM 400/400 · ÖZL 399/400 · İST 398/400
-- ⇒ Raporun STOK kesimi 07.09 12:32 (dosya damgası, canlı view); SATIŞ kesimi 06.09.
--   Orijinal raporda iki farklı kesim noktası var — bu onun kendi tutarsızlığı.
--   Yeniden üretimde tek as-of kullanılır (deterministik): --bitis <son kapalı gün>.

-- DERS: "birebir olmalı" uyarısı iki hatayı çıkardı. Anlık view kullanmak bir scripti
-- sessizce tekrar-üretilemez yapar; pencere sınırı da örnekle değil TÜM evrende ölçülmeli.

-- (iv) KALAN SAPMANIN KAYNAĞI — 07.09'da hareket gören ürünler
SELECT ehstkID AS stkID FROM dbo.irsHrk
WHERE ehMekan IN (1,4477,4478) AND ehTrhS = '20260907' GROUP BY ehstkID;
-- 9.644 ürün. Düzeltilmiş üretimde uyuşmayan ürünlerin ne kadarı bu kümede:
--   Stok_FSM      1.069 uyuşmaz → 1.066 hareketli (%99,7)
--   Stok_OZLUCE   1.636 → 1.635 (%99,9)
--   Stok_ISTYOLU  1.548 → 1.383 (%89,3)
--   Satis_FSM     1.000 →   999 (%99,9)
--   Satis_OZLUCE  1.582 → 1.574 (%99,5)
--   Satis_ISTYOLU 1.265 → 1.204 (%95,2)
--   Satis_Toplam  3.299 → 3.230 (%97,9)
--   ToplamStok    4.374 → 3.583 (%81,9)  ← içinde MerkezStok (WMS) var, o ayrı sebep
-- ⇒ Sapma raporun gün-ortası kesiminden; tanımdan DEĞİL.
-- ⚠ İst.Yolu'nda küçük açıklanamayan artık (165 stok / 61 satış): İst.Yolu eTip 4
--   (Mağaza Satış / Sınav faturaları) taşıyor ve irs kayıtları gün içinde yeniden
--   yazılabiliyor (sema: "Değeri gördüm, tarihini görmedim"). Teyit bekliyor.
