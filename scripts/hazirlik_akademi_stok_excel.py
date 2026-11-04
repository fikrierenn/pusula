# -*- coding: utf-8 -*-
"""HAZIRLIK + AKADEMİ KATEGORİSİ — MAĞAZA BAZLI STOK + SATIŞ HIZI + DEVİR (Excel).

GMY isteği 04.11.2026: "hazırlık ve akademi kategorisinin mağaza bazlı stok
durumları" + "satış hızı ve devir kolonları" (merkez depo istenmedi → çıkarıldı).

KATEGORİ: bkm.UrunBilgi.Kategori3 IN ('Akademi','Hazırlık Kitapları').

STOK: dbo.stokSonAltDepo_vw, mağaza 1/4477/4478 (DOĞRU — merkez depo hariç,
WMS kuralı yalnız mekan 12 içindi, burada mekan 12 yok).

SATIŞ HIZI + DEVİR (son 12 ay, 3 mağaza toplamı):
  · Satış tabanı = irsHrk kanonik: ehTip IN (4,5,100,101), net adet = −SUM(ehAdetN)
    (satış çıkış negatif, iade giriş pozitif → net satış = satış − iade).
  · Aylık Hız = 12 ay satış / 12.
  · Devir (yıllık kez) = 12 ay satış adet / mevcut 3-mağaza stok. Stok ≤ 0 ise
    hesaplanamaz ("—"); satış var ama stok yoksa tükenmiş sinyali.
  · ÇIKARIM YOK: ham 12-ay satış adedi de kolonda (devirin arkasındaki sayı).

KAPSAM: 3 mağazada stoğu <> 0 olan ürünler. Her yerde 0 olan (tükenmiş/pasif)
detayda listelenmez; dipnotta çeşit sayısı.

⚠ pyodbc (pymssql DEĞİL): DerinSIS varchar CP1254 (coding-discipline). Salt-okuma.

Kullanım:
    python scripts/hazirlik_akademi_stok_excel.py [--cikti yol.xlsx] [--ay 12]
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
from openpyxl.styles import Alignment, Font, PatternFill, Side, Border
from openpyxl.utils import get_column_letter

if hasattr(sys.stdout, "buffer"):
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MAGAZALAR = [1, 4477, 4478]
MEKAN_AD = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu"}
KATEGORILER = ("Akademi", "Hazırlık Kitapları")

KIRMIZI = PatternFill("solid", fgColor="E30622")
ACIK = PatternFill("solid", fgColor="F7F7F7")
BASLIK_YAZI = Font(bold=True, color="FFFFFF", size=10)
KALIN = Font(bold=True)
SOLUK = Font(italic=True, color="808080", size=9)
KIRMIZI_YAZI = Font(color="E30622")
INCE = Side(style="thin", color="D9D9D9")
KENAR = Border(left=INCE, right=INCE, top=INCE, bottom=INCE)


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


def iso(g: dt.date) -> str:
    return g.strftime("%Y%m%d")


SQL_URUN = """
SELECT u.stkID, u.stkKod, u.stkAd, u.mrkAd, u.Yazar, u.Kategori3,
       u.UrunDurum, u.SatisFiyat
FROM bkm.UrunBilgi u
WHERE u.Kategori3 IN ('Akademi', 'Hazırlık Kitapları')
"""

SQL_MAGAZA_STOK = """
SELECT s.ehstkID AS stkID, s.ehMekan, SUM(s.stok) AS stok
FROM dbo.stokSonAltDepo_vw s WITH (NOLOCK)
JOIN bkm.UrunBilgi u ON u.stkID = s.ehstkID
WHERE u.Kategori3 IN ('Akademi', 'Hazırlık Kitapları')
  AND s.ehMekan IN (1, 4477, 4478)
GROUP BY s.ehstkID, s.ehMekan
"""

# 12-ay satış (net adet) — 3 mağaza toplamı. ? = bas, ? = bit (ISO bitişik)
SQL_SATIS = """
SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS adet
FROM dbo.irsHrk h WITH (NOLOCK)
JOIN bkm.UrunBilgi u ON u.stkID = h.ehstkID
WHERE u.Kategori3 IN ('Akademi', 'Hazırlık Kitapları')
  AND h.ehTip IN (4, 5, 100, 101) AND h.ehMekan IN (1, 4477, 4478)
  AND h.ehTrhS >= ? AND h.ehTrhS < ?
