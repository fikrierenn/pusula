# -*- coding: utf-8 -*-
"""
SATINALMA TOPLANTI ANALİZİ — çok-sayfalı aksiyon Excel'i (MAĞAZA tarafı).
Girdi: stok_satis_aylik_wide çıktısı (ham 46 ay × 4 kanal). Ham ayları ÖZET
metriklere indirir (Son 12 ay / Son 3 ay / Aylık hız / Trend) ve satınalma
kararına dönük sayfalar üretir.

KULLANICI DİREKTİFİ: e-ticaret HARİÇ, SADECE MAĞAZA tarafı (FSM/OZL/IST).
satinalma-danisman kurulu kararları (çifte-sayım + confound):
  • Talep/hız = yalnız mağaza satışı (e-tic çıkarıldı).
  • İKİ STOK HAVUZU AYRI: Mağaza stoğu (FSM+OZL+IST) vs Depo (merkez, paylaşımlı).
    Merkez depo e-tic+kurumsal+mağazayı besler → aşırı/ölü MAĞAZA STOĞUYLA ölçülür,
    depo o hesaba KATILMAZ (katılırsa aşırı-stok haksız şişer). Depo = ikmal havuzu.
  • Sipariş kararı = mağaza stok + DEPO birlikte → depo doluysa AL değil TRANSFER.
  • YENİ ürün (ilk satış son 6 ayda) ölü/aşırıdan çıkarılır (erken yargı haksız).
  • Mevsimsel ürün (yıllık satışın ≥%60'ı tek 3-ay bloğunda) işaretlenir.
  • Değer = ETİKET (fiyat × stok), MALİYET DEĞİL; gerçek aşırı maliyet marj/indirim.
  • Alıcı atıfı YOK (veride insID yok) → bu AKSİYON listesi, suçlama değil.

Sayfalar: 0 Özet · 1 Sipariş · 2 Aşırı(mağaza) · 3 Ölü(mağaza) · 4 Transfer · 5 Yaşlanan
Kullanım: python scripts/satinalma_toplanti_analiz.py <girdi.xlsx>
"""
import os, sys, re, datetime
import pyodbc
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

IN = sys.argv[1] if len(sys.argv) > 1 else None
if not IN or not os.path.exists(IN):
    sys.exit("Girdi xlsx yolu ver: python scripts/satinalma_toplanti_analiz.py <rapor.xlsx>")

# --- EŞİKLER (toplantıda tartışılabilir; Özet sayfasında yazılı) ---
ACIL_AY       = 1.0     # kullanılabilir stok < 1 aylık hız → ACİL
YAKIN_AY      = 2.0     # 1-2 ay → YAKIN; sipariş hedefi 2 ay (60 gün)
HEDEF_AY      = 2.0     # önerilen sipariş = HEDEF_AY × hız − (mağaza+depo)
ASIRI_AY      = 12.0    # mağaza stoğu > 12 ay yetecek → AŞIRI
ASIRI_NORM_AY = 6.0     # fazlalık = mağaza stok − 6 ay × hız
OLU_AY        = 12      # son 12 ay mağaza satışı = 0 → ÖLÜ
ESKI_GUN      = 365     # depoya son giriş > 365 gün → yaşlanan
SUBE_MIN_AY   = 1.0     # şube stoğu < 1 aylık şube hızı → yetersiz
SUBE_HEDEF_AY = 2.0     # şube transfer hedefi
YENI_AY       = 6       # ilk satış son 6 ayda → YENİ (ölü/aşırıdan çıkar)
MEVSIM_PAY    = 0.60    # yıllık satışın ≥%60'ı tek 3-ay bloğunda → mevsimsel
# AŞIRI ALIM (taze maske): taze parti büyük alınıp çoğu stokta yatıyor → over-buy bayrağı
ASIRI_ALIM_MIN_GUN  = 7      # en az 7 gün geçmiş (1-2 günlük taze değil, satış şansı oldu)
ASIRI_ALIM_PARTI_PAY= 0.70   # son partinin ≥%70'i hâlâ stokta (dağıtılmamış/satılmamış)
ASIRI_ALIM_MIN_LOT  = 100    # hız=0 kolu: parti anlamlı büyük

