---
name: yonetici-rapor
description: "Yönetici-grade kurumsal belge üretir — 6 kanıtlı format: PwC veri-analiz raporu · Amazon Working-Backwards (PR-FAQ teklif) · Deloitte toplantı-notu+aksiyon · Bain sunum-taslağı · Goldman e-posta taslağı · McKinsey haftalık durum-raporu. Ortak omurga: veri-temelli, ÖZET-ÖNCE, OVERCLAIM YASAK (sinyal vs gürültü ayır, her iddia kanıtlı, belirsizliği açık yaz). \"rapor yaz\", \"analiz raporu\", \"yönetici raporu\", \"bu veriyi rapora çevir\", \"working backwards\", \"PR-FAQ\", \"teklif belgesi\", \"toplantı notu/tutanak\", \"aksiyon maddeleri çıkar\", \"sunum hazırla\", \"e-posta taslağı yaz\", \"haftalık durum raporu\", \"liderliğe sun\", \"/yonetici-rapor\" denildiğinde veya bir analiz/teklif/toplantı/sunum/e-posta yönetici belgesine dönüştürülecekse devreye gir."
allowed-tools: Read, Grep, Glob, Bash, WebSearch, mcp__sqlserver__sql_query
user-invocable: true
model: inherit
---

# yonetici-rapor — Yönetici Belgesi Üretici (PwC + Amazon)

Dağınık sayıları/fikri, üst-yöneticinin 30 saniyede okuyup aksiyona geçeceği **parlak + dürüst** belgeye çevirir. İki format, tek disiplin.

## Mod seçimi (niyet)
| Girdi | Mod | Format |
|---|---|---|
| Mevcut veri/sayı → "ne oldu, anomali var mı, ne yapmalı" | **ANALİZ** | PwC veri-analiz raporu (§F1) |
| Yeni fikir/proje/teklif → "bunu yapalım mı, onay ver" | **TEKLİF** | Amazon Working-Backwards / PR-FAQ (§F2) |
| Toplantı ham-not/transkript → karar+aksiyon | **TOPLANTI** | Deloitte toplantı-notu (§F3) |
| Fikir/veri → liderlik onayı için sunum | **SUNUM** | Bain sunum-taslağı (§F4) |
| Bir durumu birine iletmek | **E-POSTA** | Goldman e-posta taslağı (§F5) |
| Haftalık ilerleme → yöneticiye özet | **HAFTALIK** | McKinsey durum-raporu (§F6) |

Şüphede kullanıcıya sor. Birden çok mümkünse birincil + kısa ek.

