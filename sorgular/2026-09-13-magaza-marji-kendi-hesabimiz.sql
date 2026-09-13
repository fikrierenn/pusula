/* ============================================================================
   MAĞAZA MARJI — KENDİ HESABIMIZ, PERAKENDE / DİĞER AYRIK        2026-09-13
   DB: EncoreMerkez + DerinSISBkm (profil: erp — 3 parçalı isim)

   ⭐ KOŞULDU 13.09.2026 (ERP ağı birkaç kez koptu, gelince ölçüldü).
   BAŞLIK SONUÇ: **PERAKENDE BRÜT MARJ %37,3** — ciro 689,9M ₺ · SMM 432,6M ₺ ·
   brüt kâr **257,3M ₺**. Üç şube birbirinin 0,8 puanı içinde.

   Kullanıcı yönü:
     1) "web cirosu karlılığı raporlamaya gerek yok şimdilik, odak noktamız
         mağazalar, sonra com tarafına bakacağız"
     2) "o kolona takılma, biz kendi hesabımıza bakalım"  ← `posOzetUrun.posMaliyet`
     3) "perakende satış ve diğer satışı ayırmak gerek"
     4) "ehtip 100 perakende zaten / sınav da kasadan düzenlenen belge"
     5) "30 bin üstü kanunen ya e-arşiv ya da e-fatura oluyor" → "hatta 30 değil
        12 bin" → "fiş kesme limiti var kanunen"

   ⚠⚠⚠ (3) TABANI DEĞİŞTİRDİ — bu dosyanın ilk hâli `dbo.posOzetUrun` üzerine
   kuruluydu ve O YOLLA KANAL AYRIMI YAPILAMAZ. `posOzetUrun` bir ÜRÜN-GÜN
   ÖZETİDİR; belge tipi taşımaz, dolayısıyla perakende fişi ile Sınav faturasını
   ayıramaz. DerinSIS tarafı da ayıramaz: `irsHrk.ehTip=100` GÜNLÜK ÖZET belgedir
   (ayda ~32 satır) — `.claude/rules/sql-server-conventions.md` § KANAL AYRACI.
   ⇒ Kanal sorusu BELGE BAZLIDIR ve yalnız kasadan (EncoreMerkez) gelir.
   Taban `Sales` + `SalesProducts`a taşındı. (4) bunu doğruluyor: Sınav da kasadan
   düzenlenen bir belgedir, yani ayrım kasada YAPILABİLİR.

   ⚠ Taşımanın BEDELİ: belge-bazlı ölçüm yalnız **Ağu-2025 sonrası** güvenlidir
   (POS geçişi). 12 aylık pencere 13.09.2025'te başlıyor ⇒ şart SAĞLANIYOR;
   pencere uzatılırsa ölçüm KIRILIR.
   ============================================================================ */

/* ── 0) KANAL SÖZLÜĞÜ ──────────────────────────────────────────────────────── */
-- EncoreMerkez `Sales.DocumentsTypeId`:
--   1 = Fiş            ┐ PERAKENDE
--   3 = İade (−)       ┘  ⇒ iade NEGATİF işaretle netlenir, ayrı kanal değil
--   2 = Fatura · 6 = Personel Fiş · 7 = Personel Fatura · 8 = Sınav Okulları
--
-- ⚠⚠ **`2` = "KURUMSAL" DEĞİLDİR** (kullanıcı düzeltmesi): yasal bir FİŞ TAVANI
--   var; sepet o tutarı aşınca PERAKENDE müşteriye de fatura kesilir. Eşik
--   TAHMİN EDİLMEDİ, blok 0b ile VERİDEN OKUNDU.
-- ⚠ Belge tipi kümesi dışına çıkan satır 'z) TANIMSIZ' olarak AYRI raporlanır —
--   sessizce bir tarafa karışmasın (liste elle yazılmaz kuralı). ÇIKMADI.

