"""SEMA KOLONLARINI CANLI KATALOĞA BAĞLAR — drift denetimi + `columns:` üretimi.

Neden var (plan-44 F4): sema 124 entity taşıyor ama kolon açıklaması YALNIZ 1'inde vardı
(`dbo.irsHrk`). Geri kalanında `key:` listesi var — elle yazılmış, denetlenmemiş, bayatlayabilir.
"Liste elle yazılmaz" kuralı (olctum-mu-cikardim-mi §3) tam olarak bunu yasaklar.

YAKALADIĞI HATA SINIFI — ölçülmüş, uydurma değil:
  · `EncoreMerkez.dbo.Sales.SaleDate` diye bir kolon YOK, doğrusu `Date`. `entities.yaml`
    bunu zaten yazmıştı ama `queries.yaml` yine bayat kaldı — iki kayıt birbirini
    denetlemiyordu. 15 katalog sorgusunun 3'ü bu yüzden kırıktı.
  · `SalesProducts`ta `Quantity`/`RowTotal` yok (`Amount`/`TotalPrice`), header'da
    `DiscountTotalDirect` yok (`DiscountTotal`).
  · `irsHrk.ehstkID` (küçük s) vs `fatAyr.ehStkID` (büyük S) — SQL Server case-insensitive
    olduğu için ÇALIŞIR ama case-sensitive collation'a taşınırsa kırılır.

KURAL: sema'da yazan bir kolon canlıda YOKSA bu bir YALAN → KIRIK. Canlıda olup sema'da
olmayan kolon yalan değil, eksiklik → bilgi. (`error-handling.md` § Reddet mi Say mı:
çelişki reddedilir, eksiklik sayılır.)

Sorgu aracı: `sqlcli` (sql-server-conventions § SORGU ARACI — ad-hoc pymssql snippet'i yazma).

Çıkış kodu:  0 drift yok · 1 DRIFT (sema yalan söylüyor) · 2 KOŞAMADI

Kullanım:
    python tools/sema_kolon_cek.py                      # drift denetimi (tüm entity)
    python tools/sema_kolon_cek.py --ayrintili
    python tools/sema_kolon_cek.py --doldur dbo.urn     # `columns:` bloğu üret (yapıştırılır)
"""
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

REPO = Path(__file__).resolve().parents[1]
SEMA = REPO / "sema"

# Hangi entity hangi sunucu/veritabanında. Ön ek → (sqlcli profili, veritabanı).
# 2 parçalı ad (dbo.urn / depo.x / bkm.y / mhs.z / ent.w) → ERP varsayılanı.
ONEK_HARITA = {
    "EncoreMerkez": ("erp", "EncoreMerkez"),
    "DerinCrm": ("erp", "DerinCrm"),
    "BKMDATA": ("erp", "BKMDATA"),
    "BKMMaliyet": ("erp", "BKMMaliyet"),
    "DerinSISBkm": ("erp", "DerinSISBkm"),
    "BKM_GENEL": ("zirve", "BKM_GENEL"),
}
VARSAYILAN = ("erp", "DerinSISBkm")
# Linked server (ODAKJOKER.JOKER.*) katalog sorgusu OPENQUERY ister — v1 kapsamı dışı,
# ATLANMAZ, "atlandi" diye raporlanır (atlanan denetim koşmuş sayılmaz).
ATLA_ONEK = ("ODAKJOKER",)

GERCEK_NESNE_TIPLERI = {"tablo", "view", "sp", "tvf", "openquery", "sema", None}


def kosamadi(mesaj):
    print("KOSAMADI  %s" % mesaj)
    sys.exit(2)


