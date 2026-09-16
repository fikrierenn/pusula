/* ============================================================================
   VARDİYA YÖNET — "PDKS PROGRAM RAPORU" KURAL TÜRETİMİ + YENİDEN ÜRETİM
   DB     : DerinSISBkm (BKM.vrd.*) + OPENQUERY([PDKS]) → wtimserv (GecoTime)
   Soru   : "Vardiya Yonet → Pdks Aktar → Excel Aktar" çıktısı SQL'den birebir
            üretilebilir mi? Türetme kuralları (giriş toleransı, mola, durum) ne?
   Kaynak : Fsm Kisi Tarih Birlestirme Formulleri Standart cc.xlsx
            sayfa "Vardiya Yönet Program Raporu" (FSM, 31.08–13.09.2026, 595 satır)
   Sonuç  : ÜRETİLDİ. 595 satır × 9 kolon karşılaştırıldı → 0 fark.
            Üretici: scripts/vardiya_pdks_program_raporu.py
   Tarih  : 2026-09-15
   ⚠ MCP sql_query CTE'yi auto-TOP wrap ile bozar → bu dosya SSMS içindir.
   ⚠ OPENQUERY tarih literali ISO 'YYYYMMDD' (linked server kuralı).
============================================================================ */

/* ---------------------------------------------------------------------------
   TÜRETİLEN KURALLAR (Excel'in 595 satırı üzerinde ölçüldü, tahmin DEĞİL)

   1) Personel Giriş = plana 10 dk TOLERANS, ÇİFT YÖNLÜ
          giris = plan + sign(kart-plan) * MAX(0, ABS(kart-plan) - 10)
      Erken gelen plandan önce sayılmaz; geç gelenin ilk 10 dk'sı affedilir.
      521/521 satır tuttu. İzin gününde plan = 0 alınır (kart - 10).
      Karşı kanıt: tolerans 10 → 5 yapılınca 760 hücre farkı (kapı gerçek).

   2) Personel Çıkış = HAM PDKS çıkışı. Tolerans YOK (521/521).

   3) Personel Çalışma = (çıkış - giriş) - mola; mola ARAÇ tablosu:
          brüt >= 7:30 → 60 dk · 4:30..7:29 → 45 dk · 2:30..4:29 → 15 dk · altı 0
      Sınır ölçüldü: brüt 447 dk → 45 · 454 dk → 60.
      ⚠ Excel'in "Mola Saatleri" sayfası FARKLI eşik kullanır (brüt 8:30 → 60).
        Fark 7:30–8:30 bandında 15 dk'dır ve KASITLIDIR: M kolonu aracın molası,
        Z kolonu Excel'in molası. İki ayrı ölçüdür, biri diğerinin kontrolü değil.
      ⚠ 45 dk bandının ALT sınırı (2:30–4:29) veride gözlenmedi → ÇIKARIM.

   4) Durum — HAM PDKS saatiyle karar verilir, TOLERANSLI saatle DEĞİL (595/595):
          izin & okutma var → "İzin Günü Çalışılmış"
          izin & okutma yok → "İzinli"
          okutma yok        → "Devamsız"
          kartGiriş > planBaşlama VEYA kartÇıkış < planBitiş
                            → "Geç girilmiş ve/veya erken çıkılmış"
          aksi              → "Normal Çalışma"
      ⚠ Tolerans kuralıyla karar verilirse 92 satır yanlış sınıflanır (ölçüldü):
        kart 1 dk geç basılmış ama toleransla plana çekilmiş satırlar "Normal"
        görünür. Araç bunları geç sayar.

   5) "PDKS Giriş Fark" = planBaşlama - kartGiriş (erken geliş dk)
      "PDKS Çıkış Fark" = kartÇıkış - planBitiş
      (bunlar "Vardiya Yönet Raporu" sayfasında var, "Program Raporu"nda yok)
--------------------------------------------------------------------------- */

