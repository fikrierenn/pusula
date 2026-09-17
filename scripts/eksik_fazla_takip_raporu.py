# -*- coding: utf-8 -*-
"""BKMKİTAP EKSİK VE FAZLA TAKİP RAPORU — 11 sayfalık çalışma kitabının üretimi.

Elle kurulan `BKMKİTAP Eksik ve Fazla Takip Raporu.xlsx` dosyasının SQL'den
yeniden üretimi. Hesap çekirdeği `vardiya_pdks_program_raporu`dur (kurallar orada
ÖLÇÜLDÜ); bu dosya bir EMITTER'dır — hesap YAPMAZ, biçim verir
(`.claude/rules/emitter-ayrimi.md`).

SAYFALAR — üç sınıf, karıştırılmaz. Kaynak dosyadaki `Ayrıntı1` KALDIRILDI
(GMY kararı 17.09.2026): bir PivotTable hücresine çift tıklanınca oluşan anlık
dökümdü, veriden yeniden üretilemiyordu ve boş duruyordu.



  ÜRETİLEN (SQL'den):
    · Vardiya Yönet Program Raporu   — 40 kolon, formüllü ana sayfa
    · Vardiya Yönet Raporu           — aracın ham çıktısının karşılığı (24 kolon)
    · Güncel Personel Listesi        — Zirve BKM_GENEL.dbo.vw_PersonelDepartman
    · Özet Y                         — PivotTable → SUMIFS (formüle çevrildi)
    · Haftalık Çalışma Gün Sayısı    — PivotTable → SUMIFS
    · Mola Saatleri                  — parametre sayfası (şube saatleri ÖLÇÜLÜR)

  KOPYALANAN (veri DEĞİL — politika/elle girdi; kaynaktan türetilemez):
    · Çalışma Saatleri               — grup×şube×bölüm → günlük saat (İK politikası)
    · Kart Basmayan Gruplar          — rapor dışı tutulan kadro (yönetim kararı)
    · Mağaza Geri Dönüşleri          — yöneticinin elle bildirdiği saat düzeltmeleri
    · <Ay> Devir Saatler             — ÖNCEKİ ayın kapanış bakiyesi

  ÜRETİLEMEYEN (bilerek boş):
    · V/W "Yönetici Onaylı Giriş/Çıkış" — elle girilir. Kaynak dosyada 4.873 satırda
      dolu; hiçbir veri kaynağından türetilemiyor (ölçüldü). Boş bırakılır; formül
      `IF(V=0,T,V)` ile toleranslı saate düşer, değer girilince kendiliğinden devreye
      girer.
    · AK "Evden Çalışma veya Ek Mesai" — elle girilir.

DÜZELTİLEN İKİ FORMÜL (bu oturumda ölçüldü, kaynak dosyada HATALIYDI):
  1) AD "Net Çalışma Saati Olması Gereken": eski formül `Q="Devamsız"` satırında
     VLOOKUP'u İKİ KEZ topluyordu (taban + ek terim) → vardiya saatinin 2 KATI.
     Ayrıca ayraç olarak Q (durum) kullanılıyordu; doğru ayraç J (vardiya tanımı):
     vardiya tanımı gerçek saat aralığıysa devamsız da olsa mesai BEKLENİR (eksik
     saat oluşsun), izin/özel-durum etiketiyse 0.
  2) AI "Haftalık İzin Artı Ekleniş": prim haftanın SAYFADAKİ İLK SATIRINA
     yazılıyordu. Kapsam iki ISO haftası (31.08–13.09) ve 36. haftanın ilk günü
     31 AĞUSTOS → Eylül haftasının primi Ağustos'a düşüyordu (331 kişi-hafta).
     Yeni formül satır sırasına değil HAFTANIN GÜNÜNE bağlı (Pazar) ve sabit 7:30
     yerine gruba göre VLOOKUP kullanır (GM'de 9:00).

⚠ Tarih kolonu GERÇEK TARİH yazılır (metin değil): `WEEKDAY`/`WEEKNUM` metin
  tarihte locale'e göre sessizce kayabilir. B anahtarı bu yüzden
  `TEXT(I;"gg.aa.yyyy")` kullanır — `Mağaza Geri Dönüşleri` sayfasındaki anahtarla
  birebir aynı biçim.

Kullanım:
    python scripts/eksik_fazla_takip_raporu.py --bas 31.08.2026 --bit 13.09.2026
"""
from __future__ import annotations

import argparse
import datetime as dt
import json

import os
import re
import sys

import pyodbc
from openpyxl import Workbook, load_workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter as GL

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vardiya_pdks_program_raporu as cekirdek      # noqa: E402  (hesap çekirdeği)

# ⚠ stdout SARMALANMAZ — çekirdek modülü import edilirken zaten UTF-8'e sarıyor.
# İkinci kez sarmak ilk sarmalayıcıyı çöp toplamaya bırakır, o da ALTTAKİ buffer'ı
# kapatır → "I/O operation on closed file" (ölçüldü).

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# J (Vardiya Tanım) bu etiketleri taşıyorsa o gün mesai BEKLENMEZ.
# Küme kaynak dosyanın 5.062 satırından ÖLÇÜLDÜ (elle yazılmadı):
#   HFT.İZİN 627 · ÖZEL DURUM 53 · RAPOR 31 · YILLIK İZİN 10 · ÜCRETSİZ İZİN 7
# Tüm rapor varlıkları TEK KLASÖRDE (GMY kararı 17.09.2026): parametre dosyası,
# elle girilen veri sayfalarının kaynağı ve üretilen çıktı `vardiya/` altında durur.
# Kod `scripts/` altında kalır.
VARDIYA_DIZIN = os.path.join(KOK, "vardiya")
PARAMETRE_YOLU = os.path.join(VARDIYA_DIZIN, "vardiya_parametreleri.json")

# Kaynak çalışma kitabından yalnız bunlar KOPYALANIR (parametre değil, elle girilen
# VERİ). Parametre/tanım tabloları artık JSON'dan ÜRETİLİR.
KOPYALANAN = ["Mağaza Geri Dönüşleri"]

