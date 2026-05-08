import { afterEach, beforeEach, describe, it } from "node:test";
import assert from "node:assert/strict";
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
    assert.equal(isWriteQuery("SELECT * FROM Users"), false);
  });

  it("INSERT/UPDATE/DELETE'i write olarak tanır", () => {
    assert.equal(isWriteQuery("INSERT INTO Foo VALUES (1)"), true);
    assert.equal(isWriteQuery("UPDATE Foo SET x=1"), true);
    assert.equal(isWriteQuery("DELETE FROM Foo"), true);
  });

  it("DROP/ALTER/CREATE/TRUNCATE'i write olarak tanır", () => {
    assert.equal(isWriteQuery("DROP TABLE Foo"), true);
    assert.equal(isWriteQuery("ALTER TABLE Foo ADD x INT"), true);
    assert.equal(isWriteQuery("CREATE TABLE Foo(x INT)"), true);
    assert.equal(isWriteQuery("TRUNCATE TABLE Foo"), true);
  });

  it("EXEC/EXECUTE'u write olarak tanır", () => {
    assert.equal(isWriteQuery("EXEC sp_help"), true);
    assert.equal(isWriteQuery("EXECUTE sp_help"), true);
  });

  it("Yorum içindeki write keyword'ünü görmezden gelir", () => {
    assert.equal(isWriteQuery("SELECT 1 -- DROP TABLE Foo"), false);
    assert.equal(isWriteQuery("SELECT 1 /* UPDATE Foo */"), false);
  });
});

describe("isWriteAllowed", () => {
  it("ALLOW_WRITE belirtilmemişse default false", () => {
    assert.equal(isWriteAllowed(), false);
  });

  it("ALLOW_WRITE=true ise true", () => {
    process.env.ALLOW_WRITE = "true";
    assert.equal(isWriteAllowed(), true);
  });

  it("ALLOW_WRITE=1 (true değil) ise false — string strict match", () => {
    process.env.ALLOW_WRITE = "1";
    assert.equal(isWriteAllowed(), false);
  });
});

describe("isMultiStatementAllowed", () => {
  it("default false (multi-statement reddedilir)", () => {
    assert.equal(isMultiStatementAllowed(), false);
  });

  it("ALLOW_MULTI_STATEMENT=true ise true", () => {
    process.env.ALLOW_MULTI_STATEMENT = "true";
    assert.equal(isMultiStatementAllowed(), true);
  });
});

describe("splitStatements", () => {
  it("Tek statement listesi", () => {
    assert.deepEqual(splitStatements("SELECT 1"), ["SELECT 1"]);
  });

  it("Trailing semicolon discard", () => {
    assert.deepEqual(splitStatements("SELECT 1;"), ["SELECT 1"]);
  });

  it("İki statement böler", () => {
    const r = splitStatements("SELECT 1; SELECT 2");
    assert.equal(r.length, 2);
  });

  it("String literal içindeki semicolon split etmez", () => {
    const r = splitStatements("SELECT 'a;b'");
    assert.equal(r.length, 1);
  });

  it("Escape edilmiş tek tırnak (escape '') destekler", () => {
    const r = splitStatements("SELECT 'a''b;c'");
    assert.equal(r.length, 1);
  });

  it("Yorum içindeki semicolon split etmez", () => {
    const r = splitStatements("SELECT 1 /* foo;bar */");
    assert.equal(r.length, 1);
  });

  it("Multi-statement DOS (WAITFOR)", () => {
    const r = splitStatements("SELECT 1; WAITFOR DELAY '00:00:05'");
    assert.equal(r.length, 2);
  });

  it("Multi-statement bypass (write keyword sonra)", () => {
    const r = splitStatements("SELECT 1; UPDATE Foo SET x=1");
    assert.equal(r.length, 2);
  });

  it("Boş string sıfır statement döner", () => {
    assert.deepEqual(splitStatements(""), []);
    assert.deepEqual(splitStatements("  "), []);
    assert.deepEqual(splitStatements(";;"), []);
  });
});

describe("sanitizeError", () => {
  it("Password env vars'ı [REDACTED-PASSWORD] ile değiştirir", () => {
    process.env.MSSQL_PASSWORD = "secret123";
    const err = new Error("Login failed: secret123 not accepted");
    const sanitized = sanitizeError(err);
    assert.ok(!sanitized.message.includes("secret123"));
    assert.ok(sanitized.message.includes("[REDACTED-PASSWORD]"));
  });

  it("Host env vars'ı [REDACTED-HOST] ile değiştirir", () => {
    process.env.MSSQL_HOST = "192.168.40.25\\ZRVSQL2008";
    const err = new Error("Cannot reach 192.168.40.25\\ZRVSQL2008");
    const sanitized = sanitizeError(err);
    assert.ok(!sanitized.message.includes("192.168.40.25"));
    assert.ok(sanitized.message.includes("[REDACTED-HOST]"));
  });

  it("originalError chain'indeki sızıntıları da temizler", () => {
    process.env.MSSQL_PASSWORD = "topsecret";
    const outer = new Error("Login failed") as Error & {
      originalError?: { message: string };
    };
    outer.originalError = { message: "Auth fail with topsecret on host" };
    const sanitized = sanitizeError(outer);
    assert.ok(!sanitized.message.includes("topsecret"));
    assert.ok(sanitized.message.includes("[REDACTED-PASSWORD]"));
  });

  it("Password boş string ise dokunmaz", () => {
    delete process.env.MSSQL_PASSWORD;
    const err = new Error("Some error");
    const sanitized = sanitizeError(err);
    assert.equal(sanitized.message, "Some error");
  });

  it("Error olmayan değeri Error'a sarar", () => {
    const sanitized = sanitizeError("string error");
    assert.ok(sanitized instanceof Error);
    assert.equal(sanitized.message, "string error");
  });
});

describe("getMaxRows", () => {
  it("default 1000", () => {
    assert.equal(getMaxRows(), 1000);
  });

  it("MAX_ROWS env vars'ından okur", () => {
    process.env.MAX_ROWS = "500";
    assert.equal(getMaxRows(), 500);
  });
});
