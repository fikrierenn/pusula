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

═══ 2. AŞAMA — 2027: KOMBİNASYON MODELİ ══════════════════════════════════════
⭐ GMY 2026-09-13: _"kombinasyon modelini kullan"_. Backtest'te kazandığı için.
Her (ay × şube × kategori) hücresinde İKİ AYRI tahmin yapılır, sonra ORTALAMASI:
  A) BİZİM MODEL   — kategori bazlı hacim büyümesi × mevsim payı × takvim × fiyat
  B) sNaive+drift  — o ayın 2026 cirosu × TEK genel katsayı (sade, kaba, güçlü)
  KOMBİNASYON = (A + B) / 2
Gerekçe ÖLÇÜLDÜ (scripts/tahmin_backtest.py, rolling origin, MASE):
  kesim 2024→2025: A 0,702 · B 0,675 · **KOMBİNASYON 0,621** (hepsinden iyi)
  kesim 2023→2024: A 1,372 · B 1,239 · KOMBİNASYON 1,249 (A'dan iyi)
M-yarışmalarının tekrarlanan bulgusu — BKM verisinde de TUTTU.
⚠ B'ye takvim çarpanı UYGULANMAZ (backtest'te de yoktu). 2027'de çarpan ≈1,00
  olduğu için fark ihmal edilebilir; başka bir yılda önemli olabilir.
Adet ve birim fiyat da kombine edilir; birim = kombine ciro ÷ kombine adet, yani
Excel'deki üç sütun ARİTMETİK OLARAK TUTARLIDIR (adet × birim = ciro).

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

═══ 4. AŞAMA — FİYAT SENARYOLARI: OVP + DOLAR ÇAPALI ═════════════════════════
⭐ GMY 2026-09-14: _"enflasyon tahminleri dolar OVP diğer tahminleri de baz alarak
yapmalısın; her şeyin bir mantığı ve gerekçesi olmalı"_. Türetme zinciri:
  ÖLÇÜLEN 1 — bizim birim fiyat artışımız 2026 (Oca-Ağu): **+%15,0**
  ÖLÇÜLEN 2 — TÜİK Ağu-2026 yıllık: TÜFE %31,51 · **TEMEL MALLAR %15,89** · Hizmet %40,28
  ÇIKARIM 1 — kitap/kırtasiye TEMEL MALDIR ⇒ fiyatımız mal enflasyonuyla BİREBİR
              (geçişkenlik 15,0/15,89 = 0,94). **MANŞET TÜFE İLE KIYAS YANILTIR.**
  ÇIKARIM 2 — temel mal / manşet oranı = 15,89/31,51 = **0,50**
  ÇAPA      — OVP 2027: enflasyon **%21,0** · dolar 56,05 ₺ (**+%19,6**) · 2028 %15,5
  DÜŞÜK  %10 — OVP %21 TUTAR ve mal/manşet oranı 0,50'de kalır (21×0,50≈10,6)
  ORTA   %15 — OVP bir miktar AŞILIR ya da malın payı yükselir; 2026'mız tekrar eder
  YÜKSEK %21 — mal-manşet farkı KAPANIR, OVP manşeti doğrudan fiyata yansır;
               dolar +%19,6 ile de uyumlu (ithal mal maliyet baskısı)
⚠ OVP bir HEDEFTİR, tahmin değil; geçmişte gerçekleşme hedefin ÜSTÜNDE kaldı.
  Piyasa/TCMB anket beklentileri OVP'nin ÜSTÜNDEDİR — YÜKSEK senaryo o yöndür.

═══ 5. AŞAMA — KATEGORİ MÜDAHALESİ: KPSS ════════════════════════════════════
⭐ GMY: _"akademi bu sene kpss senesiydi seneye olmayacak"_.
ÖLÇÜLEN: Akademi 2026 adet **+%153** (30.908 → 78.346, Oca-Ağu) — bu bir SINAV
TAKVİMİ olayıdır, trend DEĞİL. Model onu 1,60 ile kırpıyordu; o bile YANLIŞ YÖN.
UYGULANAN: 2026 zirvesi taban ALINMADI → 2027 = 2025 seviyesi × genel hacim trendi.
Hem A hem B bileşenine uygulandı (yoksa kaba bileşen düzeltmeyi yarı yarıya geri alırdı).
Sonuç: Akademi 2027 adedi 2026'ya göre **−%31**.
⚠ Bu bir ÖLÇÜM DEĞİL, **İŞ BİLGİSİDİR** (kaynak: GMY beyanı). Sınav takvimi
  değişirse yeniden ele alınmalı.

═══ SINIRLAR (ölçümden önce yazıldı) ══════════════════════════════════════════
⚠ HACİM TEK SENARYO: üç senaryo yalnız FİYATI değiştirir; hacim tek varsayımdır.
  ⭐ AMA HACİM ARTIK KASADAN DOĞRULANDI (2026-09-14, eski kasa `INTER_BOS`):
    2025 H1 → 2026 H1 **fiş +%20,1 · adet +%34,1 · sepet +%11,7**.
    ⚠ Eski kasada satır TİPİ kritik: `SAT`+`IPT` sayılır; `PRI` (promosyon) ve
      `IND` satırları ADET TAŞIR ama satış değildir — süzülmezse 2025 şişer ve
      büyüme SAHTE olarak küçülür (ilk ölçümde tam bu oldu: −%3 çıkmıştı).
