/* ============================================================================
   ODAK ÜRÜN HATTI — DÜZELTME ÖNERİLERİ (2026-10-03)
   Sorun listesi: docs/13-odak-entegrasyon-brief.docx §7 · docs/13-odak-urun-hatti.md §4

   ⚠ BU DOSYA ÇALIŞTIRILMAK İÇİN DEĞİL. ERP SP'leri bu depodan değiştirilmez
     (erp-write-policy). Her blok, ilgili SP'deki satırların YERİNE konacak
     önerilen koddur; uygulama SP sahibinin (DerinSIS/BKMDATA) onayıyla yapılır.

   TEST YÖNTEMİ (yazmadan):
     1) Derleme: her ">>> ... <<<" bloğu sys.dm_exec_describe_first_result_set
        ile derlendi (geçersiz kolon/tablo varsa hata 207/208 döner; boş = geçti).
        Yöntemin kırılabilirliği sınandı: bozuk kolon adı → 207.
     2) Etki: her düzeltmenin SELECT karşılığıyla kaç satırı değiştireceği ölçüldü
        (sonuçlar blok başında "ETKİ" satırında).
   ============================================================================ */


/* ── S-1 + S-2 · ent.odakFiyatAktarim satır 63–84 (ikinci blok) ───────────────
   SORUN: 228'li üründe alış satırı yazılmadığı için iskonto farkı hiç kapanmıyor →
          her saat aynı 10.108 ürüne belge (S-1). 220 süzgeci bu blokta yok (S-2).
          Satır 73 "önceki fiyat"ı etiket − 0,01 yazıyor (sahte).
   DÜZELTME: 220 ve 228 süzgeci + birinci bloktaki koruma süzgeçleri + gerçek önceki fiyat.
   */
/* ETKİ (ölçüldü): ikinci blok adayı 13.671 ürün → 553 ürün. 228'li 10.108 ürünlük saatlik döngü ve 220'li 15 ürün düşer. */
-- >>> S-1 db=DerinSISBkm
CREATE TABLE #odakFiyatTemp([stkID] int NOT NULL,[firmaID] int NOT NULL,[urnMrkID] smallint NOT NULL,
  [fiyatS] decimal(15,4) NOT NULL,[etiket_fiyat] decimal(15,4) NOT NULL,[alis_iskonto] decimal(15,4) NOT NULL,
  Fiyat decimal(15,4) NULL, barkod varchar(50) NULL);
;WITH aaa AS (
    SELECT u.stkID fStkID,
           CASE WHEN sonrakiFiyat IS NULL THEN u.fiyatS ELSE sonrakiFiyat END sonrakiFiyat,
           ISNULL(fInd1,0) fInd1, u.fiyatS, u.urnMrkID,
           ROW_NUMBER() OVER (PARTITION BY u.stkID ORDER BY fTarihSon DESC) sno
    FROM urn u WITH (NOLOCK)
    LEFT JOIN fytOzl a WITH (NOLOCK) ON a.fStkID = u.stkID AND a.fFrmID IN (9525) AND fTur = 1 AND fTip = 1
)
INSERT INTO #odakFiyatTemp
SELECT a.fStkID, 9525, a.urnMrkID,
       u.fiyatS,                                                    -- DÜZELTME: gerçek önceki fiyat (eski: etiket − 0,01)
       CASE WHEN ISNULL(cift.Fiyat,-1) < odak.etiket_fiyat THEN odak.etiket_fiyat ELSE ISNULL(cift.Fiyat,-1) END,
       mar.discount, cift.Fiyat, ub.urnBarkod
FROM aaa a
JOIN urn u                                  WITH (NOLOCK) ON u.stkID = a.fStkID
JOIN urnBrkd AS ub                          WITH (NOLOCK) ON ub.urnBrkdStkID = u.stkID
JOIN BKMDATA.ent.odak_urun_tam AS odak      WITH (NOLOCK) ON odak.barkod = ub.urnBarkod
JOIN BKMDATA.ent.odak_marka AS mar          WITH (NOLOCK) ON mar.group_id = odak.group_id AND mar.parent_id = odak.marka_id
LEFT JOIN bkm.CiftUrunlerMaxFyat cift       WITH (NOLOCK) ON cift.urnBrkdStkID = ub.urnBrkdStkID
LEFT JOIN #odakFiyatTemp temp                              ON temp.stkID = a.fStkID
LEFT JOIN urnBilgi ub220                    WITH (NOLOCK) ON ub220.bVeriID = u.stkID AND ub220.bBilgiID = 220 AND ub220.bDeger = 'True'   -- DÜZELTME S-2
LEFT JOIN urnBilgi ub228                    WITH (NOLOCK) ON ub228.bVeriID = u.stkID AND ub228.bBilgiID = 228 AND ub228.bDeger = 'True'   -- DÜZELTME S-1
WHERE sno = 1
  AND fInd1 <> ISNULL(mar.discount,0)
  AND temp.stkID IS NULL
  AND ub220.bVeriID IS NULL          -- DÜZELTME S-2: "Odak Fiyat Güncellenmesin" bu blokta da geçerli
  AND ub228.bVeriID IS NULL          -- DÜZELTME S-1: alış satırı yazılmayan üründe iskonto kıyası hiç kapanmaz
  AND odak.SilinecekUrun = 0         -- birinci bloktaki (satır 56–57) korumalar
  AND odak.etiket_fiyat < 999999;
