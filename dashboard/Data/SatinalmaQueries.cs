using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Satınalma raporları veri erişimi (emitter-ayrımı). <c>partial</c> — her rapor kendi metod+SQL dosyasında
/// (bu dosya = Hesap-Sorma; yeni rapor → SatinalmaQueries.Xxx.cs kısmi + GetXxxAsync). Ortak: Db.OpenAsync
/// salt-okuma (erp-write-policy), 3-parçalı DerinSISBkm isim (master katalog Err 208; conventions 23.06).
///
/// Hesap-Sorma çekirdeği = sorgular/2026-08-12-satinalma-hesap-DINAMIK.sql (Python emitter ile doğrulandı).
/// Aynı SQL Dapper ile: @AY0 tek param, türev tarihler DATEADD. FARK: e-ticaret satışı HARİÇ (şube-only) —
/// OPENQUERY linked-server 18,5s perf sorunu (kullanıcı kararı, e-tic ayrı incelenecek).
/// </summary>
public sealed partial class SatinalmaQueries(Db db, ILogger<SatinalmaQueries> logger, AyarService ayar)
{
    // Alım Analizi eşikleri Ayarlar sayfasından (hardcode değil) + SABİT sezon pencereleri → SQL Dapper param'ı.
    DynamicParameters BaseParams(string ay0)
    {
        var p = new DynamicParameters();
        p.Add("AY0", ay0);
        p.Add("ESIK", ayar.Deger.SatinFazlaAy);
        p.Add("MAT", ayar.Deger.SatinMaterialite);
        p.Add("MINKOLI", ayar.Deger.SatinMinKoli);
        p.Add("MINSTOK", ayar.Deger.SatinMinStok);
        p.Add("SEZMIN", ayar.Deger.SatinSezonMinTaban);
        p.Add("RETAILCAP", ayar.Deger.SatinRetailCap);
        var sz = SatinalmaSezon.Hesapla(ay0);   // sabit sezon (kaymaz) — en yakın gelen sezonun geçen/önceki yıl penceresi
        p.Add("SEZb", sz.SEZb); p.Add("SEZe", sz.SEZe);
        p.Add("PSEZb", sz.PSEZb); p.Add("PSEZe", sz.PSEZe);
        p.Add("SEZAY", sz.AylarMM.Length);      // sezon ay sayısı (retail-momentum floor sezon-normalize)
        return p;
    }
    // Ay-bazlı sonuç cache (geçmiş ay değişmez; içinde-olunan ay TTL ile tazelenir). Static → tüm request'ler paylaşır.
    static readonly System.Collections.Concurrent.ConcurrentDictionary<string, (System.DateTime Ts, IReadOnlyList<SatinalmaAnalizSatir> Rows)> _cache = new();
    static readonly System.TimeSpan _ttl = System.TimeSpan.FromMinutes(20);

    /// <summary>Hesap-sorma: bir ayın alım kararları + FAZLA/ÖLÜ/YENİDEN-STOK değerlendirmesi. ay0='YYYYMMDD'. 20dk cache.</summary>
    public async Task<IReadOnlyList<SatinalmaAnalizSatir>> GetAnalizAsync(string ay0)
    {
        // ay0 whitelist: tam 8 hane rakam (SQL injection guard — string param olsa da savunma).
        if (ay0 is null || ay0.Length != 8 || !ay0.All(char.IsDigit))
            throw new ArgumentException("ay0 'YYYYMMDD' 8-hane olmalı", nameof(ay0));

        if (_cache.TryGetValue(ay0, out var hit) && System.DateTime.UtcNow - hit.Ts < _ttl)
            return hit.Rows;

        var sw = System.Diagnostics.Stopwatch.StartNew();
        await using var c = await db.OpenAsync();
        var p = BaseParams(ay0);
        var rows = await c.QueryAsync<SatinalmaAnalizSatir>(new CommandDefinition(AnalizSql, p, commandTimeout: 240));
        var list = rows.AsList();
        _cache[ay0] = (System.DateTime.UtcNow, list);
        logger.LogInformation("Alım Analizi {Ay}: {N} ürün, {Ms}ms (şube-only, e-tic hariç; cache'lendi)", ay0, list.Count, sw.ElapsedMilliseconds);
        return list;
    }

