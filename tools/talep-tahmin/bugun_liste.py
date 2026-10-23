"""
Bugünün ürün ürün sipariş listesi (ileriye dönük) — mağaza 1.
  stok, proc önerisi, Min/Max  ← items.csv (bkm.OneriSiparis, bugünün satırı)
  tahmin                       ← yalnız T öncesi haftalar (v4: ilk1000 geo(v3,SES0.5), kuyruk v3)
  öneri                        ← order-up-to: S = ⌈Q_q((7+L)/7 × haftalık tahmin)⌉, sipariş = max(0, S − stok)   (yoldaki = 0 VARSAYIMI)
  kantiller                    ← 1-hafta artıkları, T öncesi son 6 origin (t + 4 ≤ T)
Kullanım: python bugun_liste.py <data_dir> <T(hafta)> <tarih> <çıktı.html> [q=0.9] [L=2]
"""
import datetime as dt
import html
import sys

import numpy as np
import pandas as pd

import evaluate as E
import forecast as F
import models as M
import policy_backtest as PB

O, T, TARIH, OUT = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
Q = float(sys.argv[5]) if len(sys.argv) > 5 else 0.9
L = int(sys.argv[6]) if len(sys.argv) > 6 else 2
ONAY_TL = 5000.0   # ENS K6 eşiği gibi — KALİBRE DEĞİL; ENS kernel çağrılmıyor, kural bu betikte uygulanıyor

P = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv"); Y, first, W = P.Y, P.first, P.Y.shape[1]
assert T <= W, f"T={T} panelden ileride (W={W})"
ub = pd.read_csv(f"{O}/urunbilgi.csv").set_index("stk")
katana = ub["katana"].reindex(P.stk).fillna("Bilinmiyor").to_numpy(); kc = np.unique(katana, return_inverse=True)[1]
cost_all = ub["sonalis"].reindex(P.stk).to_numpy(float)
C, ci = M.category_totals(Y, katana)
gm = M.GlobalModel(Y, first, ci, C, ub["fiyat"].reindex(P.stk).to_numpy(float), kc.astype(np.float32), use_price=False)


def fc(t, idx):
    if gm.trained_at is None or t - gm.trained_at >= 12: gm.fit(t)
    g = gm.predict(t, idx); s5 = E.ses(Y[idx], t, first[idx], 0.5)
    past52 = Y[:, t - 52:t].sum(1); pop = Y[:, t - 13:t].sum(1) > 0
    order = np.argsort(-np.where(pop, past52, -1)); rank = np.empty(len(Y), int); rank[order] = np.arange(len(Y))
    r = rank[idx]; tier = np.where(r < 100, "ilk100", np.where(r < 1000, "ilk1000", "kuyruk"))
    return np.where(r < 1000, np.sqrt(np.maximum(g, 0) * np.maximum(s5, 0)), g), tier, r


rq = PB.ResidualQuantiles()
for t in range(T - 4 - 20, T - 4 + 1, 4):                      # 6 origin; haftalık hedefler t..t+3 < T
    idx = np.nonzero(Y[:, t - 13:t].sum(1) > 0)[0]
    Fp, tier, _ = fc(t, idx); fw = Fp / 4
    for k in range(4):
        for tt in ("ilk100", "ilk1000", "kuyruk"): rq.add(tt, fw[tier == tt], Y[idx[tier == tt], t + k])
rq.fit()

it = pd.read_csv(f"{O}/items.csv")                               # bugünkü OneriSiparis satırları
pos = pd.Series(np.arange(len(P.stk)), index=P.stk)
it = it[it.stk.isin(pos.index) & ((it.m90 > 0) | (it.oneri > 0))].copy()
idx = pos[it.stk].to_numpy()
Fp, tier, rank = fc(T, idx); fw = Fp / 4
h = (7 + L) / 7.0
S = np.ceil(rq.q(tier, fw * h, Q)); lo = rq.q(tier, fw * h, 0.1); hi = rq.q(tier, fw * h, 0.9)
stok = np.maximum(it.stok.to_numpy(float), 0)
yeni = np.maximum(0, S - stok); proc = np.maximum(it.oneri.fillna(0).to_numpy(float), 0)
c = np.where(np.isfinite(cost_all[idx]) & (cost_all[idx] > 0), cost_all[idx], it.fiyat.fillna(0).to_numpy(float) * 0.6)
names = pd.read_csv(f"{O}/adlar.csv").drop_duplicates("stk").set_index("stk")["ad"]
with np.errstate(divide="ignore", invalid="ignore"):
    hafta_stok = np.where(fw > 0.05, stok / fw, np.inf)
df = pd.DataFrame({"sıra": rank + 1, "stk": it.stk.to_numpy(), "ürün": [names.get(s, "?") for s in it.stk],
                   "kategori": [ub["katana"].get(s, "?") for s in it.stk], "stok": stok,
                   "haftalık_tahmin": fw, f"{7+L}g_aralık": [f"{a:.0f}–{b:.0f}" for a, b in zip(lo, hi)],
                   "hedef_S": S, "kaç_haftalık_stok": hafta_stok, "proc_min_max": [f"{a:.0f}/{b:.0f}" for a, b in zip(it.mn, it.mx)],
                   "proc_öneri": proc, "yeni_öneri": yeni, "yeni_tutar_TL": yeni * c})