BASLIK_ANA = [
    "FORMÜLLÜ", "FORMÜLLÜ", "Şube", "SicilNo", "PDKS No", "Personel", "Bölüm",
    "Görev", "Tarih", "Vardiya Tanım", "Personel Giriş", "Personel Çıkış",
    "PDKS Giris", "PDKS Çıkış", "Personel Çalışma", "Vardiya Tanım Çalışma",
    "Durum", "EksikSaat", "FazlaSaat", "Toleranslı Giriş", "Toleranslı Çıkış",
    "Yönetici Onaylı  Giriş", "Yönetici Onaylı  Çıkış", "Giriş", "Çıkış",
    "Brüt Çalışma Saati", "Mola Saati", "Net Çalışma Saati\nGerçekleşen",
    "Net Çalışma Saati 2\nGerçekleşen", "Net Çalışma Saati Olması Gereken",
    "Eksik Saat", "Fazla Saat", "İzin Durumu", "Hafta",
    "Haftalık İzin Artı Ekleniş",
    "Net 11 saatin üstü çalışma var ise ek 00:30:00 mola yansıtma",
    "Evden Çalışma veya Ek Mesai", "Kart Basma Durum", "Aktif/Pasif", "Grup",
    # ── AO: çekirdeğin denetim notu (gün dönümü · şüpheli "Devamsız" · devir günü).
    #    Aracın kolonlarının ARASINA giremez, yoksa tüm formüller bir kolon kayar.
    "Ölçüm Notu",
]

BASLIK_VYR = [
    "Şube", "SicilNo", "PDKS No", "Personel", "Bölüm", "Görev", "Tarih",
    "Vardiya Tanım", "İzin", "Vardiya Başlama", "Vardiya Bitiş", "Personel Giriş",
    "Personel Çıkış", "PDKS Giris", "PDKS Çıkış", "PDKS Giriş Fark",
    "PDKS Çıkış Fark", "Personel Çalışma", "Vardiya Tanım Çalışma", "Durum",
    "Gün Kayıt Sayısı", "Mazeret Tipi", "EksikSaat", "FazlaSaat",
]

BASLIK_PERSONEL = [
    "Sno", "Adı Soyadı", "Doğum Tarihi", "Tc Kimlik No", "İşe Giriş Tar.",
    "Cinsiyeti", "Nüf.Cüz.Seri No", "Departman (grup)", "Cüzdan Kayıt No",
    "Meslek İli", "Görevi", "Meslek İlçesi", "Personel Grubu",
    "Nüf.Kay.Old.Mah/köy", "Durum",
]

# Zirve İK. ⚠ `perbilgi`ye DOĞRUDAN inilmez: A4/SeriNo kolonları satırın yaşına
# göre İKİ ANLAM taşıyor (köy adları istihdam tipi sanılır) — sema
# `zirve_perbilgi_a4_iki_anlamli`. Kadro daima bu view üzerinden okunur.
# As-of şartı kullanıcının kendi kadro raporundan (sema `zirve_as_of_kadro_sarti`).
SQL_PERSONEL = """
SELECT  AdSoyad, Vatno, Dt, Igt, Ict, Cinsiyet,
        Lokasyon, AltLokasyon, AltAltLokasyon, Departman, Unvan, Kadro, Firma
FROM    dbo.vw_PersonelDepartman
WHERE   Igt <= ? AND (Ict IS NULL OR Ict >= ?)
ORDER BY AdSoyad
"""

# =============================================================================
# YARDIMCI
# =============================================================================
def zirve_baglan(env: dict[str, str]):
    """⚠ pyodbc: adlandırılmış örneğe (ters bölü) pymssql portsuz ulaşamaz, asılır."""
    host = env.get("ZIRVE_HOST", "")
    if not re.fullmatch(r"[A-Za-z0-9._\\\-]+", host):
        sys.exit("Gecersiz ZIRVE_HOST (.env)")
    return pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host};Database={env.get('ZIRVE_DATABASE', 'BKM_GENEL')};"
        f"UID={env['ZIRVE_USER']};PWD={env['ZIRVE_PASSWORD']};"
        "TrustServerCertificate=yes;Encrypt=no;Login Timeout=15",
        timeout=300,
    )


def sa(metin: str) -> dt.time:
    s, d = metin.split(":")
    return dt.time(int(s), int(d))


def sure(hhmm: str | None) -> dt.timedelta | None:
    """'07:30' / '-2:07' → timedelta."""
    if not hhmm:
        return None
    eksi = hhmm.startswith("-")
    p = hhmm.lstrip("-").split(":")
    td = dt.timedelta(hours=int(p[0]), minutes=int(p[1]))
    return -td if eksi else td


def eksik_fazla(calisma: str | None, plan: str | None):
    """Aracın EksikSaat/FazlaSaat'i (R/S kolonları).

    Formül DEĞİL, Python'da hesaplanır: `Personel Çalışma` negatif olabiliyor
    ("-2:07") ve Excel negatif saatte #DEĞER! verir — kaynak dosyada S sütunu
    5.062 satırın TAMAMINDA #VALUE! idi.
    """
    c, p = sure(calisma), sure(plan)
    if c is None or p is None:
        return (None, None)
    return (p - c, dt.timedelta(0)) if c < p else (dt.timedelta(0), c - p)


def baslik_bicim(ws, n: int, satir: int = 1) -> None:
    for c in range(1, n + 1):
        h = ws.cell(satir, c)
        h.font = Font(bold=True, color="FFFFFF", size=10)
        h.fill = PatternFill("solid", fgColor="E30622")
        h.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    ws.freeze_panes = f"A{satir + 1}"


def sayfa_kopyala(hedef: Workbook, kaynak_wb, ad: str) -> int:
    """Politika/elle-girdi sayfasını olduğu gibi taşır (değer + formül + biçim)."""
    src = kaynak_wb[ad]
    ws = hedef.create_sheet(ad)
    for row in src.iter_rows():
        for c in row:
            if c.value is None:
                continue
            h = ws.cell(c.row, c.column, c.value)
            if c.number_format:
                h.number_format = c.number_format
    for k, v in src.column_dimensions.items():
        if v.width:
            ws.column_dimensions[k].width = v.width
    return src.max_row


# =============================================================================
# ANA SAYFA
# =============================================================================
def parametre_oku(yol: str) -> dict:
    """Parametre/tanım tablolarını JSON'dan okur ve YAPISINI DENETLER.

    Denetim kasıtlı: eksik/boş bir parametre bloğu sessizce geçerse `VLOOKUP`
    #YOK verir ve hata ana sayfanın 5.000 satırına dağılır — sebebi orada
    aranmaz. Burada patlarsa nerede olduğu bellidir.
    """
    if not os.path.exists(yol):
        sys.exit(f"KOŞAMADI: parametre dosyası yok: {yol}")
    with open(yol, encoding="utf-8") as f:
        cfg = json.load(f)
    for alan, tip in (("izin_etiketleri", list), ("mola_net_tablosu", list),
                      ("mola_brut_tablosu", list), ("subeler", list),
                      ("calisma_saatleri", list), ("kart_basmayan_gruplar", list)):
        if not isinstance(cfg.get(alan), tip) or not cfg[alan]:
            sys.exit(f"KOŞAMADI: parametre dosyasında '{alan}' eksik veya boş.")
    for s in cfg["subeler"]:
        if not s.get("sube") or not s.get("grup"):
            sys.exit(f"KOŞAMADI: 'subeler' kaydında sube/grup eksik: {s}")
    return cfg


