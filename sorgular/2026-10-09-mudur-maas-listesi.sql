-- Müdür + müdür yardımcısı maaş listesi (mağaza + merkez, 3 firma)
-- Sunucu: Zirve (ZIRVE\ZRVSQL2008) · DB: BKM_GENEL · MCP: mcp__zirve__sql_query
-- Kaynak: dbo.vw_PersonelDepartman (İK kanonik, CARİ ücret)
--       + dbo.vw_PuanBil        (bordro, TARİHSEL maliyet — sema: entities:BKM_GENEL.dbo.vw_PuanBil)
--
-- KRİTİK KURALLAR
--   1) AKTİF = Ict IS NULL (Personeldurumu DEĞİL — tarihçe içerir).
--   2) v.Ucret = CARİ oran, NET (TahakkukSekli='NET' tüm kadro). İKİ BİRİM:
--      GÜNLÜK (aylık = Ucret×30) vs AYLIK (doğrudan). View `Ucretsekli`'yi TAŞIMAZ
--      → eşik ayrımı. ÖLÇÜLDÜ 09.10.2026: bu 22 kişide GÜNLÜK üst sınırı 3.333,34 ₺,
--      AYLIK alt sınırı 100.000 ₺ → 8.000 eşiği güvenli (30× uçurum).
--      Geçmiş AY maliyeti için v.Ucret KULLANILMAZ → vw_PuanBil.
--   3) Join `vw_PuanBil.Personelno = vw_PersonelDepartman.Personelno` — ikisi de FİRMA
--      SONEKLİ string ('1108-BKM'), 1:1 (kişi×ay). Ham `dbo.puanbil` INT ve yalnız
--      BKM_GENEL → oraya join edilirse Heykel/Şura personeli SESSİZCE düşer.
--   4) SON TAM BORDRO AYI = Eylül 2026. Ekim'de yalnız 17 kişi var (Eylül 381) →
--      cari ay bordrosu KOŞMAMIŞ, kısmi. (sema: vw_PuanBil.bordro_gecikmesi)
--   5) İşveren maliyeti = Bt + Isskk + Iisk (yönetimin kendi formülü). Kıdem karşılığı
--      ve yan haklar (giyim/yemek/yol) BU FORMÜLDE YOK → ALT SINIR.
--   6) ⚠ `Sak` = AVANS/KESİNTİ. Eylül net ödeneni cari netin altındaysa sebebi budur,
--      ücret düşüklüğü DEĞİL. Kullanıcı teyidi 09.10.2026: İsmail Ertem (890-BKM)
--      YILLIK İZNE çıktı, izin ücreti peşin ödendi → Sak 76.666,67 = tam 23 günlük
--      ücret; Calismagunu 6 / Primgunu 30 ile tutarlı (yıllık izin prim günü sayılır).
--      DOĞRULAMA: Faruk Bingölbali'de kimlik TAM tutuyor (75.000 − 3.383 = 71.617).
--   7) `Calismagunu` vw_PuanBil'de YOK (yalnız ham dbo.puanbil'de, BKM_GENEL).
--
-- Kapsam: Unvan LIKE '%MÜDÜR%' OR '%MDR%' → 22 kişi (13 müdür + 9 yardımcı;
--         11 mağaza + 11 merkez). GENEL MÜDÜR YARDIMCISI dahil, YÖNETİM KURULU
--         BAŞKANI hariç (müdür ünvanı değil). 'MDR.' kısaltması şart — 3 ünvan
--         (Mağazalar Satış Opr. MDR. · İdari İşler ve Opr. MDR. · Kitap Dışı
--         Satınalma MDR.) yalnız kısaltmayla yazılı, '%MÜDÜR%' onları KAÇIRIR.
--
-- Sonuç (ölçüm 09.10.2026): cari aylık net toplam 1.678.501,80 ₺ ·
--         Eylül işveren maliyeti 3.112.167,15 ₺
-- Emitter: scripts/beyaz_yaka_maas_excel.py → briefings/2026-10-09/mudur-maas-listesi.xlsx

SELECT
    v.Personelno,
    v.AdSoyad,
    CASE WHEN v.Unvan LIKE '%YARDIMCISI%' OR v.Unvan LIKE '%YRD%'
         THEN 'Yardımcı' ELSE 'Müdür' END                        AS Seviye,
    CASE WHEN v.Lokasyon = 'MAĞAZALAR' THEN 'Mağaza'
         ELSE 'Merkez' END                                       AS Grup,
    v.AltLokasyon                                                AS Sube,
    v.Unvan,
    v.Firma,
    CONVERT(varchar, v.Igt, 104)                                 AS GirisTarihi,
    CAST(DATEDIFF(DAY, v.Igt, GETDATE()) / 365.25 AS decimal(5,1)) AS KidemYil,
    v.Ucret                                                      AS UcretOran,
    CASE WHEN v.Ucret < 8000 THEN 'GÜNLÜK' ELSE 'AYLIK' END      AS UcretSekli,
    CAST(CASE WHEN v.Ucret < 8000 THEN v.Ucret * 30
              ELSE v.Ucret END AS decimal(18,2))                 AS CariAylikNet,
    b.Primgunu                                                   AS EylPrimGun,
    CAST(ISNULL(b.Sak, 0)           AS decimal(18,2))            AS EylAvansKesinti,
    CAST(b.Netu                     AS decimal(18,2))            AS EylNetOdenen,
    CAST(b.Bt                       AS decimal(18,2))            AS EylBrut,
    CAST(b.Isskk                    AS decimal(18,2))            AS EylIsvSGK,
    CAST(b.Iisk                     AS decimal(18,2))            AS EylIsvIssizlik,
    CAST(b.Bt + b.Isskk + b.Iisk    AS decimal(18,2))            AS EylIsverenMaliyet
FROM dbo.vw_PersonelDepartman v
LEFT JOIN dbo.vw_PuanBil b
       ON b.Personelno = v.Personelno
      AND b.Yil = 2026
      AND b.Ayindex = 9            -- SON TAM BORDRO AYI (kural 4)
WHERE v.Ict IS NULL
  AND (v.Unvan LIKE '%MÜDÜR%' OR v.Unvan LIKE '%MDR%')
ORDER BY
    CASE WHEN v.Lokasyon = 'MAĞAZALAR' THEN 1 ELSE 0 END,
    CASE WHEN v.Unvan LIKE '%YARDIMCISI%' OR v.Unvan LIKE '%YRD%' THEN 1 ELSE 0 END,
    CariAylikNet DESC;
