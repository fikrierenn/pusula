/* ============================================================================
   bkm.sp_Vrd_KisiGunDoldur — kişi-gün tabanının T-SQL karşılığı (plan 47, Faz 1)
   Hedef : DEV → BkmPanel @ BT-FIKRI\SQLEXPRESS. PROD'a yazma YOK.

   Kurallar `scripts/vardiya_pdks_program_raporu.py` çekirdeğinden BİREBİR
   taşındı; hiçbiri burada YENİDEN İCAT EDİLMEDİ. Kapı: SP çıktısı ile Python
   çıktısı kişi-gün bazında karşılaştırılır, **fark 0 çıkmadan Python emekli
   edilmez** (iki uygulama sessizce ayrışmasın diye).

   ERİŞİM (ölçüldü 17.09.2026): yerelde `LIVE201 → 192.168.40.201` linked server
   var ve ÇİFT ATLAMA çalışıyor —
       OPENQUERY(LIVE201, '… OPENQUERY([PDKS], ''…'') …')
   Tırnak katmanı üç seviye olduğu için sorgular DEĞİŞKENDE kurulur ve her
   katmanda `REPLACE(x, '''', '''''')` ile kaçırılır; elle tırnak sayma YAPILMAZ.

   ⚠ SÜRELER DAKİKA. Gece mesaisinde çıkış ertesi güne sarkar (>1440) ve `time`
     tipi bunu tutamaz.
   ============================================================================ */

