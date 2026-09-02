# -*- coding: utf-8 -*-
"""Personel maliyeti (brut isveren) + fazla mesai / yasal sinir — K-21 ve K-22.

Kaynak: Zirve bordro `dbo.vw_PuanBil`. Maliyet = Bt + Isskk + Iisk (brut toplam + isveren
SGK hissesi + isveren issizlik payi) — yonetimin kendi bordro kontrol formulu.
Yasal cerceve: 4857 s.K. m.41 (yillik 270 saat) + m.63 (45 saat/hafta -> 195 saat/ay).

⚠⚠ OLCU BIRIMI **FTE** (tam zaman esdeger) = `SUM(Primgunu) / 30` — SGK prim gunu, tam ay 30.
Bordro SATIRI (kisi-ay) yaniltir: ay icinde 1 gun calisan da 1 sayilir (kullanici uyarisi
03.09.2026). Olculen sapma: 5 magaza Agustos-2025'te 211 satir vs 168,9 FTE (%25 sisme) —
sezonluk giris/cikis yogun oldugu icin en cok SEZON ayinda sisiyor. Kayit sayisi (`kisi_ay`)
seffaflik icin JSON'da KALIR ama kisi-basi metrikler FTE ile hesaplanir.

UC PENCERE birden uretilir (kullanici uyarisi 03.09.2026 — "analizi sezon icin yapman
gerekmiyor muydu, kadro artisini aylik yapmalisin"):
  * `ay`       — AY x YIL kirilimi (kadro artisi ve maliyetin HANGI AY olustugu gorunur)
  * `sezon`    — 01.07-31.08 sezon penceresi (bordro kosmus aylarla; eksik ay BAYRAKLI)
  * `kumulatif`— yilbasindan son tam bordro ayina (yil geneli referansi)
Sezon penceresi ESAS, kumulatif referanstir; ikisi ayni tabloda yan yana ETIKETLI durur.
"""
import sys

from verimlilik_ortak import (AY_AD_KISA, AY_NORMAL_SAAT, CARI, FM_YILLIK_SINIR, MEKAN,
                              ONCEKI, SUBE)


