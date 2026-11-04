-- Fazla + hareketsiz stok — mekan başına, ürün başına (salt-okuma). 2026-10-14, sahip isteği.
-- @MK mekan (1 FSM · 4477 Özlüce · 4478 İst.Yolu · 12 Merkez Depo), @M/@R ürün koduna göre bölme (satır sınırı),
-- @A = son 52 haftanın başı, @P = önceki 52 haftanın başı (ISO yyyy-mm-dd).
-- stok: stokSonAltDepo_vw (anlık, tüm alt depolar toplamı) · talep: satış − iade (1,4,100 − 3,5,101); depoda + sevk (11 Depo Depo, 13 Depo Mağaza; çıkış bacağı)
-- gerçek hareket: defter düzeltmeleri HARİÇ (16 Stok EKLE, 17 Merkezi Düzeltme, 88/89 Diğer Giriş/Çıkış, 90 Ürün SAY, 97 Devir, 99 Sayım)
WITH s AS (
  SELECT v.ehstkID stk, SUM(v.stok) stok
  FROM stokSonAltDepo_vw v WITH (NOLOCK)
  WHERE v.ehMekan = CAST(@MK AS int) AND v.ehstkID % CAST(@M AS int) = CAST(@R AS int)
  GROUP BY v.ehstkID HAVING SUM(v.stok) > 0
), h AS (
  SELECT h.ehstkID stk,
    MAX(h.ehTrhS) son_hareket,
    MAX(CASE WHEN h.ehTip NOT IN (16,17,88,89,90,97,99) THEN h.ehTrhS END) son_gercek,
    MAX(CASE WHEN h.ehTip IN (1,4,100) THEN h.ehTrhS END) son_satis,
    MAX(CASE WHEN h.ehAdetN > 0 AND h.ehTip IN (0,8,9,10,11,13) THEN h.ehTrhS END) son_giris,
    -SUM(CASE WHEN h.ehTrhS >= CONVERT(date,@A,23) AND h.ehTip IN (1,3,4,5,100,101) THEN h.ehAdetN ELSE 0 END) satis52,
    -SUM(CASE WHEN h.ehTrhS >= CONVERT(date,@P,23) AND h.ehTrhS < CONVERT(date,@A,23) AND h.ehTip IN (1,3,4,5,100,101) THEN h.ehAdetN ELSE 0 END) satis52p,
    -SUM(CASE WHEN h.ehTrhS >= CONVERT(date,@A,23) AND h.ehTip IN (11,13) AND h.ehAdetN < 0 THEN h.ehAdetN ELSE 0 END) sevk52,
    -SUM(CASE WHEN h.ehTrhS >= CONVERT(date,@P,23) AND h.ehTrhS < CONVERT(date,@A,23) AND h.ehTip IN (11,13) AND h.ehAdetN < 0 THEN h.ehAdetN ELSE 0 END) sevk52p
  FROM dbo.irsHrk h WITH (NOLOCK)
  WHERE h.ehMekan = CAST(@MK AS int) AND h.ehstkID % CAST(@M AS int) = CAST(@R AS int)
    AND h.ehstkID IN (SELECT stk FROM s)
  GROUP BY h.ehstkID
)
SELECT s.stk, CAST(s.stok AS decimal(18,3)) stok,
  CONVERT(char(10), h.son_hareket, 23) son_hareket, CONVERT(char(10), h.son_gercek, 23) son_gercek,
  CONVERT(char(10), h.son_satis, 23) son_satis, CONVERT(char(10), h.son_giris, 23) son_giris,
  CAST(ISNULL(h.satis52,0) AS decimal(18,3)) satis52, CAST(ISNULL(h.satis52p,0) AS decimal(18,3)) satis52p,
  CAST(ISNULL(h.sevk52,0) AS decimal(18,3)) sevk52, CAST(ISNULL(h.sevk52p,0) AS decimal(18,3)) sevk52p
FROM s LEFT JOIN h ON h.stk = s.stk
