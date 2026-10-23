"""
Bilimsel Min/Max — (R,s,S) günlük gözden geçirme, geçmişe dönük benzetim (ön-kayıt 6, ENS c9686d9 + c7b8128). OneriSiparis KULLANILMAZ.
  μ_g = v4 haftalık tahmin / 7  (v4: ilk1000 geo(v3, SES0.5), kuyruk v3; yalnız t öncesi veri)
  σ_g = son 26 hafta haftalık satış std / √7
  Min = ⌈μ_g·P + z(SL)·σ_g·√P⌉ ;  EOQ = √(2·52·μ_h·K / (c·h)) ;  Max = Min + max(1, ⌈EOQ⌉) ;  μ_h = 0 ∧ σ = 0 → Min = Max = 0
  sipariş: her iş günü, stok + yoldaki ≤ Min ise Max − (stok + yoldaki); teslim 2 iş günü sonra.
Test: son 26 hafta; başlangıç stoğu irsHrk paneli; talep = haftalık gerçek satış / 7 (gün). Kıyas: aynı dönemde GERÇEKLEŞEN (panel).
Kullanım: python minmax_sim.py <data_dir> <mağaza_adı> <çıktı_önek>
"""
import sys

import numpy as np
import pandas as pd
from scipy.stats import norm

import datetime as dt

import evaluate as E
import events as EV
import forecast as F
import models as M
import stock as SK

O, MAG, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
OFF = int(sys.argv[4]) if len(sys.argv) > 4 else 0          # pencere kaydırma (hafta): 0 = son 26 hafta, 26 = ondan önceki 26 hafta
P_GUN, L_IS, K_TL, H_YIL, MAXGUN = 4.0, 2, 10.0, 0.40, 30
SLS = (0.80, 0.85, 0.90, 0.95, 0.97)
TEST = 26
SINAV = ["Eğitim - Sınavlara Hazırlık - Okula Yardımcı", "Sınavlara Hazırlık Kitapları", "Eğitim ve Okula Yardımcı Kitaplar"]   # Sınav Okul Malzemeleri KAPSAM DIŞI

Pn = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv"); Y, first, W = Pn.Y, Pn.first, Pn.Y.shape[1]
ub = pd.read_csv(f"{O}/urunbilgi.csv").drop_duplicates("stk").set_index("stk")
katana = ub["katana"].reindex(Pn.stk).fillna("Bilinmiyor").to_numpy(); kc = np.unique(katana, return_inverse=True)[1]
kat2 = ub["kat2"].reindex(Pn.stk).fillna("").to_numpy()
GRUP = np.where(kat2 == "Kitap", np.where(np.isin(katana, SINAV), "Kitap-Hazırlık", "Kitap-Genel"),
                np.where(np.isin(kat2, ["Kırtasiye / Hediyelik", "Oyuncak / Elektronik"]), kat2, "Diğer"))
