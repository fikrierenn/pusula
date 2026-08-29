# -*- coding: utf-8 -*-
"""
ÇOK SATAN ÜRÜN × STOK × BULUNURLUK (OSA) — çekirdek hesap (emitter ayrı).
Kaynak (sema canonical):
  satış  = dbo.irsHrk ehTip IN (4,100) satış / (5,101) iade · ehMekan IN (1,4477,4478) · ehAltDepo=0
           net adet = -SUM(ehAdetN) (çıkış negatif) · net ciro = gross - iade (ehTutarN KDV-HARİÇ)
  şube stok (anlık) = dbo.irsHrk kümülatif SUM(ehAdetN), tüm ehTip, ehAltDepo=0
  depo stok         = ent.odak_depo_Stok (KANONİK; stokSonAltDepo_vw mekan-toplamı KULLANILMAZ — transit 26142 tuzağı)
  bulunurluk        = bkm.StokAyBakiyeMekanBazli (Kaynak='irsHrk') carry-forward + GİRİŞ bakiyesi (M-1 ay-sonu) >= MIN_STOK
  master            = bkm.UrunBilgi (urnTip=0)
Çıktı: scratchpad/cok_satan_evren.csv
SQL arşivi: sorgular/2026-08-25-cok-satan-50-stok-bulunurluk.sql
"""
import os, re, sys, csv, datetime
import pyodbc

sys.stdout.reconfigure(encoding="utf-8")
R = os.path.join(os.path.dirname(__file__), "..")
OUT = os.environ.get("COKSATAN_OUT", ".")
MIN_STOK = 3
AY = 12

ENV = {}
with open(os.path.join(R, ".env"), encoding="utf-8") as f:
    for ln in f:
        m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
        if m and not ln.lstrip().startswith("#"):
            ENV[m.group(1)] = m.group(2).strip().strip('"')
host = ENV["MSSQL_HOST"]; port = ENV.get("MSSQL_PORT", "1433")
if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
    sys.exit("Geçersiz host/port (.env)")
cn = pyodbc.connect(
    "Driver={ODBC Driver 18 for SQL Server};Server=%s,%s;Database=DerinSISBkm;"
    "UID=%s;PWD=%s;TrustServerCertificate=yes;Timeout=30"
    % (host, port, ENV["MSSQL_USER"], ENV["MSSQL_PASSWORD"]), timeout=30)
cn.timeout = 1200
cur = cn.cursor()

today = datetime.date.today()
ay0 = datetime.date(today.year, today.month, 1)


def add_m(d, n):
    y, m = divmod((d.year * 12 + d.month - 1) + n, 12)
    return datetime.date(y, m + 1, 1)


bas12 = add_m(ay0, -AY)
bas3 = add_m(ay0, -3)
bas1 = add_m(ay0, -1)
print("Pencere: %s - %s (bu ay kismi, haric)" % (bas12.strftime("%d.%m.%Y"), ay0.strftime("%d.%m.%Y")), flush=True)


def chunks(x, n=1000):
    for i in range(0, len(x), n):
        yield x[i:i + n]


# ---------- 1) evren: son12 şube satışı ----------
cur.execute("""
SELECT h.ehstkID,
       -SUM(h.ehAdetN)                                                        AS adet12,
       SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE -h.ehTutarN END)  AS ciro12,
       -SUM(CASE WHEN h.ehTrhS>=? THEN h.ehAdetN ELSE 0 END)                   AS adet3,
       -SUM(CASE WHEN h.ehTrhS>=? THEN h.ehAdetN ELSE 0 END)                   AS adet1,
       COUNT(DISTINCT h.ehMekan)                                               AS satan_sube
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehTip IN (4,100,5,101) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0
  AND h.ehTrhS >= ? AND h.ehTrhS < ?
GROUP BY h.ehstkID
HAVING -SUM(h.ehAdetN) >= 100
    OR SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE -h.ehTutarN END) >= 50000
""", bas3, bas1, bas12, ay0)
sat = {int(r[0]): dict(adet12=float(r[1]), ciro12=float(r[2]), adet3=float(r[3]),
                       adet1=float(r[4]), satan_sube=int(r[5])) for r in cur.fetchall()}
ids = list(sat.keys())
print("Evren: %d SKU" % len(ids), flush=True)

# ---------- 2) master ----------
mst = {}
for ch in chunks(ids):
    cur.execute("SELECT stkID, stkAd, Kategori3, KatAna, mrkAd, FirmaAd, SatisFiyat, SonAlis, urnTip "
                "FROM bkm.UrunBilgi WHERE stkID IN (%s)" % ",".join(str(i) for i in ch))
    for r in cur.fetchall():
        mst[int(r[0])] = dict(ad=r[1], kat3=r[2], katana=r[3], marka=r[4], firma=r[5],
                              fiyat=float(r[6] or 0), alis=float(r[7] or 0), urnTip=int(r[8] or 0))