def sqlcli(profil, veritabani, sql, max_satir=20000):
    """sqlcli ile salt-okuma sorgu → satır listesi. Hata yutulmaz.

    `sqlcli`de `--database` YOK: profil sunucu+veritabanını birlikte sabitler. Aynı sunucudaki
    başka veritabanına 3-parçalı `<db>.sys.*` ile gidilir (dashboard'un Err 208 dersiyle aynı
    mantık). `veritabani` burada yalnız hata mesajı içindir.
    """
    komut = ["sqlcli", "query", "--profile", profil,
             "--format", "json", "--read-only", "--max-rows", str(max_satir), sql]
    try:
        p = subprocess.run(komut, capture_output=True, timeout=180)
    except FileNotFoundError:
        kosamadi("sqlcli bulunamadi (global dotnet tool kurulu mu?)")
    except subprocess.TimeoutExpired:
        kosamadi("sqlcli zaman asimi (%s/%s)" % (profil, veritabani))
    cikti = p.stdout.decode("utf-8", errors="replace")
    if p.returncode != 0:
        kosamadi("sqlcli hata (%s/%s): %s"
                 % (profil, veritabani, (p.stderr.decode("utf-8", "replace") or cikti)[:300]))
    # sqlcli banner'ı ANSI renk kodu içeriyor ("\x1b[38;5;8m") — içindeki '[' JSON başlangıcı
    # sanılmasın diye önce escape dizileri temizlenir, sonra satır başındaki '[' aranır.
    cikti = re.sub(r"\x1b\[[0-9;]*m", "", cikti)
    m = re.search(r"^\s*\[", cikti, re.M)
    if not m:
        kosamadi("sqlcli JSON dondurmedi (%s/%s): %s" % (profil, veritabani, cikti[:200]))
    try:
        satirlar = json.loads(cikti[m.start():])
    except json.JSONDecodeError as ex:
        kosamadi("sqlcli JSON bozuk (%s/%s): %s" % (profil, veritabani, ex))
    if len(satirlar) >= max_satir:
        kosamadi("max-rows (%d) doldu — sonuc SESSIZCE kesilmis olabilir, siniri yukselt"
                 % max_satir)
    return satirlar


def hedef_coz(entity_id):
    """entity id → (profil, veritabani, sema, nesne) | None (atlanacaksa)."""
    parca = entity_id.split(".")
    if parca[0] in ATLA_ONEK:
        return None
    if len(parca) >= 3 and parca[0] in ONEK_HARITA:
        profil, db = ONEK_HARITA[parca[0]]
        return profil, db, parca[1], ".".join(parca[2:])
    if len(parca) == 2:
        profil, db = VARSAYILAN
        return profil, db, parca[0], parca[1]
    return None


