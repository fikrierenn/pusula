/* ═══════════════════════════════════════════════════════════════════════════════
   AĞU–EYL 2026 ALIM RÖNTGENİ — ARZ GÜNÜ + COLD-START AYRIMI        10.09.2026
   (arşiv borcu 11.09'da kapatıldı — semantic-layer § ikiz yükümlülük)

   Soru (kullanıcı): "sezon için verilen siparişleri verilmiş olarak görme, sen olsan ne
   sipariş verirdin" → önce ELDEKİ alım kararlarının röntgeni çekildi.

   ═══ MANZARA (ÖLÇÜLDÜ, 01.08.2026 – 10.09.2026) ════════════════════════════════
   Net alım (Alış 0 + Yerel Alım 10 − Alış İade 2): **151,2M ₺ · 34.140 çeşit · ~860K adet**
     Yerel Alım (10)  30.979 çeşit · 481.976 adet · 113,8M ₺
     Alış (0)          4.532 çeşit · 445.433 adet ·  35,2M ₺
     Alış İade (2)       149 çeşit · −66.840 adet ·  −2,2M ₺

   ═══ ARZ GÜNÜ DAĞILIMI (alınan adet ÷ günlük satış hızı) ═══════════════════════
     Tabanda yok (okul ders kitabı) 1.179 çeşit ·  89.056 adet · 25,4M ₺ · %16,8
     Satışsız (365g hiç satmamış)   3.379       · 116.154      · 11,5M  ·  %7,6
     ≤30 gün (sıkı)                 4.095       ·  31.947      ·  5,2M  ·  %3,4
     30–90 gün (sağlıklı)           9.486       · 112.132      · 26,2M  · %17,3
     90–180 gün                     5.983       ·  69.778      · 17,6M  · %11,6
     180–365 gün (ağır)             4.016       ·  65.380      · 13,6M  ·  %9,0
     >365 gün (1 yıldan fazla arz)  6.029       · 440.860      · 49,7M  · %32,9
   İlk bakış: adetin %51'i, paranın %33'ü >1 yıllık stok. ⚠ BU HÂLİYLE RAPORA YAZILAMAZ.

   ═══ ÜÇ TUZAK — ikisi ölçülüp ayıklandı, biri beyan edildi ═════════════════════
   1) COLD-START (yeni ürün): satış geçmişi olmayan ürünün ilk stoklaması otomatik
      "sonsuz arz" görünür. `IlkGiris` ile ayrıldı →
        >365 kovası: YENİ 32,4M (%65) · ESKİ 17,4M (%35)
        satışsız  : YENİ 6,95M · ESKİ 4,54M
      Yani aşırı görüntüsünün ÜÇTE İKİSİ yeni ürün lansmanı — meşru, ölü stok değil.
   2) "TABANDA YOK" 25,4M = Sınav Okulları ithal kurs kitabı (Options, Life Vision,
      Universal Goals, Raz Plus; hepsi urnTip 0). Kurumsal kesin alım → perakende
      hızıyla ölçülmez, yargıdan ÇIKAR.
   3) SAĞDAN SANSÜR + payda kararsızlığı (ÇIKARIM sınırı): stok bitince satış kesilir →
      hız düşük görünür → arz günü YÜKSEK çıkar. "Aşırı" tarafı ABARTILI; gerçek fazlalık
      bundan azdır. Ayrıca yavaş devirli üründe metrik patlar (yılda 8 satana 2 koli =
      >1 yıl) — MOQ zorlaması olabilir, tek başına "kötü karar" kanıtı DEĞİL.

   ═══ HESAP SORULACAK DİLİM (ÜST SINIR) ═════════════════════════════════════════
     >365 ESKİ 17,4M + satışsız ESKİ 4,54M ≈ 21,9M ₺ (10.09 akşamı verilen rakam)

   ⚠ DÜZELTME 11.09.2026 — o 21,9M **YAŞI BİLİNMEYENİ DE ESKİ SAYIYORDU.** Yaş ayracı
     `IlkGiris >= ... THEN 'YENİ' ELSE 'ESKİ'` yazılmıştı; `IlkGiris NULL` (mağaza rafına
     hiç çıkmamış, yalnız depoda duran ürün) sessizce ESKİ kovasına düşüyordu. Ölçüldü:
       YENİ (<1 yıl)              4.599 çeşit · 316.523 adet · 39,33M ₺   (cold-start, meşru)
       ESKİ (≥1 yıl, yaşı BİLİNEN) 4.501 çeşit · 161.497 adet · **18,27M ₺**  ← hesap sorulur
       YAŞI BİLİNMİYOR (NULL)        307 çeşit ·  78.990 adet ·  3,65M ₺   ← AYRI kova
     Yani hesap sorulacak dilim **18,3M ₺ (%12,1)**, 21,9M değil. Aradaki 3,65M "eski" diye
     yargılanamaz — yaşı ölçülmemiştir (rafa hiç çıkmamış olabilir: yeni de olabilir, kalıntı
     da). `olctum-mu-cikardim-mi` § BULGUYU ölçüp KARARI tahmin etme.
     Excel emitter'ı (`scripts/asiri_alim_excel.py`) zaten `IlkGiris < DATEADD(YEAR,-1,…)`
     yazdığı için NULL'ları DIŞARIDA bırakıyordu → iki emitter 3,65M ayrışıyordu; fark
     ölçülünce sebep çıktı (veri-dogrula § cross-source sweep).
   Kalan ~129M: sağlıklı arz (30–180g, %29) · yeni ürün bahsi (~4.600 çeşide ~39M) ·
   kurumsal kesin talep. Yoğunlaşma: çeşitlerin %20'si paranın %86'sını taşıyor (ABC normal).

   ═══ İKİ KAÇIŞ HİPOTEZİ — ÖLÇÜLDÜ ve ÇÜRÜDÜ ═══════════════════════════════════
   · DERYA — Mopak A4 fotokopi kağıdı, 919K ₺ tek kalem, 7.680 adet.
     Hipotez "iç tüketim (sınav baskısı)" → RED: iç kullanım (tip 98) 12 ayda 8 adet.
     Gerçek yıllık çıkış ≈ 2.185 (POS 1.142 + toptan Satış 970 + mağaza 73) → ~3,5 yıllık stok.
     Sonuç: talep kararı DEĞİL, finansal karar (enflasyon/fiyat hedge?). Alıcıya sorulacak:
     "bu bir fiyat kilidi miydi, ne kadar tasarruf?" — değilse aşırı.
   · YANIT — 22 sınav hazırlık kitabı, 3,76M ₺.
     Hipotez "Sınav Okulları'na kurumsal toplu dağıtım" → RED: 12 ayda depo→mağaza transfer
     2 adet. Hepsi perakende satılıyor (POS 4.282 + mağaza 468 ≈ 4.750/yıl) ama her biri
     700–1.000 günlük stokla alınmış. Hafifletici: alım sezon başı (365g düz hız Eyl-Ara
     zirvesini az sayar) + çoğu 3-6 belgeli tekrar-ikmal. Ağırlaştırıcı: sınav hazırlık
     kitabının İÇERİK ÖMRÜ var — format/müfredat değişince eski baskı satılamaz.

   ⚠ Alıcıya atıf YAPILAMAZ: kararı kimin verdiği veride izli değil (yalnız
     `bkm.OneriSiparisTalep`). Bunlar ürün/tedarikçi kohortudur, kişi karnesi değil.

   Emitter: `scripts/asiri_alim_excel.py` (3 sayfa: kategori · tedarikçi · ürün) →
            `raporlar/asiri-alim-agu-eyl-2026.xlsx`
   Köprü  : `irs.eFirma → frm.frmID` (sema `bridges.yaml` → `irs-firma`, confidence 1.0).
            ⚠ Bu köprü CANLI keşfedildi, halbuki sema'da tanımlıydı → `before-major-change.md`
            § Fact-Force Gate vakası olarak yazıldı: SEMA İLK, canlı doğrulama SONRA.
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── 1) ARZ GÜNÜ DAĞILIMI ───────────────────────────────────────────────────────
   Alım = ehTip 0 (Alış) + 10 (Yerel Alım) + 2 (Alış İade, negatif) — irsTip_vw.
   ⚠ `fat.eTip=10` BAŞKA ŞEY (İade Fark Faturası); irsHrk ve fat AYRI sözlükler. */
