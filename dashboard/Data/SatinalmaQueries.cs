using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Satınalma raporları veri erişimi (emitter-ayrımı). <c>partial</c> — her rapor kendi metod+SQL dosyasında
/// (bu dosya = Hesap-Sorma; yeni rapor → SatinalmaQueries.Xxx.cs kısmi + GetXxxAsync). Ortak: Db.OpenAsync
/// salt-okuma (erp-write-policy), 3-parçalı DerinSISBkm isim (master katalog Err 208; conventions 23.06).
///
/// Hesap-Sorma çekirdeği = sorgular/2026-08-12-satinalma-hesap-DINAMIK.sql (Python emitter ile birebir
/// doğrulandı — Temmuz+Ağustos 0-fark). Aynı SQL Dapper ile: @AY0 tek param, türev tarihler DATEADD;
/// OPENQUERY(ODAKJOKER) linked server master'dan çözülür (katalogdan bağımsız), aynen kalır.
/// </summary>
public sealed partial class SatinalmaQueries(Db db, ILogger<SatinalmaQueries> logger)
{
    /// <summary>Hesap-sorma: bir ayın alım kararları + FAZLA/ÖLÜ/YENİDEN-STOK değerlendirmesi. ay0='YYYYMMDD'.</summary>
    public async Task<IReadOnlyList<SatinalmaHesapSatir>> GetHesapSormaAsync(string ay0)
    {
        // ay0 whitelist: tam 8 hane rakam (SQL injection guard — string param olsa da savunma).
        if (ay0 is null || ay0.Length != 8 || !ay0.All(char.IsDigit))
            throw new ArgumentException("ay0 'YYYYMMDD' 8-hane olmalı", nameof(ay0));

        await using var c = await db.OpenAsync();
        var rows = await c.QueryAsync<SatinalmaHesapSatir>(new CommandDefinition(HesapSormaSql, new { AY0 = ay0 }, commandTimeout: 240));
        return rows.AsList();
    }

