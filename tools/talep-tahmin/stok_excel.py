"""
Fazla + hareketsiz stok — mekan başına FORMÜLLÜ Excel (sahip, 2026-10-14: "bilmeyen biri bile anlamalı, formüllü olmalı").
Ham veri (mavi) ERP'den gelir; tüm hesaplar (siyah) Excel formülüdür ve 'Ayarlar' sayfasındaki sarı hücrelere bağlıdır.
Formüllere Python'un aynı hesapla bulduğu değer önbellek olarak yazılır (dosya açılır açılmaz rakam görünsün);
doğrulama: excel_dogrula.ps1 dosyayı gerçek Excel'de baştan hesaplatır, sonuç Python değerleriyle satır satır karşılaştırılır.
Girdi: .cache/talep-tahmin-ortak/fazla-<mekan>.csv (sorgular/06-operasyon/2026-10-14-fazla-hareketsiz-stok.sql) + ürün kartları + adlar.
Kullanım: python stok_excel.py <çıktı_dizini> [mekan ...]   (varsayılan: 1 4477 4478 12)
"""
import datetime as dt
import os
import sys

import numpy as np
import pandas as pd
import xlsxwriter

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
C = os.path.join(ROOT, ".cache")
OUTD = sys.argv[1]
SECIM = [int(x) for x in sys.argv[2:]] or [1, 4477, 4478, 12]
MEKAN = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu", 12: "Merkez Depo"}
BUGUN = dt.date(2026, 10, 14)
# Ayarlar — (satır, ad, değer, açıklama). Formüller bu hücrelere bağlı; değiştirilirse tüm dosya yeniden hesaplanır.
AYAR = [
    (3, "Fazla sayılma eşiği (yıl)", 1, "Stok, beklenen satışın bu kadar yılından fazlasına yetiyorsa 'fazla' sayılır."),
    (4, "Rapor tarihi", BUGUN, "Hareketsizlik ve 'yeni ürün' bu tarihe göre ölçülür. Stok ve hareketler bu tarihin verisidir."),
    (5, "Büyüme yumuşatma (adet)", 5, "Az satan üründe tek başına ürünün kendi büyümesine güvenilmez; bu kadar adetlik ağırlıkla kategori büyümesine yaklaştırılır."),
    (6, "Ürün büyümesi alt sınır", 0.25, "Büyüme çarpanı bundan küçük olamaz (aşırı düşüşü sınırlar)."),
    (7, "Ürün büyümesi üst sınır", 2, "Büyüme çarpanı bundan büyük olamaz (aşırı artışı sınırlar)."),
    (8, "Kategori büyümesi alt sınır", 0.5, "Kategori büyümesi bundan küçük olamaz."),
    (9, "Kategori büyümesi üst sınır", 2, "Kategori büyümesi bundan büyük olamaz."),
    (10, "Çok fazla eşiği (yıl)", 3, "Bu kadar yıldan uzun yetecek stok 'çok fazla' diye ayrıca işaretlenir."),
    (11, "Hareketsizlik eşiği (hafta)", 52, "Bu kadar haftadır gerçek hareket (satış, alış, transfer, iade) görmeyen ürün 'hareketsiz' sayılır."),
    (12, "Yeni ürün eşiği (hafta)", 52, "Bundan daha yeni ürünlerin geçen yılı yok; büyüme olarak kategori büyümesi kullanılır."),
    (13, "Maliyet yoksa fiyat × oran", 0.6, "Son alış maliyeti bilinmeyen üründe maliyet = satış fiyatı × bu oran (tahmin)."),
    (14, "Transfer eşiği (şirket geneli, yıl)", 0.5, "Bu şubede fazla ama tüm şirkette bundan kısa süreye yeten ürün 'transfer adayı' sayılır."),
]
A_ = {r: v for r, _, v, _ in AYAR}
DEF_DISI = "Stok EKLE, Merkezi Düzeltme, Diğer Giriş, Diğer Çıkış, Ürün SAY, Devir, Sayım"

# ── veri ──────────────────────────────────────────────────────────────────────────────────────────────
kart = [pd.read_csv(os.path.join(C, f), low_memory=False) for f in
        ["talep-tahmin/urunbilgi.csv", "talep-tahmin-4477/urunbilgi.csv", "talep-tahmin-4478/urunbilgi.csv",
         "talep-tahmin-ortak/urunbilgi-tum.csv", "talep-tahmin-ortak/urunbilgi-4478-12.csv"] if os.path.exists(os.path.join(C, f))]
