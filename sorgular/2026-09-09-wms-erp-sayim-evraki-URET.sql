/* ═══════════════════════════════════════════════════════════════════════════════
   WMS TOPLAMI ↔ ERP DEFTERİ → ± SAYIM EVRAKI ÜRETİCİ — **DRY-RUN / SALT-OKUMA**
                                                                        09.09.2026
   Kullanıcı tasarımı (verbatim): "zaten wms e dokunmyacak wms toplamını hesaplayıp
   erp ile bakacak +- sayım evrak girişi yapmalı"

   ⚠⚠⚠ HİÇBİR ERP / WMS TABLOSUNA YAZMA YOK. Yazma yalnız `#mutabakat` (tempdb) ve
   `@Haric` (tablo değişkeni) üzerinde — oturum kapanınca yok olurlar. `EXEC` yok.
   Çıktısı: çalıştırılacak `EXEC` satırlarının METNİ (kopyalanıp gözden geçirilmek üzere).
   Yazma kararı ve koşumu kullanıcıdadır. İlgili plan: plans/43-wms-erp-defter-esitleme.md

   ── TASARIM ────────────────────────────────────────────────────────────────────
   WMS'e DOKUNULMAZ. Yalnız ERP defteri düzeltilir:
     1. WMS toplamı ürün bazında hesaplanır (depo.stok_adres_palet_vw)
     2. ERP merkez defteri net bakiyesi hesaplanır (irsHrk, ehMekan=12)
     3. Fark = WMS − ERP
     4. Fark > 0 → ERP eksik → **GİRİŞ** sayım evrakı (@GC = 0)
        Fark < 0 → ERP fazla → **ÇIKIŞ** sayım evrakı (@GC = 1)
     5. Evrak `bkm.SayimIrsaliyeBaslikOlustur` + `bkm.SayimIrsaliyeSatirEkle` ile yazılır.
        Bu iki SP `irs`/`irsAyr`a yazar, `paletUrnTnm`e HİÇ dokunmaz → WMS güvende.
   `depo.sayimIsle` KULLANILMAZ: o SP aynı koşuda WMS'i de oynatır ve ehTutar=0 yazar.

   ── KAPSAM: ÇIKIŞ ALANI **DAHİL** (09.09.2026 ölçümüyle düzeltildi) ────────────
   Panel "satılabilir merkez stoğu" için `adrsAlanTipID IN (0,1)` kullanır (ÇIKIŞ =
   sevke hazır, ayrılmış mal). DEFTER MUTABAKATI BAŞKA BİR SORU: mal ÇIKIŞ alanında da
   hâlâ bizim ve ERP defterinde duruyor. ÖLÇÜLDÜ — mutabık ürün sayısı:
        RAF+GİRİŞ  409.229   ·   TÜM ALANLAR  417.812
        yalnız ÇIKIŞ dahil olunca mutabık olan: 9.820 ürün
        yalnız ÇIKIŞ hariç olunca mutabık olan: 1.237 ürün
   → Net +8.583 ürün lehine. Defter ÇIKIŞ alanındaki malı sayıyor. Bu yüzden
     mutabakat kapsamı TÜM ALANLAR. (Uyumsuz çeşit 17.027 → 8.476'ya düştü.)
   ⚠ İki kapsam karıştırılmaz: panel stoğu (0,1) · defter mutabakatı (0,1,2).

   ── BAŞKA NE OLABİLİR (elenen alternatif açıklama) ─────────────────────────────
   "ÇIKIŞ dahil edince mutabıklık artıyor" bulgusunun alternatifi: tesadüf. Elendi —
   9.820'ye 1.237 asimetri tesadüf olamaz; ayrıca yön anlamlı (ÇIKIŞ hariç bırakılınca
   ERP hep 'fazla' görünüyordu, çünkü defter o malı hâlâ taşıyor).

   ── ehAltDepo ──────────────────────────────────────────────────────────────────
   ÖLÇÜLDÜ: mekan 12 defterinde `ehAltDepo` yalnız **0** (39.858.210 satır, tek değer)
   → alt depo ayrımı YOK, ek süzgeç gerekmez.

   ── EVREN: HİZMET/SARF KALEMLERİ HARİÇ (ölçümle düzeltildi 09.09.2026) ─────────
   ⚠ `urnTip = 0` guard'ı YETMİYOR: `KARGO GELİRİ` (stkID 144860) urnTip=0, satisTur=0
   ve `urnKtgrID=10` ("Çocuk Kitapları"! veri kiri) olduğu için guard'a takılmıyor.
   ÖLÇÜLDÜ — farkın iki tarafını da 5 kalem taşıyor, hiçbiri WMS'te YOK (Wms=0):
     144860  KARGO GELİRİ                    ERP −2.798.582  → sahte GİRİŞ 2.798.582
     583160  Geri Dönüşüm Kağıt Madde Alımı  ERP +1.764.200  → sahte ÇIKIŞ 1.764.200
     144963  KAPIDA ÖDEME GELİRİ             ERP −1.194.588  → sahte GİRİŞ
     436306  KOMİSYON BEDELİ                 ERP   −207.999  → sahte GİRİŞ
     1543633 TANIMSIZ ÜRÜN %20               ERP    +37.504  → sahte ÇIKIŞ
   Bunlar hizmet/sarf/muhasebe kalemi; WMS'te hiç durmazlar. "Düzeltilmez", mutabakat
   EVRENİNDEN ÇIKARILIR. Süzgeç: `bkm.UrunBilgi.Kategori3 NOT IN ('KARGO','Genel',
   'Tanımsız','Zkargo')` — kategori bazlı, elle stkID listesi DEĞİL.

   ── ÖLÇÜLEN BÜYÜKLÜK (09.09.2026, TÜM ALANLAR, hizmet/sarf HARİÇ) ──────────────
   | Belge                        | Çeşit | Adet    | Maliyet proxy | Maliyetsiz |
   |------------------------------|-------|---------|---------------|------------|
   | GİRİŞ (@GC=0) — ERP eksik    | 5.443 | 152.105 |   231.979 ₺   | 3.761      |
   | ÇIKIŞ (@GC=1) — ERP fazla    | 2.952 |  41.952 |   177.172 ₺   | 1.450      |
   Net: ERP defteri **+110.153 adet / ~+54.806 ₺** (maliyet proxy).

   ⚠ HARİÇ BIRAKILMADAN ÖNCEKİ (YANLIŞ) RAKAM, tarihsel kayıt: GİRİŞ 5.518 çeşit /
   4.389.670 adet / 32.304.553 ₺ · ÇIKIŞ 2.958 / 1.843.671 / 180.134 ₺ → net +32,1M ₺.
   Bunun **%96'sı yukarıdaki 5 hizmet kalemiydi.** Gerçek büyüklük 32 milyon değil
   ~55 bin ₺. Kapsam hatası tutarı 590 kat şişiriyordu.
   ⚠ Maliyet proxy = `Aktarim.dbo.BKM_STOKLAR_MALIYETLI.ORT_ALIS`. SP'nin fiilen
     kullanacağı `bkm.UrunMaliyet` dört kademeli (alış faturası → ORT_ALIS → fiyat
     listesi → **0**). 5.287 çeşitte ORT_ALIS yok; SP bir kısmını kurtarır, kurtarmadığı
     deftere **0 ₺** ile girer → adet düzelir, değer düzelmez.

   ── BİLİNMEYEN — PİLOT ŞART ────────────────────────────────────────────────────
   `dbo.irsSatir_ekle` ŞİFRELİ (definition NULL) → `@ADET`in İŞARETİNİ nasıl yorumladığı
   OKUNAMADI. İki olasılık:
     (a) İşaret belgeden gelir → her iki belgeye de POZİTİF adet
     (b) İşaret adetten gelir → çıkış belgesine NEGATİF adet
   `depo.sayimIsle` (b) gibi davranıyor: çıkış irsaliyesine `sAdet − pUAdetN` (negatif)
   yazıyor. `bkm.SayimIrsaliyeSatirEkle` de tutarı `ABS(@ADET)` ile hesaplıyor — bu da
   negatif adet beklendiğini düşündürüyor ama KANIT DEĞİL.
   ⇒ **TEK ÜRÜNLE PİLOT ZORUNLU**: bir ürün için evrak yaz, `irsHrk`ta oluşan `ehAdetN`
     işaretini ölç, farkın kapandığını doğrula. Blok 5 iki varyantı da üretiyor.
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── PARAMETRELER (dilimleme — tek partide her şeyi yazmak YASAK) ───────────── */
DECLARE @Kisi        int = 323;              -- evrakı açan kullanıcı
DECLARE @Tarih       date = CONVERT(date, GETDATE());
DECLARE @Kategori    varchar(60) = NULL;     -- NULL = tümü; ör. 'Kırtasiye'
DECLARE @EnAzAdet    int = 1;                -- bu adetin altındaki farkı atla
DECLARE @DilimTavani int = 200;              -- bir partide en çok kaç çeşit
DECLARE @EvrakOnEk   varchar(20) = 'MUTABAKAT';
-- Mutabakat evreninden ÇIKARILAN kategoriler (hizmet/sarf/muhasebe — WMS'te durmazlar).
-- Kategori bazlı süzgeç; elle stkID listesi tutulmuyor (liste bayatlar).
DECLARE @Haric table (Kat varchar(60) PRIMARY KEY);
INSERT INTO @Haric (Kat) VALUES ('KARGO'), ('Genel'), ('Tanımsız'), ('Zkargo');

/* ── BLOK 1 — KAPSAM KANITI (ÇIKIŞ dahil kararının dayanağı) ───────────────── */
;WITH e AS (
    SELECT ehstkID AS stkID, SUM(ehAdetN) AS E
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK) WHERE ehMekan = 12 GROUP BY ehstkID
),
w01 AS (
    SELECT stkID, SUM(Stok) AS W FROM DerinSISBkm.depo.stok_adres_palet_vw WITH (NOLOCK)
    WHERE adrsAlanTipID IN (0,1) GROUP BY stkID
),
wAll AS (
    SELECT stkID, SUM(Stok) AS W FROM DerinSISBkm.depo.stok_adres_palet_vw WITH (NOLOCK)
    GROUP BY stkID
),
k AS (SELECT stkID FROM e UNION SELECT stkID FROM wAll)
SELECT 'BLOK 1 — kapsam kanıtı' AS Blok,
       SUM(CASE WHEN ISNULL(a.W,0) = ISNULL(e.E,0) THEN 1 ELSE 0 END) AS Mutabik_RafGiris,
       SUM(CASE WHEN ISNULL(b.W,0) = ISNULL(e.E,0) THEN 1 ELSE 0 END) AS Mutabik_TumAlanlar,
       SUM(CASE WHEN ISNULL(a.W,0) <> ISNULL(e.E,0) AND ISNULL(b.W,0) = ISNULL(e.E,0)
                THEN 1 ELSE 0 END) AS CikisDahilOlunca_Kazanilan,
       SUM(CASE WHEN ISNULL(a.W,0) = ISNULL(e.E,0) AND ISNULL(b.W,0) <> ISNULL(e.E,0)
                THEN 1 ELSE 0 END) AS CikisDahilOlunca_Kaybedilen
