"""
MERKEZ DEPO İŞGÜCÜ / VERİM RAPORU — yıllar arası (ilk N ay)
Kaynak: DerinSISBkm WMS (depo şeması). Merkez depo = mekan 12.
- Hareket kategorileri (paletIcHrk × irs × firma): Mal Kabul / Heykel(Bursa Kültür alış) /
  İade Kabul / GENEL Giriş / Mağaza Sevk / İade-GENEL Sevk.
- Görev işgücü (gerçek operatör): Raflama (paletIcHrk pHrkTip=0,pGC=0) + Toplama (emirAyr emTamam=1).
Çıktı: briefings/depo-isgucu-raporu.xlsx
Kullanım: python depo_isgucu_raporu.py [--yillar 2024 2025 2026] [--ay1 1 --ay2 5]
Detay model: docs/12-depo-wms.md
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

# Hareket kategori sırası: (ascii_anahtar, Türkçe görünüm). ascii anahtar = SQL CASE çıktısı
# (Türkçe karakterli string eşleşmesi pymssql'de kayabiliyor → ascii key ile eşle, Türkçe göster).
KATEGORILER = [("MalKabul", "Mal Kabul"), ("Heykel", "Heykel (Bursa Kültür alış)"),
               ("IadeKabul", "İade Kabul"), ("GenelGiris", "GENEL Giriş"),
               ("MagazaSevk", "Mağaza Sevk"), ("IadeSevk", "İade-GENEL Sevk")]


def cfg():
    e = R / ".env"
    if e.exists():
        for l in e.read_text(encoding="utf-8").splitlines():
            if "=" in l and not l.strip().startswith("#"):
                k, v = l.split("=", 1); os.environ.setdefault(k.strip(), v.strip())
    h = os.environ.get("MSSQL_HOST")
    if h:
        return dict(server=h, user=os.environ.get("MSSQL_USER", "sa"),
                    password=os.environ.get("MSSQL_PASSWORD", ""),
                    database=os.environ.get("MSSQL_DATABASE", "master"))
    return json.loads((R / ".secrets" / "db.json").read_text(encoding="utf-8"))


def hareket(cur, yillar, ay1, ay2):
    """Hareket kategorisi × yıl → {kategori: {yil: (islem, adet)}}."""
    yl = ",".join(str(int(y)) for y in yillar)
    cs = """CASE
          WHEN p.pGC=0 AND i.eFirma=56 THEN 'Heykel'
          WHEN p.pGC=0 AND i.eTip=0  THEN 'MalKabul'
          WHEN p.pGC=0 AND i.eTip=9  THEN 'IadeKabul'
          WHEN p.pGC=0 AND i.eTip=16 THEN 'GenelGiris'
          WHEN p.pGC=1 AND i.eTip=13 THEN 'MagazaSevk'
          WHEN p.pGC=1 AND i.eTip IN (90,99) THEN 'IadeSevk'
          ELSE 'Diger'
        END"""
    cur.execute(f"""SELECT YEAR(p.pikTarih) Yil, {cs} Kategori,
        COUNT(*) Islem, CAST(SUM(ABS(p.piAdet)) AS bigint) Adet
      FROM DerinSISBkm.depo.paletIcHrk p WITH(NOLOCK)
      JOIN DerinSISBkm.dbo.irs i WITH(NOLOCK) ON i.eID=p.piIrsID
      WHERE MONTH(p.pikTarih) BETWEEN %s AND %s AND YEAR(p.pikTarih) IN ({yl})
      GROUP BY YEAR(p.pikTarih), {cs}""", (ay1, ay2))
    d = {}
    for r in cur.fetchall():
        d.setdefault(r["Kategori"], {})[r["Yil"]] = (int(r["Islem"] or 0), int(r["Adet"] or 0))
    return d


def gorev(cur, yillar, ay1, ay2):
    """Görev (Raflama/Toplama) × yıl → {gorev: {yil: (personel, islem, adet)}}."""
    yl = ",".join(str(int(y)) for y in yillar)
    out = {}
    # Raflama = yerleştirme girişi (paletIcHrk pHrkTip=0, pGC=0)
    cur.execute(f"""SELECT YEAR(pikTarih) Yil, COUNT(DISTINCT pikKisi) Personel,
        COUNT(*) Islem, CAST(SUM(piAdet) AS bigint) Adet
      FROM DerinSISBkm.depo.paletIcHrk WITH(NOLOCK)
      WHERE pHrkTip=0 AND pGC=0 AND MONTH(pikTarih) BETWEEN %s AND %s AND YEAR(pikTarih) IN ({yl})
      GROUP BY YEAR(pikTarih)""", (ay1, ay2))
    out["Raflama"] = {r["Yil"]: (int(r["Personel"] or 0), int(r["Islem"] or 0), int(r["Adet"] or 0)) for r in cur.fetchall()}
    # Toplama = picking (emirAyr emTamam=1)
    cur.execute(f"""SELECT YEAR(emTarih) Yil, COUNT(DISTINCT emKisi) Personel,
        COUNT(*) Islem, CAST(SUM(emAdet) AS bigint) Adet
      FROM DerinSISBkm.depo.emirAyr WITH(NOLOCK)
      WHERE emTamam=1 AND MONTH(emTarih) BETWEEN %s AND %s AND YEAR(emTarih) IN ({yl})
      GROUP BY YEAR(emTarih)""", (ay1, ay2))
    out["Toplama"] = {r["Yil"]: (int(r["Personel"] or 0), int(r["Islem"] or 0), int(r["Adet"] or 0)) for r in cur.fetchall()}
    return out


def pct(a, b):
    if not a:
        return "—"
    return f"%{100*(b-a)/a:+.0f}".replace("%+", "%+").replace("%+-", "−%").replace("+", "+")


def build(yillar, ay1, ay2):
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"],
                           database=c.get("database", "master"), charset="UTF-8",
                           login_timeout=20, timeout=300)
    cur = conn.cursor(as_dict=True)
    hrk = hareket(cur, yillar, ay1, ay2)
    grv = gorev(cur, yillar, ay1, ay2)
    cur.close(); conn.close()

    wb = Workbook()
    red = PatternFill("solid", fgColor=KIRMIZI); white = Font(color="FFFFFF", bold=True)
    gri = PatternFill("solid", fgColor="F1F5F9")
    thin = Border(*[Side(style="thin", color="E2E8F0")] * 4)
    ymd = f"İlk {ay2-ay1+1} ay ({ay1:02d}-{ay2:02d})" if (ay1, ay2) == (1, 5) else f"Ay {ay1}-{ay2}"

    def tl(v): return f"{v:,.0f}".replace(",", ".")
    def dpct(a, b):
        if not a: return "—"
        s = 100 * (b - a) / a
        return (f"+%{s:.0f}" if s >= 0 else f"−%{abs(s):.0f}")

    YS = sorted(int(y) for y in yillar)

    # ---- Yönetici Özeti ----
    ws = wb.active; ws.title = "Yönetici Özeti"
    ws["A1"] = "MERKEZ DEPO İŞGÜCÜ / VERİM RAPORU"; ws["A1"].font = Font(bold=True, size=15, color=KIRMIZI)
    ws["A2"] = f"Mekan 12 (Ana Depo) · {ymd} · kaynak: WMS paletIcHrk/emirAyr/irs · gerçek operatör (emKisi/pikKisi)"
    ws["A2"].font = Font(italic=True, color="64748B")

    # Görev verim tablosu
    ws["A4"] = "GÖREV İŞGÜCÜ VERİMİ (gerçek operatör)"; ws["A4"].font = Font(bold=True, size=12, color=KIRMIZI)
    hdr = ["Görev / Yıl"] + [str(y) for y in YS] + ["Δ ilk→son"]
    hr = 5
    for j, h in enumerate(hdr, 1):
        cc = ws.cell(hr, j, h); cc.fill = red; cc.font = white; cc.alignment = Alignment(horizontal="center"); cc.border = thin
    metr = [("Personel", 0), ("İşlem", 1), ("Adet", 2), ("Kişi başı adet", None)]
    rr = hr
    for gname in ["Raflama", "Toplama"]:
        g = grv.get(gname, {})
        ws.cell(rr + 1, 1, gname).font = Font(bold=True, size=11, color=KIRMIZI)
        rr += 1
        for mlabel, idx in metr:
            rr += 1
            ws.cell(rr, 1, "   " + mlabel).font = Font(size=10)
            vals = []
            for j, y in enumerate(YS, 2):
                t = g.get(y)
                if idx is None:  # kişi başı
                    v = (t[2] / t[0]) if t and t[0] else 0
                else:
                    v = t[idx] if t else 0
                vals.append(v)
                cc = ws.cell(rr, j, round(v)); cc.border = thin; cc.number_format = "#,##0"
            cc = ws.cell(rr, len(YS) + 2, dpct(vals[0], vals[-1])); cc.border = thin
            cc.font = Font(bold=True, color=("16A34A" if str(cc.value).startswith("+") else "DC2626"))

    # Hareket kategorileri tablosu (adet)
    h2 = rr + 3
    ws.cell(h2, 1, "HAREKET ADETLERİ (kategori × yıl)").font = Font(bold=True, size=12, color=KIRMIZI)
    h2 += 1
    for j, h in enumerate(["Kategori / Yıl"] + [str(y) for y in YS] + ["Δ ilk→son"], 1):
        cc = ws.cell(h2, j, h); cc.fill = red; cc.font = white; cc.alignment = Alignment(horizontal="center"); cc.border = thin
    rr = h2
    topl = {y: 0 for y in YS}
    for key, disp in KATEGORILER:
        rr += 1
        ws.cell(rr, 1, disp).font = Font(size=10, bold=(key in ("MalKabul", "MagazaSevk")))
        vals = []
        for j, y in enumerate(YS, 2):
            a = hrk.get(key, {}).get(y, (0, 0))[1]
            topl[y] += a; vals.append(a)
            cc = ws.cell(rr, j, a); cc.border = thin; cc.number_format = "#,##0"
        cc = ws.cell(rr, len(YS) + 2, dpct(vals[0], vals[-1])); cc.border = thin
        cc.font = Font(bold=True, color=("16A34A" if str(cc.value).startswith("+") else "DC2626"))
    rr += 1
    ws.cell(rr, 1, "TOPLAM").font = Font(bold=True)
    tv = []
    for j, y in enumerate(YS, 2):
        cc = ws.cell(rr, j, topl[y]); cc.fill = gri; cc.font = Font(bold=True); cc.border = thin; cc.number_format = "#,##0"; tv.append(topl[y])
    cc = ws.cell(rr, len(YS) + 2, dpct(tv[0], tv[-1])); cc.fill = gri; cc.font = Font(bold=True); cc.border = thin

    ws.column_dimensions["A"].width = 30
    for y in range(len(YS) + 2):
        ws.column_dimensions[get_column_letter(y + 2)].width = 14

    # Yorum
    ir = rr + 2
    top = grv.get("Toplama", {})
    kb = {y: (top[y][2] / top[y][0] if top.get(y) and top[y][0] else 0) for y in YS}
    notes = ["YORUM",
        f"• Toplama kişi-başı adet {tl(kb.get(YS[0],0))} → {tl(kb.get(YS[-1],0))} ({dpct(kb.get(YS[0],0), kb.get(YS[-1],0))}) — operatör verimi.",
        f"• Toplam depo hareketi {tl(tv[0])} → {tl(tv[-1])} adet ({dpct(tv[0], tv[-1])}).",
        "• Personel = o yıl iş yapan distinct WMS operatör (emKisi/pikKisi). Kadro değil, aktif operatör.",
        "• Heykel = Bursa Kültür (firma 56) alışı (depoya giriş). Heykel'e sevk merkez depodan değil (mağaza kaynaklı).",
        "• eTip=16 GENEL Giriş teyit bekliyor (e-tic iade / merkez intake?)."]
    for k, ln in enumerate(notes):
        ws.cell(ir + k, 1, ln).font = Font(bold=True, size=12, color=KIRMIZI) if ln == "YORUM" else Font(size=10)

    # ---- Hareket Detay ----
    hw = wb.create_sheet("Hareket Detay")
    for j, h in enumerate(["Kategori"] + [f"{y} İşlem" for y in YS] + [f"{y} Adet" for y in YS], 1):
        cc = hw.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    for i, (key, disp) in enumerate(KATEGORILER, 2):
        hw.cell(i, 1, disp).font = Font(bold=True, size=10)
        for j, y in enumerate(YS):
            isl, ad = hrk.get(key, {}).get(y, (0, 0))
            c1 = hw.cell(i, 2 + j, isl); c1.number_format = "#,##0"; c1.border = thin
            c2 = hw.cell(i, 2 + len(YS) + j, ad); c2.number_format = "#,##0"; c2.border = thin
    hw.column_dimensions["A"].width = 28
    for k in range(2 * len(YS)):
        hw.column_dimensions[get_column_letter(2 + k)].width = 13

    # ---- Görev İşgücü (detaylı) ----
    gw = wb.create_sheet("Görev İşgücü")
    for j, h in enumerate(["Görev", "Yıl", "Personel", "İşlem", "Adet", "Kişi başı adet"], 1):
        cc = gw.cell(1, j, h); cc.fill = red; cc.font = white; cc.border = thin
    ri = 2
    for gname in ["Raflama", "Toplama"]:
        for y in YS:
            t = grv.get(gname, {}).get(y, (0, 0, 0))
            kbv = (t[2] / t[0]) if t[0] else 0
            for j, v in enumerate([gname, y, t[0], t[1], t[2], round(kbv)], 1):
                cc = gw.cell(ri, j, v); cc.border = thin
                if j >= 3: cc.number_format = "#,##0"
            ri += 1
    for j, w in enumerate([14, 8, 11, 12, 14, 16], 1):
        gw.column_dimensions[get_column_letter(j)].width = w
    ch = BarChart(); ch.title = "Toplama kişi başı adet (verim)"; ch.height = 8; ch.width = 16
    # chart from Görev İşgücü Toplama rows (last len(YS))
    base = 2 + len(YS)
    ch.add_data(Reference(gw, min_col=6, min_row=base, max_row=base + len(YS) - 1))
    ch.set_categories(Reference(gw, min_col=2, min_row=base, max_row=base + len(YS) - 1))
    gw.add_chart(ch, "H2")

    out = R / "briefings" / "depo-isgucu-raporu.xlsx"
    wb.save(out)
    print(f"Excel: {out}")
    for y in YS:
        t = grv.get("Toplama", {}).get(y, (0, 0, 0))
        kbv = (t[2] / t[0]) if t[0] else 0
        print(f"  {y}: hareket {tl(topl[y])} · Toplama {t[0]}p {tl(t[2])} adet (kişi başı {tl(kbv)})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--yillar", nargs="+", type=int, default=[2024, 2025, 2026])
    ap.add_argument("--ay1", type=int, default=1)
    ap.add_argument("--ay2", type=int, default=5)
    a = ap.parse_args()
    build(a.yillar, a.ay1, a.ay2)
