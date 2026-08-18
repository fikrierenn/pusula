/*
  Soru: 2025'te yevmiye fiş sayısı neden %95 çöktü (2024: 2,69M fiş → 2025: 123K)?
        Posting değişikliği mi, iş değişikliği mi?
  DB: DerinSISBkm. Tetik: 2026-08-17/18 şirket-dönem kontrolünün yan bulgusu.

  CEVAP: GL posting değişikliği DEĞİL — KAYNAK BELGE (satış faturası) kesilmeyi bıraktı.
  Kırılma tarihi: Ocak 2025 geçiş, ŞUBAT 2025'te tamamlanmış.

  KANIT ZİNCİRİ:
   1) mhs.mhsFisBaslik aylık: Ara'24 251.813 fiş → Oca'25 44.589 → Şub'25 7.123 (sonra ~5-8K plato).
   2) Kırılan entegrasyon tipi (mhs.mhsEntTip): 1=Fatura 409.224→6.297 (−%98,5) ·
      2=Cari 397.014→15.541 (−%96,1) · 3=POS 1.214→1.181 (DEĞİŞMEDİ, zaten özet) · 0=Kullanıcı 103→55.
   3) Giren kişi AYNI (Pınar/Şule/pinar.muhasebe1-2) → personel/yetki değişikliği DEĞİL.
   4) KAYNAK BELGE çöküşü — dbo.fat: SATIŞ faturası (eTip=1) Ara'24 122.145 → Şub'25 104.
      ALIŞ faturası (eTip=0) SABİT ~1.000-1.100/ay → alım tarafı etkilenmemiş.
   5) Ara'24'teki 122.145 satış faturasının TAMAMI eMekan=12 (MERKEZ DEPO) = e-ticaret sevk faturası.
   6) dbo.car cari hareket: 382.563 → 13.011 (aynı oran).
   7) irsHrk stok tarafı: sevk/fatura satışı (ehTip 1/4) Ara'24 94,9M ₺ → Şub'25 4,9M ₺;
      POS (ehTip 100) SABİT (41,0M → 38,5M → 33,1M → 37,2M) → MAĞAZA satışı devam ediyor.

  SONUÇ: Şubat 2025'te e-ticaret/depo-sevk faturalama BKM Kitap tüzel kişisinden çıktı.
  Mağaza POS satışı DerinSIS'te devam; e-ticaret fatura kanalı DerinSIS'te YOK.
  (Grup içi yeniden yapılandırma hipotezi: ilişkili taraf frmID 9525 ODAK KİTAP-POİNT alımı
   2024 217M → 2025 308M ₺ ile aynı döneme denk geliyor — NEDENSELLİK TEYİT EDİLMEDİ, GMY doğrulayacak.)

  ETKİLERİ (kritik):
   A) GL forensic (B-117): 2024 ile 2025+ satır-sayısı temelli hiçbir metrik kıyaslanamaz
      (Benford, mükerrer, anomali yoğunluğu, SoD). Yıl-kırılımı ZORUNLU.
   B) Satış/talep modelleri (B-139 "2024↔2025 vahşi sezon-ayrışması"): 2024 irsHrk satışı
      e-ticaret sevkini İÇERİR, Şub'25 sonrası İÇERMEZ → "2024'te 417 sattı, 2025'te 17" gibi
      çöküşler ÜRÜN TALEBİ DEĞİL KANAL KAYBI olabilir. Satınalma retail-momentum + bulunurluk
      son12/son24 pencereleri bu kırılmayı aşıyorsa YANILTICI.
   C) 2025+ ciro analizinde e-ticaret DerinSIS'ten gelmez → JOKER doğrudan okunmalı (dashboard zaten böyle).
*/

-- 1) Yevmiye fiş başlığı aylık (kırılma tarihini bul)
SELECT YEAR(b.fisTarih)*100 + MONTH(b.fisTarih) AS yilay, COUNT(*) AS fis_basligi
FROM mhs.mhsFisBaslik b WITH(NOLOCK)
WHERE b.fisTarih >= '20240601' AND b.fisTarih < '20260901'
GROUP BY YEAR(b.fisTarih)*100 + MONTH(b.fisTarih)
ORDER BY 1;

