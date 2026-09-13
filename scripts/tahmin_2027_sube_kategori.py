# -*- coding: utf-8 -*-
"""2026 KAPANIŞ + 2027 TAHMİN — ay × şube × kategori, adet / birim fiyat / ciro.

Doğuş sebebi 13.09.2026 (GMY), sırayla gelen dört yön:
  1) _"bana 2027 şube ciro satış tahmini yapman lazım ay şube hatta kategori adet
      birim fiyat ciro kırılımlı şekilde"_ → _"ay şube kategori çalışman lazım"_
  2) _"ilk önce bu yıl kalan ayların kapanışlarını tahmin etmen lazım sanırım"_
  3) _"seneye de bayram resmi tatil dini bayram okul sezonu vs dikkate almalısın"_
GMY kararları (AskUserQuestion): fiyat → ÜÇ SENARYO · şube → belirsiz, taban + duyarlılık ·
Sınav → **AYRI TUT, KARIŞTIRMA**.

⚠ (2) ilk kurguyu GEÇERSİZ KILDI: tahmin trailing-12 penceresi üzerineydi. Artık
   önce 2026 KAPANIR (Eyl-Ara), 2027 TAM 2026'nın üstüne kurulur.

═══ NEDEN ADET VE FİYAT AYRI ══════════════════════════════════════════════════
İki kuvvet TERS yönde (ölçüldü, hizalı pencere, perakende):
    adet  2024/23 +%13,3 · 2025/24 +%21,3 · 2026/25 +%33,0   (HIZLANIYOR)
    fiyat 2025/24 ~+%30  · 2026/25 ~+%17,9                    (YAVAŞLIYOR)
Tek sayıyla tahmin bu ikisini karıştırır ve yanılır.

═══ KAYNAK ════════════════════════════════════════════════════════════════════
DerinSIS `dbo.irsHrk` — 5 yıl derinlik, ADET + CİRO, KDV HARİÇ.
Kanonik ciro: **eTip 100 − 101 + 4 − 5**. `eTip=100` tek başına İst.Yolu'nda −%9,5 sapar.
Sınav ayrımı ÜRÜN BAZLI (`bkm.UrunBilgi.KatAna LIKE 'Sınav Okul%'`); belge bazlı
(EncoreMerkez `DocumentsTypeId=8`) ayrımdan FARKLI sonuç verir — karıştırma.
⚠ EncoreMerkez kullanılmadı: belge-bazlı ölçüm yalnız Ağu-2025 sonrası güvenli
  (POS geçişi) → mevsimsellik için yeterli geçmiş yok.

═══ 1. AŞAMA — 2026 KAPANIŞI ══════════════════════════════════════════════════
⚠⚠ EYLÜL TAKVİMLE KAPATILMAZ. Sema `sezon_ciro_tahmini_okul_hizali`: okul açılışı
kayan yılda tahmin takvim ayı üzerinden yapılmaz. ÖLÇÜLEN açılışlar:
    2024-2025 → 09.09.2024 · 2025-2026 → 08.09.2025 · 2026-2027 → **14.09.2026**
2026'da açılış **6 GÜN GEÇ**. 13.09.2026'da okul HENÜZ AÇILMAMIŞTI (T−1); 2025'te
aynı takvim gününde okul 5 gündür açıktı ve zirve (T+5) geçmişti. Takvim kıyası
bunu "talep kaybı" sanır — YANLIŞ.
Yöntem: (1) günlük seri okul açılışına hizalanır (ofset = gün − açılış);
(2) büyüme çarpanı k SON TAM hizalı günlerden ölçülür (T−29..T−2);
(3) kalan günler = 2025'in AYNI OFSETLERİ × k; (4) takvime geri yazılır.
Ölçülen k (T−29..T−2, perakende): **ciro ×1,468 · adet ×1,247**.
Ekim-Aralık sezon sonrası → takvim YoY (k_adet + fiyat artışı) ile kapatılır.

═══ 2. AŞAMA — 2027 ══════════════════════════════════════════════════════════
2027 adet = 2026 TAM YIL adet × hacim büyümesi (ölçülen k_adet, kırpmalı)
Mevsim  = 2026 tam yılın aylık adet payı (okul kaymasıyla birlikte)
Fiyat   = 2026 birim fiyat × aylık fiyat endeksi × senaryo çarpanı
Ciro    = satır satır adet × birim (toplamdan TÜRETİLMEZ)

═══ 3. AŞAMA — TAKVİM KATMANI (GMY isteği) ═══════════════════════════════════
⭐ BAYRAM ETKİSİ ÖLÇÜLDÜ, VARSAYILMADI — ve ham ortalama YANILTIYORDU:
  Kapalı günlerin `irsHrk`'de SATIRI YOK, dolayısıyla AVG onları saymıyor.
  Takvim günü üzerinden düzeltilince sonuç TERSİNE döndü:
      Ramazan 2025 ham ×1,95 → düzeltilmiş **×1,30**
      Ramazan 2026 ham ×1,54 → düzeltilmiş **×1,15**
      Kurban  2025 ham ×1,18 → düzeltilmiş **×0,89**
      Kurban  2026 ham ×1,06 → düzeltilmiş **×0,85**
  ⇒ **Ramazan Bayramı satışı ARTIRIYOR, Kurban Bayramı DÜŞÜRÜYOR.**
  Ham ortalamaya bakılsaydı Kurban da "artırıcı" yazılacaktı. ("Nüfus sıfırsa
  geçti değil bakamadım" sınıfı hata — `olctum-mu-cikardim-mi.md`.)
⭐ 2027'DE AY SEVİYESİNDE BAYRAM KAYMASI YOK: iki bayram da AYNI AYDA kalıyor
  (Ramazan 19-22 Mar 2026 → 8-11 Mar 2027 · Kurban 26-30 May 2026 → 15-19 May 2027)
  ve gün sayıları aynı ⇒ ay çarpanı ≈ 1. Bu bir SONUÇTUR, ihmal değil.
⚠ 19 MAYIS 2027 ÇAKIŞMASI: Kurban'ın 4. günü ile Atatürk'ü Anma AYNI GÜNE denk
  geliyor ⇒ 2026'da ayrı düşen iki tatil 2027'de üst üste biniyor, Mayıs'ta bir
  çalışma günü KAZANILIYOR. Modele giriyor.
⚠ 2027-2028 OKUL AÇILIŞI MEB'ce HENÜZ AÇIKLANMADI → 13.09.2027 (pazartesi)
  VARSAYILDI. Bu bir ÇIKARIMDIR, ölçüm değil; açıklanınca yeniden koşulmalı.

═══ SINIRLAR (ölçümden önce yazıldı) ══════════════════════════════════════════
⚠ HACİM TEK SENARYO: üç senaryo yalnız FİYATI değiştirir. Adet +%25-33 ile geliyor;
  bu hızın sürmesi garanti DEĞİL. Hacim riski ÖZET'te ayrı duyarlılık olarak yazılır.
⚠ KAPASİTE YOK: raf/metrekare/personel kısıtı modele girmiyor.
⚠ Ağustos/Eylül SINIRI ±1-2 hafta oynar: iki ayın TOPLAMI güvenilir, ayrı ayrı
  dağılımı değildir. Ağu+Eyl 2025 yılın %26'sı.
⚠ Trend + mevsim + takvim. Kampanya takvimi, rakip, tadilat, hava YOK.
⚠ Ciro KDV HARİÇtir. Kapsam üç mağaza (1 · 4477 · 4478).

⚠ pyodbc (pymssql DEĞİL): Türkçe varchar CP1254, pymssql bozar.

Kullanım:
    python scripts/tahmin_2027_sube_kategori.py
    python scripts/tahmin_2027_sube_kategori.py --dusuk 5 --orta 12 --yuksek 20
Çıkış: 0 dosya yazıldı · 2 KOŞAMADI (bağlantı/şema/boş sonuç — sessizlik kanıt değil).
"""
from __future__ import annotations

