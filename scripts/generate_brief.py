"""
BKM Kitap — Pazartesi Brief otomatik üretici.

Kullanım:
    python generate_brief.py [--date YYYY-MM-DD]
        --date  : Pazartesi tarihi (default: bu haftanın Pazartesi'si)

Çıktı:
    briefings/<MONDAY>/brief.html
    briefings/<MONDAY>/brief.txt

Davranış:
    - Ayın ilk Pazartesi → monthly şablon (önceki ay kapanış + kategori bazlı)
    - Diğer Pazartesi    → weekly şablon (sade hafta + MTD)

Bağımlılıklar: pymssql, jinja2
    pip install pymssql jinja2

DB config: ENV (MSSQL_HOST/USER/PASSWORD) veya .secrets/db.json:
    {"server": "192.168.40.201", "user": "sa", "password": "...", "database": "master"}
"""

import argparse
import json
import os
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

try:
    import pymssql
    from jinja2 import Environment, FileSystemLoader
except ImportError as e:
    sys.exit(f"Eksik paket: {e}. Yükle: pip install pymssql jinja2")

SCRIPT_VERSION = "1.1.0"  # 1.1.0: e-ticaret (JOKER) haftalık kanal kırılımı + birleşik toplam
REPO_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = REPO_ROOT / "briefings" / "template"
BRIEFINGS_DIR = REPO_ROOT / "briefings"

MEKAN_NAMES = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu"}
MEKAN_KEYS = {1: "fsm", 4477: "ozluce", 4478: "istyolu"}
TR_GUN = {
    "Monday": "Pzt", "Tuesday": "Sal", "Wednesday": "Çar",
    "Thursday": "Per", "Friday": "Cum", "Saturday": "Cmt", "Sunday": "Pzr",
}

# Türkiye resmi tatilleri (kısa liste, 2026)
SPECIAL_DAYS = {
    "01.01.2026": "Yılbaşı",
    "23.04.2026": "Çocuk Bayramı 🇹🇷",
    "01.05.2026": "Emek Bayramı 🌹",
    "10.05.2026": "Anneler Günü 👩",
    "19.05.2026": "Atatürk'ü Anma 🇹🇷",
    "21.06.2026": "Babalar Günü 👨",
    "30.08.2026": "Zafer Bayramı 🇹🇷",
    "29.10.2026": "Cumhuriyet Bayramı 🇹🇷",
}


# ----------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------

def _load_env_file():
    """Repo kökündeki .env'i parse et (dotenv olmadan, basit)."""
    env_path = REPO_ROOT / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        k = k.strip()
        v = v.strip().strip('"').strip("'")
        if k and k not in os.environ:
            os.environ[k] = v


def get_db_config():
    _load_env_file()
    env_host = os.environ.get("MSSQL_HOST")
    if env_host:
        return {
            "server": env_host,
            "user": os.environ.get("MSSQL_USER", "sa"),
            "password": os.environ.get("MSSQL_PASSWORD", ""),
            "database": os.environ.get("MSSQL_DATABASE", "master"),
        }
    cfg_path = REPO_ROOT / ".secrets" / "db.json"
    if cfg_path.exists():
        return json.loads(cfg_path.read_text(encoding="utf-8"))
    sys.exit("DB config yok. MSSQL_HOST env veya .secrets/db.json gerek.")


def get_monday(d):
    return d - timedelta(days=d.weekday())


def is_first_monday_of_month(d):
    return d.day <= 7


def fmt_money(n):
    if n is None:
        return "—"
    return f"{int(round(n)):,}".replace(",", ".")


def fmt_int(n):
    if n is None:
        return "0"
    return f"{int(round(n)):,}".replace(",", ".")


def fmt_pct(curr, prev):
    if not prev:
        return ("—", 0.0)
    pct = (curr - prev) / prev * 100
    sign = "+" if pct >= 0 else ""
    return (f"{sign}%{pct:.1f}".replace(".", ","), pct)


def query(conn, sql, **params):
    cur = conn.cursor(as_dict=True)
    cur.execute(sql, params)
    rows = cur.fetchall()
    cur.close()
    return rows


# ----------------------------------------------------------------
# SQL
# ----------------------------------------------------------------

