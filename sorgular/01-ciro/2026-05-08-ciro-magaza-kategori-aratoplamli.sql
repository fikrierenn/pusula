-- =====================================================================
-- CIRO_MAGAZA_KATEGORI_ARATOPLAMLI_GUNLUK_KARSILASTIRMA.sql
-- Amaç: Kategori detay + KİTAP ara toplam + DİĞER ara toplam + GENEL TOPLAM
-- Sıralama:
--   1) KİTAP grubu kategorileri (Akademi, Çocuk Kitabı, Hazırlık Kitapları, Kitap) — alfabetik
--   2) ★ KİTAP ARA TOPLAM
--   3) DİĞER kategoriler — alfabetik
--   4) ★ DİĞER ARA TOPLAM
--   5) ★★ GENEL TOPLAM
-- Kaynak: dbo.irsHrk + bkm.urunbilgi.Kategori3
-- Mağazalar: FSM (1), Özlüce (4477), İst.Yolu (4478)
-- ehTip: 4=Mağaza Satış, 100=POS Satış, 5=Mağaza İade, 101=POS İade
-- FİLTRE: Kategori3='Genel' hariç, stkID 583160 (Geri Dönüşüm) hariç
-- =====================================================================
DECLARE @BugunBaslangic date = CONVERT(date,'08.05.2026',104);
DECLARE @BugunBitis     date = CONVERT(date,'09.05.2026',104);
DECLARE @DunBaslangic   date = CONVERT(date,'07.05.2026',104);
DECLARE @DunBitis       date = CONVERT(date,'08.05.2026',104);