FROM k LEFT JOIN e ON e.stkID = k.stkID
       LEFT JOIN w01  a ON a.stkID = k.stkID
       LEFT JOIN wAll b ON b.stkID = k.stkID;


/* ── BLOK 2 — MUTABAKAT TABANI (ürün bazında WMS toplamı ↔ ERP defteri) ────── */
IF OBJECT_ID('tempdb..#mutabakat') IS NOT NULL DROP TABLE #mutabakat;  -- tempdb
;WITH wms AS (
    -- WMS TOPLAMI: tüm alanlar (RAF + GİRİŞ + ÇIKIŞ). WMS'e YAZILMIYOR, yalnız okunuyor.
    SELECT stkID, SUM(Stok) AS W
    FROM DerinSISBkm.depo.stok_adres_palet_vw WITH (NOLOCK)
    GROUP BY stkID
),
erp AS (
    -- ERP MERKEZ DEFTERİ: hareket net bakiyesi. ehAltDepo tek değer 0 → süzgeç gereksiz.
    SELECT ehstkID AS stkID, SUM(ehAdetN) AS E
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan = 12
    GROUP BY ehstkID
)
ham AS (
    SELECT ISNULL(w.stkID, e.stkID)                    AS stkID,
           CONVERT(int, ISNULL(w.W, 0))                AS WmsToplam,
           CONVERT(int, ISNULL(e.E, 0))                AS ErpDefter,
           CONVERT(int, ISNULL(w.W,0) - ISNULL(e.E,0)) AS Fark
    FROM wms w FULL OUTER JOIN erp e ON e.stkID = w.stkID
    WHERE ISNULL(w.W,0) <> ISNULL(e.E,0)
)
SELECT h.stkID, h.WmsToplam, h.ErpDefter, h.Fark,
       CONVERT(bit, CASE WHEN ISNULL(ub.Kategori3,'Genel') IN
                        (SELECT Kat FROM @Haric) THEN 1 ELSE 0 END) AS EvrenDisi
