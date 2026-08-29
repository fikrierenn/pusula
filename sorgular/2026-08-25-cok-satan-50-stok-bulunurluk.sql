/* =====================================================================================
   ÇOK SATAN ÜRÜN × STOK × BULUNURLUK (OSA) — keşif + analiz SQL'i (25.08.2026)
   Soru : En çok satan 50 ürünün stok seviyesi / bulunurluğu ne? Sezona hazır mıyız?
   DB   : DerinSISBkm (192.168.40.201)
   Rapor: docs/2026-08-25-cok-satan-stok-bulunurluk.md · Script: scripts/cok_satan_bulunurluk.py
   Bulgu özeti:
     - Şube cirosunun %40'ı (322M ₺) Sınav Okulları PAKET SKU'su → raf stoğu yok, evrenden çıkar.
     - Raf evreni 8.856 SKU / 431,2M ₺. Top50 ciro payı yalnız %9,4 (uzun kuyruk).
     - Sezon SKU'larının 108'i stok/sezon-talep <%25; bunun 52'si geçen yıl da öyleydi (JIT normal)
       → GERÇEK GERİLEME 56 SKU. Kritik 108'in 79'unda son 60 günde SİPARİŞ SATIRI YOK.
     - Raf evreninin %30'u en az bir şubede kuru; tarihsel ort. 2,6/12 ay kuru (%21 OOS-ay).
     - Kapsam >365 gün olan 1.986 SKU → ~22,6M ₺ bağlı para.
   Konvansiyon: satış ehTip 4/100, iade 5/101 (ehAdetN çıkışta NEGATİF) · ehTutarN KDV-HARİÇ
                şube mekan 1/4477/4478 · ehAltDepo=0 · urnTip=0
   ===================================================================================== */

DECLARE @ay0   date = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);  -- bu ay kısmi → hariç
DECLARE @bas12 date = DATEADD(MONTH, -12, @ay0);
DECLARE @bas3  date = DATEADD(MONTH,  -3, @ay0);
DECLARE @bas1  date = DATEADD(MONTH,  -1, @ay0);
DECLARE @min   int  = 3;   -- bulunurluk eşiği (sema: metrics.bulunurluk_osa)

/* ---------------------------------------------------------------------------
   BLOK 1 — ÇOK SATAN EVRENİ (son 12 tam ay, şube perakende)
   NOT: Kategori3='Sınav Okulları' / KatAna 'Sınav Okul%' = HİZMET/PAKET SKU (raf stoğu yok)
        Poşet (Kategori3='Genel', ambalaj) adet sıralamasını domine eder → ikisi de HARİÇ.
   --------------------------------------------------------------------------- */
WITH satis AS (
    SELECT h.ehstkID,
           -SUM(h.ehAdetN)                                                       AS adet12,
           SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE -h.ehTutarN END) AS ciro12,
           -SUM(CASE WHEN h.ehTrhS >= @bas3 THEN h.ehAdetN ELSE 0 END)            AS adet3,
           -SUM(CASE WHEN h.ehTrhS >= @bas1 THEN h.ehAdetN ELSE 0 END)            AS adet1,
           COUNT(DISTINCT h.ehMekan)                                              AS satan_sube
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehTip IN (4,100,5,101) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo = 0
      AND h.ehTrhS >= @bas12 AND h.ehTrhS < @ay0
    GROUP BY h.ehstkID
), stok_sube AS (   -- anlık şube stoğu = irsHrk kümülatif (mağazada WMS yok)
    SELECT h.ehstkID,
           SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END) AS stok_fsm,
           SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END) AS stok_ozl,
           SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END) AS stok_ist
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehAltDepo = 0
    GROUP BY h.ehstkID
)
SELECT TOP 200
       u.stkID, u.stkAd, u.KatAna, u.Kategori3, u.mrkAd, u.FirmaAd, u.SonAlis,
       s.adet12, s.ciro12, s.adet3, s.adet1, s.satan_sube,
       ss.stok_fsm, ss.stok_ozl, ss.stok_ist,
       ISNULL(od.StokMiktar, 0)                                                   AS stok_depo_odak,
       CASE WHEN s.adet3 > 0
            THEN CONVERT(decimal(10,1), (ss.stok_fsm + ss.stok_ozl + ss.stok_ist) / (s.adet3 / 90.0))
       END                                                                        AS kapsam_gun
FROM satis s
JOIN bkm.UrunBilgi u              ON u.stkID = s.ehstkID AND u.urnTip = 0
LEFT JOIN stok_sube ss            ON ss.ehstkID = s.ehstkID
OUTER APPLY (SELECT SUM(o.StokMiktar) AS StokMiktar FROM ent.odak_depo_Stok o WHERE o.stkID = s.ehstkID) od
WHERE u.KatAna NOT LIKE N'Sınav Okul%' AND ISNULL(u.Kategori3, N'') <> N'Sınav Okulları'
  AND NOT (u.stkAd LIKE N'%Poşet%' AND u.Kategori3 = N'Genel')
  AND u.stkAd NOT LIKE N'SHF-%'                       -- sahaf: tekil kopya, reorder edilemez
