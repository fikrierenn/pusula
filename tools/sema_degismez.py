# -*- coding: utf-8 -*-
"""SEMA DEĞİŞMEZLERİNİ KOŞTURUR — `sema/degismezler.json`.

NEDEN VAR
---------
Semantik katmanın eksik yarısı buydu: `queries.yaml` doğrulanmış SQL'i
SAKLAR ama kimse YENİDEN KOŞMAZ. `last_verified` + `ttl_days` bir
BAYRAKTIR, bir ÖLÇÜM değil — süresi dolduğunu görmek için birinin
bakması gerekir, ve bakılmaz.

Bu betik farkı kapatır: her değişmez canlı veride yeniden koşar.
Bayatlarsa çıkış kodu 1 olur.

Araştırma (2026-09-03) aynı yeri gösteriyor:
  · ölçüt SQL METNİ değil ÇALIŞTIRMA SONUCU olmalı (promptfoo),
  · davranış baseline kaydedilip regresyon aranmalı (Arthur AI),
  · semantik katman doğruluğu %84-90 → %98-100 (dbt 2026 benchmark).

SESSİZ ATLAMA YOK
-----------------
Veritabanına bağlanamazsa PATLAR, "geçti" demez. Bir ölçümün BOŞ dönmesi
ile KOŞMAMASI ekranda aynı görünür; yeşil çıktı değişmezlerin gerçekten
koştuğu anlamına gelmeli.

YENİ DEĞİŞMEZ EKLERKEN
----------------------
Beklenen değeri bilerek boz, KIRMIZI olduğunu gör, sonra geri al.
Kırılabildiği kanıtlanmamış bir test, test değildir.

ÇOK SUNUCU
----------
Her kayıt `sunucu` alanı taşır: `erp` (varsayılan — MSSQL_HOST, DerinSIS/
EncoreMerkez), `zirve` (ZIRVE_HOST — bordro/İK, BKM_GENEL), `joker`
(JOKER_HOST — e-ticaret). Bordro gerçekleri ayrı sunucuda olduğu için
tek-sunucu koşucu onları hiç ölçemiyordu.

Kullanım:
    python tools/sema_degismez.py
    python tools/sema_degismez.py --ayrintili
    python tools/sema_degismez.py --sadece <id>   # yeni değişmezi kırmızı görmek için
"""
import json
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DOSYA = REPO / "sema" / "degismezler.json"


def load_env_file():
    """`.env` dosyasını ortama yükler — diğer betiklerle aynı desen."""
    yol = REPO / ".env"
    if not yol.exists():
        return
    for satir in yol.read_text(encoding="utf-8").splitlines():
        satir = satir.strip()
        if not satir or satir.startswith("#") or "=" not in satir:
            continue
        k, v = satir.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip())


# Sunucu adı -> .env önek eşlemesi. Yeni sunucu eklenince buraya bir satır.
SUNUCULAR = {
    "erp": ("MSSQL_HOST", "MSSQL_USER", "MSSQL_PASSWORD", "MSSQL_DATABASE"),
    "zirve": ("ZIRVE_HOST", "ZIRVE_USER", "ZIRVE_PASSWORD", "ZIRVE_DATABASE"),
    "joker": ("JOKER_HOST", "JOKER_USER", "JOKER_PASSWORD", "JOKER_DATABASE"),
}


def get_db_config(sunucu="erp"):
    """`sunucu` etiketine göre bağlantı bilgisi. Eksikse PATLAR — sessiz atlama yok."""
    load_env_file()
    if sunucu not in SUNUCULAR:
        sys.exit("Bilinmeyen sunucu etiketi: %s (gecerli: %s)"
                 % (sunucu, ", ".join(sorted(SUNUCULAR))))
    h, u, p, d = SUNUCULAR[sunucu]
    host = os.environ.get(h)
    if host:
        return dict(server=host,
                    user=os.environ.get(u, "sa"),
                    password=os.environ.get(p, ""),
                    database=os.environ.get(d, "master"))
    if sunucu == "erp":
        cfg = REPO / ".secrets" / "db.json"
        if cfg.exists():
            return json.loads(cfg.read_text(encoding="utf-8"))
    sys.exit("'%s' sunucusu icin config yok — %s env degiskeni gerek." % (sunucu, h))


def _katalog_kimlikleri():
    """`queries.yaml` sorgu id'leri — `korur` alanini capraz denetlemek icin.
    Katalog yoksa veya pyyaml kurulu degilse bos kume doner (denetim atlanir, PATLAMAZ:
    katalogsuz depo da gecerli)."""
    yol = REPO / "sema" / "queries.yaml"
    if not yol.exists():
        return set()
    try:
        import yaml
    except ImportError:
        return set()
    veri = yaml.safe_load(yol.read_text(encoding="utf-8")) or {}
    return {q.get("id") for q in veri.get("queries", []) if q.get("id")}


def ac_baglanti(cfg, db):
    """Hedefe gore surucu secer.

    Adlandirilmis ornek (`SUNUCU\\ORNEK`) icin pymssql portsuz calismaz — baglanti
    asilir ve olcum "bos" gorunur. O yuzden ismde ters bolu varsa **pyodbc**
    (ODBC Driver 18), degilse pymssql. Ayni secim scripts/verimlilik_ortak.py'de.
    """
    sunucu_adi = cfg["server"]
    if "\\" in sunucu_adi:
        import pyodbc
        return pyodbc.connect(
            "Driver={ODBC Driver 18 for SQL Server};Server=%s;Database=%s;UID=%s;PWD=%s;"
            "TrustServerCertificate=yes;Timeout=30"
            % (sunucu_adi, db, cfg["user"], cfg["password"]), timeout=30)
    try:
        import pymssql
    except ImportError:
        sys.exit("pymssql yok: pip install pymssql")
    return pymssql.connect(server=sunucu_adi, user=cfg["user"],
                           password=cfg["password"], database=db)