def parametre_yaz(cfg: dict, yol: str) -> None:
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
        f.write("\n")


def calisma_saatleri_tamamla(cfg: dict, satirlar: list[list],
                             net_gereken: dict[str, str],
                             grup: dict[str, str]) -> list[str]:
    """Politika tablosunda KARŞILIĞI OLMAYAN grup×şube×bölüm birleşimlerini
    şube varsayılanıyla EKLER ve `not` alanına damga düşer.

    Neden sessiz IFERROR değil: eksik anahtar `VLOOKUP` ile #YOK verir, o da
    AD→AE/AF→Özet zincirini komple bozar. Sessizce şube varsayılanına düşmek ise
    politika boşluğunu GİZLER (`error-handling.md` § fallback sessiz olmasın).
    Ortası: kayıt eklenir ama damgalanır — JSON git'te izlenir, İK görür ve
    gerçek saati yazar.
    """
    mevcut = {f"{c.get('grup') or ''}{c.get('sube') or ''}{c.get('bolum') or ''}"
              for c in cfg["calisma_saatleri"]}
    gerekli = {(grup.get(s[0]) or "", s[0] or "", s[4] or "") for s in satirlar}
    eklenen = []
    for g, sb, bolum in sorted(gerekli):
        if f"{g}{sb}{bolum}" in mevcut:
            continue
        cfg["calisma_saatleri"].append({
            "grup": g, "sube": sb, "bolum": bolum or None,
            "saat": net_gereken.get(sb, "07:30"),
            "not": "OTOMATİK EKLENDİ — şube varsayılanı, İK onaylamalı",
        })
        eklenen.append(f"{g} / {sb} / {bolum or '(bölüm boş)'}")
    return eklenen


def calisma_saatleri_sayfa(wb: Workbook, cfg: dict) -> None:
    """`Çalışma Saatleri` — JSON'dan ÜRETİLİR. AD ve AI formüllerinin VLOOKUP tabanı.

    ⚠ E kolonu GERÇEK ZAMAN olmalı, metin DEĞİL: metin Excel'de her sayıdan büyük
    sayılır, `IF(AC<AD;...)` hep TRUE döner ve Eksik/Fazla YER DEĞİŞTİRİR — hata
    vermeden (2026-09-15'te ölçüldü).
    """
    ws = wb.create_sheet("Çalışma Saatleri")
    for c, b in enumerate([None, "Grup", "Şube", "Bölüm", "Çalışma Saatleri",
                           "Not"], start=1):
        if b:
            ws.cell(1, c, b)
    baslik_bicim(ws, 6)
    for r, k in enumerate(cfg["calisma_saatleri"], start=2):
        ws.cell(r, 1, f"=B{r}&C{r}&D{r}")
        ws.cell(r, 2, k.get("grup"))
        ws.cell(r, 3, k.get("sube"))
        ws.cell(r, 4, k.get("bolum"))
        ws.cell(r, 5, sa(k["saat"])).number_format = "[h]:mm"
        ws.cell(r, 6, k.get("not"))
    for k, w in (("A", 40), ("B", 18), ("C", 16), ("D", 26), ("E", 16), ("F", 46)):
        ws.column_dimensions[k].width = w


def kart_basmayan_sayfa(wb: Workbook, cfg: dict) -> None:
    """`Kart Basmayan Gruplar` — JSON'dan ÜRETİLİR. AL kolonunun VLOOKUP tabanı."""
    ws = wb.create_sheet("Kart Basmayan Gruplar")
    for c, b in enumerate(["Adı Soyadı", "Kartvizit Ünvanı", "Grup",
                           "Raporlama Durum"], start=1):
        ws.cell(1, c, b)
    baslik_bicim(ws, 4)
    for r, k in enumerate(cfg["kart_basmayan_gruplar"], start=2):
        ws.cell(r, 1, k.get("ad_soyad"))
        ws.cell(r, 2, k.get("kartvizit_unvani"))
        ws.cell(r, 3, k.get("grup"))
        ws.cell(r, 4, k.get("raporlama_durum"))
    for k, w in (("A", 28), ("B", 30), ("C", 14), ("D", 18)):
        ws.column_dimensions[k].width = w


