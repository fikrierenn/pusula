/* ============================================================================
   2026-09-21 — BKM Mağaza: İŞLEM LOGU                     (DB: BkmPanel, APP-LOCAL)
   Plan: plans/50-magaza-urun-bulma-uygulamasi.md

   ⚠ ERP'DE DEĞİL — panel veritabanı (erp-write-policy.md).

   NEDEN: cihaz kaydı "kim hangi telefonu kullanıyor" sorusunu cevaplıyordu ama
   "ne yapıldı" sorusunu değil. Kayıp cihaz, yanlış bilgi şikâyeti veya bir barkodun
   ne zaman sorgulandığı ancak işlem izi varsa cevaplanır (security-principles.md
   § Audit Logging: log olmayan aksiyon takip edilemez).

   ⚠ KVKK / ORANTILILIK — bilinçli sınırlar:
     · Kişi bazlı ARAMA METNİ 90 günden uzun tutulmaz (temizlik işi aşağıda).
     · Log PERFORMANS DEĞERLENDİRMESİ için kullanılmaz; amacı denetim ve arıza takibi.
       Bu niyet burada yazılı olmazsa, veri var diye sonradan "kim kaç arama yaptı"
       karnesine dönüşür — ik-danisman kuralı: ölçüm aracı ceza aracına çevrilince
       personel aracı kullanmayı bırakır ve veri de biter.
     · Personele bildirilmeli (aydınlatma) — uygulama içinde yazılı.
   ============================================================================ */

IF OBJECT_ID('dbo.PanelMagazaIslemLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PanelMagazaIslemLog
    (
        Id        bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_PanelMagazaIslemLog PRIMARY KEY,
        Tarih     datetime2(0)  NOT NULL CONSTRAINT DF_PMIL_Tarih DEFAULT (SYSUTCDATETIME()),
        CihazId   nvarchar(64)  NULL,
        AdSoyad   nvarchar(128) NULL,
        MekanId   int           NULL,
        Islem     nvarchar(24)  NOT NULL,   -- arama · urun · barkod · kayit · gecmis
        Detay     nvarchar(200) NULL,       -- arama metni / stkID / barkod
        Ip        nvarchar(45)  NULL
    );

    CREATE INDEX IX_PanelMagazaIslemLog_Tarih ON dbo.PanelMagazaIslemLog (Tarih DESC);
    CREATE INDEX IX_PanelMagazaIslemLog_Cihaz ON dbo.PanelMagazaIslemLog (CihazId, Tarih DESC);
END
GO

/* 90 günden eski kayıtları sil (elle ya da zamanlanmış görevle):
       DELETE FROM dbo.PanelMagazaIslemLog WHERE Tarih < DATEADD(day, -90, SYSUTCDATETIME());

   Bir cihazın izi:
       SELECT TOP 200 Tarih, Islem, Detay FROM dbo.PanelMagazaIslemLog
       WHERE CihazId = N'<uuid>' ORDER BY Tarih DESC;
*/
