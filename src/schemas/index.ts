import { z } from "zod";

export const QuerySchema = z.object({
  query: z.string().describe("SQL sorgusu (SELECT, WITH, vb.)"),
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı. Belirtilmezse varsayılan kullanılır"),
  max_rows: z
    .number()
    .int()
    .min(1)
    .max(10000)
    .optional()
    .describe("Döndürülecek maksimum satır sayısı (varsayılan: 1000)"),
});

export const BrowseSchemaInput = z.object({
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
  schema_filter: z
    .string()
    .optional()
    .describe("Schema filtresi (örn: 'bkm', 'dbo', 'audit')"),
});

export const DescribeTableInput = z.object({
  table_name: z
    .string()
    .describe("Tablo adı (schema dahil, örn: 'bkm.SatisDetay')"),
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
});

export const ExecSpInput = z.object({
  procedure_name: z
    .string()
    .describe("Stored procedure adı (schema dahil, örn: 'bkm.sp_AySonuKontrol')"),
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
  parameters: z
    .record(z.union([z.string(), z.number(), z.boolean(), z.null()]))
    .optional()
    .describe("SP parametreleri — key:value objesi"),
});

export const ListDatabasesInput = z.object({});

export const TableStatsInput = z.object({
  table_name: z
    .string()
    .describe("Tablo adı (schema dahil)"),
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
});

export const IndexAnalysisInput = z.object({
  table_name: z
    .string()
    .optional()
    .describe("Belirli bir tablo için index analizi. Boş bırakılırsa tüm tablolar"),
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
});

export const RecentErrorsInput = z.object({
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
  minutes: z
    .number()
    .int()
    .min(1)
    .max(1440)
    .optional()
    .describe("Son kaç dakikadaki hatalar (varsayılan: 60)"),
});

// ─── Discovery Araçları ──────────────────────────────────

export const SearchColumnsInput = z.object({
  search_term: z
    .string()
    .describe("Aranacak terim — kolon adı veya tablo adında arar (örn: 'fiyat', 'barkod', 'sip')"),
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
});

export const TableRelationshipsInput = z.object({
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
  table_name: z
    .string()
    .optional()
    .describe("Belirli bir tablonun ilişkileri. Boş bırakılırsa tüm FK'lar döner"),
});

export const TableSampleInput = z.object({
  table_name: z
    .string()
    .describe("Tablo adı (schema dahil, örn: 'ent.tsoft_urun')"),
  database: z
    .string()
    .optional()
    .describe("Hedef veritabanı adı"),
  rows: z
    .number()
    .int()
    .min(1)
    .max(20)
    .optional()
    .describe("Örnek satır sayısı (varsayılan: 5, max: 20)"),
});
