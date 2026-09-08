/*
  Soru: "Okul acilisi bu sene 1 hafta kaydi, ciro tahmini yapamiyorum."
  Amac: sezon egrisini okul acilisina hizalayip (a) takvim-ayi carpitmasini olcmek,
        (b) Eyl-Ara 2026 tahminini uretmek.
  DB: DerinSISBkm. Kaynak eTip 100 (POS gunluk ozet) — POS gecisinden bagimsiz, 3 magaza.
  Olcum tarihi: 08.09.2026 · son TAM gun 07.09.2026 (bugunun eTip 100 belgesi gun ici yeniden yazilir).

  OKUL ACILISI (T gunu):
    2024-2025 -> 09.09.2024  · 2025-2026 -> 08.09.2025 · 2026-2027 -> 14.09.2026 (6 GUN GEC)
    2024 tarihi VARSAYILMADI, OLCULDU: 2025 sezon SEKLINE en iyi oturan pazartesi arandi
    (T-56..T+28 normalize edilmis gunluk egri, L1 sapma) -> 09.09 = 0,1027 · 02.09 = 0,2051 ·
    16.09 = 0,2695. MEB takvimiyle birebir.

  BULGU 1 — TAKVIM YANILGISI (Agustos 2026 "kotu" gorunuyor, degil):
    Perakende: takvim Agu 56,94M -> 72,92M (+%28,1) | okul-hizali (T-45..T-14) 43,54 -> 74,49 (+%71,1)
    Sinav    : takvim Agu 129,94M -> 99,19M (-%23,7) | okul-hizali 52,47 -> 99,23 (+%89,1)

  BULGU 2 — AY KOPRUSU (2025 sezonu 2026 takvimine tasinsa, tek basina kaymanin etkisi):
    Perakende Agu -14,3M / Eyl +3,4M / Eki +6,1M · Sinav Agu -77,5M / Eyl +74,8M / Eki +2,6M
    => Agustos'tan ~92M TL Eylul-Ekim'e KAYDI. Takvim-ayi YoY bu yuzden Agu'da kotu, Eyl'de sisik.

  BULGU 3 — TAHMIN (net KDV-haric, 3 magaza POS, e-ticaret HARIC):
    Yontem: 2026(o) = 2025(o) x k · o = okul acilisina gun ofseti · k son hizali gunlerden.
    k perakende 1,37 / 1,50 / 1,62 · k Sinav 0,93 / 1,11 / 1,29 (dusuk/orta/yuksek)
    Eyl 418,7 / 464,1 / 507,4M (2025: 313,0M) · Eki 106,3 / 117,1 / 127,5M (71,4M)
    Kas 74,1 / 81,3 / 88,2M (54,6M) · Ara 79,0 / 86,7 / 94,0M (60,6M)
    Eyl-Ara toplam 678,0 / 749,1 / 817,2M (2025: 499,7M · orta +%49,9)
  ⚠ Buyume NOMINAL. Fisher fiyat endeksi Tem-Agu'da +%19,8 -> reel hacim buyumesi ~+%21-25.
  ⚠ Son 12 hizali gunde perakende buyumesi %65-90'dan %36-50'ye indi. Ya buyume yavasliyor
    ya dalga acilisa daha da yaklasti (o zaman T-6..T+3 fazla gelir). ACIK SORU — 14.09 sonrasi olculur.
  ⚠ Sinav lumpy (kurumsal toplu siparis) — k bandi genis, tek gun tahmini yapilmaz.

  Dogrulama: bu sorgunun 2025 aylik toplamlari onceki olcumlerle birebir tutuyor
    (Eyl-2025 313,0M · Agu-2025 186,9M).
*/

-- ============ 1) GUNLUK SERI (analizin ham girdisi) ============
-- Cikti Python'da hizalanir: ofset = DATEDIFF(DAY, o_yilin_okul_acilisi, gun)
SELECT CONVERT(varchar(8), bs.eTarihS, 112) AS gun,
       CASE WHEN COALESCE(kat.Kategori3,'x') IN ('Sınav Okulları','Sınav Kıyafet')
            THEN 1 ELSE 0 END                                   AS sinav,
       SUM(CAST(dt.ehTutar - dt.ehIndirim AS float))            AS net_kdvharic
