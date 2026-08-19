# Plan 35 — Sınav Paneli (hızlı kazanımlar)

**Tarih:** 2026-08-19
**Proje:** `bkm`
**Yazan:** Claude (Fikri direktifi: "hızlı kazanımları ekleyelim")
**Durum:** `Taslak` — onay bekliyor

---

## 1. Problem

Sınav Okulları operasyonu 29.07.2025–19.08.2026 arasında **430,9M ₺ (KDV dahil)** ciro üretti; dashboard'da **tek kart bile yok** (`Tahmin.razor`'da sezon etkisi + takvimde sınav günü dışında hiçbir şey). Aynı zamanda 2026-08-19 keşfinde üç somut para/güven riski çıktı:

- `snv.Siparis.Odendi` bit'i **1.787 siparişte hatalı "ödendi"** gösteriyor (kısmi ödemeyi tam sanıyor).
- Dönem 8'de **64.521,90 ₺** eksik kalem var; 32.672,90 ₺'si stok varken kasadan geçmemiş.
- 13 ayda **92 satır / 4.015,75 ₺ eksik kesilen KDV** (POS oranı ≠ ERP oranı).

Bu bilgiler şu an yalnız `sorgular/2026-08-19-*.sql` dosyalarında; kimse düzenli görmüyor.

## 2. Scope

### Kapsam dahili — tek sayfa `/sinav`, 5 bölüm

1. **Sezon KPI şeridi** — net ciro (KDV hariç) · sipariş (`DISTINCT SiparisKod`) · ort. sepet · yan ürün payı · iade oranı · kısmi sipariş sayısı.
2. **Ödeme Sağlık Kartı** — TAM / KISMİ / HİÇ ÖDENMEDİ dağılımı + **flag çelişkisi sayacı** (çelişki > 0 → `text-error`).
3. **Eksik Kalem Tahsilat Tablosu** — kampüs + sınıf + ürün + tutar (`SinavUrun.Fiyat`) + **stok var/yok** rozeti.
4. **Yan Ürün Attach Kartı** — Paket / Kıyafet / Yan kova kırılımı + attach oranı + fiş başı yan ciro.
5. **İade Radarı** — `LinkedDocumentId` zinciri; `KASA_DUZELTMESI` vs `GERCEK_IADE` etiketi + kampüs kırılımı.

### Kapsam dışı (bilinçli)

