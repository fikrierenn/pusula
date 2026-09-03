# -*- coding: utf-8 -*-
"""Excel: kadro sayfalari — Kadro · Bolum · Personel (KVKK) · Norm · Maliyet · Yontem."""
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from verimlilik_ortak import CARI, ONCEKI
from verimlilik_xlsx_ortak import (ADET, ADET1, BASLIK, BASLIK_YAZI, BOLUM_YAZI, GRI,
                                   INCE, KAT, KENAR, NOT_YAZI, TL, VURGU, YESIL_YAZI,
                                   YUZDE, _basliklar, _notlar, _yaz)

# ------------------------------------------------------------------ Kadro (5 magaza)
def sayfa_kadro(wb, veri):
    """Eski magaza-tablo-sp.xlsx'in DOGRU halefi: kadro tablosu, tek-tablo sayimi (join fan-out yok)."""
    ws = wb.create_sheet("Kadro")
    kolonlar = [
        ("Magaza", 13, None),
        ("Kadrolu taban 30.06 · 2025", 12, ADET), ("Kadrolu taban 30.06 · 2026", 12, ADET), ("Taban Δ", 9, "+0;-0;0"),
        ("Kadrolu 31.08 · 2025", 11, ADET), ("Kadrolu 31.08 · 2026", 11, ADET),
        ("Sezon ici hareket 2025", 11, "+0;-0;0"), ("Sezon ici hareket 2026", 11, "+0;-0;0"),
        ("Sezonluk 31.08 · 2025", 11, ADET), ("Sezonluk 31.08 · 2026", 11, ADET),
        ("Toplam 31.08 · 2025", 11, ADET), ("Toplam 31.08 · 2026", 11, ADET), ("Toplam Δ", 9, "+0;-0;0"),
    ]
    ws.cell(1, 1, "Bes magaza kadro tablosu — as-of Igt <= T AND (Ict IS NULL OR Ict >= T)").font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    s = 4
    ilk = s
    for m in veri["magaza_kadro"]:
        ws.cell(s, 1, m["sube"]).border = KENAR
        ham = {2: m["kadrolu_taban25"], 3: m["kadrolu_taban26"],
               5: m["kadrolu_kesim25"], 6: m["kadrolu_kesim26"],
               9: m["sezonluk_kesim25"], 10: m["sezonluk_kesim26"]}
        for kol, v in ham.items():
            c = ws.cell(s, kol, v)
            c.number_format = ADET
            c.border = KENAR
        s += 1
    son = s - 1

    ws.cell(s, 1, "TOPLAM").font = Font(bold=True)
    ws.cell(s, 1).fill = GRI
    ws.cell(s, 1).border = KENAR
    for kol in (2, 3, 5, 6, 9, 10):
        c = ws.cell(s, kol, "=SUM(%s%d:%s%d)" % (get_column_letter(kol), ilk, get_column_letter(kol), son))
        c.number_format = ADET
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    toplam = s

    for r in list(range(ilk, son + 1)) + [toplam]:
        dolgu = GRI if r == toplam else None
        turemeler = {
            4: "=C%d-B%d" % (r, r),          # taban farki (patrona soylenen +14 bu satirdan)
            7: "=E%d-B%d" % (r, r),          # 2025 sezon ici
            8: "=F%d-C%d" % (r, r),          # 2026 sezon ici
            11: "=E%d+I%d" % (r, r),         # toplam 2025
            12: "=F%d+J%d" % (r, r),         # toplam 2026
            13: "=L%d-K%d" % (r, r),
        }
        for kol, f in turemeler.items():
            c = ws.cell(r, kol, f)
            c.number_format = kolonlar[kol - 1][2]
            c.border = KENAR
            if dolgu:
                c.fill = dolgu
                c.font = Font(bold=True)
        if r == toplam:
            ws.cell(r, 4).fill = VURGU
            ws.cell(r, 8).fill = VURGU

    s = toplam + 2
    _notlar(ws, [
        "TABAN FARKI (D kolonu, TOPLAM satiri) = patrona soylenen +14: kadrolu 139 -> 153, 1 TEMMUZ'DAN ONCE olustu.",
        "SEZON ICI HAREKET = kesim - taban. 2026'da -4; 2025'te de -4 -> sezon icinde kadro buyutulmedi, iki yilin deseni ayni.",
        "Sayim TEK TABLO uzerinden (vw_PersonelDepartman). Onceki surumde perbilgi LEFT JOIN'i bir kisiyi iki kez saymis:",
        "   Ozluce 31.08.2026 kadrolu 42 gorunuyordu, DOGRUSU 41 (teyit: KADRO 41 + SEZONLUK 13 = 54 kisi).",
        "   Bu yuzden magaza toplami 150 degil 149; sezon ici hareket -3 degil -4.",
        "Heykel ve Sura POS raporlamasinda yok -> is hacmi sayfalarinda yer almaz, kadro tablosunda VARDIR.",
        "KAPSAM: Lokasyon = MAGAZALAR. Cift gorevli 1 kisi (GM satinalma 'KITAP DISI S.A' + Heykel) bu",
        "   kapsamda GORUNMEZ. O kisi Heykel'e eklenirse taban 140 -> 154, kesim 136 -> 150 olur;",
        "   TABAN FARKI yine +14, SEZON ICI HAREKET yine -4. Yani cift gorev savunmayi DEGISTIRMIYOR.",
        "Kaynak view anlik durumu tutar (kadro gecmisi yok): kisinin BUGUNKU lokasyon etiketi her iki yila",
        "   da uygulanir. Bu yuzden kapsam iki yilda tutarli, ama gecmis unvan/lokasyon degisimi izlenemez.",
    ], s)
    return ws


