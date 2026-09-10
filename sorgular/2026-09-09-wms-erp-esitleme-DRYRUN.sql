/* ═══════════════════════════════════════════════════════════════════════════════
   MERKEZ DEPO SAYIM/EŞİTLEME ZİNCİRİ — GÖVDE ÇÖZÜMLEMESİ + **DRY-RUN**  09.09.2026

   ⚠⚠⚠ BU DOSYADA INSERT / UPDATE / DELETE / TRUNCATE / EXEC YOK. Yalnız SELECT.

   Bu dosyanın ilk sürümü (aynı gün, daha erken) `ent.JokerJokerCKEsitleme` desenini
   merkez depoya uyarlıyordu. Kullanıcı "ezbere yazma, satır satır hakim ol" dedi;
   `depo.sayimIsle` ve komşuları `sys.sql_modules`tan okunduğunda o sürümün üç
   iddiası çürüdü. Geri alınanlar Bölüm F'de tek tek yazılı.

   ═══ BÖLÜM A — depo.sayimIsle (ÖLÇÜLDÜ: 3.830 karakter, satır satır) ════════════
   İmza: depo.sayimIsle(@sayimID int, @paletBazliSifirlansin tinyint, @kisi int)

   1) İKİ irsaliye başlığı açar (SCOPE_IDENTITY ile yakalar):
        INSERT irs (eTip=99 'Sayım', eGC=1, eMekan=12, eNo='JokerStok Ç', eFirma=0, eAltDepo=0)
        INSERT irs (eTip=99,        eGC=0, eMekan=12, eNo='JokerStok G', ...)
      ⚠ eNo metni SP'ye GÖMÜLÜ → merkez eşitlemesi de defterde "JokerStok" görünür.
   2) UPDATE depo.sayım SET paletBazliSifirlansin=@param, cikisIrsaliyeID, girisIrsaliyeID
      ⚠ Başlığa ne yazarsan yaz: **SP parametresi ezer.** Başlıktaki değer anlamsız.
   3) #tempSayim = ÜÇ kol:
      farkTip 0 — YALNIZ @paletBazliSifirlansin=1 iken. sayımAyr'da adı geçen
                  paletlerdeki, sayımAyr'da LİSTELENMEMİŞ ürünler → adet = −pUAdetN,
                  yön = çıkış. **Listelemediğin ürün paletten SİLİNİR** (adım 7).
      farkTip 1 — sayımAyr ∩ paletUrnTnm, sAdet <> pUAdetN → adet = sAdet − pUAdetN,
                  yön = (sAdet < pUAdetN ? çıkış : giriş).
      farkTip 2 — sayımAyr'da var, paletUrnTnm'de yok → adet = sAdet, yön = giriş.
      Üç kolun hepsinde `INNER JOIN depo.paletTnm ON pID = spID`
        → paletTnm'de olmayan spID **sessizce düşer** (hata yok, satır yok).
      Adres üç kolda da `paletTnm.pSonPozID`
        → **`sAdrsID` / `sSonPozAdrsID` HİÇ OKUNMUYOR.** Kritik tek alan `spID`=PALET.
   4) INSERT depo.paletIcHrk — kolon↔değer eşleşmesi sırayla:
        piİlkID=paletID · piSonID=0 · piStkID=urun · piAdet=adet · pikKisi=@kisi ·
        pikTarih=getdate() · piTermID=1+farkTip · pGC=yon · pHrkTip=2 ·
        piIrsID=irsaliyeID · piIlkAdrsID=adresID · piSonAdrsID=0
      ⚠ `piTermID` terminal değil **1+farkTip** taşıyor (kolonun kötüye kullanımı).
        `pHrkTip=2` sabit → sema'daki "2 = SAYIM" bu satırla doğrulandı.
   5) INSERT irsAyr — ehKdv=1 sabit · ehAdet=ehAdetN=adet · ehNot=paletID ·
      **ehTutar=0 · ehIndirim=0** · ehSira=1 (her satırda 1).
      ⚠ Bu yol deftere TUTARSIZ (0 ₺) yazar. Parasal etki bu SP'den doğmaz.
   6) EXEC dbo.irsSatirHrk_ekle ×2
      ⚠⚠ **OKUNAMIYOR**: `sys.sql_modules.definition` NULL. Obje var, tip
        SQL_STORED_PROCEDURE, şema `dbo` (yanlış şema değil) → şifreli/izinsiz.
        `irsHrk`ı üreten adım tam olarak bu. Zincirin SON MİLİ kara kutu.
   7) DELETE depo.paletUrnTnm (farkTip 0 karşılığı, paletBazli=1 iken).
   8) UPDATE depo.paletUrnTnm SET pUAdetN = sAdet (fark olan satırlar).
   9) INSERT depo.paletUrnTnm (yeni palet-ürün) — `INNER JOIN urnBarkod_vw`
      → **barkodsuz ürün sessizce düşer**: hareket + irsAyr yazılmış, WMS'e girmemiş.
        ÖLÇÜLDÜ: WMS'te barkodsuz 3 çeşit. Çok-barkodlu ürün 0 → fan-out riski YOK.
  10) UPDATE depo.sayım SET sDurum = 1.

   YOK OLAN GÜVENLİKLER: BEGIN TRAN yok · TRY/CATCH yok · @sayimID doğrulaması yok ·
   satır sınırı yok. Yarıda kalırsa irs başlığı satırsız, palet oynamış kalır.

   ═══ BÖLÜM B — ÖLÇÜLEN ŞEMA GERÇEKLERİ ════════════════════════════════════════
   · depo.stok_adres_palet_vw = paletUrnTnm ⋈ paletTnm ⋈ adres(pSonPozID),
     `WHERE pUAdetN > 0`, `Stok = SUM(pUAdetN)`
     → **"WMS Stok" ile `pUAdetN` AYNI ŞEY.**
   · (pUID, pUStkID) TEKİL — 0 mükerrer ikili. View'deki SUM kozmetik.
   · View `pUAdetN > 0` süzer → **80.108 satır sıfır**, **43 satır negatif (−907 adet)**
     WMS ölçümünde GÖRÜNMÜYOR.
   · adres JOIN'i INNER → pSonPozID'si `depo.adres`te olmayan palet view'de yok.
   · irsTip_vw: 99 'Sayım' · 16 'Stok EKLE' · 90 'Ürün SAY' · 9 'Mağaza Depo' ·
     13 'Depo Mağaza'.

   ═══ BÖLÜM C — sayimIsle WMS↔ERP EŞİTLEMESİ YAPMAZ (asıl sonuç) ════════════════
   Karşılaştırdığı iki şey:  (BEYAN ettiğin sAdet) ↔ (WMS'in paletUrnTnm'i).
   ERP defteri karşılaştırmaya HİÇ girmez; yalnız sonucu alır. Bundan iki şey çıkar:

   (1) `sAdet = WMS Stok` verilirse → sAdet = pUAdetN → farkTip 1 koşulu tutmaz,
       farkTip 2 tutmaz → #tempSayim BOŞ → irsAyr satırı yok →
       **ERP DEFTERİ DEĞİŞMEZ.** İlk sürümün yaptığı buydu: satır üretip sıfır düzeltme.
   (2) ERP'yi WMS'e çekmek için sAdet'e ERP defterini yazmak gerekir — ama 8-9. adımlar
       o zaman **WMS'i ERP'ye çeker** (pUAdetN=sAdet). Ters yön; standing kural merkez
       stoğunun doğru kaynağı WMS diyor. Yani bu SP ile "ERP'yi düzelt, WMS'e dokunma"
       MÜMKÜN DEĞİL — her koşuda ikisi birlikte oynar.

   JOKER'de çalışmasının sebebi: `20353` paleti JOKER stoğunun ERP-tarafı AYNASI ve
   karşılaştırılan sAdet DIŞ kaynaktan (JOKER_RAF_STOK) gelir → fark doğar. Merkezde
   böyle bir dış kaynak yok; fark zaten defterin İÇİNDE.

   ═══ BÖLÜM D — `WMS-GunlukSayimEmiri` = FİZİKİ SAYIM EMRİ (doğru desen) ════════
   (Job gövdesi kullanıcı tarafından verildi; bağımlılıkları burada ölçüldü.)
   · Beyan etmez, **saydırır**: `depo.emir` emTip=5, emDurum=0, emDepoID=12, emHavuz=1,
     emBesOto=1 → terminal operatörü fiilen sayar.
   · `emirAyr`: emIlkAdres = emSonAdres = adrsID (**yer değiştirme yok, yerinde sayım**) ·
     emİlkPozID = PALET · **emSonPozID = stkID** (isim tuzağı: pozisyon değil ÜRÜN;
     `paletUrnTnm ON pUID=emİlkPozID AND pUStkID=emSonPozID` bunu kanıtlıyor) ·
     emAdet = sistemAdet (sistemin iddiası) · emTamam=0.
   · `emPaletID = 217542` **GÖMÜLÜ** — ÖLÇÜLDÜ: pID 217542, pSonPozID 82157,
     adres 'CK01', alanTip **2 (ÇIKIŞ ALANI)**, içerik 0 satır → sanal hedef palet.
     JOKER'in 20353'ü ile aynı sınıf gömme; merkez için de tek sabit hedef.
   · `sayilcaklar` iki kol: (a) dün mekan/firma 12 · eTip IN (13,9) · eNo LIKE '%-F1'/'%-E1'
     belgelerindeki ürünler, (b) dün iptal edilen emir satırları (emIptalNeden<>4).
     → **Hayalet stok bu iki ölçüte GİRMİYOR.** Genişletme yeri tam burası
       (bkz. sorgular/2026-09-09-wms-erp-fark-sayim-emri-ONERI.sql).
   · `#src` ürünün BULUNDUĞU TÜM palet/adresleri alır (`Stok>0`) — kasıtlı fan-out.
   · Son DELETE: kaynak adresin `adresSnl.adrs3 = 0` olduğu satırları emirden ATAR.
     ÖLÇÜLDÜ: adrs3=0 → 3.231 adres; **3.224'ü RAF ALANI**, kalanı ÇIKIŞ 2 · HAVUZ 3 ·
     GİRİŞ 1 · İADE 1. adrs3 ∈ 0..12 (kat/koordinat). Yani sıfır-katlı adresler
     sayıma alınmıyor → genişletme yaparken hayaletin bu adreslerde olan kısmı düşer.
     Aynı DELETE `urnBarkod_vw` INNER JOIN'i taşıdığı için **barkodsuz satır silinmez**,
     emirde kalır (sayimIsle'nin tersi davranış).
   · `@EmNo = 'GUN'+yyMMdd` → gün içinde ikinci koşumda **aynı emNo** (tekillik guard yok).
   · EXEC dbo.BKM_TerminalSayimKullaniciEkle @EmirID (ÖLÇÜLDÜ, 667 krk, okunur):
     `depo.emirTerm`e termID=14 + gömülü 17 termKod ('ebahar','1008','1002'…) ekler;
     ayrıca emTip=5 emirlerinden satırı biten (emTamam=0 kalmayan) hepsini emDurum=1 yapar.
     ⚠ Kullanıcı/terminal listesi SP'ye GÖMÜLÜ — personel değişiminde sessizce bayatlar.

   ═══ BÖLÜM E — bkm.SayimIrsaliye* = ERP-ONLY DÜZELTME YOLU (aranan araç) ═══════
   Kullanıcının işaret ettiği `bkm` şemalı sayım evrakı SP'leri. WMS'e DOKUNMAZ:
   yalnız `irs`/`irsAyr` yazar, `paletUrnTnm`e hiç girmez. Merkez için doğru yol bu.

   · bkm.SayimIrsaliyeBaslikOlustur(@SUBE, @EVRAKNO, @TARIH, @KULLANICI, @GC,
       @belgeNot='', @eTip tinyint=99, @frmID=0, @eNot='')
     → EXEC dbo.irs_ekle ... **@onay = 1** (anında onaylı; gece onay job'ı beklemez)
     → RETURN irsaliye no; hata olursa **-1** döner ve BKMDATA.dbo.EXCEPTION_LOG'a yazar.
     @GC: 0 giriş / 1 çıkış → ERP-eksik ve ERP-fazla için İKİ AYRI belge gerekir.
   · bkm.SayimIrsaliyeSatirEkle(@IRSALIYE_NO, @STKID, @ADET, @ehTutar=0, @ehi1=0, @ehNot='')
     → KDV'yi **kanonik yoldan** alır: `urn.KDVs → urnKDV.kdvYuzde` (bugün düzelttiğimiz
       lookup; `kdvYuzde_vw` DEĞİL — SP zaten doğrusunu kullanıyor).
     → eTip=99 ise **tutarı KENDİ hesaplar**: `ehTutar = bkm.UrunMaliyet(stkID, eTarih) *
       ABS(adet)`, `ehTutarKDV = ehTutar * kdvOran/100`. Yani sayım farkı burada
       **maliyetle** deftere girer (sayimIsle'nin ehTutar=0'ının tersi).
     → ehSira'yı MAX+1 ile kendisi verir; RETURN 1 başarı / -1 hata (+EXCEPTION_LOG).
   · bkm.UrunMaliyet(@STKID, @TARIH) (ÖLÇÜLDÜ, 2.243 krk) — üç kademeli:
     (1) son 5 alış faturası satırı (`fat.eTip=0`, `eDurum<>2`, `Neden<>243`,
         eFirma 9525 için 01.09.2022 sonrası) ∪ son 5 `BKMDATA..ODAK_FATURA` satırı
         → ağırlıklı ortalama = SUM(ehTutarN)/SUM(ehAdetN)
     (2) NULL ise `Aktarim.dbo.BKM_STOKLAR_MALIYETLI.ORT_ALIS`
     (3) NULL ise fiyat listesi `fytOzl` (fTur=1, fTip=1) × 5 kademe iskonto
     (4) hâlâ NULL ise **0** → maliyeti bilinmeyen ürün deftere 0 ₺ ile girer (sessiz).
   · bkm.SayımEksiStokGetir(@MekanId) — defterde negatif bakiyeli ürünleri getirir
     (bizim "ERP negatif" kümesinin kurumsal karşılığı): `ehAltDepo=0`, `urnTip=0`,
     `satisTur=0`, `urnKtgrID<>78`, `bkm.SINAV_URUN` hariç, 9 stkID elle hariç,
     `HAVING SUM(ehAdetN) < 0`.
     ⚠ İçindeki `u.stkAd NOT LIKE 'Sınav okulları'` **joker karaktersiz** → tam
       eşleşmeden başkasını süzmüyor, fiilen etkisiz satır. Gerçek süzgeç
       urnKtgrID + SINAV_URUN.
   · Alt yazıcılar `dbo.irs_ekle` ve `dbo.irsSatir_ekle` **ŞİFRELİ** (definition NULL).
     Yani iki yolun da son mili okunamıyor; "satır satır hakimim" iddiası buraya kadar.
   · Ayrıca mevcut: bkm.SayimIrsaliyeSatirEkle2 · SayimSatirGirisCikisDuzenle ·
     SayimRafAktar/Guncelle · SayimUrunEkle · SayimLogEkle + tablolar (SayimBaslik,
     SayimEmirBaslik/Detaylari, SayimRaflari, SayimKullanici, SayimLog…) — BKM'nin
     kendi reyon-sayım uygulaması. `bkm.ReyonSayimEmriOlustur` günlük reyon emrini
     üretir (POS köprüsü `urnBrkd.urnBarkod = SalesProducts.BarcodeNo` ile — stkKod
     DEĞİL, doğru köprü).

   ═══ BÖLÜM F — GERİ ALINAN İDDİALAR (ilk sürüm yanlıştı) ══════════════════════
   1. "sAdrsID/sSonPozAdrsID gerçek adres taşımalı" → GEREKSİZ. sayimIsle bu iki
      kolonu okumuyor; adresi paletTnm.pSonPozID'den alıyor. Kritik alan spID.
   2. "Tek koşuda 72,2M ₺ K/Z etkisi" → İKİ KEZ yanlış:
      (a) depo.sayimIsle yolu ehTutar=0 yazar, tutar üretmez;
      (b) etiket fiyatı yanlış taban. ÖLÇÜLDÜ (ORT_ALIS ile, 09.09):
          ERP AZALIR 13.465 çeşit / 2.254.001 adet → etiket 70.434.250 ₺ ama
            **maliyet 1.639.833 ₺** (7.201 çeşitte ORT_ALIS YOK)
          ERP ARTAR  3.562 çeşit / 4.258.229 adet → etiket 6.835.396 ₺ ama
            **maliyet 32.154.572 ₺** (2.410 çeşitte ORT_ALIS YOK)
          → Etikete göre 63,6M ₺ DÜŞÜŞ, maliyete göre 30,5M ₺ ARTIŞ. **Yön bile
            değişiyor.** Kesin tutar ancak bkm.UrunMaliyet ürün-ürün koşularak
            bulunur ve maliyeti bilinmeyen 9.611 çeşit 0 ₺ ile girer.
   3. "WMS'i sayım olarak yazıp ERP'yi eşitleriz" → YANLIŞ (Bölüm C).
   4. "Başlıkta paletBazliSifirlansin=1 verilmiş" → başlıktaki değer önemsiz, SP ezer.
   Not: çeşit sayıları (13.465/3.562) bugünün erken ölçümündeki 13.804/4.009'dan
   farklı; bu dosyanın süzgeci (RAF+GİRİŞ, ÇIKIŞ hariç) esas alınmıştır.
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── BLOK 1 — FARK TABANI (ürün düzeyi) ───────────────────────────────────────
   ⚠ KAPSAM UYARISI (09.09.2026 sonrası): aşağıdaki bloklar `adrsAlanTipID IN (0,1)`
   kullanıyor — bu PANEL stoğunun kapsamı. **Defter mutabakatı için YANLIŞ**: ÇIKIŞ
   alanındaki mal da defterde duruyor (ölçüldü: ÇIKIŞ dahil edilince 9.820 ürün daha
   mutabık, kaybedilen 1.237). Mutabakat ve evrak üretimi için doğru dosya:
       sorgular/2026-09-09-wms-erp-sayim-evraki-URET.sql
   Bu dosya artık MEKANİZMA ÇÖZÜMLEMESİ belgesidir (Bölüm A-F); sayıları referans almayın. */
