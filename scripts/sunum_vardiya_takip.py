# -*- coding: utf-8 -*-
"""VARDIYA TAKIBI — magaza mudurleri toplantisi. V3: ANLATI + INFOGRAFIK.

NEDEN V3: GMY geri bildirimi — "hic olmamis, duygu aktarmiyor, infografik yok,
danisman lazim". V2 bir VERI DOKUMUYDU (kart+tablo+bar). V3 bir ANLATI:
insan -> yorgunluk -> sebep -> sistem -> risk -> rica.

IK DANISMAN KURULUNUN DUZELTTIGI IKI HATA (ik-danisman skill, 20.09):
 1. "Haftalik 45 saat asimi 335" YASAL IHLAL TABLOSUNDAN CIKARILDI. 45 saat
    NORMAL calisma sinridir; ustu fazla calismadir ve MESRUDUR. Skill bu hatanin
    17.09'da bir kez yapildigini yaziyordu (545 kisi-hafta) — V2 tekrarlamisti.
 2. "1.006.335 TL tek denetimin faturasi" SLAYTI KALDIRILDI. 209 kisinin
    HEPSINDE onay/kayit yok varsayimina dayaniyordu; bu OLCULMEDI. Ayrica
    perverse incentive: ceza korkusu mudurun kaydi DUZELTMESINI degil
    GUZELLESTIRMESINI tesvik eder (skill kural 6). Ceza artik tek slaytta ve
    "olabilecek" diye etiketli.

INSAN HIKAYESI — OLCULDU ve TEMIZ (KVKK: isim/sicil/sube YOK)
  ISO hafta 37, tek kisi: Pzt 09:00-20:31 · Sal 09:00-21:00 · Car 09:00-19:17 ·
  Per 09:00-21:07 · Cum 09:00-20:30 · Cmt 09:22-21:21 · Paz 09:02-21:03
  = 74,4 saat / 7 gun / 0 izin. Yedi gunun yedisi de "Normal Calisma" damgali.
  ⚠ ILK SECILEN HIKAYE ATILDI: 74,9 saatlik bir hafta bulunmustu ama Pazar
    12:08-34:15 (21,1 saat) idi — bu calisma DEGIL, unutulmus cikis okutmasi.
    Danismanin 3. tuzagi. Supheli + >12 saat elenerek yeniden secildi.
  ⚠ 140 yedi-gunluk haftanin 137'si TEMIZ (yalniz 3'unde bozuk kayit) -> baslik
    ayakta. Temiz haftalarin ortalamasi 56,8 saat.

KAPSAM: 4 MAGAZA (FSM · OZLUCE · IST.YOLU · HEYKEL). GM + kafeler + SURA haric.
  31.08-16.09.2026 = 17 GUN · 223 kisi · 3.589 kisi-gun · 23.927 saat calisma.
  Sube ADI hicbir slaytta GECMEZ (GMY karari: toplanti savunmaya donmesin).

OLCULMUS DIGER RAKAMLAR
  Fazla 2.699 sa · eksik 1.861 sa · 223 kisinin 150'si ikisini birden
  Fazla kaynak: fazla calisma 1.367 · hafta tatili primi 1.050 · izin iptali 250 · plansiz 31
  Cikistan sonra 1.346 sa (151 gun 2 saat ustu = 573 sa) · giristen once 631 sa
  Okutmasiz gun 559/3.589 · gunluk sapma 17 gunun 17'sinde %34-45
  Bordro (Agustos, sirket geneli): 4.265 sa fazla mesaiye 900.395 TL = 211 TL/saat
  Ceza (2026, iki kaynakla teyit): m.41 4.815 TL/isci · m.63/68/69/75 26.620 · m.37 9.944
"""
import os, re
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pptx.chart.data import CategoryChartData
from pptx.enum.chart import XL_CHART_TYPE
from pptx.oxml.ns import qn

TPL = r"C:\Users\fikri.eren\Desktop\Sunum.pptx"
OUT = r"C:\Users\fikri.eren\Desktop\Sunum_Vardiya.pptx"
SKILL = r"C:\Users\fikri.eren\.claude\skills\bkm-sunum\assets"
ICOW = os.path.join(SKILL, "_icons"); ICOR = os.path.join(SKILL, "_icons_red")

RED = RGBColor(0xE3, 0x06, 0x22); DRED = RGBColor(0xA6, 0x00, 0x1A); ROSE = RGBColor(0xC0, 0x14, 0x2B)
CHAR = RGBColor(0x2B, 0x2B, 0x2B); GREY = RGBColor(0x6E, 0x6E, 0x6E); LGREY = RGBColor(0xF2, 0xF2, 0xF2)
MGREY = RGBColor(0x9A, 0x9A, 0x9A); WHITE = RGBColor(0xFF, 0xFF, 0xFF); INK = RGBColor(0x33, 0x33, 0x33)
PALE = RGBColor(0xE6, 0xE6, 0xE6)
SET = [RED, ROSE, RGBColor(0x7A, 0x10, 0x20), RGBColor(0x4A, 0x4A, 0x4A), RGBColor(0x8C, 0x8C, 0x8C)]