# ------------------------------------------------------------------ Bolum (departman)
def sayfa_bolum(wb, veri):
    """Kadro NEREYE gitti: yonetim / kasa / mal kabul / satis reyonlari."""
    ws = wb.create_sheet("Bolum")
    kolonlar = [
        ("Bolum", 20, None),
        ("Kadrolu 2025", 11, ADET), ("Kadrolu 2026", 11, ADET), ("Kadrolu Δ", 10, "+0;-0;0"),
        ("Sezonluk 2025", 11, ADET), ("Sezonluk 2026", 11, ADET), ("Sezonluk Δ", 10, "+0;-0;0"),
        ("Toplam 2025", 11, ADET), ("Toplam 2026", 11, ADET), ("Toplam Δ", 10, "+0;-0;0"),
        ("Sezonluk payi 2026", 12, "0.0%"),
    ]
    ws.cell(1, 1, "Bölüm bazında kadro — 31.08 kesimi, beş mağaza").font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    s = 4
    ilk = s
    for b in veri["bolum"]:
        ws.cell(s, 1, b["bolum"]).border = KENAR
        for kol, v in ((2, b["kadrolu25"]), (3, b["kadrolu26"]),
                       (5, b["sezonluk25"]), (6, b["sezonluk26"])):
            c = ws.cell(s, kol, v)
            c.number_format = ADET
            c.border = KENAR
        s += 1
    son = s - 1

    ws.cell(s, 1, "TOPLAM").font = Font(bold=True)
    ws.cell(s, 1).fill = GRI
    ws.cell(s, 1).border = KENAR
    for kol in (2, 3, 5, 6):
        c = ws.cell(s, kol, "=SUM(%s%d:%s%d)" % (get_column_letter(kol), ilk, get_column_letter(kol), son))
        c.number_format = ADET
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    toplam = s

    for r in list(range(ilk, son + 1)) + [toplam]:
        dolgu = GRI if r == toplam else None
        for kol, f in {4: "=C%d-B%d" % (r, r), 7: "=F%d-E%d" % (r, r),
                       8: "=B%d+E%d" % (r, r), 9: "=C%d+F%d" % (r, r),
                       10: "=I%d-H%d" % (r, r),
                       11: "=IF(I%d=0,\"\",F%d/I%d)" % (r, r, r)}.items():
            c = ws.cell(r, kol, f)
            c.number_format = kolonlar[kol - 1][2]
            c.border = KENAR
            if dolgu:
                c.fill = dolgu
                c.font = Font(bold=True)
        if r == toplam:
            ws.cell(r, 4).fill = VURGU

    s = toplam + 2
    _notlar(ws, [
        "OKUNACAK NOKTA: yonetim (MAGAZA departmani) ve MAL KABUL BUYUMEDI — artis satis/kasa tarafinda.",
        "Sezonluk payi yuksek bolumler (KIRTASIYE, YARDIMCI KITAP, KIYAFET) sezon yuku tasiyan reyonlar;",
        "   oradaki kisi artisi kalici kadro degil, Eylul sonunda tahliye edilir.",
        "Bolum = Zirve 'Departman' alani (reyon). Bir kisi tek bolumde sayilir; toplam kapsam sayimiyla mutabik.",
        "Devir (turnover) bolum bazinda AYRI olculdu: en bozuk COCUK %179 · IDARI ISLER %183 · KASA %160;",
        "   MAGAZA (yonetim) %25 ve ayrilanin ortalama kidemi 4,7 yil -> yonetim katmani stabil.",
    ], s)
    return ws


# ------------------------------------------------------------------ Personel (kisi duzeyi, KVKK)
def sayfa_personel(wb, veri):
    """Kisi listesi — YALNIZ --kisi ile. Ucret/TCKN/IBAN YOK. Cikti dosyasi gitignore'da."""
    ws = wb.create_sheet("Personel")
    kolonlar = [("Ad Soyad", 26, None), ("Şube", 13, None), ("Bölüm", 18, None), ("Ünvan", 30, None),
                ("Kadro", 11, None), ("Giriş", 11, None), ("Çıkış", 11, None),
                ("31.08.2025", 10, None), ("31.08.2026", 10, None), ("Kıdem (yıl)", 10, "0.0")]
    ws.cell(1, 1, "Mağaza personeli — 31.08.2025 veya 31.08.2026'da çalışanlar").font = Font(bold=True, size=12)
    ws.cell(2, 1, "KVKK: ücret / TC no / IBAN yok. Bu sayfa yalnız iç kullanım; patron sunumunda YER ALMAZ.").font = NOT_YAZI
    _basliklar(ws, kolonlar, satir=4)

    s = 5
    for p in veri.get("personel", []):
        deger = [p["ad"], p["sube"], p["bolum"], p["unvan"], p["kadro"], p["giris"], p["cikis"],
                 "✓" if p["aktif25"] else "", "✓" if p["aktif26"] else "", p["kidem_gun"] / 365.0]
        for i, (kol, v_) in enumerate(zip(kolonlar, deger), start=1):
            c = ws.cell(s, i, v_)
            c.border = KENAR
            if kol[2]:
                c.number_format = kol[2]
            if i in (8, 9):
                c.alignment = Alignment(horizontal="center")
            if p["kadro"] == "SEZONLUK":
                c.font = Font(size=10, color="A6001A")
        s += 1
    ws.auto_filter.ref = "A4:J%d" % (s - 1)
    ws.freeze_panes = "A5"
    _notlar(ws, [
        "Kadro = SEZONLUK satirlar kirmizi. Bos cikis = halen calisiyor.",
        "31.08.YYYY kolonu: o tarihte fiilen calisiyor muydu (as-of Igt <= T AND (Ict IS NULL OR Ict >= T)).",
        "%d kisi listelendi." % len(veri.get("personel", [])),
    ], s + 1)
    return ws



