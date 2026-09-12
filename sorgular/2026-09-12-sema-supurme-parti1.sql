/* ============================================================================
   ŞEMA SÜPÜRMESİ — 1. PARTİ  (2026-09-12)
   DB: DerinSISBkm (profil: erp)

   NEDEN (kullanıcı direktifi): "sen neden tüm şemaya bakıp sıra ile keşifler
   yaparak tüm şemayı çözmüyorsun". Haklı — o güne kadar iş TEPKİSEL yürüyordu
   (bir ipin ucunu tut, çek). Tepkisel yol gerçek bulgular üretti ama KAPSAM üretmedi.

   ⚠ AMA DÜZ KATALOG DA İŞE YARAMAZ. Bu oturumun gerçek bulguları — `posKDV` oran
     değil KOD · `eTip 4` Sınav vekili DEĞİL · `carCek` pk'si olmayan bir kolonu
     gösteriyordu — hepsi DAVRANIŞ ölçmekten çıktı, liste çıkarmaktan değil.
     Bu yüzden süpürme "tablo adı + kolon listesi" değil; her kayıt en az bir
     ÖLÇÜLMÜŞ gerçek ya da açıkça ÇIKARIM etiketi taşır.
   ============================================================================ */

/* 1) YÜZEY — şema başına obje / dolu / satır */
SELECT s.name AS sema, COUNT(*) AS obje,
       SUM(CASE WHEN o.type='U' THEN 1 ELSE 0 END) AS tablo,
       SUM(CASE WHEN o.type='V' THEN 1 ELSE 0 END) AS view_,
       SUM(CASE WHEN ISNULL(ps.satir,0)>0 THEN 1 ELSE 0 END) AS dolu,
       CONVERT(bigint, SUM(ISNULL(ps.satir,0))) AS satir
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
OUTER APPLY (SELECT SUM(p.row_count) AS satir
             FROM   DerinSISBkm.sys.dm_db_partition_stats p
             WHERE  p.object_id = o.object_id AND p.index_id IN (0,1)) ps
WHERE  o.type IN ('U','V')
GROUP BY s.name ORDER BY SUM(ISNULL(ps.satir,0)) DESC;
/* Ölçüm: 1.233 obje (856 tablo + 377 view) · 568 DOLU · 2.837.052.547 satır.
   ent 1,83 milyar (api_log) · dbo 586M · bkm 306M · mhs 55M · depo 21,6M. */

/* 2) KUYRUK — yedek/temp elenir, sema'nın bildiği düşülür.
      ⚠ Sınıflandırma DESENDİR, kanıt değil: `_` önekli · `tmp`/`temp` · 8 haneli
        tarih içeren · `sil` şeması. Desen yanlış eleyebilir; eleme GERİ ALINABİLİR. */
SELECT s.name+'.'+o.name AS ad,
       CONVERT(bigint, ISNULL(ps.satir,0)) AS satir,
       CONVERT(varchar(10), o.modify_date, 120) AS degisim,
       CASE WHEN o.name LIKE '\_%' ESCAPE '\' OR o.name LIKE 'tmp%'
              OR o.name LIKE '%temp%' OR o.name LIKE '%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%'
              OR o.name LIKE '%yedek%' OR o.name LIKE '%backup%' OR s.name='sil'
            THEN 'YEDEK/TEMP' ELSE 'is' END AS sinif
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
OUTER APPLY (SELECT SUM(p.row_count) AS satir
             FROM   DerinSISBkm.sys.dm_db_partition_stats p
             WHERE  p.object_id = o.object_id AND p.index_id IN (0,1)) ps
WHERE  o.type='U' AND ISNULL(ps.satir,0) > 0
ORDER BY ps.satir DESC;
/* Ölçüm: 568 dolu tablo → YEDEK/TEMP 124 (49,2M satır) · İŞ 444.
   Sema bunların 41'ini biliyor → KUYRUK 403 tablo / 2.224.522.331 satır. */

/* 3) 1. PARTİ — en ağır 8 iş tablosu (ent.api_log hariç: 1,82 milyar satırlık LOG) */
SELECT s.name+'.'+o.name AS tablo, c.column_id, c.name AS kolon, ty.name AS tip,
       c.is_nullable, CASE WHEN ic.key_ordinal IS NOT NULL THEN 1 ELSE 0 END AS pk
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
JOIN   DerinSISBkm.sys.columns c ON c.object_id = o.object_id
JOIN   DerinSISBkm.sys.types  ty ON ty.user_type_id = c.user_type_id
LEFT JOIN DerinSISBkm.sys.indexes i ON i.object_id = o.object_id AND i.is_primary_key = 1
LEFT JOIN DerinSISBkm.sys.index_columns ic ON ic.object_id = o.object_id
       AND ic.index_id = i.index_id AND ic.column_id = c.column_id
WHERE (s.name='dbo'  AND o.name IN ('fytOzl','drn2','sipAyr','fyt','posOzetUrun',
                                    'urnBilgi','fat','urnOzt'))
   OR (s.name='eftr' AND o.name='efatAyr')
ORDER BY tablo, c.column_id;

/* ÖLÇÜLEN — parti 1 özeti (hepsi sema/entities.yaml'a yazıldı)
   dbo.fytOzl      155.649.829 · 27 kol · PK fID          fiyat tarihçesi (geniş)
   dbo.drn2         60.571.406 ·  9 kol · PK izID         DENETİM İZİ (kim/ne/ne zaman)
   dbo.sipAyr       41.742.913 · 25 kol · **PK YOK**      sipariş satırı
   dbo.fyt          15.737.428 · 12 kol · PK fID          fiyat tarihçesi (dar)
   dbo.posOzetUrun  13.151.756 · 11 kol · PK (mekan,tarih,stkID)  POS KÖPRÜSÜ
   dbo.urnBilgi     10.431.581 ·  3 kol · PK (bVeriID,bBilgiID)   EAV
   dbo.urnOzt        8.377.810 · 47 kol · PK (stkID,mekan)        ÜRÜN×MEKAN ÖN-AGREGA
   eftr.efatAyr      8.159.668 · 27 kol · PK (efatID,Sira)        e-fatura satırı
   dbo.fat           7.050.770 · 52 kol · PK eID                  FATURA BAŞLIĞI

   ★ ÜÇ GERÇEK BULGU:
   (a) `dbo.fat` SEMA BOŞLUĞUYDU — `codes:fat.eTip` kod kümesi kayıtlıydı ama
       TABLONUN KENDİSİ entities'te yoktu. Kod sözlüğü var, nesnesi yok.
   (b) `dbo.sipAyr` 41,7M satır ve TANIMLI PRIMARY KEY YOK. Doğal anahtar
       `(ehID, ehSira)` görünüyor ama TEKİLLİĞİ SINANMADI — sınanmadan join
       anahtarı yapılırsa fan-out riski var.
   (c) `dbo.urnBilgi` ≠ `bkm.UrunBilgi`. Biri DerinSIS'in 3 kolonluk EAV tablosu,
       öteki BKM'nin 37 kolonluk zenginleştirilmiş ürün view'ı. Sorguda biri
       diğerinin yerine yazılırsa HATA VERMEZ, boş/yanlış sonuç döner.

   ⚠ ÇIKARIM ETİKETLİ (ölçülmedi, yazıldı):
   · `fyt` ↔ `fytOzl` iş bölümü (hangisi kanonik)
   · `urnOzt` ön-agregasının tazeliği ve dolduran job
   · `drn2.izTip` / `izProgID` kod kümeleri
   · `efatAyr.SatirEslesmeDurum` kod kümesi
*/
