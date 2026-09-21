-- PDKS'te GÖRÜNEN ama ZİRVE'DE OLMAYAN personel — üç kaynak çapraz kontrolü.
-- Soru (GMY 21.09.2026): "zirve'den kontrol et <kişi>" — zei32 raporundan düşen
--   kişi gerçekten çalışmamış mı, yoksa kayıt mı eksik?
--
-- ⚠ KVKK: TC bu dosyaya YAZILMAZ, parametre olarak verilir.
--   Çalıştırma:  sqlcli query --profile zirve --param tc:str=<TC> ...
--
-- ÜÇ KAYNAK, ÜÇÜ DE AYRI SORUYA CEVAP VERİR — biri yetmez:
--   PDKS  (TPerTab/TPerInd)     → kart açıldı mı, okutma var mı
--   ERP   (BKM.vrd.Vardiya*)    → mağaza bu kişiye vardiya yazdı mı
--   ZİRVE (vw_PersonelDepartman)→ bordroya girdi mi (işe giriş/çıkış tarihi)
-- Kart açılmış olması İŞE BAŞLADI demek DEĞİLDİR.

-- ── 1) PDKS: kart kaydı, okutma, aktiflik ────────────────────────────────
-- (LIVE201 → PDKS çift atlama; ham OPENQUERY yazma, zei32_rapor.cift_atlama kullan)
-- TC kolonu TPerInd.PIn_SteuerNr'dedir — TPerTab'da Per_SteuerNr DİYE BİR KOLON YOK
-- (207 alındı 21.09.2026).
--   SELECT p.Per_PersNr, p.Per_Vorname, p.Per_Name, i.PIn_SteuerNr,
--          p.Per_AuswNr, p.Per_ZeitAktiv, p.Per_Grp1, p.Per_Grp2, p.Per_Grp3,
--          ilk_gun    = (SELECT MIN(s.TMS_Datum) FROM TTagMoS s WHERE s.TMS_PersNr=p.Per_PersNr),
--          son_gun    = (SELECT MAX(s.TMS_Datum) FROM TTagMoS s WHERE s.TMS_PersNr=p.Per_PersNr),
--          okutma_hic = (SELECT COUNT(*) FROM TTagLes l WHERE l.TLe_PersNr=p.Per_PersNr
--                        AND l.TLe_VonZeit IS NOT NULL)
--   FROM TPerTab p LEFT JOIN TPerInd i ON i.PIn_PersNr = p.Per_PersNr
--   WHERE p.Per_Name LIKE '%<SOYAD>%'

-- ── 2) ERP: mağaza vardiya planına yazmış mı? ────────────────────────────
-- profil: erp   (⚠ vrd şeması DerinSISBkm'de değil, BKM veritabanında:
--                 2 parçalı 'vrd.VardiyaDetay' → Err 208. 3 parçalı yaz.)
SELECT  s.SubeAd, COUNT(*) AS satir, MIN(v.Tarih) AS ilk, MAX(v.Tarih) AS son
FROM        BKM.vrd.Vardiya       v
INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo    = v.SubeNo
INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
WHERE   vd.SicilNo = @tc          -- SicilNo = 11 haneli TC
GROUP BY s.SubeAd;

-- ── 3) ZİRVE: bordro kaydı var mı? ───────────────────────────────────────
-- profil: zirve (192.168.40.25\ZRVSQL2008 — adlandırılmış örnek, pyodbc)
-- ⚠ Igt = işe giriş tarihi · Ict = işten çıkış tarihi (NULL = hâlâ çalışıyor).
-- ⚠ View işten AYRILANLARI DA taşır (Ict dolu) → "yok" demek gerçekten yok demek.
--   Kapsam ölçüldü 21.09.2026: 3 firma / 1.301 kişi ·
--   BKM_GENEL 1.108 · BURSA_KÜLTÜR_MERKEZİ 145 · ASİYE_BİNGÖLBALI 48 ·
--   Igt 2009-01-03 → 2026-09-16.  Vatno = 11 hane, TC ile birebir aranabilir.
SELECT  Personelno, AdSoyad, Igt, Ict, Lokasyon, AltLokasyon,
        Departman, Unvan, Kadro, IstenCikisKodu, Firma
FROM    dbo.vw_PersonelDepartman
WHERE   Vatno = @tc;

-- ── BULGU (21.09.2026, PersNr 3511 · FSM / MAL KABUL) ────────────────────
--   PDKS  : kart açılmış, 03-08.09.2026 arası 6 gün, okutma SIFIR, sonra pasif
--           (Per_ZeitAktiv=0 + Per_AuswNr=PersNr → ayrılma ölçütü)
--   ERP   : vardiya planında HİÇ satır yok — mağaza ona vardiya yazmamış
--   ZİRVE : TC bordroda HİÇ yok (ayrılan kaydı bile yok)
--   ⇒ ÜÇ KAYNAK DA AYNI ŞEYİ SÖYLÜYOR: işe başlamamış. zei32 'ayrılanlar hariç'
--     süzgecinin onu düşürmesi DOĞRU. "6 günü var" tek başına çalıştı demek değil.
--   Not: aynı bölüme (FSM / MAL KABUL) 16.09.2026'da yeni giriş var — kadro
--     sonradan doldurulmuş görünüyor (ÇIKARIM, aynı pozisyon olduğu ölçülmedi).