SQL_PERIOD = """
SELECT MG.mekanID,
    SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * (s.GrossTotal - s.DiscountTotal)) AS NetCiro,
    SUM(IIF(s.DocumentsTypeId = 3, -1, 1)) AS Fis
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
    ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK)
    ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'
WHERE s.Date >= %(start)s AND s.Date < %(end)s
  AND spb.Id IS NULL
GROUP BY MG.mekanID
"""

SQL_DAILY = """
SELECT CONVERT(varchar, s.Date, 104) AS Tarih,
    DATENAME(WEEKDAY, s.Date) AS Gun,
    SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * (s.GrossTotal - s.DiscountTotal)) AS NetCiro,
    SUM(IIF(s.DocumentsTypeId = 3, -1, 1)) AS Fis
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
    ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK)
    ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'
WHERE s.Date >= %(start)s AND s.Date < %(end)s
  AND spb.Id IS NULL
GROUP BY CONVERT(varchar, s.Date, 104), DATENAME(WEEKDAY, s.Date)
"""

SQL_HEDEF = """
SELECT mekanId, SUM(hedef) AS HedefToplam
FROM BKMDATA.dbo.Hedef WITH(NOLOCK)
WHERE mekanId IN (1, 4477, 4478)
  AND tarih >= %(start)s AND tarih < %(end)s
GROUP BY mekanId
"""

SQL_CATEGORY = """
SELECT MG.mekanID, CAST(ktg.ktgrAd AS nvarchar(50)) AS Kategori,
    SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * sp.TotalPrice) AS Ciro
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
    ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
    ON sp.SalesId = s.Id AND sp.IsValid = 1 AND sp.BarcodeNo <> '1001'
JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id = sp.ProductsId
JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CONVERT(int, pr.Code)
JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID = u.urnKtgr2ID
WHERE s.Date >= %(start)s AND s.Date < %(end)s AND ISNUMERIC(pr.Code) = 1
GROUP BY MG.mekanID, CAST(ktg.ktgrAd AS nvarchar(50))
"""

# Türkçe ay adları (Python locale'den bağımsız)
TR_AY = {1: "Ocak", 2: "Şubat", 3: "Mart", 4: "Nisan", 5: "Mayıs", 6: "Haziran",
         7: "Temmuz", 8: "Ağustos", 9: "Eylül", 10: "Ekim", 11: "Kasım", 12: "Aralık"}


def fmt_pct_value(v):
    """Sayıyı Türkçe virgüllü yüzde gösterimine çevir: 29.2 → '29,2'"""
    if v is None:
        return "—"
    return f"{v:.1f}".replace(".", ",")

SQL_CATEGORY_TOTAL = """
SELECT
    SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * sp.TotalPrice) AS CategoryMatched,
    (SELECT SUM(IIF(s2.DocumentsTypeId = 3, -1, 1) * (s2.GrossTotal - s2.DiscountTotal))
     FROM EncoreMerkez.dbo.Sales s2 WITH(NOLOCK)
     LEFT JOIN EncoreMerkez.dbo.SalesProducts spb2 WITH(NOLOCK)
        ON spb2.SalesId = s2.Id AND spb2.BarcodeNo = '1001'
     WHERE s2.Date >= %(start)s AND s2.Date < %(end)s AND spb2.Id IS NULL) AS SalesTotal
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
    ON sp.SalesId = s.Id AND sp.IsValid = 1 AND sp.BarcodeNo <> '1001'
JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id = sp.ProductsId
JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CONVERT(int, pr.Code)
WHERE s.Date >= %(start)s AND s.Date < %(end)s AND ISNUMERIC(pr.Code) = 1
"""

SQL_CATEGORY_HEDEF = """
SELECT ktg.ktgrID, CAST(ktg.ktgrAd AS nvarchar(50)) AS Kategori,
    SUM(h.hedef) AS Hedef
FROM BKMDATA.dbo.Hedef h WITH(NOLOCK)
JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID = h.ktgId
WHERE h.mekanId IN (1, 4477, 4478)
  AND h.tarih >= %(start)s AND h.tarih < %(end)s
GROUP BY ktg.ktgrID, CAST(ktg.ktgrAd AS nvarchar(50))
"""

