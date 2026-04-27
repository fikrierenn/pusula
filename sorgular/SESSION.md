# SESSION.md — Envanter Soruşturması Master Index

> **Üst bağlam:** `../CLAUDE.md`
> **Son güncelleme:** 15 Nisan 2026
> **Kullanıcı:** Fikri
> **DB:** DerinSISBkm @ 192.168.40.201 (MCP: `sqlserver`)
> **İkincil sunucu:** 192.168.40.66\SQLEXPRESS (MCP: `sqlserver-express`) — envanter soruşturmasıyla ilgili DEĞİL, ayrı bağlantı. Detay: `../CLAUDE.md` → "Veritabanı Bağlantısı" bölümü.

---

## Soruşturmanın Hikayesi

1. **Tetik:** İst.Yolu envanter raporunda **-54M TL** anormal değer.
2. **İlk hipotez:** Job filtresi eksik, kategori dışı bir şey sızıyor.
3. **Bulgu:** Sınav Okulları Kategori3'ünde 22 süreli yayın paketi paket/parça kod uyumsuzluğundan negatife düşmüş (-299.9M TL).
4. **Genişleme:** Tüm stoka tarama → bilateral distorsiyon (paket negatif + parça pozitif) + 8 başka anomali tipi.
5. **Çıktı:** ~120 SKU, ~-268M TL düzeltilebilir distorsiyon. Tek satır SQL ile kısa vadeli, yeni Kategori3 ile kalıcı çözüm.

---

## Dosya Index

### Envanter Soruşturması (bu sırada okunmalı)

| # | Dosya | İçerik | Durum |
|---|---|---|---|
| 1 | `envanter_raporu_job_sorgusu.sql` | MaliyetRaporu-Ceren job'ının orijinal SQL'i | ✅ Referans |
| 2 | `envanter_raporu_analiz.md` | İlk analiz, problem tanımı | ✅ Tamam |
| 3 | `kontrol_gun_bazli_detay.sql` | Gün bazlı kontrol sorguları | ✅ Tamam |
| 4 | `sorunlu_urunler_tutar_detay.md` | 22 süreli yayın paketi detayı, FSM/Özlüce/İstYolu | ✅ Tamam |
| 5 | `tum_stoklar_anomali_taramasi.md` | 3 anomali kümesi: A negatif, B pozitif, C WMS | ✅ Tamam |
| 6 | `envanter_derin_analiz.md` | 11 bölümlü derin analiz | ✅ Tamam |
| 7 | `urun_listesi_tespitler.md` | 10 bölümlü ürün-bazlı tespit (A-J) | ✅ Tamam |

### Satış Kanalı Köprüsü (Sınav / Retail Ayrımı — 15 Nis 2026)

| # | Dosya | İçerik | Durum |
|---|---|---|---|
| 8 | `sinav_kanal_koprusu.md` | `BKM.snv.SinavSiparisFisEncore.InvoiceNo ↔ EncoreMerkez.dbo.Sales.DocumentNo` köprüsü — %99,79 kapsama, 315 TL sapma | ✅ Keşif tamam |

Durumlar:
- Köprü kolonu doğrulandı, toplu tutar eşleşmesi geçti
- Collation tuzağı (`Turkish_CS_AS` vs `Turkish_CI_AS`) belgelendi
- **Beklemede:** `Sales → fat/irsHrk` bağlantısı, barkod patterni doğrulaması, view tasarımı, 2026 Sınav/Retail ayrıştırılmış tahmin

### Diğer (EncoreMerkez SQL kütüphanesi)

Bkz. `INDEX.md` ve `00-README.md` — bu envanter soruşturmasıyla ilgili **değil**.

---

## Anahtar Bulgular Tek Bakışta

### Kök Neden (tek cümle)
Sınav Okulları aboneliği **paket koduyla** çıkış yapıyor, parça/modül **kendi koduyla** giriş yapıyor → paket kodları İst.Yolu'nda eksiye düşüyor, parça kodları aynı mağazada şişiyor.

### Sayısal Etki

| Boyut | Değer |
|---|---:|
| Negatif paket SKU | 22 |
| Negatif tutar | -299.9M TL |
| Pozitif parça SKU | 17 |
| Pozitif tutar | +30.0M TL |
| Diğer anomaliler (D-J) | ~80 SKU, ~+5M TL |
| **Net düzeltilebilir** | **~120 SKU, ~-268M TL** |

### En Acil 3 Aksiyon

1. **Job filtresi (5 dk):**
   ```sql
   AND NOT (U.urnKtgrID = 78 AND U.urnKtgr1ID = 5 AND U.urnKtgr2ID = 19)
   ```

2. **Fiziksel sayım (1 hafta):**
   - The Edd Duygulu Mini Not Defter — 97.178 adet
   - Touch Marker — 49.696 adet
   - Mileo Fon Kartonu — 1.999 TL fiyat doğrulaması

3. **stkID konsolidasyon talebi IT'ye:**
   - Options 1 Student's Book: 1673526 ↔ 1668021
   - Note The Time: 17 SKU
   - OBM Harry Potter: 12 SKU

---

## Sonraki Adımlar (Bekleyen)

- [ ] **Satış & Ciro Analizi** — kullanıcı seçti, SQL connection bloke ettiği için duruyor
- [ ] Maliyet/Kâr analizi (FIFO yansıtma)
- [ ] Cari/müşteri segmentasyonu
- [ ] Tedarikçi performansı
- [ ] ERP genel sağlık check
- [ ] Job/Rapor mimarisi review

---

## Kritik Hatırlatmalar

- **Tarih:** DMY (`104` style: `dd.MM.yyyy`)
- **urnKtgr2 join:** kolon adı `ktgrAd` (`ktgr2Ad` HATA verir)
- **Mekan:** 1=FSM, 4477=Özlüce, 4478=İst.Yolu
- **Job exclude listesi:** `urnKtgr2ID NOT IN (11,25,23,9,5,6)` + (önerilen) Sınav Okulları
- **MCP sunucu seçimi:** BKM/ERP/envanter = `mcp__sqlserver__*`. "Express'te / 66'da / diğer sunucuda" dendiğinde = `mcp__sqlserver-express__*`. Emin değilsen sor.
