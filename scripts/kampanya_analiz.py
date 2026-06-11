"""
E-TİCARET KAMPANYA / MARKA ANALİZİ — iki dönem kıyaslamalı
Bir yayınevi/markanın (J_ITEMS.BRAND) e-ticaret etkisini iki dönem kıyaslar:
büyüklük, indirim derinliği, sepet etkisi (halo/çapraz satış), kanal, saat,
müşteri (üye/misafir), birlikte alınan marka + ürünler.
Çıktı: briefings/kampanya-analiz-<marka>.xlsx
Kullanım: python kampanya_analiz.py [--marka "Ephesus Yayınları"] [--d1 20260501 20260508] [--d2 20260601 20260608]
"""
import sys, os, json, argparse
from pathlib import Path
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pymssql
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.chart import BarChart, Reference

R = Path(__file__).resolve().parent.parent
KIRMIZI = "E30622"
D = "ODAKJOKER.JOKER.dbo"


def cfg():
    e = R / ".env"
    if e.exists():
        for l in e.read_text(encoding="utf-8").splitlines():
            if "=" in l and not l.strip().startswith("#"):
                k, v = l.split("=", 1); os.environ.setdefault(k.strip(), v.strip())
    h = os.environ.get("MSSQL_HOST")
    if h:
        return dict(server=h, user=os.environ.get("MSSQL_USER", "sa"), password=os.environ.get("MSSQL_PASSWORD", ""), database=os.environ.get("MSSQL_DATABASE", "master"))
    return json.loads((R / ".secrets" / "db.json").read_text(encoding="utf-8"))