/* ── 0b) ★★ FİŞ TAVANI VERİDEN OKUNDU ──────────────────────────────────────── */
SELECT s.DocumentsTypeId AS tip, YEAR(s.Date) AS yil, COUNT(*) AS belge,
       CONVERT(decimal(18,2), MAX(s.GrossTotal - s.DiscountTotal)) AS max_brut,
       CONVERT(decimal(18,2), AVG(s.GrossTotal - s.DiscountTotal)) AS ort_brut,
       SUM(CASE WHEN (s.GrossTotal - s.DiscountTotal) > 12000 THEN 1 ELSE 0 END) AS ustu_12k,
       SUM(CASE WHEN (s.GrossTotal - s.DiscountTotal) > 30000 THEN 1 ELSE 0 END) AS ustu_30k
FROM   EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE  s.Date >= '20240901' AND s.DocumentsTypeId IN (1,2)
GROUP BY s.DocumentsTypeId, YEAR(s.Date)
ORDER BY tip, yil;
/* ⭐ TAVAN GERÇEK VE KESKİN:
   tip  yıl    belge      max_brut      ort_brut   >12.000 ₺  >30.000 ₺
    1  2025   508.826   **9.900,00**      714,54       0          0
    1  2026   749.891  **12.000,00**      708,76       0          0
    2  2025     2.453     53.528,00     3.173,97     107          7
    2  2026     3.532     48.098,00     3.095,16     236          9
   ⇒ Fiş tavanı VERİDEN OKUNDU: 2025 = 9.900 ₺ · 2026 = **12.000 ₺**. Üstünde
     TEK FİŞ YOK. Kullanıcının sayısı birebir doğrulandı; tavanın yıla göre
     DEĞİŞTİĞİ de görüldü — sabit eşik yazmak eski yılı yanlış sınıflardı.
   ⇒ AMA AYRIM PRATİKTE KÜÇÜK: `2`nin ortalaması 3.095 ₺, yani ÇOĞU tavanın
     ALTINDA — yasa zorlaması değil, fatura İSTEYEN müşteri. Tavanı aşan 236 belge
     (2026). `2`nin toplam cirosu 14,0M ₺ = kasa cirosunun %1,2.
   ⇒ KARAR: `2` AYRI kanal olarak raporlanır, perakendeye KARIŞTIRILMAZ; ama
     maddi etkisi olmadığı için İKİYE BÖLÜNMEDİ. Gerekçe ÖLÇÜLDÜ, varsayılmadı.
     (Blok 2 bunu bağımsız destekliyor: `2`nin marjı %36,4, perakende %37,3.) */

/* ── 1) ★ KANAL BÜYÜKLÜĞÜ ──────────────────────────────────────────────────── */
SELECT CASE WHEN s.DocumentsTypeId IN (1,3) THEN 'a) PERAKENDE fis+iade'
            WHEN s.DocumentsTypeId = 8      THEN 'b) SINAV OKULLARI'
            WHEN s.DocumentsTypeId = 2      THEN 'c) FATURA'
            WHEN s.DocumentsTypeId IN (6,7) THEN 'd) PERSONEL'
            ELSE 'z) TANIMSIZ tip=' + CONVERT(varchar(10), s.DocumentsTypeId) END AS kanal,
       COUNT(DISTINCT s.Id) AS belge,
       CONVERT(decimal(18,0), SUM(CASE WHEN s.DocumentsTypeId = 3
              THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
              ELSE  (s.GrossTotal - s.DiscountTotal - s.VatTotal) END)) AS NET_CIRO
FROM   EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE  s.Date >= DATEADD(MONTH,-12,GETDATE())
GROUP BY CASE WHEN s.DocumentsTypeId IN (1,3) THEN 'a) PERAKENDE fis+iade'
            WHEN s.DocumentsTypeId = 8      THEN 'b) SINAV OKULLARI'
            WHEN s.DocumentsTypeId = 2      THEN 'c) FATURA'
            WHEN s.DocumentsTypeId IN (6,7) THEN 'd) PERSONEL'
            ELSE 'z) TANIMSIZ tip=' + CONVERT(varchar(10), s.DocumentsTypeId) END
