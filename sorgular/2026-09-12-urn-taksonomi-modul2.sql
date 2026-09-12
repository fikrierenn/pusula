/* ============================================================================
   MODÜL 2 — `dbo.urn` FK KOMŞULUĞU: ÜRÜN TAKSONOMİSİ        (2026-09-12)
   DB: DerinSISBkm (profil: erp)

   Hub #2 (`dbo.urn`, 22 tablo referans veriyor). Komşuluk 32 tekil tablo;
   13'ü sema'da vardı, 19'u burada ölçüldü.

   ⭐ BU MODÜLÜN İKİ BULGUSU DOĞRUDAN AÇIK İŞLERE DOKUNUYOR:
     (a) `urn.kod2ID` ÜRÜNÜN ALICISIDIR — ve lookup'ta AYNI KİŞİ İKİ KODDA;
         alıcı karnesi bugün o kişiyi ikiye bölüyor.
     (b) `urn.kod4ID` KAMPANYA ETİKETİDİR ve `bkm.urnkod4log` tam tarihçeyi tutuyor —
         "3AL2ÖDE gerçek kârlılık etkisi" (CLAUDE.md açık madde) ölçülebilir hale geldi.
   ============================================================================ */

/* 1) KOMŞULUĞUN TOPLU ÖLÇÜMÜ */
SELECT s.name+'.'+o.name AS tablo,
       MAX(CASE WHEN p.index_id IN (0,1) THEN p.rows END) AS satir,
       (SELECT COUNT(*) FROM DerinSISBkm.sys.columns c WHERE c.object_id=o.object_id) AS kolon
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id=o.schema_id
JOIN   DerinSISBkm.sys.partitions p ON p.object_id=o.object_id
WHERE  s.name+'.'+o.name IN ('b2b.sepetAyr','dbo.b2bSepetAyr','dbo.fatAyrIhr','dbo.irsTshAyr',
       'dbo.posOzetKsyrIptalDetay','dbo.satBldrmAyr','hal.Kunyeler','mhs.mhsEntUrn','dbo.urnBrm',
       'dbo.urnDonem','dbo.urnGrp','dbo.urnKod1','dbo.urnKtgr','dbo.urnMrk','dbo.urnkod2',
       'dbo.urnkod3','dbo.urnkod4','dbo.urnkod5','dbo.urnKDV')
GROUP BY s.name,o.name,o.object_id ORDER BY satir DESC;
/* urnkod5 173.629 · urnMrk 10.300 · mhsEntUrn 1.605 · urnKtgr 82 · urnkod4 46 ·
   urnKDV 11 · urnkod2 11 · urnGrp 5 · urnBrm 4 · urnKod1 3 · urnkod3 3 · urnDonem 1
   SIFIR SATIRLI 7: satBldrmAyr · irsTshAyr · b2bSepetAyr · b2b.sepetAyr ·
     hal.Kunyeler · posOzetKsyrIptalDetay · fatAyrIhr (İHRACAT fatura satırı)
   ⇒ `frm` komşuluğundaki desen tekrarladı: B2B SEPET ve İHRACAT kurulu ama BOŞ.
   ⚠ `posOzetKsyrIptalDetay` boş → POS kasiyer İPTAL detayı tutulmuyor; kasiyer bazlı
     iptal/iade denetimi bu tablodan YAPILAMAZ. */

/* 2) TAKSONOMİ LOOKUP'LARININ TAM DÖKÜMÜ (elle yazma — buradan oku) */
SELECT 'kod1' AS t, CONVERT(varchar(10),kod1ID) AS id, CONVERT(varchar(50),kod1Ad) AS ad FROM DerinSISBkm.dbo.urnKod1 WITH(NOLOCK)
UNION ALL SELECT 'kod2', CONVERT(varchar(10),kod2ID), CONVERT(varchar(50),kod2Ad) FROM DerinSISBkm.dbo.urnkod2 WITH(NOLOCK)
UNION ALL SELECT 'kod3', CONVERT(varchar(10),kod3ID), CONVERT(varchar(50),kod3Ad) FROM DerinSISBkm.dbo.urnkod3 WITH(NOLOCK)
UNION ALL SELECT 'Donem', CONVERT(varchar(10),donemID), CONVERT(varchar(50),donemAd) FROM DerinSISBkm.dbo.urnDonem WITH(NOLOCK)
UNION ALL SELECT 'Brm', CONVERT(varchar(10),brmKod), CONVERT(varchar(50),brmAd) FROM DerinSISBkm.dbo.urnBrm WITH(NOLOCK)
UNION ALL SELECT 'Grp', CONVERT(varchar(10),grpID), CONVERT(varchar(50),grpAd) FROM DerinSISBkm.dbo.urnGrp WITH(NOLOCK);
/* kod1 = ÜRÜN DURUMU     0 Pasif · 1 Aktif · 2 Tükendi
   kod2 = ALICI (satınalmacı) — 11 kayıt, adlar PERSONEL VERİSİ (sema'ya yazılmaz)
   kod3 = ÖNERİ DURUMU    0 Öneri Yok · 1 Öneri Var · 2 Ön Sipariş
   Donem = TEK SATIR "Dönemsel değil" → sezonluk-ürün mekanizması HİÇ KULLANILMAMIŞ
   Brm  = AD · DZN · KG · KL   (urn'de ÜÇ birim kolonu da buraya bakar)
   Grp  = 5 satır (GENEL + 4 kampanya) → ürün-grubu ŞABLONU kurulu ama kullanılmıyor */

