/* =======================================================================
   BKM.vrd Şeması · Tablo Keşfi
   -----------------------------------------------------------------------
   BKM veritabanındaki vrd (vardiya planlama) şemasının kolonları.
   Pano yapılmadan önce yapı keşfi için çalıştırıldı — arşivlenmiş referans.
   ======================================================================= */

-- Tablo listesi
SELECT TOP 50 TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'vrd';

-- Tüm kolonlar
SELECT TOP 200 TABLE_NAME, COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'vrd'
-- ORDER BY TABLE_NAME, ORDINAL_POSITION  -- ORDER BY olmaz (MCP TOP sarması)
;

/* ÖZET YAPI:
   vrd.Vardiya        : VardiyaNo (PK), SubeNo, Tarih (haftanın Pzt), BitisTarih, Kesin
   vrd.VardiyaDetay   : Id, VardiyaNo, SicilNo (TC), Bolum, Gorev, Personel,
                        PartTime, ToplamCalismaDk,
                        Pazartesi, Sali, Carsamba, Persembe, Cuma, Cumartesi, Pazar
                        (7 gün kolonu, her biri VardiyaZaman.VardiyaId'ye FK
                         veya özel kod: 51=HFT.İZİN, 52=ÜCRETSİZ, 53=ÜCRTLİ,
                         55=RESMİ TATİL, 58=YILLIK, 62=GÜVENLİK, 63=RAPOR, 73=MESAİ İZNİ)
   vrd.VardiyaZaman   : VardiyaId (PK), Aciklama, GrupNo, Aktif,
                        Baslama, Bitis, MolaSureDk, ToplamCalismaDk,
                        Dinlenme1Baslama/Bitis, Dinlenme2Baslama/Bitis,
                        YemekBaslama/Bitis, Izin
   vrd.SubeListe      : SubeNo (PK), SubeAd, GrupNo, EkBilgi1, EkBilgi2

   KRİTİK BULGU:
   - VardiyaZaman.MolaSureDk var → planda toplam mola dakikası biliniyor.
   - YemekBaslama/Bitis ve Dinlenme1/2 saatleri ayrı kolonlar.
   - Gerçek hesapta: plan net = ToplamCalismaDk − MolaSureDk.
*/