import copy as _copy
from pptx.opc.constants import RELATIONSHIP_TYPE as RT

pr = Presentation(TPL); srcpr = Presentation(TPL)
TITLE_BG = srcpr.slides[0]; CONTENT_BG = srcpr.slides[1]


def L(name):
    for l in pr.slide_masters[0].slide_layouts:
        if l.name == name: return l
    return pr.slide_masters[0].slide_layouts[6]


def copy_bg(src, dst):
    bg = src._element.find(qn('p:cSld')).find(qn('p:bg'))
    if bg is None: return
    bg2 = _copy.deepcopy(bg)
    for blip in bg2.iter(qn('a:blip')):
        rid = blip.get(qn('r:embed'))
        if rid: blip.set(qn('r:embed'), dst.part.relate_to(src.part.related_part(rid), RT.IMAGE))
    dst._element.find(qn('p:cSld')).insert(0, bg2)


sld = pr.slides._sldIdLst
for sid in list(sld):
    try: pr.part.drop_rel(sid.get(qn('r:id')))
    except Exception: pass
    sld.remove(sid)


def add(name):
    sl = pr.slides.add_slide(L(name))
    copy_bg(TITLE_BG if name in ("Başlık Slaydı", "Bölüm Üst Bilgisi") else CONTENT_BG, sl)
    return sl


def setph(sl, idx, text):
    for ph in sl.placeholders:
        if ph.placeholder_format.idx == idx: ph.text = text; return ph
    return None


def tb(sl, x, y, w, h, runs, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, sp=1.0):
    bx = sl.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)); tf = bx.text_frame
    tf.word_wrap = True; tf.vertical_anchor = anchor
    if isinstance(runs, str): runs = [(runs, None, None, None)]
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
    if line: sh.line.color.rgb = line; sh.line.width = Pt(lw)
    else: sh.line.fill.background()
    sh.shadow.inherit = False; return sh


def circ(sl, x, y, d, bg, icon=None):
    c = sl.shapes.add_shape(MSO_SHAPE.OVAL, Inches(x), Inches(y), Inches(d), Inches(d))
    c.fill.solid(); c.fill.fore_color.rgb = bg; c.line.fill.background(); c.shadow.inherit = False
    if icon:
        ip = d * 0.55
        sl.shapes.add_picture(os.path.join(ICOW, icon + ".png"),
                              Inches(x + (d - ip) / 2), Inches(y + (d - ip) / 2), Inches(ip), Inches(ip))
    return c


def card(sl, x, y, w, h, top=None):
    rrect(sl, x, y, w, h, WHITE, RGBColor(0xE0, 0xE0, 0xE0))
    if top: rrect(sl, x, y, w, 0.07, top, rad=False)


def sig(sl):
    tb(sl, 9.3, 6.95, 3.4, 0.3, [("© BKM Kitap 2026", 9, False, MGREY)], align=PP_ALIGN.RIGHT)


def tablo(sl, rows, x, y, w, h, widths, fs=11.5):
    t = sl.shapes.add_table(len(rows), len(rows[0]), Inches(x), Inches(y), Inches(w), Inches(h)).table
    for i, cw in enumerate(widths): t.columns[i].width = Inches(cw)
    for r, row in enumerate(rows):
        for c, val in enumerate(row):
            cell = t.cell(r, c); cell.text = val
            for para in cell.text_frame.paragraphs:
                sayi = bool(re.fullmatch(r"[%\d.,]+(\s?(TL|₺|saat|sa))?", val))
                para.alignment = PP_ALIGN.RIGHT if (c > 0 and r > 0 and sayi) else PP_ALIGN.LEFT
                for run in para.runs:
                    run.font.size = Pt(fs); run.font.name = "Calibri"; run.font.bold = (r == 0)
                    run.font.color.rgb = WHITE if r == 0 else INK
            cell.fill.solid(); cell.fill.fore_color.rgb = RED if r == 0 else (LGREY if r % 2 else WHITE)
    return t


def ekran(sl, x, y, w, h, baslik):
    """TEMSİLÎ uygulama ekranı — gerçek ekran görüntüsü DEĞİL, etiketi öyle der."""
    rrect(sl, x, y, w, h, WHITE, RGBColor(0xC8, 0xC8, 0xC8), rad=False, lw=1.25)
    rrect(sl, x, y, w, 0.3, RGBColor(0xEC, 0xEC, 0xEC), rad=False)
    for i in range(3):
        circ(sl, x + 0.1 + i * 0.14, y + 0.1, 0.09, RGBColor(0xC0, 0xC0, 0xC0))
    tb(sl, x + 0.62, y + 0.02, w - 0.8, 0.26, [(baslik, 9, False, GREY)], anchor=MSO_ANCHOR.MIDDLE)
    return y + 0.3