ORDER BY s.ciro12 DESC;                               -- adet listesi için: ORDER BY s.adet12 DESC

/* ---------------------------------------------------------------------------
   BLOK 2 — HARİÇ TUTULANIN BÜYÜKLÜĞÜ (neden evren temizliği şart)
   --------------------------------------------------------------------------- */
SELECT CASE WHEN u.KatAna LIKE N'Sınav Okul%' OR u.Kategori3 = N'Sınav Okulları' THEN 'SINAV OKULLARI (paket/hizmet)'
            WHEN u.stkAd LIKE N'%Poşet%' AND u.Kategori3 = N'Genel'              THEN 'POŞET (ambalaj)'
            ELSE 'RAF ÜRÜNÜ' END                                                  AS kova,
       COUNT(DISTINCT u.stkID)                                                     AS sku,
       -SUM(h.ehAdetN)                                                             AS adet,
       SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE -h.ehTutarN END)      AS ciro
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.UrunBilgi u ON u.stkID = h.ehstkID AND u.urnTip = 0
WHERE h.ehTip IN (4,100,5,101) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo = 0
  AND h.ehTrhS >= @bas12 AND h.ehTrhS < @ay0
GROUP BY CASE WHEN u.KatAna LIKE N'Sınav Okul%' OR u.Kategori3 = N'Sınav Okulları' THEN 'SINAV OKULLARI (paket/hizmet)'
              WHEN u.stkAd LIKE N'%Poşet%' AND u.Kategori3 = N'Genel'              THEN 'POŞET (ambalaj)'
              ELSE 'RAF ÜRÜNÜ' END
ORDER BY ciro DESC;

/* ---------------------------------------------------------------------------
   BLOK 3 — TARİHSEL BULUNURLUK: son 12 ayın kaç ayı "kuru" (giriş bakiyesi < @min)
   Tuzak (sema entities.bkm.StokAyBakiyeMekanBazli):
     satır sadece HAREKETLİ aya yazılır → carry-forward ŞART (Donem <= hedef, TOP 1 DESC)
     "o ay satılabilir miydi" → GİRİŞ bakiyesi = M-1 ay sonu (same-month-end DEĞİL)
   @hedef tablosuna Blok 1'in stkID'lerini koy.
   --------------------------------------------------------------------------- */
DECLARE @hedef TABLE (stkID int PRIMARY KEY);
-- INSERT @hedef(stkID) VALUES (1582646),(1520662), ... ;   -- Blok 1 çıktısı

;WITH aylar AS (   -- 12 ayın GİRİŞ dönemi = önceki ayın son günü
    SELECT DATEADD(DAY, -1, DATEADD(MONTH, n.k, @bas12)) AS giris
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11)) n(k)
), grid AS (
    SELECT t.stkID, m.mekan, a.giris
    FROM @hedef t
    CROSS JOIN (VALUES (1),(4477),(4478)) m(mekan)
    CROSS JOIN aylar a
)
SELECT g.stkID, g.mekan,
       SUM(CASE WHEN ISNULL(b.Stok,0) < @min THEN 1 ELSE 0 END) AS kuru_ay,
       SUM(CASE WHEN b.Stok IS NULL THEN 1 ELSE 0 END)          AS kayit_yok_ay
FROM grid g
OUTER APPLY (SELECT TOP 1 x.Stok
             FROM bkm.StokAyBakiyeMekanBazli x WITH(NOLOCK)
             WHERE x.stkID = g.stkID AND x.ehMekan = g.mekan AND x.Kaynak = 'irsHrk'
               AND x.Donem <= g.giris
             ORDER BY x.Donem DESC) b
GROUP BY g.stkID, g.mekan
ORDER BY kuru_ay DESC;

/* ---------------------------------------------------------------------------
   BLOK 4 — SEZON HAZIRLIĞI: geçen yıl Ağu-Eki talebi vs BUGÜNKÜ stok
   (Kapsam metriği son-3-ay hızına dayanır → mevsimsel üründe YANILTIR; sezon-bazlı ölç.)
   --------------------------------------------------------------------------- */