FROM dbo.irs bs WITH(NOLOCK)
INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
WHERE bs.eTip = 100 AND bs.eMekan IN (1, 4477, 4478)
  AND bs.eTarihS >= '20240601' AND bs.eTarihS < '20260908'
GROUP BY CONVERT(varchar(8), bs.eTarihS, 112),
       CASE WHEN COALESCE(kat.Kategori3,'x') IN ('Sınav Okulları','Sınav Kıyafet') THEN 1 ELSE 0 END;
-- Mutabakat: Tem+Agu perakende 2025 86,98M -> 2026 125,34M (tek sorguyla teyit edildi).

-- ============ 2) TAKVIM vs OKUL-HIZALI ayni pencerede (BULGU 1'in kaniti) ============
-- T-45..T-14 = "Agustos karsiligi" 32 gunluk hizali pencere.
SELECT CASE WHEN COALESCE(kat.Kategori3,'x') IN ('Sınav Okulları','Sınav Kıyafet')
            THEN 'Sinav' ELSE 'Perakende' END AS kanal,
       YEAR(bs.eTarihS) AS yil,
       SUM(CASE WHEN bs.eTarihS >= CASE YEAR(bs.eTarihS) WHEN 2025 THEN '20250801' ELSE '20260801' END
             AND bs.eTarihS <  CASE YEAR(bs.eTarihS) WHEN 2025 THEN '20250901' ELSE '20260901' END
                THEN CAST(dt.ehTutar - dt.ehIndirim AS float) ELSE 0 END)      AS takvim_agustos,
       SUM(CASE WHEN DATEDIFF(DAY, CASE YEAR(bs.eTarihS) WHEN 2025 THEN '20250908' ELSE '20260914' END,
                              bs.eTarihS) BETWEEN -45 AND -14
                THEN CAST(dt.ehTutar - dt.ehIndirim AS float) ELSE 0 END)      AS okul_hizali_T45_T14
FROM dbo.irs bs WITH(NOLOCK)
INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
WHERE bs.eTip = 100 AND bs.eMekan IN (1, 4477, 4478)
  AND ((bs.eTarihS >= '20250701' AND bs.eTarihS < '20250908')
    OR (bs.eTarihS >= '20260707' AND bs.eTarihS < '20260908'))
GROUP BY CASE WHEN COALESCE(kat.Kategori3,'x') IN ('Sınav Okulları','Sınav Kıyafet')
              THEN 'Sinav' ELSE 'Perakende' END, YEAR(bs.eTarihS)
ORDER BY 1, 2;

-- ============ 3) HAFTALIK OKUL-HIZALI SERI (sunuma giden tablo) ============
SELECT CASE WHEN COALESCE(kat.Kategori3,'x') IN ('Sınav Okulları','Sınav Kıyafet')
            THEN 'Sinav' ELSE 'Perakende' END AS kanal,
       YEAR(bs.eTarihS) AS yil,
       -- hafta etiketi: T-1 = acilistan onceki 7 gun, T+0 = acilis haftasi
       CASE WHEN DATEDIFF(DAY, CASE YEAR(bs.eTarihS) WHEN 2024 THEN '20240909'
                                WHEN 2025 THEN '20250908' ELSE '20260914' END, bs.eTarihS) >= 0
            THEN  DATEDIFF(DAY, CASE YEAR(bs.eTarihS) WHEN 2024 THEN '20240909'
                                WHEN 2025 THEN '20250908' ELSE '20260914' END, bs.eTarihS) / 7
            ELSE -((-DATEDIFF(DAY, CASE YEAR(bs.eTarihS) WHEN 2024 THEN '20240909'
                                WHEN 2025 THEN '20250908' ELSE '20260914' END, bs.eTarihS) + 6) / 7)
       END AS hafta_ofset,
       SUM(CAST(dt.ehTutar - dt.ehIndirim AS float)) AS net_kdvharic
