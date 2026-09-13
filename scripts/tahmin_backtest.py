# -*- coding: utf-8 -*-
"""TAHMİN MODELİ GERİYE DÖNÜK SINAMA (rolling-origin backtest).

Doğuş sebebi 13.09.2026 (GMY): _"bilimsel olarak yapıyorsun değil mi, bununla ilgili
literatür çalışmalar vs araştırma yaptın mı"_.

DÜRÜST CEVAP: `tahmin_2027_sube_kategori.py` yazıldığında literatür taranmadı ve
model HİÇ SINANMADI. Bu script o boşluğu kapatır.

═══ LİTERATÜRÜN DAYATTIĞI İKİ ŞART ════════════════════════════════════════════
1) **TEMEL ÇİZGİYİ GEÇMEK ZORUNLUDUR.** M5 yarışmasında 5.507 takımın yalnız
   **%35,8'i** seasonal-naive (sNaive) temel çizgisini geçebildi. Yani sNaive güçlü
   bir rakiptir; onu geçmeyen bir model karmaşıklığını HAK ETMEZ.
   (Makridakis/Spiliotis/Assimakopoulos, M5 Accuracy competition, IJF 2022.)
2) **ÖLÇEKTEN BAĞIMSIZ, ÖLÇEKLENMİŞ HATA.** MAPE sıfıra yakın ve değişken ölçekli
   serilerde patlar. Hyndman & Koehler (2006) MASE'i bu yüzden önerir; M5 onun
   karesel kardeşi RMSSE'yi kullanır. Burada **MASE** raporlanır.

═══ YÖNTEM ════════════════════════════════════════════════════════════════════
Rolling origin: iki ayrı kesim noktasından geleceğe bakılır ve GERÇEKLE kıyaslanır.
   Kesim 2023-12-31 → 2024 tahmin edilir → 2024 gerçeğiyle kıyas
   Kesim 2024-12-31 → 2025 tahmin edilir → 2025 gerçeğiyle kıyas
Kesimden SONRAKİ hiçbir bilgi kullanılmaz (sızıntı yok) — fiyat artışı bile yalnız
kesime kadarki veriden ölçülür.

Yarışan dört yöntem (hepsi ay × şube × kategori grain'inde):
   sNaive        : gelecek yıl = geçen yılın AYNI ayı (literatürün temel çizgisi)
   sNaive+drift  : sNaive × genel ciro büyümesi (tek katsayı)
   BİZİM MODEL   : adet × birim fiyat ayrık (hacim büyümesi + mevsim payı + fiyat)
   BİZİM (kırpsız): aynı model, 0,70-1,60 kırpması KAPALI — kırpmanın katkısı ölçülür

═══ MASE ══════════════════════════════════════════════════════════════════════
   MASE = ortalama|tahmin − gerçek| ÷ ortalama|sNaive hatası (EĞİTİM döneminde)|
   MASE < 1 → eğitim dönemindeki sNaive'den iyi · > 1 → daha kötü.
⚠ Ölçek, kesimden ÖNCEKİ dönemin sNaive hatasıdır (test döneminin DEĞİL) —
  aksi hâlde ölçek test verisinden sızar.

⚠ SINIR: iki kesim noktası AZ. Literatür daha çok origin ister; 2022'den beri
  yalnız 5 yıl veri var ve ilk yıllar POS öncesi. Bu yüzden sonuç YÖN gösterir,
  kesin hata payı VERMEZ.
⚠ SINIR: 2024 ve 2025 çok yüksek enflasyon yıllarıdır. Bir yöntemin burada iyi
  çıkması, düşük enflasyonda da iyi olacağı anlamına GELMEZ.

⚠ pyodbc (pymssql DEĞİL): Türkçe varchar CP1254, pymssql bozar.

Kullanım: python scripts/tahmin_backtest.py
Çıkış: 0 sınandı · 2 KOŞAMADI.
"""
from __future__ import annotations

import io
import os
import re
import sys
from collections import defaultdict

import pyodbc

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUYUME_ALT, BUYUME_UST = 0.70, 1.60
ASGARI_TABAN_ADET = 200


def kosamadi(m: str):
    print(f"KOSAMADI: {m}", file=sys.stderr)
    raise SystemExit(2)


def env_oku(yol):
    if not os.path.exists(yol):
        kosamadi(f".env yok: {yol}")
    env = {}
    with open(yol, encoding="utf-8") as f:
        for ln in f:
            if ln.lstrip().startswith("#"):
                continue
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
            if m:
                env[m.group(1)] = m.group(2).strip().strip('"')
    return env


