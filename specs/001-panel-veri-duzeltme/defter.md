# Defter — 001-panel-veri-duzeltme

Görevler: `specs/001-panel-veri-duzeltme/tasks.md` · biçim ve kurallar: `.claude/hooks/ledger.py`

- 03.10 23:22 · Commit: d5cf345 chore(bkm): Orkestra bağlantısı (proje-kur)
- 03.10 23:23 · Commit: c223b41 docs(bkm): Orkestra /tanit + spec/plan/görevler 001 (panel veri düzeltmeleri)
- 03.10 23:23 · Ön tarama: dosya/arayüz çiftleri ve AC kapsamı gorevler-rapor.md + gorev-taramasi.md'de; 49/49 AC bağlı, çelişki yok. C1–C5 GMY onaylı (03.10). Commit başlığı <tip>(bkm): … (T-0NN).
- 03.10 23:33 · Commit: a2bc444 chore(bkm): T-001 taban ölçümü (T-001)
- 03.10 23:34 · T-001: kapılar STATIC ✓ (sql_denetle 0 bulgu; test seviyesi yok — salt-okuma ölçüm)
- 03.10 23:34 · Karar: KR-2 ölçümü %1,35 (>%0,5) çıktı ama GMY'nin onaylı KR-2 kararı korunur (ciroda sipariş kuralı, satır iptal kuralı ciroya 003'te) — karar ölçümden önce büyüklük bilinmeden verildi, GMY'ye bitiş kapısında rakamla bildirilecek — yanlışsa e-tic ana ciro 003'e kadar ~%1,35 (Eylül 1,65M TL) şişik kalır
- 03.10 23:34 · Karar: T-001 J bloğunda 'altı yer' yerine beş okuma yeri bulundu; görev metni sayım hatası, beş yer kabul — tasks.md liste beşini sayıyor zaten — yanlışsa altıncı yer H8 kapsamı dışında kalır, T-051..053 sırasında grep ile yeniden taranır
- 03.10 23:38 · T-001: inceleme r0 — gorev-inceleyici Düzeltme gerekli (1 Yüksek: KumeA IsValid asimetrisi, doğrulandı HediyeCekiQueries GeriDonusumHaric IsValid=1 join'e ekleniyor), sql-inceleyici Onaylandı (3 Orta yorum düzeltmesi: D kayma, C sebep, G zaman); düzeltme turu 1 gönderildi
- 03.10 23:40 · Commit: a7449e0 fix(bkm): T-001 başlık düzeltmeleri (T-001)
- 03.10 23:40 · T-001: düzeltme turu 1/5 (7 giderildi, 0 açık; a2bc444..a7449e0), STATIC ✓
- 03.10 23:41 · T-001: orta (ertelendi): C başlığındaki '36 belgenin sebebi kod 12 başka ürün satırında' cümlesi sql-inceleyici r0'da ölçüldü ama ayrıştırma SQL'i arşivde yok — KR-4 tüketen görevin (T-009) özetine 'kollara ayrıştırma bloğu ekle' notu taşınacak
- 03.10 23:41 · T-001: orta (ertelendi): G 'tamamen zaman kayması' hükmü büyüklükçe ölçülmedi (mekanizma + zaman damgası var) — T-012 (H08 kanonik) özetine taşınacak
- 03.10 23:41 · T-001: dusuk (ertelendi): H bloğunda negatif DonemId (-8..-7) anlamı açıklanmadı — T-013 özetine not
- 03.10 23:41 · T-001: tamam (c223b41..a7449e0, inceleme temiz, 3 ertelendi)
- 03.10 23:42 · Commit: 53dd9b2 chore(bkm): T-002 e-tic kayma ölçümü koşu 1 (T-002)
- 03.10 23:43 · T-002: kapılar STATIC ✓ (0 bulgu)
- 03.10 23:43 · T-003: KARAR bekliyor değil, TAKVİM bekliyor — en erken 10.10.2026 23:42 (Koşu 1 + 7 gün)
- 03.10 23:44 · T-002: dusuk (ertelendi): başlıkta 'Aynı kaynak — neden'/'Başka ne olabilir' satırları yok; DECLARE'li dosya sq.sh'te literal koşuldu; A/B ayrı tarih değişkenleri — T-003 özetine taşındı
- 03.10 23:44 · T-002: tamam (ea58d7c..53dd9b2, inceleme temiz, 1 ertelendi)
- 03.10 23:50 · Commit: 86993cc chore(bkm): T-004 hedef tabanı ölçümü (T-004)
- 03.10 23:51 · T-004: kapılar STATIC ✓ (0 bulgu)
- 03.10 23:53 · T-004: inceleme r0 — gorev-inceleyici Düzeltme gerekli (2 Yüksek: öneri belgesindeki istatistikler arşivsiz [sql-inceleyici de aynı, doğrulandı: dosyada blok B yok]; 'itiraz yoksa uygulanır' varsayılanı yok), sql-inceleyici Geçer (Orta: düşük güçlü test, eşli Kitap/Kırtasiye kıyası önerisi)
- 03.10 23:53 · Karar: T-004 düzeltmesine eşli Kitap(%0)/Kırtasiye(%20) mağaza×ay kıyası (Tem-2025..Eyl-2026) eklenir; veri tek bandı (1,00 ya da 1,20) gösterirse o 'itiraz yoksa 09.10.2026'da uygulanır' varsayılanı olur, göstermezse belge açıkça 'varsayılan yok, not durur' der — AC-13.4 notu her iki durumda teyide kadar kalır — yanlışsa hedef kıyası yanlış tabanla yapılır (GMY itiraz penceresiyle sınırlı)
- 04.10 00:01 · Commit: 16d0181 fix(bkm): T-004 arşiv + eşli KDV testi (T-004)
- 04.10 00:02 · T-004: düzeltme turu 1/5 (7 giderildi; 86993cc..16d0181), STATIC ✓
- 04.10 00:02 · Karar: T-004 bootstrap aralığı yerine SQL'de medyan/çeyrek + binom işaret testi kabul — sql-yazar sorgular/ altına .py yazamıyor (yazma politikası) ve eşli test 37/45 tek yönlü p=7,7e-6 ile kararı zaten veriyor — yanlışsa aralık tahmini eksik kalır, karar değişmez
- 04.10 00:04 · T-004: yeniden inceleme r1 — Y-1 ADDRESSED, Y-2 KISMEN (mağaza medyanları + p arşivsiz), yeni Orta 4 (bağımsızlık iddiası, alternatif açıklama, E kısmi ay, Kalem kopyası); düzeltme turu 2 gönderildi
- 04.10 00:07 · Commit: 186daa0 fix(bkm): T-004 belge kanıt bağları (T-004)
- 04.10 00:08 · T-004: düzeltme turu 2/5 (6 giderildi; 16d0181..186daa0), STATIC ✓
- 04.10 00:09 · T-004: dusuk (ertelendi): MAXRECURSION 100 sınırı (n=45), Kalem notu INNER/LEFT JOIN farkını anmıyor, SQL çıktısında mağaza adı yok
- 04.10 00:09 · T-004: tamam (d83f324..186daa0, inceleme temiz, 2 düzeltme turu, 1 ertelendi). Öneri: kategori bazlı, Sınav dahil, KDV hariç; itiraz yoksa 09.10.2026