;WITH HareketKaynak AS (
    SELECT
        Hareket.ehMekan  AS MekanID,
        Hareket.ehTip    AS HareketTipi,
        Hareket.ehAdetN  AS HareketAdet,
        Hareket.ehTutarN AS HareketTutar,
        ISNULL(NULLIF(UrunBilgi.Kategori3,''),'(Tanımsız)') AS KategoriAdi,
        CASE WHEN UrunBilgi.Kategori3 IN (N'Akademi', N'Çocuk Kitabı', N'Hazırlık Kitapları', N'Kitap')
             THEN N'KİTAP' ELSE N'DİĞER' END AS KitapDiger,
        CASE
            WHEN Hareket.ehTrhS >= @BugunBaslangic AND Hareket.ehTrhS < @BugunBitis THEN 'B'
            WHEN Hareket.ehTrhS >= @DunBaslangic   AND Hareket.ehTrhS < @DunBitis   THEN 'D'
        END AS Donem
    FROM dbo.irsHrk AS Hareket WITH (NOLOCK)
    JOIN bkm.urunbilgi AS UrunBilgi
         ON UrunBilgi.stkID = Hareket.ehstkID
    WHERE Hareket.ehTrhS    >= @DunBaslangic
      AND Hareket.ehTrhS    <  @BugunBitis
      AND Hareket.ehMekan   IN (1, 4477, 4478)
      AND Hareket.ehTip     IN (4, 5, 100, 101)
      AND Hareket.ehAltDepo  = 0
      AND ISNULL(NULLIF(UrunBilgi.Kategori3, ''), '(Tanımsız)') <> 'Genel'
      AND Hareket.ehstkID    <> 583160
),
KategoriPivot AS (
    SELECT
        KategoriAdi, KitapDiger,
        -- FSM Bugün
        -SUM(CASE WHEN Donem='B' AND MekanID=1    AND HareketTipi IN (4,100) THEN HareketAdet  ELSE 0 END) AS FsmSatisAdetB,
         SUM(CASE WHEN Donem='B' AND MekanID=1    AND HareketTipi IN (5,101) THEN HareketAdet  ELSE 0 END) AS FsmIadeAdetB,
         SUM(CASE WHEN Donem='B' AND MekanID=1    AND HareketTipi IN (4,100) THEN HareketTutar ELSE 0 END) AS FsmSatisTutarB,
         SUM(CASE WHEN Donem='B' AND MekanID=1    AND HareketTipi IN (5,101) THEN HareketTutar ELSE 0 END) AS FsmIadeTutarB,
        -- FSM Dün
        -SUM(CASE WHEN Donem='D' AND MekanID=1    AND HareketTipi IN (4,100) THEN HareketAdet  ELSE 0 END)
        -SUM(CASE WHEN Donem='D' AND MekanID=1    AND HareketTipi IN (5,101) THEN HareketAdet  ELSE 0 END) AS FsmNetAdetD,
         SUM(CASE WHEN Donem='D' AND MekanID=1    AND HareketTipi IN (4,100) THEN HareketTutar ELSE 0 END)
        -SUM(CASE WHEN Donem='D' AND MekanID=1    AND HareketTipi IN (5,101) THEN HareketTutar ELSE 0 END) AS FsmNetTutarD,
        -- Özlüce Bugün
        -SUM(CASE WHEN Donem='B' AND MekanID=4477 AND HareketTipi IN (4,100) THEN HareketAdet  ELSE 0 END) AS OzluceSatisAdetB,
         SUM(CASE WHEN Donem='B' AND MekanID=4477 AND HareketTipi IN (5,101) THEN HareketAdet  ELSE 0 END) AS OzluceIadeAdetB,
         SUM(CASE WHEN Donem='B' AND MekanID=4477 AND HareketTipi IN (4,100) THEN HareketTutar ELSE 0 END) AS OzluceSatisTutarB,
         SUM(CASE WHEN Donem='B' AND MekanID=4477 AND HareketTipi IN (5,101) THEN HareketTutar ELSE 0 END) AS OzluceIadeTutarB,
        -- Özlüce Dün
        -SUM(CASE WHEN Donem='D' AND MekanID=4477 AND HareketTipi IN (4,100) THEN HareketAdet  ELSE 0 END)
        -SUM(CASE WHEN Donem='D' AND MekanID=4477 AND HareketTipi IN (5,101) THEN HareketAdet  ELSE 0 END) AS OzluceNetAdetD,
         SUM(CASE WHEN Donem='D' AND MekanID=4477 AND HareketTipi IN (4,100) THEN HareketTutar ELSE 0 END)
        -SUM(CASE WHEN Donem='D' AND MekanID=4477 AND HareketTipi IN (5,101) THEN HareketTutar ELSE 0 END) AS OzluceNetTutarD,
        -- İst.Yolu Bugün
        -SUM(CASE WHEN Donem='B' AND MekanID=4478 AND HareketTipi IN (4,100) THEN HareketAdet  ELSE 0 END) AS IstYoluSatisAdetB,
         SUM(CASE WHEN Donem='B' AND MekanID=4478 AND HareketTipi IN (5,101) THEN HareketAdet  ELSE 0 END) AS IstYoluIadeAdetB,
         SUM(CASE WHEN Donem='B' AND MekanID=4478 AND HareketTipi IN (4,100) THEN HareketTutar ELSE 0 END) AS IstYoluSatisTutarB,
         SUM(CASE WHEN Donem='B' AND MekanID=4478 AND HareketTipi IN (5,101) THEN HareketTutar ELSE 0 END) AS IstYoluIadeTutarB,
        -- İst.Yolu Dün
        -SUM(CASE WHEN Donem='D' AND MekanID=4478 AND HareketTipi IN (4,100) THEN HareketAdet  ELSE 0 END)
        -SUM(CASE WHEN Donem='D' AND MekanID=4478 AND HareketTipi IN (5,101) THEN HareketAdet  ELSE 0 END) AS IstYoluNetAdetD,
         SUM(CASE WHEN Donem='D' AND MekanID=4478 AND HareketTipi IN (4,100) THEN HareketTutar ELSE 0 END)
        -SUM(CASE WHEN Donem='D' AND MekanID=4478 AND HareketTipi IN (5,101) THEN HareketTutar ELSE 0 END) AS IstYoluNetTutarD
    FROM HareketKaynak
    GROUP BY KategoriAdi, KitapDiger
),
DetayVeToplam AS (
    -- 1) KİTAP detay
    SELECT 1 AS SiralamaGrubu, KategoriAdi AS Etiket, KitapDiger,
           FsmSatisAdetB, FsmIadeAdetB, FsmSatisTutarB, FsmIadeTutarB, FsmNetAdetD, FsmNetTutarD,
           OzluceSatisAdetB, OzluceIadeAdetB, OzluceSatisTutarB, OzluceIadeTutarB, OzluceNetAdetD, OzluceNetTutarD,
           IstYoluSatisAdetB, IstYoluIadeAdetB, IstYoluSatisTutarB, IstYoluIadeTutarB, IstYoluNetAdetD, IstYoluNetTutarD
    FROM KategoriPivot
    WHERE KitapDiger = N'KİTAP'

    UNION ALL

    -- 2) KİTAP ara toplam
    SELECT 2, N'★ KİTAP ARA TOPLAM', N'KİTAP',
        SUM(FsmSatisAdetB),    SUM(FsmIadeAdetB),    SUM(FsmSatisTutarB),    SUM(FsmIadeTutarB),    SUM(FsmNetAdetD),    SUM(FsmNetTutarD),
        SUM(OzluceSatisAdetB), SUM(OzluceIadeAdetB), SUM(OzluceSatisTutarB), SUM(OzluceIadeTutarB), SUM(OzluceNetAdetD), SUM(OzluceNetTutarD),
        SUM(IstYoluSatisAdetB),SUM(IstYoluIadeAdetB),SUM(IstYoluSatisTutarB),SUM(IstYoluIadeTutarB),SUM(IstYoluNetAdetD),SUM(IstYoluNetTutarD)
    FROM KategoriPivot
    WHERE KitapDiger = N'KİTAP'

    UNION ALL

    -- 3) DİĞER detay
    SELECT 3, KategoriAdi, KitapDiger,
           FsmSatisAdetB, FsmIadeAdetB, FsmSatisTutarB, FsmIadeTutarB, FsmNetAdetD, FsmNetTutarD,
           OzluceSatisAdetB, OzluceIadeAdetB, OzluceSatisTutarB, OzluceIadeTutarB, OzluceNetAdetD, OzluceNetTutarD,
           IstYoluSatisAdetB, IstYoluIadeAdetB, IstYoluSatisTutarB, IstYoluIadeTutarB, IstYoluNetAdetD, IstYoluNetTutarD
    FROM KategoriPivot
    WHERE KitapDiger = N'DİĞER'

    UNION ALL

    -- 4) DİĞER ara toplam
    SELECT 4, N'★ DİĞER ARA TOPLAM', N'DİĞER',
        SUM(FsmSatisAdetB),    SUM(FsmIadeAdetB),    SUM(FsmSatisTutarB),    SUM(FsmIadeTutarB),    SUM(FsmNetAdetD),    SUM(FsmNetTutarD),
        SUM(OzluceSatisAdetB), SUM(OzluceIadeAdetB), SUM(OzluceSatisTutarB), SUM(OzluceIadeTutarB), SUM(OzluceNetAdetD), SUM(OzluceNetTutarD),
        SUM(IstYoluSatisAdetB),SUM(IstYoluIadeAdetB),SUM(IstYoluSatisTutarB),SUM(IstYoluIadeTutarB),SUM(IstYoluNetAdetD),SUM(IstYoluNetTutarD)
    FROM KategoriPivot
    WHERE KitapDiger = N'DİĞER'

    UNION ALL

    -- 5) GENEL TOPLAM
    SELECT 5, N'★★ GENEL TOPLAM', N'TOPLAM',
        SUM(FsmSatisAdetB),    SUM(FsmIadeAdetB),    SUM(FsmSatisTutarB),    SUM(FsmIadeTutarB),    SUM(FsmNetAdetD),    SUM(FsmNetTutarD),
        SUM(OzluceSatisAdetB), SUM(OzluceIadeAdetB), SUM(OzluceSatisTutarB), SUM(OzluceIadeTutarB), SUM(OzluceNetAdetD), SUM(OzluceNetTutarD),
        SUM(IstYoluSatisAdetB),SUM(IstYoluIadeAdetB),SUM(IstYoluSatisTutarB),SUM(IstYoluIadeTutarB),SUM(IstYoluNetAdetD),SUM(IstYoluNetTutarD)
    FROM KategoriPivot
),
GenelCiro AS (
    SELECT
        SUM( (FsmSatisTutarB    - FsmIadeTutarB)
           + (OzluceSatisTutarB - OzluceIadeTutarB)
           + (IstYoluSatisTutarB- IstYoluIadeTutarB) ) AS GenelNetCiro,
        SUM(  FsmNetTutarD + OzluceNetTutarD + IstYoluNetTutarD ) AS GenelNetCiroDun
    FROM KategoriPivot
)
SELECT
    Detay.Etiket                                                                        AS [Kategori],
    Detay.KitapDiger                                                                    AS [Grup],
    -- ============== FSM bloğu ==============
    CAST(Detay.FsmSatisAdetB - Detay.FsmIadeAdetB AS int)                               AS [FSM Net Ad],
    CAST(Detay.FsmNetAdetD AS int)                                                      AS [FSM Dün Ad],
    CAST(100.0 * ((Detay.FsmSatisAdetB - Detay.FsmIadeAdetB) - Detay.FsmNetAdetD)
         / NULLIF(Detay.FsmNetAdetD,0) AS decimal(10,1))                                AS [FSM Ad Δ%],
    CAST(Detay.FsmSatisTutarB - Detay.FsmIadeTutarB AS decimal(18,2))                   AS [FSM Net TL],
    CAST(Detay.FsmNetTutarD AS decimal(18,2))                                           AS [FSM Dün TL],
    CAST((Detay.FsmSatisTutarB - Detay.FsmIadeTutarB) - Detay.FsmNetTutarD AS decimal(18,2)) AS [FSM Δ TL],
    CAST(100.0 * ((Detay.FsmSatisTutarB - Detay.FsmIadeTutarB) - Detay.FsmNetTutarD)
         / NULLIF(Detay.FsmNetTutarD,0) AS decimal(10,1))                               AS [FSM Δ%],
    -- ============== Özlüce bloğu ==============
    CAST(Detay.OzluceSatisAdetB - Detay.OzluceIadeAdetB AS int)                         AS [Özlüce Net Ad],
    CAST(Detay.OzluceNetAdetD AS int)                                                   AS [Özlüce Dün Ad],
    CAST(100.0 * ((Detay.OzluceSatisAdetB - Detay.OzluceIadeAdetB) - Detay.OzluceNetAdetD)
         / NULLIF(Detay.OzluceNetAdetD,0) AS decimal(10,1))                             AS [Özlüce Ad Δ%],
    CAST(Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB AS decimal(18,2))             AS [Özlüce Net TL],
    CAST(Detay.OzluceNetTutarD AS decimal(18,2))                                        AS [Özlüce Dün TL],
    CAST((Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB) - Detay.OzluceNetTutarD AS decimal(18,2)) AS [Özlüce Δ TL],
    CAST(100.0 * ((Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB) - Detay.OzluceNetTutarD)
         / NULLIF(Detay.OzluceNetTutarD,0) AS decimal(10,1))                            AS [Özlüce Δ%],
    -- ============== İst.Yolu bloğu ==============
    CAST(Detay.IstYoluSatisAdetB - Detay.IstYoluIadeAdetB AS int)                       AS [İst.Yolu Net Ad],
    CAST(Detay.IstYoluNetAdetD AS int)                                                  AS [İst.Yolu Dün Ad],
    CAST(100.0 * ((Detay.IstYoluSatisAdetB - Detay.IstYoluIadeAdetB) - Detay.IstYoluNetAdetD)
         / NULLIF(Detay.IstYoluNetAdetD,0) AS decimal(10,1))                            AS [İst.Yolu Ad Δ%],
    CAST(Detay.IstYoluSatisTutarB - Detay.IstYoluIadeTutarB AS decimal(18,2))           AS [İst.Yolu Net TL],
    CAST(Detay.IstYoluNetTutarD AS decimal(18,2))                                       AS [İst.Yolu Dün TL],
    CAST((Detay.IstYoluSatisTutarB - Detay.IstYoluIadeTutarB) - Detay.IstYoluNetTutarD AS decimal(18,2)) AS [İst.Yolu Δ TL],
    CAST(100.0 * ((Detay.IstYoluSatisTutarB - Detay.IstYoluIadeTutarB) - Detay.IstYoluNetTutarD)
         / NULLIF(Detay.IstYoluNetTutarD,0) AS decimal(10,1))                           AS [İst.Yolu Δ%],
    -- ============== Toplam bloğu ==============
    CAST( (Detay.FsmSatisAdetB    - Detay.FsmIadeAdetB)
        + (Detay.OzluceSatisAdetB - Detay.OzluceIadeAdetB)
        + (Detay.IstYoluSatisAdetB- Detay.IstYoluIadeAdetB) AS int)                     AS [Toplam Net Ad],
    CAST(Detay.FsmNetAdetD + Detay.OzluceNetAdetD + Detay.IstYoluNetAdetD AS int)       AS [Toplam Dün Ad],
    CAST(100.0 *
         ( ( (Detay.FsmSatisAdetB    - Detay.FsmIadeAdetB)
           + (Detay.OzluceSatisAdetB - Detay.OzluceIadeAdetB)
           + (Detay.IstYoluSatisAdetB- Detay.IstYoluIadeAdetB) )
         - (Detay.FsmNetAdetD + Detay.OzluceNetAdetD + Detay.IstYoluNetAdetD) )
         / NULLIF(Detay.FsmNetAdetD + Detay.OzluceNetAdetD + Detay.IstYoluNetAdetD, 0)
         AS decimal(10,1))                                                              AS [Toplam Ad Δ%],
    CAST( (Detay.FsmSatisTutarB    - Detay.FsmIadeTutarB)
        + (Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB)
        + (Detay.IstYoluSatisTutarB- Detay.IstYoluIadeTutarB) AS decimal(18,2))         AS [Toplam Net TL],
    CAST(Detay.FsmNetTutarD + Detay.OzluceNetTutarD + Detay.IstYoluNetTutarD AS decimal(18,2)) AS [Toplam Dün TL],
    CAST( ( (Detay.FsmSatisTutarB    - Detay.FsmIadeTutarB)
          + (Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB)
          + (Detay.IstYoluSatisTutarB- Detay.IstYoluIadeTutarB) )
        - (Detay.FsmNetTutarD + Detay.OzluceNetTutarD + Detay.IstYoluNetTutarD) AS decimal(18,2)) AS [Toplam Δ TL],
    CAST(100.0 *
         ( ( (Detay.FsmSatisTutarB    - Detay.FsmIadeTutarB)
           + (Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB)
           + (Detay.IstYoluSatisTutarB- Detay.IstYoluIadeTutarB) )
         - (Detay.FsmNetTutarD + Detay.OzluceNetTutarD + Detay.IstYoluNetTutarD) )
         / NULLIF(Detay.FsmNetTutarD + Detay.OzluceNetTutarD + Detay.IstYoluNetTutarD, 0)
         AS decimal(10,1))                                                              AS [Toplam Δ%],
    -- ============== Pay yüzdeleri ==============
    CAST(100.0 *
         ( (Detay.FsmSatisTutarB    - Detay.FsmIadeTutarB)
         + (Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB)
         + (Detay.IstYoluSatisTutarB- Detay.IstYoluIadeTutarB) )
         / NULLIF(Toplam.GenelNetCiro,0) AS decimal(10,1))                              AS [Pay %],
    CAST(100.0 *
         (Detay.FsmNetTutarD + Detay.OzluceNetTutarD + Detay.IstYoluNetTutarD)
         / NULLIF(Toplam.GenelNetCiroDun,0) AS decimal(10,1))                           AS [Dün Pay %],
    -- ============== Ortalama birim fiyat (Net TL / Net Ad) ==============
    CAST(
        ( (Detay.FsmSatisTutarB    - Detay.FsmIadeTutarB)
        + (Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB)
        + (Detay.IstYoluSatisTutarB- Detay.IstYoluIadeTutarB) )
        /
        NULLIF( (Detay.FsmSatisAdetB    - Detay.FsmIadeAdetB)
              + (Detay.OzluceSatisAdetB - Detay.OzluceIadeAdetB)
              + (Detay.IstYoluSatisAdetB- Detay.IstYoluIadeAdetB), 0)
        AS decimal(18,2))                                                               AS [Ort. Birim ₺ (Bugün)],
    CAST(
        (Detay.FsmNetTutarD + Detay.OzluceNetTutarD + Detay.IstYoluNetTutarD)
        / NULLIF(Detay.FsmNetAdetD + Detay.OzluceNetAdetD + Detay.IstYoluNetAdetD, 0)
        AS decimal(18,2))                                                               AS [Ort. Birim ₺ (Dün)],
    CAST(100.0 *
         (
           ( ( (Detay.FsmSatisTutarB    - Detay.FsmIadeTutarB)
             + (Detay.OzluceSatisTutarB - Detay.OzluceIadeTutarB)
             + (Detay.IstYoluSatisTutarB- Detay.IstYoluIadeTutarB) )
             /
             NULLIF( (Detay.FsmSatisAdetB    - Detay.FsmIadeAdetB)
                   + (Detay.OzluceSatisAdetB - Detay.OzluceIadeAdetB)
                   + (Detay.IstYoluSatisAdetB- Detay.IstYoluIadeAdetB), 0)
           )
           -
           ( (Detay.FsmNetTutarD + Detay.OzluceNetTutarD + Detay.IstYoluNetTutarD)
             / NULLIF(Detay.FsmNetAdetD + Detay.OzluceNetAdetD + Detay.IstYoluNetAdetD, 0)
           )
         )
         /
         NULLIF(
           (Detay.FsmNetTutarD + Detay.OzluceNetTutarD + Detay.IstYoluNetTutarD)
           / NULLIF(Detay.FsmNetAdetD + Detay.OzluceNetAdetD + Detay.IstYoluNetAdetD, 0)
         , 0)
         AS decimal(10,1))                                                              AS [Birim Δ%]
FROM DetayVeToplam AS Detay
CROSS JOIN GenelCiro AS Toplam
ORDER BY Detay.SiralamaGrubu,
         CASE WHEN Detay.SiralamaGrubu IN (1, 3) THEN Detay.Etiket END
         COLLATE Turkish_CI_AS ASC;
