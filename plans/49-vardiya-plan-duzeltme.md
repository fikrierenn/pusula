# Plan 49 — Vardiya planı düzeltme + izin günü tanımı (V-05)

**Tarih:** 2026-09-19
**Proje:** `bkm`
**Yazan:** Fikri / Claude
**Durum:** `Taslak` — onay bekliyor

---

## 1. Problem

Kişi-gün hesabı `bkm.sp_Vrd_KisiGunDoldur` tarafından yazılıyor ve vardiya planı PDKS
aktarımından geliyor. **Plan eksik olduğunda SP sessizce şube varsayılanına düşüyor**
(`ÇALIŞMA SAATİ POLİTİKASINDA KARŞILIĞI YOK — şube varsayılanı kullanıldı`).

**ÖLÇÜLDÜ (19.09.2026, 6.113 kişi-gün):**

| Ölçüt | Değer |
|---|---|
| Plan süresi boş (`PlanCalismaDk IS NULL`) | **0** |
| Vardiya tanımı boş → `Vardiya Tanımsız Çalışma` | **172 gün** |
| İzinli gün (`Izin = 1`) | 781 |
| `İzin Günü Çalışılmış` | 143 |

172 günün dağılımı: Genel Müdürlük 70 (7 kişi, görev tanımsız ofis kadrosu, ort.
511-554 dk) · Heykel 49 (10 kişi) · kafeler 25 · mağazalar 17. Yani bunlar **hata
değil, EKSİK TANIM**: ofis çalışanının PDKS'de vardiya kaydı yok, SP 540 dk
varsayılanı uyguluyor ve eksik/fazla o tabana göre hesaplanıyor.

**Bugün bu eksiği düzeltmenin yolu YOK.** Excel'e dönülüyor; panel yalnız gösteriyor.

## 2. Scope

### Kapsam dahili
- Yeni app-owned tablo `bkm.Vrd_PlanDuzeltme` — kişi-gün bazında **plan düzeltmesi**
  (vardiya tanımı, başlama/bitiş/süre) ve **izin günü işareti**.
