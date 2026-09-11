# -*- coding: utf-8 -*-
"""KİTAPDIŞI SİPARİŞ ÖNERİSİ → Excel (miktar + satış taahhüdü + çıkış planı).

Kullanıcı isteği 10.09.2026: _"sen bir kitapdışı satınalmacısı olsan hangi ürünlere kaç tane
sipariş verirdin kaç tane satmasını planlardın"_ → skill `.claude/skills/siparis-karari/SKILL.md`,
bu script onun EMITTER'ı (hesap çekirdeği burada, panelde henüz yok — TODO B-171(a)).

⚠ KULLANICI DİREKTİFİ (10.09.2026): _"yeni gelen sezon siparişlerini var olarak görme"_
→ açık satın alma siparişi (yolda mal) **eldeki stoktan DÜŞÜLMEZ**; kolonda GÖSTERİLİR ve
özet sayfasında "netlenirse öneri şu kadar düşer" olarak ayrıca yazılır. İki okuma da
görünür kalsın diye böyle: karar kullanıcının.

═══ KOHORT (paneldeki ölçütle AYNI) ═════════════════════════════════════════════
Kategori3 ∈ {Kırtasiye, Oyuncak, Hediyelik, Elektronik, Spor & Outdoor}
  · 365 günde satış ≥ 5 adet          → talep KANITI var (censored: bu bir ALT SINIR)
  · ToplamStok < kapak                 → KAPAK ALTI (stok 0 bunun yalnız uç hâli)
  · defter güvenilir: StokFsm/StokOzl/StokIst/MerkezStok ≥ 0 AND SatisFiyat > 0
Aşırı/ölü stok havuzlarına sipariş YAZILMAZ (o taraf indirim/iade işi).

═══ İKİ LİSTE ═══════════════════════════════════════════════════════════════════
A-SÜREKLİ  (SatanAy ≥ 6) → BUGÜN sipariş yazılır.
B-SEZON/SEYREK (SatanAy < 6) → bu sezon YAZILMAZ. Bugün 10.09; sezon (Tem–Eki) 2/3 geçmiş,
  5-7 günde gelen mal sezon KUYRUĞUNA yetişir → gelecek sezon ön-sipariş listesi.

═══ MİKTAR ══════════════════════════════════════════════════════════════════════
    hız      = Satis365 / 365                       (gün başına; alt sınır)
    kapak    = max(hız, sezon penceresi) × (temin süresi + 30 gün gözden geçirme)
               ↑ sezon penceresi = geçen yılın AYNI takvim aralığındaki satış (Ağu/Eyl/Eki)
    emniyet  = z × sqrt(CV² / SatanAy) × kapak      (kapağın %100'ünü AŞAMAZ)
    öneri    = ceil(kapak + emniyet)
    tavan    = kategori eşiği × sezon satışı        (Kırtasiye 2× · diğer 3×) — AŞILAMAZ
    z: Kırtasiye/Elektronik 1,65 (%95) · Oyuncak/Hediyelik 1,04 (%85)
⚠ KOHORT DÜZELTMESİ (10.09.2026 akşamı, kullanıcı: _"çok çok az bu sipariş rakamları emin
misin"_): ölçüt `ToplamStok = 0` idi. Kırtasiye'de ölçüldü — o ölçüt 796 çeşit / 1.114 adet
gösterirken kapağın altına düşmüş gerçek ihtiyaç **1.687 çeşit / 14.528 adet**ti; liste
gerçeğin ~**1/13'ünü** görüyordu. Artık kohort kapak altı; öneriden **eldeki stok düşülür**
ve satırlar ACİL (rafta yok) / İKMAL (kapak altı) diye ayrılır.

⚠ Emniyette CV² **SatanAy'a bölünür**. İlk sürümde `z·sqrt(CV²)` yazılıydı ve sıçramalı
üründe stok şişiriyordu (Noki sunum dosyası CV²=6,11 → 248 adet önerdi, 12 haftalık plan 114).
Aralıklı talepte belirsizliğin cevabı daha çok stok DEĞİL, daha sık sipariştir.

═══ SATIŞ TAAHHÜDÜ + ÇIKIŞ ══════════════════════════════════════════════════════
Her satır üç sayı taşır (skill sözleşmesi 1): adet · hedef sell-through (%+hafta) · tutmazsa
çıkış eylemi. Taahhüt sipariş ANINDA yazılırsa hesap sorulabilir; sonradan konan eşik geriye
dönük yargıdır.

═══ ÖLÇÜLMEDİ / SINIR ══════════════════════════════════════════════════════════
· Talep tahminleri **ALT SINIR** — raf boşken satış kesilmiş (sağdan sansürlü; EM düzeltmesi yok).
· Croston/SBA/TSB beklenen değeri YOK — 365g hızı vekil (TODO B-171(a)).
· MOQ / koli katı veride yok → adetler yuvarlanmadı; tedarikçiyle teyit gerek.
· Tedarikçi iade hakkı veride izli değil (`urn.alimIadeYok` tek değer) → **kesin alım varsayıldı**.
· Birim maliyeti 0/NULL olan çeşitlerde yatırım tutarı EKSİK sayılır (özet sayfada adedi yazılı).
· Alıcı boyutu veride yok — liste ürün bazlı, kişiye atıf yapılmıyor.

⚠ pyodbc (pymssql DEĞİL): DerinSIS varchar CP1254, pymssql Türkçe'yi bozar.

Kullanım:
    python scripts/siparis_onerisi_excel.py [--kesim 2026-09-09] [--sezon 2025]
                                            [--net-acik-siparis] [--cikti yol.xlsx]
    --net-acik-siparis : açık siparişi eldeki stok gibi DÜŞ (kullanıcı direktifinin TERSİ,
                         kıyas için; varsayılan KAPALI)
Çıkış: 0 dosya yazıldı · 2 KOŞAMADI (bağlantı/şema/boş sonuç — sessizlik kanıt değil).
"""
from __future__ import annotations

