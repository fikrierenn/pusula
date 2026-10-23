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

# 1. Macro inventory check
sql1 = """
SELECT 
    COUNT(*) AS ToplamSatir,
    COUNT(CASE WHEN ToplamStok > 0 THEN 1 END) AS PozitifStokSKU,
    SUM(CONVERT(bigint, MerkezStok)) AS MerkezAdet,
    SUM(CONVERT(bigint, MagazaStok)) AS MagazaAdet,
    SUM(CONVERT(bigint, ToplamStok)) AS ToplamAdet,
    SUM(CONVERT(decimal(28,2), ToplamStok * SatisFiyat)) AS ToplamListeDegeri,
    SUM(CONVERT(decimal(28,2), ToplamStok * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END)) AS TahminiMaliyetDegeri
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = '2026-09-15'
"""

cursor.execute(sql1)
r1 = cursor.fetchone()
print("=== 1. SatisAnaliziTaban KESİM 15.09.2026 MAKRO ===")
for k, v in r1.items():
    if isinstance(v, (int, float)):
        print(f"{k}: {v:,.2f}")
    else:
        print(f"{k}: {v}")

# 2. bkm.ENVANTER_RAPORU en son kaydı
sql2 = """
SELECT TOP 5 Tarih, MaliyetTip, SUM(StokAdet) AS Adet, SUM(StokMaliyet) AS Tutar
FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH (NOLOCK)
GROUP BY Tarih, MaliyetTip
ORDER BY Tarih DESC, MaliyetTip
"""
try:
    cursor.execute(sql2)
    rows2 = cursor.fetchall()
    print("\n=== 2. bkm.ENVANTER_RAPORU SON KAYITLAR ===")
    for r in rows2:
        print(r)
except Exception as e:
    print("ENVANTER_RAPORU sorgulanamadi:", e)

# 3. Fazla Stok Eşiği (Stok > 3x Sezon Satışı veya Devir < 1.0)
sql3 = """
SELECT 
    COUNT(*) AS FazlaSKUSayisi,
    SUM(CONVERT(bigint, ToplamStok)) AS FazlaAdet,
    SUM(CONVERT(decimal(28,2), ToplamStok * SatisFiyat)) AS FazlaListeDegeri,
    SUM(CONVERT(decimal(28,2), ToplamStok * CASE WHEN BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat THEN BirimMaliyet ELSE SatisFiyat * 0.45 END)) AS FazlaMaliyetDegeri
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = '2026-09-15'
  AND ToplamStok > 0
  AND (SezonToplam <= 0 OR ToplamStok > 3 * SezonToplam)
"""
cursor.execute(sql3)
r3 = cursor.fetchone()
print("\n=== 3. AŞIRI STOK (FAZLA STOK: Stok > 3x Sezon Satışı veya Satışı Olmayan) ===")
for k, v in r3.items():
    if isinstance(v, (int, float)):
        print(f"{k}: {v:,.2f}")
    else:
        print(f"{k}: {v}")

conn.close()
