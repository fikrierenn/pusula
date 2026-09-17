/* ============================================================================
   BKMKİTAP Eksik ve Fazla Takip Raporu — KAYNAK KEŞFİ (2026-09-17)
   Soru : 11 sayfalık çalışma kitabının hangi sayfası hangi kaynaktan üretilebilir?
   DB   : DerinSISBkm (BKM.vrd.* + OPENQUERY[PDKS]) · BKM_GENEL (Zirve, AYRI sunucu)
   Bulgu: 7 sayfa üretilebilir · 2 sayfa elle girilen veri · 2 kolon (V/W, AK) türetilemez.
   Üretim: scripts/eksik_fazla_takip_raporu.py · parametre config/vardiya_parametreleri.json
   ============================================================================ */

/* 1) ZİRVE — "Güncel Personel Listesi" sayfasının kaynağı.
      ⚠ perbilgi'ye DOĞRUDAN inilmez (A4/SeriNo satırın yaşına göre iki anlamlı,
        sema: zirve_perbilgi_a4_iki_anlamli). Kadro daima bu view üzerinden.
      ⚠ İkinci parametre DÖNEM BAŞI'dır, dönem sonu DEĞİL: dönem içinde ayrılan
        kişi listeden düşerse ana sayfadaki `Aktif/Pasif` onu "Pasif" gösterir,
        oysa o günlerde çalışıp kart basmıştır.
      ÖLÇÜM (31.08–13.09.2026): dönem sonuna bakınca 18 kişi / 167 kişi-gün kayboldu;
      dönem başına çekilince 6 kişi kaldı (onlar gerçekten Zirve'de kayıtsız). */
SELECT  AdSoyad, Vatno, Dt, Igt, Ict, Cinsiyet,
        Lokasyon, AltLokasyon, AltAltLokasyon, Departman, Unvan, Kadro, Firma
FROM    BKM_GENEL.dbo.vw_PersonelDepartman
WHERE   Igt <= '20260913' AND (Ict IS NULL OR Ict >= '20260831')
ORDER BY AdSoyad;

/* 2) Kart basmış ama Zirve'de o dönemde kaydı OLMAYAN 6 kişinin teşhisi.
      İki sınıf çıktı: (a) Ict geçmişte dolu ama kişi çalışıyor (ERTUĞRUL AKSOY,
      EMRE AYDIN, EMRE DEMİR — Ict 2026-03-10 / 2025-12-31), (b) yeni kayıt dönem
      BİTİMİNDEN SONRA açılmış (AYFER BİÇER, Igt 2026-09-14).
      ⇒ Rapor hatası DEĞİL, İK kayıt boşluğu. Uydurulmaz, raporlanır. */
SELECT AdSoyad, Igt, Ict, Lokasyon, AltLokasyon, Firma
FROM   BKM_GENEL.dbo.vw_PersonelDepartman
WHERE  AdSoyad IN ('HAKAN ÇETİN','ERTUĞRUL AKSOY','AZİZHAN MEYDAN',
                   'EMRE AYDIN','EMRE DEMİR','AYFER BİÇER')
ORDER BY AdSoyad, Igt;

/* 3) Vardiya planı + PDKS okutması: ana sayfanın C..Q kolonları.
      Tam sorgu ve ÖLÇÜLMÜŞ kurallar (10 dk çift yönlü tolerans · çıkışta tolerans
      YOK · mola tablosu · 5 durum kodu) çekirdek script'tedir:
        scripts/vardiya_pdks_program_raporu.py  (SQL_PLAN / SQL_PDKS / SQL_TC /
        SQL_HAM_OKUTMA / SQL_SUBE_GRP / SQL_PDKS_SUBE / SQL_NET_GEREKEN)
      Arşiv: sorgular/2026-09-15-vardiya-pdks-program-raporu.sql
      Burada tekrarlanmaz — kopyalanan SQL çatallanır (emitter-ayrimi.md). */

/* 4) Şube başına "olması gereken net çalışma" — elle yazılmaz, plandan ÖLÇÜLÜR.
      ÖLÇÜM (31.08–13.09.2026): GENEL MÜDÜRLÜK 09:00 · diğer 8 şube 07:30.
      Tek sabit kullanılsaydı GM'nin TÜM kadrosu günde 1,5 saat fazla mesai görünürdü. */
SELECT  s.SubeAd, vz.ToplamCalismaDk, COUNT(*) AS KisiGun
FROM        BKM.vrd.Vardiya       v
INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo     = v.SubeNo
INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
CROSS APPLY (VALUES (vd.Pazartesi), (vd.Sali), (vd.Carsamba), (vd.Persembe),
                    (vd.Cuma), (vd.Cumartesi), (vd.Pazar)) AS g(Vid)
INNER JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.Vid
WHERE   v.Tarih >= DATEADD(day, -6, '20260831') AND v.Tarih <= '20260913'
    AND vz.Izin = 0 AND g.Vid <> 0 AND vz.ToplamCalismaDk > 0
GROUP BY s.SubeAd, vz.ToplamCalismaDk
ORDER BY s.SubeAd, KisiGun DESC;