IF OBJECT_ID('tempdb..#fark') IS NOT NULL DROP TABLE #fark;   -- tempdb, ERP tablosu DEĞİL
;WITH wms AS (
    SELECT stkID, SUM(Stok) AS W
    FROM DerinSISBkm.depo.stok_adres_palet_vw WITH (NOLOCK)
    WHERE adrsAlanTipID IN (0,1)          -- ÇIKIŞ ALANI (2) sevke hazır mal, hariç
    GROUP BY stkID
),
erp AS (
    SELECT ehstkID AS stkID, SUM(ehAdetN) AS E
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan = 12
    GROUP BY ehstkID
)
SELECT ISNULL(w.stkID, e.stkID)     AS stkID,
       CONVERT(int, ISNULL(w.W, 0)) AS WmsStok,
       CONVERT(int, ISNULL(e.E, 0)) AS ErpDefter,
       CONVERT(int, ISNULL(w.W,0) - ISNULL(e.E,0)) AS Fark
INTO #fark
FROM wms w FULL OUTER JOIN erp e ON e.stkID = w.stkID
WHERE ISNULL(w.W,0) <> ISNULL(e.E,0);

SELECT 'BLOK 1 — fark tabanı' AS Blok, COUNT(*) AS UyumsuzCesit,
       SUM(CASE WHEN Fark > 0 THEN 1 ELSE 0 END) AS ErpEksik_Cesit,
       SUM(CASE WHEN Fark < 0 THEN 1 ELSE 0 END) AS ErpFazla_Cesit,
       CONVERT(bigint, SUM(ABS(Fark))) AS MutlakFarkAdet
