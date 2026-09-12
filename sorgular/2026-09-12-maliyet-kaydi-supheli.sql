/* ============================================================================
   MALİYET KAYDI ŞÜPHELİ — "hiç satmamış 46,8M ₺"nin %64'ü iki muhasebe kalemiydi
   Tarih: 12.09.2026 · DB: DerinSISBkm (bkm.SatisAnaliziTaban, kesim 11.09.2026)

   NASIL BULUNDU: hesap-sorma toplantısı ÖNCESİ `veri-dogrula` QA'sı. Soru şuydu:
   "maliyeti bilinmeyen çeşitler RASTGELE mi dağılmış, yoksa ölü stokta mı yığılı?"
   Cevap ikisinden de kötü çıktı — asıl sorun maliyeti BİLİNMEYEN değil, maliyeti
   YANLIŞ yazılmış kayıtlardı.

   ═══ BULGU ════════════════════════════════════════════════════════════════
   Hiç satmamış kohortunda ortalama `BirimMaliyet / SatisFiyat` = 7,32
   (satan üründe 0,44). Uçta 232.018×. Kırılım:

     A) maliyet > fiyat (imkânsız marj)     38 çeşit · maliyet 29,90M ₺ · etiket 0,08M ₺
     B) maliyet fiyatın %70-100'ü          597 çeşit · maliyet  0,36M ₺ · etiket 0,48M ₺
     C) normal (maliyet < %70)          32.651 çeşit · maliyet 16,57M ₺ · etiket 43,26M ₺

   A dilimini iki kalem taşıyor ve ikisi de ÜRÜN DEĞİL:
     stkID 128118  "Muhtelif Ürün"              5 adet × 4.640.370 ₺ = 23.201.852 ₺
     stkID  81809  "İskonto ve Fiyat Farkı"  1.055 adet ×     6.279 ₺ =  6.624.345 ₺
   ⚠ İkisi de ERP'de `urn.urnTip = 0` (NORMAL ÜRÜN) olarak tanımlı — bu yüzden
   `urnTip` süzgeci bunları ELEMİYOR. Kontrol edildi: tabanda `urnTip <> 0` → 0 kayıt,
   yani sızıntı bizim filtremizde değil, ERP ürün master'ında.

   YAYILIM (tüm evren, ToplamStok>0): 258 çeşit / 31,4M ₺ = evren maliyetinin %7,7'si.
   (Panel kartı stoksuzları da sayar → 313 çeşit / 31,45M ₺.)

   MALİYET KAPSAMI RASTGELE DEĞİL (ikinci bulgu):
     maliyeti bilinen çeşit oranı — evren %88,5 · ölü stok %79,9 · hiç satmamış %76,1
   ⇒ "maliyetli toplamlar alt sınırdır" beyanı TEK BAŞINA yetmiyor; eksiklik en çok
   satmayan malda yığılı, yani en çok konuşulan kohortta.

   ═══ DÜZELTME ════════════════════════════════════════════════════════════
   `MaliyetGuvenilirSart = (BirimMaliyet > 0 AND BirimMaliyet <= SatisFiyat)` — 20 maliyet
   toplamının hepsi buna geçti. Dışlanan kayıt GİZLENMEDİ: `MaliyetSupheliSart` ile ayrı
   sayılıyor, ekranda kendi satırı ve `MaliyetSupheli` liste filtresi var.

   ⚠ NEDEN KEYFÎ BİR KESİM DEĞİL: TMS 2 / IAS 2 — stok, maliyet ile net gerçekleşebilir
   değerin DÜŞÜĞÜ ile değerlenir. Maliyeti satış fiyatını aşan kayıt değerleme tabanı
   olamaz. Panel hangisinin (fiyat mı maliyet mi) yanlış olduğunu bilemez, o yüzden
   düzeltmiyor — dışlayıp sayıyor.

   ETKİ (panelde okundu, öncesi → sonrası):
     hiç satmamış      46,8M → 16,9M ₺   (%64 düştü)
     ölü stok toplam   71,0M → 41,0M ₺
     envanter maliyet 409,6M → 378,1M ₺
     aşırı stok fazla  74,7M → 73,7M ₺   (kirlilik yalnız %1,3 — bu kart zaten temizdi)
     gerçekleşen kâr  232,6M → 233,0M ₺ · marj %31,4 → %31,5

   KIRILABİLİRLİK KANITLANDI: şart `(BirimMaliyet > 0)` hâline geri döndürüldü →
   hiç satmamış yine 46,8M ₺ okudu → şart geri alındı.
   ============================================================================ */

