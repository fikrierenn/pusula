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

adet25 = sum(m["adet25"] for m in v["magaza"]); adet26 = sum(m["adet26"] for m in v["magaza"])
kh25 = sum(m["kdvharic25"] for m in v["magaza"]); kh26 = sum(m["kdvharic26"] for m in v["magaza"])
kd25 = sum(m["kdvdahil25"] for m in v["magaza"]); kd26 = sum(m["kdvdahil26"] for m in v["magaza"])
kadro25 = sum(m["kadro25"] for m in v["magaza"]); kadro26 = sum(m["kadro26"] for m in v["magaza"])

d_adet = adet26 / adet25 - 1
d_ciro = kd26 / kd25 - 1
d_kadro = kadro26 / kadro25 - 1
kb25, kb26 = adet25 / kadro25, adet26 / kadro26
d_kb = kb26 / kb25 - 1
kat = d_adet / d_kadro
taban_fark = k5["kadrolu_taban26"] - k5["kadrolu_taban25"]
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
    for l in pr.slide_masters[0].slide_layouts:
        if l.name == name:
            return l
    return pr.slide_masters[0].slide_layouts[6]


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
    except Exception:
        pass
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
    return None


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


def cift_bar(sl, x, y, w, h, kategoriler, s25, s26, etiket25="2025", etiket26="2026", yuzde_etiket=False):
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
    return ch


# ================================================================= 1 KAPAK
s = add("Başlık Slaydı")
setph(s, 0, "Kadro ve İş Hacmi Değerlendirmesi")
setph(s, 1, "Sezon 2026 · Mağazalar · kadro 30.06 ve 31.08 · iş hacmi %s – %s ile %s – %s"
            % (PT[str(ONCEKI)][0], PT[str(ONCEKI)][1], PT[str(CARI)][0], PT[str(CARI)][1]))

# ================================================================= 2 GUNDEM
s = add("Yalnızca Başlık"); setph(s, 0, "Kapsam ve İçerik")
ag = [("users", "Kadro gelişimi", "Taban 30.06 · sezon içi hareket · sezonluk kadro."),
      ("package", "İş hacmi gelişimi", "Elleçlenen ürün adedi ve ciro, aynı dönemde."),
      ("zap", "Personel başına iş", "Kadro büyümesiyle iş büyümesinin karşılaştırması."),
      ("layers", "Kadro dağılımı", "Bölüm ve mağaza bazında artışın dağılımı."),
      ("shield-check", "Yöntem ve açıklamalar", "Enflasyon · kurumsal kanal · sistem geçişi · takvim."),
      ("alert-triangle", "İyileştirme alanı", "Yeni alınan personelin ilk iki haftada kalma oranı.")]