- Yazma yolu: onay ekranıyla aynı desende tek metot + kapsam kapısı + denetim izi.
- Okuma: rapor sorgularında `LEFT JOIN` ile plan alanlarının üzerine yazılması
  (`Vrd_Onay`'ın bugünkü deseni).
- Kimin yazabildiği: `vardiya.onayla` (şube sorumlusu + İK). GMY **yazmaz**
  (plan 48 yetki matrisi: GMY salt-okuma).

### Kapsam dışı
- **Vardiya planı ÜRETİMİ** (kim hangi gün hangi vardiyada çalışacak — ileriye dönük
  çizelge). Bu ayrı bir üründür; burada yalnız GEÇMİŞ bir günün eksik tanımı düzeltilir.
- PDKS'ye geri yazma. Kaynak sistem dokunulmaz kalır.
- `sp_Vrd_KisiGunDoldur` değişikliği — SP'nin yazdığı kolonlar OKUNUR, üzerine
  uygulama katmanında yazılır (emitter-ayrimi.md: hesap çoğaltılmaz).
- İzin **hakedişi** (yıllık izin bakiyesi). Burada yalnız "bu gün izinliydi" işareti var.

### Etkilenen dosyalar (tahmin)
- `sorgular/2026-09-XX-vardiya-plan-duzeltme-tablo-kur.sql` — DDL (idempotent)
- `lib/Bkm.Shared/Data/VardiyaQueries.cs` — okuma birleşimi + yazma metodu
- `lib/Bkm.Shared/Models/VardiyaModels.cs` — DTO alanları
- `vardiya-app/Pages/Approval.cshtml(.cs)` — mevcut ekrana plan/izin bölümü
- `tests/BkmVardiya.Tests/PlanCorrectionTests.cs` — yeni
- `.claude/rules/erp-write-policy.md` — yeni app-owned tablo satırı

**Tahmini boyut:** 6-7 dosya / ~400 satır.

## 3. Alternatifler

### (a) SP'yi değiştirip planı SP içinde düzeltmek — **REDDEDİLDİ**
Hesap SP'de, düzeltme de SP'de olsaydı tek yer olurdu. Ama düzeltme bir **insan
kararıdır** ve SP her koşumda kişi-günü yeniden yazıyor; düzeltmeyi SP'ye koymak
"kim düzeltti, ne zaman" sorusunu cevapsız bırakır ve denetim izi kurulamaz.
Ayrıca SP'yi her düzeltme için yeniden koşturmak gerekirdi.

### (b) `Vrd_KisiGun` satırını doğrudan UPDATE etmek — **REDDEDİLDİ**
En kısa yol ve **en tehlikelisi**: tablo yalnız SP tarafından yazılıyor
(`erp-write-policy.md`). Uygulama oraya yazarsa SP'nin bir sonraki koşumu düzeltmeyi
**sessizce ezer** ve kimse fark etmez. Ayrıca "ölçülen" ile "düzeltilen" ayrımı kaybolur.

### (c) Düzeltmeyi `Vrd_Onay` tablosuna eklemek — **REDDEDİLDİ**
Onay ile plan düzeltmesi **farklı sorular**: onay "bu mesaiyi kabul ediyorum" der,
plan düzeltmesi "bu günün tanımı şuydu" der. Aynı satıra koymak, birini silmeyi
ötekini de silmek yapardı; ayrıca onay tablosu bugün boş (0 satır) ve şeması
onay-özel (`OnayliGirisDk` vb.).

### (d) AYRI tablo + okuma birleşimi — **SEÇİLDİ**
`Vrd_Onay` deseninin ikizi: ölçülen (SP) ile düzeltilen (insan) ayrı durur, ikisi
okuma anında birleşir. SP yeniden koşsa da düzeltme kaybolmaz. Denetim izi doğal.

## 4. Riskler

| Risk | Etki | Azaltma |
|---|---|---|
| Düzeltme kapsam dışı bir kişi-güne yazılır | Yetki sızıntısı | Yazma yolunda kapsam kapısı (`SaveApprovalAsync` deseni) + test |
| Düzeltme eksik/fazla hesabını değiştirir ama Excel'le sapar | İki farklı toplam | Rapor ekranında "düzeltilmiş" işareti + düzeltme sayısı KPI'ı |
| İzin işareti mevzuat kapısını yanıltır | Sahte uyum | Mevzuat kapısı düzeltilmiş veriyi okur; `mesai_mevzuat_kapisi.py` kapsamına alınır |
| Yeni tablo `erp-write-policy` listesine yazılmaz | Politika bayatlar | Aynı commit'te kural güncellenir (DoD) |
| Düzeltme yazılır, iz yazılmaz | Denetlenemez | Tek işlem (V-12 deseni), test: iz tam bir kez |

## 5. Done criteria

1. DDL idempotent koşuyor; tablo `bkm.Vrd_PlanDuzeltme`, koşullu UNIQUE (SicilNo, Tarih).
2. Yazma yolu tek metot, kapsam kapılı, **iz ile aynı işlemde**.
3. Okuma: rapor satırında düzeltilmiş plan görünüyor ve **düzeltilmiş olduğu belli**.
4. Testler: kapsam dışına yazamama · idempotent · iz tam bir kez · düzeltme okumada
   görünüyor. Her biri kırmızı kiple doğrulanmış.
5. `erp-write-policy.md` güncel; `tools/vardiya_kapsam_denetimi.py` yeni tabloyu
   kapsamlı tablolar listesine almış (boğazdan geçiyor).
6. Excel ile mutabakat: düzeltme YOKKEN rakamlar bugünküyle **birebir aynı**.

## 6. Rollback

Tablo yeni ve yalnız uygulama yazıyor: `DROP TABLE bkm.Vrd_PlanDuzeltme` + kodun
revert'i yeter. `Vrd_KisiGun`'a dokunulmadığı için ölçülen veri etkilenmez — geri alma
**veri kaybı üretmez**.

## 7. Adımlar

1. **DDL** — tablo + koşullu UNIQUE + CHECK (süreler 0-2880) + `erp-write-policy` satırı.
2. **Model + okuma** — `VrdRow`'a düzeltme alanları; `GetRowsAsync` LEFT JOIN
   (boğazdan, `VrdSql.PersonDays` ile).
3. **Yazma** — `SavePlanCorrectionAsync`: kapsam kapısı → işlem → yazma + iz.
4. **Ekran** — onay ekranına "Plan düzeltme / İzin günü" bölümü.
5. **Testler** — dört iddia, dördü de kırmızı kiple.
6. **Kapılar** — kapsam denetimi + mevzuat kapısı güncellenir.

## 8. Açık sorular (onay öncesi)

- **S1.** Düzeltme eksik/fazla hesabını DEĞİŞTİRSİN mi, yoksa yalnız NOT olarak mı
  dursun? (Değiştirirse yayınlanan Excel'den sapar; sapma bilinçli olmalı.)
- **S2.** 172 günün 70'i Genel Müdürlük ofis kadrosu. Bunlar için tek tek düzeltme mi,
  yoksa `Vrd_CalismaSaati`'ne bölüm bazlı kalıcı tanım mı? İkincisi daha az emek ama
  politika tablosunu değiştirir (İK kararı).
- **S3.** İzin günü işareti PDKS'deki `Izin` alanını mı ezecek, yoksa ayrı mı duracak?