INTO #mutabakat
FROM ham h
LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = h.stkID;

-- BLOK 2a — EVREN DIŞI kalemler (hizmet/sarf — düzeltilmez, çıkarılır)
SELECT 'BLOK 2a — evren dışı' AS Blok, m.stkID,
       LEFT(ISNULL(u.stkAd,'-'), 42) AS Urun, ISNULL(ub.Kategori3,'-') AS Kategori3,
       m.WmsToplam, m.ErpDefter, m.Fark
FROM #mutabakat m
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = m.stkID
LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = m.stkID
WHERE m.EvrenDisi = 1 AND ABS(m.Fark) >= 1000
ORDER BY ABS(m.Fark) DESC;

DELETE FROM #mutabakat WHERE EvrenDisi = 1;   -- tempdb; ERP tablosuna DOKUNMAZ

SELECT 'BLOK 2 — mutabakat tabanı (evren içi)' AS Blok, COUNT(*) AS UyumsuzCesit,
       SUM(CASE WHEN Fark > 0 THEN 1 ELSE 0 END) AS ErpEksik,
       SUM(CASE WHEN Fark < 0 THEN 1 ELSE 0 END) AS ErpFazla,
       CONVERT(bigint, SUM(CASE WHEN Fark > 0 THEN Fark ELSE 0 END))  AS EksikAdet,
       CONVERT(bigint, SUM(CASE WHEN Fark < 0 THEN -Fark ELSE 0 END)) AS FazlaAdet
