import {
  getPool,
  isWriteAllowed,
  isWriteQuery,
  getMaxRows,
  runQueryWithTimeout,
  getQueryTimeoutMs,
  splitStatements,
  isMultiStatementAllowed,
  sanitizeError,
} from "../services/database.js";

interface QueryResult {
  row_count: number;
  columns: string[];
  rows: Record<string, unknown>[];
  truncated: boolean;
  execution_time_ms: number;
  wrapped_with_top: boolean;
}

const MAX_VALUE_LEN = 200;

/**
 * Sarıcı TOP N — kullanıcının SELECT'ini `SELECT TOP (N) * FROM (<q>) __wrap`
 * şeklinde sarar. Böylece milyon satırlık sonuç set'i SQL Server tarafında
 * kesilir, Node heap'ine yığılmaz. Edge case'lerde dokunmaz.
 */
export function wrapWithTopIfSafe(
  query: string,
  limit: number
): { sql: string; wrapped: boolean } {
  const stripped = query
    .replace(/--.*$/gm, "")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .trim();

  // İçinde tehlikeli/yazma statement'ları varsa dokunma
  const upper = stripped.toUpperCase();
  const writeKw = /\b(INSERT|UPDATE|DELETE|MERGE|EXEC|EXECUTE|CREATE|ALTER|DROP|TRUNCATE|GRANT|REVOKE|DENY|BACKUP|RESTORE)\b/;
  if (writeKw.test(upper)) return { sql: query, wrapped: false };

  // Birden fazla statement (noktalı virgülle ayrılmış, boş olmayan) varsa sarmala
  const stmts = stripped.split(/;\s*/).filter((s) => s.length > 0);
  if (stmts.length > 1) return { sql: query, wrapped: false };

  // Kullanıcı zaten TOP yazmışsa dokunma
  if (/\bTOP\s*\(/.test(upper) || /\bTOP\s+\d/.test(upper)) {
    return { sql: query, wrapped: false };
  }

  // SELECT veya WITH (CTE) ile başlamıyorsa dokunma — WAITFOR, SET, DECLARE vb.
  if (!/^(SELECT|WITH)\b/.test(upper)) {
    return { sql: query, wrapped: false };
  }

  // Trailing ; varsa temizle
  const clean = stripped.replace(/;+\s*$/, "");
  const wrapped = `SELECT TOP (${limit}) * FROM (\n${clean}\n) AS __mcp_wrap`;
  return { sql: wrapped, wrapped: true };
}

export async function executeQuery(
  query: string,
  database?: string,
  maxRows?: number
): Promise<QueryResult> {
  // Güvenlik 1: Multi-statement reject (`SELECT 1; WAITFOR ...` veya
  // `SELECT 1; UPDATE Foo` bypass'larını kapatır). Default: tek statement.
  const stmts = splitStatements(query);
  if (stmts.length > 1 && !isMultiStatementAllowed()) {
    throw new Error(
      `Birden fazla statement reddedildi (${stmts.length} bulundu). ` +
        "Tek bir statement gönderin. ALLOW_MULTI_STATEMENT=true ile " +
        "açılabilir (önerilmez — DOS/state pollution riski)."
    );
  }

  // Güvenlik 2: Yazma keyword'leri (INSERT/UPDATE/DELETE/...) reddet
  if (isWriteQuery(query) && !isWriteAllowed()) {
    throw new Error(
      "Yazma sorguları devre dışı. ALLOW_WRITE=true ayarı gerekiyor. " +
        "Güvenlik için varsayılan sadece SELECT."
    );
  }

  const limit = maxRows || getMaxRows();
  let pool;
  try {
    pool = await getPool(database);
  } catch (err) {
    throw sanitizeError(err);
  }
  const start = Date.now();

  const { sql: finalSql, wrapped } = wrapWithTopIfSafe(query, limit);

  let result;
  try {
    result = await runQueryWithTimeout(pool, finalSql, getQueryTimeoutMs());
  } catch (err) {
    throw sanitizeError(err);
  }

  const elapsed = Date.now() - start;
  const recordset = (result.recordset || []) as Record<string, unknown>[];
  const truncated = wrapped
    ? recordset.length >= limit
    : recordset.length > limit;
  const rows = wrapped ? recordset : recordset.slice(0, limit);
  const columns = rows.length > 0 ? Object.keys(rows[0]) : [];

  return {
    row_count: rows.length,
    columns,
    rows,
    truncated,
    execution_time_ms: elapsed,
    wrapped_with_top: wrapped,
  };
}

function truncateValue(v: unknown): string {
  if (v === null || v === undefined) return "NULL";
  if (v instanceof Date) return v.toISOString();
  let s = typeof v === "string" ? v : String(v);
  // Markdown tablo bozulmasın
  s = s.replace(/\r?\n/g, " ").replace(/\|/g, "\\|");
  if (s.length > MAX_VALUE_LEN) s = s.slice(0, MAX_VALUE_LEN) + "…";
  return s;
}

export function formatQueryResult(result: QueryResult): string {
  const lines: string[] = [];
  lines.push(`✓ ${result.row_count} satır (${result.execution_time_ms}ms)`);

  if (result.truncated) {
    lines.push(
      result.wrapped_with_top
        ? `⚠ Sonuç SQL tarafında TOP ${result.row_count}'e kesildi — daha fazlası için max_rows arttır veya sorguya daralt.`
        : `⚠ Sonuç kesildi — MAX_ROWS limitine ulaşıldı`
    );
  }

  if (result.rows.length === 0) {
    lines.push("Sonuç yok.");
    return lines.join("\n");
  }

  const cols = result.columns;
  lines.push("");
  lines.push("| " + cols.join(" | ") + " |");
  lines.push("| " + cols.map(() => "---").join(" | ") + " |");

  for (const row of result.rows.slice(0, 50)) {
    const vals = cols.map((c) => truncateValue(row[c]));
    lines.push("| " + vals.join(" | ") + " |");
  }

  if (result.rows.length > 50) {
    lines.push(
      `\n... ve ${result.rows.length - 50} satır daha (JSON formatında döndürüldü)`
    );
  }

  return lines.join("\n");
}
