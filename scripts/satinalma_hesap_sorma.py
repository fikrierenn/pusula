# -*- coding: utf-8 -*-
"""
SATINALMA HESAP-SORMA raporu (aylık) — "bu ay bunları aldın, neden bu kadar aldın".
ADİL tasarım (satinalma-danisman disiplini): sezon + yeni-ürün + confound ayrık, overclaim yasak.

Model (roll-forward + sezonlu tükenme):
  Açılış stok (ay öncesi irsHrk ledger) + Bu ay Alış − Tükenme = Kapanış.
  Sezonlu tükenme = geçen yıl aylık ŞEKİL × YoY(g) ile ileri yürüt (stok bitene kadar).
  FAZLA-ALIM ancak: sezonlu tükenme > eşik VE ürün yeni değil VE talep var.
Kaynaklar: stok/alış/tükenme = dbo.irsHrk ledger (mağazada stokSon ile birebir, CK dahil tam).
  Tükenme = şube (irsHrk ehTip 1,4,100) + e-tic (OPENQUERY ODAKJOKER). Alış = ehTip 0,10.
  Maliyet = son alış faturası > 31.05.2021 devir(ehTip 99) fallback. Atıf = bkm.UrunBilgi.SatinAlma (9 alıcı).
Kısıt: SatinAlma = ürünün ŞU ANKİ sorumlu alıcısı (per-sipariş karar veren değil) → dille belirtilir.
Kullanım: python scripts/satinalma_hesap_sorma.py [YYYYMM]   (varsayılan = son kapalı ay)
"""
import os, sys, re, datetime
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pyodbc
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.comments import Comment

# ---- hedef ay ----
if len(sys.argv) > 1:
    AY = sys.argv[1]
else:
    t = datetime.date.today().replace(day=1) - datetime.timedelta(days=1)   # geçen ay
    AY = f"{t.year:04d}{t.month:02d}"
AYY, AYM = int(AY[:4]), int(AY[4:6])
def ym_add(y, m, d):
    m2 = m - 1 + d; return y + m2 // 12, m2 % 12 + 1
_ny, _nm = ym_add(AYY, AYM, 1)
T_AY0 = f"{AYY:04d}{AYM:02d}01"                 # ay başı
T_AY1 = f"{_ny:04d}{_nm:02d}01"                 # sonraki ay başı (üst sınır)
# geçmiş şekil penceresi: 24 ay (YoY + sezon şekli). Baş = ay başı − 24 ay.
_gy, _gm = ym_add(AYY, AYM, -24)
T_GEC = f"{_gy:04d}{_gm:02d}01"
_wy, _wm = ym_add(AYY, AYM, -12)
T_WSTART = f"{_wy:04d}{_wm:02d}01"   # son-12-ay talep penceresi başı (stok-vardı testi için)
ESIK = 12                                        # sezonlu tükenme > 12 ay → fazla
MAT_ESIK = 5000                                  # materiality: bağlı para < bu → küçük/uzun-kuyruk (odak)
MIN_KOLI = 24                                    # bu ay alış ≤ bu → küçük-koli/min-sipariş (adil-atıf)
MIN_STOK = 3                                      # stoklu-ay için min şube bakiye (≈1/şube×3); 1-2 adet 'stok vardı' sayılmaz
print(f"Hedef ay: {AY} · alış [{T_AY0},{T_AY1}) · şekil geçmişi [{T_GEC},{T_AY0})", flush=True)

# ---- .env + bağlantı ----
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

# ---- 1) BU AY ALIŞ (satır setini belirler) ----
print("Alış çekiliyor...", flush=True)
alis = {}   # stkID -> (adet, tutar)
cur.execute(f"""
    SELECT h.ehstkID, SUM(h.ehAdetN), SUM(h.ehTutarN)
    FROM dbo.irsHrk h WITH(NOLOCK)
    JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=h.ehstkID AND u.Kat3ID IN (10,12,16)
    WHERE h.ehTip IN (0,10) AND h.ehTrhS>='{T_AY0}' AND h.ehTrhS<'{T_AY1}' AND h.ehAdetN>0
    GROUP BY h.ehstkID""")
for sid, ad, tt in cur.fetchall():
    alis[sid] = (int(ad or 0), float(tt or 0))
ids = list(alis.keys())
print(f"  {len(ids)} ürün alınmış", flush=True)
if not ids:
    sys.exit("Bu ay alış yok.")

# geçici tablo: alınan stkID'ler (IN-list yerine join — hızlı, injection yok)
cur.execute("CREATE TABLE #a (stkID int PRIMARY KEY)")
cur.executemany("INSERT INTO #a VALUES (?)", [(int(s),) for s in ids])

# ---- 2) LEDGER: açılış (< ay başı) + kapanış (< sonraki ay) ----
print("Açılış/Kapanış stok (ledger)...", flush=True)
acilis = {}; kapanis = {}; wstart_stok = {}
cur.execute(f"""
    SELECT h.ehstkID,
       SUM(CASE WHEN h.ehTrhS<'{T_AY0}' THEN h.ehAdetN ELSE 0 END),
       SUM(CASE WHEN h.ehTrhS<'{T_AY1}' THEN h.ehAdetN ELSE 0 END),
       SUM(CASE WHEN h.ehTrhS<'{T_WSTART}' THEN h.ehAdetN ELSE 0 END)
    FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
    WHERE h.ehTrhS<'{T_AY1}' GROUP BY h.ehstkID""")
for sid, ac, kp, ws in cur.fetchall():
    acilis[sid] = int(ac or 0); kapanis[sid] = int(kp or 0); wstart_stok[sid] = int(ws or 0)

# ---- 3) AYLIK ŞEKİL: şube satış (24 ay) ----
print("Aylık şekil — şube satış...", flush=True)
aylik = {}          # stkID -> {ay: adet}  (şube + e-tic birleşik — analiz için)
aylik_sube = {}     # sadece şube (sayfa için)
aylik_etic = {}     # sadece e-tic (sayfa için)
cur.execute(f"""
    SELECT h.ehstkID, CONVERT(varchar(7),h.ehTrhS,126) ay, -SUM(h.ehAdetN)
    FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
    WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>='{T_GEC}' AND h.ehTrhS<'{T_AY0}'
    GROUP BY h.ehstkID, CONVERT(varchar(7),h.ehTrhS,126)""")
for sid, ay, q in cur.fetchall():
    aylik.setdefault(sid, {})[ay] = aylik.get(sid, {}).get(ay, 0) + int(q or 0)
    aylik_sube.setdefault(sid, {})[ay] = aylik_sube.get(sid, {}).get(ay, 0) + int(q or 0)

# ---- 4) AYLIK ŞEKİL: e-tic (OPENQUERY, kategori-geniş, Python'da alınan-set süz) ----
print("Aylık şekil — e-tic (OPENQUERY)...", flush=True)
cur.execute(f"""
    SELECT x.stkID, x.ay, CONVERT(int,x.qty)
    FROM OPENQUERY(ODAKJOKER, '
        SELECT i.DERINSIS_ID stkID,
               CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2) ay,
               SUM(d.QUANTITY) qty
        FROM JOKER.dbo.J_ORDER_DETAILS d
            JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF
            JOIN JOKER.dbo.J_ITEMS  i ON i.LOGICALREF=d.ITEMREF
        WHERE o.ORDERDATE>=''{T_GEC}'' AND o.ORDERDATE<''{T_AY0}'' AND i.DERINSIS_ID>0 AND d.STATUS NOT IN (2004,2005,2010)
        GROUP BY i.DERINSIS_ID, CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2)') x
    JOIN #a ON #a.stkID=x.stkID""")
for sid, ay, q in cur.fetchall():
    aylik.setdefault(sid, {})[ay] = aylik.get(sid, {}).get(ay, 0) + int(q or 0)
    aylik_etic.setdefault(sid, {})[ay] = aylik_etic.get(sid, {}).get(ay, 0) + int(q or 0)

# ---- 5) MASTER + MALIYET ----
print("Master + maliyet...", flush=True)
master = {}
cur.execute("""SELECT u.stkID, u.SatinAlma, u.stkAd, u.Kategori3, u.mrkAd
    FROM bkm.UrunBilgi u WITH(NOLOCK) JOIN #a ON #a.stkID=u.stkID""")
