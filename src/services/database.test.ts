import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  isWriteQuery,
  isWriteAllowed,
  isMultiStatementAllowed,
  splitStatements,
  sanitizeError,
  getMaxRows,
} from "./database.js";

// Bu testler env vars'a dokunduğu için her test öncesi/sonrası temizlik.
const ENV_KEYS = [
  "ALLOW_WRITE",
  "ALLOW_MULTI_STATEMENT",
  "MAX_ROWS",
  "MSSQL_PASSWORD",
  "MSSQL_HOST",
];
const original: Record<string, string | undefined> = {};

beforeEach(() => {
  for (const k of ENV_KEYS) original[k] = process.env[k];
  for (const k of ENV_KEYS) delete process.env[k];
});

afterEach(() => {
  for (const k of ENV_KEYS) {
    if (original[k] === undefined) delete process.env[k];
    else process.env[k] = original[k];
  }
});

describe("isWriteQuery", () => {
  it("SELECT ifadesini write değil olarak tanır", () => {
    expect(isWriteQuery("SELECT * FROM Users")).toBe(false);
  });

  it("INSERT/UPDATE/DELETE'i write olarak tanır", () => {
    expect(isWriteQuery("INSERT INTO Foo VALUES (1)")).toBe(true);
    expect(isWriteQuery("UPDATE Foo SET x=1")).toBe(true);
    expect(isWriteQuery("DELETE FROM Foo")).toBe(true);
  });

  it("DROP/ALTER/CREATE/TRUNCATE'i write olarak tanır", () => {
    expect(isWriteQuery("DROP TABLE Foo")).toBe(true);
    expect(isWriteQuery("ALTER TABLE Foo ADD x INT")).toBe(true);
    expect(isWriteQuery("CREATE TABLE Foo(x INT)")).toBe(true);
    expect(isWriteQuery("TRUNCATE TABLE Foo")).toBe(true);
  });

  it("EXEC/EXECUTE'u write olarak tanır", () => {
    expect(isWriteQuery("EXEC sp_help")).toBe(true);
    expect(isWriteQuery("EXECUTE sp_help")).toBe(true);
  });

  it("Yorum içindeki write keyword'ünü görmezden gelir", () => {
    expect(isWriteQuery("SELECT 1 -- DROP TABLE Foo")).toBe(false);
    expect(isWriteQuery("SELECT 1 /* UPDATE Foo */")).toBe(false);
  });
});

describe("isWriteAllowed", () => {
  it("ALLOW_WRITE belirtilmemişse default false", () => {
    expect(isWriteAllowed()).toBe(false);
  });

  it("ALLOW_WRITE=true ise true", () => {
    process.env.ALLOW_WRITE = "true";
    expect(isWriteAllowed()).toBe(true);
  });

  it("ALLOW_WRITE=1 (true değil) ise false — string strict match", () => {
    process.env.ALLOW_WRITE = "1";
    expect(isWriteAllowed()).toBe(false);
  });
});

describe("isMultiStatementAllowed", () => {
  it("default false (multi-statement reddedilir)", () => {
    expect(isMultiStatementAllowed()).toBe(false);
  });

  it("ALLOW_MULTI_STATEMENT=true ise true", () => {
    process.env.ALLOW_MULTI_STATEMENT = "true";
    expect(isMultiStatementAllowed()).toBe(true);
  });
});

describe("splitStatements", () => {
  it("Tek statement listesi", () => {
    expect(splitStatements("SELECT 1")).toEqual(["SELECT 1"]);
  });

  it("Trailing semicolon discard", () => {
    expect(splitStatements("SELECT 1;")).toEqual(["SELECT 1"]);
  });

  it("İki statement böler", () => {
    const r = splitStatements("SELECT 1; SELECT 2");
    expect(r).toHaveLength(2);
  });

  it("String literal içindeki semicolon split etmez", () => {
    const r = splitStatements("SELECT 'a;b'");
    expect(r).toHaveLength(1);
  });

  it("Escape edilmiş tek tırnak (escape '') destekler", () => {
    const r = splitStatements("SELECT 'a''b;c'");
    expect(r).toHaveLength(1);
  });

  it("Yorum içindeki semicolon split etmez", () => {
    const r = splitStatements("SELECT 1 /* foo;bar */");
    expect(r).toHaveLength(1);
  });

  it("Multi-statement DOS (WAITFOR)", () => {
    const r = splitStatements("SELECT 1; WAITFOR DELAY '00:00:05'");
    expect(r).toHaveLength(2);
  });

  it("Multi-statement bypass (write keyword sonra)", () => {
    const r = splitStatements("SELECT 1; UPDATE Foo SET x=1");
    expect(r).toHaveLength(2);
  });

  it("Boş string sıfır statement döner", () => {
    expect(splitStatements("")).toEqual([]);
    expect(splitStatements("  ")).toEqual([]);
    expect(splitStatements(";;")).toEqual([]);
  });
});

describe("sanitizeError", () => {
  it("Password env vars'ı [REDACTED-PASSWORD] ile değiştirir", () => {
    process.env.MSSQL_PASSWORD = "secret123";
    const err = new Error("Login failed: secret123 not accepted");
    const sanitized = sanitizeError(err);
    expect(sanitized.message).not.toContain("secret123");
    expect(sanitized.message).toContain("[REDACTED-PASSWORD]");
  });

  it("Host env vars'ı [REDACTED-HOST] ile değiştirir", () => {
    process.env.MSSQL_HOST = "192.168.40.25\\ZRVSQL2008";
    const err = new Error("Cannot reach 192.168.40.25\\ZRVSQL2008");
    const sanitized = sanitizeError(err);
    expect(sanitized.message).not.toContain("192.168.40.25");
    expect(sanitized.message).toContain("[REDACTED-HOST]");
  });

  it("originalError chain'indeki sızıntıları da temizler", () => {
    process.env.MSSQL_PASSWORD = "topsecret";
    const inner = new Error("Bad password: topsecret") as Error & {
      originalError?: { message: string };
    };
    const outer = new Error("Login failed") as Error & {
      originalError?: { message: string };
    };
    outer.originalError = { message: "Auth fail with topsecret on host" };
    const sanitized = sanitizeError(outer);
    expect(sanitized.message).not.toContain("topsecret");
    expect(sanitized.message).toContain("[REDACTED-PASSWORD]");
  });

  it("Password boş string ise dokunmaz", () => {
    delete process.env.MSSQL_PASSWORD;
    const err = new Error("Some error");
    const sanitized = sanitizeError(err);
    expect(sanitized.message).toBe("Some error");
  });

  it("Error olmayan değeri Error'a sarar", () => {
    const sanitized = sanitizeError("string error");
    expect(sanitized).toBeInstanceOf(Error);
    expect(sanitized.message).toBe("string error");
  });
});

describe("getMaxRows", () => {
  it("default 1000", () => {
    expect(getMaxRows()).toBe(1000);
  });

  it("MAX_ROWS env vars'ından okur", () => {
    process.env.MAX_ROWS = "500";
    expect(getMaxRows()).toBe(500);
  });
});
