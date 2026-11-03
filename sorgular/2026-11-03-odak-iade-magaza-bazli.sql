/*
  ODAK'a yapılan İADE İRSALİYELERİ — mağaza bazlı (DerinSISBkm)
  Soru: 20 Eylül 2026 sonrası ODAK'a mağaza bazlı iade analizi.

  BULGU (canlı doğrulandı 2026-11-03):
    ODAK iade = dbo.irs eFirma=9525 (ODAK KİTAP-POİNT İNTERNET TEKNOLOJİLERİ) +
                eTip 12 'Alış Mağaza İade' (mağaza→ODAK) [+ eTip 2 'Alış İade' merkez depo, 2 belge].
    ⚠ ODAK İADE DEPOSU = mekan 4480 'İade Deposu (ODAK)' DEĞİL: frmDurum=1 (pasif),
      20 Eylül sonrası 0 hareket. "ODAK'a iade" firma 9525 üstünden irsaliye ile yapılır.
    Adet = SUM(ABS(ehAdetN)) (iade çıkış = negatif). Tutar = SUM(ehTutarN) KDV-HARİÇ.
    Mağaza = i.eMekan: 1=FSM · 4477=Özlüce · 4478=İst.Yolu · 12=Merkez Depo.

  ÖLÇÜM (20.09–02.11.2026):
    İst.Yolu 175 irs / 32.674 ad / 435.134 ₺ · Özlüce 158 / 19.234 / 315.028 ·
    FSM 150 / 10.163 / 671.685 (en az adet, en yüksek tutar = Sinan Kuzucu soru bankası iadesi) ·
    Merkez Depo (eTip 2) 2 / 1.353 / 143.115.
  Üretim: scripts/odak_iade_analiz.py → raporlar/odak-iade-analiz-YYYYMMDD-*.xlsx
*/

-- Mağaza özeti
SELECT i.eMekan, COUNT(DISTINCT i.eID) irsaliye, COUNT(*) satir,
       SUM(ABS(h.ehAdetN)) iade_adet, SUM(h.ehTutarN) iade_tutar_kdvharic,
       COUNT(DISTINCT h.ehstkID) cesit
FROM dbo.irs i WITH(NOLOCK)
JOIN dbo.irsHrk h WITH(NOLOCK) ON h.ehID = i.eID
WHERE i.eFirma = 9525 AND i.eTip IN (2,12) AND i.eTarih >= '20260920'
GROUP BY i.eMekan;

-- İrsaliye listesi (iade dispatch note'ları)
SELECT i.eID, i.eNo, i.eTarih, i.eMekan, i.eTip,
       COUNT(*) satir, SUM(ABS(h.ehAdetN)) adet, SUM(h.ehTutarN) tutar,
       COUNT(DISTINCT h.ehstkID) cesit
FROM dbo.irs i WITH(NOLOCK)
JOIN dbo.irsHrk h WITH(NOLOCK) ON h.ehID = i.eID
WHERE i.eFirma = 9525 AND i.eTip IN (2,12) AND i.eTarih >= '20260920'
GROUP BY i.eID, i.eNo, i.eTarih, i.eMekan, i.eTip
ORDER BY i.eTarih, i.eMekan;

-- Teyit: ODAK iade deposu (mekan 4480) 20 Eylül sonrası BOŞ (bu analizde kullanılmaz)
SELECT COUNT(*) AS mekan4480_hareket_20eylulsonrasi
FROM dbo.irsHrk WITH(NOLOCK) WHERE ehMekan = 4480 AND ehTrhS >= '20260920';
