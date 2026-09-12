/* ============================================================================
   RAKİP FİYAT MOTORU — VAR, ÇALIŞIYOR, AMA KÖRLEŞMİŞ          (2026-09-12)
   DB: DerinSISBkm + BKMDATA (profil: erp)

   BULUŞ YOLU: kullanıcının elle sorgu arşivi (`D:/Belgelerim/sql`) →
   `ÖRÜMCEK DEĞİŞEN FİYATLAR RAPOR.sql` içinde yoruma alınmış bir JOIN:
     --JOIN BKMDATA.dbo.RakipFiyatAnalizBugun r ON r.stkID = ub.stkID
   Kullanıcı teyidi: "otomatik çalışıyordu o sistem örümcek çekip otomatik değişip
   siteye gidiyor".
   ============================================================================ */

/* ── 1) ZİNCİR ──────────────────────────────────────────────────────────────
     BKMDATA.bkmdata.list_has_price        ← ham kazıma (Barcode·Source·Price·CreatedDate)
       → BKMDATA.ent.RakipFiyatlari         PIVOT, 9 rakip sütunu, CreatedDate = BUGÜN
       → BKMDATA.dbo.RakipFiyatAnalizBugun  öneri view'ı
       → DerinSISBkm.ent.OrumcekFiyatAktar2 (SP) → ent.OrumcekBugunDegisenFiyatlar
     Girdi listesi: DerinSISBkm.ent.tsoft_rakip_takip (3.707 ürün — SEÇKİ, tüm katalog değil)
     Maliyet girdisi: BKMDATA.ent.OdakUrunMaliyet (643.951)
   ------------------------------------------------------------------------- */

/* ── 2) ★ FİYATLAMA KURALI — view tanımından OKUNDU (tahmin değil) ──────────
     RakipFiyat        = MIN(D&R, KitapYurdu)          en ucuz rakip
     DusulebilirFiyat  = ustFiyat / 2                  LİSTE FİYATININ YARISI = taban
     YeniFiyat         = IIF(DusulebilirFiyat < RakipFiyat,
                             RakipFiyat + 0.01,        ← rakibin BİR KURUŞ ÜSTÜ
                             DusulebilirFiyat)
     Süzgeç            = yalnız ustFiyat > RakipFiyat olan ürünler
   ⚠ `+0.01` yönü: view'de yoruma alınmış bir `RakipFiyat - 0.01` satırı da duruyor.
     Bilinçli mi kaza mı ÖLÇÜLEMEZ — BİR İŞ KARARIDIR, kullanıcıya sorulur.
   ------------------------------------------------------------------------- */
SELECT m.definition FROM BKMDATA.sys.sql_modules m
JOIN   BKMDATA.sys.objects o ON o.object_id = m.object_id
WHERE  o.name = 'RakipFiyatAnalizBugun';

/* ── 3) ⚠⚠⚠ MOTOR ÖLMEMİŞ, KÖRLEŞMİŞ — VE SESSİZ ──────────────────────────── */
SELECT 'tsoft_rakip_takip' AS kaynak, COUNT_BIG(*) AS satir FROM DerinSISBkm.ent.tsoft_rakip_takip
UNION ALL SELECT 'BKMDATA.ent.RakipFiyatlari',   COUNT_BIG(*) FROM BKMDATA.ent.RakipFiyatlari
UNION ALL SELECT 'RakipFiyatAnalizBugun',        COUNT_BIG(*) FROM BKMDATA.dbo.RakipFiyatAnalizBugun
UNION ALL SELECT 'BKMDATA.ent.OdakUrunMaliyet',  COUNT_BIG(*) FROM BKMDATA.ent.OdakUrunMaliyet;
/* tsoft_rakip_takip 3.707 · RakipFiyatlari 3.710 · **RakipFiyatAnalizBugun 0** ·
   OdakUrunMaliyet 643.951
   ⇒ Öneri view'ı SIFIR satır dönüyor. HATA YOK, UYARI YOK — ekranda "değişecek
     fiyat yok" gibi görünüyor. Sebep aşağıda. */

/* ── 4) ★ SEBEP: KAYNAK BAZINDA SON VERİ TARİHİ ────────────────────────────── */
SELECT [Source] AS kaynak, COUNT_BIG(*) AS satir,
       CONVERT(varchar(10),MIN(CreatedDate),120) AS ilk,
       CONVERT(varchar(10),MAX(CreatedDate),120) AS son
FROM   BKMDATA.bkmdata.list_has_price WITH(NOLOCK)
GROUP BY [Source] ORDER BY son DESC, satir DESC;
/* BKM Kitap      6.899.082  2021-11-17 .. **2026-09-12 (BUGÜN)**
   Kitapsepeti    5.808.482  2022-12-16 .. **2026-09-12 (BUGÜN)**
   Kitap Yurdu    3.164.391  2021-11-17 .. 2025-12-15
   İdefix         2.577.168  2021-11-17 .. 2025-12-15
   Kitap Seç      2.035.188  2021-11-17 .. 2025-12-15
   Amazon.com.tr  1.891.648  2021-11-17 .. 2025-12-15
   D&R            1.389.315  2021-11-17 .. 2024-03-04
   Ravza Kitap    1.500.818  2021-11-17 .. 2023-08-13
   Kidega           810.384  2021-11-17 .. 2023-08-13
   Kitap365         392.145  2021-11-17 .. 2022-09-02

   ⭐ DÖRT KAYNAK AYNI GÜN (2025-12-15) BİRDEN SUSMUŞ.
     ⇒ Tek tek "site bizi blokladı" DEĞİL — TEK BİR OLAY (ağ / altyapı / sağlayıcı).
       Sebebi veritabanından ÖLÇÜLEMEZ; BEYAN EDİLDİ.
   ⚠ Öneri view'ı yalnız D&R + KitapYurdu kullanıyor; ikisi de ÖLÜ.
     ⇒ Otomatik yeniden fiyatlama D&R için 2024-03'ten, KitapYurdu için 2025-12'den
       beri HİÇBİR ÖNERİ ÜRETMİYOR. İki yıldır kör, ekranda sağlıklı. */

