/*
  Soru (patron hesap sormasi): "Bu sene neden fazla eleman aldiniz?"
  Amac: kadro artisini is hacmi artisiyla karsilastirip iddiayi olcmek.
  DB: Zirve BKM_GENEL (kadro) + 192.168.40.201 EncoreMerkez (POS satis).
  Pencere: 1 Tem - 2 Eyl, 2025 vs 2026 (ayni takvim gunu kesimi).

  BULGU (2026-09-02):
    Kadro (ayni takvim gununde AKTIF kisi): 325 -> 344 (+19, %5,8)
      · sezonluk 74 -> 77 · kadrolu 251 -> 267
      · SEZON ONCESI 30 Haziran: 245 -> 265 (+20) => artis sezon karari DEGIL, yil-ici buyume
    Perakende (belge tipi 1): fis 96.203 -> 157.922 (+%64,2) · net ciro 62,9M -> 117,3M (+%86,6)
    Sinav Okullari (tip 8): belge 4.187 -> 2.220 · ciro 189,5M -> 132,0M (-%30,4)
      => TOPLAM ciro 251,1M -> 249,0M (yatay) yaniltici: dusus kurumsal kanaldan, magaza yuku artti
    Kisi basi fis: 296 -> 459 (+%55) => verimlilik ARTTI
    Sube bazli kadro (02 Eyl): Ozluce 50->61 · Ist.Yolu 50->61 · FSM 42->45 · kafeler +5 · depo 17->19
                               Heykel 42->37 · Sura 19->16 · Genel Yonetim 53->50 · FSM Kafe 18->16
      => artis is buyuyen yere gitti, kuculen yerde kadro dusuruldu
    ZAYIF NOKTA (kendin soyle): kadrolu alim 48->61 ve 18'i Eylul'u gormeden ayrildi (2025: 6);
      14g tutunma kadroluda %92,1 -> %75,5. Brut alimin bir kismi IKAME.

  ⚠ Yontem notlari:
    - "Aktif kisi" as-of tarih: Igt <= T AND (Ict IS NULL OR Ict >= T). Bugunku snapshot DEGIL.
    - EncoreMerkez net KDV-haric (header) = GrossTotal - DiscountTotal - VatTotal (sema: entities.Sales).
      Iade (tip 3) sign'li dusulur. Sales'te IsValid YOK (o SalesProducts'ta).
    - Toplam ciro/kisi metrigi YANILTIR (Sinav kurumsal cirosu kadro-yogun degil) -> perakende ayri olculur.
    - StoresId: 1=Ist.Yolu · 2=FSM · 3=Ozluce (CLAUDE.md mekan eslemesi). Heykel/Sura EncoreMerkez POS'ta YOK.
    - Kafe personeli AltLokasyon'da ayri (FSM KAFE vb.) ama POS fisleri magaza StoresId'sine dusebilir
      -> sube bazli "fis/kisi" oranini kafe dahil/haric ayrimiyla yorumla.
*/

-- ⚠ AS-OF KANONIK TANIM: aktif = Igt <= T AND (Ict IS NULL OR Ict >= T) — IK'nin
--   sp_PersonelKarsilastirma_Ozet konvansiyonu. Bu dosyada 02.09.2026'da "Ict > T" kullanan
--   bloklar >= ile duzeltildi (sapma: cikisi tam kesim gunu olan kisi, 1 kisilik fark).
-- ============ 1) ZIRVE: as-of aktif kadro (2 Eylul + sezon oncesi 30 Haziran) ============
-- MCP: zirve · DB: BKM_GENEL
SELECT
    SUM(CASE WHEN Igt <= '20250902' AND (Ict IS NULL OR Ict >= '20250902') THEN 1 ELSE 0 END) AS aktif_02Eyl25,
    SUM(CASE WHEN Igt <= '20260902' AND (Ict IS NULL OR Ict >= '20260902') THEN 1 ELSE 0 END) AS aktif_02Eyl26,
    SUM(CASE WHEN Kadro = 'SEZONLUK' AND Igt <= '20250902' AND (Ict IS NULL OR Ict >= '20250902') THEN 1 ELSE 0 END) AS sezonluk_02Eyl25,
    SUM(CASE WHEN Kadro = 'SEZONLUK' AND Igt <= '20260902' AND (Ict IS NULL OR Ict >= '20260902') THEN 1 ELSE 0 END) AS sezonluk_02Eyl26,
    SUM(CASE WHEN ISNULL(Kadro,'X') <> 'SEZONLUK' AND Igt <= '20250902' AND (Ict IS NULL OR Ict >= '20250902') THEN 1 ELSE 0 END) AS kadrolu_02Eyl25,
    SUM(CASE WHEN ISNULL(Kadro,'X') <> 'SEZONLUK' AND Igt <= '20260902' AND (Ict IS NULL OR Ict >= '20260902') THEN 1 ELSE 0 END) AS kadrolu_02Eyl26,
    SUM(CASE WHEN Igt <= '20250630' AND (Ict IS NULL OR Ict >= '20250630') THEN 1 ELSE 0 END) AS aktif_30Haz25,
    SUM(CASE WHEN Igt <= '20260630' AND (Ict IS NULL OR Ict >= '20260630') THEN 1 ELSE 0 END) AS aktif_30Haz26
