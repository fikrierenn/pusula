---
name: veri-dogrula
description: Analiz/rapor CFO'ya gitmeden metodoloji + doğruluk QA. Rakam üreten her analiz, SQL sonucu, dashboard verisi veya rapor taslağı için pre-delivery denetim — BKM-özel çek-liste (IsValid, iade sign, KDV-hariç, fiş-bazlı müşteri, DiscountTotalDirect) + genel pitfall kataloğu (join explosion, average-of-averages, eksik dönem). "veri doğrula", "rapor doğrula", "analizi kontrol et", "sayılar tutuyor mu", "CFO'ya gitmeden bak", "/veri-dogrula" denildiğinde veya önemli rakamlı çıktı teslim edilmeden önce devreye gir. RAPORLAR, kaynağı kendiliğinden DEĞİŞTİRMEZ.
---

# veri-dogrula — Teslim Öncesi Analiz QA

> `yonetici-rapor` overclaim-yasak omurgasının rakam ayağı: iddia = kanıt + güven. Bu skill kanıtı denetler.
> Girdi: konuşmadaki analiz, SQL+sonuç, rapor dosyası, dashboard sorgusu — hangisi varsa.

## 1. Metodoloji (soru doğru mu?)

- **Soru çerçevesi:** analiz gerçekten sorulan soruyu mu cevaplıyor? Farklı yorumlanabilir mi?
- **Dönem kıyası adil mi:** MTD vs tam-ay kıyası YASAK (eksik dönem). YoY/MoM aynı gün-sayısı / aynı takvim kesiti.
- **Popülasyon:** istemeden dışlanan var mı (mağaza, kanal, belge tipi)? Kapsam raporda AÇIK yazılmış mı?
- **Baz:** oran değişimlerinde pay VE payda ayrı incelendi mi (denominator shift — oran düştü ama sebep payda büyümesi olabilir)?

## 2. BKM-Özel Çek-Liste (her madde sorguda ara, ✓/✗ işaretle)

| # | Kontrol | Yanlışsa belirti |
|---|---|---|
| 1 | `SalesProducts` → `IsValid = 1` var mı? | adet/ciro şişer |
| 2 | İade: SUM'da DocType=3 negatif sign, AVG'de hariç mi? | ciro şişer, sepet ort. bozulur |
| 3 | Müşteri raporu FİŞ bazlı mı? (sayım DocType=1, ciro (1,3); Fatura/Personel/Sınav-8 HARİÇ) | kartsız 266M-vakası (B-102) |
| 4 | İndirim = sadece `DiscountTotalDirect` mi? | Campaign eklenirse çift sayım |
| 5 | Net ciro = `GrossTotal - DiscountTotal - VatTotal` mi? `TotalAmount` KULLANILMIŞSA hata | TotalAmount ≠ ciro (çöp değer) |
| 6 | Ürün eşleşmesi stkID üstünden mi? (`stkKod=BarcodeNo` join YASAK; POS köprü `Products.Code=stkID`) | kategori sessiz kaçar (Oyuncak vakası) |
| 7 | Tarih: yerel DMY/104, ODAKJOKER `YYYYMMDD` mi? | linked-server sessiz yanlış aralık |
| 8 | Cross-db string join → `COLLATE Turkish_CI_AS` var mı? | collation hatası veya sessiz kaçak |
| 9 | `ehAdetN` işareti doğru mu? (satış 1/4/100 negatif çıkış; mutlak gerekiyorsa ABS) | adet toplamı ters/sıfırlanır |
| 10 | Hedef kıyası prorate-tabanlı mı? (BKMDATA.Hedef tarih<bugün; %100 taban, takvim-pace değil) | önde/geride etiketi yanlış |
| 11 | İç-kart filtresi (`IcKartFiltre`) uygulanmış mı (müşteri/sadakat)? | Kumbara/Mağaza kartı gerçek müşteri sanılır |
| 12 | Dapper: 8+ kolon ValueTuple mı? → record olmalı | 8. kolon sessiz 0/null |

## 3. Genel Pitfall Kataloğu

- **Join explosion:** 1-N join sonrası SUM şişer. Test: join'li satır sayısı vs kaynak satır sayısı.
- **Average of averages:** grup ortalamalarının ortalaması ≠ genel ortalama. Ağırlıklı hesapla.
- **Survivorship bias:** sadece hâlâ aktif/mevcut kayıtlar üzerinden geçmiş yorumu.
- **Filtre tutarsızlığı:** aynı rapordaki iki metrik farklı WHERE ile — kıyaslanamaz.
- **Yuvarlanmış ara-değerle hesap:** ham veriden tek seferde hesapla, ara yuvarlama biriktirme.

