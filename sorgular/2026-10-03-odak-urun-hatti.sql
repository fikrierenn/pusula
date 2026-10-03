/* ============================================================================
   ODAK ÜRÜN · FİYAT · ÖZELLİK · STOK HATTI — tam keşif  (2026-10-03)
   DB: DerinSISBkm + BKMDATA + msdb (profil: erp) · salt-okuma
   Rapor: docs/13-odak-urun-hatti.md · sema: entities odak_alt_sistemi_yuzeyi,
          odak_urun_hatti_kurallari, odak_fiyat_aktarim_motoru
   ============================================================================ */

/* ── 0a) ODAK'a dokunan TÜM modüller (ad ya da tanımında 'odak') ─────────────
   Sonuç: DerinSISBkm 58 modül · BKMDATA 16 modül. */
SELECT s.name+'.'+o.name obje, o.type, o.modify_date, LEN(m.definition) uzunluk
FROM DerinSISBkm.sys.sql_modules m JOIN DerinSISBkm.sys.objects o ON o.object_id=m.object_id
JOIN DerinSISBkm.sys.schemas s ON s.schema_id=o.schema_id
WHERE m.definition LIKE '%odak%' OR o.name LIKE '%odak%';
-- (BKMDATA için aynısı)

/* ── 0b) SQL Agent: çağıran job'lar + takvim + son koşum ─────────────────────
   odakUrunAktar_job: saatlik 08:30-23:01, adım1 ent.odakUrunAktar 0, adım2 ent.tsofturunaktarim 0 (son 4dk30sn)
   OdakDegisenStokGuncelle: 5 dk · JOKER_IPTAL_STOKKODLARI: 5 dk
   OdakUrunGuncellemeEslestir ve 6 SP'nin çağıranı JOB DEĞİL, MODÜL DEĞİL. */
SELECT j.name, j.enabled, s.step_id, s.database_name, s.command
FROM msdb.dbo.sysjobs j JOIN msdb.dbo.sysjobsteps s ON s.job_id=j.job_id
WHERE s.command LIKE '%odak%' OR j.name LIKE '%odak%' OR s.command LIKE '%tsoft%';

/* ── 0c) Koşum istatistiği (plan önbelleği, 30.09'dan beri) ───────────────── */
SELECT DB_NAME(ps.database_id) db, OBJECT_NAME(ps.object_id,ps.database_id) sp,
       ps.execution_count, ps.last_execution_time, ps.total_elapsed_time/1000/NULLIF(ps.execution_count,0) ort_ms
FROM sys.dm_exec_procedure_stats ps
WHERE OBJECT_NAME(ps.object_id,ps.database_id) LIKE '%odak%' OR OBJECT_NAME(ps.object_id,ps.database_id) LIKE 'tsoft%';

/* ── 0d) Eşitleme koşum log'u: Tip 0 (web) → Tip 1 (mağaza), saatlik ──────── */
SELECT TOP 30 * FROM BKMDATA.dbo.OdakDataProcedureRunTime ORDER BY LogDate DESC;

/* ── 01_lookup ── */
SELECT 'bilgi' k, CONVERT(varchar,t.BilgiID) id, t.BilgiAd ad FROM DerinSISBkm.dbo.urnBilgiTnm t WHERE t.BilgiID IN (10,101,102,106,168,169,174,175,176,177,181,183,184,185,189,190,191,192,193,198,200,204,220,228)
UNION ALL SELECT 'kod1', CONVERT(varchar,kod1ID), kod1Ad FROM DerinSISBkm.dbo.urnKod1
UNION ALL SELECT 'status', CONVERT(varchar,saleStatusId)+'/'+CONVERT(varchar,SatisDurum), Aciklama FROM BKMDATA.dbo.OdakUrunDurumStatus
UNION ALL SELECT 'kod5', CONVERT(varchar,kod5ID), '['+kod5Ad+']' FROM DerinSISBkm.dbo.urnkod5 WHERE kod5ID IN (133048,180833)
UNION ALL SELECT 'frm', CONVERT(varchar,frmID), frmAd FROM DerinSISBkm.dbo.frm WHERE frmID IN (56,9525)
UNION ALL SELECT 'kisi137', '137', ISNULL((SELECT TOP 1 CONVERT(varchar,1) FROM DerinSISBkm.sys.objects WHERE 1=0),'?')


/* ── 02_tam_profil ── */
SELECT 'tam' t, satis_durum, SilinecekUrun, SadeceMagaza, COUNT(*) n,
 SUM(CASE WHEN ISNULL(barkod,'')='' THEN 1 ELSE 0 END) bos_barkod,
 SUM(CASE WHEN etiket_fiyat=0 THEN 1 ELSE 0 END) fiyat0,
 SUM(CASE WHEN etiket_fiyat>=999999 THEN 1 ELSE 0 END) fiyat999999,
 MIN(dtarih) min_dt, MAX(dtarih) max_dt
FROM BKMDATA.ent.odak_urun_tam WITH(NOLOCK) GROUP BY satis_durum, SilinecekUrun, SadeceMagaza
UNION ALL
SELECT 'magaza', satis_durum, SilinecekUrun, SadeceMagaza, COUNT(*),
 SUM(CASE WHEN ISNULL(barkod,'')='' THEN 1 ELSE 0 END), SUM(CASE WHEN etiket_fiyat=0 THEN 1 ELSE 0 END),
 SUM(CASE WHEN etiket_fiyat>=999999 THEN 1 ELSE 0 END), MIN(dtarih), MAX(dtarih)
