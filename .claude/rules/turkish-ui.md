# Türkçe UI Kuralları

_Türkçe UI'lı projelerde aktif. İngilizce projeye bootstrap ederken `--no-turkish` flag'i ile hariç tut._

## Dil Ayrımı

| Alan | Dil |
|---|---|
| Kod (class, method, variable) | İngilizce |
| SQL table/column | İngilizce |
| UI metni (view, label, button, toast) | **Türkçe** (UTF-8) |
| CLAUDE.md / TODO.md / docs/ | Türkçe |
| Git commit message | Türkçe veya İngilizce (tutarlı) |

## Türkçe Karakter Kuralı

- **UTF-8** zorunlu. Layout dosyasında `<meta charset="utf-8">` ve `<html lang="tr">`.
- ASCII sadeleştirme **yasak**: "Düzenle" ✓, "Duzenle" ✗.
- İşaretler: `ı`, `İ`, `ş`, `Ş`, `ğ`, `Ğ`, `ü`, `Ü`, `ö`, `Ö`, `ç`, `Ç`.
- **İ vs I ayrımı:** "İptal", "İşlem" ✓ — büyük ı yazma.

## Çeviri Sözlüğü

| İngilizce | Türkçe |
|---|---|
| Edit | Düzenle |
| Delete | Sil |
| Save | Kaydet |
| Cancel | İptal |
| Create / Add | Ekle / Oluştur |
| Update | Güncelle |
| Login / Logout | Giriş Yap / Çıkış Yap |
| User | Kullanıcı |
| Role | Rol |
| Preview | Önizleme |
| Operation / Action | İşlem |
| Filter | Filtre |
| Search | Ara / Arama |
| Settings | Ayarlar |
| Profile | Profil |
| Dashboard | Pano / Dashboard |
| Report | Rapor |
| Component | Bileşen |

## Hata Mesajları

- Kullanıcıya dostça, Türkçe: "Beklenmedik bir hata oluştu. Lütfen sistem yöneticisine bildirin."
- Teknik detay **logger**'a, kullanıcıya asla.
- "Kullanıcı adı zaten mevcut." ✓ / "User already exists." ✗.

## Otomasyon

`turkish-ui-normalizer` skill'i (opsiyonel, proje bazlı): ASCII'leştirilmiş metinleri UTF-8'e çevirir.
