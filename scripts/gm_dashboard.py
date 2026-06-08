"""
GM DASHBOARD — tek sayfa, tüm raporlar + dönem seçici (canlı veri).

Dönem-duyarlı paneller (ciro, mağaza, e-ticaret, kategori, ödeme, iade, dönüşüm)
3 dönem için ön-hesaplanır (Günlük=dün / Haftalık=son 7g / Aylık=MTD); HTML'deki
<select> ile anında değişir. Referans paneller (envanter, devir, stockout, RFM,
ABC, marka, işgücü üçgeni) sabit.

Çıktı: briefings/gm-dashboard/index.html (self-contained, Chart.js CDN).
Kullanım: python gm_dashboard.py [--ref-date YYYY-MM-DD]   (default: dün)
DB: .env / .secrets/db.json.
"""
import sys, csv, json, os, argparse, re
from pathlib import Path
from datetime import date, timedelta
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pymssql

R = Path(__file__).resolve().parent.parent
OUT = R / "briefings" / "gm-dashboard"
KIRMIZI = "#E30622"
MEKAN = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu"}
EXC = "(N'Sınav Okulları',N'Dergi',N'Genel',N'Tanımsız',N'Etkinlik',N'Hediye Çeki',N'Sınav Kayıt')"


def cfg():
    e = R / ".env"
    if e.exists():
        for l in e.read_text(encoding="utf-8").splitlines():
            if "=" in l and not l.strip().startswith("#"):
                k, v = l.split("=", 1); os.environ.setdefault(k.strip(), v.strip())
    h = os.environ.get("MSSQL_HOST")
    if h:
        return dict(server=h, user=os.environ.get("MSSQL_USER", "sa"),
                    password=os.environ.get("MSSQL_PASSWORD", ""), database=os.environ.get("MSSQL_DATABASE", "master"))
    return json.loads((R / ".secrets" / "db.json").read_text(encoding="utf-8"))


def Q(cur, sql, p=None):
    cur.execute(sql, p or ())
    return cur.fetchall()


def fnum(n): return f"{n:,.0f}".replace(",", ".")


