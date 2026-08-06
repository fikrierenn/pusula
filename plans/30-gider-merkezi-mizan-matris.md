# Plan 30 — Gider Merkezi Mizan Heat-Matrix (muhasebe app)

**Durum:** onaylı (kullanıcı 3 tasarım sorusu + "sadece giderler mizandan" yanıtladı) · **Tier:** 3

## Problem
Muhasebe tarafında gider raporu yok. Gider merkezi bazında (mağaza/kafe/merkez-dept),
mizandan gelen gerçek gideri heat-matrix olarak görmek isteniyor.

## Kapsam (kullanıcı kararları)
- **Kaynak = MİZAN** (`mhs.mhsFis` GL satırları — MizanQueries ile aynı çekirdek). Fatura/car DEĞİL.
- **Gider tanımı:** hesap `7%` tümü (740 hizmet/kafe · 760 pazarlama · 770 genel yönetim · 780 finansman)
  + gider-nitelikli 6xx (`LEFT(hspKod,2) IN 62,63,65,66,68`). **Gelir 6xx hariç** (600/602/610/642/679).
  BKM 7/A yöntemi → yansıtma (7x1) aktif değil, çift-sayım yok (canlı doğrulandı 2026-08-06).
- **İşaret:** Bakiye = Borç − Alacak = `SUM(fisBA=1→-fisTutar) − SUM(fisBA=0→fisTutar)` (mizan konvansiyonu).
- **Kapanış fişi HARİÇ** (`fisAd <> N'Kapanış'`) — kesin mizan.
- **Yıl = fisSirketID + 2020** (sirketID 6 = 2026). Yıl dropdown = mevcut sirketID'ler.
- **Ay + mod:** Kümüle (Oca→seçili ay, `MONTH ≤ ay`) | Seçili ay (`MONTH = ay`).
- **İki sekme:** (1) Gider Merkezi × Ay (12 ay trend) · (2) Gider Merkezi × Gider Türü (7xx/6xx ana grup).
- Gider merkezi adı: `frm.frmAd` → "G - " / " Gider Merkezi" temizlenir. `fisGdrMerkez=0` → "GENEL (dağıtılmamış)".

## Mimari (emitter-ayrımı)
- **Çekirdek:** tek sorgu, grain (GmKod, GmAd, TurKod, Ay) — tüm yıl. `Lib/GiderMerkeziQueries.cs`.
- **Emitter (dashboard/razor):** C#'ta iki pivot (Ay / Tür) + mod filtresi + heat renk. `Features/GiderMerkezi/`.
- Tür adı tablodan (`mhs.mhsAnaHsp`, hardcode yok).

## Adımlar
1. `Lib/GiderMerkeziQueries.cs` — GetDonemler (yıl listesi) + GetMatris(sirketId) → satır listesi + ana-hesap adları.
2. `Features/GiderMerkezi/Index.cshtml.cs` — yıl/ay/mod bind, pivot kur (Ay + Tür), heat max hesapla.
3. `Features/GiderMerkezi/Index.cshtml` — filtre bar + sekmeli iki matris + heat hücre (sequential kırmızı, alpha=val/max).
4. `_Layout.cshtml` nav + Program.cs DI (GiderMerkeziQueries).
5. Build + preview doğrula (rakam mizanla mutabık).

## Done
- Build yeşil · preview'da matris görünür · GENEL satırı finansmanı içerir · rakam mizan 7xx toplamıyla tutar.
- Salt-okuma (ERP-write policy: sadece SELECT).

## Rollback
Yeni dosyalar (git rm) + _Layout/Program.cs 2 satır geri. İzole feature, cascade yok.
