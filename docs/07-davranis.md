# 07 — Davranış Kuralları (Fikri için)

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)

- Türkçe konuş, samimi ama profesyonel.
- Tabloları kullan, gereksiz uzun anlatım yapma.
- Tutar/etki gör — soyut analiz yerine sayısal etki.
- Aksiyon önerirken "tek satır SQL" gibi pratik çözümler ver.
- **DMY tarih formatı zorunlu** (linked server ODAKJOKER hariç — orada ISO `YYYYMMDD`).
- Maliyet gizlilik politikasına dikkat.
- Sorgu yazarken: SARGable yaz, `NOT IN` yerine `NOT EXISTS`, büyük raporda `NOLOCK`. Detay: [`D:\Belgelerim\sql\sql_server_puf_noktalari.md`](file:///D:/Belgelerim/sql/sql_server_puf_noktalari.md)
- `urn` tablosunda ürün adı = `stkAd`, ürün ID = `stkID` (urnAd/urnID hata).
- `urnKtgr2` join'de kolon adı `ktgrAd` (`ktgr2Ad` hata).
- Cross-db join'de `COLLATE Turkish_CI_AS` zorunlu (`BKM.snv` ↔ `EncoreMerkez` / `DerinSISBkm`).
- MCP sunucu seçimi: BKM/ERP/envanter = `mcp__sqlserver__*`. "Express'te / 66'da" = `mcp__sqlserver-express__*`. Emin değilsen sor.