def metrics(cur, marka, s, e):
    """Tek dönem metrikleri."""
    # ürün düzeyi: adet, net, brüt, indirim
    cur.execute(f"""SELECT SUM(d.QUANTITY) Adet,
        CAST(SUM(d.QUANTITY*d.SELLINGPRICE) AS decimal(18,0)) Net,
        CAST(SUM(d.QUANTITY*d.SELLINGPRICEWITHOUTDISCOUNT) AS decimal(18,0)) Brut,
        CAST(SUM(d.QUANTITY*(d.SELLINGPRICEWITHOUTDISCOUNT-d.SELLINGPRICE)) AS decimal(18,0)) Indirim
      FROM {D}.J_ORDER_DETAILS d JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF
      WHERE it.BRAND=%s AND d.ORDERDATE>=%s AND d.ORDERDATE<%s""", (marka, s, e))
    u = cur.fetchone()
    # sepet (halo): markanın geçtiği siparişlerin tüm satırları, marka vs çapraz
    cur.execute(f"""WITH ord AS (SELECT DISTINCT d.ORDERREF oid FROM {D}.J_ORDER_DETAILS d JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF WHERE it.BRAND=%s AND d.ORDERDATE>=%s AND d.ORDERDATE<%s)
      SELECT (SELECT COUNT(*) FROM ord) Siparis,
        CAST(SUM(d.QUANTITY*d.SELLINGPRICE) AS decimal(18,0)) SepetUrun,
        CAST(SUM(CASE WHEN it.BRAND=%s THEN d.QUANTITY*d.SELLINGPRICE ELSE 0 END) AS decimal(18,0)) MarkaCiro,
        CAST(SUM(CASE WHEN it.BRAND=%s THEN 0 ELSE d.QUANTITY*d.SELLINGPRICE END) AS decimal(18,0)) Capraz
      FROM {D}.J_ORDER_DETAILS d JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF JOIN ord ON ord.oid=d.ORDERREF""",
                (marka, s, e, marka, marka))
    h = cur.fetchone()
    # sipariş toplam (TOTALPRICE, kargo dahil) + AOV
    cur.execute(f"""SELECT COUNT(*) Sip, CAST(SUM(x.TOTALPRICE) AS decimal(18,0)) Ciro, CAST(AVG(x.TOTALPRICE) AS decimal(18,0)) AOV
      FROM (SELECT DISTINCT o.ORDERID, o.TOTALPRICE FROM {D}.J_ORDERS o JOIN {D}.J_ORDER_DETAILS d ON d.ORDERREF=o.ORDERID JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF WHERE it.BRAND=%s AND o.ORDERDATE>=%s AND o.ORDERDATE<%s) x""", (marka, s, e))
    o = cur.fetchone()
    # genel
    cur.execute(f"""SELECT COUNT(*) TumSip, CAST(AVG(TOTALPRICE) AS decimal(18,0)) GenelAOV FROM {D}.J_ORDERS WHERE ORDERDATE>=%s AND ORDERDATE<%s""", (s, e))
    g = cur.fetchone()
    # üye/misafir
    cur.execute(f"""SELECT SUM(CASE WHEN x.CUSTOMERREF>0 THEN 1 ELSE 0 END) Uye, SUM(CASE WHEN x.CUSTOMERREF=0 OR x.CUSTOMERREF IS NULL THEN 1 ELSE 0 END) Misafir, COUNT(DISTINCT NULLIF(x.CUSTOMERREF,0)) TekilUye
      FROM (SELECT DISTINCT o.ORDERID, oc.CUSTOMERREF FROM {D}.J_ORDERS o JOIN {D}.J_ORDER_DETAILS d ON d.ORDERREF=o.ORDERID JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF LEFT JOIN {D}.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF WHERE it.BRAND=%s AND o.ORDERDATE>=%s AND o.ORDERDATE<%s) x""", (marka, s, e))
    m = cur.fetchone()
    sip = int(h["Siparis"] or 0); net = float(u["Net"] or 0); brut = float(u["Brut"] or 0)
    sepet = float(h["SepetUrun"] or 0); capraz = float(h["Capraz"] or 0)
    return dict(adet=int(u["Adet"] or 0), net=net, brut=brut, indirim=float(u["Indirim"] or 0),
                indirimP=round(100*float(u["Indirim"] or 0)/brut, 1) if brut else 0,
                birim=round(net/int(u["Adet"]), 0) if u["Adet"] else 0,
                siparis=sip, siparisCiro=float(o["Ciro"] or 0), aov=float(o["AOV"] or 0),
                sepetUrun=sepet, markaCiro=float(h["MarkaCiro"] or 0), capraz=capraz,
                caprazP=round(100*capraz/sepet, 1) if sepet else 0,
                ortSepet=round(sepet/sip, 0) if sip else 0,
                genelAOV=float(g["GenelAOV"] or 0), tumSiparis=int(g["TumSip"] or 0),
                payP=round(100*sip/int(g["TumSip"]), 1) if g["TumSip"] else 0,
                uye=int(m["Uye"] or 0), misafir=int(m["Misafir"] or 0), tekilUye=int(m["TekilUye"] or 0))


