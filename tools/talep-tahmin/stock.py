"""
v5 — stok paneli ve talep sansürü.

Stok: mağaza 1 tüm hareketler (irsHrk, her ehTip) haftalık net → kümülatif toplam = hafta SONU stok.
  Açılış devri (ehTip 99, 2021-05-31) hafta −1'de → sütun 0 (kaydırma +1).
Sansür (Nahmias 1994; "stockout-censored demand"): hafta w'de stok başta (S_end[w−1]) ya da sonda (S_end[w]) ≤ 0 ise
  o haftanın satışı talebin ALT sınırıdır → `censored[w] = True`. `instock[w] = ~censored[w]`.
Doğrulama: bkm.OneriSiparis.Stok (karar günü D = hafta w Pazartesi) ↔ S_end[w−1] (önceki Pazar sonu).
"""
from __future__ import annotations

import numpy as np
import pandas as pd


def load_stock(path: str, stk_index: np.ndarray, W: int):
    """stk_index: talep panelinin ürün dizisi (P.stk). Dönüş: S_end [n_ürün, W] (hafta 0..W−1), bilinmeyen = NaN."""
    df = pd.read_csv(path)
    df["w"] = df["w"] + 1                                     # −1 (açılış) → 0
    df = df[(df["w"] >= 0) & (df["w"] <= W)]
    pos = pd.Series(np.arange(len(stk_index)), index=stk_index)
    df = df[df["stk"].isin(pos.index)]
    M = np.zeros((len(stk_index), W + 1), np.float32)
    np.add.at(M, (pos[df["stk"]].to_numpy(), df["w"].to_numpy()), df["q"].to_numpy(np.float32))
    S = np.cumsum(M, axis=1)[:, 1:]                           # sütun k → talep haftası k sonu stok
    known = np.zeros(len(stk_index), bool); known[pos[df["stk"].unique()].to_numpy()] = True
    S[~known] = np.nan                                        # hiç hareketi olmayan ürün: stok bilinmiyor
    return S


def censor_flags(S: np.ndarray) -> np.ndarray:
    """censored[i, w] = stok hafta başında (S[w−1]) veya sonunda (S[w]) ≤ 0. Bilinmeyen stok → sansürsüz kabul."""
    start = np.concatenate([np.full((S.shape[0], 1), np.nan, np.float32), S[:, :-1]], axis=1)
    with np.errstate(invalid="ignore"):
        c = (start <= 0) | (S <= 0)
    return c & ~np.isnan(S)


def validate(S: np.ndarray, stk_index: np.ndarray, durum_csv: str):
    """Karar günü stoku (OneriSiparis.Stok) ile panel S_end[w−1] karşılaştırması."""
    d = pd.read_csv(durum_csv)
    pos = pd.Series(np.arange(len(stk_index)), index=stk_index)
    d = d[d["stk"].isin(pos.index)]
    est = S[pos[d["stk"]].to_numpy(), d["w"].to_numpy() - 1]
    real = d["stok"].to_numpy(float)
    ok = np.isfinite(est)
    diff = est[ok] - real[ok]
    return {"n": int(ok.sum()), "tam_eşit": float((np.abs(diff) < 0.5).mean()),
            "±1 içinde": float((np.abs(diff) <= 1).mean()), "medyan_mutlak_fark": float(np.median(np.abs(diff)))}