SELECT CONVERT(varchar(10),CreatedDate,120) AS gun, COUNT_BIG(*) AS satir,
       COUNT(DISTINCT [Source]) AS kaynak
FROM   BKMDATA.bkmdata.list_has_price WITH(NOLOCK)
WHERE  CreatedDate >= DATEADD(DAY,-7,GETDATE())
GROUP BY CONVERT(varchar(10),CreatedDate,120) ORDER BY gun DESC;
/* Son 7 gün: günde 7.416-7.434 satır, **2 kaynak** — kesintisiz.
   ⭐ TOPLAMA ALTYAPISI ÇALIŞIYOR. Sorun "kazıyıcı bozuk" değil, HEDEF LİSTESİ DARALMIŞ.
   ⇒ EN UCUZ ONARIM: öneri view'ını `Kitapsepeti`yi de kullanacak şekilde genişletmek.
     Veri ZATEN geliyor; güvenlik duvarı / kazıma sorununa HİÇ dokunmadan motor dirilir. */

/* ── 5) ★ HEDEF MARJ İKİ KADEMELİ — veride yazılı, kullanılmıyor ───────────── */
SELECT piyasaMarj AS marj, COUNT_BIG(*) AS urun
FROM   DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE urnTip = 0
GROUP BY piyasaMarj ORDER BY urun DESC;
/* %35 → 131.816 · %20 → 97.479 · %30 → 83.026 · **%0 → 81.035 (yalnız ~%10)** ·
   %25 → 49.776 · %40 → 45.803 · %23 → 36.742 · %15 → 33.338 · %10 → 29.982 …
   ⇒ Katalogun ~%90'ında HEDEF MARJ yazılı. Fiili marjı hedefle karşılaştıran bir
     analiz bugün YAPILMIYOR — veri hazır. */

SELECT mrkPiyasaMarjOndeger AS marj, COUNT(*) AS marka
FROM   DerinSISBkm.dbo.urnMrk WITH(NOLOCK)
GROUP BY mrkPiyasaMarjOndeger ORDER BY marka DESC;
/* 0 → 5.460 marka · %27 → 746 · %17 → 655 · %22 → 542 · %25 → 378 · %30 → 259 …
   ⇒ 10.300 markanın 4.840'ında MARKA BAZLI ÖNDEĞER var.
   ⚠ Ürün mü markayı ezer, boşsa markadan mı düşer — ÖLÇÜLMEDİ (şifreli fiyat
     fonksiyonlarının içinde). Açık soru.
   ⚠ `piyasaMarj` bir HEDEFtir, GERÇEKLEŞEN marj DEĞİL. Karıştırılmaz.
   (Kaynak ipucu: D:/Belgelerim/sql/PiyasaMarjListesi.sql) */

/* ── 6) ★ FİYAT DEĞİŞİM BELGESİ: dbo.fytB — %94'Ü OTOMATİK ────────────────── */
/* fyt.fhID ve fytOzl.fhID → fytB.feID ; fytMkn.fhmID → belgenin MEKAN listesi
   (fytTip=2 "Mekansal Fiyat" mekanizması).
   Onay akışı: gKisi/gTarih (giren) · kKisi/kTarih (kaydeden) · oKisi/oTarih (ONAYLAYAN) */
SELECT b.feNeden AS neden_kod, n.fnAd AS neden, COUNT_BIG(*) AS belge,
       SUM(CASE WHEN b.feOnay = 1 THEN 1 ELSE 0 END) AS onayli
FROM   DerinSISBkm.dbo.fytB b WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.fytNdn n WITH(NOLOCK) ON n.fnID = b.feNeden
WHERE  b.feTarihA >= DATEADD(YEAR,-2,GETDATE())
GROUP BY b.feNeden, n.fnAd ORDER BY belge DESC;
/* Son 2 yıl, 86.192 belge:
     4 "Emek Entegrasyon"      81.113  (%94,1)   onaylı 81.113
     0 "Normal fiyat geçiş"     5.077  (%5,9)    onaylı 5.077
     5 "Firma Marka Otomatik"       2            onaylı 2
     3 "REKABET"                    0  ← HİÇ KULLANILMAMIŞ
   ⇒ Fiyat kararlarının %94'ü bir ENTEGRASYONDAN geliyor, insan kararından değil.
   ⇒ "Rekabet" kodu tanımlı ama ÖLÜ — rakip-fiyat motorunun körleşmesiyle TUTARLI.
   ⚠ Belgelerin TAMAMI feOnay=1 (86.192/86.192) → onay adımı pratikte bir KONTROL
     DEĞİL, otomatik damga. Tasarım mı arıza mı ÖLÇÜLMEDİ. */

/* ============================================================================
   ÖZET — ÜÇ SESSİZ DURUM
   1. Öneri view'ı 0 satır dönüyor ve HATA VERMİYOR (girdileri ölü).
   2. "Rekabet" neden kodu tanımlı ama hiç kullanılmamış.
   3. Onay adımı %100 onaylı — kontrol gibi duruyor, kontrol değil.
   Üçü de ekranda SAĞLIKLI görünür.
   ============================================================================ */
