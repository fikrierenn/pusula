# AFCP Tezi — Otonom Finansal Kontrol Düzlemi

> `afcp-danisman` skill'inin grounding dokümanı. Kaynak: 03.07.2026 kurul oturumu (Fikri + kurul).
> Bu bir "kesin gerçek" değil — **çürütülmeye açık, gelişen tez.** Danışırken güncelle.

## 0. Çürütülen premis

"ERP+Muhasebe+Finans+Satın Alma+İK+WMS+E-Ticaret+MIS'i tek AI platformunda **birleştir**" = süper-monolit refleksi (SAP/Oracle/Netsuite 40 yıl denedi, tam başaramadı). AI entegrasyon probleminin çözümü değil, **artık gereksiz olduğunun** kanıtı.

Gerçek kayma: **birleştirme değil, ayrıştırma.** Bugünkü ERP 3 şeyi tek yerde tutar → hantal:
1. Kayıt (system of record)
2. Mantık (iş kuralı, mevzuat, hesap)
3. Arayüz (ekran, form, onay)

AFCP bunları böler: kayıt commodity olur, zekâ üstteki **kontrol düzlemine** kayar. (Kubernetes analojisi: sunucuları birleştirmedi, aptallaştırıp zekâyı control plane'e taşıdı.)

## 1. 20 fikir → 15 öldü → 5 kaldı

**20 ham fikir:** sürekli kapanış · mevzuat-as-code · kanıt zinciri · istisna-öncelikli muhasebe · tevkifat sınıflandırıcı · nakit-öngörü · otonom mutabakat · denetçi-kopyası · vergi-optimizasyon · sözleşme→muhasebe · otonom satın alma · fraud refleks ağı · bordro muhakeme · konuşma-MIS · e-fatura semantik ayrıştırıcı · senaryo-motoru · denetim-izi üreteci · tedarikçi-risk · KDV iade dosyalayıcı · karar-sorumluluk protokolü.

**Öldürme gerekçeleri:**
- Özellik-kategori-değil (vergi-opt, senaryo, konuşma-MIS) → moat'suz, 6 ayda kopyalanır. Kategoriye feature olarak gömüldü.
- Finans-dışı (satın alma, tedarikçi-risk) → kategoriyi bulandırır (monolit tuzağı).
- Tahmin oyuncağı (nakit-öngörü, senaryo) → yanlış çıkınca sorumsuz, Anaplan/Pigment zaten var.
- Point-solution'lar (tevkifat, bordro, e-fatura, KDV-iade) → aynı fikrin parçası: "mevzuatı kod yap + ajanla uygula" → #2'ye birleşti.
- Aynı damar (kapanış, mutabakat, istisna) → tek fikre birleşti.

**5 hayatta kalan (her biri kopyalanamaz varlık biriktirir):**
1. Mevzuat-as-Code Motoru
2. Kanıt Zinciri / Evidence Ledger
3. İstisna-Öncelikli Sürekli Kapanış
4. Sürekli İç-Denetim / Auditor Twin
5. Karar-Sorumluluk Protokolü

Bunlar 5 ayrı ürün değil — **5 katman, tek organizma = AFCP.** #2+#5 (mevzuat-kod + sorumluluk) olmadan diğerleri Türkiye'de hukuken çalışamaz → asıl moat orada.

## 2. Vizyon

2035'te muhasebe departmanı "veri girişi + kapanış ekibi" değil, **"istisna onay + sorumluluk imzalama masası."** Muhasebeci kalkmaz — rolü değişir: veri işçisi → **istisna hâkimi + sorumluluk imzalayıcısı.** (AI hukuki sorumluluk alamaz → insan imzası azaltılmış ama vazgeçilmez noktaya sıkışır.)

## 3. Mimari (3 düzlem)

- **Onay Yüzeyi** (Human Liability Surface): istisna kuyruğu + tek-tık imza + sorumluluk kaydı.
- **Kontrol Düzlemi** (değerin %90'ı): Ajan Filosu (sınıfla/mutabık-kıl/kapat/denetle) + Mevzuat-Kod + Kanıt Zinciri + Semantik Katman (her kaynağı ortak dile çevirir — BKM `sema/*.yaml`'ın kurumsal/self-learning hâli).
- **Veri Düzlemi** (commodity): DerinSIS · POS · Banka API · GİB e-Fatura/e-Defter · SGK · JOKER · WMS.

En kritik karar: kontrol düzlemi veri düzlemini **değiştirmez, üstüne oturur.** Gerçekçi (core ERP sökülmez) + wedge + moat (zamanla tüm zekâ senin katmanında birikir).

## 4. MVP — "Sürekli Mutabakat + Kanıt Zinciri" (6-9 ay)

Kapsam: banka ekstresi ↔ cari hareket ↔ e-fatura üç-yönlü otonom eşleştirme. Eşleşen sessiz akar; eşleşmeyen istisna kuyruğuna. Her karar kanıt kaydı (belgeler + kural versiyonu + ajan kimliği + güven skoru + insan imzası). İnsan sadece istisna görür + tek-tık onaylar.

Neden doğru: ölçülebilir ROI ("400 saat → 20 saat"), düşük hukuki risk (öneri, beyanname değil), veri biriktirir (sonraki katmanlar bedavaya gelir).

**MVP'de YAPMA:** otomatik beyanname gönderme, vergi-opt önerisi, bordro (yüksek hukuki risk — güven inşa etmeden dokunma).

Genişleme: mutabakat → sürekli kapanış → otonom sınıflandırma → sürekli denetim → beyanname hazırlama.

## 5. Gelir modeli (kullanıcı-başı SaaS DEĞİL)

1. Platform tabanı (aylık sabit): KOBİ ₺25-75K/ay, kurumsal ₺250K+/ay.
2. İşlem-bazlı: otonom işlenen ekonomik olay başına mikro-ücret (hacimle büyür — SAP'nin yakalayamadığı model).
3. **Sonuç-bazlı (asıl büyük para):** "denetim maliyetini %40 düşürdük → tasarrufun %20'si bizim." CFO'ya emek değil sonuç sat.
4. Mevzuat-Kod aboneliği: ayrı SKU; Logo/Mikro/Netsis'e API olarak da satılabilir.

#3+#4 kopyalanamaz gelir → net-negatif churn.

## 6. Teknik altyapı

- Ajan orkestrasyon: deterministik iş akışı (kod) + sınırlı LLM muhakeme (aday üretir, karar VERMEZ). Karar = deterministik mevzuat-kod + insan imzası. (BKM `agent-usage.md` leaf/orchestrator + model-katman disiplininin kurumsal karşılığı.)
- Mevzuat-Kod: versiyonlu, çalıştırılabilir, tarih-etkili, kaynak-referanslı (VUK madde no), test-edilebilir (rules-as-code — kamu projelerinin özel-sektör muhasebe versiyonu).
- Kanıt Zinciri: append-only, hash-zincirli, WORM depolama (blockchain gerekmez — daha ucuz). Regülatör-okunur export (e-Defter/XBRL).
- Semantik katman: kaynak şema → ortak ontoloji, sürekli-öğrenen (sema-ogren pattern), decay/TTL, confidence.
- Güven & determinizm: her eylem güven skoru taşır; eşik-altı → otomatik istisna kuyruğu (halüsinasyon-beyannameye-kaçtı felaketini mimariyle engeller).
- Sıfır-veri-taşıma: veri kaynağında kalır (KVKK + kurumsal güven).

## 7. Moat (para ile kapatılamaz 4 varlık)

1. Mevzuat-Kod kütüphanesi (yıllar sürer, her kural canlı işlemle doğrulanmalı).
2. Kanıt zinciri verisi (milyonlarca karar+gerekçe+imza; network effect).
3. Denetçi/GİB güveni (ilk kuran standardı belirler — kategori-kral).
4. Değiştirme maliyeti (tüm mali hafıza senin düzleminde → en yapışkan moat).

**Neden SAP/Oracle yapamaz:** kontrol düzlemi onların record-satış modelini commodity'leştirir → kendi kanibalizasyonları → innovator's dilemma. Senin kaybedecek core-business'in yok.

## 8. Patentlenebilir (savunma + pazarlık kozu, mutlak engel değil)

1. Otonom karar → hukuki sorumluluk zinciri protokolü (en güçlü; kimse çözmedi).
2. Güven-skoru eşikli otonom/istisna yönlendirme algoritması.
3. Tarih-etkili mevzuat-kod uygulama motoru (retroaktif değişiklik dâhil).
4. Çok-kaynaklı semantik mutabakat (öğrenen ontoloji).
5. Kanıt-zinciri → regülatör-format (e-Defter/XBRL) otomatik dönüşüm.

## 9. Neden bugüne kadar yapılmadı (5 engel, hepsi yeni kalktı)

1. LLM öncesi yapılandırılmamış-belgeden ekonomik-olay çıkarımı imkânsızdı (2023+ mümkün).
2. Yanlış soru soruldu ("AI muhasebeciyi değiştirir mi?" yerine "AI işi yapıp insanı imzaya sıkıştırırsa?").
3. Kanıt/denetlenebilirlik olmadan kara-kutu AI finansa sokulmaz — kanıt-öncelikli mimari yeni.
4. Mevzuat-as-code kültürü yeni (kamu son 5 yıl; özele taşınma yeni).
5. **Asıl sebep — iş modeli:** değeri olan oyuncular (SAP/Oracle/Logo/Mikro) yaparsa kendi record-satışını öldürür. Çıkar çatışması → kapı startup'a açık.

## 10. BKM senaryosu (gerçek zemin testi)

Bugün: 3 mağaza, POS+ERP+e-ticaret+banka+GİB = 4+ ada; kapanış elle (`bkm.Fin_AyKapanis`); mutabakat/KDV/tevkifat manuel; `muhasebe-denetci` skill reaktif.

AFCP ile: POS satışı → anında net ciro (KDV-hariç/iade-netli, BKM kurallarıyla) + e-fatura mutabakat + cari + kanıt zinciri. Ay-sonu maratonu yok, hep-kapalı. Tevkifat ajanı güven<%85 → Fikri'ye düşer. `muhasebe-denetci`+`silent-failure-hunter` sürekli koşar. **BKM `sema/*.yaml` = AFCP semantik katman prototipi** → BKM kategoriyi elle yaşıyor.

BKM = ideal design partner + ilk referans müşteri + en zorlu test zemini (yüksek hacim + çok-kanal + Türk mevzuat yoğun).

## 11. Öldürme senaryoları (kendi tezini vur)

1. **Güven inşa edilemez** — bir yanlış otonom işlem + GİB cezası → kategori yanar. Önlem: güven-eşiği + zorunlu imza + MVP'de beyanname-yok.
2. **Mevzuat-kod bakımı boğar** — sürekli değişir, çürür. Önlem: ayrı gelir hattı (kendini finanse etsin) + değişiklik-ajanı + hukukçu-in-loop. Zorluğu moat'a çevir.
3. **Entegrasyon cehennemi** — her ERP farklı. Önlem: self-learning semantik katman; ilk 10 müşteride el-emeği kabul, sonra otomatikleş.
4. **Monolit'e geri dönüş** — "İK/WMS de ekleyelim" → premis tuzağı. Önlem: 3 yıl finansal kontrol düzleminde derinleş, sonra yatay.
5. **Sorumluluk protokolü hukuken tutmaz** — imza gerçekten sorumluluk devretmiyorsa regüle edilemez. Önlem: baştan YMM odaları + baro + GİB ile tasarla (en zoru, teknik değil kurumsal).

## Tek cümle
Kategori "modülleri tek AI'da birleştirmek" değil — system-of-record'u commodity'ye indirip tüm zekâyı üstteki, her otonom kararı hukuken-savunulabilir kanıtla saran özerk finansal kontrol düzlemine taşımak. Değer **ayrıştırmada.** BKM = ilk laboratuvar.