def satir(sl, x, y, w, h, hucreler, kalin=False, zemin=None):
    if zemin is not None: rrect(sl, x, y, w, h, zemin, rad=False)
    cx = x + 0.12
    for metin, cw, col in hucreler:
        tb(sl, cx, y, cw, h, [(metin, 9, kalin, col)], anchor=MSO_ANCHOR.MIDDLE)
        cx += cw


# ══════════════════ 1 · KAPAK ══════════════════
s = add("Başlık Slaydı")
setph(s, 0, "Bir haftanın hikâyesi")
setph(s, 1, "Vardiya takibi neden önemli   ·   31 Ağustos – 16 Eylül 2026 · dört mağaza · 223 kişi")

# ══════════════════ 2 · BİR KİŞİNİN HAFTASI (timeline) ══════════════════
# ⚠ ÖRNEK İKİ KEZ DEĞİŞTİ, İKİSİNİ DE GMY YAKALADI:
#   (1) İlk hafta 74,9 saatti ama Pazar 12:08-34:15 idi -> unutulmuş çıkış okutması.
#   (2) İkinci hafta TEMİZDİ ama vardiyası 09:00-17:30'du — günlerin yalnız %5,9'u.
#       "Mağazalar öyle çalışmıyor" (GMY). Doğru: baskın vardiya 13:30-22:00 (%34,9).
#   Bu üçüncü örnek BASKIN vardiyadan: 7 günün 6'sı kapanış vardiyası.
#   ÖLÇÜLDÜ: 13:30-22:00 vardiyasının gerçek ritmi giriş 13:14 · çıkış 22:07 ·
#   çalışma 7,9 saat · fazla 50 dk -> GÜNLÜK DÜZEN OTURMUŞ. Mesaj bu yüzden
#   "her gün çok çalışıyorlar" DEĞİL, "yedinci gün yok" oldu.
s = add("Yalnızca Başlık"); setph(s, 0, "Ekibinizden birinin bir haftası")
# (ad, planBas, planBit, giris, cikis, fazlaDk) — ondalık saat
gunler = [("Pazartesi", 13.5, 22.0, 9.167, 20.700, 182), ("Salı", 13.5, 22.0, 13.500, 22.067, 4),
          ("Çarşamba", 10.0, 18.5, 10.000, 20.150, 99), ("Perşembe", 13.5, 22.0, 13.483, 22.383, 24),
          ("Cuma", 13.5, 22.0, 11.467, 22.033, 124), ("Cumartesi", 13.5, 22.0, 11.417, 22.050, 128),
          ("Pazar", 13.5, 22.0, 13.367, 22.583, 493)]
X0, X1, SA0, SA1 = 2.45, 11.05, 9.0, 23.0
def px(sa): return X0 + (X1 - X0) * (sa - SA0) / (SA1 - SA0)
for sa in (9, 11, 13, 15, 17, 19, 21, 23):
    tb(s, px(sa) - 0.3, 1.42, 0.6, 0.25, [("%02d:00" % sa, 8.5, False, MGREY)], align=PP_ALIGN.CENTER)
for i, (ad, pb, pt, g, c, fz) in enumerate(gunler):
    y = 1.78 + i * 0.6
    tb(s, 0.62, y, 1.75, 0.42, [(ad, 11.5, False, CHAR)], anchor=MSO_ANCHOR.MIDDLE)
    rrect(s, px(pb), y + 0.02, px(pt) - px(pb), 0.38, PALE, rad=False)
    if g < pb:
        rrect(s, px(g), y + 0.08, px(pb) - px(g), 0.26, RED, rad=False)
    rrect(s, px(max(g, pb)), y + 0.08, px(min(c, pt)) - px(max(g, pb)), 0.26,
          RGBColor(0x8C, 0x8C, 0x8C), rad=False)
    if c > pt:
        rrect(s, px(pt), y + 0.08, px(c) - px(pt), 0.26, RED, rad=False)
    tb(s, px(c) + 0.06, y, 1.6, 0.42,
       [("fazla %d dk" % fz, 10, True, RED if fz > 60 else GREY)], anchor=MSO_ANCHOR.MIDDLE)
tb(s, 2.45, 6.02, 9.2, 0.3,
   [("Açık gri: planlı vardiya (çoğu gün 13:30–22:00).  Koyu gri: plan içi.  Kırmızı: planın dışı.",
     9, False, MGREY)])
