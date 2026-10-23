# -*- coding: utf-8 -*-
"""İst.Yolu Kültür norm 4 → 5 — tek slayt, BKM şablonu (bkm-sunum skill kalıbı)."""
import copy as _copy
import shutil
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pptx.oxml.ns import qn
from pptx.opc.constants import RELATIONSHIP_TYPE as RT

TPL = r"C:\Users\fikri.eren\Desktop\Sunum.pptx"
OUT = r"D:\Dev\pusula\briefings\2026-10-15\istyolu-kultur-norm.pptx"
DESK = r"C:\Users\fikri.eren\Desktop\IstYolu_Kultur_Norm.pptx"

RED = RGBColor(0xE3, 0x06, 0x22); DRED = RGBColor(0xA6, 0x00, 0x1A); ROSE = RGBColor(0xC0, 0x14, 0x2B)
CHAR = RGBColor(0x2B, 0x2B, 0x2B); GREY = RGBColor(0x6E, 0x6E, 0x6E); LGREY = RGBColor(0xF2, 0xF2, 0xF2)
MGREY = RGBColor(0x9A, 0x9A, 0x9A); WHITE = RGBColor(0xFF, 0xFF, 0xFF); INK = RGBColor(0x33, 0x33, 0x33)
BORDER = RGBColor(0xE0, 0xE0, 0xE0); PINK = RGBColor(0xFD, 0xE8, 0xEA)

pr = Presentation(TPL)
src = Presentation(TPL)
CONTENT_BG = src.slides[1]


def L(name):
    for l in pr.slide_masters[0].slide_layouts:
        if l.name == name:
            return l
    return pr.slide_masters[0].slide_layouts[6]


def copy_bg(s, d):
    bg = s._element.find(qn('p:cSld')).find(qn('p:bg'))
    if bg is None:
        return
    bg2 = _copy.deepcopy(bg)
    for blip in bg2.iter(qn('a:blip')):
        rid = blip.get(qn('r:embed'))
        if rid:
            blip.set(qn('r:embed'), d.part.relate_to(s.part.related_part(rid), RT.IMAGE))
    d._element.find(qn('p:cSld')).insert(0, bg2)


sld = pr.slides._sldIdLst
for sid in list(sld):
    try:
        pr.part.drop_rel(sid.get(qn('r:id')))
    except KeyError:
        pass
    sld.remove(sid)


def tb(sl, x, y, w, h, runs, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, sp=1.0):
    bx = sl.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h)); tf = bx.text_frame
    tf.word_wrap = True; tf.vertical_anchor = anchor
    for m in ("margin_left", "margin_right", "margin_top", "margin_bottom"):
        setattr(tf, m, Inches(0.02))
    first = True
    for txt, sz, bd, col in runs:
        p = tf.paragraphs[0] if first else tf.add_paragraph(); first = False
        p.alignment = align; p.line_spacing = sp
        r = p.add_run(); r.text = txt; r.font.size = Pt(sz); r.font.bold = bool(bd)
        r.font.name = "Calibri"; r.font.color.rgb = col or INK
    return bx


def rrect(sl, x, y, w, h, fill, line=None, rad=True):
    sh = sl.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE if rad else MSO_SHAPE.RECTANGLE,
                             Inches(x), Inches(y), Inches(w), Inches(h))
    sh.fill.solid(); sh.fill.fore_color.rgb = fill
    if line:
        sh.line.color.rgb = line; sh.line.width = Pt(1)
    else:
        sh.line.fill.background()
    sh.shadow.inherit = False
    if rad:
        sh.adjustments[0] = 0.08
    return sh


s = pr.slides.add_slide(L("Yalnızca Başlık"))
copy_bg(CONTENT_BG, s)
for ph in s.placeholders:
    if ph.placeholder_format.idx == 0:
        ph.text = "İst.Yolu Kültür reyonu: norm 4'ten 5'e"

# ---- 1) dört KPI kartı ----
kpi = [
    ("38,5 milyon TL", "Son 12 ayda Kitap satışı.", "FSM 39,4 milyon TL. FSM normu 5, İst.Yolu 4."),
    ("%17", "Asma kat: raflamanın %17'si.", "Satışın %6'sı. Kültür raflarının %22'si orada."),
    ("%59", "Sabah 10-13 tek kişi.", "Akşam sürenin %79'unda 2 kişi: katta birer."),
    ("%1,6", "+1 kişinin Kitap satışına oranı.", "Yılda yaklaşık 608 bin TL."),
]
x0, y0, w, h, gap = 0.6, 1.62, 2.95, 1.20, 0.17
for i, (big, l1, l2) in enumerate(kpi):
    x = x0 + i * (w + gap)
    rrect(s, x, y0, w, h, WHITE, BORDER, rad=False)
    rrect(s, x, y0, 0.08, h, RED, rad=False)
    tb(s, x + 0.22, y0 + 0.06, w - 0.3, 0.5, [(big, 24, True, RED)])
    tb(s, x + 0.22, y0 + 0.56, w - 0.3, 0.3, [(l1, 11.5, True, CHAR)])
    tb(s, x + 0.22, y0 + 0.84, w - 0.3, 0.33, [(l2, 10, False, GREY)])

