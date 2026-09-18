/* =====================================================================
   ŞUBE ACL'İ ZAMANSAL OLDU + kapsam çözücü tarih alır (plan 48 Adım 4)
   Hedef: DEV — BT-FIKRI\SQLEXPRESS · BkmPanel · şema bkm
   Tarih: 19.09.2026

   GMY kararları (19.09): *"sistemden bağımsız olsun, bölge yok, geçmiş önemli"*

   1. SİSTEMDEN BAĞIMSIZ → ACL `kullanıcı ↔ şube` kalır. `(şube, sistem)` ikilisine
      çıkarılmaz; bir kullanıcı bir şubeyi görüyorsa her sistemde görür.
   2. BÖLGE YOK → hiyerarşi kurulmaz. `Vrd_Sube.Grup` (MAĞAZA/KAFE/GENEL MÜDÜRLÜK)
      bir TİP ayrımıdır, hiyerarşi değil — "bütün kafeleri gör" ile "bölgeyi gör"
      farklı şeylerdir ve ikincisi İSTENMEDİ.
   3. GEÇMİŞ ÖNEMLİ → ACL'e geçerlilik aralığı eklendi ve kapsam çözücü artık
      TARİH alıyor.

   ⚠ YORUM KARARI — açıkça beyan ediliyor (ÇIKARIM, ölçüm değil):
   Kapsam, kişi-gün satırının TARİHİNE göre çözülür. Sonucu:
     · Müdür Ağustos'ta A şubesindeyse, B'ye geçtikten sonra da AĞUSTOS'un
       A satırlarını görmeye devam eder (kendi dönemi).
     · A'nın YENİ müdürü, kendinden önceki dönemin satırlarını GÖRMEZ.
     · İK ve GMY her ikisini de görür ("tüm şubeler" yetkisi zamansız).
   Bu davranış istenmiyorsa değişecek tek yer `Vrd_SubeKapsami`'nin @Tarih
   kullanımıdır — çağıran tarafta dağılmaz.
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ── 1. ACL'E GEÇERLİLİK ARALIĞI ───────────────────────────────────────
   Silme yerine KAPATMA: müdür şube değiştirdiğinde satır silinmez,
   GecerliBit yazılır. Silinseydi "o tarihte kim neredeydi" sorusu
   cevaplanamaz olurdu ve bu tam olarak GMY'nin "geçmiş önemli"
   dediği şeydir.

   ⚠ Aynı derste ikinci kere: `bkm.Vrd_Devir` de bu yüzden dondurulmuştu
   (PDKS geçmişe dönük değişiyor — ÖLÇÜLDÜ 17.09). Kayıt silen bir tasarım
   geçmişi yeniden üretilemez yapar. */

IF COL_LENGTH('bkm.Vrd_KullaniciSube', 'GecerliBas') IS NULL
BEGIN
    ALTER TABLE bkm.Vrd_KullaniciSube
        ADD GecerliBas date NOT NULL CONSTRAINT DF_VrdKullSube_Bas DEFAULT ('19000101'),
            GecerliBit date NULL;   -- NULL = hâlâ geçerli (açık uçlu)
END;
GO

/* Aynı kullanıcı+şube için AYNI ANDA iki açık satır olamaz.
   ⚠ Eski UNIQUE(UserId, Sube) KALDIRILMALI: zamansal modelde aynı çift
   birden çok kez geçerli olabilir (ayrıldı, geri döndü). Ama AÇIK olan
   yalnız bir tane olmalı — yoksa erişimi kaldırma yine yarım kalır
   (Solum 0005'in dersi, zamansal hâli). */
IF INDEXPROPERTY(OBJECT_ID('bkm.Vrd_KullaniciSube'), 'UX_Vrd_KullaniciSube', 'IndexID') IS NOT NULL
    DROP INDEX UX_Vrd_KullaniciSube ON bkm.Vrd_KullaniciSube;
GO