tb(s, 2.25, 6.35, 10.45, 0.45,
   [("Salı günü fazlası 4 dakika. Günlük düzen yerinde — eksik olan yedinci gün.",
     14.5, True, DRED)], anchor=MSO_ANCHOR.MIDDLE)
sig(s)

# ══════════════════ 3 · BU TEK KİŞİ DEĞİL (dot grid) ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Yedinci gün kimde yok?")
# 223 nokta · 109'u kirmizi (bir hafta hic izin kullanmamis)
KOL, D, BOS = 25, 0.17, 0.235
for i in range(223):
    r, c = divmod(i, KOL)
    circ(s, 0.75 + c * BOS, 1.6 + r * BOS, D, RED if i < 109 else PALE)
tb(s, 0.75, 1.6 + 9 * BOS + 0.15, 6.4, 0.5,
   [("223 kişi  ·  kırmızı olanlar bir hafta boyunca hiç izin kullanmadı", 11.5, False, GREY)])
card(s, 7.2, 1.55, 5.5, 1.5, RED)
tb(s, 7.5, 1.72, 5.0, 0.7, [("109 kişi", 34, True, RED)])
tb(s, 7.5, 2.45, 5.0, 0.5, [("iki kişiden biri", 13, False, GREY)])
card(s, 7.2, 3.2, 5.5, 1.35, ROSE)
tb(s, 7.5, 3.35, 5.0, 0.55, [("137 hafta", 24, True, CHAR)])
tb(s, 7.5, 3.92, 5.0, 0.5, [("yedi günün yedisi de çalışılmış", 11.5, False, GREY)])
card(s, 7.2, 4.7, 5.5, 1.35, RGBColor(0x4A, 0x4A, 0x4A))
tb(s, 7.5, 4.85, 5.0, 0.55, [("56,8 saat", 24, True, CHAR)])
tb(s, 7.5, 5.42, 5.0, 0.5, [("o haftaların ortalaması", 11.5, False, GREY)])
tb(s, 2.25, 6.3, 10.45, 0.5,
   [("Yasal normal çalışma haftada 45 saat. Bu haftaların ortalaması 56,8.", 12.5, False, GREY)],
   anchor=MSO_ANCHOR.MIDDLE)
sig(s)

# ══════════════════ 4 · AKŞAMLAR ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Akşamlar nereye gidiyor?")
cd = CategoryChartData()
cd.categories = ["15 dk'ya kadar", "16–30 dk", "31–60 dk", "1–2 saat", "2 saatten fazla"]
cd.add_series("saat", (112.7, 142.3, 171.1, 346.4, 573.4))
bc = s.shapes.add_chart(XL_CHART_TYPE.COLUMN_CLUSTERED, Inches(0.6), Inches(1.5), Inches(7.5), Inches(3.9), cd).chart
bc.has_legend = False; bc.has_title = False
bc.plots[0].has_data_labels = True; bc.plots[0].vary_by_categories = False
bc.series[0].format.fill.solid(); bc.series[0].format.fill.fore_color.rgb = RED
card(s, 8.4, 1.5, 4.3, 1.75, RED)
tb(s, 8.65, 1.68, 3.8, 0.7, [("151", 36, True, RED)])
tb(s, 8.65, 2.38, 3.8, 0.75, [("akşam, biri iki saatten fazla kaldı", 12, False, GREY)], sp=1.1)
card(s, 8.4, 3.4, 4.3, 1.75, RGBColor(0x4A, 0x4A, 0x4A))
tb(s, 8.65, 3.58, 3.8, 0.7, [("573", 36, True, CHAR)])
tb(s, 8.65, 4.28, 3.8, 0.75, [("saat — sadece o akşamlarda", 12, False, GREY)], sp=1.1)
tb(s, 0.6, 5.55, 12.1, 0.95,
   [("Çıkıştan sonra toplam 1.346 saat, girişten önce 631 saat.", 14, True, DRED),
    ("Hiçbiri planlanmadı. Çoğu konuşulmadı bile — ama kart kaydında duruyor.", 13, False, INK)], sp=1.2)
sig(s)

# ══════════════════ 5 · İYİ GÜN YOK (ısı şeridi) ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "İyi bir gün yok")
oran = [40, 37, 41, 42, 39, 40, 43, 35, 34, 38, 43, 42, 38, 41, 42, 45, 45]
etiket = ["31.08", "01.09", "02.09", "03.09", "04.09", "05.09", "06.09", "07.09", "08.09",
          "09.09", "10.09", "11.09", "12.09", "13.09", "14.09", "15.09", "16.09"]
