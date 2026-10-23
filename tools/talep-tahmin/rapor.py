"""Talep tahmini araştırma raporu (HTML, tek dosya, bağımlılıksız SVG). Girdi: .cache/talep-tahmin/* çıktıları."""
from __future__ import annotations

import datetime as dt
import html
import sys

import numpy as np
import pandas as pd

import events as EV

O = sys.argv[1] if len(sys.argv) > 1 else "D:/Dev/pusula/.cache/talep-tahmin"
OUT = sys.argv[2] if len(sys.argv) > 2 else "D:/Dev/pusula/raporlar/2026-10-13-talep-tahmin.html"
RUN = sys.argv[3] if len(sys.argv) > 3 else "v6"

COL = {"okul": "#2563eb", "bayram": "#dc2626", "özel gün": "#db2777", "kampanya": "#d97706", "resmî tatil": "#6b7280"}
SIG = pd.read_csv(f"{O}/olay_etkisi.csv")
SIG["anlamlı"] = np.where(SIG.GA_alt > 1.05, "↑", np.where(SIG.GA_üst < 0.95, "↓", ""))
SIGSET = set(SIG[SIG.anlamlı != ""].olay)
EVS = pd.DataFrame(EV.events())


def esc(s): return html.escape(str(s))


def season_chart(df, seri, w=1100, h=250):
    x = df[df.seri == seri].sort_values("w")
    W = x.w.max() + 1; ymax = np.nanpercentile(x.satis, 99.5) * 1.05
    X = lambda i: 40 + (w - 50) * i / (W - 1); Yp = lambda v: h - 25 - (h - 40) * min(v, ymax) / ymax
    sv = [f'<svg viewBox="0 0 {w} {h}" width="100%" role="img">']
    for _, e in EVS.iterrows():
        if 0 <= e.w < W:
            op = 0.9 if e.olay in SIGSET else 0.25
            dash = "" if e.dogrulama != "bilgi" else ' stroke-dasharray="3 3"'
            sv.append(f'<line x1="{X(e.w):.1f}" x2="{X(e.w):.1f}" y1="12" y2="{h-25}" stroke="{COL.get(e.tur, "#999")}" stroke-opacity="{op}"{dash}><title>{esc(e.olay)} {e.tarih} ({e.dogrulama})</title></line>')
    pts = " ".join(f"{X(i):.1f},{Yp(v):.1f}" for i, v in zip(x.w, x.satis))
    sv.append(f'<polyline points="{pts}" fill="none" stroke="var(--ink)" stroke-width="1.4"/>')
    for yr in range(2022, 2027):
        wi = (dt.date(yr, 1, 1) - EV.D0).days // 7
        if 0 <= wi < W: sv.append(f'<text x="{X(wi):.1f}" y="{h-8}" text-anchor="middle">{yr}</text>')
    sv.append(f'<text x="40" y="10">{esc(seri)} — haftalık perakende satış (adet)</text></svg>')
    return "".join(sv)


def heatmap(df, seri):
    x = df[(df.seri == seri) & df.yil.between(2021, 2026)]
    piv = x.pivot_table(index="yil", columns="isohafta", values="endeks")
    cw, ch = 19, 22; w = 60 + cw * 53; h = 30 + ch * len(piv)
    sv = [f'<svg viewBox="0 0 {w} {h}" width="100%" role="img"><text x="0" y="12">{esc(seri)} — sezon endeksi (yerel tabana oran; kırmızı ↑, mavi ↓)</text>']
    for r, (yr, row) in enumerate(piv.iterrows()):
        sv.append(f'<text x="0" y="{30+ch*r+15}">{yr}</text>')
        for c in range(1, 54):
            v = row.get(c, np.nan)
            if not np.isfinite(v): continue
            t = np.clip(np.log(v) / np.log(3), -1, 1)
            col = f"rgba(220,38,38,{t:.2f})" if t > 0 else f"rgba(37,99,235,{-t:.2f})"
            sv.append(f'<rect x="{60+cw*(c-1)}" y="{30+ch*r}" width="{cw-1}" height="{ch-1}" fill="{col}"><title>{yr} hafta {c}: ×{v:.2f}</title></rect>')
    for c in (1, 10, 20, 30, 36, 40, 52):
        sv.append(f'<text x="{60+cw*(c-1)}" y="{h}" font-size="9">H{c}</text>')
    return "".join(sv) + "</svg>"


def table(d, fmt=None):
    fmt = fmt or {}
    th = "".join(f"<th>{esc(c)}</th>" for c in d.columns)
    rows = []
    for _, r in d.iterrows():
        tds = "".join(f"<td>{esc(fmt[c](r[c]) if c in fmt else r[c])}</td>" for c in d.columns)
        rows.append(f"<tr>{tds}</tr>")
    return f'<div class="wrap"><table><tr>{th}</tr>{"".join(rows)}</table></div>'


