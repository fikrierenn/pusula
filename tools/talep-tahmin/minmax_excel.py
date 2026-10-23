"""
Bugünkü Min/Max + sipariş listesi — mağaza başına FORMÜLLÜ Excel (ön-kayıt 6/7/8 sonucu: v2 + A2 sezon katmanı). OneriSiparis KULLANILMAZ.
Python yalnız GİRDİLERİ üretir (mavi): stok (stokSonAltDepo_vw), haftalık tahmin (v4, yalnız 11.10.2026'ya kadarki veri), sezon oranı (A2),
26 hafta satış oynaklığı, fiyat/maliyet, ODAK durumu, önemli yazar/yayınevi. Min, Max, stoklama kararı, raf kuralı, sipariş = Excel formülü (siyah),
'Ayarlar' sayfasındaki sarı hücrelere bağlı. Python ikizi aynı hesabı yapar → excel_dogrula.ps1 + karşılaştırma ile doğrulanır.
Kullanım: python minmax_excel.py <çıktı_dizini> [1 4477 4478]
"""
import datetime as dt
import os
import sys

import numpy as np
import pandas as pd
import xlsxwriter
from scipy.stats import norm

import evaluate as E
import events as EV
import forecast as F
import models as M

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
C_ = os.path.join(ROOT, ".cache"); ORT = os.path.join(C_, "talep-tahmin-ortak")
OUTD = sys.argv[1]; SECIM = [int(x) for x in sys.argv[2:]] or [1, 4477, 4478]
DIR = {1: "talep-tahmin", 4477: "talep-tahmin-4477", 4478: "talep-tahmin-4478"}; AD = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu"}
BUGUN = dt.date(2026, 10, 14)
SINAV = ["Eğitim - Sınavlara Hazırlık - Okula Yardımcı", "Sınavlara Hazırlık Kitapları", "Eğitim ve Okula Yardımcı Kitaplar"]
GRUPLAR = ["Kitap-Genel", "Kitap-Hazırlık", "Kırtasiye / Hediyelik", "Oyuncak / Elektronik", "Diğer"]
SL0 = {"Kitap-Genel": 0.95, "Kitap-Hazırlık": 0.97, "Kırtasiye / Hediyelik": 0.97, "Oyuncak / Elektronik": 0.95, "Diğer": 0.97}
# Ayarlar: (satır, ad, değer, açıklama)
AYAR = [(3, "Koruma süresi (gün)", 4, "Günlük sipariş (1 gün) + depodan teslim 2 iş günü ≈ 4 takvim günü. Min bu kadar günlük satışı + güvenlik payını karşılar."),
        (4, "Sipariş satırı maliyeti (TL)", 10, "Bir ürünü bir kez sipariş etmenin maliyeti (toplama, sevk, kabul). Max'taki ekonomik sipariş miktarını belirler. KALİBRE DEĞİL."),
        (5, "Yıllık elde tutma oranı", 0.40, "Stokta bekleyen malın yıllık maliyeti / alış maliyeti (sermaye + alan + eskime). KALİBRE DEĞİL."),
        (6, "Raf kuralı açık mı (1/0)", 1, "1 = ODAK'ta var/temin ediliyor + önemli yazar/yayınevi olan kitap stoklanmasa bile rafta 1 adet (Min 0 / Max 1)."),
        (7, "Max gün tavanı (0 = kapalı)", 0, "0'dan büyükse Max, bu kadar günlük satışı aşamaz. Benzetimde tavansız daha iyiydi; varsayılan kapalı."),
        (9, "Hizmet seviyesi — Kitap-Genel", SL0["Kitap-Genel"], "Rafta bulunma olasılığı hedefi. Kâr hesabında en iyi: %95."),
        (10, "Hizmet seviyesi — Kitap-Hazırlık", SL0["Kitap-Hazırlık"], "Kâr hesabında en iyi: %97."),
        (11, "Hizmet seviyesi — Kırtasiye / Hediyelik", SL0["Kırtasiye / Hediyelik"], "Kâr hesabında en iyi: %97."),
        (12, "Hizmet seviyesi — Oyuncak / Elektronik", SL0["Oyuncak / Elektronik"], "Kâr hesabında en iyi: %95."),
        (13, "Hizmet seviyesi — Diğer", SL0["Diğer"], "Kâr hesabında en iyi: %97."),
        (15, "Stoğu 0 olan üründe yeniden stoklama: en az satış (son 26 hafta)", 2,
         "Stoğu (yoldaki dahil) 0 olan ürün, son 26 haftada bu kadar satmadıysa sipariş edilmez (raf kuralındaki kitaplar hariç). Sahip kararı 14.10.2026; benzetimde SINANMADI."),
        (17, "Onay eşiği — kitap dışı (sipariş sonrası gün)", 60, "Sipariş sonrası stok bu kadar günden uzun yetecekse satır 'Onaya düşer' (otomatik geçmez). Danışman önerisi; kalibre değil."),
        (18, "Onay eşiği — kitap (sipariş sonrası gün)", 90, "Kitap için aynı eşik."),
        (19, "Onay için en az sipariş tutarı (TL)", 1000,
         "Uzun yetecek satır ancak tutarı bu kadar ya da fazlaysa onaya düşer (maliyeti tahmini satır HER ZAMAN düşer). Ölçüldü 15.10: 1.000 TL'de ilk gün mağaza başına ~1.000–1.200 satır, uzun yetecek tutarın ~%40'ı.")]
