# Plan 04 — Günlük Kâr/Zarar (Kitap) — Alış Faturası vs İrsaliye Hareket Maliyet Karşılaştırması

> Tier 3 — yeni pattern (iki ayrı maliyet kaynağı + cross-db join), birden fazla dosya etkiliyor (plan + sorgu + journal + TODO).

**Tarih:** 07.05.2026
**Proje:** `bkm`
**Yazan:** Claude (oturum: 20260507-XXXXXX)
**Durum:** Tamamlandı (07.05.2026 — sorgu üretildi, doğrulandı, çalışıyor)

> **Sapma:** Plan'da iki maliyet kaynağı (fat+fatAyr ile irsHrk) karşılaştırması öngörüldü. Test sonucu 2 kritik bulgu çıktı: (1) `irsHrk.ehMlyt` BKM'de %99 boş, (2) `fatAyr.ehMaliyet` kolonu hep 0 — kullanılmıyor. Asıl formül: `ehTutarN / ABS(ehAdetN)` (DerinSIS alış faturasında ehAdet NEGATİF tutuluyor). Maliyet B kaldırıldı, tek kaynak Maliyet A ile devam edildi. Kullanıcı 07.05.2026'da onayladı.

---

## 1. Problem

CFO (Fikri) günlük kâr/zarar görmek istiyor ama BKM Kitap'ta tek bir kanonik maliyet yok. ERP'de iki ayrı yer var: alış faturası (`fat`/`fatAyr.ehMaliyet`) ve stok hareket maliyeti (`irsHrk.ehMlyt`). Bu ikisi arasında zaman gecikmesi (irsaliye → fatura), iskonto yansıma, fason/depo transfer farkları olur. Tek maliyet seçmek bilgi kaybı; ikisini ayrı kolonda göstermek **fark anomalisini de tespit edilebilir kılar** (örn. fatura geç kesilmiş ürünün marjı yanlış görünebilir).

İlk faz kapsamı sadece **kitap kategorisi (urnKtgr2 ID 2/8/15) + EncoreMerkez POS (3 mağaza)**. JOKER e-ticaret v2'ye bırakıldı.

## 2. Scope

### Kapsam dahili
- `@BasTarih`, `@BitTarih` parametrik tek T-SQL dosyası.
- Satış kaynağı: EncoreMerkez `Sales` + `SalesProducts` (IsValid=1, DocumentsTypeId 1/2/3/6/7/8 — iade sign).
- Ürün filtresi: kitap kategorisi (urnKtgr2 `IN (2, 8, 15, 24)` = Çocuk Kitabı + Hazırlık + Kitap + Akademi — kullanıcı 07.05.2026 onayı).
- Maliyet A: `fat.eGC=1 AND fat.onay=1 AND fat.eDurum=0` → `fatAyr` ROW_NUMBER per `ehStkID` ORDER BY `eTarih DESC, eID DESC`. Birim = `ehTutarN/ehAdetN` (KDV hariç net birim) **ve** `ehMaliyet` kolonu — ikisi de raporda görünür.
- Maliyet B: `irsHrk` ROW_NUMBER per `ehstkID` WHERE `ehAdetN > 0` (giriş hareketi, ehTip filtresi netleşecek doğrulama adımında) ORDER BY `ehTrhS DESC, hrkID DESC`. Birim = `ehMlyt/ehAdetN` (toplam ise) ya da doğrudan ehMlyt (birim ise).
- Cross-db join: BKM (Sales) ↔ DerinSIS (urn, fat, irsHrk) — `COLLATE Turkish_CI_AS` zorunlu.
- 2 result-set: (a) ürün-bazlı detay, (b) kategori özet (toplam brüt/indirim/net/maliyetA/maliyetB/marjA/marjB/sapma).
- Çıktı: `sorgular/04-karzarar/2026-05-07-gunluk-kar-zarar-maliyet-karsilastirma.sql`.

### Kapsam dışı (v2'ye bırak)
- JOKER e-ticaret kanalı.
- Kırtasiye / sınav okulları kategorileri.
- FIFO/ortalama maliyet (`bkm.fifo_*` tabloları).
- KDV detay kolonları (genel net üzerinden hesap, KDV oranı bilgi olarak gösterilir).
- Stored procedure'a sarma — sorgu kararlı olunca v3'te.
- Excel template — operasyonel kullanım sonrası ihtiyaç çıkarsa.