def ana_sayfa(wb: Workbook, satirlar: list[list], devir: list[list],
              izin_etiketleri: list[str], sayim_bas: dt.date | None = None) -> int:
    """`sayim_bas`: bu tarihten ÖNCEKİ günler raporda DURUR ama Eksik/Fazla Saat'e
    KATILMAZ (0 yazılır).

    Gerekçe (GMY 17.09.2026: *"31 08 ağustos devrinde var zaten"*): dönem başındaki
    gün önceki ayın devir bakiyesine dahilse, günlük satırı da toplama girerse ÇİFT
    SAYILIR. Ama o günü tamamen atmak da olmaz — ÖLÇÜLDÜ: 31.08 Pazartesi olduğu
    için atıldığında 36. haftanın "7 gün çalıştı" şartı 6 günle sağlanamıyor ve
    haftalık izin primi **378 saat** sıfırlanıyor.
    Çözüm: satır DURUR (hafta bütünlüğü + İzin Durumu sayımı için), yalnız Eksik/Fazla
    Saat sıfırlanır ve Ölçüm Notu'nda beyan edilir.
    """
    ws = wb.create_sheet("Vardiya Yönet Program Raporu")
    ws.append(BASLIK_ANA)
    baslik_bicim(ws, len(BASLIK_ANA))
    # AK uyarısı — GMY bildirimi 17.09.2026: bu kolon eskiden gün dönümü telafisi
    # için ELLE dolduruluyordu. ÖLÇÜLDÜ: kaynak dosyada AK dolu 11 satırın 9'u tam
    # olarak çıkış<giriş olan satırlar (ör. AYŞE KARATAŞ 12.09 çıkış 00:24 → AK 2:24).
    # Gün dönümü ARTIK Z formülünde otomatik; AK'ya aynı saat yazılırsa AF
    # (`...+AI+AK`) o mesaiyi İKİ KEZ sayar.
    ws.cell(1, 37).comment = Comment(
        "GÜN DÖNÜMÜ ARTIK OTOMATİK.\n\n"
        "Gece mesaisine kalıp ertesi gün çıkan personelin fazla mesaisi Brüt "
        "Çalışma Saati (Z) formülünde kendiliğinden hesaplanır.\n\n"
        "Buraya gün dönümü telafisi YAZMAYIN — Fazla Saat (AF) kolonu AK'yı da "
        "topladığı için mesai İKİ KEZ sayılır.\n\n"
        "Bu kolon yalnız gerçek evden çalışma / ayrıca onaylanmış ek mesai için.",
        "BKM Rapor")
    ws.cell(1, 37).comment.width = 320
    ws.cell(1, 37).comment.height = 180

    son = len(satirlar) + len(devir) + 1
    CS = "'Çalışma Saatleri'!$A:$E"

    for i, s in enumerate(satirlar, start=2):
        ek = s[16] if len(s) > 16 else {}
        devir_gunu = sayim_bas is not None and ek.get("Tarih") is not None             and ek["Tarih"] < sayim_bas
        izin_kosul = ",".join(f'$J{i}="{e}"' for e in izin_etiketleri)
        r_s = eksik_fazla(s[12], s[13])
        ws.append([
            f"=AN{i}&C{i}&G{i}",                       # A  Grup+Şube+Bölüm anahtarı
            f'=F{i}&TEXT(I{i},"gg.aa.yyyy")',          # B  Personel+Tarih anahtarı
            s[0], s[1], s[2], s[3], s[4], s[5],        # C..H
            ek.get("Tarih"),                           # I  GERÇEK TARİH (metin değil)
            s[7],                                      # J  Vardiya Tanım
            s[8], s[9], s[10], s[11],                  # K..N saatler
            s[12], s[13], s[14],                       # O Personel Çalışma, P plan, Q Durum
            r_s[0], r_s[1],                            # R, S
            f"=+K{i}", f"=+L{i}",                      # T, U Toleranslı
            None, None,                                # V, W Yönetici Onaylı (ELLE)
            f"=IF(V{i}=0,T{i},V{i})",                  # X Giriş
            f"=IF(W{i}=0,U{i},W{i})",                  # Y Çıkış
            # Z Brüt — GÜN DÖNÜMÜ: çıkış girişten küçükse ertesi güne aittir.
            # Düz çıkarma negatif verir, AA mola formülü onu 0 sayar ve Eksik
            # Saat sessizce şişer (9 kişi-gün ölçüldü).
            f"=IF(Y{i}<X{i},Y{i}+1-X{i},Y{i}-X{i})",   # Z Brüt
            (f'=IF(OR(Z{i}="",Z{i}<=0),0,IF(Z{i}<=TIME(4,0,0),TIME(0,15,0),'
             f"IF(Z{i}<=TIME(7,30,0),TIME(0,30,0),TIME(1,0,0))))"),   # AA Mola
            f"=+Z{i}-AA{i}",                           # AB Net gerçekleşen
            f"=+AB{i}-AJ{i}",                          # AC Net 2 (11 saat molası düşülmüş)
            # AD — DÜZELTİLDİ: ayraç J (vardiya tanımı), Q değil; çift toplama kaldırıldı
            f"=IF(OR({izin_kosul}),0,VLOOKUP($A{i},{CS},5,0))",
            # AE/AF — sayım penceresi dışındaki gün toplama KATILMAZ (devirde sayılı)
            (0 if devir_gunu else f"=IF(AC{i}<AD{i},AD{i}-AC{i},0)"),      # AE Eksik
            (0 if devir_gunu else
             f"=IF(AC{i}>AD{i},AC{i}-AD{i},0)+AI{i}+AK{i}"),               # AF Fazla
            f'=IF(OR(Q{i}="İZİNLİ",Q{i}="DEVAMSIZ"),0,1)',   # AG İzin Durumu
            f"=WEEKNUM(I{i},2)",                       # AH Hafta
            # AI — DÜZELTİLDİ: haftanın SON GÜNÜNE (Pazar) yazılır, sayfadaki ilk
            # satıra değil; ay dönümünde prim önceki aya kaçmasın diye.
            (f"=IFERROR(IF(AND(WEEKDAY($I{i},2)=7,"
             f"SUMIFS($AG$2:$AG${son},$D$2:$D${son},$D{i},"
             f"$AH$2:$AH${son},$AH{i})=7),VLOOKUP($A{i},{CS},5,0),0),0)")
            if not devir_gunu else 0,
            f"=IF(AB{i}>TIME(11,0,0),TIME(0,30,0),0)",  # AJ
            None,                                       # AK Evden/Ek Mesai (ELLE)
            f"=IFERROR(VLOOKUP(F{i},'Kart Basmayan Gruplar'!A:D,4,0),\"Dahil\")",
            # AM Aktif/Pasif — eşleşme TC ile (GMY kararı 17.09.2026), İSİMLE DEĞİL.
            # İsim eşleşmesi adaşta yanlış kişinin durumunu yazar; son koşumda
            # 1 adaş ÖLÇÜLDÜ. Anahtar: SicilNo (D) ↔ Tc Kimlik No (personel D).
            f"=IFERROR(VLOOKUP($D{i},'Güncel Personel Listesi'!$D:$O,12,0),\"Zirve'de yok\")",
            f"=VLOOKUP(C{i},'Mola Saatleri'!$E:$G,3,0)",
            # AO Ölçüm Notu — beyan SESSİZ KALMAZ.
            " · ".join(n for n in (
                ("ÖNCEKİ AY DEVRİNDE SAYILDI — Eksik/Fazla Saat'e katılmaz, satır "
                 "yalnız hafta bütünlüğü için durur") if devir_gunu else "",
                s[15] if len(s) > 15 and s[15] else "",
            ) if n) or None,
        ])
        if devir_gunu:
            ws.cell(i, 41).font = Font(italic=True, color="9A3412")

    # ── DEVİR SATIRLARI ── önceki ayın bakiyesi. Formül TAŞIMAZ: Eksik/Fazla sabit
    # değer, kalan kolonlar boş (kaynak dosyada da böyle).
    for j, d in enumerate(devir, start=len(satirlar) + 2):
        for hedef, kaynak in ((3, 0), (4, 1), (5, 2), (6, 3), (7, 4), (8, 5), (9, 6)):
            ws.cell(j, hedef, d[kaynak])
        ws.cell(j, 31, d[7]).number_format = "[h]:mm"
        ws.cell(j, 32, d[8]).number_format = "[h]:mm"

    for c, w in enumerate([22, 22, 13, 13, 9, 24, 18, 22, 11, 14] + [10] * 8
                          + [11] * 12 + [13] * 8 + [52], start=1):
        ws.column_dimensions[GL(c)].width = w
    elle = PatternFill("solid", fgColor="FFF3C4")
    for r in range(2, len(satirlar) + 2):
        ws.cell(r, 9).number_format = "dd.mm.yyyy"
        for c in (18, 19, 26, 27, 28, 29, 30, 31, 32, 35, 36):
            ws.cell(r, c).number_format = "[h]:mm"
        for c in (20, 21, 24, 25):
            ws.cell(r, c).number_format = "hh:mm"
        for c in (22, 23, 37):                  # ELLE girilen üç kolon
            ws.cell(r, c).number_format = "hh:mm"
            ws.cell(r, c).fill = elle
    ws.auto_filter.ref = f"A1:AO{son}"
    return son


