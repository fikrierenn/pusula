# BKM Kitap — DerinSIS Semantik Katmanı

> **Kaynak:** Fikri'nin `D:\Belgelerim\sql` klasöründeki ~100 SQL'i + canlı şema doğrulaması (192.168.40.201).
> **Kapsam:** Sadece **şu anda kullanılan** sistemler. Eski Logo (LG_220_*), Vega Cafe, GOPLUS, eski WMSBKM çıkarıldı. Joker AYRI DB ama `odakjoker` Linked Server üzerinden erişiliyor.
> **Son güncelleme:** 15 Nisan 2026

---

## 0. Aktif Veritabanları (192.168.40.201)

| DB | Amaç |
|---|---|
| **DerinSISBkm** | Ana ERP — perakende, B2B, depo (WMS), muhasebe, fatura, sipariş |
| DerinSISBkmWeb | Web sitesi (e-ticaret) operasyonel verileri |
| DerinSISBkmCrm | CRM (kampanya, müşteri segmenti) |
| BKM, BKMDATA | Yardımcı veri ambarları |
| BKMMaliyet | Maliyet hesaplama |
| BkmKargo | Kargo entegrasyonu |
| ENTEGRATION | Sistem entegrasyon staging |
| KIBO | Bilinmiyor (gerekirse araştırılır) |
| **Joker** (Linked Server: `odakjoker`) | Ayrı DB — DerinSIS içinde değil. 4-part naming ile erişilir: `odakjoker.[dbname].dbo.[table]` |

