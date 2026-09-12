/* ============================================================================
   ZİRVE (BKM_GENEL) — İK/BORDRO GERÇEKLERİ, KULLANICININ ELLE SORGULARINDAN
   (2026-09-12) · profil: zirve (pyodbc, 192.168.40.25\ZRVSQL2008)

   KAYNAK: kullanıcı `D:/Belgelerim/sql`i işaret etti — 322 elle yazılmış `.sql`.
   "PERSONEL" ile başlayan 13 dosyanın TAMAMI Zirve sorgusu (kullanıcı teyidi).
   Ayrıca `vw_PersonelDepartman`ın TAM TANIMINI kullanıcı doğrudan verdi.

   ⚠ YÖNTEM NOTU: bu dosyalar KANIT DEĞİL, İPUCUDUR. Her iddia canlı ölçümle
     doğrulandı; doğrulanamayanlar BEYAN edildi.
   ⚠ `PERSONEL *` dosyaları kişisel veri bağlamı taşır (ad/TC/ücret) — depoya
     KOPYALANMADI; yalnız ŞEMA GERÇEĞİ ve İŞ KURALI alındı.
   ============================================================================ */

/* ── 1) `vw_PersonelDepartman` TANIMI (kullanıcıdan) — ÜÇ VERİTABANI UNION'U ──
   Üç kol, aynı şekil:
     FROM [BURSA_KÜLTÜR_MERKEZİ_GENEL].dbo.perbilgi   → Firma='BURSA_KÜLTÜR_MERKEZİ'
     FROM [ASİYE_BİNGÖLBALI_GENEL].dbo.perbilgi       → Firma='ASİYE_BİNGÖLBALI'
     FROM perbilgi (yerel BKM_GENEL)                  → Firma='BKM_GENEL'
   Her kolda:  WHERE p.Ict > DATEFROMPARTS(2023,12,31) OR p.Ict IS NULL

   ⭐ `Personelno` EKİ VIEW'DE ÜRETİLİYOR, SAKLANMIYOR:
        CAST(p.Personelno AS VARCHAR(10)) + '-BKMH' | '-ABG' | '-BKM'
      ⇒ ham `perbilgi`de ek YOK; '1108-BKM' diye arayan sorgu BOŞ döner.

   ⭐ KOLON EŞLEMESİ (satıcı adı → view adı) — hepsi yeniden amaçlandırılmış:
        SeriNo       → Lokasyon        (satıcı: nüfus cüzdanı seri no)
        Grupkodu     → AltLokasyon
        Ckn          → AltAltLokasyon  (satıcı: cüzdan kayıt no)
        Meslekilcesi → Departman       (satıcı: meslek ilçesi)
        Gorevi       → Unvan
        **A4         → Kadro**         (satıcı: nüfusa kayıtlı olduğu mah/köy)
        Icn→IstenCikisKodu · Kanun→KanunNo · ts→TahakkukSekli · Od→OgrenimDurumu ·
        Bankaadi→Banka · A7→PrimTutari · Maas→Ucret

   ⭐ SINIRI DELEN NOKTA: rapor login'i yalnız BKM_GENEL'e erişiyor, ama view
      diğer iki firmanın veritabanını okuyor (view sahibinin yetkisiyle).
      Diğer iki firmanın verisine ULAŞILAN TEK YOL bu view.

   ⚠ PENCERE DONMUŞ: `2023-12-31` SABİT, kayan pencere DEĞİL. View zamanla yalnız
     BÜYÜR; **2024 öncesi ayrılanlar KALICI OLARAK GÖRÜNMEZ.**
*/

/* ── 2) ★★★ AYNI KOLON, İKİ ANLAM — AYIRICI SATIRIN YAŞI ────────────────────── */
SELECT CASE WHEN (Ict > DATEFROMPARTS(2023,12,31) OR Ict IS NULL)
            THEN 'VIEW ICINDE' ELSE 'VIEW DISINDA' END AS pencere,
       COUNT(*) AS satir, COUNT(DISTINCT Serino) AS tekil_serino,
       MIN(Serino) AS ornek_min, MAX(Serino) AS ornek_max
FROM   dbo.perbilgi
GROUP BY CASE WHEN (Ict > DATEFROMPARTS(2023,12,31) OR Ict IS NULL)
              THEN 'VIEW ICINDE' ELSE 'VIEW DISINDA' END;
/* VIEW İÇİNDE  1.103 satır · Serino **3 tekil** → GENEL MÜDÜRLÜK · MAĞAZALAR · KAFELER
   VIEW DIŞINDA 2.475 satır · Serino **146 tekil** → gerçek kimlik seri no ('Z11-221600') */

SELECT CASE WHEN (Ict > DATEFROMPARTS(2023,12,31) OR Ict IS NULL)
            THEN 'ICINDE' ELSE 'DISINDA' END AS pencere,
       A4 AS a4, COUNT(*) AS satir
FROM   dbo.perbilgi
GROUP BY CASE WHEN (Ict > DATEFROMPARTS(2023,12,31) OR Ict IS NULL)
              THEN 'ICINDE' ELSE 'DISINDA' END, A4
