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
    # kategori mix — irsHrk (stkID üstünden; stkKod≠barkod, EncoreMerkez join kategori kaçırıyordu)
    kat = Q(cur, """SELECT TOP 8 CAST(k.ktgrAd AS nvarchar(50)) K, CAST(ABS(SUM(CASE WHEN h.ehTip IN(4,100) THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) Ciro
      FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
      WHERE h.ehTrhS>=%s AND h.ehTrhS<%s AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100) AND k.ktgrAd<>N'Sınav Okulları'
      GROUP BY CAST(k.ktgrAd AS nvarchar(50)) ORDER BY Ciro DESC""", (start, end))
    ode = Q(cur, """SELECT CAST(pt.Name AS nvarchar(40)) K, SUM(sp.Amount) Tutar FROM EncoreMerkez.dbo.SalesPayments sp WITH(NOLOCK)
      JOIN EncoreMerkez.dbo.PaymentTypes pt ON pt.Id=sp.PaymentTypesId JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId
      WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND sp.IsChangeAmount=0 AND s.Date>=%s AND s.Date<%s GROUP BY CAST(pt.Name AS nvarchar(40))""", (start, end))
    # mağaza × kategori (drill) — irsHrk (stkID)
    skat = Q(cur, """SELECT h.ehMekan mekanID, CAST(k.ktgrAd AS nvarchar(50)) K, CAST(ABS(SUM(CASE WHEN h.ehTip IN(4,100) THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) Ciro
      FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
      WHERE h.ehTrhS>=%s AND h.ehTrhS<%s AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100) AND k.ktgrAd<>N'Sınav Okulları'
      GROUP BY h.ehMekan, CAST(k.ktgrAd AS nvarchar(50))""", (start, end))
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
    ap = argparse.ArgumentParser(); ap.add_argument("--ref-date"); ap.add_argument("--serve", action="store_true"); ap.add_argument("--port", type=int, default=8000); a = ap.parse_args()
    if a.serve:   # özeti yeniden HESAPLAMA — mevcut index.html'i sun + API canlı (anında başlar)
        return serve(a.port)
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
    # marka top 20 — irsHrk (stkID)
    marka = [[r["M"], int(r["Ciro"] or 0), int(r["Adet"] or 0), int(r["Cesit"])] for r in Q(cur, """SELECT TOP 20 CAST(mrk.mrkAd AS nvarchar(80)) M,
        CAST(ABS(SUM(CASE WHEN h.ehTip IN(4,100) THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) Ciro,
        CAST(-SUM(CASE WHEN h.ehTip IN(4,100) THEN h.ehAdetN ELSE 0 END) AS int) Adet, COUNT(DISTINCT h.ehstkID) Cesit
      FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnMrk mrk ON mrk.mrkID=u.urnMrkID
      WHERE h.ehTrhS>='2026-05-01' AND h.ehTrhS<'2026-06-01' AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100)
      GROUP BY CAST(mrk.mrkAd AS nvarchar(80)) ORDER BY Ciro DESC""")]
    # ÜRÜN detayı (kategori başına top 50, irsHrk stkID) — embed → drill server'sız çalışır
    urunler = {}
    # sat=Mayıs satış adet · stok=tüm-zaman net bakiye (current) · devir=12×sat/stok (ölü stok sinyali)
    for r in Q(cur, f"""SELECT kat, kod, ad, sat, ciro, stok FROM (
        SELECT CAST(k.ktgrAd AS nvarchar(50)) kat, u.stkKod kod, CAST(u.stkAd AS nvarchar(70)) ad,
          -SUM(CASE WHEN h.ehTip IN(4,100) AND h.ehTrhS>='2026-05-01' AND h.ehTrhS<'2026-06-01' THEN h.ehAdetN ELSE 0 END) sat,
          CAST(ABS(SUM(CASE WHEN h.ehTip IN(4,100) AND h.ehTrhS>='2026-05-01' AND h.ehTrhS<'2026-06-01' THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) ciro,
          CAST(SUM(h.ehAdetN) AS int) stok,
          ROW_NUMBER() OVER(PARTITION BY CAST(k.ktgrAd AS nvarchar(50)) ORDER BY -SUM(CASE WHEN h.ehTip IN(4,100) AND h.ehTrhS>='2026-05-01' AND h.ehTrhS<'2026-06-01' THEN h.ehAdetN ELSE 0 END) DESC) rn
        FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
        WHERE h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND k.ktgrAd NOT IN {EXC}
        GROUP BY CAST(k.ktgrAd AS nvarchar(50)), u.stkKod, CAST(u.stkAd AS nvarchar(70))) x WHERE rn<=50 AND sat>0"""):
        sat = int(r["sat"]); stok = int(r["stok"] or 0); devir = round(12*sat/stok, 2) if stok > 0 else 0
        urunler.setdefault(r["kat"], []).append([r["kod"], r["ad"], sat, int(r["ciro"] or 0), stok, devir])
    # envanter per-lokasyon (değer güncel + Mayıs ort. adet) — kategori
    LOCS = ["FSM", "Özlüce", "İst.Yolu", "WMS Depo", "Odak Depo"]
    valq = Q(cur, f"""SELECT CAST(KTGR3 AS nvarchar(50)) K,
        CAST(SUM([FSM Stok Maliyet]) AS decimal(18,0)) L0, CAST(SUM([Özlüce Stok Maliyet]) AS decimal(18,0)) L1, CAST(SUM([İst.Yolu Stok Maliyet]) AS decimal(18,0)) L2,
        CAST(SUM([Merkez Depo Stok Maliyet]) AS decimal(18,0)) L3, CAST(SUM([Odak Depo Stok Maliyet]) AS decimal(18,0)) L4
      FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK) WHERE Tarih=(SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU) AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN {EXC} GROUP BY CAST(KTGR3 AS nvarchar(50))""")

    def adetq(dt):
        return {r["K"]: [float(r[c] or 0) for c in ("L0", "L1", "L2", "L3", "L4")] for r in Q(cur, f"""SELECT CAST(KTGR3 AS nvarchar(50)) K,
            SUM(ISNULL([Fsm Stok Adet],0)) L0, SUM(ISNULL([Özlüce Stok Adet],0)) L1, SUM(ISNULL([İst.Yolu Stok Adet],0)) L2,
            SUM(ISNULL([Merkez Depo Stok Adet],0)) L3, SUM(ISNULL([Odak Depo Stok Adet],0)) L4
          FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK) WHERE CAST(Tarih AS date)=%s AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN {EXC} GROUP BY CAST(KTGR3 AS nvarchar(50))""", (dt,))}
    ab, ae = adetq("2026-05-01"), adetq("2026-05-31")
    satmap = {e["k"]: e["sat"] for e in everim}
    envkat = []
    for r in valq:
        k = r["K"]
        v = [float(r[c] or 0) for c in ("L0", "L1", "L2", "L3", "L4")]
        av = [round((ab.get(k, [0]*5)[i] + ae.get(k, [0]*5)[i]) / 2) for i in range(5)]
        envkat.append(dict(k=k, sat=satmap.get(k, 0), v=[round(x) for x in v], a=av))
    # ciro vs envanter payı (kategori, Mayıs 3 mağaza) — CIRO irsHrk'tan (envanterle AYNI kaynak/eşleşme;
    # EncoreMerkez SalesProducts.BarcodeNo↔urn.stkKod join bazı kategorileri (Oyuncak) kaçırıyordu).
    cve_ciro = {r["K"]: int(r["Ciro"] or 0) for r in Q(cur, f"""SELECT CAST(k.ktgrAd AS nvarchar(50)) K,
        CAST(ABS(SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) Ciro
      FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK) JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
      WHERE h.ehTrhS>='2026-05-01' AND h.ehTrhS<'2026-06-01' AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100) AND k.ktgrAd NOT IN {EXC}
      GROUP BY CAST(k.ktgrAd AS nvarchar(50))""")}
    cve = [dict(k=ek["k"], ciro=cve_ciro.get(ek["k"], 0), env=ek["v"][0]+ek["v"][1]+ek["v"][2]) for ek in envkat]
    cve = [c for c in cve if c["env"] > 0 or c["ciro"] > 0]
    cur.close(); conn.close()
    REF = dict(everim=everim, abc=abc, rfm_yk=rfm_yk, rfm_et=rfm_et, marka=marka, envkat=envkat, locs=LOCS, cve=cve, urunler=urunler)
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
    return tmpl


