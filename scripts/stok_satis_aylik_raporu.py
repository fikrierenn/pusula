# -*- coding: utf-8 -*-
"""
Stoğu olan ürün × lokasyon stok + 2023'ten beri AY-AY satış (mağaza bazlı) -> Excel.
Kaynak: DEPO=depo.stok_adres_palet_vw (WMS anlık hücre, RAF+GR CK01-hariç) · MAĞAZA stok+aylık satış=dbo.irsHrk · master=bkm.UrunBilgi.
Sheet'ler:
  • Ozet    — stoğu olan HER ürün: Depo(mekan12)/FSM/Özlüce/İst.Yolu anlık stok + master.
  • FSM     — FSM stoğu>0 ürün: FSM stok + 2023-01..bugün aylık satış adet (mekan 1).
  • Ozluce  — Özlüce stoğu>0 ürün: Özlüce stok + aylık satış (mekan 4477).
  • IstYolu — İst.Yolu stoğu>0 ürün: İst stok + aylık satış (mekan 4478).
Konvansiyon (sema canonical): stok = SUM(ehAdetN) ehAltDepo=0; satış = ehTip IN (1,4,100), -SUM(ehAdetN) (çıkış negatif).
Kullanım: python scripts/stok_satis_aylik_raporu.py [YYYYMM_bas]   (varsayılan 202301)
SQL kaynağı (insan-okunur): sorgular/2026-07-31-stok-satis-aylik.sql
"""
import os, sys, re, datetime
import pyodbc
import openpyxl
from openpyxl.styles import Font, Alignment

BAS = sys.argv[1] if len(sys.argv) > 1 else "202301"

# .env oku (literal sır gömülmez; runtime okunur)
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
    f"UID={ENV['MSSQL_USER']};PWD={ENV['MSSQL_PASSWORD']};TrustServerCertificate=yes;Timeout=30",
    timeout=30)
cn.timeout = 900

# --- ay listesi: BAS .. bu ay (dahil) ---
by, bm = int(BAS[:4]), int(BAS[4:6])
today = datetime.date.today()
months = []
y, mo = by, bm
while (y, mo) <= (today.year, today.month):
    months.append(y * 100 + mo)
    mo += 1
    if mo > 12:
        mo = 1; y += 1
month_labels = [f"{m//100}-{m%100:02d}" for m in months]

MEKAN = {12: "Depo", 1: "FSM", 4477: "Ozluce", 4478: "IstYolu"}
STORE_MEKAN = [(1, "FSM"), (4477, "Ozluce"), (4478, "IstYolu")]

print("Stok çekiliyor (mağaza=irsHrk · DEPO=WMS RAF+GR, CK01 hariç)...", flush=True)
stok = {}   # stkID -> {mekanID: adet} (12=Depo/WMS · 1/4477/4478=mağaza irsHrk)
cur = cn.cursor()
# mağaza stok: irsHrk kümülatif (mağazalarda WMS yok)
cur.execute("""
    SELECT ehMekan, ehstkID, SUM(ehAdetN)
    FROM dbo.irsHrk WITH(NOLOCK)
    WHERE ehMekan IN (1,4477,4478) AND ehAltDepo=0
    GROUP BY ehMekan, ehstkID
    HAVING SUM(ehAdetN) > 0
""")
for mk, sid, st in cur.fetchall():
    stok.setdefault(sid, {})[mk] = int(st)
# DEPO (mekan 12) = WMS anlık hücre — RAF(0)+GR(1), CK01 HARİÇ (irsHrk DEĞİL: fiziki envanter)
cur.execute("""
    SELECT stkID, SUM(Stok)
    FROM depo.stok_adres_palet_vw
    WHERE Stok>0 AND adrsAlanTipID IN (0,1) AND adrsAd<>'CK01'
    GROUP BY stkID
    HAVING SUM(Stok) > 0
""")
for sid, st in cur.fetchall():
    stok.setdefault(sid, {})[12] = int(st)
print(f"  {len(stok)} ürün stokta (>=1 lokasyon)", flush=True)