# ---------- 3) şube satış + anlık stok ----------
sube_sat, sube_stok = {}, {}
for ch in chunks(ids):
    inl = ",".join(str(i) for i in ch)
    cur.execute("""
    SELECT h.ehstkID, h.ehMekan, -SUM(h.ehAdetN),
           -SUM(CASE WHEN h.ehTrhS>=? THEN h.ehAdetN ELSE 0 END)
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehTip IN (4,100,5,101) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0
      AND h.ehTrhS>=? AND h.ehTrhS<? AND h.ehstkID IN (%s)
    GROUP BY h.ehstkID, h.ehMekan""" % inl, bas3, bas12, ay0)
    for r in cur.fetchall():
        sube_sat.setdefault(int(r[0]), {})[int(r[1])] = (float(r[2]), float(r[3]))
    cur.execute("""
    SELECT h.ehstkID, h.ehMekan, SUM(h.ehAdetN)
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehstkID IN (%s)
    GROUP BY h.ehstkID, h.ehMekan""" % inl)
    for r in cur.fetchall():
        sube_stok.setdefault(int(r[0]), {})[int(r[1])] = float(r[2] or 0)

# ---------- 4) depo (ODAK) stok ----------
depo = {}
for ch in chunks(ids):
    cur.execute("SELECT stkID, SUM(StokMiktar) FROM ent.odak_depo_Stok WHERE stkID IN (%s) GROUP BY stkID"
                % ",".join(str(i) for i in ch))
    for r in cur.fetchall():
        depo[int(r[0])] = float(r[1] or 0)

# ---------- 5) bulunurluk: kuru-ay sayısı (giriş bakiyesi < MIN_STOK) ----------
aylar = []
for k in range(AY):
    m0 = add_m(bas12, k)
    aylar.append(m0 - datetime.timedelta(days=1))     # M-1 ay sonu
vals = ",".join("(DATEFROMPARTS(%d,%d,%d))" % (g.year, g.month, g.day) for g in aylar)
kuru = {}
done = 0
for ch in chunks(ids, 300):
    idv = ",".join("(" + str(i) + ")" for i in ch)
    cur.execute("""
    SELECT t.stkID, t.mekan,
           SUM(CASE WHEN ISNULL(b.Stok,0) < %d THEN 1 ELSE 0 END),
           SUM(CASE WHEN b.Stok IS NULL THEN 1 ELSE 0 END)
    FROM (SELECT s.stkID, m.mekan, a.g
          FROM (VALUES %s) s(stkID)
          CROSS JOIN (VALUES (1),(4477),(4478)) m(mekan)
          CROSS JOIN (VALUES %s) a(g)) t
    OUTER APPLY (SELECT TOP 1 x.Stok FROM bkm.StokAyBakiyeMekanBazli x WITH(NOLOCK)
                 WHERE x.stkID=t.stkID AND x.ehMekan=t.mekan AND x.Kaynak='irsHrk' AND x.Donem<=t.g
                 ORDER BY x.Donem DESC) b
    GROUP BY t.stkID, t.mekan""" % (MIN_STOK, idv, vals))
    for r in cur.fetchall():
        kuru.setdefault(int(r[0]), {})[int(r[1])] = (int(r[2]), int(r[3]))
    done += len(ch)
    print("  bulunurluk %d/%d" % (done, len(ids)), flush=True)

# ---------- 6) birleştir ----------
rows = []
for sid, s in sat.items():
    m = mst.get(sid, {})
    if m.get("urnTip", 0) != 0:
        continue
    st = sube_stok.get(sid, {}); ss = sube_sat.get(sid, {}); ku = kuru.get(sid, {})
    stok_sube = sum(max(0.0, v) for v in st.values())
    g3 = s["adet3"] / 90.0
    rows.append(dict(
        stkID=sid, ad=m.get("ad"), kat3=m.get("kat3"), katana=m.get("katana"), marka=m.get("marka"),
        firma=m.get("firma"), fiyat=m.get("fiyat"), alis=m.get("alis"),
        adet12=s["adet12"], ciro12=s["ciro12"], adet3=s["adet3"], adet1=s["adet1"],
        satan_sube=s["satan_sube"],
        stok_fsm=max(0.0, st.get(1, 0)), stok_ozl=max(0.0, st.get(4477, 0)),
        stok_ist=max(0.0, st.get(4478, 0)), stok_sube=stok_sube, stok_depo=depo.get(sid, 0.0),
        gun_kapsam=round(stok_sube / g3, 1) if g3 > 0 else "",
        kuru_fsm=ku.get(1, ("", ""))[0], kuru_ozl=ku.get(4477, ("", ""))[0], kuru_ist=ku.get(4478, ("", ""))[0],
        satis_fsm=ss.get(1, (0, 0))[0], satis_ozl=ss.get(4477, (0, 0))[0], satis_ist=ss.get(4478, (0, 0))[0],
        satis3_fsm=ss.get(1, (0, 0))[1], satis3_ozl=ss.get(4477, (0, 0))[1], satis3_ist=ss.get(4478, (0, 0))[1],
    ))
p = os.path.join(OUT, "cok_satan_evren.csv")
with open(p, "w", newline="", encoding="utf-8-sig") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)
print("OK: %d satir -> %s" % (len(rows), p), flush=True)
cn.close()
