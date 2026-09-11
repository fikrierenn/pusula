"""SEMA SÖZLEŞMESİNİ DENETLER — `sema/_sozlesme.yaml` vs `sema/*.yaml`.

Neden var (ölçüm 2026-09-11, plan-44): `sema/` 305 kayıtla en değerli kurumsal varlığımız
ama şemasızdı — entities'te ~100 alan adı yalnız 1 kayıtta, kanıt 4 ayrı adla, 312 kaydın
140'ında kanıt / 102'sinde damga yok, 81 çapraz referansın tamamı prose'a gömülü. Bunların
hiçbiri patlamaz; sessizce yanlış kalır.

`sema_degismez.py` ŞEMA GERÇEĞİNİ koşturur (canlı DB'ye sorar).
`sema_sorgu_dumani.py` KATALOG SORGULARINI koşturur (SQL ayakta mı).
Bu araç üçüncü eksik yarıyı kapatır: SEMA'NIN KENDİ YAPISINI denetler. DB'ye bağlanmaz,
saf dosya denetimi — o yüzden her zaman ve hızlı koşabilir (pre-commit).

Çıkış kodu — üç durum bilinçli ayrı:
    0  geçti
    1  KIRIK      (sözleşme ihlali)
    2  KOŞAMADI   (sözleşme/dosya okunamadı, YAML bozuk) — asla yeşil sayılmaz

Kullanım:
    python tools/sema_denetim.py
    python tools/sema_denetim.py --ayrintili
    python tools/sema_denetim.py --dosya metrics
    python tools/sema_denetim.py --sadece-kirik
"""
import datetime as dt
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO = Path(__file__).resolve().parents[1]
SEMA = REPO / "sema"
SOZLESME_YOL = SEMA / "_sozlesme.yaml"
DOSYALAR = ["entities", "bridges", "codes", "metrics", "queries"]

TARIH_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
# Gömülü referans taramasında gürültüyü kesmek için: kısa/genel id'ler aranmaz.
GOMULU_MIN_UZUNLUK = 8


def kosamadi(mesaj):
    """KOŞAMADI = yeşil DEĞİL. Boş dönmekle hiç koşmamak ekranda aynı görünür."""
    print("KOSAMADI  %s" % mesaj)
    sys.exit(2)


class Bulgu:
    __slots__ = ("seviye", "kural", "yer", "mesaj")

    def __init__(self, seviye, kural, yer, mesaj):
        self.seviye = seviye      # "kirik" | "uyari"
        self.kural = kural
        self.yer = yer
        self.mesaj = mesaj


def yukle(yol):
    import yaml
    try:
        metin = yol.read_text(encoding="utf-8")
    except OSError as ex:
        kosamadi("okunamadi %s: %s" % (yol.name, ex))
    try:
        return yaml.safe_load(metin)
    except Exception as ex:
        kosamadi("YAML bozuk %s: %s" % (yol.name, str(ex)[:200]))


def kayitlari_cikar(dosya, veri):
    """(bolum, id, govde) üretir. Map bölümü → anahtar=id; liste bölümü → govde['id']."""
    if not isinstance(veri, dict):
        kosamadi("%s.yaml kok dugumu harita degil" % dosya)
    for bolum, icerik in veri.items():
        if bolum in ("version", "updated", "plan"):
            continue
        if isinstance(icerik, dict):
            for k, v in icerik.items():
                yield bolum, str(k), v
        elif isinstance(icerik, list):
            for i, v in enumerate(icerik):
                kid = v.get("id") if isinstance(v, dict) else None
                yield bolum, str(kid) if kid else "[%d]" % i, v


def duz_metin(v):
    if isinstance(v, str):
        return v
    if isinstance(v, dict):
        return " ".join(duz_metin(x) for x in v.values())
    if isinstance(v, list):
        return " ".join(duz_metin(x) for x in v)
    return str(v)


def ttl_turet(guven, varsayilanlar):
    if guven is None:
        return None
    try:
        g = float(guven)
    except (TypeError, ValueError):
        return None
    if g >= 1.0:
        return None
    for aralik, gun in varsayilanlar.items():
        if aralik == "1.0" or gun is None:
            continue
        alt, ust = (float(x) for x in aralik.split("-"))
        if alt <= g <= ust:
            return int(gun)
    return None