# E-ticaret (JOKER linked server). ⚠️ ORDERDATE param = ISO 'YYYYMMDD' string (DMY sessiz hata!).
# Net = gerçek iptal/iade hariç (STATUS 1001 İptal, 1006 İade, 1007 Kayıp, 3000/4000 Odak-İptal; 3004/3006 NORMAL — sema/codes.yaml).
# Çöp kanal (admin girişleri) → 'Diğer'. Doğrulama 11.06.2026: hafta 01-07.06 net 19,1M ₺.
SQL_ETICARET = """
SELECT
    CASE WHEN o.APPLICATION IN ('Mobil Uygulama (Android)', 'Mobil Uygulama (iOS)',
                                'Mobil Site', 'Web Sitesi')
         THEN o.APPLICATION ELSE 'Diğer' END AS Kanal,
    COUNT(*) AS Siparis,
    SUM(CASE WHEN o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000) THEN 1 ELSE 0 END) AS NetSiparis,
    SUM(CASE WHEN o.STATUS IN (1001, 1006, 1007, 3000, 4000) THEN 1 ELSE 0 END) AS IptalIade,
    SUM(CASE WHEN o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000) THEN o.TOTALPRICE ELSE 0 END) AS NetCiro
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
WHERE o.ORDERDATE >= %(start)s AND o.ORDERDATE < %(end)s
GROUP BY CASE WHEN o.APPLICATION IN ('Mobil Uygulama (Android)', 'Mobil Uygulama (iOS)',
                                     'Mobil Site', 'Web Sitesi')
              THEN o.APPLICATION ELSE 'Diğer' END
"""


# ----------------------------------------------------------------
# Data builders
# ----------------------------------------------------------------

def build_period_summary(rows, hedef_rows=None):
    """rows: SQL_PERIOD çıktısı. hedef_rows: SQL_HEDEF çıktısı (opsiyonel)."""
    by_mekan = {r["mekanID"]: r for r in rows}
    hedef_by_mekan = {h["mekanId"]: float(h["HedefToplam"]) for h in (hedef_rows or [])}

    total_net = sum(float(r["NetCiro"] or 0) for r in rows)
    total_fis = sum(int(r["Fis"] or 0) for r in rows)
    total_hedef = sum(hedef_by_mekan.values()) if hedef_by_mekan else None
    sepet = (total_net / total_fis) if total_fis else 0
    gerc = (total_net / total_hedef * 100) if total_hedef else None

    stores = []
    for mid in [4477, 4478, 1]:  # Özlüce, İst.Yolu, FSM
        r = by_mekan.get(mid, {"NetCiro": 0, "Fis": 0})
        net = float(r.get("NetCiro") or 0)
        fis = int(r.get("Fis") or 0)
        sep = (net / fis) if fis else 0
        h = hedef_by_mekan.get(mid)
        store = {
            "mekan_id": mid,
            "name": MEKAN_NAMES[mid],
            "key": MEKAN_KEYS[mid],
            "net_ciro": net,
            "net_ciro_fmt": fmt_money(net),
            "net_fmt": fmt_money(net),
            "fis": fis,
            "fis_int": fis,
            "fis_fmt": fmt_int(fis),
            "sepet": sep,
            "sepet_int": int(sep),
            "sepet_fmt": fmt_money(sep),
            "hedef": h,
            "hedef_fmt": fmt_money(h) if h else None,
            "gerceklesme_pct": round(net / h * 100, 1) if h else None,
            "delta": (net - h) if h else 0,
            "delta_fmt": fmt_money(net - h) if h else None,
            "pct_color": (
                "#27ae60" if h and net / h >= 0.95
                else "#f39c12" if h and net / h >= 0.85
                else "#c0392b" if h
                else "#666"
            ),
        }
        stores.append(store)

    summary = {
        "net_ciro": total_net,
        "net_ciro_fmt": fmt_money(total_net),
        "fis": total_fis,
        "fis_int": total_fis,
        "fis_fmt": fmt_int(total_fis),
        "sepet": sepet,
        "sepet_int": int(sepet),
        "sepet_fmt": fmt_money(sepet),
        "hedef": total_hedef,
        "hedef_fmt": fmt_money(total_hedef) if total_hedef else None,
        "gerceklesme_pct": round(gerc, 1) if gerc else None,
        "delta": (total_net - total_hedef) if total_hedef else 0,
        "delta_fmt": fmt_money(total_net - total_hedef) if total_hedef else None,
        "pct_color": (
            "#27ae60" if total_hedef and gerc >= 95
            else "#f39c12" if total_hedef and gerc >= 85
            else "#c0392b" if total_hedef
            else "#666"
        ),
    }
    return summary, stores


