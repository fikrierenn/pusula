"""
İŞGÜCÜ × TRAFİK × DÖNÜŞÜM ÜÇGENİ — FSM (günlük)

Üç kaynağı birleştirir: kapı sayıcı trafik (CSV) + PDKS çalışılan saat (OPENQUERY)
+ POS fiş/ciro. Günlük yük (giriş/personel-saat), SPLH, dönüşüm + korelasyonlar.
Amaç: personel trafiğe doğru yerleşmiş mi — eksik/fazla personel günleri tespit.

DOĞRULAMA (08.04-07.06.2026, 60 gün, FSM):
  İşgücü↔trafik +0.69 (planlama çalışıyor) · yük↔dönüşüm +0.01 (kapasite var) ·
  işgücü↔dönüşüm -0.20 (ekstra personel dönüşüm getirmiyor — doygun).
  Eksik personel: 23.04 Çocuk Bayramı yük 14.4. Fazla: 02.06 Salı yük 7.5.

Kullanım: python isgucu_trafik_ucgen.py
DB: .env / .secrets/db.json (generate_brief.py ile aynı). Trafik: sayiyo/fsm_gunluk_trafik.csv.
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
DBAS, DSON = "20260408", "20260607"  # PDKS dönem (OPENQUERY ISO)


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


SALES = """SELECT CONVERT(varchar,s.Date,23) T, SUM(IIF(s.DocumentsTypeId=3,-1,1)) Fis,
  SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) Ciro
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo=%s
WHERE MG.mekanID=1 AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
  AND s.Date>=%s AND s.Date<%s GROUP BY CONVERT(varchar,s.Date,23)"""

# PDKS çalışılan saat (OPENQUERY iç literaller '' ile, dış arg ' ile)
LAB_INNER = ("SELECT CONVERT(varchar(10),z.TZe_Datum,23) Gun, "
             "CAST(SUM(DATEDIFF(MINUTE,z.TZe_VonZeit,z.TZe_BisZeit))/60.0 AS decimal(18,1)) Saat, "
             "COUNT(DISTINCT z.TZe_PersNr) Personel "
             "FROM TTagZei z JOIN TPerTab p ON p.Per_PersNr=z.TZe_PersNr "
             "WHERE z.TZe_Datum>=''%s'' AND z.TZe_Datum<=''%s'' "
             "AND p.Per_Grp1=''MAĞAZALAR'' AND LTRIM(RTRIM(p.Per_Grp2))=''FSM'' "
             "AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL "
             "GROUP BY CONVERT(varchar(10),z.TZe_Datum,23)") % (DBAS, DSON)


def corr(a, b):
    ma, mb = statistics.mean(a), statistics.mean(b)
    return (sum((a[i]-ma)*(b[i]-mb) for i in range(len(a))) / len(a)) / (statistics.pstdev(a)*statistics.pstdev(b))


def main():
    traf = {r["Tarih"]: int(r["Giris"]) for r in csv.DictReader(open(R/"sayiyo"/"fsm_gunluk_trafik.csv", encoding="utf-8"))}
    days = sorted(traf)
    y, m, d = map(int, days[-1].split("-"))
    end = date.fromordinal(date(y, m, d).toordinal()+1).isoformat()
    cfg = db_cfg()
    conn = pymssql.connect(server=cfg["server"], user=cfg["user"], password=cfg["password"],
                           database=cfg.get("database", "master"), login_timeout=20, timeout=60)
    cur = conn.cursor(as_dict=True)
    cur.execute(SALES, ("1001", days[0], end))
    sal = {r["T"]: r for r in cur.fetchall()}
    cur.execute("SELECT * FROM OPENQUERY([PDKS], '" + LAB_INNER + "')")
    lab = {r["Gun"]: r for r in cur.fetchall()}
    cur.close(); conn.close()

    rows = []
    for g in days:
        if g == date.today().isoformat() or g not in sal or g not in lab:
            continue
        gi = traf[g]
        if gi < 50:
            continue
        fis = int(sal[g]["Fis"]); ci = float(sal[g]["Ciro"] or 0)
        sa = float(lab[g]["Saat"]); pe = int(lab[g]["Personel"])
        if sa <= 0:
            continue
        rows.append(dict(g=g, wd=WD[date(*map(int, g.split("-"))).weekday()], gi=gi, fis=fis, ci=ci,
                         pe=pe, sa=sa, conv=100*fis/gi, load=gi/sa, splh=ci/sa))

    gi = [r["gi"] for r in rows]; sa = [r["sa"] for r in rows]
    conv = [r["conv"] for r in rows]; load = [r["load"] for r in rows]
    print(f"\nFSM İŞGÜCÜ ÜÇGENİ — {rows[0]['g']}…{rows[-1]['g']} ({len(rows)} gün)\n" + "="*58)
    print(f"Ort: giriş={statistics.mean(gi):.0f} · saat={statistics.mean(sa):.0f} · "
          f"yük={statistics.mean(load):.1f} · dönüşüm %{statistics.mean(conv):.1f} · SPLH {statistics.mean([r['splh'] for r in rows]):.0f}")
    print("\nKORELASYON:")
    print(f"  işgücü-saat ↔ trafik     : {corr(sa,gi):+.2f}  (personel trafiğe ayarlanıyor mu)")
    print(f"  yük ↔ dönüşüm            : {corr(load,conv):+.2f}  (kalabalık dönüşümü bozuyor mu)")
    print(f"  işgücü-saat ↔ dönüşüm    : {corr(sa,conv):+.2f}  (ekstra personel dönüşüm getiriyor mu)")
    print("\nHAFTAGÜNÜ:  gün  giriş  saat   yük  dönüşüm  SPLH")
    for w in WD:
        rs = [r for r in rows if r["wd"] == w]
        if rs:
            print(f"  {w:<4}{statistics.mean([r['gi'] for r in rs]):>6.0f}"
                  f"{statistics.mean([r['sa'] for r in rs]):>6.0f}{statistics.mean([r['load'] for r in rs]):>6.1f}"
                  f"  %{statistics.mean([r['conv'] for r in rs]):>5.1f}{statistics.mean([r['splh'] for r in rs]):>7.0f}")
    print("\nEKSİK personel (en yüksek yük):")
    for r in sorted(rows, key=lambda r: -r["load"])[:4]:
        print(f"  {r['g']} {r['wd']} yük={r['load']:.1f} (giriş {r['gi']}, saat {r['sa']:.0f}, dönüşüm %{r['conv']:.1f})")
    print("FAZLA personel (en düşük yük):")
    for r in sorted(rows, key=lambda r: r["load"])[:4]:
        print(f"  {r['g']} {r['wd']} yük={r['load']:.1f} (giriş {r['gi']}, saat {r['sa']:.0f}, dönüşüm %{r['conv']:.1f})")


if __name__ == "__main__":
    main()
