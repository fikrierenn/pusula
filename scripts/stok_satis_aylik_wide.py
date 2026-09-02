# -*- coding: utf-8 -*-
"""
WIDE tek-satır/ürün Stok+Satış raporu — FORMÜLLÜ (dinamik son-12-ay).
"bkm temmuz k_o_ Stok ve Satış Raporu Şube Detaylı.xlsx" dosyasını ÜRETİR.

Kapsam: Kırtasiye+Oyuncak+Hediyelik (bkm.UrunBilgi.Kat3ID IN 10,12,16) — TÜM ürün (stok/satış 0 olsa da).
Kolon düzeni (birebir dosya):
  stkID | BarkodAna | stkAd | mrkAd | Kategori3 | Üst Fiyat | Toplam Etiket Değeri
        | depo_stok | FSM_stok | OZL_stok | IST_stok | Toplam Stok | Son 1 yıl Satış | Stok Dönüş Hızı
        | FSM_YYYY-MM (tüm ay) | OZL_… | IST_… | ETIC_…
Formül kolonları (Excel'de canlı, script her koşuda aralığı yeniden yazar):
  Toplam Etiket Değeri = ÜstFiyat × ToplamStok
  Toplam Stok          = SUM(depo:IST)
  Son 1 yıl Satış      = 4 kanalın SON 12 AYI toplamı (dinamik → yeni ay eklenince otomatik kayar)
  Stok Dönüş Hızı      = ToplamStok / Son 1 yıl Satış

Kaynak (sema canonical — ilk wide SQL ile aynı):
  ŞUBE satış  = dbo.irs_vw NET (eTip 1,4,3,5,100,101; -1*SUM(ehAdet); eDurum=1 veya eTip 100/101)
  E-TİC satış = OPENQUERY(ODAKJOKER) J_ITEMS.DERINSIS_ID=stkID (STATUS NOT IN 2004,2005,2010)
  DEPO stok   = depo.stok_adres_palet_vw RAF(0)+GR(1)  ·  MAĞAZA stok = stokSon_vw
Türkçe varchar → pyodbc (ODBC Driver 18, CP1254 doğru decode).
Kullanım: python scripts/stok_satis_aylik_wide.py [YYYYMM_bas]   (varsayılan 202301)
"""
import os, sys, re, datetime
import pyodbc
import openpyxl
from openpyxl.styles import Font, PatternFill
from openpyxl.utils import get_column_letter

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
MALIYET = "--maliyet" in sys.argv          # temmuz birebir = maliyetsiz (varsayılan); --maliyet → 4 ek kolon
BAS = ARGS[0] if ARGS else "202301"

# --- .env (sır runtime okunur, literal gömülmez) ---
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
cn.timeout = 1800

# --- ay listesi: BAS .. geçen ay (dahil). İçinde bulunulan ay HARİÇ (tam-olmayan ay yok) ---
by, bm = int(BAS[:4]), int(BAS[4:6])
today = datetime.date.today()
end_excl = today.year * 100 + today.month           # bu ayın 1'i (üst sınır, hariç)
months, y, mo = [], by, bm
while y * 100 + mo < end_excl:
    months.append(f"{y:04d}-{mo:02d}")
    mo += 1
    if mo > 12:
        mo = 1; y += 1
T1 = f"{by:04d}{bm:02d}01"
T2 = f"{end_excl // 100:04d}{end_excl % 100:02d}01"   # ISO, üst sınır hariç
CH = [("FSM", 1), ("OZL", 4477), ("IST", 4478)]      # şube kanalları (mekan)
print(f"Dönem: {months[0]} .. {months[-1]} ({len(months)} ay) · T1={T1} T2={T2}(hariç)", flush=True)

cur = cn.cursor()

# --- MASTER: tüm kategori ürünü (stok/satış 0 olsa da) ---
print("Master çekiliyor (Kırtasiye+Oyuncak+Hediyelik)...", flush=True)
master = {}   # stkID -> [barkod, ad, marka, kategori, ustfiyat]
cur.execute("""
    SELECT stkID, BarkodAna, stkAd, mrkAd, Kategori3, CONVERT(float, SatisFiyat)
    FROM bkm.UrunBilgi WITH(NOLOCK) WHERE Kat3ID IN (10,12,16)""")
for sid, brk, ad, mrk, kat, fy in cur.fetchall():
    master[sid] = [brk or "", (ad or "").strip(), (mrk or "").strip(), (kat or "").strip(), float(fy or 0)]