FROM BKMDATA.ent.odak_urun_magaza_tam WITH(NOLOCK) GROUP BY satis_durum, SilinecekUrun, SadeceMagaza
ORDER BY 1,2,3,4


/* ── 03_kdv ── */
SELECT KDV, COUNT(*) n, SUM(CASE WHEN satis_durum=1 THEN 1 ELSE 0 END) aktif FROM BKMDATA.ent.odak_urun_tam WITH(NOLOCK) GROUP BY KDV ORDER BY n DESC


/* ── 04_ciftbarkod ── */
SELECT 'tam_ayni_barkod_coklu_urun_id' olcum, COUNT(*) n FROM (SELECT barkod FROM BKMDATA.ent.odak_urun_tam WITH(NOLOCK) GROUP BY barkod HAVING COUNT(*)>1) x
UNION ALL SELECT 'tam_ayni_barkod_farkli_fiyat', COUNT(*) FROM (SELECT barkod FROM BKMDATA.ent.odak_urun_tam WITH(NOLOCK) GROUP BY barkod HAVING COUNT(*)>1 AND MIN(etiket_fiyat)<>MAX(etiket_fiyat)) x
UNION ALL SELECT 'CiftUrunlerMaxFyat_satir', COUNT(*) FROM DerinSISBkm.bkm.CiftUrunlerMaxFyat
UNION ALL SELECT 'tam_urun_id_tekrar', COUNT(*) FROM (SELECT urun_id FROM BKMDATA.ent.odak_urun_tam WITH(NOLOCK) GROUP BY urun_id HAVING COUNT(*)>1) x
UNION ALL SELECT 'magaza_urun_id_tekrar', COUNT(*) FROM (SELECT urun_id FROM BKMDATA.ent.odak_urun_magaza_tam WITH(NOLOCK) GROUP BY urun_id HAVING COUNT(*)>1) x
UNION ALL SELECT 'urnBarkod_tekrar', COUNT(*) FROM (SELECT urnBarkod FROM DerinSISBkm.dbo.urnBrkd WITH(NOLOCK) GROUP BY urnBarkod HAVING COUNT(*)>1) x
UNION ALL SELECT 'tam_barkod_urnBrkd_esles', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) WHERE EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) WHERE b.urnBarkod=o.barkod)
UNION ALL SELECT 'tam_barkod_eslesmez', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) WHERE NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) WHERE b.urnBarkod=o.barkod)
UNION ALL SELECT 'tam_barkod_eslesmez_aktif_silinmez', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) WHERE o.satis_durum=1 AND o.SilinecekUrun=0 AND NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) WHERE b.urnBarkod=o.barkod)
UNION ALL SELECT 'stkID_birden_cok_odak_satiri', COUNT(*) FROM (SELECT b.urnBrkdStkID FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod GROUP BY b.urnBrkdStkID HAVING COUNT(*)>1) x


/* ── 05_magaza_fiyat ── */
SELECT 'magaza>tam' d, COUNT(*) n FROM BKMDATA.ent.odak_urun_magaza_tam m WITH(NOLOCK) JOIN BKMDATA.ent.odak_urun_tam t WITH(NOLOCK) ON t.urun_id=m.urun_id WHERE m.etiket_fiyat>t.etiket_fiyat
UNION ALL SELECT 'magaza<tam', COUNT(*) FROM BKMDATA.ent.odak_urun_magaza_tam m WITH(NOLOCK) JOIN BKMDATA.ent.odak_urun_tam t WITH(NOLOCK) ON t.urun_id=m.urun_id WHERE m.etiket_fiyat<t.etiket_fiyat
UNION ALL SELECT 'magaza=tam', COUNT(*) FROM BKMDATA.ent.odak_urun_magaza_tam m WITH(NOLOCK) JOIN BKMDATA.ent.odak_urun_tam t WITH(NOLOCK) ON t.urun_id=m.urun_id WHERE m.etiket_fiyat=t.etiket_fiyat
UNION ALL SELECT 'magaza_var_tam_yok', COUNT(*) FROM BKMDATA.ent.odak_urun_magaza_tam m WITH(NOLOCK) WHERE NOT EXISTS(SELECT 1 FROM BKMDATA.ent.odak_urun_tam t WHERE t.urun_id=m.urun_id)
UNION ALL SELECT 'tam_var_magaza_yok', COUNT(*) FROM BKMDATA.ent.odak_urun_tam t WITH(NOLOCK) WHERE NOT EXISTS(SELECT 1 FROM BKMDATA.ent.odak_urun_magaza_tam m WHERE m.urun_id=t.urun_id)
UNION ALL SELECT 'tam_vs_odak_urun_fiyat_farkli', COUNT(*) FROM BKMDATA.ent.odak_urun o WITH(NOLOCK) JOIN BKMDATA.ent.odak_urun_tam t WITH(NOLOCK) ON t.urun_id=o.urun_id WHERE o.etiket_fiyat<>t.etiket_fiyat
UNION ALL SELECT 'tam_vs_odak_urun_satisdurum_farkli', COUNT(*) FROM BKMDATA.ent.odak_urun o WITH(NOLOCK) JOIN BKMDATA.ent.odak_urun_tam t WITH(NOLOCK) ON t.urun_id=o.urun_id WHERE o.satis_durum<>t.satis_durum
UNION ALL SELECT 'tam_vs_odak_urun_barkod_farkli', COUNT(*) FROM BKMDATA.ent.odak_urun o WITH(NOLOCK) JOIN BKMDATA.ent.odak_urun_tam t WITH(NOLOCK) ON t.urun_id=o.urun_id WHERE o.barkod<>t.barkod