GW = 0.69
for i, (o, e) in enumerate(zip(oran, etiket)):
    x = 0.62 + i * GW
    t = (o - 33) / 13.0                       # 34→45 arasi tonlama
    col = RGBColor(0xE3, int(0x06 + (1 - t) * 0x90), int(0x22 + (1 - t) * 0x70))
    rrect(s, x, 1.7, GW - 0.08, 1.5, col, rad=False)
    tb(s, x, 2.05, GW - 0.08, 0.5, [("%%%d" % o, 13, True, WHITE)], align=PP_ALIGN.CENTER)
    tb(s, x, 3.25, GW - 0.08, 0.3, [(e, 8.5, False, GREY)], align=PP_ALIGN.CENTER)
tb(s, 0.62, 3.75, 12.1, 0.6,
   [("Her karede o günün sapma oranı: plana uymayan kişi-günlerin payı.", 12, False, GREY)])
rrect(s, 0.6, 4.4, 12.1, 1.5, LGREY, RED, lw=2)
tb(s, 1.0, 4.4, 11.3, 1.5,
   [("17 günün 17'sinde de sapma var. En iyi gün %34, en kötü gün %45.", 17, True, DRED),
    ("Yani bu bir “kötü hafta” değil. Böyle çalışıyoruz.", 14, False, INK)],
   anchor=MSO_ANCHOR.MIDDLE, sp=1.25)
sig(s)

# ══════════════════ 6 · BÖLÜM — SEBEP ══════════════════
s = add("Bölüm Üst Bilgisi"); setph(s, 0, "Peki bu neden oluyor?")
setph(s, 1, "Sebep insanlar değil — plan")

# ══════════════════ 7 · FAZLA MESAİ NEREDEN ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Fazla mesai nereden geliyor?")
kay = [("Vardiya uzamış", 1367.1, "Kapanış sarkıyor, planlı bitiş tutmuyor"),
       ("Tatil gününde çalışılmış", 1050.0, "Hafta tatili primi — dinlenme günü kullanılmamış"),
       ("İzin kullandırılmamış", 250.0, "Planlı izin iptal edilmiş"),
       ("Planı olmayan gün", 31.4, "Vardiya tanımsız çalışma")]
for i, (h, v, d) in enumerate(kay):
    y = 1.55 + i * 1.02
    tb(s, 0.62, y, 4.0, 0.4, [(h, 13.5, True, CHAR)])
    tb(s, 0.62, y + 0.38, 4.2, 0.55, [(d, 10.5, False, GREY)], sp=1.05)
    bw = 6.9 * (v / 1367.1)
    rrect(s, 5.0, y + 0.06, max(bw, 0.35), 0.5, SET[i], rad=False)
    tb(s, 5.12 + max(bw, 0.35), y, 1.6, 0.62,
       [("%s sa" % ("{:,.0f}".format(v).replace(",", ".")), 14, True, CHAR)], anchor=MSO_ANCHOR.MIDDLE)
rrect(s, 0.6, 5.7, 12.1, 0.8, LGREY, RED, lw=2)
tb(s, 1.0, 5.7, 11.3, 0.8,
   [("İlk iki kalem toplamın %89'u. İkisi de planlama kararı — kimsenin niyeti değil.", 13.5, True, DRED)],
   anchor=MSO_ANCHOR.MIDDLE)
sig(s)

# ══════════════════ 8 · GÖRÜNMEYEN YARI ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Bir de göremediğimiz günler var")
SATIR2, KOL2, D2, B2 = 10, 12, 0.33, 0.45   # 120 kare = her kare ~30 kisi-gun
kirmizi = round(120 * 559 / 3589)
for c in range(KOL2):                        # SUTUN-ONCELIKLI: blok solda toplanir
    for r in range(SATIR2):
        i = c * SATIR2 + r
        rrect(s, 0.75 + c * B2, 1.6 + r * B2, D2, D2, RED if i < kirmizi else PALE, rad=False)
tb(s, 2.25, 6.35, 10.45, 0.4,
   [("Her kare ≈ 30 kişi-gün. Kırmızı olanlarda giriş de çıkış da okutulmamış.", 11, False, GREY)],
   anchor=MSO_ANCHOR.MIDDLE)
card(s, 6.4, 1.55, 6.3, 1.6, RED)
tb(s, 6.65, 1.75, 5.8, 0.7, [("559 gün", 30, True, RED)])
tb(s, 6.65, 2.45, 5.8, 0.55, [("3.589 günün içinde okutmasız", 12, False, GREY)])
tb(s, 6.4, 3.35, 6.3, 2.4,
   [("Okutma olmayan gün, sonradan doldurulamaz.", 15, True, DRED),
    ("Kart kaydı işçinin imzası sayılır. O gün okutulmadıysa, ne kadar çalışıldığını "
     "sonradan kimse kanıtlayamaz — ne şirket, ne çalışan.", 12.5, False, INK)], sp=1.2)
