# -*- coding: utf-8 -*-
"""Kisi basi is hacmi (verimlilik) -> Excel. "Ayni kadro daha cok is yapti" dosyasi.

VERIYI KENDI CEKER (elle rakam YOK):
  hacim -> DerinSIS irs/irsAyr eTip=100, Sinav haric  (cekirdek: sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql blok 11)
  kadro -> Zirve BKM_GENEL.dbo.vw_PersonelDepartman, as-of Igt<=T AND (Ict IS NULL OR Ict>=T)
Pencere OKUL ACILISINA HIZALI: gun ofseti -69..-14 (her iki yil 56 gun). Takvim-tarihli kiyas yaniltir.
Oranlarin hepsi Excel FORMULU olarak yazilir (patron ham rakamdan dogrulayabilsin).

Sayfalar: Sunum (patrona) · Ozet · Magaza · Kadro · Bolum · Kategori · Aylik · Yillar · Oca-Agu · Norm · Yontem [+ Personel: --kisi]
Kullanim:
  python scripts/verimlilik_excel.py --cek <veri.json> <cikti.xlsx>   # DB'den ceker, ikisini de yazar
  python scripts/verimlilik_excel.py <veri.json> <cikti.xlsx>         # mevcut json'dan sadece Excel
  python scripts/verimlilik_excel.py --cek --kisi <veri.json> <KISILI.xlsx>   # + personel listesi (KVKK: gitignore'da)
"""
import json
import os
import re
import sys
from pathlib import Path

from openpyxl import Workbook
from openpyxl.chart import BarChart, LineChart, Reference
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

ADET = "#,##0"
ADET1 = "#,##0.0"
TL = "#,##0"
YUZDE = "+0.0%;-0.0%"
KAT = "0.0\"x\""

BASLIK = PatternFill("solid", fgColor="E30622")
BASLIK_YAZI = Font(bold=True, color="FFFFFF", size=10)
GRI = PatternFill("solid", fgColor="F2F2F2")
VURGU = PatternFill("solid", fgColor="FFF3CD")
YESIL_YAZI = Font(bold=True, color="1F7A4D")
INCE = Side(style="thin", color="D9D9D9")
KENAR = Border(left=INCE, right=INCE, top=INCE, bottom=INCE)
NOT_YAZI = Font(italic=True, size=9, color="666666")
BOLUM_YAZI = Font(bold=True, size=10)


# ================================================================= VERI CEKME
OKUL_ACILIS = {2025: "20250908", 2026: "20260914"}   # MEB calisma takvimi (dogrulanmis)
OFSET_BAS, OFSET_SON = -69, -14                      # acilistan geriye 9. -> 2. hafta = 56 gun
MEKAN = {4478: "İst. Yolu", 4477: "Özlüce", 1: "FSM"}
SUBE = {4478: "İST. YOLU", 4477: "ÖZLÜCE", 1: "FSM"}   # Zirve AltLokasyon karsiligi
SINAV = "(N'Sınav Okulları', N'Sınav Kıyafet')"
# ⚠ sema/metrics.yaml → sinav_okullari_SATIS: ayiklama IKI KOLLU olmali —
#   Kategori3 IN (...) VEYA KatAna LIKE N'Sınav Okul%'. Yalniz Kategori3 ile 2026'da
#   160 adet / 67 bin TL kaciyordu (toplamin %0,02'si; tez degismiyor ama kural bu).
SINAV_HARIC = ("(COALESCE(kat.Kategori3, N'x') NOT IN " + SINAV +
               " AND COALESCE(kat.KatAna, N'x') NOT LIKE N'Sınav Okul%')")
SINAV_DAHIL = ("(COALESCE(kat.Kategori3, N'x') IN " + SINAV +
               " OR COALESCE(kat.KatAna, N'x') LIKE N'Sınav Okul%')")
YILLAR = [2023, 2024, 2025, 2026]
ONCEKI, CARI = 2025, 2026


def maskele(ad):
    """Ad Soyad -> her parcanin ilk 3 harfi. KVKK: dogrudan kimlik yerine tanima-yeterli kisaltma."""
    if not ad:
        return ""
    return " ".join((p[:3] + ".") if len(p) > 3 else p for p in str(ad).split())


def _env():
    yol = Path(__file__).resolve().parent.parent / ".env"
    env = {}
    with open(yol, encoding="utf-8") as f:
        for ln in f:
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
            if m and not ln.lstrip().startswith("#"):
                env[m.group(1)] = m.group(2).strip().strip('"')
    return env


def _cn(env, sunucu):
    """sunucu: 'erp' (DerinSIS) veya 'zirve' (İK)."""
    import pyodbc

    if sunucu == "erp":
        host, port, db = env["MSSQL_HOST"], env.get("MSSQL_PORT", "1433"), "DerinSISBkm"
        kullanici, sifre = env["MSSQL_USER"], env["MSSQL_PASSWORD"]
        if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
            sys.exit("Geçersiz MSSQL_HOST/PORT (.env)")
        adres = "%s,%s" % (host, port)
    else:
        host, db = env.get("ZIRVE_HOST", ""), env.get("ZIRVE_DATABASE", "BKM_GENEL")
        kullanici, sifre = env.get("ZIRVE_USER", ""), env.get("ZIRVE_PASSWORD", "")
        if not sifre:
            sys.exit("ZIRVE_PASSWORD .env'de yok — kadro verisi çekilemez (plan-38).")
        if not re.fullmatch(r"[A-Za-z0-9._\\\-]+", host):
            sys.exit("Geçersiz ZIRVE_HOST (.env)")
        adres = host
    # Bağlantı kurulumu SINIRLI retry ile (error-handling.md: transient → bounded retry + log).
    # 02.09.2026: aynı sunucuya MCP ulaşırken pyodbc'nin yeni TCP bağlantısı iki kez zaman aşımına
    # düştü (login timeout). Tek denemede script çöküyordu; 3 deneme + artan bekleme ile geçiyor.
    import time
    conn_str = ("Driver={ODBC Driver 18 for SQL Server};Server=%s;Database=%s;UID=%s;PWD=%s;"
                "TrustServerCertificate=yes;Timeout=30" % (adres, db, kullanici, sifre))
    son_hata = None
    for deneme in (1, 2, 3):
        try:
            cn = pyodbc.connect(conn_str, timeout=30)
            if deneme > 1:
                print("  bağlantı %d. denemede kuruldu (%s)" % (deneme, sunucu), flush=True)
            cn.timeout = 600
            return cn
        except pyodbc.Error as e:
            son_hata = e
            gecici = any(k in str(e) for k in ("08001", "HYT00", "timeout", "zaman aşımı"))
            if not gecici or deneme == 3:
                break
            bekle = 3 * deneme
            print("  ⚠ %s bağlantısı kurulamadı (deneme %d/3) — %d sn sonra tekrar"
                  % (sunucu, deneme, bekle), flush=True)
            time.sleep(bekle)
    sys.exit("%s bağlantısı kurulamadı (3 deneme): %s" % (sunucu, son_hata))


def _hizali_kosul(alias="bs.eTarihS"):
    """Iki yilin okul-hizali penceresi (OR'lu), kesim = veri sonu."""
    parcalar = []
    for yil, acilis in OKUL_ACILIS.items():
        parcalar.append(
            "(YEAR(%s) = %d AND DATEDIFF(DAY, '%s', %s) BETWEEN %d AND %d)"
            % (alias, yil, acilis, alias, OFSET_BAS, OFSET_SON))
    return "(" + " OR ".join(parcalar) + ")"