FROM dbo.irs bs WITH(NOLOCK)
INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
WHERE bs.eTip = 100 AND bs.eMekan IN (1, 4477, 4478)
  AND bs.eTarihS >= '20240601' AND bs.eTarihS < '20260908'
GROUP BY CASE WHEN COALESCE(kat.Kategori3,'x') IN ('Sınav Okulları','Sınav Kıyafet')
              THEN 'Sinav' ELSE 'Perakende' END, YEAR(bs.eTarihS),
       CASE WHEN DATEDIFF(DAY, CASE YEAR(bs.eTarihS) WHEN 2024 THEN '20240909'
                                WHEN 2025 THEN '20250908' ELSE '20260914' END, bs.eTarihS) >= 0
            THEN  DATEDIFF(DAY, CASE YEAR(bs.eTarihS) WHEN 2024 THEN '20240909'
                                WHEN 2025 THEN '20250908' ELSE '20260914' END, bs.eTarihS) / 7
            ELSE -((-DATEDIFF(DAY, CASE YEAR(bs.eTarihS) WHEN 2024 THEN '20240909'
                                WHEN 2025 THEN '20250908' ELSE '20260914' END, bs.eTarihS) + 6) / 7)
       END
ORDER BY 1, 3, 2;
-- Perakende hizali haftalik YoY 2026/2025: T-9 +%76 · T-8 +%69 · T-7 +%81 · T-6 +%66 ·
--   T-5 +%75 · T-4 +%70 · T-3 +%71 · T-2 +%38  (son hafta yavaslama -> ACIK SORU, yukari bak)

-- ============ 4) SUBE BAZLI GUNLUK SERI (Eylul-2026 sube tahmininin girdisi) ============
-- eMekan: 1=FSM · 4477=Ozluce · 4478=Ist.Yolu (DerinSIS mekan; EncoreMerkez StoresId ILE AYNI DEGIL).
-- Sinav Okullari operasyonu Agu-2024'te FSM'den Ist.Yolu'na tasindi -> FSM/Ozluce Sinav cirosu 0.
SELECT CONVERT(varchar(8), bs.eTarihS, 112) AS gun, bs.eMekan AS mekan,
       CASE WHEN COALESCE(kat.Kategori3,'x') IN ('Sınav Okulları','Sınav Kıyafet')
            THEN 1 ELSE 0 END                                   AS sinav,
       SUM(CAST(dt.ehTutar - dt.ehIndirim AS float))            AS net_kdvharic
FROM dbo.irs bs WITH(NOLOCK)
INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
LEFT JOIN bkm.UrunBilgi kat WITH(NOLOCK) ON kat.stkID = dt.ehStkID
WHERE bs.eTip = 100 AND bs.eMekan IN (1, 4477, 4478)
  AND bs.eTarihS >= '20240601' AND bs.eTarihS < '20260908'
GROUP BY CONVERT(varchar(8), bs.eTarihS, 112), bs.eMekan,
       CASE WHEN COALESCE(kat.Kategori3,'x') IN ('Sınav Okulları','Sınav Kıyafet') THEN 1 ELSE 0 END;