ub = pd.concat(kart).drop_duplicates("stk").set_index("stk")
ad = pd.concat([pd.read_csv(os.path.join(C, "talep-tahmin-ortak/adlar-ek.csv")), pd.read_csv(os.path.join(C, "talep-tahmin/adlar.csv"))]).drop_duplicates("stk").set_index("stk")["ad"]
dis = set(pd.read_csv(os.path.join(C, "talep-tahmin/devredisi.csv")).iloc[:, 0])
# 2026-10-15 danışman bulguları (doğrulandı): mal-olmayan kodlar (Kategori3 KARGO/Genel/Zkargo — sema mutabakat_evreni_hizmet_sarf_haric),
# Sınav operasyonu markaları (dağıtım kayda girmiyor → ayrı), birim maliyet için son 12 ay alış medyanı
MAL_DEGIL = set(pd.read_csv(os.path.join(C, "talep-tahmin-ortak/mal-olmayan.csv")).stk.astype(int))
SINAV_MRK = {2100, 2101, 3904, 3905, 3906, 4641, 5298, 5972, 5973, 5974}
MED12 = pd.read_csv(os.path.join(C, "talep-tahmin-ortak/alis-medyan12.csv")).set_index("stk")["medyan12"]
NEG = pd.read_csv(os.path.join(C, "talep-tahmin-ortak/negatif.csv"))
KDV = pd.read_csv(os.path.join(C, "talep-tahmin-ortak/kdv.csv")).drop_duplicates("stk").set_index("stk")["kdv"]   # kart fiyatı KDV dahil (ölçüldü)
ham = {}
for mk in MEKAN:
    d = pd.read_csv(os.path.join(C, f"talep-tahmin-ortak/fazla-{mk}.csv")).drop_duplicates("stk")
    d = d[~d.stk.isin(dis) & ~d.stk.isin(MAL_DEGIL)].copy()
    d["talep52"] = d.satis52 + (d.sevk52 if mk == 12 else 0); d["talep52p"] = d.satis52p + (d.sevk52p if mk == 12 else 0)
    ham[mk] = d
sir = pd.concat(ham.values()).groupby("stk").agg(sir_stok=("stok", "sum"), sir_satis=("satis52", "sum"))   # depo sevki iç akış → sayılmaz


def tarih(s):
    return pd.to_datetime(s, errors="coerce")


def hazirla(mk):
    d = ham[mk].join(sir, on="stk")
    u = ub.reindex(d.stk)
    d["ürün"] = [ad.get(s, "(adı bulunamadı)") for s in d.stk]
    _k2 = u["kat2"].fillna("").to_numpy(); _ka = u["katana"].fillna("").to_numpy()
    _kitap = np.isin(_k2, ["Tanımsız", "Genel", ""]) & pd.Series(_ka).str.contains("Kitap|Okula Yardımcı|Sınavlara Hazırlık|Periyodik", regex=True).to_numpy()
    d["grup"] = np.where(_kitap, "Kitap", np.where(_k2 == "", "(grup yok)", _k2))     # ön-kayıt 11: kat2 Tanımsız kitaplar
    d["kategori"] = u["katana"].fillna("(kategori yok)").to_numpy()
    d["sonalis_kart"] = u["sonalis"].to_numpy(float); d["fiyat"] = u["fiyat"].to_numpy(float)
    d["med12"] = MED12.reindex(d.stk).to_numpy(float); d["kdv"] = KDV.reindex(d.stk).fillna(0).to_numpy(float)
    kart = np.nan_to_num(d.sonalis_kart); med = np.nan_to_num(d.med12)
    d["sonalis"] = np.where(kart > 0.05, np.where((med > 0) & (kart > 3 * med), med, kart), 0.0)   # H ikizi (medyan YALNIZ yukarı hatada)
    d["sinav"] = np.where(pd.Series(u["katana"].fillna("")).str.startswith("Sınav Okul").to_numpy() | u["yayinevi"].isin(SINAV_MRK).to_numpy(), "Evet", "")
    d["giris_t"] = tarih(u["giris"]).to_numpy(); d["songer_t"] = tarih(d.son_gercek); d["sonsat_t"] = tarih(d.son_satis)
    # Python ikizleri — Excel formülleriyle BİREBİR aynı hesap (önbellek değer + doğrulama referansı)
    _pnet = np.nan_to_num(d.fiyat) / (1 + d.kdv / 100)
    d["maliyet"] = np.where(d.sonalis > 0, np.where(d.sonalis > 1.5 * _pnet, _pnet * A_[13], d.sonalis), _pnet * A_[13])   # O ikizi
    d["stok_tl"] = d.stok * d.maliyet
    sup = (d.stok_tl > 5e6) | ((d.stok > 100_000) & (d.stok > 20 * np.maximum(d.talep52, 1)))
    ayrilan = d[sup].copy(); d = d[~sup].copy()
    bugun = pd.Timestamp(BUGUN)
    d["yeni"] = np.where(pd.notna(d.giris_t) & (d.giris_t > bugun - pd.Timedelta(days=7 * A_[12])), "Evet", "Hayır")
    k = d.groupby("kategori")[["talep52p", "talep52"]].sum()
    kat = pd.DataFrame({"n": d.groupby("kategori").size(), "onceki": k.talep52p, "son": k.talep52})
    kat["buyume"] = np.where(kat.onceki > 0, np.clip(kat.son / kat.onceki.where(kat.onceki > 0, 1), A_[8], A_[9]), 1.0)
    kat = kat.sort_values("son", ascending=False)
    d["kat_b"] = kat.buyume.reindex(d.kategori).to_numpy()
    gp = np.minimum(A_[7], np.maximum(A_[6], (np.maximum(d.talep52, 0) + A_[5] * d.kat_b) / (np.maximum(d.talep52p, 0) + A_[5])))
    d["buyume"] = np.where(d.yeni == "Evet", d.kat_b, gp)
    d["beklenen"] = np.maximum(d.talep52, 0) * d.buyume
    d["kapsama"] = np.where(d.beklenen > 0, d.stok / d.beklenen.where(d.beklenen > 0, 1), np.nan)
    d["durum"] = np.where(d.beklenen == 0, "Satış yok (tamamı fazla)",
                          np.where(d.kapsama > A_[10], "Çok fazla (3 yıldan uzun)", np.where(d.kapsama > A_[3], "Fazla (1–3 yıl)", "Normal")))
    d["fazla_adet"] = np.where(d.beklenen == 0, d.stok, np.maximum(0, d.stok - d.beklenen * A_[3]))
    d["fazla_tl"] = d.fazla_adet * d.maliyet
    hh = (bugun - d.songer_t).dt.days
    d["har_hafta"] = np.floor(hh / 7)
    d["hareketsiz"] = np.where(d.songer_t.isna() | (hh > 7 * A_[11]), "Evet", "Hayır")
    d["sir_kap"] = np.where(d.sir_satis > 0, d.sir_stok / d.sir_satis.where(d.sir_satis > 0, 1), np.nan)
    d["transfer"] = np.where((mk != 12) & (d.fazla_adet > 0) & (d.sir_satis > 0) & (d.sir_kap < A_[14]), "Evet", "")
    d = d.sort_values(["sinav", "fazla_tl", "stok_tl"], ascending=[True, False, False]).reset_index(drop=True)   # Sınav en sonda
    return d, kat, ayrilan