CREATE OR ALTER PROCEDURE bkm.sp_Vrd_KisiGunDoldur
    @Bas      date,
    @Bit      date,
    @SayimBas date = NULL,        -- NULL → @Bas
    @Konus    bit  = 1            -- 1 → ekrana özet yaz
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @SayimBas IS NULL SET @SayimBas = @Bas;
    IF @SayimBas < @Bas
        THROW 50001, 'KOSAMADI: @SayimBas, @Bas''tan once olamaz.', 1;

    DECLARE @bas8 char(8) = CONVERT(char(8), @Bas, 112),
            @bit8 char(8) = CONVERT(char(8), @Bit, 112);
    DECLARE @l2 nvarchar(max), @l1 nvarchar(max), @sql nvarchar(max);
    DECLARE @TOLERANS int = 10;   -- dk, ÇİFT YÖNLÜ (ölçüldü 521/521)

    -- =====================================================================
    -- 1) VARDİYA PLANI — 201 üstünde, PDKS'e inmeden
    --    `Tarih` haftanın PAZARTESİ'sidir; gün ofseti CROSS APPLY ile açılır.
    --    VardiyaId = 0 → o gün vardiya atanmamış (SIFIR SENTİNEL, NULL değil).
    -- =====================================================================
    CREATE TABLE #plan (
        SubeAd nvarchar(50), SicilNo varchar(11), Personel nvarchar(120),
        Bolum nvarchar(80), Gorev nvarchar(120), Tarih date,
        VardiyaTanim nvarchar(60), Baslama time(0), Bitis time(0),
        ToplamCalismaDk int, Izin bit);

    SET @l1 = N'
        SELECT  s.SubeAd,
                LTRIM(RTRIM(vd.SicilNo)) AS SicilNo,
                vd.Personel, vd.Bolum, vd.Gorev,
                CONVERT(date, DATEADD(day, g.ofs, v.Tarih)) AS Tarih,
                vz.Aciklama AS VardiyaTanim, vz.Baslama, vz.Bitis,
                vz.ToplamCalismaDk, vz.Izin
        FROM        BKM.vrd.Vardiya       v
        INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo    = v.SubeNo
        INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
        CROSS APPLY (VALUES (0, vd.Pazartesi), (1, vd.Sali), (2, vd.Carsamba),
                            (3, vd.Persembe), (4, vd.Cuma), (5, vd.Cumartesi),
                            (6, vd.Pazar)) AS g(ofs, VardiyaId)
        LEFT  JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
        WHERE   g.VardiyaId <> 0
            AND DATEADD(day, g.ofs, v.Tarih) >= ''' + @bas8 + '''
            AND DATEADD(day, g.ofs, v.Tarih) <= ''' + @bit8 + '''';

    SET @sql = N'INSERT INTO #plan SELECT * FROM OPENQUERY(LIVE201, '''
             + REPLACE(@l1, '''', '''''') + ''') p';
    EXEC sp_executesql @sql;

    IF NOT EXISTS (SELECT 1 FROM #plan)
        THROW 50002, 'KOSAMADI: plan satiri YOK. Bos nufus "ihlal yok" demek degildir.', 1;

    -- =====================================================================
    -- 2) TC → PersNr  (PDKS, çift atlama)
    --    ⚠ MÜKERRER TC: 11 TC iki PersNr taşıyor (yeniden işe giriş). Doğru
    --      kayıt ÖLÇÜLDÜ: 11'inin 11'inde tam biri `Per_ZeitAktiv = 1` ve kart
    --      okumaları onda. MIN/MAX tahmini DEĞİL, bu süzgeç kullanılır.
    --    ⚠ `Per_ZeitAktiv` "personel aktif mi" DEĞİL, "PDKS zaman takibi açık
    --      mı" demektir — müdürlerde 0'dır ve onlar çalışmaktadır.
    -- =====================================================================
    CREATE TABLE #tc (TC varchar(11) COLLATE Turkish_CI_AS, PersNr int, Aktif int);

    SET @l2 = N'
        SELECT i.PIn_SteuerNr AS TC, i.PIn_PersNr AS PersNr,
               ISNULL(p.Per_ZeitAktiv, 0) AS Aktif
        FROM TPerInd i LEFT JOIN TPerTab p ON p.Per_PersNr = i.PIn_PersNr
        WHERE i.PIn_SteuerNr <> ''''';
    SET @l1 = N'SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.PersNr, x.Aktif
                FROM OPENQUERY([PDKS], ''' + REPLACE(@l2, '''', '''''') + ''') x';
    SET @sql = N'INSERT INTO #tc SELECT * FROM OPENQUERY(LIVE201, '''
             + REPLACE(@l1, '''', '''''') + ''') y';
    EXEC sp_executesql @sql;

    CREATE TABLE #tcTek (TC varchar(11) COLLATE Turkish_CI_AS PRIMARY KEY, PersNr int);
    INSERT INTO #tcTek (TC, PersNr)
    SELECT TC, PersNr FROM (
        SELECT TC, PersNr,
               ROW_NUMBER() OVER (PARTITION BY TC ORDER BY Aktif DESC, PersNr DESC) rn
        FROM #tc) t WHERE rn = 1;

    -- =====================================================================
    -- 3) PDKS GÜNLÜK ÖZET — TLe_BeginnKz = 0 (günün ilk satırı / gün özeti)
    -- =====================================================================
    CREATE TABLE #pdks (
        TC varchar(11) COLLATE Turkish_CI_AS, Gun char(8),
        Giris datetime NULL, Cikis datetime NULL,
        KayitSayisi int, Mazeret nvarchar(40) NULL);

    SET @l2 = N'
        SELECT  i.PIn_SteuerNr AS TC, CONVERT(char(8), l.TLe_Datum, 112) AS Gun,
                MIN(l.TLe_VonZeit) AS Giris, MAX(l.TLe_BisZeit) AS Cikis,
                COUNT(*) AS KayitSayisi, MIN(l.TLe_AbwArt) AS Mazeret
        FROM        TPerInd i
        INNER JOIN  TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
        WHERE   l.TLe_Datum >= ''' + @bas8 + ''' AND l.TLe_Datum <= ''' + @bit8 + '''
            AND l.TLe_BeginnKz = 0 AND i.PIn_SteuerNr <> ''''
        GROUP BY i.PIn_SteuerNr, CONVERT(char(8), l.TLe_Datum, 112)';
    SET @l1 = N'SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.Gun, x.Giris, x.Cikis,
                       x.KayitSayisi, x.Mazeret
                FROM OPENQUERY([PDKS], ''' + REPLACE(@l2, '''', '''''') + ''') x';
    SET @sql = N'INSERT INTO #pdks SELECT * FROM OPENQUERY(LIVE201, '''
             + REPLACE(@l1, '''', '''''') + ''') y';
    EXEC sp_executesql @sql;

    IF NOT EXISTS (SELECT 1 FROM #pdks)
        THROW 50003, 'KOSAMADI: PDKS tarafi BOS dondu -- okuma gercekten yok mu, yoksa linked server mi dustu?', 1;

    -- =====================================================================
    -- 4) HAM OKUTMA (TZeiBuf) — "Devamsız" etiketini DENETLEMEK için.
    --    `TTagLes` giriş+çıkış ÇİFTİ ister; tek okutma yapan kişide satır
    --    OLUŞMAZ ve rapor "Devamsız" der. Ham okutmada görünür.
    -- =====================================================================
    CREATE TABLE #ham (TC varchar(11) COLLATE Turkish_CI_AS, Gun char(8), Okutma int);

    SET @l2 = N'
        SELECT  i.PIn_SteuerNr AS TC, CONVERT(char(8), b.ZBu_ErfDatum, 112) AS Gun,
                COUNT(*) AS Okutma
        FROM        TZeiBuf b
        INNER JOIN  TPerInd i ON i.PIn_PersNr = b.ZBu_PersNr
        WHERE   b.ZBu_ErfDatum >= ''' + @bas8 + ''' AND b.ZBu_ErfDatum <= ''' + @bit8 + '''
            AND ISNULL(b.ZBu_Storniert, 0) = 0 AND i.PIn_SteuerNr <> ''''
        GROUP BY i.PIn_SteuerNr, CONVERT(char(8), b.ZBu_ErfDatum, 112)';
    SET @l1 = N'SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.Gun, x.Okutma
                FROM OPENQUERY([PDKS], ''' + REPLACE(@l2, '''', '''''') + ''') x';
    SET @sql = N'INSERT INTO #ham SELECT * FROM OPENQUERY(LIVE201, '''
             + REPLACE(@l1, '''', '''''') + ''') y';
    EXEC sp_executesql @sql;

    -- =====================================================================
    -- 5) PLANSIZ AMA KART BASAN — kapsam PDKS tarafından çizilir (Per_Grp1 +
    --    Per_Grp2), plandan DEĞİL. Hafta içinde işe giren plana işlenmemiş
    --    olabilir; kart bastıysa raporda GÖRÜNMELİ (kullanıcı isteği 15.09).
    --    ⚠ Per_Grp2 TEK BAŞINA YETMEZ: "FSM" hem mağazanın hem FSM KAFE'nin
    --      Per_Grp2'si; ayıran Per_Grp1 (MAĞAZALAR / KAFELER).
    --    Python şube şube döngüyle çekiyor; burada TEK GEÇİŞTE çekilip yerelde
    --    eşleniyor — sonuç aynı, tur sayısı 9 yerine 2.
    -- =====================================================================
    CREATE TABLE #subeGrp (SubeAd nvarchar(50) COLLATE Turkish_CI_AS,
                           G1 nvarchar(60) COLLATE Turkish_CI_AS,
                           G2 nvarchar(60) COLLATE Turkish_CI_AS);
    SET @l2 = N'SELECT SubeAd, Per_Grp1, Per_Grp2 FROM bkm.SubeListe WHERE Per_Grp2 IS NOT NULL';
    -- ⚠ COLLATE uygulanan her ifadeye TAKMA AD şart; adsız kolon `INSERT … SELECT`
    --   içinde "An object or column name is missing or empty" ile patlar (ölçüldü).
    SET @l1 = N'SELECT SubeAd = x.SubeAd COLLATE Turkish_CI_AS,
                       G1 = LTRIM(RTRIM(x.Per_Grp1)) COLLATE Turkish_CI_AS,
                       G2 = LTRIM(RTRIM(x.Per_Grp2)) COLLATE Turkish_CI_AS
                FROM OPENQUERY([PDKS], ''' + REPLACE(@l2, '''', '''''') + ''') x';
    SET @sql = N'INSERT INTO #subeGrp SELECT * FROM OPENQUERY(LIVE201, '''
             + REPLACE(@l1, '''', '''''') + ''') y';
    EXEC sp_executesql @sql;

    CREATE TABLE #pdksGrp (
        TC varchar(11) COLLATE Turkish_CI_AS, PersNr int, Ad nvarchar(120),
        G1 nvarchar(60) COLLATE Turkish_CI_AS, G2 nvarchar(60) COLLATE Turkish_CI_AS,
        Gun char(8), Giris datetime NULL, Cikis datetime NULL,
        KayitSayisi int, Mazeret nvarchar(40) NULL);

    SET @l2 = N'
        SELECT  ISNULL(i.PIn_SteuerNr, '''') AS TC, p.Per_PersNr AS PersNr,
                LTRIM(RTRIM(p.Per_Vorname)) + '' '' + LTRIM(RTRIM(p.Per_Name)) AS Ad,
                LTRIM(RTRIM(p.Per_Grp1)) AS G1, LTRIM(RTRIM(p.Per_Grp2)) AS G2,
                CONVERT(char(8), l.TLe_Datum, 112) AS Gun,
                MIN(l.TLe_VonZeit) AS Giris, MAX(l.TLe_BisZeit) AS Cikis,
                COUNT(*) AS KayitSayisi, MIN(l.TLe_AbwArt) AS Mazeret
        FROM        TPerTab p
        INNER JOIN  TTagLes l ON l.TLe_PersNr = p.Per_PersNr
        LEFT  JOIN  TPerInd i ON i.PIn_PersNr = p.Per_PersNr
        WHERE   l.TLe_Datum >= ''' + @bas8 + ''' AND l.TLe_Datum <= ''' + @bit8 + '''
            AND l.TLe_BeginnKz = 0
        GROUP BY i.PIn_SteuerNr, p.Per_PersNr, p.Per_Vorname, p.Per_Name,
                 p.Per_Grp1, p.Per_Grp2, CONVERT(char(8), l.TLe_Datum, 112)';
    SET @l1 = N'SELECT TC = x.TC COLLATE Turkish_CI_AS, x.PersNr, x.Ad,
                       G1 = x.G1 COLLATE Turkish_CI_AS, G2 = x.G2 COLLATE Turkish_CI_AS,
                       x.Gun, x.Giris, x.Cikis, x.KayitSayisi, x.Mazeret
                FROM OPENQUERY([PDKS], ''' + REPLACE(@l2, '''', '''''') + ''') x';
    SET @sql = N'INSERT INTO #pdksGrp SELECT * FROM OPENQUERY(LIVE201, '''
             + REPLACE(@l1, '''', '''''') + ''') y';
    EXEC sp_executesql @sql;

    -- =====================================================================
    -- 6) BİRLEŞİK KİŞİ-GÜN — planlı + plansız
    -- =====================================================================
    CREATE TABLE #sat (
        SubeAd nvarchar(50), SicilNo varchar(11), Personel nvarchar(120),
        Bolum nvarchar(80), Gorev nvarchar(120), Tarih date,
        VardiyaTanim nvarchar(60), PlanBasDk int NULL, PlanBitDk int NULL,
        PlanCalismaDk int, Izin bit, Plansiz bit,
        KartGirisDk int NULL, KartCikisDk int NULL,
        KayitSayisi int NULL, Mazeret nvarchar(40) NULL, PersNr int NULL,
        HamOkutma int NULL);

    INSERT INTO #sat
    SELECT  p.SubeAd, p.SicilNo, p.Personel, p.Bolum, p.Gorev, p.Tarih,
            p.VardiyaTanim,
            DATEDIFF(minute, 0, p.Baslama), DATEDIFF(minute, 0, p.Bitis),
            ISNULL(p.ToplamCalismaDk, 0), ISNULL(p.Izin, 0), 0,
            DATEPART(hour, d.Giris) * 60 + DATEPART(minute, d.Giris),
            DATEPART(hour, d.Cikis) * 60 + DATEPART(minute, d.Cikis),
            d.KayitSayisi, d.Mazeret, t.PersNr, h.Okutma
    FROM        #plan p
    LEFT  JOIN  #pdks  d ON d.TC = p.SicilNo AND d.Gun = CONVERT(char(8), p.Tarih, 112)
    LEFT  JOIN  #tcTek t ON t.TC = p.SicilNo
    LEFT  JOIN  #ham   h ON h.TC = p.SicilNo AND h.Gun = CONVERT(char(8), p.Tarih, 112);

    -- Plansız: bu şubenin PDKS grubunda kart basmış ama plan anahtarı olmayan.
    -- Kişi bilgisi (Bölüm/Görev) plandan gelir; yoksa NULL bırakılır — UYDURULMAZ.
    INSERT INTO #sat
    SELECT  sg.SubeAd, g.TC, ISNULL(k.Personel, g.Ad), k.Bolum, k.Gorev,
            CONVERT(date, g.Gun), NULL, NULL, NULL, 0, 0, 1,
            DATEPART(hour, g.Giris) * 60 + DATEPART(minute, g.Giris),
            DATEPART(hour, g.Cikis) * 60 + DATEPART(minute, g.Cikis),
            g.KayitSayisi, g.Mazeret, g.PersNr, NULL
    FROM        #pdksGrp g
    INNER JOIN  #subeGrp sg ON sg.G1 = g.G1 AND sg.G2 = g.G2
    OUTER APPLY (SELECT TOP 1 x.Personel, x.Bolum, x.Gorev
                 FROM #plan x WHERE x.SicilNo = g.TC
                 ORDER BY x.Tarih) k
    WHERE NOT EXISTS (SELECT 1 FROM #plan x
                      WHERE x.SicilNo = g.TC
                        AND CONVERT(char(8), x.Tarih, 112) = g.Gun);

    -- =====================================================================
    -- 7) HESAP — tolerans · gün dönümü · mola · durum
    -- =====================================================================
    DELETE FROM bkm.Vrd_KisiGun WHERE KesimBas = @Bas AND KesimBit = @Bit;

    ;WITH h AS (
        SELECT s.*,
               -- İzin gününde plan başlaması 0 sayılır (ölçüldü: araç böyle yapıyor)
               planBas0 = CASE WHEN s.Izin = 1 THEN 0 ELSE ISNULL(s.PlanBasDk, 0) END,
               varsa    = CASE WHEN s.KartGirisDk IS NOT NULL
                                AND s.KartCikisDk IS NOT NULL THEN 1 ELSE 0 END
        FROM #sat s
    ), t AS (
        SELECT h.*,
               -- ÇİFT YÖNLÜ tolerans: erken gelen plandan önce sayılmaz,
               -- geç gelenin ilk 10 dk'sı affedilir.
               girisDk = CASE WHEN h.varsa = 0 THEN NULL ELSE
                    h.planBas0 + CASE
                        WHEN ABS(h.KartGirisDk - h.planBas0) <= @TOLERANS THEN 0
                        WHEN h.KartGirisDk - h.planBas0 > 0
                             THEN h.KartGirisDk - h.planBas0 - @TOLERANS
                        ELSE h.KartGirisDk - h.planBas0 + @TOLERANS END END
        FROM h
    ), c AS (
        SELECT t.*,
               -- GÜN DÖNÜMÜ: çıkış girişten küçükse ertesi güne aittir (+24 saat).
               -- Çıkışta tolerans YOK (ölçüldü 521/521).
               cikisDk = CASE WHEN t.varsa = 0 THEN NULL
                              WHEN t.KartCikisDk < t.girisDk THEN t.KartCikisDk + 1440
                              ELSE t.KartCikisDk END
        FROM t
    ), b AS (
        SELECT c.*, brutDk = CASE WHEN c.varsa = 0 THEN NULL
                                  ELSE c.cikisDk - c.girisDk END
        FROM c
    ), m AS (
        SELECT b.*,
               -- Mola tablosu PARAMETREDEN okunur (tip 'arac'). Hardcode edilirse
               -- Python ile SP sessizce ayrışır.
               molaDk = ISNULL((SELECT TOP 1 v.MolaDk FROM bkm.Vrd_Mola v
                                WHERE v.Tip = 'arac' AND v.AltSinirDk <= b.brutDk
                                ORDER BY v.AltSinirDk DESC), 0)
        FROM b
    )
    INSERT INTO bkm.Vrd_KisiGun
        (KesimBas, KesimBit, SayimBas, Sube, SicilNo, PdksNo, Personel, Bolum,
         Gorev, Tarih, VardiyaTanim, PlanBaslamaDk, PlanBitisDk, PlanCalismaDk,
         KartGirisDk, KartCikisDk, GirisDk, CikisDk, BrutDk, MolaDk, CalismaDk,
         Durum, Izin, GunDonumu, SayimDisi, KayitSayisi, MazeretTipi, OlcumNotu)
    SELECT
        @Bas, @Bit, @SayimBas, m.SubeAd, ISNULL(m.SicilNo, ''), m.PersNr,
        m.Personel, m.Bolum, m.Gorev, m.Tarih, m.VardiyaTanim,
        -- ⚠ İZİN GÜNÜNDE PLAN SAATİ RAPORLANMAZ. `VardiyaZaman` izin satırında
        --   Baslama/Bitis'i 00:00 tutuyor; ham yazılırsa "izinli ama 00:00-00:00
        --   vardiyası var" gibi okunur. Araç bu kolonları BOŞ bırakır, Python da
        --   öyle yapıyor — parite ölçümünde 781 satırda ayrıştı, SP'ye taşındı.
        CASE WHEN m.Izin = 1 THEN NULL ELSE m.PlanBasDk END,
        CASE WHEN m.Izin = 1 THEN NULL ELSE m.PlanBitDk END,
        CASE WHEN m.Izin = 1 THEN 0 ELSE ISNULL(m.PlanCalismaDk, 0) END,
        m.KartGirisDk, m.KartCikisDk, m.girisDk, m.cikisDk, m.brutDk,
        CASE WHEN m.varsa = 1 THEN m.molaDk END,
        CASE WHEN m.varsa = 1 THEN m.brutDk - m.molaDk ELSE 0 END,
        -- DURUM — HAM PDKS saatiyle karar verilir, toleranslıyla DEĞİL (595/595).
        durum = CASE
            WHEN m.Plansiz = 1                       THEN N'Vardiya Tanımsız Çalışma'
            WHEN m.Izin = 1 AND m.varsa = 1          THEN N'İzin Günü Çalışılmış'
            WHEN m.Izin = 1                          THEN N'İzinli'
            WHEN m.varsa = 0                         THEN N'Devamsız'
            WHEN (m.PlanBasDk IS NOT NULL AND m.KartGirisDk > m.PlanBasDk)
              OR (m.PlanBitDk IS NOT NULL AND m.KartCikisDk < m.PlanBitDk)
                                                     THEN N'Geç girilmiş ve/veya erken çıkılmış'
            ELSE N'Normal Çalışma' END,
        m.Izin,
        CASE WHEN m.varsa = 1 AND m.KartCikisDk < m.girisDk THEN 1 ELSE 0 END,
        CASE WHEN m.Tarih < @SayimBas THEN 1 ELSE 0 END,
        m.KayitSayisi, m.Mazeret,
        -- ÖLÇÜM NOTU — düzeltme ve şüphe SESSİZ KALMAZ.
        NULLIF(CASE
            WHEN m.varsa = 1 AND m.KartCikisDk < m.girisDk AND m.brutDk > 16 * 60
                THEN N'GÜN DÖNÜMÜ — çıkış ertesi gün sayıldı, brüt '
                     + CONVERT(nvarchar(4), m.brutDk / 60) + N':'
                     + RIGHT('0' + CONVERT(nvarchar(4), m.brutDk % 60), 2)
                     + N' ŞÜPHELİ (çıkış okutması unutulmuş olabilir)'
            WHEN m.varsa = 1 AND m.KartCikisDk < m.girisDk
                THEN N'GÜN DÖNÜMÜ — çıkış ertesi gün sayıldı'
            WHEN m.Plansiz = 0 AND m.Izin = 0 AND m.varsa = 0 AND m.PersNr IS NULL
                THEN N'PDKS kaydı yok — ölçülemiyor (devamsız DEĞİL)'
            WHEN m.Plansiz = 0 AND m.Izin = 0 AND m.varsa = 0 AND m.HamOkutma > 0
                THEN N'HAM OKUTMA VAR (' + CONVERT(nvarchar(10), m.HamOkutma)
                     + N' kez) — giriş/çıkış çifti oluşmamış'
            WHEN m.Plansiz = 0 AND m.Izin = 0 AND m.varsa = 0
                THEN N'Ham okutma da yok'
            ELSE N'' END, N'')
    FROM m;

    -- =====================================================================
    -- 8) YAYINLANAN RAPORUN ÖLÇÜSÜ — Eksik/Fazla Saat
    --
    -- ⚠ TABAN `Vrd_CalismaSaati` POLİTİKA TABLOSUDUR, vardiya planının SÜRESİ
    --   DEĞİL. İki taban farklı sonuç verir; ÖLÇÜLDÜ (17.09.2026, 6.113 kişi-gün):
    --   plan tabanı 4.313/4.596 saat · politika tabanı 6.118/5.024 saat.
    --   Yayınlanan Excel raporu politika tabanını kullanıyor; panel de onu
    --   kullanmak ZORUNDA, yoksa iki doğruluk kaynağı olur (emitter-ayrimi).
    --
    -- ⚠ ÇALIŞMA ÖLÇÜSÜ DE AYRI: Excel kendi mola tablosunu (tip 'excel') kullanır
    --   ve net 11 saati aşınca 30 dk daha düşer. Aracın ölçüsü (`CalismaDk`)
    --   DEĞİŞMEDEN durur — ikisi kasıtlı iki ayrı ölçü.
    -- =====================================================================
    UPDATE k SET
        k.GerekenDk = CASE
            WHEN k.SayimDisi = 1 THEN 0
            WHEN k.VardiyaTanim IN (N'HFT.İZİN', N'RAPOR', N'YILLIK İZİN',
                                    N'ÜCRETSİZ İZİN', N'ÖZEL DURUM') THEN 0
            -- ⚠ POLİTİKADA KARŞILIĞI YOKSA ŞUBE VARSAYILANINA DÜŞ — ama SESSİZCE
            --   DEĞİL: aşağıda Ölçüm Notu'na damga düşülür. NULL bırakılsaydı o
            --   satır Eksik/Fazla'ya hiç girmezdi ve rapor sessizce eksik olurdu.
            --   ÖLÇÜLDÜ (17.09.2026): tek satır (plansız kart basan, bölümsüz)
            --   18,8 dk fazla mesaiyi düşürüyordu.
            ELSE ISNULL(cs.CalismaDk, s.CalismaDk) END,
        k.Net2Dk = CASE WHEN k.BrutDk IS NULL THEN NULL ELSE
            k.BrutDk - x.molaExcel
            - CASE WHEN k.BrutDk - x.molaExcel > 11 * 60 THEN 30 ELSE 0 END END
    FROM        bkm.Vrd_KisiGun k
    INNER JOIN  bkm.Vrd_Sube s ON s.Sube = k.Sube
    LEFT  JOIN  bkm.Vrd_CalismaSaati cs
             ON cs.Grup = s.Grup AND cs.Sube = k.Sube
            AND cs.BolumAnahtar = ISNULL(k.Bolum, N'')
    CROSS APPLY (SELECT molaExcel = ISNULL((SELECT TOP 1 v.MolaDk FROM bkm.Vrd_Mola v
                                            WHERE v.Tip = 'excel' AND v.AltSinirDk < k.BrutDk
                                            ORDER BY v.AltSinirDk DESC), 0)) x
    WHERE k.KesimBas = @Bas AND k.KesimBit = @Bit;

    -- HAFTALIK İZİN PRİMİ — haftada 7 gün çalışıp hafta tatili kullanmayana,
    -- haftanın SON GÜNÜNE (Pazar) yazılır. Sayfadaki ilk satıra yazılırsa ay
    -- dönümünde primi önceki aya kaçırır (ÖLÇÜLDÜ: 331 kişi-hafta).
    ;WITH g AS (
        SELECT SicilNo, hafta = DATEPART(iso_week, Tarih),
               calisilan = SUM(CASE WHEN Durum IN (N'İzinli', N'Devamsız') THEN 0 ELSE 1 END)
        FROM bkm.Vrd_KisiGun
        WHERE KesimBas = @Bas AND KesimBit = @Bit
        GROUP BY SicilNo, DATEPART(iso_week, Tarih)
    )
    -- ⚠ PRİM TUTARI POLİTİKA SAATİDİR, `GerekenDk` DEĞİL. `GerekenDk` izin
    --   etiketli günde 0'a çekilir; haftanın 7 günü çalışan kişinin Pazar'ı
    --   çoğu zaman "İzin Günü Çalışılmış"tır (vardiya tanımı HFT.İZİN) ve prim
    --   sessizce SIFIRLANIR. ÖLÇÜLDÜ: 972 saat çıktı, doğrusu 1.380 saat.
    UPDATE k SET k.HaftalikPrimDk = cs.CalismaDk
    FROM bkm.Vrd_KisiGun k
    INNER JOIN g ON g.SicilNo = k.SicilNo AND g.hafta = DATEPART(iso_week, k.Tarih)
    INNER JOIN bkm.Vrd_Sube s ON s.Sube = k.Sube
    LEFT  JOIN bkm.Vrd_CalismaSaati cs
            ON cs.Grup = s.Grup AND cs.Sube = k.Sube
           AND cs.BolumAnahtar = ISNULL(k.Bolum, N'')
    WHERE k.KesimBas = @Bas AND k.KesimBit = @Bit
      AND k.SayimDisi = 0
      -- ⚠ PAZAR TESPİTİ `DATEPART(weekday)` İLE YAPILMAZ: sonucu `@@DATEFIRST`'e
      --   bağlıdır ve oturum diline göre değişir. ÖLÇÜLDÜ: 36. haftanın primi
      --   (378 saat) sessizce düştü, 37. haftanınki geldi — hata vermeden.
      --   1900-01-01 Pazartesi'dir; gün farkının 7'ye kalanı 6 ise Pazar.
      AND DATEDIFF(day, '19000101', k.Tarih) % 7 = 6
      AND g.calisilan >= 7;

    UPDATE bkm.Vrd_KisiGun SET
        HaftalikPrimDk = ISNULL(HaftalikPrimDk, 0),
        EksikDk = CASE WHEN SayimDisi = 1 OR Net2Dk IS NULL OR GerekenDk IS NULL THEN 0
                       WHEN Net2Dk < GerekenDk THEN GerekenDk - Net2Dk ELSE 0 END,
        FazlaDk = CASE WHEN SayimDisi = 1 THEN 0 ELSE
                       CASE WHEN Net2Dk IS NOT NULL AND GerekenDk IS NOT NULL
                                 AND Net2Dk > GerekenDk THEN Net2Dk - GerekenDk ELSE 0 END
                       + ISNULL(HaftalikPrimDk, 0) END
    WHERE KesimBas = @Bas AND KesimBit = @Bit;

    -- =====================================================================
    -- 9) FAZLA MESAİNİN KAYNAĞI — "ne kadarı fazla çalışma, ne kadarı izin
    --    iptali" (GMY isteği 17.09.2026). Tek rakam yönetilemez: üç kalem
    --    HUKUKEN DE AYRIDIR (m.41 fazla çalışma · m.46 hafta tatili çalışması
    --    1 yevmiye + %50 · izin gününde çalıştırma), ödeme biçimleri farklı.
    --
    -- ⚠ İZİN GÜNÜNDE `GerekenDk` 0'dır (izin etiketi) → o satırda fazlanın
    --   TAMAMI izin iptalidir. Kalem sırası bu yüzden önemli: önce izin iptali
    --   ve plansız ayrılır, "fazla çalışma" ARTAKALANDIR — toplam hep tutar.
    -- =====================================================================
    UPDATE bkm.Vrd_KisiGun SET
        FazlaIzinIptalDk = CASE WHEN SayimDisi = 1 THEN 0
                                WHEN Izin = 1 AND Net2Dk > 0 THEN Net2Dk ELSE 0 END,
        FazlaPlansizDk   = CASE WHEN SayimDisi = 1 THEN 0
                                WHEN Durum = N'Vardiya Tanımsız Çalışma'
                                     AND Net2Dk > ISNULL(GerekenDk, 0)
                                THEN Net2Dk - ISNULL(GerekenDk, 0) ELSE 0 END
    WHERE KesimBas = @Bas AND KesimBit = @Bit;

    UPDATE bkm.Vrd_KisiGun SET
        FazlaCalismaDk = ISNULL(FazlaDk, 0) - ISNULL(HaftalikPrimDk, 0)
                       - ISNULL(FazlaIzinIptalDk, 0) - ISNULL(FazlaPlansizDk, 0)
    WHERE KesimBas = @Bas AND KesimBit = @Bit;

    -- KONTROL EDİLEBİLİRLİK — GMY sorusu 17.09.2026: *"patron sezonda izinleri
    -- iptal ediyor mecburen, dağılan mağaza gün bitiminde toplanmak için
    -- çalışmak gerekiyor — ne kadarı mağazanın elinde yapılmış mesai?"*
    --
    -- Plan üstü çalışma İKİ UÇTAN doğar ve ikisi AYRI yönetim sorusudur:
    --   · çıkış plan bitişinden SONRA  → kapanış/toplanma, mağaza operasyonu
    --   · giriş plan başlangıcından ÖNCE → erken açılış/hazırlık
    -- Ölçülüp yazılır; yorum panelde değil `ik-danisman`'da.
    UPDATE bkm.Vrd_KisiGun SET
        CikisSonrasiDk = CASE WHEN SayimDisi = 0 AND CikisDk > PlanBitisDk
                              THEN CikisDk - PlanBitisDk ELSE 0 END,
        GirisOncesiDk  = CASE WHEN SayimDisi = 0 AND GirisDk < PlanBaslamaDk
                              THEN PlanBaslamaDk - GirisDk ELSE 0 END
    WHERE KesimBas = @Bas AND KesimBit = @Bit;

    -- İzin satırında Net2Dk yok ama GerekenDk 0 → eksik 0. Çalışmayan (Devamsız)
    -- satırda Net2Dk NULL ve GerekenDk dolu → EKSİK SAYILMALI (plan vardı, gelmedi).
    UPDATE bkm.Vrd_KisiGun SET EksikDk = GerekenDk
    WHERE KesimBas = @Bas AND KesimBit = @Bit
      AND SayimDisi = 0 AND Net2Dk IS NULL AND ISNULL(GerekenDk, 0) > 0;

    -- Politika boşluğu BEYAN EDİLİR (fallback sessiz kalmaz — error-handling.md).
    UPDATE k SET k.OlcumNotu =
        CASE WHEN k.OlcumNotu IS NULL THEN N'' ELSE k.OlcumNotu + N' · ' END
        + N'ÇALIŞMA SAATİ POLİTİKASINDA KARŞILIĞI YOK — şube varsayılanı kullanıldı'
    FROM        bkm.Vrd_KisiGun k
    INNER JOIN  bkm.Vrd_Sube s ON s.Sube = k.Sube
    LEFT  JOIN  bkm.Vrd_CalismaSaati cs
             ON cs.Grup = s.Grup AND cs.Sube = k.Sube
            AND cs.BolumAnahtar = ISNULL(k.Bolum, N'')
    WHERE k.KesimBas = @Bas AND k.KesimBit = @Bit
      AND cs.CalismaDk IS NULL AND k.SayimDisi = 0;

    IF @Konus = 1
    BEGIN
        SELECT Kesim = CONVERT(char(10), @Bas, 104) + N' – ' + CONVERT(char(10), @Bit, 104),
               SayimBas = CONVERT(char(10), @SayimBas, 104),
               KisiGun = COUNT(*), Sube = COUNT(DISTINCT Sube),
               Plansiz = SUM(CASE WHEN Durum = N'Vardiya Tanımsız Çalışma' THEN 1 ELSE 0 END),
               GunDonumu = SUM(CONVERT(int, GunDonumu)),
               SayimDisi = SUM(CONVERT(int, SayimDisi))
        FROM bkm.Vrd_KisiGun WHERE KesimBas = @Bas AND KesimBit = @Bit;
    END
END
GO