def period_data(cur, start, end, traf, hedef=None):
    """Dönem-duyarlı veri (start,end ISO date, end exclusive). Döner: dict."""
    giso, g2iso = start.replace("-", ""), end.replace("-", "")
    store = Q(cur, """SELECT MG.mekanID, SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) Net, SUM(IIF(s.DocumentsTypeId=3,-1,1)) Fis,
        SUM(IIF(s.DocumentsTypeId=3,s.GrossTotal,0)) Iade
      FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK) JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
      JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
      LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
      WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=%s AND s.Date<%s GROUP BY MG.mekanID""", (start, end))
    etic = Q(cur, """SELECT CASE WHEN o.APPLICATION IN ('Mobil Uygulama (Android)','Mobil Uygulama (iOS)','Mobil Site','Web Sitesi') THEN o.APPLICATION ELSE 'Diğer' END K,
        COUNT(*) Sip, SUM(o.TOTALPRICE) Ciro FROM ODAKJOKER.JOKER.dbo.J_ORDERS o WHERE o.ORDERDATE>=%s AND o.ORDERDATE<%s
        GROUP BY CASE WHEN o.APPLICATION IN ('Mobil Uygulama (Android)','Mobil Uygulama (iOS)','Mobil Site','Web Sitesi') THEN o.APPLICATION ELSE 'Diğer' END""", (giso, g2iso))
    kat = Q(cur, """SELECT TOP 8 CAST(ktg.ktgrAd AS nvarchar(50)) K, CAST(SUM(sp.TotalPrice) AS decimal(18,0)) Ciro
      FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId
      JOIN DerinSISBkm.dbo.urn u ON u.stkKod COLLATE Turkish_CI_AS=sp.BarcodeNo COLLATE Turkish_CI_AS
      JOIN DerinSISBkm.dbo.urnKtgr2 ktg ON ktg.ktgrID=u.urnKtgr2ID
      WHERE sp.IsValid=1 AND sp.BarcodeNo<>'1001' AND s.Date>=%s AND s.Date<%s AND ktg.ktgrAd<>N'Sınav Okulları'
      GROUP BY CAST(ktg.ktgrAd AS nvarchar(50)) ORDER BY Ciro DESC""", (start, end))
    ode = Q(cur, """SELECT CAST(pt.Name AS nvarchar(40)) K, SUM(sp.Amount) Tutar FROM EncoreMerkez.dbo.SalesPayments sp WITH(NOLOCK)
      JOIN EncoreMerkez.dbo.PaymentTypes pt ON pt.Id=sp.PaymentTypesId JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId
      WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND sp.IsChangeAmount=0 AND s.Date>=%s AND s.Date<%s GROUP BY CAST(pt.Name AS nvarchar(40))""", (start, end))
    # mağaza × kategori (drill-down)
    skat = Q(cur, """SELECT MG.mekanID, CAST(ktg.ktgrAd AS nvarchar(50)) K, CAST(SUM(sp.TotalPrice) AS decimal(18,0)) Ciro
      FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId
      JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
      JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
      JOIN DerinSISBkm.dbo.urn u ON u.stkKod COLLATE Turkish_CI_AS=sp.BarcodeNo COLLATE Turkish_CI_AS
      JOIN DerinSISBkm.dbo.urnKtgr2 ktg ON ktg.ktgrID=u.urnKtgr2ID
      WHERE sp.IsValid=1 AND sp.BarcodeNo<>'1001' AND s.Date>=%s AND s.Date<%s AND ktg.ktgrAd<>N'Sınav Okulları'
      GROUP BY MG.mekanID, CAST(ktg.ktgrAd AS nvarchar(50))""", (start, end))
    skat_map = {}
    for r in skat:
        skat_map.setdefault(r["mekanID"], []).append([r["K"], int(r["Ciro"])])
    for mid in skat_map:
        skat_map[mid] = sorted(skat_map[mid], key=lambda x: -x[1])[:7]
    smap = {s["mekanID"]: s for s in store}
    fiz = sum(float(s["Net"] or 0) for s in store); fis = sum(int(s["Fis"]) for s in store)
    iade = sum(float(s["Iade"] or 0) for s in store)
    etc = sum(float(e["Ciro"] or 0) for e in etic); esip = sum(int(e["Sip"]) for e in etic)
    # FSM dönüşüm: bu dönemdeki giriş toplamı
    d0 = date.fromisoformat(start); d1 = date.fromisoformat(end)
    gir = sum(traf.get((d0+timedelta(days=i)).isoformat(), 0) for i in range((d1-d0).days))
    fsmfis = int(smap[1]["Fis"]) if 1 in smap else 0
    donus = round(100*fsmfis/gir, 1) if gir else None
    # mağaza kartları
    stc = []
    for mid in (4477, 1, 4478):
        s = smap.get(mid)
        net = float(s["Net"] or 0) if s else 0; f = int(s["Fis"]) if s else 0
        sia = float(s["Iade"] or 0) if s else 0
        ger = None
        if hedef and hedef.get(mid):
            ger = round(100*net/hedef[mid], 1)
        stc.append(dict(mid=mid, ad=MEKAN[mid], net=net, fis=f, atv=round(net/f) if f else 0, ger=ger,
                        iade=round(sia), kat=skat_map.get(mid, [])))
    odemap = sorted(([o["K"], round(float(o["Tutar"] or 0))] for o in ode), key=lambda x: -x[1])
    nakit = sum(v for k, v in odemap if k == "TÜRK LİRASI")
    odetop = sum(v for k, v in odemap)
    return dict(fiz=round(fiz), fis=fis, iade=round(iade), etc=round(etc), esip=esip, toplam=round(fiz+etc),
                donus=donus, gir=gir, stores=stc, odeme=odemap,
                etic=sorted([[e["K"].replace("Mobil Uygulama ", "").replace("(", "").replace(")", ""), round(float(e["Ciro"] or 0)), int(e["Sip"])] for e in etic], key=lambda x: -x[1]),
                kat=[[k["K"], int(k["Ciro"])] for k in kat],
                nakit_pct=round(100*nakit/odetop, 1) if odetop else 0,
                iade_pct=round(100*iade/fiz, 2) if fiz else 0)


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--ref-date"); a = ap.parse_args()
    dun = a.ref_date or (date.today() - timedelta(days=1)).isoformat()
    d = date.fromisoformat(dun)
    g2 = (d + timedelta(days=1)).isoformat()
    hafta_bas = (d - timedelta(days=6)).isoformat()
    ay_bas = d.replace(day=1).isoformat()
    # trafik
    traf = {}
    tp = R / "sayiyo" / "fsm_gunluk_trafik.csv"
    if tp.exists():
        for r in csv.DictReader(open(tp, encoding="utf-8")):
            traf[r["Tarih"]] = int(r["Giris"])
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"], database=c.get("database", "master"), charset="UTF-8", login_timeout=20, timeout=240)
    cur = conn.cursor(as_dict=True)
    # hedef (MTD)
    hed = {h["mekanId"]: float(h["H"] or 0) for h in Q(cur, "SELECT mekanId, SUM(hedef) H FROM BKMDATA.dbo.Hedef WITH(NOLOCK) WHERE mekanId IN (1,4477,4478) AND tarih>=%s AND tarih<%s GROUP BY mekanId", (ay_bas, g2))}
    print("dönem verileri...")
    DATA = {
        "gunluk": period_data(cur, dun, g2, traf),
        "haftalik": period_data(cur, hafta_bas, g2, traf),
        "ay": period_data(cur, ay_bas, g2, traf, hed),
    }
    # trend (son 14 gün fiziksel)
    trend = Q(cur, """SELECT CONVERT(varchar,s.Date,23) T, SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) Net
      FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK) LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
      WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=DATEADD(DAY,-13,%s) AND s.Date<%s GROUP BY CONVERT(varchar,s.Date,23)""", (dun, g2))
    trend = sorted(trend, key=lambda x: x["T"])
    print("referans paneller...")
    # envanter
    env = Q(cur, f"""SELECT CAST(SUM([FSM Stok Maliyet]+[Özlüce Stok Maliyet]+[İst.Yolu Stok Maliyet]+[Merkez Depo Stok Maliyet]+[Odak Depo Stok Maliyet]) AS decimal(18,0)) T
      FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK) WHERE Tarih=(SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU) AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN {EXC}""")[0]["T"]
    # envanter verim (devir + WoS + sell-through + stok TL) — kategori
    ev = Q(cur, f"""SELECT m.K, m.Sat, m.Gel, ISNULL(b.A,0) BA, ISNULL(e.A,0) EA, ISNULL(b.M,0) BM, ISNULL(e.M,0) EM
      FROM (SELECT CAST(k.ktgrAd AS nvarchar(50)) K, -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) Sat, SUM(CASE WHEN h.ehTip IN (10,13) THEN h.ehAdetN ELSE 0 END) Gel
        FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
        WHERE h.ehTrhS>='2026-05-01' AND h.ehTrhS<'2026-06-01' AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100,10,13) GROUP BY CAST(k.ktgrAd AS nvarchar(50))) m
      LEFT JOIN (SELECT KTGR3 K, SUM(ISNULL([Fsm Stok Adet],0)+ISNULL([Özlüce Stok Adet],0)+ISNULL([İst.Yolu Stok Adet],0)) A, SUM(ISNULL([FSM Stok Maliyet],0)+ISNULL([Özlüce Stok Maliyet],0)+ISNULL([İst.Yolu Stok Maliyet],0)) M FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK) WHERE CAST(Tarih AS date)='2026-05-01' AND [Maliyet Tipi]='Ort.Maliyet' GROUP BY KTGR3) b ON b.K COLLATE Turkish_CI_AS=m.K COLLATE Turkish_CI_AS
      LEFT JOIN (SELECT KTGR3 K, SUM(ISNULL([Fsm Stok Adet],0)+ISNULL([Özlüce Stok Adet],0)+ISNULL([İst.Yolu Stok Adet],0)) A, SUM(ISNULL([FSM Stok Maliyet],0)+ISNULL([Özlüce Stok Maliyet],0)+ISNULL([İst.Yolu Stok Maliyet],0)) M FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK) WHERE CAST(Tarih AS date)='2026-05-31' AND [Maliyet Tipi]='Ort.Maliyet' GROUP BY KTGR3) e ON e.K COLLATE Turkish_CI_AS=m.K COLLATE Turkish_CI_AS
      WHERE m.K NOT IN {EXC}""")
    everim = []
    for r in ev:
        sat = float(r["Sat"] or 0); gel = float(r["Gel"] or 0)
        ort = (float(r["BA"] or 0)+float(r["EA"] or 0))/2; stl = (float(r["BM"] or 0)+float(r["EM"] or 0))/2
        if ort <= 0: continue
        everim.append(dict(k=r["K"], devir=round(12*sat/ort, 2), wos=round(ort*52/12/sat, 1) if sat else None,
                           st=round(100*sat/(float(r["BA"] or 0)+gel), 1) if (float(r["BA"] or 0)+gel) else None,
                           stoktl=round(stl), sat=round(sat)))
    # ABC + total
    abcq = Q(cur, """SELECT Sinif, COUNT(*) N, CAST(SUM(Ciro) AS decimal(18,0)) Ciro FROM (
        SELECT ProductsId, Ciro, 100.0*SUM(Ciro) OVER(ORDER BY Ciro DESC ROWS UNBOUNDED PRECEDING)/SUM(Ciro) OVER() KP FROM (
          SELECT sp.ProductsId, SUM(sp.TotalPrice) Ciro FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId
          WHERE sp.IsValid=1 AND sp.BarcodeNo<>'1001' AND s.Date>='2026-05-01' AND s.Date<'2026-06-01' AND s.DocumentsTypeId IN (1,2,6,7,8) GROUP BY sp.ProductsId HAVING SUM(sp.TotalPrice)>0) p) r
      CROSS APPLY (SELECT CASE WHEN KP<=80 THEN 'A' WHEN KP<=95 THEN 'B' ELSE 'C' END Sinif) x GROUP BY Sinif""")
    abc = {r["Sinif"]: dict(n=int(r["N"]), ciro=int(r["Ciro"])) for r in abcq}
    # RFM iki kanal
    def rfm_q(sql, params):
        return sorted([[r["S"], int(r["N"]), int(r["C"] or 0)] for r in Q(cur, sql, params)])
    rfm_yk = rfm_q("""SELECT seg.S, COUNT(*) N, SUM(c.Mon) C FROM (SELECT s.CustomersId, DATEDIFF(DAY,MAX(s.Date),%s) Rec, COUNT(*) Frq, SUM(s.GrossTotal-s.DiscountTotal) Mon
        FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK) WHERE s.DocumentsTypeId=1 AND s.CustomersId>0 AND s.Date>=DATEADD(DAY,-365,%s) AND s.Date<%s GROUP BY s.CustomersId) c
      CROSS APPLY (SELECT CAST(CASE WHEN Frq>=8 AND Rec<=30 THEN N'1-Şampiyon' WHEN Frq>=4 AND Rec<=90 THEN N'2-Sadık' WHEN Frq<=2 AND Rec<=30 THEN N'3-Yeni' WHEN Rec BETWEEN 91 AND 180 THEN N'4-Risk' WHEN Rec>180 THEN N'5-Kayıp' ELSE N'6-Diğer' END AS nvarchar(20)) S) seg GROUP BY seg.S""", (dun, dun, g2))
    g2iso = g2.replace("-", ""); dun_iso = dun.replace("-", ""); bas365 = (d - timedelta(days=365)).isoformat().replace("-", "")
    rfm_et = rfm_q("""SELECT seg.S, COUNT(*) N, SUM(c.Mon) C FROM (SELECT oc.CUSTOMERREF, DATEDIFF(DAY,MAX(o.ORDERDATE),%s) Rec, COUNT(*) Frq, SUM(o.TOTALPRICE) Mon
        FROM ODAKJOKER.JOKER.dbo.J_ORDERS o JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF WHERE o.ORDERDATE>=%s AND o.ORDERDATE<%s AND oc.CUSTOMERREF>0 GROUP BY oc.CUSTOMERREF) c
      CROSS APPLY (SELECT CAST(CASE WHEN Frq>=5 AND Rec<=30 THEN N'1-Şampiyon' WHEN Frq>=3 AND Rec<=90 THEN N'2-Sadık' WHEN Frq<=2 AND Rec<=30 THEN N'3-Yeni' WHEN Rec BETWEEN 91 AND 180 THEN N'4-Risk' WHEN Rec>180 THEN N'5-Kayıp' ELSE N'6-Diğer' END AS nvarchar(20)) S) seg GROUP BY seg.S""", (dun, bas365, g2iso))
    # marka top 20
    marka = [[r["M"], int(r["Ciro"]), int(r["Adet"]), int(r["Cesit"])] for r in Q(cur, """SELECT TOP 20 CAST(mrk.mrkAd AS nvarchar(80)) M, CAST(SUM(sp.TotalPrice) AS decimal(18,0)) Ciro, CAST(SUM(sp.Amount) AS int) Adet, COUNT(DISTINCT sp.ProductsId) Cesit FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
      JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId JOIN DerinSISBkm.dbo.urn u ON u.stkKod COLLATE Turkish_CI_AS=sp.BarcodeNo COLLATE Turkish_CI_AS
      JOIN DerinSISBkm.dbo.urnMrk mrk ON mrk.mrkID=u.urnMrkID WHERE sp.IsValid=1 AND sp.BarcodeNo<>'1001' AND s.Date>='2026-05-01' AND s.Date<'2026-06-01' AND s.DocumentsTypeId IN (1,2,6,7,8)
      GROUP BY CAST(mrk.mrkAd AS nvarchar(80)) ORDER BY Ciro DESC""")]
    cur.close(); conn.close()
    REF = dict(everim=everim, abc=abc, rfm_yk=rfm_yk, rfm_et=rfm_et, marka=marka)
    render(dun, DATA, trend, int(env or 0), REF)


