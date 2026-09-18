/* ============================================================================
   PDKS — zei32Giris_Cikis_GM_Maz-2 RAPORUNUN KAYNAK KEŞFİ
   Soru : Crystal Reports çıktısı `vardiya/zei32Giris_Cikis_GM_Maz-2.xls`
          (16.09.2026 · HEYKEL · 44 satır) PDKS'ten yeniden üretilebilir mi?
   Hedef: PDKS (çift atlama — yerel BkmPanel → LIVE201 → [PDKS])
   Tarih: 18.09.2026

   BULGU ÖZETİ
   -----------
   1. Rapor adındaki "zei" `TTagZei`den gelir AMA saatler oradan GELMEZ:
      TTagZei PLAN/işlenmiş segmentleri tutar (yuvarlak saatler, ZeitArt=NCAL/FM1),
      fiili kart okutması `TTagLes`tedir. Rapordaki "Pdks 1. Giris/Cikis" HAM okuma.
   2. `TZe_BruttoZeit` = rapordaki "Bürüt Süre" · `TZe_TagMod` = "Gün Modeli"
      · `TZe_AbwArt` = "Mazeret" (→ TAbwArt sözlüğü).
   3. Gün Modeli değerleri (16.09 HEYKEL): 818 · G1 · G2 · G3 · SABIT.
   4. Rapor süzgeci `Per_ZeitAktiv` DEĞİL — xls'te 43 aktif + 1 pasif var,
      dışarıda kalan 6'nın 1'i aktif. Gerçek süzgeç ÖLÇÜLEMEDİ (açık soru).
   5. ⚠ PDKS GERİYE DÖNÜK DÜZELTİLİYOR: xls 17.09 07:18'de alınmış, PersNr 463
      için giriş 08:50 yazıyor; aynı gün 20:23'te çekilen canlı veri 08:52.
      "Birebir aynı" çıktı SABİT BİR HEDEF DEĞİL.

   ⚠ ÇİFT ATLAMA TIRNAK KURALI: iç sorgu (L2) → ' iki katına, sonra L1 → yine
     iki katına. Python tarafında `replace("'","''")` iki kez uygulanır.
   ============================================================================ */

