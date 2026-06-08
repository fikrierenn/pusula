"""
G8 — DÖNÜŞÜM ORANI (FSM kapı sayıcı × POS fiş)

Kapı sayıcı trafik verisi (sayiyo/*.xlsx → tidy CSV) + EncoreMerkez fiş/ciro
birleştirip günlük dönüşüm oranı (Fiş / Giriş) + ziyaretçi başına ciro hesaplar.

KAPSAM: Şu an SADECE FSM (tek kapı sayıcı). Özlüce + İst.Yolu sayıcıları gelince
        çoklu mağaza eklenecek (B-22). Uzun vade: trafiği SQL tabloya yükle → native join.

Kullanım:
    python donusum_orani.py [--csv sayiyo/fsm_gunluk_trafik.csv]

DB config: ENV (MSSQL_HOST/USER/PASSWORD) veya .secrets/db.json (generate_brief.py ile aynı).

DOĞRULAMA (02-08.06.2026, MCP ile): hafta 5.471 fiş / 10.738 giriş = %51,0 dönüşüm.
"""
import argparse, csv, json, os, sys
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

try:
    import pymssql
except ImportError as e:
    sys.exit(f"Eksik paket: {e}. Yükle: pip install pymssql")

REPO_ROOT = Path(__file__).resolve().parent.parent


def load_env_file():
    env = REPO_ROOT / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())


def get_db_config():
    load_env_file()
    host = os.environ.get("MSSQL_HOST")
    if host:
        return dict(server=host, user=os.environ.get("MSSQL_USER", "sa"),
                    password=os.environ.get("MSSQL_PASSWORD", ""),
                    database=os.environ.get("MSSQL_DATABASE", "master"))
    cfg = REPO_ROOT / ".secrets" / "db.json"
    if cfg.exists():
        return json.loads(cfg.read_text(encoding="utf-8"))
    sys.exit("DB config yok. MSSQL_HOST env veya .secrets/db.json gerek.")


# FSM günlük fiş + net ciro (geri dönüşüm hariç, iade sign'lı)
SQL_FSM = """
SELECT CONVERT(varchar, s.Date, 23) AS Tarih,
    SUM(IIF(s.DocumentsTypeId = 3, -1, 1)) AS Fis,
    SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * (s.GrossTotal - s.DiscountTotal)) AS NetCiro
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
    ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK)
    ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'
WHERE MG.mekanID = 1 AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
  AND s.Date >= %(start)s AND s.Date < %(end)s
GROUP BY CONVERT(varchar, s.Date, 23)
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=str(REPO_ROOT / "sayiyo" / "fsm_gunluk_trafik.csv"))
    args = ap.parse_args()

    # 1) trafik CSV (Tarih ISO, Giris)
    traffic = {}
    with open(args.csv, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            traffic[row["Tarih"]] = int(row["Giris"])
    if not traffic:
        sys.exit("Trafik CSV boş.")
    gunler = sorted(traffic)
    start, end = gunler[0], gunler[-1]

    # 2) DB fiş/ciro
    cfg = get_db_config()
    conn = pymssql.connect(server=cfg["server"], user=cfg["user"],
                           password=cfg["password"], database=cfg.get("database", "master"))
    cur = conn.cursor(as_dict=True)
    # end exclusive → son günü dahil et
    from datetime import date as _d
    y, m, d = map(int, end.split("-"))
    end_excl = (_d(y, m, d).toordinal() + 1)
    end_excl = _d.fromordinal(end_excl).isoformat()
    cur.execute(SQL_FSM, {"start": start, "end": end_excl})
    sales = {r["Tarih"]: r for r in cur.fetchall()}
    cur.close(); conn.close()

    # 3) birleştir + dönüşüm
    print(f"\nFSM DÖNÜŞÜM ORANI — {start} … {end}\n" + "=" * 64)
    print(f"{'Tarih':<12}{'Giriş':>8}{'Fiş':>8}{'Dönüşüm':>10}{'Net Ciro':>14}{'₺/Ziyaret':>12}")
    tg = tf = tc = 0
    for g in gunler:
        giris = traffic[g]
        s = sales.get(g)
        fis = int(s["Fis"]) if s else 0
        ciro = float(s["NetCiro"]) if s and s["NetCiro"] else 0.0
        tg += giris; tf += fis; tc += ciro
        donus = f"%{100*fis/giris:.1f}".replace(".", ",") if giris else "—"
        cpv = f"{ciro/giris:,.0f}".replace(",", ".") if giris else "—"
        print(f"{g:<12}{giris:>8}{fis:>8}{donus:>10}{ciro:>14,.0f}{cpv:>12}")
    print("-" * 64)
    dt = f"%{100*tf/tg:.1f}".replace(".", ",") if tg else "—"
    print(f"{'TOPLAM':<12}{tg:>8}{tf:>8}{dt:>10}{tc:>14,.0f}{tc/tg:>12,.0f}")
    print(f"\nDönüşüm = Fiş / Giriş · ₺/Ziyaret = Net Ciro / Giriş")
    print("Kapsam: FSM (tek kapı sayıcı). Özlüce + İst.Yolu sayıcıları bekleniyor (B-22).")


if __name__ == "__main__":
    main()
