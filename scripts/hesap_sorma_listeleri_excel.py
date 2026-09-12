# -*- coding: utf-8 -*-
"""HESAP-SORMA TOPLANTISI ÇALIŞMA LİSTELERİ → Excel (üç sayfa + özet).

Üretim sebebi: `satinalma-danisman` kurulu 12.09.2026 — _"toplantı 'bakarız' ile biterse
boşa gitti"_. Her liste bir TAAHHÜDE bağlanır: kalem · sahibi · tarih · ölçü.
Sayfalar ÇALIŞMA belgesidir; son dört kolon BOŞ gelir ve toplantıda alıcı doldurur.

═══ NEDEN DÖRT DEĞİL ÜÇ SAYFA ═════════════════════════════════════════════════
Kurulun 2 numaralı listesi "ACİL — hiç stok yok, kapak altı" (3.153 çeşit). O liste
BU SCRIPTTE ÜRETİLMEZ: sipariş hesap çekirdeği (kapak + emniyet + ölçülen yıl oranı)
zaten `scripts/siparis_onerisi_excel.py` içinde ve `emitter-ayrimi.md` gereği bir hesap
İKİ YERE yazılmaz — kopyalanan çekirdek biri güncellenince öteki bayatlar.
    python scripts/siparis_onerisi_excel.py        ← ACİL listesi oradan çıkar

═══ SAYFALAR ══════════════════════════════════════════════════════════════════
A · STOKSUZ-KANITLI   356 çeşit — geçen sezon ≥20 adet sattı, BUGÜN stok TAM SIFIR.
    Toplantının açılış kartı. Para: geçen sezon bu ürünlerden FİİLEN 6,89M ₺ ciro.
B · AŞIRI STOK ilk 1.000 — eşik üstü fazla maliyete göre. 34,2M ₺ = fazlanın %46'sı.
C · HİÇ SATMAMIŞ ilk 1.000 — 7,47M ₺ = o kohortun %44'ü. SAHİBİ SATINALMA DEĞİL:
    ticaret/fiyatlandırma + finans (tasfiye kararı). Kurul 12.09: çeşit başına 509 ₺,
    envanterin %4,5'i — hesap-sorma kalemi değil, tasfiye kalemi.

═══ HER SATIRDA AÇIK SİPARİŞ KOLONU VAR (kritik) ══════════════════════════════
Kurul toplantının en büyük riskini _"alıcı 'yolda mal var' diyecek, cevabın olmayacak"_
diye koydu. Kolon o yüzden var. Süzgeç sema'dan (canlı keşif YAPILMADI):
  · `eTip IN (0,3)` — Alış + Yerel Alım. **eTip 9 MAL KABUL'dür, alım DEĞİL**
    (19.08.2026'da bu hataya düşülüp mal kabulcü en büyük satınalmacı gösterilmişti);
    eTip 13 = depo→mağaza sevki, satınalma değil.
  · tarih `sip.eTarih` — `eTarihS` SEVK PLANI ve geçmişte kalabilir.
  · adet `sipAyr.ehAdet` — **`ehAdetN` DEĞİL**, açık satırlarda 0 olabilir.
  · `eDurum <> 2` (iptal şüphesi). 0/1 ayrımı sema'da TEYİT BEKLİYOR, ikisi de açık sayıldı.

⚠ "Sipariş girilmiş" ≠ "mal hâlâ yolda". `sipAyr.ehSevkAdet` tamamen NULL, `irsAyr.ehSipID`
bağı doğrulanamadı (TODO B-180) → karşılanma ölçülemiyor. Bu yüzden İKİ pencere ayrı yazılır:
  Sip30  = son 30 gün  → "HÂLÂ sipariş giriliyor" (süren davranış)
  Sip180 = son 180 gün → "sipariş GİRİLMİŞTİ" (geçmiş karar; malı gelmiş olabilir)
ODAK ortalama temini 5,03 gün; 180 günlük sayıyı "hâlâ veriyor" diye okumak YANLIŞTIR.

⚠ Panel açık siparişi BİLEREK NETLEMEZ (kullanıcı direktifi 10.09.2026: _"yeni gelen sezon
siparişlerini var olarak görme"_). Bu script de netlemez — GÖSTERİR.

═══ ÖLÇÜLMEDİ / SINIR ═════════════════════════════════════════════════════════
· Alıcı boyutu veride YOK (taban 46 kolon) → liste ÜRÜN bazlı, kişiye atıf yapılmıyor.
· Maliyet ön-şartı `0 < BirimMaliyet <= SatisFiyat` (TMS 2). Şartı sağlamayan 313 çeşit
  (31,45M ₺ yazılı maliyet) listelere GİRMEZ — ayrı bir muhasebe konusudur.
· Kayıp rakamları sağdan sansürlü = ALT SINIR; aşırı stok TAM ölçülü (asimetri duruyor).
· A sayfasındaki "GeçenSezonCiro" FİİLİ cirodur (irsHrk), bugünkü fiyatla tahmin DEĞİL —
  bugünkü fiyatla hesap %36 şişiriyordu (ölçüldü 12.09, TODO B-177).

⚠ pyodbc (pymssql DEĞİL): DerinSIS varchar CP1254, pymssql Türkçe'yi bozar.

Kullanım:
    python scripts/hesap_sorma_listeleri_excel.py [--kesim 2026-09-11] [--sezon 2025]
                                                  [--adet 1000] [--cikti yol.xlsx]
Çıkış: 0 dosya yazıldı · 2 KOŞAMADI (bağlantı/şema/boş sonuç — sessizlik kanıt değil).
"""
from __future__ import annotations