-- ═══════════════════════════════════════════════════════════════════════════
-- BLOK 1 — RAPORUN ANA GÖVDESİ (plan × fiili, kişi-gün)
-- Geniş biçim (Pazartesi..Pazar ayrı int kolon) CROSS APPLY ile UNPIVOT edilir.
-- VardiyaId = 0 → o gün vardiya atanmamış (SIFIR SENTİNEL, NULL DEĞİL).
-- ═══════════════════════════════════════════════════════════════════════════
DECLARE @Sube varchar(50) = 'FSM';
DECLARE @Bas  date = CONVERT(date, '31.08.2026', 104);
DECLARE @Bit  date = CONVERT(date, '13.09.2026', 104);

WITH plan_gun AS (
    SELECT  s.SubeAd,
            LTRIM(RTRIM(vd.SicilNo))                    AS TC,
            vd.Personel, vd.Bolum, vd.Gorev,
            CONVERT(date, DATEADD(day, g.ofs, v.Tarih)) AS Tarih,
            vz.Aciklama                                 AS VardiyaTanim,
            vz.Baslama, vz.Bitis, vz.ToplamCalismaDk, vz.Izin
    FROM        BKM.vrd.Vardiya       v
    INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo     = v.SubeNo
    INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
    CROSS APPLY (VALUES (0, vd.Pazartesi), (1, vd.Sali), (2, vd.Carsamba),
                        (3, vd.Persembe),  (4, vd.Cuma), (5, vd.Cumartesi),
                        (6, vd.Pazar)) AS g(ofs, VardiyaId)
    LEFT  JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
    WHERE   s.SubeAd = @Sube
        AND g.VardiyaId <> 0                       -- sıfır sentinel
        AND DATEADD(day, g.ofs, v.Tarih) BETWEEN @Bas AND @Bit
),
fiili AS (      -- PDKS günlük özet; TLe_BeginnKz = 0 → günün ilk satırı
    SELECT  x.TC COLLATE Turkish_CI_AS AS TC, x.Gun, x.Giris, x.Cikis, x.KayitSayisi
    FROM OPENQUERY([PDKS], '
        SELECT  i.PIn_SteuerNr                     AS TC,
                CONVERT(char(8), l.TLe_Datum, 112) AS Gun,
                MIN(l.TLe_VonZeit)                 AS Giris,
                MAX(l.TLe_BisZeit)                 AS Cikis,
                COUNT(*)                           AS KayitSayisi
        FROM        TPerInd i
        INNER JOIN  TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
        WHERE   l.TLe_Datum >= ''20260831'' AND l.TLe_Datum <= ''20260913''
            AND l.TLe_BeginnKz = 0 AND i.PIn_SteuerNr <> ''''
        GROUP BY i.PIn_SteuerNr, CONVERT(char(8), l.TLe_Datum, 112)
    ') x
)
SELECT  p.SubeAd, p.TC, p.Personel, p.Bolum, p.Gorev,
        CONVERT(varchar(10), p.Tarih, 104)        AS Tarih,
        p.VardiyaTanim,
        CONVERT(varchar(5), f.Giris, 108)         AS PdksGiris,
        CONVERT(varchar(5), f.Cikis, 108)         AS PdksCikis,
        p.ToplamCalismaDk                         AS PlanDk,
        CASE
            WHEN p.Izin = 1 AND f.Giris IS NOT NULL THEN 'İzin Günü Çalışılmış'
            WHEN p.Izin = 1                         THEN 'İzinli'
            WHEN f.Giris IS NULL                    THEN 'Devamsız'
            WHEN DATEDIFF(minute, 0, CONVERT(time, f.Giris))
                 > DATEDIFF(minute, 0, CONVERT(time, p.Baslama))
              OR DATEDIFF(minute, 0, CONVERT(time, f.Cikis))
                 < DATEDIFF(minute, 0, CONVERT(time, p.Bitis))
                                                    THEN 'Geç girilmiş ve/veya erken çıkılmış'
            ELSE 'Normal Çalışma'
        END                                       AS Durum
FROM        plan_gun p
LEFT  JOIN  fiili    f ON f.TC = p.TC COLLATE Turkish_CI_AS
                      AND f.Gun = CONVERT(char(8), p.Tarih, 112)
ORDER BY p.Tarih, p.Personel;


/* ############################################################################
   ANALİZ İZİ — kuralları çıkarırken koşulan keşif sorguları (nasıl bulduk)
############################################################################ */

-- ── K1. Haftalık plan başlıkları: kaç şube, kaçı kesinleşmiş ──────────────
--    Bulgu: her hafta 9 başlık = 9 şube. 14.09.2026'da 9'un 7'si Kesin=1.
SELECT TOP 12 CONVERT(varchar(10), v.Tarih, 104) AS Hafta,
       COUNT(*) AS PlanBaslik,
       SUM(CASE WHEN v.Kesin = 1 THEN 1 ELSE 0 END) AS Kesin,
       COUNT(DISTINCT v.SubeNo) AS Sube
FROM BKM.vrd.Vardiya v GROUP BY v.Tarih ORDER BY v.Tarih DESC;

-- ── K2. Ekrandaki şube listesi ile vrd.SubeListe birebir mi? ──────────────
--    Bulgu: 9 şube, ekranla birebir. 14.09 haftası 354 kişi-satır, TC %100 dolu.
SELECT s.SubeNo, s.SubeAd, COUNT(vd.SicilNo) AS KisiSatir,
       SUM(CASE WHEN LEN(LTRIM(RTRIM(vd.SicilNo))) = 11 THEN 1 ELSE 0 END) AS TcDolu
FROM BKM.vrd.Vardiya v
JOIN BKM.vrd.SubeListe s ON s.SubeNo = v.SubeNo
LEFT JOIN BKM.vrd.VardiyaDetay vd ON vd.VardiyaNo = v.VardiyaNo
WHERE v.Tarih = CONVERT(datetime, '14.09.2026', 104)
GROUP BY s.SubeNo, s.SubeAd ORDER BY s.SubeNo;

-- ── K3. TC köprüsünün GÜNCEL eşleşme oranı ────────────────────────────────
--    Bulgu: 14.09 haftası 338/354 = %95,5.
--    ⚠ sema'daki "%14,81 öksüz" TÜM GEÇMİŞ içindir (16.735 satır, ayrılmış
--      personel dahil). İkisi çelişmiyor — KAPSAMLARI farklı.
SELECT COUNT(*) AS PlanKisi,
       SUM(CASE WHEN p.TC IS NOT NULL THEN 1 ELSE 0 END) AS PdksEslesen
FROM BKM.vrd.Vardiya v
JOIN BKM.vrd.VardiyaDetay vd ON vd.VardiyaNo = v.VardiyaNo
LEFT JOIN (SELECT DISTINCT PIn_SteuerNr AS TC
           FROM OPENQUERY([PDKS], 'SELECT PIn_SteuerNr FROM TPerInd
                                   WHERE PIn_SteuerNr IS NOT NULL
                                     AND PIn_SteuerNr <> ''''')) p
       ON p.TC COLLATE Turkish_CI_AS = vd.SicilNo COLLATE Turkish_CI_AS
