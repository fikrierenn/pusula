#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Şube kapsamı KAPISI — `userId` alan her sorgu gerçekten kapsam süzgeci kuruyor mu?

NEDEN VAR (19.09.2026): kapsam sekiz sorguya elle eklendi ve BİRİ ATLANDI —
`GetStayBandsAsync` `userId` parametresini alıyordu ama SQL'inde
`Vrd_SubeKapsami` YOKTU. Derleme temizdi, sayfa çalışıyordu; kalma bandı tablosu
kapsam DIŞINDAKİ şubeleri gösterecekti.

Gözle bulundu. Gözle bulunan şey ikinci kez kaçar — bu yüzden kapı.

⚠ SINIR: metin denetimi. `Vrd_SubeKapsami` geçiyor mu diye bakar; o süzgecin
DOĞRU kolona bağlandığını (ör. `Sube IN (...)` yerine `Bolum IN (...)`) görmez.
Yetki sızıntısının tamamını kapatmaz, ATLANMIŞ süzgeci kapatır.

Çıkış: 0 geçti · 1 KIRIK · 2 KOŞAMADI
"""
from __future__ import annotations
import io, re, sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

KAYNAK = Path(__file__).resolve().parent.parent / "lib/Bkm.Shared/Data/VardiyaQueries.cs"
KAPSAM_IMI = "Vrd_SubeKapsami"

if not KAYNAK.exists():
    print(f"KOŞAMADI  kaynak yok: {KAYNAK}")
    sys.exit(2)

metin = io.open(KAYNAK, encoding="utf-8").read()

# Metot gövdelerini ayır: `public async Task…Ad(` → bir sonraki `public` bildirimine kadar
basliklar = list(re.finditer(r"public\s+async\s+Task[^(]*?(\w+Async)\s*\(", metin))
if not basliklar:
    print("KOŞAMADI  hiç metot bulunamadı — sözdizimi değişmiş olabilir")
    sys.exit(2)

kirik, denetlenen = [], 0
for i, m in enumerate(basliklar):
    ad = m.group(1)
    bas = m.start()
    son = basliklar[i + 1].start() if i + 1 < len(basliklar) else len(metin)
    govde = metin[bas:son]

    if "string userId" not in govde:
        continue                      # kapsam istemeyen metot
    denetlenen += 1

    if KAPSAM_IMI not in govde:
        kirik.append(ad)
        print(f"KIRIK {ad}: `userId` alıyor ama SQL'inde {KAPSAM_IMI} YOK — "
              f"kapsam süzgeci atlanmış, sorgu kapsam DIŞINI döndürür.")
    elif not re.search(r"new\s*\{[^}]*\buserId\b", govde):
        kirik.append(ad)
        print(f"KIRIK {ad}: SQL'de @userId var ama parametre nesnesinde userId YOK — "
              f"çalışma anında 'Must declare the scalar variable @userId'.")
    else:
        print(f"OK    {ad}")

if denetlenen == 0:
    print("KOŞAMADI  `userId` alan hiçbir metot bulunamadı — imza değişmiş olabilir")
    sys.exit(2)

print()
if kirik:
    print(f"KIRIK · {len(kirik)} sorguda kapsam eksik")
    sys.exit(1)
print(f"Denetim geçti · {denetlenen} sorgunun hepsinde kapsam süzgeci var")