import argparse
import datetime as dt
import io
import os
import re
import sys
from collections import defaultdict

import pyodbc
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASLIK_DOLGU = PatternFill("solid", fgColor="1F3864")

MEKAN_AD = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu"}
AY_AD = ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
         "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

# ÖLÇÜLDÜ (sema: sezon_ciro_tahmini_okul_hizali § okul_acilis_olculdu).
# 2027 AÇIKLANMADI → varsayım, Excel'de ÇIKARIM diye işaretli.
OKUL_ACILIS = {2024: dt.date(2024, 9, 9), 2025: dt.date(2025, 9, 8),
               2026: dt.date(2026, 9, 14), 2027: dt.date(2027, 9, 13)}
OKUL_2027_VARSAYIM = True

# Dini bayramlar (web'den doğrulandı 13.09.2026). (ad, ilk_gun, son_gun) — arefe dahil.
BAYRAM = {
    2025: [("ramazan", dt.date(2025, 3, 30), dt.date(2025, 4, 1)),
           ("kurban", dt.date(2025, 6, 6), dt.date(2025, 6, 9))],
    2026: [("ramazan", dt.date(2026, 3, 19), dt.date(2026, 3, 22)),
           ("kurban", dt.date(2026, 5, 26), dt.date(2026, 5, 30))],
    2027: [("ramazan", dt.date(2027, 3, 8), dt.date(2027, 3, 11)),
           ("kurban", dt.date(2027, 5, 15), dt.date(2027, 5, 19))],
}
# ÖLÇÜLEN gün ağırlıkları (takvim günü düzeltilmiş, iki yılın ortalaması)
BAYRAM_AGIRLIK = {"ramazan": 1.22, "kurban": 0.87}

