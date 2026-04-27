import { getPool } from "../services/database.js";

interface DatabaseInfo {
  name: string;
  state: string;
  size_mb: number;
  compatibility_level: number;
}

interface SchemaTable {
  schema_name: string;
  table_name: string;
  table_type: string;
  row_count: number;
  size_kb: number;
}

interface ColumnInfo {
  column_name: string;
  data_type: string;
  max_length: number | null;
  is_nullable: boolean;
  is_identity: boolean;
  is_primary_key: boolean;
  default_value: string | null;
  description: string | null;
}

interface TableDescription {
  full_name: string;
  columns: ColumnInfo[];
  indexes: IndexInfo[];
  foreign_keys: FkInfo[];
  row_count: number;
}

interface IndexInfo {
  index_name: string;
  type: string;
  columns: string;
  is_unique: boolean;
}

interface FkInfo {
  fk_name: string;
  column: string;
  references: string;
}

export async function listDatabases(): Promise<DatabaseInfo[]> {
  const pool = await getPool("master");
  const result = await pool.request().query(`
    SELECT 
      d.name,
      d.state_desc AS state,
      CAST(SUM(mf.size) * 8.0 / 1024 AS DECIMAL(10,2)) AS size_mb,
      d.compatibility_level
    FROM sys.databases d
    LEFT JOIN sys.master_files mf ON d.database_id = mf.database_id
    WHERE d.database_id > 4
    GROUP BY d.name, d.state_desc, d.compatibility_level
    ORDER BY d.name
  `);
  return result.recordset;
}

export async function browseSchema(
  database?: string,
  schemaFilter?: string
): Promise<SchemaTable[]> {
  const pool = await getPool(database);

  let whereClause = "";
  if (schemaFilter) {
    whereClause = `AND s.name = '${schemaFilter.replace(/'/g, "''")}'`;
  }

  const result = await pool.request().query(`
    SELECT 
      s.name AS schema_name,
      t.name AS table_name,
      CASE WHEN t.type = 'U' THEN 'TABLE' ELSE 'VIEW' END AS table_type,
      ISNULL(p.rows, 0) AS row_count,
      ISNULL(SUM(a.total_pages) * 8, 0) AS size_kb
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
    LEFT JOIN sys.allocation_units a ON p.partition_id = a.container_id
    WHERE 1=1 ${whereClause}
    GROUP BY s.name, t.name, t.type, p.rows

    UNION ALL

    SELECT 
      s.name AS schema_name,
      v.name AS table_name,
      'VIEW' AS table_type,
      0 AS row_count,
      0 AS size_kb
    FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE 1=1 ${whereClause}

    ORDER BY schema_name, table_name
  `);

  return result.recordset;
}

