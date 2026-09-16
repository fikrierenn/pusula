# Defter Grubu Stok Yeterliliği — Geçen Yıl / Bu Yıl Kontrol Raporu

**Soru (GMY):** Defter grubunda stok seviyesi yeterli mi? Geçen yılla karşılaştırmalı kontrol.
**Kesim:** 14.09.2026 (okulun ilk günü)
**Evren:** `bkm.UrunBilgi.Kat1 = 'Defterler'` — 11.554 çeşit, hepsi stok ürünü (`urnTip=0`)
**Kapsam:** FSM (1) · Özlüce (4477) · İst.Yolu (4478) + merkez depo (WMS)
**Satış tabanı:** `irsHrk` ehTip 100 − 101 + 4 − 5 (kanonik şube formülü), KDV hariç net
**Üretim:** `scripts/defter_stok_yeterlilik_excel.py` · SQL arşivi: `sorgular/2026-09-14-defter-stok-yeterlilik-kontrol.sql`
**Excel:** `ciktilar/defter-stok-yeterlilik-2026-09-14.xlsx` (açık listesi 1.584 satır + atıl stok)

---

## 0. Önce takvim: ay bazlı kıyas yönü TERS gösteriyor

Okul 2025'te **8 Eylül**, 2026'da **14 Eylül** açıldı. Altı gün kayma var.

| Ölçüm | 2025 | 2026 | Değişim |
|---|--:|--:|--:|
| Ağustos ayı (takvim) | 30.018 adet | 23.943 adet | **−%20,2** |
| Okula göre hizalı son 45 gün | 67.294 adet | 74.684 adet | **+%11,0** |
| Aynı pencere, ciro | 5,69M ₺ | 7,87M ₺ | +%38,3 |

Takvime bakan "defter satışı %20 düştü" der. Doğrusu **%11 arttı**. Aşağıdaki
her kıyas okul gününe hizalı yapıldı. **[ÖLÇÜLDÜ]**

---

## 1. Kısa cevap

**Grup toplamında stok yeterli. Ama sezona geçen yıldan daha ince girdik ve
açıkla fazla aynı anda duruyor.**

| Soru | Cevap |
|---|---|
| Toplam stok sezonu çıkarır mı? | **Evet.** Mağazada 176.231 + depoda 483.100 adet. Beklenen kalan sezon 68.645 adet. Kapak **2,57 kat**. |
| Sezona geçen yıl kadar hazır mı girdik? | **Hayır.** Giriş stoğu %9,5 azaldı, talep %11 arttı. |
| Raf boşluğu geçen yıldan kötü mü? | **Hayır, aynı.** Kuru giriş oranı %18,7 → %19,5. |
| Asıl sorun ne? | **Dağıtım.** 24.659 adet açık ile 66.487 adet satmayan stok yan yana. |

---

## 2. Sezona ne kadar stokla girdik (31 Ağustos)

| Mağaza | 2025 giriş | 2026 giriş | Değişim |
|---|--:|--:|--:|
| FSM | 63.712 | 58.888 | −%7,6 |
| Özlüce | 70.583 | 64.514 | −%8,6 |
| İst.Yolu | 58.212 | 50.762 | **−%12,8** |
| **Toplam** | **192.507** | **174.164** | **−%9,5** |

Çeşit ise arttı: 12.484 → 13.351 (+%6,9).

**Sonuç:** çeşit başına derinlik **15,4 → 13,0 adet**, yani −%15,6. Daha çok
model, her modelden daha az adet. **[ÖLÇÜLDÜ]**

### Giriş kapağı

Giriş stoğunu o sezonun talebine bölünce:

| | Giriş stoğu | Sezon talebi | Kapak |
|---|--:|--:|--:|
| 2025 (gerçekleşen) | 192.507 | 123.469 | **1,56** |
| 2026 (beklenen) | 174.164 | 143.341 | **1,22** |

Giriş kapağı **%22 daraldı**. İst.Yolu 2026'da 0,92 ile sezonu kendi stoğuyla
çıkarmıyor — depodan besleme zorunlu. **[ÖLÇÜLDÜ + ÇIKARIM]** (2026 talebi
geçen yılın aynı SKU satışı × 1,11 ile kurulmuştur.)

---

## 3. Bugün itibarıyla kapak

| Mağaza | Beklenen kalan sezon | Bugün stok | Kapak |
|---|--:|--:|--:|
| FSM | 21.143 | 54.622 | 2,58 |
| Özlüce | 25.203 | 69.605 | 2,76 |
| İst.Yolu | 22.299 | 52.004 | 2,33 |
| **Toplam** | **68.645** | **176.231** | **2,57** |

Arkada merkez depoda **483.100 adet** daha var (rafta 456.337, girişte 26.763).

**Büyüme varsayımına duyarlılık:** çarpan 1,00 olsa kapak 2,85 · 1,26 olsa 2,26 ·
1,50 olsa 1,90. Hangi varsayımla bakılırsa bakılsın grup toplamı dar değil.

---

## 4. Raf boşluğu geçen yıldan kötüleşmedi

