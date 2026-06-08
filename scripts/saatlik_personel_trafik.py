"""
SAATLİK PERSONEL × TRAFİK × SATIŞ — FSM (işgücü hizalama)

Her saat İÇERİDE kaç çalışan var (PDKS giriş/çıkış) vs o saatin trafiği (kapı
sayıcı saatlik) vs satış (POS saatlik fiş). Amaç: pik saatlerde eksik/fazla
personel tespiti → vardiya optimizasyonu.

⚠️ DURUM: UNTESTED — yazıldığında DB (192.168.40.201) erişilemezdi. Bağlantı
   gelince doğrulanacak. Saatlik trafik için kapı sayıcıdan "Saatlik" export şart
   (eldeki export günlük). Saatlik trafik YOKSA fiş (POS) aktivite proxy'si kullanılır.

Gereksinim:
  1. Saatlik trafik CSV (Tarih,Saat,Giris) — kapı sayıcı "Görünüm: Saatlik" export.
     YOKSA --no-traffic ile sadece personel×fiş hizalaması.
  2. DB config (.env / .secrets/db.json), generate_brief.py ile aynı.

Kullanım:
  python saatlik_personel_trafik.py --date 2026-06-07 [--traffic sayiyo/fsm_saatlik.csv]

YÖNTEM (içeride kaç personel):
  PDKS TTagZei segmentleri (PersNr, VonZeit, BisZeit) çekilir; her saat H için
  segmenti [H:00, H+1:00) ile çakışan distinct PersNr sayılır = o saat içeride.
  (SQL'de saat-slot jimnastiği yerine Python'da expand — daha sağlam/test edilebilir.)
"""
import sys, csv, json, os, argparse
from pathlib import Path
from datetime import datetime
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pymssql

R = Path(__file__).resolve().parent.parent
ACIK, KAPALI = 8, 23  # mağaza saatleri (08-23)


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


# FSM personel segmentleri (giriş-çıkış) — PDKS OPENQUERY
SEG_SQL = """SELECT * FROM OPENQUERY([PDKS], '
  SELECT z.TZe_PersNr AS PersNr, z.TZe_VonZeit AS Von, z.TZe_BisZeit AS Bis
  FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
  WHERE z.TZe_Datum = ''{d}''
    AND p.Per_Grp1 = ''MAĞAZALAR'' AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
    AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL
')"""

# FSM saatlik fiş/ciro (POS)
FIS_SQL = """SELECT DATEPART(HOUR, s.Date) Saat,
    SUM(IIF(s.DocumentsTypeId=3,-1,1)) Fis,
    CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) AS decimal(18,0)) Ciro
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK) ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
WHERE MG.mekanID=1 AND s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= %(g)s AND s.Date < %(g2)s
GROUP BY DATEPART(HOUR, s.Date)"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date", required=True, help="YYYY-MM-DD")
    ap.add_argument("--traffic", help="saatlik trafik CSV (Tarih,Saat,Giris)")
    args = ap.parse_args()
    g = args.date
    gd = datetime.strptime(g, "%Y-%m-%d")
    g2 = gd.replace(hour=0); g2 = g2.toordinal() + 1
    from datetime import date as _d
    g2 = _d.fromordinal(g2).isoformat()

    cfg = db_cfg()
    conn = pymssql.connect(server=cfg["server"], user=cfg["user"], password=cfg["password"],
                           database=cfg.get("database", "master"))
    cur = conn.cursor(as_dict=True)
    cur.execute(SEG_SQL.format(d=g.replace("-", "")))
    segs = cur.fetchall()
    cur.execute(FIS_SQL, {"g": g, "g2": g2})
    fis = {int(r["Saat"]): r for r in cur.fetchall()}
    cur.close(); conn.close()

    # saatlik trafik (varsa)
    traf = {}
    if args.traffic and Path(args.traffic).exists():
        for r in csv.DictReader(open(args.traffic, encoding="utf-8")):
            if r.get("Tarih") == g:
                traf[int(r["Saat"])] = int(r["Giris"])

    # her saat içeride personel: segment [Von,Bis) saat H'yi kapsıyor mu
    def icerde(h):
        n = 0
        for s in segs:
            v, b = s["Von"], s["Bis"]
            if v is None or b is None:
                continue
            if v.hour <= h and b.hour > h or (v.hour <= h and b.hour == h and b.minute > 0):
                n += 1
        return n

    print(f"\nFSM SAATLİK — {g}\n" + "=" * 56)
    print(f"{'Saat':<6}{'İçerde Pers.':>13}{'Giriş':>8}{'Fiş':>7}{'Giriş/Pers':>12}")
    for h in range(ACIK, KAPALI):
        pers = icerde(h)
        gi = traf.get(h)
        f = int(fis[h]["Fis"]) if h in fis else 0
        gp = f"{gi/pers:.1f}" if (gi and pers) else "—"
        gis = str(gi) if gi is not None else "—"
        print(f"{h:02d}:00{'':<1}{pers:>13}{gis:>8}{f:>7}{gp:>12}")
    print("\nYORUM: Giriş/Personel yüksek saatler = eksik personel (pik), düşük = fazla.")
    print("Saatlik trafik yoksa Fiş aktivite proxy'si kullan; ideal: kapı sayıcı saatlik export.")


if __name__ == "__main__":
    main()