    // DINAMIK SQL — @AY0 DECLARE'i kaldırıldı (Dapper param), objeler 3-parçalı, final alias boşluksuz.
    private const string AnalizSql = """
        SET NOCOUNT ON;
        DECLARE @d0 date = CONVERT(date,@AY0);
        DECLARE @AY1  char(8)=CONVERT(char(8),DATEADD(month, 1,@d0),112);
        DECLARE @S12b char(8)=CONVERT(char(8),DATEADD(month,-12,@d0),112);
        DECLARE @S24b char(8)=CONVERT(char(8),DATEADD(month,-24,@d0),112);
        DECLARE @O12b char(8)=@S24b, @O12e char(8)=@S12b;
        -- @SEZb/@SEZe (geçen-yıl SABİT sezon) + @PSEZb/@PSEZe (önceki-yıl) = Dapper param (SatinalmaSezon.Hesapla).
        -- Kayan pencere DEĞİL — sabit takvim sezonu (Yaz/Okul/Ara-Tatil/Sömestr), ay0'a göre en yakın gelen.
        DECLARE @L_ay0 char(7)=CONVERT(char(7),@d0,126);
        DECLARE @L_son3 char(7)=CONVERT(char(7),DATEADD(month,-3,@d0),126);   -- retail-momentum: son 3 ay başı
        DECLARE @L_s12 char(7)=CONVERT(char(7),CONVERT(date,@S12b),126);
        DECLARE @L_s24 char(7)=CONVERT(char(7),CONVERT(date,@S24b),126);
        DECLARE @L_sezb char(7)=CONVERT(char(7),CONVERT(date,@SEZb),126);
        DECLARE @L_seze char(7)=CONVERT(char(7),CONVERT(date,@SEZe),126);
        DECLARE @L_psezb char(7)=CONVERT(char(7),CONVERT(date,@PSEZb),126);
        DECLARE @L_pseze char(7)=CONVERT(char(7),CONVERT(date,@PSEZe),126);
        -- @ESIK/@MAT/@MINKOLI/@MINSTOK/@SEZMIN = Dapper param (Ayarlar sayfası → AyarService); hardcode DEĞİL.

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
        CREATE TABLE #ay (stkID int, ay char(7), satis int, retail int, fis int);
        -- retail = her hareket @RETAILCAP'e kırpılıp toplanır (bulk tek-hareket düşer); fis = o ay distinct fiş sayısı
        -- (retail momentum SADECE çok-fişli aylardan sayılır → tek-bulk ayı 'retail' saymaz — #agg gate fis>=3).
        INSERT #ay SELECT h.ehstkID, CONVERT(char(7),h.ehTrhS,126), CONVERT(int,-SUM(h.ehAdetN)),
               CONVERT(int, SUM(CASE WHEN -h.ehAdetN > @RETAILCAP THEN @RETAILCAP ELSE -h.ehAdetN END)),
               CONVERT(int, COUNT(DISTINCT h.ehID))
        FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
        WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>=@S24b AND h.ehTrhS<@AY0
        GROUP BY h.ehstkID, CONVERT(char(7),h.ehTrhS,126);
        -- NOT: E-ticaret satışı HARİÇ (kullanıcı kararı) — sadece şube (irsHrk 1/4/100). OPENQUERY(ODAKJOKER)
        -- filtresiz 2,7M satır/18,5s perf sorunu yaptığından kaldırıldı; e-tic ayrı detayda incelenecek.
        -- (DINAMIK/Excel e-tic DAHİL → dashboard bu ölçüde küçük sapabilir; bu kategorilerde e-tic payı düşük.)
        IF OBJECT_ID('tempdb..#aylik') IS NOT NULL DROP TABLE #aylik;
        SELECT stkID, ay, SUM(satis) AS satis, SUM(retail) AS retail, SUM(fis) AS fis INTO #aylik FROM #ay GROUP BY stkID, ay;
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
           ISNULL(SUM(CASE WHEN ay>=@L_psezb AND ay<@L_pseze THEN al.satis END),0) AS gy_sezon_onc,
           ISNULL(SUM(CASE WHEN ay>=@L_s12 AND ay<@L_ay0 AND al.satis>0 THEN 1 END),0) AS satis_ay,
           ISNULL(SUM(CASE WHEN ay>=@L_son3 AND ay<@L_ay0 AND al.fis>=3 THEN al.retail END),0) AS retail_son3   -- bulk-kırpılmış + çok-fişli son 3 ay (tek-bulk ayı hariç)
        INTO #agg
        FROM #a a LEFT JOIN #aylik al ON al.stkID=a.stkID
        GROUP BY a.stkID;
        ALTER TABLE #agg ADD g float, g_kaynak varchar(10), beklenen int;
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
        -- Büyüme: (1) SEZON-özel geçen sezon÷önceki-yıl sezon (taban≥@SEZMIN); (2) yıllık SEZON-DIŞI (sezon çıkarılmış);
        -- (3) kategori. 0.3–6 kırp.
        UPDATE g SET
           g.g = CASE WHEN r.raw<0.3 THEN 0.3 WHEN r.raw>6 THEN 6 ELSE r.raw END,
           g.g_kaynak = r.kaynak
        FROM #agg g
        LEFT JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=g.stkID
        LEFT JOIN #katg kg ON kg.Kat3ID=u.Kat3ID
        CROSS APPLY (SELECT
             CASE WHEN g.gy_sezon_onc>=@SEZMIN THEN 1.0*g.gy_sezon/g.gy_sezon_onc
                  WHEN (g.onc12-g.gy_sezon_onc)>=100 THEN 1.0*(g.son12-g.gy_sezon)/NULLIF(g.onc12-g.gy_sezon_onc,0)
                  ELSE ISNULL(kg.g,1.0) END AS raw,
             CASE WHEN g.gy_sezon_onc>=@SEZMIN THEN 'sezon'
                  WHEN (g.onc12-g.gy_sezon_onc)>=100 THEN 'ürün'
                  ELSE 'kategori' END AS kaynak) r;
        -- BEKLENEN = geçen-yıl sezon × büyüme; AMA g<1 (düşüş) tabana ÇARPILMAZ (g_fc=max(1,g)). gy_sezon zaten
        -- düşmüş sayı; üstüne bir düşüş daha = çifte-ceza (tükenme döngüsündeki g_eff=1 kararıyla tutarlı).
        -- RETAIL-MOMENTUM FLOOR: beklenen, sezonluk-tabanın VE son3ay retail-velocity'nin (sezon-normalize) BÜYÜĞÜ.
        -- Sezonluk-taban anomalik düşükse (Okul'25=17) ama ürün retail satıyorsa (bulk hariç) floor kurtarır.
        -- Bulk/toptan @RETAILCAP'te kesildi → gerçek fazlayı gizlemez (over-buy'ın retail-momentum'u düşük).
        UPDATE #agg SET beklenen =
            CASE WHEN CONVERT(int, gy_sezon * CASE WHEN g<1 THEN 1.0 ELSE g END)
                    >= CONVERT(int, retail_son3/3.0*@SEZAY)
                 THEN CONVERT(int, gy_sezon * CASE WHEN g<1 THEN 1.0 ELSE g END)
                 ELSE CONVERT(int, retail_son3/3.0*@SEZAY) END;

        -- PERF: OUTER APPLY-per-ürün (2446× stokSon_vw 848K tarama) yerine set-based tek GROUP BY (IN #a).
        IF OBJECT_ID('tempdb..#sube') IS NOT NULL DROP TABLE #sube;
        SELECT ehstkID AS stkID, CONVERT(int,SUM(stok)) AS s INTO #sube
        FROM DerinSISBkm.dbo.stokSon_vw WITH(NOLOCK)
        WHERE ehMekan IN (1,4477,4478) AND ehstkID IN (SELECT stkID FROM #a) GROUP BY ehstkID;
        IF OBJECT_ID('tempdb..#depo') IS NOT NULL DROP TABLE #depo;
        SELECT stkID, CONVERT(int,SUM(Stok)) AS d INTO #depo
        FROM DerinSISBkm.depo.stok_adres_palet_vw WITH(NOLOCK)
        WHERE adrsAlanTipID IN (0,1) AND stkID IN (SELECT stkID FROM #a) GROUP BY stkID;
        IF OBJECT_ID('tempdb..#led') IS NOT NULL DROP TABLE #led;
        SELECT ehstkID AS stkID,
               SUM(CASE WHEN ehTrhS<@AY0 THEN ehAdetN ELSE 0 END) AS acilis,
               SUM(CASE WHEN ehTrhS<@AY1 THEN ehAdetN ELSE 0 END) AS kapanis
        INTO #led FROM DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
        WHERE ehTrhS<@AY1 AND ehstkID IN (SELECT stkID FROM #a) GROUP BY ehstkID;
        IF OBJECT_ID('tempdb..#stok') IS NOT NULL DROP TABLE #stok;
        SELECT a.stkID,
           CONVERT(int, ISNULL(su.s,0)+ISNULL(dp.d,0)) AS kap,
           CONVERT(int, ISNULL(l.kapanis,0)-ISNULL(l.acilis,0)) AS ay_net,
           CONVERT(int, ISNULL(su.s,0)+ISNULL(dp.d,0) - (ISNULL(l.kapanis,0)-ISNULL(l.acilis,0))) AS ac
        INTO #stok
        FROM #a a
        LEFT JOIN #sube su ON su.stkID=a.stkID
        LEFT JOIN #depo dp ON dp.stkID=a.stkID
        LEFT JOIN #led l ON l.stkID=a.stkID;

        -- PERF: 6,4M-satır StokAyBakiye'yi ürün-başı 88K× korelasyonlu taramak yerine ÖNCE #a ürünlerine
        -- filtrele (#bal, indexli) → carry-forward TOP1 tiny-tabloya seek. DonemA char(7) önden hesaplı.
        IF OBJECT_ID('tempdb..#bal') IS NOT NULL DROP TABLE #bal;
        SELECT stkID, ehMekan, CONVERT(char(7),Donem,126) AS DonemA, Stok
        INTO #bal FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
        WHERE Kaynak='irsHrk' AND stkID IN (SELECT stkID FROM #a);
        CREATE CLUSTERED INDEX ix ON #bal(stkID, ehMekan, DonemA);
        IF OBJECT_ID('tempdb..#stoklu') IS NOT NULL DROP TABLE #stoklu;
        SELECT a.stkID,
          SUM(CASE WHEN (bal.bakiye>=@MINSTOK OR ISNULL(sa.satis,0)>0) THEN 1 ELSE 0 END) AS stoklu_ay
        INTO #stoklu
        FROM #a a
        CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11)) v(n)
        CROSS APPLY (SELECT CONVERT(char(7),DATEADD(month,v.n,CONVERT(date,@S12b)),126) AS ay) m
        OUTER APPLY (SELECT SUM(x.Stok) bakiye FROM (
             SELECT b.ehMekan, (SELECT TOP 1 b2.Stok FROM #bal b2
                WHERE b2.stkID=a.stkID AND b2.ehMekan=b.ehMekan AND b2.DonemA<=m.ay
                ORDER BY b2.DonemA DESC) Stok
             FROM (SELECT DISTINCT ehMekan FROM #bal WHERE stkID=a.stkID) b) x) bal
        OUTER APPLY (SELECT satis FROM #aylik WHERE stkID=a.stkID AND ay=m.ay) sa
        GROUP BY a.stkID;

        IF OBJECT_ID('tempdb..#f') IS NOT NULL DROP TABLE #f;
        SELECT TOP 120 CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT NULL))-1) AS f INTO #f FROM sys.all_columns;   -- PERF: 120 ay (10 yıl) yeter; ötesi zaten 'tükenmez'. 1000 = 2,4M-satır window (yavaş).
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
           ISNULL(NULLIF(u.Kat2,''),ISNULL(NULLIF(u.Kat1,''),'—'))   AS Grup1,   -- ürün tipi (Silgiler/Kalemtıraşlar/...); Kat2 boşsa Kat1
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
           ag.gy_sezon_onc                                           AS GySezonOnc,
           ag.onc12                                                  AS Onc12,
           ag.beklenen                                               AS BeklenenSezon,
           ag.retail_son3                                            AS RetailSon3,
           st.kap - ag.beklenen                                      AS SezonKalan,
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
             WHEN st.kap - ag.beklenen < 0 THEN (CASE WHEN NOT(ag.son12>0 AND ag.gy_sezon>=0.5*ag.son12) AND ag.satis_ay<9 AND ag.g>=2 THEN N'🟠 TREND-HIZLI' ELSE N'🟢 AZ ALMIŞ' END)
             WHEN st.kap>0 AND ISNULL(tk.tuk_ay,999) > @ESIK THEN
                (CASE WHEN ag.g_kaynak='kategori' THEN N'🟠 İZLE (veri yok)'
                      WHEN a.alis_adet<=@MINKOLI THEN N'🟡 KÜÇÜK-ALIM'
                      WHEN CONVERT(money, CASE WHEN st.kap-ag.beklenen>0 THEN st.kap-ag.beklenen ELSE 0 END)   -- SEZONLUK donmuş: sezon-sonrası kalan × birim (linear DEĞİL)
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