-- <<<


/* ── S-1 (ek) + S-3 · ent.odakFiyatAktarim satır 132–140 (satış satırı) ────────
   SORUN: satış satırı (fTur = 0) fiyat değişmese de ve ürünün HER tedarikçisi için yazılıyor
          (satır 49 urnFrm Etkin=1 çoğaltması) → aynı ürün-gün 323.590 tekrar.
   DÜZELTME: satış satırı ürün başına bir kez (9525 tercihli) ve yalnız fiyat değişince. */
/* ETKİ: temp tabloya bağlı, SELECT karşılığı kurulamadı. Hedef: aynı ürün-gün 323.590 tekrar satış satırı → 0; değişmeyen fiyat için satış satırı yazılmaz. */
-- >>> S-3 db=DerinSISBkm
CREATE TABLE #odakFiyatTemp([stkID] int NOT NULL,[firmaID] int NOT NULL,[urnMrkID] smallint NOT NULL,
  [fiyatS] decimal(15,4) NOT NULL,[etiket_fiyat] decimal(15,4) NOT NULL,[alis_iskonto] decimal(15,4) NOT NULL,
  Fiyat decimal(15,4) NULL, barkod varchar(50) NULL);
CREATE TABLE #inserted (FeID int, feNot varchar(50), feFrmID int);
DECLARE @kisi int = 137;
SELECT i.feID, t.stkID, dbo.fn_tarih(null), 0, t.fiyatS, t.etiket_fiyat, 0, 0, 0, t.etiket_fiyat,
       @kisi, ROW_NUMBER() OVER (PARTITION BY i.feID ORDER BY t.stkID), dbo.fn_tarih(null), t.firmaID, 1