/*  EYLUL 2026 TAHMINI · SUBE BAZLI (net KDV-haric, M TL, e-ticaret HARIC)
    01-07 Eyl GERCEK + 08-30 Eyl = 2025'in okul-hizali ayni gunleri x k (k sube x kanal bazinda ayri)

    sube / kanal          1-7 ger   dusuk    ORTA  yuksek   Eyl-25   YoY(orta)
    FSM  · Perakende          5,8    48,0    49,3    50,8     34,5     +%43,0
    Ozluce · Perakende       10,5    65,8    67,6    68,0     44,3     +%52,6
    Ist.Yolu · Perakende     15,6    61,8    69,0    78,3     43,1     +%60,1
    Ist.Yolu · Sinav         83,8   247,7   279,7   310,3    191,2     +%46,3
    ----------------------------------------------------------------------
    FSM TOPLAM                5,8    48,0    49,3    50,8     34,5     +%43,0
    OZLUCE TOPLAM            10,5    65,8    67,6    68,0     44,3     +%52,6
    IST.YOLU TOPLAM          99,4   309,5   348,7   388,6    234,3     +%48,9
    PERAKENDE (3 magaza)     31,8   175,6   186,0   197,1    121,9     +%52,5
    GENEL TOPLAM            115,7   423,2   465,6   507,4    313,0     +%48,7

    Kalan 23 gun (08-30 Eyl) gerekli gunluk ort (ORTA): FSM 1,89M · Ozluce 2,49M · Ist.Yolu 10,84M
      (01-07 gerceklesen: FSM 0,83M · Ozluce 1,49M · Ist.Yolu 14,20M — Ist.Yolu'nun 1-7 ortalamasi
       yuksek cunku Sinav toplu siparisleri o pencereye dustu.)

    ⚠ Bant genisligi kaynagi Ist.Yolu: perakende k 1,24-1,69, Sinav k 0,93-1,29 (lumpy kurumsal).
      FSM/Ozluce dar (k 1,50-1,60) -> o iki subenin tahmini daha guvenilir.
    ⚠ Sube x kanal ayri k ile toplam 465,6M; tek-carpan (kanal duzeyi) hesapta 464,1M — %0,3 fark,
      kirilim inceldikce beklenen sapma.
*/

/*  ============ 5) ACILIS ONCESI / SONRASI — SUBE BAZLI (blok 4 serisinden turetildi) ============
    Ofset >= 0 = acilis gunu ve sonrasi · ofset < 0 = oncesi. Sezon penceresi T-63..T+52.

    A) SEZON PAYI — iki yilda da AYNI (egri sekli sabit; hizalamanin dogrulugunun kaniti)
       sube / kanal          2024 once / sonra  %once  |  2025 once / sonra  %once
       FSM · Perakende          16,2 /  30,6M   %34,6  |     25,9 /  49,3M   %34,5
       Ozluce · Perakende       28,8 /  41,6M   %40,9  |     42,0 /  61,6M   %40,5
       Ist.Yolu · Perakende     30,1 /  23,7M   %56,0  |     47,5 /  41,7M   %53,3
       Ist.Yolu · Sinav        183,3 /  48,9M   %78,9  |    257,9 /  68,2M   %79,1
       => FSM/Ozluce SONRASI agirlikli (acilis sonrasi eksik-tamamlama) — kaymadan EN COK etkilenen.
          Ist.Yolu perakende ONCESI agirlikli · Sinav %79 oncesi (kurumsal on siparis).

    B) EYLUL KIRILIMI (M TL) — Eyl-2025 once/sonra/top | Eyl-2026 tahmin once/sonra/top | k
       FSM · Perakende          6,5 /  28,0 /  34,5  |  14,8 /  34,5 /  49,3  | 1,54
       Ozluce · Perakende      10,7 /  33,6 /  44,3  |  25,7 /  41,9 /  67,6  | 1,56
       Ist.Yolu · Perakende    17,6 /  25,5 /  43,1  |  38,6 /  30,4 /  69,0  | 1,44
       Ist.Yolu · Sinav       127,5 /  63,6 / 191,2  | 212,0 /  67,7 / 279,7  | 1,11
       TOPLAM                 162,4 / 150,7 / 313,0  | 291,1 / 174,5 / 465,6  |
       (Eylul 2025'te ay icinde 7 gun oncesi + 23 gun sonrasi · 2026'da 13 + 17.)

    C) EYLUL'DEN EKIM'E TASINAN KUYRUK (T+17..T+22 = 2025'in 25-30 Eylul'u)
       FSM 5,6 -> 8,7M · Ozluce 6,8 -> 10,6M · Ist.Yolu perakende 4,3 -> 6,2M · Sinav 2,8 -> 3,1M
       TOPLAM 19,5M (2025 fiyati) -> 28,6M (2026 carpaniyla). Ekim'deki +%64 YoY'un ana sebebi budur.

    D) EYLUL+EKIM BIRLIKTE (kayma notrlenir) — ORTA senaryo
       FSM      56,2 -> 86,6M  (+%54,0)  |  yalniz Eylul +%43,0  -> 11,0 puan fark
       Ozluce   72,9 -> 115,7M (+%58,6)  |  yalniz Eylul +%52,6  ->  6,0 puan fark
       Ist.Yolu 255,3 -> 382,6M (+%49,9) |  yalniz Eylul +%48,9  ->  1,0 puan fark
       TOPLAM   384,4 -> 584,9M (+%52,1) |  yalniz Eylul +%48,7  ->  3,4 puan fark
       => Sube kiyasi YALNIZ EYLUL uzerinden yapilirsa FSM haksiz yere en kotu gorunur.
          Dogru cerceve: Eylul+Ekim birlikte, ya da okul-hizali pencere.
*/

