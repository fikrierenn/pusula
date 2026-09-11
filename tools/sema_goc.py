"""SEMA EŞ-ANLAMLI ALAN GÖÇÜ — aynı kavramın farklı adlarını kanonik ada katlar.

Neden var (plan-44 F2): aynı kavram sema'da 4 ayrı adla yazılmıştı (`kanit`/`dogrulama`/
`olculdu`/`olcum`), açıklama 4 adla, uygulama 4 adla. Makine hangisini okuyacağını bilemez;
insan da her kaydı ayrı öğrenmek zorunda kalır.

NEDEN SATIR-BAZLI (yaml round-trip DEĞİL):
  · `yaml.safe_load` + `dump` YORUMLARI ve blok-skaler biçimini (`>-`) SİLER. sema'daki
    yorumlar bilgi taşıyor (`# --- ERP iç ---`, kolon yanı notları).
  · ruamel.yaml kurulu değil ve bu iş için bağımlılık eklemeye değmez.
  · Bu göç zaten satır-yerel: yalnız `    <eski>:` anahtar belirtecini değiştiriyoruz,
    satırın kalanına ve öteki her şeye DOKUNMUYORUZ (byte-byte aynı kalıyor).

GÜVENLİK — üç kapı:
  1. ÇATIŞMA: kanonik ad o kayıtta ZATEN varsa rename mükerrer anahtar üretir ve YAML
     sessizce birini yutar. Böyle kayıtlar ATLANIR ve raporlanır (elle karar).
  2. EŞDEĞERLİK: yazmadan önce yeni metin safe_load edilir ve eski yapının
     "beklenen dönüşümü" ile BİREBİR karşılaştırılır. Fark varsa HİÇBİR ŞEY yazılmaz.
  3. Varsayılan KURU KOŞU. Yazmak için `--uygula` gerekir.

Eşleme tek kaynaktan gelir: `sema/_sozlesme.yaml` (`esanlamli` + `esanlamli_dosya_bazli`).
Burada ikinci bir liste tutulmaz.

Kullanım:
    python tools/sema_goc.py                 # kuru koşu (rapor)
    python tools/sema_goc.py --uygula
    python tools/sema_goc.py --dosya metrics --uygula
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO = Path(__file__).resolve().parents[1]
SEMA = REPO / "sema"
DOSYALAR = ["entities", "bridges", "codes", "metrics", "queries"]

UST_BOLUM = re.compile(r"^([A-Za-z0-9_]+):")
MAP_GIRDI = re.compile(r"^  ([^\s#][^:]*):")        # "  dbo.urn:" / "  marj_kdv_tabani:"
LISTE_GIRDI = re.compile(r"^  - ")                  # "  - id: urn-kdv-oran"
ALAN = re.compile(r"^(    )([A-Za-z0-9_À-ɏ]+)(:)")  # tam 4 boşluk girintili alan

# Elle karar verilmiş tekil vakalar — gerekçesi ZORUNLU.
# İçerik okunarak belirlendi (2026-09-11); toplu eşlemeye sokulamaz çünkü kayıtta hem
# `aciklama` hem `note` var ve ikisi FARKLI şey söylüyor.
OZEL = {
    ("metrics", "kampanya_indirim_orani", "aciklama"): (
        "kural",
        "icerigi formul ('Brut = ... Oran = indirim/brut'), tanim degil; `note` zaten "
        "ayri bir uyari tasiyor (3al2ode teorik %33 vs efektif %25-26).",
    ),
}


def kosamadi(mesaj):
    print("KOSAMADI  %s" % mesaj)
    sys.exit(2)


def eslemeyi_oku():
    """Kanonik eşlemeyi SÖZLEŞMEDEN al — ikinci liste tutma."""
    import yaml
    yol = SEMA / "_sozlesme.yaml"
    if not yol.exists():
        kosamadi("sozlesme yok: %s" % yol)
    soz = yaml.safe_load(yol.read_text(encoding="utf-8"))
    genel = {}
    for kanonik, eskiler in (soz.get("esanlamli") or {}).items():
        for e in eskiler:
            genel[e] = kanonik
    dosyaya_ozel = defaultdict(dict)
    for dosya, harita in (soz.get("esanlamli_dosya_bazli") or {}).items():
        for kanonik, eskiler in (harita or {}).items():
            for e in eskiler:
                dosyaya_ozel[dosya][e] = kanonik
    return genel, dosyaya_ozel


def kayit_tara(satirlar):
    """[(id, bas, son)] — her kaydın satır aralığı (0-tabanlı, son hariç)."""
    baslangiclar = []
    for i, s in enumerate(satirlar):
        if s[:1] not in (" ", "", "#") and UST_BOLUM.match(s):
            baslangiclar.append((None, i))            # bölüm sınırı
        elif LISTE_GIRDI.match(s):
            m = re.search(r"\bid:\s*\"?([^\"#\s]+)", s)
            baslangiclar.append((m.group(1) if m else "[liste]", i))
        elif MAP_GIRDI.match(s):
            baslangiclar.append((MAP_GIRDI.match(s).group(1).strip(), i))
    sonuc = []
    for n, (kid, bas) in enumerate(baslangiclar):
        son = baslangiclar[n + 1][1] if n + 1 < len(baslangiclar) else len(satirlar)
        if kid is not None:
            sonuc.append((kid, bas, son))
    return sonuc


def alanlari_bul(satirlar, bas, son):
    """{alan_adi: [satir_no]} — yalnız 4 boşluk girintili üst seviye alanlar."""
    bulunan = defaultdict(list)
    for i in range(bas, son):
        m = ALAN.match(satirlar[i])
        if m:
            bulunan[m.group(2)].append(i)
    return bulunan


def main():
    uygula = "--uygula" in sys.argv
    tek = None
    if "--dosya" in sys.argv:
        i = sys.argv.index("--dosya")
        if i + 1 < len(sys.argv):
            tek = sys.argv[i + 1]
    try:
        import yaml
    except ImportError:
        kosamadi("pyyaml yok: pip install pyyaml")

    genel, dosyaya_ozel = eslemeyi_oku()
    hedefler = [tek] if tek else DOSYALAR
    for d in hedefler:
        if d not in DOSYALAR:
            kosamadi("bilinmeyen dosya: %s" % d)

    toplam_degisen = 0
    toplam_catisan = 0
    yazilacak = {}

    for dosya in hedefler:
        yol = SEMA / ("%s.yaml" % dosya)
        if not yol.exists():
            kosamadi("yok: %s" % yol)
        # Satır sonunu KORU: sema dosyaları depoda CRLF. LF'e çevirmek dosyanın tamamını
        # "değişmiş" gösterir (başka makinede dev diff) — göç satır-yerel kalmalı.
        ham_bayt = yol.read_bytes()
        satir_sonu = "\r\n" if ham_bayt.count(b"\r\n") > ham_bayt.count(b"\n") // 2 else "\n"
        ham = ham_bayt.decode("utf-8")
        satirlar = ham.replace("\r\n", "\n").split("\n")
        esleme = dict(genel)
        esleme.update(dosyaya_ozel.get(dosya, {}))

        eski_yapi = yaml.safe_load(ham)
        degisiklikler = []     # (satir_no, eski_ad, yeni_ad, kayit_id)
        catisanlar = []

        for kid, bas, son in kayit_tara(satirlar):
            alanlar = alanlari_bul(satirlar, bas, son)
            mevcut = set(alanlar)
            for eski_ad, satir_nolari in list(alanlar.items()):
                ozel = OZEL.get((dosya, kid, eski_ad))
                yeni_ad = ozel[0] if ozel else esleme.get(eski_ad)
                if not yeni_ad or yeni_ad == eski_ad:
                    continue
                if yeni_ad in mevcut:
                    catisanlar.append((kid, eski_ad, yeni_ad))
                    continue
                for n in satir_nolari:
                    degisiklikler.append((n, eski_ad, yeni_ad, kid))
                mevcut.add(yeni_ad)   # aynı kayıtta ikinci bir eski ad aynı hedefe gitmesin

        if not degisiklikler and not catisanlar:
            print("%-10s degisiklik yok" % dosya)
            continue

        yeni_satirlar = list(satirlar)
        for n, eski_ad, yeni_ad, _ in degisiklikler:
            yeni_satirlar[n] = ALAN.sub(
                lambda m, y=yeni_ad: "%s%s%s" % (m.group(1), y, m.group(3)),
                yeni_satirlar[n], count=1)
        yeni_metin = "\n".join(yeni_satirlar)

        # ── KAPI 2: eşdeğerlik ──
        try:
            yeni_yapi = yaml.safe_load(yeni_metin)
        except Exception as ex:
            kosamadi("%s: gocten sonra YAML bozuldu: %s" % (dosya, str(ex)[:180]))
        beklenen = donustur(eski_yapi, dosya, esleme, degisiklikler)
        if yeni_yapi != beklenen:
            fark_yaz(dosya, beklenen, yeni_yapi)
            kosamadi("%s: esdegerlik kanitlanamadi — HICBIR SEY yazilmadi" % dosya)

        print("%-10s %d alan yeniden adlandirilacak, %d catisma atlandi"
              % (dosya, len(degisiklikler), len(catisanlar)))
        ozet = defaultdict(int)
        for _, e, y, _ in degisiklikler:
            ozet[(e, y)] += 1
        for (e, y), n in sorted(ozet.items()):
            print("             %-18s -> %-10s  %d" % (e, y, n))
        for kid, e, y in catisanlar:
            print("    CATISMA  %s: hem `%s` hem `%s` var — elle karar" % (kid, e, y))

        toplam_degisen += len(degisiklikler)
        toplam_catisan += len(catisanlar)
        yazilacak[yol] = yeni_metin

    print()
    print("Toplam %d alan · %d catisma." % (toplam_degisen, toplam_catisan))
    if not uygula:
        print("KURU KOSU — yazilmadi. Uygulamak icin: python tools/sema_goc.py --uygula")
        return
    for yol, metin in yazilacak.items():
        yol.write_text(metin, encoding="utf-8", newline="\n")
        print("yazildi: %s" % yol.name)


def donustur(yapi, dosya, esleme, degisiklikler):
    """Eski yapının BEKLENEN hâli — yalnız gerçekten değiştirilen (kayit,alan) çiftleri."""
    hedef = defaultdict(dict)
    for _, eski_ad, yeni_ad, kid in degisiklikler:
        hedef[kid][eski_ad] = yeni_ad
    if not isinstance(yapi, dict):
        return yapi
    sonuc = {}
    for bolum, icerik in yapi.items():
        if isinstance(icerik, dict):
            yeni_bolum = {}
            for kid, govde in icerik.items():
                yeni_bolum[kid] = kaydi_donustur(govde, hedef.get(str(kid), {}))
            sonuc[bolum] = yeni_bolum
        elif isinstance(icerik, list):
            yeni_liste = []
            for govde in icerik:
                kid = str(govde.get("id")) if isinstance(govde, dict) else None
                yeni_liste.append(kaydi_donustur(govde, hedef.get(kid, {})))
            sonuc[bolum] = yeni_liste
        else:
            sonuc[bolum] = icerik
    return sonuc


def kaydi_donustur(govde, harita):
    if not harita or not isinstance(govde, dict):
        return govde
    return {harita.get(k, k): v for k, v in govde.items()}


def fark_yaz(dosya, beklenen, gercek):
    print("ESDEGERLIK KIRIK — %s" % dosya)
    if not (isinstance(beklenen, dict) and isinstance(gercek, dict)):
        print("  kok tipi farkli"); return
    for bolum in set(beklenen) | set(gercek):
        b, g = beklenen.get(bolum), gercek.get(bolum)
        if b == g:
            continue
        print("  bolum %s farkli" % bolum)
        if isinstance(b, dict) and isinstance(g, dict):
            for kid in list(set(b) | set(g))[:10]:
                if b.get(kid) != g.get(kid):
                    print("    kayit %s:" % kid)
                    print("      beklenen alanlar: %s" % sorted(b.get(kid, {}) or {}))
                    print("      gercek   alanlar: %s" % sorted(g.get(kid, {}) or {}))


if __name__ == "__main__":
    main()
