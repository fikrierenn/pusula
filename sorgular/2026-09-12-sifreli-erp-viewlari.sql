/* ============================================================================
   ŞİFRELİ ERP VIEW KATMANI — MANTIK OKUNAMIYOR, DAVRANIŞ KANITLANDI (2026-09-12)
   DB: DerinSISBkm (profil: erp)

   ÇIKIŞ NOKTASI: kullanıcının elle sorgu arşivi (`D:/Belgelerim/sql`, 576 dosya)
   sema ile kıyaslandı. Sema'nın HİÇ bilmediği ama en çok kullanılan ERP nesneleri:
     urnBarkod_vw 37 dosya · stokSon_vw 14 · urnKategori_vw 12 · fn_fytOzlListe
   Yani satıcının HAZIR OKUMA KATMANI pratikte ham tablodan daha çok kullanılıyor.
   ============================================================================ */

/* ── 1) ÜÇ ŞIKKI TEK SORGUDA AYIR (şifreli / izin yok / yanlış şema) ────────── */
SELECT s.name+'.'+o.name AS obje, o.type_desc AS tip,
       OBJECTPROPERTY(o.object_id,'IsEncrypted')                          AS sifreli,
       HAS_PERMS_BY_NAME(s.name+'.'+o.name,'OBJECT','VIEW DEFINITION')    AS izin_var,
       CASE WHEN m.definition IS NULL THEN 'NULL' ELSE 'OK' END           AS tanim
FROM   DerinSISBkm.sys.objects o
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
LEFT JOIN DerinSISBkm.sys.sql_modules m ON m.object_id = o.object_id
WHERE  o.name IN ('urnBarkod_vw','stokSon_vw','urnKategori_vw','fn_fytOzlListe',
                  'stok_adres_vw','markaIndirimEtkin_vw');
/* ÖLÇÜM:
     dbo.urnBarkod_vw       sifreli=1  izin=1  tanim=NULL   → GERÇEKTEN ŞİFRELİ
     dbo.stokSon_vw         sifreli=1  izin=1  tanim=NULL   → GERÇEKTEN ŞİFRELİ
     dbo.urnKategori_vw     sifreli=1  izin=1  tanim=NULL   → GERÇEKTEN ŞİFRELİ
     dbo.fn_fytOzlListe     sifreli=1  izin=1  tanim=NULL   → GERÇEKTEN ŞİFRELİ
     depo.stok_adres_vw     sifreli=0  izin=1  tanim=OK     → okunuyor (304 karakter)
     ent.markaIndirimEtkin_vw sifreli=0 izin=1 tanim=OK     → okunuyor (278 karakter)

   ⇒ `sql-server-conventions.md` § "OBJECT_DEFINITION NULL ≠ şifreli" kuralının (a)
     şıkkı. Zirve'deki örnek (c) şıkkıydı (izin yok). AYNI BELİRTİ, FARKLI SEBEP —
     ve ayrım bu tek sorguyla yapılıyor.
   ⚠ Satıcı her şeyi şifrelememiş; `depo`/`ent` şemasındakiler açık. */

/* ── 2) ★ urnBarkod_vw ≡ urnBrkd WHERE urnBrkdOnce = 0  (KÜME EŞİTLİĞİ) ─────── */
SELECT (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.urnBarkod_vw)                       AS view_satir,
       (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK))               AS ham_tum,
       (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK) WHERE urnBrkdOnce=0) AS ham_once0,
       (SELECT COUNT_BIG(*) FROM (SELECT urnBrkdStkID,barkod FROM DerinSISBkm.dbo.urnBarkod_vw
          EXCEPT SELECT urnBrkdStkID,urnBarkod FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK)) a) AS viewde_var_hamda_yok;
/* view 837.747 · ham tüm 895.194 · ham Once=0 **837.747** · fark 0
   ⇒ EŞİT SAYIM + TEK YÖNLÜ FARK 0 ⇒ KÜMELER ÖZDEŞ (barkod PK olduğu için mükerrer yok).
   ⇒ View, kanonik birincil-barkod seçimini HAZIR veriyor; süzgeci unutma riski biter.
   ⚠ KOLON ADI DEĞİŞİYOR: ham tabloda `urnBarkod`, view'de **`barkod`**. */

/* ── 3) ★★ urnKategori_vw ≡ urn WHERE urnTip = 0  (SESSİZ SÜZGEÇ) ───────────── */
SELECT (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE urnTip=0) AS urntip0,
       (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.urnKategori_vw)                  AS view_satir,
       (SELECT COUNT_BIG(*) FROM (SELECT stkID FROM DerinSISBkm.dbo.urnKategori_vw
          EXCEPT SELECT stkID FROM DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE urnTip=0) a) AS viewde_fazla,
       (SELECT COUNT_BIG(*) FROM (SELECT stkID FROM DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE urnTip=0
          EXCEPT SELECT stkID FROM DerinSISBkm.dbo.urnKategori_vw) b) AS viewde_eksik;
/* 837.997 = 837.997 · **İKİ YÖNLÜ FARK 0** ⇒ TAM ÖZDEŞLİK KANITLANDI. */