- Kampüs karnesi, huni, sınıf sepet analizi, momentum eğrisi, retention (öneri #6-#13 — sonraki tur).
- `bkm.SinavOdemeDurumLog` yazma tablosu (ERP-yazma onayı ayrı konu).
- Dönem 5-6 tarihçesi (`snv.SiparisFis` / EAR-EFA köprüsü farklı).
- Öğrenci adı/telefonu (KVKK — kampüs + sınıf + `SiparisKod` yeterli).
- Excel export (mevcut `ExcelExport.cs` ile sonra eklenebilir).

### Etkilenen dosyalar

| Dosya | Ne |
|---|---|
| `dashboard/Data/SinavQueries.cs` | **YENİ** — 5 metot, `Db.OpenAsync()` + 3-parçalı isim |
| `dashboard/Models/SinavModels.cs` | **YENİ** — 5 record (positional, `CAST(... AS int)` kuralına dikkat) |
| `dashboard/Components/Pages/Sinav.razor` | **YENİ** — 5 bölüm, DaisyUI token |
| `dashboard/Models/NavRegistry.cs` | 1 satır — `new NavItem("sinav", "Sınav", "graduation-cap", Section: "...")` |
| `dashboard/Data/ServiceRegistration.cs` | DI kaydı (ilgili `AddBkm*` grubuna) |
| `TODO.md` | B-155..B-159 |

**Tahmini boyut:** 6 dosya · ~600 satır (Queries ~250, Razor ~250, Models ~80, kayıt 2 satır).
`file-size-discipline`: Razor 300 satırı aşarsa bölüm sub-component'e çıkar (code-behind DEĞİL — markup RenderFragment kuralı).

## 3. Alternatifler

### A: Mevcut sayfalara dağıt (Mağaza / Müşteri / Kontrol)
**Açıklama:** Sınav KPI'larını ilgili sayfalara kart olarak serpiştir, yeni sayfa açma.
**Reddetme sebebi:** Sınav ayrı bir operasyon (ayrı sipariş/kitap/kampüs modeli, `snv` şeması). Kartlar bağlamsız kalır; ayrıca müşteri raporları CFO direktifiyle **Sınav hariç** (B-103) — aynı sayfada yan yana durması kural çelişkisi yaratır.

### B: Python emitter (Excel/brief) ile başla, dashboard sonra
**Açıklama:** `scripts/sinav_rapor.py` yazıp Excel/markdown üret.
**Reddetme sebebi:** Bu 5 metrik **düzenli izlenmeli** (sezon içi günlük), tek seferlik döküm değil. Emitter-ayrımı kuralı gereği çekirdek zaten `sorgular/`'da hazır; dashboard emitter'ı doğru ilk basamak. Excel sonradan aynı çekirdekten dökülür.

### C (SEÇİLEN): Tek yeni sayfa `/sinav`, 5 bölüm, mevcut SQL'lerden port
**Sebep:** Beş öneri aynı veri kümesini (Siparis + SiparisDetay + SinavSiparisFisEncore + Sales) paylaşıyor → tek sayfa, tek sorgu turu, tek nav girişi. Sorgular bu oturumda yazılıp canlı doğrulandı (721 satır / 24 fiş header mutabakatı birebir). Efor S, risk düşük.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| **`Db.OpenAsync` master bağlamı** → 2-parçalı isim Err 208 | Yüksek | Yüksek | Tüm nesneler **3-parçalı** (`BKM.snv.Siparis`, `EncoreMerkez.dbo.Sales`, `DerinSISBkm.dbo.urn`) — `sql-server-conventions.md` 23.06 dersi |
| Dapper record materialization (`smallint`/`tinyint`, 8+ kolon) | Orta | Orta | `CAST(... AS int)`; 8+ kolonda ValueTuple YASAK → `record` |
| Perf: `SiparisDetay` 365K satır × `OUTER APPLY` | Orta | Orta | Dönem filtresi (`DonemId`) zorunlu; ödeme özeti tek pass GROUP BY; ölç, >2s ise pre-agg düşün |
| `SiparisDetay` fan-out (SiparisId+StokId) | Yüksek (ciro şişer) | Düşük | `OUTER APPLY TOP 1` — 18.08'de 721=721 doğrulandı, kural korunur |
| KDV-dahil/hariç karışması | Yüksek | Orta | Tek kaynak: `TotalPrice − VatTotal`; UI'da her tutarın yanında "KDV hariç" etiketi |
| Dönem seçimi hardcode | Orta | Orta | `@DonemId` parametre + sayfada dropdown (aktif dönem varsayılan); `DonemId=8` gömme YASAK |
| Dev server açıkken build patlar | Düşük | Yüksek | `preview_stop` → `dotnet build` (18.08 dersi) |

## 5. Done Criteria

- [ ] `/sinav` sayfası açılıyor, 5 bölüm veri döndürüyor.
- [ ] **Mutabakat:** sayfa net ciro (KDV hariç) = `Σ(GrossTotal − DiscountTotal − VatTotal)` header toplamıyla **birebir** (18.08.2026 için 1.211.490,57 ₺).
- [ ] Ödeme kartı dönem 8'de **294 / 35 / 28** ve çelişki **35** gösteriyor.
- [ ] Eksik kalem tablosu **55 satır / 64.521,90 ₺** toplamı veriyor.
- [ ] Attach kartı Paket 1.098.902,37 · Kıyafet 35.408,92 · Yan 77.179,28 (18.08) veriyor.
- [ ] İade radarı 298 iade fişi (171 FE-içi + 127 FE-dışı) sayıyor.
- [ ] `dotnet build` yeşil, uyarı yok.
- [ ] Mobil (375px) okunabilir; tablolar `overflow-x-auto`.
- [ ] Hardcode hex renk YOK (`renk-standardi.md`), tüm tutarlar KDV-hariç etiketli.
- [ ] `veri-dogrula` skill'i ile QA geçti.

## 6. Rollback Planı

`git revert <commit>` yeterli — 3 yeni dosya + 2 satır kayıt. DB'ye yazma YOK (salt-okuma, `erp-write-policy.md` uyumlu). Nav girişi kalkınca sayfa erişilemez olur, başka sayfa etkilenmez.

## 7. Adımlar

1. [ ] **B-155** `SinavQueries.cs` + `SinavModels.cs` — 5 metot, 3-parçalı isim, dönem parametreli
2. [ ] **B-156** `Sinav.razor` — 5 bölüm, DaisyUI, KDV-hariç etiketi, dönem dropdown
3. [ ] **B-157** NavRegistry + ServiceRegistration kaydı
4. [ ] **B-158** Mutabakat doğrulama (done criteria rakamları) + build
5. [ ] **B-159** `veri-dogrula` QA + `sema/entities.yaml`'a `snv.*` kayıtları (SiparisDetay ödeme modeli, SinavUrun.Fiyat, SinifKitap.FisteGoster çürütmesi)

## 8. İlişkili

- Kaynak SQL (bu oturum): `sorgular/2026-08-19-sinav-encore-kdv-denetim.sql` · `-sinav-fis-detay-DOGRU.sql` · `-sinav-yan-urun-atif.sql` · `-sinav-kdv-anomali-tum-gecmis.sql` · `-sinav-iade-zinciri.sql` · `-sinav-odeme-durumu-pingpong.sql` · `-sinav-odeme-kismi-model.sql`
- Brifingler: `briefings/2026-08-19/sinav-*.md` (3 dosya)
- Açık TODO örtüşmesi: **B-10** (`bkm.HareketKanal_vw` Sınav/Perakende ayrımı) ve **B-11** (2026 tahmin Sınav ayrık) — bu plan onları kapsamıyor, veriyi hazırlıyor.
- Kurallar: `sql-server-conventions.md` (3-parçalı · Dapper CAST · iade sign) · `renk-standardi.md` · `emitter-ayrimi.md` (çekirdek `sorgular/`'da, bu dashboard emitter'ı) · `erp-write-policy.md` (salt-okuma)

## 9. Onay

- [x] Plan kullanıcıya gösterildi — 19.08.2026
- [ ] Geri bildirim alındı
- [ ] Onay alındı

### ⚠️ Ön koşul

`git status` **17 uncommitted dosya** — `commit-discipline.md` 15 eşiği aşıldı, yeni iş öncesi commit-split gerekiyor. Kullanıcı onayı olmadan commit atılmaz.