def add_wow(curr_summary, curr_stores, prev_summary, prev_stores):
    """WoW kolonları ekle."""
    wow_str, wow_pct = fmt_pct(curr_summary["net_ciro"], prev_summary["net_ciro"])
    fis_wow_str, _ = fmt_pct(curr_summary["fis"], prev_summary["fis"])
    sep_wow_str, _ = fmt_pct(curr_summary["sepet"], prev_summary["sepet"])
    curr_summary["wow_str"] = wow_str
    curr_summary["wow_pct"] = wow_pct
    curr_summary["fis_wow_str"] = fis_wow_str
    curr_summary["sepet_wow_str"] = sep_wow_str

    prev_by_mekan = {s["mekan_id"]: s for s in prev_stores}
    for s in curr_stores:
        p = prev_by_mekan.get(s["mekan_id"], {})
        ws, wp = fmt_pct(s["net_ciro"], p.get("net_ciro", 0))
        s["wow_str"] = ws
        s["wow_pct"] = wp


def add_delta_str(summary, stores):
    """Hedef-gerçek delta string."""
    if summary.get("delta") is not None:
        summary["delta_str"] = fmt_money(summary["delta"]) + " ₺"
    for s in stores:
        if s.get("delta") is not None:
            s["delta_str"] = fmt_money(s["delta"]) + " ₺"


def build_daily(rows):
    """Günlük seyir, gün başına 3 mağaza toplamı."""
    by_date = {}
    for r in rows:
        t = r["Tarih"]
        if t not in by_date:
            by_date[t] = {"NetCiro": 0, "Fis": 0, "Gun": r["Gun"]}
        by_date[t]["NetCiro"] += float(r["NetCiro"] or 0)
        by_date[t]["Fis"] += int(r["Fis"] or 0)

    daily = []
    for t in sorted(by_date.keys(), key=lambda x: datetime.strptime(x, "%d.%m.%Y")):
        d = by_date[t]
        net = d["NetCiro"]
        fis = d["Fis"]
        gun_tr = TR_GUN.get(d["Gun"], d["Gun"])
        special = SPECIAL_DAYS.get(t)
        sep = (net / fis) if fis else 0
        daily.append({
            "tarih": t,
            "gun_label": f"{t[:5]} {gun_tr}",  # "20.04 Pzt"
            "net_ciro": net,
            "net_ciro_fmt": fmt_money(net),
            "fis": fis,
            "fis_int": fis,
            "fis_fmt": fmt_int(fis),
            "sepet": sep,
            "sepet_int": int(sep),
            "sepet_fmt": fmt_money(sep),
            "is_special": bool(special),
            "special_note": special,
        })
    return daily