FROM #fark;


/* ── BLOK 2 — HANGİ FARK HANGİ YOLA GİDER ───────────────────────────────────── */
SELECT 'BLOK 2 — sınıf ve yol' AS Blok, x.Sinif, x.Yol,
       COUNT(*) AS Cesit, CONVERT(bigint, SUM(ABS(x.Fark))) AS Adet,
       CONVERT(decimal(18,2), SUM(ABS(x.Fark) * ISNULL(x.OrtAlis,0))) AS MaliyetTutar,
       SUM(CASE WHEN x.OrtAlis IS NULL THEN 1 ELSE 0 END) AS MaliyetiBilinmeyen
FROM (
    SELECT f.Fark, m.ORT_ALIS AS OrtAlis,
           CASE WHEN f.ErpDefter < 0                   THEN '1-ERP defteri NEGATİF'
                WHEN f.WmsStok > 0 AND f.ErpDefter = 0 THEN '2-HAYALET (WMS var, defter 0)'
                WHEN f.WmsStok = 0 AND f.ErpDefter > 0 THEN '3-defter kalıntısı (WMS yok)'
                WHEN f.WmsStok > f.ErpDefter           THEN '4-WMS fazla'
                ELSE                                        '5-ERP fazla' END AS Sinif,
           CASE WHEN f.WmsStok = 0
                THEN 'palet/adres YOK → fiziki sayım imkânsız → bkm.SayimIrsaliye* (defter)'
                ELSE 'fiziki sayım emri (depo.emir tip 5) → sonra defter düzeltmesi' END AS Yol
    FROM #fark f
    LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI m WITH (NOLOCK) ON m.STKID = f.stkID
) x
GROUP BY x.Sinif, x.Yol
ORDER BY x.Sinif;