WITH alim AS (
    SELECT h.ehstkID AS stkID,
           SUM(h.ehAdetN)  AS AlinanAdet,
           SUM(h.ehTutarN) AS AlinanTutar
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehTrhS >= '20260801' AND h.ehTrhS < '20260911'
      AND h.ehTip IN (0, 10, 2)
    GROUP BY h.ehstkID
    HAVING SUM(h.ehAdetN) > 0          -- net giriş olanlar (iade netlenmiş)
),
j AS (
    SELECT a.stkID, a.AlinanAdet, a.AlinanTutar, t.SatisToplam,
           CASE WHEN ISNULL(t.SatisToplam, 0) > 0
                THEN a.AlinanAdet / (t.SatisToplam / 365.0) END AS ArzGun
    FROM alim a
    LEFT JOIN DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
           ON t.stkID = a.stkID
          AND t.Kesim = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban)
          AND t.SezonYil = 2025
)
SELECT Kova, COUNT(*) AS Cesit,
       CONVERT(bigint, SUM(AlinanAdet))  AS Adet,
       CONVERT(bigint, SUM(AlinanTutar)) AS Tutar
FROM (
    SELECT *, CASE
        WHEN SatisToplam IS NULL        THEN '0 tabanda YOK (okul ders kitabi / yeni)'
        WHEN ISNULL(SatisToplam, 0) = 0 THEN '1 satissiz (365g hic satmamis)'
        WHEN ArzGun <= 30               THEN '2 <=30 gun (siki)'
        WHEN ArzGun <= 90               THEN '3 30-90 gun (saglikli)'
        WHEN ArzGun <= 180              THEN '4 90-180 gun'
        WHEN ArzGun <= 365              THEN '5 180-365 gun (agir)'
        ELSE                                 '6 >365 gun (1 yildan fazla arz)'
    END AS Kova
    FROM j
) x
GROUP BY Kova
ORDER BY Kova;