# ------------------------------------------------------------------ Norm
def sayfa_norm(wb, veri):
    """Norm kadro (sezon disi) vs gercek kadrolu."""
    n = veri.get("norm")
    if not n:
        return None
    ws = wb.create_sheet("Norm")
    kolonlar = [("Mağaza / Grup", 15, None),
                ("Norm kadrolu", 12, ADET), ("Operasyonel kadrolu", 15, ADET), ("Kadrolu farkı", 12, "+0;-0;0"),
                ("Norm sezonluk", 12, ADET), ("Sezonluk 31.08", 12, ADET), ("Sezonluk farkı", 12, "+0;-0;0"),
                ("NORM TOPLAM", 12, ADET), ("GERÇEK TOPLAM", 13, ADET), ("TOPLAM FARK", 12, "+0;-0;0")]
    ws.cell(1, 1, "Norm kadro (%s, sezon dışı) ile gerçek kadrolu karşılaştırması" % n["tarih"]).font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    s = 4
    ilk = s
    ayr_ = n.get("ayrik", {})
    for r in n["sube"]:
        a_ = ayr_.get(r["sube"], {})
        ops_ = r["kadrolu_kesim26"] - a_.get("engelli", 0) - a_.get("etkinlik", 0)
        ws.cell(s, 1, r["sube"].title()).border = KENAR
        for kol, v_ in ((2, r["norm"]), (3, ops_),
                        (5, r["norm_sezonluk"]), (6, r["sezonluk_kesim26"]),
                        (8, r["norm_toplam"]), (9, ops_ + r["sezonluk_kesim26"])):
            c = ws.cell(s, kol, v_); c.number_format = ADET; c.border = KENAR
        for kol, f in ((4, "=C%d-B%d" % (s, s)), (7, "=F%d-E%d" % (s, s)), (10, "=I%d-H%d" % (s, s))):
            c = ws.cell(s, kol, f)
            c.number_format = "+0;-0;0"
            c.border = KENAR
            c.font = Font(bold=True)
            if kol == 10:
                c.fill = VURGU
        s += 1
    son = s - 1
    ws.cell(s, 1, "TOPLAM").font = Font(bold=True); ws.cell(s, 1).fill = GRI; ws.cell(s, 1).border = KENAR
    for kol in (2, 3, 5, 6, 8, 9):
        c = ws.cell(s, kol, "=SUM(%s%d:%s%d)" % (get_column_letter(kol), ilk, get_column_letter(kol), son))
        c.number_format = ADET; c.border = KENAR; c.fill = GRI; c.font = Font(bold=True)
    for kol, f in ((4, "=C%d-B%d" % (s, s)), (7, "=F%d-E%d" % (s, s)), (10, "=I%d-H%d" % (s, s))):
        c = ws.cell(s, kol, f); c.number_format = "+0;-0;0"
        c.border = KENAR; c.fill = VURGU; c.font = Font(bold=True)

    # --- BOLUM BAZINDA norm acigi
    s += 2
    ws.cell(s, 1, "BÖLÜM BAZINDA NORM AÇIĞI").font = BOLUM_YAZI
    s += 1
    bkolon = [("Bölüm", 18, None), ("Norm", 9, ADET), ("Kadrolu 31.08", 12, ADET),
              ("Açık", 9, ADET), ("Fazla", 9, ADET), ("Sezonluk 31.08", 13, ADET)]
    for i, (ad, gen, _f) in enumerate(bkolon, start=1):
        h = ws.cell(s, i, ad)
        h.fill = BASLIK; h.font = BASLIK_YAZI; h.border = KENAR
        h.alignment = Alignment(horizontal="center")
    s += 1
    for r in n["bolum"]:
        # K-06: normda tanimli ama kayitta hic kisi olmayan bolum "acik" degil TEYIT BEKLEYEN
        teyit = r.get("teyit_gerekiyor")
        ws.cell(s, 1, r["bolum"].title() + (" (teyit bekliyor)" if teyit else "")).border = KENAR
        for kol, v_ in ((2, r["norm"]), (3, r["kadrolu26"]),
                        (4, "—" if teyit else (r["acik"] or "—")),
                        (5, r["fazla"] or "—"), (6, r["sezonluk26"])):
            c = ws.cell(s, kol, v_)
            c.number_format = ADET
            c.border = KENAR
            if teyit:
                c.fill = PatternFill("solid", fgColor="FFF6E6")
            elif kol == 4 and r["acik"]:
                c.font = Font(bold=True, color="A6001A")
                c.fill = VURGU
        s += 1
    ws.cell(s, 1, "TOPLAM").font = Font(bold=True); ws.cell(s, 1).fill = GRI; ws.cell(s, 1).border = KENAR
    for kol, v_ in ((2, sum(r["norm"] for r in n["bolum"])),
                    (3, sum(r["kadrolu26"] for r in n["bolum"])),
                    (4, n["acik_bolum_toplam"]), (5, n["fazla_bolum_toplam"]),
                    (6, sum(r["sezonluk26"] for r in n["bolum"]))):
        c = ws.cell(s, kol, v_)
        c.number_format = ADET; c.border = KENAR; c.fill = GRI; c.font = Font(bold=True)
    # NORM DISI gruplar + IK kayit toplami (sunumla ayni katmanlar)
    s += 1
    eng_t = sum(a.get("engelli", 0) for a in ayr_.values())
    etk_t = sum(a.get("etkinlik", 0) for a in ayr_.values())
    for etiket, adet_ in (("Etkinlik (norm dışı)", etk_t), ("Engelli (norm dışı)", eng_t)):
        c = ws.cell(s, 1, etiket); c.border = KENAR; c.font = Font(italic=True, size=10)
        c2 = ws.cell(s, 3, adet_); c2.number_format = ADET; c2.border = KENAR
        c2.fill = PatternFill("solid", fgColor="FFF6E6")
        ws.cell(s, 1).fill = PatternFill("solid", fgColor="FFF6E6")
        s += 1
    c = ws.cell(s, 1, "Kayıt toplamı (İK, tüm gruplar)"); c.border = KENAR; c.font = Font(italic=True, size=10)
    for kol, v_ in ((3, n["toplam"]["kadrolu_kesim26"]), (6, n["toplam"]["sezonluk_kesim26"]),
                    (9, n["toplam"]["kadrolu_kesim26"] + n["toplam"]["sezonluk_kesim26"])):
        c2 = ws.cell(s, kol, v_); c2.number_format = ADET; c2.border = KENAR
    s += 2
    _notlar(ws, [
        "KURAL: norm = ENGELLI DISINDAKI personel (yonetim karari). Magaza satirlari OPERASYONEL "
        "kadroyu gosterir (kadrolu - engelli - etkinlik); en altta IK'nin kayit toplami durur.",
        "⚠ BOLUM acigi (%d) MAGAZA acigindan (%d) BUYUK: magaza icinde bir bolumun fazlasi baska "
        "bolumun acigini maskeler." % (n["acik_bolum_toplam"], n.get("acik_sube_toplam", 0)),
        "TEYIT BEKLEYEN: normda tanimli ama kayitta HIC kisi olmayan bolum(ler) %s = %d kisi. "
        "Bolum adi Zirve'de baska yazili olabilir (key-mismatch) veya bolum gercekten bos; "
        "ACIK TOPLAMINA DAHIL EDILMEDI." % (
            ", ".join(x.title() for x in n.get("teyit_bolumler", [])) or "yok",
            n.get("acik_bolum_teyit", 0)),
        "ENGELLI TESPITI: Personelno bicimi yuzunden atlanan kayit sayisi %d (0 olmali; >0 ise "
        "engelli sayisi ALT SINIR, norm acigi oldugundan kucuk gorunur)."
        % n.get("engelli_format_atlanan", 0),
        "NORM SEZON DISI kadroyu tanimlar -> sezonluk personel norma DAHIL DEGIL; kiyas yalniz KADROLU ile.",
        "Norm kaynagi: %s (%s). Yonetim parametresi, Zirve'den sorgulanmaz." % (n["kaynak_dosya"], n["tarih"]),
        "KAPSAM DISI: %s norm tablosunda yok." % (", ".join(x.title() for x in n["kapsam_disi"]) or "—"),
        "Eksi fark = normun ALTINDA calisiliyor. 31.08'de norm %d, OPERASYONEL kadrolu %d "
        "(kayit %d - engelli/etkinlik). Ustteki tablo operasyonel rakami gosterir." % (
            n["toplam"]["norm"],
            n["toplam"]["kadrolu_kesim26"] - sum(a.get("engelli", 0) + a.get("etkinlik", 0)
                                                 for a in n.get("ayrik", {}).values()),
            n["toplam"]["kadrolu_kesim26"]),
    ], s)
    return ws


