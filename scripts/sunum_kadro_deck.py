# -*- coding: utf-8 -*-
"""Sezon 2026 kadro savunmasi -> BKM Kitap kurumsal sunumu (.pptx).

Cekirdek veri: briefings/sezon-kadro-20260902/verimlilik-veri.json (canli DB'den uretilir —
scripts/verimlilik_excel.py --cek). Bu dosya EMITTER: hesap YAPMAZ, veriyi okur ve slayta doker.

Marka: bkm-sunum skill sabitleri — sablon C:\\Users\\fikri.eren\\Desktop\\Sunum.pptx,
arka plan (kirmizi ikon-desenli bant + bkmkitap logosu) orijinal slaytlardan KOPYALANIR.
Palet yalniz kirmizi + gri (navy/teal/gokkusagi YASAK).

⚠ ICERIK KURALI: "1 Temmuz oncesi yonetim bende degildi" ifadesi YAZILMAZ. Yalniz TARIH CERCEVESI
kullanilir (taban 30.06 vs sezon 01.07-31.08) — rakam kendi hikayesini anlatir.
⚠ KVKK: kisi adi / personel no / ucret YOK; tum rakamlar toplulastirilmis.

Kullanim: python scripts/sunum_kadro_deck.py [cikti.pptx]
Varsayilan cikti: briefings/sezon-kadro-20260902/sunum-kadro-sezon2026.pptx
"""
import json
import os
import sys
import copy as _copy
from pathlib import Path

from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pptx.chart.data import CategoryChartData
from pptx.enum.chart import XL_CHART_TYPE, XL_LEGEND_POSITION, XL_MARKER_STYLE
from pptx.oxml.ns import qn
from pptx.opc.constants import RELATIONSHIP_TYPE as RT

try:   # Windows cp1254 konsolu: ok/uyari isaretleri UnicodeEncodeError veriyordu
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, OSError) as _e:
    print("stdout utf-8 yapilamadi: %s" % _e)

KOK = Path(__file__).resolve().parent.parent
VERI = KOK / "briefings" / "sezon-kadro-20260902" / "verimlilik-veri.json"
TPL = r"C:\Users\fikri.eren\Desktop\Sunum.pptx"
# varsayilan cikti BRIEF klasoru (repo icinde, veriyle ayni yerde). Masaustu icin yol argumani ver.
OUT = sys.argv[1] if len(sys.argv) > 1 else str(
    KOK / "briefings" / "sezon-kadro-20260902" / "sunum-kadro-sezon2026.pptx")
IKON = Path(os.path.expanduser("~")) / ".claude" / "skills" / "bkm-sunum" / "assets"
ICOW, ICOR = str(IKON / "_icons"), str(IKON / "_icons_red")

RED = RGBColor(0xE3, 0x06, 0x22); DRED = RGBColor(0xA6, 0x00, 0x1A); ROSE = RGBColor(0xC0, 0x14, 0x2B)
CHAR = RGBColor(0x2B, 0x2B, 0x2B); GREY = RGBColor(0x6E, 0x6E, 0x6E); LGREY = RGBColor(0xF2, 0xF2, 0xF2)
MGREY = RGBColor(0x9A, 0x9A, 0x9A); WHITE = RGBColor(0xFF, 0xFF, 0xFF); INK = RGBColor(0x33, 0x33, 0x33)
YESIL = RGBColor(0xA6, 0x00, 0x1A)   # marka: yesil YASAK -> "artis" rakami koyu kirmizi
SET = [RED, ROSE, RGBColor(0x7A, 0x10, 0x20), RGBColor(0x4A, 0x4A, 0x4A), RGBColor(0x8C, 0x8C, 0x8C)]

# ----------------------------------------------------------------- veri
ONCEKI, CARI = 2025, 2026        # kiyas yillari (verimlilik_excel.py ile ayni)
v = json.loads(VERI.read_text(encoding="utf-8"))
mag = {m["ad"]: m for m in v["magaza"]}
k5 = v["kadro_5magaza"]
gun = v["meta"]["gun"]
POS_SUBE = {"İST. YOLU": "İst. Yolu", "ÖZLÜCE": "Özlüce", "FSM": "FSM"}

# K-19: toplamlar CEKIRDEKTE hesaplanir (emitter-ayrimi); burada yeniden SUM edilmez.
if "toplam" not in v:
    sys.exit("VERİ ESKİ: JSON'da «toplam» bloğu yok. scripts/verimlilik_excel.py --cek ile yeniden üret.")
tpl_ = v["toplam"]
adet25, adet26 = tpl_["adet25"], tpl_["adet26"]
kh25, kh26 = tpl_["kdvharic25"], tpl_["kdvharic26"]
kd25, kd26 = tpl_["kdvdahil25"], tpl_["kdvdahil26"]
kadro25, kadro26 = tpl_["kadro25"], tpl_["kadro26"]

d_adet = adet26 / adet25 - 1
d_ciro = kd26 / kd25 - 1
d_kadro = kadro26 / kadro25 - 1
kb25, kb26 = adet25 / kadro25, adet26 / kadro26
d_kb = kb26 / kb25 - 1
kat = d_adet / d_kadro
taban_fark = k5["kadrolu_taban26"] - k5["kadrolu_taban25"]
# K-15: bolum grafigi 31.08 KESIM deltalarini gosterir; altindaki cumle taban (30.06) farkini
#   yaziyordu. Bugun ikisi de ayni ciktigi icin tutuyordu — olcuyu grafigin kaynagiyla esitle.
kesim_fark = k5["kadrolu_kesim26"] - k5["kadrolu_kesim25"]
sezon_ici_26 = k5["kadrolu_kesim26"] - k5["kadrolu_taban26"]
sezon_ici_25 = k5["kadrolu_kesim25"] - k5["kadrolu_taban25"]
oa = v["ocak_agustos"]
d_sinav = oa["sinav"]["kdvdahil26"] / oa["sinav"]["kdvdahil25"] - 1
d_mag_oa = oa["magaza"]["kdvdahil26"] / oa["magaza"]["kdvdahil25"] - 1

bolum = sorted(v["bolum"], key=lambda b: b["kadrolu26"] - b["kadrolu25"], reverse=True)
buyuyen = [b for b in bolum if b["kadrolu26"] - b["kadrolu25"] > 0]
sabit = [b for b in bolum if b["kadrolu26"] - b["kadrolu25"] == 0
         and b["bolum"] in ("MAĞAZA", "MAL KABUL", "İDARİ İŞLER")]


def tr_title(metin):
    """Turkce baslik-buyutme. Python .title() I->i, İ->i̇ bozar (KIRTASİYE -> Kirtasiye)."""
    kucuk = {"I": "ı", "İ": "i", "Ş": "ş", "Ğ": "ğ", "Ü": "ü", "Ö": "ö", "Ç": "ç"}
    out = []
    for kelime in metin.split():
        if kelime in ("FSM", "POS", "ERP", "KDV", "İK"):   # gercek kisaltmalar aynen kalir
            out.append(kelime)                             # ("MAL" gibi 3 harfli kelimeler DEGIL)
            continue
        ilk, kalan = kelime[0], kelime[1:]
        out.append(ilk + "".join(kucuk.get(ch, ch.lower()) for ch in kalan))
    return " ".join(out)


def bin(x, ondalik=0):
    s = ("{:,.%df}" % ondalik).format(x).replace(",", "·").replace(".", ",").replace("·", ".")
    return s


def yuzde(x, ondalik=1):
    return ("%+." + str(ondalik) + "f%%").replace("%%", "%") % (x * 100)


def yzd(x):   # "+%34,9" — Turkce yazim (isaret, yuzde, virgul)
    return ("+" if x >= 0 else "−") + "%" + ("%.1f" % abs(x * 100)).replace(".", ",")


# ----------------------------------------------------------------- iskele
pr = Presentation(TPL)
srcpr = Presentation(TPL)
TITLE_BG, CONTENT_BG = srcpr.slides[0], srcpr.slides[1]


def L(name):
    """Sablon layout'u. K-14: bulunamazsa SESSIZCE bos layout'a dusmez — cikar.

    Eski davranis: slide_layouts[6] (bos) donuyordu -> baslik placeholder'i olmayan slayt,
    setph() de None donup sessizce gecince BASLIKSIZ deste uretiliyordu.
    """
    for l in pr.slide_masters[0].slide_layouts:
        if l.name == name:
            return l
    sys.exit("ŞABLON LAYOUT BULUNAMADI: '%s'. Şablon (%s) değişmiş — mevcut layout'lar: %s"
             % (name, TPL, ", ".join(l.name for l in pr.slide_masters[0].slide_layouts)))


def copy_bg(src, dst):
    csrc = src._element.find(qn('p:cSld')); bg = csrc.find(qn('p:bg'))
    if bg is None:
        return
    bg2 = _copy.deepcopy(bg)
    for blip in bg2.iter(qn('a:blip')):
        rid = blip.get(qn('r:embed'))
        if not rid:
            continue
        nrid = dst.part.relate_to(src.part.related_part(rid), RT.IMAGE)
        blip.set(qn('r:embed'), nrid)
    dst._element.find(qn('p:cSld')).insert(0, bg2)


sld = pr.slides._sldIdLst
for sid in list(sld):
    try:
        pr.part.drop_rel(sid.get(qn('r:id')))
    except KeyError as e:      # iliski zaten yok — bilgi amacli, sessiz yutma yok
        print("  ⚠ şablon slayt ilişkisi bulunamadı, atlandı: %s" % e, flush=True)
    sld.remove(sid)


def add(name):
    sl = pr.slides.add_slide(L(name))
    copy_bg(TITLE_BG if name in ("Başlık Slaydı", "Bölüm Üst Bilgisi") else CONTENT_BG, sl)
    return sl


def setph(sl, idx, text):
    """Placeholder metni. Icerik slaytlarinda BASLIK KUTUSU SABITLENIR.

    ⚠ Yerlesim dersi (02.09.2026): sablonun "Yalnizca Baslik" layout'unda baslik placeholder'i
    y~0.3'ten y~2.5'e kadar uzuyor. Icerik y1.5'te basladigi icin kart/KPI kutulari basligin
    KUTUSUNUN icine giriyordu (gorsel olarak ust bant basligin altinda kaliyor). Cozum: icerik
    slaytlarinda baslik kutusu y0.30-1.30 arasina sabitlenir; icerik y1.45'ten sonra serbest.
    """
    for ph in sl.placeholders:
        if ph.placeholder_format.idx == idx:
            ph.text = text
            if idx == 0 and sl.slide_layout.name == "Yalnızca Başlık":
                ph.left, ph.top = Inches(0.6), Inches(0.30)
                ph.width, ph.height = Inches(12.05), Inches(1.00)
            return ph
    # K-14: placeholder yoksa basliksiz slayt uretilirdi (sessiz kayip) — cikar.
    sys.exit("PLACEHOLDER BULUNAMADI (idx=%d, layout '%s'): başlıksız slayt üretilmesin diye "
             "durduruldu. Metin: %s" % (idx, sl.slide_layout.name, text[:60]))


