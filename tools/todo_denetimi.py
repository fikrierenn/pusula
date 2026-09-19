#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TODO KAPISI — madde SESSİZCE kaybolmasın, kapanan madde AÇIK kalmasın.

NEDEN VAR (19.09.2026, ÖLÇÜLDÜ — kendi hatam):
  TODO düzenlemelerinde madde sınırını "bir sonraki BOŞ SATIR" diye arıyordum.
  Vardiya maddeleri aralarında boş satır OLMADAN diziliydi; `V-01` güncellemesi
  `V-02 · V-03 · V-04 · V-05`i BİRLİKTE SİLDİ. Dosya geçerli göründü, commit geçti,
  hiçbir şey uyarmadı. İki commit sonra "V-05 yap" denince madde BULUNAMADI ve
  ancak o zaman fark edildi.

  Kaybın sinsiliği: silinen madde ekranda YOKTUR, yani bakınca "yapılmış" gibi
  görünür. Açık borç, kapanmış borçtan ayırt edilemez hâle gelir.

YAKALAMA SÖZLEŞMESİ
  YAKALAR        : bir önceki sürümde VAR olan madde kimliğinin KAYBOLMASI ·
                   mükerrer kimlik · commit'te "kapandı" denen ama TODO'da hâlâ
                   `[ ]` duran madde (done-but-open)
  YAKALAMAZ      : maddenin METNİNİN sessizce değişmesi (kimlik duruyorsa sessiz) ·
                   yanlış kapatma (madde `[x]` ama iş bitmemiş) — onu ancak insan bilir
  BİLİNEN ATLATMA: kimliksiz yazılmış yeni madde — kapı onu SAYAR ama KIRIK saymaz
                   (depoda kimliksiz eski maddeler var; kırık saymak gürültü üretirdi)
  YÜKSELTME YOLU : kimliksiz madde sayısı bugünkü taban değerin ÜSTÜNE çıkarsa
                   kırmızıya çevirmek (tavan bugün ölçülüp yazıldı)

Çıkış: 0 geçti · 1 KIRIK · 2 KOŞAMADI
"""
from __future__ import annotations
import io, re, subprocess, sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

KOK = Path(__file__).resolve().parent.parent
TODO = KOK / "TODO.md"

# Madde satiri: "- [ ] **V-05 ..." / "- [x] ~~**B-172 ..."
MADDE = re.compile(r"^\s*- \[([ xX])\]\s*(.*)$")

# Kimlik: V-05 · B-172 · HK-3 · M-01b · B-23a · C-NEW-01 · HK-tray
# ⚠ İLK YAZIMDA YALNIZ RAKAM KABUL EDİYORDU ve depodaki gerçek kimliklerin bir
#   kısmını (HK-tray, B-23a, C-NEW-01, M-01b) "kimliksiz" diye KIRIK saydı. Kapının
#   ölçütü, ölçtüğü dosyanın GERÇEĞİNE uymak zorunda; uymayan kapı gürültü üretir
#   ve gürültülü kapı kapatılır.
# ⚠ PARANTEZLİ EK KİMLİĞİN PARÇASIDIR: `B-172` ile `B-172(c2)` AYRI maddelerdir.
#   İlk yazımda parantez atılıyordu ve ikisi MÜKERRER görünüyordu — yani kapı,
#   olmayan bir kusuru bildiriyordu (yanlış alarm, gerçek dup'ları gölgeler).
# UYARI  BESINCI KALIBRASYON (19.09): desen `B-98-gen` ve `B-172(c2)` kimliklerini
#   KISALTIYORDU (`B-98` / `B-172`) ve onlari asil maddelerin MUKERRERI gibi
#   gosteriyordu. Sebep: ek parcalar OPSIYONELDI ve `\b` onlardan ONCE de
#   eslesiyordu — yani desen "en kisa kabul edilebilir" kimligi aliyordu.
#   Cozum: ekleri tekrarli yapip ARDINDAN gelen `-` ya da `(` varsa eslesmeyi
#   REDDETMEK. Yanlis pozitif gurultusu boylece VERIDEN degil DESENDEN cikti.
KIMLIK = re.compile(
    r"\*\*~{0,2}\s*([A-Z]{1,4}-[A-Za-z0-9]{1,8}(?:-[A-Za-z0-9]{1,6})*(?:\([A-Za-z0-9]{1,4}\))?)(?![-(\w])")

# Arsiv bolumundeki maddeler kimlik istemez (tarihsel kayit).
ARSIV_BASLIK = re.compile(r"^#+\s*(Arşiv|ARŞİV|Archive)", re.M)

# KIMLIKSIZ MADDE TAVANI — bugun olculdu (19.09.2026). Kirik saymiyoruz cunku
# depoda eski kimliksiz maddeler var; ama SAYI ARTARSA kapi kirmiziya doner.
# Tavan bir hedef degil, bir TABAN: yeni kimliksiz madde eklenmesin diye.
KIMLIKSIZ_TAVAN = 10
# Mukerrer kimlik tabani. 19.09'da 6 olcuLDU, ayni gun SIFIRA indi (V-16):
# ikisi DESEN KUSURUYDU (`B-98-gen` / `B-172(c2)` kisaltiliyordu), dordu GERCEKTI
# ve birlestirildi. Tavan artik 0 — yeni mukerrer kimlik KIRAR.
MUKERRER_TAVAN = 0


def maddeleri_cikar(metin: str) -> tuple[dict[str, bool], list[str], list[str]]:
    """{kimlik: kapali_mi} · mükerrer kimlikler · kimliksiz madde metinleri."""
    arsiv = ARSIV_BASLIK.search(metin)
    sinir = arsiv.start() if arsiv else len(metin)

    kimlikli: dict[str, bool] = {}
    kimliksiz: list[str] = []
    mukerrer: list[str] = []

    for satir in metin[:sinir].splitlines():
        m = MADDE.match(satir)
        if not m:
            continue
        kapali = m.group(1).lower() == "x"
        k = KIMLIK.search(m.group(2))
        if not k:
            kimliksiz.append(m.group(2)[:70])
            continue
        kid = k.group(1)
        if kid in kimlikli:
            mukerrer.append(kid)
        kimlikli[kid] = kapali
    return kimlikli, mukerrer, kimliksiz


def onceki_surum() -> str | None:
    """HEAD'deki TODO.md. Yoksa (ilk commit) None."""
    r = subprocess.run(["git", "show", "HEAD:TODO.md"], cwd=KOK, capture_output=True)
    return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None


