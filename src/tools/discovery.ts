/**
 * Semantik keşif araçları — BKM Kitap veri modeli taraması için
 * Kolon/tablo arama, FK ilişki haritası ve örnek veri çekme
 */

import { getPool } from "../services/database.js";

// ─── search_columns ──────────────────────────────────────

interface ColumnMatch {
  schema_name: string;
  table_name: string;
  column_name: string;
  data_type: string;
  is_nullable: boolean;
}

export async function searchColumns(
  searchTerm: string,
  database?: string
): Promise<ColumnMatch[]> {
  const pool = await getPool(database);
  const safeTerm = searchTerm.replace(/'/g, "''");

  const result = await pool.request().query(`
    SELECT
      s.name AS schema_name,
      t.name AS table_name,
      c.name AS column_name,
      tp.name + CASE
        WHEN tp.name IN ('varchar','nvarchar','char','nchar')
          THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR) END + ')'
        WHEN tp.name IN ('decimal','numeric')
          THEN '(' + CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR) + ')'
        ELSE ''
      END AS data_type,
      c.is_nullable
    FROM sys.columns c
    INNER JOIN sys.types tp ON c.user_type_id = tp.user_type_id
    INNER JOIN sys.tables t ON c.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE c.name LIKE '%${safeTerm}%' OR t.name LIKE '%${safeTerm}%'
    ORDER BY s.name, t.name, c.column_id
  `);

  return result.recordset;
}

export function formatColumnSearch(
  term: string,
  matches: ColumnMatch[]
): string {
  if (matches.length === 0) {
    return `'${term}' ile eşleşen kolon veya tablo bulunamadı.`;
  }

  const lines = [`## '${term}' arama sonuçları (${matches.length} eşleşme)\n`];
  lines.push("| Schema | Tablo | Kolon | Tip | Nullable |");
  lines.push("| --- | --- | --- | --- | --- |");

  for (const m of matches.slice(0, 200)) {
    lines.push(
      `| ${m.schema_name} | ${m.table_name} | ${m.column_name} | ${m.data_type} | ${m.is_nullable ? "✓" : "✗"} |`
    );
  }

  if (matches.length > 200) {
    lines.push(`\n... ve ${matches.length - 200} eşleşme daha`);
  }

  return lines.join("\n");
}

// ─── get_table_relationships ─────────────────────────────

interface Relationship {
  fk_name: string;
  from_schema: string;
  from_table: string;
  from_column: string;
  to_schema: string;
  to_table: string;
  to_column: string;
}

export async function getTableRelationships(
  database?: string,
  tableName?: string
): Promise<Relationship[]> {
  const pool = await getPool(database);

  let tableFilter = "";
  if (tableName) {
    let schema = "dbo";
    let table = tableName;
    if (tableName.includes(".")) {
      [schema, table] = tableName.split(".");
    }
    const safeSchema = schema.replace(/'/g, "''");
    const safeTable = table.replace(/'/g, "''");
    tableFilter = `
      AND (
        (OBJECT_SCHEMA_NAME(fk.parent_object_id) = '${safeSchema}' AND OBJECT_NAME(fk.parent_object_id) = '${safeTable}')
        OR
        (OBJECT_SCHEMA_NAME(fk.referenced_object_id) = '${safeSchema}' AND OBJECT_NAME(fk.referenced_object_id) = '${safeTable}')
      )
    `;
  }

  const result = await pool.request().query(`
    SELECT
      fk.name AS fk_name,
      OBJECT_SCHEMA_NAME(fk.parent_object_id) AS from_schema,
      OBJECT_NAME(fk.parent_object_id) AS from_table,
      COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS from_column,
      OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS to_schema,
      OBJECT_NAME(fk.referenced_object_id) AS to_table,
      COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS to_column
    FROM sys.foreign_keys fk
    INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
    WHERE 1=1 ${tableFilter}
    ORDER BY from_schema, from_table, fk_name
  `);

  return result.recordset;
}

export function formatRelationships(
  rels: Relationship[],
  tableName?: string
): string {
  if (rels.length === 0) {
    return tableName
      ? `${tableName} tablosunda foreign key ilişkisi bulunamadı.`
      : "Veritabanında foreign key ilişkisi bulunamadı.";
  }

  const title = tableName
    ? `## ${tableName} İlişki Haritası`
    : "## Veritabanı İlişki Haritası";

  const lines = [`${title} (${rels.length} FK)\n`];
  lines.push("| FK Adı | Kaynak (Schema.Tablo.Kolon) | → | Hedef (Schema.Tablo.Kolon) |");
  lines.push("| --- | --- | --- | --- |");

  for (const r of rels) {
    lines.push(
      `| ${r.fk_name} | ${r.from_schema}.${r.from_table}.${r.from_column} | → | ${r.to_schema}.${r.to_table}.${r.to_column} |`
    );
  }

  return lines.join("\n");
}

// ─── get_table_sample ────────────────────────────────────

export async function getTableSample(
  tableName: string,
  database?: string,
  rows: number = 5
): Promise<Record<string, unknown>[]> {
  let schema = "dbo";
  let table = tableName;
  if (tableName.includes(".")) {
    [schema, table] = tableName.split(".");
  }

  const safeSchema = schema.replace(/]/g, "]]");
  const safeTable = table.replace(/]/g, "]]");
  const limit = Math.min(rows, 20);

  const pool = await getPool(database);
  const result = await pool
    .request()
    .query(`SELECT TOP ${limit} * FROM [${safeSchema}].[${safeTable}]`);

  return result.recordset;
}

export function formatTableSample(
  tableName: string,
  rows: Record<string, unknown>[]
): string {
  if (rows.length === 0) {
    return `${tableName} tablosu boş veya bulunamadı.`;
  }

  const cols = Object.keys(rows[0]);
  const lines = [`## ${tableName} — ${rows.length} örnek satır\n`];
  lines.push("| " + cols.join(" | ") + " |");
  lines.push("| " + cols.map(() => "---").join(" | ") + " |");

  for (const row of rows) {
    const vals = cols.map((c) => {
      const v = row[c];
      if (v === null || v === undefined) return "NULL";
      if (v instanceof Date) return v.toISOString().substring(0, 19);
      const s = String(v);
      return s.length > 60 ? s.substring(0, 57) + "..." : s;
    });
    lines.push("| " + vals.join(" | ") + " |");
  }

  return lines.join("\n");
}
