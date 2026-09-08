# Plan 42 — Satış Analizi paneli (stok × satış × sezon, tarih seçmeli)

**Tarih:** 2026-09-08
**Proje:** `bkm`
**Yazan:** Claude (oturum `ecc43bbf`)
**Durum:** `Tamamlandı` — 09.09.2026 (kullanıcı onayı + danışma revizyonlarıyla)

---

## 1. Problem

"Satış Analizi <tarih>.xlsx" (Kübra Kulaksızoğlu) sezon alım kararının fiilî dayanağı:
ürün bazında stok (mağaza + merkez + ODAK) yanında 365 günlük satış ve geçen sezonun üç ayı.
Bugün bu rapor **elle üretilip Excel olarak dolaşıyor**; her üretimde SQL yeniden yazıldığı için
kapsam hataları taşıyor (bu oturumda ölçülen dördü: merkez depo çıkışı satışa sayılmıyor,
`Kategori3` filtresi satılabilir ürün kaçırıyor, `OdakStok` toplamda yok ama tabloda var,
365g pencere Ağustos'u dışarıda bırakırken SezonToplam içeriyor).

Script (`scripts/satis_analizi_excel.py`) tanımı sabitledi ama **kullanıcı hâlâ dosya bekliyor**:
tarih seçip ekranda görmek, kırılıma bakmak, gerekirse Excel indirmek istiyor.

## 2. Scope

### Kapsam dahili
- Yeni sayfa `/satis-analizi`: KPI şeridi + Kategori3/Kategori1 kırılımı + sunucu-taraflı
  filtreli & sayfalı ürün tablosu + Excel indirme.
- **Tarih seçimi: iki girdi** — (a) kesim tarihi (as-of; satış penceresi otomatik 365 gün geriye),
  (b) sezon yılı (Ağu-Eki hangi yıl). Kullanıcı kararı 08.09.2026.
- **MerkezStok her zaman bugünün WMS'i** + sayfada görünür uyarı. Kullanıcı kararı 08.09.2026.
- Yeni `dashboard/Data/SatisAnaliziQueries.cs` (salt-SELECT).
- `NavRegistry` kaydı.

### Kapsam dışı
- Merkez depo geçmiş stoğu (WMS snapshot yok — `bkm.StokAyBakiyeMekanBazli` yalnız ay-sonu).
  Uyarıyla bugünün değeri gösterilir, geçmişe gidilmez.
- Kapsam hatalarının **düzeltilmesi**: panel orijinali birebir yansıtır (kıyas mümkün olsun).
  Düzeltmeler ayrı iş — bkz. §8 açık madde.
- ODAK stoğunun toplama katılması (orijinal katmıyor; panel de katmaz).
- Yazma: hiçbir ERP tablosuna yazılmaz (`erp-write-policy`).

### Etkilenen dosyalar (tahmin)
- `dashboard/Data/SatisAnaliziQueries.cs` — YENİ, ~260 satır (3 sorgu: KPI/kırılım/sayfalı liste)
- `dashboard/Components/Pages/SatisAnalizi.razor` — YENİ, ~280 satır
- `dashboard/Models/NavRegistry.cs` — 1 satır
- `dashboard/ServiceRegistration.cs` — 1 satır (DI, ilgili `AddBkm*` grubuna)
- `sema/queries.yaml` — 1 kayıt (panelin çekirdek sorgusu, duman testine girsin)
- `sema/degismezler.json` — 1 kayıt (panel ↔ script mutabakatı, bkz. §4 sapma riski)
- `TODO.md` — plan maddeleri

**Tahmini boyut:** 7 dosya / ~560 satır (2'si yeni).

## 3. Alternatifler

### A: Mevcut Envanter sayfasına sekme
**Açıklama:** Yeni sayfa açmadan `/envanter`'a "Sezon" sekmesi.
**Reddetme sebebi:** Envanter sayfası zaten ağır (marj sorgusu ~9s, B-74 stream'leme ile idare
ediliyor); üstüne 273K satırlık ürün tablosu binince sayfa kullanılamaz hale gelir. Ayrıca
Envanter "anlık stok" sayfası; bu rapor tarih-seçmeli, iki farklı zaman modeli tek sayfada karışır.

### B: Yalnız Excel üretici kart (tarih seç → dosya in)
**Açıklama:** Ayarlar altında küçük bir kart; ekranda tablo yok.
**Reddetme sebebi:** Kullanıcı ekranda görmek istedi (08.09 kararı). Ayrıca Excel'e bakmak
mevcut sorunu (dosya dolaşması) sürdürür; kırılımı ekranda görmek karar hızını artırır.

### C: Sayfayı script'in SQL'ini aynen çağırarak yaz (tek sorgu, 275K satır)
**Açıklama:** `satis_analizi_excel.py` sorgusunu Dapper'a taşı, sonucu belleğe al, sayfada filtrele.
**Reddetme sebebi:** Ölçüldü — o sorgu **17 saniye** sürüyor ve 275K satır döndürüyor. Blazor
Server'da bu hem circuit belleğini şişirir hem ilk açılışı 17s'ye çıkarır. Pahalı kısım
`MIN(irsHrk.ehTrhS)` tam-tablo agregası; ekranda ise IlkGirisTarihi yalnız **görünen sayfada**
gerekiyor.

### D (SEÇİLEN): Üç ayrı sorgu — agrega, kırılım, sayfalı liste
**Açıklama:**
1. **KPI** — tek satır agrega (stok değeri, çeşit, gün-stok, ölü stok ₺, stoksuz sezon ürünü).
2. **Kırılım** — `GROUP BY Kategori3` (12 satır) + istenirse `Kategori1` drill.
3. **Liste** — filtre (arama/kategori/mağaza/durum) + `ORDER BY … OFFSET/FETCH`, sayfa başına
   50-200 satır. `IlkGirisTarihi` bu sorguda **OUTER APPLY** ile yalnız görünen satırlar için
   hesaplanır (`sql-server-conventions` § "filtreyi aşağı it" kuralı).
4. **Excel indirme** — tam dökümü isteyen buton `ExcelExport.Olustur` ile üretir; ağır sorgu
   yalnız butona basılınca koşar (sayfa açılışını bloklamaz).

**Sebep:** Sayfa açılışı yalnız 1+2'yi bekler (agrega, ~1-3s hedefi); 273K satır hiçbir zaman
belleğe alınmaz. Ölçülen 17s yalnız Excel yolunda kalır ve orada kabul edilebilir.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Panel SQL'i script'ten **sapar** → aynı metrik iki yerde farklı (emitter-ayrımı ihlali) | **yüksek** (sessiz yanlış rakam) | orta | Tanımlar `sema/queries.yaml`'a yazılır + `sema/degismezler.json`'a **panel ↔ script mutabakat** değişmezi (aynı kesimde SezonToplam ve Satis_Toplam eşit olmalı). Kırılabilirliği sınanır. |
| Ürün tablosu sorgusu yavaş (273K satır üstünde filtre+sıralama) | orta | orta | `OFFSET/FETCH` + arama `stkID IN (alt-sorgu UNION)` kalıbı (`OR EXISTS` yasak, 17.06 dersi). Ölçüm: her filtre kombinasyonunda <2s hedefi; aşarsa index önerisi TODO'ya. |
| Dapper record materialization hatası (smallint/tinyint, 8+ kolon) | orta | orta | 8+ kolonlu sorgularda **record** (ValueTuple yasak, 24.06 dersi) + `CAST(... AS int)` (23.06 dersi). |
| `Db.OpenAsync` master bağlamında 2-parçalı isim → Err 208 | orta | **yüksek** (bu tuzağa daha önce düşüldü) | Tüm ERP nesneleri **3-parçalı**: `DerinSISBkm.bkm.UrunBilgi`, `DerinSISBkm.dbo.irsHrk`, `DerinSISBkm.depo.stok_adres_palet_vw`, `DerinSISBkm.ent.odak_depo_Stok`. Login-arkası smoke test. |
| Kullanıcı geçmiş tarih seçip merkez stoğu geçmiş sanır | orta | orta | Sayfa başlığında ve MerkezStok kolonu başlığında sabit uyarı: "merkez depo = **bugünün** WMS'i". Kesim tarihi bugünden farklıysa uyarı `warning` rengine döner. |
| Lucide ikon koşullu render → circuit çöküşü | yüksek | düşük | İkon/spinner sabit tutulur, görünürlük CSS ile (29.08 dersi). |

## 5. Done Criteria

- [ ] `/satis-analizi` açılıyor, login-arkası smoke test geçiyor (Err 208 yok).
- [ ] Kesim tarihi + sezon yılı değiştirilince KPI ve kırılım yeniden hesaplanıyor.
- [ ] **Mutabakat ölçüldü:** aynı kesim (`--bitis`) için panel KPI'ları ile
      `scripts/satis_analizi_excel.py` çıktısının toplamları **birebir** eşit
      (SezonToplam, Satis_Toplam, MagazaStok, ToplamStokTutar).
- [ ] Ürün tablosu filtreli sorgusu <2s (ölçülüp yazılacak).
- [ ] Sayfa açılışı (KPI+kırılım) <3s (ölçülüp yazılacak).
- [ ] MerkezStok uyarısı görünüyor; kesim ≠ bugün iken vurgulu.
- [ ] Excel indirme çalışıyor, script çıktısıyla aynı kolon sırası.
- [ ] `sema/queries.yaml` kaydı duman testinden geçiyor (`tools/sema_sorgu_dumani.py`).
- [ ] Panel↔script değişmezi yeşil **ve** bilerek kırmızıya düşürülüp geri alındı.
- [ ] `dotnet build` yeşil.

## 6. Rollback Planı

- `git revert <commit>` yeterli: yalnız yeni dosya + 2 satır kayıt (NavRegistry, DI).
- DB değişikliği YOK (salt-okuma), migration yok, config yok.
- Nav kaydı geri alınınca sayfa erişilemez hale gelir; kalan dosya zararsızdır.

## 7. Adımlar

1. [ ] **P42-1** `SatisAnaliziQueries.cs` — KPI + kırılım sorguları (3-parçalı isim, record).
2. [ ] **P42-2** Sayfalı/filtreli ürün listesi sorgusu (OFFSET/FETCH + OUTER APPLY IlkGirisTarihi).
3. [ ] **P42-3** `SatisAnalizi.razor` — tarih seçiciler, KPI şeridi, kırılım tablosu, uyarı bandı.
4. [ ] **P42-4** Ürün tablosu + filtreler + sayfalama UI.
5. [ ] **P42-5** Excel indirme (`ExcelExport.Olustur`, script ile aynı kolon sırası).
6. [ ] **P42-6** NavRegistry + DI kaydı.
7. [ ] **P42-7** Mutabakat ölçümü (panel vs script) + `sema/queries.yaml` + değişmez.
8. [ ] **P42-8** Build + login-arkası smoke + perf ölçümü, sonuçlar plana yazılır.

## 8. İlişkili

- Kaynak/tanım kanıtı: `sorgular/2026-09-08-satis-analizi-excel-denetim.sql` §10
- Çekirdek script (emitter kardeşi): `scripts/satis_analizi_excel.py`
- Sema: `ent.DEPOLARDAKISTOKLAR`, `irsHrk.MERKEZ_DEPO_CIKISI`, `MEKAN_CIRO_MUTABAKAT_FORMULU`
- Kurallar: `emitter-ayrimi.md` (tek çekirdek, çok emitter) · `sql-server-conventions.md`
  (3-parçalı isim, WMS merkez stoğu, Dapper tuzakları) · `renk-standardi.md` (DaisyUI token)
- Journal: `docs/journal/bkm/2026-09-08.md`
- **Açık madde (bu planın kapsamı DIŞI):** raporun 4 kapsam hatası panelde de yansıyacak.
  Düzeltilmiş bir "gerçek talep" görünümü (merkez çıkışı dahil gün-stok, kaçan kategoriler)
  ayrı bir iş olarak TODO'ya girer — panel önce orijinali birebir yansıtsın, kıyas mümkün olsun.

## 9. Onay

- [x] Plan kullanıcıya gösterildi
- [ ] Kullanıcı onayladı → uygulamaya geçilir

---

## 10. Uygulama sonucu (09.09.2026)

Plan onaylandı ve uygulandı; **danışma turları planı üç yerde değiştirdi**:

### Değişen kararlar
| Plan (08.09) | Uygulanan (09.09) | Sebep |
|---|---|---|
| CTE ile canlı hesap | **`bkm.SatisAnaliziTaban` ön-agrega** (ERP app-owned tablo, kullanıcı onaylı) | Ölçüldü: sayfa çevirme 5,3-5,4 s → **15-27 ms**, KPI 3,2-3,8 s → **54 ms**, arama 5,8 s riski → **16 ms**. `#temp` yetmedi (bağlantı kapsamlı) |
| KPI 8 kart | **4 kart, karşı-metrik aynı kartta iki satır** | Kullanıcı: "taşıyorlar, çok sıkışık". Carousel 8 kartı tek satıra sığdırıyordu |
| Orijinali birebir yansıt | + **taze stok / stok yaşı / ODAK temin süresi / giriş maliyeti** eklendi | Danışma: adil-atıf (yeni mal aşırı sayılmaz) · 131,4M ₺'lik bulgu leadTime'la ortaya çıktı · "tutar satış fiyatıyla" eksiği maliyetle kapandı |

### Eklenenler (planda yoktu)
- Kullanıcı seçmeli kolon (30 kolon, tercih `dbo.PanelKolonTercih`'te kişi başına) — Solum danışmasıyla tasarlandı
- Ürün drill sayfası `/satis-analizi/urun/{stkId}` — beş soruya cevap
- Aylık satış grafiği (365 gün) — sezon kapsamasının yanıltmasını düzeltiyor
- Giriş maliyeti + bağlanan para (kanonik `birim_maliyet` MLYT şelalesi)

### Kurul incelemesinde bulunan ve düzeltilen üç hata
1. **Taze tanımı yanlıştı** — son partiye bağlıydı; hızlı devreden her ürün "değerlendirilemez" görünüyordu. Doğrusu ürünün mağazadaki ilk girişi.
2. **Karar cümlesi sırası ters** — tazelik kontrolü stok/satış dengesinden önce geliyordu.
3. **Dengesizlik ölçütü kaçırıyordu** — `min stok <= 0` yerine mağazalar arası stok/satış oranı 3 kat farkı.

### Açık kalan (kullanıcı kararı bekliyor)
- **KPI adı vs içerik:** "Bağlanan Stok 1.025.664.281 ₺" satış fiyatıyla; ölçülen tek üründe bağlanan para 823.457 ₺ vs satış fiyatıyla 3.763.090 ₺ (**4,6 kat**). Ya ad değişir ya maliyet şelalesi tabana konur.
- **Marj KDV karışık** — satış KDV dahil, maliyet hariç olabilir; kitap %0 / kırtasiye %20.
- **Açık sipariş (yolda mal) hâlâ yok** — kurulun "en kritik eksik" dediği madde.
