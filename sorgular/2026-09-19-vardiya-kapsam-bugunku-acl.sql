/* =====================================================================
   DÜZELTME — KAPSAM BUGÜNKÜ ACL'DEN ÇÖZÜLÜR (plan 48 Adım 4)
   Hedef: DEV — BT-FIKRI\SQLEXPRESS · BkmPanel · şema bkm
   Tarih: 19.09.2026

   NEDEN DÜZELTİLİYOR — GMY itirazı (19.09), haklı:
     *"ama eski müdür verileri görmezse nasıl karşılaştırma tahmin vs yapacak"*

   Önceki sürüm (aynı gün, birkaç saat önce) kapsamı kişi-gün satırının
   TARİHİNE bağlıyordu. Sonucu: A şubesine YENİ atanan müdür, kendinden
   önceki dönemi GÖREMİYORDU — yani kendi şubesinin geçmişini. Geçen yılla
   kıyas, trend ve tahmin bunsuz yapılamaz.

   HATA SINIFI: iki AYRI soruyu tek mekanizmaya bağlamak.

     GÖRME YETKİSİ   "bugün hangi şubeden sorumluyum"  → o şubenin TÜM geçmişi
     DENETİM KAYDI   "o tarihte kim sorumluydu"        → zamansal ACL + view

   Zamansal ACL YANLIŞ DEĞİLDİ ve KALIYOR — yalnız amacı düzeltildi: geçmişi
   saklar, yetkiyi kesmez.

   NE DEĞİŞİYOR
     · `Vrd_SubeKapsami` @Tarih parametresini BIRAKIR → bugünkü ACL'den çözer.
     · Geçmiş sorusu `Vrd_KullaniciSubeGecmis_vw`de kalır (dokunulmuyor).
     · `GecerliBas`/`GecerliBit`/kısıtlar OLDUĞU GİBİ kalır.

   DAVRANIŞ (beyan edilir):
     · A'nın yeni müdürü A'nın TÜM geçmişini görür. ✔ (kıyas/tahmin mümkün)
     · B'ye geçen eski müdür A'yı ARTIK GÖRMEZ — kendi dönemi dahil.
       Sorumluluk bitti; kaydı denetim izinde duruyor.
     · İK / GMY her şeyi görür.
   ===================================================================== */

SET NOCOUNT ON;
GO

IF OBJECT_ID('bkm.Vrd_SubeKapsami') IS NOT NULL DROP FUNCTION bkm.Vrd_SubeKapsami;
GO

CREATE FUNCTION bkm.Vrd_SubeKapsami (@KullaniciId nvarchar(450))
RETURNS TABLE
AS
RETURN
(
    -- (1) "Tüm şubeler" yetkisi → şube kümesinin TAMAMI (canlı okunur;
    --     yeni açılan şube kendiliğinden kapsama girer).
    SELECT s.Sube
    FROM   bkm.Vrd_Sube AS s
    WHERE  EXISTS (
        SELECT 1
        FROM   bkm.SolumPermissionGrant AS g
        WHERE  g.PermissionName = N'vardiya.tumSubeler'
          AND  (
                 (g.ProviderName = N'User' AND g.ProviderKey = @KullaniciId)
              OR (g.ProviderName = N'Role' AND EXISTS (
                     SELECT 1
                     FROM   bkm.Vrd_UserRoles AS ur
                     JOIN   bkm.Vrd_Roles     AS r ON r.Id = ur.RoleId
                     WHERE  ur.UserId = @KullaniciId
                       AND  r.Name    = g.ProviderKey))
               )
    )

    UNION

    -- (2) ACL: BUGÜN geçerli olan satırlar.
    --     "Bugün sorumluysan geçmişi de görürsün" — tarih süzgeci YOK.
    SELECT ks.Sube
    FROM   bkm.Vrd_KullaniciSube AS ks
    WHERE  ks.UserId = @KullaniciId
      AND  ks.GecerliBas <= CAST(SYSDATETIME() AS date)
      AND  (ks.GecerliBit IS NULL OR ks.GecerliBit >= CAST(SYSDATETIME() AS date))
);
GO

/* ── DENETİM TARAFI DEĞİŞMEDİ ──────────────────────────────────────────
   "Bu onayı veren kişi o tarihte bu şubeden sorumlu muydu?" sorusunun
   cevabı hâlâ bkm.Vrd_KullaniciSubeGecmis_vw'de. Zamansal ACL'in varlık
   sebebi bu; yetki süzgeci değil.

   İleride onay kaydı denetlenirken kullanılacak kalıp:

     SELECT g.* FROM bkm.Vrd_KullaniciSubeGecmis_vw g
     WHERE  g.UserId = @onaylayan AND g.Sube = @sube
       AND  g.GecerliBas <= @onayTarihi
       AND  (g.GecerliBit IS NULL OR g.GecerliBit >= @onayTarihi);
   -- satır YOKSA: onay, sorumlu olmadığı bir dönem için verilmiş.
*/
