# -*- coding: utf-8 -*-
"""SEZON STOĞU — İKİ LİSTE, TEK HESAP ÇEKİRDEĞİ → Excel.

GMY 14.09.2026: _"gerçekten stok olup mağazada olan sezon ürünlerinin listesini almak
istiyorum"_ → _"yıl boyu ortalama büyüme ile değerleyerek sezon büyümesini de dikkate al"_
→ _"rapor hiç anlaşılır değil"_ → _"stoğu merkez dahil sezona yetmeyecekleri de raporlamak
gerek"_ → **_"yanıltıcı bir şey istemiyorum"_**.

═══ İKİ SORU, İKİ MOD ═════════════════════════════════════════════════════════
(A) varsayılan   — "Mağaza rafımda, bu sezon beklediğimden FAZLA mal duruyor mu?"
(B) --yetmeyen   — "Merkez dahil elimdeki, sezon sonuna kalan talebi KARŞILAMIYOR mu?"

Zıt eylem isterler: (A) indirim/iade/transfer · (B) sipariş/transfer. Bu yüzden ayrı
dosyaya yazılır, ama hesap TEK yerdedir (`emitter-ayrimi.md`).

═══ BÜYÜME — ÖNCE ÜRÜN, YOKSA KATEGORİ (14.09.2026 düzeltmesi) ════════════════
Kategori büyürken ürün küçülüyorsa kategori büyümesi o ürünü GİZLER. Bu yüzden
büyüme önce ÜRÜN bazlı ölçülür; yalnız geçen yıl aynı pencerede **≥ 20 adet** satmış
üründe güvenilir sayılır.

⚠ ÖLÇÜLDÜ (kesim 13.09.2026, kalan talebi olan 65.898 çeşit): ürün bazlı büyüme
yalnız **4.740 çeşitte** (%7,2) güvenilir. Eşik 5 adede indirilse 15.214 (%23,1).
Yani kalan %92,8 için kategori büyümesi kullanılmak ZORUNDA — her satırda hangisinin
kullanıldığı **"Büyüme kaynağı"** kolonunda yazılıdır.

Ürün oranı [0,2 – 5,0] dışındaysa aykırı sayılıp kategoriye düşülür (tek adetlik
dalgalanma 20 katlık talep uydurmasın). Bu bir SEÇİMDİR, ölçüm değil — böyle yazıldı.

Her iki büyüme de okul açılışına **HİZALI** ölçülür (her iki yıl `T−44 .. T−1`).
⚠⚠ HİZASIZ ÖLÇÜM YÖNÜ TERS ÇEVİRİYOR (ölçüldü 14.09.2026):
    Hazırlık Kitapları: hizasız 0,727 ("%27 küçüldü") · HİZALI 1,104 ("%10 büyüdü")
`olctum-mu-cikardim-mi.md` § 2b — iki yılın metriği aynı tanımla kurulmazsa kıyas değil.

═══ (A)'NIN KAPSAMI DARALDI — sezon malı olmayan listeden ÇIKTI ═══════════════
Sezon katı = sezon günlük ort. ÷ sezon dışı günlük ort. (son 365 gün; Ağu-Eki = 92
gün, kalan 273 gün). Hediyelik 0,85 · Oyuncak 0,78 → bunlar sezonda DAHA AZ satıyor.
"Sezon fazlası" diye listelemek alıcıyı yanlış eyleme iter: onların fazlası varsa bu
bir SEZON sorunu değil, yıl boyu aşırı stok sorunudur (panelin Aşırı Stok kartı).

⇒ (A) modunda sezon katı ÖLÇÜLMÜŞ ve ≤ 1,0 olan satırlar listeden ÇIKARILIR.
   Ölçülemeyen (365 günde satışı olmayan) ÇIKARILMAZ — ölçmediğimizi atmayız,
   "ölçülemedi" diye yazarız.

═══ (B)'NİN KAPSAMI GENİŞLEDİ — rafı boşalmış ürün artık içeride ══════════════
Eski sürüm her iki modda `MagazaStok > 0` şartı koyuyordu. (B) için bu YANLIŞTI:
rafı tamamen boşalmış ürün açığın EN KÖTÜ hâlidir ve sessizce düşüyordu.
⚠ ÖLÇÜLDÜ: 5.672 çeşit / 40.927 adet / **16,0M ₺** açık bu yüzden görünmüyordu
(görünen 116,1M ₺'nin yanında %12 eksik sayım).

═══ AÇIK SİPARİŞ NETLENMEZ — "açık" alanı ÖLÜ (ölçüldü 14.09.2026) ════════════
`sip.eDurum = 2` (kapalı) **24.02.2025'ten beri hiç yazılmamış**. Sonuç: eDurum'a
göre "açık" görünen alış siparişlerinin adet olarak **%86,4'ü bir yıldan eski**
(37.065 belge / 19.920.271 adet). Son 30 gün yalnız %0,74 (226 belge / 171.014 adet).

⇒ Açık sipariş (B)'den DÜŞÜLMEZ. Yalnız **son 30 günde sipariş edilen adet** bir
  BAYRAK kolonu olarak gösterilir (ODAK temin ort. 5,03 gün + pay). Netlemek raporu
  20 milyon hayalet adetle yalanlardı.
  GMY direktifi de aynı yönde: _"yeni gelen sezon siparişlerini var olarak görme"_.
⚠ Bu adet "sipariş edildi"dir, "yolda" değil: `sipAyr.ehSevkAdet` alış siparişi
  satırlarının %100'ünde NULL → karşılanma ölçülemiyor (B-180).

═══ MERKEZ STOĞU WMS'TEN — hayalet şüphesi kolonu ═════════════════════════════
Taban merkez stoğunu WMS'ten okur (`depo.stok_adres_palet_vw`, raf+giriş alanı) —
ERP defteri negatifli olduğu için kural budur. Ama kural ÇİFT YÖNLÜDÜR: satış ERP'de
kesilip WMS'ten düşülmediyse WMS ŞİŞİK kalır. Defterle karşılaştırılır; WMS > 0 iken
defter ≤ 0 ise satır **"HAYALET ŞÜPHELİ"** işaretlenir.
⚠ ÖLÇÜLDÜ: (B) evreninde merkez stoğu olan 8.810 çeşidin **84'ü** şüpheli (2.369
adet) — küçük ama sıfır değil. Şüpheliyse açık GERÇEKTE DAHA BÜYÜK olabilir.

═══ ÜÇ ŞART (ortak) ══════════════════════════════════════════════════════════
1. Geçen sezon (Ağu–Eki) FİİLEN satmış → `SezonToplam > 0`
   ⚠ "Sezonluk ürün" değil, "sezonda satmış ürün".
2. Defter güvenilir → negatif raf/merkez stoğu ve fiyatı 0 olan kayıtlar DIŞARIDA.
3. Para yalnız maliyeti geçerli olanlarda (TMS 2: `0 < maliyet ≤ satış fiyatı`) →
   ₺ toplamı ALT SINIRDIR.

⚠ pyodbc (pymssql DEĞİL): Türkçe varchar CP1254, pymssql bozar.

Kullanım:
    python scripts/sezon_magaza_stok_excel.py [--yetmeyen]
        [--kesim 2026-09-13] [--sezon 2025] [--min-kat 1.0]
        [--acilis-bu 2026-09-14] [--acilis-gecen 2025-09-08] [--sezon-sonu 2026-10-31]
Çıkış: 0 dosya yazıldı · 2 KOŞAMADI (bağlantı/şema/boş sonuç — sessizlik kanıt değil).
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

# Ürün bazlı büyümenin güvenilir sayılması için geçen yıl aynı pencerede gereken adet.
URUN_BUYUME_TABAN = 20
# Aykırı koruması — SEÇİM, ölçüm değil. Dışındaki oran kategoriye düşer.
URUN_BUYUME_ALT, URUN_BUYUME_UST = 0.2, 5.0
# Açık sipariş bayrağı penceresi (gün). ODAK temin ort. 5,03 gün + pay.
SIPARIS_PENCERE = 30


def kosamadi(mesaj: str) -> None:
    """Ölçüm YAPILAMADI → çıkış 2. Boş sonuç ile hiç koşmamak ekranda aynı görünür."""
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


# Kategori yolu — panelin C# karşılığıyla AYNI kural (boş basamak atlanır).
YOL = ("STUFF(ISNULL(N' > ' + NULLIF(t.Kategori1, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat1, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat2, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat3, N''), N'')"
       " + ISNULL(N' > ' + NULLIF(t.Kat4, N''), N''), 1, 3, N'')")

MALIYET_GECERLI = "(t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat)"

# ⚠ 8632 KORUMASI: beklenen/kalan talep ifadeleri SELECT+WHERE+ORDER BY'da onlarca kez
# geçiyor. İç içe yazılırsa "deyim hizmetleri sınırı" aşılır (panelde iki kez yaşandı).
# Her biri CROSS APPLY ile SATIR BAŞINA BİR KEZ hesaplanır, sonraki adım takma adı OKUR.
SQL = f"""
WITH sz AS (
    -- SEZON KATI — ürün sezona ne kadar bağımlı (son 365 gün).
    -- ⚠ Tabandaki SatisToplam - SezonToplam ile HESAPLANAMAZ: pencereler kısmen örtüşüyor.
    SELECT h.ehstkID AS stkID,
           SUM(CASE WHEN MONTH(h.ehTrhS) IN (8,9,10) THEN -h.ehAdetN ELSE 0 END) / 92.0  AS SezGun,
           SUM(CASE WHEN MONTH(h.ehTrhS) NOT IN (8,9,10) THEN -h.ehAdetN ELSE 0 END) / 273.0 AS DisiGun
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS > DATEADD(DAY,-365,?) AND h.ehTrhS <= ?
    GROUP BY h.ehstkID
),
kl AS (
    -- KALAN SEZON TALEBİ: geçen yılın, okul açılışından itibaren AYNI GÜN SAYISI
    -- boyunca satışı. Bugün T+0 ise sezon sonuna kaç gün varsa geçen yıl da o kadar.
    SELECT h.ehstkID AS stkID, SUM(-h.ehAdetN) AS KalanGY
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS <= ?
    GROUP BY h.ehstkID
),
ub AS (
    -- ÜRÜN BAZLI büyüme, okul açılışına hizalı (her iki yıl T−44..T−1).
    SELECT h.ehstkID AS stkID,
           SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,?) AND h.ehTrhS < ?
                    THEN -h.ehAdetN ELSE 0 END) AS Y2,
           SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,?) AND h.ehTrhS < ?
                    THEN -h.ehAdetN ELSE 0 END) AS Y1
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= DATEADD(DAY,-44,?) AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
b AS (
    SELECT u.Kategori3,
           SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-364,?) AND h.ehTrhS <= ?
                    THEN -h.ehAdetN ELSE 0 END) AS Yil2,
           SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-728,?) AND h.ehTrhS < DATEADD(DAY,-364,?)
                    THEN -h.ehAdetN ELSE 0 END) AS Yil1,
           SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,?) AND h.ehTrhS < ?
                    THEN -h.ehAdetN ELSE 0 END) AS Sez2,
           SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,?) AND h.ehTrhS < ?
                    THEN -h.ehAdetN ELSE 0 END) AS Sez1
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK) ON u.stkID = h.ehstkID
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= DATEADD(DAY,-728,?) AND h.ehTrhS <= ?
    GROUP BY u.Kategori3
),
k AS (
    SELECT Kategori3,
           CONVERT(float, Yil2) / NULLIF(Yil1, 0) AS YilBuyume,
           CONVERT(float, Sez2) / NULLIF(Sez1, 0) AS SezonBuyume
    FROM b
),
sp AS (
    -- SON N GÜNDE SİPARİŞ EDİLEN (bayrak — DÜŞÜLMEZ). Yalnız satın alma: 0 Alış · 3 Yerel Alım.
    -- ⚠ eDurum'a güvenilmez: kapalı (2) 24.02.2025'ten beri hiç yazılmamış.
    SELECT sa.ehstkID AS stkID, SUM(sa.ehAdet) AS SipAdet
    FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
    WHERE s.eTip IN (0,3) AND s.eTarih >= ? AND s.eTarih <= ?
    GROUP BY sa.ehstkID
),
dft AS (
    -- ERP MERKEZ DEFTERİ — yalnız WMS'i ÇAPRAZ DENETLEMEK için (stok kaynağı DEĞİL).
    SELECT d.ehstkID AS stkID, SUM(d.stok) AS DefterMerkez
    FROM DerinSISBkm.dbo.stokSonAltDepo_vw d WITH (NOLOCK)
    WHERE d.ehMekan = 12
    GROUP BY d.ehstkID
)
SELECT t.Kategori3                                      AS [Kategori],
       {YOL}                                            AS [Kategori yolu],
       t.stkAd                                          AS [Ürün],
       t.BarkodAna                                      AS [Barkod],
       t.stkID                                          AS [stkID],
       t.Yayinevi                                       AS [Yayınevi/Marka],
       CONVERT(decimal(18,2), t.SatisFiyat)             AS [Satış fiyatı],
       t.SezonToplam                                    AS [Geçen sezon sattı],
       CONVERT(decimal(6,3), bx.Buyume)                 AS [Büyüme],
       bx.Kaynak                                        AS [Büyüme kaynağı],
       CONVERT(int, ROUND(cx.Beklenen, 0))              AS [Bu sezon beklenen],
       t.MagazaStok                                     AS [Mağazada duran],
       CONVERT(int, ROUND(t.MagazaStok - cx.Beklenen, 0)) AS [FAZLA adet],
       CONVERT(decimal(18,2), CASE WHEN {MALIYET_GECERLI} AND t.MagazaStok > cx.Beklenen
            THEN (t.MagazaStok - cx.Beklenen) * t.BirimMaliyet END) AS [FAZLA ₺ (maliyet)],
       CONVERT(decimal(10,2), t.MagazaStok / NULLIF(cx.Beklenen, 0)) AS [Kaç katı],
       CONVERT(decimal(8,2), sk.SezonKat)               AS [Sezon katı],
       CASE WHEN sk.SezonKat IS NULL THEN N'ölçülemedi'
            WHEN sk.SezonKat > 1 THEN N'evet' ELSE N'HAYIR' END AS [Sezon malı mı],
       DATEDIFF(DAY, t.SonSatis, ?)                     AS [Son satıştan bu yana gün],
       t.MerkezStok                                     AS [Merkezde bekleyen],
       CASE WHEN t.MerkezStok > 0 AND ISNULL(dft.DefterMerkez, 0) <= 0
            THEN N'HAYALET ŞÜPHELİ' ELSE N'' END        AS [Merkez şüpheli],
       t.StokFsm                                        AS [FSM],
       t.StokOzl                                        AS [Özlüce],
       t.StokIst                                        AS [İst.Yolu],
       cx.KalanTalep                                    AS [Sezon sonuna kalan talep],
       cx.Elde                                          AS [Elde (mağaza+merkez)],
       CONVERT(int, cx.KalanTalep - cx.Elde)            AS [AÇIK adet],
       CONVERT(decimal(18,2), CASE WHEN cx.KalanTalep > cx.Elde
            THEN (cx.KalanTalep - cx.Elde) * t.SatisFiyat END) AS [AÇIK ₺ (kaçacak ciro)],
       CONVERT(int, ISNULL(sp.SipAdet, 0))              AS [Son 30g sipariş edildi],
       CONVERT(decimal(6,3), k.YilBuyume)               AS [Yıl boyu büyüme (kontrol)],
       CONVERT(decimal(18,2), CASE WHEN {MALIYET_GECERLI}
            THEN t.BirimMaliyet END)                    AS [Birim maliyet]
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN k   ON k.Kategori3 = t.Kategori3
LEFT JOIN sz  ON sz.stkID = t.stkID
LEFT JOIN kl  ON kl.stkID = t.stkID
LEFT JOIN ub  ON ub.stkID = t.stkID
LEFT JOIN sp  ON sp.stkID = t.stkID
LEFT JOIN dft ON dft.stkID = t.stkID
-- Büyüme TEK yerde seçilir: ürün güvenilirse ürün, değilse kategori. Kaynağı yazılır.
CROSS APPLY (SELECT UrunOran = CASE WHEN ISNULL(ub.Y1, 0) >= {URUN_BUYUME_TABAN}
                                    THEN CONVERT(float, ub.Y2) / ub.Y1 END) bo