fiyat = ub["fiyat"].reindex(Pn.stk).to_numpy(float); son = ub["sonalis"].reindex(Pn.stk).to_numpy(float)
cost = np.where(np.nan_to_num(son) > 0, son, np.nan_to_num(fiyat) * 0.6); fiyat = np.nan_to_num(fiyat)
# ═══ ön-kayıt 11 (ENS 99caafd) — v4: danışman bulgularının toplu düzeltmesi ═══
import os
V4 = os.environ.get("POLITIKA") == "v4"
_ORT4 = os.path.join(os.path.dirname(O.rstrip("/\\")), "talep-tahmin-ortak")
KITAP = (kat2 == "Kitap") | (np.isin(kat2, ["Tanımsız", "Genel", ""]) & pd.Series(katana).str.contains("Kitap|Okula Yardımcı|Sınavlara Hazırlık|Periyodik", regex=True).to_numpy())
if V4:
    GRUP = np.where(KITAP, np.where(np.isin(katana, SINAV), "Kitap-Hazırlık", "Kitap-Genel"),
                    np.where(np.isin(kat2, ["Kırtasiye / Hediyelik", "Oyuncak / Elektronik"]), kat2, "Diğer"))
    _kdv4 = pd.read_csv(f"{_ORT4}/kdv.csv").drop_duplicates("stk").set_index("stk")["kdv"].reindex(Pn.stk).fillna(0).to_numpy(float)
    PNET_ALL = fiyat / (1 + _kdv4 / 100)
    _med = pd.read_csv(f"{_ORT4}/alis-medyan12.csv").set_index("stk")["medyan12"].reindex(Pn.stk).fillna(0).to_numpy(float)
    _kart = np.nan_to_num(son)
    _c = np.where(_kart > 0.05, _kart, np.nan)
    _c = np.where((_c > 0) & (_med > 0) & (_c > 3 * _med), _med, _c)                  # yalnız YUKARI hata
    _c = np.where(np.isnan(_c), PNET_ALL * 0.6, _c)
    cost = np.where(_c > 1.5 * PNET_ALL, PNET_ALL * 0.6, _c)                            # birim şüphesi
    _set = pd.read_csv(f"{_ORT4}/setler.csv"); DONUSUM = np.isin(Pn.stk, _set[_set.alis_24ay == 0].stk.to_numpy())
    SINAV_MRK4 = {2100, 2101, 3904, 3905, 3906, 4641, 5298, 5972, 5973, 5974}
    _mal_degil = set(pd.read_csv(f"{_ORT4}/mal-olmayan.csv").stk.astype(int))
# "rafta bulunsun" (0/1) kuralı — ön-kayıt 6 eki 2 (ENS 03ba834)
import os
_ORT = os.path.join(os.path.dirname(O.rstrip("/\\")), "talep-tahmin-ortak")
_od = pd.read_csv(f"{_ORT}/odak.csv").drop_duplicates("stk").set_index("stk")
YER_TUTUCU = {8015, 22894, 54435, 54441, 106869}                                 # Anonim, Derleme, Kolektif, Komisyon, Sınav Ankara
_ya = pd.read_csv(f"{_ORT}/yazar-onem.csv"); ONEMLI_YAZAR = set(_ya[_ya["onemli_%80"]].yazar.astype(int)) - YER_TUTUCU
_yv = pd.read_csv(f"{_ORT}/yayinevi-onem.csv"); ONEMLI_YAYINEVI = set(_yv[_yv["onemli_%80"]].yayinevi.astype(int))
_yz = ub["yazar"].reindex(Pn.stk).fillna(0).astype(int).to_numpy(); _yy = ub["yayinevi"].reindex(Pn.stk).fillna(0).astype(int).to_numpy()
_os = _od["odak_stok"].reindex(Pn.stk).fillna(0).to_numpy(); _odr = _od["odak_durum"].reindex(Pn.stk).fillna(0).to_numpy()
RAF = (KITAP if V4 else (kat2 == "Kitap")) & ((_os > 0) | (_odr == 1)) & (np.isin(_yz, list(ONEMLI_YAZAR)) | np.isin(_yy, list(ONEMLI_YAYINEVI)))
print(f"rafta bulunsun kuralına giren ürün (tüm panel): {int(RAF.sum()):,}", file=sys.stderr)
C, ci = M.category_totals(Y, katana)
St = SK.load_stock(f"{O}/stokhareket.csv", Pn.stk, W)
gm = M.GlobalModel(Y, first, ci, C, fiyat, kc.astype(np.float32), use_price=False)


def v4(t, idx):
    if gm.trained_at is None or t < gm.trained_at or t - gm.trained_at >= 12: gm.fit(t)
    g = gm.predict(t, idx); s5 = E.ses(Y[idx], t, first[idx], 0.5)
    past52 = Y[:, t - 52:t].sum(1); pop = Y[:, t - 13:t].sum(1) > 0
    order = np.argsort(-np.where(pop, past52, -1)); rank = np.empty(len(Y), int); rank[order] = np.arange(len(Y))
    return np.where(rank[idx] < 1000, np.sqrt(np.maximum(g, 0) * np.maximum(s5, 0)), g) / 4.0   # 4 haftalık → haftalık


