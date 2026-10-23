"""
Gerçekçi ikmal simülasyonu (sahip bilgisi, 2026-10-13): depo her iş günü sevk eder; mal ertesi iş günü gelir + 1 gün kabul/rafa çıkış
→ etkin tedarik süresi L = 2 iş günü (duyarlılık 1, 3). Gözden geçirme: haftalık (her Pazartesi sipariş).

Her karar günü T (Pazartesi), ürün ürün, 28 gün gün-gün:
  talep(gün) = o haftanın gerçek perakende satışı / 7   (VARSAYIM: hafta içi eşit dağılım; haftalık veri)
  PROC  : gerçek kuralı (s,S) — stok ≤ Minimum ise Maximum − stok sipariş (679.666 kararın %100'ünde doğrulandı); Min/Max T günündeki değer
  YENİ  : stok + yoldaki < S ise S − (stok + yoldaki);  S = ⌈ Q_q( (7+L)/7 × haftalık tahmin ) ⌉   (order-up-to, kantil 1-hafta artıklarından)
  başlangıç stoğu = T günündeki GERÇEK stok (bkm.OneriSiparis.Stok)
Ölçüt: kaçan satış (adet, TL@fiyat), ortalama stok (TL@maliyet — bağlı sermaye), dönem sonu stok, sipariş adedi/TL, doluluk.
Sansür: geçmiş satış, o dönemin gerçek stoğuyla gerçekleşti → kaçan satış ALT sınır (her iki politika için aynı veri).
"""
from __future__ import annotations

import argparse
import sys

import numpy as np
import pandas as pd

import evaluate as E
import forecast as F
import models as M
import policy_backtest as PB

H = 4
QGRID = (0.5, 0.7, 0.8, 0.9, 0.95)


