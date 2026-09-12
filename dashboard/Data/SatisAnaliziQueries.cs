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
    /// <summary>
    /// DEFTER GÜVENİLİR ÖN-ŞARTI — <b>tek kaynak</b>, bulunurluk/kayıp/eylem kartlarının
    /// hepsinde uygulanır.
    ///
    /// Kullanıcı denetimi 10.09.2026 ("diğerlerinde de benzer tuzaklar olabilir tüm kpi ları
    /// bir danışmana kontrol ettir"). Bulunan desen: <c>StokX &lt;= 0</c> yazan her ölçüt
    /// NEGATİF defter stoğunu da "boş/yok" sayıyordu. Negatif stok fiziksel bir durum DEĞİL,
    /// defter hatasıdır: mal girişi karta yazılmamış, satış yazılmıştır (vaka stkID 643638
    /// "Missim Bijuteri 49,50 Tl" — 11 alış hareketi karşısında 1.106 satış hareketi).
    /// Böyle bir kayıttan "raf boş" ya da "stok yok" sonucu çıkarılamaz.
    ///
    /// ÖLÇÜLDÜ (kesim 09.09.2026, evren 275.385): güvenilmez <b>327 çeşit</b> (%0,12) —
    /// küçük ama tutar etkisi orantısız, çünkü bu kartlar yüksek satışlı fiyat kartları:
    ///   · Stokta Yokluk: 49 çeşidi negatif, kayıp <b>1.972.350 ₺</b> = kartın %8,5'i
    ///   · Raf Bulunurluk: 11 çeşit · Sezon Açığı: 62 çeşitte bir raf negatif
    ///   · Aşırı Stok: <b>0</b> kaçak (matematik zaten koruyordu)
    ///
    /// ⚠ KART 1 (Envanter Değeri) bu şartı UYGULAMAZ — o kart evrenin TOPLAM değerini
    /// gösterir; güvenilmez kayıtları çıkarmak toplam bilançoyu yanlış yapar. Onlar
    /// "doğrulanamıyor" satırında ayrıca beyan edilir.
    /// </summary>
    /// <summary>
    /// ÖLÜ STOK ölçütü — 365 günde satmadı, stok var, değerlendirilecek kadar zamanı olmuş.
    ///
    /// ⚠ ÜÇ DÜZELTME 10.09.2026 denetiminden (B3 + B6):
    /// (1) <b>POS ÇELİŞKİSİ</b> — bağımsız kaynak. ERP defteri "365 günde satış yok" derken
    ///     POS'ta satış görünen <b>348 çeşit / 1.686.915 ₺</b> vardı (ölçüldü). İki kaynak
    ///     çelişiyorsa ürün ÖLÜ sayılamaz; kararı (iade/imha) yanlış çeşit üstüne kurar.
    ///     Ek olarak 61 çeşitte <c>SatisToplam &lt; 0</c> (iade &gt; satış) — onlar da satmış.
    /// (2) <b>RAFA HİÇ ÇIKMAMIŞ ayrıldı</b> — <b>895 çeşit / 9.711.542 ₺</b> aynı anda
    ///     "ölü stok" ve "Rafa Çıkmamış Envanter" kartındaydı. İki kart ZIT eylem öneriyor:
    ///     ölü stok "iade/imha", rafa çıkmamış "rafa çıkar". Satması imkânsız olan mala
    ///     ölü damgası vurmak haksız — <c>IlkGiris IS NOT NULL</c> şartı onları ayırıyor.
    /// (3) Defter güvenilir ön-şartı.
    /// Etki: 116.924 → <b>115.670 çeşit</b> · 154,0M → <b>142,6M ₺</b>.
    /// </summary>
    private const string OluStokSart =
        "(t.SatisToplam <= 0 AND t.ToplamStok > 0 " +
        // B-172(e) GAMING KAPISI (12.09.2026): eşik 0 → 1. TEK POS satışı ürünü ölü stok
        // kohortundan çıkarıyordu (personel/iç kart satışı yeter). ÖLÇÜLDÜ: açık fiilen
        // KÜÇÜK — tek satışla çıkan 9 çeşit / 29.116 ₺ etiket / 14.915 ₺ maliyet, kohort
        // 115.923 çeşit / 144,2M ₺ (çeşidin %0,008'i). Kapı yine de kapatıldı: maliyeti
        // sıfır, tersi bir gün ısırır.
        // ⚠ "FARKLI GÜNLERDE" ŞARTI UYGULANMADI — tabanda POS gün sayısı yok, eklemek
        // taban şeması değişikliği demek ve 9 çeşitlik evren için orantısız. Bu bir
        // ÖLÇÜLMÜŞ erteleme (TODO B-172e), tahmin değil.
        "AND (t.PosAdet IS NULL OR t.PosAdet <= 1) " +
        "AND t.IlkGiris IS NOT NULL " +
        "AND " + YeniDegilSart + " AND " + DefterGuvenilirSart + ")";

    /// <summary>
    /// STOKTA YOKLUK — geçen sezon sattı, bugün hiç stok yok. <b>B1 düzeltmesi 10.09.2026:</b>
    /// ölçüt <c>ToplamStok &lt;= 0</c> idi ve NEGATİF defteri de "yok" sayıyordu.
    /// ÖLÇÜLDÜ: 8.102 çeşidin 49'u negatif ve kayıp tutarı <b>1.972.350 ₺</b> = kartın
    /// 23,1M ₺'sinin <b>%8,5'i</b>. Çeşit başına ortalama 40.252 ₺ — evren ortalamasının çok
    /// üstünde, çünkü bunlar yüksek satışlı FİYAT KARTLARI (bkz. <c>DefterGuvenilirSart</c>).
    /// Gerçek yokluk <c>= 0</c>; negatif olan defter hatasıdır ve o kayıtlar
    /// "doğrulanamıyor" satırında sayılır. Kart 8.102 → <b>8.041 çeşit / 21,0M ₺</b>.
    /// </summary>
    private const string StoksuzSezonSart =
        "(t.SezonToplam > 0 AND t.ToplamStok = 0 AND " + DefterGuvenilirSart + ")";

    /// <summary>
    /// RAF BULUNURLUK KAYBI — daha önce rafa çıkmış, bugün ÜÇ rafın hepsi boş, merkezde mal var.
    ///
    /// ⚠ <b>B2 düzeltmesi 10.09.2026 — varlık şartı yeterlilik şartı sanılıyordu.</b>
    /// <c>MerkezStok &gt; 0</c> "merkezde mal var → transfer" diye okunuyordu; ÖLÇÜLDÜ:
    /// 3.476 çeşidin <b>1.808'i (%52) merkezde ≤2 adet</b> taşıyor (1.896.000 ₺). Kart
    /// yarısında transfer edilecek mal olmadan "mal var" diyordu.
    ///
    /// ══ AYRAÇ MERKEZ STOĞU DEĞİL, TALEP — geriye dönük ölçümle bulundu ═══════════
    /// İlk düzeltmede yeterlilik ölçütü <c>MerkezStok &gt;= 5</c> seçilmişti ve bu ÖLÇÜMLE
    /// TÜRETİLMEMİŞTİ (panel içi tutarlılıktan geliyordu). Borç kapatıldı: 01.08.2025
    /// as-of'unda rafı boş + merkezinde mal olan ürünler bulundu, SONRAKİ 12 AYDA satıldı mı
    /// ölçüldü.
    ///
    /// MERKEZ STOĞU AYIRT ETMİYOR (sonraki yıl satma oranı, merkez adedine göre):
    ///   1 adet %3,2 · 2 %4,9 · 3-4 %8,2 · <b>5-9 %7,4</b> · 10-24 %6,4 · 25+ %11,9
    ///   → tek yönlü DEĞİL (3-4 → 5-9 düşüyor) ve hiçbir bant %12'yi geçmiyor.
    ///
    /// ÖNCEKİ YIL TALEBİ AYIRT EDİYOR (aynı kohort, aynı sonuç değişkeni):
    ///   talep kanıtı YOK → <b>%3,5</b> (8.736 çeşit) · 1-4 adet → %13,3 (1.330) ·
    ///   <b>5-19 → %38,4</b> (229) · 20-49 → %57,4 (47) · 50+ → %60,0 (10)
    ///   → tek yönlü, dik ve 1-4 → 5-19 arasında ÜÇ KAT sıçrama var.
    /// ⇒ Eşik doğru yerdeydi (5) ama YANLIŞ DEĞİŞKENDE. Ölçüt <c>SatisToplam &gt;= 5</c>.
    /// <c>MerkezStok &gt;= 5</c> eklenmedi — ölçüm desteklemiyor (200 çeşide düşürüp
    /// ayırt edici güç katmıyor).
    ///
    /// ⚠ EN ÖNEMLİ SONUÇ: talep kanıtı OLMAYAN 8.736 çeşidin sonraki yıl satma oranı %3,5 —
    /// bu bir BULUNURLUK KAYBI değil ÖLÜ STOK'tur. Eski ölçüt onları kartta tutuyordu.
    /// Kart 3.464 → <b>448 çeşit / 2.069.830 ₺</b> · merkezde 8.021 adet.
    ///
    /// ══ İSTATİSTİK — kabul görmüş yöntemle sınandı (kullanıcı isteği 10.09.2026) ═══
    /// Bantlara gözle bakmak yetmez; iki ölçüt <b>Cochran-Armitage trend testi</b> (ki-kare
    /// 1 sd, sıralı gruplarda oran trendi) ve oranlara <b>Wilson skor aralığı</b> ile sınandı
    /// (n 10 ile 8.736 arasında değişiyor; normal yaklaşım bu uçlarda güvenilmez):
    ///   MERKEZ STOĞU:  chi2(1) = <b>95,6</b> · p = 1,4e-22 — ama desen <b>MONOTON DEĞİL</b>
    ///     (3,2 → 4,9 → 8,2 → <b>7,4 → 6,4</b> → 11,9) ve iki komşu bant GA'sı ÇAKIŞIK.
    ///   ÖNCEKİ YIL TALEBİ: chi2(1) = <b>873,0</b> · p = 7,2e-192 · <b>MONOTON</b>
    ///     (3,5 → 13,3 → 38,4 → 57,4 → 60,0); 1-4 %13,3 [11,6-15,2] ile 5-19 %38,4
    ///     [32,4-44,9] GA'ları ÇAKIŞMIYOR → 5 kesimi destekli.
    /// ⚠ DERS: merkez ekseninde p değeri son derece küçük OLDUĞU HÂLDE ölçüt geçersiz —
    /// Cochran-Armitage yalnız DOĞRUSAL trende karşı güçlüdür, U-şeklini/monoton olmayanı
    /// kaçırır. Küçük p tek başına bir ölçütü doğrulamaz; monotonluk + GA ayrışması şart.
    /// ⚠ Üst iki bant (n=47 ve n=10) TEK BAŞINA güvenilmez — GA'ları çakışıyor; 20-49 ile
    /// 50+ arasında ayrım yapılmadı, ikisi de "5+" içinde.
    ///
    /// ⚠⚠ KESİM VERİDEN SEÇİLDİ → ETKİ BÜYÜKLÜĞÜ ŞİŞKİN (Altman &amp; Royston 2006, BMJ
    /// "The cost of dichotomising continuous variables"; Royston/Altman/Sauerbrei 2006,
    /// Stat Med "Dichotomizing continuous predictors in multiple regression: a bad idea").
    /// Veriden türetilen "optimal kesim" spuriously significant sonuç ve gruplar arası farkın
    /// AŞIRI tahmini riski taşır. Bu yüzden kesimdeki oran farkı (%13,3 → %38,4) bir ETKİ
    /// ölçüsü olarak SUNULMAZ — yalnız kohort seçiminde kullanılır. Aynı literatür sürekli
    /// değişkeni ikiye bölmemeyi (spline/kesirli polinom) önerir; panel bir KOHORT LİSTESİ
    /// ürettiği için kesim zorunlu, ama bedeli beyan edilir.
    ///
    /// ⚠ ÖLÇÜM SINIRI: as-of merkez stoğu WMS'ten DEĞİL defterden alındı (WMS geçmişi yok) —
    /// merkez tarafı bu yüzden zaten şüpheliydi; sonuç değişkeni (mağaza satışı) etkilenmiyor.
    /// Bir bantta merkez adet toplamı absürt çıktı (33,8M) → tek üründe defter patlaması;
    /// çeşit-bazlı oranı bozmuyor.
    /// </summary>
    private const string RafBosSart =
        "(t.IlkGiris IS NOT NULL AND t.MerkezStok > 0 AND t.SatisToplam >= 5 " +
        "AND t.StokFsm <= 0 AND t.StokOzl <= 0 AND t.StokIst <= 0 " +
        "AND " + DefterGuvenilirSart + ")";

    /// <summary>
    /// RAFA ÇIKMAMIŞ ENVANTER — merkeze girmiş, mağazaya HİÇ girmemiş. Satması imkânsız.
    /// ⚠ B9: 1.068 çeşidin 129'unda (%12) merkezde ≤2 adet var; karşı-metrik ADET
    /// gösterdiği için yanıltma sınırlı, ölçüt daraltılmadı — beyan yeterli sayıldı.
    /// Defter güvenilir ön-şartı eklendi (1.068 → 1.065).
    /// </summary>
    private const string RafsizSart =
        "(t.IlkGiris IS NULL AND t.MerkezStok > 0 AND " + DefterGuvenilirSart + ")";

    /// <summary>
    /// DOĞRULANAMAYAN KAYIT — negatif stok ya da fiyatı 0. <b>B5 düzeltmesi 10.09.2026:</b>
    /// çeşit sayısı 6 koşuldan geliyordu ama TUTAR yalnız 2 koşuldan
    /// (<c>ToplamStok &lt; 0 OR SatisFiyat &lt;= 0</c>) → ekranda "327 çeşit … −2.142.316 ₺"
    /// derken sayı ile para AYNI KÜMEDEN DEĞİLDİ (tutar yalnız 106 çeşidi kapsıyordu).
    /// Artık ikisi de bu tek ifadeden gelir; tam tutar <b>931.395 ₺</b>.
    /// </summary>
    private const string DefterGuvenilmezSart = "(NOT " + DefterGuvenilirSart + ")";

    /// <summary>
    /// TALEP DESENİ SINIFLARI — Syntetos/Boylan/Croston (2005) dörtlü sınıflandırması.
    /// Eşikler <b>ADI = 1,32</b> (ortalama talep-arası aralık, ay) ve <b>CV² = 0,49</b>
    /// (sıfır-olmayan talep büyüklüklerinin kareli değişim katsayısı).
    ///
    /// ⚠⚠ BU EŞİKLER YAYINLANMIŞTIR, VERİDEN TÜRETİLMEDİ — ve bu bilinçli bir seçim.
    /// Altman &amp; Royston (2006) uyarısı: veriden seçilen "optimal kesim" gruplar arası
    /// farkı abartır ve tekrarlanabilirliği düşüktür. Panelin diğer üç eşiği (aşırı stok 3× ·
    /// sezon 0,50 · raf kaybı 5 satış) o uyarıya tabidir; bu ikisi DEĞİL, çünkü dışarıdan
    /// gelir ve BKM verisine bakılarak seçilmemiştir.
    ///
    /// NEDEN GEREKLİ — ÖLÇÜLDÜ 10.09.2026 (Eyl 2025 – Ağu 2026, 12 tam ay, 275.385 çeşit):
    ///   hiç satmadı  121.411 (%44,1) · stok <b>194,6M ₺</b> (%19,1) · satış 4.027
    ///   DÜZGÜN        11.156  (%4,1) · stok 139,7M (%13,7) · satış <b>1.946.808</b>
    ///   DEĞİŞKEN       6.671  (%2,4) · stok 160,6M (%15,7) · satış 1.572.201
    ///   ARALIKLI     121.590 (%44,2) · stok <b>396,6M ₺</b> (%38,8) · satış 944.251
    ///   SIÇRAMALI     14.557  (%5,3) · stok 129,4M (%12,7) · satış 667.757
    /// ⇒ Satışın <b>%68,5'i</b> yalnız %6,5 çeşitten (DÜZGÜN+DEĞİŞKEN) geliyor; stoğun
    ///   <b>%57,9'u (591,2M ₺)</b> aralıklı ya da hiç satmayan çeşitlerde ve satışın oradan
    ///   payı yalnız %18,5.
    /// ⇒ "Gün-stok" ve "günlük ortalama satış" YALNIZ ADI ≤ 1,32 olan %6,5'te güvenilir.
    ///
    /// Kaynak: Croston 1972 · Syntetos-Boylan 2005 (SBA, Croston'ın yanlılığını düzeltir) ·
    /// Syntetos/Boylan/Croston 2005 (sınıflandırma) · Teunter/Syntetos/Babai 2011 (TSB,
    /// eskime için sıfır-talep olasılığını ayrı izler).
    /// ⚠ SBA/TSB TAHMİNİ YAPILMADI — panel yalnız SINIFLANDIRMAYI kullanıyor; sipariş
    /// önerisi üretmiyor. Sınıflandırma "bu metrik burada geçerli mi" sorusunu cevaplar.
    /// </summary>
    private const string TalepADI = "(12.0 / NULLIF(t.SatanAy, 0))";

    /// <summary>Talep deseni sınıfı — 0 hiç satmadı · 1 düzgün · 2 değişken · 3 aralıklı · 4 sıçramalı.</summary>
    private const string TalepSinifiSql =
        "CASE WHEN t.SatanAy IS NULL OR t.SatanAy = 0 THEN 0 " +
        "     WHEN " + TalepADI + " <= 1.32 AND ISNULL(t.TalepCV2, 0) <= 0.49 THEN 1 " +
        "     WHEN " + TalepADI + " <= 1.32 THEN 2 " +
        "     WHEN ISNULL(t.TalepCV2, 0) <= 0.49 THEN 3 " +
        "     ELSE 4 END";

    /// <summary>
    /// GÜN-STOK GÜVENİLİR Mİ — yalnız ADI ≤ 1,32 (düzgün/değişken talep). Aralıklı talepte
    /// ortalama çoğu SIFIR olan aylara yayılır ve gün-stok anlamını yitirir.
    /// </summary>
    private const string GunStokGuvenilirSart =
        "(t.SatanAy IS NOT NULL AND t.SatanAy > 0 AND " + TalepADI + " <= 1.32)";

    private const string DefterGuvenilirSart =
        "(t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 " +
        "AND t.MerkezStok >= 0 AND t.SatisFiyat > 0)";

    /// <summary>
    /// SEZONLUK RAF AÇIĞI — geçen sezon BU mağazada sattı · bugün BU rafta stok yok ·
    /// merkez depoda mal var. Eylem <b>TRANSFER</b>, sipariş DEĞİL (mal zaten şirketin).
    ///
    /// Kullanıcı istedi (10.09.2026): "şubelerde geçen sezon çok iyi satmış ama bu sezon
    /// rafında olmayan ama depoda olanlar" + "satış kaybı olanlar bu tanıma mı giriyor".
    /// Cevap ÖLÇÜLDÜ: hayır, tam girmiyordu. Kohort 389 çeşit / 459 mağaza-ürün satırı,
    /// geçen sezon 35.291 adet = <b>5.616.497 ₺</b>, merkezde bekleyen 74.830 adet
    /// (talebin ~2 katı). Mevcut kartların kapsaması:
    ///   Sezon Stok Açığı 186 (%48) — yakalıyor ama eylemi SİPARİŞ gibi okunuyor
    ///   Raf Bulunurluk Kaybı 52 (%13) — ÜÇ rafın da boş olmasını şart koşuyor; 337'sinde
    ///     başka mağazada stok var
    ///   Stokta Yokluk 4 (%1) — tanım <c>ToplamStok&lt;=0</c>, depoda mal olduğu için dışlıyor
    ///   Aşırı Stok 61 (%16) — çelişki DEĞİL, teşhis: merkez şişik, raf boş
    ///   <b>HİÇBİRİ 179 (%46)</b> — 15.507 adet / 1.135.340 ₺ panelde hiç görünmüyordu
    /// Sebep: kartlar TOPLAM stoğa bakıyor, merkezi "var" sayıyor → raf boş olsa da
    /// "stok yeterli" görünüyor.
    ///
    /// ⚠ TALEP EŞİĞİ YOK — ve bu bir SEÇİM değil ÖLÇÜM sonucu. Eşik aranırken bantlara göre
    /// gerçekleşme oranı ölçüldü (bu sezon Ağu+Eyl1-9 ÷ geçen yıl aynı pencere):
    ///   raf boş: 1-2 → 0,10 · 3-4 → 0,09 · 5-9 → 0,08 · 10-24 → 0,08 · 25-49 → 0,03 · 50+ → 0,06
    ///   raf dolu: 1,04 – 1,24 (her bantta)
    /// Boşluk HER BANTTA aynı derinlikte (~%92 kayıp) → talep eşiği gerekçelenemiyor.
    /// Eşik listeyi değil SIRALAMAYI belirler; kart kayıp tutarına göre okunur.
    ///
    /// ⚠ TAKVİYE MUHAFIZI ZORUNLU — anlık-raf tuzağını kapatıyor. Muhafızsız ölçümde 50+
    /// bandı <b>2,93</b> çıkıyordu (raf boş olanlar raf dolu olanlardan İYİ satmış gibi):
    /// hızlı dönen üründe raf o gün boş ama ay içinde takviye gelmiş ve bol satmış — "bugün
    /// boş" kayıp DEĞİL, "hızlı tükendi" demek. <c>SonGiris</c> muhafızı ile 2,93 → 0,06.
    /// ⚠ SINIR: <c>SonGiris</c> ÜRÜN düzeyinde (mağaza kırılımı yok) → "bu rafa takviye
    /// gelmedi" değil "bu ürüne hiçbir mağazada takviye gelmedi" demek. Muhafız bu yüzden
    /// TEMKİNLİ: gerçek kohortun bir kısmını dışarıda bırakır, yanlış pozitif üretmez.
    /// ⚠ SINIR: <c>MerkezStok</c> WMS anlık (sql-server-conventions § MERKEZ DEPO) — hayalet
    /// stok riski var; adet küçükse fiziksel teyit ister.
    ///
    /// ══ DÜZELTME 10.09.2026 (aynı gün, kullanıcı denetimi) ═════════════════════════
    /// Kullanıcı örnek istedi: <b>stkID 643638</b> "Missim Bijuteri 49,50 Tl" — kart bunu
    /// "depoda var → transfer" diye gösteriyordu. Gerçek: raf FSM <b>−216</b> · Özlüce
    /// <b>−250</b> · İst.Yolu <b>−36</b>, merkezde <b>1 adet</b>, tutar −24.799,50 ₺.
    /// Bu bir FİYAT KARTI (adında fiyat var) ve "gir çık" deseni taşıyor: 11 alış hareketi /
    /// 1.113 adet karşısında <b>1.106 satış hareketi / 1.889 adet</b> — mal girişi bu karta
    /// yazılmıyor, satış yazılıyor, defter kronik negatife gidiyor.
    ///
    /// İki ölçüt hatası birleşiyordu:
    ///   (a) <c>StokFsm &lt;= 0</c> negatifi de "boş raf" sayıyordu → 21 çeşit / 208.169 ₺
    ///   (b) <c>MerkezStok &gt; 0</c> "transfer yeter" sanılıyordu → <b>622 çeşit /
    ///       5.793.010 ₺ = tutarın %74'ü</b> aslında ALIM gerektiriyordu
    /// Merkez karşılama bantları (ölçüldü): &lt;%10 → 120 çeşit / 3.490.966 ₺ ama merkezde
    /// topu topu 306 adet (eksik 11.563) · %10-25 → 143 / 1.038.225 · %25-50 → 157 / 607.033
    /// · %50-100 → 202 / 656.786 · <b>%100+ → 1.494 çeşit / 2.082.380 ₺, merkezde 47.800</b>.
    /// ⇒ Ölçüte <c>MerkezStok >= eksikAdet</c> eklendi; kart 2.116 → <b>1.494 çeşit / 2,08M ₺</b>.
    /// Karşılamayanlar (622 çeşit) Sezon Stok Açığı kartının işi — orada eylem ALIM.
    ///
    /// ⚠ "Adında fiyat" KURAL OLARAK KULLANILMADI: evrende 54 çeşit ve 313 negatif raflının
    /// yalnız 26'sını yakalıyor — liste-benzeri, zayıf ayraç. Kullanılan ayraç NEGATİF DEFTER
    /// STOĞU (evrende 313 çeşit / 931.395 ₺).
    ///
    /// Türetme SQL'i: <c>sorgular/2026-09-10-acik-siparis-etip-ve-sezon-raf-acigi.sql</c> blok 2.
    /// </summary>
    /// <remarks>
    /// Eksik adet — YALNIZ rafı boş olan mağazanın geçen sezon satışı. Ölçüt ve tutar AYNI
    /// ifadeyi kullanır (ayrışırsa kart kendi eşiğini ihlal eder).
    /// </remarks>
    private const string SezonRafEksikAdet =
        "(CASE WHEN t.SezonFsm > 0 AND t.StokFsm = 0 THEN t.SezonFsm ELSE 0 END " +
        " + CASE WHEN t.SezonOzl > 0 AND t.StokOzl = 0 THEN t.SezonOzl ELSE 0 END " +
        " + CASE WHEN t.SezonIst > 0 AND t.StokIst = 0 THEN t.SezonIst ELSE 0 END)";

    private const string SezonRafAcigiSart =
        "(t.MerkezStok > 0 " +
        "AND (t.SonGiris IS NULL OR t.SonGiris < DATEADD(DAY, -14, @kesim)) " +
        // NEGATİF RAF "BOŞ" DEĞİL: negatif defter stoğu fiziksel boşluk kanıtı değil, defter
        // hatasıdır (panelin Veri Kirli kartı onları ayrı gösteriyor). Ölçüt "= 0" (boş),
        // "<= 0" (boş VEYA bozuk) değil.
        "AND ((t.SezonFsm > 0 AND t.StokFsm = 0) " +
        "  OR (t.SezonOzl > 0 AND t.StokOzl = 0) " +
        "  OR (t.SezonIst > 0 AND t.StokIst = 0)) " +
        // MERKEZ EKSİĞİ KARŞILAMALI — kartın adı, grubu ve önerdiği eylem ancak o zaman doğru.
        "AND t.MerkezStok >= " + SezonRafEksikAdet + " " +
        "AND " + DefterGuvenilirSart + ")";

    /// <summary>
    /// Sezonluk raf açığının KAYIP TUTARI — yalnız açığı olan mağazanın sezon adedi sayılır.
    /// Rafı dolu mağazanın satışı kayıp değildir; toplam sezon adedi kullanmak tutarı şişirirdi.
    /// </summary>
    private const string SezonRafAcigiTutar = "(" + SezonRafEksikAdet + " * t.SatisFiyat)";

    private const string AsiriStokKat = "3";

    /// <summary>
    /// KATEGORİ BAZLI AŞIRI STOK KATSAYISI — ölçümle türetildi 10.09.2026.
    ///
    /// Panel geneli 3× eşiği bir sorun taşıyordu: <b>Kırtasiye devir 1,25</b> ile
    /// <b>Dergi 5,95</b> aynı eşiği paylaşıyordu. Aynı yöntem kategori bazında koşuldu
    /// (01.08.2025 kapsama katı → sonraki 12 ayın yıllık devri; devrin 1,0 ALTINA düştüğü
    /// kat = o kategorinin eşiği). Bant başına en az 30 çeşit şartı kondu.
    ///
    /// ÖLÇÜM (yıllık devir, bant sırasıyla &lt;2× · 2-3× · 3-5× · 5-8× · 8×+):
    ///   Kırtasiye          4,78 · <b>0,93</b> · 0,64 · 0,49 · 0,31   MONOTON ⇒ eşik <b>2×</b>
    ///   Hazırlık Kitapları 11,68 · 2,14 · 1,93 · <b>1,20</b> · 0,28  MONOTON ⇒ eşik <b>8×</b>
    ///   Çocuk Kitabı       5,57 · 1,36 · 1,06 · (n&lt;30) · 0,30      bant EKSİK ⇒ değişmedi
    ///   Oyuncak            3,21 · 0,94 · <b>1,13</b> · 0,61 · 0,42   MONOTON DEĞİL ⇒ değişmedi
    ///   Hediyelik          4,81 · (n&lt;30) · 0,42 · (n&lt;30) · 0,38  bant EKSİK ⇒ değişmedi
    ///   Akademi · Dergi · Elektronik · Kitap: yalnız &lt;2× bandı n≥30 ⇒ TÜRETİLEMEDİ
    ///
    /// ⇒ Yalnız <b>iki kategori</b> değişti; kanıtı monoton ve bantları dolu olanlar.
    /// Kalan sekizde panel geneli 3× duruyor — "ölçemediğimi değiştirmem" kuralı.
    ///
    /// ETKİ (kesim 09.09.2026, ölçüldü):
    ///   Kırtasiye 9.897 → <b>11.679 çeşit</b> · 219,8M → <b>247,6M ₺</b> (eşik SIKILAŞTI,
    ///     çünkü devri yavaş: 1,25)
    ///   Hazırlık Kitapları 1.427 → <b>460 çeşit</b> · 11,9M → <b>4,9M ₺</b> (eşik GEVŞEDİ,
    ///     çünkü devri hızlı: 3,16 — haksız "aşırı" damgası kalktı)
    ///
    /// ⚠ Bu bir LİSTE değil ÖLÇÜM SONUCU eşlemesi; kategori adları panel evreninin
    /// (<c>Kategori3Evreni</c>) parçası ve zaten sabit. Yeni kategori eklenirse ELSE dalına
    /// düşer (3×) — sessiz kalmaz, panel geneli eşiğini alır.
    /// ⚠ <c>bkm.OneriSiparisKtg3Ondeger</c> politika tablosuna BAĞLANMADI — kullanıcı o
    /// tabloyu iptal etti (10.09.2026). Eşik ölçümden gelir, politika tablosundan değil.
    /// ⚠ Aynı confound geçerli: ters nedensellik (alıcı çok satmasını beklediğine çok stok
    /// koyar) ve veriden seçilen kesimin bedeli (Altman &amp; Royston) — beyan edildi.
    ///
    /// Türetme SQL'i: <c>sorgular/2026-09-10-kategori-bazli-asiri-stok-esigi.sql</c>
    /// </summary>
    private const string AsiriStokKatSql =
        "(CASE t.Kategori3 " +
        "WHEN N'Kırtasiye' THEN 2 " +
        "WHEN N'Hazırlık Kitapları' THEN 8 " +
        "ELSE " + AsiriStokKat + " END)";

    /// <summary>
    /// Aşırı stok ölçütü — <b>TEK KAYNAK</b>. KPI, kategori kırılımı, ODAK temin tablosu ve
    /// liste filtresi bunu kullanır; eşik burada değişince hepsi birlikte değişir (önce altı
    /// yerde ayrı ayrı <c>5 *</c> yazılıydı — ayrışma riski).
    /// </summary>
    private const string AsiriStokSart =
        "(t.SezonToplam > 0 AND t.ToplamStok > " + AsiriStokKatSql + " * t.SezonToplam " +
        // Kaçak ÖLÇÜLDÜ = 0 (negatif toplam pozitif eşiği geçemez); şart tutarlılık için,
        // rakamı değiştirmiyor: 29.656 → 29.625 (fark yalnız fiyatı 0 olanlar).
        "AND " + DefterGuvenilirSart + ")";

    private const string SezonHazirlikSart =
        "(t.SezonToplam > 0 AND t.ToplamStok > 0 AND t.ToplamStok < 0.5 * t.SezonToplam " +
        // ⚠ `ToplamStok > 0` negatif TOPLAMI zaten dışlıyordu, ama 62 çeşitte bir RAF
        // negatifti ve toplamı küçültüp eksik adedi ŞİŞİRİYORDU (kayıp olduğundan fazla).
        "AND " + DefterGuvenilirSart + ")";

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
        // B7 (10.09 denetimi): `StokFsm <= 0` negatifi de "boş raf" sayıyordu ve
        // `MagazaStok > 0` negatif bir rafı pozitif bir rafla maskeliyordu — 193 çeşit.
        // Ön-şart ikisini birden kapatıyor; "<= 0" ifadeleri artık yalnız 0'a denk gelir.
        "AND " + DefterGuvenilirSart + " " +
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
        // SİPARİŞ sezon penceresi (plan-46) — takvim matematiği C#'ta yapılır, SQL'de DEĞİL.
        // ⚠ NEDEN: ay örtüşmesini SQL ifadesiyle kurmak DATEFROMPARTS/DATEADD/DATEDIFF
        // zincirini 12+ kez iç içe yazdırıyordu ve SQL Server 8632 "deyim hizmetleri sınırına
        // ulaşıldı" ile sorguyu REDDETTİ (ölçüldü 11.09.2026, panel hiç açılmadı).
        // pbas = kesimin SEZON YILINA taşınmış hâli (Ay1/Ay2/Ay3 o yıla ait).
        pbas = SezonPencereBasi(f),
        a8 = new DateTime(f.SezonYil, 8, 1),
        a9 = new DateTime(f.SezonYil, 9, 1),
        a10 = new DateTime(f.SezonYil, 10, 1),
        a11 = new DateTime(f.SezonYil, 11, 1),
    };

    /// <summary>
    /// Kesimin sezon yılına taşınmış karşılığı. 29 Şubat tuzağı: sezon yılı artık yıl
    /// değilse gün 28'e çekilir (yoksa ArgumentOutOfRange).
    /// </summary>
    private static DateTime SezonPencereBasi(SatisAnaliziFiltre f)
    {
        var gun = Math.Min(f.Kesim.Day, DateTime.DaysInMonth(f.SezonYil, f.Kesim.Month));
        return new DateTime(f.SezonYil, f.Kesim.Month, gun);
    }

    /// <summary>
    /// KPI + Kategori3 kırılımı — tek geçiş, 196 ms.
    /// Aşırı stok eşiği <c>AsiriStokSart</c>'tan gelir (3×, veriden türetildi 10.09).
    /// Eşik KATEGORİ BAZLI (<c>AsiriStokKatSql</c>): panel geneli 3×, Kırtasiye 2×, Hazırlık
    /// Kitapları 8× — üçü de ölçümle türetildi. <c>bkm.OneriSiparisKtg3Ondeger</c> politika
    /// tablosu kullanıcı kararıyla İPTAL (10.09.2026); eşik ölçümden gelir.
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
                   SUM(CASE WHEN {StoksuzSezonSart} THEN 1 ELSE 0 END) AS StoksuzCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {StoksuzSezonSart}
                        THEN t.SezonToplam * t.SatisFiyat ELSE 0 END))                     AS StoksuzKayip,
                   -- İKİLİ TABAN (12.09.2026, kullanıcı: "hem maliyet hem üst fiyat olmalı
                   -- her şeyde"). Kayıp kartlarında ANA sayı satış fiyatıdır (kaçan ciro);
                   -- maliyet karşılığı = kaçan adet × birim maliyet → aradaki fark KAÇAN BRÜT
                   -- KÂR. İki sayı yan yana durunca kartın parası ölçülebilir hâle geliyor.
                   CONVERT(decimal(18,2), SUM(CASE WHEN {StoksuzSezonSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.SezonToplam) * t.BirimMaliyet
                        ELSE 0 END))                                                  AS StoksuzMaliyet,
                   SUM(CASE WHEN {StoksuzSezonSart} AND t.OdakStok > 0 THEN 1 ELSE 0 END) AS StoksuzOdakCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {StoksuzSezonSart} AND t.OdakStok > 0
                        THEN t.SezonToplam * t.SatisFiyat ELSE 0 END))                     AS StoksuzOdakKayip,
                   SUM(CASE WHEN {AsiriStokSart} THEN 1 ELSE 0 END) AS AsiriCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {AsiriStokSart}
                        THEN t.Tutar ELSE 0 END))                                          AS AsiriTutar,
                   -- B-172(b) MALİYET TABANI (12.09.2026). Kart etiket fiyatıyla 325,3M ₺
                   -- gösteriyordu; maliyetle 111,6M ₺ (2,91 kat şişik ceza). Dahası eşiğe
                   -- KADARKİ stok meşrudur — ceza yalnız FAZLA kısma yazılır: 73,2M ₺.
                   -- Maliyet kapsamı ölçüldü: 28.974/30.403 çeşit (%95,3) · etiketin %97,5'i.
                   CONVERT(decimal(18,2), SUM(CASE WHEN {AsiriStokSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.ToplamStok) * t.BirimMaliyet
                        ELSE 0 END))                                              AS AsiriMaliyet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {AsiriStokSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.ToplamStok - {AsiriStokKatSql} * t.SezonToplam)
                             * t.BirimMaliyet ELSE 0 END))                        AS AsiriFazlaMaliyet,
                   SUM(CASE WHEN {AsiriStokSart} AND t.OdakStok > 0 THEN 1 ELSE 0 END) AS AsiriOdakCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {AsiriStokSart} AND t.OdakStok > 0
                        THEN t.Tutar ELSE 0 END))                                          AS AsiriOdakTutar,
                   -- Hareketsiz: satış yok + stok var + DEĞERLENDİRİLECEK kadar zamanı olmuş.
                   -- Yenilik koruması olmadan yeni açılan ürün haksız damgalanıyordu (ölçüldü).
                   SUM(CASE WHEN {OluStokSart} THEN 1 ELSE 0 END) AS HareketsizCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {OluStokSart}
                        THEN t.Tutar ELSE 0 END))                                          AS HareketsizTutar,
                   -- RAFA HİÇ ÇIKMAMIŞ (kullanıcı isteği 09.09: "gelmiş ama mağazaya gitmemiş
                   -- te bir kpi olmalı"). Merkeze girmiş, mağazaya HİÇ girmemiş → satması
                   -- imkânsız. IlkGiris NULL = mağaza defterinde tek giriş kaydı yok.
                   -- ÖLÇÜLDÜ 09.09: 1.182 çeşit / 142.714 adet / 24,17M ₺; 802'si 90 günden eski.
                   SUM(CASE WHEN {RafsizSart} THEN 1 ELSE 0 END) AS RafsizCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {RafsizSart}
                        THEN t.Tutar ELSE 0 END))                                          AS RafsizTutar,
                   -- RAFTA YOK ama MERKEZDE VAR — daha önce rafa çıkmış, şimdi rafı boş.
                   -- Satışı olanlar KANITLI TALEP + boş raf = kayıp satış (ölçüldü: 3.539
                   -- çeşit / 10,46M ₺, 1.218'inin satışı var). Transferle çözülür, alımla değil.
                   -- ⚠ DÜZELTME 09.09 (kullanıcı bildirimi, stkID 1697931): ölçüt MagazaStok
                   -- TOPLAMI <= 0 idi ve NEGATİF stoğu maskeliyordu — o üründe FSM 5 adet VARDI
                   -- ama İst.Yolu −13 (veri kiri) toplamı −8 yapıyor, ürün "rafı boş" görünüyordu.
                   -- Doğrusu: ÜÇ RAFIN HEPSİ boş. Ölçüldü: 3.539 → 3.533 çeşit (6'sı aslında
                   -- rafta vardı), tutar 10,46M → 10,27M ₺.
                   -- STOK DEĞERİ tabanlı üç kart da MALİYETE (12.09.2026). Aşırı/Ölü Stok
                   -- maliyete geçmişti; bunlar etikette kalınca panel iki dil konuşuyordu.
                   -- ⚠ KAYIP POTANSİYELİ kartları (Sezon Stok Açığı · Stokta Yokluk · Sezonluk
                   -- Raf Açığı) ÇEVRİLMEDİ ve çevrilmemeli: kaçan satış SATIŞ FİYATIYLA ölçülür,
                   -- maliyetle değil. Taban farkı orada DOĞRU.
                   CONVERT(decimal(18,2), SUM(CASE WHEN {RafBosSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.ToplamStok) * t.BirimMaliyet
                        ELSE 0 END))                                              AS RafBosMaliyet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {RafsizSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.ToplamStok) * t.BirimMaliyet
                        ELSE 0 END))                                              AS RafsizMaliyet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {DengesizSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.ToplamStok) * t.BirimMaliyet
                        ELSE 0 END))                                              AS DengesizMaliyet,
                   SUM(CASE WHEN {RafBosSart} THEN 1 ELSE 0 END)                                             AS RafBosCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {RafBosSart} THEN t.Tutar ELSE 0 END))            AS RafBosTutar,
                   -- Karşı-metrik DEĞİŞTİ: "satışı olan" artık ANA ölçütte (talep >= 5), tekrar
                   -- göstermek bilgi eklemiyor. Yerine merkezde bekleyen adet.
                   CONVERT(bigint, SUM(CASE WHEN {RafBosSart} THEN t.MerkezStok ELSE 0 END)) AS RafBosSatisliCesit,
                   -- ⚠ GENİŞLETİLDİ 09.09: eski ölçüt yalnız TOPLAM negatifi görüyordu; merkez
                   -- pozitifse mağaza rafındaki eksi stok gizleniyordu (ölçüldü: 187 çeşit /
                   -- 4,89M ₺ hiçbir ölçütte görünmüyordu; mağaza raflarında −8.160 adet negatif).
                   -- Vaka: stkID 1697931 FSM 5 · İst.Yolu −13 · merkez 600 → toplam 592 "temiz".
                   SUM(CASE WHEN {DefterGuvenilmezSart} THEN 1 ELSE 0 END)  AS KirliCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {DefterGuvenilmezSart}
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
                   CONVERT(decimal(18,2), SUM(CASE WHEN {SezonHazirlikSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.SezonToplam - t.ToplamStok) * t.BirimMaliyet
                        ELSE 0 END))                                                  AS SezonAcikMaliyet,
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
                   -- B-172(b) devamı (12.09.2026): ölü stok da MALİYETLE. Aşırı Stok maliyete
                   -- geçince bu kart etikette kalmıştı → iki kart farklı taban konuşuyordu.
                   -- ÖLÇÜLDÜ: etiket 144,7M ₺ · maliyet 71,0M ₺.
                   CONVERT(decimal(18,2), SUM(CASE WHEN {OluStokSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.ToplamStok) * t.BirimMaliyet
                        ELSE 0 END))                                              AS HareketsizMaliyet,
                   -- ⚠ ÖLÇÜM SÜRPRİZİ: "hiç satılmamış" çeşidin %38'i ve etiketin %36'sı AMA
                   -- MALİYETİN %66'sı (46,8M / 71,0M). Etiket fiyatıyla bakınca küçük görünüyor;
                   -- bağlanan para asıl ORADA. Eskiden satmış kohortta etiket/maliyet 3,8×,
                   -- hiç satmamışta 1,1× — ikisi AYNI kartta tek sayıyla anlatılamaz.
                   CONVERT(decimal(18,2), SUM(CASE WHEN {OluStokSart} AND t.SonSatis IS NULL
                        AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), t.ToplamStok) * t.BirimMaliyet
                        ELSE 0 END))                                              AS HicSatilmamisMaliyet,
                   SUM(CASE WHEN {OluStokSart} AND t.SonSatis IS NULL THEN 1 ELSE 0 END)              AS HicSatilmamisCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {OluStokSart}
                        AND t.SonSatis IS NULL THEN t.Tutar ELSE 0 END))                AS HicSatilmamisTutar,
                   -- Rafa çıkmamış stoğun ADEDİ — o kartın karşı-metriği (tutar zaten
                   -- birincil değerde; ikinci kez tutar göstermek bilgi eklemiyordu).
                   CONVERT(bigint, SUM(CASE WHEN {RafsizSart}
                        THEN t.MerkezStok ELSE 0 END))                                AS RafsizAdet,
                   -- TALEP DESENİ — "gün-stok burada geçerli mi" sorusunun cevabı.
                   SUM(CASE WHEN ({TalepSinifiSql}) IN (1, 2) THEN 1 ELSE 0 END)      AS DuzgunTalepCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN ({TalepSinifiSql}) IN (1, 2)
                        THEN t.Tutar ELSE 0 END))                                     AS DuzgunTalepTutar,
                   SUM(CASE WHEN ({TalepSinifiSql}) IN (3, 4) THEN 1 ELSE 0 END)      AS ArelikliTalepCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN ({TalepSinifiSql}) IN (3, 4)
                        THEN t.Tutar ELSE 0 END))                                     AS ArelikliTalepTutar,
                   -- SEZONLUK RAF AÇIĞI (ölçüt: SezonRafAcigiSart, tek yer)
                   SUM(CASE WHEN {SezonRafAcigiSart} THEN 1 ELSE 0 END)               AS SezonRafCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {SezonRafAcigiSart}
                        THEN {SezonRafAcigiTutar} ELSE 0 END))                        AS SezonRafTutar,
                   CONVERT(decimal(18,2), SUM(CASE WHEN {SezonRafAcigiSart} AND t.BirimMaliyet > 0
                        THEN CONVERT(decimal(18,4), {SezonRafEksikAdet}) * t.BirimMaliyet
                        ELSE 0 END))                                                  AS SezonRafMaliyet,
                   -- Karşı-metrik: merkezde bekleyen adet — transferin hammaddesi
                   CONVERT(bigint, SUM(CASE WHEN {SezonRafAcigiSart}
                        THEN t.MerkezStok ELSE 0 END))                                AS SezonRafMerkezAdet
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

        // SİPARİŞ ÖZETİ AYRI SORGU (plan-46). ⚠ NEDEN AYRI: KPI sorgusu 56 agregayla zaten
        // sınırdaydı; sipariş ifadeleri eklenince SQL Server 8632 "deyim hizmetleri sınırına
        // ulaşıldı" verdi ve panel HİÇ açılmadı (ölçüldü 11.09.2026). Ayrı sorgu hem sınırı
        // aşmıyor hem maliyeti izole ediyor.
        var siparis = await SiparisOzetAsync(conn, f, ct);

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
            StoksuzSezonMaliyet: satirlar.Sum(x => x.StoksuzMaliyet),
            StoksuzSezonOdakVarCesit: satirlar.Sum(x => x.StoksuzOdakCesit),
            StoksuzSezonOdakVarKayip: satirlar.Sum(x => x.StoksuzOdakKayip),
            AsiriStokCesit: satirlar.Sum(x => x.AsiriCesit),
            AsiriStokTutar: satirlar.Sum(x => x.AsiriTutar),
            AsiriStokMaliyet: satirlar.Sum(x => x.AsiriMaliyet),
            AsiriStokFazlaMaliyet: satirlar.Sum(x => x.AsiriFazlaMaliyet),
            AsiriStokOdakVarCesit: satirlar.Sum(x => x.AsiriOdakCesit),
            AsiriStokOdakVarTutar: satirlar.Sum(x => x.AsiriOdakTutar),
            HareketsizCesit: satirlar.Sum(x => x.HareketsizCesit),
            HareketsizTutar: satirlar.Sum(x => x.HareketsizTutar),
            RafsizCesit: satirlar.Sum(x => x.RafsizCesit),
            RafsizTutar: satirlar.Sum(x => x.RafsizTutar),
            RafBosMaliyet: satirlar.Sum(x => x.RafBosMaliyet),
            RafsizMaliyet: satirlar.Sum(x => x.RafsizMaliyet),
            DengesizMaliyet: satirlar.Sum(x => x.DengesizMaliyet),
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
            SezonAcikMaliyet: satirlar.Sum(x => x.SezonAcikMaliyet),
            SezonAcikOdakCesit: satirlar.Sum(x => x.SezonAcikOdakCesit),
            SezonAcikOdakTutar: satirlar.Sum(x => x.SezonAcikOdakTutar),
            MaliyetliDeger: satirlar.Sum(x => x.MaliyetliDeger),
            MaliyetKapsamEtiket: satirlar.Sum(x => x.MaliyetKapsamEtiket),
            PosNetKdvHaric: satirlar.Sum(x => x.PosNetKdvHaric),
            SatilanMaliyet: satirlar.Sum(x => x.SatilanMaliyet),
            PosBrutToplam: satirlar.Sum(x => x.PosBrutToplam),
            PosNetToplam: satirlar.Sum(x => x.PosNetToplam),
            MarjCesit: satirlar.Sum(x => x.MarjCesit),
            HareketsizMaliyet: satirlar.Sum(x => x.HareketsizMaliyet),
            HicSatilmamisMaliyet: satirlar.Sum(x => x.HicSatilmamisMaliyet),
            HicSatilmamisCesit: satirlar.Sum(x => x.HicSatilmamisCesit),
            HicSatilmamisTutar: satirlar.Sum(x => x.HicSatilmamisTutar),
            RafsizAdet: satirlar.Sum(x => x.RafsizAdet),
            SezonRafCesit: satirlar.Sum(x => x.SezonRafCesit),
            SezonRafTutar: satirlar.Sum(x => x.SezonRafTutar),
            SezonRafMaliyet: satirlar.Sum(x => x.SezonRafMaliyet),
            SezonRafMerkezAdet: satirlar.Sum(x => x.SezonRafMerkezAdet),
            DuzgunTalepCesit: satirlar.Sum(x => x.DuzgunTalepCesit),
            DuzgunTalepTutar: satirlar.Sum(x => x.DuzgunTalepTutar),
            ArelikliTalepCesit: satirlar.Sum(x => x.ArelikliTalepCesit),
            ArelikliTalepTutar: satirlar.Sum(x => x.ArelikliTalepTutar),
            SiparisCesit: siparis.Cesit,
            SiparisAdet: siparis.Adet,
            SiparisMaliyet: siparis.Maliyet,
            SiparisEtiket: siparis.Etiket,
            SiparisAcilCesit: siparis.AcilCesit,
            SiparisAcilAdet: siparis.AcilAdet,
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
                   SUM(CASE WHEN {StoksuzSezonSart} THEN 1 ELSE 0 END) AS StoksuzCesit,
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
                   SUM(CASE WHEN {StoksuzSezonSart} THEN 1 ELSE 0 END) AS StoksuzCesit,
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
        int StoksuzCesit, decimal StoksuzKayip,
        decimal StoksuzMaliyet,   // ⚠ SQL'de StoksuzKayip'ten HEMEN SONRA
        int StoksuzOdakCesit, decimal StoksuzOdakKayip,
        int AsiriCesit, decimal AsiriTutar,
        // ⚠ SQL'de AsiriTutar ile AsiriOdakCesit ARASINA girer (Dapper pozisyonel).
        decimal AsiriMaliyet, decimal AsiriFazlaMaliyet,
        int AsiriOdakCesit, decimal AsiriOdakTutar,
        int HareketsizCesit, decimal HareketsizTutar,
        int RafsizCesit, decimal RafsizTutar,
        // ⚠ SQL'de RafBosCesit'ten ÖNCE geliyorlar (Dapper pozisyonel).
        decimal RafBosMaliyet, decimal RafsizMaliyet, decimal DengesizMaliyet,
        int RafBosCesit, decimal RafBosTutar, long RafBosSatisliCesit,
        int KirliCesit, decimal KirliTutar,
        int YeniCesit, decimal YeniTutar,
        int DengesizCesit, decimal DengesizTutar,
        int SezonAcikCesit, decimal SezonAcikTutar, decimal SezonAcikMaliyet,
        int SezonAcikOdakCesit, decimal SezonAcikOdakTutar,
        decimal MaliyetliDeger, decimal MaliyetKapsamEtiket,
        decimal PosNetKdvHaric, decimal SatilanMaliyet,
        decimal PosBrutToplam, decimal PosNetToplam, int MarjCesit,
        // ⚠ SQL'de HicSatilmamisCesit'ten ÖNCE geliyorlar (Dapper pozisyonel).
        decimal HareketsizMaliyet, decimal HicSatilmamisMaliyet,
        int HicSatilmamisCesit, decimal HicSatilmamisTutar, long RafsizAdet,
        // ⚠ SIRA SQL SELECT SIRASIYLA AYNI OLMAK ZORUNDA — Dapper pozisyonel record'da
        // isim değil SIRA eşler. Talep deseni agregaları SQL'de RafsizAdet'ten HEMEN SONRA
        // geliyor; burada SezonRaf'tan sonraya yazılınca materialization patladı (10.09).
        int DuzgunTalepCesit, decimal DuzgunTalepTutar,
        int ArelikliTalepCesit, decimal ArelikliTalepTutar,
        int SezonRafCesit, decimal SezonRafTutar,
        decimal SezonRafMaliyet,   // ⚠ SQL'de SezonRafTutar'dan HEMEN SONRA
        long SezonRafMerkezAdet);
}

/// <summary>Sayfa açılışında tek geçişte gelen özet: KPI + Kategori3 kırılımı.</summary>
public sealed record SatisAnaliziOzet(SatisAnaliziKpi Kpi, IReadOnlyList<SatisAnaliziKirilim> Kategori3);

/// <summary>ODAK temin süresi bandı kırılımı.</summary>
public sealed record TeminKirilim(string Ad, int Sira, int Cesit, decimal Tutar, long OdakStok);
