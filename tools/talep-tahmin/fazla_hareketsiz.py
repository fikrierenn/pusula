"""
Tüm şubeler + Merkez Depo: 1 yıldan fazla yetecek stok + 52 haftadır gerçek hareketi olmayan stok (sahip isteği, 2026-10-14).
Girdi: .cache/talep-tahmin-ortak/fazla-<mekan>.csv (sorgular/06-operasyon/2026-10-14-fazla-hareketsiz-stok.sql)
  stok        = stokSonAltDepo_vw (anlık)
  talep (52h) = satış − iade (1,4,100 − 3,5,101); Merkez Depo'da + sevk (11 Depo Depo, 13 Depo Mağaza; çıkış bacağı)
  büyüme      = ürün (talep52 + κ·g_kat)/(talep52_önceki + κ), κ=5, [0.25, 2]; yeni ürün (giriş < 52h) → g_kat; g_kat ∈ [0.5, 2]
  kapsama     = stok / (talep52 × büyüme)  → > 1 yıl = fazla; fazla kısım = stok − beklenen 12 ay
  hareketsiz  = son GERÇEK hareket (defter düzeltmeleri 16/17/88/89/90/97/99 HARİÇ) 52 haftadan eski ya da hiç yok
  şirket geneli kapsama = ürünün 4 mekan toplam stoğu / şubelerin toplam satışı (+ depo satışı; iç sevk çift sayılmaz)
Kullanım: python fazla_hareketsiz.py <çıktı_dizini>
"""
import datetime as dt
import html
import os
import sys

import numpy as np
import pandas as pd

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
C = os.path.join(ROOT, ".cache")
OUTD = sys.argv[1]
MEKAN = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu", 12: "Merkez Depo"}
A = pd.Timestamp("2025-10-13"); BUGUN = pd.Timestamp("2026-10-14")
GERCEK_DISI = "16 Stok EKLE, 17 Merkezi Düzeltme, 88/89 Diğer Giriş/Çıkış, 90 Ürün SAY, 97 Devir, 99 Sayım"

kart = []
for f in ["talep-tahmin/urunbilgi.csv", "talep-tahmin-4477/urunbilgi.csv", "talep-tahmin-4478/urunbilgi.csv",
          "talep-tahmin-ortak/urunbilgi-tum.csv", "talep-tahmin-ortak/urunbilgi-4478-12.csv"]:
    p = os.path.join(C, f)
    if os.path.exists(p): kart.append(pd.read_csv(p, low_memory=False))
ub = pd.concat(kart).drop_duplicates("stk").set_index("stk")
ad = pd.read_csv(os.path.join(C, "talep-tahmin/adlar.csv")).drop_duplicates("stk").set_index("stk")["ad"]
if os.path.exists(os.path.join(C, "talep-tahmin-ortak/adlar-ek.csv")):
    ad = pd.concat([ad, pd.read_csv(os.path.join(C, "talep-tahmin-ortak/adlar-ek.csv")).drop_duplicates("stk").set_index("stk")["ad"]])
    ad = ad[~ad.index.duplicated()]

frames = []
for mk, mad in MEKAN.items():
    p = os.path.join(C, f"talep-tahmin-ortak/fazla-{mk}.csv")
    if not os.path.exists(p): print("YOK:", p); continue
    d = pd.read_csv(p).drop_duplicates("stk"); d["mekan"] = mad
    d["talep52"] = d.satis52 + (d.sevk52 if mk == 12 else 0); d["talep52p"] = d.satis52p + (d.sevk52p if mk == 12 else 0)
    frames.append(d)
D = pd.concat(frames, ignore_index=True)
_dis = set(pd.read_csv(os.path.join(C, "talep-tahmin/devredisi.csv")).iloc[:, 0])            # FifoDevreDisiUrunler (poşet, hediye çeki …)
print(f"envanter dışı (FifoDevreDisi) satır çıkarıldı: {int(D.stk.isin(_dis).sum()):,}"); D = D[~D.stk.isin(_dis)].reset_index(drop=True)
u = ub.reindex(D.stk)
D["ürün"] = [ad.get(s, "?") for s in D.stk]; D["grup"] = u["kat2"].to_numpy(); D["kategori"] = u["katana"].fillna("?").to_numpy()
cost = u["sonalis"].to_numpy(float); fb = ~(np.isfinite(cost) & (cost > 0))
D["birim_maliyet"] = np.where(fb, u["fiyat"].to_numpy(float) * 0.6, cost); D["maliyet_tahmini"] = np.where(fb, "fiyat×0.6", "")
D["kartsız"] = ~D.stk.isin(ub.index)
giris = pd.to_datetime(u["giris"], errors="coerce").to_numpy()
D["giriş"] = pd.Series(giris).dt.strftime("%d.%m.%Y").to_numpy(); D["yeni_ürün"] = pd.Series(giris).gt(BUGUN - pd.Timedelta(weeks=52)).to_numpy()