# ================= GİRDİ OKU =================
print(f"Okunuyor: {IN}", flush=True)
wb = openpyxl.load_workbook(IN, read_only=True)
ws = wb["Sayfa1"]
it = ws.iter_rows(values_only=True)
HEAD = list(next(it))
ix = {h: i for i, h in enumerate(HEAD)}

# ay kolonları: yalnız MAĞAZA kanalları (ETIC hariç — kullanıcı direktifi)
AYMASK = re.compile(r"^(FSM|OZL|IST)_(\d{4}-\d{2})$")
aycols = {}  # kanal -> {ay: idx}
for h, i in ix.items():
    m = AYMASK.match(str(h))
    if m:
        aycols.setdefault(m.group(1), {})[m.group(2)] = i
months = sorted(aycols["FSM"].keys())
son_ay = months[-1]
L12 = months[-12:]; L3 = months[-3:]; P3 = months[-6:-3]

I_SID, I_BRK, I_AD, I_MRK, I_KAT, I_UF = ix["stkID"], ix["BarkodAna"], ix["stkAd"], ix["mrkAd"], ix["Kategori3"], ix["Üst Fiyat"]
I_SG, I_GUN = ix["Depoya Son Giriş (Alış)"], ix["Son Girişten Bu Yana (gün)"]
I_DEPO, I_FSM, I_OZL, I_IST = ix["depo_stok"], ix["FSM_stok"], ix["OZL_stok"], ix["IST_stok"]

def mevsimsel(mser12, toplam):
    if toplam <= 0: return False
    best = max(sum(mser12[k:k+3]) for k in range(len(mser12) - 2)) if len(mser12) >= 3 else sum(mser12)
    return best / toplam >= MEVSIM_PAY

urunler = []
for row in it:
    uf = float(row[I_UF] or 0)
    depo = max(0, int(row[I_DEPO] or 0))
    # ⚠ ERP defter mağaza stoğu NEGATİF olabilir (hayalet/oversold, K-37) → satılabilir değil, 0'a sabitle
    fsm = max(0, int(row[I_FSM] or 0)); ozl = max(0, int(row[I_OZL] or 0)); ist = max(0, int(row[I_IST] or 0))
    magaza_stok = fsm + ozl + ist                                   # MAĞAZA rafı (depo HARİÇ)
    # mağaza aylık seri (3 şube toplamı) — hız/yeni/mevsim için
    mser = [sum(int(row[aycols[ch][a]] or 0) for ch in ("FSM", "OZL", "IST")) for a in months]
    son12 = sum(mser[-12:]); son3 = sum(mser[-3:]); onc3 = sum(mser[-6:-3])
    # GÜNCEL hız = son 12 ay ortalaması ile son 3 ay ortalamasının BÜYÜĞÜ
    # (rampa/sezon-zirvesi ürünlerde 12-ay ortalaması güncel talebi az gösterir → yanlış aşırı-stok)
    hiz = max(max(0, son12) / 12.0, max(0, son3) / 3.0)
    # şube bazında son12 (transfer için)
    s_fsm = sum(int(row[aycols["FSM"][a]] or 0) for a in L12)
    s_ozl = sum(int(row[aycols["OZL"][a]] or 0) for a in L12)
    s_ist = sum(int(row[aycols["IST"][a]] or 0) for a in L12)
    # YENİ: ilk satışlı ay son YENI_AY içinde mi
    first_idx = next((k for k, v in enumerate(mser) if v > 0), None)
    yeni = first_idx is not None and (len(mser) - 1 - first_idx) < YENI_AY
    urunler.append({
        "sid": row[I_SID], "brk": row[I_BRK], "ad": row[I_AD], "mrk": row[I_MRK], "kat": row[I_KAT],
        "uf": uf, "depo": depo, "fsm": fsm, "ozl": ozl, "ist": ist, "magaza_stok": magaza_stok,
        "tstok": magaza_stok + depo,                                # merkez depo YALNIZ mağazaya hizmet → dahil
        "s_fsm": s_fsm, "s_ozl": s_ozl, "s_ist": s_ist,
        "son12": son12, "son3": son3, "onc3": onc3, "hiz": hiz,
        "yeni": yeni, "mevsim": mevsimsel(mser[-12:], son12),
        "etiket": uf * (magaza_stok + depo), "songiris": row[I_SG], "gun": row[I_GUN],
    })
