# -*- coding: utf-8 -*-
"""SEZON AKSİYON LİSTESİ — sade, tek sayfa, satınalma ile paylaşılacak.

GMY 14.09.2026: "365 günde satılan, sezonda satılan, sezon büyümesi %20, satılacak
miktar, mağaza+depo stok, açık, fazla — daha basit, satınalma ile paylaşıp aksiyon
alınacak liste".

Satılacak miktar = sezonda satılan × (1 + büyüme)     [büyüme varsayılan %20, sabit]
Toplam stok      = mağaza + depo(merkez)
AÇIK             = satılacak − toplam stok   (pozitifse)
FAZLA            = toplam stok − satılacak   (pozitifse)

Kapsam: geçen sezon (Ağu–Eki) satmış · defter güvenilir (negatif stok / fiyat 0 dışarıda).

Kullanım:
    python scripts/sezon_aksiyon_listesi_excel.py [--kesim 2026-09-13] [--sezon 2025]
        [--buyume 0.20] [--durum acik|fazla]
Çıkış: 0 dosya yazıldı · 2 KOŞAMADI.
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
LACI = PatternFill("solid", fgColor="1F3864")
ACIK = PatternFill("solid", fgColor="D9E2F3")


def kosamadi(mesaj: str) -> None:
    print(f"KOSAMADI: {mesaj}", file=sys.stderr)
    raise SystemExit(2)


def env_oku(yol: str) -> dict[str, str]:
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
    for a in ("MSSQL_USER", "MSSQL_PASSWORD"):
        if not env.get(a):
            kosamadi(f"{a} .env'de yok — sessizce bos sifreyle baglanilmaz")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 900
    return cn


YOL = ("STUFF(ISNULL(N' > ' + NULLIF(t.Kategori1, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat1, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat2, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat3, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat4, N''), N''), 1, 3, N'')")

MALIYET_GECERLI = "(t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat)"

SQL = f"""
SELECT t.Kategori3                                   AS [Kategori],
       {YOL}                                         AS [Kategori yolu],
       t.stkAd                                       AS [Ürün],
       t.BarkodAna                                   AS [Barkod],
       t.stkID                                       AS [stkID],
       t.Yayinevi                                    AS [Yayınevi/Marka],
       CONVERT(decimal(18,2), t.SatisFiyat)          AS [Satış fiyatı],
       t.SatisToplam                                 AS [365 günde satılan],
       t.SezonToplam                                 AS [Sezonda satılan],
       CONVERT(decimal(5,2), ?)                      AS [Büyüme],
       s.Satilacak                                   AS [Satılacak miktar],
       t.MagazaStok                                  AS [Mağaza stok],
       t.MerkezStok                                  AS [Depo stok],
       s.Elde                                        AS [Toplam stok],
       CASE WHEN s.Satilacak > s.Elde THEN s.Satilacak - s.Elde ELSE 0 END AS [AÇIK],
       CASE WHEN s.Elde > s.Satilacak THEN s.Elde - s.Satilacak ELSE 0 END AS [FAZLA],
       CASE WHEN s.Satilacak > s.Elde THEN N'AÇIK — sipariş/transfer'
            WHEN s.Elde > s.Satilacak THEN N'FAZLA — indirim/iade/transfer'
            ELSE N'DENGE' END                        AS [Durum],
       CONVERT(decimal(18,2), CASE WHEN s.Satilacak > s.Elde
            THEN (s.Satilacak - s.Elde) * t.SatisFiyat END)     AS [AÇIK ₺ (satış fiyatı)],
       CONVERT(decimal(18,2), CASE WHEN s.Elde > s.Satilacak AND {MALIYET_GECERLI}
            THEN (s.Elde - s.Satilacak) * t.BirimMaliyet END)   AS [FAZLA ₺ (maliyet)]
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
CROSS APPLY (SELECT Satilacak = CONVERT(int, CEILING(t.SezonToplam * (1.0 + ?))),
                    Elde      = t.MagazaStok + t.MerkezStok) s
WHERE t.Kesim = ? AND t.SezonYil = ?
  AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
  AND (? = 0 OR s.Satilacak > s.Elde)      -- yalnız AÇIK
  AND (? = 0 OR s.Elde > s.Satilacak)      -- yalnız FAZLA
ORDER BY CASE WHEN s.Satilacak > s.Elde THEN (s.Satilacak - s.Elde) * t.SatisFiyat
              ELSE (s.Elde - s.Satilacak) * ISNULL(t.BirimMaliyet, 0) END DESC