import argparse
import datetime as dt
import io
import math
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

KITAPDISI = ("Kırtasiye", "Oyuncak", "Hediyelik", "Elektronik", "Spor & Outdoor")
Z_YUKSEK = ("Kırtasiye", "Elektronik")     # %95 hizmet düzeyi — sürekli raf malı
ESIK_KAT = {"Kırtasiye": 2}                # diğer kitapdışı 3× (panel geneli)
GOZDEN_GECIRME_GUN = 30                    # aylık sipariş turu
PLAN_HAFTA = 12
HEDEF_SELLTHROUGH = 0.70                   # A listesi: 12 haftada %70


def kosamadi(mesaj: str) -> None:
    """Ölçüm YAPILAMADI → çıkış 2. Boş sonuç ile hiç koşmamak ekranda aynı görünür."""
    print(f"KOSAMADI: {mesaj}", file=sys.stderr)
    raise SystemExit(2)


def env_oku(yol: str) -> dict[str, str]:
    """`.env` — kimlik YALNIZ burada durur (dört sözleşme: tek kimlik yolu)."""
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
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 900
    return cn


# Açık sipariş süzgeci panelle AYNI: yalnız SATIN ALMA (0 Alış · 3 Yerel Alım), iptal hariç.
# Süzgeç olmadan 9 Alış İade Emri / 1 Satış / 13 Depo-Mağaza da "yolda mal" sayılıyordu
# (adetin %86'sı) — sql-server-conventions § açık sipariş eTip.
SQL = """
WITH t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = ? AND SezonYil = ?
      AND Kategori3 IN (N'Kırtasiye', N'Oyuncak', N'Hediyelik', N'Elektronik', N'Spor & Outdoor')
      AND StokFsm >= 0 AND StokOzl >= 0 AND StokIst >= 0 AND MerkezStok >= 0 AND SatisFiyat > 0
      AND SatisToplam >= 5
      -- KAPAK ALTI (10.09.2026 duzeltmesi). Eski olcut `ToplamStok = 0` idi ve
      -- gercek ikmal ihtiyacinin ~1/13'unu goruyordu: Kirtasiye'de 796 cesit
      -- gosterirken kapagin altina dusmus 1.687 cesit / 14.528 adet vardi.
      -- Perakende siparisinin GOVDESI "stogu var ama yetersiz"tir; stok=0 onun
      -- yalniz en uc halidir (ve orada kayip ZATEN yasaniyor).
      AND CONVERT(decimal(18,4), ToplamStok)
          < (SatisToplam / 365.0) * (CONVERT(decimal(9,2), ISNULL(LeadTime, 7)) + 30)
),
sup_raw AS (
    -- TEDARİKÇİ: son 24 ayın alımında (ehTip 0 Alış · 10 Yerel Alım) adet bazında BASKIN firma.
    -- Köprü sema'dan: bridges.yaml → irs-firma (dbo.irs.eFirma → dbo.frm.frmID, confidence 1.0).
    -- ⚠ 10.09'da bu köprü canlı keşfedilmişti (2 tur kayıp); artık sema'dan alınıyor.
    SELECT h.ehstkID AS stkID, i.eFirma AS frmID, ISNULL(f.frmAd, '(firma yok)') AS frmAd,
           SUM(h.ehAdetN) AS adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
    LEFT JOIN DerinSISBkm.dbo.frm f WITH (NOLOCK) ON f.frmID = i.eFirma
    WHERE h.ehTip IN (0, 10) AND h.ehTrhS >= DATEADD(MONTH, -24, CONVERT(date, ?))
    GROUP BY h.ehstkID, i.eFirma, f.frmAd
),
sup AS (
    SELECT stkID, frmID, frmAd,
           ROW_NUMBER() OVER (PARTITION BY stkID ORDER BY adet DESC) AS rn
    FROM sup_raw
),
acik AS (
    SELECT sa.ehstkID AS stkID,
           CONVERT(int, SUM(sa.ehAdet)) AS AcikAdet,
           COUNT(DISTINCT s.eID)        AS AcikBelge,
           MAX(s.eTarih)                AS SonSiparis
    FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
    WHERE s.eDurum <> 2 AND s.eTip IN (0, 3)
      AND s.eTarih >= DATEADD(DAY, -120, CONVERT(date, ?))
    GROUP BY sa.ehstkID
)
SELECT t.stkID,
       ISNULL(t.BarkodAna, '')                       AS Barkod,
       LEFT(ISNULL(t.stkAd, '(ad yok)'), 70)         AS Urun,
       t.Kategori3,
       ISNULL(t.Yayinevi, '')                        AS Marka,
       CONVERT(int, t.SatisToplam)                   AS Satis365,
       CONVERT(int, ISNULL(t.SezonToplam, 0))        AS SezonSatis,
       ISNULL(t.SatanAy, 0)                          AS SatanAy,
       CONVERT(decimal(9,2), ISNULL(t.TalepCV2, 1))  AS CV2,
       CONVERT(int, ISNULL(t.LeadTime, 7))           AS TeminGun,
       ISNULL(sp.frmID, 0)                           AS TedarikciID,
       ISNULL(sp.frmAd, '(tedarikçi bilinmiyor)')    AS Tedarikci,
       CONVERT(int, ISNULL(t.Ay1, 0))                AS SezonAgu,
       CONVERT(int, ISNULL(t.Ay2, 0))                AS SezonEyl,
       CONVERT(int, ISNULL(t.Ay3, 0))                AS SezonEki,
       CONVERT(int, t.ToplamStok)                    AS ToplamStok,
       CONVERT(int, t.MagazaStok)                    AS MagazaStok,
       CONVERT(int, t.MerkezStok)                    AS MerkezStok,
       CONVERT(int, ISNULL(t.OdakStok, 0))           AS OdakStok,
       CONVERT(int, ISNULL(a.AcikAdet, 0))           AS AcikSiparis,
       ISNULL(a.AcikBelge, 0)                        AS AcikBelge,
       a.SonSiparis                                  AS SonSiparisTarih,
       CONVERT(decimal(18,2), t.SatisFiyat)          AS Fiyat,
       CONVERT(decimal(18,2), ISNULL(t.BirimMaliyet, 0)) AS Maliyet,
       t.SonSatis                                    AS SonSatis
FROM t
LEFT JOIN acik a ON a.stkID = t.stkID
LEFT JOIN sup sp ON sp.stkID = t.stkID AND sp.rn = 1
ORDER BY t.SatisToplam DESC
"""