# Resmî (dini olmayan) tatiller — mağaza açık ama trafiği farklı; gün SAYISI için.
RESMI_TATIL = {
    2026: [(1, 1), (4, 23), (5, 1), (5, 19), (7, 15), (8, 30), (10, 29)],
    2027: [(1, 1), (4, 23), (5, 1), (5, 19), (7, 15), (8, 30), (10, 29)],
}

BUYUME_ALT, BUYUME_UST = 0.70, 1.60
ASGARI_TABAN_ADET = 200


def kosamadi(mesaj: str) -> None:
    print(f"KOSAMADI: {mesaj}", file=sys.stderr)
    raise SystemExit(2)


def env_oku(yol: str) -> dict:
    if not os.path.exists(yol):
        kosamadi(f".env bulunamadi: {yol}")
    env = {}
    with open(yol, encoding="utf-8") as f:
        for ln in f:
            if ln.lstrip().startswith("#"):
                continue
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
            if m:
                env[m.group(1)] = m.group(2).strip().strip('"')
    return env


def baglan(env: dict) -> pyodbc.Connection:
    host, port = env.get("MSSQL_HOST", ""), env.get("MSSQL_PORT", "1433")
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
        kosamadi("Gecersiz MSSQL_HOST/MSSQL_PORT (.env)")
    for anahtar in ("MSSQL_USER", "MSSQL_PASSWORD"):
        if not env.get(anahtar):
            kosamadi(f"{anahtar} .env'de yok — sessizce bos sifreyle baglanilmaz")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30", timeout=30)
    cn.timeout = 900
    return cn


SQL_GUNLUK = """
SELECT CAST(h.ehTrhS AS date) AS Gun, h.ehMekan AS Mekan, b.Kategori3 AS Kategori,
       SUM(CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN ELSE -h.ehTutarN END) AS Ciro,
       SUM(CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN) ELSE -ABS(h.ehAdetN) END) AS Adet
FROM   dbo.irsHrk h WITH (NOLOCK)
JOIN   bkm.UrunBilgi b WITH (NOLOCK) ON b.stkID = h.ehstkID
WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
   AND h.ehTrhS >= '20240101' AND h.ehTrhS <= ?
   AND ((? = 1 AND b.KatAna NOT LIKE 'Sınav Okul%')
     OR (? = 0 AND b.KatAna     LIKE 'Sınav Okul%'))
GROUP BY CAST(h.ehTrhS AS date), h.ehMekan, b.Kategori3
"""


def son_tam_gun(cn) -> dt.date:
    """Bugünün eTip 100 belgesi gün içinde yeniden yazılır → son TAM gün esas."""
    cur = cn.cursor()
    cur.execute("SELECT MAX(CAST(ehTrhS AS date)) FROM dbo.irsHrk WITH (NOLOCK) "
                "WHERE ehTip IN (100,101,4,5)")
    r = cur.fetchone()
    if not r or not r[0]:
        kosamadi("irsHrk'de satis hareketi yok")
    son = r[0] if isinstance(r[0], dt.date) else r[0].date()
    return son - dt.timedelta(days=1)


def cek(cn, bitis: dt.date, sinav_haric: bool) -> list:
    cur = cn.cursor()
    bay = 1 if sinav_haric else 0
    cur.execute(SQL_GUNLUK, bitis, bay, bay)
    rows = [((r.Gun if isinstance(r.Gun, dt.date) else r.Gun.date()),
             int(r.Mekan), (r.Kategori or "Tanımsız"),
             float(r.Ciro or 0), float(r.Adet or 0)) for r in cur.fetchall()]
    if not rows:
        kosamadi(f"Gunluk taban BOS (sinav_haric={sinav_haric})")
    return rows


