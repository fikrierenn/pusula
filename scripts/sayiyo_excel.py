"""
SAYIYO (KAPI SAYICI) EXCEL RAPORU — FSM
Veri kaynağı: bkm.MusteriSayi (API ile otomatik beslenen kapı sayacı, günlük SUM) +
EncoreMerkez POS (fiş/ciro). CSV/xlsx elle-yükleme akışı KALDIRILDI (24.07.2026) — API canlı.
Gün gün detay (trafik + fiş + dönüşüm + ciro + sepet) + Yönetici Özeti sayfası.
Çıktı: briefings/sayiyo-rapor.xlsx
Kullanım: python sayiyo_excel.py [--gun 60]
"""
import sys, json, os, statistics, argparse
from pathlib import Path
from datetime import date, timedelta
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pymssql
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.chart import LineChart, BarChart, Reference
from openpyxl.utils import get_column_letter

R = Path(__file__).resolve().parent.parent
KIRMIZI = "E30622"
WD = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Pzr"]


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


# FSM = posMagaza.mekanID=1 (bkm.MusteriSayi.MekanId=1 ile aynı mekan). Geri dönüşüm fişi (BarcodeNo='1001') hariç.
SQL_GIRIS = """
    SELECT CONVERT(varchar, CAST(Tarih AS date), 23) T, SUM(MusteriSayi) Giris
    FROM DerinSISBkm.bkm.MusteriSayi
    WHERE MekanId = 1 AND Tarih >= %s AND Tarih < %s
    GROUP BY CAST(Tarih AS date)
"""

SQL_FIS = """
    SELECT CONVERT(varchar, s.Date, 23) T, SUM(IIF(s.DocumentsTypeId = 3, -1, 1)) Fis,
        CAST(SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * (s.GrossTotal - s.DiscountTotal - s.VatTotal)) AS decimal(18,0)) Ciro
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Pos p ON p.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores st ON st.Id = p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'
    WHERE MG.mekanID = 1 AND spb.Id IS NULL AND s.DocumentsTypeId IN (1,2,3,6,7,8)
      AND s.Date >= %s AND s.Date < %s
    GROUP BY CONVERT(varchar, s.Date, 23)
"""


def get_data(gun):
    bit = date.today()  # bugün genelde kısmi (yarım gün) → dışla
    bas = bit - timedelta(days=gun)
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"], database=c.get("database", "master"), charset="UTF-8", login_timeout=20, timeout=120)
    cur = conn.cursor(as_dict=True)
    cur.execute(SQL_GIRIS, (bas.isoformat(), bit.isoformat()))
    traf = {r["T"]: int(r["Giris"]) for r in cur.fetchall()}
    cur.execute(SQL_FIS, (bas.isoformat(), bit.isoformat()))
    sal = {r["T"]: r for r in cur.fetchall()}
    cur.close(); conn.close()

    rows = []
    for g in sorted(traf):
        gi = traf[g]
        if gi < 50 or g not in sal:
            continue
        s = sal[g]
        fis = int(s["Fis"]); ci = float(s["Ciro"] or 0)
        yy, mm, dd = map(int, g.split("-"))
        rows.append(dict(g=g, wd=WD[date(yy, mm, dd).weekday()], gi=gi, fis=fis, ci=ci,
                         conv=100*fis/gi if gi else 0, cpv=ci/gi if gi else 0,
                         sepet=ci/fis if fis else 0))
    return rows