# ============ DEEP DRILL API (canlı sorgu) ============
URUN_SQL = """SELECT TOP 100 u.stkKod kod, CAST(u.stkAd AS nvarchar(80)) ad,
    -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) sat,
    CAST(ABS(SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) ciro,
    CAST(SUM(h.ehAdetN) AS int) bak
  FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
  JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
  WHERE k.ktgrAd=%s AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0
    AND h.ehTrhS<'2026-06-01' AND h.ehstkID IS NOT NULL
  GROUP BY u.stkKod, CAST(u.stkAd AS nvarchar(80))
  HAVING -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)>0
  ORDER BY sat DESC"""

HAR_YK = """SELECT TOP 100 CONVERT(varchar,s.Date,104) tarih, CAST(s.Id AS varchar) kod,
    (SELECT COUNT(*) FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) WHERE sp.SalesId=s.Id AND sp.IsValid=1) adet,
    CAST(s.GrossTotal-s.DiscountTotal AS decimal(18,0)) tutar
  FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK) WHERE s.CustomersId=%s AND s.Date>=DATEADD(DAY,-365,GETDATE())
  ORDER BY s.Date DESC"""


def MUS_YK(seg):
    cond = {"1-Şampiyon": "COUNT(*)>=8 AND DATEDIFF(DAY,MAX(s.Date),%(d)s)<=30",
            "2-Sadık": "COUNT(*)>=4 AND DATEDIFF(DAY,MAX(s.Date),%(d)s)<=90",
            "3-Yeni": "COUNT(*)<=2 AND DATEDIFF(DAY,MAX(s.Date),%(d)s)<=30",
            "4-Risk": "DATEDIFF(DAY,MAX(s.Date),%(d)s) BETWEEN 91 AND 180",
            "5-Kayıp": "DATEDIFF(DAY,MAX(s.Date),%(d)s)>180"}.get(seg, "1=0")
    return """SELECT TOP 100 s.CustomersId id, MAX(CAST(s.CustomerCardNo AS nvarchar(40))) ad, NULL tel,
        COUNT(*) frq, CAST(SUM(s.GrossTotal-s.DiscountTotal) AS decimal(18,0)) mon, DATEDIFF(DAY,MAX(s.Date),%(d)s) rec
      FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
      WHERE s.DocumentsTypeId=1 AND s.CustomersId>0 AND s.Date>=DATEADD(DAY,-365,%(d)s) AND s.Date<DATEADD(DAY,1,%(d)s)
      GROUP BY s.CustomersId HAVING """ + cond + " ORDER BY mon DESC"