/* ── BLOK 3 — FİZİKİ SAYIM EMRİ ADAYI + job'ın üç kapısı ────────────────────────
   `WMS-GunlukSayimEmiri` desenine göre üretilecek `#src` satırları ve her satırın
   hangi kapıdan geçip geçmeyeceği. Kapılar Bölüm D'de gövdeden çıkarıldı.        */
SELECT TOP 50
       d.adrsID, d.PaletID, d.stkID,
       CONVERT(decimal(15,3), d.Stok) AS sistemAdet,
       f.ErpDefter, f.Fark,
       ISNULL(t.alanTipAd, '?')       AS AlanTipi,
       d.adrsAd                       AS Adres,
       sn.adrs3,
       CASE WHEN sn.adrs3 = 0 THEN 'DÜŞER — son DELETE adrs3=0 satırını atar'
            WHEN sn.adrsID IS NULL THEN 'ŞÜPHELİ — adresSnl kaydı yok'
            ELSE 'geçer' END          AS AdresKapisi,
       CASE WHEN pt.pID IS NULL THEN 'DÜŞER — paletTnm yok' ELSE 'geçer' END AS PaletKapisi,
       CASE WHEN NOT EXISTS (SELECT 1 FROM DerinSISBkm.dbo.urnBarkod_vw b
                             WHERE b.urnBrkdStkID = d.stkID)
            THEN 'barkodsuz — emirde KALIR, terminalde okunamaz' ELSE 'barkod var' END
                                      AS BarkodKapisi,
       LEFT(ISNULL(u.stkAd,'(ad yok)'), 40) AS Urun
