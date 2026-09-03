/* ehTip 88 "Diğer Giriş" / 89 "Diğer Çıkış" NEDİR? (plan 41 açık soru 1)
   DB: DerinSISBkm (192.168.40.201) · Araç: sqlcli --profile erp
   Soru: sema'da hiç belgelenmemiş bu iki kod ±65M adet taşıyor; iş anlamı bilinmeden
         bkm.IrsTipGrupMap'te grup/bayrak ataması yapılamaz.

   BULGU — 88/89 = MANUEL STOK DÜZELTME KANALI:
   · Sebep kodu `irs.Neden`/`NedenAlt` HİÇ KULLANILMIYOR (tümü 0). Sebep serbest metin
     `irs.eNot` alanına yazılıyor → sınıflandırma ancak metinle yapılabilir.
   · 88: 364.226 satır / 423 belge. %85'i TEK OLAY: "WMS - ERP EŞİTLEME" 2 belge,
     310.096 satır, 31.12.2025, +21,3M adet.
   · 89: 28.935 satır / 158 belge. %91'i aynı olay: 26.278 satır, −35,85M adet.
   · Mekan: 88 → %87 Merkez Depo (12) · 89 → %91 Merkez Depo. Mağaza payı küçük düzeltmeler.
   · Diğer kalemler: "ODAK Efaturalarında olmayan ürün" (104 belge/41.851 satır, Ağu–Eki 2023),
     SINAV OKULLARI STOK DÜZELTME, HASARLI/SİGORTA HASARLI, KAMPANYALI ÜRÜN STOK DÜZELTME,
     HEDİYE ÇEKİ ÜRETİM, İST.YOLU SEVK STOK DÜZELTME (88/89 çifti aynı gün, ±10.872 → transfer
     düzeltmesi), ve **SahafGiris** (12 belge/4.844 satır, 06.05–27.08.2026 — HÂLÂ AKTİF).

   ⚠ TEK KOD ALTINDA ÜÇ AYRI İŞ: (a) sistem eşitleme (tek seferlik, dev hacim),
     (b) e-fatura istisna girişi, (c) SAHAF ALIMI = gerçek mal girişi. Yani `ehTip=88`
     "düzeltme" demek DEĞİL. Satınalma/maliyet analizleri `ehTip IN (0,10)` kullandığı için
     sahaf girişleri o analizlerin DIŞINDA kalıyor (bkz. TODO K-32).

   ⚠ ÖLÇÜM TUZAĞI (kendi hatam, 2026-09-03): MIN/MAX tarih `CONVERT(varchar,...,104)`
     üstünden alınınca dd.MM.yyyy METİN olarak sıralanır ve "ilk 01.09.2023 > son 31.08.2023"
     gibi saçma aralık verir. Tarih AGGREGATE'i daima date/datetime üstünde alınır, sonra
     biçimlendirilir. */

-- 1) Sebep kolonu kullanılıyor mu (hayır — hepsi 0)
SELECT i.eTip, i.Neden, i.NedenAlt, COUNT(*) AS belge
FROM dbo.irs i WITH(NOLOCK)
WHERE i.eTip IN (88, 89)
GROUP BY i.eTip, i.Neden, i.NedenAlt
ORDER BY i.eTip, belge DESC;

-- 2) İş anlamı: eNot metnine göre kırılım (satır sayısı + net adet + doğru tarih aralığı)
--    Başlık↔satır anahtarı: irsHrk.ehID = irs.eID (eIrsID DEĞİL — o alan 0 dolu)
SELECT i.eTip,
       LEFT(ISNULL(NULLIF(LTRIM(RTRIM(i.eNot)), ''), '(not yok)'), 40) AS notu,
       COUNT(DISTINCT i.eID)                        AS belge,
       SUM(h.satir)                                 AS satir,
       CAST(SUM(h.adet) AS decimal(18, 0))          AS net_adet,
       CONVERT(varchar, MIN(i.eTarihS), 104)        AS ilk,
       CONVERT(varchar, MAX(i.eTarihS), 104)        AS son
FROM dbo.irs i WITH(NOLOCK)
CROSS APPLY (
    SELECT COUNT(*) AS satir, SUM(CAST(x.ehAdetN AS float)) AS adet
    FROM dbo.irsHrk x WITH(NOLOCK)
    WHERE x.ehID = i.eID AND x.ehTip = i.eTip
) h
WHERE i.eTip IN (88, 89)
GROUP BY i.eTip, LEFT(ISNULL(NULLIF(LTRIM(RTRIM(i.eNot)), ''), '(not yok)'), 40)
ORDER BY SUM(h.satir) DESC;

-- 3) Mekan dağılımı — merkez depo mu mağaza mı
SELECT h.ehTip, h.ehMekan, COUNT(*) AS satir,
       CAST(SUM(CAST(h.ehAdetN AS float)) AS decimal(18, 0)) AS net_adet
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehTip IN (88, 89)
GROUP BY h.ehTip, h.ehMekan
ORDER BY satir DESC;

-- 4) SAHAF girişi ayrı ölçülür (2026'da aktif, gerçek mal girişi — düzeltme değil)
SELECT YEAR(i.eTarihS) AS yil, COUNT(DISTINCT i.eID) AS belge, SUM(h.satir) AS satir,
       CAST(SUM(h.adet) AS decimal(18, 0)) AS net_adet
FROM dbo.irs i WITH(NOLOCK)
CROSS APPLY (
    SELECT COUNT(*) AS satir, SUM(CAST(x.ehAdetN AS float)) AS adet
    FROM dbo.irsHrk x WITH(NOLOCK)
    WHERE x.ehID = i.eID AND x.ehTip = i.eTip
) h
WHERE i.eTip = 88 AND i.eNot LIKE '%Sahaf%'
GROUP BY YEAR(i.eTarihS)
ORDER BY yil DESC;
