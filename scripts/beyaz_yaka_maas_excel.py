# -*- coding: utf-8 -*-
"""Maas/kadro listesi -> Excel (emitter).

Cekirdek (hesap/filtre/is mantigi) `sorgular/*-maas-listesi.sql` dosyalarindadir.
Bu script SADECE bicimlendirir -- SUM/CASE/join YAPMAZ; ozet sayfasindaki tum
toplamlar Excel FORMULUDUR, Python'da hesaplanmaz (.claude/rules/emitter-ayrimi.md).

Kolon duzeni GIRDININ kendi anahtar sirasindan gelir; her anahtarin basligi/
genisligi/bicimi asagidaki tek sozlukten okunur. Yeni kolon = sozluge tek satir.
Bilinmeyen anahtar duser DEGIL, duz metin olarak basilir (sessiz kolon kaybi yok).

Girdi : cekirdek sorgunun JSON ciktisi (MCP zirve veya sqlcli --format json).
Cikti : xlsx (Liste + <gruplama> ozeti sayfalari).

Kullanim:
    python scripts/beyaz_yaka_maas_excel.py <girdi.json> <cikti.xlsx> [gruplama_alani]

Ornek:
    python scripts/beyaz_yaka_maas_excel.py \
        briefings/2026-10-09/mudur-maas-veri.json \
        briefings/2026-10-09/mudur-maas-listesi.xlsx Sube
"""
import json
import sys
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

TL = '#,##0.00\\ "₺"'  # 1.234,56 ₺
BASLIK_DOLGU = PatternFill("solid", fgColor="E30622")  # BKM kirmizisi
BASLIK_YAZI = Font(bold=True, color="FFFFFF", size=10)
TOPLAM_DOLGU = PatternFill("solid", fgColor="F2F2F2")
INCE = Side(style="thin", color="D9D9D9")
KENAR = Border(left=INCE, right=INCE, top=INCE, bottom=INCE)

# alan -> (baslik, genislik, sayi_bicimi, toplanabilir_mi)
KOLON_SOZLUK = {
    "Personelno":        ("Personel No", 13, None, False),
    "AdSoyad":           ("Ad Soyad", 26, None, False),
    "Seviye":            ("Seviye", 11, None, False),
    "Grup":              ("Grup", 10, None, False),
    "Sube":              ("Şube / Birim", 17, None, False),
    "Departman":         ("Departman", 26, None, False),
    "Unvan":             ("Ünvan", 32, None, False),
    "Firma":             ("Firma", 22, None, False),
    "Kadro":             ("Kadro", 11, None, False),
    "GirisTarihi":       ("Giriş Tarihi", 13, None, False),
    "KidemYil":          ("Kıdem (yıl)", 11, "0.0", False),
    "Cinsiyet":          ("Cinsiyet", 10, None, False),
    "OgrenimDurumu":     ("Öğrenim", 22, None, False),
    "UcretOran":         ("Ücret Oranı", 13, TL, False),
    "UcretSekli":        ("Ücret Şekli", 12, None, False),
    "AylikNet":          ("Aylık Net", 15, TL, True),
    "CariAylikNet":      ("Cari Aylık Net", 16, TL, True),
    "EylPrimGun":        ("Eyl. Prim Günü", 13, "0", False),
    "EylAvansKesinti":   ("Eyl. Avans/Kesinti", 17, TL, True),
    "EylNetOdenen":      ("Eyl. Net Ödenen", 16, TL, True),
    "EylBrut":           ("Eyl. Brüt", 15, TL, True),
    "EylIsvSGK":         ("Eyl. İşv. SGK", 14, TL, True),
    "EylIsvIssizlik":    ("Eyl. İşv. İşsizlik", 15, TL, True),
    "EylIsverenMaliyet": ("Eyl. İşveren Maliyeti", 20, TL, True),
}
VARSAYILAN = (None, 16, None, False)  # sozlukte olmayan alan icin


def _kolon_tanim(alan):
    baslik, genislik, bicim, toplanir = KOLON_SOZLUK.get(alan, VARSAYILAN)
    return (baslik or alan), genislik, bicim, toplanir


def _basliklari_yaz(ws, basliklar):
    ws.append(basliklar)
    for h in ws[1]:
        h.fill = BASLIK_DOLGU
        h.font = BASLIK_YAZI
        h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        h.border = KENAR
    ws.row_dimensions[1].height = 30
    ws.freeze_panes = "A2"