FROM dbo.vw_PersonelDepartman;

-- ============ 2) ZIRVE: sube bazli as-of kadro (artis nereye gitti) ============
SELECT ISNULL(AltLokasyon,'(bos)') AS sube,
       MIN(Igt) AS ilk_personel_girisi,          -- yeni sube var mi? (yok: en yenisi 2022)
       SUM(CASE WHEN Igt <= '20250902' AND (Ict IS NULL OR Ict >= '20250902') THEN 1 ELSE 0 END) AS aktif_02Eyl25,
       SUM(CASE WHEN Igt <= '20260902' AND (Ict IS NULL OR Ict >= '20260902') THEN 1 ELSE 0 END) AS aktif_02Eyl26
FROM dbo.vw_PersonelDepartman
GROUP BY AltLokasyon
ORDER BY 4 DESC;

-- ============ 3) ENCOREMERKEZ: is hacmi (belge tipi kirilimli) ============
-- MCP: sqlserver · DB: EncoreMerkez
SELECT YEAR(s.Date) AS yil, s.DocumentsTypeId AS belge_tip,
       COUNT(*) AS adet,
       SUM(s.GrossTotal - s.DiscountTotal - s.VatTotal) AS net_kdvharic
FROM dbo.Sales s
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND ((s.Date >= '20250701' AND s.Date < '20250903')
    OR (s.Date >= '20260701' AND s.Date < '20260903'))
GROUP BY YEAR(s.Date), s.DocumentsTypeId
ORDER BY 2, 1;
-- tip 1 (fis): 96.203 / 62,9M  ->  157.922 / 117,3M     = ASIL MAGAZA YUKU
-- tip 8 (Sinav): 4.187 / 189,5M -> 2.220 / 132,0M       = TOPLAMI ASAGI CEKEN KALEM

-- ============ 4) ENCOREMERKEZ: toplam (iade sign'li) + fis adedi ============
SELECT YEAR(s.Date) AS yil,
       COUNT(*) AS belge,
       SUM(CASE WHEN s.DocumentsTypeId = 3
                THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
                ELSE  (s.GrossTotal - s.DiscountTotal - s.VatTotal) END) AS net_ciro_kdvharic,
       SUM(CASE WHEN s.DocumentsTypeId = 1 THEN 1 ELSE 0 END) AS fis_adet
FROM dbo.Sales s
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND ((s.Date >= '20250701' AND s.Date < '20250903')
    OR (s.Date >= '20260701' AND s.Date < '20260903'))
GROUP BY YEAR(s.Date);

-- ⚠⚠ BLOK 5 UYARISI (sql-denetci 02.09.2026): asagidaki net hesabinda IADE SIGN'I YOK
--   (DocumentsTypeId=3 negatife cevrilmiyor) -> "net" SISIK cikar. Ayrica bu blok EncoreMerkez
--   tabanlidir ve POS gecisi yuzunden 2025 tarafi eksiktir (bkz. BLOK 10 SUPERSEDED notu).
--   KULLANMA. Nihai rakamlar BLOK 11'de (DerinSIS eTip 100) ve scripts/verimlilik_excel.py'de.
--   Dogru desen: SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(net) ELSE (net) END)
-- ============ 5) ENCOREMERKEZ: magaza bazli hacim (kadro artisiyla eslestir) ============
SELECT YEAR(s.Date) AS yil, s.StoresId AS magaza,
       COUNT(*) AS adet,
       SUM(s.GrossTotal - s.DiscountTotal - s.VatTotal) AS net,
       AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN s.GrossTotal - s.DiscountTotal - s.VatTotal END) AS ort_sepet