rrect(s, 6.4, 5.2, 6.3, 0.8, LGREY, RED, lw=2)
tb(s, 6.65, 5.2, 5.8, 0.8,
   [("97 günde hiç PDKS kaydı yok, 186 günde ham okutma bile yok.", 12, True, DRED)],
   anchor=MSO_ANCHOR.MIDDLE)
sig(s)

# ══════════════════ 9 · BÖLÜM — SİSTEM ══════════════════
s = add("Bölüm Üst Bilgisi"); setph(s, 0, "Artık canlı görüyoruz")
setph(s, 1, "Mail ile takip bitti")

# ══════════════════ 10 · MAİL vs CANLI ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Fark hız değil, zamanında olmak")
card(s, 0.6, 1.5, 5.9, 2.6, RGBColor(0x8C, 0x8C, 0x8C))
tb(s, 0.9, 1.7, 5.4, 0.35, [("ESKİ · MAİL", 11, True, GREY)])
for i, t in enumerate(["Ay bitince Excel gelir", "Rakam 2-3 hafta gecikir",
                       "Kim neyi onayladı belirsiz", "İtiraz mail zincirinde kaybolur",
                       "Düzeltme zamanı çoktan geçmiştir"]):
    tb(s, 0.9, 2.12 + i * 0.37, 5.4, 0.35, [("·  " + t, 12, False, INK)])
card(s, 6.8, 1.5, 5.9, 2.6, RED)
tb(s, 7.1, 1.7, 5.4, 0.35, [("YENİ · CANLI", 11, True, RED)])
for i, t in enumerate(["Rakam gün içinde görünür", "Herkes kendi mağazasını görür",
                       "Onay ve itiraz ekranda", "Kim ne zaman yaptı kayıtlı",
                       "Ay kapanmadan düzeltilir"]):
    tb(s, 7.1, 2.12 + i * 0.37, 5.4, 0.35, [("·  " + t, 12, False, INK)])
ok = [("Bugün olan", "bugün görünür"), ("Yanlışsa", "bugün düzelir"), ("Sonra", "tartışma çıkmaz")]
for i, (h, d) in enumerate(ok):
    x = 0.6 + i * 4.15; card(s, x, 4.4, 3.9, 1.15, SET[i])
    tb(s, x + 0.25, 4.55, 3.4, 0.38, [(h, 13, True, CHAR)])
    tb(s, x + 0.25, 4.93, 3.45, 0.45, [(d, 12, False, GREY)])
rrect(s, 0.6, 5.75, 12.1, 0.7, LGREY, RED, lw=2)
tb(s, 1.0, 5.75, 11.3, 0.7,
   [("Ay kapandıktan sonra gelen rakam bilgi verir ama hiçbir şeyi değiştiremez.", 13.5, True, DRED)],
   anchor=MSO_ANCHOR.MIDDLE)
sig(s)

# ══════════════════ 11 · EKRAN 1 ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Müdürün gördüğü ekran")
ty = ekran(s, 0.6, 1.45, 8.3, 4.5, "bkm vardiya  ·  Mesai Raporu")
rrect(s, 0.6, ty, 8.3, 0.52, RED, rad=False)
tb(s, 0.75, ty, 5.0, 0.52, [("Kesim: 31.08 – 16.09.2026", 10.5, True, WHITE)], anchor=MSO_ANCHOR.MIDDLE)
tb(s, 6.3, ty, 2.45, 0.52, [("Mağazam ▾", 10.5, False, WHITE)], anchor=MSO_ANCHOR.MIDDLE, align=PP_ALIGN.RIGHT)
ky = ty + 0.62
for i, (v, l) in enumerate([("50", "kişi"), ("334", "saat eksik"), ("457", "saat fazla"), ("258", "istisna")]):
    kx = 0.75 + i * 2.0
    rrect(s, kx, ky, 1.85, 0.85, LGREY, RGBColor(0xDD, 0xDD, 0xDD), rad=False)
    tb(s, kx, ky + 0.06, 1.85, 0.42, [(v, 17, True, RED if i else CHAR)], align=PP_ALIGN.CENTER)
    tb(s, kx, ky + 0.48, 1.85, 0.3, [(l, 8.5, False, GREY)], align=PP_ALIGN.CENTER)
ry = ky + 1.05
satir(s, 0.68, ry, 8.14, 0.32,
      [("Personel", 1.9, WHITE), ("Tarih", 0.95, WHITE), ("Giriş", 0.8, WHITE),
       ("Çıkış", 0.8, WHITE), ("Durum", 2.85, WHITE), ("Onay", 0.85, WHITE)],
      kalin=True, zemin=RGBColor(0x4A, 0x4A, 0x4A))
