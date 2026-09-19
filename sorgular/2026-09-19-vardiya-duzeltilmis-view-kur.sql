/*  DÜZELTİLMİŞ KİŞİ-GÜN VIEW'I — plan 49 / V-05 · 19.09.2026
    Hedef: BkmPanel (DEV).

    NE İÇİN: GMY kararı S1 — plan düzeltmesi eksik/fazla hesabının TABANINA girer.
    Taban `GerekenDk`tir (politika tablosundan gelir, `sp_Vrd_KisiGunDoldur` yazar).

    ⚠ FORMÜL NEDEN BURADA, C#'TA DEĞİL: eksik/fazla formülü SP'de yazılı. Aynı formülü
      okuma katmanında C# ile yeniden yazmak İKİ DOĞRULUK KAYNAĞI üretirdi ve ikisi
      ayrıştığında hangisinin doğru olduğu bilinemezdi (`emitter-ayrimi.md`). View,
      formülü SP ile AYNI dilde ve AYNI depo klasöründe tutar.

    ⚠ DÜZELTME YOKSA VIEW, `Vrd_KisiGun` İLE BİREBİR AYNIDIR. Bu bir iddia değil,
      done-criteria: düzeltme tablosu boşken panel rakamları değişmemeli.

    ⚠ İZİN İŞARETİ EZİLMEZ (karar S3): `Izin` kaynağın dediğidir ve DURUR.
      `IzinDuzeltme` insanın dediğidir, AYRI kolonda. Ekran ikisini de gösterir.
      Hesap tarafında düzeltilmiş izin `GerekenDk`i 0'a çeker — çünkü izinli günün
      tabanı yoktur; ama kaynağın değeri kaybolmaz.
*/

IF OBJECT_ID('bkm.Vrd_KisiGunDuzeltilmis_vw') IS NOT NULL
    DROP VIEW bkm.Vrd_KisiGunDuzeltilmis_vw;
GO

