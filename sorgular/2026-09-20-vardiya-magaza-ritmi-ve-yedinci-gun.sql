/* =============================================================================
   VARDİYA — MAĞAZANIN GERÇEK RİTMİ ve "YEDİNCİ GÜN"
   DB: BkmPanel (DEV — BT-FIKRI\SQLEXPRESS).  Ölçüm: 20.09.2026
   Kesim: 31.08–16.09.2026 (17 GÜN) · kapsam: FSM · ÖZLÜCE · İST. YOLU · HEYKEL

   Bağlam: mağaza müdürleri sunumu (Sunum_Vardiya.pptx). Sunumdaki her rakam
   buradan çıktı. Üç kez yanlış hikâye kuruldu ve üçü de ÖLÇÜMLE düzeltildi;
   blok 4 ve 5 o düzeltmelerin kanıtıdır.

   ⚠ KAPSAM KARARI (GMY): Genel Müdürlük, kafeler ve ŞURA HARİÇ. GM kişi-günün
     %21'i ama eksik saatin %44'ünü taşıyordu (ofis kadrosu düzenli kart basmıyor:
     orada 70 gün "vardiya tanımsız", 214 gün "devamsız") — dahil edilseydi tablo
     mağazaların kendi gerçeği olmaktan çıkardı.
============================================================================= */

DECLARE @magaza TABLE (Sube nvarchar(50));
INSERT INTO @magaza VALUES (N'FSM'), (N'ÖZLÜCE'), (N'İST. YOLU'), (N'HEYKEL');


/* --- BLOK 1: KAPSAM ve PENCERE ------------------------------------------- */
SELECT  Kisi        = COUNT(DISTINCT SicilNo),
        KisiGun     = COUNT(*),
        Magaza      = COUNT(DISTINCT Sube),
        FarkliGun   = COUNT(DISTINCT Tarih),     -- 17 (16 DEĞİL)
        CalismaSaat = CAST(SUM(ISNULL(CalismaDk,0))/60.0 AS decimal(10,1)),
        EksikSaat   = CAST(SUM(ISNULL(EksikDk,0))/60.0 AS decimal(10,1)),
        FazlaSaat   = CAST(SUM(ISNULL(FazlaDk,0))/60.0 AS decimal(10,1))
FROM    bkm.Vrd_KisiGun WHERE Sube IN (SELECT Sube FROM @magaza);
/* ÖLÇÜLDÜ: 223 · 3.589 · 4 · 17 · 23.926,9 · 1.861,2 · 2.698,5
   ⚠ GÜN SAYISI ÖNCE 16 YAZILMIŞTI. Gün-gün kişi sayımının toplamı tam 3.589
     ediyor ve 17 satır var — 31.08 dahil. Kesim 31.08 başlıyor, sayım 01.09. */


/* --- BLOK 2: MAĞAZA GERÇEKTEN NASIL ÇALIŞIYOR ----------------------------
   Sunumun ilk sürümü "planlı bitiş 18:00" diyordu ve UYDURMAYDI. Gerçek
   vardiya kümesi burada: baskın olan KAPANIŞ vardiyası 13:30-22:00. */
SELECT  VardiyaTanim = ISNULL(NULLIF(VardiyaTanim,''), N'(tanımsız)'),
        Gun          = COUNT(*),
        Pay          = CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER () AS decimal(5,1)),
        Kisi         = COUNT(DISTINCT SicilNo),
        OrtCalismaSa = CAST(AVG(CASE WHEN ISNULL(CalismaDk,0)>0 THEN CalismaDk*1.0 END)/60.0 AS decimal(5,1)),
        OrtFazlaDk   = CAST(AVG(ISNULL(FazlaDk,0)*1.0) AS decimal(6,0))
FROM    bkm.Vrd_KisiGun WHERE Sube IN (SELECT Sube FROM @magaza)
GROUP BY ISNULL(NULLIF(VardiyaTanim,''), N'(tanımsız)')
ORDER BY COUNT(*) DESC;
/* ÖLÇÜLDÜ (ilk altı):
     13:30 - 22:00  1.254 gün  %34,9  138 kişi  7,9 sa  48 dk
     10:00 - 18:30    378      %10,5   87       7,8     41
     09:45 - 18:15    300       %8,4   47       7,9     61
     HFT.İZİN         271       %7,6  166       7,6     62
     13:00 - 21:30    229       %6,4   38       7,8     16
     09:00 - 17:30    211       %5,9   36       8,2     42
   ⭐ ÇIKARILAN SONUÇ: ortalama çalışma HER vardiyada 7,6-8,2 saat. Yani GÜNLÜK
     SÜRE PLANA UYUYOR. "Her gün çok çalışıyorlar" iddiası YANLIŞ olurdu.
     Sunumun mesajı bu ölçümden sonra "yedinci gün yok"a çevrildi. */


