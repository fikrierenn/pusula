"""
Eylül 2026 sınaması (sahip isteği): 31.08.2026 sabahı tahmin et (yalnız ≤ 30.08 verisi) → 31.08–27.09 (4 hafta) gerçek satışla karşılaştır.
Yöntemler: 13h-ort (proc mantığı: Miktar90/3), v4 (ilk1000 geo(v3,SES0.5), kuyruk v3), v6⊕SES (sansür+takvim+büyüme).
Aralık: %80 (P10–P90), tahmin-göreli artık kantilleri — T öncesi 6 origin (hedef T'den önce kapanmış).
Sansür: hedef 4 haftada stok bitti mi (yeniden kurulan stok paneli) → bittiyse gerçek satış talebin ALT sınırı.
Kullanım: python eylul.py <data_dir> <çıktı.html>
"""
import datetime as dt
import html
import sys

import numpy as np
import pandas as pd

import evaluate as E
import events as EV
import forecast as F
import models as M
import policy_backtest as PB
import stock as SK

O, OUT = sys.argv[1], sys.argv[2]
H = 4
T = (dt.date(2026, 8, 31) - EV.D0).days // 7          # 273
D_T = EV.D0 + dt.timedelta(weeks=T)

P = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv"); Y, first, W = P.Y, P.first, P.Y.shape[1]
ub = pd.read_csv(f"{O}/urunbilgi.csv").set_index("stk")
katana = ub["katana"].reindex(P.stk).fillna("Bilinmiyor").to_numpy(); kc = np.unique(katana, return_inverse=True)[1]
price = ub["fiyat"].reindex(P.stk).to_numpy(float)
C, ci = M.category_totals(Y, katana)
St = SK.load_stock(f"{O}/stokhareket.csv", P.stk, W); instock = ~SK.censor_flags(St)
evw = {}
for e in EV.events(): evw.setdefault(e["olay"], []).append(e["w"])
g = pd.to_datetime(ub["giris"].reindex(P.stk), errors="coerce"); launch_w = ((g - pd.Timestamp(EV.D0)).dt.days // 7).to_numpy(float)
v3 = M.GlobalModel(Y, first, ci, C, price, kc.astype(np.float32), use_price=False)
v6 = M.GlobalModelV6(Y, first, ci, C, price, kc.astype(np.float32), use_price=False, instock=instock, event_weeks=evw, launch_w=launch_w)


def methods(t, idx):
    for m in (v3, v6):
        if m.trained_at is None or t - m.trained_at >= 12: m.fit(t)
    g3 = v3.predict(t, idx); g6 = v6.predict(t, idx); s5 = E.ses(Y[idx], t, first[idx], 0.5)
    past52 = Y[:, t - 52:t].sum(1); pop = Y[:, t - 13:t].sum(1) > 0
    order = np.argsort(-np.where(pop, past52, -1)); rank = np.empty(len(Y), int); rank[order] = np.arange(len(Y))
    r = rank[idx]; top = r < 1000
    geo = lambda a, b: np.sqrt(np.maximum(a, 0) * np.maximum(b, 0))
    return {"13h-ort (proc mantığı)": E.ma(Y[idx], t, 13), "v4": np.where(top, geo(g3, s5), g3), "v6⊕SES": np.where(top, geo(g6, s5), g6)}, r


cal = {k: PB.ResidualQuantiles() for k in ("13h-ort (proc mantığı)", "v4", "v6⊕SES")}
for t in range(T - 4 - 20, T - 4 + 1, 4):
    idx = np.nonzero(Y[:, t - 13:t].sum(1) > 0)[0]
    fc, r = methods(t, idx); A = Y[idx, t:t + H].sum(1)
    tier = np.where(r < 100, "ilk100", np.where(r < 1000, "ilk1000", "kuyruk"))
    for k, Fp in fc.items():
        for tt in ("ilk100", "ilk1000", "kuyruk"): cal[k].add(tt, Fp[tier == tt], A[tier == tt])
for c in cal.values(): c.fit()

idx = np.nonzero(Y[:, T - 13:T].sum(1) > 0)[0]
fc, r = methods(T, idx); tier = np.where(r < 100, "ilk100", np.where(r < 1000, "ilk1000", "kuyruk"))
A = Y[idx, T:T + H].sum(1); cens = ~instock[idx, T:T + H].all(1)
names = pd.read_csv(f"{O}/adlar.csv").drop_duplicates("stk").set_index("stk")["ad"]

rows = []
for k, Fp in fc.items():
    lo = cal[k].q(tier, Fp, 0.1); hi = cal[k].q(tier, Fp, 0.9)
    for tn, m in (("ilk100", tier == "ilk100"), ("ilk1000", r < 1000), ("kuyruk", tier == "kuyruk"), ("tümü", np.ones(len(idx), bool))):
        a, f, cz = A[m], np.maximum(Fp[m], 0), cens[m]
        fair = np.where(cz, np.maximum(0, a - f), np.abs(f - a))
        rows.append({"yöntem": k, "katman": tn, "ürün": int(m.sum()), "tahmin_toplam": f.sum(), "gerçek_toplam": a.sum(),
                     "toplam_sapma%": 100 * (f.sum() / a.sum() - 1), "WAPE": np.abs(f - a).sum() / a.sum(), "adil_WAPE": fair.sum() / a.sum(),
                     "aralık_kapsama%": 100 * ((a >= lo[m]) & (a <= hi[m])).mean(), "stok_biten_ürün%": 100 * cz.mean()})
summ = pd.DataFrame(rows)
pd.set_option("display.width", 220)
print(f"Origin {D_T} (hafta {T}); hedef {D_T} → {D_T + dt.timedelta(weeks=4)}; ürün {len(idx):,}")
print(summ.round(3).to_string(index=False))

lo4 = cal["v4"].q(tier, fc["v4"], 0.1); hi4 = cal["v4"].q(tier, fc["v4"], 0.9)
det = pd.DataFrame({"sıra": r + 1, "ürün": [names.get(s, "?") for s in P.stk[idx]], "kategori": katana[idx],
                    "13h-ort": fc["13h-ort (proc mantığı)"], "v4": fc["v4"], "v4_%80_aralık": [f"{a:.0f}–{b:.0f}" for a, b in zip(lo4, hi4)],
                    "v6⊕SES": fc["v6⊕SES"], "gerçek": A, "aralıkta": np.where((A >= lo4) & (A <= hi4), "✓", "✗"),
                    "stok_bitti": np.where(cens, "evet (gerçek alt sınır)", "")})
det = det.sort_values("sıra"); det.to_csv(OUT.replace(".html", ".csv"), index=False, encoding="utf-8-sig")
top = det.head(100)
print(top.head(20).to_string(index=False, float_format=lambda v: f"{v:.0f}"))
th = "".join(f"<th>{c}</th>" for c in top.columns)
tr = "".join("<tr>" + "".join(f"<td>{html.escape(f'{v:.0f}' if isinstance(v, float) else str(v))}</td>" for v in rw) + "</tr>" for rw in top.itertuples(index=False))
sh = "".join(f"<th>{c}</th>" for c in summ.columns)
sr = "".join("<tr>" + "".join(f"<td>{html.escape(f'{v:,.3f}' if isinstance(v, float) else str(v))}</td>" for v in rw) + "</tr>" for rw in summ.itertuples(index=False))
open(OUT, "w", encoding="utf-8").write(f"""<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>Eylül 2026 sınaması</title>
<style>body{{font:13px system-ui;margin:16px;background:#fff;color:#111}}@media(prefers-color-scheme:dark){{body{{background:#161616;color:#eee}}}}
table{{border-collapse:collapse;margin-bottom:16px}}td,th{{border-bottom:1px solid #8884;padding:3px 7px;text-align:right;white-space:nowrap}}td:nth-child(2),td:nth-child(3),th:nth-child(2),th:nth-child(3){{text-align:left}}</style></head><body>
<h2>Eylül 2026 sınaması — {D_T:%d.%m.%Y} sabahı tahmin, {D_T:%d.%m} → {(D_T + dt.timedelta(weeks=4)):%d.%m.%Y} gerçek satışla</h2>
<p>Model yalnız {(D_T - dt.timedelta(days=1)):%d.%m.%Y}'e kadarki perakende satışı gördü. Ürünler o güne kadarki 52 hafta satışına göre sıralı (sonuca göre seçim yok).
"stok_bitti" = 4 hafta içinde stok tükendi → gerçek satış talebin ALT sınırı; adil_WAPE bu ürünlerde yalnız eksik tahmini cezalandırır.</p>
<h3>Özet</h3><table><tr>{sh}</tr>{sr}</table>
<h3>İlk 100 ürün</h3><table><tr>{th}</tr>{tr}</table><p>Tamamı: aynı adla .csv</p></body></html>""")
print("→", OUT)