print(f"  {len(master)} ürün", flush=True)

# --- MALİYET (yalnız --maliyet modunda; temmuz birebir çıktıda maliyet kolonu yok) ---
maliyet = {}   # stkID -> (birim_maliyet, tarih, kaynak)
if MALIYET:
    # SON ALIŞ MALİYETİ: en son alış faturası birim net (KDV-hariç) — fat eTip=0
    print("Son alış maliyeti çekiliyor (fatAyr+fat, son fatura)...", flush=True)
    cur.execute("""
        WITH la AS (
            SELECT fa.ehstkID AS stkID,
                   CONVERT(decimal(18,4), fa.ehTutarN / NULLIF(fa.ehAdetN, 0)) AS birim,
                   f.eTarih,
                   ROW_NUMBER() OVER (PARTITION BY fa.ehstkID ORDER BY f.eTarih DESC, f.eID DESC) rn
            FROM dbo.fatAyr fa WITH(NOLOCK)
            JOIN dbo.fat f WITH(NOLOCK) ON fa.ehID = f.eID
            JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = fa.ehstkID AND u.Kat3ID IN (10,12,16)
            WHERE f.eTip = 0 AND f.eDurum <> 2 AND fa.ehAdetN > 0
        )
        SELECT stkID, birim, eTarih FROM la WHERE rn = 1""")
    for sid, birim, trh in cur.fetchall():
        maliyet[sid] = (float(birim or 0), trh, "Fatura")
    print(f"  {len(maliyet)} ürün faturadan maliyetli", flush=True)

    # FALLBACK: 31.05.2021 açılış DEVİR (irsHrk ehTip=99 'Sayım') — faturası olmayanlar
    print("Devir maliyeti çekiliyor (31.05.2021 açılış sayımı)...", flush=True)
    DEVIR_TRH = datetime.date(2021, 5, 31)
    nd = 0
    cur.execute("""
        SELECT h.ehstkID,
               CONVERT(decimal(18,4), SUM(h.ehTutarN) / NULLIF(SUM(h.ehAdetN), 0)) AS birim
        FROM dbo.irsHrk h WITH(NOLOCK)
        JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = h.ehstkID AND u.Kat3ID IN (10,12,16)
        WHERE h.ehTip = 99 AND h.ehTrhS >= '20210531' AND h.ehTrhS < '20210601'
        GROUP BY h.ehstkID
        HAVING SUM(h.ehAdetN) <> 0""")
    for sid, birim in cur.fetchall():
        if sid not in maliyet:                       # sadece faturasızlara devir
            maliyet[sid] = (float(birim or 0), DEVIR_TRH, "Devir")
            nd += 1
    print(f"  {nd} ürün devirden maliyetli (fatura yok) · toplam maliyetli {len(maliyet)}", flush=True)

# --- STOK: depo (WMS hücre RAF+GR) + mağaza (stokSon_vw) ---
print("Stok çekiliyor (depo=WMS RAF+GR · mağaza=stokSon_vw)...", flush=True)
depo = {}    # stkID -> adet
cur.execute("""
    SELECT stkID, SUM(Stok) FROM depo.stok_adres_palet_vw WITH(NOLOCK)
    WHERE Stok>0 AND adrsAlanTipID IN (0,1) GROUP BY stkID""")
for sid, st in cur.fetchall():
    depo[sid] = int(st or 0)
mstok = {}   # stkID -> {mekan: adet}
cur.execute("""
    SELECT ehstkID, ehMekan, SUM(stok) FROM stokSon_vw WITH(NOLOCK)
    WHERE ehMekan IN (1,4477,4478) GROUP BY ehstkID, ehMekan""")
for sid, mk, st in cur.fetchall():
    mstok.setdefault(sid, {})[mk] = int(st or 0)

# --- SATIŞ: ŞUBE (irs_vw net) — stkID × kanal × ay ---
print("Şube satış çekiliyor (irs_vw net)...", flush=True)
sales = {}   # (stkID, "FSM"/"OZL"/"IST"/"ETIC") -> {ay: adet}
sold = set()  # satış hareketi olan stkID (net!=0) — stok=0 & satış=0 filtresi için
name = {1: "FSM", 4477: "OZL", 4478: "IST"}
cur.execute(f"""
    SELECT i.ehStkID, i.eMekan,
           CONVERT(varchar(7), i.eTarih, 126) AS ay,
           CONVERT(int, -1*SUM(i.ehAdet)) AS qty
    FROM dbo.irs_vw i WITH(NOLOCK)
    JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = i.ehStkID
    WHERE i.eTip IN (1,4,3,5,100,101) AND i.eTarih >= '{T1}' AND i.eTarih < '{T2}'
      AND (i.eDurum = 1 OR i.eTip IN (100,101))
      AND i.eMekan IN (1,4477,4478) AND u.Kat3ID IN (10,12,16)
    GROUP BY i.ehStkID, i.eMekan, CONVERT(varchar(7), i.eTarih, 126)""")
