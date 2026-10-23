"""
v1.1+ değerlendirme — doğrulama/test ayrımı, parametre ayarı, olasılıksal tahmin, katmanlı rapor.

Tasarım (bilimsel kontrol):
  * Origin'ler iki DÖNEME ayrılır: AYAR (val) [156, 208) ve TEST [208, W−H]. Parametre/yöntem seçimi
    yalnız AYAR'da; rapor yalnız TEST'te → "aynı veride ayarla-ölç" iyimserliği yok.
  * Nokta ölçütleri: WAPE (MAE-tabanlı; seyrek talepte sıfıra yakın tahmini ödüllendirir — Kolassa 2016),
    RMSE-tabanlı ölçeklenmiş hata (ortalamayı ödüllendirir), bias. Band isabeti TÜM kararlarda:
    F>0 → |A−F| ≤ 0.5F; F=0 → A=0.
  * Olasılıksal: tahmin-göreli artık dağılımından (A/F, segment×hacim kovası) empirik kantiller, AYAR'da
    kalibre edilir (split-conformal benzeri, Angelopoulos & Bates 2021), TEST'te kapsama + pinball loss.
  * Katman: origin'de yalnız geçmiş 52 hafta adedine göre ilk100 / ilk1000 / kuyruk (geleceğe bakmaz).
"""
from __future__ import annotations

import argparse
import sys

import numpy as np
import pandas as pd

import forecast as F
import models as M

H = F.H
QS = (0.1, 0.5, 0.9)
PRED_DIR = None          # ayarlanırsa her origin'in ürün-bazlı tahminleri .npz olarak kaydedilir (yeniden-ölçüm için)
SEASON_FN = None         # T → "sezon:<olaylar>" / "normal"
MAJOR = ("Okul açılışı", "Yarıyıl tatili", "Yaz karnesi", "Yılbaşı", "Ramazan Bayramı", "Kurban Bayramı")


def make_season_fn():
    import events as EV
    ev = [(e["olay"], e["w"]) for e in EV.events() if e["olay"] in MAJOR]
    def f(T):
        hit = sorted({o for o, w in ev if T - 1 <= w < T + H})      # pencere + bir hafta önce (okul öncesi tepe)
        return "sezon:" + "+".join(hit) if hit else "normal"
    return f


# ───────────── yöntemler (parametreli) ─────────────
def ma(Y, T, k):
    return Y[:, max(0, T - k):T].sum(1) / k * H


def ses(Y, T, first, alpha):
    return F.m_ses(Y, T, first, alpha)


def croston_init(Y, T, first, alpha, beta, warm=13):
    """Croston/SBA/TSB — ısınma penceresiyle başlatma (ilk `warm` hafta ortalaması; tek-satış önyargısı azalır)."""
    n = Y.shape[0]
    z = np.zeros(n); p = np.ones(n); q = np.zeros(n); zt = np.zeros(n); pi = np.zeros(n)
    started = np.zeros(n, bool)
    for t in range(T):
        y = Y[:, t]; d = y > 0
        born = (~started) & (first + warm <= t)               # ısınma bitince başlat
        if born.any():
            idx = np.nonzero(born)[0]
            W = np.stack([Y[i, first[i]:first[i] + warm] for i in idx]) if len(idx) < 2000 else None
            if W is None:
                cols = first[idx][:, None] + np.arange(warm)[None, :]
                W = Y[idx[:, None], cols]
            k = (W > 0).sum(1); s = W.sum(1)
            z[idx] = np.where(k > 0, s / np.maximum(k, 1), 0)
            p[idx] = np.where(k > 0, warm / np.maximum(k, 1), warm)
            zt[idx] = z[idx]; pi[idx] = k / warm; q[idx] = 0
            started |= born
        # BUG (2026-10-13, düzeltildi): burada `continue` vardı → doğum olan HER hafta tüm ürünlerin
        # güncellemesi atlanıyordu; parametreler sonucu değiştirmiyordu (4 kombinasyon birebir aynı).
        act = started & ~born
        q[act] += 1
        hit = act & d
        z[hit] = alpha * y[hit] + (1 - alpha) * z[hit]
        p[hit] = alpha * q[hit] + (1 - alpha) * p[hit]
        q[hit] = 0
        pi[act] = beta * d[act] + (1 - beta) * pi[act]
        zt[hit] = alpha * y[hit] + (1 - alpha) * zt[hit]
    young = ~started                                            # ısınmayı bitirmemiş ürün → MA(4)
    cro = np.where(young, ma(Y, T, 4) / H, z / p)
    sba = np.where(young, ma(Y, T, 4) / H, (1 - alpha / 2) * z / p)
    tsb = np.where(young, ma(Y, T, 4) / H, pi * zt)
    return cro * H, sba * H, tsb * H