/* ── 06_acilan ── */
SELECT CONVERT(varchar(7),u.kTarih,120) ay, COUNT(*) acilan_137,
 SUM(CASE WHEN u.urnKtgrID=1 THEN 1 ELSE 0 END) kategori1_kalan,
 SUM(CASE WHEN u.kod1ID=1 THEN 1 ELSE 0 END) aktif, SUM(CASE WHEN u.kod1ID=0 THEN 1 ELSE 0 END) pasif, SUM(CASE WHEN u.kod1ID=2 THEN 1 ELSE 0 END) tukendi,
 SUM(CASE WHEN u.piyasaMarj>0 THEN 1 ELSE 0 END) piyasaMarj_dolu
FROM DerinSISBkm.dbo.urn u WITH(NOLOCK) WHERE u.ugKisi=137 AND u.kTarih>=DATEADD(MONTH,-12,GETDATE())
GROUP BY CONVERT(varchar(7),u.kTarih,120) ORDER BY ay DESC


/* ── 07_bilgi10 ── */
SELECT 'bagli_urun' o, COUNT(DISTINCT u.stkID) n FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID WHERE o.SilinecekUrun=0
UNION ALL SELECT 'bilgi10_yok', COUNT(DISTINCT u.stkID) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID WHERE o.SilinecekUrun=0 AND NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) WHERE x.bVeriID=u.stkID AND x.bBilgiID=10)
UNION ALL SELECT 'bilgi10_yok_son90g_acilan', COUNT(DISTINCT u.stkID) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID WHERE o.SilinecekUrun=0 AND u.kTarih>=DATEADD(DAY,-90,GETDATE()) AND NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) WHERE x.bVeriID=u.stkID AND x.bBilgiID=10)
UNION ALL SELECT 'son90g_acilan_bagli', COUNT(DISTINCT u.stkID) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID WHERE o.SilinecekUrun=0 AND u.kTarih>=DATEADD(DAY,-90,GETDATE())
UNION ALL SELECT 'son90g_bagli_bilgi174_yok', COUNT(DISTINCT u.stkID) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID WHERE o.SilinecekUrun=0 AND u.kTarih>=DATEADD(DAY,-90,GETDATE()) AND NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) WHERE x.bVeriID=u.stkID AND x.bBilgiID=174)


/* ── 08_stkkod_ne_barkod ── */
SELECT 'bagli_stkKod<>barkod' o, COUNT(*) n FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID WHERE u.stkKod<>o.barkod
UNION ALL SELECT 'bagli_stkKod=barkod', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID WHERE u.stkKod=o.barkod
UNION ALL SELECT '193_farkli_stkKod<>barkod', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=u.stkID AND x.bBilgiID=193 WHERE u.stkKod<>o.barkod AND o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(10),o.basim_tarihi_yil)
UNION ALL SELECT '193_farkli_stkKod=barkod', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=u.stkID AND x.bBilgiID=193 WHERE u.stkKod=o.barkod AND o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(10),o.basim_tarihi_yil)
UNION ALL SELECT '191_farkli_stkKod<>barkod', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=u.stkID AND x.bBilgiID=191 WHERE u.stkKod<>o.barkod AND o.SilinecekUrun=0 AND x.bDeger<>CASE WHEN ISNULL(o.sayfa_sayisi,0)>1 THEN CONVERT(varchar(10),o.sayfa_sayisi) ELSE '' END
UNION ALL SELECT '192_farkli_stkKod<>barkod', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=u.stkID AND x.bBilgiID=192 WHERE u.stkKod<>o.barkod AND o.SilinecekUrun=0 AND x.bDeger<>ISNULL(CONVERT(varchar(10),o.basim_sayisi),'')
UNION ALL SELECT '192_farkli_stkKod=barkod', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=u.stkID AND x.bBilgiID=192 WHERE u.stkKod=o.barkod AND o.SilinecekUrun=0 AND x.bDeger<>ISNULL(CONVERT(varchar(10),o.basim_sayisi),'')


/* ── 09_enboy ── */
SELECT '101_en_farkli' o, COUNT(*) n FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=b.urnBrkdStkID AND x.bBilgiID=101 WHERE o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(20),o.en)
UNION ALL SELECT '102_boy_farkli', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=b.urnBrkdStkID AND x.bBilgiID=102 WHERE o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(20),o.boy)
UNION ALL SELECT '106_agirlik_farkli', COUNT(*) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=b.urnBrkdStkID AND x.bBilgiID=106 WHERE o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(20),o.agirlik)
UNION ALL SELECT '101_toplam', COUNT(*) FROM DerinSISBkm.dbo.urnBilgi WITH(NOLOCK) WHERE bBilgiID=101
UNION ALL SELECT '101_tek_deger_sayisi', COUNT(DISTINCT bDeger) FROM DerinSISBkm.dbo.urnBilgi WITH(NOLOCK) WHERE bBilgiID=101
UNION ALL SELECT '184_kalan_tarih_gecmis', COUNT(*) FROM DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) WHERE x.bBilgiID=184 AND TRY_CONVERT(date,x.bDeger)<=CAST(GETDATE() AS date)
UNION ALL SELECT '184_toplam', COUNT(*) FROM DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) WHERE x.bBilgiID=184