def cek_maliyet(zc, veri, ciro_ay):
    """Bordro maliyet + fazla mesai bloklari. Pencere = son TAM bordro ayi (dinamik)."""
    # 12) PERSONEL MALIYETI + FAZLA MESAI (K-21 + K-22) — Zirve bordro (vw_PuanBil).
    #   Pencere DINAMIK: son TAM bordro ayina kadar. (2026 Agustos bordrosu henuz kosmamis:
    #   31 kisi vs Temmuz 256 -> o ayi almak maliyeti %88 eksik gosterirdi.)
    print("Zirve: bordro maliyet + fazla mesai...", flush=True)
    zc.execute("""
        SELECT b.Yil, b.Ayindex, COUNT(*) AS kisi
        FROM dbo.vw_PuanBil b
        INNER JOIN dbo.vw_PersonelDepartman p ON p.Personelno = b.Personelno
        WHERE b.Yil IN (?, ?) AND p.Lokasyon LIKE 'MA%'
        GROUP BY b.Yil, b.Ayindex""", ONCEKI, CARI)
    bordro_ay = {}
    for yil, ay_, kisi in zc.fetchall():
        bordro_ay[(int(yil), int(ay_))] = int(kisi)
    if not bordro_ay:
        sys.exit("BORDRO VERİSİ YOK (vw_PuanBil) — maliyet bloğu üretilemez.")
    zirve_max = {y: max((k for (yy, _a), k in bordro_ay.items() if yy == y), default=0)
                 for y in (ONCEKI, CARI)}
    son_ay = 0
    for ay_ in range(1, 13):
        tam = all(bordro_ay.get((y, ay_), 0) >= 0.6 * zirve_max[y] for y in (ONCEKI, CARI))
        if not tam:
            break
        son_ay = ay_
    if son_ay < 3:
        sys.exit("BORDRO PENCERESİ ÇOK KISA (son tam ay %d) — maliyet kıyası yapılamaz." % son_ay)

    zc.execute("""
        SELECT b.Yil, p.AltLokasyon,
               COUNT(*)                                      AS kisi_ay,
               SUM(CAST(b.Primgunu AS float))                 AS prim_gun,
               SUM(b.Bt)                                      AS brut,
               SUM(b.Isskk)                                   AS isv_sgk,
               SUM(b.Iisk)                                    AS isv_issizlik,
               SUM(b.Bt + b.Isskk + b.Iisk)                   AS maliyet,
               SUM(b.Netu)                                    AS net,
               SUM(b.fm1 + b.fm2 + b.fm3)                     AS fm_saat,
               SUM(b.fmtutar1 + b.fmtutar2 + b.fmtutar3)      AS fm_tutar,
               SUM(CASE WHEN (b.fm1 + b.fm2 + b.fm3) > 0 THEN 1 ELSE 0 END)  AS fm_yapan_kisi_ay,
               SUM(CASE WHEN (b.fm1 + b.fm2 + b.fm3) > ? THEN 1 ELSE 0 END)  AS fm_sinir_hizinda,
               MAX(b.fm1 + b.fm2 + b.fm3)                     AS fm_en_yuksek
        FROM dbo.vw_PuanBil b
        INNER JOIN dbo.vw_PersonelDepartman p ON p.Personelno = b.Personelno
        WHERE b.Yil IN (?, ?) AND b.Ayindex BETWEEN 1 AND ? AND p.Lokasyon LIKE 'MA%'
        GROUP BY b.Yil, p.AltLokasyon""",
               FM_YILLIK_SINIR / 12.0, ONCEKI, CARI, son_ay)
    mal_sube = {}
    for (yil, sube, kisi_ay, prim_gun, brut, isvs, isvi, mal, net_, fms, fmt, fmy, fmsn,
         fmmax) in zc.fetchall():
        mal_sube[(int(yil), sube)] = {
            "kisi_ay": int(kisi_ay), "prim_gun": float(prim_gun or 0),
            "fte": float(prim_gun or 0) / 30.0, "brut": float(brut or 0),
            "isveren_sgk": float(isvs or 0), "isveren_issizlik": float(isvi or 0),
            "maliyet": float(mal or 0), "net": float(net_ or 0),
            "fm_saat": float(fms or 0), "fm_tutar": float(fmt or 0),
            "fm_yapan_kisi_ay": int(fmy or 0), "fm_sinir_hizinda_kisi_ay": int(fmsn or 0),
            "fm_en_yuksek_kisi_ay": float(fmmax or 0)}
    # AY x YIL x SUBE kirilimi — sezon/kumulatif pencereler bundan TURETILIR (tek sorgu).
    zc.execute("""
        SELECT b.Yil, b.Ayindex, p.AltLokasyon,
               COUNT(*)                                       AS kisi_ay,
               SUM(CAST(b.Primgunu AS float))                 AS prim_gun,
               SUM(b.Bt + b.Isskk + b.Iisk)                   AS maliyet,
               SUM(b.Bt)                                      AS brut,
               SUM(b.Isskk)                                   AS isv_sgk,
               SUM(b.Iisk)                                    AS isv_issizlik,
               SUM(b.Netu)                                    AS net,
               SUM(b.fm1 + b.fm2 + b.fm3)                     AS fm_saat,
               SUM(b.fmtutar1 + b.fmtutar2 + b.fmtutar3)      AS fm_tutar,
               SUM(CASE WHEN (b.fm1 + b.fm2 + b.fm3) > 0 THEN 1 ELSE 0 END)  AS fm_yapan_kisi_ay,
               SUM(CASE WHEN (b.fm1 + b.fm2 + b.fm3) > ? THEN 1 ELSE 0 END)  AS fm_sinir_hizinda
        FROM dbo.vw_PuanBil b
        INNER JOIN dbo.vw_PersonelDepartman p ON p.Personelno = b.Personelno
        WHERE b.Yil IN (?, ?) AND b.Ayindex BETWEEN 1 AND ? AND p.Lokasyon LIKE 'MA%'
        GROUP BY b.Yil, b.Ayindex, p.AltLokasyon""",
               FM_YILLIK_SINIR / 12.0, ONCEKI, CARI, son_ay)
    ay_sube = {}
    for (yil, ay_, sube, kisi_ay, prim_gun, mal_, brut, isvs, isvi, net_, fms, fmt, fmy,
         fmsn) in zc.fetchall():
        ay_sube[(int(yil), int(ay_), sube)] = {
            "kisi_ay": int(kisi_ay), "prim_gun": float(prim_gun or 0),
            "fte": float(prim_gun or 0) / 30.0,
            "maliyet": float(mal_ or 0), "brut": float(brut or 0),
            "isveren_sgk": float(isvs or 0), "isveren_issizlik": float(isvi or 0),
            "net": float(net_ or 0), "fm_saat": float(fms or 0), "fm_tutar": float(fmt or 0),
            "fm_yapan_kisi_ay": int(fmy or 0), "fm_sinir_hizinda_kisi_ay": int(fmsn or 0)}

    for yil in (ONCEKI, CARI):
        if not any(y == yil for (y, _s) in mal_sube):
            sys.exit("BORDRO KAPSAMI BOŞ: %d yılında mağaza personeli bulunamadı." % yil)

    def _mtop(yil, subeler):
        alanlar = ("kisi_ay", "prim_gun", "fte", "brut", "isveren_sgk", "isveren_issizlik",
                   "maliyet", "net", "fm_saat", "fm_tutar", "fm_yapan_kisi_ay",
                   "fm_sinir_hizinda_kisi_ay")
        d = {a: sum(mal_sube.get((yil, sb), {}).get(a, 0) for sb in subeler) for a in alanlar}
        d["fm_en_yuksek_kisi_ay"] = max(
            [mal_sube.get((yil, sb), {}).get("fm_en_yuksek_kisi_ay", 0) for sb in subeler] or [0])
        return d

    POS_SUBELER = [SUBE[m] for m in MEKAN]
    TUM_SUBELER = sorted({sb for (_y, sb) in mal_sube})
    maliyet = {"pencere_ay": son_ay,
               "pencere": "01-%02d ay (Oca–%s), her iki yıl" % (son_ay, AY_AD_KISA[son_ay]),
               "kapsam_pos": POS_SUBELER, "kapsam_tum": TUM_SUBELER,
               "sube": {"%s|%d" % (sb, y): mal_sube[(y, sb)] for (y, sb) in sorted(
                   mal_sube, key=lambda t: (t[1], t[0]))},
               "pos": {}, "tum": {}, "formul": "Personel maliyeti = Brüt Toplam (Bt) + İşveren "
               "SGK Hissesi (Isskk) + İşveren İşsizlik Payı (Iisk) — Zirve bordro vw_PuanBil, "
               "yönetimin kendi bordro kontrol raporundaki formül."}
    for yil in (ONCEKI, CARI):
        ek = yil % 100
        maliyet["pos"]["%d" % ek] = _mtop(yil, POS_SUBELER)
        maliyet["tum"]["%d" % ek] = _mtop(yil, TUM_SUBELER)
        ciro = sum(ciro_ay.get((yil, a_), (0.0, 0.0))[0] for a_ in range(1, son_ay + 1))
        adet_ = sum(ciro_ay.get((yil, a_), (0.0, 0.0))[1] for a_ in range(1, son_ay + 1))
        if ciro <= 0:
            sys.exit("CİRO PENCERESİ BOŞ (%d, 1-%d ay) — maliyet oranı hesaplanamaz." % (yil, son_ay))
        p_ = maliyet["pos"]["%d" % ek]
        p_["ciro_kdvharic"] = ciro
        p_["adet"] = adet_
        p_["maliyet_ciro_orani"] = p_["maliyet"] / ciro
        # ⚠ KISI-BASI metrikler FTE ile (bordro satiri degil) — yarim ay calisan 1 sayilmaz
        p_["fte_basi_maliyet"] = p_["maliyet"] / p_["fte"] if p_["fte"] else 0.0
        p_["fte_basi_ciro"] = ciro / p_["fte"] if p_["fte"] else 0.0
        p_["fm_fte_basi_saat"] = p_["fm_saat"] / p_["fte"] if p_["fte"] else 0.0
        p_["fm_yillik_fte_saat"] = p_["fm_fte_basi_saat"] * 12.0
        p_["ort_prim_gun"] = p_["prim_gun"] / p_["kisi_ay"] if p_["kisi_ay"] else 0.0

    # ---- PENCERELER: sezon (Tem-Agu) + aylik. Kumulatif blok yukarida "pos"/"tum" olarak duruyor.
    ALANLAR = ("kisi_ay", "prim_gun", "fte", "brut", "isveren_sgk", "isveren_issizlik",
               "maliyet", "net", "fm_saat", "fm_tutar", "fm_yapan_kisi_ay",
               "fm_sinir_hizinda_kisi_ay")

    def _pencere(yil, aylar, subeler):
        d = {a: sum(ay_sube.get((yil, ay_, sb), {}).get(a, 0)
                    for ay_ in aylar for sb in subeler) for a in ALANLAR}
        d["ciro_kdvharic"] = sum(ciro_ay.get((yil, ay_), (0.0, 0.0))[0] for ay_ in aylar)
        d["adet"] = sum(ciro_ay.get((yil, ay_), (0.0, 0.0))[1] for ay_ in aylar)
        d["aylar"] = list(aylar)
        if d["fte"]:
            d["fte_basi_maliyet"] = d["maliyet"] / d["fte"]
            d["fte_basi_ciro"] = d["ciro_kdvharic"] / d["fte"]
            d["fm_fte_basi_saat"] = d["fm_saat"] / d["fte"]
            d["fm_yillik_fte_saat"] = d["fm_saat"] / d["fte"] * 12.0
        if d["kisi_ay"]:
            d["ort_prim_gun"] = d["prim_gun"] / d["kisi_ay"]
        if d["ciro_kdvharic"]:
            d["maliyet_ciro_orani"] = d["maliyet"] / d["ciro_kdvharic"]
        return d

    # SEZON = 01.07-31.08; bordro kosmus aylarla sinirli (2026 Agustos henuz yok -> BAYRAK)
    sezon_aylar = [a_ for a_ in (7, 8) if a_ <= son_ay]
    if not sezon_aylar:
        sys.exit("SEZON PENCERESİ BOŞ: bordro son tam ay %d, sezon ayı (7-8) yok." % son_ay)
    maliyet["sezon"] = {
        "aylar": sezon_aylar,
        "etiket": (AY_AD_KISA[sezon_aylar[0]] if len(sezon_aylar) == 1
                   else "%s–%s" % (AY_AD_KISA[sezon_aylar[0]], AY_AD_KISA[sezon_aylar[-1]])),
        "eksik_aylar": [a_ for a_ in (7, 8) if a_ not in sezon_aylar],
        "tam_mi": sezon_aylar == [7, 8],
        "pos": {"%d" % (y % 100): _pencere(y, sezon_aylar, POS_SUBELER) for y in (ONCEKI, CARI)},
        "tum": {"%d" % (y % 100): _pencere(y, sezon_aylar, TUM_SUBELER) for y in (ONCEKI, CARI)},
    }
    if not maliyet["sezon"]["tam_mi"]:
        maliyet["sezon"]["uyari"] = (
            "⚠ SEZON PENCERESİ EKSİK: %s ayı bordrosu henüz koşmadı (%d yılı). Sezon karşılaştırması "
            "%s ayı/ayları ile sınırlıdır; Ağustos bordrosu işlendiğinde bu blok kendiliğinden "
            "tamamlanır. Yıl geneli için «kümülatif» pencereye bakılır."
            % (", ".join(AY_AD_KISA[a_] for a_ in maliyet["sezon"]["eksik_aylar"]), CARI,
               ", ".join(AY_AD_KISA[a_] for a_ in sezon_aylar)))

    # AYLIK kirilim — kadro (kisi-ay) ve maliyetin HANGI AY olustugu
    maliyet["ay"] = []
    for ay_ in range(1, son_ay + 1):
        satir = {"ay": ay_, "ad": AY_AD_KISA[ay_], "sezon_mu": ay_ in (7, 8)}
        for yil in (ONCEKI, CARI):
            ek = yil % 100
            p_ = _pencere(yil, [ay_], POS_SUBELER)
            satir["kisi_ay%d" % ek] = p_["kisi_ay"]
            satir["fte%d" % ek] = p_["fte"]
            satir["ort_prim_gun%d" % ek] = p_.get("ort_prim_gun", 0.0)
            satir["maliyet%d" % ek] = p_["maliyet"]
            satir["fm_saat%d" % ek] = p_["fm_saat"]
            satir["ciro%d" % ek] = p_["ciro_kdvharic"]
            satir["oran%d" % ek] = p_.get("maliyet_ciro_orani")
        maliyet["ay"].append(satir)

    maliyet["pencere_aciklama"] = (
        "SEZON penceresi esastır (%s); KÜMÜLATİF pencere (%s) yıl geneli referansıdır. Aylık "
        "kırılım kadro ve maliyet artışının hangi ayda oluştuğunu gösterir." % (
            maliyet["sezon"]["etiket"], maliyet["pencere"]))

    # K-22: "kadro almasaydik ne olurdu" — eksik kisi-ay kapasitesi fazla mesaiye biner.
    #   Model: kadro ONCEKI yilin kisi-ay seviyesinde kalsaydi, aradaki kisi-ay farki
    #   AY_NORMAL_SAAT kadar calisma kapasitesi eksigi demektir; bu eksik ancak fazla mesai
    #   ile kapanirdi. VARSAYIM: is hacmi ayni kalir ve isgucu ihtiyaci kisiyle dogru orantili.
    # ⚠ MODEL SEZON PENCERESINDE kurulur (kullanici uyarisi 03.09): kadro sezonda artiyor,
    #   yil geneli kumulatif pencere sezonu suladiriyor. Kumulatif surum de raporlanir.
    p25 = maliyet["sezon"]["pos"]["%d" % (ONCEKI % 100)]
    p26 = maliyet["sezon"]["pos"]["%d" % (CARI % 100)]
    k25 = maliyet["pos"]["%d" % (ONCEKI % 100)]
    k26 = maliyet["pos"]["%d" % (CARI % 100)]
    # ⚠ EKSIK KAPASITE FTE farkindan hesaplanir: bordro satiri (kisi-ay) yarim ay calisani
    #   tam sayar ve kapasite farkini SISIRIR (kullanici uyarisi 03.09.2026).
    eksik_fte = p26["fte"] - p25["fte"]
    eksik_kisi_ay = p26["kisi_ay"] - p25["kisi_ay"]      # seffaflik: kayit farki da tutulur
    ek_fm = max(0.0, eksik_fte) * AY_NORMAL_SAAT
    varsayim_fm = p26["fm_saat"] + ek_fm
    kisi_ay_taban = p25["fte"] or 1
    veri["fazla_mesai"] = {
        "pencere_ay": son_ay,
        "pencere": "SEZON — %s (%s)" % (maliyet["sezon"]["etiket"],
                                        "tam" if maliyet["sezon"]["tam_mi"] else "eksik ay var"),
        "sezon_aylar": sezon_aylar,
        "kumulatif": {"fm_saat25": k25["fm_saat"], "fm_saat26": k26["fm_saat"],
                      "kisi_ay25": k25["kisi_ay"], "kisi_ay26": k26["kisi_ay"],
                      "fte25": k25["fte"], "fte26": k26["fte"],
                      "kisi_basi_yillik25": k25.get("fm_yillik_fte_saat", 0.0),
                      "kisi_basi_yillik26": k26.get("fm_yillik_fte_saat", 0.0)},
        "yasal_yillik_sinir_saat": FM_YILLIK_SINIR,
        "ay_normal_saat": AY_NORMAL_SAAT,
        "fiili": {"fm_saat26": p26["fm_saat"], "fm_saat25": p25["fm_saat"],
                  "kisi_ay26": p26["kisi_ay"], "kisi_ay25": p25["kisi_ay"],
                  "fte26": p26["fte"], "fte25": p25["fte"],
                  "kisi_basi_yillik26": p26.get("fm_yillik_fte_saat", 0.0),
                  "kisi_basi_yillik25": p25.get("fm_yillik_fte_saat", 0.0),
                  "sinir_hizinda_kisi_ay26": p26["fm_sinir_hizinda_kisi_ay"],
                  "sinir_hizinda_kisi_ay25": p25["fm_sinir_hizinda_kisi_ay"]},
        "kadro_artmasaydi": {
            "eksik_fte": eksik_fte,
            "eksik_kisi_ay": eksik_kisi_ay,
            "ek_fm_saat": ek_fm,
            "toplam_fm_saat": varsayim_fm,
            "kisi_basi_yillik_saat": (varsayim_fm / kisi_ay_taban) * 12.0,
            "sinir_asimi": (varsayim_fm / kisi_ay_taban) * 12.0 > FM_YILLIK_SINIR},
        "varsayim": ("SEZON penceresinde (%s) ölçülür; birim FTE (tam zaman eşdeğer = SGK prim "
                     "günü ÷ 30) — bordro satırı sayılsaydı yarım ay çalışan tam sayılır ve "
                     "kapasite farkı şişerdi. İşgücü ihtiyacı FTE ile doğru orantılı kabul edilir; "
                     "%.1f FTE'lik kapasite eksiği ancak fazla mesaiyle kapanırdı "
                     "(FTE başına %.0f saat "
                     "normal çalışma). Yasal çerçeve: 4857 s.K. m.41 yıllık %d saat üst sınır. "
                     "Yıllıklandırma: sezon ayı başına düşen fazla mesai × 12 (sezon yoğunluğunun "
                     "yıla yayılması hâlinde ulaşacağı seviye)."
                     % (maliyet["sezon"]["etiket"], eksik_fte, AY_NORMAL_SAAT,
                        int(FM_YILLIK_SINIR))),
        "kaynak": "Zirve BKM_GENEL dbo.vw_PuanBil — fm1+fm2+fm3 (saat), fmtutar1..3 (tutar); "
                  "kapasite birimi FTE = SUM(Primgunu)/30"}
    veri["maliyet"] = maliyet
