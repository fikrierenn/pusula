# Plan 21 — BKM-Asistan Faz-2: Gmail + Google Takvim

**Tarih:** 2026-06-18
**Proje:** `bkm`
**Yazan:** Fikri / Claude
**Durum:** `Taslak`
**Önceki:** [`plans/20-bkm-asistan-pwa.md`](20-bkm-asistan-pwa.md) (master, Faz-1 tamamlandı)

---

## 1. Problem

Faz-1'de asistan "cuma toplantı ayarla" deyince yalnızca **görev notu** oluşturuyor — gerçek takvim etkinliği kurmuyor, mail okuyamıyor/yazamıyor. CFO'nun beklediği: asistan gerçek aksiyon alsın (toplantı + davet, gelen kutusu özeti, yanıt taslağı). Bunun için Google ekosistemine (Gmail + Calendar) bağlanmak gerekiyor.

## 2. Scope

### Kapsam dahili
- **Google OAuth2** tek-kullanıcı (fikrieren@gmail.com) — refresh-token kalıcı, bir kerelik onay.
- **Takvim araçları:** `takvim_listele` (oku), `takvim_etkinlik_oner` (öner→ONAY→oluştur+davet).
- **Mail araçları:** `mail_ozet` (oku/özet), `mail_taslak_oner` (öner→ONAY→Gmail taslağı; gönderme ayrı onay).
- **Onay UI:** Asistan.razor'a "etkinlik önerisi" + "mail taslağı" onay kartları (gorev_taslak_oner deseni genelleştirilir).
- **Güvenlik:** source-to-sink izolasyon (SQL/müşteri verisi otomatik mail gövdesine GİTMEZ) + PII + her dış-aksiyon CFO onayı.

### Kapsam dışı
- Otomatik mail gönderme (onaysız) — YASAK.
- Çoklu kullanıcı / Workspace domain-delegation.
- Tekrarlayan etkinlik, katılımcı müsaitlik (suggest_time) — sonraki tur.
- Faz-3 ajanda/hatırlatma motoru (TakvimService tatil≠kişisel).

### Etkilenen dosyalar (tahmin)
- `dashboard/GmDashboard.csproj` — NuGet: Google.Apis.Calendar.v3, Google.Apis.Gmail.v1, Google.Apis.Auth.
- `dashboard/Data/Asistan/GoogleAuthService.cs` (YENİ) — OAuth flow + refresh-token store.
- `dashboard/Data/Asistan/TakvimMailAraclar.cs` (YENİ) — Calendar+Gmail tool implementasyonu.
- `dashboard/Data/Asistan/AsistanAraclar.cs` — yeni tool tanımları + dispatch.
- `dashboard/Data/Asistan/AsistanService.cs` — onay-bekleyen aksiyon (AsistanCevap genişlet: Taslak→OneriTipi).
- `dashboard/Components/Pages/Asistan.razor` — etkinlik/mail onay kartları.
- `dashboard/Program.cs` — DI + `/auth/google` + `/auth/google/callback` minimal endpoint.
- `.env` — GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET (gitignore).
- BkmPanel.dbo.PanelGoogleToken (YENİ tablo) — refresh-token (tek satır).

**Tahmini boyut:** ~6 yeni/değişen dosya, ~450 satır + NuGet.

## 3. Alternatifler

### A: Service account
**Açıklama:** Google service account ile sunucu-sunucu.
**Reddetme sebebi:** Kişisel Gmail/Calendar'a erişemez (yalnız Workspace domain-wide delegation). fikrieren@gmail.com kişisel → çalışmaz.

### B: Claude Code MCP Google araçları
**Açıklama:** Bu oturumda bağlı Gmail/GCal MCP'yi kullan.
**Reddetme sebebi:** Onlar Claude Code oturum araçları — deploy edilen Blazor app'in değil. Dashboard ayrı uygulama, kendi OAuth'u gerek.

