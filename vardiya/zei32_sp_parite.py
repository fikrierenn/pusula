"""PARİTE KAPISI — reporthub SP'si ile kanonik Python scripti aynı şeyi mi üretiyor?

NEDEN VAR: `dbo.sp_PdksGirisCikisDetay` (reporthub, 192.168.40.201/BKM),
`vardiya/zei32_rapor.py`ın T-SQL portudur. İki çıktı iki ayrı yerde yaşıyor —
biri düzeltilip diğeri unutulursa SESSİZCE ayrışırlar ve kimse fark etmez.
Bu script farkı ölçer. (pusula `.claude/rules/emitter-ayrimi.md`)

ÇIKIŞ KODU (sözleşme — `sql-server-conventions.md` § dört sözleşme):
    0  GEÇTİ    — hücre farkı yok
    1  KIRIK    — fark var, sayısı ve örnekleri yazılır
    2  KOŞAMADI — SP yok / bağlanılamadı / taraflardan biri boş
                  ⚠ KOŞAMAMAK YEŞİL DEĞİLDİR.

KULLANIM:
    python vardiya/zei32_sp_parite.py --bas 01.09.2026 --bit 16.09.2026
    python vardiya/zei32_sp_parite.py --bas 16.09.2026 --bit 16.09.2026 --sube-no 3

⚠ SP kurulmadan bu script 2 döner. Kurulum:
    Mosaik/Database/sp_PdksGirisCikisDetay.sql  →  192.168.40.201 / [BKM]
"""

import argparse
import datetime as dt

import re
import subprocess
import sys
from pathlib import Path

if sys.platform == "win32":
    for _s in (sys.stdout, sys.stderr):
        try:
            _s.reconfigure(encoding="utf-8")
        except Exception:
            pass

REPO = Path(__file__).resolve().parent.parent

# Kaynak raporun kolon sırası (zei32_rapor.py BASLIKLAR ile birebir)
KOLONLAR = ["Sicil No", "Adı", "Soyadı", "Grup0", "Grup1", "Grup2", "Grup3",
            "Grup4", "Grup5", "Tarih", "Pdks 1. Giris", "Pdks 1. Cikis",
            "Gün Modeli", "Mazeret", "Bürüt Süre"]

# Farkı raporlanan kolonlar — kimlik/grup alanları aynı kaynaktan geldiği için
# kıyas anlamlı olan değer kolonları bunlar.
DEGER_KOLONLARI = ["Pdks 1. Giris", "Pdks 1. Cikis", "Gün Modeli",
                   "Mazeret", "Bürüt Süre"]


def cik(kod: int, mesaj: str):
    print(mesaj)
    sys.exit(kod)


def tarih_oku(metin: str) -> dt.date:
    m = re.fullmatch(r"(\d{2})\.(\d{2})\.(\d{4})", metin.strip())
    if not m:
        cik(2, f"KOŞAMADI: tarih dd.MM.yyyy olmalı: {metin!r}")
    return dt.date(int(m.group(3)), int(m.group(2)), int(m.group(1)))


