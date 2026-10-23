"""
Eylül sınaması (yıl parametreli) (sahip isteği): 31.08.2026 sabahı tahmin et (yalnız ≤ 30.08 verisi) → 31.08–27.09 (4 hafta) gerçek satışla karşılaştır.
Yöntemler: 13h-ort (proc mantığı: Miktar90/3), v4 (ilk1000 geo(v3,SES0.5), kuyruk v3), v6⊕SES (sansür+takvim+büyüme).
Aralık: %80 (P10–P90), tahmin-göreli artık kantilleri — T öncesi 6 origin (hedef T'den önce kapanmış).
Sansür: hedef 4 haftada stok bitti mi (yeniden kurulan stok paneli) → bittiyse gerçek satış talebin ALT sınırı.
Kullanım: python eylul.py <data_dir> <çıktı.html>
"""
import datetime as dt
import html
import os
import sys

import numpy as np
import pandas as pd

import evaluate as E
import events as EV
import forecast as F
import models as M
import policy_backtest as PB
import stock as SK

O, OUT = sys.argv[1], sys.argv[2]
YIL = int(sys.argv[3]) if len(sys.argv) > 3 else 2026
SEZON = sys.argv[4] if len(sys.argv) > 4 else "okul"
H = 4
if SEZON == "okul":
    _s1 = dt.date(YIL, 9, 1); _mon = _s1 - dt.timedelta(days=_s1.weekday())    # 1 Eylül'e en yakın Pazartesi (aynı kural her yıl)
    ORIGIN = _mon if (_s1 - _mon).days <= 3 else _mon + dt.timedelta(days=7)
else:                                                                          # ön-kayıt eki 1 (3a18a1f)
    ORIGIN = {"yilbasi": EV.nth_weekday(YIL, 12, 0, 3), "yariyil": EV.nth_weekday(YIL, 1, 0, 3), "karne": EV.nth_weekday(YIL, 6, 0, 2),
              "ekim": EV.nth_weekday(YIL, 10, 0, 3), "mart": EV.nth_weekday(YIL, 3, 0, 1)}[SEZON]          # ekim/mart: sezon-dışı koruma (ön-kayıt 4)
T = (ORIGIN - EV.D0).days // 7
D_T = EV.D0 + dt.timedelta(weeks=T)

P = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv"); Y, first, W = P.Y, P.first, P.Y.shape[1]
ub = pd.read_csv(f"{O}/urunbilgi.csv").set_index("stk")
katana = ub["katana"].reindex(P.stk).fillna("Bilinmiyor").to_numpy(); kc = np.unique(katana, return_inverse=True)[1]
price = ub["fiyat"].reindex(P.stk).to_numpy(float)
C, ci = M.category_totals(Y, katana)
St = SK.load_stock(f"{O}/stokhareket.csv", P.stk, W); instock = ~SK.censor_flags(St)
evw = {}
for e in EV.events(): evw.setdefault(e["olay"], []).append(e["w"])
g = pd.to_datetime(ub["giris"].reindex(P.stk), errors="coerce"); launch_w = ((g - pd.Timestamp(EV.D0)).dt.days // 7).to_numpy(float)
v3 = M.GlobalModel(Y, first, ci, C, price, kc.astype(np.float32), use_price=False)
kat2 = ub["kat2"].reindex(P.stk).fillna("").to_numpy()
GRUP = np.where(np.isin(kat2, ["Kitap", "Kırtasiye / Hediyelik", "Oyuncak / Elektronik"]), kat2, "Diğer")
_SINAV5 = ["Eğitim - Sınavlara Hazırlık - Okula Yardımcı", "Sınavlara Hazırlık Kitapları", "Sınav Okul Malzemeleri", "Eğitim ve Okula Yardımcı Kitaplar"]
ALT = np.where(GRUP == "Kitap", np.where(np.isin(katana, _SINAV5), "Kitap-Hazırlık", "Kitap-Genel"), "")   # ön-kayıt 5 (ENS c9ffe3a)
v6 = M.GlobalModelV6(Y, first, ci, C, price, kc.astype(np.float32), use_price=False, instock=instock, event_weeks=evw, launch_w=launch_w)
v9 = M.GlobalModelV9(Y, first, ci, C, price, kc.astype(np.float32), use_price=False, instock=instock, event_weeks=evw, launch_w=launch_w,
                     evl=[(e["olay"], e["w"]) for e in EV.events()], cat_index=lambda t: cat_event_index(t))   # ön-kayıt 4




def season_uplift(t, idx, level, kappa=200.0, lo=0.5, hi=4.0):
    """ÖN-KAYIT (ea63c75) adayları. Geçmiş 1-2 sezon, TAKVİM hizalı (52y hafta önce):
    çarpan = Σ(sezon 4 haftası) / Σ(öncesindeki 13 haftanın 4 haftalık karşılığı).
    level='kategori' (v7r): kategori çarpanı, 1'e κ birimle büzülme, [lo, hi] sınırı.
    level='ürün'     (v7p): ürün çarpanı, kategori çarpanına κ birimle büzülme, [lo, hi] sınırı."""
    num = np.zeros(len(idx)); den = np.zeros(len(idx)); cnum = np.zeros(C.shape[0]); cden = np.zeros(C.shape[0])
    for y in (1, 2):
        a = t - 52 * y
        if a - 13 < 0: continue
        num += Y[idx, a:a + H].sum(1); den += Y[idx, a - 13:a].sum(1) / 13 * H
        cnum += C[:, a:a + H].sum(1); cden += C[:, a - 13:a].sum(1) / 13 * H
    uc = ((cnum + kappa) / (cden + kappa))[ci[idx]]              # kategori → 1'e büzülme
    u = uc if level == "kategori" else (num + kappa * uc) / (den + kappa)
    return np.clip(u, lo, hi)


EVL = [(e["olay"], e["w"]) for e in EV.events()]
KMIN, KMAX, KAPPA_W = -8, 4, 50.0
_ucache = {}


# ÖN-KAYIT EKİ 3 (056e893) — yapısal kırılma: Sınav Okulları operasyonu FSM (1) → İst.Yolu (4478), B = 2024-08-05
_son = O.rstrip("/\\").rsplit("-", 1)[-1]
MEKAN = int(os.environ.get("MEKAN") or (_son if _son.isdigit() else 1))
SINAV = ["Eğitim - Sınavlara Hazırlık - Okula Yardımcı", "Sınavlara Hazırlık Kitapları", "Sınav Okul Malzemeleri", "Eğitim ve Okula Yardımcı Kitaplar"]
B_KIR = (dt.date(2024, 8, 5) - EV.D0).days // 7
KIRILMA = MEKAN in (1, 4478)
CATS = np.unique(katana)
if KIRILMA:                                                       # kardeş mağaza Özlüce (4477) — kırılmasız, profil ödünç kaynağı
    REF = os.environ.get("REF_DIR") or os.path.join(os.path.dirname(O.rstrip("/\\")), "talep-tahmin-4477")
    _Pr = F.load_panel(f"{REF}/weekly.csv", f"{REF}/toplu.csv", f"{REF}/devredisi.csv")
    _kr = pd.read_csv(f"{REF}/urunbilgi.csv").set_index("stk")["katana"].reindex(_Pr.stk).fillna("Bilinmiyor").to_numpy()
    _Cr, _ = M.category_totals(_Pr.Y, _kr); _cr = list(np.unique(_kr))
    C_REF = np.zeros_like(C); _wn = min(W, _Cr.shape[1])
    for j, nm in enumerate(CATS):
        if nm in _cr: C_REF[j, :_wn] = _Cr[_cr.index(nm), :_wn]
    print(f"kırılma kuralı AKTİF: mağaza {MEKAN}, B=hafta {B_KIR}, ödünç profil kaynağı {REF}")
SINAV_J = np.array([j for j, nm in enumerate(CATS) if nm in SINAV], int)


def _profiles(Cm, t, occ_filter=lambda w: True):
    """olay → [n_kategori, len(ks)] profil; yalnız tamamen < t kapanmış tekrarlar."""
    ncat = Cm.shape[0]; tot = Cm.sum(0); ks = np.arange(KMIN, KMAX + 1); prof = {}
    for o in sorted({o for o, _ in EVL}):
        occ = [w for oo, w in EVL if oo == o and w + KMAX < t and w - 26 >= 0 and occ_filter(w)]
        if not occ: continue
        lc = np.zeros((ncat, len(ks))); lg = np.zeros(len(ks)); B = np.zeros(ncat)
        for we in occ:
            seg = slice(we - 26, min(t, we + 27))
            bc = np.median(Cm[:, seg], axis=1); bg = np.median(tot[seg])
            lc += np.log((Cm[:, we + ks] + 1) / (bc[:, None] + 1)); lg += np.log((tot[we + ks] + 1) / (bg + 1)); B += bc
        lc /= len(occ); lg /= len(occ); B /= len(occ)
        wgt = (B / (B + KAPPA_W))[:, None]                                   # küçük kategori → mağaza-geneli profile büzülür
        prof[o] = np.clip(np.exp(wgt * lc + (1 - wgt) * lg[None, :]), 0.3, 6.0)
    return prof


def cat_event_index(t):
    """ÖN-KAYIT EKİ 2 (21ce5d2) — v8k. Kategori × olay göreli-hafta profili (yalnız < t verisi), olay-hizalı.
    EKİ 3: mağaza ∈ {1, 4478}, sınav kategorileri, t > B → yalnız kırılma-sonrası tekrarlar (w_e − 8 ≥ B); yoksa Özlüce profili.
    Döner: U [n_kategori, W] — her hafta için en yakın olayın profil çarpanı (yakın olay yoksa 1)."""
    if t in _ucache: return _ucache[t]
    ncat = C.shape[0]; ks = np.arange(KMIN, KMAX + 1)
    prof = _profiles(C, t)
    if KIRILMA and t > B_KIR and len(SINAV_J):
        post = _profiles(C, t, lambda w: w + KMIN >= B_KIR); ref = _profiles(C_REF, t)
        for o in prof:
            src = post.get(o, ref.get(o))
            if src is not None: prof[o][SINAV_J] = src[SINAV_J]
            else: prof[o][SINAV_J] = 1.0
    U = np.ones((ncat, W)); best = np.full(W, 99)
    for o, we in EVL:
        if o not in prof: continue
        for j, k in enumerate(ks):
            w = we + k
            if 0 <= w < W and abs(k) < best[w]: best[w] = abs(k); U[:, w] = prof[o][:, j]
    _ucache[t] = U
    return U


def methods(t, idx):
    for m in (v3, v6, v9):
        # SIZINTI KORUMASI (2026-10-14): model t'den SONRAKİ veriyle eğitilmişse (t < trained_at) mutlaka yeniden eğit.
        if m.trained_at is None or t < m.trained_at or t - m.trained_at >= 12: m.fit(t)
    g3 = v3.predict(t, idx); g6 = v6.predict(t, idx); g9 = v9.predict(t, idx); s5 = E.ses(Y[idx], t, first[idx], 0.5)
    past52 = Y[:, t - 52:t].sum(1); pop = Y[:, t - 13:t].sum(1) > 0
    order = np.argsort(-np.where(pop, past52, -1)); rank = np.empty(len(Y), int); rank[order] = np.arange(len(Y))
    r = rank[idx]; top = r < 1000
    geo = lambda a, b: np.sqrt(np.maximum(a, 0) * np.maximum(b, 0))
    base = E.ma(Y[idx], t, 13)
    out = {"13h-ort (proc mantığı)": base, "v4": np.where(top, geo(g3, s5), g3), "v6⊕SES": np.where(top, geo(g6, s5), g6)}
    out["v7r⊕v6"] = geo(base * season_uplift(t, idx, "kategori", 200.0, 0.5, 4.0), out["v6⊕SES"])
    out["v7p⊕v6"] = geo(base * season_uplift(t, idx, "ürün", 200.0, 0.5, 3.0), out["v6⊕SES"])
    U = cat_event_index(t)[ci[idx]]
    lvl = Y[idx, t - 13:t].sum(1) / U[:, t - 13:t].sum(1)
    out["v8k⊕v6"] = geo(lvl * U[:, t:t + H].sum(1), out["v6⊕SES"])
    out["v9g"] = g9; out["v9g⊕SES"] = np.where(top, geo(g9, s5), g9); out["v6 saf (tanı)"] = g6
    return out, r


KEYS = ["13h-ort (proc mantığı)", "v4", "v6⊕SES", "v7r⊕v6", "v7p⊕v6", "v8k⊕v6", "v9g", "v9g⊕SES", "v6 saf (tanı)"]
cal = {k: PB.ResidualQuantiles() for k in KEYS}
# Aralık kalibrasyonu: SEZON-HİZALI — geçmiş yılların aynı sezon origin'i (±4 hafta) [yoksa son 6 origin]
cal_origins = [t for y in (1, 2) for t in (T - 52 * y - 4, T - 52 * y, T - 52 * y + 4) if t - 13 >= 104 and t + H <= T]
if not cal_origins: cal_origins = list(range(T - 4 - 20, T - 4 + 1, 4))
cal_origins = sorted(set(cal_origins))
print("kalibrasyon origin'leri:", cal_origins)
for t in cal_origins:
    idx = np.nonzero(Y[:, t - 13:t].sum(1) > 0)[0]
    fc, r = methods(t, idx); A = Y[idx, t:t + H].sum(1)
    tier = np.where(r < 100, "ilk100", np.where(r < 1000, "ilk1000", "kuyruk"))
    for k, Fp in fc.items():
        for tt in ("ilk100", "ilk1000", "kuyruk"): cal[k].add(tt, Fp[tier == tt], A[tier == tt])
for c in cal.values(): c.fit()

idx = np.nonzero(Y[:, T - 13:T].sum(1) > 0)[0]
fc, r = methods(T, idx); tier = np.where(r < 100, "ilk100", np.where(r < 1000, "ilk1000", "kuyruk"))
A = Y[idx, T:T + H].sum(1); cens = ~instock[idx, T:T + H].all(1)
names = pd.read_csv(f"{O}/adlar.csv").drop_duplicates("stk").set_index("stk")["ad"]

rows = []
for k, Fp in fc.items():
    lo = cal[k].q(tier, Fp, 0.1); hi = cal[k].q(tier, Fp, 0.9)
    seg = [("tümü", tn, mm) for tn, mm in (("ilk100", tier == "ilk100"), ("ilk1000", r < 1000), ("kuyruk", tier == "kuyruk"), ("tümü", np.ones(len(idx), bool)))]
    seg += [(gname, tn, (GRUP[idx] == gname) & mm) for gname in ("Kitap", "Kırtasiye / Hediyelik", "Oyuncak / Elektronik", "Diğer")
            for tn, mm in (("ilk1000", r < 1000), ("tümü", np.ones(len(idx), bool)))]
    seg += [(a_, tn, (ALT[idx] == a_) & mm) for a_ in ("Kitap-Hazırlık", "Kitap-Genel")
            for tn, mm in (("ilk1000", r < 1000), ("tümü", np.ones(len(idx), bool)))]
    if KIRILMA and SEZON == "okul" and YIL == 2024:                       # EKİ 3 — puandan çıkar, ayrı raporla
        sin = np.isin(katana[idx], SINAV)
        seg = [(g_, t_, m_ & ~sin) for g_, t_, m_ in seg] + [("sınav (kırılma etkili)", "tümü", sin)]
    for grp, tn, m in seg:
        a, f, cz = A[m], np.maximum(Fp[m], 0), cens[m]
        if a.sum() <= 0: continue
        fair = np.where(cz, np.maximum(0, a - f), np.abs(f - a))
        rows.append({"yöntem": k, "grup": grp, "katman": tn, "ürün": int(m.sum()), "tahmin_toplam": f.sum(), "gerçek_toplam": a.sum(),
                     "toplam_sapma%": 100 * (f.sum() / a.sum() - 1), "WAPE": np.abs(f - a).sum() / a.sum(), "adil_WAPE": fair.sum() / a.sum(),
                     "aralık_kapsama%": 100 * ((a >= lo[m]) & (a <= hi[m])).mean(), "stok_biten_ürün%": 100 * cz.mean()})
np.savez_compressed(OUT.replace(".html", ".tahmin.npz"), stk=P.stk[idx], gercek=A, sansur=cens, sira=r,
                    **{k.replace("⊕", "+").replace(" ", "_").replace("(", "").replace(")", ""): v for k, v in fc.items()})   # ön-kayıt 5: ürün-düzeyi kayıt
summ = pd.DataFrame(rows); summ.insert(0, "yıl", YIL); summ.insert(0, "sezon", SEZON); summ.to_csv(OUT.replace(".html", ".ozet.csv"), index=False, encoding="utf-8-sig")
pd.set_option("display.width", 220)
print(f"[{SEZON} {YIL}] Origin {D_T} (hafta {T}); hedef {D_T} → {D_T + dt.timedelta(weeks=4)}; ürün {len(idx):,}")
print(summ.round(3).to_string(index=False))

lo4 = cal["v4"].q(tier, fc["v4"], 0.1); hi4 = cal["v4"].q(tier, fc["v4"], 0.9)
det = pd.DataFrame({"sıra": r + 1, "ürün": [names.get(s, "?") for s in P.stk[idx]], "kategori": katana[idx],
                    "13h-ort": fc["13h-ort (proc mantığı)"], "v4": fc["v4"], "v4_%80_aralık": [f"{a:.0f}–{b:.0f}" for a, b in zip(lo4, hi4)],
                    "v6⊕SES": fc["v6⊕SES"], "gerçek": A, "aralıkta": np.where((A >= lo4) & (A <= hi4), "✓", "✗"),
                    "stok_bitti": np.where(cens, "evet (gerçek alt sınır)", "")})
det = det.sort_values("sıra"); det.to_csv(OUT.replace(".html", ".csv"), index=False, encoding="utf-8-sig")
top = det.head(100)
print(top.head(20).to_string(index=False, float_format=lambda v: f"{v:.0f}"))
th = "".join(f"<th>{c}</th>" for c in top.columns)
tr = "".join("<tr>" + "".join(f"<td>{html.escape(f'{v:.0f}' if isinstance(v, float) else str(v))}</td>" for v in rw) + "</tr>" for rw in top.itertuples(index=False))
sh = "".join(f"<th>{c}</th>" for c in summ.columns)
sr = "".join("<tr>" + "".join(f"<td>{html.escape(f'{v:,.3f}' if isinstance(v, float) else str(v))}</td>" for v in rw) + "</tr>" for rw in summ.itertuples(index=False))
open(OUT, "w", encoding="utf-8").write(f"""<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>Eylül sınaması (yıl parametreli)</title>
<style>body{{font:13px system-ui;margin:16px;background:#fff;color:#111}}@media(prefers-color-scheme:dark){{body{{background:#161616;color:#eee}}}}
table{{border-collapse:collapse;margin-bottom:16px}}td,th{{border-bottom:1px solid #8884;padding:3px 7px;text-align:right;white-space:nowrap}}td:nth-child(2),td:nth-child(3),th:nth-child(2),th:nth-child(3){{text-align:left}}</style></head><body>
<h2>Eylül sınaması (yıl parametreli) — {D_T:%d.%m.%Y} sabahı tahmin, {D_T:%d.%m} → {(D_T + dt.timedelta(weeks=4)):%d.%m.%Y} gerçek satışla</h2>
<p>Model yalnız {(D_T - dt.timedelta(days=1)):%d.%m.%Y}'e kadarki perakende satışı gördü. Ürünler o güne kadarki 52 hafta satışına göre sıralı (sonuca göre seçim yok).
"stok_bitti" = 4 hafta içinde stok tükendi → gerçek satış talebin ALT sınırı; adil_WAPE bu ürünlerde yalnız eksik tahmini cezalandırır.</p>
<h3>Özet</h3><table><tr>{sh}</tr>{sr}</table>
<h3>İlk 100 ürün</h3><table><tr>{th}</tr>{tr}</table><p>Tamamı: aynı adla .csv</p></body></html>""")
print("→", OUT)
