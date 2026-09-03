# -*- coding: utf-8 -*-
"""DerinSIS is hacmi bloklari (POS eTip=100): hizali pencere · kanal · trend · kategori ·
aylik · okul kaymasi · Agustos yarim-ay · aylik KDV-haric ciro.

cek_hacim(cur, veri) -> (hacim, yil_adet, ciro_ay)  — sonrasinda kadro ve maliyet bloklari kullanir.
"""
import datetime as _dt
import sys

from verimlilik_ortak import (CARI, MEKAN, OFSET_BAS, OFSET_SON, OKUL_ACILIS, ONCEKI,
                              SINAV_DAHIL, SINAV_HARIC, YILLAR, _hizali_kosul)


def cek_hacim(cur, veri):
    """DerinSIS bloklari. veri sozlugunu doldurur, sonraki bloklarin ihtiyaci olani dondurur."""
    # 1) okul-hizali pencere, magaza x yil
    print("DerinSIS: okul-hizalı pencere (mağaza × yıl)...", flush=True)
    cur.execute("""
        SELECT bs.eMekan, YEAR(bs.eTarihS) AS yil,
               SUM(ABS(CAST(dt.ehAdet AS float)))                            AS adet,
               SUM(CAST(dt.ehTutar - dt.ehIndirim AS float))                 AS kdvharic,
               SUM(CAST(dt.ehTutar - dt.ehIndirim + dt.ehTutarKDV AS float)) AS kdvdahil,
               COUNT(DISTINCT CAST(bs.eTarihS AS date))                      AS gun,
               MIN(CAST(bs.eTarihS AS date))                                 AS ilk_gun,
               MAX(CAST(bs.eTarihS AS date))                                 AS son_gun
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND """ + SINAV_HARIC + """
          AND """ + _hizali_kosul() + """
        GROUP BY bs.eMekan, YEAR(bs.eTarihS)""")
    hacim, gunler, pencere_tarih = {}, {}, {}
    gun_mekan = {}          # K-08: gun sayisi MAGAZA x YIL bazinda — tek sozlukte eziliyordu
    for mekan, yil, adet, kh, kd, gun, ilk, son in cur.fetchall():
        hacim[(int(mekan), int(yil))] = (float(adet), float(kh), float(kd))
        gunler[int(yil)] = int(gun)
        gun_mekan[(int(mekan), int(yil))] = int(gun)
        # fiili ilk/son gun (magazalar arasi ayni pencerede; genis olani al)
        eski = pencere_tarih.get(int(yil))
        ilk_s, son_s = ilk.strftime("%d.%m.%Y"), son.strftime("%d.%m.%Y")
        if eski is None:
            pencere_tarih[int(yil)] = [ilk_s, son_s]
        else:
            pencere_tarih[int(yil)] = [min(eski[0], ilk_s, key=lambda d: d[6:] + d[3:5] + d[:2]),
                                       max(eski[1], son_s, key=lambda d: d[6:] + d[3:5] + d[:2])]
    if len(gunler) != 2 or len(set(gunler.values())) != 1:
        sys.exit("Pencere eşit değil (gün sayıları %s) — kıyas yapılamaz." % gunler)
    veri["meta"]["gun"] = next(iter(gunler.values()))
    # K-08: eski kontrol yalnizca SON magazanin gun sayisini kiyasliyordu. Bir magaza bir yil
    #   eksik gun satmissa (kapanis/ariza) o magazanin delta ve kisi-basi rakami sessizce sapar.
    gun_uyari = []
    for mekan in MEKAN:
        g_o, g_c = gun_mekan.get((mekan, ONCEKI)), gun_mekan.get((mekan, CARI))
        if g_o is None or g_c is None:
            sys.exit("PENCERE EKSİK: %s mağazasında %s verisi yok (gün sayıları %s)."
                     % (MEKAN[mekan], ONCEKI if g_o is None else CARI, gun_mekan))
        if g_o != g_c:
            sys.exit("PENCERE EŞİT DEĞİL (%s): %d gün %d, %d gün %d — mağaza bazında kıyas bozulur."
                     % (MEKAN[mekan], ONCEKI, g_o, CARI, g_c))
        if g_o != veri["meta"]["gun"]:
            gun_uyari.append("%s %d gün (pencere %d)" % (MEKAN[mekan], g_o, veri["meta"]["gun"]))
    if gun_uyari:
        print("  ⚠ satış günü pencereden az: %s" % " · ".join(gun_uyari), flush=True)
    veri["meta"]["gun_magaza"] = {"%s|%d" % (MEKAN[m], y): g
                                  for (m, y), g in sorted(gun_mekan.items())}
    veri["meta"]["gun_uyari"] = gun_uyari
    veri["meta"]["pencere_tarih"] = {str(k): val for k, val in sorted(pencere_tarih.items())}

    # 2) Ocak-Agustos, magaza vs Sinav
    print("DerinSIS: Ocak-Ağustos kanal kırılımı...", flush=True)
    cur.execute("""
        SELECT YEAR(bs.eTarihS) AS yil,
               CASE WHEN """ + SINAV_DAHIL + """ THEN 'sinav' ELSE 'magaza' END AS kanal,
               SUM(ABS(CAST(dt.ehAdet AS float)))                            AS adet,
               SUM(CAST(dt.ehTutar - dt.ehIndirim + dt.ehTutarKDV AS float)) AS kdvdahil
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND YEAR(bs.eTarihS) IN (?, ?)
          AND MONTH(bs.eTarihS) BETWEEN 1 AND 8
        GROUP BY YEAR(bs.eTarihS),
                 CASE WHEN """ + SINAV_DAHIL + """ THEN 'sinav' ELSE 'magaza' END""",
                ONCEKI, CARI)
    oa = {"magaza": {}, "sinav": {}}
    for yil, kanal, adet, kd in cur.fetchall():
        ek = "%d" % (int(yil) % 100)
        oa[kanal]["adet" + ek] = float(adet)
        oa[kanal]["kdvdahil" + ek] = float(kd)
    veri["ocak_agustos"] = oa

    # 3) yillik trend: Oca-Agu adet (Sinav haric)
    print("DerinSIS: 4 yıllık Ocak-Ağustos adet...", flush=True)
    cur.execute("""
        SELECT YEAR(bs.eTarihS) AS yil, SUM(ABS(CAST(dt.ehAdet AS float))) AS adet
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND """ + SINAV_HARIC + """
          AND YEAR(bs.eTarihS) BETWEEN ? AND ?
          AND MONTH(bs.eTarihS) BETWEEN 1 AND 8
        GROUP BY YEAR(bs.eTarihS)""", YILLAR[0], YILLAR[-1])
    yil_adet = {int(y): float(a) for y, a in cur.fetchall()}

    # 3b) KATEGORI x yil — hangi kategori ne kadar buyudu (bolum kadrosuyla eslestirmek icin)
    print("DerinSIS: kategori büyümesi (okul-hizalı pencere)...", flush=True)
    cur.execute("""
        SELECT COALESCE(kat.Kategori3, N'(tanımsız)') AS kategori, YEAR(bs.eTarihS) AS yil,
               SUM(ABS(CAST(dt.ehAdet AS float)))                            AS adet,
               SUM(CAST(dt.ehTutar - dt.ehIndirim + dt.ehTutarKDV AS float)) AS ciro
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND """ + SINAV_HARIC + """
          AND """ + _hizali_kosul() + """
        GROUP BY COALESCE(kat.Kategori3, N'(tanımsız)'), YEAR(bs.eTarihS)""")
    kt = {}
    for k, yil, adet, ciro in cur.fetchall():
        d = kt.setdefault(k, {"kategori": k})
        ek = int(yil) % 100
        d["adet%d" % ek] = float(adet)
        d["ciro%d" % ek] = float(ciro)
    # 3b-2) ayni kategoriler icin OCAK-AGUSTOS kumulatif (kullanici: "01.01-31.08 arasini da yapsak")
    print("DerinSIS: kategori büyümesi (Ocak-Ağustos)...", flush=True)
    cur.execute("""
        SELECT COALESCE(kat.Kategori3, N'(tanımsız)') AS kategori, YEAR(bs.eTarihS) AS yil,
               SUM(ABS(CAST(dt.ehAdet AS float)))                            AS adet,
               SUM(CAST(dt.ehTutar - dt.ehIndirim + dt.ehTutarKDV AS float)) AS ciro
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND """ + SINAV_HARIC + """
          AND YEAR(bs.eTarihS) IN (?, ?)
          AND MONTH(bs.eTarihS) BETWEEN 1 AND 8
        GROUP BY COALESCE(kat.Kategori3, N'(tanımsız)'), YEAR(bs.eTarihS)""", ONCEKI, CARI)
    for k_, yil, adet, ciro in cur.fetchall():
        d = kt.setdefault(k_, {"kategori": k_})
        ek = int(yil) % 100
        d["oa_adet%d" % ek] = float(adet)
        d["oa_ciro%d" % ek] = float(ciro)

    # iki yili birden olan ve anlamli buyuklukteki kategoriler (adet>=2000) — kuyruk gurultusu haric
    veri["kategori"] = sorted(
        [d for d in kt.values()
         if d.get("adet25", 0) >= 2000 and d.get("adet26", 0) >= 2000],
        key=lambda d: -d["adet26"])

    # 3c) AYLIK kirilim (Haz-Tem-Agu, takvim ayi) — Agustos'u okul kaymasi geri cekiyor, gorunur olsun
    print("DerinSIS: aylık kırılım (Haz/Tem/Ağu)...", flush=True)
    cur.execute("""
        SELECT YEAR(bs.eTarihS) AS yil, MONTH(bs.eTarihS) AS ay,
               SUM(ABS(CAST(dt.ehAdet AS float)))                            AS adet,
               SUM(CAST(dt.ehTutar - dt.ehIndirim + dt.ehTutarKDV AS float)) AS ciro
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND """ + SINAV_HARIC + """
          AND YEAR(bs.eTarihS) IN (?, ?)
          AND MONTH(bs.eTarihS) IN (6, 7, 8)
        GROUP BY YEAR(bs.eTarihS), MONTH(bs.eTarihS)""", ONCEKI, CARI)
    ay_ad = {6: "Haziran", 7: "Temmuz", 8: "Ağustos"}
    ay = {}
    for yil, a, adet, ciro in cur.fetchall():
        d = ay.setdefault(int(a), {"ay": int(a), "ad": ay_ad[int(a)]})
        ek = int(yil) % 100
        d["adet%d" % ek] = float(adet)
        d["ciro%d" % ek] = float(ciro)
    veri["aylik"] = [ay[k] for k in sorted(ay)]

    # 3d) OKUL KAYMASI DUZELTMESI — "kayma olmasaydi Agustos ne kapanirdi, ne kadari Eylul'e kaydi"
    # Yontem: 2026 gunleri 2025'in 6 gun ONCESINE denk gelir (acilis 08.09.2025 -> 14.09.2026).
    #   (a) HIZALI 27 GUN: 2025 01-27 Agu  <->  2026 07 Agu - 02 Eyl (veri sonu) -> gercek buyume orani g
    #   (b) 2025'in 28-31 Agu dilimi 2026'da 03-06 Eyl'e denk gelir -> HENUZ GERCEKLESMEDI
    #   (c) Kayma-arindirilmis Agustos 2026 = 2025 Agustos toplami x (1+g)
    #   (d) Eylul'e kayan = (c) - gercek Agustos 2026
    #   (e) 2025'te okul-oncesi dalga 28 Agu - 07 Eyl idi; 2026'da 03-13 Eyl'e denk gelir -> beklenen hacim
    print("DerinSIS: okul kayması düzeltmesi (Ağustos → Eylül)...", flush=True)
    # ⚠ BUGUN HARIC: eTip 100 GUNLUK OZET belgesidir, gun icinde yeniden yazilir -> son TAM gun esas.
    #   (02.09.2026'da iki olcum arasinda 6.225 adet oynadi; bugunu almak rakami oynak yapar.)
    import datetime as _dt
    son_tam = _dt.date.today() - _dt.timedelta(days=1)
    # 2026'nin son tam gunu, 2025'te 6 gun once + 1 yil once gune denk gelir (okul kaymasi)
    esli_2025 = son_tam.replace(year=son_tam.year - 1) - _dt.timedelta(days=6)
    hizali_gun = (son_tam - _dt.date(son_tam.year, 8, 7)).days + 1
    dilimler = {
        "y25_hizali":    ("20250801", esli_2025.strftime("%Y%m%d")),
        "y25_agu_kalan": ((esli_2025 + _dt.timedelta(days=1)).strftime("%Y%m%d"), "20250831"),
        "y25_eyl_1_7":   ("20250901", "20250907"),
        "y25_agu_tam":   ("20250801", "20250831"),
        "y26_agu_tam":   ("20260801", "20260831"),
        "y26_hizali":    ("20260807", son_tam.strftime("%Y%m%d")),
    }
    kayma = {}
    for ad, (bas, son) in dilimler.items():
        cur.execute("""
            SELECT SUM(ABS(CAST(dt.ehAdet AS float))),
                   SUM(CAST(dt.ehTutar - dt.ehIndirim + dt.ehTutarKDV AS float)),
                   COUNT(DISTINCT CAST(bs.eTarihS AS date))
            FROM dbo.irs bs WITH(NOLOCK)
            INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
            LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
            WHERE bs.eTip = 100
              AND bs.eMekan IN (1, 4477, 4478)
              AND """ + SINAV_HARIC + """
              AND bs.eTarihS >= ? AND bs.eTarihS <= ?""", bas, son)
        adet, ciro, gunn = cur.fetchone()
        kayma[ad] = {"adet": float(adet or 0), "ciro": float(ciro or 0), "gun": int(gunn or 0)}

    # K-07: bir dilim bos donerse (tarih penceresi hatasi / veri gecikmesi) "or 0" sessizce
    #   sifir yazar ve "Eylul'e kayan" TUM Agustos kadar cikar. Bos dilim = hesap yapilamaz.
    for ad in dilimler:
        d_ = kayma[ad]
        if d_["adet"] <= 0 or d_["ciro"] <= 0 or d_["gun"] <= 0:
            sys.exit("KAYMA DİLİMİ BOŞ: %s (%s – %s) → adet %.0f, ciro %.0f, gün %d. "
                     "Tarih penceresi veya veri eksik; kayma hesabı yapılamaz."
                     % (ad, dilimler[ad][0], dilimler[ad][1], d_["adet"], d_["ciro"], d_["gun"]))
    if kayma["y25_hizali"]["gun"] != kayma["y26_hizali"]["gun"]:
        sys.exit("KAYMA PENCERESİ EŞİT DEĞİL: %d gün %d, %d gün %d — hizalı büyüme oranı sapar."
                 % (ONCEKI, kayma["y25_hizali"]["gun"], CARI, kayma["y26_hizali"]["gun"]))

    g_adet = kayma["y26_hizali"]["adet"] / kayma["y25_hizali"]["adet"] - 1
    g_ciro = kayma["y26_hizali"]["ciro"] / kayma["y25_hizali"]["ciro"] - 1
    kayma["hizali_buyume"] = {"adet": g_adet, "ciro": g_ciro,
                              "gun": kayma["y26_hizali"]["gun"],
                              "pencere_2025": "01.08 – %s.2025" % esli_2025.strftime("%d.%m"),
                              "pencere_2026": "07.08 – %s.2026" % son_tam.strftime("%d.%m"),
                              "son_tam_gun": son_tam.strftime("%d.%m.%Y")}
    # K-07: hizali buyume orani makul bantta olmali. Bant disi = pencere/filtre hatasi
    #   (or. bir yil Sinav dahil kalmis) — hatali oran tum kayma tahminini carpitir.
    for ad_, g_ in (("adet", g_adet), ("ciro", g_ciro)):
        if not (-0.5 <= g_ <= 2.0):
            sys.exit("HİZALI BÜYÜME BANT DIŞI (%s): %%%.1f. Pencere/filtre hatası olasılığı — "
                     "kayma tahmini üretilmedi." % (ad_, g_ * 100))
    kayma["agustos_kaymasiz_tahmin"] = {
        "adet": kayma["y25_agu_tam"]["adet"] * (1 + g_adet),
        "ciro": kayma["y25_agu_tam"]["ciro"] * (1 + g_ciro)}
    kayma["eylule_kayan"] = {
        "adet": kayma["agustos_kaymasiz_tahmin"]["adet"] - kayma["y26_agu_tam"]["adet"],
        "ciro": kayma["agustos_kaymasiz_tahmin"]["ciro"] - kayma["y26_agu_tam"]["ciro"]}
    for ad_ in ("adet", "ciro"):
        if kayma["eylule_kayan"][ad_] <= 0:
            print("  ⚠ kayma-arındırılmış Ağustos gerçekleşenin ALTINDA (%s) — kayma anlatısı "
                  "bu ölçüde desteklenmiyor." % ad_, flush=True)
    # 2025 okul-oncesi dalga (28 Agu - 07 Eyl) -> 2026'da 03-13 Eyl beklentisi
    dalga25_adet = kayma["y25_agu_kalan"]["adet"] + kayma["y25_eyl_1_7"]["adet"]
    dalga25_ciro = kayma["y25_agu_kalan"]["ciro"] + kayma["y25_eyl_1_7"]["ciro"]
    kayma["eylul_dalga_beklentisi"] = {
        "pencere_2025": "%s - 07.09.2025" % (esli_2025 + _dt.timedelta(days=1)).strftime("%d.%m"),
        "pencere_2026": "%s - 13.09.2026" % (son_tam + _dt.timedelta(days=1)).strftime("%d.%m"),
        "adet_2025": dalga25_adet, "ciro_2025": dalga25_ciro,
        "adet_2026_tahmin": dalga25_adet * (1 + g_adet),
        "ciro_2026_tahmin": dalga25_ciro * (1 + g_ciro)}
    kayma["yontem"] = ("2026 günleri 2025'in 6 gün öncesine denk gelir (açılış 08.09.2025 → 14.09.2026). "
                       "Hizalı 27 günde ölçülen büyüme (adet %%%.1f · ciro %%%.1f) 2025 Ağustos toplamına "
                       "uygulanarak kayma-arındırılmış Ağustos bulunur. VARSAYIM: talep kaybı yok, yalnız "
                       "zamanlama kaydı. Bugünün verisi HARİÇ (eTip 100 gün içinde yeniden yazılır); "
                       "son tam gün %s." % (g_adet * 100, g_ciro * 100, son_tam.strftime("%d.%m.%Y")))
    veri["kayma"] = kayma


    # 3g) AYLIK CIRO (KDV HARIC) — personel maliyeti/ciro orani icin (K-21).
    #   ⚠ Maliyet KDV'siz bir gider; ciro da KDV-HARIC net alinir (KDV-dahil oran yaniltir).
    #   Sinav DAHIL: o satisi da ayni magaza personeli yapiyor — oranin dogru paydasi.
    print("DerinSIS: aylık ciro (KDV hariç, maliyet oranı için)...", flush=True)
    cur.execute("""
        SELECT YEAR(bs.eTarihS) AS yil, MONTH(bs.eTarihS) AS ay,
               SUM(CAST(dt.ehTutar - dt.ehIndirim AS float))                 AS net_kdvharic,
               SUM(ABS(CAST(dt.ehAdet AS float)))                            AS adet
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND YEAR(bs.eTarihS) IN (?, ?)
          AND MONTH(bs.eTarihS) BETWEEN 1 AND 12
        GROUP BY YEAR(bs.eTarihS), MONTH(bs.eTarihS)""", ONCEKI, CARI)
    ciro_ay = {}
    for yil, ay_, net, adet in cur.fetchall():
        ciro_ay[(int(yil), int(ay_))] = (float(net or 0), float(adet or 0))

    # 3f) AGUSTOS YARIM-AY is hacmi — sezonluk alimin 1-14 Agustos'a kaymasinin gerekcesi
    print("DerinSIS: Ağustos yarım-ay iş hacmi...", flush=True)
    cur.execute("""
        SELECT YEAR(bs.eTarihS) AS yil,
               CASE WHEN DAY(bs.eTarihS) <= 14 THEN 1 ELSE 2 END AS yarim,
               SUM(ABS(CAST(dt.ehAdet AS float)))                            AS adet,
               SUM(CAST(dt.ehTutar - dt.ehIndirim + dt.ehTutarKDV AS float)) AS ciro
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND """ + SINAV_HARIC + """
          AND MONTH(bs.eTarihS) = 8
          AND YEAR(bs.eTarihS) IN (?, ?)
        GROUP BY YEAR(bs.eTarihS), CASE WHEN DAY(bs.eTarihS) <= 14 THEN 1 ELSE 2 END""",
                ONCEKI, CARI)
    yarim = {"1": {}, "2": {}}
    for yil, y_, adet, ciro in cur.fetchall():
        yarim[str(int(y_))]["adet%d" % (int(yil) % 100)] = float(adet)
        yarim[str(int(y_))]["ciro%d" % (int(yil) % 100)] = float(ciro)
    veri["agustos_yarim"] = yarim


    # 3h) GUNLUK CIRO — sezonun kalani icin okul-hizali TAHMIN modelinin girdisi.
    #   2025'in gunluk satisi 2026 takvimine ofsetlenerek tasinir (verimlilik_cek_tahmin).
    print("DerinSIS: günlük ciro (tahmin modeli girdisi)...", flush=True)
    cur.execute("""
        SELECT CAST(bs.eTarihS AS date) AS gun,
               SUM(CAST(dt.ehTutar - dt.ehIndirim AS float)) AS net_kdvharic
        FROM dbo.irs bs WITH(NOLOCK)
        INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
        WHERE bs.eTip = 100
          AND bs.eMekan IN (1, 4477, 4478)
          AND bs.eTarihS >= ? AND bs.eTarihS < ?
        GROUP BY CAST(bs.eTarihS AS date)""",
                "%d0601" % ONCEKI, "%d1201" % CARI)
    gunluk = {}
    for gun, net in cur.fetchall():
        gunluk[(gun.year, gun.isoformat())] = float(net or 0)

    return hacim, yil_adet, ciro_ay, gunluk