31 Ağustos'ta stoğu sıfır olup önceki yıl o mağazada satmış olan SKU oranı:

| | Kuru hücre | Talepli hücre | Oran |
|---|--:|--:|--:|
| 2025 | 973 | 5.190 | %18,7 |
| 2026 | 1.239 | 6.343 | %19,5 |

Fark yok. **[ÖLÇÜLDÜ]**

> **Bir sahte bulgu burada elendi.** İlk kurguda 2025 için aynı-yıl, 2026 için
> önceki-yıl talebi kullanılmıştı; ölçüm "kuru çeşit 336 → 1.239, **3,7 kat**"
> diye alarm veriyordu. Metrik simetrik hâle getirilince oran sabit çıktı.
> Ayrıca 1.239 kuru hücrenin yalnız 284'ünde depoda stok var — gerisi büyük
> ölçüde bırakılmış tasarım, stok hatası değil.

---

## 5. Asıl bulgu: açık ile fazla yan yana duruyor

SKU-mağaza düzeyinde bugünkü stok, beklenen kalan sezonla karşılaştırıldı.
Sadece **canlı** ürünler sayıldı (depoda stoğu var ya da bu yıl satmış).

| | Hücre | Adet | Maliyet |
|---|--:|--:|--:|
| **Açık** (stok < beklenen) | 1.584 | 24.659 | 1,44M ₺ |
| — depodan tamamen kapanır | 764 | — | — |
| — kısmi transfer | 94 | — | — |
| — **satın alma gerekir** | **726** | — | — |
| **Zirvede hiç satmayan stok** | 9.094 | **66.487** | 3,13M ₺ |

Son 45 günün zirvesinde hiç satmayan stok, mağaza stoğunun **%37,9'u**:
FSM %48,8 · Özlüce %37,3 · İst.Yolu %26,8.

Aynı grupta 24.659 adet eksik, 66.487 adet fazla. Bu bir **hacim sorunu değil,
yerleştirme sorunu**. **[ÖLÇÜLDÜ]**

### Açık nerede yoğunlaşıyor (ilk 300 kayıt)

| Alt grup | Açık ₺ | | Marka | Açık ₺ |
|---|--:|---|---|--:|
| Kareli Defter | 349.705 | | Keskin Color | 565.369 |
| Çizgili Defter | 310.383 | | Gıpta | 294.298 |
| Resim Defteri ve Blokları | 184.018 | | Arı Yayıncılık | 89.897 |
| Butik Defterler | 99.483 | | Mynote | 39.768 |

İki marka (Keskin Color + Gıpta) ilk 300 açığın **%76'sını** taşıyor.

### Bugün transferle kapanabilecek örnekler

| Mağaza | Ürün | Bugün stok | Beklenen | Depoda |
|---|---|--:|--:|--:|
| İst.Yolu | Keskin Color Free Platinum A4 60 Yp. (154490) | **0** | 169 | 744 |
| Özlüce | Gıpta Pastoral Çizgili Spiralli PP (241761) | 153 | 440 | 1.862 |
| İst.Yolu | Keskin Color Cool Kareli Spiralli (75609) | 28 | 269 | 939 |
| İst.Yolu | Keskin A4 6+3x25 Ayraçlı PP (1604125) | 3 | 36 | 180 |

Satın alma gerektirenlerin başında **Resimino 35x50 Resim Defteri (442805)**
geliyor: üç mağazada toplam 633 adet açık, depoda stok yok.

---

## 6. Ne yapılmalı

1. **Transfer (bugün):** 858 SKU-mağaza hücresi depodan beslenebilir — ~12.180 adet.
   İst.Yolu önce, kapağı en dar olan o.
2. **Satın alma (bu hafta):** 726 hücrede depo da boş. Keskin Color ve Gıpta ile
   önce bu iki markanın kareli/çizgili spiralli hattı konuşulmalı.
3. **Atıl stok (sezon sonrası):** 66.487 adet / 3,13M ₺ zirvede hiç satmadı.
   FSM'de her iki adetten biri bu grupta. Sezon kapanınca iade/indirim/transfer kararı.
4. **Gelecek sezon:** çeşit %6,9 arttı, derinlik %15,6 düştü. Çeşit genişletmenin
   derinliği yediği ölçülüyor; 2027 alımında çeşit sayısı bir karar olarak konuşulmalı.

---

## 7. Bu raporun sınırları

- **Kayıp satış alt sınırdır.** Stok bitince satış kesilir, o yüzden geçen yılın
  talebi gerçek talebin altındadır (sağdan sansürlü ölçüm). Literatürde kabul
  gören düzeltme EM tabanlı sansürlü-talep tahminidir; uygulanmadı.
- **SKU düzeyinde tek yıldan tahmin gürültülüdür.** Defter tasarımı yıllık döner.
  Liste bir **öncelik sırasıdır**, sipariş emri değil.
- **Merkez depo geçmişi yok.** WMS ay-sonu snapshot'ı yalnız 31.08.2026 için var;
  deponun geçen yıl ne taşıdığı **ölçülemedi**.