wb.close()
print(f"  {len(urunler)} ürün · dönem {months[0]}..{son_ay} · e-tic HARİÇ (mağaza-only)", flush=True)

# --- SON PARTİ + FIFO "kalan stok ne zamandan kalmış" (alış partileri ehTip 0+10, TÜM mekan) ---
# AYNI GÜN TOPLA: GROUP BY ehstkID, CONVERT(date,ehTrhS) → bir günün tüm irsaliye/satırı tek parti.
# ehTip 0 (Alış, çoğu depo-12) + 10 (Yerel Alım, çoğu mağaza direkt ~3,4M adet) birlikte — yoksa
# mağazaya yerel alınan ürünün partisi hiç görünmez (ölçüm 2026-11-03).
ENV = {}
with open(os.path.join(os.path.dirname(__file__), "..", ".env"), encoding="utf-8") as f:
    for ln in f:
        m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
        if m and not ln.lstrip().startswith("#"):
            ENV[m.group(1)] = m.group(2).strip().strip('"')
host = ENV["MSSQL_HOST"]; port = ENV.get("MSSQL_PORT", "1433")
if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
    sys.exit("Geçersiz host/port (.env)")
ay_y, ay_m = int(son_ay[:4]), int(son_ay[5:7])
nxt = datetime.date(ay_y + 1, 1, 1) if ay_m == 12 else datetime.date(ay_y, ay_m + 1, 1)
T2 = nxt.strftime("%Y%m%d")                                  # rapor ayı + 1 ayın 1'i (hariç)
ref_date = nxt - datetime.timedelta(days=1)                  # rapor ayının son günü (gün hesabı)
print(f"Alış partileri çekiliyor (ehTip 0+10, tüm mekan, ehTrhS < {T2})...", flush=True)
cn = pyodbc.connect(
    f"Driver={{ODBC Driver 18 for SQL Server}};Server={host},{port};Database=DerinSISBkm;"
    f"UID={ENV['MSSQL_USER']};PWD={ENV['MSSQL_PASSWORD']};TrustServerCertificate=yes;Timeout=30", timeout=30)
cn.timeout = 600
cur = cn.cursor()
cur.execute("""
    SELECT h.ehstkID, CONVERT(date, h.ehTrhS) d, SUM(h.ehAdetN) q
    FROM dbo.irsHrk h WITH(NOLOCK)
    JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = h.ehstkID AND u.Kat3ID IN (10,12,16)
    WHERE h.ehTip IN (0,10) AND h.ehTrhS < ?
    GROUP BY h.ehstkID, CONVERT(date, h.ehTrhS)""", T2)
layers = {}
for sid, d, q in cur.fetchall():
    layers.setdefault(sid, []).append((d, int(q or 0)))
cur.close(); cn.close()
for lst in layers.values():
    lst.sort()
print(f"  {len(layers)} ürün alış partili", flush=True)

def fifo_bilgi(sid, tstok):
    """FIFO (en eski önce çıkar) → kalan = en yeni partiler. Dönüş: son parti adet, elde kalan EN ESKİ parti tarihi, gün."""
    lst = layers.get(sid)
    if not lst:
        return None, None, None
    son_q = lst[-1][1]
    if tstok <= 0:
        return son_q, None, None
    rem = tstok; eski = None
    for d, q in reversed(lst):            # en yeniden en eskiye
        if q <= 0:
            continue
        rem -= q; eski = d
        if rem <= 0:
            break
    return son_q, eski, ((ref_date - eski).days if eski else None)

for u in urunler:
    u["son_parti"], u["eski_kalan"], u["eski_gun"] = fifo_bilgi(u["sid"], u["tstok"])

def degisim(u):
    if u["onc3"] <= 0:
        return None
    return (u["son3"] - u["onc3"]) / u["onc3"]

def asiri_alim(u):
    """Taze parti büyük alınıp çoğu hâlâ stokta → over-buy (taze maskesini deler)."""
    g = u.get("gun"); sp = u.get("son_parti") or 0; ts = u.get("tstok") or 0; hz = u.get("hiz") or 0
    if g is None or not (ASIRI_ALIM_MIN_GUN <= g < 90):
        return False
    if sp <= 0 or ts < ASIRI_ALIM_PARTI_PAY * sp:      # partinin çoğu satılmış/dağıtılmışsa değil
        return False
    return (hz > 0 and sp > ASIRI_AY * hz) or (hz <= 0 and sp >= ASIRI_ALIM_MIN_LOT)