n = 0
while True:
    rows = cur.fetchmany(50000)
    if not rows:
        break
    for sid, mk, ay, qty in rows:
        sales.setdefault((sid, name[mk]), {})[ay] = int(qty)
        if qty:
            sold.add(sid)
        n += 1
print(f"  {n} şube satır", flush=True)

# --- SATIŞ: E-TİCARET (OPENQUERY uzak-aggregate) ---
print("E-tic satış çekiliyor (OPENQUERY ODAKJOKER)...", flush=True)
cur.execute(f"""
    SELECT x.stkID, x.ay, CONVERT(int, x.qty) qty
    FROM OPENQUERY(ODAKJOKER, '
        SELECT i.DERINSIS_ID AS stkID,
               CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2) AS ay,
               SUM(d.QUANTITY) AS qty
        FROM JOKER.dbo.J_ORDER_DETAILS d
            JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF
            JOIN JOKER.dbo.J_ITEMS  i ON i.LOGICALREF=d.ITEMREF
        WHERE o.ORDERDATE>=''{T1}'' AND o.ORDERDATE<''{T2}'' AND i.DERINSIS_ID>0 AND d.STATUS NOT IN (2004,2005,2010)
        GROUP BY i.DERINSIS_ID, CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2)') x
    JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = x.stkID AND u.Kat3ID IN (10,12,16)""")
ne = 0
for sid, ay, qty in cur.fetchall():
    sales.setdefault((sid, "ETIC"), {})[ay] = int(qty)
    if qty:
        sold.add(sid)
    ne += 1
print(f"  {ne} e-tic satır", flush=True)
cur.close(); cn.close()

# ================= EXCEL (write_only, formüllü) =================
print("Excel yazılıyor...", flush=True)
CHANNELS = ["FSM", "OZL", "IST", "ETIC"]
# Başlık — temmuz birebir (maliyetsiz); --maliyet ise 4 ek kolon araya girer; ay blokları sona
HEAD = ["stkID", "BarkodAna", "stkAd", "mrkAd", "Kategori3", "Üst Fiyat"]
if MALIYET:
    HEAD += ["Son Alış Maliyeti"]
HEAD += ["Toplam Etiket Değeri"]
if MALIYET:
    HEAD += ["Toplam Maliyet Değeri"]
HEAD += ["depo_stok", "FSM_stok", "OZL_stok", "IST_stok", "Toplam Stok", "Son 1 yıl Satış", "Stok Dönüş Hızı"]
for ch in CHANNELS:
    HEAD += [f"{ch}_{m}" for m in months]

# İsim → sütun harfi (kolon eklenince formül kırılmaz)
COL = {h: get_column_letter(i + 1) for i, h in enumerate(HEAD)}
UF, ET = COL["Üst Fiyat"], COL["Toplam Etiket Değeri"]
if MALIYET:
    SM, MD = COL["Son Alış Maliyeti"], COL["Toplam Maliyet Değeri"]
DEPO, IST, TS, S1 = COL["depo_stok"], COL["IST_stok"], COL["Toplam Stok"], COL["Son 1 yıl Satış"]
nm = len(months)
def block_last12(ch):                       # kanalın son-12-ay aralığı (harf başlangıç,bitiş)
    start = HEAD.index(f"{ch}_{months[0]}") + 1
    end = start + nm - 1
    lo = start + max(0, nm - 12)            # son 12 ay (az ay varsa tümü)
    return get_column_letter(lo), get_column_letter(end)
RANGES = [block_last12(ch) for ch in CHANNELS]