A_ = {r: v for r, _, v, _ in AYAR}; SLROW = {g: 9 + i for i, g in enumerate(GRUPLAR)}

odak = pd.read_csv(f"{ORT}/odak.csv").drop_duplicates("stk").set_index("stk")
YER_TUTUCU = {8015, 22894, 54435, 54441, 106869}
_ya = pd.read_csv(f"{ORT}/yazar-onem.csv"); ONEMLI_YAZAR = set(_ya[_ya["onemli_%80"]].yazar.astype(int)) - YER_TUTUCU
_yv = pd.read_csv(f"{ORT}/yayinevi-onem.csv"); ONEMLI_YAYINEVI = set(_yv[_yv["onemli_%80"]].yayinevi.astype(int))
adlar = pd.concat([pd.read_csv(f"{ORT}/adlar-ek.csv"), pd.read_csv(f"{C_}/talep-tahmin/adlar.csv")]).drop_duplicates("stk").set_index("stk")["ad"]
# 2026-10-15 danışman bulguları (doğrulandı): mal-olmayan kodlar, Sınav markaları (kurumsal), birim maliyet için 12 ay alış medyanı
MAL_DEGIL = set(pd.read_csv(f"{ORT}/mal-olmayan.csv").stk.astype(int))
SINAV_MRK = {2100, 2101, 3904, 3905, 3906, 4641, 5298, 5972, 5973, 5974}
MED12 = pd.read_csv(f"{ORT}/alis-medyan12.csv").set_index("stk")["medyan12"]
KDV = pd.read_csv(f"{ORT}/kdv.csv").drop_duplicates("stk").set_index("stk")["kdv"]                 # kart fiyatı KDV dahil (ölçüldü)
_set = pd.read_csv(f"{ORT}/setler.csv"); DONUSUM = set(_set[_set.alis_24ay == 0].stk.astype(int))   # set/paket bölme — Dönüşüm (95) ile giriyor, alış yok
EVL = sorted([(e["olay"], e["w"]) for e in EV.events()], key=lambda x: x[1]); KMIN, KMAX = -8, 4
B_KIR = (dt.date(2024, 8, 5) - EV.D0).days // 7


def panel(mk):
    O = os.path.join(C_, DIR[mk])
    P = F.load_panel(f"{O}/weekly.csv", f"{O}/toplu.csv", f"{O}/devredisi.csv")
    ub = pd.read_csv(f"{O}/urunbilgi.csv").drop_duplicates("stk").set_index("stk")
    kat = ub["katana"].reindex(P.stk).fillna("Bilinmiyor").to_numpy()
    return P, ub, kat


def profiller(Cm, t, flt=lambda w: True):
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


def sezon_orani(mk, Y, C, cats, t):
    """A2 (ön-kayıt 7): kategori olay profili; oran = U(t) / ort U[t−13, t) — yalnız t öncesi veri. Hedef haftası profil dışındaysa 1."""
    Wx = t + 1; ks = np.arange(KMIN, KMAX + 1); prof = profiller(C, t)
    sj = np.array([j for j, nm in enumerate(cats) if nm in SINAV], int)
    if mk in (1, 4478) and t > B_KIR and len(sj):
        Pr, _, kr = panel(4477); Cr, _ = M.category_totals(Pr.Y, kr); crl = list(np.unique(kr)); Cref = np.zeros_like(C)
        for j, nm in enumerate(cats):
            if nm in crl: Cref[j, :min(C.shape[1], Cr.shape[1])] = Cr[crl.index(nm), :min(C.shape[1], Cr.shape[1])]
        post = profiller(C, t, lambda w: w + KMIN >= B_KIR); ref = profiller(Cref, t)
        for o in prof:
            src = post.get(o, ref.get(o)); prof[o][sj] = src[sj] if src is not None else 1.0
    U = np.ones((C.shape[0], Wx + 1)); best = np.full(Wx + 1, 99)
    for o, we in EVL:
        if o not in prof: continue
        for j, k in enumerate(ks):
            w = we + k
            if 0 <= w <= Wx and abs(k) < best[w]: best[w] = abs(k); U[:, w] = prof[o][:, j]
    return np.maximum(1.0, U[:, t] / U[:, t - 13:t].mean(1))