/*  ============ 6) DUZELTME: kaymanin NET etkisi ve "Ekim kuyrugu" ============
    ⚠ Blok 5-C'deki "Eylul'den Ekim'e 28,6M tasindi" rakami BRUT'tu (6 hizali gunun tam degeri)
      ve YANILTICIYDI: Eylul o 6 gunu kaybederken BASINDAN 6 gun KAZANIYOR. Net transfer bu degil.

    TEMIZ KARSI-OLGU (tamamen sentetik: ayni 2025 egrisi x ayni k, tek fark acilis 14.09 vs 08.09):
       sube / kanal          Eyl 14.09 / 08.09   fark  |  Eki 14.09 / 08.09   fark
       FSM · Perakende         49,5 /  53,2M   -3,7M   |   37,3 / 33,6M    +3,7M
       Ozluce · Perakende      68,0 /  69,3M   -1,3M   |   48,1 / 44,7M    +3,3M
       Ist.Yolu · Perakende    71,5 /  62,0M   +9,5M   |   26,0 / 23,7M    +2,3M
       Ist.Yolu · Sinav       296,1 / 212,8M  +83,3M   |    7,9 /  5,1M    +2,9M
       TOPLAM                 485,0 / 397,3M  +87,7M   |  119,3 /107,1M   +12,2M

    DOGRU OKUMA: kayma parayi EYLUL'den Ekim'e degil, AGUSTOS'tan EYLUL'e tasiyor (+87,7M).
      Ekim yalnizca +12,2M aliyor. Ekim'deki +%67 YoY'un ~%26'si kayma, gerisi GERCEK buyume.
    ⚠ FSM/Ozluce Eylul'u kaymadan NEGATIF etkileniyor (-3,7M / -1,3M) cunku cirolari
      acilis-SONRASI agirlikli; kuyruklari Ekim'e kaciyor. Ist.Yolu tersine kazaniyor.

    KUYRUK NE KADARI DALGA? T+17..T+22 gunluk ort / Kasim tabani (dalga-disi normal is):
      FSM 0,94 / 0,55 = x1,71 · Ozluce 1,13 / 0,79 = x1,43 · Ist.Yolu 0,72 / 0,45 = x1,60
      => kuyrugun ~%60'i NORMAL IS (takvimde kalir, kaymaz), ~%40'i dalga artigi.

    ============ 7) SINAV — KOMPLE AYRI DEGERLENDIRME ============
    Sinav ayri bir is kolu: kurumsal/toplu, yalniz Ist.Yolu (Agu-2024'te FSM'den tasindi),
    yilin %97'si Agu+Eyl'de. Perakende ile ayni tabloda toplanmasi sube kiyasini bozar.

    A) MEVSIMSELLIK: zirve T-2 (2024 07.09 18,3M · 2025 06.09 30,0M) — acilistan ONCE.
       Sezonun %50'si T-5/T-6'da, %90'i T+4/T+5'te BITIYOR. Taban 0,04M/gun (ihmal edilebilir)
       => SINAV SAF DALGA, KUYRUKSUZ. Ekim/Eylul orani: 2024 %3,1 · 2025 %2,4.
       Kayma sonrasi bile Ekim'e cikmiyor (+2,9M).
    B) SEZON TAHMINI (pay yontemi, T-7 kesimi):
       2024 sezon 232,2M (%48,0'i T-7'de tamam) · 2025 326,1M (%43,8) · 2026 T-63..T-7 183,9M
       -> 2026 sezon 383,3 .. 419,8M (orta 400,8M) · 2025'e gore +%22,9
       Eylul-2026 tek basina: 247,7 / 279,7 / 310,3M (Eyl-2025 191,2M)
    C) "SINAV KUCULUYOR" IDDIASI ARTEFAKT:
       Oca-Agu takvim 134,9M -> 104,6M = -%22,5  |  okul-hizali T-63..T-7 +%28,7
       Agustos'un Sinav cirosunun buyuk kismi 2026'da Eylul'e kaydi.
    D) RISK: Sinav lumpy. Son TAM hizali hafta (T-2) YoY -%5 geldi (81,2 vs 85,3M) —
       sezon basi +%1121/+%126 iken. Ya on-siparis erken alindi ya talep zayifliyor.
       k bandi 0,93-1,29 bu yuzden genis; Sinav'da gun/hafta bazli tahmin YAPILMAZ.
*/