GROUP BY h.ehstkID
"""


def cek(cn: pyodbc.Connection, bas: dt.date, bit: dt.date) -> dict:
    cur = cn.cursor()

    urun: dict[int, dict] = {}
    cur.execute(SQL_URUN)
    for r in cur.fetchall():
        urun[r.stkID] = {
            "_stkID": r.stkID,
            "stkKod": r.stkKod or "",
            "stkAd": (r.stkAd or "").strip(),
            "mrkAd": (r.mrkAd or "").strip(),
            "Yazar": (r.Yazar or "").strip(),
            "Kategori3": r.Kategori3,
            "UrunDurum": r.UrunDurum or "",
            "SatisFiyat": float(r.SatisFiyat or 0),
            1: 0.0, 4477: 0.0, 4478: 0.0, "satis12": 0.0,
        }
    print(f"  ürün (kategori): {len(urun)}")

    cur.execute(SQL_MAGAZA_STOK)
    for r in cur.fetchall():
        u = urun.get(r.stkID)
        if u is not None:
            u[r.ehMekan] = float(r.stok or 0)

    cur.execute(SQL_SATIS, iso(bas), iso(bit))
    for r in cur.fetchall():
        u = urun.get(r.stkID)
        if u is not None:
            u["satis12"] = float(r.adet or 0)

    cur.close()
    return urun


def baslik_satiri(ws, satir, basliklar):
    for j, (ad, gen) in enumerate(basliklar, start=1):
        h = ws.cell(row=satir, column=j, value=ad)
        h.fill = KIRMIZI
        h.font = BASLIK_YAZI
        h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        h.border = KENAR
        ws.column_dimensions[get_column_letter(j)].width = gen
    ws.row_dimensions[satir].height = 30


def yaz(urun: dict, cikti: str, ay: int, bas: dt.date, bit: dt.date):
    wb = Workbook()

    # --- ÖZET ---
    ws = wb.active
    ws.title = "Özet"
    ws.sheet_view.showGridLines = False
    ws["A1"] = "Hazırlık + Akademi — Mağaza Bazlı Stok, Satış Hızı, Devir"
    ws["A1"].font = Font(bold=True, size=14, color="E30622")
    ws["A2"] = (f"Üretim: {dt.datetime.now():%d.%m.%Y %H:%M} · Stok: stokSonAltDepo_vw "
                f"· Satış: {bas:%d.%m.%Y}–{bit:%d.%m.%Y} ({ay} ay, irsHrk kanonik)")
    ws["A2"].font = SOLUK

    bas_o = [("Kategori", 22), ("Mağaza", 12), ("Çeşit", 11), ("Stok Adet", 13),
             (f"{ay} Ay Satış", 13), ("Aylık Hız", 12), ("Devir (yıl/kez)", 14),
             ("Stok Değeri (₺)", 18)]
    baslik_satiri(ws, 4, bas_o)

    satir = 5
    for kat in KATEGORILER:
        ku = [u for u in urun.values() if u["Kategori3"] == kat]
        for mk in MAGAZALAR:
            cesit = sum(1 for u in ku if u[mk] != 0)
            stok = sum(u[mk] for u in ku)
            # satış/devir mağaza bazlı değil (satis12 = 3-mağaza top). Özette kategori
            # düzeyinde satış/devir satırı aşağıda; mağaza satırında yalnız stok.
            deger = sum(u[mk] * u["SatisFiyat"] for u in ku if u[mk] > 0)
            _satir_yaz(ws, satir, [kat, MEKAN_AD[mk], cesit, round(stok), None, None, None, round(deger, 2)])
            satir += 1
        # kategori toplamı + satış/devir
        kstok = sum(u[m] for u in ku for m in MAGAZALAR)
        ksat = sum(u["satis12"] for u in ku)
        khiz = ksat / ay if ay else 0
        kdev = (ksat / kstok) if kstok > 0 else None
        kdeg = sum(u[m] * u["SatisFiyat"] for u in ku for m in MAGAZALAR if u[m] > 0)
        _satir_yaz(ws, satir, [f"{kat} — TOPLAM", "3 mağaza", None, round(kstok),
                               round(ksat), round(khiz, 1),
                               round(kdev, 2) if kdev is not None else "—", round(kdeg, 2)], kalin=True)
        satir += 2

    satir += 1
    sifir = sum(1 for u in urun.values() if u[1] == 0 and u[4477] == 0 and u[4478] == 0)
    ws.cell(row=satir, column=1, value=(
        f"Not: 3 mağazada stoğu 0 olan {sifir:,} çeşit (tükenmiş/pasif) detayda listelenmez. "
        f"Devir = {ay} ay satış ÷ mevcut stok (stok 0 → '—'). "
        f"Değer = adet × satış fiyatı (kitap KDV %0), maliyet değil.")).font = SOLUK

    # --- ÜRÜN DETAY ---
    wd = wb.create_sheet("Ürün Detay")
    wd.sheet_view.showGridLines = False
    bas_d = [("stkID", 10), ("Barkod/Kod", 16), ("Ürün Adı", 44), ("Yayınevi", 22),
             ("Yazar", 20), ("Kategori", 16), ("Durum", 9),
             ("FSM", 8), ("Özlüce", 8), ("İst.Yolu", 9), ("Stok Top.", 10),
             (f"{ay} Ay Satış", 11), ("Aylık Hız", 10), ("Devir", 9), ("Ay Stok", 9),
             ("Satış Fiyatı", 11), ("Değer (₺)", 13)]
    baslik_satiri(wd, 1, bas_d)
    wd.freeze_panes = "A2"

    satilabilir = [u for u in urun.values() if u[1] != 0 or u[4477] != 0 or u[4478] != 0]
    satilabilir.sort(key=lambda u: u["satis12"], reverse=True)

    r = 2
    for u in satilabilir:
        stok = u[1] + u[4477] + u[4478]
        sat = u["satis12"]
        hiz = sat / ay if ay else 0
        devir = (sat / stok) if stok > 0 else None
        ay_stok = (stok / hiz) if hiz > 0 else None   # months of supply
        deger = sum(u[m] * u["SatisFiyat"] for m in MAGAZALAR if u[m] > 0)
        vals = [u["_stkID"], u["stkKod"], u["stkAd"], u["mrkAd"], u["Yazar"],
                u["Kategori3"], u["UrunDurum"],
                round(u[1]), round(u[4477]), round(u[4478]), round(stok),
                round(sat), round(hiz, 1),
                round(devir, 2) if devir is not None else "—",
                round(ay_stok, 1) if ay_stok is not None else "—",
                u["SatisFiyat"], round(deger, 2)]
        for j, v in enumerate(vals, start=1):
            c = wd.cell(row=r, column=j, value=v)
            c.border = KENAR
            if j in (8, 9, 10, 11, 12):
                c.number_format = "#,##0"
                if isinstance(v, (int, float)) and v < 0:
                    c.font = KIRMIZI_YAZI
            elif j in (13, 14, 15):
                c.number_format = "#,##0.0"
            elif j in (16, 17):
                c.number_format = "#,##0.00"
        # tükenmiş-ama-satan vurgu: stok<=0 ve satış>0
        if stok <= 0 and sat > 0:
            wd.cell(row=r, column=11).font = KIRMIZI_YAZI
        if r % 2 == 1:
            for j in range(1, len(vals) + 1):
                cc = wd.cell(row=r, column=j)
                if cc.fill.fgColor.rgb in (None, "00000000"):
                    cc.fill = ACIK
        r += 1

    print(f"  detay satır: {r - 2}")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)
    print(f"BITTI · {cikti}")


def _satir_yaz(ws, satir, vals, kalin=False):
    for j, v in enumerate(vals, start=1):
        if v is None:
            continue
        c = ws.cell(row=satir, column=j, value=v)
        c.border = KENAR
        if kalin:
            c.font = KALIN
        if j in (3, 4, 5):
            c.number_format = "#,##0"
        elif j == 6:
            c.number_format = "#,##0.0"
        elif j == 8:
            c.number_format = "#,##0.00"
    if not kalin and satir % 2 == 0:
        for j in range(1, len(vals) + 1):
            ws.cell(row=satir, column=j).fill = ACIK


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ay", type=int, default=12, help="satış hızı penceresi (ay)")
    ap.add_argument("--cikti", default=os.path.join(
        KOK, "raporlar", f"hazirlik-akademi-stok-{dt.datetime.now():%Y%m%d}.xlsx"))
    args = ap.parse_args()

    bit = dt.date.today()
    bas = dt.date(bit.year - args.ay // 12, bit.month, bit.day) if args.ay == 12 \
        else bit - dt.timedelta(days=round(args.ay * 30.44))

    env = env_oku(os.path.join(KOK, ".env"))
    print("Bağlanıyor (DerinSISBkm, salt-okuma)...")
    cn = baglan(env)
    print(f"Stok + {args.ay} ay satış çekiliyor ({bas:%d.%m.%Y}–{bit:%d.%m.%Y})...")
    urun = cek(cn, bas, bit)
    cn.close()
    yaz(urun, args.cikti, args.ay, bas, bit)


if __name__ == "__main__":
    main()
