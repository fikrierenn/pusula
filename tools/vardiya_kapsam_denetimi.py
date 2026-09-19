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
  YÜKSELTME YOLU : ✅ YAPILDI (V-10) — `BannedApiAnalyzers` Dapper çağrısını `VrdSql`
                   dışında DERLENMEZ yapıyor. Bu kapı artık onun da AYAKTA olduğunu
                   denetler: yasak listesi silinir ya da sembol adı yanlış yazılırsa
                   ban SESSİZCE ölür (ölçüldü 19.09: yanlış sembol adıyla derleme
                   GEÇTİ, hiçbir uyarı çıkmadı)

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
# ⚠ PLAN 49 (V-05): duzeltilmis VIEW listeye girdi — kisi-gun verisi donduruyor,
#   yani kapsam tasir. `Vrd_PlanDuzeltme` ise GIRMEDI ve bu bir OLCUMLE duzeltildi:
#   once "ne olur ne olmaz" diye eklenmisti, kapi da yazma yolunu KIRIK verdi.
#   Dogrusu `Vrd_Onay` ile ayni sinif — tablo kapsam TASIMAZ, kimligi SicilNo+Tarih'tir
#   ve kapsami ona `PersonDays` uzerinden yazilan muhafiz baglar. Kapsamli saymak,
#   kapsamsiz bir tabloya kapsam suzgeci arattirirdi: kapi yesil kalmak icin anlamsiz
#   bir suzgec yazmaya zorlardi.
KAPSAMLI_TABLOLAR = ["bkm.Vrd_KisiGun", "bkm.Vrd_Devir", "bkm.Vrd_KisiGunDuzeltilmis_vw"]

# URETIM KOKLERI ARTIK KESFEDILIYOR, ELLE YAZILMIYOR (19.09, Solum'un uyarisi).
#
# ⚠ ONCEKI HALI BIR FOTOGRAFTI: `["lib/Bkm.Shared", "vardiya-app", "dashboard"]`.
#   O liste yazildigi gun dogruydu; DORDUNCU bir uygulama vardiya tablosuna
#   dokunmaya baslasa kapi onu HIC TARAMAZDI ve sessizce yesil kalirdi.
#   Solum'un ayni gun yasadigi vaka: bir plan "sifir tuketici bu metodu eziyor"
#   diye olcmus, o gun IKI tuketici varmis, bugun UC — olcum bayatlamis.
#   Sinif: "giris kosulu bir kez olculurse KOSUL DEGIL FOTOGRAFTIR" ve bunun
#   NUFUS tarafi ("nufus buyur mu") hic sorulmamisti.
#
# ⚠ BUGUN OLCULDU: taranmayan projelerin (asistan · muhasebe · dashboardv2 ·
#   RaporApp · SsmsExcelExporter · diskscan) HICBIRI vardiya tablosuna ya da panel
#   veritabanina dokunmuyor. Yani RISK YOK degil, NUFUS YOK — ve nufus buyudugu an
#   kapi artik kendiliginden gorur.
#
# `tests/` BILEREK DISARIDA: test kapsamsiz nufusu olcmek ZORUNDADIR (olcemezse
# sizintinin varligini da yoklugunu da kanitlayamaz). Muafiyet bir bosluk degil,
# testin ISIDIR — ve yalniz burada yazili oldugu icin gorunurdur.
TEST_KOKU = "tests"


def uretim_koklerini_kesfet() -> list[str]:
    """Depodaki her .csproj dizini bir uretim kokudur (tests/ haric)."""
    kokler = set()
    for proj in KOK.rglob("*.csproj"):
        if any(p in ("bin", "obj", "node_modules", ".claude") for p in proj.parts):
            continue
        rel = proj.parent.relative_to(KOK).as_posix()
        if rel == TEST_KOKU or rel.startswith(TEST_KOKU + "/"):
            continue
        kokler.add(rel)
    return sorted(kokler)


URETIM_KOKLERI = uretim_koklerini_kesfet()

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

if not URETIM_KOKLERI:
    print("KOŞAMADI  hiç üretim projesi bulunamadı — keşif boş döndü, bu kapı "
          "hiçbir dosya taramıyor demektir (yeşil DEĞİL)")
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
    print(f"OK    boğaz tekeli ({taranan} üretim dosyası / {len(URETIM_KOKLERI)} proje "
          f"tarandı, kapsamlı tabloya erişen tek yer VrdSql.cs)")

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

# ── 4. YASAK LİSTESİ AYAKTA MI (V-10'un sessiz ölümü) ────────────────────────
# ÖLÇÜLDÜ (19.09.2026): `BannedSymbols.txt` içindeki sembol adı YANLIŞ yazılırsa
# analizör hiçbir şey demez — ban ölür, derleme geçer, kimse fark etmez. Dosyanın
# silinmesi de aynı sonucu verir. Yani V-10 bir kapıdır ve onun da bir kapısı gerekir.
# V-11'den beri IKI liste var: kapsamli sorgular (lib) ve kimlik/ACL (vardiya-app).
YASAK_LISTELERI = ["lib/Bkm.Shared/BannedSymbols.txt", "vardiya-app/BannedSymbols.txt"]
BEKLENEN_GIRDI = "T:Dapper.SqlMapper;"

for rel in YASAK_LISTELERI:
    yol = KOK / rel
    if not yol.exists():
        kirik.append(f"yasak-listesi-yok:{rel}")
        print(f"KIRIK yasak listesi YOK: {rel} — ban ölmüş, Dapper çağrısı boğaz "
              f"dışında yeniden DERLENİR.")
        continue
    liste = io.open(yol, encoding="utf-8").read()
    if BEKLENEN_GIRDI not in liste:
        kirik.append(f"yasak-listesi-bozuk:{rel}")
        print(f"KIRIK {rel}: `{BEKLENEN_GIRDI}` girdisi YOK — sembol adı değişmiş ya da "
              f"silinmiş olabilir; ban SESSİZCE ölür (analizör uyarmaz).")
        continue
    # Yorum satırı tuzağı: aynı satır iki kez -> RS0031; farklı satırlar ->
    # SESSİZCE yok sayılır ve dosya "açıklamalı" görünür (ölçüldü).
    yorumlu = [l for l in liste.splitlines() if l.strip() and ";" not in l]
    if yorumlu:
        kirik.append(f"yasak-listesi-yorum:{rel}")
        print(f"KIRIK {rel}: girdi olmayan {len(yorumlu)} satır var — bu dosya yorum "
              f"TANIMAZ; gerekçe `.editorconfig`e yazılır.")
    else:
        print(f"OK    yasak listesi ayakta: {rel}")

# ⚠ BU DENETIM METINDIR ve sembolun GERCEK bir tipe cozuldugunu GORMEZ. Onu
#   `tests/BkmVardiya.Tests/BanListLivenessTests.cs` yansimayla olcuyor (Solum'un
#   ayni gun odeyerek ogrendigi ders). Ikisi ayri katman: bu ucuz ve pre-commit'te,
#   oteki kesin ve test kosumunda.

# ── 5. PANEL SALT-OKUMA (plan 48 Adım 7, GMY kararı 19.09) ───────────────────
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