def sp_ciktisi(bas: dt.date, bit: dt.date, sube_no: str | None,
               ayrilanlar: str, bos_gunler: str):
    """SP'yi 40.201 üzerinde çalıştırır (salt-SELECT). sqlcli `erp` profili.

    ⚠ sqlcli profilleri ÇALIŞMA DİZİNİNE bağlı — bu yüzden cwd=REPO veriliyor.
      (sql-server-conventions: başka depodan çağrı sessizce geçer.)
    """
    sube_arg = f"'{sube_no}'" if sube_no else "NULL"
    # SP imzası 28.09.2026'da `bit` bayraklarına döndü: portal `select` için
    # FilterDefinition ister, o ise veri-erişim mekanizmasıdır ve eklenen her
    # anahtar tüm PDKS raporlarını 403'e düşürüyordu. Yön TERS: bayrak
    # "dahil et" / "gizle" (varsayılan 0 = hariç tut / göster).
    dahil = 1 if ayrilanlar == "dahil" else 0
    gizle = 1 if bos_gunler == "haric" else 0
    sql = (f"EXEC BKM.dbo.sp_PdksGirisCikisDetay "
           f"@Bas='{bas:%Y%m%d}', @Bit='{bit:%Y%m%d}', "
           f"@sube_Filtre={sube_arg}, "
           f"@AyrilanlariDahilEt={dahil}, @KayitsizGunleriGizle={gizle}")
    try:
        p = subprocess.run(
            ["sqlcli", "query", "--profile", "erp", "--format", "json",
             "--max-rows", "500000", "--timeout", "600", sql],
            cwd=str(REPO), capture_output=True, text=True, encoding="utf-8",
            timeout=900)
    except FileNotFoundError:
        cik(2, "KOŞAMADI: sqlcli bulunamadı (PATH).")
    except subprocess.TimeoutExpired:
        cik(2, "KOŞAMADI: SP 15 dakikada dönmedi.")

    ham = (p.stdout or "") + (p.stderr or "")
    # SQL Server hata dili sunucuya göre değişir — TR ve EN karşılığı birlikte
    # aranır. Tanınmazsa aşağıdaki genel dal yine 2 döndürür (yeşile düşme yok).
    yok_izleri = ("could not find", "bulunamadı", "does not exist")
    if "sp_PdksGirisCikisDetay" in ham and any(i in ham.lower() for i in yok_izleri):
        cik(2, "KOŞAMADI: SP kurulu DEĞİL (192.168.40.201 / BKM).\n"
               "         Kurulum: Mosaik/Database/sp_PdksGirisCikisDetay.sql")
    if p.returncode != 0:
        cik(2, f"KOŞAMADI: sqlcli çıkış {p.returncode}\n{ham[:1500]}")

    import json
    # ⚠ sqlcli banner'ı ANSI renk kaçışı taşır ("\x1b[38;5;8m") ve içindeki '['
    #   ham find("[") ile JSON başlangıcı sanılır. Kaçışlar ÖNCE temizlenir.
    temiz = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", p.stdout)
    bas_idx = temiz.find("[")
    if bas_idx < 0:
        cik(2, f"KOŞAMADI: sqlcli JSON döndürmedi.\n{ham[:1500]}")
    try:
        satirlar = json.loads(temiz[bas_idx:])
    except json.JSONDecodeError as e:
        cik(2, f"KOŞAMADI: JSON ayrıştırılamadı: {e}\n{temiz[bas_idx:bas_idx+300]}")

    if not satirlar:
        cik(2, "KOŞAMADI: SP boş döndü. Bu 'veri yok' DEMEK DEĞİL — "
               "aralık/şube seçimi veya PDKS bağlantısı kontrol edilmeli.")
    return satirlar


def py_ciktisi(bas: dt.date, bit: dt.date, sube: str | None,
               ayrilanlar: str, bos_gunler: str):
    """Kanonik Python scriptini içeriden çağırır (Excel yazmadan)."""
    sys.path.insert(0, str(REPO / "vardiya"))
    try:
        import pyodbc
        import zei32_rapor as z
    except ImportError as e:
        cik(2, f"KOŞAMADI: zei32_rapor içe aktarılamadı: {e}")

    try:
        cn = pyodbc.connect(z.PANEL)
    except Exception as e:
        cik(2, f"KOŞAMADI: BkmPanel'e bağlanılamadı: {e}")
    try:
        cn.timeout = 600
        satirlar = z.veri_cek(cn, bas, bit, sube, ayrilanlar)
        if bos_gunler == "dahil":
            satirlar, _ = z.bos_gunleri_doldur(cn, satirlar, bas, bit, ayrilanlar)
    finally:
        cn.close()
    if not satirlar:
        cik(2, "KOŞAMADI: Python tarafı boş döndü.")
    return satirlar


def anahtar_sp(r: dict):
    return (int(r["Sicil No"]), str(r["Tarih"]).strip())


def anahtar_py(r: list):
    t = r[9]
    return (int(r[0]), t.strftime("%d.%m.%Y") if hasattr(t, "strftime") else str(t))


def norm(v) -> str:
    """Boş/None tek biçime iner. Sayı biçimi farkı (8.3 vs 8.30) elenmez —
    elenirse gerçek bir sapma gizlenebilir."""
    return "" if v is None else str(v).strip()