/* --- BLOK 3: BASKIN VARDİYANIN GÜNLÜK RİTMİ ------------------------------ */
SELECT  Gun          = COUNT(*),
        OrtGirisDk   = AVG(GirisDk),      -- 794  = 13:14
        OrtCikisDk   = AVG(CikisDk),      -- 1327 = 22:07
        OrtCalismaDk = AVG(CalismaDk),    -- 474  = 7,9 sa
        OrtFazlaDk   = AVG(ISNULL(FazlaDk,0)),
        Cikis22Sonrasi = SUM(CASE WHEN CikisDk > 1320 THEN 1 ELSE 0 END),
        GunDonumu      = SUM(CASE WHEN CikisDk > 1440 THEN 1 ELSE 0 END)
FROM    bkm.Vrd_KisiGun
WHERE   Sube IN (SELECT Sube FROM @magaza)
  AND   VardiyaTanim = '13:30 - 22:00' AND GirisDk IS NOT NULL;
/* ÖLÇÜLDÜ: 1.196 · 794 · 1.327 · 474 · 50 · 937 · 14
   Kapanış vardiyasında 1.196 günün 937'sinde (%78) çıkış 22:00'den sonra. */


/* --- BLOK 4: YEDİNCİ GÜN — ve BOZUK KAYIT AYIKLAMASI ---------------------
   ⚠ BURASI ÜÇ HATANIN AYIKLANDIĞI YER. Bir haftanın "7 gün çalışıldı" olması
     kişinin İŞTE OLDUĞUNU söyler; ama o haftanın SAATİNİ kullanmadan önce
     bozuk okutma elenmelidir (çıkış okutmayı unutan kişide brüt 20+ saat çıkar
     ve hafta toplamı şişer). Ayraç: OlcumNotu 'ŞÜPHELİ' veya CalismaDk > 720. */
WITH h AS (
    SELECT  SicilNo, hafta = DATEPART(iso_week, Tarih),
            calisilan = SUM(CASE WHEN ISNULL(CalismaDk,0) > 0 THEN 1 ELSE 0 END),
            bozuk     = SUM(CASE WHEN OlcumNotu LIKE '%ŞÜPHELİ%'
                                   OR ISNULL(CalismaDk,0) > 720 THEN 1 ELSE 0 END),
            saat      = CAST(SUM(CalismaDk)/60.0 AS decimal(8,1))
    FROM    bkm.Vrd_KisiGun WHERE Sube IN (SELECT Sube FROM @magaza)
    GROUP BY SicilNo, DATEPART(iso_week, Tarih))
SELECT  YediGunHafta  = COUNT(*),
        BozukIceren   = SUM(CASE WHEN bozuk > 0 THEN 1 ELSE 0 END),
        TemizHafta    = SUM(CASE WHEN bozuk = 0 THEN 1 ELSE 0 END),
        TemizKisi     = COUNT(DISTINCT CASE WHEN bozuk = 0 THEN SicilNo END),
        TemizOrtSaat  = CAST(AVG(CASE WHEN bozuk = 0 THEN saat END) AS decimal(6,1)),
        TemizEnYuksek = MAX(CASE WHEN bozuk = 0 THEN saat END)
FROM    h WHERE calisilan >= 7;
/* ÖLÇÜLDÜ: 140 · 3 · 137 · 109 · 56,8 · 74,4
   ⭐ 140'ın yalnız 3'ü bozuk kayıt içeriyor -> başlık AYAKTA.
     109 kişi = 223'ün %48,9'u, yani "iki kişiden biri".
     Temiz haftaların ortalaması 56,8 saat (yasal normal hafta 45 saat). */