for i, (ic, h, d) in enumerate(ag):
    x = 0.6 + (i % 3) * 4.15; y = 1.5 + (i // 3) * 2.15
    card(s, x, y, 3.9, 1.95, RED); circ(s, x + 0.25, y + 0.22, 0.58, RED, ic)
    tb(s, x + 0.25, y + 0.9, 3.4, 0.4, [(h, 14, True, CHAR)])
    tb(s, x + 0.25, y + 1.28, 3.45, 0.6, [(d, 11, False, GREY)])
sig(s)

# ================================================================= 3 TEK SAYFA OZET
s = add("Yalnızca Başlık"); setph(s, 0, "Yönetici Özeti")
kpi(s, 0.6, 1.5, 2.9, "TABAN FARKI · 30.06", "%+d" % taban_fark,
    "kadrolu %d → %d kişi" % (k5["kadrolu_taban25"], k5["kadrolu_taban26"]), ikon="users")
kpi(s, 3.65, 1.5, 2.9, "SEZON İÇİ KADROLU", "%+d" % sezon_ici_26,
    "%d → %d · geçen yıl %+d" % (k5["kadrolu_taban26"], k5["kadrolu_kesim26"], sezon_ici_25),
    ikon="users")
kpi(s, 6.7, 1.5, 2.9, "ÜRÜN ADEDİ", yzd(d_adet),
    "%s → %s adet" % (bin(adet25), bin(adet26)), YESIL, 30, ikon="package")
kpi(s, 9.75, 1.5, 2.9, "KİŞİ BAŞI ÜRÜN", yzd(d_kb),
    "%s → %s adet" % (bin(kb25), bin(kb26)), YESIL, 30, ikon="zap")

rrect(s, 0.6, 3.75, 12.05, 0.95, LGREY, RED, lw=1.5)
tb(s, 0.9, 3.75, 11.5, 0.95,
   [("Kadro farkı sezon öncesinde oluşmuştur; sezon döneminde kadro azalırken iş hacmi %s artmıştır."
     % yzd(d_adet).replace("+", ""), 15, True, DRED)], anchor=MSO_ANCHOR.MIDDLE)

card(s, 0.6, 4.85, 5.9, 1.1, MGREY)
tb(s, 0.85, 4.95, 5.4, 0.3, [("KADRO · ÜÇ POS MAĞAZASI (SEZONLUK DAHİL)", 10, True, GREY)])
tb(s, 0.85, 5.25, 5.4, 0.6, [("%d → %d kişi  (%s)" % (kadro25, kadro26, yzd(d_kadro)), 15, True, CHAR)])
card(s, 6.75, 4.85, 5.9, 1.1, RED)
tb(s, 7.0, 4.95, 5.4, 0.3, [("İŞ HACMİ", 10, True, GREY)])
tb(s, 7.0, 5.25, 5.4, 0.6,
   [("iş hacmi, kadronun %s katı oranında artmıştır" % ("%.1f" % kat).replace(".", ","), 15, True, RED)])
dipnot(s, DIP_KARMA)
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
         (k5["kadrolu_taban26"], k5["kadrolu_kesim26"]))
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
             "Sezonluk 31.08\n2025", "Sezonluk 31.08\n2026"]
satirlar = [basliklar]
for m in v["magaza_kadro"]:
    satirlar.append([tr_title(m["sube"]),
                     str(m["kadrolu_taban25"]), str(m["kadrolu_taban26"]),
                     str(m["kadrolu_kesim25"]), str(m["kadrolu_kesim26"]),
                     "%+d" % (m["kadrolu_kesim25"] - m["kadrolu_taban25"]),
                     "%+d" % (m["kadrolu_kesim26"] - m["kadrolu_taban26"]),
                     str(m["sezonluk_kesim25"]), str(m["sezonluk_kesim26"])])
satirlar.append(["TOPLAM",
                 str(k5["kadrolu_taban25"]), str(k5["kadrolu_taban26"]),
                 str(k5["kadrolu_kesim25"]), str(k5["kadrolu_kesim26"]),
                 "%+d" % sezon_ici_25, "%+d" % sezon_ici_26,
                 str(k5["sezonluk_kesim25"]), str(k5["sezonluk_kesim26"])])
t = s.shapes.add_table(len(satirlar), 9, Inches(0.6), Inches(1.55), Inches(12.05), Inches(3.3)).table
for w, gen in zip(range(9), (2.05, 1.3, 1.3, 1.3, 1.3, 1.1, 1.1, 1.3, 1.3)):
    t.columns[w].width = Inches(gen)
t.rows[0].height = Inches(0.55)
for r, row in enumerate(satirlar):
    for c, val in enumerate(row):
        cell = t.cell(r, c); cell.text = val
        son_satir = (r == len(satirlar) - 1)
        for para in cell.text_frame.paragraphs:
            para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
            for run in para.runs:
                run.font.size = Pt(9.5 if r == 0 else 11)
                run.font.name = "Calibri"
                run.font.bold = (r == 0 or son_satir or c in (5, 6))
                run.font.color.rgb = WHITE if r == 0 else (DRED if c in (5, 6) else INK)
        cell.fill.solid()
        cell.fill.fore_color.rgb = RED if r == 0 else (
            LGREY if son_satir else (WHITE if r % 2 else RGBColor(0xFA, 0xFA, 0xFA)))
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
s = add("Yalnızca Başlık"); setph(s, 0, "Personel Başına İş Hacmi")
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
s = add("Yalnızca Başlık"); setph(s, 0, "Personel Başına İş Hacmi — Dört Yıllık Seyir")
cd = CategoryChartData(); cd.categories = [str(y_["yil"]) for y_ in v["yillar"]]
cd.add_series("adet / kişi", tuple(y_["adet"] / y_["kadrolu"] for y_ in v["yillar"]))
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