# BU YIL / GEÇEN YIL aynı takvim penceresi — sezon TEKRARLANABİLİR Mİ?
# ⚠ Geçen yılın sezonunu olduğu gibi sipariş etmek "bu yıl da aynı" varsayımıdır ve
# ÖLÇÜLMEDEN yapılamaz. Ölçüldü (1-9 Eylül, adet): Kırtasiye **0,77** · Oyuncak 1,50 ·
# Hediyelik 1,02 · Elektronik 0,96. Kırtasiye'de geçen yıl kadar almak %30 fazla almaktır.
SQL_SEZON_ORAN = """
SELECT ISNULL(ub.Kategori3, '(yok)') AS Kategori,
       CONVERT(decimal(9,4),
         -SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < ? THEN h.ehAdetN ELSE 0 END)
         / NULLIF(-SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < ? THEN h.ehAdetN ELSE 0 END), 0)
       ) AS Oran,
       CONVERT(int, -SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < ? THEN h.ehAdetN ELSE 0 END)) AS BuYilAdet
FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = h.ehstkID
WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
  AND ub.Kategori3 IN (N'Kırtasiye', N'Oyuncak', N'Hediyelik', N'Elektronik', N'Spor & Outdoor')
GROUP BY ub.Kategori3
"""
SEZON_ORAN_TABAN = 200      # bu yıl < 200 adet satmış kategoride oran GÜVENİLMEZ → 1,0
# Grup/ilişkili taraf firmalar (ODAK-POINT vb). Kaynak: sema bridges.yaml → irs-firma notu.
# Bunlara verilen sipariş grup İÇİ akış — dış tedarikçiyle aynı pazarlık/vade konusu değil.
ILISKILI_TARAF = {9525, 22100, 56, 38093, 4841, 23842, 58, 9339, 4694, 7950, 50582}      # bu yıl < 200 adet satmış kategoride oran GÜVENİLMEZ → 1,0

BEKLENEN_KOLONLAR = [
    "stkID", "Barkod", "Urun", "Kategori3", "Marka", "Satis365", "SezonSatis", "SatanAy",
    "CV2", "TeminGun", "TedarikciID", "Tedarikci", "SezonAgu", "SezonEyl", "SezonEki", "ToplamStok", "MagazaStok", "MerkezStok", "OdakStok",
    "AcikSiparis", "AcikBelge", "SonSiparisTarih",
    "Fiyat", "Maliyet", "SonSatis",
]