def ofset(g: dt.date) -> int:
    return (g - OKUL_ACILIS[g.year]).days


def olc_k(gunluk, kesim: dt.date):
    """Okul-hizalı büyüme çarpanı: T−29..T−2 penceresi, 2026 / 2025."""
    alt, ust = -29, ofset(kesim)          # kesim = son tam gün (T−2 civarı)
    top = {2025: [0.0, 0.0], 2026: [0.0, 0.0]}
    for g, _m, _k, c, a in gunluk:
        if g.year in top and alt <= ofset(g) <= ust:
            top[g.year][0] += c
            top[g.year][1] += a
    if top[2025][1] <= 0:
        kosamadi("Hizali pencerede 2025 adedi sifir — k olculemez")
    return (top[2026][0] / top[2025][0], top[2026][1] / top[2025][1], alt, ust)


def bayram_agirlik(g: dt.date) -> float:
    for ad, bas, bit in BAYRAM.get(g.year, []):
        if bas <= g <= bit:
            return BAYRAM_AGIRLIK[ad]
    return 1.0


def ay_takvim_carpani(yil_yeni: int, yil_eski: int) -> dict:
    """Her ay için 'etkin gün' oranı. Bayram günleri ölçülen ağırlıkla sayılır."""
    def etkin(yil):
        d = defaultdict(float)
        g = dt.date(yil, 1, 1)
        while g.year == yil:
            d[g.month] += bayram_agirlik(g)
            g += dt.timedelta(days=1)
        return d
    y, e = etkin(yil_yeni), etkin(yil_eski)
    return {a: (y[a] / e[a] if e[a] else 1.0) for a in range(1, 13)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dusuk", type=float, default=9.0)
    ap.add_argument("--orta", type=float, default=18.0)
    ap.add_argument("--yuksek", type=float, default=28.0)
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()
    if not (a.dusuk <= a.orta <= a.yuksek):
        kosamadi("Senaryolar sirali olmali")
    SEN = {"dusuk": 1 + a.dusuk / 100, "orta": 1 + a.orta / 100,
           "yuksek": 1 + a.yuksek / 100}

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        kesim = son_tam_gun(cn)
        per = cek(cn, kesim, True)
        snv = cek(cn, kesim, False)
    finally:
        cn.close()

    k_ciro, k_adet, ofs_alt, ofs_ust = olc_k(per, kesim)

    # ── 1) 2026 KAPANIŞI ─────────────────────────────────────────────────────
    # Gerçekleşen (kesime kadar) + Eylül kalanı (okul-hizalı) + Eki-Ara (YoY).
    ger26 = defaultdict(lambda: [0.0, 0.0])          # (ay,mek,ktg) -> [ciro,adet]
    ger25_gun = defaultdict(lambda: [0.0, 0.0])      # (gun,mek,ktg)
    ay25 = defaultdict(lambda: [0.0, 0.0])           # (ay,mek,ktg) 2025 tam
    for g, mek, ktg, c, ad in per:
        if g.year == 2026:
            ger26[(g.month, mek, ktg)][0] += c
            ger26[(g.month, mek, ktg)][1] += ad
        elif g.year == 2025:
            ger25_gun[(g, mek, ktg)][0] += c
            ger25_gun[(g, mek, ktg)][1] += ad
            ay25[(g.month, mek, ktg)][0] += c
            ay25[(g.month, mek, ktg)][1] += ad

    kapanis26 = defaultdict(lambda: [0.0, 0.0])
    for anahtar, v in ger26.items():
        kapanis26[anahtar][0] += v[0]
        kapanis26[anahtar][1] += v[1]

    # Eylül kalanı: kesim+1 .. 30.09.2026, her günü 2025'in AYNI OFSETİNE eşle.
    g = kesim + dt.timedelta(days=1)
    eylul_kalan_gun = 0
    while g <= dt.date(2026, 9, 30):
        o = ofset(g)
        esdeger = OKUL_ACILIS[2025] + dt.timedelta(days=o)
        for (g25, mek, ktg), v in ger25_gun.items():
            if g25 == esdeger:
                kapanis26[(9, mek, ktg)][0] += v[0] * k_ciro
                kapanis26[(9, mek, ktg)][1] += v[1] * k_adet
        eylul_kalan_gun += 1
        g += dt.timedelta(days=1)

    # Ekim-Aralık: sezon sonrası → takvim YoY.
    for ay in (10, 11, 12):
        for (a25, mek, ktg), v in ay25.items():
            if a25 == ay:
                kapanis26[(ay, mek, ktg)][0] += v[0] * k_ciro
                kapanis26[(ay, mek, ktg)][1] += v[1] * k_adet

    # ── 2) 2027 ──────────────────────────────────────────────────────────────
    tk = ay_takvim_carpani(2027, 2026)
    yil26 = defaultdict(lambda: [0.0, 0.0])          # (mek,ktg)
    for (ay, mek, ktg), v in kapanis26.items():
        yil26[(mek, ktg)][0] += v[0]
        yil26[(mek, ktg)][1] += v[1]
    gen_adet26 = sum(v[1] for v in yil26.values())
    gen_adet25 = sum(v[1] for v in ay25.values())
    genel_buyume = (gen_adet26 / gen_adet25) if gen_adet25 else 1.0

    satirlar, notlar = [], []
    for (mek, ktg), (c26, a26) in sorted(yil26.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        if a26 <= 0 or c26 <= 0:
            continue
        birim26 = c26 / a26
        a25_top = sum(v[1] for (ay, m, k), v in ay25.items() if m == mek and k == ktg)
        isaret = ""
        if a25_top < ASGARI_TABAN_ADET:
            buyume, isaret = genel_buyume, "taban küçük → genel büyüme"
        else:
            buyume = a26 / a25_top
            if buyume < BUYUME_ALT:
                buyume, isaret = BUYUME_ALT, f"kırpıldı (ölçülen {a26/a25_top:.2f})"
            elif buyume > BUYUME_UST:
                buyume, isaret = BUYUME_UST, f"kırpıldı (ölçülen {a26/a25_top:.2f})"

        yil_adet27 = a26 * buyume
        aylik = {ay: kapanis26[(ay, mek, ktg)][1] for ay in range(1, 13)}
        pay_top = sum(aylik.values())
        if pay_top <= 0:
            aylik = {ay: 1.0 for ay in range(1, 13)}
            pay_top = 12.0
            isaret = (isaret + " · mevsim yok, düz dağıtıldı").strip(" ·")

        for ay in range(1, 13):
            adet = yil_adet27 * (aylik[ay] / pay_top) * tk[ay]
            ac, aa = kapanis26[(ay, mek, ktg)]
            endeks = ((ac / aa) / birim26) if aa > 0 and birim26 > 0 else 1.0
            s = {"mekan": MEKAN_AD.get(mek, str(mek)), "kategori": ktg, "ay": ay,
                 "adet": adet, "buyume": buyume, "takvim": tk[ay], "isaret": isaret}
            for ad_s, carp in SEN.items():
                b = birim26 * endeks * carp
                s[f"birim_{ad_s}"] = b
                s[f"ciro_{ad_s}"] = adet * b
            satirlar.append(s)
        if isaret:
            notlar.append((MEKAN_AD.get(mek, str(mek)), ktg, isaret))

    if not satirlar:
        kosamadi("Model hic satir uretmedi")

    # ── EXCEL ────────────────────────────────────────────────────────────────
    def yaz(ws, basliklar, rows, gen=None, para=()):
        ws.append(basliklar)
        for c in range(1, len(basliklar) + 1):
            h = ws.cell(row=1, column=c)
            h.font = Font(bold=True, color="FFFFFF")
            h.fill = BASLIK_DOLGU
            h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        for r in rows:
            ws.append(r)
        for i, w in enumerate(gen or [], start=1):
            ws.column_dimensions[get_column_letter(i)].width = w
        for c in para:
            for r in range(2, ws.max_row + 1):
                ws.cell(row=r, column=c).number_format = "#,##0"
        ws.freeze_panes = "A2"

    wb = Workbook()
    t27 = {s_ad: sum(s[f"ciro_{s_ad}"] for s in satirlar) for s_ad in SEN}
    c26_top = sum(v[0] for v in kapanis26.values())
    a26_top = sum(v[1] for v in kapanis26.values())
    c25_top = sum(v[0] for v in ay25.values())

    ws = wb.active
    ws.title = "ÖZET"
    rows = [
        ["2025 GERÇEKLEŞEN (perakende, KDV hariç)", round(c25_top), round(gen_adet25)],
        [f"2026 KAPANIŞ (Oca-{AY_AD[kesim.month]} {kesim.day} gerçek + kalanı tahmin)",
         round(c26_top), round(a26_top)],
        ["2026 / 2025 ciro", f"{c26_top/c25_top:.3f}" if c25_top else "", ""],
        ["2026 / 2025 adet", f"{genel_buyume:.3f}", ""],
        # 2027 bu tabanın üstüne kuruluyor; tabanın ne kadarının TAHMİN olduğu
        # başlıkta durmazsa okuyucu 2026'yı "bilinen" sanır. Bilinmiyor.
        [f"⚠ 2026 kapanışının {100*sum(v[0] for v in ger26.values())/c26_top:.0f}%'i GERÇEKLEŞEN, "
         f"{100*(1-sum(v[0] for v in ger26.values())/c26_top):.0f}%'i TAHMİN",
         round(sum(v[0] for v in ger26.values())), ""],
        ["⚠ 2027, bu KISMEN TAHMİN tabanın üstüne kuruluyor — hata birikir.", "", ""], [],
        ["2027 TAHMİN — üç fiyat senaryosu", "", ""],
        [f"  DÜŞÜK  (+%{a.dusuk:g} birim fiyat)", round(t27["dusuk"]), ""],
        [f"  ORTA   (+%{a.orta:g} birim fiyat)", round(t27["orta"]), ""],
        [f"  YÜKSEK (+%{a.yuksek:g} birim fiyat)", round(t27["yuksek"]), ""], [],
        ["ŞUBE KIRILIMI (2027)", "Ciro ORTA ₺", "Adet"],
    ]
    sube = defaultdict(lambda: defaultdict(float))
    for s in satirlar:
        sube[s["mekan"]]["adet"] += s["adet"]
        for k_ in SEN:
            sube[s["mekan"]][f"ciro_{k_}"] += s[f"ciro_{k_}"]
    for mek in sorted(sube):
        rows.append([f"  {mek}", round(sube[mek]["ciro_orta"]), round(sube[mek]["adet"])])
    ort_sube = sum(v["ciro_orta"] for v in sube.values()) / max(len(sube), 1)
    rows += [
        [],
        ["HACİM DUYARLILIĞI — ⚠ ÜÇ SENARYONUN DIŞINDA, ASIL BELİRSİZLİK BURADA", "", ""],
        [f"  Model adedin +%{(genel_buyume-1)*100:.0f} büyümeye devam ettiğini varsayar.", "", ""],
        ["  Hacim büyümesi YARIYA inerse (orta fiyat)",
         round(t27["orta"] * (1 + (genel_buyume - 1) / 2) / genel_buyume), ""],
        ["  Hacim 2026 seviyesinde SABİT kalırsa (orta fiyat)",
         round(t27["orta"] / genel_buyume), ""],
        ["  ⚠ Hacim sabit kalırsa ciro, üç fiyat senaryosunun EN DÜŞÜĞÜNÜN de altına iner.", "", ""],
        [],
        ["YENİ ŞUBE DUYARLILIĞI (GMY: belirsiz → ikisi de gösterilsin)", "", ""],
        ["  Ortalama bir şubenin 2027 cirosu (orta senaryo)", round(ort_sube), ""],
        ["  ⚠ TAM YIL + OLGUN varsayımı. Açılış ayı ve rampa yoktur; ilk yıl bunun ALTINDA kalır.", "", ""],
    ]
    yaz(ws, ["Kalem", "Ciro ₺ (KDV hariç)", "Adet"], rows, [62, 22, 16], (2, 3))

    ws = wb.create_sheet("2026 KAPANIŞ")
    rows = []
    for (ay, mek, ktg), v in sorted(kapanis26.items()):
        ger = ger26.get((ay, mek, ktg), [0.0, 0.0])
        tip = "gerçekleşen" if ay < kesim.month else (
            "gerçek+tahmin" if ay == kesim.month else "TAHMİN")
        rows.append([ay, AY_AD[ay], MEKAN_AD.get(mek, str(mek)), ktg, tip,
                     round(v[1]), round(v[0] / v[1], 2) if v[1] else 0, round(v[0]),
                     round(ger[0])])
    yaz(ws, ["Ay No", "Ay", "Şube", "Kategori", "Tip", "Adet", "Birim ₺", "Ciro ₺",
             "bunun gerçekleşeni ₺"], rows, [7, 11, 11, 20, 14, 12, 12, 16, 18], (6, 8, 9))

    ws = wb.create_sheet("2027 AY x ŞUBE")
    ags = defaultdict(lambda: defaultdict(float))
    for s in satirlar:
        ags[(s["ay"], s["mekan"])]["adet"] += s["adet"]
        for k_ in SEN:
            ags[(s["ay"], s["mekan"])][f"ciro_{k_}"] += s[f"ciro_{k_}"]
    rows = []
    for (ay, mek) in sorted(ags):
        v = ags[(ay, mek)]
        rows.append([ay, AY_AD[ay], mek, round(v["adet"]),
                     round(v["ciro_orta"] / v["adet"], 2) if v["adet"] else 0,
                     round(v["ciro_dusuk"]), round(v["ciro_orta"]), round(v["ciro_yuksek"]),
                     round(tk[ay], 4)])
    yaz(ws, ["Ay No", "Ay", "Şube", "Adet", "Birim ₺ (orta)", "Ciro DÜŞÜK ₺",
             "Ciro ORTA ₺", "Ciro YÜKSEK ₺", "Takvim çarpanı"],
        rows, [7, 11, 11, 12, 15, 17, 17, 17, 14], (4, 6, 7, 8))

    ws = wb.create_sheet("2027 AY x ŞUBE x KATEGORİ")
    rows = []
    for s in sorted(satirlar, key=lambda x: (x["ay"], x["mekan"], -x["ciro_orta"])):
        rows.append([s["ay"], AY_AD[s["ay"]], s["mekan"], s["kategori"], round(s["adet"]),
                     round(s["birim_orta"], 2), round(s["ciro_dusuk"]), round(s["ciro_orta"]),
                     round(s["ciro_yuksek"]), round(s["buyume"], 3), round(s["takvim"], 4),
                     s["isaret"]])
    yaz(ws, ["Ay No", "Ay", "Şube", "Kategori", "Adet", "Birim ₺ (orta)", "Ciro DÜŞÜK ₺",
             "Ciro ORTA ₺", "Ciro YÜKSEK ₺", "Hacim büyüme", "Takvim çarpanı", "Not"],
        rows, [7, 11, 11, 20, 11, 14, 16, 16, 16, 13, 13, 28], (5, 7, 8, 9))

    ws = wb.create_sheet("SINAV (AYRI)")
    sn = defaultdict(lambda: [0.0, 0.0])
    for g, _m, _k, c, ad in snv:
        sn[g.year][0] += c
        sn[g.year][1] += ad
    rows = [["⚠ GMY kararı: Sınav AYRI TUTULDU, tahmine KARIŞTIRILMADI.", "", "", ""],
            ["Sebep: adet iki yılda yarıya indi, ciroyu fiyat taşıyor — perakendeyle", "", "", ""],
            ["aynı model geçerli değil. Aşağısı GERÇEKLEŞEN, tahmin DEĞİL.", "", "", ""],
            ["", "", "", ""], ["Yıl", "Ciro ₺ (KDV hariç)", "Adet", "Birim ₺"]]
    for y in sorted(sn):
        c, ad = sn[y]
        rows.append([y, round(c), round(ad), round(c / ad, 2) if ad else 0])
    rows.append(["", "", "", ""])
    rows.append([f"⚠ {kesim.year} KISMİDİR — son tam gün {kesim}.", "", "", ""])
    yaz(ws, ["Sınav Okulları — GERÇEKLEŞEN (ürün bazlı: KatAna LIKE 'Sınav Okul%')",
             "", "", ""], rows, [52, 22, 16, 14])

    ws = wb.create_sheet("YÖNTEM & SINIRLAR")
    y = [
        ["2026 KAPANIŞ + 2027 TAHMİN — YÖNTEM VE SINIRLAR"], [],
        ["Kaynak", "DerinSIS dbo.irsHrk · kanonik ciro eTip 100−101+4−5 · KDV HARİÇ"],
        ["Kapsam", "FSM (1) · Özlüce (4477) · İst.Yolu (4478)"],
        ["Sınav ayrımı", "ÜRÜN BAZLI (KatAna LIKE 'Sınav Okul%') — belge bazlıdan FARKLI"],
        ["Son tam gün", str(kesim) + "  (bugünün eTip 100 belgesi gün içinde yeniden yazılır)"],
        [], ["1. AŞAMA — 2026 KAPANIŞI"],
        ["⚠ EYLÜL TAKVİMLE KAPATILMADI", "Okul açılışı kayan yılda takvim tahmini yanıltır."],
        ["Ölçülen açılışlar", "2024: 09.09 · 2025: 08.09 · 2026: 14.09 → 2026'da 6 GÜN GEÇ"],
        ["13.09.2026 durumu", "okul HENÜZ AÇILMAMIŞ (T−1). 2025'te aynı gün 5 gündür açıktı."],
        ["Yöntem", f"günler okul açılışına hizalandı; k, T{ofs_alt}..T{ofs_ust} penceresinden ölçüldü"],
        ["ÖLÇÜLEN k", f"ciro ×{k_ciro:.3f} · adet ×{k_adet:.3f}"],
        ["Eylül kalanı", f"{eylul_kalan_gun} gün, 2025'in AYNI OFSETLERİ × k"],
        ["Ekim-Aralık", "sezon sonrası → takvim YoY (× k)"],
        [], ["2. AŞAMA — 2027"],
        ["Adet", "2026 tam yıl adet × hacim büyümesi (0,70-1,60 kırpmalı)"],
        ["Mevsim", "2026 tam yılın aylık adet payı"],
        ["Fiyat", "2026 birim × aylık fiyat endeksi × senaryo"],
        ["Ciro", "satır satır adet × birim (toplamdan TÜRETİLMEZ)"],
        [], ["3. AŞAMA — TAKVİM KATMANI"],
        ["⭐ BAYRAM ÖLÇÜLDÜ", "ham AVG YANILTIYORDU: kapalı günün irsHrk'de SATIRI YOK,"],
        ["", "AVG onları saymıyor. Takvim günü düzeltmesiyle sonuç TERSİNE döndü:"],
        ["", "Ramazan 2025 ×1,95→1,30 · 2026 ×1,54→1,15 (ARTIRIYOR)"],
        ["", "Kurban  2025 ×1,18→0,89 · 2026 ×1,06→0,85 (DÜŞÜRÜYOR)"],
        ["Kullanılan ağırlık", f"ramazan {BAYRAM_AGIRLIK['ramazan']} · kurban {BAYRAM_AGIRLIK['kurban']}"],
        ["⭐ 2027'de ay kayması YOK", "Ramazan 19-22 Mar 2026 → 8-11 Mar 2027 (aynı ay)"],
        ["", "Kurban 26-30 May 2026 → 15-19 May 2027 (aynı ay) ⇒ ay çarpanı ≈ 1"],
        ["⚠ 19 Mayıs 2027", "Kurban 4. günü ile Atatürk'ü Anma ÇAKIŞIYOR → Mayıs'ta bir"],
        ["", "çalışma günü kazanılıyor. Modele girdi."],
        ["⚠ OKUL 2027 ÇIKARIM", "2027-2028 takvimi MEB'ce AÇIKLANMADI. 13.09.2027 VARSAYILDI."],
        ["", "Bu ÖLÇÜM DEĞİL. Takvim açıklanınca yeniden koşulmalı."],
        [], ["SINIRLAR"],
        ["HACİM RİSKİ YOK", "Üç senaryo yalnız FİYATI değiştirir; hacim tek varsayım."],
        ["KAPASİTE YOK", "Raf/metrekare/personel kısıtı modelde yok."],
        ["AĞU/EYL SINIRI", "±1-2 hafta oynar: iki ayın TOPLAMI güvenilir, ayrımı değil."],
        ["MODEL SINIRI", "Trend + mevsim + takvim. Kampanya, rakip, tadilat, hava YOK."],
        ["KDV", "KDV HARİÇ. KDV dahil raporlarla yan yana konmaz."],
        [], ["İŞARETLENEN SATIRLAR"],
    ]
    for mek, ktg, nt in notlar:
        y.append([mek, ktg, nt])
    if not notlar:
        y.append(["(yok)"])
    yaz(ws, ["", "", ""], y, [26, 62, 40])

    cikti = a.cikti or os.path.join(KOK, "raporlar", "2027-tahmin-ay-sube-kategori.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)
    print(f"YAZILDI: {cikti}")
    print(f"  son tam gun: {kesim} · k_ciro {k_ciro:.3f} · k_adet {k_adet:.3f}")
    print(f"  2025 gercek : {c25_top:>15,.0f} TL")
    print(f"  2026 kapanis: {c26_top:>15,.0f} TL  ({c26_top/c25_top:.3f}x)")
    for s_ad in ("dusuk", "orta", "yuksek"):
        print(f"  2027 {s_ad.upper():>6}: {t27[s_ad]:>15,.0f} TL  "
              f"({t27[s_ad]/c26_top:.3f}x)")
    print(f"  satir {len(satirlar)} · isaretli {len(notlar)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
