using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Kadro / Sezon Personeli paneli — plan-38. SALT-OKUMA (erp-write-policy.md: Zirve'ye yazma YASAK).
/// Çekirdek sorgular <c>sorgular/2026-09-02-sezon-personel-kohort-magaza.sql</c> ve
/// <c>sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql</c> (canlı doğrulanmış); bu sınıf dashboard
/// EMITTER'ıdır — iş mantığı çoğaltılmaz (emitter-ayrimi.md).
///
/// ZORUNLU KURALLAR (02.09.2026 keşif dersleri):
/// • <b>Sezon personeli = <c>Kadro='SEZONLUK'</c></b> (Zirve'nin kendi bayrağı). Giriş-tarihi penceresi
///   TEK BAŞINA ayraç DEĞİL: aynı pencerede kadrolu alım da var, ölçüm sessizce bozulur
///   (karışık %83,2 vs sezonluk %91,8 vs kadrolu %75,5 — 14 gün tutunma).
/// • <b>AKTİF = <c>Ict IS NULL</c></b>, <c>Personeldurumu</c> DEĞİL (o alan tarihçe içerir).
/// • <b>MUTABAKAT REFERANSI: <c>Zirve dbo.sp_PersonelKarsilastirma_Ozet</c></b> (İK'nın kurumsal raporu).
///   Konvansiyonu birebir alınır: as-of aktif = <c>Igt &lt;= T AND (Ict IS NULL OR Ict &gt;= T)</c>,
///   kıyas = seçilen tarih vs <c>DATEADD(YEAR,-1,...)</c>. SP tüm lokasyonu tek kırılımda verir
///   (Lokasyon+AltLokasyon+AltAltLokasyon, kadro tipi ayırmaz); bu panel ek olarak sezonluk/kadrolu/
///   engelli/etkinlik ayrımı ve taban→kesim akışı getirir. Doğrulama (31.08.2026 · tüm lokasyon):
///   SP 322 → 335 (+13); aynı formülle bu sınıf da 322 → 335.
/// • <b>As-of sayım</b>: <c>Igt &lt;= T AND (Ict IS NULL OR Ict &gt;= T)</c> — bugünkü snapshot DEĞİL, tarihe dönerek sayım.
/// • <b>"Bugün aktif" yıllar arası KIYASLANAMAZ</b> (censoring): cari yıl kohortu Eylül tahliyesini
///   görmemiştir. Panel bu yüzden TABAN + KESİM modeli kurar; ham "aktif" tek başına gösterilmez.
/// • <b>Engelli ayracı</b> <c>perbilgi.Kanun='14857'</c> (4857/30 teşviki) VEYA <c>Ozurlulukkodu='E'</c>
///   (teşviksiz engelli izi). ALT SINIR: teşviksiz engelli güncel doldurulmuyor. KVKK m.6 özel
///   nitelikli → panelde yalnız ŞUBE toplamı; reyon/isim/ücret YOK.
/// • <b>perbilgi JOIN</b>: <c>vw_PersonelDepartman.Personelno</c> ('179-BKM') string, <c>perbilgi.Personelno</c>
///   INT → doğrudan join conversion error. Parse + <c>LIKE '%-BKM'</c> firma daraltması ZORUNLU
///   (yoksa numara çakışması fan-out). perbilgi yalnız BKM_GENEL firmasını tutar.
/// • <b>Zirve SQL 2008</b>: <c>TRY_CONVERT</c>/<c>IIF</c>/<c>STRING_AGG</c> YOK. Tarihler ISO literal
///   ('20260831') — Zirve bağlantısında <c>SET DATEFORMAT</c> uygulanmaz.
/// • <b>İş hacmi</b> EncoreMerkez'den (<c>Db.OpenAsync</c>, 3-parçalı isim ZORUNLU — varsayılan katalog
///   master). Perakende fiş = <c>DocumentsTypeId=1</c>, satır <c>IsValid=1</c>, KDV-hariç =
///   <c>TotalPrice - VatTotal</c>. Ürün adedi enflasyondan bağımsız → kadro kıyasında birincil ölçüt.
/// </summary>
public sealed class KadroQueries(Db db)
{
    /// <summary>Engelli bayrağı (teşvikli VEYA teşviksiz iz). perbilgi LEFT JOIN ile gelir.</summary>
    private const string EngelliKosul = """
        (LTRIM(RTRIM(CAST(p.Kanun AS nvarchar(20)))) = '14857'
         OR LTRIM(RTRIM(CAST(p.Ozurlulukkodu AS nvarchar(10)))) = 'E')
        """;

    /// <summary>vw_PersonelDepartman → perbilgi join (parse + firma daraltması). Fan-out önlemi.</summary>
    private const string PerbilgiJoin = """
        LEFT JOIN dbo.perbilgi p
               ON p.Personelno = CASE WHEN CHARINDEX('-', v.Personelno) > 1
                                       AND ISNUMERIC(LEFT(v.Personelno, CHARINDEX('-', v.Personelno) - 1)) = 1
                                      THEN CONVERT(int, LEFT(v.Personelno, CHARINDEX('-', v.Personelno) - 1)) END
              AND v.Personelno LIKE '%-BKM'
        """;

    /// <summary>
    /// As-of aktif sayım — <b>Zirve İK raporuyla (sp_PersonelKarsilastirma_Ozet) BİREBİR aynı konvansiyon</b>:
    /// <c>Ict &gt;= T</c> (çıkış tarihi kesim günü olan kişi O GÜN ÇALIŞMIŞTIR, sayılır).
    /// ⚠ <c>Ict &gt; T</c> yazılırsa kurumsal rapordan düşük çıkar (02.09.2026 mutabakat: 31.08.2026
    /// tüm lokasyon 335 vs 330; mağazalarda kadrolu 150 vs 148). SP referanstır, sapma YASAK.
    /// </summary>
    private static string AsOf(string tarih) =>
        $"v.Igt <= '{tarih}' AND (v.Ict IS NULL OR v.Ict >= '{tarih}')";

    /// <summary>ISO literal (Zirve SQL2008 — parametre yerine güvenli literal; girdi DateOnly, injection yok).</summary>
    private static string Iso(DateOnly d) => d.ToString("yyyyMMdd");

    /// <summary>
    /// Şube × grup kadro sayımı. Gruplar birbirini KESMEZ: sezonluk → engelli → etkinlik → diğer kadrolu.
    /// <paramref name="taban"/> sezon-öncesi kesim (ör. 30.06), <paramref name="kesim"/> ölçüm günü (ör. 31.08).
    /// Her ikisi cari yıl; önceki yıl aynı takvim gününden otomatik türetilir (adil kıyas).
    /// </summary>
    public async Task<IReadOnlyList<KadroSubeGrup>> GetSubeGrupAsync(DateOnly taban, DateOnly kesim, bool yalnizMagaza = true)
    {
        var tabanO = Iso(taban.AddYears(-1));
        var tabanC = Iso(taban);
        var kesimO = Iso(kesim.AddYears(-1));
        var kesimC = Iso(kesim);
        var magazaFiltre = yalnizMagaza ? "WHERE v.Lokasyon LIKE 'MA%'" : "";

        var sql = $"""
            SELECT ISNULL(v.AltLokasyon, '(tanımsız)') AS Sube,
                   CASE WHEN v.Kadro = 'SEZONLUK' THEN 'SEZONLUK'
                        WHEN {EngelliKosul} THEN 'ENGELLI'
                        WHEN v.Departman = N'ETKİNLİK' THEN 'ETKINLIK'
                        ELSE 'DIGER KADROLU' END AS Grup,
                   SUM(CASE WHEN {AsOf(tabanO)} THEN 1 ELSE 0 END) AS TabanOnceki,
                   SUM(CASE WHEN {AsOf(tabanC)} THEN 1 ELSE 0 END) AS TabanCari,
                   SUM(CASE WHEN {AsOf(kesimO)} THEN 1 ELSE 0 END) AS KesimOnceki,
                   SUM(CASE WHEN {AsOf(kesimC)} THEN 1 ELSE 0 END) AS KesimCari
            FROM dbo.vw_PersonelDepartman v
            {PerbilgiJoin}
            {magazaFiltre}
            GROUP BY v.AltLokasyon,
                     CASE WHEN v.Kadro = 'SEZONLUK' THEN 'SEZONLUK'
                          WHEN {EngelliKosul} THEN 'ENGELLI'
                          WHEN v.Departman = N'ETKİNLİK' THEN 'ETKINLIK'
                          ELSE 'DIGER KADROLU' END
            HAVING SUM(CASE WHEN {AsOf(kesimO)} THEN 1 ELSE 0 END)
                 + SUM(CASE WHEN {AsOf(kesimC)} THEN 1 ELSE 0 END)
                 + SUM(CASE WHEN {AsOf(tabanO)} THEN 1 ELSE 0 END)
                 + SUM(CASE WHEN {AsOf(tabanC)} THEN 1 ELSE 0 END) > 0
            ORDER BY 1, 2
            """;

        await using var conn = await db.OpenZirveAsync();
        return (await conn.QueryAsync<KadroSubeGrup>(sql)).ToList();
    }

    /// <summary>Kesim özeti (sezonluk / kadrolu / taban) — şube kırılımından bağımsız tek satır.</summary>
    public async Task<KadroOzet> GetOzetAsync(DateOnly taban, DateOnly kesim, bool yalnizMagaza = true)
    {
        var tabanO = Iso(taban.AddYears(-1));
        var tabanC = Iso(taban);
        var kesimO = Iso(kesim.AddYears(-1));
        var kesimC = Iso(kesim);
        var magazaFiltre = yalnizMagaza ? "WHERE v.Lokasyon LIKE 'MA%'" : "";
        const string Sez = "v.Kadro = 'SEZONLUK'";
        const string Kad = "ISNULL(v.Kadro, 'X') <> 'SEZONLUK'";

        var sql = $"""
            SELECT SUM(CASE WHEN {Kad} AND {AsOf(tabanO)} THEN 1 ELSE 0 END) AS TabanKadroluOnceki,
                   SUM(CASE WHEN {Kad} AND {AsOf(tabanC)} THEN 1 ELSE 0 END) AS TabanKadroluCari,
                   SUM(CASE WHEN {Sez} AND {AsOf(kesimO)} THEN 1 ELSE 0 END) AS KesimSezonlukOnceki,
                   SUM(CASE WHEN {Sez} AND {AsOf(kesimC)} THEN 1 ELSE 0 END) AS KesimSezonlukCari,
                   SUM(CASE WHEN {Kad} AND {AsOf(kesimO)} THEN 1 ELSE 0 END) AS KesimKadroluOnceki,
                   SUM(CASE WHEN {Kad} AND {AsOf(kesimC)} THEN 1 ELSE 0 END) AS KesimKadroluCari
            FROM dbo.vw_PersonelDepartman v
            {magazaFiltre}
            """;

        await using var conn = await db.OpenZirveAsync();
        return await conn.QuerySingleAsync<KadroOzet>(sql);
    }

    /// <summary>
    /// Kohort tutunma (eşit kıdem). Kohort = <c>Kadro</c> segmenti + giriş [sezon başı .. kesim].
    /// Risk kümesi h gün için: <c>Igt &lt;= kesim - h</c> → iki yıl aynı takvim penceresinde kıyaslanır.
    /// </summary>
    public async Task<IReadOnlyList<KadroTutunma>> GetTutunmaAsync(DateOnly sezonBasi, DateOnly kesim, bool yalnizMagaza = true)
    {
        var magazaFiltre = yalnizMagaza ? "AND v.Lokasyon LIKE 'MA%'" : "";
        var satirlar = new List<KadroTutunma>();
        await using var conn = await db.OpenZirveAsync();

        foreach (var yilFark in new[] { -1, 0 })
        {
            var bas = Iso(sezonBasi.AddYears(yilFark));
            var son = Iso(kesim.AddYears(yilFark));
            var r14 = Iso(kesim.AddYears(yilFark).AddDays(-14));
            var r30 = Iso(kesim.AddYears(yilFark).AddDays(-30));
            var yil = kesim.AddYears(yilFark).Year;

            var sql = $"""
                SELECT CASE WHEN v.Kadro = 'SEZONLUK' THEN 'SEZONLUK' ELSE 'KADROLU' END AS Segment,
                       {yil} AS Yil,
                       COUNT(*) AS Alinan,
                       SUM(CASE WHEN v.Ict IS NOT NULL AND v.Ict < '{son}' THEN 1 ELSE 0 END) AS KesimeKadarAyrilan,
                       SUM(CASE WHEN v.Igt <= '{r14}' THEN 1 ELSE 0 END) AS Risk14,
                       SUM(CASE WHEN v.Igt <= '{r14}' AND (v.Ict IS NULL OR DATEDIFF(DAY, v.Igt, v.Ict) >= 14) THEN 1 ELSE 0 END) AS Kalan14,
                       SUM(CASE WHEN v.Igt <= '{r30}' THEN 1 ELSE 0 END) AS Risk30,
                       SUM(CASE WHEN v.Igt <= '{r30}' AND (v.Ict IS NULL OR DATEDIFF(DAY, v.Igt, v.Ict) >= 30) THEN 1 ELSE 0 END) AS Kalan30
                FROM dbo.vw_PersonelDepartman v
                WHERE v.Igt >= '{bas}' AND v.Igt <= '{son}' {magazaFiltre}
                GROUP BY CASE WHEN v.Kadro = 'SEZONLUK' THEN 'SEZONLUK' ELSE 'KADROLU' END
                """;
            satirlar.AddRange(await conn.QueryAsync<KadroTutunma>(sql));
        }
        return satirlar;
    }

    /// <summary>
    /// Mağaza iş hacmi — <b>DerinSIS `irs`/`irsAyr`, eTip=100 (POS satışı)</b>. Pencere [sezon başı .. kesim],
    /// iki yıl aynı takvim günü. <b>Sınav Okulları + Sınav Kıyafet AYIKLANIR</b> (aksi halde İst. Yolu
    /// cirosunun %77'si Sınav'dan gelir → mağaza iş yükü ölçülmez).
    ///
    /// ⚠ NEDEN EncoreMerkez DEĞİL: POS sistemi Temmuz 2025'te değişti (ENPOS/INTER_BOS → EncoreMerkez).
    /// EncoreMerkez'de 2025 Ocak–Haziran verisi YOK, Temmuz 2025 kısmi (ilk fiş: İst. Yolu 11.07, Özlüce
    /// 21.07, FSM 23.07). O kaynakla YoY ölçülürse adet +%67 / ciro +%97 çıkar — ARTEFAKT.
    /// DerinSIS kesintisiz: doğrusu adet +%16,9 / ciro +%44,1 (Tem+Ağu 2025→2026, Sınav hariç).
    /// Kural: `sema/metrics.yaml → pos_sistem_gecisi_2025`.
    ///
    /// ⚠ FİŞ SAYISI DerinSIS'ten ALINAMAZ: eTip 100 günlük aggregate'tir (bir gün = bir belge, 2.608 satır).
    /// Bu yüzden ölçü KALEM (satır) + ADET + NET CİRO. Fiş adedi gerekiyorsa Ağustos-2025 ve sonrası için
    /// EncoreMerkez kullanılır (öncesi eksik).
    ///
    /// Mekan eşlemesi: 1=FSM · 4477=Özlüce · 4478=İst. Yolu (EncoreMerkez StoresId ile FARKLI).
    /// Net ciro KDV-hariç = `ehTutar - ehIndirim`. Adet `ABS(ehAdet)` (satış çıkış → negatif).
    /// </summary>
    public async Task<IReadOnlyList<KadroIsHacmi>> GetIsHacmiAsync(DateOnly sezonBasi, DateOnly kesim)
    {
        var basO = Iso(sezonBasi.AddYears(-1));
        var sonO = Iso(kesim.AddYears(-1).AddDays(1));
        var basC = Iso(sezonBasi);
        var sonC = Iso(kesim.AddDays(1));

        var sql = $"""
            SELECT bs.eMekan AS StoresId,
                   MAX(mk.mekanAd) AS Magaza,
                   0 AS FisOnceki,
                   0 AS FisCari,
                   SUM(CASE WHEN bs.eTarihS >= '{basO}' AND bs.eTarihS < '{sonO}' THEN 1 ELSE 0 END) AS KalemOnceki,
                   SUM(CASE WHEN bs.eTarihS >= '{basC}' AND bs.eTarihS < '{sonC}' THEN 1 ELSE 0 END) AS KalemCari,
                   SUM(CASE WHEN bs.eTarihS >= '{basO}' AND bs.eTarihS < '{sonO}' THEN ABS(dt.ehAdet) ELSE 0 END) AS AdetOnceki,
                   SUM(CASE WHEN bs.eTarihS >= '{basC}' AND bs.eTarihS < '{sonC}' THEN ABS(dt.ehAdet) ELSE 0 END) AS AdetCari,
                   SUM(CASE WHEN bs.eTarihS >= '{basO}' AND bs.eTarihS < '{sonO}' THEN dt.ehTutar - dt.ehIndirim ELSE 0 END) AS NetOnceki,
                   SUM(CASE WHEN bs.eTarihS >= '{basC}' AND bs.eTarihS < '{sonC}' THEN dt.ehTutar - dt.ehIndirim ELSE 0 END) AS NetCari
            FROM DerinSISBkm.dbo.irs bs WITH(NOLOCK)
            INNER JOIN DerinSISBkm.dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
            LEFT JOIN DerinSISBkm.bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
            LEFT JOIN DerinSISBkm.dbo.mekan_vw mk WITH(NOLOCK) ON mk.mekanID = bs.eMekan
            WHERE bs.eTip = 100
              AND bs.eMekan IN (1, 4477, 4478)
              AND ((bs.eTarihS >= '{basO}' AND bs.eTarihS < '{sonO}')
                OR (bs.eTarihS >= '{basC}' AND bs.eTarihS < '{sonC}'))
              AND COALESCE(kat.Kategori3, N'(Tanimsiz)') NOT IN (N'Sınav Okulları', N'Sınav Kıyafet')
            GROUP BY bs.eMekan
            ORDER BY bs.eMekan
            """;

        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<KadroIsHacmi>(sql)).ToList();
    }
}