def build(rows):
    wb = Workbook()
    red = PatternFill("solid", fgColor=KIRMIZI)
    white = Font(color="FFFFFF", bold=True)
    bold = Font(bold=True)
    thin = Border(*[Side(style="thin", color="E2E8F0")] * 4)
    center = Alignment(horizontal="center")

    # ---- Yönetici Özeti ----
    ws = wb.active; ws.title = "Yönetici Özeti"
    convs = [r["conv"] for r in rows]
    tg = sum(r["gi"] for r in rows); tf = sum(r["fis"] for r in rows); tc = sum(r["ci"] for r in rows)
    med = statistics.median(convs)
    lost = sum((med-r["conv"])/100*r["gi"]*(r["ci"]/r["fis"] if r["fis"] else 0) for r in rows if r["conv"] < med)
    yillik = lost/len(rows)*365
    best = max(rows, key=lambda r: r["conv"]); worst = min(rows, key=lambda r: r["conv"])

    ws["A1"] = "BKM KİTAP — FSM KAPI SAYICI RAPORU"; ws["A1"].font = Font(bold=True, size=16, color=KIRMIZI)
    ws["A2"] = f"Dönem: {rows[0]['g']} … {rows[-1]['g']}  ·  {len(rows)} gün  ·  Mağaza: FSM (Bursa Nilüfer)"; ws["A2"].font = Font(italic=True, color="64748B")

    kpis = [("Toplam Giriş (ziyaretçi)", f"{tg:,}".replace(",", ".")),
            ("Toplam Fiş", f"{tf:,}".replace(",", ".")),
            ("Ortalama Dönüşüm", f"%{statistics.mean(convs):.1f}".replace(".", ",")),
            ("Toplam Ciro", f"{tc:,.0f} ₺".replace(",", ".")),
            ("Ortalama Sepet (ATV)", f"{tc/tf:,.0f} ₺".replace(",", "."))]
    r0 = 4
    for i, (k, v) in enumerate(kpis):
        col = 1 + i*2
        ws.cell(r0, col, k).font = Font(size=9, color="64748B")
        cell = ws.cell(r0+1, col, v); cell.font = Font(bold=True, size=14, color=KIRMIZI)

    insights = [
        "", "BULGULAR",
        f"• Dönüşüm: ortalama %{statistics.mean(convs):.1f}, medyan %{med:.1f}, bant %{min(convs):.1f}–%{max(convs):.1f} (giren her 2 kişiden ~1'i alışveriş yaptı — sağlıklı).".replace(".", ",", 6),
        f"• En iyi gün: {best['g']} {best['wd']} %{best['conv']:.1f}  ·  En kötü: {worst['g']} {worst['wd']} %{worst['conv']:.1f} (incele — trafik normal, dönüşüm düşük = operasyon).".replace(".", ",", 4),
        f"• FIRSAT: kötü günler ortalamaya çekilse → günlük ~{lost/len(rows):,.0f} ₺, YILLIK ~{yillik:,.0f} ₺ ek ciro (sadece tutarlılıkla).".replace(",", "."),
        "", "ÖNERİLER",
        "• Düşük-dönüşüm günleri için kök-neden takibi (personel/stok/deneyim) — her puan = para.",
        "• Özel günlere (bayram vb.) personel takviyesi — pik trafik kadrolanmazsa satış kaçar.",
        "", "Not: Kapı sayıcı şu an sadece FSM'de. Özlüce + İst.Yolu'na yayılırsa fırsat 3 mağazaya katlanır.",
    ]
    rr = r0 + 3
    for line in insights:
        c = ws.cell(rr, 1, line)
        if line in ("BULGULAR", "ÖNERİLER"):
            c.font = Font(bold=True, size=12, color=KIRMIZI)
        elif line.startswith("Not:"):
            c.font = Font(italic=True, size=9, color="64748B")
        else:
            c.font = Font(size=10)
        rr += 1
    ws.column_dimensions["A"].width = 30
    for col in "BCDEFGHI":
        ws.column_dimensions[col].width = 16

    # ---- Gün Gün ----
    d = wb.create_sheet("Gün Gün")
    hdr = ["Tarih", "Gün", "Giriş", "Fiş", "Dönüşüm %", "Net Ciro ₺", "₺/Ziyaret", "Sepet"]
    for j, h in enumerate(hdr, 1):
        c = d.cell(1, j, h); c.fill = red; c.font = white; c.alignment = center; c.border = thin
    for i, r in enumerate(rows, 2):
        vals = [r["g"], r["wd"], r["gi"], r["fis"], round(r["conv"], 1), round(r["ci"]), round(r["cpv"]), round(r["sepet"])]
        for j, v in enumerate(vals, 1):
            cc = d.cell(i, j, v); cc.border = thin
            if j in (3, 4, 6, 7, 8): cc.number_format = "#,##0"
            if j == 5: cc.number_format = "0.0"
            if r["wd"] in ("Cmt", "Pzr"): cc.fill = PatternFill("solid", fgColor="FEF2F2")
    nr = len(rows) + 1
    # toplam satırı
    tr = nr + 1
    d.cell(tr, 1, "TOPLAM/ORT").font = bold
    d.cell(tr, 3, tg).number_format = "#,##0"; d.cell(tr, 4, tf).number_format = "#,##0"
    d.cell(tr, 5, round(statistics.mean(convs), 1)).number_format = "0.0"
    d.cell(tr, 6, round(tc)).number_format = "#,##0"; d.cell(tr, 7, round(tc/tg)).number_format = "#,##0"
    d.cell(tr, 8, round(tc/tf)).number_format = "#,##0"
    for j in range(1, 9): d.cell(tr, j).font = bold
    widths = [11, 6, 9, 8, 11, 14, 11, 10]
    for j, w in enumerate(widths, 1):
        d.column_dimensions[get_column_letter(j)].width = w
    d.freeze_panes = "A2"

    # grafik: dönüşüm trend (line) + giriş (bar) ayrı
    ch = LineChart(); ch.title = "Günlük Dönüşüm Oranı (%)"; ch.height = 7; ch.width = 20
    data = Reference(d, min_col=5, min_row=1, max_row=nr); cats = Reference(d, min_col=1, min_row=2, max_row=nr)
    ch.add_data(data, titles_from_data=True); ch.set_categories(cats); ch.y_axis.title = "%"
    ws.add_chart(ch, "A28")
    cb = BarChart(); cb.title = "Günlük Giriş (trafik)"; cb.height = 7; cb.width = 20
    db = Reference(d, min_col=3, min_row=1, max_row=nr); cb.add_data(db, titles_from_data=True); cb.set_categories(cats)
    ws.add_chart(cb, "A43")

    out = R / "briefings" / "sayiyo-rapor.xlsx"
    wb.save(out)
    print(f"Excel: {out}")
    print(f"  {len(rows)} gün · ort dönüşüm %{statistics.mean(convs):.1f} · yıllık fırsat ~{yillik:,.0f} ₺".replace(",", "."))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--gun", type=int, default=60)
    args = ap.parse_args()
    build(get_data(args.gun))
