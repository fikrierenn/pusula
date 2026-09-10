using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Satış Analizi paneli sorguları (plan-42). SALT-SELECT — yazma yalnız
/// <see cref="SatisAnaliziTabanService"/>'te (erp-write-policy).
///
/// Ön-agrega <c>bkm.SatisAnaliziTaban</c>'dan okur. NEDEN (ölçüldü, 274.933 ürün):
///   CTE ile her istekte yeniden hesap → sayfa 5,31-5,44 s · KPI 3,15-3,76 s · arama 5,8 s riski
///   tablodan                          → sayfa 17 ms · KPI 196 ms · arama 346 ms · kohort 73 ms
/// ⚠ <c>COUNT(*) OVER ()</c> KULLANILMAZ: sayfa başına 1,2 s ekliyordu (ölçüldü). Toplam bir kez
///   sayılır (34 ms) ve sayfa çevirmede tekrar sorulmaz.
///
/// ⚠ 3-PARÇALI İSİM ZORUNLU: Db.OpenAsync varsayılan katalog = master → 2-parçalı isim Err 208.
///
/// TANIM KANITI: sorgular/2026-09-08-satis-analizi-excel-denetim.sql §10-12.
/// Kardeş emitter: scripts/satis_analizi_excel.py — ikisi AYRIŞMAMALI.
/// </summary>
public sealed partial class SatisAnaliziQueries(
    Db db,
    ILogger<SatisAnaliziQueries> logger,
    Microsoft.Extensions.Caching.Memory.IMemoryCache cache)
{
    /// <summary>
    /// Rapor evreni — ÖLÇÜLDÜ: liste dışı 59.826 çeşidin HİÇBİRİ orijinal raporda yok.
    /// ⚠ Satılabilir ürün kaçırıyor (ıslak mendil 'Kişisel Bakım', WMS'te ~366K adet). Panel
    /// orijinali birebir yansıtsın diye AYNEN korunuyor; düzeltme ayrı iş (plan-42 §8).
    /// </summary>
    /// <remarks>
    /// ⚠ "Kafe Hammede" ÇIKARILDI (kullanıcı kararı 09.09.2026: "kafe hammadde devre dışı
    /// bırakalım"). ÖLÇÜLDÜ (kesim 08.09.2026): kategoride yalnız <b>2 çeşit</b> vardı —
    /// stkID 89918 "KAFE RESTAURANT SATIŞLARI" (hizmet/toplayıcı kalem, MagazaStok −46;
    /// kategori agregasını −21'e düşüren tek sebep) ve 1721975 "Wınboss 20 W. Silikon
    /// Tabanca" (95 adet, yanlış kategorilenmiş gerçek ürün). Toplam 26.504,54 ₺ / 49 adet.
    /// Kafe/restoran operasyonu perakende raf analizinin konusu değil; negatif agrega da
    /// gün-stok gibi türev metrikleri anlamsızlaştırıyordu.
    /// ⚠ "Zkargo" da ÇIKARILDI (aynı gün, kullanıcı: "giderlere ait stoklarda olmamalı
    /// listede o grubu da devre dışı bırak"). ÖLÇÜLDÜ: kategorinin TEK üyesi stkID 79405
    /// <b>"ALIŞ KARGO GİDERİ"</b> — <c>stkKod = '153.10'</c> (muhasebe hesap kodu deseni,
    /// 153 = Ticari Mallar), 12.571 adet, <b>Tutar 0,00 ₺</b>, satış 0. Bir gider kalemi,
    /// mal değil. Panel evrenindeki 275.059 çeşit içinde noktalı stkKod taşıyan TEK kayıt.
    ///
    /// ⚠ ELENEN İKİ ÖLÇÜT (ölçüldü, ikisi de yanlış çıktı — sema'ya bakıp körü körüne
    /// uygulamamak için): (a) <c>urnTip &lt;&gt; 0</c> — tabandaki 275.059 satırın TAMAMI
    /// urnTip=0; gider/hizmet kalemleri bu yoldan hiç sızmıyor (kaynak <c>bkm.UrunBilgi</c>
    /// zaten taşımıyor), süzgeç yalnız ileriye dönük emniyet. (b) <c>satisTur &lt;&gt; 0</c> —
    /// 32 kayıt çıktı ama hepsi GERÇEK ürün (Missim/Çilek Bijuteri fiyat-noktası kartları,
    /// soru bankası); gider işareti DEĞİL.
    /// </remarks>
    public static readonly string[] Kategori3Evreni =
    [
        "Kitap", "Kırtasiye", "Oyuncak", "Çocuk Kitabı", "Hazırlık Kitapları",
        "Akademi", "Hediyelik", "Elektronik", "Dergi", "Spor & Outdoor",
    ];

    private const string Taban = "DerinSISBkm.bkm.SatisAnaliziTaban";

    /// <summary>
    /// SATIŞ HIZI PAYDASI (etkin gün) — <b>TEK TANIM</b>, beş yerde kullanılır (KPI · kırılım ·
    /// temin kırılımı · liste kolonu · akran medyanı). Ayrı ayrı yazılırsa biri düzeltilir
    /// öteki bayatlar.
    ///
    /// = min(365, COALESCE(mağazaya ilk giriş, kart açılışı)'ndan kesime kadar geçen gün),
    /// <b>en az 1</b>.
    ///
    /// ⚠ ALT SINIR 1 ŞART — yoksa SQL 8134 "sıfıra bölünme" patlar. Ölçüldü 09.09.2026:
    /// `IlkGiris` NULL olduğunda devreye giren `AcilisTarihi`, kesimden SONRA olabiliyor
    /// (kart 09.09'da açıldı, kesim 08.09) → <c>DATEDIFF + 1 = 0</c>. Panel "Veri alınamadı"
    /// hatası verdi. Sadece `IlkGiris` kullanılırken bu mümkün değildi (mağaza girişi kesimden
    /// sonra olamaz), COALESCE fallback'i açtı. İlk ölçümüm <c>MIN = 1</c> demişti ama o
    /// ESKİ tabandı — taban yenilenince 09.09 kartları girdi ve sınır aşıldı.
    ///
    /// ⚠ 365'e SABİT bölmek YANLIŞ (kullanıcı uyarısı 09.09): rafa yeni girenin hızı düşük
    /// çıkar, gün-stok şişer. Ölçüldü: 22.385 üründe ort. gün-stok 1.644 → 524.
    /// Her iki tarih de NULL ise 365 (pencerenin tamamı varsayılır).
    /// </summary>
    /// <summary>Tek satır hali — const birleştirmede kullanılır (satır sonu sorunu olmasın).</summary>
    private const string EtkinGunTekSatir =
        "CASE WHEN COALESCE(t.IlkGiris, t.AcilisTarihi) IS NULL THEN 365 " +
        "WHEN DATEDIFF(DAY, COALESCE(t.IlkGiris, t.AcilisTarihi), t.Kesim) + 1 < 1 THEN 1 " +
        "WHEN DATEDIFF(DAY, COALESCE(t.IlkGiris, t.AcilisTarihi), t.Kesim) + 1 < 365 " +
        "THEN DATEDIFF(DAY, COALESCE(t.IlkGiris, t.AcilisTarihi), t.Kesim) + 1 ELSE 365 END";

    private const string EtkinGunSql = """
        CASE WHEN COALESCE(t.IlkGiris, t.AcilisTarihi) IS NULL THEN 365
             WHEN DATEDIFF(DAY, COALESCE(t.IlkGiris, t.AcilisTarihi), t.Kesim) + 1 < 1   THEN 1
             WHEN DATEDIFF(DAY, COALESCE(t.IlkGiris, t.AcilisTarihi), t.Kesim) + 1 < 365 THEN DATEDIFF(DAY, COALESCE(t.IlkGiris, t.AcilisTarihi), t.Kesim) + 1
             ELSE 365 END
        """;

    /// <summary>
    /// SEZON HAZIRLIĞI — geçen sezon sattı, bugün stoğu o satışın YARISINDAN az.
    /// "Stoksuz sezon" kartından FARKLI: orada stok SIFIR, burada VAR ama yetmez.
    /// Panelin son-tarihi olan tek kohortu (sezon Ağu–Eki; sipariş penceresi şimdi).
    /// ✅ 0,50 katsayısı ARTIK ÖLÇÜLDÜ (10.09.2026) — seçilmiş değil, türetilmiş.
    /// Yöntem: AYNI TALEP BANDI içinde gerçekleşme oranı. Talep vekili önceki yılın aynı
    /// sezonu (2024 Ağu–Eki satışı 10-200 adet); kapsama = 01.08.2025 rafı ÷ 2024 satışı;
    /// sonuç = 2025 sezon satışı ÷ 2024. Bantlara göre gerçekleşme:
    ///   &lt;0,25 → <b>0,34</b> · 0,25-0,50 → <b>0,61</b> · 0,50-0,75 → 0,75 · 0,75-1,00 → 0,84
    ///   · 1,00-1,50 → 0,93 · 1,50-3,00 → 1,24 · 3,00+ → 2,22
    /// Tek yönlü ve alt uçta dik; 1,00 kapsamada doyuyor (0,93). <b>0,50</b> = gerçekleşmenin
    /// çöktüğü çizgi (altında önceki yıl talebinin en az %39'u kaybediliyor).
    ///
    /// ⚠ CONFOUND (giderilmedi): TERS NEDENSELLİK — alıcı çok satmasını beklediğine çok stok
    /// koyar, yüksek kapsama zaten yüksek beklentiyi taşır (3,00+ bandı 2,22). Ayrıca
    /// ORTALAMAYA DÖNÜŞ: &lt;0,25 bandı en yüksek 2024 talebine sahip (54 adet). Tablo saf
    /// "bulunurluk etkisi" DEĞİL; ama alt uçtaki 0,34 yalnız bununla açıklanamayacak kadar dik.
    ///
    /// ⛔ ELENEN ÖLÇÜT: "sezon sonunda stok ≤ 0" tükenme vekili olarak denendi — bantlara göre
    /// %0,4-6,6 ve TEK YÖNLÜ DEĞİL (depo sezon içinde takviye ediyor). Karşılanmamış talep
    /// gözlenemez (satmadığının kaydı yok), o yüzden gerçekleşme oranı kullanıldı.
    ///
    /// Türetme SQL'i: <c>sorgular/2026-09-10-esik-turetme-asiri-stok-ve-sezon.sql</c> blok 1.
    /// </summary>
    /// <summary>
    /// AŞIRI STOK — sezon satışının katından fazla stok. Eşik <b>3×</b>.
    ///
    /// ✅ 3× ÖLÇÜLDÜ (10.09.2026), eski 5× SEÇİLMİŞTİ ve gevşek çıktı. Yöntem: 01.08.2025
    /// başlangıç stoğunun SONRAKİ 12 AYDA satılan oranı (yıllık devir), kapsama katına göre:
    ///   &lt;2× → <b>6,36</b> (~2 ay stok) · 2-3× → <b>1,04</b> (~12 ay) · 3-5× → 0,71 (~17 ay)
    ///   · 5-8× → 0,51 (~24 ay) · 8-15× → 0,40 (~30 ay) · 15×+ → 0,23 (~4,3 yıl)
    /// Yıllık devir 1,0'ın ALTINA 3×'te düşüyor — yani 3× "bir yıldan fazla stok" demek.
    /// 5× ise ~24 aylık stok: aşırılığı ancak iki yılı geçince yakalıyordu.
    /// Hiç satmayan payı da aynı yönde: &lt;2× %16,2 → 15×+ %2,7 (uçta mal kilitli kalıyor).
    ///
    /// Etki (kesim 09.09.2026, ölçüldü): 5× → 16.697 çeşit / 238,0M ₺ ·
    /// <b>3× → 29.647 çeşit / 309,9M ₺</b> etiket; maliyetle <b>107,3M ₺</b> bağlı sermaye.
    ///
    /// ⚠ CONFOUND: "yıllık devir" hem stok düzeyini hem talep değişimini taşır (&lt;2× bandının
    /// 6,36'sı sürekli takviye edilen hızlı ürünler). Ölçüt aşırılığı değil DEVRİ ölçüyor —
    /// ama karar değişkeni de devir: 1,0 altı = bir yıldan fazla stok.
    ///
    /// Türetme SQL'i: <c>sorgular/2026-09-10-esik-turetme-asiri-stok-ve-sezon.sql</c> blok 2.
    /// </summary>
    private const string AsiriStokKat = "3";

    /// <summary>
    /// Aşırı stok ölçütü — <b>TEK KAYNAK</b>. KPI, kategori kırılımı, ODAK temin tablosu ve
    /// liste filtresi bunu kullanır; eşik burada değişince hepsi birlikte değişir (önce altı
    /// yerde ayrı ayrı <c>5 *</c> yazılıydı — ayrışma riski).
    /// </summary>
    private const string AsiriStokSart =
        "(t.SezonToplam > 0 AND t.ToplamStok > " + AsiriStokKat + " * t.SezonToplam)";

    private const string SezonHazirlikSart =
        "(t.SezonToplam > 0 AND t.ToplamStok > 0 AND t.ToplamStok < 0.5 * t.SezonToplam)";

    /// <summary>
    /// MAĞAZALAR ARASI DENGESİZLİK — bir rafta stok yok, ötekinde TALEBE GÖRE fazla,
    /// ürün sezonda satıyor. Eylemi transfer; sipariş açmak yanlış karar (mal şirkette).
    ///
    /// ⚠ İKİ EŞİK BİRLİKTE — biri tek başına yetmiyor, İKİSİ DE ÖLÇÜLDÜ 09.09.2026
    /// (kesim 08.09, SonGiris muhafızı açık):
    ///   · yalnız GÖRELİ (≥14 günlük kapsama)     → <b>22.839 çeşit</b> — kohort taşıyor.
    ///     Sebep: yavaş üründe eşik çöküyor; yılda 10 satanda 14 gün = 0,38 adet, yani
    ///     HER stok geçiyor. Göreli ölçüt yavaş-hareketi ayıklamıyor, tam tersini yapıyor.
    ///   · yalnız MUTLAK (≥20 adet)               → 1.241 çeşit. satinalma-danisman itirazı:
    ///     günde 5 satanla yılda 5 satanı aynı sayıyor, talebi hiç görmüyor.
    ///   · GÖRELİ <b>ve</b> MUTLAK ≥5 adet        → <b>4.826 çeşit / 24,78M ₺</b>  ← SEÇİLEN
    ///   · GÖRELİ ve MUTLAK ≥20 adet              → 1.229 çeşit / 10,56M ₺
    /// Seçim: anlamlı MİKTAR (≥5) <b>ve</b> anlamlı KAPSAMA (≥14 gün). Taban 5 seçildi,
    /// ölçülmedi — 20 daralttığı için değil, kırtasiyede 20 adet fazla yüksek olduğu için.
    /// Kapsama çarpımla kurulur (sıfıra bölünme yok): <c>rafStok × etkinGün ≥ 14 × satış365</c>.
    ///
    /// ⚠ YOLDAKİ TRANSFER MUHAFIZI: dengesizlik çoğu zaman "yolda olan mal"dır — ölçüldü
    /// 09.09 (stkID 1739183): Özlüce'ye +480, belge 07.09 ama deftere 09.09 10:12'de düştü.
    /// Yaş filtresi olmadan bu kart en hızlı ürünlerde yanlış-pozitif üretir. Tam çözüm
    /// tek-bacaklı <c>ehTip 13</c> satırlarını ölçmek (tabanda YOK); buradaki
    /// <c>SonGiris &lt; kesim−14</c> bir VEKİL — son 14 günde mal kabulü olan ürün hariç.
    /// </summary>
    private const string DengesizSart =
        "(t.SezonToplam > 0 AND t.SatisToplam > 0 AND t.MagazaStok > 0 " +
        "AND (t.SonGiris IS NULL OR t.SonGiris < DATEADD(DAY, -14, @kesim)) AND (" +
        "(t.StokFsm <= 0 AND ((t.StokOzl >= 5 AND t.StokOzl * (" + EtkinGunTekSatir + ") >= 14 * t.SatisToplam) OR (t.StokIst >= 5 AND t.StokIst * (" + EtkinGunTekSatir + ") >= 14 * t.SatisToplam))) OR " +
        "(t.StokOzl <= 0 AND ((t.StokFsm >= 5 AND t.StokFsm * (" + EtkinGunTekSatir + ") >= 14 * t.SatisToplam) OR (t.StokIst >= 5 AND t.StokIst * (" + EtkinGunTekSatir + ") >= 14 * t.SatisToplam))) OR " +
        "(t.StokIst <= 0 AND ((t.StokFsm >= 5 AND t.StokFsm * (" + EtkinGunTekSatir + ") >= 14 * t.SatisToplam) OR (t.StokOzl >= 5 AND t.StokOzl * (" + EtkinGunTekSatir + ") >= 14 * t.SatisToplam)))))";

    /// <summary>
    /// TAZE STOK süzgeci. <c>TazeGunHaric &gt; 0</c> ise son N günde mal kabulü olan ürünler
    /// DEĞERLENDİRMEDEN çıkarılır (adil-atıf: yeni gelen mal aşırı/hareketsiz sayılmaz).
    /// KPI, kırılım ve listede AYNI şart uygulanır — yoksa KPI ile tablo ayrışır.
    /// </summary>
    /// <summary>
    /// YENİ ÜRÜN SQL SÜZGECİ — "değerlendirilecek kadar zamanı oldu mu".
    ///
    /// ⚠ Bu tek yerde tanımlıdır ve KPI ile liste süzgeci AYNI ifadeyi kullanır; ayrışırsa
    /// kart bir sayı, liste başka sayı gösterir (SayfaSonucu'nun yasakladığı çelişki).
    ///
    /// NEDEN <c>COALESCE(IlkGiris, AcilisTarihi)</c>: yenilik önce MAĞAZAYA ilk girişten
    /// ölçülür; ürün mağazaya hiç girmediyse <c>IlkGiris</c> NULL olur ve eski sürüm onu
    /// sessizce "eski" sayıyordu. Ölçüldü 09.09.2026 (kullanıcı bildirimi, stkID 1739163
    /// "Penna Kar Küresi Peluş" — kartı 04.09.2026'da açılmış, mağazaya hiç girmemiş,
    /// merkezde 1.344 adet, yine de HAREKETSİZ listesinde): 119.434 hareketsiz çeşidin
    /// 4.374'ü son 90 günde yeni (31,34M ₺), 371'i mağazaya hiç girmemiş + yeni açılmış.
    /// İkisi de NULL olan kayıt YOK (ölçüldü: 0) → COALESCE her zaman bir tarih bulur.
    /// </summary>
    private const string YeniDegilSart =
        "COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim)";

    private static string TazeSart(SatisAnaliziFiltre f) => f.TazeGunHaric > 0
        // ⚠ Eski hâli "SonGiris IS NULL OR ..." idi: tarihi bilinmeyeni sessizce ESKİ sayıyordu.
        // Mağazaya hiç girmemiş ürünün SonGiris'i NULL olur (mağaza defterinde kayıt yok) →
        // 4 gün önce açılmış ürün "eski" muamelesi görüyordu (stkID 1739163 vakası, 09.09).
        // Doğrusu: bilinen en yeni tarihe düş — son mal kabulü → mağazaya ilk giriş → kart açılışı.
        ? " AND " + "(COALESCE(t.SonGiris, t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@taze, @kesim))"
        : "";

    /// <summary>Kesim+sezon süzgeci — her sorgunun ilk şartı (index'lerin ön eki).</summary>
    private static object KesimP(SatisAnaliziFiltre f) => new
    {
        kesim = f.Kesim.ToDateTime(TimeOnly.MinValue),
        sezon = (short)f.SezonYil,
        taze = f.TazeGunHaric,
        // YENİLİK EŞİĞİ — ekrandaki "taze gün" kutusuna bağlı; kutu kapalıysa varsayılan.
        // Kullanıcı kararı 09.09: 90 çok uzun, 30-45 aralığı → 45 seçildi (ortası).
        // Ölçüldü: 30g 2.040 çeşit/22,0M ₺ · 45g 2.658/24,6M ₺ · 90g 4.374/31,3M ₺ korur.
        yeniGun = f.TazeGunHaric > 0 ? f.TazeGunHaric : SatisAnaliziFiltre.YeniUrunGunVarsayilan,
    };

    /// <summary>
    /// KPI + Kategori3 kırılımı — tek geçiş, 196 ms.
    /// Aşırı stok eşiği <c>AsiriStokSart</c>'tan gelir (3×, veriden türetildi 10.09).
    /// Kategori bazlı hedef gün-stok politikası (<c>bkm.OneriSiparisKtg3Ondeger</c>) hâlâ BOŞ;
    /// dolduğunda eşik kategoriye göre farklılaşabilir — panel geneli eşiği o zamana kadar tek.
    /// </summary>
    public async Task<SatisAnaliziOzet> GetOzetAsync(SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT t.Kategori3 AS Ad,
                   COUNT(*)                                       AS Cesit,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.ToplamStok)))  AS Stok,
                   -- Gün-stok payı MAĞAZA stoğudur (kapsam asimetrisi düzeltmesi 09.09):
                   -- payda mağaza satışı olduğu için pay da mağaza olmalı. Merkez AYRI.
                   CONVERT(bigint, SUM(CONVERT(bigint, t.MagazaStok)))  AS MagazaStok,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.MerkezStok)))  AS MerkezStok,
                   CONVERT(decimal(18,2), SUM(t.Tutar))           AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SatisToplam))) AS Satis365,
                   CONVERT(float, SUM(CONVERT(float, t.SatisToplam) / {EtkinGunSql})) AS GunlukHiz,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SezonToplam))) AS Sezon,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 THEN 1 ELSE 0 END) AS StoksuzCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0
                        THEN t.SezonToplam * t.SatisFiyat ELSE 0 END))                     AS StoksuzKayip,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 AND t.OdakStok > 0 THEN 1 ELSE 0 END) AS StoksuzOdakCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 AND t.OdakStok > 0
                        THEN t.SezonToplam * t.SatisFiyat ELSE 0 END))                     AS StoksuzOdakKayip,
                   SUM(CASE WHEN {AsiriStokSart} THEN 1 ELSE 0 END) AS AsiriCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {AsiriStokSart}
                        THEN t.Tutar ELSE 0 END))                                          AS AsiriTutar,
                   SUM(CASE WHEN {AsiriStokSart} AND t.OdakStok > 0 THEN 1 ELSE 0 END) AS AsiriOdakCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {AsiriStokSart} AND t.OdakStok > 0
                        THEN t.Tutar ELSE 0 END))                                          AS AsiriOdakTutar,
                   -- Hareketsiz: satış yok + stok var + DEĞERLENDİRİLECEK kadar zamanı olmuş.
                   -- Yenilik koruması olmadan yeni açılan ürün haksız damgalanıyordu (ölçüldü).
                   SUM(CASE WHEN t.SatisToplam <= 0 AND t.ToplamStok > 0
                                 AND COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim)
                            THEN 1 ELSE 0 END) AS HareketsizCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SatisToplam <= 0 AND t.ToplamStok > 0
                        AND COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim)
                        THEN t.Tutar ELSE 0 END))                                          AS HareketsizTutar,
                   -- RAFA HİÇ ÇIKMAMIŞ (kullanıcı isteği 09.09: "gelmiş ama mağazaya gitmemiş
                   -- te bir kpi olmalı"). Merkeze girmiş, mağazaya HİÇ girmemiş → satması
                   -- imkânsız. IlkGiris NULL = mağaza defterinde tek giriş kaydı yok.
                   -- ÖLÇÜLDÜ 09.09: 1.182 çeşit / 142.714 adet / 24,17M ₺; 802'si 90 günden eski.
                   SUM(CASE WHEN t.IlkGiris IS NULL AND t.MerkezStok > 0 THEN 1 ELSE 0 END) AS RafsizCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.IlkGiris IS NULL AND t.MerkezStok > 0
                        THEN t.Tutar ELSE 0 END))                                          AS RafsizTutar,
                   -- RAFTA YOK ama MERKEZDE VAR — daha önce rafa çıkmış, şimdi rafı boş.
                   -- Satışı olanlar KANITLI TALEP + boş raf = kayıp satış (ölçüldü: 3.539
                   -- çeşit / 10,46M ₺, 1.218'inin satışı var). Transferle çözülür, alımla değil.
                   -- ⚠ DÜZELTME 09.09 (kullanıcı bildirimi, stkID 1697931): ölçüt MagazaStok
                   -- TOPLAMI <= 0 idi ve NEGATİF stoğu maskeliyordu — o üründe FSM 5 adet VARDI
                   -- ama İst.Yolu −13 (veri kiri) toplamı −8 yapıyor, ürün "rafı boş" görünüyordu.
                   -- Doğrusu: ÜÇ RAFIN HEPSİ boş. Ölçüldü: 3.539 → 3.533 çeşit (6'sı aslında
                   -- rafta vardı), tutar 10,46M → 10,27M ₺.
                   SUM(CASE WHEN t.IlkGiris IS NOT NULL AND t.MerkezStok > 0
                                 AND t.StokFsm <= 0 AND t.StokOzl <= 0 AND t.StokIst <= 0
                            THEN 1 ELSE 0 END)                                             AS RafBosCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.IlkGiris IS NOT NULL AND t.MerkezStok > 0
                        AND t.StokFsm <= 0 AND t.StokOzl <= 0 AND t.StokIst <= 0 THEN t.Tutar ELSE 0 END))                      AS RafBosTutar,
                   SUM(CASE WHEN t.IlkGiris IS NOT NULL AND t.MerkezStok > 0
                            AND t.StokFsm <= 0 AND t.StokOzl <= 0 AND t.StokIst <= 0
                            AND t.SatisToplam > 0 THEN 1 ELSE 0 END)                       AS RafBosSatisliCesit,
                   -- ⚠ GENİŞLETİLDİ 09.09: eski ölçüt yalnız TOPLAM negatifi görüyordu; merkez
                   -- pozitifse mağaza rafındaki eksi stok gizleniyordu (ölçüldü: 187 çeşit /
                   -- 4,89M ₺ hiçbir ölçütte görünmüyordu; mağaza raflarında −8.160 adet negatif).
                   -- Vaka: stkID 1697931 FSM 5 · İst.Yolu −13 · merkez 600 → toplam 592 "temiz".
                   SUM(CASE WHEN t.StokFsm < 0 OR t.StokOzl < 0 OR t.StokIst < 0 OR t.MerkezStok < 0 OR t.ToplamStok < 0 OR t.SatisFiyat <= 0 THEN 1 ELSE 0 END)  AS KirliCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.ToplamStok < 0 OR t.SatisFiyat <= 0
                        THEN t.Tutar ELSE 0 END))                                          AS KirliTutar,
                   -- YENİ ÜRÜN — "henüz değerlendirilemez" kovası (adil-atıf). Hareketsiz/aşırı
                   -- ölçütleri bu ürünleri KASITLI dışlıyor; kaç çeşit ve ne kadar para o
                   -- kararın DIŞINDA kaldığı görünmeli, yoksa dışlama sessiz kalır.
                   -- Eşik @yeniGun ile AYNI (varsayılan 45) → kartla liste ayrışmaz.
                   SUM(CASE WHEN COALESCE(t.IlkGiris, t.AcilisTarihi) >= DATEADD(DAY, -@yeniGun, @kesim)
                                 AND t.ToplamStok > 0 THEN 1 ELSE 0 END)                   AS YeniCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN COALESCE(t.IlkGiris, t.AcilisTarihi) >= DATEADD(DAY, -@yeniGun, @kesim)
                        AND t.ToplamStok > 0 THEN t.Tutar ELSE 0 END))                     AS YeniTutar,
                   -- MAĞAZALAR ARASI DENGESİZLİK → TRANSFER (ölçüt: DengesizSart, tek yer)
                   SUM(CASE WHEN {DengesizSart} THEN 1 ELSE 0 END)                         AS DengesizCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {DengesizSart}
                        THEN t.Tutar ELSE 0 END))                                          AS DengesizTutar,
                   -- SEZON HAZIRLIĞI (ölçüt: SezonHazirlikSart, tek yer) — eksik adet × fiyat
                   SUM(CASE WHEN {SezonHazirlikSart} THEN 1 ELSE 0 END)                    AS SezonAcikCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {SezonHazirlikSart}
                        THEN (t.SezonToplam - t.ToplamStok) * t.SatisFiyat ELSE 0 END))     AS SezonAcikTutar,
                   SUM(CASE WHEN {SezonHazirlikSart} AND t.OdakStok > 0 THEN 1 ELSE 0 END) AS SezonAcikOdakCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {SezonHazirlikSart} AND t.OdakStok > 0
                        THEN (t.SezonToplam - t.ToplamStok) * t.SatisFiyat ELSE 0 END))     AS SezonAcikOdakTutar,
                   -- ── GERÇEKLEŞEN MARJ + MALİYETLİ DEĞER (kurul #2, 10.09.2026) ──────────
                   -- Kaynak tabandaki yeni kolonlar (BirimMaliyet · PosAdet/Net/Kdv/Brut).
                   -- ⚠ NULL olanlar toplama GİRMEZ: maliyeti bilinmeyen ürünü 0 maliyetle
                   -- toplamak marjı %100 gösterir (sessiz yanlış rakam). Kapsam AYRI ölçülür
                   -- ve ekranda yazılır — dışlama sessiz kalmaz.
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.ToplamStok) * t.BirimMaliyet ELSE 0 END)) AS MaliyetliDeger,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.BirimMaliyet > 0
                        THEN t.Tutar ELSE 0 END))                                          AS MaliyetKapsamEtiket,
                   -- Marj yalnız İKİSİ de bilinen üründe hesaplanır (maliyet VE POS satışı).
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.BirimMaliyet > 0 AND t.PosAdet > 0
                        THEN t.PosNet - t.PosKdv ELSE 0 END))                              AS PosNetKdvHaric,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.BirimMaliyet > 0 AND t.PosAdet > 0
                        THEN CONVERT(decimal(18,4), t.PosAdet) * t.BirimMaliyet ELSE 0 END)) AS SatilanMaliyet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.BirimMaliyet > 0 AND t.PosAdet > 0
                        THEN t.PosBrut ELSE 0 END))                                        AS PosBrutToplam,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.BirimMaliyet > 0 AND t.PosAdet > 0
                        THEN t.PosNet ELSE 0 END))                                         AS PosNetToplam,
                   SUM(CASE WHEN t.BirimMaliyet > 0 AND t.PosAdet > 0 THEN 1 ELSE 0 END)   AS MarjCesit,
                   -- HAREKETSİZLERİN KAÇI HİÇ SATILMAMIŞ (kullanıcı isteği 10.09).
                   -- İki AYRI problem: hiç satılmamış = ALIM hatası · satıyordu durdu =
                   -- TALEP kaybı. Aynı kartta tek sayı olarak toplanınca ayrım kayboluyordu.
                   SUM(CASE WHEN t.SatisToplam <= 0 AND t.ToplamStok > 0
                                 AND COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim)
                                 AND t.SonSatis IS NULL THEN 1 ELSE 0 END)              AS HicSatilmamisCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SatisToplam <= 0 AND t.ToplamStok > 0
                        AND COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim)
                        AND t.SonSatis IS NULL THEN t.Tutar ELSE 0 END))                AS HicSatilmamisTutar,
                   -- Rafa çıkmamış stoğun ADEDİ — o kartın karşı-metriği (tutar zaten
                   -- birincil değerde; ikinci kez tutar göstermek bilgi eklemiyordu).
                   CONVERT(bigint, SUM(CASE WHEN t.IlkGiris IS NULL AND t.MerkezStok > 0
                        THEN t.MerkezStok ELSE 0 END))                                AS RafsizAdet
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon{TazeSart(f)}
            GROUP BY t.Kategori3
            ORDER BY SUM(t.Tutar) DESC
            """;

        await using var conn = await db.OpenAsync();
        var satirlar = (await conn.QueryAsync<OzetSatirRow>(
            new CommandDefinition(sql, KesimP(f), commandTimeout: 120, cancellationToken: ct))).ToList();

        // Merkez depo çıkışı — TALEP DEĞİL, ayrı kutu (danışma kararı 08.09: %72'si grup şirketine).
        var merkezCikis = await MerkezCikisAsync(conn, f, ct);

        var kpi = new SatisAnaliziKpi(
            ToplamStok: satirlar.Sum(x => x.Stok),
            ToplamStokTutar: satirlar.Sum(x => x.Tutar),
            Cesit: satirlar.Sum(x => x.Cesit),
            MagazaStok: satirlar.Sum(x => x.MagazaStok),
            MerkezStok: satirlar.Sum(x => x.MerkezStok),
            PerakendeSatis365: satirlar.Sum(x => x.Satis365),
            MerkezCikis365: merkezCikis.Evrende,
            MerkezCikisEvrenDisi: merkezCikis.EvrenDisi,
            StoksuzSezonCesit: satirlar.Sum(x => x.StoksuzCesit),
            StoksuzSezonKayip: satirlar.Sum(x => x.StoksuzKayip),
            StoksuzSezonOdakVarCesit: satirlar.Sum(x => x.StoksuzOdakCesit),
            StoksuzSezonOdakVarKayip: satirlar.Sum(x => x.StoksuzOdakKayip),
            AsiriStokCesit: satirlar.Sum(x => x.AsiriCesit),
            AsiriStokTutar: satirlar.Sum(x => x.AsiriTutar),
            AsiriStokOdakVarCesit: satirlar.Sum(x => x.AsiriOdakCesit),
            AsiriStokOdakVarTutar: satirlar.Sum(x => x.AsiriOdakTutar),
            HareketsizCesit: satirlar.Sum(x => x.HareketsizCesit),
            HareketsizTutar: satirlar.Sum(x => x.HareketsizTutar),
            RafsizCesit: satirlar.Sum(x => x.RafsizCesit),
            RafsizTutar: satirlar.Sum(x => x.RafsizTutar),
            RafBosCesit: satirlar.Sum(x => x.RafBosCesit),
            RafBosTutar: satirlar.Sum(x => x.RafBosTutar),
            RafBosSatisliCesit: satirlar.Sum(x => x.RafBosSatisliCesit),
            VeriKirliCesit: satirlar.Sum(x => x.KirliCesit),
            VeriKirliTutar: satirlar.Sum(x => x.KirliTutar),
            YeniCesit: satirlar.Sum(x => x.YeniCesit),
            YeniTutar: satirlar.Sum(x => x.YeniTutar),
            DengesizCesit: satirlar.Sum(x => x.DengesizCesit),
            DengesizTutar: satirlar.Sum(x => x.DengesizTutar),
            SezonAcikCesit: satirlar.Sum(x => x.SezonAcikCesit),
            SezonAcikTutar: satirlar.Sum(x => x.SezonAcikTutar),
            SezonAcikOdakCesit: satirlar.Sum(x => x.SezonAcikOdakCesit),
            SezonAcikOdakTutar: satirlar.Sum(x => x.SezonAcikOdakTutar),
            MaliyetliDeger: satirlar.Sum(x => x.MaliyetliDeger),
            MaliyetKapsamEtiket: satirlar.Sum(x => x.MaliyetKapsamEtiket),
            PosNetKdvHaric: satirlar.Sum(x => x.PosNetKdvHaric),
            SatilanMaliyet: satirlar.Sum(x => x.SatilanMaliyet),
            PosBrutToplam: satirlar.Sum(x => x.PosBrutToplam),
            PosNetToplam: satirlar.Sum(x => x.PosNetToplam),
            MarjCesit: satirlar.Sum(x => x.MarjCesit),
            HicSatilmamisCesit: satirlar.Sum(x => x.HicSatilmamisCesit),
            HicSatilmamisTutar: satirlar.Sum(x => x.HicSatilmamisTutar),
            RafsizAdet: satirlar.Sum(x => x.RafsizAdet),
            // Hızlar ürün bazında kendi raf süresine bölünüp SQL'de toplandı → burada topla, BÖLME.
            PerakendeGunlukHiz: satirlar.Sum(x => x.GunlukHiz));

        var kirilim = satirlar.Select(x => new SatisAnaliziKirilim(
            x.Ad, x.Cesit, x.Stok, x.Tutar, x.Satis365, x.Sezon, x.StoksuzCesit, x.AsiriTutar,
            GunlukHiz: x.GunlukHiz)).ToList();

        logger.LogInformation("Satış Analizi özet: {Cesit} çeşit / {Kat} kategori, kesim {Kesim}",
            kpi.Cesit, kirilim.Count, f.Kesim);
        return new SatisAnaliziOzet(kpi, kirilim);
    }

    /// <summary>Kategori1 (KatAna) kırılımı — seçili Kategori3 içinde drill.</summary>
    public async Task<IReadOnlyList<SatisAnaliziKirilim>> GetKategori1Async(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT TOP 30 t.Kategori1 AS Ad, COUNT(*) AS Cesit,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.ToplamStok)))  AS Stok,
                   CONVERT(decimal(18,2), SUM(t.Tutar))           AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SatisToplam))) AS Satis365,
                   CONVERT(float, SUM(CONVERT(float, t.SatisToplam) / {EtkinGunSql})) AS GunlukHiz,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SezonToplam))) AS Sezon,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 THEN 1 ELSE 0 END) AS StoksuzCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {AsiriStokSart}
                        THEN t.Tutar ELSE 0 END)) AS AsiriTutar
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
              AND (@kategori3 IS NULL OR t.Kategori3 = @kategori3){TazeSart(f)}
            GROUP BY t.Kategori1
            ORDER BY SUM(t.Tutar) DESC
            """;
        await using var conn = await db.OpenAsync();
        var p = new DynamicParameters(KesimP(f));
        p.Add("kategori3", f.Kategori3);
        return (await conn.QueryAsync<SatisAnaliziKirilim>(
            new CommandDefinition(sql, p, commandTimeout: 120, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// Yayınevi kırılımı — iade/konsinye koşulu yayınevi bazlı olduğu için karar tarafında şart
    /// (satinalma-danisman 08.09). ⚠ İade hakkı VERİDE İZLİ DEĞİL (ölçüldü: urn.alimIadeYok sabit 2,
    /// frm.frmIadeKural lookup'sız) → ekranda bu sınır yazılır.
    /// </summary>
    public async Task<IReadOnlyList<SatisAnaliziKirilim>> GetYayineviAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT TOP 30 ISNULL(t.Yayinevi, N'(tanımsız)') AS Ad, COUNT(*) AS Cesit,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.ToplamStok)))  AS Stok,
                   CONVERT(decimal(18,2), SUM(t.Tutar))           AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SatisToplam))) AS Satis365,
                   CONVERT(float, SUM(CONVERT(float, t.SatisToplam) / {EtkinGunSql})) AS GunlukHiz,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SezonToplam))) AS Sezon,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 THEN 1 ELSE 0 END) AS StoksuzCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {AsiriStokSart}
                        THEN t.Tutar ELSE 0 END)) AS AsiriTutar
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
              AND (@kategori3 IS NULL OR t.Kategori3 = @kategori3){TazeSart(f)}
            GROUP BY t.Yayinevi
            ORDER BY SUM(t.Tutar) DESC
            """;
        await using var conn = await db.OpenAsync();
        var p = new DynamicParameters(KesimP(f));
        p.Add("kategori3", f.Kategori3);
        return (await conn.QueryAsync<SatisAnaliziKirilim>(
            new CommandDefinition(sql, p, commandTimeout: 120, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// ODAK temin süresi kırılımı — "5 günde gelen mal için ne kadar stok tutuyoruz" sorusu.
    /// ÖLÇÜLDÜ 08.09: aşırı stok + ODAK'ta var kohortunun %97'si (131,4M ₺) ≤5 gün temin süreli.
    /// </summary>
    public async Task<IReadOnlyList<TeminKirilim>> GetTeminKirilimAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT CASE WHEN t.LeadTime IS NULL THEN N'bilinmiyor'
                        WHEN t.LeadTime <= 3  THEN N'≤3 gün'
                        WHEN t.LeadTime <= 5  THEN N'4-5 gün'
                        WHEN t.LeadTime <= 7  THEN N'6-7 gün'
                        WHEN t.LeadTime <= 10 THEN N'8-10 gün'
                        WHEN t.LeadTime <= 15 THEN N'11-15 gün'
                        ELSE N'16+ gün' END AS Ad,
                   MIN(ISNULL(t.LeadTime, 999)) AS Sira,
                   COUNT(*) AS Cesit,
                   CONVERT(decimal(18,2), SUM(t.Tutar)) AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.OdakStok))) AS OdakStok
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
              AND {AsiriStokSart} AND t.OdakStok > 0{TazeSart(f)}
            GROUP BY CASE WHEN t.LeadTime IS NULL THEN N'bilinmiyor'
                          WHEN t.LeadTime <= 3  THEN N'≤3 gün'
                          WHEN t.LeadTime <= 5  THEN N'4-5 gün'
                          WHEN t.LeadTime <= 7  THEN N'6-7 gün'
                          WHEN t.LeadTime <= 10 THEN N'8-10 gün'
                          WHEN t.LeadTime <= 15 THEN N'11-15 gün'
                          ELSE N'16+ gün' END
            ORDER BY MIN(ISNULL(t.LeadTime, 999))
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<TeminKirilim>(
            new CommandDefinition(sql, KesimP(f), commandTimeout: 120, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// Merkez depo çıkışı (ehMekan=12, ehTip 1/3/5/101) — 365 gün, iade netlenmiş.
    /// ⚠ TÜKETİCİ TALEBİ DEĞİL: %72'si grup şirketine (frmID 56), %16'sı ODAK'a (ölçüm 08.09).
    /// Raf gün-stoğuna GİRMEZ; ayrı gösterilir. Çıkış ayrıca SIÇRAMALI (%67 tek günde) →
    /// merkez için gün-stok hesaplanmaz.
    ///
    /// ⚠ İKİ SAYI DÖNER — ÇELİŞKİYİ ÖNLEMEK İÇİN (09.09.2026):
    /// İlk sürüm TÜM evreni sayıyordu (1.895.799) ama ürün-bazlı <c>MerkezCikis</c> kolonunun
    /// toplamı 1.215.293'tü; ekranda aynı şey için iki rakam görünüyordu. Sebep ÖLÇÜLDÜ:
    /// merkez çıkışının 1.139 çeşidi / 670.659 adedi panel evreninin (Kategori3'ün 12 değeri)
    /// DIŞINDA. Artık <c>Evrende</c> = panelin kendi evreni (kolon toplamıyla tutar),
    /// <c>EvrenDisi</c> = kategori filtresi yüzünden görünmeyen kısım — ekranda AYRI yazılır,
    /// sessizce yutulmaz (kapsam hatası #2, Excel denetimi 08.09).
    /// </summary>
    private static async Task<(long Evrende, long EvrenDisi)> MerkezCikisAsync(
        System.Data.Common.DbConnection conn, SatisAnaliziFiltre f, CancellationToken ct)
    {
        const string sql = """
            SELECT CONVERT(bigint, ISNULL(SUM(CASE WHEN t.stkID IS NOT NULL THEN x.Cikis END), 0)) AS Evrende,
                   CONVERT(bigint, ISNULL(SUM(CASE WHEN t.stkID IS NULL     THEN x.Cikis END), 0)) AS EvrenDisi
            FROM (
                SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Cikis
                FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
                WHERE h.ehMekan = 12 AND h.ehTip IN (1, 3, 5, 101)
                  AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
                GROUP BY h.ehstkID
                HAVING -SUM(h.ehAdetN) > 0
            ) x
            LEFT JOIN DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
                   ON t.stkID = x.stkID AND t.Kesim = @kesim AND t.SezonYil = @sezon
            """;
        var cmd = new CommandDefinition(sql,
            new
            {
                bas = f.Baslangic.ToDateTime(TimeOnly.MinValue),
                kesim = f.Kesim.ToDateTime(TimeOnly.MinValue),
                sezon = (short)f.SezonYil,
            },
            commandTimeout: 180, cancellationToken: ct);
        var r = await conn.QuerySingleAsync<(long Evrende, long EvrenDisi)>(cmd);
        return r;
    }

    private sealed record OzetSatirRow(
        string Ad, int Cesit, long Stok, long MagazaStok, long MerkezStok, decimal Tutar, long Satis365, double GunlukHiz, long Sezon,
        int StoksuzCesit, decimal StoksuzKayip, int StoksuzOdakCesit, decimal StoksuzOdakKayip,
        int AsiriCesit, decimal AsiriTutar, int AsiriOdakCesit, decimal AsiriOdakTutar,
        int HareketsizCesit, decimal HareketsizTutar,
        int RafsizCesit, decimal RafsizTutar,
        int RafBosCesit, decimal RafBosTutar, int RafBosSatisliCesit,
        int KirliCesit, decimal KirliTutar,
        int YeniCesit, decimal YeniTutar,
        int DengesizCesit, decimal DengesizTutar,
        int SezonAcikCesit, decimal SezonAcikTutar,
        int SezonAcikOdakCesit, decimal SezonAcikOdakTutar,
        decimal MaliyetliDeger, decimal MaliyetKapsamEtiket,
        decimal PosNetKdvHaric, decimal SatilanMaliyet,
        decimal PosBrutToplam, decimal PosNetToplam, int MarjCesit,
        int HicSatilmamisCesit, decimal HicSatilmamisTutar, long RafsizAdet);
}

/// <summary>Sayfa açılışında tek geçişte gelen özet: KPI + Kategori3 kırılımı.</summary>
public sealed record SatisAnaliziOzet(SatisAnaliziKpi Kpi, IReadOnlyList<SatisAnaliziKirilim> Kategori3);

/// <summary>ODAK temin süresi bandı kırılımı.</summary>
public sealed record TeminKirilim(string Ad, int Sira, int Cesit, decimal Tutar, long OdakStok);
