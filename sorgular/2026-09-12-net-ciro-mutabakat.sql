/* ============================================================================
   net_ciro METRİĞİ — KANIT KOŞUMU + BAĞIMSIZ MUTABAKAT  (2026-09-12)
   DB: DerinSISBkm + EncoreMerkez (profil: erp)

   NEDEN: `metrics:net_ciro` sema'nın EN ÇOK ATIF ALAN metriği (ölçüldü 2026-09-12 —
   kendi tanımı hariç repoda 36 geçiş / 12 dosya) ve `evidence` alanı BOŞTU.
   `_metrik_kanit_durumu_2026_09_12` kaydındaki 107 işaretçisiz metriğin İLKİ olarak
   kapatılıyor.

   YÖNTEM (kaydın kendi kapatma ölçütü): formülü KOŞTUR → BAĞIMSIZ bir kaynakla
   karşılaştır → sapmayı tarihiyle yaz. "Formül yazılı" kanıt değildir.

   ⚠ KAPSAM EŞLEŞMESİ (olctum-mu-cikardim-mi § kural 2): iki taraf AYNI süzgeçle
     ölçülmeli. irsHrk tarafı `ehAltDepo=0` + 3 POS mekanı; EncoreMerkez tarafı
     `DocumentsTypeId IN (1,2,3,6,7,8)` + iade (3) negatif işaretli. Sınav kanalı
     İKİ tarafta da içeride (irsHrk `ehTip=4` ↔ Encore `DocumentsTypeId=8`).
   ============================================================================ */

/* 1) SEMA FORMÜLÜ — bileşenleriyle birlikte (tek tek görünsün diye ehTip kırılımlı) */
SELECT h.ehMekan, h.ehTip,
       CONVERT(decimal(18,2), SUM(h.ehTutarN)) AS tutar,
       COUNT_BIG(*) AS satir
FROM   DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
WHERE  h.ehTip IN (1,3,4,5,100,101)      -- formülün artı (1,4,100) ve eksi (3,5,101) uçları
  AND  h.ehAltDepo = 0
  AND  h.ehTrhS >= '20260801' AND h.ehTrhS < '20260901'
  AND  h.ehMekan IN (1, 4477, 4478)
GROUP BY h.ehMekan, h.ehTip
ORDER BY h.ehMekan, h.ehTip;
/* NET = SUM(1,4,100) − SUM(3,5,101). Ölçüm Ağu-2026 (KDV hariç):
     mekan 1    (FSM)      17.765.930,26 − 397.654,74   =  17.368.275,52
     mekan 4477 (Özlüce)   27.038.632,71 − 587.147,47   =  26.451.485,24
     mekan 4478 (İst.Yolu) 142.182.133,25 − 1.684.451,65 = 140.497.681,60
   ⚠ ÖLÇÜLEN YAN BULGU: formülün `ehTip=1` (Satış) terimi bu ÜÇ MAĞAZADA DA SIFIR.
     `ehTip=1` canlıda en büyük tip (31,2M satır) ama POS mağazalarında hiç yok —
     başka mekanlarda (depo/merkez) duruyor. Yani formül ÇOK KANALLI; mağaza
     ölçümünde `1` terimi taşınıyor ama katkısı yok. Bu bir hata değil, KAPSAM
     bilgisidir ve kayda yazıldı. */

/* 2) BAĞIMSIZ KAYNAK — EncoreMerkez POS başlığı.
      Net KDV-hariç = GrossTotal − DiscountTotal − VatTotal (sql-server-conventions).
      İade (DocumentsTypeId=3) negatif işaretle düşülür. */
SELECT s.StoresId,
       CONVERT(decimal(18,2), SUM(CASE WHEN s.DocumentsTypeId = 3
              THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
              ELSE  (s.GrossTotal - s.DiscountTotal - s.VatTotal) END)) AS net_kdv_haric,
       COUNT_BIG(*) AS belge
FROM   EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE  s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND  s.Date >= '20260801' AND s.Date < '20260901'
GROUP BY s.StoresId
ORDER BY s.StoresId;
/* Stores 1 → 139.696.939,15 (25.135 belge) · 2 → 17.137.629,93 (27.153) ·
   3 →  26.380.600,59 (33.091). */

