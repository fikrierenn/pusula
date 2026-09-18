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

# Kapsam suzgeci istemesi ZORUNLU olan tablolar. Bir sorguda kapsamin BIR KEZ
# yazilmis olmasi yetmez: her alt-sorgu kendi suzgecini ister.
# ⚠ Bu liste 19.09.2026'da bir OLCUMDEN dogdu: Vrd_Devir alt-sorgusu suzgecsizdi
#   ve bir sube muduru kendi doneminin 334 saatini ama TUM SIRKETIN 1.858 saatlik
#   devrini goruyordu. Kapi o gun yalniz "metotta kapsam gecti mi" diye bakiyordu
#   ve bunu GORMEDI.
KAPSAMLI_TABLOLAR = ["bkm.Vrd_KisiGun", "bkm.Vrd_Devir"]

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
        # Her kapsamli tablo referansi kadar kapsam suzgeci var mi?
        gereken = sum(govde.count(t) for t in KAPSAMLI_TABLOLAR)
        var = govde.count(KAPSAM_IMI)
        if gereken > var:
            kirik.append(ad)
            print(f"KIRIK {ad}: {gereken} kapsamli tablo referansi var ama yalniz {var} "
                  f"kapsam suzgeci — bir alt-sorgu suzgecsiz kalmis (kapsam DISI veri doner).")
        else:
            print(f"OK    {ad}  ({var} suzgec / {gereken} tablo referansi)")

if denetlenen == 0:
    print("KOŞAMADI  `userId` alan hiçbir metot bulunamadı — imza değişmiş olabilir")
    sys.exit(2)

# ── PANEL SALT-OKUMA (plan 48 Adım 7, GMY kararı 19.09) ──────────────────────
# GMY panelinde vardiya sayfası SALT-OKUMA özettir. Yazma yolu oraya geri
# konulursa ÜÇ kapı birden atlanmış olur: rol yetkisi · şube kapsamı · denetim izi.
# Panel tek kullanıcılıdır ve üçü de orada YOK.
PANEL_SAYFA = Path(__file__).resolve().parent.parent / "dashboard/Components/Pages/Vardiya.razor"
YASAK = ["SaveApprovalAsync", "OnayKaydet"]

if PANEL_SAYFA.exists():
    panel = io.open(PANEL_SAYFA, encoding="utf-8").read()
    bulunan = [y for y in YASAK if y in panel]
    if bulunan:
        kirik.append("panel-yazma")
        print()
        print(f"KIRIK panel SALT-OKUMA olmalı ama yazma yolu var: {', '.join(bulunan)} "
              f"→ rol yetkisi + şube kapsamı + denetim izi ATLANIR (üçü de panelde yok).")
    else:
        print("OK    panel salt-okuma (dashboard/Vardiya.razor'da yazma yolu yok)")
else:
    print("KOŞAMADI  panel sayfası bulunamadı — taşındıysa bu denetim güncellenmeli")
    sys.exit(2)

print()
if kirik:
    print(f"KIRIK · {len(kirik)} bulgu")
    sys.exit(1)
print(f"Denetim geçti · {denetlenen} sorguda kapsam süzgeci + panel salt-okuma")