WHERE v.Tarih = CONVERT(datetime, '14.09.2026', 104);

-- ── K4. MÜKERRER TC — hangi PersNr doğru? ─────────────────────────────────
--    Bulgu: 11 TC iki kayıt taşıyor. 11'inin 11'inde tam BİRİ Per_ZeitAktiv=1
--    ve dönem içi kart okumaları DA onda. ⇒ MIN/MAX sıralaması değil,
--    AKTİFLİK süzgeci kullanılır. (MAX tesadüfen aynı sonucu verirdi — gerekçe
--    farklı olurdu; "kopyalanan desende gerekçe de kopyalanmaz".)
SELECT * FROM OPENQUERY([PDKS], '
    SELECT i.PIn_SteuerNr AS TC, i.PIn_PersNr AS PersNr,
           p.Per_Name, p.Per_Vorname, p.Per_ZeitAktiv AS Aktif,
           (SELECT COUNT(*) FROM TTagLes l
             WHERE l.TLe_PersNr = i.PIn_PersNr AND l.TLe_Datum >= ''20260801'') AS Okuma
    FROM TPerInd i LEFT JOIN TPerTab p ON p.Per_PersNr = i.PIn_PersNr
    WHERE i.PIn_SteuerNr IN (SELECT PIn_SteuerNr FROM TPerInd
                              WHERE PIn_SteuerNr <> ''''
                              GROUP BY PIn_SteuerNr HAVING COUNT(*) > 1)
') x;

-- ── K5. ŞUBE ↔ PDKS GRUP EŞLEMESİ — Per_Grp2 TEK BAŞINA YETMEZ ────────────
--    Bulgu: "FSM" hem FSM mağazanın hem FSM KAFE'nin Per_Grp2'sidir; ayıran
--    Per_Grp1 (MAĞAZALAR / KAFELER). Aynı durum İST.YOLU ve ÖZLÜCE'de de var.
--    ⇒ Per_Grp2 ile tek başına şube süzen sorgu KAFE personelini mağazaya yazar.
SELECT * FROM OPENQUERY([PDKS],
    'SELECT SubeNo, SubeAd, Per_Grp0, Per_Grp1, Per_Grp2 FROM bkm.SubeListe') x
ORDER BY x.SubeNo;

-- ── K6. ARACIN ATTIĞI KİŞİLER — neden 644 plan satırı, 595 rapor satırı? ──
--    Bulgu: araç Per_ZeitAktiv=0 (işten ayrılmış) personeli TAMAMEN atıyor,
--    kart basmış olsa bile. FSM'de 5 kişi:
--      NECMETTİN ÇELİK / RESUL ÇİL  → Aktif=0, dönemde 0 okuma  (atılması doğru)
--      FURKAN DEMİR                 → Aktif=0, 1 okuma
--      MERT SARGIN                  → Aktif=0, 12 okuma  ⚠ ÇALIŞMIŞ ama raporda YOK
--      İHSAN KARATAŞ                → Aktif=1, 5 okuma, planı 14.09'da başlıyor
--                                     ⇒ kart basmış ama plansız → raporda YOK
--    GMY kararı (15.09.2026): "kart bastıysa vardiya tanımı olmasa bile gelmeli."
--    ⇒ Üretici kural: pasif personel YALNIZ kart okutması olmayan günde düşer.
SELECT * FROM OPENQUERY([PDKS], '
    SELECT LTRIM(RTRIM(p.Per_Vorname)) + '' '' + LTRIM(RTRIM(p.Per_Name)) AS Ad,
           p.Per_PersNr, p.Per_ZeitAktiv AS Aktif,
           LTRIM(RTRIM(p.Per_Grp1)) AS Grp1, LTRIM(RTRIM(p.Per_Grp2)) AS Grp2,
           i.PIn_SteuerNr AS TC,
           (SELECT COUNT(*) FROM TTagLes l
             WHERE l.TLe_PersNr = p.Per_PersNr
               AND l.TLe_Datum BETWEEN ''20260831'' AND ''20260913'') AS Okuma
    FROM TPerTab p LEFT JOIN TPerInd i ON i.PIn_PersNr = p.Per_PersNr
    WHERE LTRIM(RTRIM(p.Per_Grp1)) = ''MAĞAZALAR''
      AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
') x
WHERE x.Aktif = 0 AND x.Okuma > 0;    -- ayrılmış ama çalışmış

-- ── K7. İZİN KODLARI (vrd.VardiyaZaman.Izin = 1) ──────────────────────────
--    51 HFT.İZİN · 52 ÜCRETSİZ İZİN · 53 ÜCRTLİ İZİN · 55 RESMİ TATİL
--    58 YILLIK İZİN · 63 RAPOR · 73 MESAİ İZNİ      (62 GÜVENLİK → Izin=0)
SELECT vz.VardiyaId, vz.Aciklama, vz.Izin, vz.Aktif
FROM BKM.vrd.VardiyaZaman vz
WHERE vz.Izin = 1 OR vz.VardiyaId IN (51,52,53,55,58,62,63,73)
ORDER BY vz.VardiyaId;