print("Ürün master çekiliyor (Kırtasiye+Oyuncak+Hediyelik)...", flush=True)
# SADECE Kırtasiye/Oyuncak/Hediyelik (Kategori3) — Kitap/Akademi/Çocuk Kitabı vb. HARİÇ
master = {}  # stkID -> (kod, ad, marka, kategori)
cur.execute("SELECT stkID, stkKod, stkAd, mrkAd, Kategori3 FROM bkm.UrunBilgi WHERE Kategori3 IN (N'Kırtasiye', N'Oyuncak', N'Hediyelik')")
for sid, kod, ad, mrk, kat in cur.fetchall():
    master[sid] = (kod or "", (ad or "").strip(), (mrk or "").strip(), (kat or "").strip())

print("Aylık satış çekiliyor (büyük)...", flush=True)
# satış: mağaza × ürün × ay, adet (çıkış negatif → -SUM pozitif)
sales = {}  # (stkID, mekanID) -> {ym: qty}
cur.execute(f"""
    SELECT ehstkID, ehMekan, YEAR(ehTrhS)*100+MONTH(ehTrhS) AS ym, -SUM(ehAdetN) AS qty
    FROM dbo.irsHrk WITH(NOLOCK)
    WHERE ehMekan IN (1,4477,4478) AND ehTip IN (1,4,100) AND ehTrhS >= '{BAS}01'
    GROUP BY ehstkID, ehMekan, YEAR(ehTrhS)*100+MONTH(ehTrhS)
""")
n = 0
while True:
    rows = cur.fetchmany(50000)
    if not rows:
        break
    for sid, mk, ym, qty in rows:
        sales.setdefault((sid, mk), {})[ym] = int(qty)
        n += 1
print(f"  {n} satış satırı (ürün×mağaza×ay)", flush=True)
cur.close(); cn.close()

# --- Excel ---
print("Excel yazılıyor...", flush=True)
wb = openpyxl.Workbook(write_only=True)
hdr_font = Font(bold=True)

def sid_sort(sids):
    return sorted(sids, key=lambda s: (master.get(s, ("", "", "", ""))[3], master.get(s, ("", "zzz"))[1]))

# kategori-içi (master) VE stoğu olan ürünler — SABİT sıra, tüm sheet'lerde aynı
inkat = [s for s in stok if s in master]
order = sid_sort(inkat)

# Ozet sheet — 4 lokasyon stok + aylık TOPLAM satış (3 şube toplamı)
ws = wb.create_sheet("Ozet")
ws.append(["StkID", "Kod", "Urun", "Marka", "Kategori", "Depo", "FSM", "Ozluce", "IstYolu", "ToplamStok"] + month_labels)
for sid in order:
    kod, ad, mrk, kat = master[sid]
    d = stok[sid]
    st12, st1, st4477, st4478 = d.get(12, 0), d.get(1, 0), d.get(4477, 0), d.get(4478, 0)
    row = [sid, kod, ad, mrk, kat, st12, st1, st4477, st4478, st12 + st1 + st4477 + st4478]
    row += [sum(sales.get((sid, mk), {}).get(m, 0) for mk in (1, 4477, 4478)) for m in months]  # aylık 3-şube toplam satış
    ws.append(row)

# Mağaza sheet'leri — aynı SABİT satır seti + 4 lokasyon stok + o mağazanın aylık satışı
for mk, sheet in STORE_MEKAN:
    ws = wb.create_sheet(sheet)
    ws.append(["StkID", "Kod", "Urun", "Marka", "Kategori", "Depo", "FSM", "Ozluce", "IstYolu"] + month_labels)
    for sid in order:
        kod, ad, mrk, kat = master[sid]
        d = stok[sid]
        srow = sales.get((sid, mk), {})
        row = [sid, kod, ad, mrk, kat, d.get(12, 0), d.get(1, 0), d.get(4477, 0), d.get(4478, 0)]
        row += [srow.get(m, 0) for m in months]
        ws.append(row)
    print(f"  {sheet}: {len(order)} ürün", flush=True)

out = os.path.join(os.path.dirname(__file__), "..", "raporlar",
                   f"stok-satis-aylik-{today.strftime('%Y%m%d')}.xlsx")
os.makedirs(os.path.dirname(out), exist_ok=True)
wb.save(out)
print("BITTI -> " + os.path.abspath(out), flush=True)
