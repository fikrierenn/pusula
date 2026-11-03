# -*- coding: utf-8 -*-
"""
ODAK'a (firma 9525 ODAK KİTAP-POİNT) yapılan İADE İRSALİYELERİ — mağaza bazlı analiz.

Tanım (canlı doğrulandı 2026-11-03):
  İade irsaliyesi = dbo.irs, eFirma = 9525 (ODAK KİTAP-POİNT İNTERNET TEKNOLOJİLERİ),
  eTip IN (12 'Alış Mağaza İade', 2 'Alış İade'), eTarih >= BAS.
  ODAK İADE DEPOSU (mekan 4480) DEĞİL — o pasif, 20 Eylül sonrası 0 hareket.
  Adet = SUM(ABS(ehAdetN)) (iade = çıkış, negatif). Tutar = SUM(ehTutarN) KDV-HARİÇ.
Mağaza (eMekan): 1=FSM · 4477=Özlüce · 4478=İst.Yolu · 12=Merkez Depo.

Sayfalar: Magaza Ozeti · Irsaliye Listesi · Urun Detay
Kullanım: python scripts/odak_iade_analiz.py [YYYYMMDD_bas]   (varsayılan 20260920)
"""
import os, sys, re, datetime
import pyodbc
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

BAS = sys.argv[1] if len(sys.argv) > 1 else "20260920"
if not re.fullmatch(r"\d{8}", BAS):
    sys.exit("Tarih YYYYMMDD olmalı (örn. 20260920)")
ODAK = 9525
MEKAN = {1: "FSM", 4477: "Özlüce", 4478: "İst.Yolu", 12: "Merkez Depo"}

ENV = {}
with open(os.path.join(os.path.dirname(__file__), "..", ".env"), encoding="utf-8") as f:
    for ln in f:
        m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
        if m and not ln.lstrip().startswith("#"):
            ENV[m.group(1)] = m.group(2).strip().strip('"')
host = ENV["MSSQL_HOST"]; port = ENV.get("MSSQL_PORT", "1433")
if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
    sys.exit("Geçersiz host/port (.env)")
cn = pyodbc.connect(
    f"Driver={{ODBC Driver 18 for SQL Server}};Server={host},{port};Database=DerinSISBkm;"
    f"UID={ENV['MSSQL_USER']};PWD={ENV['MSSQL_PASSWORD']};TrustServerCertificate=yes;Timeout=30", timeout=30)
cn.timeout = 600
cur = cn.cursor()
WHERE = f"i.eFirma={ODAK} AND i.eTip IN (2,12) AND i.eTarih >= '{BAS}'"
print(f"ODAK iade çekiliyor (firma {ODAK}, eTip 2/12, tarih >= {BAS})...", flush=True)

# 1) Mağaza özeti
cur.execute(f"""
    SELECT i.eMekan, COUNT(DISTINCT i.eID) AS irsaliye, COUNT(*) AS satir,
           SUM(ABS(h.ehAdetN)) AS adet, SUM(h.ehTutarN) AS tutar,
           COUNT(DISTINCT h.ehstkID) AS cesit
    FROM dbo.irs i WITH(NOLOCK)
    JOIN dbo.irsHrk h WITH(NOLOCK) ON h.ehID = i.eID
    WHERE {WHERE}
    GROUP BY i.eMekan""")
ozet = [dict(mekan=MEKAN.get(r[0], str(r[0])), irsaliye=r[1], satir=r[2],
             adet=int(r[3] or 0), tutar=float(r[4] or 0), cesit=r[5]) for r in cur.fetchall()]
ozet.sort(key=lambda x: -x["tutar"])

# 2) İrsaliye listesi
cur.execute(f"""
    SELECT i.eID, i.eNo, i.eTarih, i.eMekan, i.eTip,
           COUNT(*) AS satir, SUM(ABS(h.ehAdetN)) AS adet, SUM(h.ehTutarN) AS tutar,
           COUNT(DISTINCT h.ehstkID) AS cesit
    FROM dbo.irs i WITH(NOLOCK)
    JOIN dbo.irsHrk h WITH(NOLOCK) ON h.ehID = i.eID
    WHERE {WHERE}
    GROUP BY i.eID, i.eNo, i.eTarih, i.eMekan, i.eTip""")
irsaliyeler = [dict(eno=r[1], tarih=r[2], mekan=MEKAN.get(r[3], str(r[3])),
                    tip=("Alış Mağaza İade" if r[4] == 12 else "Alış İade"),
                    satir=r[5], adet=int(r[6] or 0), tutar=float(r[7] or 0), cesit=r[8])
               for r in cur.fetchall()]
