# -*- coding: utf-8 -*-
"""Zirve kadro bloklari: 5 magaza kapsam · sube tablosu · 3 POS hacim+kadro · yillik trend ·
bolum · magaza x bolum · arka ofis · personel listesi (KVKK) · sezonluk alim · tutunma · mutabakat.
"""
import sys

from verimlilik_ortak import (ASOF, CARI, MEKAN, OKUL_ACILIS, ONCEKI, SUBE, YILLAR, maskele)


def cek_kadro(zc, veri, hacim, yil_adet, kisi=False):
    """Kadro/bolum/sezonluk bloklari. `kisi=True` ise kisi-duzeyi liste de cekilir (KVKK)."""
    # 5 magaza kadrolu taban/kesim + sezonluk (POS'ta olmayan Heykel/Sura dahil)
    def kadro_5(tarih, sezonluk=None):
        kosul = "v.Lokasyon LIKE 'MA%'"
        if sezonluk is True:
            kosul += " AND v.Kadro = 'SEZONLUK'"
        elif sezonluk is False:
            kosul += " AND COALESCE(v.Kadro, '') <> 'SEZONLUK'"
        zc.execute("SELECT COUNT(*) FROM dbo.vw_PersonelDepartman v WHERE " + kosul
                   + " AND " + ASOF, tarih, tarih)
        return int(zc.fetchone()[0])

    veri["kadro_5magaza"] = {
        "kadrolu_taban%d" % (ONCEKI % 100): kadro_5("%d0630" % ONCEKI, False),
        "kadrolu_taban%d" % (CARI % 100): kadro_5("%d0630" % CARI, False),
        "kadrolu_kesim%d" % (ONCEKI % 100): kadro_5("%d0831" % ONCEKI, False),
        "kadrolu_kesim%d" % (CARI % 100): kadro_5("%d0831" % CARI, False),
        "sezonluk_kesim%d" % (ONCEKI % 100): kadro_5("%d0831" % ONCEKI, True),
        "sezonluk_kesim%d" % (CARI % 100): kadro_5("%d0831" % CARI, True),
        "toplam_kesim%d" % (ONCEKI % 100): kadro_5("%d0831" % ONCEKI),
        "toplam_kesim%d" % (CARI % 100): kadro_5("%d0831" % CARI),
    }

    # 5 magaza kadro tablosu (taban kadrolu · kesim sezonluk/kadrolu/toplam) — TEK TABLO, join yok
    print("Zirve: 5 mağaza kadro tablosu...", flush=True)
    veri["magaza_kadro"] = []
    for sube in ("İST. YOLU", "ÖZLÜCE", "FSM", "HEYKEL", "ŞURA"):
        satir = {"sube": sube}
        for yil in (ONCEKI, CARI):
            ek = yil % 100
            zc.execute("""
                SELECT SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                                 AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS kadrolu_taban,
                       SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                                 AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS kadrolu_kesim,
                       SUM(CASE WHEN v.Kadro = 'SEZONLUK' AND v.Igt <= ?
                                 AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS sezonluk_kesim
                FROM dbo.vw_PersonelDepartman v
                WHERE v.AltLokasyon = ? AND v.Lokasyon LIKE 'MA%'""",
                       "%d0630" % yil, "%d0630" % yil,
                       "%d0831" % yil, "%d0831" % yil,
                       "%d0831" % yil, "%d0831" % yil, sube)
            kt, kk, sk = (int(x or 0) for x in zc.fetchone())
            satir["kadrolu_taban%d" % ek] = kt
            satir["kadrolu_kesim%d" % ek] = kk
            satir["sezonluk_kesim%d" % ek] = sk
        veri["magaza_kadro"].append(satir)

    # 3 POS magazasi: is hacmi + kadro. K-11: kadro AYRI bir sayim sorgusundan geliyordu
    #   (kadro_sube) — iki kaynak sessizce ayrisabilir ve "143 -> 160" tabani kayardi. Artik
    #   kadro TEK KAYNAK: yukaridaki magaza_kadro tablosu (kadrolu + sezonluk).
    _mk = {m["sube"]: m for m in veri["magaza_kadro"]}
    for mekan, ad in MEKAN.items():
        sat = {"ad": ad, "mekan": mekan}
        mkr = _mk[SUBE[mekan]]
        for yil in (ONCEKI, CARI):
            ek = yil % 100
            h = hacim[(mekan, yil)]
            sat["kadro%d" % ek] = mkr["kadrolu_kesim%d" % ek] + mkr["sezonluk_kesim%d" % ek]
            sat["adet%d" % ek], sat["kdvharic%d" % ek], sat["kdvdahil%d" % ek] = h[0], h[1], h[2]
        veri["magaza"].append(sat)

    # yillik trend kadrolu (3 POS magazasi)
    for yil in YILLAR:
        zc.execute("""SELECT COUNT(*) FROM dbo.vw_PersonelDepartman v
                      WHERE v.AltLokasyon IN (?, ?, ?) AND v.Lokasyon LIKE 'MA%'
                        AND COALESCE(v.Kadro, '') <> 'SEZONLUK'
                        AND """ + ASOF,
                   SUBE[4478], SUBE[4477], SUBE[1], "%d0831" % yil, "%d0831" % yil)
        veri["yillar"].append({"yil": yil, "kadrolu": int(zc.fetchone()[0]),
                               "adet": yil_adet.get(yil, 0.0)})
    # 6) BOLUM (departman) kirilimi — kadro nereye gitti: yonetim / kasa / mal kabul / satis reyonlari
    print("Zirve: bölüm (departman) kırılımı...", flush=True)
    zc.execute("""
        SELECT COALESCE(v.Departman, N'(tanımsız)') AS departman,
               SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS kadrolu25,
               SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS kadrolu26,
               SUM(CASE WHEN v.Kadro = 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS sezonluk25,
               SUM(CASE WHEN v.Kadro = 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS sezonluk26
        FROM dbo.vw_PersonelDepartman v
        WHERE v.Lokasyon LIKE 'MA%'
        GROUP BY COALESCE(v.Departman, N'(tanımsız)')
        HAVING SUM(CASE WHEN v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END)
             + SUM(CASE WHEN v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) > 0
        ORDER BY 3 DESC""",
               "%d0831" % ONCEKI, "%d0831" % ONCEKI, "%d0831" % CARI, "%d0831" % CARI,
               "%d0831" % ONCEKI, "%d0831" % ONCEKI, "%d0831" % CARI, "%d0831" % CARI,
               "%d0831" % ONCEKI, "%d0831" % ONCEKI, "%d0831" % CARI, "%d0831" % CARI)
    veri["bolum"] = [{"bolum": b, "kadrolu25": int(k25), "kadrolu26": int(k26),
                      "sezonluk25": int(s25), "sezonluk26": int(s26)}
                     for b, k25, k26, s25, s26 in zc.fetchall()]

    # 7) MAGAZA x BOLUM capraz kirilim — hangi magazada hangi reyon buyudu
    print("Zirve: mağaza × bölüm çapraz kırılımı...", flush=True)
    zc.execute("""
        SELECT v.AltLokasyon AS sube, COALESCE(v.Departman, N'(tanımsız)') AS bolum,
               SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS kadrolu25,
               SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS kadrolu26,
               SUM(CASE WHEN v.Kadro = 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS sezonluk26
        FROM dbo.vw_PersonelDepartman v
        WHERE v.Lokasyon LIKE 'MA%'
        GROUP BY v.AltLokasyon, COALESCE(v.Departman, N'(tanımsız)')
        HAVING SUM(CASE WHEN v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END)
             + SUM(CASE WHEN v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) > 0""",
               "%d0831" % ONCEKI, "%d0831" % ONCEKI, "%d0831" % CARI, "%d0831" % CARI,
               "%d0831" % CARI, "%d0831" % CARI,
               "%d0831" % ONCEKI, "%d0831" % ONCEKI, "%d0831" % CARI, "%d0831" % CARI)
    veri["magaza_bolum"] = [{"sube": s_, "bolum": b_, "kadrolu25": int(k25), "kadrolu26": int(k26),
                             "sezonluk26": int(s26)}
                            for s_, b_, k25, k26, s26 in zc.fetchall()]

    # 8) ARKA OFIS HARIC kadro — Muhasebe/On Muhasebe/Bilgi Islem mağaza kadrosunda KAYITLI ama
    #    is magaza isi degil (2026'da merkeze kaydilar). Seffaflik icin ikinci kapsam olarak tutulur.
    print("Zirve: arka ofis hariç kadro (ikinci kapsam)...", flush=True)
    ARKA_OFIS = ("MUHASEBE", "ÖN MUHASEBE", "BİLGİ İŞLEM")
    zc.execute("""
        SELECT SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS taban25,
               SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS taban26,
               SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS kesim25,
               SUM(CASE WHEN COALESCE(v.Kadro,'') <> 'SEZONLUK' AND v.Igt <= ?
                         AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END) AS kesim26
        FROM dbo.vw_PersonelDepartman v
        WHERE v.Lokasyon LIKE 'MA%'
          AND COALESCE(v.Departman, '') NOT IN (?, ?, ?)""",
               "%d0630" % ONCEKI, "%d0630" % ONCEKI, "%d0630" % CARI, "%d0630" % CARI,
               "%d0831" % ONCEKI, "%d0831" % ONCEKI, "%d0831" % CARI, "%d0831" % CARI,
               *ARKA_OFIS)
    t25, t26, s25v, s26v = (int(x or 0) for x in zc.fetchone())
    veri["arka_ofis_haric"] = {"bolumler": list(ARKA_OFIS),
                               "kadrolu_taban25": t25, "kadrolu_taban26": t26,
                               "kadrolu_kesim25": s25v, "kadrolu_kesim26": s26v}

    # 9) PERSONEL LISTESI (kisi-duzeyi) — YALNIZ --kisi bayragiyla. KVKK: ucret/TCKN/IBAN ALINMAZ.
    #    Cikti dosyasi gitignore'da (briefings/**/*KISILI*.xlsx) — commit'lenmez.
    if kisi:
        print("Zirve: personel listesi (kişi düzeyi)...", flush=True)
        zc.execute("""
            SELECT v.AdSoyad, v.AltLokasyon, COALESCE(v.Departman, N'(tanımsız)') AS Departman,
                   COALESCE(v.Unvan, N'') AS Unvan, COALESCE(v.Kadro, N'(tanımsız)') AS Kadro,
                   v.Igt, v.Ict,
                   CASE WHEN v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END AS aktif25,
                   CASE WHEN v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?) THEN 1 ELSE 0 END AS aktif26,
                   DATEDIFF(DAY, v.Igt, COALESCE(v.Ict, ?)) AS kidem_gun
            FROM dbo.vw_PersonelDepartman v
            WHERE v.Lokasyon LIKE 'MA%'
              AND (   (v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?))
                   OR (v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?)))
            ORDER BY v.AltLokasyon, COALESCE(v.Departman, N''), v.Igt""",
                   "%d0831" % ONCEKI, "%d0831" % ONCEKI, "%d0831" % CARI, "%d0831" % CARI,
                   "%d0831" % CARI,
                   "%d0831" % ONCEKI, "%d0831" % ONCEKI, "%d0831" % CARI, "%d0831" % CARI)
        veri["personel"] = [
            {"ad": maskele(ad), "sube": sube, "bolum": bol, "unvan": unv, "kadro": kad,
             "giris": igt.strftime("%d.%m.%Y") if igt else "",
             "cikis": ict.strftime("%d.%m.%Y") if ict else "",
             "aktif25": int(a25), "aktif26": int(a26), "kidem_gun": int(kg or 0)}
            for ad, sube, bol, unv, kad, igt, ict, a25, a26, kg in zc.fetchall()]
        print("  %d kişi" % len(veri["personel"]), flush=True)


    # 3e) SEZONLUK ALIM ZAMANLAMASI — "erken aldiniz" itirazinin testi
    # Kohortlar okul acilisina gore AYNI ofsette kesilir (T-12): 2025 -> 27.08, 2026 -> 02.09.
    # Iki olcu birlikte verilir:
    #   (a) TAKVIM olcusu  = ortalama alim gunu (yilin kacinci gunu) -> takvim olarak erken mi?
    #   (b) ACILIS olcusu  = acilistan kac gun once -> ⚠ acilis 6 gun kaydigi icin bu olcu
    #       2026'yi mekanik olarak 6 gun "erken" gosterir; tek basina kullanilamaz.
    print("Zirve: sezonluk alım zamanlaması...", flush=True)
    alim = {}
    for yil, kesim_ofset in ((ONCEKI, 12), (CARI, 12)):
        acilis = OKUL_ACILIS[yil]
        zc.execute("""
            SELECT COUNT(*),
                   AVG(CAST(DATEPART(DAYOFYEAR, v.Igt) AS float)),
                   AVG(CAST(DATEDIFF(DAY, v.Igt, ?) AS float)),
                   SUM(CASE WHEN MONTH(v.Igt) <= 7 THEN 1 ELSE 0 END),
                   SUM(CASE WHEN MONTH(v.Igt) = 8 AND DAY(v.Igt) <= 14 THEN 1 ELSE 0 END),
                   SUM(CASE WHEN DATEDIFF(DAY, v.Igt, ?) > 45 THEN 1 ELSE 0 END)
            FROM dbo.vw_PersonelDepartman v
            WHERE v.Lokasyon LIKE 'MA%' AND v.Kadro = 'SEZONLUK'
              AND v.Igt >= ? AND v.Igt <= DATEADD(DAY, -?, ?)""",
                   acilis, acilis, "%d0601" % yil, kesim_ofset, acilis)
        n, ort_gun, ort_once, temmuz, agu1_14, cok_erken = zc.fetchone()
        alim[str(yil)] = {"kohort": int(n or 0),
                          "ort_yil_gunu": float(ort_gun or 0),
                          "ort_acilistan_once_gun": float(ort_once or 0),
                          "temmuz_ve_oncesi": int(temmuz or 0),
                          "agustos_1_14": int(agu1_14 or 0),
                          "gun45_oncesi": int(cok_erken or 0)}
    veri["sezonluk_alim"] = alim

    # 3e-2) 31.08'de CALISAN sezonlugun alim donemi dagilimi ("62 kisi ne zaman alinmis")
    #  ⚠ Kohort (donem icinde alinan) ile AKTIF (o gun calisan) AYRI kumeler: kohort 73, aktif 62.
    #     Fark: 31.08'den once ayrilanlar + 01-02 Eylul alimlari.
    for yil in (CARI, ONCEKI):
        zc.execute("""
            SELECT x.donem, COUNT(*)
            FROM (
                SELECT CASE WHEN YEAR(v.Igt) < ? THEN '0_onceki_yildan'
                            WHEN MONTH(v.Igt) <= 6 THEN '1_haziran_ve_oncesi'
                            WHEN MONTH(v.Igt) = 7 THEN '2_temmuz'
                            WHEN MONTH(v.Igt) = 8 AND DAY(v.Igt) <= 14 THEN '3_agustos_1_14'
                            ELSE '4_agustos_15_31' END AS donem
                FROM dbo.vw_PersonelDepartman v
                WHERE v.Lokasyon LIKE 'MA%' AND v.Kadro = 'SEZONLUK'
                  AND v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?)
            ) x
            GROUP BY x.donem""", yil, "%d0831" % yil, "%d0831" % yil)
        veri["sezonluk_alim"][str(yil)]["aktif_donem"] = {d: int(k) for d, k in zc.fetchall()}





