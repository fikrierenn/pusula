using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// plan-34 B-145 — FİYAT SAPMASI: aynı ürünü farklı tedarikçiden farklı birim fiyata almak.
/// Hesap-sorma eksenlerinin EN TEMİZİ: karar tamamen alıcının kontrolünde (hangi tedarikçiden, ne fiyata),
/// confound az (piyasa artışı aynı dönemde tüm tedarikçileri etkiler → aynı-ay kıyası bunu büyük ölçüde eler).
/// Kanıt vakası: Harry Potter kalemi — BUDAK 226,11 ₺ vs PROMARKA 233,10 ₺ (%3).
/// Salt-okuma (erp-write-policy) · 3-parçalı DerinSISBkm isim (master katalog, Err 208).
/// </summary>
public sealed partial class SatinalmaQueries
{
    /// <summary>
    /// Son N ayda ≥2 tedarikçiden alınan ürünlerde birim-fiyat farkı + fazla ödenen tutar.
    /// PERF: tek GROUP BY + ROW_NUMBER (satır-başı korelasyonlu alt-sorgu YOK — 24,9s dersi, 2026-08-18).
    /// ADALET: (a) bedava/0-tutarlı satır hariç (birim fiyatı yapay düşürür), (b) tedarikçi başına min adet eşiği
    /// (tek-adetlik numune fiyatı kıyasa girmez), (c) fazla-ödenen = en ucuza göre, yalnız pozitif fark.
    /// </summary>
    public async Task<IReadOnlyList<FiyatSapmaRow>> GetFiyatSapmaAsync(string ay0, int aySayisi = 12, int minAdet = 6)
    {
        const string sql = """
            SET NOCOUNT ON;
            DECLARE @d0 date = CONVERT(date,@AY0);
            DECLARE @BAS char(8)=CONVERT(char(8),DATEADD(month,-@AYSAYI,@d0),112);
            DECLARE @SON char(8)=CONVERT(char(8),DATEADD(month,1,@d0),112);

            -- Ürün × tedarikçi birim fiyatı (alış faturası = fiyatın kanonik kaynağı; iptal eDurum=2 hariç).
            IF OBJECT_ID('tempdb..#tf') IS NOT NULL DROP TABLE #tf;
            SELECT fa.ehstkID AS stkID, f.eFirma,
                   CONVERT(int, SUM(fa.ehAdetN))                                        AS adet,
                   CONVERT(decimal(18,4), SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0))   AS birim,
                   MAX(f.eTarihS)                                                       AS son_tarih
            INTO #tf
            FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON f.eID = fa.ehID
            JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = fa.ehstkID AND u.Kat3ID IN (10,12,16)
            WHERE f.eTip = 0 AND f.eDurum <> 2
              AND fa.ehAdetN > 0 AND fa.ehTutarN > 0          -- bedava/0-tutarlı satır kıyasa girmez
              AND f.eTarihS >= @BAS AND f.eTarihS < @SON
            GROUP BY fa.ehstkID, f.eFirma
            HAVING SUM(fa.ehAdetN) >= @MINADET                -- numune/tek-adet fiyatı kıyasa girmez
               AND SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0) >= 1.0;   -- birim <1 ₺ = adet/tutar karşılığı yok
               -- (jenerik 'Muhtelif' SKU, paket/bundle satırı) → yüzdeyi patlatır, alıcı suçlanamaz.
            CREATE CLUSTERED INDEX ix ON #tf(stkID);

            -- Ürün bazında en ucuz / en pahalı tedarikçi + toplam fazla ödenen.
            IF OBJECT_ID('tempdb..#ozet') IS NOT NULL DROP TABLE #ozet;
            SELECT stkID,
                   COUNT(*)                     AS ted_sayi,
                   CONVERT(int, SUM(adet))       AS toplam_adet,
                   MIN(birim)                    AS en_az,
                   MAX(birim)                    AS en_cok
            INTO #ozet
            FROM #tf GROUP BY stkID HAVING COUNT(*) >= 2;

            -- Fazla ödenen: en_az bir JOIN kolonu olarak gelir. (CROSS APPLY içinde SUM((t.birim - o.en_az)*t.adet)
            -- YASAK: "toplanmış deyimde dış başvuru + birden çok sütun" hatası — aggregate-outer-reference kısıtı.)
            IF OBJECT_ID('tempdb..#fz') IS NOT NULL DROP TABLE #fz;
            SELECT t.stkID, CONVERT(decimal(18,2), SUM((t.birim - o.en_az) * t.adet)) AS fazla
            INTO #fz
            FROM #tf t JOIN #ozet o ON o.stkID = t.stkID
            GROUP BY t.stkID;

            SELECT o.stkID                                                       AS UrunKodu,
                   u.stkAd                                                       AS UrunAd,
                   u.Kategori3                                                   AS Kategori,
                   u.mrkAd                                                       AS Marka,
                   o.ted_sayi                                                    AS TedarikciSayi,
                   o.toplam_adet                                                 AS ToplamAdet,
                   CONVERT(decimal(18,2), o.en_az)                               AS EnAzBirim,
                   CONVERT(decimal(18,2), o.en_cok)                              AS EnCokBirim,
                   CONVERT(decimal(12,1), 100.0*(o.en_cok-o.en_az)/NULLIF(o.en_az,0)) AS FarkPct,   -- (6,1) TAŞTI: uç fark %99999'u aşabiliyor
                   CONVERT(decimal(18,0), fz.fazla)                              AS FazlaOdenen,
                   ISNULL(fa1.frmAd, '—')                                        AS EnAzTedarikci,
                   ISNULL(fa2.frmAd, '—')                                        AS EnCokTedarikci,
                   CONVERT(varchar(10), fa2.son_tarih, 104)                      AS EnCokSonTarih,
                   -- ÖLÇEK ŞÜPHESİ: en pahalı/en ucuz > 10× ise aynı satılabilir birim DEĞİL (paket/koli/bundle farkı)
                   -- → ana listeden ayrılır, sayısı şeffaf gösterilir (sessiz kırpma yasak).
                   CONVERT(bit, CASE WHEN o.en_az > 0 AND o.en_cok/o.en_az > 10 THEN 1 ELSE 0 END) AS OlcekSuphesi,
                   -- İLİŞKİLİ TARAF: kıyasın uçlarından biri grup-içi şirketse fark 'alıcı hatası' DEĞİL,
                   -- transfer fiyatlaması konusudur (frm 9525 ODAK-POINT alımın ~%40'ı — 2026-08-18 teyidi).
                   CONVERT(bit, CASE WHEN fa1.eFirma IN @ILISKILI OR fa2.eFirma IN @ILISKILI THEN 1 ELSE 0 END) AS IliskiliTaraf
            FROM #ozet o
            JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = o.stkID
            LEFT JOIN #fz fz ON fz.stkID = o.stkID
            OUTER APPLY (SELECT TOP 1 fr.frmAd, t.eFirma FROM #tf t
                         LEFT JOIN DerinSISBkm.dbo.frm fr WITH(NOLOCK) ON fr.frmID = t.eFirma
                         WHERE t.stkID = o.stkID ORDER BY t.birim ASC) fa1
            OUTER APPLY (SELECT TOP 1 fr.frmAd, t.son_tarih, t.eFirma FROM #tf t
                         LEFT JOIN DerinSISBkm.dbo.frm fr WITH(NOLOCK) ON fr.frmID = t.eFirma
                         WHERE t.stkID = o.stkID ORDER BY t.birim DESC) fa2
            WHERE 100.0*(o.en_cok-o.en_az)/NULLIF(o.en_az,0) >= 1.0     -- %1 altı gürültü
            ORDER BY fz.fazla DESC;
            """;
        var p = new DynamicParameters();
        p.Add("AY0", ay0);
        p.Add("AYSAYI", aySayisi);
        p.Add("MINADET", minAdet);
        p.Add("ILISKILI", ayar.Deger.IliskiliTarafIds);
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<FiyatSapmaRow>(new CommandDefinition(sql, p, commandTimeout: 90))).ToList();
        logger.LogInformation("Fiyat sapması: {N} ürün (≥2 tedarikçi, {Ay} ay, min {Adet} adet)", rows.Count, aySayisi, minAdet);
        return rows;
    }
}