CREATE VIEW bkm.Vrd_KisiGunDuzeltilmis_vw
AS
SELECT
    k.*,

    -- ── DÜZELTME ALANLARI (ham hâlleriyle — ekran ikisini de gösterebilsin) ──
    DuzeltmeVardiyaTanim  = d.VardiyaTanim,
    DuzeltmePlanBaslamaDk = d.PlanBaslamaDk,
    DuzeltmePlanBitisDk   = d.PlanBitisDk,
    DuzeltmePlanCalismaDk = d.PlanCalismaDk,
    DuzeltmeIzinliMi      = d.IzinliMi,
    DuzeltmeAciklama      = d.Aciklama,
    DuzeltmeKaydeden      = d.Kaydeden,
    DuzeltmeKayitUtc      = d.KayitUtc,
    DuzeltildiMi          = CASE WHEN d.SicilNo IS NULL THEN CONVERT(bit, 0) ELSE CONVERT(bit, 1) END,

    -- ── ETKİN DEĞERLER — düzeltme varsa o, yoksa kaynağın değeri ─────────────
    EtkinVardiyaTanim = ISNULL(d.VardiyaTanim, k.VardiyaTanim),

    -- Etkin taban, ÜÇ dallı — ikinci dal bir ÖLÇÜMDEN doğdu (19.09):
    --   1) düzeltme "izinli" diyorsa taban 0 (izinli günün tabanı yoktur),
    --   2) KAYNAK izinli ve düzeltme bu konuda SUSUYORSA taban DEĞİŞMEZ,
    --   3) aksi hâlde düzeltilmiş süre, o da yoksa SP'nin yazdığı `GerekenDk`.
    --
    -- ⚠ İKİNCİ DAL OLMADAN NE OLUYORDU (ölçüldü, geri alınabilir işlemde):
    --   izinli bir güne süre yazılınca `EtkinEksikDk` 0 → 480 oluyordu; yani
    --   kişi İZİNDEYKEN 8 saat EKSİK görünüyordu. Delta aritmetiği doğruydu,
    --   ANLAMI yanlıştı — Solum'un "çok adımlı mantığı tek satırlık fikstürle
    --   ölçemezsin" uyarısının bizdeki karşılığı: tek NORMAL gün üzerinde
    --   test edildiği için görünmüyordu.
    --
    -- ⚠ "Aslında izinli DEĞİLDİ" demek hâlâ mümkün: `IzinliMi = 0` yazılırsa
    --   üçüncü dala düşer ve süre uygulanır. Yani kaynak EZİLMİYOR, ama
    --   bilinçli bir itiraz yazılabiliyor (karar S3).
    EtkinGerekenDk = CASE
        WHEN d.IzinliMi = 1 THEN 0
        WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
        ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END,

    -- ── ETKİN EKSİK/FAZLA — SP'NİN DEĞERİNE TABAN FARKI UYGULANIR ──────────
    --
    -- ⚠ İLK YAZIMDA FORMÜL SIFIRDAN YENİDEN YAZILMIŞTI ve SP'den AYRIŞTI:
    --   mutabakat 82.800 dk fark verdi. Sebep: SP'nin `FazlaDk`ı yalnız
    --   `Net2 - Gereken` değil — izin gününde hafta tatili primi (`HaftalikPrimDk`,
    --   540 dk) de içinde. Yani "aynı formülü yazdım" sanmak YETMEDİ; formülün
    --   TAMAMI SP'nin dört ayrı UPDATE bloğuna yayılmış.
    --
    -- DOĞRU MEKANİZMA: formülü kopyalamak değil, TABAN FARKINI uygulamak.
    --   Δ = EtkinGereken - Gereken   (düzeltme yoksa Δ = 0)
    --   Eksik' = max(Eksik + Δ, 0)   ·   Fazla' = max(Fazla - Δ, 0)
    -- Düzeltme YOKKEN sonuç SP'nin değerinin AYNISI olur — mutabakat aritmetik
    -- olarak garanti, iddia değil. Prim gibi taban-dışı kalemler olduğu gibi taşınır
    -- (vardiya tanımı hafta tatili primini değiştirmez).
    EtkinEksikDk = CASE WHEN k.SayimDisi = 1 THEN 0 ELSE
        CASE WHEN ISNULL(k.EksikDk, 0)
                + (CASE WHEN d.IzinliMi = 1 THEN 0
                            WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
                            ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END
                   - ISNULL(k.GerekenDk, 0)) > 0
             THEN ISNULL(k.EksikDk, 0)
                + (CASE WHEN d.IzinliMi = 1 THEN 0
                            WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
                            ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END
                   - ISNULL(k.GerekenDk, 0))
             ELSE 0 END END,

    EtkinFazlaDk = CASE WHEN k.SayimDisi = 1 THEN 0 ELSE
        CASE WHEN ISNULL(k.FazlaDk, 0)
                - (CASE WHEN d.IzinliMi = 1 THEN 0
                            WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
                            ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END
                   - ISNULL(k.GerekenDk, 0)) > 0
             THEN ISNULL(k.FazlaDk, 0)
                - (CASE WHEN d.IzinliMi = 1 THEN 0
                            WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
                            ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END
                   - ISNULL(k.GerekenDk, 0))
             ELSE 0 END END

FROM       bkm.Vrd_KisiGun       k
LEFT JOIN  bkm.Vrd_PlanDuzeltme  d
       ON  d.SicilNo = k.SicilNo AND d.Tarih = k.Tarih;
GO

/*  MUTABAKAT — düzeltme tablosu boşken view ile kaynak BİREBİR aynı olmalı.
    Fark çıkarsa view'ın formülü SP'den ayrışmış demektir ve bu SESSİZ bir
    sapmadır: panel bir rakam, yayınlanan Excel başka bir rakam gösterir.        */
SELECT Kontrol       = N'duzeltme yokken view = kaynak',
       DuzeltmeSatir = (SELECT COUNT(*) FROM bkm.Vrd_PlanDuzeltme),
       EksikFark     = (SELECT SUM(ABS(ISNULL(v.EtkinEksikDk,0) - ISNULL(v.EksikDk,0)))
                        FROM bkm.Vrd_KisiGunDuzeltilmis_vw v),
       FazlaFark     = (SELECT SUM(ABS(ISNULL(v.EtkinFazlaDk,0) - ISNULL(v.FazlaDk,0)))
                        FROM bkm.Vrd_KisiGunDuzeltilmis_vw v);
GO
