"""Ürün ürün geçmiş karar günü: proc'un GERÇEK önerisi ↔ yeni sistem (yalnız o güne kadarki veri) ↔ sonraki 4 hafta GERÇEK satış.
Kullanım: python urun_ornek.py <data_dir> <T(hafta)> <çıktı.html> [q=0.7]"""
import datetime as dt
import html
import sys

import numpy as np
import pandas as pd

import evaluate as E
import forecast as F
import models as M
import policy_backtest as PB

O, T, OUT = sys.argv[1], int(sys.argv[2]), sys.argv[3]
Q = float(sys.argv[4]) if len(sys.argv) > 4 else 0.7
H = 4
D = dt.date(2021, 6, 7) + dt.timedelta(weeks=T)

P = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv")
Y, first = P.Y, P.first
ub = pd.read_csv(f"{O}/urunbilgi.csv").set_index("stk")
katana = ub["katana"].reindex(P.stk).fillna("Bilinmiyor").to_numpy()
kc = np.unique(katana, return_inverse=True)[1]
C, ci = M.category_totals(Y, katana)
gm = M.GlobalModel(Y, first, ci, C, ub["fiyat"].reindex(P.stk).to_numpy(float), kc.astype(np.float32), use_price=False)


def fc(t, idx):
    if gm.trained_at is None or t - gm.trained_at >= 12: gm.fit(t)
    g = gm.predict(t, idx); s5 = E.ses(Y[idx], t, first[idx], 0.5)
    past52 = Y[:, t - 52:t].sum(1); pop = Y[:, t - 13:t].sum(1) > 0
    order = np.argsort(-np.where(pop, past52, -1)); rank = np.empty(len(Y), int); rank[order] = np.arange(len(Y))
    r = rank[idx]; tier = np.where(r < 100, "ilk100", np.where(r < 1000, "ilk1000", "kuyruk"))
    return np.where(r < 1000, np.sqrt(np.maximum(g, 0) * np.maximum(s5, 0)), g), tier, r


# Kantil kalibrasyonu: T'den ÖNCEKİ 6 origin (yalnız geçmiş; sonuçları T'den önce kapanmış: t+H ≤ T)
rq = PB.ResidualQuantiles()
for t in range(T - 4 * 7, T - H + 1, 4):
    idx = np.nonzero(Y[:, t - 13:t].sum(1) > 0)[0]
    Fp, tier, _ = fc(t, idx); A = Y[idx, t:t + H].sum(1)
    for k in ("ilk100", "ilk1000", "kuyruk"): rq.add(k, Fp[tier == k], A[tier == k])
rq.fit()

durum = pd.read_csv(f"{O}/durum.csv"); g = durum[durum.w == T]
pos = pd.Series(np.arange(len(P.stk)), index=P.stk); g = g[g.stk.isin(pos.index)]
idx = pos[g.stk].to_numpy()
Fp, tier, rank = fc(T, idx)
lo = rq.q(tier, Fp, 0.1); hi = rq.q(tier, Fp, 0.9); tq = np.ceil(rq.q(tier, Fp, Q))
stok = np.maximum(g.stok.to_numpy(float), 0); proc = np.maximum(g.oneri.fillna(0).to_numpy(float), 0)
biz = np.maximum(0, tq - stok); A = Y[idx, T:T + H].sum(1)
names = pd.read_csv(f"{O}/adlar.csv").drop_duplicates("stk").set_index("stk")["ad"]   # ürün kartı (bkm.UrunBilgi.stkAd); önceki sürüm dünkü listeden alıyordu → satıştan düşenler kategori adıyla görünüyordu
df = pd.DataFrame({"stk": g.stk.to_numpy(), "ürün": [names.get(s, ub["katana"].get(s, "?")) for s in g.stk],
                   "kategori": [ub["katana"].get(s, "?") for s in g.stk], "sıra": rank, "stok": stok,
                   "tahmin": Fp, "aralık": [f"{a:.0f}–{b:.0f}" for a, b in zip(lo, hi)],
                   "proc_sipariş": proc, "yeni_sipariş": biz, "gerçek_4h_satış": A})
for p in ("proc", "yeni"):
    av = df.stok + df[f"{p}_sipariş"]
    df[f"{p}_kaçan"] = np.maximum(0, df.gerçek_4h_satış - av); df[f"{p}_fazla"] = np.maximum(0, av - df.gerçek_4h_satış)
top = df.sort_values("sıra").head(40)


def verdict(r):
    pk, yk = r.proc_kaçan, r.yeni_kaçan
    if yk < pk and r.yeni_fazla <= r.proc_fazla + (pk - yk): return "yeni daha iyi"
    if pk < yk and r.proc_fazla <= r.yeni_fazla + (yk - pk): return "proc daha iyi"
    if pk == yk and r.proc_fazla == r.yeni_fazla: return "aynı"
    return "karışık"


top = top.assign(sonuç=top.apply(verdict, axis=1))
cols = ["ürün", "kategori", "stok", "proc_sipariş", "yeni_sipariş", "tahmin", "aralık", "gerçek_4h_satış", "proc_kaçan", "yeni_kaçan", "proc_fazla", "yeni_fazla", "sonuç"]
print(f"Karar günü {D} (hafta {T}), q={Q}. Sonraki 4 hafta: {D} → {D + dt.timedelta(weeks=4)}")
print(top[cols].head(15).to_string(index=False, float_format=lambda v: f"{v:.0f}"))
summ = top.sonuç.value_counts().to_dict()
tot = {p: (top[f"{p}_sipariş"].sum(), top[f"{p}_kaçan"].sum(), top[f"{p}_fazla"].sum()) for p in ("proc", "yeni")}
print("İlk 40 özet:", summ, "| proc sipariş/kaçan/fazla:", tot["proc"], "| yeni:", tot["yeni"])
rows = "".join("<tr>" + "".join(f"<td>{html.escape(str(r[c]) if c in ('ürün','kategori','aralık','sonuç') else f'{r[c]:.0f}')}</td>" for c in cols) + "</tr>" for _, r in top.iterrows())
th = "".join(f"<th>{c}</th>" for c in cols)
open(OUT, "w", encoding="utf-8").write(f"""<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>Ürün ürün geriye dönük</title>
<style>body{{font:13px system-ui;margin:16px;background:#fff;color:#111}}@media(prefers-color-scheme:dark){{body{{background:#161616;color:#eee}}}}
table{{border-collapse:collapse}}td,th{{border-bottom:1px solid #8884;padding:3px 7px;text-align:right;white-space:nowrap}}td:nth-child(1),td:nth-child(2),th:nth-child(1),th:nth-child(2){{text-align:left}}</style></head><body>
<h2>Karar günü {D} — ilk 40 ürün (o güne kadarki satışa göre)</h2>
<p>stok = o günkü gerçek stok · proc_sipariş = OneriSiparisAdet (gerçek) · yeni_sipariş = ⌈q={Q} kantili⌉ − stok, yalnız {D} öncesi veriyle ·
gerçek_4h_satış = sonraki 4 hafta perakende satış · kaçan/fazla = stok+sipariş ile gerçek satış farkı (tedarik süresi 0 varsayımı; stok bittiyse gerçek talep daha yüksek olabilir).</p>
<p>Özet: {summ} · proc sipariş/kaçan/fazla = {tuple(int(x) for x in tot['proc'])} · yeni = {tuple(int(x) for x in tot['yeni'])}</p>
<table><tr>{th}</tr>{rows}</table></body></html>""")
print("→", OUT)