def cek(env, kisi=False):
    """Tum rakamlari canli ceker. Elle girilen sayi YOK."""
    veri = {"meta": {}, "magaza": [], "yillar": [], "notlar": NOTLAR}
    erp = _cn(env, "erp")
    cur = erp.cursor()

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
    for mekan, yil, adet, kh, kd, gun, ilk, son in cur.fetchall():
        hacim[(int(mekan), int(yil))] = (float(adet), float(kh), float(kd))
        gunler[int(yil)] = int(gun)
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

    g_adet = kayma["y26_hizali"]["adet"] / kayma["y25_hizali"]["adet"] - 1
    g_ciro = kayma["y26_hizali"]["ciro"] / kayma["y25_hizali"]["ciro"] - 1
    kayma["hizali_buyume"] = {"adet": g_adet, "ciro": g_ciro,
                              "gun": kayma["y26_hizali"]["gun"],
                              "pencere_2025": "01.08 – %s.2025" % esli_2025.strftime("%d.%m"),
                              "pencere_2026": "07.08 – %s.2026" % son_tam.strftime("%d.%m"),
                              "son_tam_gun": son_tam.strftime("%d.%m.%Y")}
    kayma["agustos_kaymasiz_tahmin"] = {
        "adet": kayma["y25_agu_tam"]["adet"] * (1 + g_adet),
        "ciro": kayma["y25_agu_tam"]["ciro"] * (1 + g_ciro)}
    kayma["eylule_kayan"] = {
        "adet": kayma["agustos_kaymasiz_tahmin"]["adet"] - kayma["y26_agu_tam"]["adet"],
        "ciro": kayma["agustos_kaymasiz_tahmin"]["ciro"] - kayma["y26_agu_tam"]["ciro"]}
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

    erp.close()



    # 4) kadro — Zirve
    print("Zirve: kadro as-of sayımları...", flush=True)
    zrv = _cn(env, "zirve")
    zc = zrv.cursor()
    asof = "v.Igt <= '%s' AND (v.Ict IS NULL OR v.Ict >= '%s')"

    def kadro_sube(tarih, sube):
        zc.execute("SELECT COUNT(*) FROM dbo.vw_PersonelDepartman v "
                   "WHERE v.AltLokasyon = ? AND v.Lokasyon LIKE 'MA%' AND "
                   + (asof % (tarih, tarih)), sube)
        return int(zc.fetchone()[0])

    for mekan, ad in MEKAN.items():
        h_o = hacim[(mekan, ONCEKI)]
        h_c = hacim[(mekan, CARI)]
        veri["magaza"].append({
            "ad": ad, "mekan": mekan,
            "kadro%d" % (ONCEKI % 100): kadro_sube("%d0831" % ONCEKI, SUBE[mekan]),
            "kadro%d" % (CARI % 100): kadro_sube("%d0831" % CARI, SUBE[mekan]),
            "adet%d" % (ONCEKI % 100): h_o[0], "adet%d" % (CARI % 100): h_c[0],
            "kdvharic%d" % (ONCEKI % 100): h_o[1], "kdvharic%d" % (CARI % 100): h_c[1],
            "kdvdahil%d" % (ONCEKI % 100): h_o[2], "kdvdahil%d" % (CARI % 100): h_c[2],
        })

    # 5 magaza kadrolu taban/kesim + sezonluk (POS'ta olmayan Heykel/Sura dahil)
    def kadro_5(tarih, sezonluk=None):
        kosul = "v.Lokasyon LIKE 'MA%'"
        if sezonluk is True:
            kosul += " AND v.Kadro = 'SEZONLUK'"
        elif sezonluk is False:
            kosul += " AND COALESCE(v.Kadro, '') <> 'SEZONLUK'"
        zc.execute("SELECT COUNT(*) FROM dbo.vw_PersonelDepartman v WHERE " + kosul
                   + " AND " + (asof % (tarih, tarih)))
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

    # yillik trend kadrolu (3 POS magazasi)
    for yil in YILLAR:
        zc.execute("""SELECT COUNT(*) FROM dbo.vw_PersonelDepartman v
                      WHERE v.AltLokasyon IN (?, ?, ?) AND v.Lokasyon LIKE 'MA%'
                        AND COALESCE(v.Kadro, '') <> 'SEZONLUK'
                        AND """ + (asof % ("%d0831" % yil, "%d0831" % yil)),
                   SUBE[4478], SUBE[4477], SUBE[1])
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




    # 10) NORM KADRO karsilastirmasi — norm bir YONETIM PARAMETRESI, Zirve'den sorgulanmaz.
    #     Dosya: briefings/<klasor>/norm-kadro-YYYYMMDD.json (kullanici/IK verir, tarihli).
    #     ⚠ Norm SEZON DISI kadroyu tanimlar -> sezonluk personel norma dahil DEGIL; kiyas
    #     yalnizca KADROLU sayilarla yapilir. Sura norm tablosunda yok, kapsam disi tutulur.
    norm_dosya = sorted(Path(__file__).resolve().parent.parent.joinpath(
        "briefings", "sezon-kadro-20260902").glob("norm-kadro-*.json"))
    if norm_dosya:
        nd = json.loads(norm_dosya[-1].read_text(encoding="utf-8"))
        print("Norm kadro dosyası: %s" % norm_dosya[-1].name, flush=True)
        norm_sube, norm_bolum = {}, {}
        for bol, subeler in nd["norm"].items():
            norm_bolum[bol] = sum(subeler.values())
            for sube, adet in subeler.items():
                norm_sube[sube] = norm_sube.get(sube, 0) + adet
        mk = {m["sube"]: m for m in veri["magaza_kadro"]}
        satirlar = []
        for sube, nm in sorted(norm_sube.items(), key=lambda x: -x[1]):
            m = mk.get(sube)
            if not m:
                continue
            nsez = nd.get("norm_sezonluk", {}).get(sube, 0)
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
                  AND COALESCE(v.Kadro,'') <> 'SEZONLUK'
                  AND v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?)
            ) x
            GROUP BY x.bolum""", *(list(norm_subeler) + ["%d0831" % CARI, "%d0831" % CARI]))
        eng_bolum = {b: int(k) for b, k in zc.fetchall() if k}
        ger_bolum, sez_bolum = {}, {}
        for r in veri["magaza_bolum"]:
            if r["sube"] in norm_subeler:
                ger_bolum[r["bolum"]] = ger_bolum.get(r["bolum"], 0) + r["kadrolu26"]
                sez_bolum[r["bolum"]] = sez_bolum.get(r["bolum"], 0) + r["sezonluk26"]
        bolum_kars = []
        for b in sorted(set(norm_bolum) | set(ger_bolum),
                        key=lambda x: -max(0, norm_bolum.get(x, 0) - ger_bolum.get(x, 0))):
            nm, gr0, sz = norm_bolum.get(b, 0), ger_bolum.get(b, 0), sez_bolum.get(b, 0)
            if not (nm or gr0 or sz):
                continue
            eng = eng_bolum.get(b, 0)
            gr = gr0 - eng                      # engelli norm disi -> operasyonel kadrolu
            bolum_kars.append({"bolum": b, "norm": nm, "kadrolu26": gr, "kayit_kadrolu26": gr0,
                               "engelli26": eng, "norm_disi": (b == "ETKİNLİK"),
                               "acik": max(0, nm - gr), "fazla": max(0, gr - nm), "sezonluk26": sz})
        veri["norm"] = {
            "tarih": nd["meta"]["tarih"], "kaynak_dosya": norm_dosya[-1].name,
            "kapsam_disi": [x for x in mk if x not in norm_sube],
            "sube": satirlar,
            "bolum": bolum_kars,
            # ⚠ Bolum bazinda acik toplami, magaza bazindan BUYUK olur: magaza icinde bir bolumun
            #   fazlasi baska bolumun acigini maskeler (net -8, magaza-acik 11, bolum-acik 15).
            "acik_bolum_toplam": sum(r["acik"] for r in bolum_kars if not r["norm_disi"]),
            "fazla_bolum_toplam": sum(r["fazla"] for r in bolum_kars if not r["norm_disi"]),
            "engelli_bolum": eng_bolum,
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
        veri["norm"]["ayrik"] = ayrik
        veri["norm"]["engelli_kapsam_uyarisi"] = (
            "Engelli kadro yalnız BKM_GENEL firmasında vardır (FSM · İst. Yolu · Özlüce). Heykel "
            "(Bursa Kültür Merkezi, 35 kişi) ve Şura (Asiye Bingölbalı, 16 kişi) ayrı tüzel "
            "kişiliktir ve çalışan sayıları 50'nin ALTINDA olduğu için 4857/30 engelli istihdam "
            "yükümlülüğü doğmaz — o mağazalarda engelli kadro yoktur (veri eksikliği değildir).")


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

    zrv.close()

    veri["meta"].update({
        "baslik": "Kişi başı iş hacmi — sezon %d vs %d" % (CARI, ONCEKI),
        "kesim": "otomatik (veri sonu, okul-hizalı pencerede)",
        "cekirdek_sql": "sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql (blok 11)",
        "kadro_kaynak": "Zirve BKM_GENEL.dbo.vw_PersonelDepartman — as-of Igt <= T AND (Ict IS NULL OR Ict >= T), "
                        "sp_PersonelKarsilastirma_Ozet ile birebir",
        "hacim_kaynak": "DerinSIS irs/irsAyr eTip=100 (POS satışı), Sınav Okulları/Kıyafet hariç, iade netlenmiş",
        "pencere": "Okul açılışına hizalı — %s: %s – %s · %s: %s – %s (her iki yıl %d gün; açılış %s ve %s, "
                   "gün ofseti %d..%d)"
                   % (ONCEKI, veri["meta"]["pencere_tarih"][str(ONCEKI)][0],
                      veri["meta"]["pencere_tarih"][str(ONCEKI)][1],
                      CARI, veri["meta"]["pencere_tarih"][str(CARI)][0],
                      veri["meta"]["pencere_tarih"][str(CARI)][1],
                      veri["meta"]["gun"], OKUL_ACILIS[ONCEKI], OKUL_ACILIS[CARI],
                      OFSET_BAS, OFSET_SON),
    })
    return veri


NOTLAR = [
    "Ürün adedi enflasyondan bağımsız — kadro kıyasında birincil ölçüt. Ciro ikincil (fiyat endeksi +%19,8, Fisher, eşleşen ürün).",
    "Kıyas okul açılışına hizalı yapılır. Takvim tarihine göre kıyas 2026'da yapay düşüş gösterir: açılış 8 Eylül 2025'ten 14 Eylül 2026'ya, 6 gün kaydı.",
    "İş hacmi EncoreMerkez POS'tan DEĞİL DerinSIS'ten alınır: POS Temmuz 2025'te değişti (ENPOS → EncoreMerkez), EncoreMerkez'in 2025 tabanı eksik.",
    "Heykel ve Şura POS raporlamasında yok — mağaza sayfası üç POS mağazası (FSM · Özlüce · İst. Yolu). Beş mağaza kadro hareketi Özet'te ayrı.",
    "Kadro = o tarihte fiilen çalışan kişi (sezonluk + kadrolu). Kişi başı oranlar kasiyer değil TÜM mağaza kadrosu üzerinden.",
    "Fiş sayısı bu kaynakta yok: eTip 100 günlük özet belgedir (bir gün = bir belge).",
    "Kıdem → verimlilik testi NEGATİF çıktı: aynı kasiyerin öğrenme eğrisi düz (220 → 256 → 242 fiş/gün), mağaza kıdem sıralaması verimlilikle uyuşmuyor. 'Tecrübeli 1 kişi = acemi 3 kişi' iddiası bu veriyle savunulamaz.",
]


def _basliklar(ws, kolonlar, satir=1):
    """kolonlar = [(baslik, genislik, format), ...]"""
    for i, (ad, gen, _f) in enumerate(kolonlar, start=1):
        h = ws.cell(satir, i, ad)
        h.fill = BASLIK
        h.font = BASLIK_YAZI
        h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        h.border = KENAR
        ws.column_dimensions[get_column_letter(i)].width = gen
    ws.row_dimensions[satir].height = 30
    ws.freeze_panes = ws.cell(satir + 1, 2)


def _yaz(ws, satir, kolonlar, degerler):
    for i, ((_ad, _gen, fmt), deger) in enumerate(zip(kolonlar, degerler), start=1):
        c = ws.cell(satir, i, deger)
        c.border = KENAR
        if fmt:
            c.number_format = fmt
        if i == 1:
            c.alignment = Alignment(horizontal="left")
    return satir + 1


def _notlar(ws, notlar, satir, kol=1):
    for n in notlar:
        c = ws.cell(satir, kol, n)
        c.font = NOT_YAZI
        c.alignment = Alignment(wrap_text=False)
        satir += 1
    return satir


# --------------------------------------------------- Sunum (patrona gosterilen)
def sayfa_sunum(wb, veri):
    """PATRONA GOSTERILEN sayfa — ilk sirada. Tek ekran, dumduz Turkce, jargon yok.

    Rakamlar Ozet sayfasindan FORMULLE gelir (tek kaynak): Ozet'te ham rakam degisirse burasi da doner.
    Teknik bloklar (kapsam etiketleri, kopru kontrolu, mutabakat) arkadaki sayfalarda kalir.
    """
    ws = wb.create_sheet("Sunum", 0)
    ws.column_dimensions["A"].width = 4
    ws.column_dimensions["B"].width = 82
    ws.column_dimensions["C"].width = 26
    ws.sheet_view.showGridLines = False

    b = ws.cell(2, 2, "Sezon 2026 — kadro mu büyüdü, iş mi büyüdü?")
    b.font = Font(bold=True, size=16, color="1F5B57")
    ws.cell(3, 2, "Beş mağaza kadrosu · üç POS mağazası iş hacmi · 2025 ile aynı takvim dönemi").font = NOT_YAZI

    satirlar = [
        ("1", "Kadro farkı sezon başlamadan ÖNCE oluştu.",
         "30 Haziran'da kadrolu personel 139'dan 153'e çıkmıştı.", "='Ozet'!D20", "+0 kişi;-0 kişi"),
        ("2", "Sezon boyunca kadro büyümedi, KÜÇÜLDÜ.",
         "1 Temmuz – 31 Ağustos: kadrolu 153 → 149. Geçen yıl da aynı yönde (−4).", "='Ozet'!C22", "+0 kişi;-0 kişi"),
        ("3", "Sezonluk personel geçen yıldan AZ.",
         "31 Ağustos'ta çalışan sezonluk: 65 → 62 kişi.", "='Ozet'!D23", "+0 kişi;-0 kişi"),
        ("4", "Aynı dönemde elleçlenen ürün adedi %35 arttı.",
         "574.718 → 775.192 adet. Adet enflasyondan etkilenmez — fiilen kasadan geçen, rafa dizilen mal.",
         "='Ozet'!E8", "+0,0%"),
        ("5", "Ciro %71 arttı.",
         "71,8 milyon → 122,6 milyon ₺ (KDV dahil, iadeler düşülmüş).", "='Ozet'!E10", "+0,0%"),
        ("6", "KİŞİ BAŞINA düşen iş de arttı.",
         "Kişi başı ürün 4.019 → 4.845 adet; günlük 71,8 → 86,5 adet.", "='Ozet'!E13", "+0,0%"),
        ("7", "İş hacmi, kadronun yaklaşık 3 KATI hızla büyüdü.",
         "Ürün adedi +%34,9 · kadro +%11,9.", "='Ozet'!B17", "0,0\"x\""),
        ("8", "Artış yönetimde değil, RAFIN ÖNÜNDE.",
         "Yönetim +0 · Mal Kabul +0 · İdari İşler +0. Artış: Yardımcı Kitap +6 · Kırtasiye +3 · Kasa +2.",
         None, None),
        ("9", "Büyüme kurumsaldan gelmedi, mağazadan geldi.",
         "Sınav Okulları Ocak–Ağustos cirosu −%22,4 küçüldü; mağaza tarafı +%54,9 büyüdü.",
         "='Oca-Agu'!G4", "+0,0%"),
    ]

    s = 5
    for no, baslik, aciklama, formul, fmt in satirlar:
        n = ws.cell(s, 1, no)
        n.font = Font(bold=True, size=11, color="FFFFFF")
        n.fill = PatternFill("solid", fgColor="1F5B57")
        n.alignment = Alignment(horizontal="center", vertical="center")
        t = ws.cell(s, 2, baslik)
        t.font = Font(bold=True, size=11.5)
        t.alignment = Alignment(vertical="center")
        if formul:
            c = ws.cell(s, 3, formul)
            c.number_format = fmt
            c.font = Font(bold=True, size=14, color="1F7A4D")
            c.alignment = Alignment(horizontal="right", vertical="center")
        s += 1
        a = ws.cell(s, 2, aciklama)
        a.font = Font(size=10, color="444444")
        a.alignment = Alignment(wrap_text=True, vertical="top")
        ws.row_dimensions[s].height = 26
        s += 1

    s += 1
    k = ws.cell(s, 2, "TEK CÜMLE: Kadro farkı 1 Temmuz'dan önce kurulmuştu; sezon içinde kadro küçülürken "
                      "iş hacmi %35 büyüdü, kişi başına düşen iş %21 arttı.")
    k.font = Font(bold=True, size=11, color="1F5B57")
    k.alignment = Alignment(wrap_text=True, vertical="center")
    ws.cell(s, 1).fill = PatternFill("solid", fgColor="FFF3CD")
    ws.row_dimensions[s].height = 34
    s += 2

    ws.cell(s, 2, "Rakamların kaynağı ve kontrolü: Ozet · Magaza · Kadro · Bolum · Yillar · Oca-Agu · Yontem "
                  "sayfaları. Kadro = Zirve İK (İK'nın kendi karşılaştırma raporuyla birebir), iş hacmi = "
                  "DerinSIS mağaza satışı (Sınav hariç).").font = NOT_YAZI
    ws.cell(s, 2).alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[s].height = 28
    return ws


# ------------------------------------------------------------------ Ozet
def sayfa_ozet(wb, veri):
    """Kapsam ETIKETLI ozet + KOPRU kontrolu.

    ⚠ 02.09.2026 kullanici uyarisi: onceki surumde iki kapsam (3 POS magazasi vs 5 magaza) ve iki tarih
    (30.06 taban vs 31.08 kesim) etiketsiz yan yana duruyordu -> "rakamlar birbiriyle tutmuyor" goruntusu.
    Simdi her blok kapsamini yaziyor, altta KOPRU blogu aritmetigi formulle ispatliyor (kontrol = 0).
    """
    ws = wb.active
    ws.title = "Ozet"
    mag = veri["magaza"]
    gun = veri["meta"]["gun"]
    k5 = veri["kadro_5magaza"]
    POS = {"İST. YOLU", "ÖZLÜCE", "FSM"}

    # 3 POS magazasinin kadrolu/sezonluk ayrimi — magaza_kadro'dan (ayni kaynak, ayni as-of konvansiyonu)
    pos_kadrolu = {y: sum(m["kadrolu_kesim%d" % (y % 100)] for m in veri["magaza_kadro"] if m["sube"] in POS)
                   for y in (ONCEKI, CARI)}
    pos_sezonluk = {y: sum(m["sezonluk_kesim%d" % (y % 100)] for m in veri["magaza_kadro"] if m["sube"] in POS)
                    for y in (ONCEKI, CARI)}
    disi = {y: (k5["kadrolu_kesim%d" % (y % 100)] - pos_kadrolu[y]
                + k5["sezonluk_kesim%d" % (y % 100)] - pos_sezonluk[y]) for y in (ONCEKI, CARI)}

    kolonlar = [("Olcu", 44, None), ("%d" % ONCEKI, 16, None), ("%d" % CARI, 16, None),
                ("Fark", 15, None), ("Degisim", 11, YUZDE)]
    ws.cell(1, 1, "Ayni kadro, daha cok is — kapsamlar AYRI etiketli, altta kopru kontrolu").font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    def blok(s, metin):
        c = ws.cell(s, 1, metin)
        c.font = Font(bold=True, size=10, color="FFFFFF")
        for k in range(1, 6):
            ws.cell(s, k).fill = PatternFill("solid", fgColor="1F5B57")
        return s + 1

    def satir(s, etiket, v25, v26, fmt, oran=True, vurgu=False):
        ws.cell(s, 1, "   " + etiket).border = KENAR
        for kol, v in ((2, v25), (3, v26)):
            h = ws.cell(s, kol, v)
            h.number_format = fmt
            h.border = KENAR
            if vurgu:
                h.fill = GRI
                h.font = Font(bold=True)
        f = ws.cell(s, 4, "=C%d-B%d" % (s, s))
        f.number_format = "+#,##0;-#,##0;0" if fmt in (ADET, TL) else fmt
        f.border = KENAR
        if vurgu:
            f.fill = VURGU
            f.font = Font(bold=True)
        if oran:
            d = ws.cell(s, 5, '=IF(B%d=0,"",C%d/B%d-1)' % (s, s, s))
            d.number_format = YUZDE
            d.border = KENAR
        return s + 1

    # ---------------- KAPSAM A — uc POS magazasi
    s = blok(4, "KAPSAM A — UC POS MAGAZASI (FSM · Ozluce · Ist. Yolu) · is hacmi YALNIZ burada olculebilir")
    r_kad_a = s
    s = satir(s, "Kadrolu — 31.08", pos_kadrolu[ONCEKI], pos_kadrolu[CARI], ADET)
    r_sez_a = s
    s = satir(s, "Sezonluk — 31.08", pos_sezonluk[ONCEKI], pos_sezonluk[CARI], ADET)
    r_toplam_a = s
    ws.cell(s, 1, "= TOPLAM KADRO — 31.08 (kisi)").font = Font(bold=True)
    ws.cell(s, 1).border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d+%s%d" % (h, r_kad_a, h, r_sez_a))
        c.number_format = ADET
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    f = ws.cell(s, 4, "=C%d-B%d" % (s, s)); f.number_format = "+#,##0;-#,##0;0"; f.border = KENAR; f.fill = GRI
    d = ws.cell(s, 5, "=C%d/B%d-1" % (s, s)); d.number_format = YUZDE; d.border = KENAR; d.fill = GRI
    s += 1
    r_adet = s
    s = satir(s, "Urun adedi (elleclenen) — %d gun" % gun,
              sum(m["adet%d" % (ONCEKI % 100)] for m in mag),
              sum(m["adet%d" % (CARI % 100)] for m in mag), ADET)
    r_kh = s
    s = satir(s, "Ciro — KDV haric (TL)",
              sum(m["kdvharic%d" % (ONCEKI % 100)] for m in mag),
              sum(m["kdvharic%d" % (CARI % 100)] for m in mag), TL)
    s = satir(s, "Ciro — KDV dahil (TL)",
              sum(m["kdvdahil%d" % (ONCEKI % 100)] for m in mag),
              sum(m["kdvdahil%d" % (CARI % 100)] for m in mag), TL)
    s += 1

    # ---------------- KISI BASI (kapsam A)
    s = blok(s, "KISI BASI — asil olcu · kapsam A toplam kadrosuna bolunur (satir %d)" % r_toplam_a)
    for etiket, fmt, f25, f26 in [
        ("Urun adedi / kisi", ADET, "=B%d/B%d" % (r_adet, r_toplam_a), "=C%d/C%d" % (r_adet, r_toplam_a)),
        ("Urun adedi / kisi / gun", ADET1, "=B%d/B%d/%d" % (r_adet, r_toplam_a, gun), "=C%d/C%d/%d" % (r_adet, r_toplam_a, gun)),
        ("Ciro (KDV haric) / kisi (TL)", TL, "=B%d/B%d" % (r_kh, r_toplam_a), "=C%d/C%d" % (r_kh, r_toplam_a)),
    ]:
        ws.cell(s, 1, "   " + etiket).border = KENAR
        for kol, f in ((2, f25), (3, f26)):
            c = ws.cell(s, kol, f)
            c.number_format = fmt
            c.border = KENAR
            c.fill = GRI
        fk = ws.cell(s, 4, "=C%d-B%d" % (s, s)); fk.number_format = fmt; fk.border = KENAR; fk.fill = GRI
        dd = ws.cell(s, 5, "=C%d/B%d-1" % (s, s)); dd.number_format = YUZDE; dd.border = KENAR
        dd.fill = GRI; dd.font = YESIL_YAZI
        s += 1
    ws.cell(s, 1, "   Is buyumesi kadro buyumesinin kac kati (adet ÷ kadro)").border = KENAR
    kat = ws.cell(s, 2, "=E%d/E%d" % (r_adet, r_toplam_a))
    kat.number_format = KAT; kat.fill = VURGU; kat.border = KENAR; kat.font = Font(bold=True, size=12)
    ws.cell(s, 3, "adet degisimi ÷ kadro degisimi").font = NOT_YAZI
    s += 1
    ws.cell(s, 1, "   ayni oran ciro ile (ciro ÷ kadro)").border = KENAR
    kat2 = ws.cell(s, 2, "=E%d/E%d" % (r_kh, r_toplam_a))
    kat2.number_format = KAT; kat2.border = KENAR
    s += 2

    # ---------------- KAPSAM B — bes magaza
    s = blok(s, "KAPSAM B — BES MAGAZA (+ Heykel, Sura: POS raporlamasinda YOK -> is hacmi olculemez)")
    r_taban_b = s
    s = satir(s, "Kadrolu — TABAN 30.06 (sezon oncesi kurulu kadro)",
              k5["kadrolu_taban%d" % (ONCEKI % 100)], k5["kadrolu_taban%d" % (CARI % 100)], ADET, vurgu=True)
    r_kesim_b = s
    s = satir(s, "Kadrolu — KESIM 31.08", k5["kadrolu_kesim%d" % (ONCEKI % 100)],
              k5["kadrolu_kesim%d" % (CARI % 100)], ADET)
    ws.cell(s, 1, "   Sezon ici kadrolu degisim (kesim - taban)").border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d-%s%d" % (h, r_kesim_b, h, r_taban_b))
        c.number_format = "+0;-0;0"
        c.border = KENAR
        c.fill = VURGU
        c.font = Font(bold=True)
    ws.cell(s, 4, "iki yilda da -4: sezon icinde kadro BUYUMEDI").font = NOT_YAZI
    s += 1
    s = satir(s, "Sezonluk — 31.08", k5["sezonluk_kesim%d" % (ONCEKI % 100)],
              k5["sezonluk_kesim%d" % (CARI % 100)], ADET)
    r_toplam_b = s
    s = satir(s, "= Toplam kadro — 31.08", k5["toplam_kesim%d" % (ONCEKI % 100)],
              k5["toplam_kesim%d" % (CARI % 100)], ADET)
    s += 1

    # ---------------- KOPRU
    s = blok(s, "KOPRU — A ile B nasil bagli (KONTROL satiri 0 olmali)")
    r_k1 = s
    ws.cell(s, 1, "   Kapsam A toplam kadro (31.08)").border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d" % (h, r_toplam_a))
        c.number_format = ADET
        c.border = KENAR
    s += 1
    r_k2 = s
    s = satir(s, "+ Heykel + Sura (kadrolu + sezonluk)", disi[ONCEKI], disi[CARI], ADET, oran=False)
    r_k3 = s
    ws.cell(s, 1, "   = Kapsam B toplam kadro (hesap)").border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d+%s%d" % (h, r_k1, h, r_k2))
        c.number_format = ADET
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    s += 1
    ws.cell(s, 1, "   KONTROL: hesap - B blogundaki toplam (0 OLMALI)").font = Font(bold=True)
    ws.cell(s, 1).border = KENAR
    for kol, h in ((2, "B"), (3, "C")):
        c = ws.cell(s, kol, "=%s%d-%s%d" % (h, r_k3, h, r_toplam_b))
        c.number_format = "0"
        c.border = KENAR
        c.fill = VURGU
        c.font = Font(bold=True)
    s += 2

    _notlar(ws, [
        "NEDEN IKI KAPSAM: is hacmi (adet/ciro) yalniz POS raporlamasi olan UC magazada olculebilir;",
        "   kadro hareketi ise bes magazanin tamaminda anlamli. Karismasin diye bloklar ayri + kopru var.",
        "NEDEN IKI TARIH: 30.06 = sezon baslamadan onceki kurulu kadro (+14 farki BURADA olustu),",
        "   31.08 = sezon zirvesindeki fiili kadro. Ayni yilin iki farkli gunu; birbirinin yerine gecmez.",
        "Kadrolu = Kadro <> 'SEZONLUK' · Sezonluk = Kadro = 'SEZONLUK' · Toplam = ikisinin toplami.",
        "Tum yuzde / oran / kopru satirlari Excel FORMULU — ham rakami degistir, hepsi kendini gunceller.",
    ], s)
    return ws


# ------------------------------------------------------------------ Magaza
def sayfa_magaza(wb, veri):
    ws = wb.create_sheet("Magaza")
    gun = veri["meta"]["gun"]
    kolonlar = [
        ("Magaza", 13, None),
        ("Kadro 2025", 9, ADET), ("Kadro 2026", 9, ADET), ("Kadro Δ%", 9, YUZDE),
        ("Urun adedi 2025", 13, ADET), ("Urun adedi 2026", 13, ADET), ("Adet Δ%", 9, YUZDE),
        ("Adet/kisi 2025", 11, ADET), ("Adet/kisi 2026", 11, ADET), ("Adet/kisi Δ%", 11, YUZDE),
        ("Adet/kisi/gun 2025", 12, ADET1), ("Adet/kisi/gun 2026", 12, ADET1),
        ("Ciro 2025 (KDV haric)", 15, TL), ("Ciro 2026 (KDV haric)", 15, TL), ("Ciro Δ%", 9, YUZDE),
        ("Ciro/kisi 2025", 13, TL), ("Ciro/kisi 2026", 13, TL), ("Ciro/kisi Δ%", 11, YUZDE),
        ("Is / kadro (kac kat)", 11, KAT),
    ]
    ws.cell(1, 1, "Magaza bazinda kisi basi is — okul-hizali pencere (%d gun, Sinav haric)" % gun).font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    s = 4
    ilk = s
    for m in veri["magaza"]:
        ws.cell(s, 1, m["ad"]).border = KENAR
        ham = {2: m["kadro25"], 3: m["kadro26"], 5: m["adet25"], 6: m["adet26"],
               13: m["kdvharic25"], 14: m["kdvharic26"]}
        for kol, v in ham.items():
            c = ws.cell(s, kol, v)
            c.number_format = kolonlar[kol - 1][2]
            c.border = KENAR
        s += 1
    son = s - 1

    # TOPLAM satiri — ham kolonlar SUM
    ws.cell(s, 1, "TOPLAM").font = Font(bold=True)
    ws.cell(s, 1).fill = GRI
    ws.cell(s, 1).border = KENAR
    for kol in (2, 3, 5, 6, 13, 14):
        c = ws.cell(s, kol, "=SUM(%s%d:%s%d)" % (get_column_letter(kol), ilk, get_column_letter(kol), son))
        c.number_format = kolonlar[kol - 1][2]
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    toplam = s

    # tureme kolonlari (formul) — hem magaza satirlari hem TOPLAM
    for r in list(range(ilk, son + 1)) + [toplam]:
        kalin = Font(bold=True) if r == toplam else None
        dolgu = GRI if r == toplam else None
        turemeler = {
            4: "=C%d/B%d-1" % (r, r),
            7: "=F%d/E%d-1" % (r, r),
            8: "=E%d/B%d" % (r, r),
            9: "=F%d/C%d" % (r, r),
            10: "=I%d/H%d-1" % (r, r),
            11: "=E%d/B%d/%d" % (r, r, gun),
            12: "=F%d/C%d/%d" % (r, r, gun),
            15: "=N%d/M%d-1" % (r, r),
            16: "=M%d/B%d" % (r, r),
            17: "=N%d/C%d" % (r, r),
            18: "=Q%d/P%d-1" % (r, r),
            19: "=G%d/D%d" % (r, r),
        }
        for kol, f in turemeler.items():
            c = ws.cell(r, kol, f)
            c.number_format = kolonlar[kol - 1][2]
            c.border = KENAR
            if dolgu:
                c.fill = dolgu
            if kalin:
                c.font = kalin
            if kol in (10, 18, 19):
                c.font = Font(bold=True, color="1F7A4D")

    # grafik: kisi basi urun adedi, magaza bazinda 2025 vs 2026
    g = BarChart()
    g.type = "col"
    g.title = "Kisi basi urun adedi — 2025 vs 2026"
    g.y_axis.title = "adet / kisi"
    g.height, g.width = 8, 16
    g.add_data(Reference(ws, min_col=8, max_col=9, min_row=3, max_row=son), titles_from_data=True)
    g.set_categories(Reference(ws, min_col=1, min_row=ilk, max_row=son))
    ws.add_chart(g, "A%d" % (toplam + 3))

    s = toplam + 22
    _notlar(ws, [
        "Kadro = 31.08 itibariyla o magazada fiilen calisan TUM personel (sezonluk + kadrolu).",
        "'Is / kadro' = urun adedi buyumesi / kadro buyumesi. 1,0x'in uzeri: is kadrodan hizli buyudu.",
        "Ist. Yolu kadrosu en cok buyuyen magaza (50 -> 61) ama ise ragmen kisi basi adedi de artti.",
    ], s)
    return ws


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



# ------------------------------------------------------------------ Kategori
def sayfa_kategori(wb, veri):
    """Hangi kategori ne kadar buyudu — bolum kadro artisiyla ESLESTIRME sayfasi."""
    ws = wb.create_sheet("Kategori")
    # kategori -> hangi bolumun (reyonun) isi (BKM reyon/kategori eslesmesi)
    ESLES = {
        "Hazırlık Kitapları": "YARDIMCI KİTAP", "Kırtasiye": "KIRTASİYE", "Kitap": "KÜLTÜR",
        "Çocuk Kitabı": "ÇOCUK", "Oyuncak": "OYUNCAK", "Akademi": "AKADEMİ",
        "Hediyelik": "KIRTASİYE / OYUNCAK", "Gıda": "KAFE / GIDA",
    }
    kadro_delta = {b["bolum"]: b["kadrolu26"] - b["kadrolu25"] for b in veri["bolum"]}

    kolonlar = [("Kategori", 19, None), ("İlgili bölüm", 18, None),
                ("Adet 2025", 12, ADET), ("Adet 2026", 12, ADET), ("Adet Δ", 9, YUZDE),
                ("Ciro 2025 (M ₺)", 13, ADET1), ("Ciro 2026 (M ₺)", 13, ADET1), ("Ciro Δ", 9, YUZDE),
                ("Oca-Ağu adet 2025", 14, ADET), ("Oca-Ağu adet 2026", 14, ADET), ("Oca-Ağu adet Δ", 12, YUZDE),
                ("Oca-Ağu ciro Δ", 12, YUZDE),
                ("Bölüm kadro Δ", 11, "+0;-0;0")]
    ws.cell(1, 1, "Kategori büyümesi (okul-hizalı pencere VE Ocak-Ağustos) + o kategoriye bakan bölümün "
                  "kadro değişimi").font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    s = 4
    ilk = s
    for k in veri["kategori"]:
        bolum = ESLES.get(k["kategori"], "—")
        ws.cell(s, 1, k["kategori"]).border = KENAR
        ws.cell(s, 2, bolum).border = KENAR
        for kol, v_ in ((3, k["adet25"]), (4, k["adet26"])):
            c = ws.cell(s, kol, v_); c.number_format = ADET; c.border = KENAR
        for kol, v_ in ((6, k["ciro25"] / 1e6), (7, k["ciro26"] / 1e6)):
            c = ws.cell(s, kol, v_); c.number_format = ADET1; c.border = KENAR
        for kol, f in ((5, "=D%d/C%d-1" % (s, s)), (8, "=G%d/F%d-1" % (s, s))):
            c = ws.cell(s, kol, f); c.number_format = YUZDE; c.border = KENAR
            c.font = Font(bold=True)
        for kol, v_ in ((9, k.get("oa_adet25")), (10, k.get("oa_adet26"))):
            c = ws.cell(s, kol, v_ if v_ is not None else "—")
            c.number_format = ADET
            c.border = KENAR
        for kol, f in ((11, "=IF(OR(I%d=\"—\",J%d=\"—\"),\"\",J%d/I%d-1)" % (s, s, s, s)),
                       (12, "=IF(OR(I%d=\"—\",J%d=\"—\"),\"\",%s)" % (s, s, "0"))):
            c = ws.cell(s, kol, f)
            c.number_format = YUZDE
            c.border = KENAR
        if k.get("oa_ciro25"):
            c = ws.cell(s, 12, (k["oa_ciro26"] / k["oa_ciro25"]) - 1)
            c.number_format = YUZDE
            c.border = KENAR
        kd = kadro_delta.get(bolum)
        c = ws.cell(s, 13, kd if kd is not None else "—")
        c.number_format = "+0;-0;0"
        c.border = KENAR
        if kd:
            c.fill = VURGU
        s += 1
    son = s - 1

    ws.cell(s, 1, "TOPLAM").font = Font(bold=True)
    ws.cell(s, 1).fill = GRI; ws.cell(s, 1).border = KENAR
    ws.cell(s, 2).fill = GRI; ws.cell(s, 2).border = KENAR
    for kol in (3, 4, 6, 7, 9, 10):
        c = ws.cell(s, kol, "=SUM(%s%d:%s%d)" % (get_column_letter(kol), ilk, get_column_letter(kol), son))
        c.number_format = ADET if kol in (3, 4, 9, 10) else ADET1
        c.border = KENAR; c.fill = GRI; c.font = Font(bold=True)
    for kol, f in ((5, "=D%d/C%d-1" % (s, s)), (8, "=G%d/F%d-1" % (s, s)),
                   (11, "=J%d/I%d-1" % (s, s))):
        c = ws.cell(s, kol, f); c.number_format = YUZDE; c.border = KENAR
        c.fill = GRI; c.font = Font(bold=True)

    s += 2
    _notlar(ws, [
        "IKI PENCERE: sol blok OKUL-HIZALI pencere (sezon kiyasi), sag blok OCAK-AGUSTOS kumulatif (yil geneli).",
        "ESLESME: kategori (urun) -> o urune bakan reyon (bolum). Kadro Δ o BOLUMUN kadrolu degisimidir.",
        "OKUNACAK: kadro artisi en hizli buyuyen kategorilere gitti (Hazirlik Kitaplari, Kirtasiye, Akademi);",
        "   en yavas buyuyen kategoride (Cocuk Kitabi) kadro AZALTILDI. Yani alim rastgele degil.",
        "Kapsam: uc POS magazasi, okul-hizali pencere, Sinav haric, KDV dahil, iadeler dusulmus.",
        "Toplam satiri yalniz bu tablodaki kategorilerin toplami (adet>=2000 esigi altindaki kuyruk haric).",
    ], s)
    return ws



# ------------------------------------------------------------------ Aylik (takvim ayi)
def sayfa_aylik(wb, veri):
    """Haz/Tem/Agu ay ay — Agustos'un neden zayif gorundugu (okul kaymasi) burada gorunur."""
    ws = wb.create_sheet("Aylik")
    kolonlar = [("Ay", 12, None), ("Adet 2025", 13, ADET), ("Adet 2026", 13, ADET), ("Adet Δ", 10, YUZDE),
                ("Ciro 2025 (M ₺)", 14, ADET1), ("Ciro 2026 (M ₺)", 14, ADET1), ("Ciro Δ", 10, YUZDE)]
    ws.cell(1, 1, "Aylık seyir — takvim ayı (üç POS mağazası, Sınav hariç, KDV dahil)").font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    s = 4
    ilk = s
    for a in veri.get("aylik", []):
        ws.cell(s, 1, a["ad"]).border = KENAR
        for kol, v_ in ((2, a["adet25"]), (3, a["adet26"])):
            c = ws.cell(s, kol, v_); c.number_format = ADET; c.border = KENAR
        for kol, v_ in ((5, a["ciro25"] / 1e6), (6, a["ciro26"] / 1e6)):
            c = ws.cell(s, kol, v_); c.number_format = ADET1; c.border = KENAR
        for kol, f in ((4, "=C%d/B%d-1" % (s, s)), (7, "=F%d/E%d-1" % (s, s))):
            c = ws.cell(s, kol, f); c.number_format = YUZDE; c.border = KENAR; c.font = Font(bold=True)
        s += 1
    son = s - 1

    ws.cell(s, 1, "TOPLAM").font = Font(bold=True); ws.cell(s, 1).fill = GRI; ws.cell(s, 1).border = KENAR
    for kol in (2, 3, 5, 6):
        c = ws.cell(s, kol, "=SUM(%s%d:%s%d)" % (get_column_letter(kol), ilk, get_column_letter(kol), son))
        c.number_format = ADET if kol in (2, 3) else ADET1
        c.border = KENAR; c.fill = GRI; c.font = Font(bold=True)
    for kol, f in ((4, "=C%d/B%d-1" % (s, s)), (7, "=F%d/E%d-1" % (s, s))):
        c = ws.cell(s, kol, f); c.number_format = YUZDE; c.border = KENAR; c.fill = GRI; c.font = Font(bold=True)

    # --- KAYMA DUZELTMESI blogu
    k = veri.get("kayma")
    if k:
        s += 2
        ws.cell(s, 1, "OKUL KAYMASI DÜZELTMESİ").font = BOLUM_YAZI
        s += 1
        h = k["hizali_buyume"]
        satirlar = [
            ("Hizalı pencere (aynı talep gününe denk gelen günler)",
             "%s  vs  %s  (%d gün)" % (h["pencere_2025"], h["pencere_2026"], h["gun"])),
            ("Hizalı pencerede büyüme",
             "adet +%%%.1f · ciro +%%%.1f" % (h["adet"] * 100, h["ciro"] * 100)),
            ("Ağustos 2025 (gerçek)",
             "%s adet · %.1f M TL" % ("{:,.0f}".format(k["y25_agu_tam"]["adet"]).replace(",", "."),
                                      k["y25_agu_tam"]["ciro"] / 1e6)),
            ("Ağustos 2026 (gerçek)",
             "%s adet · %.1f M TL  (adet +%%%.1f)"
             % ("{:,.0f}".format(k["y26_agu_tam"]["adet"]).replace(",", "."),
                k["y26_agu_tam"]["ciro"] / 1e6,
                (k["y26_agu_tam"]["adet"] / k["y25_agu_tam"]["adet"] - 1) * 100)),
            ("Ağustos 2026 — KAYMA OLMASAYDI (tahmin)",
             "%s adet · %.1f M TL"
             % ("{:,.0f}".format(k["agustos_kaymasiz_tahmin"]["adet"]).replace(",", "."),
                k["agustos_kaymasiz_tahmin"]["ciro"] / 1e6)),
            ("EYLÜL'E KAYAN (tahmin)",
             "%s adet · %.1f M TL"
             % ("{:,.0f}".format(k["eylule_kayan"]["adet"]).replace(",", "."),
                k["eylule_kayan"]["ciro"] / 1e6)),
            ("Okul öncesi dalga — 2025 gerçekleşen (%s)" % k["eylul_dalga_beklentisi"]["pencere_2025"],
             "%s adet · %.1f M TL"
             % ("{:,.0f}".format(k["eylul_dalga_beklentisi"]["adet_2025"]).replace(",", "."),
                k["eylul_dalga_beklentisi"]["ciro_2025"] / 1e6)),
            ("Okul öncesi dalga — 2026 beklenen (%s)" % k["eylul_dalga_beklentisi"]["pencere_2026"],
             "%s adet · %.1f M TL"
             % ("{:,.0f}".format(k["eylul_dalga_beklentisi"]["adet_2026_tahmin"]).replace(",", "."),
                k["eylul_dalga_beklentisi"]["ciro_2026_tahmin"] / 1e6)),
        ]
        for etiket, deger in satirlar:
            a = ws.cell(s, 1, etiket); a.border = KENAR
            b = ws.cell(s, 2, deger); b.border = KENAR
            ws.merge_cells(start_row=s, start_column=2, end_row=s, end_column=7)
            if "KAYMA OLMASAYDI" in etiket or "KAYAN" in etiket or "beklenen" in etiket:
                a.font = Font(bold=True); b.font = Font(bold=True, color="A6001A")
                a.fill = VURGU; b.fill = VURGU
            s += 1
        s += 1
        ws.cell(s, 1, "Yöntem: " + k["yontem"]).font = NOT_YAZI
        ws.cell(s, 1).alignment = Alignment(wrap_text=True, vertical="top")
        ws.merge_cells(start_row=s, start_column=1, end_row=s, end_column=7)
        ws.row_dimensions[s].height = 42
        s += 1

    s += 2
    _notlar(ws, [
        "AGUSTOS NEDEN ZAYIF GORUNUYOR: okullar 2025'te 8 Eylul, 2026'da 14 Eylul acildi (6 gun kayma).",
        "   2025'in son-Agustos alis dalgasi 2026'da EYLUL'e kaydi -> takvim ayi kiyasinda Agustos dusuk cikar.",
        "   Temmuz +%36,3 adet, Agustos +%5,5 adet: fark talep kaybi degil, TAKVIM.",
        "Dogru kiyas okul-acilisina hizali penceredir (Ozet sayfasi): adet +%34,9 · ciro +%70,7.",
        "Bu sayfa 'ay ay ne oldu' sorusunun cevabidir; kadro kiyasinda hizali pencere kullanilir.",
    ], s)
    return ws


