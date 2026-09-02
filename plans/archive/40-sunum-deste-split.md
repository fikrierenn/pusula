# Plan 40 — Sunum destesinin bölünmesi (K-23)

**Tier:** 3 (5+ yeni dosya, patrona giden çıktıyı üreten script)
**Tarih:** 03.09.2026 · **İlgili TODO:** K-23 · **Öncesi:** plan 39 (veri+Excel split, tamamlandı)

## Problem

`scripts/sunum_kadro_deck.py` 1.333 satır (`file-size-discipline.md` kırmızı çizgi 500).
Modül düzeyinde akış: slaytlar sırayla, modül gövdesinde oluşuyor; ~40 türetilmiş global
(`mag`, `k5`, `d_adet`, `bolum`, `DIP_POS`…) tüm bloklar arasında paylaşılıyor. Bir slaytı
değiştirmek için 1.333 satırın tamamını bağlama almak gerekiyor.

## Scope

`sunum_kadro_deck.py` → yardımcı katman + bağlam nesnesi + tema bazlı slayt modülleri + CLI.
Çıktı DEĞİŞMEZ: 19 slayt, aynı geometri, aynı metin, aynı grafik serileri.

## Hedef yapı

| Dosya | İçerik | ~satır |
|---|---|---|
| `sunum_ortak.py` | palet + biçim yardımcıları (`bin`/`yzd`/`tr_title`) + şablon durumu (`ac()`, `L`, `copy_bg`, `add`) + çizim yardımcıları (`setph`/`tb`/`rrect`/`circ`/`card`/`sig`/`dipnot`/`kpi`/`cift_bar`) | 260 |
| `sunum_baglam.py` | `hesapla(v)` → `SimpleNamespace`: türetilmiş oranlar + kapsam/dönem dipnot metinleri (DIP_*) | 90 |
| `sunum_slayt_kadro.py` | kapak · norma göre durum · kadro akışı · beş mağaza tablosu | 170 |
| `sunum_slayt_hacim.py` | dönem iş hacmi · kişi başı · dört yıllık · bölüm · mağaza performans · kategori · takvim kayması | 350 |
| `sunum_slayt_norm.py` | norm kadro detayı · norm açığı (bölüm) | 220 |
| `sunum_slayt_maliyet.py` | personel maliyeti/ciro · fazla mesai sınırı · sezonluk alım zamanlaması | 230 |
| `sunum_slayt_kapanis.py` | yöntem/itirazlar · iyileştirme alanı · kapanış | 120 |
| `sunum_kadro_deck.py` | CLI: JSON oku → `ac()` → `hesapla()` → slayt fonksiyonlarını SIRAYLA çağır → kaydet | 60 |

**Sözleşme:** her slayt fonksiyonu `slayt_<ad>(C)` imzasını taşır; `C` bağlam nesnesi
(salt-okuma kabul edilir), çizim `sunum_ortak` yardımcılarıyla yapılır. Slayt SIRASI yalnız
CLI'da durur — sıra değişikliği tek dosyada görünür.

## Yöntem (mekanik, yeniden yazım YOK)

Blok taşıma + **tokenize tabanlı** isim yeniden yazımı: bağlam adları yalnız NAME token'ında
`C.<ad>` olur; STRING token'ına DOKUNULMAZ. (Naif regex tehlikeli: Türkçe metinde "mal",
"kat", "gun" gibi kelimeler geçiyor — `"fiili mal miktarını"` bozulurdu.) Blok içinde
atanan adlar (`ast` Store taraması) yerel kalır, `C.` almaz.

## Alternatifler (reddedilen)

1. **Sınıf (`Deste`) + metotlar.** Red: `add/tb/kpi` çağrılarının tamamı `self.`/`D.` ile
   yeniden yazılır → mekanik olmayan büyük diff, regresyon riski yüksek.
2. **Bağlam yerine `**kwargs` / global sözlük geçirmek.** Red: `C.d_adet` okunurluğu kaybolur,
   yazım hatası çalışma anına kalır.
3. **Slaytları tek modülde bırakıp yalnız yardımcıları çıkarmak.** Red: kalan dosya ~1.030
   satır — kırmızı çizginin iki katı, sorun çözülmemiş olur.

## Riskler

| Risk | Önlem |
|---|---|
| Metin/rakam sessizce değişir | **Regresyon kanıtı:** 19 slayt × 332 şekil (tür + geometri + metin + grafik serileri) baseline'a alındı; split sonrası birebir karşılaştırılır |
| Bağlam adı atlanır → NameError | Modüller `ast.parse` + gerçek koşum ile sınanır; NameError zaten çalışma anında patlar (sessiz değil) |
| Şablon durumu (pr/BG) modül globali | `ac()` tek giriş noktası; CLI dışında çağıran yok |
| Yerleşim bozulur | `sunum_yerlesim_denetle.py` + PowerPoint COM PNG export ile gözle kontrol |

## Done kriterleri

- [x] Her dosya < 500 satır (en büyüğü sunum_slayt_hacim.py 361).
- [x] Baseline ile **0 fark** (19 slayt, 332 şekil: tür/geometri/metin/grafik serileri birebir).
- [x] `sunum_yerlesim_denetle.py` ihlal yok ✓ · `tutarlilik_kontrol.py` 94/94 ✓
- [x] Veri tarafı (plan 39 modülleri) dokunulmadı ✓

## Rollback

Tek commit → `git revert`.

## Sonuç (03.09.2026 — tamamlandı)

8 modül, 1.484 satır (önce tek dosya 1.333): sunum_slayt_hacim 361 · sunum_ortak 239 ·
sunum_slayt_norm 228 · sunum_slayt_maliyet 218 · sunum_slayt_kadro 168 · sunum_slayt_kapanis 129 ·
sunum_baglam 75 · sunum_kadro_deck (CLI) 66.

**Taşıma sırasında çıkan iki yapısal tuzak:**
1. Şablon durumu (`pr`, `TITLE_BG`, `CONTENT_BG`) modül gövdesinde kuruluyordu → import anında
   şablon açılıyor ve ikinci kez açılınca `IndexError` veriyordu. `ac(tpl)` tek giriş noktası
   yapıldı; import artık yan etkisiz.
2. Bloklar arası paylaşılan yerel adlar (`nrm`, `mal`, `fm`, `al`, `ay2`, `ky`) bir blokta atanıp
   sonrakinde okunuyordu → bölünmede NameError. Hepsi bağlama (`hesapla`) taşındı; slayt
   fonksiyonları birbirinin yerel değişkenine artık bağımlı değil.
