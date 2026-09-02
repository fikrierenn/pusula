# -*- coding: utf-8 -*-
"""Slaytlar: norm kadro magaza detayi · norm acigi (bolum bazinda).

Norm bir YONETIM PARAMETRESIDIR (briefings/*/norm-kadro-*.json) ve norm = ENGELLI
DISINDAKI personel sayisidir (yonetim karari 02.09.2026)."""
# ⚠ Yildiz import BILINCLI: palet + cizim yardimcilarinin TAMAMI kullaniliyor ve
#   `bin`/`yzd` gibi bicim yardimcilari sunum_ortak'ta tanimli (tek kaynak).
from sunum_ortak import *          # noqa: F401,F403

def slayt_norm_detay(C):
    """Norm kadro — magaza detayi + kapsam sozlugu."""
    # ================================================================= NORM KADRO
    nrm = C.v.get("norm")
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
             % (sum(m["kadro25"] for m in C.v["magaza"]), sum(m["kadro26"] for m in C.v["magaza"]),
                tp["norm_toplam"], tp["toplam_kesim26"], kad_ops + tp["sezonluk_kesim26"],
                C.k5["kadrolu_kesim26"], C.k5["sezonluk_kesim26"], C.k5["toplam_kesim26"]),
             8, False, INK)], sp=1.08)
        dipnot(s, "* Norm = ENGELLİ DIŞINDAKİ personel sayısı (yönetim kararı); etkinlik de norm dışı. "
                  "Mağaza satırları operasyonel kadroyu gösterir (kadrolu − engelli − etkinlik). "
                  "Engelli %d · etkinlik %d kişi ayrı satırda; en alttaki kayıt toplamı İK'nın resmi "
                  "rakamıdır (kadrolu %d · sezonluk %d) · Norm kaynağı: BKMKİTAP Mağaza Kadro ve Sezon "
                  "Takip Tablosu, %s · Kapsam dışı: %s · Gerçek sayılar 31.08 as-of."
               % (eng_top, etk_top, tp["kadrolu_kesim26"], tp["sezonluk_kesim26"], nrm["tarih"],
                  ", ".join(tr_title(x) for x in nrm["kapsam_disi"]) or "—"))
        sig(s)


def slayt_norm_acigi_bolum(C):
    """Norm acigi — bolum bazinda (+ teyit bekleyen satirlar)."""
    # ================================================================= NORM ACIGI · BOLUM
    if C.nrm and C.nrm.get("bolum"):
        s = add("Yalnızca Başlık"); setph(s, 0, "Norm Açığı — Bölüm Bazında")
        bl = C.nrm["bolum"]
        acik_bolum = C.nrm["acik_bolum_toplam"]
        # K-11/K-06: magaza acigi ve teyit bekleyen acik CEKIRDEKTEN okunur (emitter hesap yapmaz).
        acik_sube = C.nrm["acik_sube_toplam"]
        acik_teyit = C.nrm.get("acik_bolum_teyit", 0)
        teyit_adlar = C.nrm.get("teyit_bolumler", [])

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
                      str(acik_bolum), str(C.nrm["fazla_bolum_toplam"]),
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
                             sorted(C.nrm.get("engelli_bolum", {}).items(), key=lambda x: -x[1])) or "yok",
                  C.nrm["tarih"]))
        sig(s)