def neden(r):
    if r.yeni_öneri > 0 and r.proc_öneri == 0: return f"stok {r.stok:.0f} < {7+L} günlük %{Q*100:.0f} ihtiyaç {r.hedef_S:.0f}; proc stok>Min dediği için 0"
    if r.yeni_öneri == 0 and r.proc_öneri > 0: return f"stok {r.stok:.0f} ≥ {7+L} günlük %{Q*100:.0f} ihtiyaç {r.hedef_S:.0f}; proc Min'e düştüğü için Max'a tamamlıyor"
    if r.yeni_öneri > 0: return f"ikisi de sipariş diyor; yeni {r.yeni_öneri:.0f}, proc {r.proc_öneri:.0f}"
    return ""


df["neden"] = df.apply(neden, axis=1)
df["onay(kural)"] = np.where(df.yeni_tutar_TL >= ONAY_TL, "onay gerekli", "")
df["fazla_stok"] = np.where(df.kaç_haftalık_stok > 26, "⚠ >6 ay", "")
df = df.sort_values("sıra")
df.to_csv(OUT.replace(".html", ".csv"), index=False, encoding="utf-8-sig")
top100 = df[df.sıra <= 100]
fark = df[(df.yeni_öneri != df.proc_öneri)].sort_values("sıra")
cols = ["sıra", "ürün", "kategori", "stok", "haftalık_tahmin", f"{7+L}g_aralık", "kaç_haftalık_stok", "proc_min_max", "proc_öneri", "yeni_öneri", "yeni_tutar_TL", "onay(kural)", "fazla_stok", "neden"]
fmt = {"stok": "{:.0f}", "haftalık_tahmin": "{:.1f}", "kaç_haftalık_stok": "{:.1f}", "proc_öneri": "{:.0f}", "yeni_öneri": "{:.0f}", "yeni_tutar_TL": "{:,.0f}"}


def tablo(d):
    th = "".join(f"<th>{c}</th>" for c in cols)
    tr = "".join("<tr>" + "".join(f"<td>{html.escape(fmt[c].format(r[c]) if c in fmt and np.isfinite(r[c]) else ('∞' if c in fmt else str(r[c])))}</td>" for c in cols) + "</tr>" for _, r in d.iterrows())
    return f"<div style='overflow-x:auto'><table><tr>{th}</tr>{tr}</table></div>"


ozet = {"ürün": len(df), "proc sipariş veren": int((df.proc_öneri > 0).sum()), "yeni sipariş veren": int((df.yeni_öneri > 0).sum()),
        "proc toplam adet": int(df.proc_öneri.sum()), "yeni toplam adet": int(df.yeni_öneri.sum()),
        "yeni toplam TL (maliyet)": f"{(df.yeni_öneri * 0 + df.yeni_tutar_TL).sum():,.0f}", "6 aydan fazla stoklu ürün": int((df.kaç_haftalık_stok > 26).sum())}
print(f"T={T} ({TARIH}) q={Q} L={L}  özet: {ozet}")
print(top100[cols[:11]].head(25).to_string(index=False, float_format=lambda v: f"{v:.0f}"))
open(OUT, "w", encoding="utf-8").write(f"""<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>Sipariş listesi {TARIH}</title>
<style>body{{font:13px system-ui;margin:16px;background:#fff;color:#111}}@media(prefers-color-scheme:dark){{body{{background:#161616;color:#eee}}}}
table{{border-collapse:collapse}}td,th{{border-bottom:1px solid #8884;padding:3px 7px;text-align:right;white-space:nowrap}}td:nth-child(2),td:nth-child(3),td:last-child,th:nth-child(2),th:nth-child(3){{text-align:left}}</style></head><body>
<h2>Mağaza 1 — sipariş önerisi {TARIH} (q={Q}, tedarik {L} iş günü, haftalık gözden geçirme)</h2>
<p><b>Kaynaklar:</b> stok/proc önerisi/Min-Max = bugünkü bkm.OneriSiparis · tahmin = 11.10.2026'ya kadarki perakende satış (v4) ·
öneri = {7+L} günlük ihtiyacın %{Q*100:.0f} kantiline tamamla − stok. <b>Varsayım:</b> yolda mal yok (veri alınmadı). <b>onay(kural)</b> = sipariş tutarı ≥ {ONAY_TL:,.0f} TL —
bu betiğin kuralı, ENS kernel'i çağrılmadı, eşik kalibre değil. <b>kaç_haftalık_stok</b> = stok / haftalık tahmin.</p>
<p><b>Özet:</b> {html.escape(str(ozet))}</p>
<h3>İlk 100 ürün (son 52 hafta satışına göre)</h3>{tablo(top100)}
<h3>Proc ile yeni önerinin farklı olduğu ürünler (ilk 300)</h3>{tablo(fark.head(300))}
<p>Tam liste: aynı adla .csv (Excel'de açılır).</p></body></html>""")
print("→", OUT, "+ .csv")
