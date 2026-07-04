# Plan 27 — Banka Ekstresi Satır Sınıflandırıcı (öğrenen, öneri-bazlı)

> **Tier 3.** Yeni pattern (retrieval/embedding + öğrenme döngüsü), yeni Blazor sayfası, yeni panel tablosu, LLM entegrasyonu.
> AFCP tezinin (bkz. `.claude/skills/afcp-danisman/TEZ.md`) BKM'de ilk somut, veri-doğrulanmış pilotu.
> Başlangıç: 04.07.2026 · Durum: **Faz 0 KANITLANDI ✅ → Faz 1**

## Faz 0 sonucu (04.07.2026 — KANIT GEÇTİ)

Kanıt: C# konsol (`scratchpad/bankaproof`), 807.600 geçmiş satır (2021-2026, 1.639 cari), zaman-bazlı holdout (son 30g = 2.434 test), **saf lexical** (normalize + BA-anahtarlı çoğunluk, embedding YOK).

| Auto-onay eşiği | Kapsam | Doğruluk |
|---|---|---|
| agree≥90% & n≥3 | %73,8 | %92,65 |
| **agree≥97% & n≥5** | **%61,4** | **%98,80** ← operasyon noktası |
| agree≥99% & n≥5 | %55,4 | %99,56 |

**Kararlar:**
1. **Operasyon noktası: agree≥97% & n≥5** → satırların ~%61'i otomatik, ~%99 doğru. Kalanı istisna (top-3 aday).
2. **Embedding + LLM v1'de GEREKMEZ** — lexical yeter. Sadece hiç-görülmemiş satır (~%8 no-hit) için Faz-2 zenginleştirme (embedding/LLM aday-üretici).
3. **no-digit fallback zayıf (%45)** — virman'da hesap-no karışıyor → v1'de exact-only, no-digit'i kaldır veya sadece aday-üretici olarak kullan.
4. **Bulgu (Fikri'ye):** aynı isim→farklı cari vakaları (POİNT 60285/9525, KUARK 3 cari) muhtemel **mükerrer cari kaydı** — DerinSIS cari-master temizliği ayrı iş.

## Problem

BKM muhasebesinde en büyük tekrarlı elle-iş: **banka ekstresi satır sınıflandırma.** `DerinSISBkm.dbo.car` cTip=122 ("Banka Ekstresi") — son 30 günde **2.310 satır, ~77/gün, hepsi elle** (cFatID=0). Her satır: serbest-metin açıklamayı ("YANIT YAYINCILIK", "GARANTİ BANKA KOMİSYONU", "KESİNTİ YOLUYLA ÖDENEN VERGİLER") okuyup **hangi karşı-cariye ait** (cKodKarsi) olduğuna karar vermek + çift kayıt girmek. Kabaca 20-40 saat/ay saf sınıflandırma emeği.

**Neden AI-şekilli:** serbest-metin → varlık (cari) sınıflandırma. **Eğitim verisi hazır:** geçmiş her cTip=122 satırı bir etiketli örnek (cNot → seçilen cKodKarsi). BKM'nin yıllarca birikmiş "açıklama→cari" eşlemesi `car`'da duruyor.

## Amaç / Done kriteri

1. **Faz 0 (kanıt):** geçmiş 122 satırlarında holdout testi — "açıklama+tutardan geçmişe bakarak cKodKarsi tahmin edilebilir mi?" Eşik: yüksek-güven kovada ≥%85 doğruluk + ≥%50 kapsam. TUTMAZSA plan durur / yeniden düşünülür.
2. **Faz 1 (motor):** kural + retrieval sınıflandırıcı → her yeni satıra `(önerilen cKodKarsi, güven, top-3 aday, gerekçe)`.
3. **Faz 2 (arayüz):** Blazor "Banka Ekstresi Eşleştirme" sayfası — yeşil auto tek-tık onay, sarı istisna kuyruğu, toplu-onay.
4. **Faz 3 (öğrenme):** her onay/düzeltme index'e eklenir; auto-fill eşiği kabul/düzeltme metriğiyle ayarlanır.

**Bitmiş sayılır:** muhasebeci bir haftalık ekstreyi, satırların ≥%70'ini tek-tık/toplu onaylayıp kalanı elle seçerek, bugünkünün çok altında sürede kapatır.

## Kapsam (scope)

- **İÇİNDE:** cTip=122 satır sınıflandırma önerisi; öğrenen index; Blazor öneri/onay sayfası; kanıt scripti; kural+retrieval+kuyruk-LLM motoru.
- **DIŞINDA (şimdilik):** `car`'a otomatik YAZMA (erp-write-policy — sadece öneri, insan DerinSIS'e girer). Diğer cTip'ler (Kredi Kartı 103 vb. sonraki faz). Otomatik e-defter. Diğer şirketler/SaaS.