    // DINAMIK SQL — @AY0 DECLARE'i kaldırıldı (Dapper param), objeler 3-parçalı, final alias boşluksuz.
    private const string HesapSormaSql = """
        SET NOCOUNT ON;
        DECLARE @d0 date = CONVERT(date,@AY0);
        DECLARE @AY1  char(8)=CONVERT(char(8),DATEADD(month, 1,@d0),112);
        DECLARE @S12b char(8)=CONVERT(char(8),DATEADD(month,-12,@d0),112);
        DECLARE @S24b char(8)=CONVERT(char(8),DATEADD(month,-24,@d0),112);
        DECLARE @O12b char(8)=@S24b, @O12e char(8)=@S12b;
        DECLARE @SEZb char(8)=CONVERT(char(8),DATEADD(month,-11,@d0),112);
        DECLARE @SEZe char(8)=CONVERT(char(8),DATEADD(month, -8,@d0),112);
        DECLARE @PSEZb char(8)=CONVERT(char(8),DATEADD(month,-12,CONVERT(date,@SEZb)),112);
        DECLARE @PSEZe char(8)=CONVERT(char(8),DATEADD(month,-12,CONVERT(date,@SEZe)),112);
        DECLARE @L_ay0 char(7)=CONVERT(char(7),@d0,126);
        DECLARE @L_s12 char(7)=CONVERT(char(7),CONVERT(date,@S12b),126);
        DECLARE @L_s24 char(7)=CONVERT(char(7),CONVERT(date,@S24b),126);
        DECLARE @L_sezb char(7)=CONVERT(char(7),CONVERT(date,@SEZb),126);
        DECLARE @L_seze char(7)=CONVERT(char(7),CONVERT(date,@SEZe),126);
        DECLARE @ESIK int=12, @MAT int=5000, @MINKOLI int=24;

        IF OBJECT_ID('tempdb..#a') IS NOT NULL DROP TABLE #a;
        SELECT h.ehstkID AS stkID, CONVERT(int,SUM(h.ehAdetN)) AS alis_adet, CONVERT(money,SUM(h.ehTutarN)) AS alis_tutar
        INTO #a
        FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
        JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=h.ehstkID AND u.Kat3ID IN (10,12,16)
        WHERE h.ehTip IN (0,10) AND h.ehTrhS>=@AY0 AND h.ehTrhS<@AY1 AND h.ehAdetN>0
        GROUP BY h.ehstkID;
        CREATE UNIQUE CLUSTERED INDEX ix ON #a(stkID);

        IF OBJECT_ID('tempdb..#ilk') IS NOT NULL DROP TABLE #ilk;
        SELECT h.ehstkID AS stkID, MIN(h.ehTrhS) AS ilk_giris
        INTO #ilk FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
        WHERE h.ehTip IN (0,10,13,16,99) AND h.ehTrhS<@AY1 GROUP BY h.ehstkID;

        IF OBJECT_ID('tempdb..#ay') IS NOT NULL DROP TABLE #ay;
        CREATE TABLE #ay (stkID int, ay char(7), satis int);
        INSERT #ay SELECT h.ehstkID, CONVERT(char(7),h.ehTrhS,126), CONVERT(int,-SUM(h.ehAdetN))
        FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
        WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>=@S24b AND h.ehTrhS<@AY0
        GROUP BY h.ehstkID, CONVERT(char(7),h.ehTrhS,126);
        INSERT #ay SELECT x.stkID, x.ay, CONVERT(int,x.qty)
        FROM OPENQUERY(ODAKJOKER,'
            SELECT i.DERINSIS_ID stkID, CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2) ay, SUM(d.QUANTITY) qty
            FROM JOKER.dbo.J_ORDER_DETAILS d JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
            WHERE o.ORDERDATE>=''20230101'' AND o.ORDERDATE<''20270101'' AND i.DERINSIS_ID>0 AND d.STATUS NOT IN (2004,2005,2010)
            GROUP BY i.DERINSIS_ID, CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2)') x
        JOIN #a ON #a.stkID=x.stkID
        WHERE x.ay>=@L_s24 AND x.ay<@L_ay0;
        IF OBJECT_ID('tempdb..#aylik') IS NOT NULL DROP TABLE #aylik;
        SELECT stkID, ay, SUM(satis) AS satis INTO #aylik FROM #ay GROUP BY stkID, ay;
        CREATE CLUSTERED INDEX ix ON #aylik(stkID, ay);

        IF OBJECT_ID('tempdb..#shape') IS NOT NULL DROP TABLE #shape;
        SELECT s.stkID, m.idx, ISNULL(a.satis,0) AS val
        INTO #shape
        FROM (SELECT stkID FROM #a) s
        CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11)) m(idx)
        LEFT JOIN #aylik a ON a.stkID=s.stkID AND a.ay=CONVERT(char(7),DATEADD(month,m.idx,CONVERT(date,@S12b)),126);
        CREATE CLUSTERED INDEX ix ON #shape(stkID, idx);

        IF OBJECT_ID('tempdb..#agg') IS NOT NULL DROP TABLE #agg;
        SELECT a.stkID,
           ISNULL(SUM(CASE WHEN ay>=@L_s12 AND ay<@L_ay0 THEN al.satis END),0) AS son12,
           ISNULL(SUM(CASE WHEN ay>=@L_s24 AND ay<@L_s12 THEN al.satis END),0) AS onc12,
           ISNULL(SUM(al.satis),0) AS son24,
           ISNULL(SUM(CASE WHEN ay>=@L_sezb AND ay<@L_seze THEN al.satis END),0) AS gy_sezon,
           ISNULL(SUM(CASE WHEN ay>=@L_s12 AND ay<@L_ay0 AND al.satis>0 THEN 1 END),0) AS satis_ay
        INTO #agg
        FROM #a a LEFT JOIN #aylik al ON al.stkID=a.stkID
        GROUP BY a.stkID;
        ALTER TABLE #agg ADD g float, g_kaynak varchar(10);
        IF OBJECT_ID('tempdb..#katg') IS NOT NULL DROP TABLE #katg;
        SELECT Kat3ID, CASE WHEN raw<0.5 THEN 0.5 WHEN raw>4.0 THEN 4.0 ELSE raw END AS g
        INTO #katg
        FROM (
          SELECT u.Kat3ID,
             CASE WHEN SUM(CASE WHEN i.ehTrhS>=@PSEZb AND i.ehTrhS<@PSEZe THEN -i.ehAdetN ELSE 0 END) > 0
                  THEN 1.0*SUM(CASE WHEN i.ehTrhS>=@SEZb AND i.ehTrhS<@SEZe THEN -i.ehAdetN ELSE 0 END)
                          /SUM(CASE WHEN i.ehTrhS>=@PSEZb AND i.ehTrhS<@PSEZe THEN -i.ehAdetN ELSE 0 END)
                  ELSE 1.0 END AS raw
          FROM DerinSISBkm.dbo.irsHrk i WITH(NOLOCK) JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=i.ehstkID AND u.Kat3ID IN (10,12,16)
          WHERE i.ehTip IN (1,4,100) AND i.ehTrhS>=@PSEZb AND i.ehTrhS<@SEZe
          GROUP BY u.Kat3ID) t;
        UPDATE g SET g.g = CASE WHEN g.onc12>=100 THEN CASE WHEN 1.0*g.son12/g.onc12<0.3 THEN 0.3 WHEN 1.0*g.son12/g.onc12>6 THEN 6 ELSE 1.0*g.son12/g.onc12 END
                                ELSE ISNULL(kg.g,1.0) END,
               g.g_kaynak = CASE WHEN g.onc12>=100 THEN 'ürün' ELSE 'kategori' END
        FROM #agg g
        LEFT JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=g.stkID
        LEFT JOIN #katg kg ON kg.Kat3ID=u.Kat3ID;

        IF OBJECT_ID('tempdb..#stok') IS NOT NULL DROP TABLE #stok;
        SELECT a.stkID,
           ISNULL(sube.s,0)+ISNULL(depo.d,0) AS kap,
           ISNULL(led.kapanis,0)-ISNULL(led.acilis,0) AS ay_net
        INTO #stok
        FROM #a a
        OUTER APPLY (SELECT SUM(stok) s FROM DerinSISBkm.dbo.stokSon_vw WHERE ehstkID=a.stkID AND ehMekan IN (1,4477,4478)) sube
        OUTER APPLY (SELECT SUM(Stok) d FROM DerinSISBkm.depo.stok_adres_palet_vw WHERE stkID=a.stkID AND adrsAlanTipID IN (0,1)) depo
        OUTER APPLY (SELECT SUM(CASE WHEN ehTrhS<@AY0 THEN ehAdetN ELSE 0 END) acilis,
                            SUM(CASE WHEN ehTrhS<@AY1 THEN ehAdetN ELSE 0 END) kapanis
                     FROM DerinSISBkm.dbo.irsHrk WITH(NOLOCK) WHERE ehstkID=a.stkID AND ehTrhS<@AY1) led;
        ALTER TABLE #stok ADD ac int;
        UPDATE #stok SET ac = kap - ay_net;

        IF OBJECT_ID('tempdb..#stoklu') IS NOT NULL DROP TABLE #stoklu;
        SELECT a.stkID,
          SUM(CASE WHEN (bal.bakiye>0 OR ISNULL(sa.satis,0)>0) THEN 1 ELSE 0 END) AS stoklu_ay
        INTO #stoklu
        FROM #a a
        CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11)) v(n)
        CROSS APPLY (SELECT CONVERT(char(7),DATEADD(month,v.n,CONVERT(date,@S12b)),126) AS ay) m
        OUTER APPLY (SELECT SUM(x.Stok) bakiye FROM (
             SELECT b.ehMekan, (SELECT TOP 1 b2.Stok FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b2 WITH(NOLOCK)
                WHERE b2.stkID=a.stkID AND b2.ehMekan=b.ehMekan AND b2.Kaynak='irsHrk' AND CONVERT(char(7),b2.Donem,126)<=m.ay
                ORDER BY b2.Donem DESC) Stok
             FROM (SELECT DISTINCT ehMekan FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli WITH(NOLOCK) WHERE stkID=a.stkID AND Kaynak='irsHrk') b) x) bal
        OUTER APPLY (SELECT satis FROM #aylik WHERE stkID=a.stkID AND ay=m.ay) sa
        GROUP BY a.stkID;

        IF OBJECT_ID('tempdb..#f') IS NOT NULL DROP TABLE #f;
        SELECT TOP 1000 CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT NULL))-1) AS f INTO #f FROM sys.all_columns;
        IF OBJECT_ID('tempdb..#tuk') IS NOT NULL DROP TABLE #tuk;
        ;WITH exp AS (
            SELECT sh.stkID, f.f,
               sh.val * (CASE WHEN g.g>=1 THEN 1+(g.g-1)*(CASE WHEN f.f<12 THEN 1-f.f/12.0 ELSE 0 END) ELSE 1 END) AS e
            FROM #f f JOIN #shape sh ON sh.idx=(f.f+1)%12 JOIN #agg g ON g.stkID=sh.stkID
        ), cum AS (
            SELECT stkID, f, e, SUM(e) OVER (PARTITION BY stkID ORDER BY f) AS c,
                   SUM(e) OVER (PARTITION BY stkID ORDER BY f) - e AS cb
            FROM exp
        ), gecis AS (
            SELECT c.stkID, MIN(c.f) AS f0
            FROM cum c JOIN #stok st ON st.stkID=c.stkID
            WHERE st.kap>0 AND c.c>=st.kap AND c.e>0
            GROUP BY c.stkID
        )
        SELECT g.stkID,
           CONVERT(decimal(10,1), cm.f + (st.kap - cm.cb)/cm.e) AS tuk_ay
        INTO #tuk
        FROM gecis g
        JOIN cum cm ON cm.stkID=g.stkID AND cm.f=g.f0
        JOIN #stok st ON st.stkID=g.stkID;

        IF OBJECT_ID('tempdb..#mal') IS NOT NULL DROP TABLE #mal;
        SELECT stkID, birim INTO #mal FROM (
           SELECT fa.ehstkID stkID, CONVERT(decimal(18,4),SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0)) birim,
                  ROW_NUMBER() OVER (PARTITION BY fa.ehstkID ORDER BY MAX(f.eTarih) DESC, f.eID DESC) rn
           FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK) JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
           JOIN #a ON #a.stkID=fa.ehstkID WHERE f.eTip=0 AND f.eDurum<>2 AND fa.ehAdetN>0
           GROUP BY fa.ehstkID, f.eID) t WHERE rn=1;
        INSERT #mal SELECT h.ehstkID, CONVERT(decimal(18,4),SUM(h.ehTutarN)/NULLIF(SUM(h.ehAdetN),0))
        FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
        WHERE h.ehTip=99 AND h.ehTrhS>='20210531' AND h.ehTrhS<'20210601' AND h.ehstkID NOT IN (SELECT stkID FROM #mal)
        GROUP BY h.ehstkID HAVING SUM(h.ehAdetN)<>0;

        SELECT
           a.stkID                                                   AS UrunKodu,
           u.stkAd                                                   AS UrunAd,
           u.Kategori3                                               AS Kategori,
           u.mrkAd                                                   AS Marka,
           a.alis_adet                                               AS AlisAdet,
           CONVERT(int,a.alis_tutar)                                 AS AlisTutar,
           CONVERT(decimal(18,2), ISNULL(NULLIF(m.birim,0), CASE WHEN a.alis_adet>0 THEN a.alis_tutar/a.alis_adet END)) AS BirimMaliyet,
           st.ac                                                     AS AyBasi,
           st.kap                                                    AS AySonu,
           ag.son12                                                  AS Son12,
           CONVERT(decimal(6,2),ag.g)                                AS Buyume,
           CONVERT(decimal(10,1), CASE WHEN ag.son12=0 OR st.kap<=0 THEN NULL ELSE ISNULL(tk.tuk_ay,999) END) AS TukAy,
           CONVERT(decimal(10,1), CASE WHEN ag.son12>0 THEN st.kap/(ag.son12/12.0) END) AS TukBasit,
           ag.gy_sezon                                               AS GySezon,
           CONVERT(int, ag.gy_sezon*ag.g)                            AS BeklenenSezon,
           st.kap - CONVERT(int, ag.gy_sezon*ag.g)                   AS SezonKalan,
           sl.stoklu_ay                                              AS StokluAy,
           CONVERT(decimal(10,1), CASE WHEN sl.stoklu_ay>0 THEN 1.0*ag.son12/sl.stoklu_ay END) AS AylikHiz,
           CONVERT(int, CASE WHEN ag.son12>0 THEN 100.0*ag.gy_sezon/ag.son12 ELSE 0 END) AS SezonPay,
           ag.g_kaynak                                               AS BuyumeKaynak,
           (DATEDIFF(month, ik.ilk_giris, @AY0))                     AS IlkGirisAy,
           ag.satis_ay                                               AS SatisAy,
           CASE
             WHEN DATEDIFF(month,ik.ilk_giris,@AY0) BETWEEN 0 AND 11 THEN 'GENÇ'
             WHEN ag.son24=0 THEN 'DURGUN'
             WHEN ag.son12>0 AND 1.0*ag.gy_sezon/ag.son12>=0.5 THEN 'SEZONSAL'
             WHEN ag.satis_ay>=9 THEN 'NORMAL'
             WHEN ag.g>=2 THEN 'TREND'
             WHEN ag.g<0.7 THEN 'DÜŞÜŞ'
             ELSE 'DÜZENSİZ' END                                     AS Karakter,
           CASE
             WHEN DATEDIFF(month,ik.ilk_giris,@AY0) BETWEEN 0 AND 11 THEN N'GENÇ ÜRÜN'
             WHEN ag.son12=0 AND sl.stoklu_ay>=6 THEN N'🔴 ÖLÜ-ALIM'
             WHEN ag.son12=0 THEN N'🟠 YENİDEN-STOK'
             WHEN st.kap - ag.gy_sezon*ag.g < 0 THEN (CASE WHEN NOT(ag.son12>0 AND ag.gy_sezon>=0.5*ag.son12) AND ag.satis_ay<9 AND ag.g>=2 THEN N'🟠 TREND-HIZLI' ELSE N'🟢 AZ ALMIŞ' END)
             WHEN st.kap>0 AND ISNULL(tk.tuk_ay,999) > @ESIK THEN
                (CASE WHEN ag.g_kaynak='kategori' THEN N'🟠 İZLE (veri yok)'
                      WHEN a.alis_adet<=@MINKOLI THEN N'🟡 KÜÇÜK-ALIM'
                      WHEN CONVERT(money,CASE WHEN ag.son12>0 THEN (st.kap-1.0*ag.son12/NULLIF(sl.stoklu_ay,0)*@ESIK) ELSE 0 END)
                           * ISNULL(NULLIF(m.birim,0),CASE WHEN a.alis_adet>0 THEN a.alis_tutar/a.alis_adet END) < @MAT THEN N'🟡 UZUN-KUYRUK'
                      ELSE N'🔴 FAZLA' END)
             WHEN st.kap>0 AND ISNULL(tk.tuk_ay,999) > 6 THEN N'🟠 İZLE'
             ELSE N'🟢 NORMAL' END                                    AS Degerlendirme
        FROM #a a
        JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=a.stkID
        JOIN #agg ag ON ag.stkID=a.stkID
        JOIN #stok st ON st.stkID=a.stkID
        LEFT JOIN #stoklu sl ON sl.stkID=a.stkID
        LEFT JOIN #tuk tk ON tk.stkID=a.stkID
        LEFT JOIN #ilk ik ON ik.stkID=a.stkID
        LEFT JOIN #mal m ON m.stkID=a.stkID
        ORDER BY u.Kategori3, u.stkAd;
        """;
}
