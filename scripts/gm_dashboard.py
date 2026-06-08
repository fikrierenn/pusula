"""
GM DASHBOARD — tek sayfa HTML (canlı veri).

GM rapor sisteminin görsel panosu: birleşik günlük ciro (fiziksel+online),
mağaza kartları, e-ticaret kanal, FSM dönüşüm (kapı sayıcı), envanter, 7-gün trend.
Çıktı: briefings/gm-dashboard/index.html (self-contained, Chart.js CDN).

Kullanım: python gm_dashboard.py [--date YYYY-MM-DD]   (default: dün)
DB: .env / .secrets/db.json (generate_brief.py ile aynı).
"""
import sys, csv, json, os, argparse
from pathlib import Path
from datetime import date, timedelta, datetime
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pymssql

R = Path(__file__).resolve().parent.parent
OUT = R / "briefings" / "gm-dashboard"
KIRMIZI = "#E30622"
MEKAN = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu"}


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


def tl(n):
    return f"{n:,.0f}".replace(",", ".") + " ₺"


def q(cur, sql, p=None):
    cur.execute(sql, p or ())
    return cur.fetchall()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--date")
    a = ap.parse_args()
    gun = a.date or (date.today() - timedelta(days=1)).isoformat()
    g2 = (date.fromisoformat(gun) + timedelta(days=1)).isoformat()
    giso = gun.replace("-", "")
    g2iso = g2.replace("-", "")
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"],
                           database=c.get("database", "master"), login_timeout=20, timeout=90)
    cur = conn.cursor(as_dict=True)

    # mağaza günlük (G1) + MTD
    aybas = gun[:8] + "01"
    store = q(cur, """SELECT MG.mekanID,
        SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) NetCiro,
        SUM(IIF(s.DocumentsTypeId=3,-1,1)) Fis
      FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
      JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
      JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
      LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
      WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=%s AND s.Date<%s
      GROUP BY MG.mekanID""", (gun, g2))
    mtd = q(cur, """SELECT MG.mekanID, SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) Net
      FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
      JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
      JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
      LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
      WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=%s AND s.Date<%s
      GROUP BY MG.mekanID""", (aybas, g2))
    hedef = q(cur, "SELECT mekanId, SUM(hedef) H FROM BKMDATA.dbo.Hedef WITH(NOLOCK) WHERE mekanId IN (1,4477,4478) AND tarih>=%s AND tarih<%s GROUP BY mekanId", (aybas, g2))
    # 7 gün trend (fiziksel)
    trend = q(cur, """SELECT CONVERT(varchar,s.Date,23) T, SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) Net
      FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
      LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
      WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=DATEADD(DAY,-6,%s) AND s.Date<%s
      GROUP BY CONVERT(varchar,s.Date,23)""", (gun, g2))
    # e-ticaret kanal
    eticaret = q(cur, "SELECT o.APPLICATION K, COUNT(*) Sip, SUM(o.TOTALPRICE) Ciro FROM ODAKJOKER.JOKER.dbo.J_ORDERS o WHERE o.ORDERDATE>=%s AND o.ORDERDATE<%s GROUP BY o.APPLICATION", (giso, g2iso))
    # envanter (Ort.Maliyet, Dergi/Sınav hariç)
    env = q(cur, """SELECT CAST(SUM([FSM Stok Maliyet]+[Özlüce Stok Maliyet]+[İst.Yolu Stok Maliyet]+[Merkez Depo Stok Maliyet]+[Odak Depo Stok Maliyet]) AS decimal(18,0)) T
      FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
      WHERE Tarih=(SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU) AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN (N'Sınav Okulları',N'Dergi')""")
    cur.close(); conn.close()

    # FSM dönüşüm (kapı sayıcı CSV)
    traf = {}
    tp = R / "sayiyo" / "fsm_gunluk_trafik.csv"
    if tp.exists():
        for r in csv.DictReader(open(tp, encoding="utf-8")):
            traf[r["Tarih"]] = int(r["Giris"])
    fsm_fis = next((int(s["Fis"]) for s in store if s["mekanID"] == 1), 0)
    giris = traf.get(gun)
    donusum = (100 * fsm_fis / giris) if giris else None

    # hesap
    smap = {s["mekanID"]: s for s in store}
    mmap = {m["mekanID"]: float(m["Net"] or 0) for m in mtd}
    hmap = {h["mekanId"]: float(h["H"] or 0) for h in hedef}
    fiz_net = sum(float(s["NetCiro"] or 0) for s in store)
    fiz_fis = sum(int(s["Fis"]) for s in store)
    et_ciro = sum(float(e["Ciro"] or 0) for e in eticaret)
    et_sip = sum(int(e["Sip"]) for e in eticaret)
    toplam = fiz_net + et_ciro
    env_tl = float(env[0]["T"]) if env and env[0]["T"] else 0

    GUN_TR = {0:"Pzt",1:"Sal",2:"Çar",3:"Per",4:"Cum",5:"Cmt",6:"Pzr"}
    dt = date.fromisoformat(gun)
    baslik_tarih = dt.strftime("%d.%m.%Y") + " " + GUN_TR[dt.weekday()]

    # kartlar
    store_cards = ""
    for mid in (4477, 1, 4478):
        s = smap.get(mid);
        if not s: continue
        net = float(s["NetCiro"] or 0); fis = int(s["Fis"]); atv = net/fis if fis else 0
        ger = 100*mmap.get(mid,0)/hmap[mid] if hmap.get(mid) else 0
        renk = "#16a34a" if ger>=100 else ("#dc2626" if ger<95 else "#64748b")
        store_cards += f"""<div class=card><div class=ct>{MEKAN[mid]}</div>
          <div class=cv>{tl(net)}</div>
          <div class=cm>{fis:,} fiş · sepet {atv:,.0f} ₺</div>
          <div class=cm>MTD hedef <b style="color:{renk}">%{ger:.1f}</b></div></div>""".replace(",", ".")

    et_rows = "".join(f"<tr><td>{e['K']}</td><td style='text-align:right'>{int(e['Sip']):,}</td><td style='text-align:right'>{tl(float(e['Ciro'] or 0))}</td></tr>".replace(",",".") for e in sorted(eticaret,key=lambda x:-float(x['Ciro'] or 0)))
    trend_s = sorted(trend, key=lambda x: x["T"])
    trend_lbl = json.dumps([t["T"][5:] for t in trend_s])
    trend_val = json.dumps([round(float(t["Net"] or 0)) for t in trend_s])
    et_lbl = json.dumps([e["K"].replace("Mobil Uygulama ","").replace("(","").replace(")","") for e in sorted(eticaret,key=lambda x:-float(x['Ciro'] or 0))])
    et_val = json.dumps([round(float(e["Ciro"] or 0)) for e in sorted(eticaret,key=lambda x:-float(x['Ciro'] or 0))])
    don_txt = f"%{donusum:.1f}" if donusum else "—"

    html = f"""<!doctype html><html lang=tr><head><meta charset=utf-8>
<meta name=viewport content="width=device-width,initial-scale=1">
<title>BKM GM Dashboard — {baslik_tarih}</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>
*{{box-sizing:border-box;margin:0;font-family:'Segoe UI',system-ui,sans-serif}}
body{{background:#f1f5f9;color:#0f172a;padding:20px}}
.hd{{display:flex;align-items:center;gap:14px;margin-bottom:18px}}
.hd .logo{{background:{KIRMIZI};color:#fff;font-weight:800;padding:8px 14px;border-radius:10px;font-size:20px;letter-spacing:1px}}
.hd h1{{font-size:20px}} .hd .tar{{margin-left:auto;color:#64748b;font-size:14px}}
.big{{background:linear-gradient(135deg,{KIRMIZI},#b00518);color:#fff;border-radius:16px;padding:22px 26px;display:flex;gap:40px;align-items:center;flex-wrap:wrap;margin-bottom:16px;box-shadow:0 6px 20px rgba(227,6,34,.25)}}
.big .lbl{{opacity:.85;font-size:13px;text-transform:uppercase;letter-spacing:1px}}
.big .num{{font-size:38px;font-weight:800;line-height:1.1}}
.big .sub{{font-size:14px;opacity:.9}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:14px;margin-bottom:16px}}
.card{{background:#fff;border-radius:14px;padding:16px 18px;box-shadow:0 2px 8px rgba(0,0,0,.06)}}
.card.kpi{{border-left:5px solid {KIRMIZI}}}
.ct{{font-size:12px;color:#64748b;text-transform:uppercase;letter-spacing:.5px;font-weight:700}}
.cv{{font-size:26px;font-weight:800;margin:4px 0}} .cm{{font-size:13px;color:#475569}}
.row{{display:grid;grid-template-columns:1fr 1fr;gap:14px}}
@media(max-width:780px){{.row{{grid-template-columns:1fr}}}}
.panel{{background:#fff;border-radius:14px;padding:16px 18px;box-shadow:0 2px 8px rgba(0,0,0,.06)}}
.panel h3{{font-size:14px;margin-bottom:12px;color:#334155}}
table{{width:100%;border-collapse:collapse;font-size:14px}} td{{padding:6px 4px;border-bottom:1px solid #f1f5f9}}
.foot{{color:#94a3b8;font-size:12px;text-align:center;margin-top:18px}}
.gauge{{font-size:34px;font-weight:800;color:{KIRMIZI}}}
</style></head><body>
<div class=hd><span class=logo>bkmkitap</span><h1>Genel Müdür Panosu</h1><span class=tar>{baslik_tarih} · kapanış</span></div>

<div class=big>
  <div><div class=lbl>Toplam Ciro (fiziksel + online)</div><div class=num>{tl(toplam)}</div>
    <div class=sub>Fiziksel {tl(fiz_net)} · E-ticaret {tl(et_ciro)} (%{100*et_ciro/toplam if toplam else 0:.0f})</div></div>
  <div><div class=lbl>İşlem</div><div class=num>{fiz_fis+et_sip:,}</div><div class=sub>{fiz_fis:,} fiş · {et_sip:,} sipariş</div></div>
  <div><div class=lbl>FSM Dönüşüm (kapı sayıcı)</div><div class=num>{don_txt}</div><div class=sub>{(str(giris)+' giriş') if giris else 'veri yok'}</div></div>
</div>

<div class=grid>{store_cards}
  <div class="card kpi"><div class=ct>Envanter Değeri (Ort.Maliyet)</div><div class=cv>{tl(env_tl)}</div><div class=cm>Dergi/Sınav hariç</div></div>
</div>

<div class=row>
  <div class=panel><h3>Son 7 Gün — Fiziksel Net Ciro</h3><canvas id=trend height=140></canvas></div>
  <div class=panel><h3>E-ticaret Kanal Dağılımı</h3><canvas id=etc height=140></canvas>
    <table style="margin-top:10px"><tr><td><b>Kanal</b></td><td style="text-align:right"><b>Sipariş</b></td><td style="text-align:right"><b>Ciro</b></td></tr>{et_rows}</table></div>
</div>

<div class=foot>BKM Kitap · GM Dashboard (otomatik) · scripts/gm_dashboard.py · {datetime_now()}</div>
<script>
new Chart(document.getElementById('trend'),{{type:'line',data:{{labels:{trend_lbl},datasets:[{{data:{trend_val},borderColor:'{KIRMIZI}',backgroundColor:'rgba(227,6,34,.1)',fill:true,tension:.3}}]}},options:{{plugins:{{legend:{{display:false}}}},scales:{{y:{{ticks:{{callback:v=>(v/1000000).toFixed(1)+'M'}}}}}}}}}});
new Chart(document.getElementById('etc'),{{type:'doughnut',data:{{labels:{et_lbl},datasets:[{{data:{et_val},backgroundColor:['{KIRMIZI}','#f59e0b','#0ea5e9','#64748b']}}]}},options:{{plugins:{{legend:{{position:'right'}}}}}}}});
</script></body></html>"""

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "index.html").write_text(html, encoding="utf-8")
    print(f"Dashboard: {OUT/'index.html'}")
    print(f"  Toplam {tl(toplam)} (fiziksel {tl(fiz_net)} + online {tl(et_ciro)}) · FSM dönüşüm {don_txt}")


def datetime_now():
    return datetime.now().strftime("%d.%m.%Y %H:%M") if False else "üretildi"


if __name__ == "__main__":
    main()
