# -*- coding: utf-8 -*-
"""MAĞAZA BAZLI GÜNLÜK CİRO (fiş sayılı, Sınav ayrımlı) → Excel.

Doğuş sebebi 12.09.2026: _"geçen yıl okul açılışı öncesi hafta sonu mağaza bazlı cumartesi
pazar cirosu lazım, bugün de İstanbul Yolu Sınav ve Sınav hariç ciro"_ → ardından
_"tek rapor tüm şubeler tüm tarihler"_ + _"iadeyi içinden düş, KDV'li olsun"_.

KAYNAK: **EncoreMerkez `dbo.Sales`** (kasa tarafı). ERP `irsHrk` DEĞİL — kanal (Sınav) ayrımı
yalnız belge tipinden yapılabiliyor ve o EncoreMerkez'de.

═══ CİRO TABANI ═══════════════════════════════════════════════════════════════
KDV DAHİL  = GrossTotal − DiscountTotal          ← bu raporun ANA sayısı (kullanıcı isteği)
KDV HARİÇ  = GrossTotal − DiscountTotal − VatTotal
⚠ Panel ve öteki raporlar CFO direktifiyle (plan-16) **KDV HARİÇ** çalışır. Bu rapor KDV
dahili öne alır; iki taban yan yana konursa rakamlar tutmaz. O yüzden İKİSİ DE yazılıyor.
İndirim yalnız `DiscountTotalDirect` değil `DiscountTotal` — header toplamı (Campaign alt küme).

Belge tipleri: 1 Fiş · 2 Fatura · 3 İade · 6 Personel Fiş · 7 Personel Fatura · 8 Sınav.
⚠⚠ **İADE DÜŞÜLMEZ** (kullanıcı direktifi 12.09.2026: _"iade hiç düşme"_). Tip 3 hiçbir ciro
toplamına girmez; tutarı yalnız `İade` sütununda BİLGİ olarak durur. Bu, projenin varsayılanının
(iade işaretli düşülür — `veri-dogrula` çek-liste md.2) DIŞIDIR. Başka bir raporla yan yana
konursa rakamlar tutmaz; ÖZET sayfasında yazılı.
Sepet ortalama = FİŞ cirosu (tip 1) ÷ FİŞ sayısı — fatura, Sınav ve iade hariç.

═══ SINAV AYRIMI = BELGE BAZLI ════════════════════════════════════════════════
`DocumentsTypeId = 8`. Ürün bazlı ayrım (`KatAna LIKE 'Sınav Okul%'`) FARKLI sonuç verir —
ikisi karıştırılmaz (`sql-server-conventions.md` § KANAL AYRACI).

⚠⚠ **İADE KANALA ATANAMIYOR — ölçülmüş sınır.** İade belgesi tip 3'tür ve kanal taşımaz;
`LinkedDocumentId` İst.Yolu'nda yalnız yarısında dolu (ölçüldü 12.09.2026: 22/54 · 27/66 ·
28/51). Yani **Sınav satışının iadesi de "Sınav hariç" sütununu eksiltir**. İst.Yolu'nda iade
260-462 bin ₺ = perakende cirosunun %17-29'u — ihmal edilebilir değil. Perakende rakamı bu
yüzden bir miktar DÜŞÜK olabilir.

═══ SAAT KESİMİ — kapanmamış günü tam günle kıyaslama ═════════════════════════
Gün içindeyken çekilen rapor tam günle kıyaslanamaz. `--kesim` saati verilirse her gün için
o saate kadarki rakam AYRI sayfada üretilir; karşılaştırma oradan yapılır.
Ölçüldü 12.09.2026: İst.Yolu günün %88,4'ünü (Sınav) / %81,2'sini (perakende) 20:10'dan önce
yapmış, mağaza 22:35'te kapanmış. Kesimsiz kıyas yanıltır.

⚠ pyodbc (pymssql DEĞİL): Türkçe varchar CP1254, pymssql bozar.

Kullanım:
    python scripts/hafta_sonu_magaza_ciro_excel.py \\
        --gunler 2025-09-06,2025-09-07,2026-09-12 --kesim 20:10
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
BASLIK_DOLGU = PatternFill("solid", fgColor="1F3864")
TOPLAM_DOLGU = PatternFill("solid", fgColor="D9E2F3")


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
    for anahtar in ("MSSQL_USER", "MSSQL_PASSWORD"):
        if not env.get(anahtar):
            kosamadi(f"{anahtar} .env'de yok — sessizce bos sifreyle baglanilmaz")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=EncoreMerkez;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 600
    return cn


# ?1 = gün (date). Saat kesimi dakika cinsinden ?2 (24*60 = kesim yok demek).
SQL = """
WITH g AS (
    SELECT st.Name AS Magaza, s.DocumentsTypeId AS Tip,
           (s.GrossTotal - s.DiscountTotal)              AS Dahil,
           (s.GrossTotal - s.DiscountTotal - s.VatTotal) AS Haric,
           s.Date AS Zaman
    FROM dbo.Sales s WITH (NOLOCK)
    JOIN dbo.Stores st WITH (NOLOCK) ON st.Id = s.StoresId
    WHERE s.Date >= ? AND s.Date < DATEADD(DAY, 1, ?)
      AND s.DocumentsTypeId IN (1,2,3,6,7,8)
      AND DATEPART(HOUR, s.Date) * 60 + DATEPART(MINUTE, s.Date) < ?
)
SELECT Magaza,
       SUM(CASE WHEN Tip = 1 THEN 1 ELSE 0 END) AS Fis,
       SUM(CASE WHEN Tip = 8 THEN 1 ELSE 0 END) AS SinavBelge,
       SUM(CASE WHEN Tip = 3 THEN 1 ELSE 0 END) AS IadeBelge,
       COUNT(*)                                  AS ToplamBelge,
       -- ⚠ İADE DÜŞÜLMEZ (kullanıcı direktifi 12.09.2026: "iade hiç düşme").
       -- Tip 3 ciro toplamlarının HİÇBİRİNE girmez; tutarı yalnız Iade_* sütununda BİLGİ olarak
       -- durur. Bu, projenin varsayılanının (iade işaretli düşülür) DIŞIDIR — başka raporla
       -- yan yana konursa tutmaz.
       CONVERT(decimal(18,2), SUM(CASE WHEN Tip IN (3,8) THEN 0 ELSE Dahil END)) AS SinavHaric_Dahil,
       CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 8 THEN Dahil ELSE 0 END))      AS Sinav_Dahil,
       CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 3 THEN Dahil ELSE 0 END))      AS Iade_Dahil,
       CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 3 THEN 0 ELSE Dahil END))      AS Toplam_Dahil,
       CONVERT(decimal(18,2), SUM(CASE WHEN Tip IN (3,8) THEN 0 ELSE Haric END)) AS SinavHaric_Haric,
       CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 8 THEN Haric ELSE 0 END))      AS Sinav_Haric,
       CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 3 THEN 0 ELSE Haric END))      AS Toplam_Haric,
       CONVERT(decimal(18,2), SUM(CASE WHEN Tip = 1 THEN Dahil ELSE 0 END)
            / NULLIF(SUM(CASE WHEN Tip = 1 THEN 1 ELSE 0 END), 0)) AS Sepet_Dahil,
       CONVERT(varchar(5), MAX(Zaman), 108) AS SonHareket
