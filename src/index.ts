import "dotenv/config";
import { randomUUID } from "node:crypto";
import { createServer, IncomingMessage, ServerResponse } from "node:http";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import {
  QuerySchema,
  BrowseSchemaInput,
  DescribeTableInput,
  ExecSpInput,
  ListDatabasesInput,
  TableStatsInput,
  IndexAnalysisInput,
  RecentErrorsInput,
  SearchColumnsInput,
  TableRelationshipsInput,
  TableSampleInput,
} from "./schemas/index.js";
import { executeQuery, formatQueryResult } from "./tools/query.js";
import {
  listDatabases,
  browseSchema,
  describeTable,
  formatDatabaseList,
  formatSchemaList,
  formatTableDescription,
} from "./tools/schema.js";
import { executeSp, formatSpResult } from "./tools/sp.js";
import {
  getTableStats,
  analyzeIndexes,
  getRecentErrors,
} from "./tools/diagnostics.js";
import {
  searchColumns,
  formatColumnSearch,
  getTableRelationships,
  formatRelationships,
  getTableSample,
  formatTableSample,
} from "./tools/discovery.js";
import { closeAll } from "./services/database.js";

// ─── Logging (stderr — MCP stdout'u JSON-RPC için) ───────
function log(tool: string, phase: string, data?: Record<string, unknown>) {
  const ts = new Date().toISOString();
  const payload = data ? " " + JSON.stringify(data) : "";
  process.stderr.write(`[${ts}] ${tool} ${phase}${payload}\n`);
}

// ─── JSON payload guard — büyük sonuç için <json> bloğunu kes ──
const MAX_JSON_BYTES = 500 * 1024; // 500 KB
const MAX_JSON_ROWS = 500;

function safeJsonBlock(data: unknown, rowCount?: number): string {
  if (rowCount !== undefined && rowCount > MAX_JSON_ROWS) {
    return `\n\n<json>\n(JSON bloğu atlandı — ${rowCount} satır, MAX_JSON_ROWS=${MAX_JSON_ROWS}. Daha küçük max_rows kullan.)\n</json>`;
  }
  let json: string;
  try {
    json = JSON.stringify(data, null, 2);
  } catch (err) {
    return `\n\n<json>\n(JSON serileştirme hatası: ${(err as Error).message})\n</json>`;
  }
  if (json.length > MAX_JSON_BYTES) {
    return `\n\n<json>\n(JSON bloğu atlandı — ${Math.round(json.length / 1024)} KB > ${MAX_JSON_BYTES / 1024} KB. Daha küçük max_rows kullan.)\n</json>`;
  }
  return `\n\n<json>\n${json}\n</json>`;
}

const server = new McpServer({
  name: "sqlserver-mcp-server",
  version: "1.1.0",
});

// ─── sql_query ────────────────────────────────────────────
server.registerTool(
  "sql_query",
  {
    title: "SQL Sorgusu Çalıştır",
    description:
      "SQL Server üzerinde SELECT sorgusu çalıştırır. Varsayılan: salt okunur. " +
      "ALLOW_WRITE=true ile INSERT/UPDATE/DELETE/EXEC de mümkün. " +
      "Büyük sorgular otomatik olarak server-side TOP N ile sarılır ve " +
      "QUERY_TIMEOUT_MS dolunca SQL tarafında iptal edilir.",
    inputSchema: QuerySchema.shape,
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
    },
  },
  async (args) => {
    const start = Date.now();
    log("sql_query", "start", {
      db: args.database,
      bytes: args.query.length,
      max_rows: args.max_rows,
    });
    try {
      const result = await executeQuery(args.query, args.database, args.max_rows);
      const text = formatQueryResult(result);
      const json = safeJsonBlock(result, result.row_count);
      log("sql_query", "ok", {
        rows: result.row_count,
        ms: Date.now() - start,
        truncated: result.truncated,
        wrapped: result.wrapped_with_top,
      });
      return {
        content: [
          { type: "text", text },
          { type: "text", text: json },
        ],
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_query", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `SQL Hatası: ${msg}` }],
      };
    }
  }
);