def api_query(sql, params):
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"], database=c.get("database", "master"), charset="UTF-8", login_timeout=15, timeout=60)
    cur = conn.cursor(as_dict=True)
    cur.execute(sql, params)
    rows = cur.fetchall()
    cur.close(); conn.close()
    return rows


def serve(port=8000):
    import urllib.parse
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
    html = (OUT / "index.html").read_text(encoding="utf-8")  # önceden üretilmiş — anında sun
    today = date.today().isoformat()
    g2 = (date.today() + timedelta(days=1)).isoformat()

    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _send(self, body, ct="application/json"):
            b = body.encode("utf-8") if isinstance(body, str) else body
            self.send_response(200); self.send_header("Content-Type", ct + "; charset=utf-8")
            self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

        def do_GET(self):
            u = urllib.parse.urlparse(self.path); qs = urllib.parse.parse_qs(u.query)
            try:
                if u.path == "/" or u.path == "/index.html":
                    return self._send(html, "text/html")
                if u.path == "/api/urun":
                    kat = qs.get("kat", [""])[0]
                    rows = api_query(URUN_SQL, (kat,))
                    return self._send(json.dumps([dict(kod=str(r["kod"]), ad=str(r["ad"] or ""), sat=int(r["sat"] or 0), bak=int(r["bak"] or 0), ciro=int(r["ciro"] or 0)) for r in rows], ensure_ascii=False))
                if u.path == "/api/musteri":
                    kanal = qs.get("kanal", ["yk"])[0]; seg = qs.get("seg", [""])[0]
                    if kanal == "yk":
                        rows = api_query(MUS_YK(seg), {"d": today})
                    else:
                        rows = api_query(MUS_ET(seg), {"d": today, "b": (date.today()-timedelta(days=365)).isoformat().replace("-", ""), "g": g2.replace("-", "")})
                    return self._send(json.dumps([dict(id=r["id"], ad=str(r.get("ad") or r["id"]), tel=str(r.get("tel") or ""), frq=int(r["frq"]), mon=int(r["mon"] or 0), rec=int(r["rec"])) for r in rows], ensure_ascii=False))
                if u.path == "/api/hareket":
                    kanal = qs.get("kanal", ["yk"])[0]; cid = qs.get("id", ["0"])[0]
                    if kanal == "yk":
                        rows = api_query(HAR_YK, (int(cid),))
                    else:
                        rows = api_query(HAR_ET, (int(cid),))
                    return self._send(json.dumps([dict(tarih=r["tarih"], kod=str(r.get("kod") or ""), ref=str(r.get("ref") or r.get("kod") or ""), adet=int(r.get("adet") or 0), tutar=int(r["tutar"] or 0)) for r in rows], ensure_ascii=False))
                if u.path == "/api/fis":
                    kanal = qs.get("kanal", ["yk"])[0]; fis = qs.get("fis", ["0"])[0]
                    rows = api_query(FIS_YK if kanal == "yk" else FIS_ET, (int(fis),))
                    return self._send(json.dumps([dict(ad=str(r["ad"] or ""), adet=float(r["adet"] or 0), birim=float(r["birim"] or 0), brut=float(r["brut"] or 0), indirim=float(r["indirim"] or 0), net=float(r["net"] or 0)) for r in rows], ensure_ascii=False))
                self.send_response(404); self.end_headers()
            except Exception as e:
                self._send(json.dumps({"err": str(e)}))

    srv = ThreadingHTTPServer(("0.0.0.0", port), H)
    print(f"GM Dashboard sunucusu: http://localhost:{port}  (Ctrl+C ile durdur)")
    srv.serve_forever()


def MUS_ET(seg):
    cond = {"1-Şampiyon": "COUNT(*)>=5 AND DATEDIFF(DAY,MAX(o.ORDERDATE),%(d)s)<=30",
            "2-Sadık": "COUNT(*)>=3 AND DATEDIFF(DAY,MAX(o.ORDERDATE),%(d)s)<=90",
            "3-Yeni": "COUNT(*)<=2 AND DATEDIFF(DAY,MAX(o.ORDERDATE),%(d)s)<=30",
            "4-Risk": "DATEDIFF(DAY,MAX(o.ORDERDATE),%(d)s) BETWEEN 91 AND 180",
            "5-Kayıp": "DATEDIFF(DAY,MAX(o.ORDERDATE),%(d)s)>180"}.get(seg, "1=0")
    return """SELECT TOP 100 oc.CUSTOMERREF id, MAX(CAST(oc.CMAIL AS nvarchar(80))) ad, MAX(CAST(oc.CPHONE AS nvarchar(30))) tel,
        COUNT(*) frq, CAST(SUM(o.TOTALPRICE) AS decimal(18,0)) mon, DATEDIFF(DAY,MAX(o.ORDERDATE),%(d)s) rec
      FROM ODAKJOKER.JOKER.dbo.J_ORDERS o JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
      WHERE o.ORDERDATE>=%(b)s AND o.ORDERDATE<%(g)s AND oc.CUSTOMERREF>0
      GROUP BY oc.CUSTOMERREF HAVING """ + cond + " ORDER BY mon DESC"


HAR_ET = """SELECT TOP 100 CONVERT(varchar,o.ORDERDATE,104) tarih, o.ORDERCODE kod, o.ORDERID ref, NULL adet,
    CAST(o.TOTALPRICE AS decimal(18,0)) tutar
  FROM ODAKJOKER.JOKER.dbo.J_ORDERS o JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
  WHERE oc.CUSTOMERREF=%s ORDER BY o.ORDERDATE DESC"""