def tb(sl, x, y, w, h, runs, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, sp=1.0):
    bx = sl.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)); tf = bx.text_frame
    tf.word_wrap = True; tf.vertical_anchor = anchor
    if isinstance(runs, str):
        runs = [(runs, None, None, None)]
    first = True
    for txt, sz, bd, col in runs:
        p = tf.paragraphs[0] if first else tf.add_paragraph(); first = False
        p.alignment = align; p.line_spacing = sp
        r = p.add_run(); r.text = txt; r.font.size = Pt(sz or 13); r.font.bold = bool(bd)
        r.font.name = "Calibri"; r.font.color.rgb = col or INK
    return bx


def rrect(sl, x, y, w, h, fill, line=None, rad=True, lw=1):
    sh = sl.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rad else MSO_SHAPE.RECTANGLE,
                             Inches(x), Inches(y), Inches(w), Inches(h))
    sh.fill.solid(); sh.fill.fore_color.rgb = fill
    if line:
        sh.line.color.rgb = line; sh.line.width = Pt(lw)
    else:
        sh.line.fill.background()
    sh.shadow.inherit = False
    return sh


def circ(sl, x, y, d, bg, icon):
    c = sl.shapes.add_shape(MSO_SHAPE.OVAL, Inches(x), Inches(y), Inches(d), Inches(d))
    c.fill.solid(); c.fill.fore_color.rgb = bg; c.line.fill.background(); c.shadow.inherit = False
    ip = d * 0.55
    sl.shapes.add_picture(os.path.join(ICOW, icon + ".png"),
                          Inches(x + (d - ip) / 2), Inches(y + (d - ip) / 2), Inches(ip), Inches(ip))


def card(sl, x, y, w, h, top=None, ikon=None):
    """KART: KARE kenarli beyaz kutu + SOL dikey vurgu cubugu (+ opsiyonel ikon).

    ⚠ Tasarim gecmisi (02.09.2026): once yuvarlak kart + UST yatay serit denendi. Serit kare
    koseli oldugu icin yuvarlak kosenin disina tasti; ice alinca da kartin ustunde ayri bir
    cizgi gibi durdu ("kutular cizginin altina giriyor"). ÇOZUM: kart KARE kenar (rad=False),
    vurgu SOL dikeyde ve kartla tam ayni yukseklikte -> kose uyumsuzlugu MATEMATIKSEL OLARAK
    imkansiz. Yeni kart eklerken bu deseni bozma.
    """
    rrect(sl, x, y, w, h, WHITE, RGBColor(0xDC, 0xDC, 0xDC), rad=False)
    if top:
        rrect(sl, x, y, 0.075, h, top, rad=False)
    if ikon:
        sl.shapes.add_picture(os.path.join(ICOR, ikon + ".png"),
                              Inches(x + w - 0.52), Inches(y + 0.18), Inches(0.3), Inches(0.3))


def sig(sl):
    tb(sl, 9.3, 6.95, 3.4, 0.3, [("© Fikri Eren 2026", 9, False, MGREY)], align=PP_ALIGN.RIGHT)


PT = v["meta"]["pencere_tarih"]
DONEM_POS = "%s – %s (%d) · %s – %s (%d), her iki yıl %d gün, okul açılışına hizalı" % (
    PT[str(ONCEKI)][0][:5], PT[str(ONCEKI)][1], ONCEKI,
    PT[str(CARI)][0][:5], PT[str(CARI)][1], CARI, gun)
DONEM_OCA_AGU = "01.01 – 31.08 (her iki yıl, kümülatif)"
POS_ADLARI = "FSM · Özlüce · İst. Yolu"
BES_ADLARI = "FSM · Özlüce · İst. Yolu · Heykel · Şura"
DIP_POS = ("* Kapsam: üç POS mağazası — %s (Heykel ve Şura POS raporlamasında yok) · Dönem: %s"
           % (POS_ADLARI, DONEM_POS))
DIP_OCA_AGU = "* Kapsam: üç POS mağazası — %s · Dönem: %s" % (POS_ADLARI, DONEM_OCA_AGU)
DIP_BES = ("* Kapsam: beş mağazanın tamamı — %s · Ölçüm noktaları: 30.06 tabanı ve 31.08 kesimi "
           "(tarih aralığı değil, o gün fiilen çalışan kişi)" % BES_ADLARI)
DIP_KARMA = ("* Kadro: beş mağaza (%s), ölçüm noktaları 30.06 ve 31.08 · İş hacmi ve personel başına: "
             "üç POS mağazası (%s), dönem %s" % (BES_ADLARI, POS_ADLARI, DONEM_POS))


def dipnot(sl, metin):
    """Kapsam notu — LOGONUN SAGINDA (x2.1, y6.2). Her rakamli slaytta ZORUNLU.

    ⚠ Yerlesim dersi (02.09.2026): dipnot y6.02'de tam genislikteydi ve slayt-ozel alt notlarla
    (y5.6-5.95, sarma sonrasi 6.1-6.5'e uzayan) UST USTE BINIYORDU. Artik logo bandi hizasinda,
    logodan sonra basliyor: slayt icerigi y6.1'e kadar serbest.
    """
    tb(sl, 2.1, 6.2, 10.45, 0.62, [(metin, 8, False, MGREY)], sp=1.05)


def kpi(sl, x, y, w, etiket, deger, alt, renk=RED, buyuk=34, ikon=None):
    """KPI kutusu.

    ⚠ Yerlesim dersi (02.09.2026): etiket 2 satira sardiginda (uzun etiket, ör. "KADRO · UC POS
    MAGAZASI (SEZONLUK DAHIL)") ikinci satir DEGERIN uzerine biniyordu. Bloklar arasi mesafe
    artirildi, kutu 1.75 -> 2.0 buyudu, etiket puntosu 10 -> 9. Etiketi kisa tut (<= 28 karakter):
    ikinci satir icin yer var ama tercih tek satir.
    """
    card(sl, x, y, w, 2.0, renk, ikon=ikon)
    tb(sl, x + 0.28, y + 0.18, w - 0.95, 0.42, [(etiket, 9, True, GREY)], sp=1.05)
    tb(sl, x + 0.28, y + 0.66, w - 0.45, 0.72, [(deger, buyuk, True, renk)])
    tb(sl, x + 0.28, y + 1.44, w - 0.45, 0.5, [(alt, 10, False, GREY)], sp=1.05)


def cift_bar(sl, x, y, w, h, kategoriler, s25, s26, etiket25="2025", etiket26="2026",
             yuzde_etiket=False, sifirdan=False):
    cd = CategoryChartData(); cd.categories = kategoriler
    cd.add_series(etiket25, s25); cd.add_series(etiket26, s26)
    ch = sl.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(x), Inches(y),
                             Inches(w), Inches(h), cd).chart
    ch.has_title = False
    ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.TOP; ch.legend.include_in_layout = False
    ch.font.size = Pt(10); ch.font.name = "Calibri"
    pl = ch.plots[0]; pl.gap_width = 60; pl.has_data_labels = True
    pl.data_labels.number_format_is_linked = False
    pl.data_labels.number_format = '0.0"%"' if yuzde_etiket else '#,##0'
    pl.data_labels.font.size = Pt(9)
    ch.series[0].format.fill.solid(); ch.series[0].format.fill.fore_color.rgb = MGREY
    ch.series[1].format.fill.solid(); ch.series[1].format.fill.fore_color.rgb = RED
    if sifirdan:
        # ⚠ KESIK EKSEN YASAK: kadro grafiginde eksen 125'ten basliyordu, 139-153 farki
        # olcusuz buyuk gorunuyordu. Patron sunumunda "eksen kesik" itirazi acik hedef.
        ch.value_axis.minimum_scale = 0
    return ch


# ================================================================= 1 KAPAK
s = add("Başlık Slaydı")
setph(s, 0, "Kadro ve İş Hacmi Değerlendirmesi")
setph(s, 1, "Sezon 2026 · Mağazalar · kadro 30.06 ve 31.08 · iş hacmi %s – %s ile %s – %s"
            % (PT[str(ONCEKI)][0], PT[str(ONCEKI)][1], PT[str(CARI)][0], PT[str(CARI)][1]))

# ================================================================= 2 NORMA GORE DURUM (ILK MESAJ)
# Norm sunumun OMURGASI: patron "fazla eleman aldiniz" derken sirketin kendi norm tablosuna gore
# EKSIK calisiliyor. Bu yuzden kapaktan hemen sonra gelir; sonraki slaytlar bu cerceveye baglanir.
nrm0 = v.get("norm")
if nrm0:
    s = add("Yalnızca Başlık"); setph(s, 0, "Yönetici Özeti — Norma Göre Durum")
    tp0 = nrm0["toplam"]
    fark0 = tp0["toplam_kesim26"] - tp0["norm_toplam"]

    kpi(s, 0.6, 1.5, 3.9, "NORM · KADRO + SEZON", "%d" % tp0["norm_toplam"],
        "kadrolu %d + sezonluk %d · %s tarihli norm" % (tp0["norm"], tp0["norm_sezonluk"], nrm0["tarih"]),
        MGREY, 34, ikon="users")
    kpi(s, 4.68, 1.5, 3.9, "GERÇEK · 31 AĞUSTOS (OPERASYONEL)",
        "%d" % (tp0["kadrolu_kesim26"] - sum(a.get("etkinlik", 0) + a.get("engelli", 0)
                                             for a in nrm0.get("ayrik", {}).values())
                + tp0["sezonluk_kesim26"]),
        "engelli ve etkinlik norm dışı tutuldu", MGREY, 34, ikon="users")
    ayr0 = nrm0.get("ayrik", {})
    dis0 = sum(a.get("etkinlik", 0) + a.get("engelli", 0) for a in ayr0.values())
    kad_ops0 = tp0["kadrolu_kesim26"] - dis0
    fark0 = (kad_ops0 + tp0["sezonluk_kesim26"]) - tp0["norm_toplam"]
    kpi(s, 8.75, 1.5, 3.9, "NORMA GÖRE", "%+d kişi" % fark0,
        "kadrolu %+d · sezonluk %+d (engelli/etkinlik norm dışı)"
        % (kad_ops0 - tp0["norm"], tp0["sezonluk_kesim26"] - tp0["norm_sezonluk"]),
        DRED, 28, ikon="alert-triangle")

    rrect(s, 0.6, 3.62, 12.05, 0.82, LGREY, RED, lw=2)
    tb(s, 0.9, 3.62, 11.5, 0.82,
       [("Kadro fazlası yok: 31 Ağustos'ta toplam personel şirketin kendi norm tablosunun "
         "%d KİŞİ ALTINDADIR." % abs(fark0), 15, True, DRED)], align=PP_ALIGN.CENTER,
       anchor=MSO_ANCHOR.MIDDLE)

    card(s, 0.6, 4.52, 12.05, 1.22, RED, ikon="package")
    tb(s, 0.95, 4.64, 6.0, 0.3, [("AYNI DÖNEMDE İŞ HACMİ · ÜÇ POS MAĞAZASI", 9.5, True, GREY)])
    tb(s, 0.95, 4.98, 11.2, 0.68,
       [("ürün adedi %s (%s → %s) · ciro %s — eksik kadroyla üretildi"
         % (yzd(d_adet), bin(adet25), bin(adet26), yzd(d_ciro)), 14, True, DRED)])
    tb(s, 0.6, 5.82, 12.05, 0.26,
       [("Kadro farkı sezon ÖNCESİNDE oluştu (taban 30.06: %d → %d, %+d) · sezon içinde kadrolu %+d · "
         "personel başına iş %s · mağaza ve grup kırılımı detay slaytlarında."
         % (k5["kadrolu_taban25"], k5["kadrolu_taban26"], taban_fark, sezon_ici_26, yzd(d_kb)),
         9.5, False, GREY)])

    dipnot(s, "* Norm = ENGELLİ DIŞINDAKİ personel sayısı (yönetim kararı); etkinlik kadrosu da norm "
              "dışı — gerçek rakamdan düşüldü (engelli %d · etkinlik %d kişi). İK'nın kayıt toplamı "
              "kadrolu %d + sezonluk %d = %d · Norm kaynağı: BKMKİTAP Mağaza Kadro ve Sezon Takip "
              "Tablosu, %s · Kapsam: dört mağaza (Şura norm tablosunda yok) · İş hacmi üç POS mağazası."
           % (sum(a.get("engelli", 0) for a in ayr0.values()),
              sum(a.get("etkinlik", 0) for a in ayr0.values()),
              tp0["kadrolu_kesim26"], tp0["sezonluk_kesim26"], tp0["toplam_kesim26"], nrm0["tarih"]))
    sig(s)