FROM (SELECT x.*, ROW_NUMBER() OVER (PARTITION BY x.stkID
                                     ORDER BY CASE WHEN x.firmaID = 9525 THEN 0 ELSE 1 END, x.firmaID) rn
      FROM #odakFiyatTemp x) t                                       -- DÜZELTME S-3: ürün başına tek satış satırı
INNER JOIN frm    WITH (NOLOCK) ON frmID = t.firmaID
INNER JOIN urnFrm WITH (NOLOCK) ON urnFrmStkID = t.stkID AND urnFrmFirmaID = t.firmaID
INNER JOIN fytB   WITH (NOLOCK) ON SUBSTRING(frmAd,1,10)+' Odak2 Ent' = feNot AND t.firmaID = feFrmID AND feOnay = 1
        AND feTarihA = dbo.fn_tarih(null) AND feTarihAson = feTarihA AND feTarihS = feTarihA AND feTarihSson = feTarihA
JOIN #inserted AS i ON i.feID = fytB.feID AND i.feNot = fytB.feNot AND i.feFrmID = fytB.feFrmID
WHERE t.rn = 1
  AND t.fiyatS <> t.etiket_fiyat;                                   -- DÜZELTME S-1: fiyat değişmiyorsa satış satırı yok
-- <<<


/* ── S-4 · ent.odakUrunAktar satır 212–219 (Ürün Web Adı ekleme) ──────────────
   SORUN: satır 219 olmayan satırın bDeger'ini (NULL) karşılaştırıyor → blok hiç satır üretmez.
   DÜZELTME: satır 219 silinir.
   ETKİ: ilk koşumda 599.370 web adı satırı eklenir (çift ürünler hariç tutulmadığı için
         aynı stkID'ye birden çok satır gelebilir → çift süzgeci eklendi). */
/* ETKİ (ölçüldü): ilk koşumda 599.096 web adı satırı eklenir; aynı stkID'ye birden çok satır riski 0. */
-- >>> S-4 db=DerinSISBkm
INSERT INTO urnBilgi (bBilgiID, bVeriID, bDeger)
SELECT 10, urn.stkID, IIF(odak.kategori_id_2 = '001007002', odak.marka_ad + ' ' + odak.urun_ad, odak.urun_ad)
FROM urn WITH (NOLOCK)
JOIN urnBrkd AS bar                    WITH (NOLOCK) ON bar.urnBrkdStkID = urn.stkID
INNER JOIN BKMDATA.ent.odak_urun_tam odak WITH (NOLOCK) ON odak.barkod = bar.urnBarkod
LEFT JOIN urnBilgi ubilgi              WITH (NOLOCK) ON ubilgi.bVeriID = urn.stkID AND ubilgi.bBilgiID = 10
WHERE ubilgi.bBilgiID IS NULL
  AND odak.SilinecekUrun = 0
  AND urn.stkID NOT IN (SELECT urnBrkdStkID FROM bkm.CiftUrunlerMaxFyat);   -- DÜZELTME: satır 219 yerine çift ürün süzgeci
-- <<<


/* ── S-5 · ent.odakUrunAktar satır 389–391 (193), 424–426 (192), 449–451 (191) ──
   SORUN: "on barkod=stkKod" → ürün kodu barkoddan farklı 23.230 üründe güncelleme çalışmıyor.
   DÜZELTME: diğer bloklar gibi urnBrkd üzerinden bağlan. Üç blokta aynı değişiklik. */
/* ETKİ (ölçüldü): 193 → 2.360 · 192 → 115 · 191 → 62 satır güncellenir (bulgudaki sapmayla birebir). */
-- >>> S-5a db=DerinSISBkm
UPDATE bilgialtbaslik SET bilgialtbaslik.bDeger = CONVERT(varchar(10), odak.basim_tarihi_yil)
FROM urn WITH (NOLOCK)
JOIN urnBrkd AS bar                       WITH (NOLOCK) ON bar.urnBrkdStkID = urn.stkID        -- DÜZELTME
INNER JOIN BKMDATA.ent.odak_urun_tam odak WITH (NOLOCK) ON odak.barkod = bar.urnBarkod         -- DÜZELTME (eski: barkod=stkKod)
INNER JOIN urnBilgi AS bilgialtbaslik     WITH (ROWLOCK) ON bilgialtbaslik.bVeriID = urn.stkID AND bilgialtbaslik.bBilgiID = 193
WHERE odak.basim_tarihi_yil <> 0
  AND odak.SilinecekUrun = 0
  AND ISNULL(TRY_CONVERT(int, bilgialtbaslik.bDeger), -1) <> odak.basim_tarihi_yil
  AND urn.stkID NOT IN (SELECT urnBrkdStkID FROM bkm.CiftUrunlerMaxFyat);
-- <<<
-- >>> S-5b db=DerinSISBkm
UPDATE bilgialtbaslik SET bilgialtbaslik.bDeger = CONVERT(varchar(10), odak.basim_sayisi)
FROM urn WITH (NOLOCK)
JOIN urnBrkd AS bar                       WITH (NOLOCK) ON bar.urnBrkdStkID = urn.stkID
INNER JOIN BKMDATA.ent.odak_urun_tam odak WITH (NOLOCK) ON odak.barkod = bar.urnBarkod
INNER JOIN urnBilgi AS bilgialtbaslik     WITH (ROWLOCK) ON bilgialtbaslik.bVeriID = urn.stkID AND bilgialtbaslik.bBilgiID = 192
WHERE ISNULL(odak.basim_sayisi,0) <> 0
  AND odak.SilinecekUrun = 0
  AND ISNULL(TRY_CONVERT(int, bilgialtbaslik.bDeger), -1) <> odak.basim_sayisi
  AND urn.stkID NOT IN (SELECT urnBrkdStkID FROM bkm.CiftUrunlerMaxFyat);
-- <<<
-- >>> S-5c db=DerinSISBkm
UPDATE bilgialtbaslik SET bilgialtbaslik.bDeger = IIF(ISNULL(odak.sayfa_sayisi,0) > 1, CONVERT(varchar(10), odak.sayfa_sayisi), '')
FROM urn WITH (NOLOCK)
JOIN urnBrkd AS bar                       WITH (NOLOCK) ON bar.urnBrkdStkID = urn.stkID
INNER JOIN BKMDATA.ent.odak_urun_tam odak WITH (NOLOCK) ON odak.barkod = bar.urnBarkod
INNER JOIN urnBilgi AS bilgialtbaslik     WITH (ROWLOCK) ON bilgialtbaslik.bVeriID = urn.stkID AND bilgialtbaslik.bBilgiID = 191
WHERE odak.SilinecekUrun = 0
  AND bilgialtbaslik.bDeger <> IIF(ISNULL(odak.sayfa_sayisi,0) > 1, CONVERT(varchar(10), odak.sayfa_sayisi), '')
  AND urn.stkID NOT IN (SELECT urnBrkdStkID FROM bkm.CiftUrunlerMaxFyat);
-- <<<


/* ── S-6 · ent.odakUrunAktar — 102 Boy (satır 538), 177 Alt başlık (satır 195) için eksik UPDATE ──
   DÜZELTME: her eklemenin arkasına, diğer alanlardaki gibi "farklıysa güncelle" bloğu.
   175 Açıklama: ODAK HTML entity taşıyor, ERP'de çözülmüş metin var; önce tek biçime
   karar verilmeli — kör güncelleme 292.562 satırı yeniden yazar. Bu yüzden önerilmedi. */
/* ETKİ (ölçüldü): 102 Boy → 5.392 · 177 Alt başlık → 1.297 satır. (Bulgudaki 4.578'in kalanı ODAK'ta 'None' yazan boş alt başlık; onlar bilerek dışarıda.) */
-- >>> S-6a db=DerinSISBkm
UPDATE ub SET ub.bDeger = CONVERT(varchar(20), odak.boy)
FROM urn WITH (NOLOCK)
JOIN urnBrkd AS bar                       WITH (NOLOCK) ON bar.urnBrkdStkID = urn.stkID
INNER JOIN BKMDATA.ent.odak_urun_tam odak WITH (NOLOCK) ON odak.barkod = bar.urnBarkod
INNER JOIN urnBilgi AS ub                 WITH (ROWLOCK) ON ub.bVeriID = urn.stkID AND ub.bBilgiID = 102
WHERE odak.SilinecekUrun = 0
  AND ISNULL(TRY_CONVERT(decimal(9,2), ub.bDeger), -1) <> odak.boy        -- sayısal kıyas: '13.0' = '13.00'
  AND urn.stkID NOT IN (SELECT urnBrkdStkID FROM bkm.CiftUrunlerMaxFyat);
-- <<<
-- >>> S-6b db=DerinSISBkm
UPDATE ub SET ub.bDeger = ISNULL(odak.urun_alt_baslik,'')
FROM urn WITH (NOLOCK)
JOIN urnBrkd AS bar                       WITH (NOLOCK) ON bar.urnBrkdStkID = urn.stkID
INNER JOIN BKMDATA.ent.odak_urun_tam odak WITH (NOLOCK) ON odak.barkod = bar.urnBarkod
INNER JOIN urnBilgi AS ub                 WITH (ROWLOCK) ON ub.bVeriID = urn.stkID AND ub.bBilgiID = 177
WHERE odak.SilinecekUrun = 0
  AND ISNULL(odak.urun_alt_baslik,'') <> 'None'
  AND ub.bDeger <> ISNULL(odak.urun_alt_baslik,'')
  AND urn.stkID NOT IN (SELECT urnBrkdStkID FROM bkm.CiftUrunlerMaxFyat);
-- <<<


/* ── S-7 · ent.tsofturunaktarim satır 15–21 ──────────────────────────────────
   SORUN: satır 11 ERP'de kapalı (urnDurum=0) ürünü pasif yapıyor, satır 15 geri aktif yapıyor.
   DÜZELTME: aktif yapmadan önce ERP'de açık olduğuna bak. */
/* ETKİ (ölçüldü): şu an kapalı ama aktif 130 ürün. Düzeltme sonrası satır 11 bunları pasif yapar ve bir daha aktiflenmez. */
-- >>> S-7 db=DerinSISBkm
UPDATE u SET u.kod1ID = 1
FROM BKMDATA.ent.odak_urun_tam o WITH (NOLOCK)
JOIN dbo.urnBrkd AS bar WITH (NOLOCK) ON bar.urnBarkod = o.barkod
JOIN dbo.urn u                        ON u.stkID = bar.urnBrkdStkID
WHERE u.kod1ID IN (0,2)
  AND o.satis_durum = 1
  AND u.urnDurum = 1;                                                   -- DÜZELTME
-- (eski LEFT JOIN + "bar.urnBrkdStkID IS NULL OR" dalı ERP'de olmayan ürün için hiçbir satırı
--  güncelleyemezdi; INNER JOIN aynı sonucu verir.)
-- <<<


/* ── S-8 · ent.odakUrunAktar satır 882–887 ───────────────────────────────────
   SORUN: aynı ERP ürününe bağlı ODAK kayıtlarından biri silinmiş, biri satışta → adım 1 pasif,
          adım 2 (tsofturunaktarim satır 15) aktif yapıyor.
   DÜZELTME: satışta bir kaydı varsa pasife ÇEKME (adım 2 ile aynı kural).
   ⚠ İŞ KARARI: 140 üründe silinen kayıt "Yasaklı". Yasaklıyı her durumda pasif tutmak
     isteniyorsa kural tersine yazılmalı ve tsofturunaktarim satır 15'e de eklenmeli. */
/* ETKİ (ölçüldü, anlık): eski kural 354 ürünü pasife çekiyor; yeni kural 213. Aradaki 141 ürün satışta ikinci kaydı olduğu için aktif kalır (adım 2 ile çakışma biter). */
-- >>> S-8 db=DerinSISBkm
UPDATE u SET u.kod1ID = 0
FROM BKMDATA.ent.odak_urun_tam d
JOIN urnBrkd AS bar ON bar.urnBarkod = d.barkod
JOIN urn AS u       ON u.stkID = bar.urnBrkdStkID
WHERE u.kod1ID <> 0
  AND (d.SilinecekUrun = 1 OR d.SadeceMagaza = 1)
  AND NOT EXISTS (SELECT 1                                              -- DÜZELTME
                  FROM BKMDATA.ent.odak_urun_tam d2
                  JOIN urnBrkd b2 ON b2.urnBarkod = d2.barkod
                  WHERE b2.urnBrkdStkID = u.stkID
                    AND d2.satis_durum = 1 AND d2.SilinecekUrun = 0 AND d2.SadeceMagaza = 0);
-- <<<


/* ── S-9 · BKMDATA.ent.OdakUrunGuncellemeEslestir satır 30–37 ────────────────
   SORUN: görsel değişince eski görseli bulan birleşim "u.stkKod = odak.barkod".
   DÜZELTME: barkod tablosu üzerinden. (SP BKMDATA'da; test için tam adla yazıldı.) */
/* ETKİ: girdisi saatlik odak_urun_temp olduğu için önceden sayılamaz. Hedef: ürün kodu barkoddan farklı grupta bayat görsel 1.761 (eşit grupta 183). */
-- >>> S-9 db=DerinSISBkm
DELETE res
FROM BKMDATA.ent.odak_urun_temp tmp
JOIN BKMDATA.ent.odak_urun_tam AS odak         ON odak.urun_id = tmp.urun_id
JOIN DerinSISBkm.dbo.urnBrkd bar WITH (NOLOCK)  ON bar.urnBarkod = odak.barkod          -- DÜZELTME
JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK)        ON u.stkID = bar.urnBrkdStkID            -- DÜZELTME (eski: u.stkKod = odak.barkod)
JOIN DerinSISBkm.ent.tsoft_urun AS tsoft        ON tsoft.stkid = u.stkID
JOIN DerinSISBkmWeb.web.urnWeb AS res           ON res.urnWebBilgiID = u.stkID
WHERE odak.gorsel_guncelleme_tarih <> tmp.gorsel_guncelleme_tarih
   OR odak.urun_gorsel_url <> tmp.urun_gorsel_url;