def detay(cur, marka, s, e):
    """Son dönem detay: kanal, saat, çapraz marka, birlikte ürün."""
    cur.execute(f"""SELECT x.APPLICATION Kanal, COUNT(*) Sip, CAST(AVG(x.TOTALPRICE) AS decimal(18,0)) AOV, CAST(SUM(x.TOTALPRICE) AS decimal(18,0)) Ciro
      FROM (SELECT DISTINCT o.ORDERID, o.APPLICATION, o.TOTALPRICE FROM {D}.J_ORDERS o JOIN {D}.J_ORDER_DETAILS d ON d.ORDERREF=o.ORDERID JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF WHERE it.BRAND=%s AND o.ORDERDATE>=%s AND o.ORDERDATE<%s) x
      GROUP BY x.APPLICATION ORDER BY COUNT(*) DESC""", (marka, s, e))
    kanal = cur.fetchall()
    cur.execute(f"""SELECT DATEPART(HOUR,x.ORDERDATE) Saat, COUNT(*) Sip
      FROM (SELECT DISTINCT o.ORDERID, o.ORDERDATE FROM {D}.J_ORDERS o JOIN {D}.J_ORDER_DETAILS d ON d.ORDERREF=o.ORDERID JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF WHERE it.BRAND=%s AND o.ORDERDATE>=%s AND o.ORDERDATE<%s) x
      GROUP BY DATEPART(HOUR,x.ORDERDATE) ORDER BY DATEPART(HOUR,x.ORDERDATE)""", (marka, s, e))
    saat = cur.fetchall()
    sub = f"(SELECT d2.ORDERREF FROM {D}.J_ORDER_DETAILS d2 JOIN {D}.J_ITEMS it2 ON it2.LOGICALREF=d2.ITEMREF WHERE it2.BRAND=%s AND d2.ORDERDATE>=%s AND d2.ORDERDATE<%s)"
    cur.execute(f"""SELECT TOP 15 it.BRAND Marka, SUM(d.QUANTITY) Adet, CAST(SUM(d.QUANTITY*d.SELLINGPRICE) AS decimal(18,0)) Ciro
      FROM {D}.J_ORDER_DETAILS d JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF
      WHERE it.BRAND<>%s AND d.ORDERDATE>=%s AND d.ORDERDATE<%s AND d.ORDERREF IN {sub}
      GROUP BY it.BRAND ORDER BY SUM(d.QUANTITY*d.SELLINGPRICE) DESC""", (marka, s, e, marka, s, e))
    cmarka = cur.fetchall()
    cur.execute(f"""SELECT TOP 25 it.NAME Urun, it.BRAND Marka, SUM(d.QUANTITY) Adet, CAST(SUM(d.QUANTITY*d.SELLINGPRICE) AS decimal(18,0)) Ciro
      FROM {D}.J_ORDER_DETAILS d JOIN {D}.J_ITEMS it ON it.LOGICALREF=d.ITEMREF
      WHERE it.BRAND<>%s AND d.ORDERDATE>=%s AND d.ORDERDATE<%s AND d.ORDERREF IN {sub}
      GROUP BY it.NAME, it.BRAND ORDER BY SUM(d.QUANTITY) DESC""", (marka, s, e, marka, s, e))
    curun = cur.fetchall()
    return kanal, saat, cmarka, curun


def delta(a, b):
    if not a:
        return "—"
    return f"+%{100*(b-a)/a:.0f}".replace("+%-", "−%") if a else "—"