# ================================================================= 5 KADRO AKISI
s = add("Yalnızca Başlık"); setph(s, 0, "Kadro Farkının Oluşum Dönemi")
akis = [("2025 tabanı", "%d" % k5["kadrolu_taban25"], "30 Haziran 2025", MGREY),
        ("Sezon öncesi eklenen", "%+d" % taban_fark, "1 Temmuz'dan önce", RED),
        ("2026 tabanı", "%d" % k5["kadrolu_taban26"], "30 Haziran 2026", MGREY),
        ("Sezon içi değişim", "%+d" % sezon_ici_26, "1 Tem – 31 Ağu", DRED),
        ("31 Ağustos 2026", "%d" % k5["kadrolu_kesim26"], "sezon zirvesi", MGREY)]
for i, (h, deger, alt, col) in enumerate(akis):
    x = 0.6 + i * 2.44
    card(s, x, 1.55, 2.28, 1.9, col)
    tb(s, x + 0.16, 1.68, 2.0, 0.5, [(h, 10.5, True, GREY)])
    tb(s, x + 0.16, 2.15, 2.0, 0.7, [(deger, 30, True, col)])
    tb(s, x + 0.16, 2.92, 2.0, 0.4, [(alt, 9.5, False, MGREY)])
    if i < 4:
        tb(s, x + 2.28, 2.2, 0.16, 0.4, [("›", 20, True, MGREY)], align=PP_ALIGN.CENTER)

cift_bar(s, 0.6, 3.7, 6.1, 2.05, ["Taban 30.06", "Kesim 31.08"],
         (k5["kadrolu_taban25"], k5["kadrolu_kesim25"]),
         (k5["kadrolu_taban26"], k5["kadrolu_kesim26"]), sifirdan=True)
rrect(s, 7.0, 3.8, 5.65, 1.75, LGREY, RED, lw=1.5)
tb(s, 7.25, 3.92, 5.2, 1.55,
   [("Sezon döneminde kadro artışı yoktur.", 15, True, DRED),
    ("Kadrolu personel %d → %d (%+d). Önceki yıl da aynı yönde (%+d): sezon döneminde alınan "
     "kadrolu personel ayrılanların yerine gelmiş, kadroyu büyütmemiştir."
     % (k5["kadrolu_taban26"], k5["kadrolu_kesim26"], sezon_ici_26, sezon_ici_25), 12, False, INK)], sp=1.15)
dipnot(s, DIP_BES)
sig(s)

# ================================================================= 6 BES MAGAZA TABLOSU
s = add("Yalnızca Başlık"); setph(s, 0, "Mağaza Bazında Kadro")
basliklar = ["Mağaza",
             "Kadrolu 30.06\n2025", "Kadrolu 30.06\n2026",
             "Kadrolu 31.08\n2025", "Kadrolu 31.08\n2026",
             "Sezon içi\n2025", "Sezon içi\n2026",
             "Sezonluk 31.08\n2025", "Sezonluk 31.08\n2026",
             "GENEL TOPLAM" + chr(10) + "31.08 · 2025", "GENEL TOPLAM" + chr(10) + "31.08 · 2026"]
satirlar = [basliklar]
for m in v["magaza_kadro"]:
    satirlar.append([tr_title(m["sube"]),
                     str(m["kadrolu_taban25"]), str(m["kadrolu_taban26"]),
                     str(m["kadrolu_kesim25"]), str(m["kadrolu_kesim26"]),
                     "%+d" % (m["kadrolu_kesim25"] - m["kadrolu_taban25"]),
                     "%+d" % (m["kadrolu_kesim26"] - m["kadrolu_taban26"]),
                     str(m["sezonluk_kesim25"]), str(m["sezonluk_kesim26"]),
                     str(m["kadrolu_kesim25"] + m["sezonluk_kesim25"]),
                     str(m["kadrolu_kesim26"] + m["sezonluk_kesim26"])])
satirlar.append(["TOPLAM",
                 str(k5["kadrolu_taban25"]), str(k5["kadrolu_taban26"]),
                 str(k5["kadrolu_kesim25"]), str(k5["kadrolu_kesim26"]),
                 "%+d" % sezon_ici_25, "%+d" % sezon_ici_26,
                 str(k5["sezonluk_kesim25"]), str(k5["sezonluk_kesim26"]),
                 str(k5["toplam_kesim25"]), str(k5["toplam_kesim26"])])
t = s.shapes.add_table(len(satirlar), 11, Inches(0.6), Inches(1.55), Inches(12.05), Inches(3.3)).table
for w, gen in zip(range(11), (1.55, 1.1, 1.1, 1.1, 1.1, 0.92, 0.92, 1.1, 1.1, 1.03, 1.03)):
    t.columns[w].width = Inches(gen)
t.rows[0].height = Inches(0.55)
for r, row in enumerate(satirlar):
    for c, val in enumerate(row):
        cell = t.cell(r, c); cell.text = val
        son_satir = (r == len(satirlar) - 1)
        for para in cell.text_frame.paragraphs:
            para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
            for run in para.runs:
                run.font.size = Pt(8.5 if r == 0 else 10.5)
                run.font.name = "Calibri"
                run.font.bold = (r == 0 or son_satir or c in (5, 6, 9, 10))
                run.font.color.rgb = WHITE if r == 0 else (DRED if c in (5, 6, 9, 10) else INK)
        cell.fill.solid()
        if r == 0:
            cell.fill.fore_color.rgb = RED
        elif son_satir:
            cell.fill.fore_color.rgb = LGREY
        elif c in (9, 10):
            cell.fill.fore_color.rgb = RGBColor(0xFD, 0xF2, 0xF3)   # genel toplam kolonu vurgusu
        else:
            cell.fill.fore_color.rgb = WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA)
pos_kadrolu = {y_: sum(m["kadrolu_kesim%d" % (y_ % 100)] for m in v["magaza_kadro"]
                       if m["sube"] in POS_SUBE) for y_ in (2025, 2026)}
pos_sezonluk = {y_: sum(m["sezonluk_kesim%d" % (y_ % 100)] for m in v["magaza_kadro"]
                        if m["sube"] in POS_SUBE) for y_ in (2025, 2026)}
rrect(s, 0.6, 4.95, 12.05, 0.75, LGREY, RED, lw=1.5)
tb(s, 0.85, 4.95, 11.6, 0.75,
   [("İŞ HACMİ KAPSAMI — üç POS mağazası (FSM · Özlüce · İst. Yolu): kadrolu %d → %d · sezonluk %d → %d · "
     "TOPLAM KADRO %d → %d.  Diğer slaytlardaki %d → %d kadro rakamı bu satırdır."
     % (pos_kadrolu[2025], pos_kadrolu[2026], pos_sezonluk[2025], pos_sezonluk[2026],
        pos_kadrolu[2025] + pos_sezonluk[2025], pos_kadrolu[2026] + pos_sezonluk[2026],
        pos_kadrolu[2025] + pos_sezonluk[2025], pos_kadrolu[2026] + pos_sezonluk[2026]),
     11.5, True, DRED)], anchor=MSO_ANCHOR.MIDDLE)
tb(s, 0.6, 5.78, 12.05, 0.3,
   [("Kadrolu = sezonluk dışı personel · Sezon içi = 31.08 kesimi ile 30.06 tabanı arasındaki değişim "
     "(her iki yılda da negatif: %+d ve %+d)." % (sezon_ici_25, sezon_ici_26), 10, False, GREY)], sp=1.15)
dipnot(s, DIP_BES + " İş hacmi kapsamı üç POS mağazasıdır (%s)." % POS_ADLARI)
sig(s)

# ================================================================= 8 IS HACMI
s = add("Yalnızca Başlık"); setph(s, 0, "Dönem İş Hacmi")
kpi(s, 0.6, 1.5, 3.9, "ELLEÇLENEN ÜRÜN", yzd(d_adet), "%s → %s adet" % (bin(adet25), bin(adet26)),
    YESIL, 32, ikon="package")
kpi(s, 4.68, 1.5, 3.9, "CİRO · KDV DAHİL", yzd(d_ciro),
    "%s → %s milyon TL" % (bin(kd25 / 1e6, 1), bin(kd26 / 1e6, 1)), YESIL, 32, ikon="layers")
kpi(s, 8.75, 1.5, 3.9, "KADRO · 3 MAĞAZA", yzd(d_kadro),
    "%d → %d kişi (sezonluk dahil)" % (kadro25, kadro26), MGREY, 32, ikon="users")

cift_bar(s, 0.6, 3.5, 6.1, 2.15, ["Ürün adedi (bin)", "Ciro (milyon TL)", "Kadro (kişi)"],
         (adet25 / 1000, kd25 / 1e6, kadro25), (adet26 / 1000, kd26 / 1e6, kadro26))
rrect(s, 7.0, 3.7, 5.65, 2.0, LGREY, RED, lw=1.5)
tb(s, 7.25, 3.85, 5.2, 1.75,
   [("Ürün adedi birincil ölçüdür", 14, True, DRED),
    ("Adet enflasyondan etkilenmez; kasadan geçen, rafa dizilen ve depodan çıkan fiili mal "
     "miktarını gösterir. Ciro fiyat artışını içerir, adet içermez.", 12, False, INK)], sp=1.15)
tb(s, 0.6, 5.72, 12.05, 0.32,
   [("Kaynak: DerinSIS mağaza satışı · Sınav hariç · iadeler düşülmüş · KDV dahil.", 10, False, MGREY)])
dipnot(s, DIP_POS)
sig(s)

