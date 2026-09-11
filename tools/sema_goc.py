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
import subprocess
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


def blok_haritasi(baslik_satiri):
    """Kaydın gövdesi BLOK harita mı (altına 4 boşluklu alan eklenebilir mi)?

    Hayır olduğu iki hâl var ve ikisi de araya satır eklenince YAML'ı bozar:
      `  X: {a: 1}`      → satır-içi (flow) harita
      `  X: "bir metin"` → skaler değer (sema'da 4 fifo_* kaydı böyle)
    İkisi de ATLANIR ve raporlanır — atlanan iş yapılmış sayılmaz.
    """
    kalan = baslik_satiri.split(":", 1)[-1].strip()
    return kalan == "" or kalan.startswith("#")


def baglari_kur(uygula, tek_dosya):
    """`kullanir:` referans grafını kur — prose'a gömülü bağları AÇIK alana taşı.

    Tespit BU DOSYADA DEĞİL: `sema_denetim.py --oneri-baglar` üretir (salt-okuma), burası
    yalnız yazar. Tespiti iki yere kopyalamak `emitter-ayrimi` ihlali olurdu — çekirdek bir,
    emitter çok.

    Yerleştirme: kaydın BAŞLIK satırından hemen sonra 4 boşluk girintili yeni satır. Kayıtta
    zaten `kullanir:` varsa yalnız TEK SATIRLIK liste biçimi (`[a, b]`) genişletilir; blok
    biçim ATLANIR ve raporlanır (atlanan iş yapılmış sayılmaz).
    """
    import json
    import yaml

    p = subprocess.run([sys.executable, str(Path(__file__).with_name("sema_denetim.py")),
                        "--oneri-baglar"], capture_output=True)
    if p.returncode != 0:
        kosamadi("sema_denetim.py --oneri-baglar basarisiz: %s"
                 % p.stderr.decode("utf-8", "replace")[:300])
    try:
        oneriler = json.loads(p.stdout.decode("utf-8", "replace"))
    except json.JSONDecodeError as ex:
        kosamadi("oneri JSON bozuk: %s" % ex)

    per_dosya = defaultdict(dict)
    for o in oneriler:
        per_dosya[o["dosya"]][o["id"]] = o["oneriler"]

    toplam, atlanan_top = 0, 0
    yazilacak = {}
    for dosya in ([tek_dosya] if tek_dosya else DOSYALAR):
        hedefler = per_dosya.get(dosya)
        if not hedefler:
            print("%-10s bag onerisi yok" % dosya)
            continue
        yol = SEMA / ("%s.yaml" % dosya)
        ham_bayt = yol.read_bytes()
        satir_sonu = "\r\n" if ham_bayt.count(b"\r\n") > ham_bayt.count(b"\n") // 2 else "\n"
        ham = ham_bayt.decode("utf-8")
        satirlar = ham.replace("\r\n", "\n").split("\n")
        eski_yapi = yaml.safe_load(ham)

        eklenecek = []   # (satir_no, metin, kid, refler)
        atlanan = []
        beklenen_ek = {}
        for kid, bas, son in kayit_tara(satirlar):
            refler = hedefler.get(kid)
            if not refler:
                continue
            # Satır-içi (flow) harita: `  X: {key: [...], grain: "..."}`. Altına blok anahtar
            # eklenemez — YAML "expected <block end>" verir. ATLANIR, raporlanır.
            if not blok_haritasi(satirlar[bas]):
                atlanan.append((kid, "blok harita degil (satir-ici deger/flow) — elle ekle"))
                continue
            alanlar = alanlari_bul(satirlar, bas, son)
            if "kullanir" in alanlar:
                n = alanlar["kullanir"][0]
                mevcut = satirlar[n]
                if "[" in mevcut and "]" in mevcut:
                    ic = mevcut[mevcut.index("[") + 1:mevcut.rindex("]")].strip()
                    var_olan = [x.strip() for x in ic.split(",") if x.strip()]
                    yeni = var_olan + [r for r in refler if r not in var_olan]
                    eklenecek.append((n, "    kullanir: [%s]" % ", ".join(yeni), kid, refler))
                    beklenen_ek[kid] = yeni
                else:
                    atlanan.append((kid, "kullanir blok biciminde — elle ekle"))
                continue
            eklenecek.append((bas + 1, "    kullanir: [%s]" % ", ".join(refler), kid, refler))
            beklenen_ek[kid] = list(refler)

        if not eklenecek and not atlanan:
            print("%-10s degisiklik yok" % dosya)
            continue

        yeni_satirlar = list(satirlar)
        # Var olan satırı DEĞİŞTİR (aynı no) vs YENİ satır EKLE (araya) ayrı işlenir;
        # ekleme sondan başa yapılır ki satır numaraları kaymasın.
        degistir = {n: m for n, m, kid, _ in eklenecek if satirlar[n].lstrip().startswith("kullanir:")}
        ekle_listesi = [(n, m) for n, m, kid, _ in eklenecek if n not in degistir]
        for n, m in degistir.items():
            yeni_satirlar[n] = m
        for n, m in sorted(ekle_listesi, reverse=True):
            yeni_satirlar.insert(n, m)
        yeni_metin = "\n".join(yeni_satirlar)

        try:
            yeni_yapi = yaml.safe_load(yeni_metin)
        except Exception as ex:
            kosamadi("%s: bag kurulunca YAML bozuldu: %s" % (dosya, str(ex)[:200]))
        beklenen = bag_beklenen(eski_yapi, beklenen_ek)
        if yeni_yapi != beklenen:
            fark_yaz(dosya, beklenen, yeni_yapi)
            kosamadi("%s: esdegerlik kanitlanamadi — HICBIR SEY yazilmadi" % dosya)

        print("%-10s %d kayda bag eklendi (%d referans)"
              % (dosya, len(eklenecek), sum(len(r) for _, _, _, r in eklenecek)))
        for kid, sebep in atlanan:
            print("    ATLANDI  %s — %s" % (kid, sebep))
        toplam += len(eklenecek)
        atlanan_top += len(atlanan)
        yazilacak[yol] = (yeni_metin, satir_sonu)

    print()
    print("Toplam %d kayit baglandi · %d atlandi." % (toplam, atlanan_top))
    if not uygula:
        print("KURU KOSU — yazilmadi. Uygulamak icin: --baglari-kur --uygula")
        return
    for yol, (metin, se) in yazilacak.items():
        yol.write_bytes(metin.replace("\n", se).encode("utf-8"))
        print("yazildi: %s" % yol.name)