def hazirla(mk):
    P, ub, kat = panel(mk); Y, first, W = P.Y, P.first, P.Y.shape[1]; t = W                         # t = bugünkü hafta (veri 11.10'a kadar)
    kc = np.unique(kat, return_inverse=True)[1]; C, ci = M.category_totals(Y, kat); cats = list(np.unique(kat))
    fiyat = np.nan_to_num(ub["fiyat"].reindex(P.stk).to_numpy(float))
    gm = M.GlobalModel(Y, first, ci, C, fiyat, kc.astype(np.float32), use_price=False); gm.fit(t)
    stok_g = pd.read_csv(f"{ORT}/fazla-{mk}.csv").drop_duplicates("stk").set_index("stk").stok
    _yv = ub["yayinevi"].reindex(P.stk).to_numpy()
    kurumsal = pd.Series(kat).str.startswith("Sınav Okul").to_numpy() | np.isin(_yv, list(SINAV_MRK)) | np.isin(P.stk, list(MAL_DEGIL)) | np.isin(P.stk, list(DONUSUM))
    aktif = (Y[:, t - 26:t].sum(1) > 0) | pd.Series(P.stk).isin(stok_g[stok_g > 0].index).to_numpy()
    idx = np.nonzero(aktif & ~kurumsal)[0]
    g = gm.predict(t, idx); s5 = E.ses(Y[idx], t, first[idx], 0.5)
    past52 = Y[:, t - 52:t].sum(1); pop = Y[:, t - 13:t].sum(1) > 0
    order = np.argsort(-np.where(pop, past52, -1)); rank = np.empty(len(Y), int); rank[order] = np.arange(len(Y))
    mu_h = np.maximum(np.where(rank[idx] < 1000, np.sqrt(np.maximum(g, 0) * np.maximum(s5, 0)), g) / 4.0, 0)
    oran = sezon_orani(mk, Y, C, cats, t)[ci[idx]]
    stk = P.stk[idx]; u = ub.reindex(stk)
    k2 = u["kat2"].fillna("").to_numpy(); ka = kat[idx]
    kitap_mi = (k2 == "Kitap") | (np.isin(k2, ["Tanımsız", "Genel", ""]) & pd.Series(ka).str.contains("Kitap|Okula Yardımcı|Sınavlara Hazırlık|Periyodik", regex=True).to_numpy())  # ön-kayıt 11
    grup = np.where(kitap_mi, np.where(np.isin(ka, SINAV), "Kitap-Hazırlık", "Kitap-Genel"),
                    np.where(np.isin(k2, ["Kırtasiye / Hediyelik", "Oyuncak / Elektronik"]), k2, "Diğer"))
    od = odak.reindex(stk)
    yz = u["yazar"].fillna(0).astype(int).to_numpy(); yy = u["yayinevi"].fillna(0).astype(int).to_numpy()
    d = pd.DataFrame({"stk": stk, "ürün": [adlar.get(s, "(adı bulunamadı)") for s in stk], "grup": grup, "kategori": ka,
                      "stok": stok_g.reindex(stk).fillna(0).clip(lower=0).to_numpy(), "yolda": 0.0,
                      "tahmin_h": mu_h, "sezon": oran, "sd_h": Y[idx, t - 26:t].std(1), "s26": Y[idx, t - 26:t].sum(1),
                      "fiyat": fiyat[idx], "sonalis_kart": u["sonalis"].to_numpy(float), "med12": MED12.reindex(stk).to_numpy(float), "kdv": KDV.reindex(stk).fillna(0).to_numpy(float),
                      "odak_stok": od.odak_stok.fillna(0).to_numpy(), "odak_durum": od.odak_durum.fillna(0).to_numpy(),
                      "temin_gun": od.odak_temin_gun.to_numpy(),
                      "onemli": np.where(np.isin(yz, list(ONEMLI_YAZAR)) | np.isin(yy, list(ONEMLI_YAYINEVI)), "Evet", "Hayır")})
    # ── Python ikizi (Excel formülleriyle birebir) ──
    _k = np.nan_to_num(d.sonalis_kart); _m = np.nan_to_num(d.med12)
    d["sonalis"] = np.where(_k > 0.05, np.where((_m > 0) & (_k > 3 * _m), _m, _k), 0.0)                  # L ikizi (v4: medyan YALNIZ yukarı hatada)
    pnet = d.fiyat / (1 + d.kdv / 100)
    d["maliyet"] = np.where(d.sonalis > 0, np.where(d.sonalis > 1.5 * pnet, pnet * 0.6, d.sonalis), pnet * 0.6)   # Q ikizi
    d["kaynak"] = np.where(_k <= 0.05, "Tahmin (net fiyat×0,6)", np.where((_m > 0) & (_k > 3 * _m), "12 ay alış medyanı (kart sapıyor)",
                           np.where(d.sonalis > 1.5 * pnet, "Birim şüphesi → tahmin", "Kart son alış")))
    d["mu_g"] = d.tahmin_h * d.sezon / 7; d["sd_g"] = d.sd_h / np.sqrt(7)
    d["SL"] = d.grup.map(SL0); z = norm.ppf(d.SL)
    d["psat"] = 1 - np.exp(-52 * d.tahmin_h * d.sezon)
    d["stokla"] = np.where((pnet > d.maliyet) & (52 * d.tahmin_h * d.sezon * (pnet - d.maliyet) >= d.maliyet * A_[5]) & ((d.tahmin_h > 0) | (d.sd_h > 0)), "Evet", "Hayır")   # v4
    d["raf"] = np.where((A_[6] == 1) & (d.grup.str.startswith("Kitap")) & ((d.odak_stok > 0) | (d.odak_durum == 1)) & (d.onemli == "Evet"), "Evet", "Hayır")
    mn = np.floor(d.mu_g * A_[3] + z * d.sd_g * np.sqrt(A_[3]) + 0.5).clip(lower=0)
    eoq = np.where(d.maliyet > 0, np.sqrt(2 * 52 * d.tahmin_h * d.sezon * A_[4] / (d.maliyet * A_[5]).where(d.maliyet > 0, 1)), 0)
    mx = mn + np.maximum(1, np.ceil(eoq))
    d["Min"] = np.where(d.stokla == "Evet", mn, 0)
    d["Max"] = np.where(d.stokla == "Evet", mx, np.where(d.raf == "Evet", 1, 0))
    d["siparis"] = np.where(d.stok + d.yolda <= d.Min, np.maximum(0, d.Max - d.stok - d.yolda), 0)
    d.loc[(d.stok + d.yolda <= 0) & (d.s26 < A_[15]) & (d.raf != "Evet"), "siparis"] = 0          # sahip eşiği (yeniden stoklama)
    d.loc[(d.stokla == "Hayır") & (d.raf == "Hayır"), "siparis"] = 0
    d["siparis_TL"] = d.siparis * d.maliyet
    with np.errstate(divide="ignore", invalid="ignore"):
        d["min_gun"] = np.where(d.mu_g > 0, d.Min / d.mu_g, np.nan); d["max_gun"] = np.where(d.mu_g > 0, d.Max / d.mu_g, np.nan)
        d["gun_sonra"] = np.where(d.mu_g > 0, (d.stok + d.yolda + d.siparis) / d.mu_g, np.nan)
    esik = np.where(d.grup.str.startswith("Kitap"), A_[18], A_[17])
    d["onay"] = np.where((d.siparis > 0) & ((d.kaynak != "Kart son alış") | ((np.nan_to_num(d.gun_sonra, nan=0) > esik) & (d.siparis_TL >= A_[19]))), "Evet", "")
    d = d.sort_values(["siparis_TL", "s26"], ascending=False).reset_index(drop=True)
    return d


