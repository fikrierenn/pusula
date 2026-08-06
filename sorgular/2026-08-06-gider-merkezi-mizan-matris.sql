/* ============================================================================
   GİDER MERKEZİ — MİZAN HEAT-MATRIX  (DerinSISBkm)  [DİNAMİK]
   Kaynak: mhs.mhsFis (GL satır) — MizanQueries.cs çekirdeği.
   Kurallar: Bakiye = Borç−Alacak (fisBA=1→-fisTutar / fisBA=0→fisTutar);
             Kapanış fişi HARİÇ; Yıl = fisSirketID + 2020 (2026 → sirket 6).
   Gider = 7xx tümü + gider-6xx (62/63/65/66/68); gelir 6xx (600/602/642/679) HARİÇ.
   MUTABAKAT (2026-08-06): DerinSIS resmi "Gider Merkezi Dağılımlı Mizan" (Haziran.26) ile
     birebir — 740=5.271.289,94 · 760=14.076.671,28 · 770=21.006.811,77 · 780=38.488.515,55
     (hücre+grup kuruşuna kadar tuttu). Bu sorgu o raporun tekrar-üretilebilir hali.
   İki matris:
     A) GİDER MERKEZİ × AY   (satır dinamik · 12 takvim ayı)
     B) HESAP (detay/alt kırılım) × GİDER MERKEZİ   (İKİ EKSEN DE DİNAMİK)
   Ayarlar: @yil · @ay (üst ay) · @ayBas (1=kümüle · =@ay → SEÇİLİ TEK AY).
   ============================================================================ */

DECLARE @yil    int = 2026;
DECLARE @ay     int = 6;             -- test: tek ay → @ayBas = @ay (aşağıda)
DECLARE @ayBas  int = 6;             -- KÜMÜLE: 1  ·  SEÇİLİ TEK AY: @ayBas = @ay
DECLARE @sirket int = @yil - 2020;


/* ========== A)  GİDER MERKEZİ × AY  (satır dinamik · 12 ay) ================ */
;WITH g AS (
    SELECT v.GiderMerkezi, MONTH(ff.fisTarih) AS Ay,
           SUM(CASE WHEN ff.fisBA=1 THEN -ff.fisTutar ELSE 0 END)
         - SUM(CASE WHEN ff.fisBA=0 THEN  ff.fisTutar ELSE 0 END) AS Gider
    FROM DerinSISBkm.mhs.mhsFis ff
    JOIN DerinSISBkm.mhs.mhsFisBaslik b ON b.fisbID=ff.fisID AND b.fisbSirketID=ff.fisSirketID
    JOIN DerinSISBkm.mhs.mhsHsp h       ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
    LEFT JOIN DerinSISBkm.dbo.frm gm     ON gm.frmID=ff.fisGdrMerkez
    CROSS APPLY (SELECT CASE WHEN ff.fisGdrMerkez>0
                    THEN LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(gm.frmAd,N'G - ',N''),N'G- ',N''),N' Gider Merkezi',N'')))
                    ELSE N'GENEL (dağıtılmamış)' END) v(GiderMerkezi)
    WHERE ff.fisSirketID=@sirket AND MONTH(ff.fisTarih)<=@ay
      AND ISNULL(b.fisAd,N'')<>N'Kapanış'
      AND (h.hspKod LIKE '7%' OR LEFT(h.hspKod,2) IN ('62','63','65','66','68'))
    GROUP BY v.GiderMerkezi, MONTH(ff.fisTarih)
)
SELECT GiderMerkezi,
       SUM(CASE WHEN Ay= 1 THEN Gider END) AS Oca, SUM(CASE WHEN Ay= 2 THEN Gider END) AS Sub,
       SUM(CASE WHEN Ay= 3 THEN Gider END) AS Mar, SUM(CASE WHEN Ay= 4 THEN Gider END) AS Nis,
       SUM(CASE WHEN Ay= 5 THEN Gider END) AS May, SUM(CASE WHEN Ay= 6 THEN Gider END) AS Haz,
       SUM(CASE WHEN Ay= 7 THEN Gider END) AS Tem, SUM(CASE WHEN Ay= 8 THEN Gider END) AS Agu,
       SUM(CASE WHEN Ay= 9 THEN Gider END) AS Eyl, SUM(CASE WHEN Ay=10 THEN Gider END) AS Eki,
       SUM(CASE WHEN Ay=11 THEN Gider END) AS Kas, SUM(CASE WHEN Ay=12 THEN Gider END) AS Ara,
       SUM(Gider) AS Toplam
FROM g GROUP BY GiderMerkezi ORDER BY SUM(Gider) DESC;


/* ========== B)  HESAP (detay/alt kırılım) × GİDER MERKEZİ  [DİNAMİK] =======
   Satır = hesap detay (hspKod+ad), ana grup (740/760/…) altında sıralı.
   Sütun = mevcut gider merkezleri (veriden, hardcode yok).
   Dönem = @ayBas..@ay  (tek ay için @ayBas=@ay).                             */