/* --- BLOK 5: SUNUMDAKİ ÖRNEK HAFTA — neden ÜÇÜNCÜ aday seçildi -----------
   1. aday: 74,9 saat  -> Pazar 12:08-34:15 (21,1 sa) = UNUTULMUŞ ÇIKIŞ. Atıldı.
   2. aday: 74,4 saat  -> temizdi AMA vardiyası 09:00-17:30, günlerin %5,9'u.
                          "Mağazalar öyle çalışmıyor" (GMY). Atıldı.
   3. aday: 62,6 saat  -> temiz VE 7 günün 6'sı kapanış vardiyası. SEÇİLDİ. */
WITH h AS (
    SELECT  SicilNo, hafta = DATEPART(iso_week, Tarih),
            calisilan = SUM(CASE WHEN ISNULL(CalismaDk,0) > 0 THEN 1 ELSE 0 END),
            bozuk     = SUM(CASE WHEN OlcumNotu LIKE '%ŞÜPHELİ%'
                                   OR ISNULL(CalismaDk,0) > 720 THEN 1 ELSE 0 END),
            kapanis   = SUM(CASE WHEN VardiyaTanim LIKE '13:30%'
                                   OR VardiyaTanim LIKE '13:00%'
                                   OR VardiyaTanim LIKE '12:30%' THEN 1 ELSE 0 END),
            saat      = SUM(CalismaDk)
    FROM    bkm.Vrd_KisiGun WHERE Sube IN (SELECT Sube FROM @magaza)
    GROUP BY SicilNo, DATEPART(iso_week, Tarih))
SELECT TOP 3 hafta, calisilan, kapanis, Saat = CAST(saat/60.0 AS decimal(6,1))
FROM   h WHERE calisilan >= 7 AND bozuk = 0 AND kapanis >= 4
ORDER BY saat DESC;
/* ÖLÇÜLDÜ: hafta 37 · 7 gün · 6 kapanış · 62,6 saat (SicilNo sunumda YOK — KVKK)
   Seçilen haftanın günleri (sunumun 2. slaydı):
     Pzt plan 13:30-22:00  gerçek 09:10-20:42  10,5 sa  fazla 182 dk
     Sal plan 13:30-22:00  gerçek 13:30-22:04   7,6 sa  fazla   4 dk   <-- disiplin var
     Çar plan 10:00-18:30  gerçek 10:00-20:09   9,2 sa  fazla  99 dk
     Per plan 13:30-22:00  gerçek 13:29-22:23   7,9 sa  fazla  24 dk
     Cum plan 13:30-22:00  gerçek 11:28-22:02   9,6 sa  fazla 124 dk
     Cmt plan 13:30-22:00  gerçek 11:25-22:03   9,6 sa  fazla 128 dk
     Paz plan 13:30-22:00  gerçek 13:22-22:35   8,2 sa  fazla 493 dk  <-- 7. gün */


/* --- BLOK 6: OKUTMASIZ GÜNLER -------------------------------------------- */
SELECT  ToplamGun   = COUNT(*),
        TamOkutma   = SUM(CASE WHEN GirisDk IS NOT NULL AND CikisDk IS NOT NULL THEN 1 ELSE 0 END),
        IkisiDeYok  = SUM(CASE WHEN GirisDk IS NULL AND CikisDk IS NULL THEN 1 ELSE 0 END),
        TekTaraf    = SUM(CASE WHEN (GirisDk IS NULL AND CikisDk IS NOT NULL)
                                 OR (GirisDk IS NOT NULL AND CikisDk IS NULL) THEN 1 ELSE 0 END)
FROM    bkm.Vrd_KisiGun WHERE Sube IN (SELECT Sube FROM @magaza);
/* ÖLÇÜLDÜ: 3.589 · 3.030 · 559 · 0
   ⭐ TEK TARAFI EKSİK GÜN YOK: okutma ya tam var ya hiç yok. */

SELECT  Not_ = ISNULL(NULLIF(OlcumNotu,''), N'(not yok)'), Gun = COUNT(*)
FROM    bkm.Vrd_KisiGun WHERE Sube IN (SELECT Sube FROM @magaza)
GROUP BY ISNULL(NULLIF(OlcumNotu,''), N'(not yok)') ORDER BY COUNT(*) DESC;
/* ÖLÇÜLDÜ: (not yok) 3.277 · "Ham okutma da yok" 186 ·
   "PDKS kaydı yok — ölçülemiyor (devamsız DEĞİL)" 97 ·
   "HAM OKUTMA VAR (2 kez) — giriş/çıkış çifti oluşmamış" 13 · gün dönümü 12+2 · … */