-- <<<


/* ── S-10 · ent.odakUrunAktar satır 879 ──────────────────────────────────────
   SORUN: tüm ürün tablosunda kısa adı her saat yeniden yazıyor; SUBSTRING(x,0,30) 29 karakter.
   DÜZELTME: yalnız ODAK'ın açtığı ürün (ugKisi=137) ve doğru başlangıç (1).
   ⚠ "1" ile ilk koşumda ODAK ürünlerinde kısa ad 29→30 karakter olur (tek seferlik toplu güncelleme). */
/* ETKİ (ölçüldü): kapsam 842.648 → 288.466 ürün (ugKisi=137). İlk koşumda 114.487 kısa ad 29→30 karaktere uzar; ODAK dışı 194.128 ürüne artık dokunulmaz. */
-- >>> S-10 db=DerinSISBkm
UPDATE u SET u.stkAdKisa = SUBSTRING(u.stkAd, 1, 30)
FROM dbo.urn AS u WITH (ROWLOCK)
WHERE u.ugKisi = 137                                                    -- DÜZELTME: yalnız otomatik açılan ürün
  AND u.stkAdKisa <> SUBSTRING(u.stkAd, 1, 30);                         -- DÜZELTME: 0 → 1
-- <<<


/* ── S-11 · ent.odakUrunAktar satır 145–151 ──────────────────────────────────
   SORUN: kategori 43/35 dışındaki HER ürüne 56 ve 9525 tedarikçi bağı.
   ÖNERİ (iş kararına bağlı): yalnız ODAK'ta karşılığı olan ürüne bağla. Var olan
   808 bin bağ bu değişiklikle silinmez; temizlik ayrıca karar ister. */