/* 3) ★ CANLI DAĞILIM — kod1 / kod2 / kod3 */
SELECT u.kod1ID AS kod, k.kod1Ad AS ad, COUNT_BIG(*) AS urun
FROM   DerinSISBkm.dbo.urn u WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urnKod1 k WITH(NOLOCK) ON k.kod1ID=u.kod1ID
GROUP BY u.kod1ID,k.kod1Ad ORDER BY urun DESC;
/* Pasif 356.310 · Aktif 324.940 · Tükendi 157.046
   ⚠ Katalogun yalnız %38'i AKTİF. 838.292'lik ham ürün sayısı AKTİF KATALOG DEĞİLDİR. */

SELECT u.kod3ID AS kod, k.kod3Ad AS ad, COUNT_BIG(*) AS urun
FROM   DerinSISBkm.dbo.urn u WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urnkod3 k WITH(NOLOCK) ON k.kod3ID=u.kod3ID
GROUP BY u.kod3ID,k.kod3Ad ORDER BY urun DESC;
/* Öneri Yok 802.367 (%95,7) · Ön Sipariş 29.542 · Öneri Var 6.387
   ⚠ "Ön Sipariş" henüz çıkmamış ürün — talep vekili yapılamaz, ölü stok da değil.
     Bulunurluk/aşırı-stok kartlarının bu 29.542'yi nasıl ele aldığı ÖLÇÜLMEDİ. */

/* 4) ★★ kod2 = ALICI, VE AYNI KİŞİ İKİ KODDA */
SELECT u.kod2ID AS kod, k.kod2Ad AS ad, COUNT_BIG(*) AS urun
FROM   DerinSISBkm.dbo.urn u WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urnkod2 k WITH(NOLOCK) ON k.kod2ID=u.kod2ID
GROUP BY u.kod2ID,k.kod2Ad ORDER BY urun DESC;
/* En büyük alıcı 408.329 ürün (katalogun %48'i). `0 = Genel` 41.554 → ALICI ATANMAMIŞ;
   bu bir alıcıya yazılmaz, kırılımda ayrı gösterilir.
   ⚠⚠ kod2ID 1 ve 6 AYNI KİŞİ (yalnız nokta farkı). */

SELECT kod2ID AS kod, COUNT_BIG(*) AS urun,
       CONVERT(varchar(10),MIN(kTarih),120) AS ilk_urun,
       CONVERT(varchar(10),MAX(kTarih),120) AS son_urun,
       SUM(CASE WHEN kod1ID=1 THEN 1 ELSE 0 END) AS aktif_urun
FROM   DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE kod2ID IN (1,6) GROUP BY kod2ID;
/* kod 6 → 118.712 ürün · 2021-08-05 .. 2026-09-12 · 43.218 aktif
   kod 1 →  52.142 ürün · 2023-08-23 .. 2026-09-12 ·  9.356 aktif
   ⇒ İKİSİ DE CANLI (eski/yeni değil). `GROUP BY kod2ID` bu kişiyi İKİYE BÖLER:
     toplam 170.854 ürün / 52.574 aktif, iki satıra dağılmış görünür.
   ⇒ ALICI BAZLI GRUPLAMA NORMALİZE EDİLMİŞ ADLA YAPILIR. */

/* 4b) KAPI + KÖRLÜK KANITI (paylaşılan dosyaya dokunmadan koşuldu) */
SELECT 'normalize (dogru)' AS yontem, COUNT_BIG(*) AS cakisan_grup FROM (
    SELECT UPPER(REPLACE(REPLACE(LTRIM(RTRIM(kod2Ad)),'.',''),' ','')) AS norm
    FROM DerinSISBkm.dbo.urnkod2 WITH(NOLOCK)
    GROUP BY UPPER(REPLACE(REPLACE(LTRIM(RTRIM(kod2Ad)),'.',''),' ','')) HAVING COUNT(*) > 1) a
UNION ALL
SELECT 'ham ad (naif)', COUNT_BIG(*) FROM (
    SELECT kod2Ad FROM DerinSISBkm.dbo.urnkod2 WITH(NOLOCK)
    GROUP BY kod2Ad HAVING COUNT(*) > 1) b;
/*   normalize → 1  (grup: "ERENBORAN", kod2ID 1 ve 6)
     ham ad    → 0  ← NAİF KONTROL BU HATAYI GÖREMEZ
   Kapının değeri tam olarak normalize adımındadır.
   Değişmez: `alici-kodu-mukerrer-ad-artmiyor` (48., eq 1 = "daha kötüye gitmesin") */