/* ── 2) COLD-START AYRIMI — "aşırı"nın ne kadarı yeni ürün? ─────────────────────
   Bu blok olmadan 49,7M'nin tamamı ölü stok sanılırdı; %65'i yeni ürün çıktı. */
WITH alim AS (
    SELECT h.ehstkID AS stkID, SUM(h.ehAdetN) AS adet, SUM(h.ehTutarN) AS tutar
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehTrhS >= '20260801' AND h.ehTrhS < '20260911' AND h.ehTip IN (0, 10, 2)
    GROUP BY h.ehstkID HAVING SUM(h.ehAdetN) > 0
),
j AS (
    SELECT a.stkID, a.adet, a.tutar, t.SatisToplam,
           CASE WHEN ISNULL(t.SatisToplam, 0) > 0
                THEN a.adet / (t.SatisToplam / 365.0) END AS ArzGun,
           CASE WHEN t.IlkGiris >= DATEADD(YEAR, -1, CONVERT(date, '20260909'))
                THEN 'YENI (<1yil)' ELSE 'ESKI (>=1yil)' END AS Yas
    FROM alim a
    LEFT JOIN DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
           ON t.stkID = a.stkID
          AND t.Kesim = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban)
          AND t.SezonYil = 2025
)
SELECT CASE WHEN ISNULL(SatisToplam, 0) = 0 AND SatisToplam IS NOT NULL THEN 'satissiz'
            WHEN ArzGun > 365 THEN '>365 asiri' ELSE 'diger' END AS Kova,
       Yas, COUNT(*) AS Cesit,
       CONVERT(bigint, SUM(adet))  AS Adet,
       CONVERT(bigint, SUM(tutar)) AS Tutar
FROM j
WHERE (ISNULL(SatisToplam, 0) = 0 AND SatisToplam IS NOT NULL) OR ArzGun > 365
GROUP BY CASE WHEN ISNULL(SatisToplam, 0) = 0 AND SatisToplam IS NOT NULL THEN 'satissiz'
              WHEN ArzGun > 365 THEN '>365 asiri' ELSE 'diger' END, Yas
ORDER BY Kova, Yas;

/* ── 2b) YAŞ AYRACI — NULL'u ESKİ saymak 3,65M ₺'yi yanlış kovaya atıyordu ──────
   11.09.2026 düzeltmesi. `ELSE 'ESKI'` deseni NULL'u sessizce yutar; üç kova ayrı yazılır. */
