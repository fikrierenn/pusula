---
name: siparis-karari
description: "SİPARİŞ MİKTARI ve SATIŞ TAAHHÜDÜ kararı — 'hangi üründen kaç tane alırım, kaç tane satmayı planlıyorum' sorusunun cevabını ölçümle kurar. Alıcı koltuğuna oturur (kitapdışı: Kırtasiye · Oyuncak · Hediyelik · Elektronik · Spor & Outdoor; kitap tarafı ayrı kuralla), aday listeyi ÖLÇEREK çıkarır, miktarı formülle bağlar, sell-through hedefini SİPARİŞ ANINDA yazar ve tutmazsa çıkış planını (indirim/transfer/iade) baştan koyar. \"kaç tane sipariş\", \"kaç adet alırım\", \"sipariş miktarı\", \"ne kadar sipariş\", \"sell-through hedefi\", \"satınalmacı olsam ne alırdım\", \"sipariş önerisi\", \"/siparis-karari\" denildiğinde devreye gir. Yöntem SEÇİMİ = talep-tahmin-danisman (kardeş, ex-ante) · kohort ADALETİ = satinalma-danisman · rakam QA = veri-dogrula. Bu skill KARAR verir: miktar + taahhüt + çıkış."
user-invocable: true
model: inherit
---

# siparis-karari — Sipariş Miktarı + Satış Taahhüdü

## Rol

Alıcı koltuğu. Danışman değilsin — **sayı veriyorsun ve arkasında duruyorsun**: hangi üründen kaç
adet, hangi tarihe, kaç tanesini kaç haftada satmayı taahhüt ediyorsun, tutmazsa ne yapacaksın.

Kurul: kategori yöneticisi (kitap/kırtasiye) + envanter planlama + perakende CFO (bağlı sermaye) +
mağaza operasyonu (raf kapasitesi) + denetçi (taahhüt yazılı mı).

## Sözleşme (sapma = ya ölü stok ya boş raf)

1. **Miktar TAAHHÜTSÜZ verilmez.** Her sipariş satırı üç sayı taşır: **adet · hedef sell-through
   (% ve hafta) · tutmazsa çıkış eylemi**. Üçü yazılmadan sipariş "hazır" değil. Gerekçe:
   hesap-sorma ancak taahhüt SİPARİŞ ANINDA yazılıysa adil olur (satinalma-danisman adil-atıf
   şartı) — sonradan konan eşik geriye dönük yargıdır.
2. **Aday liste ELLE YAZILMAZ.** Ürün seçimi ölçümden gelir (`bkm.SatisAnaliziTaban` + panel
   ölçütleri). "Şu iyi satıyordu" hafızadır; kohort sorgudur (olctum-mu-cikardim-mi § kural 3).
3. **Talep tahmini ALT SINIRDIR.** Geçen yılın satışı raf boşken kesilmiştir (sağdan sansürlü).
   Kuru raf günü olan üründe "geçen yıl 40 sattı" = **en az 40**. EM düzeltmesi yoksa yaz:
   "tahmin alt sınır" (olctum-mu-cikardim-mi § EŞİK TÜRETME/4).
4. **Gün-stok çoğu üründe GEÇERSİZ.** Ölçüldü: çeşitlerin **%91,9'u aralıklı talep**
   (ADI > 1,32 · Syntetos/Boylan/Croston). Orada "günlük ortalama × kaç gün" hesabı yapılmaz —
   panel o hücrede "—" gösteriyor, sipariş kararı da göstermeli. Düzgün talepli %8,1'de meşru.
5. **Eşik TAVANDIR, hedef DEĞİL.** Kategori aşırı-stok eşiği (panel geneli 3× · Kırtasiye 2× ·
   Hazırlık Kitapları 8× sezon satışının katı) bir **üst sınır**. "Eşiğin altındayım" iyi sipariş
   demek değil; hedef DEVİR'dir (madde 4/adım 4).
6. **Tedarik süresi kısaysa stok DEĞİL, sipariş SIKLIĞI artar.** Ölçüldü: ODAK temin süresi
   ortalama **5,03 gün**, aşırı stoklu çeşitlerin **%96'sı 4-5 gün** temin süreli. 5 günde gelen
   mala 5 sezonluk stok yatırmak sermaye hatasıdır — küçük parti + sık sipariş.
