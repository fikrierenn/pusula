/* =============================================================================
   VARDİYA — DEVİR ALT-SORGUSUNDA DÖNEM SÜZGECİ YOKTU (V-20)
   DB: BkmPanel (DEV — BT-FIKRI\SQLEXPRESS).  Ölçüm tarihi: 19.09.2026
   Araç: sqlcli --profile panel

   SORU: `GetSummaryAsync` devir bakiyesini ayrı bir tablodan (`bkm.Vrd_Devir`)
         topluyor. Kapsam (şube) süzgeci 19.09'da eklendi. Peki DÖNEM?

   BULGU: Dönem süzgeci HİÇ YOKTU. Tablo dönem bazlı (PK Donem+SicilNo) ve sorgu
         kapsamdaki BÜTÜN dönemleri topluyordu. Dev veride tek dönem olduğu için
         22 testin hiçbiri göremiyordu — TEK NÜFUSLU EKSEN KAPIYI SINAMAZ.

   ⚠ BLOK 3 TABLOYA YAZMAZ: ikinci dönem `UNION ALL` ile SİMÜLE edilir. Ölçüm
     için gerçek veriye dokunmak gerekmiyordu; dokunulsaydı dondurulmuş bir
     kapanış dönemi riske girerdi (`erp-write-policy.md`).
============================================================================= */

/* --- BLOK 1: EKSEN NÜFUSU — neden hiçbir test göremedi --------------------
   Kesim de dönem de TEK. Bir eksende tek değer varken yanlış kod da doğru
   sayıyı verir; yeşil test burada bir şey kanıtlamaz. */
SELECT  Kaynak      = 'kesim',
        Deger       = CONVERT(varchar(30), KesimBas, 104) + ' → '
                    + CONVERT(varchar(30), KesimBit, 104),
        Satir       = COUNT(*),
        Sube        = COUNT(DISTINCT Sube)
FROM    bkm.Vrd_KisiGun
GROUP BY KesimBas, KesimBit
UNION ALL
SELECT  'devir dönemi', Donem, COUNT(*), COUNT(DISTINCT Sube)
FROM    bkm.Vrd_Devir
GROUP BY Donem;
/* ÖLÇÜLDÜ: kesim 31.08.2026 → 16.09.2026 (6.113 satır / 9 şube)
            devir dönemi 2026-08     (  186 satır / 8 şube)  — İKİSİ DE TEK. */


/* --- BLOK 2: SESSİZ KAYIP KONTROLÜ — NULL şube ---------------------------
   Kapsam süzgeci `Sube IN (...)` biçiminde. `Vrd_Devir.Sube` NULL tanımlı;
   NULL bir satır bu süzgeçten SESSİZCE düşerdi ve düştüğü hiçbir yerde
   yazmazdı. Bugün 0 — ama bu bir ÖLÇÜM, garanti değil, o yüzden değişmeze
   çevrildi (`vardiya-devir-sube-null-yok`). */
SELECT  DevirSubeNull    = SUM(CASE WHEN Sube IS NULL THEN 1 ELSE 0 END),
        DevirSubeNullDk  = SUM(CASE WHEN Sube IS NULL THEN EksikDk ELSE 0 END),
        DevirToplam      = COUNT(*),
        KisiGunSubeNull  = (SELECT SUM(CASE WHEN Sube IS NULL THEN 1 ELSE 0 END)
                            FROM bkm.Vrd_KisiGun)
FROM    bkm.Vrd_Devir;
/* ÖLÇÜLDÜ: 0 · 0 · 186 · 0 */


/* --- BLOK 3: KUSURUN KANITI — ikinci dönem SİMÜLE edilir ------------------
   `GENEL MÜDÜRLÜK` = en çok kişi-günü olan şube (müdür fikstürünün seçtiği).
   Üç satır: bugünkü durum · bugünkü KOD ikinci dönemle · DOĞRU kod. */
SELECT  Senaryo = 'bugün (tek dönem)',
        Eksik   = SUM(EksikDk),
        Fazla   = SUM(FazlaDk)
FROM    bkm.Vrd_Devir
WHERE   Sube = N'GENEL MÜDÜRLÜK'

UNION ALL
SELECT  'ikinci dönem — SÜZGEÇSİZ (19.09 öncesi kod)', SUM(EksikDk), SUM(FazlaDk)
FROM   (SELECT EksikDk, FazlaDk, Sube, Donem FROM bkm.Vrd_Devir
        UNION ALL SELECT 50000, 3000, N'GENEL MÜDÜRLÜK', '2026-09') s
WHERE   Sube = N'GENEL MÜDÜRLÜK'

UNION ALL
SELECT  'ikinci dönem — DÖNEM SÜZGEÇLİ (doğrusu)', SUM(EksikDk), SUM(FazlaDk)
FROM   (SELECT EksikDk, FazlaDk, Sube, Donem FROM bkm.Vrd_Devir
        UNION ALL SELECT 50000, 3000, N'GENEL MÜDÜRLÜK', '2026-09') s2
WHERE   Sube = N'GENEL MÜDÜRLÜK' AND Donem = '2026-08';
/* ÖLÇÜLDÜ:
     bugün (tek dönem) ........................  69.563 dk eksik ·   544 fazla
     ikinci dönem — SÜZGEÇSİZ ................. 119.563 dk eksik · 3.544 fazla
     ikinci dönem — DÖNEM SÜZGEÇLİ ............  69.563 dk eksik ·   544 fazla
   Yani süzgeçsiz hâlde BAŞKA BİR DÖNEMİN devri, seçili kesimin toplamına
   giriyordu. Rakam saçma değil MAKUL çıkıyordu — o yüzden kabul edilirdi. */


/* --- BLOK 4: KESİM ↔ DÖNEM EŞLEMESİ — n = 1, ÇIKARIM ---------------------
   Düzeltme bir eşleme SEÇMEK zorundaydı. Tek veri noktası üç kuralı da
   destekliyor; ayırt edilemiyor. Kod (b)'yi kullanıyor çünkü anlamı taşıyan
   tek kural o: devir, SAYILAN ayın öncesinde KAPANAN ayın bakiyesidir.
   ⚠ İKİNCİ GERÇEK KESİM YAZILINCA BU SORGU YENİDEN KOŞULACAK (TODO V-20). */
SELECT  KesimBas, KesimBit, SayimBas,
        Aday_a_KesimBasAyi        = CONVERT(char(7), KesimBas, 126),
        Aday_b_SayimBasBirOncesi  = CONVERT(char(7), DATEADD(month, -1, SayimBas), 126),
        Aday_c_KesimBitBirOncesi  = CONVERT(char(7), DATEADD(month, -1, KesimBit), 126),
        GercekDonem               = (SELECT MAX(Donem) FROM bkm.Vrd_Devir)
FROM    bkm.Vrd_KisiGun
GROUP BY KesimBas, KesimBit, SayimBas;
/* ÖLÇÜLDÜ: üç aday da '2026-08' → gerçek dönem '2026-08'. AYIRT EDİLEMİYOR.
   (a) yalnız KesimBas ayın SON GÜNÜ olduğu için tutuyor; sayım başıyla kesim
   başı aynı güne gelirse (a) kendi ayını gösterir ve YANLIŞ olur. */