import argparse
import datetime as dt
import io
import os
import re
import sys

import pyodbc
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Eşik sabitleri — PANELLE AYNI (SatisAnaliziQueries.AsiriStokKat / AsiriKapakKat).
# Ayrışırsa liste ve kart farklı sayı gösterir; o yüzden burada da yorumla bağlanıyor.
SEZON_KAT = 2      # stok > 2 × sezon satışı
KAPAK_KAT = 5      # stok > 5 × (temin + 30 gün) × talep  → devir hedefi 2,0'dan geliyor
GOZDEN_GECIRME = 30
KANITLI_ESIK = 20  # sezonda ≥20 adet = "talebi kanıtlı" (10.09 raf-kaybı ölçümü)

BASLIK_DOLGU = PatternFill("solid", fgColor="1F3864")
BOS_DOLGU = PatternFill("solid", fgColor="FFF2CC")   # alıcının dolduracağı kolonlar


def kosamadi(mesaj: str) -> None:
    """Ölçüm YAPILAMADI → çıkış 2. Boş sonuç ile hiç koşmamak ekranda aynı görünür."""
    print(f"KOSAMADI: {mesaj}", file=sys.stderr)
    raise SystemExit(2)


def env_oku(yol: str) -> dict[str, str]:
    """`.env` — kimlik YALNIZ burada durur (dört sözleşme: tek kimlik yolu)."""
    if not os.path.exists(yol):
        kosamadi(f".env bulunamadi: {yol}")
    env: dict[str, str] = {}
    with open(yol, encoding="utf-8") as f:
        for ln in f:
            if ln.lstrip().startswith("#"):
                continue
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
            if m:
                env[m.group(1)] = m.group(2).strip().strip('"')
    return env


def baglan(env: dict[str, str]) -> pyodbc.Connection:
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
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 900
    return cn


# ── Ortak parçalar ────────────────────────────────────────────────────────────
# Defter güvenilir + maliyet güvenilir: PANELLE AYNI ön-şartlar.
DEFTER = ("t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 "
          "AND t.MerkezStok >= 0 AND t.SatisFiyat > 0")
MALIYET = "t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat"