irsaliyeler.sort(key=lambda x: (x["tarih"], x["mekan"]))

# 3) Ürün detay (mağaza × ürün)
cur.execute(f"""
    SELECT i.eMekan, h.ehstkID, u.stkAd, u.mrkAd, u.Kategori3,
           SUM(ABS(h.ehAdetN)) AS adet, SUM(h.ehTutarN) AS tutar
    FROM dbo.irs i WITH(NOLOCK)
    JOIN dbo.irsHrk h WITH(NOLOCK) ON h.ehID = i.eID
    LEFT JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = h.ehstkID
    WHERE {WHERE}
    GROUP BY i.eMekan, h.ehstkID, u.stkAd, u.mrkAd, u.Kategori3""")
urunler = [dict(mekan=MEKAN.get(r[0], str(r[0])), sid=r[1], ad=(r[2] or "").strip(),
                mrk=(r[3] or "").strip(), kat=(r[4] or "").strip(),
                adet=int(r[5] or 0), tutar=float(r[6] or 0)) for r in cur.fetchall()]
urunler.sort(key=lambda x: -x["tutar"])
cur.close(); cn.close()
print(f"  {len(ozet)} mekan · {len(irsaliyeler)} irsaliye · {len(urunler)} ürün satırı", flush=True)

# ================= EXCEL =================
wb = openpyxl.Workbook()
HB = Font(bold=True, color="FFFFFF"); HF = PatternFill("solid", fgColor="E30622")
TOP = Font(bold=True)
INT = "#,##0"; TL = "#,##0.00"; DT = "dd.mm.yyyy"

def sheet(ad, kolonlar, satirlar, toplam=True):
    w = wb.create_sheet(ad)
    for j, (bas, *_x) in enumerate(kolonlar, 1):
        c = w.cell(row=1, column=j, value=bas); c.font = HB; c.fill = HF
        c.alignment = Alignment(vertical="center", wrap_text=True)
    for i, s in enumerate(satirlar, 2):
        for j, (bas, key, nf, wd) in enumerate(kolonlar, 1):
            c = w.cell(row=i, column=j, value=s.get(key))
            if nf: c.number_format = nf
    if toplam and satirlar:
        tr = len(satirlar) + 2
        w.cell(row=tr, column=1, value="TOPLAM").font = TOP
        for j, (bas, key, nf, wd) in enumerate(kolonlar, 1):
            if nf in (INT, TL) and key in ("irsaliye", "satir", "adet", "tutar", "cesit"):
                col = get_column_letter(j)
                c = w.cell(row=tr, column=j, value=f"=SUM({col}2:{col}{tr-1})")
                c.number_format = nf; c.font = TOP
    for j, (bas, key, nf, wd) in enumerate(kolonlar, 1):
        w.column_dimensions[get_column_letter(j)].width = wd
    w.freeze_panes = "A2"
    w.auto_filter.ref = f"A1:{get_column_letter(len(kolonlar))}{1 + max(len(satirlar), 1)}"

sheet("Magaza Ozeti",
      [("Mağaza", "mekan", None, 14), ("İrsaliye", "irsaliye", INT, 10), ("Satır", "satir", INT, 9),
       ("İade Adet", "adet", INT, 11), ("İade Tutar (KDV hariç)", "tutar", TL, 20), ("Çeşit", "cesit", INT, 9)],
      ozet)

sheet("Irsaliye Listesi",
      [("İrsaliye No", "eno", None, 16), ("Tarih", "tarih", DT, 12), ("Mağaza", "mekan", None, 13),
       ("Tip", "tip", None, 18), ("Satır", "satir", INT, 8), ("İade Adet", "adet", INT, 11),
       ("İade Tutar (KDV hariç)", "tutar", TL, 20), ("Çeşit", "cesit", INT, 8)],
      irsaliyeler)

sheet("Urun Detay",
      [("Mağaza", "mekan", None, 13), ("stkID", "sid", None, 9), ("Ürün", "ad", None, 40),
       ("Marka", "mrk", None, 16), ("Kategori", "kat", None, 11),
       ("İade Adet", "adet", INT, 11), ("İade Tutar (KDV hariç)", "tutar", TL, 20)],
      urunler, toplam=False)

if "Sheet" in wb.sheetnames:
    del wb["Sheet"]
out = os.path.join(os.path.dirname(__file__), "..", "raporlar", f"odak-iade-analiz-{BAS}-{datetime.date.today():%Y%m%d}.xlsx")
os.makedirs(os.path.dirname(out), exist_ok=True)
wb.save(out)
print("BITTI ·", os.path.abspath(out), flush=True)
