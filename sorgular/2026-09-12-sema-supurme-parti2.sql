/* ============================================================================
   ŞEMA SÜPÜRMESİ — 2. PARTİ  (2026-09-12)
   DB: DerinSISBkm (profil: erp)
   Kuyruk: 403 iş tablosu · 1. parti 9 · bu parti 10 → kalan 384.

   ⚠ BU PARTİNİN EN ÖNEMLİ BULGUSU BİR TABLO DEĞİL, BİR DURUM:
     iki büyük ön-agrega ~DOKUZ AY BAYAT ve bunu gören hiçbir şey yok.
   ============================================================================ */

/* 1) KOLON + PK dökümü (10 tablo) */
SELECT s.name+'.'+o.name AS tablo, c.column_id, c.name AS kolon, ty.name AS tip,
       CASE WHEN ic.key_ordinal IS NOT NULL THEN 1 ELSE 0 END AS pk
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
JOIN   DerinSISBkm.sys.columns c ON c.object_id = o.object_id
JOIN   DerinSISBkm.sys.types  ty ON ty.user_type_id = c.user_type_id
LEFT JOIN DerinSISBkm.sys.indexes i ON i.object_id = o.object_id AND i.is_primary_key = 1
LEFT JOIN DerinSISBkm.sys.index_columns ic ON ic.object_id = o.object_id
       AND ic.index_id = i.index_id AND ic.column_id = c.column_id
WHERE (s.name='bkm'   AND o.name IN ('Rapor_IrsHrk_GunlukOzet','StokBakiyeGunluk',
                                     'Enf_AylikUrunSatislari','SiparisOdemeDurum',
                                     'OdakIrsaliyeDetay'))
   OR (s.name='depo'  AND o.name='emirTerm')
   OR (s.name='dbo'   AND o.name='urnFrm')
   OR (s.name='earsv' AND o.name='efatArsv')
   OR (s.name='ent'   AND o.name='fiyat_tarihce_tsoft')
   OR (s.name='drs'   AND o.name='derinus2')
ORDER BY tablo, c.column_id;

/* 2) ★ TAZELİK + İKİ-TABAN SINAMASI — iki ön-agregayı sorgula */
SELECT (SELECT CONVERT(varchar(10), MAX(GunTarih),120)
          FROM DerinSISBkm.bkm.Rapor_IrsHrk_GunlukOzet WITH(NOLOCK)) AS rapor_son_gun,
       (SELECT CONVERT(varchar(10), MAX(Tarih),120)
          FROM DerinSISBkm.bkm.StokBakiyeGunluk WITH(NOLOCK))        AS bakiye_son_gun,
       (SELECT COUNT_BIG(*) FROM DerinSISBkm.bkm.StokBakiyeGunluk WITH(NOLOCK)
         WHERE StokMiktar_HareketEsas <> StokMiktar_EvrakEsas)       AS iki_taban_farkli,
       (SELECT COUNT_BIG(*) FROM DerinSISBkm.bkm.StokBakiyeGunluk WITH(NOLOCK)) AS bakiye_satir;
/* Ölçüm 2026-09-12:
     Rapor_IrsHrk_GunlukOzet  son gün 2025-12-24   → ~9 AY BAYAT (9,48M satır)
     StokBakiyeGunluk         son gün 2025-12-27   → ~9 AY BAYAT (5,33M satır)
     StokMiktar_HareketEsas <> StokMiktar_EvrakEsas olan satır: 0 (%0,00)

   ⇒ İKİ SONUÇ:
   (a) 14,8M satırlık iki ön-agrega bugünün verisini TAŞIMIYOR. "Hızlı olsun" diye
       buraya yönelen bir rapor SESSİZCE 2025 rakamı gösterir. Kodda neredeyse hiç
       kullanılmadıkları için (0 ve 1 dosya) kimse fark etmemiş.
   (b) `StokBakiyeGunluk`un İKİ TABAN kolonu (`HareketEsas` / `EvrakEsas`) isimleri
       farklı taban vaat ediyor ama BUGÜNKÜ VERİDE TAMAMEN ÖZDEŞ. Ayrıştıkları gün
       hangisinin doğru olduğu YAZILI DEĞİL. */

/* 3) KOD ERİŞİMİ (dosya sistemi tarafı — grep -rlw) */
/* Ölçüm 2026-09-12 · dashboard + scripts + sorgular + tools:
     Rapor_IrsHrk_GunlukOzet 0 · StokBakiyeGunluk 1 · Enf_AylikUrunSatislari 1
     SiparisOdemeDurum 0 · OdakIrsaliyeDetay 0 · urnFrm 0 · derinus2 0
     efatArsv 0 · emirTerm 1 · fiyat_tarihce_tsoft 0
   ⚠ ERİŞİM ≠ DOĞRULUK. Bu sayı "kod bu tabloyu tanıyor mu"yu söyler, tablonun
     doğru anlaşıldığını DEĞİL. */

/* 4) PARTİ 2 ÖZETİ — ölçülen ve sema'ya yazılan
     bkm.Rapor_IrsHrk_GunlukOzet 9.484.180 · PK(GunTarih,ehMekan,ehTip,ehstkID)  BAYAT
     earsv.efatArsv              6.667.883 · PK efatArsvID        e-arşiv (XML gövdeli)
     ent.fiyat_tarihce_tsoft     6.586.731 · PK YOK               e-tic fiyat tarihçesi
     drs.derinus2                5.979.652 · PK d2ID              el terminali okuması
     bkm.StokBakiyeGunluk        5.333.738 · PK 4'lü              BAYAT + iki özdeş taban
     bkm.Enf_AylikUrunSatislari  4.771.411 · PK(Ay,stkID,Kaynak)  üst/net fiyat AYRI
     depo.emirTerm               4.601.636 · PK 2'li              saf çoka-çok köprü
     dbo.urnFrm                  3.824.279 · PK(stkID,firmaID)    ürün↔tedarikçi, FAN-OUT
     bkm.SiparisOdemeDurum       1.847.633 · PK YOK               sip/fatura/tahsil ÜÇGENİ
     bkm.OdakIrsaliyeDetay       1.829.125 · PK YOK               KdvOran GERÇEK ORAN

   ★ ÜÇ TEKRAR EDEN DESEN (parti 1 + 2 birlikte):
   1. PK'SIZ BÜYÜK TABLO: sipAyr (41,7M) · SiparisOdemeDurum (1,85M) ·
      OdakIrsaliyeDetay (1,83M) · fiyat_tarihce_tsoft (6,59M). Doğal anahtar
      görünüyor ama TEKİLLİĞİ SINANMADAN join anahtarı yapılırsa fan-out.
   2. KDV: DerinSIS yerlisi KOD taşır (`urn.KDVs`, `posOzetUrun.posKDV`);
      e-fatura/ODAK tarafı GERÇEK ORAN taşır (`efatAyr.KdvYuzdesi`, `OdakIrsaliyeDetay.KdvOran`).
      İkisi aynı sorguda karışırsa sessiz yanlış rakam.
   3. FİYAT İKİLİĞİ her yerde ama FARKLI İSİMLERLE: `fyt.oncekiFiyat/sonrakiFiyat` ·
      `Enf_*.UstFiyat*/NetFiyat*` · `fiyat_tarihce_tsoft.fiyatliste/fiyatnet` ·
      `OdakIrsaliyeDetay.BirimFiyat/NetFiyat`. Aynı kavram, dört ayrı ad.
*/