-- Base grain (dinamik string parçası): Grup + Hesap + HspKod(sıra) + Merkez + Gider.
DECLARE @base nvarchar(max) = N'
    SELECT LEFT(h.hspKod,3) + N'' '' + CAST(ISNULL(an.aHspAd,N'''') AS nvarchar(60)) AS Grup,
           h.hspKod + N'' '' + CAST(h.hspAd AS nvarchar(70)) AS Hesap,
           h.hspKod AS HspKod,
           v.GiderMerkezi AS Merkez,
           SUM(CASE WHEN ff.fisBA=1 THEN -ff.fisTutar ELSE 0 END)
         - SUM(CASE WHEN ff.fisBA=0 THEN  ff.fisTutar ELSE 0 END) AS Gider
    FROM DerinSISBkm.mhs.mhsFis ff
    JOIN DerinSISBkm.mhs.mhsFisBaslik b ON b.fisbID=ff.fisID AND b.fisbSirketID=ff.fisSirketID
    JOIN DerinSISBkm.mhs.mhsHsp h       ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
    LEFT JOIN DerinSISBkm.mhs.mhsAnaHsp an ON CAST(an.aHspID AS varchar(20))=LEFT(h.hspKod,3)
    LEFT JOIN DerinSISBkm.dbo.frm gm     ON gm.frmID=ff.fisGdrMerkez
    CROSS APPLY (SELECT CASE WHEN ff.fisGdrMerkez>0
                    THEN LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(gm.frmAd,N''G - '',N''''),N''G- '',N''''),N'' Gider Merkezi'',N'''')))
                    ELSE N''GENEL (dağıtılmamış)'' END) v(GiderMerkezi)
    WHERE ff.fisSirketID=@sirket
      AND MONTH(ff.fisTarih) BETWEEN @ayBas AND @ay
      AND ISNULL(b.fisAd,N'''')<>N''Kapanış''
      AND (h.hspKod LIKE ''7%'' OR LEFT(h.hspKod,2) IN (''62'',''63'',''65'',''66'',''68''))
    GROUP BY LEFT(h.hspKod,3) + N'' '' + CAST(ISNULL(an.aHspAd,N'''') AS nvarchar(60)),
             h.hspKod + N'' '' + CAST(h.hspAd AS nvarchar(70)), h.hspKod, v.GiderMerkezi';

-- 1) Sütun listesi = mevcut gider merkezleri (veriden, tutar DESC).
DECLARE @cols nvarchar(max);
DECLARE @colSql nvarchar(max) = N'
    SELECT @cols = STUFF((
       SELECT N'', SUM(CASE WHEN src.Merkez=N'''''' + REPLACE(x.Merkez,'''''''','''''''''''') + N'''''' THEN src.Gider END) AS '' + QUOTENAME(x.Merkez)
       FROM (SELECT Merkez, SUM(Gider) AS T FROM (' + @base + N') b0 GROUP BY Merkez) x
       ORDER BY x.T DESC
       FOR XML PATH(''''), TYPE).value(''.'',''nvarchar(max)''), 1, 2, N'''');';
EXEC sp_executesql @colSql,
     N'@sirket int,@ayBas int,@ay int,@cols nvarchar(max) OUTPUT',
     @sirket, @ayBas, @ay, @cols OUTPUT;
IF @cols IS NULL SET @cols = N'CAST(NULL AS decimal(18,2)) AS [veri yok]';

-- 2) Pivot: satır = hesap detay (grup altında sıralı) · sütun = gider merkezi.
DECLARE @sql nvarchar(max) = N'
    SELECT src.Grup, src.Hesap, ' + @cols + N', SUM(src.Gider) AS Toplam
    FROM (' + @base + N') src
    GROUP BY src.Grup, src.Hesap, src.HspKod
    ORDER BY src.HspKod;';
EXEC sp_executesql @sql,
     N'@sirket int,@ayBas int,@ay int',
     @sirket, @ayBas, @ay;

/* ============================================================================
   ERP-NATIVE TEYİT (2026-08-06) — gider tanımı + fisGdrMerkez köprüsü çapraz-doğrulandı:
   1. Resmi 'Gider Merkezi Dağılımlı Mizan' (Haziran.26 xlsx) ↔ bağımsız pyodbc:
      grand total + 109 hesap + 19 merkez + 365/365 hücre = 0 sapma (kuruşuna).
   2. mhs.mhsGelirTabloGiderMerkeziDetayli (decrypted SP): INNER JOIN frm ON frmID=fisGdrMerkez
      — aynı köprü. NOT: bu SP 6xx-only (aHspID LIKE '6%'), 7xx YOK → BKM 7/A'da opex'i göstermez
      (dönem kârı opex-siz şişkin). Benim mizanım 7xx işletme giderini bu boşlukta gösterir.
   3. dbo.kontrol_masrafmerkezibosolan6li_vw / 7li_vw: hspAnaID LIKE '6%'/'7%' + fisGdrMerkez=0
      → ERP'nin 'gider merkezi atanmamış satır' kontrolü = %69 GENEL bulgusunun ERP-native karşılığı.
   4. Köprü posMagaza.mekanGiderMerkez→frm: FSM→GFsm · Özlüce→GOzl · İst→GIst (mağaza-bazlı atama).
   ============================================================================ */
