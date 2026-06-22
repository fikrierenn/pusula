/* B-110 — Tedarikçi/Yayınevi Performans Scorecard (sermaye verimliliği)
   DB: DerinSISBkm · Soru: hangi marka/yayınevinden sipariş kesmeli? (devir<1,5× = sermaye tuzağı)
   Bulgu (son 12 ay, 22.06.2026): Faber-Castell devir 0,46× (636K stok yavaş) · Yapı Kredi 1,28× · Bilgi Sarmal devir 9,7× ama iade %12,4 yüksek.
   Devir = son 12 ay satış adet / anlık stok adet. İade oranı = iade tutar / brüt satış.
   PERF dersi: satış agregatı + stok agregatı AYRI derived-table, mrkID'de JOIN.
   Satır-başı OUTER APPLY (stok korelasyonu) → 30s timeout. Ayrı GROUP BY + JOIN → ~17s.
   İç-operasyon + ev-markası hariç: mrkID 0=Markasız, 269=BKM Kitap, 2101=Sınav Okulları, 5972=Sınav Kıyafet, 10911=BKM-Mağaza. */

SELECT TOP 30 sv.Marka, sv.SatisAdet, sv.IadeAdet, sv.NetCiro, sv.SatisBrut, sv.IadeTutar,
    CAST(ISNULL(st.StokAdet, 0) AS int) AS StokAdet,
    CAST(CASE WHEN ISNULL(st.StokAdet,0) > 0 THEN sv.SatisAdet * 1.0 / st.StokAdet END AS decimal(6,2)) AS Devir,
    CAST(CASE WHEN sv.SatisBrut > 0 THEN sv.IadeTutar * 100.0 / sv.SatisBrut END AS decimal(5,2)) AS IadeYuzde
FROM (
    SELECT m.mrkID, m.mrkAd AS Marka,
        CAST(-SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehAdetN ELSE 0 END) AS int) AS SatisAdet,
        CAST(SUM(CASE WHEN a.ehTip IN (3,5,101) THEN a.ehAdetN ELSE 0 END) AS int) AS IadeAdet,
        SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehTutarN WHEN a.ehTip IN (3,5,101) THEN -a.ehTutarN ELSE 0 END) AS NetCiro,
        SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehTutarN ELSE 0 END) AS SatisBrut,
        SUM(CASE WHEN a.ehTip IN (3,5,101) THEN a.ehTutarN ELSE 0 END) AS IadeTutar
    FROM DerinSISBkm.dbo.irsHrk a WITH(NOLOCK)
    JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = a.ehstkID
    JOIN DerinSISBkm.dbo.urnMrk m WITH(NOLOCK) ON m.mrkID = u.urnMrkID
    WHERE a.ehTrhS >= DATEADD(year, -1, CAST(GETDATE() AS date))
      AND a.ehMekan IN (12,1,4478,4477)
      AND m.mrkID NOT IN (0, 269, 2101, 5972, 10911)
    GROUP BY m.mrkID, m.mrkAd
    HAVING -SUM(CASE WHEN a.ehTip IN (4,100) THEN a.ehAdetN ELSE 0 END) >= 50
) sv
LEFT JOIN (
    SELECT u2.urnMrkID, SUM(s.stok) AS StokAdet
    FROM DerinSISBkm.dbo.stokSonAltDepo_vw s WITH(NOLOCK)
    JOIN DerinSISBkm.dbo.urn u2 WITH(NOLOCK) ON u2.stkID = s.ehstkID
    WHERE s.ehAltDepo = 0 AND s.stok > 0 AND s.ehMekan IN (12,1,4478,4477)
    GROUP BY u2.urnMrkID
) st ON st.urnMrkID = sv.mrkID
ORDER BY sv.NetCiro DESC;
