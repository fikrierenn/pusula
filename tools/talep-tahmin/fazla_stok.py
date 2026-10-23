"""
1 yıldan fazla yetecek stok listesi (sahip isteği, 2026-10-14). Model GEREKMEZ — şeffaf ölçü:
  kapsama_ham (yıl)    = bugünkü stok / son 52 haftanın perakende satışı (POS − POS iade; toplu/fatura satışı HARİÇ)
  kapsama (yıl)        = bugünkü stok / (son 52 hafta × büyüme)   ← sınıflandırma BUNA göre (sahip: "yıllık büyüme de olmalı")
  büyüme: kategori g_k = son 52h / önceki 52h (kategori toplamı); ürün g = (s52 + κ·g_k)/(s52_önceki + κ), κ=5, [0.25, 2];
          yeni ürün (giriş < 52h) → g_k (kendi geçmişi yok)
  sınıf: ölü (52 haftada 0 satış) · >3 yıl · 1–3 yıl
  yeni ürün işareti: giriş < 52 hafta → geçmiş satış eksik görünür, kapsama ŞİŞİK olabilir
Stok kaynağı: mağaza 1 → bkm.OneriSiparis bugünkü satır (items.csv); diğer mağaza → stok hareketlerinden yeniden kurulan panel (son hafta sonu).
Maliyet: bkm.UrunBilgi.SonAlis; yoksa fiyat × 0.6 (işaretlenir).
Kullanım: python fazla_stok.py <data_dir> <mağaza_adı> <çıktı.html>
"""
import datetime as dt
import html
import os
import sys

import numpy as np
import pandas as pd

import events as EV
import forecast as F
import stock as SK

O, MAG, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
P = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv"); Y, W = P.Y, P.Y.shape[1]
son = EV.D0 + dt.timedelta(weeks=W) - dt.timedelta(days=1)
ub = pd.read_csv(f"{O}/urunbilgi.csv").drop_duplicates("stk").set_index("stk")
_ortak = os.path.join(os.path.dirname(O.rstrip("/\\")), "talep-tahmin-ortak", "urunbilgi-tum.csv")   # satışı olmayan ürünlerin kartı (mekan 1/4477'de HERHANGİ hareket)
if os.path.exists(_ortak):
    _u2 = pd.read_csv(_ortak, low_memory=False).drop_duplicates("stk").set_index("stk"); ub = pd.concat([ub, _u2[~_u2.index.isin(ub.index)]])
dis = set(pd.read_csv(f"{O}/devredisi.csv").iloc[:, 0])
names = pd.read_csv(f"{O}/adlar.csv").drop_duplicates("stk").set_index("stk")["ad"]

if os.path.exists(f"{O}/items.csv"):
    it = pd.read_csv(f"{O}/items.csv").drop_duplicates("stk"); stok = it.set_index("stk")["stok"]; kaynak = "bkm.OneriSiparis (bugün)"
else:
    S = SK.load_stock(f"{O}/stokhareket.csv", P.stk, W); stok = pd.Series(S[:, W - 1], index=P.stk); kaynak = f"stok hareketlerinden kurulan panel ({son:%d.%m.%Y})"
stok = stok[(stok > 0) & ~stok.index.isin(dis)]
kartsiz = stok[~stok.index.isin(ub.index)]                       # ürün kartı yok (ad/kategori/maliyet yok) → ana listeden çıkar, ayrı say
stok = stok[stok.index.isin(ub.index)]
print(f"ürün kartı olmayan stoklu kod: {len(kartsiz):,} (toplam adet {kartsiz.sum():,.0f}; en büyük: {kartsiz.sort_values().tail(3).to_dict()}) → listede YOK")