for sid, sa, ad, kat, mrk in cur.fetchall():
    master[sid] = ((sa or "—").strip(), (ad or "").strip(), (kat or "").strip(), (mrk or "").strip())
maliyet = {}
cur.execute("""
    SELECT stkID, birim FROM (
      SELECT fa.ehstkID stkID, CONVERT(decimal(18,4), SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0)) birim,
             ROW_NUMBER() OVER (PARTITION BY fa.ehstkID ORDER BY MAX(f.eTarih) DESC, f.eID DESC) rn
      FROM dbo.fatAyr fa WITH(NOLOCK) JOIN dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
      JOIN #a ON #a.stkID=fa.ehstkID
      WHERE f.eTip=0 AND f.eDurum<>2 AND fa.ehAdetN>0
      GROUP BY fa.ehstkID, f.eID) t WHERE rn=1""")   # fatura-bazında topla-böl (bedava/0-birim satırlar ortalamaya dahil): SUM(tutar)/SUM(adet), sonra en son fatura
for sid, b in cur.fetchall():
    maliyet[sid] = float(b or 0)
cur.execute("""
    SELECT h.ehstkID, CONVERT(decimal(18,4), SUM(h.ehTutarN)/NULLIF(SUM(h.ehAdetN),0))
    FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
    WHERE h.ehTip=99 AND h.ehTrhS>='20210531' AND h.ehTrhS<'20210601'
    GROUP BY h.ehstkID HAVING SUM(h.ehAdetN)<>0""")
for sid, b in cur.fetchall():
    maliyet.setdefault(sid, float(b or 0))
# ilk STOK-GİRİŞ (yaş kapısı): alış(0,10) · sevk/transfer(13) · stok-ekle(16) · devir-sayım(99).
# Satış/iade HARİÇ → ürün stoğa GERÇEKTEN ne zaman girdi. <12 ay = genç (değerlendirme için erken/adil değil).
ilk_giris = {}
cur.execute(f"""SELECT h.ehstkID, MIN(h.ehTrhS) FROM dbo.irsHrk h WITH(NOLOCK)
    JOIN #a ON #a.stkID=h.ehstkID WHERE h.ehTip IN (0,10,13,16,99) AND h.ehTrhS<'{T_AY1}'
    GROUP BY h.ehstkID""")
for sid, dt in cur.fetchall():
    ilk_giris[sid] = dt

# aylık net ledger delta (TÜM ehTip) — ay-ay stok yeniden-kurulumu (stoklu-ay + aktif-ay hızı)
aylik_delta = {}
cur.execute(f"""SELECT h.ehstkID, CONVERT(varchar(7),h.ehTrhS,126) ay, SUM(h.ehAdetN)
    FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
    WHERE h.ehTrhS>='{T_WSTART}' AND h.ehTrhS<'{T_AY0}'
    GROUP BY h.ehstkID, CONVERT(varchar(7),h.ehTrhS,126)""")
for sid, ay, dl in cur.fetchall():
    aylik_delta.setdefault(sid, {})[ay] = int(dl or 0)

# KATEGORİ sezon YoY büyüme (ürün-g gürültülü → kategori stabil; önümüz sezon = hedef+1..+3)
def _yms(t, off):
    y, m = ym_add(t[0], t[1], off); return f"{y:04d}{m:02d}01"
_s1 = ym_add(AYY, AYM, 1); _s4 = ym_add(AYY, AYM, 4)
SLY0, SLY1 = _yms(_s1, -12), _yms(_s4, -12)   # geçen yıl aynı sezon [başlangıç, bitiş)
SPY0, SPY1 = _yms(_s1, -24), _yms(_s4, -24)   # önceki yıl aynı sezon
g_kat = {}
cur.execute(f"""SELECT u.Kategori3,
    -SUM(CASE WHEN i.ehTrhS>='{SLY0}' AND i.ehTrhS<'{SLY1}' THEN i.ehAdetN ELSE 0 END) s_ly,
    -SUM(CASE WHEN i.ehTrhS>='{SPY0}' AND i.ehTrhS<'{SPY1}' THEN i.ehAdetN ELSE 0 END) s_py
    FROM dbo.irsHrk i WITH(NOLOCK)
    JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=i.ehstkID AND u.Kat3ID IN (10,12,16)
    WHERE i.ehTip IN (1,4,100) AND i.ehTrhS>='{SPY0}' AND i.ehTrhS<'{SLY1}'
    GROUP BY u.Kategori3""")
for kat, sly, spy in cur.fetchall():
    gg = (float(sly) / float(spy)) if (spy and spy > 0) else 1.0
    g_kat[(kat or "").strip()] = min(4.0, max(0.5, gg))   # floor 0.5, tavan 4 (cap büyümeyi kırpmasın)

# BU AY tükenme (satış) — roll-forward'ı kapatmak için (ay başı + alış − satış + diğer = ay sonu)
tuk_month = {}
cur.execute(f"""SELECT h.ehstkID, -SUM(h.ehAdetN) FROM dbo.irsHrk h WITH(NOLOCK)
    JOIN #a ON #a.stkID=h.ehstkID WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>='{T_AY0}' AND h.ehTrhS<'{T_AY1}'
    GROUP BY h.ehstkID""")
for sid, q in cur.fetchall():
    tuk_month[sid] = int(q or 0)
cur.execute(f"""SELECT x.stkID, CONVERT(int,x.qty)
    FROM OPENQUERY(ODAKJOKER, '
        SELECT i.DERINSIS_ID stkID, SUM(d.QUANTITY) qty
        FROM JOKER.dbo.J_ORDER_DETAILS d JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF
            JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
        WHERE o.ORDERDATE>=''{T_AY0}'' AND o.ORDERDATE<''{T_AY1}'' AND i.DERINSIS_ID>0 AND d.STATUS NOT IN (2004,2005,2010)
        GROUP BY i.DERINSIS_ID') x JOIN #a ON #a.stkID=x.stkID""")
for sid, q in cur.fetchall():
    tuk_month[sid] = tuk_month.get(sid, 0) + int(q or 0)

# ŞUBE aylık bakiye — PERSISTENT tablodan (bkm.StokAyBakiyeMekanBazli, floored, güvenilir; canlı-recon yerine)
sube_series = {}   # sid -> {mekan: [(ay, stok)...] artan}
cur.execute("""SELECT stkID, ehMekan, CONVERT(varchar(7),Donem,126) ay, Stok
    FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
    WHERE Kaynak='irsHrk' AND stkID IN (SELECT stkID FROM #a)
    ORDER BY stkID, ehMekan, Donem""")   # floor YOK: 2021 devir bakiyesi ileri taşınır (duran ölü-stok stoklu-ay sayılır)
for sid, mk, ay, st in cur.fetchall():
    sube_series.setdefault(sid, {}).setdefault(mk, []).append((ay, int(st or 0)))
# DEPO fiziki = canlı WMS (tablodaki WMS de aynı anlık; canlı en güncel)
fiziki_depo = {}
cur.execute("""SELECT stkID, SUM(Stok) FROM depo.stok_adres_palet_vw WITH(NOLOCK)
    WHERE adrsAlanTipID IN (0,1) AND stkID IN (SELECT stkID FROM #a) GROUP BY stkID""")
for sid, s in cur.fetchall():
    fiziki_depo[sid] = int(s or 0)
# ŞUBE ay-sonu = CANLI fiziki (stokSon_vw, mekan 1/4477/4478) — duran devir stoğunu da gösterir (DINAMIK ile tek kaynak)
fiziki_sube = {}
cur.execute("""SELECT ehstkID, SUM(stok) FROM stokSon_vw WITH(NOLOCK)
    WHERE ehMekan IN (1,4477,4478) AND ehstkID IN (SELECT stkID FROM #a) GROUP BY ehstkID""")
for sid, s in cur.fetchall():
    fiziki_sube[sid] = int(s or 0)
cur.execute("DROP TABLE #a")
cur.close(); cn.close()

# ================= HESAP (Python) =================
# 12-ay şekil penceresi: son 12 ay (ay başı-12 .. ay başı) ay etiketleri
def ym_labels(y, m, n):
    out = []
    for i in range(n):
        yy, mm = ym_add(y, m, i); out.append(f"{yy:04d}-{mm:02d}")
    return out
