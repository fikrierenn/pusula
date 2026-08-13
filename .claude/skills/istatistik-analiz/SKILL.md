---
name: istatistik-analiz
description: Satış/ciro/işlem verisinde istatistiksel analiz — zaman-serisi trend, outlier/anomali tespiti (z-score, IQR, hareketli ortalama sapması), mevsimsellik, segment kıyasının anlamlılığı. "outlier var mı", "bu sapma anlamlı mı", "trend ne", "anomali tara", "istatistik analiz", "bu düşüş normal mi", "/istatistik-analiz" denildiğinde veya bir rakam farkının gürültü mü sinyal mi olduğu sorulduğunda devreye gir. Benford/mükerrer/GL-forensik BURADA DEĞİL → muhasebe-denetci; tahmin modeli yorumu → forecast-yorum.
---

# istatistik-analiz — Sinyal mi Gürültü mü?

> Amaç: "geçen haftaya göre %12 düştü" cümlesine istatistiksel bağlam vermek. Overclaim-yasak: anlamlılık gösterilemiyorsa "normal dalgalanma aralığında" de, hikâye uydurma.

## 1. Veri Hazırlık (BKM kuralları geçerli)

- Seri çekerken standart filtreler: IsValid, iade sign, DocType, KDV-hariç net (`sql-server-conventions.md`). Şüphen varsa önce `veri-dogrula`.
- Grain'i sabitle: gün mü hafta mı ay mı? Karışık grain'le trend yorumu YASAK.
- Takvim etkisini ayır: hafta içi/sonu, ay başı/sonu, bayram/sınav dönemi (BKM'de sınav takvimi ciroyu domine eder).

## 2. Trend

- Basit: 7-gün / 28-gün hareketli ortalama üst üste çiz — ham gün verisiyle yorum yapma (gün gürültüsü yüksek).
- Yön testi: son N nokta hareketli ortalamanın üstünde mi altında mı (art arda 5+ aynı yön = trend sinyali).
- YoY kıyas: aynı takvim kesiti (gün-sayısı eşit, MTD-vs-MTD). Sınav operasyon taşınması (Ağu 2024 FSM→İst.Yolu) gibi yapısal kırılmaları not düş — kırılma öncesi/sonrası tek seri gibi kıyaslanmaz.

## 3. Outlier / Anomali

| Yöntem | Ne zaman | Eşik |
|---|---|---|
| z-score | yeterli nokta (30+), ~normal dağılım | \|z\| > 3 güçlü, 2-3 şüpheli |
| IQR | çarpık dağılım (ciro genelde çarpık) | < Q1−1.5·IQR veya > Q3+1.5·IQR |
| Hareketli ort. sapması | zaman serisi günlük radar | > ±%X (seriye göre kalibre, sabit uydurma) |

- Ciro/tutar serileri çarpık → **IQR varsayılan**, z-score'u log-dönüşümle veya hiç.
- Outlier bulundu ≠ hata: önce iş açıklaması ara (kampanya günü, toplu kurumsal satış, iade dalgası). Açıklanamayan → `veri-dogrula` çek-listesiyle veri hatası mı bak, değilse raporla.
- Sıfır/boş gün ayrı sınıf: outlier değil, veri-akışı arızası olabilir (job gecikmesi — tarih MIN/MAX kontrolü).

## 4. Segment Kıyası Anlamlı mı?

- İki oran kıyası (örn. kartlı oranı mağaza A vs B): örneklem büyüklüğünü yaz. Küçük n'de fark yorumlama (haftada 40 fişlik segmentte ±%10 gürültüdür).
- Kaba anlamlılık: iki oranın farkı > 2·√(p(1−p)/n) değilse "belirsiz" de.
- Ortalama kıyasında average-of-averages tuzağı → ağırlıklı hesap (`veri-dogrula` §3).

## 5. Çıktı Formatı

Her bulgu: **gözlem + büyüklük + bağlam + hüküm**.
Örn: "İst.Yolu Salı cirosu 412K; 8-haftalık Salı ortalaması 388K ± IQR bandı [301K, 465K] → bant içi, **normal dalgalanma**." Hüküm üçlü: **sinyal / gürültü / veri-şüphesi**.

## Anti-pattern

- ❌ İki noktadan trend ("dün düştü → düşüş trendi").
- ❌ Eşiği sonuca göre seçme (z>2 tut ki anomali çıksın).
- ❌ Outlier'ı sorgusuz silip ortalama almak — önce açıkla, sonra karar.
- ❌ Yapısal kırılma üstünden kesintisiz YoY (sınav taşınması vakası).
- ❌ Benford/mükerrer burada koşturmak → `muhasebe-denetci` işi.

## İlişkili
- `.claude/skills/veri-dogrula/SKILL.md` — veri doğruluğu (bu skill'in ön-şartı).
- `.claude/skills/muhasebe-denetci/SKILL.md` — GL-forensik (Benford, round-number, mükerrer).
- `.claude/skills/forecast-yorum/SKILL.md` — tahmin modeli yorumu.
- `.claude/rules/sql-server-conventions.md` — seri çekim filtreleri.