# =============================================================================
# DİĞER ÜRETİLEN SAYFALAR
# =============================================================================
def vardiya_yonet_raporu(wb: Workbook, satirlar: list[list]) -> None:
    """Aracın ham çıktısının karşılığı. Ana sayfayla AYNI çekirdekten beslenir."""
    ws = wb.create_sheet("Vardiya Yönet Raporu")
    ws.append(BASLIK_VYR)
    baslik_bicim(ws, len(BASLIK_VYR))
    for i, s in enumerate(satirlar, start=2):
        ek = s[16] if len(s) > 16 else {}
        ws.append([
            s[0], s[1], s[2], s[3], s[4], s[5], ek.get("Tarih"), s[7],
            ek.get("Izin"), ek.get("Baslama"), ek.get("Bitis"),
            s[8], s[9], s[10], s[11],
            ek.get("GirisFark"), ek.get("CikisFark"),
            s[12], s[13], s[14],
            ek.get("KayitSayisi"), ek.get("Mazeret"),
            # W/X — ana sayfadaki R/S ile AYNI SEBEPTEN formül değil: `Personel
            # Çalışma` negatif olabiliyor ("-2:07") ve Excel negatif saat metninde
            # #DEĞER! verir. ÖLÇÜLDÜ: formül bırakılınca 9 satır patladı.
            *eksik_fazla(s[12], s[13]),
        ])
    for r in range(2, len(satirlar) + 2):
        ws.cell(r, 7).number_format = "dd.mm.yyyy"
        for c in (23, 24):
            ws.cell(r, c).number_format = "[h]:mm"
    for c, w in enumerate([13, 13, 9, 24, 18, 22, 11, 14, 8, 13, 12] + [11] * 13,
                          start=1):
        ws.column_dimensions[GL(c)].width = w


def personel_listesi(wb: Workbook, kisiler: list[tuple]) -> int:
    ws = wb.create_sheet("Güncel Personel Listesi")
    ws.append(BASLIK_PERSONEL)
    baslik_bicim(ws, len(BASLIK_PERSONEL))
    for n, k in enumerate(kisiler, start=1):
        (ad, tc, dogum, igt, ict, cins, lok, altlok, altalt, dep, unvan, kadro,
         _firma) = k
        # ⚠ Başlıklar SATICININ adları, değerler İK'nın yeniden amaçlandırdığı
        #   anlamlar (sema `zirve_vw_persdept_tanimi`): SeriNo→Lokasyon,
        #   Grupkodu→AltLokasyon, Ckn→AltAltLokasyon, Meslekilcesi→Departman,
        #   Gorevi→Unvan, A4→Kadro. Kaynak dosyada da böyleydi.
        # "Personel Grubu" (M) view'de YOK → boş bırakılır, uydurulmaz.
        ws.append([n, ad, dogum, tc, igt, cins, lok, altlok, altalt, dep,
                   unvan, dep, None, kadro, "Aktif" if ict is None else "Pasif"])
    for r in range(2, len(kisiler) + 2):
        for c in (3, 5):
            ws.cell(r, c).number_format = "dd.mm.yyyy"
    for c, w in enumerate([6, 26, 13, 14, 13, 10, 18, 18, 18, 18, 24, 18, 14, 13, 9],
                          start=1):
        ws.column_dimensions[GL(c)].width = w
    return len(kisiler)


def mola_saatleri(wb: Workbook, cfg: dict, net_gereken: dict[str, str]) -> None:
    """`Mola Saatleri` — JSON'dan ÜRETİLİR. AN kolonunun (Grup) VLOOKUP tabanı.

    ⚠ Saatler GERÇEK ZAMAN olmalı — metin yazılırsa Excel onu her sayıdan büyük
    sayar ve Eksik/Fazla YER DEĞİŞTİRİR (hata vermeden). 2026-09-15'te ölçüldü.
    """
    ws = wb.create_sheet("Mola Saatleri")
    ws["A1"], ws["B1"], ws["C1"] = "Net Çalışma Saatlerine Göre", "Mola", "Brüt Süre"
    for r, k in enumerate(cfg["mola_net_tablosu"], start=2):
        ws.cell(r, 1, sa(k["net_calisma_alt_sinir"])).number_format = "[h]:mm"
        ws.cell(r, 2, sa(k["mola"])).number_format = "[h]:mm"
        ws.cell(r, 3, "Üstü" if k.get("brut_ustu") else f"=+A{r}+B{r}")
        if not k.get("brut_ustu"):
            ws.cell(r, 3).number_format = "[h]:mm"
    ws["E1"], ws["F1"], ws["G1"] = "Şube", "Çalışma Saat", "Grup"
    for i, k in enumerate(cfg["subeler"], start=2):
        sb = k["sube"]
        ws.cell(i, 5, sb)
        # JSON'da saat verilmemişse vardiya planından ÖLÇÜLEN mod kullanılır.
        ws.cell(i, 6, sa(k.get("calisma_saat")
                         or net_gereken.get(sb, "07:30"))).number_format = "[h]:mm"
        ws.cell(i, 7, k["grup"])
    ws["I1"], ws["J1"] = "Brüt Süre", "Mola"
    for r, k in enumerate(cfg["mola_brut_tablosu"], start=2):
        ws.cell(r, 9, sa(k["brut_sure"])).number_format = "[h]:mm"
        ws.cell(r, 10, sa(k["mola"])).number_format = "[h]:mm"
    for k, w in (("A", 26), ("E", 16), ("F", 14), ("G", 18)):
        ws.column_dimensions[k].width = w