## Kritik kısıtlar

- **erp-write-policy:** ERP'ye (`Db.OpenAsync`) TEK yazılabilir hedef `bkm.Fin_AyKapanis`. Bu pilot `car`'a **YAZMAZ.** Öğrenme/öneri verisi **`BkmPanel`** (yazılabilir, app-local) `dbo.Panel*` tablolarında. İnsan öneriyi görür, DerinSIS'e kendi girer.
- **Gizlilik (KVKK):** banka açıklamaları hassas (isim/tutar). **Embedding YEREL** (bge-m3 / multilingual-e5, CPU). Dışarı API'ye ham banka verisi gönderilMEZ. Kuyruk-LLM kullanılırsa yalnız açıklama + aday-isimler (tam mali veri değil) veya yerel model.
- **Türkçe varchar:** okuma scriptleri **pyodbc + ODBC Driver 18** (pymssql CP1254 bozar — coding-discipline).
- **3-parçalı isim:** app `master` bağlamında → `DerinSISBkm.dbo.car` (sql-server-conventions).

## Mimari (katmanlı — refleks "LLM at" DEĞİL)

Satırların %80+'i tekrar → asıl problem hafıza/arama, muhakeme değil.

| Katman | Ne | Kapsam | Maliyet |
|---|---|---|---|
| 1. Kural (deterministik) | tam/regex eşleşme ("BANKA KOMİSYONU"→sabit hesap) | ~%40 | sıfır |
| 2. Retrieval (embedding k-NN) | benzer geçmiş satır → cKodKarsi oy | ~%45 | ucuz, yerel |
| 3. Kuyruk-LLM (re-ranker) | belirsiz satır: top-3 adaydan seç ya da "belirsiz" | ~%15 | sınırlı |

Güven = f(top-1 benzerlik, oy marjı, kural tetiği). Eşik-üstü → auto öneri; altı → istisna kuyruğu.

## Teknoloji

- **Embedding:** yerel `bge-m3` veya `multilingual-e5-large` (sentence-transformers, CPU). Faz 0 bunsuz başlar (token-Jaccard baseline) — embedding Faz 1'de.
- **Vektör:** abartma yok. Geçmiş birkaç yüz bin satır → `BkmPanel` tablosunda embedding (varbinary/JSON) + Python/C# cosine. Ağır vektör-DB gereksiz.
- **Kuyruk-LLM:** mevcut `dashboard/Data/Asistan/ILlmProvider.cs` soyutlaması (Groq/Gemini/OpenRouter/Zai/Fallback) tekrar kullanılır; gizlilik için yerel opsiyon flag'li.
- **Arayüz:** Blazor (`asistan-ui` + `renk-standardi`: success/warning/error = güven bandı).

## Alternatifler (reddedilen)

