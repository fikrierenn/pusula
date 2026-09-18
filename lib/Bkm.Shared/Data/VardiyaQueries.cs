using Dapper;
using Bkm.Shared.Models;

namespace Bkm.Shared.Data;

/// <summary>
/// Vardiya / Mesai paneli — plan-47 Faz 2. Kaynak <b>panel DB</b> (<c>Db.OpenPanel</c>,
/// yerel <c>BkmPanel</c>), ERP DEĞİL. Tablolar <c>bkm.Vrd_*</c>; hesap
/// <c>bkm.sp_Vrd_KisiGunDoldur</c> tarafından yazılır — bu sınıf SALT-OKUR
/// (tek istisna <see cref="SaveApprovalAsync"/>, aşağıda gerekçesi var).
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
    // ═══ ŞUBE KAPSAMI SÖZLEŞMESİ — plan 48 Adım 4, GMY kararı "b-tam yap" ═══
    //
    // HER metot `userId` alır ve kapsam VERİTABANINDA çözülür:
    //     Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
    //
    // Şube kimliği ve "tüm şubeler" yetkisi UYGULAMADAN GEÇMEZ. Ölçüt (Solum,
    // 18.09): "bu yoldan geçen değerlerden hangisi bir YETKİ KARARIDIR?" → SIFIR.
    // Yani yanlış bir şube id'si "geçemez" değil, GEÇİRİLECEK YER YOKTUR.
    //
    // ⚠ `sube` parametresi bir YETKİ DEĞİL, GÖRÜNTÜ FİLTRESİDİR: kapsam İÇİNDE
    //   daraltır. Uydurulmuş bir değer kesişimde düşer, kapsamı genişletemez.
    //
    // ⚠ YAZMA da kapılı (SaveApprovalAsync): okuma süzgeci yazma yolunu korumaz,
    //   çünkü SicilNo+Tarih elle de gelebilir.
    //
    // ⚠ KAPSAM BUGÜNKÜ ACL'DEN çözülür, satırın tarihinden DEĞİL (19.09 düzeltmesi,
    //   GMY itirazı): bugün bir şubeden sorumluysan o şubenin TÜM geçmişini
    //   görürsün — yoksa yeni atanan müdür kıyas ve tahmin yapamazdı. "O tarihte
    //   kim sorumluydu" ayrı bir sorudur ve `Vrd_KullaniciSubeGecmis_vw`de durur.

    /// <summary>Yazılabilir kesimler (en yeni önce). Boşsa SP hiç koşmamıştır.</summary>
    public async Task<IReadOnlyList<VrdKesim>> GetCutoffsAsync(string userId)
    {
        using var cn = db.OpenPanel();
        var r = await cn.QueryAsync<VrdKesim>("""
            SELECT  KesimBas, KesimBit, SayimBas,
                    KisiGun  = COUNT(*),
                    SubeSay  = COUNT(DISTINCT Sube),
                    Yazilma  = MAX(YazilmaUtc)
            FROM    bkm.Vrd_KisiGun
            WHERE   Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
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
    public async Task<VrdOzet?> GetSummaryAsync(string userId, DateOnly bas, DateOnly bit)
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
                Supheli   = SUM(CASE WHEN OlcumNotu LIKE @supheli THEN 1 ELSE 0 END),
                -- ⚠ DEVİR BAKİYESİ AYRI TABLODA ama yayınlanan raporun TOPLAMINA
                --   GİRER. Panel yalnız dönemi gösterirse Excel'le 1.858/201 saat
                --   sapar ve iki farklı toplam ortaya çıkar (ölçüldü 17.09.2026).
                DevirEksikDk = (SELECT ISNULL(SUM(EksikDk), 0) FROM bkm.Vrd_Devir),
                DevirFazlaDk = (SELECT ISNULL(SUM(FazlaDk), 0) FROM bkm.Vrd_Devir)
            FROM bkm.Vrd_KisiGun
            WHERE KesimBas = @bas AND KesimBit = @bit
              AND Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
            """, new
        {
            userId,
            bas = bas.ToDateTime(TimeOnly.MinValue),
            bit = bit.ToDateTime(TimeOnly.MinValue),
            supheli = VrdConstants.SuspectPattern,
        });
    }

    public async Task<IReadOnlyList<VrdDurum>> GetStatusBreakdownAsync(string userId, DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        var r = await cn.QueryAsync<VrdDurum>("""
            SELECT Durum, KisiGun = COUNT(*)
            FROM   bkm.Vrd_KisiGun
            WHERE  KesimBas = @bas AND KesimBit = @bit
              AND  Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
            GROUP BY Durum ORDER BY COUNT(*) DESC
            """, new { userId, bas = bas.ToDateTime(TimeOnly.MinValue), bit = bit.ToDateTime(TimeOnly.MinValue) });
        return r.AsList();
    }

    public async Task<IReadOnlyList<VrdSube>> GetBranchBreakdownAsync(string userId, DateOnly bas, DateOnly bit)
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
              AND   Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
            GROUP BY Sube ORDER BY Sube
            """, new { userId, bas = bas.ToDateTime(TimeOnly.MinValue), bit = bit.ToDateTime(TimeOnly.MinValue) });
        return r.AsList();
    }

    /// <summary>
    /// FAZLA MESAİNİN KAYNAĞI — SP'nin yazdığı kolonlar okunur, türetilmez.
    /// "Ne kadarı fazla çalışma, ne kadarı izin iptali" (GMY sorusu 17.09.2026).
    /// </summary>
    public async Task<VrdFazlaKaynak?> GetOvertimeSourceAsync(string userId, DateOnly bas, DateOnly bit, string? sube)
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
              AND  Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
              AND (@sube IS NULL OR Sube = @sube)
            """, new
        {
            userId,
            bas = bas.ToDateTime(TimeOnly.MinValue),
            bit = bit.ToDateTime(TimeOnly.MinValue),
            sube = string.IsNullOrWhiteSpace(sube) ? null : sube,
        });
    }

    /// <summary>
    /// Kapanış sonrası kalma süre bandı. Uzun kuyruk ayrı bir sorudur: 15 dakikalık
    /// toplanma ile 2 saati aşan kalma AYNI ŞEY DEĞİLDİR ve aynı aksiyonu almaz.
    /// </summary>
    public async Task<IReadOnlyList<VrdKalmaBant>> GetStayBandsAsync(
        string userId, DateOnly bas, DateOnly bit, string? sube)
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
            userId,
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
    public async Task<VrdUyum?> GetComplianceAsync(string userId, DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        // ⚠ CTE MATERYALİZE EDİLMEZ — beş referans beş yeniden tarama demekti ve
        //   `geceDk` içindeki VALUES alt-sorgusu satır başına koşuyordu.
        //   ÖLÇÜLDÜ (18.09.2026, 6.113 satır): 43,2 sn → komut zaman aşımı, sayfa
        //   500 veriyordu. #temp'e tek geçiş + aritmetik kesişim: **0,30 sn**,
        //   aynı sonuç (93 · 93 · 1 · 124 · 544 · 2). 144 kat.
        //
        // ⚠ #o'ya İNDEKS EKLENMEDİ — DENENDİ, YAVAŞLATTI.
        //   `CREATE CLUSTERED INDEX (supheli, SicilNo, Tarih)` ölçüldü (6 koşum):
        //   medyan 81 ms → 104-117 ms. 6.113 satırda sıralama maliyeti tarama
        //   kazancını aşıyor. Hızı veren indeks DEĞİL, tek geçişti.
        //
        //   İndeksin gerçekten kazandırdığı yer KAYNAK TABLO: kapı bir kesimin
        //   tamamını tarar ve GirisDk/CikisDk/Izin/OlcumNotu ister; bunlar
        //   `IX_Vrd_KisiGun_Kesim`te YOK. `IX_Vrd_KisiGun_KesimUyum` bunun için
        //   var (24 kesim taklidi, 146.712 satır: 89,6 → 22,9 ms). DDL:
        //   sorgular/2026-09-17-vardiya-tablo-kur.sql
        return await cn.QuerySingleOrDefaultAsync<VrdUyum>("""
            SELECT SicilNo, Tarih, CalismaDk, GirisDk, CikisDk, Izin,
                   -- gece = [giriş,çıkış] ∩ 20:00–06:00; çıkış 1440'ı aşabildiği
                   -- için pencere iki gün için toplanır (m.69).
                   geceDk = CASE WHEN GirisDk IS NULL OR CikisDk IS NULL
                                      OR CikisDk <= GirisDk THEN 0 ELSE
                       CASE WHEN (CASE WHEN CikisDk < @geceBit THEN CikisDk ELSE @geceBit END)
                               - (CASE WHEN GirisDk > @geceBas THEN GirisDk ELSE @geceBas END) > 0
                            THEN (CASE WHEN CikisDk < @geceBit THEN CikisDk ELSE @geceBit END)
                               - (CASE WHEN GirisDk > @geceBas THEN GirisDk ELSE @geceBas END) ELSE 0 END
                     + CASE WHEN (CASE WHEN CikisDk < @geceBit2 THEN CikisDk ELSE @geceBit2 END)
                               - (CASE WHEN GirisDk > @geceBas2 THEN GirisDk ELSE @geceBas2 END) > 0
                            THEN (CASE WHEN CikisDk < @geceBit2 THEN CikisDk ELSE @geceBit2 END)
                               - (CASE WHEN GirisDk > @geceBas2 THEN GirisDk ELSE @geceBas2 END) ELSE 0 END
                   END,
                   supheli = CASE WHEN OlcumNotu LIKE @supheli THEN 1 ELSE 0 END
            INTO   #o
            FROM   bkm.Vrd_KisiGun
            WHERE  KesimBas = @bas AND KesimBit = @bit
              AND  Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId));

            WITH hf AS (
              SELECT SicilNo, hafta = DATEPART(iso_week, Tarih),
                     gun = COUNT(DISTINCT Tarih),
                     dinlenme = SUM(CASE WHEN Izin = 1 OR ISNULL(CalismaDk,0) = 0 THEN 1 ELSE 0 END),
                     toplamDk = SUM(ISNULL(CalismaDk,0))
              FROM #o WHERE supheli = 0
              GROUP BY SicilNo, DATEPART(iso_week, Tarih))
            SELECT
              Gunluk11 = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND ISNULL(CalismaDk,0) > @gunlukTavan),
              Brut12   = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND GirisDk IS NOT NULL
                                                    AND CikisDk IS NOT NULL AND CikisDk-GirisDk > @brutTavan),
              Gece75   = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND geceDk > @geceTavan),
              HaftaTat = (SELECT COUNT(*) FROM hf WHERE gun >= 7 AND dinlenme = 0),
              Ustu45   = (SELECT COUNT(*) FROM hf WHERE toplamDk > @haftalikNormal),
              Supheli  = (SELECT COUNT(*) FROM #o WHERE supheli = 1);
            """, new
        {
            userId,
            bas = bas.ToDateTime(TimeOnly.MinValue),
            bit = bit.ToDateTime(TimeOnly.MinValue),
            supheli = VrdConstants.SuspectPattern,
            // ⚠ Eşikler GÖMÜLÜ SAYI DEĞİL — tek kaynak MesaiEsik, Python karşılığıyla
            //   tools/mesai_esik_denetimi.py karşılaştırıyor.
            geceBas = WorkTimeLimit.NightStartMin, geceBit = WorkTimeLimit.NightEndMin,
            geceBas2 = WorkTimeLimit.NightStartMin2, geceBit2 = WorkTimeLimit.NightEndMin2,
            gunlukTavan = WorkTimeLimit.DailyCapMin,
            brutTavan = WorkTimeLimit.DailyGrossCapMin,
            geceTavan = WorkTimeLimit.NightCapMin,
            haftalikNormal = WorkTimeLimit.WeeklyNormalMin,
        });
    }

    /// <summary>
    /// Kişi-gün listesi. <paramref name="sadeceSorunlu"/> → yalnız eksik/fazla saat
    /// doğuran, ölçüm notu taşıyan veya devamsız satırlar.
    /// </summary>
    public async Task<IReadOnlyList<VrdSatir>> GetRowsAsync(
        string userId, DateOnly bas, DateOnly bit, string? sube, string? ara, bool sadeceSorunlu, int limit = 400)
    {
        using var cn = db.OpenPanel();
        var r = await cn.QueryAsync<VrdSatir>("""
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
              AND  k.Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
              AND (@sube IS NULL OR k.Sube = @sube)
              -- ⚠ ESCAPE ZORUNLU: kullanıcı '%' ya da '_' yazarsa süzgeç sessizce
              --   genişlerdi (injection değil ama YANLIŞ SONUÇ). Kaçış C# tarafında.
              AND (@ara  IS NULL OR k.Personel LIKE '%' + @ara + '%' ESCAPE '\'
                                 OR k.SicilNo  LIKE @ara + '%'       ESCAPE '\')
              -- ⚠ KOŞUL PARAMETRELİ, string birleştirme DEĞİL. Eski hâli enterpolasyonlu
              --   raw string ile kuruluyordu; bugün güvenliydi (yalnız bool'a bağlı
              --   sabit metin) ama
              --   kalıp riskliydi: oraya bir gün parametre olmayan bir değer girerse
              --   sessizce injection olurdu (security-principles.md).
              AND (@sadeceSorunlu = 0
                   OR k.OlcumNotu IS NOT NULL
                   OR k.Durum IN (N'Devamsız', N'Vardiya Tanımsız Çalışma')
                   OR (k.SayimDisi = 0 AND k.CalismaDk <> k.PlanCalismaDk))
            ORDER BY k.Tarih DESC, k.Sube, k.Personel
            """, new
        {
            userId,
            bas = bas.ToDateTime(TimeOnly.MinValue),
            bit = bit.ToDateTime(TimeOnly.MinValue),
            sube = string.IsNullOrWhiteSpace(sube) ? null : sube,
            ara = string.IsNullOrWhiteSpace(ara) ? null : LikeKacir(ara.Trim()),
            sadeceSorunlu = sadeceSorunlu ? 1 : 0,
            limit,
        });
        return r.AsList();
    }

    /// <summary>
    /// SQL <c>LIKE</c> joker karakterlerini kaçırır. Kaçırılmazsa kullanıcının yazdığı
    /// <c>%</c> süzgeci sessizce genişletir; <c>[</c> ise karakter kümesi açar ve arama
    /// beklenmedik sonuç verir. Injection DEĞİL (sorgu parametreli) ama YANLIŞ SONUÇ.
    /// Kaçış karakteri sorguda <c>ESCAPE '\'</c> ile bildirilir.
    /// </summary>
    private static string LikeKacir(string s) =>
        s.Replace("\\", "\\\\").Replace("%", "\\%").Replace("_", "\\_").Replace("[", "\\[");

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
    public async Task SaveApprovalAsync(string userId, string sicilNo, DateOnly tarih,
        int? girisDk, int? cikisDk, int? ekMesaiDk, string? aciklama, string kaydeden)
    {
        if (string.IsNullOrWhiteSpace(userId))
            throw new ArgumentException("userId boş olamaz — şube kapsamı çözülemez.", nameof(userId));
        if (string.IsNullOrWhiteSpace(sicilNo))
            throw new ArgumentException("SicilNo boş olamaz — kişi-gün kimliği kurulamaz.", nameof(sicilNo));
        foreach (var (ad, v) in new[] { ("Giriş", girisDk), ("Çıkış", cikisDk) })
            if (v is < 0 or > 2880)
                throw new ArgumentOutOfRangeException(ad, $"{ad} dakikası 0-2880 dışında: {v}");
        if (ekMesaiDk is < 0 or > 1440)
            throw new ArgumentOutOfRangeException(nameof(ekMesaiDk), "Ek mesai 0-1440 dakika dışında.");

        using var cn = db.OpenPanel();

        // ⚠ YAZMA TARAFI KAPSAM KAPISI — okuma süzgeci burada YETMEZ.
        //   Okuma sorguları kapsam dışını göstermiyor ama yazma yolu SicilNo+Tarih
        //   ile çağrılıyor; bu değerler ekrandan değil elle de gelebilir. Kapı
        //   olmasaydı bir müdür, görmediği bir şubenin satırına onay yazabilirdi.
        //   Kapsam yine SQL'de çözülüyor — uygulama şube kimliği taşımıyor ((b)-tam).
        //
        //   SESSİZ BAŞARISIZLIK OLMAZ: eşleşme yoksa MERGE'ün hiçbir şey yapmasını
        //   beklemek yerine AÇIKÇA fırlatılır. "Kaydettim" deyip yazmamak, yanlış
        //   şubeye yazmaktan daha kötüdür — kimse fark etmez.
        var kapsamda = await cn.ExecuteScalarAsync<int>("""
            SELECT COUNT(*)
            FROM   bkm.Vrd_KisiGun k
            WHERE  k.SicilNo = @sicilNo AND k.Tarih = @tarih
              AND  k.Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
            """, new { userId, sicilNo, tarih = tarih.ToDateTime(TimeOnly.MinValue) });

        if (kapsamda == 0)
            throw new UnauthorizedAccessException(
                $"Bu kişi-gün kaydı şube kapsamınızda değil (sicil {sicilNo}, {tarih:dd.MM.yyyy}).");

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
