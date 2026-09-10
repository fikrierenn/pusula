/* ═══════════════════════════════════════════════════════════════════════════════
   ÖNERİ — WMS↔ERP FARKINI SAYIM EMRİNE ALMAK                          09.09.2026

   ⚠⚠ BU SCRIPT ÇALIŞTIRILMADI VE ÇALIŞTIRILMAMALI (benim tarafımdan).
   Hedefi `depo.emir` / `depo.emirAyr` — DerinSIS NATIVE tablolar.
   `.claude/rules/erp-write-policy.md`: native tablo yazımı MUTLAK YASAK; yalnız
   app-owned `bkm.*` tablolarına yazılabilir. Bu dosya DB yöneticisinin (Fikri)
   uygulaması için hazırlanmış bir ÖNERİ metnidir.

   ── PROBLEM ────────────────────────────────────────────────────────────────────
   WMS'te stok var ama ERP merkez defterinde yok: 349 çeşit / 3.757 adet (ölçüldü
   09.09.2026). 261'inde merkez satışı, 342'sinde belgesiz palet hareketi var.
   Kitap tarafında yığılı: Akademi %90 · Kitap %61 · Kırtasiye %0,9 · Oyuncak %0,8.

   MEKANİZMA (stkID 248104 uçtan uca izlendi):
     23.02.2026 İst.Yolu→merkez transfer +1 (irsaliye 7121400, WMS'e de işlendi)
     22.05.2026 merkez SATIŞ −1 (belge 7135278) — WMS'te KARŞILIĞI YOK
     10.07.2026 elle palet taşıması raf 44711 → GR01 37250 (piIrsID=0, belgesiz)
   Sonuç: ERP defteri 0, WMS 1 adet.

   ── NEDEN MEVCUT JOB'LAR YAKALAMIYOR ──────────────────────────────────────────
   `paletDegistir ve günlük wms irsaliye onay` (aktif): `irs`'te onay=0 AND
     eTip IN (16,90,99) olan WMS irsaliyelerini ONAYLAR. Hacim büyük — merkez depoda
     son 30 günde eTip 16 "Stok EKLE" +273.602 · eTip 90 "Ürün SAY" −183.054 ·
     eTip 99 "Sayım" −8.599 adet. AMA bu bir ONAY mekanizması, KARŞILAŞTIRMA değil:
     WMS'te işlem YAPILMIŞSA ERP'ye taşır. İşlem yoksa fark kalıcı olur.
   `WMS-GunlukSayimEmiri` (aktif): sayılacakları YALNIZ `depo.emirAyrIptal` +
     `depo.emirAyr` + `depo.paletUrnTnm` üzerinden seçiyor — yani iptal edilen emir
     satırları. Hayalet stok bu ölçüte GİRMİYOR.
   `ERP12 Güncelle`: senkron DEĞİL — `bkm.Erp12GunlukCiro` ciro özeti (adı yanıltıcı).

   ── DESEN KAYNAĞI: ent.JokerJokerCKEsitleme ───────────────────────────────────
   Kullanıcı işaret etti ("bundan esinlenebilirsin"). O SP'nin izlediği yol:
     1. Aktarım tablosunu TRUNCATE (Aktarim.dbo.JOKER_STOK_3108)
     2. İki kaynağı FULL OUTER JOIN ile karşılaştır → farkı aktarım tablosuna yaz
     3. depo.sayım başlığı aç (sNo, sDurum, sDepoID, cikisIrsaliyeID, girisIrsaliyeID)
     4. depo.sayımAyr'a satırları bas (spStkID, sAdet, sAdrsID, sSonPozAdrsID)
   Sonra gece job'u o sayım irsaliyesini onaylayarak ERP'ye işliyor. Zincir tam.

   ── ÖNERİLEN EN DAR ÇÖZÜM ─────────────────────────────────────────────────────
   YENİ JOB YAZMAYIN. `WMS-GunlukSayimEmiri`'nin `sayilcaklar` CTE'sine AŞAĞIDAKİ
   KOLU EKLEMEK yeterli: sayım/onay zinciri zaten çalışıyor, fark ona beslenir.
   (footprint-ladder: mevcut mekanizmayı genişlet, yeni yüzey açma.)

   ⚠ ÖNCE OKUNSUN — ÜÇ UYARI:
   1. TEK YÖNLÜ DEĞERLENDİRME YAPMAYIN. Ters yön de var ve daha büyük: ERP defteri
      pozitif ama WMS'te olmayan 9.146 çeşit / 1.996.995 adet. Merkez stoğu WMS'ten
      okunuyor çünkü defter kalıntı/negatif taşıyor. İki taraf da tek başına doğru
      değil; bu kol yalnız "WMS'te var, defterde yok" yönünü sayıma alır.
   2. SAYIM SONUCU FİZİKSEL OLMALI. Bu kol malın YOK olduğunu iddia etmez; "git bak"
      der. Sayımcı malı bulursa WMS doğrudur ve fark ERP tarafında düzeltilir.
   3. HACİM SINIRI ŞART. 349 çeşit bir günde sayıma verilirse depo boğulur; aşağıda
      günlük TOP 50 (en yüksek etiket değeri) alınıyor. Sayılanlar tekrar gelmesin
      diye bir "sayıldı" izi tutulmalı (aşağıda NOT EXISTS ile emir geçmişine bakılıyor).
   ═══════════════════════════════════════════════════════════════════════════════ */