def simulate(stok0, demand_w, order_fn, L):
    """stok0 [n]; demand_w [n, 4] haftalık talep; order_fn(week, inv, pipeline) → sipariş [n]. Gün-gün, L iş günü (hafta sonu yok sayılır: 7 gün/hafta, sipariş Pzt)."""
    n = len(stok0); inv = stok0.astype(float).copy(); arrivals = {}
    lost = np.zeros(n); ordered = np.zeros(n); inv_sum = np.zeros(n)
    for d in range(28):
        wk = d // 7
        if d % 7 == 0:
            pipe = sum(v for k, v in arrivals.items() if k > d)
            o = np.maximum(0, order_fn(wk, inv, pipe)); ordered += o
            arrivals[d + L] = arrivals.get(d + L, 0) + o
        inv += arrivals.pop(d, 0)
        dem = demand_w[:, wk] / 7.0
        sold = np.minimum(inv, dem); lost += dem - sold; inv -= sold
        inv_sum += inv
    return {"siparis": ordered, "kacan": lost, "son_stok": inv, "ort_stok": inv_sum / 28}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True); ap.add_argument("--out", required=True)
    ap.add_argument("--lead-days", type=int, nargs="+", default=[1, 2, 3])
    ap.add_argument("--ayar_end", type=int, default=208)
    a = ap.parse_args(); O = a.data
    P = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv"); Y, first, W = P.Y, P.first, P.Y.shape[1]
    ub = pd.read_csv(f"{O}/urunbilgi.csv").set_index("stk")
    katana = ub["katana"].reindex(P.stk).fillna("Bilinmiyor").to_numpy(); kc = np.unique(katana, return_inverse=True)[1]
    cost = ub["sonalis"].reindex(P.stk).to_numpy(float)
    C, ci = M.category_totals(Y, katana)
    gm = M.GlobalModel(Y, first, ci, C, ub["fiyat"].reindex(P.stk).to_numpy(float), kc.astype(np.float32), use_price=False)

    def forecast_at(T, idx):
        if gm.trained_at is None or T - gm.trained_at >= 12:
            gm.fit(T); print(f"  v3 eğitildi T={T}", file=sys.stderr)
        g = gm.predict(T, idx); s5 = E.ses(Y[idx], T, first[idx], 0.5)
        past52 = Y[:, T - 52:T].sum(1); pop = Y[:, T - 13:T].sum(1) > 0
        order = np.argsort(-np.where(pop, past52, -1)); rank = np.empty(len(Y), int); rank[order] = np.arange(len(Y))
        r = rank[idx]; tier = np.where(r < 100, "ilk100", np.where(r < 1000, "ilk1000", "kuyruk"))
        return np.where(r < 1000, np.sqrt(np.maximum(g, 0) * np.maximum(s5, 0)), g), tier

    # 1-hafta ufuklu artık kalibrasyonu (yalnız geçmiş origin'ler, hedef T'den önce kapanmış)
    rq = PB.ResidualQuantiles()
    for t in range(156, 188, 4):
        idx = np.nonzero(Y[:, t - 13:t].sum(1) > 0)[0]
        Fp, tier = forecast_at(t, idx); fw = Fp / 4.0
        for k in range(H):                                          # her haftayı ayrı örnek say
            for tt in ("ilk100", "ilk1000", "kuyruk"):
                m = tier == tt; rq.add(tt, fw[m], Y[idx[m], t + k])
    rq.fit()

    durum = pd.read_csv(f"{O}/durum.csv"); pos = pd.Series(np.arange(len(P.stk)), index=P.stk); rows = []
    for T, g in durum.groupby("w"):
        if T + H > W: continue
        g = g[g.stk.isin(pos.index)]; idx = pos[g.stk].to_numpy()
        stok0 = np.maximum(g.stok.to_numpy(float), 0)
        mn = g.mn.fillna(0).to_numpy(float); mx = g.mx.fillna(0).to_numpy(float)
        price = g.fiyat.fillna(0).to_numpy(float)
        c = np.where(np.isfinite(cost[idx]) & (cost[idx] > 0), cost[idx], price * 0.6)
        dem = Y[idx, T:T + H]
        Fp, tier = forecast_at(T, idx); fw = Fp / 4.0
        phase = "ayar" if T < a.ayar_end else "test"
        for L in a.lead_days:
            res = {"proc": simulate(stok0, dem, lambda wk, inv, pipe: np.where(inv + pipe <= mn, mx - inv - pipe, 0), L)}
            for q in QGRID:
                S = np.ceil(rq.q(tier, fw * (7 + L) / 7.0, q))
                res[f"yeni q={q}"] = simulate(stok0, dem, lambda wk, inv, pipe, S=S: np.where(inv + pipe < S, S - inv - pipe, 0), L)
            for pol, r in res.items():
                for t in ("ilk100", "ilk1000", "kuyruk", "tümü"):
                    m = np.ones(len(idx), bool) if t == "tümü" else (tier == t)
                    rows.append({"T": T, "faz": phase, "L": L, "politika": pol, "katman": t, "talep": dem[m].sum(),
                                 "siparis": r["siparis"][m].sum(), "siparis_TL": (r["siparis"] * c)[m].sum(),
                                 "kacan": r["kacan"][m].sum(), "kacan_TL": (r["kacan"] * price)[m].sum(),
                                 "ort_stok_TL": (r["ort_stok"] * c)[m].sum(), "son_stok_TL": (r["son_stok"] * c)[m].sum()})
        print(f"T={T} {phase} ürün {len(idx):,}", file=sys.stderr)
    df = pd.DataFrame(rows); df.to_csv(a.out + ".csv", index=False)
    pd.set_option("display.width", 220)
    for L in a.lead_days:
        for t in ("ilk100", "ilk1000", "kuyruk", "tümü"):
            s = df[(df.faz == "test") & (df.L == L) & (df.katman == t)].groupby("politika")[
                ["talep", "siparis", "siparis_TL", "kacan", "kacan_TL", "ort_stok_TL", "son_stok_TL"]].sum()
            ndays = df[(df.faz == "test") & (df.L == L)]["T"].nunique()   # BUG düzeltildi: .T transpoz idi
            s["doluluk"] = 1 - s.kacan / s.talep
            s["ort_stok_TL"] = s.ort_stok_TL / ndays          # karar günü başına ortalama bağlı sermaye
            print(f"\n== TEST · L={L} iş günü · {t} ({ndays} karar günü, talep {int(s.talep.iloc[0]):,})")
            print(s.drop(columns="talep").round(0).to_string(float_format=lambda v: f"{v:,.0f}"))


if __name__ == "__main__":
    main()
