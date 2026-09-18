using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Vardiya / Mesai paneli — plan-47 Faz 2. Kaynak <b>panel DB</b> (<c>Db.OpenPanel</c>,
/// yerel <c>BkmPanel</c>), ERP DEĞİL. Tablolar <c>bkm.Vrd_*</c>; hesap
/// <c>bkm.sp_Vrd_KisiGunDoldur</c> tarafından yazılır — bu sınıf SALT-OKUR
/// (tek istisna <see cref="OnayKaydetAsync"/>, aşağıda gerekçesi var).
///
/// Bu sınıf bir EMITTER'dır: hesap ÇOĞALTILMAZ (emitter-ayrimi.md). Eksik/fazla
/// saat, mola, gün dönümü, durum kodu — hepsi SP'de üretilmiştir.
///
/// ZORUNLU KURALLAR (17.09.2026 ölçümleri):
/// • <b>Süreler DAKİKA</b> (int). Gece mesaisinde çıkış ertesi güne sarkar (&gt;1440);
///   <c>time</c> tipi bunu tutamaz. Biçimleme ekranda yapılır.
/// • <b>SayimDisi satırlar toplama GİRMEZ.</b> Dönem başındaki gün önceki ayın
///   devrinde sayılıdır; satır raporda DURUR (hafta bütünlüğü için) ama eksik/fazla
///   hesabına katılmaz.
/// • <b>ŞÜPHELİ okutma denetim DIŞI.</b> Çıkış okutmasını unutan kişi 17-20 saat
///   çalışmış görünür; uyum sayımına girerse SAHTE ihlal üretir ve gerçeği gürültüye
///   gömer. Ayraç: <c>OlcumNotu LIKE '%ŞÜPHELİ%'</c>.
/// • <b>Gece çalışması = 20:00-06:00 penceresindeki süre</b> (4857 m.69), "gün dönümü
///   olan satır" DEĞİL. Yanlış tanımla 14 gün ihlal çıkmıştı, doğrusu 1 gün.
/// • <b>Haftalık 45 saat üstü İHLAL DEĞİLDİR</b> — fazla çalışmadır. Sert sınır yıllık
///   270 saat + yazılı işçi muvafakati (m.41/7).
/// Yorum çerçevesi: <c>.claude/skills/ik-danisman/SKILL.md</c> § Mesai Mevzuat Kapısı.
/// </summary>
public sealed class VardiyaQueries(Db db)
{
    /// <summary>Yazılabilir kesimler (en yeni önce). Boşsa SP hiç koşmamıştır.</summary>
    public async Task<IReadOnlyList<VrdKesim>> KesimlerAsync()
    {
        using var cn = db.OpenPanel();
        var r = await cn.QueryAsync<VrdKesim>("""
            SELECT  KesimBas, KesimBit, SayimBas,
                    KisiGun  = COUNT(*),
                    SubeSay  = COUNT(DISTINCT Sube),
                    Yazilma  = MAX(YazilmaUtc)
            FROM    bkm.Vrd_KisiGun
            GROUP BY KesimBas, KesimBit, SayimBas
            ORDER BY KesimBit DESC, KesimBas DESC
            """);
        return r.AsList();
    }

    /// <summary>
    /// Kesim özeti: eksik/fazla saat + durum kırılımı.
    /// Eksik/Fazla burada TÜRETİLİR (plan süresi vs gerçekleşen) — SP'nin yazdığı
    /// alanlardan, yeni bir iş kuralı EKLENMEZ.
    /// </summary>
    public async Task<VrdOzet?> OzetAsync(DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        return await cn.QuerySingleOrDefaultAsync<VrdOzet>("""
            SELECT
                KisiGun   = COUNT(*),
                SubeSay   = COUNT(DISTINCT Sube),
                KisiSay   = COUNT(DISTINCT NULLIF(SicilNo, '')),
                -- ⚠ SP'nin yazdığı kolonlar OKUNUR, burada YENİDEN HESAPLANMAZ.
                --   Taban `Vrd_CalismaSaati` politika tablosudur; vardiya planının
                --   süresiyle hesaplanırsa yayınlanan Excel'den SAPAR (ölçüldü:
                --   plan tabanı 4.313/4.596 saat vs politika tabanı 6.118/5.024).
                EksikDk   = SUM(ISNULL(EksikDk, 0)),
                FazlaDk   = SUM(ISNULL(FazlaDk, 0)),
                SayimDisi = SUM(CONVERT(int, SayimDisi)),
                GunDonumu = SUM(CONVERT(int, GunDonumu)),
                Supheli   = SUM(CASE WHEN OlcumNotu LIKE N'%ŞÜPHELİ%' THEN 1 ELSE 0 END),
                -- ⚠ DEVİR BAKİYESİ AYRI TABLODA ama yayınlanan raporun TOPLAMINA
                --   GİRER. Panel yalnız dönemi gösterirse Excel'le 1.858/201 saat
                --   sapar ve iki farklı toplam ortaya çıkar (ölçüldü 17.09.2026).
                DevirEksikDk = (SELECT ISNULL(SUM(EksikDk), 0) FROM bkm.Vrd_Devir),
                DevirFazlaDk = (SELECT ISNULL(SUM(FazlaDk), 0) FROM bkm.Vrd_Devir)
            FROM bkm.Vrd_KisiGun
            WHERE KesimBas = @bas AND KesimBit = @bit
            """, new { bas = bas.ToDateTime(TimeOnly.MinValue), bit = bit.ToDateTime(TimeOnly.MinValue) });
    }

    public async Task<IReadOnlyList<VrdDurum>> DurumKirilimAsync(DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        var r = await cn.QueryAsync<VrdDurum>("""
            SELECT Durum, KisiGun = COUNT(*)
            FROM   bkm.Vrd_KisiGun
            WHERE  KesimBas = @bas AND KesimBit = @bit
            GROUP BY Durum ORDER BY COUNT(*) DESC
            """, new { bas = bas.ToDateTime(TimeOnly.MinValue), bit = bit.ToDateTime(TimeOnly.MinValue) });
        return r.AsList();
    }

    public async Task<IReadOnlyList<VrdSube>> SubeKirilimAsync(DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        var r = await cn.QueryAsync<VrdSube>("""
            SELECT  Sube,
                    KisiGun = COUNT(*),
                    KisiSay = COUNT(DISTINCT NULLIF(SicilNo, '')),
                    EksikDk = SUM(ISNULL(EksikDk, 0)),
                    FazlaDk = SUM(ISNULL(FazlaDk, 0))
            FROM    bkm.Vrd_KisiGun
            WHERE   KesimBas = @bas AND KesimBit = @bit
            GROUP BY Sube ORDER BY Sube
            """, new { bas = bas.ToDateTime(TimeOnly.MinValue), bit = bit.ToDateTime(TimeOnly.MinValue) });
        return r.AsList();
    }

    /// <summary>
    /// FAZLA MESAİNİN KAYNAĞI — SP'nin yazdığı kolonlar okunur, türetilmez.
    /// "Ne kadarı fazla çalışma, ne kadarı izin iptali" (GMY sorusu 17.09.2026).
    /// </summary>
    public async Task<VrdFazlaKaynak?> FazlaKaynakAsync(DateOnly bas, DateOnly bit, string? sube)
    {
        using var cn = db.OpenPanel();
        return await cn.QuerySingleOrDefaultAsync<VrdFazlaKaynak>("""
            SELECT FazlaCalismaDk = SUM(ISNULL(FazlaCalismaDk, 0)),
                   IzinIptalDk    = SUM(ISNULL(FazlaIzinIptalDk, 0)),
                   HaftaTatilDk   = SUM(ISNULL(HaftalikPrimDk, 0)),
                   PlansizDk      = SUM(ISNULL(FazlaPlansizDk, 0)),
                   CikisSonrasiDk = SUM(ISNULL(CikisSonrasiDk, 0)),
                   GirisOncesiDk  = SUM(ISNULL(GirisOncesiDk, 0))
            FROM   bkm.Vrd_KisiGun
            WHERE  KesimBas = @bas AND KesimBit = @bit
              AND (@sube IS NULL OR Sube = @sube)
            """, new
        {
            bas = bas.ToDateTime(TimeOnly.MinValue),
            bit = bit.ToDateTime(TimeOnly.MinValue),
            sube = string.IsNullOrWhiteSpace(sube) ? null : sube,
        });
    }

    /// <summary>
    /// Kapanış sonrası kalma süre bandı. Uzun kuyruk ayrı bir sorudur: 15 dakikalık
    /// toplanma ile 2 saati aşan kalma AYNI ŞEY DEĞİLDİR ve aynı aksiyonu almaz.
    /// </summary>
    public async Task<IReadOnlyList<VrdKalmaBant>> KalmaBandiAsync(
        DateOnly bas, DateOnly bit, string? sube)
    {
        using var cn = db.OpenPanel();
        var r = await cn.QueryAsync<VrdKalmaBant>("""
            SELECT Bant = CASE WHEN CikisSonrasiDk <=  15 THEN N'≤ 15 dk'
                               WHEN CikisSonrasiDk <=  30 THEN N'16–30 dk'
                               WHEN CikisSonrasiDk <=  60 THEN N'31–60 dk'
                               WHEN CikisSonrasiDk <= 120 THEN N'1–2 saat'
                               ELSE N'2 saat üstü' END,
                   Satir = COUNT(*), Dk = SUM(CikisSonrasiDk)
            FROM   bkm.Vrd_KisiGun
            WHERE  KesimBas = @bas AND KesimBit = @bit
              AND  ISNULL(CikisSonrasiDk, 0) > 0
              AND (@sube IS NULL OR Sube = @sube)
            GROUP BY CASE WHEN CikisSonrasiDk <=  15 THEN N'≤ 15 dk'
                          WHEN CikisSonrasiDk <=  30 THEN N'16–30 dk'
                          WHEN CikisSonrasiDk <=  60 THEN N'31–60 dk'
                          WHEN CikisSonrasiDk <= 120 THEN N'1–2 saat'
                          ELSE N'2 saat üstü' END
            ORDER BY MIN(CikisSonrasiDk)
            """, new
        {
            bas = bas.ToDateTime(TimeOnly.MinValue),
            bit = bit.ToDateTime(TimeOnly.MinValue),
            sube = string.IsNullOrWhiteSpace(sube) ? null : sube,
        });
        return r.AsList();
    }

    /// <summary>
    /// MESAİ MEVZUAT KAPISI — `tools/mesai_mevzuat_kapisi.py` ile AYNI eşikler ve
    /// AYNI tanımlar. İki yerde iki farklı sayı çıkarsa biri bayatlamış demektir.
    /// ⚠ Gece süresi 20:00-06:00 kesişimidir; çıkış 1440'ı aşabildiği için pencere
    ///   iki gün için taranır.
    /// ⚠ ŞÜPHELİ satırlar denetim DIŞI.
    /// </summary>
    public async Task<VrdUyum?> UyumAsync(DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        // ⚠ CTE MATERYALİZE EDİLMEZ — beş referans beş yeniden tarama demekti ve
        //   `geceDk` içindeki VALUES alt-sorgusu satır başına koşuyordu.
        //   ÖLÇÜLDÜ (18.09.2026, 6.113 satır): 43,2 sn → komut zaman aşımı, sayfa
        //   500 veriyordu. #temp'e tek geçiş + aritmetik kesişim: **0,30 sn**,
        //   aynı sonuç (93 · 93 · 1 · 124 · 544 · 2). 144 kat.
        return await cn.QuerySingleOrDefaultAsync<VrdUyum>("""
            SELECT SicilNo, Tarih, CalismaDk, GirisDk, CikisDk, Izin,
                   -- gece = [giriş,çıkış] ∩ 20:00–06:00; çıkış 1440'ı aşabildiği
                   -- için pencere iki gün için toplanır (m.69).
                   geceDk = CASE WHEN GirisDk IS NULL OR CikisDk IS NULL
                                      OR CikisDk <= GirisDk THEN 0 ELSE
                       CASE WHEN (CASE WHEN CikisDk < 1800 THEN CikisDk ELSE 1800 END)
                               - (CASE WHEN GirisDk > 1200 THEN GirisDk ELSE 1200 END) > 0
                            THEN (CASE WHEN CikisDk < 1800 THEN CikisDk ELSE 1800 END)
                               - (CASE WHEN GirisDk > 1200 THEN GirisDk ELSE 1200 END) ELSE 0 END
                     + CASE WHEN (CASE WHEN CikisDk < 3240 THEN CikisDk ELSE 3240 END)
                               - (CASE WHEN GirisDk > 2640 THEN GirisDk ELSE 2640 END) > 0
                            THEN (CASE WHEN CikisDk < 3240 THEN CikisDk ELSE 3240 END)
                               - (CASE WHEN GirisDk > 2640 THEN GirisDk ELSE 2640 END) ELSE 0 END
                   END,
                   supheli = CASE WHEN OlcumNotu LIKE N'%ŞÜPHELİ%' THEN 1 ELSE 0 END
            INTO   #o
            FROM   bkm.Vrd_KisiGun
            WHERE  KesimBas = @bas AND KesimBit = @bit;

            WITH hf AS (
              SELECT SicilNo, hafta = DATEPART(iso_week, Tarih),
                     gun = COUNT(DISTINCT Tarih),
                     dinlenme = SUM(CASE WHEN Izin = 1 OR ISNULL(CalismaDk,0) = 0 THEN 1 ELSE 0 END),
                     toplamDk = SUM(ISNULL(CalismaDk,0))
              FROM #o WHERE supheli = 0
              GROUP BY SicilNo, DATEPART(iso_week, Tarih))
            SELECT
              Gunluk11 = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND ISNULL(CalismaDk,0) > 660),
              Brut12   = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND GirisDk IS NOT NULL
                                                    AND CikisDk IS NOT NULL AND CikisDk-GirisDk > 720),
              Gece75   = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND geceDk > 450),
              HaftaTat = (SELECT COUNT(*) FROM hf WHERE gun >= 7 AND dinlenme = 0),
              Ustu45   = (SELECT COUNT(*) FROM hf WHERE toplamDk > 2700),
              Supheli  = (SELECT COUNT(*) FROM #o WHERE supheli = 1);
            """, new { bas = bas.ToDateTime(TimeOnly.MinValue), bit = bit.ToDateTime(TimeOnly.MinValue) });
    }

    /// <summary>
    /// Kişi-gün listesi. <paramref name="sadeceSorunlu"/> → yalnız eksik/fazla saat
    /// doğuran, ölçüm notu taşıyan veya devamsız satırlar.
    /// </summary>
    public async Task<IReadOnlyList<VrdSatir>> SatirlarAsync(
        DateOnly bas, DateOnly bit, string? sube, string? ara, bool sadeceSorunlu, int limit = 400)
    {
        using var cn = db.OpenPanel();
        var r = await cn.QueryAsync<VrdSatir>($"""
            SELECT TOP (@limit)
                   k.Sube, k.SicilNo, k.Personel, k.Bolum, k.Gorev, k.Tarih,
                   k.VardiyaTanim, k.KartGirisDk, k.KartCikisDk, k.GirisDk, k.CikisDk,
                   k.BrutDk, k.MolaDk, k.CalismaDk, k.PlanCalismaDk,
                   k.GerekenDk, k.Net2Dk, k.HaftalikPrimDk,
                   k.EksikDk, k.FazlaDk, k.Durum,
                   k.GunDonumu, k.SayimDisi, k.OlcumNotu,
                   OnayGirisDk = o.OnayliGirisDk, OnayCikisDk = o.OnayliCikisDk,
                   EkMesaiDk   = o.EkMesaiDk
            FROM        bkm.Vrd_KisiGun k
            LEFT  JOIN  bkm.Vrd_Onay   o ON o.SicilNo = k.SicilNo AND o.Tarih = k.Tarih
            WHERE  k.KesimBas = @bas AND k.KesimBit = @bit
              AND (@sube IS NULL OR k.Sube = @sube)
              AND (@ara  IS NULL OR k.Personel LIKE '%' + @ara + '%' OR k.SicilNo LIKE @ara + '%')
              {(sadeceSorunlu ? """
                AND (k.OlcumNotu IS NOT NULL
                     OR k.Durum IN (N'Devamsız', N'Vardiya Tanımsız Çalışma')
                     OR (k.SayimDisi = 0 AND k.CalismaDk <> k.PlanCalismaDk))
              """ : "")}
            ORDER BY k.Tarih DESC, k.Sube, k.Personel
            """, new
        {
            bas = bas.ToDateTime(TimeOnly.MinValue),
            bit = bit.ToDateTime(TimeOnly.MinValue),
            sube = string.IsNullOrWhiteSpace(sube) ? null : sube,
            ara = string.IsNullOrWhiteSpace(ara) ? null : ara.Trim(),
            limit,
        });
        return r.AsList();
    }

    /// <summary>
    /// YÖNETİCİ ONAYI — panelin TEK yazma noktası.
    ///
    /// Hedef <c>BkmPanel</c> (app-local), ERP DEĞİL — <c>erp-write-policy.md</c>
    /// kapsamında bir ERP yazması değildir. Bu veri hiçbir sorgudan çıkmaz; bugüne
    /// kadar Excel hücresinde yaşıyordu ve dosya yenilenince kayboluyordu. Tablonun
    /// gerçek gerekçesi budur.
    ///
    /// ⚠ <c>EkMesaiDk</c>'ya GÜN DÖNÜMÜ TELAFİSİ YAZILMAZ — gece mesaisi artık
    ///   otomatik hesaplanıyor; buraya aynı saat girilirse mesai İKİ KEZ sayılır.
    ///   ÖLÇÜLDÜ (17.09.2026): eski Excel'de elle doldurulan 11 satırın 9'u tam
    ///   olarak bu telafiydi. DB tarafında ayrıca CHECK var (0-1440).
    /// </summary>
    public async Task OnayKaydetAsync(string sicilNo, DateOnly tarih,
        int? girisDk, int? cikisDk, int? ekMesaiDk, string? aciklama, string kaydeden)
    {
        if (string.IsNullOrWhiteSpace(sicilNo))
            throw new ArgumentException("SicilNo boş olamaz — kişi-gün kimliği kurulamaz.", nameof(sicilNo));
        foreach (var (ad, v) in new[] { ("Giriş", girisDk), ("Çıkış", cikisDk) })
            if (v is < 0 or > 2880)
                throw new ArgumentOutOfRangeException(ad, $"{ad} dakikası 0-2880 dışında: {v}");
        if (ekMesaiDk is < 0 or > 1440)
            throw new ArgumentOutOfRangeException(nameof(ekMesaiDk), "Ek mesai 0-1440 dakika dışında.");

        using var cn = db.OpenPanel();
        // Üç alan da boşsa kayıt SİLİNİR — "hepsini temizledim" niyetini boş satır
        // olarak saklamak sonraki okumada gereksiz JOIN eşleşmesi üretir.
        if (girisDk is null && cikisDk is null && ekMesaiDk is null && string.IsNullOrWhiteSpace(aciklama))
        {
            await cn.ExecuteAsync(
                "DELETE FROM bkm.Vrd_Onay WHERE SicilNo = @sicilNo AND Tarih = @tarih",
                new { sicilNo, tarih = tarih.ToDateTime(TimeOnly.MinValue) });
            return;
        }
        await cn.ExecuteAsync("""
            MERGE bkm.Vrd_Onay AS h
            USING (SELECT @sicilNo AS SicilNo, @tarih AS Tarih) AS k
               ON h.SicilNo = k.SicilNo AND h.Tarih = k.Tarih
            WHEN MATCHED THEN UPDATE SET
                 OnayliGirisDk = @girisDk, OnayliCikisDk = @cikisDk,
                 EkMesaiDk = @ekMesaiDk, Aciklama = @aciklama,
                 Kaydeden = @kaydeden, KayitUtc = SYSUTCDATETIME()
            WHEN NOT MATCHED THEN INSERT
                 (SicilNo, Tarih, OnayliGirisDk, OnayliCikisDk, EkMesaiDk, Aciklama, Kaydeden)
                 VALUES (@sicilNo, @tarih, @girisDk, @cikisDk, @ekMesaiDk, @aciklama, @kaydeden);
            """, new
        {
            sicilNo, tarih = tarih.ToDateTime(TimeOnly.MinValue),
            girisDk, cikisDk, ekMesaiDk,
            aciklama = string.IsNullOrWhiteSpace(aciklama) ? null : aciklama.Trim(),
            kaydeden,
        });
    }
}