def main():
    ayrintili = "--ayrintili" in sys.argv
    sadece_kirik = "--sadece-kirik" in sys.argv
    tek_dosya = None
    if "--dosya" in sys.argv:
        i = sys.argv.index("--dosya")
        if i + 1 < len(sys.argv):
            tek_dosya = sys.argv[i + 1]

    try:
        import yaml  # noqa: F401
    except ImportError:
        kosamadi("pyyaml yok: pip install pyyaml")

    if not SOZLESME_YOL.exists():
        kosamadi("sozlesme yok: %s" % SOZLESME_YOL)
    soz = yukle(SOZLESME_YOL)
    for gerekli in ("ortak", "tipler", "kurallar", "esanlamli"):
        if gerekli not in soz:
            kosamadi("sozlesmede '%s' bolumu yok" % gerekli)

    ortak = soz["ortak"]
    tipler = soz["tipler"]
    kurallar = soz["kurallar"]
    esanlamli = soz["esanlamli"]
    esanlamli_dosya = soz.get("esanlamli_dosya_bazli", {})
    deger_esanlamli = soz.get("deger_esanlamli", {})
    ttl_varsayilan = kurallar.get("ttl_varsayilan", {})

    hedef_dosyalar = [tek_dosya] if tek_dosya else DOSYALAR
    for d in hedef_dosyalar:
        if d not in DOSYALAR:
            kosamadi("bilinmeyen dosya: %s (secenekler: %s)" % (d, ", ".join(DOSYALAR)))

    # ── kayıtları topla ──
    kayitlar = []          # (dosya, bolum, id, govde)
    idler = defaultdict(set)   # dosya -> {id}
    for dosya in DOSYALAR:    # referans çözümü için HEPSİ okunur, denetim hedefle sınırlı
        yol = SEMA / ("%s.yaml" % dosya)
        if not yol.exists():
            kosamadi("sema dosyasi yok: %s" % yol.name)
        for bolum, kid, govde in kayitlari_cikar(dosya, yukle(yol)):
            kayitlar.append((dosya, bolum, kid, govde))
            idler[dosya].add(kid)

    bulgular = []
    bugun = dt.date.today()

    def ekle(seviye, kural, yer, mesaj):
        bulgular.append(Bulgu(seviye, kural, yer, mesaj))

    def sev(dugum, varsayilan="uyari"):
        if isinstance(dugum, dict):
            return dugum.get("seviye", varsayilan)
        return varsayilan

    # ── 1. id tekilliği ──
    sev_id = sev(kurallar.get("id_tekilligi"), "kirik")
    for dosya in hedef_dosyalar:
        gorulen = set()
        for d, bolum, kid, _ in kayitlar:
            if d != dosya:
                continue
            anahtar = (bolum, kid)
            if anahtar in gorulen:
                ekle(sev_id, "id_tekilligi", "%s:%s" % (dosya, kid), "ayni bolumde tekrar eden id")
            gorulen.add(anahtar)

    # ── 2. kayıt bazlı denetim ──
    for dosya, bolum, kid, govde in kayitlar:
        if dosya not in hedef_dosyalar:
            continue
        yer = "%s:%s" % (dosya, kid)
        tip_anahtar = "%s.%s" % (dosya, bolum)
        tip = tipler.get(tip_anahtar)
        if tip is None:
            ekle("uyari", "bilinmeyen_tip", yer, "sozlesmede tanimsiz bolum: %s" % tip_anahtar)
            continue
        if tip.get("kayit_tipi") == "metin_listesi":
            continue
        if not isinstance(govde, dict):
            ekle("uyari", "yapi", yer, "kayit harita degil (%s)" % type(govde).__name__)
            continue

        alanlar = set(govde.keys())
        muaf = bool(tip.get("ortak_muaf"))
        # Kısmi muafiyet: o kayıt tipinde kanıt BAŞKA bir mekanizmayla sağlanıyorsa
        # (ör. queries → sorgu dumanı koşumu) ilgili ortak alan aranmaz. Gerekçesi
        # sözleşmede `muafiyet_gerekcesi` alanında YAZILI olmak zorunda.
        kismi_muaf = set(tip.get("ortak_muaf_alanlar", []) or [])
        if kismi_muaf and not tip.get("muafiyet_gerekcesi"):
            ekle("kirik", "gerekcesiz_muafiyet", tip_anahtar,
                 "ortak_muaf_alanlar var ama muafiyet_gerekcesi yazilmamis")

        # Açık çapraz referanslar — koşullu kurallar da bunlara bakar, o yüzden burada toplanır.
        referanslar = [str(r) for r in (govde.get("kullanir", []) or [])]
        if dosya == "queries":
            referanslar += ["metrics:%s" % m for m in (govde.get("metrics", []) or [])]

        # 2a. ortak zorunlu — confidence
        if not muaf and "confidence" not in kismi_muaf:
            spec = ortak["zorunlu"]["confidence"]
            if "confidence" not in govde:
                ekle(sev(spec), "confidence_yok", yer, "confidence alani yok")
            else:
                try:
                    g = float(govde["confidence"])
                    alt, ust = spec["aralik"]
                    if not (alt <= g <= ust):
                        ekle("kirik", "confidence_aralik", yer,
                             "confidence %s araligin disinda [%s, %s]" % (g, alt, ust))
                except (TypeError, ValueError):
                    ekle("kirik", "confidence_tip", yer, "confidence sayi degil: %r" % govde["confidence"])

        # 2b. koşullu zorunlu — last_verified / evidence
        if not muaf:
            guven = govde.get("confidence")
            kalici = False
            try:
                kalici = float(guven) >= 1.0
            except (TypeError, ValueError):
                pass

            lv_spec = ortak["kosullu_zorunlu"]["last_verified"]
            lv = govde.get("last_verified")
            if lv is None:
                if not kalici:
                    ekle(sev(lv_spec), "damga_yok", yer, "last_verified yok (decay hesaplanamaz)")
            else:
                lv_s = lv.isoformat() if isinstance(lv, (dt.date, dt.datetime)) else str(lv)
                if not TARIH_RE.match(lv_s):
                    ekle(sev(kurallar.get("tarih_bicimi"), "kirik"), "tarih_bicimi", yer,
                         "last_verified YYYY-MM-DD degil: %r" % lv_s)
                else:
                    # stale
                    ttl = govde.get("ttl_days") or ttl_turet(guven, ttl_varsayilan)
                    if ttl:
                        yas = (bugun - dt.date.fromisoformat(lv_s)).days
                        if yas > int(ttl):
                            ekle(sev(kurallar.get("stale")), "stale", yer,
                                 "bayat: %d gun (ttl %s)" % (yas, ttl))

            ev_spec = ortak["kosullu_zorunlu"]["evidence"]
            if ("evidence" not in kismi_muaf and "evidence" not in govde
                    and govde.get("kanit_durumu") is None):
                ekle(sev(ev_spec), "kanit_yok", yer,
                     "evidence yok ve kanit_durumu beyan edilmemis")

        # 2c. tipe özel zorunlu
        for kural in tip.get("zorunlu", []) or []:
            gerekli = kural.get("alan", [])
            if not any(a in alanlar for a in gerekli):
                ekle(kural.get("seviye", "uyari"), "zorunlu_alan", yer,
                     "su alanlardan en az biri gerekli: %s" % ", ".join(gerekli))

        # 2d. bilinmeyen üst seviye alan
        bilinen = set(["id", "ayrinti"])
        bilinen |= set(ortak["zorunlu"]) | set(ortak["kosullu_zorunlu"]) | set(ortak["opsiyonel"])
        bilinen |= set(tip.get("opsiyonel", []) or [])
        bilinen |= set(tip.get("ozel", {}) or {})
        for kural in tip.get("zorunlu", []) or []:
            bilinen |= set(kural.get("alan", []))
        bilinmeyen = sorted(alanlar - bilinen)
        if bilinmeyen:
            ekle(sev(kurallar.get("bilinmeyen_ust_alan")), "bilinmeyen_alan", yer,
                 "sozlesme disi ust alan (ayrinti: altina tasi): %s" % ", ".join(bilinmeyen[:8])
                 + (" … +%d" % (len(bilinmeyen) - 8) if len(bilinmeyen) > 8 else ""))

        # 2e. eş-anlamlı (göç bekliyor)
        esler = dict(esanlamli)
        for kanonik, eski_liste in (esanlamli_dosya.get(dosya, {}) or {}).items():
            esler[kanonik] = list(esler.get(kanonik, [])) + list(eski_liste)
        for kanonik, eskiler in esler.items():
            kullanilan = [e for e in eskiler if e in alanlar]
            if kullanilan:
                ekle("uyari", "esanlamli", yer,
                     "%s -> `%s` olmali" % (", ".join(kullanilan), kanonik))

        # 2f. enum değer denetimi (+ değer düzeyi eş-anlamlı göçü)
        for alan, spec in (tip.get("ozel", {}) or {}).items():
            if not isinstance(spec, dict) or alan not in govde:
                continue
            izin = spec.get("degerler")
            if not izin:
                continue
            deger = govde[alan]
            if deger in izin:
                continue
            kanonik = None
            for hedef, eskiler in (deger_esanlamli.get(alan, {}) or {}).items():
                if deger in eskiler:
                    kanonik = hedef
                    break
            if kanonik:
                ekle("uyari", "deger_esanlamli", yer,
                     "%s=%r -> %r olmali" % (alan, deger, kanonik))
            else:
                ekle(spec.get("seviye", "uyari"), "gecersiz_deger", yer,
                     "%s=%r izinli degil: %s" % (alan, deger, ", ".join(map(str, izin))))

        # 2f2. koşullu kurallar — "tip şu ise şu alan gerekir"
        for kural in tip.get("kosullu", []) or []:
            kosul = kural.get("kosul", {})
            k_alan, k_kume = kosul.get("alan"), set(kosul.get("deger_kumesi", []))
            deger = govde.get(k_alan)
            # değer eş-anlamlıysa kanonik karşılığıyla değerlendir (göç sırasında da doğru çalışsın)
            for hedef, eskiler in (deger_esanlamli.get(k_alan, {}) or {}).items():
                if deger in eskiler:
                    deger = hedef
                    break
            if deger not in k_kume:
                continue
            if govde.get("status") in (kural.get("muaf_status") or []):
                continue
            gerek = kural.get("gerek", {})
            if "en_az_biri" in gerek and not any(a in alanlar for a in gerek["en_az_biri"]):
                ekle(kural.get("seviye", "uyari"), kural.get("ad", "kosullu"), yer,
                     "tip=%s icin su alanlardan biri gerekli: %s"
                     % (deger, ", ".join(gerek["en_az_biri"])))
            if "referans_dosyasi" in gerek:
                istenen = gerek["referans_dosyasi"]
                if not any(r.startswith(istenen + ":") for r in referanslar):
                    ekle(kural.get("seviye", "uyari"), kural.get("ad", "kosullu"), yer,
                         "tip=%s icin `kullanir:` altinda en az bir %s: referansi gerekli"
                         % (deger, istenen))

        # 2g. atomiklik
        atom = tip.get("atomiklik")
        if atom:
            uzunluk = len(duz_metin(govde))
            if uzunluk > int(atom.get("tavan_char", 4000)):
                ekle(atom.get("seviye", "uyari"), "atomiklik", yer,
                     "%d karakter — tek kayit = tek gercek degil, bol" % uzunluk)

        # 2h. referans çözümü — kullanir + queries.metrics (liste yukarıda toplandı)
        for ref in referanslar:
            if ":" not in ref:
                ekle("kirik", "referans_bicimi", yer,
                     "kullanir girdisi '<dosya>:<id>' degil: %r" % ref)
                continue
            hedef_dosya, hedef_id = ref.split(":", 1)
            if hedef_dosya not in idler:
                ekle("kirik", "cozulmeyen_referans", yer, "bilinmeyen dosya: %r" % ref)
            elif hedef_id not in idler[hedef_dosya]:
                ekle(sev(kurallar.get("cozulmeyen_referans"), "kirik"), "cozulmeyen_referans", yer,
                     "hedef yok: %r" % ref)

        # 2i. prose'a gömülü referans (graf eksik)
        beyan = set(referanslar)
        metin = duz_metin({k: v for k, v in govde.items() if k not in ("kullanir",)})
        for hedef_dosya in ("bridges", "metrics"):
            for hedef_id in idler[hedef_dosya]:
                if len(hedef_id) < GOMULU_MIN_UZUNLUK:
                    continue
                if hedef_dosya == dosya and hedef_id == kid:
                    continue
                if hedef_id in metin and ("%s:%s" % (hedef_dosya, hedef_id)) not in beyan:
                    ekle(sev(kurallar.get("gomulu_referans")), "gomulu_referans", yer,
                         "prose'da geciyor ama kullanir'de yok: %s:%s" % (hedef_dosya, hedef_id))

    # ── öneri modu: makine-okunur bağ önerisi (SALT-OKUMA — yazan taraf sema_goc.py) ──
    # Tespit mantığı TEK yerde kalsın diye burada duruyor; göç aracı bu JSON'u tüketir
    # (emitter-ayrimi: hesap çekirdeği bir, emitter çok).
    if "--oneri-baglar" in sys.argv:
        import json as _json
        oneri = defaultdict(list)
        for b in bulgular:
            if b.kural != "gomulu_referans":
                continue
            hedef = b.mesaj.split("kullanir'de yok:")[-1].strip()
            oneri[b.yer].append(hedef)
        cikti = [{"yer": yer, "dosya": yer.split(":", 1)[0], "id": yer.split(":", 1)[1],
                  "oneriler": sorted(set(refs))}
                 for yer, refs in sorted(oneri.items())]
        print(_json.dumps(cikti, ensure_ascii=False, indent=1))
        sys.exit(0)

    # ── rapor ──
    kirik = [b for b in bulgular if b.seviye == "kirik"]
    uyari = [b for b in bulgular if b.seviye != "kirik"]

    denetlenen = sum(1 for d, _, _, _ in kayitlar if d in hedef_dosyalar)
    print("SEMA DENETIM — %d kayit (%s)" % (denetlenen, ", ".join(hedef_dosyalar)))
    print()

    per_kural = defaultdict(list)
    for b in bulgular:
        per_kural[(b.seviye, b.kural)].append(b)

    print("%-6s %-22s %6s" % ("SEVIYE", "KURAL", "ADET"))
    print("-" * 38)
    for (seviye, kural), liste in sorted(per_kural.items(), key=lambda x: (x[0][0] != "kirik", -len(x[1]))):
        print("%-6s %-22s %6d" % (seviye.upper(), kural, len(liste)))
    print("-" * 38)
    print("%-6s %-22s %6d" % ("", "KIRIK toplam", len(kirik)))
    print("%-6s %-22s %6d" % ("", "UYARI toplam", len(uyari)))
    print()

    if kirik:
        print("== KIRIK ==")
        for b in kirik:
            print("  [%s] %s — %s" % (b.kural, b.yer, b.mesaj))
        print()

    if uyari and not sadece_kirik:
        print("== UYARI ==")
        for (seviye, kural), liste in sorted(per_kural.items(), key=lambda x: -len(x[1])):
            if seviye == "kirik":
                continue
            gosterilecek = liste if ayrintili else liste[:4]
            print("  %s (%d)" % (kural, len(liste)))
            for b in gosterilecek:
                print("      %s — %s" % (b.yer, b.mesaj))
            if not ayrintili and len(liste) > len(gosterilecek):
                print("      … +%d (--ayrintili ile hepsi)" % (len(liste) - len(gosterilecek)))
        print()

    if kirik:
        print("Sozlesme ihlali var. Duzelt: sema/_sozlesme.yaml kaydin tipini tanimlar;")
        print("zengin/tek-kullanimlik alanlar SILINMEZ, `ayrinti:` altina tasinir.")
        sys.exit(1)

    print("Sozlesme ihlali yok (KIRIK 0).")
    sys.exit(0)


if __name__ == "__main__":
    main()
