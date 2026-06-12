---
name: asistan-ui
description: BKM-Asistan'ın kullanıcı arayüzünü (Blazor PWA) PRATİK, UI-ODAKLI, kullanıcı-dostu tasarlar/geliştirir. "asistan arayüzü", "asistan ekranı", "asistan tasarla/yap", "asistan UI", "chat ekranı" denildiğinde veya BKM-Asistan'a yeni etkileşim/sayfa eklenirken devreye gir. Telegram gibi komut-yazma DEĞİL — buton-öncelikli, az-tıklama, dokunmatik-dostu. CFO tek kullanıcı, telefonda PWA.
---

# BKM-Asistan UI Skill

> Amaç: asistan arayüzünü her seferinde aynı PRATİK + KULLANICI-DOSTU kalıpla kur.
> Telegram POC'si komut-yazma (kaydet/Emre'ye at) yüzünden kullanışsızdı → **buton-öncelikli PWA**.

## 1. Tasarım İlkeleri (KEMİK)

1. **Az tıklama.** Not yaz → tek [Gönder] → taslak gelir → tek [Kaydet]. Maksimum 2 tık ile iş biter.
2. **Yazma minimum.** Aksiyonlar BUTON (kaydet/ata/kapat). Sadece not + isim yazılır. Komut yazdırma YASAK.
3. **Anlık geri bildirim.** Her aksiyonda görsel: spinner (inference), toast ("Görev #5 kaydedildi"), renk değişimi.
4. **Dokunmatik-dostu.** Butonlar ≥44px yükseklik, parmak aralığı. PWA telefonda kullanılır.
5. **Tek ekran akışı.** Sayfa değişimi yok — not, taslak, görev listesi aynı sayfada (scroll).
6. **BKM tema.** Kırmızı (#E30622) ana aksiyon, app.css pattern (.panel/.card). Dashboard ile bütünleşik.
7. **Affedici.** Yanlış olursa [Düzelt]/[İptal] her zaman görünür. Geri alınabilir.
8. **Beklemeyi gizle.** Model ilk yükleme ~20sn / inference ~10-30sn → spinner + "düşünüyorum…" (boş ekran değil).

## 2. Ekran Düzeni (/asistan)

```
┌─ Asistan ──────────────────────────────────┐
│ [ Not / fikir yaz...        ] [Gönder ▶]    │  ← üst: tek input + buton
├────────────────────────────────────────────┤
│ 💬 Konuşma akışı (kartlar):                 │
│   ┌ Senin notun ─────────┐                  │  (sağa yaslı, gri)
│   └──────────────────────┘                  │
│   ┌ 📋 Taslak kartı ──────────────┐         │  (sola, beyaz, formatlı)
│   │ 📋 Başlık                      │         │
│   │ 📝 Açıklama · ⚡ Öncelik       │         │
│   │ [✅ Kaydet] [👤 Ata] [✏️ Düzelt] [❌]│   │  ← BÜYÜK butonlar
│   └───────────────────────────────┘         │
├────────────────────────────────────────────┤
│ 📌 Açık Görevler (kart liste):              │
│   #5 Vitrin yenileme · Orta → Emre  [Kapat] │
│   #4 ...                            [Kapat]  │
└────────────────────────────────────────────┘
```

## 3. Etkileşim Akışı

| Adım | Kullanıcı | Sistem |
|---|---|---|
| 1 | Not yazar + [Gönder] (veya Enter) | Not kartı ekle (sağ) + spinner "düşünüyorum…" |
| 2 | bekler (10-30sn) | LlmService.TaslakUret → taslak kartı (sol) + butonlar |
| 3a | [✅ Kaydet] | GorevService.Kaydet → toast "Görev #N ✓" + liste yenile |
| 3b | [👤 Ata] | satır-içi isim input belir → [Kaydet] → atanan dolu |
| 3c | [✏️ Düzelt] | satır-içi düzeltme input → TaslakUret(not,düzeltme) → yeni taslak |
| 3d | [❌ İptal] | taslak kartını soldur |
| 4 | görev listesinde [Kapat] | GorevService.Kapat → kart gri/üstü çizili |

**Buton seçimi modal değil satır-içi** (Ata/Düzelt inputu kartın altında açılır — popup yok, akış kesilmez).

## 4. Teknik Kalıp (Blazor)

- **Sayfa:** `Components/Pages/Asistan.razor` (@page "/asistan", @rendermode InteractiveServer).
- **Servisler (DI):**
  - `LlmService` (Singleton) — LLamaSharp model lazy-load + SemaphoreSlim(1,1) seri inference. `TaslakUret(not, duzeltme?)`.
  - `GorevService` (Singleton) — SQLite asistan.db. Kaydet/Liste/Kapat/Ata.
- **State:** `List<ChatMesaj>` (rol: kullanıcı/taslak), `_pendingTaslak`, `_gorevler`, `_loading`, `_atamaModu`.
- **Stil:** app.css'e `.chat-*` ekle (mesaj balonu, taslak kartı, aksiyon butonları). Mevcut .panel/.card/.clk taklit.
- **Model yükleme:** ilk TaslakUret çağrısında yükle; UI "model hazırlanıyor (~20sn, ilk seferlik)" göster.

## 5. Yapma / Yap

**YAPMA:** komut yazdırma · modal popup (akış keser) · çok-adım sihirbaz · küçük buton · boş bekleme ekranı · sayfa geçişi.
**YAP:** tek input + büyük buton · satır-içi genişleme · anlık toast · spinner · renk-kodlu durum · Enter ile gönder · son N konuşmayı sakla (scroll).

## 5b. Esinlenilen Tasarım Pattern'leri (2026 chatbot UX araştırması)

> Web araştırma (aiuxdesign.guide, fuselabcreative, lazarev.agency, sendbird). BKM'ye uyarlanmış.

1. **Intent-first, "hybrid trap"tan kaç:** Chat = açık-uçlu/belirsiz (not→taslak). GUI/buton = yapılandırılmış/tekrarlı/riskli (görev kaydet/ata/kapat). Chat'i HER ŞEYE zorlama → bizde görev aksiyonu BUTON, not yorumlama CHAT. ✓
2. **Chat + yapılandırılmış UI karışık:** mesaj akışında düz metin DEĞİL — kart, buton, rozet. Taslak = kart (formatlı), aksiyon = buton. Kullanıcı yaz VEYA tıkla (hangisi hızlıysa).
3. **Quick-reply / öneri butonları:** boş ekranda "ne yazabilirim" örnekleri (welcome). İlk açılışta 2-3 örnek not chip'i ("vitrin yenile", "toplantı ayarla") → tık ile doldur, yazmayı azalt.
4. **Confidence / belirsizlik göstergesi:** model emin değilse "❓ Açık sorular" (zaten formatımızda). Eksik bilgi varsa NETLEŞTİRME sorusu sor — uydurma yapma. Taslakta "tahmin" alanları gri/italik.
5. **Mesaj bölme (mobil):** 80 kelime tek blok DEĞİL → kısa kartlar. Taslak alanları (başlık/açıklama/öncelik) ayrı satır, taranabilir. Mobilde çoğu etkileşim "başka iş yaparken".
6. **4 kalite ölçütü (her ekranda):** (a) **capability transparency** — asistan ne yapabilir görünür (üst ipucu/menü), (b) **recovery** — hata/yanlışta [Düzelt]/[İptal]/[Tekrar], (c) **confidence** — emin değilken belli et, (d) **accessibility** — kontrast, büyük dokunma alanı, klavye (Enter).
7. **Progressive disclosure:** taslak özet gelir; "detay/gerekçe" istenirse genişler. Bir kerede her şeyi gösterme.

## 6. Genişleme (sonraki)
- Mail özet kartı (Graph) · hatırlatma · BKM-BI sorgu ("dün ciro?") — hepsi AYNI chat akışında, farklı kart tipi.
- Push (Telegram) sadece bildirim için (PWA kapalıyken).

## İlişkili
- `docs/arastirma/2026-06-12-bkm-asistan-acik-kaynak.md` — vizyon + mimari
- `asistan/` — Telegram POC (mantık kaynağı: prompt, SQLite, parse)
- `dashboard/` — entegrasyon hedefi (Asistan.razor + LlmService + GorevService)