# ── Excel ─────────────────────────────────────────────────────────────────────────────────────────────
# Ürünler sayfası sütunları: (başlık, genişlik, tür, kaynak/formül, açıklama). tür: in=ham veri (mavi), f=formül (siyah)
U = "Ürünler"
COLS = [
    ("Ürün kodu", 10, "in", "stk", "ERP ürün kodu (stkID)."),
    ("Ürün adı", 46, "in", "ürün", ""),
    ("Grup", 18, "in", "grup", "Ürün kartındaki ana grup."),
    ("Kategori", 26, "in", "kategori", "Ürün kartındaki kategori."),
    ("Stok (adet)", 10, "in", "stok", "Bugünkü stok (stokSonAltDepo_vw)."),
    ("Önceki yıl talep (adet)", 12, "in", "talep52p", "104–52 hafta önce arası: satış − iade. Merkez Depo'da + şubelere/depolara sevk."),
    ("Son yıl talep (adet)", 12, "in", "talep52", "Son 52 hafta: satış − iade. Merkez Depo'da + şubelere/depolara sevk."),
    ("Kullanılan alış maliyeti (TL)", 12, "f", "=IF(N(AC{r})>0.05,IF(AND(N(AD{r})>0,AC{r}>3*AD{r}),AD{r},AC{r}),0)",
     "Kart son alışı (AC); kart, son 12 ay alış medyanının (AD) 3 katından YÜKSEKSE medyan (tek koli fiyatlı satır kartı bozabiliyor). Kart 0,05 TL altı = yok. Medyan aşağı düzeltmede kullanılmaz (kitap alış satırları iskontosuz liste fiyatı)."),
    ("Satış fiyatı (TL)", 11, "in", "fiyat", "Ürün kartındaki satış fiyatı."),
    ("Ürün giriş tarihi", 11, "in_d", "giris_t", "Ürünün sisteme ilk giriş tarihi."),
    ("Son gerçek hareket", 11, "in_d", "songer_t", f"Son satış/alış/transfer/iade tarihi. Defter düzeltmeleri ({DEF_DISI}) hareket sayılmaz. Boş = hiç yok."),
    ("Son satış tarihi", 11, "in_d", "sonsat_t", "Boş = hiç satılmamış."),
    ("Şirket toplam stok (adet)", 12, "in", "sir_stok", "Bu ürünün 3 şube + Merkez Depo toplam stoğu."),
    ("Şirket son yıl satış (adet)", 12, "in", "sir_satis", "Bu ürünün tüm mekanlardaki son 52 hafta satışı (iç sevk hariç)."),
    ("Birim maliyet (TL)", 11, "f", "=IF(N(H{r})>0,IF(H{r}>1.5*I{r}/(1+AF{r}/100),I{r}/(1+AF{r}/100)*Ayarlar!$C$13,H{r}),I{r}/(1+AF{r}/100)*Ayarlar!$C$13)",
     "Alış maliyeti; yoksa ya da KDV hariç net fiyatın 1,5 katından büyükse (birim şüphesi) net fiyat × Ayarlar C13."),
    ("Stok tutarı (TL)", 13, "f", "=E{r}*O{r}", "Stok × birim maliyet."),
    ("Yeni ürün mü", 9, "f", '=IF(AND(ISNUMBER(J{r}),J{r}>Ayarlar!$C$4-7*Ayarlar!$C$12),"Evet","Hayır")', "Giriş tarihi Ayarlar C12 haftadan yeniyse Evet."),
    ("Kategori büyümesi", 10, "f", "=IFERROR(INDEX('Kategori büyümesi'!$E:$E,MATCH(D{r},'Kategori büyümesi'!$A:$A,0)),1)", "'Kategori büyümesi' sayfasından."),
    ("Büyüme çarpanı", 10, "f", '=IF(Q{r}="Evet",R{r},MIN(Ayarlar!$C$7,MAX(Ayarlar!$C$6,(MAX(G{r},0)+Ayarlar!$C$5*R{r})/(MAX(F{r},0)+Ayarlar!$C$5))))',
     "(Son yıl + 5 × kategori büyümesi) ÷ (önceki yıl + 5); 0,25–2 arası. Yeni üründe kategori büyümesi."),
    ("Beklenen gelecek yıl satış (adet)", 13, "f", "=MAX(G{r},0)*S{r}", "Son yıl talep × büyüme çarpanı."),
    ("Kaç yıl yeter", 9, "f", '=IF(T{r}>0,E{r}/T{r},"Satış yok")', "Stok ÷ beklenen gelecek yıl satış."),
    ("Durum", 22, "f", '=IF(T{r}=0,"Satış yok (tamamı fazla)",IF(U{r}>Ayarlar!$C$10,"Çok fazla (3 yıldan uzun)",IF(U{r}>Ayarlar!$C$3,"Fazla (1–3 yıl)","Normal")))',
     "Kaç yıl yeter > 3 → Çok fazla · > 1 → Fazla · satış yoksa stoğun tamamı fazla."),
    ("Fazla adet", 10, "f", "=IF(T{r}=0,E{r},MAX(0,E{r}-T{r}*Ayarlar!$C$3))", "Stoktan, bir yıllık beklenen satış düşülünce kalan."),
    ("Fazla tutar (TL)", 13, "f", "=W{r}*O{r}", "Fazla adet × birim maliyet."),
    ("Kaç haftadır hareketsiz", 11, "f", '=IF(ISNUMBER(K{r}),INT((Ayarlar!$C$4-K{r})/7),"Hiç hareket yok")', "Rapor tarihi − son gerçek hareket (hafta)."),
    ("Hareketsiz mi", 9, "f", '=IF(OR(NOT(ISNUMBER(K{r})),Ayarlar!$C$4-K{r}>7*Ayarlar!$C$11),"Evet","Hayır")', "Ayarlar C11 haftadan uzun süredir gerçek hareket yoksa Evet."),
    ("Şirket geneli kaç yıl yeter", 11, "f", '=IF(N{r}>0,M{r}/N{r},"Satış yok")', "Şirket toplam stok ÷ şirket son yıl satış."),
    ("Transfer adayı", 9, "f", '=IF(AND(W{r}>0,ISNUMBER(AA{r}),AA{r}<Ayarlar!$C$14),"Evet","")', "Burada fazla ama şirket genelinde Ayarlar C14 yıldan kısa yetiyor → başka şubeye kaydırılabilir."),
    ("Kart son alış (TL)", 11, "in", "sonalis_kart", "Ürün kartındaki son alış (ham)."),
    ("Son 12 ay alış medyanı (TL)", 11, "in", "med12", "Son 12 ayın alış satırlarının (Alış, Yerel Alım) birim fiyat medyanı. Boş = son 12 ayda alış yok."),
    ("Sınav operasyonu", 9, "in", "sinav", "Sınav Okul Malzemeleri ya da Sınav markası. Dağıtım satış olarak kaydedilmediği için stok ŞİŞİK görünebilir — fazla toplamına katılmaz, ayrı gösterilir."),
    ("Satış KDV %", 7, "in", "kdv", "Ürün kartındaki satış KDV oranı. Satış fiyatı KDV DAHİL; tahmini maliyet KDV hariç net fiyattan hesaplanır."),
]
PYV = ["sonalis", "maliyet", "stok_tl", "yeni", "kat_b", "buyume", "beklenen", "kapsama", "durum", "fazla_adet", "fazla_tl", "har_hafta", "hareketsiz", "sir_kap", "transfer"]


