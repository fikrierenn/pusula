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
    -- 1. Merkez Depo Fiili Tutar
    SUM(CONVERT(decimal(28,2), MerkezStok * SatisFiyat)) AS Merkez_Liste,
    SUM(CONVERT(decimal(28,2), MerkezStok * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END)) AS Merkez_Maliyet,
    
    -- 2. Mağazalar Fiili Tutar
    SUM(CONVERT(decimal(28,2), MagazaStok * SatisFiyat)) AS Magaza_Liste,
    SUM(CONVERT(decimal(28,2), MagazaStok * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END)) AS Magaza_Maliyet,

    -- 3. Mağaza Dağılımları
    SUM(CONVERT(decimal(28,2), StokFsm * SatisFiyat)) AS Fsm_Liste,
    SUM(CONVERT(decimal(28,2), StokOzl * SatisFiyat)) AS Ozl_Liste,
    SUM(CONVERT(decimal(28,2), StokIst * SatisFiyat)) AS Ist_Liste
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = '2026-09-15' AND ToplamStok > 0
"""

cursor.execute(sql)
r = cursor.fetchone()
print("=== GERÇEK FİİLİ TUTAR HESAPLAMASI ===")
for k, v in r.items():
    print(f"{k}: {v:,.2f} TL")

conn.close()