FROM dbo.Sales s
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND ((s.Date >= '20250701' AND s.Date < '20250903')
    OR (s.Date >= '20260701' AND s.Date < '20260903'))
GROUP BY YEAR(s.Date), s.StoresId
ORDER BY 2, 1;
-- 1 Ist.Yolu 33.562->47.383 (+%41; net dusuk cunku Sinav burada)
-- 2 FSM      31.615->54.538 (+%72, net +%107)
-- 3 Ozluce   41.052->67.214 (+%64, net +%86)

-- ============ 6) MAGAZALAR · 31 AGUSTOS kesimi · sezonluk / kadrolu ayri ============
-- Lokasyon LIKE 'MA%' = yalniz MAGAZALAR (kafe/depo/merkez haric)
SELECT ISNULL(AltLokasyon,'(bos)') AS sube,
       SUM(CASE WHEN Kadro='SEZONLUK' AND Igt <= '20250831' AND (Ict IS NULL OR Ict >= '20250831') THEN 1 ELSE 0 END) AS sez_31Agu25,
       SUM(CASE WHEN Kadro='SEZONLUK' AND Igt <= '20260831' AND (Ict IS NULL OR Ict >= '20260831') THEN 1 ELSE 0 END) AS sez_31Agu26,
       SUM(CASE WHEN ISNULL(Kadro,'X')<>'SEZONLUK' AND Igt <= '20250831' AND (Ict IS NULL OR Ict >= '20250831') THEN 1 ELSE 0 END) AS kad_31Agu25,
       SUM(CASE WHEN ISNULL(Kadro,'X')<>'SEZONLUK' AND Igt <= '20260831' AND (Ict IS NULL OR Ict >= '20260831') THEN 1 ELSE 0 END) AS kad_31Agu26,
       -- 30 Haziran sezon-oncesi TABAN (kadrolu; magazalarda sezonluk pratikte 0)
       SUM(CASE WHEN ISNULL(Kadro,'X')<>'SEZONLUK' AND Igt <= '20250630' AND (Ict IS NULL OR Ict >= '20250630') THEN 1 ELSE 0 END) AS kad_30Haz25,
       SUM(CASE WHEN ISNULL(Kadro,'X')<>'SEZONLUK' AND Igt <= '20260630' AND (Ict IS NULL OR Ict >= '20260630') THEN 1 ELSE 0 END) AS kad_30Haz26
FROM dbo.vw_PersonelDepartman
WHERE Lokasyon LIKE 'MA%'
GROUP BY AltLokasyon
ORDER BY 3 DESC;
-- KRITIK BULGU: magazalarda kadrolu 30 Haz 150 -> 31 Agu 148 (sezon ICINDE -2; 2025'te de 133->132)
--   => 31 Agustos'taki +16 kadrolu fark sezon oncesinde +17 olarak KURULUYDU. Sezon alimi kadroyu buyutmedi.
--   Sezonluk magazalarda AZALDI: 64 -> 61.

-- ============ 7) ENGELLI personel (KVKK m.6 ozel nitelikli — toplulastirilmis) ============
-- Ayrac: perbilgi.Kanun='14857' (4857/30 engelli istihdam tesviki). Ozurlulukkodu OLU (aktifte 0 dolu).
-- perbilgi YALNIZ BKM_GENEL -> firma daraltmasi zorunlu (join fan-out onlemi).
SELECT ISNULL(v.Lokasyon,'(bos)') AS grup, ISNULL(v.AltLokasyon,'(bos)') AS sube,
       SUM(CASE WHEN v.Igt <= '20250831' AND (v.Ict IS NULL OR v.Ict >= '20250831') THEN 1 ELSE 0 END) AS engelli_31Agu25,
       SUM(CASE WHEN v.Igt <= '20260831' AND (v.Ict IS NULL OR v.Ict >= '20260831') THEN 1 ELSE 0 END) AS engelli_31Agu26