- **Maliyet sabit fiyatla.** Her iki yıla bugünün son alış fiyatı uygulandı; ₺
  karşılaştırması değil, karışım karşılaştırmasıdır.
- **Bugün kısmi.** Kasa satışı ERP'ye saatte bir akar; 14.09 verisi eksiktir.
  Bu yüzden 2026'nın sezon (T+0 sonrası) satışı hiç kıyaslanmadı.
- **Kapsam seçimi.** Defterde dokuz mekan var; bu rapor üç mağaza + merkez depoyu
  kapsar. İade Deposu (4480) gibi mekanlar hariçtir.

---

## 8. Formüllü Excel (ürün detaylı) — GMY 2. tur isteği

_"ürün detaylı, senin çıkarımların değil de her şey Excel'de görünecek şekilde
formüllü olarak hazırlar mısın"_ → `ciktilar/defterler-stok-yeterlilik-formullu-2026-09-14.xlsx`

**Tasarım:** Python yalnız **ölçülen 22 ham kolonu** çeker. Tüm türetmeler (14 kolon)
Excel **formülü** olarak yazılı ve `Parametreler!B4`'teki büyüme çarpanına bağlı.
`Özet`, `Mağaza Özet`, `Alt Grup / Marka / Tedarikçi Kırılımı` sayfalarındaki
**her rakam SUMIFS/SUMPRODUCT ile Ürün Detay'dan gelir** — sabit yazılmış sayı yok.
Çarpanı 1,00 veya 1,50 yapın, bütün dosya yeniden hesaplanır.

| Sayfa | İçerik |
|---|---|
| Parametreler | Büyüme çarpanı (sarı hücre), çıpalar, ölçülen pencereler, kesim anı, kaynaklar |
| Özet | 5 blok — giriş stoğu · hizalı satış · bugün kapak · açık · atıl. Hepsi formül |
| Ürün Detay | 15.491 satır (mağaza × ürün) · 22 ölçüm + 14 formül kolonu · filtreli |
| Mağaza Özet | Üç şube + toplam, 17 kolon, hepsi SUMIFS |
| Alt Grup / Marka / Tedarikçi | Aynı metrikler kırılımlı |
| Okuma Kılavuzu | 36 kolonun tanımı (ÖLÇÜM / FORMÜL etiketli) + 8 sınır maddesi |

### Bir tanım hatası bu turda düzeltildi

7. bölüme kadarki "canlı" testi ürünün **herhangi bir şubede** satıp satmadığına
bakıyordu. Excel'e ilk taşındığında kolon **şube bazlı** olduğu için test daraldı:
"bu şubede satmamış" → "bırakılmış" sayıldı ve açık sessizce küçüldü
(**1.584 → 1.318 satır**). Düzeltme: `BY ön-sezon TÜM ŞUBE` ham kolonu eklendi,
`Canlı mı` formülü onu kullanıyor.

### Doğrulama ve doğrulanmayan

- **Formül referansları denetlendi:** `python scripts/defter_stok_yeterlilik_excel.py
  --denetle <xlsx>` — 14 formül kolonunun her biri beklenen başlıklara bakıyor mu,
  2.426 özet formülünün aralığı tüm satırları kapsıyor mu. Çıkış 0 geçti · 1 KIRIK ·
  2 KOŞAMADI. **Kırılabilirliği kanıtlandı:** bir kolon harfi kaydırıldı → KIRIK
  (yanlış referansı konumuyla yazdı); bir SUMIFS aralığı 1000. satırda kesildi →
  KIRIK ("EKSİK SATIR — sessiz alt-tahmin"). İkisi de geri alındı.
- **Excel'in kendi hesabı bu ortamda KOŞMADI** — Excel COM açılamadı
  (`Workbooks.Open` COMException), LibreOffice kurulu değil. Denetim komutu bu yüzden
  "formüllerin vermesi gereken değerleri" dosyanın ham kolonlarından bağımsız
  yeniden hesaplayıp yazıyor; dosya açılınca `Özet` sayfası bunlarla aynı olmalı.
- **Ölçüm kolonları birebir tutuyor:** giriş stoğu 2025/2026, hizalı ön-sezon adedi,
  geçen yıl sezon tabanı — sqlcli ile yapılan bağımsız ölçümle **%0,00** fark.
- **Canlı veri kayması:** mağaza stoğu ilk ölçümde 176.231, Excel kesiminde 174.643
  (−%0,90). Okulun ilk günü, stok saat saat düşüyor. `Parametreler!B15` kesim anını
  **saatiyle** yazıyor — bu dosya bir fotoğraftır.

### Excel kesimindeki değerler (büyüme 1,11)

| | |
|---|--:|
| Beklenen kalan sezon | 68.645 adet |
| Bugün mağaza stoğu | 174.643 adet |
| Mağaza kapağı | 2,54× |
| Açık satır (canlı) | 1.612 |
| Açık adet / maliyeti | 25.851 / 1.470.105 ₺ |
| Depodan karşılanır / satın alma | 12.550 / 13.301 adet |
| Bırakılmış görünen açık satır | 630 |
| Zirvede satmayan stok / maliyeti | 66.834 adet / 3.149.699 ₺ |