notlar = [("2024'te kadro atladı", "Kadrolu 60 → 91. Adet yalnız %11 arttı → kişi başı iş düştü.", DRED),
          ("Ama 2023 'norm' değil", "O yıl FSM kasada 0, Özlüce kasada 1 kişi vardı — eksik kadroyla "
                                    "çalışma.", GREY),
          ("2024 → 2026 toparlanma", "Kişi başı iş %28,8 arttı; bu yıl kadro büyürken verim de arttı.", RED)]
y = 1.75
for h, d, col in notlar:
    card(s, 8.1, y, 4.55, 1.2, col)
    tb(s, 8.35, y + 0.12, 4.05, 0.35, [(h, 12.5, True, CHAR)])
    tb(s, 8.35, y + 0.48, 4.05, 0.7, [(d, 10.5, False, GREY)])
    y += 1.35
tb(s, 0.6, 5.65, 12.05, 0.5,
   [("Kadro = 31.08 itibarıyla kadrolu (sezonluk hariç; yıllar arası tahliye zamanlaması kıyası bozar).",
     10, False, MGREY)])
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
   [("Yönetim +0  ·  Mal Kabul +0  ·  İdari İşler +0", 13, True, CHAR),
    ("Bu üç bölümde kadro değişimi sıfırdır.", 10.5, False, GREY)], sp=1.15)
card(s, 8.1, 3.5, 4.55, 1.7, RED)
tb(s, 8.35, 3.62, 4.05, 0.35, [("KADROSU ARTAN BÖLÜMLER", 10.5, True, GREY)])
tb(s, 8.35, 3.98, 4.05, 1.15,
   [("  ·  ".join("%s %+d" % (tr_title(b["bolum"]), b["kadrolu26"] - b["kadrolu25"]) for b in ilk5),
     12, True, DRED)], sp=1.15)
rrect(s, 0.6, 5.28, 12.05, 0.72, LGREY, RED, lw=1.5)
tb(s, 0.9, 5.28, 11.5, 0.72,
   [("Kadrolu %+d kişilik artışın tamamı satış ve kasa bölümlerindedir; yönetim kadrosunda değişim "
     "yoktur." % taban_fark, 13.5, True, DRED)], anchor=MSO_ANCHOR.MIDDLE)
dipnot(s, DIP_BES)
sig(s)

# ================================================================= 12b MAGAZA x BOLUM MATRISI
s = add("Yalnızca Başlık"); setph(s, 0, "Mağaza × Bölüm Kadro Değişimi")
SUBE_SIRA = ["İST. YOLU", "ÖZLÜCE", "FSM", "HEYKEL", "ŞURA"]
mb = {(r["sube"], r["bolum"]): r for r in v["magaza_bolum"]}
def delta(sube, bolum):
    r = mb.get((sube, bolum))
    return None if r is None else r["kadrolu26"] - r["kadrolu25"]


bolumler = sorted({r["bolum"] for r in v["magaza_bolum"]},
                  key=lambda b: -sum((delta(x, b) or 0) for x in SUBE_SIRA))
onemli = [b for b in bolumler
          if any((delta(x, b) or 0) != 0 for x in SUBE_SIRA)
          or b in ("MAĞAZA", "MAL KABUL", "İDARİ İŞLER")][:12]