FROM dbo.vw_PersonelDepartman v
INNER JOIN dbo.perbilgi p
        ON p.Personelno = CASE WHEN CHARINDEX('-', v.Personelno) > 1
                                AND ISNUMERIC(LEFT(v.Personelno, CHARINDEX('-', v.Personelno)-1)) = 1
                               THEN CONVERT(int, LEFT(v.Personelno, CHARINDEX('-', v.Personelno)-1)) END
WHERE v.Personelno LIKE '%-BKM'
  AND LTRIM(RTRIM(CAST(p.Kanun AS nvarchar(20)))) = '14857'
GROUP BY v.Lokasyon, v.AltLokasyon
ORDER BY 4 DESC;
-- 31.08.2025: Ist.Yolu 1 · FSM 1 · (magaza disi: Genel Yonetim 1 · FSM Kafe 1) = toplam 4
-- 31.08.2026: Ist.Yolu 2 · FSM 1 · (magaza disi: FSM Kafe 1) = toplam 4  -> MAGAZALARDA 2 -> 3
-- Tamami Kadro='KADRO' (sezonluk degil). Bordro capraz-teyit: puanbil Kanunno='14857' Tem-2025/Agu-2025/Tem-2026 = 5 kisi.
-- ⚠ Agu-2026 puanbil HENUZ TAM DEGIL (05510 sadece 19 kisi) -> ay bordrosu islenmemis, Agu-2026 sayisi buradan okunmaz.

-- Aylik bordro teyidi (kanun no dagilimi)
SELECT pb.Yil, pb.Ayindex, LTRIM(RTRIM(pb.Kanunno)) AS kanunno, COUNT(*) AS kisi
FROM dbo.puanbil pb
WHERE ((pb.Yil = 2025 AND pb.Ayindex IN (7,8)) OR (pb.Yil = 2026 AND pb.Ayindex IN (7,8)))
  AND LTRIM(RTRIM(ISNULL(pb.Kanunno,''))) <> ''
GROUP BY pb.Yil, pb.Ayindex, LTRIM(RTRIM(pb.Kanunno))
ORDER BY 1, 2, 4 DESC;
-- 05510 = normal 5510 · 06111 = 6111 gencler/kadin tesviki · 14857 = ENGELLI · 00000 = tesviksiz

-- ⚠ YASAL KOTA RISKI (teyit gerekir): Is Kanunu m.30 -> 50+ isci calistiran ozel isyeri %3 engelli.
--   Kota SGK ISYERI SICILI bazinda hesaplanir, sirket toplami degil. BKM_GENEL aktif ~292 kisi;
--   tesvikli engelli 4-5 kisi. Tek sicil olsaydi kota ~9 kisi olurdu -> ACIK RISKI VAR ama
--   sicil kirilimi olmadan KESIN denemez. Dogrulama: SGK sicil bazli calisan + engelli sayisi (IK/muhasebe).

-- ============ 8) ETKINLIK personeli ============
SELECT ISNULL(Departman,'(bos)') AS departman, ISNULL(Unvan,'(bos)') AS unvan, ISNULL(AltLokasyon,'(bos)') AS sube,
       SUM(CASE WHEN Igt <= '20250831' AND (Ict IS NULL OR Ict >= '20250831') THEN 1 ELSE 0 END) AS aktif_31Agu25,
       SUM(CASE WHEN Igt <= '20260831' AND (Ict IS NULL OR Ict >= '20260831') THEN 1 ELSE 0 END) AS aktif_31Agu26
FROM dbo.vw_PersonelDepartman
WHERE Departman LIKE '%ETK%' OR Unvan LIKE '%ETK%' OR Unvan LIKE '%ORGAN%'
GROUP BY Departman, Unvan, AltLokasyon
ORDER BY 5 DESC;
-- ETKINLIK departmani magazalarda 31.08'de 2 kisi (2025 FSM+Ist.Yolu · 2026 Ozluce+Ist.Yolu), tamami KADRO.
-- OKUL TEMSILCISI departmani + PAZARLAMA/organizasyon: 31.08'de aktif 0.
-- Bordro-disi promotor/etkinlik destegi Zirve'de IZ BIRAKMIYOR -> varsa ayri kaynak gerekir (IK teyidi).