ORDER BY kanal;
/* ⭐⭐ SON 12 AY, NET KDV HARİÇ (üç mağaza):
   a) PERAKENDE (fiş+iade)  1.151.296 belge   **709.240.570 ₺**
   b) SINAV OKULLARI            7.047 belge   **406.391.952 ₺**   ← %36
   c) FATURA                    5.191 belge      13.996.180 ₺   (%1,2)
   d) PERSONEL                  9.542 belge      10.657.742 ₺
   TOPLAM 1.140.286.444 ₺ · 'z) TANIMSIZ' satırı ÇIKMADI (belge kümesi kapalı).
   ⇒ **AYIRMAK ŞARTMIŞ**: Sınav tek başına kasa cirosunun %36'sı. Ayrılmasaydı
     "mağaza marjı" diye raporlanan sayının üçte biri okul kanalından gelirdi.
   ⚠ `Sales.Date` — `SaleDate` DİYE BİR KOLON YOK (entities: EncoreMerkez.Sales).
   ⚠ Header indirimi `DiscountTotal`; `DiscountTotalDirect` HEADER'da YOKTUR. */

/* ── 2) ★★★ BRÜT MARJ — KANAL AYRIK, KENDİ HESABIMIZ ───────────────────────── */
-- SATIŞ ucu = kasada FİİLEN tahsil edilen, KDV hariç, SATIR bazında
-- ALIŞ  ucu = alış faturasının BİRİM NET fiyatı (fat eTip=0 + fatAyr), KDV hariç
--
-- ⭐ NEDEN `posMaliyet` / `fytOzl` DEĞİL (kullanıcı: "o kolona takılma"):
--   Kanonik maliyet yolu `fytOzl` (fTur=1/fTip=1) üzerinden akıyor ve `urnBilgi`
--   228 "Odak Alış Fiyat Güncellenmesin" bayrağı 114.977 üründe o satırın
--   yazılmasını DURDURUYOR ⇒ maliyet bayatlıyor (ölçüldü: taze %24,9 vs bayraksız
--   %35,6). Marjı o alandan okumak, bayrağın etkisini sessizce marja taşır.
-- ⭐ HİÇBİR YERDE İSKONTO ORANI KULLANILMIYOR (12.09 dersi, commit 524bd02):
--   ne marka vekili `odak_marka.discount`, ne fatura `ehIndirim` oranı ekonomiyi
--   ölçer — ikisi de bir SUNUM tercihini ölçer. Yalnız BİRİM NET FİYAT kullanılır.
WITH sat AS (
  SELECT CASE WHEN s.DocumentsTypeId IN (1,3) THEN 'a) PERAKENDE'
              WHEN s.DocumentsTypeId = 8      THEN 'b) SINAV'
              WHEN s.DocumentsTypeId = 2      THEN 'c) FATURA'
              ELSE 'd) PERSONEL' END AS kanal,
         CONVERT(int, p.Code) AS stkID,
         SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -sp.Amount ELSE sp.Amount END) AS adet,
         SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(sp.TotalPrice - sp.VatTotal)
                  ELSE  (sp.TotalPrice - sp.VatTotal) END) AS ciro
  FROM   EncoreMerkez.dbo.Sales s WITH(NOLOCK)
  JOIN   EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id
  JOIN   EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
  WHERE  s.Date >= DATEADD(MONTH,-12,GETDATE())
         AND s.DocumentsTypeId IN (1,2,3,6,7,8)
         AND sp.IsValid = 1                  -- ⚠ ZORUNLU, atlanırsa ciro şişer
         AND ISNUMERIC(p.Code) = 1           -- ⚠ compat 110: TRY_CONVERT YOK
  GROUP BY CASE WHEN s.DocumentsTypeId IN (1,3) THEN 'a) PERAKENDE'
              WHEN s.DocumentsTypeId = 8      THEN 'b) SINAV'
              WHEN s.DocumentsTypeId = 2      THEN 'c) FATURA'
              ELSE 'd) PERSONEL' END, CONVERT(int, p.Code)
), al AS (
  SELECT a.ehStkID AS stkID,
         SUM(a.ehTutarN) / NULLIF(SUM(a.ehAdetN),0) AS birim
  FROM   DerinSISBkm.dbo.fat f WITH(NOLOCK)
  JOIN   DerinSISBkm.dbo.fatAyr a WITH(NOLOCK) ON a.ehID = f.eID
  WHERE  f.eTip = 0                           -- ⚠ SADECE ALIŞ FATURASI
         AND f.eTarih >= DATEADD(MONTH,-24,GETDATE())
         AND a.ehTutar > 0 AND a.ehAdetN > 0
  GROUP BY a.ehStkID
)
SELECT sat.kanal,
       CASE WHEN al.stkID IS NULL THEN '2-OLCULEMEZ' ELSE '1-olculebilir' END AS durum,
       COUNT(DISTINCT sat.stkID) AS urun,
       CONVERT(decimal(18,0), SUM(sat.ciro))                AS CIRO,
       CONVERT(decimal(18,0), SUM(sat.adet * al.birim))     AS SMM,
       CONVERT(decimal(18,0), SUM(sat.ciro) - SUM(sat.adet * al.birim)) AS BRUT_KAR,
       CONVERT(decimal(10,1), 100.0*(SUM(sat.ciro) - SUM(sat.adet * al.birim))
                              / NULLIF(SUM(sat.ciro),0))    AS MARJ
