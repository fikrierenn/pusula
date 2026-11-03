/*
  irsHrk + irs (irsaliye) TARİH KOLONLARI — hangisi ne? (DerinSISBkm)
  Soru: "depoya en son giriş/kabul" için doğru tarih hangisi?
  Bağlam: stok_satis_aylik_wide.py "Depoya Son Giriş (Alış)" kolonu.

  ÖLÇÜM (2026-10-12, ehTip=0 Alış, mekan 12, Tem–Eki 2026, 11.740 hareket):
    ehTrhS = eTarihS (stok efektif)  : 11.740 / 11.740  = %100  ← BİREBİR
    ehTrhS = eTarih  (irsaliye belge): 9.142  / 11.740  = %77,9 (⇒ %22 FARKLI)
    ehTrhS = kTarih  (kayıt zamanı)  : 7.692  / 11.740  = %65,5
    eTarih <> kTarih (belge≠kayıt)   : 6.640  / 11.740  = %56,6

  SONUÇ (ölçülü, tahmin değil):
    irs.eTarih   = İRSALİYENİN KENDİ belge tarihi (tedarikçi irsaliyesi üstündeki). Mal yolda olabilir.
    irs.eTarihS  = STOK EFEKTİF tarihi (malın stoğa/depoya işlendiği gün) = irsHrk.ehTrhS (%100).
    irs.kTarih/gTarih/oTarih = kaydın sisteme GİRİLDİĞİ an (timestamp, saat:dk).
    irsHrk.hrkTarih = hareket satırının kayıt anı (timestamp).
    irs.eTarihV  = vade (ödeme) tarihi.
  ⇒ "Depoya kabul/giriş günü" = irsHrk.ehTrhS (= eTarihS). İrsaliye belge tarihi (eTarih) DEĞİL.

  AYRICA (mekan 12 ehTip, 2026, canlı):
    ehTip=0  Alış (tedarikçi mal kabul) — GİRİŞ (ehAdetN>0).
    ehTip=13 "Depo→Mağaza" — ÇIKIŞ (ehAdetN<0). ⚠ Eski sema notu "13=mal kabul giriş" YANLIŞTI
             (o not mağaza tarafı bağlamıydı; depo tarafında 13 çıkıştır).
    ehTip=9  "Mağaza→Depo" (mağaza iadesi) — GİRİŞ. 16 Stok EKLE / 88 Diğer Giriş / 3 Satış İade de giriş.
*/

-- 1) Tarih kolonlarının kimliği (hangi irs tarihi = ehTrhS)
SELECT COUNT(*) AS toplam,
  SUM(CASE WHEN CONVERT(date,h.ehTrhS)=CONVERT(date,i.eTarih)  THEN 1 ELSE 0 END) AS ehTrhS_eq_eTarih_belge,
  SUM(CASE WHEN CONVERT(date,h.ehTrhS)=CONVERT(date,i.eTarihS) THEN 1 ELSE 0 END) AS ehTrhS_eq_eTarihS_stok,
  SUM(CASE WHEN CONVERT(date,h.ehTrhS)=CONVERT(date,i.kTarih)  THEN 1 ELSE 0 END) AS ehTrhS_eq_kTarih_kayit,
  SUM(CASE WHEN CONVERT(date,i.eTarih)<>CONVERT(date,i.kTarih) THEN 1 ELSE 0 END) AS belge_kayit_farkli
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN dbo.irs   i WITH(NOLOCK) ON i.eID = h.ehID
WHERE h.ehTip = 0 AND h.ehMekan = 12 AND h.ehTrhS >= '20260701';

-- 2) Ayrışan vaka (belge ≠ kayıt) — tarihlerin ne olduğunu gözle gör
SELECT TOP 20 h.ehID, h.ehTrhS AS hrk_ehTrhS, i.eTarih AS irs_belge, i.eTarihS AS stok_efektif,
       i.gTarih AS giris_ts, i.kTarih AS kayit_ts, i.eTarihV AS vade,
       DATEDIFF(day, i.eTarih, i.kTarih) AS belge_kayit_fark
FROM dbo.irs i WITH(NOLOCK)
JOIN dbo.irsHrk h WITH(NOLOCK) ON h.ehID = i.eID AND h.ehTip = 0 AND h.ehMekan = 12
WHERE i.eTarih >= '20260801' AND DATEDIFF(day, i.eTarih, i.kTarih) <> 0
ORDER BY h.hrkTarih DESC;

-- 3) Ürün bazında depoya son alış tarihi (stok_satis_aylik_wide.py bunu kullanır)
SELECT h.ehstkID, CONVERT(date, MAX(h.ehTrhS)) AS depoya_son_giris
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = h.ehstkID AND u.Kat3ID IN (10,12,16)
WHERE h.ehTip = 0 AND h.ehMekan = 12
GROUP BY h.ehstkID;