def alan_ekle(uygula, json_yolu):
    """Genel ilkel: verilen kayıtlara verilen alanları ekle (JSON'dan).

    JSON: [{"dosya": "metrics", "id": "net_ciro", "alanlar": {"tip": "basit", ...}}, …]
    Var olan alanın ÜSTÜNE YAZMAZ — atlar ve raporlar (elle yazılmış değer korunur).
    Aynı eşdeğerlik kapısı: safe_load(yeni) == beklenen(eski) değilse hiçbir şey yazılmaz.
    """
    import json
    import yaml

    yol = Path(json_yolu)
    if not yol.exists():
        kosamadi("json yok: %s" % yol)
    try:
        istek = json.loads(yol.read_text(encoding="utf-8"))
    except json.JSONDecodeError as ex:
        kosamadi("json bozuk: %s" % ex)

    per_dosya = defaultdict(dict)
    for o in istek:
        per_dosya[o["dosya"]][str(o["id"])] = o["alanlar"]

    toplam, atlanan_top = 0, 0
    yazilacak = {}
    for dosya, hedefler in sorted(per_dosya.items()):
        if dosya not in DOSYALAR:
            kosamadi("bilinmeyen dosya: %s" % dosya)
        p = SEMA / ("%s.yaml" % dosya)
        ham_bayt = p.read_bytes()
        se = "\r\n" if ham_bayt.count(b"\r\n") > ham_bayt.count(b"\n") // 2 else "\n"
        ham = ham_bayt.decode("utf-8")
        satirlar = ham.replace("\r\n", "\n").split("\n")
        eski_yapi = yaml.safe_load(ham)

        ekleme = []        # (satir_no, metinler)
        beklenen_ek = {}
        atlanan = []
        bulunan = set()
        for kid, bas, son in kayit_tara(satirlar):
            alanlar_istek = hedefler.get(kid)
            if not alanlar_istek:
                continue
            bulunan.add(kid)
            if not blok_haritasi(satirlar[bas]):
                # Satır-içi (flow) harita `  X: {a: 1, b: 2}` → süslü parantezin İÇİNE yaz.
                # Tek satırda açılıp kapanmıyorsa dokunma (çok satırlı flow riskli).
                satir = satirlar[bas]
                kalan = satir.split(":", 1)[-1].strip()
                if not (kalan.startswith("{") and kalan.endswith("}")):
                    atlanan.append((kid, "coklu-satir/flow olmayan deger — elle ekle"))
                    continue
                ic_mevcut = set(re.findall(r"[{,]\s*([A-Za-z0-9_]+)\s*:", kalan))
                yaz = {a: v for a, v in alanlar_istek.items() if a not in ic_mevcut}
                kor = [a for a in alanlar_istek if a in ic_mevcut]
                if kor:
                    atlanan.append((kid, "zaten var, korundu: %s" % ", ".join(kor)))
                if not yaz:
                    continue
                ek = ", ".join("%s: %s" % (a, yaml_deger(v)) for a, v in yaz.items())
                aci = satir.index("{")
                satirlar[bas] = satir[:aci + 1] + ek + ", " + satir[aci + 1:].lstrip()
                beklenen_ek[kid] = yaz
                continue
            mevcut = set(alanlari_bul(satirlar, bas, son))
            yazilacak_alan = {a: v for a, v in alanlar_istek.items() if a not in mevcut}
            korunan = [a for a in alanlar_istek if a in mevcut]
            if korunan:
                atlanan.append((kid, "zaten var, korundu: %s" % ", ".join(korunan)))
            if not yazilacak_alan:
                continue
            metinler = ["    %s: %s" % (a, yaml_deger(v)) for a, v in yazilacak_alan.items()]
            ekleme.append((bas + 1, metinler))
            beklenen_ek[kid] = yazilacak_alan
        eksik = sorted(set(hedefler) - bulunan)
        for kid in eksik:
            atlanan.append((kid, "KAYIT BULUNAMADI"))

        # `beklenen_ek` flow-harita yazımını da kapsar (o kayıtlarda `ekleme` boş kalır ama
        # `satirlar` yerinde değişmiştir) — ikisinden biri doluysa yazma yapılmalı.
        if not ekleme and not beklenen_ek:
            print("%-10s eklenecek alan yok" % dosya)
            for kid, sebep in atlanan:
                print("    ATLANDI  %s — %s" % (kid, sebep))
            atlanan_top += len(atlanan)
            continue

        yeni_satirlar = list(satirlar)
        for n, metinler in sorted(ekleme, reverse=True):
            for m in reversed(metinler):
                yeni_satirlar.insert(n, m)
        yeni_metin = "\n".join(yeni_satirlar)

        try:
            yeni_yapi = yaml.safe_load(yeni_metin)
        except Exception as ex:
            kosamadi("%s: alan eklenince YAML bozuldu: %s" % (dosya, str(ex)[:200]))
        beklenen = alan_beklenen(eski_yapi, beklenen_ek)
        if yeni_yapi != beklenen:
            fark_yaz(dosya, beklenen, yeni_yapi)
            kosamadi("%s: esdegerlik kanitlanamadi — HICBIR SEY yazilmadi" % dosya)

        n_alan = sum(len(m) for _, m in ekleme)
        print("%-10s %d kayda %d alan eklenecek" % (dosya, len(ekleme), n_alan))
        for kid, sebep in atlanan:
            print("    ATLANDI  %s — %s" % (kid, sebep))
        toplam += n_alan
        atlanan_top += len(atlanan)
        yazilacak[p] = (yeni_metin, se)

    print()
    print("Toplam %d alan · %d atlanan." % (toplam, atlanan_top))
    if not uygula:
        print("KURU KOSU — yazilmadi. Uygulamak icin: --alan-ekle <json> --uygula")
        return
    for p, (metin, se) in yazilacak.items():
        p.write_bytes(metin.replace("\n", se).encode("utf-8"))
        print("yazildi: %s" % p.name)


