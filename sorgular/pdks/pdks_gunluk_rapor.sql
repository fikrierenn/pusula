/* =======================================================================
   PDKS Günlük Rapor — GecoTime (SQL Server: 192.168.40.66\SQLEXPRESS)
   DB: wtimserv  |  Compat: 110
   -----------------------------------------------------------------------
   Kaynak: dbo.TTagLes (günlük ham kart okutma özeti — kişi/gün başına 1 satır)
   Join  : dbo.TPerTab (personel + Grup0..5 + Gün Modeli)
           dbo.TAbwArt (mazeret / devamsızlık açıklaması)
   -----------------------------------------------------------------------
   Excel → DB alan eşleşmesi:
     Sicil No        = Per_PersNr
     Adı             = Per_Vorname
     Soyadı          = Per_Name
     Grup0..5        = Per_Grp0 .. Per_Grp5
     Tarih           = TLe_Datum
     Pdks 1. Giriş   = TLe_VonZeit   (datetime — saat kısmı)
     Pdks 1. Çıkış   = TLe_BisZeit
     Gün Modeli      = Per_TagMod    (ör. 830-1)
     Mazeret         = Abw_AbwArtBez (TAbwArt lookup)
     Brüt Süre       = TLe_IstZeit   (decimal saat; 10.07 = 10s 07dk biçiminde yazdırılmış)
   -----------------------------------------------------------------------
   Tarih literal kuralı: DMY (CONVERT ..., 104). yyyy-MM-dd YOK.
   Compat 110: STRING_AGG / TRIM / IIF / TRY_CONVERT YOK.
   ======================================================================= */

DECLARE @Tarih     datetime     = CONVERT(datetime, '14.04.2026', 104);
DECLARE @Grup1     nvarchar(100) = N'GENEL MÜDÜRLÜK';
DECLARE @Grup2     nvarchar(100) = N'MALİ İŞLER VE YÖNETİM SİSTEMLERİ';  -- NULL bırakılırsa filtre uygulanmaz

SELECT
    p.Per_PersNr                                  AS [Sicil No],
    p.Per_Vorname                                 AS [Adı],
    p.Per_Name                                    AS [Soyadı],
    p.Per_Grp0                                    AS [Grup0],
    p.Per_Grp1                                    AS [Grup1],
    p.Per_Grp2                                    AS [Grup2],
    p.Per_Grp3                                    AS [Grup3],
    p.Per_Grp4                                    AS [Grup4],
    p.Per_Grp5                                    AS [Grup5],
    CONVERT(varchar(10), l.TLe_Datum, 104)        AS [Tarih],            -- dd.MM.yyyy
    CONVERT(varchar(5),  l.TLe_VonZeit, 108)      AS [Pdks 1. Giriş],   -- HH:mm
    CONVERT(varchar(5),  l.TLe_BisZeit, 108)      AS [Pdks 1. Çıkış],
    p.Per_TagMod                                  AS [Gün Modeli],
    a.Abw_AbwArtBez                               AS [Mazeret],
    l.TLe_IstZeit                                 AS [Brüt Süre]          -- ondalık saat
FROM dbo.TTagLes       AS l
INNER JOIN dbo.TPerTab AS p ON p.Per_PersNr = l.TLe_PersNr
LEFT  JOIN dbo.TAbwArt AS a ON a.Abw_AbwArt  = l.TLe_AbwArt
WHERE l.TLe_Datum = @Tarih
  AND l.TLe_BeginnKz = 0                         -- günün ilk (ve çoğu zaman tek) satırı
  AND p.Per_ZeitAktiv = 1                        -- aktif personel
  AND (@Grup1 IS NULL OR p.Per_Grp1 = @Grup1)
  AND (@Grup2 IS NULL OR p.Per_Grp2 = @Grup2)
ORDER BY p.Per_Grp3, p.Per_Grp4, p.Per_PersNr;