/* ── 10_tarih ── */
SELECT TOP 12 CONVERT(varchar(7),u.gTarih,120) g_ay, COUNT(*) n, MIN(u.stkID) min_id, MAX(u.stkID) max_id, SUM(CASE WHEN u.kTarih>=DATEADD(DAY,-3,GETDATE()) THEN 1 ELSE 0 END) kTarih_son3g
FROM DerinSISBkm.dbo.urn u WITH(NOLOCK) WHERE u.ugKisi=137 GROUP BY CONVERT(varchar(7),u.gTarih,120) ORDER BY g_ay DESC


/* ── 11_ornek ── */
SELECT TOP 6 'en' k, o.barkod, CONVERT(varchar(20),o.en) odak, x.bDeger erp, u.stkKod FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=b.urnBrkdStkID AND x.bBilgiID=101 WHERE o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(20),o.en)
UNION ALL SELECT TOP 6 'boy', o.barkod, CONVERT(varchar(20),o.boy), x.bDeger, u.stkKod FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=b.urnBrkdStkID AND x.bBilgiID=102 WHERE o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(20),o.boy)
UNION ALL SELECT TOP 6 'agirlik', o.barkod, CONVERT(varchar(20),o.agirlik), x.bDeger, u.stkKod FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=b.urnBrkdStkID AND x.bBilgiID=106 WHERE o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(20),o.agirlik)
UNION ALL SELECT TOP 6 'yil=', o.barkod, CONVERT(varchar(20),o.basim_tarihi_yil), x.bDeger, u.stkKod FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=u.stkID AND x.bBilgiID=193 WHERE u.stkKod=o.barkod AND o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(10),o.basim_tarihi_yil)
UNION ALL SELECT TOP 6 'yil<>', o.barkod, CONVERT(varchar(20),o.basim_tarihi_yil), x.bDeger, u.stkKod FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=u.stkID AND x.bBilgiID=193 WHERE u.stkKod<>o.barkod AND o.SilinecekUrun=0 AND x.bDeger<>CONVERT(varchar(10),o.basim_tarihi_yil)


/* ── 12_bilgi10_test ── */
SELECT 'insert_bloğu_aynen' t, COUNT(*) n
from DerinSISBkm.dbo.urn with(nolock) JOIN DerinSISBkm.dbo.urnBrkd AS bar with(nolock) ON bar.urnBrkdStkID=urn.stkID
inner JOIN BKMDATA.ent.odak_urun_tam odak with(nolock) on barkod=bar.urnBarkod
LEFT JOIN DerinSISBkm.dbo.urnBilgi ubilgi with(nolock) ON ubilgi.bVeriID=urn.stkID AND ubilgi.bBilgiID=10
WHERE ubilgi.bBilgiID IS NULL AND odak.SilinecekUrun=0
AND IIF(odak.kategori_id_2 ='001007002',odak.marka_ad+' '+ odak.[urun_ad],odak.[urun_ad] ) <>bDeger
UNION ALL SELECT 'kosul_bDeger_olmadan', COUNT(*)
from DerinSISBkm.dbo.urn with(nolock) JOIN DerinSISBkm.dbo.urnBrkd AS bar with(nolock) ON bar.urnBrkdStkID=urn.stkID
inner JOIN BKMDATA.ent.odak_urun_tam odak with(nolock) on barkod=bar.urnBarkod
LEFT JOIN DerinSISBkm.dbo.urnBilgi ubilgi with(nolock) ON ubilgi.bVeriID=urn.stkID AND ubilgi.bBilgiID=10
WHERE ubilgi.bBilgiID IS NULL AND odak.SilinecekUrun=0


/* ── 13_sayisal ── */
SELECT kol, COUNT(*) urun,
 SUM(CASE WHEN TRY_CONVERT(decimal(9,2),en_e)<>en THEN 1 ELSE 0 END) en_fark,
 SUM(CASE WHEN TRY_CONVERT(decimal(9,2),boy_e)<>boy THEN 1 ELSE 0 END) boy_fark,
 SUM(CASE WHEN TRY_CONVERT(decimal(9,2),ag_e)<>agirlik THEN 1 ELSE 0 END) agirlik_fark,
 SUM(CASE WHEN basim_tarihi_yil<>0 AND TRY_CONVERT(int,yil_e)<>basim_tarihi_yil THEN 1 ELSE 0 END) yil_fark,
 SUM(CASE WHEN ISNULL(basim_sayisi,0)<>0 AND TRY_CONVERT(int,bs_e)<>basim_sayisi THEN 1 ELSE 0 END) basimsayisi_fark,
 SUM(CASE WHEN ISNULL(sayfa_sayisi,0)>1 AND TRY_CONVERT(int,ss_e)<>sayfa_sayisi THEN 1 ELSE 0 END) sayfa_fark,
 SUM(CASE WHEN cilt_e<>cilt_tipi THEN 1 ELSE 0 END) cilt_fark,
 SUM(CASE WHEN kag_e<>kagit_cinsi THEN 1 ELSE 0 END) kagit_fark,
 SUM(CASE WHEN ac_e<>ISNULL(urun_aciklama,'') THEN 1 ELSE 0 END) aciklama_fark,
 SUM(CASE WHEN alt_e<>ISNULL(urun_alt_baslik,'') THEN 1 ELSE 0 END) altbaslik_fark,
 SUM(CASE WHEN stkAd<>LTRIM(RTRIM(SUBSTRING(CONVERT(varchar(100),urun_ad),1,100))) THEN 1 ELSE 0 END) ad_fark