/* ETKİ (ölçüldü): bugün eklenecek yeni bağ 0 (hepsi zaten bağlı). Değişiklik yalnız İLERİYE dönük: ODAK dışı yeni ürüne bağ eklenmez. */
-- >>> S-11 db=DerinSISBkm
INSERT INTO urnFrm (urnFrmStkID, urnFrmFirmaID, urnFrmEsas, urnFrmEtkin)
SELECT u.stkID, frm.frmID, 1, 1
FROM urn u WITH (NOLOCK)
JOIN frm WITH (NOLOCK) ON frm.frmID IN (56, 9525)
LEFT JOIN urnFrm f WITH (NOLOCK) ON f.urnFrmStkID = u.stkID AND f.urnFrmFirmaID = frm.frmID
WHERE u.urnKtgrID NOT IN (43, 35)
  AND f.urnFrmStkID IS NULL
  AND EXISTS (SELECT 1 FROM urnBrkd b JOIN BKMDATA.ent.odak_urun_tam o ON o.barkod = b.urnBarkod
              WHERE b.urnBrkdStkID = u.stkID);                          -- DÜZELTME: yalnız ODAK ürünü
-- <<<


/* ── S-12 · ent.odakUrunAktar satır 178–181 ──────────────────────────────────
   SORUN: birden çok urnFrmEsas=0 kaydı olan 25.480 ürün her koşumda güncellemeye giriyor,
          hangi firmanın yazılacağı belirsiz.
   DÜZELTME: ürün başına belirli bir seçim (en küçük firma no). */