def main() -> int:
    ap = argparse.ArgumentParser(description="SP ↔ Python parite kapısı")
    ap.add_argument("--bas", required=True, help="dd.MM.yyyy")
    ap.add_argument("--bit", required=True, help="dd.MM.yyyy")
    ap.add_argument("--sube", default=None, help="Per_Grp2 (Python tarafı)")
    ap.add_argument("--sube-no", default=None, help="SubeNo (SP tarafı)")
    ap.add_argument("--ayrilanlar", choices=("dahil", "haric"), default="haric")
    ap.add_argument("--bos-gunler", choices=("dahil", "haric"), default="dahil")
    ap.add_argument("--ornek", type=int, default=15, help="yazılacak fark örneği")
    a = ap.parse_args()

    if bool(a.sube) != bool(a.sube_no):
        cik(2, "KOŞAMADI: --sube ve --sube-no BİRLİKTE verilmeli — biri "
               "Per_Grp2 (Python), diğeri SubeNo (SP). Tek taraf verilirse "
               "iki küme farklı olur ve fark ÖLÇÜM DEĞİL, kapsam farkı olur.")

    bas, bit = tarih_oku(a.bas), tarih_oku(a.bit)

    print(f"Pencere : {bas:%d.%m.%Y} – {bit:%d.%m.%Y}")
    print(f"Ayarlar : ayrılanlar={a.ayrilanlar} · boş günler={a.bos_gunler} "
          f"· şube={a.sube or 'TÜMÜ'}")
    print("-" * 72)

    sp = sp_ciktisi(bas, bit, a.sube_no, a.ayrilanlar, a.bos_gunler)
    py = py_ciktisi(bas, bit, a.sube, a.ayrilanlar, a.bos_gunler)
    print(f"SP satır     : {len(sp):>7}")
    print(f"Python satır : {len(py):>7}")

    sp_h = {anahtar_sp(r): r for r in sp}
    py_h = {anahtar_py(r): r for r in py}
    if len(sp_h) != len(sp):
        print(f"  ⚠ SP'de mükerrer anahtar: {len(sp) - len(sp_h)}")
    if len(py_h) != len(py):
        print(f"  ⚠ Python'da mükerrer anahtar: {len(py) - len(py_h)}")

    yok_sp = sorted(set(py_h) - set(sp_h))
    yok_py = sorted(set(sp_h) - set(py_h))
    kirik = 0
    if yok_sp:
        kirik += len(yok_sp)
        print(f"  ⚠ Python'da VAR, SP'de YOK : {len(yok_sp)} → {yok_sp[:5]}")
    if yok_py:
        kirik += len(yok_py)
        print(f"  ⚠ SP'de VAR, Python'da YOK : {len(yok_py)} → {yok_py[:5]}")

    idx = {ad: i for i, ad in enumerate(KOLONLAR)}
    hucre = 0
    ornekler = []
    for k in sorted(set(sp_h) & set(py_h)):
        s, pr = sp_h[k], py_h[k]
        for ad in DEGER_KOLONLARI:
            sv, pv = norm(s.get(ad)), norm(pr[idx[ad]])
            if sv != pv:
                hucre += 1
                if len(ornekler) < a.ornek:
                    ornekler.append(f"    {k[0]:>6} {k[1]:<11} {ad:<14} "
                                    f"sp={sv!r:<12} py={pv!r}")

    print("-" * 72)
    print(f"Ortak satır  : {len(set(sp_h) & set(py_h)):>7}")
    print(f"Hücre farkı  : {hucre:>7}")
    for o in ornekler:
        print(o)
    if hucre > a.ornek:
        print(f"    … {hucre - a.ornek} fark daha")

    if kirik or hucre:
        print("\nKIRIK — SP ile Python ayrışmış. İKİSİ BİRDEN düzeltilmeli; "
              "biri düzeltilip diğeri bırakılırsa aynı soru iki farklı "
              "cevap verir.")
        return 1

    print("\nGEÇTİ — SP ve Python aynı çıktıyı üretiyor.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