def cek_tutunma(zc, veri):
    """Kohort tutunma (14/30 gun) — sunumdaki «kalma orani» KPI'sinin kaynagi."""
    # 11) KOHORT TUTUNMA — "yeni alinanin ilk 14/30 gunde kalma orani" (sunum KPI'si)
    #   ⚠ Bu rakamlar ONCE sunuma HARDCODE yazilmisti (python-reviewer bulgusu 02.09.2026).
    #   Artik canli olculur; tutarlilik denetcisi sunumda yazani JSON ile karsilastirir.
    print("Zirve: kohort tutunma (14/30 gün)...", flush=True)
    tutunma = {}
    for yil in (ONCEKI, CARI):
        bas = "%d0701" % yil
        son = "%d0831" % yil
        for segment, kosul in (("KADROLU", "COALESCE(v.Kadro,'') <> 'SEZONLUK'"),
                               ("SEZONLUK", "v.Kadro = 'SEZONLUK'")):
            zc.execute("""
                SELECT COUNT(*) AS alinan,
                       SUM(CASE WHEN v.Ict IS NOT NULL AND v.Ict < ? THEN 1 ELSE 0 END) AS ayrilan,
                       SUM(CASE WHEN v.Igt <= DATEADD(DAY, -14, ?) THEN 1 ELSE 0 END) AS risk14,
                       SUM(CASE WHEN v.Igt <= DATEADD(DAY, -14, ?)
                                 AND (v.Ict IS NULL OR DATEDIFF(DAY, v.Igt, v.Ict) >= 14)
                                THEN 1 ELSE 0 END) AS kalan14,
                       SUM(CASE WHEN v.Igt <= DATEADD(DAY, -30, ?) THEN 1 ELSE 0 END) AS risk30,
                       SUM(CASE WHEN v.Igt <= DATEADD(DAY, -30, ?)
                                 AND (v.Ict IS NULL OR DATEDIFF(DAY, v.Igt, v.Ict) >= 30)
                                THEN 1 ELSE 0 END) AS kalan30
                FROM dbo.vw_PersonelDepartman v
                WHERE v.Lokasyon LIKE 'MA%' AND """ + kosul + """
                  AND v.Igt >= ? AND v.Igt <= ?""",
                       son, son, son, son, son, bas, son)
            alinan, ayrilan, r14, k14, r30, k30 = (int(x or 0) for x in zc.fetchone())
            tutunma.setdefault(segment, {})[str(yil)] = {
                "alinan": alinan, "ayrilan": ayrilan,
                "risk14": r14, "kalan14": k14,
                "oran14": (k14 / r14) if r14 else None,
                "risk30": r30, "kalan30": k30,
                "oran30": (k30 / r30) if r30 else None}
    veri["tutunma"] = tutunma