export async function describeTable(
  tableName: string,
  database?: string
): Promise<TableDescription> {
  const pool = await getPool(database);

  // Parse schema.table
  let schema = "dbo";
  let table = tableName;
  if (tableName.includes(".")) {
    const parts = tableName.split(".");
    schema = parts[0];
    table = parts[1];
  }

  const safeSchema = schema.replace(/'/g, "''");
  const safeTable = table.replace(/'/g, "''");

  // Columns
  const colResult = await pool.request().query(`
    SELECT 
      c.name AS column_name,
      tp.name + CASE 
        WHEN tp.name IN ('varchar','nvarchar','char','nchar') THEN '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR) END + ')'
        WHEN tp.name IN ('decimal','numeric') THEN '(' + CAST(c.precision AS VARCHAR) + ',' + CAST(c.scale AS VARCHAR) + ')'
        ELSE '' 
      END AS data_type,
      c.max_length,
      c.is_nullable,
      c.is_identity,
      CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS is_primary_key,
      dc.definition AS default_value,
      ep.value AS description
    FROM sys.columns c
    INNER JOIN sys.types tp ON c.user_type_id = tp.user_type_id
    INNER JOIN sys.tables t ON c.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN (
      SELECT ic.object_id, ic.column_id
      FROM sys.index_columns ic
      INNER JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
      WHERE i.is_primary_key = 1
    ) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
    LEFT JOIN sys.default_constraints dc ON c.default_object_id = dc.object_id
    LEFT JOIN sys.extended_properties ep ON ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = 'MS_Description'
    WHERE s.name = '${safeSchema}' AND t.name = '${safeTable}'
    ORDER BY c.column_id
  `);

  // Indexes (STUFF+FOR XML PATH for SQL 2012 compat)
  const idxResult = await pool.request().query(`
    SELECT
      i.name AS index_name,
      i.type_desc AS type,
      STUFF((
        SELECT ', ' + c2.name
        FROM sys.index_columns ic2
        INNER JOIN sys.columns c2 ON ic2.object_id = c2.object_id AND ic2.column_id = c2.column_id
        WHERE ic2.object_id = i.object_id AND ic2.index_id = i.index_id
        ORDER BY ic2.key_ordinal
        FOR XML PATH(''), TYPE
      ).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS columns,
      i.is_unique,
      i.is_primary_key
    FROM sys.indexes i
    INNER JOIN sys.tables t ON i.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = '${safeSchema}' AND t.name = '${safeTable}' AND i.name IS NOT NULL
    GROUP BY i.object_id, i.index_id, i.name, i.type_desc, i.is_unique, i.is_primary_key
    ORDER BY i.is_primary_key DESC, i.name
  `);

  // Foreign keys
  const fkResult = await pool.request().query(`
    SELECT 
      fk.name AS fk_name,
      COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS [column],
      OBJECT_SCHEMA_NAME(fkc.referenced_object_id) + '.' + OBJECT_NAME(fkc.referenced_object_id) + '.' + COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS [references]
    FROM sys.foreign_keys fk
    INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
    INNER JOIN sys.tables t ON fk.parent_object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = '${safeSchema}' AND t.name = '${safeTable}'
  `);

  // Row count
  const countResult = await pool.request().query(`
    SELECT SUM(p.rows) AS row_count
    FROM sys.partitions p
    INNER JOIN sys.tables t ON p.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE s.name = '${safeSchema}' AND t.name = '${safeTable}' AND p.index_id IN (0, 1)
  `);

  return {
    full_name: `${schema}.${table}`,
    columns: colResult.recordset,
    indexes: idxResult.recordset,
    foreign_keys: fkResult.recordset,
    row_count: countResult.recordset[0]?.row_count || 0,
  };
}

export function formatDatabaseList(dbs: DatabaseInfo[]): string {
  const lines = ["| Veritabanı | Durum | Boyut (MB) | Uyumluluk |"];
  lines.push("| --- | --- | --- | --- |");
  for (const db of dbs) {
    lines.push(
      `| ${db.name} | ${db.state} | ${db.size_mb} | ${db.compatibility_level} |`
    );
  }
  return lines.join("\n");
}

export function formatSchemaList(tables: SchemaTable[]): string {
  const bySchema = new Map<string, SchemaTable[]>();
  for (const t of tables) {
    if (!bySchema.has(t.schema_name)) bySchema.set(t.schema_name, []);
    bySchema.get(t.schema_name)!.push(t);
  }

  const lines: string[] = [];
  for (const [schema, items] of bySchema) {
    lines.push(`\n### ${schema} (${items.length} obje)`);
    lines.push("| Tablo/View | Tip | Satır | KB |");
    lines.push("| --- | --- | --- | --- |");
    for (const t of items) {
      lines.push(
        `| ${t.table_name} | ${t.table_type} | ${t.row_count.toLocaleString()} | ${t.size_kb.toLocaleString()} |`
      );
    }
  }
  return lines.join("\n");
}

export function formatTableDescription(desc: TableDescription): string {
  const lines: string[] = [];
  lines.push(`## ${desc.full_name} (${desc.row_count.toLocaleString()} satır)`);

  lines.push("\n### Kolonlar");
  lines.push("| Kolon | Tip | Nullable | PK | Identity | Default | Açıklama |");
  lines.push("| --- | --- | --- | --- | --- | --- | --- |");
  for (const c of desc.columns) {
    lines.push(
      `| ${c.column_name} | ${c.data_type} | ${c.is_nullable ? "✓" : "✗"} | ${c.is_primary_key ? "✓" : ""} | ${c.is_identity ? "✓" : ""} | ${c.default_value || ""} | ${c.description || ""} |`
    );
  }

  if (desc.indexes.length > 0) {
    lines.push("\n### İndeksler");
    lines.push("| İndeks | Tip | Kolonlar | Unique |");
    lines.push("| --- | --- | --- | --- |");
    for (const i of desc.indexes) {
      lines.push(
        `| ${i.index_name} | ${i.type} | ${i.columns} | ${i.is_unique ? "✓" : "✗"} |`
      );
    }
  }

  if (desc.foreign_keys.length > 0) {
    lines.push("\n### Foreign Key'ler");
    lines.push("| FK | Kolon | Referans |");
    lines.push("| --- | --- | --- |");
    for (const fk of desc.foreign_keys) {
      lines.push(`| ${fk.fk_name} | ${fk.column} | ${fk.references} |`);
    }
  }

  return lines.join("\n");
}