# Ürünler sütunları: (başlık, genişlik, tür, kaynak/formül, açıklama)
U = "Ürünler"
COLS = [("Ürün kodu", 10, "in", "stk", ""), ("Ürün adı", 44, "in", "ürün", ""), ("Grup", 18, "in", "grup", "Hizmet seviyesi bu gruba göre (Ayarlar)."),
        ("Kategori", 24, "in", "kategori", ""), ("Stok (adet)", 9, "in", "stok", "Bugünkü stok (stokSonAltDepo_vw)."),
        ("Yolda (adet)", 9, "in", "yolda", "Depodan çıkmış, henüz girmemiş. VERİ YOK → 0. Biliniyorsa elle girin; sipariş buna göre azalır."),
        ("Haftalık tahmin (adet)", 11, "in", "tahmin_h", "v4 talep tahmini (yalnız 11.10.2026'ya kadarki satış). 4478 testinden sonra kalan doğrulanmış yöntem."),
        ("Sezon çarpanı", 9, "in", "sezon", "A2: kategorinin olay-hizalı sezon eğrisi; bu hafta / son 13 hafta ortalaması, en az 1. Üç ayrı dönemde doğrulandı."),
        ("Satış oynaklığı (haftalık std)", 11, "in", "sd_h", "Son 26 haftanın haftalık satış standart sapması."),
        ("Son 26 hafta satış", 10, "in", "s26", "Perakende satış − iade, haftalık; iadenin satıştan fazla olduğu hafta 0 sayılır (talep eksi olamaz)."), ("Satış fiyatı (TL)", 10, "in", "fiyat", ""), ("Kullanılan alış maliyeti (TL)", 10, "f", "=IF(N(AD{r})>0.05,IF(AND(N(AE{r})>0,AD{r}>3*AE{r}),AE{r},AD{r}),0)",
         "Kart son alışı (AD); kart, son 12 ay alış medyanının (AE) 3 katından YÜKSEKSE medyan (tek koli fiyatlı satır kartı bozabiliyor). Kart 0,05 TL altı = yok. Medyan aşağı düzeltmede kullanılmaz (kitap alış satırları iskontosuz liste fiyatı)."),
        ("ODAK stok", 8, "in", "odak_stok", "ODAK e-ticaret deposu stoğu."), ("ODAK durumu", 8, "in", "odak_durum", "1 Satışta (temin ediliyor) · 2 Tükendi · 3 Yeni baskı · 4 Liste dışı · 5 Yasaklı · 6 Eski baskı · 0 ODAK'ta yok."),
        ("ODAK temin süresi (gün)", 9, "in", "temin_gun", ""), ("Önemli yazar/yayınevi", 9, "in", "onemli", "Yazar ya da yayınevi, şirket kitap satışının ilk %80'inde."),
        ("Birim maliyet (TL)", 10, "f", "=IF(N(L{r})>0,IF(L{r}>1.5*K{r}/(1+AF{r}/100),K{r}/(1+AF{r}/100)*0.6,L{r}),K{r}/(1+AF{r}/100)*0.6)",
         "Alış maliyeti; yoksa ya da KDV hariç net fiyatın 1,5 katından büyükse (birim şüphesi) net fiyat × 0,6. Kaynağı AG sütununda."),
        ("Günlük beklenen satış", 10, "f", "=G{r}*H{r}/7", "Haftalık tahmin × sezon çarpanı ÷ 7."),
        ("Hizmet seviyesi", 8, "f", "=INDEX(Ayarlar!$C$9:$C$13,MATCH(C{r},Ayarlar!$B$9:$B$13,0))", "Grubun hedefi (Ayarlar)."),
        ("Bir yılda satılma olasılığı", 9, "f", "=1-EXP(-52*G{r}*H{r})", "Poisson: yıl içinde en az 1 adet satılma olasılığı."),
        ("Stoklamaya değer mi", 9, "f", '=IF(K{r}/(1+AF{r}/100)>Q{r},IF(AND(52*G{r}*H{r}*(K{r}/(1+AF{r}/100)-Q{r})>=Q{r}*Ayarlar!$C$5,OR(G{r}>0,I{r}>0)),"Evet","Hayır"),"Hayır")',
         "Yıllık beklenen satış × birim net kâr (KDV hariç) ≥ maliyet × elde tutma oranı ise Evet. Rafta bekleme süresi hesaba katılır: çok satan üründe bir adet günlerce bekler. Hayır ise talep gelince ODAK'tan."),
        ("Raf kuralı", 8, "f", '=IF(AND(Ayarlar!$C$6=1,LEFT(C{r},5)="Kitap",OR(M{r}>0,N{r}=1),P{r}="Evet"),"Evet","Hayır")', "Kitap + ODAK'ta var/temin ediliyor + önemli yazar/yayınevi → rafta 1 adet."),
        ("Min", 7, "f", '=IF(U{r}="Evet",MAX(0,ROUND(R{r}*Ayarlar!$C$3+NORMSINV(S{r})*I{r}/SQRT(7)*SQRT(Ayarlar!$C$3),0)),0)',
         "Koruma süresince beklenen satış + güvenlik payı (hizmet seviyesine göre)."),
        ("Ekonomik sipariş miktarı", 9, "f", "=IF(Q{r}>0,SQRT(2*52*G{r}*H{r}*Ayarlar!$C$4/(Q{r}*Ayarlar!$C$5)),0)", "√(2 × yıllık satış × sipariş maliyeti ÷ (maliyet × elde tutma oranı))."),
        ("Max", 7, "f", '=IF(U{r}="Evet",IF(Ayarlar!$C$7>0,MIN(W{r}+MAX(1,ROUNDUP(X{r},0)),MAX(W{r}+1,ROUNDUP(R{r}*Ayarlar!$C$7,0))),W{r}+MAX(1,ROUNDUP(X{r},0))),IF(V{r}="Evet",1,0))',
         "Min + ekonomik sipariş miktarı (en az 1). Stoklanmayan ama raf kuralındaki kitapta 1."),
        ("Sipariş (adet)", 9, "f", '=IF(OR(U{r}="Evet",V{r}="Evet"),IF(E{r}+F{r}<=W{r},IF(AND(E{r}+F{r}<=0,J{r}<Ayarlar!$C$15,V{r}<>"Evet"),0,MAX(0,Y{r}-E{r}-F{r})),0),0)',
         "Stok + yolda ≤ Min ise Max'a tamamla. Stoğu 0 olan ürün son 26 haftada Ayarlar C15'ten az sattıysa sipariş yok (raf kuralı hariç)."),
        ("Sipariş tutarı (TL)", 11, "f", "=Z{r}*Q{r}", ""),
        ("Min kaç günlük", 8, "f", '=IF(R{r}>0,W{r}/R{r},"")', "Min, kaç günlük satışa denk."),
        ("Max kaç günlük", 8, "f", '=IF(R{r}>0,Y{r}/R{r},"")', "Max, kaç günlük satışa denk."),
        ("Kart son alış (TL)", 10, "in", "sonalis_kart", "Ürün kartındaki son alış (ham)."),
        ("Son 12 ay alış medyanı (TL)", 10, "in", "med12", "Son 12 ayın alış satırlarının birim fiyat medyanı (kitapta iskontosuz liste fiyatı olabilir). Boş = son 12 ayda alış yok."),
        ("Satış KDV %", 7, "in", "kdv", "Ürün kartındaki satış KDV oranı. Satış fiyatı KDV DAHİL; kâr hesabında KDV hariç net fiyat kullanılır."),
        ("Maliyet kaynağı", 22, "f", '=IF(N(AD{r})<=0.05,"Tahmin (net fiyat×0,6)",IF(AND(N(AE{r})>0,AD{r}>3*AE{r}),"12 ay alış medyanı (kart sapıyor)",IF(L{r}>1.5*K{r}/(1+AF{r}/100),"Birim şüphesi → tahmin","Kart son alış")))',
         "Birim maliyetin nereden geldiği. 'Kart son alış' dışındakiler tahmin/düzeltme — sipariş onaya düşer."),
        ("Sipariş sonrası kaç gün yeter", 9, "f", '=IF(R{r}>0,(E{r}+F{r}+Z{r})/R{r},"")', "(Stok + yolda + sipariş) ÷ günlük beklenen satış."),
        ("Onaya düşer", 8, "f", '=IF(Z{r}>0,IF(OR(AG{r}<>"Kart son alış",AND(ISNUMBER(AH{r}),AH{r}>IF(LEFT(C{r},5)="Kitap",Ayarlar!$C$18,Ayarlar!$C$17),AA{r}>=Ayarlar!$C$19)),"Evet",""),"")',
         "Sipariş var VE (maliyet tahmini/şüpheli YA DA (sipariş sonrası stok Ayarlar C17/C18 günden uzun yetiyor VE tutar ≥ Ayarlar C19)) → otomatik geçmez, insan onayı.")]
