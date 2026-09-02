# Plan 39 — Kadro savunma script'lerinin bölünmesi (K-20)

**Tier:** 3 (3+ yeni dosya, mevcut kullanıcı-görünür çıktı üreten pipeline)
**Tarih:** 03.09.2026 · **Sahip:** Fikri Eren · **İlgili TODO:** K-20

## Problem

| Dosya | Satır | Sınır |
|---|---|---|
| `scripts/verimlilik_excel.py` | 2.283 | 500 (kırmızı çizgi) |
| `scripts/sunum_kadro_deck.py` | 1.333 | 500 |

`file-size-discipline.md`: 300 hedef, **500 kırmızı çizgi — bir sonraki PR'da split zorunlu**.
İki dosya da bu oturumda büyüdü (maliyet + fazla mesai blokları). Tek `cek()` fonksiyonu
930 satır; bir bloğu değiştirmek tüm dosyayı context'e almayı gerektiriyor.

## Scope

**Kapsamda:** `verimlilik_excel.py` → veri çekirdeği + Excel emitter modüllerine bölünmesi.
CLI adı ve kullanımı DEĞİŞMEZ (`python scripts/verimlilik_excel.py [--cek] [--kisi] veri.json cikti.xlsx`).

**Kapsam dışı (ayrı adım):** `sunum_kadro_deck.py` — modül düzeyi akış (slaytlar sırayla
oluşuyor, ~30 global türetilmiş değer). Bölünmesi bir bağlam nesnesi (`C`) sözleşmesi
gerektirir; veri tarafı bölünüp doğrulandıktan sonra ele alınacak.

## Hedef yapı

| Dosya | İçerik | ~satır |
|---|---|---|
| `verimlilik_ortak.py` | sabitler (yıl/mekân/şube/okul takvimi/Sınav filtresi/FM yasal sabitleri), `maskele`, `_env`, bağlantı fabrikası + `kapat_baglantilar`, `_hizali_kosul`, `NOTLAR` | 150 |
| `verimlilik_cek_hacim.py` | DerinSIS blokları: hizalı pencere, Oca-Ağu kanal, 4 yıllık trend, kategori, aylık, kayma düzeltmesi, Ağustos yarım-ay, aylık KDV-hariç ciro | 350 |
| `verimlilik_cek_kadro.py` | Zirve: şube kadro tablosu, 5 mağaza kapsam, mağaza hacim+kadro, yıllık trend, bölüm, mağaza×bölüm, arka ofis, personel (KVKK), sezonluk alım, tutunma, mutabakat | 430 |
| `verimlilik_cek_norm.py` | norm dosyası okuma + beyan doğrulaması + şube/bölüm karşılaştırması + engelli/etkinlik ayrımı | 250 |
| `verimlilik_cek_maliyet.py` | bordro maliyet + fazla mesai + yasal sınır modeli | 160 |
| `verimlilik_cek.py` | `cek()` orkestrasyonu + `veri["toplam"]` + meta | 110 |
| `verimlilik_xlsx_ortak.py` | Excel format sabitleri + `_basliklar` / `_yaz` / `_notlar` | 90 |
| `verimlilik_xlsx_ozet.py` | Sunum + Ozet sayfaları | 290 |
| `verimlilik_xlsx_hacim.py` | Magaza · Kategori · Aylik · Yillar · Oca-Agu | 380 |
| `verimlilik_xlsx_kadro.py` | Kadro · Bolum · Personel · Norm · Maliyet · Yontem | 450 |
| `verimlilik_excel.py` | CLI: argüman ayrıştırma, `cek()` çağrısı + JSON yazımı, sayfa sırası, kaydetme | 80 |

## Alternatifler (reddedilen)

1. **Hiç bölmemek, kuralı esnetmek.** Red: kural 500'ü kırmızı çizgi ilan ediyor ve dosya
   büyümeye devam ediyor (bu oturumda +400 satır). Borç kartopu.
2. **Tek `verimlilik_cek.py` + tek `verimlilik_xlsx.py` (2 dosya).** Red: 1.100 + 1.150 satır —
   kırmızı çizginin iki katı; sorunu yarı yarıya taşımak olur.
3. **Paket dizini (`scripts/verimlilik/`).** Red: proje düz `scripts/` düzeni kullanıyor
   (import yolu + mevcut .bat/otomasyon çağrıları değişir). Getirisi yok.

## Riskler

| Risk | Önlem |
|---|---|
| Taşıma sırasında blok atlanması / sıra bozulması | Taşıma script'le yapılır; her modül `python -c ast.parse` ile sınanır |
| Çıktı sessizce değişir | **Regresyon kanıtı:** split öncesi JSON + Excel hücre değerleri baseline alınır; split sonrası birebir karşılaştırılır |
| Döngüsel import | Bağımlılık tek yönlü: `ortak ← cek_* ← cek ← excel(CLI)`, `xlsx_ortak ← xlsx_* ← excel(CLI)` |
| `--cek` DB turu uzun, hızlı geri bildirim yok | Önce JSON'suz mod (mevcut JSON'dan Excel) doğrulanır, sonra tam `--cek` turu |

## Done kriterleri

- [x] Her yeni dosya < 500 satır (en büyüğü verimlilik_xlsx_kadro.py 459).
- [x] `python scripts/verimlilik_excel.py <json> <xlsx>` — 12 sayfa, hücre değerleri baseline ile BİREBİR (0 fark).
- [x] `--cek --kisi` turu — JSON baseline ile aynı (1e-6). Kalan sapma yalnız SQL SUM sırası kaynaklı ~1e-8 float jitter (iki ardışık canlı koşumda da var, koda bağlı değil).
- [x] `tutarlilik_kontrol.py` 94/94 ✓ · `sunum_yerlesim_denetle.py` ihlal yok ✓
- [x] `sunum_kadro_deck.py` değişmeden çalıştı (19 slayt) ✓

## Rollback

Tek commit → `git revert`. Ara durum bırakılmaz (split ve doğrulama aynı commit'te).

## Adımlar

1. Baseline: mevcut JSON + Excel hücre değerlerini scratchpad'e dök.
2. `verimlilik_ortak.py` + `verimlilik_xlsx_ortak.py` çıkar.
3. `cek()` gövdesini dört domain fonksiyonuna böl (`_hacim` / `_kadro` / `_norm` / `_maliyet`),
   her biri kendi modülünde; `cek()` yalnız orkestrasyon.
4. Excel sayfalarını üç modüle taşı.
5. `verimlilik_excel.py`'yi CLI'ya indir.
6. Doğrula (JSON'suz → tam `--cek` → iki denetçi → deste).
7. TODO K-20 kapat, journal'a yaz.

## Sonuç (03.09.2026 — tamamlandı)

11 modül, toplam 2.405 satır (önce tek dosya 2.283 — artış modül başlıkları/import'lar).
Satır dağılımı: xlsx_kadro 459 · xlsx_hacim 369 · cek_hacim 315 · cek_kadro 292 · xlsx_ozet 286 ·
cek_norm 196 · ortak 147 · cek_maliyet 139 · excel(CLI) 89 · cek 57 · xlsx_ortak 56.

**Yan bulgu (split doğrulamasının yakaladığı gerçek hata):** `norm.bolum` listesi eşit açıkta
`set` sıralamasına düşüyordu → aynı veriden farklı satır sırası ve "en büyük açıklar" kartında
kayma. İkincil sıralama anahtarı (bölüm adı) eklendi; iki ardışık koşum artık aynı sırayı veriyor.

**Kapsam dışı kalan:** `sunum_kadro_deck.py` (1.333 satır) → TODO **K-23**.