SELECT u.urnTip AS urnTip, u.kod1ID AS kod1, COUNT_BIG(*) AS dusen
FROM   DerinSISBkm.dbo.urn u WITH(NOLOCK)
WHERE  NOT EXISTS (SELECT 1 FROM DerinSISBkm.dbo.urnKategori_vw v WHERE v.stkID = u.stkID)
GROUP BY u.urnTip, u.kod1ID ORDER BY dusen DESC;
/* DÜŞEN 304 KAYIT RASTGELE DEĞİL:
     urnTip = 1 → **252**  (gider/hizmet: "İndirilebilir Bağış ve Yardımlar",
                            "Belediye Vergileri", "Gider Tahakkukları")
     urnTip = 2 → **52**   (demirbaş/gayrimenkul: "Bursa Nilüfer … Ada 3 Parsel …")
   ⭐ O **52**, sema'nın 2026-09-03'te BAĞIMSIZ bulduğu "urnTip=2 = demirbaş/araç satışı,
     52 kayıt" ölçümüyle BİREBİR AYNI — çapraz teyit.
   ⇒ İKİ YÖNLÜ SONUÇ: normal-ürün süzgeci isteyen BEDAVA doğru sonuç alır; `urn` ile
     satır sayısı kıyaslayan 304'lük farkın sebebini bilemez. Fark ARTIK YAZILI.
   ⚠ Bu deponun KANONİK kategori kaynağı DEĞİL — o hâlâ `bkm.UrunBilgi.KatAna/Kategori3`.
     İki kategori sistemi yan yana; hangisi kullanıldıysa raporda YAZILIR.
     (`urnKategori_vw`: KategoriAd 2.999 ayrı · SonDalAd 1.807 ayrı, 75 kolon) */

/* ── 4) stokSon_vw = stokSonAltDepo_vw (altDepo TOPLANMIŞ) ─────────────────── */
SELECT (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.stokSon_vw)          AS stokson,
       (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.stokSonAltDepo_vw)   AS stoksonaltdepo,
       (SELECT COUNT(DISTINCT ehMekan) FROM DerinSISBkm.dbo.stokSon_vw) AS mekan;
/* 1.573.693 vs 1.573.699 → fark 6 · ehMekan **10 ayrı değer** */

SELECT COUNT_BIG(*) AS cok_altdepolu_cift FROM (
    SELECT ehstkID, ehMekan FROM DerinSISBkm.dbo.stokSonAltDepo_vw
    GROUP BY ehstkID, ehMekan HAVING COUNT(*) > 1) z;
/* **6** — farkın tamamını açıklıyor. İki view pratikte 6 satır dışında ÖZDEŞ.
   ⇒ altDepo kırılımı gerekmiyorsa `stokSon_vw` daha güvenli (altDepo üzerinden
     yanlışlıkla çift sayma riski yok).
   ⭐ 10 ayrı `ehMekan` → "defterde dokuz mekan var" bulgusuyla tutarlı; üç-mağaza
     süzgeci burada da bir KAPSAM SEÇİMİDİR.
   ⚠ MERKEZ DEPO (mekan 12) için KULLANILMAZ — merkez stoğu WMS'ten okunur. */

/* ── 5) DEĞİŞMEZ + KIRILABİLİRLİK KANITI ───────────────────────────────────── */
/* Kapı `sifreli-erp-viewlari-esdegerligi` (53.) dört EXCEPT'in TOPLAMINI 0 bekler.
   NEDEN KAPI: şifreli view'in içi değişirse HABERİMİZ OLMAZ — kaynak okunamıyor,
   sürüm yok, uyarı yok. Değişirse o view'i kullanan her sorgu SESSİZCE başka bir
   küme üzerinde çalışmaya başlar. Kapı, okunamayan mantığın yerine KOŞULABİLİR bir
   sözleşme koyar. */
SELECT 'HATA 1 — urnTip suzgeci unutulursa' AS senaryo, COUNT_BIG(*) AS ihlal FROM (
    SELECT stkID FROM DerinSISBkm.dbo.urn WITH(NOLOCK)
    EXCEPT SELECT stkID FROM DerinSISBkm.dbo.urnKategori_vw) a
UNION ALL
SELECT 'HATA 2 — barkod viewi Once=1 sanilirsa', COUNT_BIG(*) FROM (
    SELECT urnBrkdStkID,urnBarkod FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK) WHERE urnBrkdOnce=1
    EXCEPT SELECT urnBrkdStkID,barkod FROM DerinSISBkm.dbo.urnBarkod_vw) b;
/*   doğru formül                              0
     HATA 1 (urnTip süzgeci unutulur)        304
     HATA 2 (Once=1 tarafı sanılır)       57.445                                  */

/* ── 6) ARŞİVDE ADI GEÇEN AMA BU VERİTABANINDA OLMAYAN NESNELER ────────────── */
/*   stokKarti_vw · depoStokDurum_vw · siparisDetay_vw · asrsLokasyonKonum_vw ·
     stokMinMax · lokasyonlananKalan_vw → DerinSISBkm'de YOK.
     Hepsi `_ARSIV_WMSBKM` klasöründen, yani ARTIK KULLANILMAYAN eski WMS
     veritabanına ait.
   ⇒ **Arşivde ad görmek nesnenin VAR olduğu anlamına gelmez.** Arşiv İPUCU verir,
     GEÇERLİLİK vermez — her ad bugünkü kataloga karşı doğrulanır. */

/* ============================================================================
   DERS — ŞİFRELİ NESNEYE "BİLEMEYİZ" DEMEK GEREKMİYOR
   Mantık okunamıyorsa DAVRANIŞ kanıtlanır: iki yönlü `EXCEPT` ile küme eşitliği
   testi, üç view'in de ne yaptığını KESİN belirledi. Sonra o eşdeğerlik bir
   değişmeze bağlanır — çünkü okunamayan mantık sessizce değişebilir.
   ============================================================================ */