PYV = ["sonalis", "maliyet", "mu_g", "SL", "psat", "stokla", "raf", "Min", None, "Max", "siparis", "siparis_TL", "min_gun", "max_gun", "kaynak", "gun_sonra", "onay"]


def kitap(mk, d, path):
    n = len(d); last = n + 1; mad = AD[mk]
    wb = xlsxwriter.Workbook(path, {"constant_memory": True})
    base = {"font_name": "Arial", "font_size": 10}; Fm = lambda **k: wb.add_format({**base, **k})
    H = Fm(bold=True, bg_color="#1F4E78", font_color="#FFFFFF", text_wrap=True, valign="top", border=1)
    HIN = Fm(bold=True, bg_color="#2E75B6", font_color="#FFFFFF", text_wrap=True, valign="top", border=1)
    IN = Fm(font_color="#0000FF"); IN_N = Fm(font_color="#0000FF", num_format="#,##0"); IN_2 = Fm(font_color="#0000FF", num_format="0.00")
    FX = Fm(); FN = Fm(num_format="#,##0"); F2 = Fm(num_format="0.00"); FP = Fm(num_format="0%"); F1 = Fm(num_format="0.0")
    T1 = Fm(bold=True, font_size=14); T2 = Fm(bold=True, font_size=11); B = Fm(bold=True); W = Fm(text_wrap=True, valign="top")
    Y = Fm(bg_color="#FFFF00", font_color="#0000FF", border=1); YP = Fm(bg_color="#FFFF00", font_color="#0000FF", border=1, num_format="0%")
    BIG = Fm(num_format="#,##0", bold=True)
    UR = lambda c: f"'{U}'!${c}$2:${c}${last}"

    ws = wb.add_worksheet("Nasıl okunur"); ws.set_column(1, 1, 118); ws.set_column(2, 2, 16); ws.hide_gridlines(2)
    ws.write(0, 1, f"{mad} — Min/Max ve bugünkü sipariş listesi ({BUGUN:%d.%m.%Y})", T1)
    r = 2
    for t_, f_ in [("Bu dosya her ürün için iki sayı verir:", T2),
                   ("Min — raftaki stok (yoldaki dahil) bu sayıya ya da altına inerse sipariş verilir.", W),
                   ("Max — sipariş, stoğu bu sayıya tamamlayacak kadar verilir. 'Sipariş (adet)' sütunu bugün ne kadar isteneceğini gösterir.", W),
                   ("", W), ("Nasıl hesaplanır:", T2),
                   ("1) Günlük beklenen satış = haftalık tahmin × sezon çarpanı ÷ 7. Tahmin yalnız geçmiş satıştan; sezon çarpanı kategorinin okul, yılbaşı gibi dönemlerdeki eğrisi.", W),
                   ("2) Stoklamaya değer mi? Ürünün bir yıl içinde satılma olasılığı × kârı, bir adeti bir yıl tutmanın maliyetinden küçükse stoklanmaz (Min = Max = 0); talep gelince ODAK'tan.", W),
                   ("3) Raf kuralı: stoklanmayan bir kitap ODAK'ta varsa ya da temin ediliyorsa ve yazarı ya da yayınevi önemliyse rafta 1 adet tutulur (Min 0, Max 1).", W),
                   ("4) Min = koruma süresi (4 gün) boyunca beklenen satış + güvenlik payı. Güvenlik payı hizmet seviyesi ve satışın oynaklığından gelir.", W),
                   ("5) Max = Min + ekonomik sipariş miktarı (çok küçük siparişlerle uğraşmamak için; en az 1).", W),
                   ("6) Sipariş = stok + yolda ≤ Min ise Max − (stok + yolda), değilse 0.", W),
                   ("7) Stoğu 0 olan ürün son 26 haftada en az 2 kez satmadıysa yeniden sipariş edilmez (Ayarlar'da değiştirilebilir; raf kuralındaki kitaplar hariç).", W),
                   ("8) Onaya düşer: maliyeti tahmin/şüpheli olan ya da sipariş sonrası stoğu çok uzun yetecek satırlar otomatik geçmez (Ayarlar C17/C18).", W),
                   ("Fiyatlar: kart satış fiyatı KDV DAHİL; kâr hesabında KDV hariç net fiyat kullanılır. Maliyet kaynağı her satırda yazılıdır.", W),
                   ("", W), ("Örnek — Ürünler sayfasının ilk satırı (canlı):", T2)]:
        ws.write(r, 1, t_, f_); r += 1
    for t_, f_, fm in [("Ürün", "='Ürünler'!B2", W), ("Stok", "='Ürünler'!E2", FN), ("Günlük beklenen satış", "='Ürünler'!R2", F2),
                       ("Hizmet seviyesi", "='Ürünler'!S2", FP), ("Stoklamaya değer mi", "='Ürünler'!U2", FX), ("Min", "='Ürünler'!W2", FN),
                       ("Max", "='Ürünler'!Y2", FN), ("Sipariş (adet)", "='Ürünler'!Z2", FN), ("Sipariş tutarı (TL)", "='Ürünler'!AA2", FN)]:
        ws.write(r, 1, "   " + t_, W); ws.write_formula(r, 2, f_, fm); r += 1
    r += 1
    for t_, f_ in [("Renkler: mavi = sistemden gelen veri · siyah = formül · sarı (Ayarlar) = sizin değiştirebileceğiniz değer.", W),
                   ("Ne kadar güvenilir: politika geçmişte 3 ayrı 26 haftalık dönemde, 3 şubede gün gün denendi. Gerçekleşenle hemen hemen AYNI stoğu tutarak gerçekte yapılmış satışların %94–96'sını yakaladı "
                    "(kaçan %4–6; gerçekleşenin kendi kaçanı ölçülemediği için 'mevcut uygulamadan iyi' denemez). Kalan kaybın %92–95'i ani sıçrama haftalarından (toplu alım gibi).", W),
                   ("Bilinmeyenler: yoldaki mal (0 kabul edildi — biliniyorsa 'Yolda' sütununa yazın) · ürünün koli/paket büyüklüğü · sayım farkları. Sipariş maliyeti ve elde tutma oranı kalibre edilmedi.", W),
                   ("Kapsam dışı: Sınav Okul Malzemeleri (kurumsal paketler) ve envanter dışı kodlar (poşet, hediye çeki …).", W),
                   ("Kaynak: DerinSIS (anlık stok, satış hareketleri, ürün kartı), BKMDATA ODAK durumu. Salt okuma. bkm.OneriSiparis KULLANILMADI.", W)]:
        ws.write(r, 1, t_, f_); r += 1

    wo = wb.add_worksheet("Özet"); wo.set_column(0, 0, 44); wo.set_column(1, 6, 15); wo.hide_gridlines(2)
    wo.write(0, 0, f"{mad} — bugünkü sipariş özeti ({BUGUN:%d.%m.%Y})", T1); wo.write(1, 0, "Tüm rakamlar 'Ürünler' sayfasından formülle.", W)
    for j, h in enumerate(["Grup", "Ürün", "Stoklanan ürün", "Raf kuralıyla 1 adet", "Sipariş verilecek ürün", "Sipariş adet", "Sipariş tutarı (TL)", "Onaya düşen ürün", "Onaya düşen tutar (TL)"]): wo.write(3, j, h, H)
    for i, g in enumerate(GRUPLAR):
        rr = 4 + i; ref = f"$A{rr + 1}"; wo.write(rr, 0, g)
        wo.write_formula(rr, 1, f"=COUNTIFS({UR('C')},{ref})", FN)
        wo.write_formula(rr, 2, f'=COUNTIFS({UR("C")},{ref},{UR("U")},"Evet")', FN)
        wo.write_formula(rr, 3, f'=COUNTIFS({UR("C")},{ref},{UR("U")},"Hayır",{UR("V")},"Evet")', FN)
        wo.write_formula(rr, 4, f'=COUNTIFS({UR("C")},{ref},{UR("Z")},">0")', FN)
        wo.write_formula(rr, 5, f"=SUMIFS({UR('Z')},{UR('C')},{ref})", FN)
        wo.write_formula(rr, 6, f"=SUMIFS({UR('AA')},{UR('C')},{ref})", FN)
        wo.write_formula(rr, 7, f'=COUNTIFS({UR("C")},{ref},{UR("AI")},"Evet")', FN)
        wo.write_formula(rr, 8, f'=SUMIFS({UR("AA")},{UR("C")},{ref},{UR("AI")},"Evet")', FN)
    rt = 4 + len(GRUPLAR); wo.write(rt, 0, "Toplam", B)
    for j in range(1, 9): col = "ABCDEFGHI"[j]; wo.write_formula(rt, j, f"=SUM({col}5:{col}{rt})", BIG)

    wu = wb.add_worksheet(U); wu.freeze_panes(1, 2); wu.set_row(0, 48)
    for j, (h, w, t, src, ac) in enumerate(COLS):
        wu.write(0, j, h, HIN if t == "in" else H); wu.set_column(j, j, w)
        if ac: wu.write_comment(0, j, ac, {"x_scale": 2.2, "y_scale": 1.3})
    fin = {"stok": IN_N, "yolda": IN_N, "tahmin_h": IN_2, "sezon": IN_2, "sd_h": IN_2, "s26": IN_N, "fiyat": IN_2, "sonalis_kart": IN_2, "med12": IN_2, "kdv": IN_N,
           "odak_stok": IN_N, "odak_durum": IN_N, "temin_gun": IN_N}
    ff = [F2, F2, F2, FP, FP, FX, FX, FN, F2, FN, FN, FN, F1, F1, FX, F1, FX]
    arr = {c: d[c].to_numpy() for c in d.columns}
    eoq_py = np.where(d.maliyet > 0, np.sqrt(2 * 52 * d.tahmin_h * d.sezon * A_[4] / (d.maliyet * A_[5]).where(d.maliyet > 0, 1)), 0)
    for i in range(n):
        r = i + 1; e = r + 1; fj = 0
        for j, (h, w, t, src, ac) in enumerate(COLS):
            if t == "f":
                key = PYV[fj]; v = eoq_py[i] if key is None else arr[key][i]
                if isinstance(v, (float, np.floating)) and not np.isfinite(v): v = ""
                elif isinstance(v, (np.floating, np.integer)): v = float(v)
                wu.write_formula(r, j, src.format(r=e), ff[fj], v); fj += 1; continue
            v = arr[src][i]
            if isinstance(v, str): wu.write_string(r, j, v, IN)
            elif v is None or (isinstance(v, float) and np.isnan(v)): continue
            else: wu.write_number(r, j, float(v), fin.get(src, IN))
    wu.autofilter(0, 0, n, len(COLS) - 1)

    wa = wb.add_worksheet("Ayarlar"); wa.set_column(1, 1, 40); wa.set_column(2, 2, 12); wa.set_column(3, 3, 112)
    wa.write(0, 1, "Ayarlar — sarı hücreleri değiştirebilirsiniz; tüm dosya yeniden hesaplanır", T1)
    wa.write(1, 1, "Ayar", H); wa.write(1, 2, "Değer", H); wa.write(1, 3, "Ne işe yarar", H)
    for rr, name, val, ac in AYAR:
        sl = 9 <= rr <= 13
        if rr == 9: wa.write(7, 1, "Hizmet seviyeleri (kategori grubuna göre)", B)   # constant_memory: satırlar ARTAN sırada yazılmalı (aksi hâlde sessizce kaybolur)
        wa.write(rr - 1, 1, name.split(" — ")[-1] if sl else name, B)
        wa.write_number(rr - 1, 2, val, YP if sl else Y); wa.write(rr - 1, 3, ac, W)
    wa.write(21, 1, "Hizmet seviyesi başlangıç değerleri: 3 şube × 2 dönem benzetiminde 'kaçan satış kârı + elde tutma maliyeti' toplamını en aza indiren seviyeler (marj %40, elde tutma %40/yıl varsayımıyla).", W)
    wb.close()


