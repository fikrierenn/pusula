# -*- coding: utf-8 -*-
"""
ODAK (firma 9525) ALIŞ–SATIŞ–İADE hesap-sorma analizi — "neden bu kadar alındı?"
Dönem: Ağu–Kas 2026 (2026-08-01 .. 2026-12-01 hariç). Mağaza bazlı (eMekan).

Tanımlar (canlı doğrulandı 2026-11-03):
  GELİŞ (alış)   = irs eFirma=9525, eTip IN (10 'Yerel Alım', 0 'Alış') · adet=SUM(ehAdetN) giriş(+), tutar=SUM(ehTutarN) KDV-hariç
  İADE (gerçek)  = irs eFirma=9525, eTip IN (12,2), Neden <> 246 · adet=SUM(ABS(ehAdetN)), tutar=SUM(ehTutarN)
  EKSİK (çıkar)  = aynı ama Neden=246 'eksik gelen mal' — ÜRÜN İADESİ DEĞİL (tedarikçi eksik gönderimi kesintisi); ayrı kolonda, iadeye katılmaz
  SATIŞ          = dbo.irs_vw net (eTip 1,4,3,5,100,101; eDurum=1 veya 100/101), eMekan mağaza — ürünün o mağazadaki toplam satışı
  KALAN STOK     = mağaza: stokSon_vw anlık · merkez depo(12): WMS depo.stok_adres_palet_vw (sema: depo defteri güvenilmez, WMS kullan)
  DÖNEM BAŞI STOK= anlık stoktan GERİ GİDEREK (01.08.2026): mağaza = kalan − Σ ehAdetN(ehTrhS>=T1) [defter; %1 kanıtlı vs 2026-07-31 snapshot] ·
                   merkez depo = WMS_kalan − Σ piAdet(pikTarih>=T1) [palet hareket; iç transfer net'te götürür, net = sınır-geçen]
Mağaza: 1=FSM · 4477=Özlüce · 4478=İst.Yolu · 12=Merkez Depo.

⚠ CONFOUND (satinalma-danisman): (a) EKSİK (246) over-buy DEĞİL, ayrıldı. (b) ODAK malı İADE HAKLI/konsinye
olabilir → yüksek iade saf zarar olmayabilir (teyit: Ayarlar/sözleşme). (c) Ağu-Eki okul/sınav sezonu →
yüksek alım sezonla meşru olabilir. (d) Satış ürün-bazlı toplam (kaynak ayrıştırılamaz, stok değiştirilebilir).
(e) Alıcı (insID) boyutu bu çıktıda yok → kişiye değil ALIM KARARINA bakılır.
GERÇEK OVER-BUY SİNYALİ: dönem başı stok ZATEN yüksekken alış + düşük satış + yüksek kalan stok. Sell-through =
satış / (dönem başı + alış). Düşük sell-through + yüksek kalan = "zaten vardı, neden aldın". Dönem başı rekonstrüksiyon
negatife düşerse 0'a sabitlenir (ürün T1'de yoktu / defter gürültüsü).

Sayfalar: Magaza Ozeti · Marka Ozeti · Urun Detay
Kullanım: python scripts/odak_hesapsorma_analiz.py
"""
import os, sys, re, datetime
import pyodbc
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

T1, T2 = "20260801", "20261201"
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
cn.timeout = 900
cur = cn.cursor()
print(f"ODAK alış/iade/satış çekiliyor ({T1}..{T2})...", flush=True)

D = {}   # (mekan, stkID) -> alanlar
def slot(mk, sid):
    return D.setdefault((mk, sid), dict(alis_adet=0, alis_tutar=0.0, iade_adet=0, iade_tutar=0.0,
                                        eksik_adet=0, eksik_tutar=0.0, satis_adet=0, stok=0, stok_basi=0))

# GELİŞ (alış)
cur.execute(f"""SELECT i.eMekan, h.ehstkID, SUM(h.ehAdetN), SUM(h.ehTutarN)
    FROM dbo.irs i WITH(NOLOCK) JOIN dbo.irsHrk h WITH(NOLOCK) ON h.ehID=i.eID
    WHERE i.eFirma={ODAK} AND i.eTip IN (0,10) AND i.eTarih>='{T1}' AND i.eTarih<'{T2}'
    GROUP BY i.eMekan, h.ehstkID""")
for mk, sid, ad, tt in cur.fetchall():
    s = slot(mk, sid); s["alis_adet"] = int(ad or 0); s["alis_tutar"] = float(tt or 0)

