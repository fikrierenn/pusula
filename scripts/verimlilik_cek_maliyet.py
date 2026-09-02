# -*- coding: utf-8 -*-
"""Personel maliyeti (brut isveren) + fazla mesai / yasal sinir — K-21 ve K-22.

Kaynak: Zirve bordro `dbo.vw_PuanBil`. Maliyet = Bt + Isskk + Iisk (brut toplam + isveren
SGK hissesi + isveren issizlik payi) — yonetimin kendi bordro kontrol formulu.
Yasal cerceve: 4857 s.K. m.41 (yillik 270 saat) + m.63 (45 saat/hafta -> 195 saat/ay).
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
    for (yil, sube, kisi_ay, brut, isvs, isvi, mal, net_, fms, fmt, fmy, fmsn, fmmax) in zc.fetchall():
        mal_sube[(int(yil), sube)] = {
            "kisi_ay": int(kisi_ay), "brut": float(brut or 0),
            "isveren_sgk": float(isvs or 0), "isveren_issizlik": float(isvi or 0),
            "maliyet": float(mal or 0), "net": float(net_ or 0),
            "fm_saat": float(fms or 0), "fm_tutar": float(fmt or 0),
            "fm_yapan_kisi_ay": int(fmy or 0), "fm_sinir_hizinda_kisi_ay": int(fmsn or 0),
            "fm_en_yuksek_kisi_ay": float(fmmax or 0)}
    for yil in (ONCEKI, CARI):
        if not any(y == yil for (y, _s) in mal_sube):
            sys.exit("BORDRO KAPSAMI BOŞ: %d yılında mağaza personeli bulunamadı." % yil)

    def _mtop(yil, subeler):
        alanlar = ("kisi_ay", "brut", "isveren_sgk", "isveren_issizlik", "maliyet", "net",
                   "fm_saat", "fm_tutar", "fm_yapan_kisi_ay", "fm_sinir_hizinda_kisi_ay")
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
        p_["kisi_ay_basi_maliyet"] = p_["maliyet"] / p_["kisi_ay"] if p_["kisi_ay"] else 0.0
        p_["kisi_ay_basi_ciro"] = ciro / p_["kisi_ay"] if p_["kisi_ay"] else 0.0
        p_["fm_kisi_ay_basi_saat"] = p_["fm_saat"] / p_["kisi_ay"] if p_["kisi_ay"] else 0.0
        p_["fm_yillik_kisi_basi_saat"] = p_["fm_kisi_ay_basi_saat"] * 12.0

    # K-22: "kadro almasaydik ne olurdu" — eksik kisi-ay kapasitesi fazla mesaiye biner.
    #   Model: kadro ONCEKI yilin kisi-ay seviyesinde kalsaydi, aradaki kisi-ay farki
    #   AY_NORMAL_SAAT kadar calisma kapasitesi eksigi demektir; bu eksik ancak fazla mesai
    #   ile kapanirdi. VARSAYIM: is hacmi ayni kalir ve isgucu ihtiyaci kisiyle dogru orantili.
    p25 = maliyet["pos"]["%d" % (ONCEKI % 100)]
    p26 = maliyet["pos"]["%d" % (CARI % 100)]
    eksik_kisi_ay = p26["kisi_ay"] - p25["kisi_ay"]
    ek_fm = max(0.0, eksik_kisi_ay) * AY_NORMAL_SAAT
    varsayim_fm = p26["fm_saat"] + ek_fm
    kisi_ay_taban = p25["kisi_ay"] or 1
    veri["fazla_mesai"] = {
        "pencere_ay": son_ay,
        "yasal_yillik_sinir_saat": FM_YILLIK_SINIR,
        "ay_normal_saat": AY_NORMAL_SAAT,
        "fiili": {"fm_saat26": p26["fm_saat"], "fm_saat25": p25["fm_saat"],
                  "kisi_ay26": p26["kisi_ay"], "kisi_ay25": p25["kisi_ay"],
                  "kisi_basi_yillik26": p26["fm_yillik_kisi_basi_saat"],
                  "kisi_basi_yillik25": p25["fm_yillik_kisi_basi_saat"],
                  "sinir_hizinda_kisi_ay26": p26["fm_sinir_hizinda_kisi_ay"],
                  "sinir_hizinda_kisi_ay25": p25["fm_sinir_hizinda_kisi_ay"]},
        "kadro_artmasaydi": {
            "eksik_kisi_ay": eksik_kisi_ay,
            "ek_fm_saat": ek_fm,
            "toplam_fm_saat": varsayim_fm,
            "kisi_basi_yillik_saat": (varsayim_fm / kisi_ay_taban) * 12.0,
            "sinir_asimi": (varsayim_fm / kisi_ay_taban) * 12.0 > FM_YILLIK_SINIR},
        "varsayim": ("İşgücü ihtiyacı kişi sayısıyla doğru orantılı kabul edilir; %d kişi-aylık "
                     "kapasite eksiği ancak fazla mesaiyle kapanırdı (kişi-ay başına %.0f saat "
                     "normal çalışma). Yasal çerçeve: 4857 s.K. m.41 yıllık %d saat üst sınır."
                     % (eksik_kisi_ay, AY_NORMAL_SAAT, int(FM_YILLIK_SINIR))),
        "kaynak": "Zirve BKM_GENEL dbo.vw_PuanBil — fm1+fm2+fm3 (saat), fmtutar1..3 (tutar)"}
    veri["maliyet"] = maliyet