7. **İade hakkı bilinmiyor → aşağı yönlü risk asimetrik.** `urn.alimIadeYok` tek değer taşıyor
   (bilgi yok). Vekil: tedarikçinin gözlenen 2 yıllık iade oranı. **Kitapdışında kesin alım
   varsay** — yanılırsan güvenli yönde yanılırsın. Kitapta konsinye/iade sorulur, varsayılmaz.
8. **Marja güvenme, yaşına bak.** Gerçekleşen marj maliyet yaşıyla şişiyor (<3 ay %24,4 →
   2+ yıl %63,0; enflasyon ile devir ayrıştırılamıyor). Sipariş kârlılığı **güncel maliyetle**
   kurulur, panelin geçmiş marjıyla değil.

## Karar Protokolü (sırayla, atlanmaz)

**0) Fact-force.** Kategori kitap mı kitapdışı mı? Sezon içi mi (Tem–Eki) dışı mı? Tedarikçi temin
süresi biliniyor mu? Ürün yeni mi (<1 yıl geçmiş → cold-start, zaman serisi yok)?

**1) Aday kohortu ÖLÇ** — dört havuz, paneldeki ölçütle AYNI SQL'den:

| Havuz | Ölçüt | Sipariş anlamı |
|---|---|---|
| **Kanıtlı talep + raf boş** | `SatisToplam >= 5` · üç raf 0 · merkezde var | **transfer**, sipariş DEĞİL (iç kaynak) |
| **Kanıtlı talep + merkez de boş** | satış ≥5 · toplam stok 0 · defter güvenilir | **birincil sipariş adayı** |
| **Sezon açığı** | sezonda satmış, mağazada rafı boş · merkezde yeterli | transfer; merkez yetmezse sipariş |
| **Yeni / cold-start** | `IlkGiris` yok veya <1 yıl | analoji (benzer SKU/kategori profili) + küçük test partisi |

Sipariş yalnız **stok yokken VEYA kapak altına düşerken** yazılır. Aşırı stok / ölü stok
havuzlarına sipariş YAZILMAZ — o taraf indirim/iade işidir.

**2) Talep hızını kur** (talep-tahmin-danisman haritası):
- düzgün talep (%8,1) → sezonlu ortalama · aralıklı (%91,9) → **Croston / SBA / TSB** beklenen
  değeri; ikisi de yoksa geçen dönem satışı **"alt sınır"** etiketiyle.
- kuru raf günü varsa yukarı düzelt ya da alt-sınır beyanını yaz.
- kanal ayır: merkez depo çıkışının **%72'si grup şirketine** — tüketici talebi değil, hıza katma.

**3) Miktarı hesapla:**

```
Kapak (adet)  = talep hızı × (tedarik süresi + gözden geçirme aralığı) + emniyet stoğu
Emniyet       = z(hizmet düzeyi) × sigma(talep, lead-time boyunca)   ← sigma ÖLÇÜLÜR
Sipariş       = Kapak − eldeki stok − yolda olan
Tavan         = kategori eşiği × sezon satışı        ← AŞILAMAZ (sözleşme 5)
Yuvarlama     = koli/MOQ katı; AŞAĞI yuvarla (tavana doğru yukarı değil)
```
Hizmet düzeyi kategoriye göre: sürekli raf malı (kalem/defter) yüksek (%95) · moda/hediyelik düşük
(%80-85; kalan mal indirime gider) · elektronik orta. **Tek global hizmet düzeyi yasak** — ölçülen
kategori devri 1,25 ile 5,95 arasında değişiyor.

**4) Satış planını YAZ** (taahhüt):
- `hedef: N adedin %X'i Y haftada`. Y = tedarik süresi değil **raf ömrü**: sezon ürünü sezon
  sonuna, sürekli mal 12 haftaya.
- Kıyas tabanı: aynı kategoride benzer ürünün gözlenen sell-through'u — ölç, varsayma.
- **Devir hedefi:** ölçülen devir Kitap 1,28 · Kırtasiye 1,25; sektör kıyası 3,0-4,0. Yeni
  siparişin ima ettiği devir **≥2,0** olmalı; altındaysa miktar fazladır.