# --- Görsel biçim (temmuz dosyasıyla eşleşen renk bantları + sayı formatı) ---
F_DEGER = PatternFill("solid", fgColor="D9D9D9")   # gri  — tutar/değer kolonları
F_STOK  = PatternFill("solid", fgColor="FCE4D6")   # şeftali — depo + şube stok
F_TSTOK = PatternFill("solid", fgColor="E4DFEC")   # mor  — Toplam Stok
F_SATIS = PatternFill("solid", fgColor="DDEBF7")   # mavi — Son 1 yıl Satış
F_HIZ   = PatternFill("solid", fgColor="E2EFDA")   # yeşil — Stok Dönüş Hızı
F_HEAD  = PatternFill("solid", fgColor="F2F2F2")   # açık gri — başlık
FILL = {"Toplam Etiket Değeri": F_DEGER, "Toplam Maliyet Değeri": F_DEGER,
        "depo_stok": F_STOK, "FSM_stok": F_STOK, "OZL_stok": F_STOK, "IST_stok": F_STOK,
        "Toplam Stok": F_TSTOK, "Son 1 yıl Satış": F_SATIS, "Stok Dönüş Hızı": F_HIZ}
_METIN = {"stkID", "BarkodAna", "stkAd", "mrkAd", "Kategori3", "Maliyet Kaynak"}
def nfmt(h):
    if h == "Stok Dönüş Hızı": return "#,##0.00"
    if h == "Son Alış Tarihi": return "dd.mm.yyyy"
    if h in _METIN: return None
    return "#,##0"                                  # tutar/stok/satış/fiyat → binlik ayraç
NF = {h: nfmt(h) for h in HEAD}

wb = openpyxl.Workbook(write_only=True)
ws = wb.create_sheet("Sayfa1")
ws.freeze_panes = "A2"
hb = Font(bold=True)
hdr_cells = [openpyxl.cell.WriteOnlyCell(ws, value=h) for h in HEAD]
for c in hdr_cells:
    c.font = hb
    c.fill = F_HEAD
ws.append(hdr_cells)

# FİLTRE: stok=0 VE satış=0 olan ürünü hiç yazma (boş satır selini kes)
def _aktif(s):
    return (depo.get(s, 0) + sum(mstok.get(s, {}).values())) != 0 or s in sold
order = sorted((s for s in master if _aktif(s)), key=lambda s: (master[s][3], master[s][1]))  # kategori, ad
for r, sid in enumerate(order, start=2):
    brk, ad, mrk, kat, fy = master[sid]
    d = mstok.get(sid, {})
    row = [sid, brk, ad, mrk, kat, fy]                  # ... Üst Fiyat
    if MALIYET:
        mb = maliyet.get(sid, (0, None, "Yok"))[0]
        row += [mb]                                     # Son Alış Maliyeti (fatura/devir birim net)
    row += [f"={UF}{r}*{TS}{r}"]                        # Toplam Etiket Değeri = ÜstFiyat×ToplamStok
    if MALIYET:
        row += [f"={SM}{r}*{TS}{r}"]                    # Toplam Maliyet Değeri = SonAlış×ToplamStok
    row += [depo.get(sid, 0),                           # depo
            d.get(1, 0), d.get(4477, 0), d.get(4478, 0),  # FSM/OZL/IST stok
            f"=SUM({DEPO}{r}:{IST}{r})",                # Toplam Stok
            "=" + "+".join(f"SUM({a}{r}:{b}{r})" for a, b in RANGES),  # Son 1 yıl (4 kanal son-12)
            f"=IFERROR({TS}{r}/{S1}{r},0)"]             # Stok Dönüş Hızı (0'a bölme guard)
    for ch in CHANNELS:
        srow = sales.get((sid, ch), {})
        row += [srow.get(m, 0) for m in months]
    cells = []
    for ci, val in enumerate(row):
        c = openpyxl.cell.WriteOnlyCell(ws, value=val)
        h = HEAD[ci]
        f = FILL.get(h)
        if f is not None:
            c.fill = f
        nf = NF[h]
        if nf is not None:
            c.number_format = nf
        cells.append(c)
    ws.append(cells)

ws.auto_filter.ref = f"A1:{get_column_letter(len(HEAD))}{len(order) + 1}"   # başlık filtre okları

suf = "-maliyetli" if MALIYET else ""
out = os.path.join(os.path.dirname(__file__), "..", "raporlar",
                   f"stok-satis-aylik-wide{suf}-{today.strftime('%Y%m%d')}.xlsx")
os.makedirs(os.path.dirname(out), exist_ok=True)
wb.save(out)
print(f"BITTI · {len(order)} satır × {len(HEAD)} kolon · son-12 aralık {RANGES}", flush=True)
print(" -> " + os.path.abspath(out), flush=True)
