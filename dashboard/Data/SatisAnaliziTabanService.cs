using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// <c>bkm.SatisAnaliziTaban</c> ön-agrega tablosunu doldurur (plan-42).
///
/// ⚠ ERP'ye YAZAN tek yer bu servistir ve YALNIZ bu tabloya yazar
/// (.claude/rules/erp-write-policy.md — kullanıcı onayı 08-09.09.2026). Başka hiçbir tabloya
/// dokunmaz; DerinSIS native tablo yazımı MUTLAK YASAK olarak durur.
///
/// NEDEN ÖN-AGREGA — ÖLÇÜLDÜ (274.933 ürün):
///   CTE ile: sayfa çevirme 5,31-5,44 s · KPI 3,15-3,76 s · arama 5,8 s riski
///   tablodan: sayfa 17 ms · KPI 196 ms · arama 346 ms · kohort 73 ms
///   doldurma 27,3 s (kesim başına TEK SEFER; index'ler INSERT'te güncellendiği için
///   indexsiz SELECT INTO'nun 6,9 s'sinden yavaş — kabul edildi, tek seferlik).
///
/// KESİM POLİTİKASI: (Kesim, SezonYil) anahtarlı, <see cref="SaklananKesim"/> kadar kesim
/// saklanır (kullanıcı kararı: son 2-3) → tarih değiştirince bekleme olmaz.
/// </summary>
public sealed class SatisAnaliziTabanService(Db db, ILogger<SatisAnaliziTabanService> logger)
{
    public const int SaklananKesim = 3;

    /// <summary>Aynı kesim için eşzamanlı iki doldurma koşmasın (iki kullanıcı/iki sekme).</summary>
    private static readonly SemaphoreSlim Kilit = new(1, 1);

    /// <summary>O kesim için taban hazır mı (satır var mı)?</summary>
    public async Task<TabanDurum> DurumAsync(DateOnly kesim, int sezonYil, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync();
        var cmd = new CommandDefinition("""
            SELECT COUNT(*) AS Satir, MAX(Uretim) AS Uretim
            FROM DerinSISBkm.bkm.SatisAnaliziTaban
            WHERE Kesim = @kesim AND SezonYil = @sezon
            """, new { kesim = kesim.ToDateTime(TimeOnly.MinValue), sezon = (short)sezonYil },
            commandTimeout: 60, cancellationToken: ct);
        var r = await conn.QuerySingleAsync<TabanDurumRow>(cmd);
        return new TabanDurum(r.Satir > 0, r.Satir, r.Uretim);
    }

    /// <summary>
    /// Taban yoksa doldurur; varsa dokunmaz. <paramref name="zorla"/> = yeniden hesapla.
    /// Doldurma ~27 s → çağıran ekranda "hazırlanıyor" göstermeli.
    /// </summary>
    public async Task<TabanDurum> HazirlaAsync(
        DateOnly kesim, int sezonYil, bool zorla = false, CancellationToken ct = default)
    {
        var durum = await DurumAsync(kesim, sezonYil, ct);
        if (durum.Hazir && !zorla) return durum;

        await Kilit.WaitAsync(ct);
        try
        {
            // Kilit beklerken başka biri doldurmuş olabilir.
            durum = await DurumAsync(kesim, sezonYil, ct);
            if (durum.Hazir && !zorla) return durum;

            var basladi = DateTime.Now;
            await using var conn = await db.OpenAsync();
            var p = new
            {
                kesim = kesim.ToDateTime(TimeOnly.MinValue),
                bas = kesim.AddDays(-364).ToDateTime(TimeOnly.MinValue),
                sezon = (short)sezonYil,
                s1b = new DateTime(sezonYil, 8, 1),
                s2b = new DateTime(sezonYil, 9, 1),
                s3b = new DateTime(sezonYil, 10, 1),
                s3s = new DateTime(sezonYil, 10, 31),
                Kategoriler = SatisAnaliziQueries.Kategori3Evreni,
            };
            var cmd = new CommandDefinition(DoldurSql, p, commandTimeout: 900, cancellationToken: ct);
            await conn.ExecuteAsync(cmd);

            var yeni = await DurumAsync(kesim, sezonYil, ct);
            logger.LogInformation(
                "Satış Analizi tabanı doldu: kesim {Kesim} sezon {Sezon} → {Satir} satır, {Saniye:0.0}s",
                kesim, sezonYil, yeni.Satir, (DateTime.Now - basladi).TotalSeconds);

            await EskileriSilAsync(conn, ct);
            return yeni;
        }
        finally
        {
            Kilit.Release();
        }
    }

