# Kodlama Disiplini (Karpathy Prensipleri)

> **Rule katmanı:** on-demand (konu-bazlı) — kod yazımı tetiklenince birincil. Core değil. plan-12 WS-2 / footprint-ladder.

## Simplicity First — Spekülatif Kod Yasak

- İstenen dışında feature ekleme. "İleride lazım olur" gerekçesiyle abstraction yok.
- Tek kullanımlık kod için class/interface/strategy pattern çıkarma.
- İmkânsız senaryolar için error handling yazma (iç kodda framework garantilerine güven).
- 200 satır yazıp 50'ye düşürebiliyorsan → yeniden yaz.
- Test: "Kıdemli bir mühendis buna 'gereksiz karmaşık' der mi?" Evet → sadeleştir.

**YAPMA:**
```
// Kullanıcı "discount hesapla" dedi → Strategy pattern + factory + config sınıfı
```
**YAP:**
```
// 1 fonksiyon, 1 satır iş mantığı
```

## Surgical Changes — Sadece İstenen Satıra Dokun

- Bug fix yaparken komşu kodu "iyileştirme", yorum düzenleme, stil değiştirme yasak.
- Mevcut stili taklit et — farklı yapardın bile olsa.
- İlgisiz dead code fark edersen: **raporla, silme** (kullanıcı kararı).
- Senin değişikliğin yüzünden orphan kalan import/değişken/fonksiyonu sil. Önceden var olan dead code'a dokunma.

**Kontrol testi:** Her değiştirilen satır, kullanıcının talebine doğrudan izlenebilmeli. İzlenemiyorsa → o satırı geri al.

## BKM Stack Kalıpları (17.06 dersleri)

- **Blazor Server auth — SignIn `HttpContext` ister, interactive circuit'te YOK.** Login/logout cookie `SignInAsync` için interactive Razor component değil → **minimal API endpoint** (`MapPost("/auth/login")` düz HTML form + `ctx.SignInAsync`). Login sayfası static SSR/HTML (Blazor değil).
- **Modal-üstü-modal Blazor'da çalışmaz** — ikinci modal aynı z-index → arkada/küçük kalır. Drill için ikinci modal yerine **ayrı tam-ekran sayfa** (`NavigateTo("/sayfa?id=...")` + `[SupplyParameterFromQuery]`).
- **pyodbc Windows auth (localhost named instance):** `pyodbc.connect("Driver={ODBC Driver 18 for SQL Server};Server=localhost\\SQLEXPRESS;Database=...;Trusted_Connection=yes;TrustServerCertificate=yes;Login Timeout=10")`. pymssql trusted-connection zayıf → Windows-auth gereken yerde pyodbc. Cursor `with cn.cursor() as cur:`, tek `commit()` + `finally close()`. ODBC connection-string'e env değeri gömülürken whitelist guard (`re.fullmatch(r"[A-Za-z0-9._\\-]+", host)`) — injection.
- **Python↔C# köprüsü = ortak SQL tablosu (API/REST DEĞİL).** Python pyodbc yazar, C# Dapper okur (örn. PanelForecast: Ad PK + JSON nvarchar(max)). Nested veri şemaya açmak kırılgan → tek JSON-string kolon sağlam.