CROSS APPLY (SELECT
        Buyume = CASE WHEN bo.UrunOran BETWEEN {URUN_BUYUME_ALT} AND {URUN_BUYUME_UST}
                      THEN bo.UrunOran ELSE ISNULL(k.SezonBuyume, 1.0) END,
        Kaynak = CASE WHEN bo.UrunOran BETWEEN {URUN_BUYUME_ALT} AND {URUN_BUYUME_UST}
                      THEN N'ürün (n>={URUN_BUYUME_TABAN})'
                      WHEN k.SezonBuyume IS NOT NULL THEN N'kategori'
                      ELSE N'yok (1,000 alındı)' END) bx
CROSS APPLY (SELECT Beklenen   = t.SezonToplam * bx.Buyume,
                    KalanTalep = CONVERT(int, CEILING(ISNULL(kl.KalanGY, 0) * bx.Buyume)),
                    Elde       = t.MagazaStok + t.MerkezStok,
                    SezKat     = sz.SezGun / NULLIF(sz.DisiGun, 0)) cx0
CROSS APPLY (SELECT Beklenen = cx0.Beklenen, KalanTalep = cx0.KalanTalep,
                    Elde = cx0.Elde) cx
CROSS APPLY (SELECT SezonKat = cx0.SezKat) sk
WHERE t.Kesim = ? AND t.SezonYil = ?
  AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
  -- (A) rafta mal olacak. (B)'de ŞART DEĞİL: rafı boşalmış ürün açığın en kötü hâli
  --     ve eski sürümde 5.672 çeşit / 16,0M ₺ bu yüzden sessizce düşüyordu.
  AND (? = 0 OR t.MagazaStok > 0)
  -- (A) sezon malı olmayanı LİSTELEME (ölçülmüş ve <= 1,0 olan). Ölçülemeyen kalır.
  AND (? = 0 OR sk.SezonKat IS NULL OR sk.SezonKat > 1.0)
  AND (? = 0 OR t.MagazaStok / NULLIF(cx.Beklenen, 0) >= ?)
  -- (B) MERKEZ DAHİL elindeki, sezon sonuna kalan talebi karşılamıyor.
  AND (? = 0 OR (ISNULL(kl.KalanGY, 0) > 0 AND cx.Elde < cx.KalanTalep))