def main():
    df = pd.read_csv(f"{O}/sezon_endeks.csv", parse_dates=["tarih"])
    pts = pd.read_csv(f"{O}/{RUN}.points.csv"); qd = pd.read_csv(f"{O}/{RUN}.quantiles.csv")
    pol = pd.read_csv(f"{O}/policy.csv")
    sb = ["""<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>BKM Talep Tahmini</title><style>
:root{--bg:#f7f7f5;--card:#fff;--ink:#1c1c1a;--mut:#6b6b66;--line:#e3e2dc}
@media (prefers-color-scheme:dark){:root{--bg:#141413;--card:#1e1e1c;--ink:#ecebe6;--mut:#a3a29b;--line:#34332f}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.5 system-ui,"Segoe UI",sans-serif}
main{max-width:1180px;margin:0 auto;padding:24px 16px 64px}h1{font-size:24px;margin:0 0 4px}h2{font-size:17px;margin:0 0 8px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:16px;margin-top:14px}.mut{color:var(--mut)}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}th,td{padding:4px 8px;border-bottom:1px solid var(--line);text-align:right;white-space:nowrap}
th:first-child,td:first-child{text-align:left}th{color:var(--mut);font-size:12px}.wrap{overflow-x:auto}svg text{fill:var(--mut);font-size:11px}
.lg span{display:inline-block;margin-right:14px}.lg i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:4px;vertical-align:-1px}
</style></head><body><main>"""]
    sb.append(f"""<h1>BKM mağaza 1 — talep tahmini araştırması</h1>
<p class="mut">Perakende talep = POS satış − POS iade (toplu/fatura satışları ve stoksuz ürünler hariç) · 2021-06 → 2026-10, 279 hafta ·
rolling-origin: AYAR 2024-06…2025-06, TEST 2025-06…2026-09 · üretildi {dt.datetime.now():%d.%m.%Y %H:%M}</p>""")
    lg = "".join(f'<span><i style="background:{c}"></i>{t}</span>' for t, c in COL.items())
    sb.append(f'<div class="card"><h2>1 · Sezonlar ve mini sezonlar</h2><p class="lg">{lg}<span>— koyu çizgi: veride anlamlı etkisi ölçülen olay · soluk: anlamlı etki yok · kesikli: tarih DOĞRULANMADI</span></p>')
    for s in ("MAĞAZA", "Kırtasiye / Hediyelik", "Kitap", "Oyuncak / Elektronik"):
        sb.append(season_chart(df, s))
    sb.append("</div>")
    sb.append('<div class="card"><h2>2 · Sezon ısı haritası (yıl × ISO hafta)</h2><p class="mut">Okul açılışı tepesi 2021-23\'te H34-36, 2024-26\'da H36-38 — sezon kayıyor; "geçen yılın aynı haftası" bu yüzden yanılıyor.</p>')
    for s in ("Kırtasiye / Hediyelik", "Kitap", "Oyuncak / Elektronik"):
        sb.append(heatmap(df, s))
    sb.append("</div>")
    s2 = SIG[SIG.anlamlı != ""].copy()
    s2["etki"] = (s2.ort_endeks - 1).map(lambda v: f"{v:+.0%}")
    s2["%95 GA"] = s2.apply(lambda r: f"[{r.GA_alt - 1:+.0%}, {r.GA_üst - 1:+.0%}]", axis=1)
    sb.append('<div class="card"><h2>3 · Olay etkileri (event study)</h2><p class="mut">Hafta endeksi = satış / 13 haftalık merkezli medyan. Yıl başına bir gözlem; bootstrap %95 GA. "bilgi" = tarih Claude\'un bilgisi, kaynakla doğrulanmadı.</p>')
    sb.append(table(s2[["olay", "seri", "hafta", "yıl", "etki", "%95 GA", "doğrulama"]].sort_values(["olay", "seri"])))
    none = sorted(set(SIG.olay) - SIGSET)
    sb.append(f'<p class="mut">Kategori düzeyinde anlamlı etkisi bulunamayan: {esc(", ".join(none))}.</p></div>')
    tst = pts[pts.faz == "test"]; aya = pts[pts.faz == "ayar"]
    keep = [m for m in tst.yöntem.unique() if m.startswith(("v3:global-GBM(fiyatsız)", "v4:geo", "v5", "v6")) or m in ("MA(13)", "SES(0.5)", "MA(4)", "mevsimsel-naive")]
    sb.append('<div class="card"><h2>4 · Model yarışı (TEST; sıralama AYAR WAPE\'ine göre)</h2><p class="mut">MA(13) = Miktar90/3 karşılığı (proc\'un kendisi değil). "sansürsüz" = hedef penceresinde stok hiç bitmemiş.</p>')
    for kt in [k for k in ("ilk100·sansürsüz", "ilk1000·sansürsüz", "kuyruk·sansürsüz", "tümü·sansürsüz", "tümü") if k in set(tst.katman)]:
        t = tst[(tst.katman == kt) & tst.yöntem.isin(keep)].groupby("yöntem").agg(WAPE=("WAPE", "mean"), bias=("bias", "mean"), band=("band", "mean"))
        q = qd[(qd.katman == kt) & qd.yöntem.isin(keep)].groupby("yöntem").agg(kapsama80=("kapsama80", "mean"), pinball=("pinball", "mean"))
        v = aya[(aya.katman == kt) & aya.yöntem.isin(keep)].groupby("yöntem").WAPE.mean().rename("ayar_WAPE")
        t = t.join(q).join(v).sort_values("ayar_WAPE").reset_index()
        sb.append(f"<h2 style='margin-top:12px;font-size:15px'>{esc(kt)}</h2>")
        sb.append(table(t, {c: (lambda v: f"{v:.3f}") for c in ("WAPE", "bias", "band", "kapsama80", "pinball", "ayar_WAPE")}))
    sb.append("""<p><b>Okuma (dürüst):</b> TÜM pencerelerde v6 (sansür+takvim+büyüme ⊕ SES) en iyi görünüyor — ilk100 WAPE 0.533→0.495,
büyük hatalar (sRMSE) −%21. Ama <b>sansürsüz</b> pencerelerde (gerçek talebin bilindiği yer) kazanç çoğunlukla kayboluyor (ilk100 0.426 vs 0.430).
Kazanç stoğun bittiği haftalarda yoğun; orada gerçek satış talebin ALT sınırı olduğu için daha düşük tahmin yapay olarak iyi skor alabilir.
Sezon tepeleri (okul açılışı) aynı zamanda stoğun en çok bittiği dönem → "takvim sezonda yardım ediyor" iddiası şu an sansürle karışık, KANITLANMADI.
Sıradaki: sansürlü pencerelerde tek-yönlü hata (yalnız tahmin &lt; satış ise ceza) + sezon haftaları ayrı ölçüm.</p>""")
    sb.append("</div>")
    tp = pol[(pol.faz == "test") & (pol.katman == "tümü")].groupby(["politika", "q"], dropna=False)[["talep", "siparis", "kacan_adet", "kacan_TL", "fazla_TL"]].sum().reset_index()
    tp["doluluk"] = 1 - tp.kacan_adet / tp.talep
    sb.append('<div class="card"><h2>5 · Sipariş simülasyonu (TEST, 17 karar günü, tüm ürünler)</h2><p class="mut">Tedarik süresi 0 varsayımı; kaçan satış sansür nedeniyle alt sınır. v4 tahmincisi.</p>')
    sb.append(table(tp.drop(columns="talep"), {"siparis": lambda v: f"{v:,.0f}", "kacan_adet": lambda v: f"{v:,.0f}", "kacan_TL": lambda v: f"{v/1e6:,.1f} M", "fazla_TL": lambda v: f"{v/1e6:,.1f} M", "doluluk": lambda v: f"{v:.1%}", "q": lambda v: "" if pd.isna(v) else f"{v:.2f}"}))
    sb.append("</div>")
    sb.append("""<div class="card"><h2>6 · Sınırlar</h2><ul>
<li>Tek mağaza (mağaza 1). Toplu satışlar talepten çıkarıldı (ayrı tahmin edilmeli).</li>
<li>Sansür: stoksuz haftaların talebi görünmez; v5 bunu modele ve ölçüme katıyor, ama sansürlü pencerelerde gerçek talep hâlâ bilinmiyor.</li>
<li>Takvim: bazı bayram/okul/ara tatil tarihleri kaynakla doğrulanmadı (kesikli çizgi). pusula/scripts/forecast/calendar_reg.py ile aynı bayram tablosu kullanıldı.</li>
<li>Sipariş simülasyonu: tedarik süresi ve yoldaki sipariş yok; maliyet bugünkü SonAlis.</li>
<li>pusula/scripts/forecast (toplam satış, büyüme/GLM) ile hiyerarşik uzlaştırma henüz yapılmadı.</li></ul></div></main></body></html>""")
    with open(OUT, "w", encoding="utf-8") as f: f.write("".join(sb))
    print("→", OUT)


if __name__ == "__main__":
    main()