1. **Saf LLM per-satır (zero-shot):** pahalı değil ama halüsinasyon (olmayan cari uydurur), BKM-özel binlerce cari label'ı bilmez, doğal güven yok. → Reddedildi; retrieval + kuralı yener.
2. **Klasik ML sınıflandırıcı (TF-IDF + GBM/logistic):** label uzayı binlerce cari, yeni cari geldiğinde retrain, zarif değil. → Retrieval daha iyi oturuyor (yeni örnek = index'e ekle, retrain yok).
3. **`car`'a otomatik yazan tam otomasyon:** erp-write-policy ihlali + güven inşa edilmeden riskli. → Reddedildi; öneri-önce, insan-onay.
4. **Bulut embedding (OpenAI):** KVKK/banka-verisi dışarı. → Reddedildi; yerel embedding.

## Riskler

- İsimsiz satır ("HAVALE") → sınıflanamaz, istisnada kalır (kabul).
- Tutar zayıf sinyal; asıl sinyal metin. Bazı cari sadece tutar deseniyle ayrışır.
- Yeni tedarikçi → yakın komşu yok → düşük güven → istisna (doğru davranış).
- Türkçe kısaltma/embedding kalitesi ("GRNT", "ÖD.") test edilmeli.
- Kanıt (Faz 0) eşiği tutmazsa → pilot yeniden düşünülür (banka-ekstresi tekrarı sandığımızdan az olabilir).

## Rollback

- Faz 0: sadece script, DB'ye dokunmaz — silmek yeter.
- Faz 1-3: tüm veri `BkmPanel.Panel*` tablolarında, ERP'ye sıfır yazma → tablo drop + sayfa/servis kaldır. ERP etkilenmez.

## Adımlar (sıra + bağımlılık)

- [ ] **F0.1** Kanıt scripti `scripts/banka_siniflandirma_deneme.py` — holdout, token-Jaccard baseline, doğruluk@güven-bandı. *(bağımlılıksız)*
- [ ] **F0.2** Sonucu değerlendir → eşik tutar mı? Tutmazsa DUR.
- [ ] **F1.1** `BkmPanel` şema: `PanelBankaOrnek` (öğrenme index: normNot, embedding, cKodKarsi, kaynak, onaylayan, zaman) + `PanelBankaOneri` (öneri kuyruğu).
- [ ] **F1.2** Bootstrap scripti: geçmiş cTip=122 → index doldur (+ embedding hesapla).
- [ ] **F1.3** Sınıflandırma motoru (kural + retrieval + kuyruk-LLM) — C# servis `BankaSiniflandirmaService` veya Python + C# köprü (ortak SQL tablo — coding-discipline).
- [ ] **F2.1** Blazor sayfa `BankaEkstresi.razor` + `BankaQueries` (öneri listele, onay yaz `BkmPanel`).
- [ ] **F2.2** UI: güven bandı, top-3 aday, tek-tık + toplu onay, istisna filtresi.
- [ ] **F3.1** Öğrenme döngüsü: onay/düzeltme → index append; metrik (kabul/düzeltme) → eşik ayarı.
- [ ] **F3.2** Kanıt/metrik paneli: auto kapsam + doğruluk zaman serisi (mini kanıt-zinciri).

## F1 durumu (04.07 — bağımsız app kuruldu, canlı test)

- **Bağımsız app** `D:\Dev\pusula\muhasebe` — Razor Pages + Dapper + Tailwind, **API YOK** (Operax `D:\Dev\operax` mimarisi baz). Blazor mis-scaffold düzeltildi. Build temiz (0 hata). Feature-based (`Features/BankaEkstresi`, `Features/Dashboard`), `Lib/Db.cs` (.env → DerinSISBkm salt-okuma), `Lib/BankaSiniflandirmaService.cs` (in-memory index, öneri-only). Auth/Audit/CsvExport/yerel-LLM = sonraki faz (Operax'tan alınacak; survey `.claude` görev çıktısında).
- **Canlı smoke (gerçek DB, tarayıcı):** motor 807K index'i yükledi, uçtan uca sınıflandırdı. ✅
- **UI + auth ✅ (04.07):** (a) **Banka hesabı dropdown** (cKod seçimi — bu ekstre hangi hesap; son-12-ay AKTİF filtre, 286→119; frmKod=GL alt-hesap 102.10.x). (b) **İstisna cari-arama** (`OnGetCariAra` JSON handler + min-JS: isim/kod ara → sonuca tıkla → son-odaklı satır kutusuna yazar). (c) **Windows auth** (Negotiate — DerinSIS'le aynı domain kimliği; dev'de zorlanmaz, prod'da `FallbackPolicy`; `Kim`=`User.Identity.Name` fallback "muhasebe"). Sarı-vurgu = İstisna (onay bekliyor). Build yeşil, canlı doğrulandı.
- **Aktif öğrenme ✅ (04.07):** `bkm.BankaOgrenme` (app-owned, DerinSIS bkm şeması — erp-write-policy güncellendi) + onay/düzelt UI. Öğrenilen-index ÖNCELİKLİ (geçmişi ezer), belleğe anında + kalıcı. Canlı doğrulandı: İstisna→onay→"öğrenildi" AUTO, DB'de Id=1 (Türkçe nvarchar korundu). Düzeltme=`kaynak='duzeltme'`, onay=`onay`. `OgrenmeKaydet` + `_ogrenilen` + `Karar(ogrenildi:true)`.
- **KRİTİK BULGU (canlı test holdout'u düzeltti): yön (cBA) = PERSPEKTİF.** cTip=122 çift-kayıt: her satırın ayna tarafı var. Yanlış yön → **banka hesabını** önerir (virman/ayna); doğru yön → gerçek cari/gider. Aynı 3 açıklama BA=1'de banka, BA=0'da doğru cari (YANIT→223, komisyon→40824, vergi→8172) verdi. **Holdout %92-99 iyimserdi** — ham next-row tahmini iki perspektifi karıştırıyordu. Gerçek doğruluk perspektif kilitlenince netleşir.
- Doğru perspektifte bile örnekler İstisna'ya düştü (agree<%97 veya n<5) → sistem **false-auto'dan kaçınıyor** (doğru muhafazakâr davranış). AUTO kovası perspektif kilitlenip gerçek batch koşunca dolar.

### Perspektif kilidi ✅ (04.07 — doğrulandı + motora uygulandı)
- Eğitim/index filtresi = `cKod frmTip=5 (banka)` satırlar (582K/807K). Ayna/virman gürültüsü kalktı.
- **Ölçülen kazanım:** agree≥97%/n≥5 → **%69,7 kapsam · %99,62 doğruluk** (kilitsiz %61/%98,8 idi). agree≥90%/n≥3 doğruluk %92,65→%99,07.
- `BankaSiniflandirmaService.YukleAsync` bankaSet (frmTip=5) yükler + filtreler. Build yeşil.
- KALAN: ham ekstrenin borç/alacak kolonu → doğru BA eşleme (Monday, gerçek dosyayla).

## DerinSIS giriş ekranı ↔ motor alan eşlemesi (04.07 — ekran teyitli, elle giriş)

Cari giriş ekranı (İşlem Türü="Banka Ekstresi"). Şule'nin elle doldurduğu alanlar:

| Ekran alanı | Kaynak |
|---|---|
| Notlar (banka açıklaması) | banka Excel = **girdi** |
| İşlem Türü | sabit "Banka Ekstresi" (cTip=122) |
| Karşı Hesap Kodu | **banka hesabı — sabit** (ekstre hangi bankaysa; ör. 4522 Garanti) |
| Alacak/Borç | Excel yön (±) |
| Tutar / İşlem-Vade Tarihi | Excel |
| **Hesap Kodu (gerçek cari)** | **← Şule muhakemesi = MOTOR TAHMİNİ** (tek otomatikleşen alan) |

**Motor sözleşmesi:** girdi = (banka, yön, tutar, **açıklama**) → çıktı = **Hesap Kodu (banka-olmayan gerçek cari)** + güven + top-3 + GL hesap (mhsEntFrm). Eğitim/tahmin hedefi = çiftin **banka-olmayan tarafı** (`cKod ∈ banka hesapları olan satırın cKodKarsi`'si, ya da eşdeğer: 4522-olmayan taraf). cBA tek başına ayraç değil — banka-perspektifi ayraç.

## Pazartesi (07.07) — gerçek dosya doğrulaması + içeri-alma

1. Fikri **ham banka ekstresi Excel** + **işlenmiş (girilmiş) hali** getirir.
2. Ham → motor (`ClassifyBatchAsync`) → **işlenmiş hali üret** (satır→cari öneri). Excel-oku yolu bağlanır (kolon eşleme tarih/tutar/açıklama/yön).
3. Üretilen vs gerçek işlenmiş → uçtan uca doğruluk (holdout %99; gerçek dosyada teyit).
4. **SP tarama:** banka ekstresini bugün DerinSIS'e alan SP/mekanizma (`car` cTip=122 üreten) → entegrasyon yolu (öneri nasıl içeri alınır — sonraki faz, ERP-write onayına tabi).

Not: ham ekstrede **yön** (borç/alacak / ±) kolonu şart (motor BA ayırır); işlenmişte **karşı cari kod/ad** görünsün (karşılaştırma).

## Genişleme fırsatları (04.07 araştırma — veri-doğrulandı)

- **Faz-1.5: Kredi Kartı (cFatTip=103)** — 2. manuel sınıflandırma darboğazı (1.640 satır/90g, 166 cari). Banka ekstresiyle AYNI şekil → motor `cTip IN (122,103)` ile ~sıfır ek kodla genişler. 122 kanıtlanınca ekle. (Virman 102/Nakit 100/KDV-cari 19 = küçük/mekanik, düşük öncelik.)
- **Ayrı bet: Mutabakat / açık-kalem asistanı (idea C)** — `cKalan<>0` yaşlandırma (04.07): 0-90g ~1.300 satır/510M (canlı-aksiyonel) + **1yıl+ 290.226 satır/3,54 mlr / 3.757 cari** (çoğu mutabakat-hijyeni borcu, anlamsız vade dahil — aktif alacak DEĞİL sanılıyor; triyaj gerek). Ağır, muhakeme-yoğun → ayrı plan, bu hafta değil. `mali-islem-akislari` skill disiplini.
- **Elenenler (veri çürüttü):** GL-mapping boşluk raporu (305 karşı-cari %100 eşli, boşluk 0) · postalanmamış backlog (sadece 186/%3, %97 temiz).

### Araştırma-dayanaklı katman ekleri (04.07 — sektör best-practice + literatür)
Sektör (Xero/QuickBooks/fintech API) = **yerel katmanlı sınıflandırıcı + düzeltmeden-öğrenme** (bizim yaptığımız, doğrulandı; kaynak: Quadratic/ExpenseSorted/HITL-Springer-2022). Eksik + eklenecekler:
- **Katman sırası:** L1 öğrenilen-exact (VAR) → L2 **skill/kural katmanı** → L3 exact-history (VAR) → L4 embedding (no-hit) → L5 human.
- **L2 skill/kural genelleştirme (HITL rule induction):** tekrarlı düzeltmelerden token/pattern kural türet ("KOMİSYON içeren → komisyon gideri", "HGS → 3988"). Motor ÖNERİR, Şule ONAYLAR (aşırı-genelleme riski → onaysız otomatik kural YOK). No-hit (~%8) + digit-yoğun virman kuyruğunu kapatır. Instance-based ezberin üstüne generalization.
- **Tutar sinyali (F1.5):** sektör "amount patterns" kullanıyor; biz sadece açıklama+yön. Belirsiz (İstisna) satırlarda tutar tiebreaker.
- **L4 embedding (F2):** yerel sentence-transformer/ONNX (LLamaSharp/local-llm-integration skill) — hiç-görülmemiş açıklama için semantik komşu. KVKK: yerel, banka verisi dışarı çıkmaz.
- **cKod (banka hesabı) = SEÇİM, tahmin değil:** ~30 şirket banka hesabı (alt-hesaplar: Garanti G001/G002/G006/G008/G009/G011...). Ekstre tek-hesap → per-file dropdown (frmTip=5) / Excel IBAN'dan auto. `frmKod`=GL alt-hesap (102.10.x) deterministik. Virman karşı-hesabı cKodKarsi olarak tahmin edilir.

## İlişkili

- `.claude/skills/afcp-danisman/TEZ.md` — kategori tezi (bu pilot onun mikro-modeli).
- `.claude/rules/erp-write-policy.md` — sıfır ERP-yazma korkuluğu.
- `.claude/rules/coding-discipline.md` — pyodbc, Python↔C# ortak-tablo köprüsü, yerel embedding.
- `dashboard/Data/Db.cs` — `OpenPanel` (yazılabilir) / `OpenAsync` (ERP salt-okuma).
- `dashboard/Data/Asistan/ILlmProvider.cs` — kuyruk-LLM soyutlaması (tekrar kullan).
