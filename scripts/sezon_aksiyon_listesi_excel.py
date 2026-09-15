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
SELECT t.stkAd                                       AS [Ürün],
       t.Kategori3                                   AS [Kategori],
       t.BarkodAna                                   AS [Barkod],
       t.SatisToplam                                 AS [365 günde satılan],
       t.SezonToplam                                 AS [Sezonda satılan],
       s.Satilacak                                   AS [Satılacak],
       t.MagazaStok                                  AS [Mağaza],
       t.MerkezStok                                  AS [Depo],
       s.Elde                                        AS [Toplam stok],
       CASE WHEN s.Satilacak > s.Elde THEN s.Satilacak - s.Elde ELSE 0 END AS [AÇIK],
       CASE WHEN s.Elde > s.Satilacak THEN s.Elde - s.Satilacak ELSE 0 END AS [FAZLA],
       -- TEK tutar kolonu: AÇIK satırda satış fiyatıyla, FAZLA satırda maliyetle.
       -- İki ayrı kolon vardı; çoğu satırda biri hep boştu ve "toplanabilir" görünüyordu.
       CONVERT(decimal(18,2), CASE
            WHEN s.Satilacak > s.Elde THEN (s.Satilacak - s.Elde) * t.SatisFiyat
            WHEN s.Elde > s.Satilacak AND {MALIYET_GECERLI}
                 THEN (s.Elde - s.Satilacak) * t.BirimMaliyet END)          AS [Tutar]
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

PARA = {"Tutar"}


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

        # ⚠ Büyüme artık SELECT'te kolon DEĞİL (sabit sayı, başlıkta yazıyor) →
        #   yalnız CROSS APPLY'daki tek ? kaldı. Sıra SQL'deki ? sırasıdır.
        cur.execute(SQL, a.buyume, kesim, a.sezon, yalniz_acik, yalniz_fazla)
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
    acik_tl = sum(float(r[ix["Tutar"]] or 0) for r in sat if (r[ix["AÇIK"]] or 0) > 0)
    fazla_tl = sum(float(r[ix["Tutar"]] or 0) for r in sat if (r[ix["FAZLA"]] or 0) > 0)
    malsiz = sum(1 for r in sat
                 if (r[ix["FAZLA"]] or 0) > 0 and r[ix["Tutar"]] is None)

    # ══ TEK SAYFA ═════════════════════════════════════════════════════════════
    # GMY 15.09.2026: "özete gerek yok". ÖZET sayfası (kutular + kategori tablosu +
    # 5 madde not) KALDIRILDI. Sınırlar SİLİNMEDİ — başlığın üstünde tek satır kaldı;
    # dosya elden ele dolaşıyor, rakam bağlamsız okunmasın.
    wb = Workbook()
    ws = wb.active
    ws.title = "LİSTE"

    ust = (f"Kesim {kesim:%d.%m.%Y} · satılacak = sezonda satılan × {1 + a.buyume:g} "
           f"(büyüme %{a.buyume * 100:g}) · AÇIK = satılacak − (mağaza+depo), FAZLA = tersi · "
           f"Tutar: AÇIK'ta satış fiyatı, FAZLA'da maliyet — ikisi toplanmaz · "
           f"Açık sipariş DÜŞÜLMEDİ (ERP'de kapatma alanı 24.02.2025'ten beri yazılmıyor) · "
           f"FAZLA tutarı alt sınır ({malsiz} üründe maliyet yok/şüpheli) · depo stoğu WMS'ten")
    ws.cell(1, 1, ust).font = Font(italic=True, size=9, color="555555")
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(bas))
    ws.cell(1, 1).alignment = Alignment(wrap_text=True, vertical="center")
    ws.row_dimensions[1].height = 30

    for j, b in enumerate(bas, start=1):
        h = ws.cell(2, j, b)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    ws.row_dimensions[2].height = 30

    for i, r in enumerate(sat, start=3):
        for j, (v, ad) in enumerate(zip(r, bas), start=1):
            c = ws.cell(i, j, v)
            if ad in PARA:
                c.number_format = '#,##0 "₺"'
            elif isinstance(v, int):
                c.number_format = "#,##0"

    genis = {"Ürün": 45, "Kategori": 18, "Barkod": 15}
    for j, b in enumerate(bas, start=1):
        ws.column_dimensions[get_column_letter(j)].width = genis.get(b, max(len(b) + 2, 11))
    ws.freeze_panes = "D3"
    ws.auto_filter.ref = f"A2:{get_column_letter(len(bas))}{len(sat) + 2}"

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
