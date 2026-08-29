-- Beyaz yaka maaş listesi — GENEL MÜDÜRLÜK ofis kadrosu (dar kapsam)
-- Sunucu: Zirve (ZIRVE\ZRVSQL2008) · DB: BKM_GENEL · MCP: mcp__zirve__sql_query
-- Kaynak: dbo.vw_PersonelDepartman = İK KANONİK kaynağı (ham dbo.perbilgi DEĞİL — perbilgi.Maas BAYAT)
--
-- KRİTİK KURALLAR (2026-08-29 keşif):
--   1) AKTİF = Ict IS NULL  (Personeldurumu DEĞİL — tarihçe içerir)
--   2) Ucret = CARİ oran, puanbil Tem'26 ile birebir tuttu (207/212 exact, kalan 2 ara-dönem zam)
--   3) Ucretsekli iki türlü:  GÜNLÜK (338 kişi, aylık = Ucret × 30)  |  AYLIK (3 kişi, doğrudan)
--      View Ucretsekli'yi TAŞIMIYOR → eşik ayrımı: GÜNLÜK max 3.333 ₺ · AYLIK min 100.000 ₺
--      (Aradaki uçurum sayesinde 8.000 ₺ eşiği güvenli; puanbil ile 212/212 doğrulandı.)
--   4) Tüm tutarlar NET (TahakkukSekli = 'NET'), BRÜT DEĞİL.
--   5) View 3 firmayı birleştirir (BKM_GENEL 288 + BURSA_KÜLTÜR_MERKEZİ 36 + ASİYE_BİNGÖLBALİ 17 = 341).
--      dbo.perbilgi yalnız BKM_GENEL'i (288) tutar → perbilgi'ye join edersen 53 kişi SESSİZCE düşer.
--
-- Beyaz yaka tanımı (kullanıcı onayı 29.08.2026 — DAR kapsam):
--   Lokasyon = 'GENEL MÜDÜRLÜK', eksi saha/fiziksel ünvanlar (depo, forklift, şoför, bekçi, temizlik, bakım).
--   Mağaza/kafe yönetimi (Mağaza Müdürü, Md.Yrd., Kafe Yöneticisi) ile şef kadroları (Reyon/Kasa/Mutfak) HARİÇ.
-- Sonuç: 48 kişi · toplam aylık net 3.213.381,20 ₺ (ölçüm 29.08.2026)
-- Emitter: scripts/beyaz_yaka_maas_excel.py → briefings/2026-08-29/beyaz-yaka-maas-listesi.xlsx

SELECT
    v.Personelno,
    v.AdSoyad,
    v.Departman,
    v.Unvan,
    v.Firma,
    CONVERT(varchar, v.Igt, 104)                                   AS GirisTarihi,
    CAST(DATEDIFF(DAY, v.Igt, GETDATE()) / 365.25 AS decimal(5,1)) AS KidemYil,
    v.Ucret                                                        AS UcretOran,
    CASE WHEN v.Ucret < 8000 THEN 'GÜNLÜK' ELSE 'AYLIK' END        AS UcretSekli,
    CAST(CASE WHEN v.Ucret < 8000 THEN v.Ucret * 30
              ELSE v.Ucret END AS decimal(18,2))                   AS AylikNet,
    v.Cinsiyet,
    v.OgrenimDurumu,
    v.Banka,
    v.Iban
FROM dbo.vw_PersonelDepartman v
WHERE v.Ict IS NULL
  AND v.Lokasyon = 'GENEL MÜDÜRLÜK'
  AND ISNULL(v.Unvan, '') NOT IN (
        'DEPO PERSONELİ', 'DEPO SORUMLUSU', 'FORKLİFT OPERATÖRÜ',
        'MAL KABUL SORUMLUSU', 'ŞOFÖR', 'BEKÇİ', 'TEMİZLİK PERSONELİ',
        'BAKIM ONARIM UZMANI'
      )
ORDER BY AylikNet DESC;
