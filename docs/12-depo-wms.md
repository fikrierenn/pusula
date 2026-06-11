# 12 — Merkez Depo / WMS (DerinSISBkm `depo` + `bkm` şeması)

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)
> Keşif: 10.06.2026 oturumu (depo işgücü raporu için). Merkez depo = **mekan 12 (Ana Depo)**.

WMS iş emri tabanlı çalışır: emir (görev) → palet operasyonu → operatör + adet kaydı. İşgücü/verim analizinin kaynağı bu şema (irsHrk değil — irsHrk muhasebe hareketi).

---

## İş Emri Modeli (`depo` şeması)

- **`depo.emir`** (11.748 satır): `emID` (PK), `emNo`, **`emTip`** (görev tipi), `emBhTip` (alt-bölüm 0/1/2/3), `kTarih`, `emDepoID`, `emHarekatTip`, `emTasimaTip`.
- **`depo.emTip`** lookup (5) = **GÖREV tipleri:**
  | emTipID | Ad | Karşılık |
  |---|---|---|
  | 0 | YERLEŞTİRME EMRİ | Raflama (putaway) |
  | 1 | BESLEME EMRİ | Replenishment |
  | 2 | TOPLAMA EMRİ | Picking |
  | 3 | ARAÇ PLANLAMA EMRİ | Şoför / sevkiyat planı |
  | 4 | HAVUZ EMRİ | Havuz |
- **`depo.emirAyr`** (5,3M satır) = **TOPLAMA (picking) operasyon detayı** (%99,97 emTip=2): `emAyrID`, `emPaletID`, **`emAdet`**, `emTamam` (1=tamamlandı), **`emKisi`** (GERÇEK operatör), `emTarih`. → toplama iş gücü buradan.
- **`depo.emirSat`** (11.756) = palet↔emir köprüsü, sadece [`satPID`, `satEmirID`]. Köprü: `emirAyr.emPaletID = emirSat.satPID` → `emirSat.satEmirID = emir.emID` → `emir.emTip`.
- **`depo.paletIcHrk`** (1,4M) = **iç hareket (yerleştirme/raflama + toplama paleti):** `piAdet`, **`pikKisi`** (operatör), `pikTarih`, **`pGC`** (0=giriş, 1=çıkış), **`pHrkTip`** (0/1/2), **`piIrsID`** (→`dbo.irs.eID`), `piIlkAdrsID`/`piSonAdrsID`. `pHrkTip=0 & pGC=0` = **Raflama** (yerleştirme girişi).
- **`depo.paletSevkLog`** (295K) = sevk-çıkış logu: `psAdet`, `psKabulİrsID`/`psSevkİrsID` (irsaliye), `psEmirID`. ⚠️ `kKisi` burada tek sistem-kullanıcısı (=operatör DEĞİL → operatör için `emirAyr.emKisi`).
- Lookup'lar: `paletIcHrkTip` (0=KULLANICI,1=EMİR,2=SAYIM,3=GERİ AL), `paletTip` (0=PALET,1=KASA,2=ROT,3=ÇIKIŞ KASASI).
- `bkm.MalKabulBaslik`/`MalKabulSatirLog` (Miktar, KullaniciId, MekanId, EvrakTarihi) = **MAĞAZA mal kabulü** (MekanId=1/4477/4478), merkez depo DEĞİL. `bkm.SevkiyatHareketBaslik`/`Detay` = mağaza kaynaklı sevk (2026'da devreye girdi).

## İrsaliye / Hareket Tipi (`dbo.irs`)
- **`dbo.irs`** (7,1M başlık): `eID` (PK), `eNo`, `eMekan`, `eFirma`, **`eTip`** (irsaliye tip), `eTarih`. Detay adet: `paletIcHrk.piIrsID = irs.eID` üzerinden `piAdet`.
- ⚠️ **`irs.eTip` için temiz lookup YOK** (`dbo.belgeTip` sadece "Fatura"). Kategori eşlemesi deneysel — Fikri teyit edecek.
- `irsHrk` (muhasebe hareket): `ehID`, `ehMekan`, `ehTip`, `ehAdetN`. Depo = `ehMekan=12`. **Hedef/karşı-mekan kolonu YOK** → Heykel/mağaza sevk ayrımı irsHrk'tan çıkmaz (palet/irs hedef adresi gerekir).

## Hareket Kategorisi = eTip + Yön (pGC) + Firma grubu (10.06 ÇÖZÜLDÜ)
Merkez depo (mekan 12) hareketi `paletIcHrk`×`irs`×`frm` ile ayrışır. Firma: `irs.eFirma → frm.frmID`. Mağaza frmID = 1/4477/4478, GENEL=0, tedarikçi=diğer (78 firma).

| Kategori | eTip | Yön (pGC) | Firma | 2024 | 2025 | 2026 |
|---|---|---|---|---|---|---|
| **Mal Kabul** | 0 | Giriş (0) | Tedarikçi | 1.465.479 | 2.107.440 | 2.253.759 |
| **İade Kabul** | 9 | Giriş (0) | Mağaza | 28.054 | 53.321 | 61.330 |
| **GENEL Giriş** | 16 | Giriş (0) | GENEL | 84.148 | 170.070 | 330.593 |
| **Mağaza Sevk** | 13 | Çıkış (1) | Mağaza | 692.259 | 816.904 | 1.412.174 |
| **İade/GENEL Sevk** | 90+99 | Çıkış (1) | GENEL | 152.255 | 259.498 | 136.055 |

- **Heykel = Bursa Kültür** (frm: firma 60398 "HEYKEL TRANSFER DEPOSU", 60400 "Heykel Transfer"; Bursa Kültür A.Ş. = 56/58/4694/7950/9339/38093…). ⚠️ **Merkez depo sevki Heykel'e gitmiyor** — sadece 3 mağaza + GENEL. Heykel transferi **mağaza kaynaklı** (`SevkiyatHareketBaslik.HedefMekanId=60398`), merkez depo işgücüne dahil değil.
- Belirsiz: eTip=16 GENEL giriş (330K, hızlı büyüyor — e-tic iade / merkez intake?) Fikri netleştirecek.

## Görev İşgücü / Verim (Oca-May, GERÇEK operatör) — KESİN
| Görev | Kaynak | 2024 | 2025 | 2026 |
|---|---|---|---|---|
| Raflama (yerleştirme) | `paletIcHrk` pHrkTip=0,pGC=0 | 17p / 4,09M adet | 12p / 5,75M | 16p / 5,30M |
| Toplama (picking) | `emirAyr` emTamam=1 | 10p / 1,02M adet | 9p / 1,38M | 8p / 2,82M |

**Toplama verimi (kişi başı adet):** 2024 102.339 → 2025 152.816 → 2026 **352.701** (+%245). Daha az kişiyle (10→8) 2,75× iş.

## Depo İşgücü Raporu (kullanıcı formatı)
Görev×Yıl matrisi: GÖREV (Mal Kabul/Raflama/Toplama/Şoför) × {personel, 5 hareket kolonu (Mal Kabul/İade Kabul/Heykel Transfer/Mağaza Sevk/İade Sevk), Kişi Başı Adet, % Değişim}, yıl bloğu (2024/2025/2026 ilk 5 ay). Görev→hareket ATAMA modeli (aynı hareket birden çok göreve sayılabilir). Hareket adetleri=veri (eTip), personel=gerçek operatör (emKisi) veya manuel kadro. Script (planlanan): `scripts/depo_isgucu_raporu.py`.