def yaml_deger(v):
    """Skaler değeri güvenli YAML'a çevir (tırnaklama gerekirse tırnakla)."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    s = str(v)
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", s):
        return s
    return '"%s"' % s.replace('"', '\\"')


def alan_beklenen(yapi, beklenen_ek):
    if not isinstance(yapi, dict):
        return yapi
    sonuc = {}
    for bolum, icerik in yapi.items():
        if isinstance(icerik, dict):
            sonuc[bolum] = {k: _alan_uygula(v, beklenen_ek.get(str(k)))
                            for k, v in icerik.items()}
        elif isinstance(icerik, list):
            sonuc[bolum] = [_alan_uygula(v, beklenen_ek.get(str(v.get("id"))
                                                            if isinstance(v, dict) else None))
                            for v in icerik]
        else:
            sonuc[bolum] = icerik
    return sonuc


def _alan_uygula(govde, alanlar):
    if not alanlar or not isinstance(govde, dict):
        return govde
    yeni = dict(govde)
    yeni.update(alanlar)
    return yeni


def bag_beklenen(yapi, beklenen_ek):
    """Eski yapı + yalnız `kullanir` anahtarı eklenmiş/genişletilmiş hâli."""
    if not isinstance(yapi, dict):
        return yapi
    sonuc = {}
    for bolum, icerik in yapi.items():
        if isinstance(icerik, dict):
            sonuc[bolum] = {k: _bag_uygula(v, beklenen_ek.get(str(k)))
                            for k, v in icerik.items()}
        elif isinstance(icerik, list):
            sonuc[bolum] = [_bag_uygula(v, beklenen_ek.get(str(v.get("id"))
                                                           if isinstance(v, dict) else None))
                            for v in icerik]
        else:
            sonuc[bolum] = icerik
    return sonuc


def _bag_uygula(govde, refler):
    if not refler or not isinstance(govde, dict):
        return govde
    yeni = dict(govde)
    yeni["kullanir"] = refler
    return yeni


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

    if "--baglari-kur" in sys.argv:
        return baglari_kur(uygula, tek)
    if "--alan-ekle" in sys.argv:
        i = sys.argv.index("--alan-ekle")
        if i + 1 >= len(sys.argv):
            kosamadi("--alan-ekle <json-yolu> gerekli")
        return alan_ekle(uygula, sys.argv[i + 1])

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