WITH sezon AS (   -- geçen yıl okul sezonu (01.08.2025 - 01.11.2025)
    SELECT h.ehstkID,
           -SUM(h.ehAdetN)                                                        AS sezon_adet,
           SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE -h.ehTutarN END)  AS sezon_ciro
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehTip IN (4,100,5,101) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo = 0
      AND h.ehTrhS >= DATEFROMPARTS(2025,8,1) AND h.ehTrhS < DATEFROMPARTS(2025,11,1)
    GROUP BY h.ehstkID
), stok AS (
    SELECT h.ehstkID,
           SUM(h.ehAdetN)                                                                    AS stok_bugun,
           SUM(CASE WHEN h.ehTrhS < DATEFROMPARTS(2025,8,26) THEN h.ehAdetN ELSE 0 END)      AS stok_gecen_yil
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehAltDepo = 0
    GROUP BY h.ehstkID
)
SELECT TOP 100 u.stkID, u.stkAd, u.Kategori3,
       z.sezon_adet, z.sezon_ciro,
       s.stok_gecen_yil, s.stok_bugun, ISNULL(od.dp,0) AS depo_bugun,
       CONVERT(decimal(6,3), (s.stok_bugun + ISNULL(od.dp,0)) * 1.0 / NULLIF(z.sezon_adet,0)) AS hazirlik_orani,
       CASE WHEN s.stok_gecen_yil * 1.0 / NULLIF(z.sezon_adet,0) < 0.25
            THEN 'JIT (gecen yil da dusuk)' ELSE 'GERCEK GERILEME' END                        AS tani
FROM sezon z
JOIN bkm.UrunBilgi u ON u.stkID = z.ehstkID AND u.urnTip = 0
JOIN stok s          ON s.ehstkID = z.ehstkID
OUTER APPLY (SELECT SUM(o.StokMiktar) AS dp FROM ent.odak_depo_Stok o WHERE o.stkID = z.ehstkID) od
WHERE z.sezon_adet >= 100
  AND u.KatAna NOT LIKE N'Sınav Okul%'
  AND (s.stok_bugun + ISNULL(od.dp,0)) * 1.0 / z.sezon_adet < 0.25
ORDER BY z.sezon_ciro DESC;

/* ---------------------------------------------------------------------------
   BLOK 5 — "MAL YOLDA MI?" açık sipariş kontrolü
   ⚠️ TUZAK: sipariş GİRİŞ tarihi = sip.eTarih. sip.eTarihS = SEVK PLANI ve geçmişte kalabilir
      (25.08.2026'da eTarihS max 31.07.2026 → "Ağustos'ta sipariş yok" YANLIŞ sonucu verir).
   ⚠️ Adet = sipAyr.ehAdet (ehAdetN farklı/0 olabilir). ehSevkAdet kullanılmıyor (NULL)
      → karşılanma oranı ÖLÇÜLEMİYOR, yalnız "sipariş satırı var/yok".
   eTip: 0=dış alım · 3=? · 9=iade emri · 13=depo→mağaza sevk (sema codes sip.eTip)
   --------------------------------------------------------------------------- */
SELECT a.ehStkID, s.eTip, COUNT(DISTINCT s.eID) AS siparis, SUM(a.ehAdet) AS adet,
       MAX(CONVERT(varchar(10), s.eTarih, 104)) AS son_siparis
FROM dbo.sipAyr a WITH(NOLOCK)
JOIN dbo.sip s WITH(NOLOCK) ON s.eID = a.ehID
WHERE a.ehStkID IN (SELECT stkID FROM @hedef)
  AND s.eTarih >= DATEADD(DAY, -60, GETDATE()) AND s.eDurum <> 2
GROUP BY a.ehStkID, s.eTip
ORDER BY a.ehStkID, s.eTip;

/* ---------------------------------------------------------------------------
   BLOK 6 — DEPODA VAR / RAFTA YOK (dağıtım hatası — satınalma değil sevk sorunu)
   --------------------------------------------------------------------------- */
WITH sat AS (
    SELECT h.ehstkID, h.ehMekan, -SUM(h.ehAdetN) AS adet12
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehTip IN (4,100,5,101) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo = 0
      AND h.ehTrhS >= @bas12 AND h.ehTrhS < @ay0
    GROUP BY h.ehstkID, h.ehMekan
), stk AS (
    SELECT h.ehstkID, h.ehMekan, SUM(h.ehAdetN) AS stok
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehAltDepo = 0
    GROUP BY h.ehstkID, h.ehMekan
)
SELECT TOP 100 u.stkID, u.stkAd, u.Kategori3,
       CASE s.ehMekan WHEN 1 THEN 'FSM' WHEN 4477 THEN 'Özlüce' ELSE 'İst.Yolu' END AS kuru_sube,
       s.adet12 AS sube_satis_12ay, ISNULL(k.stok,0) AS sube_stok, od.dp AS depo_stok
FROM sat s
JOIN bkm.UrunBilgi u ON u.stkID = s.ehstkID AND u.urnTip = 0
LEFT JOIN stk k      ON k.ehstkID = s.ehstkID AND k.ehMekan = s.ehMekan
CROSS APPLY (SELECT SUM(o.StokMiktar) AS dp FROM ent.odak_depo_Stok o WHERE o.stkID = s.ehstkID) od
WHERE ISNULL(k.stok,0) < @min AND s.adet12 > 0 AND od.dp >= 10
  AND u.KatAna NOT LIKE N'Sınav Okul%'
ORDER BY s.adet12 DESC;
