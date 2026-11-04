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
    timeout=30
)
cursor = conn.cursor(as_dict=True)

# 1. SatisAnaliziTaban son kesim
cursor.execute("""
SELECT MAX(Kesim) AS SonKesim, DATEDIFF(day, MAX(Kesim), GETDATE()) AS GecenGun
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
""")
r1 = cursor.fetchone()
print("1. SatisAnaliziTaban Son Kesim:", r1)

# 2. irsHrk canlilik
cursor.execute("""
SELECT MAX(ehTrhS) AS SonIrsHrk, COUNT(*) AS Son10GunKayit
FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
WHERE ehTrhS >= '2026-10-01'
""")
r2 = cursor.fetchone()
print("2. irsHrk Canlilik (Ekim 2026):", r2)

# 3. SatisAnaliziTaban nasil dolduruluyor?
cursor.execute("""
SELECT OBJECT_NAME(m.object_id) AS ObjeAdi, o.type_desc
FROM DerinSISBkm.sys.sql_modules m
JOIN DerinSISBkm.sys.objects o ON o.object_id = m.object_id
WHERE m.definition LIKE '%SatisAnaliziTaban%'
""")
r3 = cursor.fetchall()
print("3. SatisAnaliziTaban ile iliskili objeler:", r3)

conn.close()