IF INDEXPROPERTY(OBJECT_ID('bkm.Vrd_KullaniciSube'), 'UX_Vrd_KullaniciSube_Acik', 'IndexID') IS NULL
CREATE UNIQUE NONCLUSTERED INDEX UX_Vrd_KullaniciSube_Acik
    ON bkm.Vrd_KullaniciSube (UserId, Sube)
    WHERE GecerliBit IS NULL;
GO

/* Aralık tutarlılığı: bitiş başlangıçtan önce olamaz. Bu bir VERİ durumu
   değil KOD hatasıdır (dogrulama-siniri: iki şey aynı anda doğru olamaz) →
   kısıt, uyarı değil. */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_VrdKullSube_Aralik')
    ALTER TABLE bkm.Vrd_KullaniciSube
        ADD CONSTRAINT CK_VrdKullSube_Aralik CHECK (GecerliBit IS NULL OR GecerliBit >= GecerliBas);
GO

/* ── 2. KAPSAM ÇÖZÜCÜ — artık TARİH alıyor ─────────────────────────────
   Sözleşme değişti: @KullaniciId + @Tarih.
   @Tarih NULL → bugün (giriş ekranı, menü, "şu an neyi görüyorum").
   @Tarih dolu → o günkü kapsam (kişi-gün satırı, onay, denetim).

   (b)-tam bozulmadı: hâlâ hiçbir ŞUBE kimliği ve hiçbir YETKİ bayrağı
   uygulamadan geçmiyor. @Tarih bir yetki kararı değil, satırın kendi
   olgusudur — uydurulmuş bir tarih yalnız o günün kapsamını verir. */

IF OBJECT_ID('bkm.Vrd_SubeKapsami') IS NOT NULL DROP FUNCTION bkm.Vrd_SubeKapsami;
GO

CREATE FUNCTION bkm.Vrd_SubeKapsami (@KullaniciId nvarchar(450), @Tarih date)
RETURNS TABLE
AS
RETURN
(
    -- (1) "Tüm şubeler" yetkisi: şube kümesinin TAMAMI.
    --     Yetki ZAMANSIZ — İK/GMY geçmişi de bütün olarak görür. Yetkiyi de
    --     tarihlemek, geçmiş bir dönemi kimsenin göremediği bir boşluğa
    --     düşürebilirdi (o dönem yetkili olan kişi ayrılmışsa).
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

    -- (2) ACL: verilen TARİHTE geçerli olan satırlar.
    SELECT ks.Sube
    FROM   bkm.Vrd_KullaniciSube AS ks
    WHERE  ks.UserId = @KullaniciId
      AND  ks.GecerliBas <= ISNULL(@Tarih, CAST(SYSDATETIME() AS date))
      AND  (ks.GecerliBit IS NULL OR ks.GecerliBit >= ISNULL(@Tarih, CAST(SYSDATETIME() AS date)))
);
GO

/* ── 3. "O TARİHTE NEREDEYDİ" — denetim sorusu ─────────────────────────
   GMY'nin "geçmiş önemli" kararının doğrudan karşılığı. Denetim izinde
   bir onayın kim tarafından, hangi yetkiyle verildiği sorulduğunda
   cevabı bu view üretir. */

IF OBJECT_ID('bkm.Vrd_KullaniciSubeGecmis_vw') IS NOT NULL DROP VIEW bkm.Vrd_KullaniciSubeGecmis_vw;
GO

CREATE VIEW bkm.Vrd_KullaniciSubeGecmis_vw
AS
SELECT  ks.UserId,
        u.UserName,
        ks.Sube,
        ks.GecerliBas,
        ks.GecerliBit,
        Durum = CASE WHEN ks.GecerliBit IS NULL THEN N'açık' ELSE N'kapalı' END,
        ks.VerenId,
        ks.VerilmeUtc
FROM    bkm.Vrd_KullaniciSube AS ks
LEFT JOIN bkm.Vrd_Users       AS u ON u.Id = ks.UserId;
GO