/* ETKİ (ölçüldü): ilk koşumda 12.778 ürünün ana tedarikçisi değişir; sonra 25.480 ürünlük saatlik yeniden yazma biter. */
-- >>> S-12 db=DerinSISBkm
UPDATE u SET u.stkFirma = f.firma
FROM urn u WITH (ROWLOCK)
JOIN (SELECT urnFrmStkID, MIN(urnFrmFirmaID) firma
      FROM urnFrm WITH (NOLOCK) WHERE urnFrmEsas = 0
      GROUP BY urnFrmStkID) f ON f.urnFrmStkID = u.stkID                -- DÜZELTME: tek, belirli seçim
WHERE f.firma <> u.stkFirma;
-- <<<


/* ── S-13 · BKMDATA.ent.OdakUrunGuncellemeMagazaEslestir satır 16 ────────────
   SORUN: değişen mağaza kaydının log'unda Tip yazılmıyor → DEFAULT 0 (web). */
/* ETKİ: girdisi saatlik magaza_temp; önceden sayılamaz. Bundan sonraki mağaza değişimleri Tip=1 ile ayrılır, geçmiş kayıtlar düzelmez. */
-- >>> S-13 db=DerinSISBkm
INSERT INTO BKMDATA.ent.odak_urun_log (urun_id, satis_durum, etiket_fiyat, LogTarih, Tip)   -- DÜZELTME: Tip
SELECT DISTINCT tmp.urun_id, tmp.satis_durum, tmp.etiket_fiyat, GETDATE(), 1                 -- DÜZELTME: 1 = mağaza
FROM BKMDATA.ent.odak_urun_magaza_temp tmp
JOIN BKMDATA.ent.odak_urun_magaza_tam AS tam ON tam.urun_id = tmp.urun_id
WHERE tam.etiket_fiyat <> tmp.etiket_fiyat
   OR tam.satis_durum  <> tmp.satis_durum;
-- <<<


/* ── S-14 · BKMDATA.dbo.OdakDegisenStokGuncelle — satır 63'ten sonra eklenecek ──
   SORUN: OdakStokDegisenStok_Log silinmiyor (94,7M satır, günde ~112 bin).
   ÖNERİ: 90 günden eski satırları parça parça sil (her 5 dk koşumda en çok 50 bin satır;
          kilitlenmeyi önlemek için TOP). Saklama süresi iş kararı. */
/* ETKİ (ölçüldü): 90 günden eski 86.018.556 satır. Koşum başı 50 bin ile ~1.720 koşum (5 dk'da bir ≈ 6 gün) sonra kararlı hâle gelir. */
-- >>> S-14 db=DerinSISBkm
DELETE TOP (50000) FROM BKMDATA.dbo.OdakStokDegisenStok_Log
WHERE LogDate < DATEADD(DAY, -90, GETDATE());
-- <<<


/* ── S-15 · BKMDATA.ent.OdakUrunMaliyet (görünüm) ────────────────────────────
   SORUN: barkod düzeyinde gruplandığı için 40 stkID çok satır; maliyet FLOAT.
   DÜZELTME: stkID başına tek satır (en yüksek etiket — fiyat motorunun çift ürün kuralıyla aynı),
             DECIMAL. Görünüm tanımı (CREATE OR ALTER VIEW gövdesi): */
/* ETKİ (ölçüldü): 647.529 → 647.486 satır; stkID başına çok satır 40 → 0. */
-- >>> S-15 db=DerinSISBkm
SELECT ub.urnBrkdStkID AS StkID,
       MAX(ou.barkod) AS barkod,
       MAX(om.discount) AS OdakIskonto,
       MAX(ou.etiket_fiyat) AS UstFiyat,
       CAST(MAX(ou.etiket_fiyat * (100 - ISNULL(om.discount,0)) / 100) AS decimal(18,4)) AS OdakMaliyet,   -- DÜZELTME: FLOAT → DECIMAL
       MAX(o.Durum) AS OdakDurum