/* 5) ★★ kod4 = KAMPANYA ETİKETİ + TAM TARİHÇE */
SELECT TOP 8 u.kod4ID AS kod, k.kod4Ad AS ad, COUNT_BIG(*) AS urun
FROM   DerinSISBkm.dbo.urn u WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urnkod4 k WITH(NOLOCK) ON k.kod4ID=u.kod4ID
GROUP BY u.kod4ID, k.kod4Ad ORDER BY urun DESC;
/* 3 AL 2 ÖDE 427.291 (katalogun ~yarısı) · Kampanya Dışı 286.096 · Tanımsız 81.918 ·
   %50 INDIRIM 16.687 · %30 6.873 · %25 4.598 · Sahaf A Kalite 4.174 · %20 3.181 */

SELECT TOP 10 l.kod4yeni AS yeni_kod, k.kod4Ad AS ad, COUNT_BIG(*) AS adet
FROM   DerinSISBkm.bkm.urnkod4log l WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urnkod4 k WITH(NOLOCK) ON k.kod4ID=l.kod4yeni
WHERE  l.tarih IN ('20260506','20260512')
GROUP BY l.kod4yeni, k.kod4Ad ORDER BY adet DESC;
/* İKİ GÜNDE TOPLU YENİDEN ETİKETLEME:
     %50 INDIRIM    611.150
     3 AL 2 ÖDE     412.689
     Kampanya Dışı  134.760
     Tanımsız        57.104
   ⇒ `bkm.urnkod4log`un 1,34M satırının sebebi bu (2026-04-18'den beri tutuluyor).
   ⚠ ETİKET BAZLI ZAMAN SERİSİ 2026-05-06 ve 05-12'de KIRILIR — öncesiyle sonrası
     karşılaştırılamaz.
   ⭐ FIRSAT: kampanya üyeliği ÜRÜN BAZINDA TARİHÇELİ. CLAUDE.md'nin açık maddesi
     "3AL2ÖDE gerçek kârlılık etkisi" artık `urn.kod4ID` (anlık) + `bkm.urnkod4log`
     (geçmiş) ile ölçülebilir. `urn`den geçmiş SORULMAZ — log'dan sorulur. */

/* 6) kod5 = YAZAR (boyut tablosu, lookup değil) */
SELECT TOP 8 kod5ID AS id, kod5Ad AS ad FROM DerinSISBkm.dbo.urnkod5 WITH(NOLOCK) ORDER BY kod5ID;
/* "Bahtiyar Akyılmaz, Murat Sezginer" · "Fuat Başkan" · "(E) Mirek-Zade Mehmed Nami" …
   ⚠ ÇOK YAZARLI tek metin → `kod5ID` bir KİŞİYİ değil YAZAR KÜMESİNİ adresler.
     Yazar bazlı analiz ayrıştırma ister. Mükerrer yazım ÖLÇÜLMEDİ (açık soru —
     alıcı kodundaki mükerrer-ad tuzağının 173.629 satırlık hâli olabilir). */

/* 7) urnKtgr — KATEGORİ SANMA */
SELECT ktgrID, ktgrAd FROM DerinSISBkm.dbo.urnKtgr WITH(NOLOCK) ORDER BY ktgrID;
/* 82 satır ama içerik e-ticaret VİTRİNİ: "Çok Satan Kitaplar" · "Ramazan Şenliği" ·
   "1 Milyon Kitap Kampanyası" · "[DELCACHEFONKS]" · "Kategorisiz Ürünler"…
   ⚠ Ürün taksonomisi sanıp analiz ekseni yapmak YANLIŞ — kanonik kategori
     `bkm.UrunBilgi.KatAna/Kategori3`. `urnKtgr2` AYRI bir tablodur, karıştırma. */

/* ============================================================================
   MODÜL 2 ÖZETİ — dört ders
   1. ÜRÜN KARTI SANDIĞIMIZDAN ÇOK DAHA FAZLASINI TAŞIYOR: durum (kod1), ALICI (kod2),
      öneri durumu (kod3), KAMPANYA (kod4), yazar (kod5). Beşi de tek tablo join'iyle
      geliyor ve beşi de bu depoda yazılı DEĞİLDİ.
   2. MÜKERRER LOOKUP KAYDI, ATIF ANALİZİNİ SESSİZCE BÖLER. Naif kontrol göremez;
      normalize etmeyen kapı kördür.
   3. KURULU AMA KULLANILMAYAN MEKANİZMA deseni burada da: urnDonem (tek satır),
      urnGrp (5 satır), 7 boş tablo. ERP'nin YETENEĞİ ile BKM'nin KULLANIMI ayrı şeyler.
   4. ANLIK DURUM ≠ GEÇMİŞ. `urn.kod4ID` bugünü söyler; geçmiş yalnız
      `bkm.urnkod4log`da. Anlık kolondan tarihsel soru sormak sessiz yanlış üretir.
   ============================================================================ */
