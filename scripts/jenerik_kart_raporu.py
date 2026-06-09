"""
JENERİK / İÇ KART KULLANIM RAPORU
Kasiyerlerin gerçek müşteri kartı yerine genel/mağaza/operatör kartı okutması →
CRM veri kaybı + sahte sadık müşteri. Mağaza + kart + operatör kırılımı.
Çıktı: briefings/jenerik-kart-raporu.xlsx
Kullanım: python jenerik_kart_raporu.py [--gun 90]
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
MEKAN = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu"}
# jenerik kart tanımı: mağaza/kumbara isim VEYA 599/699 dummy telefon
GEN = "(c.Name LIKE '%Mağaza%' OR c.Name LIKE '%Kumbara%' OR c.PhoneNumber LIKE '599%' OR c.PhoneNumber LIKE '699%')"


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


def get_data(gun):
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"], database=c.get("database", "master"), charset="UTF-8", login_timeout=20, timeout=180)
    cur = conn.cursor(as_dict=True)
    base = """FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
      JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
      JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
      LEFT JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id=s.CustomersId
      WHERE s.DocumentsTypeId=1 AND s.Date>=DATEADD(DAY,-%d,CAST(GETDATE() AS date))""" % gun
    cur.execute("""SELECT MG.mekanID,
        COUNT(*) ToplamFis, CAST(SUM(s.GrossTotal-s.DiscountTotal) AS decimal(18,0)) ToplamCiro,
        SUM(CASE WHEN c.Id IS NOT NULL AND %s THEN 1 ELSE 0 END) JenFis,
        CAST(SUM(CASE WHEN c.Id IS NOT NULL AND %s THEN s.GrossTotal-s.DiscountTotal ELSE 0 END) AS decimal(18,0)) JenCiro,
        SUM(CASE WHEN s.CustomersId=0 OR s.CustomersId IS NULL THEN 1 ELSE 0 END) KartsizFis,
        CAST(SUM(CASE WHEN s.CustomersId=0 OR s.CustomersId IS NULL THEN s.GrossTotal-s.DiscountTotal ELSE 0 END) AS decimal(18,0)) KartsizCiro
      %s GROUP BY MG.mekanID""" % (GEN, GEN, base))
    mag = {r["mekanID"]: r for r in cur.fetchall()}
    cur.execute("""SELECT TOP 40 MG.mekanID, CAST(c.Name AS nvarchar(40)) Kart, CAST(c.PhoneNumber AS nvarchar(15)) Tel,
        COUNT(*) Fis, CAST(SUM(s.GrossTotal-s.DiscountTotal) AS decimal(18,0)) Ciro
      %s AND c.Id IS NOT NULL AND %s
      GROUP BY MG.mekanID, CAST(c.Name AS nvarchar(40)), CAST(c.PhoneNumber AS nvarchar(15))
      HAVING COUNT(*)>=10 ORDER BY COUNT(*) DESC""" % (base, GEN))
    kart = cur.fetchall()
    cur.close(); conn.close()
    return mag, kart


def build(gun):
    mag, kart = get_data(gun)
    wb = Workbook()
    red = PatternFill("solid", fgColor=KIRMIZI); white = Font(color="FFFFFF", bold=True)
    thin = Border(*[Side(style="thin", color="E2E8F0")] * 4)
    tg = sum(int(m["ToplamFis"]) for m in mag.values()); tgc = sum(float(m["ToplamCiro"] or 0) for m in mag.values())
    tj = sum(int(m["JenFis"]) for m in mag.values()); tjc = sum(float(m["JenCiro"] or 0) for m in mag.values())
    tk = sum(int(m["KartsizFis"]) for m in mag.values())

    def tl(v): return f"{v:,.0f}".replace(",", ".")

    # ---- Yönetici Özeti ----
    ws = wb.active; ws.title = "Yönetici Özeti"
    ws["A1"] = "BKM KİTAP — JENERİK / İÇ KART KULLANIM RAPORU"; ws["A1"].font = Font(bold=True, size=15, color=KIRMIZI)
    ws["A2"] = f"Son {gun} gün · jenerik = mağaza/operatör/dummy(599-699) kart · gerçek müşteri yerine okutuluyor"; ws["A2"].font = Font(italic=True, color="64748B")
    kpis = [("Toplam Fiş", tl(tg)), ("Jenerik Kart Fiş", tl(tj)), ("Jenerik Oranı", f"%{100*tj/tg:.1f}".replace(".", ",")),
            ("Jenerik Ciro", tl(tjc) + " ₺"), ("Kartsız Fiş", f"%{100*tk/tg:.0f}".replace(".", ","))]
    for i, (k, v) in enumerate(kpis):
        ws.cell(4, 1 + i * 2, k).font = Font(size=9, color="64748B")
        ws.cell(5, 1 + i * 2, v).font = Font(bold=True, size=13, color=KIRMIZI)
    worst = max(mag.items(), key=lambda kv: int(kv[1]["JenFis"]) / max(1, int(kv[1]["ToplamFis"])))
    wpct = 100 * int(worst[1]["JenFis"]) / int(worst[1]["ToplamFis"])
    lines = [
        "", "BULGULAR",
        f"• En sorunlu mağaza: {MEKAN[worst[0]]} — fişlerin %{wpct:.1f}'i jenerik kart ({tl(int(worst[1]['JenFis']))} fiş, {tl(float(worst[1]['JenCiro'] or 0))} ₺).".replace(".", ",", 2),
        "• Jenerik kart = kasiyer gerçek müşteriyi sormadan kendi/mağaza kartını okutuyor → o ciro sahte 'sadık müşteri'ye yazılıyor, gerçek müşteri CRM'e girmiyor.",
        f"• Kayıp: bu fişlerdeki müşteriler tanınmıyor → kampanya/SMS/sadakat hedeflenemiyor. Yıllık tahmini {tl(tjc/gun*365)} ₺ ciro 'anonim' kalıyor.".replace(".", ",", 1),
        "• Operatör inisiyalli kartlar (AKL, RGR, ALİ, AGH...) = kasiyerlerin kişisel genel kartları; sahte RFM Şampiyon/Sadık üretiyor.",
        "", "ÖNERİLER",
        "• İst.Yolu kasiyerlerine müşteri kartı sorma zorunluluğu + günlük jenerik-oran takibi (hedef <%5).",
        "• Operatör genel kartlarını (AKL/RGR/...) POS'tan kapat veya kullanımına kota/uyarı koy.",
        "• Kartı olmayan müşteriye anında kayıt (telefon) teşviki — kasada hızlı üyelik.",
        "• Bu rapor haftalık çalıştırılıp mağaza müdürlerine gönderilsin.",
        "", f"Not: FSM %{100*int(mag.get(1,{}).get('JenFis',0))/max(1,int(mag.get(1,{}).get('ToplamFis',1))):.1f} ve Özlüce düşük — sorun İst.Yolu'na özgü, çözülebilir.".replace(".", ",", 1),
    ]
    rr = 7
    for ln in lines:
        cc = ws.cell(rr, 1, ln)
        if ln in ("BULGULAR", "ÖNERİLER"): cc.font = Font(bold=True, size=12, color=KIRMIZI)
        elif ln.startswith("Not:"): cc.font = Font(italic=True, size=9, color="64748B")
        else: cc.font = Font(size=10)
        rr += 1
    ws.column_dimensions["A"].width = 32
    for col in "BCDEFGHIJ": ws.column_dimensions[col].width = 15

    # ---- Mağaza Özeti ----
    d = wb.create_sheet("Mağaza Özeti")
    hdr = ["Mağaza", "Toplam Fiş", "Toplam Ciro", "Jenerik Fiş", "Jenerik %", "Jenerik Ciro", "Kartsız Fiş", "Kartsız %", "Gerçek Müşteri %"]
    for j, h in enumerate(hdr, 1):
        cc = d.cell(1, j, h); cc.fill = red; cc.font = white; cc.alignment = Alignment(horizontal="center"); cc.border = thin
    ri = 2
    for mid in (1, 4477, 4478):
        m = mag.get(mid)
        if not m: continue
        t = int(m["ToplamFis"]); jf = int(m["JenFis"]); kf = int(m["KartsizFis"])
        gercek = t - jf - kf
        vals = [MEKAN[mid], t, round(float(m["ToplamCiro"] or 0)), jf, round(100 * jf / t, 1), round(float(m["JenCiro"] or 0)),
                kf, round(100 * kf / t, 1), round(100 * gercek / t, 1)]
        for j, v in enumerate(vals, 1):
            cc = d.cell(ri, j, v); cc.border = thin
            if j in (2, 3, 4, 6, 7): cc.number_format = "#,##0"
            if j in (5, 8, 9): cc.number_format = "0.0"
            if j == 5 and round(100 * jf / t, 1) >= 10: cc.fill = PatternFill("solid", fgColor="FEE2E2"); cc.font = Font(bold=True, color="DC2626")
        ri += 1
    for j, w in enumerate([12, 11, 14, 11, 10, 13, 11, 10, 15], 1):
        d.column_dimensions[get_column_letter(j)].width = w
    ch = BarChart(); ch.title = "Jenerik Kart Oranı (%)"; ch.height = 7; ch.width = 16
    data = Reference(d, min_col=5, min_row=1, max_row=ri - 1); cats = Reference(d, min_col=1, min_row=2, max_row=ri - 1)
    ch.add_data(data, titles_from_data=True); ch.set_categories(cats)
    ws.add_chart(ch, "A26")

    # ---- Jenerik Kartlar ----
    k = wb.create_sheet("Jenerik Kartlar")
    hk = ["Mağaza", "Kart Adı", "Telefon", "Fiş", "Ciro ₺"]
    for j, h in enumerate(hk, 1):
        cc = k.cell(1, j, h); cc.fill = red; cc.font = white; cc.alignment = Alignment(horizontal="center"); cc.border = thin
    for i, r in enumerate(kart, 2):
        vals = [MEKAN.get(r["mekanID"], r["mekanID"]), r["Kart"], r["Tel"], int(r["Fis"]), round(float(r["Ciro"] or 0))]
        for j, v in enumerate(vals, 1):
            cc = k.cell(i, j, v); cc.border = thin
            if j in (4, 5): cc.number_format = "#,##0"
    for j, w in enumerate([11, 32, 14, 9, 14], 1):
        k.column_dimensions[get_column_letter(j)].width = w
    k.freeze_panes = "A2"

    out = R / "briefings" / "jenerik-kart-raporu.xlsx"
    wb.save(out)
    print(f"Excel: {out}")
    print(f"  {gun} gün · jenerik %{100*tj/tg:.1f} ({tl(tj)} fiş, {tl(tjc)} ₺) · en kötü {MEKAN[worst[0]]} %{wpct:.1f}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--gun", type=int, default=90); a = ap.parse_args()
    build(a.gun)