def ozet_y(wb: Workbook, satirlar: list[list], devir: list[list],
           son: int) -> int:
    """Kaynak dosyadaki PivotTable'ın FORMÜLLÜ karşılığı.

    Pivot yerine SUMIFS: T/U'ya yönetici saati girilince pivot yenilemeye gerek
    kalmadan güncellenir (aynı dönüşüm f1887e6'da yapıldı ve mutabakatı ölçüldü).
    """
    ws = wb.create_sheet("Özet Y")
    ws["A1"], ws["B1"] = "Tarih", "(Tümü)"
    ws["A2"], ws["B2"] = "Kart Basma Durum", "(Tümü)"
    ws["A3"], ws["B3"] = "Aktif/Pasif", "(Tümü)"
    ws["H4"] = "Net Saat"
    for c, b in enumerate(["Grup", "Şube", "Bölüm", "Görev", "Personel",
                           "Toplam Eksik Saat", "Toplam Fazla Saat",
                           "Toplam Eksik Saat", "Toplam Fazla Saat"], start=1):
        ws.cell(5, c, b)
    baslik_bicim(ws, 9, satir=5)

    A = "'Vardiya Yönet Program Raporu'!"
    # ⚠ DEVİR SATIRLARI DA KÜMEYE GİRER. Kişi listesi yalnız dönem satırlarından
    # kurulursa, dönemde hiç çalışmamış ama önceki aydan bakiyesi olan kişinin
    # saatleri özetten SESSİZCE düşer. ÖLÇÜLDÜ (31.08–13.09): 19,90 saat eksik +
    # 53,00 saat fazla kayboluyordu; eklendikten sonra ana sayfayla farkı 0.
    # Devir satırının kolon düzeni dönem satırıyla aynı (0 Şube · 3 Personel ·
    # 4 Bölüm · 5 Görev).
    kisiler = sorted({(s[0], s[4], s[5], s[3]) for s in satirlar}
                     | {(d[0], d[4], d[5], d[3]) for d in devir},
                     key=lambda x: (x[0] or "", x[1] or "", x[2] or "", x[3] or ""))
    for i, (sb, bolum, gorev, ad) in enumerate(kisiler, start=6):
        ws.cell(i, 1, f"=IFERROR(VLOOKUP(B{i},'Mola Saatleri'!$E:$G,3,0),\"\")")
        ws.cell(i, 2, sb)
        ws.cell(i, 3, bolum)
        ws.cell(i, 4, gorev)
        ws.cell(i, 5, ad)
        # ⚠ BOŞ BÖLÜM TUZAĞI: `SUMIFS` ölçütü BOŞ bir hücreyi gösterirse Excel onu
        # 0 sayar ve gerçekten boş olan hücrelerle EŞLEŞMEZ → o kişinin saatleri
        # sessizce 0 görünür. ÖLÇÜLDÜ: 21 kişide 19,90 eksik + 53,00 fazla saat
        # kayboluyordu (bölümü olmayan kişiler = plansız kart basanlar).
        # Boş ölçütün Excel'deki karşılığı "=" dizgisidir.
        bolum = f'IF($C{i}="","=",$C{i})'
        for c, hedef in ((6, "$AE"), (7, "$AF")):
            ws.cell(i, c, f"=SUMIFS({A}{hedef}$2:{hedef}${son},"
                          f"{A}$F$2:$F${son},$E{i},{A}$C$2:$C${son},$B{i},"
                          f"{A}$G$2:$G${son},{bolum})").number_format = "[h]:mm"
        ws.cell(i, 8, f"=IF(F{i}>G{i},F{i}-G{i},0)").number_format = "[h]:mm"
        ws.cell(i, 9, f"=IF(G{i}>F{i},G{i}-F{i},0)").number_format = "[h]:mm"
    for c, w in enumerate([18, 16, 22, 26, 26, 16, 16, 16, 16], start=1):
        ws.column_dimensions[GL(c)].width = w
    return len(kisiler)


def haftalik_gun(wb: Workbook, satirlar: list[list], son: int) -> int:
    """Kişi × hafta: çalışılan gün + hafta tatili kullanımı (pivot → formül).

    Kişi anahtarı SicilNo (TC) — isim DEĞİL: adaş kadro tek kişiye yığılır.
    """
    ws = wb.create_sheet("Haftalık Çalışma Gün Sayısı")
    for c, b in enumerate(["Şube", "SicilNo", "Personel", "Hafta",
                           "Çalışılan Gün", "HFT.İZİN Gün",
                           "Hafta Tatili Kullanılmadı", "Eksik Saat", "Fazla Saat"],
                          start=1):
        ws.cell(1, c, b)
    baslik_bicim(ws, 9)
    A = "'Vardiya Yönet Program Raporu'!"
    anahtar = sorted({(s[0], s[1], s[3], s[16]["Tarih"].isocalendar()[1])
                      for s in satirlar},
                     key=lambda x: (x[0] or "", x[2] or "", x[3]))
    for i, (sb, sicil, ad, hf) in enumerate(anahtar, start=2):
        ws.cell(i, 1, sb)
        ws.cell(i, 2, sicil)
        ws.cell(i, 3, ad)
        ws.cell(i, 4, hf)
        # ⚠ BOŞ SİCİL TUZAĞI — Özet Y'deki boş bölüm tuzağının ikizi. PDKS'te TC'si
        # olmayan kişinin SicilNo'su boştur; `SUMIFS` boş ölçüt hücresini 0 sayar ve
        # boş hücrelerle eşleşmez → o satırlar sessizce sayılmaz. ÖLÇÜLDÜ
        # (31.08–16.09): 0,31 saat fazla mesai kayboluyordu.
        sicil = f'IF($B{i}="","=",$B{i})'
        ws.cell(i, 5, f"=SUMIFS({A}$AG$2:$AG${son},{A}$D$2:$D${son},{sicil},"
                      f"{A}$AH$2:$AH${son},$D{i})")
        ws.cell(i, 6, f"=COUNTIFS({A}$D$2:$D${son},{sicil},"
                      f"{A}$AH$2:$AH${son},$D{i},{A}$J$2:$J${son},\"HFT.İZİN\")")
        ws.cell(i, 7, f"=IF(AND(F{i}=0,E{i}>=7),1,0)")
        for c, hedef in ((8, "$AE"), (9, "$AF")):
            ws.cell(i, c, f"=SUMIFS({A}{hedef}$2:{hedef}${son},"
                          f"{A}$D$2:$D${son},{sicil},"
                          f"{A}$AH$2:$AH${son},$D{i})").number_format = "[h]:mm"
    for c, w in enumerate([13, 13, 26, 8, 13, 13, 22, 12, 12], start=1):
        ws.column_dimensions[GL(c)].width = w
    return len(anahtar)


