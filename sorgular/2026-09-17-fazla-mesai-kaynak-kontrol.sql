/* ============================================================================
   FAZLA MESAİNİN KAYNAĞI ve KONTROL EDİLEBİLİRLİĞİ (2026-09-17)
   Soru : "ne kadarı fazla çalışmadan, ne kadarı izin iptalinden" +
          "kapanış anonsu yasak, müşteri bitene kadar bekleniyor — ne kadarı
           mağazanın elinde?" (GMY)
   DB   : BkmPanel (bkm.Vrd_KisiGun) + EncoreMerkez (LIVE201 linked server)
   ============================================================================ */

/* 1) KAYNAK KIRILIMI — dönem içi 4.822,1 saat (devir hariç)
      YÖNETİM POLİTİKASI 2.505,7 sa (%52): izin iptali 1.125,7 + hafta tatili 1.380,0
      OPERASYON          2.316,3 sa (%48): plan üstü 2.232,9 + plansız 83,4 */
SELECT FazlaCalisma = SUM(FazlaCalismaDk)/60.0, IzinIptal = SUM(FazlaIzinIptalDk)/60.0,
       HaftaTatili  = SUM(HaftalikPrimDk)/60.0, Plansiz   = SUM(FazlaPlansizDk)/60.0,
       CikisSonrasi = SUM(CikisSonrasiDk)/60.0, GirisOncesi = SUM(GirisOncesiDk)/60.0
FROM   bkm.Vrd_KisiGun WHERE KesimBit = '2026-09-16';

/* 2) KAPANIŞ VARDİYASI — ÖLÇEK ETKİSİ (GMY: "20 dk geç kapanan şubede 35-40
      personel varsa günde 800 dk, 15 günde 200 saat")
      ⭐ TAHMİN BİREBİR TUTTU: İst.Yolu 33,3 kişi/gün × ort 30 dk → 16 günde 170,1 saat.
      Kısa gecikme ÖNEMSİZ DEĞİLDİR — kişi sayısıyla çarpılır. */
SELECT Sube,
       kisiGun       = COUNT(*),
       gun           = COUNT(DISTINCT Tarih),
       kisiGunlukOrt = COUNT(*) * 1.0 / NULLIF(COUNT(DISTINCT Tarih), 0),
       kalanKisiGun  = SUM(CASE WHEN ISNULL(CikisSonrasiDk,0) > 0 THEN 1 ELSE 0 END),
       ortGecikmeDk  = AVG(CASE WHEN ISNULL(CikisSonrasiDk,0) > 0 THEN CikisSonrasiDk END),
       toplamSa      = SUM(ISNULL(CikisSonrasiDk,0))/60.0
FROM   bkm.Vrd_KisiGun
WHERE  KesimBit = '2026-09-16' AND SayimDisi = 0
   AND PlanBitisDk >= 1260            -- kapanış vardiyası = plan bitişi >= 21:00
GROUP BY Sube ORDER BY SUM(ISNULL(CikisSonrasiDk,0)) DESC;

/* 3) MAĞAZA KAPANIŞ SAATİ — anons yasağının izi
      Son fiş ortalaması 22:02-22:10, plan bitişi 22:00. Yani mağaza planlanandan
      SONRA kapanıyor ve bu bir POLİTİKA sonucudur, personel tercihi değil. */
SELECT * FROM OPENQUERY(LIVE201, '
  SELECT Magaza = st.Name,
         Gun = COUNT(DISTINCT CONVERT(date, s.Date)),
         SonFisOrtDk = AVG(x.sonDk), SonFisEnGecDk = MAX(x.sonDk), SonFisEnErkenDk = MIN(x.sonDk)
  FROM (SELECT StoresId, Gun = CONVERT(date, Date),
               sonDk = DATEPART(hour, MAX(Date))*60 + DATEPART(minute, MAX(Date))
        FROM EncoreMerkez.dbo.Sales
        WHERE Date >= ''20260901'' AND Date < ''20260917''
          AND DocumentsTypeId IN (1,2,3,6,7,8)
        GROUP BY StoresId, CONVERT(date, Date)) x
  JOIN EncoreMerkez.dbo.Sales s ON s.StoresId = x.StoresId
  JOIN EncoreMerkez.dbo.Stores st ON st.Id = x.StoresId
  GROUP BY st.Name') y;

/* 4) ⭐ YOĞUNLUK TESTİ — GMY iddiası: "gündüzde de yoğun olduğu için mağaza
      personeli mecburen kalmaya devam ediyor"
      ÖLÇÜLDÜ (şube-gün, 16 gün): fiş sayısı ↔ fazla çalışma korelasyonu
          FSM 0,86 · İST.YOLU 0,82 · ÖZLÜCE 0,76
      Medyan altı → medyan üstü gün:
          FSM 10,2 → 23,8 sa (2,3×) · İST.YOLU 15,8 → 42,6 (2,7×) · ÖZLÜCE 15,8 → 26,2 (1,7×)
      ⇒ Fazla mesai TALEBE bağlı hareket ediyor; "personel fazla kalıyor" okuması
        veriyle desteklenmiyor.
      ⚠ SINIR: korelasyon nedensellik değildir. Yoğun gün aynı zamanda sezon günü
        ve kadro da o gün aynı — confound giderilmedi. Yön ve büyüklük net, atıf değil. */
SELECT k.Sube, k.Tarih, f.Fis,
       fazlaSa = SUM(ISNULL(k.FazlaCalismaDk,0))/60.0,
       kisiGun = COUNT(*)
FROM   bkm.Vrd_KisiGun k
JOIN  (SELECT * FROM OPENQUERY(LIVE201, '
         SELECT Magaza = st.Name, Gun = CONVERT(date, s.Date), Fis = COUNT(*)
         FROM EncoreMerkez.dbo.Sales s
         JOIN EncoreMerkez.dbo.Stores st ON st.Id = s.StoresId
         WHERE s.Date >= ''20260901'' AND s.Date < ''20260917''
           AND s.DocumentsTypeId IN (1,2,3,6,7,8)
         GROUP BY st.Name, CONVERT(date, s.Date)')) f
       ON f.Magaza = CASE k.Sube WHEN N'FSM'        THEN N'FSM Mağaza'
                                 WHEN N'ÖZLÜCE'     THEN N'ÖZLÜCE'
                                 WHEN N'İST. YOLU'  THEN N'IST YOLU MGZ' END
      AND f.Gun = k.Tarih
WHERE  k.KesimBit = '2026-09-16' AND k.SayimDisi = 0
GROUP BY k.Sube, k.Tarih, f.Fis
ORDER BY k.Sube, k.Tarih;

/* ⚠ KAFELER · HEYKEL · ŞURA · GENEL MÜDÜRLÜK bu testin DIŞINDA — o şubelerde POS
   fişi yok ya da Stores eşlemesi kurulmadı. "Ölçemedim", "etkisi yok" DEĞİL. */
