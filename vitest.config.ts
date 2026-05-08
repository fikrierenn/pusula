import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["src/**/*.test.ts"],
    environment: "node",
    // Test'ler env-dependent fonksiyonları çağırıyor (isWriteAllowed,
    // getMaxRows vb.) — process.env'e dokunan testler birbirini etkilemesin.
    isolate: true,
  },
});
