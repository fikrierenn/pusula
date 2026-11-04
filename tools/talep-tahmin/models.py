"""
v2 (hiyerarşik sezon) ve v3 (global öğrenen model) — forecast.py yöntem kütüphanesine ek.

v2 — kategori sezon çarpanı (hiyerarşik sezonsallık; ürün tek başına sezon tahmini için çok seyrek):
    oran_c = Σ_y∈{1,2} C_c[T−52y : T−52y+H]  /  Σ_y (C_c[T−52y−13 : T−52y] / 13 · H)
    büzülme: log oran ← log oran · n/(n+κ), n = paydadaki birim hacmi, κ = 200 (küçük kategori → 1'e çekilir)
    tahmin = taban × oran (taban: SBA / ADIDA / proc)
v3 — global HistGradientBoosting (Poisson kaybı; Makridakis vd. 2022 M5: global ağaç modelleri kazanır).
    Eğitim kümesi: origin t için hedef [t, t+H) tamamen T'den ÖNCE gözlenmiş olmalı (t + H ≤ T) → sızıntı yok.
"""
from __future__ import annotations

import numpy as np
from sklearn.ensemble import HistGradientBoostingRegressor

H = 4


def category_totals(Y: np.ndarray, cat: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Kategori × hafta toplamı (tüm ürünler; T sonrası sütunlar yalnız ileri origin'lerde kullanılır)."""
    cats, ci = np.unique(cat, return_inverse=True)
    C = np.zeros((len(cats), Y.shape[1]), np.float64)
    np.add.at(C, ci, Y.astype(np.float64))
    return C, ci


def seasonal_ratio(C: np.ndarray, T: int, kappa: float = 200.0, years=(1, 2)) -> np.ndarray:
    num = np.zeros(C.shape[0]); den = np.zeros(C.shape[0])
    for y in years:
        a = T - 52 * y
        if a - 13 < 0: continue
        num += C[:, a:a + H].sum(1)
        den += C[:, a - 13:a].sum(1) / 13.0 * H
    with np.errstate(divide="ignore", invalid="ignore"):
        r = np.where((num > 0) & (den > 0), num / den, 1.0)
    w = den / (den + kappa)
    return np.exp(np.log(r) * w)


def series_scale(Y, T):
    """Seri ölçeği (H haftalık birimde): son 13 ve 52 haftanın ortalama hızlarının ortalaması + 1.
    M5 pratiği: hedef ve sayım özellikleri bu ölçeğe bölünür → model 'kendi ortalamasının kaç katı' öğrenir,
    büyük hacimli nadir ürünlerde Poisson ıraksaması (1.27e10 tahmin, 2026-10-13) önlenir."""
    def s(a, b): return Y[:, max(0, a):max(0, b)].sum(1)
    return (s(T - 13, T) / 13.0 + s(T - 52, T) / 52.0) / 2.0 * H + 1.0


def features(Y: np.ndarray, T: int, first: np.ndarray, ratio_p: np.ndarray, trend_p: np.ndarray,
             price: np.ndarray, kat: np.ndarray, scale: np.ndarray, use_price: bool = True) -> np.ndarray:
    """Origin T'de ürün başına özellikler (yalnız [0, T) verisi). Sayımlar `scale`'e bölünür."""
    def s(a, b): return Y[:, max(0, a):max(0, b)].sum(1)
    S = Y[:, max(0, T - 52):T]
    nz = S > 0
    # Son satıştan beri geçen hafta (0 = geçen hafta sattı; satış yoksa 52).
    # BUG (düzeltildi): önce son satışın PENCERE İÇİ İNDEKSİ yazılıyordu (geçen hafta satan → 51).
    since_last = np.where(nz.any(1), np.argmax(nz[:, ::-1], 1), 52)
    cnt = lambda v: v / scale
    cols = [
        cnt(Y[:, T - 1] * H), cnt(s(T - 4, T)), cnt(s(T - 13, T) / 13 * H), cnt(s(T - 26, T) / 26 * H),
        cnt(s(T - 52, T) / 52 * H),
        cnt(s(T - 52, T - 52 + H)) if T >= 52 else np.zeros(len(Y)),
        cnt(s(T - 104, T - 104 + H)) if T >= 104 else np.zeros(len(Y)),
        cnt(s(T - 52 - 13, T - 52) / 13 * H) if T >= 65 else np.zeros(len(Y)),
        nz.mean(1), since_last, np.minimum(T - first, 260),
        ratio_p, trend_p, np.log(scale), kat,
    ]
    if use_price: cols.insert(-1, price)
    return np.column_stack(cols).astype(np.float32)


def feature_names(use_price=True):
    n = ["y1", "s4", "s13", "s26", "s52", "ly_h", "ly2_h", "ly_prev13", "nz52", "since_last", "age",
         "kat_sezon", "kat_trend", "log_olcek", "kat"]
    if use_price: n.insert(-1, "fiyat")
    return n


class GlobalModel:
    """Origin'ler arasında genişleyen pencereyle eğitilen tek global model."""

    def __init__(self, Y, first, ci, C, price, kat_code, min_origin=104, step=4, max_rows=400_000, seed=0, use_price=True):
        self.use_price = use_price
        self.Y, self.first, self.ci, self.C = Y, first, ci, C
        self.price, self.kat = price, kat_code
        self.min_origin, self.step, self.max_rows = min_origin, step, max_rows
        self.rng = np.random.default_rng(seed)
        self.model = None; self.trained_at = None

    def _feat(self, T, idx):
        ratio = seasonal_ratio(self.C, T)[self.ci[idx]]
        with np.errstate(divide="ignore", invalid="ignore"):
            tr = self.C[:, T - 4:T].sum(1) / (self.C[:, T - 13:T].sum(1) / 13 * 4)
        trend = np.nan_to_num(tr, nan=1.0, posinf=1.0)[self.ci[idx]]
        sc = series_scale(self.Y[idx], T)
        return features(self.Y[idx], T, self.first[idx], ratio, trend, self.price[idx], self.kat[idx], sc, self.use_price), sc

    def fit(self, T):
        Xs, ys = [], []
        for t in range(self.min_origin, T - H + 1, self.step):          # hedef [t, t+H) ⊂ [0, T)
            idx = np.nonzero(self.Y[:, t - 13:t].sum(1) > 0)[0]
            X_t, sc = self._feat(t, idx)
            Xs.append(X_t); ys.append(self.Y[idx, t:t + H].sum(1) / sc)        # normalize hedef
        X = np.vstack(Xs); y = np.concatenate(ys)
        if len(y) > self.max_rows:
            k = self.rng.choice(len(y), self.max_rows, replace=False); X, y = X[k], y[k]
        m = HistGradientBoostingRegressor(loss="poisson", max_iter=300, learning_rate=0.05, max_leaf_nodes=63,
                                          min_samples_leaf=50, l2_regularization=1.0,
                                          categorical_features=[feature_names(self.use_price).index("kat")],
                                          early_stopping=True, validation_fraction=0.1, random_state=0)
        m.fit(X, y); self.model = m; self.trained_at = T
        return len(y)

    def predict(self, T, idx):
        X, sc = self._feat(T, idx)
        return np.maximum(self.model.predict(X), 0) * sc


# ═══════════════════════ v5 (sansür) + v6 (takvim, büyüme, yayın yaşı) ═══════════════════════
EVENT_KEYS = ["Okul açılışı", "Yarıyıl tatili", "Yaz karnesi", "Yılbaşı", "Babalar Günü", "Kurban Bayramı",
              "Ramazan Bayramı", "Ara tatil (MEB)", "Kasım indirimi (Efsane Cuma)", "Öğretmenler Günü",
              "Sevgililer Günü", "Anneler Günü"]


class GlobalModelV6(GlobalModel):
    """GlobalModel + v5 sansür (stokta kalma oranları; yalnız sansürsüz hedeflerle eğitim) + v6 takvim/büyüme.
    instock: [n, W] bool (True = hafta sansürsüz). event_weeks: {olay: [hafta indeksleri]}. launch_w: ürün yayın haftası."""

    def __init__(self, *a, instock=None, event_weeks=None, launch_w=None, use_v5=True, use_v6=True, **kw):
        super().__init__(*a, **kw)
        self.instock, self.ev, self.launch_w = instock, event_weeks or {}, launch_w
        self.use_v5, self.use_v6 = use_v5, use_v6

    def _extra(self, T, idx):
        cols = []
        if self.use_v5:
            for k in (4, 13, 52):
                cols.append(self.instock[idx, max(0, T - k):T].mean(1))
        if self.use_v6:
            for e in EVENT_KEYS:
                ws = np.asarray(self.ev.get(e, []))
                cols.append(np.full(len(idx), float(((ws >= T) & (ws < T + H)).sum())))      # pencerede olay var mı
                ly = ((ws >= T - 52) & (ws < T - 52 + H)).sum()                                # geçen yıl aynı pencerede vardı mı
                cols.append(np.full(len(idx), float(ly)))
            okul = np.asarray(self.ev.get("Okul açılışı", [])); nxt = okul[okul >= T]
            cols.append(np.full(len(idx), float(min(nxt.min() - T, 30)) if len(nxt) else 30.0))   # okul açılışına hafta
            tot = self.Y.sum(0)
            with np.errstate(divide="ignore", invalid="ignore"):
                yoy_s = tot[T - 13:T].sum() / max(tot[T - 65:T - 52].sum(), 1.0) if T >= 65 else 1.0
                yoy_c = (self.C[:, T - 13:T].sum(1) / np.maximum(self.C[:, T - 65:T - 52].sum(1), 1.0)) if T >= 65 else np.ones(self.C.shape[0])
            cols.append(np.full(len(idx), float(yoy_s))); cols.append(np.clip(yoy_c[self.ci[idx]], 0, 10))
            la = T - self.launch_w[idx]
            cols.append(np.where(np.isfinite(la), np.clip(la, -10, 260), np.nan))
        return np.column_stack(cols).astype(np.float32) if cols else np.zeros((len(idx), 0), np.float32)

    def _feat(self, T, idx):
        X, sc = super()._feat(T, idx)
        return np.hstack([X[:, :-1], self._extra(T, idx), X[:, -1:]]), sc     # kat en sonda kalsın (kategorik indeks)

    def fit(self, T):
        Xs, ys = [], []
        for t in range(self.min_origin, T - H + 1, self.step):
            idx = np.nonzero(self.Y[:, t - 13:t].sum(1) > 0)[0]
            if self.use_v5:                                                       # yalnız sansürsüz hedef penceresi
                idx = idx[self.instock[idx, t:t + H].all(1)]
            X_t, sc = self._feat(t, idx)
            Xs.append(X_t); ys.append(self.Y[idx, t:t + H].sum(1) / sc)
        X = np.vstack(Xs); y = np.concatenate(ys)
        if len(y) > self.max_rows:
            k = self.rng.choice(len(y), self.max_rows, replace=False); X, y = X[k], y[k]
        kat_col = X.shape[1] - 1
        m = HistGradientBoostingRegressor(loss="poisson", max_iter=400, learning_rate=0.05, max_leaf_nodes=63,
                                          min_samples_leaf=50, l2_regularization=1.0, categorical_features=[kat_col],
                                          early_stopping=True, validation_fraction=0.1, random_state=0)
        m.fit(X, y); self.model = m; self.trained_at = T
        return len(y)


# ═══════════════════════ v9g — ürün düzeyinde OLAY-HİZALI sezon (ön-kayıt 4, ENS de3c2e3) ═══════════════════════
class GlobalModelV9(GlobalModelV6):
    """GlobalModelV6 + olay-hizalı ürün sezon özellikleri. evl: [(olay, hafta)], cat_index: t → U [n_kat, W] (v8k indeksi)."""

    def __init__(self, *a, evl=None, cat_index=None, kappa_p=2.0, **kw):
        super().__init__(*a, **kw)
        self.evl = sorted(evl or [], key=lambda x: x[1]); self.cat_index = cat_index; self.kappa_p = kappa_p
        self.codes = {o: i for i, o in enumerate(sorted({o for o, _ in self.evl}))}

    def anchor(self, t):
        """(olay kodu, göreli hafta, s1, s2). Çapa = hedef merkezine (t+1.5) en yakın tekrar, −8 ≤ t+1.5−w_e ≤ 6."""
        best = None
        for o, we in self.evl:
            k = t + 1.5 - we
            if -8 <= k <= 6 and (best is None or abs(k) < abs(best[2])): best = (o, we, k)
        if best is None: return -1, 99.0, 52, 104
        o, we, k = best
        prev = [w for oo, w in self.evl if oo == o and w < we - 26]
        s1 = we - prev[-1] if prev else 52
        s2 = we - prev[-2] if len(prev) >= 2 else s1 + 52
        return self.codes[o], float(k), int(s1), int(s2)

    def _v9(self, T, idx, sc):
        code, k, s1, s2 = self.anchor(T)
        def s(a, b): return self.Y[idx, max(0, a):max(0, b)].sum(1)
        ly = s(T - s1, T - s1 + H); p13 = s(T - s1 - 13, T - s1) / 13 * H
        ly2 = s(T - s2, T - s2 + H) if T - s2 >= 13 else np.zeros(len(idx))
        p13b = s(T - s2 - 13, T - s2) / 13 * H if T - s2 >= 13 else np.zeros(len(idx))
        if self.cat_index is not None:
            U = self.cat_index(T)[self.ci[idx]]
            rc = (U[:, T:T + H].sum(1) / H) / (U[:, T - 13:T].sum(1) / 13)
        else:
            rc = np.ones(len(idx))
        den = p13 + p13b
        rp = np.log((ly + ly2 + self.kappa_p * rc) / (den + self.kappa_p))      # ürün oranı, κ birimle kategori oranına büzülür
        cols = [ly / sc, p13 / sc, ly2 / sc, p13b / sc, rp, np.log(rc),
                np.full(len(idx), k, float), np.full(len(idx), float(code))]
        return np.column_stack(cols).astype(np.float32)

    def _feat(self, T, idx):
        X, sc = super()._feat(T, idx)
        return np.hstack([X[:, :-1], self._v9(T, idx, sc), X[:, -1:]]), sc