-- ============ 9) ENGELLI kadro ZAMAN SERISI (birim bazli, as-of) ============
-- Ayrac birlesik: Kanun='14857' (tesvikli) VEYA Ozurlulukkodu='E' (tesviksiz engelli izi).
-- KVKK m.6 ozel nitelikli -> yalniz sayim; isim/unvan raporda paylasilmaz.
SELECT ISNULL(v.AltLokasyon,'(bos)') AS sube,
       SUM(CASE WHEN v.Igt <= '20250630' AND (v.Ict IS NULL OR v.Ict >= '20250630') THEN 1 ELSE 0 END) AS d_30Haz25,
       SUM(CASE WHEN v.Igt <= '20250831' AND (v.Ict IS NULL OR v.Ict >= '20250831') THEN 1 ELSE 0 END) AS d_31Agu25,
       SUM(CASE WHEN v.Igt <= '20251231' AND (v.Ict IS NULL OR v.Ict >= '20251231') THEN 1 ELSE 0 END) AS d_31Ara25,
       SUM(CASE WHEN v.Igt <= '20260630' AND (v.Ict IS NULL OR v.Ict >= '20260630') THEN 1 ELSE 0 END) AS d_30Haz26,
       SUM(CASE WHEN v.Igt <= '20260831' AND (v.Ict IS NULL OR v.Ict >= '20260831') THEN 1 ELSE 0 END) AS d_31Agu26,
       SUM(CASE WHEN v.Ict IS NULL THEN 1 ELSE 0 END) AS bugun
FROM dbo.vw_PersonelDepartman v
INNER JOIN dbo.perbilgi p
        ON p.Personelno = CASE WHEN CHARINDEX('-', v.Personelno) > 1
                                AND ISNUMERIC(LEFT(v.Personelno, CHARINDEX('-', v.Personelno)-1)) = 1
                               THEN CONVERT(int, LEFT(v.Personelno, CHARINDEX('-', v.Personelno)-1)) END
WHERE v.Personelno LIKE '%-BKM'
  AND (LTRIM(RTRIM(CAST(p.Kanun AS nvarchar(20)))) = '14857'
    OR LTRIM(RTRIM(CAST(p.Ozurlulukkodu AS nvarchar(10)))) = 'E')
GROUP BY v.AltLokasyon
ORDER BY 3 DESC;
-- SIRKET TOPLAMI: 30.06.25=5 · 31.08.25=5 · 31.12.25=5 · 30.06.26=4 · 31.08.26=4 · bugun=4
-- GENEL MUDURLUK: 1 -> 0 (Idari Isler, tesvikli 14857, 28.04.2023-23.10.2025 = 909 gun; ayrica 2024'te 66 gunluk 2. istihdam)
-- MERKEZ DEPO: 1 -> 0 (Ozurlulukkodu='E' ama Kanun='00000' = TESVIKSIZ, 12.02.2025-30.11.2025)
-- IST.YOLU 1 -> 2 (tek ikame) · FSM 1 · FSM KAFE 1 sabit
-- ⚠ YON TERS: toplam kadro 325 -> 344 buyurken engelli 5 -> 4 dustu. %3 kota mantiginda artmasi gerekirdi.
--   Bos kadro Genel Mudurluk (Idari Isler/yemekhane) tarafinda -> kota+tesvik icin en kolay doldurulacak yer.

-- ============ 10) MAGAZA IS HACMI: fis + kalem + URUN ADEDI + ciro (1 Tem - 31 Agu) ============
-- Neden adet: ciro "fiyat artti" diye elestirilebilir, ELLECLENEN ADET elestirilemez (enflasyondan bagimsiz).
-- SalesProducts.IsValid=1 ZORUNLU. KDV-haric satir = TotalPrice - VatTotal (sema: entities.SalesProducts).
SELECT s.StoresId AS magaza, YEAR(s.Date) AS yil,
       COUNT(DISTINCT s.Id) AS fis,
       COUNT(*) AS kalem,
       SUM(sp.Amount) AS urun_adet,
       SUM(sp.TotalPrice - sp.VatTotal) AS net_kdvharic
FROM dbo.Sales s
INNER JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
WHERE s.DocumentsTypeId = 1                      -- yalniz perakende fis (magaza is yuku)
  AND ((s.Date >= '20250701' AND s.Date < '20250901')
    OR (s.Date >= '20260701' AND s.Date < '20260901'))
