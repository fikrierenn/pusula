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

# 1. Ham SatisAnaliziTaban Alanları
sql1 = """
SELECT 
    COUNT(*) AS ToplamSKU,
    SUM(CONVERT(bigint, MerkezStok)) AS MerkezStok_Sum,
    SUM(CONVERT(bigint, MagazaStok)) AS MagazaStok_Sum,
    SUM(CONVERT(bigint, StokFsm)) AS StokFsm_Sum,
    SUM(CONVERT(bigint, StokOzl)) AS StokOzl_Sum,
    SUM(CONVERT(bigint, StokIst)) AS StokIst_Sum,
    SUM(CONVERT(bigint, ToplamStok)) AS ToplamStok_Sum
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = '2026-09-15'
"""
cursor.execute(sql1)
r1 = cursor.fetchone()
print("=== 1. SatisAnaliziTaban Ham Toplamlar ===")
for k, v in r1.items():
    print(f"{k}: {v:,}")

# 2. StokFsm + StokOzl + StokIst toplamı MagazaStok'a eşit mi?
sql2 = """
SELECT TOP 10
    stkID, stkAd, MerkezStok, MagazaStok, StokFsm, StokOzl, StokIst, ToplamStok
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = '2026-09-15' AND ToplamStok > 1000
ORDER BY ToplamStok DESC
"""
cursor.execute(sql2)
rows2 = cursor.fetchall()
print("\n=== 2. Örnek Satırlar (En Yüksek Stoklar) ===")
for r in rows2:
    print(f"{r['stkID']} | {r['stkAd'][:25]} | WMS: {r['MerkezStok']} | Magaza: {r['MagazaStok']} (FSM:{r['StokFsm']}, Ozl:{r['StokOzl']}, Ist:{r['StokIst']}) | Top: {r['ToplamStok']}")

# 3. Canlı WMS tablosu (depo.stok_adres_palet_vw veya stokSonAltDepo_vw) ile mağaza stokları
sql3 = """
SELECT 
    SUM(CASE WHEN ehMekan = 12 THEN stok ELSE 0 END) AS GercekDefterMerkez12,
    SUM(CASE WHEN ehMekan = 1 THEN stok ELSE 0 END) AS FsmStok,
    SUM(CASE WHEN ehMekan = 4477 THEN stok ELSE 0 END) AS OzluceStok,
    SUM(CASE WHEN ehMekan = 4478 THEN stok ELSE 0 END) AS IstYoluStok,
    SUM(CASE WHEN ehMekan IN (1, 4477, 4478) THEN stok ELSE 0 END) AS GercekMagazalarToplami
FROM DerinSISBkm.dbo.stokSonAltDepo_vw WITH (NOLOCK)
"""
try:
    cursor.execute(sql3)
    r3 = cursor.fetchone()
    print("\n=== 3. Canlı ERP Defteri (stokSonAltDepo_vw Mekanlar) ===")
    for k, v in r3.items():
        print(f"{k}: {v:,}")
except Exception as e:
    print("stokSonAltDepo_vw sorgulanamadı:", e)

conn.close()