def beyan_edilen_kolonlar(govde):
    """Kaydın İDDİA ettiği kolon adları: columns anahtarları + key listesi + pk."""
    kolonlar = set()
    c = govde.get("columns")
    if isinstance(c, dict):
        kolonlar |= {str(k) for k in c}
    k = govde.get("key")
    if isinstance(k, list):
        kolonlar |= {str(x) for x in k}
    elif isinstance(k, str):
        kolonlar |= {p.strip() for p in k.split(",") if p.strip()}
    pk = govde.get("pk")
    if isinstance(pk, str):
        # `pk` iki şekilde yazılıyor: SAF anahtar ("ehID" · "(ehID, ehSira)" · "Donem,stkID")
        # ya da AÇIKLAMALI ("(ehID, ehSira) — PK KISITI YOK ..."). Yalnız ilk ayraca kadar
        # olan kısım anahtar sayılır; o kısım saf tanımlayıcı listesi DEĞİLSE hiçbir kolon
        # iddiası türetilmez.
        #
        # Bu kural iki sahte drift'in dersidir (ölçüldü 2026-09-11, kendi aracımın ilk iki
        # koşusu): (a) `(çek)` içinden `ek` çıkarıldı, (b) kendi yazdığım açıklamadan
        # `MANTIKSAL`/`KISITI`/`tabloda` kolon sanıldı. Emin olunamayan yerde İDDİA ETME.
        bas = re.split(r"—|;|\s-\s|\bMANTIKSAL\b", pk)[0].strip()
        if bas and re.fullmatch(r"[\s(),A-Za-z0-9_]+", bas):
            kolonlar |= set(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", bas))
    elif isinstance(pk, list):
        kolonlar |= {str(x) for x in pk}
    return {x for x in kolonlar if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", x)}


def main():
    ayrintili = "--ayrintili" in sys.argv
    tip_oner = "--tip-oner" in sys.argv
    doldur = None
    if "--doldur" in sys.argv:
        i = sys.argv.index("--doldur")
        if i + 1 < len(sys.argv):
            doldur = sys.argv[i + 1]

    try:
        import yaml
    except ImportError:
        kosamadi("pyyaml yok: pip install pyyaml")

    yol = SEMA / "entities.yaml"
    if not yol.exists():
        kosamadi("yok: %s" % yol)
    veri = yaml.safe_load(yol.read_text(encoding="utf-8"))
    entities = veri.get("entities") or {}

    # ── hedefleri grupla: (profil, db) -> {nesne_adi: [entity_id]} ──
    gruplar = defaultdict(lambda: defaultdict(list))
    atlanan, cozulemeyen = [], []
    for kid, govde in entities.items():
        if not isinstance(govde, dict):
            continue
        if govde.get("tip") not in GERCEK_NESNE_TIPLERI:
            continue                      # kural/olcum notu — kolonu olmaz
        if doldur and kid != doldur:
            continue
        hedef = hedef_coz(kid)
        if hedef is None:
            (atlanan if kid.split(".")[0] in ATLA_ONEK else cozulemeyen).append(kid)
            continue
        profil, db, sema_adi, nesne = hedef
        gruplar[(profil, db)][nesne].append((kid, sema_adi, govde))

    if not gruplar:
        kosamadi("hedef entity bulunamadi%s" % (" (--doldur %s)" % doldur if doldur else ""))

    # ── --tip-oner: entity `tip`'ini CANLI KATALOGDAN türet (elle yazma) ──
    if tip_oner:
        import json as _json
        NESNE_TIP = {
            "USER_TABLE": "tablo", "VIEW": "view",
            "SQL_STORED_PROCEDURE": "sp", "EXTENDED_STORED_PROCEDURE": "sp",
            "SQL_TABLE_VALUED_FUNCTION": "tvf", "SQL_INLINE_TABLE_VALUED_FUNCTION": "tvf",
            "SQL_SCALAR_FUNCTION": "tvf", "SYNONYM": "view",
        }
        istek, bulunamadi = [], []
        for (profil, db), nesneler in gruplar.items():
            onek = "" if profil == "zirve" else "%s." % db
            liste = ", ".join("'%s'" % a.replace("'", "''") for a in sorted(nesneler))
            sql = ("SELECT s.name AS sema_adi, o.name AS nesne, o.type_desc AS nesne_tipi "
                   "FROM {p}sys.objects o JOIN {p}sys.schemas s ON s.schema_id=o.schema_id "
                   "WHERE o.name IN ({liste})".format(p=onek, liste=liste))
            canli_tip = {}
            for r in sqlcli(profil, db, sql, max_satir=5000):
                canli_tip[(str(r["sema_adi"]), str(r["nesne"]))] = str(r["nesne_tipi"])
            for nesne, kayitlar in nesneler.items():
                for kid, sema_adi, govde in kayitlar:
                    td = canli_tip.get((sema_adi, nesne))
                    if td is None:
                        bulunamadi.append(kid)
                        continue
                    esl = NESNE_TIP.get(td)
                    if esl is None:
                        bulunamadi.append("%s (bilinmeyen type_desc: %s)" % (kid, td))
                        continue
                    if govde.get("tip") == esl:
                        continue
                    istek.append({"dosya": "entities", "id": kid, "alanlar": {"tip": esl}})
        print("# %d entity tipi CANLI KATALOGDAN turetildi (sys.objects.type_desc)"
              % len(istek), file=sys.stderr)
        print("# ATANMADI (canlida yok — kural/olcum notu olabilir): %d" % len(bulunamadi),
              file=sys.stderr)
        for k in bulunamadi:
            print("#   %s" % k, file=sys.stderr)
        print(_json.dumps(istek, ensure_ascii=False, indent=1))
        return

    # ── canlı katalog ──
    canli = defaultdict(dict)   # (profil,db,sema,nesne) -> {kolon: tip}
    for (profil, db), nesneler in gruplar.items():
        adlar = sorted({n for n in nesneler})
        liste = ", ".join("'%s'" % a.replace("'", "''") for a in adlar)
        # Profil kendi veritabanını sabitliyor; başka veritabanı istendiyse katalog
        # görünümleri 3-parçalı nitelenir. zirve profilinde db adı ${ZIRVE_DATABASE}
        # ile geldiği için nitelemeden (boş ön ek) gidilir.
        onek = "" if profil == "zirve" else "%s." % db
        sql = (
            "SELECT s.name AS sema_adi, o.name AS nesne, c.name AS kolon, "
            "ty.name AS veri_tipi, c.is_nullable AS bos_olabilir "
            "FROM {p}sys.objects o "
            "JOIN {p}sys.schemas s ON s.schema_id = o.schema_id "
            "JOIN {p}sys.columns c ON c.object_id = o.object_id "
            "JOIN {p}sys.types ty ON ty.user_type_id = c.user_type_id "
            "WHERE o.name IN ({liste})".format(p=onek, liste=liste)
        )
        for r in sqlcli(profil, db, sql):
            anahtar = (profil, db, str(r["sema_adi"]), str(r["nesne"]))
            canli[anahtar][str(r["kolon"])] = str(r["veri_tipi"])

    # ── --doldur: columns bloğu üret ──
    if doldur:
        for (profil, db), nesneler in gruplar.items():
            for nesne, kayitlar in nesneler.items():
                for kid, sema_adi, govde in kayitlar:
                    kolonlar = canli.get((profil, db, sema_adi, nesne))
                    if not kolonlar:
                        kosamadi("canli katalogda bulunamadi: %s (%s/%s)" % (kid, profil, db))
                    beyan = beyan_edilen_kolonlar(govde)
                    print("# %s — %s/%s · %d kolon (canli sys.columns, %s)"
                          % (kid, profil, db, len(kolonlar), "elle YAZMA"))
                    print("    columns:")
                    for ad, tip in sorted(kolonlar.items()):
                        isaret = "  # sema'da anahtar" if ad in beyan else ""
                        print("      %s: {veri_tipi: %s, description: \"\"}%s" % (ad, tip, isaret))
        return

    # ── drift denetimi ──
    yalan = []      # sema'da var, canlıda YOK  → KIRIK
    bulunamayan = []  # nesnenin kendisi canlıda yok
    eksik_sayac = {}
    for (profil, db), nesneler in gruplar.items():
        for nesne, kayitlar in nesneler.items():
            for kid, sema_adi, govde in kayitlar:
                kolonlar = canli.get((profil, db, sema_adi, nesne))
                if not kolonlar:
                    bulunamayan.append((kid, "%s/%s" % (profil, db)))
                    continue
                beyan = beyan_edilen_kolonlar(govde)
                if not beyan:
                    continue
                canli_kucuk = {k.lower(): k for k in kolonlar}
                for b in sorted(beyan):
                    if b.lower() not in canli_kucuk:
                        yalan.append((kid, b))
                eksik_sayac[kid] = len(kolonlar) - len(beyan)

    print("SEMA KOLON DRIFT — %d entity denetlendi (%d hedef veritabani)"
          % (sum(len(v) for g in gruplar.values() for v in g.values()), len(gruplar)))
    print()
    if atlanan:
        print("ATLANDI (linked server katalogu OPENQUERY ister — koşmuş SAYILMAZ): %d" % len(atlanan))
        for k in atlanan if ayrintili else atlanan[:5]:
            print("    %s" % k)
        if not ayrintili and len(atlanan) > 5:
            print("    … +%d" % (len(atlanan) - 5))
        print()
    if cozulemeyen:
        print("HEDEF COZULEMEDI (ad kalibi <sema>.<nesne> degil): %d" % len(cozulemeyen))
        for k in cozulemeyen if ayrintili else cozulemeyen[:8]:
            print("    %s" % k)
        if not ayrintili and len(cozulemeyen) > 8:
            print("    … +%d" % (len(cozulemeyen) - 8))
        print()
    if bulunamayan:
        print("NESNE CANLIDA YOK: %d" % len(bulunamayan))
        for k, h in bulunamayan:
            print("    %s (%s)" % (k, h))
        print()

    if yalan:
        print("== DRIFT — sema'da yazan kolon CANLIDA YOK ==")
        per = defaultdict(list)
        for kid, kolon in yalan:
            per[kid].append(kolon)
        for kid, kolonlar in sorted(per.items()):
            print("  %s: %s" % (kid, ", ".join(kolonlar)))
        print()
        print("Bu bir YALAN, eksiklik degil: sema bir kolonu var diyor, canlida yok.")
        print("Once OLC (dogru adi bul), sonra sema'yi duzelt — kaydi silme.")
        sys.exit(1)

    print("Drift yok — beyan edilen kolonlarin hepsi canlida var.")
    if eksik_sayac:
        zengin = sorted(eksik_sayac.items(), key=lambda x: -x[1])[:8]
        print()
        print("Kapsama boslugu (canlida olup sema'da anilmayan kolon sayisi — eksiklik, yalan degil):")
        for kid, n in zengin:
            print("    %-48s +%d kolon" % (kid, n))
    sys.exit(0)


if __name__ == "__main__":
    main()
