"""
Sipariş-düzeyi geriye dönük simülasyon (sahip önerisi, 2026-10-13): "o gün bu sistem şu kadar sipariş önerseydi ne olurdu?"

Her karar günü D (4 haftada bir Pazartesi, hafta indeksi T), mağaza 1, ürün ürün:
  stok_D, proc önerisi (OneriSiparisAdet) ← bkm.OneriSiparis (o günün satırı)
  talep tahmini (v4: ilk1000 → geo(v3,SES0.5), kuyruk → v3) — YALNIZ [0,T) verisi
  bizim sipariş(q) = max(0, ⌈Q_q(4 hafta talep)⌉ − stok_D)    Q_q: AYAR döneminde kalibre artık-kantili
  gerçekleşen A = sonraki 4 hafta perakende satış (POS − iade)

Skor (politika başına): kaçan satış = max(0, A − (stok+sipariş)) [adet, TL@fiyat];
fazla stok = max(0, stok+sipariş − A) [adet, TL@maliyet]; sipariş adedi; doluluk = min(A, stok+sipariş)/A.

Kıyas: VERİMLİ SINIR — q ızgarası (kaçan satış, fazla stok) eğrisi; proc ve "sipariş yok" noktaları.
Proc'un noktası eğrinin üstündeyse, maliyet varsayımından bağımsız olarak baskın (dominated).

VARSAYIMLAR / SINIRLAR (rapora basılır):
  * Sipariş anında gelir (tedarik süresi 0), yoldaki sipariş yok.
  * Sansür: A, o dönemin GERÇEK stoğuyla gerçekleşti; stok bittiyse A talebin ALT sınırıdır → kaçan satış alt sınır.
  * Proc'un Maximum'u 4 haftadan uzun bir kapsamı hedefliyor olabilir → sipariş adetleri ayrıca raporlanır.
  * Maliyet: bkm.UrunBilgi.SonAlis (bugünkü; yoksa fiyat×0.6).
"""
from __future__ import annotations

import argparse
import sys

import numpy as np
import pandas as pd

import evaluate as E
import forecast as F
import models as M

H = 4
QGRID = (0.5, 0.6, 0.7, 0.8, 0.85, 0.9, 0.95)