def render(dun, DATA, trend, env, REF):
    everim = REF["everim"]; abc = REF["abc"]; marka = REF["marka"]
    devir = sorted([[e["k"], e["devir"]] for e in everim], key=lambda x: -x[1])
    d = date.fromisoformat(dun)
    GUN_TR = {0: "Pzt", 1: "Sal", 2: "Çar", 3: "Per", 4: "Cum", 5: "Cmt", 6: "Pzr"}
    bas = d.strftime("%d.%m.%Y") + " " + GUN_TR[d.weekday()]
    trend_lbl = [t["T"][5:] for t in trend]
    trend_val = [round(float(t["Net"] or 0)) for t in trend]
    olu = sorted(everim, key=lambda e: -e["stoktl"])  # kilitli sermaye
    abc_rows = "".join(f"<tr><td>{k}</td><td style='text-align:right'>{fnum(abc[k]['n'])}</td><td style='text-align:right'>{fnum(abc[k]['ciro'])} ₺</td></tr>" for k in ('A', 'B', 'C') if k in abc)
    rfm_rows = "".join(f"<tr><td>{s}</td><td style='text-align:right'>{fnum(n)}</td></tr>" for s, n, c in REF["rfm_yk"][:6])
    marka_rows = "".join(f"<tr><td>{m}</td><td style='text-align:right'>{fnum(c)} ₺</td></tr>" for m, c, ad, ce in marka[:6])
    devir_rows = "".join(f"<tr><td>{k}</td><td style='text-align:right'>{v:.2f}x</td></tr>" for k, v in devir[:5])
    olu_rows = "".join(f"<tr><td>{e['k']}</td><td style='text-align:right'>{fnum(e['stoktl'])} ₺</td><td style='text-align:right;color:#dc2626'>{e['devir']:.2f}x</td></tr>" for e in olu[:5])

    tmpl = TEMPLATE
    repl = {
        "__KIRMIZI__": KIRMIZI, "__BAS__": bas, "__ENV__": fnum(env),
        "__DATA__": json.dumps(DATA, ensure_ascii=False),
        "__REF__": json.dumps(REF, ensure_ascii=False),
        "__TRENDLBL__": json.dumps(trend_lbl), "__TRENDVAL__": json.dumps(trend_val),
        "__ABC__": abc_rows, "__RFM__": rfm_rows, "__MARKA__": marka_rows,
        "__DEVIR__": devir_rows, "__DEVIRSLOW__": olu_rows,
    }
    for k, v in repl.items():
        tmpl = tmpl.replace(k, v)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "index.html").write_text(tmpl, encoding="utf-8")
    g = DATA["gunluk"]
    print(f"Dashboard: {OUT/'index.html'}")
    print(f"  Günlük toplam {fnum(g['toplam'])} ₺ (online %{round(100*g['etc']/g['toplam']) if g['toplam'] else 0}) · FSM dönüşüm %{g['donus']}")