# =============================================================================
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bas", default="31.08.2026")
    ap.add_argument("--bit", default="13.09.2026")
    ap.add_argument("--kaynak", default=os.path.join(
        VARDIYA_DIZIN, "BKMKİTAP Eksik ve Fazla Takip Raporu.xlsx"),
        help="Elle girilen VERİ sayfalarının (geri dönüşler, devir) kopyalanacağı dosya")
    ap.add_argument("--parametre", default=PARAMETRE_YOLU,
                    help="Parametre/tanım tablolarının JSON dosyası")
    ap.add_argument("--sayim-bas", default=None,
                    help="Eksik/Fazla toplamına giren İLK gün (varsayılan --bas). "
                         "Öncesindeki günler raporda durur ama toplama katılmaz — "
                         "önceki ayın devrinde sayıldıkları için.")
    ap.add_argument("--cikti", default=None)
    ap.add_argument("--sql-yaz", action="store_true",
                    help="Hesaplanan kişi-günü ve devri DEV SQL tablolarına da yaz "
                         "(bkm.Vrd_KisiGun / bkm.Vrd_Devir). Excel yine üretilir.")
    ap.add_argument("--devir-tazele", action="store_true",
                    help="Dondurulmuş devir kaydının ÜZERİNE yaz (varsayılan: yazmaz).")
    a = ap.parse_args()

    bas = dt.datetime.strptime(a.bas, "%d.%m.%Y").date()
    bit = dt.datetime.strptime(a.bit, "%d.%m.%Y").date()
    sayim_bas = (dt.datetime.strptime(a.sayim_bas, "%d.%m.%Y").date()
                 if a.sayim_bas else bas)
    if sayim_bas < bas:
        sys.exit("KOŞAMADI: --sayim-bas, --bas'tan önce olamaz.")
    print(f"KAPSAM: {bas:%d.%m.%Y} – {bit:%d.%m.%Y}"
          + (f" · SAYIM {sayim_bas:%d.%m.%Y}'den itibaren "
             f"(öncesi devirde sayılı)" if sayim_bas != bas else ""))

    cfg = parametre_oku(a.parametre)
    print(f"Parametre: {os.path.relpath(a.parametre, KOK)} — "
          f"şube {len(cfg['subeler'])} · çalışma saati {len(cfg['calisma_saatleri'])} · "
          f"kart basmayan {len(cfg['kart_basmayan_gruplar'])}")

    if not os.path.exists(a.kaynak):
        sys.exit(f"KOŞAMADI: elle girilen veri sayfaları için kaynak dosya yok: "
                 f"{a.kaynak}")
    kaynak_wb = load_workbook(a.kaynak)
    for ad in KOPYALANAN:
        if ad not in kaynak_wb.sheetnames:
            sys.exit(f"KOŞAMADI: kaynak dosyada '{ad}' sayfası yok.")

    env = cekirdek.env_oku(os.path.join(KOK, ".env"))

    # ── 1. ERP/PDKS: vardiya planı + kart okutma ──────────────────────────
    cn = cekirdek.baglan(env)
    try:
        cur = cn.cursor()
        print("  Olması gereken net çalışma (plandan ÖLÇÜLDÜ):")
        net_gereken = cekirdek.net_gereken_olc(cur, bas, bit)
        cur.close()
        satirlar: list[list] = []
        for sb in sorted(net_gereken):
            print(f"-- {sb} --")
            satirlar += cekirdek.veri_cek(cn, sb, bas, bit, genis=True)
    finally:
        cn.close()
    satirlar.sort(key=lambda s: (str(s[0] or ""), s[16]["Tarih"], str(s[3] or "")))
    print(f"TOPLAM kişi-gün: {len(satirlar)} · {len(net_gereken)} şube")

    # ── Bölüm/Görev tamamlama ────────────────────────────────────────────
    # Plana işlenmemiş ama kart basmış satırlarda Bölüm/Görev BOŞ gelir (bilgi
    # plandan okunuyor, o kişinin o gün planı yok). Aynı kişinin BAŞKA GÜNKÜ plan
    # satırı bu bilgiyi taşıyor — oradan doldurulur. Uydurma değil, aynı kişinin
    # kendi kaydı. ÖLÇÜLDÜ: kaynak dosyayla 119 satırlık Bölüm/Görev farkının
    # sebebi buydu. Kalan boşluk SESSİZ GEÇİLMEZ, sayılır.
    kimlik = {}
    for s in satirlar:
        if s[4] or s[5]:
            kimlik.setdefault(s[1], (s[4], s[5]))
    plandan = 0
    for s in satirlar:
        if s[4] is None and s[5] is None and s[1] in kimlik:
            s[4], s[5] = kimlik[s[1]]
            plandan += 1

    # ── 2. Zirve: güncel personel ─────────────────────────────────────────
    zcn = zirve_baglan(env)
    try:
        zc = zcn.cursor()
        zc.execute(SQL_PERSONEL, bit, bas)
        kisiler = [tuple(r) for r in zc.fetchall()]
        zc.close()
    finally:
        zcn.close()
    if not kisiler:
        sys.exit("KOŞAMADI: Zirve personel listesi BOŞ döndü. Boş nüfus 'kimse yok' "
                 "demek değildir — bağlantı/şart kontrol edilmeli.")
    # AM kolonu TC ile eşliyor → liste TC'de TEKİL olmalı, yoksa VLOOKUP ilk
    # satırı alır ve hangisi olduğu rastgeleye kalır.
    # ⚠ Zirve'de `Personelno` çalışma DÖNEMİ kimliğidir (1.296 numara ↔ 1.162 TC):
    # yeniden işe girenin İKİ kaydı vardır. Kişi anahtarı `Vatno` (sema
    # `zirve_as_of_kadro_sarti`). Aynı TC'den hangi kayıt seçilir:
    #   1) hâlâ çalışan (Ict IS NULL)  2) yoksa işe giriş tarihi EN YENİ olan
    # Tahmin değil, sıralama kuralı — "ilk gelen" rastgeleliği kaldırıldı.
    en_iyi: dict[str, tuple] = {}
    tcsiz = 0
    for k in kisiler:
        tc = str(k[1] or "").strip()
        if not tc:
            tcsiz += 1
            continue
        onceki = en_iyi.get(tc)
        skor = (k[4] is None, k[3] or dt.date.min)      # (çalışıyor mu, Igt)
        if onceki is None or skor > onceki[0]:
            en_iyi[tc] = (skor, k)
    tekil = [v[1] for v in en_iyi.values()]
    tekil.sort(key=lambda k: str(k[0] or ""))
    print(f"Zirve personel: {len(kisiler)} kayıt → {len(tekil)} tekil TC "
          f"({len(kisiler) - len(tekil) - tcsiz} mükerrer TC birleştirildi"
          f"{f' · {tcsiz} kayıtta TC YOK, listeye alınmadı' if tcsiz else ''})")
    adas = len(kisiler) - len({str(k[0] or "") for k in kisiler})
    if adas:
        print(f"  (bilgi: listede {adas} adaş var — eşleşme TC ile olduğu için "
              f"sorun değil)")

    # Bölüm/Görev'i plandan dolduramayanlar için İKİNCİ kaynak: Zirve.
    # Eşleşme TC (Vatno ↔ SicilNo) ile — isimle DEĞİL (adaş riski).
    # ⚠ Zirve'nin `Departman`ı plandaki `Bölüm` ile aynı sözlüğü kullanmayabilir
    # (KAFELER'de Departman üç kaba değer taşır, ayrım Unvan'dadır — sema
    # `zirve_ik_organizasyon_ve_kafeler_istisnasi`). Bu yüzden kaynak AYRI
    # sayılır ve ekrana ayrı yazılır; plan kaydı varsa O tercih edilir.
    zirve_kimlik = {str(k[1]).strip(): (k[9], k[10]) for k in kisiler if k[1]}
    zirveden = 0
    for s in satirlar:
        if s[4] is None and s[5] is None and str(s[1]).strip() in zirve_kimlik:
            s[4], s[5] = zirve_kimlik[str(s[1]).strip()]
            zirveden += 1
    kalan = sum(1 for s in satirlar if s[4] is None and s[5] is None)
    print(f"Bölüm/Görev tamamlama: plandan {plandan} · Zirve'den {zirveden}"
          f"{f' · {kalan} satır HÂLÂ BOŞ' if kalan else ' · boş kalmadı'}")

    # ── 3. Devir sayfası (önceki ayın kapanışı) ───────────────────────────
    devir_ad = next((n for n in kaynak_wb.sheetnames if "Devir" in n), None)
    devir: list[list] = []
    if devir_ad:
        d = kaynak_wb[devir_ad]
        for r in range(2, d.max_row + 1):
            if d.cell(r, 1).value is None:
                continue
            devir.append([d.cell(r, c).value for c in range(1, 10)])
        print(f"Devir satırı: {len(devir)} ({devir_ad})")
    else:
        print("⚠ Devir sayfası kaynak dosyada YOK — devir satırı eklenmedi.")

    # ── 4. Çalışma kitabı ─────────────────────────────────────────────────
    wb = Workbook()
    wb.remove(wb.active)
    if devir_ad:
        sayfa_kopyala(wb, kaynak_wb, devir_ad)
    for ad in KOPYALANAN:
        n = sayfa_kopyala(wb, kaynak_wb, ad)
        print(f"  kopyalandı: {ad} ({n} satır)")
    personel_listesi(wb, tekil)
    kart_basmayan_sayfa(wb, cfg)

    grup_haritasi = {s["sube"]: s["grup"] for s in cfg["subeler"]}
    eksik_grup = [s for s in net_gereken if s not in grup_haritasi]
    if eksik_grup:
        # Grup eşlemesi olmayan şube → AN #YOK → A anahtarı bozulur → AD/AI çöker.
        # Sessiz geçilmez: parametre dosyası eksik demektir.
        sys.exit(f"KOŞAMADI: parametre dosyasında grubu tanımlı OLMAYAN şube: "
                 f"{eksik_grup}. config 'subeler' bloğuna eklenmeli.")
    mola_saatleri(wb, cfg, net_gereken)

    eklenen = calisma_saatleri_tamamla(cfg, satirlar, net_gereken, grup_haritasi)
    calisma_saatleri_sayfa(wb, cfg)
    if eklenen:
        parametre_yaz(cfg, a.parametre)
        print(f"⚠ Parametre dosyasına {len(eklenen)} 'çalışma saati' kaydı OTOMATİK "
              f"eklendi (şube varsayılanı, 'not' alanında damgalı — İK gerçek saati "
              f"yazmalı). Dosya güncellendi: {os.path.relpath(a.parametre, KOK)}")
        for e in eklenen:
            print(f"     · {e}")

    # Eşleşme TC ile. Eşleşmeyen = kart basmış ama Zirve'de o dönemde kaydı olmayan
    # kişi → kolonda "Zirve'de yok" yazar. SESSİZ KALMAZ, isimleri yazılır.
    # ⚠ Bunların bilinen bir kısmı KARDEŞ FİRMA kadrosudur (bkz. SQL_PERSONEL
    #   yanındaki not): `BKM_2_GENEL` bordrosu view'a dahil değil ve okunamıyor.
    #   GMY kararı: peşine düşülmeyecek. "Pasif" YAZILMAZ — kişi çalışıyor;
    #   ölçemediğimizi yazmak doğru, işten ayrılmış göstermek yanlış iddia olurdu.
    tcler = {str(k[1] or "").strip() for k in tekil}
    eslesmeyen = sorted({(s[3], str(s[1] or "").strip()) for s in satirlar
                         if str(s[1] or "").strip() not in tcler})
    if eslesmeyen:
        print(f"⚠ Kart basmış ama Zirve'de bu dönemde kaydı YOK: {len(eslesmeyen)} kişi "
              f"→ 'Aktif/Pasif' kolonunda \"Zirve'de yok\" yazacak "
              f"(bir kısmı kardeş firma kadrosu):")
        for ad, tc in eslesmeyen:
            print(f"     · {ad}  (TC {tc or 'YOK'})")

    son = ana_sayfa(wb, satirlar, devir, cfg["izin_etiketleri"], sayim_bas)
    vardiya_yonet_raporu(wb, satirlar)
    n_ozet = ozet_y(wb, satirlar, devir, son)
    n_hafta = haftalik_gun(wb, satirlar, son)

    sira = [devir_ad, "Mağaza Geri Dönüşleri", "Kart Basmayan Gruplar",
            "Güncel Personel Listesi", "Özet Y", "Çalışma Saatleri",
            "Vardiya Yönet Program Raporu", "Vardiya Yönet Raporu",
            "Haftalık Çalışma Gün Sayısı", "Mola Saatleri"]
    wb._sheets = [wb[n] for n in sira if n and n in wb.sheetnames]

    cikti = a.cikti or os.path.join(
        VARDIYA_DIZIN,
        f"BKMKİTAP Eksik ve Fazla Takip Raporu - {bit:%d.%m.%Y}.xlsx")
    os.makedirs(os.path.dirname(cikti), exist_ok=True)
    wb.save(cikti)
    if a.sql_yaz:
        # Excel emitter'ı DEĞİŞMEZ; tablo İKİNCİ çıktıdır (emitter-ayrimi: tek
        # hesap çekirdeği, çok çıktı — hesap burada TEKRARLANMAZ).
        import vardiya_sql                                   # noqa: E402
        print("")
        print("SQL (DEV):")
        vardiya_sql.kisi_gun_yaz(satirlar, bas, bit, sayim_bas)
        if devir and devir_ad:
            aylar = {"Ocak": "01", "Şubat": "02", "Mart": "03", "Nisan": "04",
                     "Mayıs": "05", "Haziran": "06", "Temmuz": "07",
                     "Ağustos": "08", "Eylül": "09", "Ekim": "10",
                     "Kasım": "11", "Aralık": "12"}
            m = re.match(r"([A-Za-zÇĞİÖŞÜçğıöşü]+)[.](\d{4})", devir_ad)
            if m and m.group(1) in aylar:
                vardiya_sql.devir_yaz(devir, m.group(2) + "-" + aylar[m.group(1)],
                                      a.devir_tazele)
            else:
                # Sessiz atlanmaz: hangi devrin YAZILMADIĞI yazılır.
                print("  ⚠ Devir dönemi '" + str(devir_ad) +
                      "' adından ÇÖZÜLEMEDİ — yazılmadı.")

    print(f"\nÖzet Y satır: {n_ozet} · Haftalık satır: {n_hafta} · "
          f"ana sayfa son satır: {son}")
    print(f"YAZILDI: {cikti}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