def durum(u):
    b = []
    if u.get("yeni"): b.append("Yeni ürün")
    if u.get("gun") is not None and u["gun"] < 90: b.append("Taze parti")
    if asiri_alim(u): b.append("İzle: dağıtılmamış")
    if u.get("mevsim"): b.append("Mevsimsel")
    return ", ".join(b)

def triyaj(u):
    """Tek aksiyon etiketi — mevcut eşikler (ACIL/YAKIN/ASIRI_AY) + satış trendi. Yeni eşik icat YOK.
    WOS (kaç ay yeter) × trend quadrant'ı; nedensel değil, operasyonel yön."""
    hz = u.get("hiz") or 0; ts = u.get("tstok") or 0
    if ts <= 0:
        return "Stok yok"
    if hz <= 0:
        if asiri_alim(u): return "Taze — satış başlamadı (izle)"
        return "Yeni/taze — bekle" if u.get("yeni") else "Ölü — 12 ay satış yok"
    ay = ts / hz
    d = degisim(u)                               # son 3 ay vs önceki 3 ay
    if ay > ASIRI_AY:
        return "Birikiyor — taze, izle" if asiri_alim(u) else "Birikiyor — alımı durdur"
    if ay < ACIL_AY:
        return "İnce — stockout riski"
    if d is not None and d <= -0.30 and ay > YAKIN_AY:
        return "Yavaşlıyor — izle"
    return "Sağlıklı"

# ================= ÇIKTI (hesaplamalar Excel FORMÜLÜ — canlı) =================
wbo = openpyxl.Workbook()
HB = Font(bold=True, color="FFFFFF"); HF = PatternFill("solid", fgColor="E30622")
INT = "#,##0"; TL = "#,##0"; AY = "#,##0.0"; DT = "dd.mm.yyyy"; PCT = "+0%;-0%"

def F(fn):                                 # formül kolonu işareti: fn(satir_no, kolon_harf_haritası) -> "=..."
    return ("F", fn)

def sheet(ad, kolonlar, satirlar):
    w = wbo.create_sheet(ad)
    C = {bas: get_column_letter(j) for j, (bas, *_x) in enumerate(kolonlar, 1)}
    for j, (bas, *_x) in enumerate(kolonlar, 1):
        c = w.cell(row=1, column=j, value=bas); c.font = HB; c.fill = HF
        c.alignment = Alignment(vertical="center", wrap_text=True)
    for i, s in enumerate(satirlar, 2):
        for j, (bas, spec, nf, wd) in enumerate(kolonlar, 1):
            if isinstance(spec, tuple) and spec and spec[0] == "F":
                v = spec[1](i, C)                      # formül
            elif callable(spec):
                v = spec(s)
            else:
                v = s.get(spec)
            c = w.cell(row=i, column=j, value=v)
            if nf:
                c.number_format = nf
    for j, (bas, spec, nf, wd) in enumerate(kolonlar, 1):
        w.column_dimensions[get_column_letter(j)].width = wd
    w.freeze_panes = "A2"
    w.auto_filter.ref = f"A1:{get_column_letter(len(kolonlar))}{1 + max(len(satirlar), 1)}"

BASE = [("stkID", "sid", None, 9), ("Barkod", "brk", None, 15), ("Ürün", "ad", None, 38),
        ("Marka", "mrk", None, 15), ("Kategori", "kat", None, 11), ("Üst Fiyat", "uf", TL, 9)]
# Mağaza stok DETAYLI (FSM/OZL/IST) + formüllü Mağaza Toplam + Depo + formüllü Toplam Stok
MAG = [("FSM", "fsm", INT, 7), ("OZL", "ozl", INT, 7), ("IST", "ist", INT, 7),
       ("Mağaza Toplam", F(lambda r, C: f"={C['FSM']}{r}+{C['OZL']}{r}+{C['IST']}{r}"), INT, 13),
       ("Depo", "depo", INT, 9),
       ("Toplam Stok", F(lambda r, C: f"={C['Mağaza Toplam']}{r}+{C['Depo']}{r}"), INT, 11)]