GROUP BY s.StoresId, YEAR(s.Date)
ORDER BY 1, 2;
-- 1 Ist.Yolu: fis 26.266->41.656 (+%59) · kalem 122.521->193.759 (+%58) · adet 148.478->232.556 (+%57) · net 19,44M->33,86M (+%74) | kadro 50->61 (+%22)
-- 2 FSM     : fis 28.121->50.936 (+%81) · kalem 105.423->196.374 (+%86) · adet 127.903->235.604 (+%84) · net 14,41M->32,21M (+%124) | kadro 40->43 (+%8)
-- 3 Ozluce  : fis 36.179->62.188 (+%72) · kalem 166.018->276.307 (+%66) · adet 200.400->326.764 (+%63) · net 24,06M->48,26M (+%101) | kadro 50->55 (+%10)
-- TOPLAM 3 magaza: fis +%71 · kalem +%69 · ADET +%67 · ciro +%97  vs  KADRO +%14 (140->159)
-- Kisi basi adet: 3.406 -> 5.000 (+%47) · kisi basi net ciro 413.643 -> 719.117 TL (+%74)
-- SEPET DERINLIGI SABIT: urun/fis 5,26 -> 5,14 · sepet tutari 640 -> 739 TL (+%15)
--   => "fis sayisi artti ama ayni musteriyi bolduniz" itirazi CURUR: sepet kucul-memis, buyumus.
-- Birim fiyat 121,5 -> 143,8 TL (+%18) = ciro artisinin fiyat kismi; kalan artis GERCEK HACIM.
-- ⚠ Heykel/Sura EncoreMerkez POS'ta YOK -> bu tablo 3 magaza; kadro karsilastirmasi da ayni 3 magaza.
-- ⚠ Kafe personeli AltLokasyon'da ayri sayilir ama kafe fisi magaza StoresId'sine dusuyorsa kisi-basi oran hafif sisebilir.

-- ##############################################################################
-- ⚠⚠ BLOK 10 GECERSIZ (SUPERSEDED 02.09.2026) — POS GECIS ARTEFAKTI
-- EncoreMerkez 2025 verisi 11-23.07.2025'te BASLIYOR (eski sistem INTER_BOS 22.07'de bitiyor).
-- Yani blok 10'un 2025 tarafi EKSIK -> +%67 adet / +%97 ciro SAHTE YUKSEK.
-- Dogru olcum: DerinSIS eTip 100 (iki yilda da tam), Sinav haric, OKUL-HIZALI pencere -> BLOK 11.
-- ##############################################################################

-- ⚠ 08.09.2026 DUZELTME NOTU (B-162/B-164): asagidaki blok `eTip = 100` TEK BASINA kullaniyor.
--   Olculdu: `eTip 4` (Magaza Satis) eTip 100'un DISINDA ayri kanal ve pratikte sadece Ist.Yolu'nda
--   (Sinav toplu faturalari). Sinav AYIKLANDIKTAN sonra bile Ist.Yolu +%2,7..4,4 eksik kaliyor;
--   iade (101/5) da netlenmiyor (-%0,4..1,0). Kanonik: eTip 100 − 101 + 4 − 5.
--   ETKI: 3 magaza TOPLAMINDA sapma +%0,5-0,6 -> bu bloktan cikan SONUC DEGISMEZ
--   (adet +%34,9 / ciro +%70,7 / kadro +%11,9 karsilastirmasi ayakta). Sube bazinda Ist.Yolu
--   bir miktar yukari kayar. Rakamlar patrona sunuldugu icin GERIYE DONUK DEGISTIRILMEDI;
--   yeniden uretilirse dogru formul kullanilmali. Bkz. sorgular/2026-09-08-okul-hizali-ciro-tahmini.sql blok 9.
-- ============ 11) DOGRU IS HACMI: DerinSIS eTip 100 + Sinav haric + OKUL-HIZALI ============
-- Kaynak DerinSIS (POS gecisinden bagimsiz). eTip 100 = POS satisi, gunluk ozet (fis sayisi YOK).
-- ehTutar KDV-HARIC; KDV-dahil icin + ehTutarKDV. Satista ehAdet negatif -> ABS.
-- Sinav ayiklamasi ZORUNLU: eTip 100 icinde Sinav Okullari/Kiyafet var (Ist.Yolu Agu-2026'nin %77'si).
-- Pencere: okul acilisina hizali (2025 = 08.09.2025, 2026 = 14.09.2026), gun ofseti -69..-14
--   => her iki yil da acilistan geriye 9. hafta ile 2. hafta arasi TAM 56 gun (haftalar birebir eslesir).
--   Takvim gunune gore kiyas YANLIS: 6 gunluk kayma Agustos'ta yapay dusus gosterir.
SELECT bs.eMekan AS mekan, YEAR(bs.eTarihS) AS yil,
       SUM(ABS(CAST(dt.ehAdet AS float)))                                 AS adet,
       SUM(CAST(dt.ehTutar - dt.ehIndirim AS float))                      AS net_kdvharic,
       SUM(CAST(dt.ehTutar - dt.ehIndirim + dt.ehTutarKDV AS float))      AS net_kdvdahil