BASLIKLAR = [
    "stkID", "Barkod", "Ürün", "Kategori", "Marka", "Satış 365g", "Sezon satış",
    "Satan ay", "CV²", "Talep deseni", "Temin gün", "Tedarikçi", "İlişkili taraf",
    "Hız tabanı", "Eldeki stok", "Mağaza", "Merkez",
    "ODAK stok", "Açık sipariş (120g)", "Açık belge", "Aciliyet",
    "Kapak (adet)", "Fiyat ₺", "Birim maliyet ₺", "ÖNERİ ADET", "Yatırım ₺",
    f"Plan {PLAN_HAFTA} hafta adet", f"Plan {PLAN_HAFTA} hafta ₺",
    "Hedef sell-through", "Hedef tarih", "Tutmazsa çıkış eylemi", "Not",
]


def talep_deseni(satan_ay: int, cv2: float) -> str:
    """Syntetos/Boylan/Croston sınıflandırması — ADI 1,32 · CV² 0,49 eşikleri."""
    if not satan_ay:
        return "satış yok"
    adi = 12.0 / satan_ay
    if adi <= 1.32 and cv2 <= 0.49:
        return "düzgün"
    if adi <= 1.32:
        return "değişken"
    if cv2 <= 0.49:
        return "aralıklı"
    return "sıçramalı"


SEZON_AY = {8: "SezonAgu", 9: "SezonEyl", 10: "SezonEki"}   # taban Ay1/Ay2/Ay3


def pencere_talebi(r: dict, bas: dt.date, gun: int) -> float:
    """GEÇEN YILIN AYNI TAKVİM PENCERESİNDEKİ satışı (Ağu/Eyl/Eki aylıklarından orantılı).

    ⚠ NEDEN VAR (11.09.2026 ölçümü): düz 365g hızı SEZON ürününde talebi ÇOK düşük sayar.
    Kırtasiye'de sezon-yoğun 285 çeşit için ölçüldü — 50 günlük pencere talebi düz hızla
    **7.257 adet**, geçen yılın aynı penceresiyle **29.057 adet**: **4 kat fark**.
    Sebep: `Satis365` penceresi (Eyl-2025→Eyl-2026) sezonun Ağu-Eyl zirvesini dışarıda
    bırakıyor; ölçülen aylık dağılım Ağu 10.510 · **Eyl 29.193** · Eki 10.437 — zirve EYLÜL,
    yani tam şu an. Düz hızla sipariş = sezonun ortasında eksik almak.
    """
    toplam = 0.0
    for i in range(gun):
        g = bas + dt.timedelta(days=i)
        alan = SEZON_AY.get(g.month)
        if not alan:                    # sezon dışı gün (Kas-Tem) — aylık veri yok
            continue
        import calendar
        toplam += float(r[alan] or 0) / calendar.monthrange(g.year, g.month)[1]
    return toplam


