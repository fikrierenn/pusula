/* ============================================================================
   PDKS — ANOMALİ SINIFLARI + RAPOR PORTALINA TAŞIMA
   Soru : (a) zei32 raporu reporthub (Mosaik) portalına eklenebilir mi?
          (b) "İK işini yapmıyorsa" hangi anomaliler GERÇEKTEN var?
   Hedef: 192.168.40.201 · [BKM] · Linked Server [PDKS] (TEK ATLAMA)
   Tarih: 28.09.2026

   ⭐ TEK ATLAMA KEŞFİ: bugüne kadar PDKS'e yerel `BkmPanel`den
      `OPENQUERY(LIVE201 → [PDKS])` ÇİFT atlama ile gidiliyordu. Ölçüldü:
      40.201'in KENDİSİNDE `[PDKS]` linked server tanımlı ve tek
      `OPENQUERY([PDKS], ...)` çalışıyor → iş istasyonu bağımlılığı KALKTI.
      Portal raporları bunu kullanır (DataSourceKey 'PDKS' → 40.201/[BKM]).

   BULGU ÖZETİ
   -----------
   1. `TTagMoS` GELECEĞE satır üretiyor: 483.907 satırın 401.598'i (%83)
      gelecek tarihli, en ileri gün 10.01.2053, 110 kişi. Anomali raporu
      bugünle KIRPMAZSA tek kişi "1522 gün devamsız" görünür.
   2. Mükerrer TC deseni = İŞTEN ÇIKIP GERİ DÖNEN. 12 kişinin 12'sinde
      eski kayıt takip=0 + kart no = sicil no (İK kuralı DOĞRU uygulanmış),
      yeni kayıt takip=1 + gerçek kart + güncel okutma. "Hata" DEĞİL.
   3. Uzun devamsızlığın ÇOĞU zaten halledilmiş: DESIZ ≥15 gün olan
      46 kişinin 42'si çıkışı TAM işlenmiş. Aksiyon gereken 4.
   4. "Gün planı üretilmemiş" ham hâliyle YENİ GİRENLERİ yakalar (34 kişi);
      yalnız İÇ BOŞLUK sayılınca gerçek sayı 1 (PersNr 2005).
   5. `TTagLes` eksik çıkış okutması GERİYE DÖNÜK tamamlanıyor: aynı
      pencere 10:25'te 12 kişi / 22 gün, 10:40'ta 9 kişi / 19 gün.
   ============================================================================ */