# Açık sipariş — sema tuzakları uygulanmış (eTip 0/3 · eTarih · ehAdet).
ACIK_SIPARIS = """
    acik AS (
        SELECT a.ehstkID AS stkID,
               SUM(CASE WHEN s.eTarih >= DATEADD(DAY, -30, ?) THEN CONVERT(float, a.ehAdet)
                        ELSE 0 END) AS Sip30,
               SUM(CONVERT(float, a.ehAdet)) AS Sip180
        FROM DerinSISBkm.dbo.sipAyr a WITH (NOLOCK)
        JOIN DerinSISBkm.dbo.sip    s WITH (NOLOCK) ON s.eID = a.ehID
        WHERE s.eTip IN (0, 3) AND s.eDurum <> 2
          AND s.eTarih >= DATEADD(DAY, -180, ?) AND s.eTarih < DATEADD(DAY, 1, ?)
        GROUP BY a.ehstkID
    )"""

# Kapak (ikmal döngüsü) — paneldeki AsiriEsikSql ile aynı üç sınırın en yükseği.
KAPAK_P = f"(CONVERT(int, ISNULL(t.LeadTime, 7)) + {GOZDEN_GECIRME})"
ESIK_SQL = f"""
    CASE WHEN {SEZON_KAT}.0 * t.SezonToplam >= {KAPAK_KAT} * {KAPAK_P} * CONVERT(float, t.SatisToplam) / 365.0
          AND {SEZON_KAT}.0 * t.SezonToplam >= {KAPAK_KAT} * {KAPAK_P} * (CONVERT(float, ISNULL(t.Ay1,0)) + ISNULL(t.Ay2,0) + ISNULL(t.Ay3,0)) / 92.0
         THEN {SEZON_KAT}.0 * t.SezonToplam
         WHEN {KAPAK_KAT} * {KAPAK_P} * CONVERT(float, t.SatisToplam) / 365.0 >= {KAPAK_KAT} * {KAPAK_P} * (CONVERT(float, ISNULL(t.Ay1,0)) + ISNULL(t.Ay2,0) + ISNULL(t.Ay3,0)) / 92.0
         THEN {KAPAK_KAT} * {KAPAK_P} * CONVERT(float, t.SatisToplam) / 365.0
         ELSE {KAPAK_KAT} * {KAPAK_P} * (CONVERT(float, ISNULL(t.Ay1,0)) + ISNULL(t.Ay2,0) + ISNULL(t.Ay3,0)) / 92.0 END"""


SQL_A = f"""
WITH t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = ? AND SezonYil = ?
),
{ACIK_SIPARIS},
ger AS (   -- GEÇEN SEZON FİİLİ CİRO (bugünkü fiyatla tahmin DEĞİL — %36 şişiriyordu)
    SELECT h.ehstkID AS stkID,
           SUM(CASE WHEN h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE h.ehTutarN END) AS Ciro
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
)
SELECT t.stkID, t.BarkodAna, t.stkAd, t.Kategori3, t.Yayinevi,
       t.SezonToplam, t.SatisToplam, t.MerkezStok, t.OdakStok, t.LeadTime,
       CONVERT(decimal(18,2), ISNULL(g.Ciro, 0))      AS GecenSezonCiro,
       CONVERT(decimal(18,2), t.SatisFiyat)           AS SatisFiyat,
       CONVERT(int, ISNULL(c.Sip30, 0))               AS Sip30,
       CONVERT(int, ISNULL(c.Sip180, 0))              AS Sip180,
       t.SonSatis, t.SonGiris
FROM t LEFT JOIN acik c ON c.stkID = t.stkID
       LEFT JOIN ger  g ON g.stkID = t.stkID
WHERE {DEFTER} AND t.SezonToplam >= {KANITLI_ESIK} AND t.ToplamStok = 0
ORDER BY ISNULL(g.Ciro, 0) DESC
"""

