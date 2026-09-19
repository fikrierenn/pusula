#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ŞUBE KAPSAMI KAPISI — boğaz tekeli + parametre çapası + panel salt-okuma.

NEDEN VAR (19.09.2026, DÖRT ölçülmüş sızıntı — dördünde de derleme temizdi):
  1. Kapsam sekiz sorguya ELLE eklendi, biri atlandı (`GetStayBandsAsync`).
  2. Kapsam vardı ama DEVİR ALT-SORGUSUNDA yoktu: müdür kendi döneminin 334
     saatini, tüm şirketin 1.858 saatlik devrini görüyordu. Ekranda MAKUL duruyordu.
  3. SQL `@sube` isterken C# `branch` gönderiyordu — üç sorgu çalışma anında
     patlıyordu. Kapının ilk hâli bunu göremezdi: "süzgeç VAR MI" diye soruyordu,
     "süzgeç ÇALIŞIYOR MU" diye değil.
  4. Aynı sınıf `SaveApprovalAsync`'te: SQL `@girisDk/@cikisDk/@ekMesaiDk/@kaydeden`,
     C# `inMin/outMin/extraShiftMin/savedBy` — onay YAZMA yolu hiç çalışmıyordu.

V-09'dan sonra kapı METİN SAYMIYOR, YAPIYI koruyor. Yapı (`VrdSql`) süzgeci
kaynağın içine koydu; bu kapı o yapının ATLATILMADIĞINI denetler.

YAKALAMA SÖZLEŞMESİ
  YAKALAR        : kapsamlı tabloyu boğaz dışında SQL'de kullanmak · boğazı atlayıp
                   doğrudan Dapper çağırmak · `userId` alıp boğazı hiç kullanmamak ·
                   panele yazma yolu geri koymak
  YAKALAMAZ      : boğazın İÇİNDEKİ süzgecin yanlış kolona bağlanması
                   (`Sube IN` yerine `Bolum IN`) — orası TEK yer olduğu için
                   uçtan uca test (`tests/BkmVardiya.Tests`) ile korunuyor
  BİLİNEN ATLATMA: yeni bir dosyada yeni bir bağlantı açıp ham SQL yazmak —
                   TARANAN KÖKLER listesi genişletilmezse görünmez
  YÜKSELTME YOLU : `BannedApiAnalyzers` ile Dapper çağrısını `VrdSql` dışında
                   DERLENMEZ yapmak (boğaz kurulduğu için artık ön koşulu var)