FROM   sat LEFT JOIN al ON al.stkID = sat.stkID
GROUP BY sat.kanal, CASE WHEN al.stkID IS NULL THEN '2-OLCULEMEZ' ELSE '1-olculebilir' END
ORDER BY sat.kanal, durum;
/* ⭐⭐⭐ KANAL BAZINDA BRÜT MARJ:
   kanal      durum          ürün      CİRO ₺        SMM ₺       BRÜT KÂR ₺    MARJ
   PERAKENDE  ölçülebilir 128.233  689.933.105  432.586.658  257.346.447  **%37,3**
   PERAKENDE  ÖLÇÜLEMEZ    24.124   19.317.128        —            —         —
   SINAV      ölçülebilir   6.816   93.935.743   37.618.592   56.317.151    %60,0
   SINAV      ÖLÇÜLEMEZ     1.017 **312.456.209**     —            —         —
   FATURA     ölçülebilir  19.348   12.669.373    8.059.239    4.610.134    %36,4
   FATURA     ÖLÇÜLEMEZ     2.259    1.326.808        —            —         —
   PERSONEL   ölçülebilir  17.272   10.502.322    7.151.594    3.350.729    %31,9
   PERSONEL   ÖLÇÜLEMEZ     1.102      155.419        —            —         —

   ⇒ **PERAKENDE KAPSAMI SAĞLAM**: ölçülemeyen 19,3M ₺ = cironun %2,7'si.
   ⇒ **FATURA (%36,4) PERAKENDEYE ÇOK YAKIN (%37,3)** — `2` ayrı bir iş değil,
     ağırlıkla fatura isteyen/tavanı aşan perakende. Blok 0b'yi bağımsız destekler.
   ⇒ PERSONEL %31,9 — personel indirimi marjı 5,4 puan düşürüyor (beklenen yön).
   ⚠⚠ **SINAV'IN %77'Sİ ÖLÇÜLEMİYOR (312,5M ₺ / 1.017 ürün) ve bu bir VERİ KUSURU
     DEĞİL, İŞ MODELİ FARKI**: o ciro "X. SINIF SÜRELİ YAYIN 2026" paketlerinden
     geliyor (birim ~55.000 ₺; 2.sınıf 28,4M/509 adet · 3.sınıf 27,4M/497 ·
     1.sınıf 24,3M/431 · 9.sınıf 23,6M/448 · 8.sınıf 23,2M/443 …), marka
     "SINAV OKULLARI". Kendi yayını/hizmeti olduğu için ALIŞ FATURASI YOK.
     ⇒ Sınav kârlılığı BU YOLLA ÖLÇÜLEMEZ; ayrı maliyet yolu ister (basım/telif/
       öğretmen). Ölçülen %60,0 yalnız Sınav'ın SATIN ALDIĞI malın marjıdır,
       KANALIN marjı DEĞİLDİR — karıştırılmamalı.
   ⚠ "OLCULEMEZ" satırı raporda KALIR ve cirosu yazılır: "sıfır" değil, "bakamadım". */