satir = [["Bölüm"] + [tr_title(x) for x in SUBE_SIRA] + ["Toplam"]]
for b in onemli:
    hucre = []
    for x in SUBE_SIRA:
        d = delta(x, b)
        hucre.append("—" if d is None else ("%+d" % d if d else "0"))
    satir.append([tr_title(b)] + hucre + ["%+d" % sum((delta(x, b) or 0) for x in SUBE_SIRA)])
t = s.shapes.add_table(len(satir), 7, Inches(0.6), Inches(1.5), Inches(12.05),
                       Inches(min(4.3, 0.32 * len(satir)))).table
for i, gen in enumerate((3.0, 1.65, 1.5, 1.35, 1.55, 1.35, 1.65)):
    t.columns[i].width = Inches(gen)
for r, row in enumerate(satir):
    for c, val in enumerate(row):
        cell = t.cell(r, c); cell.text = val
        son = (r == len(satir) - 1)
        for para in cell.text_frame.paragraphs:
            para.alignment = PP_ALIGN.LEFT if c == 0 else PP_ALIGN.CENTER
            for run in para.runs:
                run.font.size = Pt(10.5); run.font.name = "Calibri"
                run.font.bold = (r == 0 or c == 6 or son)
                run.font.color.rgb = WHITE if r == 0 else (
                    DRED if (c == 6 and r > 0 and val.startswith("+")) else INK)
        cell.fill.solid()
        cell.fill.fore_color.rgb = RED if r == 0 else (LGREY if son or r % 2 == 0 else WHITE)
tb(s, 0.6, min(5.74, 1.5 + min(4.3, 0.32 * len(satir)) + 0.10), 12.05, 0.32,
   [("'—' ilgili mağazada o bölüm yoktur · Yönetim, Mal Kabul ve İdari İşler satırları tüm "
     "mağazalarda sıfır veya negatiftir.", 9.5, False, GREY)], sp=1.1)
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
     "olan İst. Yolu'nda dahi oran 2,2 katıdır.", 11.5, False, INK)], sp=1.15)
dipnot(s, DIP_POS)
sig(s)

# ================================================================= 12d KATEGORI x BOLUM ESLESME
s = add("Yalnızca Başlık"); setph(s, 0, "Kategori Büyümesi ve İlgili Bölüm Kadrosu")
ESLES = {"Hazırlık Kitapları": "YARDIMCI KİTAP", "Kırtasiye": "KIRTASİYE", "Kitap": "KÜLTÜR",
         "Çocuk Kitabı": "ÇOCUK", "Oyuncak": "OYUNCAK", "Akademi": "AKADEMİ"}
kadro_delta = {b["bolum"]: b["kadrolu26"] - b["kadrolu25"] for b in v["bolum"]}
kat_veri = [k for k in v["kategori"] if k["kategori"] in ESLES]
kat_veri.sort(key=lambda k: -kadro_delta.get(ESLES[k["kategori"]], 0))

satir = [["Kategori", "Bakan bölüm", "Ürün adedi 2025 → 2026", "Adet Δ", "Ciro Δ", "Bölüm kadro Δ"]]
for k in kat_veri:
    b = ESLES[k["kategori"]]
    satir.append([k["kategori"], tr_title(b),
                  "%s → %s" % (bin(k["adet25"]), bin(k["adet26"])),
                  yzd(k["adet26"] / k["adet25"] - 1),
                  yzd(k["ciro26"] / k["ciro25"] - 1),
                  "%+d kişi" % kadro_delta.get(b, 0)])
t = s.shapes.add_table(len(satir), 6, Inches(0.6), Inches(1.5), Inches(12.05), Inches(2.6)).table
for i, gen in enumerate((2.6, 2.2, 2.9, 1.5, 1.5, 1.35)):
    t.columns[i].width = Inches(gen)
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
ch = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(4.44),
                        Inches(7.4), Inches(1.56), cd).chart