def build_categories(rows, hedef_rows=None, top_n=10):
    """Kategori × mağaza matrisi + hedef + gerçekleşme %."""
    by_cat = {}
    for r in rows:
        cat = r["Kategori"]
        if cat not in by_cat:
            by_cat[cat] = {1: 0, 4477: 0, 4478: 0}
        by_cat[cat][r["mekanID"]] = float(r["Ciro"] or 0)

    # Kategori bazlı hedef (3 mağaza toplamı)
    hedef_by_cat = {}
    for h in (hedef_rows or []):
        hedef_by_cat[h["Kategori"]] = float(h["Hedef"] or 0)

    cats = []
    for cat, vals in by_cat.items():
        toplam = vals[1] + vals[4477] + vals[4478]
        hedef = hedef_by_cat.get(cat, 0)
        gerc_pct = (toplam / hedef * 100) if hedef > 0 else None
        # Renk: yeşil ≥%95, sarı %85-95, kırmızı <%85
        if gerc_pct is None:
            pct_color = "#666"
        elif gerc_pct >= 95:
            pct_color = "#27ae60"
        elif gerc_pct >= 85:
            pct_color = "#f39c12"
        else:
            pct_color = "#c0392b"
        cats.append({
            "kategori": cat,
            "fsm": vals[1], "fsm_fmt": fmt_money(vals[1]),
            "ozluce": vals[4477], "ozluce_fmt": fmt_money(vals[4477]),
            "istyolu": vals[4478], "istyolu_fmt": fmt_money(vals[4478]),
            "toplam": toplam, "toplam_fmt": fmt_money(toplam),
            "hedef": hedef,
            "hedef_fmt": fmt_money(hedef) if hedef > 0 else "—",
            "gerc_pct_str": f"%{gerc_pct:.1f}".replace(".", ",") if gerc_pct is not None else "—",
            "pct_color": pct_color,
        })
    cats.sort(key=lambda x: -x["toplam"])
    cats = cats[:top_n]
    grand = sum(c["toplam"] for c in cats)
    for c in cats:
        pct = c["toplam"] / grand * 100 if grand else 0
        c["pay_pct"] = f"{pct:.1f}".replace(".", ",")
    return cats


# ----------------------------------------------------------------
# Main
# ----------------------------------------------------------------

KANAL_SIRA = ["Mobil Uygulama (Android)", "Mobil Uygulama (iOS)", "Mobil Site", "Web Sitesi", "Diğer"]


def build_eticaret(rows, prev_rows=None):
    """JOKER kanal satırları → kanallar listesi + toplam. WoW prev_rows ile."""
    prev_net = {}
    if prev_rows:
        prev_net = {r["Kanal"]: float(r["NetCiro"] or 0) for r in prev_rows}

    kanallar = []
    for r in sorted(rows, key=lambda r: KANAL_SIRA.index(r["Kanal"]) if r["Kanal"] in KANAL_SIRA else 99):
        net = float(r["NetCiro"] or 0)
        net_sip = int(r["NetSiparis"] or 0)
        wow_str, wow_pct = fmt_pct(net, prev_net.get(r["Kanal"]))
        kanallar.append({
            "name": r["Kanal"],
            "siparis_fmt": fmt_int(net_sip),
            "iptal_fmt": fmt_int(r["IptalIade"] or 0),
            "net_ciro": net,
            "net_ciro_fmt": fmt_money(net),
            "sepet_int": int(net / net_sip) if net_sip else 0,
            "wow_str": wow_str, "wow_pct": wow_pct,
        })

    top_net = sum(k["net_ciro"] for k in kanallar)
    top_sip = sum(int(r["NetSiparis"] or 0) for r in rows)
    top_iptal = sum(int(r["IptalIade"] or 0) for r in rows)
    prev_top = sum(prev_net.values()) if prev_net else None
    wow_str, wow_pct = fmt_pct(top_net, prev_top)
    toplam = {
        "siparis_fmt": fmt_int(top_sip),
        "iptal_fmt": fmt_int(top_iptal),
        "net_ciro": top_net,
        "net_ciro_fmt": fmt_money(top_net),
        "sepet_int": int(top_net / top_sip) if top_sip else 0,
        "wow_str": wow_str, "wow_pct": wow_pct,
    }
    return kanallar, toplam


