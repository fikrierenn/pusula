import { afterEach, beforeEach, describe, it } from "node:test";
import assert from "node:assert/strict";
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
    assert.equal(r.wrapped, true);
    assert.match(r.sql, /SELECT TOP \(100\)/);
    assert.match(r.sql, /__mcp_wrap/);
  });

  it("WITH (CTE) ile başlayan sorgu da sarılır", () => {
    const r = wrapWithTopIfSafe("WITH cte AS (SELECT 1 AS x) SELECT * FROM cte", 50);
    assert.equal(r.wrapped, true);
  });

  it("Yazma keyword'ü varsa dokunmaz", () => {
    const r = wrapWithTopIfSafe("UPDATE Foo SET x=1", 100);
    assert.equal(r.wrapped, false);
    assert.equal(r.sql, "UPDATE Foo SET x=1");
  });

  it("Birden fazla statement varsa dokunmaz", () => {
    const r = wrapWithTopIfSafe("SELECT 1; SELECT 2", 100);
    assert.equal(r.wrapped, false);
  });

  it("Kullanıcı zaten TOP yazmışsa dokunmaz", () => {
    const r = wrapWithTopIfSafe("SELECT TOP 10 * FROM Foo", 100);
    assert.equal(r.wrapped, false);
    const r2 = wrapWithTopIfSafe("SELECT TOP (10) * FROM Foo", 100);
    assert.equal(r2.wrapped, false);
  });

  it("DECLARE/SET/WAITFOR ile başlayan dokunmaz", () => {
    assert.equal(wrapWithTopIfSafe("DECLARE @x INT", 100).wrapped, false);
    assert.equal(wrapWithTopIfSafe("SET LOCK_TIMEOUT 1000", 100).wrapped, false);
    assert.equal(wrapWithTopIfSafe("WAITFOR DELAY '00:00:01'", 100).wrapped, false);
  });

  it("Trailing semicolon temizlenir", () => {
    const r = wrapWithTopIfSafe("SELECT * FROM Foo;", 100);
    assert.equal(r.wrapped, true);
    assert.doesNotMatch(r.sql, /;\s*\)/);
  });
});
