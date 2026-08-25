# plan-36 — Hediye Çeki Paneli (dashboard emitter)

**Durum:** Uygulamada · **Tarih:** 25.08.2026 · **Tier:** 3
**Çekirdek:** [`sorgular/2026-08-25-hediye-ceki-karlilik-indirim.sql`](../sorgular/2026-08-25-hediye-ceki-karlilik-indirim.sql) (18 blok, canlı doğrulanmış)
**Belge:** [`docs/2026-08-25-hediye-ceki-indirim-raporu.md`](../docs/2026-08-25-hediye-ceki-indirim-raporu.md) (v5)
**Sema:** `sema/metrics.yaml` → `hediye_ceki`, `maliyet_proxy_sapmalari`

---

## 1. Problem

Hediye çeki indirim politikası kararı tek seferlik bir rapora sıkışmış durumda. Karar sürekli tekrarlanıyor (her toplu alım görüşmesinde) ve rapor bayatlıyor. Panelde canlı olmalı.

Bugün dashboard'da yalnız **Envanter → hediye çeki yükümlülük özeti** var (`RefQueries.Envanter.GetHediyeCekiAsync`, aylık satılan vs kullanılan). Bu, kararı vermeye yetmiyor: kanal kırılımı, baremli kârlılık, müşteri bazlı mevcut indirim ve bonus alternatifi yok.

## 2. Scope

Yeni sayfa `/hediye-ceki` — 5 bölüm:

1. **KPI bandı** — satılan (net) · kullanılan · bakiye · fatura kanalı ortalama indirim
2. **Kanal kırılımı** — `irsHrk` hareket tipi bazlı (satış faturası / POS / mağaza satış / iade / bedelsiz)
3. **Baremli kârlılık** — çek dilimi × ort. çek × ort. sepet × kaldıraç × marj × kâr/fiş × kâr/1 ₺ çek × kitap payı
4. **Fatura kanalı indirimleri** — müşteri bazlı brüt / indirim / oran (kararın asıl konusu: kuralsızlık)
5. **Bonus vs indirim simülatörü** — oran seçilir, kupür seçilir; kâr/1 ₺ karşılaştırması + nominal örneği

Pencere: son 12 tam ay (kayan). Tüm tutarlar KDV-hariç net.

## 3. Alternatifler (reddedilenler)

**(a) Envanter sayfasına ek bölüm.** Reddedildi: `Envanter.razor` 553 satır, `RefQueries.Envanter.cs` 565 satır — ikisi de file-size kırmızı çizgisinde (500). 5 bölüm eklemek disiplini bozar. Ayrıca konu envanter değil ticari politika; yerleşim yanıltıcı olur.

**(b) Sadakat sayfasına sekme.** Reddedildi: hediye çeki sadakat programı değil; kurumsal satış/fiyat politikası. Kullanıcı bu paneli "müşteri davranışı" altında aramaz.

**(c) Pre-agg tablo (`bkm.HediyeCekiBarem`) + gece job.** Reddedildi (bu turda): yeni `bkm.*` tablo yazımı `erp-write-policy.md` gereği ayrı onay ister. Perf gerekirse ikinci turda gündeme gelir.

## 4. Mimari

**Emitter ayrımı.** İş mantığı `sorgular/2026-08-25-*.sql` çekirdeğinde; bu panel emitter. Formül/filtre çoğaltılmaz, port edilir.

**Perf kararı — fat5 iki sorguya bölünür.** Dilim × stkID üzerinde `fat5` OUTER APPLY tek sorguda ~54K çağrı → zaman aşımı (MCP'de 30 s'de patladı). Çözüm:

- `GetBaremKalemAsync` → dilim × stkID × kategori net/adet (fat5 YOK, hızlı)
- `GetMaliyetAsync` → distinct stkID × fat5 birim maliyet (~9K satır, ~15 s, `commandTimeout: 180`)
- Razor `@code` içinde `adet × birim maliyet` çarpımı ve dilim/kategori toplaması

Bu, emitter'da **aritmetik** bırakır (iş mantığı değil): grain, filtre, maliyet şelalesi SQL'de kalır. `emitter-ayrimi.md` sınırında; gerekçe dosya başında yorumla yazılır.

**Cache.** `AppState` deseni (Envanter'deki `env_hc` gibi) — `hc_*` anahtarları. İlk yükleme ~15 s, sonrası cache.

**Zorunlu kurallar (keşifte doğrulanmış):**
- **3-parçalı isim** — `Db.OpenAsync()` katalog `master`
- Geri dönüşüm ayıklaması **iki koşullu**: `sp.RefundReasonId <> 12 AND p.Code <> '583160'`
- Çek SKU'ları marj hesabından hariç (`KatAna <> N'Hediye Çeki'` — avans, stok değil)
- Kanal toplamı `irsHrk`'den; **`fatAyr.ehTutarN` eTip=4'te KULLANILMAZ** (beslenmiyor)
- İade sign'ı `DocumentsTypeId=3` → negatif; indirim yalnız `DiscountTotalDirect`

## 5. Riskler

| Risk | Karşılık |
|---|---|
| İlk yükleme 15 s | AppState cache + yükleniyor göstergesi; kabul edildi (kullanıcı kararı) |
| fat5 kapsama boşluğu (maliyeti olmayan stkID) | Kapsama yüzdesi panelde **açıkça** gösterilir; maliyetsiz satır net'ten düşülmez |
| Barem-1 kaldıracının yanlış okunması | Panelde basılı kupür / kısmi bakiye ayrımı gösterilir; bonus simülatörü **yalnız basılı** oranları kullanır |
| Müşteri grup konsolidasyonu ERP'de yok (`frmBagID` boş) | ✅ `musteri_gruplari` parametresi (Rapor Parametreleri) — panel bu haritayla konsolide eder |
| Bonus simülatörünün fazla güvenilir görünmesi | 50/100 ₺ oranının 28 fişe dayandığı panelde yazılı; "pilot gerekir" notu |

## 6. Done kriterleri

- [x] `dotnet build` yeşil
- [x] `/hediye-ceki` sayfası 5 bölümle açılıyor, nav'da görünüyor
- [x] Rakamlar arşiv SQL çıktısıyla tutuyor (kanal 3.198.307 brüt / kullanım 2.589.048 / barem-6 marj %37,4)
- [x] Kapsama ve örneklem uyarıları panelde yazılı
- [ ] Envanter'deki HC bloğundan panele link (ikinci tur)
- [x] Müşteri grup parametresi (Rapor Parametreleri → `musteri_gruplari`); panel fatura tablosu konsolide

## 7. Rollback

Tek commit; `git revert`. Dosyalar bağımsız (yeni sayfa + yeni servis); NavRegistry ve ServiceRegistration'dan birer satır çıkar. Mevcut sayfalara dokunulmuyor → yan etki yok.

## 8. Adımlar

1. `Models/HediyeCekiModels.cs` — record'lar
2. `Data/HediyeCekiQueries.cs` — 6 sorgu metodu (salt-okuma)
3. `Components/Pages/HediyeCeki.razor` — 5 bölüm + simülatör
4. `Models/NavRegistry.cs` + `ServiceRegistration.cs` — birer satır
5. `dotnet build` + rakam mutabakatı
