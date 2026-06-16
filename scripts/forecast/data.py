"""SQL → günlük net ciro serisi (plan-15 tahmin motoru, Faz 1).

irsHrk günlük net: satış (ehTip 1,4,100) − iade (3,5,101); 3 mağaza (1,4477,4478).
Mevcut rapor altyapısıyla aynı bağlantı/config/retry (scripts/_errors.py, generate_brief get_db_config).
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pandas as pd

# scripts/ dizinini path'e ekle → _errors yeniden kullan (DRY, plan-12 WS-5 retry).
_SCRIPTS = Path(__file__).resolve().parent.parent
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))
from _errors import connect_with_retry  # noqa: E402

_REPO_ROOT = _SCRIPTS.parent

# Tek mağaza analizi gerekirse mekan filtresi; 0/None = 3 mağaza toplam.
_MEKANLAR = (1, 4477, 4478)


def _load_env_file() -> None:
    """.env varsa ortam değişkenlerine yükle (generate_brief ile aynı davranış)."""
    env_path = _REPO_ROOT / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        k, v = k.strip(), v.strip().strip('"').strip("'")
        if k and k not in os.environ:
            os.environ[k] = v


def get_db_config() -> dict:
    """DB config — MSSQL_HOST env veya .secrets/db.json (generate_brief ile birebir)."""
    _load_env_file()
    host = os.environ.get("MSSQL_HOST")
    if host:
        return {
            "server": host,
            "user": os.environ.get("MSSQL_USER", "sa"),
            "password": os.environ.get("MSSQL_PASSWORD", ""),
            "database": os.environ.get("MSSQL_DATABASE", "master"),
        }
    cfg_path = _REPO_ROOT / ".secrets" / "db.json"
    if cfg_path.exists():
        return json.loads(cfg_path.read_text(encoding="utf-8"))
    sys.exit("DB config yok. MSSQL_HOST env veya .secrets/db.json gerek.")


def get_daily_series(mekan: int = 0) -> pd.DataFrame:
    """Günlük net ciro serisi → DataFrame[ds(date), y(float)]. mekan=0 → 3 mağaza toplam.

    Boş gün (satış yok) tarih aralığında 0 ile doldurulur (model sürekli seri bekler).
    """
    import pymssql

    sql = """
        SELECT CAST(h.ehTrhS AS date) AS ds,
               CAST(SUM(CASE WHEN h.ehTip IN (1,4,100) THEN h.ehTutarN
                             WHEN h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS float) AS y
        FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
        WHERE h.ehMekan IN (1,4477,4478) AND (%d = 0 OR h.ehMekan = %d)
          AND h.ehTip IN (1,3,4,5,100,101)
        GROUP BY CAST(h.ehTrhS AS date)
        ORDER BY ds;
    """
    cfg = get_db_config()
    conn = connect_with_retry(lambda: pymssql.connect(
        server=cfg["server"], user=cfg["user"], password=cfg["password"],
        database=cfg.get("database", "master"), autocommit=True,
    ))
    try:
        df = pd.read_sql(sql, conn, params=(mekan, mekan))
    finally:
        conn.close()

    if df.empty:
        raise RuntimeError("irsHrk günlük seri boş — bağlantı/filtre kontrol et (sessiz 0 döndürmez).")

    df["ds"] = pd.to_datetime(df["ds"])
    # Sürekli günlük index — eksik günleri 0 ile doldur (kapalı gün = 0 satış).
    full = pd.date_range(df["ds"].min(), df["ds"].max(), freq="D")
    df = df.set_index("ds").reindex(full, fill_value=0.0).rename_axis("ds").reset_index()
    return df


if __name__ == "__main__":
    # CLI smoke: gunluk seri ozeti (ASCII — Windows cp1254 konsol).
    d = get_daily_series()
    print(f"gun sayisi: {len(d)}  aralik: {d['ds'].min().date()} - {d['ds'].max().date()}")
    print(f"toplam net: {d['y'].sum():,.0f}  ort/gun: {d['y'].mean():,.0f}")
    print(d.tail(7).to_string(index=False))
