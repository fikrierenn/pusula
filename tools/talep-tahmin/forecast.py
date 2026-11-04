"""
BKM talep tahmini — araştırma çerçevesi (mağaza 1, haftalık ürün satışı).

Bilimsel çerçeve:
  * Rolling-origin değerlendirme (Tashman 2000): her origin T'de yalnız [0, T) verisi kullanılır,
    hedef = sonraki H haftanın toplam net satışı (H=4 ≈ 30 gün; ENS/PLAN-04 sonuç penceresiyle aynı).
  * Ölçütler: WAPE, bias, MAE, ENS göreli band isabeti (|A−F| ≤ 0.5F), pinball loss (q=0.1/0.5/0.9),
    %80 aralık kapsaması. Segment: Syntetos-Boylan-Croston (2005) ADI/CV² sınıfları.
  * Yöntemler: proc-eşleniği (13 hafta ort.), naive, mevsimsel naive, SES, Croston (1972),
    SBA (Syntetos & Boylan 2005), TSB (Teunter, Syntetos & Babai 2011), ADIDA (Nikolopoulos vd. 2011),
    kombinasyon (Makridakis vd. M4/M5 bulgusu: kombinasyon tek yöntemi yener).

Girdi: weekly.csv (stk,w,q) — yalnız sıfır-olmayan hücreler. Hafta 0 = 2021-06-07.
Sınır: stoksuz haftalarda satış SANSÜRLÜ talep; v1 bunu düzeltmez (açıkça raporlanır).
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass

import numpy as np
import pandas as pd

H = 4  # ufuk (hafta)


# ───────────────────────── veri ─────────────────────────
@dataclass
class Panel:
    stk: np.ndarray        # ürün kimlikleri
    Y: np.ndarray          # [n_ürün, n_hafta] float32, net satış (negatif net → 0'a kırpılır, ayrıca sayılır)
    first: np.ndarray      # ilk satış haftası (ürün "doğumu")
    n_neg: int


def load_panel(path: str, toplu: str | None = None, exclude: str | None = None) -> Panel:
    """Perakende talep paneli.
    path   : weekly.csv (ehTip 1,4,100 − 3,5,101)
    toplu  : toplu.csv (ehTip 1,4 − 3,5) → çıkarılır ⇒ perakende = POS(100) − POS iade(101)
    exclude: devredisi.csv (BKMMaliyet.dbo.FifoDevreDisiUrunler — poşet/hediye çeki/gider; stkID-curated)
    """
    df = pd.read_csv(path)
    if toplu:
        t = pd.read_csv(toplu); t["q"] = -t["q"]
        df = pd.concat([df, t]).groupby(["stk", "w"], as_index=False)["q"].sum()
        df = df[df["q"] != 0]
    n_excl = 0
    if exclude:
        ex = set(pd.read_csv(exclude)["stk"].dropna().astype(int))
        n_excl = int(df["stk"].isin(ex).sum()); df = df[~df["stk"].isin(ex)]
    df = df[df["w"] >= 0]
    stk, inv = np.unique(df["stk"].to_numpy(), return_inverse=True)
    W = int(df["w"].max()) + 1
    Y = np.zeros((len(stk), W), dtype=np.float32)
    np.add.at(Y, (inv, df["w"].to_numpy()), df["q"].to_numpy(dtype=np.float32))
    n_neg = int((Y < 0).sum())
    Y = np.maximum(Y, 0)          # iade fazlası haftalar talep değildir
    has = Y > 0
    first = np.where(has.any(1), has.argmax(1), W)
    if n_excl: print(f"dışlanan (devre dışı ürün) hücre: {n_excl:,}", file=sys.stderr)
    return Panel(stk, Y, first, n_neg)


# ───────────────────────── yöntemler (vektörel, ürün ekseni) ─────────────────────────
def m_proc(Y, T):
    """Mevcut proc'un eşleniği: son 13 haftanın (≈90 gün) ortalaması × H."""
    return Y[:, max(0, T - 13):T].sum(1) / 13.0 * H


def m_naive(Y, T):
    return Y[:, T - H:T].sum(1)