⚠ KAPASİTE YOK: raf/metrekare/personel kısıtı modele girmiyor.
⚠ Ağustos/Eylül SINIRI ±1-2 hafta oynar: iki ayın TOPLAMI güvenilir, ayrı ayrı
  dağılımı değildir. Ağu+Eyl 2025 yılın %26'sı.
⚠ Trend + mevsim + takvim. Kampanya takvimi, rakip, tadilat, hava YOK.
⚠ Ciro KDV HARİÇtir. Kapsam üç mağaza (1 · 4477 · 4478).

⚠ pyodbc (pymssql DEĞİL): Türkçe varchar CP1254, pymssql bozar.

Kullanım:
    python scripts/tahmin_2027_sube_kategori.py
    python scripts/tahmin_2027_sube_kategori.py --dusuk 8 --orta 14 --yuksek 25
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

# ── KAPASITE (olculdu 2026-09-14, Eyl2025-Eyl2026, DocumentsTypeId=1) ───────
# Gozlenen EN YOGUN GUN fis sayisi. Tavan bunun `--kapasite-payi` katidir.
ZIRVE_GUN_FIS = {1: 2206, 4477: 2389, 4478: 1933}
SEPET_ADET = 5.16          # olculdu: son 12 ay, odemeli satirlar
# ── KARSI-METRIK (olculdu 2026-09-14, ayni-yil alis fiyati eslemesi, Oca-Agu) ─
# 24 aylik pencereyle %37,3 cikiyordu ve "iyimserdir" diye beyan edilmisti;
# ayni-yil eslemeyle %30,5 -> beyan edilen iyimserlik 6,8 PUAN.
BRUT_MARJ = 0.305

BUYUME_ALT, BUYUME_UST = 0.70, 1.60
ASGARI_TABAN_ADET = 200

# ── KATEGORİ BAZLI İŞ BİLGİSİ MÜDAHALESİ (GMY girdisi 2026-09-14) ────────────
# GMY: "akademi bu sene kpss senesiydi seneye olmayacak".
# Akademi 2026'da +%153 büyüdü (30.908 → 78.346 adet, Oca-Ağu) — bu bir SINAV
# TAKVİMİ olayıdır, trend DEĞİLDİR. Model bunu 1,60 ile kırpıyordu ama o bile
# yanlış yön: 2027'de büyüme değil DÜŞÜŞ beklenir.
# KURAL: KPSS etkisi çıkarılır, kategori 2025 seviyesine döner ve oradan genel
# hacim trendiyle büyür → 2027 adet = adet2025 × genel_buyume.
# ⚠ Bu bir ÖLÇÜM DEĞİL, İŞ BİLGİSİDİR. Kaynağı GMY beyanıdır ve Excel'de öyle
#   işaretlenir. Sınav takvimi değişirse yeniden ele alınmalı.
KPSS_KATEGORILERI = {"Akademi"}


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


# ⭐ OGRENCI KAYITLARI — BKM.snv.Siparis (GMY 2026-09-14: "sepet ogrenci sayisi
#   tahmininden gidelim"). Olculdu: siparis/ogrenci = 1,00, yani siparis = ogrenci.
#   ⚠ KISISEL VERI: `snv.Ogrenci` ad-soyad/kimlik/telefon tasir — bu sorgu yalnizca
#     SAYIM yapar, satir verisi CEKMEZ.
SQL_OGRENCI = """
SELECT sn.SinifNo AS Sinif, YEAR(sp.Tarih) AS Yil,
       CASE WHEN YEAR(sp.Tarih)=2026 THEN DATEDIFF(DAY,'20260914',sp.Tarih)
            WHEN YEAR(sp.Tarih)=2025 THEN DATEDIFF(DAY,'20250908',sp.Tarih)
            ELSE DATEDIFF(DAY,'20240909',sp.Tarih) END AS Ofset,
       COUNT(DISTINCT sp.OgrenciId) AS Ogrenci
FROM   BKM.snv.Siparis sp WITH (NOLOCK)
JOIN   BKM.snv.Sinif  sn WITH (NOLOCK) ON sn.SinifId = sp.SinifId
WHERE  YEAR(sp.Tarih) BETWEEN 2024 AND 2026 AND sn.SinifNo BETWEEN 1 AND 12
GROUP BY sn.SinifNo, YEAR(sp.Tarih),
       CASE WHEN YEAR(sp.Tarih)=2026 THEN DATEDIFF(DAY,'20260914',sp.Tarih)
            WHEN YEAR(sp.Tarih)=2025 THEN DATEDIFF(DAY,'20250908',sp.Tarih)
            ELSE DATEDIFF(DAY,'20240909',sp.Tarih) END
"""