def baglan(env):
    host, port = env.get("MSSQL_HOST", ""), env.get("MSSQL_PORT", "1433")
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
        kosamadi("Gecersiz MSSQL_HOST/PORT")
    for k in ("MSSQL_USER", "MSSQL_PASSWORD"):
        if not env.get(k):
            kosamadi(f"{k} .env'de yok")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30", timeout=30)
    cn.timeout = 900
    return cn


SQL = """
SELECT YEAR(h.ehTrhS) AS Yil, MONTH(h.ehTrhS) AS Ay, h.ehMekan AS Mekan,
       b.Kategori3 AS Kategori,
       SUM(CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN ELSE -h.ehTutarN END) AS Ciro,
       SUM(CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN) ELSE -ABS(h.ehAdetN) END) AS Adet
FROM   dbo.irsHrk h WITH (NOLOCK)
JOIN   bkm.UrunBilgi b WITH (NOLOCK) ON b.stkID = h.ehstkID
WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
   AND h.ehTrhS >= '20220101' AND h.ehTrhS < '20260101'
   AND b.KatAna NOT LIKE 'Sınav Okul%'
GROUP BY YEAR(h.ehTrhS), MONTH(h.ehTrhS), h.ehMekan, b.Kategori3
"""


def yil_top(d, yil, idx):
    return sum(v[idx] for (y, _a, _m, _k), v in d.items() if y == yil)


def tahmin_et(d, kesim_yil, kirp: bool):
    """Kesim yılına kadarki veriyle kesim_yil+1'i tahmin et. Sızıntı yok."""
    hedef = kesim_yil + 1
    onceki = kesim_yil - 1

    gen_a_k = yil_top(d, kesim_yil, 1)
    gen_a_o = yil_top(d, onceki, 1)
    genel_buyume = (gen_a_k / gen_a_o) if gen_a_o else 1.0

    gen_c_k, gen_c_o = yil_top(d, kesim_yil, 0), yil_top(d, onceki, 0)
    birim_k = gen_c_k / gen_a_k if gen_a_k else 0
    birim_o = gen_c_o / gen_a_o if gen_a_o else 0
    fiyat_buyume = (birim_k / birim_o) if birim_o else 1.0

    # (mekan,kategori) yıl toplamları
    yk = defaultdict(lambda: [0.0, 0.0])
    yo = defaultdict(lambda: [0.0, 0.0])
    for (y, _a, m, k), v in d.items():
        if y == kesim_yil:
            yk[(m, k)][0] += v[0]
            yk[(m, k)][1] += v[1]
        elif y == onceki:
            yo[(m, k)][0] += v[0]
            yo[(m, k)][1] += v[1]

    out = {}
    for (m, k), (c_k, a_k) in yk.items():
        if a_k <= 0 or c_k <= 0:
            continue
        birim = c_k / a_k
        a_o = yo.get((m, k), [0.0, 0.0])[1]
        if a_o < ASGARI_TABAN_ADET:
            buyume = genel_buyume
        else:
            buyume = a_k / a_o
            if kirp:
                buyume = max(BUYUME_ALT, min(BUYUME_UST, buyume))
        yil_adet = a_k * buyume

        # mevsim payı: kesim ve önceki yılın ortalama aylık adet payı
        paylar = {}
        for yy, agirlik in ((kesim_yil, 0.5), (onceki, 0.5)):
            tot = sum(d.get((yy, a, m, k), [0, 0])[1] for a in range(1, 13))
            if tot > 0:
                for a in range(1, 13):
                    paylar[a] = paylar.get(a, 0.0) + agirlik * d.get((yy, a, m, k), [0, 0])[1] / tot
        ptop = sum(paylar.values())
        if ptop <= 0:
            paylar = {a: 1 / 12 for a in range(1, 13)}
            ptop = 1.0

        for a in range(1, 13):
            adet = yil_adet * paylar.get(a, 0.0) / ptop
            ac, aa = d.get((kesim_yil, a, m, k), [0.0, 0.0])
            endeks = ((ac / aa) / birim) if aa > 0 and birim > 0 else 1.0
            out[(hedef, a, m, k)] = adet * birim * endeks * fiyat_buyume
    return out


def snaive(d, kesim_yil, drift=1.0):
    hedef = kesim_yil + 1
    return {(hedef, a, m, k): v[0] * drift
            for (y, a, m, k), v in d.items() if y == kesim_yil and v[0] > 0}


