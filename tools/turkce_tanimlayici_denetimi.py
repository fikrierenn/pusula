#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TÜRKÇE TANIMLAYICI KAPISI — kod İngilizce, UI Türkçe (`turkish-ui.md`).

═══ YAKALAMA SÖZLEŞMESİ ═══════════════════════════════════════════════════════
YAKALAR:
  • C#/Razor kodunda TANIMLAYICI konumunda Türkçe kelime: sınıf, metot, property,
    alan, yerel değişken, parametre adları (`Sube`, `MudurAdi`, `KisiGunOku`…).
  • Türkçe karakter taşıyan tanımlayıcı (`Ölçüm`, `Şube`).
  • Türkçe dosya adı (`SubeKapsamiTests.cs`).

YAKALAMAZ:
  • YORUMLAR ve DİZELER — onlar Türkçe OLMALI (UI metni, hata mesajı, açıklama).
    Satırdan çıkarılır.
  • SQL metinlerindeki kolon adları (dize içinde, yukarıdaki sebeple elenir).
  • Listede olmayan Türkçe kelime. Liste elle yazılmıştır ve EKSİKTİR —
    `olctum-mu-cikardim-mi.md` § "liste elle yazılmaz" ihlali, bilerek: kelime
    kümesini veriden türetmenin yolu yok. Yeni ihlal görülünce listeye eklenir.
  • Domain adları: `Vardiya`, `Bkm`, `Vrd` (ürün/şirket adı, çevrilmez).

BİLİNEN ATLATMA:
  • Kelimeyi listede olmayan bir Türkçe kelimeyle yazmak (`Magaza` yerine `Dukkan`).
  • Türkçe kelimeyi kısaltmak (`Sb` = şube).

YÜKSELTME YOLU:
  ✅ YAPILDI (V-19, 19.09): kara listenin YANINA ak liste kondu
    (`tools/kod-sozcukleri.txt`, 236 sözcük). Bildirilen her adın her sözcüğü
    dağarcıkta olmak zorunda; olmayan sözcük KIRIK verir ve iki seçenek sunar —
    İngilizceyse dosyaya BİR SATIR ekle, Türkçeyse ÇEVİR.
  ⚠ AK LİSTE KURULURKEN İKİ KAÇAK BULDU: `LikeKacir` ve `CalistirAsync` aylardır
    koddaydı; kara listede o kelimeler olmadığı için kapı onları HİÇ görmemişti
    (`EscapeLike` / `RunAsync` yapıldı). Yani "kara listenin eksikliği görünmez"
    bir teori değil, bu depoda ÖLÇÜLMÜŞ bir olgudur.

