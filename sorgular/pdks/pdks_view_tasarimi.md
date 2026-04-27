# vrd · View Tasarım Notları

**Sorun:** `vrd.VardiyaDetay`'da gün kolonları (Pazartesi..Pazar) yatay tutulduğundan her sorguda hangi günün kolonu hard-coded yazılmak zorunda (`vd.Carsamba`, `vd.Cuma`, ...). Bu hem dashboard'ı hem SP'leri kırılgan yapıyor.

**Çözüm:** UNPIVOT mantığıyla 7 gün kolonunu satıra çeviren view + tarih bazlı eşleşme.

---

## 1. vrd.VardiyaDetayGun_vw (temel view)

```sql
CREATE OR ALTER VIEW vrd.VardiyaDetayGun_vw AS
SELECT
  v.VardiyaNo,
  v.SubeNo,
  v.Tarih                                    AS HaftaBas,   -- haftanın Pazartesi'si
  vd.Id                                      AS DetayId,
  vd.SicilNo, vd.Personel, vd.Bolum, vd.Gorev, vd.PartTime,
  DATEADD(DAY, gun.Offset, v.Tarih)          AS Gun,        -- gerçek gün (date)
  gun.GunAd                                  AS GunAdi,
  gun.VardiyaId                              AS VardiyaId   -- hem vardiya kodu hem özel kod (51..100)
FROM vrd.Vardiya v
INNER JOIN vrd.VardiyaDetay vd ON vd.VardiyaNo = v.VardiyaNo
CROSS APPLY (VALUES
  (0, N'Pazartesi', vd.Pazartesi),
  (1, N'Salı',      vd.Sali),
  (2, N'Çarşamba',  vd.Carsamba),
  (3, N'Perşembe',  vd.Persembe),
  (4, N'Cuma',      vd.Cuma),
  (5, N'Cumartesi', vd.Cumartesi),
  (6, N'Pazar',     vd.Pazar)
) gun(Offset, GunAd, VardiyaId);
```

**Kullanım:**
```sql
SELECT g.*, vz.Aciklama, vz.Baslama, vz.Bitis, vz.Izin, vz.ToplamCalismaDk, vz.MolaSureDk
FROM vrd.VardiyaDetayGun_vw g
LEFT JOIN vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
WHERE g.Gun = CONVERT(date, '15.04.2026', 104);
```

Artık hangi gün olduğunu düşünmeye gerek yok — tarih ver, ilgili kişiler ve atandıkları vardiya kodları otomatik gelir.

---

## 2. vrd.VardiyaZaman_vw (zenginleştirilmiş)

```sql
CREATE OR ALTER VIEW vrd.VardiyaZaman_vw AS
SELECT
  vz.*,
  CASE WHEN vz.Izin = 1 THEN 1 ELSE 0 END                AS IzinMi,
  CASE WHEN vz.VardiyaId = 100 THEN 1 ELSE 0 END         AS OzelDurumMu,
  vz.ToplamCalismaDk - ISNULL(vz.MolaSureDk, 0)          AS NetCalismaDk
FROM vrd.VardiyaZaman vz;
```

---

## 3. vrd.PlanFiili_vw (plan + fiili birleşik — opsiyonel, ağır)

OPENQUERY(PDKS) ile canlı TTagLes join'i. View olarak tanımlanırsa her çağrıda PDKS'e gider — **iTVF olarak tanımlamak daha mantıklı**:

```sql
CREATE OR ALTER FUNCTION vrd.fn_PlanFiili(@Tarih date)
RETURNS TABLE AS RETURN
WITH pdks AS (
  SELECT * FROM OPENQUERY([PDKS], '
    SELECT i.PIn_SteuerNr AS TC,
           CONVERT(varchar(5), l.TLe_VonZeit, 108) AS FiiliGiris,
           CONVERT(varchar(5), l.TLe_BisZeit, 108) AS FiiliCikis,
           l.TLe_IstZeit AS BrutSure,
           l.TLe_AbwArt  AS MazeretKod
    FROM TPerInd i
    INNER JOIN TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
    WHERE l.TLe_BeginnKz = 0
  ')
)
SELECT
  s.SubeAd AS Sube, g.Bolum, g.Personel, g.SicilNo AS TC,
  vz.Aciklama AS PlanVardiya,
  CONVERT(varchar(5), vz.Baslama, 108) AS PlanBas,
  CONVERT(varchar(5), vz.Bitis,   108) AS PlanBit,
  vz.Izin,
  p.FiiliGiris, p.FiiliCikis, p.BrutSure, p.MazeretKod
FROM vrd.VardiyaDetayGun_vw g
INNER JOIN vrd.SubeListe     s  ON s.SubeNo    = g.SubeNo
LEFT  JOIN vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
LEFT  JOIN pdks              p  ON p.TC COLLATE Turkish_CI_AS = g.SicilNo COLLATE Turkish_CI_AS
WHERE g.Gun = @Tarih;
```

⚠ **Uyarı:** OPENQUERY bir iTVF içinde kullanılamayabilir (linked server remote call inline fn'ye hoş bakmaz). Güvenli alternatif: **stored procedure** (`bkm.sp_PdksPlanFiili @Tarih`) veya önce `#tmp` tablosuna materialize etmek.

---

## Uygulama Planı

1. `vrd.VardiyaDetayGun_vw` — **önce bu**, her şeyin temeli.
2. `vrd.VardiyaZaman_vw` — IzinMi, NetCalismaDk kolonları.
3. Mevcut `pdks_vardiya_plan_fiili.sql` ve `pdks_sube_ozet.sql` sorgularını bu view'lara göre yeniden yaz (Carsamba hard-code'u kalksın).
4. Pano ve SP'ler için `bkm.sp_PdksPlanFiili_Liste @Tarih` stored procedure (OPENQUERY içeride, iTVF yerine SP).
5. `bkm.YoneticiKadro` tablosu ekle → view'a `LEFT JOIN` ile "yönetici mi" bilgisi de gelsin.

---

## Yan Faydalar

- Haftalık rapor: `WHERE g.Gun BETWEEN @Bas AND @Bit` → tek sorguda haftanın tamamı.
- Kişi takibi: `WHERE g.SicilNo = '...' AND g.Gun >= '01.04.2026'` → ay içi plan geçmişi tek tablo.
- İzin dağılımı: `GROUP BY g.GunAdi, vz.Aciklama WHERE vz.Izin=1` → haftanın hangi günü hangi izin yoğun.