sy, sm = ym_add(AYY, AYM, -12)     # son 12 ay başlangıcı
py, pm = ym_add(AYY, AYM, -24)     # önceki 12 ay başlangıcı
SON12 = ym_labels(sy, sm, 12)      # şekil (gelecek talep proxy) + son12 toplam
ONC12 = ym_labels(py, pm, 12)      # YoY payda
YENI_CUTOFF = datetime.datetime(sy, sm, 1)   # ilk-hareket bundan sonraysa "yeni" (yeterli geçmiş yok)

def hesapla(sid, kat):
    d = aylik.get(sid, {})
    son12 = sum(d.get(a, 0) for a in SON12)
    onc12 = sum(d.get(a, 0) for a in ONC12)
    son24 = sum(d.values())
    # BÜYÜME: ürün-bazlı YoY (yeterli TABAN varsa güvenilir) → yoksa kategori sezon-g fallback
    # (küçük tabandan büyüme gürültülü: 75→370 = ×5 güvenilmez; eşik 100 adet önceki-yıl)
    if onc12 >= 100:
        g = min(6.0, max(0.3, son12 / onc12)); g_kaynak = "ürün"
    else:
        g = g_kat.get(kat, 1.0); g_kaynak = "kategori"
    # STOK: ŞUBE aylık bakiye persistent tablodan (bkm.StokAyBakiyeMekanBazli) · DEPO canlı WMS
    ser = sube_series.get(sid, {})
    def _sbal(M):                                   # M ayı-sonundaki toplam şube bakiyesi (son değer taşınır)
        t = 0
        for lst in ser.values():
            last = 0
            for ay, st in lst:                      # artan sıralı
                if ay <= M: last = st
                else: break
            t += last
        return t
    sube_now = fiziki_sube.get(sid, 0); depo_now = fiziki_depo.get(sid, 0)   # ay-sonu = canlı fiziki (stokSon_vw)
    kap = sube_now + depo_now                        # ay sonu = fiziki (şube + depo)
    net_month = kapanis.get(sid, 0) - acilis.get(sid, 0)     # ledger ay-net (delta güvenilir)
    ac = kap - net_month                             # ay başı
    # ŞUBE stoklu-ay: bakiye>0 VEYA o ay satış>0 (sattıysa stok vardı — recon 0'a floor'lanmışsa düzeltir)
    stoklu_ay = sum(1 for M in SON12 if _sbal(M) >= MIN_STOK or d.get(M, 0) > 0)
    aktif_ay = max(1, stoklu_ay)
    aylik_ort = son12 / aktif_ay                    # aktif-ay hızı (şube stoklu ay'a böl)
    # yaş: ilk STOK-GİRİŞ'ten bu yana kaç ay (alış/sevk/stok-ekle/devir). <12 ay → genç.
    ih = ilk_giris.get(sid)
    history_ay = ((AYY - ih.year) * 12 + (AYM - ih.month)) if ih is not None else 0
    genc = (0 <= history_ay < 12)                  # stoğa <12 ay önce girdi → değerlendirme için erken
    yeni = genc and son24 == 0                     # yeni + hiç satmamış (eski+satmayan artık ÖLÜ olabilir)
    had_stock = stoklu_ay >= 6                      # 12 ayın ≥yarısı ŞUBE'de stoklu → satma fırsatı vardı
    shape = [d.get(a, 0) for a in SON12]
    tuk_ay = None                                  # sezonlu ileri tükenme (şekil × sönümlü büyüme) — GERÇEK ay (cap yok)
    if sum(shape) > 0 and kap > 0:
        rem = kap; f = 0
        while f < 999:
            # büyüme primi zamanla söner: boom (g>1) 12 ayda baseline'a iner.
            # ÇÖKÜŞ (g<1) İLERİYE UZATILMAZ → g_eff=1 (bugünkü hızda erit; düşüşü sonsuza çarpmak
            # aşırı-kötümser: ürün zaten düşmüş son12'ye, üstüne bir düşüş daha = çifte-sayım).
            g_eff = (1.0 + (g - 1.0) * max(0.0, 1.0 - f / 12.0)) if g >= 1.0 else 1.0
            # SEZON HİZASI: f=0 = ilk gelecek ay (hedef+1). Geçen yıl karşılığı SON12[1] (hedef−11).
            # SON12[0]=hedef−12 olduğu için +1 kaydır → gelecek Ağu, geçen Ağu'ya oturur.
            exp = shape[(f + 1) % 12] * g_eff
            if exp <= 0:
                f += 1; continue
            if rem <= exp:
                tuk_ay = f + rem / exp; break
            rem -= exp; f += 1
        if tuk_ay is None:
            tuk_ay = 999.0                          # 999 = pratikte tükenmez (talep var ama çok yavaş)
    trend = (g >= 2.0)                             # güçlü son-yıl boom → muhtemel trend/fad (kalıcı değil)
    gy_sezon = sum(shape[1:4])                      # geçen yıl önümüz-sezon (hedef+1..+3 = Ağu-Eki) GERÇEK satış
    sezon3 = gy_sezon * g                           # bu sezon beklenen (× büyüme)
    naive_mos = (kap / (son12 / 12.0)) if son12 > 0 else None
    # ---- ÜRÜN KARAKTERİ (şekil-bazlı: istikrar + sezon-hizası + büyüme) ----
    satis_ay = sum(1 for x in shape if x > 0)       # kaç ayda satış oldu (istikrar sinyali)
    sezon_pay = (gy_sezon / son12) if son12 > 0 else 0.0   # satışın önümüz-sezon payı (sezonluk sinyali)
    if genc:               karakter = "GENÇ"         # stoğa <12 ay önce girdi (öncelik)
    elif son24 == 0:       karakter = "DURGUN"       # eski + 24 ay hiç satış
    elif sezon_pay >= 0.5: karakter = "SEZONSAL"     # satışın ≥%50'si sezonda → her yıl tekrar (istikrardan ÖNCE bak)
    elif satis_ay >= 9:    karakter = "NORMAL"       # yılın ≥9 ayı yayılı satar → istikrarlı staple (g güvenilir)
    elif g >= 2.0:         karakter = "TREND"        # spiky + sezon-dışı + büyüme → fad riski (kalıcı değil)
    elif g < 0.7:          karakter = "DÜŞÜŞ"        # talep azalıyor
    else:                  karakter = "DÜZENSİZ"     # dalgalı, net desen yok
    return dict(son12=son12, onc12=onc12, son24=son24, g=g, g_kaynak=g_kaynak, kap=kap, ac=ac, tuk_ay=tuk_ay,
                gy_sezon=gy_sezon, sezon3=sezon3, naive=naive_mos, yeni=yeni, genc=genc, had_stock=had_stock,
                stoklu_ay=stoklu_ay, aylik_ort=aylik_ort, history_ay=history_ay,
                satis_ay=satis_ay, sezon_pay=sezon_pay, karakter=karakter,
                sube_now=sube_now, depo_now=depo_now)

def bayrak(sid, h, al_adet):
    if h["genc"]:                                      # stoğa <12 ay önce girdi → değerlendirme için erken
        return f"GENÇ ÜRÜN — stoğa {h['history_ay']} ay önce girdi (<12), hüküm için erken — izle"
    if h["son12"] == 0:                                # eski ürün (stoğa >12 ay önce girdi) ama son 12 ay satış 0
        if h["had_stock"]:
            return "🔴 ÖLÜ-ALIM — stok vardı ama 12 ay satmadı, yine de alındı"
        return "🟠 YENİDEN-STOK — stoksuzdu (eski talep), restok — izle"
    if h["kap"] - h["sezon3"] < 0:
        if h["karakter"] == "TREND":               # fad → "daha al" tehlikeli (trend biter, elde kalır)
            return "🟠 TREND-HIZLI — hız trend-kaynaklı, kalıcı olmayabilir; kısa-vade/küçük parti, bulk riskli"
        return "🟢 AZ ALMIŞ — sezon eritir, stockout riski"
    if h["tuk_ay"] is not None and h["tuk_ay"] > ESIK:
        if h["g_kaynak"] == "kategori":            # geçen yıl verisi yok → büyüme belirsiz → suçlama zayıf
            return f"🟠 İZLE — geçmiş yıl verisi yok (büyüme belirsiz), {h['tuk_ay']:.0f} ayda erir"
        return f"🔴 FAZLA — sezon+büyüme dahil {h['tuk_ay']:.0f} ayda erir"
    if h["tuk_ay"] is not None and h["tuk_ay"] > 6:
        return f"🟠 İZLE — {h['tuk_ay']:.0f} ay"
    return "🟢 NORMAL"