# İADE (gerçek, Neden<>246) + EKSİK (246)
cur.execute(f"""SELECT i.eMekan, h.ehstkID, CASE WHEN i.Neden=246 THEN 1 ELSE 0 END eksik,
       SUM(ABS(h.ehAdetN)), SUM(h.ehTutarN)
    FROM dbo.irs i WITH(NOLOCK) JOIN dbo.irsHrk h WITH(NOLOCK) ON h.ehID=i.eID
    WHERE i.eFirma={ODAK} AND i.eTip IN (2,12) AND i.eTarih>='{T1}' AND i.eTarih<'{T2}'
    GROUP BY i.eMekan, h.ehstkID, CASE WHEN i.Neden=246 THEN 1 ELSE 0 END""")
for mk, sid, eksik, ad, tt in cur.fetchall():
    s = slot(mk, sid)
    if eksik:
        s["eksik_adet"] = int(ad or 0); s["eksik_tutar"] = float(tt or 0)
    else:
        s["iade_adet"] = int(ad or 0); s["iade_tutar"] = float(tt or 0)

# SATIŞ (mağaza net, ürün-bazlı — kaynak firma ayrımı yok)
cur.execute(f"""SELECT i.eMekan, i.ehStkID, CONVERT(int,-1*SUM(i.ehAdet))
    FROM dbo.irs_vw i WITH(NOLOCK)
    WHERE i.eTip IN (1,4,3,5,100,101) AND (i.eDurum=1 OR i.eTip IN (100,101))
      AND i.eMekan IN (1,4477,4478) AND i.eTarih>='{T1}' AND i.eTarih<'{T2}'
    GROUP BY i.eMekan, i.ehStkID""")
while True:
    rows = cur.fetchmany(50000)
    if not rows:
        break
    for mk, sid, q in rows:
        if (mk, sid) in D:                      # yalnız ODAK-alışı olan ürünler
            D[(mk, sid)]["satis_adet"] = int(q or 0)

# KALAN STOK — anlık mağaza (stokSon_vw defter; mağaza için güvenilir)
cur.execute("""SELECT ehMekan, ehstkID, SUM(stok) FROM dbo.stokSon_vw WITH(NOLOCK)
    WHERE ehMekan IN (1,4477,4478) GROUP BY ehMekan, ehstkID""")
for mk, sid, st in cur.fetchall():
    if (mk, sid) in D:
        D[(mk, sid)]["stok"] = int(st or 0)

# KALAN STOK — merkez depo (12) WMS (sema: depo defteri güvenilmez → WMS)
cur.execute("""SELECT stkID, SUM(Stok) FROM depo.stok_adres_palet_vw WITH(NOLOCK) GROUP BY stkID""")
for sid, st in cur.fetchall():
    if (12, sid) in D:
        D[(12, sid)]["stok"] = int(st or 0)

# DÖNEM BAŞI STOK — mağaza: anlık − net irsHrk hareket(ehTrhS>=T1) [defter, %1 kanıtlı]
cur.execute(f"""SELECT ehMekan, ehstkID, SUM(ehAdetN) FROM dbo.irsHrk WITH(NOLOCK)
    WHERE ehMekan IN (1,4477,4478) AND ehTrhS>='{T1}' GROUP BY ehMekan, ehstkID""")
for mk, sid, net in cur.fetchall():
    if (mk, sid) in D:
        D[(mk, sid)]["stok_basi"] = D[(mk, sid)]["stok"] - int(net or 0)

# DÖNEM BAŞI STOK — merkez depo: WMS kalan − net palet hareket(pikTarih>=T1) [iç transfer net'te götürür]
cur.execute(f"""SELECT piStkID, SUM(piAdet) FROM depo.paletIcHrk WITH(NOLOCK)
    WHERE pikTarih>='{T1}' GROUP BY piStkID""")
for sid, net in cur.fetchall():
    if (12, sid) in D:
        D[(12, sid)]["stok_basi"] = D[(12, sid)]["stok"] - int(net or 0)

# dönem başı negatif = ürün T1'de yoktu / defter gürültüsü → 0'a sabitle
for s in D.values():
    if s["stok_basi"] < 0:
        s["stok_basi"] = 0