T1 = W - OFF; T0 = T1 - TEST
s0 = np.nan_to_num(St[:, T0 - 1], nan=0.0)
KURUMSAL = pd.Series(katana).str.startswith("Sınav Okul").to_numpy()
if V4: KURUMSAL = KURUMSAL | DONUSUM | ub["yayinevi"].reindex(Pn.stk).isin(SINAV_MRK4).to_numpy() | np.isin(Pn.stk, list(_mal_degil))      # sahip: sınav kurumsal paketleri devre dışı (KatAna LIKE 'Sınav Okul%')
idx = np.nonzero(((Y[:, T0 - 26:T1].sum(1) > 0) | (s0 > 0)) & ~KURUMSAL)[0]                 # test döneminde ya da öncesinde satışı olan ya da stoklu
n = len(idx); c_ = np.nan_to_num(cost[idx]); p_ = fiyat[idx]
_kdv = pd.read_csv(os.path.join(os.path.dirname(O.rstrip("/\\")), "talep-tahmin-ortak", "kdv.csv")).drop_duplicates("stk").set_index("stk")["kdv"]
PNET = p_ / (1 + _kdv.reindex(Pn.stk[idx]).fillna(0).to_numpy(float) / 100)          # kart fiyatı KDV dahil (ölçüldü 2026-10-15)
if V4: PNET = PNET_ALL[idx]
print(f"{MAG}: ürün {n:,}, test haftaları {T0}…{T1 - 1}", file=sys.stderr)

# ═══ ön-kayıt 7 (ENS b0e7dba) — sezon ön-yükleme: A1 ürün LY · A2 kategori profili ═══
SEZON = os.environ.get("SEZON", "")
EVL = sorted([(e["olay"], e["w"]) for e in EV.events()], key=lambda x: x[1])
KMIN, KMAX = -8, 4


def capa(t):
    best = None
    for o, we in EVL:
        k = t + 0.5 - we
        if KMIN <= k <= KMAX and (best is None or abs(k) < abs(best[2])): best = (o, we, k)
    if best is None: return None
    prev = [w for oo, w in EVL if oo == best[0] and w < best[1] - 26]
    return best[1] - prev[-1] if prev else None


_son = O.rstrip("/\\").rsplit("-", 1)[-1]; MEKAN = int(_son) if _son.isdigit() else 1
B_KIR = (dt.date(2024, 8, 5) - EV.D0).days // 7; CATS = list(np.unique(katana))
SINAV_J = np.array([j for j, nm in enumerate(CATS) if nm in SINAV], int)
if SEZON == "A2" and MEKAN in (1, 4478):
    _R = os.path.join(os.path.dirname(O.rstrip("/\\")), "talep-tahmin-4477")
    _Pr = F.load_panel(f"{_R}/weekly.csv", f"{_R}/toplu.csv", f"{_R}/devredisi.csv")
    _kr = pd.read_csv(f"{_R}/urunbilgi.csv").drop_duplicates("stk").set_index("stk")["katana"].reindex(_Pr.stk).fillna("Bilinmiyor").to_numpy()
    _Cr, _ = M.category_totals(_Pr.Y, _kr); _cr = list(np.unique(_kr)); C_REF = np.zeros_like(C); _wn = min(W, _Cr.shape[1])
    for j, nm in enumerate(CATS):
        if nm in _cr: C_REF[j, :_wn] = _Cr[_cr.index(nm), :_wn]