pos = pd.Series(np.arange(len(P.stk)), index=P.stk)
s52 = np.array([Y[pos[s], W - 52:W].sum() if s in pos.index else 0.0 for s in stok.index])
s52p = np.array([Y[pos[s], W - 104:W - 52].sum() if s in pos.index else 0.0 for s in stok.index])
_kat_all = ub["katana"].reindex(P.stk).fillna("?").to_numpy()
_c52 = pd.Series(Y[:, W - 52:W].sum(1)).groupby(_kat_all).sum(); _c52p = pd.Series(Y[:, W - 104:W - 52].sum(1)).groupby(_kat_all).sum()
g_kat_tab = (_c52 / _c52p.where(_c52p > 0)).clip(0.5, 2.0).fillna(1.0)
lastw = np.array([(W - 1 - np.nonzero(Y[pos[s]] > 0)[0].max()) if s in pos.index and (Y[pos[s]] > 0).any() else np.nan for s in stok.index])
u = ub.reindex(stok.index)
cost = u["sonalis"].to_numpy(float); fb = ~(np.isfinite(cost) & (cost > 0))
cost = np.where(fb, u["fiyat"].to_numpy(float) * 0.6, cost)
giris = pd.to_datetime(u["giris"], errors="coerce")
yeni = (giris > pd.Timestamp(son) - pd.Timedelta(weeks=52)).to_numpy()
gk = g_kat_tab.reindex(u["katana"].fillna("?")).fillna(1.0).to_numpy()
g = np.where(yeni, gk, np.clip((s52 + 5 * gk) / (s52p + 5), 0.25, 2.0))
bek = s52 * g                                                     # beklenen 12 ay satış
with np.errstate(divide="ignore"):
    kap = np.where(bek > 0, stok.to_numpy(float) / bek, np.inf)
    kap_ham = np.where(s52 > 0, stok.to_numpy(float) / s52, np.inf)

df = pd.DataFrame({"stk": stok.index, "ürün": [names.get(s, "?") for s in stok.index], "grup": u["kat2"].to_numpy(), "kategori": u["katana"].to_numpy(),
                   "stok": stok.to_numpy(float), "satış_önceki_52h": s52p, "satış_52h": s52, "büyüme_kat": gk, "büyüme_ürün": g,
                   "beklenen_12ay": bek, "kapsama_ham_yıl": kap_ham, "kapsama_yıl": kap,
                   "son_satıştan_beri_hafta": lastw, "giriş": giris.dt.strftime("%d.%m.%Y").to_numpy(), "yeni_ürün(<52h)": np.where(yeni, "evet", ""),
                   "birim_maliyet": cost, "maliyet_tahmini": np.where(fb, "fiyat×0.6", ""), "stok_tutarı_TL": stok.to_numpy(float) * cost})
supheli = df[(df.stok_tutarı_TL > 5e6) | ((df.stok > 10_000) & (df.stok > 10 * np.maximum(df["satış_52h"], 1)))].copy()   # veri şüphesi: fiziksel olarak inanılmaz → toplamlara GİRMEZ
df = df[~df.stk.isin(supheli.stk)]
print(f"VERİ ŞÜPHESİ (stok > 10.000 adet ya da > 5M TL, toplamlardan çıkarıldı): {len(supheli)}"); print(supheli[["stk", "ürün", "kategori", "stok", "satış_52h", "birim_maliyet", "stok_tutarı_TL"]].to_string(index=False))
supheli.to_csv(OUT.replace(".html", ".veri-suphesi.csv"), index=False, encoding="utf-8-sig")
df = df[df.kapsama_yıl > 1].copy()
df["sınıf"] = np.where(~np.isfinite(df.kapsama_yıl), "ölü (52h satış yok)", np.where(df.kapsama_yıl > 3, ">3 yıl", "1–3 yıl"))
df["fazla_adet(1 yıl üstü)"] = np.where(np.isfinite(df.kapsama_yıl), df.stok - df["beklenen_12ay"], df.stok)
df["fazla_tutar_TL"] = df["fazla_adet(1 yıl üstü)"] * df.birim_maliyet
df = df.sort_values("fazla_tutar_TL", ascending=False)
df.to_csv(OUT.replace(".html", ".csv"), index=False, encoding="utf-8-sig")

tum = (stok * pd.Series(cost, index=stok.index)).drop(supheli.stk, errors="ignore").sum()
oz = df.groupby("sınıf").agg(ürün=("stk", "size"), stok_adet=("stok", "sum"), stok_TL=("stok_tutarı_TL", "sum"), fazla_TL=("fazla_tutar_TL", "sum"))
og = df.groupby(["grup"]).agg(ürün=("stk", "size"), stok_TL=("stok_tutarı_TL", "sum"), fazla_TL=("fazla_tutar_TL", "sum")).sort_values("fazla_TL", ascending=False)
ok = df.groupby(["kategori"]).agg(ürün=("stk", "size"), fazla_TL=("fazla_tutar_TL", "sum")).sort_values("fazla_TL", ascending=False).head(15)
pd.set_option("display.width", 220)
_ham = (kap_ham > 1).sum(); print(f"[karşılaştırma] büyümesiz ölçüyle 1 yıl üstü: {_ham:,} ürün · büyümeli: {len(df):,}")
print(f"{MAG}: stoklu ürün {len(stok):,}, toplam stok ≈ {tum:,.0f} TL (maliyet) · 1 yıldan fazla: {len(df):,} ürün, stok {df.stok_tutarı_TL.sum():,.0f} TL, "
      f"1 yıl ÜSTÜ kısım {df.fazla_tutar_TL.sum():,.0f} TL · yeni ürün işaretli {int((df['yeni_ürün(<52h)'] == 'evet').sum()):,} · maliyet tahmini {int((df.maliyet_tahmini != '').sum()):,}")