FROM (
 SELECT CASE WHEN u.stkKod=o.barkod THEN 'stkKod=barkod' ELSE 'stkKod<>barkod' END kol, o.en,o.boy,o.agirlik,o.basim_tarihi_yil,o.basim_sayisi,o.sayfa_sayisi,o.cilt_tipi,o.kagit_cinsi,CONVERT(nvarchar(4000),o.urun_aciklama) urun_aciklama,o.urun_alt_baslik,o.urun_ad,u.stkAd,
  x101.bDeger en_e,x102.bDeger boy_e,x106.bDeger ag_e,x193.bDeger yil_e,x192.bDeger bs_e,x191.bDeger ss_e,x190.bDeger cilt_e,x189.bDeger kag_e,x175.bDeger ac_e,x177.bDeger alt_e
 FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x101 WITH(NOLOCK) ON x101.bVeriID=u.stkID AND x101.bBilgiID=101
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x102 WITH(NOLOCK) ON x102.bVeriID=u.stkID AND x102.bBilgiID=102
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x106 WITH(NOLOCK) ON x106.bVeriID=u.stkID AND x106.bBilgiID=106
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x193 WITH(NOLOCK) ON x193.bVeriID=u.stkID AND x193.bBilgiID=193
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x192 WITH(NOLOCK) ON x192.bVeriID=u.stkID AND x192.bBilgiID=192
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x191 WITH(NOLOCK) ON x191.bVeriID=u.stkID AND x191.bBilgiID=191
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x190 WITH(NOLOCK) ON x190.bVeriID=u.stkID AND x190.bBilgiID=190
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x189 WITH(NOLOCK) ON x189.bVeriID=u.stkID AND x189.bBilgiID=189
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x175 WITH(NOLOCK) ON x175.bVeriID=u.stkID AND x175.bBilgiID=175
 LEFT JOIN DerinSISBkm.dbo.urnBilgi x177 WITH(NOLOCK) ON x177.bVeriID=u.stkID AND x177.bBilgiID=177
 WHERE o.SilinecekUrun=0 AND u.stkID NOT IN (SELECT urnBrkdStkID FROM DerinSISBkm.bkm.CiftUrunlerMaxFyat)
) z GROUP BY kol


/* ── 14_acilis ── */
SELECT CONVERT(varchar(7),u.gTarih,120) ay, COUNT(*) acilan, SUM(CASE WHEN u.urnKtgrID=1 THEN 1 ELSE 0 END) ktgr1_kaldi,
 SUM(CASE WHEN u.kod1ID=1 THEN 1 ELSE 0 END) aktif, SUM(CASE WHEN u.kod1ID=0 THEN 1 ELSE 0 END) pasif, SUM(CASE WHEN u.kod1ID=2 THEN 1 ELSE 0 END) tukendi,
 SUM(CASE WHEN u.piyasaMarj>0 THEN 1 ELSE 0 END) piyasaMarj_dolu, SUM(CASE WHEN u.fiyatS=0 THEN 1 ELSE 0 END) fiyatS0,
 SUM(CASE WHEN x.bVeriID IS NOT NULL THEN 1 ELSE 0 END) b169_true
FROM DerinSISBkm.dbo.urn u WITH(NOLOCK) LEFT JOIN DerinSISBkm.dbo.urnBilgi x WITH(NOLOCK) ON x.bVeriID=u.stkID AND x.bBilgiID=169 AND x.bDeger='True'
WHERE u.ugKisi=137 AND u.gTarih>=DATEADD(MONTH,-12,GETDATE()) GROUP BY CONVERT(varchar(7),u.gTarih,120) ORDER BY ay DESC


/* ── 15_frm ── */
SELECT 'urnFrm_56' o, COUNT(*) n FROM DerinSISBkm.dbo.urnFrm WITH(NOLOCK) WHERE urnFrmFirmaID=56
UNION ALL SELECT 'urnFrm_9525', COUNT(*) FROM DerinSISBkm.dbo.urnFrm WITH(NOLOCK) WHERE urnFrmFirmaID=9525
UNION ALL SELECT 'urn_toplam', COUNT(*) FROM DerinSISBkm.dbo.urn WITH(NOLOCK)
UNION ALL SELECT 'urn_ktgr_not_43_35', COUNT(*) FROM DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE urnKtgrID NOT IN (43,35)
UNION ALL SELECT 'urn_ktgr_not_43_35_9525_yok', COUNT(*) FROM DerinSISBkm.dbo.urn u WITH(NOLOCK) WHERE urnKtgrID NOT IN (43,35) AND NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnFrm f WHERE f.urnFrmStkID=u.stkID AND f.urnFrmFirmaID=9525)
UNION ALL SELECT 'urnFrm_9525_esas1', COUNT(*) FROM DerinSISBkm.dbo.urnFrm WITH(NOLOCK) WHERE urnFrmFirmaID=9525 AND urnFrmEsas=1
UNION ALL SELECT 'urn_stkFirma_9525', COUNT(*) FROM DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE stkFirma=9525
UNION ALL SELECT 'urn_stkFirma_56', COUNT(*) FROM DerinSISBkm.dbo.urn WITH(NOLOCK) WHERE stkFirma=56
UNION ALL SELECT 'urn_stkFirma_esas0_degil', COUNT(*) FROM DerinSISBkm.dbo.urn u WITH(NOLOCK) WHERE EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnFrm f WHERE f.urnFrmStkID=u.stkID AND f.urnFrmEsas=0) AND NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnFrm f WHERE f.urnFrmStkID=u.stkID AND f.urnFrmEsas=0 AND f.urnFrmFirmaID=u.stkFirma)
UNION ALL SELECT 'urn_esas0_birden_cok', COUNT(*) FROM (SELECT urnFrmStkID FROM DerinSISBkm.dbo.urnFrm WITH(NOLOCK) WHERE urnFrmEsas=0 GROUP BY urnFrmStkID HAVING COUNT(*)>1) x