# ================= EXCEL =================
print("Excel yazılıyor...", flush=True)
HEAD = ["Ürün Kodu", "Ürün Adı", "Kategori", "Marka",
        "Bu Ay Alınan (adet)", "Bu Ay Alış Tutarı (₺, KDV'siz)", "Birim Maliyet (₺)",
        "Ay Başındaki Stok", "Ay Sonundaki Stok (=başı+alınan−satılan+diğer)", "Son 12 Ay Satış (adet)",
        "Yıllık Büyüme (bu yıl ÷ geçen yıl)", "Kaç Ayda Tükenir (sezon+büyüme)", "Kaç Ayda Tükenir (basit)",
        "Geçen Yıl Sezon Satışı (adet)", "Bu Sezon Beklenen Satış (=geçen sezon×büyüme)",
        "Sezon Sonrası Elde Kalacak (=ay sonu−beklenen)", "Fazla Stokta Bağlı Para (₺)",
        "Değerlendirme", "Açıklama / Gerekçe",
        "Ürün Karakteri", "Geçen Yıl Toplam Satış (büyüme tabanı)", "Yılda Kaç Ay Satmış (12'de)",
        "Yılda Kaç Ay Stoklu (12'de)", "Aylık Satış Hızı (=son12÷stoklu ay)", "Satışın Sezon Payı (%)",
        "Büyüme Kaynağı (ürün/kategori)", "Stoğa İlk Girişten Beri (ay)",
        "Bu Ay Satılan (adet)", "Bu Ay Diğer Hareket (transfer/sayım)"]

def yorum(h, al_adet, ac, bay):
    def tr(n): return f"{n:,}".replace(",", ".")   # Türkçe binlik ayracı (nokta)
    hiz = round(h["aylik_ort"])
    kap = h["kap"]; tuk = h["tuk_ay"]; bek = round(h["sezon3"])

    def sure(t):                                    # ay ve yıl olarak sade ifade
        if t is None:
            return ""
        if t >= 999:
            return "bu satış hızıyla pratikte hiç tükenmez"
        if t >= 24:
            return f"eldeki stok bu satış hızıyla yaklaşık {t:.0f} ayda (yaklaşık {t/12:.0f} yılda) tükenir"
        return f"eldeki stok bu satış hızıyla yaklaşık {t:.0f} ayda tükenir"

    if "FAZLA" in bay:
        s = (f"Ay başında elde {tr(ac)} adet vardı, bu ay {tr(al_adet)} adet daha alındı. "
             f"Ürün ayda ortalama {tr(hiz)} adet satıyor. {sure(tuk).capitalize()}. "
             f"İhtiyaçtan çok fazla alınmış.")
        if h["g"] < 1.0:
            s += " Üstelik ürünün satışı geçen yıla göre düşüşte."
        return s
    if "KÜÇÜK-ALIM" in bay:
        return (f"Bu ay yalnızca {al_adet} adet alınmış — bu en küçük koli miktarı, daha azı alınamıyor. "
                f"Elde {tr(kap)} adet fazla stok var ama bu ayki alım küçük olduğu için alıcının kararı sayılmaz.")
    if "UZUN-KUYRUK" in bay:
        return (f"Yavaş satan bir çeşit ürünü. {sure(tuk).capitalize()}, "
                f"ama bağlanan para küçük olduğu için öncelikli değil.")
    if "YENİDEN-STOK" in bay:
        return (f"Geçen yıl stoğu bittiği için satılamamış, ama eskiden talebi vardı. "
                f"{tr(al_adet)} adet ile yeniden stoklanmış. Ölü ürün değil, izlemek yeterli.")
    if "GENÇ" in bay:
        return (f"Ürün stoğa ilk kez {h['history_ay']} ay önce girdi (alış veya sevkle). "
                f"Tam bir yıllık satış geçmişi olmadığı için şimdilik değerlendirilemiyor.")
    if "DEĞERLENDİRME" in bay:
        return (f"Bu üründen son iki yılda hiç satış olmamış. "
                f"Talep bilgisi olmadığı için değerlendirilemiyor.")
    if "ÖLÜ" in bay:
        return (f"Ürün yıl boyunca elde vardı ama hiç satmadı. Buna rağmen {tr(al_adet)} adet daha alınmış. "
                f"Satmayan bir ürüne alım yapılmış.")
    if "TREND" in bay:
        return (f"Ürünün satışı son bir yılda çok arttı, ama bu geçici bir moda olabilir. "
                f"Önümüzdeki dönemde yaklaşık {tr(bek)} adet satması bekleniyor. Bu hız kalıcı olmayabilir; "
                f"az miktarda ve sık almak, bir kerede çok stoklamaktan daha güvenli.")
    if "AZ ALMIŞ" in bay:
        return (f"Ürün iyi satıyor, elde sadece {tr(kap)} adet kalmış. "
                f"Önümüzdeki dönemde yaklaşık {tr(bek)} adet satması bekleniyor. "
                f"Bu stok yetmeyecek, daha alınmalı.")
    if "verisi yok" in bay:
        return (f"Geçen yıl bu üründen satış olmadığı için ne kadar büyüdüğü kesin bilinmiyor. "
                f"{sure(tuk).capitalize()}, ama tahmin kesin olmadığı için izlemek gerekir.")
    if "İZLE" in bay:
        return f"{sure(tuk).capitalize()} — sınırda bir durum, izlemek gerekir."
    return (f"{sure(tuk).capitalize()} — stok ile satış dengeli, sorun görünmüyor."
            if tuk is not None else "Stok ile satış dengeli, sorun görünmüyor.")

rows = []
denetim = []       # otomatik tutarlılık denetimi için satır-başı hesaplar
for sid in ids:
    _sa, ad, kat, mrk = master.get(sid, ("—", "", "", ""))
    al_adet, al_tut = alis[sid]
    h = hesapla(sid, kat)
    bmal = maliyet.get(sid, 0)
    if bmal <= 0 and al_adet > 0 and al_tut > 0:      # fatura/devir yok → bu ayki alış birimi (en taze)
        bmal = round(al_tut / al_adet, 4)
    bay = bayrak(sid, h, al_adet)
    ac = h["ac"]                                               # ay başı (fiziki-ankrajlı)
    satildi = tuk_month.get(sid, 0)                             # bu ay satılan (şube+etic)
    diger = h["kap"] - ac - al_adet + satildi                  # bu ay diğer (transfer/sayım): roll-forward kapatır
    donmus = 0
    if "FAZLA" in bay:
        fazla_adet = max(0, h["kap"] - h["sezon3"])   # SEZONLUK: sezon-sonrası kalan (kap − gy_sezon×g); linear DEĞİL (sezonsalda şişer)
        donmus = fazla_adet * bmal
    # materiality (#1) + min-sipariş (#3): büyük FAZLA'yı gürültüden ayır (odak + adil-atıf)
    if "FAZLA" in bay and al_adet <= MIN_KOLI:
        bay = f"🟡 KÜÇÜK-ALIM — {al_adet} adet (min-koli, az alınamaz); stok fazla ama bu ay az aldı"
    elif "FAZLA" in bay and donmus < MAT_ESIK:
        bay = f"🟡 UZUN-KUYRUK — küçük fazla ({round(donmus):,} ₺ bağlı); yavaş SKU, düşük öncelik"
    rows.append([sid, ad, kat, mrk,
                 al_adet, round(al_tut), round(bmal, 2),
                 ac, h["kap"], h["son12"], round(h["g"], 2),
                 round(h["tuk_ay"], 1) if h["tuk_ay"] is not None else None,
                 round(h["naive"], 1) if h["naive"] is not None else None,
                 h["gy_sezon"], round(h["sezon3"]), h["kap"] - round(h["sezon3"]),
                 round(donmus), bay, yorum(h, al_adet, ac, bay),
                 h["karakter"], h["onc12"], h["satis_ay"], h["stoklu_ay"],
                 round(h["aylik_ort"], 1), round(h["sezon_pay"] * 100), h["g_kaynak"], h["history_ay"],
                 satildi, diger])
    denetim.append(dict(sid=sid, bay=bay, bmal=bmal, al_tut=al_tut, al_adet=al_adet, donmus=donmus,
                        satildi=satildi, diger=diger, **h))   # h zaten ac/kap içerir