### C: (SEÇİLEN) Kullanıcı-onaylı OAuth2 + refresh-token
**Açıklama:** Google Cloud OAuth client → bir kerelik consent → refresh-token DB'de → Google.Apis ile Calendar/Gmail çağrısı.
**Sebep:** Kişisel Google hesabına tek-kullanıcı erişimin standart yolu; Gemini (Google) ekosistemiyle hizalı.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| OAuth kurulum sürtünmesi (Google Cloud) | orta | yüksek | Adım-adım rehber; test-user modu (doğrulama gerekmez) |
| Yanlış mail gönderme | yüksek | orta | Gönderme ASLA otomatik — taslak+CFO onay+ikinci "Gönder" tık |
| SQL/PII mail gövdesine sızar | yüksek | orta | source-to-sink izolasyon: araç sonucu otomatik mail'e gitmez; gövde LLM-yazımı CFO onaylı |
| Refresh-token iptal/expiry | orta | düşük | 401'de "yeniden bağlan" akışı; token DB'de, /auth/google ile tazele |
| Unverified-app consent uyarısı | düşük | yüksek | Test-user olarak ekle (External + test) → uyarı geçilir |
| Google API quota | düşük | düşük | Tek kullanıcı, cömert quota |

## 5. Done Criteria

- [ ] `/auth/google` → consent → callback → refresh-token DB'ye yazıldı (bir kerelik).
- [ ] "yarın 14:00 ekiple toplantı" → `takvim_etkinlik_oner` → onay kartı → **Onayla** → Google Takvim'de gerçek etkinlik + davet.
- [ ] "bugünkü gelen kutusu özeti" → `mail_ozet` → okunabilir Türkçe özet (PII makul).
- [ ] "X'e şu konuda yanıt yaz" → `mail_taslak_oner` → onay kartı → **Gönder** (ikinci onay) → Gmail'de gönderildi VEYA taslak.
- [ ] Güvenlik: asistan onaysız etkinlik/mail OLUŞTURAMAZ (kod + canlı doğrula).
- [ ] Build yeşil + canlı uçtan-uca test.

## 6. Rollback Planı

- Git revert (her adım ayrı commit).
- Araçları geri çek: AsistanAraclar Tanimlar'dan takvim/mail çıkar → asistan eski haline (görev+veri).
- Token tablosu DROP — yan etki yok (izole).
- NuGet geri alınır; OAuth endpoint'leri AllowAnonymous, kaldırılması güvenli.

## 7. Adımlar / TODO

1. [ ] **F2-1** Ön-koşul: Google Cloud OAuth client (KULLANICI — §10 rehber) → client_id/secret .env.
2. [ ] **F2-2** NuGet + GoogleAuthService (OAuth flow + PanelGoogleToken store) + `/auth/google[/callback]`.
3. [ ] **F2-3** TakvimMailAraclar: `takvim_listele` + `takvim_etkinlik_oner` (Calendar API).
4. [ ] **F2-4** `mail_ozet` + `mail_taslak_oner` (Gmail API) + source-to-sink izolasyon + PII.
5. [ ] **F2-5** AsistanCevap genişlet (öneri-tipi: görev/etkinlik/mail) + Asistan.razor onay kartları.
6. [ ] **F2-6** Güvenlik: dış-aksiyon onaysız çalışmaz (kod + canlı). + commit'ler.
7. [ ] **F2-7** Canlı uçtan-uca test (etkinlik kur + mail özet + taslak) + journal.

## 8. İlişkili
- Master: `plans/20-bkm-asistan-pwa.md` (Faz-2 satır 14-16, 93-100, 153-157).
- Güvenlik: `.claude/rules/security-principles.md` (OAuth secret env, onay), source-to-sink (plan-20 sat.100).
- TODO: B-45 altına F2-* maddeleri.

## 9. Ön-Koşul Rehberi (KULLANICI — Google Cloud, ~10 dk)

1. https://console.cloud.google.com → yeni proje ("BKM-Asistan").
2. **APIs & Services → Enable:** "Google Calendar API" + "Gmail API".
3. **OAuth consent screen:** External → uygulama adı/mail → **Test users**'a `fikrieren@gmail.com` ekle (doğrulama gerekmez).
4. **Credentials → Create OAuth client ID → Web application:**
   - Authorized redirect URI: `http://localhost:5112/auth/google/callback`
5. Çıkan **Client ID + Client Secret**'ı bana ver → `.env`'e yazarım (gitignore).
6. Scope'lar (consent'te onaylayacağın): Calendar etkinlik + Gmail oku + Gmail gönder.

## 10. Onay
- [ ] Plan gösterildi
- [ ] Onay alındı: ____