TEMPLATE = r"""<!doctype html><html lang=tr><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>BKM GM Dashboard — __BAS__</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>
*{box-sizing:border-box;margin:0;font-family:'Segoe UI',system-ui,sans-serif}
body{background:#f1f5f9;color:#0f172a;padding:18px;max-width:1280px;margin:auto}
.hd{display:flex;align-items:center;gap:14px;margin-bottom:16px;flex-wrap:wrap}
.logo{background:__KIRMIZI__;color:#fff;font-weight:800;padding:8px 14px;border-radius:10px;font-size:19px;letter-spacing:1px}
.hd h1{font-size:19px} .tar{color:#64748b;font-size:13px}
select{margin-left:auto;padding:8px 12px;border-radius:9px;border:2px solid __KIRMIZI__;font-size:14px;font-weight:700;color:__KIRMIZI__;background:#fff;cursor:pointer}
.big{background:linear-gradient(135deg,__KIRMIZI__,#b00518);color:#fff;border-radius:16px;padding:20px 24px;display:flex;gap:36px;align-items:center;flex-wrap:wrap;margin-bottom:14px;box-shadow:0 6px 20px rgba(227,6,34,.25)}
.big .lbl{opacity:.85;font-size:12px;text-transform:uppercase;letter-spacing:1px}
.big .num{font-size:34px;font-weight:800;line-height:1.1} .big .sub{font-size:13px;opacity:.9}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px;margin-bottom:14px}
.card{background:#fff;border-radius:13px;padding:14px 16px;box-shadow:0 2px 8px rgba(0,0,0,.06)}
.card.kpi{border-left:5px solid __KIRMIZI__}
.ct{font-size:11px;color:#64748b;text-transform:uppercase;letter-spacing:.5px;font-weight:700}
.cv{font-size:23px;font-weight:800;margin:4px 0} .cm{font-size:12.5px;color:#475569}
.sec{font-size:12px;font-weight:800;color:#94a3b8;text-transform:uppercase;letter-spacing:1px;margin:18px 0 8px}
.row{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px}
.panel{background:#fff;border-radius:13px;padding:14px 16px;box-shadow:0 2px 8px rgba(0,0,0,.06)}
.panel h3{font-size:13px;margin-bottom:10px;color:#334155}
table{width:100%;border-collapse:collapse;font-size:13px} td{padding:5px 4px;border-bottom:1px solid #f1f5f9}
.foot{color:#94a3b8;font-size:11px;text-align:center;margin-top:16px}
.clk{cursor:pointer;transition:transform .1s,box-shadow .1s}
.clk:hover{transform:translateY(-2px);box-shadow:0 6px 18px rgba(227,6,34,.22)}
.big .clk:hover{opacity:.85}
.ovl{display:none;position:fixed;inset:0;background:rgba(15,23,42,.55);z-index:50;align-items:center;justify-content:center;padding:20px}
.ovl.on{display:flex}
.modal{background:#fff;border-radius:16px;padding:22px 24px;max-width:560px;width:100%;max-height:85vh;overflow:auto;box-shadow:0 20px 50px rgba(0,0,0,.3)}
.modal h2{font-size:18px;color:__KIRMIZI__;margin-bottom:4px}
.modal .x{float:right;cursor:pointer;font-size:22px;color:#94a3b8;line-height:1}
.modal .kpis{display:flex;gap:18px;margin:12px 0;flex-wrap:wrap}
.modal .kpis div span{display:block;font-size:11px;color:#64748b} .modal .kpis div b{font-size:18px}
</style></head><body>
<div class=ovl id=ovl onclick="if(event.target===this)this.classList.remove('on')"><div class=modal id=modal></div></div>
<div class=hd><span class=logo>bkmkitap</span><h1>Genel Müdür Panosu</h1><span class=tar id=tar></span>
  <select id=dsel onchange="render(this.value)">
    <option value=gunluk>Günlük (dün)</option>
    <option value=haftalik>Haftalık (son 7 gün)</option>
    <option value=ay>Aylık (ay başı→bugün)</option>
  </select></div>

<div class=big>
  <div><div class=lbl>Toplam Ciro (fiziksel + online)</div><div class=num id=b_toplam></div><div class=sub id=b_alt></div></div>
  <div><div class=lbl>İşlem</div><div class=num id=b_islem></div><div class=sub id=b_islemalt></div></div>
  <div><div class=lbl>FSM Dönüşüm (kapı sayıcı)</div><div class=num id=b_donus></div><div class=sub id=b_donusalt></div></div>
  <div class=clk onclick="detayOdeme()"><div class=lbl>İade / Ödeme &#9656;</div><div class=num id=b_iade></div><div class=sub>nakit ödeme <span id=b_nakit></span></div></div>
</div>

<div class=grid id=stores></div>

<div class=row>
  <div class=panel><h3>Mağaza Kategori Mix (dönem)</h3><canvas id=ch_kat height=150></canvas></div>
  <div class=panel><h3>E-ticaret Kanal (dönem)</h3><canvas id=ch_etic height=150></canvas></div>
  <div class=panel><h3>Son 14 Gün — Fiziksel Net Ciro</h3><canvas id=ch_trend height=150></canvas></div>
</div>

<div class=sec>Referans — Envanter & Müşteri & Merchandising (aylık/güncel)</div>
<div class=grid>
  <div class="card kpi"><div class=ct>Envanter Değeri (Ort.Maliyet)</div><div class=cv>__ENV__ ₺</div><div class=cm>Dergi/Sınav hariç</div></div>
</div>
<div class=row>
  <div class="panel clk" onclick="detayDevir()"><h3>Devir Hızı — Hızlı (yıllık) &#9656;</h3><table>__DEVIR__</table></div>
  <div class="panel clk" onclick="detayOlu()"><h3>Ölü Sermaye — kilitli stok ₺ &#9656;</h3><table><tr><td><b>Kategori</b></td><td style="text-align:right"><b>Stok ₺</b></td><td style="text-align:right"><b>Devir</b></td></tr>__DEVIRSLOW__</table></div>
  <div class="panel clk" onclick="detayAbc()"><h3>ABC Analizi (Pareto) &#9656;</h3><table><tr><td><b>Sınıf</b></td><td style="text-align:right"><b>Ürün</b></td><td style="text-align:right"><b>Ciro</b></td></tr>__ABC__</table></div>
  <div class="panel clk" onclick="detayRfm()"><h3>RFM — Yazarkasa (365g) &#9656;</h3><table>__RFM__</table></div>
  <div class="panel clk" onclick="detayMarka()"><h3>Top Marka / Yayınevi (Mayıs) &#9656;</h3><table>__MARKA__</table></div>
</div>

<div class=foot>BKM Kitap · GM Dashboard (otomatik) · scripts/gm_dashboard.py</div>
<script>
const DATA=__DATA__;
const REF=__REF__;
const fnum=n=>Math.round(n).toLocaleString('tr-TR');
const tl=n=>fnum(n)+' ₺';
let chKat,chEtic,chTrend;
function render(p){
  window.CUR=p;
  const x=DATA[p];
  document.getElementById('tar').textContent='__BAS__ · '+({gunluk:'günlük',haftalik:'haftalık',ay:'aylık (MTD)'}[p]);
  document.getElementById('b_toplam').textContent=tl(x.toplam);
  document.getElementById('b_alt').innerHTML='Fiziksel '+tl(x.fiz)+' · E-ticaret '+tl(x.etc)+' (%'+(x.toplam?Math.round(100*x.etc/x.toplam):0)+')';
  document.getElementById('b_islem').textContent=fnum(x.fis+x.esip);
  document.getElementById('b_islemalt').textContent=fnum(x.fis)+' fiş · '+fnum(x.esip)+' sipariş';
  document.getElementById('b_donus').textContent=x.donus?('%'+x.donus):'—';
  document.getElementById('b_donusalt').textContent=x.gir?(fnum(x.gir)+' giriş (FSM)'):'veri yok';
  document.getElementById('b_iade').textContent='%'+x.iade_pct;
  document.getElementById('b_nakit').textContent='%'+x.nakit_pct;
  // mağaza kartları
  let h='';
  for(let i=0;i<x.stores.length;i++){const s=x.stores[i];
    let g=s.ger!=null?('<div class=cm>MTD hedef <b style="color:'+(s.ger>=100?'#16a34a':(s.ger<95?'#dc2626':'#64748b'))+'">%'+s.ger+'</b></div>'):'';
    h+='<div class="card clk" onclick="detayStore('+i+')"><div class=ct>'+s.ad+' &#9656;</div><div class=cv>'+tl(s.net)+'</div><div class=cm>'+fnum(s.fis)+' fiş · sepet '+fnum(s.atv)+' ₺</div>'+g+'</div>';
  }
  document.getElementById('stores').innerHTML=h;
  // grafikler
  const kpi='__KIRMIZI__';
  if(chKat)chKat.destroy();
  chKat=new Chart(document.getElementById('ch_kat'),{type:'bar',data:{labels:x.kat.map(k=>k[0]),datasets:[{data:x.kat.map(k=>k[1]),backgroundColor:kpi}]},options:{indexAxis:'y',plugins:{legend:{display:false}},scales:{x:{ticks:{callback:v=>(v/1000000).toFixed(1)+'M'}}}}});
  if(chEtic)chEtic.destroy();
  chEtic=new Chart(document.getElementById('ch_etic'),{type:'doughnut',data:{labels:x.etic.map(e=>e[0]),datasets:[{data:x.etic.map(e=>e[1]),backgroundColor:[kpi,'#f59e0b','#0ea5e9','#64748b']}]},options:{plugins:{legend:{position:'right'}}}});
}
chTrend=new Chart(document.getElementById('ch_trend'),{type:'line',data:{labels:__TRENDLBL__,datasets:[{data:__TRENDVAL__,borderColor:'__KIRMIZI__',backgroundColor:'rgba(227,6,34,.1)',fill:true,tension:.3}]},options:{plugins:{legend:{display:false}},scales:{y:{ticks:{callback:v=>(v/1000000).toFixed(1)+'M'}}}}});
function openModal(html){document.getElementById('modal').innerHTML='<span class=x onclick="document.getElementById(\'ovl\').classList.remove(\'on\')">&times;</span>'+html;document.getElementById('ovl').classList.add('on');}
function detayStore(i){const s=DATA[window.CUR].stores[i];
  let rows=s.kat.map(k=>'<tr><td>'+k[0]+'</td><td style="text-align:right">'+tl(k[1])+'</td></tr>').join('');
  openModal('<h2>'+s.ad+'</h2><div style="color:#64748b;font-size:12px">'+({gunluk:'günlük',haftalik:'haftalık',ay:'aylık (MTD)'}[window.CUR])+' detay</div>'+
   '<div class=kpis><div><span>Net Ciro</span><b>'+tl(s.net)+'</b></div><div><span>Fiş</span><b>'+fnum(s.fis)+'</b></div><div><span>Sepet Ort</span><b>'+fnum(s.atv)+' ₺</b></div><div><span>İade</span><b>'+tl(s.iade)+'</b></div>'+(s.ger!=null?'<div><span>MTD Hedef</span><b>%'+s.ger+'</b></div>':'')+'</div>'+
   '<h3 style="font-size:13px;margin:8px 0">Kategori Kırılımı</h3><table>'+rows+'</table>');}
function detayOdeme(){const o=DATA[window.CUR].odeme;const top=o.reduce((a,b)=>a+b[1],0);
  let rows=o.map(k=>'<tr><td>'+k[0]+'</td><td style="text-align:right">'+tl(k[1])+'</td><td style="text-align:right;color:#64748b">%'+(top?(100*k[1]/top).toFixed(1):0)+'</td></tr>').join('');
  openModal('<h2>Ödeme Dağılımı</h2><div style="color:#64748b;font-size:12px">'+({gunluk:'günlük',haftalik:'haftalık',ay:'aylık (MTD)'}[window.CUR])+' · kasa mutabakat</div><table style="margin-top:10px"><tr><td><b>Tip</b></td><td style="text-align:right"><b>Tutar</b></td><td style="text-align:right"><b>Pay</b></td></tr>'+rows+'</table>');}
function detayDevir(){let e=[...REF.everim].sort((a,b)=>b.devir-a.devir);
  let rows=e.map(x=>'<tr><td>'+x.k+'</td><td style="text-align:right">'+x.devir.toFixed(2)+'x</td><td style="text-align:right">'+(x.wos?x.wos.toFixed(0)+' hf':'—')+'</td><td style="text-align:right">'+(x.st!=null?'%'+x.st:'—')+'</td><td style="text-align:right">'+tl(x.stoktl)+'</td></tr>').join('');
  openModal('<h2>Envanter Verim — Kategori</h2><div style="color:#64748b;font-size:12px">Mayıs 2026 · devir / weeks-of-supply / sell-through / stok değeri</div><table style="margin-top:10px"><tr><td><b>Kategori</b></td><td style="text-align:right"><b>Devir/yıl</b></td><td style="text-align:right"><b>WoS</b></td><td style="text-align:right"><b>Sell-thr.</b></td><td style="text-align:right"><b>Stok ₺</b></td></tr>'+rows+'</table>');}
function detayOlu(){let e=[...REF.everim].sort((a,b)=>b.stoktl-a.stoktl);let tot=e.reduce((a,b)=>a+b.stoktl,0);
  let rows=e.map(x=>'<tr><td>'+x.k+'</td><td style="text-align:right">'+tl(x.stoktl)+'</td><td style="text-align:right;color:#64748b">%'+(tot?(100*x.stoktl/tot).toFixed(0):0)+'</td><td style="text-align:right;color:'+(x.devir<1.5?'#dc2626':'#16a34a')+'">'+x.devir.toFixed(2)+'x</td><td style="text-align:right">'+(x.wos?x.wos.toFixed(0)+' hf':'—')+'</td></tr>').join('');
  openModal('<h2>Ölü Sermaye — Kilitli Stok</h2><div style="color:#64748b;font-size:12px">Stok değeri yüksek + devir düşük = ölü sermaye (kırmızı devir &lt;1,5x). Toplam '+tl(tot)+'</div><table style="margin-top:10px"><tr><td><b>Kategori</b></td><td style="text-align:right"><b>Stok ₺</b></td><td style="text-align:right"><b>Pay</b></td><td style="text-align:right"><b>Devir</b></td><td style="text-align:right"><b>WoS</b></td></tr>'+rows+'</table>');}
function detayAbc(){let a=REF.abc;let tn=0,tc=0;for(const k of['A','B','C'])if(a[k]){tn+=a[k].n;tc+=a[k].ciro;}
  let rows=['A','B','C'].filter(k=>a[k]).map(k=>'<tr><td><b>'+k+'</b></td><td style="text-align:right">'+fnum(a[k].n)+'</td><td style="text-align:right">%'+(100*a[k].n/tn).toFixed(0)+'</td><td style="text-align:right">'+tl(a[k].ciro)+'</td><td style="text-align:right">%'+(100*a[k].ciro/tc).toFixed(0)+'</td></tr>').join('');
  openModal('<h2>ABC Analizi (Pareto 80/20)</h2><div style="color:#64748b;font-size:12px">Mayıs · A=ilk %80 ciro · C=uzun kuyruk (clearance adayı)</div><table style="margin-top:10px"><tr><td><b>Sınıf</b></td><td style="text-align:right"><b>Ürün</b></td><td style="text-align:right"><b>SKU %</b></td><td style="text-align:right"><b>Ciro</b></td><td style="text-align:right"><b>Ciro %</b></td></tr>'+rows+'</table>');}
function detayRfm(){function t(arr,frqL){return arr.map(x=>'<tr><td>'+x[0]+'</td><td style="text-align:right">'+fnum(x[1])+'</td><td style="text-align:right">'+tl(x[2])+'</td></tr>').join('');}
  openModal('<h2>RFM Müşteri Segmentasyonu</h2><div style="color:#64748b;font-size:12px">365 gün · iki ayrı evren (kimlik köprüsü yok)</div>'+
   '<h3 style="font-size:13px;margin:10px 0 4px">Yazarkasa (sadakat kartı)</h3><table><tr><td><b>Segment</b></td><td style="text-align:right"><b>Müşteri</b></td><td style="text-align:right"><b>Ciro</b></td></tr>'+t(REF.rfm_yk)+'</table>'+
   '<h3 style="font-size:13px;margin:14px 0 4px">E-ticaret (JOKER)</h3><table><tr><td><b>Segment</b></td><td style="text-align:right"><b>Müşteri</b></td><td style="text-align:right"><b>Ciro</b></td></tr>'+t(REF.rfm_et)+'</table>');}
function detayMarka(){let rows=REF.marka.map((x,i)=>'<tr><td>'+(i+1)+'. '+x[0]+'</td><td style="text-align:right">'+tl(x[1])+'</td><td style="text-align:right">'+fnum(x[2])+'</td><td style="text-align:right">'+fnum(x[3])+'</td><td style="text-align:right">'+tl(x[1]/x[3])+'</td></tr>').join('');
  openModal('<h2>Marka / Yayınevi — Top 20</h2><div style="color:#64748b;font-size:12px">Mayıs · ciro/çeşit = yoğunluk (dar+güçlü vs geniş+uzun kuyruk)</div><table style="margin-top:10px"><tr><td><b>Marka</b></td><td style="text-align:right"><b>Ciro</b></td><td style="text-align:right"><b>Adet</b></td><td style="text-align:right"><b>Çeşit</b></td><td style="text-align:right"><b>₺/Çeşit</b></td></tr>'+rows+'</table>');}
render('gunluk');
</script></body></html>"""


if __name__ == "__main__":
    main()