# ------------------------------------------------------------------ Yillar
def sayfa_yillar(wb, veri):
    ws = wb.create_sheet("Yillar")
    kolonlar = [("Yil", 8, None), ("Kadrolu (31.08)", 13, ADET), ("Urun adedi (Oca-Agu)", 16, ADET),
                ("Adet / kisi", 12, ADET), ("Onceki yila gore", 13, YUZDE)]
    ws.cell(1, 1, "Kisi basi is — 4 yillik trend (uc POS magazasi, Ocak-Agustos kumulatif, Sinav haric)").font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    s = 4
    ilk = s
    for y in veri["yillar"]:
        ws.cell(s, 1, y["yil"]).border = KENAR
        for kol, v in ((2, y["kadrolu"]), (3, y["adet"])):
            c = ws.cell(s, kol, v)
            c.number_format = ADET
            c.border = KENAR
        c = ws.cell(s, 4, "=C%d/B%d" % (s, s))
        c.number_format = ADET
        c.border = KENAR
        c.font = Font(bold=True)
        if s > ilk:
            d = ws.cell(s, 5, "=D%d/D%d-1" % (s, s - 1))
            d.number_format = YUZDE
            d.border = KENAR
        else:
            ws.cell(s, 5, "—").border = KENAR
        s += 1
    son = s - 1

    g = LineChart()
    g.title = "Kisi basi urun adedi — 4 yillik trend"
    g.y_axis.title = "adet / kisi"
    g.height, g.width = 8, 16
    g.add_data(Reference(ws, min_col=4, min_row=3, max_row=son), titles_from_data=True)
    g.set_categories(Reference(ws, min_col=1, min_row=ilk, max_row=son))
    ws.add_chart(g, "G3")

    s += 1
    _notlar(ws, [
        "2024 ATLAMASI: kadrolu 60 -> 91, adet yalniz +%11 -> kisi basi is -%27. Kadro sismesi 2024'te oldu.",
        "AMA 2023 verimliligi 'norm' DEGIL: 2023'te FSM kasada 0 kisi, Ozluce kasada 1 kisi vardi (eksik kadroyla calisma).",
        "2024 -> 2026: kisi basi is +%28,8 toparlanma. Bu yil kadro +15 kisi buyurken kisi basi is de artti.",
        "Bu sayfada kadro yalniz KADROLU (sezonluk haric) — yillar arasi sezonluk tahliye zamanlamasi kiyasi bozuyor.",
    ], s)
    return ws