# ÜRÜN MASTER
sids = sorted({sid for (_mk, sid) in D})
master = {}
CH = 1000
for k in range(0, len(sids), CH):
    chunk = sids[k:k + CH]
    ph = ",".join("?" * len(chunk))
    cur.execute(f"SELECT stkID, BarkodAna, stkAd, mrkAd, Kategori3, CONVERT(float,SatisFiyat) FROM bkm.UrunBilgi WITH(NOLOCK) WHERE stkID IN ({ph})", *chunk)
    for sid, brk, ad, mrk, kat, fy in cur.fetchall():
        master[sid] = (brk or "", (ad or "").strip(), (mrk or "").strip(), (kat or "").strip(), float(fy or 0))
cur.close(); cn.close()
print(f"  {len(D)} mağaza×ürün satırı · {len(master)} ürün", flush=True)

# satır listesi
rows_all = []
for (mk, sid), s in D.items():
    brk, ad, mrk, kat, fy = master.get(sid, ("", "", "", "", 0))
    rows_all.append(dict(mekan=MEKAN.get(mk, str(mk)), sid=sid, brk=brk, ad=ad, mrk=mrk, kat=kat, uf=fy, **s))
rows_all.sort(key=lambda r: -r["alis_tutar"])

# ================= EXCEL =================
wb = openpyxl.Workbook()
HB = Font(bold=True, color="FFFFFF"); HF = PatternFill("solid", fgColor="E30622"); TOP = Font(bold=True)
INT = "#,##0"; TL = "#,##0"; PCT = "0%"

def F(fn): return ("F", fn)
def sheet(ad, kolonlar, satirlar, toplam_keys=()):
    w = wb.create_sheet(ad)
    C = {b: get_column_letter(j) for j, (b, *_x) in enumerate(kolonlar, 1)}
    for j, (b, *_x) in enumerate(kolonlar, 1):
        c = w.cell(row=1, column=j, value=b); c.font = HB; c.fill = HF
        c.alignment = Alignment(vertical="center", wrap_text=True)
    for i, s in enumerate(satirlar, 2):
        for j, (b, spec, nf, wd) in enumerate(kolonlar, 1):
            if isinstance(spec, tuple) and spec and spec[0] == "F":
                v = spec[1](i, C)
            elif callable(spec):
                v = spec(s)
            else:
                v = s.get(spec)
            c = w.cell(row=i, column=j, value=v)
            if nf: c.number_format = nf
    if toplam_keys and satirlar:
        tr = len(satirlar) + 2
        w.cell(row=tr, column=1, value="TOPLAM").font = TOP
        for j, (b, spec, nf, wd) in enumerate(kolonlar, 1):
            if spec in toplam_keys:
                col = get_column_letter(j)
                c = w.cell(row=tr, column=j, value=f"=SUM({col}2:{col}{tr-1})"); c.number_format = nf; c.font = TOP
    for j, (b, spec, nf, wd) in enumerate(kolonlar, 1):
        w.column_dimensions[get_column_letter(j)].width = wd
    w.freeze_panes = "A2"
    w.auto_filter.ref = f"A1:{get_column_letter(len(kolonlar))}{1 + max(len(satirlar),1)}"

# oran formülleri (satış/alış, iade/alış) — alış kolonuna göre
def f_sell(ac, sc): return F(lambda r, C: f"=IF({C[ac]}{r}>0,{C[sc]}{r}/{C[ac]}{r},\"\")")
def f_iade(ac, ic): return F(lambda r, C: f"=IF({C[ac]}{r}>0,{C[ic]}{r}/{C[ac]}{r},\"\")")
# sell-through = satış / (dönem başı stok + alış) — düşük = elde kalmış, "zaten vardı neden aldın"
def f_st(bc, ac, sc): return F(lambda r, C: f"=IF({C[bc]}{r}+{C[ac]}{r}>0,{C[sc]}{r}/({C[bc]}{r}+{C[ac]}{r}),\"\")")

# --- Mağaza Özeti ---
mo = {}
for r in rows_all:
    m = mo.setdefault(r["mekan"], dict(mekan=r["mekan"], stok_basi=0, alis_adet=0, alis_tutar=0, satis_adet=0,
                                       iade_adet=0, iade_tutar=0, eksik_adet=0, eksik_tutar=0, stok=0, cesit=0))
    for k in ("stok_basi", "alis_adet", "alis_tutar", "satis_adet", "iade_adet", "iade_tutar", "eksik_adet", "eksik_tutar", "stok"):
        m[k] += r[k]
    m["cesit"] += 1