# ───────────── ölçüm ─────────────
def band_all(F_, A):
    F_ = np.maximum(F_, 0)
    return np.where(F_ > 0, np.abs(A - F_) <= 0.5 * F_ + 1e-9, A == 0)


def point_metrics(F_, A, cens=None):
    """cens: True = hedef penceresinde stok bitti → A gerçek talebin ALT sınırı. Adil hata (cWAPE): sansürsüzde |F−A|,
    sansürlüde max(0, A−F) (gerçek hatanın alt sınırı; düşük tahmin yapay avantaj kazanamaz, yüksek tahmin haksız ceza almaz)."""
    F_ = np.maximum(F_, 0); sA = A.sum(); e = F_ - A
    out = {"n": len(A), "WAPE": np.abs(e).sum() / sA, "bias": e.sum() / sA,
           "sRMSE": np.sqrt((e ** 2).mean()) / max(A.mean(), 1e-9), "band": band_all(F_, A).mean()}
    if cens is not None:
        ce = np.where(cens, np.maximum(0, A - F_), np.abs(e))
        out["cWAPE"] = ce.sum() / sA
        out["c_sRMSE"] = np.sqrt((ce ** 2).mean()) / max(A.mean(), 1e-9)
        out["sansür_oranı"] = float(cens.mean())
    return out


def pinball(q, Fq, A):
    d = A - Fq
    return np.maximum(q * d, (q - 1) * d).mean()


# ───────────── olasılıksal katman: tahmin-göreli artık kantilleri ─────────────
def vol_bucket(Fp):
    return np.digitize(Fp, [0.5, 2, 5, 15, 50])               # 6 hacim kovası


class QuantileCalibrator:
    """AYAR origin'lerinde (yöntem, hacim kovası) başına A − F artıklarının kantilleri ölçeklenmiş olarak saklanır:
       u = (A − F) / sqrt(F + 1)  (Poisson-benzeri varyans ölçeği). Kantil(F) = max(0, F + Q_u · sqrt(F+1))."""
    def __init__(self): self.store = {}
    def add(self, key, Fp, A):
        b = vol_bucket(Fp); u = (A - Fp) / np.sqrt(Fp + 1)
        for k in np.unique(b): self.store.setdefault((key, k), []).append(u[b == k])
    def fit(self):
        self.q = {k: np.quantile(np.concatenate(v), QS) for k, v in self.store.items()}
    def predict(self, key, Fp):
        b = vol_bucket(Fp); out = np.zeros((len(QS), len(Fp)))
        for k in np.unique(b):
            m = b == k; qu = self.q.get((key, k), np.zeros(len(QS)))
            out[:, m] = np.maximum(0, Fp[m][None, :] + qu[:, None] * np.sqrt(Fp[m] + 1)[None, :])
        return np.round(out)                                    # adet tamsayıdır


def candidates(Ys, T, fs):
    out = {f"MA({k})": ma(Ys, T, k) for k in (4, 8, 13, 26)}
    for a in (0.1, 0.2, 0.3, 0.5):
        out[f"SES({a})"] = ses(Ys, T, fs, a)
    for a, b in ((0.1, 0.05), (0.1, 0.1), (0.2, 0.1), (0.2, 0.2)):
        cro, sba, tsb = croston_init(Ys, T, fs, a, b)
        out[f"SBA({a})"] = sba; out[f"TSB({a},{b})"] = tsb
    out["Croston(0.1)"] = croston_init(Ys, T, fs, 0.1, 0.05)[0]
    out["mevsimsel-naive"] = F.m_snaive(Ys, T)
    return out


def seasonal_ratio_k(C, T, k, kappa=200.0):
    """Kategori sezon çarpanı: geçen 1-2 yılın [T−52y, +H) toplamı / [T−52y−k, T−52y) penceresinin H'ye ölçeklenmişi.
    Taban yöntemin etkin penceresi k ile eşlenir (MA(4) → k=4; SES(0.5) ≈ 3 hafta)."""
    num = np.zeros(C.shape[0]); den = np.zeros(C.shape[0])
    for y in (1, 2):
        a = T - 52 * y
        if a - k < 0: continue
        num += C[:, a:a + H].sum(1); den += C[:, a - k:a].sum(1) / k * H
    with np.errstate(divide="ignore", invalid="ignore"):
        r = np.where((num > 0) & (den > 0), num / den, 1.0)
    return np.exp(np.log(r) * den / (den + kappa))