def _profiles(Cm, t, flt=lambda w: True):
    ncat = Cm.shape[0]; tot = Cm.sum(0); ks = np.arange(KMIN, KMAX + 1); prof = {}
    for o in sorted({o for o, _ in EVL}):
        occ = [w for oo, w in EVL if oo == o and w + KMAX < t and w - 26 >= 0 and flt(w)]
        if not occ: continue
        lc = np.zeros((ncat, len(ks))); lg = np.zeros(len(ks)); B = np.zeros(ncat)
        for we in occ:
            seg = slice(we - 26, min(t, we + 27)); bc = np.median(Cm[:, seg], axis=1); bg = np.median(tot[seg])
            lc += np.log((Cm[:, we + ks] + 1) / (bc[:, None] + 1)); lg += np.log((tot[we + ks] + 1) / (bg + 1)); B += bc
        lc /= len(occ); lg /= len(occ); B /= len(occ); wgt = (B / (B + 50.0))[:, None]
        prof[o] = np.clip(np.exp(wgt * lc + (1 - wgt) * lg[None, :]), 0.3, 6.0)
    return prof


def kat_indeks(t):
    ks = np.arange(KMIN, KMAX + 1); prof = _profiles(C, t)
    if MEKAN in (1, 4478) and t > B_KIR and len(SINAV_J):
        post = _profiles(C, t, lambda w: w + KMIN >= B_KIR); ref = _profiles(C_REF, t)
        for o in prof:
            src = post.get(o, ref.get(o)); prof[o][SINAV_J] = src[SINAV_J] if src is not None else 1.0
    U = np.ones((C.shape[0], W)); best = np.full(W, 99)
    for o, we in EVL:
        if o not in prof: continue
        for j, k in enumerate(ks):
            w = we + k
            if 0 <= w < W and abs(k) < best[w]: best[w] = abs(k); U[:, w] = prof[o][:, j]
    return U


def sezon_mu(t, mu_h):
    """Sezon katmanı: haftalık μ'yü (yalnız t öncesi veriyle) yükseltir; çapa yoksa değiştirmez."""
    if not SEZON: return mu_h
    if SEZON == "A1":
        s1 = capa(t)
        if not s1 or t - s1 - 13 < 0: return mu_h
        ly = Y[idx, t - s1]; num = Y[idx, t - 13:t].sum(1); den = Y[idx, t - s1 - 13:t - s1].sum(1)
        cnum = C[:, t - 13:t].sum(1); cden = C[:, t - s1 - 13:t - s1].sum(1)
        gk = np.clip(np.where(cden > 0, cnum / np.maximum(cden, 1e-9), 1.0), 0.5, 2.0)[ci[idx]]
        g = np.clip((num + 5 * gk) / (den + 5), 0.5, 2.0)
        return np.maximum(mu_h, ly * g)
    if SEZON == "A2":
        if capa(t) is None and not any(KMIN <= t + 0.5 - we <= KMAX for _, we in EVL): return mu_h
        U = kat_indeks(t)[ci[idx]]
        oran = U[:, t] / U[:, t - 13:t].mean(1)
        return mu_h * np.maximum(1.0, oran)
    return mu_h


