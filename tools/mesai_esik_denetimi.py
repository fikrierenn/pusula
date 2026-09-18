#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mesai mevzuat eşiği ÇATALLANMA denetimi — C# ↔ Python.

NEDEN VAR (19.09.2026 denetimi): aynı eşikler iki dilde iki kopya hâlinde
yaşıyor. `VardiyaQueries.UyumAsync` bunu bir yorumla kabul ediyordu —

    "tools/mesai_mevzuat_kapisi.py ile AYNI eşikler ve AYNI tanımlar.
     İki yerde iki farklı sayı çıkarsa biri bayatlamış demektir."

— ama YORUM KAPI DEĞİLDİR. `test-discipline.md` § yazılı kural ≠ uygulanan kural:
kuralı çiğneyeni bugün kim görür? Cevap "hiç kimse" ise kural yoktur.

Bu kapı o boşluğu kapatır: iki taraftaki adları ve değerleri karşılaştırır.

Kaynaklar:
    C#     lib/Bkm.Shared/Models/VrdSabit.cs   (static class MesaiEsik)
    Python tools/mesai_mevzuat_kapisi.py       (modül düzeyi sabitler)

Kullanım:
    python tools/mesai_esik_denetimi.py

Çıkış kodu (sqlcli sözleşmesi):
    0 geçti · 1 KIRIK (değerler sapmış) · 2 KOŞAMADI (kaynak okunamadı/parse edilemedi)

⚠ SINIRLAR — neyi GÖRMEZ:
· Değerlerin DOĞRU olduğunu söylemez, yalnız İKİ TARAFTA AYNI olduğunu. İkisi
  birden yanlışsa bu kapı yeşil verir (mevzuat doğruluğu ayrı bir soru).
· Eşiğin KULLANILDIĞI yeri denetlemez: sabit doğru ama yanlış karşılaştırmada
  (`>` yerine `>=`) kullanılıyorsa görmez.
· Python tarafında sabitler `AD = ifade  # yorum` biçiminde yazılmak zorunda;
  hesap fonksiyona taşınırsa bu kapı KOŞAMADI verir (sessizce geçmez).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

KOK = Path(__file__).resolve().parent.parent
CS = KOK / "lib" / "Bkm.Shared" / "Models" / "VrdSabit.cs"
PY = KOK / "tools" / "mesai_mevzuat_kapisi.py"

# C# adı → Python adı. İkisi de değişebilir; eşleme burada TEK YERDE.
ESLEME = {
    "GunlukTavanDk":     "GUNLUK_TAVAN_DK",
    "GunlukBrutTavanDk": "GUNLUK_BRUT_TAVAN_DK",
    "GeceTavanDk":       "GECE_TAVAN_DK",
    "GeceBasDk":         "GECE_BAS_DK",
    "GeceBitDk":         "GECE_BIT_DK",
    "HaftalikNormalDk":  "HAFTALIK_NORMAL_DK",
}


def kosamadi(mesaj: str) -> None:
    print("KOŞAMADI  " + mesaj)
    sys.exit(2)


def oku(p: Path) -> str:
    if not p.exists():
        kosamadi(f"kaynak yok: {p}")
    return p.read_text(encoding="utf-8")


def hesapla(ifade: str) -> int | None:
    """`11 * 60` / `7 * 60 + 30` / `1440 + GeceBasDk` gibi basit aritmetiği çöz.

    Yalnız rakam, + - *, boşluk ve TANINAN sabit adları kabul edilir — keyfi
    ifade çalıştırılmaz (eval güvenliği)."""
    if not re.fullmatch(r"[0-9\s+\-*]+", ifade):
        return None
    try:
        return int(eval(ifade, {"__builtins__": {}}, {}))   # noqa: S307 — desen yukarıda kısıtlı
    except Exception:
        return None


def cs_sabitleri(metin: str) -> dict[str, int]:
    govde = metin.split("class MesaiEsik", 1)
    if len(govde) < 2:
        kosamadi("C# tarafında `class MesaiEsik` bulunamadı")
    sonuc: dict[str, int] = {}
    for ad, ifade in re.findall(r"public const int\s+(\w+)\s*=\s*([^;]+);", govde[1]):
        ifade = ifade.strip()
        # Başka bir sabite atıfsa (GeceBasDk2 = 1440 + GeceBasDk) önce onu koy
        for bilinen, deger in sonuc.items():
            ifade = re.sub(rf"\b{bilinen}\b", str(deger), ifade)
        d = hesapla(ifade)
        if d is not None:
            sonuc[ad] = d
    return sonuc


def py_sabitleri(metin: str) -> dict[str, int]:
    sonuc: dict[str, int] = {}
    for satir in metin.splitlines():
        m = re.match(r"^([A-Z][A-Z0-9_]*)\s*=\s*([^#\n]+)", satir)
        if not m:
            # `GECE_BAS_DK, GECE_BIT_DK = 20 * 60, 30 * 60` — çoklu atama
            c = re.match(r"^([A-Z][A-Z0-9_]*)\s*,\s*([A-Z][A-Z0-9_]*)\s*=\s*([^#\n]+)", satir)
            if c:
                parcalar = c.group(3).split(",")
                if len(parcalar) == 2:
                    for ad, ifade in zip((c.group(1), c.group(2)), parcalar):
                        d = hesapla(ifade.strip())
                        if d is not None:
                            sonuc[ad] = d
            continue
        d = hesapla(m.group(2).strip())
        if d is not None:
            sonuc[m.group(1)] = d
    return sonuc


cs = cs_sabitleri(oku(CS))
py = py_sabitleri(oku(PY))

print("═" * 74)
print("MESAİ EŞİĞİ ÇATALLANMA DENETİMİ — C# ↔ Python")
print("═" * 74)

kirik: list[str] = []
for cs_ad, py_ad in ESLEME.items():
    if cs_ad not in cs:
        kosamadi(f"C# sabiti okunamadı: MesaiEsik.{cs_ad} (sözdizimi değişmiş olabilir)")
    if py_ad not in py:
        kosamadi(f"Python sabiti okunamadı: {py_ad} (sözdizimi değişmiş olabilir)")
    if cs[cs_ad] != py[py_ad]:
        kirik.append(f"{cs_ad}={cs[cs_ad]} ↔ {py_ad}={py[py_ad]}")
        print(f"KIRIK {cs_ad}: C# {cs[cs_ad]} ≠ Python {py[py_ad]} dk — biri bayatlamış.")
    else:
        print(f"OK    {cs_ad} = {cs[cs_ad]} dk  ({py_ad})")

# Türetilmiş ikinci gün penceresi: kendi içinde tutarlı mı (C# tek kaynak)
for tur, taban in (("GeceBasDk2", "GeceBasDk"), ("GeceBitDk2", "GeceBitDk")):
    if tur in cs and taban in cs and cs[tur] != cs[taban] + 1440:
        kirik.append(tur)
        print(f"KIRIK {tur}={cs[tur]} ≠ {taban}+1440={cs[taban] + 1440}")

print()
if kirik:
    print(f"KIRIK · {len(kirik)} eşik çatallanmış")
    sys.exit(1)
print(f"Denetim geçti · {len(ESLEME)} eşik iki tarafta da aynı")
