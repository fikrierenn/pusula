/* ============================================================================
   ODAK FİYAT / ÜRÜN OTOMASYONU — "%94'ü otomatik" bulgusunun KAYNAĞI  (2026-09-12)
   DB: DerinSISBkm + BKMDATA (profil: erp)

   Kullanıcı işaret etti: "otomatik odak fiyatlarını çekip aktaran SP'ler var,
   otomatik ürün açıyor fiyat yapıyor". Doğru çıktı — ve fiyat belgelerinin
   %94'ünü yazan motor bu.
   ============================================================================ */

/* ── 1) ODAK YÜZEYİ — iki DB, 60+ nesne, kritik SP'ler ŞİFRESİZ ─────────────── */
SELECT 'DerinSISBkm' AS db, s.name+'.'+o.name AS obje, o.type_desc AS tip,
       ISNULL((SELECT MAX(CASE WHEN p.index_id IN (0,1) THEN p.rows END)
               FROM DerinSISBkm.sys.partitions p WHERE p.object_id=o.object_id),-1) AS satir,
       CONVERT(varchar(10),o.modify_date,120) AS degisim,
       OBJECTPROPERTY(o.object_id,'IsEncrypted') AS sifreli
FROM   DerinSISBkm.sys.objects o JOIN DerinSISBkm.sys.schemas s ON s.schema_id=o.schema_id
WHERE  o.name LIKE '%odak%' AND o.type IN ('U','V','P','FN','IF','TF')
UNION ALL
SELECT 'BKMDATA', s.name+'.'+o.name, o.type_desc,
       ISNULL((SELECT MAX(CASE WHEN p.index_id IN (0,1) THEN p.rows END)
               FROM BKMDATA.sys.partitions p WHERE p.object_id=o.object_id),-1),
       CONVERT(varchar(10),o.modify_date,120),
       OBJECTPROPERTY(o.object_id,'IsEncrypted')
FROM   BKMDATA.sys.objects o JOIN BKMDATA.sys.schemas s ON s.schema_id=o.schema_id
WHERE  o.name LIKE '%odak%' AND o.type IN ('U','V','P','FN','IF','TF')
ORDER BY db, obje;
/* BUGÜN GÜNCELLENEN TABLOLAR: ent.odak_urun 644.856 · odak_urun_tam 645.381 ·
   odak_urun_magaza_tam 645.128 · dbo.OdakUrunDurum 646.872 · stok_aktarim_odak 498.054 ·
   DerinSISBkm.ent.odak_depo_Stok 497.527
   **dbo.OdakStokDegisenStok_Log 92.392.737 satır** (dün)
   ⇒ ODAK yalnız fiyat değil; STOK ve ÜRÜN AÇMA hattı da.

   ŞİFRESİZ (IsEncrypted=0) VE YENİ OTOMASYON SP'LERİ:
     ent.odakUrunAktar                      2026-09-09   ÜRÜN AKTARIMI
     bkm.OdakUrunlerineGoreTsoftUrunAc      2026-08-31   OTOMATİK ÜRÜN AÇMA
     ent.OdakUrunGuncellemeEslestir         2026-07-22
     ent.odakFiyatAktarim                   2026-05-22   FİYAT AKTARIMI  ← blok 2
     bkm.OdakSatisIrsaliyeFiyatOlustur      2026-02-24
     bkm.OdakTukendileriTukendiYap          2025-06-18
     bkm.OdaktaDatasiOlupMarjiSorunluUrunler (VIEW) 2025-09-02
   ⚠ Yalnız `odakFiyatAktarim` OKUNDU; diğerlerinin içeriği HENÜZ OKUNMADI. */