rows.sort(key=lambda r: (-(r[16] or 0), -(r[5] or 0)))   # bağlı para, sonra alış tutar

# ================= OTOMATİK TUTARLILIK DENETİMİ (regresyon guard) =================
def dogrula(D):
    ihlal = {}
    def ek(sid, kural): ihlal.setdefault(kural, []).append(sid)
    for x in D:
        s = x["sid"]; bay = x["bay"]; kap = x["kap"]; ac = x["ac"]
        aysonu = ac + x["al_adet"] - x["satildi"] + x["diger"]
        if aysonu != kap: ek(s, "roll-forward kapanmıyor (ay başı+alınan−satılan+diğer≠ay sonu)")
        if x["son12"] > 0 and x["stoklu_ay"] == 0: ek(s, "sattı ama stoklu-ay=0")
        if x["bmal"] <= 0 and x["al_tut"] > 0: ek(s, "birim maliyet 0 ama bu ay alış değeri var")
        if x["donmus"] > 0 and not any(t in bay for t in ("FAZLA", "UZUN-KUYRUK", "KÜÇÜK-ALIM")):
            ek(s, "bağlı para var ama etiket fazla-ailesi değil")
        if "🔴 FAZLA" in bay and (x["tuk_ay"] or 0) <= ESIK: ek(s, "FAZLA ama tükenme ≤12 ay")
        if x["g_kaynak"] == "ürün" and x["onc12"] < 100: ek(s, "büyüme 'ürün' ama taban<100")
        if x["g_kaynak"] == "kategori" and x["onc12"] >= 100: ek(s, "büyüme 'kategori' ama taban≥100")
        if x["karakter"] == "DÜŞÜŞ" and x["g"] >= 0.7: ek(s, "karakter DÜŞÜŞ ama büyüme≥0.7")
        if x["karakter"] == "SEZONSAL" and x["sezon_pay"] < 0.5: ek(s, "karakter SEZONSAL ama sezon-payı<0.5")
        if x["karakter"] == "NORMAL" and x["satis_ay"] < 9: ek(s, "karakter NORMAL ama satışlı-ay<9")
        if x["karakter"] == "DURGUN" and x["son24"] != 0: ek(s, "karakter DURGUN ama son24≠0")
        if kap < 0: ek(s, "ay sonu stok negatif")
        if "AZ ALMIŞ" in bay and kap >= x["sezon3"]: ek(s, "AZ-ALMIŞ ama ay sonu≥beklenen")
        if x["stoklu_ay"] > 0 and abs(x["aylik_ort"] - x["son12"] / x["stoklu_ay"]) > 0.5:
            ek(s, "aylık hız ≠ son12/stoklu-ay")
        if x["tuk_ay"] is None and x["son12"] > 0 and kap > 0: ek(s, "tükenme boş ama satış+stok var")
    return ihlal
_ihlal = dogrula(denetim)
if _ihlal:
    print("⚠️ TUTARLILIK İHLALLERİ:", flush=True)
    for k, sids in sorted(_ihlal.items(), key=lambda kv: -len(kv[1])):
        print(f"   [{len(sids)}] {k}  (ör: {sids[:5]})", flush=True)
else:
    print("✓ Tutarlılık denetimi temiz (ihlal yok).", flush=True)

# ---- türetilen kolonları Excel FORMÜLÜNE çevir (kaynak izlenebilir olsun; sıralama SONRASI, gerçek satır no) ----
def _L(name): return get_column_letter(HEAD.index(name) + 1)
_ab, _al = _L("Ay Başındaki Stok"), _L("Bu Ay Alınan (adet)")
_sat, _dig = _L("Bu Ay Satılan (adet)"), _L("Bu Ay Diğer Hareket (transfer/sayım)")
_as = _L("Ay Sonundaki Stok (=başı+alınan−satılan+diğer)")
_s12, _stok = _L("Son 12 Ay Satış (adet)"), _L("Yılda Kaç Ay Stoklu (12'de)")
_gy, _buy = _L("Geçen Yıl Sezon Satışı (adet)"), _L("Yıllık Büyüme (bu yıl ÷ geçen yıl)")
_bek = _L("Bu Sezon Beklenen Satış (=geçen sezon×büyüme)")
iAS = HEAD.index("Ay Sonundaki Stok (=başı+alınan−satılan+diğer)")
iHIZ = HEAD.index("Aylık Satış Hızı (=son12÷stoklu ay)")
iBEK = HEAD.index("Bu Sezon Beklenen Satış (=geçen sezon×büyüme)")
iKAL = HEAD.index("Sezon Sonrası Elde Kalacak (=ay sonu−beklenen)")
iBAS = HEAD.index("Kaç Ayda Tükenir (basit)")
iSPY = HEAD.index("Satışın Sezon Payı (%)")
for i, r in enumerate(rows):
    er = i + 2
    r[iAS]  = f"={_ab}{er}+{_al}{er}-{_sat}{er}+{_dig}{er}"
    r[iHIZ] = f"=IFERROR({_s12}{er}/{_stok}{er},0)"
    r[iBEK] = f"=ROUND({_gy}{er}*{_buy}{er},0)"
    r[iKAL] = f"={_as}{er}-{_bek}{er}"
    r[iBAS] = f'=IFERROR(ROUND({_as}{er}/({_s12}{er}/12),1),"")'
    r[iSPY] = f"=IFERROR(ROUND({_gy}{er}/{_s12}{er}*100,0),0)"

# ---- özet kırılımları (KATEGORİ + MARKA) — sistematik pattern ----
def ozetle(key_idx):
    g = {}
    for r in rows:
        k = r[key_idx] or "—"
        e = g.setdefault(k, dict(sku=0, adet=0, tl=0, fazla=0, olu=0, az=0, izle=0, yeni=0, donmus=0))
        e["sku"] += 1; e["adet"] += r[4] or 0; e["tl"] += r[5] or 0; e["donmus"] += r[16] or 0
        d = r[17] or ""
        if "FAZLA" in d: e["fazla"] += 1
        elif "ÖLÜ" in d: e["olu"] += 1
        elif "UZUN-KUYRUK" in d or "KÜÇÜK-ALIM" in d: e["izle"] += 1   # materiality/min-koli → izle
        elif "YENİDEN" in d: e["izle"] += 1      # restok = izle
        elif "GENÇ" in d: e["yeni"] += 1         # genç = değerlendirme dışı (muaf)
        elif "TREND" in d: e["az"] += 1          # trend-hızlı = temkinli-al (az tarafı)
        elif "AZ ALMIŞ" in d: e["az"] += 1
        elif "İZLE" in d: e["izle"] += 1
        elif "DEĞERLENDİRME" in d: e["yeni"] += 1  # 24-ay satmayan = muaf
    out = [[k, v["sku"], v["adet"], round(v["tl"]), v["fazla"], round(v["donmus"]),
            v["olu"], v["az"], v["izle"], v["yeni"]] for k, v in g.items()]
    out.sort(key=lambda x: -x[5])
    return out
OZ_TAIL = ["SKU", "Alış Adet", "Alış Tutar ₺", "🔴FAZLA", "Bağlı Para ₺",
           "🔴ÖLÜ", "🟢AZ-ALMIŞ", "🟠İZLE", "Muaf(genç/durgun)"]
kat_rows = ozetle(2); kat_h = ["Kategori"] + OZ_TAIL
marka_rows = ozetle(3); marka_h = ["Marka/Yayınevi"] + OZ_TAIL

# ---- özet sayılar (Notlar için) ----
fazla = [r for r in rows if "FAZLA" in r[17]]
olu = [r for r in rows if "ÖLÜ" in r[17]]
muaf = [r for r in rows if "DEĞERLENDİRME" in r[17] or "GENÇ" in r[17]]
az = [r for r in rows if "AZ ALMIŞ" in r[17]]
trend = [r for r in rows if "TREND" in r[17]]
restok = [r for r in rows if "YENİDEN" in r[17]]
uzun = [r for r in rows if "UZUN-KUYRUK" in r[17] or "KÜÇÜK-ALIM" in r[17]]
donmus_tot = sum(r[16] or 0 for r in fazla)
mal0 = sum(1 for r in fazla if (r[6] or 0) == 0)
top_kat = kat_rows[0] if kat_rows else ["—", 0, 0, 0, 0, 0]
top_mrk = marka_rows[0] if marka_rows else ["—", 0, 0, 0, 0, 0]
kar = {}
for r in rows:
    kar[r[19]] = kar.get(r[19], 0) + 1
