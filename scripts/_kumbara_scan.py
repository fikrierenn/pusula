"""Tek seferlik: 'Kumbara' değerini TÜM string kolonlarda tara (value-search).
Hangi veritabanı.tablo.kolon içinde 'Kumbara' geçen değer var → raporla.
Bulgu (16.06.2026): Kumbara = EncoreMerkez.dbo.RefundReasons Id=17 indirim tipi.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _errors import connect_with_retry  # noqa
from forecast.data import get_db_config  # noqa  (env config)

import pymssql

ARA = "Kumbara"
ALLOWED_DBS = ("EncoreMerkez", "DerinSISBkm", "BKMDATA")   # sabit allowlist — dışarıdan beslenmez


def _esc(ident: str) -> str:
    """SQL identifier güvenli quoting — köşeli parantez kaçışı ( ] → ]] )."""
    return ident.replace("]", "]]")


cfg = get_db_config()
conn = connect_with_retry(lambda: pymssql.connect(
    server=cfg["server"], user=cfg["user"], password=cfg["password"],
    database="master", autocommit=True, login_timeout=10, timeout=30))

bulunan = []
try:
    cur = conn.cursor()
    for db in ALLOWED_DBS:
        # string kolonları topla — parantez: tip filtresi VE (uzunluk VEYA MAX). (precedence fix)
        cur.execute(f"""
            SELECT s.name, t.name, c.name
            FROM [{_esc(db)}].sys.columns c
            JOIN [{_esc(db)}].sys.tables t ON t.object_id=c.object_id
            JOIN [{_esc(db)}].sys.schemas s ON s.schema_id=t.schema_id
            JOIN [{_esc(db)}].sys.types ty ON ty.user_type_id=c.user_type_id
            WHERE ty.name IN ('nvarchar','varchar','nchar','char','text','ntext')
              AND (c.max_length BETWEEN 1 AND 4000 OR c.max_length = -1)
        """)
        kolonlar = [(r[0], r[1], r[2]) for r in cur.fetchall()]
        print(f"[{db}] {len(kolonlar)} string kolon taranıyor...", file=sys.stderr, flush=True)
        for sch, tbl, col in kolonlar:
            cE, sE, tE, dE = _esc(col), _esc(sch), _esc(tbl), _esc(db)
            q = f"SELECT TOP 1 CAST([{cE}] AS nvarchar(80)) FROM [{dE}].[{sE}].[{tE}] WITH(NOLOCK) WHERE [{cE}] LIKE %s"
            try:
                cur.execute(q, ("%" + ARA + "%",))
                row = cur.fetchone()
                if row and row[0]:
                    bulunan.append((db, sch, tbl, col, row[0]))
                    print(f"  BULUNDU: {db}.{sch}.{tbl}.{col} = {row[0]!r}", flush=True)
            except pymssql.OperationalError:
                raise   # bağlantı kesilmesi sessizce yutulmaz
            except pymssql.Error as e:
                # erişilemeyen/computed kolon → atla (stderr, sessiz değil)
                print(f"  [atla] {db}.{sch}.{tbl}.{col}: {str(e)[:50]}", file=sys.stderr, flush=True)
finally:
    conn.close()

print(f"\n=== TOPLAM {len(bulunan)} kolon 'Kumbara' içeriyor ===", flush=True)
for db, sch, tbl, col, v in bulunan:
    print(f"{db}.{sch}.{tbl}.{col}  →  {v}", flush=True)
