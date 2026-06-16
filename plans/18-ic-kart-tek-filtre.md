# Plan 18 — İç-Kart Tek Kanonik Filtre

**Tarih:** 16.06.2026 · **Tier:** 3 · **Durum:** uygulanıyor

## Problem
İç/mağaza kartları (İstanbulyolu Mağaza 10.779 fiş, AKL 7.476, RGR 2.699, Kumbara kartları…) müşteri sorgularında **tutarsız** eleniyor:
- RFM segment (yazarkasa): sadece `icIds` (boş→filtre yok) → İstanbulyolu Mağaza "şampiyon müşteri" görünüyor.
- Kazanım / Kart-oranı: isim (Mağaza/Kumbara) + icIds, **tel filtresi yok** → AKL/RGR kaçıyor.
- Sadakat WinBack/Pareto/Kartlı: sadece icIds.
- Sadakat RfmGeçiş / TekrarAlış: **HİÇBİR** iç-kart filtresi yok.

Tek doğru tanım `GetYkCustomersAsync`'te zaten var (isim Mağaza/Kumbara + tel 599%/699% geçersiz prefix + elle icIds) ama kopyalanmamış.

## Çözüm
**Tek kanonik SQL helper** — `IcKartFiltre.Sql(sAlias, hasIcIds)`. Customer JOIN GEREKTİRMEZ (NOT IN alt-sorgu formu → her alias'ta çalışır):
```
AND {s}.CustomersId NOT IN (SELECT Id FROM DerinCrm.dbo.Customer WITH(NOLOCK)
    WHERE Name LIKE '%Mağaza%' OR Name LIKE '%Kumbara%'
       OR ISNULL(PhoneNumber,'') LIKE '599%' OR ISNULL(PhoneNumber,'') LIKE '699%')
[AND {s}.CustomersId NOT IN @icIds]
```
Manuel liste (UI tıkla-işaretle, IcKartService) zaten aktif → `@icIds` ile biner.

## Uygulanacak sorgular (9)
RefQueries: RFM ykSql · kazanım · kart-oranı (CASE içi) · GetYkCustomersAsync (inline→helper).
SadakatQueries: WinBack · Pareto · Kartlı · RfmGeçiş (+icIds param ×2 altsorgu) · TekrarAlış (+param, çok altsorgu).

## Done / Mutabakat
- RFM/sadakat müşteri sayıları DÜŞER (iç kartlar çıkar) — doğru yön, beklenen.
- E-ticaret RFM (JOKER CUSTOMERREF) ayrı evren — DOKUNULMAZ.
- Build yeşil + /musteri + /sadakat smoke (İstanbulyolu Mağaza RFM'den çıktı mı doğrula).

## Rollback
git revert — helper + 2 query dosyası tek commit.
