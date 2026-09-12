/* ============================================================================
   FİYAT ALT SİSTEMİ (kara kutu) + ZİRVE VIEW TANIMLARI (açıldı)   2026-09-12
   DB: DerinSISBkm (profil: erp) · BKM_GENEL (profil: zirve)

   Devamı: sorgular/2026-09-12-sifreli-erp-viewlari.sql
   ============================================================================ */

/* ── 1) ⚠⚠⚠ FİYAT MANTIĞI UÇTAN UCA ŞİFRELİ ────────────────────────────────── */
SELECT s.name+'.'+o.name AS obje, o.type_desc AS tip,
       OBJECTPROPERTY(o.object_id,'IsEncrypted') AS sifreli
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
WHERE  o.type IN ('V','FN','IF','TF','P')
  AND (o.name LIKE '%fyt%' OR o.name LIKE '%fiyat%')
ORDER BY sifreli DESC, obje;
/* 60+ nesne, İSTİSNASIZ hepsi IsEncrypted = 1:
     fiyat_oku · fiyat_yaz · fn_fiyat · fn_fiyatOzl · fn_fiyatMkn · fn_fiyatNrm ·
     fiyatSatis_vw · fiyatAlis_vw · fiyatOzelSatis_vw · fn_fytListe ·
     14 ayrı fn_fytOzlListe* varyantı (Mekansal · FirmaMekansal · GeriDonus ·
     TumFirmalar · EkKartFiyat · TumFrmListe …)
   ⇒ Tek bir okunamayan fonksiyon DEĞİL — fiyatın nasıl belirlendiği KARA KUTU,
     ve marj / kampanya / satınalma işinin tam ortasında duruyor. */

/* ── 2) ⭐ SÖZLÜK AÇIK — fiyat sisteminin kod kümeleri okunabilir tablolarda ── */
SELECT * FROM DerinSISBkm.dbo.fytTur WITH(NOLOCK);
SELECT * FROM DerinSISBkm.dbo.fytTip WITH(NOLOCK);
SELECT * FROM DerinSISBkm.dbo.fytNdn WITH(NOLOCK);
/* fytTur (9) : 0 Satış Fiyatı · 1 Son Alış Fiyatı · 2 Döviz · 3 Alış Fiyatı 2 ·
                4 Web · 5 Alış Fiyatı 3 · 6 Liste Web · 7 Alış Fiyatı 4 · 8 Ozl Web
     ⇒ 4 / 6 / 8 → E-TİCARET FİYATI AYRI TUTULUYOR; mağaza fiyatıyla karıştırılmaz.
   fytTip (5) : 0 Kart Fiyatı · 1 Tarihsel Fiyat · 2 Mekansal Fiyat · 3 Özel Fiyat ·
                4 Ek İndirim
   fytNdn (7) : FİYAT DEĞİŞİM NEDENİ —
                0 Normal fiyat geçiş · 1 Düzeltme · 2 Firma düzeltmesi ·
                3 REKABET · 4 Emek Entegrasyon ·
                5 Firma Marka Otomatik (fnOto = 1) · 6 Grup Fiyat Değiştir
     ⇒ "Rekabet" bir NEDEN KODU olarak KAYITLI. Fiyat kararının gerekçesi veride
       duruyor ve sema'da YOKTU — fiyat analizinde doğrudan kullanılabilir. */

/* ── 3) ŞİFRELİ FONKSİYONUN DAVRANIŞI (imza şifreli nesnede de okunur) ──────── */
SELECT p.parameter_id, p.name AS parametre, ty.name AS tip
FROM   DerinSISBkm.sys.parameters p
JOIN   DerinSISBkm.sys.objects o ON o.object_id = p.object_id
JOIN   DerinSISBkm.sys.types ty ON ty.user_type_id = p.user_type_id
WHERE  o.name = 'fn_fytOzlListe' ORDER BY p.parameter_id;
/* @tarih smalldatetime · @tur int · @tip int
   Dönüş 13 kolon: fhID · fStkID · fTarih · fTur · sonrakiFiyat · fTarihSon · fTip ·
                   fInd1..fInd5 · sonrakiNet
   (Yalnız GÖVDE gizli; imza ve dönüş şeması okunuyor.) */

SELECT 0 AS tur, 0 AS tip, COUNT_BIG(*) AS satir FROM DerinSISBkm.dbo.fn_fytOzlListe(GETDATE(),0,0)
UNION ALL SELECT 1,0, COUNT_BIG(*) FROM DerinSISBkm.dbo.fn_fytOzlListe(GETDATE(),1,0)
UNION ALL SELECT 2,0, COUNT_BIG(*) FROM DerinSISBkm.dbo.fn_fytOzlListe(GETDATE(),2,0)
UNION ALL SELECT 0,1, COUNT_BIG(*) FROM DerinSISBkm.dbo.fn_fytOzlListe(GETDATE(),0,1)
UNION ALL SELECT 0,2, COUNT_BIG(*) FROM DerinSISBkm.dbo.fn_fytOzlListe(GETDATE(),0,2)
UNION ALL SELECT 1,1, COUNT_BIG(*) FROM DerinSISBkm.dbo.fn_fytOzlListe(GETDATE(),1,1);
/* @tur=0 (Satış)   → 776.458      @tur=1 (Son Alış) → 792.670     @tur=2 (Döviz) → 0
   @tip 0 / 1 / 2   → hepsi 776.458  (AYRIM ÜRETMİYOR)
   ⇒ Sürücü parametre @tur. @tip'in bu çağrı biçiminde neden etkisiz olduğu
     ÖLÇÜLMEDİ — açık soru.
   ⚠ Ham tablolar: fytOzl 155.754.960 satır · fyt 15.738.133 · fytB 516.632.
     Fiyat tarihçesi devasa; şifreli fonksiyonlar bunun üstünde çalışıyor. */