mozet = sorted(mo.values(), key=lambda x: -x["alis_tutar"])
sheet("Magaza Ozeti",
      [("Mağaza", "mekan", None, 13), ("Çeşit", "cesit", INT, 8),
       ("Dönem Başı Stok", "stok_basi", INT, 12),
       ("Alış Adet", "alis_adet", INT, 11), ("Alış Tutar", "alis_tutar", TL, 14),
       ("Satış Adet", "satis_adet", INT, 11), ("Kalan Stok", "stok", INT, 11),
       ("İade Adet", "iade_adet", INT, 10), ("İade Tutar", "iade_tutar", TL, 13),
       ("Eksik Adet", "eksik_adet", INT, 10), ("Eksik Tutar", "eksik_tutar", TL, 13),
       ("Satış/Alış", f_sell("Alış Adet", "Satış Adet"), PCT, 10),
       ("İade/Alış", f_iade("Alış Adet", "İade Adet"), PCT, 10),
       ("Sell-through", f_st("Dönem Başı Stok", "Alış Adet", "Satış Adet"), PCT, 11)],
      mozet, toplam_keys=("stok_basi", "alis_adet", "alis_tutar", "satis_adet", "iade_adet", "iade_tutar", "eksik_adet", "eksik_tutar", "stok", "cesit"))

# --- Marka Özeti ---
mk = {}
for r in rows_all:
    b = mk.setdefault(r["mrk"] or "(boş)", dict(mrk=r["mrk"] or "(boş)", stok_basi=0, alis_adet=0, alis_tutar=0,
                                                satis_adet=0, iade_adet=0, iade_tutar=0, stok=0, cesit=0))
    for k in ("stok_basi", "alis_adet", "alis_tutar", "satis_adet", "iade_adet", "iade_tutar", "stok"):
        b[k] += r[k]
    b["cesit"] += 1
marka = sorted(mk.values(), key=lambda x: -x["alis_tutar"])
sheet("Marka Ozeti",
      [("Marka", "mrk", None, 26), ("Çeşit", "cesit", INT, 8),
       ("Dönem Başı Stok", "stok_basi", INT, 12),
       ("Alış Adet", "alis_adet", INT, 11), ("Alış Tutar", "alis_tutar", TL, 14),
       ("Satış Adet", "satis_adet", INT, 11), ("Kalan Stok", "stok", INT, 11),
       ("İade Adet", "iade_adet", INT, 10), ("İade Tutar", "iade_tutar", TL, 13),
       ("Satış/Alış", f_sell("Alış Adet", "Satış Adet"), PCT, 10),
       ("İade/Alış", f_iade("Alış Adet", "İade Adet"), PCT, 10),
       ("Sell-through", f_st("Dönem Başı Stok", "Alış Adet", "Satış Adet"), PCT, 11)],
      marka, toplam_keys=("stok_basi", "alis_adet", "alis_tutar", "satis_adet", "iade_adet", "iade_tutar", "stok", "cesit"))

# --- Ürün Detay ---
sheet("Urun Detay",
      [("Mağaza", "mekan", None, 12), ("stkID", "sid", None, 9), ("Barkod", "brk", None, 15),
       ("Ürün", "ad", None, 38), ("Marka", "mrk", None, 16), ("Kategori", "kat", None, 11),
       ("Üst Fiyat", "uf", TL, 9),
       ("Dönem Başı Stok", "stok_basi", INT, 12),
       ("Alış Adet", "alis_adet", INT, 10), ("Alış Tutar", "alis_tutar", TL, 13),
       ("Satış Adet", "satis_adet", INT, 10), ("Kalan Stok", "stok", INT, 10),
       ("İade Adet", "iade_adet", INT, 9), ("İade Tutar", "iade_tutar", TL, 12),
       ("Eksik Adet", "eksik_adet", INT, 9), ("Eksik Tutar", "eksik_tutar", TL, 12),
       ("Satış/Alış", f_sell("Alış Adet", "Satış Adet"), PCT, 10),
       ("İade/Alış", f_iade("Alış Adet", "İade Adet"), PCT, 10),
       ("Sell-through", f_st("Dönem Başı Stok", "Alış Adet", "Satış Adet"), PCT, 11)],
      rows_all)

if "Sheet" in wb.sheetnames:
    del wb["Sheet"]
out = os.path.join(os.path.dirname(__file__), "..", "raporlar", f"odak-hesapsorma-{T1}-{T2}.xlsx")
os.makedirs(os.path.dirname(out), exist_ok=True)
wb.save(out)
print("BITTI ·", os.path.abspath(out), flush=True)