SATIS = [("Son 12 Ay", "son12", INT, 9), ("Son 3 Ay", "son3", INT, 8), ("Önceki 3 Ay", "onc3", INT, 10),
         ("Aylık Hız", F(lambda r, C: f"=MAX({C['Son 12 Ay']}{r}/12,{C['Son 3 Ay']}{r}/3)"), AY, 9),
         ("Değişim %", F(lambda r, C: f"=IF({C['Önceki 3 Ay']}{r}>0,({C['Son 3 Ay']}{r}-{C['Önceki 3 Ay']}{r})/{C['Önceki 3 Ay']}{r},\"\")"), PCT, 10),
         ("Durum", durum, None, 17), ("Triyaj", triyaj, None, 22)]
BATCH = [("Son Parti Tarihi", "songiris", DT, 14), ("Son Parti Adet", "son_parti", INT, 12),
         ("En Eski Kalan Parti", "eski_kalan", DT, 15), ("En Eski Kalan (gün)", "eski_gun", INT, 13)]
AYYETER = ("Kaç Ay Yeter", F(lambda r, C: f"=IF({C['Aylık Hız']}{r}>0,{C['Toplam Stok']}{r}/{C['Aylık Hız']}{r},\"\")"), AY, 11)
ETIKET  = ("Etiket Değeri", F(lambda r, C: f"={C['Üst Fiyat']}{r}*{C['Toplam Stok']}{r}"), TL, 14)

# --- 1 SİPARİŞ ÖNERİSİ (mağaza talebi; depo ikmal havuzu sayılır) ---
siparis = []
for u in urunler:
    if u["hiz"] <= 0 or u["yeni"]:
        continue
    kullan = u["magaza_stok"] + u["depo"]            # mağaza rafı + merkez depo (ikmal)
    ayk = kullan / u["hiz"]
    if ayk >= YAKIN_AY:
        continue
    oner = max(0, round(HEDEF_AY * u["hiz"] - kullan))
    if oner <= 0:                                    # depo zaten karşılıyor → sipariş değil (transfer)
        continue
    u2 = dict(u); u2["kullan"] = kullan; u2["ayk"] = ayk; u2["oner_sip"] = oner
    u2["aciliyet"] = "Acil" if ayk < ACIL_AY else "Yakın"
    siparis.append(u2)
siparis.sort(key=lambda u: (u["ayk"], -u["son12"]))
sheet("Siparis Onerisi",
      BASE + MAG + SATIS +
      [AYYETER,
       ("Aciliyet", F(lambda r, C: f"=IF({C['Kaç Ay Yeter']}{r}=\"\",\"\",IF({C['Kaç Ay Yeter']}{r}<1,\"Acil\",\"Yakın\"))"), None, 10),
       ("Önerilen Sipariş", F(lambda r, C: f"=MAX(0,ROUND(2*{C['Aylık Hız']}{r}-{C['Toplam Stok']}{r},0))"), INT, 14)] + BATCH,
      siparis)

# --- 2 AŞIRI STOK (mağaza + depo; merkez depo yalnız mağazaya hizmet eder) ---
asiri = []
for u in urunler:
    if u["tstok"] <= 0 or u["yeni"]:
        continue
    over = asiri_alim(u)                       # taze büyük alım (hız=0 olsa da aşırı)
    if u["hiz"] <= 0:
        if not over:                           # satış yok + aşırı-alım değil → aşırı değil
            continue
        ayk = None
    else:
        ayk = u["tstok"] / u["hiz"]
        if ayk <= ASIRI_AY and not over:
            continue
    u2 = dict(u); u2["ayk"] = ayk
    u2["fazla_adet"] = max(0, round(u["tstok"] - ASIRI_NORM_AY * u["hiz"]))
    u2["fazla_deger"] = u2["fazla_adet"] * u["uf"]
    asiri.append(u2)
asiri.sort(key=lambda u: -u["fazla_deger"])
sheet("Asiri Stok",
      BASE + MAG + SATIS +
      [AYYETER,
       ("Fazla Adet", F(lambda r, C: f"=MAX(0,ROUND({C['Toplam Stok']}{r}-6*{C['Aylık Hız']}{r},0))"), INT, 10),
       ("Fazla Etiket Değeri", F(lambda r, C: f"={C['Fazla Adet']}{r}*{C['Üst Fiyat']}{r}"), TL, 16)] + BATCH,
      asiri)