## OMURGA — "PwC mantığı" (her iki formatta ZORUNLU)
1. **Özet önce.** Belge yönetici-özetiyle açılır (3 cümle, 30 sn). Gerisi destek.
2. **OVERCLAIM YASAK.** Veri neyse o. "Milyarlık hata bulduk" deme — ölç, ayır, doğrula. (Bu oturum dersi: naif "kaç farklı hesap" metriği gayrimenkul-varlık + gider-merkezi yüzünden şişti; gerçek sinyal tek Telekom→Danışmanlık'tı.)
3. **Sinyal vs gürültü.** Anomali listesinde yanlış-pozitifi (yapısal/meşru) ayrı göster; gerçek şüpheyi izole et. "Göster, yargılama" — insan-incelemesine çıkar.
4. **Her iddia kanıtlı.** Rakam → kaynağı (tablo/sorgu). KPI → nasıl ölçülür. Kanıtsız sayı yazma.
5. **Belirsizliği açık yaz.** Eksik veriyi (trend yok, örneklem küçük, %100 emin değil) SAKLAMA — dürüstlük notu düş. (B/D fikirleri veriyle çürüdü — çürüğü de raporla.)
6. **Sade dil.** Jargon/moda-kelime yok. Kök-neden iş-diliyle ("telekom danışmanlık kesmez → mis-kod").

## Format 1 — PwC VERİ-ANALİZ RAPORU
Sırayla (zayıf bölümü atlama, "veri yok" de):
1. **Yönetici Özeti** (3 cümle, 30 sn) — en üstte.
2. **Veri Özeti** — kaynak, dönem, grain, örneklem.
3. **Temel Metrikler** — toplam/ortalama/%, büyüme; her önemli sayıya bağlam.
4. **Trend** — yükselen/düşen/sabit; zaman-serisi yoksa AÇIKÇA söyle.
5. **Karşılaştırma** — geçen ay/çeyrek/yıl, hedef; yoksa söyle.
6. **Sıralama** — en iyi/en kötü performans (metriğe göre).
7. **Anomali** — olağandışı + olası açıklama; **yanlış-pozitif vs gerçek şüphe ayrı.**
8. **Kök Neden** — sayılar NEDEN böyle, sade dil.
9. **Görselleştirme önerisi** — hangi grafik (bar/çizgi/ısı/sankey), ne gösterir.
10. **Öneriler** — 3-5 somut, veriye dayalı aksiyon.

## Format 2 — AMAZON WORKING-BACKWARDS (PR-FAQ)
1. **Basın Bülteni** — proje BAŞARMIŞ varsayımıyla duyuru; gelecek nasıl görünüyor (müşteri gözünden).
2. **Müşteri Problemi** — kim faydalanıyor, hangi acıyı çözer (net).
3. **Mevcut Durum vs Gelecek** — bugün nasıl / sonra nasıl.
4. **Çözüm Genel Bakış** — sade, jargonsuz.
5. **Temel KPI'lar** — başarı hedef-sayılarla; nasıl ölçülür.
6. **Zaman Çizelgesi** — faz faz rollout, kilometre taşları.
7. **Kaynak İhtiyacı** — bütçe/insan/araç.
8. **Risk + azaltma** — ne ters gider, her risk için plan.
9. **SSS** — liderliğin soracağı zor soruları öngör + yanıtla.
10. **Ekler** — her iddiayı destekleyen veri/hesap.

> BKM'de "müşteri" = çoğu zaman **Fikri/GM veya muhasebe ekibi** (iç kullanıcı). PR-FAQ'ı ona göre yaz.

## Format 3 — DELOITTE TOPLANTI-NOTU (§F3)
Ham not/transkript → yapılandırılmış tutanak. Kimse "ne demiştik?" diye sormasın.
1. **Toplantı özeti** — tek paragraf (konular + sonuç).
2. **Kararlar** — her karar + **onaylayan kişi.**
3. **Aksiyon maddeleri** — görev · **sorumlu** · **son teslim tarihi** (tablo).
4. **Açık konular** — kim cevaplayacak, ne zamana kadar (çözülmemiş).
5. **Riskler** · **Geleceğe bırakılanlar** (ertelenen başlıklar).
6. **Sonraki gündem** · **Paydaş güncellemeleri** (katılmayanlara).
7. **Zaman-çizelgesi değişiklikleri** (kayan tarihler).
8. **Takip e-posta taslağı** — notlar ekli, gönderilmeye hazır.

## Format 4 — BAIN SUNUM-TASLAĞI (§F4)
Fikir/veri → liderlik onay sunumu. Slayt başlıkları = **çıkarım cümlesi** (başlık değil).
1. **Anlatı akışı** — başlangıç · orta · öneri (mantıksal).
2. **Yönetici-özeti slaytı** — patron tek slayta baksa tümünü yakalar.
3. **Problem** — aciliyet yaratan dil, panik değil.
4. **Veri-görselleştirme** — ham rakam → hikâye anlatan grafik.
5. **Bulgu slaytları** — 3-5, her biri **1 çıkarım + kanıt.**
6. **Öneri slaytı** — sahip · zaman · beklenen etki · sonraki adım.
7. **Yedek slayt** — "bu rakamı nereden aldın?" için.
8. **Konuşmacı notları** (söylenecek, slaytta yazmayan) + **tek-cümle özet** (Slack/e-posta).

## Format 5 — GOLDMAN E-POSTA TASLAĞI (§F5)
Konu satırı + gövde + **belirtilen ton** (resmi/dostça/acil/diplomatik). Tipler:
- **Yukarı** (patrona net güncelleme) · **Aşağı** (ekibe belirsizsiz görev) · **Fonksiyon-arası** (öncelik talebi).
- **Kötü haber** — çözümle çerçevele (şikâyetçi değil çözücü görün).
- **Takip-hatırlatma** (nazik+net) · **Teşekkür** (samimi, yalakalık yok) · **Nazik red** (ilişki korunur) · **Yükseltme** (kimseyi zora sokmadan).
> İş gerekçesiyle yaz; kişisel şikâyet değil. Konu satırı meşguldeki insanı açtırmalı.

## Format 6 — McKINSEY HAFTALIK DURUM (§F6)
Patronun 1 saatini harcadığını düşündüren, düzenlemesiz üste-iletilebilir rapor.
1. **Proje özeti** — tek paragraf.
2. **Bu hafta tamamlananlar** — ölçütlü ("X bitti" değil, "X %99 doğrulukla").
3. **Hedefe karşı ilerleme** — % + **yeşil/sarı/kırmızı.**
4. **Engeller+riskler** — diplomatik dil (şikâyet değil işaret).
5. **Gelecek hafta öncelikleri** — 5-7, proaktif.
6. **Karar-bekleyenler** — liderlik evet/hayır diyebilsin (net).
7. **Ölçüt panosu** · **Paydaş güncellemeleri** · **Kaynak talepleri** (iş-gerekçesi).
8. **Yönetici özeti** — 2 cümle, düzenlemesiz üste iletilir.

## BKM temeli (veri-grounding)
- Rakam gerekiyorsa: `sema/*.yaml` (köprü/kod/metrik) → doğru join, sonra `mcp__sqlserver__sql_query` (tek-SELECT, CTE yok — sql-server-conventions). Uydurma sayı YASAK.
- Sektör kıyası gerekiyorsa: `WebSearch` + kaynak-linki (ezber yok).
- Mevcut analiz varsa onu formatla; yoksa veriyi çek + analiz et, sonra formatla.

## Çıktı
- Varsayılan: markdown (bu formatta, terminalde).
- İstenirse görsel **Artifact/pano** (özet-kart + tablo + grafik) — `artifact-design` skill'i yükle, sonra Artifact.
- Uzun tablo → `overflow-x` scroll; sayı Türkçe format (1.000.000 ₺).

## Anti-pattern
- ❌ Overclaim / dramatize ("dev fraud", "milyarlık kaçak") — ölçüp ayırmadan.
- ❌ Kanıtsız KPI / uydurma yüzde.
- ❌ Yanlış-pozitifi gerçek bulgu gibi sunmak (gürültüyü sinyal sanmak).
- ❌ Jargon-yığını, moda-kelime, 5-paragraf giriş (özet-önce ihlali).
- ❌ Eksik veriyi saklamak ("trend" bölümünü uydurmak).

## İlişkili
- `.claude/skills/gm-rapor/` — operasyonel rapor KATALOĞU (sabit sorgular). Bu skill = yönetici-belge DİSİPLİNİ (format+ton). Tamamlayıcı: gm-rapor sayıyı üretir, yonetici-rapor onu belgeye çevirir.
- `.claude/rules/sql-server-conventions.md` · `.claude/rules/response-style.md` · `sema/README.md`.
- `.claude/skills/muhasebe-denetci/` · `afcp-danisman/` — bulgu kaynağı olabilir.