/* ── 3) ★★ PERAKENDE MARJI — KATEGORİ KIRILIMI ─────────────────────────────── */
-- `sat` CTE'si `DocumentsTypeId IN (1,3)` ile daraltıldı; kategori
-- `urn` → `urnKtgr2.ktgrAd` (ktgr2Ad HATA). `WHERE sat.ciro > 0`.
/* kategori            ürün      CİRO ₺       BRÜT KÂR ₺     MARJ    zararına ürün / ciro
   Hazırlık Kitapları  9.770  150.311.253   57.213.643    %38,1      220 /   469.717
   **Kırtasiye**      17.408  137.338.964   58.987.041  **%42,9**    766 / **5.140.508**
   Kitap              44.724  129.104.276   44.144.349    %34,2      677 /   889.087
   Çocuk Kitabı       32.429  103.617.794   34.224.578    %33,0      432 /   151.704
   Oyuncak             8.092   92.296.558   33.757.623    %36,6       44 /   759.006
   Akademi            10.070   30.711.482   10.403.323    %33,9      239 /   112.688
   Hediyelik           2.313   21.846.301    9.308.778    %42,6       36 /   238.547
   Gıda                  784    8.514.089    3.500.193    %41,1        5 /     5.607
   Sınav Kıyafet         195    6.253.564    3.090.199    %49,4        2 /    28.722
   Elektronik            987    4.806.663    1.896.992    %39,5       25 /    35.986
   Kişisel Bakım          71    2.926.343    1.099.103    %37,6        1 /    30.428
   **Dergi**             556    2.394.488      400.298  **%16,7**      4 /    22.470
   Genel                  15      147.071     −301.361   %−204,9       6 /   107.890
   Etkinlik                1          168      −82.677        —        1 /       168

   ⇒ **KIRTASİYE EN KÂRLI KALEM (%42,9 · 59,0M ₺ brüt kâr)** — 12.09'da web
     tarafında "en sorunlu kategori" görünüyordu; MAĞAZADA TAM TERSİ. Fark kanal:
     web listeden ~%35+ indirimle satıyor, mağaza satmıyor.
   ⇒ Kırtasiye aynı zamanda zararına satışın yoğunlaştığı yer: 766 ürün / 5,1M ₺
     (perakende zararına cirosunun ~%60'ı). Kârlı kategori, kusurlu kuyruk.
   ⇒ **DERGİ %16,7** — tek başına düşük. Dergi iş modeli (sabit fiyat, düşük
     iskonto, iade hakkı) gereği olabilir AMA ÖLÇÜLMEDİ ⇒ AÇIK SORU.
   ⚠ `Genel` (−%204,9) ve `Etkinlik` (168 ₺ ciroya 82.845 ₺ SMM) AYKIRI DEĞER:
     15 ve 1 ürün. Ciroları ihmal edilebilir ama SMM'leri gerçek — büyük ihtimalle
     satış birimi ile fatura birimi farklı (koli vs adet). İNCELENMEDİ. */

/* ── 4) ★ ÜÇ ŞUBE AYNI PERAKENDE MARJINI MI YAPIYOR ───────────────────────── */
/* mağaza            CİRO ₺        BRÜT KÂR ₺    MARJ    zararına ürün / ciro
   ÖZLÜCE        299.066.981   110.714.512   %37,0     1.889 / 3.177.427
   FSM Mağaza    206.699.275    78.195.367   %37,8     1.466 / 2.619.873
   IST YOLU MGZ  184.773.935    68.871.188   %37,3     1.503 / 2.647.013
   ⇒ **ÜÇ ŞUBE 0,8 PUAN İÇİNDE.** Marj farkı şubeden değil ürün karmasından gelir;
     "hangi mağaza daha iyi yönetiliyor" sorusu BU TABLOYLA YANITLANMAZ.
   ⇒ İst.Yolu'nun düşük görünme riski ortadan kalktı: Sınav ayrı kanalda
     (406,4M ₺) olduğu için buradaki 184,8M ₺ SAF PERAKENDEDİR. */