### Etkilenen dosyalar
- `plans/04-gunluk-kar-zarar-maliyet-karsilastirma.md` — bu dosya (yeni).
- `sorgular/04-karzarar/2026-05-07-gunluk-kar-zarar-maliyet-karsilastirma.sql` — final sorgu (yeni klasör + dosya).
- `TODO.md` — B-NEW-07..09 ekleme + B-07 referansı.
- `docs/journal/bkm/2026-05-07.md` — oturum notu (handoff'ta).

**Tahmini boyut:** 4 dosya / ~250 satır SQL + ~30 satır plan/journal.

## 3. Alternatifler

### A: Tek kaynak — sadece irsHrk.ehMlyt
**Açıklama:** Sadece `irsHrk` üzerinden son giriş maliyeti çekilir, fatura tarafına bakılmaz. En basit sorgu, en az join.
**Reddetme sebebi:** Kullanıcı açıkça "ikisini ayrı kolonda göster" dedi. Tek kaynak, fatura geç kesilen ürünlerde sapmayı gizler.

### B: FIFO ortalama maliyet (`bkm.fifo_*`)
**Açıklama:** `bkm.fifo_ErpDevirFiyatlari.birimMaliyet` veya `bkm.fifo_SabitFiyat.birimMaliyet` — ortalama/sabit maliyet hesabı.
**Reddetme sebebi:** Kullanıcı 07.05.2026'da "fyt/fiyatAlis_vw/frmSzlm prototip, aktif değil" uyarısı verdi. `fifo_*` tabloları da aynı şüphe altında — doğrulanmadan kullanılmaz. v3 araştırma maddesi.

### C: SEÇİLEN — fat+fatAyr (Maliyet A) + irsHrk (Maliyet B) çift kolon
**Açıklama:** İki ayrı CTE, her ürün için iki maliyet, marj1+marj2+sapma kolonları.
**Sebep:** Kullanıcı kararı + bilgi kaybı yok + sapma sinyal değeri var (geç fatura tespiti, fason iadesi anormallikleri, iskonto yansıma farkı).

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| `irsHrk.ehMlyt` birim mi toplam mı belirsiz | Yüksek (yanlış maliyet) | Orta | Doğrulama adımında 5 örnek üzerinden ehMlyt vs ehTutarN/ehAdetN ilişkisi netleşecek; kararı sorguda yorum satırına yazacağız. |
| Kitap kategori ID seçimi (2 vs 15 vs 2+8+15) | Orta | Düşük | Default `IN (2,8,15)`, sorgu üstünde `@KategoriIDList` parametre olarak yorum + ayarlanabilir CTE. |
| EncoreMerkez Products ↔ DerinSIS urn köprüsü kayıp ürünler | Orta | Orta | Sorguda `unmapped_count` kontrol kolonu; >%5 ise alarm yorum. Köprü: önce LinkedProductId, fallback Barcode↔stkKod. |
| Cross-db collation hatası | Düşük | Yüksek | Tüm string join'lerde `COLLATE Turkish_CI_AS`. |
| İade satırları sign | Yüksek (yanlış net) | Yüksek | `CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END * brüt` pattern'i kullanılacak. |
| Yabancı para alış faturası (`fat.eDvzID <> 1`) | Orta | Düşük | **Karar (07.05.2026 kullanıcı onayı):** v1'de `eDvzID=1` (TL) filtresi, döviz alışlı ürünler `MaliyetKaynak=Yok` gösterilir. v2'de eDvzKur ile çevrim. |
| NULL maliyet (hiç giriş hareketi olmayan ürün) | Orta | Orta | `ISNULL(maliyet, 0)` + `MaliyetKaynak` flag kolonu (A/B/Yok). NULL'lar kategori özetinde "MaliyetiOlmayan" alt-toplam. |
| `fatAyr` 40M satır — slow scan | Orta | Düşük | ROW_NUMBER inner CTE'de tarih filtresi (son 6 ay) + IDX_FATAYR_..._ehStkID index'i kullanılır. |
| Mağaza-içi transfer veya sayım irsHrk'da görünür | Yüksek | Yüksek | `ehTip` doğrulama adımında: alış girişi vs transfer giriş ayrımı netleştirilecek; transfer hariç tutulacak. |

## 5. Done Criteria

- [ ] Sorgu `@BasTarih='01.05.2026', @BitTarih='07.05.2026'` ile <30 saniyede sonuç dönüyor.
- [ ] Kategori özet: brüt × adet, indirim ile net, mantık check ✓ (toplam net = aynı dönem `bkm` günlük ciro raporu kitap kategorisi toplamı, ±%2 tolerans).
- [ ] Top 10 ürün için ehMaliyet, ehMlyt elle 5 örnekte cross-check ✓.
- [ ] Bir iade günü test edildi (örn. iade çok olan tarih), net negatif çıkıyor mu doğrulama ✓.
- [ ] NULL maliyetli ürün sayısı kategori özetinde gösteriliyor (gizlenmiyor).
- [ ] `MaliyetKaynak` flag kolonu üç değer alabiliyor: 'A_VeB', 'A_Sadece', 'B_Sadece', 'Yok'.
- [ ] Sorgu üstünde KULLANIM bloğu (`-- KULLANIM:` yorumu): parametre tanımı + örnek invocation + bilinen sınırlamalar.
- [ ] `TODO.md` B-07 referansıyla güncellendi.

## 6. Rollback Planı

- Sadece SQL dosyası — production şemaya yazma yok, sadece SELECT.
- Yanlış sonuç çıkarsa `git revert` ile sorgu silinir, eski rapor formatına dönülür.
- Eğer prod report'a entegre edilirse (sonraki faz): SP versiyonlama + eski SP geri çağrılır.

## 7. Adımlar

1. [x] **Kanal kararı** — sadece POS (kullanıcı onayladı).
2. [x] **DerinSIS şema keşfi** — fat/fatAyr/irsHrk doğrulandı, fyt/frmSzlm dışlandı.
3. [ ] **Doğrulama keşifleri** (sorgu yazımı öncesi 4 küçük test):
   - 3a. `irsHrk.ehMlyt` birim mi toplam mı — 10 örnek üzerinden ehTutarN, ehAdetN, ehMlyt karşılaştırma.
   - 3b. `fat.eTip` alış faturası kodları (eGC=1 içinde) — fatura tipleri tablosu varsa kontrol, yoksa 1/2/4 değerleri "alış faturası" mı netleşsin.
   - 3c. `irsHrk.ehTip` giriş kodları — alış girişi (10/100) vs transfer (96/99/101) ayrımı için ehTip + ehID→irs.eTip cross-check.
   - 3d. EncoreMerkez Products ↔ DerinSIS urn köprü doğrulama — 100 ürün üzerinden eşleşme oranı (LinkedProductId vs Barcode fallback).
4. [ ] **Maliyet A CTE** yaz — fat (eGC=1, onay=1, eDurum=0, eDvzID=1) → fatAyr LEFT JOIN urn, ROW_NUMBER per ehStkID.
5. [ ] **Maliyet B CTE** yaz — irsHrk (ehAdetN>0, ehTip alış kodları, hrkTarih son 12 ay), ROW_NUMBER per ehstkID.
6. [ ] **Satış CTE** yaz — EncoreMerkez Sales+SalesProducts kitap kategorisinde, IsValid=1, DocumentsTypeId iade sign.
7. [ ] **Detay sorgu** — ürün bazlı: stkID, stkAd, ktgrAd, adet, brüt, indirim, net, MaliyetA_birim, MaliyetA_satır, MaliyetB_birim, MaliyetB_satır, MarjA, MarjB, Sapma, MaliyetKaynak.
8. [ ] **Kategori özet** sorgu — kategori bazlı toplamlar.
9. [ ] **Doğrulama**: 01-07 Mayıs 2026 testi, top 10 elle, iade günü, NULL sayım.
10. [ ] **Dosya kaydet**: `sorgular/04-karzarar/2026-05-07-gunluk-kar-zarar-maliyet-karsilastirma.sql`.
11. [ ] **TODO.md** B-NEW-07/08/09 ekle, B-07 referansı.
12. [ ] **Journal** günün sonunda yazılacak (handoff'ta).

## 8. İlişkili

- TODO: B-07 (Faz 1 — "Ürün bazlı maliyet/marj analizi — 3Al2Öde gerçek kârlılık etkisi") ile bağlantılı, bu plan onun ön-çalışması.
- Önceki sorgular: `sorgular/04-urun/kitap_satir_analizi.sql`, `sorgular/04-urun/10_12_kategori-bazli.sql`.
- Konvansiyonlar: `.claude/rules/sql-server-conventions.md` — DMY tarih, IsValid=1, DocumentsTypeId, COLLATE.
- Önceki şema notu: `docs/05-eticaret-joker.md` (e-ticaret v2 için referans).

## 9. Onay

> Kullanıcı onay verene kadar SQL yazılmaz. Doğrulama keşifleri (madde 3a-3d) plan onayı SONRASI yapılır, çünkü 3a-3d bulguları sorgu satırlarını şekillendirir.

- [ ] Plan kullanıcıya gösterildi
- [ ] Geri bildirim alındı
- [ ] Onay alındı: ___ tarih ___ Fikri imza
