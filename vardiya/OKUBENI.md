# Vardiya — Eksik ve Fazla Takip Raporu

Bu klasör raporun **tüm varlıklarını** taşır. Kod `scripts/` altındadır.

## Dosyalar

| Dosya | Ne |
|---|---|
| `vardiya_parametreleri.json` | **Tanım/parametre tabloları.** Excel sayfaları BU DOSYADAN üretilir; Excel'de elle değiştirilen parametre bir sonraki üretimde kaybolur. |
| `BKMKİTAP Eksik ve Fazla Takip Raporu.xlsx` | Elle kurulan **kaynak** dosya. Yalnız iki sayfası kullanılıyor: `Mağaza Geri Dönüşleri` (yöneticinin elle bildirdiği saat düzeltmeleri) ve `<Ay> Devir Saatler` (önceki ayın kapanış bakiyesi). İkisi de veriden türetilemez. |
| `BKMKİTAP Eksik ve Fazla Takip Raporu - GG.AA.YYYY.xlsx` | Üretilen rapor. Dosya adındaki tarih kapsamın **son günüdür**. |

## Üretim

```bash
python scripts/eksik_fazla_takip_raporu.py --bas 31.08.2026 --bit 16.09.2026 --sayim-bas 01.09.2026
```

- `--bas` : verinin çekileceği ilk gün. **Haftanın Pazartesi'sinden başlat** — haftalık
  izin primi "7 gün çalıştı" şartını arar, hafta yarım kalırsa prim hiç çıkmaz.
- `--sayim-bas` : Eksik/Fazla toplamına giren ilk gün. Öncesindeki günler raporda
  **durur** (hafta bütünlüğü için) ama toplama katılmaz — önceki ayın devrinde
  sayıldıkları için. `AO "Ölçüm Notu"` kolonunda satır satır yazılır.
- `--bit` : son gün.

Eylül kapanışı: `--bas 31.08.2026 --bit 30.09.2026 --sayim-bas 01.09.2026`
Ekim: `--bas 28.09.2026 --bit 31.10.2026 --sayim-bas 01.10.2026` (39. hafta Pazartesi 28.09).

## Elle doldurulan üç kolon

| Kolon | Ne zaman yazılır |
|---|---|
| `V` / `W` Yönetici Onaylı Giriş/Çıkış | Yönetici saati düzeltince. Boşken formül toleranslı saate düşer; değer girilince zincir kendiliğinden yeniden hesaplanır. |
| `AK` Evden Çalışma veya Ek Mesai | **Yalnız gerçek evden çalışma / ayrıca onaylanmış ek mesai.** Gece mesaisi (gün dönümü) ARTIK OTOMATİK — buraya yazılırsa `AF = …+AI+AK` mesaiyi iki kez sayar. |

## Bilinmesi gerekenler

- **Gün dönümü otomatik.** Gece mesaisine kalıp ertesi sabah çıkanda çıkış girişten
  küçük olur; hesap +24 saatle yapılır, gösterim gün-içi saat kalır (00:30) ve düzeltme
  `AO` kolonunda beyan edilir. Brüt 16 saati geçerse "ŞÜPHELİ — çıkış okutması unutulmuş
  olabilir" damgası düşer.
- **Parametre dosyasına otomatik kayıt eklenebilir.** `Çalışma Saatleri`nde karşılığı
  olmayan grup×şube×bölüm çıkarsa şube varsayılanıyla eklenir ve `"not"` alanına
  *"OTOMATİK EKLENDİ — İK onaylamalı"* yazılır. Bu kayıtlara gerçek saati İK yazmalı.
- **Zirve'de kaydı olmayan personel** `Aktif/Pasif` kolonunda "Pasif" görünür; üretim
  sırasında isim listesi ekrana yazılır. Rapor hatası değil, İK kayıt boşluğudur.
- **Doğrulama kapısı:** her üretimden sonra Excel'de yeniden hesaplanır; beklenen
  sonuç **0 formül hatası** ve ana sayfa = `Özet Y` = `Haftalık + Devir` (üç bağımsız
  yol, fark 0,0000).
