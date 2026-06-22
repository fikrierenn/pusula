---
name: muhasebe-denetci
description: Genel muhasebe veri denetçisi (GL forensic). Yevmiye/cari/fatura üzerinde kapanış-sonrası müdahale, ters-yön kayıt, entegrasyon kaçağı, KDV uyumsuzluğu, askıda hesap, Benford sapması, görevler-ayrılığı (SoD), round-number/mükerrer anomalilerini MEVCUT SP/view'ları çalıştırıp ÜSTÜNE muhakeme katarak (çapraz-bağ, iz-sürme, severity) Türkçe denetim raporu basar. "muhasebe denetle", "kapanış sonrası müdahale", "yevmiye anomali", "mizan kontrol", "kaçak var mı", "denetçi", "/muhasebe-denetci" denildiğinde veya aylık kapanış sonrası devreye gir. RAPORLAR + İZ SÜRER, kayıt DEĞİŞTİRMEZ.
allowed-tools: Read, Bash, Grep, Glob, mcp__sqlserver__sql_query
user-invocable: true
model: inherit
---

# Muhasebe Denetçi Skill (GL Forensic)

## Amaç
Sabit SP/view'lar "bilineni" yakalar; bu skill **üstüne muhakeme** koyar → bilinmeyeni de yakalar. Akış: sabit kontrolleri çalıştır → çapraz-bağ kur → Benford/outlier yorumla → iz sür → severity'le → Türkçe rapor. **Yalnız okur, kayıt değiştirmez.** (Footprint: SP/view = araç, skill = akıl.)

## Domain Gerçekleri (KRİTİK — sapma = yanlış bulgu)
- **DB:** `DerinSISBkm`. Şemalar: `mhs` (yevmiye/GL), `dbo` (car/fat/frm/kontrol_*).
- **İşaret:** `mhsFis.fisBA=0` = **alacak tarafı (gelir 6xx burada)**, `fisBA=1` = **borç tarafı (gider 7xx burada)**. `fisTutar` alacakta negatif saklı; bakiye = `SUM(fisTutar)`. (Canlı doğrulandı 22.06 — 600 borç-kolonunda göründü çünkü etiket ters.)
- **Şirket = dönem yılı:** `mhsFisBaslik.fisbSirketID` (6=2026, 5=2025…).
- **Yevmiye join:** `mhsFis.fisID = mhsFisBaslik.fisbID` (+`fisSirketID`) — fiş başına 2 satır (B/A). `yevmiyeNo` UNIQUE DEĞİL (join etme).
- **Gider konvansiyonu:** CAR `frm.frmKod LIKE 'G-%'` · FAT `urn.stkKod LIKE 'G-%'` · MHS hesap `hspKod LIKE '6%'/'7%'`.
- **Kapanış:** `bkm.Fin_AyKapanis` (DonemYil/DonemAy/KapanisDT). ⚠️ **2026 ayları GİRİLMEDEN** kapanış kontrolleri 2026 için boş döner — raporda belirt.
- **Manuel ayrımı:** `mhsFisBaslik.fisEntTipID=0` = elle; 1/3/4 = otomatik entegrasyon (POS/fatura batch). **SoD/zamanlama kontrolleri EntTip=0 filtreler** — yoksa false-positive seli (%85 "geç kayıt" otomatikti).
- **Kişi master = `dbo.drn1`** (insID → insAd). `gKisi/cgKisi/ckKisi/coKisi/oKisi → drn1.insID`. Raporda ID DEĞİL isim göster (`LEFT JOIN dbo.drn1`). Muhasebe ekibi (22.06): Şule(1897, CAR komisyon/faiz), Pınar(16)+pinar.muhasebe1(449)/2(450) (MHS tahakkuk), Özge (erken-2025 CAR). Küçük ekip → giren=onaylayan ÇOĞUNLUKLA yapısal (kişisel şüphe değil); giren≠onaylayan olan nadir vaka gerçek-SoD sinyali.
- **Tarih:** DMY (`CONVERT(...,104)` / `DATEFROMPARTS`).

## MCP Limiti
`mcp__sqlserver__sql_query`: **CTE yok, tek SELECT, top-level ORDER BY yok (TOP ekle), multi-statement yok.** CTE'li/DECLARE'li tam sorgular SSMS içindir. SP'ler MCP'den `EXEC` ile çağrılır (tek statement).

## Araç Envanteri (önce bunları çalıştır)