veri = [("A. Y****", "07.09", "09:10", "20:42", "Erken giriş · fazla 182 dk", "bekliyor"),
        ("M. K****", "01.09", "—", "—", "PDKS kaydı yok", "bekliyor"),
        ("S. D****", "09.09", "12:10", "21:04", "Vardiya tanımsız", "bekliyor"),
        ("H. T****", "14.09", "13:14", "23:59", "Kapanış sarktı · fazla 135 dk", "onaylı"),
        ("E. B****", "15.09", "13:22", "00:12", "Gün dönümü", "bekliyor")]
for i, r in enumerate(veri):
    yy = ry + 0.32 + i * 0.34
    col = RED if r[5] == "bekliyor" else RGBColor(0x4A, 0x4A, 0x4A)
    satir(s, 0.68, yy, 8.14, 0.34,
          [(r[0], 1.9, INK), (r[1], 0.95, INK), (r[2], 0.8, INK), (r[3], 0.8, INK),
           (r[4], 2.85, INK), (r[5], 0.85, col)], zemin=(LGREY if i % 2 == 0 else WHITE))
for i, (h, d, col) in enumerate([("KENDİ MAĞAZASI", "Başka mağaza görünmez.", RED),
                                 ("BEKLEYENLER ÜSTTE", "Aranmıyor, karşınıza geliyor.", ROSE),
                                 ("GÜN İÇİNDE", "Ay sonu beklenmiyor.", RGBColor(0x4A, 0x4A, 0x4A))]):
    yy = 1.45 + i * 1.55
    card(s, 9.2, yy, 3.5, 1.4, col)
    tb(s, 9.45, yy + 0.16, 3.0, 0.38, [(h, 10, True, col if i < 2 else GREY)])
    tb(s, 9.45, yy + 0.55, 3.0, 0.75, [(d, 11, False, GREY)], sp=1.1)
tb(s, 0.6, 6.05, 12.1, 0.4, [("Temsilî ekrandır; isimler kısaltılmıştır.", 10, False, MGREY)])
sig(s)

# ══════════════════ 12 · EKRAN 2 ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Onay ve itiraz aynı yerde")
ty = ekran(s, 0.6, 1.45, 7.2, 4.55, "bkm vardiya  ·  Gün Detayı  ·  13.09.2026")
tb(s, 0.8, ty + 0.12, 6.8, 0.4, [("A. Y****   ·   13 Eylül 2026 Pazar  ·  bu haftanın 7. çalışma günü", 12, True, CHAR)])
for i, (etiket, deger) in enumerate([("Planlı vardiya", "13:30 – 22:00   (kapanış vardiyası)"),
                                     ("Okutulan giriş", "13:22"),
                                     ("Okutulan çıkış", "22:35"),
                                     ("Hesaplanan", "8 sa 12 dk çalışma  ·  haftanın 7. günü")]):
    yy = ty + 0.55 + i * 0.38
    rrect(s, 0.8, yy, 6.8, 0.38, LGREY if i % 2 == 0 else WHITE, rad=False)
    tb(s, 0.95, yy, 2.4, 0.38, [(etiket, 9.5, False, GREY)], anchor=MSO_ANCHOR.MIDDLE)
    tb(s, 3.4, yy, 4.1, 0.38, [(deger, 9.5, True, INK)], anchor=MSO_ANCHOR.MIDDLE)
sy = ty + 2.25
tb(s, 0.8, sy, 6.8, 0.32, [("Müdür kararı", 10, True, CHAR)])
for i, (m, secili) in enumerate([("Bir şey söylemiyorum", False), ("İzinliydi", False),
                                 ("İzinli değildi (kaynağa itiraz)", True)]):
    yy = sy + 0.34 + i * 0.36
    o = circ(s, 0.95, yy + 0.07, 0.16, RED if secili else WHITE)
    o.line.color.rgb = RED if secili else RGBColor(0xBB, 0xBB, 0xBB)
    tb(s, 1.25, yy, 6.2, 0.32, [(m, 10, secili, INK if secili else GREY)], anchor=MSO_ANCHOR.MIDDLE)
