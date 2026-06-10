"""
KAPIDA ÖDEME (COD) PERFORMANS RAPORU — e-ticaret (JOKER)
Kapıda ödeme = J_ORDERS.PAYDEFREF=-3. Teslim performansı + iade oranı (kargo durumu),
COD vs online kıyas, aylık trend, kâr/zarar modeli (service fee geliri vs iade kargo
zararı), kara liste (tekrar kapıda-red eden müşteriler — COD kapatma adayı).
Kargo durum: 0=İşlem görmemiş, 1=Teslim, 2=İade geldi, 3=Kayıp, 4=Hareket görüyor.
Çıktı: briefings/kapida-odeme-analiz.xlsx
Kullanım: python kapida_odeme_analiz.py [--kargo 180] [--olgungun 15] [--gun 120]
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
COD = -3            # Kapıda Ödeme PAYDEFREF
ONLINE = -13        # iyzico (online kart)


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


def fetch(gun, olgungun, kargo):
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"], database=c.get("database", "master"), charset="UTF-8", login_timeout=20, timeout=300)
    cur = conn.cursor(as_dict=True)
    # OLGUN pencere: çözülmüş siparişler (sipariş tarihi > olgungun gün önce)
    olw = f"o.ORDERDATE>=DATEADD(DAY,-{gun},GETDATE()) AND o.ORDERDATE<DATEADD(DAY,-{olgungun},GETDATE())"

    # 1) Teslim performansı (olgun): COD vs online kargo durumu
    cur.execute(f"""SELECT cs.STATUS Kod, CAST(cs.NAME AS nvarchar(25)) Durum,
        SUM(CASE WHEN o.PAYDEFREF={COD} THEN 1 ELSE 0 END) COD,
        SUM(CASE WHEN o.PAYDEFREF={ONLINE} THEN 1 ELSE 0 END) Online
      FROM {D}.J_ORDERS o JOIN {D}.J_ORDER_CARGO_STATUS cs ON cs.STATUS=o.CARGODELIVERYSTATUS
      WHERE {olw} GROUP BY cs.STATUS, CAST(cs.NAME AS nvarchar(25))""")
    teslim = {r["Kod"]: r for r in cur.fetchall()}

    # 2) Profil (son 'gun' gün, tüm COD): sipariş, ciro, AOV, üye/misafir, service fee, kargo
    cur.execute(f"""SELECT CASE WHEN o.PAYDEFREF={COD} THEN 'COD' ELSE 'Online' END Tip,
        COUNT(*) Sip, CAST(SUM(o.TOTALPRICE) AS decimal(18,0)) Ciro, CAST(AVG(o.TOTALPRICE) AS decimal(18,0)) AOV,
        CAST(SUM(o.SERVICEPRICE) AS decimal(18,0)) ServiceGelir,
        SUM(CASE WHEN oc.CUSTOMERREF=0 OR oc.CUSTOMERREF IS NULL THEN 1 ELSE 0 END) Misafir,
        SUM(CASE WHEN o.APPLICATION LIKE 'Mobil Uygulama%' THEN 1 ELSE 0 END) App
      FROM {D}.J_ORDERS o LEFT JOIN {D}.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
      WHERE o.PAYDEFREF IN ({COD},{ONLINE}) AND o.ORDERDATE>=DATEADD(DAY,-{gun},GETDATE())
      GROUP BY CASE WHEN o.PAYDEFREF={COD} THEN 'COD' ELSE 'Online' END""")
    profil = {r["Tip"]: r for r in cur.fetchall()}

    # 3) Aylık trend (COD): sipariş, ciro, teslim, iade
    cur.execute(f"""SELECT LEFT(CONVERT(varchar,o.ORDERDATE,112),6) YilAy, COUNT(*) Sip,
        CAST(SUM(o.TOTALPRICE) AS decimal(18,0)) Ciro,
        SUM(CASE WHEN o.CARGODELIVERYSTATUS=1 THEN 1 ELSE 0 END) Teslim,
        SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END) Iade
      FROM {D}.J_ORDERS o WHERE o.PAYDEFREF={COD} AND o.ORDERDATE>=DATEADD(DAY,-{gun},GETDATE())
      GROUP BY LEFT(CONVERT(varchar,o.ORDERDATE,112),6) ORDER BY LEFT(CONVERT(varchar,o.ORDERDATE,112),6)""")
    trend = cur.fetchall()

    # 4) Kara liste: tekrar kapıda-red eden müşteriler (≥2 iade)
    cur.execute(f"""SELECT oc.CUSTOMERREF, CAST(MAX(oc.CMAIL) AS nvarchar(45)) Mail, CAST(MAX(oc.CPHONE) AS nvarchar(15)) Tel,
        SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END) Iade,
        SUM(CASE WHEN o.CARGODELIVERYSTATUS=1 THEN 1 ELSE 0 END) Teslim,
        COUNT(*) ToplamCOD, CAST(SUM(o.TOTALPRICE) AS decimal(18,0)) Tutar
      FROM {D}.J_ORDERS o JOIN {D}.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
      WHERE o.PAYDEFREF={COD} AND oc.CUSTOMERREF>0 AND o.ORDERDATE>=DATEADD(DAY,-{gun},GETDATE())
      GROUP BY oc.CUSTOMERREF
      HAVING SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END)>=2
      ORDER BY SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END) DESC, SUM(o.TOTALPRICE) DESC""")
    kara = cur.fetchall()
    # 5) İade gerçek kargo (tek yön) — gidiş-dönüş zararı = 2× bu (firmaya ödenir, müşteriden tahsil yok)
    cur.execute(f"""SELECT CAST(SUM(o.CARGOPRICE) AS decimal(18,0)) IadeKargo
      FROM {D}.J_ORDERS o WHERE {olw} AND o.PAYDEFREF={COD} AND o.CARGODELIVERYSTATUS=2""")
    iade_kargo = float((cur.fetchone() or {}).get("IadeKargo") or 0)
    cur.close(); conn.close()
    return teslim, profil, trend, kara, iade_kargo


def build(gun, olgungun, kargo):
    teslim, profil, trend, kara, iade_kargo = fetch(gun, olgungun, kargo)
    wb = Workbook()
    red = PatternFill("solid", fgColor=KIRMIZI); white = Font(color="FFFFFF", bold=True)
    thin = Border(*[Side(style="thin", color="E2E8F0")] * 4)

    def tl(v): return f"{v:,.0f}".replace(",", ".")

    cod_teslim = int(teslim.get(1, {}).get("COD", 0)); cod_iade = int(teslim.get(2, {}).get("COD", 0))
    on_teslim = int(teslim.get(1, {}).get("Online", 0)); on_iade = int(teslim.get(2, {}).get("Online", 0))
    cod_iadeP = round(100 * cod_iade / (cod_teslim + cod_iade), 1) if (cod_teslim + cod_iade) else 0
    on_iadeP = round(100 * on_iade / (on_teslim + on_iade), 1) if (on_teslim + on_iade) else 0
    pc = profil.get("COD", {}); po = profil.get("Online", {})
    service = float(pc.get("ServiceGelir") or 0)
    # İade zararı = gerçek CARGOPRICE × 2 (gidiş + geri getirme); müşteriden tahsil yok, BKM yutar.
    # kargo param sadece CARGOPRICE yoksa fallback (tek yön).
    iade_zarar = round(iade_kargo * 2) if iade_kargo > 0 else cod_iade * kargo
    # service fee = PASS-THROUGH (müşteriden alınan ≈ kargo/tahsilat firmasına ödenen) → kâr DEĞİL, nötr.
    net = -iade_zarar

    # ---- Yönetici Özeti ----
    ws = wb.active; ws.title = "Yönetici Özeti"
    ws["A1"] = "BKM KİTAP — KAPIDA ÖDEME PERFORMANS RAPORU"; ws["A1"].font = Font(bold=True, size=15, color=KIRMIZI)
    ws["A2"] = f"E-ticaret · son {gun} gün (teslim oranı: {olgungun}+ gün olgunlaşmış siparişler) · kargo gidiş-dönüş varsayım {kargo}₺"; ws["A2"].font = Font(italic=True, color="64748B")
    kpis = [("COD Sipariş", tl(int(pc.get("Sip") or 0))), ("COD Ciro", tl(float(pc.get("Ciro") or 0)) + " ₺"),
            ("COD Ort. Sepet", tl(float(pc.get("AOV") or 0)) + " ₺"), ("COD İade Oranı", f"%{cod_iadeP}".replace(".", ",")),
            ("Online İade Oranı", f"%{on_iadeP}".replace(".", ","))]
    for i, (k, v) in enumerate(kpis):
        ws.cell(4, 1 + i * 2, k).font = Font(size=9, color="64748B")
        ws.cell(5, 1 + i * 2, v).font = Font(bold=True, size=13, color=KIRMIZI)
    lines = ["", "KÂR / ZARAR MODELİ (operasyonel, ürün marjı hariç)",
             f"• Service (kapıda ödeme) ücreti: müşteriden +{tl(service)} ₺ ≈ kargo/tahsilat firmasına ödenen → NÖTR (pass-through, KÂR DEĞİL).",
             f"• İade kargo zararı ({cod_iade} iade × gerçek kargo × 2 gidiş-dönüş = {tl(iade_kargo)}×2): −{tl(iade_zarar)} ₺ (iadede tahsil yok, müşteri ödemez).",
             f"• COD NET OPERASYONEL MALİYET: −{tl(iade_zarar)} ₺ (sadece iade zararı).",
             "• COD'un değeri finansal kârda değil → kartı olmayan/güvenmeyen müşteriye SATIŞ + büyük sepet (enablement). İade düştükçe maliyet düşer.",
             "", "BULGULAR",
             f"• COD iade (kapıda red) oranı %{cod_iadeP} — online %{on_iadeP}. COD ~{round(cod_iadeP/on_iadeP) if on_iadeP else 0}× daha riskli teslimde.".replace(".", ",", 2),
             f"• COD ort. sepet {tl(float(pc.get('AOV') or 0))}₺ > online {tl(float(po.get('AOV') or 0))}₺ → büyük sepet ama teslim riski yüksek.",
             f"• Tekrar kapıda-red eden {len(kara)} müşteri (kara liste sayfası); {sum(1 for k in kara if int(k['Teslim'])==0)}'i hiç teslim almamış.",
             "", "AKSİYON",
             "• Hiç teslim almayan (Teslim=0) müşterilere COD KAPAT (sadece ön ödeme).",
             "• ≥2 iadeli müşteriye SMS teyit zorunlu + COD limiti; 3. iadede otomatik blok.",
             "• Misafir COD'u kısıtla (üyeye aç) — misafir takip edilemiyor.",
             "• COD iade oranını brief KPI'sına ekle (hedef <%5)."]
    rr = 7
    for ln in lines:
        cc = ws.cell(rr, 1, ln)
        if ln in ("KÂR / ZARAR MODELİ (operasyonel, ürün marjı hariç)", "BULGULAR", "AKSİYON"):
            cc.font = Font(bold=True, size=12, color=KIRMIZI)
        else:
            cc.font = Font(size=10)
        rr += 1
    ws.column_dimensions["A"].width = 40
    for col in "BCDEFGHIJ": ws.column_dimensions[col].width = 14

    # ---- Teslim Performansı ----
    tp = wb.create_sheet("Teslim Performansı")
    for j, h in enumerate(["Kargo Durumu", "Kapıda Ödeme", "Online", "COD %"], 1):
        cc = tp.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    codtot = sum(int(teslim.get(k, {}).get("COD", 0)) for k in teslim)
    ri = 2
    for kod in sorted(teslim):
        r = teslim[kod]; cv = int(r["COD"])
        for j, v in enumerate([r["Durum"], cv, int(r["Online"]), round(100 * cv / codtot, 1) if codtot else 0], 1):
            cc = tp.cell(ri, j, v); cc.border = thin
            if j in (2, 3): cc.number_format = "#,##0"
            if j == 4: cc.number_format = "0.0"
            if kod == 2: cc.font = Font(bold=True, color="DC2626")
        ri += 1
    tp.cell(ri + 1, 1, f"COD kargolanan iade oranı: %{cod_iadeP}  |  Online: %{on_iadeP}").font = Font(bold=True, color=KIRMIZI)
    for j, w in enumerate([22, 14, 12, 9], 1): tp.column_dimensions[get_column_letter(j)].width = w

    # ---- Aylık Trend ----
    tr = wb.create_sheet("Aylık Trend")
    for j, h in enumerate(["Ay", "COD Sipariş", "COD Ciro", "Teslim", "İade", "İade %"], 1):
        cc = tr.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    for i, r in enumerate(trend, 2):
        t = int(r["Teslim"]); ia = int(r["Iade"]); ip = round(100 * ia / (t + ia), 1) if (t + ia) else 0
        for j, v in enumerate([r["YilAy"], int(r["Sip"]), int(r["Ciro"] or 0), t, ia, ip], 1):
            cc = tr.cell(i, j, v); cc.border = thin
            if j in (2, 3, 4, 5): cc.number_format = "#,##0"
            if j == 6: cc.number_format = "0.0"
    for j, w in enumerate([9, 12, 14, 10, 9, 9], 1): tr.column_dimensions[get_column_letter(j)].width = w

    # ---- Kara Liste ----
    kl = wb.create_sheet("Kara Liste")
    for j, h in enumerate(["CustomersId", "Mail", "Telefon", "İade", "Teslim", "Toplam COD", "Red %", "Tutar ₺", "Öneri"], 1):
        cc = kl.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    for i, r in enumerate(kara, 2):
        ia = int(r["Iade"]); te = int(r["Teslim"]); tot = int(r["ToplamCOD"])
        redp = round(100 * ia / tot, 1) if tot else 0
        oneri = "COD KAPAT (hiç almamış)" if te == 0 else ("COD limit/SMS teyit" if ia >= 3 else "izle")
        for j, v in enumerate([r["CUSTOMERREF"], r["Mail"], r["Tel"], ia, te, tot, redp, int(r["Tutar"] or 0), oneri], 1):
            cc = kl.cell(i, j, v); cc.border = thin
            if j in (4, 5, 6, 8): cc.number_format = "#,##0"
            if j == 7: cc.number_format = "0.0"
        if te == 0:
            for j in range(1, 10): kl.cell(i, j).fill = PatternFill("solid", fgColor="FEE2E2")
    kl.freeze_panes = "A2"
    for j, w in enumerate([12, 34, 15, 8, 8, 11, 8, 12, 24], 1): kl.column_dimensions[get_column_letter(j)].width = w

    out = R / "briefings" / "kapida-odeme-analiz.xlsx"
    wb.save(out)
    print(f"Excel: {out}")
    print(f"  COD {tl(float(pc.get('Ciro') or 0))}₺ · iade %{cod_iadeP} (online %{on_iadeP}) · service {tl(service)} NÖTR(pass-through) · iade zararı {tl(iade_zarar)}₺ · kara liste {len(kara)} ({sum(1 for k in kara if int(k['Teslim'])==0)} hiç-almayan)")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--kargo", type=int, default=180, help="iade gidiş-dönüş kargo maliyeti")
    ap.add_argument("--olgungun", type=int, default=15, help="teslim için olgunlaşma gün eşiği")
    ap.add_argument("--gun", type=int, default=120, help="analiz penceresi gün")
    a = ap.parse_args()
    build(a.gun, a.olgungun, a.kargo)