def mase_olcek(d, kesim_yil):
    """Ölçek = EĞİTİM dönemindeki sNaive hatası. Test verisinden SIZMAZ."""
    hatalar = []
    for (y, a, m, k), v in d.items():
        if y == kesim_yil:
            onc = d.get((y - 1, a, m, k), [0.0, 0.0])[0]
            if onc > 0 or v[0] > 0:
                hatalar.append(abs(v[0] - onc))
    return (sum(hatalar) / len(hatalar)) if hatalar else 0.0


def degerlendir(tahmin, d, hedef_yil, olcek):
    anahtarlar = set(tahmin) | {(y, a, m, k) for (y, a, m, k) in d if y == hedef_yil}
    mutlak, ger_top, tah_top, n = 0.0, 0.0, 0.0, 0
    for key in anahtarlar:
        t = tahmin.get(key, 0.0)
        g = d.get(key, [0.0, 0.0])[0]
        if g <= 0 and t <= 0:
            continue
        mutlak += abs(t - g)
        ger_top += g
        tah_top += t
        n += 1
    mae = mutlak / n if n else 0.0
    return {
        "MASE": (mae / olcek) if olcek else float("nan"),
        "MAE": mae,
        "yil_sapma_%": 100 * (tah_top - ger_top) / ger_top if ger_top else float("nan"),
        "tahmin": tah_top, "gercek": ger_top, "n": n,
    }


def main():
    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        cur = cn.cursor()
        cur.execute(SQL)
        d = {}
        for r in cur.fetchall():
            d[(int(r.Yil), int(r.Ay), int(r.Mekan), r.Kategori or "Tanımsız")] = \
                [float(r.Ciro or 0), float(r.Adet or 0)]
    finally:
        cn.close()
    if not d:
        kosamadi("Taban BOS")

    print("=" * 78)
    print("TAHMIN MODELI GERIYE DONUK SINAMA — rolling origin, ay x sube x kategori")
    print("Olcut: MASE (Hyndman & Koehler 2006). <1 = egitim donemi sNaive'inden IYI")
    print("Literatur notu: M5'te 5.507 takimin yalniz %35,8'i sNaive'i gecebildi.")
    print("=" * 78)

    for kesim in (2023, 2024):
        hedef = kesim + 1
        olcek = mase_olcek(d, kesim)
        drift_c = (yil_top(d, kesim, 0) / yil_top(d, kesim - 1, 0)) if yil_top(d, kesim - 1, 0) else 1.0
        adaylar = {
            "sNaive (temel cizgi)": snaive(d, kesim),
            f"sNaive+drift (x{drift_c:.3f})": snaive(d, kesim, drift_c),
            "BIZIM MODEL": tahmin_et(d, kesim, kirp=True),
            "BIZIM (kirpsiz)": tahmin_et(d, kesim, kirp=False),
        }
        # Literatur: basit ORTALAMA kombinasyon cogu zaman bilesenlerinden iyidir
        # (M-yarismalarinin tekrarlanan bulgusu). Sinaniyor, varsayilmiyor.
        bizim, sn_d = adaylar["BIZIM MODEL"], adaylar[f"sNaive+drift (x{drift_c:.3f})"]
        adaylar["KOMBINASYON (bizim+drift)/2"] = {
            key: 0.5 * bizim.get(key, 0.0) + 0.5 * sn_d.get(key, 0.0)
            for key in set(bizim) | set(sn_d)
        }
        print(f"\n--- KESIM {kesim}-12-31 -> {hedef} tahmin edildi "
              f"(MASE olcegi: {olcek:,.0f} TL) ---")
        print(f"{'yontem':<30} {'MASE':>7} {'MAE TL':>12} {'yil sapmasi':>12} {'satir':>7}")
        for ad, t in adaylar.items():
            r = degerlendir(t, d, hedef, olcek)
            print(f"{ad:<30} {r['MASE']:>7.3f} {r['MAE']:>12,.0f} "
                  f"{r['yil_sapma_%']:>11.1f}% {r['n']:>7}")
        g = sum(v[0] for (y, _a, _m, _k), v in d.items() if y == hedef)
        print(f"  ({hedef} gercek toplam: {g:,.0f} TL)")

    print("\n" + "=" * 78)
    print("YORUM: MASE > 1 ise model, egitim donemindeki basit mevsimsel tekrardan")
    print("DAHA KOTU demektir. Yil sapmasi ise toplamda ne kadar sastigini gosterir;")
    print("MASE dusuk ama sapma buyukse model ayrimi tutturuyor, SEVIYEYI kaciriyordur.")
    print("=" * 78)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