FROM #fark f
JOIN DerinSISBkm.depo.stok_adres_palet_vw d WITH (NOLOCK) ON d.stkID = f.stkID
LEFT JOIN DerinSISBkm.depo.adresAlanTip t   ON t.alanTipID = d.adrsAlanTipID
LEFT JOIN DerinSISBkm.depo.adresSnl   sn WITH (NOLOCK) ON sn.adrsID  = d.adrsID
LEFT JOIN DerinSISBkm.depo.paletTnm   pt WITH (NOLOCK) ON pt.pID     = d.PaletID
LEFT JOIN DerinSISBkm.dbo.urn         u  WITH (NOLOCK) ON u.stkID    = f.stkID
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI m WITH (NOLOCK) ON m.STKID = f.stkID
WHERE d.adrsAlanTipID IN (0,1) AND d.Stok > 0
ORDER BY ABS(f.Fark) * ISNULL(m.ORT_ALIS, 0) DESC;

-- Kapıların toplu etkisi (TOP'suz)
SELECT 'BLOK 3 — kapı elemesi' AS Blok,
       COUNT(*) AS AdaySatir,
       SUM(CASE WHEN sn.adrs3 = 0 THEN 1 ELSE 0 END)      AS Adrs3SifirDuser,
       SUM(CASE WHEN sn.adrsID IS NULL THEN 1 ELSE 0 END) AS AdresSnlYok,
       SUM(CASE WHEN pt.pID IS NULL THEN 1 ELSE 0 END)    AS PaletTnmYok
FROM #fark f
JOIN DerinSISBkm.depo.stok_adres_palet_vw d WITH (NOLOCK) ON d.stkID = f.stkID
LEFT JOIN DerinSISBkm.depo.adresSnl sn WITH (NOLOCK) ON sn.adrsID = d.adrsID
LEFT JOIN DerinSISBkm.depo.paletTnm pt WITH (NOLOCK) ON pt.pID    = d.PaletID
WHERE d.adrsAlanTipID IN (0,1) AND d.Stok > 0;


/* ── BLOK 4 — paletBazliSifirlansin=1 RİSKİ (yalnız sayimIsle yolunda) ─────────
   Eşitlemeye giren paletlerde, listede OLMAYAN ürün satırları = bayrak 1 verilirse
   yok edilecek stok.                                                             */
SELECT 'BLOK 4 — paletBazli=1 ile silinecek' AS Blok,
       COUNT(*) AS Satir, COUNT(DISTINCT d.stkID) AS Cesit,
       CONVERT(bigint, SUM(d.Stok)) AS Adet
FROM DerinSISBkm.depo.stok_adres_palet_vw d WITH (NOLOCK)
WHERE d.adrsAlanTipID IN (0,1) AND d.Stok > 0
  AND d.PaletID IN (SELECT d2.PaletID
                    FROM DerinSISBkm.depo.stok_adres_palet_vw d2 WITH (NOLOCK)
                    JOIN #fark f2 ON f2.stkID = d2.stkID
                    WHERE d2.adrsAlanTipID IN (0,1))
  AND NOT EXISTS (SELECT 1 FROM #fark f WHERE f.stkID = d.stkID);


/* ── BLOK 5 — bkm.SayimIrsaliye* YOLUNDA ÜRETİLECEK BELGE İSKELETİ (SELECT) ────
   Yazma YOK. İki belge gerekir: ERP-eksik için @GC=0 (giriş), ERP-fazla için @GC=1.
   Tutarı SP kendisi bkm.UrunMaliyet ile hesaplar → aşağıdaki tutar YALNIZCA
   ORT_ALIS proxy'si, SP'nin bulacağı değer bundan farklı olabilir.               */
SELECT CASE WHEN f.Fark > 0 THEN 0 ELSE 1 END AS GC,
       CASE WHEN f.Fark > 0 THEN 'giriş belgesi (ERP eksik)'
                            ELSE 'çıkış belgesi (ERP fazla)' END AS Belge,
       COUNT(*) AS SatirSayisi,
       CONVERT(bigint, SUM(ABS(f.Fark))) AS ToplamAdet,
       CONVERT(decimal(18,2), SUM(ABS(f.Fark) * ISNULL(m.ORT_ALIS,0))) AS ProxyTutar,
       SUM(CASE WHEN m.ORT_ALIS IS NULL THEN 1 ELSE 0 END) AS MaliyetsizSatir
FROM #fark f
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI m WITH (NOLOCK) ON m.STKID = f.stkID
GROUP BY CASE WHEN f.Fark > 0 THEN 0 ELSE 1 END,
         CASE WHEN f.Fark > 0 THEN 'giriş belgesi (ERP eksik)'
                              ELSE 'çıkış belgesi (ERP fazla)' END;

/* [YAZMA — BU DOSYADA YOK] Gerçek koşumda sıra şöyle olurdu:
     DECLARE @irs int;
     EXEC @irs = bkm.SayimIrsaliyeBaslikOlustur
            @SUBE=12, @EVRAKNO='<benzersiz>', @TARIH=<bugün>, @KULLANICI=<kisi>,
            @GC=<0|1>, @belgeNot='WMS-ERP mutabakat', @eTip=99;
     IF @irs = -1 → BKMDATA.dbo.EXCEPTION_LOG okunur, DURULUR.
     -- her ürün için:
     EXEC bkm.SayimIrsaliyeSatirEkle @IRSALIYE_NO=@irs, @STKID=<stkID>, @ADET=<ABS(fark)>;
   ⚠ Bu yol `@onay=1` ile yazar → deftere ANINDA işler, geri alınması ayrı belge ister.
   ⚠ 17.027 çeşidi tek belgede yazmak yanlış: dilim (kategori/koridor/tutar eşiği) şart.
   ⚠ Karar sırası: fiziki sayım ÖNCE (WMS'in doğruluğu teyit), defter düzeltmesi SONRA.
     Sayımsız defter düzeltmesi WMS'i sorgusuz doğru kabul etmek olur — Bölüm B'deki
     80.108 sıfır + 43 negatif satır bunun neden riskli olduğunu gösteriyor.          */

DROP TABLE #fark;
