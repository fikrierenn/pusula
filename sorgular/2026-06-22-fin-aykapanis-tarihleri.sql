/* bkm.Fin_AyKapanis — kapanış tarihleri upsert (idempotent MERGE).
   Kaynak: Fikri 22.06.2026. Eksik olanlar: Ara.25 + Oca–May.26 (mevcut 2025 Oca–Kas zaten vardı).
   KapanisDT = kapanış günü 23:59:59 (mevcut konvansiyon). Tekrar çalıştırılabilir.
   Deploy sonrası: bkm.sp_KapanisMudahaleKontrol_v2 / muhasebe-denetci 2026 kapanmış aylar için de çalışır. */

MERGE bkm.Fin_AyKapanis AS h
USING (VALUES
    (2025, 1,  '2025-02-14 23:59:59'), (2025, 2,  '2025-03-14 23:59:59'),
    (2025, 3,  '2025-04-11 23:59:59'), (2025, 4,  '2025-05-20 23:59:59'),
    (2025, 5,  '2025-06-16 23:59:59'), (2025, 6,  '2025-07-07 23:59:59'),
    (2025, 7,  '2025-08-15 23:59:59'), (2025, 8,  '2025-09-11 23:59:59'),
    (2025, 9,  '2025-10-14 23:59:59'), (2025, 10, '2025-11-14 23:59:59'),
    (2025, 11, '2025-12-12 23:59:59'), (2025, 12, '2026-01-13 23:59:59'),
    (2026, 1,  '2026-02-13 23:59:59'), (2026, 2,  '2026-03-17 23:59:59'),
    (2026, 3,  '2026-04-15 23:59:59'), (2026, 4,  '2026-05-22 23:59:59'),
    (2026, 5,  '2026-06-16 23:59:59')
) AS s (DonemYil, DonemAy, KapanisDT)
ON  h.DonemYil = s.DonemYil AND h.DonemAy = s.DonemAy
WHEN MATCHED AND h.KapanisDT <> CONVERT(datetime2(0), s.KapanisDT) THEN
    UPDATE SET h.KapanisDT = CONVERT(datetime2(0), s.KapanisDT)
WHEN NOT MATCHED BY TARGET THEN
    INSERT (DonemYil, DonemAy, KapanisDT, Aciklama, KayitDT)
    VALUES (s.DonemYil, s.DonemAy, CONVERT(datetime2(0), s.KapanisDT),
            N'Muhasebe ay kapanışı ('
              + SUBSTRING(N'OcaŞubMarNisMayHazTemAğuEylEkiKasAra', (s.DonemAy-1)*3+1, 3)
              + '.' + RIGHT(CAST(s.DonemYil AS varchar(4)),2) + ')',
            SYSDATETIME());

SELECT DonemYil, DonemAy, CONVERT(varchar(10),KapanisDT,104) AS Kapanis, Aciklama
FROM bkm.Fin_AyKapanis ORDER BY DonemYil, DonemAy;