kar_txt = " · ".join(f"{k}:{v}" for k, v in sorted(kar.items(), key=lambda x: -x[1]))

# ---- Excel ----
red = PatternFill("solid", fgColor="E30622"); white = Font(color="FFFFFF", bold=True)
thin = Border(*[Side(style="thin", color="E2E8F0")] * 4)
ctr = Alignment(horizontal="center", vertical="center", wrap_text=True)
left = Alignment(horizontal="left", vertical="top", wrap_text=True)
def yaz(ws, head, data, widths, num_cols, freeze="A2"):
    for ci, hh in enumerate(head, 1):
        c = ws.cell(1, ci, hh); c.fill = red; c.font = white; c.alignment = ctr; c.border = thin
    ws.freeze_panes = freeze
    for ri, r in enumerate(data, 2):
        for ci, v in enumerate(r, 1):
            c = ws.cell(ri, ci, v); c.border = thin
            if ci in num_cols: c.number_format = "#,##0"
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w
    ws.auto_filter.ref = f"A1:{get_column_letter(len(head))}{len(data)+1}"

wb = openpyxl.Workbook()
ws1 = wb.active; ws1.title = "Ürün Detay"
yaz(ws1, HEAD, rows,
    [8, 40, 12, 18, 10, 13, 12, 13, 20, 12, 14, 16, 14, 15, 20, 18, 15, 34, 62, 14, 16, 13, 13, 16, 13, 14, 13, 13, 16],
    {5, 6, 7, 8, 9, 10, 14, 15, 16, 17, 21, 22, 23, 25, 27, 28, 29}, freeze="C2")

# Her başlık hücresine NOT (ne işe yarar · nasıl hesaplandı · nasıl bakılır) — fareyle üstüne gel
KOMENT = {
    "Bu Ay Alınan (adet)": "NE: Bu ay satın alınan adet.\nNASIL: irsHrk fiziki stok girişi (ehTip 0 Alış + 10 Yerel Alım).\nBAK: Son 12 Ay Satış'ın kaç katı? Çok üstündeyse fazla-alım şüphesi.",
    "Bu Ay Alış Tutarı (₺, KDV'siz)": "NE: Bu ayki alışın parası (KDV-hariç net).\nNASIL: irsHrk ehTutarN toplamı.\nBAK: adet × birim maliyet civarı.",
    "Birim Maliyet (₺)": "NE: Bir adedin alış maliyeti (KDV-hariç).\nNASIL: Son alış faturası birim; yoksa 31.05.2021 devir. Bağlı-para hesabında kullanılır.",
    "Ay Başındaki Stok": "NE: Ay başında eldeki fiziki stok (şube+depo).\nNASIL: = Ay Sonu − bu ayın net hareketi (ledger delta).",
    "Ay Sonundaki Stok (=başı+alınan−satılan+diğer)": "NE: Ay sonunda eldeki fiziki stok.\nNASIL: Excel formülü = Ay Başı + Bu Ay Alınan − Bu Ay Satılan + Diğer. Fiziki: şube(stokSon)+depo(WMS). Hücreye tıkla, kaynağı gör.",
    "Son 12 Ay Satış (adet)": "NE: Son 12 ayda satılan toplam adet (şube + e-ticaret).\nBAK: Ana talep göstergesi. Bu Ay Alınan bunun kaç katı = kaç yıllık aldın.",
    "Yıllık Büyüme (bu yıl ÷ geçen yıl)": "NE: Talep büyüme katsayısı.\nNASIL: Son 12 Ay ÷ Geçen Yıl Toplam (taban≥100 ise ürünün kendi YoY'u; ince ise kategori sezon oranı).\nBAK: >1 büyüyor · <1 düşüyor.",
    "Kaç Ayda Tükenir (sezon+büyüme)": "NE: Eldeki stok kaç ayda biter (ANA KARAR ölçüsü).\nNASIL: Ay sonu stok, geçen yılın aylık satış deseni × büyüme ile ileri yürütülür (sezonu + büyümeyi hesaba katar). 999 = pratikte tükenmez.\nBAK: >12 ay = FAZLA şüphesi.",
    "Kaç Ayda Tükenir (basit)": "NE: Sezonsuz kaba yeterlilik.\nNASIL: = Ay Sonu ÷ (Son 12 Ay ÷ 12). Kıyas için; karar bunun değil soldakinin.",
    "Geçen Yıl Sezon Satışı (adet)": "NE: Geçen yıl önümüzdeki sezonda (Ağu-Eyl-Eki) FİİLEN satılan adet.\nBAK: Tahminin ham dayanağı (şeffaflık).",
    "Bu Sezon Beklenen Satış (=geçen sezon×büyüme)": "NE: Bu sezon beklenen satış.\nNASIL: Excel formülü = Geçen Yıl Sezon × Büyüme.",
    "Sezon Sonrası Elde Kalacak (=ay sonu−beklenen)": "NE: Sezon geçtikten sonra elde kalacak.\nNASIL: = Ay Sonu − Bu Sezon Beklenen. NEGATİF = sezon hepsini yer → stockout riski, daha al.",
    "Fazla Stokta Bağlı Para (₺)": "NE: Fazla stokta donmuş sermaye (sezonluk).\nNASIL: (Ay Sonu − Bu Sezon Beklenen) × Birim Maliyet — sezon-sonrası kalan. Sadece FAZLA'da dolu (linear değil).",
    "Değerlendirme": "NE: Sonuç etiketi (FAZLA / AZ-ALMIŞ / ÖLÜ / TREND / GENÇ ...).\nBAK: Anlamları 'Kapsam & Yorum' sayfasında Etiket Sözlüğü'nde.",
    "Açıklama / Gerekçe": "NE: Etiketin kanıtlı gerekçesi (tek cümle) — rakamlarla neden bu sonuç.",
    "Ürün Karakteri": "NE: Satış deseni tipi: NORMAL(istikrarlı) / SEZONSAL / TREND(fad) / DÜŞÜŞ / DÜZENSİZ / GENÇ / DURGUN.\nBAK: Ayrım mantığı 'Kapsam & Yorum' sayfasında.",
    "Geçen Yıl Toplam Satış (büyüme tabanı)": "NE: Önceki 12 ayın satışı = büyüme katsayısının paydası.\nBAK: <100 ise büyüme güvenilmez → kategori oranı kullanılır.",
    "Yılda Kaç Ay Satmış (12'de)": "NE: Son 12 ayın kaçında satış oldu (istikrar).\nBAK: ≥9 = istikrarlı staple · düşük = spiky (sezon/fad).",
    "Yılda Kaç Ay Stoklu (12'de)": "NE: Son 12 ayın kaçında ŞUBE stoğu vardı (satabilir miydi).\nNASIL: bkm.StokAyBakiyeMekanBazli tablosundan.\nBAK: ≥6 stoklu + hiç satış = gerçek ÖLÜ.",
    "Aylık Satış Hızı (=son12÷stoklu ay)": "NE: Gerçek aylık satış hızı.\nNASIL: Excel formülü = Son 12 Ay ÷ Stoklu Ay (stoksuz ayları saymaz).",
    "Satışın Sezon Payı (%)": "NE: Satışın önümüz-sezondaki payı.\nNASIL: = Geçen Yıl Sezon ÷ Son 12 Ay × 100.\nBAK: Yüksek (≥50) = sezonsal ürün.",
    "Büyüme Kaynağı (ürün/kategori)": "NE: Büyüme katsayısı nereden geldi.\n'ürün' = kendi YoY'u (taban≥100) · 'kategori' = taban ince, kategori sezon oranı.",
    "Stoğa İlk Girişten Beri (ay)": "NE: Ürün stoğa ilk kez ne zaman girdi (alış/sevk/stok-ekle/devir).\nBAK: <12 ay = GENÇ (tam yıllık satış geçmişi yok → değerlendirme için erken).",
    "Bu Ay Satılan (adet)": "NE: Bu ay satılan adet (şube + e-tic). Roll-forward'ın çıkış kalemi.",
    "Bu Ay Diğer Hareket (transfer/sayım)": "NE: Bu ayki transfer/sayım/iade net hareketi.\nBAK: Alıcının kararı DEĞİL; roll-forward'ı kapatmak için (ay başı+alınan−satılan+diğer=ay sonu).",
}
for ci, hh in enumerate(HEAD, 1):
    if hh in KOMENT:
        cm = Comment(KOMENT[hh], "Rapor"); cm.width = 300; cm.height = 150
        ws1.cell(1, ci).comment = cm