/* ── 16_kod1 ── */
SELECT o.satis_durum, o.SilinecekUrun, o.SadeceMagaza, ISNULL(st.SatisDurum,-9) odak_stat, u.kod1ID, COUNT(*) n
FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID
LEFT JOIN BKMDATA.dbo.OdakUrunDurum d WITH(NOLOCK) ON d.ProductCode=CONVERT(varchar(50),o.urun_id) LEFT JOIN BKMDATA.dbo.OdakUrunDurumStatus st ON st.saleStatusId=d.saleStatus
GROUP BY o.satis_durum, o.SilinecekUrun, o.SadeceMagaza, ISNULL(st.SatisDurum,-9), u.kod1ID ORDER BY n DESC


/* ── 17_misc ── */
SET LANGUAGE Turkish; SELECT 'tr_2025-11-01' o, CONVERT(varchar(10),CONVERT(datetime,'2025-11-01'),104) v
UNION ALL SELECT 'tr_01.11.2025', CONVERT(varchar(10),CONVERT(datetime,'01.11.2025'),104)
UNION ALL SELECT 'sifre_dolu', CONVERT(varchar,COUNT(*)) FROM DerinSISBkm.bkm.OneriSiparisOdakKullanici WHERE LEN(ISNULL(OdakSifre,''))>0
UNION ALL SELECT 'sifre_toplam', CONVERT(varchar,COUNT(*)) FROM DerinSISBkm.bkm.OneriSiparisOdakKullanici
UNION ALL SELECT 'fat_eTarih_tip', TYPE_NAME(system_type_id) FROM DerinSISBkm.sys.columns WHERE object_id=OBJECT_ID('DerinSISBkm.dbo.fat') AND name='eTarih'
UNION ALL SELECT 'login_dil', (SELECT default_language_name FROM sys.server_principals WHERE name=SUSER_SNAME())
UNION ALL SELECT 'maliyet_view_dup_stk', CONVERT(varchar,COUNT(*)) FROM (SELECT StkID FROM BKMDATA.ent.OdakUrunMaliyet GROUP BY StkID HAVING COUNT(*)>1) x
UNION ALL SELECT 'maliyet_view_satir', CONVERT(varchar,COUNT(*)) FROM BKMDATA.ent.OdakUrunMaliyet
UNION ALL SELECT 'tam_marka_eslesmez', CONVERT(varchar,COUNT(*)) FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) WHERE NOT EXISTS(SELECT 1 FROM BKMDATA.ent.odak_marka m WHERE m.group_id=o.group_id AND m.parent_id=o.marka_id)
UNION ALL SELECT 'marka_discount_dagilim_>13', CONVERT(varchar,COUNT(*)) FROM BKMDATA.ent.odak_marka WHERE discount>13
UNION ALL SELECT 'hardcode_barkod_9786257283298', (SELECT TOP 1 CONVERT(varchar,b.urnBrkdStkID)+' '+u.stkAd FROM DerinSISBkm.dbo.urnBrkd b JOIN DerinSISBkm.dbo.urn u ON u.stkID=b.urnBrkdStkID WHERE b.urnBarkod='9786257283298')
UNION ALL SELECT 'hardcode_bakiye_9786257283298', CONVERT(varchar,SUM(bakiye)) FROM BKMDATA.dbo.stok_aktarim_odak WHERE barkod='9786257283298'
UNION ALL SELECT 'stok_aktarim_barkod_eslesmez_satir', CONVERT(varchar,COUNT(*)) FROM BKMDATA.dbo.stok_aktarim_odak s WHERE NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnBrkd b WHERE b.urnBarkod=s.barkod)
UNION ALL SELECT 'stok_aktarim_barkod_eslesmez_bakiye', CONVERT(varchar,SUM(bakiye)) FROM BKMDATA.dbo.stok_aktarim_odak s WHERE NOT EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnBrkd b WHERE b.urnBarkod=s.barkod)
UNION ALL SELECT 'stok_aktarim_negatif', CONVERT(varchar,COUNT(*)) FROM BKMDATA.dbo.stok_aktarim_odak WHERE bakiye<0
UNION ALL SELECT 'depo_stok_negatif', CONVERT(varchar,COUNT(*)) FROM DerinSISBkm.ent.odak_depo_Stok WHERE StokMiktar<0
UNION ALL SELECT 'depo_stok_toplam_adet', CONVERT(varchar,SUM(CONVERT(bigint,StokMiktar))) FROM DerinSISBkm.ent.odak_depo_Stok
UNION ALL SELECT 'stok_aktarim_toplam_adet', CONVERT(varchar,SUM(CONVERT(bigint,bakiye))) FROM BKMDATA.dbo.stok_aktarim_odak


/* ── 18_140 ── */
SELECT CASE WHEN c.urnBrkdStkID IS NULL THEN 'tekil' ELSE 'cift' END tur, u.kod1ID, COUNT(DISTINCT u.stkID) n,
 COUNT(DISTINCT CASE WHEN akt.stkID IS NOT NULL THEN u.stkID END) baska_satiri_aktif
