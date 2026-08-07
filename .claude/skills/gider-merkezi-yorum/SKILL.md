---
name: gider-merkezi-yorum
description: Gider Merkezi Dağılımlı Mizan (dashboard /gider-mizan + sorgular/*gider-merkezi-mizan*.sql) çıktısını YÖNETİCİ gözüyle yorumlar. Dağıtım kalitesi (atanmış vs GENEL, GENEL'i kurumsal-vs-dağıtılabilir ayır), konsantrasyon (Pareto merkez/hesap), sabit-değişken, trend (MoM), mağaza/kafe/merkez kıyas, aksiyon. "gider merkezi yorumla", "gider dağıtımı nasıl", "hangi merkez neye harcıyor", "GENEL neden şişik", "gider analiz", "masraf merkezi", "/gider-merkezi-yorum" denildiğinde veya gider-mizan çıktısı yorumlanacaksa devreye gir. RAPORLAR + YORUMLAR, kayıt DEĞİŞTİRMEZ. Overclaim YASAK.
---

# gider-merkezi-yorum — Gider Merkezi Mizanı Yorumcusu

Gider Merkezi Dağılımlı Mizan'ın (7xx + gider-6xx, merkez bazlı) rakamlarını **iş kararına** çevirir. Rapor üretir/çalıştırır DEĞİL — mevcut çıktıyı (dashboard `/gider-mizan`, `GiderMizanQueries`, `sorgular/2026-08-06-gider-merkezi-mizan-matris.sql`) OKUR, muhakeme katar. Kaydı DEĞİŞTİRMEZ.

## Omurga: OVERCLAIM YASAK
Her iddia = **rakam + kaynak + kontrol-edilebilirlik**. "Merkez X kötü yönetiliyor" DEME — "Merkez X gideri Y ama Z'nin çoğu sabit/kurumsal (kontrol dışı)" DE. Sinyal ile gürültüyü ayır; belirsizliği açık yaz.

## Veri kaynağı (sema-driven)
- Metrik tanımı: `sema/metrics.yaml` → `gider_mizan_dagitim` (7xx + gider-6xx 62/63/65/66/68, gelir 6xx HARİÇ, Bakiye=Borç−Alacak, Kapanış-hariç, yıl=sirketID+2020).
- Köprü: `sema/bridges.yaml` → `mhsfis-gdrmerkez` (fisGdrMerkez→frm) + `posmagaza-gdrmerkez` (mağaza→gider merkezi).
- ERP-native referans: `mhs.mhsGelirTabloGiderMerkeziDetayli` (6xx-only P&L — opex'i GÖSTERMEZ, bu rapor tamamlar), `kontrol_masrafmerkezibosolan6li/7li_vw` (atanmamış kontrolü).

## Analiz Çerçevesi (sırayla)

### 1. Dağıtım Kalitesi — İLK BAKILACAK (BKM'de kritik)
GENEL (fisGdrMerkez=0 = atanmamış) payını ölç. AMA ikiye AYIR — bu adım atlanırsa yanlış alarm:
- **Kurumsal/dağıtılamaz** (meşru GENEL): 780 finansman (kredi faizi — şirket geneli), 689 KKEG/vergi cezası, bazı 770 merkez-ortak. Bunlar doğası gereği merkeze atanmaz.
- **Dağıtılabilir-ama-atanmamış** (ASIL BULGU): personel ücreti (`x.10.001/002` 740/760/770), kira (`760.40.005`), SSK, enerji — mağaza/kafe/departmana atanabilir ama GENEL'de duruyor. Bu, **per-mağaza gerçek maliyet/kârlılığı imkânsız kılar**.
- Çıktı: "GENEL %X — bunun %A'sı kurumsal (meşru), %B'si dağıtılabilir (aksiyon)."

### 2. Konsantrasyon (Pareto)
- Hangi 3-5 merkez giderin %80'ini taşıyor? Hangi 5-10 hesap?
- Tek-hesap yoğunlaşması (ör. 780 kredi faizi tek başına GENEL'in ~%40'ı) → o kalem ayrı yönetilir, ortalamaya yayma.

### 3. Sabit vs Değişken / Kontrol-edilebilirlik
- Sabit (kira, amortisman, kredi faizi, personel-çekirdek) vs değişken (enerji, sarf, komisyon, mesai).
- Kontrol-edilebilir mi: alıcı/merkez kararına bağlı mı, yoksa sözleşme/yasa mı (vergi, SSK, faiz)? Hesap-sorulabilir gideri ayır.

### 4. Trend (MoM / kümüle)
- Ay×merkez matrisinde sıçrama/mevsimsellik. Tek-ay outlier mı süreklilik mi (bkz. istatistik-analiz — z-score/IQR gerekiyorsa oraya devret).
- Kira/ücret sabit → düz olmalı; sıçrama = yeni sözleşme/işe alım veya kayıt hatası (muhasebe-denetci'ye işaret).

### 5. Benchmark (kıyas — dikkatli)
- Mağaza gideri ancak CİRO/m²/personel ile normalize edilince kıyaslanır (ham TL yanıltır — büyük mağaza doğal olarak çok harcar).
- Kafe 740 (hizmet üretim) ≠ mağaza 760 (pazarlama) — farklı fonksiyon, çapraz-kıyas yapma.
- Ciro verisi bu raporda YOK → kıyas için net_ciro (sema metrics) ile birleştir; yoksa "kıyas için ciro gerekli" de, uydurma.

### 6. Aksiyon (kanıtlı, dar)
- Her aksiyon bir rakama bağlı: "760.10.001 Ücret 35,9M GENEL'de → mağaza dağıtımı yapılırsa per-mağaza P&L açılır."
- Dağıtım anahtarı öner (ciro/personel/m²) ama "karar muhasebe/CFO'da" — sen dayatmazsın.

## Çıktı Formatı
1. **Tek cümle özet** (en kritik bulgu).
2. **Dağıtım kalitesi tablosu** (atanmış / GENEL-kurumsal / GENEL-dağıtılabilir + %).
3. **Konsantrasyon** (top merkez + top hesap).
4. **2-4 aksiyon** (rakam-bağlı, kontrol-edilebilirlik etiketli).
5. **Belirsizlik notu** (ciro yok / dönem eksik / kayıt teyidi gereken).

## Sınırlar
- Rakam ÜRETMEZ — mevcut mizan çıktısını yorumlar. Yeni rakam gerekirse `sorgular/*gider-merkezi-mizan*.sql` çalıştır (sema-driven).
- Anomali/forensic (kapanış-sonrası müdahale, mükerrer, Benford) → `muhasebe-denetci`. İstatistiksel anlamlılık/outlier → `istatistik-analiz`. Bu skill = STRÜKTÜR + DAĞITIM + KARAR yorumu.
- Overclaim yasak: kontrol-dışı gideri (faiz/vergi/SSK) "kötü yönetim" sayma.

## İlişkili
- `sema/metrics.yaml` (gider_mizan_dagitim) · `sema/bridges.yaml` (mhsfis-gdrmerkez, posmagaza-gdrmerkez)
- `dashboard/Data/GiderMizanQueries.cs` · `sorgular/2026-08-06-gider-merkezi-mizan-matris.sql`
- `.claude/skills/muhasebe-denetci` (forensic) · `istatistik-analiz` (anlamlılık) · `yonetici-rapor` (belge)
- `.claude/rules/emitter-ayrimi.md` (çekirdek tek, yorum ayrı emitter)