FROM dbo.irs bs WITH(NOLOCK)
INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
WHERE bs.eTip = 100
  AND bs.eMekan IN (1, 4477, 4478)
  AND COALESCE(kat.Kategori3, 'x') NOT IN ('Sınav Okulları', 'Sınav Kıyafet')
  AND ((bs.eTarihS >= '20250701' AND bs.eTarihS <= '20250825'
        AND DATEDIFF(DAY, '20250908', bs.eTarihS) BETWEEN -69 AND -14)
    OR (bs.eTarihS >= '20260707' AND bs.eTarihS <= '20260831'
        AND DATEDIFF(DAY, '20260914', bs.eTarihS) BETWEEN -69 AND -14))
GROUP BY bs.eMekan, YEAR(bs.eTarihS)
ORDER BY 1, 2;
-- SONUC (KDV dahil):
--   1    FSM      : adet 170.555 -> 215.773 (+%26,5) · ciro 19,31M -> 31,33M (+%62,3) | kadro 42 -> 45
--   4477 Ozluce   : adet 230.765 -> 301.250 (+%30,5) · ciro 30,48M -> 48,02M (+%57,6) | kadro 51 -> 54
--   4478 Ist.Yolu : adet 173.398 -> 258.169 (+%48,9) · ciro 22,05M -> 43,25M (+%96,1) | kadro 50 -> 61
--   TOPLAM        : adet 574.718 -> 775.192 (+%34,9) · ciro 71,84M -> 122,60M (+%70,7) | kadro 143 -> 160 (+%11,9)
--   KDV haric ciro: 66,93M -> 114,69M (+%71,4)  => KDV buyume oranini degistirmiyor.
--   Kisi basi adet: 4.019 -> 4.845 (+%20,6) · kisi basi ciro 502K -> 766K TL (+%52,5)
--   => IS HACMI KADRONUN 3 KATI HIZLA BUYUDU (adet +%34,9 vs kadro +%11,9).

-- ============ 11b) Ayni sorgu Sinav KIRILIMLI (patron itirazi: "buyume kurumsaldan geldi") ============
-- Hizali pencerede Sinav: adet 12.075 -> 18.572 · ciro 53,51M -> 100,85M (+%88)  [Tem-Agu sezonluk zirve]
-- AMA Ocak-Agustos tam resminde Sinav KUCULDU:
--   Magaza: adet 2.752.385 -> 3.607.309 (+%31,1) · ciro 316,06M -> 489,43M (+%54,9)
--   Sinav : adet    33.584 ->    21.693 (-%35,4) · ciro 136,11M -> 105,58M (-%22,4)
--   => Buyumenin tamami raftan geldi; kurumsal dususu de magaza kapatti.
--   ⚠ Eski "toplam ciro 251M -> 249M sabit kaldi" iddiasi da EncoreMerkez artefakti -> GECERSIZ.
--   Gercek toplam (3 magaza POS, Oca-Agu): 452,17M -> 595,01M (+%31,6)

-- ============ 12) KIDEM -> VERIMLILIK TESTI (SONUC: VERI DESTEKLEMIYOR) ============
-- Soru: "1 tecrubeli adamin isini 3 acemi yapamaz" iddiasi rakamla dogrulanabilir mi?
-- Test A: AYNI kasiyerin ogrenme egrisi (ilk 14 gun / 15-44 gun / 45+ gun), kohort = ilk satisi 01.10.2025 sonrasi
SELECT CASE WHEN DATEDIFF(DAY, k.ilk, s.Date) < 14 THEN '1_ilk_14_gun'
            WHEN DATEDIFF(DAY, k.ilk, s.Date) < 45 THEN '2_15_44_gun'
            ELSE '3_45_gun_ustu' END AS donem,
       COUNT(DISTINCT s.UsersId) AS kasiyer,
       COUNT(*) AS fis,
       COUNT(DISTINCT CONVERT(varchar(12), s.UsersId) + '|' + CONVERT(varchar(8), s.Date, 112)) AS kasiyer_gun,
       CAST(SUM(CAST(s.GrossTotal - s.DiscountTotal - s.VatTotal AS float)) / COUNT(*) AS decimal(10,2)) AS ort_sepet_net,
       CAST(100.0 * SUM(CASE WHEN s.DiscountTotal > 0 THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,2)) AS indirimli_fis_yuzde