## 4. Spot-Check (bağımsız yeniden hesap)

- 1-2 kilit rakamı FARKLI yoldan yeniden hesapla (örn. kategori toplamı vs genel toplam; irsHrk vs Encore kıyası).
- Alt-toplamlar toplamı = genel toplam mı? Yüzdeler ~%100 mü?
- Büyüklük mantıklı mı? (günlük mağaza cirosu bilinen aralıkta mı — sıfır/10x sapma = kırmızı bayrak)

## 4b. Cross-Source Mutabakat Sweep

> _Uyarlama: `/last30days` aynı hikâyeyi 20 kaynakta bulup dedup eder. BKM analoğu: aynı metriği ≥2 bağımsız kaynakta hesapla, sapmayı bayrakla._ Rakam tek kaynaktan geliyorsa **doğrulanamaz** — mümkünse ikinci kaynakla çapraz-kontrol.

**İlke:** aynı iş-metriğini **≥2 bağımsız kaynakta** hesapla → aynı grain'e getir → `|fark| / taban > tolerans` (varsayılan %1) → **bayrakla + kök-sebep sınıfla.** Uymuyorsa sustur değil — raporla (sessiz-fallback yasak).

**BKM kaynak çiftleri (tipik mutabakatlar):**

| Metrik | Kaynak A | Kaynak B | Hizalama dikkati |
|---|---|---|---|
| Net ciro (mağaza) | DerinSIS `irsHrk` (ehTip 1/4/100) | EncoreMerkez `Sales` (POS) | grain (ehTrhS vs Sales.Date), iade-sign, KDV-hariç, collation |
| Alış (adet/tutar) | `fatAyr` eTip=0 | `irsHrk` ehTip=0 | tarih anchor, ehAdetN işareti |
| E-tic ciro | JOKER (satır net) | EncoreMerkez online kanalı | türeme filtresi, ISO tarih |
| Stok | `irsHrk` canlı | WMS `depo.*` + ODAK `ent.odak_depo_Stok` | transit mekan hariç (26142/4480/4835) |
| Personel/gider | `BKM_GENEL` (Zirve) | DerinSIS mhs | dönem, cari köprü |

**Yöntem:** her kaynağı **bağımsız** hesapla (emitter-ayrımı: ortak grain, ama sorguyu tek kaynaktan türetip diğerine uydurma — bağımsızlık kaybolur). Kök-sebep sınıfları: **grain uyumsuz · filtre farkı · tarih kayması · collation kaçağı · kapsam (dahil/hariç belge tipi)**. Fark tolerans-içiyse ✓ "iki kaynak mutabık"; dışıysa ✗ + hangi sınıf.

**Sınır:** her metrik iki-kaynaklı değildir (ör. WMS operatör verimi tek kaynak). Tek-kaynak metrik → çıktıda "mutabakat yok, tek kaynak" notu (overclaim değil, dürüst).

## 5. Çıktı

Bulgu tablosu: `# | İddia/Metrik | Kontrol | Sonuç (✓/✗/şüpheli) | Kanıt`. Sonuna tek satır güven notu: **yüksek / orta (şu belirsizlik) / düşük (teslim etme)**. ✗ bulgular kullanıcı onayı olmadan düzeltilmez — raporla.

## Anti-pattern

- ❌ "SQL çalıştı, sonuç geldi → doğru." Çalışmak ≠ doğru rakam.
- ❌ Sadece konvansiyon bakıp metodolojiyi atlamak (o iş `sql-denetci`'nin; buranın işi metodoloji + rakam).
- ❌ Şüpheli bulguyu sessizce düzeltip teslim — önce raporla.

## İlişkili
- `.claude/rules/sql-server-conventions.md` — çek-liste maddelerinin kaynağı.
- `.claude/rules/emitter-ayrimi.md` — tek hesap çekirdeği/çoklu emitter (§4b bağımsızlık ilkesi buradan).
- `.claude/agents/sql-denetci.md` — dosya-düzeyi konvansiyon taraması (tamamlayıcı).
- `.claude/skills/yonetici-rapor/SKILL.md` — overclaim-yasak omurga (bu skill kanıt ayağı).
- `.claude/skills/tablo-profil/SKILL.md` — tanınmayan tablo → önce profil.