/*  ============ 8) HACIM AYRISTIRMASI: adet · fis · sepet · kategori · fiyat endeksi ============
    Pencere A (adet/kategori/fiyat): okul-hizali T-63..T-7 -> 2025 07.07-01.09 · 2026 13.07-07.09 (56 gun)
    Pencere B (fis/sepet):           okul-hizali T-38..T-7 -> 2025 01.08-01.09 · 2026 07.08-07.09 (32 gun)
      ⚠ Pencere B AYRI cunku Pencere A'nin baslangici (07.07.2025) POS GECISININ ICINE dusuyor
        (Ist.Yolu 11.07 · Ozluce 21.07 · FSM 23.07.2025). Ilk olcum bu yuzden fis +%55,7 verdi;
        gecis-disi pencerede gercek +%21,9. pos_sistem_gecisi_2025 tuzagi CANLI YAKALANDI.

    A) ADET vs CIRO (DerinSIS eTip 100, Pencere A)
       FSM      adet 187.878 -> 238.140 (+%26,8) · ciro +%59,7 · cesit 30.323 -> 33.008
       Ozluce   adet 267.068 -> 350.421 (+%31,2) · ciro +%57,2 · cesit 40.088 -> 42.311
       Ist.Yolu adet 244.058 -> 329.206 (+%34,9) · ciro +%68,8 · cesit 29.184 -> 36.132
       TOPLAM   adet 699.004 -> 917.768 (+%31,3) · ciro +%62,2 · birim deger +%23,5
       Sinav    adet  31.537 ->  32.573 (+%3,3)  · ciro +%28,7 -> buyume TAMAMEN fiyat/urun-degeri

    B) FIS · SEPET · FIS BASINA ADET (EncoreMerkez, Pencere B)
       FSM      fis 24.912 -> 29.779 (+%19,5) · sepet 512 -> 678 (+%32,6) · fis/adet 4,59 -> 5,16 (+%12,6)
       Ozluce   fis 31.407 -> 36.781 (+%17,1) · sepet 679 -> 891 (+%31,3) · fis/adet 5,70 -> 6,30 (+%10,7)
       Ist.Yolu fis 18.666 -> 24.840 (+%33,1) · sepet 709 -> 898 (+%26,8) · fis/adet 10,27 -> 9,91 (-%3,5)
       TOPLAM   fis 74.985 -> 91.400 (+%21,9) · sepet 631 -> 824 (+%30,6) · fis/adet 6,46 -> 6,91 (+%6,9)
       Sinav    belge 3.801 -> 3.802 (+%0,0) · sepet 45.234 -> 59.828 (+%32,3)
         => Sinav'da MUSTERI SAYISI SABIT, buyume tamamen sepet buyuklugunden.

    C) KATEGORI (Pencere A, perakende)      net %   adet %  birim %  pay26
       Kirtasiye                   25,1 -> 40,9M  +%63,1  +%29,4  +%26,1  %30,1
       Egitim-Sinavlara Hazirlik   16,8 -> 30,8M  +%82,8  +%60,3  +%14,0  %22,6   <- EN HIZLI (adet bazli)
       Edebiyat Kitaplari          11,8 -> 19,9M  +%68,8  +%30,8  +%29,0  %14,6
       Hobi ve Oyuncak              9,9 -> 14,3M  +%45,0  +%54,6   -%6,2  %10,5   <- tek FIYATI DUSEN
       Cocuk Kitaplari               8,4 -> 12,5M  +%48,3  +%14,2  +%29,9   %9,2   <- adet zayif
       Hediyelik                    0,9 ->  2,4M +%156,7  +%67,7  +%53,1   %1,7
       Egitim ve Okula Yardimci     1,0 ->  0,9M   -%5,8  -%25,7  +%26,7   %0,7   <- TEK KUCULEN
       ⚠ 'Yabanci Dilde Kitaplar' +%458 net / +%12 adet -> birim +%398: mix/az-sayida-yuksek-tutar
         supheli, teyit edilmeden yorumlanmaz (%1,1 pay).

    D) FIYAT/HACIM (matched-model, ortak urun · Pencere A · perakende)
       Ortak urun 32.574 · kapsam 2025 %75,0 / 2026 %54,2
       Laspeyres +%19,9 · Paasche +%20,4 · FISHER +%20,1
       Nominal ciro +%62,2 -> REEL hacim +%35,0 (adet +%31,3 ile tutarli; fark = urun karisimi)
       ✔ Capraz teyit: 02.09 olcumu Tem-Agu icin Fisher +%19,8 demisti — bagimsiz pencerede +%20,1.

    ⚠⚠ IKI CELISKI — KULLANILMADI, RAPOR EDILDI:
    1) KARTLI MUSTERI SAYISI KIRIK. Kartli fis payi 2025 %0,3-1,4 -> 2026 %77,4-81,9;
       tekil kartli FSM 69 -> 17.999. Bu musteri buyumesi DEGIL, sadakat-karti yakalamanin
       2025'te heniz calismamasi (POS gecisi sonrasi devreye alindi). YoY musteri sayisi
       BU VERIDEN OLCULEMEZ. Kartli analiz icin taban 2026 olmali.
    2) IST.YOLU'NDA PERAKENDE/SINAV AYRIMI IKI KAYNAKTA UYUSMUYOR.
       Perakende net 2025: Encore 13,23M vs DerinSIS 25,71M (-%48,6) · 2026 22,31 vs 41,41 (-%46,1).
       Sebep: Encore ayraci DocumentsTypeId=8 (BELGE tipi), DerinSIS ayraci Kategori3 (URUN tipi) —
       Sinav faturasindaki kitap/kirtasiye Encore'da Sinav, DerinSIS'te perakende sayiliyor.
       Ustelik Ist.Yolu TOPLAMI da tutmuyor (185,2 vs 168,1M) -> ek fark var, kok sebep ACIK.
       FSM/Ozluce %0,4-1,8 icinde tutuyor. Ist.Yolu kanal-kirilimli fis/sepet metrikleri
       BU AYRIM COZULENE KADAR GUVENILMEZ. (Yeni TODO.)
*/