FROM #mutabakat;


/* ── BLOK 3 — İKİ BELGE ÖZETİ + maliyet etkisi ─────────────────────────────── */
SELECT 'BLOK 3 — belge özeti' AS Blok,
       CASE WHEN m.Fark > 0 THEN 0 ELSE 1 END AS GC,
       CASE WHEN m.Fark > 0 THEN 'GİRİŞ — ERP eksik, deftere eklenecek'
                            ELSE 'ÇIKIŞ — ERP fazla, defterden düşülecek' END AS Belge,
       COUNT(*) AS Cesit,
       CONVERT(bigint, SUM(ABS(m.Fark))) AS Adet,
       CONVERT(decimal(18,2), SUM(ABS(m.Fark) * ISNULL(c.ORT_ALIS,0))) AS MaliyetProxy,
       SUM(CASE WHEN c.ORT_ALIS IS NULL THEN 1 ELSE 0 END) AS MaliyetsizCesit
FROM #mutabakat m
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI c WITH (NOLOCK) ON c.STKID = m.stkID
GROUP BY CASE WHEN m.Fark > 0 THEN 0 ELSE 1 END,
         CASE WHEN m.Fark > 0 THEN 'GİRİŞ — ERP eksik, deftere eklenecek'
                              ELSE 'ÇIKIŞ — ERP fazla, defterden düşülecek' END;


/* ── BLOK 4 — DİLİMLEME HARİTASI (hangi partiden başlanacak) ───────────────────
   Sıralama MALİYETE göre — etiket fiyatına göre değil (yön değiştiriyor, plan-43 §3.1). */
