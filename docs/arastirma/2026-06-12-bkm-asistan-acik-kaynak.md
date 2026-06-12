# BKM-Asistan — Açık Kaynak Araştırması

> Kaynak: deep-research (24 kaynak, 12.06.2026) + sentez. OpenClaw'dan esinlenme.
> **VİZYON:** Genel kişisel/ofis AI asistanı (CFO'nun "ikinci beyni"). Raporlama/BI sadece YAN araçlardan biri.

## 1. BKM-Asistan = Kişisel Ofis Asistanı (BI değil, BI bir eklenti)

**ÇEKİRDEK (asıl iş — günlük akış):**
| Yetenek | Örnek | API/repo |
|---|---|---|
| **Mail tara+özetle** | gelen kutusu → önemli/acil ayır, günlük özet, aksiyon çıkar | **Microsoft Graph** (kurumsal Outlook) · Gmail API |
| **Hatırlatma** | "yarın tedarikçiyi ara" → zamanlı bildirim | Telegram + cron/schedule |
| **Toplantı planla** | uygun zaman bul, davet gönder | **Graph Calendar** / Google Calendar |
| **Görev oluştur** | mailden/sohbetten görev üret + takip | **Graph To Do** · Todoist · basit SQL |
| **Sohbet/komut** | serbest soru, doğal dil komut | agent loop + Claude |

**YAN ARAÇLAR (eklenti — gerektiğinde çağrılır):**
| Yetenek | Örnek | Kaynak |
|---|---|---|
| BKM-BI sorgu | "dün ciro ne oldu" → SQL → cevap | sema + Dapper + gm-rapor (ZATEN VAR) |
| Operasyon uyarı | "iade %5 aştı" push | n8n eşik akışı |

→ Yani: asistan **mail/takvim/görev** odaklı çalışır; CFO arada BKM verisi de sorabilir. BI, 50 yetenekten biri.

### Örnek akış (kullanıcının asıl istediği) — Not → Görev → Ata
```
1. CFO Telegram'a kısa not atar:
   "özlüce vitrin yenilensin, ramazan teması, bütçe ayrılsın"
2. Asistan notu GELİŞTİRİR (yapılandırır):
   Başlık: Özlüce vitrin yenileme (Ramazan)
   Açıklama: ... · Öncelik: orta · Tahmini bütçe sorusu · Kabul kriteri
   → CFO'ya taslağı gösterir, onay ister
3. CFO: "bunu Murat'a görev olarak at"
4. Asistan:
   • görevi oluşturur (Microsoft Planner/To Do veya görev tablosu)
   • Murat'a atar (mail + Telegram bildirim)
   • takibe alır (son tarih hatırlatma, durum sorgusu)
5. Sonra CFO: "Murat'ın görevleri ne durumda" → asistan özet
```
**Gereken parçalar:** ekip/kişi rehberi (Murat=kim, kanalı) · görev sistemi (atama+durum) · onay adımı (taslağı göster, sonra at). Bu "tek-kullanıcı asistan"ı **ekip orkestrasyonuna** çıkarır.
- **Görev sistemi seçeneği:** Microsoft Planner (Graph — ekip görevi+atama+durback) ⭐ · Todoist (paylaşımlı) · kendi SQL tablo (basit, tam kontrol).
- **Kişiye ulaşma:** mail (resmi taslak) + Telegram (bildirim) — kişi rehberi (ad→mail/chat_id) gerekir.

**Anahtar:** Kurumsal mail **Microsoft 365/Exchange** ise → **Microsoft Graph API** tek noktadan mail+takvim+görev+kişiler (en güçlü kombo). Kişisel Gmail için Gmail+Calendar API. **n8n** her ikisini orkestre eder (mail trigger → Claude özet → görev/hatırlatma → Telegram, kod yazmadan).

## 2. Kategori Değerlendirme (BKM uygunluk: .NET stack, self-host, lisans)

### Asistan gateway'ler
| Repo | Lisans | Stack | BKM uygunluk | Karar |
|---|---|---|---|---|
| **OpenClaw** | — | TypeScript/Node | 15 kanal/sandbox/companion = aşırı | ❌ klonlama, fikir al |
| **LibreChat** | MIT ✅ | Node | **MCP client** (resmi) — mevcut sema MCP'yi takar | ⚠️ ağır ama MCP köprüsü değerli |
| AnythingLLM | — | Node/Docker | Telegram **tek-kullanıcı modu** (BKM tam!) | ⚠️ hazır ama kara-kutu |
| Open WebUI | — | Python | Pipelines **deprecated** | ❌ |

### Conversational BI / text-to-SQL
| Repo | Stack | MSSQL | BKM uygunluk | Karar |
|---|---|---|---|---|
| **DataLine** | Python | **native MSSQL** ✅ | **local-first**, veri LLM'den gizli, charting | ⭐ en uygun — incele/dene |
| Vanna | Python | MSSQL ✅ | agentic text-to-SQL, RAG | ⭐ sema'yı eğitim verisi yap |
| WrenAI | Python | MSSQL belirsiz ⚠️ | semantic layer (MDL) — sema'mıza benzer | fikir: MDL ≈ sema/*.yaml |

### Agent framework
| Repo | Stack | BKM uygunluk | Karar |
|---|---|---|---|
| **Microsoft Agent Framework** | **.NET + Python** ✅ | Semantic Kernel successor, dashboard ile aynı dil | ⭐ çekirdek agent loop bunda |
| LangGraph | Python | graph + checkpoint hafıza | fikir: state/memory deseni |
| CrewAI / AutoGen | Python | çok-ajan | BKM tek-ajan yeter, gereksiz |

### Otomasyon / uyarı (Katman B+C)
| Repo | Stack | BKM uygunluk | Karar |
|---|---|---|---|
| **n8n** | Node (self-host) | **MSSQL + Telegram hazır entegrasyon**, DB monitoring/alerting | ⭐ Katman B (uyarı) için hazır — kod yazmadan |
| Activepieces | Node | n8n alternatifi, daha sade | alternatif |

### Mesajlaşma kanalı (.NET — Katman D)
| Repo | Lisans | BKM uygunluk | Karar |
|---|---|---|---|
| **Telegram.Bot** | MIT ✅ | C# %99.9, en popüler .NET, dashboard stack | ⭐ kanal = bu |
| Whatsapp-Business-Cloud-Api-Net | MIT ✅ | C#/.NET, NuGet, ASP.NET DI | WhatsApp gerekirse |
| WAHA | — | WhatsApp+C# (no Business API) | alternatif |

## 3. Önerilen Mimari (ofis asistanı merkez, BI yan araç)

```
┌─ KANAL ── Telegram.Bot (C#, MIT) ← CFO telefondan ─┐
└──────────────────────┬─────────────────────────────┘
                       ▼
┌─ AGENT LOOP ── MS Agent Framework (.NET) + Claude ─┐
│  doğal dil → hangi araç? → çağır → Türkçe cevap    │
└──────────────────────┬─────────────────────────────┘
                       ▼
┌─ ARAÇLAR (asistanın elindeki yetenekler) ──────────┐
│  ÇEKİRDEK (ofis):                                  │
│   • Mail (Microsoft Graph / Gmail API)             │
│   • Takvim (Graph / Google Calendar)               │
│   • Görev+Hatırlatma (Graph To Do / SQL tablo)     │
│  YAN (BKM-BI — gerektiğinde):                      │
│   • sema + Dapper + gm-rapor SQL (ZATEN VAR)        │
└──────────────────────┬─────────────────────────────┘
                       ▼
┌─ OTOMASYON ── n8n self-host (kod yazmadan akış) ───┐
│  • mail geldi → Claude özet → görevse görev aç     │
│  • zamanlı: sabah özet, hatırlatma push            │
│  • BKM eşik: iade%>5 / bekleyen>8g → uyarı         │
└────────────────────────────────────────────────────┘
```
**Tek karar noktası:** Kurumsal mail M365 mi? Evet → **Microsoft Graph** (mail+takvim+görev TEK API, .NET SDK var). Hayır → Gmail+Google Calendar.

## 4. Ne Almalı / Ne Atmalı

**AL:**
- **Telegram.Bot** (.NET kanal — MIT, stack uyumlu)
- **Microsoft Agent Framework** (.NET agent loop — SK successor)
- **DataLine/Vanna deseni** (text-to-SQL; sema'yı eğitim/şema verisi yap)
- **n8n** (Katman B uyarı — kod yazmadan SQL→Telegram eşik akışı)
- **WrenAI MDL fikri** = bizim `sema/*.yaml` zaten bu (semantic layer)

**ATMA:**
- OpenClaw bütünü (15 kanal, sandbox, companion, voice — BKM tek kullanıcı/tek kanal)
- Çok-ajan (CrewAI/AutoGen — tek ajan yeter)
- Open WebUI Pipelines (deprecated)
- WhatsApp Business (Meta onay/webhook yükü — Telegram'la başla)

## 5. BKM Avantajı (yarısı hazır)
- ✅ **Semantic layer:** `sema/*.yaml` = WrenAI MDL'in elle yapılmış, doğrulanmış hali
- ✅ **Araç kataloğu:** gm-rapor L/M/K + 30+ doğrulanmış SQL
- ✅ **Veri katmanı:** Dapper/Queries (Blazor)
- ✅ **Stack:** .NET → Telegram.Bot + Agent Framework aynı dil
- ❌ **Eksik:** kanal (Telegram) + agent loop + uyarı akışı (n8n)

→ "Kendi yapın" = OpenClaw'ı klonlamak DEĞİL, bu 3 eksiği eklemek. Çekirdek bir hafta sonu.

## 6. Önerilen Faz Planı (B-45 detay) — OFİS ÖNCE, BI sonra
1. **Faz 1 (POC):** Telegram.Bot + Agent Framework + **mail özet** (Graph/Gmail). "Bugün önemli mail var mı" → özet. + hatırlatma. (~2-3 gün)
2. **Faz 2:** Takvim + görev — toplantı planla, mailden görev üret, To Do/SQL takip.
3. **Faz 3:** n8n otomasyon — sabah mail özeti push, zamanlı hatırlatma.
4. **Faz 4 (BI eklenti):** sema+gm-rapor aracını tak — "dün ciro?" de cevaplasın. (BKM tarafı ZATEN hazır, sadece araç olarak bağla.)
5. **Faz 5:** BKM eşik uyarıları (n8n) + operasyon komutları (dikkatli).

> Önce CFO'nun günlük akışı (mail/takvim/görev), sonra BI. BI en kolayı (altyapı hazır) ama vizyonun küçük parçası.
> **Güvenlik baştan:** tek-kullanıcı (Telegram user_id whitelist), mail/takvim OAuth token güvenli sakla (.env/secret), Claude'a yazma-yetkisi onaylı.

## Kaynaklar (doğrulanmış)
- LibreChat MIT + MCP client (3-0 / 2-0 vote): github.com/danny-avila/librechat
- DataLine MSSQL+local-first: github.com/RudderStack/dataline
- Vanna MSSQL text-to-SQL: github.com/vanna-ai/vanna
- WrenAI GenBI/MDL: github.com/Canner/WrenAI
- MS Agent Framework .NET: learn.microsoft.com/agent-framework
- Telegram.Bot MIT C#: github.com/TelegramBots/Telegram.Bot
- WhatsApp Cloud .NET MIT: github.com/gabrieldwight/Whatsapp-Business-Cloud-Api-Net
- n8n MSSQL+Telegram: n8n.io/integrations/microsoft-sql/and/telegram
