"""Min/Max Excel doğrulaması: Excel'in hesapladığı formül sütunları (Q..AC) ↔ Python ikizi, satır satır.
Kullanım: python minmax_karsilastir.py <dosya.excel-hesapladi.xlsx> <dosya.python-degerleri.csv>"""
import sys

import numpy as np
import openpyxl
import pandas as pd

XL, PY = sys.argv[1], sys.argv[2]
py = pd.read_csv(PY, low_memory=False)
ws = openpyxl.load_workbook(XL, read_only=True, data_only=True)["Ürünler"]
xl = pd.DataFrame(list(ws.iter_rows(min_row=2, min_col=1, max_col=35, values_only=True)))
assert len(xl) == len(py), f"satır sayısı farklı: Excel {len(xl)} / Python {len(py)}"
assert (xl[0].astype("int64").to_numpy() == py.stk.to_numpy()).all(), "ürün kodu sırası farklı"
cols = ["maliyet", "mu_g", "SL", "psat", "stokla", "raf", "Min", "eoq", "Max", "siparis", "siparis_TL", "min_gun", "max_gun"]
kotu = 0
for j, c in enumerate(cols):
    a = xl[16 + j]; b = py[c]
    if b.dtype == object:
        bad = a.fillna("").astype(str) != b.fillna("").astype(str)
    else:
        an = pd.to_numeric(a.replace("", np.nan), errors="coerce"); bn = pd.to_numeric(b, errors="coerce")
        bad = ~np.isclose(an, bn, rtol=1e-9, atol=1e-6, equal_nan=True)
    bad = pd.Series(np.asarray(bad), index=a.index); n = int(bad.sum()); kotu += n
    print(f"{c:11s} farklı: {n}" + (f"  örnek satır {bad.idxmax() + 2}: Excel={a[bad].iloc[0]!r} Python={b[bad].iloc[0]!r}" if n else ""))
for j, c in ((32, "kaynak"), (33, "gun_sonra"), (34, "onay")):                # v4 ek sütunları (AG, AH, AI)
    if c not in py.columns: continue
    a, b = xl[j], py[c]
    if b.dtype == object:
        bad = a.fillna("").astype(str) != b.fillna("").astype(str)
    else:
        bad = ~np.isclose(pd.to_numeric(a.replace("", np.nan), errors="coerce"), pd.to_numeric(b, errors="coerce"), rtol=1e-9, atol=1e-6, equal_nan=True)
    n = int(np.asarray(bad).sum()); kotu += n; print(f"{c:11s} farklı: {n}")
if "sonalis" in py.columns:                                       # L: kullanılan alış maliyeti (2026-10-15)
    bad = ~np.isclose(pd.to_numeric(xl[11], errors="coerce").fillna(0), py["sonalis"].fillna(0), rtol=1e-9, atol=1e-6)
    n = int(bad.sum()); kotu += n; print(f"{'sonalis(L)':11s} farklı: {n}")
print(f"TOPLAM farklı hücre: {kotu} / {len(py) * (len(cols) + 1):,}")