# ================================================================= 9 KISI BASI MAGAZA
s = add("Yalnızca Başlık"); setph(s, 0, "Personel Başına İş Hacmi — Okul-Hizalı Pencere")
kats, s1, s2 = [], [], []
for ad in ("Özlüce", "İst. Yolu", "FSM"):
    m = mag[ad]
    kats.append(ad); s1.append(m["adet25"] / m["kadro25"]); s2.append(m["adet26"] / m["kadro26"])
cift_bar(s, 0.6, 1.6, 6.3, 3.9, kats, tuple(s1), tuple(s2))
y = 1.75
for ad, a, b in zip(kats, s1, s2):
    card(s, 7.2, y, 5.45, 1.15, RED)
    tb(s, 7.45, y + 0.12, 3.0, 0.35, [(ad, 13, True, CHAR)])
    tb(s, 7.45, y + 0.5, 3.05, 0.5,
       [("%s → %s adet/kişi" % (bin(a), bin(b)), 12.5, False, INK)])
    tb(s, 10.7, y + 0.12, 1.85, 0.5, [(yzd(b / a - 1), 17, True, YESIL)], align=PP_ALIGN.RIGHT)
    y += 1.3
tb(s, 0.6, 5.68, 12.05, 0.34,
   [("Kişi başı = 31 Ağustos'ta o mağazada fiilen çalışan TÜM personel (sezonluk dahil). Kadrosu en çok "
     "büyüyen mağazada dahi kişi başı iş artmıştır (İst. Yolu %d → %d)."
     % (mag["İst. Yolu"]["kadro25"], mag["İst. Yolu"]["kadro26"]), 9.5, False, GREY)])
dipnot(s, DIP_POS)
sig(s)

# ================================================================= 10 4 YILLIK TREND
# K-16: bu slayt Oca-Agu adedini KADROLU'ya bolerken onceki slayt hizali-pencere adedini TUM
#   kadroya boluyor — iki farkli olcek. Basliklarda ve etiketlerde olcu ADIYLA yazilir.
s = add("Yalnızca Başlık")
setph(s, 0, "Dört Yıllık Seyir — Ocak-Ağustos Adedi / Kadrolu")
cd = CategoryChartData(); cd.categories = [str(y_["yil"]) for y_ in v["yillar"]]
cd.add_series("Oca-Ağu adet ÷ kadrolu", tuple(y_["adet"] / y_["kadrolu"] for y_ in v["yillar"]))
lc = s.shapes.add_chart(XL_CHART_TYPE.LINE_MARKERS, Inches(0.6), Inches(1.6),
                        Inches(7.2), Inches(3.9), cd).chart
lc.has_title = False; lc.has_legend = False
lc.font.size = Pt(11); lc.font.name = "Calibri"
lc.plots[0].has_data_labels = True
lc.plots[0].data_labels.number_format_is_linked = False
lc.plots[0].data_labels.number_format = '#,##0'
lc.plots[0].data_labels.font.size = Pt(10)
ser = lc.series[0]; ser.format.line.color.rgb = RED; ser.format.line.width = Pt(2.5)
ser.smooth = False
# marka: varsayilan mavi baklava isaretci YASAK -> kirmizi daire
ser.marker.style = XL_MARKER_STYLE.CIRCLE
ser.marker.size = 7
ser.marker.format.fill.solid(); ser.marker.format.fill.fore_color.rgb = RED
ser.marker.format.line.color.rgb = WHITE

# K-10: bu ucu ONCE elle yazilmisti (60 -> 91, +%11, +%28,8). JSON yenilenince bayatlardi;
#   artik v["yillar"]'dan turetilir.
_yl = {y_["yil"]: y_ for y_ in v["yillar"]}
_yrs = sorted(_yl)
_atl_o, _atl_y = max(zip(_yrs, _yrs[1:]),
                     key=lambda p: _yl[p[1]]["kadrolu"] - _yl[p[0]]["kadrolu"])
_kb = {y_: _yl[y_]["adet"] / _yl[y_]["kadrolu"] for y_ in _yrs}
notlar = [("%d'te kadro atladı" % _atl_y,
           "Kadrolu %d → %d. Adet yalnız %s arttı → kişi başı iş %s."
           % (_yl[_atl_o]["kadrolu"], _yl[_atl_y]["kadrolu"],
              yzd(_yl[_atl_y]["adet"] / _yl[_atl_o]["adet"] - 1),
              "düştü" if _kb[_atl_y] < _kb[_atl_o] else "arttı"), DRED),
          ("Ama %d 'norm' değil" % _atl_o,
           "O yıl FSM kasada 0, Özlüce kasada 1 kişi vardı — eksik kadroyla çalışma.", GREY),
          ("%d → %d toparlanma" % (_atl_y, _yrs[-1]),
           "Kişi başı iş %s arttı; bu yıl kadro büyürken verim de arttı."
           % yzd(_kb[_yrs[-1]] / _kb[_atl_y] - 1), RED)]
y = 1.75
for h, d, col in notlar:
    card(s, 8.1, y, 4.55, 1.2, col)
    tb(s, 8.35, y + 0.12, 4.05, 0.35, [(h, 12.5, True, CHAR)])
    tb(s, 8.35, y + 0.48, 4.05, 0.7, [(d, 10.5, False, GREY)])
    y += 1.35
tb(s, 0.6, 5.65, 12.05, 0.5,
   [("Ölçü: Ocak–Ağustos ürün adedi ÷ 31.08 kadrolu (sezonluk HARİÇ; yıllar arası sezonluk "
     "zamanlaması kıyası bozar). «Okul-hizalı pencere ÷ TÜM kadro» ölçüsü ayrı slayttadır — iki "
     "ölçünün seviyeleri karşılaştırılmaz, yönleri karşılaştırılır.", 10, False, MGREY)])
dipnot(s, DIP_OCA_AGU + " · kadro: 31.08 kesimi, her yıl")
sig(s)

# ================================================================= 12 BOLUM KIRILIMI
s = add("Yalnızca Başlık"); setph(s, 0, "Bölüm Bazında Kadro Değişimi")
ilk5 = buyuyen[:5]
cd = CategoryChartData()
cd.categories = [tr_title(b["bolum"]) for b in ilk5] + [tr_title(b["bolum"]) for b in sabit]
cd.add_series("kadrolu değişim (kişi)",
              tuple([b["kadrolu26"] - b["kadrolu25"] for b in ilk5] + [0 for _ in sabit]))
bc = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(1.6),
                        Inches(7.2), Inches(3.6), cd).chart
bc.has_title = False; bc.has_legend = False
bc.font.size = Pt(10.5); bc.font.name = "Calibri"
bc.plots[0].has_data_labels = True; bc.plots[0].gap_width = 60
bc.plots[0].data_labels.number_format_is_linked = False
bc.plots[0].data_labels.number_format = '+0;-0;0'
bc.series[0].format.fill.solid(); bc.series[0].format.fill.fore_color.rgb = RED
bc.plots[0].vary_by_categories = False

card(s, 8.1, 1.6, 4.55, 1.75, MGREY)
tb(s, 8.35, 1.72, 4.05, 0.35, [("KADROSU DEĞİŞMEYEN BÖLÜMLER", 10.5, True, GREY)])
tb(s, 8.35, 2.08, 4.05, 1.2,
   [("  ·  ".join("%s +0" % tr_title(b["bolum"]) for b in sabit) or "—", 13, True, CHAR),
    ("Bu %d bölümde kadro değişimi sıfırdır." % len(sabit), 10.5, False, GREY)], sp=1.15)
card(s, 8.1, 3.5, 4.55, 1.7, RED)
tb(s, 8.35, 3.62, 4.05, 0.35, [("KADROSU ARTAN BÖLÜMLER", 10.5, True, GREY)])
tb(s, 8.35, 3.98, 4.05, 1.15,
   [("  ·  ".join("%s %+d" % (tr_title(b["bolum"]), b["kadrolu26"] - b["kadrolu25"]) for b in ilk5),
     12, True, DRED)], sp=1.15)
rrect(s, 0.6, 5.28, 12.05, 0.72, LGREY, RED, lw=1.5)
tb(s, 0.9, 5.28, 11.5, 0.72,
   [("31 Ağustos kesiminde kadrolu %+d kişilik artışın tamamı satış ve kasa bölümlerindedir; "
     "yönetim kadrosunda değişim yoktur." % kesim_fark, 13.5, True, DRED)],
   anchor=MSO_ANCHOR.MIDDLE)
dipnot(s, DIP_BES)
sig(s)

# ================================================================= 12c MAGAZA PERFORMANS
s = add("Yalnızca Başlık"); setph(s, 0, "Mağaza Performans Karşılaştırması")
perf = [["Mağaza", "Kadro 31.08", "Kadro Δ", "Ürün adedi Δ", "Ciro Δ", "Adet/kişi Δ", "İş ÷ kadro"]]
for ad in ("Özlüce", "İst. Yolu", "FSM"):
    m = mag[ad]
    dk = m["kadro26"] / m["kadro25"] - 1
    da = m["adet26"] / m["adet25"] - 1
    dc = m["kdvdahil26"] / m["kdvdahil25"] - 1
    dkb = (m["adet26"] / m["kadro26"]) / (m["adet25"] / m["kadro25"]) - 1
    perf.append([ad, "%d → %d" % (m["kadro25"], m["kadro26"]), yzd(dk), yzd(da), yzd(dc), yzd(dkb),
                 ("%.1f" % (da / dk)).replace(".", ",") + "x"])
perf.append(["TOPLAM", "%d → %d" % (kadro25, kadro26), yzd(d_kadro), yzd(d_adet), yzd(d_ciro),
             yzd(d_kb), ("%.1f" % kat).replace(".", ",") + "x"])

# K-10: "en cok kadro ekleyen magazada dahi oran X kat" cumlesi elle yaziliydi (2,2) — turetilir.
_en_kadro = max(("Özlüce", "İst. Yolu", "FSM"),
                key=lambda a: mag[a]["kadro26"] / mag[a]["kadro25"] - 1)
_m = mag[_en_kadro]
_en_kadro_oran = ("%.1f" % ((_m["adet26"] / _m["adet25"] - 1)
                            / (_m["kadro26"] / _m["kadro25"] - 1))).replace(".", ",")

t = s.shapes.add_table(len(perf), 7, Inches(0.6), Inches(1.5), Inches(12.05), Inches(1.9)).table
for i, gen in enumerate((2.2, 1.9, 1.5, 1.85, 1.5, 1.7, 1.4)):
    t.columns[i].width = Inches(gen)
for r, row in enumerate(perf):
    for c, val in enumerate(row):
        cell = t.cell(r, c); cell.text = val
        son = (r == len(perf) - 1)
        for para in cell.text_frame.paragraphs:
            para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
            for run in para.runs:
                run.font.size = Pt(11.5); run.font.name = "Calibri"
                run.font.bold = (r == 0 or son or c == 6)
                run.font.color.rgb = WHITE if r == 0 else (YESIL if c in (3, 4, 5) and r > 0 else INK)
        cell.fill.solid()
        cell.fill.fore_color.rgb = RED if r == 0 else (LGREY if son else WHITE)