if __name__ == "__main__":
    os.makedirs(OUTD, exist_ok=True)
    for mk in SECIM:
        d = hazirla(mk)
        p = os.path.join(OUTD, f"2026-10-14-minmax-{AD[mk].replace('.', '')}.xlsx")
        kitap(mk, d, p)
        d.assign(eoq=np.where(d.maliyet > 0, np.sqrt(2 * 52 * d.tahmin_h * d.sezon * A_[4] / (d.maliyet * A_[5]).where(d.maliyet > 0, 1)), 0))[
            ["stk", "sonalis", "maliyet", "mu_g", "SL", "psat", "stokla", "raf", "Min", "eoq", "Max", "siparis", "siparis_TL", "min_gun", "max_gun", "kaynak", "gun_sonra", "onay"]].to_csv(
            p.replace(".xlsx", ".python-degerleri.csv"), index=False, encoding="utf-8-sig")
        print(f"{AD[mk]}: {len(d):,} ürün · stoklanan {int((d.stokla == 'Evet').sum()):,} · raf kuralı {int(((d.stokla == 'Hayır') & (d.raf == 'Evet')).sum()):,} · "
              f"sipariş {int((d.siparis > 0).sum()):,} ürün / {d.siparis.sum():,.0f} adet / {d.siparis_TL.sum():,.0f} TL → {p}")
