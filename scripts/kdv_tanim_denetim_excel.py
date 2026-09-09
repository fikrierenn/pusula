# -*- coding: utf-8 -*-
"""KDV TANIM DENETİMİ → Excel.

Kullanıcı isteği 09.09.2026: "şu anda aktif kdv oranlarını bulup hatalı tanımlı ürün
var mı kontrol eder misin".

AKTİF ORANLAR — mevzuattan değil, POS'ta FİİLEN kesilenden ölçüldü (son 90 gün,
hepsi 09.09.2026'da da kullanılmış):
    %20  574.825 satır / 20.249 çeşit
    %0   464.193 satır / 57.391 çeşit
    %10  143.310 satır /  6.679 çeşit
    %1    40.798 satır /    544 çeşit
  → %8 ve %18 AKTİF DEĞİL. Eski kod taşıyan normal ürün yalnız 2 (ikisi de stoksuz/satışsız).

İKİ AYRI BULGU, iki ayrı sayfa:

  SAYFA "Gecmis Sapma" — POS'ta kesilen oran ürünün tanımlı oranından FARKLI.
    365 günde 219 çeşit / 7.085 satır / 855.106 ₺ ciro
      eksik kesilen KDV: 100.206 ₺   ·   fazla kesilen: 36.660 ₺
    Baskın desen: tanımlı %20 ama %0 kesilmiş → 123 çeşit / 84.382 ₺ eksik.
    Mekanizma (stkID 1736283 Hot Wheels): kart KDV'siz açılmış, 91 satış %0 kesilmiş,
    kart 02.09.2026'da düzeltilmiş, 03.09'dan sonra %20. Yani hata kart kurulumunda.
    ⚠ AKTİF sapma YOK: son sapma 02.09.2026, ondan sonra sıfır.

  SAYFA "Supheli Tanim" — ölçütün KÖR NOKTASI. Kart yanlış ama POS da aynı yanlışı
    kesiyorsa yukarıdaki test bunu YAKALAMAZ (ikisi uyumlu görünür). O yüzden kategori
    mantığı ile ayrıca tarandı:
      kitap tarafında sıfır-dışı → Çocuk Kitabı %20 385 ürün (2.104.860 ₺) · %10 732 ·
        Kitap %20 227 · %10 246 · Akademi %10 55 · Hazırlık %10 31 · Dergi %20 8
      KDV'li tarafta %0        → Kırtasiye 2.867 ürün (2.018.694 ₺) · Oyuncak 141 ·
        Hediyelik 113 · Elektronik 25
    ⚠ Bunlar ŞÜPHELİ, KESİN HATA DEĞİL: kitap kategorisinde oyuncaklı/kırtasiyeli set,
    kırtasiye kategorisinde süreli yayın olabilir. Ürün adına bakılarak teyit edilmeli.
    Satışı olanlar öncelikli — para orada dönüyor.

⚠ pyodbc (pymssql DEĞİL): DerinSIS varchar CP1254, pymssql Türkçe'yi bozuyor.
⚠ Lookup dbo.urnKDV — kdvYuzde_vw KULLANILMAZ (Hizmet/Hammadde varyantlarını atıyor).

Kullanım:
    python scripts/kdv_tanim_denetim_excel.py [--gun 365] [--cikti yol.xlsx]
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

# ⚠ bkm.UrunBilgi'de `Yayinevi` kolonu YOK: marka ile yayınevi BKM'de aynı şey ve
# kolon adı `mrkAd` (taban da `u.mrkAd AS Yayinevi` diye alıyor).

# Kategori → beklenen KDV mantığı. ⚠ ÇIKARIM, kesin kural değil: kategori adı ürünün
# vergi niteliğini KESİN belirlemez (kitap kategorisinde oyuncaklı set olabilir).
KITAP_KATEGORILERI = ("Kitap", "Çocuk Kitabı", "Akademi", "Hazırlık Kitapları", "Dergi")
KDVLI_KATEGORILER = ("Kırtasiye", "Oyuncak", "Hediyelik", "Elektronik", "Spor & Outdoor")


def env_oku(yol: str) -> dict[str, str]:
    if not os.path.exists(yol):
        sys.exit(f".env bulunamadi: {yol}")
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
    host, port = env["MSSQL_HOST"], env.get("MSSQL_PORT", "1433")
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
        sys.exit("Gecersiz MSSQL_HOST/MSSQL_PORT (.env)")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 900
    return cn


SQL_AKTIF_ORAN = """
SELECT CONVERT(int, sp.VatPercent) AS Oran, COUNT(*) AS Satir,
       COUNT(DISTINCT p.Code) AS Cesit, MAX(s.Date) AS SonKullanim