KAPININ ÜÇ KATMANI (Solum'un ayrımı + V-19):
  • Türkçe HARF taraması (`ıİşŞğĞüÜöÖçÇ`) — kapalı küme, kaçış YOK.
  • ASCII'ye çevrilmiş Türkçe KELİME listesi — kara liste; hızlı ve açık mesaj
    verir ama eksikliği GÖRÜNMEZ, tek başına GÜVENCE DEĞİLDİR.
  • AK LİSTE (V-19) — bildirilen adlardaki her sözcük dağarcıkta mı? Eksikliği
    İNSANA SORAR: yanlış pozitifin bedeli bir satır, yanlış negatifin bedeli
    görünmeyen bir ihlal.
  ⚠ KÖR NOKTA KAPANDI (19.09): `.razor` uzantısı ne süpürmede vardı ne de
    razor sayılıyordu. Dashboard'ın 61 UI dosyası HİÇ bakılmamıştı; elle
    verilse C# gibi işlenip UI metnine Türkçe-harf taraması uygulanırdı.
    "dashboard taranıyor" cümlesi doğruydu, KAPSAMI yanlıştı — uzantı listesi
    bir yerden türetilmiyordu, elle yazılmıştı.
  ⚠ Ak liste dosyası okunamazsa kapı KOŞAMADI der — sessizce kara listeye düşmek
    YASAK, çünkü o hâlde kapı çalışıyor GÖRÜNÜR.
═══════════════════════════════════════════════════════════════════════════════

NEDEN VAR: 19.09.2026 oturumunda GMY **dört kez** aynı şeyi söylemek zorunda
kaldı ("hâlâ Türkçe isim kullanıyorsun"). Kural yazılıydı ve okunmuştu; çiğneyeni
gören yoktu. `test-discipline.md` § yazılı kural ≠ uygulanan kural.

Kullanım:
    python tools/turkce_tanimlayici_denetimi.py [dosya ...]
    (dosya verilmezse KAPSAM listesi taranır)

Çıkış: 0 geçti · 1 KIRIK · 2 KOŞAMADI
"""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

KOK = Path(__file__).resolve().parent.parent

# Yeni yazılan kod. Eski dashboard/scripts kapsam DIŞI — oradaki Türkçe adlar
# devralınmış borçtur ve bu kapı onları toptan kırmızıya çevirseydi kapı
# KAPATILIRDI (kimse 500 ihlalli bir kapıyı açık tutmaz).
# ⚠ KAPSAM GENISLEDI (V-08, 19.09): `dashboard` da tarnaiyor. Ama TEMIZ DEGIL —
#   olculdu: 85 dosyada 2.431 bulgu. Iki secenek vardi ve ikisi de kotuydu:
#     (a) kapsama alma  -> dashboard KOR kalir (bugune kadarki hal)
#     (b) kapsama al ve bloklama -> 2.431 hatayla kapi ILK GUN KAPATILIR
#   Ucuncu yol secildi: CIRCIR. Her dosyanin bugunku sayisi TAVAN
#   (`tools/turkce-taban.json`). ARTIS kirar, azalis "tabani guncelle" der,
#   YENI dosya temiz olmak zorunda (taban 0).
#   Yani borc DONDURULUYOR, gizlenmiyor: sayisi dosyada YAZILI ve her kosumda
#   ekrana basiliyor.
KAPSAM = ["vardiya-app", "lib/Bkm.Shared", "tests", "dashboard"]
TABAN_DOSYASI = Path(__file__).resolve().parent / "turkce-taban.json"
TABANLI_KOKLER = ("dashboard",)   # circir yalniz burada; otekiler SIFIR tolerans

TURKCE_KELIMELER = [
    "Sube", "Mudur", "Kisi", "Gun", "Tarih", "Onay", "Sifre", "Kullanici",
    "Sayfa", "Deger", "Adi", "Hata", "Kesim", "Ozet", "Uyum", "Kaynak",
    "Bant", "Satir", "Durum", "Gorev", "Bolum", "Personel", "Sicil",
    "Eksik", "Fazla", "Giris", "Cikis", "Mola", "Calisma", "Devir",
    "Sayim", "Olcum", "Yazilma", "Aciklama", "Kaydeden", "Yetki", "Izin",
    "Rapor", "Tablo", "Sorgu", "Kapsam", "Nufus", "Fabrika", "Istemci",
    "Yanit", "Sonuc", "Mevcut", "Onceki", "Yeni", "Eski", "Toplam",
    "Bugun", "Secili", "Gecerli", "Bos", "Dolu", "Temizle", "Kur",
    "Oku", "Yaz", "Sil", "Ekle", "Guncelle", "Bul", "Ara", "Getir",
    "Kaydet", "Yukle", "Baslat", "Bitir", "Kontrol", "Denetim", "Damga",
    "Onek", "Artik", "Islem", "Ayrac", "Suzgec", "Kirilim", "Ortak",
    # 19.09 ikinci tur — ilk listede YOKTU ve kactilar (sozlesmedeki
    # "BILINEN ATLATMA" maddesinin ilk gerceklesmesi):
    "Kaydeden", "Dakika", "Metin", "Muaf", "Mesai", "Kadro", "Ek",
    "Yukleyici", "Bicim", "Sabit", "Kur", "Uret", "Cevir", "Hazirla",
]
TURKCE_HARF = "ıİşŞğĞüÜöÖçÇ"

# ── AK LİSTE (V-19) — kapının ÜÇÜNCÜ yarısı ─────────────────────────────────
# Kara liste "şu kelimeler yasak" der ve eksikliği GÖRÜNMEZ. Ak liste "yalnız bu
# sözcükler serbest" der ve eksikliği HER YENİ SÖZCÜKTE İNSANA SORAR.
#
# ⚠ KURULURKEN İKİ KAÇAK BULDU: `LikeKacir` ve `CalistirAsync` aylardır koddaydı,
#   kara listede o kelimeler olmadığı için kapı onları HİÇ görmemişti.
SOZLUK_DOSYASI = Path(__file__).resolve().parent / "kod-sozcukleri.txt"

# Yalnız BİLDİRİM yerleri taranır (tip · metot · özellik adı). Kullanım yerleri
# değil: aynı adı iki kez bildirmiyoruz ve kullanım taraması dış kütüphane adlarını
# (Dapper, Identity) da çekerdi — dağarcık şişer, kapı gürültülenir.
BILDIRIM_DESENLERI = [
    re.compile(r"\b(?:class|record|struct|interface|enum)\s+(\w+)"),
    re.compile(r"\b(?:public|private|internal|protected)\s+"
               r"(?:static\s+|async\s+|sealed\s+|override\s+|new\s+)*"
               r"[\w<>?,\[\]\.]+\s+(\w+)\s*[\(\{=;]"),
]
SOZCUK_PARCA = re.compile(r"[A-ZÇĞİÖŞÜ][a-zçğıöşü0-9]*|[a-zçğıöşü0-9]+")

# C# anahtar sözcükleri dağarcığa girmez.
CS_ANAHTAR = set("""abstract as async await base bool break byte case catch char checked class
const continue decimal default delegate do double else enum event explicit extern false finally
fixed float for foreach get goto if implicit in int interface internal is lock long namespace new
null object operator out override params private protected public readonly ref return sbyte sealed
set short sizeof stackalloc static string struct switch this throw true try typeof uint ulong
unchecked unsafe ushort using var virtual void volatile while record init with when and or not
nameof value global file required scoped""".split())


def taban_yukle() -> dict:
    """Circir tabani: {dosya yolu -> izin verilen bulgu sayisi}.

    ⚠ Dosya YOKSA kapi KOSAMADI demez, TABANSIZ calisir (yani sifir tolerans) —
      cunku tabanin yoklugu kapiyi GEVSETMEZ, SIKISTIRIR. Guvenli yon budur.
    """
    if not TABAN_DOSYASI.exists():
        return {}
    try:
        import json
        return json.loads(io.open(TABAN_DOSYASI, encoding="utf-8").read()).get("dosyalar", {})
    except (ValueError, OSError):
        return {}


def dagarcigi_yukle():
    """Ak liste. Dosya yoksa KOŞAMADI — sessizce kara listeye düşmek YASAK."""
    if not SOZLUK_DOSYASI.exists():
        return None
    sozcukler = set()
    for satir in io.open(SOZLUK_DOSYASI, encoding="utf-8"):
        satir = satir.strip()
        if satir and not satir.startswith("#"):
            sozcukler.add(satir.lower())
    return sozcukler or None

# Kod dışı bırakılacaklar: yorum + dize
# SATIR YORUMU icin `[^\n]*` kullanilir, `.*$` DEGIL.
# Gerekce olculdu (19.09.2026): `re.S` bayragiyla `.` newline de esler ve
# `$` yalniz dosya sonunda durur -> ilk `//` yorumundan itibaren dosyanin
# TAMAMI siliniyordu, yani hicbir C# dosyasi gercekte denetlenmiyordu.
# Kapi SESSIZCE yesil veriyordu; kirmizi kip kosulmasaydi gorulmezdi.
YORUM = re.compile(r"//[^\n]*|/\*.*?\*/|@\*.*?\*@", re.S)
DIZE = re.compile(r'"""[\s\S]*?"""|"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
RAZOR_METIN = re.compile(r">[^<>{}@]*<")          # HTML metin düğümleri


def _gosterim(p: Path) -> str:
    """Yolu kısa göster — komut satırından göreli yol verilmişse relative_to çöker."""
    try:
        return str(p.resolve().relative_to(KOK))
    except ValueError:
        return str(p)


def _satir_koru(m: re.Match) -> str:
    """Eşleşmeyi siler AMA satır sayısını korur — yoksa satır numarası kayar
    ve bulgu yanlış satırı gösterir (ilk sürümde tam bu oldu)."""
    return chr(10) * m.group(0).count(chr(10))


# Razor'da KOD yalnız `@` ile başlayan ifadelerdedir: `@Model.Foo`, `@Bar(x)`,
# `@if (…)`, `@code { … }`. Gerisi HTML metnidir ve TÜRKÇE OLMALI.
# İlk sürüm tersini yapıyordu (HTML metnini çıkarıp kalanı kod saymak) ve
# `Toplam @VrdFormat…` gibi satırlarda UI metnini tanımlayıcı sandı.
RAZOR_IFADE = re.compile(r"@[A-Za-z_][\w.]*(?:\([^)]*\))?")


KOD_BLOK_BAS = re.compile(r"@(?:code|functions)\s*\{")


def _kod_blok_satirlari(metin: str) -> set:
    """`@code { … }` / `@functions { … }` gövdesinin 1-tabanlı satır numaraları.

    ⚠ BU BLOK 19.09'A KADAR HİÇ DENETLENMEDİ. `RAZOR_IFADE` deseni `@code`i
      tek sözcük olarak eşleyip GÖVDEYİ atıyordu; dashboard'ın .razor
      dosyalarında ise C#'ın TAMAMI orada durur. Yani kapı ".razor taranıyor"
      derken yalnız markup'taki `@Ifade` referanslarını görüyordu — bildirimleri
      DEĞİL. Kırmızı kip koşulmasaydı görülmezdi: `private int SatirSayisi`
      eklendi, kapı YEŞİL kaldı.
      Sınıf: `test-discipline.md` § YAZILI KURAL ≠ UYGULANAN KURAL.

    Süslü parantez sayımı yorum/dize AYIKLANDIKTAN sonra yapılır — yoksa
    bir dizedeki `}` bloğu erken kapatır.
    """
    satirlar = set()
    for m in KOD_BLOK_BAS.finditer(metin):
        i = m.end() - 1
        derinlik = 0
        while i < len(metin):
            if metin[i] == "{":
                derinlik += 1
            elif metin[i] == "}":
                derinlik -= 1
                if derinlik == 0:
                    break
            i += 1
        bas = metin.count(chr(10), 0, m.start()) + 1
        son = metin.count(chr(10), 0, min(i, len(metin) - 1)) + 1
        satirlar.update(range(bas, son + 1))
    return satirlar


def soyutla(metin: str, razor: bool):
    """(temiz metin, @code gövde satırları) döner.

    Razor'da iki AYRI bölge vardır ve aynı muameleyi göremezler:
      • markup  — UI metni Türkçe OLMALI; yalnız `@Ifade` referansları koddur.
      • @code   — düpedüz C#; harf taraması dahil TAM denetim görür.
    """
    metin = YORUM.sub(_satir_koru, metin)
    metin = DIZE.sub(_satir_koru, metin)
    if not razor:
        return metin, set()
    kod_satir = _kod_blok_satirlari(metin)
    return chr(10).join(
        satir if i in kod_satir else " ".join(RAZOR_IFADE.findall(satir))
        for i, satir in enumerate(metin.splitlines(), 1)), kod_satir


def kod_kismi(metin: str, razor: bool) -> str:
    """Kod DIŞINI çıkar. Razor'da tersi: yalnız `@` ifadelerini TUT."""
    metin = YORUM.sub(_satir_koru, metin)
    metin = DIZE.sub(_satir_koru, metin)
    if razor:
        # satır yapısını koru: her satırda yalnız @ifadelerini bırak
        return chr(10).join(" ".join(RAZOR_IFADE.findall(satir)) for satir in metin.splitlines())
    return metin


def ihlaller(yol: Path) -> list[tuple[int, str, str]]:
    # ⚠ Razor'da TÜRKÇE HARF denetimi YAPILMAZ: UI metni Türkçe harf doludur ve
    #   kalan HTML parçalarını koddan ayırmak güvenilir değil. Razor'da yalnız
    #   KELİME listesi aranır (tanımlayıcı adları). C#'ta ikisi de aranır.
    razor = yol.suffix.lower() in (".cshtml", ".razor")
    ham = io.open(yol, encoding="utf-8-sig", errors="replace").read()
    bulgular: list[tuple[int, str, str]] = []

    # Dosya adı
    ad = yol.stem
    for k in TURKCE_KELIMELER:
        if re.search(rf"{k}", ad) and ad not in ("VardiyaQueries", "VardiyaModels", "VardiyaAppFactory"):
            bulgular.append((0, ad, f"dosya adı Türkçe: {k}"))
            break

    satirlar = ham.splitlines()
    temiz_metin, kod_satir = soyutla(ham, razor)
    temiz = temiz_metin.splitlines()
    for i, satir in enumerate(temiz, 1):
        if not satir.strip():
            continue
        # Harf taraması: C# dosyasının tamamında, razor'da YALNIZ @code gövdesinde
        # (markup'ta Türkçe harf UI metnidir, ihlal değil).
        for ch in (satir if (not razor or i in kod_satir) else ""):
            if ch in TURKCE_HARF:
                bulgular.append((i, satirlar[i - 1].strip()[:90], f"tanımlayıcıda Türkçe harf '{ch}'"))
                break
        else:
            for k in TURKCE_KELIMELER:
                if re.search(rf"\b\w*{k}\w*\b", satir):
                    eslesen = re.search(rf"\b\w*{k}\w*\b", satir).group(0)
                    # `Vardiya`/`Vrd`/`Bkm` domain adları serbest
                    if eslesen in ("Vardiya", "Vrd", "Bkm"):
                        continue
                    bulgular.append((i, satirlar[i - 1].strip()[:90], f"Türkçe tanımlayıcı: {eslesen}"))
                    break
    return bulgular


def bilinmeyen_sozcukler(yol: Path, dagarcik: set) -> list:
    """Ak liste denetimi: bildirilen adlardaki sozcukler dagarcikta var mi?

    UYARI  KARA LISTEDEN FARKI BU: kara liste "su kelime yasak" der ve listede
      olmayan Turkce kelimeyi HIC gormez. Ak liste "bu sozcugu tanimiyorum" der —
      yani eksikligi INSANA SORAR. Yanlis pozitifin bedeli bir satir eklemek,
      yanlis negatifin bedeli gorunmeyen bir ihlal.
    """
    uzanti = yol.suffix.lower()
    if uzanti not in (".cs", ".razor"):
        return []   # .cshtml'de bildirim yok; markup adlarini taramak gurultu uretir
    ham = io.open(yol, encoding="utf-8-sig", errors="replace").read()
    temiz, kod_satir = soyutla(ham, razor=(uzanti == ".razor"))
    if uzanti == ".razor":
        # Ak liste yalniz @code GOVDESINE bakar: markup'ta bildirim yoktur ve
        # `@Ifade` referanslarini bildirim sanmak gurultu uretir.
        temiz = chr(10).join(satir if i in kod_satir else ""
                             for i, satir in enumerate(temiz.splitlines(), 1))
    satirlar = ham.splitlines()

    bulgular = []
    gorulen = set()
    for desen in BILDIRIM_DESENLERI:
        for m in desen.finditer(temiz):
            ad = m.group(1)
            if ad in CS_ANAHTAR:
                continue
            satir_no = temiz[:m.start()].count(chr(10)) + 1
            for w in SOZCUK_PARCA.findall(ad):
                wl = w.lower()
                if len(wl) < 2 or wl.isdigit() or wl in CS_ANAHTAR or wl in dagarcik:
                    continue
                if wl in gorulen:
                    continue
                gorulen.add(wl)
                metin = satirlar[satir_no - 1].strip()[:90] if satir_no <= len(satirlar) else ""
                bulgular.append((satir_no, metin, "ak listede YOK: '%s' (ad: %s)" % (w, ad)))
    return bulgular


hedefler: list[Path] = []
if len(sys.argv) > 1:
    hedefler = [Path(a) for a in sys.argv[1:] if Path(a).exists()]
else:
    for k in KAPSAM:
        for uzanti in ("*.cs", "*.cshtml", "*.razor"):
            hedefler += [p for p in (KOK / k).rglob(uzanti)
                         if "obj" not in p.parts and "bin" not in p.parts]

if not hedefler:
    print("KOŞAMADI  taranacak dosya bulunamadı — kapsam yolları değişmiş olabilir")
    sys.exit(2)

print("═" * 74)
print("TÜRKÇE TANIMLAYICI DENETİMİ — kod İngilizce, UI/yorum Türkçe")
print("═" * 74)

DAGARCIK = dagarcigi_yukle()
if DAGARCIK is None:
    print("KOSAMADI  ak liste okunamadi (tools/kod-sozcukleri.txt) — kapinin ikinci "
          "yarisi CALISMIYOR demektir; sessizce kara listeye dusmek YASAK")
    sys.exit(2)

TABAN = taban_yukle()


def tabanli_mi(yol: Path) -> bool:
    rel = yol.relative_to(KOK).as_posix() if str(yol).startswith(str(KOK)) else yol.as_posix()
    return rel.startswith(TABANLI_KOKLER)


toplam = 0
dondurulan = 0      # tabanin ALTINDA ya da ESIT kalan (borc, yeni ihlal degil)
gevseyen = []       # taban DUSMUS: tabani sikistirma firsati
for p in sorted(hedefler):
    b = ihlaller(p) + bilinmeyen_sozcukler(p, DAGARCIK)
    rel = p.relative_to(KOK).as_posix() if str(p).startswith(str(KOK)) else p.as_posix()
    izin = TABAN.get(rel, 0) if tabanli_mi(p) else 0

    if len(b) <= izin:
        # Taban ALTINDA ya da esit — bu bir BORC, yeni ihlal degil.
        dondurulan += len(b)
        if len(b) < izin:
            gevseyen.append((rel, izin, len(b)))
        continue

    asim = b[izin:] if izin else b
    toplam += len(asim)
    print(f"\nKIRIK {_gosterim(p)}" + (f"  (taban {izin}, şimdi {len(b)})" if izin else ""))
    for satir, metin, sebep in asim[:6]:
        print(f"   satır {satir:>4}: {sebep}")
        if metin:
            print(f"              {metin}")
    if len(asim) > 6:
        print(f"   … {len(asim) - 6} bulgu daha")

print()
if toplam:
    print(f"KIRIK · {toplam} bulgu. Kod İngilizce olmalı (turkish-ui.md); yorum ve UI")
    print("        metni Türkçe KALIR — bu kapı onlara dokunmaz.")
    print("        'ak listede YOK' bulgusu iki seçenek sunar: sözcük İngilizceyse")
    print("        tools/kod-sozcukleri.txt'e BİR SATIR ekle, Türkçeyse ÇEVİR.")
    sys.exit(1)
if gevseyen:
    print(f"BİLGİ  {len(gevseyen)} dosya tabanının ALTINDA — tabanı SIKIŞTIR "
          f"(tools/turkce-taban.json). Çırcır ancak sıkıştırılırsa ilerler.")
    for rel, izin, simdi in gevseyen[:5]:
        print(f"       · {rel}: {izin} → {simdi}")
print(f"Denetim geçti · {len(hedefler)} dosya · ak liste {len(DAGARCIK)} sözcük · "
      f"dondurulmuş borç {dondurulan} bulgu ({len(TABAN)} dosya)")