SQL_B = f"""
WITH t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = ? AND SezonYil = ?
),
{ACIK_SIPARIS},
e AS (
    SELECT t.*, {ESIK_SQL} AS Esik, ISNULL(c.Sip30, 0) AS Sip30, ISNULL(c.Sip180, 0) AS Sip180
    FROM t LEFT JOIN acik c ON c.stkID = t.stkID
    WHERE {DEFTER} AND {MALIYET}
      AND t.SezonToplam > 0
      AND CONVERT(float, t.ToplamStok) > {SEZON_KAT}.0 * t.SezonToplam
      AND CONVERT(float, t.ToplamStok) * 365.0 > {KAPAK_KAT} * {KAPAK_P} * t.SatisToplam
      AND CONVERT(float, t.ToplamStok) * 92.0  > {KAPAK_KAT} * {KAPAK_P} * (CONVERT(float, ISNULL(t.Ay1,0)) + ISNULL(t.Ay2,0) + ISNULL(t.Ay3,0))
)
SELECT TOP (?) stkID, BarkodAna, stkAd, Kategori3, Yayinevi,
       ToplamStok, CONVERT(int, Esik) AS MesruTavan,
       CONVERT(int, CONVERT(float, ToplamStok) - Esik) AS FazlaAdet,
       CONVERT(decimal(18,2), (CONVERT(float, ToplamStok) - Esik) * BirimMaliyet) AS FazlaMaliyet,
       SatisToplam, SezonToplam, MerkezStok, OdakStok, LeadTime,
       CONVERT(decimal(18,2), BirimMaliyet) AS BirimMaliyet,
       CONVERT(int, Sip30) AS Sip30, CONVERT(int, Sip180) AS Sip180,
       SonGiris, SonSatis
FROM e
ORDER BY (CONVERT(float, ToplamStok) - Esik) * BirimMaliyet DESC
"""

SQL_C = f"""
WITH t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = ? AND SezonYil = ?
),
{ACIK_SIPARIS}
SELECT TOP (?) t.stkID, t.BarkodAna, t.stkAd, t.Kategori3, t.Yayinevi,
       t.ToplamStok, t.MerkezStok,
       CONVERT(decimal(18,2), CONVERT(float, t.ToplamStok) * t.BirimMaliyet) AS StokMaliyeti,
       CONVERT(decimal(18,2), t.Tutar)        AS EtiketDegeri,
       CONVERT(decimal(18,2), t.BirimMaliyet) AS BirimMaliyet,
       CONVERT(decimal(18,2), t.SatisFiyat)   AS SatisFiyat,
       t.IlkGiris, t.SonGiris, t.AcilisTarihi,
       CONVERT(int, ISNULL(c.Sip180, 0))      AS Sip180
FROM t LEFT JOIN acik c ON c.stkID = t.stkID
WHERE {DEFTER} AND {MALIYET}
  AND t.SatisToplam <= 0 AND t.ToplamStok > 0
  AND (t.PosAdet IS NULL OR t.PosAdet <= 1)
  AND t.IlkGiris IS NOT NULL
  AND COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -45, ?)
  AND t.SonSatis IS NULL
ORDER BY CONVERT(float, t.ToplamStok) * t.BirimMaliyet DESC
"""

# Alıcının dolduracağı kolonlar — her sayfanın SONUNA eklenir.
EYLEM_KOLON = {
    "A": ["EYLEM (sipariş/vazgeç)", "ADET", "TARİH", "GEREKÇE"],
    "B": ["ÇIKIŞ EYLEMİ (iade/kampanya/transfer/fiyat/bekle)", "HEDEF TARİH", "GEREKÇE", "SORUMLU"],
    "C": ["KARAR (iade/likidasyon/imha/fiyat)", "HEDEF TARİH", "GEREKÇE", "SORUMLU"],
}


