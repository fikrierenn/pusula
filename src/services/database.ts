import sql from "mssql";

interface DbConfig {
  host: string;
  instance?: string; // Named instance (e.g. SQLEXPRESS). When set, port is ignored — SQL Browser resolves dynamic port.
  port: number;
  user: string;
  password: string;
  database: string;
  trustServerCertificate: boolean;
  requestTimeout: number;
  trustedConnection: boolean;
}

const pools = new Map<string, sql.ConnectionPool>();

function getBaseConfig(): DbConfig {
  // Named instance support: MSSQL_HOST="HOST\\INSTANCE" → split into host + instance.
  // For named instances, omit explicit port and let SQL Browser resolve via UDP 1434.
  const rawHost = process.env.MSSQL_HOST || "localhost";
  let host = rawHost;
  let instance: string | undefined;
  if (rawHost.includes("\\")) {
    const parts = rawHost.split("\\");
    host = parts[0];
    instance = parts[1];
  }
  // Explicit MSSQL_INSTANCE env var overrides parsing
  if (process.env.MSSQL_INSTANCE) {
    instance = process.env.MSSQL_INSTANCE;
  }
  return {
    host,
    instance,
    port: parseInt(process.env.MSSQL_PORT || "1433"),
    user: process.env.MSSQL_USER || "sa",
    password: process.env.MSSQL_PASSWORD || "",
    database: process.env.MSSQL_DATABASE || "master",
    trustServerCertificate: true,
    requestTimeout: parseInt(process.env.QUERY_TIMEOUT_MS || "30000"),
    trustedConnection: process.env.MSSQL_TRUSTED === "true",
  };
}

function getAllowedDatabases(): string[] {
  const raw = process.env.ALLOWED_DATABASES || "";
  return raw
    .split(",")
    .map((d) => d.trim())
    .filter(Boolean);
}

function isAllowed(database: string): boolean {
  const allowed = getAllowedDatabases();
  if (allowed.length === 0) return true; // no restriction if env not set
  return allowed.some((d) => d.toLowerCase() === database.toLowerCase());
}

export async function getPool(database?: string): Promise<sql.ConnectionPool> {
  const cfg = getBaseConfig();
  const dbName = database || cfg.database;

  if (!isAllowed(dbName)) {
    throw new Error(
      `Veritabanı '${dbName}' izin listesinde yok. İzin verilenler: ${getAllowedDatabases().join(", ")}`
    );
  }

  const key = dbName.toLowerCase();

  if (pools.has(key)) {
    const existing = pools.get(key)!;
    if (existing.connected) return existing;
    pools.delete(key);
  }

  const poolConfig: sql.config = {
    server: cfg.host,
    database: dbName,
    options: {
      trustServerCertificate: cfg.trustServerCertificate,
      encrypt: false,
      // Named instance: tedious uses SQL Browser (UDP 1434) to resolve dynamic port
      ...(cfg.instance ? { instanceName: cfg.instance } : {}),
    },
    requestTimeout: cfg.requestTimeout,
    pool: {
      max: 5,
      min: 0,
      idleTimeoutMillis: 60000,
    },
  };
  // Only set explicit port when NOT using a named instance.
  // If both port and instanceName are set, mssql/tedious uses port and skips instance discovery.
  if (!cfg.instance) {
    poolConfig.port = cfg.port;
  }

  // Windows Authentication veya SQL Auth
  if (cfg.trustedConnection) {
    // @ts-ignore — mssql supports this on Windows
    poolConfig.authentication = {
      type: "ntlm",
      options: { domain: "", userName: cfg.user, password: cfg.password },
    };
  } else {
    poolConfig.user = cfg.user;
    poolConfig.password = cfg.password;
  }

  const pool = new sql.ConnectionPool(poolConfig);
  await pool.connect();
  pools.set(key, pool);
  return pool;
}

export function isWriteAllowed(): boolean {
  return process.env.ALLOW_WRITE === "true";
}

export function getMaxRows(): number {
  return parseInt(process.env.MAX_ROWS || "1000");
}

const WRITE_KEYWORDS = [
  "INSERT",
  "UPDATE",
  "DELETE",
  "DROP",
  "ALTER",
  "CREATE",
  "TRUNCATE",
  "EXEC",
  "EXECUTE",
  "MERGE",
  "GRANT",
  "REVOKE",
  "DENY",
  "BACKUP",
  "RESTORE",
];

export function isWriteQuery(queryText: string): boolean {
  const normalized = queryText
    .replace(/--.*$/gm, "")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .trim()
    .toUpperCase();

  return WRITE_KEYWORDS.some((kw) => {
    const regex = new RegExp(`(^|\\s)${kw}(\\s|$)`);
    return regex.test(normalized);
  });
}

export function getQueryTimeoutMs(): number {
  return parseInt(process.env.QUERY_TIMEOUT_MS || "30000");
}

/**
 * Execute a query with a hard timeout that actually cancels the running
 * SQL request on timeout (not just the node-side promise). Returns the
 * mssql IResult. If the timeout fires, the request is cancelled and
 * the promise rejects with a timeout error.
 */
export async function runQueryWithTimeout<T = unknown>(
  pool: sql.ConnectionPool,
  query: string,
  timeoutMs?: number
): Promise<sql.IResult<T>> {
  const ms = timeoutMs ?? getQueryTimeoutMs();
  const request = pool.request();
  // Request-level timeout (mssql>=9 typing, ignored by TS type but respected at runtime)
  (request as unknown as { requestTimeout?: number }).requestTimeout = ms;

  let timer: NodeJS.Timeout | undefined;
  let cancelled = false;

  const timeoutPromise = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      cancelled = true;
      try {
        request.cancel();
      } catch {
        // swallow, query() promise will reject below
      }
      reject(new Error(`Query cancelled — timeout ${ms}ms aşıldı`));
    }, ms);
  });

  try {
    const result = (await Promise.race([
      request.query<T>(query),
      timeoutPromise,
    ])) as sql.IResult<T>;
    return result;
  } catch (err) {
    if (cancelled) {
      throw new Error(`Query cancelled — timeout ${ms}ms aşıldı`);
    }
    throw err;
  } finally {
    if (timer) clearTimeout(timer);
  }
}

export async function closeAll(): Promise<void> {
  for (const [, pool] of pools) {
    try {
      await pool.close();
    } catch {
      // ignore close errors
    }
  }
  pools.clear();
}
