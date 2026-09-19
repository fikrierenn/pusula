#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TÜRKÇE TANIMLAYICI KAPISI — kod İngilizce, UI Türkçe (`turkish-ui.md`).

═══ YAKALAMA SÖZLEŞMESİ ═══════════════════════════════════════════════════════
YAKALAR:
  • C#/Razor kodunda TANIMLAYICI konumunda Türkçe kelime: sınıf, metot, property,
    alan, yerel değişken, parametre adları (`Sube`, `MudurAdi`, `KisiGunOku`…).
  • Türkçe karakter taşıyan tanımlayıcı (`Ölçüm`, `Şube`).
  • Türkçe dosya adı (`SubeKapsamiTests.cs`).

YAKALAMAZ:
  • YORUMLAR ve DİZELER — onlar Türkçe OLMALI (UI metni, hata mesajı, açıklama).
    Satırdan çıkarılır.
  • SQL metinlerindeki kolon adları (dize içinde, yukarıdaki sebeple elenir).
  • Listede olmayan Türkçe kelime. Liste elle yazılmıştır ve EKSİKTİR —
    `olctum-mu-cikardim-mi.md` § "liste elle yazılmaz" ihlali, bilerek: kelime
    kümesini veriden türetmenin yolu yok. Yeni ihlal görülünce listeye eklenir.
  • Domain adları: `Vardiya`, `Bkm`, `Vrd` (ürün/şirket adı, çevrilmez).

BİLİNEN ATLATMA:
  • Kelimeyi listede olmayan bir Türkçe kelimeyle yazmak (`Magaza` yerine `Dukkan`).
  • Türkçe kelimeyi kısaltmak (`Sb` = şube).

YÜKSELTME YOLU:
  • İhlal ikinci kez listede olmayan bir kelimeden gelirse, liste yaklaşımı
    terk edilip sözlük tabanlı bir çözüm (TDK kelime listesi) tartışılır.
  ⚠ BU TETİK ZATEN ATEŞLENDİ (19.09, aynı gün): ikinci turda 14 kelime listeye
    EKLENDİ çünkü kaçmışlardı. Yani yükseltme borcu bugün AÇIK — kapatılmadı,
    V-19 olarak yazıldı.