def kitap(mk, d, kat, ayrilan, path):
    mad = MEKAN[mk]; n = len(d); last = n + 1
    wb = xlsxwriter.Workbook(path, {"constant_memory": True, "strings_to_numbers": False})
    base = {"font_name": "Arial", "font_size": 10}
    F = lambda **k: wb.add_format({**base, **k})
    H = F(bold=True, bg_color="#1F4E78", font_color="#FFFFFF", text_wrap=True, valign="top", border=1)
    HIN = F(bold=True, bg_color="#2E75B6", font_color="#FFFFFF", text_wrap=True, valign="top", border=1)
    IN = F(font_color="#0000FF"); IN_N = F(font_color="#0000FF", num_format="#,##0"); IN_TL = F(font_color="#0000FF", num_format="#,##0.00")
    IN_D = F(font_color="#0000FF", num_format="dd.mm.yyyy")
    FX = F(); FX_N = F(num_format="#,##0"); FX_TL = F(num_format="#,##0"); FX_1 = F(num_format="0.0"); FX_2 = F(num_format="0.00")
    T1 = F(bold=True, font_size=14); T2 = F(bold=True, font_size=11); B = F(bold=True); W = F(text_wrap=True, valign="top")
    Y = F(bg_color="#FFFF00", font_color="#0000FF", border=1); YD = F(bg_color="#FFFF00", font_color="#0000FF", border=1, num_format="dd.mm.yyyy")
    BIG = F(num_format="#,##0", bold=True); PCT = F(num_format="0.0%", bold=True)

    # 1) Nasıl okunur
    ws = wb.add_worksheet("Nasıl okunur"); ws.set_column(0, 0, 4); ws.set_column(1, 1, 120); ws.hide_gridlines(2)
    ws.write(0, 1, f"{mad} — fazla ve hareketsiz stok ({BUGUN:%d.%m.%Y})", T1)
    satirlar = [
        ("Bu dosya üç soruya cevap verir:", T2),
        ("1) Hangi ürünlerden, önümüzdeki bir yılda satabileceğimizden FAZLA stok var? → 'Durum' sütunu, 'Fazla adet', 'Fazla tutar'.", W),
        ("2) Hangi ürünler 52 haftadır hiç hareket görmedi (satılmadı, alınmadı, transfer edilmedi)? → 'Hareketsiz mi' sütunu.", W),
        ("3) Burada fazla olan hangi ürün başka şubede lazım? → 'Transfer adayı' sütunu (satın almak yerine kaydırılabilir).", W),
        ("", W),
        ("Nasıl hesaplanır (tek ürün için, adım adım):", T2),
        ("a) Geçen yıl kaç adet sattık? (Son yıl talep — iadeler düşülmüş)", W),
        ("b) Ürün büyüyor mu küçülüyor mu? Son yılı önceki yılla kıyaslarız. Az satan üründe bu oran yanıltıcı olur; o yüzden kategorinin genel büyümesine yaklaştırırız. → 'Büyüme çarpanı'", W),
        ("c) Gelecek yıl kaç satarız? = son yıl satış × büyüme çarpanı → 'Beklenen gelecek yıl satış'", W),
        ("d) Stok kaç yıl yeter? = stok ÷ beklenen gelecek yıl satış → 'Kaç yıl yeter'. 1'den büyükse fazla stok var.", W),
        ("e) Ne kadarı fazla? = stok − bir yıllık beklenen satış → 'Fazla adet'; bunun maliyetle tutarı → 'Fazla tutar (TL)'.", W),
        ("", W),
        ("Örnek — Ürünler sayfasının ilk satırındaki ürün (rakamlar canlıdır, ürünler sayfasından gelir):", T2),
    ]
    r = 2
    for t, f in satirlar: ws.write(r, 1, t, f); r += 1
    ws.set_column(2, 2, 18)
    ornek = [("Ürün", "='Ürünler'!B2", W), ("Ürün kodu", "='Ürünler'!A2", FX), ("Stok (adet)", "='Ürünler'!E2", FX_N),
             ("Önceki yıl satış (adet)", "='Ürünler'!F2", FX_N), ("Son yıl satış (adet)", "='Ürünler'!G2", FX_N),
             ("Büyüme çarpanı", "='Ürünler'!S2", FX_2), ("Beklenen gelecek yıl satış (adet)", "='Ürünler'!T2", FX_N),
             ("Kaç yıl yeter", "='Ürünler'!U2", FX_1), ("Durum", "='Ürünler'!V2", FX), ("Fazla adet", "='Ürünler'!W2", FX_N),
             ("Birim maliyet (TL)", "='Ürünler'!O2", FX_TL), ("Fazla tutar (TL)", "='Ürünler'!X2", FX_TL)]
    for t, f, fm in ornek: ws.write(r, 1, "   " + t, W); ws.write_formula(r, 2, f, fm); r += 1
    r += 1
    for t in [("Renkler:", T2), ("Mavi yazı = ERP'den gelen ham veri (değiştirmeyin). Siyah yazı = formül (hesap). Sarı hücre = 'Ayarlar' sayfasında sizin değiştirebileceğiniz eşik.", W),
              ("Eşiği değiştirmek için: 'Ayarlar' sayfasındaki sarı hücreyi değiştirin; tüm dosya ve 'Özet' kendiliğinden yeniden hesaplanır (ör. 'fazla' için 1 yıl yerine 2 yıl).", W),
              ("", W), ("Sayfalar:", T2),
              ("Özet — mağazanın toplam tablosu (formülle Ürünler'den hesaplanır) · Ürünler — her stoklu ürün, bir satır; en çok para bağlayan en üstte, filtrelenebilir ·", W),
              ("Kategori büyümesi — kategorilerin son yıl / önceki yıl satış oranı · Ayarlar — eşikler · Ayrılan kayıtlar — inanılmaz büyüklükteki kayıtlar (veri hatası şüphesi), toplamlara girmez.", W),
              ("", W), ("Bilinmeyenler (bu dosya bilemez):", T2),
              ("• Ürünün yayınevine/tedarikçiye iade edilip edilemeyeceği. • Sayım farkı: kayıtta görünen ürün rafta olmayabilir. • Yoldaki (sevk edilmiş, henüz girmemiş) mal.", W),
              ("• Son alış maliyeti olmayan ürünlerde maliyet tahminidir (satış fiyatı × 0,6).", W),
              ("", W), ("Veri düzeltmeleri (15.10.2026, danışman bulguları — ERP'de doğrulandı):", T2),
              ("• Maliyet: kart son alışı, son 12 ayın alış medyanından 3 kattan fazla sapıyorsa medyan kullanılır (ör. laminasyon filmi: kartta 920 TL, gerçek alış 9,20 TL — koli fiyatı girilmiş).", W),
              ("• Sınav operasyonu (Sınav Okul Malzemeleri + Sınav markaları) AYRI gösterilir: öğrenciye dağıtım satış olarak kaydedilmiyor, stok yıl boyu birikip Ağustos'ta toplu siliniyor → 'fazla' görünür ama aksiyon rakamı değildir.", W),
              ("• Mal olmayan kodlar (kargo/kapıda ödeme/komisyon gelirleri, iskonto, kafe malzemesi, poşet) rapora alınmadı. Negatif bakiyeler ayrı sayfada.", W),
              ("", W), ("Kaynak: DerinSIS (stokSonAltDepo_vw anlık stok, irsHrk hareketler, bkm.UrunBilgi kart). Salt okuma. Tahmin modeli kullanılmadı.", W)]:
        ws.write(r, 1, t[0], t[1]); r += 1

    # 2) Özet
    wo = wb.add_worksheet("Özet"); wo.set_column(0, 0, 62); wo.set_column(1, 1, 18); wo.set_column(2, 2, 14); wo.set_column(3, 6, 16); wo.hide_gridlines(2)
    wo.write(0, 0, f"{mad} — özet ({BUGUN:%d.%m.%Y})", T1)
    wo.write(1, 0, "Tüm rakamlar 'Ürünler' sayfasından formülle hesaplanır. Tutarlar maliyet üzerinden, TL.", W)
    UR = lambda c: f"'{U}'!${c}$2:${c}${last}"
    NS = f'{UR("AE")},"<>Evet"'                  # Sınav operasyonu HARİÇ (dağıtım kayda girmiyor — 2026-10-15 doğrulandı)
    SV = f'{UR("AE")},"Evet"'
    oz = [
        ("Stokta olan ürün sayısı (Sınav operasyonu hariç)", f"=COUNTIFS({NS})", BIG, None),
        ("Toplam stok tutarı (TL)", f"=SUMIFS({UR('P')},{NS})", BIG, None),
        ("", None, None, None),
        ("Bir yıldan uzun yetecek kadar stoğu olan ürün sayısı", f'=COUNTIFS({UR("V")},"<>Normal",{NS})', BIG, None),
        ("   bu ürünlerin toplam stok tutarı (TL)", f'=SUMIFS({UR("P")},{UR("V")},"<>Normal",{NS})', BIG, "=B9/B6"),
        ("   bunun bir yılı AŞAN kısmı — fazla stok (TL)", f"=SUMIFS({UR('X')},{NS})", BIG, "=B10/B6"),
        ("      hiç satmayan (son yıl satış yok) ürünlerdeki fazla (TL)", f'=SUMIFS({UR("X")},{UR("V")},"Satış yok*",{NS})', BIG, None),
        ("      3 yıldan uzun yetecek ürünlerdeki fazla (TL)", f'=SUMIFS({UR("X")},{UR("V")},"Çok fazla*",{NS})', BIG, None),
        ("      1–3 yıl yetecek ürünlerdeki fazla (TL)", f'=SUMIFS({UR("X")},{UR("V")},"Fazla (1*",{NS})', BIG, None),
        ("", None, None, None),
        ("52 haftadır hiç gerçek hareketi olmayan ürün sayısı", f'=COUNTIFS({UR("Z")},"Evet",{NS})', BIG, None),
        ("   bu ürünlerin stok tutarı (TL)", f'=SUMIFS({UR("P")},{UR("Z")},"Evet",{NS})', BIG, "=B16/B6"),
        ("", None, None, None),
        ("Transfer adayı ürün sayısı (burada fazla, şirkette az)", f'=COUNTIFS({UR("AB")},"Evet",{NS})', BIG, None),
        ("   bu ürünlerdeki fazla tutar (TL)", f'=SUMIFS({UR("X")},{UR("AB")},"Evet",{NS})', BIG, None),
        ("", None, None, None),
        ("SINAV OPERASYONU (ayrı — dağıtım satış olarak kaydedilmiyor, stok şişik görünebilir)", f"=COUNTIFS({SV})", BIG, None),
        ("   stok tutarı (TL)", f"=SUMIFS({UR('P')},{SV})", BIG, None),
        ("   'fazla' görünen kısım (TL) — kayıt mutabakatı bekliyor, aksiyon rakamı DEĞİL", f"=SUMIFS({UR('X')},{SV})", BIG, None),
    ]
    wo.write(3, 0, "Kalem", H); wo.write(3, 1, "Değer", H); wo.write(3, 2, "Toplam stoğa oranı", H)
    for i, (t, f, fm, pf) in enumerate(oz):
        rr = 4 + i
        if not t: continue
        wo.write(rr, 0, t, B if not t.startswith(" ") else W)
        wo.write_formula(rr, 1, f, fm)
        if pf: wo.write_formula(rr, 2, pf, PCT)
    # grup tablosu
    g0 = 4 + len(oz) + 2
    wo.write(g0 - 1, 0, "Gruplara göre (Sınav operasyonu hariç)", T2)
    hdr = ["Grup", "Ürün sayısı", "Stok tutarı (TL)", "Fazla tutar (TL)", "Hareketsiz ürün", "Hareketsiz tutar (TL)"]
    for j, h in enumerate(hdr): wo.write(g0, j, h, H)
    gruplar = d.groupby("grup").fazla_tl.sum().sort_values(ascending=False).index.tolist()
    for i, g in enumerate(gruplar):
        rr = g0 + 1 + i; ref = f"$A{rr + 1}"
        wo.write(rr, 0, g)
        wo.write_formula(rr, 1, f"=COUNTIFS({UR('C')},{ref},{NS})", FX_N)
        wo.write_formula(rr, 2, f"=SUMIFS({UR('P')},{UR('C')},{ref},{NS})", FX_TL)
        wo.write_formula(rr, 3, f"=SUMIFS({UR('X')},{UR('C')},{ref},{NS})", FX_TL)
        wo.write_formula(rr, 4, f'=COUNTIFS({UR("C")},{ref},{UR("Z")},"Evet",{NS})', FX_N)
        wo.write_formula(rr, 5, f'=SUMIFS({UR("P")},{UR("C")},{ref},{UR("Z")},"Evet",{NS})', FX_TL)
    rt = g0 + 1 + len(gruplar)
    wo.write(rt, 0, "Toplam", B)
    for j in range(1, 6):
        col = "ABCDEF"[j]; wo.write_formula(rt, j, f"=SUM({col}{g0 + 2}:{col}{rt})", BIG)
    # hareketsizlik süresi
    h0 = rt + 3
    wo.write(h0 - 1, 0, "Hareketsiz ürünler — ne kadar süredir hareketsiz (Sınav operasyonu hariç)", T2)
    for j, h in enumerate(["Süre", "Ürün sayısı", "Stok tutarı (TL)"]): wo.write(h0, j, h, H)
    araliklar = [("1–2 yıl", ">=52", "<104"), ("2–3 yıl", ">=104", "<156"), ("3–5 yıl", ">=156", "<260"), ("5 yıldan uzun", ">=260", None)]
    for i, (t, a, b) in enumerate(araliklar):
        rr = h0 + 1 + i; c = f'{UR("Y")},"{a}"' + (f',{UR("Y")},"{b}"' if b else "") + f",{NS}"
        wo.write(rr, 0, t); wo.write_formula(rr, 1, f"=COUNTIFS({c})", FX_N); wo.write_formula(rr, 2, f"=SUMIFS({UR('P')},{c})", FX_TL)
    rr = h0 + 1 + len(araliklar)
    wo.write(rr, 0, "Hiç hareket kaydı yok"); wo.write_formula(rr, 1, f'=COUNTIFS({UR("Y")},"Hiç hareket yok",{NS})', FX_N)
    wo.write_formula(rr, 2, f'=SUMIFS({UR("P")},{UR("Y")},"Hiç hareket yok",{NS})', FX_TL)
    wo.write(rr + 2, 0, f"Not: {len(ayrilan)} kayıt veri hatası şüphesiyle toplamlara girmedi — 'Ayrılan kayıtlar' sayfası. "
             f"Mal olmayan kodlar (kargo/kapıda ödeme/komisyon gelirleri, iskonto, kafe malzemesi, poşet — {len(MAL_DEGIL)} kod) rapora hiç alınmadı. "
             f"Negatif bakiyeler 'Negatif bakiyeler' sayfasında.", W)

    # 3) Ürünler
    wu = wb.add_worksheet(U); wu.freeze_panes(1, 2); wu.set_row(0, 48)
    for j, (h, w, t, src, ac) in enumerate(COLS):
        wu.write(0, j, h, HIN if t.startswith("in") else H); wu.set_column(j, j, w)
        if ac: wu.write_comment(0, j, ac, {"x_scale": 2.2, "y_scale": 1.3})
    fmt_in = {"stok": IN_N, "talep52p": IN_N, "talep52": IN_N, "sonalis_kart": IN_TL, "med12": IN_TL, "kdv": IN_N, "fiyat": IN_TL, "sir_stok": IN_N, "sir_satis": IN_N}
    fmt_f = [FX_TL, FX_TL, FX_TL, FX, FX_2, FX_2, FX_N, FX_1, FX, FX_N, FX_TL, FX_N, FX, FX_1, FX]
    arr = {c: d[c].to_numpy() for c in set([s for _, _, t, s, _ in COLS if t.startswith("in")] + PYV)}
    for i in range(n):
        r = i + 1; e = r + 1
        fj = 0
        for j, (h, w, t, src, ac) in enumerate(COLS):
            if t == "f":
                v = arr[PYV[fj]][i]
                if mk == 12 and h == "Transfer adayı": fj += 1; continue          # depo: transfer kavramı yok
                if isinstance(v, (float, np.floating)) and not np.isfinite(v):
                    v = "Satış yok" if PYV[fj] in ("kapsama", "sir_kap") else "Hiç hareket yok"
                elif isinstance(v, (np.floating, np.integer)): v = float(v)
                if os.environ.get("SABOTAJ"): v = 0                                # doğrulama: önbellek BİLEREK yanlış → Excel gerçekten hesaplıyor mu?
                wu.write_formula(r, j, src.format(r=e), fmt_f[fj], v); fj += 1
                continue
            v = arr[src][i]
            if t == "in_d":
                if pd.notna(v): wu.write_datetime(r, j, pd.Timestamp(v).to_pydatetime(), IN_D)
            elif isinstance(v, str): wu.write_string(r, j, v, IN)
            elif v is None or (isinstance(v, float) and np.isnan(v)): continue
            else: wu.write_number(r, j, float(v), fmt_in.get(src, IN))
    wu.autofilter(0, 0, n, len(COLS) - 1)

    # 4) Kategori büyümesi
    wk = wb.add_worksheet("Kategori büyümesi"); wk.freeze_panes(1, 0); wk.set_row(0, 32)
    for j, (h, w) in enumerate([("Kategori", 40), ("Ürün sayısı", 11), ("Önceki yıl talep (adet)", 14), ("Son yıl talep (adet)", 14), ("Kategori büyümesi", 12)]):
        wk.write(0, j, h, H); wk.set_column(j, j, w)
    for i, (kname, row) in enumerate(kat.iterrows()):
        rr = i + 1; e = rr + 1
        wk.write_string(rr, 0, str(kname))
        wk.write_formula(rr, 1, f"=COUNTIFS({UR('D')},A{e})", FX_N, float(row.n))
        wk.write_formula(rr, 2, f"=SUMIFS({UR('F')},{UR('D')},A{e})", FX_N, float(row.onceki))
        wk.write_formula(rr, 3, f"=SUMIFS({UR('G')},{UR('D')},A{e})", FX_N, float(row.son))
        wk.write_formula(rr, 4, f"=IF(C{e}>0,MIN(Ayarlar!$C$9,MAX(Ayarlar!$C$8,D{e}/C{e})),1)", FX_2, float(row.buyume))
    wk.write(len(kat) + 2, 0, "Kategori büyümesi = son yıl ÷ önceki yıl; Ayarlar C8–C9 arasında sınırlı. Önceki yıl satışı yoksa 1 (değişim yok) kabul edilir.", W)

    # 5) Ayarlar
    wa = wb.add_worksheet("Ayarlar"); wa.set_column(1, 1, 38); wa.set_column(2, 2, 14); wa.set_column(3, 3, 110)
    wa.write(0, 1, "Ayarlar — sarı hücreleri değiştirebilirsiniz; tüm dosya yeniden hesaplanır", T1)
    wa.write(1, 1, "Ayar", H); wa.write(1, 2, "Değer", H); wa.write(1, 3, "Ne işe yarar", H)
    for rr, name, val, ac in AYAR:
        wa.write(rr - 1, 1, name, B)
        if isinstance(val, dt.date): wa.write_datetime(rr - 1, 2, dt.datetime.combine(val, dt.time()), YD)
        else: wa.write_number(rr - 1, 2, val, Y)
        wa.write(rr - 1, 3, ac, W)
    wa.write(AYAR[-1][0] + 1, 1, "Kaynak: eşikler sahip ile konuşularak seçilen başlangıç değerleridir (14.10.2026); kalibre edilmemiştir.", W)

    # 6) Ayrılan kayıtlar
    wy = wb.add_worksheet("Ayrılan kayıtlar"); wy.set_column(0, 0, 10); wy.set_column(1, 1, 50); wy.set_column(2, 6, 16)
    for j, h in enumerate(["Ürün kodu", "Ürün adı", "Stok (adet)", "Son yıl talep", "Birim maliyet", "Stok tutarı", "Neden"]): wy.write(0, j, h, H)
    for i, rw in enumerate(ayrilan.itertuples()):
        wy.write(i + 1, 0, rw.stk); wy.write(i + 1, 1, rw.ürün); wy.write(i + 1, 2, rw.stok, FX_N); wy.write(i + 1, 3, rw.talep52, FX_N)
        wy.write(i + 1, 4, rw.maliyet, FX_TL); wy.write(i + 1, 5, rw.stok_tl, FX_TL)
        wy.write(i + 1, 6, "Tek kalem 5 milyon TL'den büyük ya da 100.000 adetten fazla ve yıllık talebin 20 katı — veri hatası olabilir, kontrol edilmeli.")
    if not len(ayrilan): wy.write(1, 0, "Ayrılan kayıt yok.")

    # 7) Negatif bakiyeler (2026-10-15 muhasebe danışmanı — rapor toplamına girmiyordu, görünmüyordu)
    ng = NEG[NEG.mekan == mk].copy(); ng["stk"] = ng.stk.astype(int)
    un = ub.reindex(ng.stk)
    ng["ad"] = [ad.get(s_, "(adı bulunamadı)") for s_ in ng.stk]; ng["kategori"] = un["katana"].fillna("").to_numpy()
    kk = np.nan_to_num(un["sonalis"].to_numpy(float)); ff = np.nan_to_num(un["fiyat"].to_numpy(float))
    ng["maliyet"] = np.where(kk > 0, kk, ff * A_[13])
    ng["tur"] = np.where(ng.stk.isin(MAL_DEGIL), "Mal değil (hizmet/muhasebe kodu)",
                         np.where(pd.Series(un["katana"].fillna("")).str.startswith("Sınav Okul").to_numpy() | un["yayinevi"].isin(SINAV_MRK).to_numpy(), "Sınav operasyonu", "Ürün"))
    ng = ng.assign(tl=ng.stok * ng.maliyet).sort_values("tl")
    wn = wb.add_worksheet("Negatif bakiyeler"); wn.freeze_panes(1, 0)
    for j, (h, w) in enumerate([("Ürün kodu", 10), ("Ürün adı", 46), ("Kategori", 26), ("Tür", 30), ("Stok (adet, negatif)", 14), ("Birim maliyet (TL)", 13), ("Tutar (TL)", 15)]):
        wn.write(0, j, h, H); wn.set_column(j, j, w)
    for i, rw in enumerate(ng.itertuples()):
        e = i + 2
        wn.write_number(i + 1, 0, rw.stk); wn.write_string(i + 1, 1, str(rw.ad)); wn.write_string(i + 1, 2, str(rw.kategori)); wn.write_string(i + 1, 3, rw.tur)
        wn.write_number(i + 1, 4, float(rw.stok), FX_N); wn.write_number(i + 1, 5, float(rw.maliyet), FX_TL)
        wn.write_formula(i + 1, 6, f"=E{e}*F{e}", FX_TL, float(rw.tl))
    wn.write(len(ng) + 2, 1, "Defterde stok eksiye düşmüş kalemler (satış/çıkış girişten önce kaydedilmiş ya da giriş hiç kaydedilmemiş). Pozitif stok toplamlarına girmez; "
             "fazlanın 'gerçek' karşılığı olabilir (ör. Sınav paket–parça kaydı). Mal olmayan kodlar burada yalnız bilgi için listelenir.", W)
    wb.close()
    return n


if __name__ == "__main__":
    os.makedirs(OUTD, exist_ok=True)
    for mk in SECIM:
        d, kat, ayr = hazirla(mk)
        p = os.path.join(OUTD, f"2026-10-14-stok-{MEKAN[mk].replace('.', '').replace(' ', '-')}.xlsx")
        n = kitap(mk, d, kat, ayr, p)
        d[["stk"] + PYV].to_csv(p.replace(".xlsx", ".python-degerleri.csv"), index=False, encoding="utf-8-sig")   # doğrulama referansı
        print(f"{MEKAN[mk]}: {n:,} ürün, ayrılan {len(ayr)} → {p}  · fazla {d.fazla_tl.sum():,.0f} TL · hareketsiz {d.loc[d.hareketsiz == 'Evet', 'stok_tl'].sum():,.0f} TL")