/* --- BLOK 7: GÜNLÜK SAPMA ŞERİDİ (sunum slayt 5) ------------------------- */
SELECT  Gun   = CONVERT(varchar(10), Tarih, 104),
        Kisi  = COUNT(*),
        Sapma = SUM(CASE WHEN Durum <> N'Normal Çalışma' AND Durum <> N'İzinli' THEN 1 ELSE 0 END),
        Oran  = CAST(100.0*SUM(CASE WHEN Durum <> N'Normal Çalışma' AND Durum <> N'İzinli'
                                    THEN 1 ELSE 0 END)/COUNT(*) AS decimal(5,0))
FROM    bkm.Vrd_KisiGun WHERE Sube IN (SELECT Sube FROM @magaza)
GROUP BY Tarih ORDER BY Tarih;
/* ÖLÇÜLDÜ: 40·37·41·42·39·40·43·35·34·38·43·42·38·41·42·45·45
   17 günün 17'sinde sapma var; en iyi %34, en kötü %45. */


/* --- BLOK 8: FAZLA MESAİNİN KAYNAĞI + AKŞAM BANTLARI --------------------- */
SELECT  FazlaCalisma = CAST(SUM(ISNULL(FazlaCalismaDk,0))/60.0 AS decimal(10,1)),
        HaftaTatili  = CAST(SUM(ISNULL(HaftalikPrimDk,0))/60.0 AS decimal(10,1)),
        IzinIptal    = CAST(SUM(ISNULL(FazlaIzinIptalDk,0))/60.0 AS decimal(10,1)),
        Plansiz      = CAST(SUM(ISNULL(FazlaPlansizDk,0))/60.0 AS decimal(10,1)),
        CikisSonrasi = CAST(SUM(ISNULL(CikisSonrasiDk,0))/60.0 AS decimal(10,1)),
        GirisOncesi  = CAST(SUM(ISNULL(GirisOncesiDk,0))/60.0 AS decimal(10,1)),
        IkiSaatUstuGun  = SUM(CASE WHEN CikisSonrasiDk > 120 THEN 1 ELSE 0 END),
        IkiSaatUstuSaat = CAST(SUM(CASE WHEN CikisSonrasiDk > 120 THEN CikisSonrasiDk END)/60.0 AS decimal(10,1))
FROM    bkm.Vrd_KisiGun WHERE Sube IN (SELECT Sube FROM @magaza);
/* ÖLÇÜLDÜ: 1.367,1 · 1.050,0 · 250,0 · 31,4 · 1.345,9 · 630,5 · 151 · 573,4
   Dört kalem toplamı = FazlaDk toplamı (161.908 dk) — birebir.
   İlk iki kalem toplamın %89,6'sı; ikisi de PLANLAMA kararı. */


/* --- BLOK 9: FAZLA MESAİNİN SAAT MALİYETİ (ZİRVE bordro) -----------------
   ⚠ BAŞKA SUNUCU: BKM_GENEL (192.168.40.25\ZRVSQL2008), sqlcli --profile zirve.
   ⚠ Bordroda LOKASYON kolonu YOK -> saat ücreti ŞİRKET GENELİDİR, mağaza
     bazına ayrıştırılamaz. Sunumda "şirket ortalaması" diye yazıldı. */
-- SELECT Yil, Ayindex,
--        FmSaat   = CAST(SUM(fm1+fm2+fm3) AS decimal(12,1)),
--        FmTutar  = CAST(SUM(fmtutar1+fmtutar2+fmtutar3) AS decimal(14,2)),
--        SaatBasi = CAST(SUM(fmtutar1+fmtutar2+fmtutar3)
--                        / NULLIF(SUM(fm1+fm2+fm3),0) AS decimal(10,2))
-- FROM dbo.vw_PuanBil WHERE Yil = 2026 GROUP BY Yil, Ayindex ORDER BY Ayindex;
/* ÖLÇÜLDÜ (Ağustos 2026 = son TAM kapanan ay): 4.265,5 saat · 900.394,91 ₺
   -> saat başı 211,09 ₺.  Eylül henüz kapanmadı (25 kayıt) — KULLANILMAZ. */