def main():
    ayrintili = "--ayrintili" in sys.argv
    sadece = None
    if "--sadece" in sys.argv:
        i = sys.argv.index("--sadece")
        if i + 1 >= len(sys.argv):
            sys.exit("--sadece <id> bekleniyor.")
        sadece = sys.argv[i + 1]

    if not DOSYA.exists():
        sys.exit("Bulunamadi: %s" % DOSYA)
    veri = json.loads(DOSYA.read_text(encoding="utf-8"))
    kayitlar = veri.get("degismezler", [])
    if not kayitlar:
        sys.exit("degismezler bos — koşacak bir şey yok.")

    # KIMLIK TEKILLIGI: ayni id iki kez yazilirsa biri golgelenir
    # ve "kostu" sanilir.
    kimlikler = [k["id"] for k in kayitlar]
    tekrar = {x for x in kimlikler if kimlikler.count(x) > 1}
    if tekrar:
        sys.exit("Tekrarlayan degismez kimligi: %s" % ", ".join(sorted(tekrar)))

    # YAPISAL DENETIM (bel/Belinza xUnit kosucusundan alindi): gerekcesi
    # yazilmayan bir degismez, kirildiginda ne yapilacagini soylemez.
    kusur = []
    for k in kayitlar:
        if not (k.get("neden") or "").strip():
            kusur.append("%s: `neden` bos" % k["id"])
        if not (k.get("soru") or "").strip():
            kusur.append("%s: `soru` bos" % k["id"])
        if not (k.get("db") or "").strip():
            kusur.append("%s: `db` bos" % k["id"])
        if k.get("karsilastirma") not in ("esit", "enaz", "encok"):
            kusur.append("%s: karsilastirma gecersiz (%s)" % (k["id"], k.get("karsilastirma")))
        if k.get("sunucu", "erp") not in SUNUCULAR:
            kusur.append("%s: sunucu gecersiz (%s)" % (k["id"], k.get("sunucu")))
    # `korur` alani queries.yaml'daki sorgu id'sine isaret eder. Yazim hatasi olan
    # referans SESSIZCE baglantisiz kalir -> degismez hangi sorguyu korudugunu soylemez.
    katalog = _katalog_kimlikleri()
    if katalog:
        for k in kayitlar:
            for qid in k.get("korur", []):
                if qid not in katalog:
                    kusur.append("%s: korur -> queries.yaml'da yok (%s)" % (k["id"], qid))

    if kusur:
        sys.exit("Degismez kaydi kusurlu:\n  " + "\n  ".join(kusur))

    if sadece:
        kayitlar = [k for k in kayitlar if k["id"] == sadece]
        if not kayitlar:
            sys.exit("Boyle bir degismez yok: %s" % sadece)

    kirik = []
    baglantilar = {}   # (sunucu, db) -> conn ; ayni hedef icin tek baglanti

    def baglan(sunucu, db):
        anahtar = (sunucu, db)
        if anahtar not in baglantilar:
            cfg = get_db_config(sunucu)
            try:
                baglantilar[anahtar] = ac_baglanti(cfg, db or cfg.get("database"))
            except Exception as ex:
                # SESSIZ ATLAMA YOK.
                for c in baglantilar.values():
                    try:
                        c.close()
                    except Exception:
                        pass
                sys.exit("%s/%s baglanilamadi — degismezler KOSMADI.\n  %s"
                         % (sunucu, db, ex))
        return baglantilar[anahtar]

    for k in kayitlar:
        db = k.get("db")
        sunucu = k.get("sunucu", "erp")
        conn = baglan(sunucu, db)
        imlec = conn.cursor()
        imlec.execute(k["sql"])
        satir = imlec.fetchone()
        deger = 0 if satir is None or satir[0] is None else float(satir[0])

        bek = float(k["beklenen"])
        kars = k["karsilastirma"]
        gecti = (deger == bek if kars == "esit"
                 else deger >= bek if kars == "enaz"
                 else deger <= bek if kars == "encok"
                 else False)

        isaret = "OK   " if gecti else "KIRIK"
        etiket = k["id"] if sunucu == "erp" else "%s:%s" % (sunucu, k["id"])
        print("%s %-38s %s (%s %s)" % (isaret, etiket, _sayi(deger), kars, _sayi(bek)))
        if ayrintili:
            print("        %s" % k["soru"])

        if not gecti:
            kirik.append(k)

    for c in baglantilar.values():
        try:
            c.close()
        except Exception:
            pass

    print()
    print("%d degismez kostu (%d hedef), %d kirik."
          % (len(kayitlar), len(baglantilar), len(kirik)))

    if kirik:
        print()
        for k in kirik:
            print("KIRIK [%s]" % k["id"])
            print("  soru          : %s" % k["soru"])
            print("  son dogrulama : %s" % k["dogrulandi"])
            print("  NEDEN ONEMLI  : %s" % k["neden"])
            print()
        print("Veri degismis olabilir — once OLC, sonra ya kodu ya")
        print("`sema/degismezler.json`'u duzelt. Kaydi sessizce silmek,")
        print("ogrenilen gercegi unutmaktir.")
        sys.exit(1)


def _sayi(x):
    return str(int(x)) if float(x).is_integer() else ("%.2f" % x)


if __name__ == "__main__":
    main()