yaz(wb.create_sheet("Kategori Özeti"), kat_h, kat_rows, [14, 8, 11, 15, 9, 15, 8, 11, 9, 11], {3, 5})
yaz(wb.create_sheet("Marka Özeti"), marka_h, marka_rows, [30, 8, 11, 15, 9, 15, 8, 11, 9, 11], {3, 5})

# ---- Kapsam & Yorum sayfası ----
wsN = wb.create_sheet("Kapsam & Yorum")
notlar = [
    (f"SATINALMA HESAP-SORMA — {AY[:4]}-{AY[4:]} · Kapsam & Yorum", True),
    ("", False),
    ("GENEL YORUM", True),
    (f"• {len(fazla)} SKU GERÇEK FAZLA (materyal, ≥{MAT_ESIK}₺ + koli>{MIN_KOLI}) · bağlı para ~{donmus_tot:,.0f} ₺ (alt-sınır). Ayrıca {len(uzun)} küçük/uzun-kuyruk (düşük öncelik, ayrıldı).", False),
    (f"• {len(olu)} ÖLÜ-ALIM (stok vardı 12 ay satmadı) · {len(az)} AZ-ALMIŞ (sezon eritir → daha alınmalı) · {len(trend)} TREND-HIZLI (temkinli, bulk riskli) · {len(restok)} YENİDEN-STOK (stoksuzdu, restok).", False),
    (f"• {len(muaf)} ürün MUAF (genç <12 ay veya 24 ay satmayan) → değerlendirme dışı (adil).", False),
    (f"• Ürün karakteri dağılımı: {kar_txt}.", False),
    (f"• En çok bağlı-para kategori: {top_kat[0]} ({top_kat[4]} FAZLA, {top_kat[5]:,.0f} ₺). En çok marka: {top_mrk[0]} ({top_mrk[4]} FAZLA, {top_mrk[5]:,.0f} ₺).", False),
    ("• FAZLA = ay sonu stok, önümüzdeki sezon (geçen yıl aynı dönem × KATEGORİ büyüme katsayısı) DAHİL 12 aydan uzun sürede erir. Sezon + büyüme + genç ürün + stockout confound'ları ayrık.", False),
    ("", False),
    ("KOLON SÖZLÜĞÜ (formüller Excel'de canlı — hücreye tıkla, kaynağı gör)", True),
    ("• Ay Başındaki Stok: ay başında eldeki fiziki adet (mağaza + depo, irsHrk defter bakiyesi).", False),
    ("• Bu Ay Satılan / Bu Ay Diğer Hareket: bu ay satış (şube+e-tic) / transfer-sayım-iade. ROLL-FORWARD: Ay Sonu = Ay Başı + Bu Ay Alınan − Bu Ay Satılan + Diğer (Excel formülü, izlenebilir).", False),
    ("• Son 12 Ay Satış: son 12 ayda satılan toplam adet (mağaza + e-ticaret).", False),
    ("• Büyüme Katsayısı: ÜRÜNÜN geçen 12 ay / önceki 12 ay satış oranı (ör. 7,5 = 7,5 kat büyüme; 0,2 = çöküş). Önceki yıl <12 adet satan ince ürünlerde kategori sezon oranına düşülür. Gelecek talebi bununla ölçekliyoruz.", False),
    ("• Yıllık Büyüme = Son 12 Ay Satış ÷ Geçen Yıl Toplam Satış (ör. 5,0 = 5 kat; 0,3 = çöküş). Taban <100 ise ürün yerine kategori sezon oranı kullanılır (Büyüme Kaynağı kolonu gösterir).", False),
    ("• Kaç Ayda Tükenir (sezon+büyüme): ay sonu stok, geçen yılın aylık deseni × büyüme ile ileri yürütülünce kaç ayda biter (iteratif — bu kolon değer, ama girdileri yandaki kolonlarda görünür). ANA KARAR ölçüsü.", False),
    ("• Kaç Ayda Tükenir (basit) = Ay Sonu ÷ (Son 12 Ay ÷ 12). Sezonsuz kaba kıyas (Excel formülü).", False),
    ("• Geçen Yıl Sezon Satışı: geçen yıl önümüzdeki sezonda (Ağu-Eyl-Eki) FİİLEN satılan adet — tahminin ham dayanağı.", False),
    ("• Bu Sezon Beklenen Satış = Geçen Yıl Sezon Satışı × Yıllık Büyüme (Excel formülü).", False),
    ("• Sezon Sonrası Elde Kalacak = Ay Sonu − Bu Sezon Beklenen (Excel formülü; negatif = sezon hepsini yer = stockout riski).", False),
    ("• Fazla Stokta Bağlı Para = (Ay Sonu − Bu Sezon Beklenen) × Birim Maliyet — SEZONLUK sezon-sonrası kalan (linear değil; sezonsal üründe şişmez). Sadece FAZLA'da dolu.", False),
    ("• Ürün Karakteri: satış deseni tipi (aşağıda) — NORMAL / SEZONSAL / TREND / DÜŞÜŞ / DÜZENSİZ / GENÇ / DURGUN.", False),
    ("• Geçen Yıl Toplam Satış (taban): önceki 12 ayın satışı — büyüme paydası. <100 = büyüme güvenilmez → kategori.", False),
    ("• Yılda Kaç Ay Satmış: son 12 ayın kaçında satış oldu. ≥9 = istikrarlı staple; düşük = spiky (sezon/fad).", False),
    ("• Yılda Kaç Ay Stoklu: son 12 ayın kaçında stok vardı. ≥6 stoklu + hiç satış yok = gerçek ÖLÜ (satabilirdi).", False),
    ("• Aylık Satış Hızı = Son 12 Ay Satış ÷ Yılda Kaç Ay Stoklu (Excel formülü; stoksuz ayları saymaz → gerçek hız).", False),
    ("• Satışın Sezon Payı % = Geçen Yıl Sezon Satışı ÷ Son 12 Ay × 100 (Excel formülü). Yüksek = sezonsal.", False),
    ("• Büyüme Kaynağı: 'ürün' (kendi YoY'u, taban ≥100) veya 'kategori' (taban ince → kategori sezon oranı).", False),
    ("• Stoğa İlk Girişten Beri (ay): ürün stoğa ilk kez ne zaman girdi (alış/sevk/stok-ekle/devir). <12 ay = GENÇ (değerlendirme için erken).", False),
    ("", False),
    ("ÜRÜN KARAKTERİ — SEZONSAL / TREND / NORMAL NASIL AYRILIR", True),
    ("Tek sayı (büyüme) trend'i ayırmaz; SATIŞ DESENİNE (şekil) bakılır. Sıra ile ilk uyan:", False),
    ("• DURGUN: 24 ayda hiç satış yok → talep verisi yok, değerlendirme dışı.", False),
    ("• GENÇ: ilk satış <12 ay → tam sezon geçmişi yok, hüküm erken.", False),
    ("• NORMAL (staple): yılın ≥9 ayı satar (istikrarlı, ör. kurşun kalem ucu). Büyüme güvenilir, standart değerlendirme.", False),
    ("• SEZONSAL: satışın çoğu (≥%50) okul sezonunda toplanır, yılın kalanı durgun (ör. kitap kabı, okul seti). Her yıl TEKRAR eder → stoklamak doğru; tükenme zaten sezon-şekliyle hesaplanır, 'trend' sayılmaz.", False),
    ("• TREND / FAD: spiky (birkaç ay) + sezon-DIŞI + son yıl 2 kat+ büyüme (ör. sezon-dışı slime patlaması). Hız kalıcı DEĞİL → 'daha al' tehlikeli, kısa-vade küçük parti; bulk trend bitince elde kalır.", False),
    ("• DÜŞÜŞ: büyüme <0,7 → talep azalıyor (fazla alım riski yüksek).", False),
    ("• DÜZENSİZ: net desen yok (dalgalı) → temkinli yorumla.", False),
    ("Neden önemli: SEZONSAL ile TREND aynı 'yüksek büyüme'yi gösterebilir; sezonsalı fad sanıp stoklamayı kısmak stockout yapar, fad'ı sezonsal sanıp bulk almak donmuş stok yapar.", False),
    ("", False),
    ("DEĞERLENDİRME ETİKETLERİ", True),
    ("• 🔴 FAZLA: eldeki + alınan, sezon+büyüme dahil >12 ayda erir → aşırı alım.", False),
    ("• 🔴 ÖLÜ-ALIM: 12 ayın çoğu stokluydu ama hiç satmadı, yine de alındı.", False),
    ("• 🟢 AZ ALMIŞ: sezon eldeki stoğu eritir → stockout riski, DAHA alınmalı (istikrarlı talep).", False),
    ("• 🟠 TREND-HIZLI: son yıl 2 kat+ büyüdü (trend/fad) — hızlı satıyor ama kalıcı olmayabilir; kısa-vade küçük parti al, büyük bulk trend bitince elde kalır.", False),
    ("• 🟠 YENİDEN-STOK: son yıl stoksuzdu (satamadı), eski talep var, restok — ölü değil.", False),
    ("• 🟠 İZLE: sezon+büyüme dahil 6-12 ayda erir, sınırda.", False),
    ("• GENÇ ÜRÜN: 12 aydan yeni, tam sezon geçmişi yok → hüküm için erken (muaf).", False),
    ("• DEĞERLENDİRME DIŞI: 24 ayda hiç satış yok (yeni/durgun), talep verisi yok (muaf).", False),
    ("", False),
    ("KAPSAM NOTLARI (metodoloji)", True),
    ("1. Alış = fiziki stok-giriş (irsHrk ehTip 0 Alış + 10 Yerel Alım). Fatura-tarihine göre ~%8 fark AY-SINIRI zamanlamasıdır (ay sonu faturası, malın stok girişi sonraki ay); sonraki ay netleşir. Materyal alımlar birebir tutar.", False),
    ("2. Stok FİZİKİ-ankrajlı: Ay Sonu = ŞUBE (stokSon, irsHrk ile birebir) + DEPO (WMS anlık). Ay Başı = Ay Sonu − o ayın net hareketi (ledger delta güvenilir). Denklem Excel'de: ay başı + alınan − satılan + diğer = ay sonu.", False),
    ("2b. Yılda Kaç Ay Stoklu / ÖLÜ ayrımı = ŞUBE stoğu geri-sarılarak (fiziki şube − sonraki hareketler; irsHrk mekan 1/4477/4478, güvenilir). Satış şubeden olur → 'satabilir miydi' için şube stoğu yeterli. Depo (mekan 12) ledger'ı geçmişte bozuk, backfill edilmez.", False),
    ("3. Tükenme (satış) = şube (irsHrk 1/4/100) + e-ticaret (JOKER). Tüm tutarlar KDV-hariç net.", False),
    ("4. Büyüme katsayısı = ÜRÜN YoY (önceki-12-ay ≥12 adet ise güvenilir; floor 0,3 tavan 6). İnce/gürültülü veride (önceki-12-ay <12) KATEGORİ sezon YoY fallback (Kırtasiye ×1,37 · Oyuncak ×1,61 · Hediyelik ×2,54). Geçen yıl verisi yok + FAZLA → suçlama zayıf, İZLE'ye yumuşatılır.", False),
    ("4b. Büyüme primi SÖNÜMLÜ: boom (g>1) ileri projeksiyonda 12 ayda baseline'a iner (trend/fad kalıcı sayılmaz); çöküş (g<1) sürer. Sonsuz-boom ekstrapolasyonu yok.", False),
    (f"5. Fazla Stokta Bağlı Para = fazla-adet × birim maliyet (son fatura > 2021 devir fallback). ALT-SINIR: {mal0} FAZLA üründe maliyet yok (0 sayıldı) → gerçek biraz daha yüksek.", False),
    ("6. Adil-atıf kapıları: GENÇ (<12 ay geçmiş) ve DEĞERLENDİRME DIŞI (24 ay satmayan) FAZLA'dan muaf; stockout (stoksuz ay) ÖLÜ sayılmaz. Atıf = Kategori3 + Marka (kişi değil).", False),
    ("7. Overclaim yasak: her etiket kanıt + confound taşır; 'kötü alıcı' yargısı YOK.", False),
]
big = Font(bold=True, size=12); bold = Font(bold=True)
for ri, (txt, hdr) in enumerate(notlar, 1):
    c = wsN.cell(ri, 1, txt); c.alignment = left
    if hdr: c.font = big if ri == 1 else bold