# büyüme — mekan × kategori, yalnız bu dosyadaki (stoklu) ürünlerden (YAKLAŞIK: stoğu bitmiş ürünler dahil değil)
t = D.groupby(["mekan", "kategori"])[["talep52", "talep52p"]].sum()
gk_tab = (t.talep52 / t.talep52p.where(t.talep52p > 0)).clip(0.5, 2.0).fillna(1.0)
D["büyüme_kat"] = gk_tab.reindex(pd.MultiIndex.from_arrays([D.mekan, D.kategori])).fillna(1.0).to_numpy()
tp = D.talep52.clip(lower=0); tpp = D.talep52p.clip(lower=0)
D["büyüme_ürün"] = np.where(D.yeni_ürün, D.büyüme_kat, np.clip((tp + 5 * D.büyüme_kat) / (tpp + 5), 0.25, 2.0))
D["beklenen_12ay"] = tp * D.büyüme_ürün
with np.errstate(divide="ignore", invalid="ignore"):
    D["kapsama_yıl"] = np.where(D.beklenen_12ay > 0, D.stok / D.beklenen_12ay, np.inf)
D["stok_TL"] = D.stok * D.birim_maliyet
sg = pd.to_datetime(D.son_gercek, errors="coerce")
D["son_gerçek_hareket"] = sg.dt.strftime("%d.%m.%Y"); D["gerçek_hareketsiz_hafta"] = ((BUGUN - sg).dt.days // 7).astype("Int64")
D["hareketsiz_52h"] = sg.isna() | (sg < A)

# şirket geneli: toplam stok / toplam satış (depo sevkleri iç akış → çift sayılmaz)
sir = D.groupby("stk").agg(şirket_stok=("stok", "sum"), şirket_satış52=("satis52", "sum"))
D = D.join(sir, on="stk")
with np.errstate(divide="ignore", invalid="ignore"):
    D["şirket_kapsama_yıl"] = np.where(D.şirket_satış52 > 0, D.şirket_stok / D.şirket_satış52, np.inf)

supheli = D[(D.stok_TL > 5e6) | ((D.stok > 100_000) & (D.stok > 20 * np.maximum(D.talep52, 1)))]   # yalnız inanılmaz büyüklük; çok fazla ama gerçek stok LİSTEDE kalır
D = D[~D.index.isin(supheli.index)]

F = D[D.kapsama_yıl > 1].copy()
F["sınıf"] = np.where(~np.isfinite(F.kapsama_yıl), "satışsız (52h talep yok)", np.where(F.kapsama_yıl > 3, ">3 yıl", "1–3 yıl"))
F["fazla_adet"] = np.where(np.isfinite(F.kapsama_yıl), F.stok - F.beklenen_12ay, F.stok); F["fazla_TL"] = F.fazla_adet * F.birim_maliyet
F["transfer_adayı"] = np.where((F.mekan != "Merkez Depo") & (F.şirket_kapsama_yıl < 0.5), "evet (şirket geneli < 6 ay)", "")
HZ = D[D.hareketsiz_52h].copy()

os.makedirs(OUTD, exist_ok=True)
cols_f = ["mekan", "stk", "ürün", "grup", "kategori", "stok", "talep52p", "talep52", "büyüme_ürün", "beklenen_12ay", "kapsama_yıl", "sınıf",
          "fazla_adet", "fazla_TL", "son_gerçek_hareket", "giriş", "yeni_ürün", "şirket_kapsama_yıl", "transfer_adayı", "birim_maliyet", "maliyet_tahmini"]
cols_h = ["mekan", "stk", "ürün", "grup", "kategori", "stok", "stok_TL", "son_gerçek_hareket", "gerçek_hareketsiz_hafta", "son_hareket", "son_satis",
          "son_giris", "giriş", "birim_maliyet", "maliyet_tahmini"]
F.sort_values("fazla_TL", ascending=False)[cols_f].to_csv(f"{OUTD}/2026-10-14-fazla-stok-tum.csv", index=False, encoding="utf-8-sig")
HZ.sort_values("stok_TL", ascending=False)[cols_h].to_csv(f"{OUTD}/2026-10-14-hareketsiz-52h-tum.csv", index=False, encoding="utf-8-sig")
supheli.to_csv(f"{OUTD}/2026-10-14-stok-veri-suphesi.csv", index=False, encoding="utf-8-sig")

oz = pd.DataFrame({
    "stoklu ürün": D.groupby("mekan").size(), "stok TL": D.groupby("mekan").stok_TL.sum(),
    ">1 yıl ürün": F.groupby("mekan").size(), ">1 yıl stok TL": F.groupby("mekan").stok_TL.sum(), "1 yılı aşan kısım TL": F.groupby("mekan").fazla_TL.sum(),
    "52h hareketsiz ürün": HZ.groupby("mekan").size(), "52h hareketsiz TL": HZ.groupby("mekan").stok_TL.sum(),
    "transfer adayı ürün": F[F.transfer_adayı != ""].groupby("mekan").size()}).reindex(list(MEKAN.values())).fillna(0)
oz.loc["TOPLAM"] = oz.sum()
og = F.groupby(["mekan", "grup"]).fazla_TL.sum().unstack(0).reindex(columns=list(MEKAN.values())).fillna(0); og["toplam"] = og.sum(1); og = og.sort_values("toplam", ascending=False)
hz_yas = pd.cut(HZ.gerçek_hareketsiz_hafta.fillna(9999).astype(float), [51, 104, 156, 260, 1e9], labels=["1–2 yıl", "2–3 yıl", "3–5 yıl", "5+ yıl / hiç"])
oh = HZ.groupby([hz_yas, "mekan"], observed=False).stok_TL.sum().unstack(1).reindex(columns=list(MEKAN.values())).fillna(0)
pd.set_option("display.width", 220)
print(oz.round(0).to_string()); print(og.round(0).to_string()); print(oh.round(0).to_string())
print(f"veri şüphesi: {len(supheli)}"); print(supheli[["mekan", "stk", "ürün", "stok", "talep52", "birim_maliyet", "stok_TL"]].to_string(index=False))
print("kartsız (maliyetsiz) stoklu kod:", int(D.kartsız.sum()), "· maliyet tahmini:", int((D.maliyet_tahmini != "").sum()), "· adı bilinmeyen:", int((D.ürün == "?").sum()))

fmt = lambda v: "∞" if isinstance(v, float) and not np.isfinite(v) else (f"{v:,.1f}" if isinstance(v, float) and abs(v) < 100 else (f"{v:,.0f}" if isinstance(v, (float, int, np.integer)) and not isinstance(v, bool) else str(v)))
def tb(d, idx=True):
    head = ([d.index.name or ""] if idx else []) + list(d.columns)
    rows = "".join("<tr>" + (f"<td>{html.escape(str(i))}</td>" if idx else "") + "".join(f"<td>{html.escape(fmt(v))}</td>" for v in r) + "</tr>" for i, r in zip(d.index, d.itertuples(index=False)))
    return "<div style='overflow-x:auto'><table><tr>" + "".join(f"<th>{html.escape(str(c))}</th>" for c in head) + "</tr>" + rows + "</table></div>"
top_f = F.sort_values("fazla_TL", ascending=False)[["mekan", "ürün", "kategori", "stok", "talep52", "kapsama_yıl", "fazla_TL", "son_gerçek_hareket", "transfer_adayı"]].head(200)
top_h = HZ.sort_values("stok_TL", ascending=False)[["mekan", "ürün", "kategori", "stok", "stok_TL", "son_gerçek_hareket", "son_hareket", "son_satis"]].head(200)
open(f"{OUTD}/2026-10-14-fazla-hareketsiz-stok.html", "w", encoding="utf-8").write(f"""<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>Fazla ve hareketsiz stok</title>
<style>body{{font:13px system-ui;margin:16px;background:#fff;color:#111}}@media(prefers-color-scheme:dark){{body{{background:#161616;color:#eee}}}}
table{{border-collapse:collapse;margin-bottom:16px}}td,th{{border-bottom:1px solid #8884;padding:3px 7px;text-align:right;white-space:nowrap}}td:first-child,th:first-child{{text-align:left}}</style></head><body>
<h2>Fazla ve hareketsiz stok — 3 şube + Merkez Depo ({BUGUN:%d.%m.%Y})</h2>
<p><b>Stok:</b> stokSonAltDepo_vw (anlık; envanter dışı FifoDevreDisi kodları hariç). Not: bkm.OneriSiparis yalnız öneri satırı olan ürünleri taşır — FSM'de 125.7 bin
ürüne karşı görünümde 176 bin; bu rapor görünümü esas alır (14.10 sabahki FSM raporunun yerine geçer). <b>Talep:</b> son 52 hafta satış − iade; Merkez Depo'da + şubelere/depolara sevk. <b>Büyüme:</b> ürünün son 52h / önceki 52h talebi,
kategori büyümesine büzülmüş. <b>Fazla:</b> stok > beklenen 12 ay talep. <b>Hareketsiz:</b> 52 haftadır GERÇEK hareket yok — defter düzeltmeleri ({GERCEK_DISI}) hareket sayılmadı
(Aralık 2025 negatif defter temizliği 88/89 ile yapıldı; sayılsaydı ölü ürünler canlı görünürdü). <b>Transfer adayı:</b> bu mekanda fazla, ama şirket geneli kapsaması 6 aydan kısa.
<b>Maliyet:</b> son alış; yoksa fiyat×0,6. Model kullanılmadı.</p>
<p><b>Bilinmeyenler:</b> iade edilebilirlik (yayınevi) · sayım farkı (kayıtta var, rafta yok olabilir) · yoldaki mal. Veri şüphesi {len(supheli)} kayıt toplamlara girmedi (ayrı CSV).</p>
<h3>Özet</h3>{tb(oz.round(0))}<h3>1 yılı aşan kısım (TL) — grup × mekan</h3>{tb(og.round(0))}<h3>Hareketsiz stok (TL) — hareketsizlik süresi × mekan</h3>{tb(oh.round(0))}
<h3>En çok fazla TL bağlayan 200 kalem</h3>{tb(top_f, False)}<h3>En çok TL bağlayan 200 hareketsiz kalem</h3>{tb(top_h, False)}
<p>Tam listeler (Excel): 2026-10-14-fazla-stok-tum.csv · 2026-10-14-hareketsiz-52h-tum.csv · 2026-10-14-stok-veri-suphesi.csv</p></body></html>""")
print("→", f"{OUTD}/2026-10-14-fazla-hareketsiz-stok.html")


# ═══════════════════════ Excel (sahip: "düzgün bir excel ver") ═══════════════════════
def excel(path):
    import xlsxwriter
    wb = xlsxwriter.Workbook(path, {"constant_memory": True, "nan_inf_to_errors": True})
    H = wb.add_format({"bold": True, "bg_color": "#1F4E78", "font_color": "#FFFFFF", "text_wrap": True, "valign": "top", "border": 1})
    TL = wb.add_format({"num_format": "#,##0"}); AD = wb.add_format({"num_format": "#,##0"}); D1 = wb.add_format({"num_format": "0.0"})
    TXT = wb.add_format({}); B = wb.add_format({"bold": True}); W = wb.add_format({"text_wrap": True, "valign": "top"})
    T1 = wb.add_format({"bold": True, "font_size": 14}); TLB = wb.add_format({"num_format": "#,##0", "bold": True})

    def sheet(name, df, spec):
        """spec: [(sütun, başlık, genişlik, biçim)]"""
        ws = wb.add_worksheet(name[:31]); ws.freeze_panes(1, 0); ws.set_row(0, 32)
        for j, (c, h, w, f) in enumerate(spec):
            ws.write(0, j, h, H); ws.set_column(j, j, w)
        vals = [df[c].to_numpy() for c, *_ in spec]
        for i in range(len(df)):
            for j, (c, h, w, f) in enumerate(spec):
                v = vals[j][i]
                if v is None or (isinstance(v, float) and np.isnan(v)) or v is pd.NA: continue
                if isinstance(v, (float, np.floating)) and not np.isfinite(v): ws.write_string(i + 1, j, "satış yok"); continue
                if isinstance(v, (bool, np.bool_)): ws.write_string(i + 1, j, "evet" if v else ""); continue
                if isinstance(v, (int, float, np.integer, np.floating)): ws.write_number(i + 1, j, float(v), f)
                else: ws.write_string(i + 1, j, str(v))
        ws.autofilter(0, 0, len(df), len(spec) - 1)
        return ws

    # 1) Özet
    ws = wb.add_worksheet("Özet"); ws.set_column(0, 0, 26); ws.set_column(1, 9, 16)
    ws.write(0, 0, f"Fazla ve hareketsiz stok — {BUGUN:%d.%m.%Y}", T1)
    ws.write(1, 0, "Tutarlar maliyet (son alış) üzerinden, TL. Tanımlar 'Açıklama' sayfasında.")
    r = 3
    ws.write_row(r, 0, ["Mekan"] + list(oz.columns), H); ws.set_row(r, 45)
    for i, (mk, row) in enumerate(oz.iterrows()):
        fmt_ = TLB if mk == "TOPLAM" else TL
        ws.write(r + 1 + i, 0, mk, B if mk == "TOPLAM" else TXT)
        for j, v in enumerate(row): ws.write_number(r + 1 + i, 1 + j, float(v), fmt_)
    r += len(oz) + 3
    ws.write(r - 1, 0, "1 yılı aşan kısım (TL) — grup × mekan", B)
    ws.write_row(r, 0, ["Grup"] + list(og.columns), H)
    for i, (g, row) in enumerate(og.iterrows()):
        ws.write(r + 1 + i, 0, str(g))
        for j, v in enumerate(row): ws.write_number(r + 1 + i, 1 + j, float(v), TL)
    r += len(og) + 3
    ws.write(r - 1, 0, "52 hafta hareketsiz stok (TL) — hareketsizlik süresi × mekan", B)
    ws.write_row(r, 0, ["Süre"] + list(oh.columns), H)
    for i, (g, row) in enumerate(oh.iterrows()):
        ws.write(r + 1 + i, 0, str(g))
        for j, v in enumerate(row): ws.write_number(r + 1 + i, 1 + j, float(v), TL)

    fz = [("stk", "Ürün kodu", 10, AD), ("ürün", "Ürün adı", 48, TXT), ("grup", "Grup", 18, TXT), ("kategori", "Kategori", 26, TXT),
          ("stok", "Stok (adet)", 10, AD), ("talep52p", "Önceki 52 hafta talep", 12, AD), ("talep52", "Son 52 hafta talep", 12, AD),
          ("büyüme_ürün", "Büyüme çarpanı", 10, D1), ("beklenen_12ay", "Beklenen 12 ay talep", 12, AD), ("kapsama_yıl", "Kapsama (yıl)", 10, D1),
          ("sınıf", "Sınıf", 20, TXT), ("fazla_adet", "1 yılı aşan adet", 12, AD), ("fazla_TL", "1 yılı aşan tutar (TL)", 14, TL),
          ("birim_maliyet", "Birim maliyet (TL)", 12, TL), ("maliyet_tahmini", "Maliyet tahmini mi", 12, TXT),
          ("son_gerçek_hareket", "Son gerçek hareket", 12, TXT), ("giriş", "Ürün giriş tarihi", 12, TXT), ("yeni_ürün", "Yeni ürün (<52h)", 10, TXT),
          ("şirket_kapsama_yıl", "Şirket geneli kapsama (yıl)", 12, D1), ("transfer_adayı", "Transfer adayı", 22, TXT)]
    for mk in MEKAN.values():
        sheet(f"Fazla - {mk}", F[F.mekan == mk].sort_values("fazla_TL", ascending=False), fz)
    sheet("Transfer adayları", F[F.transfer_adayı != ""].sort_values("fazla_TL", ascending=False), [("mekan", "Mekan", 12, TXT)] + fz)
    hz = [("mekan", "Mekan", 12, TXT), ("stk", "Ürün kodu", 10, AD), ("ürün", "Ürün adı", 48, TXT), ("grup", "Grup", 18, TXT), ("kategori", "Kategori", 26, TXT),
          ("stok", "Stok (adet)", 10, AD), ("stok_TL", "Stok tutarı (TL)", 14, TL), ("birim_maliyet", "Birim maliyet (TL)", 12, TL),
          ("son_gerçek_hareket", "Son gerçek hareket", 12, TXT), ("gerçek_hareketsiz_hafta", "Kaç haftadır hareketsiz", 12, AD),
          ("son_hareket", "Son hareket (defter dahil)", 12, TXT), ("son_satis", "Son satış", 12, TXT), ("son_giris", "Son giriş", 12, TXT),
          ("giriş", "Ürün giriş tarihi", 12, TXT), ("maliyet_tahmini", "Maliyet tahmini mi", 12, TXT)]
    sheet("Hareketsiz 52 hafta", HZ.sort_values("stok_TL", ascending=False), hz)
    sheet("Veri şüphesi", supheli.assign(neden="tutar > 5M TL ya da adet > 100.000 ve talebin 20 katı"),
          [("mekan", "Mekan", 12, TXT), ("stk", "Ürün kodu", 10, AD), ("ürün", "Ürün adı", 48, TXT), ("stok", "Stok", 12, AD),
           ("talep52", "Son 52 hafta talep", 12, AD), ("birim_maliyet", "Birim maliyet", 12, TL), ("stok_TL", "Tutar", 14, TL), ("neden", "Neden", 40, TXT)])
    ws = wb.add_worksheet("Açıklama"); ws.set_column(0, 0, 28); ws.set_column(1, 1, 110)
    rows = [("Kaynak", "DerinSIS: stokSonAltDepo_vw (anlık stok), irsHrk (hareketler), bkm.UrunBilgi (kart, son alış). Salt okuma. Model kullanılmadı."),
            ("Mekanlar", "FSM = 1 · Özlüce = 4477 · İst.Yolu = 4478 · Merkez Depo = 12. Transit depolar hariç. Envanter dışı kodlar (poşet, hediye çeki …) hariç."),
            ("Talep", "Son 52 hafta satış − iade (Satış, Mağaza Satış, POS Satış − iadeleri). Merkez Depo'da ayrıca şubelere/depolara sevk (Depo Mağaza, Depo Depo)."),
            ("Büyüme", "Ürünün son 52 hafta talebi / önceki 52 hafta; az satan üründe kategori büyümesine yaklaştırılır (5 adet ağırlık), 0,25–2 arası sınırlı. Yeni ürün: kategori büyümesi."),
            ("Kapsama", "Stok ÷ beklenen 12 ay talep. 1'den büyükse stok bir yıldan uzun yeter. 'satış yok' = son 52 haftada hiç talep yok."),
            ("1 yılı aşan kısım", "Stok − beklenen 12 ay talep (adet ve son alış maliyetiyle TL). Elden çıkarılması/iadesi düşünülebilecek miktar."),
            ("Hareketsiz", "Son 52 haftada hiç GERÇEK hareketi olmayan stok. Defter düzeltmeleri hareket sayılmaz: Stok EKLE, Merkezi Düzeltme, Diğer Giriş/Çıkış, Ürün SAY, Devir, Sayım. (Aralık 2025 negatif defter temizliği Diğer Giriş/Çıkış ile yapıldı.)"),
            ("Transfer adayı", "Bu şubede fazla ama ürünün şirket geneli kapsaması 6 aydan kısa → başka şubeye kaydırma satın almanın yerine geçebilir."),
            ("Maliyet", "Son alış; yoksa satış fiyatı × 0,6 ('Maliyet tahmini mi' = fiyat×0.6)."),
            ("Bilinmeyenler", "Yayınevine iade edilebilirlik · sayım farkı (kayıtta var, rafta yok olabilir) · yoldaki mal."),
            ("Uyarı", "bkm.OneriSiparis tablosunda stk 1609276 için 14,6 milyon adet stok görünüyor; anlık stok 5 adet. Sipariş prosedürünü besleyen tabloda veri hatası — kontrol edilmeli.")]
    for i, (k, v) in enumerate(rows): ws.write(i, 0, k, B); ws.write(i, 1, v, W)
    wb.close()


excel(f"{OUTD}/2026-10-14-fazla-hareketsiz-stok.xlsx")
print("→", f"{OUTD}/2026-10-14-fazla-hareketsiz-stok.xlsx")