| # | Kontrol | Araç | Ne yakalar |
|---|---|---|---|
| K1 | **Kapanış-sonrası müdahale** | `EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Mod='OZET'` (+ drill `@Mod='DETAY',@GiderKod=`) | Kapanmış aya CAR/FAT/MHS geç-giriş/sonradan-değişim + RiskSkor |
| K2 | **Ters-yön kayıt** | `mhsFis` 6xx `fisBA=1` / 7xx `fisBA=0` (610/611 hariç) | Gelir/gider yanlış tarafta — düzeltme mi manipülasyon mu |
| K3 | **Dengesiz fiş** | `mhs.mhsFisKontrolBakiye_vw` / per-`fisID` `SUM(fisTutar)<>0` | Borç≠alacak (bütünlük) |
| K4 | **Entegrasyon kaçağı** | `dbo.kontrolMhsBagliCariYok_vw`, `kontrolMhsBagliFaturaYok_vw`, `kontrol_fatCarMhsFisIDFarkli_vw`, `kontrol_carMhsEntYok_vw` | Cari/fatura muhasebeye işlenmemiş/yanlış bağlı |
| K5 | **KDV uyumsuzluğu** | `dbo.kontrolFaturakdvfarkı_vw`, `raporKDV_vw`; 191 vs 391 oran bazlı | İndirilecek/hesaplanan tutarsız, oran-hesap yanlış |
| K6 | **Askıda/ara hesap** | `dbo.kontrol_mhsAraHesapKontrol_vw`; 190/196/197/369/397 uzun kapanmayan | Sayım fazlası/eksiği, şüpheli, geçici hesap birikmiş |
| K7 | **Ödenmemiş çek/vade** | `dbo.fn_odenmemisCekler`, `carCek` | Vadesi geçen/yaklaşan çek, likidite |
| K8 | **Ön muhasebe / çift fatura** | `kontrol_OnMuhasebeGiris_vw`, `kontrol_irsaliyeCiftFatura`, `kontrol_faturaNoYok_vw` | Eksik giriş, mükerrer fatura, no'suz belge |
| K9 | **Benford (ilk-iki-hane)** | `mhsFis.fisTutar` (manuel havuz) | Beklenen %4,14(10)→%0,44(99) sapma (ridge/valley) |
| K10 | **SoD / olağandışı kullanıcı** | manuel fiş (EntTip=0) `gKisi=oKisi`; kullanıcı×ters-kayıt | Giren=onaylayan, tek kullanıcıda anomali yığını |

> Yeni `kontrol_*` view'ı görürsen (`sys.objects name LIKE 'kontrol%'`) envantere ekle — Fikri'nin yazdığı onlarca var.

## Akış (muhakeme katmanı — "daha çok yakala")

1. **Dönem belirle.** Argüman yoksa: en son kapanmış ay (`Fin_AyKapanis` MAX) + içinde bulunulan ay. 2026 kapanış yoksa K1 için uyar.
2. **Sabitleri çalıştır (K1–K10).** Her birinden adet + tutar + örnek topla. Tek-SELECT/EXEC, MCP-hazır.
3. **Çapraz-bağ kur (ASIL DEĞER).** Aynı evrak/cari/kullanıcı birden çok bayrakta mı? Örn: *kapanış-sonrası + round-number + giren=onaylayan + gider carisi* → tek tek zayıf, birlikte YÜKSEK. RiskSkor'u bu kesişimle yükselt.
4. **İz sür.** Bir sinyal çıkınca derinleş: "bu kullanıcı 5 ayda kaç müdahale", "bu cari neden tekrar tekrar düzeltiliyor", "bu hesap neden hep ay sonu yuvarlak". 1-2 ek hedefli sorgu.
5. **Benford yorumla (K9).** Sapan ilk-iki-hane → o aralıktaki fişleri listele (sabit eşik dayatma; gözlem + bağlam). <~300 kayıtta Benford anlamsız — atla.
6. **Severity + öneri.** Her bulgu: Düşük/Orta/Yüksek + GM'e tek cümle "ne yapmalı".

## Çıktı — Türkçe Denetim Raporu

```
# Muhasebe Denetim — <Dönem> (<tarih>)
Kapanış: <KapanisDT> · Kapsam: CAR+FAT+MHS · 2026 kapanış: <girildi/EKSİK>

## 🔴 Yüksek Risk
- <Bulgu> — <adet> evrak / <tutar> ₺. Örnek: <EvrakNo>. <çapraz-bağ notu>. Öneri: <aksiyon>.
## 🟡 Orta
## 🟢 Bilgi / izlenecek
## Benford
- Sapan hane: <NN> (beklenen %x, gözlenen %y) → <n> fiş, örnek <…>
## Mutabakat
- Muhasebe ciro(600) vs operasyon ciro: <fark> → entegrasyon kaçağı mı
```

- Rakam = mutlaka kaynak araçtan (uydurma yok). Bulgu yoksa "temiz" de, şişirme.
- Sessiz hata yok: bir kontrol çalışmazsa (view yok / 2026 kapanış yok) raporda **açıkça** belirt.

## İkiz Yükümlülük
Anlamlı yeni keşif (yeni kontrol view, yeni anomali kalıbı) → `sema-ogren` ile `sema/*.yaml`'a + çalıştırdığın özgün SQL'i `sorgular/YYYY-MM-DD-muhasebe-denetim-*.sql`'e arşivle (`.claude/rules/semantic-layer.md`).

## İlişkili
- `sorgular/2026-06-22-muhasebe-kontrol-v2.sql` — `sp_KapanisMudahaleKontrol_v2` (K1 motoru, drill).
- `sorgular/2026-06-22-muhasebe-kontrol-DUZ.sql` — düz (SP'siz) sürüm.
- `.claude/rules/sql-server-conventions.md` — DMY/compat/işaret kuralları.
- Mevcut `denetim` skill = KOD/SQL/güvenlik denetimi (farklı); bu = muhasebe-VERİ denetimi.
