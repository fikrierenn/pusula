> ⚠️ **MCP server kodu taşındı (10.06.2026):** Gerçek server kodu artık bağımsız proje **`D:\Dev\sqlserver-mcp`**'de geliştiriliyor (plan: `plans/06-mcp-server-ayiklama.md`). Buradaki `src/` + `dist/` **dondurulmuş kopyadır** — mevcut claude config'leri hâlâ buradaki `dist/index.js`'i çalıştırdığı için duruyor. Config geçişi yapılınca (TODO M-01) buradan silinecek. Bu repo = **BKM analitik çalışma alanı** (raporlar, scriptler, sema/, docs/).

# Pusula — BKM Kitap Analitik Çalışma Alanı

Claude Code Desktop'tan SQL Server veritabanlarına doğrudan erişim sağlayan MCP server.

## Ne Yapıyor?

8 tool ile SQL Server'ını Claude Code'a açıyorsun:

| Tool | Açıklama | Salt Okunur? |
|------|----------|:---:|
| `sql_query` | SELECT sorgusu çalıştır, sonuçları markdown tablo olarak al | ✓ |
| `sql_list_databases` | Tüm veritabanlarını listele (boyut, durum) | ✓ |
| `sql_browse_schema` | Tabloları/view'ları schema bazında keşfet | ✓ |
| `sql_describe_table` | Kolon, PK, FK, index, extended property detayları | ✓ |
| `sql_exec_sp` | Stored procedure çalıştır (ALLOW_WRITE gerekir) | ✗ |
| `sql_table_stats` | Boyut, erişim zamanı, kullanım istatistikleri | ✓ |
| `sql_index_analysis` | Eksik/kullanılmayan index tespit et | ✓ |
| `sql_recent_errors` | Error log'dan son hatalar | ✓ |

## Kurulum (Windows — D:\Dev\)

### 1. Projeyi kopyala

```powershell
cd D:\Dev\
# Bu dizini kopyala veya git clone yap
cd sqlserver-mcp-server
```

### 2. Bağımlılıkları yükle

```powershell
npm install
```

### 3. Environment ayarla

```powershell
copy .env.example .env
notepad .env
```

`.env` dosyasını düzenle:
```env
MSSQL_HOST=localhost
MSSQL_PORT=1433
MSSQL_USER=sa
MSSQL_PASSWORD=SeninkiNeYazBuraya
MSSQL_DATABASE=master
ALLOWED_DATABASES=BKM,YonetIQ
MAX_ROWS=1000
QUERY_TIMEOUT_MS=30000
ALLOW_WRITE=false
ALLOW_MULTI_STATEMENT=false
```

> **Windows Auth kullanmak için:** `MSSQL_TRUSTED=true` ekle

### Güvenlik katmanları (varsayılanlar)

1. **`ALLOWED_DATABASES`** whitelist — listede olmayan DB sorgu reddedilir.
2. **`ALLOW_WRITE=false`** (default) — INSERT/UPDATE/DELETE/DROP/ALTER/CREATE/TRUNCATE/EXEC/MERGE/GRANT/REVOKE/DENY/BACKUP/RESTORE keyword'leri reddedilir.
3. **`ALLOW_MULTI_STATEMENT=false`** (default) — `SELECT 1; UPDATE Foo` gibi çoklu statement reddedilir; `SELECT 1; WAITFOR DELAY ...` DOS bypass'larını kapatır.
4. **Multi-statement parser** yorum + string literal aware (`SELECT 'a;b'` tek statement sayılır, `SELECT 1 /* foo;bar */` tek sayılır).
5. **`sanitizeError`** — bağlantı hatalarındaki password/host sızıntısını `[REDACTED]` ile maskeler.
6. **Server-side TOP wrap** (`MAX_ROWS`) — milyon satırlık SELECT'ler Node heap'ine değil SQL Server'da kesilir.
7. **Request-level timeout** (`QUERY_TIMEOUT_MS`) — süre dolarsa request iptal edilir, hung connection bırakmaz.

### 4. Build et

```powershell
npm run build
```

### 5. Test et

```powershell
npm start
```
Eğer `sqlserver-mcp-server başlatıldı ✓` görüyorsan, çalışıyor.

### 6. Claude Code Desktop'a kaydet

Claude Code Desktop'un config dosyasını aç:

**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

Şunu ekle:

```json
{
  "mcpServers": {
    "sqlserver": {
      "command": "node",
      "args": ["D:\\Dev\\sqlserver-mcp-server\\dist\\index.js"],
      "env": {
        "MSSQL_HOST": "localhost",
        "MSSQL_PORT": "1433",
        "MSSQL_USER": "sa",
        "MSSQL_PASSWORD": "SeninkiNeYazBuraya",
        "MSSQL_DATABASE": "master",
        "ALLOWED_DATABASES": "BKM,YonetIQ",
        "MAX_ROWS": "1000",
        "QUERY_TIMEOUT_MS": "30000",
        "ALLOW_WRITE": "false"
      }
    }
  }
}
```