def kapatildigi_soylenen(n: int = 10) -> set[str]:
    """Son N commit iletisinde KAPANDIĞI SÖYLENEN madde kimlikleri.

    ⚠ İLK YAZIMDA "iletide geçen HER kimlik" sayılıyordu ve YANLIŞ ALARM verdi:
      commit'lerde yeni AÇILAN maddeler de anılıyor ("V-15 açıldı"). Bir kimliğin
      ANILMASI kapandığı anlamına GELMEZ. Ölçüt daraltıldı: ya `Closes:` fragmanı,
      ya da kimliğin AYNI SATIRINDA bir kapanış sözcüğü.
    """
    r = subprocess.run(["git", "log", f"-{n}", "--format=KONU:%s%n%b%n--"],
                       cwd=KOK, capture_output=True)
    if r.returncode != 0:
        return set()

    kapanis = re.compile(r"KAPANDI|KAPATILDI|closes?\b|✅", re.I)
    kimlik = re.compile(r"\b([A-Z]{1,4}-[A-Za-z0-9]{1,8})\b")
    bulunan: set[str] = set()
    for satir in r.stdout.decode("utf-8", "replace").splitlines():
        if satir.strip().lower().startswith("closes:"):
            bulunan.update(kimlik.findall(satir))
            continue
        # UYARI  GOVDE METNI KAPANIS BEYANI DEGILDIR (dorduncu kalibrasyon, 19.09).
        #   Kapi kendi commit'imi yakaladi: `Kirmizi kip: bos commit
        #   "test: V-17 KAPANDI" -> kapi V-17'yi YAKALADI` cumlesi bir DENEYIN
        #   ANLATIMIYDI, bir kapanis iddiasi degil. Govde serbest metindir ve
        #   kapanis sozcuklerini ALINTILAR.
        #   Olcut daraltildi: kapanis sozcugu yalniz KONU satirinda sayilir; govdede
        #   yalniz ACIK `Closes:` fragmani gecerli.
        #   TAKAS ACIK YAZILIYOR (Solum'un asimetrisi): bu degisiklik bir YANLIS
        #   ALARMI kaldiriyor ama bir YANLIS NEGATIF acabilir — kapanisi yalniz
        #   govdede anan bir commit artik goruluemez. Panzehir `Closes:` fragmani ve
        #   o BILINCLI bir eylem; gorunmez bir kayip degil.
        if not satir.startswith("KONU:"):
            continue
        # UYARI  SATIR DEGIL PARCA: olcut once SATIR duzeyindeydi ve YANLIS ALARM
        #   verdi -- `docs: V-15 kapandi - V-05 5/6 adim - V-17 acildi` satirinda uc
        #   kimlik var ama yalniz BIRI kapaniyor. Satiri ayraclardan bolup her parcayi
        #   ayri degerlendirmek, kapanis sozcugunu DOGRU kimlige bagliyor.
        #   (Bu kapinin UCUNCU kalibrasyon duzeltmesi; her biri bir yanlis alarmdan
        #   dogdu ve gurultulu kapi, kapatilan kapidir.)
        for parca in re.split(r"[\u00b7;]", satir):
            if kapanis.search(parca):
                bulunan.update(kimlik.findall(parca))
    return bulunan