def m_snaive(Y, T):
    """Geçen yılın aynı H haftası (52 hafta önce)."""
    return Y[:, T - 52:T - 52 + H].sum(1) if T >= 52 else m_proc(Y, T)


def m_ses(Y, T, first, alpha=0.1):
    lvl = np.zeros(Y.shape[0], np.float64)
    started = np.zeros(Y.shape[0], bool)
    for t in range(T):
        y = Y[:, t]
        born = (~started) & (first <= t)
        lvl[born] = y[born]; started |= born
        upd = started & ~born
        lvl[upd] = alpha * y[upd] + (1 - alpha) * lvl[upd]
    return lvl * H


def m_croston_family(Y, T, first, alpha=0.1, beta=0.05):
    """Croston, SBA ve TSB'yi tek geçişte hesaplar (ürün doğumundan itibaren)."""
    n = Y.shape[0]
    z = np.zeros(n); p = np.ones(n); q = np.zeros(n, int)       # Croston: boyut, aralık, son talepten beri
    zt = np.zeros(n); pi = np.zeros(n)                            # TSB: boyut, olasılık
    started = np.zeros(n, bool)
    for t in range(T):
        y = Y[:, t]; d = y > 0
        born = (~started) & (first <= t)
        z[born] = y[born]; p[born] = 1.0; q[born] = 0
        zt[born] = y[born]; pi[born] = 1.0
        started |= born
        act = started & ~born
        q[act] += 1
        hit = act & d
        z[hit] = alpha * y[hit] + (1 - alpha) * z[hit]
        p[hit] = alpha * q[hit] + (1 - alpha) * p[hit]
        q[hit] = 0
        pi[act] = beta * d[act] + (1 - beta) * pi[act]
        zt[hit] = alpha * y[hit] + (1 - alpha) * zt[hit]
    croston = z / p
    sba = (1 - alpha / 2) * croston
    tsb = pi * zt
    return croston * H, sba * H, tsb * H


def m_adida(Y, T, first, alpha=0.2):
    """ADIDA: H-haftalık kovalara toplanmış seride SES; tahmin doğrudan H-ufuk toplamıdır."""
    k = T // H
    if k < 2:
        return m_proc(Y, T)
    agg = Y[:, T - k * H:T].reshape(Y.shape[0], k, H).sum(2)
    start = T - k * H
    lvl = np.zeros(Y.shape[0]); started = np.zeros(Y.shape[0], bool)
    for j in range(k):
        y = agg[:, j]; wk = start + j * H
        born = (~started) & (first < wk + H)
        lvl[born] = y[born]; started |= born
        upd = started & ~born
        lvl[upd] = alpha * y[upd] + (1 - alpha) * lvl[upd]
    return lvl


# ───────────────────────── ölçüm ─────────────────────────
def sbc_class(Y, T, first):
    """Syntetos-Boylan-Croston: ADI ≥ 1.32 kesikli, CV² ≥ 0.49 değişken (son 52 hafta, doğumdan beri). Vektörel."""
    lo = T - 52
    S = Y[:, lo:T].astype(np.float64)
    valid = np.arange(lo, T)[None, :] >= first[:, None]
    nz = (S > 0) & valid
    L = valid.sum(1); k = nz.sum(1)
    sm = np.where(nz, S, 0).sum(1); sq = np.where(nz, S * S, 0).sum(1)
    with np.errstate(divide="ignore", invalid="ignore"):
        mean = sm / k; var = sq / k - mean ** 2
        cv2 = var / mean ** 2; adi = L / k
    cls = np.where(adi >= 1.32, np.where(cv2 < 0.49, "kesikli", "topaklı"), np.where(cv2 < 0.49, "düzgün", "dalgalı")).astype(object)
    cls[k < 2] = "çok-seyrek"
    cls[L == 0] = "yok"
    return cls


def metrics(F, A):
    F = np.maximum(F, 0)
    ae = np.abs(F - A); sA = A.sum()
    pos = F > 0
    band = np.abs(A[pos] - F[pos]) <= 0.5 * F[pos] + 1e-9
    return {
        "n": int(len(A)),
        "WAPE": float(ae.sum() / sA) if sA > 0 else np.nan,
        "bias": float((F - A).sum() / sA) if sA > 0 else np.nan,
        "MAE": float(ae.mean()),
        "band": float(band.mean()) if pos.any() else np.nan,
    }