wsN.column_dimensions["A"].width = 160

# ---- EK SAYFALAR: Aylık Stok Bakiye (şube) + Aylık Satış (şube+e-tic) ----
def sbal_at(sid, M):                                # M ayı-sonu toplam şube bakiyesi (son değer taşınır)
    t = 0
    for lst in sube_series.get(sid, {}).values():
        last = 0
        for ay, st in lst:
            if ay <= M: last = st
            else: break
        t += last
    return t
AYLAR = ONC12 + SON12                               # 24 ay (eskiden yeniye)
sube_rows, etic_rows, stok_rows = [], [], []
for sid in ids:
    _sa, ad, kat, mrk = master.get(sid, ("—", "", "", ""))
    ds = aylik_sube.get(sid, {}); de = aylik_etic.get(sid, {})
    sube_rows.append([sid, ad, kat, mrk] + [ds.get(ay, 0) for ay in AYLAR])
    etic_rows.append([sid, ad, kat, mrk] + [de.get(ay, 0) for ay in AYLAR])
    stok_rows.append([sid, ad, kat, mrk] + [sbal_at(sid, ay) for ay in AYLAR] + [fiziki_depo.get(sid, 0)])
for R in (sube_rows, etic_rows, stok_rows):
    R.sort(key=lambda r: (r[2] or "", r[1] or ""))       # kategori, ad
ID4 = ["Ürün Kodu", "Ürün Adı", "Kategori", "Marka"]
W4 = [8, 40, 12, 18]
yaz(wb.create_sheet("Aylık Satış (Şube)"), ID4 + AYLAR, sube_rows, W4 + [9] * len(AYLAR),
    set(range(5, 5 + len(AYLAR))), freeze="E2")
yaz(wb.create_sheet("Aylık Satış (E-tic)"), ID4 + AYLAR, etic_rows, W4 + [9] * len(AYLAR),
    set(range(5, 5 + len(AYLAR))), freeze="E2")
yaz(wb.create_sheet("Aylık Stok Bakiye"), ID4 + AYLAR + ["Depo (anlık WMS)"], stok_rows,
    W4 + [9] * len(AYLAR) + [13], set(range(5, 6 + len(AYLAR))), freeze="E2")

out = os.path.join(os.path.dirname(__file__), "..", "raporlar", f"satinalma-hesap-{AY}.xlsx")
os.makedirs(os.path.dirname(out), exist_ok=True)
try:
    wb.save(out)
except PermissionError:                       # dosya Excel'de açık → kilit; alternatif isimle kaydet
    out = out.replace(".xlsx", "-yeni.xlsx")
    wb.save(out)
    print("UYARI: ana dosya açık (kilitli) → -yeni.xlsx'e yazıldı.", flush=True)
print(f"BITTI · {len(rows)} alım satırı · sayfalar: Ürün Detay / Kategori Özeti / Marka Özeti / Kapsam & Yorum")
print(f"  🔴 FAZLA: {len(fazla)} · bağlı para ~{donmus_tot:,.0f} ₺ (maliyet=0 olan {mal0} hariç)")
print(f"  🔴 ÖLÜ: {len(olu)} · 🟢 AZ-ALMIŞ: {len(az)} · 🟠 TREND-HIZLI: {len(trend)} · 🟠 YENİDEN-STOK: {len(restok)} · MUAF: {len(muaf)}")
print(f"  karakter: {kar_txt}")
print(f"  kategori büyüme katsayısı: {g_kat}")
print(" -> " + os.path.abspath(out))
