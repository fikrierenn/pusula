/* ============================================================================
   2026-06-25 · Yevmiye fişi ↔ Fatura audit + köprü keşfi (DerinSISBkm)
   Soru: Yevmiye/fatura "kim oluşturdu/değiştirdi" + fiş↔fatura bağı var mı?
   Bulgu:
     - Audit: mhsFisBaslik & fat → gKisi/gTarih(oluşturan), kKisi/kTarih(değiştiren),
       oKisi/oTarih(onaylayan) → drn1.insID (insAd+insSoyad). "Değişti mi"=kTarih>gTarih.
       Alan-bazlı değişiklik LOG tablosu YOK.
     - Köprü: fat.eMhsFisID = mhsFisBaslik.fisbID (fisbID GLOBAL benzersiz). TEMİZ sayısal.
       eNo ile eşleme YANILTIR (noktalı varyant '25225839.' ayrı belge).
     - Üst hesap: mhsHsp.hspKod prefix self-join (hspAnaID DEĞİL — o TDHP grup no).
   Sema: bridges.yaml fat-mhsfis / hesap-usthesap / kisi-drn1.
   ============================================================================ */

-- 1) Fiş audit + üst hesap (yevmiye sayfası sorgusunun çekirdeği)
SELECT b.fisbID, b.yevmiyeNo,
       LTRIM(RTRIM(g.insAd+' '+g.insSoyad)) AS Giren,
       CONVERT(varchar(10),b.gTarih,104)+' '+CONVERT(varchar(5),b.gTarih,108) AS GirisT,
       LTRIM(RTRIM(k.insAd+' '+k.insSoyad)) AS Degistiren,
       CONVERT(varchar(10),b.kTarih,104)+' '+CONVERT(varchar(5),b.kTarih,108) AS DegisT,
       LTRIM(RTRIM(o.insAd+' '+o.insSoyad)) AS Onaylayan,
       h.hspKod, LTRIM(RTRIM(h.hspAd)) AS HesapAd,
       LTRIM(RTRIM(p.hspAd)) AS UstAd, p.hspKod AS UstKod
FROM mhs.mhsFisBaslik b
JOIN mhs.mhsFis ff ON ff.fisID=b.fisbID AND ff.fisSirketID=b.fisbSirketID
JOIN mhs.mhsHsp h  ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
LEFT JOIN mhs.mhsHsp p ON p.hspSirketID=h.hspSirketID
     AND CHARINDEX('.',REVERSE(h.hspKod))>0
     AND p.hspKod=LEFT(h.hspKod, LEN(h.hspKod)-CHARINDEX('.',REVERSE(h.hspKod)))
LEFT JOIN dbo.drn1 g ON g.insID=b.gKisi
LEFT JOIN dbo.drn1 k ON k.insID=b.kKisi
LEFT JOIN dbo.drn1 o ON o.insID=b.oKisi
WHERE b.fisbID=15466371 AND b.fisbSirketID=6
ORDER BY ff.fsID;

-- 2) Fatura → yevmiye köprüsü (eMhsFisID, çift yön)
SELECT b.fisbID, b.yevmiyeNo, fa.eID AS FaturaEID, fa.eNo AS FaturaNo
FROM mhs.mhsFisBaslik b
OUTER APPLY (SELECT TOP 1 f2.eID, f2.eNo FROM dbo.fat f2 WHERE f2.eMhsFisID=b.fisbID) fa
WHERE b.fisbID IN (15466371,15466372) AND b.fisbSirketID=6;

-- 3) fisbID global benzersiz mi? (köprüde sirket gerekmez kanıtı) → 0 dönmeli
SELECT COUNT(*) AS TekrarEdenFisbID
FROM (SELECT TOP 100 fisbID FROM mhs.mhsFisBaslik
      GROUP BY fisbID HAVING COUNT(DISTINCT fisbSirketID)>1) x;

-- 4) Fatura audit + matrah/kdv toplamı (ne değişti sinyali: kTarih>gTarih)
SELECT f.eID, f.eNo, CONVERT(varchar(10),f.eTarihS,104) eTarih, f.eMhsFisID,
       LTRIM(RTRIM(g.insAd+' '+g.insSoyad)) Giren, CONVERT(varchar(16),f.gTarih,120) gT,
       CONVERT(varchar(16),f.kTarih,120) kT,
       (SELECT SUM(a.ehTutar)+SUM(ISNULL(a.ehTutarKDV,0)) FROM dbo.fatAyr a WHERE a.ehID=f.eID) AS GenelToplam
FROM dbo.fat f LEFT JOIN dbo.drn1 g ON g.insID=f.gKisi
WHERE f.eID IN (7050402,7050409);