FROM BKMDATA.ent.odak_urun_tam o WITH(NOLOCK) JOIN DerinSISBkm.dbo.urnBrkd b WITH(NOLOCK) ON b.urnBarkod=o.barkod JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=b.urnBrkdStkID
LEFT JOIN DerinSISBkm.bkm.CiftUrunlerMaxFyat c ON c.urnBrkdStkID=u.stkID
LEFT JOIN (SELECT DISTINCT b2.urnBrkdStkID stkID FROM BKMDATA.ent.odak_urun_tam o2 JOIN DerinSISBkm.dbo.urnBrkd b2 ON b2.urnBarkod=o2.barkod
           WHERE o2.satis_durum=1 AND o2.SilinecekUrun=0 AND o2.SadeceMagaza=0) akt ON akt.stkID=u.stkID
WHERE (o.SilinecekUrun=1 OR o.SadeceMagaza=1) AND u.kod1ID<>0
GROUP BY CASE WHEN c.urnBrkdStkID IS NULL THEN 'tekil' ELSE 'cift' END, u.kod1ID
-- cift/1: 141 (141'i aktif ikinci satırlı) · cift/2: 7

/* ── 19_log ── */
SELECT CONVERT(varchar(10),LogTarih,104) gun, ISNULL(CONVERT(varchar,Tip),'NULL') Tip, COUNT(*) n
FROM BKMDATA.ent.odak_urun_log WITH(NOLOCK) WHERE LogTarih>=DATEADD(DAY,-7,CAST(GETDATE() AS date))
GROUP BY CONVERT(varchar(10),LogTarih,104), ISNULL(CONVERT(varchar,Tip),'NULL'), CAST(LogTarih AS date) ORDER BY CAST(LogTarih AS date) DESC, 2


/* ── 20_view_tarih ── */
SELECT 'view_mevcut' o, COUNT(*) n FROM DerinSISBkm.bkm.OdakIadeIrsaliyeleriFaturalasmamis
UNION ALL SELECT 'ca_fatura_kasimdan_once', COUNT(*) FROM DerinSISBkm.bkm.OdakIadeIrsaliyeleriFaturalasmamis v JOIN DerinSISBkm.dbo.fat f ON f.eID=v.AlisFatId WHERE f.eTarih<'01.11.2025'


/* ── SONUÇ ÖZETİ (2026-10-03) ─────────────────────────────────────────────
 02 tam: satışta 345.425 · satış dışı 295.364 · SadeceMagaza 7.278 · Silinecek 2.084 · fiyat 0 / ≥999999 yok
 03 KDV 0: 623.790 · 20: 17.833 · 10: 7.265
 04 aynı barkod çok urun_id 36 (32'si farklı fiyat) · CiftUrunlerMaxFyat 350 stkID · urnBarkod tekil
 05 mağaza fiyatı = web fiyatı 648.875/648.875
 07+12 bilgi 10 ekleme bloğu: aynen 0 satır, karşılaştırmasız 599.370 → ÖLÜ BLOK
 10 gTarih = açılış (stkID monoton); kTarih değişim tarihi — açılış için KULLANMA
 13 künye sapması: stkKod<>barkod (23.230) yıl 2.360 · basım 115 · sayfa 60 · boy 1.293 · alt başlık 46
                   stkKod=barkod (623.185) yıl 0 · basım 0 · sayfa 0 · boy 4.099 · alt başlık 4.532
 14 otomatik açılış (ugKisi=137, gTarih) ayda 3.000-4.650
 15 urnFrm 9525: 808.775 · stkFirma=9525: 679.076 / 842.648
 16+18 silinecek/yalnız-mağaza ama aktif 141 → 141'i çift, hepsinin aktif ikinci satırı var
 17 '2025-11-01' Türkçe oturumda 11.01.2025 · OdakSifre dolu 7/8 · stok mutabakatı 7.591.652 − 2.469 − 7 = 7.589.176
 19 odak_urun_log Tip yalnız 0/1 (mağaza değişimi DEFAULT 0 ile web gibi yazılıyor)
 20 OdakIadeIrsaliyeleriFaturalasmamis bugün 0 satır
 ek: bayraksız tekil üründe urn.fiyatS = etiket_fiyat 645.914/645.914 · 220 bayraklı 401/501 farklı
 ek: irsaliye KDV (9525, eTip 1, 30 gün, iskontolu+KDV'li 797) → iskonto sonrası 719, yalnız öncesi 0
 ek: OdakStokDegisenStok_Log 94.739.458 (12.09: 92.392.737)
*/

/* ══ EK — SORUNLARIN DERİN İNCELEMESİ (2026-10-03, ikinci tur) ═══════════════
   Satır numaraları sys.sql_modules tanımına göre. */

/* ── E1) odakFiyatAktarim satır 63-84 + 130-131: 228'li üründe her saat fiyat satırı ──
   30g: satış satırı 4.702.211 · sahte önceki (etiket-0,01) 4.630.424 · distinct ürün 36.497
   228=True 10.108 ürün → 4.560.438 satır (ürün başı 451, 30 günün 29'u) · bugün saatte ~10.465 satır */
WITH r AS (SELECT f.fStkID, COUNT(*) satir, COUNT(DISTINCT b.feTarihA) gun
           FROM DerinSISBkm.dbo.fytOzl f JOIN DerinSISBkm.dbo.fytB b ON b.feID=f.fhID
           WHERE b.feNot LIKE '%Odak2 Ent' AND b.feTarihA>=DATEADD(DAY,-30,GETDATE())
             AND f.fTur=0 AND f.oncekiFiyat=f.sonrakiFiyat-0.01 GROUP BY f.fStkID)
SELECT CASE WHEN x228.bVeriID IS NOT NULL THEN '228_True' ELSE '228_yok' END b228,
       COUNT(*) urun, SUM(r.satir) satir, AVG(r.satir) ort_satir, AVG(r.gun) ort_gun
FROM r LEFT JOIN DerinSISBkm.dbo.urnBilgi x228 ON x228.bVeriID=r.fStkID AND x228.bBilgiID=228 AND x228.bDeger='True'
GROUP BY CASE WHEN x228.bVeriID IS NOT NULL THEN '228_True' ELSE '228_yok' END;

SELECT CONVERT(varchar(13),b.gTarih,120) saat, COUNT(*) satir
FROM DerinSISBkm.dbo.fytOzl f JOIN DerinSISBkm.dbo.fytB b ON b.feID=f.fhID
WHERE b.feNot LIKE '%Odak2 Ent' AND b.feTarihA>=CAST(GETDATE() AS date)
GROUP BY CONVERT(varchar(13),b.gTarih,120) ORDER BY 1;

/* ── E2) 220 bayrağı ikinci blokta yok: elle fiyat eziliyor (15 ürün, 3.037 satır/30g) ── */
WITH r AS (SELECT DISTINCT f.fStkID FROM DerinSISBkm.dbo.fytOzl f JOIN DerinSISBkm.dbo.fytB b ON b.feID=f.fhID
           JOIN DerinSISBkm.dbo.urnBilgi x ON x.bVeriID=f.fStkID AND x.bBilgiID=220 AND x.bDeger='True'
           WHERE b.feNot LIKE '%Odak2 Ent' AND b.feTarihA>=DATEADD(DAY,-30,GETDATE()) AND f.fTur=0)
SELECT u.stkID, u.fiyatS,
  (SELECT TOP 1 CONVERT(varchar(10),b.feTarihA,104)+' '+b.feNot+' '+CONVERT(varchar,f.sonrakiFiyat)
   FROM DerinSISBkm.dbo.fytOzl f JOIN DerinSISBkm.dbo.fytB b ON b.feID=f.fhID
   WHERE f.fStkID=u.stkID AND f.fTur=0 AND b.feNot NOT LIKE '%Odak2 Ent' ORDER BY f.fID DESC) son_elle
FROM r JOIN DerinSISBkm.dbo.urn u ON u.stkID=r.fStkID;
-- 1677679: elle 800 (03.10.2026) → bugün 864 = ODAK etiketi · 251314: elle 200 → 112,90

/* ── E3) satır 49 urnFrm fan-out: aynı ürün-gün çok satış satırı 323.590 ── */

/* ── E4) tsofturunaktarim 11-12 / 15-21: ERP'de kapalı ama web'de aktif 130/130 ODAK satışta ── */
SELECT COUNT(DISTINCT u.stkID) FROM DerinSISBkm.dbo.urn u JOIN DerinSISBkm.dbo.urnBrkd b ON b.urnBrkdStkID=u.stkID
JOIN BKMDATA.ent.odak_urun_tam o ON o.barkod=b.urnBarkod WHERE u.urnDurum=0 AND u.kod1ID=1 AND o.satis_durum=1;

/* ── E5) odakUrunAktar 879: kısa ad global — 842.648/842.648 = ilk 29 karakter (194.128 ODAK dışı) ── */
SELECT COUNT(*) toplam, SUM(CASE WHEN stkAdKisa=SUBSTRING(stkAd,0,30) THEN 1 ELSE 0 END) esit FROM DerinSISBkm.dbo.urn;

/* ── E6) odakUrunAktar 178-181: her koşumda güncellemeye giren ürün 25.480 ── */
SELECT COUNT(*) FROM DerinSISBkm.dbo.urn u WHERE EXISTS(SELECT 1 FROM DerinSISBkm.dbo.urnFrm f
  WHERE f.urnFrmStkID=u.stkID AND f.urnFrmEsas=0 AND f.urnFrmFirmaID<>u.stkFirma);

/* ── E7) Eslestir 34 (stkKod join) — bayat görsel: stkKod<>barkod 1.761/23.446 · eşit 183/623.357 ── */
SELECT CASE WHEN u.stkKod=o.barkod THEN 'esit' ELSE 'farkli' END grp, COUNT(*) urun,
       SUM(CASE WHEN w.kt IS NOT NULL AND o.gorsel_guncelleme_tarih>DATEADD(MINUTE,1,w.kt) THEN 1 ELSE 0 END) bayat
FROM BKMDATA.ent.odak_urun_tam o JOIN DerinSISBkm.dbo.urnBrkd b ON b.urnBarkod=o.barkod
JOIN DerinSISBkm.dbo.urn u ON u.stkID=b.urnBrkdStkID
LEFT JOIN (SELECT urnWebBilgiID, MAX(urnWebkTarih) kt FROM DerinSISBkmWeb.web.urnWeb GROUP BY urnWebBilgiID) w ON w.urnWebBilgiID=u.stkID
WHERE o.SilinecekUrun=0 GROUP BY CASE WHEN u.stkKod=o.barkod THEN 'esit' ELSE 'farkli' END;