FROM EncoreMerkez.dbo.SalesProducts sp WITH (NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH (NOLOCK) ON s.Id = sp.SalesId
JOIN EncoreMerkez.dbo.Products p WITH (NOLOCK) ON p.Id = sp.ProductsId
WHERE sp.IsValid = 1 AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
  AND s.Date >= DATEADD(DAY, -90, CAST(GETDATE() AS date))
GROUP BY sp.VatPercent
ORDER BY 2 DESC
"""

# POS'ta kesilen ≠ tanımlı. Ürün × kesilen oran kırılımı; KDV farkı KDV-hariç tabana göre.
SQL_SAPMA = """
SELECT x.stkID, x.Urun, x.Kategori, x.Tanimli, x.Kesilen, x.Satir,
       CONVERT(decimal(18,2), x.Tutar) AS Ciro,
       CONVERT(decimal(18,2), x.KesilenKDV) AS KesilenKDV,
       CONVERT(decimal(18,2), x.Tutar / (1 + x.Kesilen / 100.0) * x.Tanimli / 100.0) AS OlmasiGereken,
       CONVERT(decimal(18,2), x.Tutar / (1 + x.Kesilen / 100.0) * x.Tanimli / 100.0
               - x.KesilenKDV) AS Fark,
       x.Ilk, x.Son
FROM (
    SELECT CONVERT(int, p.Code) AS stkID,
           LEFT(MAX(u.stkAd), 70) AS Urun,
           MAX(ISNULL(ub.Kategori3, '(yok)')) AS Kategori,
           MAX(CONVERT(int, k.kdvYuzde)) AS Tanimli,
           CONVERT(int, sp.VatPercent) AS Kesilen,
           COUNT(*) AS Satir, SUM(sp.TotalPrice) AS Tutar, SUM(sp.VatTotal) AS KesilenKDV,
           MIN(s.Date) AS Ilk, MAX(s.Date) AS Son
    FROM EncoreMerkez.dbo.SalesProducts sp WITH (NOLOCK)
    JOIN EncoreMerkez.dbo.Sales s WITH (NOLOCK) ON s.Id = sp.SalesId
    JOIN EncoreMerkez.dbo.Products p WITH (NOLOCK) ON p.Id = sp.ProductsId
    JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = CONVERT(int, p.Code)
    JOIN DerinSISBkm.dbo.urnKDV k ON k.kdvID = u.KDVs
    LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = u.stkID
    WHERE sp.IsValid = 1 AND ISNUMERIC(p.Code) = 1
      -- ⚠ BELGE TİPİ SÜZGECİ (QA bulgusu 09.09): ilk sürümde YOKTU. İade (3) sapma
      -- toplamına 1.229 ₺ katıyor ve İŞARETİ ters okunuyor — iade bir satış değil.
      -- Personel (6/7) ve Sınav (8) küçük (242 + 463 ₺) ama kapsam açık yazılmalı.
      AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
      AND s.Date >= DATEADD(DAY, -?, CAST(GETDATE() AS date))
      AND CONVERT(int, sp.VatPercent) <> CONVERT(int, k.kdvYuzde)
    GROUP BY CONVERT(int, p.Code), sp.VatPercent
) x
ORDER BY ABS(x.Tutar / (1 + x.Kesilen / 100.0) * x.Tanimli / 100.0 - x.KesilenKDV) DESC
"""

# Kategori mantığına aykırı tanım — ölçütün kör noktası (kart yanlış, POS da aynı yanlış).
SQL_SUPHELI = """
SELECT u.stkID, LEFT(u.stkAd, 70) AS Urun, ub.Kategori3, ub.KatAna,
       CONVERT(int, k.kdvYuzde) AS TanimliOran, k.kdvAd AS KodAdi,
       CASE WHEN ub.Kategori3 IN ({kitap}) THEN 'kitap kategorisi ama KDV''li tanımlı'
            ELSE 'KDV''li kategori ama %0 tanımlı' END AS Neden,
       CONVERT(int, ISNULL(t.ToplamStok, 0)) AS Stok,
       CONVERT(int, ISNULL(t.SatisToplam, 0)) AS Satis365,
       CONVERT(decimal(18,2), ISNULL(t.Tutar, 0)) AS StokTutar,
       CONVERT(decimal(18,2), u.fiyatS) AS SatisFiyat,
       ub.mrkAd AS Yayinevi, ub.Yazar
FROM DerinSISBkm.dbo.urn u WITH (NOLOCK)
JOIN DerinSISBkm.dbo.urnKDV k ON k.kdvID = u.KDVs
JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = u.stkID
LEFT JOIN DerinSISBkm.bkm.SatisAnaliziTaban t
       ON t.stkID = u.stkID AND t.Kesim = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban)
