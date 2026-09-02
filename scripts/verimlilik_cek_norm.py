# -*- coding: utf-8 -*-
"""Norm kadro karsilastirmasi (yonetim parametresi) + engelli/etkinlik ayrimi.

Norm bir YONETIM PARAMETRESIDIR — Zirve'den sorgulanmaz, briefings/<klasor>/norm-kadro-*.json
dosyasindan okunur. Kural: norm = ENGELLI DISINDAKI personel (yonetim karari 02.09.2026).
"""
import json
import sys
from pathlib import Path

from verimlilik_ortak import ASOF, CARI, ONCEKI


def cek_norm(zc, veri):
    """Norm dosyasini okur, beyani dogrular, sube + bolum karsilastirmasini veri'ye yazar."""
    # 10) NORM KADRO karsilastirmasi — norm bir YONETIM PARAMETRESI, Zirve'den sorgulanmaz.
    #     Dosya: briefings/<klasor>/norm-kadro-YYYYMMDD.json (kullanici/IK verir, tarihli).
    #     ⚠ Norm SEZON DISI kadroyu tanimlar -> sezonluk personel norma dahil DEGIL; kiyas
    #     yalnizca KADROLU sayilarla yapilir. Sura norm tablosunda yok, kapsam disi tutulur.
    norm_dosya = sorted(Path(__file__).resolve().parent.parent.joinpath(
        "briefings", "sezon-kadro-20260902").glob("norm-kadro-*.json"))
    if norm_dosya:
        nd = json.loads(norm_dosya[-1].read_text(encoding="utf-8"))
        print("Norm kadro dosyası: %s" % norm_dosya[-1].name, flush=True)
        # ⚠ sube_esleme UYGULANIR (norm dosyasi "İSTANBUL YOLU" yazarsa Zirve "İST. YOLU" ile
        #   eslesmez ve o subenin normu SESSIZCE dusardi — silent-failure-hunter bulgusu 3).
        esleme = nd.get("sube_esleme", {})
        norm_sube, norm_bolum = {}, {}
        for bol, subeler in nd["norm"].items():
            norm_bolum[bol] = sum(subeler.values())
            for sube, adet in subeler.items():
                sube = esleme.get(sube, sube)
                norm_sube[sube] = norm_sube.get(sube, 0) + adet
        # BEYAN DOGRULAMASI (bulgu 4): elle girilen norm tablosunun kendi toplam satiriyla
        # departman toplamlari tutmali. Tek hucre yanlis girilirse burada patlar.
        beyan = nd.get("beyan_edilen_toplam", {})
        for sube, bekl in beyan.items():
            if sube == "GENEL":
                continue
            hedef = esleme.get(sube, sube)
            if norm_sube.get(hedef) != bekl:
                sys.exit("NORM DOSYASI TUTARSIZ: %s departman toplamı %s, beyan %s (dosya: %s)"
                         % (hedef, norm_sube.get(hedef), bekl, norm_dosya[-1].name))
        if beyan.get("GENEL") not in (None, sum(norm_sube.values())):
            sys.exit("NORM DOSYASI TUTARSIZ: genel toplam %d, beyan %s"
                     % (sum(norm_sube.values()), beyan.get("GENEL")))
        beyan_sez = nd.get("beyan_edilen_toplam_sezonluk", {})
        nsez_top = sum(v_ for k_, v_ in nd.get("norm_sezonluk", {}).items())
        if beyan_sez.get("GENEL") not in (None, nsez_top):
            sys.exit("NORM DOSYASI TUTARSIZ: sezonluk norm toplamı %d, beyan %s"
                     % (nsez_top, beyan_sez.get("GENEL")))
        mk = {m["sube"]: m for m in veri["magaza_kadro"]}
        satirlar = []
        for sube, nm in sorted(norm_sube.items(), key=lambda x: -x[1]):
            m = mk.get(sube)
            if not m:
                sys.exit("NORM ŞUBESİ EŞLEŞMEDİ: '%s' Zirve şube listesinde yok (%s). "
                         "norm dosyasındaki sube_esleme sözlüğünü güncelle — aksi halde o şubenin "
                         "normu sessizce düşer." % (sube, ", ".join(sorted(mk))))
            nsez = nd.get("norm_sezonluk", {}).get(sube, 0)
            if not nsez:   # esleme uygulanmis adla da dene
                nsez = next((v_ for k_, v_ in nd.get("norm_sezonluk", {}).items()
                             if esleme.get(k_, k_) == sube), 0)
            satirlar.append({"sube": sube, "norm": nm, "norm_sezonluk": nsez,
                             "norm_toplam": nm + nsez,
                             "kadrolu_taban26": m["kadrolu_taban26"],
                             "kadrolu_kesim26": m["kadrolu_kesim26"],
                             "sezonluk_kesim26": m["sezonluk_kesim26"],
                             "toplam_kesim26": m["kadrolu_kesim26"] + m["sezonluk_kesim26"]})
        # BOLUM bazinda norm vs gercek (yalniz norm tablosundaki magazalar)
        norm_subeler = set(norm_sube)
        # ⚠ KARAR: engelli norm DISI -> bolum bazinda da dusulur. Bolum dagilimi canli olculur.
        zc.execute("""
            SELECT x.bolum, SUM(x.eng)
            FROM (
                SELECT COALESCE(v.Departman, N'(tanımsız)') AS bolum,
                       CASE WHEN EXISTS (SELECT 1 FROM dbo.perbilgi p
                                          WHERE p.Personelno = CASE WHEN CHARINDEX('-', v.Personelno) > 1
                                                     AND ISNUMERIC(LEFT(v.Personelno, CHARINDEX('-', v.Personelno) - 1)) = 1
                                                THEN CONVERT(int, LEFT(v.Personelno, CHARINDEX('-', v.Personelno) - 1)) END
                                            AND v.Personelno LIKE '%-BKM'
                                            AND (LTRIM(RTRIM(CAST(p.Kanun AS nvarchar(20)))) = '14857'
                                              OR LTRIM(RTRIM(CAST(p.Ozurlulukkodu AS nvarchar(10)))) = 'E'))
                            THEN 1 ELSE 0 END AS eng
                FROM dbo.vw_PersonelDepartman v
                WHERE v.AltLokasyon IN (?, ?, ?, ?)
                  AND v.Lokasyon LIKE 'MA%'          -- ⚠ kapsam sizintisi guard'i (bulgu 5)
                  AND COALESCE(v.Kadro,'') <> 'SEZONLUK'
                  AND v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?)
            ) x
            GROUP BY x.bolum""", *(list(norm_subeler) + ["%d0831" % CARI, "%d0831" % CARI]))
        eng_bolum = {b: int(k) for b, k in zc.fetchall() if k}
        # K-09: engelli tespiti Personelno'yu "<no>-BKM" bicimine gore ayristirir. Bicim bozuksa
        #   (tire yok / sol taraf sayi degil) kisi SESSIZCE "engelli degil" sayilir -> engelli az,
        #   operasyonel kadro fazla, norm acigi KUCUK gorunur. Atlanan satir sayisi olculur.
        zc.execute("""
            SELECT COUNT(*) FROM dbo.vw_PersonelDepartman v
            WHERE v.Lokasyon LIKE 'MA%' AND COALESCE(v.Kadro,'') <> 'SEZONLUK'
              AND v.Personelno LIKE '%-BKM'
              AND NOT (CHARINDEX('-', v.Personelno) > 1
                       AND ISNUMERIC(LEFT(v.Personelno, CHARINDEX('-', v.Personelno) - 1)) = 1)
              AND """ + ASOF, "%d0831" % CARI, "%d0831" % CARI)
        eng_atlanan = int(zc.fetchone()[0] or 0)
        if eng_atlanan:
            print("  ⚠ engelli taramasında %d kayıt Personelno biçimi yüzünden atlandı — "
                  "engelli sayısı ALT SINIR." % eng_atlanan, flush=True)
        ger_bolum, sez_bolum = {}, {}
        for r in veri["magaza_bolum"]:
            if r["sube"] in norm_subeler:
                ger_bolum[r["bolum"]] = ger_bolum.get(r["bolum"], 0) + r["kadrolu26"]
                sez_bolum[r["bolum"]] = sez_bolum.get(r["bolum"], 0) + r["sezonluk26"]
        bolum_kars = []
        # ⚠ IKINCIL ANAHTAR SART: esit acikta set siralamasi calisma-arasi DEGISIYOR
        #   (PYTHONHASHSEED) -> ayni veriden farkli satir sirasi, "en buyuk aciklar" karti kayiyor.
        for b in sorted(set(norm_bolum) | set(ger_bolum),
                        key=lambda x: (-max(0, norm_bolum.get(x, 0) - ger_bolum.get(x, 0)), x)):
            nm, gr0, sz = norm_bolum.get(b, 0), ger_bolum.get(b, 0), sez_bolum.get(b, 0)
            if not (nm or gr0 or sz):
                continue
            eng = eng_bolum.get(b, 0)
            gr = gr0 - eng                      # engelli norm disi -> operasyonel kadrolu
            # K-06: normda tanimli ama kayitta HIC kisi olmayan bolum (MUHASEBE 1/0, OYUN ALANI
            #   1/0) "acik" sayilmaz. Iki olasilik ayirt edilemiyor: (a) bolum gercekten bos,
            #   (b) bolum adi Zirve'de baska yazili (key-mismatch). Ayri "teyit gerekiyor"
            #   satirina alinir; operasyonel acik toplamina GIRMEZ.
            teyit = (nm > 0 and gr0 == 0)
            bolum_kars.append({"bolum": b, "norm": nm, "kadrolu26": gr, "kayit_kadrolu26": gr0,
                               "engelli26": eng, "norm_disi": (b == "ETKİNLİK"),
                               "teyit_gerekiyor": teyit,
                               "acik": max(0, nm - gr), "fazla": max(0, gr - nm), "sezonluk26": sz})
        veri["norm"] = {
            "tarih": nd["meta"]["tarih"], "kaynak_dosya": norm_dosya[-1].name,
            "kapsam_disi": [x for x in mk if x not in norm_sube],
            "sube": satirlar,
            "bolum": bolum_kars,
            # ⚠ Bolum bazinda acik toplami, magaza bazindan BUYUK olur: magaza icinde bir bolumun
            #   fazlasi baska bolumun acigini maskeler (net -8, magaza-acik 11, bolum-acik 15).
            "acik_bolum_toplam": sum(r["acik"] for r in bolum_kars
                                     if not r["norm_disi"] and not r["teyit_gerekiyor"]),
            # normda var ama kayitta hic kisi yok -> teyit bekleyen (acik toplamina girmez, K-06)
            "acik_bolum_teyit": sum(r["acik"] for r in bolum_kars if r["teyit_gerekiyor"]),
            "teyit_bolumler": [r["bolum"] for r in bolum_kars if r["teyit_gerekiyor"]],
            "fazla_bolum_toplam": sum(r["fazla"] for r in bolum_kars if not r["norm_disi"]),
            "engelli_bolum": eng_bolum, "engelli_format_atlanan": eng_atlanan,
            "toplam": {"norm": sum(r["norm"] for r in satirlar),
                       "norm_sezonluk": sum(r["norm_sezonluk"] for r in satirlar),
                       "norm_toplam": sum(r["norm_toplam"] for r in satirlar),
                       "kadrolu_taban26": sum(r["kadrolu_taban26"] for r in satirlar),
                       "kadrolu_kesim26": sum(r["kadrolu_kesim26"] for r in satirlar),
                       "sezonluk_kesim26": sum(r["sezonluk_kesim26"] for r in satirlar),
                       "toplam_kesim26": sum(r["toplam_kesim26"] for r in satirlar)},
        }


        # ENGELLI / ETKINLIK sube bazinda (kadrolu, kesim gunu) — ayri satir gosterimi icin.
        # ⚠ Engelli tespiti perbilgi'ye dayanir -> yalniz BKM_GENEL; diger firmalarda ALT SINIR.
        zc.execute("""
            SELECT x.sube, SUM(x.etk) AS etkinlik, SUM(x.eng) AS engelli, SUM(x.bkm) AS bkm_genel_kisi
            FROM (
                SELECT v.AltLokasyon AS sube,
                       CASE WHEN v.Departman = N'ETKİNLİK' THEN 1 ELSE 0 END AS etk,
                       CASE WHEN EXISTS (SELECT 1 FROM dbo.perbilgi p
                                          WHERE p.Personelno = CASE WHEN CHARINDEX('-', v.Personelno) > 1
                                                     AND ISNUMERIC(LEFT(v.Personelno, CHARINDEX('-', v.Personelno) - 1)) = 1
                                                THEN CONVERT(int, LEFT(v.Personelno, CHARINDEX('-', v.Personelno) - 1)) END
                                            AND v.Personelno LIKE '%-BKM'
                                            AND (LTRIM(RTRIM(CAST(p.Kanun AS nvarchar(20)))) = '14857'
                                              OR LTRIM(RTRIM(CAST(p.Ozurlulukkodu AS nvarchar(10)))) = 'E'))
                            THEN 1 ELSE 0 END AS eng,
                       CASE WHEN v.Firma = 'BKM_GENEL' THEN 1 ELSE 0 END AS bkm
                FROM dbo.vw_PersonelDepartman v
                WHERE v.Lokasyon LIKE 'MA%' AND COALESCE(v.Kadro,'') <> 'SEZONLUK'
                  AND v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?)
            ) x
            GROUP BY x.sube""", "%d0831" % CARI, "%d0831" % CARI)
        ayrik = {}
        for sube, etk, eng, bkm in zc.fetchall():
            ayrik[sube] = {"etkinlik": int(etk or 0), "engelli": int(eng or 0),
                           "bkm_genel_kisi": int(bkm or 0)}
        # ⚠ ayrik BES magaza kapsaminda olculur ama DORT norm magazasinin toplamindan dusulur;
        #   norm disi subeleri (Sura) ayikla, yoksa kapsam disi bir kisi norm acigini kaydirir
        #   (silent-failure-hunter bulgusu 6).
        ayrik = {k_: val for k_, val in ayrik.items() if k_ in norm_sube}
        veri["norm"]["ayrik"] = ayrik
        # magaza acigi TEK KAYNAK: iki emitter da bunu okur (bulgu 7 — Excel 11, deste 14 diyordu).
        # ayrik atandiktan SONRA hesaplanir (operasyonel kadro = kayit - engelli - etkinlik).
        veri["norm"]["acik_sube_toplam"] = sum(
            max(0, r["norm"] - (r["kadrolu_kesim26"]
                                - ayrik.get(r["sube"], {}).get("engelli", 0)
                                - ayrik.get(r["sube"], {}).get("etkinlik", 0)))
            for r in veri["norm"]["sube"])
        veri["norm"]["engelli_kapsam_uyarisi"] = (
            "Engelli kadro yalnız BKM_GENEL firmasında vardır (FSM · İst. Yolu · Özlüce). Heykel "
            "(Bursa Kültür Merkezi, 35 kişi) ve Şura (Asiye Bingölbalı, 16 kişi) ayrı tüzel "
            "kişiliktir ve çalışan sayıları 50'nin ALTINDA olduğu için 4857/30 engelli istihdam "
            "yükümlülüğü doğmaz — o mağazalarda engelli kadro yoktur (veri eksikliği değildir).")
