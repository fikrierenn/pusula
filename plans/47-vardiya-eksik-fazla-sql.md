# 47 — Vardiya Eksik/Fazla Takip: hesabın SQL tarafına taşınması

**Durum:** Faz 1 adım 1-5 TAMAM (parite tuttu) · adım 6-7 açık · **Tier:** 3 · **Tarih:** 17.09.2026
**Karar sahibi:** Fikri Eren (GMY) — *"bkm tabloları olarak yapalım bir önek ile de isim
türetelim"* · *"şimdilik tabloları yerel sql tarafına mı kuralım, dev prod olursa
derinsis içine alırız"*

## Problem

`scripts/eksik_fazla_takip_raporu.py` hesabı Python'da yapıyor ve çıktı yalnız Excel.
Sonuçları panel okuyamıyor, geçmiş dönem saklanmıyor, elle girilen iki veri kümesi
(yönetici onaylı saatler · mağaza geri dönüşleri) Excel hücresinde yaşıyor ve dosya
yenilenince kayboluyor.

Ayrıca **PDKS geçmişe dönük düzeltiliyor** — ÖLÇÜLDÜ (17.09.2026): 15.09'da çekilmiş
dosyayla canlı PDKS arasında 5 kişi-gün farklı çıktı (SERHAT KELEŞ 02.09 → dosyada
19:24, canlıda 17:30). Yani ay kapanışında ödenen rakam sonradan yeniden
sorgulanarak bulunamaz; dondurulmuş bir kayıt gerekir.

## Kapsam

**Faz 1 (bu plan):** yerel SQL'de tablolar + SP + parite kapısı. Excel aynen çalışmaya
devam eder, sadece hesabı SP'den alır.
**Faz 2 (ayrı karar):** panelde yönetici giriş ekranı; ancak o zaman `Vrd_Onay` elle
dolmaya başlar.
**Faz 3 (ayrı karar):** dev→prod, aynı isimlerle `DerinSISBkm`'e taşıma.

## Nerede kurulacak

| | Dev (şimdi) | Prod (sonra) |
|---|---|---|
| Sunucu | `BT-FIKRI\SQLEXPRESS` (SQL 2022, 16.0) | `192.168.40.201` |
| Veritabanı | `BkmPanel` | `DerinSISBkm` |
| Şema | **`bkm`** | `bkm` |
| Nesne adları | `bkm.Vrd_*` | `bkm.Vrd_*` — **AYNI** |

⭐ Şema ve nesne adları dev ile prod'da **birebir aynı** tutulur. Terfi bir bağlantı
dizesi değişikliğidir, yeniden yazım değil. `dbo.Panel*` adlandırması bilinçli olarak
KULLANILMADI; kullanılsaydı prod'a geçerken her nesnenin adı değişecekti.

### Erişim ÖLÇÜLDÜ (varsayım değil)

Yerel örnekte `LIVE201 → 192.168.40.201` linked server zaten tanımlı ve **çift atlama
çalışıyor**: `OPENQUERY(LIVE201, '… OPENQUERY([PDKS], ''…'') …')` → 11.629 PDKS kaydı
döndü (01.09 sonrası). Yani vardiya planı da PDKS okutması da yerel SP'den erişilebilir;
hesap dev tarafında eksiksiz koşar.

## Nesneler

**Önek `Vrd_`** — ERP'nin kendi `BKM.vrd` şemasıyla aynı kısaltma, mevcut
`bkm.Fin_AyKapanis` deseniyle tutarlı.

### Hesap — yalnız SP yazar

| Nesne | Grain / içerik |
|---|---|
| `bkm.Vrd_KisiGun` | `(Kesim, Sube, SicilNo, Tarih)` · plan, kart, durum, brüt/net/eksik/fazla, ölçüm notu |
| `bkm.sp_Vrd_KisiGunDoldur @Bas,@Bit,@SayimBas` | kesimi siler + yeniden yazar (idempotent) |
| `bkm.Vrd_EksikFazla_vw` | okuma yüzü: `Vrd_KisiGun` üzerine `Vrd_Onay` bindirilmiş |

### Elle girilen — tek yazılan taraf

| Nesne | İçerik |
|---|---|
| `bkm.Vrd_Onay` | yönetici onaylı giriş/çıkış + evden çalışma/ek mesai |
| `bkm.Vrd_MagazaGeriDonus` | mağaza geri dönüşleri |

### Dondurulan

| Nesne | İçerik |
|---|---|
| `bkm.Vrd_Devir` | ay kapanış bakiyesi. Bir kez yazılır, sonra DOKUNULMAZ. |

### Parametreler — JSON kaynak, tabloya TEK YÖNLÜ senkron