WHERE u.urnTip = 0
  AND (   (ub.Kategori3 IN ({kitap})  AND k.kdvYuzde > 0)
       OR (ub.Kategori3 IN ({kdvli})  AND k.kdvYuzde = 0))
ORDER BY ISNULL(t.SatisToplam, 0) DESC, ISNULL(t.Tutar, 0) DESC
"""


def sayfa_yaz(ws, baslik_bandi, basliklar, satirlar, para_kolonlari=(), tarih_kolonlari=()):
    for i, metin in enumerate(baslik_bandi, start=1):
        ws.cell(row=i, column=1, value=metin).font = Font(
            bold=(i == 1), size=12 if i == 1 else 9, italic=(i > 1))
    bas = len(baslik_bandi) + 2
    sari = PatternFill("solid", fgColor="FFF3CD")
    for j, (ad, gen) in enumerate(basliklar, start=1):
        h = ws.cell(row=bas, column=j, value=ad)
        h.font = Font(bold=True)
        h.fill = sari
        h.alignment = Alignment(horizontal="center", wrap_text=True)
        ws.column_dimensions[get_column_letter(j)].width = gen
    for i, s in enumerate(satirlar, start=bas + 1):
        for j, v in enumerate(s, start=1):
            c = ws.cell(row=i, column=j, value=v)
            if j in tarih_kolonlari:
                c.number_format = "DD.MM.YYYY"
            elif j in para_kolonlari:
                c.number_format = "#,##0.00"
    ws.freeze_panes = ws.cell(row=bas + 1, column=1)
    if satirlar:
        ws.auto_filter.ref = (f"A{bas}:{get_column_letter(len(basliklar))}"
                              f"{bas + len(satirlar)}")


def main() -> None:
    ap = argparse.ArgumentParser(description="KDV tanım denetimi → Excel")
    ap.add_argument("--gun", type=int, default=365, help="Sapma taramasının penceresi (gün)")
    ap.add_argument("--cikti", default=None)
    arg = ap.parse_args()

    def liste(t):
        return ", ".join("'" + x.replace("'", "''") + "'" for x in t)

    sql_supheli = SQL_SUPHELI.replace("{kitap}", liste(KITAP_KATEGORILERI)) \
                             .replace("{kdvli}", liste(KDVLI_KATEGORILER))

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        with cn.cursor() as cur:
            cur.execute(SQL_AKTIF_ORAN)
            aktif = cur.fetchall()
            cur.execute(SQL_SAPMA, arg.gun)
            sapma = cur.fetchall()
            cur.execute(sql_supheli)
            supheli = cur.fetchall()
    finally:
        cn.close()

    wb = Workbook()

    # ── Sayfa 1: aktif oranlar ────────────────────────────────────────────────
    ws = wb.active
    ws.title = "Aktif Oranlar"
    sayfa_yaz(
        ws,
        [f"POS'ta FİİLEN kesilen KDV oranları — son 90 gün · {dt.date.today():%d.%m.%Y}",
         "Mevzuattan değil VERİDEN ölçüldü: bu oranlar gerçekten kesiliyor.",
         "Listede olmayan oran (%8, %18) aktif kullanımda DEĞİL."],
        [("Oran %", 10), ("Satır", 12), ("Çeşit", 12), ("Son kullanım", 14)],
        aktif, tarih_kolonlari=(4,))

    # ── Sayfa 2: geçmiş sapma ─────────────────────────────────────────────────
    ws2 = wb.create_sheet("Gecmis Sapma")
    # ⚠ QA NOTU (09.09): eksik/fazla ayrımı ÜRÜN × KESİLEN-ORAN agregesi üzerinden yapılıyor.
    # Aynı grupta hem + hem − satır varsa grup içinde netleşir → ayrım ±1.647 ₺ kayıyor
    # (agrege eksik 98.470 / fazla 36.571 → net 61.899; satır bazında gerçek net 63.546).
    # NET rakam güvenilir; eksik/fazla dağılımı YAKLAŞIKTIR ve öyle etiketlenir.
    eksik = sum(float(r[9]) for r in sapma if float(r[9]) > 0)
    fazla = -sum(float(r[9]) for r in sapma if float(r[9]) < 0)
    net = eksik - fazla
    sayfa_yaz(
        ws2,
        [f"POS'ta kesilen oran ürünün TANIMLI oranından farklı — son {arg.gun} gün",
         f"{len({r[0] for r in sapma})} çeşit · {sum(r[5] for r in sapma):,} satır · "
         f"NET fark {net:,.2f} ₺ (eksik ~{eksik:,.2f} / fazla ~{fazla:,.2f} — dağılım YAKLAŞIK, "
         f"ürün×oran agregesinde işaretler netleştiği için ±1.647 ₺ kayabilir; NET güvenilir)",
         "Kapsam: DocumentsTypeId 1,2,6,7,8 (İADE 3 HARİÇ — iade bir satış değil). "
         "İade dahil edilirse net 63.546 ₺, hariç 62.317 ₺.",
         "Fark > 0 → EKSİK kesilmiş (beyan eksiği). Fark < 0 → FAZLA kesilmiş "
         "(müşteriden fazla alınmış).",
         "⚠ Karşılaştırma ürünün BUGÜNKÜ tanımıyla yapılır: kart sonradan düzeltildiyse "
         "geçmiş satış burada 'sapma' görünür. Tarih aralığına bakın."],
        [("stkID", 10), ("Ürün", 46), ("Kategori", 16), ("Tanımlı %", 10), ("Kesilen %", 10),
         ("Satır", 8), ("Ciro", 13), ("Kesilen KDV", 13), ("Olması gereken", 14),
         ("Fark", 12), ("İlk", 12), ("Son", 12)],
        sapma, para_kolonlari=(7, 8, 9, 10), tarih_kolonlari=(11, 12))

    # ── Sayfa 3: şüpheli tanım ────────────────────────────────────────────────
    ws3 = wb.create_sheet("Supheli Tanim")
    sayfa_yaz(
        ws3,
        ["Kategori mantığına aykırı KDV tanımı — ölçütün KÖR NOKTASI",
         "Kart yanlış ama POS da aynı yanlışı kesiyorsa 'Gecmis Sapma' testi bunu YAKALAMAZ; "
         "bu sayfa kategori mantığıyla tarar.",
         "⚠ ŞÜPHELİ, KESİN HATA DEĞİL: kitap kategorisinde oyuncaklı/kırtasiyeli set, "
         "kırtasiye kategorisinde süreli yayın olabilir. Ürün adıyla teyit edilmeli.",
         "Satışı olanlar üstte — para orada dönüyor."],
        [("stkID", 10), ("Ürün", 46), ("Kategori3", 16), ("KatAna", 16),
         ("Tanımlı %", 10), ("Kod adı", 14), ("Neden şüpheli", 30),
         ("Stok", 10), ("Satış 365g", 11), ("Stok tutarı", 13), ("Satış fiyatı", 12),
         ("Yayınevi/Marka", 22), ("Yazar", 20)],
        supheli, para_kolonlari=(10, 11))

    yol = arg.cikti or os.path.join(KOK, f"KDV Tanim Denetimi {dt.date.today():%Y-%m-%d}.xlsx")
    wb.save(yol)
    print(f"Aktif oran: {len(aktif)} · Geçmiş sapma: {len(sapma)} satır "
          f"(eksik {eksik:,.2f} ₺ / fazla {fazla:,.2f} ₺) · Şüpheli tanım: {len(supheli)} ürün")
    print(f"Yazildi: {yol}")


if __name__ == "__main__":
    main()
