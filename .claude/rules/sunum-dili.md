# Sunum Dili — Sade, Yalın, Tek Okumada Anlaşılır

> **Rule katmanı:** on-demand — patrona/yönetime giden sunum, rapor, brief metni yazılırken birincil.
> Kullanıcı direktifi 03.09.2026: _"ifadeler çok anlaşılır değil, kafa karıştırıyor; daha basit,
> yalın, sade olmalı — dil ağır ve karışık."_ `paths:` yok — compact sonrası survive.

## Ölçüt

Slaytı ilk kez gören biri **bir kez okuyup** anlamalı. İkinci okuma gerekiyorsa cümle uzundur.

- Cümle **en fazla 15 kelime**. İki fikir varsa iki cümle.
- Dipnot **en fazla 2 cümle**. Ayrıntı Excel'e gider, slayta değil.
- Kart metni: **1 mesaj + 1 kanıt**. Üçüncü cümle eklemek yerine sil.
- Parantez içi açıklama zinciri yasak: `(tam zaman eşdeğer = SGK prim günü ÷ 30)` gibi.

## Jargon → Gündelik Karşılık (ZORUNLU)

| Yazma ❌ | Yaz ✅ |
|---|---|
| FTE / tam zaman eşdeğer | **tam gün çalışan** (gerekirse: "yarım ay çalışan yarım sayılır") |
| kişi-ay / bordro satırı | **bordroda görünen kişi** |
| kümülatif pencere | **yılbaşından bu yana** |
| okul-hizalı pencere | **okul dönemine göre eşleşen günler** |
| as-of / kesim tarihi | **o gün çalışan** / **31 Ağustos itibarıyla** |
| maliyet / ciro oranı | **100 TL satışta personele giden para** |
| operasyonel kadrolu | **fiilen mağazada çalışan** |
| brüt işveren maliyeti | **şirkete toplam maliyeti** |
| segment / KADROLU–SEZONLUK | **kadrolu** / **sezonluk** (küçük harf, açıklamasız) |
| kıyas mümkün / kısmi | **karşılaştırılabilir** / **yarısı gerçek** |
| yıllıklandırma | **yıla çevrildiğinde** |
| varsayım | **kabul** (ör. "Şu kabul edildi: …") |
| pencere | **dönem** |
| grain / kapsam | **hangi mağazalar / hangi tarihler** |

## Sayı Anlatımı

- Yüzde puan yerine para dili: `%12,85 → %12,15` değil → **"100 TL satışta 12,85 TL'den 12,15 TL'ye indi"**.
- Büyük tutar: `990.400.000 ₺` değil → **"990 milyon TL"**.
- Oran + mutlak birlikte: "+%15,8 (97 → 112 kişi)".
- Ondalık en fazla bir hane. Kuruş, personel sayısında ondalık yasak.

## Slayt Metni Kalıbı

1. **Başlık:** ne anlatıyor (5-7 kelime, soru işareti yok).
2. **KPI:** rakam + tek satır ne olduğu.
3. **Kart:** "Şu oldu. Sebebi şu." (iki kısa cümle)
4. **Dipnot:** hangi mağazalar, hangi tarih, veri nereden. Nokta.

## Anti-pattern

- ❌ "Ölçü birimi FTE (tam zaman eşdeğer) = SGK prim günü ÷ 30 — ay içinde yarım çalışan tam sayılmaz"
  ✅ "Tam gün çalışan sayısı. Yarım ay çalışan yarım sayılır."
- ❌ "ESAS DÖNEM: Tem (sezon) · yıl geneli referansı 01-07 ay (Oca–Tem), her iki yıl"
  ✅ "Sezon: Temmuz–Ekim. Karşılaştırma şimdilik Temmuz."
- ❌ Tek dipnotta 6 madde `·` ile dizmek → en önemli 2'sini bırak.
- ❌ Aynı slaytta iki farklı ölçü adı (kişi-ay + FTE) → tek ad seç.
- ❌ Kanun maddesi metne gömmek ("4857 s.K. m.41") → "yasal sınır" yaz, madde dipnota.

## İlişkili
- `.claude/rules/response-style.md` — özlülük (sohbet tarafı).
- `.claude/skills/bkm-sunum/SKILL.md` — marka + yerleşim.
- `.claude/rules/turkish-ui.md` — Türkçe UTF-8 yazım.