# ---- 2) norm kişi başına tablo ----
ty = 3.0
tb(s, 0.6, ty, 7.9, 0.32, [("Norm kişi başına yük", 13, True, CHAR)])
rows = [
    ("", "FSM", "Özlüce", "İst.Yolu (4)", "İst.Yolu (5)"),
    ("Yıllık Kitap satışı", "7,9 mn TL", "8,4 mn TL", "9,6 mn TL", "7,7 mn TL"),
    ("Yıllık Kitap adedi", "31.700", "32.800", "37.100", "29.700"),
    ("Raf", "394", "402", "676", "541"),
    ("Stok adedi", "19.500", "17.300", "33.400", "26.700"),
    ("Yıllık raflama", "32.800", "15.000", "42.100", "33.600"),
]
gt = s.shapes.add_table(len(rows), 5, Inches(0.6), Inches(ty + 0.36), Inches(7.9), Inches(2.04))
t = gt.table
cw = [2.3, 1.3, 1.3, 1.5, 1.5]
for j, c in enumerate(cw):
    t.columns[j].width = Inches(c)
for i, row in enumerate(rows):
    t.rows[i].height = Inches(0.33)
    for j, val in enumerate(row):
        cell = t.cell(i, j)
        cell.margin_left = cell.margin_right = Inches(0.08)
        cell.vertical_anchor = MSO_ANCHOR.MIDDLE
        hdr = i == 0
        cur = j == 3
        cell.fill.solid()
        if hdr:
            cell.fill.fore_color.rgb = RED if cur else (DRED if j == 4 else RGBColor(0x4A, 0x4A, 0x4A))
        elif cur:
            cell.fill.fore_color.rgb = PINK
        else:
            cell.fill.fore_color.rgb = WHITE if i % 2 else LGREY
        tf = cell.text_frame; tf.word_wrap = True
        p = tf.paragraphs[0]; p.alignment = PP_ALIGN.LEFT if j == 0 else PP_ALIGN.RIGHT
        r = p.add_run(); r.text = val; r.font.name = "Calibri"
        r.font.size = Pt(12 if hdr else 12.5)
        r.font.bold = hdr or cur
        r.font.color.rgb = WHITE if hdr else (RED if cur else CHAR)

# ---- 3) sağ panel: yük artıyor ----
px, pw = 8.75, 3.95
rrect(s, px, ty + 0.36, pw, 2.04, WHITE, BORDER, rad=False)
rrect(s, px, ty + 0.36, pw, 0.07, RED, rad=False)
tb(s, px, ty, pw, 0.32, [("Yük artıyor", 13, True, CHAR)])
tb(s, px + 0.22, ty + 0.5, pw - 0.4, 0.3,
   [("Kitap içeren fiş, geçen yılın aynı dönemine göre", 10, False, GREY)])
trend = [("+%30", "İst.Yolu · Eylül"), ("+%60", "İst.Yolu · Ekim 1-14"), ("−%6", "FSM · Eylül")]
for k, (v, lab) in enumerate(trend):
    yy = ty + 0.85 + k * 0.45
    tb(s, px + 0.22, yy, 1.25, 0.42, [(v, 20, True, RED if k < 2 else GREY)])
    tb(s, px + 1.5, yy + 0.08, pw - 1.7, 0.32, [(lab, 12, False, CHAR)])

# ---- 4) mesaj şeridi ----
my = 5.58
rrect(s, 0.6, my, 12.1, 0.42, RED, rad=False)
tb(s, 0.8, my, 11.8, 0.42,
   [("5. kişiyle satış yükü FSM ve Özlüce'nin hemen altına iniyor. Raf, stok ve raflama yükü yine en yüksek. Maliyeti satışın %1,6'sı.", 13, True, WHITE)],
   anchor=MSO_ANCHOR.MIDDLE)

# ---- 5) dipnot ----
tb(s, 0.6, 6.02, 12.1, 0.25,
   [("Kaynak: kasa satışı Eki 2025–Eyl 2026 (Sınav belgesi ve ürünü hariç) · PDKS 28.09–14.10.2026 · "
     "raf/stok 15.10.2026 · raflama kayıtları Eki 2025–Eyl 2026 · bordro Eylül 2026. Norm kişi başı = yıllık değer ÷ norm.",
     8.5, False, MGREY)])

tb(s, 9.3, 6.95, 3.4, 0.3, [("© Fikri Eren 2026", 9, False, MGREY)], align=PP_ALIGN.RIGHT)

import os
os.makedirs(os.path.dirname(OUT), exist_ok=True)
pr.save(OUT)
shutil.copyfile(OUT, DESK)
print("OK", OUT, DESK, pr.slide_width / 914400, pr.slide_height / 914400)
