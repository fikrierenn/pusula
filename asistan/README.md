# BKM-Asistan (POC)

Telegram'a not yaz → **yerel LLM** (LLamaSharp, app-içi) görev taslağına çevirir.
Gizlilik: model makinende çalışır, veri hiçbir buluta gitmez.

## Kurulum (tek seferlik)

### 1. Model indir (GGUF)
Türkçe için Qwen2.5-3B (~2GB, CPU'da çalışır):
- https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF
- Dosya: `qwen2.5-3b-instruct-q4_k_m.gguf`
- `asistan/models/` klasörüne koy (veya istediğin yere, path .env'de)

Makinen güçlüyse 7B daha kaliteli: `Qwen2.5-7B-Instruct-GGUF`.

### 2. Telegram bot token
Telegram'da **@BotFather** → `/newbot` → bot adı ver → token al.

### 3. .env (repo kökü `D:\Dev\pusula\.env`'e ekle)
```
TELEGRAM_BOT_TOKEN=123456:ABC...        # BotFather token
LLM_MODEL_PATH=D:\Dev\pusula\asistan\models\qwen2.5-3b-instruct-q4_k_m.gguf
TELEGRAM_USER_ID=                        # (ops) kendi Telegram user_id — sadece sen kullan. Boş=herkes
LLM_GPU_LAYERS=0                         # CUDA GPU varsa 20-35, CPU ise 0
```
> Kendi user_id'ni öğrenmek: bota mesaj at, @userinfobot'a sor, veya boş bırak (POC).
> GPU (NVIDIA) varsa hız için: `dotnet add package LLamaSharp.Backend.Cuda12` + LLM_GPU_LAYERS=35.

## Çalıştır
```
cd asistan
dotnet run
```
Model yüklenir (~10-30sn), bot açılır. Telegram'dan not yaz:
> "özlüce vitrin yenilensin ramazan teması bütçe ayrılsın"

→ görev taslağı (başlık/açıklama/öncelik/kabul kriteri) döner.

## Sonraki adımlar (B-45 roadmap)
- Onay adımı (taslağı göster → "Murat'a at")
- Kişi rehberi + görev atama (mail/Telegram)
- Mail/takvim (Microsoft Graph), ses/dikte, KVKK maskeleme
- BKM-BI aracı (sema+gm-rapor) — "dün ciro?"