# ------------------------------------------------------------------ Maliyet (bordro) + fazla mesai
def sayfa_maliyet(wb, veri):
    """Personel maliyeti / ciro orani (K-21) + fazla mesai yasal sinir (K-22).

    Kaynak: Zirve bordro vw_PuanBil — maliyet = Brut Toplam + Isveren SGK + Isveren Issizlik.
    ⚠ Pencere son TAM bordro ayina kadar (Agustos bordrosu kosmadan alinirsa maliyet eksik cikar).
    """
    m = veri.get("maliyet")
    f = veri.get("fazla_mesai")
    if not m or not f:
        return None
    ws = wb.create_sheet("Maliyet")
    p25, p26 = m["pos"]["%d" % (ONCEKI % 100)], m["pos"]["%d" % (CARI % 100)]
    sz = m["sezon"]
    sz25, sz26 = sz["pos"]["%d" % (ONCEKI % 100)], sz["pos"]["%d" % (CARI % 100)]
    ws.cell(1, 1, "Personel maliyeti ve ciro orani — SEZON %s (kiyas: %s) · yil geneli: %s · "
                  "uc POS magazasi (%s)"
            % (sz["kural_etiket"], sz["etiket"], m["pencere"],
               " · ".join(x.title() for x in m["kapsam_pos"]))
            ).font = Font(bold=True, size=12)
    if sz.get("uyari"):
        u = ws.cell(2, 1, sz["uyari"])
        u.font = Font(bold=True, size=9, color="A6001A")

    kolonlar = [("Olcu", 30, None),
                ("SEZON %d" % ONCEKI, 15, TL), ("SEZON %d" % CARI, 15, TL), ("SEZON Δ", 10, YUZDE),
                ("KUM. %d" % ONCEKI, 15, TL), ("KUM. %d" % CARI, 15, TL), ("KUM. Δ", 10, YUZDE)]
    _basliklar(ws, kolonlar, satir=3)
    s = 4
    satirlar = [
        ("Calisan (tam gun karsiligi)", "fte", ADET1),
        ("Bordroda gorunen kisi (bilgi)", "kisi_ay", ADET),
        ("Kisi basina ortalama calisilan gun", "ort_prim_gun", ADET1),
        ("Brut ucret toplami", "brut", TL),
        ("Isveren SGK hissesi", "isveren_sgk", TL),
        ("Isveren issizlik payi", "isveren_issizlik", TL),
        ("PERSONEL MALIYETI (brut isveren)", "maliyet", TL),
        ("Net odenen (bilgi)", "net", TL),
        ("Ciro (KDV haric, Sinav dahil)", "ciro_kdvharic", TL),
        ("Kisi basina maliyet", "fte_basi_maliyet", TL),
        ("Kisi basina satis", "fte_basi_ciro", TL),
        ("Fazla mesai (saat)", "fm_saat", ADET1),
    ]
    for etiket, alan, fmt in satirlar:
        vurgu = etiket.startswith("PERSONEL") or etiket.startswith("FTE —")
        c0 = ws.cell(s, 1, etiket); c0.border = KENAR
        if vurgu:
            c0.font = Font(bold=True)
        for kol, kaynak in ((2, sz25), (3, sz26), (5, p25), (6, p26)):
            c = ws.cell(s, kol, kaynak.get(alan, 0)); c.number_format = fmt; c.border = KENAR
            if vurgu:
                c.font = Font(bold=True)
        for kol, (b_, c_) in ((4, ("B", "C")), (7, ("E", "F"))):
            c = ws.cell(s, kol, "=%s%d/%s%d-1" % (c_, s, b_, s))
            c.number_format = YUZDE; c.border = KENAR; c.font = Font(bold=True)
            if vurgu:
                c.fill = VURGU
        s += 1
    # ORAN satiri — yuzde PUAN farki (oranin orani yaniltir)
    c0 = ws.cell(s, 1, "MALIYET / CIRO ORANI"); c0.border = KENAR; c0.font = Font(bold=True)
    for kol, kaynak in ((2, sz25), (3, sz26), (5, p25), (6, p26)):
        c = ws.cell(s, kol, kaynak.get("maliyet_ciro_orani")); c.number_format = "0.00%"
        c.border = KENAR; c.font = Font(bold=True)
    for kol, (b_, c_) in ((4, ("B", "C")), (7, ("E", "F"))):
        c = ws.cell(s, kol, "=%s%d-%s%d" % (c_, s, b_, s))
        c.number_format = "+0.00%;-0.00%"; c.border = KENAR; c.font = Font(bold=True)
        c.fill = VURGU
    s += 1
    ws.cell(s, 1, "Δ satirlari yuzde PUAN farkidir (eksi = ciro icindeki personel yuku azaldi). "
                  "SEZON = %s (esas) · KUM. = %s (yil geneli referansi)."
            % (sz["etiket"], m["pencere"])).font = Font(italic=True, size=9)
    s += 2

    # --- GECEN YILIN TAM SEZONU (referans: sezon neye benziyor)
    g = sz["gecen_yil_tam"]["pos"]
    ws.cell(s, 1, "GECEN YILIN TAM SEZONU (%d, %s) — %d sezonu tamamlaninca ayni pencerede kiyas"
            % (ONCEKI, sz["kural_etiket"], CARI)).font = BOLUM_YAZI
    s += 1
    for etiket, val, fmt in (("FTE (tam zaman esdeger)", g["fte"], ADET1),
                             ("  — kadrolu FTE", sz["gecen_yil_tam"]["segment"]["KADROLU"]["fte"], ADET1),
                             ("  — sezonluk FTE", sz["gecen_yil_tam"]["segment"]["SEZONLUK"]["fte"], ADET1),
                             ("Personel maliyeti", g["maliyet"], TL),
                             ("Ciro (KDV haric)", g["ciro_kdvharic"], TL),
                             ("Maliyet / ciro orani", g.get("maliyet_ciro_orani", 0), "0.00%"),
                             ("Fazla mesai (saat)", g["fm_saat"], ADET1)):
        c0 = ws.cell(s, 1, etiket); c0.border = KENAR
        c = ws.cell(s, 2, val); c.number_format = fmt; c.border = KENAR
        s += 1
    ws.cell(s, 1, "SEZONUN SEKLI: sezonda ciro birkac kat artarken kadro ayni oranda artmaz -> "
                  "maliyet/ciro orani sezon aylarinda sezon disina gore COK dusuktur. Bu yuzden "
                  "sezon ile yil-geneli oranlari BIRBIRIYLE kiyaslanmaz.").font = Font(italic=True, size=9)
    s += 2

    # --- KADROLU / SEZONLUK AYRIMI (kullanici istegi 03.09)
    ws.cell(s, 1, "KADROLU / SEZONLUK AYRIMI — uc POS magazasi").font = BOLUM_YAZI
    s += 1
    skol = [("Segment", 16, None), ("SEZON FTE %d" % ONCEKI, 12, ADET1),
            ("SEZON FTE %d" % CARI, 12, ADET1), ("SEZON maliyet %d" % ONCEKI, 15, TL),
            ("SEZON maliyet %d" % CARI, 15, TL), ("FTE basi maliyet %d" % CARI, 15, TL),
            ("KUM. FTE %d" % ONCEKI, 12, ADET1), ("KUM. FTE %d" % CARI, 12, ADET1),
            ("KUM. maliyet %d" % CARI, 15, TL), ("SEZON FM saat %d" % CARI, 13, ADET1)]
    for i, (ad, gen, _f) in enumerate(skol, start=1):
        h = ws.cell(s, i, ad); h.fill = BASLIK; h.font = BASLIK_YAZI; h.border = KENAR
        h.alignment = Alignment(horizontal="center")
    s += 1
    for sg in ("KADROLU", "SEZONLUK"):
        a25 = sz["segment"][sg]["%d" % (ONCEKI % 100)]
        a26 = sz["segment"][sg]["%d" % (CARI % 100)]
        k25 = m["segment_kumulatif"][sg]["%d" % (ONCEKI % 100)]
        k26 = m["segment_kumulatif"][sg]["%d" % (CARI % 100)]
        ws.cell(s, 1, sg.title()).border = KENAR
        for kol, val, fmt in ((2, a25["fte"], ADET1), (3, a26["fte"], ADET1),
                              (4, a25["maliyet"], TL), (5, a26["maliyet"], TL),
                              (6, a26.get("fte_basi_maliyet", 0), TL),
                              (7, k25["fte"], ADET1), (8, k26["fte"], ADET1),
                              (9, k26["maliyet"], TL), (10, a26["fm_saat"], ADET1)):
            c = ws.cell(s, kol, val); c.number_format = fmt; c.border = KENAR
        s += 1
    ws.cell(s, 1, "TOPLAM").font = Font(bold=True); ws.cell(s, 1).fill = GRI
    ws.cell(s, 1).border = KENAR
    for kol, val, fmt in ((2, sz25["fte"], ADET1), (3, sz26["fte"], ADET1),
                          (4, sz25["maliyet"], TL), (5, sz26["maliyet"], TL),
                          (6, sz26.get("fte_basi_maliyet", 0), TL),
                          (7, p25["fte"], ADET1), (8, p26["fte"], ADET1),
                          (9, p26["maliyet"], TL), (10, sz26["fm_saat"], ADET1)):
        c = ws.cell(s, kol, val); c.number_format = fmt; c.border = KENAR
        c.fill = GRI; c.font = Font(bold=True)
    s += 1
    ws.cell(s, 1, "⚠ Segment ayraci `vw_PersonelDepartman.Kadro` = BUGUNKU durum (tarihlenmiyor): "
                  "gecmiste sezonluk calisip kadroya gecen kisi GECMIS ayda da KADROLU gorunur. "
                  "Ayrica sezonluk alimin buyuk kismi AGUSTOS'ta; Agustos bordrosu islenince "
                  "sezonluk agirligi gercek seviyesine cikar.").font = Font(italic=True, size=9)
    s += 2

    # --- AYLIK KIRILIM (kadro artisi ve maliyet HANGI AY olustu)
    ws.cell(s, 1, "AYLIK KIRILIM — uc POS magazasi (* = sezon ayi %s; %d icin bordrosu "
                  "kosmamis aylar bos)" % (sz["kural_etiket"], CARI)).font = BOLUM_YAZI
    s += 1
    akol = [("Ay", 8, None), ("FTE %d" % ONCEKI, 10, ADET1), ("FTE %d" % CARI, 10, ADET1),
            ("FTE Δ", 9, YUZDE), ("Maliyet %d" % ONCEKI, 14, TL), ("Maliyet %d" % CARI, 14, TL),
            ("Maliyet Δ", 10, YUZDE), ("FM saat %d" % ONCEKI, 11, ADET1),
            ("FM saat %d" % CARI, 11, ADET1), ("Oran %d" % ONCEKI, 9, None),
            ("Oran %d" % CARI, 9, None), ("Kayit %d" % ONCEKI, 9, ADET),
            ("Kayit %d" % CARI, 9, ADET), ("Ort. prim gunu %d" % CARI, 13, ADET1),
            ("Kadrolu FTE %d" % ONCEKI, 12, ADET1), ("Kadrolu FTE %d" % CARI, 12, ADET1),
            ("Sezonluk FTE %d" % ONCEKI, 13, ADET1), ("Sezonluk FTE %d" % CARI, 13, ADET1)]
    for i, (ad, gen, _f) in enumerate(akol, start=1):
        h = ws.cell(s, i, ad); h.fill = BASLIK; h.font = BASLIK_YAZI; h.border = KENAR
        h.alignment = Alignment(horizontal="center")
    s += 1
    for r in m["ay"]:
        c0 = ws.cell(s, 1, r["ad"] + ("*" if r["sezon_mu"] else ""))
        c0.border = KENAR
        if r["sezon_mu"]:
            c0.font = Font(bold=True)
        yok = not r.get("kiyas_mumkun", True)      # bordrosu kosmamis ay -> CARI yil bos
        for kol, val, fmt in ((2, r["fte%d" % (ONCEKI % 100)], ADET1),
                              (3, "—" if yok else r["fte%d" % (CARI % 100)], ADET1),
                              (5, r["maliyet%d" % (ONCEKI % 100)], TL),
                              (6, "—" if yok else r["maliyet%d" % (CARI % 100)], TL),
                              (8, r["fm_saat%d" % (ONCEKI % 100)], ADET1),
                              (9, "—" if yok else r["fm_saat%d" % (CARI % 100)], ADET1),
                              (12, r["kisi_ay%d" % (ONCEKI % 100)], ADET),
                              (13, "—" if yok else r["kisi_ay%d" % (CARI % 100)], ADET),
                              (14, "—" if yok else r["ort_prim_gun%d" % (CARI % 100)], ADET1),
                              (15, r["kadrolu_fte%d" % (ONCEKI % 100)], ADET1),
                              (16, "—" if yok else r["kadrolu_fte%d" % (CARI % 100)], ADET1),
                              (17, r["sezonluk_fte%d" % (ONCEKI % 100)], ADET1),
                              (18, "—" if yok else r["sezonluk_fte%d" % (CARI % 100)], ADET1)):
            c = ws.cell(s, kol, val); c.number_format = fmt; c.border = KENAR
            if r["sezon_mu"]:
                c.fill = VURGU
        for kol, (b_, c_) in ((4, ("B", "C")), (7, ("E", "F"))):
            c = ws.cell(s, kol, "=%s%d/%s%d-1" % (c_, s, b_, s))
            c.number_format = YUZDE; c.border = KENAR
        for kol, anahtar in ((10, "oran%d" % (ONCEKI % 100)), (11, "oran%d" % (CARI % 100))):
            deg_ = None if (yok and kol == 11) else r[anahtar]
            c = ws.cell(s, kol, deg_ if deg_ is not None else "—")
            c.number_format = "0.0%"
            c.border = KENAR
        s += 1
    s += 1

    # --- SUBE BAZINDA
    ws.cell(s, 1, "SUBE BAZINDA MALIYET VE FAZLA MESAI (bes magaza)").font = BOLUM_YAZI
    s += 1
    bkolon = [("Sube", 14, None), ("FTE %d" % ONCEKI, 10, ADET1), ("FTE %d" % CARI, 10, ADET1),
              ("Maliyet %d" % ONCEKI, 15, TL), ("Maliyet %d" % CARI, 15, TL), ("Maliyet Δ", 10, YUZDE),
              ("FM saat %d" % ONCEKI, 11, ADET1), ("FM saat %d" % CARI, 11, ADET1),
              ("FM tutar %d" % CARI, 13, TL)]
    for i, (ad, gen, _f) in enumerate(bkolon, start=1):
        h = ws.cell(s, i, ad); h.fill = BASLIK; h.font = BASLIK_YAZI; h.border = KENAR
        h.alignment = Alignment(horizontal="center")
        ws.column_dimensions[get_column_letter(i)].width = max(
            gen, ws.column_dimensions[get_column_letter(i)].width or 0)
    s += 1
    for sube in m["kapsam_tum"]:
        a = m["sube"].get("%s|%d" % (sube, ONCEKI), {})
        b = m["sube"].get("%s|%d" % (sube, CARI), {})
        ws.cell(s, 1, sube.title()).border = KENAR
        for kol, val, fmt in ((2, a.get("fte", 0), ADET1), (3, b.get("fte", 0), ADET1),
                              (4, a.get("maliyet", 0), TL), (5, b.get("maliyet", 0), TL),
                              (7, a.get("fm_saat", 0), ADET1), (8, b.get("fm_saat", 0), ADET1),
                              (9, b.get("fm_tutar", 0), TL)):
            c = ws.cell(s, kol, val); c.number_format = fmt; c.border = KENAR
        c = ws.cell(s, 6, "=E%d/D%d-1" % (s, s)); c.number_format = YUZDE; c.border = KENAR
        s += 1
    s += 1

    # --- FAZLA MESAI / YASAL SINIR
    ws.cell(s, 1, "FAZLA MESAI VE YASAL SINIR (4857 s.K. m.41 — yillik %d saat)"
            % int(f["yasal_yillik_sinir_saat"])).font = BOLUM_YAZI
    s += 1
    fi, kv = f["fiili"], f["kadro_artmasaydi"]
    for etiket, val, fmt in (
            ("Fiili FM saat %d (uc POS)" % ONCEKI, fi["fm_saat25"], ADET1),
            ("Fiili FM saat %d (uc POS)" % CARI, fi["fm_saat26"], ADET1),
            ("Kisi basi YILLIK FM %d (saat)" % ONCEKI, fi["kisi_basi_yillik25"], ADET1),
            ("Kisi basi YILLIK FM %d (saat)" % CARI, fi["kisi_basi_yillik26"], ADET1),
            ("Yillik sinir hizinda kisi-ay %d" % ONCEKI, fi["sinir_hizinda_kisi_ay25"], ADET),
            ("Yillik sinir hizinda kisi-ay %d" % CARI, fi["sinir_hizinda_kisi_ay26"], ADET),
            ("VARSAYIM: kadro %d seviyesinde kalsaydi eksik kisi-ay" % ONCEKI,
             kv["eksik_kisi_ay"], ADET),
            ("VARSAYIM: gereken EK fazla mesai (saat)", kv["ek_fm_saat"], ADET1),
            ("VARSAYIM: kisi basi YILLIK FM (saat)", kv["kisi_basi_yillik_saat"], ADET1),
            ("YASAL UST SINIR (saat/yil/kisi)", f["yasal_yillik_sinir_saat"], ADET1)):
        c0 = ws.cell(s, 1, etiket); c0.border = KENAR
        c = ws.cell(s, 2, val); c.number_format = fmt; c.border = KENAR
        if etiket.startswith("VARSAYIM: kisi basi") or etiket.startswith("YASAL"):
            c0.font = Font(bold=True); c.font = Font(bold=True); c.fill = VURGU
        s += 1
    s += 1

    # --- SEZONUN KALANI: TAHMIN (kullanici istegi 03.09)
    th = veri.get("tahmin") or {}
    if th and not th.get("gerek_yok"):
        ws.cell(s, 1, "SEZONUN KALANI — TAHMIN (%s sonrasi tahmindir)"
                % th["son_gercek_gun"]).font = BOLUM_YAZI
        s += 1
        tkol = [("Ay", 8, None), ("Ciro tipi", 10, None), ("Maliyet tipi", 12, None),
                ("Ciro %d (gercek)" % ONCEKI, 15, TL), ("Ciro %d" % CARI, 15, TL),
                ("Ciro Δ", 9, YUZDE), ("  gerceklesen", 14, TL), ("  tahmin", 14, TL),
                ("Tahmin gunu", 11, ADET), ("FTE %d" % ONCEKI, 10, ADET1),
                ("FTE %d" % CARI, 10, ADET1), ("Maliyet %d" % CARI, 14, TL),
                ("Maliyet/ciro %d" % CARI, 13, None)]
        for i, (ad, gen, _f) in enumerate(tkol, start=1):
            h = ws.cell(s, i, ad); h.fill = BASLIK; h.font = BASLIK_YAZI; h.border = KENAR
            h.alignment = Alignment(horizontal="center")
        s += 1
        for r in th["ay"]:
            tahmin_mi = (r["fte_tip"] == "tahmin")
            ws.cell(s, 1, r["ad"]).border = KENAR
            for kol, tip in ((2, r["ciro_tip"]), (3, r["maliyet_tip"])):
                c = ws.cell(s, kol, tip.upper() if tip != "gerçek" else "gercek")
                c.border = KENAR
                if tip != "gerçek":
                    c.font = Font(bold=True, color="A6001A")
            for kol, val, fmt in ((4, r["ciro_gecen_yil"], TL), (5, r["ciro_toplam"], TL),
                                  (7, r["ciro_gerceklesen"], TL), (8, r["ciro_tahmin"], TL),
                                  (9, r["ciro_tahmin_gun"], ADET),
                                  (10, r["fte_gecen_yil"], ADET1), (11, r["fte"], ADET1),
                                  (12, r["maliyet"], TL),
                                  (13, (r["maliyet"] / r["ciro_toplam"]) if r["ciro_toplam"] else "—",
                                   "0.00%")):
                cc = ws.cell(s, kol, val); cc.number_format = fmt; cc.border = KENAR
                if tahmin_mi:
                    cc.fill = PatternFill("solid", fgColor="FFF6E6")
            cc = ws.cell(s, 6, "=E%d/D%d-1" % (s, s)); cc.number_format = YUZDE; cc.border = KENAR
            s += 1
        # kayma etkisini notrleyen birlesik satir (Agu+Eyl birlikte okunur)
        b_ = th["birlesik_agu_eyl"]
        c0 = ws.cell(s, 1, "Agu+Eyl"); c0.font = Font(bold=True); c0.border = KENAR
        ws.cell(s, 2, "kayma notr").font = Font(italic=True, size=9)
        for kol, val, fmt in ((4, b_["ciro_gecen_yil"], TL), (5, b_["ciro"], TL),
                              (10, b_["fte_gecen_yil"], ADET1), (11, b_["fte"], ADET1),
                              (12, b_["maliyet"], TL)):
            cc = ws.cell(s, kol, val); cc.number_format = fmt; cc.border = KENAR
            cc.fill = PatternFill("solid", fgColor="EFEFEF")
        cc = ws.cell(s, 6, "=E%d/D%d-1" % (s, s)); cc.number_format = YUZDE; cc.border = KENAR
        s += 1
        t_ = th["sezon_toplam"]
        ws.cell(s, 1, "SEZON TOPLAM").font = Font(bold=True)
        ws.cell(s, 1).fill = GRI; ws.cell(s, 1).border = KENAR
        for kol, val, fmt in ((4, t_["ciro_gecen_yil"], TL), (5, t_["ciro"], TL),
                              (10, t_["fte_gecen_yil"], ADET1), (11, t_["fte"], ADET1),
                              (12, t_["maliyet"], TL),
                              (13, t_["maliyet_ciro_orani"] or "—", "0.00%")):
            cc = ws.cell(s, kol, val); cc.number_format = fmt; cc.border = KENAR
            cc.fill = GRI; cc.font = Font(bold=True)
        cc = ws.cell(s, 6, "=E%d/D%d-1" % (s, s)); cc.number_format = YUZDE
        cc.border = KENAR; cc.fill = GRI; cc.font = Font(bold=True)
        s += 2
        ws.cell(s, 1, th["kayma_notu"]).font = Font(bold=True, size=9, color="A6001A")
        s += 1
        ws.cell(s, 1, "YONTEM: %s" % th["yontem"]).font = Font(italic=True, size=9)
        s += 1
        for vs in th["varsayimlar"]:
            ws.cell(s, 1, "VARSAYIM: %s" % vs).font = Font(italic=True, size=9)
            s += 1
        s += 1

    _notlar(ws, [
        "FORMUL: %s" % m["formul"],
        "CALISAN SAYISI TAM GUN KARSILIGIDIR (SGK prim gunu / 30): yarim ay calisan yarim "
        "sayilir. Bordroda gorunen kisi sayisi yaniltir — ay icinde 1 gun calisan da 1 sayilir. "
        "Iki rakam da tabloda yan yana durur.",
        "PENCERE: %s" % m["pencere_aciklama"],
        "SEZON ESAS: kadro sezonda (01.07-31.08) artiyor -> maliyet/FM kiyasi SEZON penceresinde "
        "yapilir. Kumulatif (yilbasindan itibaren) pencere sezonu sulandirir, referans olarak durur.",
        "⚠ %s" % (sz.get("uyari") or "Sezon penceresi tam (Tem+Agu bordrosu islenmis)."),
        "ORAN: maliyet/ciro yuzde PUAN olarak kiyaslanir. Ciro KDV HARIC (maliyet de KDV'siz), "
        "Sinav DAHIL (o satisi da ayni magaza personeli yapiyor).",
        "K-22 VARSAYIM: %s" % f["varsayim"],
        "⚠ Sube dagilimi personelin BUGUNKU subesine gore yapilir (bordro ayindaki subesi degil) — "
        "toplamlar dogru, sube kirilimi yer degistirenlerde kayabilir.",
        "KVKK: kisi bazli ucret/maliyet YOK; tum rakamlar sube/kapsam duzeyinde toplulastirilmis.",
    ], s)
    return ws