-- 2) Hangi entegrasyon tipi kırıldı? (lookup: mhs.mhsEntTip → 0 Kullanıcı·1 Fatura·2 Cari·3 POS·4 Mağaza Kasası·5 Cari Fiş)
SELECT CASE WHEN b.fisTarih < '20250101' THEN '1_2024Q4' ELSE '2_2025Q1' END AS donem,
       b.fisEntTipID, e.entTipAd, COUNT(*) AS fis
FROM mhs.mhsFisBaslik b WITH(NOLOCK)
LEFT JOIN mhs.mhsEntTip e WITH(NOLOCK) ON e.entTipID = b.fisEntTipID
WHERE (b.fisTarih >= '20241001' AND b.fisTarih < '20250101')
   OR (b.fisTarih >= '20250201' AND b.fisTarih < '20250501')
GROUP BY CASE WHEN b.fisTarih < '20250101' THEN '1_2024Q4' ELSE '2_2025Q1' END,
         b.fisEntTipID, e.entTipAd
ORDER BY 1, COUNT(*) DESC;

-- 3) Giren kişi değişti mi? (aynı kişilerse personel/yetki sebebi ELENİR)
SELECT CASE WHEN b.fisTarih < '20250101' THEN '1_2024Q4' ELSE '2_2025Q1' END AS donem,
       b.fisEntTipID, b.gKisi, k.insAd, COUNT(*) AS fis
FROM mhs.mhsFisBaslik b WITH(NOLOCK)
LEFT JOIN dbo.drn1 k WITH(NOLOCK) ON k.insID = b.gKisi
WHERE ((b.fisTarih >= '20241001' AND b.fisTarih < '20250101')
    OR (b.fisTarih >= '20250201' AND b.fisTarih < '20250501'))
  AND b.fisEntTipID IN (1,2)
GROUP BY CASE WHEN b.fisTarih < '20250101' THEN '1_2024Q4' ELSE '2_2025Q1' END,
         b.fisEntTipID, b.gKisi, k.insAd
ORDER BY 1, COUNT(*) DESC;

-- 4) KÖK SEBEP: kaynak belge (satış faturası) çöküşü — alış SABİT, satış SIFIRA yakın
SELECT YEAR(f.eTarihS)*100 + MONTH(f.eTarihS) AS yilay,
       COUNT(*) AS fatura,
       SUM(CASE WHEN f.eTip = 0 THEN 1 ELSE 0 END) AS alis,
       SUM(CASE WHEN f.eTip = 1 THEN 1 ELSE 0 END) AS satis
FROM dbo.fat f WITH(NOLOCK)
WHERE f.eTarihS >= '20240901' AND f.eTarihS < '20250701'
GROUP BY YEAR(f.eTarihS)*100 + MONTH(f.eTarihS)
ORDER BY 1;

-- 5) Kaybolan satış faturaları hangi mekandan? (Ara'24: %100 Merkez Depo = e-ticaret sevk)
SELECT f.eMekan, m.mekanAd, COUNT(*) AS satis_faturasi
FROM dbo.fat f WITH(NOLOCK)
LEFT JOIN dbo.mekan_vw m WITH(NOLOCK) ON m.mekanID = f.eMekan
WHERE f.eTarihS >= '20241201' AND f.eTarihS < '20250101' AND f.eTip = 1
GROUP BY f.eMekan, m.mekanAd
ORDER BY COUNT(*) DESC;

-- 6) Cari hareket aynı oranda düştü mü?
SELECT YEAR(c.cTarih)*100 + MONTH(c.cTarih) AS yilay, COUNT(*) AS cari_hareket
FROM dbo.car c WITH(NOLOCK)
WHERE c.cTarih >= '20240901' AND c.cTarih < '20250701'
GROUP BY YEAR(c.cTarih)*100 + MONTH(c.cTarih)
ORDER BY 1;