if SEZON: VAR_OVERRIDE = [(0.90, "tavansız", "raf kuralı var")]
# haftalık Min/Max (her SL için) — yalnız t öncesi veri
VAR = [(sl, v, kr) for sl in SLS for v in ("tavansız", f"{MAXGUN} gün tavanlı") for kr in ("raf kuralı yok", "raf kuralı var")]
if SEZON: VAR = VAR_OVERRIDE; SLS = (0.90,)
mins = {k: np.zeros((n, TEST)) for k in VAR}; maxs = {k: np.zeros((n, TEST)) for k in VAR}; gun_min = {k: [] for k in VAR}; gun_max = {k: [] for k in VAR}
for k in range(TEST):
    t = T0 + k
    mu_h = sezon_mu(t, np.maximum(v4(t, idx), 0)); sd_h = Y[idx, t - 26:t].std(1)
    if os.environ.get("SIGMA") == "MAD":                                            # ön-kayıt 9 (v3): zirveye duyarsız oynaklık
        _w = Y[idx, t - 26:t]; sd_h = 1.4826 * np.median(np.abs(_w - np.median(_w, axis=1, keepdims=True)), axis=1)
    mu_g, sd_g = mu_h / 7, sd_h / np.sqrt(7)
    with np.errstate(divide="ignore", invalid="ignore"):
        eoq = np.where(c_ > 0, np.sqrt(2 * 52 * mu_h * K_TL / (c_ * H_YIL)), 0)
    olu = (mu_h <= 0) & (sd_h <= 0)
    # v2 stoklama kararı (TASARIM DÜZELTMESİ, ENS 38f18e8): bir yılda ≥1 satış olasılığı × marj ≥ elde tutma maliyeti
    psat = 1 - np.exp(-52 * mu_h)
    stokla = (p_ > c_) & (psat * (p_ - c_) >= c_ * H_YIL)
    if os.environ.get("STOKLAMA") == "v3" or V4:                                          # ön-kayıt 10: rafta kalma süresi + KDV hariç net fiyat
        stokla = (PNET > c_) & (52 * mu_h >= c_ * H_YIL / np.maximum(PNET - c_, 1e-9))
    olu = olu | ~stokla
    for sl in SLS:
        mn = np.floor(mu_g * P_GUN + norm.ppf(sl) * sd_g * np.sqrt(P_GUN) + 0.5)      # v2: olağan yuvarlama
        mx = mn + np.maximum(1, np.ceil(np.nan_to_num(eoq)))
        mxc = np.minimum(mx, np.maximum(mn + 1, np.ceil(mu_g * MAXGUN)))      # gün tavanı (ek, sahip sorusu)
        for v, m_ in (("tavansız", mx), (f"{MAXGUN} gün tavanlı", mxc)):
          for kr in ("raf kuralı yok", "raf kuralı var"):
            key = (sl, v, kr)
            if key not in mins: continue
            mn_k = np.where(olu, 0, mn); mx_k = np.where(olu, 0, m_)
            if kr == "raf kuralı var": mx_k = np.where(RAF[idx], np.maximum(mx_k, 1), mx_k); mn_k = np.where(RAF[idx], np.maximum(mn_k, 0), mn_k)
            mins[key][:, k] = mn_k; maxs[key][:, k] = mx_k
            ok = (~olu) & (mu_g > 0)
            gun_min[key].append(np.median(mn[ok] / mu_g[ok]) if ok.any() else np.nan); gun_max[key].append(np.median(m_[ok] / mu_g[ok]) if ok.any() else np.nan)

D = Y[idx, T0:T1] / 7.0                                                       # günlük talep (hafta içi eşit — VARSAYIM)


def is_gunu_sonra(d, k):                                                     # d günü (0=Pzt) + k iş günü
    while k > 0:
        d += 1
        if d % 7 < 5: k -= 1
    return d