def make_extra(P, urunbilgi_path, use_v3, stok_path=None):
    ub = pd.read_csv(urunbilgi_path).set_index("stk")
    katana = ub["katana"].reindex(P.stk).fillna("Bilinmiyor").to_numpy()
    kcodes, kc = np.unique(katana, return_inverse=True)
    price = ub["fiyat"].reindex(P.stk).to_numpy(dtype=np.float64)
    C, ci = M.category_totals(P.Y, katana)
    gm = M.GlobalModel(P.Y, P.first, ci, C, price, kc.astype(np.float32)) if use_v3 else None
    gm_np = M.GlobalModel(P.Y, P.first, ci, C, price, kc.astype(np.float32), use_price=False) if use_v3 else None
    v56 = {}
    if stok_path:
        import stock as SK, events as EV, datetime as _dt
        St = SK.load_stock(stok_path, P.stk, P.Y.shape[1]); instock = ~SK.censor_flags(St)
        evw = {}
        for e in EV.events(): evw.setdefault(e["olay"], []).append(e["w"])
        g = pd.to_datetime(ub["giris"].reindex(P.stk), errors="coerce")
        launch_w = ((g - pd.Timestamp(EV.D0)).dt.days // 7).to_numpy(float)
        base = dict(use_price=False, instock=instock, event_weeks=evw, launch_w=launch_w)
        v56 = {"v5:+sansür": M.GlobalModelV6(P.Y, P.first, ci, C, price, kc.astype(np.float32), use_v6=False, **base),
               "v6:+sansür+takvim+büyüme": M.GlobalModelV6(P.Y, P.first, ci, C, price, kc.astype(np.float32), **base)}
        P.instock = instock
    print(f"kategori {len(kcodes)} · fiyatsız ürün {np.isnan(price).sum():,} · v3={'açık' if use_v3 else 'kapalı'}", file=sys.stderr)

    def extra(T, idx):
        Ys, fs = P.Y[idx], P.first[idx]
        out = {}
        r4 = seasonal_ratio_k(C, T, 4)[ci[idx]]; r3 = seasonal_ratio_k(C, T, 3)[ci[idx]]
        out["v2:MA(4)×sezon"] = ma(Ys, T, 4) * r4
        out["v2:SES(0.5)×sezon"] = ses(Ys, T, fs, 0.5) * r3
        out["v2:TSB(0.2,0.2)×sezon"] = croston_init(Ys, T, fs, 0.2, 0.2)[2] * r4
        if gm is not None:
            if gm_np.trained_at is None or T - gm_np.trained_at >= 12: gm_np.fit(T)
            g = gm_np.predict(T, idx); out["v3:global-GBM(fiyatsız)"] = g
            s5 = ses(Ys, T, fs, 0.5)
            out["v4:ort(v3,SES0.5)"] = (g + s5) / 2                                   # eşit ağırlık (Clemen 1989)
            out["v4:geo(v3,SES0.5)"] = np.sqrt(np.maximum(g, 0) * np.maximum(s5, 0))  # geometrik — çarpımsal hataya dayanıklı
            r = np.argsort(np.argsort(-Ys[:, T - 52:T].sum(1)))                       # katman (yalnız geçmiş)
            out["v4:katmanlı"] = np.where(r < 1000, (g + s5) / 2, g)
            for nm, mdl in v56.items():
                if mdl.trained_at is None or T - mdl.trained_at >= 12:
                    n = mdl.fit(T); print(f"  {nm} eğitildi T={T} satır={n:,}", file=sys.stderr)
                gv = mdl.predict(T, idx); out[nm] = gv
                out[nm + " ⊕SES(geo,ilk1000)"] = np.where(r < 1000, np.sqrt(np.maximum(gv, 0) * np.maximum(s5, 0)), gv)
        return out
    return extra


def tiers(Ys, T):
    past52 = Ys[:, T - 52:T].sum(1)
    rank = np.argsort(-past52, kind="stable"); r = np.empty_like(rank); r[rank] = np.arange(len(rank))
    return {"ilk100": r < 100, "ilk1000": r < 1000, "kuyruk": r >= 1000, "tümü": np.ones(len(Ys), bool)}


def run(weekly, toplu, exclude, out, val=(156, 208), every=4, extra_factory=None):
    P = F.load_panel(weekly, toplu, exclude)
    Y, first = P.Y, P.first; W = Y.shape[1]
    extra = extra_factory(P) if extra_factory else None
    origins = list(range(val[0], W - H + 1, every))
    print(f"ürün {len(P.stk):,} · hafta {W} · origin {len(origins)} (ayar <{val[1]} ≤ test)", file=sys.stderr)
    rows = []; cal = QuantileCalibrator(); test_cache = []
    for T in origins:
        pop = Y[:, T - 13:T].sum(1) > 0
        idx = np.nonzero(pop)[0]; Ys, fs = Y[idx], first[idx]
        A = Ys[:, T:T + H].sum(1)
        fc = candidates(Ys, T, fs)
        if extra: fc.update(extra(T, idx))
        phase = "ayar" if T < val[1] else "test"
        tr = tiers(Ys, T)
        unc = P.instock[idx, T:T + H].all(1) if getattr(P, "instock", None) is not None else None
        cens = ~unc if unc is not None else None
        sezon = SEASON_FN(T) if SEASON_FN else ""
        if unc is not None:
            tr = {**tr, **{k + "·sansürsüz": v & unc for k, v in list(tr.items())}}
        if PRED_DIR and unc is not None:
            np.savez_compressed(f"{PRED_DIR}/T{T}.npz", idx=idx, A=A, cens=cens,
                                **{k.replace(":", "_").replace(" ", "_"): np.maximum(v, 0).astype(np.float32) for k, v in fc.items()})
        for name, Fp in fc.items():
            Fp = np.maximum(Fp, 0)
            if phase == "ayar":
                # BUG (düzeltildi): `~False` → -1 → bool & -1 tamsayı indeksine dönüşüyordu (kalibrasyon 2 üründen).
                for key, m in (("ilk100", tr["ilk100"]), ("ilk1000", tr["ilk1000"] & ~tr["ilk100"]), ("kuyruk", tr["kuyruk"])):
                    assert m.dtype == bool
                    cal.add((name, key), Fp[m], A[m])
            for tn, m in tr.items():
                rows.append({"faz": phase, "T": T, "sezon": sezon, "yöntem": name, "katman": tn,
                             **point_metrics(Fp[m], A[m], cens[m] if cens is not None else None)})
        if phase == "test": test_cache.append((T, fc, A, tr))
    cal.fit()
    qrows = []
    for T, fc, A, tr in test_cache:
        for name, Fp in fc.items():
            Fp = np.maximum(Fp, 0); Q = np.zeros((len(QS), len(Fp)))
            m100 = tr["ilk100"]; m1000 = tr["ilk1000"] & ~m100; mk = tr["kuyruk"]
            for key, m in (("ilk100", m100), ("ilk1000", m1000), ("kuyruk", mk)):
                if m.any(): Q[:, m] = cal.predict((name, key), Fp[m])
            for tn, m in tr.items():
                qrows.append({"T": T, "yöntem": name, "katman": tn,
                              "kapsama80": float(((A[m] >= Q[0, m]) & (A[m] <= Q[2, m])).mean()),
                              "pinball": float(np.mean([pinball(q, Q[i, m], A[m]) for i, q in enumerate(QS)]))})
    df = pd.DataFrame(rows); qd = pd.DataFrame(qrows)
    df.to_csv(out + ".points.csv", index=False); qd.to_csv(out + ".quantiles.csv", index=False)
    return df, qd


def report(df, qd):
    pd.set_option("display.width", 220)
    # ayar fazında katman başına en iyi (WAPE) yöntem; test fazında rapor
    for tn in [k for k in ("ilk100", "ilk1000", "kuyruk", "tümü", "ilk100·sansürsüz", "ilk1000·sansürsüz", "kuyruk·sansürsüz", "tümü·sansürsüz") if k in set(df.katman)]:
        v = df[(df.faz == "ayar") & (df.katman == tn)].groupby("yöntem").WAPE.mean().sort_values()
        t = df[(df.faz == "test") & (df.katman == tn)].groupby("yöntem").agg(
            n=("n", "sum"), WAPE=("WAPE", "mean"), bias=("bias", "mean"), sRMSE=("sRMSE", "mean"), band=("band", "mean"))
        q = qd[qd.katman == tn].groupby("yöntem").agg(kapsama80=("kapsama80", "mean"), pinball=("pinball", "mean"))
        t = t.join(q).join(v.rename("ayar_WAPE")).sort_values("ayar_WAPE")
        print(f"\n== {tn} — TEST (n={int(t.n.iloc[0]):,}); sıralama AYAR WAPE'ine göre (seçim testten bağımsız)")
        print(t.drop(columns="n").round(3).to_string())


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("weekly"); ap.add_argument("--toplu"); ap.add_argument("--exclude"); ap.add_argument("--out", required=True)
    ap.add_argument("--urunbilgi"); ap.add_argument("--v3", action="store_true"); ap.add_argument("--stok")
    ap.add_argument("--pred-dir")
    a = ap.parse_args()
    if a.pred_dir:
        import os; os.makedirs(a.pred_dir, exist_ok=True); PRED_DIR = a.pred_dir
    SEASON_FN = make_season_fn()
    fac = (lambda P: make_extra(P, a.urunbilgi, a.v3, a.stok)) if a.urunbilgi else None
    df, qd = run(a.weekly, a.toplu, a.exclude, a.out, extra_factory=fac)
    report(df, qd)