"""

PARA = {"Satış fiyatı", "AÇIK ₺ (satış fiyatı)", "FAZLA ₺ (maliyet)"}
ORAN = {"Büyüme"}


def ayir(n: float, para: bool = False) -> str:
    s = f"{n:,.0f}".replace(",", ".")
    return f"{s} ₺" if para else s


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kesim", default=None)
    ap.add_argument("--sezon", type=int, default=2025)
    ap.add_argument("--buyume", type=float, default=0.20,
                    help="sezon buyumesi (0.20 = %%20)")
    ap.add_argument("--durum", choices=["acik", "fazla"], default=None,
                    help="yalniz acik ya da yalniz fazla listele")
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()

    yalniz_acik = 1 if a.durum == "acik" else 0
    yalniz_fazla = 1 if a.durum == "fazla" else 0

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

        cur.execute(SQL, a.buyume, a.buyume, kesim, a.sezon, yalniz_acik, yalniz_fazla)
        bas = [d[0] for d in cur.description]
        sat = [list(x) for x in cur.fetchall()]
    finally:
        cn.close()

    if not sat:
        kosamadi(f"Liste BOS dondu (kesim {kesim}, sezon {a.sezon})")

    ix = {b: i for i, b in enumerate(bas)}
    cesit = len(sat)
    acik_c = sum(1 for r in sat if (r[ix["AÇIK"]] or 0) > 0)
    fazla_c = sum(1 for r in sat if (r[ix["FAZLA"]] or 0) > 0)
    acik_a = sum(int(r[ix["AÇIK"]] or 0) for r in sat)
    fazla_a = sum(int(r[ix["FAZLA"]] or 0) for r in sat)
    acik_tl = sum(float(r[ix["AÇIK ₺ (satış fiyatı)"]] or 0) for r in sat)
    fazla_tl = sum(float(r[ix["FAZLA ₺ (maliyet)"]] or 0) for r in sat)
    malsiz = sum(1 for r in sat
                 if (r[ix["FAZLA"]] or 0) > 0 and r[ix["FAZLA ₺ (maliyet)"]] is None)

    wb = Workbook()
    ws = wb.active
    ws.title = "ÖZET"
    ws.cell(1, 1, "SEZON AKSİYON LİSTESİ").font = Font(bold=True, size=15)
    ws.cell(2, 1, f"kesim {kesim:%d.%m.%Y} · sezon {a.sezon} · büyüme %{a.buyume * 100:g} "
                  f"· satılacak = sezonda satılan × {1 + a.buyume:g}"
            ).font = Font(italic=True, size=9, color="555555")

    kutu = [("Ürün çeşidi", ayir(cesit)),
            ("AÇIK ürün", ayir(acik_c)),
            ("AÇIK adet", ayir(acik_a)),
            ("AÇIK ₺ (satış fiyatı)", ayir(acik_tl, True)),
            ("FAZLA ürün", ayir(fazla_c)),
            ("FAZLA adet", ayir(fazla_a)),
            ("FAZLA ₺ (maliyet)", ayir(fazla_tl, True))]
    for i, (k, v) in enumerate(kutu, start=4):
        ws.cell(i, 1, k).font = Font(bold=True, size=11)
        c = ws.cell(i, 2, v)
        c.font = Font(bold=True, size=12)
        c.alignment = Alignment(horizontal="right")
        c.fill = ACIK

    ozet: dict[str, list] = {}
    for r in sat:
        k = ozet.setdefault(r[ix["Kategori"]] or "(boş)", [0, 0, 0.0, 0, 0.0])
        k[0] += 1
        k[1] += int(r[ix["AÇIK"]] or 0)
        k[2] += float(r[ix["AÇIK ₺ (satış fiyatı)"]] or 0)
        k[3] += int(r[ix["FAZLA"]] or 0)
        k[4] += float(r[ix["FAZLA ₺ (maliyet)"]] or 0)
    ozet_sat = sorted(([k] + v for k, v in ozet.items()), key=lambda x: -x[3])

    r0 = 4 + len(kutu) + 1
    ws.cell(r0, 1, "KATEGORİYE GÖRE").font = Font(bold=True, size=12)
    kb = ["Kategori", "Çeşit", "AÇIK adet", "AÇIK ₺", "FAZLA adet", "FAZLA ₺"]
    for j, b in enumerate(kb, start=1):
        h = ws.cell(r0 + 1, j, b)
        h.font = Font(bold=True, color="FFFFFF")
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, horizontal="center")
    for i, r in enumerate(ozet_sat, start=r0 + 2):
        for j, v in enumerate(r, start=1):
            c = ws.cell(i, j, v)
            if j in (2, 3, 5):
                c.number_format = "#,##0"
            elif j in (4, 6):
                c.number_format = '#,##0 "₺"'

    r1 = r0 + len(ozet_sat) + 4
    ws.cell(r1, 1, "NASIL OKUNUR").font = Font(bold=True, size=12)
    notlar = [
        ("Satılacak miktar", f"Sezonda satılan × {1 + a.buyume:g} (büyüme %{a.buyume * 100:g}, "
                             "sabit alındı)."),
        ("Toplam stok", "Mağaza stok + depo (merkez) stok."),
        ("AÇIK", "Satılacak miktar − toplam stok. Sipariş ya da transfer gerekir."),
        ("FAZLA", "Toplam stok − satılacak miktar. İndirim, iade ya da transfer gerekir."),
        ("Sezonda satılan", f"Geçen sezon (Ağu–Eki {a.sezon}) fiilen satılan adet."),
        ("365 günde satılan", "Son 365 gün toplam satış — sezona ne kadar bağımlı olduğunu görmek "
                              "için yanında duruyor."),
        ("⚠ Açık sipariş düşülmedi", "ERP'de 'kapalı' durumu 24.02.2025'ten beri yazılmıyor; açık "
                                     "görünen alış siparişlerinin %86,4'ü bir yıldan eski. Bu "
                                     "yüzden hiçbir sipariş bu listeden düşülmedi."),
        ("⚠ FAZLA ₺ alt sınır", f"{malsiz} üründe maliyet kaydı yok ya da şüpheli. Adetleri "
                                "gerçek, ₺ toplamına girmiyor."),
        ("⚠ Depo stoğu WMS", "Merkez stoğu WMS'ten okunuyor; ERP defteriyle çelişen satırlar "
                             "olabilir. Fiziksel sayım yapılmadan kesin sayılmaz."),
        ("⚠ Tek gün", "Kesim fotoğrafı. Stok gün içinde değişir."),
    ]
    for i, (k, v) in enumerate(notlar, start=r1 + 1):
        ws.cell(i, 1, k).font = Font(bold=True, size=10)
        ws.cell(i, 2, v).alignment = Alignment(wrap_text=True, vertical="top")
    ws.column_dimensions["A"].width = 24
    ws.column_dimensions["B"].width = 96
    for j in range(3, 8):
        ws.column_dimensions[get_column_letter(j)].width = 16

    ws2 = wb.create_sheet("LİSTE")
    for j, b in enumerate(bas, start=1):
        h = ws2.cell(1, j, b)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    ws2.row_dimensions[1].height = 32
    for i, r in enumerate(sat, start=2):
        for j, (v, ad) in enumerate(zip(r, bas), start=1):
            c = ws2.cell(i, j, v)
            if ad in PARA:
                c.number_format = '#,##0 "₺"'
            elif ad in ORAN:
                c.number_format = "0.00"
            elif isinstance(v, int):
                c.number_format = "#,##0"
    genis = {"Ürün": 42, "Kategori yolu": 38, "Yayınevi/Marka": 18, "Barkod": 15,
             "Durum": 24, "Kategori": 18}
    for j, b in enumerate(bas, start=1):
        ws2.column_dimensions[get_column_letter(j)].width = genis.get(b, max(len(b) + 2, 11))
    ws2.freeze_panes = "D2"
    ws2.auto_filter.ref = f"A1:{get_column_letter(len(bas))}{len(sat) + 1}"

    ek = f"-{a.durum}" if a.durum else ""
    cikti = a.cikti or os.path.join(
        KOK, "raporlar", f"sezon-aksiyon-listesi-{kesim:%Y%m%d}{ek}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)

    print(f"YAZILDI: {cikti}")
    print(f"  cesit {ayir(cesit)}")
    print(f"  ACIK  {ayir(acik_c)} urun · {ayir(acik_a)} adet · {ayir(acik_tl)} TL")
    print(f"  FAZLA {ayir(fazla_c)} urun · {ayir(fazla_a)} adet · {ayir(fazla_tl)} TL")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