def hesapla(r: dict, net_acik: bool, kesim: dt.date | None = None,
            oranlar: dict | None = None) -> dict:
    kat = r["Kategori3"]
    hiz = r["Satis365"] / 365.0
    temin = max(int(r["TeminGun"] or 7), 1)
    kapak = hiz * (temin + GOZDEN_GECIRME_GUN)
    # SEZON DÜZELTMESİ: pencere geçen yılın aynı takvim aralığına denk geliyorsa, düz hız
    # ile sezon talebinin BÜYÜĞÜ alınır. Sezon dışı üründe sezon penceresi zaten küçük →
    # max() onları etkilemez; yalnız sezon-yoğunu yukarı çeker.
    hiz_tabani = "365g düz"
    if kesim is not None:
        sezon_talep = pencere_talebi(r, kesim, temin + GOZDEN_GECIRME_GUN)
        # BU YIL / GEÇEN YIL oranı — sezonun tekrarlandığı VARSAYILMAZ, ölçülür.
        oran = (oranlar or {}).get(kat, 1.0)
        sezon_talep *= oran
        if sezon_talep > kapak:
            kapak = sezon_talep
            hiz_tabani = "sezon × %.2f" % oran
    z = 1.65 if kat in Z_YUKSEK else 1.04
    ay = max(int(r["SatanAy"] or 1), 1)
    emniyet = z * math.sqrt(max(float(r["CV2"] or 1.0), 0.0) / ay) * kapak
    emniyet = min(emniyet, kapak)          # kapağın %100'ünü aşamaz (sıçramalı koruması)
    # SEZON SONU EMNİYET TAVANI: taban sezon penceresiyse sezon BİTİYOR demektir; oradaki
    # asimetri terstir — eksik almanın bedeli kaçan satış, fazla almanınki ÖLÜ STOK (mal
    # gelecek sezona kalır ve kırtasiyede model/desen değişir). Emniyet %25'e iner.
    if hiz_tabani.startswith("sezon"):
        emniyet = min(emniyet, 0.25 * kapak)
    # ELDEKİ STOK DÜŞÜLÜR — kohort artık kapak altı (stok 0 DEĞİL, yetersiz).
    stok = float(r["ToplamStok"] or 0)
    ham = kapak + emniyet - stok
    if net_acik:                            # kullanıcı direktifinin TERSİ — yalnız kıyas için
        ham -= float(r["AcikSiparis"] or 0)
    oneri = max(int(math.ceil(ham)), 0)
    tavan_kat = ESIK_KAT.get(kat, 3)
    sezon = int(r["SezonSatis"] or 0)
    # Tavan da eldeki stoğu sayar: elde 3× sezon varsa zaten aşırı, sipariş 0.
    tavan = max(tavan_kat * sezon - stok, 0) if sezon > 0 else None
    kirpildi = False
    if tavan is not None and oneri > tavan:
        oneri, kirpildi = int(tavan), True
    plan_adet = int(math.ceil(hiz * PLAN_HAFTA * 7))
    return dict(
        Oneri=oneri,
        HizTabani=hiz_tabani,
        Kapak=int(math.ceil(kapak + emniyet)),
        Aciliyet=("ACİL — rafta yok" if stok <= 0 else "ikmal — kapak altı"),
        Yatirim=round(oneri * float(r["Maliyet"] or 0), 2),
        PlanAdet=plan_adet,
        PlanTL=round(plan_adet * float(r["Fiyat"] or 0), 2),
        Desen=talep_deseni(int(r["SatanAy"] or 0), float(r["CV2"] or 0)),
        Kirpildi=kirpildi,
        TavanKat=tavan_kat,
    )


def cikis_eylemi(r: dict, h: dict) -> str:
    if r["OdakStok"] and int(r["OdakStok"]) > 0:
        return (f"Hafta {PLAN_HAFTA}'de hedefin altındaysa: ODAK'ta stok var → yeni sipariş "
                f"DURDUR, kalanı satan mağazaya transfer et")
    if h["Desen"] in ("sıçramalı", "aralıklı"):
        return (f"Hafta {PLAN_HAFTA}'de hedefin altındaysa: parti küçült (yarısı), "
                f"tedarikçiden iade talebi (iade oranı >%2 ise), sonra kademeli indirim")
    return (f"Hafta {PLAN_HAFTA}'de hedefin altındaysa: satan mağazaya transfer → "
            f"kademeli indirim (%15 → %30) → paket/kampanya")


def not_metni(r: dict, h: dict) -> str:
    n = []
    if h["Kirpildi"]:
        n.append(f"tavan kırptı ({h['TavanKat']}× sezon satışı)")
    if not float(r["Maliyet"] or 0):
        n.append("birim maliyet YOK → yatırım eksik")
    if int(r["AcikSiparis"] or 0) > 0:
        n.append(f"120 günde {int(r['AcikSiparis'])} adet açık sipariş var "
                 f"(direktif: eldeki stok SAYILMADI)")
    if int(r["OdakStok"] or 0) > 0:
        n.append(f"ODAK'ta {int(r['OdakStok'])} adet — hızlı temin")
    n.append("talep ALT SINIR (raf boşken satış kesilmiş)")
    return " · ".join(n)


def yaz(ws, satirlar: list[dict], hedef_metni: str, kesim: dt.date) -> None:
    kalin = Font(bold=True, color="FFFFFF")
    dolgu = PatternFill("solid", fgColor="1F3864")
    ws.append(BASLIKLAR)
    for c in range(1, len(BASLIKLAR) + 1):
        h = ws.cell(row=1, column=c)
        h.font, h.fill = kalin, dolgu
        h.alignment = Alignment(wrap_text=True, vertical="center")
    ws.freeze_panes = "D2"
    hedef_tarih = (kesim + dt.timedelta(days=PLAN_HAFTA * 7)).strftime("%d.%m.%Y")
    for r in satirlar:
        h = r["_h"]
        ws.append([
            r["stkID"], r["Barkod"], r["Urun"], r["Kategori3"], r["Marka"],
            r["Satis365"], r["SezonSatis"], r["SatanAy"], float(r["CV2"]), h["Desen"],
            r["TeminGun"], r["Tedarikci"],
            ("EVET" if int(r["TedarikciID"] or 0) in ILISKILI_TARAF else ""), h["HizTabani"], r["ToplamStok"], r["MagazaStok"], r["MerkezStok"],
            r["OdakStok"], r["AcikSiparis"], r["AcikBelge"], h["Aciliyet"], h["Kapak"],
            float(r["Fiyat"]), float(r["Maliyet"]), h["Oneri"], h["Yatirim"],
            h["PlanAdet"], h["PlanTL"], hedef_metni, hedef_tarih,
            cikis_eylemi(r, h), not_metni(r, h),
        ])
    genislik = [9, 15, 46, 12, 18, 10, 10, 8, 7, 11, 9, 34, 11, 15, 10, 8, 8, 9, 13, 9, 17, 11,
                11, 13, 11, 12, 12, 13, 16, 11, 62, 58]
    for i, w in enumerate(genislik, start=1):
        ws.column_dimensions[get_column_letter(i)].width = w
    for row in ws.iter_rows(min_row=2, min_col=23, max_col=28):
        for c in row:
            c.number_format = "#,##0.00"


