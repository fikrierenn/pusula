/* ============================================================================
   SEMA ÇEKİRDEK KAYITLARINA KANIT ÜRETİMİ  (2026-09-12)
   DB: DerinSISBkm · EncoreMerkez · BKMDATA (profil: erp)

   NEDEN: `sema denetle` 185 kayıtta `kanit_yok` diyordu — ve bunlar en çok kullanılan
   ÇEKİRDEK kayıtlardı (`dbo.urn`, `dbo.irsHrk`, `dbo.irs`, `EncoreMerkez.Sales`,
   `depo.*` …). Yani sema'nın en güvendiğimiz kısmı "bunu nereden biliyoruz" sorusuna
   cevap veremiyordu.

   ⚠ KANIT UYDURULAMAZ. Yöntem: her kaydın KENDİ İDDİASINI (pk/key kolonları, nesnenin
   varlığı, büyüklüğü) canlıda doğrula, sonucu `evidence` olarak yaz. Bu hem boşluğu
   kapatır hem DRIFT VARSA yakalar — nitekim yakaladı (aşağıda blok 3).

   ⚠ KULLANIM ≠ KANIT (kullanıcı direktifi 2026-09-12: "sen yine test et yorumla ama
   kanıt kabul etme direkt olarak"). Bir sorgunun o tabloyu kullanması kaydın DOĞRU
   olduğunu göstermez — yanlış bir sorgu da o tabloyu kullanır. Bu yüzden kullanım
   bilgisi AYRI alana (`applied_in`) ve "ERİŞİMDİR, DOĞRULUK DEĞİL" uyarısıyla yazıldı.

   SONUÇ: entities'te 60 kayıt kapandı (31'ine ÖLÇÜLMÜŞ kanıt · 29'una gerekçeli
   `evidence_status: pending`). Toplam UYARI 731 → 671, `kanit_yok` 185 → 125.
   ============================================================================ */

/* 1) HEDEF LİSTESİ — hangi kayıtların kanıtı yok?
      (dosya tarafı: `sema denetle --ayrintili | grep "evidence yok"`)
      Aşağıdaki sorgu, kaydın İDDİA ETTİĞİ nesnenin canlı karşılığını getirir.
   ⚠ `--max-rows` AÇIKÇA verilir ve dönen satır beklenenle karşılaştırılır:
     ilk denemede tüm katalog çekildi ve TAM 3000 satır döndü = SESSİZ KESİLME.
     Hedef tablolarla daraltınca 609 satıra indi. */
SELECT 'DerinSISBkm' AS db, s.name AS sema, o.name AS obj, o.type_desc,
       c.name AS kolon, ISNULL(ps.satir,0) AS satir
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
JOIN   DerinSISBkm.sys.columns c ON c.object_id = o.object_id
OUTER APPLY (SELECT SUM(p.row_count) AS satir
             FROM   DerinSISBkm.sys.dm_db_partition_stats p
             WHERE  p.object_id = o.object_id AND p.index_id IN (0,1)) ps
WHERE  o.type IN ('U','V')
  AND ((s.name='dbo'  AND o.name IN ('urn','irsHrk','irs','mekan_vw','car','frm','drn1',
                                     'carCek','bakiyeVDGG_vw'))
    OR (s.name='depo' AND o.name IN ('emir','emirAyr','emirSat','paletIcHrk','paletSevkLog',
                                     'paletUrnTnm','paletTnm','adres','stok_adres_palet_vw'))
    OR (s.name='mhs'  AND o.name IN ('mhsFis','mhsFisBaslik','mhsHsp','mhsAnaHsp','mzn',
                                     'mhsMizan_vw'))
    OR (s.name='bkm'  AND o.name IN ('UrunBilgi','Fin_AyKapanis','MalKabulBaslik',
                                     'MalKabulSatirLog','OneriSiparisKullaniciKategori'))
    OR (s.name='ent'  AND o.name IN ('JokerCKStok_vw','odak_depo_Stok')));
/* Aynısı EncoreMerkez (Sales, Products, SalesProductCampaigns) ve BKMDATA (Hedef) için.
   ⚠ VIEW'da `dm_db_partition_stats` SATIR VERMEZ → view kayıtlarına "0 satır" YAZILMADI,
     "satır sayısı partition-stats'ta YOK (view)" yazıldı. "0" yazmak yanlış iddia olurdu. */

/* 2) DOĞRULAMA MANTIĞI (Python tarafında): kayıttaki pk + key kolonlarının HEPSİ
      yukarıdaki canlı kolon kümesinde var mı?
      Sonuç: 35 kayıt karşılaştırıldı → 31 TUTTU · 4 TUTMADI. */

/* 3) ★ TUTMAYAN 4 KAYIT — üçü GÖSTERİM, biri GERÇEK HATA
      mhs.mhsHsp        pk: "(hspID, hspSirketID)"   → tek METİN, makineyle doğrulanamaz
      bkm.Fin_AyKapanis pk: "(DonemYil, DonemAy)"    → tek METİN
      mhs.mzn           key: [... h1..h8, h1Ad..h8Ad] → ARALIK gösterimi
      dbo.carCek        pk: "(çek)"                  → ❌ ÖYLE BİR KOLON YOK */

/* 3a) carCek'in GERÇEK anahtarı — tahmin edilmedi, ölçüldü */
SELECT i.name AS indeks, i.is_primary_key, c.name AS kolon, ic.key_ordinal
FROM   DerinSISBkm.sys.indexes i
JOIN   DerinSISBkm.sys.index_columns ic ON ic.object_id = i.object_id
                                       AND ic.index_id  = i.index_id
JOIN   DerinSISBkm.sys.columns c ON c.object_id = i.object_id
                                AND c.column_id = ic.column_id
JOIN   DerinSISBkm.sys.objects o ON o.object_id = i.object_id
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
WHERE  s.name = 'dbo' AND o.name = 'carCek' AND i.is_primary_key = 1
ORDER BY ic.key_ordinal;
/* -> cekID (tanımlı PRIMARY KEY). */

/* 3b) Tekillik sınaması — "PK var" demek yetmez, tutuyor mu? */
SELECT COUNT(*)                AS satir,
       COUNT(DISTINCT cekID)   AS tekil_cekID,
       COUNT(DISTINCT cekNo)   AS tekil_cekNo
FROM   DerinSISBkm.dbo.carCek WITH(NOLOCK);
/* -> 12.097 / 12.097 / 12.092.
   cekID TEKİL (PK doğrulandı) · cekNo TEKİL DEĞİL → anahtar olamaz.
   Sema'daki `pk: "(çek)"` düzeltildi: `pk: [cekID]`. */

/* 4) KULLANIM İŞARETÇİSİ — `applied_in` alanına yazılan şey.
      Kod tarafında: grep -rlw <tablo> sorgular/ dashboard/ scripts/
      Ölçüm 2026-09-12: 31 kaydın 25'i kod/sorguda geçiyor, 6'sı HİÇ geçmiyor
      (depo.emirSat · depo.paletSevkLog · ent.JokerCKStok_vw ·
       bkm.OneriSiparisKullaniciKategori · bkm.MalKabulBaslik · bkm.MalKabulSatirLog).
      En çok geçenler: EncoreMerkez.Sales 87 dosya · dbo.irsHrk 80 · dbo.urn 64 ·
      bkm.UrunBilgi 48 · dbo.irs 36 · dbo.frm 36.
   ⚠ BU SAYI ERİŞİMDİR, DOĞRULUK DEĞİL. 87 dosyada geçen yanlış bir kayıt,
     87 dosyada yanlıştır. Kanıt `evidence` alanındadır, bu alanda değil. */