// ─── sql_list_databases ───────────────────────────────────
server.registerTool(
  "sql_list_databases",
  {
    title: "Veritabanlarını Listele",
    description:
      "SQL Server instance'ındaki tüm kullanıcı veritabanlarını boyut ve durum bilgileriyle listeler.",
    inputSchema: ListDatabasesInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async () => {
    const start = Date.now();
    log("sql_list_databases", "start");
    try {
      const dbs = await listDatabases();
      const text = formatDatabaseList(dbs);
      log("sql_list_databases", "ok", { count: dbs.length, ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_list_databases", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── sql_browse_schema ────────────────────────────────────
server.registerTool(
  "sql_browse_schema",
  {
    title: "Schema Keşfet",
    description:
      "Bir veritabanındaki tüm tabloları ve view'ları schema bazında listeler. " +
      "Satır sayısı ve boyut bilgisi içerir. schema_filter ile belirli bir schema filtrele.",
    inputSchema: BrowseSchemaInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async (args) => {
    const start = Date.now();
    log("sql_browse_schema", "start", { db: args.database, filter: args.schema_filter });
    try {
      const tables = await browseSchema(args.database, args.schema_filter);
      const text = formatSchemaList(tables);
      log("sql_browse_schema", "ok", { count: tables.length, ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_browse_schema", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── sql_describe_table ───────────────────────────────────
server.registerTool(
  "sql_describe_table",
  {
    title: "Tablo Detayı",
    description:
      "Bir tablonun kolonlarını, tiplerini, PK/FK/index bilgilerini ve extended property açıklamalarını gösterir. " +
      "Format: 'schema.tablo' (örn: 'bkm.SatisDetay').",
    inputSchema: DescribeTableInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async (args) => {
    const start = Date.now();
    log("sql_describe_table", "start", { db: args.database, table: args.table_name });
    try {
      const desc = await describeTable(args.table_name, args.database);
      const text = formatTableDescription(desc);
      log("sql_describe_table", "ok", { ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_describe_table", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── sql_exec_sp ──────────────────────────────────────────
server.registerTool(
  "sql_exec_sp",
  {
    title: "Stored Procedure Çalıştır",
    description:
      "SQL Server stored procedure çalıştırır. ALLOW_WRITE=true gerektirir. " +
      "Parametreler key:value objesi olarak gönderilir. Birden fazla result set destekler.",
    inputSchema: ExecSpInput.shape,
    annotations: {
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: false,
    },
  },
  async (args) => {
    const start = Date.now();
    log("sql_exec_sp", "start", { db: args.database, sp: args.procedure_name });
    try {
      const result = await executeSp(
        args.procedure_name,
        args.database,
        args.parameters
      );
      const text = formatSpResult(result);
      log("sql_exec_sp", "ok", { ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_exec_sp", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [
          {
            type: "text",
            text: `SP Hatası: ${msg}. SP adını schema ile birlikte yazın (örn: bkm.sp_AySonuKontrol).`,
          },
        ],
      };
    }
  }
);

// ─── sql_table_stats ──────────────────────────────────────
server.registerTool(
  "sql_table_stats",
  {
    title: "Tablo İstatistikleri",
    description:
      "Bir tablonun boyut, satır sayısı, son erişim zamanı ve kullanım istatistiklerini gösterir. " +
      "Performans analizi ve kapasite planlaması için kullanılır.",
    inputSchema: TableStatsInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async (args) => {
    const start = Date.now();
    log("sql_table_stats", "start", { db: args.database, table: args.table_name });
    try {
      const text = await getTableStats(args.table_name, args.database);
      log("sql_table_stats", "ok", { ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_table_stats", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── sql_index_analysis ───────────────────────────────────
server.registerTool(
  "sql_index_analysis",
  {
    title: "İndeks Analizi",
    description:
      "Eksik indeks önerilerini ve kullanılmayan indeksleri tespit eder. " +
      "Performans optimizasyonu için kritik. Belirli tablo veya tüm veritabanı bazında çalışır.",
    inputSchema: IndexAnalysisInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async (args) => {
    const start = Date.now();
    log("sql_index_analysis", "start", { db: args.database, table: args.table_name });
    try {
      const text = await analyzeIndexes(args.database, args.table_name);
      log("sql_index_analysis", "ok", { ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_index_analysis", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── sql_recent_errors ────────────────────────────────────
server.registerTool(
  "sql_recent_errors",
  {
    title: "Son Hatalar",
    description:
      "SQL Server error log'undan son X dakikadaki hata ve uyarıları çeker. " +
      "Sorun teşhisinde ilk bakılacak yer.",
    inputSchema: RecentErrorsInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async (args) => {
    const start = Date.now();
    log("sql_recent_errors", "start", { db: args.database, minutes: args.minutes });
    try {
      const text = await getRecentErrors(args.database, args.minutes);
      log("sql_recent_errors", "ok", { ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_recent_errors", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── sql_search_columns ──────────────────────────────────
server.registerTool(
  "sql_search_columns",
  {
    title: "Kolon/Tablo Ara",
    description:
      "Kolon adı veya tablo adında metin arar. Veri modeli keşfi ve semantik katman " +
      "oluşturmak için kullanışlı. Örnek: 'fiyat', 'barkod', 'siparis', 'crm'.",
    inputSchema: SearchColumnsInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async (args) => {
    const start = Date.now();
    log("sql_search_columns", "start", { db: args.database, term: args.search_term });
    try {
      const matches = await searchColumns(args.search_term, args.database);
      const text = formatColumnSearch(args.search_term, matches);
      log("sql_search_columns", "ok", { count: matches.length, ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_search_columns", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── sql_relationships ───────────────────────────────────
server.registerTool(
  "sql_relationships",
  {
    title: "İlişki Haritası",
    description:
      "Veritabanındaki tüm foreign key ilişkilerini veya belirli bir tablonun " +
      "ilişkilerini gösterir. Veri modeli anlayışı ve JOIN stratejisi için kritik.",
    inputSchema: TableRelationshipsInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async (args) => {
    const start = Date.now();
    log("sql_relationships", "start", { db: args.database, table: args.table_name });
    try {
      const rels = await getTableRelationships(args.database, args.table_name);
      const text = formatRelationships(rels, args.table_name);
      log("sql_relationships", "ok", { count: rels.length, ms: Date.now() - start });
      return { content: [{ type: "text", text }] };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_relationships", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── sql_sample_data ─────────────────────────────────────
server.registerTool(
  "sql_sample_data",
  {
    title: "Örnek Veri",
    description:
      "Bir tablodan TOP N örnek satır getirir. Veri yapısını ve içeriği anlamak, " +
      "kolon değerlerini incelemek ve sorgu yazmadan önce veriyi tanımak için.",
    inputSchema: TableSampleInput.shape,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  },
  async (args) => {
    const start = Date.now();
    log("sql_sample_data", "start", { db: args.database, table: args.table_name, rows: args.rows });
    try {
      const rows = await getTableSample(
        args.table_name,
        args.database,
        args.rows
      );
      const text = formatTableSample(args.table_name, rows);
      const json = safeJsonBlock(rows, rows.length);
      log("sql_sample_data", "ok", { rows: rows.length, ms: Date.now() - start });
      return {
        content: [
          { type: "text", text },
          { type: "text", text: json },
        ],
      };
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      log("sql_sample_data", "err", { ms: Date.now() - start, msg });
      return {
        isError: true,
        content: [{ type: "text", text: `Hata: ${msg}` }],
      };
    }
  }
);

// ─── Transport seçimi ────────────────────────────────────

async function startStdio() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  process.stderr.write("sqlserver-mcp-server (stdio) başlatıldı ✓\n");
}

async function startHttp() {
  const port = parseInt(process.env.MCP_PORT || "3333");
  const host = process.env.MCP_HOST || "0.0.0.0";
  const token = process.env.MCP_AUTH_TOKEN || "";
  const path = process.env.MCP_PATH || "/mcp";

  if (!token) {
    process.stderr.write(
      "UYARI: MCP_AUTH_TOKEN boş. HTTP modunda kimlik doğrulamasız açma — sadece yerel test için!\n"
    );
  }

  // Stateful: her yeni bağlantı için bir transport oluşturulur
  const transports = new Map<string, StreamableHTTPServerTransport>();

  const handler = async (req: IncomingMessage, res: ServerResponse) => {
    // CORS (Claude web/cowork için)
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization, mcp-session-id"
    );
    res.setHeader(
      "Access-Control-Allow-Methods",
      "GET, POST, DELETE, OPTIONS"
    );
    res.setHeader("Access-Control-Expose-Headers", "mcp-session-id");

    if (req.method === "OPTIONS") {
      res.writeHead(204).end();
      return;
    }

    // Health
    if (req.url === "/healthz" || req.url === "/health") {
      res.writeHead(200, { "Content-Type": "text/plain" }).end("ok");
      return;
    }

    if (!req.url || !req.url.startsWith(path)) {
      res.writeHead(404).end("not found");
      return;
    }

    // Auth
    if (token) {
      const auth = req.headers["authorization"];
      const expected = `Bearer ${token}`;
      if (auth !== expected) {
        res.writeHead(401, { "Content-Type": "text/plain" }).end(
          "unauthorized"
        );
        return;
      }
    }

    // Body okuma
    let body: unknown = undefined;
    if (req.method === "POST") {
      const chunks: Buffer[] = [];
      for await (const chunk of req) chunks.push(chunk as Buffer);
      const raw = Buffer.concat(chunks).toString("utf8");
      if (raw) {
        try {
          body = JSON.parse(raw);
        } catch {
          res.writeHead(400).end("invalid json");
          return;
        }
      }
    }

    // Session yönetimi
    const sessionId = req.headers["mcp-session-id"] as string | undefined;
    let transport = sessionId ? transports.get(sessionId) : undefined;

    if (!transport) {
      transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => randomUUID(),
      });
      await server.connect(transport);
      const sid = transport.sessionId;
      if (sid) {
        transports.set(sid, transport);
        const t = transport;
        t.onclose = () => {
          if (t.sessionId) transports.delete(t.sessionId);
        };
      }
    }

    await transport.handleRequest(req, res, body);
  };

  const httpServer = createServer((req, res) => {
    handler(req, res).catch((err) => {
      process.stderr.write(`HTTP handler error: ${err}\n`);
      if (!res.headersSent) res.writeHead(500).end("internal error");
    });
  });

  httpServer.listen(port, host, () => {
    process.stderr.write(
      `sqlserver-mcp-server (http) http://${host}:${port}${path} başlatıldı ✓\n`
    );
  });

  return httpServer;
}

async function main() {
  const mode = (process.env.MCP_TRANSPORT || "stdio").toLowerCase();
  if (mode === "http" || mode === "sse") {
    await startHttp();
  } else {
    await startStdio();
  }
}

// Graceful shutdown
process.on("SIGINT", async () => {
  await closeAll();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  await closeAll();
  process.exit(0);
});

main().catch((err) => {
  process.stderr.write(`Başlatma hatası: ${err}\n`);
  process.exit(1);
});