def sayfa_yaz(wb: Workbook, ad: str, basliklar: list[str], satirlar: list,
              eylem: list[str], not_metni: str) -> None:
    ws = wb.create_sheet(ad)
    ws.cell(1, 1, not_metni).font = Font(italic=True, size=9, color="555555")
    ws.merge_cells(start_row=1, start_column=1, end_row=1,
                   end_column=max(len(basliklar) + len(eylem), 2))
    ws.row_dimensions[1].height = 30
    ws.cell(1, 1).alignment = Alignment(wrap_text=True, vertical="center")

    tum = basliklar + eylem
    for j, b in enumerate(tum, start=1):
        h = ws.cell(2, j, b)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = BASLIK_DOLGU
        h.alignment = Alignment(wrap_text=True, vertical="center")
    ws.row_dimensions[2].height = 34

    for i, satir in enumerate(satirlar, start=3):
        for j, v in enumerate(satir, start=1):
            ws.cell(i, j, v)
        for j in range(len(basliklar) + 1, len(tum) + 1):
            ws.cell(i, j).fill = BOS_DOLGU

    for j, b in enumerate(tum, start=1):
        en = max(len(str(b)), 10)
        for i in range(3, min(len(satirlar) + 3, 60)):
            v = ws.cell(i, j).value
            if v is not None:
                en = max(en, min(len(str(v)), 46))
        ws.column_dimensions[get_column_letter(j)].width = min(en + 2, 48)
    ws.freeze_panes = "A3"
    ws.auto_filter.ref = f"A2:{get_column_letter(len(tum))}{len(satirlar) + 2}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kesim", default=None, help="ISO tarih; yoksa tabandaki EN SON kesim")
    ap.add_argument("--sezon", type=int, default=2025)
    ap.add_argument("--adet", type=int, default=1000, help="B ve C sayfalarında kalem sayısı")
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        cur = cn.cursor()
        if a.kesim:
            kesim = dt.date.fromisoformat(a.kesim)
        else:
            cur.execute("SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban")
            r = cur.fetchone()
            if not r or not r[0]:
                kosamadi("Taban BOS — kesim okunamadi (sessizlik kanit degil)")
            kesim = r[0] if isinstance(r[0], dt.date) else dt.date.fromisoformat(str(r[0])[:10])

        # Sezon penceresi: Ağu–Eki, seçilen sezon yılı.
        sez_bas = dt.date(a.sezon, 8, 1)
        sez_son = dt.date(a.sezon, 11, 1)

        cur.execute(SQL_A, kesim, a.sezon, kesim, kesim, kesim, sez_bas, sez_son)
        bas_a = [d[0] for d in cur.description]
        sat_a = [list(r) for r in cur.fetchall()]

        cur.execute(SQL_B, kesim, a.sezon, kesim, kesim, kesim, a.adet)
        bas_b = [d[0] for d in cur.description]
        sat_b = [list(r) for r in cur.fetchall()]

        cur.execute(SQL_C, kesim, a.sezon, kesim, kesim, kesim, a.adet, kesim)
        bas_c = [d[0] for d in cur.description]
        sat_c = [list(r) for r in cur.fetchall()]
    finally:
        cn.close()

    if not sat_a and not sat_b and not sat_c:
        kosamadi("Uc liste de BOS dondu — kesim/sezon yanlis ya da taban dolu degil")

    wb = Workbook()
    ws = wb.active
    ws.title = "ÖZET"
    ozet = [
        ("HESAP-SORMA TOPLANTISI — ÇALIŞMA LİSTELERİ", ""),
        ("Kesim (son kapalı gün)", str(kesim)),
        ("Sezon yılı (Ağu–Eki)", str(a.sezon)),
        ("", ""),
        ("SAYFA", "KALEM · PARA · SAHİBİ"),
        ("A · STOKSUZ-KANITLI", f"{len(sat_a)} çeşit · geçen sezon fiili ciro "
         f"{sum(float(r[10] or 0) for r in sat_a):,.0f} ₺ · SATINALMA · bu hafta"),
        ("B · AŞIRI STOK", f"{len(sat_b)} çeşit · fazla maliyet "
         f"{sum(float(r[8] or 0) for r in sat_b):,.0f} ₺ · SATINALMA · 2 hafta"),
        ("C · HİÇ SATMAMIŞ", f"{len(sat_c)} çeşit · stok maliyeti "
         f"{sum(float(r[7] or 0) for r in sat_c):,.0f} ₺ · TİCARET+FİNANS · 1 ay"),
        ("D · ACİL (kapak altı, stok 0)", "BU DOSYADA YOK → python scripts/siparis_onerisi_excel.py"),
        ("", ""),
        ("NASIL KULLANILIR", "Sarı kolonlar toplantıda doldurulur. Her satır bir KARAR taşır."),
        ("", ""),
        ("SINIRLAR (okunmadan rakam kullanılmaz)", ""),
        ("Alıcı boyutu", "Veride YOK (taban 46 kolon) — liste ÜRÜN bazlı, kişiye atıf yapılmaz."),
        ("Açık sipariş", "NETLENMEDİ, GÖSTERİLDİ (kullanıcı direktifi). Sip30 = 'hâlâ sipariş "
                         "giriliyor'; Sip180 = 'girilmişti, malı gelmiş olabilir' — ODAK temini "
                         "5,03 gün. İkisi AYNI iddia değildir."),
        ("Sipariş karşılanma", "ÖLÇÜLEMİYOR (ehSevkAdet NULL, irsAyr bağı doğrulanamadı) — "
                               "'sipariş girilmiş' ≠ 'mal yolda'."),
        ("Maliyet", "Ön-şart 0 < maliyet ≤ satış fiyatı (TMS 2). Şartı sağlamayan 313 çeşit "
                    "(31,45M ₺ yazılı) listelere GİRMEDİ — ayrı bir MUHASEBE konusu."),
        ("A sayfası cirosu", "irsHrk'dan FİİLİ ciro. Bugünkü fiyatla hesap %36 şişiriyordu."),
        ("Kayıp tahminleri", "Sağdan sansürlü = ALT SINIR. Aşırı stok TAM ölçülü (asimetri)."),
        ("Eşik", "2× sezon VE 5× ikmal kapağı — ikisi BİRDEN aşılmalı. Kapak katı veriden "
                 "değil devir hedefinden (2,0) geliyor."),
    ]
    for i, (k, v) in enumerate(ozet, start=1):
        c1 = ws.cell(i, 1, k)
        ws.cell(i, 2, v).alignment = Alignment(wrap_text=True, vertical="top")
        if i == 1:
            c1.font = Font(bold=True, size=13)
        elif k and not v:
            c1.font = Font(bold=True)
        elif k:
            c1.font = Font(bold=True, size=10)
    ws.column_dimensions["A"].width = 34
    ws.column_dimensions["B"].width = 96

    sayfa_yaz(wb, "A · STOKSUZ-KANITLI", bas_a, sat_a, EYLEM_KOLON["A"],
              "Geçen sezon ≥20 adet satmış, BUGÜN stoğu TAM SIFIR. GecenSezonCiro = irsHrk'dan "
              "FİİLİ ciro (tahmin değil). Sip30/Sip180 = açık satın alma siparişi (eTip 0/3) — "
              "NETLENMEDİ, gösteriliyor.")
    sayfa_yaz(wb, "B · AŞIRI STOK", bas_b, sat_b, EYLEM_KOLON["B"],
              "MesruTavan = üç sınırın en yükseği (2× sezon · kapağın düz ve sezon ayağı). Ceza "
              "yalnız FazlaAdet'e yazılır. Sip30 > 0 ise stok zaten tavanın üstündeyken son 30 "
              "günde sipariş girilmiş demektir.")
    sayfa_yaz(wb, "C · HİÇ SATMAMIŞ", bas_c, sat_c, EYLEM_KOLON["C"],
              "365 günde ERP'de de POS'ta da satış yok, rafa çıkmış, 45 günden eski. SAHİBİ "
              "SATINALMA DEĞİL — tasfiye kararı (ticaret/fiyatlandırma + finans). Çeşit başına "
              "ortalama 509 ₺; hesap-sorma kalemi değil.")

    cikti = a.cikti or os.path.join(
        KOK, "raporlar", f"hesap-sorma-listeleri-{kesim:%Y%m%d}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)
    print(f"YAZILDI: {cikti}")
    print(f"  A · stoksuz-kanitli : {len(sat_a):>5} cesit")
    print(f"  B · asiri stok      : {len(sat_b):>5} cesit")
    print(f"  C · hic satmamis    : {len(sat_c):>5} cesit")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
