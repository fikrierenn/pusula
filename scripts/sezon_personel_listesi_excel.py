# -*- coding: utf-8 -*-
"""Sezon kohortu KISI LISTESI + gun gun hareket -> Excel (emitter).

Cekirdek (kohort penceresi / Kadro='SEZONLUK' ayraci / aktif tanimi)
sorgular/2026-09-02-sezon-personel-kohort-magaza.sql dosyasindadir.
Bu script bicimlendirir; gunluk hareket tablosu satir SAYIMI (pivot), is
mantigi degil -- esik/filtre/tanim SQL tarafinda (.claude/rules/emitter-ayrimi.md).

⚠ KISISEL VERI: cikti ad-soyad + personel no icerir. Dosya .gitignore'da olmali,
paylasim yetkili kisiyle sinirli (KVKK veri minimizasyonu: ucret/cinsiyet/ogrenim
bu ciktida YOK).

Girdi : kisi satirlari JSON (MCP zirve sql_query ciktisinin rows dizisi)
        alanlar: Personelno AdSoyad Kadro Sube Departman Unvan
                 GirisTarihi(dd.MM.yyyy) CikisTarihi KalisGun Kohort CikisKodu
Cikti : xlsx -- Gun-Gun-<yil> (hareket ozeti) + Liste-<yil> (kisi listesi)

Kullanim:
    python scripts/sezon_personel_listesi_excel.py <rows.json> <cikti.xlsx>
"""
import json
import sys
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

BASLIK_DOLGU = PatternFill("solid", fgColor="E30622")
BASLIK_YAZI = Font(bold=True, color="FFFFFF", size=10)
SEZON_DOLGU = PatternFill("solid", fgColor="F2F2F2")
AYRILDI_YAZI = Font(color="A2382B")
ZIRVE_DOLGU = PatternFill("solid", fgColor="FFF3CD")   # en yogun alim gunu
INCE = Side(style="thin", color="D9D9D9")
KENAR = Border(left=INCE, right=INCE, top=INCE, bottom=INCE)
NOT_YAZI = Font(italic=True, size=9, color="666666")
TARIH = "DD.MM.YYYY"


def _gun(s):
    return datetime.strptime(s, "%d.%m.%Y").date() if s else None


def _basliklar(ws, kolonlar):
    ws.append([k[0] for k in kolonlar])
    for i, (_, gen, _f) in enumerate(kolonlar, start=1):
        ws.column_dimensions[get_column_letter(i)].width = gen
    for h in ws[1]:
        h.fill = BASLIK_DOLGU
        h.font = BASLIK_YAZI
        h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        h.border = KENAR
    ws.row_dimensions[1].height = 30
    ws.freeze_panes = "A2"


def _bicim(ws, kolonlar, ilk=2):
    for satir in ws.iter_rows(min_row=ilk):
        for h, (_, _g, fmt) in zip(satir, kolonlar):
            h.border = KENAR
            if fmt:
                h.number_format = fmt


def sayfa_gun_gun(wb, satirlar, yil, son_gun):
    """Gun bazli giris/cikis hareketi + kumulatif sahadaki kisi."""
    kolonlar = [
        ("Tarih", 13, TARIH), ("Gun", 11, None),
        ("Giren sezonluk", 13, "0"), ("Giren kadrolu", 13, "0"), ("Giren toplam", 12, "0"),
        ("Cikan", 10, "0"), ("Net", 9, "0"), ("Gun sonu sahada", 14, "0"),
        ("Giren subeler", 46, None),
    ]
    ws = wb.create_sheet(f"Gun-Gun-{yil}")
    _basliklar(ws, kolonlar)

    kohort = [r for r in satirlar if r["Kohort"] == yil]
    giren = defaultdict(lambda: {"sezonluk": 0, "kadrolu": 0, "sube": defaultdict(int)})
    cikan = defaultdict(int)
    for r in kohort:
        g = _gun(r["GirisTarihi"])
        hucre = giren[g]
        if r["Kadro"] == "SEZONLUK":
            hucre["sezonluk"] += 1
        else:
            hucre["kadrolu"] += 1
        hucre["sube"][r["Sube"]] += 1
        c = _gun(r["CikisTarihi"])
        if c:
            cikan[c] += 1

    baslangic = date(yil, 7, 1)
    bitis = min(son_gun, date(yil, 9, 30))
    gun_adi = ["Pzt", "Sal", "Car", "Per", "Cum", "Cmt", "Paz"]
    sahada = 0
    en_yogun = max((v["sezonluk"] + v["kadrolu"] for v in giren.values()), default=0)
    t = baslangic
    while t <= bitis:
        gi = giren.get(t, {"sezonluk": 0, "kadrolu": 0, "sube": {}})
        toplam_giren = gi["sezonluk"] + gi["kadrolu"]
        ci = cikan.get(t, 0)
        sahada += toplam_giren - ci
        if toplam_giren or ci:
            subeler = ", ".join(f"{s} {n}" for s, n in sorted(gi["sube"].items(), key=lambda x: -x[1]))
            ws.append([t, gun_adi[t.weekday()], gi["sezonluk"], gi["kadrolu"],
                       toplam_giren, ci, toplam_giren - ci, sahada, subeler])
            if toplam_giren == en_yogun and en_yogun > 0:
                for h in ws[ws.max_row]:
                    h.fill = ZIRVE_DOLGU
        t += timedelta(days=1)

    _bicim(ws, kolonlar)
    son = ws.max_row + 2
    ws.cell(son, 1, "Hareketsiz gunler atlandi. 'Gun sonu sahada' = kumulatif (giren - cikan), "
                    "yalniz bu kohort. Sari satir = en yogun alim gunu.").font = NOT_YAZI
    ws.cell(son + 1, 1, f"Pencere: 01.07.{yil} - {bitis.strftime('%d.%m.%Y')}").font = NOT_YAZI
    return ws