def run(path, origins_every=4, start_week=None, out=None, toplu=None, exclude=None):
    P = load_panel(path, toplu, exclude)
    Y, first = P.Y, P.first
    W = Y.shape[1]
    start = start_week or 156            # ilk origin: ~3 yıl veri sonrası (2024-06) — iki sezon geçmişi
    origins = list(range(start, W - H + 1, origins_every))
    print(f"ürün {len(P.stk):,} · hafta {W} · negatif-net hücre {P.n_neg:,} (0'a kırpıldı) · origin {len(origins)} ({start}→{origins[-1]})", file=sys.stderr)
    rows = []
    for T in origins:
        pop = Y[:, T - 13:T].sum(1) > 0                 # proc popülasyonu: son 90 günde satışı olan
        Ys, fs = Y[pop], first[pop]                       # yalnız aktif ürünler (hız; sonuç aynı)
        A = Ys[:, T:T + H].sum(1)
        cr, sba, tsb = m_croston_family(Ys, T, fs)
        fc = {
            "proc(13h-ort)": m_proc(Ys, T),
            "naive(4h)": m_naive(Ys, T),
            "mevsimsel-naive": m_snaive(Ys, T),
            "SES(0.1)": m_ses(Ys, T, fs),
            "Croston": cr, "SBA": sba, "TSB": tsb,
            "ADIDA": m_adida(Ys, T, fs),
        }
        fc["kombinasyon(SES,SBA,TSB,ADIDA)"] = np.median(np.vstack([fc["SES(0.1)"], fc["SBA"], fc["TSB"], fc["ADIDA"]]), 0)
        cls = sbc_class(Ys, T, fs)
        m2 = Ys[:, T - 13:T].sum(1) >= 2
        allm = np.ones(len(Ys), bool)
        # Katman: origin'de YALNIZ geçmiş 52 haftanın adedine göre sıra (geleceğe bakmaz; fiyat kullanılmaz)
        past52 = Ys[:, T - 52:T].sum(1)
        rank = np.argsort(-past52, kind="stable"); r = np.empty_like(rank); r[rank] = np.arange(len(rank))
        tiers = [("ilk100", r < 100), ("ilk1000", r < 1000), ("kuyruk(>1000)", r >= 1000)]
        for name, F in fc.items():
            for seg_name, mask in [("tümü", allm), ("M90≥2", m2)] + tiers + [(c, cls == c) for c in ("düzgün", "dalgalı", "kesikli", "topaklı", "çok-seyrek")]:
                if mask.sum() == 0: continue
                rows.append({"T": T, "yöntem": name, "segment": seg_name, **metrics(F[mask], A[mask])})
    df = pd.DataFrame(rows)
    # origin'ler üzerinden: WAPE/bias için toplam-ağırlıklı değil basit ortalama + n
    summ = df.groupby(["segment", "yöntem"]).agg(n=("n", "sum"), WAPE=("WAPE", "mean"), bias=("bias", "mean"),
                                                MAE=("MAE", "mean"), band=("band", "mean")).reset_index()
    if out:
        df.to_csv(out + ".origins.csv", index=False); summ.to_csv(out + ".summary.csv", index=False)
    return summ


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("weekly"); ap.add_argument("--out"); ap.add_argument("--every", type=int, default=4)
    ap.add_argument("--toplu"); ap.add_argument("--exclude")
    a = ap.parse_args()
    s = run(a.weekly, a.every, out=a.out, toplu=a.toplu, exclude=a.exclude)
    pd.set_option("display.width", 200); pd.set_option("display.max_rows", 200)
    for seg in ["ilk100", "ilk1000", "kuyruk(>1000)", "tümü", "M90≥2", "düzgün", "dalgalı", "kesikli", "topaklı", "çok-seyrek"]:
        t = s[s.segment == seg].sort_values("WAPE")
        if len(t): print(f"\n== {seg} (n karar={t.n.iloc[0]:,})\n" + t[["yöntem", "WAPE", "bias", "MAE", "band"]].round(3).to_string(index=False))