/* ── 2) ★★ ent.odakFiyatAktarim — TAM MANTIK (7.334 karakter, şifresiz) ─────── */
SELECT m.definition FROM DerinSISBkm.sys.sql_modules m
JOIN   DerinSISBkm.sys.objects o ON o.object_id=m.object_id
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id=o.schema_id
WHERE  s.name='ent' AND o.name='odakFiyatAktarim';
/* AKIŞ:
     BKMDATA.ent.odak_urun_tam.etiket_fiyat
       → barkod köprüsü (urnBrkd.urnBarkod = odak.barkod)
       → urn.fiyatS ile FARKLI olanlar seçilir
       → fytB başlığı + fytOzl satırları YAZILIR
       → EXEC posAktPlanli_yaz 10, @gun   (tarihsel fiyat ETKİNLEŞTİRİLİR, POS'a iner)

   HER ÜRÜN İÇİN İKİ SATIR:
     fTur=1 (Son Alış) — fInd1..3 iskontolarıyla
     fTur=0 (Satış)    — indirimsiz
     ikisi de fTip=1 (Tarihsel)

   BAŞLIK SABİTLERİ:
     feNeden = 4  ("Emek Entegrasyon")
     feNot   = SUBSTRING(frmAd,1,10) + ' Odak2 Ent'
     **feOnay = 1 DOĞRUDAN YAZILIYOR**
     gKisi = kKisi = oKisi = 137
   ⇒ "Onay adımı %100 onaylı" bulgusunun SEBEBİ BU: onay bir insan kararı değil,
     SP'nin sabit yazdığı bir 1. oKisi=137 bir sistem hesabı.

   DİĞER MANTIK:
     · bkm.CiftUrunlerMaxFyat — çift ürünlerde MAX fiyat; bir dalda −0,01
     · odak.etiket_fiyat < 999999 · odak.SilinecekUrun = 0  (koruma süzgeçleri)
     · Marka iskontosu BKMDATA.ent.odak_marka.discount → fInd1, YALNIZ firmaID=9525
       (ODAK-POINT); diğerlerinde sakMrk.skY1..3
     · İkinci blok "marka iskonto oranı değişenler"i ayrıca yakalar (fInd1 <> mar.discount)
       ⇒ fiyat aynı kalsa bile İSKONTO değişimi belge üretir
     · Koşum sonunda ent.ProcedureLogEkle → BKMDATA.dbo.OdakDataProcedureRunTime */

/* ── 3) ⚠ VARSAYILAN KAPALI AMA KOŞUYOR ─────────────────────────────────────── */
/* İmza: CREATE PROCEDURE [ent].[odakFiyatAktarim] @cikis bit = 1
   İlk satır: if @cikis = 1 return 0
   ⇒ Parametresiz çağrılırsa HİÇBİR ŞEY YAPMAZ. Peki koşuyor mu? */
SELECT CONVERT(varchar(7),feTarihA,120) AS ay, COUNT_BIG(*) AS belge
FROM   DerinSISBkm.dbo.fytB WITH(NOLOCK)
WHERE  feNot LIKE '%Odak2 Ent%' AND feTarihA >= DATEADD(MONTH,-8,GETDATE())
GROUP BY CONVERT(varchar(7),feTarihA,120) ORDER BY ay DESC;
/* 2026-09 1.506 · 08 3.539 · 07 3.075 · 06 3.026 · 05 2.424 · 04 3.292 ·
   03 3.272 · 02 3.450 · 01 2.559
   ⇒ KOŞUYOR — çağıran taraf @cikis=0 geçiyor, guard etkisiz.
   ⚠ Çağıranın kim olduğu (SQL job / başka SP) ÖLÇÜLMEDİ — açık soru. */

/* ── 4) ★★ İKİ ELLE HARİÇ TUTMA BAYRAĞI (dbo.urnBilgi) ─────────────────────── */
SELECT bBilgiID, bDeger, COUNT_BIG(*) AS urun
FROM   DerinSISBkm.dbo.urnBilgi WITH(NOLOCK)
WHERE  bBilgiID IN (220,228)
GROUP BY bBilgiID, bDeger ORDER BY bBilgiID, urun DESC;
/* 220 = True →     781 ürün  → fiyat değişim kümesinden TAMAMEN çıkarılır
   228 = True → 114.967 ürün  → yalnız ALIŞ satırı (fTur=1) YAZILMAZ
   (220=False 744 · 228=False 10)
   ⚠ 228, katalogun ~%14'ü. Sema'nın kanonik MALİYET yolu fytOzl fTur=1/fTip=1
     olduğu için bu bayrak doğrudan maliyeti besleyen satırı kesiyor. */