ORDER BY satir DESC;
/* İÇİNDE (istihdam tipi, TEMİZ):  KADRO 875 · SEZONLUK 212 · NULL 8 · '' 3
   DIŞINDA (KARIŞIK):              KADRO 1.370 · PART-TİME 214 · SEZONLUK 183 ·
     ÜCRETSİZ 26 · STAJYER 19 · BELİRLİ 5
     **+ KÖY/MAHALLE ADLARI**: ELMASBAHÇELER · KALEDERE · KALBURCU · KÜÇÜKDERE ·
     VAKIF MAHALLESİ · YOĞUNOLUK MAHALLESİ · ADABÜK MAHALLESİ · AKIMLI KÖYÜ ·
     BAŞKÖY KÖYÜ · BULUGÖZE KÖYÜ · ÇİRİŞHANE · TEPE · BAHAR …

   ⇒ İK bu kolonları BİR TARİHTE DEVRALDI; eski kayıtlar satıcının orijinal anlamını
     taşımaya devam ediyor. View'in `Ict > 2023-12-31` süzgeci — amacı bu olmasa da —
     pratikte ANLAM SINIRIYLA ÇAKIŞIYOR.
   ⇒ **KURAL: `perbilgi`ye DOĞRUDAN inen hiçbir kadro/istihdam sorgusu yazılmaz.**
     Ham tabloda `GROUP BY A4` yapan bir kadro raporu "ELMASBAHÇELER"i bir istihdam
     tipi olarak sayar — hata vermez, kova yanlıştır.
   ⇒ `kadro-etiket-kumesi-kapali` değişmezinin NEDEN view üstünde koşması gerektiğinin
     kanıtı: ham tabloda koşsaydı onlarca sahte "etiket" görüp sürekli kırmızı verirdi.
   ⚠ `PART-TİME` (Türkçe İ) ÜÇÜNCÜ yazım — view'de `PART TIME` ve `PART-TIME` da var.
     Aynı kavram üç yazım; mükerrer-etiket tuzağı (aynı gün DerinSIS'te `urn.kod2ID`
     alıcı kodunda da ölçüldü). */

/* Kullanıcının kontrol sorgusundaki takma adlar BAYAT SANILDI, ÖLÇÜLDÜ, ESKİ VERİDE
   DOĞRU ÇIKTI:  `Kadro AS [Nüf.Kay.Old.Mah/Köy]` · `Lokasyon AS [Nüf.Cüz.Seri No]` ·
   `AltAltLokasyon AS [Cüzdan Kayıt No]` · `Departman AS [Meslek İlçesi]`
   ⇒ Elle yazılmış sorgudaki "yanlış görünen" ayrıntı bile bir GERÇEĞİN İZİ olabiliyor. */

/* ── 3) Kadro değer kümesi (VIEW üstünde — doğru yer) ───────────────────────── */
SELECT TOP 15 Kadro, COUNT(*) AS kisi
FROM   dbo.vw_PersonelDepartman GROUP BY Kadro ORDER BY kisi DESC;
/* KADRO 976 · SEZONLUK 302 · NULL 10 · '' 3 · STAJYER 2 · PART TIME 1 · PART-TIME 1 ·
   KISMİ 1 → değişmez `kadro-etiket-kumesi-kapali` yedisini de tanıyor (yeni etiket YOK) */

/* ── 4) ★ ORGANİZASYON + KAFELER İSTİSNASI ──────────────────────────────────── */
SELECT Lokasyon, COUNT(*) AS kisi, COUNT(DISTINCT AltLokasyon) AS alt,
       COUNT(DISTINCT AltAltLokasyon) AS altalt
FROM   dbo.vw_PersonelDepartman GROUP BY Lokasyon ORDER BY kisi DESC;
/* MAĞAZALAR 816 (8/6) · KAFELER 315 (3/3) · GENEL MÜDÜRLÜK 162 (3/18) · NULL 3 */

SELECT TOP 12 Departman, Unvan, COUNT(*) AS kisi
FROM   dbo.vw_PersonelDepartman WHERE Lokasyon='KAFELER'
GROUP BY Departman, Unvan ORDER BY kisi DESC;
/* Departman yalnız KAFE · KASA · MUTFAK (3 kaba değer, 315 kişiyi ayırmıyor)
   Unvan ise ayırıyor: GARSON 137 · BARİSTA 55 · KASİYER 44 · AŞÇI YARDIMCISI 34 ·
   ŞEF GARSON 16 · MUTFAK ŞEFİ 6 · BULAŞIKÇI 6 · AŞÇI 2 …
   ⇒ Kullanıcının raporundaki kural:
     `CASE WHEN d.Lokasyon = 'KAFELER' THEN d.Unvan ELSE d.Departman END AS Departman`
   ⇒ "Kolon yeniden amaçlandırma" DEĞİL, KIRILIM DERİNLİĞİ UYUŞMAZLIĞI.
     Bu CASE'i taşımayan departman raporu 315 kişiyi üç kovaya yığar ve hata vermez. */