| Nesne | İçerik |
|---|---|
| `bkm.Vrd_Sube` | şube → grup + çalışma saati |
| `bkm.Vrd_CalismaSaati` | grup×şube×bölüm → günlük saat |
| `bkm.Vrd_Mola` | net ve brüt mola eşikleri |
| `bkm.Vrd_KartBasmayan` | rapor dışı tutulan kadro |

`vardiya/vardiya_parametreleri.json` **düzenleme yüzeyi olarak kalır** (git'te izlenir,
değişiklik diff'te görünür, "OTOMATİK EKLENDİ" damgaları orada). Tablolar ondan
`--parametre-yukle` ile doldurulur; tabloya elle yazılmaz. Tek yön: JSON → tablo.

## Alternatifler (reddedildi)

1. **Hiç tablo kurma, her şey view/SP ile anlık hesaplansın.** Reddedildi: elle girilen
   iki veri kümesinin (onay, geri dönüş) hiçbir sorgudan çıkma yolu yok ve ay kapanış
   bakiyesi dondurulamaz — PDKS geriye dönük değiştiği ölçüldü.
2. **Doğrudan prod'a (`DerinSISBkm`) kurma.** Reddedildi (GMY kararı): önce dev'de
   koşsun, parite kanıtlansın, sonra taşınsın.
3. **Parametreleri de tabloya taşıyıp JSON'u bırakma.** Reddedildi: politika değişikliği
   git diff'inde görünmez olurdu; JSON aynı gün bu amaçla kurulmuştu.
4. **`dbo.Panel*` adlandırması** (panelin mevcut deseni). Reddedildi: prod'a terfi
   ederken her nesnenin adı değişirdi.

## Riskler

| Risk | Önlem |
|---|---|
| **İki uygulamanın sessizce ayrışması** (Python ↔ SP) | Parite kapısı, aşağıda. Sıfır fark çıkmadan Python emekliye ayrılmaz. |
| Çift atlama linked server yavaş/kırılgan | Ölçüldü, çalışıyor. SP'de `--timeout` ve hata sınıflandırması; koşamazsa **patlar**, boş yazmaz. |
| Dev tabloları prod sanılır | Tablo adları aynı olduğu için karışabilir. `bkm.Vrd_KisiGun.Kaynak` kolonu sunucu adını yazar. |
| Parametre tablosu elle değiştirilir, JSON ile ayrışır | Yükleyici truncate+reload yapar; tabloda `JsonSurum` damgası tutulur. |

## Parite kapısı (bitiş ölçütü)

SP yazıldığı gün koşar:

```
SP çıktısı ↔ Python çıktısı · 6.113 kişi-gün × 15 kolon → fark 0
```

Bugün kaynak Excel dosyasına karşı aynı yöntem uygulandı (73.095 hücrede 256 fark,
hepsi tek tek açıklandı). **Fark 0 çıkmadan Faz 1 kapanmaz.**

Ayrıca kırılabilirlik kanıtı: SP'nin tolerans değeri 10→5 dk yapılınca parite testinin
KIRMIZI verdiği görülür, sonra geri alınır. Kırılabildiği kanıtlanmamış test, test değildir.

## Adımlar

1. ✅ `.claude/rules/erp-write-policy.md` — izin listesi + dev/prod ayrımı.
2. ✅ `sorgular/2026-09-17-vardiya-tablo-kur.sql` — idempotent DDL. **7 tablo**
   kuruldu; `Vrd_KartBasmayan` GMY itirazıyla iptal (hiçbir hesapta kullanılmıyor).
3. ✅ Parametre yükleyici: `scripts/vardiya_parametre_yukle.py` (JSON → tablo, tek yön).
   Aracın mola tablosu da parametreye alındı (`mola_arac_tablosu` → `Vrd_Mola` tip `arac`).
4. ✅ `bkm.sp_Vrd_KisiGunDoldur` — çift atlamalı OPENQUERY, koşum 4,6-5,6 sn.
5. ✅ `tools/vardiya_parite.py` — **6.113 kişi-gün × 16 hesap kolonu → 0 fark**.
   Kırılabilirlik kanıtlandı (tolerans 10→5 dk → 9.191 hücre KIRIK → geri alındı).
6. Excel emitter'ı SP'den okuyacak şekilde çevir (Python hesabı devre dışı, kod DURUR).
7. Journal + sema kaydı.

## Geri alma

Faz 1 tamamen dev'de; geri alma `DROP SCHEMA bkm` (yerel `BkmPanel`) ve Python
emitter'ının olduğu gibi çalışmaya devam etmesi. Prod'a hiçbir şey yazılmaz.