/* --- 1) TTagZei kolon keşfi (46 kolon) ------------------------------------ */
SELECT * FROM OPENQUERY(LIVE201, '
  SELECT * FROM OPENQUERY([PDKS], ''
    SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = ''''TTagZei'''' ORDER BY ORDINAL_POSITION'') x') y;
/* Rapora karşılık gelen kolonlar:
     TZe_TagMod       nvarchar  -> "Gün Modeli"
     TZe_AbwArt       nvarchar  -> "Mazeret"
     TZe_BruttoZeit   decimal   -> "Bürüt Süre"
     TZe_ZeitArt      nvarchar  -> segment tipi (NCAL / FM1)
     TZe_IstZeit      decimal   -> segment süresi (saat.dakika)                */


/* --- 2) TTagZei GRAIN: plan segmenti, kart okutması DEĞİL ----------------- */
SELECT * FROM OPENQUERY(LIVE201, '
  SELECT * FROM OPENQUERY([PDKS], ''
    SELECT TOP 20 p.Per_PersNr, p.Per_Vorname, p.Per_Name, z.TZe_BeginnKz,
           z.TZe_VonZeit, z.TZe_BisZeit, z.TZe_IstZeit, z.TZe_BruttoZeit,
           z.TZe_TagMod, z.TZe_AbwArt, z.TZe_ZeitArt, z.TZe_AnwZeit
    FROM        TPerTab p
    INNER JOIN  TTagZei z ON z.TZe_PersNr = p.Per_PersNr
    WHERE  z.TZe_Datum = ''''20260916'''' AND p.Per_Grp2 = ''''HEYKEL''''
       AND p.Per_PersNr IN (463, 470, 2245)
    ORDER BY p.Per_PersNr, z.TZe_VonZeit'') x') y;
/* ÖLÇÜLDÜ: PersNr 463 -> üç satır.
     (a) VonZeit/BisZeit NULL · IstZeit 9.00 · AbwArt='NG'   <- günün başlık satırı
     (b) 09:00-12:00 · IstZeit 3.00 · ZeitArt='NCAL'         <- PLAN segmenti
     (c) 13:00-17:00 · IstZeit 4.00 · ZeitArt='NCAL'
   Saatler YUVARLAK -> bunlar kart okutması değil, gün modelinin segmentleri.
   HEYKEL 16.09: 50 kişi / 145 satır, hepsinde TZe_BeginnKz = 0.               */


/* --- 3) FİİLİ KART OKUTMASI: TTagLes ------------------------------------- */
SELECT * FROM OPENQUERY(LIVE201, '
  SELECT * FROM OPENQUERY([PDKS], ''
    SELECT l.TLe_BeginnKz, l.TLe_VonZeit, l.TLe_BisZeit, l.TLe_IstZeit, l.TLe_AbwArt
    FROM   TTagLes l
    WHERE  l.TLe_PersNr = 463 AND l.TLe_Datum = ''''20260916''''
    ORDER BY l.TLe_VonZeit'') x') y;
/* ÖLÇÜLDÜ: TEK satır -> 08:52 - 17:10 · IstZeit 8.18.
   xls aynı kişi için 08:50 yazıyor -> 2 dakikalık geriye dönük düzeltme.      */


/* --- 4) RAPOR SÜZGECİ: Per_ZeitAktiv DEĞİL ------------------------------- */
SELECT * FROM OPENQUERY(LIVE201, '
  SELECT * FROM OPENQUERY([PDKS], ''
    SELECT p.Per_PersNr, p.Per_Vorname, p.Per_Name, p.Per_ZeitAktiv,
           p.Per_ZeitAktivVonDatum, p.Per_ZeitAktivBisDatum
    FROM   TPerTab p
    WHERE  p.Per_Grp2 = ''''HEYKEL''''
      AND  EXISTS (SELECT 1 FROM TTagZei z
                   WHERE z.TZe_PersNr = p.Per_PersNr AND z.TZe_Datum = ''''20260916'''')
    ORDER BY p.Per_ZeitAktiv, p.Per_PersNr'') x') y;
/* ÖLÇÜLDÜ: TTagZei'de 50 kişi (44 aktif / 6 pasif), xls'te 44 kişi.
   AMA kesişim temiz değil:
     · xls içindekilerin 43'ü aktif, 1'i PASİF  (3351 YAŞAR UĞUR, ZeitAktiv=0)
     · xls dışında kalan 6'nın 1'i AKTİF        (3521 KAĞAN ESAT KURUOĞLU)
   -> Süzgeç `Per_ZeitAktiv` değil. Ne olduğu ÖLÇÜLEMEDİ; Crystal raporunun
      kendi parametresi olabilir. AÇIK SORU.
   Not: 2995 ve 3517 aynı kişidir (RECEP ÇİÇEK) — mükerrer PersNr deseni,
        sema `TPerInd.mukerrer_tuzagi` ile aynı sınıf.                         */


/* --- 5) TAbwArt KOD KÜMESİ (sema'daki "kod kümesi çıkarılmadı" boşluğu) --- */
SELECT * FROM OPENQUERY(LIVE201, '
  SELECT * FROM OPENQUERY([PDKS], ''
    SELECT a.Abw_AbwArt, a.Abw_AbwArtBez, a.Abw_AbwArtKurzBez,
           kullanim = (SELECT COUNT(*) FROM TTagZei z
                       WHERE z.TZe_AbwArt = a.Abw_AbwArt
                         AND z.TZe_Datum >= ''''20260831''''
                         AND z.TZe_Datum <= ''''20260916'''')
    FROM TAbwArt a ORDER BY 4 DESC, 1'') x') y;
/* ÖLÇÜLDÜ 18.09.2026 — 16 kod, 31.08-16.09 penceresindeki kullanım:
     NG    NORMAL GÜN        4723      DESIZ UCRETSİZ İZİN* 1268
     HTAT2 HAFTA TATİLİ 2     149      HASTA UCRETSİZ İZİN    41
     DOGUM DOGUM               17      YILIZ YILLIK İZİN      15
     UCSIZ UCRETSİZ İZİN        8
     canlıda kullanılmayan (0): EVLEN · GOREV · HTAT1 · OFF · OLUM · RESTA
                                SUT · UCRLI · VIZIT
   * DESIZ kısa adı 'DV', açıklaması 'DEVAMSIZ'.
   ⚠ `HASTA` kodunun AÇIKLAMASI 'UCRETSİZ İZİN' — kod adıyla açıklaması
     UYUŞMUYOR. Kodun anlamı açıklamadan okunamaz, İK teyidi ister.
   ⭐ HTAT1/HTAT2 ayrımı: PDKS iki ayrı hafta tatili tanıyor. HTAT2 149 kez
     kullanılmış, HTAT1 hiç. İki tatil günü olan kadroda (GM: Cmt+Paz)
     hangisinin KANUNİ hafta tatili sayıldığı sorusunun PDKS tarafındaki izi.  */