DECLARE @k date = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban);

/* ── BLOK 1 — hiç satmamış kohortunda maliyet/fiyat dilimleri ─────────────── */
WITH t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = @k AND SezonYil = 2025
      AND StokFsm >= 0 AND StokOzl >= 0 AND StokIst >= 0 AND MerkezStok >= 0
      AND SatisFiyat > 0 AND ToplamStok > 0
),
o AS (   -- ölü stok ölçütü + hiç satmamış
    SELECT * FROM t
    WHERE SatisToplam <= 0 AND (PosAdet IS NULL OR PosAdet <= 1)
      AND IlkGiris IS NOT NULL
      AND COALESCE(IlkGiris, AcilisTarihi) < DATEADD(DAY, -45, @k)
      AND SonSatis IS NULL AND ISNULL(BirimMaliyet, 0) > 0
)
SELECT CASE WHEN BirimMaliyet > SatisFiyat          THEN 'A) MALIYET FIYATTAN BUYUK'
            WHEN BirimMaliyet > 0.7 * SatisFiyat    THEN 'B) maliyet fiyatin %70-100u'
            ELSE 'C) normal (maliyet < %70)' END AS dilim,
       COUNT(*) AS cesit,
       CONVERT(decimal(12,2), SUM(CONVERT(float, ToplamStok) * BirimMaliyet) / 1000000.0) AS maliyetM,
       CONVERT(decimal(12,2), SUM(Tutar) / 1000000.0) AS etiketM,
       CONVERT(decimal(12,2), MAX(BirimMaliyet / SatisFiyat)) AS enYuksekOran
FROM o
GROUP BY CASE WHEN BirimMaliyet > SatisFiyat       THEN 'A) MALIYET FIYATTAN BUYUK'
              WHEN BirimMaliyet > 0.7 * SatisFiyat THEN 'B) maliyet fiyatin %70-100u'
              ELSE 'C) normal (maliyet < %70)' END
ORDER BY 1;
-- ÖLÇÜLDÜ: A 38 / 29,90M / 0,08M / 232.018,52 · B 597 / 0,36M / 0,48M · C 32.651 / 16,57M / 43,26M

/* ── BLOK 2 — A dilimini kimler taşıyor ──────────────────────────────────── */
SELECT TOP 8 stkID, LEFT(stkAd, 40) AS ad, Kategori3, ToplamStok, SatisFiyat,
       CONVERT(decimal(18,2), BirimMaliyet) AS birimMaliyet,
       CONVERT(decimal(14,0), CONVERT(float, ToplamStok) * BirimMaliyet) AS maliyetTL,
       MaliyetTarih
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = @k AND SezonYil = 2025 AND ToplamStok > 0 AND SatisFiyat > 0
  AND BirimMaliyet > SatisFiyat AND SatisToplam <= 0
ORDER BY CONVERT(float, ToplamStok) * BirimMaliyet DESC;
-- ÖLÇÜLDÜ: 128118 "Muhtelif Ürün" 23.201.852 ₺ · 81809 "İskonto ve Fiyat Farkı" 6.624.345 ₺
--          1670879 "8. SINIF DENEME" 56.511 ₺ · gerisi 10-15 bin ₺ mertebesinde

/* ── BLOK 3 — yayılım + urnTip kontrolü ──────────────────────────────────── */
-- tüm evren maliyeti · bunun maliyet>fiyat kısmı · urnTip<>0 sızıntısı
-- ÖLÇÜLDÜ: 256.264 çeşit / 410,2M ₺ · 258 çeşit / 31,4M ₺ (%7,7) · urnTip<>0 → 0 KAYIT

/* ── BLOK 4 — maliyet kapsamının dağılımı (rastgele DEĞİL) ───────────────── */
-- maliyeti bilinen çeşit yüzdesi:
--   tüm evren %88,5 · ölü stok %79,9 · HİÇ SATMAMIŞ %76,1 · ölü∩aşırı %91,6

/* ── BLOK 5 — aşırı stok kartı etkilendi mi (HAYIR) ──────────────────────── */
-- aşırı stok fazla maliyet 74,67M ₺ / 37.103 çeşit
-- bunun maliyet>fiyat kısmı: 33 çeşit / 0,97M ₺ = %1,3 → kart zaten temizdi