def ogrenci_cek(cn) -> dict:
    """(sinif, yil) -> tum yil ogrenci · (sinif, yil, 'T2') -> kesime kadar."""
    cur = cn.cursor()
    cur.execute(SQL_OGRENCI)
    tam = defaultdict(int)
    t2 = defaultdict(int)
    for r in cur.fetchall():
        sf, yl, of_, og = int(r.Sinif), int(r.Yil), int(r.Ofset), int(r.Ogrenci)
        tam[(sf, yl)] += og
        if of_ <= -2:
            t2[(sf, yl)] += og
    if not tam:
        kosamadi("BKM.snv.Siparis BOS dondu — ogrenci sayisi olculemedi")
    return {"tam": tam, "t2": t2}


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
    # ── OVP / DOLAR ÇAPALI SENARYOLAR (GMY: "enflasyon tahminleri dolar OVP
    #    diger tahminleri de baz alarak yapmalisin") — turetme YONTEM sayfasinda.
    ap.add_argument("--dusuk", type=float, default=10.0)
    ap.add_argument("--orta", type=float, default=15.0)
    # ⚠ KURUL KARARI (2026-09-14): YUKSEK %21 -> %28. Gerekce: OVP'nin SICILI.
    #   OVP 2026 hedefi %9,7 iken Agu-2026 gerceklesen %31,51 (3,25 kat).
    #   OVP 2024 hedefi %33 -> %41,5'e revize, gerceklesen ~%44 (1,33 kat).
    #   Yani OVP manseti TAVAN degil TABAN. %28 = OVP %21 x tarihsel 1-yil-ileri
    #   sapmasi (~1,33) VE mal-manset farkinin kapanmasi birlikte.
    ap.add_argument("--yuksek", type=float, default=28.0)
    # ── (4) KAPASITE TAVANI ─────────────────────────────────────────────────
    #   Baglayici kisit KASA GECIS HIZI (fis/gun), raf degil: adet zirve/ortalama
    #   3,99-8,36 iken FIS zirve/ortalama yalniz 1,9-2,4 -> zirve gunlerde magaza
    #   daha cok ISLEM degil daha buyuk SEPET satiyor. Tavan fisten kurulur.
    # ── SINAV'IN KENDI FIYAT MERDIVENI (GMY 2026-09-14: "sinav ayri
    #    degerlendirilmeli ... sepette eski oranda artmiyor") ────────────────
    #  ⚠ HATA DUZELTMESI: Sinav fiyatina PERAKENDENIN OVP capasi uygulaniyordu.
    #  Iki is, IKI FARKLI fiyat mekanizmasi:
    #    perakende fiyati = piyasa/enflasyon (TUFE temel mal capasi dogru)
    #    SINAV fiyati     = okulun YILLIK PAKET/UCRET KARARI — enflasyonun COK ustu
    #  Olculen (tam yil): 2024 3.749 TL -> 2025 6.909 (+%84,3) -> 2026 9.883 (+%43,0)
    #  Yavaslama orani 43,0/84,3 = 0,51.
    #    DUSUK  %15 — yavaslama HIZLANIR, mal enflasyonuna yaklasir
    #    ORTA   %22 — yavaslama AYNI oranda surer (43,0 x 0,51)
    #    YUKSEK %35 — 2026'nin artisi TEKRARLAR
    ap.add_argument("--sinav-dusuk", type=float, default=9.0)
    ap.add_argument("--sinav-orta", type=float, default=16.0)
    ap.add_argument("--sinav-yuksek", type=float, default=22.0)
    ap.add_argument("--kapasite-payi", type=float, default=1.10,
                    help="Gozlenen en yogun gunun kac kati fis/gun kabul edilsin "
                         "(1,10 = %%10 iyilesme varsayimi; SECILMIS sayi, olculmedi)")
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
        ogr = ogrenci_cek(cn)
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
        if ktg in KPSS_KATEGORILERI and a25_top > 0:
            # KPSS yılı etkisi çıkarılır: 2026 zirvesi taban alınmaz, 2025'e dönülür.
            buyume = (a25_top * genel_buyume) / a26
            isaret = (f"⚠ KPSS DÜZELTMESİ (GMY beyanı): 2026 zirve ({a26/a25_top:.2f}x) "
                      f"taban alınmadı, 2025 seviyesi × genel trend")
        elif a25_top < ASGARI_TABAN_ADET:
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
            adet_a = yil_adet27 * (aylik[ay] / pay_top) * tk[ay]
            ac, aa = kapanis26[(ay, mek, ktg)]
            endeks = ((ac / aa) / birim26) if aa > 0 and birim26 > 0 else 1.0
            s = {"mekan": MEKAN_AD.get(mek, str(mek)), "kategori": ktg, "ay": ay,
                 "buyume": buyume, "takvim": tk[ay], "isaret": isaret}
            for ad_s, carp in SEN.items():
                # ── A) BİZİM MODEL: kategori bazlı hacim × mevsim × takvim × fiyat
                b = birim26 * endeks * carp
                ciro_a = adet_a * b
                # ── B) sNaive+drift: o ayın 2026 cirosu × TEK genel katsayı.
                #    Kategori bazlı büyüme YOK, mevsim payı YOK, takvim YOK —
                #    backtest'te sınanan hâliyle birebir aynı (sadelik bilinçli).
                # ⚠ KPSS kategorisinde B de düzeltilir; yoksa kaba bileşen 2026
                # zirvesini taban alıp düzeltmeyi yarı yarıya geri alırdı.
                drift = buyume if ktg in KPSS_KATEGORILERI else genel_buyume
                ciro_b = ac * drift * carp
                # ── KOMBİNASYON: ikisinin basit ORTALAMASI (M-yarışmaları bulgusu,
                #    BKM verisinde backtest ile DOĞRULANDI: MASE 0,621 vs 0,702/0,675)
                ciro_k = 0.5 * ciro_a + 0.5 * ciro_b
                s[f"ciro_a_{ad_s}"] = ciro_a
                s[f"ciro_b_{ad_s}"] = ciro_b
                s[f"ciro_{ad_s}"] = ciro_k
                # Adet ve birim fiyat, KOMBİNE ciroyla TUTARLI olacak şekilde
                # geri türetilir: adet kombine edilir, birim = ciro / adet.
                # ⚠ DÜZELTME 2026-09-14: payda `carp` varken payda YOKTU → adet
                # olduğundan DÜŞÜK, birim fiyat olduğundan YÜKSEK çıkıyordu (ciro
                # doğruydu, çünkü ayrı hesaplanıyor). Doğrusu ciro_b / b.
                adet_b = ciro_b / b if b > 0 else 0.0
                s[f"adet_{ad_s}"] = 0.5 * adet_a + 0.5 * adet_b
                s[f"birim_{ad_s}"] = ciro_k / s[f"adet_{ad_s}"] if s[f"adet_{ad_s}"] > 0 else 0.0
            s["adet"] = s["adet_orta"]
            satirlar.append(s)
        if isaret:
            notlar.append((MEKAN_AD.get(mek, str(mek)), ktg, isaret))

    if not satirlar:
        kosamadi("Model hic satir uretmedi")

    # ── (4) KAPASITE TAVANI — ay x sube bazinda fis/gun sinirlanir ───────────
    ters_mekan = {v: k for k, v in MEKAN_AD.items()}
    import calendar as _cal
    ay_adet = defaultdict(float)
    for sr in satirlar:
        ay_adet[(sr["ay"], sr["mekan"])] += sr["adet"]
    kapasite_notu = []
    for (ay, mek_ad), toplam in sorted(ay_adet.items()):
        mek = ters_mekan.get(mek_ad)
        gun = _cal.monthrange(2027, ay)[1]
        tavan_fis = ZIRVE_GUN_FIS.get(mek, 99999) * a.kapasite_payi
        ima_fis = toplam / SEPET_ADET / gun
        if ima_fis > tavan_fis:
            olcek = tavan_fis / ima_fis
            for sr in satirlar:
                if sr["ay"] == ay and sr["mekan"] == mek_ad:
                    sr["adet"] *= olcek
                    for ad_s in SEN:
                        sr[f"adet_{ad_s}"] *= olcek
                        sr[f"ciro_{ad_s}"] *= olcek
                        sr[f"ciro_a_{ad_s}"] *= olcek
                        sr[f"ciro_b_{ad_s}"] *= olcek
                    sr["isaret"] = (sr["isaret"] + " · KAPASITE TAVANI").strip(" ·")
            kapasite_notu.append(
                (AY_AD[ay], mek_ad, round(ima_fis), round(tavan_fis), round(100*(1-olcek), 1)))

    # ── (3) SINAV TAHMINI — AYRI MODEL, kendi surucusu: PAKET ADEDI ─────────
    # GMY 13.09: "Sinav'i ayri tut, karistirma" -> tahmine KARISTIRILMADI, ama
    # kurul (CFO) 14.09'da hakli olarak "sirket butcesi olacaksa %36'lik parca bos
    # kalamaz" dedi. Bu yuzden AYRI bir blok olarak tahmin edilir.
    # ⚠ SINAV PERAKENDE MODELIYLE TAHMIN EDILEMEZ: surucusu trafik degil OGRENCI/
    #   PAKET SAYISI. Adet 3 yildir DUSUYOR, ciroyu FIYAT tasiyor.
    sn_yil = defaultdict(lambda: [0.0, 0.0])          # yil -> [ciro, adet]
    sn_gun25 = defaultdict(lambda: [0.0, 0.0])        # gun -> [ciro, adet] (2025)
    for g, _m, _k, c, ad in snv:
        sn_yil[g.year][0] += c
        sn_yil[g.year][1] += ad
        if g.year == 2025:
            sn_gun25[g][0] += c
            sn_gun25[g][1] += ad
    # Sinav'a OZGU okul-hizali k (T-29..T-2) — perakendenin k'si kullanilmaz
    sn_p = {2025: [0.0, 0.0], 2026: [0.0, 0.0]}
    for g, _m, _k, c, ad in snv:
        if g.year in sn_p and ofs_alt <= ofset(g) <= ofs_ust:
            sn_p[g.year][0] += c
            sn_p[g.year][1] += ad
    sn_k_ciro = (sn_p[2026][0] / sn_p[2025][0]) if sn_p[2025][0] else 1.0
    sn_k_adet = (sn_p[2026][1] / sn_p[2025][1]) if sn_p[2025][1] else 1.0
    # 2026 kapanisi: gerceklesen + Eylul kalani (2025'in AYNI OFSETLERI x k)
    sn26_ciro, sn26_adet = sn_yil[2026][0], sn_yil[2026][1]
    gg = kesim + dt.timedelta(days=1)
    while gg <= dt.date(2026, 9, 30):
        esd = OKUL_ACILIS[2025] + dt.timedelta(days=ofset(gg))
        v = sn_gun25.get(esd)
        if v:
            sn26_ciro += v[0] * sn_k_ciro
            sn26_adet += v[1] * sn_k_adet
        gg += dt.timedelta(days=1)
    for ayx in (10, 11, 12):
        for g, v in sn_gun25.items():
            if g.month == ayx:
                sn26_ciro += v[0] * sn_k_ciro
                sn26_adet += v[1] * sn_k_adet
    sn26_birim = sn26_ciro / sn26_adet if sn26_adet else 0.0
    # ── ⭐ SINAV ARTIK OGRENCI KOHORT MODELIYLE TAHMIN EDILIR ───────────────
    # GMY 2026-09-14: "sepet ogrenci sayisi tahmininden gidelim".
    # ⚠⚠ ONCEKI SURUM YANLISTI: paket adedi CAGR'i (-%19,7) kullaniyordu ve bu
    #    OGRENCI KAYBI ile SEPET INCELMESINI TEK SAYIYA SIKISTIRIYORDU.
    #    Ayristirilinca (gercek ogrenci verisi, BKM.snv.Siparis):
    #      ogrenci        7.435 -> 7.250 -> 6.952 kapanis  (yalniz -%4,0/yil)
    #      ogr.basi paket  8,40 -> 6,86  -> 5,83           (**-%15/yil, SEPET INCELIYOR**)
    #    Paket adedini tek basina CAGR'lamak bu ikisini ayirt edemiyordu.
    # YENI YAPI: ciro = OGRENCI x OGRENCI BASINA CIRO (ikisi AYRI tahmin edilir).
    ORAN_T2 = None   # kesime kadarki kaydin tam yila orani (olculur)
    o_tam, o_t2 = ogr["tam"], ogr["t2"]
    _p = [(sum(o_t2[(sf, y)] for sf in range(1, 13)),
           sum(o_tam[(sf, y)] for sf in range(1, 13))) for y in (2024, 2025)]
    if all(t > 0 for _k, t in _p):
        ORAN_T2 = sum(k for k, _t in _p) / sum(t for _k, t in _p)
    else:
        kosamadi("Ogrenci tamamlanma orani olculemedi")
    # 2026 kapanisi: sinif bazinda T-2 / oran
    o26 = {sf: o_t2[(sf, 2026)] / ORAN_T2 for sf in range(1, 13)}
    o25 = {sf: o_tam[(sf, 2025)] for sf in range(1, 13)}
    o24 = {sf: o_tam[(sf, 2024)] for sf in range(1, 13)}
    # Kohort gecis oranlari — iki yilin ORTALAMASI (tek yil gurultulu)
    kohort = {}
    for sf in range(2, 13):
        k1 = o25[sf] / o24[sf - 1] if o24[sf - 1] else 1.0
        k2 = o26[sf] / o25[sf - 1] if o25[sf - 1] else 1.0
        kohort[sf] = (k1 + k2) / 2
    # 1. sinif ALIMI ayri: 2 yillik CAGR
    alim_cagr = (o26[1] / o24[1]) ** 0.5 if o24[1] > 0 else 1.0
    o27 = {1: o26[1] * alim_cagr}
    for sf in range(2, 13):
        o27[sf] = o26[sf - 1] * kohort[sf]
    ogr26, ogr27 = sum(o26.values()), sum(o27.values())
    # Ogrenci basina ciro — SEPET. Olculen: +%50,4 (2025) -> +%20,8 (2026)
    obc = {2024: sn_yil[2024][0] / sum(o24.values()),
           2025: sn_yil[2025][0] / sum(o25.values()),
           2026: sn26_ciro / ogr26}
    obc_art25 = obc[2025] / obc[2024] - 1
    obc_art26 = obc[2026] / obc[2025] - 1
    obc_yavas = (obc_art26 / obc_art25) if obc_art25 else 0.5
    sn_cagr = ogr27 / ogr26 if ogr26 else 1.0   # geriye uyumluluk (adet olceginde)
    # SEPET (ogrenci basina ciro) senaryolari — SINAV'IN KENDI dinamigi
    SEN_SN = {"dusuk": 1 + a.sinav_dusuk / 100, "orta": 1 + a.sinav_orta / 100,
              "yuksek": 1 + a.sinav_yuksek / 100}
    sn27 = {k_: ogr27 * obc[2026] * c_ for k_, c_ in SEN_SN.items()}
    # OGRENCI DUYARLILIGI — asil surucu; sepet senaryolari bunu KAPSAMAZ
    sn27_ogr_duyar = {
        "kohort modeli (%{:+.1f})".format(100 * (ogr27 / ogr26 - 1)): ogr27,
        "öğrenci SABİT kalırsa": ogr26,
        "8→9 sızıntısı KAPANIRSA (0,865→0,95)":
            ogr27 + o26[8] * (0.95 - kohort[9]),
    }

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
        ["2027 TAHMİN — KOMBİNASYON MODELİ, üç fiyat senaryosu", "", ""],
        ["  (A) bizim model ve (B) sNaive+drift'in basit ORTALAMASI — backtest'te", "", ""],
        ["  ikisinden de iyi çıktı: MASE 0,621 vs 0,702 (A) / 0,675 (B).", "", ""],
        ["  A) bizim model tek başına (orta)",
         round(sum(s["ciro_a_orta"] for s in satirlar)), ""],
        ["  B) sNaive+drift tek başına (orta)",
         round(sum(s["ciro_b_orta"] for s in satirlar)), ""],
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
        # ── GERİYE DÖNÜK SINAMA — modelin KENDİ ölçülmüş hatası ──────────────
        # scripts/tahmin_backtest.py (rolling origin, MASE). Buraya ELLE yazıldı;
        # sayı değişirse backtest yeniden koşulup bu blok güncellenir.
        ["GERİYE DÖNÜK SINAMA — modelin ÖLÇÜLEN hatası (scripts/tahmin_backtest.py)", "", ""],
        ["  Ölçüt MASE (Hyndman & Koehler 2006). M5'te 5.507 takımın yalnız %35,8'i", "", ""],
        ["  seasonal-naive temel çizgisini geçebildi — sNaive güçlü bir rakiptir.", "", ""],
        ["  Kesim 2023→2024:  sNaive 2,074 · sNaive+drift 1,239 · BİZİM 1,372 · komb. 1,249", "", ""],
        ["  Kesim 2024→2025:  sNaive 1,109 · sNaive+drift 0,675 · BİZİM 0,702 · komb. 0,621", "", ""],
        ["  ⚠ BİZİM MODEL, ay×şube×kategori düzeyinde sNaive+drift'i GEÇEMİYOR.", "", ""],
        ["  ⚠ Yıl TOPLAMINDA ise daha iyi: 2025 sapması bizim +%9,9 · drift +%14,0.", "", ""],
        ["  ⇒ Model AYRIMI iyi yapıyor, SEVİYEYİ sNaive+drift kadar iyi tutturamıyor.", "", ""],
        [],
        ["⚠⚠ SENARYO BANDI GERÇEK BELİRSİZLİKTEN DAR", "", ""],
        [f"  Ölçülen yıl sapması ±%10-14. Üç fiyat senaryosu ortanın yalnız "
         f"±%{100*(t27['yuksek']-t27['dusuk'])/(2*t27['orta']):.0f}'ini kapsıyor.", "", ""],
        ["  Ölçülen hataya göre GERÇEKÇİ bant (orta ±%12):", "", ""],
        ["    alt", round(t27["orta"] * 0.88), ""],
        ["    üst", round(t27["orta"] * 1.12), ""],
        ["  ⚠ Bu bant yalnız 2 kesim noktasından türedi — YÖN gösterir, kesin değildir.", "", ""],
        [],
        ["⭐ KURULUN ALTI MADDESİ UYGULANDI (2026-09-14)", "", ""],
        [],
        ["1) DÜRÜST BANT — üç senaryo TEK BAŞINA yetersizdir", "", ""],
        ["  Senaryo bandı (düşük↔yüksek) ortanın ±%{:.1f}'i".format(
            100 * (t27["yuksek"] - t27["dusuk"]) / (2 * t27["orta"])), "", ""],
        ["  Backtest'te ÖLÇÜLEN yıl sapması ±%10-14 ⇒ bant tek başına YETMEZ.", "", ""],
        ["  ⇒ KARAR BU BANTLA VERİLİR (orta ±%12, ölçülen hatadan):", "", ""],
        ["    alt", round(t27["orta"] * 0.88), ""],
        ["    üst", round(t27["orta"] * 1.12), ""],
        [],
        ["2) ÜST SENARYO AÇILDI — OVP'nin SİCİLİ nedeniyle", "", ""],
        ["  OVP 2026 hedefi %9,7 · Ağu-2026 gerçekleşen %31,51 → 3,25 KAT", "", ""],
        ["  OVP 2024 hedefi %33 → %41,5 revize, gerçekleşen ~%44 → 1,33 kat", "", ""],
        ["  ⇒ OVP manşeti TAVAN değil TABAN. Yüksek senaryo %21 → %28 açıldı.", "", ""],
        ["  ⚠ ÇAPANIN GERİYE DÖNÜK TESTİ: OVP 2026 hedefi (%9,7) mal oranıyla", "", ""],
        ["    bizim fiyatımız için ~%4,9 derdi; GERÇEKLEŞEN +%15,0 (3 kat sapma).", "", ""],
        ["    ⇒ OVP çapası TEK BAŞINA güvenilmez; yüksek senaryo bu yüzden var.", "", ""],
        [],
        ["4) KAPASİTE TAVANI UYGULANDI — bağlayıcı kısıt KASA, raf değil", "", ""],
        ["  Adet zirve/ortalama 3,99-8,36 iken FİŞ zirve/ortalama 1,9-2,4", "", ""],
        ["  ⇒ zirve günde mağaza daha çok İŞLEM değil daha büyük SEPET satıyor.", "", ""],
        ["  Tavan = gözlenen en yoğun gün × {:.2f} (SEÇİLMİŞ pay, ölçülmedi)".format(
            a.kapasite_payi), "", ""],
        ["  Gözlenen zirve: FSM 2.206 · Özlüce 2.389 · İst.Yolu 1.933 fiş/gün", "", ""],
    ] + ([["  ⚠ TAVANA DAYANAN AY × ŞUBE (talep vardı, kapasite yoktu):", "", ""]] +
         [[f"    {ax} · {mx}: istenen {imx:,} → tavan {tvx:,} fiş/gün (−%{kx})",
           "", ""] for (ax, mx, imx, tvx, kx) in kapasite_notu]
         if kapasite_notu else [["  (hiçbir ay tavana dayanmadı)", "", ""]]) + [
        [],
        ["5) FVA ETİKETİ — sınanmamış katmanlar AÇIKÇA işaretlendi", "", ""],
        ["  Backtest (MASE 0,621) KPSS ve OVP katmanları OLMADAN koşuldu.", "", ""],
        ["  ⇒ KPSS düzeltmesi: FVA ÖLÇÜLMEDİ → **DENEME**", "", ""],
        ["  ⇒ OVP fiyat çapası: FVA ÖLÇÜLMEDİ (ileriye dönük makro çapa,", "", ""],
        ["     geçmiş kesimde koşulamaz) → **DENEME**; geriye dönük testi yukarıda.", "", ""],
        ["  ⇒ Takvim katmanı: 2027'de çarpan ≈1,00 ⇒ katkısı SIFIR (nötr).", "", ""],
        [],
        ["6) KARŞI-METRİK — ciro hedefi tek başına konmaz", "", ""],
        ["  Hedef bir DAVRANIŞ üretir: ciro hedefi → indirimle hacim satın alma.", "", ""],
        ["  Ölçülen brüt marj %{:.1f} (aynı-yıl alış eşlemesi; 24-aylık pencereyle".format(
            100 * BRUT_MARJ), "", ""],
        ["  %37,3 çıkıyordu ve iyimserdi — fark 6,8 PUAN).", "", ""],
        ["  2027 orta senaryoda BEKLENEN BRÜT KÂR (marj sabit kalırsa)",
         round(t27["orta"] * BRUT_MARJ), ""],
        ["  ⚠ Bu bir HEDEF DEĞİL, KARŞI-METRİKTİR: ciro tutup marj bunun altına", "", ""],
        ["  inerse hacim indirimle satın alınmış demektir.", "", ""],
        ["  İkinci karşı-metrik: sepet adedi (ölçülen {:.2f}) — düşerse ucuz".format(SEPET_ADET), "", ""],
        ["  ürüne kayma var demektir.", "", ""],
        [],
        ["3) SINAV — ÖĞRENCİ KOHORT MODELİ (GMY: sepet öğrenci sayısından)", "", ""],
        ["  ⚠⚠ ÖNCEKİ SÜRÜM YANLIŞTI: paket adedi CAGR'ı (−%19,7) ÖĞRENCİ KAYBI ile", "", ""],
        ["    SEPET İNCELMESİNİ tek sayıya sıkıştırıyordu. Gerçek öğrenci verisiyle", "", ""],
        ["    (BKM.snv.Siparis; sipariş/öğrenci = 1,00) ikisi AYRIŞTI:", "", ""],
        ["      öğrenci        7.435 → 7.250 → {:,.0f} kapanış   (yalnız −%4,0/yıl)".format(ogr26), "", ""],
        ["      öğr.başı paket  8,40 → 6,86 → 5,83          (−%15/yıl, SEPET İNCELİYOR)", "", ""],
        ["  ⚠ 2026 kapanışı OKUL-HİZALI: kayıt takvimi de açılışa bağlı. Kesime kadarki", "", ""],
        ["    kaydın tam yıla oranı 2024 ve 2025'te neredeyse aynı (ölçülen {:.3f}).".format(ORAN_T2), "", ""],
        ["  ÖĞRENCİ BAŞINA CİRO (sepet): 2024 {:,.0f} → 2025 {:,.0f} (+%{:.1f}) → 2026 {:,.0f} (+%{:.1f})".format(
            obc[2024], obc[2025], 100*obc_art25, obc[2026], 100*obc_art26), "", ""],
        ["    ⇒ yavaşlama oranı {:.2f} — GMY'nin 'sepette eski oranda artmıyor' gözlemi ÖLÇÜLDÜ".format(obc_yavas), "", ""],
        ["  ⭐ KOHORT GEÇİŞ ORANLARI (iki yılın ortalaması) — SIZINTI NEREDE:", "", ""],
        ["    8→9 {:.3f}  ·  9→10 {:.3f}  ·  10→11 {:.3f}  ·  11→12 {:.3f}".format(
            kohort[9], kohort[10], kohort[11], kohort[12]), "", ""],
        ["    ⇒ EN BÜYÜK KAYIP ORTAOKUL→LİSE geçişinde (8→9). 1. sınıf alımı:", "", ""],
        ["      {:,.0f} → {:,.0f} → {:,.0f} (CAGR %{:+.1f})".format(
            o24[1], o25[1], o26[1], 100*(alim_cagr-1)), "", ""],
        ["  SINAV 2026 kapanış", round(sn26_ciro), round(ogr26)],
        ["  2027 öğrenci (kohort)", "", round(ogr27)],
        ["  SINAV 2027 DÜŞÜK  (sepet +%{:g}: yavaşlama sürer)".format(a.sinav_dusuk),
         round(sn27["dusuk"]), ""],
        ["  SINAV 2027 ORTA   (sepet +%{:g})".format(a.sinav_orta), round(sn27["orta"]), ""],
        ["  SINAV 2027 YÜKSEK (sepet +%{:g}: 2026 tekrarlar)".format(a.sinav_yuksek),
         round(sn27["yuksek"]), ""],
        ["  ⚠⚠ ASIL SÜRÜCÜ ÖĞRENCİ SAYISIDIR — sepet senaryoları bunu KAPSAMAZ:", "", ""],
    ] + [[f"    {etk}", round(v * obc[2026] * SEN_SN['orta']), round(v)]
         for etk, v in sn27_ogr_duyar.items()] + [
        ["  ⚠⚠ PAKET ADEDİ BİR İŞLETME KARARIDIR (öğrenci sayısı), tahmin değil.", "", ""],
        ["  Model geçmiş düşüş trendini sürdürür. GMY bir kayıt hedefi verirse", "", ""],
        ["  adet ona sabitlenip yeniden koşulmalıdır.", "", ""],
        [],
        ["★ ŞİRKET TOPLAMI (perakende + Sınav, orta senaryo)",
         round(t27["orta"] + sn27["orta"]), ""],
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
                     round(s["ciro_yuksek"]),
                     round(s["ciro_a_orta"]), round(s["ciro_b_orta"]),
                     round(s["buyume"], 3), round(s["takvim"], 4), s["isaret"]])
    yaz(ws, ["Ay No", "Ay", "Şube", "Kategori", "Adet", "Birim ₺ (orta)", "Ciro DÜŞÜK ₺",
             "Ciro ORTA ₺", "Ciro YÜKSEK ₺", "A) bizim model ₺", "B) sNaive+drift ₺",
             "Hacim büyüme", "Takvim çarpanı", "Not"],
        rows, [7, 11, 11, 20, 11, 14, 16, 16, 16, 17, 17, 13, 13, 28], (5, 7, 8, 9, 10, 11))

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
        [], ["4. AŞAMA — FİYAT SENARYOLARI (OVP + DOLAR ÇAPALI, GMY isteği)"],
        ["ÖLÇÜLEN 1", "Bizim birim fiyat artışımız 2026 (Oca-Ağu): +%15,0"],
        ["ÖLÇÜLEN 2", "TÜİK Ağu-2026 yıllık: TÜFE %31,51 · TEMEL MALLAR %15,89 · Hizmet %40,28"],
        ["ÇIKARIM 1", "Kitap/kırtasiye TEMEL MALDIR ⇒ fiyatımız mal enflasyonuyla BİREBİR"],
        ["", "(geçişkenlik 15,0/15,89 = 0,94). MANŞET TÜFE İLE KIYAS YANILTIR."],
        ["ÇIKARIM 2", "Temel mal / manşet oranı = 15,89 / 31,51 = 0,50"],
        ["ÇAPA (OVP)", "OVP 2027: enflasyon %21,0 · dolar 56,05 ₺ (+%19,6) · 2028: %15,5 / +%13,6"],
        ["DÜŞÜK", f"+%{a.dusuk:g} — OVP %21 TUTAR ve mal/manşet oranı 0,50'de kalır"],
        ["", "  (21 × 0,50 = 10,6 → kendi geçişkenliğimizle ~%10)"],
        ["ORTA", f"+%{a.orta:g} — OVP bir miktar AŞILIR ya da malın payı yükselir;"],
        ["", "  2026 gerçekleşmemiz (+%15,0) tekrar eder"],
        ["YÜKSEK", f"+%{a.yuksek:g} — mal-manşet farkı KAPANIR, OVP manşeti doğrudan fiyata"],
        ["", "  yansır; dolar +%19,6 ile de uyumlu (ithal mal maliyet baskısı)"],
        ["⚠ SINIR", "OVP bir HEDEFTİR, tahmin değil; geçmişte gerçekleşme hedefin ÜSTÜNDE kaldı."],
        ["", "Piyasa/TCMB anket beklentileri OVP'nin ÜSTÜNDEDİR — YÜKSEK senaryo o yöndür."],
        [], ["5. AŞAMA — KATEGORİ MÜDAHALESİ (KPSS)"],
        ["GMY beyanı", "akademi bu sene kpss senesiydi seneye olmayacak"],
        ["Ölçülen", "Akademi 2026 adet +%153 (30.908 → 78.346, Oca-Ağu) — TAKVİM OLAYI, trend DEĞİL"],
        ["Uygulanan", "2026 zirvesi taban ALINMADI; 2025 seviyesi × genel hacim trendi."],
        ["", "Hem A hem B bileşenine uygulandı (yoksa kaba bileşen düzeltmeyi geri alırdı)."],
        ["⚠", "Bu bir ÖLÇÜM DEĞİL, İŞ BİLGİSİDİR (kaynak: GMY). Sınav takvimi değişirse"],
        ["", "yeniden ele alınmalı."],
        [], ["SINIRLAR"],
        ["HACİM RİSKİ YOK", "Üç senaryo yalnız FİYATI değiştirir; hacim tek varsayım."],
        ["  ⭐ AMA HACİM KASADAN DOĞRULANDI (2026-09-14)", "eski kasa INTER_BOS ile:"],
        ["", "2025 H1 → 2026 H1 fiş +%20,1 · adet +%34,1 · sepet +%11,7"],
        ["", "(eski kasa satır tipi SAT+IPT; PRI/IND satırları adet taşır, sayılmaz)"],
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
