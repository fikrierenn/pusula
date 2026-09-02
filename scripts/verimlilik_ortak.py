# -*- coding: utf-8 -*-
"""Kadro/verimlilik raporlarinin ORTAK katmani: sabitler + baglanti + kapsam filtreleri.

Bagimlilik yonu tek yonlu: ortak <- cek_* <- cek <- verimlilik_excel (CLI).
Bolunme gerekcesi + harita: plans/39-verimlilik-script-split.md (K-20).
"""
import os
import re
import sys
from pathlib import Path

import pyodbc          # kapat_baglantilar pyodbc.Error yakalar -> modul duzeyi import ZORUNLU

try:   # Windows cp1254 konsolunda ok/uyari isaretleri UnicodeEncodeError veriyordu
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, OSError) as _e:
    print("stdout utf-8 yapilamadi: %s" % _e)

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

# ---- SEZON TANIMI (kullanici, 03.09.2026): okul sezonu TEMMUZ-EKIM; agirlik Agu-Eyl-Eki.
#   Temmuz hazirlik, asil hacim ve sezonluk kadro Agustos-Ekim'de. Kadro/maliyet kiyasi bu
#   pencerede yapilir; yil-geneli kumulatif pencere yalniz REFERANSTIR.
SEZON_AYLAR = (7, 8, 9, 10)

# ---- K-22 yasal fazla mesai cercevesi (4857/41 + 63) — is hukuku sabitleri
AY_NORMAL_SAAT = 195.0     # 45 saat/hafta x 52 / 12 ay
FM_YILLIK_SINIR = 270.0    # kisi basi yillik fazla mesai ust siniri (saat)

# as-of aktif personel kosulu (iki ? alir: tarih, tarih) — sp_PersonelKarsilastirma_Ozet ile birebir
ASOF = "v.Igt <= ? AND (v.Ict IS NULL OR v.Ict >= ?)"



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


_BAGLANTILAR = []          # K-17: acilan her baglanti burada; main finally'de kapatilir


def _kapat(cn):
    """Tek baglantiyi kapat ve listeden dus (finally'de ikinci kez kapatilmasin)."""
    if cn in _BAGLANTILAR:
        _BAGLANTILAR.remove(cn)
    cn.close()


def kapat_baglantilar():
    """Acik pyodbc baglantilarini kapat. sys.exit (mutabakat hatasi) yolunda da calisir."""
    while _BAGLANTILAR:
        cn = _BAGLANTILAR.pop()
        try:
            cn.close()
        except pyodbc.Error as e:
            print("  ⚠ bağlantı kapatılamadı: %s" % e, flush=True)


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
            _BAGLANTILAR.append(cn)
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

AY_AD_KISA = {1: "Oca", 2: "Şub", 3: "Mar", 4: "Nis", 5: "May", 6: "Haz",
              7: "Tem", 8: "Ağu", 9: "Eyl", 10: "Eki", 11: "Kas", 12: "Ara"}

NOTLAR = [
    "Ürün adedi enflasyondan bağımsız — kadro kıyasında birincil ölçüt. Ciro ikincil (fiyat endeksi +%19,8, Fisher, eşleşen ürün).",
    "Kıyas okul açılışına hizalı yapılır. Takvim tarihine göre kıyas 2026'da yapay düşüş gösterir: açılış 8 Eylül 2025'ten 14 Eylül 2026'ya, 6 gün kaydı.",
    "İş hacmi EncoreMerkez POS'tan DEĞİL DerinSIS'ten alınır: POS Temmuz 2025'te değişti (ENPOS → EncoreMerkez), EncoreMerkez'in 2025 tabanı eksik.",
    "Heykel ve Şura POS raporlamasında yok — mağaza sayfası üç POS mağazası (FSM · Özlüce · İst. Yolu). Beş mağaza kadro hareketi Özet'te ayrı.",
    "Kadro = o tarihte fiilen çalışan kişi (sezonluk + kadrolu). Kişi başı oranlar kasiyer değil TÜM mağaza kadrosu üzerinden.",
    "Fiş sayısı bu kaynakta yok: eTip 100 günlük özet belgedir (bir gün = bir belge).",
    "Kıdem → verimlilik testi NEGATİF çıktı: aynı kasiyerin öğrenme eğrisi düz (220 → 256 → 242 fiş/gün), mağaza kıdem sıralaması verimlilikle uyuşmuyor. 'Tecrübeli 1 kişi = acemi 3 kişi' iddiası bu veriyle savunulamaz.",
]