> **Zaten başka MCP server'ların varsa**, `mcpServers` objesine yeni key olarak ekle.

### 7. Claude Code Desktop'u yeniden başlat

Claude Code Desktop'u kapat/aç. Sol altta 🔌 ikonunda "sqlserver" görünmeli.

## Claude.ai Workspace (Cowork) / Uzak Sandbox Kurulumu

Claude Code Desktop stdio üzerinden lokal çalışır. **Claude.ai Workspace (cowork / virtual computer)** uzak sandbox'ta çalıştığı için stdio ile bağlanamaz — HTTP transport + public tünel gerekir. "Setting up Claude's workspace..." ekranında sonsuz beklemek, MCP kırmızı görünmek tipik transport uyumsuzluğu belirtisidir.

### 1. HTTP modunda başlat

`.env` dosyasında:

```env
MCP_TRANSPORT=http
MCP_PORT=3333
MCP_PATH=/mcp
MCP_AUTH_TOKEN=<uzun-rastgele-string>
```

```powershell
npm run build
npm start
```

Stderr'de `sqlserver-mcp-server (http) http://0.0.0.0:3333/mcp başlatıldı ✓` görmelisin. Sağlık kontrolü: `curl http://localhost:3333/healthz` → `ok`.

### 2. Tünel aç (cloudflared)

```powershell
# Hızlı tünel (kayıtsız, geçici URL)
cloudflared tunnel --url http://localhost:3333
```

Çıktıdaki `https://<random>.trycloudflare.com` URL'sini kullan. (Kalıcı kullanım için named tunnel + subdomain önerilir.)

ngrok alternatifi: `ngrok http 3333`.

### 3. Workspace'e MCP connector ekle

Claude.ai Workspace ayarlarında **Add MCP server** → Remote (HTTP):
- URL: `https://<random>.trycloudflare.com/mcp`
- Authorization header: `Bearer <MCP_AUTH_TOKEN>`

Workspace yeniden yüklendiğinde bootstrap tamamlanmalı, MCP yeşile dönmeli.

### 4. "Sessiz hang" koruması

Bu sürümde:
- `sql_query` sorguyu SQL Server tarafında `SELECT TOP (N) * FROM (<your query>)` olarak sarar; milyon satırlık taramalar Node heap'ine yığılmaz.
- `QUERY_TIMEOUT_MS` dolunca request `request.cancel()` ile SQL tarafında iptal edilir, net hata döner.
- Tool handler'lar stderr'e `start/ok/err` logları yazar — Workspace/Desktop logundan takip edilebilir.
- Büyük sonuç JSON bloğu otomatik kesilir (>500 satır veya >500 KB).

## Güvenlik

- **Varsayılan: SALT OKUNUR.** `sql_query` sadece SELECT çalıştırır.
- `ALLOW_WRITE=true` açılmadan INSERT/UPDATE/DELETE/EXEC çalışmaz.
- `ALLOWED_DATABASES` ile hangi veritabanlarına erişileceğini kısıtla.
- `MAX_ROWS` ile büyük sonuç setlerini kes.
- `QUERY_TIMEOUT_MS` ile uzun sorguları timeout yap.
- SQL injection koruması: parametrize SP çağrıları. Ancak `sql_query` tool'u raw SQL alır — bu bilinçli bir tasarım kararı, çünkü Claude Code zaten güvenilen bir ortam.

## Kullanım Örnekleri (Claude Code'dan)

```
"BKM veritabanındaki bkm schema'sında kaç tablo var?"
→ Claude: sql_browse_schema(database="BKM", schema_filter="bkm")

"bkm.SatisDetay tablosunun yapısını göster"
→ Claude: sql_describe_table(table_name="bkm.SatisDetay", database="BKM")

"Bu ay BKM'nin mekan bazlı satış karşılaştırmasını çıkar"
→ Claude: sql_query(query="SELECT ...", database="BKM")

"YonetIQ veritabanında eksik indexler var mı?"
→ Claude: sql_index_analysis(database="YonetIQ")
```

## Geliştirme

```powershell
# Dev modda çalıştır (tsx ile hot reload)
npm run dev

# Build
npm run build

# MCP Inspector ile test
npx @modelcontextprotocol/inspector
```

## Stack

- TypeScript + Node.js
- `@modelcontextprotocol/sdk` — MCP protocol implementation
- `mssql` — SQL Server TDS driver (tedious)
- `zod` — Runtime input validation
- stdio transport — Claude Code Desktop entegrasyonu
