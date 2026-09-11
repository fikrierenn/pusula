#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Panel kolon/kayıt denetimi — DERLEYİCİNİN GÖRMEDİĞİ iki sessiz hata sınıfı.

Bu oturumda (10.09.2026) ikisi de İKİ KEZ oldu ve build yeşil kaldı:

  (A) DAPPER POZİSYONEL SIRA. Positional record'da Dapper isim değil SIRA eşler.
      SQL SELECT'e yeni bir kolon araya eklenip record'un SONUNA yazılınca
      materialization patlar ("A parameterless default constructor or one matching
      signature ... is required") ya da — daha kötüsü — tip uyumluysa DEĞER KAYAR
      ve hata hiç çıkmaz. Bu oturumda birincisi oldu; ikincisi sessiz yanlış rakamdır.

  (B) HÜCRE EŞLEMESİ ANAHTAR ÇATALLANMASI. Kolon anahtarı iki yerde yazılıyorsa
      (kolon tanımı ↔ değer eşlemesi) biri ötekine uymadığında kolon SESSİZCE BOŞ
      görünür. Bu oturumda çift yönlü oldu: ekranda `sonsatis`/`talepdeseni`/`satanay`
      boştu, Excel'de `kapsama` ve `sezon_ay1..3` boştu. Hata mesajı YOK.

`sqlcli` dört sözleşmesinden ikisi burada da geçerli:
  · çıkış kodu 0 geçti · 1 KIRIK · 2 KOŞAMADI (dosya bulunamadı/parse edilemedi)
  · "koşamadı" asla yeşil sayılmaz

Kullanım:
    python tools/panel_kolon_denetimi.py

⚠ SINIRLAR (silent-failure-hunter denetimi 10.09.2026 — neyi HÂLÂ görmüyor):
· BİÇİMSEL denetim. Anahtar DOĞRU ama YANLIŞ ALANA bağlıysa (`"sonsatis" => s.SonGirisTarihi`)
  bunu ASLA göremez — CFO'nun gördüğü yanlış rakam tam bu sınıftır.
· Kolon TİPİ değişimini görmez (`SatanAy int→varchar`) — Dapper eşlemeyi bozan asıl şey.
· Alias'sız SELECT kolonlarını atlar; atlanan oranı %50'yi geçerse artık KIRIK verir
  (önce yalnız uyarıydı ve sıra kıyası sessizce körleşiyordu).
· İfade birleştirmeli SQL (12.09.2026) ARTIK ÇÖZÜLÜYOR: `const string X = A + " AS Y"`
  biçimindeki bildirimler string parçalarına ayrılır ve referans ettiği const'lar açılır.
  Öncesinde bu yolla eklenen 4 alias denetim DIŞINDAYDI.
· Yalnız CIFTLER/ANAHTAR_CIFTLERI'nda listelenen çiftleri denetler. Repoda başka pozisyonel
  record var (UrunMaliyet · UrunGerceklesen · AkranOzet · DepoAdres · UrunHiz · ExcelDetaySatir …)
  ve BUNLAR DENETİM DIŞI.
· Python emitter (scripts/satis_analizi_excel.py) hiç denetlenmiyor: orada da başlık listesi
  ile SELECT kolon sayısı karşılaştırılmıyor (aynı pozisyonel kayma sınıfı).
· TESLİM YOLU: bu araç `.claude/hooks/pre-commit-antipattern.sh` üzerinden yalnız Claude'un
  Bash `git commit` çağrısında koşar. `.git/hooks/pre-commit` kurulmadıkça kullanıcının kendi
  terminalinden / IDE'den attığı commit denetimi GÖRMEZ.
⇒ "0 kırık" şunu söyler: listelenen çiftlerin alias sırası kaymamış ve kolon anahtarları
  eşlemede var. Bunun ötesi ölçülmemiştir.
"""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
# stderr DE utf-8 olmalı: Türkçe içeren traceback cp1254 konsolda UnicodeEncodeError
# verip ASIL SEBEBİ gizliyordu (silent-failure-hunter madde 17).
sys.stderr.reconfigure(encoding="utf-8")

KOK = Path(__file__).resolve().parent.parent

# ── Denetlenecek pozisyonel kayıt ↔ SQL çiftleri ────────────────────────────────
# (etiket, sql_dosyasi, sql_baslangic_imi, record_dosyasi, record_adi)
CIFTLER = [
    (
        "Özet KPI satırı",
        "dashboard/Data/SatisAnaliziQueries.cs",
        "public async Task<SatisAnaliziOzet> GetOzetAsync",
        "dashboard/Data/SatisAnaliziQueries.cs",
        "OzetSatirRow",
    ),
    # ⚠ EKLENDİ 10.09.2026 (silent-failure-hunter madde 1): bugün patlayan İKİ hatadan
    # biri (SonSatisTarihi) TAM BU ÇİFTTEYDİ ve denetim onu hiç görmüyordu. Daha kötüsü:
    # hook deseni `SatisAnaliziQueries`'i yakaladığı için Liste.cs düzenlenince denetim
    # KOŞUP "OK" basıyordu → yanlış onay.
    # ⚠ Bu çiftte alias'sız kolon ÇOK (ölçüldü: ~35 öğenin 18'i) → göreli sıra kıyası
    # KISMEN KÖR. Bu yüzden atlanan sayısı artık UYARI değil, oranı yüksekse KIRIK.
    (
        "Ürün listesi satırı",
        "dashboard/Data/SatisAnaliziQueries.Liste.cs",
        # ⚠ İM `ListeKolonlarSql` (12.09.2026): `ListeKolonlar`ı referansla içerir VE
        # sipariş kolonlarını ekler. Eski im dört alias'ı kaçırıyordu.
        "private const string ListeKolonlarSql",
        "dashboard/Models/SatisAnaliziModels.cs",
        "SatisAnaliziSatir",
    ),
]

# ── Anahtar kümesi çiftleri (kolon tanımı ↔ değer eşlemesi) ────────────────────
ANAHTAR_CIFTLERI = [
    (
        "Satış Analizi kolonları",
        "dashboard/Models/SatisAnaliziModels.cs",
        r'new\("([a-z0-9_]+)"',          # kolon tanımı: new("anahtar", "Başlık", ...)
        "dashboard/Data/SatisAnaliziHucre.cs",
        r'"([a-z0-9_]+)"\s*=>',          # eşleme: "anahtar" => s.Alan
    ),
]

kirik: list[str] = []
uyari: list[str] = []

# ⚠ VACUOUS PASS MUHAFIZI (silent-failure-hunter madde 3, KANITLANDI).
# Regex bir şey bulamazsa (sözdizimi değişti, SQL bir const'a taşındı, anahtarlar
# BÜYÜK harfe döndü) kıyas BOŞ KÜME ile yapılıyordu ve "OK 0 kolon" + exit 0 çıkıyordu.
# Yani denetimi devre dışı bırakmanın yolu onu bozmak DEĞİL, sözdizimini değiştirmekti.
# Artık her taraf için ALT SINIR var; altına düşen KOŞAMADI (exit 2) sayılır.
ASGARI_ALIAS = 20      # OzetSatirRow'da 51 alias ölçüldü; Liste'de de 15+ var
ASGARI_ANAHTAR = 20    # kolon tanımı 37 ölçüldü


def kosamadi(mesaj: str) -> None:
    """Ölçemedik — YEŞİL SAYILMAZ. sqlcli dört sözleşmesi: exit 2 = KOŞAMADI."""
    print("KOŞAMADI  " + mesaj)
    sys.exit(2)


if not CIFTLER:
    kosamadi("CIFTLER listesi BOŞ — hiçbir sıra denetimi yapılmadı")
if not ANAHTAR_CIFTLERI:
    kosamadi("ANAHTAR_CIFTLERI listesi BOŞ — hiçbir anahtar denetimi yapılmadı")


def oku(rel: str) -> str:
    p = KOK / rel
    if not p.exists():
        print(f"KOŞAMADI  dosya yok: {rel}")
        sys.exit(2)
    return io.open(p, encoding="utf-8-sig").read()


# ── SQL metnini ÇÖZ: raw-string + ifade birleştirme + sabit referansı ──────────
# ⚠ NEDEN GEREKLİ (ölçüldü 11-12.09.2026): kolonların bir kısmı raw-string'de DEĞİL,
# C# ifade birleştirmesiyle ekleniyor:
#     private const string ListeKolonlarSql =
#         ListeKolonlar + ",\n" + SiparisOneriSql + " AS SiparisOneri" + …;
# Eski çözümleyici yalnız İLK raw-string bloğunu okuyordu → bu yolla eklenen dört alias
# (EtkinGun · SiparisOneri · SiparisKapak · SiparisTaban) "SQL'de yok" sayılıyordu ve
# denetim tam da kayma üreten yerde KÖR kalıyordu. Uyarı metni bunu söylüyordu ama
# uyarı bir KAPI DEĞİLDİR — kapı ancak çözümleyici o metni okuyunca kurulur.
_STR_RE = re.compile(r'"""(.*?)"""|"((?:[^"\\]|\\.)*)"', re.S)


def _bildirim_govdesi(metin: str, im: str) -> str:
    """`im` ile başlayan bildirimin `=` sonrası gövdesi, deyim sonundaki `;`e kadar.

    ⚠ SATIR TABANLI ve RAW-STRING FARKINDA: çok satırlı `\"\"\"…\"\"\"` bloğunun İÇİNDEKİ
    `;` deyim sonu DEĞİLDİR. İlk sürüm karakter maskesiyle yazılmıştı, `;`i hiç bulamadı
    ve gövde 30.884 karaktere (dosyanın geri kalanı) taştı → 576 sahte alias üretti.
    """
    i = metin.find(im)
    if i < 0:
        return ""
    esit = metin.find("=", i)
    if esit < 0:
        return ""
    ham, blok_icinde = [], False
    for satir in metin[esit + 1:].splitlines():
        ham.append(satir)
        if satir.count('\"\"\"') % 2 == 1:      # blok açıldı ya da kapandı
            blok_icinde = not blok_icinde
            continue
        if blok_icinde:
            continue
        # Tek satırlık string'leri sil, KALAN kodda `;` var mı bak
        # ⚠ `//` YORUMU DA ELENİR (12.09.2026): elenmezse gövde erken biter —
        # `ListeKolonlar` altındaki açıklama satırı "… kayboluyordu; SQL'de …"
        # içeriyor ve o `;` deyim sonu sanılıyordu → `+ " AS EtkinGun"` satırına
        # HİÇ ulaşılmıyor, alias sessizce kayboluyordu (atlanan 4 → 1 → 0).
        kod = re.sub(r'"(?:[^"\\]|\\.)*"', "·", satir)
        kod = kod.split("//", 1)[0]
        if ";" in kod:
            break
    return "\n".join(ham)


def _sql_coz(metin: str, im: str, derinlik: int = 0) -> str:
    """Bildirimdeki TÜM string parçalarını SIRAYLA birleştirir; gövdede geçen
    `const string X` referanslarını aynı dosyada açar (derinlik ≤ 3).

    Sıra korunur — Dapper pozisyonel eşlediği için kıyasın anlamı sıradadır."""
    govde = _bildirim_govdesi(metin, im)
    if not govde:
        return ""
    parcalar = []
    son = 0
    for m in _STR_RE.finditer(govde):
        for ad in re.findall(r"\b([A-Z][A-Za-z0-9_]*)\b", govde[son:m.start()]):
            if derinlik < 3:
                ic = _sql_coz(metin, "const string " + ad + " =", derinlik + 1)
                if ic:
                    parcalar.append(ic)
        parcalar.append(m.group(1) if m.group(1) is not None else (m.group(2) or ""))
        son = m.end()
    for ad in re.findall(r"\b([A-Z][A-Za-z0-9_]*)\b", govde[son:]):
        if derinlik < 3:
            ic = _sql_coz(metin, "const string " + ad + " =", derinlik + 1)
            if ic:
                parcalar.append(ic)
    return "\n".join(parcalar)


def sql_aliaslari(metin: str, baslangic: str) -> tuple[list[str], int]:
    """SQL'den `AS Alias` adlarını SIRAYLA topla.

    Kaynak iki biçimden biri: (a) metot içindeki ilk raw-string, (b) ifade
    birleştirmeli `const string` bildirimi (12.09.2026'da eklendi)."""
    i = metin.find(baslangic)
    if i < 0:
        print("KOŞAMADI  SQL başlangıç imi bulunamadı: " + baslangic[:50])
        sys.exit(2)

    if "const string" in baslangic:
        sql = _sql_coz(metin, baslangic)
        if not sql:
            print("KOŞAMADI  const SQL gövdesi çözülemedi: " + baslangic[:50])
            sys.exit(2)
    else:
        a = metin.find('"""', i)
        b = metin.find('"""', a + 3)
        if a < 0 or b < 0:
            print("KOŞAMADI  raw-string SQL sınırları bulunamadı")
            sys.exit(2)
        sql = metin[a + 3:b]

    # Yorum satırlarını at — `-- … AS …` ve `// …` yanlış alias üretir
    satirlar = [x for x in sql.splitlines()
                if not x.strip().startswith("--") and not x.strip().startswith("//")]
    sql = "\n".join(satirlar)
    aliaslar = re.findall(r"\bAS\s+([A-Za-z_][A-Za-z0-9_]*)", sql)
    return aliaslar, sql.count("\n")


def record_parametreleri(metin: str, ad: str) -> list[str]:
    """`private sealed record Ad(...)` parametre adlarını SIRAYLA topla."""
    m = re.search(rf"record\s+{re.escape(ad)}\s*\(", metin)
    if not m:
        print(f"KOŞAMADI  record bulunamadı: {ad}")
        sys.exit(2)
    i = m.end()
    derinlik, j = 1, i
    while j < len(metin) and derinlik > 0:
        if metin[j] == "(":
            derinlik += 1
        elif metin[j] == ")":
            derinlik -= 1
        j += 1
    govde = metin[i : j - 1]
    govde = "\n".join(s for s in govde.splitlines() if not s.strip().startswith("//"))
    adlar = []
    for parca in govde.split(","):
        parca = parca.strip()
        if not parca:
            continue
        # "int DuzgunTalepCesit" → son sözcük
        son = parca.split()[-1]
        adlar.append(son)
    return adlar


print("═" * 74)
print("A) DAPPER POZİSYONEL SIRA — SQL alias sırası ↔ record parametre sırası")
print("═" * 74)

for etiket, sql_dosya, im, rec_dosya, rec_ad in CIFTLER:
    aliaslar, _ = sql_aliaslari(oku(sql_dosya), im)
    params = record_parametreleri(oku(rec_dosya), rec_ad)
    # Vacuous pass muhafızı — boş küme ile kıyas YEŞİL SAYILMAZ
    if len(aliaslar) < ASGARI_ALIAS:
        kosamadi(f"{etiket}: SQL'de yalnız {len(aliaslar)} alias bulundu (asgari "
                 f"{ASGARI_ALIAS}). Sözdizimi değişmiş ya da SQL başka yere taşınmış "
                 f"olabilir — boş kıyas yapıp 'geçti' demek yerine durduruldu.")
    if len(params) < ASGARI_ALIAS:
        kosamadi(f"{etiket}: record'da yalnız {len(params)} parametre bulundu (asgari "
                 f"{ASGARI_ALIAS}). Record adı/sözdizimi değişmiş olabilir.")
    # Yalnız İKİ TARAFTA DA olan adları kıyasla; alias'sız kolonlar atlanır
    ortak_sql = [a for a in aliaslar if a in params]
    ortak_rec = [p for p in params if p in aliaslar]
    atlanan = [p for p in params if p not in aliaslar]

    if ortak_sql == ortak_rec:
        print(f"OK    {etiket}: {len(ortak_sql)} alias sırada · atlanan {len(atlanan)}")
    else:
        # İlk sapmayı göster — hangi addan itibaren kaydığı
        for k, (x, y) in enumerate(zip(ortak_sql, ortak_rec)):
            if x != y:
                kirik.append(
                    f"{etiket}: SIRA SAPMASI {k}. konumda — SQL '{x}' ↔ record '{y}'. "
                    f"Dapper isim değil SIRA eşler; record parametrelerini SELECT sırasına al."
                )
                break
        else:
            kirik.append(f"{etiket}: uzunluk farkı — SQL {len(ortak_sql)}, record {len(ortak_rec)}")
    if atlanan:
        # ⚠ ATLANAN ORANI YÜKSEKSE SIRA KIYASI KÖR (silent-failure-hunter madde 9):
        # araya ALIAS'SIZ bir kolon eklenirse alias'ların GÖRELİ sırası değişmez →
        # sapma yakalanmaz, ama Dapper'da tüm alt pozisyonlar kayar. Yarıdan fazlası
        # atlanıyorsa denetim güvence VERMİYOR; bunu uyarı değil KIRIK olarak bildir.
        oran = len(atlanan) / max(len(params), 1)
        mesaj = (f"{etiket}: {len(atlanan)}/{len(params)} record parametresi SQL'de alias "
                 f"olarak bulunamadı (%{100 * oran:.0f}) → sıra kıyası bu kadar kolonda KÖR: "
                 + ", ".join(atlanan[:6]) + (" …" if len(atlanan) > 6 else ""))
        (kirik if oran > 0.5 else uyari).append(
            mesaj + (" ⇒ SQL'de bu kolonlara AS <Ad> yazılmalı." if oran > 0.5 else ""))

print()
print("═" * 74)
print("B) ANAHTAR ÇATALLANMASI — kolon tanımı ↔ değer eşlemesi")
print("═" * 74)

for etiket, tanim_dosya, tanim_re, esle_dosya, esle_re in ANAHTAR_CIFTLERI:
    tanimli = set(re.findall(tanim_re, oku(tanim_dosya)))
    esle_metin = oku(esle_dosya)
    # ⚠ `when` SATIRLARI ELENİYOR (silent-failure-hunter madde 2, KANITLANDI).
    # `Metin()` içindeki `decimal v when anahtar == "kapsama" =>` satırı desene UYUYORDU;
    # bu yüzden `Deger()` switch'inden "kapsama" kolu SİLİNSE bile (kolon gerçekten boşalır)
    # denetim OK diyordu. Yani bugün Excel'de boş çıkan kolonun regresyonuna karşı
    # HİÇ KORUMA YOKTU. Anahtar yalnız GERÇEK switch kolundan sayılır.
    esle_satirlar = [x for x in esle_metin.splitlines()
                     if " when " not in x and not x.strip().startswith("//")]
    eslenen = set(re.findall(esle_re, "\n".join(esle_satirlar)))
    if len(tanimli) < ASGARI_ANAHTAR:
        kosamadi(f"{etiket}: yalnız {len(tanimli)} kolon tanımı bulundu (asgari "
                 f"{ASGARI_ANAHTAR}). `new(\"anahtar\"` sözdizimi değişmiş olabilir — "
                 f"boş kümeyle kıyas 'geçti' sayılmaz.")
    if len(eslenen) < ASGARI_ANAHTAR:
        kosamadi(f"{etiket}: eşlemede yalnız {len(eslenen)} anahtar bulundu (asgari "
                 f"{ASGARI_ANAHTAR}).")

    eksik = sorted(tanimli - eslenen)     # kolon seçilebilir ama değer gelmez → BOŞ
    fazla = sorted(eslenen - tanimli)     # eşleme var, kolon tanımı yok → ölü dal

    if eksik:
        kirik.append(
            f"{etiket}: kolon tanımlı ama eşlemede YOK → o kolon SESSİZCE BOŞ görünür: "
            + ", ".join(eksik)
        )
    else:
        print(f"OK    {etiket}: {len(tanimli)} kolon tanımının hepsi eşlemede var")
    if fazla:
        uyari.append(
            f"{etiket}: eşlemede var ama kolon tanımı yok (hiçbir çıktıda seçilemez): "
            + ", ".join(fazla)
        )

print()
for u in uyari:
    print("UYARI " + u)
if kirik:
    print()
    for k in kirik:
        print("KIRIK " + k)
    print(f"\n{len(kirik)} kırık — düzeltilmeden commit edilmez.")
    sys.exit(1)

print(f"\nDenetim geçti · {len(uyari)} uyarı · 0 kırık")
sys.exit(0)