ORDER BY CASE WHEN ? = 1
         THEN CASE WHEN cx.KalanTalep > cx.Elde
                   THEN (cx.KalanTalep - cx.Elde) * t.SatisFiyat ELSE 0 END
         ELSE CASE WHEN {MALIYET_GECERLI} AND t.MagazaStok > cx.Beklenen
                   THEN (t.MagazaStok - cx.Beklenen) * t.BirimMaliyet ELSE 0 END END DESC
"""

PARA = {"FAZLA ₺ (maliyet)", "AÇIK ₺ (kaçacak ciro)", "Satış fiyatı", "Birim maliyet"}
ORAN = {"Kaç katı", "Büyüme", "Yıl boyu büyüme (kontrol)", "Sezon katı"}

ORTAK = ["Kategori", "Kategori yolu", "Ürün", "Barkod", "stkID", "Yayınevi/Marka",
         "Satış fiyatı", "Geçen sezon sattı", "Büyüme", "Büyüme kaynağı"]
A_KOLON = ORTAK + ["Bu sezon beklenen", "Mağazada duran", "FAZLA adet", "FAZLA ₺ (maliyet)",
                   "Kaç katı", "Sezon katı", "Sezon malı mı", "Son satıştan bu yana gün",
                   "Merkezde bekleyen", "FSM", "Özlüce", "İst.Yolu", "Birim maliyet"]
B_KOLON = ORTAK + ["Sezon sonuna kalan talep", "Mağazada duran", "Merkezde bekleyen",
                   "Merkez şüpheli", "Elde (mağaza+merkez)", "AÇIK adet",
                   "AÇIK ₺ (kaçacak ciro)", "Son 30g sipariş edildi", "Sezon katı",
                   "FSM", "Özlüce", "İst.Yolu"]


def urun_sayfasi(wb: Workbook, bas: list[str], sat: list, not_metni: str) -> None:
    ws = wb.create_sheet("ÜRÜNLER")
    ws.cell(1, 1, not_metni).font = Font(italic=True, size=9, color="555555")
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(bas))
    ws.cell(1, 1).alignment = Alignment(wrap_text=True, vertical="center")
    ws.row_dimensions[1].height = 28

    for j, b in enumerate(bas, start=1):
        h = ws.cell(2, j, b)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    ws.row_dimensions[2].height = 34

    for i, r in enumerate(sat, start=3):
        for j, (v, ad) in enumerate(zip(r, bas), start=1):
            c = ws.cell(i, j, v)
            if ad in PARA:
                c.number_format = '#,##0 "₺"'
            elif ad in ORAN:
                c.number_format = "0.00"
            elif isinstance(v, int):
                c.number_format = "#,##0"

    genis = {"Ürün": 40, "Kategori yolu": 38, "Yayınevi/Marka": 18, "Barkod": 15,
             "Büyüme kaynağı": 16, "Merkez şüpheli": 17}
    for j, b in enumerate(bas, start=1):
        ws.column_dimensions[get_column_letter(j)].width = genis.get(b, max(len(b) + 2, 11))
    ws.freeze_panes = "D3"
    if sat:
        ws.auto_filter.ref = f"A2:{get_column_letter(len(bas))}{len(sat) + 2}"


def ayir(n: float, para: bool = False) -> str:
    s = f"{n:,.0f}".replace(",", ".")
    return f"{s} ₺" if para else s


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yetmeyen", action="store_true",
                    help="(B) merkez dahil elindeki sezon sonuna kalan talebi karsilamayanlar")
    ap.add_argument("--kesim", default=None)
    ap.add_argument("--sezon", type=int, default=2025)
    # OKUL AÇILIŞI — arşivden (sorgular/2026-09-08-okul-hizali-ciro-tahmini.sql):
    # 2024-25 → 09.09.2024 · 2025-26 → 08.09.2025 · 2026-27 → 14.09.2026.
    # Satır verisi olduğu için sema'ya YAZILMAZ; parametreyle dışarıdan verilir.
    ap.add_argument("--acilis-bu", default="2026-09-14")
    ap.add_argument("--acilis-gecen", default="2025-09-08")
    ap.add_argument("--sezon-sonu", default="2026-10-31")
    ap.add_argument("--min-kat", type=float, default=0.0,
                    help="(A) magazadaki stok / beklenen satis alt siniri (0 = suzme yok)")
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()

    try:
        acilis_bu = dt.date.fromisoformat(a.acilis_bu)
        acilis_gecen = dt.date.fromisoformat(a.acilis_gecen)
        sezon_sonu = dt.date.fromisoformat(a.sezon_sonu)
    except ValueError as e:
        kosamadi(f"Gecersiz tarih: {e}")
    kalan_gun = (sezon_sonu - acilis_bu).days
    if kalan_gun <= 0:
        kosamadi(f"Sezon sonu ({sezon_sonu}) acilis gununden ({acilis_bu}) sonra olmali")
    # Geçen yılın AYNI UZUNLUKTAKİ penceresi — kaymayı düzeltir.
    kl_bas, kl_son = acilis_gecen, acilis_gecen + dt.timedelta(days=kalan_gun)

    mod_a = 0 if a.yetmeyen else 1
    mod_b = 1 if a.yetmeyen else 0

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
        sip_bas = kesim - dt.timedelta(days=SIPARIS_PENCERE)

        # pyodbc KONUM bazlı — sıra SQL'deki ? sırasıdır; biri değişirse ikisi birden değişir.
        cur.execute(
            SQL,
            kesim, kesim,                               # sz
            kl_bas, kl_son,                             # kl
            acilis_bu, acilis_bu,                       # ub.Y2
            acilis_gecen, acilis_gecen,                 # ub.Y1
            acilis_gecen, acilis_bu,                    # ub WHERE
            kesim, kesim,                               # b.Yil2
            kesim, kesim,                               # b.Yil1
            acilis_bu, acilis_bu,                       # b.Sez2
            acilis_gecen, acilis_gecen,                 # b.Sez1
            kesim, kesim,                               # b WHERE
            sip_bas, kesim,                             # sp
            kesim,                                      # SELECT son satış
            kesim, a.sezon,                             # WHERE Kesim / SezonYil
            mod_a,                                      # MagazaStok > 0 (yalnız A)
            mod_a,                                      # sezon katı kapısı (yalnız A)
            a.min_kat, a.min_kat,                       # min-kat
            mod_b,                                      # yetmeyen kapısı
            mod_b,                                      # ORDER BY
        )
        tum_bas = [d[0] for d in cur.description]
        tum_sat = [list(x) for x in cur.fetchall()]
    finally:
        cn.close()

    if not tum_sat:
        kosamadi(f"Liste BOS dondu (kesim {kesim}, sezon {a.sezon}, "
                 f"mod {'B' if a.yetmeyen else 'A'}) — kesim tabanda var mi?")

    ix = {b: i for i, b in enumerate(tum_bas)}
    for ad in set(A_KOLON) | set(B_KOLON):
        if ad not in ix:
            kosamadi(f"Kolon '{ad}' sorgudan gelmedi — kolon listesi ile SQL ayrismis")

    # ── Özet rakamları HAM satırdan (kolon süzmesi yalnız sunum) ──────────────
    cesit = len(tum_sat)
    magaza_adet = sum(int(r[ix["Mağazada duran"]] or 0) for r in tum_sat)
    merkez_adet = sum(int(r[ix["Merkezde bekleyen"]] or 0) for r in tum_sat)
    fazla_adet = sum(max(int(r[ix["FAZLA adet"]] or 0), 0) for r in tum_sat)
    fazla_tl = sum(float(r[ix["FAZLA ₺ (maliyet)"]] or 0) for r in tum_sat)
    acik_adet = sum(max(int(r[ix["AÇIK adet"]] or 0), 0) for r in tum_sat)
    acik_tl = sum(float(r[ix["AÇIK ₺ (kaçacak ciro)"]] or 0) for r in tum_sat)
    kalan_talep = sum(int(r[ix["Sezon sonuna kalan talep"]] or 0) for r in tum_sat)
    malsiz = sum(1 for r in tum_sat
                 if r[ix["FAZLA ₺ (maliyet)"]] is None and (r[ix["FAZLA adet"]] or 0) > 0)
    urun_buyume = sum(1 for r in tum_sat if str(r[ix["Büyüme kaynağı"]] or "").startswith("ürün"))
    hayalet = sum(1 for r in tum_sat if r[ix["Merkez şüpheli"]])
    hayalet_adet = sum(int(r[ix["Merkezde bekleyen"]] or 0) for r in tum_sat
                       if r[ix["Merkez şüpheli"]])
    siparisli = sum(1 for r in tum_sat if (r[ix["Son 30g sipariş edildi"]] or 0) > 0)
    olculemedi = sum(1 for r in tum_sat if r[ix["Sezon malı mı"]] == "ölçülemedi")

    kolonlar = B_KOLON if a.yetmeyen else A_KOLON
    bas = list(kolonlar)
    sat = [[r[ix[c]] for c in kolonlar] for r in tum_sat]

    # ── Kategori özeti ────────────────────────────────────────────────────────
    ozet: dict[str, list] = {}
    for r in tum_sat:
        k = ozet.setdefault(r[ix["Kategori"]] or "(boş)", [0, 0, 0, 0.0])
        k[0] += 1
        if a.yetmeyen:
            k[1] += int(r[ix["Sezon sonuna kalan talep"]] or 0)
            k[2] += max(int(r[ix["AÇIK adet"]] or 0), 0)
            k[3] += float(r[ix["AÇIK ₺ (kaçacak ciro)"]] or 0)
        else:
            k[1] += int(r[ix["Mağazada duran"]] or 0)
            k[2] += max(int(r[ix["FAZLA adet"]] or 0), 0)
            k[3] += float(r[ix["FAZLA ₺ (maliyet)"]] or 0)
    ozet_sat = sorted(([k] + v for k, v in ozet.items()), key=lambda x: -x[4])

    wb = Workbook()
    ws = wb.active
    ws.title = "ÖZET"

    baslik = ("SEZONA YETMEYECEKLER — merkez dahil elde < kalan talep" if a.yetmeyen
              else "MAĞAZADA DURAN FAZLA SEZON MALI")
    ws.cell(1, 1, baslik).font = Font(bold=True, size=15)
    ws.cell(2, 1, f"kesim {kesim:%d.%m.%Y} · sezon {a.sezon} · okul açılışı "
                  f"{acilis_bu:%d.%m.%Y} (geçen yıl {acilis_gecen:%d.%m.%Y}) · "
                  f"sezon sonuna {kalan_gun} gün · kaynak: satış analizi tabanı"
            ).font = Font(italic=True, size=9, color="555555")

    if a.yetmeyen:
        kutu = [("Ürün çeşidi", ayir(cesit)),
                ("Sezon sonuna kalan talep", ayir(kalan_talep)),
                ("Elde (mağaza + merkez)", ayir(magaza_adet + merkez_adet)),
                ("AÇIK adet", ayir(acik_adet)),
                ("AÇIK ₺ (etiket fiyatıyla)", ayir(acik_tl, True))]
    else:
        kutu = [("Ürün çeşidi", ayir(cesit)),
                ("Mağazada duran adet", ayir(magaza_adet)),
                ("Beklenenden FAZLA adet", ayir(fazla_adet)),
                ("Fazlanın maliyeti", ayir(fazla_tl, True)),
                ("Merkezde ayrıca bekleyen", ayir(merkez_adet))]
    for i, (k, v) in enumerate(kutu, start=4):
        ws.cell(i, 1, k).font = Font(bold=True, size=11)
        c = ws.cell(i, 2, v)
        c.font = Font(bold=True, size=12)
        c.alignment = Alignment(horizontal="right")
        c.fill = ACIK

    r0 = 4 + len(kutu) + 1
    ws.cell(r0, 1, "KATEGORİYE GÖRE").font = Font(bold=True, size=12)
    kb = (["Kategori", "Çeşit", "Kalan talep", "AÇIK adet", "AÇIK ₺"] if a.yetmeyen
          else ["Kategori", "Çeşit", "Mağazada duran", "FAZLA adet", "FAZLA ₺"])
    for j, b in enumerate(kb, start=1):
        h = ws.cell(r0 + 1, j, b)
        h.font = Font(bold=True, color="FFFFFF")
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, horizontal="center")
    for i, r in enumerate(ozet_sat, start=r0 + 2):
        for j, v in enumerate(r, start=1):
            c = ws.cell(i, j, v)
            if j in (2, 3, 4):
                c.number_format = "#,##0"
            elif j == 5:
                c.number_format = '#,##0 "₺"'

    # ── NASIL OKUNUR + ölçülmüş sınırlar ──────────────────────────────────────
    r1 = r0 + len(ozet_sat) + 4
    ws.cell(r1, 1, "NASIL OKUNUR").font = Font(bold=True, size=12)

    urun_pay = urun_buyume * 100 // max(cesit, 1)
    notlar: list[tuple[str, str]] = [
        ("Büyüme", f"Önce ÜRÜN bazlı (geçen yıl aynı pencerede en az {URUN_BUYUME_TABAN} adet "
                   f"satmışsa), yoksa kategori. Bu listede {ayir(urun_buyume)} satırda ürün "
                   f"bazlı kullanıldı (%{urun_pay}). Hangisinin kullanıldığı 'Büyüme kaynağı' "
                   f"kolonunda yazılı. Kategori büyürken ürün küçülüyorsa kategori büyümesi o "
                   f"ürünü gizler — bu yüzden ürün önce gelir."),
        ("Neden hizalı", "Okul açılışı kayıyor (2025: 8 Eylül · 2026: 14 Eylül). Takvim "
                         "günleriyle ölçünce Hazırlık Kitapları 0,73 çıkıyordu (%27 küçülme); "
                         "hizalayınca 1,10 (%10 büyüme). Aynı veri, zıt sonuç."),
        ("Sezon katı", "Sezon günlük ortalaması ÷ sezon dışı günlük ortalaması. 1,00'ın altı, "
                       "ürünün sezonda DAHA AZ sattığı anlamına gelir."),
    ]

    if a.yetmeyen:
        notlar += [
            ("Kalan talep", f"Geçen yılın okul açılışından itibaren {kalan_gun} günlük satışı × "
                            "büyüme. Bu yıl sezon sonuna kalan gün sayısı kadar."),
            ("AÇIK adet", "Kalan talep − (mağaza + merkez). Merkez DAHİL, çünkü soru "
                          "'satışı kaçırır mıyım', 'rafta var mı' değil."),
            ("Rafı boş olan da var", "Mağaza stoğu sıfır olan ürünler bu listeye DAHİL — açığın "
                                     "en kötü hâli odur. (Önceki sürümde sessizce düşüyorlardı.)"),
            ("⚠ Rakam ALT SINIR", "Geçen yılın satışı talebin vekilidir ve raf boşken satış "
                                  "kesilmiştir (sağdan sansürlü). Gerçek talep daha yüksek "
                                  "olabilir; kabul görmüş düzeltme (sansürlü talep tahmini) "
                                  "UYGULANMADI."),
            ("⚠ Kampanya/fiyat taşınmaz", "Geçen yılın penceresinde uygulanan kampanya, fiyat ve "
                                          "raf yerleşimi bu yıl aynı değil. Talep vekilinin en "
                                          "zayıf yanı budur ve ÖLÇÜLMEDİ."),
            ("⚠ AÇIK ₺ etiket fiyatı", "Kaçacak CİRO'dur, kâr değil. İkame de hesaba katılmadı — "
                                       "müşteri benzerini alırsa ciro kaçmaz."),
            ("⚠ Sipariş DÜŞÜLMEDİ", "'Son 30g sipariş edildi' bir BAYRAKTIR, açıktan "
                                    "çıkarılmaz. Sebep ölçüldü: ERP'de 'kapalı' durumu "
                                    "(eDurum=2) 24.02.2025'ten beri hiç yazılmamış; açık "
                                    "görünen alış siparişi adedinin %86,4'ü bir yıldan eski, "
                                    "son 30 gün yalnız %0,74. Netleme yapılsa rapor hayalet "
                                    f"siparişle yanıltırdı. Bu listede {ayir(siparisli)} üründe "
                                    "son 30 günde sipariş var."),
            ("⚠ Sipariş ≠ yolda", "Gösterilen adet 'sipariş edildi'dir. Karşılanma ölçülemiyor: "
                                  "alış siparişi satırlarının %100'ünde sevk adedi boş."),
        ]
    else:
        notlar += [
            ("FAZLA adet", "Mağazadaki stok − beklenen satış. Eksiyse fazla yok."),
            ("Kaç katı", "Mağazadaki stok ÷ beklenen satış. 1,00 = tam beklenen kadar."),
            ("Kapsam daraldı", "Sezon katı ÖLÇÜLMÜŞ ve 1,00'ın altında olan ürünler bu listeden "
                               "ÇIKARILDI. Onların fazlası bir sezon sorunu değil, yıl boyu "
                               "aşırı stok sorunudur (panelin Aşırı Stok kartı). Örnek: "
                               "Hediyelik 0,85 · Oyuncak 0,78 — sezonda daha AZ satıyorlar."),
            ("Ölçülemeyen kaldı", f"Son 365 günde satışı olmadığı için sezon katı ölçülemeyen "
                                  f"{ayir(olculemedi)} ürün listede BIRAKILDI — ölçmediğimizi "
                                  f"atmayız, 'ölçülemedi' diye yazarız."),
            ("Merkezde bekleyen", "0 ise besleme yok, elde kalan bu kadar."),
        ]

    notlar += [
        ("⚠ Merkez stoğu WMS", f"Merkez stoğu WMS'ten okunur (ERP defteri negatifli, güvenilmez). "
                               f"Yine de defterle karşılaştırıldı: {hayalet} üründe WMS pozitif "
                               f"ama defter sıfır/eksi ({ayir(hayalet_adet)} adet) → 'HAYALET "
                               f"ŞÜPHELİ'. Mal fiilen olmayabilir; fiziksel sayım yapılmadan "
                               f"karara dayanak alınmaz."),
        ("⚠ Para alt sınır", f"{malsiz} üründe maliyet kaydı yok ya da şüpheli (maliyet > satış "
                             "fiyatı). Adetleri gerçek, ₺ toplamına girmiyor."),
        ("⚠ Tek gün", "Kesim fotoğrafı. Mağaza stoğu gün içinde değişir."),
        ("⚠ Sezon ürünü", "\"Geçen sezon satmış ürün\" demek — \"sezonluk ürün\" değil. "
                          "O ayrımı veri taşımıyor."),
        ("⚠ Alıcı yok", "Veride satınalmacı boyutu YOK. Bu liste bir kişiye atıf DEĞİLDİR."),
    ]

    for i, (k, v) in enumerate(notlar, start=r1 + 1):
        ws.cell(i, 1, k).font = Font(bold=True, size=10)
        ws.cell(i, 2, v).alignment = Alignment(wrap_text=True, vertical="top")
    ws.column_dimensions["A"].width = 24
    ws.column_dimensions["B"].width = 96
    for j in range(3, 7):
        ws.column_dimensions[get_column_letter(j)].width = 17

    urun_sayfasi(wb, bas, sat,
                 ("Açığı en büyük (etiket ₺) ürünler önce. AÇIK = kalan talep − (mağaza + "
                  "merkez). 'Son 30g sipariş edildi' bayraktır, açıktan DÜŞÜLMEMİŞTİR."
                  if a.yetmeyen else
                  "Beklenenden fazla mal duran ürünler önce. Beklenen = geçen sezon satışı × "
                  "büyüme (önce ürün bazlı, yoksa kategori; okul açılışına hizalı). "
                  "Boş FAZLA ₺ = maliyet kaydı yok/şüpheli."))

    mod = "yetmeyen" if a.yetmeyen else "fazla"
    ek = f"-kat{a.min_kat:g}" if (a.min_kat and not a.yetmeyen) else ""
    cikti = a.cikti or os.path.join(
        KOK, "raporlar", f"sezon-{mod}-magaza-stok-{kesim:%Y%m%d}{ek}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)

    print(f"YAZILDI: {cikti}")
    print(f"  cesit {ayir(cesit)} · magaza {ayir(magaza_adet)} adet · "
          f"merkez {ayir(merkez_adet)} adet")
    if a.yetmeyen:
        print(f"  ACIK {ayir(acik_adet)} adet · {ayir(acik_tl)} TL (etiket) · "
              f"siparis bayragi {ayir(siparisli)} urun")
    else:
        print(f"  FAZLA {ayir(fazla_adet)} adet · {ayir(fazla_tl)} TL (maliyet) · "
              f"sezon kati olculemeyen {ayir(olculemedi)}")
    print(f"  urun bazli buyume {ayir(urun_buyume)} satir · "
          f"hayalet supheli {ayir(hayalet)} ({ayir(hayalet_adet)} adet) · "
          f"maliyeti yok/supheli {malsiz}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