# Fiş/sipariş içi ürün satırları — fiş görünümü (ürün/adet/birim/tutar/indirim/net)
FIS_YK = """SELECT TOP 200 CAST(pr.Name AS nvarchar(60)) ad, CAST(sp.Amount AS decimal(18,2)) adet,
    CAST((sp.TotalPrice+sp.DiscountTotalDirect)/NULLIF(sp.Amount,0) AS decimal(18,2)) birim,
    CAST(sp.TotalPrice+sp.DiscountTotalDirect AS decimal(18,2)) brut,
    CAST(sp.DiscountTotalDirect AS decimal(18,2)) indirim,
    CAST(sp.TotalPrice AS decimal(18,2)) net
  FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
  WHERE sp.SalesId=%s AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'"""
FIS_ET = """SELECT TOP 200 CAST(it.NAME AS nvarchar(60)) ad, d.QUANTITY adet,
    CAST(d.SELLINGPRICEWITHOUTDISCOUNT AS decimal(18,2)) birim,
    CAST(d.QUANTITY*d.SELLINGPRICEWITHOUTDISCOUNT AS decimal(18,2)) brut,
    CAST(d.QUANTITY*(d.SELLINGPRICEWITHOUTDISCOUNT-d.SELLINGPRICE) AS decimal(18,2)) indirim,
    CAST(d.QUANTITY*d.SELLINGPRICE AS decimal(18,2)) net
  FROM ODAKJOKER.JOKER.dbo.J_ORDER_DETAILS d JOIN ODAKJOKER.JOKER.dbo.J_ITEMS it ON it.LOGICALREF=d.ITEMREF
  WHERE d.ORDERREF=%s"""


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
<div id=locbar style="display:flex;gap:14px;flex-wrap:wrap;align-items:center;margin-bottom:10px;font-size:13px">
  <b style="color:#64748b">Lokasyon:</b></div>
<div class=grid>
  <div class="card kpi clk" onclick="detayOlu()"><div class=ct>Envanter Değeri (Ort.Maliyet) &#9656;</div><div class=cv id=env_cv>__ENV__ ₺</div><div class=cm id=env_cm>seçili lokasyon · Dergi/Sınav hariç</div></div>
</div>
<div class=row>
  <div class="panel clk" onclick="detayDevir()"><h3>Devir Hızı — Hızlı (yıllık) &#9656;</h3><table id=tbl_devir>__DEVIR__</table></div>
  <div class="panel clk" onclick="detayOlu()"><h3>Ölü Sermaye — kilitli stok ₺ &#9656;</h3><table id=tbl_olu><tr><td><b>Kategori</b></td><td style="text-align:right"><b>Stok ₺</b></td><td style="text-align:right"><b>Devir</b></td></tr>__DEVIRSLOW__</table></div>
  <div class="panel clk" onclick="detayAbc()"><h3>ABC Analizi (Pareto) &#9656;</h3><table><tr><td><b>Sınıf</b></td><td style="text-align:right"><b>Ürün</b></td><td style="text-align:right"><b>Ciro</b></td></tr>__ABC__</table></div>
  <div class="panel clk" onclick="detayRfm()"><h3>RFM — Yazarkasa (365g) &#9656;</h3><table>__RFM__</table></div>
  <div class="panel clk" onclick="detayMarka()"><h3>Top Marka / Yayınevi (Mayıs) &#9656;</h3><table>__MARKA__</table></div>
</div>
<div class=row>
  <div class="panel clk" onclick="detayCve()" style="grid-column:1/-1"><h3>Ciro Payı vs Envanter Payı — Kategori (Mayıs) &#9656;</h3>
    <canvas id=ch_cve height=90></canvas>
    <div style="font-size:11px;color:#64748b;margin-top:6px">Köşegen (gri) <b>üstü</b> = ciro payı > envanter payı (sermaye-verimli) · <b>altı</b> = fazla stok / ölü sermaye. ▸ tıkla → tablo + ürün.</div></div>
</div>