/*  ============ 9) B-162 ÇÖZÜLDÜ — İst.Yolu ayrımının KÖK SEBEBİ (2026-09-08) ============
    İKİ AYRI SEBEP vardı; ikisi de ölçüldü ve mutabakat sağlandı.

    ── SEBEP 1: eTip 4 "Mağaza Satış" — eTip 100 DIŞINDA bir satış kanalı ────────────────
    İst.Yolu'nda eTip 4 net: 2025 20,18M · 2026 29,79M (536/638 belge). FSM 0,26/0,53M,
    Özlüce 0,28/0,62M — yani PRATİKTE SADECE İst.Yolu. İçeriğinin %86-89'u Sınav kategorisi.
    eTip 100 (POS Satış) günlük ÖZET belgedir (ayda 32 belge); eTip 4 ise BELGE BAŞINA kesilen
    kurumsal satış — Sınav Okulları toplu faturaları buradan akıyor.

    MUTABAKAT FORMÜLÜ (doğrulandı):  eTip 100 − 101 + 4 − 5   ≡  EncoreMerkez toplam
       2025: FSM 12,89 vs 12,74 (+%1,15) · Özlüce 21,37 vs 21,32 (+%0,24) · İst.Yolu 185,31 vs 185,16 (+%0,08)
       2026: FSM 20,46 vs 20,20 (+%1,28) · Özlüce 32,85 vs 32,77 (+%0,26) · İst.Yolu 250,66 vs 249,78 (+%0,35)
       (Yalnız eTip 100 ile İst.Yolu −%10,24 sapıyordu.)

    ⚠⚠ ETKİ: Bu dosyadaki BLOK 1-8'in tamamı eTip 100 TEK BAŞINA kullanıyor
       -> İst.Yolu toplamı ayda ~28-30M EKSİK. FSM/Özlüce etkilenmiyor (%1 içinde).

    ── SEBEP 2: BELGE tipi ≠ ÜRÜN kategorisi (kanal ayracı çatallanması) ─────────────────
    EncoreMerkez İst.Yolu çapraz tablosu (aynı pencere, SalesProducts kalem bazlı):
                                  2025          2026
       DocType8  × ürün_Sınav     156,76M      205,64M
       DocType8  × ürün_perakende  15,17M       21,83M   <- Sınav FATURASINDA satılan kitap/kırtasiye
       DocDiğer  × ürün_Sınav       1,26M        0,19M   <- perakende fişinde satılan Sınav ürünü
       DocDiğer  × ürün_perakende  ~11,5M       22,12M
    Net bucket farkı = 21,83 − 0,19 = 21,64M (2026) · 13,92M (2025) — ölçülen boşlukla birebir.

    ── KANONİK KURAL ────────────────────────────────────────────────────────────────────
    • KANAL (raf/walk-in vs kurumsal) sorusu  -> BELGE bazlı: EncoreMerkez DocumentsTypeId=8.
      DerinSIS'ten belge-bazlı ayrım YAPILAMAZ (eTip 100 günlük özet). Encore Ağu-2025 sonrası.
    • ÜRÜN/KATEGORİ sorusu -> ÜRÜN bazlı: bkm.UrunBilgi.Kategori3.
    • TOPLAM şube cirosu (DerinSIS'ten) -> eTip 100 − 101 + 4 − 5. ASLA yalnız 100.
    • İkisi KARIŞTIRILMAZ; aynı tabloda yan yana konmaz.

    ── DÜZELTİLMİŞ TAHMİN (belge bazlı, EncoreMerkez, net KDV-hariç, M TL) ───────────────
    EYLÜL 2026   düşük / ORTA / yüksek   (2025)     YoY
       FSM · Perakende        47,9 /  49,2 /  49,7   ( 33,9)  +%45,2
       Özlüce · Perakende     65,9 /  66,0 /  67,4   ( 43,7)  +%51,0
       İst.Yolu · Perakende   42,4 /  42,7 /  43,1   ( 26,0)  +%64,3   <- ürün-bazlıda 69,0M görünüyordu
       İst.Yolu · Sınav      319,0 / 357,8 / 397,4   (238,6)  +%49,9
       TOPLAM                475,2 / 515,7 / 557,5   (342,2)  +%50,7   <- eski (eksik) tahmin 465,6M
    EKİM 2026
       FSM · Perakende        36,1 /  37,1 /  37,6   ( 21,3)  +%74,0
       Özlüce · Perakende     46,6 /  46,6 /  47,8   ( 28,2)  +%65,1
       İst.Yolu · Perakende   31,0 /  31,2 /  31,5   ( 16,8)  +%85,4
       İst.Yolu · Sınav        7,0 /   8,3 /   9,6   (  4,2)  +%99,1
       TOPLAM                120,6 / 123,3 / 126,5   ( 70,6)  +%74,6
    Not: Ekim'de iki taban birbirine yakınsıyor (İst.Yolu perakende Eki-2025 belge 16,8 vs ürün 16,5M)
      çünkü Sınav sezonu bitmiş; Eylül'de ayrışıyor (26,0 vs 43,1M).
*/
