# -*- coding: utf-8 -*-
"""SEMA SORGU KATALOĞUNU KOŞTURUR — `sema/queries.yaml`.

NEDEN VAR
---------
`degismezler.json` şema gerçeklerini yeniden koşuyordu; `queries.yaml` ise hâlâ
"saklanan ama koşmayan" taraftaydı. Kullanıcı sordu (2026-09-03): *"queries.yaml'daki
sorguları da değişmezlere çevir; hangi sorgular hangi durumda?"*

Ölçüm cevabı verdi: katalogdaki iki sorgu **bugün çalışmıyordu** —
`EncoreMerkez.dbo.Sales.SaleDate` diye bir kolon yok (doğrusu `Date`). Yani
`last_verified: 2026-06-09` damgası taşıyan bir SQL, damganın gösterdiği gün
çalışmış olsa bile bugün patlıyor ve kimse fark etmiyordu.

NE YAPAR
--------
Her kaydın `verified_sql`'ini `SELECT COUNT(*) FROM (<sql>) t` içine sarıp
çalıştırır: sorgu PARSE EDİYOR ve KOŞUYOR mu? Tutar/satır sayısı ÖLÇÜMDÜR ve
burada iddia edilmez (yarın değişir) — iddia edilen tek şey sorgunun ayakta
olduğudur. Yapısal gerçekler (kod kümesi kapalı, köprü ayakta, kolon duruyor)
`sema/degismezler.json`'a yazılır ve `tools/sema_degismez.py` ile koşar.

SESSİZ ATLAMA YOK
-----------------
Bağlanamazsa PATLAR. Sarmalanamayan sorgu (ORDER BY'lı, çoklu ifade) ATLANMAZ,
`SARILAMAZ` diye rapor edilir — atlanan sorgu koşmuş sayılmaz.

Kullanım:
    python tools/sema_sorgu_dumani.py
    python tools/sema_sorgu_dumani.py --ayrintili
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from sema_degismez import ac_baglanti, get_db_config  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
DOSYA = REPO / "sema" / "queries.yaml"

# Kayıt id'si -> (sunucu, veritabanı). Katalogda hedef alanı yok; JOKER'e linked
# server ile ERP üstünden gidilir (linked server'ın kendisi de böylece sınanır).
HEDEF = {"joker": ("erp", "DerinSISBkm")}


def hedef_bul(kayit):
    sql = str(kayit.get("verified_sql", ""))
    if "ODAKJOKER" in sql:
        return HEDEF["joker"]
    if "BKM_GENEL" in sql or "vw_PuanBil" in sql or "vw_PersonelDepartman" in sql:
        return ("zirve", "BKM_GENEL")
    return ("erp", "DerinSISBkm")


def sarilabilir(sql):
    """Alt sorgu olarak sarılabilir mi? Türetilmiş tabloda TOP'suz ORDER BY yasak."""
    duz = " ".join(sql.split())
    if ";" in duz.rstrip(";"):
        return False, "çoklu ifade"
    if re.search(r"\bORDER\s+BY\b", duz, re.I) and not re.search(r"\bTOP\s*\(?\d", duz, re.I):
        return False, "TOP'suz ORDER BY"
    return True, ""


def main():
    ayrintili = "--ayrintili" in sys.argv

    try:
        import yaml
    except ImportError:
        sys.exit("pyyaml yok: pip install pyyaml")

    if not DOSYA.exists():
        sys.exit("Bulunamadi: %s" % DOSYA)
    kayitlar = yaml.safe_load(DOSYA.read_text(encoding="utf-8")).get("queries", [])
    if not kayitlar:
        sys.exit("queries.yaml bos — kosacak bir sey yok.")

    kimlikler = [k["id"] for k in kayitlar]
    tekrar = {x for x in kimlikler if kimlikler.count(x) > 1}
    if tekrar:
        sys.exit("Tekrarlayan sorgu kimligi: %s" % ", ".join(sorted(tekrar)))

    baglantilar = {}

    def baglan(sunucu, db):
        if (sunucu, db) not in baglantilar:
            try:
                baglantilar[(sunucu, db)] = ac_baglanti(get_db_config(sunucu), db)
            except Exception as ex:
                for c in baglantilar.values():
                    try:
                        c.close()
                    except Exception:
                        pass
                sys.exit("%s/%s baglanilamadi — katalog KOSMADI.\n  %s" % (sunucu, db, ex))
        return baglantilar[(sunucu, db)]

    kirik, sarilamaz = [], []

    for k in kayitlar:
        sql = str(k.get("verified_sql", "")).strip()
        sunucu, db = hedef_bul(k)
        etiket = k["id"] if sunucu == "erp" else "%s:%s" % (sunucu, k["id"])

        if not sql:
            print("BOS   %-40s verified_sql yok" % etiket)
            kirik.append((k["id"], "verified_sql bos"))
            continue

        ok, sebep = sarilabilir(sql)
        if not ok:
            print("SARILAMAZ %-36s %s" % (etiket, sebep))
            sarilamaz.append((k["id"], sebep))
            continue

        conn = baglan(sunucu, db)
        try:
            imlec = conn.cursor()
            imlec.execute("SELECT COUNT(*) FROM (%s) t" % sql)
            satir = imlec.fetchone()
            adet = 0 if satir is None or satir[0] is None else int(satir[0])
            print("OK    %-40s %d satir" % (etiket, adet))
            if ayrintili:
                print("        %s" % str(k.get("question", ""))[:110])
        except Exception as ex:
            mesaj = str(ex).split("DB-Lib")[0].strip()[:160]
            print("KIRIK %-40s %s" % (etiket, mesaj))
            kirik.append((k["id"], mesaj))

    for c in baglantilar.values():
        try:
            c.close()
        except Exception:
            pass

    print()
    print("%d sorgu denendi (%d hedef) — %d kirik, %d sarilamaz."
          % (len(kayitlar), len(baglantilar), len(kirik), len(sarilamaz)))

    if sarilamaz:
        print()
        print("SARILAMAZ (elle kosulmali — atlanan sorgu kosmus sayilmaz):")
        for kid, sebep in sarilamaz:
            print("  %s — %s" % (kid, sebep))

    if kirik:
        print()
        for kid, mesaj in kirik:
            print("KIRIK [%s]" % kid)
            print("  %s" % mesaj)
        print()
        print("Katalog bayat. Once OLC (dogru kolon/nesne adini bul), sonra")
        print("`sema/queries.yaml`'daki verified_sql'i duzelt + last_verified'i")
        print("bugune cek. Kaydi silmek, ogrenilen sorguyu unutmaktir.")
        sys.exit(1)


if __name__ == "__main__":
    main()