print(oz.round(0).to_string()); print(og.round(0).to_string()); print(ok.round(0).to_string())

fmt = lambda v: "∞" if isinstance(v, float) and not np.isfinite(v) else (f"{v:,.1f}" if isinstance(v, float) and abs(v) < 100 else (f"{v:,.0f}" if isinstance(v, float) else str(v)))
tb = lambda d: "<div style='overflow-x:auto'><table><tr>" + "".join(f"<th>{html.escape(str(c))}</th>" for c in [d.index.name or ""] + list(d.columns)) + "</tr>" + "".join(
    "<tr><td>" + html.escape(str(i)) + "</td>" + "".join(f"<td>{html.escape(fmt(v))}</td>" for v in r) + "</tr>" for i, r in zip(d.index, d.itertuples(index=False))) + "</table></div>"
cols = ["ürün", "grup", "kategori", "stok", "satış_önceki_52h", "satış_52h", "büyüme_ürün", "beklenen_12ay", "kapsama_ham_yıl", "kapsama_yıl", "son_satıştan_beri_hafta", "giriş", "yeni_ürün(<52h)", "sınıf", "fazla_adet(1 yıl üstü)", "fazla_tutar_TL", "maliyet_tahmini"]
open(OUT, "w", encoding="utf-8").write(f"""<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>Fazla stok {MAG}</title>
<style>body{{font:13px system-ui;margin:16px;background:#fff;color:#111}}@media(prefers-color-scheme:dark){{body{{background:#161616;color:#eee}}}}
table{{border-collapse:collapse;margin-bottom:16px}}td,th{{border-bottom:1px solid #8884;padding:3px 7px;text-align:right;white-space:nowrap}}td:first-child,th:first-child{{text-align:left}}</style></head><body>
<h2>{html.escape(MAG)} — 1 yıldan fazla yetecek stok ({son:%d.%m.%Y} itibarıyla)</h2>
<p><b>Ölçü:</b> kapsama = stok ÷ beklenen 12 ay satış; beklenen = son 52 hafta perakende satış (POS − iade; toplu/fatura hariç) × büyüme.
Büyüme: ürünün son 52h / önceki 52h oranı, 5 adet ağırlıkla kategori büyümesine büzülmüş, [0,25–2] sınırlı; yeni üründe kategori büyümesi.
kapsama_ham = büyümesiz (karşılaştırma). GBM modeli kullanılmadı. <b>Stok:</b> {html.escape(kaynak)}.
<b>Maliyet:</b> son alış; yoksa fiyat×0.6 (işaretli). <b>Uyarılar:</b> yeni ürün (giriş &lt; 52 hafta) kapsaması şişik görünebilir · toplu/fatura satışı olan ürünlerde
gerçek çıkış daha yüksek · iade edilebilirlik (yayınevi/tedarikçi) bilinmiyor.</p>
<p><b>Veri şüphesi ({len(supheli)} ürün) toplamlara GİRMEDİ:</b> {html.escape("; ".join(f"{r.stk} {r.ürün} — stok {r.stok:,.0f} adet, {r.stok_tutarı_TL:,.0f} TL" for r in supheli.itertuples()))}. Ayrı dosya: .veri-suphesi.csv</p>
<p>Ürün kartı olmayan {len(kartsiz):,} stoklu kod listeden çıkarıldı (toplam {kartsiz.sum():,.0f} adet — tek kod 14,6M adet gösterebiliyor; sistem/yer tutucu kod olabilir, DOĞRULANMADI).</p>
<p>Stoklu ürün {len(stok):,} · toplam stok ≈ {tum:,.0f} TL · <b>1 yıldan fazla: {len(df):,} ürün, {df.stok_tutarı_TL.sum():,.0f} TL; bunun 1 yılı AŞAN kısmı {df.fazla_tutar_TL.sum():,.0f} TL</b></p>
<h3>Sınıf</h3>{tb(oz)}<h3>Grup</h3>{tb(og)}<h3>En çok fazla stok bağlayan 15 kategori</h3>{tb(ok)}
<h3>En çok TL bağlayan ilk 300 ürün</h3>{tb(df.set_index("stk")[cols].head(300))}<p>Tam liste: aynı adla .csv (Excel).</p></body></html>""")
print("→", OUT)