rows = []
TANI = os.environ.get("TANI")                      # tanı modu: yalnız SL 0.9 · tavansız · raf var; ürün bazlı kayıt
if TANI or SEZON: VAR = [(0.90, "tavansız", "raf kuralı var")]
for sl, var, kr in VAR:
    key = (sl, var, kr)
    inv = s0[idx].clip(min=0).astype(float).copy(); pipe = {}
    lost = np.zeros(n); inv_sum = np.zeros(n); lines = np.zeros(n); stockout_w = np.zeros((n, TEST), bool)
    for d in range(TEST * 7):
        wk = d // 7
        inv += pipe.pop(d, 0)
        if d % 7 < 5:                                                        # iş günü: gözden geçir, sipariş ver
            yol = sum(v for kk, v in pipe.items() if kk > d)
            pos = inv + yol
            o = np.where(pos <= mins[key][:, wk], maxs[key][:, wk] - pos, 0); o = np.maximum(o, 0)
            lines += o > 0
            a = is_gunu_sonra(d, L_IS); pipe[a] = pipe.get(a, 0) + o
        dem = D[:, wk]; sold = np.minimum(inv, dem); lost += dem - sold; inv -= sold
        stockout_w[:, wk] |= (inv <= 1e-9) & (dem > 0)
        inv_sum += inv
    if TANI or SEZON:
        hic = (maxs[key] == 0).all(1)                                        # tüm test boyunca hiç stoklanmayan
        tepe = Y[idx, T0:T1].max(1) > 3 * np.maximum(D.mean(1) * 7, 1e-9)     # tepe haftası ortalamanın 3 katından büyük
        np.savez_compressed(OUT + "-tani.npz", stk=Pn.stk[idx], grup=GRUP[idx], lost=lost, dem=D.sum(1) * 7, hic=hic, tepe=tepe, inv=inv_sum / (TEST * 7), c=c_)
    for g in ("Kitap-Hazırlık", "Kitap-Genel", "Kırtasiye / Hediyelik", "Oyuncak / Elektronik", "Diğer", "TÜMÜ"):
        m = np.ones(n, bool) if g == "TÜMÜ" else (GRUP[idx] == g)
        dem_tot = D[m].sum() * 7
        rows.append({"sezon": SEZON or "v2", "pencere": f"{T0}-{T1 - 1}", "mağaza": MAG, "SL": sl, "varyant": var, "raf_kuralı": kr, "medyan_min_gün": np.nanmedian(gun_min[key]), "medyan_max_gün": np.nanmedian(gun_max[key]), "grup": g, "ürün": int(m.sum()), "talep": dem_tot, "kaçan_adet": lost[m].sum(),
                     "kaçan_%": 100 * lost[m].sum() / max(dem_tot, 1e-9), "kaçan_TL": (lost * p_)[m].sum(),
                     "ort_stok_TL": (inv_sum / (TEST * 7) * c_)[m].sum(), "sipariş_satırı": lines[m].sum(),
                     "stoksuz_ürün_hafta_%": 100 * stockout_w[m].sum() / max(m.sum() * TEST, 1), "son_stok_TL": (inv * c_)[m].sum()})

# GERÇEKLEŞEN — aynı dönem, panel (irsHrk)
Sw = St[idx, T0:T1]; Sw0 = np.nan_to_num(Sw, nan=0.0).clip(min=0)
aktif = Y[idx, T0 - 13:T0].sum(1) > 0
cz = SK.censor_flags(St)[idx, T0:T1]
for g in ("Kitap-Hazırlık", "Kitap-Genel", "Kırtasiye / Hediyelik", "Oyuncak / Elektronik", "Diğer", "TÜMÜ"):
    m = np.ones(n, bool) if g == "TÜMÜ" else (GRUP[idx] == g)
    dem_tot = Y[idx, T0:T1][m].sum()
    rows.append({"sezon": "", "pencere": f"{T0}-{T1 - 1}", "mağaza": MAG, "SL": "gerçekleşen", "varyant": "", "raf_kuralı": "", "grup": g, "ürün": int(m.sum()), "talep": dem_tot, "kaçan_adet": np.nan, "kaçan_%": np.nan,
                 "kaçan_TL": np.nan, "ort_stok_TL": (Sw0.mean(1) * c_)[m].sum(), "sipariş_satırı": np.nan,
                 "stoksuz_ürün_hafta_%": 100 * (cz & (Y[idx, T0:T1] > 0) | cz & aktif[:, None])[m].sum() / max(m.sum() * TEST, 1),
                 "son_stok_TL": (Sw0[:, -1] * c_)[m].sum()})
df = pd.DataFrame(rows); df.to_csv(OUT + ".csv", index=False, encoding="utf-8-sig")
pd.set_option("display.width", 220)
print(df.round(1).to_string(index=False))