kats2 = ["Özlüce", "İst. Yolu", "FSM"]
cift_bar(s, 0.6, 3.6, 6.1, 2.3, kats2,
         tuple(0.0 for _ in kats2), tuple(0.0 for _ in kats2))  # yer tutucu, altta degistirilir
s.shapes[-1]._element.getparent().remove(s.shapes[-1]._element)  # yer tutucuyu kaldir
cd = CategoryChartData(); cd.categories = kats2
cd.add_series("kadro Δ%", tuple((mag[a]["kadro26"] / mag[a]["kadro25"] - 1) * 100 for a in kats2))
cd.add_series("ürün adedi Δ%", tuple((mag[a]["adet26"] / mag[a]["adet25"] - 1) * 100 for a in kats2))
cd.add_series("ciro Δ%", tuple((mag[a]["kdvdahil26"] / mag[a]["kdvdahil25"] - 1) * 100 for a in kats2))
ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(3.6),
                        Inches(7.4), Inches(2.35), cd).chart
ch.has_title = False
ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.TOP; ch.legend.include_in_layout = False
ch.font.size = Pt(9.5); ch.font.name = "Calibri"
ch.plots[0].gap_width = 60; ch.plots[0].has_data_labels = True
ch.plots[0].data_labels.number_format_is_linked = False
ch.plots[0].data_labels.number_format = '0"%"'
ch.plots[0].data_labels.font.size = Pt(8.5)
for i, col in enumerate((MGREY, RED, RGBColor(0x7A, 0x10, 0x20))):
    ch.series[i].format.fill.solid(); ch.series[i].format.fill.fore_color.rgb = col

rrect(s, 8.2, 3.8, 4.45, 1.95, LGREY, RED, lw=1.5)
tb(s, 8.45, 3.95, 4.0, 1.7,
   [("Değerlendirme", 13.5, True, DRED),
    ("Üç mağazanın tamamında iş hacmi artışı kadro artışının üzerindedir. Kadro artışı en yüksek "
     "olan %s mağazasında dahi oran %s katıdır." % (_en_kadro, _en_kadro_oran), 11.5, False, INK)], sp=1.15)
dipnot(s, DIP_POS)
sig(s)

# ================================================================= 12d KATEGORI x BOLUM ESLESME
s = add("Yalnızca Başlık"); setph(s, 0, "Kategori Büyümesi ve İlgili Bölüm Kadrosu")
ESLES = {"Hazırlık Kitapları": "YARDIMCI KİTAP", "Kırtasiye": "KIRTASİYE", "Kitap": "KÜLTÜR",
         "Çocuk Kitabı": "ÇOCUK", "Oyuncak": "OYUNCAK", "Akademi": "AKADEMİ"}
kadro_delta = {b["bolum"]: b["kadrolu26"] - b["kadrolu25"] for b in v["bolum"]}
kat_veri = [k for k in v["kategori"] if k["kategori"] in ESLES]
kat_veri.sort(key=lambda k: -kadro_delta.get(ESLES[k["kategori"]], 0))
# K-13: tabloda YALNIZ bolum eslesmesi olan kategoriler var; geri kalanlar (Genel, Hediyelik,
#   Kisisel Bakim...) gorunmuyordu -> "kadro en hizli buyuyene gitti" iddiasi denetlenemiyordu.
#   Kalanlar tek "DIGER" satirinda toplanir + kapsam yuzdesi dipnota yazilir.
_dis = [k for k in v["kategori"] if k["kategori"] not in ESLES]
_tum25 = sum(k["adet25"] for k in v["kategori"]) or 1
_tum26 = sum(k["adet26"] for k in v["kategori"]) or 1
_kaps26 = sum(k["adet26"] for k in kat_veri)
_kapsam_yzd = ("%%%.0f" % (100.0 * _kaps26 / _tum26))

NL = chr(10)
satir = [["Kategori", "Bakan bölüm", "Ürün adedi 2025 → 2026",
          "SEZON" + NL + "adet Δ", "SEZON" + NL + "ciro Δ",
          "OCA-AĞU" + NL + "adet Δ", "OCA-AĞU" + NL + "ciro Δ",
          "Bölüm" + NL + "kadro Δ"]]
for k in kat_veri:
    b = ESLES[k["kategori"]]
    oa_adet = yzd(k["oa_adet26"] / k["oa_adet25"] - 1) if k.get("oa_adet25") else "—"
    oa_ciro = yzd(k["oa_ciro26"] / k["oa_ciro25"] - 1) if k.get("oa_ciro25") else "—"
    satir.append([k["kategori"], tr_title(b),
                  "%s → %s" % (bin(k["adet25"]), bin(k["adet26"])),
                  yzd(k["adet26"] / k["adet25"] - 1),
                  yzd(k["ciro26"] / k["ciro25"] - 1),
                  oa_adet, oa_ciro,
                  "%+d kişi" % kadro_delta.get(b, 0)])
if _dis:
    _d25, _d26 = sum(k["adet25"] for k in _dis), sum(k["adet26"] for k in _dis)
    _dc25, _dc26 = sum(k["ciro25"] for k in _dis), sum(k["ciro26"] for k in _dis)
    _doa25, _doa26 = (sum(k.get("oa_adet25") or 0 for k in _dis),
                      sum(k.get("oa_adet26") or 0 for k in _dis))
    _doc25, _doc26 = (sum(k.get("oa_ciro25") or 0 for k in _dis),
                      sum(k.get("oa_ciro26") or 0 for k in _dis))
    satir.append(["DİĞER (%d kategori)" % len(_dis), "bölüm eşleşmesi yok",
                  "%s → %s" % (bin(_d25), bin(_d26)),
                  yzd(_d26 / _d25 - 1) if _d25 else "—",
                  yzd(_dc26 / _dc25 - 1) if _dc25 else "—",
                  yzd(_doa26 / _doa25 - 1) if _doa25 else "—",
                  yzd(_doc26 / _doc25 - 1) if _doc25 else "—", "—"])
t = s.shapes.add_table(len(satir), 8, Inches(0.6), Inches(1.5), Inches(12.05), Inches(2.7)).table
for i, gen in enumerate((2.15, 1.75, 2.35, 1.2, 1.15, 1.25, 1.15, 1.05)):
    t.columns[i].width = Inches(gen)
t.rows[0].height = Inches(0.5)
for r, row in enumerate(satir):
    for c, val in enumerate(row):
        cell = t.cell(r, c); cell.text = val
        for para in cell.text_frame.paragraphs:
            para.alignment = PP_ALIGN.LEFT if c <= 1 else PP_ALIGN.CENTER
            for run in para.runs:
                run.font.size = Pt(11.5); run.font.name = "Calibri"
                run.font.bold = (r == 0 or c in (3, 4, 5))
                run.font.color.rgb = WHITE if r == 0 else (DRED if c in (3, 4) else INK)
        cell.fill.solid()
        cell.fill.fore_color.rgb = RED if r == 0 else (LGREY if r % 2 == 0 else WHITE)

kats3 = [k["kategori"] for k in kat_veri]
# tek seri: adet buyumesi (kadro Δ tabloda — ayni grafikte olcek farki cubuklari yok ediyordu)
cd = CategoryChartData(); cd.categories = kats3
cd.add_series("ürün adedi Δ%", tuple((k["adet26"] / k["adet25"] - 1) * 100 for k in kat_veri))
ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(4.62),
                        Inches(7.4), Inches(1.42), cd).chart
ch.has_title = False; ch.has_legend = False
ch.font.size = Pt(9); ch.font.name = "Calibri"
ch.plots[0].gap_width = 70; ch.plots[0].has_data_labels = True
ch.plots[0].vary_by_categories = False
ch.plots[0].data_labels.number_format_is_linked = False
ch.plots[0].data_labels.number_format = '0"%"'
ch.plots[0].data_labels.font.size = Pt(8.5)
ch.series[0].format.fill.solid(); ch.series[0].format.fill.fore_color.rgb = RED
tb(s, 0.6, 4.34, 7.4, 0.26, [("Ürün adedi büyümesi (%) — kategori bazında", 10, True, GREY)])

rrect(s, 8.2, 4.42, 4.45, 1.62, LGREY, RED, lw=1.5)
tb(s, 8.45, 4.5, 4.0, 1.48,
   [("Değerlendirme", 13.5, True, DRED),
    ("Kadro artışı, ürün adedi en hızlı artan kategorilere yönlendirilmiştir. SEZON kolonları "
     "okul-hizalı pencereyi, OCA-AĞU kolonları yılın tamamını (01.01–31.08) gösterir; sıralama "
     "iki pencerede de aynıdır. DİĞER satırı, tek bir reyona atfedilemeyen kategorilerin "
     "toplamıdır (kadro eşleşmesi yapılamaz); kapsam bütünlüğü için gösterilir.",
     10, False, INK)], sp=1.12)
dipnot(s, DIP_POS + " · OCA-AĞU kolonları: 01.01 – 31.08 kümülatif (her iki yıl) · Bölüm "
          "eşleşmesi olan %d kategori ayrı satırda = hizalı pencere adedinin %s'i; kalan %d "
          "kategori DİĞER satırında toplandı (eşik: iki yılda da ≥2.000 adet)"
          % (len(kat_veri), _kapsam_yzd, len(_dis)))

# ================================================================= TAKVIM KAYMASI
ky = v.get("kayma")
if ky:
    s = add("Yalnızca Başlık"); setph(s, 0, "Takvim Kayması: Ağustos ve Eylül")
    h = ky["hizali_buyume"]
    dg = ky["eylul_dalga_beklentisi"]
    ay_adet_d = ky["y26_agu_tam"]["adet"] / ky["y25_agu_tam"]["adet"] - 1

    kpi(s, 0.6, 1.5, 3.9, "AĞUSTOS · GERÇEK", yzd(ay_adet_d),
        "%s → %s adet" % (bin(ky["y25_agu_tam"]["adet"]), bin(ky["y26_agu_tam"]["adet"])),
        MGREY, 30, ikon="workflow")
    kpi(s, 4.68, 1.5, 3.9, "AĞUSTOS · KAYMASIZ", bin(ky["agustos_kaymasiz_tahmin"]["adet"]),
        "adet tahmini · %s M TL" % bin(ky["agustos_kaymasiz_tahmin"]["ciro"] / 1e6, 1), DRED, 26,
        ikon="rocket")
    kpi(s, 8.75, 1.5, 3.9, "EYLÜL'E KAYAN", bin(ky["eylule_kayan"]["adet"]),
        "adet · %s M TL" % bin(ky["eylule_kayan"]["ciro"] / 1e6, 1), DRED, 26, ikon="workflow")

    cd = CategoryChartData(); cd.categories = ["Ağustos (adet, bin)"]
    cd.add_series("2025 gerçekleşen", (ky["y25_agu_tam"]["adet"] / 1000,))
    cd.add_series("2026 gerçekleşen", (ky["y26_agu_tam"]["adet"] / 1000,))
    cd.add_series("2026 kayma olmasaydı", (ky["agustos_kaymasiz_tahmin"]["adet"] / 1000,))
    ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(3.5),
                            Inches(6.1), Inches(2.35), cd).chart
    ch.has_title = False
    ch.has_legend = True; ch.legend.position = XL_LEGEND_POSITION.TOP; ch.legend.include_in_layout = False
    ch.font.size = Pt(9.5); ch.font.name = "Calibri"
    ch.plots[0].gap_width = 80; ch.plots[0].has_data_labels = True
    ch.plots[0].data_labels.number_format_is_linked = False
    ch.plots[0].data_labels.number_format = '#,##0'
    ch.plots[0].data_labels.font.size = Pt(9)
    for i, col in enumerate((MGREY, RED, RGBColor(0x7A, 0x10, 0x20))):
        ch.series[i].format.fill.solid(); ch.series[i].format.fill.fore_color.rgb = col

    rrect(s, 7.0, 3.6, 5.65, 2.15, LGREY, RED, lw=1.5)
    tb(s, 7.25, 3.72, 5.2, 1.95,
       [("Eylül'de beklenen dalga", 13.5, True, DRED),
        ("2025'te okul öncesi alış dalgası %s aralığındaydı: %s adet · %s M TL. Aynı dalga 2026'da "
         "%s aralığına denk geliyor; hizalı büyüme oranıyla %s adet · %s M TL beklenmektedir."
         % (dg["pencere_2025"], bin(dg["adet_2025"]), bin(dg["ciro_2025"] / 1e6, 1),
            dg["pencere_2026"], bin(dg["adet_2026_tahmin"]), bin(dg["ciro_2026_tahmin"] / 1e6, 1)),
         11, False, INK)], sp=1.15)

    dipnot(s, "* Kapsam: üç POS mağazası — %s · Hizalı pencere %s ile %s (%d gün; bugün hariç, son tam "
              "gün %s) · Tahmin yöntemi: hizalı büyüme %s, talep kaybı olmadığı varsayımıyla."
           % (POS_ADLARI, h["pencere_2025"], h["pencere_2026"], h["gun"], h["son_tam_gun"],
              yzd(h["adet"])))
    sig(s)