FROM dbo.Sales s WITH(NOLOCK)                                            -- EncoreMerkez
JOIN (SELECT UsersId, MIN(Date) AS ilk
      FROM dbo.Sales WITH(NOLOCK)
      WHERE DocumentsTypeId = 1 AND StoresId IN (1,2,3) AND Date >= '20250701'
      GROUP BY UsersId) k ON k.UsersId = s.UsersId
WHERE s.DocumentsTypeId = 1 AND s.StoresId IN (1,2,3)
  AND s.Date < '20260901' AND k.ilk >= '20251001'
GROUP BY CASE WHEN DATEDIFF(DAY, k.ilk, s.Date) < 14 THEN '1_ilk_14_gun'
              WHEN DATEDIFF(DAY, k.ilk, s.Date) < 45 THEN '2_15_44_gun'
              ELSE '3_45_gun_ustu' END
ORDER BY 1;
-- Ilk 14 gun : 40 kasiyer · 71.157 fis / 323 kasiyer-gun = 220 fis/gun · sepet 633,67 TL · indirimli %62,45
-- 15-44 gun  : 23 kasiyer · 100.652 fis / 394 = 256 fis/gun · sepet 582,66 TL · indirimli %62,07
-- 45+ gun    : 16 kasiyer · 306.120 fis / 1.264 = 242 fis/gun · sepet 602,61 TL · indirimli %63,37
-- => Kidem etkisi YOK: fis hizi ilk iki haftadan sonra +%16, sonra duz; SEPET ilk 14 gunde EN YUKSEK.
--    Sebep: kasa isi TALEP-SINIRLI (kuyruk kadar fis cekilir) -> beceri farki fis hizina yansimaz.
--
-- Test B: kasiyer HESABI bazli 2025 vs 2026 kiyasi OLCULEMEZ.
--   2025 Agu-Eyl aktif UsersId kumesi {2,4,7,8,10-17,21-47} · 2026 Tem-Agu kumesi {2,4,7,9-13,15,21-27,36,39,56-86}
--   -> kumeler neredeyse AYRIK (hesaplar yenilenmis/devir yuksek) + yuksek hacimli tezgahlar yeni hesaplarda.
--
-- Test C: magaza kidem derinligi vs verimlilik (n=3, ANEKDOT) — Zirve, 31.08.2026 aktif:
--   FSM      : ort kidem 1,35 yil · 1+ yil 16/45 (%36) · 5+ yil 5 · adet/kisi 4.795
--   Ozluce   : ort kidem 1,08 yil · 1+ yil 15/54 (%28) · 5+ yil 2 · adet/kisi 5.579
--   Ist.Yolu : ort kidem 0,86 yil · 1+ yil 19/61 (%31) · 5+ yil 0 · adet/kisi 4.232
--   => Siralama TUTMUYOR: en az tecrubeli-oranli magaza (Ozluce) EN VERIMLI. Ist.Yolu hem en kidemsiz
--      hem en dusuk verimli (iddiayi destekleyen tek nokta) ama n=3 -> kanit degil.
--
-- ⚠ NIHAI HUKUM: "1 tecrubeli = 3 acemi" iddiasi BU VERIYLE savunulamaz. Patron sayfasina KONULMADI.
--    Savunulabilir olan: (a) kisi basi verimlilik +%20,6 (kadro sismedi, mevcut kadro daha cok is yapti),
--    (b) sirkulasyon maliyeti: 32 kadrolu alimin 9'u 14 gunde ayrildi -> ayni pozisyon iki kez dolduruldu,
--    (c) Ist.Yolu'nda 5+ yil kidemli KIMSE YOK (yapisal risk; verimlilige yansimasi olculemedi).