# ------------------------------------------------------------------ Oca-Agu (itiraz cevabi)
def sayfa_oca_agu(wb, veri):
    ws = wb.create_sheet("Oca-Agu")
    oa = veri["ocak_agustos"]
    kolonlar = [("Kanal", 24, None), ("Adet 2025", 14, ADET), ("Adet 2026", 14, ADET), ("Adet Δ%", 10, YUZDE),
                ("Ciro 2025 (KDV dahil)", 17, TL), ("Ciro 2026 (KDV dahil)", 17, TL), ("Ciro Δ%", 10, YUZDE)]
    ws.cell(1, 1, "\"Buyume kurumsaldan geldi\" itirazinin cevabi — Ocak-Agustos, uc POS magazasi").font = Font(bold=True, size=12)
    _basliklar(ws, kolonlar, satir=3)

    s = 4
    for etiket, blok in (("Magaza (perakende raf)", oa["magaza"]), ("Sinav Okullari (kurumsal)", oa["sinav"])):
        ws.cell(s, 1, etiket).border = KENAR
        for kol, v in ((2, blok["adet25"]), (3, blok["adet26"]),
                       (5, blok["kdvdahil25"]), (6, blok["kdvdahil26"])):
            c = ws.cell(s, kol, v)
            c.number_format = kolonlar[kol - 1][2]
            c.border = KENAR
        for kol, f in ((4, "=C%d/B%d-1" % (s, s)), (7, "=F%d/E%d-1" % (s, s))):
            c = ws.cell(s, kol, f)
            c.number_format = YUZDE
            c.border = KENAR
        s += 1
    ilk, son = 4, s - 1

    ws.cell(s, 1, "TOPLAM").font = Font(bold=True)
    ws.cell(s, 1).fill = GRI
    ws.cell(s, 1).border = KENAR
    for kol in (2, 3, 5, 6):
        c = ws.cell(s, kol, "=SUM(%s%d:%s%d)" % (get_column_letter(kol), ilk, get_column_letter(kol), son))
        c.number_format = kolonlar[kol - 1][2]
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    for kol, f in ((4, "=C%d/B%d-1" % (s, s)), (7, "=F%d/E%d-1" % (s, s))):
        c = ws.cell(s, kol, f)
        c.number_format = YUZDE
        c.border = KENAR
        c.fill = GRI
        c.font = Font(bold=True)
    s += 2

    _notlar(ws, [
        "Sinav Okullari KUCULDU (adet -%35, ciro -%22). Buyumenin tamami magaza rafindan geldi.",
        "Magaza tarafi kurumsal dususu de kapatti: toplam yine buyudu.",
        "Sinav = Kategori3 'Sinav Okullari' + 'Sinav Kiyafet'; ayni POS belgesi icinde geldigi icin AYIKLANMASI zorunlu.",
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
        ws.cell(s, 1, r["bolum"].title()).border = KENAR
        for kol, v_ in ((2, r["norm"]), (3, r["kadrolu26"]),
                        (4, r["acik"] or "—"), (5, r["fazla"] or "—"), (6, r["sezonluk26"])):
            c = ws.cell(s, kol, v_)
            c.number_format = ADET
            c.border = KENAR
            if kol == 4 and r["acik"]:
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
        "bolumun acigini maskeler." % (n["acik_bolum_toplam"],
                                       sum(max(0, r["norm"] - r["kadrolu_kesim26"]) for r in n["sube"])),
        "NORM SEZON DISI kadroyu tanimlar -> sezonluk personel norma DAHIL DEGIL; kiyas yalniz KADROLU ile.",
        "Norm kaynagi: %s (%s). Yonetim parametresi, Zirve'den sorgulanmaz." % (n["kaynak_dosya"], n["tarih"]),
        "KAPSAM DISI: %s norm tablosunda yok." % (", ".join(x.title() for x in n["kapsam_disi"]) or "—"),
        "Eksi fark = normun ALTINDA calisiliyor. Toplamda 31.08'de norm %d, gercek kadrolu %d." % (
            n["toplam"]["norm"], n["toplam"]["kadrolu_kesim26"]),
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


def main(argv):
    cek_mod = "--cek" in argv
    kisi_mod = "--kisi" in argv
    args = [a for a in argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        print(__doc__)
        return 2
    veri_yolu, cikti = Path(args[0]), Path(args[1])

    if cek_mod:
        veri = cek(_env(), kisi=kisi_mod)
        veri_yolu.parent.mkdir(parents=True, exist_ok=True)
        # KVKK: kisi-duzeyi satirlar PAYLASILAN json'a YAZILMAZ (o dosya git'te izleniyor).
        # Ayri *KISILI*.json dosyasina gider; gitignore o deseni yakalar.
        paylasilan = {k: val for k, val in veri.items() if k != "personel"}
        veri_yolu.write_text(json.dumps(paylasilan, ensure_ascii=False, indent=2), encoding="utf-8")
        print("Veri yazıldı: %s (toplulaştırılmış)" % veri_yolu, flush=True)
        if veri.get("personel"):
            kisi_yolu = veri_yolu.with_name(veri_yolu.stem + "-KISILI.json")
            kisi_yolu.write_text(json.dumps({"personel": veri["personel"]}, ensure_ascii=False, indent=2),
                                 encoding="utf-8")
            print("Kişi listesi ayrı dosyada: %s (gitignore)" % kisi_yolu, flush=True)
    else:
        veri = json.loads(veri_yolu.read_text(encoding="utf-8"))

    wb = Workbook()
    sayfa_ozet(wb, veri)
    sayfa_magaza(wb, veri)
    sayfa_kadro(wb, veri)
    sayfa_bolum(wb, veri)
    sayfa_kategori(wb, veri)
    sayfa_aylik(wb, veri)
    sayfa_yillar(wb, veri)
    sayfa_oca_agu(wb, veri)
    sayfa_norm(wb, veri)
    sayfa_yontem(wb, veri)
    if veri.get("personel"):
        sayfa_personel(wb, veri)
    sayfa_sunum(wb, veri)   # EN SONDA: index 0'a girer, capraz-sayfa formulleri hedeflerini bulur
    # cikti yukarida cozuldu
    cikti.parent.mkdir(parents=True, exist_ok=True)
    try:
        wb.save(cikti)
    except PermissionError:
        sys.exit("Dosya açık görünüyor, kaydedilemedi. Excel'de kapatıp tekrar çalıştır: %s" % cikti)
    print("Yazildi: %s (%d sayfa)" % (cikti, len(wb.worksheets)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