/* 3) MUTABAKAT — mekan ↔ Stores eşlemesi CLAUDE.md'den:
      FSM mekan 1 ↔ Encore 2 · Özlüce 4477 ↔ 3 · İst.Yolu 4478 ↔ 1

     mağaza     sema (irsHrk)     Encore (bağımsız)    fark          sapma
     FSM         17.368.275,52     17.137.629,93       +230.645,59   +%1,35
     Özlüce      26.451.485,24     26.380.600,59        +70.884,65   +%0,27
     İst.Yolu   140.497.681,60    139.696.939,15       +800.742,45   +%0,57

   ⇒ ÜÇ MAĞAZADA DA %1,35 İÇİNDE TUTUYOR. `sql-server-conventions` § ŞUBE CİROSU
     zaten kanonik formülün Encore ile %0,08-1,28 içinde tuttuğunu yazıyordu;
     bu koşum onu Ağu-2026 için YENİDEN ÜRETTİ.

   ⚠ SAPMA SIFIR DEĞİL ve "tuttu" demek "eşit" demek değildir. Kalan farkın kaynağı
     ÖLÇÜLMEDİ (bilinen adaylar: iade zamanlama farkı, adet düzeltmeleri, gün sınırı).
     Sapmayı sıfırlamak ayrı bir iştir; burada iddia edilen tek şey İKİ BAĞIMSIZ
     YOLUN AYNI BÜYÜKLÜĞÜ VERDİĞİdir. */

/* ============================================================================
   4) KASA AYRIMI — kullanıcı sorusu: "kasa ile bakacaksan 100/101 bakman lazım"
   Ölçüldü ve cevap BEKLENENDEN FARKLI çıktı.
   ============================================================================ */

/* 4a) Encore tarafını BELGE TİPİNE göre aç — kasanın içinde ne var? */
SELECT s.StoresId, s.DocumentsTypeId,
       CONVERT(decimal(18,2), SUM(CASE WHEN s.DocumentsTypeId = 3
              THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
              ELSE  (s.GrossTotal - s.DiscountTotal - s.VatTotal) END)) AS net,
       COUNT_BIG(*) AS belge
FROM   EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE  s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND  s.Date >= '20260801' AND s.Date < '20260901'
GROUP BY s.StoresId, s.DocumentsTypeId
ORDER BY s.StoresId, s.DocumentsTypeId;
/* Stores 1 (İst.Yolu): Fiş 19.372.671 · Fatura 759.549 · İade −1.677.234 ·
   PersFiş 136.533 · PersFatura 76.776 · **SINAV(8) 121.028.643** (2.031 belge).
   Stores 2 (FSM) ve 3 (Özlüce): SINAV kaydı YOK. */

/* 4b) ÜÇ VARYANT — hangisi kasayla tutuyor? (Ağu-2026, KDV hariç)

     mağaza    100−101        sapma     100−101+4−3−5    sapma     Encore (kasa)
     FSM       16.970.003    −%0,98     17.368.276      +%1,35     17.137.630
     Özlüce    26.081.231    −%1,13     26.451.485      +%0,27     26.380.601
     İst.Yolu 126.420.476    −%9,50    140.497.682      +%0,57    139.696.939

   ⇒ YALNIZ `100−101` İST.YOLU'NDA %9,5 AÇIK VERİR. Sebep: kasa (Encore) Sınav
     faturasını da kaydediyor; ERP tarafında o tutarın bir kısmı `eTip 4`'te.
     Kasa mutabakatı için `4` DIŞARIDA BIRAKILAMAZ. */

/* 4c) ★ KANAL EŞLEŞMESİ — iki uç var, biri mükemmel biri hiç tutmuyor */
/*  İADE UCU — KURUŞU KURUŞUNA:
      Encore DocumentsTypeId=3   ↔   irsHrk ehTip=101
        İst.Yolu  1.677.233,65   ↔   1.677.234   (fark 0,35 ₺)
        FSM         393.405,63   ↔     393.406   (fark 0,37 ₺)
        Özlüce      572.176,67   ↔     572.177   (fark 0,33 ₺)
      ⇒ Sema'daki `irshrk-pos-encore` köprüsü "grain uyarısı" diye ölçülemez
        işaretliydi; İADE UCU için ölçülebilir ve BİREBİR tutuyor.

    SINAV UCU — HİÇ TUTMUYOR:
      Encore DocumentsTypeId=8 (Sınav) 121.028.642,80
      irsHrk ehTip=4                    14.084.423,00   → 8,6 KAT fark
      ⇒ Sınav'ın ~107M'si `ehTip=100`'ün İÇİNDE (günlük ÖZET belge).
      ⚠ Bu, kuraldaki "Sınav Okulları toplu faturaları eTip 4'ten akar" ifadesini
        YANILTICI kılıyordu ve düzeltildi (sql-server-conventions 2026-09-12).
        İki iddia ters yönde: "eTip 4'ün İÇERİĞİNİN %86-89'u Sınav" DOĞRU olabilir;
        ama "SINAV'IN çoğu eTip 4" YANLIŞ. `eTip 4` Sınav VEKİLİ DEĞİLDİR. */
