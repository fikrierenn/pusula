/* ============================================================================
   SEMA KOD KÜMELERİNE KANIT — CANLI GROUP BY KIYASI  (2026-09-12)
   DB: DerinSISBkm · EncoreMerkez (profil: erp)

   NEDEN: `codes` dosyasında 23 kayıtta `evidence` yoktu. Bir kod kümesinin doğal
   kanıtı CANLI GROUP BY'dır: beyan edilen değer kümesi gerçekten veride var mı,
   ve daha önemlisi — VERİDE OLUP SEMADA OLMAYAN kod var mı?

   ⚠ ASIL SINAMA TERS YÖNDE. "Sema'da var, canlıda yok" zararsızdır (kod kullanılmıyor,
   kayıt SİLİNMEZ — silmek öğrenilen gerçeği silmektir). "Canlıda var, sema'da YOK"
   ise sessiz yanlış rakam üretir: filtre o kodu dışarıda bırakır ve kimse görmez.

   SONUÇ: 7 kod kümesi ölçüldü, İKİSİNDE DRIFT çıktı (blok 3-4).
   codes'ta 23 kayıt kapandı (5'ine ölçülmüş kanıt · 2'si elle düzeltildi ·
   16'sına gerekçeli `evidence_status: pending`).
   `kanit_yok` 98 → 75 (kalan tamamı `metrics`).
   ============================================================================ */

/* 1) CANLI DAĞILIM — yedi kod kümesi tek sorguda */
SELECT 'irsHrk.ehTip' AS kod, CONVERT(varchar(20), ehTip) AS deger, COUNT_BIG(*) AS adet
FROM   DerinSISBkm.dbo.irsHrk WITH(NOLOCK) GROUP BY ehTip
UNION ALL SELECT 'fat.eTip', CONVERT(varchar(20), eTip), COUNT_BIG(*)
FROM   DerinSISBkm.dbo.fat WITH(NOLOCK) GROUP BY eTip
UNION ALL SELECT 'depo.emir.emTip', CONVERT(varchar(20), emTip), COUNT_BIG(*)
FROM   DerinSISBkm.depo.emir WITH(NOLOCK) GROUP BY emTip
UNION ALL SELECT 'depo.adres.adrsAlanTipID', CONVERT(varchar(20), adrsAlanTipID), COUNT_BIG(*)
FROM   DerinSISBkm.depo.adres WITH(NOLOCK) GROUP BY adrsAlanTipID
UNION ALL SELECT 'mhs.mhsFis.fisBA', CONVERT(varchar(20), fisBA), COUNT_BIG(*)
FROM   DerinSISBkm.mhs.mhsFis WITH(NOLOCK) GROUP BY fisBA
UNION ALL SELECT 'depo.paletIcHrkTip', CONVERT(varchar(20), pHrkTip), COUNT_BIG(*)
FROM   DerinSISBkm.depo.paletIcHrk WITH(NOLOCK) GROUP BY pHrkTip
UNION ALL SELECT 'encore.Sales.DocumentsTypeId', CONVERT(varchar(20), DocumentsTypeId), COUNT_BIG(*)
FROM   EncoreMerkez.dbo.Sales WITH(NOLOCK) GROUP BY DocumentsTypeId
ORDER BY kod, deger;

/* 2) KIYAS SONUCU (sema `values` ↔ canlı)
     irsHrk.ehTip                 sema 34 · canlı 26 · SEMADA YOK: -   (8 kod canlıda yok)
     fat.eTip                     sema 13 · canlı 11 · SEMADA YOK: -   (2 kod canlıda yok)
     encore.Sales.DocumentsTypeId sema  6 · canlı  6 · SEMADA YOK: -   TAM ÖRTÜŞÜYOR
     mhs.mhsFis.fisBA             sema  2 · canlı  2 · SEMADA YOK: -   TAM ÖRTÜŞÜYOR
     depo.paletIcHrkTip           sema  4 · canlı  3 · SEMADA YOK: -   (3 GERİ AL yok)
     depo.adres.adrsAlanTipID     sema  3 · canlı  5 · SEMADA YOK: 2, 6   ** DRIFT **
     depo.emir.emTip              sema  5 · canlı  3 · SEMADA YOK: 5      ** DRIFT ** */

/* 3) ★ DRIFT-1 — depo.adres.adrsAlanTipID. Sema 3 kod biliyordu, canlıda 5 var.
      Dahası sema `5`i ÇIKARIMLA açıklıyordu ("özel alan, adrsAd ayırır").
      LOOKUP TABLOSU doğrudan söylüyor — liste elle yazılmaz.
   ⚠ Kolon adları TAHMİN EDİLMEZ: ilk denemede `adrsAlanTipID/adrsAlanTipAd` yazıldı,
     Err 207 döndü. Doğrusu `alanTipID` / `alanTipAd`. Önce sys.columns okunur. */
SELECT c.name AS kolon, ty.name AS tip
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
JOIN   DerinSISBkm.sys.columns c ON c.object_id = o.object_id
JOIN   DerinSISBkm.sys.types  ty ON ty.user_type_id = c.user_type_id
WHERE  s.name = 'depo' AND o.name IN ('adresAlanTip','emTip')
ORDER BY o.name, c.column_id;

SELECT alanTipID, alanTipAd FROM DerinSISBkm.depo.adresAlanTip ORDER BY alanTipID;
/* TAM küme (7 kod): 0 RAF · 1 GİRİŞ · 2 ÇIKIŞ · 3 ETİKETLEME · 4 BLOKAJ ·
   5 HAVUZ · 6 İADE.  ⇒ sema'daki "5 = özel alan, adrsAd ayırır" ÇIKARIMI
   yerine sözlüğün cevabı yazıldı: 5 = HAVUZ ALANI. */

/* 4) ★ DRIFT-2 — depo.emir.emTip. Canlıda `5` var, LOOKUP'TA DA YOK. */
SELECT emTipID, emTipAd FROM DerinSISBkm.depo.emTip ORDER BY emTipID;
/* Lookup 5 kod: 0 YERLEŞTİRME · 1 BESLEME · 2 TOPLAMA · 3 ARAÇ PLANLAMA · 4 HAVUZ. */

SELECT CONVERT(varchar(20), e.emTip) AS emTip, COUNT_BIG(*) AS adet,
       CONVERT(varchar(10), MIN(e.kTarih), 120) AS ilk,
       CONVERT(varchar(10), MAX(e.kTarih), 120) AS son,
       COUNT(DISTINCT e.emDepoID) AS depo
FROM   DerinSISBkm.depo.emir e WITH(NOLOCK)
GROUP BY e.emTip ORDER BY e.emTip;
/* Ölçüm 2026-09-12:
     emTip 2 → 10.344 kayıt · 2021-07-13 → 2026-09-12   AKTİF
     emTip 4 →  1.476 kayıt · 2021-07-12 → 2022-12-07   DURMUŞ
     emTip 5 →    487 kayıt · 2021-07-29 → 2026-09-12   AKTİF ama TANIMSIZ
   ⚠ İKİ YÖNLÜ UYUMSUZLUK:
     (a) sema'nın belgelediği 0 · 1 · 3 kodlarının canlıda SIFIR kaydı var;
     (b) canlıda AKTİF olan `5` ne sema'da ne de KENDİ LOOKUP TABLOSUNDA var
         → küme kendi sözlüğüne göre bile KAPALI DEĞİL.
   `5`in ADI ÖLÇÜLMEDİ — uydurulmadı, "bilinmiyor" diye yazıldı ve sorulacak. */
