-- =====================================================================
-- P2 — HAFTALIK KATEGORİ TREND (geçen hafta vs önceki hafta, mağaza kırılımlı)
-- Kaynak: dbo.irsHrk + bkm.urunbilgi.Kategori3 (stkID köprüsü — stkKod KULLANILMAZ)
-- Tarih: DİNAMİK — geçen Pzt-Paz penceresi (DATEDIFF WEEK epoch 1900-01-01 Pazartesi).
-- ehTip: 4/100 satış, 5/101 iade. Filtre: ehAltDepo=0, Kategori3<>'Genel', stkID 583160 hariç.
-- KDV HARİÇ (ehTutarN) — POS brief neti (KDV dahil) ile birebir kıyaslanamaz.
-- DOĞRULAMA (11.06.2026, hafta 01-07.06): KİTAP 4,96M / DİĞER 4,42M / toplam ~9,38M ✓
--   (brief KDV-dahil 10,14M ile oran tutarlı). MCP-safe özet aşağıda §B.
-- NOT: §A tam sorgu CTE'li = SSMS. MCP için §B.
-- =====================================================================

-- §A — SSMS TAM SORGU (ara toplamlı, Bugün/Dün yerine BuHafta/ÖncekiHafta)
-- Şablon: sorgular/01-ciro/2026-05-08-ciro-magaza-kategori-aratoplamli.sql
-- Aynı sorguyu kullan, sadece DECLARE bloğunu şununla değiştir:
DECLARE @BugunBaslangic date = DATEADD(WEEK, DATEDIFF(WEEK,0,GETDATE())-1, 0); -- geçen Pzt
DECLARE @BugunBitis     date = DATEADD(DAY, 7, @BugunBaslangic);               -- bu Pzt (exclusive)
DECLARE @DunBaslangic   date = DATEADD(DAY,-7, @BugunBaslangic);               -- önceki Pzt
DECLARE @DunBitis       date = @BugunBaslangic;
-- ("Bugün" = geçen hafta, "Dün" = önceki hafta olarak okunur.)

-- §B — MCP-SAFE HAFTALIK ÖZET (tek SELECT, CTE'siz; tarihleri elle ISO değil DMY literal yaz)
SELECT TOP 50 ISNULL(NULLIF(u.Kategori3,''),'(Tanımsız)') AS Kategori,
  CASE WHEN u.Kategori3 IN (N'Akademi',N'Çocuk Kitabı',N'Hazırlık Kitapları',N'Kitap')
       THEN N'KİTAP' ELSE N'DİĞER' END AS Grup,
  CAST(SUM(-h.ehAdetN) AS int) AS NetAd,
  CAST(SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE -h.ehTutarN END) AS decimal(18,0)) AS NetTL
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.urunbilgi u ON u.stkID = h.ehstkID
WHERE h.ehTrhS >= CONVERT(date,'01.06.2026',104) AND h.ehTrhS < CONVERT(date,'08.06.2026',104)
  AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo = 0
  AND ISNULL(NULLIF(u.Kategori3,''),'(Tanımsız)') <> 'Genel' AND h.ehstkID <> 583160
GROUP BY ISNULL(NULLIF(u.Kategori3,''),'(Tanımsız)'),
  CASE WHEN u.Kategori3 IN (N'Akademi',N'Çocuk Kitabı',N'Hazırlık Kitapları',N'Kitap')
       THEN N'KİTAP' ELSE N'DİĞER' END;
