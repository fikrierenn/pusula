# Plan 31 — Ayrıntılı Gelir Tablosu (Gider Merkezi) · /gelir-tablosu

**Durum:** onaylı (3 tasarım sorusu yanıtlı) · **Tier:** 3

## Problem
BKM'nin resmi P&L SP'si (`mhsGelirTabloGiderMerkeziDetayli`) **6xx-only** → 7xx işletme giderini
(740/760/770) ve 780 finansmanı GÖSTERMEZ → "dönem kârı" opex-siz şişkin (Haziran: SP 80,9M vs
gerçek 2,0M). Tam Ayrıntılı Gelir Tablosu yok.

## Kapsam (kullanıcı kararları)
- **Ayrıntılı Gelir Tablosu:** Net Satışlar (60−61) → Faaliyet Giderleri (740+760+770, kategori-gruplu)
  → **Faaliyet Kârı %** → Finansman(780)+Komisyon(653/66) + Diğer(64/65/67) + KKEG(689/68) → **Net Kâr %**.
- **Kategori = `.YY` segmenti** (7/A standart): 10 İşçi Ücret · 20 Yönetim · 30 Dışarıdan Fayda ·
  40 Çeşitli · 50 Vergi-Harç · 60 Amortisman. Kategori altında detay hesap (hspAd, fonksiyon-toplamı).
- **İşaret:** signed `fisTutar` (gelir BA=0 →+, gider BA=1 →−). Net Kâr = tüm 6xx+7xx signed toplam.
  Kapanış fişi HARİÇ; yıl=sirketID+2020.
- **Düzen:** Toplam (tüm merkez) + üstten merkez seç → o merkezin P&L'i (gelir de fisGdrMerkez-atanmış).
- **% kolonu:** her satır / Net Satışlar; Faaliyet/Net Kâr marjı.
- **Yeni sayfa** `/gelir-tablosu` (Gider Merkezi Mizanı matris ayrı kalır). Excel export.

## Doğrulama (2026-08-06, Haziran toplam)
Net Satış 75,74M (ERP SP 61x ile birebir) · Faaliyet Kârı 35,39M (%46,7) · Net Kâr 2,04M (%2,7).

## Mimari (emitter-ayrımı)
- Çekirdek: `GelirTabloQueries.cs` — signed fisTutar, hesap→P&L-satır sınıflandırması, merkez filtresi.
- Emitter: `GelirTablosu.razor` — hiyerarşik P&L + % + Faaliyet/Net Kâr + merkez seç + Excel.
- Kategori adı `.YY` map (TekDuzenHesap deseni — TDHP sabit lookup).

## Adımlar
1. `Models/GelirTabloModels.cs` (GelirDetay record).
2. `Data/GelirTabloQueries.cs` (GetDonemler, GetMerkezler, GetGelirTablo).
3. `Components/Pages/GelirTablosu.razor` (/gelir-tablosu).
4. NavRegistry + ServiceRegistration.
5. `sorgular/2026-08-06-gelir-tablosu-gider-merkezi.sql` arşiv. Build + preview.

## Done
Build yeşil · Net Satış ERP SP ile tutar · Faaliyet/Net Kâr + % görünür · merkez seç çalışır · Excel.

## Rollback
Yeni dosyalar (git rm) + nav/DI 2 satır. İzole.
