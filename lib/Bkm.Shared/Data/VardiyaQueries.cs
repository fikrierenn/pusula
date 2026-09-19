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
///   devrinde sayılıdır; satır raporda DURUR (hafta bütünlüğü için) ama missing/fazla
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
    // ⚠ `branch` parametresi bir YETKİ DEĞİL, GÖRÜNTÜ FİLTRESİDİR: kapsam İÇİNDE
    //   daraltır. Uydurulmuş bir değer kesişimde düşer, kapsamı genişletemez.
    //
    // ⚠ YAZMA da kapılı (SaveApprovalAsync): okuma süzgeci yazma yolunu korumaz,
    //   çünkü SicilNo+Tarih elle de gelebilir.
    //
    // ⚠ KAPSAM BUGÜNKÜ ACL'DEN çözülür, satırın tarihinden DEĞİL (19.09 düzeltmesi,
    //   GMY itirazı): bugün bir şubeden sorumluysan o şubenin TÜM geçmişini
    //   görürsün — yoksa created atanan müdür kıyas ve tahmin yapamazdı. "O tarihte
    //   kim sorumluydu" ayrı bir sorudur ve `Vrd_KullaniciSubeGecmis_vw`de durur.

    /// <summary>Yazılabilir kesimler (en created önce). Boşsa SP hiç koşmamıştır.</summary>
    public async Task<IReadOnlyList<VrdCutoff>> GetCutoffsAsync(string userId)
    {
        using var cn = db.OpenPanel();
        return await VrdSql.QueryAsync<VrdCutoff>(cn, $"""
            SELECT  CutoffFrom  = KesimBas,
                    CutoffTo    = KesimBit,
                    CountFrom   = SayimBas,
                    PersonDays  = COUNT(*),
                    BranchCount = COUNT(DISTINCT Sube),
                    WrittenAt   = MAX(YazilmaUtc)
            FROM    {VrdSql.PersonDays} k
            GROUP BY KesimBas, KesimBit, SayimBas
            ORDER BY KesimBit DESC, KesimBas DESC
            """, VrdParams.For(userId));
    }

    /// <summary>
    /// Kesim özeti: missing/fazla saat + durum kırılımı.
    /// Eksik/Fazla burada TÜRETİLİR (plan süresi vs gerçekleşen) — SP'nin yazdığı
    /// alanlardan, created bir iş kuralı EKLENMEZ.
    /// </summary>
    public async Task<VrdSummary?> GetSummaryAsync(string userId, DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        return await VrdSql.QuerySingleOrDefaultAsync<VrdSummary>(cn, $"""
            SELECT
                PersonDays  = COUNT(*),
                BranchCount = COUNT(DISTINCT Sube),
                PersonCount = COUNT(DISTINCT NULLIF(SicilNo, '')),
                -- ⚠ SP'nin yazdığı kolonlar OKUNUR, burada YENİDEN HESAPLANMAZ.
                --   Taban `Vrd_CalismaSaati` politika tablosudur; vardiya planının
                --   süresiyle hesaplanırsa yayınlanan Excel'den SAPAR (ölçüldü:
                --   plan tabanı 4.313/4.596 saat vs politika tabanı 6.118/5.024).
                -- ⚠ ETKİN değerler (plan 49): düzeltme varsa onun tabanıyla, yoksa
                --   SP'nin yazdığıyla. Düzeltme yokken ikisi AYNI sayıdır.
                ShortMin    = SUM(ISNULL(EtkinEksikDk, 0)),
                OvertimeMin = SUM(ISNULL(EtkinFazlaDk, 0)),
                CorrectedDays = SUM(CASE WHEN DuzeltildiMi = 1 THEN 1 ELSE 0 END),
                OutOfCount  = SUM(CONVERT(int, SayimDisi)),
                DayRollover = SUM(CONVERT(int, GunDonumu)),
                Suspect     = SUM(CASE WHEN OlcumNotu LIKE @supheli THEN 1 ELSE 0 END),
                -- ⚠ DEVİR BAKİYESİ AYRI TABLODA ama yayınlanan raporun TOPLAMINA
                --   GİRER. Panel yalnız dönemi gösterirse Excel'le 1.858/201 saat
                --   sapar ve iki farklı toplam ortaya çıkar (ölçüldü 17.09.2026).
                -- ⚠ DEVİR DE KAPSAMLI OLMALI (19.09.2026 ölçümü): süzgeçsiz hâlinde
                --   bir şube müdürü kendi döneminin 334 saatini ama TÜM ŞİRKETİN
                --   1.858 saatlik devrini görüyordu. Kapsam bir sorguda BİR KEZ
                --   yazılmakla bitmiyor; her alt-sorgu kendi süzgecini ister.
                CarryShortMin    = (SELECT ISNULL(SUM(EksikDk), 0) FROM {VrdSql.Carryover} d),
                CarryOvertimeMin = (SELECT ISNULL(SUM(FazlaDk), 0) FROM {VrdSql.Carryover} d2)
            FROM {VrdSql.PersonDays} k
            WHERE KesimBas = @bas AND KesimBit = @bit
            """, VrdParams.For(userId).Cutoff(bas, bit)
                          .Add("supheli", VrdConstants.SuspectPattern));
    }

    public async Task<IReadOnlyList<VrdStatus>> GetStatusBreakdownAsync(string userId, DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        return await VrdSql.QueryAsync<VrdStatus>(cn, $"""
            SELECT Status = Durum, PersonDays = COUNT(*)
            FROM   {VrdSql.PersonDays} k
            WHERE  KesimBas = @bas AND KesimBit = @bit
            GROUP BY Durum ORDER BY COUNT(*) DESC
            """, VrdParams.For(userId).Cutoff(bas, bit));
    }

    public async Task<IReadOnlyList<VrdBranch>> GetBranchBreakdownAsync(string userId, DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        return await VrdSql.QueryAsync<VrdBranch>(cn, $"""
            SELECT  Branch      = Sube,
                    PersonDays  = COUNT(*),
                    PersonCount = COUNT(DISTINCT NULLIF(SicilNo, '')),
                    ShortMin    = SUM(ISNULL(EtkinEksikDk, 0)),
                    OvertimeMin = SUM(ISNULL(EtkinFazlaDk, 0))
            FROM    {VrdSql.PersonDays} k
            WHERE   KesimBas = @bas AND KesimBit = @bit
            GROUP BY Sube ORDER BY Sube
            """, VrdParams.For(userId).Cutoff(bas, bit));
    }

    /// <summary>
    /// FAZLA MESAİNİN KAYNAĞI — SP'nin yazdığı kolonlar okunur, türetilmez.
    /// "Ne kadarı fazla çalışma, ne kadarı izin iptali" (GMY sorusu 17.09.2026).
    /// </summary>
    public async Task<VrdOvertimeSource?> GetOvertimeSourceAsync(string userId, DateOnly bas, DateOnly bit, string? branch)
    {
        using var cn = db.OpenPanel();
        return await VrdSql.QuerySingleOrDefaultAsync<VrdOvertimeSource>(cn, $"""
            SELECT ExtraWorkMin      = SUM(ISNULL(FazlaCalismaDk, 0)),
                   LeaveCancelledMin = SUM(ISNULL(FazlaIzinIptalDk, 0)),
                   WeeklyRestMin     = SUM(ISNULL(HaftalikPrimDk, 0)),
                   UnplannedMin      = SUM(ISNULL(FazlaPlansizDk, 0)),
                   AfterCloseMin     = SUM(ISNULL(CikisSonrasiDk, 0)),
                   BeforeOpenMin     = SUM(ISNULL(GirisOncesiDk, 0))
            FROM   {VrdSql.PersonDays} k
            WHERE  KesimBas = @bas AND KesimBit = @bit
              AND (@branch IS NULL OR Sube = @branch)
            """, VrdParams.For(userId).Cutoff(bas, bit).Branch(branch));
    }

    /// <summary>
    /// Kapanış sonrası kalma süre bandı. Uzun kuyruk ayrı bir sorudur: 15 dakikalık
    /// toplanma ile 2 saati aşan kalma AYNI ŞEY DEĞİLDİR ve aynı aksiyonu almaz.
    /// </summary>
    public async Task<IReadOnlyList<VrdStayBand>> GetStayBandsAsync(
        string userId, DateOnly bas, DateOnly bit, string? branch)
    {
        using var cn = db.OpenPanel();
        return await VrdSql.QueryAsync<VrdStayBand>(cn, $"""
            SELECT Band = CASE WHEN CikisSonrasiDk <=  15 THEN N'≤ 15 dk'
                               WHEN CikisSonrasiDk <=  30 THEN N'16–30 dk'
                               WHEN CikisSonrasiDk <=  60 THEN N'31–60 dk'
                               WHEN CikisSonrasiDk <= 120 THEN N'1–2 saat'
                               ELSE N'2 saat üstü' END,
                   DayCount = COUNT(*), Minutes = SUM(CikisSonrasiDk)
            FROM   {VrdSql.PersonDays} k
            WHERE  KesimBas = @bas AND KesimBit = @bit
              AND  ISNULL(CikisSonrasiDk, 0) > 0
              AND (@branch IS NULL OR Sube = @branch)
            GROUP BY CASE WHEN CikisSonrasiDk <=  15 THEN N'≤ 15 dk'
                          WHEN CikisSonrasiDk <=  30 THEN N'16–30 dk'
                          WHEN CikisSonrasiDk <=  60 THEN N'31–60 dk'
                          WHEN CikisSonrasiDk <= 120 THEN N'1–2 saat'
                          ELSE N'2 saat üstü' END
            ORDER BY MIN(CikisSonrasiDk)
            """, VrdParams.For(userId).Cutoff(bas, bit).Branch(branch));
    }

    /// <summary>
    /// MESAİ MEVZUAT KAPISI — `tools/mesai_mevzuat_kapisi.py` ile AYNI eşikler ve
    /// AYNI tanımlar. İki yerde iki farklı sayı çıkarsa biri bayatlamış demektir.
    /// ⚠ Gece süresi 20:00-06:00 kesişimidir; çıkış 1440'ı aşabildiği için pencere
    ///   iki gün için taranır.
    /// ⚠ ŞÜPHELİ satırlar denetim DIŞI.
    /// </summary>
    public async Task<VrdCompliance?> GetComplianceAsync(string userId, DateOnly bas, DateOnly bit)
    {
        using var cn = db.OpenPanel();
        // ⚠ CTE MATERYALİZE EDİLMEZ — beş referans beş yeniden tarama demekti ve
        //   `geceDk` içindeki VALUES alt-sorgusu satır başına koşuyordu.
        //   ÖLÇÜLDÜ (18.09.2026, 6.113 satır): 43,2 sn → komut zaman aşımı, page
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
        return await VrdSql.QuerySingleOrDefaultAsync<VrdCompliance>(cn, $"""
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
            FROM   {VrdSql.PersonDays} k
            WHERE  KesimBas = @bas AND KesimBit = @bit;

            WITH hf AS (
              SELECT SicilNo, hafta = DATEPART(iso_week, Tarih),
                     gun = COUNT(DISTINCT Tarih),
                     dinlenme = SUM(CASE WHEN Izin = 1 OR ISNULL(CalismaDk,0) = 0 THEN 1 ELSE 0 END),
                     toplamDk = SUM(ISNULL(CalismaDk,0))
              FROM #o WHERE supheli = 0
              GROUP BY SicilNo, DATEPART(iso_week, Tarih))
            SELECT
              Daily11      = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND ISNULL(CalismaDk,0) > @gunlukTavan),
              Gross12      = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND GirisDk IS NOT NULL
                                                        AND CikisDk IS NOT NULL AND CikisDk-GirisDk > @brutTavan),
              Night75      = (SELECT COUNT(*) FROM #o WHERE supheli=0 AND geceDk > @geceTavan),
              NoWeeklyRest = (SELECT COUNT(*) FROM hf WHERE gun >= 7 AND dinlenme = 0),
              Over45       = (SELECT COUNT(*) FROM hf WHERE toplamDk > @haftalikNormal),
              Suspect      = (SELECT COUNT(*) FROM #o WHERE supheli = 1);
            """, VrdParams.For(userId).Cutoff(bas, bit)
                          .Add("supheli", VrdConstants.SuspectPattern)
                          // ⚠ Eşikler GÖMÜLÜ SAYI DEĞİL — tek kaynak WorkTimeLimit, Python
                          //   karşılığıyla tools/mesai_esik_denetimi.py karşılaştırıyor.
                          .Add("geceBas", WorkTimeLimit.NightStartMin)
                          .Add("geceBit", WorkTimeLimit.NightEndMin)
                          .Add("geceBas2", WorkTimeLimit.NightStartMin2)
                          .Add("geceBit2", WorkTimeLimit.NightEndMin2)
                          .Add("gunlukTavan", WorkTimeLimit.DailyCapMin)
                          .Add("brutTavan", WorkTimeLimit.DailyGrossCapMin)
                          .Add("geceTavan", WorkTimeLimit.NightCapMin)
                          .Add("haftalikNormal", WorkTimeLimit.WeeklyNormalMin));
    }

    /// <summary>
    /// Kişi-gün listesi. <paramref name="sadeceSorunlu"/> → yalnız missing/fazla saat
    /// doğuran, ölçüm notu taşıyan veya devamsız satırlar.
    /// </summary>
    public async Task<IReadOnlyList<VrdRow>> GetRowsAsync(
        string userId, DateOnly bas, DateOnly bit, string? branch, string? ara, bool sadeceSorunlu, int limit = 400)
    {
        using var cn = db.OpenPanel();
        return await VrdSql.QueryAsync<VrdRow>(cn, $"""
            SELECT TOP (@limit)
                   Branch           = k.Sube,
                   StaffNo          = k.SicilNo,
                   PersonName       = k.Personel,
                   Department       = k.Bolum,
                   JobTitle         = k.Gorev,
                   Date             = k.Tarih,
                   ShiftPlan        = k.EtkinVardiyaTanim,
                   CardInMin        = k.KartGirisDk,
                   CardOutMin       = k.KartCikisDk,
                   InMin            = k.GirisDk,
                   OutMin           = k.CikisDk,
                   GrossMin         = k.BrutDk,
                   BreakMin         = k.MolaDk,
                   WorkMin          = k.CalismaDk,
                   PlanWorkMin      = k.PlanCalismaDk,
                   RequiredMin      = k.EtkinGerekenDk,
                   Net2Min          = k.Net2Dk,
                   WeeklyPremiumMin = k.HaftalikPrimDk,
                   ShortMin         = k.EtkinEksikDk,
                   OvertimeMin      = k.EtkinFazlaDk,
                   Status           = k.Durum,
                   DayRollover      = k.GunDonumu,
                   OutOfCount       = k.SayimDisi,
                   MeasureNote      = k.OlcumNotu,
                   ApprovedInMin    = o.OnayliGirisDk,
                   ApprovedOutMin   = o.OnayliCikisDk,
                   ExtraShiftMin    = o.EkMesaiDk
            FROM        {VrdSql.PersonDays} k
            LEFT  JOIN  bkm.Vrd_Onay   o ON o.SicilNo = k.SicilNo AND o.Tarih = k.Tarih
            WHERE  k.KesimBas = @bas AND k.KesimBit = @bit
              AND (@branch IS NULL OR k.Sube = @branch)
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
            """, VrdParams.For(userId).Cutoff(bas, bit).Branch(branch)
                          .Add("ara", string.IsNullOrWhiteSpace(ara) ? null : LikeKacir(ara.Trim()))
                          .Add("sadeceSorunlu", sadeceSorunlu ? 1 : 0)
                          .Add("limit", limit));
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
    /// PLAN DÜZELTME — eksik vardiya tanımını ve izin gününü düzeltir (plan 49 / V-05).
    ///
    /// NEDEN AYRI TABLO: <c>Vrd_KisiGun</c> yalnız <c>sp_Vrd_KisiGunDoldur</c>
    /// tarafından yazılır. Uygulama oraya yazsaydı SP'nin bir sonraki koşumu
    /// düzeltmeyi SESSİZCE ezerdi. Ölçülen (SP) ile düzeltilen (insan) ayrı durur,
    /// okuma anında <c>Vrd_KisiGunDuzeltilmis_vw</c> ile birleşir.
    ///
    /// ⚠ DÜZELTME HESABI DEĞİŞTİRİR (GMY kararı S1): düzeltilmiş süre eksik/fazlanın
    ///   TABANI olur. Yani bu bir not değil, bir RAKAM değişikliğidir — ekran
    ///   "düzeltilmiş" saymasını göstermek ZORUNDA, yoksa iki farklı toplam doğar.
    ///
    /// ⚠ İZİN İŞARETİ PDKS'Yİ EZMEZ (karar S3): kaynaktaki <c>Izin</c> durur,
    ///   buradaki işaret onun yanına yazılır.
    ///
    /// ⚠ YAZMA TARAFI KAPSAM KAPISI — okuma süzgeci burada YETMEZ: SicilNo+Tarih elle
    ///   de gelebilir. Kapı olmasaydı bir müdür görmediği şubenin gününü düzeltebilirdi.
    ///   Sessiz başarısızlık yok: eşleşme yoksa AÇIKÇA fırlatılır.
    /// </summary>
    public async Task SavePlanCorrectionAsync(
        string userId, string sicilNo, DateOnly tarih,
        string? shiftPlan, int? planStartMin, int? planEndMin, int? planWorkMin,
        bool? onLeave, string? aciklama, string savedBy)
    {
        if (string.IsNullOrWhiteSpace(userId))
            throw new ArgumentException("userId boş olamaz — şube kapsamı çözülemez.", nameof(userId));
        if (string.IsNullOrWhiteSpace(sicilNo))
            throw new ArgumentException("SicilNo boş olamaz — kişi-gün kimliği kurulamaz.", nameof(sicilNo));

        // DB'deki CHECK kısıtlarının ikizi — ama burada da var, çünkü kullanıcıya
        // "kısıt ihlali" değil SEBEBİ söylenmeli. DB tarafı son savunma, bu ilk.
        if ((planStartMin is null) != (planEndMin is null))
            throw new ArgumentException(
                "Başlama ve bitiş İKİSİ BİRDEN verilir ya da hiçbiri — yarım plan bir vardiya tanımlamaz.");
        if (planStartMin is not null && planEndMin <= planStartMin)
            throw new ArgumentException("Bitiş, başlamadan sonra olmalı (sıfır süreli vardiya bir tanım değil).");
        foreach (var (ad, v) in new[] { ("Başlama", planStartMin), ("Bitiş", planEndMin) })
            if (v is < 0 or > 2880)
                throw new ArgumentOutOfRangeException(ad, $"{ad} dakikası 0-2880 dışında: {v}");
        if (planWorkMin is < 0 or > 1440)
            throw new ArgumentOutOfRangeException(nameof(planWorkMin), "Plan süresi 0-1440 dakika dışında.");

        using var cn = db.OpenPanel();

        var kapsamda = await VrdSql.ExecuteScalarAsync<int>(cn, $"""
            SELECT COUNT(*)
            FROM   {VrdSql.PersonDays} k
            WHERE  k.SicilNo = @sicilNo AND k.Tarih = @tarih
            """, VrdParams.For(userId).StaffDay(sicilNo, tarih));

        if (kapsamda == 0)
            throw new UnauthorizedAccessException(
                $"Bu kişi-gün kaydı şube kapsamınızda değil (sicil {sicilNo}, {tarih:dd.MM.yyyy}).");

        var onceki = await VrdSql.QuerySingleOrDefaultAsync<VrdPlanCorrection>(cn, """
            SELECT ShiftPlan    = VardiyaTanim,  PlanStartMin = PlanBaslamaDk,
                   PlanEndMin   = PlanBitisDk,   PlanWorkMin  = PlanCalismaDk,
                   OnLeave      = IzinliMi,      Note         = Aciklama
            FROM   bkm.Vrd_PlanDuzeltme WHERE SicilNo = @sicilNo AND Tarih = @tarih
            """, VrdParams.For(userId).StaffDay(sicilNo, tarih));

        await using var tx = await cn.BeginTransactionAsync();
        var kayitId = $"{sicilNo}|{tarih:yyyy-MM-dd}";

        var bosaltiliyor = shiftPlan is null && planStartMin is null && planWorkMin is null
                        && onLeave is null && string.IsNullOrWhiteSpace(aciklama);

        if (bosaltiliyor)
        {
            // Hepsi boşsa kayıt SİLİNİR — boş bir düzeltme satırı okumada gereksiz
            // eşleşme üretir ve "düzeltildi" işaretini YALANCI yapar.
            if (onceki is null) { await tx.CommitAsync(); return; }

            await VrdSql.ExecuteAsync(cn,
                "DELETE FROM bkm.Vrd_PlanDuzeltme WHERE SicilNo = @sicilNo AND Tarih = @tarih",
                VrdParams.For(userId).StaffDay(sicilNo, tarih), tx);

            await AuditTrail.WriteAsync(cn, "Vrd_PlanDuzeltme", kayitId, AuditTrail.Action.Deleted,
                userId, savedBy, new { Old = onceki }, tx);
            await tx.CommitAsync();
            return;
        }

        await VrdSql.ExecuteAsync(cn, """
            MERGE bkm.Vrd_PlanDuzeltme AS h
            USING (SELECT @sicilNo AS SicilNo, @tarih AS Tarih) AS k
               ON h.SicilNo = k.SicilNo AND h.Tarih = k.Tarih
            WHEN MATCHED THEN UPDATE SET
                 VardiyaTanim = @vardiyaTanim, PlanBaslamaDk = @baslamaDk,
                 PlanBitisDk = @bitisDk, PlanCalismaDk = @calismaDk,
                 IzinliMi = @izinliMi, Aciklama = @aciklama,
                 Kaydeden = @kaydeden, KayitUtc = SYSUTCDATETIME()
            WHEN NOT MATCHED THEN INSERT
                 (SicilNo, Tarih, VardiyaTanim, PlanBaslamaDk, PlanBitisDk,
                  PlanCalismaDk, IzinliMi, Aciklama, Kaydeden)
                 VALUES (@sicilNo, @tarih, @vardiyaTanim, @baslamaDk, @bitisDk,
                         @calismaDk, @izinliMi, @aciklama, @kaydeden);
            """, VrdParams.For(userId).StaffDay(sicilNo, tarih)
                          .Add("vardiyaTanim", string.IsNullOrWhiteSpace(shiftPlan) ? null : shiftPlan.Trim())
                          .Add("baslamaDk", planStartMin)
                          .Add("bitisDk", planEndMin)
                          .Add("calismaDk", planWorkMin)
                          .Add("izinliMi", onLeave)
                          .Add("aciklama", string.IsNullOrWhiteSpace(aciklama) ? null : aciklama.Trim())
                          .Add("kaydeden", savedBy), tx);

        await AuditTrail.WriteAsync(cn, "Vrd_PlanDuzeltme", kayitId,
            onceki is null ? AuditTrail.Action.Created : AuditTrail.Action.Updated,
            userId, savedBy,
            new
            {
                Old = onceki,
                New = new
                {
                    ShiftPlan = shiftPlan, PlanStartMin = planStartMin, PlanEndMin = planEndMin,
                    PlanWorkMin = planWorkMin, OnLeave = onLeave, Note = aciklama,
                },
            }, tx);

        await tx.CommitAsync();
    }

    /// <summary>Plan düzeltmesinin denetim izine yazılan hâli (eski/yeni karşılaştırması).</summary>
    /// ⚠ ALAN ADLARI İNGİLİZCE, SQL'de ALIAS ile eşleniyor (kolon adları Türkçe:
    ///   `VardiyaTanim` vb.). Sıra SQL'deki sırayla AYNI — Dapper pozisyonel record'da
    ///   sırayı sözleşme sayar.
    public sealed record VrdPlanCorrection(
        string? ShiftPlan, int? PlanStartMin, int? PlanEndMin,
        int? PlanWorkMin, bool? OnLeave, string? Note);

    /// <summary>
    /// YÖNETİCİ ONAYI — panelin TEK yazma noktası.
    ///
    /// Hedef <c>BkmPanel</c> (app-local), ERP DEĞİL — <c>erp-write-policy.md</c>
    /// kapsamında bir ERP yazması değildir. Bu veri hiçbir sorgudan çıkmaz; bugüne
    /// kadar Excel hücresinde yaşıyordu ve file yenilenince kayboluyordu. Tablonun
    /// gerçek gerekçesi budur.
    ///
    /// ⚠ <c>ExtraShiftMin</c>'ya GÜN DÖNÜMÜ TELAFİSİ YAZILMAZ — gece mesaisi artık
    ///   otomatik hesaplanıyor; buraya aynı saat girilirse mesai İKİ KEZ sayılır.
    ///   ÖLÇÜLDÜ (17.09.2026): eski Excel'de elle doldurulan 11 satırın 9'u tam
    ///   olarak bu telafiydi. DB tarafında ayrıca CHECK var (0-1440).
    /// </summary>
    public async Task SaveApprovalAsync(string userId, string sicilNo, DateOnly tarih,
        int? inMin, int? outMin, int? extraShiftMin, string? aciklama, string savedBy)
    {
        if (string.IsNullOrWhiteSpace(userId))
            throw new ArgumentException("userId boş olamaz — şube kapsamı çözülemez.", nameof(userId));
        if (string.IsNullOrWhiteSpace(sicilNo))
            throw new ArgumentException("SicilNo boş olamaz — kişi-gün kimliği kurulamaz.", nameof(sicilNo));
        foreach (var (ad, v) in new[] { ("Giriş", inMin), ("Çıkış", outMin) })
            if (v is < 0 or > 2880)
                throw new ArgumentOutOfRangeException(ad, $"{ad} dakikası 0-2880 dışında: {v}");
        if (extraShiftMin is < 0 or > 1440)
            throw new ArgumentOutOfRangeException(nameof(extraShiftMin), "Ek mesai 0-1440 dakika dışında.");

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
        var kapsamda = await VrdSql.ExecuteScalarAsync<int>(cn, $"""
            SELECT COUNT(*)
            FROM   {VrdSql.PersonDays} k
            WHERE  k.SicilNo = @sicilNo AND k.Tarih = @tarih
            """, VrdParams.For(userId).StaffDay(sicilNo, tarih));

        if (kapsamda == 0)
            throw new UnauthorizedAccessException(
                $"Bu kişi-gün kaydı şube kapsamınızda değil (sicil {sicilNo}, {tarih:dd.MM.yyyy}).");

        // ── ÖNCEKİ HÂLİ OKU — iz "ne değişti" diyebilsin ────────────────────
        //   Yalnız created değeri yazan bir iz, denetimde işe yaramaz: "bu saat
        //   elle mi girildi, neyin yerine girildi" sorusunun cevabı eski değerde.
        var onceki = await VrdSql.QuerySingleOrDefaultAsync<VrdApprovalRecord>(cn, """
            SELECT OnayliGirisDk, OnayliCikisDk, EkMesaiDk, Aciklama
            FROM   bkm.Vrd_Onay WHERE SicilNo = @sicilNo AND Tarih = @tarih
            """, VrdParams.For(userId).StaffDay(sicilNo, tarih));

        // ── İŞLEM: onay ve izi BİRLİKTE ya yazılır ya yazılmaz ───────────────
        //   Ayrı işlem olsaydı "onay var, iz yok" aralığı doğardı — ve o aralık
        //   tam olarak denetimin sorduğu yerdir.
        await using var tx = await cn.BeginTransactionAsync();

        var kayitId = $"{sicilNo}|{tarih:yyyy-MM-dd}";

        // Üç alan da boşsa kayıt SİLİNİR — "hepsini temizledim" niyetini boş satır
        // olarak saklamak sonraki okumada gereksiz JOIN eşleşmesi üretir.
        if (inMin is null && outMin is null && extraShiftMin is null && string.IsNullOrWhiteSpace(aciklama))
        {
            if (onceki is null) { await tx.CommitAsync(); return; }   // zaten yok — iz de yazılmaz

            await VrdSql.ExecuteAsync(cn,
                "DELETE FROM bkm.Vrd_Onay WHERE SicilNo = @sicilNo AND Tarih = @tarih",
                VrdParams.For(userId).StaffDay(sicilNo, tarih), tx);

            await AuditTrail.WriteAsync(cn, "Vrd_Onay", kayitId, AuditTrail.Action.Deleted,
                userId, savedBy, new { eski = onceki }, tx);
            await tx.CommitAsync();
            return;
        }

        await VrdSql.ExecuteAsync(cn, """
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
            """, VrdParams.For(userId).StaffDay(sicilNo, tarih)
                          // ⚠ SQL'deki adlar @girisDk/@cikisDk/@ekMesaiDk/@kaydeden.
                          //   Anonim nesne kullanıldığında adlar yerel değişkenlerden
                          //   (inMin/outMin/extraShiftMin/savedBy) geliyordu ve
                          //   HİÇBİRİ EŞLEŞMİYORDU — onay kaydetme yolu çalışmıyordu
                          //   (19.09 bulgusu, boğaz kurulurken çıktı).
                          .Add("girisDk", inMin)
                          .Add("cikisDk", outMin)
                          .Add("ekMesaiDk", extraShiftMin)
                          .Add("aciklama", string.IsNullOrWhiteSpace(aciklama) ? null : aciklama.Trim())
                          .Add("kaydeden", savedBy), tx);

        await AuditTrail.WriteAsync(cn, "Vrd_Onay", kayitId,
            onceki is null ? AuditTrail.Action.Created : AuditTrail.Action.Updated,
            userId, savedBy,
            new
            {
                eski = onceki,
                created = new { ApprovedInMin = inMin, ApprovedOutMin = outMin, ExtraShiftMin = extraShiftMin, Note = aciklama },
            }, tx);

        await tx.CommitAsync();
    }

    /// <summary>Onay kaydının denetim izine yazılan hâli (eski/created karşılaştırması).</summary>
    public sealed record VrdApprovalRecord(int? ApprovedInMin, int? ApprovedOutMin, int? ExtraShiftMin, string? Note);

    /// <summary>Tek kişi-günün onay kaydı — onay ekranının açılışında okunur.</summary>
    public async Task<VrdApprovalRecord?> GetApprovalAsync(string userId, string sicilNo, DateOnly tarih)
    {
        using var cn = db.OpenPanel();
        return await VrdSql.QuerySingleOrDefaultAsync<VrdApprovalRecord>(cn, $"""
            SELECT o.OnayliGirisDk, o.OnayliCikisDk, o.EkMesaiDk, o.Aciklama
            FROM   bkm.Vrd_Onay o
            WHERE  o.SicilNo = @sicilNo AND o.Tarih = @tarih
              AND  EXISTS (SELECT 1 FROM {VrdSql.PersonDays} k
                           WHERE k.SicilNo = o.SicilNo AND k.Tarih = o.Tarih)
            """, VrdParams.For(userId).StaffDay(sicilNo, tarih));
    }
}
