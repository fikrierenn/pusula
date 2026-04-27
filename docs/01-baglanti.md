# 01 — Veritabanı Bağlantısı

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)

İki ayrı SQL Server'a paralel erişim. Her biri Claude Desktop config'inde ayrı MCP entry olarak tanımlı.

---

## 1) Ana ERP sunucusu — `sqlserver`

- **Host:** `192.168.40.201:1433`
- **MCP tool prefix:** `mcp__sqlserver__*` (sql_query, sql_list_databases, sql_describe_table, vs.)
- **İzinli DB'ler:** `master, DerinSISBkm, DerinSISBkmCrm, DerinSISBkmWeb, BKMDATA, EncoreMerkez`
- **DB (ERP):** `DerinSISBkm` — ana ERP (irsHrk, fat, urn, bkm şeması)
- **DB (Sınav):** `BKM` — sınav operasyonu yazılımı (snv şeması: Donem, Okul, Ogrenci, SinavUrun, Siparis, SinavSiparisFisEncore)
- **DB (POS):** `EncoreMerkez` — mağaza POS fiş arşivi (Sales, SalesProducts, Products, Stores)

## 2) Express sunucusu — `sqlserver-express`

- **Host:** `192.168.40.66\SQLEXPRESS` (named instance)
- **MCP tool prefix:** `mcp__sqlserver-express__*`
- **Port notu:** Named instance — ya statik port (1433/1434) açılması ya da SQL Browser servisi gerekir. Config'de `MSSQL_PORT=1433` yazıyorsa SQL Express'te IPAll → TCP Port 1433 sabitlenmiş demektir.
- **Kullanım amacı:** [DOLDUR]
- **İzinli DB'ler:** `ALLOWED_DATABASES` boş → hepsi açık.

## Ortak Kurallar

- **Config dosyası:** `C:\Users\fikri.eren\AppData\Roaming\Claude\claude_desktop_config.json`
- **MCP server kodu:** `D:\Dev\sqlserver-mcp-server\` — `src/services/database.ts` env vars okur (MSSQL_HOST, MSSQL_PORT, MSSQL_USER, MSSQL_PASSWORD, MSSQL_DATABASE, MSSQL_TRUSTED, ALLOWED_DATABASES, ALLOW_WRITE, MAX_ROWS, QUERY_TIMEOUT_MS). Kod değişikliği sonrası `npm run build` + Claude Desktop tam restart.
- **Tarih formatı (yerel):** **DMY** — `CONVERT(date, '14.04.2026', 104)` veya `dd.MM.yyyy`. `yyyy-MM-dd` **KULLANMA**.
- **Tarih formatı (linked server ODAKJOKER):** `YYYYMMDD` ISO (DMY sessiz yanlış eşleşme yapıyor). Detay: [`05-eticaret-joker.md`](05-eticaret-joker.md)
- **Hangi sunucu?** BKM/ERP/envanter = `sqlserver`. "Express'te / 66'da / diğer sunucuda" dendiğinde = `sqlserver-express`. Emin değilsen sor.

## Collation Haritası (cross-db join'de kritik)

| DB | Collation |
|---|---|
| `DerinSISBkm.dbo.*` | `Turkish_CI_AS` |
| `EncoreMerkez.dbo.*` | `Turkish_CI_AS` |
| `BKM.snv.*` | `Turkish_CS_AS` (case-sensitive) |

Cross-db string join'de `COLLATE Turkish_CI_AS` iki tarafa da zorunlu — detay: [`04-kanal-koprusu.md`](04-kanal-koprusu.md).

## Bilinen Sorunlar

- Bağlantı zaman zaman düşüyor (`Failed to connect ... in 15000ms`). Yeniden dene, gerekirse kullanıcıya bildir.