class ResidualQuantiles:
    """Katman × hacim kovası başına ölçeklenmiş artık u = (A−F)/sqrt(F+1) örnekleri; herhangi bir q için kantil."""
    def __init__(self): self.s = {}
    def add(self, tier, Fp, A):
        b = E.vol_bucket(Fp); u = (A - Fp) / np.sqrt(Fp + 1)
        for k in np.unique(b): self.s.setdefault((tier, k), []).append(u[b == k])
    def fit(self): self.s = {k: np.sort(np.concatenate(v)) for k, v in self.s.items()}
    def q(self, tier_arr, Fp, q):
        b = E.vol_bucket(Fp); out = np.empty(len(Fp))
        for key in set(zip(tier_arr, b)):
            m = (tier_arr == key[0]) & (b == key[1])
            arr = self.s.get(key)
            qu = np.quantile(arr, q) if arr is not None and len(arr) else 0.0
            out[m] = np.maximum(0, Fp[m] + qu * np.sqrt(Fp[m] + 1))
        return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True); ap.add_argument("--out", required=True)
    ap.add_argument("--cal", nargs=2, type=int, default=(156, 188))   # kalibrasyon (talep) origin'leri
    ap.add_argument("--ayar_end", type=int, default=208)              # politika ayar/test sınırı
    ap.add_argument("--lead-days", type=int, nargs="+", default=[0])  # tedarik süresi (gün) — duyarlılık için birden fazla
    a = ap.parse_args(); O = a.data
    P = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv")
    Y, first, W = P.Y, P.first, P.Y.shape[1]
    ub = pd.read_csv(f"{O}/urunbilgi.csv").set_index("stk")
    katana = ub["katana"].reindex(P.stk).fillna("Bilinmiyor").to_numpy()
    kc = np.unique(katana, return_inverse=True)[1]
    price_ub = ub["fiyat"].reindex(P.stk).to_numpy(float)
    cost = ub["sonalis"].reindex(P.stk).to_numpy(float)
    C, ci = M.category_totals(Y, katana)
    gm = M.GlobalModel(Y, first, ci, C, price_ub, kc.astype(np.float32), use_price=False)
    durum = pd.read_csv(f"{O}/durum.csv")
    pos = {s: i for i, s in enumerate(P.stk)}
    rq = ResidualQuantiles(); rows = []; frontier = []

    def forecast_at(T, idx):
        if gm.trained_at is None or T - gm.trained_at >= 12:
            n = gm.fit(T); print(f"  v3 eğitildi T={T} ({n:,})", file=sys.stderr)
        g = gm.predict(T, idx); s5 = E.ses(Y[idx], T, first[idx], 0.5)
        past52 = Y[:, T - 52:T].sum(1); pop = Y[:, T - 13:T].sum(1) > 0
        order = np.argsort(-np.where(pop, past52, -1)); rank = np.empty(len(Y), int); rank[order] = np.arange(len(Y))
        r = rank[idx]
        tier = np.where(r < 100, "ilk100", np.where(r < 1000, "ilk1000", "kuyruk"))
        Fp = np.where(r < 1000, np.sqrt(np.maximum(g, 0) * np.maximum(s5, 0)), g)
        return Fp, tier

    # 1) artık kalibrasyonu — yalnız talep (stok verisi gerekmez), [cal0, cal1)
    for T in range(a.cal[0], a.cal[1], 4):
        idx = np.nonzero(Y[:, T - 13:T].sum(1) > 0)[0]
        Fp, tier = forecast_at(T, idx); A = Y[idx, T:T + H].sum(1)
        for t in ("ilk100", "ilk1000", "kuyruk"):
            m = tier == t; rq.add(t, Fp[m], A[m])
    rq.fit()

    # 2) karar günleri
    for T, g in durum.groupby("w"):
        if T + H > W: continue
        g = g[g.stk.isin(pos)]
        idx = g.stk.map(pos).to_numpy()
        stok = np.maximum(g.stok.to_numpy(float), 0)
        proc = np.maximum(g.oneri.fillna(0).to_numpy(float), 0)
        price = g.fiyat.fillna(0).to_numpy(float)
        c = np.where(np.isfinite(cost[idx]) & (cost[idx] > 0), cost[idx], price * 0.6)
        A = Y[idx, T:T + H].sum(1)
        Fp, tier = forecast_at(T, idx)
        phase = "ayar" if T < a.ayar_end else "test"

        w1 = Y[idx, T]                                               # ilk haftanın satışı
        for L in a.lead_days:
            d1 = np.minimum(A, w1 * min(L, 7) / 7.0) if L <= 7 else np.minimum(A, Y[idx, T:T + 2].sum(1) * L / 14.0)
            # VARSAYIM: haftalık veri → tedarik süresindeki talep = ilk hafta satışı × L/7 (L ≤ 7)

            def score(policy, order, q=np.nan):
                sold1 = np.minimum(stok, d1); lost1 = d1 - sold1           # tedarik süresi: yalnız mevcut stok
                avail2 = stok - sold1 + order; d2 = A - d1                  # sipariş L. gün gelir
                lost = lost1 + np.maximum(0, d2 - avail2); left = np.maximum(0, avail2 - d2)
                for t in ("ilk100", "ilk1000", "kuyruk", "tümü"):
                    m = np.ones(len(A), bool) if t == "tümü" else (tier == t)
                    rows.append({"T": T, "faz": phase, "L": L, "politika": policy, "q": q, "katman": t, "n": int(m.sum()),
                                 "talep": A[m].sum(), "siparis": order[m].sum(),
                                 "kacan_adet": lost[m].sum(), "kacan_TL": (lost * price)[m].sum(),
                                 "fazla_adet": left[m].sum(), "fazla_TL": (left * c)[m].sum(),
                                 "stoksuz_basla": int((stok[m] == 0).sum())})

            score("sipariş-yok", np.zeros(len(A)))
            score("proc", proc)
            scale = (L + 28) / 28.0                                         # sipariş ufku L + R (R = 28 gün)
            for q in QGRID:
                tgt = np.ceil(rq.q(tier, Fp * scale, q))
                score("ENS-tahmin", np.maximum(0, tgt - stok), q)
        print(f"T={T} {phase} ürün {len(idx):,}", file=sys.stderr)

    df = pd.DataFrame(rows); df.to_csv(a.out + ".csv", index=False)
    pd.set_option("display.width", 220)
    for faz, L in [(f, l) for f in ("ayar", "test") for l in a.lead_days]:
        for t in ("ilk100", "ilk1000", "kuyruk", "tümü"):
            s = df[(df.faz == faz) & (df.L == L) & (df.katman == t)].groupby(["politika", "q"], dropna=False)[
                ["talep", "siparis", "kacan_adet", "kacan_TL", "fazla_adet", "fazla_TL"]].sum()
            s["doluluk"] = 1 - s.kacan_adet / s.talep
            print(f"\n== {faz.upper()} · {t}  (talep {int(s.talep.iloc[0]):,} adet)")
            print((s.drop(columns="talep")).round(3).to_string())


if __name__ == "__main__":
    main()
