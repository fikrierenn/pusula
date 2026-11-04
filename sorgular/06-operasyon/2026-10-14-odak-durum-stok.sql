-- ODAK durumu + tedarik süresi + ODAK depo stoğu, stkID bazında (salt-okuma). Köprü: kanonik barkod zinciri
-- (sorgular/2026-09-08-satis-analizi-excel-denetim.sql 12c — ProductCode stkID DEĞİL). @M/@R: stkID'ye göre bölme.
-- saleStatus: 1 Satışta (temin ediliyor) · 2 Tükendi · 3 Yeni baskı · 4 Liste dışı · 5 Yasaklı · 6 Eski baskı
SELECT b.urnBrkdStkID AS stk, MIN(d.leadTime) AS odak_temin_gun, MIN(d.saleStatus) AS odak_durum,
       MAX(ISNULL(s.StokMiktar, 0)) AS odak_stok
FROM BKMDATA.dbo.OdakUrunDurum d WITH (NOLOCK)
JOIN BKMDATA.ent.odak_urun_tam t WITH (NOLOCK) ON CAST(t.urun_id AS varchar(30)) COLLATE Turkish_CI_AS = d.ProductCode COLLATE Turkish_CI_AS
JOIN DerinSISBkm.dbo.urnBrkd b WITH (NOLOCK) ON b.urnBarkod COLLATE Turkish_CI_AS = t.barkod COLLATE Turkish_CI_AS AND b.urnBrkdOnce = 0
LEFT JOIN DerinSISBkm.ent.odak_depo_Stok s WITH (NOLOCK) ON s.stkID = b.urnBrkdStkID
WHERE b.urnBrkdStkID % CAST(@M AS int) = CAST(@R AS int)
GROUP BY b.urnBrkdStkID
