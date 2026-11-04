"""Excel'in hesapladığı formül değerleri ↔ Python ikizi, satır satır, her formül sütununda (stok_excel.py doğrulaması).
Kullanım: python excel_karsilastir.py <dosya.excel-hesapladi.xlsx> <dosya.python-degerleri.csv>"""
import sys

import numpy as np
import openpyxl
import pandas as pd

XL, PY = sys.argv[1], sys.argv[2]
py = pd.read_csv(PY, low_memory=False)
wb = openpyxl.load_workbook(XL, read_only=True, data_only=True)
ws = wb["Ürünler"]
rows = list(ws.iter_rows(min_row=2, min_col=1, max_col=28, values_only=True))
xl = pd.DataFrame(rows)
assert len(xl) == len(py), f"satır sayısı farklı: Excel {len(xl)} / Python {len(py)}"
assert (xl[0].astype("int64").to_numpy() == py.stk.to_numpy()).all(), "ürün kodu sırası farklı"
cols = ["maliyet", "stok_tl", "yeni", "kat_b", "buyume", "beklenen", "kapsama", "durum", "fazla_adet", "fazla_tl", "har_hafta", "hareketsiz", "sir_kap", "transfer"]
kotu = 0
for j, c in enumerate(cols):
    a = xl[14 + j]; b = py[c]
    if b.dtype == object or a.map(lambda v: isinstance(v, str)).any():
        aa = a.fillna("").astype(str).str.replace(r"\.0$", "", regex=True)
        bb = b.fillna("").astype(str).replace({"nan": ""})
        num = pd.to_numeric(aa, errors="coerce"); numb = pd.to_numeric(bb, errors="coerce")
        bad = ~((aa == bb) | (np.isclose(num, numb, rtol=1e-9, atol=1e-6) & num.notna()))
        bb2 = bb.where(~(bb.isin(["", "nan"]) & aa.isin(["Satış yok", "Hiç hareket yok"])), aa)   # Python NaN ↔ Excel metin karşılığı
        bad &= ~(aa == bb2)
    else:
        bad = ~np.isclose(pd.to_numeric(a, errors="coerce"), pd.to_numeric(b, errors="coerce"), rtol=1e-9, atol=1e-6, equal_nan=True)
    n = int(bad.sum()); kotu += n
    print(f"{c:12s} farklı hücre: {n}" + (f"  örnek: Excel={a[bad].iloc[0]!r} Python={b[bad].iloc[0]!r} (satır {bad.idxmax() + 2})" if n else ""))
if "sonalis" in py.columns:                                       # H: kullanılan alış maliyeti (2026-10-15)
    bad = ~np.isclose(pd.to_numeric(xl[7], errors="coerce").fillna(0), py["sonalis"].fillna(0), rtol=1e-9, atol=1e-6)
    n = int(bad.sum()); kotu += n; print(f"{'sonalis(H)':12s} farklı hücre: {n}")
print(f"TOPLAM farklı hücre: {kotu} / {len(py) * (len(cols) + 1):,}")