FROM g GROUP BY Magaza ORDER BY Magaza
"""

BASLIK = ["Gün", "Gün adı", "Mağaza", "Fiş", "Sınav belge", "İade belge", "Toplam belge",
          "Sınav hariç (KDV dahil)", "Sınav (KDV dahil)", "İade (KDV dahil)",
          "TOPLAM (KDV dahil)", "Sınav hariç (KDV hariç)", "Sınav (KDV hariç)",
          "TOPLAM (KDV hariç)", "Sepet ort. (KDV dahil)", "Son hareket"]
GUN_ADI = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]


def sayfa(wb: Workbook, ad: str, satirlar: list[list], not_metni: str) -> None:
    ws = wb.create_sheet(ad)
    ws.cell(1, 1, not_metni).font = Font(italic=True, size=9, color="555555")
    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(BASLIK))
    ws.cell(1, 1).alignment = Alignment(wrap_text=True, vertical="center")
    ws.row_dimensions[1].height = 32

    for j, b in enumerate(BASLIK, start=1):
        h = ws.cell(2, j, b)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = BASLIK_DOLGU
        h.alignment = Alignment(wrap_text=True, vertical="center", horizontal="center")
    ws.row_dimensions[2].height = 40

    for i, r in enumerate(satirlar, start=3):
        for j, v in enumerate(r, start=1):
            c = ws.cell(i, j, v)
            if j >= 8 and j <= 15 and isinstance(v, (int, float)):
                c.number_format = "#,##0"
            if str(r[2]).startswith("»"):          # toplam satırı
                c.font = Font(bold=True)
                c.fill = TOPLAM_DOLGU

    for j in range(1, len(BASLIK) + 1):
        en = max(len(str(BASLIK[j - 1])) // 2 + 6, 9)
        for i in range(3, len(satirlar) + 3):
            v = ws.cell(i, j).value
            if v is not None:
                en = max(en, min(len(f"{v:,.0f}" if isinstance(v, float) else str(v)), 26))
        ws.column_dimensions[get_column_letter(j)].width = en + 2
    ws.freeze_panes = "D3"


def topla(satirlar: list[list], etiket: str) -> list:
    """Sayı kolonlarını topla. Sepet ortalaması FİŞ AĞIRLIKLI hesaplanır.

    ⚠ Ortalamaların ortalaması ALINMAZ (`veri-dogrula` § average of averages). İlk sürümde
    sepet kolonu da SUM'a giriyordu ve toplam satırında 3.957 ₺ gibi anlamsız değer çıkıyordu
    — mağaza ortalamaları üst üste toplanmıştı. Ağırlıklı ortalama, toplam perakende cirosunu
    toplam fişe bölmekle ÖZDEŞTİR.
    """
    t: list = [satirlar[0][0], satirlar[0][1], etiket]
    for j in range(3, 14):                       # 14 = Sepet_Dahil → SUM'a GİRMEZ
        t.append(sum(r[j] or 0 for r in satirlar))
    fis = sum(r[3] or 0 for r in satirlar)
    agirlikli = sum((r[14] or 0) * (r[3] or 0) for r in satirlar)
    t.append(round(agirlikli / fis, 2) if fis else None)
    t.append("")
    return t


def sade_sayfa(wb: Workbook, tam: list[list], gunler: list[dt.date], kesim: str | None) -> None:
    """PATRON TABLOSU — tek sayfa, iki blok: CİRO ve MÜŞTERİ SAYISI.

    Kullanıcı geri bildirimi 12.09.2026: _"çok fazla veri olmuş patron sade bir şey sordu"_.
    Ayrıntılı sayfalar duruyor; bu sayfa yalnız sorulanı gösterir (`sunum-dili.md`).
    Müşteri sayısı = FİŞ sayısı. ⚠ Tekil müşteri DEĞİL: kartsız satışta `CustomersId = 0`
    (anonim), tekil sayım kartsızın tamamını tek müşteriye indirir.
    """
    ws = wb.create_sheet("PATRON TABLOSU", 0)
    yillar: dict[int, list[dt.date]] = {}
    for g in gunler:
        yillar.setdefault(g.year, []).append(g)

    kolonlar: list[tuple[str, list[dt.date]]] = []
    for yil in sorted(yillar):
        for g in yillar[yil]:
            kolonlar.append((f"{GUN_ADI[g.weekday()][:3]} {g:%d.%m.%y}", [g]))
        if len(yillar[yil]) > 1:
            kolonlar.append((f"{yil} TOPLAM", list(yillar[yil])))

    # (etiket, mağaza adı içinde geçen, hangi sütun) — İst.Yolu iki satıra ayrılır.
    satir_tanim = [
        ("FSM", "FSM", "haric"),
        ("Özlüce", "ÖZLÜCE", "haric"),
        ("İst.Yolu (Sınav hariç)", "IST YOLU", "haric"),
        ("İst.Yolu — Sınav", "IST YOLU", "sinav"),
    ]

    def deger(gun: dt.date, magaza: str, hangi: str, blok: str) -> float:
        idx = {("haric", "ciro"): 7, ("sinav", "ciro"): 8,
               ("haric", "musteri"): 3, ("sinav", "musteri"): 4}[(hangi, blok)]
        top = 0.0
        for r in tam:
            if str(r[2]).startswith("»"):
                continue
            if r[0] == gun.strftime("%d.%m.%Y") and magaza in str(r[2]):
                top += float(r[idx] or 0)
        return top

    r = 1
    ws.cell(r, 1, "OKUL AÇILIŞI ÖNCESİ HAFTA SONU").font = Font(bold=True, size=14)
    r += 1
    ws.cell(r, 1, "Ciro KDV dahil, iade düşülmemiş · günün tamamı · kaynak kasa (EncoreMerkez)"
            ).font = Font(italic=True, size=9, color="555555")
    r += 2

    for blok, baslik in (("ciro", "CİRO (₺)"), ("musteri", "MÜŞTERİ SAYISI (fiş)")):
        ws.cell(r, 1, baslik).font = Font(bold=True, size=12)
        r += 1
        ws.cell(r, 1, "Mağaza").font = Font(bold=True, color="FFFFFF")
        ws.cell(r, 1).fill = BASLIK_DOLGU
        for j, (ad, _) in enumerate(kolonlar, start=2):
            h = ws.cell(r, j, ad)
            h.font = Font(bold=True, color="FFFFFF")
            h.fill = BASLIK_DOLGU
            h.alignment = Alignment(horizontal="center")
        r += 1
        for etiket, mag, hangi in satir_tanim:
            ws.cell(r, 1, etiket)
            for j, (_, gs) in enumerate(kolonlar, start=2):
                c = ws.cell(r, j, sum(deger(g, mag, hangi, blok) for g in gs))
                c.number_format = "#,##0"
                if len(gs) > 1:
                    c.font = Font(bold=True)
                    c.fill = TOPLAM_DOLGU
            r += 1
        r += 1

    ws.cell(r, 1, "Müşteri sayısı = fiş sayısı. Tekil müşteri değil — kartsız satış anonimdir.")
    ws.cell(r, 1).font = Font(italic=True, size=9, color="555555")
    r += 1
    ws.cell(r, 1, f"Son gün ({max(gunler):%d.%m.%Y}) henüz kapanmadı; geçen yılın aynı saatine "
                  f"göre kıyas ayrı sayfadadır (--kesim).").font = Font(italic=True, size=9,
                                                                        color="C00000")
    ws.column_dimensions["A"].width = 24
    for j in range(2, len(kolonlar) + 2):
        ws.column_dimensions[get_column_letter(j)].width = 15


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gunler", required=True, help="ISO tarihler, virgülle: 2025-09-06,...")
    ap.add_argument("--kesim", default=None, help="SS:DD — verilirse ikinci sayfa üretilir")
    ap.add_argument("--sade", action="store_true",
                    help="YALNIZ patron tablosu (ciro + müşteri sayısı, tek sayfa)")
    ap.add_argument("--cikti", default=None)
    a = ap.parse_args()

    try:
        gunler = [dt.date.fromisoformat(x.strip()) for x in a.gunler.split(",") if x.strip()]
    except ValueError as e:
        kosamadi(f"Gecersiz tarih: {e}")
    if not gunler:
        kosamadi("--gunler bos")

    kesim_dk = 24 * 60
    if a.kesim:
        m = re.fullmatch(r"(\d{1,2}):(\d{2})", a.kesim.strip())
        if not m:
            kosamadi("--kesim SS:DD olmali")
        kesim_dk = int(m.group(1)) * 60 + int(m.group(2))

    env = env_oku(os.path.join(KOK, ".env"))
    cn = baglan(env)
    try:
        cur = cn.cursor()

        def cek(limit_dk: int) -> list[list]:
            cikti: list[list] = []
            for g in gunler:
                cur.execute(SQL, g, g, limit_dk)
                bugun = [[str(g.strftime("%d.%m.%Y")), GUN_ADI[g.weekday()]] + list(r)
                         for r in cur.fetchall()]
                if not bugun:
                    continue
                cikti.extend(bugun)
                cikti.append(topla(bugun, f"» {g:%d.%m} TOPLAM"))
            return cikti

        tam = cek(24 * 60)
        hizali = cek(kesim_dk) if a.kesim else []
    finally:
        cn.close()

    if not tam:
        kosamadi("Hicbir gun icin satir donmedi — tarihler yanlis ya da kasa verisi yok")

    wb = Workbook()
    ws = wb.active
    ws.title = "ÖZET"
    ozet = [
        ("MAĞAZA BAZLI GÜNLÜK CİRO — fiş sayılı, Sınav ayrımlı", ""),
        ("Kaynak", "EncoreMerkez dbo.Sales (KASA). ERP irsHrk değil — kanal ayrımı belge tipinden."),
        ("Günler", ", ".join(f"{g:%d.%m.%Y}" for g in gunler)),
        ("Saat kesimi", a.kesim or "(yok — yalnız tam gün)"),
        ("", ""),
        ("CİRO TABANI", ""),
        ("KDV dahil (ana sayı)", "GrossTotal − DiscountTotal"),
        ("KDV hariç (yan sütun)", "GrossTotal − DiscountTotal − VatTotal"),
        ("⚠ Taban uyarısı", "Panel ve öteki raporlar CFO direktifiyle (plan-16) KDV HARİÇ çalışır. "
                            "Bu rapor KDV dahili öne alıyor — iki raporu yan yana koyarsan tutmaz."),
        ("⚠ İade", "DÜŞÜLMEDİ (kullanıcı direktifi: 'iade hiç düşme'). Tip 3 hiçbir ciro "
                 "toplamına girmiyor; tutarı yalnız İade sütununda bilgi olarak duruyor. "
                 "Projenin varsayılanı iadeyi DÜŞER — bu rapor onun dışında."),
        ("Sepet ortalama", "Fiş cirosu (tip 1) ÷ fiş sayısı. Fatura, Sınav ve iade hariç."),
        ("Belge tipleri", "1 Fiş · 2 Fatura · 3 İade(−) · 6 Personel Fiş · 7 Personel Fatura · 8 Sınav"),
        ("", ""),
        ("ÖLÇÜLMÜŞ SINIRLAR", ""),
        ("⚠ İade kanala ATANAMIYOR", "İade belgesi kanal taşımaz; LinkedDocumentId İst.Yolu'nda "
                                     "yalnız yarısında dolu (22/54 · 27/66 · 28/51 — ölçüldü 12.09.2026). "
                                     "Sınav satışının iadesi de 'Sınav hariç' sütununu EKSİLTİR. "
                                     "İst.Yolu'nda iade 260-462 bin ₺ = perakende cirosunun %17-29'u. "
                                     "Perakende rakamı bir miktar DÜŞÜK olabilir."),
        ("⚠ Sınav ayrımı BELGE bazlı", "DocumentsTypeId = 8. Ürün bazlı ayrım (KatAna 'Sınav Okul%') "
                                       "FARKLI sonuç verir; ikisi karıştırılmaz."),
        ("⚠ Kapanmamış gün", "Gün içindeyken tam günle kıyaslanmaz. Ölçüldü 12.09.2026: İst.Yolu "
                             "günün %88,4'ünü (Sınav) / %81,2'sini (perakende) 20:10'dan önce yapmış, "
                             "mağaza 22:35'te kapanmış. Kıyas HİZALI sayfadan yapılır."),
        ("⚠ Sınav yalnız İst.Yolu", "FSM ve Özlüce'de Sınav belgesi sıfır (Ağu-2024'te operasyon taşındı)."),
    ]
    for i, (k, v) in enumerate(ozet, start=1):
        c = ws.cell(i, 1, k)
        ws.cell(i, 2, v).alignment = Alignment(wrap_text=True, vertical="top")
        c.font = Font(bold=True, size=13) if i == 1 else Font(bold=True, size=10)
    ws.column_dimensions["A"].width = 30
    ws.column_dimensions["B"].width = 104

    # Patron tablosu TAM GÜN verisinden kurulur.
    # ⚠ Bilinçli: geçmiş günlerin GERÇEK cirosu sorulmuştur; saat kesimi yalnız KIYAS içindir
    # ve kıyas notu altta yazılır. Hizalı veriyle kurulursa geçen yılın gerçek günü olduğundan
    # DÜŞÜK görünür ve patron yanlış sayıyı hatırlar.
    sade_sayfa(wb, tam, gunler, None)
    if a.sade:
        for ad in [x for x in wb.sheetnames if x != "PATRON TABLOSU"]:
            del wb[ad]
        cikti_sade = a.cikti or os.path.join(
            KOK, "raporlar", f"patron-tablosu-{max(gunler):%Y%m%d}.xlsx")
        os.makedirs(os.path.dirname(cikti_sade), exist_ok=True)
        wb.save(cikti_sade)
        print(f"YAZILDI (sade): {cikti_sade}")
        return 0

    sayfa(wb, "TAM GÜN", tam,
          "Günün tamamı. Kapanmamış gün varsa bu sayfa kıyas için KULLANILMAZ — HİZALI sayfaya bak.")
    if hizali:
        sayfa(wb, f"HİZALI {a.kesim.replace(':', '')}", hizali,
              f"Her gün {a.kesim}'a kadarki rakam. Kapanmamış günü geçen yılla kıyaslamanın "
              f"TEK adil yolu budur.")

    cikti = a.cikti or os.path.join(
        KOK, "raporlar",
        f"magaza-gunluk-ciro-{min(gunler):%Y%m%d}-{max(gunler):%Y%m%d}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)
    print(f"YAZILDI: {cikti}")
    print(f"  gun sayisi: {len(gunler)} · tam gun satiri: {len(tam)}"
          + (f" · hizali satir: {len(hizali)}" if hizali else ""))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