FROM BKMDATA.ent.odak_urun_tam AS ou
JOIN BKMDATA.ent.odak_marka AS om ON om.group_id = ou.group_id AND om.parent_id = ou.marka_id
JOIN DerinSISBkm.dbo.urnBrkd AS ub ON ub.urnBarkod = ou.barkod
JOIN BKMDATA.ent.odak_urun AS o    ON o.urun_id = ou.urun_id
GROUP BY ub.urnBrkdStkID;                                               -- DÜZELTME: stkID başına tek satır
-- <<<


/* ============================================================================
   PERFORMANS ÖNERİLERİ (P-blokları) — ölçüm: salt-okuma zamanlama (pyodbc), oturuma
   özel #temp (ERP tablosuna yazma yok). Maliyet kaynağı: sys.dm_exec_query_stats.
   odakUrunAktar_job 03.10.2026: 15 koşum, ort. 217 sn, en uzun 295 sn (günde 54 dk).
   ============================================================================ */

/* ETKİ (ölçüldü): tek öznitelik bloğu bugünkü biçimde 6,47 sn; ortak eşleme bir kez 9,06 sn, sonra aynı blok 0,75 sn. odakUrunAktar'da bu biçimde ~25 blok var (plan önbelleğine göre ~115 sn/koşum); toplam ~115 → ~30 sn ÇIKARIM (blok başı ölçüldü, toplam hesaplandı). */
-- >>> P-1 db=DerinSISBkm
-- odakUrunAktar başında BİR KEZ: ODAK → ERP eşlemesi, çift ürünler dışarıda
IF OBJECT_ID('tempdb..#bagli') IS NOT NULL DROP TABLE #bagli;
SELECT bar.urnBrkdStkID stkID, odak.urun_id, odak.barkod, odak.SilinecekUrun, odak.cilt_tipi, odak.kagit_cinsi,
       odak.agirlik, odak.en, odak.boy, odak.sayfa_sayisi, odak.basim_sayisi, odak.basim_tarihi_yil,
       odak.cep_boy, odak.cevirmen, odak.editor, odak.urun_orijinal_baslik, odak.urun_alt_baslik,
       odak.on_siparis, odak.on_siparis_tarih
INTO #bagli
FROM urnBrkd bar
JOIN BKMDATA.ent.odak_urun_tam odak ON odak.barkod = bar.urnBarkod;
DELETE b FROM #bagli b WHERE b.stkID IN (SELECT stkID FROM #bagli GROUP BY stkID HAVING COUNT(*) > 1);  -- eski çift ürün alt sorgusu her blokta yeniden hesaplanıyordu
CREATE UNIQUE CLUSTERED INDEX ix_bagli ON #bagli (stkID);
-- Her öznitelik bloğu bundan sonra bu kalıpla (örnek: 190 Cilt tipi, satır 582):
UPDATE ub SET ub.bDeger = k.cilt_tipi
FROM #bagli k
JOIN urnBilgi ub WITH (ROWLOCK) ON ub.bVeriID = k.stkID AND ub.bBilgiID = 190
WHERE k.SilinecekUrun = 0 AND ub.bDeger <> k.cilt_tipi;
-- <<<