    /// <summary>Son <see cref="SaklananKesim"/> kesim dışındakileri siler (yer kontrolü).</summary>
    private async Task EskileriSilAsync(System.Data.Common.DbConnection conn, CancellationToken ct)
    {
        var cmd = new CommandDefinition($"""
            WITH kesimler AS (
                SELECT Kesim, SezonYil,
                       ROW_NUMBER() OVER (ORDER BY MAX(Uretim) DESC) AS sira
                FROM DerinSISBkm.bkm.SatisAnaliziTaban
                GROUP BY Kesim, SezonYil
            )
            DELETE t FROM DerinSISBkm.bkm.SatisAnaliziTaban t
            JOIN kesimler k ON k.Kesim = t.Kesim AND k.SezonYil = t.SezonYil
            WHERE k.sira > {SaklananKesim}
            """, commandTimeout: 300, cancellationToken: ct);
        var silinen = await conn.ExecuteAsync(cmd);
        if (silinen > 0) logger.LogInformation("Satış Analizi tabanı: {Satir} eski satır silindi", silinen);
    }

    private sealed record TabanDurumRow(int Satir, DateTime? Uretim);

    // Tanım kanıtı: sorgular/2026-09-08-satis-analizi-excel-denetim.sql §10-12.
    // Kardeş emitter scripts/satis_analizi_excel.py ile AYNI mantık — ayrışmamalı.
    private const string DoldurSql = """
        SET NOCOUNT ON;

        DELETE FROM DerinSISBkm.bkm.SatisAnaliziTaban WHERE Kesim = @kesim AND SezonYil = @sezon;

        WITH kat AS (
            SELECT u.stkID, u.Kategori3, u.stkAd, u.KatAna AS Kategori1, u.mrkAd AS Yayinevi,
                   u.Yazar, u.BarkodAna, u.SatisFiyat, u.gTarih AS AcilisTarihi
            FROM DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK)
            WHERE u.Kategori3 IN @Kategoriler
              -- GİDER/HİZMET KALEMİ DIŞLAMASI (kullanıcı 09.09.2026: "giderlere ait stoklarda
              -- olmamalı"). Sema bunu ZORUNLU kılıyordu ve panelde EKSİKTİ:
              --   sema/codes.yaml → urn.urnTip: "tüm STOK/ürün sorgularında WHERE urnTip=0
              --   ZORUNLU — gider/hizmet kalemleri aksi halde sızdı"
              --   sema/entities.yaml → 0=STOK ÜRÜNÜ · 1=gider/hizmet kalemi · 2=fatura
              --   hizmet/gelir + sabit kıymet. 1 ve 2 stok TAŞIMAZ (irsHrk'de 0 hareket).
              --   Ölçüldü 2026-09-03: 0 → 868.094 · 1 → 252 · 2 → 52 çeşit.
              -- Değişmez: mal-olmayan-kalem-stok-hareketsiz.
              AND u.urnTip = 0
              -- MUHASEBE HESAP KODU DESENİ — urnTip'in KAÇIRDIĞI sınıf (B-170, ölçüldü 10.09.2026).
              -- `stkKod` 3 hane + nokta ile başlıyorsa bu bir ürün kartı değil, muhasebe hesabı /
              -- demirbaş kartıdır: 150.xx ilk madde · 153.xx ticari mal (ALIŞ KARGO GİDERİ) ·
              -- 253/254/255 tesis-taşıt-DEMİRBAŞ (BİLGİSAYAR · KLİMA · YAZARKASA · TRANSPALET) ·
              -- 260.xx haklar (441270 "DERİNSİS MUHASEBE PROGRAMI", Akademi kategorisinde!).
              -- ÖLÇÜLDÜ: desen 58 kayıt yakalıyor (hepsi urnTip=0 — o yüzden urnTip filtresi
              -- yetmiyordu); YANLIŞ-POZİTİF SIFIR: yalnız 2'sinde hareket var (150.01 YEMEK ÜR.
              -- 22 adet, 153.10 KARGO GİDERİ 16), gerçek perakende ürünü bu deseni taşımıyor.
              -- ⚠ Naif "nokta içeriyorsa at" kuralı YANLIŞ olurdu: 339151 "İş ve Sosyal Güvenlik
              -- Mevzuatı" gerçek kitap, stkKod'u bozuk ISBN (978605300102.07) — noktası 4.
              -- karakterde DEĞİL, bu yüzden desen onu yakalamıyor. Elle stkID listesi TUTULMUYOR
              -- (semantic-layer § ŞEMA GERÇEĞİ ≠ SATIR VERİSİ); kural desen, liste değil.
              -- Koruma: degismezler.json → muhasebe-hesap-kodu-panelde-yok
              AND u.stkKod NOT LIKE '[0-9][0-9][0-9].%'
        ),
        mgz AS (   -- mağaza rafı: hareket defterinden as-of (canlı view ANLIK, geçmiş üretemez)
            SELECT h.ehstkID AS stkID,
                   SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END) AS Fsm,
                   SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END) AS Ozl,
                   SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END) AS Ist
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            GROUP BY h.ehstkID
        ),
        depo AS (  -- merkez depo = WMS raf(0)+giriş(1); ERP defteri (mekan 12) YASAK (negatifli)
            SELECT d.stkID, SUM(d.Stok) AS Merkez
            FROM DerinSISBkm.depo.stok_adres_palet_vw d WITH (NOLOCK)
            WHERE d.adrsAlanTipID IN (0, 1)
            GROUP BY d.stkID
        ),
        sat AS (
            SELECT h.ehstkID AS stkID,
                   -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END) AS Fsm,
                   -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END) AS Ozl,
                   -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END) AS Ist
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            GROUP BY h.ehstkID
        ),
        sezon AS (
            SELECT h.ehstkID AS stkID,
                   -SUM(CASE WHEN h.ehTrhS <  @s2b THEN h.ehAdetN ELSE 0 END) AS Ay1,
                   -SUM(CASE WHEN h.ehTrhS >= @s2b AND h.ehTrhS < @s3b THEN h.ehAdetN ELSE 0 END) AS Ay2,
                   -SUM(CASE WHEN h.ehTrhS >= @s3b THEN h.ehAdetN ELSE 0 END) AS Ay3
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= @s1b AND h.ehTrhS < DATEADD(DAY, 1, @s3s)
            GROUP BY h.ehstkID
        ),
        lt AS (    -- ODAK temin süresi. ⚠ ProductCode stkID DEĞİL → barkod zinciri (ölçüm %99,9)
            SELECT b.urnBrkdStkID AS stkID, MIN(d2.leadTime) AS leadTime, MAX(d2.saleStatus) AS saleStatus
            FROM BKMDATA.dbo.OdakUrunDurum d2 WITH (NOLOCK)
            JOIN BKMDATA.ent.odak_urun_tam t WITH (NOLOCK)
                 ON CAST(t.urun_id AS varchar(30)) COLLATE Turkish_CI_AS = d2.ProductCode COLLATE Turkish_CI_AS
            JOIN DerinSISBkm.dbo.urnBrkd b WITH (NOLOCK)
                 ON b.urnBarkod COLLATE Turkish_CI_AS = t.barkod COLLATE Turkish_CI_AS AND b.urnBrkdOnce = 0
            GROUP BY b.urnBrkdStkID
        ),
        mcik AS (  -- MERKEZ DEPO ÇIKIŞI (365g) — gün-stok kapsam asimetrisini kapatmak için.
            -- Toptan/grup dağıtımı: %72 grup şirketi · %16 ODAK (e-tic) · %6 Sınav (ölçüldü 09.09).
            -- TÜKETİCİ TALEBİ DEĞİL → mağaza hızıyla toplanmaz, ayrı gösterilir.
            -- Kaynak ERP defteri: merkez STOĞU için yasak (negatifli) ama HAREKET için tek kaynak.
            -- Gun = çıkışın kaç AYRI günde olduğu. Çıkış HIZ DEĞİL SIÇRAMA (ölçüldü:
            -- çeşitlerin %67'si tek günde) → ortalama hıza bölünmez, sıçramalılık gösterilir.
            SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Cikis,
                   COUNT(DISTINCT CONVERT(date, h.ehTrhS)) AS Gun
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan = 12 AND h.ehTip IN (1, 3, 5, 101)
              AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            GROUP BY h.ehstkID
        ),
        sonsat AS ( -- SON SATIŞ TARİHİ — PENCERE YOK (kullanıcı isteği 10.09.2026:
            -- "hareketsiz stokta sanki son satış tarihi gibi bir bilgi de lazım").
            -- NEDEN PENCERESİZ: "hareketsiz" = 365 günde satış YOK demek, yani son satış
            -- tanımı gereği pencerenin DIŞINDA. Tabandaki SatisToplam bu soruyu cevaplayamaz.
            -- "Hiç satılmamış" ile "eskiden satıyordu, durdu" AYRI problemlerdir: birincisi
            -- alım hatası, ikincisi talep kaybı. NULL = hiç satılmamış (0 YAZILMAZ).
            -- Kapsam mağaza satışı (ehTip 1/4/100, mekan 1/4477/4478, çıkış) — SatisToplam
            -- ile AYNI kapsam. Merkez çıkışı DAHİL DEĞİL: tüketici talebi değil (ölçüldü,
            -- %72'si grup şirketine) ve kartın anlamını bozar.
            -- ÖLÇÜLDÜ 10.09: 3,1 s / 315.607 çeşit · en eski 01.06.2021 · en yeni 09.09.2026.
            SELECT h.ehstkID AS stkID, MAX(h.ehTrhS) AS SonSatis
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehTip IN (1, 4, 100) AND h.ehMekan IN (1, 4477, 4478) AND h.ehAdetN < 0
            GROUP BY h.ehstkID
        ),
        mlyt AS (  -- BİRİM MALİYET: son 5 ALIŞ faturasının ağırlıklı birimi, KDV HARİÇ.
            -- Kanonik tanım sema/metrics.yaml → birim_maliyet (MLYT): fatura bazında
            -- topla-böl, satır bazında DEĞİL. fat.eTip=0 alış, eDurum<>2 iptal hariç.
            -- NEDEN TABANDA (kurul #2, 10.09.2026): drill tek ürün için bkm.UrunMaliyet
            -- çağırıyor; 275K ürün için satır-başı UDF = timeout (sql-server-conventions
            -- § TVF'i korelasyonlu alt-sorguda çağırma). Set-bazlı ÖLÇÜLDÜ: 9,1 s /
            -- 433.682 çeşit / ort. birim 139,78 ₺.
            SELECT f5.stkID, CONVERT(decimal(18,4), SUM(f5.tutar) / NULLIF(SUM(f5.adet), 0)) AS BirimMaliyet
            FROM (
                SELECT fa.ehstkID AS stkID, SUM(fa.ehAdetN) AS adet, SUM(fa.ehTutarN) AS tutar,
                       ROW_NUMBER() OVER (PARTITION BY fa.ehstkID
                                          ORDER BY f.eTarih DESC, f.eID DESC) AS sira
                FROM DerinSISBkm.dbo.fatAyr fa WITH (NOLOCK)
                JOIN DerinSISBkm.dbo.fat f WITH (NOLOCK) ON f.eID = fa.ehID
                WHERE f.eTip = 0 AND f.eDurum <> 2
                GROUP BY fa.ehstkID, f.eID, f.eTarih
            ) f5
            WHERE f5.sira <= 5
            GROUP BY f5.stkID
            HAVING SUM(f5.adet) <> 0
        ),
        pos AS (   -- GERÇEKLEŞEN SATIŞ: POS'ta fiilen alınan para, 365 gün, İADE HARİÇ.
            -- ⚠ KART FİYATI YANILTIYOR (ölçüldü 09.09, 90 gün): POS brütü kart fiyatına
            -- EŞİT (%95,4-99,5) ama gerçekleşen NET çok altında — Kitap %71,1 · Çocuk
            -- Kitabı %72,3 · Kırtasiye %80,3 · Oyuncak %88,6. Etiketle 1.022,2M ₺,
            -- kategori oranlarıyla 807,3M ₺ → 214,9M ₺ (%21,03) şişme.
            -- İade (DocumentsTypeId=3) HARİÇ: ortalama fiyat sorusunda iade satırı fiyatı
            -- bozar (veri-dogrula §2/2 — AVG'de iade hariç).
            -- Köprü Products.Code = stkID (barkod DEĞİL; %99,98 eşleşme). IsValid=1 zorunlu.
            -- EncoreMerkez compat 110 → TRY_CONVERT YOK; ISNUMERIC guard + desen süzgeci.
            -- ÖLÇÜLDÜ: 3,0 s / 154.225 çeşit / 6.062.582 adet / 1.131.231.099 ₺ net.
            SELECT CONVERT(int, p.Code) AS stkID,
                   CONVERT(int, SUM(sp.Amount))                              AS PosAdet,
                   CONVERT(decimal(18,2), SUM(sp.TotalPrice))                AS PosNet,
                   CONVERT(decimal(18,2), SUM(sp.VatTotal))                  AS PosKdv,
                   CONVERT(decimal(18,2), SUM(sp.TotalPrice + sp.DiscountTotalDirect)) AS PosBrut
            FROM EncoreMerkez.dbo.SalesProducts sp WITH (NOLOCK)
            JOIN EncoreMerkez.dbo.Sales s WITH (NOLOCK) ON s.Id = sp.SalesId
            JOIN EncoreMerkez.dbo.Products p WITH (NOLOCK) ON p.Id = sp.ProductsId
            WHERE sp.IsValid = 1
              AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
              AND s.[Date] >= @bas AND s.[Date] < DATEADD(DAY, 1, @kesim)
              AND ISNUMERIC(p.Code) = 1 AND p.Code NOT LIKE '%.%' AND p.Code NOT LIKE '%e%'
            GROUP BY CONVERT(int, p.Code)
            HAVING SUM(sp.Amount) > 0
        ),
        ilk AS (   -- IlkGiris = ürünün MAĞAZAYA ilk girişi (ölçüm 399/400) · SonGiris = SON mal kabulü
            -- TAZE STOK için SonGiris şart: IlkGiris 2021'e kadar gidebilir, tazeliği ölçmez.
            SELECT g.ehstkID AS stkID, MIN(g.ehTrhS) AS IlkGiris, MAX(g.ehTrhS) AS SonGiris
            FROM DerinSISBkm.dbo.irsHrk g WITH (NOLOCK)
            WHERE g.ehAdetN > 0 AND g.ehMekan IN (1, 4477, 4478)
            GROUP BY g.ehstkID
        )
        INSERT INTO DerinSISBkm.bkm.SatisAnaliziTaban
            (Kesim, SezonYil, stkID, Kategori3, Kategori1, BarkodAna, stkAd, Yayinevi, Yazar, SatisFiyat,
             StokFsm, StokOzl, StokIst, MerkezStok, OdakStok, SatisFsm, SatisOzl, SatisIst, Ay1, Ay2, Ay3,
             MagazaStok, ToplamStok, SatisToplam, SezonToplam, Tutar, IlkGiris, SonGiris, AcilisTarihi, LeadTime, OdakDurum,
             MerkezCikis, MerkezCikisGun,
             BirimMaliyet, PosAdet, PosNet, PosKdv, PosBrut, SonSatis)
        SELECT @kesim, @sezon, k.stkID, k.Kategori3, k.Kategori1, k.BarkodAna,
               CAST(k.stkAd AS nvarchar(120)), k.Yayinevi, k.Yazar, k.SatisFiyat,
               CONVERT(int, ISNULL(m.Fsm, 0)), CONVERT(int, ISNULL(m.Ozl, 0)), CONVERT(int, ISNULL(m.Ist, 0)),
               CONVERT(int, ISNULL(d.Merkez, 0)), CONVERT(int, ISNULL(o.StokMiktar, 0)),
               CONVERT(int, ISNULL(s.Fsm, 0)), CONVERT(int, ISNULL(s.Ozl, 0)), CONVERT(int, ISNULL(s.Ist, 0)),
               CONVERT(int, ISNULL(z.Ay1, 0)), CONVERT(int, ISNULL(z.Ay2, 0)), CONVERT(int, ISNULL(z.Ay3, 0)),
               CONVERT(int, ISNULL(m.Fsm,0) + ISNULL(m.Ozl,0) + ISNULL(m.Ist,0)),
               CONVERT(int, ISNULL(m.Fsm,0) + ISNULL(m.Ozl,0) + ISNULL(m.Ist,0) + ISNULL(d.Merkez,0)),
               CONVERT(int, ISNULL(s.Fsm,0) + ISNULL(s.Ozl,0) + ISNULL(s.Ist,0)),
               CONVERT(int, ISNULL(z.Ay1,0) + ISNULL(z.Ay2,0) + ISNULL(z.Ay3,0)),
               CONVERT(decimal(18,2),
                   (ISNULL(m.Fsm,0) + ISNULL(m.Ozl,0) + ISNULL(m.Ist,0) + ISNULL(d.Merkez,0)) * k.SatisFiyat),
               i.IlkGiris, i.SonGiris, k.AcilisTarihi, CAST(lt.leadTime AS int), CAST(lt.saleStatus AS int),
               CONVERT(int, ISNULL(mc.Cikis, 0)), CONVERT(int, ISNULL(mc.Gun, 0)),
               -- GERÇEKLEŞEN MARJ İÇİN (kurul #2). NULL = kaydı yok; 0 YAZILMAZ —
               -- 0 maliyet marjı %100 gösterir, 0 satış marjı −sonsuz (sessiz yanlış rakam).
               ml.BirimMaliyet, ps.PosAdet, ps.PosNet, ps.PosKdv, ps.PosBrut,
               ss.SonSatis
        FROM kat k
        LEFT JOIN mgz  m ON m.stkID = k.stkID
        LEFT JOIN depo d ON d.stkID = k.stkID
        LEFT JOIN DerinSISBkm.ent.odak_depo_Stok o WITH (NOLOCK) ON o.stkID = k.stkID
        LEFT JOIN sat  s ON s.stkID = k.stkID
        LEFT JOIN sezon z ON z.stkID = k.stkID
        LEFT JOIN lt     ON lt.stkID = k.stkID
        LEFT JOIN mcik mc ON mc.stkID = k.stkID
        LEFT JOIN ilk  i ON i.stkID = k.stkID
        LEFT JOIN mlyt ml ON ml.stkID = k.stkID
        LEFT JOIN pos  ps ON ps.stkID = k.stkID
        LEFT JOIN sonsat ss ON ss.stkID = k.stkID
        WHERE ISNULL(m.Fsm,0) <> 0 OR ISNULL(m.Ozl,0) <> 0 OR ISNULL(m.Ist,0) <> 0 OR ISNULL(d.Merkez,0) <> 0
           OR ISNULL(s.Fsm,0) <> 0 OR ISNULL(s.Ozl,0) <> 0 OR ISNULL(s.Ist,0) <> 0
           OR ISNULL(z.Ay1,0) <> 0 OR ISNULL(z.Ay2,0) <> 0 OR ISNULL(z.Ay3,0) <> 0;
        """;
}

/// <summary>Taban hazır mı, kaç satır, ne zaman üretildi.</summary>
public sealed record TabanDurum(bool Hazir, int Satir, DateTime? Uretim);