/* ── `WMS-GunlukSayimEmiri` içindeki `sayilcaklar` CTE'sine EKLENECEK KOL ──────
   Mevcut CTE'nin sonuna UNION ALL ile eklenir; #src ile aynı kolon düzeni:
       adrsID · paletID · stkID · sistemAdet
   ------------------------------------------------------------------------------ */

UNION ALL

-- WMS'TE VAR AMA ERP MERKEZ DEFTERİNDE YOK (hayalet stok adayı)
SELECT TOP 50
       d.adrsID,
       d.PaletID,
       d.stkID,
       CONVERT(decimal(15,3), d.Stok) AS sistemAdet
FROM DerinSISBkm.depo.stok_adres_palet_vw d WITH (NOLOCK)
-- ERP merkez defteri net bakiyesi (mekan 12). Stok=WMS, hareket=defter: merkez STOĞU
-- için defter yasak (negatif taşıyor) ama HAREKET için tek kaynak.
OUTER APPLY (
    SELECT SUM(h.ehAdetN) AS Net
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehstkID = d.stkID AND h.ehMekan = 12
) df
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = d.stkID
WHERE d.Stok > 0
  AND d.adrsAlanTipID IN (0, 1)          -- RAF + GİRİŞ; ÇIKIŞ ALANI merkez stoğuna girmez
  AND ISNULL(df.Net, 0) <= 0             -- ERP'ye göre bu mal YOK
  AND u.urnTip = 0                       -- gider/hizmet/demirbaş hariç (urnTip 1/2)
  -- Aynı adres-palet-ürün son 30 günde sayıma verilmişse TEKRAR VERME (döngü olmasın).
  AND NOT EXISTS (
      SELECT 1
      FROM DerinSISBkm.depo.emirAyr ea WITH (NOLOCK)
      JOIN DerinSISBkm.depo.emir e WITH (NOLOCK) ON e.emirID = ea.emirID
      WHERE ea.emStkID = d.stkID
        AND e.kTarih >= DATEADD(DAY, -30, GETDATE())
  )
-- Önce PARASI BÜYÜK olan: sayımcının zamanı sınırlı.
ORDER BY CONVERT(decimal(18,2), d.Stok * ISNULL(u.fiyatS, 0)) DESC;


/* ── UYGULAMA ÖNCESİ DOĞRULAMA (salt-okuma, güvenle koşulur) ──────────────────
   Kolu job'a eklemeden önce KAÇ SATIR seçtiğini ve neyi seçtiğini gör.
   ------------------------------------------------------------------------------ */
SELECT TOP 50
       d.adrsID, d.PaletID, d.stkID,
       LEFT(ISNULL(u.stkAd, '(ad yok)'), 50) AS Urun,
       ISNULL(ub.Kategori3, '-')             AS Kategori,
       ISNULL(a.alanTipAd, '?')              AS AlanTipi,
       d.adrsAd                              AS Adres,
       CONVERT(int, d.Stok)                  AS WmsAdet,
       CONVERT(int, ISNULL(df.Net, 0))       AS ErpDefter,
       CONVERT(decimal(18,2), d.Stok * ISNULL(u.fiyatS, 0)) AS EtiketTutar
FROM DerinSISBkm.depo.stok_adres_palet_vw d WITH (NOLOCK)
OUTER APPLY (
    SELECT SUM(h.ehAdetN) AS Net
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehstkID = d.stkID AND h.ehMekan = 12
) df
LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = d.stkID
LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = d.stkID
LEFT JOIN DerinSISBkm.depo.adresAlanTip a ON a.alanTipID = d.adrsAlanTipID
WHERE d.Stok > 0
  AND d.adrsAlanTipID IN (0, 1)
  AND ISNULL(df.Net, 0) <= 0
  AND u.urnTip = 0
ORDER BY 10 DESC;
-- 09.09.2026 ölçümü: bu ölçütle toplam 349 çeşit / 3.757 adet aday çıkıyor.
-- Excel dökümü: python scripts/gr_palet_supheli_excel.py --tum-alanlar
--   (GR yalnız: 234 satır / 1.434 adet / 456.525 ₺ · tüm alanlar: 998 / 13.038 / 3.479.742 ₺)


/* ── ALTERNATİF: ters yönü de sayıma almak (İSTENİRSE) ────────────────────────
   Defterde pozitif ama WMS'te olmayan 9.146 çeşit / 1.996.995 adet. Bu yön çok
   daha büyük ve bilinen bir durum (defter kalıntısı) — sayıma alınırsa depoyu
   boğar. ÖNERİ: bu yön SAYIMA ALINMAZ; raporda izlenir. Karar kullanıcının.
   ------------------------------------------------------------------------------ */
SELECT COUNT(*) AS Cesit, CONVERT(bigint, SUM(e.Net)) AS DefterAdet
FROM (
    SELECT ehstkID, SUM(ehAdetN) AS Net
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan = 12
    GROUP BY ehstkID
    HAVING SUM(ehAdetN) > 0
) e
LEFT JOIN (
    SELECT stkID, SUM(Stok) AS WmsStok
    FROM DerinSISBkm.depo.stok_adres_palet_vw WITH (NOLOCK)
    WHERE adrsAlanTipID IN (0, 1)
    GROUP BY stkID
) w ON w.stkID = e.ehstkID
WHERE ISNULL(w.WmsStok, 0) <= 0;
-- 09.09.2026: 9.146 çeşit / 1.996.995 adet.
