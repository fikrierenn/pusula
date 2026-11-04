import os
import sys
import pymssql

kok = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
env = {}
with open(os.path.join(kok, ".env"), encoding="utf-8") as f:
    for l in f:
        l = l.strip()
        if l and not l.startswith("#") and "=" in l:
            k, v = l.split("=", 1)
            env[k.strip()] = v.strip().strip('"')

conn = pymssql.connect(
    server=env["MSSQL_HOST"],
    user=env["MSSQL_USER"],
    password=env["MSSQL_PASSWORD"],
    database=env.get("MSSQL_DATABASE", "DerinSISBkm"),
    timeout=120
)
cursor = conn.cursor(as_dict=True)

sql = """
SELECT 
    COUNT(*) AS ToplamSKU,
    SUM(CONVERT(bigint, MerkezStok)) AS MerkezAdet,
    SUM(CONVERT(bigint, MagazaStok)) AS MagazaAdet,
    SUM(CONVERT(bigint, ToplamStok)) AS ToplamAdet,
    SUM(CONVERT(decimal(28,2), ToplamStok * SatisFiyat)) AS ToplamListeDegeri,
    SUM(CONVERT(decimal(28,2), ToplamStok * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END)) AS ToplamMaliyetDegeri,
    
    -- Fazlalık (Stok - Sezon Satışı)
    SUM(CONVERT(bigint, CASE WHEN ToplamStok > ISNULL(SezonToplam, 0) THEN ToplamStok - ISNULL(SezonToplam, 0) ELSE 0 END)) AS NetFazlaAdet,
    SUM(CONVERT(decimal(28,2), CASE WHEN ToplamStok > ISNULL(SezonToplam, 0) THEN (ToplamStok - ISNULL(SezonToplam, 0)) * SatisFiyat ELSE 0 END)) AS NetFazlaListeDegeri,
    SUM(CONVERT(decimal(28,2), CASE WHEN ToplamStok > ISNULL(SezonToplam, 0) THEN (ToplamStok - ISNULL(SezonToplam, 0)) * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END ELSE 0 END)) AS NetFazlaMaliyetDegeri,

    -- Aşırı Stok (>3x Sezon Satışı veya Satışı Olmayan Ölü Stok)
    SUM(CONVERT(decimal(28,2), CASE WHEN ToplamStok > 3 * ISNULL(SezonToplam, 0) THEN ToplamStok * SatisFiyat ELSE 0 END)) AS AsiriStokListeDegeri,
    SUM(CONVERT(decimal(28,2), CASE WHEN ToplamStok > 3 * ISNULL(SezonToplam, 0) THEN ToplamStok * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END ELSE 0 END)) AS AsiriStokMaliyetDegeri
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = '2026-09-15' AND ToplamStok > 0
"""

cursor.execute(sql)
r = cursor.fetchone()
print("=== TÜM ŞİRKET ENVANTERİ & FAZLALIK BİLANÇOSU ===")
for k, v in r.items():
    if isinstance(v, (int, float)):
        print(f"{k}: {v:,.2f}")
    else:
        print(f"{k}: {v}")

# Kategori Bazlı Dağılım
sql_cat = """
SELECT TOP 10
    ISNULL(Kategori1, 'Diğer') AS AnaKategori,
    COUNT(*) AS SKU,
    SUM(CONVERT(bigint, ToplamStok)) AS ToplamAdet,
    SUM(CONVERT(decimal(28,2), ToplamStok * SatisFiyat)) AS ListeDegeri,
    SUM(CONVERT(decimal(28,2), ToplamStok * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END)) AS MaliyetDegeri,
    SUM(CONVERT(decimal(28,2), CASE WHEN ToplamStok > ISNULL(SezonToplam, 0) THEN (ToplamStok - ISNULL(SezonToplam, 0)) * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END ELSE 0 END)) AS FazlaMaliyet
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = '2026-09-15' AND ToplamStok > 0
GROUP BY ISNULL(Kategori1, 'Diğer')
ORDER BY ListeDegeri DESC
"""
cursor.execute(sql_cat)
cats = cursor.fetchall()
print("\n=== KATEGORİ BAZLI ENVANTER VE FAZLALIK MALİYETİ ===")
for c in cats:
    print(f"{c['AnaKategori']:20s} | Liste: {c['ListeDegeri']:,.0f} TL | Maliyet: {c['MaliyetDegeri']:,.0f} TL | Fazla Maliyet: {c['FazlaMaliyet']:,.0f} TL")

conn.close()