DECLARE @kesim date = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban);
WITH alim AS (
    SELECT h.ehstkID AS stkID, SUM(h.ehAdetN) AS adet, SUM(h.ehTutarN) AS tutar
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehTrhS >= '20260801' AND h.ehTrhS < '20260911' AND h.ehTip IN (0, 10, 2)
    GROUP BY h.ehstkID HAVING SUM(h.ehAdetN) > 0
),
t AS (
    SELECT stkID, SatisToplam, IlkGiris FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = @kesim AND SezonYil = 2025
)
SELECT CASE WHEN t.IlkGiris IS NULL THEN 'YASI BILINMIYOR (IlkGiris NULL)'
            WHEN t.IlkGiris >= DATEADD(YEAR, -1, @kesim) THEN 'YENI (<1yil)'
            ELSE 'ESKI (>=1yil)' END AS Yas,
       COUNT(*) AS Cesit, CONVERT(bigint, SUM(a.adet)) AS Adet,
       CONVERT(bigint, SUM(a.tutar)) AS Tutar
FROM alim a JOIN t ON t.stkID = a.stkID
WHERE ISNULL(t.SatisToplam, 0) = 0 OR a.adet / NULLIF(t.SatisToplam / 365.0, 0) > 365
GROUP BY CASE WHEN t.IlkGiris IS NULL THEN 'YASI BILINMIYOR (IlkGiris NULL)'
              WHEN t.IlkGiris >= DATEADD(YEAR, -1, @kesim) THEN 'YENI (<1yil)'
              ELSE 'ESKI (>=1yil)' END
ORDER BY Tutar DESC;

/* ── 3) KOHORT DARLIĞI — sipariş listesi neden "çok az" görünüyordu ─────────────
   Kullanıcı: "çok çok az bu sipariş rakamları emin misin". ÖLÇÜLDÜ ve haklı çıktı:
   Kırtasiye satan (365g≥5) 18.292 çeşit · stok=0 kohortu 796 · KAPAK ALTI 1.687 çeşit /
   14.528 adet → liste gerçek ihtiyacın ~1/13'ünü gösteriyordu.
   Düzeltme `scripts/siparis_onerisi_excel.py`'a uygulandı (kohort artık kapak altı). */
WITH k AS (
    SELECT stkAd, SatisToplam, ToplamStok,
           ISNULL(LeadTime, 7) AS L,
           (SatisToplam / 365.0) * (ISNULL(LeadTime, 7) + 30) AS Kapak
    FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban)
      AND SezonYil = 2025 AND Kategori3 = N'Kırtasiye'
      AND SatisToplam >= 5 AND SatisFiyat > 0 AND ToplamStok >= 0
)
SELECT COUNT(*) AS Satan5_Toplam,
       SUM(CASE WHEN ToplamStok < Kapak THEN 1 ELSE 0 END)                      AS KapakAlti_Cesit,
       SUM(CASE WHEN ToplamStok < Kapak THEN CEILING(Kapak - ToplamStok) ELSE 0 END) AS Ikmal_Adet,
       SUM(CASE WHEN ToplamStok = 0 THEN 1 ELSE 0 END)                          AS Stok0_EskiKohort,
       SUM(CASE WHEN ToplamStok > 0 AND ToplamStok < Kapak THEN 1 ELSE 0 END)   AS StokVar_AmaAz
FROM k;

/* ── 4) TEDARİKÇİ KÖPRÜSÜ — 21,9M dilimin kime ait olduğu ───────────────────────
   Köprü sema'da: bridges.yaml → irs-firma (dbo.irs.eFirma → dbo.frm.frmID, conf 1.0).
   İlk sırada ODAK KİTAP-POİNT = grup şirketi/ilişkili taraf → Excel'de işaretli. */
SELECT TOP 20 f.frmID, LEFT(f.frmAd, 45) AS Tedarikci,
       COUNT(DISTINCT h.ehstkID)         AS Cesit,
       CONVERT(bigint, SUM(h.ehAdetN))   AS Adet,
       CONVERT(bigint, SUM(h.ehTutarN))  AS Tutar
FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
JOIN DerinSISBkm.dbo.frm f WITH (NOLOCK) ON f.frmID = i.eFirma
WHERE h.ehTrhS >= '20260801' AND h.ehTrhS < '20260911' AND h.ehTip IN (0, 10)
GROUP BY f.frmID, f.frmAd
ORDER BY SUM(h.ehTutarN) DESC;
