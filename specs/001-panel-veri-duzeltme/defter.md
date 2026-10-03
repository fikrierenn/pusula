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