-- 7) STOK TARAFI KANITI: POS devam, sevk/fatura çöktü (talep düşüşü DEĞİL, kanal kaybı)
SELECT YEAR(h.ehTrhS)*100 + MONTH(h.ehTrhS) AS yilay,
       SUM(CASE WHEN h.ehTip IN (1,4,100) THEN h.ehTutarN ELSE 0 END) AS satis_net,
       SUM(CASE WHEN h.ehTip = 100        THEN h.ehTutarN ELSE 0 END) AS pos_net,
       SUM(CASE WHEN h.ehTip IN (1,4)     THEN h.ehTutarN ELSE 0 END) AS sevk_fatura_net
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehTrhS >= '20241101' AND h.ehTrhS < '20250501' AND h.ehAltDepo = 0
GROUP BY YEAR(h.ehTrhS)*100 + MONTH(h.ehTrhS)
ORDER BY 1;

/* ---------------------------------------------------------------------------
   8) KESİM TARİHİ — günlük satış faturası, Ocak 2025
   GMY TEYİDİ (2026-08-18): 06.01.2025'te e-ticaret faturalama POINT'e DEVREDİLDİ.
   Veri deseni: 06.01 hâlâ PİK (4.614 = BKM'de kesilen son yığın) → kuyruk 07-15.01
   (2.518 → 419 → 14.01'de 1.345 toplu kapanış → 160) → 16.01'den pratik SIFIR (29 → tek haneli).
   KURAL: analitik pencere başlangıcı = 01.02.2025 (ilk tam temiz ay).
          Ocak 2025 HİBRİT AY — YoY/MoM kıyasa KATMA.
--------------------------------------------------------------------------- */
SELECT CONVERT(varchar, CAST(f.eTarihS AS date), 104) AS gun, COUNT(*) AS satis_faturasi
FROM dbo.fat f WITH(NOLOCK)
WHERE f.eTarihS >= '20250101' AND f.eTarihS < '20250201' AND f.eTip = 1
GROUP BY CAST(f.eTarihS AS date)
ORDER BY CAST(f.eTarihS AS date);

/* ---------------------------------------------------------------------------
   9) KIRILMANIN KATEGORİ DAĞILIMI — kim etkilendi?
   Depo sevk (ehMekan=12, ehTip 1/4), aylık normalize:
     KİTAP vb.                     74,54M ₺/ay → 4,13M ₺/ay   (−%94,5)  ← kırılma BURADA
     KIRTASİYE/OYUNCAK/HEDİYELİK   3,63M ₺/ay  → 3,43M ₺/ay   (−%5,5, DÜZ)
   → Kat3 10/12/16 evreninde mekan-12 akışı e-ticaret DEĞİL, TOPTAN sevk (kırılmada düşmedi).
   → Satınalma Alım Analizi evreni MUAF; B-139 (matara/ajanda) bu kırılmayla AÇIKLANMIYOR.
--------------------------------------------------------------------------- */
SELECT CASE WHEN h.ehTrhS < '20250116' THEN '1_ONCE_6.5ay' ELSE '2_SONRA_18.5ay' END AS donem,
       CASE WHEN u.Kat3ID IN (10,12,16) THEN 'KIRTASIYE_OYUNCAK_HEDIYELIK' ELSE 'DIGER_(KITAP_vb)' END AS evren,
       SUM(CASE WHEN h.ehMekan = 12 THEN h.ehTutarN ELSE 0 END)                 AS depo_sevk_tutar,
       SUM(CASE WHEN h.ehMekan IN (1,4477,4478) THEN h.ehTutarN ELSE 0 END)     AS sube_tutar
FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
LEFT JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = h.ehstkID
WHERE h.ehTip IN (1,4) AND h.ehTrhS >= '20240701' AND h.ehTrhS < '20260801'
GROUP BY CASE WHEN h.ehTrhS < '20250116' THEN '1_ONCE_6.5ay' ELSE '2_SONRA_18.5ay' END,
         CASE WHEN u.Kat3ID IN (10,12,16) THEN 'KIRTASIYE_OYUNCAK_HEDIYELIK' ELSE 'DIGER_(KITAP_vb)' END
ORDER BY 1, 2;