<details style="margin-top:18px;background:#fff;border-radius:13px;padding:14px 18px;box-shadow:0 2px 8px rgba(0,0,0,.06)">
<summary style="cursor:pointer;font-weight:700;color:__KIRMIZI__;font-size:14px">ℹ️ Terimler & Nasıl Yorumlanır?</summary>
<div style="font-size:13px;line-height:1.9;margin-top:10px;color:#334155">
<b>Dönüşüm Oranı</b> = Fiş ÷ Giriş — mağazaya girenin yüzde kaçı alışveriş yaptı. <i>Yüksek iyi</i> (FSM ~%51 sağlıklı).<br>
<b>Sepet Ort (ATV)</b> = Ciro ÷ Fiş — ortalama fiş tutarı.<br>
<b>UPT</b> = Ürün ÷ Fiş — bir fişte ortalama kaç ürün (sepet derinliği). <i>Düşük = sığ sepet.</i><br>
<b>Devir Hızı</b> = yılda kaç kez stok satılıp yenilendi. <i>Yüksek = hızlı dönen (Dergi/Gıda); düşük = yavaş, sermaye kilitli (Kitap 1,5x).</i><br>
<b>WoS (Weeks of Supply)</b> = mevcut stok kaç haftalık satışa yeter. <i>Yüksek = fazla stok / ölü sermaye</i> (Kitap ~36 hafta).<br>
<b>Sell-through</b> = gelen malın yüzde kaçı satıldı (reorder/indirim kararı). <i>Düşük = yavaş eriyen.</i><br>
<b>GMROI</b> = Brüt marj ÷ Ort. envanter — envantere yatan 1 TL kaç TL marj getirdi. <i>>1 sağlıklı; Kitap 0,03/ay düşük.</i><br>
<b>Ölü Sermaye</b> = yüksek stok değeri + düşük devir = nakde dönmeyen kilitli para (210M ₺'nin %30'u Kitap'ta).<br>
<b>ABC (Pareto)</b> = ürünleri ciroya göre sınıfla: <b>A</b> ilk %80 ciroyu yapan az ürün · <b>C</b> uzun kuyruk (%5 ciro, clearance adayı).<br>
<b>RFM</b> = Recency (son alış ne kadar yeni) · Frequency (ne sıklıkla alıyor) · Monetary (ne kadar harcıyor) — müşteri sadakat segmenti.<br>
<b>SPLH</b> = Ciro ÷ çalışılan saat — işgücü verimi (Özlüce 3.786 ₺/saat).<br>
<b>İade Oranı</b> = İade ÷ Satış — yüksek = kalite/operasyon sinyali.<br>
<b>MTD</b> = Month-to-Date (ay başından bugüne kümülatif) · <b>WoW</b> = geçen haftaya göre · <b>YoY</b> = geçen yıla göre.
</div></details>
<div class=foot>BKM Kitap · GM Dashboard (otomatik) · scripts/gm_dashboard.py · veriyi yenile: python gm_dashboard.py · sunucu: --serve</div>
<script>
const DATA=__DATA__;
const REF=__REF__;
const KP='__KIRMIZI__';
const fnum=n=>Math.round(n).toLocaleString('tr-TR');
async function api(p){const r=await fetch('/api/'+p);return await r.json();}
function loading(t){openModal('<h2>'+t+'</h2><div style="padding:20px;color:#64748b">yükleniyor…</div>');}
function detayUrun(katEnc){let kat=decodeURIComponent(katEnc);let d=(REF.urunler&&REF.urunler[kat])||[];
  if(!d.length){openModal('<h2>'+kat+' — Ürünler</h2><div style="padding:16px;color:#64748b">Bu kategoride satış kaydı yok.</div>');return;}
  let rows=d.map(x=>{let dev=x[5]||0,st=x[4]||0;let dc=dev<=0?'#94a3b8':(dev<1.5?'#dc2626':(dev>=4?'#16a34a':'#0f172a'));
    return '<tr><td>'+x[0]+'</td><td>'+x[1]+'</td><td style="text-align:right">'+fnum(x[2])+'</td><td style="text-align:right">'+fnum(st)+'</td><td style="text-align:right;color:#64748b;font-size:11px">12×'+fnum(x[2])+'÷'+fnum(st)+'</td><td style="text-align:right;font-weight:bold;color:'+dc+'">'+(dev>0?dev.toFixed(2)+'x':'—')+'</td><td style="text-align:right">'+tl(x[3])+'</td></tr>';}).join('');
  openModal('<h2>'+kat+' — Ürünler</h2><div style="color:#64748b;font-size:12px">Mayıs · satılan adet sıralı (top 50) · <b>Devir = 12 × Satılan(ay) ÷ Stok</b> · &lt;1,5x kırmızı = ölü stok adayı</div><table style="margin-top:10px"><tr><td><b>Stok Kod</b></td><td><b>Ürün</b></td><td style="text-align:right"><b>Satılan/ay</b></td><td style="text-align:right"><b>Stok</b></td><td style="text-align:right"><b>Hesap</b></td><td style="text-align:right"><b>Devir/yıl</b></td><td style="text-align:right"><b>Ciro</b></td></tr>'+rows+'</table>');}
async function detayMusteri(kanal,segEnc){loading('Müşteri Listesi');let seg=decodeURIComponent(segEnc);let d=await api('musteri?kanal='+kanal+'&seg='+segEnc);
  let rows=d.map(x=>'<tr style="cursor:pointer" onclick="detaySiparis(\''+kanal+'\',\''+x.id+'\',\''+encodeURIComponent(x.ad)+'\')"><td>'+x.ad+' &#9656;</td><td>'+(x.tel||'')+'</td><td style="text-align:right">'+fnum(x.frq)+'</td><td style="text-align:right">'+tl(x.mon)+'</td><td style="text-align:right">'+x.rec+' gün</td></tr>').join('');
  openModal('<h2>'+seg+' — '+(kanal=='yk'?'Yazarkasa':'E-ticaret')+'</h2><div style="color:#64748b;font-size:12px">365 gün · monetary sıralı (top 100) · ▸ tıkla → sipariş/fiş</div><table style="margin-top:10px"><tr><td><b>Müşteri</b></td><td><b>Tel</b></td><td style="text-align:right"><b>Adet</b></td><td style="text-align:right"><b>Ciro</b></td><td style="text-align:right"><b>Son</b></td></tr>'+rows+'</table>');}
async function detaySiparis(kanal,id,adEnc){loading('Hareketler');let ad=decodeURIComponent(adEnc);let d=await api('hareket?kanal='+kanal+'&id='+id);
  let rows=d.map(x=>'<tr style="cursor:pointer" onclick="detayFis(\''+kanal+'\',\''+x.ref+'\',\''+x.tarih+'\')"><td>'+x.tarih+'</td><td>'+(x.kod||'')+' &#9656;</td><td style="text-align:right">'+fnum(x.adet)+'</td><td style="text-align:right">'+tl(x.tutar)+'</td></tr>').join('');
  openModal('<h2>'+ad+'</h2><div style="color:#64748b;font-size:12px">'+(kanal=='yk'?'fiş':'sipariş')+' geçmişi (365 gün, top 100) · ▸ tıkla → fiş içeriği</div><table style="margin-top:10px"><tr><td><b>Tarih</b></td><td><b>'+(kanal=='yk'?'Fiş':'Sipariş')+'</b></td><td style="text-align:right"><b>Kalem</b></td><td style="text-align:right"><b>Tutar</b></td></tr>'+rows+'</table>');}
async function detayFis(kanal,ref,tarih){loading('Fiş İçeriği');let d=await api('fis?kanal='+kanal+'&fis='+ref);
  if(!d.length){openModal('<h2>'+(kanal=='yk'?'Fiş':'Sipariş')+' #'+ref+'</h2><div style="padding:16px;color:#64748b">İçerik bulunamadı.</div>');return;}
  let mny=n=>n.toLocaleString('tr-TR',{minimumFractionDigits:2,maximumFractionDigits:2});
  let adt=n=>Number.isInteger(n)?fnum(n):n.toLocaleString('tr-TR',{maximumFractionDigits:2});
  let bT=d.reduce((a,b)=>a+b.brut,0),iT=d.reduce((a,b)=>a+b.indirim,0),nT=d.reduce((a,b)=>a+b.net,0);
  let rows=d.map(x=>'<tr><td>'+x.ad+'</td><td style="text-align:right">'+adt(x.adet)+'</td><td style="text-align:right">'+mny(x.birim)+'</td><td style="text-align:right">'+mny(x.brut)+'</td><td style="text-align:right;color:'+(x.indirim>0?'#dc2626':'#94a3b8')+'">'+(x.indirim>0?'-'+mny(x.indirim):'—')+'</td><td style="text-align:right;font-weight:600">'+mny(x.net)+'</td></tr>').join('');
  let foot='<tr style="border-top:2px solid '+KP+';font-weight:700"><td colspan=3>DİP TOPLAM ('+d.length+' kalem)</td><td style="text-align:right">'+mny(bT)+'</td><td style="text-align:right;color:#dc2626">'+(iT>0?'-'+mny(iT):'—')+'</td><td style="text-align:right;font-size:15px;color:'+KP+'">'+mny(nT)+' ₺</td></tr>';
  openModal('<h2>'+(kanal=='yk'?'Fiş':'Sipariş')+' #'+ref+'</h2><div style="color:#64748b;font-size:12px">'+tarih+' · '+(kanal=='yk'?'Yazarkasa':'E-ticaret')+' · birim fiyat × adet = tutar, indirim sonrası net</div><table style="margin-top:10px"><tr><td><b>Ürün</b></td><td style="text-align:right"><b>Adet</b></td><td style="text-align:right"><b>Birim ₺</b></td><td style="text-align:right"><b>Tutar ₺</b></td><td style="text-align:right"><b>İndirim</b></td><td style="text-align:right"><b>Net ₺</b></td></tr>'+rows+foot+'</table>');}
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
let SEL=[true,true,true,true,true];
const STMAP={}; REF.everim.forEach(e=>STMAP[e.k]=e.st);
function sumSel(arr){let s=0;for(let i=0;i<5;i++)if(SEL[i])s+=arr[i];return s;}
function envCats(){return REF.envkat.map(c=>{let v=sumSel(c.v),a=sumSel(c.a);return {k:c.k,v:v,a:a,sat:c.sat,devir:a>0?12*c.sat/a:0,wos:(a>0&&c.sat)?a*52/12/c.sat:null,st:STMAP[c.k]};});}
function locLabel(){return SEL.map((b,i)=>b?REF.locs[i]:null).filter(x=>x).join(', ')||'(hiç)';}
function renderEnv(){let cats=envCats();let tot=cats.reduce((x,y)=>x+y.v,0);
  document.getElementById('env_cv').textContent=tl(tot)+' ₺';
  document.getElementById('env_cm').textContent=locLabel()+' · Dergi/Sınav hariç';
  let dv=cats.filter(c=>c.a>0).sort((a,b)=>b.devir-a.devir);
  document.getElementById('tbl_devir').innerHTML=dv.slice(0,5).map(c=>'<tr><td>'+c.k+'</td><td style="text-align:right">'+c.devir.toFixed(2)+'x</td></tr>').join('');
  let ol=cats.slice().sort((a,b)=>b.v-a.v);
  document.getElementById('tbl_olu').innerHTML='<tr><td><b>Kategori</b></td><td style="text-align:right"><b>Stok ₺</b></td><td style="text-align:right"><b>Devir</b></td></tr>'+ol.slice(0,5).map(c=>'<tr><td>'+c.k+'</td><td style="text-align:right">'+tl(c.v)+'</td><td style="text-align:right;color:'+(c.devir<1.5?'#dc2626':'#16a34a')+'">'+c.devir.toFixed(2)+'x</td></tr>').join('');}
(function(){let h='<b style="color:#64748b">Lokasyon:</b>';REF.locs.forEach((l,i)=>{h+=' <label style="cursor:pointer"><input type=checkbox checked onchange="SEL['+i+']=this.checked;renderEnv()"> '+l+'</label>';});document.getElementById('locbar').innerHTML=h;})();
function detayDevir(){let e=envCats().filter(c=>c.a>0).sort((a,b)=>b.devir-a.devir);
  let rows=e.map(x=>'<tr><td>'+x.k+'</td><td style="text-align:right">'+fnum(Math.round(x.sat))+'</td><td style="text-align:right">'+fnum(Math.round(x.a))+'</td><td style="text-align:right;color:#64748b;font-size:11px">12×'+fnum(Math.round(x.sat))+'÷'+fnum(Math.round(x.a))+'</td><td style="text-align:right;font-weight:bold;color:'+(x.devir<1.5?'#dc2626':'#16a34a')+'">'+x.devir.toFixed(2)+'x</td><td style="text-align:right">'+(x.wos?x.wos.toFixed(0)+' hf':'—')+'</td><td style="text-align:right">'+(x.st!=null?'%'+x.st:'—')+'</td><td style="text-align:right">'+tl(x.v)+'</td><td style="text-align:center;color:'+KP+';cursor:pointer" onclick="detayUrun(\''+encodeURIComponent(x.k)+'\')">&#9656;</td></tr>').join('');
  openModal('<h2>Envanter Verim — Kategori</h2><div style="color:#64748b;font-size:12px">Mayıs · '+locLabel()+' · <b>Devir = 12 × Satılan(ay) ÷ Ort Stok adet</b> · ▸ → ürün detayı</div><table style="margin-top:10px"><tr><td><b>Kategori</b></td><td style="text-align:right"><b>Satılan/ay</b></td><td style="text-align:right"><b>Ort Stok adet</b></td><td style="text-align:right"><b>Hesap</b></td><td style="text-align:right"><b>Devir/yıl</b></td><td style="text-align:right"><b>WoS</b></td><td style="text-align:right"><b>Sell-thr.</b></td><td style="text-align:right"><b>Stok ₺</b></td><td></td></tr>'+rows+'</table>');}
function detayOlu(){let e=envCats().sort((a,b)=>b.v-a.v);let tot=e.reduce((a,b)=>a+b.v,0);
  let rows=e.map(x=>'<tr><td>'+x.k+'</td><td style="text-align:right">'+tl(x.v)+'</td><td style="text-align:right;color:#64748b">%'+(tot?(100*x.v/tot).toFixed(0):0)+'</td><td style="text-align:right">'+fnum(Math.round(x.sat))+'</td><td style="text-align:right">'+fnum(Math.round(x.a))+'</td><td style="text-align:right;color:#64748b;font-size:11px">12×'+fnum(Math.round(x.sat))+'÷'+fnum(Math.round(x.a))+'</td><td style="text-align:right;font-weight:bold;color:'+(x.devir<1.5?'#dc2626':'#16a34a')+'">'+x.devir.toFixed(2)+'x</td><td style="text-align:center;color:'+KP+';cursor:pointer" onclick="detayUrun(\''+encodeURIComponent(x.k)+'\')">&#9656;</td></tr>').join('');
  openModal('<h2>Ölü Sermaye — Kilitli Stok</h2><div style="color:#64748b;font-size:12px">'+locLabel()+' · devir &lt;1,5x kırmızı · <b>Devir = 12 × Satılan(ay) ÷ Ort Stok</b> · ▸ ürün. Toplam '+tl(tot)+' ₺</div><table style="margin-top:10px"><tr><td><b>Kategori</b></td><td style="text-align:right"><b>Stok ₺</b></td><td style="text-align:right"><b>Pay</b></td><td style="text-align:right"><b>Satılan/ay</b></td><td style="text-align:right"><b>Ort Stok adet</b></td><td style="text-align:right"><b>Hesap</b></td><td style="text-align:right"><b>Devir</b></td><td></td></tr>'+rows+'</table>');}
function detayAbc(){let a=REF.abc;let tn=0,tc=0;for(const k of['A','B','C'])if(a[k]){tn+=a[k].n;tc+=a[k].ciro;}
  let rows=['A','B','C'].filter(k=>a[k]).map(k=>'<tr><td><b>'+k+'</b></td><td style="text-align:right">'+fnum(a[k].n)+'</td><td style="text-align:right">%'+(100*a[k].n/tn).toFixed(0)+'</td><td style="text-align:right">'+tl(a[k].ciro)+'</td><td style="text-align:right">%'+(100*a[k].ciro/tc).toFixed(0)+'</td></tr>').join('');
  openModal('<h2>ABC Analizi (Pareto 80/20)</h2><div style="color:#64748b;font-size:12px">Mayıs · A=ilk %80 ciro · C=uzun kuyruk (clearance adayı)</div><table style="margin-top:10px"><tr><td><b>Sınıf</b></td><td style="text-align:right"><b>Ürün</b></td><td style="text-align:right"><b>SKU %</b></td><td style="text-align:right"><b>Ciro</b></td><td style="text-align:right"><b>Ciro %</b></td></tr>'+rows+'</table>');}
function detayRfm(){function t(arr,kanal){return arr.map(x=>'<tr style="cursor:pointer" onclick="detayMusteri(\''+kanal+'\',\''+encodeURIComponent(x[0])+'\')"><td>'+x[0]+' &#9656;</td><td style="text-align:right">'+fnum(x[1])+'</td><td style="text-align:right">'+tl(x[2])+'</td></tr>').join('');}
  let kosul='<div style="background:#f8fafc;border-radius:10px;padding:10px 12px;margin:8px 0;font-size:12px;line-height:1.7">'+
    '<b>Segment koşulları</b> (R=son alıştan bu yana gün, F=alışveriş sayısı):<br>'+
    '🏆 <b>Şampiyon</b>: çok sık + çok yeni (yazarkasa F≥8 & R≤30 gün · e-ticaret F≥5 & R≤30)<br>'+
    '💚 <b>Sadık</b>: sık + yakın (yazarkasa F≥4 & R≤90 · e-ticaret F≥3 & R≤90)<br>'+
    '🌱 <b>Yeni/Gelişen</b>: az alışveriş ama çok yeni (F≤2 & R≤30)<br>'+
    '⚠️ <b>Risk Altında</b>: 91-180 gündür gelmemiş (kaçmak üzere)<br>'+
    '💀 <b>Kayıp</b>: 180+ gündür gelmemiş (reaktivasyon hedefi)</div>';
  openModal('<h2>RFM Müşteri Segmentasyonu</h2><div style="color:#64748b;font-size:12px">RFM = <b>R</b>ecency (son alış) · <b>F</b>requency (sıklık) · <b>M</b>onetary (harcama). 365 gün · iki ayrı evren · ▸ segment tıkla → müşteri → fiş/sipariş</div>'+kosul+
   '<h3 style="font-size:13px;margin:10px 0 4px">Yazarkasa (sadakat kartı)</h3><table><tr><td><b>Segment</b></td><td style="text-align:right"><b>Müşteri</b></td><td style="text-align:right"><b>Ciro</b></td></tr>'+t(REF.rfm_yk,'yk')+'</table>'+
   '<h3 style="font-size:13px;margin:14px 0 4px">E-ticaret (JOKER)</h3><table><tr><td><b>Segment</b></td><td style="text-align:right"><b>Müşteri</b></td><td style="text-align:right"><b>Ciro</b></td></tr>'+t(REF.rfm_et,'et')+'</table>');}
function detayMarka(){let rows=REF.marka.map((x,i)=>'<tr><td>'+(i+1)+'. '+x[0]+'</td><td style="text-align:right">'+tl(x[1])+'</td><td style="text-align:right">'+fnum(x[2])+'</td><td style="text-align:right">'+fnum(x[3])+'</td><td style="text-align:right">'+tl(x[1]/x[3])+'</td></tr>').join('');
  openModal('<h2>Marka / Yayınevi — Top 20</h2><div style="color:#64748b;font-size:12px">Mayıs · ciro/çeşit = yoğunluk (dar+güçlü vs geniş+uzun kuyruk)</div><table style="margin-top:10px"><tr><td><b>Marka</b></td><td style="text-align:right"><b>Ciro</b></td><td style="text-align:right"><b>Adet</b></td><td style="text-align:right"><b>Çeşit</b></td><td style="text-align:right"><b>₺/Çeşit</b></td></tr>'+rows+'</table>');}
function detayCve(){let T=REF.cve.map(c=>Object.assign({},c));let tc=T.reduce((a,b)=>a+b.ciro,0),te=T.reduce((a,b)=>a+b.env,0);
  T.forEach(c=>{c.cp=tc?100*c.ciro/tc:0;c.ep=te?100*c.env/te:0;c.oran=c.env?c.ciro/c.env:0;});
  T.sort((a,b)=>b.oran-a.oran);
  let rows=T.map(c=>'<tr><td>'+c.k+'</td><td style="text-align:right">'+tl(c.ciro)+'</td><td style="text-align:right">%'+c.cp.toFixed(1)+'</td><td style="text-align:right">'+tl(c.env)+'</td><td style="text-align:right">%'+c.ep.toFixed(1)+'</td><td style="text-align:right;color:'+(c.oran>=0.2?'#16a34a':(c.oran<0.05?'#dc2626':'#64748b'))+'">'+c.oran.toFixed(2)+'</td><td style="text-align:center;color:'+KP+';cursor:pointer" onclick="detayUrun(\''+encodeURIComponent(c.k)+'\')">&#9656;</td></tr>').join('');
  openModal('<h2>Ciro Payı vs Envanter Payı</h2><div style="color:#64748b;font-size:12px">Mayıs · <b>Ciro/Env</b> = aylık ciro ÷ envanter değeri (yeşil ≥0,2 verimli · kırmızı &lt;0,05 fazla stok) · ▸ ürün</div><table style="margin-top:10px"><tr><td><b>Kategori</b></td><td style="text-align:right"><b>Ciro</b></td><td style="text-align:right"><b>Ciro %</b></td><td style="text-align:right"><b>Envanter</b></td><td style="text-align:right"><b>Env %</b></td><td style="text-align:right"><b>Ciro/Env</b></td><td></td></tr>'+rows+'</table>');}
(function(){let T=REF.cve;let tc=T.reduce((a,b)=>a+b.ciro,0),te=T.reduce((a,b)=>a+b.env,0);if(!tc||!te)return;
  let pts=T.map(c=>({x:100*c.env/te,y:100*c.ciro/tc,k:c.k}));let mx=Math.max(...pts.map(p=>Math.max(p.x,p.y)))*1.1;
  new Chart(document.getElementById('ch_cve'),{data:{datasets:[
    {type:'scatter',data:pts,backgroundColor:KP,pointRadius:6,pointHoverRadius:8},
    {type:'line',data:[{x:0,y:0},{x:mx,y:mx}],borderColor:'#cbd5e1',borderDash:[6,5],pointRadius:0,fill:false}
  ]},options:{plugins:{legend:{display:false},tooltip:{callbacks:{label:c=>c.raw.k?c.raw.k+' — ciro %'+c.raw.y.toFixed(1)+' / env %'+c.raw.x.toFixed(1):''}}},scales:{x:{title:{display:true,text:'Envanter Payı %'},min:0,max:mx},y:{title:{display:true,text:'Ciro Payı %'},min:0,max:mx}}}});})();
render('gunluk'); renderEnv();
</script></body></html>"""


if __name__ == "__main__":
    main()