Çıkış: 0 geçti · 1 KIRIK · 2 KOŞAMADI
"""
from __future__ import annotations
import io, re, sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

KOK = Path(__file__).resolve().parent.parent
BOGAZ = KOK / "lib/Bkm.Shared/Data/VrdSql.cs"
SORGULAR = KOK / "lib/Bkm.Shared/Data/VardiyaQueries.cs"
PANEL_SAYFA = KOK / "dashboard/Components/Pages/Vardiya.razor"

# Kapsam suzgeci istemesi ZORUNLU tablolar — bunlara erisim yalniz bogazdan.
KAPSAMLI_TABLOLAR = ["bkm.Vrd_KisiGun", "bkm.Vrd_Devir"]

# URETIM kokleri. `tests/` BILEREK DISARIDA: test kapsamsiz nufusu olcmek
# ZORUNDADIR (olcemezse sizintinin varligini da yoklugunu da kanitlayamaz).
# Muafiyet bir bosluk degil, testin ISIDIR — ve yalniz burada yazili oldugu icin
# gorunurdur.
URETIM_KOKLERI = ["lib/Bkm.Shared", "vardiya-app", "dashboard"]

kirik: list[str] = []


def sql_baglami(metin: str) -> str:
    """Yorum ve HTML/Razor metnini eler; geriye SQL benzeri gövde kalır.

    ⚠ Bu eleme kapının KENDİ KÖR NOKTASI olabilir — 19.09'da Türkçe tanımlayıcı
      kapısında tam bu oldu: `//.*$` deseni `re.S` ile birlikte ilk yorumdan
      dosya sonuna kadar her şeyi siliyordu ve kapı HİÇBİR ŞEY denetlemeden
      yeşil veriyordu. O yüzden desen satır-sonu ile sınırlı (`[^\\n]*`).
    """
    metin = re.sub(r"//[^\n]*", " ", metin)
    metin = re.sub(r"/\*.*?\*/", " ", metin, flags=re.S)
    metin = re.sub(r"<code>.*?</code>", " ", metin, flags=re.S)
    metin = re.sub(r"<b>.*?</b>", " ", metin, flags=re.S)
    return metin


def sql_kullanimi(metin: str, tablo: str) -> list[str]:
    """Tabloyu SQL olarak KULLANAN yerler (düz metinde geçmesi değil)."""
    desen = re.compile(
        r"\b(FROM|JOIN|INTO|UPDATE|MERGE|DELETE\s+FROM)\s+" + re.escape(tablo) + r"\b",
        re.I)
    return [m.group(0) for m in desen.finditer(metin)]


# ── 1. BOĞAZ TEKELİ ───────────────────────────────────────────────────────────
if not BOGAZ.exists():
    print(f"KOŞAMADI  boğaz dosyası yok: {BOGAZ}")
    sys.exit(2)

bogaz_metni = sql_baglami(io.open(BOGAZ, encoding="utf-8").read())
bogazda = sum(len(sql_kullanimi(bogaz_metni, t)) for t in KAPSAMLI_TABLOLAR)
if bogazda == 0:
    print("KOŞAMADI  boğazın kendisinde kapsamlı tablo kullanımı YOK — "
          "VrdSql.PersonDays/Carryover boşalmış olabilir; bu kapı hiçbir şey ölçemez")
    sys.exit(2)

taranan, disarida = 0, []
for kok in URETIM_KOKLERI:
    for yol in sorted((KOK / kok).rglob("*")):
        if yol.suffix.lower() not in (".cs", ".cshtml", ".razor"):
            continue
        if any(p in ("bin", "obj") for p in yol.parts):
            continue
        if yol == BOGAZ:
            continue
        taranan += 1
        govde = sql_baglami(io.open(yol, encoding="utf-8", errors="replace").read())
        for t in KAPSAMLI_TABLOLAR:
            for kullanim in sql_kullanimi(govde, t):
                disarida.append((yol.relative_to(KOK).as_posix(), kullanim.strip()))

if disarida:
    kirik.append("bogaz-tekeli")
    for yol, kullanim in disarida:
        print(f"KIRIK boğaz DIŞI kapsamlı tablo kullanımı: {yol} → `{kullanim}` "
              f"— süzgeç unutulabilir hâle geldi. VrdSql.PersonDays/Carryover kullan.")
else:
    print(f"OK    boğaz tekeli ({taranan} üretim dosyası tarandı, "
          f"kapsamlı tabloya erişen tek yer VrdSql.cs)")

# ── 2. BOĞAZ ATLANMIYOR MU (doğrudan Dapper) ─────────────────────────────────
if not SORGULAR.exists():
    print(f"KOŞAMADI  kaynak yok: {SORGULAR}")
    sys.exit(2)

sorgu_metni = io.open(SORGULAR, encoding="utf-8").read()
dogrudan = re.findall(r"\bcn\.(Query\w*|Execute\w*)Async\b", sql_baglami(sorgu_metni))
if dogrudan:
    kirik.append("bogaz-atlandi")
    print(f"KIRIK VardiyaQueries'te boğazı atlayan {len(dogrudan)} doğrudan Dapper "
          f"çağrısı: {', '.join(sorted(set(dogrudan)))} — parametre adı doğrulaması "
          f"ve kapsam kaynağı devre dışı kalır.")
else:
    print("OK    boğaz atlanmıyor (VardiyaQueries'te doğrudan Dapper çağrısı yok)")

# ── 3. KAPSAM ÇAPASI — `userId` alan her metot boğazdan geçiyor mu ───────────
basliklar = list(re.finditer(r"public\s+async\s+Task[^(]*?(\w+Async)\s*\(", sorgu_metni))
if not basliklar:
    print("KOŞAMADI  hiç metot bulunamadı — sözdizimi değişmiş olabilir")
    sys.exit(2)

denetlenen = 0
for i, m in enumerate(basliklar):
    ad = m.group(1)
    son = basliklar[i + 1].start() if i + 1 < len(basliklar) else len(sorgu_metni)
    govde = sorgu_metni[m.start():son]

    if "string userId" not in govde:
        continue
    denetlenen += 1

    if "VrdParams.For(userId)" not in govde:
        kirik.append(ad)
        print(f"KIRIK {ad}: `userId` alıyor ama VrdParams.For(userId) YOK — "
              f"kapsam çapası kurulmamış, sorgu kapsam DIŞINI döndürebilir.")
    else:
        print(f"OK    {ad}")

if denetlenen == 0:
    print("KOŞAMADI  `userId` alan hiçbir metot bulunamadı — imza değişmiş olabilir")
    sys.exit(2)

# ── 4. PANEL SALT-OKUMA (plan 48 Adım 7, GMY kararı 19.09) ───────────────────
# GMY panelinde vardiya sayfası SALT-OKUMA özettir. Yazma yolu oraya geri
# konulursa ÜÇ kapı birden atlanmış olur: rol yetkisi · şube kapsamı · denetim izi.
YASAK = ["SaveApprovalAsync", "OnayKaydet"]
if PANEL_SAYFA.exists():
    panel = io.open(PANEL_SAYFA, encoding="utf-8").read()
    bulunan = [y for y in YASAK if y in panel]
    if bulunan:
        kirik.append("panel-yazma")
        print(f"KIRIK panel SALT-OKUMA olmalı ama yazma yolu var: {', '.join(bulunan)} "
              f"→ rol yetkisi + şube kapsamı + denetim izi ATLANIR.")
    else:
        print("OK    panel salt-okuma (dashboard/Vardiya.razor'da yazma yolu yok)")
else:
    print("KOŞAMADI  panel sayfası bulunamadı — taşındıysa bu denetim güncellenmeli")
    sys.exit(2)

print()
if kirik:
    print(f"KIRIK · {len(kirik)} bulgu")
    sys.exit(1)
print(f"Denetim geçti · boğaz tekeli + {denetlenen} sorguda kapsam çapası + panel salt-okuma")
