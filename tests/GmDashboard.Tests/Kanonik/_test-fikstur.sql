-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : SORU-METNI-BASLIK (yalniz CanonicalQuery yardimci testlerinin fiksturu; gercek kanonik sorgu DEGIL)
   Ornek    : basliktaki ornek isaret gercek blok sayilmamali:
   -- blok: A  (basliktaki ornek)
*/

-- blok: A
SELECT 'govde-A' AS x;

-- blok: B  (orta blok)
SELECT 'govde-B' AS x;

-- blok: C
SELECT 'govde-C' AS x;

-- blok: D  (GO ve DECLARE ham doner)
DECLARE @n int = 1;
SELECT @n AS govde_d;
GO

-- blok: Z
SELECT 'govde-Z' AS son_satir;
