# Dashboard İçerik Önerisi Skill'i

> Amaç: GM Dashboard'a (Blazor, CFO mobil PWA) **ne eklenmeli** sorusunu sistematik yanıtla. Mevcut veriyi tarayıp, henüz dashboarda yansımamış değer fırsatlarını ranked öneri listesi olarak çıkar. Bu = "fırsat avı"; uygulama DEĞİL.

**Ne zaman:** "yeni öneri var mı", "ne ekleyebiliriz", "dashboard öneri", "içerik önerisi yap", "fırsat tara", "eksik ne", "CFO başka ne ister" denildiğinde.

**Tamamlayıcı:** Öneri seçilince **uygulamak için `dashboard-icerik` skill'i** kullanılır (ne → nasıl). Bu skill SADECE öneri üretir, kod yazmaz.

---

## İLKE

**Fırsat = erişilebilir veri − dashboarda yansıyan.** Sema'da/sorguda VAR ama hiçbir kartta GÖRÜNMÜYORsa → aday öneri. Anlık sayı var ama TREND/KARŞILAŞTIRMA yoksa → aday. Toplam var ama KIRILIM (şube/il/kategori/saat) yoksa → aday.

---

## YÖNTEM (delege et — bağlam şişmesin)

Taramayı **read-only agent**'a ver (general-purpose, model: sonnet, `run_in_background: true`). Ana ajan bağlamını ürün dökümüyle doldurma.

Agent prompt iskeleti:
```
Görev: GM Dashboard'a eklenebilecek YENİ içerik/özellik önerileri çıkar. Salt-okuma, kod YAZMA.
Scope (oku):
- dashboard/Components/Pages/*.razor — hangi içerik VAR
- dashboard/Data/*.cs — hangi sorgu/veri erişilebilir
- sema/*.yaml — erişilebilir ama KULLANILMAYAN tablo/köprü = fırsat
- docs/00-INDEX.md + ilgili docs — domain bağlamı
- TODO.md — zaten planlanan (tekrar önerme)
YAPMAYACAKLARIN: kod değiştirme · mevcut özelliği tekrar önerme · TODO'dakini önerme · erişilemez veriye öneri.
Raporla (her öneri): Başlık · Ne (kart/drill/sayfa) · Neden değerli (CFO kararı) · Veri kaynağı (sema'da erişilebilir mi) · Efor (S/M/L) · Öncelik.
8-15 öneri, yüksek-değer+düşük-efor üstte. Sonunda "hızlı kazanımlar" (1-2 saat) ayrı liste.
```

Agent dönünce ana ajan: özetle + en güçlü 3'ü işaretle + "hangisini yapayım / TODO'ya mı yazayım" diye sor.

---

## DEĞER MERCEKLERİ (öneri kalitesi)

İyi öneri şu mercekten geçer — CFO'nun **kararını** değiştirir mi?
1. **Trend > anlık** — "335K kayıp müşteri" değil "geçen aya göre +%5 kayıp".
2. **Kırılım > toplam** — saat/gün/il/şube/kategori/kanal boyutu açılınca aksiyon netleşir.
3. **Karşılaştırma > tekil** — hedef vs gerçek, alış vs satış, dönem vs önceki, kanal vs kanal.
4. **Sinyal > rapor** — eşik aşımı/anomali (devir<1.5x, stockout>%5, COD>%18) → bildirim/renk.
5. **Para etkisi** — yükümlülük (hediye çeki), marj, COD zararı, ölü sermaye.

## EFOR ÖLÇEĞİ
- **S (hızlı kazanım, ~1-2s):** mevcut sorgu varyasyonu (mekanId/dönem filtresi, 2× çağrı + delta), C#-only hesap (pace-line). Yeni tablo/köprü YOK.
- **M:** yeni sorgu + cross-db/linked join (JOKER timeout riski), enum keşfi gerekli.
- **L:** yeni sayfa, çok-kaynak, şema keşfi.

## ÖNCELİK
Yüksek = düşük efor + yüksek CFO-karar etkisi + kanıtlı veri. Linked-server/keşif-gerektiren = bir tık aşağı (risk).

---

## ÇIKTI FORMATI

```
🔥 Hızlı kazanım (S, mevcut sorgu varyasyonu):
| # | Öneri | Veri | Efor |
Orta: ...
Düşük: ...
En güçlü 3 (öneri): #x, #y, #z — gerekçe.
→ Hangisini yapayım / TODO'ya mı yazayım?
```

Seçilen öneri → `dashboard-icerik` ile uygula. TODO seçilirse → `TODO.md` BKM backlog'una B-ID ile ekle (plan-tracker).

## ANTI-PATTERN
- ❌ Erişilemez/hayali veriye öneri (önce sema doğrula).
- ❌ TODO'da/dashboardda zaten olanı önermek.
- ❌ "Güzel olur" ama CFO kararı değiştirmeyen süs öneri.
- ❌ Taramayı ana bağlamda yapıp ürün dökümüyle context şişirmek → agent'a delege et.

## İlişkili
- `.claude/skills/dashboard-icerik/SKILL.md` — seçilen öneriyi UYGULA (ne→nasıl).
- `.claude/rules/agent-usage.md` — read-only araştırma agent'ı (sonnet).
- `sema/*.yaml` — erişilebilir veri envanteri (fırsat kaynağı). · `TODO.md` — planlanan (hariç tut).