/* ── 5) KOŞULMAYAN BLOKLAR — açıkça beyan ─────────────────────────────────── */
-- (a) Zararına ürünlerin ÜRÜN BAZLI aksiyon listesi KOŞULMADI. Toplamı biliniyor
--     (perakendede ~8,4M ₺ ciro / ~4.858 ürün-şube satırı) ama zararın KAMPANYA mı
--     ALIŞ mı kaynaklı olduğu ayrıştırılmadı. Ayrıştırma için iki sütun eklenecek:
--       `urn.kod4ID` → `urnkod4.kod4Ad`  (kartta adı "Reyon", İÇERİĞİ KAMPANYA —
--          codes:urn.kod4ID; gerçek raf/planogram AYRI: `ryn.*`)
--       `urnBilgi` 228 bayrağı (bDeger='True')
-- (b) MUTABAKAT KOŞULMADI: taban `posOzetUrun`dan `SalesProducts`a taşındı ama
--     taşımanın doğruluğu ÖLÇÜLEREK gösterilmedi. Sema'da iki kanonik kimlik var:
--       `posOzetUrun` ↔ `irsHrk` (ehTip=100/101) kuruşu kuruşuna;
--       ERP kanonik ciro = `eTip 100 − 101 + 4 − 5`.
--     Karşılaştırma KAPALI GÜN ile yapılmalı: kasa→ERP aktarımı SAATLİK olduğu
--     için açık günde ERP eksiktir (12.09: kapalı gün %0,00 · açık gün +%2,50..4,18).

/* ============================================================================
   SINIRLAR (ölçümden ÖNCE yazıldı ki sonuç bunları yumuşatmasın)
   · PENCERE UYUŞMAZLIĞI: satış 12 ay, alış 24 ay. Birim alış 24 ayın ağırlıklı
     ortalamasıdır; enflasyonlu dönemde SMM'yi OLDUĞUNDAN DÜŞÜK gösterir ⇒
     **%37,3 İYİMSERDİR.** Katmanlı (parti bazlı) düzeltme: `metrics:fifo_marj`.
   · Birim alış = ΣehTutarN/ΣehAdetN — BASİT ağırlıklı ortalama, FIFO değil.
   · BELGE-BAZLI ölçüm yalnız Ağu-2025 sonrası güvenli (POS geçişi). Pencere
     13.09.2025'te başlıyor ⇒ şart sağlanıyor; UZATILIRSA kırılır.
   · `fat.eTip=0` yalnız ALIŞ FATURASI. `fat.eTip=10` İADE FARK FATURASIDIR, alış
     DEĞİL; `irsHrk.ehTip=10` ise Yerel Alım — iki sözlük AYRIDIR.
   · `fatAyr.ehTutarN` yalnız `eTip=4`te bozuk (entities:fatAyr) — burada eTip=0
     kullanıldığı için etkilenmiyor. Kapı: değişmez `alis-fatura-net-kimligi`.
   · Ürün köprüsü `Products.Code = urn.stkID` (%99,98). **`stkKod` = barkod DEĞİL**;
     `BarcodeNo = stkKod` join'i Oyuncak cirosunu 700K gösteriyordu, gerçeği 10,96M.
   · Kapsam üç mağaza. Merkez depo (12) · e-ticaret (4479) · İade Deposu (4480)
     DIŞARIDA — defterde DOKUZ mekan var (codes:mekanID); bu bir KAPSAM SEÇİMİDİR.
   · Kargo/personel/kira/komisyon/fire YOK — BRÜT marjdır, NET KÂR DEĞİLDİR.
   · "DİĞER" homojen değil: Sınav (8) okul, personel (6,7) çalışan, fatura (2)
     karışık. Tek sepette yorumlanmaz; bu yüzden dördü AYRI raporlanıyor.
   ============================================================================ */
