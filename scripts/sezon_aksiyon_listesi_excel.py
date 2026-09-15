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
SARI = PatternFill("solid", fgColor="FFF2CC")   # FORMÜL hücresi — göz ayırsın


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
-- ⚠ TÜRETİLEN KOLONLAR SQL'DE HESAPLANMAZ — Excel'de FORMÜL olarak kurulur
--   (GMY: "formüllü olsun ne nerden geliyor gözüksün"). Buradan yalnız HAM girdiler gelir.
WITH gh AS (   -- GEÇEN yılın penceresi — BU yılınkinin ay/gün AYNASI
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
bh AS (        -- BU yılın penceresi — gün sayısı gh ile BİREBİR aynı (aynalama garantisi)
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
),
yl AS (        -- YILLIK: sezon yılı 01.08.<sezon> – 31.07.<sezon+1> (365 gün)
    -- GMY kararı 15.09.2026: "01/08/2025-31/07/2026 arası olsun 365 gün".
    -- ⚠ Eski "365 günde satılan" [kesim−364, kesim] idi ve geçen sezonun başını
    --   KAÇIRIYORDU. Bu pencere geçen sezonu (Ağu–Eki) TAM İÇERİR ve bu sezona TAŞMAZ.
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= ? AND h.ehTrhS < ?
    GROUP BY h.ehstkID
)
SELECT t.stkAd                                       AS [Ürün],
       t.Kategori3                                   AS [Kategori],
       {YOL}                                         AS [Kategori yolu],
       -- ⚠ stkKod BARKOD DEĞİLDİR (sql-server-conventions) — ikisi ayrı alan.
       --   Tabanda yalnız BarkodAna var; stkKod ürün master'ından okunur.
       -- ⚠ Taban kolonu 'Yayinevi' ama kaynağı UrunBilgi.mrkAd = MARKA.
       t.Yayinevi                                    AS [Marka / Yayınevi],
       u.stkKod                                      AS [Stok kodu],
       t.BarkodAna                                   AS [Barkod],
       CONVERT(int, ISNULL(gh.Adet, 0))              AS [Geçen sezon aynı dönem],
       CONVERT(int, ISNULL(bh.Adet, 0))              AS [Bu sezon aynı dönem],
       -- SEZON AYLARI AYRI (GMY 15.09.2026: "sezon 8 9 10 ayrı olsun").
       -- Taban Ay1/Ay2/Ay3 = geçen sezonun Ağu/Eyl/Eki'si; toplamları SezonToplam.
       t.Ay1                                         AS [Ağustos],
       t.Ay2                                         AS [Eylül],
       t.Ay3                                         AS [Ekim],
       CONVERT(int, ISNULL(yl.Adet, 0))              AS [Yıllık satış],
       t.StokFsm                                     AS [FSM],
       t.StokOzl                                  AS [Özlüce],
       t.StokIst                                     AS [İst.Yolu],
       t.MerkezStok                                  AS [Depo],
       -- ⚠ 4 HANE: 2 haneye yuvarlayıp sonra çarpınca toplam 313 ₺ sapıyordu
       --   (ölçüldü 15.09.2026). Excel'de GÖRÜNEN sayı, çarpılan sayı olmalı.
       CONVERT(decimal(18,4), t.SatisFiyat)          AS [Satış fiyatı],
       CONVERT(decimal(18,4), CASE WHEN {MALIYET_GECERLI}
            THEN t.BirimMaliyet END)                 AS [Birim maliyet]
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID
LEFT JOIN gh ON gh.stkID = t.stkID
LEFT JOIN bh ON bh.stkID = t.stkID
LEFT JOIN yl ON yl.stkID = t.stkID
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

# ── SAYFA DÜZENİ ──────────────────────────────────────────────────────────────
# Türetilen her kolon FORMÜLDÜR; ham girdiler SQL'den gelir. Büyüme TEK HÜCREDE
# (B2) — değiştirilince tüm liste yeniden hesaplanır.
#   (ad, tip)  tip: "ham" = SQL kolonu · "f" = Excel formülü
DUZEN: list[tuple[str, str]] = [
    ("Ürün",                   "ham"),
    ("Kategori",               "ham"),
    ("Kategori yolu",          "ham"),
    ("Marka / Yayınevi",       "ham"),
    ("Stok kodu",              "ham"),
    ("Barkod",                 "ham"),
    ("Geçen sezon aynı dönem", "ham"),   # okula hizalı N gün, GEÇEN yıl
    ("Bu sezon aynı dönem",    "ham"),   # AYNI N gün, BU yıl
    ("Değişim",                "f"),     # =Bu/Geçen  (aynı pencere → kıyaslanabilir)
    ("Ağustos",                "ham"),   # geçen sezon
    ("Eylül",                  "ham"),
    ("Ekim",                   "ham"),
    ("Geçen sezon TAMAMI",     "f"),     # =Ağustos+Eylül+Ekim (toplandığı GÖRÜNSÜN)
    ("Yıllık satış",           "ham"),   # 01.08.<sezon> – 31.07.<sezon+1>, 365 gün   # Ağu–Eki — "Satılacak"ın tabanı
    ("Satılacak",              "f"),     # =CEILING(Geçen sezon TAMAMI × (1+büyüme); 1)
    ("FSM",                    "ham"),
    ("Özlüce",                 "ham"),
    ("İst.Yolu",               "ham"),
    ("Mağaza toplam",          "f"),     # =FSM+Özlüce+İst.Yolu
    ("Depo",                   "ham"),
    ("Toplam stok",            "f"),     # =Mağaza toplam+Depo
    ("AÇIK",                   "f"),     # =MAX(0; Satılacak−Toplam stok)
    ("FAZLA",                  "f"),     # =MAX(0; Toplam stok−Satılacak)
    ("Satış fiyatı",           "ham"),
    ("Birim maliyet",          "ham"),
    ("Tutar",                  "f"),
    ("Durum",                  "f"),   # pivot bu alanla AÇIK/FAZLA sayabiliyor
    # ── PİVOT YARDIMCILARI — LİSTE'de GİZLİ. Tek "Tutar" kolonuyla pivot, Durum'u
    #    kolon alanı yapmak zorunda kalıyordu ve 17 kolona yayılıp okunmaz oluyordu.
    #    Ayrı iki kolonla pivot düz ve okunur; LİSTE ise tek Tutar ile sade kalıyor.
    ("AÇIK ₺",                 "f"),
    ("FAZLA ₺",                "f"),
]


PARA = {"Satış fiyatı", "Birim maliyet"}


def ayir(n: float, para: bool = False) -> str:
    s = f"{n:,.0f}".replace(",", ".")
    return f"{s} ₺" if para else s


def pivot_kur(yol: str, kolon_sayisi: int, son_satir: int) -> str:
    """
    MARKA sayfasını GERÇEK PivotTable'a çevirir (Excel COM).

    GMY 15.09.2026: "marka sayfasını pivot tablo kullanarak veriden oluşturabilir miyiz".

    ⚠ NEDEN COM: openpyxl pivot tabloyu OKUR/KOPYALAR ama SIFIRDAN KURAMAZ (ölçüldü —
      openpyxl 3.1.2'de pivot.table modülü var, kurma API'si yok). xlsxwriter'da da yok.
      Excel COM 16.0 bu makinede mevcut (ölçüldü), o yüzden gerçek pivot kurulabiliyor.

    ⚠ PIVOT'UN KAZANCI: LİSTE'deki B2 büyümesi değiştirilip dosya kaydedilince pivot
      YENİDEN HESAPLANIR (RefreshOnFileOpen + sağ tık > Yenile). Önceki "değer" sayfası
      bayatlıyordu; canlı uyarı koymak zorunda kalmıştık. Pivot o sorunu KÖKTEN çözer.

    ⚠ SESSİZ BAŞARISIZLIK YASAK: Excel yoksa/meşgulse pivot KURULMAZ ve bu DÖNÜŞ
      DEĞERİNDE SÖYLENİR; dosya yine geçerli (değer tabanlı MARKA sayfası durur).
    """
    try:
        import win32com.client as win32
        import pythoncom
    except ImportError:
        return "KURULMADI — pywin32 yok (deger tabanli MARKA sayfasi duruyor)"

    son_kolon = get_column_letter(kolon_sayisi)
    pythoncom.CoInitialize()
    xl = None
    try:
        xl = win32.gencache.EnsureDispatch("Excel.Application")
        xl.Visible = False
        xl.DisplayAlerts = False
        wb = xl.Workbooks.Open(os.path.abspath(yol))
        try:
            liste = wb.Worksheets("LİSTE")
            # Eski DEĞER tabanlı MARKA sayfası gider; yerine pivot gelir.
            for ws in list(wb.Worksheets):
                if ws.Name == "MARKA":
                    ws.Delete()
            pws = wb.Worksheets.Add(After=liste)
            pws.Name = "MARKA"

            kaynak = f"LİSTE!$A$3:${son_kolon}${son_satir}"     # 3. satır = başlık
            cache = wb.PivotCaches().Create(SourceType=1, SourceData=kaynak)  # xlDatabase
            pt = cache.CreatePivotTable(TableDestination=pws.Range("A3"),
                                        TableName="MarkaPivot")
            pt.PivotFields("Marka / Yayınevi").Orientation = 1      # xlRowField
            # ⚠ Durum KOLON ALANI YAPILMADI: 4 değer × 3 durum = 17 kolona yayılıp
            #   okunmaz oluyordu (ölçüldü). Ayrı "AÇIK ₺"/"FAZLA ₺" alanlarıyla düz kalıyor.
            # ⚠ VERİ ALANI ADI, KAYNAK ALAN ADIYLA AYNI OLAMAZ — Excel 0x800A03EC verir
            #   (ölçüldü 15.09.2026: "AÇIK ₺" data field'ı aynı adlı sütunla çakıştı).
            #   Bu yüzden başlıklar "… toplam" ile ayrıldı.
            # ⚠ BİÇİM DİZGİSİ YEREL AYIRAÇLA OKUNUYOR: Türkçe Excel'de "#,##0" yazınca
            #   "," DECIMAL sayılıyor ve 21688 → "21688,0" görünüyordu (ölçüldü).
            #   Ayıraçları Excel'in kendisine sorup dizgiyi ona göre kuruyoruz.
            # ⚠ Application.International ERKEN BAĞLAMADA DEMET döner, çağrılabilir DEĞİL
            #   (ölçüldü: xl.International(4) → TypeError 'tuple' object is not callable).
            #   Hem demet hem çağrı biçimi denenir; ikisi de olmazsa Türkçe varsayılana düşer
            #   ve bu SESSİZ DEĞİL — biçim yine de okunur çıkar.
            def ayirac(sira: int, varsayilan: str) -> str:
                try:
                    return str(xl.International[sira - 1])
                except Exception:
                    try:
                        return str(xl.International(sira))
                    except Exception:
                        return varsayilan

            bicim_hata: list[str] = []
            binlik = ayirac(4, ".")            # xlThousandsSeparator
            tamsayi = f"#{binlik}##0"
            para = f'#{binlik}##0 "₺"'
            cf = pt.AddDataField(pt.PivotFields("Ürün"), "Çeşit", -4112)   # xlCount
            for alan, ad, bicim in (("AÇIK", "AÇIK adet", tamsayi),
                                    ("AÇIK ₺", "AÇIK toplam ₺", para),
                                    ("FAZLA", "FAZLA adet", tamsayi),
                                    ("FAZLA ₺", "FAZLA toplam ₺", para)):
                f = pt.AddDataField(pt.PivotFields(alan), ad, -4157)  # xlSum
                # ⚠ BİÇİM İSTEĞE BAĞLI: yerel biçim dizgisi reddedilebiliyor (0x800A03EC).
                #   Pivot'un KENDİSİ biçimden önemli — biçim tutmazsa pivot yine kurulur,
                #   sayı ham görünür. Sessiz değil: aşağıda bicim_hata sayılıp döndürülür.
                try:
                    f.NumberFormat = bicim
                except Exception:
                    bicim_hata.append(ad)
            try:
                cf.NumberFormat = tamsayi
            except Exception:
                bicim_hata.append("Çeşit")
            pt.RowAxisLayout(1)                                       # tablo düzeni
            # AÇIK tutarına göre büyükten küçüğe — alıcı en büyük açıktan başlasın.
            try:
                pt.PivotFields("Marka / Yayınevi").AutoSort(2, "AÇIK toplam ₺")  # xlDescending
            except Exception:
                pass   # sıralama kurulamazsa pivot yine geçerli; alfabetik kalır
            # Kaydedilince yeniden hesapla — büyüme değişirse pivot bayatlamasın.
            pt.PivotCache().RefreshOnFileOpen = True

            pws.Range("A1").Value = (
                "MARKA PİVOTU — kaynak LİSTE sayfası. LİSTE'de B2 büyümesini değiştirip "
                "kaydettikten sonra pivota sağ tık > Yenile (dosya yeniden açılınca "
                "kendiliğinden yenilenir). ⚠ ₺ sütunu AÇIK'ta satış fiyatı, FAZLA'da "
                "maliyettir — İKİSİ TOPLANMAZ, o yüzden Durum kırılımı ayrık duruyor.")
            pws.Range("A1").Font.Italic = True
            pws.Columns("A").ColumnWidth = 34
            wb.Save()
            ek = (f" · biçim uygulanamadı: {", ".join(bicim_hata)}"
                  if bicim_hata else "")
            return f"KURULDU — MarkaPivot ({kaynak}){ek}"
        finally:
            wb.Close(SaveChanges=False)
    except Exception as ex:                       # noqa: BLE001 — sebebi DÖNÜŞTE yazılıyor
        # ⚠ SESSİZ HATA YASAK: yalnız tipi değil, HANGİ SATIRDA patladığı da söylenir.
        #   Tek satırlık "KURULAMADI" mesajı teşhis ettirmiyordu (üç tur kaybedildi).
        import traceback
        iz = traceback.extract_tb(ex.__traceback__)
        yer = f"{iz[-1].lineno}: {iz[-1].line}" if iz else "?"
        return (f"KURULAMADI ({type(ex).__name__}: {ex}) @ satir {yer} "
                "— deger tabanli MARKA sayfasi duruyor")
    finally:
        if xl is not None:
            try:
                xl.Quit()
            except Exception:
                pass
        pythoncom.CoUninitialize()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kesim", default=None)
    ap.add_argument("--sezon", type=int, default=2025)
    ap.add_argument("--buyume", type=float, default=0.20,
                    help="sezon buyumesi (0.20 = %%20)")
    ap.add_argument("--durum", choices=["acik", "fazla"], default=None,
                    help="yalniz acik ya da yalniz fazla listele")
    # PENCERE — GMY kararı 15.09.2026: "okul açılışına takılma, rapor 01/08'den başlasın,
    # sezon 8 9 10 olsun". Sen BU yılın penceresini verirsin; GEÇEN yılınki aynı ay/güne
    # OTOMATİK aynalanır → iki pencere her zaman EŞİT uzunlukta, bozulamaz.
    # ⚠ BEYAN: bu TAKVİM hizalamasıdır, okul hizalaması DEĞİL. Okul açılışı kayıyor
    #   (08.09.2025 → 14.09.2026) ve ölçüldüğünde bazı kategorilerde YÖNÜ çeviriyor
    #   (Hazırlık Kitapları takvimle 0,727 · okula hizalı 1,104). Karar bilerek takvim yönünde.
    ap.add_argument("--pencere-bas", default=None,
                    help="bu yilin pencere basi (vars. 01.08.<kesim yili>)")
    ap.add_argument("--pencere-son", default=None,
                    help="bu yilin pencere sonu, DAHIL (vars. kesim; sezon sonu 31.10'u asmaz)")
    ap.add_argument("--pivot", action=argparse.BooleanOptionalAction, default=True,
                    help="MARKA sayfasini GERCEK PivotTable yap (Excel COM gerekir)")
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()

    yalniz_acik = 1 if a.durum == "acik" else 0
    yalniz_fazla = 1 if a.durum == "fazla" else 0
    SEZON_BAS_AY, SEZON_SON_AY = 8, 10          # GMY: "sezon 8 9 10 olsun"

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

        # ── PENCERE: bu yıl seçilir, geçen yıl AYNALANIR ────────────────────
        try:
            b_bas = (dt.date.fromisoformat(a.pencere_bas) if a.pencere_bas
                     else dt.date(kesim.year, SEZON_BAS_AY, 1))
            b_son = dt.date.fromisoformat(a.pencere_son) if a.pencere_son else kesim
        except ValueError as ex:
            kosamadi(f"Gecersiz pencere tarihi: {ex}")
        # Sezon sonunu (31 Ekim) aşma.
        sezon_sonu = dt.date(b_son.year, SEZON_SON_AY, 31)
        if b_son > sezon_sonu:
            b_son = sezon_sonu
        if b_son < b_bas:
            kosamadi(f"Pencere sonu ({b_son}) basindan ({b_bas}) once olamaz")

        def aynala(d: dt.date, yil: int) -> dt.date:
            """Ay/günü başka yıla taşı. 29 Şubat gibi olmayan güne düşerse bir gün geri al."""
            try:
                return d.replace(year=yil)
            except ValueError:
                return d.replace(year=yil, day=d.day - 1)

        # YILLIK pencere: sezon başından bir sonraki sezon başının bir gün öncesine.
        y_bas = dt.date(a.sezon, SEZON_BAS_AY, 1)
        y_son = dt.date(a.sezon + 1, SEZON_BAS_AY, 1) - dt.timedelta(days=1)

        yil_farki = kesim.year - a.sezon
        g_bas, g_son = aynala(b_bas, b_bas.year - yil_farki), aynala(b_son, b_son.year - yil_farki)
        # ⚠ EŞİT UZUNLUK ZORUNLU: farklı uzunlukta iki pencere SAHTE büyüme üretir ve
        #   hata vermez. Bugün ölçülen 44/45 gün sapmasının sınıfı budur.
        if (b_son - b_bas).days != (g_son - g_bas).days:
            kosamadi(f"Pencereler esit uzunlukta degil: bu {(b_son - b_bas).days + 1} gun, "
                     f"gecen {(g_son - g_bas).days + 1} gun")

        # Sıra SQL'deki ? sırasıdır; biri değişirse ikisi birden değişir.
        # ⚠ Üst sınır DIŞLAYICI (son + 1 gün, gece yarısı) — "23:59:59" yazılmaz.
        cur.execute(SQL,
                    g_bas, g_son + dt.timedelta(days=1),   # gh — GEÇEN yıl
                    b_bas, b_son + dt.timedelta(days=1),   # bh — BU yıl
                    y_bas, y_son + dt.timedelta(days=1),   # yl — YILLIK 365 gün
                    a.buyume,                              # CROSS APPLY
                    kesim, a.sezon, yalniz_acik, yalniz_fazla)
        bas = [d[0] for d in cur.description]
        sat = [list(x) for x in cur.fetchall()]
    finally:
        cn.close()

    if not sat:
        kosamadi(f"Liste BOS dondu (kesim {kesim}, sezon {a.sezon})")

    ix = {b: i for i, b in enumerate(bas)}
    for ad, tip in DUZEN:
        if tip == "ham" and ad not in ix:
            kosamadi(f"Ham kolon '{ad}' sorgudan gelmedi — DUZEN ile SQL ayrismis")

    # ══ FORMÜLLÜ TEK SAYFA ════════════════════════════════════════════════════
    # GMY 15.09.2026: "formüllü olsun ne nerden geliyor gözüksün" + "mağaza bazlı
    # stoklarda olmalı" + "katana kısmı da olmalı".
    #
    # Türetilen HİÇBİR sayı dosyaya hazır yazılmaz — hepsi hücre formülüdür ve
    # kaynak hücreye bakar. Büyüme TEK hücrede (B2): değiştirilince 85 bin satır
    # yeniden hesaplanır. "Bu rakam nereden geliyor?" sorusu hücreye tıklayarak
    # cevaplanır; bize sormaya gerek kalmaz.
    #
    # ⚠ Özet/toplam satırı YOK (GMY: "özete gerek yok"). Toplam isteyen kolonu
    #   seçer, Excel durum çubuğunda görür.
    kolonlar = [ad for ad, _ in DUZEN]
    K = {ad: get_column_letter(j) for j, (ad, _) in enumerate(DUZEN, start=1)}
    BAS_SATIR = 4                      # 1 not · 2 büyüme · 3 başlık · 4+ veri

    wb = Workbook()
    ws = wb.active
    ws.title = "LİSTE"

    ust = (f"Kesim {kesim:%d.%m.%Y} · sezon {a.sezon} (Ağu–Eki) · "
           f"AYNI PENCERE: geçen {g_bas:%d.%m.%Y}–{g_son:%d.%m.%Y} · "
           f"bu {b_bas:%d.%m.%Y}–{b_son:%d.%m.%Y} ({(b_son - b_bas).days + 1} gün, eşit) · "
           f"YILLIK satış {y_bas:%d.%m.%Y}–{y_son:%d.%m.%Y} ({(y_son - y_bas).days + 1} gün, "
           "geçen sezonu tam içerir, bu sezona taşmaz) · "
           "SARI kolonlar FORMÜLDÜR (hücreye tıkla, hesabı gör) · "
           "Tutar: AÇIK'ta satış fiyatı, FAZLA'da maliyet — ikisi toplanmaz · "
           "Açık sipariş DÜŞÜLMEDİ (ERP'de kapatma alanı 24.02.2025'ten beri yazılmıyor) · "
           "Birim maliyeti olmayan üründe Tutar boş kalır (para ALT SINIR) · "
           "depo stoğu WMS'ten · tek gün fotoğrafı · "
           "⚠ TAKVİM hizası — okul açılışı kayıyor (08.09.2025→14.09.2026), bu pencere onu görmez")
    ws.cell(1, 1, ust).font = Font(italic=True, size=9, color="555555")
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(kolonlar))
    ws.cell(1, 1).alignment = Alignment(wrap_text=True, vertical="center")
    ws.row_dimensions[1].height = 32

    # ── BÜYÜME: tek hücre, tüm sayfanın girdisi ──────────────────────────────
    ws.cell(2, 1, "Büyüme →").font = Font(bold=True, size=10)
    bh = ws.cell(2, 2, a.buyume)
    bh.number_format = "0%"
    bh.font = Font(bold=True, size=12)
    bh.fill = SARI
    ws.cell(2, 3, "bu hücreyi değiştir → Satılacak, AÇIK, FAZLA ve Tutar yeniden hesaplanır"
            ).font = Font(italic=True, size=9, color="555555")

    for j, ad in enumerate(kolonlar, start=1):
        h = ws.cell(3, j, ad)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    ws.row_dimensions[3].height = 30

    for i, r in enumerate(sat, start=BAS_SATIR):
        for j, (ad, tip) in enumerate(DUZEN, start=1):
            if tip == "ham":
                v = r[ix[ad]]
                c = ws.cell(i, j, v)
                if ad in PARA:
                    c.number_format = '#,##0.0000 "₺"'
                elif isinstance(v, int):
                    c.number_format = "#,##0"
                continue

            # ── FORMÜL — kaynağı hücreden okur, sabit gömmez ─────────────────
            f = {
                "Geçen sezon TAMAMI": (f'={K["Ağustos"]}{i}+{K["Eylül"]}{i}+{K["Ekim"]}{i}'),
                "Satılacak":     f'=CEILING({K["Geçen sezon TAMAMI"]}{i}*(1+$B$2),1)',
                # AYNI PENCERE olduğu için bu oran kıyaslanabilir. Geçen yıl 0 ise
                # bölme yapılmaz (BOŞ) — "sonsuz büyüme" uydurmak olurdu.
                "Değişim": (f'=IF({K["Geçen sezon aynı dönem"]}{i}>0,'
                            f'{K["Bu sezon aynı dönem"]}{i}/{K["Geçen sezon aynı dönem"]}{i},"")'),
                "Mağaza toplam": f'={K["FSM"]}{i}+{K["Özlüce"]}{i}+{K["İst.Yolu"]}{i}',
                "Toplam stok":   f'={K["Mağaza toplam"]}{i}+{K["Depo"]}{i}',
                "AÇIK":          f'=MAX(0,{K["Satılacak"]}{i}-{K["Toplam stok"]}{i})',
                "FAZLA":         f'=MAX(0,{K["Toplam stok"]}{i}-{K["Satılacak"]}{i})',
                # AÇIK varsa satış fiyatıyla, FAZLA varsa maliyetle. Maliyet boşsa
                # BOŞ bırakılır — 0 yazmak "fazlası bedava" demek olurdu.
                "Tutar": (f'=IF({K["AÇIK"]}{i}>0,{K["AÇIK"]}{i}*{K["Satış fiyatı"]}{i},'
                          f'IF(AND({K["FAZLA"]}{i}>0,{K["Birim maliyet"]}{i}<>""),'
                          f'{K["FAZLA"]}{i}*{K["Birim maliyet"]}{i},""))'),
                # Metin alan: PivotTable AÇIK/FAZLA ürününü bununla SAYAR (koşullu sayım yok).
                "Durum": (f'=IF({K["AÇIK"]}{i}>0,"AÇIK",IF({K["FAZLA"]}{i}>0,"FAZLA","DENGE"))'),
                "AÇIK ₺":  f'=IF({K["AÇIK"]}{i}>0,{K["Tutar"]}{i},0)',
                "FAZLA ₺": f'=IF({K["FAZLA"]}{i}>0,IF({K["Tutar"]}{i}="",0,{K["Tutar"]}{i}),0)',
            }[ad]
            c = ws.cell(i, j, f)
            c.fill = SARI
            c.number_format = ('#,##0.00 "₺"' if ad in ("Tutar", "AÇIK ₺", "FAZLA ₺")
                               else "0.00" if ad == "Değişim"
                               else "General" if ad == "Durum" else "#,##0")

    genis = {"Ürün": 45, "Yıllık satış": 13, "Durum": 10, "Kategori yolu": 40, "Kategori": 18, "Barkod": 15, "Stok kodu": 13, "Marka / Yayınevi": 22}
    for j, ad in enumerate(kolonlar, start=1):
        ws.column_dimensions[get_column_letter(j)].width = genis.get(ad, max(len(ad) + 2, 11))
    for gizli in ("AÇIK ₺", "FAZLA ₺"):
        ws.column_dimensions[K[gizli]].hidden = True

    ws.freeze_panes = f"E{BAS_SATIR}"
    ws.auto_filter.ref = f"A3:{get_column_letter(len(kolonlar))}{len(sat) + BAS_SATIR - 1}"

    # ══ MARKA ÖZETİ ═══════════════════════════════════════════════════════════
    # GMY 15.09.2026: "marka bazlı özet sayfası da yapalım formüllü excel için".
    #
    # ⚠ NEDEN FORMÜL DEĞİL, DEĞER: ölçüldü — kohortta 2.636 ayrı marka var ve liste
    #   85.274 satır. Marka başına SUMIFS/COUNTIFS (7 formül) yazılsaydı Excel her
    #   yeniden hesapta 2.636 × 7 × 85.274 ≈ 1,6 milyar hücre karşılaştırması yapardı.
    #   (Excel'de SÜRE ÖLÇÜLMEDİ — bu bir ÇIKARIM; ama risk alınmadı.)
    #
    # ⚠ DEĞER OLUNCA BAYATLAMA RİSKİ DOĞAR: LİSTE'de B2 büyümesi değişirse bu sayfa
    #   ESKİ büyümeye göre kalır ve sessizce yanlış olur. O yüzden sayfada B2'yi izleyen
    #   TEK CANLI FORMÜL var: büyüme değişirse kırmızı uyarı çıkar. Sessiz bayatlama yok.
    mws = wb.create_sheet("MARKA")

    marka: dict[str, list] = {}
    import math as _m
    for r in sat:
        ad = (r[ix["Marka / Yayınevi"]] or "(marka yok)").strip() or "(marka yok)"
        sezon_top = (r[ix["Ağustos"]] or 0) + (r[ix["Eylül"]] or 0) + (r[ix["Ekim"]] or 0)
        satilacak = _m.ceil(sezon_top * (1 + a.buyume))
        elde = ((r[ix["FSM"]] or 0) + (r[ix["Özlüce"]] or 0)
                + (r[ix["İst.Yolu"]] or 0) + (r[ix["Depo"]] or 0))
        g = marka.setdefault(ad, [0, 0, 0, 0.0, 0, 0, 0.0, 0, 0])
        g[0] += 1                                   # çeşit
        if satilacak > elde:
            g[1] += 1                               # AÇIK ürün
            g[2] += satilacak - elde                # AÇIK adet
            g[3] += (satilacak - elde) * float(r[ix["Satış fiyatı"]] or 0)
        elif elde > satilacak:
            g[4] += 1                               # FAZLA ürün
            g[5] += elde - satilacak                # FAZLA adet
            mal = r[ix["Birim maliyet"]]
            if mal is not None:
                g[6] += (elde - satilacak) * float(mal)
        g[7] += r[ix["Geçen sezon aynı dönem"]] or 0
        g[8] += r[ix["Bu sezon aynı dönem"]] or 0

    mbas = ["Marka / Yayınevi", "Çeşit", "AÇIK ürün", "AÇIK adet", "AÇIK ₺",
            "FAZLA ürün", "FAZLA adet", "FAZLA ₺",
            "Geçen sezon aynı dönem", "Bu sezon aynı dönem", "Değişim"]

    mnot = (f"Marka bazlı özet · kesim {kesim:%d.%m.%Y} · büyüme %{a.buyume * 100:g} · "
            f"{len(marka):,} marka".replace(",", ".") + " · "
            "Tutarlar LİSTE ile aynı tabandan: AÇIK satış fiyatıyla, FAZLA maliyetle — "
            "İKİSİ TOPLANMAZ. Değişim = bu dönem ÷ geçen dönem (aynı pencere).")
    mws.cell(1, 1, mnot).font = Font(italic=True, size=9, color="555555")
    mws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(mbas))
    mws.cell(1, 1).alignment = Alignment(wrap_text=True, vertical="center")
    mws.row_dimensions[1].height = 30

    # TEK CANLI FORMÜL — LİSTE!B2 değişirse bu sayfanın bayatladığını SÖYLER.
    uyari = mws.cell(2, 1, f'=IF(ROUND(LİSTE!$B$2,6)<>{round(a.buyume, 6)},'
                          f'"⚠ LİSTE sayfasında büyüme değiştirildi — bu özet '
                          f'%{a.buyume * 100:g} ile hesaplandı, YENİDEN ÜRETİN.","")')
    uyari.font = Font(bold=True, color="C00000", size=10)
    mws.merge_cells(start_row=2, start_column=1, end_row=2, end_column=len(mbas))

    for j, b in enumerate(mbas, start=1):
        h = mws.cell(3, j, b)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = LACI
        h.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    mws.row_dimensions[3].height = 30

    for i, (ad, g) in enumerate(sorted(marka.items(), key=lambda x: -x[1][3]), start=4):
        # Değişim: geçen dönem 0 ise oran YOK — sonsuz büyüme uydurulmaz.
        deg = (g[8] / g[7]) if g[7] > 0 else None
        for j, v in enumerate([ad, g[0], g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8], deg],
                              start=1):
            c = mws.cell(i, j, v)
            if j in (5, 8):
                c.number_format = '#,##0 "₺"'
            elif j == 11:
                c.number_format = "0.00"
            elif j > 1:
                c.number_format = "#,##0"

    mgenis = {"Marka / Yayınevi": 34}
    for j, b in enumerate(mbas, start=1):
        mws.column_dimensions[get_column_letter(j)].width = mgenis.get(b, max(len(b) + 2, 12))
    mws.freeze_panes = "B4"
    mws.auto_filter.ref = f"A3:{get_column_letter(len(mbas))}{len(marka) + 3}"

    # ── Konsol özeti — Excel'in hesaplayacağının AYNISI, Python'da ────────────
    #    (dosyada formül olduğu için openpyxl değer okuyamaz; kontrol burada)
    cesit = len(sat)
    acik_c = acik_a = fazla_c = fazla_a = malsiz = 0
    acik_tl = fazla_tl = 0.0
    import math
    for r in sat:
        sezon_top = (r[ix["Ağustos"]] or 0) + (r[ix["Eylül"]] or 0) + (r[ix["Ekim"]] or 0)
        satilacak = math.ceil(sezon_top * (1 + a.buyume))
        elde = ((r[ix["FSM"]] or 0) + (r[ix["Özlüce"]] or 0)
                + (r[ix["İst.Yolu"]] or 0) + (r[ix["Depo"]] or 0))
        if satilacak > elde:
            acik_c += 1
            acik_a += satilacak - elde
            acik_tl += (satilacak - elde) * float(r[ix["Satış fiyatı"]] or 0)
        elif elde > satilacak:
            fazla_c += 1
            fazla_a += elde - satilacak
            m = r[ix["Birim maliyet"]]
            if m is None:
                malsiz += 1
            else:
                fazla_tl += (elde - satilacak) * float(m)

    ek = f"-{a.durum}" if a.durum else ""
    cikti = a.cikti or os.path.join(
        KOK, "raporlar", f"sezon-aksiyon-listesi-{kesim:%Y%m%d}{ek}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)

    if a.pivot:
        pivot_durum = pivot_kur(cikti, len(kolonlar), len(sat) + BAS_SATIR - 1)
        print(f"  PIVOT: {pivot_durum}")

    print(f"YAZILDI: {cikti}")
    print(f"  cesit {ayir(cesit)}")
    print(f"  ACIK  {ayir(acik_c)} urun · {ayir(acik_a)} adet · {ayir(acik_tl)} TL")
    print(f"  FAZLA {ayir(fazla_c)} urun · {ayir(fazla_a)} adet · {ayir(fazla_tl)} TL")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