/* ETKİ (ölçüldü): ayrı tarama 4,94 sn ve bugün 0 satır buluyor; tırnak temizliği ad güncellemesine taşınınca bu tarama kalkar. Yan etki: her saat ~371 ürünün adı önce tırnaklı yazılıp sonra temizleniyordu, o da biter. */
-- >>> P-2 db=DerinSISBkm
-- odakUrunAktar satır 205-209 YERİNE (satır 902-905'teki iki tam-tablo REPLACE taraması silinir)
UPDATE urn SET urn.stkAd = REPLACE(REPLACE(LTRIM(RTRIM(SUBSTRING(CONVERT(varchar(100), odak.urun_ad), 1, 100))), NCHAR(8221), ' '), NCHAR(8220), ' ')
FROM urn WITH (ROWLOCK)
JOIN urnBrkd AS bar WITH (NOLOCK) ON bar.urnBrkdStkID = urn.stkID
INNER JOIN BKMDATA.ent.odak_urun_tam odak WITH (NOLOCK) ON odak.barkod = bar.urnBarkod
WHERE urn.stkAd <> REPLACE(REPLACE(LTRIM(RTRIM(SUBSTRING(CONVERT(varchar(100), odak.urun_ad), 1, 100))), NCHAR(8221), ' '), NCHAR(8220), ' ');
-- <<<

/* ETKİ (ölçüldü): son alış satırını bulan seçim bugün 19,3-20,3 sn; mevcut IDC_FYT_OZL_20221103 index'iyle 9,05 sn. ⚠ BİREBİR AYNI DEĞİL: sıralama fTarihSon yerine fTarih → 17 üründe farklı "son alış" satırı seçiliyor; fTip index'te olmadığı için süzgeç düşüyor (9525 alış satırlarında fTip<>1 olan 3 satır). İş kararı. Kabul edilmezse aynı sonuç için yeni index gerekir: (fFrmID, fTur, fTip, fStkID, fTarihSon) INCLUDE (fInd1) — fytOzl'de zaten 20 index var, etkisi ölçülemedi (DDL yasak). Ürün başına TOP 1 arayan "ilk akla gelen" biçim 1.210 sn sürdü — KULLANILMAMALI. */
-- >>> P-3 db=DerinSISBkm
WITH son AS (
    SELECT a.fStkID, a.fInd1, ROW_NUMBER() OVER (PARTITION BY a.fStkID ORDER BY a.fTarih DESC, a.fID DESC) sno
    FROM fytOzl a WITH (NOLOCK, INDEX(IDC_FYT_OZL_20221103))
    WHERE a.fFrmID = 9525 AND a.fTur = 1
)
SELECT ub.urnBrkdStkID, ISNULL(son.fInd1, 0) fInd1, mar.discount
FROM urnBrkd ub WITH (NOLOCK)
JOIN BKMDATA.ent.odak_urun_tam odak WITH (NOLOCK) ON odak.barkod = ub.urnBarkod AND odak.SilinecekUrun = 0 AND odak.etiket_fiyat < 999999
JOIN BKMDATA.ent.odak_marka mar WITH (NOLOCK) ON mar.group_id = odak.group_id AND mar.parent_id = odak.marka_id
LEFT JOIN son ON son.fStkID = ub.urnBrkdStkID AND son.sno = 1
WHERE ISNULL(son.fInd1, 0) <> ISNULL(mar.discount, 0)
  AND NOT EXISTS (SELECT 1 FROM urnBilgi x WITH (NOLOCK)
                  WHERE x.bVeriID = ub.urnBrkdStkID AND x.bBilgiID IN (220, 228) AND x.bDeger = 'True');
-- <<<

/* ETKİ (ölçüldü): yerel log'da son 24 saati bulmak 1,88 sn (Id dışında index yok, 94,7M satır); son Id ile sınırlamak 0,05 sn. Satır 11'deki ifade koşum başına ~7,6 sn (stok job'unun %80'i); uzak sunucu payı ayrıca ölçülemedi. */
-- >>> P-4 db=DerinSISBkm
-- BKMDATA.dbo.OdakDegisenStokGuncelle satır 11-20 YERİNE
DECLARE @sonId int = (SELECT MAX(Id) FROM BKMDATA.dbo.OdakStokDegisenStok_Log);
INSERT INTO BKMDATA.dbo.OdakStokDegisenStok
SELECT kitap.ProductCode, kitap.StokMiktar, kitap.InsertDate, odak.barkod
FROM KITAPSEPETI.KITAPSEPETI.dbo.OdakStokDegisenStok_Log kitap
JOIN BKMDATA.ent.odak_urun_tam AS odak ON odak.urun_id = kitap.ProductCode
LEFT JOIN (SELECT ProductCode, InsertDate FROM BKMDATA.dbo.OdakStokDegisenStok_Log
           WHERE Id > @sonId - 300000) ist                        -- yalnız son ~2,5 günlük yerel kayıt (Id aralığı, clustered seek)
       ON ist.ProductCode = kitap.ProductCode AND ist.InsertDate = kitap.InsertDate
WHERE kitap.InsertDate > GETDATE() - 1 AND ist.ProductCode IS NULL;
-- <<<

/* ETKİ (ölçüldü): açıklama karşılaştırması koşum başı 12,2-14,5 sn ve bugün 1-4 satır buluyor. Açıklamayı ODAK güncellemiyor (S-6); değişiklik yalnız yeni ürün ya da elle düzeltmeyle gelir → saatlik değil günlük yeter. Öneri: ent.tsofturunaktarim satır 177-182 bloğu, her gece 23:00'te koşan ent.tsofturunaktarim_gunluk'a (job DerinSis_Ozet adım 14) taşınır; kod aynen kalır. Günde ~15 × 13 sn ≈ 3 dk kazanç (hesap). */
-- >>> P-5 db=DerinSISBkm
UPDATE tu SET urun_aciklama = ISNULL(ub175.bDeger, ''), api_kayit_durum = 1, api_kayıt_tarih = GETDATE()
FROM ent.tsoft_urun tu WITH (ROWLOCK)
JOIN urnBilgi ub175 WITH (NOLOCK) ON ub175.bBilgiID = 175 AND ub175.bVeriID = tu.stkid
WHERE ISNULL(tu.urun_aciklama, '') <> ub175.bDeger;
-- <<<
