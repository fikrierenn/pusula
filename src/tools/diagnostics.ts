import { getPool } from "../services/database.js";

export async function getTableStats(
  tableName: string,
  database?: string
): Promise<string> {
  const pool = await getPool(database);

  let schema = "dbo";
  let table = tableName;
  if (tableName.includes(".")) {
    [schema, table] = tableName.split(".");
  }

  const safeSchema = schema.replace(/'/g, "''");
  const safeTable = table.replace(/'/g, "''");

  const result = await pool.request().query(`
    SELECT 
      s.name + '.' + t.name AS table_name,
      p.rows AS row_count,
      SUM(a.total_pages) * 8 AS total_kb,
      SUM(a.used_pages) * 8 AS used_kb,
      SUM(a.data_pages) * 8 AS data_kb,
      (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS unused_kb,
      MAX(ius.last_user_update) AS last_update,
      MAX(ius.last_user_seek) AS last_seek,
      MAX(ius.last_user_scan) AS last_scan,
      MAX(ius.last_user_lookup) AS last_lookup,
      SUM(ius.user_seeks) AS total_seeks,
      SUM(ius.user_scans) AS total_scans,
      SUM(ius.user_lookups) AS total_lookups,
      SUM(ius.user_updates) AS total_updates
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0, 1)
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
    LEFT JOIN sys.dm_db_index_usage_stats ius ON t.object_id = ius.object_id AND ius.database_id = DB_ID()
    WHERE s.name = '${safeSchema}' AND t.name = '${safeTable}'
    GROUP BY s.name, t.name, p.rows
  `);

  if (result.recordset.length === 0) {
    return `Tablo bulunamadı: ${schema}.${table}`;
  }

  const r = result.recordset[0];
  const lines = [
    `## ${r.table_name} İstatistikleri`,
    "",
    `| Metrik | Değer |`,
    `| --- | --- |`,
    `| Satır sayısı | ${Number(r.row_count).toLocaleString()} |`,
    `| Toplam boyut | ${Number(r.total_kb).toLocaleString()} KB |`,
    `| Kullanılan | ${Number(r.used_kb).toLocaleString()} KB |`,
    `| Veri | ${Number(r.data_kb).toLocaleString()} KB |`,
    `| Kullanılmayan | ${Number(r.unused_kb).toLocaleString()} KB |`,
    `| Son güncelleme | ${r.last_update || "Yok"} |`,
    `| Son seek | ${r.last_seek || "Yok"} |`,
    `| Son scan | ${r.last_scan || "Yok"} |`,
    `| Toplam seek | ${Number(r.total_seeks || 0).toLocaleString()} |`,
    `| Toplam scan | ${Number(r.total_scans || 0).toLocaleString()} |`,
    `| Toplam update | ${Number(r.total_updates || 0).toLocaleString()} |`,
  ];

  return lines.join("\n");
}

export async function analyzeIndexes(
  database?: string,
  tableName?: string
): Promise<string> {
  const pool = await getPool(database);

  let tableFilter = "";
  if (tableName) {
    let schema = "dbo";
    let table = tableName;
    if (tableName.includes(".")) {
      [schema, table] = tableName.split(".");
    }
    tableFilter = `AND s.name = '${schema.replace(/'/g, "''")}' AND t.name = '${table.replace(/'/g, "''")}'`;
  }

  // Missing indexes
  const missingResult = await pool.request().query(`
    SELECT TOP 20
      s.name + '.' + t.name AS table_name,
      mid.equality_columns,
      mid.inequality_columns,
      mid.included_columns,
      migs.avg_user_impact,
      migs.user_seeks,
      migs.user_scans,
      CAST(migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS DECIMAL(18,2)) AS improvement_score
    FROM sys.dm_db_missing_index_details mid
    INNER JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
    INNER JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
    INNER JOIN sys.tables t ON mid.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE mid.database_id = DB_ID() ${tableFilter}
    ORDER BY improvement_score DESC
  `);

  // Unused indexes
  const unusedResult = await pool.request().query(`
    SELECT TOP 20
      s.name + '.' + t.name AS table_name,
      i.name AS index_name,
      i.type_desc,
      ius.user_seeks,
      ius.user_scans,
      ius.user_lookups,
      ius.user_updates,
      (SELECT SUM(a.total_pages) * 8 FROM sys.allocation_units a 
       INNER JOIN sys.partitions p ON a.container_id = p.partition_id 
       WHERE p.object_id = i.object_id AND p.index_id = i.index_id) AS size_kb
    FROM sys.indexes i
    INNER JOIN sys.tables t ON i.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id AND i.index_id = ius.index_id AND ius.database_id = DB_ID()
    WHERE i.type > 0 AND i.is_primary_key = 0 AND i.is_unique_constraint = 0
      AND ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_scans, 0) + ISNULL(ius.user_lookups, 0) = 0
      ${tableFilter}
    ORDER BY ISNULL(ius.user_updates, 0) DESC
  `);

  const lines: string[] = ["## İndeks Analizi\n"];

  if (missingResult.recordset.length > 0) {
    lines.push("### Eksik İndeksler (Önerilen)");
    lines.push("| Tablo | Equality | Inequality | Include | Etki % | Score |");
    lines.push("| --- | --- | --- | --- | --- | --- |");
    for (const r of missingResult.recordset) {
      lines.push(
        `| ${r.table_name} | ${r.equality_columns || "-"} | ${r.inequality_columns || "-"} | ${r.included_columns || "-"} | ${r.avg_user_impact?.toFixed(1)}% | ${r.improvement_score?.toFixed(0)} |`
      );
    }
  } else {
    lines.push("### Eksik İndeks Önerisi Yok ✓");
  }

  if (unusedResult.recordset.length > 0) {
    lines.push("\n### Kullanılmayan İndeksler (Kaldırılabilir)");
    lines.push("| Tablo | İndeks | Tip | Updates | KB |");
    lines.push("| --- | --- | --- | --- | --- |");
    for (const r of unusedResult.recordset) {
      lines.push(
        `| ${r.table_name} | ${r.index_name} | ${r.type_desc} | ${Number(r.user_updates || 0).toLocaleString()} | ${Number(r.size_kb || 0).toLocaleString()} |`
      );
    }
  } else {
    lines.push("\n### Kullanılmayan İndeks Yok ✓");
  }

  return lines.join("\n");
}

export async function getRecentErrors(
  database?: string,
  minutes: number = 60
): Promise<string> {
  const pool = await getPool(database);

  const result = await pool.request().query(`
    SELECT TOP 50
      ERROR_NUMBER() AS err_number,
      ERROR_MESSAGE() AS err_message,
      ERROR_SEVERITY() AS severity,
      ERROR_STATE() AS state
    FROM (SELECT 1 AS x) dummy
    WHERE 1=0

    -- Gerçek error log:
    SELECT TOP 50 
      LogDate, ProcessInfo, Text 
    FROM (
      EXEC sp_readerrorlog 0, 1, NULL, NULL, 
        DATEADD(MINUTE, -${Math.min(minutes, 1440)}, GETDATE()), NULL
    ) AS errorlog
    ORDER BY LogDate DESC
  `);

  // Fallback: xp_readerrorlog daha güvenilir
  try {
    const errResult = await pool.request().query(`
      DECLARE @start DATETIME = DATEADD(MINUTE, -${Math.min(minutes, 1440)}, GETDATE())
      CREATE TABLE #err (LogDate DATETIME, ProcessInfo NVARCHAR(100), Text NVARCHAR(MAX))
      INSERT INTO #err EXEC xp_readerrorlog 0, 1, N'error', NULL, @start
      INSERT INTO #err EXEC xp_readerrorlog 0, 1, N'fail', NULL, @start
      SELECT DISTINCT TOP 50 * FROM #err ORDER BY LogDate DESC
      DROP TABLE #err
    `);

    if (errResult.recordset.length === 0) {
      return `Son ${minutes} dakikada hata kaydı yok ✓`;
    }

    const lines = [`## Son ${minutes} dakika hata logu\n`];
    lines.push("| Tarih | Process | Mesaj |");
    lines.push("| --- | --- | --- |");
    for (const r of errResult.recordset) {
      const msg = String(r.Text || "").substring(0, 120);
      lines.push(`| ${r.LogDate} | ${r.ProcessInfo} | ${msg} |`);
    }
    return lines.join("\n");
  } catch {
    return `Hata logu okunamadı — xp_readerrorlog izni gerekebilir. Son ${minutes} dk kontrol edildi.`;
  }
}