# ================================================================= NORM KADRO
nrm = v.get("norm")
if nrm:
    s = add("Yalnızca Başlık"); setph(s, 0, "Norm Kadro — Mağaza Detayı")
    tp = nrm["toplam"]
    fark_kesim = tp["kadrolu_kesim26"] - tp["norm"]
    fark_taban = tp["kadrolu_taban26"] - tp["norm"]

    acik_toplam = sum(max(0, r["norm"] - r["kadrolu_kesim26"]) for r in nrm["sube"])
    toplam_fark = tp["toplam_kesim26"] - tp["norm_toplam"]
    tb(s, 0.6, 1.5, 12.05, 0.34,
       [("Norm %d (kadrolu %d + sezonluk %d) · operasyonel gerçek %d (kadrolu %d + sezonluk %d) · "
         "fark %+d kişi — engelli ve etkinlik norm dışı tutuldu."
         % (tp["norm_toplam"], tp["norm"], tp["norm_sezonluk"],
            tp["kadrolu_kesim26"] - sum(a.get("etkinlik", 0) + a.get("engelli", 0)
                                        for a in nrm.get("ayrik", {}).values()) + tp["sezonluk_kesim26"],
            tp["kadrolu_kesim26"] - sum(a.get("etkinlik", 0) + a.get("engelli", 0)
                                        for a in nrm.get("ayrik", {}).values()),
            tp["sezonluk_kesim26"],
            (tp["kadrolu_kesim26"] - sum(a.get("etkinlik", 0) + a.get("engelli", 0)
                                         for a in nrm.get("ayrik", {}).values())
             + tp["sezonluk_kesim26"]) - tp["norm_toplam"]), 11.5, True, DRED)])

    NL2 = chr(10)
    ayr = nrm.get("ayrik", {})
    etk_top = sum(a.get("etkinlik", 0) for a in ayr.values())
    eng_top = sum(a.get("engelli", 0) for a in ayr.values())
    satir = [["Mağaza / Grup",
              "Norm" + NL2 + "kadrolu", "Gerçek" + NL2 + "kadrolu", "Fark",
              "Norm" + NL2 + "sezonluk", "Gerçek" + NL2 + "sezonluk", "Fark",
              "NORM" + NL2 + "TOPLAM", "GERÇEK" + NL2 + "TOPLAM", "FARK"]]
    # ⚠ KARAR (yonetim): ENGELLI ve ETKINLIK NORM DISIDIR -> norm dolulugu hesabinda gercek
    #   kadroludan DUSULUR. (Norm tablosunun "engelli dahil" notu bu kararla gecersiz.)
    for r in nrm["sube"]:
        a_ = ayr.get(r["sube"], {})
        etk, eng = a_.get("etkinlik", 0), a_.get("engelli", 0)
        kad = r["kadrolu_kesim26"] - etk - eng
        top = kad + r["sezonluk_kesim26"]
        satir.append([tr_title(r["sube"]),
                      str(r["norm"]), str(kad), "%+d" % (kad - r["norm"]),
                      str(r["norm_sezonluk"]), str(r["sezonluk_kesim26"]),
                      "%+d" % (r["sezonluk_kesim26"] - r["norm_sezonluk"]),
                      str(r["norm_toplam"]), str(top), "%+d" % (top - r["norm_toplam"])])
    kad_ops = tp["kadrolu_kesim26"] - etk_top - eng_top
    # AYRI SATIRLAR
    satir.append(["Etkinlik (norm dışı)", "—", str(etk_top), "—",
                  "—", "0", "—", "—", str(etk_top), "—"])
    satir.append(["Engelli ** (norm dışı)", "—", str(eng_top), "—",
                  "—", "0", "—", "—", str(eng_top), "—"])
    satir.append(["OPERASYONEL TOPLAM", str(tp["norm"]), str(kad_ops),
                  "%+d" % (kad_ops - tp["norm"]),
                  str(tp["norm_sezonluk"]), str(tp["sezonluk_kesim26"]),
                  "%+d" % (tp["sezonluk_kesim26"] - tp["norm_sezonluk"]),
                  str(tp["norm_toplam"]), str(kad_ops + tp["sezonluk_kesim26"]),
                  "%+d" % (kad_ops + tp["sezonluk_kesim26"] - tp["norm_toplam"])])
    satir.append(["Kayıt toplamı (İK, tüm gruplar)", "—", str(tp["kadrolu_kesim26"]), "—",
                  "—", str(tp["sezonluk_kesim26"]), "—",
                  "—", str(tp["toplam_kesim26"]), "—"])

    t = s.shapes.add_table(len(satir), 10, Inches(0.6), Inches(1.98), Inches(12.05), Inches(1.9)).table
    for i, gen in enumerate((2.35, 1.02, 1.08, 0.82, 1.05, 1.14, 0.82, 1.15, 1.25, 0.82)):
        t.columns[i].width = Inches(gen)
    t.rows[0].height = Inches(0.38)
    for r_ in list(t.rows)[1:]:
        r_.height = Inches(0.2)
    ozet_satirlar = (len(satir) - 2,)                     # OPERASYONEL TOPLAM (asil kiyas)
    ayri_satirlar = (len(satir) - 4, len(satir) - 3, len(satir) - 1)   # norm disi gruplar + kayit toplami
    for r, row in enumerate(satir):
        for c, val in enumerate(row):
            cell = t.cell(r, c); cell.text = val
            for para in cell.text_frame.paragraphs:
                para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
                for run in para.runs:
                    run.font.size = Pt(7.5 if r == 0 else 9)
                    run.font.name = "Calibri"
                    run.font.bold = (r == 0 or r in ozet_satirlar or c in (3, 6, 9))
                    run.font.color.rgb = WHITE if r == 0 else (DRED if c in (3, 6, 9) else INK)
            cell.fill.solid()
            if r == 0:
                cell.fill.fore_color.rgb = RED
            elif r in ozet_satirlar:
                cell.fill.fore_color.rgb = LGREY
            elif r in ayri_satirlar:
                cell.fill.fore_color.rgb = RGBColor(0xFF, 0xF6, 0xE6)   # ayri gruplar: farkli zemin
            elif c in (7, 8, 9):
                cell.fill.fore_color.rgb = RGBColor(0xFD, 0xF2, 0xF3)
            else:
                cell.fill.fore_color.rgb = WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA)

    # ENGELLI / ETKINLIK: mağaza satirlarinin ICINDE sayilir; burada bilgi amaçli AYRI gosterilir.
    #   Engelli tespiti perbilgi'ye dayanir -> yalniz BKM_GENEL firmasinda mumkun (Heykel/Sura kor).
    tb(s, 0.6, 4.28, 12.05, 0.34,
       [("** YÖNETİM KARARI: engelli ve etkinlik kadrosu NORM DIŞIDIR — norm doluluğuna sayılmaz, "
         "mağaza satırlarından düşülmüştür. Heykel ve Şura'da engelli kadro yoktur (ayrı tüzel "
         "kişilik, 50 çalışan altı → 4857/30 yükümlülüğü doğmaz).", 8.5, False, GREY)])
    rrect(s, 0.6, 4.78, 12.05, 0.52, LGREY, RED, lw=1.5)
    tb(s, 0.9, 4.78, 11.6, 0.52,
       [("Norm doluluğu (engelli ve etkinlik hariç): norm %d · operasyonel gerçek %d → %+d KİŞİ EKSİK "
         "(kadrolu %+d · sezonluk %+d)."
         % (tp["norm_toplam"], kad_ops + tp["sezonluk_kesim26"],
            (kad_ops + tp["sezonluk_kesim26"]) - tp["norm_toplam"],
            kad_ops - tp["norm"], tp["sezonluk_kesim26"] - tp["norm_sezonluk"]),
         11, True, DRED)], anchor=MSO_ANCHOR.MIDDLE)

    # KAPSAM SOZLUGU: destede uc kapsam dolasiyor; etiket dusunce rakamlar birbirini tutmuyor
    # gorunuyor. Tutarlilik denetcisi (scripts/tutarlilik_kontrol.py) bu uc kapsami her calismada dogrular.
    rrect(s, 0.6, 5.34, 12.05, 0.74, WHITE, RGBColor(0xDC, 0xDC, 0xDC), rad=False)
    rrect(s, 0.6, 5.34, 0.075, 0.74, MGREY, rad=False)
    tb(s, 0.85, 5.36, 11.6, 0.24, [("KAPSAM SÖZLÜĞÜ — bu destede üç ayrı kapsam kullanılır", 9.5, True, GREY)])
    tb(s, 0.85, 5.58, 11.85, 0.5,
       [(("• 3 POS mağazası (FSM · Özlüce · İst. Yolu) — iş hacminin ölçülebildiği kapsam: "
          "kadro %d → %d" + chr(10) +
          "• 4 norm mağazası (+ Heykel) — norm karşılaştırması: norm %d · kayıt %d · operasyonel %d"
          + chr(10) +
          "• 5 mağaza (+ Şura) — İK kadro raporu: kadrolu %d + sezonluk %d = %d")
         % (sum(m["kadro25"] for m in v["magaza"]), sum(m["kadro26"] for m in v["magaza"]),
            tp["norm_toplam"], tp["toplam_kesim26"], kad_ops + tp["sezonluk_kesim26"],
            k5["kadrolu_kesim26"], k5["sezonluk_kesim26"], k5["toplam_kesim26"]),
         8, False, INK)], sp=1.08)
    dipnot(s, "* Norm = ENGELLİ DIŞINDAKİ personel sayısı (yönetim kararı); etkinlik de norm dışı. "
              "Mağaza satırları operasyonel kadroyu gösterir (kadrolu − engelli − etkinlik). "
              "Engelli %d · etkinlik %d kişi ayrı satırda; en alttaki kayıt toplamı İK'nın resmi "
              "rakamıdır (kadrolu %d · sezonluk %d) · Norm kaynağı: BKMKİTAP Mağaza Kadro ve Sezon "
              "Takip Tablosu, %s · Kapsam dışı: %s · Gerçek sayılar 31.08 as-of."
           % (eng_top, etk_top, tp["kadrolu_kesim26"], tp["sezonluk_kesim26"], nrm["tarih"],
              ", ".join(tr_title(x) for x in nrm["kapsam_disi"]) or "—"))
    sig(s)