/* ============================================================================
   4) ZİRVE VIEW TANIMLARI AÇILDI — kullanıcı GRANT VIEW DEFINITION verdi
   ============================================================================ */
/* profil: zirve */
SELECT o.name AS view_adi, LEN(m.definition) AS uzunluk
FROM   sys.objects o LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
WHERE  o.type = 'V' ORDER BY o.name;
/* 11/11 OKUNUYOR: vw_PerKBil 3.138 · vw_PersonelDepartmanEski 2.498 ·
   vw_PerOBil 2.375 · vw_PersonelDepartman 2.273 · vw_PuanBil 2.159 ·
   mevcut_personeller 1.524 · wPerkbil 929 · MagazaPersoneller 475 ·
   personeler 455 · personelIstenAyrilanlar 282 · v_GetDate 62
   ⇒ Önceki ölçüm doğruydu: ŞİFRELİ DEĞİLDİ, İZİN YOKTU. İzin gelince hepsi açıldı.
     Kayıt `zirve_view_tanimlari_okunamiyor` ARTIK GEÇERSİZ. */

/* (1) vw_PuanBil SÜZGEÇSİZ — üç firmanın puanbil'inin saf UNION ALL'ı, WHERE YOK.
       Kolonlar birebir; yalnız Personelno'ya firma eki ekleniyor ve Firma sabit
       metin yazılıyor.
   ⇒ Üstünde koşan 6 bordro değişmezinin NÜFUSU ÜÇ FİRMANIN TÜM TARİHİ.
     "BKM bordrosu" sanmak KAPSAM HATASIDIR. */

/* (2) vw_PersonelDepartman ↔ ...Eski FARKI = KOLON ADLANDIRMASI */
SELECT c.column_id, c.name AS kolon FROM sys.columns c
JOIN   sys.objects o ON o.object_id = c.object_id
WHERE  o.name = 'vw_PersonelDepartmanEski' ORDER BY c.column_id;
/* Eski (boşluklu takma ad): [Personel No] · [Ad Soyad] · [Tc Kimlik No] ·
     [Doğum Tarihi] · [İşe Giriş Tarihi] · [İşten Çıkış Tarihi] · [Alt Lokasyon] ·
     [Alt Alt Lokasyon] · Ünvan · [İşten Çıkış Kodu] · [Prim Tutarı] · Ücret …
   Yeni (bitişik): Personelno · AdSoyad · Vatno · Dt · Igt · Ict · AltLokasyon ·
     AltAltLokasyon · Unvan · IstenCikisKodu · PrimTutari · Ucret …
   İkisi de AYNI üç DB, AYNI `Ict > '2023-12-31'` süzgeci, AYNI ham kolonlar.
   ⇒ İkisinin de 1.296 satır olmasının sebebi bu: AYNI VERİ, farklı başlık.

   ⚠⚠ DÜZELTME (commit dbee641'de EKSİK yazmıştım): `PERSONEL AYLIK ORTALAMA.sql`
     "kırık" DEĞİL — `...Eski`nin adlandırmasına yazılmış, yani ESKİ VIEW'A yazılı.
     View adı değiştirilip eskisi `Eski` olarak saklanmış.
     Ama tam da çalışmıyor: kullandığı `p.Grup` İKİ VIEW'DE DE YOK
     ⇒ bu görünümün EN AZ ÜÇ KUŞAĞI olmuş ve `Grup` en eskisinde kalmış.
   ⇒ DERS GÜNCELLENDİ: arşiv sorgusu "kırık" diye ATILMAZ — hangi KUŞAĞA yazıldığı
     sorulur. KOLON ADLARI BİR SÜRÜM PARMAK İZİDİR. */

/* (3) YENİ KOLON: perbilgi.kidbastar (kıdem başlangıç tarihi)
       `mevcut_personeller` view'inde görüldü; `vw_PersonelDepartman`da YOK. */
SELECT COUNT(*) AS satir,
       SUM(CASE WHEN kidbastar IS NULL THEN 1 ELSE 0 END) AS kidbastar_null,
       SUM(CASE WHEN kidbastar IS NOT NULL AND Igt IS NOT NULL
                 AND CONVERT(date,kidbastar) <> CONVERT(date,Igt) THEN 1 ELSE 0 END) AS FARKLI
FROM   dbo.perbilgi;
/* 3.578 satır · 3.513 NULL · dolu olan 65'in 64'ünde Igt'den FARKLI
   ⇒ Kıdem başlangıcı işe giriş tarihiyle AYNI DEĞİL (devir · yeniden giriş ·
     devralınan personel). Kıdem/tazminat `Igt` ile hesaplanırsa o 64 kişide YANLIŞ.
   ⇒ Arşivdeki `PERSONEL KIDEM LİSTESİ.sql` `Igt` kullanıyor — kapsamı BEYAN EDİLMELİ.
   ⇒ Hangi tarihin doğru olduğu BİR İŞ KARARIDIR, ölçümle belirlenemez; İK'ya sorulur. */
