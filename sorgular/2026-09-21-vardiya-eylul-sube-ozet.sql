-- Eylül 2026 fazla mesai — ŞUBE bazında, kaleme göre kırılım.
-- Soru (GMY 21.09.2026): "hafta tatili çalışması / vardiyasından önce gelenler /
--   geç çıkanlar / diğer olarak grupla, kaç saat olmuş"
-- DB: BkmPanel (BT-FIKRI\SQLEXPRESS) — DEV. Salt-okuma.
--
-- ⚠ KAPSAM: Tablo 31.08–16.09.2026 tek kesimini taşıyor. "Eylül" = 01–16 Eylül,
--    YARIM AY. Ay tamamlanmadı; 17-30 Eylül HENÜZ ÖLÇÜLMEDİ.
--
-- ⚠⚠ İKİ AYRI AYRIŞIM VAR, TOPLANMAZLAR (ölçüldü 21.09):
--    (a) TAHAKKUK ekseni — dört kalem, toplamı FazlaDk'ya BİREBİR eşit:
--        HaftalikPrimDk + FazlaCalismaDk + FazlaIzinIptalDk + FazlaPlansizDk = FazlaDk
--        (1.380 + 2.233 + 1.126 + 83 = 4.822 sa, tam)
--    (b) ZAMAN ekseni — GirisOncesiDk / CikisSonrasiDk: planın DIŞINDA geçen ham
--        dakika. Molası düşülmemiş, erken-gel/erken-çık netleşmemiş.
--        Normal günlerde (a)=122.895 dk iken (b)=157.529 dk → 34.634 dk FAZLA.
--    ⇒ "vardiya uzaması"nı giriş-öncesi + çıkış-sonrası diye bölmek ÇİFT SAYAR.
--       Erken/geç kırılımı AYRI bir ölçüm olarak okunur, toplama girmez.

DECLARE @b date = '2026-09-01', @s date = '2026-09-16';

-- 1) Şube bazında kırılım (saat)
SELECT Sube,
       COUNT(DISTINCT SicilNo)      AS Kisi,
       COUNT(*)                     AS KisiGun,
       SUM(HaftalikPrimDk)   / 60.0 AS HaftaTatili,      -- hafta tatilinde çalışma
       SUM(FazlaCalismaDk)   / 60.0 AS VardiyaUzamasi,   -- normal günde planın dışı
       SUM(FazlaIzinIptalDk) / 60.0 AS IzinIptali,       -- DİĞER (1)
       SUM(FazlaPlansizDk)   / 60.0 AS PlansizGun,       -- DİĞER (2)
       SUM(FazlaDk)          / 60.0 AS ToplamFazla,      -- dördünün toplamı
       SUM(GirisOncesiDk)    / 60.0 AS GirisOncesi,      -- AYRI EKSEN
       SUM(CikisSonrasiDk)   / 60.0 AS CikisSonrasi      -- AYRI EKSEN
FROM bkm.Vrd_KisiGun
WHERE Tarih BETWEEN @b AND @s
GROUP BY Sube
ORDER BY SUM(FazlaDk) DESC;

-- 2) İki eksenin neden toplanmadığının kanıtı (gün tipine göre)
SELECT CASE WHEN HaftalikPrimDk  > 0 THEN 'hafta tatili gunu'
            WHEN FazlaPlansizDk  > 0 THEN 'plansiz gun'
            WHEN FazlaIzinIptalDk> 0 THEN 'izin iptali gunu'
            ELSE 'normal gun' END      AS Grup,
       COUNT(*)                        AS Satir,
       SUM(FazlaCalismaDk)             AS FazlaCalismaDk,
       SUM(GirisOncesiDk + CikisSonrasiDk) AS PlanDisiHamDk
FROM bkm.Vrd_KisiGun
WHERE Tarih BETWEEN @b AND @s
GROUP BY CASE WHEN HaftalikPrimDk  > 0 THEN 'hafta tatili gunu'
              WHEN FazlaPlansizDk  > 0 THEN 'plansiz gun'
              WHEN FazlaIzinIptalDk> 0 THEN 'izin iptali gunu'
              ELSE 'normal gun' END;
-- Bulgu: izin iptali ve plansız günlerde FazlaCalismaDk=0 ve ham plan-dışı=0
--        (o günlerin fazlası ayrı kalemde). Normal günde ham > tahakkuk.
