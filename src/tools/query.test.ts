import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { wrapWithTopIfSafe } from "./query.js";

const ENV_KEYS = ["ALLOW_WRITE", "ALLOW_MULTI_STATEMENT"];
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

describe("wrapWithTopIfSafe", () => {
  it("Basit SELECT'i TOP ile sarar", () => {
    const r = wrapWithTopIfSafe("SELECT * FROM Foo", 100);
    expect(r.wrapped).toBe(true);
    expect(r.sql).toMatch(/SELECT TOP \(100\)/);
    expect(r.sql).toMatch(/__mcp_wrap/);
  });

  it("WITH (CTE) ile başlayan sorgu da sarılır", () => {
    const r = wrapWithTopIfSafe("WITH cte AS (SELECT 1 AS x) SELECT * FROM cte", 50);
    expect(r.wrapped).toBe(true);
  });

  it("Yazma keyword'ü varsa dokunmaz", () => {
    const r = wrapWithTopIfSafe("UPDATE Foo SET x=1", 100);
    expect(r.wrapped).toBe(false);
    expect(r.sql).toBe("UPDATE Foo SET x=1");
  });

  it("Birden fazla statement varsa dokunmaz", () => {
    const r = wrapWithTopIfSafe("SELECT 1; SELECT 2", 100);
    expect(r.wrapped).toBe(false);
  });

  it("Kullanıcı zaten TOP yazmışsa dokunmaz", () => {
    const r = wrapWithTopIfSafe("SELECT TOP 10 * FROM Foo", 100);
    expect(r.wrapped).toBe(false);
    const r2 = wrapWithTopIfSafe("SELECT TOP (10) * FROM Foo", 100);
    expect(r2.wrapped).toBe(false);
  });

  it("DECLARE/SET/WAITFOR ile başlayan dokunmaz", () => {
    expect(wrapWithTopIfSafe("DECLARE @x INT", 100).wrapped).toBe(false);
    expect(wrapWithTopIfSafe("SET LOCK_TIMEOUT 1000", 100).wrapped).toBe(false);
    expect(wrapWithTopIfSafe("WAITFOR DELAY '00:00:01'", 100).wrapped).toBe(false);
  });

  it("Trailing semicolon temizlenir", () => {
    const r = wrapWithTopIfSafe("SELECT * FROM Foo;", 100);
    expect(r.wrapped).toBe(true);
    expect(r.sql).not.toMatch(/;\s*\)/);
  });
});