def ozet_yaz(ws, a: list[dict], b: list[dict], net_acik: bool, kesim: dt.date,
             maliyetsiz: int, netleme_farki: int) -> None:
    kalin = Font(bold=True)
    ws.column_dimensions["A"].width = 52
    ws.column_dimensions["B"].width = 26
    ws.column_dimensions["C"].width = 96

    def sat(k, v="", n=""):
        ws.append([k, v, n])

    def bas(t):
        ws.append([])
        ws.append([t])
        ws.cell(row=ws.max_row, column=1).font = kalin

    sat("SİPARİŞ ÖNERİSİ — KİTAPDIŞI", kesim.strftime("%d.%m.%Y"),
        "Kohort paneldeki ölçütle aynı: 365g satış ≥5 · toplam stok 0 · defter güvenilir")
    for ad, liste in (("A-SÜREKLİ (bugün yazılır)", a), ("B-SEZON/SEYREK (gelecek sezon)", b)):
        bas(ad)
        sat("çeşit", len(liste))
        sat("önerilen adet", sum(x["_h"]["Oneri"] for x in liste))
        sat("yatırım (birim maliyetle) ₺", round(sum(x["_h"]["Yatirim"] for x in liste), 2))
        sat(f"plan {PLAN_HAFTA} hafta — adet", sum(x["_h"]["PlanAdet"] for x in liste))
        sat(f"plan {PLAN_HAFTA} hafta — ciro ₺", round(sum(x["_h"]["PlanTL"] for x in liste), 2))
        sat("tavan kırptığı satır", sum(1 for x in liste if x["_h"]["Kirpildi"]),
            "kategori eşiği × sezon satışı aşılamaz (Kırtasiye 2× · diğer 3×)")

    bas("HAVUZ KIRILIMI — kohort neden genişledi")
    sat("ACİL (rafta hiç yok)", sum(1 for x in a + b if int(x["ToplamStok"] or 0) <= 0),
        "eski ölçüt YALNIZ bunları alıyordu")
    sat("İKMAL (stok var ama kapak altı)", sum(1 for x in a + b if int(x["ToplamStok"] or 0) > 0),
        "Kırtasiye'de ölçüldü: eski liste 796 çeşit, kapak altı gerçek ihtiyaç 1.687 çeşit / "
        "14.528 adet — yani listenin gördüğü ~1/13'tü. Perakende siparişinin gövdesi burası.")

    bas("AÇIK SİPARİŞ (yolda mal) — KULLANICI DİREKTİFİ")
    sat("açık sipariş eldeki stok sayıldı mı?", "HAYIR" if not net_acik else "EVET (kıyas modu)",
        'Direktif 10.09.2026: "yeni gelen sezon siparişlerini var olarak görme". '
        "Açık sipariş kolonda GÖSTERİLİR, öneriden DÜŞÜLMEZ.")
    sat("açık siparişi olan çeşit", sum(1 for x in a + b if int(x["AcikSiparis"] or 0) > 0))
    sat("açık sipariş toplam adet", sum(int(x["AcikSiparis"] or 0) for x in a + b))
    sat("netlenirse öneri şu kadar DÜŞER (adet)", netleme_farki,
        "Kıyas: --net-acik-siparis ile aynı script bu farkı uygular.")

    bas("YÖNTEM")
    sat("hız", "max(365g düz, sezon penceresi)",
        "SEZON ÜRÜNÜNDE düz hız talebi 4 KAT az sayıyordu (ölçüldü: Kırtasiye sezon-yoğun "
        "285 çeşit, 50 günlük pencere 7.257 vs 29.057 adet). Sezon penceresi = geçen yılın "
        "AYNI takvim aralığındaki satış (Ağu/Eyl/Eki aylıklarından orantılı). Zirve EYLÜL.")
    sat("kapak", f"hız × (temin + {GOZDEN_GECIRME_GUN} gün)", "aylık sipariş turu varsayıldı")
    sat("emniyet", "z × √(CV² / SatanAy) × kapak",
        "kapağın %100'ünü aşamaz. İlk sürüm z·√CV² idi ve sıçramalı üründe stok şişiriyordu "
        "(248 adet öneri vs 114 adetlik 12-hafta planı) — aralıklı talepte cevap daha sık sipariş.")
    sat("z (hizmet düzeyi)", "Kırtasiye/Elektronik 1,65 · Oyuncak/Hediyelik 1,04",
        "tek global hizmet düzeyi yok: ölçülen kategori devri 1,25 ile 5,95 arası")
    sat("tavan", "kategori eşiği × sezon satışı", "Kırtasiye 2× · diğer kitapdışı 3× (ölçümle türetildi)")
    sat("A / B ayrımı", "SatanAy ≥ 6", "10.09'da sezon (Tem–Eki) 2/3 geçmiş; sezon-ağırlıklı "
        "ürüne bugün sipariş sezon kuyruğuna yetişir")
    sat("taahhüt", f"{int(HEDEF_SELLTHROUGH*100)}% / {PLAN_HAFTA} hafta",
        "sipariş ANINDA yazılır — sonradan konan eşik geriye dönük yargıdır")

    bas("ÖLÇÜLMEDİ / SINIR")
    for m in (
        "Talep tahminleri ALT SINIR — sağdan sansürlü (stok bitince satış kesilir), EM düzeltmesi yok.",
        "Croston/SBA/TSB beklenen değeri YOK; 365g hızı vekil (TODO B-171(a)).",
        "MOQ / koli katı veride yok → adetler yuvarlanmadı, tedarikçiyle teyit gerek.",
        "Tedarikçi iade hakkı veride izli değil (urn.alimIadeYok tek değer) → kesin alım varsayıldı.",
        f"Birim maliyeti 0/NULL olan çeşit: {maliyetsiz} → yatırım tutarı bu kadar eksik.",
        "Açık sipariş 'son 120 günde açılmış' demektir; teslim edilen kısım düşülmüş DEĞİL.",
        "Alıcı boyutu veride yok — liste ürün bazlı, kişiye atıf yapılmıyor.",
        "Merkez stok WMS anlık + hayalet stok riski; 'merkezde var' kararı defterle karşılaştırılır.",
    ):
        sat(m)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kesim", default=None, help="YYYY-MM-DD (varsayılan: tabandaki son kesim)")
    ap.add_argument("--sezon", type=int, default=2025)
    ap.add_argument("--net-acik-siparis", action="store_true",
                    help="açık siparişi eldeki stok gibi DÜŞ (direktifin tersi, kıyas için)")
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        cur = cn.cursor()
        if a.kesim:
            kesim = dt.date.fromisoformat(a.kesim)
        else:
            cur.execute("SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)")
            r = cur.fetchone()
            if not r or r[0] is None:
                kosamadi("tabanda kesim YOK — panel tabanı doldurulmamış")
            kesim = r[0] if isinstance(r[0], dt.date) else dt.date.fromisoformat(str(r[0])[:10])

        # Sezon oranı: 1 Ağustos → kesim penceresi, bu yıl vs geçen yıl (aynı takvim).
        by_bas = dt.date(kesim.year, 8, 1)
        gy_bas, gy_son = dt.date(kesim.year - 1, 8, 1), dt.date(kesim.year - 1, kesim.month, kesim.day)
        cur.execute(SQL_SEZON_ORAN, by_bas, kesim, gy_bas, gy_son, by_bas, kesim)
        oranlar = {}
        for kat, oran, buyil in cur.fetchall():
            if oran is None or int(buyil or 0) < SEZON_ORAN_TABAN:
                continue               # ölçülemeyen oran 1,0 sayılır (uydurma yok)
            oranlar[kat] = float(oran)

        cur.execute(SQL, kesim, a.sezon, kesim, kesim)  # t(kesim,sezon) · sup_raw(kesim) · acik(kesim)
        kolonlar = [c[0] for c in cur.description]
        # ŞEMA DENETİMİ: kolon adı/sayısı sessizce kayarsa satırlar yanlış hücreye gider.
        if kolonlar != BEKLENEN_KOLONLAR:
            kosamadi("SELECT kolonlari beklenenden farkli:\n  beklenen: %s\n  gelen   : %s"
                     % (BEKLENEN_KOLONLAR, kolonlar))
        ham = [dict(zip(kolonlar, row)) for row in cur.fetchall()]
    finally:
        cn.close()

    # SATIR TABANI: boş sonuç "sipariş adayı yok" değil, çoğu zaman süzgeç/kesim hatasıdır.
    if len(ham) < 50:
        kosamadi(f"yalnizca {len(ham)} satir dondu (taban 50) — kesim/sezon/kategori suzgecini "
                 f"kontrol et. Bos sonuc 'aday yok' KANITI DEGIL.")

    for r in ham:
        r["_h"] = hesapla(r, a.net_acik_siparis, kesim, oranlar)
    # Öneri 0 çıkan satır (tavan kırptı ya da elde yeterli) listeye GİRMEZ.
    onerili = [r for r in ham if r["_h"]["Oneri"] > 0]
    liste_a = [r for r in onerili if int(r["SatanAy"] or 0) >= 6]
    liste_b = [r for r in onerili if int(r["SatanAy"] or 0) < 6]

    # Netleme farkı ÖLÇÜLÜR (iddia edilmez): aynı hesap açık sipariş düşülerek yeniden koşar.
    netsiz = sum(r["_h"]["Oneri"] for r in ham)
    netli = sum(hesapla(dict(r), True, kesim, oranlar)["Oneri"] for r in ham)
    netleme_farki = netsiz - netli
    maliyetsiz = sum(1 for r in ham if not float(r["Maliyet"] or 0))

    print("  sezon orani (bu yil / gecen yil, ayni takvim penceresi): " +
          " · ".join("%s %.2f" % (k, v) for k, v in sorted(oranlar.items())))
    wb = Workbook()
    hedef = f"%{int(HEDEF_SELLTHROUGH * 100)} / {PLAN_HAFTA} hafta"
    ws = wb.active
    ws.title = "A-SUREKLI (bugun)"
    yaz(ws, liste_a, hedef, kesim)
    yaz(wb.create_sheet("B-SEZON (gelecek sezon)"), liste_b, "%60 / sezon sonu", kesim)
    ozet_yaz(wb.create_sheet("OZET + YONTEM"), liste_a, liste_b, a.net_acik_siparis, kesim,
             maliyetsiz, netleme_farki)

    # ── TEDARİKÇİ ÖZETİ — sipariş fişi buradan çıkar (kime ne kadar yazılacak) ──
    ws3 = wb.create_sheet("TEDARIKCI OZET")
    ws3.append(["Tedarikçi", "İlişkili taraf", "Liste", "Çeşit", "Sipariş adedi",
                "Yatırım ₺", f"Plan {PLAN_HAFTA} hafta ₺", "ACİL çeşit", "ACİL adet",
                "Ort. temin gün"])
    for c in range(1, 11):
        h = ws3.cell(row=1, column=c)
        h.font, h.fill = Font(bold=True, color="FFFFFF"), PatternFill("solid", fgColor="1F3864")
        h.alignment = Alignment(wrap_text=True, vertical="center")
    grup: dict = {}
    for ad, liste in (("A-SÜREKLİ", liste_a), ("B-SEZON", liste_b)):
        for r in liste:
            k = (r["Tedarikci"], ad)
            g = grup.setdefault(k, dict(id=int(r["TedarikciID"] or 0), cesit=0, adet=0, yat=0.0,
                                        plan=0.0, acil_c=0, acil_a=0, temin=[]))
            g["cesit"] += 1
            g["adet"] += r["_h"]["Oneri"]
            g["yat"] += r["_h"]["Yatirim"]
            g["plan"] += r["_h"]["PlanTL"]
            g["temin"].append(int(r["TeminGun"] or 7))
            if int(r["ToplamStok"] or 0) <= 0:
                g["acil_c"] += 1
                g["acil_a"] += r["_h"]["Oneri"]
    for (ted, ad), g in sorted(grup.items(), key=lambda x: -x[1]["yat"]):
        ws3.append([ted, "EVET" if g["id"] in ILISKILI_TARAF else "", ad, g["cesit"], g["adet"],
                    round(g["yat"], 2), round(g["plan"], 2), g["acil_c"], g["acil_a"],
                    round(sum(g["temin"]) / len(g["temin"]), 1)])
    for i, w in enumerate([42, 12, 12, 8, 13, 14, 16, 10, 10, 12], start=1):
        ws3.column_dimensions[get_column_letter(i)].width = w
    for row in ws3.iter_rows(min_row=2, min_col=6, max_col=7):
        for c in row:
            c.number_format = "#,##0.00"
    ws3.freeze_panes = "A2"

    cikti = a.cikti or os.path.join(
        KOK, "raporlar", f"siparis-onerisi-kitapdisi-{kesim:%Y%m%d}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)

    print(f"Kesim {kesim:%d.%m.%Y} · aday {len(ham)} cesit")
    print(f"  A-SUREKLI     : {len(liste_a):>5} cesit · "
          f"{sum(r['_h']['Oneri'] for r in liste_a):>6} adet · "
          f"{sum(r['_h']['Yatirim'] for r in liste_a):>12,.0f} TL yatirim · "
          f"plan {sum(r['_h']['PlanTL'] for r in liste_a):,.0f} TL")
    print(f"  B-SEZON/SEYREK: {len(liste_b):>5} cesit · "
          f"{sum(r['_h']['Oneri'] for r in liste_b):>6} adet · "
          f"{sum(r['_h']['Yatirim'] for r in liste_b):>12,.0f} TL yatirim")
    print(f"  acik siparis netlenirse oneri {netleme_farki} adet DUSER (uygulanmadi: direktif)")
    print(f"  birim maliyeti olmayan cesit : {maliyetsiz}")
    print(f"Yazildi: {cikti}")


if __name__ == "__main__":
    main()