# --- 3 ÖLÜ STOK (mağaza + depo) — eldeki stok ESKİ olmalı; taze alım (en eski kalan <90 gün) ÖLÜ değil ---
olu = [u for u in urunler if u["son12"] <= 0 and u["tstok"] > 0 and not u["yeni"]
       and not (u["eski_gun"] is not None and u["eski_gun"] < 90)]
olu.sort(key=lambda u: -u["etiket"])
sheet("Olu Stok",
      BASE + MAG + [ETIKET, ("Durum", durum, None, 17), ("Triyaj", triyaj, None, 22)] + BATCH,
      olu)

# --- 4 DEPODA VAR - ŞUBEDE YOK/AZ (TRANSFER) ---
def ihtiyac(stok, son12):
    hiz = son12 / 12.0
    if hiz <= 0 or stok >= hiz * SUBE_MIN_AY: return 0, ""
    return max(0, round(SUBE_HEDEF_AY * hiz - stok)), ("YOK" if stok == 0 else "AZ")
transfer = []
for u in urunler:
    if u["depo"] <= 0:
        continue
    ihf, df = ihtiyac(u["fsm"], u["s_fsm"]); iho, do = ihtiyac(u["ozl"], u["s_ozl"]); ihi, di = ihtiyac(u["ist"], u["s_ist"])
    tih = ihf + iho + ihi
    if tih <= 0:
        continue
    u2 = dict(u)
    u2.update(fsm_d=df, ozl_d=do, ist_d=di, fsm_ih=ihf, ozl_ih=iho, ist_ih=ihi,
              oner_transfer=min(tih, u["depo"]))
    transfer.append(u2)
transfer.sort(key=lambda u: -u["oner_transfer"])
def _tr_durum(sube):
    return F(lambda r, C: f"=IF({C[sube+' Stok']}{r}=0,\"YOK\",IF({C[sube+' Stok']}{r}<{C[sube+' Satış']}{r}/12,\"AZ\",\"\"))")
def _tr_iht(sube):
    return F(lambda r, C: f"=IF({C[sube+' Stok']}{r}<{C[sube+' Satış']}{r}/12,MAX(0,ROUND(2*{C[sube+' Satış']}{r}/12-{C[sube+' Stok']}{r},0)),0)")
sheet("Depo-Sube Transfer",
      BASE + [("Depo", "depo", INT, 8),
              ("FSM Stok", "fsm", INT, 8), ("FSM Satış", "s_fsm", INT, 9), ("FSM Durum", _tr_durum("FSM"), None, 9), ("FSM İht.", _tr_iht("FSM"), INT, 8),
              ("OZL Stok", "ozl", INT, 8), ("OZL Satış", "s_ozl", INT, 9), ("OZL Durum", _tr_durum("OZL"), None, 9), ("OZL İht.", _tr_iht("OZL"), INT, 8),
              ("IST Stok", "ist", INT, 8), ("IST Satış", "s_ist", INT, 9), ("IST Durum", _tr_durum("IST"), None, 9), ("IST İht.", _tr_iht("IST"), INT, 8),
              ("Önerilen Transfer", F(lambda r, C: f"=MIN({C['FSM İht.']}{r}+{C['OZL İht.']}{r}+{C['IST İht.']}{r},{C['Depo']}{r})"), INT, 15)],
      transfer)

# --- 5 YAŞLANAN STOK ---
yaslanan = [u for u in urunler if (u["eski_gun"] is not None and u["eski_gun"] > ESKI_GUN and u["tstok"] > 0)]
yaslanan.sort(key=lambda u: -u["eski_gun"])
sheet("Yaslanan Stok",
      BASE + MAG + [ETIKET] + SATIS + BATCH,
      yaslanan)

if "Sheet" in wbo.sheetnames:
    del wbo["Sheet"]
out = os.path.join(os.path.dirname(IN), f"satinalma-toplanti-analiz-{son_ay}.xlsx")
wbo.save(out)
print("BITTI ·", os.path.abspath(out), flush=True)
for ad, n in [("Sipariş", len(siparis)), ("Aşırı", len(asiri)), ("Ölü", len(olu)),
              ("Transfer", len(transfer)), ("Yaşlanan", len(yaslanan))]:
    print(f"  {ad}: {n}", flush=True)