# ================================================================= NORM ACIGI · BOLUM
if nrm and nrm.get("bolum"):
    s = add("Yalnızca Başlık"); setph(s, 0, "Norm Açığı — Bölüm Bazında")
    bl = nrm["bolum"]
    acik_bolum = nrm["acik_bolum_toplam"]
    # K-11/K-06: magaza acigi ve teyit bekleyen acik CEKIRDEKTEN okunur (emitter hesap yapmaz).
    acik_sube = nrm["acik_sube_toplam"]
    acik_teyit = nrm.get("acik_bolum_teyit", 0)
    teyit_adlar = nrm.get("teyit_bolumler", [])

    satir = [["Bölüm", "Norm", "Operasyonel" + chr(10) + "kadrolu", "Engelli" + chr(10) + "(norm dışı)",
              "Açık", "Fazla", "Sezonluk" + chr(10) + "31.08"]]
    # K-06: normda tanimli ama kayitta hic kisi olmayan bolum "acik" degil, TEYIT BEKLEYEN.
    bl_norm = [r for r in bl if not r.get("norm_disi") and not r.get("teyit_gerekiyor")]
    bl_teyit = [r for r in bl if r.get("teyit_gerekiyor")]
    for r in bl_norm:
        satir.append([tr_title(r["bolum"]), str(r["norm"]), str(r["kadrolu26"]),
                      str(r["engelli26"]) if r["engelli26"] else "—",
                      str(r["acik"]) if r["acik"] else "—",
                      str(r["fazla"]) if r["fazla"] else "—",
                      str(r["sezonluk26"]) if r["sezonluk26"] else "—"])
    satir.append(["TOPLAM" + (" (teyit hariç)" if bl_teyit else ""),
                  str(sum(r["norm"] for r in bl_norm)),
                  str(sum(r["kadrolu26"] for r in bl_norm)),
                  str(sum(r["engelli26"] for r in bl_norm)),
                  str(acik_bolum), str(nrm["fazla_bolum_toplam"]),
                  str(sum(r["sezonluk26"] for r in bl_norm))])
    for r in bl_teyit:
        satir.append([tr_title(r["bolum"]) + " (teyit bekliyor)", str(r["norm"]), "0", "—", "—",
                      "—", str(r["sezonluk26"]) if r["sezonluk26"] else "—"])
    for r in bl:
        if r.get("norm_disi"):
            satir.append([tr_title(r["bolum"]) + " (norm dışı)", "—", str(r["kadrolu26"]), "—", "—",
                          "—", str(r["sezonluk26"]) if r["sezonluk26"] else "—"])
    t = s.shapes.add_table(len(satir), 7, Inches(0.6), Inches(1.5), Inches(7.9),
                           Inches(0.34 + 0.2 * (len(satir) - 1))).table
    for i, gen in enumerate((1.85, 0.8, 1.25, 1.05, 0.75, 0.75, 1.05)):
        t.columns[i].width = Inches(gen)
    t.rows[0].height = Inches(0.34)
    for r_ in list(t.rows)[1:]:
        r_.height = Inches(0.2)
    for r, row in enumerate(satir):
        for c, val in enumerate(row):
            cell = t.cell(r, c); cell.text = val
            son_satir = satir[r][0].startswith("TOPLAM")
            for para in cell.text_frame.paragraphs:
                para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
                for run in para.runs:
                    run.font.size = Pt(7.5 if r == 0 else 9)
                    run.font.name = "Calibri"
                    run.font.bold = (r == 0 or son_satir or c == 4)
                    run.font.color.rgb = WHITE if r == 0 else (DRED if c == 4 else INK)
            cell.fill.solid()
            norm_disi_satir = ("norm dışı" in satir[r][0] or "teyit bekliyor" in satir[r][0])
            cell.fill.fore_color.rgb = RED if r == 0 else (
                RGBColor(0xFF, 0xF6, 0xE6) if norm_disi_satir else
                (LGREY if son_satir else (WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA))))

    en_buyuk = [r for r in bl if r["acik"] and not r.get("norm_disi")
                and not r.get("teyit_gerekiyor")][:4]
    card(s, 8.7, 1.5, 3.95, 2.15, DRED, ikon="alert-triangle")
    tb(s, 8.95, 1.62, 3.0, 0.32, [("EN BÜYÜK AÇIKLAR", 10, True, GREY)])
    tb(s, 8.95, 1.98, 3.5, 1.6,
       [("\n".join("%s  %d kişi" % (tr_title(r["bolum"]), r["acik"]) for r in en_buyuk),
         12, True, DRED)], sp=1.35)

    rrect(s, 8.7, 3.85, 3.95, 2.15, LGREY, RED, lw=1.5)
    tb(s, 8.95, 3.97, 3.5, 1.95,
       [("Neden mağaza toplamından büyük?", 12, True, DRED),
        ("Bölüm bazında açık %d kişi, mağaza bazında %d. Aradaki fark, bir mağazada bir bölümün "
         "fazlasının başka bölümün açığını maskelemesinden gelir. Gerçek ihtiyaç bölüm bazında "
         "okunur.%s" % (acik_bolum, acik_sube,
                        ("" if not acik_teyit else
                         " Ayrıca normda tanımlı olduğu hâlde kayıtta hiç personeli olmayan %d "
                         "kişilik satır (%s) açığa DAHİL EDİLMEDİ — teyit bekliyor."
                         % (acik_teyit, " · ".join(tr_title(x) for x in teyit_adlar)))),
         10, False, INK)], sp=1.12)

    dipnot(s, "* Norm = engelli DIŞINDAKİ personel (yönetim kararı) — engelli bölüm bazında da "
              "DÜŞÜLDÜ: %s · ETKİNLİK normda tanımlı olmadığı için norm dışı satır olarak en altta "
              "· Kapsam: norm tablosundaki dört mağaza (Şura yok) · Norm %s tarihli · Gerçek sayılar "
              "31.08 as-of."
           % (" · ".join("%s %d" % (tr_title(b), k) for b, k in
                         sorted(nrm.get("engelli_bolum", {}).items(), key=lambda x: -x[1])) or "yok",
              nrm["tarih"]))
    sig(s)

# ================================================================= SEZONLUK ALIM ZAMANLAMASI
al = v.get("sezonluk_alim")
ay2 = v.get("agustos_yarim")
if al and ay2:
    s = add("Yalnızca Başlık"); setph(s, 0, "Sezonluk Alım Zamanlaması")
    a25, a26 = al[str(ONCEKI)], al[str(CARI)]
    gun_fark = a26["ort_yil_gunu"] - a25["ort_yil_gunu"]
    # K-10: asagidaki yorum kolonlari elle yazilmisti (+%25,1 / -%2,9 / "3 kisi") — turetilir.
    d_yarim1 = yzd(ay2["1"]["adet26"] / ay2["1"]["adet25"] - 1)
    d_yarim2 = yzd(ay2["2"]["adet26"] / ay2["2"]["adet25"] - 1)
    sez_kesim_fark = k5["sezonluk_kesim26"] - k5["sezonluk_kesim25"]

    kpi(s, 0.6, 1.5, 3.9, "ORTALAMA ALIM GÜNÜ",
        (("%.1f" % gun_fark).replace(".", ",") + " gün geç") if gun_fark > 0
        else (("%.1f" % abs(gun_fark)).replace(".", ",") + " gün erken"),
        "takvim ölçüsü · %d. → %d. gün" % (round(a25["ort_yil_gunu"]), round(a26["ort_yil_gunu"])),
        MGREY, 22, ikon="workflow")
    kpi(s, 4.68, 1.5, 3.9, "TEMMUZ VE ÖNCESİ ALIM", "%d → %d" % (a25["temmuz_ve_oncesi"], a26["temmuz_ve_oncesi"]),
        "gerçek erken alım azaldı", DRED, 30, ikon="users")
    kpi(s, 8.75, 1.5, 3.9, "1–14 AĞUSTOS İŞ HACMİ",
        yzd(ay2["1"]["adet26"] / ay2["1"]["adet25"] - 1),
        "%s → %s adet" % (bin(ay2["1"]["adet25"]), bin(ay2["1"]["adet26"])), DRED, 30, ikon="package")

    satir = [["Ölçü", "%d" % ONCEKI, "%d" % CARI, "Yorum"],
             ["Ortalama alım günü (takvim)", "%d. gün" % round(a25["ort_yil_gunu"]),
              "%d. gün" % round(a26["ort_yil_gunu"]),
              "2026 alımı ortalama %s gün DAHA GEÇ" % ("%.1f" % gun_fark).replace(".", ",")],
             ["Temmuz ve öncesi alınan", "%d kişi" % a25["temmuz_ve_oncesi"],
              "%d kişi" % a26["temmuz_ve_oncesi"], "erken alım azaldı"],
             ["Açılıştan 45+ gün önce alınan", "%d kişi" % a25["gun45_oncesi"],
              "%d kişi" % a26["gun45_oncesi"], "çok erken alım azaldı"],
             ["1–14 Ağustos alınan", "%d kişi" % a25["agustos_1_14"], "%d kişi" % a26["agustos_1_14"],
              "artış bu iki haftada"],
             ["1–14 Ağustos ürün adedi", bin(ay2["1"]["adet25"]), bin(ay2["1"]["adet26"]),
              "iş %s büyüdü — alım işi takip etti" % yzd(ay2["1"]["adet26"] / ay2["1"]["adet25"] - 1)],
             ["15–31 Ağustos ürün adedi", bin(ay2["2"]["adet25"]), bin(ay2["2"]["adet26"]),
              "%s — dalga Eylül'e kaydı" % yzd(ay2["2"]["adet26"] / ay2["2"]["adet25"] - 1)],
             ["31.08'de çalışan sezonluk", "%d kişi" % k5["sezonluk_kesim25"],
              "%d kişi" % k5["sezonluk_kesim26"],
              "kesimde %d kişi DAHA %s" % (abs(sez_kesim_fark),
                                           "AZ" if sez_kesim_fark < 0 else "FAZLA")],
             ["   — Temmuz alımı", "%d kişi" % a25.get("aktif_donem", {}).get("2_temmuz", 0),
              "%d kişi" % a26.get("aktif_donem", {}).get("2_temmuz", 0), "erken alım payı düştü"],
             ["   — 1–14 Ağustos alımı", "%d kişi" % a25.get("aktif_donem", {}).get("3_agustos_1_14", 0),
              "%d kişi" % a26.get("aktif_donem", {}).get("3_agustos_1_14", 0),
              "iş %s büyüyen dönem" % d_yarim1],
             ["   — 15–31 Ağustos alımı", "%d kişi" % a25.get("aktif_donem", {}).get("4_agustos_15_31", 0),
              "%d kişi" % a26.get("aktif_donem", {}).get("4_agustos_15_31", 0),
              "iş %s → alım azaltıldı" % d_yarim2],
             ]  # NOT: "önceki yıldan devreden" satırı patron sunumuna KONULMADI — 2025 alımlı
                #       tek kayıt hâlâ Kadro='SEZONLUK' görünüyor, veri düzeltmesi İK'da (02.09.2026).
    t = s.shapes.add_table(len(satir), 4, Inches(0.6), Inches(3.55), Inches(12.05), Inches(2.2)).table
    for i, gen in enumerate((3.6, 1.9, 1.9, 4.65)):
        t.columns[i].width = Inches(gen)
    for r_ in t.rows:
        r_.height = Inches(0.2)      # satir buyumesini sinirla (tablo dipnota/logoya binmesin)
    for r, row in enumerate(satir):
        for c, val in enumerate(row):
            cell = t.cell(r, c); cell.text = val
            for para in cell.text_frame.paragraphs:
                para.alignment = PP_ALIGN.LEFT if c in (0, 3) else PP_ALIGN.CENTER
                for run in para.runs:
                    run.font.size = Pt(8 if r == 0 else 9)
                    run.font.name = "Calibri"
                    run.font.bold = (r == 0 or c == 2)
                    run.font.color.rgb = WHITE if r == 0 else (DRED if c == 3 else INK)
            cell.fill.solid()
            cell.fill.fore_color.rgb = RED if r == 0 else (WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA))

    dipnot(s, "* İK'da düzeltme bekleyen 1 kayıt: 2025 girişli bir sezonluk personel çıkış tarihi "
              "işlenmediği için 31.08'de aktif görünüyor; düzeltilince sezonluk 62 → 61 olur (rakamlar "
              "İK'nın resmi kaydıyla birebir tutulsun diye şimdilik düzeltilmedi) · Kapsam: beş mağaza (%s) · Kohortlar okul açılışına göre AYNI ofsette kesildi "
              "(T−12: 27.08.2025 ve 02.09.2026) · İş hacmi üç POS mağazası · ⚠ \"açılıştan kaç gün önce\" "
              "ölçüsü açılış 6 gün kaydığı için 2026'yı mekanik olarak erken gösterir, takvim ölçüsü esastır."
           % BES_ADLARI)
    sig(s)