> **WMS:** AYRI DB DEĞİL — DerinSISBkm içinde `depo.*` şemasında.
> **Joker:** AYRI DB — `odakjoker` Linked Server üzerinden erişiliyor. DerinSISBkm.dbo.JOKER_* tabloları yerel snapshot/cache (entegrasyon job'ı dolduruyor); kaynak gerçeği linked server'da.

---

## 1. Şema Haritası (DerinSISBkm)

| Şema | İçerik |
|---|---|
| `dbo` | Ana tablolar (urn, fat, irs, sip, frm, posOzet*, JOKER_* lokal cache) |
| `bkm` | Türetilmiş analiz view'ları/tabloları (Urunbilgi, MagazaSatis, ENVANTER_RAPORU, NetDepoStok…) |
| `depo` | WMS (paletTnm, paletUrnTnm, adres, SatisLog) |
| `ent` | Entegrasyon view/tablolar (Joker stok dağılımı vb.) |
| `mhs` | Muhasebe entegrasyon (mhsFis, mhsEntPos…) |
| `earsv` | e-Arşiv |
| `edftr` | e-Defter (okcSatisDetay_vw) |
| `web` | Web sipariş (posHspWeb, posHspDsy) |
| `b2b` | B2B view'ları (urnSatis_vw) |
| `sil` | Eski/silinmiş tablolar — KULLANMA |

---

## 2. Tablo & View Sözlüğü

### A. Ürün

| Tablo | Amaç | Anahtar Kolonlar |
|---|---|---|
| `dbo.urn` | Ürün ana tablosu | stkID (PK), stkKod, stkAd, urnKtgrID, urnKtgr1ID, urnKtgr2ID, urnTip (0=normal), urnMrkID |
| `dbo.urnKategori_vw` | Kategori hiyerarşi view | stkID, k0Ad, k1Ad, urnKtgr2ID |
| `dbo.urnKtgr2` | Kategori3 isimleri | ktgrID, **ktgrAd** (⚠️ ktgr2Ad değil) |
| `dbo.urnMrk` | Marka | mrkID, mrkAd |
| `dbo.urnBrkd` | Barkod | urnBrkdStkID, urnBarkod, urnBrkdOnce (0=ana barkod) |
| **`bkm.Urunbilgi`** | **Ürün full info view (en pratik)** | stkID, stkKod, BarkodAna, stkAd, mrkAd, KatAna, Kat1, Kat2, Kat3, SatisFiyat, SonAlis, Kategori2, Kategori3, urnDurum, urnTip, AnaTedarikciId, frmID/FirmaAd |

### B. Mekan

| Tablo | Amaç | Kolonlar |
|---|---|---|
| `dbo.mekan_vw` | Mağaza/depo listesi | mekanID, mekanAd, mekanTip |

**Bilinen mekanID'ler:**
- 1 = FSM
- 4477 = Özlüce
- 4478 = İst.Yolu
- (Demirci, İhsaniye, Balat var ama mekanID'leri sorgulanmadı; özel şube paketlerinde geçer)
- "WMS Depo" → mekan_vw'da değil, `depo.*` üzerinden

### C. Stok Hareketleri — İki Farklı Tablo

DerinSIS'te stok verisi **iki katmanda** tutuluyor:

| Tablo | Anlam | Kullanım |
|---|---|---|
| **`dbo.irs` + `dbo.irsAyr`** | **Evrak başlık + satır** (belge seviyesi) | İndirim, KDV, sira bazlı detay gerektiğinde |
| **`dbo.irsHrk`** | **Hareket** (stok seviyesi, birleşik) | Toplam ciro/adet/maliyet raporu için |

**İlişki:**
- Aynı `ehID` (evrak) altında `irsAyr`'da **ehSira** ile satırlar var (aynı ürün birden çok satırda olabilir — farklı fiyat/indirim kademeleri için).
- `irsHrk`'da aynı ürün **tek satıra birleşir** (ehID + ehstkID + ehTip bazında gruplanmış).
- Tutar/adet toplamı aynı, satır sayısı farklı olabilir.

**Kolonlar:**

| Tablo | Kolon | Anlam |
|---|---|---|
| `irs` | eID, eTip, eMekan, eTarihS, eFirma, onay, eGC | Evrak başlığı |
| `irsAyr` | ehID, ehSira, ehStkID, **ehAdet**, **ehTutar** (KDV hariç brüt), **ehIndirim**, ehTutarKDV (KDV tutarı), ehKDV (KDV oranı kodu), ehi1..ehi5, ehiT6 (indirim yüzdesi katmanları), ehMaliyet | Evrak satırı |
| `irsHrk` | ehID, ehstkID, ehMekan, **ehTrhS**, **ehAdetN**, **ehTutarN** (= ehTutar − ehIndirim), ehMlyt, ehAltDepo, hrkID, **ehTip** | Hareket |

**Önemli formül:**
```
irsHrk.ehTutarN = irsAyr.ehTutar − irsAyr.ehIndirim
```
(Tüm tutarlar **KDV hariç**. KDV tutarı ayrı kolonda: `irsAyr.ehTutarKDV`.)

**İşaret kuralı:**
- `ehAdetN` çıkışta negatif (satış, iade vs)
- `ehTutarN` daima pozitif → net ciro = `SUM(satış) − SUM(iade)`

**Tarih kolonları — anlam ve kullanım:**

| Kolon | Tablo | Anlam |
|---|---|---|
| `eTarihS` | irs | **İş tarihi (sevk/satış efektif tarihi)** — stok ve ciro bu tarihe göre yazılır |
| `eTarih` | irs | **Belge tarihi** (fatura/sipariş kağıt tarihi). Satış tiplerinde `eTarihS` ile aynı; alım/sipariş (eTip 13, 10, 8, 3, 98) tiplerinde farklılaşabilir |
| `oTarih` | irs | İlk oluşturma anı (değişmez) |
| `kTarih` | irs | Son kayıt/güncelleme anı (evrak düzeltilirse ilerler) |
| **`ehTrhS`** | **irsHrk** | **İş tarihi** — `irs.eTarihS` ile **HER ZAMAN EŞİT** (tüm tipler için doğrulandı). Stok raporlarının ana tarihi. |
| `hrkTarih` | irsHrk | Hareket satırının fiziksel yazılma/güncelleme anı (audit log). Geriye dönük yazımda `ehTrhS < hrkTarih`. |

**Rapor kuralı:**

| Amaç | Kullanılacak tarih |
|---|---|
| Stok bakiyesi, envanter, ciro, satış/kâr raporları | **`ehTrhS`** (= `eTarihS`) — daima |
| Belge/fatura tarihi gereken yerler (KDV beyanı vs) | `eTarih` |
| "X tarihinde sistemde ne görünüyordu" (audit, forensics) | `hrkTarih <= X` filtresi |
| Ay kapanış sonrası geç gelen hareketleri izleme (delta rapor) | `hrkTarih > kapanış_tarihi AND ehTrhS <= kapanış_tarihi` |

**Felsefe:** `ehTrhS` = **iş gerçekliği** (ne oldu), `hrkTarih` = **kayıt logu** (ne zaman yazdık). Geç gelen sayım/düzeltme geçmiş ay toplamını değiştirebilir ve **değiştirmelidir** — bu distorsiyon değil, geç öğrenilen gerçeğin düzeltmesi. Finans ayı "dondurmak" yerine delta raporu izlemeli.

**Kritik — geç yazılan tipler (Ağustos 2025 analizi):**

| Tip | Ayni_gün | hrkTarih ayrışma | Not |
|---:|---|---|---|
| 99 | Hiçbiri | %100, max 189 gün | **Sayım — daima geriye dönük** |
| 89, 90, 16 | Hiçbiri | %100, +1 gün | Sistematik gece batch |
| 12 | %5 | %95 | Alış Mağaza İade — batch yazım |
| 95, 96 | ~%50 | max 167-185 gün | Geç düzeltme |
| 100, 4, 101 | %60-70 | max 16 gün | POS/mağaza — normal operasyon |

### C.1. `irsHrk.ehTip` Kod Haritası (canlı ekran doğrulanmış)

| Kod | DerinSIS Etiketi | Açıklama |
|---:|---|---|
| 1 | Satış | Toptan satış (fatura) |
| 3 | — | Satış iadesi (toptan) |
| 4 | **Mağaza Satış** | Perakende faturalı (e-arşiv dahil) |
| 5 | Mağaza Satış İade | |
| 8 | **Mağaza Mağaza** | Mağazalar arası transfer |
| 9 | — | |
| 10 | **Yerel Alım** | Tedarikçiden mal girişi (alt tip: "Fazla Malkabul") |
| 12 | **Alış Mağaza İade** | Tedarikçiye iade / "Malkabul Eksik İade" |
| 13 | — | Sipariş (eTarih ≠ eTarihS olabilir) |
| 99 | **Sayım** | Fiziki sayım farkı — geriye dönük yazılır |
| 100 | POS Satış | Yazar kasa perakende |
| 101 | POS İade | |
| 88-98 | (çeşitli) | Düzeltme/transfer tipleri |

**Satış toplamı için:** `ehTip IN (1, 4, 100)` = brüt satış, `ehTip IN (3, 5, 101)` = iade. Net ciro = brüt − iade.

| View | Amaç |
|---|---|
| `dbo.irsTip_vw` | ehTip kodları (tam liste — 34 değer) |

### D. Fatura

| Tablo | Amaç | Kolonlar |
|---|---|---|
| `dbo.fat` | Fatura başlığı | eID (PK), eNo, eMekan, eFirma, eTarihS, **eTarih**, eGC (0=giriş,1=çıkış), **eTip**, eDurum, **onay**, eDvzID, eDvzKur, eMhs, eFatID |
| `dbo.fatAyr` | Fatura satırı | ehID (FK→fat.eID), ehSira, ehStkID, ehAdet, **ehTutar**, ehIndirim, ehTutarKDV, ehKDV, **ehTutarN**, ehMaliyet, ehBirim |
| `dbo.fatTip_vw` | eTip kodları | tipID, tipAD |

### E. Sipariş

| Tablo | Amaç | Kolonlar |
|---|---|---|
| `dbo.sip` | Sipariş başlığı | sID, sMekan, sFirma, sTarih, sTip, sDurum |
| `dbo.sipAyr` | Sipariş satırı | (sip.sID üzerinden join) |
| `dbo.sipTip_vw` | Sipariş tipleri | tipID, tipAD |

### F. Cari / Firma

| Tablo | Amaç | Kolonlar |
|---|---|---|
| `dbo.frm` | Firma/cari (müşteri+tedarikçi+yayınevi) | frmID (PK), frmKod, frmAd |
| `dbo.frmSonSatisBilgi_vw` | Firma son satış özeti | - |

### G. POS / Perakende Satış (Yazar Kasa)

| Tablo | Amaç | Kolonlar |
|---|---|---|
| `dbo.posOzetUrun` | POS satışlar — ürün bazında günlük özet | (test edilmedi, irsHrk ehTip=100 daha güvenilir) |
| `dbo.posBaslik` | POS başlık | - |
| `dbo.posOdeme` | POS ödeme detayı | - |
| `dbo.posOzetOdemeZ` | Z raporu özeti | - |
| `dbo.posOzetMagazaGun` | Mağaza günlük özet | - |
| `dbo.posOzetKasiyer` | Kasiyer özet | - |
| `dbo.posOzetKdv` | KDV özeti | - |
| `dbo.posMagaza` | POS mağaza tanım | - |
| `dbo.posOnline` | Online POS | - |
| **`bkm.MagazaSatis`** | **Mağaza satış özet view** | mekanAd, mekanID, eTarih, ehStkID, ehAdet, tutar |
| `edftr.okcSatisDetay_vw` | OKC (yazar kasa) satış detay view | - |

### H. WMS / Depo

| Tablo | Amaç | Kolonlar |
|---|---|---|
| `depo.paletTnm` | Palet tanımı | pID, pSonPozID |
| `depo.paletUrnTnm` | Palet ürün tanımı | pUID, pUStkID, pUAdetN |
| `depo.adres` | Lokasyon adresi | adrsID, adrsAd |
| `depo.SatisLog` | WMS satış log | - |
| `bkm.WMSPaletBazliTumDepoStoklari` | Palet bazlı tüm depo stokları view | - |
| `bkm.NetDepoStokSipDusulmusJokerRafEklenmis` | Net depo stok (sipariş düşülmüş, joker raf eklenmiş) | - |
| `bkm.SiparisSatisStokDurum` | Sipariş × stok durumu | - |
| `bkm.SiparisSatisStokDurum15Gun` | 15 günlük | - |

### I. Joker (Online B2B — Linked Server `odakjoker`)

> **Mimari:** Joker AYRI DB. Erişim `odakjoker` Linked Server üzerinden. DerinSIS tarafında kullanım için lokal snapshot/cache view ve tablolar mevcut.
>
> **⚡ 16.06 — Dashboard direkt bağlantı:** Dashboard e-ticaret sorguları artık linked yerine **192.168.40.70'e DİREKT** bağlanıyor (`Db.OpenJokerAsync()`, `.env JOKER_HOST`). Sorgular `ODAKJOKER.JOKER.dbo.*` yerine `dbo.*`. Distributed-query overhead kalktı (4.1s→0.6s). MCP/SSMS analizde hâlâ linked kullanılabilir; .70 direkt SADECE dashboard runtime. Detay köprüler: `sema/bridges.yaml` (joker-direct-conn, items-logogrup-kategori3).
> **E-ticaret KATEGORİ:** `J_ITEMS.DERINSIS_LOGOGRUP` = DerinSIS **Kategori3**'ü metin olarak birebir taşır → cross-server join GEREKMEZ. (`ANAKATEGORI`/`WEB_ANAKATEGORI` daha kaba; `UrunBilgi.Kat3` BOŞ, doğru kolon `Kategori3`.)

**Lokal snapshot/cache (DerinSISBkm — pratikte bunları kullan):**

| Tablo / View | Amaç |
|---|---|
| `dbo.JOKER_SIPARISLER` | Joker sipariş cache |
| `dbo.JOKER_URUNLER` | Joker ürün katalog cache |
| `dbo.JOKER_BARKODLAR` | Joker barkod eşleme cache |
| `dbo.JOKER_STONSTOK` | Joker son stok cache |
| `dbo.JOKERICIPTALLER` | Joker iptal cache |
| `dbo._jokerNetStok` / `_jokerNetStokDun` | Net stok (anlık + dün) |
| `ent.JokerHavuzStok_vw` | Havuz stok |
| `ent.JokerCKStok_vw` | CK stok |
| `ent.JokerHavuz_Palet_Dagilim_vw` | Havuz palet dağılımı |
| `ent.JokerCK_Palet_Dagilim_vw` | CK palet dağılımı |
| `ent.JokerGrStok_vw` | Joker grup stok |
| `ent.malKabuldeJokerPalet_vw` | Mal kabulde Joker palet |
| `ent.JOKER_TOPLAMA_HESAPLAMA_ACIK_EMIRLER` | Açık emir toplama hesaplama |
| `dbo.ozl_jokersatissiparisi` (view) | Joker satış sipariş |
| `dbo.ozl_jokersatissiparisianlik_vw` | Anlık |
| `dbo.ozl_jokersatissiparisi_tumu` | Tümü |

### J. Envanter / Maliyet

| Tablo | Amaç |
|---|---|
| **`bkm.ENVANTER_RAPORU`** | Günlük envanter raporu (98 satır/gün, 2 maliyet tipi) — `MaliyetRaporu-Ceren` job'ı doldurur |
| `bkm.TarihtekiUstFiyat(stkID, tarih)` | Skaler fonksiyon — fyt'den fTur=0 üst fiyat |
| `dbo.fyt` | Fiyat tablosu (fTur=0 satış üst fiyat) |
| `dbo.fiyatSatis_vw` | Satış fiyat view |
| `dbo.fiyatOzelSatis_vw` | Özel satış fiyat |

### K. Muhasebe / Sayım / Diğer

| Tablo | Amaç |
|---|---|
| `mhs.mhsFis` | Muhasebe fişi |
| `mhs.mhsEntPos` | Muhasebe POS entegrasyon |
| `bkm.DepoSayimBaslik` / `DepoSayimDetay` | Depo sayım |
| `bkm.SayimEmirBaslik` | Sayım emirleri |
| `bkm.HeykelSatisKibo` | Heykel-Kibo satış |
| `bkm.Enf_AylikUrunSatislari` | Enflasyon aylık ürün satış |
| `bkm.Erp12StokCarpan` | Stok çarpan |

---

## 3. ehTip / eTip Kod Sözlüğü (CANLI DOĞRULANMIŞ)

### `irsHrk.ehTip` (irsTip_vw — 34 değer)

```
0  = Alış               1  = Satış              2  = Alış İade
3  = Satış İade         4  = Mağaza Satış       5  = Mağaza Satış İade
6  = Hizmet             7  = Gider              8  = Mağaza Mağaza
9  = Mağaza Depo        10 = Yerel Alım         11 = Depo Depo
12 = Alış Mağaza İade   13 = Depo Mağaza        14 = İade ve İmha
15 = Örnek Alımı        16 = Stok EKLE          17 = Merkezi Düzeltme
18 = Mağaza İçi İşlemler
86 = Ürün Değişim       88 = Diğer Giriş        89 = Diğer Çıkış
90 = Ürün SAY           91 = Rakipten Ürün Alış 92 = Boş Paket Çıkışı
93 = Müşteriden Bozuk İade  94 = SKT Nedeniyle  95 = Dönüşüm
96 = Bozuk Ürün         97 = Devir              98 = Şirket İçi Kullanım
99 = Sayım              100 = POS Satış         101 = POS Satış İade
```

**Satış grupları:**
- **Tüm satış (gross):** `ehTip IN (1, 4, 100)`
- **Tüm iade:** `ehTip IN (3, 5, 101)`
- **Net ciro:** satış − iade

### `fat.eTip` (fatTip_vw — 13 değer)

```
0 = Alış               1 = Satış (B2B)      2 = Alış İade
3 = Satış İade         4 = Mağaza Satış      5 = Mağaza Satış İade
6 = Hizmet             7 = Gider             8 = Fiyat Farkı
9 = Fiyat Farkı Düzeltmesi  10 = İade Fark Faturası
11 = Satış Fiyat Farkı     12 = Satış Fiyat Farkı Düzeltme
```

⚠️ **fat sadece kesilen faturalar** — perakende kasa satışları burada YOK. POS/perakende için `irsHrk.ehTip = 100` kullan.

### `sip.sTip` (sipTip_vw)

```
0=Alış Emri  1=Satış Emri  2=Mağaza Depo  3=Yerel Alım  4=Depo Depo
5=Gider  6=Hizmet  7=Mağaza Satış  8=Mağaza Mağaza  9=Alış İade
10=Satış İade  11=Mağaza Satış İade  12=Alış Mağaza İade  13=Depo Mağaza
```

---

## 4. e* / eh* Prefix Mantığı

DerinSIS evrensel kuralı:

| Prefix | Anlamı | Tipik Tablo |
|---|---|---|
| `e*` | **Evrak başlığı** (Header) | `fat.eID`, `irs.eID`, `sip.sID` |
| `eh*` | **Evrak hareket** (Detay satırı) | `fatAyr.ehID`, `irsHrk.ehID` |

**Detay satırı header'a referans:** `fatAyr.ehID = fat.eID` (aynı isim, FK).

**Standart başlık kolonları:** `eID, eNo, eMekan, eFirma, eTarihS, eTarih, eGC, eTip, eBag, eDurum, onay, eDvzID, eDvzKur, eMhs`

**Standart detay kolonları:** `ehID, ehSira, ehStkID, ehAdet, ehTutar, ehIndirim, ehTutarN, ehTutarKDV, ehKDV, ehMaliyet`

`*N` suffixli kolonlar **net** anlamına gelir (KDV/indirim sonrası).

---

## 5. JOIN Şablonları

### Satış (İrsHrk üzerinden — gerçek perakende dahil)
```sql
FROM dbo.irsHrk H WITH (NOLOCK)
JOIN dbo.mekan_vw M ON M.mekanID = H.ehMekan
JOIN bkm.Urunbilgi UB ON UB.stkID = H.ehstkID
WHERE H.ehAltDepo = 0
  AND H.ehTip IN (1, 4, 100)   -- satış
```

### Fatura + Detay + Cari
```sql
FROM dbo.fat F
JOIN dbo.fatAyr FA ON FA.ehID = F.eID
JOIN dbo.frm FR ON FR.frmID = F.eFirma
JOIN dbo.fatTip_vw FT ON FT.tipID = F.eTip
WHERE F.onay = 1
  AND F.eTip IN (1, 4)
```

### Ürün + Kategori (job şablonu)
```sql
FROM dbo.urnKategori_vw U
JOIN dbo.urnMrk M ON M.mrkID = U.urnMrkID
JOIN dbo.urnKtgr2 GRP ON GRP.ktgrID = U.urnKtgr2ID
LEFT JOIN dbo.urnBrkd BRK ON BRK.urnBrkdStkID = U.stkID AND BRK.urnBrkdOnce = 0
WHERE U.urnTip = 0
  AND U.urnKtgr2ID NOT IN (11,25,23,9,5,6)
```

### WMS Stok Toplamı
```sql
SELECT pUStkID stkID, SUM(pUAdetN) Stok
FROM depo.paletUrnTnm WITH (NOLOCK)
JOIN depo.paletTnm WITH (NOLOCK) ON paletTnm.pID = paletUrnTnm.pUID
JOIN depo.adres WITH (NOLOCK) ON pSonPozID = adrsID
WHERE pUAdetN > 0
  AND adrsAd NOT IN ('CK01')
GROUP BY pUStkID
```

---

## 6. CTE / Pratik Şablonlar

### Aylık Net Ciro (mağaza × ay)
```sql
SELECT
    FORMAT(H.ehTrhS, 'yyyy-MM') AS ay,
    M.mekanAd,
    SUM(CASE WHEN H.ehTip IN (1,4,100) THEN H.ehTutarN END) AS satis_brut,
    SUM(CASE WHEN H.ehTip IN (3,5,101) THEN H.ehTutarN END) AS iade,
    SUM(CASE WHEN H.ehTip IN (1,4,100) THEN H.ehTutarN END)
      - SUM(CASE WHEN H.ehTip IN (3,5,101) THEN H.ehTutarN END) AS net_ciro
FROM dbo.irsHrk H WITH (NOLOCK)
JOIN dbo.mekan_vw M ON M.mekanID = H.ehMekan
WHERE H.ehTrhS >= CONVERT(date,'01.01.2026',104)
  AND H.ehAltDepo = 0
  AND H.ehTip IN (1,3,4,5,100,101)
GROUP BY FORMAT(H.ehTrhS, 'yyyy-MM'), M.mekanAd
```

### Ürün ABC (top satıcılar)
```sql
SELECT TOP 50
    UB.stkKod, UB.stkAd, UB.Kategori3, UB.mrkAd,
    SUM(-H.ehAdetN) AS adet,
    SUM(H.ehTutarN) AS ciro
FROM dbo.irsHrk H WITH (NOLOCK)
JOIN bkm.Urunbilgi UB ON UB.stkID = H.ehstkID
WHERE H.ehTrhS >= DATEADD(month, -3, GETDATE())
  AND H.ehAltDepo = 0 AND H.ehTip IN (1,4,100)
GROUP BY UB.stkKod, UB.stkAd, UB.Kategori3, UB.mrkAd
ORDER BY ciro DESC
```

### Negatif Bakiye Tarama (envanter check)
```sql
SELECT ehstkID, SUM(ehAdetN) AS bakiye
FROM dbo.irsHrk WITH (NOLOCK)
WHERE ehTrhS <= GETDATE()
  AND ehAltDepo = 0
  AND ehMekan IN (1,4477,4478)
GROUP BY ehstkID
HAVING SUM(ehAdetN) < 0
```

---

## 7. Sık Kullanılan Filtreler & Magic Number'lar

| Filtre | Anlam |
|---|---|
| `urnTip = 0` | Normal ürün — **ölü stok dahil tüm ürün sorgularında ZORUNLU**. urnTip=1 gider/hizmet kalemi (250 kayıt, muhasebe). |
| `ehAltDepo = 0` | Ana depo/mağaza (alt depo değil) |
| `urnKtgr2ID NOT IN (11,25,23,9,5,6)` | Envanter Job exclude listesi |
| `urnKtgrID = 78 AND urnKtgr1ID = 5 AND urnKtgr2ID = 19` | **Sınav Okulları** (envanter -300M sorununun kaynağı) |
| `urnBrkdOnce = 0` | Ana barkod (alternatif barkod değil) |
| `onay = 1` | Onaylı belge |
| `pUAdetN > 0` | WMS'te dolu palet |
| `adrsAd NOT IN ('CK01')` | Çıkış kapısı hariç |
| `WITH (NOLOCK)` | Canlı sorguda zorunlu (özellikle irsHrk, depo.*) |
| Tarih: `CONVERT(date, '01.04.2026', 104)` | **DMY format** (yyyy-MM-dd KULLANMA) |

**stkID exclude (job'da):** `81809, 77328, 200772, 84642, 59337, 65462, 64515, 56761, 22390, 60318, 128118, 1644512`

**Ölü stok maliyet zinciri (COALESCE):**
1. `fatAyr/fat` son 5 alış faturası (`eTip=0, eDurum<>2`) → `SUM(ehTutarN)/SUM(ehAdetN)`
2. `Aktarim.dbo.BKM_STOKLAR_MALIYETLI.ORT_ALIS`
3. `urn.fiyatS × AVG(ORT_ALIS/fiyatS)` — kategori ortalama maliyet oranı imputation (filtre: `ORT_ALIS>0 AND fiyatS>0 AND ORT_ALIS<fiyatS`)

**Ölü stok ek hariç kategoriler:** `Zkargo` (alış kargo), `KARGO` (gelir kalemleri, stkID 144860/144963)

---

## 8. Bilinen Veri Kalitesi Sorunları

(Envanter soruşturmasından — `sorgular/SESSION.md` ve `urun_listesi_tespitler.md` detayları)

| Sorun | Etki |
|---|---|
| **Sınav Okulları paket negatifleri** | -299.9M TL hayalet İst.Yolu'nda (paket çıkış / parça giriş uyumsuzluğu) |
| **stkID duplikasyonu** | Aynı ürün farklı stkID'de (Options 1: 1673526 ↔ 1668021; Note The Time 17 SKU; OBM Harry Potter 12 SKU) |
| **Fiyat hatası adayları** | Mileo Fon Kartonu 1.999 TL, Yılbaşı Fanus 7.990 TL |
| **WMS aşırı birikim** | Note Defter 97K adet, Touch Marker 50K adet — fiziki sayım gerekli |
| **Kategori hijyeni** | "Tanımsız" kategoride 17.544 SKU, "Akademi"de 116.550 SKU |

---

## 9. Eski/Kullanılmayan — DİKKATE ALMA

Bu SQL'lerde geçen ama artık geçerli olmayan referanslar:

- `LG_220_*` (Logo ERP) — DerinSIS'e geçildi
- `WMSBKM` ayrı DB — TAMAMEN YOK. Tüm WMS verisi `DerinSISBkm.depo.*` şemasında.
- `Vega`, `Cafe` (BillHeader, Bill, Product) — proje sonlandı
- `GOPLUS` — yok
- `L_CAPIWHOUSE` — Logo'dan kalma, yok
- `sil.*` şeması — silinmiş tablolar arşivi, kullanma

---

## 10. Sık Kullanılacak Hızlı Komutlar

### Tüm tablo arama
```sql
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%anahtar%'
```

### Kolon arama
```sql
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%anahtar%'
```

### Tip kodu listesi
```sql
SELECT * FROM dbo.irsTip_vw    -- ehTip
SELECT * FROM dbo.fatTip_vw    -- eTip
SELECT * FROM dbo.sipTip_vw    -- sTip
```

### Mekan listesi
```sql
SELECT * FROM dbo.mekan_vw
```

---

## Notlar

- Fikri'nin SQL'lerinde NOLOCK, CTE ve `ozl_*` (özlüce/özel?) prefix sık görülüyor.
- `bkm.Urunbilgi` view'ı en pratik ürün lookup (Kategori3'e Kat3 değil **Kategori3** kolonundan eriş).
- `_jokerNetStok` ve `_jokerNetStokDun` günlük snapshot — değişim takibi için.
- WMS'te "CK" ile başlayan adresler kapı/çıkış (sayıma dahil etme).