/* ── 5) ★ AS-OF KADRO ŞARTI + KİŞİ ANAHTARI (kullanıcının kanonik raporundan) ── */
/*   WHERE (d.Ict >= @Tarih OR d.Ict IS NULL) AND d.Igt <= @Tarih
     İki as-of tarihi AYNI şartla koşturulup PIVOT edilir, fark alınır.
     Kişi eşlemesi:
       FULL OUTER JOIN ... ON gy.[Tc Kimlik No] = buyil.[Tc Kimlik No]
     ⭐ `Vatno` (TC) ile — `Personelno` ile DEĞİL. Sebebi ölçülmüş:
       `Personelno` çalışma DÖNEMİ kimliği (1.296 numara ↔ 1.162 TC); tekrar işe
       girenler `Personelno` ile eşlenirse İKİ AYRI KİŞİ sayılır. */

/* ── 6) Personelno firma eki (view üretimi, ölçümle teyit) ──────────────────── */
SELECT RIGHT(Personelno, CHARINDEX('-', REVERSE(Personelno)+'-')-1) AS ek,
       Firma, COUNT(*) AS kisi
FROM   dbo.vw_PersonelDepartman
GROUP BY RIGHT(Personelno, CHARINDEX('-', REVERSE(Personelno)+'-')-1), Firma
ORDER BY kisi DESC;
/* -BKM → BKM_GENEL 1.103 · -BKMH → BURSA_KÜLTÜR_MERKEZİ 145 · -ABG → ASİYE_BİNGÖLBALI 48
   Çapraz eşleşme YOK (1:1). ⇒ ek FİRMAYI, numara DÖNEMİ, Vatno KİŞİYİ ayırır. */

/* ── 7) BORDRO KALEM JOIN ANAHTARI (kontrol sorgusundan) ────────────────────── */
/*   vw_PuanBil b
     LEFT JOIN vw_PerKBil k ON k.Personelno=b.Personelno AND k.Yil=b.Yil
            AND k.Ayindex=b.Ayindex AND k.Fsk=b.Fsk AND k.Puantajno=b.Puantajno
     LEFT JOIN vw_PerOBil o ON (aynı beşli)
   KESİNTİ türleri: BES_KESINTISI · EK_KESINTI · ICRA_KESINTISI · AVANS · PRIM_AVANS ·
                    TRAFIK_CEZASI · YILLIK_IZIN_AVANS
   ÖDEME türleri  : PRIM · YILLIK_IZIN · YOL_UCRETI · YEMEK · EK_ODEME
   ⭐ Personel maliyeti = `b.bt + b.Isskk + b.Iisk` — sema'daki formülün BAĞIMSIZ teyidi. */
SELECT 'vw_PerKBil-5li' AS t, COUNT(*) AS mukerrer FROM (
    SELECT Personelno,Yil,Ayindex,Fsk,Puantajno FROM dbo.vw_PerKBil
    GROUP BY Personelno,Yil,Ayindex,Fsk,Puantajno HAVING COUNT(*)>1) z
UNION ALL SELECT 'vw_PerKBil-4lu (Puantajno YOK)', COUNT(*) FROM (
    SELECT Personelno,Yil,Ayindex,Fsk FROM dbo.vw_PerKBil
    GROUP BY Personelno,Yil,Ayindex,Fsk HAVING COUNT(*)>1) y;
/* 5'li → 1 mükerrer grup · 4'lü → 1 (FARK YOK)
   ⇒ `Puantajno` bu veride ayırt edicilik KATMIYOR ve mükerrerlik ondan gelmiyor.
     Tek grup olduğu için etkisi küçük ama LEFT JOIN o kişi-ayda satır ÇOĞALTIR.
     Sebebi ÖLÇÜLMEDİ (açık soru). */

/* ── 8) Kadro kaynağını ararken ELENEN adaylar (negatif sonuç da bilgidir) ──── */
/*   `perbilgi`nin 130+ metin kolonundan 34 aday tarandı; `A4` bulunmadan önce
     elenenler ve GERÇEK anlamları:
       Koy            → BOŞ (1 tekil)
       Mek1..Mek14 / Agikod → MUHASEBE HESAP KODU (770.01.001 · 335.01.001 · 361.01.002)
       Nkoi / Nkoil / Dy    → gerçekten nüfus/doğum yeri (YOZGAT · ZİLE · ZONGULDAK)
       Meslekilcesi   → 77 tekil, "YÖNETİM"      (view'de Departman)
       Meslekili      → 64 tekil, "YAZILIM"
       Grupkodu       → 16 tekil, "ÖZLÜCE KAFE"  (view'de AltLokasyon)
       Masrafmerkezi  →  9 tekil, "ÖZLÜCE"
       Gorevi         → 151 tekil, unvan         (view'de Unvan)
       Uadi/Mes/Mg/Od → ülke/meslek/medeni hal/öğrenim
     ⇒ Hiçbiri 'SEZONLUK' taşımıyordu; doğru cevap (`A4`) ancak VIEW TANIMI görülünce
       çıktı. DERS: tanımı okunamayan bir view'de kaynak kolonu veriden aramak
       pahalı ve eksik kalıyor — `GRANT VIEW DEFINITION` tek sorgu ile çözer. */
