using Solum.Abstractions;
using Solum.Core.Extensibility;
using Solum.Core.Permissions;
using Solum.Web.Menu;

namespace BkmVardiya.Security;

/// <summary>
/// SOLUM KABUĞU ADAPTÖRLERİ — V-03.
///
/// Solum'un kabuğu (<c>_SolumLayout</c>) üç şey soruyor: aktif kullanıcı kim
/// (<see cref="ICurrentUser"/>), aktif şirket ne (<see cref="ICurrentCompany"/>) ve
/// bu kullanıcının izni var mı (<see cref="IPermissionChecker"/>). Bu dosya üçünü de
/// BİZİM kimlik modelimize bağlar.
///
/// ⚠ <c>AddSolumSingleTenant</c> KULLANILMADI ve sebebi ölçüldü: o kurulum
///   <c>userId</c>'yi SABİT alıyor (tek kullanıcılı panel deseni). Bu uygulamada 17
///   gerçek kullanıcı var; sabit kullanıcı, denetim izine ve izin kontrolüne YANLIŞ
///   kimliği yazardı — sessizce.
/// </summary>
public sealed class HttpCurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    private System.Security.Claims.ClaimsPrincipal? User => accessor.HttpContext?.User;

    public string? UserId =>
        User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;

    public string? UserName => User?.Identity?.Name;

    public bool IsAuthenticated => User?.Identity?.IsAuthenticated == true;
}

/// <summary>
/// Tek şirket — BKM Kitap. Şirket seçici bilerek KULLANILMIYOR: vardiya tek tüzel
/// kişilik içinde çalışıyor ve "şirket değiştir" diye bir yetki kararı YOK.
/// Kapsam kararı şubede ve o da SQL'de (<c>Vrd_SubeKapsami</c>).
/// </summary>
public sealed class SingleCompany : ICurrentCompany
{
    public int? CompanyId => 1;
    public bool IsCrossCompany => false;
}

/// <summary>
/// Tek kiracı — vardiya verisi <c>bkm</c> şemasında durur.
///
/// ⚠ Solum başlangıçta bu servisi ZORUNLU tutuyor ve YOKSA AÇIKÇA PATLIYOR
///   ("ICurrentTenant servisini bulamadi"). Ölçüldü (19.09): kabuk açılırken ilk
///   istekte değil, kurulumda patladı ve sebebini yazdı. Sessizce boş kiracı bağlamıyla
///   çalışan bir şema süzgeci, veri sızıntısının en sessiz biçimidir — bu yüzden
///   doğru davranış budur ve buraya not ediliyor.
/// </summary>
public sealed class SingleTenant : ICurrentTenant
{
    public string? TenantKey => "bkm";
    public string? Schema => "bkm";
    public bool HasTenant => true;
}

/// <summary>
/// İzin kontrolü — çerezdeki claim'lerden okur (<see cref="PermissionLoader"/> girişte
/// yazıyor).
///
/// ⚠ BU BİR MENÜ/GÖRÜNÜM KONTROLÜDÜR. Asıl kapı SQL'dedir: şube kapsamı
///   <c>Vrd_SubeKapsami</c> TVF'inde, onay yetkisi <c>[Authorize(Policy)]</c> ve
///   <c>SaveApprovalAsync</c> içindeki kapsam kapısında. Menüden gizlemeyi güvenlik
///   saymak, adresi elle yazan herkese kapıyı açar — Solum'un kendi uyarısı da bu.
///
/// ⚠ <paramref name="resource"/> KULLANILMIYOR: bizde kayıt-düzeyi izin yok, kapsam
///   kaydın ŞUBESİNDEN geliyor ve o soru veritabanında cevaplanıyor. Burada sessizce
///   <c>true</c> dönmek yerine ad-düzeyi cevabı veriyoruz — kayıt-düzeyi bir soru
///   sorulursa cevabı yine ad düzeyidir ve bu YAZILI.
/// </summary>
public sealed class ClaimsPermissionChecker(IHttpContextAccessor accessor) : IPermissionChecker
{
    public Task<bool> IsGrantedAsync(string permissionName, RecordRef? resource,
                                     CancellationToken ct = default)
    {
        var user = accessor.HttpContext?.User;
        var granted = user is not null
                   && user.HasClaim(Permissions.ClaimType, permissionName);
        return Task.FromResult(granted);
    }
}

/// <summary>
/// Vardiya menüsü. Öğeler izinle süzülür — ama bu yalnız görünürlüktür (yukarıdaki not).
///
/// ⚠ ONAY EKRANI MENÜDE YOK ve bu bilinçli: onay tek bir kişi-gün satırından açılır
///   (<c>/Approval?sicil=…&amp;tarih=…</c>), yani bağlamsız bir menü girişi boş sayfa
///   açardı.
/// </summary>
public sealed class VardiyaMenu : IMenuContributor
{
    public void Contribute(MenuBuilderContext context)
    {
        context.Add(new MenuItem("vardiya.rapor", "Mesai Raporu") { Url = "/" });
        context.Add(new MenuItem("vardiya.sifre", "Şifre Değiştir") { Url = "/ChangePassword" });
    }
}