# ------------------------------------------------------------------ Yontem
def sayfa_yontem(wb, veri):
    ws = wb.create_sheet("Yontem")
    ws.column_dimensions["A"].width = 24
    ws.column_dimensions["B"].width = 118
    m = veri["meta"]
    ws.cell(1, 1, "Yontem ve kaynaklar").font = Font(bold=True, size=12)

    s = 3
    for etiket, deger in [
        ("Baslik", m["baslik"]),
        ("Kesim tarihi", m["kesim"]),
        ("Pencere", m["pencere"]),
        ("Kadro kaynagi", m["kadro_kaynak"]),
        ("Is hacmi kaynagi", m["hacim_kaynak"]),
        ("Cekirdek SQL", m["cekirdek_sql"]),
    ]:
        a = ws.cell(s, 1, etiket)
        a.font = BOLUM_YAZI
        a.alignment = Alignment(vertical="top")
        b = ws.cell(s, 2, deger)
        b.alignment = Alignment(wrap_text=True, vertical="top")
        ws.row_dimensions[s].height = 30
        s += 1

    s += 1
    ws.cell(s, 1, "Dikkat edilecekler").font = BOLUM_YAZI
    s += 1
    for n in veri["notlar"]:
        c = ws.cell(s, 2, "• " + n)
        c.alignment = Alignment(wrap_text=True, vertical="top")
        c.font = Font(size=9)
        ws.row_dimensions[s].height = 28
        s += 1
    return ws
