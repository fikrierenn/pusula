# Kapı Sayıcı Pilot — İş Gerekçesi (FSM, 60 gün)

**Tarih:** 08.06.2026 · **Pilot:** FSM (Bursa Nilüfer) · **Dönem:** 08.04–07.06.2026
**Karar:** Özlüce + İst.Yolu'na kapı sayıcı yatırımı yapılmalı mı?

> **Tek cümlelik sonuç:** FSM'de kapı sayıcı, yalnızca *kötü dönüşüm günlerini ortalamaya çekerek* **yıllık ~3 milyon ₺** görünmez kayıp tespit etti. 3 mağazaya yayıldığında bu fırsat katlanır; sayıcı maliyeti yanında ROI ezici.

---

## 1. Pilot ne gösterdi (60 gün, FSM)

| Metrik | Değer |
|---|---|
| Toplam giriş | 114.436 ziyaretçi |
| Toplam fiş | 58.866 |
| Toplam ciro | 31,8M ₺ |
| **Ortalama dönüşüm** | **%51,5** (medyan %51,1) |
| Dönüşüm bandı | %46,4 – %60,4 (std 2,8) |

Dönüşüm = **Fiş / Giriş** — mağazaya giren her 2 kişiden ~1'i alışveriş yapıyor.

## 2. Asıl değer: GÖRÜNMEZ kaybı görünür yaptı

Kapı sayıcı olmadan **"ciro neden düştü?"** sorusu cevapsızdı — trafik mi azaldı, dönüşüm mü bozuldu bilinmiyordu. Sayıcı bu ayrımı yapıyor:

- **En kötü gün: 12.05 Salı %46,4** — trafik NORMAL (1.823 giriş) ama dönüşüm dipte. Yani sorun trafik değil **operasyon** (personel/stok/deneyim). Bu gün ciro düşük çıktı, "az müşteri geldi" sanılırdı — **yanlış**. Sayıcı gerçek sebebi gösterdi.
- **En iyi gün: 08.04 Çarşamba %60,4** — aynı mağaza, aynı ürün, %14 puan daha yüksek dönüşüm. Fark = uygulanabilir operasyon kalitesi.

> **Bu ayrım (trafik mi / dönüşüm mü) yalnızca kapı sayıcıyla mümkün.** POS tek başına "ciro düştü" der, sebebini söyleyemez.

## 3. Parasal fırsat (sadece FSM)

Alt-medyan günler yalnızca **medyana** (%51,1) çekilse:
- **+500.390 ₺ / 60 gün** = günlük ort. **8.340 ₺** kayıp
- **Yıllık ~3,04M ₺** (sadece FSM, sadece tutarlılık — en iyi güne çekmek değil)

En iyi güne (%60) yaklaşma hedeflenirse rakam **kat kat** büyür.

## 4. Trafik artışı doğrudan ciroya döner (kapasite var)

**Trafik ↔ Dönüşüm korelasyonu: −0,09** (≈ sıfır). Yüksek trafikli günlerde (Cmt 2.402 giriş) dönüşüm düşmüyor → **FSM'de personel kapasitesi yeterli, kuyruk/yetişememe sorunu yok.**

Sonuç: vitrin/kampanya/pazarlama ile trafiği artırmak dönüşümü bozmadan **doğrudan ciroya** dönüşür. Bu güven de ancak sayıcıyla kanıtlanır.

**Haftagünü:** Cmt/Pzr en yüksek trafik (2.402/2.184) ve ciro (706K/640K) — dönüşüm korunuyor. Hafta sonu yatırımı (personel/stok) en yüksek getiri.

## 5. Çapraz-mağaza körlüğü = yanlış yatırım riski

Oturum verisinden (SPLH, satış):
- **Özlüce** en verimli: 3.786 ₺/çalışılan saat, en yüksek ciro. **Ama bu yüksek trafikten mi (lokasyon) yüksek dönüşümden mi (icra) geliyor — BİLİNMİYOR.**
- **İst.Yolu** zayıf: WoW −%18,8, fiş/saat 4,37 (en düşük). **Sorun trafik mi (pazarlama/lokasyon) yoksa dönüşüm mü (operasyon)? — BİLİNMİYOR.**

Bu iki soru, **doğru yatırım yönünü** belirler (Özlüce'yi büyüt? İst.Yolu'nu düzelt? hangisini nasıl?). Sayıcı olmadan kör karar veriliyor. **Cironun ~%39'u (fiziksel) için yarısı ölçülemiyor.**

## 6. ROI

| | |
|---|---|
| Kapı sayıcı maliyeti | ~birkaç bin ₺ / mağaza (tek seferlik) |
| FSM tek başına yıllık fırsat | ~3,04M ₺ |
| Geri ödeme süresi | **günler** |

## 7. Öneri

1. **Özlüce + İst.Yolu'na kapı sayıcı kur** — körlüğü kaldır, 3 mağaza dönüşümünü kıyasla.
2. Trafiği **SQL tabloya** yükle (`bkm.MagazaTrafik`) → dönüşüm Pazartesi brief'ine kalıcı KPI kolonu.
3. **Düşük-dönüşüm günleri** için kök-neden protokolü (personel/stok/deneyim) — her puan = para.
4. Saat-bazlı sayıcı verisi → vardiya planını trafik pikine (Cmt/Pzr, gün içi) göre optimize et.

---

**Kaynak:** `scripts/kapi_sayici_analiz.py` (FSM trafik `sayiyo/` + EncoreMerkez POS). Tekrar üretilebilir.
**Sonraki veri:** Özlüce/İst.Yolu sayıcısı geldiğinde script çoklu-mağaza genişler.