by = sy + 1.36
rrect(s, 0.95, by, 1.5, 0.42, RED, rad=False)
tb(s, 0.95, by, 1.5, 0.42, [("Kaydet", 10.5, True, WHITE)], align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
tb(s, 2.6, by, 4.8, 0.42, [("Kaydeden ve saat otomatik yazılır.", 9.5, False, MGREY)], anchor=MSO_ANCHOR.MIDDLE)
card(s, 8.1, 1.45, 4.6, 4.55, RED)
tb(s, 8.35, 1.62, 4.1, 0.4, [("HER İŞLEM İZ BIRAKIR", 11, True, RED)])
for i, (h, d) in enumerate([("Kim yaptı", "Kullanıcı adı kayıtlı"), ("Ne zaman", "Saniye hassasiyetinde"),
                            ("Neyi değiştirdi", "Eski ve yeni değer"), ("Silinebilir mi", "Hayır — iz kalıcı")]):
    yy = 2.15 + i * 0.88
    tb(s, 8.35, yy, 4.1, 0.34, [(h, 11.5, True, CHAR)])
    tb(s, 8.35, yy + 0.32, 4.1, 0.34, [(d, 10.5, False, GREY)])
tb(s, 8.35, 5.65, 4.1, 0.3, [("Mail zincirinde bu yoktu.", 10.5, True, DRED)])
tb(s, 0.6, 6.05, 12.1, 0.4, [("Temsilî ekrandır; isimler kısaltılmıştır.", 10, False, MGREY)])
sig(s)

# ══════════════════ 13 · ARKA PLANDAKİ RİSK ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Bir de arka planda bunlar var")
card(s, 0.6, 1.5, 5.9, 2.0, RED)
tb(s, 0.9, 1.7, 5.4, 0.35, [("ÖDENEN", 11, True, RED)])
tb(s, 0.9, 2.05, 5.4, 0.7, [("570 bin ₺", 30, True, CHAR)])
tb(s, 0.9, 2.78, 5.4, 0.6, [("17 günde, dört mağazada fazla mesai. Saat başı 211 ₺ — Ağustos "
                             "bordrosunun şirket ortalaması.", 11, False, GREY)], sp=1.1)
card(s, 6.8, 1.5, 5.9, 2.0, RGBColor(0x8C, 0x8C, 0x8C))
tb(s, 7.1, 1.7, 5.4, 0.35, [("ÖDENEBİLECEK", 11, True, GREY)])
tb(s, 7.1, 2.05, 5.4, 0.7, [("4.815 ₺ / kişi", 26, True, CHAR)])
tb(s, 7.1, 2.78, 5.4, 0.6, [("Fazla çalışma onayı ve kaydı gösterilemeyen her işçi için "
                             "idari para cezası.", 11, False, GREY)], sp=1.1)
rows = [("Kayıt istendiğinde bulunamazsa", "2026 cezası"),
        ("Çalışma sürelerine aykırılık", "26.620 ₺"),
        ("Ara dinlenme verilmemesi", "26.620 ₺"),
        ("Özlük dosyası eksikliği", "26.620 ₺"),
        ("Ücret hesap pusulası", "9.944 ₺")]
tablo(s, rows, 0.6, 3.75, 12.1, 1.9, [8.6, 3.5], fs=12)
rrect(s, 0.6, 5.8, 12.1, 0.75, LGREY, RED, lw=2)
tb(s, 1.0, 5.8, 11.3, 0.75,
   [("Bunlar kesinleşmiş değil, olabilecek tutarlar. ", 13, True, DRED),
    ("Kaydı olan hiçbir satır burada açılmaz.", 13, False, INK)],
   anchor=MSO_ANCHOR.MIDDLE)
sig(s)

# ══════════════════ 14 · ÜÇ RİCA ══════════════════
s = add("Yalnızca Başlık"); setph(s, 0, "Sizden istediğimiz üç şey")
rica = [("zap", "1 · Herkes kart okutsun — her giriş, her çıkış",
         "Okutma yoksa o gün kanıtlanamıyor. 17 günde 559 gün okutmasız geçti."),
        ("workflow", "2 · Yedinci günü boş bırakın",
         "Altı gün çalışan dinlenir. 137 haftada bu olmadı."),
        ("circle-check", "3 · İstisnayı onaylayın ya da itiraz edin",
         "Panelde tek tıkla. “İzinliydi” ya da “izinli değildi” demeniz yeter.")]
for i, (ic, h, d) in enumerate(rica):
    y = 1.5 + i * 1.38
    card(s, 0.6, y, 12.1, 1.22, SET[i]); circ(s, 0.9, y + 0.25, 0.7, RED, ic)
    tb(s, 1.85, y + 0.16, 10.5, 0.42, [(h, 15.5, True, CHAR)])
    tb(s, 1.85, y + 0.62, 10.5, 0.5, [(d, 12, False, GREY)])
rrect(s, 0.6, 5.7, 12.1, 0.75, LGREY, RED, lw=2)
tb(s, 1.0, 5.7, 11.3, 0.75,
   [("Rapor yazmanızı, form doldurmanızı istemiyoruz. Üçü de zaten yaptığınız işin parçası.",
     13.5, True, DRED)], anchor=MSO_ANCHOR.MIDDLE)
sig(s)

# ══════════════════ 15 · KAPANIŞ ══════════════════
s = add("Başlık Slaydı")
setph(s, 0, "Ölçtüğümüz şey saat değil — insanın yorgunluğu.")
setph(s, 1, "Görünürse yönetilir   ·   31 Ağustos – 16 Eylül 2026 ölçümü   ·   © BKM Kitap 2026")

pr.save(OUT)
print("KAYDEDILDI:", OUT, "| slayt:", len(pr.slides._sldIdLst))