/* ── 5) ★★★ BAYRAK ↔ MALİYET TAZELİĞİ + ALTERNATİF AÇIKLAMA SINAMASI ───────── */
SELECT CASE WHEN ub.bVeriID IS NULL THEN 'bayraksiz' ELSE 'bayrak 228' END AS durum,
       CASE WHEN od.barkod IS NULL THEN 'ODAKta YOK' ELSE 'ODAKta VAR' END AS odak,
       COUNT_BIG(*) AS urun,
       CONVERT(decimal(5,1), 100.0*SUM(CASE WHEN b.MaliyetTarih >= DATEADD(MONTH,-6,GETDATE())
                                            THEN 1 ELSE 0 END)/COUNT_BIG(*)) AS taze_yuzde
FROM   DerinSISBkm.bkm.SatisAnaliziTaban b WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urnBilgi ub WITH(NOLOCK)
       ON ub.bVeriID = b.stkID AND ub.bBilgiID = 228 AND ub.bDeger = 'True'
OUTER APPLY (SELECT TOP 1 o.barkod
             FROM DerinSISBkm.dbo.urnBrkd br WITH(NOLOCK)
             JOIN BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) ON o.barkod = br.urnBarkod
             WHERE br.urnBrkdStkID = b.stkID) od
WHERE  b.Kesim = '20260911' AND b.BirimMaliyet > 0
GROUP BY CASE WHEN ub.bVeriID IS NULL THEN 'bayraksiz' ELSE 'bayrak 228' END,
         CASE WHEN od.barkod IS NULL THEN 'ODAKta YOK' ELSE 'ODAKta VAR' END
ORDER BY durum, odak;
/* bayrak 228 + ODAK'ta VAR    14.780 ürün → **%24,9** taze maliyet
   bayraksız  + ODAK'ta VAR   188.559      → **%35,6**
   bayrak 228 + ODAK'ta YOK    20.021      → %11,1
   bayraksız  + ODAK'ta YOK    18.528      → %33,7

   ⇒ ALTERNATİF AÇIKLAMA SINANDI ve KISMEN ELENDİ:
     "bayraklı ürünler zaten ODAK'ta yoktur, o yüzden maliyetsizdir" denebilirdi.
     Ama ODAK'ta verisi OLAN ürünler arasında bile bayrak tazeliği
     %35,6 → %24,9'a düşürüyor (≈11 puan). BAYRAĞIN BAĞIMSIZ ETKİSİ VAR.
   ⇒ Ama bayrak TEK sebep de DEĞİL: ODAK'ta olmayan bayraksız ürünler %33,7 ile
     sağlıklı ⇒ ODAK dışında da çalışan bir maliyet kaynağı var.
   ⚠ Bayrakların NEDEN konduğu (hangi iş kuralı) ÖLÇÜLMEDİ. 114.967 ürünün gözden
     geçirilmesi bir İŞ KARARIDIR — ölçüm yalnız bedelini gösteriyor. */

/* ============================================================================
   ZİNCİR — üç ayrı bulgu tek sebebe bağlandı
     ent.odakFiyatAktarim  → feNeden=4 yazıyor  → fytB'de %94 "Emek Entegrasyon"
                           → feOnay=1 sabit     → "onay %100" (kontrol değil, damga)
                           → 228 bayrağı fTur=1 satırını keser
                                                → maliyet bayatlar
                                                → marj/ölü stok/envanter rakamı kayar
   ============================================================================ */