# ================================================================= 13 ITIRAZLAR
s = add("Yalnızca Başlık"); setph(s, 0, "Yöntem ve Açıklamalar")
itiraz = [
    ("Büyüme kurumsal kanaldan mı geldi?",
     "Tersi: Sınav Okulları küçüldü. Ocak–Ağustos cirosu %s → %s milyon TL (%s). Mağaza tarafı %s büyüdü — "
     "büyümenin tamamı raftan geldi."
     % (bin(oa["sinav"]["kdvdahil25"] / 1e6, 1), bin(oa["sinav"]["kdvdahil26"] / 1e6, 1),
        yzd(d_sinav), yzd(d_mag_oa))),
    ("Ciro artışı enflasyon kaynaklı mı?",
     "Kısmen doğru: eşleşen ürünlerde fiyat endeksi +%%19,8. Bu yüzden savunma ciroya değil ADEDE "
     "dayanıyor: ürün adedi %s ve adet fiyattan etkilenmez." % yzd(d_adet)),
    ("Kasa sistemi değişti, karşılaştırma geçerli mi?",
     "Bu yüzden ölçüm POS'tan değil ERP'den (DerinSIS) alındı — iki yılda da aynı kaynak, aynı belge tipi. "
     "Temmuz 2025 kasa geçişi ölçüye girmiyor."),
    ("Sezonluk personel erken mi alındı?",
     "Hayır: takvim ölçüsünde %s alımı ortalama %s gün DAHA GEÇ; Temmuz ve öncesi alım %d kişiden "
     "%d'ye indi. Artış 1–14 Ağustos'ta ve o iki haftada ürün adedi %s büyüdü — alım işi takip etti."
     % (CARI, ("%.1f" % (al[str(CARI)]["ort_yil_gunu"] - al[str(ONCEKI)]["ort_yil_gunu"]))
        .replace(".", ","), al[str(ONCEKI)]["temmuz_ve_oncesi"], al[str(CARI)]["temmuz_ve_oncesi"],
        yzd(v["agustos_yarim"]["1"]["adet26"] / v["agustos_yarim"]["1"]["adet25"] - 1))),
    ("Ağustos ayında ivme düşüşü var mı?",
     "Takvim etkisi: okullar 2025'te 8 Eylül, 2026'da 14 Eylül açıldı — sezon 6 gün geriye kaydı. "
     "Açılışa hizalanınca haftalık büyüme %65–79 bandında düz seyrediyor."),
]
# kart yuksekligi kart SAYISINA gore otomatik: alt sinir y6.00 (dipnot/logo bandi serbest kalsin)
ust, alt_sinir = 1.45, 6.00
adim = (alt_sinir - ust) / len(itiraz)
kh = adim - 0.10
punto_bas = 12.5 if len(itiraz) <= 4 else 11.5
punto_cev = 11 if len(itiraz) <= 4 else 9.5
y = ust
for i, (bas, cev) in enumerate(itiraz):
    card(s, 0.6, y, 12.05, kh, RED)
    s.shapes.add_picture(os.path.join(ICOR, "circle-check.png"), Inches(0.85), Inches(y + 0.14),
                         Inches(0.28), Inches(0.28))
    tb(s, 1.25, y + 0.07, 11.0, 0.32, [(bas, punto_bas, True, DRED)])
    tb(s, 1.25, y + 0.38, 11.0, kh - 0.42, [(cev, punto_cev, False, INK)], sp=1.06)
    y += adim
dipnot(s, DIP_OCA_AGU + " (kurumsal/mağaza kıyası) · hizalı dönem: %s" % DONEM_POS)
sig(s)

# ================================================================= 14 DUZELTILECEK
s = add("Yalnızca Başlık"); setph(s, 0, "İyileştirme Alanı")
# ⚠ Rakamlar JSON'dan (canlı ölçüm) gelir — python-reviewer 02.09: önce hardcode yazılıydı,
#   hiçbir sorgudan gelmiyordu ve denetçi de görmüyordu; sessizce bayatlayacak KPI'ydı.
tt = v.get("tutunma", {})


def _t(seg, yil):
    d_ = tt.get(seg, {}).get(str(yil), {})
    o = d_.get("oran14")
    return {"oran": ("%%%.1f" % (o * 100)).replace(".", ",") if o is not None else "—",
            "alinan": d_.get("alinan", 0), "ayrilan": d_.get("ayrilan", 0),
            "kalan": d_.get("kalan14", 0), "risk": d_.get("risk14", 0)}


kad25, kad26 = _t("KADROLU", ONCEKI), _t("KADROLU", CARI)
sez25, sez26 = _t("SEZONLUK", ONCEKI), _t("SEZONLUK", CARI)

card(s, 0.6, 1.5, 5.9, 2.5, DRED, ikon="alert-triangle")
tb(s, 0.85, 1.62, 5.0, 0.36, [("KADROLU ALIMDA KALMA ORANI", 10, True, GREY)])
tb(s, 0.85, 2.02, 5.4, 0.86, [("%s → %s" % (kad25["oran"], kad26["oran"]), 30, True, DRED)])
tb(s, 0.85, 2.92, 5.4, 0.95,
   [("İlk 14 günü tamamlama oranı (%d/%d → %d/%d). %d alımdan %d'si kesim tarihine kadar "
     "ayrılmıştır (önceki yıl %d alımdan %d). Aynı pozisyonun iki kez doldurulması maliyet "
     "yaratmaktadır." % (kad25["kalan"], kad25["risk"], kad26["kalan"], kad26["risk"],
                         kad26["alinan"], kad26["ayrilan"], kad25["alinan"], kad25["ayrilan"]),
     10.5, False, INK)], sp=1.1)

card(s, 6.75, 1.5, 5.9, 2.5, MGREY, ikon="users")
tb(s, 7.0, 1.62, 5.0, 0.36, [("SEZONLUK KADRODA KALMA ORANI", 10, True, GREY)])
tb(s, 7.0, 2.02, 5.4, 0.86, [("%s → %s" % (sez25["oran"], sez26["oran"]), 30, True, MGREY)])
tb(s, 7.0, 2.92, 5.4, 0.95,
   [("Sezonluk kadroda kalma oranı yükselmiştir (%d/%d → %d/%d). Sorun sezonluk alımda değil, "
     "kadrolu alımın ilk haftasındadır."
     % (sez25["kalan"], sez25["risk"], sez26["kalan"], sez26["risk"]), 10.5, False, INK)], sp=1.1)


rrect(s, 0.6, 4.2, 12.05, 1.75, LGREY, RED, lw=1.5)
tb(s, 0.9, 4.35, 11.5, 1.5,
   [("Planlanan Aksiyonlar", 13.5, True, DRED),
    ("• En bozuk üç nokta: Özlüce, Heykel, Merkez Depo → ilk hafta karşılama protokolü.\n"
     "• İdari İşler pozisyonunda ücret–vardiya revizyonu.\n"
     "• Ölçüt: gelecek sezon Eylül öncesi kayıp %20'den %12'ye (2025 seviyesi).", 12, False, INK)], sp=1.25)
dipnot(s, DIP_BES + " Tutunma ölçümü mağaza kadrosu üzerinden yapılmıştır.")
sig(s)

# ================================================================= 15 KAPANIS
s = add("Başlık Slaydı")
setph(s, 0, "Sonuç")
setph(s, 1, "Norma göre %+d kişi · kadrolu %s · ürün adedi %s · personel başına iş %s"
            % ((lambda nn: (nn["toplam"]["kadrolu_kesim26"]
                            - sum(a.get("engelli", 0) + a.get("etkinlik", 0)
                                  for a in nn.get("ayrik", {}).values())
                            + nn["toplam"]["sezonluk_kesim26"]) - nn["toplam"]["norm_toplam"])(v["norm"])
               if v.get("norm") else 0,
               ("−%d" % abs(sezon_ici_26)) if sezon_ici_26 < 0 else "+%d" % sezon_ici_26,
               yzd(d_adet), yzd(d_kb)))

try:
    pr.save(OUT)
except PermissionError:
    sys.exit("Dosya açık görünüyor, kaydedilemedi. PowerPoint'te kapatıp tekrar çalıştır: "
                 "%s" % OUT)
print("Yazildi: %s (%d slayt)" % (OUT, len(pr.slides._sldIdLst)))
