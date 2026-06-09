"""
SAYIYO (KAPI SAYICI) EXCEL RAPORU — FSM
Gün gün detay (trafik + fiş + dönüşüm + ciro + işgücü) + Yönetici Özeti sayfası.
Çıktı: briefings/sayiyo-rapor.xlsx
Kullanım: python sayiyo_excel.py
"""
import sys, csv, json, os, statistics
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


def get_data():
    traf = {r["Tarih"]: int(r["Giris"]) for r in csv.DictReader(open(R / "sayiyo" / "fsm_gunluk_trafik.csv", encoding="utf-8"))}
    days = sorted(traf)
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"], database=c.get("database", "master"), charset="UTF-8", login_timeout=20, timeout=120)
    cur = conn.cursor(as_dict=True)
    g0, g1 = days[0], (date.fromisoformat(days[-1]) + timedelta(days=1)).isoformat()
    cur.execute("""SELECT CONVERT(varchar,s.Date,23) T, SUM(IIF(s.DocumentsTypeId=3,-1,1)) Fis,
        CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) AS decimal(18,0)) Ciro
      FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK) JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
      JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
      LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
      WHERE MG.mekanID=1 AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=%s AND s.Date<%s
      GROUP BY CONVERT(varchar,s.Date,23)""", (g0, g1))
    sal = {r["T"]: r for r in cur.fetchall()}
    inner = ("SELECT CONVERT(varchar(10),z.TZe_Datum,23) Gun, CAST(SUM(DATEDIFF(MINUTE,z.TZe_VonZeit,z.TZe_BisZeit))/60.0 AS decimal(18,1)) Saat, COUNT(DISTINCT z.TZe_PersNr) Personel "
             "FROM TTagZei z JOIN TPerTab p ON p.Per_PersNr=z.TZe_PersNr WHERE z.TZe_Datum>=''%s'' AND z.TZe_Datum<=''%s'' AND p.Per_Grp1=''MAĞAZALAR'' AND LTRIM(RTRIM(p.Per_Grp2))=''FSM'' AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL "
             "GROUP BY CONVERT(varchar(10),z.TZe_Datum,23)") % (days[0].replace("-", ""), days[-1].replace("-", ""))
    cur.execute("SELECT * FROM OPENQUERY([PDKS], '" + inner + "')")
    lab = {r["Gun"]: r for r in cur.fetchall()}
    cur.close(); conn.close()
    rows = []
    son = days[-1]  # export günü genelde kısmi (yarım) — dışla
    for g in days:
        if g == son:
            continue
        gi = traf[g]
        if gi < 50 or g not in sal:
            continue
        s = sal[g]; l = lab.get(g, {})
        fis = int(s["Fis"]); ci = float(s["Ciro"] or 0); sa = float(l.get("Saat") or 0); pe = int(l.get("Personel") or 0)
        yy, mm, dd = map(int, g.split("-"))
        rows.append(dict(g=g, wd=WD[date(yy, mm, dd).weekday()], gi=gi, fis=fis, ci=ci,
                         conv=100*fis/gi if gi else 0, cpv=ci/gi if gi else 0,
                         sa=sa, pe=pe, yuk=gi/sa if sa else 0, splh=ci/sa if sa else 0))
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
            ("Ortalama ₺/Ziyaret", f"{tc/tg:,.0f} ₺".replace(",", "."))]
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
    ]
    if any(r["sa"] for r in rows):
        labr = [r for r in rows if r["sa"]]
        insights += [
            f"• İşgücü: ortalama {statistics.mean([r['pe'] for r in labr]):.0f} personel/gün, yük (ziyaretçi/saat) {statistics.mean([r['yuk'] for r in labr]):.1f}, SPLH {statistics.mean([r['splh'] for r in labr]):,.0f} ₺/saat.".replace(",", ".").replace(".", ",", 2),
            "• Personel trafiğe ayarlanıyor (hafta sonu kadro artıyor) ama özel günlerde takviye eksik kalabiliyor.",
        ]
    insights += [
        "", "ÖNERİLER",
        "• İzin/off günleri → Çarşamba + Salı (en düşük trafik; Salı zaten fazla kadrolu).",
        "• Cumartesi + Pazar → tam kadro, izin yok (en yüksek trafik + verim).",
        "• Özel günlere (bayram vb.) personel takviyesi — pik trafik kadrolanmazsa satış kaçar.",
        "• Düşük-dönüşüm günleri için kök-neden takibi (personel/stok/deneyim) — her puan = para.",
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
    for col in "BCDEFGHIJ":
        ws.column_dimensions[col].width = 16

    # ---- Gün Gün ----
    d = wb.create_sheet("Gün Gün")
    hdr = ["Tarih", "Gün", "Giriş", "Fiş", "Dönüşüm %", "Net Ciro ₺", "₺/Ziyaret", "İşgücü-Saat", "Personel", "Yük (ziy/saat)", "SPLH ₺/saat"]
    for j, h in enumerate(hdr, 1):
        c = d.cell(1, j, h); c.fill = red; c.font = white; c.alignment = center; c.border = thin
    for i, r in enumerate(rows, 2):
        vals = [r["g"], r["wd"], r["gi"], r["fis"], round(r["conv"], 1), round(r["ci"]), round(r["cpv"]),
                round(r["sa"], 1) if r["sa"] else None, r["pe"] or None, round(r["yuk"], 1) if r["yuk"] else None, round(r["splh"]) if r["splh"] else None]
        for j, v in enumerate(vals, 1):
            cc = d.cell(i, j, v); cc.border = thin
            if j in (3, 4, 6, 7, 9, 11): cc.number_format = "#,##0"
            if j in (5, 10): cc.number_format = "0.0"
            if r["wd"] in ("Cmt", "Pzr"): cc.fill = PatternFill("solid", fgColor="FEF2F2")
    nr = len(rows) + 1
    # toplam satırı
    tr = nr + 1
    d.cell(tr, 1, "TOPLAM/ORT").font = bold
    d.cell(tr, 3, tg).number_format = "#,##0"; d.cell(tr, 4, tf).number_format = "#,##0"
    d.cell(tr, 5, round(statistics.mean(convs), 1)).number_format = "0.0"
    d.cell(tr, 6, round(tc)).number_format = "#,##0"; d.cell(tr, 7, round(tc/tg)).number_format = "#,##0"
    for j in range(1, 12): d.cell(tr, j).font = bold
    widths = [11, 6, 9, 8, 11, 14, 11, 12, 10, 14, 13]
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
    build(get_data())