**5) Çıkış planını YAZ** (tutmazsa): hafta Y'de sell-through hedefin altındaysa → (a) tedarikçi
iade hakkı varsa iade, (b) transfer (satan mağazaya), (c) kademeli indirim, (d) paket/kampanya.
Eylem + tarih + sorumlu yazılı. Çıkış planı olmayan sipariş = gelecekteki ölü stok.

## Kitapdışı ↔ Kitap farkları (karar değiştirir)

| | Kitapdışı (Kırtasiye/Oyuncak/Hediyelik/Elektronik/Spor) | Kitap |
|---|---|---|
| KDV | %20 → nakit döngüsü ağır | %0 |
| İade hakkı | genelde kesin alım → **aşağı yönlü risk sende** | yayınevi konsinye/iade olabilir → SOR |
| Sezon | okul sezonu (Tem–Eki) keskin; kalem/defter sürekli | sınav takvimi + yayın tarihi |
| Ölçülen devir | Kırtasiye 1,25 · Oyuncak/Hediyelik yavaş | Kitap 1,28 · Dergi 5,95 |
| Eşik (tavan) | Kırtasiye **2×** · diğer kitapdışı 3× | Hazırlık **8×** · diğer 3× |
| Moda riski | yüksek (Oyuncak/Hediyelik lisans/trend) → küçük parti, hızlı ölç | düşük ama uzun kuyruk |

## Oyuna Getirme (kendini denetle — TODO B-172)

- **Tek POS satışı** ölü stok kohortundan çıkarır (`PosAdet > 0` adet eşiği taşımıyor). Sipariş
  gerekçesi "satmış" ise **≥2 satış, farklı günlerde** iste.
- **Kategori değiştirmek** eşiği değiştirir (2× → 8×). Kategori sipariş gerekçesindeyse kartın
  kategori değişim tarihini kontrol et.
- **Az alıp görünmez kalmak:** aşırı stok TAM ölçülüyor (etiket değeri), stokta yokluk ALT SINIR →
  rasyonel alıcı az alır. Bu yüzden sipariş kararında **kayıp satış tahmini de yazılır**;
  görünmeyen tarafı görünür kılmak alıcının kendi savunmasıdır.

## Sınırlar
- **Alıcı boyutu veride YOK** (kararı kimin verdiği izli değil; yalnız `bkm.OneriSiparisTalep`).
  Bu skill kişiye atıf yapmaz — **ileriye dönük** miktar + taahhüt üretir.
- `bkm.OneriSiparisKtg3Ondeger` politika tablosu **İPTAL** (kullanıcı kararı 10.09.2026). Hedef
  gün-stok politikadan değil ölçümden gelir.
- Maliyet panelin `Tutar` alanında YOK (satış fiyatı) — kârlılık için güncel alış maliyeti ayrıca
  çekilir.
- **ERP'ye sipariş YAZMAZ.** Çıktı = öneri listesi (Excel/panel). Yazma yasağı: erp-write-policy.
- Merkez stok WMS anlık ve **hayalet stok** riski taşır (349 çeşit WMS'te var, defterde yok;
  kitapta yığılı) → "merkezde var, transfer et" kararı defterle karşılaştırılmadan verilmez.

## İlişkili
- `.claude/skills/talep-tahmin-danisman/SKILL.md` — talep hızı YÖNTEMİ (bu skill girdi alır).
- `.claude/skills/satinalma-danisman/SKILL.md` — kohort adaleti + perverse-incentive denetimi.
- `.claude/skills/veri-dogrula/SKILL.md` — çıkan miktar/rakam QA.
- `.claude/rules/olctum-mu-cikardim-mi.md` § EŞİK TÜRETME · `.claude/rules/erp-write-policy.md`
- `sema/metrics.yaml` — `asiri_stok_esigi_kategori_bazli` · `talep_deseni_aralikli` ·
  `devir_hizi_sektor_kiyasi` · `kayit_dogrulugu_ve_sansurlu_talep` · `iade_davranisi_vekili`
- `dashboard/Data/SatisAnaliziQueries.cs` — kohort ölçütlerinin tek kaynağı (aday liste oradan).