def sayfa_liste(wb, satirlar):
    """Tek sayfa, iki yil birlikte -- Yil kolonuyla filtrelenebilir."""
    kolonlar = [
        ("Yil", 7, "0"), ("Giris", 12, TARIH), ("Personel No", 12, None), ("Ad Soyad", 26, None),
        ("Kadro", 12, None), ("Sube", 16, None), ("Reyon / Birim", 20, None),
        ("Unvan", 26, None), ("Cikis", 12, TARIH), ("Kalis (gun)", 11, "0"),
        ("Durum", 14, None), ("SGK cikis kodu", 13, None),
    ]
    ws = wb.create_sheet("Personel-Listesi")
    _basliklar(ws, kolonlar)

    sirali = sorted(satirlar, key=lambda r: (r["Kohort"], _gun(r["GirisTarihi"]),
                                             r["Sube"], r["AdSoyad"]))
    onceki_gun, onceki_yil = None, None
    for r in sirali:
        g = _gun(r["GirisTarihi"])
        c = _gun(r["CikisTarihi"])
        ws.append([r["Kohort"], g, r["Personelno"], r["AdSoyad"], r["Kadro"], r["Sube"],
                   r["Departman"], r["Unvan"], c, r["KalisGun"],
                   "Calisiyor" if c is None else "Ayrildi", r["CikisKodu"]])
        s = ws.max_row
        if r["Kadro"] == "SEZONLUK":
            for h in ws[s]:
                h.fill = SEZON_DOLGU
        if c is not None:
            ws.cell(s, 11).font = AYRILDI_YAZI
        if onceki_yil is not None and r["Kohort"] != onceki_yil:        # yil degisimi: kalin cizgi
            for h in ws[s]:
                h.border = Border(left=INCE, right=INCE, bottom=INCE,
                                  top=Side(style="medium", color="E30622"))
        elif onceki_gun is not None and g != onceki_gun:                # gun degisimi: ince cizgi
            for h in ws[s]:
                h.border = Border(left=INCE, right=INCE, bottom=INCE,
                                  top=Side(style="thin", color="9AA5A0"))
        onceki_gun, onceki_yil = g, r["Kohort"]

    _bicim(ws, kolonlar)
    ws.auto_filter.ref = f"A1:L{ws.max_row}"
    say = {}
    for r in satirlar:
        say[r["Kohort"]] = say.get(r["Kohort"], 0) + 1
    son = ws.max_row + 2
    ws.cell(son, 1, "Kohort penceresi: giris 1 Temmuz - 2 Eylul. "
                    + " · ".join(f"{y}: {n} kisi" for y, n in sorted(say.items()))
                    + ". Gri satir = SEZONLUK kadro (gercek sezon personeli), beyaz = kadrolu/diger. "
                      "Yil degisiminde kirmizi cizgi, gun degisiminde ince cizgi.").font = NOT_YAZI
    ws.cell(son + 1, 1, "KISISEL VERI -- yetkili kisiyle sinirli. SGK cikis kodu sozlugu Zirve'de yok "
                        "(IK teyidi gerekir); Kalis (gun) bos = halen calisiyor.").font = NOT_YAZI
    return ws


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    satirlar = json.loads(Path(argv[1]).read_text(encoding="utf-8"))

    wb = Workbook()
    wb.remove(wb.active)
    sayfa_liste(wb, satirlar)

    cikti = Path(argv[2])
    cikti.parent.mkdir(parents=True, exist_ok=True)
    wb.save(cikti)
    say = {y: sum(1 for r in satirlar if r["Kohort"] == y) for y in sorted({r["Kohort"] for r in satirlar})}
    print(f"yazildi: {cikti} | sayfalar: {', '.join(wb.sheetnames)} | kisi: {say}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
