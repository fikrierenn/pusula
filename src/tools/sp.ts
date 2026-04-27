import { getPool, isWriteAllowed } from "../services/database.js";

interface SpResult {
  result_sets: Record<string, unknown>[][];
  return_value: number;
  output_params: Record<string, unknown>;
  execution_time_ms: number;
}

export async function executeSp(
  procedureName: string,
  database?: string,
  parameters?: Record<string, string | number | boolean | null>
): Promise<SpResult> {
  if (!isWriteAllowed()) {
    throw new Error(
      "SP çalıştırma yazma izni gerektirir. ALLOW_WRITE=true ayarını aktif et. " +
        "Alternatif: SP'yi SELECT olarak sarmalayıp sql_query ile çalıştır."
    );
  }

  const pool = await getPool(database);
  const start = Date.now();

  const request = pool.request();

  // Add parameters
  if (parameters) {
    for (const [key, value] of Object.entries(parameters)) {
      request.input(key, value);
    }
  }

  const result = await request.execute(procedureName);
  const elapsed = Date.now() - start;

  return {
    result_sets: result.recordsets as Record<string, unknown>[][],
    return_value: result.returnValue,
    output_params: result.output,
    execution_time_ms: elapsed,
  };
}

export function formatSpResult(result: SpResult): string {
  const lines: string[] = [];
  lines.push(
    `✓ SP tamamlandı (${result.execution_time_ms}ms) — return value: ${result.return_value}`
  );

  for (let i = 0; i < result.result_sets.length; i++) {
    const rs = result.result_sets[i];
    lines.push(`\n### Sonuç Seti ${i + 1} (${rs.length} satır)`);

    if (rs.length === 0) {
      lines.push("Boş sonuç seti");
      continue;
    }

    const cols = Object.keys(rs[0]);
    lines.push("| " + cols.join(" | ") + " |");
    lines.push("| " + cols.map(() => "---").join(" | ") + " |");

    for (const row of rs.slice(0, 50)) {
      const vals = cols.map((c) => {
        const v = row[c];
        if (v === null || v === undefined) return "NULL";
        if (v instanceof Date) return v.toISOString();
        return String(v);
      });
      lines.push("| " + vals.join(" | ") + " |");
    }

    if (rs.length > 50) {
      lines.push(`... ve ${rs.length - 50} satır daha`);
    }
  }

  if (Object.keys(result.output_params).length > 0) {
    lines.push("\n### Çıktı Parametreleri");
    for (const [k, v] of Object.entries(result.output_params)) {
      lines.push(`- ${k}: ${v}`);
    }
  }

  return lines.join("\n");
}