/* --- 1) TEK ATLAMA ÇALIŞIYOR MU (40.201'den doğrudan) -------------------- */
SELECT TOP 3 x.PersNr, x.Ad
FROM OPENQUERY([PDKS], '
  SELECT TOP 3 Per_PersNr AS PersNr, Per_Vorname AS Ad FROM TPerTab') x;
/* ÖLÇÜLDÜ: satır döndü (1 ABDULKADİR, 2 ABDULSAMET...). Türkçe doğru.
   ⇒ Çift atlama (LIVE201 → PDKS) ARTIK GEREKMİYOR. Portal SP'leri
     40.201 üzerinde koştuğu için tek OPENQUERY yeterli.                   */


/* --- 2) GELECEK TARİHLİ SATIR — anomali raporunun KIRPMA gerekçesi ------ */
SELECT * FROM OPENQUERY([PDKS], '
 SELECT Bugun = CONVERT(date, GETDATE()),
        EnIleriGun   = MAX(s.TMS_Datum),
        GelecekSatir = SUM(CASE WHEN s.TMS_Datum > GETDATE() THEN 1 ELSE 0 END),
        GelecekKisi  = COUNT(DISTINCT CASE WHEN s.TMS_Datum > GETDATE() THEN s.TMS_PersNr END),
        ToplamSatir  = COUNT(*)
 FROM TTagMoS s WHERE s.TMS_Datum >= ''20260101''') x;
/* ÖLÇÜLDÜ 28.09.2026:
     Bugun 2026-09-28 · EnIleriGun **2053-01-10**
     GelecekSatir 401.598 / ToplamSatir 483.907  (%83)
     GelecekKisi  110
   ⇒ Pencere kırpılmazsa devamsızlık gün sayısı SAÇMALAŞIR. Ölçülen uç:
     PersNr 1585 · DESIZ 1.522 gün · 04.06.2026 → 20.10.2030.             */


/* --- 3) MÜKERRER TC = GERİ DÖNEN ÇALIŞAN (hata DEĞİL) ------------------- */
SELECT * FROM OPENQUERY([PDKS], '
 SELECT p.Per_PersNr,
        Ad     = LTRIM(RTRIM(p.Per_Vorname)) + '' '' + LTRIM(RTRIM(p.Per_Name)),
        Sube   = LTRIM(RTRIM(ISNULL(p.Per_Grp2, ''''))),
        p.Per_ZeitAktiv,
        KartNo = LTRIM(RTRIM(ISNULL(p.Per_AuswNr, ''''))),
        SonOkutma = (SELECT MAX(l.TLe_Datum) FROM TTagLes l
                     WHERE l.TLe_PersNr = p.Per_PersNr AND l.TLe_VonZeit IS NOT NULL)
 FROM TPerTab p
 INNER JOIN TPerInd i ON i.PIn_PersNr = p.Per_PersNr
 WHERE i.PIn_SteuerNr IS NOT NULL AND LTRIM(RTRIM(i.PIn_SteuerNr)) <> ''''
   AND EXISTS (SELECT 1 FROM TPerInd i2
               INNER JOIN TPerTab p2 ON p2.Per_PersNr = i2.PIn_PersNr
               WHERE i2.PIn_SteuerNr = i.PIn_SteuerNr AND i2.PIn_PersNr <> i.PIn_PersNr)') x;
/* ÖLÇÜLDÜ: 24 kayıt / 12 kişi. HER ÇİFTTE aynı desen:
     ESKİ : takip=0 · kart no = sicil no · son okutma aylar önce
     YENİ : takip=1 · gerçek kart no     · son okutma bugün/dün
   ör. ARDA ÇALIŞKAN 3201(kapalı, 17.06) → 3531(aktif, 27.09)
       RECEP ÇİÇEK   2995(kapalı, 08.02) → 3517(aktif, 27.09)
   ⇒ İK çıkış kuralını DOĞRU uygulamış; bunlar geri dönen çalışanlar.
     Anomali raporunda "düzelt" DEĞİL, "kişi sayan raporda tek say" uyarısı.
   ⚠ sema `mukerrerde_hangisi` (2026-09-15) doğru kaydı `Per_ZeitAktiv=1`
     diye zaten belirlemişti; bu ölçüm SEBEBİNİ ekliyor (geri dönüş).      */


/* --- 4) "İK İŞİNİ YAPMAMIŞ" ADAYLARI ------------------------------------ */
SELECT * FROM OPENQUERY([PDKS], '
 SELECT sinif = CASE WHEN p.Per_ZeitAktiv = 0
                     THEN ''A · TAKIP KAPALI ama kart no sicil no ile ESITLENMEMIS''
                     ELSE ''B · TAKIP ACIK ama uzun suredir okutma YOK'' END,
        p.Per_PersNr,
        Ad   = LTRIM(RTRIM(p.Per_Vorname)) + '' '' + LTRIM(RTRIM(p.Per_Name)),
        Sube = LTRIM(RTRIM(ISNULL(p.Per_Grp2, ''''))),
        p.Per_ZeitAktiv,
        KartNo    = LTRIM(RTRIM(ISNULL(p.Per_AuswNr, ''''))),
        SonOkutma = (SELECT MAX(l.TLe_Datum) FROM TTagLes l
                     WHERE l.TLe_PersNr = p.Per_PersNr AND l.TLe_VonZeit IS NOT NULL)
 FROM TPerTab p
 WHERE EXISTS (SELECT 1 FROM TTagMoS s WHERE s.TMS_PersNr = p.Per_PersNr
               AND s.TMS_Datum >= ''20260901'')
   AND ( ( p.Per_ZeitAktiv = 0
           AND LTRIM(RTRIM(ISNULL(p.Per_AuswNr, ''''))) <> CONVERT(varchar, p.Per_PersNr) )
      OR ( p.Per_ZeitAktiv = 1
           AND DATEDIFF(day, ISNULL((SELECT MAX(l.TLe_Datum) FROM TTagLes l
                                     WHERE l.TLe_PersNr = p.Per_PersNr
                                       AND l.TLe_VonZeit IS NOT NULL), ''19000101''),
                        GETDATE()) > 21 ) )') x;
/* ÖLÇÜLDÜ: A = 4 kişi · B = 2 kişi.
     A: 3473 KEMAL OCAK (kullanıcı teyidi: takip BİLEREK kapatıldı)
        1585 ÖMER FARUK KIRMACI · 3369 BURAK BİNGÖLBALİ · 3293 ERTUNÇ GÜLER
     B: 3468 AYDIN ÖZCAN (hiç okutma yok) · 2838 AYŞE BAYRAKTAR
   ⚠⚠ 2838 AYŞE BAYRAKTAR **DOĞUM İZNİNDE** — 76 gün DOGUM (13.07-27.09).
      "İK yapmadı" listesine koymak YANLIŞ SUÇLAMA olurdu. Bu yüzden
      anomali raporu YALNIZ `DESIZ` sayar; DOGUM/YILIZ/HASTA/UCSIZ HARİÇ.
   ⚠ 21 günlük eşik BURADA KEŞİF içindi; rapora SABİT olarak GİRMEDİ —
     "kaç gün devamsızlık incelenmeli" bir İK politikasıdır, veriden
     türetilemez. Raporda kullanıcı seçer (@DesizGunEsigi).               */


/* --- 5) MAZERET KAPSAMI — kimin devamsızlığı MEŞRU ---------------------- */
SELECT * FROM OPENQUERY([PDKS], '
 SELECT s.TMS_PersNr,
        Mazeret = LTRIM(RTRIM(ISNULL(s.TMS_LetzteAbwArt, ''''))),
        Gun = COUNT(*), IlkGun = MIN(s.TMS_Datum), SonGun = MAX(s.TMS_Datum)
 FROM TTagMoS s
 WHERE s.TMS_PersNr IN (2838, 3468, 1585, 3369, 3293, 3473)
   AND s.TMS_Datum >= ''20260601''
 GROUP BY s.TMS_PersNr, LTRIM(RTRIM(ISNULL(s.TMS_LetzteAbwArt, '''')))') x;
/* ÖLÇÜLDÜ — iki şey birden çıktı:
   (a) 2838 AYŞE BAYRAKTAR: DOGUM 76 gün (13.07→27.09) → MEŞRU, rapora girmez.
   (b) 1585 ÖMER FARUK KIRMACI: DESIZ **1.522 gün**, 04.06.2026 → **20.10.2030**
       → blok 2'deki gelecek-tarih olgusunun kişi düzeyindeki kanıtı.       */


/* --- 6) DEVAMSIZLARIN ÇOĞU ZATEN HALLEDİLMİŞ (rapor süzgecinin gerekçesi) */
SELECT * FROM OPENQUERY([PDKS], '
 SELECT durum = CASE WHEN p.Per_ZeitAktiv = 0
                       AND LTRIM(RTRIM(ISNULL(p.Per_AuswNr, ''''))) = CONVERT(varchar, p.Per_PersNr)
                     THEN ''CIKIS TAM ISLENMIS''
                     WHEN p.Per_ZeitAktiv = 0 THEN ''cikis YARIM''
                     ELSE ''kayit HALA ACIK'' END,
        kisi = COUNT(*)
 FROM TPerTab p
 WHERE EXISTS (SELECT 1 FROM TTagMoS s WHERE s.TMS_PersNr = p.Per_PersNr
               AND s.TMS_Datum BETWEEN ''20260901'' AND ''20260927''
               AND LTRIM(RTRIM(ISNULL(s.TMS_LetzteAbwArt, ''''))) = ''DESIZ''
               GROUP BY s.TMS_PersNr HAVING COUNT(*) >= 15)
 GROUP BY CASE WHEN p.Per_ZeitAktiv = 0
                 AND LTRIM(RTRIM(ISNULL(p.Per_AuswNr, ''''))) = CONVERT(varchar, p.Per_PersNr)
               THEN ''CIKIS TAM ISLENMIS''
               WHEN p.Per_ZeitAktiv = 0 THEN ''cikis YARIM''
               ELSE ''kayit HALA ACIK'' END') x;
/* ÖLÇÜLDÜ: TAM İŞLENMİŞ **42** · YARIM **1** · HÂLÂ AÇIK **3**.
   ⇒ Süzgeçsiz rapor 46 satır verir ve 42'si İK'nın DOĞRU yaptığı iştir;
     4 gerçek vakayı gömer. Rapor "çıkışı tam işlenmiş" olanı HARİÇ tutar.
     (İlk sürümde bu süzgeç YOKTU — gürültü oranı %67 ölçüldü: 114 → 38.)  */


/* --- 7) "GÜN PLANI ÜRETİLMEMİŞ" ham hâliyle YENİ GİRENİ yakalar --------- */
SELECT * FROM OPENQUERY([PDKS], '
 SELECT p.Per_PersNr,
        Ad = LTRIM(RTRIM(p.Per_Vorname)) + '' '' + LTRIM(RTRIM(p.Per_Name)),
        IlkGun = MIN(s.TMS_Datum), SonGun = MAX(s.TMS_Datum), Gun = COUNT(*),
        IlkOkutma = (SELECT MIN(l.TLe_Datum) FROM TTagLes l
                     WHERE l.TLe_PersNr = p.Per_PersNr AND l.TLe_VonZeit IS NOT NULL)
 FROM TPerTab p INNER JOIN TTagMoS s ON s.TMS_PersNr = p.Per_PersNr
 WHERE s.TMS_Datum BETWEEN ''20260901'' AND ''20260927'' AND p.Per_ZeitAktiv = 1
   AND p.Per_PersNr IN (3531, 3540, 3536, 3525)
 GROUP BY p.Per_PersNr, p.Per_Vorname, p.Per_Name') x;
/* ÖLÇÜLDÜ — dördü de YENİ GİREN, ilk PDKS günü = ilk kart okutması:
     3525 ENES ADIBELLİ  08.09  ·  3531 ARDA ÇALIŞKAN  09.09
     3536 EMİRHAN ÇELİK  15.09  ·  3540 BURAK ELİBOL   16.09
   ⇒ "pencere günü − kayıt sayısı" formülü işe girmeden önceki günleri
     EKSİK sanır. Yalnız İÇ BOŞLUK sayılır:
       DATEDIFF(DAY, MIN(Tarih), MAX(Tarih)) + 1 − COUNT(*)
     Düzeltince 34 kişi → **1** (2005 EMRE DEMİR, 7 gün).
   ⚠ Aynı tuzak zei32 raporunda daha önce ölçülmüş ve "KAYITTAN ÖNCE"
     etiketiyle ayrılmıştı (277 → 15). Yeni SP'ye taşınması ATLANMIŞTI.   */


/* --- 8) EKSİK ÇIKIŞ OKUTMASI GERİYE DÖNÜK TAMAMLANIYOR ------------------ */
SELECT * FROM OPENQUERY([PDKS], '
 SELECT Kisi = COUNT(DISTINCT s.TMS_PersNr), Gun = COUNT(*)
 FROM TTagMoS s
 LEFT JOIN (SELECT TLe_PersNr, TLe_Datum,
                   ilkVon = MIN(TLe_VonZeit), sonBis = MAX(TLe_BisZeit)
            FROM TTagLes
            WHERE TLe_Datum BETWEEN ''20260901'' AND ''20260927''
              AND TLe_VonZeit IS NOT NULL
            GROUP BY TLe_PersNr, TLe_Datum) l
   ON l.TLe_PersNr = s.TMS_PersNr AND l.TLe_Datum = s.TMS_Datum
 WHERE s.TMS_Datum BETWEEN ''20260901'' AND ''20260927''
   AND l.ilkVon IS NOT NULL AND l.sonBis IS NULL') x;
/* ÖLÇÜLDÜ AYNI GÜN İKİ KEZ, AYNI PENCERE:
     10:25 → 12 kişi / 22 gün
     10:40 →  9 kişi / 19 gün
   ⇒ Eksik çıkış okutması geriye dönük tamamlanıyor. İki koşum arasındaki
     fark VERİ HATASI DEĞİL, kaynağın bilinen davranışı
     (sema: pdks_vardiya_plani.geriye_donuk_duzeltme).
     Anomali raporunun sayısı bu yüzden ANLIK'tır; trend için tarih damgası
     ile saklanmalı, iki koşum çıplak kıyaslanmamalı.                      */


/* ============================================================================
   ÜRETİLEN NESNELER (reporthub / Mosaik portalı)
   ----------------------------------------------------------------------------
   192.168.40.201 · [BKM]
     dbo.sp_PdksGirisCikisDetay    → "PDKS Giriş/Çıkış Detay"   (ReportId 20)
     dbo.sp_PdksKayitBakimKontrol  → "PDKS Kayıt Bakım Kontrolü"(ReportId 21)
   Kaynak: D:\Dev\reporthub\Mosaik\Database\sp_Pdks*.sql + 93_/94_ seed
   Parite kapısı: D:\Dev\pusula\vardiya\zei32_sp_parite.py (çıkış 0/1/2)
   ============================================================================ */
