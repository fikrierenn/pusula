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

⚠ SINIR: bu denetim BİÇİMSEL. Alias'sız SELECT kolonlarını (ör. `ml.BirimMaliyet`)
atlar, çünkü adı ifadeden çıkarmak parse gerektirir — atlananlar rapor edilir.
Yani "0 kırık" bütün eşleşmenin doğru olduğunu KANITLAMAZ; yalnız bu iki desenin
temiz olduğunu söyler.
"""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

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


def oku(rel: str) -> str:
    p = KOK / rel
    if not p.exists():
        print(f"KOŞAMADI  dosya yok: {rel}")
        sys.exit(2)
    return io.open(p, encoding="utf-8-sig").read()


def sql_aliaslari(metin: str, baslangic: str) -> tuple[list[str], int]:
    """Metodun ilk raw-string SQL'inden `AS Alias` adlarını SIRAYLA topla."""
    i = metin.find(baslangic)
    if i < 0:
        print(f"KOŞAMADI  SQL başlangıç imi bulunamadı: {baslangic[:50]}")
        sys.exit(2)
    a = metin.find('"""', i)
    b = metin.find('"""', a + 3)
    if a < 0 or b < 0:
        print("KOŞAMADI  raw-string SQL sınırları bulunamadı")
        sys.exit(2)
    sql = metin[a + 3 : b]
    # Yorum satırlarını at — `-- ... AS ...` yanlış alias üretir
    satirlar = [s for s in sql.splitlines() if not s.strip().startswith("--")]
    sql = "\n".join(satirlar)
    aliaslar = re.findall(r"\bAS\s+([A-Za-z_][A-Za-z0-9_]*)", sql)
    # Alias'sız kolon sayısı kabaca: virgülle ayrılmış üst düzey öğe − alias sayısı
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
        uyari.append(
            f"{etiket}: {len(atlanan)} record parametresi SQL'de alias olarak bulunamadı "
            f"(alias'sız kolon olabilir, denetim dışı): {', '.join(atlanan[:6])}"
            + (" …" if len(atlanan) > 6 else "")
        )

print()
print("═" * 74)
print("B) ANAHTAR ÇATALLANMASI — kolon tanımı ↔ değer eşlemesi")
print("═" * 74)

for etiket, tanim_dosya, tanim_re, esle_dosya, esle_re in ANAHTAR_CIFTLERI:
    tanimli = set(re.findall(tanim_re, oku(tanim_dosya)))
    eslenen = set(re.findall(esle_re, oku(esle_dosya)))
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