KAPININ İKİ YARISI AYNI GÜVENDE DEĞİL (Solum'un ayrımı, 19.09):
  • Türkçe HARF taraması (`ıİşŞğĞüÜöÖçÇ`) — kapalı küme, kaçış YOK.
  • ASCII'ye çevrilmiş Türkçe kelime taraması — KARA LİSTE, yani eksikliği
    GÖRÜNMEZ. Yanlış alarm görülür ve düzeltilir; yanlış negatif sessizce
    yeşil durur. Bu kapının riski o ikinci yarıdadır ve listenin uzunluğu
    bir güvence DEĞİLDİR.
═══════════════════════════════════════════════════════════════════════════════

NEDEN VAR: 19.09.2026 oturumunda GMY **dört kez** aynı şeyi söylemek zorunda
kaldı ("hâlâ Türkçe isim kullanıyorsun"). Kural yazılıydı ve okunmuştu; çiğneyeni
gören yoktu. `test-discipline.md` § yazılı kural ≠ uygulanan kural.

Kullanım:
    python tools/turkce_tanimlayici_denetimi.py [dosya ...]
    (dosya verilmezse KAPSAM listesi taranır)

Çıkış: 0 geçti · 1 KIRIK · 2 KOŞAMADI
"""
from __future__ import annotations

import io
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

KOK = Path(__file__).resolve().parent.parent

# Yeni yazılan kod. Eski dashboard/scripts kapsam DIŞI — oradaki Türkçe adlar
# devralınmış borçtur ve bu kapı onları toptan kırmızıya çevirseydi kapı
# KAPATILIRDI (kimse 500 ihlalli bir kapıyı açık tutmaz).
KAPSAM = ["vardiya-app", "lib/Bkm.Shared", "tests"]

TURKCE_KELIMELER = [
    "Sube", "Mudur", "Kisi", "Gun", "Tarih", "Onay", "Sifre", "Kullanici",
    "Sayfa", "Deger", "Adi", "Hata", "Kesim", "Ozet", "Uyum", "Kaynak",
    "Bant", "Satir", "Durum", "Gorev", "Bolum", "Personel", "Sicil",
    "Eksik", "Fazla", "Giris", "Cikis", "Mola", "Calisma", "Devir",
    "Sayim", "Olcum", "Yazilma", "Aciklama", "Kaydeden", "Yetki", "Izin",
    "Rapor", "Tablo", "Sorgu", "Kapsam", "Nufus", "Fabrika", "Istemci",
    "Yanit", "Sonuc", "Mevcut", "Onceki", "Yeni", "Eski", "Toplam",
    "Bugun", "Secili", "Gecerli", "Bos", "Dolu", "Temizle", "Kur",
    "Oku", "Yaz", "Sil", "Ekle", "Guncelle", "Bul", "Ara", "Getir",
    "Kaydet", "Yukle", "Baslat", "Bitir", "Kontrol", "Denetim", "Damga",
    "Onek", "Artik", "Islem", "Ayrac", "Suzgec", "Kirilim", "Ortak",
    # 19.09 ikinci tur — ilk listede YOKTU ve kactilar (sozlesmedeki
    # "BILINEN ATLATMA" maddesinin ilk gerceklesmesi):
    "Kaydeden", "Dakika", "Metin", "Muaf", "Mesai", "Kadro", "Ek",
    "Yukleyici", "Bicim", "Sabit", "Kur", "Uret", "Cevir", "Hazirla",
]
TURKCE_HARF = "ıİşŞğĞüÜöÖçÇ"

# Kod dışı bırakılacaklar: yorum + dize
# SATIR YORUMU icin `[^\n]*` kullanilir, `.*$` DEGIL.
# Gerekce olculdu (19.09.2026): `re.S` bayragiyla `.` newline de esler ve
# `$` yalniz dosya sonunda durur -> ilk `//` yorumundan itibaren dosyanin
# TAMAMI siliniyordu, yani hicbir C# dosyasi gercekte denetlenmiyordu.
# Kapi SESSIZCE yesil veriyordu; kirmizi kip kosulmasaydi gorulmezdi.
YORUM = re.compile(r"//[^\n]*|/\*.*?\*/|@\*.*?\*@", re.S)
DIZE = re.compile(r'"""[\s\S]*?"""|"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
RAZOR_METIN = re.compile(r">[^<>{}@]*<")          # HTML metin düğümleri


def _gosterim(p: Path) -> str:
    """Yolu kısa göster — komut satırından göreli yol verilmişse relative_to çöker."""
    try:
        return str(p.resolve().relative_to(KOK))
    except ValueError:
        return str(p)


def _satir_koru(m: re.Match) -> str:
    """Eşleşmeyi siler AMA satır sayısını korur — yoksa satır numarası kayar
    ve bulgu yanlış satırı gösterir (ilk sürümde tam bu oldu)."""
    return chr(10) * m.group(0).count(chr(10))


# Razor'da KOD yalnız `@` ile başlayan ifadelerdedir: `@Model.Foo`, `@Bar(x)`,
# `@if (…)`, `@code { … }`. Gerisi HTML metnidir ve TÜRKÇE OLMALI.
# İlk sürüm tersini yapıyordu (HTML metnini çıkarıp kalanı kod saymak) ve
# `Toplam @VrdFormat…` gibi satırlarda UI metnini tanımlayıcı sandı.
RAZOR_IFADE = re.compile(r"@[A-Za-z_][\w.]*(?:\([^)]*\))?")


def kod_kismi(metin: str, razor: bool) -> str:
    """Kod DIŞINI çıkar. Razor'da tersi: yalnız `@` ifadelerini TUT."""
    metin = YORUM.sub(_satir_koru, metin)
    metin = DIZE.sub(_satir_koru, metin)
    if razor:
        # satır yapısını koru: her satırda yalnız @ifadelerini bırak
        return chr(10).join(" ".join(RAZOR_IFADE.findall(satir)) for satir in metin.splitlines())
    return metin


def ihlaller(yol: Path) -> list[tuple[int, str, str]]:
    # ⚠ Razor'da TÜRKÇE HARF denetimi YAPILMAZ: UI metni Türkçe harf doludur ve
    #   kalan HTML parçalarını koddan ayırmak güvenilir değil. Razor'da yalnız
    #   KELİME listesi aranır (tanımlayıcı adları). C#'ta ikisi de aranır.
    razor = yol.suffix.lower() == ".cshtml"
    ham = io.open(yol, encoding="utf-8-sig", errors="replace").read()
    bulgular: list[tuple[int, str, str]] = []

    # Dosya adı
    ad = yol.stem
    for k in TURKCE_KELIMELER:
        if re.search(rf"{k}", ad) and ad not in ("VardiyaQueries", "VardiyaModels", "VardiyaAppFactory"):
            bulgular.append((0, ad, f"dosya adı Türkçe: {k}"))
            break

    satirlar = ham.splitlines()
    temiz = kod_kismi(ham, razor).splitlines()
    for i, satir in enumerate(temiz, 1):
        if not satir.strip():
            continue
        for ch in ("" if razor else satir):
            if ch in TURKCE_HARF:
                bulgular.append((i, satirlar[i - 1].strip()[:90], f"tanımlayıcıda Türkçe harf '{ch}'"))
                break
        else:
            for k in TURKCE_KELIMELER:
                if re.search(rf"\b\w*{k}\w*\b", satir):
                    eslesen = re.search(rf"\b\w*{k}\w*\b", satir).group(0)
                    # `Vardiya`/`Vrd`/`Bkm` domain adları serbest
                    if eslesen in ("Vardiya", "Vrd", "Bkm"):
                        continue
                    bulgular.append((i, satirlar[i - 1].strip()[:90], f"Türkçe tanımlayıcı: {eslesen}"))
                    break
    return bulgular


hedefler: list[Path] = []
if len(sys.argv) > 1:
    hedefler = [Path(a) for a in sys.argv[1:] if Path(a).exists()]
else:
    for k in KAPSAM:
        for uzanti in ("*.cs", "*.cshtml"):
            hedefler += [p for p in (KOK / k).rglob(uzanti)
                         if "obj" not in p.parts and "bin" not in p.parts]

if not hedefler:
    print("KOŞAMADI  taranacak dosya bulunamadı — kapsam yolları değişmiş olabilir")
    sys.exit(2)

print("═" * 74)
print("TÜRKÇE TANIMLAYICI DENETİMİ — kod İngilizce, UI/yorum Türkçe")
print("═" * 74)

toplam = 0
for p in sorted(hedefler):
    b = ihlaller(p)
    if b:
        toplam += len(b)
        print(f"\nKIRIK {_gosterim(p)}")
        for satir, metin, sebep in b[:6]:
            print(f"   satır {satir:>4}: {sebep}")
            if metin:
                print(f"              {metin}")
        if len(b) > 6:
            print(f"   … {len(b) - 6} bulgu daha")

print()
if toplam:
    print(f"KIRIK · {toplam} Türkçe tanımlayıcı. Kod İngilizce olmalı (turkish-ui.md);")
    print("        yorum ve UI metni Türkçe KALIR — bu kapı onlara dokunmaz.")
    sys.exit(1)
print(f"Denetim geçti · {len(hedefler)} dosyada Türkçe tanımlayıcı yok")