if not TODO.exists():
    print(f"KOŞAMADI  TODO.md yok: {TODO}")
    sys.exit(2)

simdi, mukerrer, kimliksiz = maddeleri_cikar(io.open(TODO, encoding="utf-8").read())

if not simdi:
    print("KOŞAMADI  hiç madde bulunamadı — TODO biçimi değişmiş olabilir; "
          "bu kapı hiçbir şey ölçmüyor demektir")
    sys.exit(2)

kirik: list[str] = []

# ── 1. KAYIP MADDE — bugünkü hatanın tam karşılığı ───────────────────────────
eski_metin = onceki_surum()
if eski_metin is None:
    print("UYARI  önceki sürüm okunamadı (ilk commit?) — kayıp madde ÖLÇÜLEMEDİ")
else:
    eski, _, _ = maddeleri_cikar(eski_metin)
    kayip = sorted(set(eski) - set(simdi))
    if kayip:
        kirik.append("kayip-madde")
        print(f"KIRIK  {len(kayip)} madde KAYBOLDU: {', '.join(kayip)}")
        print("       Madde SİLİNMEZ: bittiyse `[x]`, gereksizse ARŞİV'e taşınır.")
        print("       (Sık sebep: düzenlemede sınırı BOŞ SATIR sanmak — maddeler "
              "bitişikse sonrakiler de silinir.)")
    else:
        print(f"OK     kayıp madde yok ({len(eski)} → {len(simdi)} kimlik)")

# ── 2. MÜKERRER KİMLİK ───────────────────────────────────────────────────────
# ⚠ MÜKERRER DE TAVANLI, kimliksiz gibi: ilk koşumda 5 GERÇEK dup buldu
#   (B-06 ve B-12 iki ayrı bölümde birer kez daha yazılmış — `todo-verification.md`
#   S3'ün uyardığı sınıf). Bugün kırmızıya çevirmek bütün işi durdururdu; taban
#   yazıldı, ARTIŞ kırar.
if len(set(mukerrer)) > MUKERRER_TAVAN:
    kirik.append("mukerrer")
    print(f"KIRIK  mükerrer kimlik {len(set(mukerrer))} > tavan {MUKERRER_TAVAN}: "
          f"{', '.join(sorted(set(mukerrer)))}")
    print("       Aynı numara iki maddede; biri kapatılınca öteki sessizce kaybolur.")
elif mukerrer:
    print(f"UYARI  mükerrer kimlik {len(set(mukerrer))} (tavan {MUKERRER_TAVAN}, eski borç): "
          f"{', '.join(sorted(set(mukerrer)))}")
else:
    print(f"OK     kimlikler tekil ({len(simdi)} madde)")

# ── 3. KİMLİKSİZ MADDE — sayılır, tavanı aşarsa kırılır ─────────────────────
if len(kimliksiz) > KIMLIKSIZ_TAVAN:
    kirik.append("kimliksiz")
    print(f"KIRIK  kimliksiz madde {len(kimliksiz)} > tavan {KIMLIKSIZ_TAVAN}. "
          f"Yeni madde kimlikle yazılır; kimliksiz madde aranamaz ve kapatılamaz.")
    for b in kimliksiz[:5]:
        print(f"       · {b}")
else:
    print(f"OK     kimliksiz madde {len(kimliksiz)} ≤ tavan {KIMLIKSIZ_TAVAN} (eski borç)")

# ── 4. DONE-BUT-OPEN (commit-discipline S1'in mekanik hâli) ─────────────────
denen = kapatildigi_soylenen()
acik_ama_kapandi_denen = sorted(k for k in denen if simdi.get(k) is False)
if acik_ama_kapandi_denen:
    kirik.append("done-but-open")
    print(f"KIRIK  commit'te KAPANDI denen ama TODO'da hâlâ AÇIK: "
          f"{', '.join(acik_ama_kapandi_denen)}")
    print("       Commit bir maddeyi kapatıyorsa AYNI commit'te `[x]` + hash yazılır "
          "(commit-discipline.md S1).")
else:
    print("OK     done-but-open yok (son 10 commit)")

print()
if kirik:
    print(f"KIRIK · {len(kirik)} bulgu")
    sys.exit(1)
acik = sum(1 for v in simdi.values() if not v)
print(f"Denetim geçti · {len(simdi)} madde ({acik} açık · {len(simdi) - acik} kapalı)")
