# Plan 20 — BKM-Asistan (PWA-içi, Claude API tool-use) — B-45

## Problem
CFO telefondan (PWA) doğal dille "dün kargo ne oldu, geçen aya göre ciro?" sorup **veri-temelli Türkçe cevap** alamıyor. Mevcut Asistan.razor sadece not→görev-taslak (yerel qwen). Veri-sorgu yeteneği yok. Dashboard'da sayfa sayfa gezmek yerine soru-cevap isteniyor.

## Vizyon (17.06 genişletme): CFO "elim-ayağım" Executive Assistant
Sadece veri/kod değil — CFO'nun günlük işini yöneten çok-araçlı asistan. **PWA-içi**, tek chat, tool-use loop. Yetenek = tool (learn-claude-code dispatch-map: yeni yetenek = yeni handler, loop değişmez).

### Yetenek Matrisi (tool'lar)
| # | Yetenek | Tool | Backend | Faz | Not |
|---|---|---|---|---|---|
| 1 | **Veri-sorgu** (ciro/kargo/stok) | `sql_sorgu` (salt-okuma) + `sema_oku` | Dapper + sema/*.yaml | **Faz 1** | deep-research bunu derinleştiriyor |
| 2 | **Görev/TODO** (ekle/listele/kapat/ata) | `gorev_*` | `GorevService` (BkmPanel — MEVCUT) | **Faz 1** | en kolay, servis hazır |
| 3 | **Rapor/KPI** (brief/sunum) | `gm_rapor` | gm-rapor + bkm-sunum | Faz 2 | hazır skill'ler |
| 4 | **Mail özet** (gelen kutusu → özet) | `mail_oku` | Graph API (M365) / IMAP — backend ARAŞTIR | Faz 2 | bkmkitap.com mail (B-20) |
| 5 | **Mail taslak** (yanıt/yeni öner) | `mail_taslak` | Graph/SMTP — **gönderme ONAY** | Faz 2 | taslak üret, CFO onaylar+gönderir |
| 6 | **Takvim/ajanda** (etkinlik/hatırlatma) | `takvim_*` | Graph Calendar / Google — ARAŞTIR | Faz 3 | TakvimService tatil≠kişisel ajanda (yeni) |
| 7 | **Hatırlatma/follow-up** | `hatirlatma` | BkmPanel tablo + bildirim | Faz 3 | "X'i ara, Y'yi takip et" |

### Öğrenen / Kişiselleşen Katman (CROSS-CUTTING — her fazda aktif; 17.06 vizyon)
"Beni anlasın, öğrensin, sürekli gelişsin." BKM'nin kendi continuous-learning DNA'sının (/learn + sema-ogren + MEMORY.md + ECC instinct) **asistana uyarlanması**. Veri DIŞARI gitmez — bellek lokal BkmPanel.

- **`PanelAsistanBellek` tablosu** (BkmPanel): `tip` (tercih / gerçek / düzeltme / kısayol / sık-soru), `icerik`, `confidence`, `kullanim_sayisi`, `son_kullanim`, `kaynak` (hangi sohbet). atomic + confidence (sema-ogren pattern).
- **RECALL (her sohbet başı):** soruya ilgili bellek → sistem-prompt'a enjekte (CFO tercihleri, sık metrikler, ton, kısayollar). "dün ciro" → CFO'nun "ciro = KDV-hariç net, perakende+online" tercihini hatırla.
- **LEARN (sohbet içi):**
  - **Düzeltme:** CFO "hayır onu değil, X'i kastettim" → kalıcı (bir daha aynı hata yok). learn-claude-code s09 recall + ECC instinct.
  - **Tercih:** "ben hep şöyle isterim" → bellek (format/ton/varsayılan dönem).
  - **Sık-soru → kısayol:** aynı soru 3× → quick-reply öner ("Her sabah ciro özeti ister misin?").
  - **Hatadan ders:** yanlış SQL/yorum → düzelt + bellek (sema-ogren'e köprü, kalıcı şema gerçeği ise).
- **DECAY/CURATOR:** bellek yaşlanır (sema decay pattern); stale tercih → yeniden-doğrula. consolidate benzeri periyodik bakım.
- **Kişiselleşme:** zamanla CFO'nun dilini/önceliğini öğrenir — quick-reply'lar, varsayılan dönem, ton CFO'ya göre adapte. "elim-ayağım" hissi buradan gelir.
- **Sınır:** bellek = TERCİH/davranış (PII değil). Finansal rakam asistan-belleğine yazılmaz (her sorguda canlı SQL). Claude API'ye sadece tercih-özeti gider.

### Faz sırası
- **Faz 1 (çekirdek):** tool-use loop + veri-sorgu + görev + **öğrenen katman çekirdeği** (PanelAsistanBellek + recall/learn). Öğrenme baştan içeride — sonradan eklenmez.
- **Faz 2:** rapor + mail (özet/taslak — Graph/IMAP backend kararı, gönderme onaylı).
- **Faz 3:** takvim/ajanda + hatırlatma + kişiselleşme derinleşir (proaktif öneriler).

### Scope (Faz 1 — bu plan)
- **PWA-içi**: `Asistan.razor` → veri-sorgu + görev modu (intent ayrımı).
- **Claude API tool-use loop** (yerel qwen zayıf → Anthropic SDK).
- Faz-1 araçlar: `sql_sorgu` (salt-okuma, sema-driven) + `sema_oku` + `gorev_ekle/listele/kapat`.
- Cevap: Türkçe + sayı/mini-tablo. B-84 auth arkasında, tek-kullanıcı CFO.
- Mail/takvim Faz 2-3 (ayrı plan; backend = Graph mı IMAP mı araştır — BKM mail M365 mi?).

## Alternatifler (reddedilen)
- ~~Telegram bot~~ — ekstra kanal/bağımlılık (Telegram.Bot), PWA zaten var, auth ayrı. 17.06 reddedildi.
- ~~Yerel qwen (LlmService) tool-use~~ — küçük model tool-use/SQL üretimi zayıf, güvenilmez. Claude API primary.
- ~~Serbest SQL üretimi (guard'sız)~~ — asistan DROP/UPDATE üretebilir → **salt-okuma guard ZORUNLU** (aşağıda).
- ~~Text-to-SQL fine-tune~~ — over-engineering; sema/*.yaml context + Claude yeterli.

## Riskler
- **GÜVENLİK (en kritik):** asistan SQL = yalnız `SELECT`. INSERT/UPDATE/DELETE/DROP/ALTER/EXEC/MERGE/TRUNCATE → RED. Parser/regex guard + `ALLOW_WRITE=false` + ayrı salt-okuma bağlantı. Tek-DB allowlist (sema kapsamı). Asistan asla yazma yapmaz.
- **API maliyet:** tek-kullanıcı, az sorgu. Model: Sonnet (denge) veya Haiku (ucuz/hızlı). Sistem-prompt'a sema özeti (token). Bağlam-sıkıştırma (uzun sohbet).
- **Yanlış rakam:** asistan SQL'i sema-driven olmalı (doğru join/filtre/KDV-hariç/iade-netleme). Sistem-prompt = sema kuralları. Cevapta "kaynak/sorgu" şeffaflığı.
- **Sır:** ANTHROPIC_API_KEY → .env (gitignore), plaintext kod YASAK.
- **SQL injection değil ama:** Claude'un ürettiği SQL doğrudan çalışır → salt-okuma guard tek savunma. Sonuç satır limiti (MAX_ROWS).

## Done Kriterleri
- "dün ciro?" / "geçen ay kargo iade?" → doğru sema-driven SELECT + Türkçe cevap + sayı.
- Yazma denemesi (asistan veya kullanıcı "sil") → guard reddeder, log.
- API key yoksa graceful ("asistan yapılandırılmamış").
- Görev-taslak modu (mevcut) bozulmaz — iki mod bir arada.
- B-84 auth arkasında; salt-okuma bağlantı (write imkânsız).
- Build yeşil + smoke (3 örnek soru doğru rakam, dashboard ile mutabık).

## Rollback
Yeni dosyalar (AsistanService/AsistanAraclar) + Asistan.razor genişleme + csproj Anthropic SDK. Sorun → revert; LlmService görev-taslak modu kalır.

## Mimari
```
Asistan.razor (chat)
  → AsistanService.SorAsync(soru)
      → Anthropic SDK: messages + tools[sql_sorgu, sema_oku] + system(sema kuralları)
      → loop: tool_use → AsistanAraclar.Execute → tool_result → Claude → final text
  → cevap (Türkçe + opsiyonel tablo)
```
- **AsistanAraclar.cs:** `sql_sorgu(sql)` — SaltOkumaGuard(sql) → Db salt-okuma bağlantı → satır limitli sonuç (JSON). `sema_oku(dosya)` — sema/*.yaml döndür.
- **SaltOkumaGuard:** trim→tek statement→`SELECT`/`WITH` ile başlamalı; yasak keyword (INSERT/UPDATE/DELETE/DROP/ALTER/EXEC/MERGE/TRUNCATE/GRANT/sp_/xp_) RED; `;` multi-statement RED.
- **Db:** salt-okuma bağlantı (ApplicationIntent=ReadOnly veya ayrı login; en azından guard). MAX_ROWS limit.

## Kod Organizasyonu (asistan kısımları AYRI — dağılmasın)
Tek proje (dashboard) ama asistan kodu kendi grubunda:
- `dashboard/Data/Asistan/` namespace: `AsistanService.cs` (tool-use loop), `AsistanAraclar.cs` (tool tanım+exec), `AsistanBellek.cs` (PanelAsistanBellek recall/learn), `SaltOkumaGuard.cs`, `PiiMaske.cs`.
- `dashboard/Components/Pages/Asistan.razor` — UI (mevcut, genişler).
- BkmPanel tabloları: `PanelGorev` (var), `PanelAsistanBellek` (yeni).
- Plan dosyaları: bu plan = master + Faz-1. Faz-2 (mail/takvim) → Faz-1 bitince `plans/21-asistan-mail-takvim.md`. Faz-3 → plan-22. (Şimdi bölme erken — detay yok.)

## Adımlar
1. **Anthropic SDK** — nuget (`Anthropic.SDK` veya raw HttpClient). `.env` ANTHROPIC_API_KEY + model (haiku/sonnet). Db'ye okuma-guard helper.
2. **AsistanAraclar.cs** — tool tanımları (JSON schema) + `sql_sorgu` (guard+exec+limit) + `sema_oku`. Salt-okuma guard birim-mantığı.
3. **AsistanService.cs** — tool-use loop (system=sema kuralları özeti, max N tur, bağlam-sıkıştırma). Hata/loglu.
4. **Asistan.razor** — veri-sorgu modu: chat input → SorAsync → cevap balonu (+ tablo varsa). Görev-taslak modu korunur (intent ayrımı: soru mu / not mu).
5. **Güvenlik smoke** — yazma denemesi reddi + 3 veri sorusu doğru rakam (dashboard mutabakat).
6. DI kayıt + sema sistem-prompt + Türkçe.

## Done sonrası
- Plan → archive. Journal + TODO B-45 [x]. /learn (tool-use SQL guard dersi).
- v2: grafik cevap, gm-rapor aracı, ses.

## Repo Sömürüsü — ASİSTAN gözüyle (18.06; daha önce skill/disiplin gözüyle bakılmıştı)
Bu oturumda taranan repolar, BKM-Asistan'ın PARÇALARINA ders verir:

| Repo | Asistan'a sömürü | Faz |
|---|---|---|
| **learn-claude-code** ⭐⭐ | **Çekirdek harness:** tool-use loop (s01-02) + **permission/salt-okuma (s03)** + hook (s04) + planlama/delegasyon (s05-06) + **memory/recall (s09)** + **bağlam-sıkıştırma (s08)** + retry (s11). Asistan mimarisi birebir bu. | 1 |
| **superpowers** ⭐ | **Asistan düşünme disiplini:** brainstorming → belirsiz soruyu CFO'ya netleştir (SQL'den ÖNCE) · verification-before-completion → cevabı sunmadan doğrula (rakam mantıklı mı) · systematic-debugging → yanlış cevap root-cause · subagent → karmaşık görev böl (depth≤2, Hermes) | 1-2 |
| **vibecosystem** | **Oto-öğrenme döngüsü:** "her hata kurala" → asistan düzeltme→PanelAsistanBellek (öğrenen katman) · dev-QA döngüsü → cevap üret→self-check→düzelt (max 3) | 1 (memory) |
| **karpathy + mattpocock** | **Cevap-öncesi:** think-before (varsayımı açık et) · `/grill-with-docs` → eksik bilgide netleştirme sorusu (uydurma yok) · goal-driven (CFO'nun asıl istediği) | 1 |
| **TestSprite** | **Self-verify:** asistan SQL sonucu → "bu mantıklı mı, dashboard ile tutar mı" iç-doğrulama (consistent-bundle → tutarlı cevap formatı) | 2 |
| **ui-ux-pro-max** | **Chat UX:** quick-reply chip · kart/mini-tablo cevap · cursor/focus/Türkçe (asistan-ui §5.5 zaten) · "beni anlıyor" hissi = öğrenen + proaktif öneri | 1 |
| **awesome-claude-skills (Document)** | **Asistan çıktısı:** "sunum çıkar/PDF ver" → `bkm-sunum` + anthropic pdf/pptx araç olarak | 2 |
| CodeGraph / app-ideas / alexa / karpathy-tekrar | Asistan'a doğrudan ders yok (kod-nav / fikir-liste / Alexa / zaten coding-discipline) | — |

**Hermes (plan-12) asistan dersleri:** tool **registry single-source** (dispatch-map — yeni yetenek=1 handler) · **context-compression** (uzun sohbet+memory sıkıştır) · **error-classifier** (mevcut `SqlErrorClassifier` REUSE — tool hata transient/fatal) · **delegation depth-bounded** (karmaşık görev subagent ≤2) · **narrow-waist** (yetenek=en dar tool, framework kurma) · **curator** (memory decay — öğrenen katmanda var).

**OpenClaw:** çekirdek (agent-loop + tool-dispatch) AL; 15-kanal/sandbox/companion ATMA (B-45 kararı — PWA tek kanal).

## KVKK / PII Maskeleme (KRİTİK — baştan tasarla, sonradan zor)
Müşteri adı/telefon Claude API'ye giderken **maskelenmeli** (KVKK + finansal gizlilik). Pattern:
- **Tercih:** asistan SQL sonucu CFO'ya Blazor'da DİREKT render (PII CFO'da kalır); Claude'a giden `tool_result`'ta PII **maskeli/agregat** (Open WebUI Filters deseni). Veya müşteri-PII sorgusunda token-replace (lokal geri-eşleme).
- En basit Faz-1: asistan agregat/sayı sorularına odaklı (ciro/adet/trend — PII yok). Müşteri-bazlı (ad/tel) sorgu → maskeli veya CFO-only render.
- Sema'da PII kolonları işaretli (Customer.Name/PhoneNumber) → asistan bunları Claude'a ham göndermez.

## Açık karar (kullanıcı)
- **API key:** Anthropic key var mı? (sk-ant-…) — yoksa edinilmeli.
- **Model:** Haiku (ucuz/hızlı, basit SQL yeter) vs Sonnet (karmaşık soru). Öneri: **Haiku** başla, yetmezse Sonnet.
- **MS Agent Framework mı, çıplak Claude tool-use mu?** → Öneri: **çıplak Claude tool-use loop** (learn-claude-code pattern, basit, tek-ajan). Agent Framework tek-ajanda over-abstraction.
- **Mail backend:** BKM `bkmkitap.com` = M365/Exchange mi? Evet → Graph API (mail+takvim+görev+kişi TEK). Hayır → IMAP/SMTP + Google Calendar. (Faz 2)