def mutabakat(veri):
    """Kapsam sayimi ile sube/bolum toplamlari BIREBIR tutmali; tutmuyorsa sessiz yanlis rakam."""
    # MUTABAKAT: sube-bazli toplam ile kapsam-bazli sayim BIREBIR tutmali.
    # Tutmuyorsa bir kisi iki kapsamda birden ya da hic sayilmiyor -> sessiz yanlis rakam.
    k5 = veri["kadro_5magaza"]
    for alan, yil in (("kadrolu_taban", ONCEKI), ("kadrolu_taban", CARI),
                      ("kadrolu_kesim", ONCEKI), ("kadrolu_kesim", CARI),
                      ("sezonluk_kesim", ONCEKI), ("sezonluk_kesim", CARI)):
        anahtar = "%s%d" % (alan, yil % 100)
        sube_toplam = sum(m[anahtar] for m in veri["magaza_kadro"])
        if sube_toplam != k5[anahtar]:
            sys.exit("MUTABAKAT HATASI %s: şube toplamı %d, kapsam sayımı %d — "
                     "bir kişi yanlış kapsamda (ör. Lokasyon='GENEL MÜDÜRLÜK' ama AltLokasyon şube)."
                     % (anahtar, sube_toplam, k5[anahtar]))
    for alan in ("kadrolu_kesim", "sezonluk_kesim"):
        for yil in (ONCEKI, CARI):
            ek = yil % 100
            bolum_toplam = sum(b["%s%d" % (alan.split("_")[0], ek)] for b in veri["bolum"])
            if bolum_toplam != k5["%s%d" % (alan, ek)]:
                sys.exit("MUTABAKAT HATASI bölüm/%s%d: bölüm toplamı %d, kapsam sayımı %d."
                         % (alan, ek, bolum_toplam, k5["%s%d" % (alan, ek)]))
    print("Mutabakat OK: şube ve bölüm toplamları kapsam sayımıyla birebir.", flush=True)