ch.has_title = False; ch.has_legend = False
ch.font.size = Pt(9); ch.font.name = "Calibri"
ch.plots[0].gap_width = 70; ch.plots[0].has_data_labels = True
ch.plots[0].vary_by_categories = False
ch.plots[0].data_labels.number_format_is_linked = False
ch.plots[0].data_labels.number_format = '0"%"'
ch.plots[0].data_labels.font.size = Pt(8.5)
ch.series[0].format.fill.solid(); ch.series[0].format.fill.fore_color.rgb = RED
tb(s, 0.6, 4.16, 7.4, 0.26, [("Ürün adedi büyümesi (%) — kategori bazında", 10, True, GREY)])

rrect(s, 8.2, 4.4, 4.45, 1.7, LGREY, RED, lw=1.5)
tb(s, 8.45, 4.5, 4.0, 1.5,
   [("Değerlendirme", 13.5, True, DRED),
    ("Kadro artışı, ürün adedi en hızlı artan kategorilere yönlendirilmiştir. Artışın en düşük "
     "olduğu kategoride (Çocuk Kitabı) kadro azaltılmıştır.", 11.5, False, INK)], sp=1.15)
dipnot(s, DIP_POS)
sig(s)

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
    ("Ağustos ayında ivme düşüşü var mı?",
     "Takvim etkisi: okullar 2025'te 8 Eylül, 2026'da 14 Eylül açıldı — sezon 6 gün geriye kaydı. "
     "Açılışa hizalanınca haftalık büyüme %65–79 bandında düz seyrediyor."),
]
y = 1.45
for i, (bas, cev) in enumerate(itiraz):
    card(s, 0.6, y, 12.05, 1.08, RED)
    s.shapes.add_picture(os.path.join(ICOR, "circle-check.png"), Inches(0.85), Inches(y + 0.17),
                         Inches(0.3), Inches(0.3))
    tb(s, 1.28, y + 0.1, 11.0, 0.36, [(bas, 13, True, DRED)])
    tb(s, 1.28, y + 0.45, 11.0, 0.58, [(cev, 11, False, INK)], sp=1.08)
    y += 1.18
dipnot(s, DIP_OCA_AGU + " (kurumsal/mağaza kıyası) · hizalı dönem: %s" % DONEM_POS)
sig(s)

# ================================================================= 14 DUZELTILECEK
s = add("Yalnızca Başlık"); setph(s, 0, "İyileştirme Alanı")
card(s, 0.6, 1.5, 5.9, 2.5, DRED)
tb(s, 0.85, 1.65, 5.4, 0.4, [("KADROLU ALIMDA KALMA ORANI", 11, True, GREY)])
tb(s, 0.85, 2.05, 5.4, 0.9, [("%95,7 → %75,0", 32, True, DRED)])
tb(s, 0.85, 2.95, 5.4, 0.95,
   [("İlk 14 günü tamamlama oranı. 32 alımdan 10'u kesim tarihine kadar ayrılmıştır (önceki yıl "
     "24 alımdan 2). Aynı pozisyonun iki kez doldurulması maliyet yaratmaktadır.", 11, False, INK)], sp=1.1)
card(s, 6.75, 1.5, 5.9, 2.5, MGREY)
tb(s, 7.0, 1.65, 5.4, 0.4, [("SEZONLUK KADRODA KALMA ORANI", 11, True, GREY)])
tb(s, 7.0, 2.05, 5.4, 0.9, [("%93,9 → %95,1", 32, True, YESIL)])
tb(s, 7.0, 2.95, 5.4, 0.95,
   [("Sezonluk kadroda kalma oranı yükselmiştir. Sorun sezonluk alımda değil, kadrolu alımın "
     "ilk haftasındadır.", 11, False, INK)], sp=1.1)

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
setph(s, 1, "Sezon dönemi kadrolu %+d · ürün adedi %s · personel başına iş %s"
            % (sezon_ici_26, yzd(d_adet), yzd(d_kb)))

pr.save(OUT)
print("Yazildi: %s (%d slayt)" % (OUT, len(pr.slides._sldIdLst)))