def liste_sayfasi(wb, satirlar, alanlar):
    ws = wb.create_sheet("Liste")
    _basliklari_yaz(ws, [_kolon_tanim(a)[0] for a in alanlar])

    for r in satirlar:
        ws.append([r.get(a) for a in alanlar])

    son = ws.max_row  # son veri satiri
    for idx, alan in enumerate(alanlar, start=1):
        _, genislik, bicim, _ = _kolon_tanim(alan)
        harf = get_column_letter(idx)
        ws.column_dimensions[harf].width = genislik
        for hucre in ws[harf][1:]:
            hucre.border = KENAR
            if bicim:
                hucre.number_format = bicim

    # TOPLAM satiri -- her toplanabilir kolon icin Excel SUM formulu
    ws.append([])
    toplam = ws.max_row + 1
    ws.cell(toplam, 1, "TOPLAM").font = Font(bold=True)
    ws.cell(toplam, 2, f'=COUNTA(B2:B{son}) & " kişi"').font = Font(bold=True)
    for idx, alan in enumerate(alanlar, start=1):
        _, _, bicim, toplanir = _kolon_tanim(alan)
        if toplanir:
            harf = get_column_letter(idx)
            h = ws.cell(toplam, idx, f"=SUM({harf}2:{harf}{son})")
            h.font = Font(bold=True)
            h.number_format = bicim
    for c in range(1, len(alanlar) + 1):
        ws.cell(toplam, c).fill = TOPLAM_DOLGU
        ws.cell(toplam, c).border = KENAR

    ws.auto_filter.ref = f"A1:{get_column_letter(len(alanlar))}{son}"
    return son


def ozet_sayfasi(wb, satirlar, alanlar, grup_alani, liste_son):
    """<grup_alani> ozeti. Kisi sayisi ve tutarlar Liste'den FORMULLE turer."""
    para_alanlari = [a for a in alanlar if _kolon_tanim(a)[3]]
    grup_harf = get_column_letter(alanlar.index(grup_alani) + 1)

    # Excel sayfa adi: / \ * ? [ ] YASAK, en fazla 31 karakter
    ad = _kolon_tanim(grup_alani)[0]
    for yasak in "/\\*?[]:":
        ad = ad.replace(yasak, "-")
    ws = wb.create_sheet(f"{ad} Özeti"[:31])
    _basliklari_yaz(ws, [_kolon_tanim(grup_alani)[0], "Kişi"]
                        + [_kolon_tanim(a)[0] for a in para_alanlari])

    gruplar = sorted({str(r.get(grup_alani)) for r in satirlar})
    ilk, son = 2, 1 + len(gruplar)
    for i, g in enumerate(gruplar):
        s = ilk + i
        ws.cell(s, 1, g)
        ws.cell(s, 2, f'=COUNTIF(Liste!${grup_harf}$2:${grup_harf}${liste_son},$A{s})')
        for j, alan in enumerate(para_alanlari, start=3):
            ph = get_column_letter(alanlar.index(alan) + 1)
            ws.cell(s, j, f'=SUMIF(Liste!${grup_harf}$2:${grup_harf}${liste_son},'
                          f'$A{s},Liste!${ph}$2:${ph}${liste_son})')

    toplam = son + 1
    ws.cell(toplam, 1, "TOPLAM").font = Font(bold=True)
    for c in range(2, 3 + len(para_alanlari)):
        harf = get_column_letter(c)
        ws.cell(toplam, c, f"=SUM({harf}{ilk}:{harf}{son})").font = Font(bold=True)

    ws.column_dimensions["A"].width = 24
    ws.column_dimensions["B"].width = 8
    for j, alan in enumerate(para_alanlari, start=3):
        ws.column_dimensions[get_column_letter(j)].width = _kolon_tanim(alan)[1]
    for satir in ws.iter_rows(min_row=2, max_row=toplam, max_col=2 + len(para_alanlari)):
        for hucre in satir:
            hucre.border = KENAR
            if hucre.column == 2:
                hucre.number_format = "0"
            elif hucre.column > 2:
                hucre.number_format = TL
    for c in range(1, 3 + len(para_alanlari)):
        ws.cell(toplam, c).fill = TOPLAM_DOLGU


def main():
    if len(sys.argv) not in (3, 4):
        print(__doc__)
        return 2

    girdi, cikti = Path(sys.argv[1]), Path(sys.argv[2])
    satirlar = json.loads(girdi.read_text(encoding="utf-8"))
    if not satirlar:
        print(f"HATA: {girdi} bos -- Excel uretilmedi.", file=sys.stderr)
        return 1

    alanlar = list(satirlar[0].keys())
    # Tum satirlar ayni alan kumesini tasimali; tasimiyorsa sessiz bos hucre olur.
    for i, r in enumerate(satirlar[1:], start=2):
        if list(r.keys()) != alanlar:
            eksik = set(alanlar) - set(r)
            fazla = set(r) - set(alanlar)
            print(f"HATA: {i}. satirin alanlari ilk satirdan farkli "
                  f"(eksik={sorted(eksik)}, fazla={sorted(fazla)})", file=sys.stderr)
            return 1

    grup_alani = sys.argv[3] if len(sys.argv) == 4 else (
        "Departman" if "Departman" in alanlar else
        "Sube" if "Sube" in alanlar else alanlar[0])
    if grup_alani not in alanlar:
        print(f"HATA: gruplama alani '{grup_alani}' girdide yok. "
              f"Mevcut: {', '.join(alanlar)}", file=sys.stderr)
        return 1

    wb = Workbook()
    wb.remove(wb.active)
    liste_son = liste_sayfasi(wb, satirlar, alanlar)
    ozet_sayfasi(wb, satirlar, alanlar, grup_alani, liste_son)

    cikti.parent.mkdir(parents=True, exist_ok=True)
    wb.save(cikti)
    print(f"OK: {cikti}  ({len(satirlar)} satir, gruplama='{grup_alani}')")
    return 0


if __name__ == "__main__":
    sys.exit(main())
