"""Takvim regresor matrisi (plan-15 Faz 1).

GLM tatil/okul etkisini CARPAN degil GERCEK REGRESOR olarak alir.
Tatil kaynak: gomulu statik TR tablosu 2021-2027 (ulusal sabit + dini bilinen tarihler).
  - Apps Script API yalnizca bu-yil+-1 veriyor → 5 yil fit icin yetersiz; gomulu tablo tarihsel-tam.
Okul kaynak: dashboard/data/okul-takvimi.json (MEB donem + sinav, elle).
"""
from __future__ import annotations

import json
import warnings
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd

_REPO_ROOT = Path(__file__).resolve().parent.parent.parent
_OKUL_PATH = _REPO_ROOT / "dashboard" / "data" / "okul-takvimi.json"

# --- Dini bayram TAM gunleri (mağaza kapali) — Diyanet/resmi takvim, 2021-2027. Arife (yarim) ayri. ---
# Ramazan Bayrami (3 gun) + Kurban Bayrami (4 gun). Arife = bayramin ilk gununden onceki gun.
_RAMAZAN = {
    2021: date(2021, 5, 13), 2022: date(2022, 5, 2), 2023: date(2023, 4, 21),
    2024: date(2024, 4, 10), 2025: date(2025, 3, 30), 2026: date(2026, 3, 20), 2027: date(2027, 3, 10),
}
_KURBAN = {
    2021: date(2021, 7, 20), 2022: date(2022, 7, 9), 2023: date(2023, 6, 28),
    2024: date(2024, 6, 16), 2025: date(2025, 6, 6), 2026: date(2026, 5, 27), 2027: date(2027, 5, 16),
}
# Ulusal (sabit tarih, mağaza genelde acik → ayri zayif regresor).
_ULUSAL_AYGUN = [(1, 1), (4, 23), (5, 1), (5, 19), (7, 15), (8, 30), (10, 29)]


def _dini_gunler(yil: int):
    """yil icin (dini_tam_gun set, arife set) — Ramazan 3g + Kurban 4g + her birinin arifesi."""
    tam, arife = set(), set()
    if yil in _RAMAZAN:
        b = _RAMAZAN[yil]
        for i in range(3):
            tam.add(b + pd.Timedelta(days=i))
        arife.add(b - pd.Timedelta(days=1))
    if yil in _KURBAN:
        b = _KURBAN[yil]
        for i in range(4):
            tam.add(b + pd.Timedelta(days=i))
        arife.add(b - pd.Timedelta(days=1))
    return {pd.Timestamp(d) for d in tam}, {pd.Timestamp(d) for d in arife}


def _okul_donemleri():
    """okul-takvimi.json → (donem araliklari [(bas,son)], sinav tarih set). Yoksa bos (notr)."""
    if not _OKUL_PATH.exists():
        warnings.warn(f"okul-takvimi.json yok ({_OKUL_PATH}) — okul/sinav regresoru NOTR (0). "
                      "GLM tatil etkisi eksik kalir.", stacklevel=2)
        return [], set()
    try:
        j = json.loads(_OKUL_PATH.read_text(encoding="utf-8"))
    except Exception as e:
        warnings.warn(f"okul-takvimi.json okunamadi ({e}) — okul/sinav regresoru NOTR (0).", stacklevel=2)
        return [], set()
    donem = []
    for d in j.get("Donemler", []):
        donem.append((pd.Timestamp(_dmy(d["Bas"])), pd.Timestamp(_dmy(d["Son"]))))
    sinav = {pd.Timestamp(_dmy(s["Tarih"])) for s in j.get("Sinavlar", [])}
    return donem, sinav


def _dmy(s: str) -> date:
    g, a, y = s.split(".")
    return date(int(y), int(a), int(g))


def build_regressors(index: pd.DatetimeIndex) -> pd.DataFrame:
    """Verilen gunluk index icin regresor matrisi.

    Sutunlar (hepsi 0/1 dummy, GLM katsayisi = etki):
      bayram        dini bayram tam gunu (mağaza kapali) — en guclu negatif
      arife         bayram arifesi (yarim gun)
      bayram_oncesi bayramdan onceki 3 gun (stok-up; pozitif olabilir)
      ulusal        ulusal tatil (zayif)
      okul_acik     okul donemde
      sinav         LGS/YKS gunu (+- 7 gun pencere; sinav sezonu zirvesi)
    """
    idx = pd.DatetimeIndex(index).normalize()
    yillar = range(idx.year.min(), idx.year.max() + 1)
    dini_tam, arife = set(), set()
    for y in yillar:
        t, a = _dini_gunler(y)
        dini_tam |= t
        arife |= a
    oncesi = set()
    for d in dini_tam:
        for k in range(1, 4):
            oncesi.add(d - pd.Timedelta(days=k))
    oncesi -= dini_tam | arife  # bayram + arife gunlerini cikar (cift-isaret onle)
    ulusal = {pd.Timestamp(date(y, ay, g)) for y in yillar for (ay, g) in _ULUSAL_AYGUN}

    donem, sinav = _okul_donemleri()
    sinav_pencere = set()
    for s in sinav:
        for k in range(-7, 8):
            sinav_pencere.add(s + pd.Timedelta(days=k))

    def okul_acik(ts):
        return any(b <= ts <= e for (b, e) in donem)

    df = pd.DataFrame(index=idx)
    df["bayram"] = idx.isin(dini_tam).astype(float)
    df["arife"] = idx.isin(arife).astype(float)
    df["bayram_oncesi"] = idx.isin(oncesi).astype(float)
    df["ulusal"] = idx.isin(ulusal).astype(float)
    df["okul_acik"] = np.array([okul_acik(t) for t in idx], dtype=float)
    df["sinav"] = idx.isin(sinav_pencere).astype(float)
    return df.reset_index(drop=True)


if __name__ == "__main__":
    # CLI smoke: 2026 Mayis-Haziran regresor ozeti.
    rng = pd.date_range("2026-05-01", "2026-06-30", freq="D")
    r = build_regressors(rng)
    r.insert(0, "ds", rng)
    aktif = r[(r[["bayram", "arife", "bayram_oncesi", "sinav"]].sum(axis=1) > 0)]
    print("Mayis-Haziran 2026 ozel gunler:")
    print(aktif.to_string(index=False))
    print(f"\nokul_acik gun: {int(r['okul_acik'].sum())}/{len(r)}")