SELECT TOP 20 'BLOK 4 — dilim önerisi' AS Blok,
       ISNULL(ub.Kategori3, '(kategori yok)') AS Kategori3,
       COUNT(*) AS Cesit,
       CONVERT(bigint, SUM(ABS(m.Fark))) AS Adet,
       CONVERT(decimal(18,2), SUM(ABS(m.Fark) * ISNULL(c.ORT_ALIS,0))) AS MaliyetProxy
FROM #mutabakat m
LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = m.stkID
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI c WITH (NOLOCK) ON c.STKID = m.stkID
GROUP BY ISNULL(ub.Kategori3, '(kategori yok)')
ORDER BY SUM(ABS(m.Fark) * ISNULL(c.ORT_ALIS,0)) DESC;


/* ── BLOK 5 — ÜRETİLEN EVRAK (yazılacak EXEC satırlarının METNİ) ───────────────
   Bu blok metin döndürür, hiçbir şey çalıştırmaz. Gözden geçirilip onaylanırsa
   kullanıcı elle koşar. Adet işareti için İKİ varyant birlikte veriliyor (pilot şart). */
;WITH dilim AS (
    SELECT TOP (@DilimTavani)
           m.stkID, m.WmsToplam, m.ErpDefter, m.Fark,
           ISNULL(ub.Kategori3, '-') AS Kategori3,
           c.ORT_ALIS
    FROM #mutabakat m
    LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = m.stkID
    LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI c WITH (NOLOCK) ON c.STKID = m.stkID
    WHERE ABS(m.Fark) >= @EnAzAdet
      AND (@Kategori IS NULL OR ub.Kategori3 = @Kategori)
    ORDER BY ABS(m.Fark) * ISNULL(c.ORT_ALIS, 0) DESC
)
SELECT
    CASE WHEN d.Fark > 0 THEN 'GİRİŞ (GC=0)' ELSE 'ÇIKIŞ (GC=1)' END AS Belge,
    d.stkID, LEFT(ISNULL(u.stkAd,'(ad yok)'), 45) AS Urun, d.Kategori3,
    d.WmsToplam, d.ErpDefter, d.Fark,
    CONVERT(decimal(18,2), ABS(d.Fark) * ISNULL(d.ORT_ALIS,0)) AS MaliyetProxy,
    CASE WHEN d.ORT_ALIS IS NULL THEN 'MALİYET YOK → 0 ₺ girebilir' ELSE '' END AS Uyari,
    -- VARYANT (a): her iki belgeye de POZİTİF adet
    'EXEC bkm.SayimIrsaliyeSatirEkle @IRSALIYE_NO=@irs, @STKID='
        + CONVERT(varchar(12), d.stkID)
        + ', @ADET=' + CONVERT(varchar(12), ABS(d.Fark)) + ';'   AS Varyant_A_Pozitif,
    -- VARYANT (b): çıkış belgesine NEGATİF adet (depo.sayimIsle'nin davranışı)
    'EXEC bkm.SayimIrsaliyeSatirEkle @IRSALIYE_NO=@irs, @STKID='
        + CONVERT(varchar(12), d.stkID)
        + ', @ADET=' + CONVERT(varchar(12), d.Fark) + ';'        AS Varyant_B_Isaretli
FROM dilim d
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = d.stkID
ORDER BY CASE WHEN d.Fark > 0 THEN 0 ELSE 1 END,
         ABS(d.Fark) * ISNULL(d.ORT_ALIS,0) DESC;

-- Bu dilimin başlık satırları (iki belge — biri giriş biri çıkış)
SELECT 'BLOK 5 — başlık' AS Blok, x.GC,
       'DECLARE @irs int; EXEC @irs = bkm.SayimIrsaliyeBaslikOlustur @SUBE=12, @EVRAKNO='''
       + @EvrakOnEk + '-' + CONVERT(varchar(8), @Tarih, 112) + '-'
       + CASE WHEN x.GC = 0 THEN 'G' ELSE 'C' END
       + ''', @TARIH=''' + CONVERT(varchar(10), @Tarih, 104)
       + ''', @KULLANICI=' + CONVERT(varchar(10), @Kisi)
       + ', @GC=' + CONVERT(varchar(1), x.GC)
       + ', @belgeNot=''WMS-ERP mutabakat'', @eTip=99;'
       + ' IF @irs = -1 RAISERROR(''Baslik olusmadi — EXCEPTION_LOG bak'',16,1);' AS BaslikKomutu
FROM (SELECT 0 AS GC UNION ALL SELECT 1) x;


/* ── BLOK 6 — PİLOT (tek ürün) ─────────────────────────────────────────────────
   Sıfırıncı adım: en küçük etkili farkı olan BİR ürünle evrak yaz, sonucu ölç.    */
SELECT TOP 3 'BLOK 6 — pilot adayı' AS Blok,
       m.stkID, LEFT(ISNULL(u.stkAd,'-'),45) AS Urun,
       m.WmsToplam, m.ErpDefter, m.Fark,
       CONVERT(decimal(18,2), ABS(m.Fark) * ISNULL(c.ORT_ALIS,0)) AS MaliyetProxy
FROM #mutabakat m
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = m.stkID
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI c WITH (NOLOCK) ON c.STKID = m.stkID
WHERE ABS(m.Fark) BETWEEN 1 AND 3 AND c.ORT_ALIS IS NOT NULL
ORDER BY ABS(m.Fark) * c.ORT_ALIS ASC;

/* PİLOT DOĞRULAMA (evrak yazıldıktan SONRA koşulur — salt-okuma):
     -- 1) belge ve satırı gör
     SELECT i.eID, i.eTip, i.eGC, i.eNo, i.eTarih, a.ehStkID, a.ehAdet, a.ehAdetN,
            a.ehTutar, a.ehTutarKDV
     FROM DerinSISBkm.dbo.irs i JOIN DerinSISBkm.dbo.irsAyr a ON a.ehID = i.eID
     WHERE i.eNo LIKE 'MUTABAKAT-%';
     -- 2) defter hareketi oluştu mu, İŞARET ne
     SELECT ehTip, ehGC, ehAdetN, ehTutarN, ehTrhS
     FROM DerinSISBkm.dbo.irsHrk WHERE ehstkID = <pilot stkID> AND ehMekan = 12
       AND ehTrhS >= CONVERT(date, GETDATE()) ORDER BY ehID DESC;
     -- 3) fark kapandı mı → Blok 2'yi yeniden koş, o stkID listede OLMAMALI
   Beklenen: fark kapanır. Ters işaret girdiyse fark İKİYE KATLANIR → varyant değiştir
   ve ters evrakla düzelt (rollback: plan-43 §11).                                  */

DROP TABLE #mutabakat;

/* ── UYGULAMA SIRASI (özet) ────────────────────────────────────────────────────
   0. Blok 1 → kapsam kararını teyit et.
   1. Blok 6 → tek ürünle PİLOT. İşaret varyantını ampirik belirle. (ZORUNLU)
   2. Blok 4 → dilim seç (kategori veya tutar eşiği), @DilimTavani ≤ 200.
   3. Blok 5 → üretilen metni GÖZDEN GEÇİR, sonra koş: önce başlık, sonra satırlar.
   4. Blok 2 → farkın azaldığını ÖLÇ. Azalmadıysa DUR.
   5. Sonraki dilim. Her dilim kendi evrak numarasını alır (izlenebilirlik).
   ⚠ `@onay = 1` → belge anında deftere işler. Geri alma ters yönlü ikinci evrakla olur.
   ⚠ Muhasebe onayı: net etki ERP defterinde +2.545.999 adet / maliyet proxy +32,1M ₺.
     Maliyetsiz 5.287 çeşit 0 ₺ ile girer — adet düzelir, değer düzelmez.
   ⚠ Bu evrak WMS'e DOKUNMAZ. WMS'in kendisi yanlışsa (hayalet stok) bu düzeltme
     yanlışı deftere KOPYALAR. Hayalet şüphesi olan ürünler önce fiziki sayılmalı:
     sorgular/2026-09-09-wms-erp-fark-sayim-emri-ONERI.sql
   ═══════════════════════════════════════════════════════════════════════════════ */
