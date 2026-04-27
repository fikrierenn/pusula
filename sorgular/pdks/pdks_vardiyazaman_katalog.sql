/* =======================================================================
   BKM.vrd.VardiyaZaman · Tam Katalog
   -----------------------------------------------------------------------
   Vardiya tanımlarının tamamı — hangi kod izin, hangisi çalışma?
   ======================================================================= */

SELECT TOP 200
  VardiyaId,
  Aciklama,
  GrupNo,
  Aktif,
  CONVERT(varchar(5), Baslama, 108) AS Bas,
  CONVERT(varchar(5), Bitis,   108) AS Bit,
  MolaSureDk,
  ToplamCalismaDk,
  Izin,
  EkBilgi1,
  EkBilgi2
FROM vrd.VardiyaZaman
ORDER BY VardiyaId;

/* =====================================================================
   KRİTİK NOTLAR (15.04.2026 keşfi):

   İZİN KODLARI (Izin = 1):
     51 HFT.İZİN        · 52 ÜCRETSİZ İZİN   · 53 ÜCRTLİ İZİN
     55 RESMİ TATİL     · 58 YILLIK İZİN      · 63 RAPOR
     73 MESAİ İZNİ

   ÇALIŞMA VARDİYALARI (Izin = 0):
     1-19, 50, 62 GÜVENLİK (23:00-07:30 gece), 72-113 ...

   ⚠ FİLTRE HATASI:
     Eski sorgularda NOT IN (51,52,53,55,58,62,63,73) yazıyordu.
     62 GÜVENLİK aslında çalışma vardiyası — filtreden ÇIKARILMALI.
     Doğru filtre: vz.Izin = 0  (veya NOT IN (51,52,53,55,58,63,73))

   ⚠ KOD 100 "ÖZEL DURUM":
     Izin = 0, saat 00:00-00:00, ToplamCalismaDk = 0
     Sistem açısından izin değil ama çalışma da değil — belirsiz slot.
     Pratikte "plan belirsiz / değişken" anlamında kullanılıyor.
     3 kişi bu kodda: EMRE KALFA (HEYKEL), HATİCE KÜBRA BOZDOĞAN (ÖZLÜCE),
                      ZEYNEP İÇEL (ÖZLÜCE).
   ===================================================================== */
