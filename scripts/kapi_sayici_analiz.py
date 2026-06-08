"""
KAPI SAYICI PİLOT ANALİZ — FSM (yatırım gerekçesi)

FSM kapı sayıcı trafiği + POS satışı birleştirip dönüşüm analizini derinleştirir:
haftagünü pattern, trafik↔dönüşüm korelasyonu, kayıp-satış fırsatı (parasal).
Amaç: pilot değerini sayısallaştır → Özlüce + İst.Yolu yatırım kararını destekle.

Kullanım: python kapi_sayici_analiz.py
DB config: generate_brief.py ile aynı (.env / .secrets/db.json).
"""
import sys, csv, json, os, statistics
from pathlib import Path
from datetime import date
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pymssql

R = Path(__file__).resolve().parent.parent
WD = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Pzr"]
TRAFIK_CSV = R / "sayiyo" / "fsm_gunluk_trafik.csv"


def db_cfg():
    env = R / ".env"
    if env.exists():
        for l in env.read_text(encoding="utf-8").splitlines():
            if "=" in l and not l.strip().startswith("#"):
                k, v = l.split("=", 1); os.environ.setdefault(k.strip(), v.strip())
    h = os.environ.get("MSSQL_HOST")
    if h:
        return dict(server=h, user=os.environ.get("MSSQL_USER", "sa"),
                    password=os.environ.get("MSSQL_PASSWORD", ""),
                    database=os.environ.get("MSSQL_DATABASE", "master"))
    return json.loads((R / ".secrets" / "db.json").read_text(encoding="utf-8"))


SQL = """SELECT CONVERT(varchar,s.Date,23) T, SUM(IIF(s.DocumentsTypeId=3,-1,1)) Fis,
  SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) Ciro
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
WHERE MG.mekanID=1 AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
  AND s.Date>=%(start)s AND s.Date<%(end)s
GROUP BY CONVERT(varchar,s.Date,23)"""


def main():
    traf = {r["Tarih"]: int(r["Giris"]) for r in csv.DictReader(open(TRAFIK_CSV, encoding="utf-8"))}
    days = sorted(traf)
    y, m, d = map(int, days[-1].split("-"))
    end = date.fromordinal(date(y, m, d).toordinal() + 1).isoformat()
    cfg = db_cfg()
    conn = pymssql.connect(server=cfg["server"], user=cfg["user"], password=cfg["password"],
                           database=cfg.get("database", "master"))
    cur = conn.cursor(as_dict=True)
    cur.execute(SQL, {"start": days[0], "end": end})
    sal = {r["T"]: r for r in cur.fetchall()}
    cur.close(); conn.close()

    rows = []
    for g in days:
        if g not in sal:
            continue
        gi = traf[g]
        if gi < 50:  # bozuk/yarım sayıcı günü
            continue
        fis = int(sal[g]["Fis"]); ci = float(sal[g]["Ciro"] or 0)
        yy, mm, dd = map(int, g.split("-"))
        rows.append(dict(g=g, wd=WD[date(yy, mm, dd).weekday()], gi=gi, fis=fis, ci=ci,
                         conv=100*fis/gi, atv=ci/fis if fis else 0))
    # son günü (yarım) çıkar
    if rows and rows[-1]["g"] == date.today().isoformat():
        rows = rows[:-1]
    convs = [r["conv"] for r in rows]
    med = statistics.median(convs)

    print(f"\nFSM KAPI SAYICI ANALİZ — {rows[0]['g']} … {rows[-1]['g']} ({len(rows)} gün)\n" + "=" * 60)
    print(f"Dönüşüm: ort %{statistics.mean(convs):.1f} · medyan %{med:.1f} · "
          f"bant %{min(convs):.1f}-%{max(convs):.1f} · std {statistics.pstdev(convs):.1f}")
    print(f"Toplam: {sum(r['gi'] for r in rows):,} giriş · {sum(r['fis'] for r in rows):,} fiş · "
          f"{sum(r['ci'] for r in rows):,.0f} ₺")

    print("\nHAFTAGÜNÜ ortalamaları:")
    print(f"{'Gün':<5}{'Dönüşüm':>9}{'Giriş':>8}{'Ciro':>11}{'ATV':>7}")
    for w in WD:
        rs = [r for r in rows if r["wd"] == w]
        if rs:
            print(f"{w:<5}%{statistics.mean([r['conv'] for r in rs]):>7.1f}"
                  f"{statistics.mean([r['gi'] for r in rs]):>8.0f}"
                  f"{statistics.mean([r['ci'] for r in rs]):>11,.0f}"
                  f"{statistics.mean([r['atv'] for r in rs]):>7.0f}")

    lost = sum((med-r["conv"])/100*r["gi"]*r["atv"] for r in rows if r["conv"] < med)
    print(f"\nFIRSAT (alt-medyan günler medyana çekilse): +{lost:,.0f} ₺ / {len(rows)} gün")
    print(f"  günlük {lost/len(rows):,.0f} ₺ · YILLIK ~{lost/len(rows)*365:,.0f} ₺ (sadece FSM)")

    gs = [r["gi"] for r in rows]
    corr = (sum((gs[i]-statistics.mean(gs))*(convs[i]-statistics.mean(convs)) for i in range(len(rows)))
            / len(rows)) / (statistics.pstdev(gs)*statistics.pstdev(convs))
    print(f"\nTrafik↔Dönüşüm korelasyon: {corr:+.2f} "
          f"({'kapasite OK — trafik artışı ciroya döner' if abs(corr) < 0.2 else 'yüksek trafikte dönüşüm düşüyor — personel'})")
    b = max(rows, key=lambda r: r["conv"]); w = min(rows, key=lambda r: r["conv"])
    print(f"En iyi: {b['g']} {b['wd']} %{b['conv']:.1f} · En kötü: {w['g']} {w['wd']} %{w['conv']:.1f} (incele)")


if __name__ == "__main__":
    main()