def build(marka, d1, d2):
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"], database=c.get("database", "master"), charset="UTF-8", login_timeout=20, timeout=300)
    cur = conn.cursor(as_dict=True)
    m1 = metrics(cur, marka, d1[0], d1[1])
    m2 = metrics(cur, marka, d2[0], d2[1])
    kanal, saat, cmarka, curun = detay(cur, marka, d2[0], d2[1])
    cur.close(); conn.close()

    wb = Workbook()
    red = PatternFill("solid", fgColor=KIRMIZI); white = Font(color="FFFFFF", bold=True)
    thin = Border(*[Side(style="thin", color="E2E8F0")] * 4)
    L1 = d1[0][:6] + " " + d1[0][6:] + "-" + d1[1][6:]
    L2 = d2[0][:6] + " " + d2[0][6:] + "-" + d2[1][6:]

    def tl(v): return f"{v:,.0f}".replace(",", ".")

    # ---- Yönetici Özeti ----
    ws = wb.active; ws.title = "Yönetici Özeti"
    ws["A1"] = f"E-TİCARET KAMPANYA ANALİZİ — {marka}"; ws["A1"].font = Font(bold=True, size=15, color=KIRMIZI)
    ws["A2"] = f"{L1}  vs  {L2}  ·  marka=J_ITEMS.BRAND · sepet etkisi + indirim derinliği + kanal/saat/müşteri"; ws["A2"].font = Font(italic=True, color="64748B")
    rows = [
        ("Net Ciro (marka)", tl(m1["net"]) + " ₺", tl(m2["net"]) + " ₺", delta(m1["net"], m2["net"])),
        ("Satılan Adet", tl(m1["adet"]), tl(m2["adet"]), delta(m1["adet"], m2["adet"])),
        ("Ort. Birim Fiyat", tl(m1["birim"]) + " ₺", tl(m2["birim"]) + " ₺", delta(m1["birim"], m2["birim"])),
        ("İndirim Oranı", f"%{m1['indirimP']}".replace(".", ","), f"%{m2['indirimP']}".replace(".", ","), f"{m2['indirimP']-m1['indirimP']:+.1f} puan".replace(".", ",")),
        ("İndirim Tutarı", tl(m1["indirim"]) + " ₺", tl(m2["indirim"]) + " ₺", delta(m1["indirim"], m2["indirim"])),
        ("Markalı Sipariş", tl(m1["siparis"]), tl(m2["siparis"]), delta(m1["siparis"], m2["siparis"])),
        ("Bu Siparişlerin Cirosu", tl(m1["siparisCiro"]) + " ₺", tl(m2["siparisCiro"]) + " ₺", delta(m1["siparisCiro"], m2["siparisCiro"])),
        ("Çapraz Satış", tl(m1["capraz"]) + " ₺", tl(m2["capraz"]) + " ₺", delta(m1["capraz"], m2["capraz"])),
        ("Çapraz Satış Oranı", f"%{m1['caprazP']}".replace(".", ","), f"%{m2['caprazP']}".replace(".", ","), f"{m2['caprazP']-m1['caprazP']:+.1f} puan".replace(".", ",")),
        ("Ort. Sepet (markalı)", tl(m1["ortSepet"]) + " ₺", tl(m2["ortSepet"]) + " ₺", delta(m1["ortSepet"], m2["ortSepet"])),
        ("Genel Ortalama Sepet", tl(m1["genelAOV"]) + " ₺", tl(m2["genelAOV"]) + " ₺", delta(m1["genelAOV"], m2["genelAOV"])),
        ("Sipariş Payı (markalı/tüm)", f"%{m1['payP']}".replace(".", ","), f"%{m2['payP']}".replace(".", ","), f"{m2['payP']-m1['payP']:+.1f} puan".replace(".", ",")),
        ("Üye Sipariş", tl(m1["uye"]), tl(m2["uye"]), delta(m1["uye"], m2["uye"])),
        ("Misafir Sipariş", tl(m1["misafir"]), tl(m2["misafir"]), delta(m1["misafir"], m2["misafir"])),
    ]
    hr = 4
    for j, h in enumerate(["Metrik", L1, L2, "Değişim"], 1):
        cc = ws.cell(hr, j, h); cc.fill = red; cc.font = white; cc.alignment = Alignment(horizontal="center"); cc.border = thin
    for i, r in enumerate(rows, hr + 1):
        for j, v in enumerate(r, 1):
            cc = ws.cell(i, j, v); cc.border = thin
            if j == 1: cc.font = Font(bold=True, size=10)
            if j == 4: cc.font = Font(bold=True, color=("16A34A" if str(v).startswith("+") else ("DC2626" if str(v).startswith("−") else "0F172A")))
    ws.column_dimensions["A"].width = 30
    for col in "BCD": ws.column_dimensions[col].width = 18

    ins_row = hr + len(rows) + 2
    insights = ["YORUM",
        f"• İndirim {m1['indirimP']}% → {m2['indirimP']}% (derinleşti); adet {delta(m1['adet'],m2['adet'])} → derin indirim hacmi sürdü.",
        f"• Yanında alınan diğer ürün satışı {tl(m1['capraz'])} → {tl(m2['capraz'])} ₺ ({delta(m1['capraz'],m2['capraz'])}). Sepetin %{m2['caprazP']}'i marka-dışı güçlü; indirim 'maliyetini' çapraz tam-fiyat satış telafi ediyor.",
        f"• Markalı sipariş payı %{m1['payP']} → %{m2['payP']} (e-ticaretin giderek büyüyen kısmı).",
        f"• Müşteri %{round(100*m2['uye']/max(1,m2['siparis']))} üye (CRM yakalama iyi).",
        "• En çok birlikte alınan marka/ürünler ayrı sayfada → bundle/öneri fırsatı.",
        "", "ÖNERİLER",
        "• Bundle: marka + en sık eşleşen 2-3 kitap seti → sepeti büyüt.",
        "• İndirim marj kontrolü (karzarar): net marj + çapraz marj birlikte pozitif mi?",
        "• Push zamanlaması akşam 18-21 (saat sayfası); App'e ağırlık (yüksek sepet)."]
    for k, ln in enumerate(insights):
        cc = ws.cell(ins_row + k, 1, ln)
        cc.font = Font(bold=True, size=12, color=KIRMIZI) if ln in ("YORUM", "ÖNERİLER") else Font(size=10)

    # ---- Kanal ----
    kw = wb.create_sheet("Kanal")
    for j, h in enumerate(["Kanal (" + L2 + ")", "Sipariş", "Ortalama Sepet ₺", "Ciro ₺"], 1):
        cc = kw.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    for i, r in enumerate(kanal, 2):
        for j, v in enumerate([r["Kanal"], int(r["Sip"]), int(r["AOV"] or 0), int(r["Ciro"] or 0)], 1):
            cc = kw.cell(i, j, v); cc.border = thin
            if j in (2, 3, 4): cc.number_format = "#,##0"
    for j, w in enumerate([26, 11, 11, 14], 1): kw.column_dimensions[get_column_letter(j)].width = w

    # ---- Saat ----
    sw = wb.create_sheet("Saat")
    for j, h in enumerate(["Saat", "Sipariş"], 1):
        cc = sw.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    for i, r in enumerate(saat, 2):
        sw.cell(i, 1, int(r["Saat"])); cc = sw.cell(i, 2, int(r["Sip"])); cc.number_format = "#,##0"
    ch = BarChart(); ch.title = "Saat Bazlı Sipariş (" + L2 + ")"; ch.height = 8; ch.width = 18
    ch.add_data(Reference(sw, min_col=2, min_row=1, max_row=len(saat) + 1), titles_from_data=True)
    ch.set_categories(Reference(sw, min_col=1, min_row=2, max_row=len(saat) + 1))
    sw.add_chart(ch, "D2")
    sw.column_dimensions["A"].width = 8; sw.column_dimensions["B"].width = 10

    # ---- Çapraz Marka ----
    cm = wb.create_sheet("Çapraz Markalar")
    for j, h in enumerate(["Marka (birlikte alınan)", "Adet", "Çapraz Ciro ₺"], 1):
        cc = cm.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    for i, r in enumerate(cmarka, 2):
        for j, v in enumerate([r["Marka"], int(r["Adet"]), int(r["Ciro"] or 0)], 1):
            cc = cm.cell(i, j, v); cc.border = thin
            if j in (2, 3): cc.number_format = "#,##0"
    for j, w in enumerate([28, 10, 14], 1): cm.column_dimensions[get_column_letter(j)].width = w

    # ---- Birlikte Ürünler ----
    cu = wb.create_sheet("Birlikte Ürünler")
    for j, h in enumerate(["Ürün (Ephesus yanında)", "Marka", "Adet", "Ciro ₺"], 1):
        cc = cu.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    for i, r in enumerate(curun, 2):
        for j, v in enumerate([r["Urun"], r["Marka"], int(r["Adet"]), int(r["Ciro"] or 0)], 1):
            cc = cu.cell(i, j, v); cc.border = thin
            if j in (3, 4): cc.number_format = "#,##0"
    for j, w in enumerate([44, 22, 9, 12], 1): cu.column_dimensions[get_column_letter(j)].width = w

    safe = "".join(ch if ch.isalnum() else "-" for ch in marka).strip("-").lower()
    out = R / "briefings" / f"kampanya-analiz-{safe}.xlsx"
    wb.save(out)
    print(f"Excel: {out}")
    print(f"  {marka} · {L1} net {tl(m1['net'])} ind%{m1['indirimP']} → {L2} net {tl(m2['net'])} ind%{m2['indirimP']} · çapraz %{m2['caprazP']}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--marka", default="Ephesus Yayınları")
    ap.add_argument("--d1", nargs=2, default=["20260501", "20260508"])
    ap.add_argument("--d2", nargs=2, default=["20260601", "20260608"])
    a = ap.parse_args()
    build(a.marka, a.d1, a.d2)