def main():
    parser = argparse.ArgumentParser(description="Pazartesi Brief Üretici")
    parser.add_argument("--date", help="Pazartesi tarihi (YYYY-MM-DD), default bu hafta")
    args = parser.parse_args()

    target = (datetime.strptime(args.date, "%Y-%m-%d").date()
              if args.date else date.today())
    monday = get_monday(target)
    week_start = monday - timedelta(days=7)
    week_end = monday
    prev_week_start = week_start - timedelta(days=7)
    prev_week_end = week_start
    next_monday = monday + timedelta(days=7)

    is_monthly = is_first_monday_of_month(monday)
    if monday.month == 1:
        prev_month_year, prev_month_num = monday.year - 1, 12
    else:
        prev_month_year, prev_month_num = monday.year, monday.month - 1
    prev_month_start = date(prev_month_year, prev_month_num, 1)
    prev_month_end = date(prev_month_year + 1, 1, 1) if prev_month_num == 12 else date(prev_month_year, prev_month_num + 1, 1)

    mtd_start = date(monday.year, monday.month, 1)
    mtd_end = monday  # exclusive (bugün dahil değil — script Pazar gece çalışırsa Pazartesi sabah verisi henüz yok)

    print(f"[gen] Pazartesi: {monday}, monthly_kickoff: {is_monthly}")
    print(f"[gen] Hafta: {week_start} → {week_end - timedelta(days=1)}")
    print(f"[gen] MTD: {mtd_start} → {mtd_end - timedelta(days=1)}")
    if is_monthly:
        print(f"[gen] Önceki ay: {prev_month_start} → {prev_month_end - timedelta(days=1)}")

    # DB
    cfg = get_db_config()
    conn = pymssql.connect(
        server=cfg["server"], user=cfg["user"], password=cfg["password"],
        database=cfg.get("database", "master"), autocommit=True,
    )
    warnings = []

    try:
        wk_rows = query(conn, SQL_PERIOD, start=week_start, end=week_end)
        prev_wk_rows = query(conn, SQL_PERIOD, start=prev_week_start, end=prev_week_end)
        daily_rows = query(conn, SQL_DAILY, start=week_start, end=week_end)

        mtd_rows = query(conn, SQL_PERIOD, start=mtd_start, end=mtd_end)
        mtd_hedef_rows = query(conn, SQL_HEDEF, start=mtd_start, end=mtd_end)

        # E-ticaret (JOKER) — linked server düşerse brief yine üretilsin
        etic_rows = etic_prev_rows = None
        try:
            iso = lambda d: d.strftime("%Y%m%d")  # JOKER ORDERDATE ISO zorunlu
            etic_rows = query(conn, SQL_ETICARET, start=iso(week_start), end=iso(week_end))
            etic_prev_rows = query(conn, SQL_ETICARET, start=iso(prev_week_start), end=iso(prev_week_end))
        except Exception as e:
            print(f"[warn] E-ticaret (ODAKJOKER) sorgusu basarisiz: {e}", file=sys.stderr)
            warnings.append("E-ticaret verisi alınamadı (ODAKJOKER linked server) — bu hafta brief sadece fiziksel mağazaları kapsıyor.")

        if is_monthly:
            pm_rows = query(conn, SQL_PERIOD, start=prev_month_start, end=prev_month_end)
            pm_hedef_rows = query(conn, SQL_HEDEF, start=prev_month_start, end=prev_month_end)
            cat_rows = query(conn, SQL_CATEGORY, start=prev_month_start, end=prev_month_end)
            cat_total_rows = query(conn, SQL_CATEGORY_TOTAL, start=prev_month_start, end=prev_month_end)
            cat_hedef_rows = query(conn, SQL_CATEGORY_HEDEF, start=prev_month_start, end=prev_month_end)
    finally:
        conn.close()

    # Build
    week, stores = build_period_summary(wk_rows)
    prev_week, prev_stores = build_period_summary(prev_wk_rows)
    add_wow(week, stores, prev_week, prev_stores)

    daily = build_daily(daily_rows)
    mtd, mtd_stores = build_period_summary(mtd_rows, mtd_hedef_rows)

    # E-ticaret + birleşik toplam
    has_eticaret = bool(etic_rows)
    etic_kanallar, eticaret = (build_eticaret(etic_rows, etic_prev_rows) if has_eticaret else ([], None))
    birlesik = None
    if has_eticaret:
        b_net = week["net_ciro"] + eticaret["net_ciro"]
        birlesik = {
            "net_ciro_fmt": fmt_money(b_net),
            "fiziksel_pay": round(week["net_ciro"] / b_net * 100) if b_net else 0,
            "online_pay": round(eticaret["net_ciro"] / b_net * 100) if b_net else 0,
        }
    if not mtd_hedef_rows:
        warnings.append(f"Bu ay ({TR_AY[monday.month]} {monday.year}) için hedef tablosunda kayıt yok — gerçekleşme % gösterilmiyor.")

    # Pazartesi format
    monday_dmy = monday.strftime("%d.%m.%Y")
    next_monday_dmy = next_monday.strftime("%d.%m.%Y")
    week_number = monday.isocalendar()[1]
    next_week_number = next_monday.isocalendar()[1]
    mtd_label_tr = f"{TR_AY[monday.month]} {monday.year}"

    # Önümüzdeki haftada özel gün var mı?
    next_week_specials = []
    for i in range(7):
        d = monday + timedelta(days=i)
        ds = d.strftime("%d.%m.%Y")
        if ds in SPECIAL_DAYS:
            next_week_specials.append(f"{TR_GUN[d.strftime('%A')]} {ds[:5]} — {SPECIAL_DAYS[ds]}")
    next_week_note = (
        f"Hafta {next_week_number} ({(monday + timedelta(days=6)).strftime('%d.%m.%Y')} kapanışı). "
        + (f"Özel gün(ler): {'; '.join(next_week_specials)}" if next_week_specials else "Özel gün yok, baseline beklenir.")
    )

    context = {
        "monday_dmy": monday_dmy,
        "next_monday_dmy": next_monday_dmy,
        "week_number": week_number,
        "next_week_number": next_week_number,
        "week_start": week_start.strftime("%d.%m"),
        "week_end": (week_end - timedelta(days=1)).strftime("%d.%m"),
        "data_cutoff": (mtd_end - timedelta(days=1)).strftime("%d.%m.%Y") + " 23:59",
        "generated_at": datetime.now().strftime("%d.%m.%Y %H:%M"),
        "script_version": SCRIPT_VERSION,
        "mtd_label": mtd_label_tr,
        "next_week_note": next_week_note,
        "warnings": warnings,
        "has_warnings": bool(warnings),
        "week": week,
        "stores": stores,
        "daily": daily,
        "mtd": mtd,
        "mtd_stores": mtd_stores,
        "has_eticaret": has_eticaret,
        "etic_kanallar": etic_kanallar,
        "eticaret": eticaret,
        "birlesik": birlesik,
    }

    if is_monthly:
        prev_month, prev_month_stores = build_period_summary(pm_rows, pm_hedef_rows)
        add_delta_str(prev_month, prev_month_stores)
        categories = build_categories(cat_rows, hedef_rows=cat_hedef_rows, top_n=10)

        # Eşleşme oranı
        if cat_total_rows and cat_total_rows[0]["SalesTotal"]:
            matched = float(cat_total_rows[0]["CategoryMatched"] or 0)
            total = float(cat_total_rows[0]["SalesTotal"] or 0)
            match_pct = round(matched / total * 100, 1) if total else 0
            other = total - matched
            other_pct = round(100 - match_pct, 1)
        else:
            match_pct = 0
            other = 0
            other_pct = 0

        prev_month_label_tr = f"{TR_AY[prev_month_start.month]} {prev_month_start.year}"

        context.update({
            "prev_month_label": prev_month_label_tr,
            "prev_month": prev_month,
            "prev_month_stores": prev_month_stores,
            "categories": categories,
            "category_top_n": 10,
            "category_match_pct": match_pct,
            "category_other_fmt": fmt_money(other),
            "category_other_pct": other_pct,
        })

        template_html = "brief.monthly.html.tmpl"
        template_txt = "brief.monthly.txt.tmpl"
    else:
        template_html = "brief.weekly.html.tmpl"
        template_txt = "brief.weekly.txt.tmpl"

    # Render
    env = Environment(loader=FileSystemLoader(str(TEMPLATE_DIR)), autoescape=False, trim_blocks=False, lstrip_blocks=False)
    html = env.get_template(template_html).render(**context)
    txt = env.get_template(template_txt).render(**context)

    # Yaz
    out_dir = BRIEFINGS_DIR / monday.strftime("%Y-%m-%d")
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "brief.html").write_text(html, encoding="utf-8")
    (out_dir / "brief.txt").write_text(txt, encoding="utf-8")

    print(f"[OK] Brief uretildi: {out_dir}")
    print(f"     - {out_dir / 'brief.html'}")
    print(f"     - {out_dir / 'brief.txt'}")
    print(f"     Tip: {'monthly_kickoff' if is_monthly else 'weekly'}")
    if warnings:
        print(f"     Uyari: {len(warnings)} adet")
        for w in warnings:
            print(f"       - {w}")


if __name__ == "__main__":
    sys.exit(main())
