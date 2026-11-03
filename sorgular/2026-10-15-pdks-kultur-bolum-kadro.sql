-- =============================================================================
-- PDKS KÜLTÜR BÖLÜMÜ — MAĞAZA BAZLI KADRO × KİTAP İŞ YÜKÜ (Eylül 2026)
-- Soru: Kültür reyonunda mağaza başına kaç kişi çalışıyor, günde kaç kişi var,
--       bu Kitap satış hacmiyle orantılı mı? Norm (11.08) ve Zirve 31.08 ile kıyas.
-- Tarih: 15.10.2026 · Ölçüm sahibi: GMY talebi
--
-- KAYNAKLAR
--   PDKS  : BkmPanel → LIVE201 → [PDKS] çift atlama (vardiya/zei32_rapor.py cift_atlama).
--           Blok 1-3 PDKS İÇ sorgusudur; elle OPENQUERY tırnağı yazma, cift_atlama'ya ver.
--           (201 üzerinde SSMS'ten: SELECT * FROM OPENQUERY([PDKS], '<iç sorgu, '' ile>'))
--   ERP   : DerinSISBkm (blok 4) · Encore: EncoreMerkez (blok 5) · Zirve: BKM_GENEL (blok 6)
--
-- TANIMLAR
--   Kültür personeli  = TPerTab.Per_Grp1 'MAĞAZALAR' + Per_Grp3 = 'KÜLTÜR'
--                       (Per_Grp2 şube, Per_Grp4 görev: REYON ŞEFİ / SATIŞ DANIŞMANI)
--   Aktif kişi        = Eylül'de saatli TTagLes okutması olan; işten çıkan HARİÇ
--                       (Per_ZeitAktiv = 0 AND Per_AuswNr = PersNr)
--   Fiili saat        = gün başına ilk giriş → son çıkış (molayı İÇERİR; Kültür'de günde
--                       tek segment okutuluyor, brüt = segment toplamı ölçüldü)
--   Kitap             = bkm.UrunBilgi.Kategori3 = 'Kitap' (Çocuk Kitabı/Akademi/Hazırlık AYRI)
--   Ciro              = irsHrk ehTip 100 − 101 + 4 − 5, ehTutarN (KDV hariç), Sınav ürünü hariç
--
-- BULGU ÖZETİ (ÖLÇÜLDÜ 15.10.2026)
--   Şube     | kişi (şef+SD) | kişi-gün | fiili saat | günde ort | Kitap adet | Kitap net ₺ | adet/kişi-gün
--   FSM      | 5 (1+4)       | 135      | 1.211,0    | 4,50      | 15.048     | 3.881.374   | 111
--   HEYKEL   | 5 (1+4)       | 107      |   917,5    | 3,57      | ölçülemez (ayrı tüzel kişilik, DerinSISBkm'de satış yok)
--   İST.YOLU | 4 (1+3)       | 103      |   874,4    | 3,43      | 21.811     | 5.778.761   | 212
--   ÖZLÜCE   | 7 (1+6)       | 185      | 1.622,3    | 6,17      | 21.940     | 6.066.238   | 119
--   ⚠ İst.Yolu: işten çıkan 1 sezonluk (PersNr 3449, son okutma 27.09) 23 kişi-gün/199,1 saat
--     çalıştı; dahil edilirse günde ort 4,20, adet/kişi-gün 173.
--   ⚠ İst.Yolu Kitap'ının 3.424 adet / 896.745 ₺'si Sınav Okulları BELGESİ (Encore DocType 8);
--     düşülürse adet/kişi-gün 179 (çıkan dahil 146). FSM/Özlüce'de Sınav belgesinde Kitap yok.
--   Eşleşme: PDKS Kültür 22 kişinin 22'si Zirve'de de Departman='KÜLTÜR', aynı şube.
--     Zirve'de olup Eylül'de okutması olmayan tek kişi: Özlüce PersNr 2838 — DOĞUM izni
--     (TTagMoS mazeret DOGUM, 01.08-30.09 tamamı).
--   Norm (kadrolu) FSM 5 · İst.Yolu 4 · Özlüce 7 · Heykel 6.
--   Zirve 31.08 (kadro+sezonluk): FSM 5+1 · İst.Yolu 4+1 · Özlüce 7+0 · Heykel 4+0.
--   Zirve 30.09: FSM 4+1 · İst.Yolu 4+0 · Özlüce 8+0 (1'i doğum izni) · Heykel 5+0.
--   SINIR: Per_Grp3/Departman bugünkü değer; ay içinde bölüm değiştiren kişi bugünkü bölümde sayılır.
-- =============================================================================


-- ── BLOK 1 (PDKS iç sorgu) — bölüm envanteri: Eylül'de okutan kişi, Grp1×Grp2×Grp3 ──
SELECT p.Per_Grp1, p.Per_Grp2, p.Per_Grp3, COUNT(*) AS kisi,
       SUM(CASE WHEN o.n IS NULL THEN 0 ELSE 1 END) AS okutan
FROM TPerTab p
LEFT JOIN (SELECT TLe_PersNr, COUNT(*) n FROM TTagLes
           WHERE TLe_Datum >= '20260901' AND TLe_Datum <= '20260930' AND TLe_VonZeit IS NOT NULL
           GROUP BY TLe_PersNr) o ON o.TLe_PersNr = p.Per_PersNr
GROUP BY p.Per_Grp1, p.Per_Grp2, p.Per_Grp3
HAVING SUM(CASE WHEN o.n IS NULL THEN 0 ELSE 1 END) > 0;
-- (aggregate-CASE içinde EXISTS yazılamaz — Err 130; derived table ile)


-- ── BLOK 2 (PDKS iç sorgu) — Kültür kişi bazında kişi-gün + fiili dakika ──
-- ayrilan kolonu işten çıkan bayrağı; özet tabloda ayrilan = 0 alınır.
SELECT p.Per_PersNr, LTRIM(RTRIM(p.Per_Grp2)) AS sube, LTRIM(RTRIM(p.Per_Grp4)) AS gorev,
       p.Per_ZeitAktiv,
       CASE WHEN p.Per_ZeitAktiv = 0
             AND LTRIM(RTRIM(ISNULL(p.Per_AuswNr,''))) = CONVERT(varchar, p.Per_PersNr)
            THEN 1 ELSE 0 END AS ayrilan,
       COUNT(*) AS kisi_gun,
       SUM(d.brut_dk) AS brut_dk, SUM(d.net_dk) AS net_dk,
       SUM(CASE WHEN d.cikissiz_seg > 0 THEN 1 ELSE 0 END) AS cikissiz_gun,
       MIN(d.TLe_Datum) AS ilk_gun, MAX(d.TLe_Datum) AS son_gun
FROM TPerTab p
JOIN (
    SELECT TLe_PersNr, TLe_Datum,
           brut_dk = CASE WHEN MAX(TLe_BisZeit) IS NULL THEN NULL ELSE
                     (DATEDIFF(MINUTE, MIN(TLe_VonZeit), MAX(TLe_BisZeit)) + 1440) % 1440 END,
           net_dk  = SUM(CASE WHEN TLe_BisZeit IS NULL THEN 0
                         ELSE (DATEDIFF(MINUTE, TLe_VonZeit, TLe_BisZeit) + 1440) % 1440 END),
           cikissiz_seg = SUM(CASE WHEN TLe_BisZeit IS NULL THEN 1 ELSE 0 END)
    FROM TTagLes
    WHERE TLe_Datum >= '20260901' AND TLe_Datum <= '20260930'
      AND TLe_VonZeit IS NOT NULL            -- saatsiz mazeret satırı girişi boşaltır (sema)
    GROUP BY TLe_PersNr, TLe_Datum) d ON d.TLe_PersNr = p.Per_PersNr
WHERE p.Per_Grp1 LIKE 'MA%LAR%' AND LTRIM(RTRIM(p.Per_Grp3)) = 'KÜLTÜR'
GROUP BY p.Per_PersNr, p.Per_Grp2, p.Per_Grp4, p.Per_ZeitAktiv, p.Per_AuswNr
ORDER BY 2, 3, 1;
-- Ölçüldü: 22 kişi, çıkışsız gün 0, brüt = net (günde tek giriş/çıkış okutması).


-- ── BLOK 3 (PDKS iç sorgu) — şube × gün Kültür kişi sayısı (günlük ortalama/min/max) ──
SELECT LTRIM(RTRIM(p.Per_Grp2)) AS sube, d.TLe_Datum AS gun, COUNT(DISTINCT p.Per_PersNr) AS kisi
FROM TPerTab p
JOIN (SELECT DISTINCT TLe_PersNr, TLe_Datum FROM TTagLes
      WHERE TLe_Datum >= '20260901' AND TLe_Datum <= '20260930' AND TLe_VonZeit IS NOT NULL) d
  ON d.TLe_PersNr = p.Per_PersNr
WHERE p.Per_Grp1 LIKE 'MA%LAR%' AND LTRIM(RTRIM(p.Per_Grp3)) = 'KÜLTÜR'
  AND NOT (p.Per_ZeitAktiv = 0
           AND LTRIM(RTRIM(ISNULL(p.Per_AuswNr,''))) = CONVERT(varchar, p.Per_PersNr))
GROUP BY LTRIM(RTRIM(p.Per_Grp2)), d.TLe_Datum;
-- Ölçüldü (30 gün, sıfır gün yok): FSM 3-5 · HEYKEL 3-5 · İST.YOLU 3-4 · ÖZLÜCE 5-7.


-- ── BLOK 4 (DerinSISBkm) — Kitap satışı mağaza bazlı, kanonik formül, Sınav ürünü hariç ──
SELECT h.ehMekan,
       SUM(-h.ehAdetN) AS adet,                                     -- satış negatif, iade pozitif → işaret çevrilir
       SUM(CASE WHEN h.ehTip IN (100, 4) THEN h.ehTutarN ELSE -h.ehTutarN END) AS net_kdv_haric
FROM dbo.irsHrk h
JOIN bkm.UrunBilgi u ON u.stkID = h.ehstkID
WHERE h.ehTip IN (100, 101, 4, 5)
  AND h.ehMekan IN (1, 4477, 4478)                                  -- FSM · Özlüce · İst.Yolu (Heykel ayrı tüzel kişilik)
  AND h.ehTrhS >= CONVERT(date, '01.09.2026', 104)
  AND h.ehTrhS <  CONVERT(date, '01.10.2026', 104)
  AND u.Kategori3 = N'Kitap'
  AND u.KatAna NOT LIKE N'Sınav Okul%'
GROUP BY h.ehMekan;
-- Ölçüldü: 1 → 15.048 / 3.881.374 · 4477 → 21.940 / 6.066.238 · 4478 → 21.811 / 5.778.761


-- ── BLOK 5 (EncoreMerkez) — Kitap satışının belge tipine dağılımı (Sınav belgesi payı) ──
-- StoresId: 1 = İst.Yolu · 2 = FSM · 3 = Özlüce
SELECT s.StoresId, s.DocumentsTypeId,
       SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -sp.Amount ELSE sp.Amount END) AS adet,
       SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(sp.TotalPrice - sp.VatTotal)
                ELSE sp.TotalPrice - sp.VatTotal END) AS net_kdv_haric
FROM dbo.Sales s
JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN dbo.Products p ON p.Id = sp.ProductsId
JOIN DerinSISBkm.bkm.UrunBilgi u
  ON u.stkID = CASE WHEN ISNUMERIC(p.Code) = 1 THEN CONVERT(int, p.Code) END
WHERE s.Date >= CONVERT(datetime, '01.09.2026', 104)
  AND s.Date <  CONVERT(datetime, '01.10.2026', 104)
  AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND u.Kategori3 = N'Kitap'
GROUP BY s.StoresId, s.DocumentsTypeId;
-- Ölçüldü: DocType 8 (Sınav) yalnız İst.Yolu'nda → 3.424 adet / 896.745 ₺.
-- FSM ve Özlüce Encore toplamı ERP ile adet bazında %0,3 içinde tutuyor.


-- ── BLOK 6 (Zirve BKM_GENEL) — Kültür kadrosu 31.08 ve 30.09 itibarıyla ──
SELECT v.AltLokasyon, v.Departman, COALESCE(v.Kadro, '') AS Kadro,
       SUM(CASE WHEN v.Igt <= '20260831' AND (v.Ict IS NULL OR v.Ict >= '20260831') THEN 1 ELSE 0 END) AS k0831,
       SUM(CASE WHEN v.Igt <= '20260930' AND (v.Ict IS NULL OR v.Ict >= '20260930') THEN 1 ELSE 0 END) AS k0930
FROM dbo.vw_PersonelDepartman v
WHERE v.Lokasyon LIKE 'MA%'
  AND v.Departman = N'KÜLTÜR'
GROUP BY v.AltLokasyon, v.Departman, COALESCE(v.Kadro, '');
-- Kişi eşleşmesi (PDKS ↔ Zirve) ad-soyad ile yapıldı: 22/22 aynı şube + KÜLTÜR.


-- =============================================================================
-- EK — BUGÜN İTİBARIYLA (15.10.2026): RAF/ADRES + STOK + SON 30 GÜN
-- GMY: "reyon sayısı, stok adeti, adresli ürün adeti gibi şeyler de eklesek" +
--      "bugün itibari ile istiyorum".
-- Pencere: son 30 TAM gün 15.09–14.10.2026 (bugün hariç; kasa→ERP saatlik aktarım).
-- Stok ve raf ataması ANLIK — sorgunun koştuğu anın değeri.
--
-- BULGU (ÖLÇÜLDÜ 15.10.2026) — Kültür bölümü
--   KAYNAK: konum = bkm.SayimRaflari (KANONİK, çoklu konum dahil — blok 11), raf→bölüm ryn.*.
--   Şube     | kişi | günde ort | kişi-gün | Kitap adet (30g) | adet/kişi-gün | reyon | dolu raf | adresli ürün | stoklu çeşit | stok adet
--   FSM      | 5    | 4,47      | 134      | 17.895           | 134           | 42    | 1.972    | 76.224       | 57.342       |  97.699
--   İST.YOLU | 4    | 3,37      | 101      | 21.227 (*)       | 210           | 52    | 2.706    | 65.813       | 58.574       | 133.509
--   ÖZLÜCE   | 7    | 6,13      | 184      | 24.773           | 135           | 27    | 2.814    | 53.223       | 45.659       | 120.930
--   HEYKEL   | 5    | 4,03      | 121      | ölçülemez        | —             | raf sistemi yok (ryn.*'da mekan yok)
--   (*) Sınav belgesi (Encore DocType 8) 871 adet / 224.493 ₺ düşülmüş. İst.Yolu'nda ayrılan
--       sezonluk (3449) pencerede 11 gün çalıştı; dahil edilirse adet/kişi-gün 190.
--   Günlük kişi başı: dolu raf FSM 441 · İst.Yolu 803 · Özlüce 459 | stoklu çeşit 12.828 · 17.381 · 7.448
--                     | stok adet 21.856 · 39.617 · 19.728
--   Çok konumlu ürün (Kültür içinde 2+ raf): FSM 0 · İst.Yolu 721 · Özlüce 1.414.
--   Stok adeti ürünün MAĞAZA toplamıdır — ERP adeti konuma ayırmaz (sema bkm.SayimRaflari).
--   Kabul sınandı: Kültür rafındaki ürünlerin %92-97'si Kategori3='Kitap'
--     (FSM 70.422/76.224 · İst.Yolu 62.969/65.813 · Özlüce 51.424/53.223).
--   Kitap stoğunun Kültür alanındaki payı (adet, blok 9): FSM %76 · İst.Yolu %87 · Özlüce %73;
--     kalanı başka bölüm adresinde (Akademi/Çocuk); adressiz Kitap ≈ 0.
--   ⚠ Blok 7-9 bkm.SUBE_RAF_LISTE okur: ürün başına TEK konum (ada/stant/mağaza deposu yok).
--     Tablodaki rakamlar blok 11'den; 7-9 yapı ve kapsam kontrolü için duruyor.
--   SINIR: "reyon" mağazalar arası kıyaslanamaz — Özlüce reyonları daha iri tanımlı
--     (27 reyon / 2.814 dolu raf). Raf sayısı daha karşılaştırılabilir ama raf boyu ölçülmedi.
-- =============================================================================


-- ── BLOK 7 (DerinSISBkm) — Kültür bölümü raf yapısı ──
-- bkm.SUBE_RAF_LISTE = ryn.kat → alan (BÖLÜM) → reyon → rafGrp → raf → rafUrun
SELECT mekan, alanAD,
       COUNT(DISTINCT reyonID) AS reyon, COUNT(DISTINCT rafgrpID) AS raf_grubu,
       COUNT(DISTINCT rafID) AS raf, COUNT(*) AS satir, COUNT(DISTINCT stkId) AS adresli_urun
FROM bkm.SUBE_RAF_LISTE
GROUP BY mekan, alanAD
ORDER BY mekan, alanAD;


-- ── BLOK 8 (DerinSISBkm) — Kültür adresli ürünlerin kategori dağılımı + bugünkü stok ──
WITH adres AS (
    SELECT DISTINCT mekan, stkId FROM bkm.SUBE_RAF_LISTE WHERE alanAD = N'KÜLTÜR'
), stok AS (
    SELECT ehMekan, ehstkID, SUM(stok) AS stok FROM dbo.stokSonAltDepo_vw
    WHERE ehAltDepo = 0 AND ehMekan IN (1, 4477, 4478) GROUP BY ehMekan, ehstkID
)
SELECT a.mekan, u.Kategori3,
       COUNT(*) AS adresli_urun,
       SUM(CASE WHEN s.stok > 0 THEN 1 ELSE 0 END) AS stoklu_cesit,
       SUM(CASE WHEN s.stok > 0 THEN s.stok ELSE 0 END) AS stok_adet,
       SUM(CASE WHEN s.stok < 0 THEN 1 ELSE 0 END) AS eksi_stok_cesit
FROM adres a
LEFT JOIN stok s ON s.ehMekan = a.mekan AND s.ehstkID = a.stkId
LEFT JOIN bkm.UrunBilgi u ON u.stkID = a.stkId
GROUP BY a.mekan, u.Kategori3
ORDER BY a.mekan, adresli_urun DESC;


-- ── BLOK 9 (DerinSISBkm) — Kitap stoğunun adres kapsamı (Kültür / başka bölüm / adressiz) ──
WITH stok AS (
    SELECT ehMekan, ehstkID, SUM(stok) AS stok FROM dbo.stokSonAltDepo_vw
    WHERE ehAltDepo = 0 AND ehMekan IN (1, 4477, 4478) GROUP BY ehMekan, ehstkID
), adres AS (
    SELECT mekan, stkId, MAX(CASE WHEN alanAD = N'KÜLTÜR' THEN 1 ELSE 0 END) AS kultur
    FROM bkm.SUBE_RAF_LISTE GROUP BY mekan, stkId
)
SELECT s.ehMekan,
       COUNT(*) AS kitap_stoklu_cesit, SUM(s.stok) AS kitap_stok_adet,
       SUM(CASE WHEN a.kultur = 1 THEN 1 ELSE 0 END) AS kultur_adresli_cesit,
       SUM(CASE WHEN a.kultur = 1 THEN s.stok ELSE 0 END) AS kultur_adresli_adet,
       SUM(CASE WHEN a.stkId IS NOT NULL AND a.kultur = 0 THEN 1 ELSE 0 END) AS baska_alan_cesit,
       SUM(CASE WHEN a.stkId IS NULL THEN 1 ELSE 0 END) AS adressiz_cesit
FROM stok s
JOIN bkm.UrunBilgi u ON u.stkID = s.ehstkID AND u.Kategori3 = N'Kitap'
LEFT JOIN adres a ON a.mekan = s.ehMekan AND a.stkId = s.ehstkID
WHERE s.stok > 0
GROUP BY s.ehMekan;
-- Ölçüldü: FSM 72.793 çeşit/118.976 adet · İst.Yolu 63.554/146.751 · Özlüce 67.270/160.584.


-- ── BLOK 10 — son 30 gün: blok 2 ve blok 3 aynen, tarihler '20260915'..'20261014';
--             blok 4 tarihleri '15.09.2026'..'15.10.2026' (üst sınır hariç);
--             blok 5 aynı pencere, DocumentsTypeId = 8 → İst.Yolu 871 adet / 224.493 ₺.


-- ── BLOK 11 (DerinSISBkm) — KANONİK: Kültür rafı konumları bkm.SayimRaflari'ndan ──
-- SayimRaflari raf ADINI taşır; bölüm, ryn.* hiyerarşisinde (mekan, rafAD) eşlemesiyle bulunur.
-- Ölçüldü: rafAD eşleşmeyen konum satırı 2 (İst.Yolu), birden çok bölüme düşen raf adı ≤111 satır.
WITH kraf AS (
    SELECT DISTINCT k.katMekan AS mekan, f.rafAD, r.reyonID
    FROM ryn.kat k JOIN ryn.alan a ON a.alanKatID = k.katID AND a.alanAD = N'KÜLTÜR'
    JOIN ryn.reyon r ON r.reyonAlanID = a.alanID
    JOIN ryn.rafGrp g ON g.rafgrpReyonID = r.reyonID
    JOIN ryn.raf f ON f.rafRafGrpID = g.rafgrpID
), kon AS (
    SELECT DISTINCT s.MekanId, s.StokId, s.RafAd
    FROM bkm.SayimRaflari s
    WHERE EXISTS (SELECT 1 FROM kraf x WHERE x.mekan = s.MekanId AND x.rafAD = s.RafAd)
), urun AS (
    SELECT MekanId, StokId, COUNT(*) AS konum FROM kon GROUP BY MekanId, StokId
), stok AS (
    SELECT ehMekan, ehstkID, SUM(stok) AS stok FROM dbo.stokSonAltDepo_vw
    WHERE ehAltDepo = 0 AND ehMekan IN (1, 4477, 4478) GROUP BY ehMekan, ehstkID
)
SELECT u.MekanId,
       (SELECT COUNT(DISTINCT reyonID) FROM kraf WHERE kraf.mekan = u.MekanId) AS reyon,
       (SELECT COUNT(DISTINCT rafAD) FROM kraf WHERE kraf.mekan = u.MekanId) AS raf_tanimli,
       (SELECT COUNT(DISTINCT RafAd) FROM kon WHERE kon.MekanId = u.MekanId) AS raf_dolu,
       SUM(u.konum) AS konum_satiri,
       COUNT(*) AS adresli_urun,
       SUM(CASE WHEN u.konum > 1 THEN 1 ELSE 0 END) AS cok_konumlu_urun,
       SUM(CASE WHEN s.stok > 0 THEN 1 ELSE 0 END) AS stoklu_cesit,
       SUM(CASE WHEN s.stok > 0 THEN s.stok ELSE 0 END) AS stok_adet,
       SUM(CASE WHEN ub.Kategori3 = N'Kitap' THEN 1 ELSE 0 END) AS kitap_urun
FROM urun u
LEFT JOIN stok s ON s.ehMekan = u.MekanId AND s.ehstkID = u.StokId
LEFT JOIN bkm.UrunBilgi ub ON ub.stkID = u.StokId
GROUP BY u.MekanId;
-- Ölçüldü 15.10.2026: FSM 42 reyon / 2.141 tanımlı / 1.972 dolu raf · İst.Yolu 52 / 2.859 / 2.706
--   · Özlüce 27 / 2.957 / 2.814.


-- =============================================================================
-- EK 2 — SAAT BAZLI YOĞUNLUK × KÜLTÜR PERSONELİ (15.09–14.10.2026, 22 hafta içi + 8 hafta sonu)
-- GMY: "saat bazlı yoğunluk personel kıyası yapar mısın"
--
-- Personel kuralı = sema `pdks_saatlik_personel` (TrafikQueries.GetPdksPersonelAsync):
--   kişi-gün aralığı ilk giriş → son çıkış (mola dahil), giriş saati aşağı yuvarlanır,
--   çıkış dakikası > 0 ise o saat dahil, tam saatte çıkışta değil; ortalama = toplam /
--   o gün tipindeki TÜM günler. Kaynak TTagLes (fiili kart), TTagZei (plan) DEĞİL.
--   Ayrılan sezonluk (3449) çalıştığı günlerde DAHİL — burada soru fiili varlık.
-- Yoğunluk = Encore fiş saati, Kitap içeren perakende fiş (DocType 1 + 6), Sınav/fatura/iade hariç.
-- Hesap: scratchpad Python (blok 12 + 13 sonucu birleştirilir; saat × gün tipi).
--
-- BULGU (ÖLÇÜLDÜ 15.10.2026) — saat başına, Kültür çalışanı başına Kitap adedi
--   Hafta içi   10   12   13   15   16   17   18   19   20   21
--   FSM        8,6 14,0  6,8  9,4 13,6 12,7 15,3 18,5 19,1 16,0
--   İST.YOLU   9,3 14,9  8,2 10,9 14,7 14,7 16,2 19,7 23,3 20,6
--   ÖZLÜCE     8,1 12,7  8,2 10,0 11,7 14,5 13,7 19,7 19,7 13,4
--   Hafta sonu
--   FSM        7,7 27,5 19,4 25,6 24,7 20,7 18,3 21,7 19,3 16,3
--   İST.YOLU   7,9 31,4 24,6 37,6 34,7 33,8 32,2 41,6 36,5 31,5
--   ÖZLÜCE     9,7 18,3 19,7 21,3 21,2 20,2 18,4 23,0 20,4 17,0
--   Desen: personel 13-18 arası en kalabalık (iki vardiya üst üste: FSM 4,5 · İst.Yolu 3,5 ·
--   Özlüce 5,9 kişi hafta içi); satış hafta içi 16-20'de zirve. 19:00'da personel düşüyor
--   (FSM 4,1→3,0 · İst.Yolu 3,4→2,4 · Özlüce 5,4→4,1), satış yüksek kalıyor.
--   Hafta içi en düşük yük 13-14 (kişi başı 6,8-8,2 adet); en yüksek 19-20.
--   Hafta sonu İst.Yolu her saatte diğer iki mağazanın ~1,5-2 katı; 19:00'da 2,5 kişiyle 41,6.
--   SINIR: reyon işi yalnız satış değil (raflama, mal kabul, sayım) — sabah saatlerinin düşük
--   satış/kişi oranı boşta kalma demek değil. Fiş saati kasadaki saattir, rafta geçen süre değil.
--   Heykel'de satış verisi yok (personel profili hesaplandı, yoğunluk yok).
-- =============================================================================


-- ── BLOK 12 (PDKS iç sorgu) — Kültür kişi-gün giriş/çıkış aralığı ──
SELECT p.Per_PersNr, LTRIM(RTRIM(p.Per_Grp2)) AS sube, l.TLe_Datum,
       MIN(l.TLe_VonZeit) AS giris, MAX(l.TLe_BisZeit) AS cikis
FROM TTagLes l JOIN TPerTab p ON p.Per_PersNr = l.TLe_PersNr
WHERE l.TLe_Datum >= '20260915' AND l.TLe_Datum <= '20261014' AND l.TLe_VonZeit IS NOT NULL
  AND p.Per_Grp1 LIKE 'MA%LAR%' AND LTRIM(RTRIM(p.Per_Grp3)) = 'KÜLTÜR'
GROUP BY p.Per_PersNr, p.Per_Grp2, l.TLe_Datum;
-- Ölçüldü: 551 kişi-gün, çıkışsız 0, gece/ters aralık 0.


-- ── BLOK 13 (EncoreMerkez) — saat × gün tipi Kitap fiş ve adet ──
-- StoresId: 1 = İst.Yolu · 2 = FSM · 3 = Özlüce · gun tipi 1 = Cumartesi/Pazar
SELECT s.StoresId,
       CASE WHEN (DATEPART(weekday, s.Date) + @@DATEFIRST - 2) % 7 >= 5 THEN 1 ELSE 0 END AS hafta_sonu,
       DATEPART(hour, s.Date) AS saat,
       COUNT(DISTINCT s.Id) AS kitap_fis,
       SUM(sp.Amount) AS kitap_adet
FROM dbo.Sales s
JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN dbo.Products p ON p.Id = sp.ProductsId
JOIN DerinSISBkm.bkm.UrunBilgi u
  ON u.stkID = CASE WHEN ISNUMERIC(p.Code) = 1 THEN CONVERT(int, p.Code) END
WHERE s.Date >= CONVERT(datetime, '15.09.2026', 104)
  AND s.Date <  CONVERT(datetime, '15.10.2026', 104)
  AND s.DocumentsTypeId IN (1, 6)
  AND u.Kategori3 = N'Kitap'
GROUP BY s.StoresId,
         CASE WHEN (DATEPART(weekday, s.Date) + @@DATEFIRST - 2) % 7 >= 5 THEN 1 ELSE 0 END,
         DATEPART(hour, s.Date);


-- =============================================================================
-- EK 3 — İST.YOLU KÜLTÜR NORM 4 → 5 KARAR DESTEĞİ (15.10.2026)
-- Talep (mağaza): asma kat var; 4 kişi = 1 sabah 1 öğle 1 akşam 1 izinli → iş yetişmiyor,
-- akşam soru soracak personel kalmıyor.
--
-- ÖLÇÜLDÜ
--   Kapsama (blok 12 aralıkları, dakika hassasiyeti; 28.09–14.10 = sezonluk ayrıldıktan sonra):
--     günde gelen kişi: 3 kişi 11/17 gün, 4 kişi 6/17 gün
--     10-13: dakikaların %59'unda ≤1 kişi (FSM %42, Özlüce %4)
--     18-22: %79 tam 2 kişi, %7 ≤1 (FSM 2,6 · Özlüce 3,0 ort kişi)
--   Kat dağılımı (bkm.SUBE_RAF_LISTE Kültür rafları): İst.Yolu Kat 1 2.081 + Kat 2 (asma kat) 611
--     raf → rafların %22'si ayrı katta. FSM Kat 0'da yalnız 109 raf (%5); Özlüce tek kat.
--   Kitap adet yıllık (ERP, 10.2025–09.2026): FSM 159.659 · İst.Yolu 158.463 · Özlüce 231.465
--     → 12 aylık ortalamada İst.Yolu = FSM (norm 5).
--   Geçen yıla göre İst.Yolu: Ağu +%38 · Eyl +%35 · Eki 1-14 +%68 (FSM yatay, Özlüce +%10-17).
--   Kasa teyidi (Encore DocType 1+6, Kitap içeren fiş): İst.Yolu Eyl 5.079→6.595 (+%30),
--     Eki 1-14 2.445→3.923 (+%60). FSM Eyl 7.250→6.835.
--   Artışın kaynağı (Eyl 1–Eki 14, +9.787 adet): ilk 15 ürün ~4.600 adet; çeşit 7.002→9.282.
--     Yeni çıkan romanlar + okul okuma klasikleri (Çalıkuşu, Ateşten Gömlek, Kuyucaklı Yusuf,
--     Beyaz Diş). Yarısı geniş tabanlı, yarısı okul dönemine bağlı olabilir.
--   Maliyet (Zirve vw_PuanBil, Eyl 2026, Kültür, tam gün karşılığı): satış danışmanı
--     50.634 ₺/ay · reyon şefi 89.730 ₺/ay (şirkete toplam maliyet).
--   100 TL Kitap satışında Kültür personeline giden (30 gün, ÇIKARIM: ünvan ortalaması × kişi):
--     İst.Yolu 4 kişi ≈ 4,4 TL · +1 ile ≈ 5,3 TL · FSM ≈ 6,4 TL · Özlüce ≈ 5,7 TL.
-- =============================================================================


-- ── BLOK 14 (DerinSISBkm) — aylık Kitap adet, 12 ay ──
SELECT CONVERT(char(7), h.ehTrhS, 120) AS ay, h.ehMekan, SUM(-h.ehAdetN) AS adet
FROM dbo.irsHrk h JOIN bkm.UrunBilgi u ON u.stkID = h.ehstkID
WHERE h.ehTip IN (100, 101, 4, 5) AND h.ehMekan IN (1, 4477, 4478)
  AND h.ehTrhS >= CONVERT(date, '01.10.2025', 104) AND h.ehTrhS < CONVERT(date, '01.10.2026', 104)
  AND u.Kategori3 = N'Kitap' AND u.KatAna NOT LIKE N'Sınav Okul%'
GROUP BY CONVERT(char(7), h.ehTrhS, 120), h.ehMekan;


-- ── BLOK 15 (EncoreMerkez) — Kitap içeren perakende fiş, Eyl + Eki 1-14, iki yıl ──
SELECT YEAR(s.Date) AS yil, CASE WHEN MONTH(s.Date) = 9 THEN '09' ELSE '10(1-14)' END AS ay,
       s.StoresId, COUNT(DISTINCT s.Id) AS kitap_fis, SUM(sp.Amount) AS adet
FROM dbo.Sales s
JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN dbo.Products p ON p.Id = sp.ProductsId
JOIN DerinSISBkm.bkm.UrunBilgi u
  ON u.stkID = CASE WHEN ISNUMERIC(p.Code) = 1 THEN CONVERT(int, p.Code) END
WHERE ((s.Date >= CONVERT(datetime, '01.09.2025', 104) AND s.Date < CONVERT(datetime, '15.10.2025', 104))
    OR (s.Date >= CONVERT(datetime, '01.09.2026', 104) AND s.Date < CONVERT(datetime, '15.10.2026', 104)))
  AND s.DocumentsTypeId IN (1, 6) AND u.Kategori3 = N'Kitap'
GROUP BY YEAR(s.Date), CASE WHEN MONTH(s.Date) = 9 THEN '09' ELSE '10(1-14)' END, s.StoresId;


-- ── BLOK 16 (BKM_GENEL / Zirve) — Kültür ünvan bazlı aylık maliyet (tam gün karşılığı) ──
SELECT p.Unvan, COUNT(*) AS kisi_ay,
       SUM(b.Primgunu) / 30.0 AS tam_gun,
       SUM(b.Bt + b.Isskk + b.Iisk) / NULLIF(SUM(b.Primgunu) / 30.0, 0) AS aylik_maliyet_tamgun
FROM dbo.vw_PuanBil b
JOIN dbo.vw_PersonelDepartman p ON p.Personelno = b.Personelno
WHERE b.Yil = 2026 AND b.Ayindex = 9 AND p.Lokasyon LIKE 'MA%' AND p.Departman = N'KÜLTÜR'
GROUP BY p.Unvan;


-- ── BLOK 17 (DerinSISBkm) — 12 ay Kitap adet + net ciro (sezondan bağımsız kıyas tabanı) ──
-- Ölçüldü 15.10.2026 (10.2025–09.2026): FSM 159.662 / 39.633.122 · İst.Yolu 158.463 / 40.858.027
--   · Özlüce 231.466 / 59.075.436.  Norm kişi başı ciro: FSM 7,93M · İst.Yolu 10,21M (5 ile 8,17M)
--   · Özlüce 8,44M.  Norm kişi başı adet: 31.932 · 39.616 (5 ile 31.693) · 33.066.
--   +1 satış danışmanı yıllık ≈ 607.608 ₺ = İst.Yolu yıllık Kitap net cirosunun %1,5'i.
SELECT h.ehMekan, SUM(-h.ehAdetN) AS adet,
       SUM(CASE WHEN h.ehTip IN (100, 4) THEN h.ehTutarN ELSE -h.ehTutarN END) AS net_kdv_haric
FROM dbo.irsHrk h JOIN bkm.UrunBilgi u ON u.stkID = h.ehstkID
WHERE h.ehTip IN (100, 101, 4, 5) AND h.ehMekan IN (1, 4477, 4478)
  AND h.ehTrhS >= CONVERT(date, '01.10.2025', 104) AND h.ehTrhS < CONVERT(date, '01.10.2026', 104)
  AND u.Kategori3 = N'Kitap' AND u.KatAna NOT LIKE N'Sınav Okul%'
GROUP BY h.ehMekan;


-- ── BLOK 18 (DerinSISBkm) — İst.Yolu Kitap satışının raf katına dağılımı (asma kat = Kat 2) ──
-- Kat 2 yalnız KÜLTÜR alanı taşır (612 raf) → asma kat. Konum: bkm.SayimRaflari (bugünkü atama)
-- geçmiş satışa uygulanır → ürün yer değiştirdiyse sapma olur (ÇIKARIM sınırı).
-- Ölçüldü 15.10.2026 (Kitap, Sınav ürünü hariç):
--   son 30 gün (15.09–14.10): yalnız asma kat 1.128 adet / 365.275 ₺ (%5,1 adet · %6,4 ciro) ·
--     iki katta 1.012 / 265.773 · yalnız Kat 1 19.595 / 5.022.455 · adressiz/depo 363 / 58.534
--   12 ay (10.2025–09.2026): yalnız asma kat 8.973 adet (%5,7) / 2.589.257 ₺ (%6,3)
--   Kitap stoğu bugün: yalnız asma kat 13.919 çeşit / 25.533 adet (≈%22 çeşit · %18 adet)
--   → asma kat uzun kuyruk: stoğun %18'i, satışın %5-6'sı. 30 günde stok dönüşü asma kat %4,4 · Kat 1 %16,6.
WITH rafkat AS (
    SELECT DISTINCT f.rafAD, k.katAD
    FROM ryn.kat k JOIN ryn.alan a ON a.alanKatID = k.katID
    JOIN ryn.reyon r ON r.reyonAlanID = a.alanID
    JOIN ryn.rafGrp g ON g.rafgrpReyonID = r.reyonID
    JOIN ryn.raf f ON f.rafRafGrpID = g.rafgrpID
    WHERE k.katMekan = 4478
), urunkat AS (
    SELECT s.StokId,
           MAX(CASE WHEN rk.katAD = N'Kat 2' THEN 1 ELSE 0 END) AS k2,
           MAX(CASE WHEN rk.katAD = N'Kat 1' THEN 1 ELSE 0 END) AS k1
    FROM bkm.SayimRaflari s JOIN rafkat rk ON rk.rafAD = s.RafAd
    WHERE s.MekanId = 4478
    GROUP BY s.StokId
), satis AS (
    SELECT h.ehstkID,
           SUM(CASE WHEN h.ehTrhS >= CONVERT(date,'15.09.2026',104) THEN -h.ehAdetN ELSE 0 END) AS adet30,
           SUM(CASE WHEN h.ehTrhS >= CONVERT(date,'15.09.2026',104)
                    THEN CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN ELSE -h.ehTutarN END ELSE 0 END) AS net30,
           SUM(CASE WHEN h.ehTrhS < CONVERT(date,'01.10.2026',104) THEN -h.ehAdetN ELSE 0 END) AS adet12,
           SUM(CASE WHEN h.ehTrhS < CONVERT(date,'01.10.2026',104)
                    THEN CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN ELSE -h.ehTutarN END ELSE 0 END) AS net12
    FROM dbo.irsHrk h JOIN bkm.UrunBilgi u ON u.stkID = h.ehstkID
    WHERE h.ehTip IN (100,101,4,5) AND h.ehMekan = 4478
      AND h.ehTrhS >= CONVERT(date,'01.10.2025',104) AND h.ehTrhS < CONVERT(date,'15.10.2026',104)
      AND u.Kategori3 = N'Kitap' AND u.KatAna NOT LIKE N'Sınav Okul%'
    GROUP BY h.ehstkID
)
SELECT CASE WHEN uk.StokId IS NULL THEN '4 adressiz/depo'
            WHEN uk.k2 = 1 AND uk.k1 = 0 THEN '1 yalniz asma kat'
            WHEN uk.k2 = 1 AND uk.k1 = 1 THEN '2 iki katta'
            WHEN uk.k1 = 1 THEN '3 yalniz Kat 1'
            ELSE '4 adressiz/depo' END AS sinif,
       COUNT(*) AS satilan_cesit,
       SUM(s.adet30) AS adet30, CAST(SUM(s.net30) AS bigint) AS net30,
       SUM(s.adet12) AS adet12, CAST(SUM(s.net12) AS bigint) AS net12
FROM satis s LEFT JOIN urunkat uk ON uk.StokId = s.ehstkID
GROUP BY CASE WHEN uk.StokId IS NULL THEN '4 adressiz/depo'
            WHEN uk.k2 = 1 AND uk.k1 = 0 THEN '1 yalniz asma kat'
            WHEN uk.k2 = 1 AND uk.k1 = 1 THEN '2 iki katta'
            WHEN uk.k1 = 1 THEN '3 yalniz Kat 1'
            ELSE '4 adressiz/depo' END
ORDER BY 1
;


-- ── BLOK 19 (DerinSISBkm) — İst.Yolu operasyon işi (raflama + sayım) kata göre ──
-- Raflama = bkm.SayimLog Tip 6 (RafNo dolu). Sayım = SayimEmirDetaylari satırı (iptal hariç).
-- RafNo → (rafAD) → ryn kat/alan. Ölçüldü 15.10.2026, pencere 01.10.2025–14.10.2026:
--   Kültür raflama: Kat 1 138.436 · Kat 2 (asma) 29.310 · Depo 4.117 → asma kat %17,1
--     son 30 gün: Kat 1 3.466 · asma 1.999 · Depo 1.029 → asma kat %30,8
--   Kültür sayım satırı: Kat 1 1.564 · asma 302 · Depo 112 → asma kat %15,3 (son 30 gün %21)
--   Karşılaştır: asma kat Kitap satışının %5-6'sı (blok 18).
WITH rafkat AS (
    SELECT f.rafAD, MIN(k.katAD) AS katAD, MIN(a.alanAD) AS alanAD
    FROM ryn.kat k JOIN ryn.alan a ON a.alanKatID = k.katID
    JOIN ryn.reyon r ON r.reyonAlanID = a.alanID
    JOIN ryn.rafGrp g ON g.rafgrpReyonID = r.reyonID
    JOIN ryn.raf f ON f.rafRafGrpID = g.rafgrpID
    WHERE k.katMekan = 4478
    GROUP BY f.rafAD
), ops AS (
    SELECT 'raflama' AS is_tipi, l.RafNo, l.LogDate AS t, 1 AS satir
    FROM bkm.SayimLog l
    WHERE l.MekanId = 4478 AND l.Tip = 6
      AND l.LogDate >= CONVERT(datetime,'01.10.2025',104) AND l.LogDate < CONVERT(datetime,'15.10.2026',104)
    UNION ALL
    SELECT 'sayim', d.RafNo, d.OlusturmaTarihi, 1
    FROM bkm.SayimEmirDetaylari d
    JOIN bkm.SayimEmirTanimlari e ON e.SayimEmirBaslikId = d.SayimEmirBaslikId AND e.RafNo = d.RafNo AND e.StokId = d.StokId
    WHERE ISNULL(d.Iptal,0) = 0
      AND d.OlusturmaTarihi >= CONVERT(datetime,'01.10.2025',104) AND d.OlusturmaTarihi < CONVERT(datetime,'15.10.2026',104)
      AND EXISTS (SELECT 1 FROM rafkat x WHERE x.rafAD = d.RafNo)
)
SELECT o.is_tipi,
       CASE WHEN o.t >= CONVERT(datetime,'15.09.2026',104) THEN 'son30' ELSE 'once' END AS donem,
       ISNULL(rk.katAD, '(eslesmedi)') AS kat, ISNULL(rk.alanAD, '') AS alan,
       COUNT(*) AS satir
FROM ops o LEFT JOIN rafkat rk ON rk.rafAD = o.RafNo
GROUP BY o.is_tipi, CASE WHEN o.t >= CONVERT(datetime,'15.09.2026',104) THEN 'son30' ELSE 'once' END,
         ISNULL(rk.katAD, '(eslesmedi)'), ISNULL(rk.alanAD, '')
ORDER BY 1, 2, 3, 4
;

-- ── BLOK 20 (DerinSISBkm) — Kültür raflama, üç mağaza ──
-- Ölçüldü: 12 ay (10.2025–09.2026) FSM 163.886 · Özlüce 104.820 · İst.Yolu 168.204
--   norm kişi başı: FSM 32.777 · Özlüce 14.974 · İst.Yolu 42.051 (5 ile 33.641)
--   son 30 gün: FSM 3.482 · Özlüce 1.053 · İst.Yolu 6.494
--   SINIR: satır = ürün yerleştirme olayı, harcanan süre değil.
WITH rafkat AS (
    SELECT k.katMekan AS mekan, f.rafAD, MIN(a.alanAD) AS alanAD
    FROM ryn.kat k JOIN ryn.alan a ON a.alanKatID = k.katID
    JOIN ryn.reyon r ON r.reyonAlanID = a.alanID
    JOIN ryn.rafGrp g ON g.rafgrpReyonID = r.reyonID
    JOIN ryn.raf f ON f.rafRafGrpID = g.rafgrpID
    GROUP BY k.katMekan, f.rafAD
)
SELECT l.MekanId,
       SUM(CASE WHEN l.LogDate < CONVERT(datetime,'01.10.2026',104) THEN 1 ELSE 0 END) AS raflama_12ay,
       SUM(CASE WHEN l.LogDate >= CONVERT(datetime,'15.09.2026',104) THEN 1 ELSE 0 END) AS raflama_son30
FROM bkm.SayimLog l
JOIN rafkat rk ON rk.mekan = l.MekanId AND rk.rafAD = l.RafNo AND rk.alanAD = N'KÜLTÜR'
WHERE l.Tip = 6 AND l.MekanId IN (1, 4477, 4478)
  AND l.LogDate >= CONVERT(datetime,'01.10.2025',104) AND l.LogDate < CONVERT(datetime,'15.10.2026',104)
GROUP BY l.MekanId
;


-- ── BLOK 21 (EncoreMerkez) — DÜZELTME: 12 ay Kitap, SINAV BELGESİ HARİÇ, tek kaynak kasa ──
-- GMY sordu: "sınav belgelerini rapora dahil etmedin değil mi". Blok 17 (ERP) YALNIZ ürün-bazlı
-- Sınav süzgeci taşıyordu; Sınav Okulları BELGESİYLE (DocType 8) satılan Kitap içerideydi.
-- Ölçüldü 15.10.2026 (10.2025–09.2026): DocType 8 Kitap yalnız İst.Yolu → 4.624 adet / 1.207.065 ₺.
-- Ayrıca İst.Yolu'nda ERP − kasa farkı 5.389 adet (FSM 1.114 · Özlüce 1.778) → ERP'de belge
-- ayrımı yapılamadığı için slayt tabanı KASAYA alındı (DocType 1,2,3(−),6,7; 8 HARİÇ):
--   FSM 158.548 adet / 39.411.433 ₺ · İst.Yolu 148.450 / 38.542.352 · Özlüce 229.688 / 58.774.012
--   norm kişi başı ciro: FSM 7,88M · Özlüce 8,40M · İst.Yolu 9,64M (5 ile 7,71M)
--   norm kişi başı adet: 31.710 · 32.813 · 37.112 (5 ile 29.690)
--   İst.Yolu / FSM: ciro %97,8 · adet %93,6 (blok 17'deki "FSM'den fazla" ifadesi GEÇERSİZ).
--   +1 kişi maliyeti / İst.Yolu Kitap satışı = %1,58.
-- StoresId: 1 = İst.Yolu · 2 = FSM · 3 = Özlüce
SELECT s.StoresId, s.DocumentsTypeId,
       SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -sp.Amount ELSE sp.Amount END) AS adet,
       SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(sp.TotalPrice - sp.VatTotal)
                ELSE sp.TotalPrice - sp.VatTotal END) AS net_kdv_haric
FROM dbo.Sales s
JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN dbo.Products p ON p.Id = sp.ProductsId
JOIN DerinSISBkm.bkm.UrunBilgi u
  ON u.stkID = CASE WHEN ISNUMERIC(p.Code) = 1 THEN CONVERT(int, p.Code) END
WHERE s.Date >= CONVERT(datetime, '01.10.2025', 104)
  AND s.Date <  CONVERT(datetime, '01.10.2026', 104)
  AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND u.Kategori3 = N'Kitap' AND u.KatAna NOT LIKE N'Sınav Okul%'
GROUP BY s.StoresId, s.DocumentsTypeId
ORDER BY 1, 2;
