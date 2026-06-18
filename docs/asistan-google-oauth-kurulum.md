# BKM-Asistan — Google OAuth Kurulum Rehberi (Faz-2)

> Amaç: dashboard asistanının senin Google hesabınla (fikrieren@gmail.com) **Takvim + Gmail** kullanabilmesi için bir kerelik OAuth kurulumu.
> Süre: ~10 dk. Çıktı: **Client ID** + **Client Secret** (bunları bana ver → `.env`'e yazarım).
> Not: Google konsolu 2025'te arayüzü değiştirdi — artık "APIs & Services > OAuth consent screen" yerine **"Google Auth platform"** menüsü. Eski rehberler/ekran görüntüleri farklı olabilir; aşağısı güncel.

---

## Neden gerekiyor?

Dashboard ayrı bir uygulama; senin Gmail/Takvim'ine erişmek için Google'dan **izin (OAuth)** alması gerekir. Bu izin bir kerelik onayla "refresh-token"a dönüşür, asistan onunla çağrı yapar. Şifre PAYLAŞILMAZ — Google'ın standart yetki akışı.

---

## Adım 1 — Proje oluştur

1. https://console.cloud.google.com aç (fikrieren@gmail.com ile giriş).
2. Üst bardaki proje seçiciden **New Project**.
3. Ad: `BKM-Asistan` → **Create**. Oluşunca o projeyi seç.

## Adım 2 — API'leri aç

1. Sol menü ☰ → **APIs & Services → Library** (veya arama: "API Library").
2. **"Google Calendar API"** ara → aç → **Enable**.
3. Geri dön, **"Gmail API"** ara → aç → **Enable**.

## Adım 3 — OAuth onay ekranı (Branding/Audience)

1. ☰ → **Google Auth platform** → **Branding** (ilk kez ise **Get Started**).
2. **App name:** `BKM Asistan` · **User support email:** kendi mailin → **Next**.
3. **Audience:** **External** seç → **Next**.
4. **Contact Information:** kendi mailin → **Next**.
5. "I agree to the Google API Services: User Data Policy" işaretle → **Continue** → **Create**.

## Adım 4 — Test kullanıcı ekle (KRİTİK — yoksa "doğrulanmamış uygulama" hatası)

1. **Google Auth platform → Audience** sekmesi.
2. **Test users** → **Add users** → `fikrieren@gmail.com` yaz → **Save**.
   - (Test modunda doğrulama/Google incelemesi GEREKMEZ. Consent'te "Google doğrulamadı" uyarısı çıkarsa → **Advanced → Go to BKM Asistan (unsafe)** ile geç; test-user olduğun için güvenli.)

## Adım 5 — Scope'lar (Data Access)

1. **Google Auth platform → Data Access → Add or Remove Scopes**.
2. Aşağıdakileri ekle (arama kutusuna yapıştır):
   - `https://www.googleapis.com/auth/calendar.events`  (takvim etkinliği oluştur/oku)
   - `https://www.googleapis.com/auth/gmail.readonly`  (gelen kutusu oku/özet)
   - `https://www.googleapis.com/auth/gmail.send`  (yanıt gönder — yalnız senin onayınla)
3. **Update** → **Save**.

## Adım 6 — OAuth Client ID oluştur

1. **Google Auth platform → Clients** → **Create Client**.
2. **Application type:** **Web application**.
3. **Name:** `BKM Asistan Web`.
4. **Authorized redirect URIs → Add URI:**
   ```
   http://localhost:5112/auth/google/callback
   ```
   (Dashboard bu portta çalışıyor. İleride farklı host/porta taşırsak buraya ekleriz.)
5. **Create**.
6. Açılan kutudaki **Client ID** ve **Client secret**'ı kopyala.

## Adım 7 — Bana ver

İki değeri bana ilet (sohbete yapıştır VEYA `.env`'e şu satırları sen ekle):

```
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=xxxxx
```

`.env` zaten `.gitignore`'da — commit'lenmez. Sonra ben `/auth/google` akışını kurarım: bir kez "Bağlan" → Google onay ekranı → refresh-token DB'ye yazılır. Tek seferlik.

---

## Resmi dökümanlar

- OAuth client oluşturma: https://developers.google.com/workspace/guides/create-credentials
- Onay ekranı yapılandırma: https://developers.google.com/workspace/guides/configure-oauth-consent
- Calendar API: https://developers.google.com/calendar/api/guides/overview
- Gmail API: https://developers.google.com/gmail/api/guides

## Sık sorunlar

| Sorun | Çözüm |
|---|---|
| "Access blocked: app not verified" | Test-user eklediğinden emin ol (Adım 4) → consent'te Advanced → devam |
| "redirect_uri_mismatch" | Adım 6'daki URI birebir `http://localhost:5112/auth/google/callback` olmalı (sonda / yok) |
| Scope onayı eksik | Adım 5'teki 3 scope'u da ekledin mi; consent ekranında hepsini işaretle |
| Token süresi/iptal | `/auth/google` ile yeniden bağlan — refresh-token tazelenir |

> İlişkili: [`plans/21-asistan-mail-takvim.md`](../plans/21-asistan-mail-takvim.md) §9.
