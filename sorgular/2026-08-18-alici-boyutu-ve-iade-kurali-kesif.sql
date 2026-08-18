/*
  Soru: Alım Analizi'ne alıcı-atıf eklenebilir mi (kim karar verdi)? "Fazla aldı" iddiası
        iade hakkı/vade koşulu bilinmeden adil mi?
  DB: DerinSISBkm. Tetik: 2026-08-18 Alım Analizi eksik-boyut denetimi (satinalma-danisman).

  BULGULAR:
   1) irs.gKisi = MAL KABUL personeli (GMY teyidi) → ALICI ATIFI İÇİN KULLANILAMAZ.
      12 ayda 4 kişi: SAMET TILCI 2.320 evrak/118 tedarikçi · Mehmet 517/46 · Mesut 99/27 · Erkan 53/18.
   2) GERÇEK KARAR BOYUTU = bkm.OneriSiparisTalep (EkleyenKullanici + OnaylayanKullanici +
      SiparisMiktar + Onay + SipId). 25 kullanıcı, 2024-06 → 2026-08.
      İKİ TİP: kişi hesabı (eren.boran2 29.253 talep · seyda.cindan 15.231 · hakan.cetin 1.215/25.334 adet)
      vs REYON paylaşımlı hesap (ist.cocuk 23.358 · ist.kultur 14.846 · fsm.kultur 9.674 …).
      → paylaşımlı hesapta BİREYE atıf YAPILAMAZ, reyon sorumlusuna atfedilir.
      SoD sinyali: onay oranı çoğunda ~%100 (formalite şüphesi); istisna sirac.yigit %14, kubra %52.
   3) Tedarikçiye bağlanma: bkm.OneriSiparisTalepSiparis (FrmId, SipAdet, TalepNo, Gonderildi).
   4) İADE/VADE: dbo.frm.frmIadeKural DOLU (0→1.248 peşin · 1→99 · 2→1.273, vadeTur=1'de ort 130 gün);
      frmVade/frmVade1..5/frmVadeTur mevcut. ⚠️ dbo.urn.alimIadeYok ÖLÜ KOLON (138.920 ürün tek değer=2).
      frmIadeKural 0/1/2 kod anlamı TEYİT BEKLİYOR (lookup yok).
*/

-- 1) Alış evrakını giren kişiler (ALICI DEĞİL — mal kabul; atıf tuzağı kanıtı)
SELECT i.gKisi, k.insAd,
       COUNT(DISTINCT i.eID)    AS alis_evrak,
       COUNT(DISTINCT i.eFirma) AS tedarikci,
       CONVERT(varchar, MIN(i.eTarihS), 104) AS ilk,
       CONVERT(varchar, MAX(i.eTarihS), 104) AS son
FROM dbo.irs i WITH(NOLOCK)
LEFT JOIN dbo.drn1 k WITH(NOLOCK) ON k.insID = i.gKisi
WHERE i.eTip = 0 AND i.eTarihS >= '20250801' AND i.eTarihS < '20260801'
GROUP BY i.gKisi, k.insAd
ORDER BY COUNT(DISTINCT i.eID) DESC;

-- 2) GERÇEK alıcı boyutu — talep açan + onaylayan + onay oranı (SoD sinyali)
SELECT t.EkleyenKullanici,
       COUNT(*)                                AS talep,
       COUNT(DISTINCT t.StkId)                 AS urun,
       SUM(t.SiparisMiktar)                    AS toplam_adet,
       SUM(CASE WHEN t.Onay = 1 THEN 1 ELSE 0 END) AS onayli,
       COUNT(DISTINCT t.OnaylayanKullanici)    AS onaylayan_sayi,
       CONVERT(varchar, MIN(t.Tarih), 104)     AS ilk,
       CONVERT(varchar, MAX(t.Tarih), 104)     AS son
FROM DerinSISBkm.bkm.OneriSiparisTalep t WITH(NOLOCK)
GROUP BY t.EkleyenKullanici
ORDER BY COUNT(*) DESC;

-- 3) Görevler ayrılığı (SoD) — ekleyen = onaylayan olan talepler (kendi talebini onaylama)
SELECT t.EkleyenKullanici, COUNT(*) AS kendi_onayladi, SUM(t.SiparisMiktar) AS adet
FROM DerinSISBkm.bkm.OneriSiparisTalep t WITH(NOLOCK)
WHERE t.Onay = 1 AND t.OnaylayanKullanici = t.EkleyenKullanici
GROUP BY t.EkleyenKullanici
ORDER BY COUNT(*) DESC;

-- 4) İade kuralı + vade dağılımı (adalet şartı) — frmTip=0 satıcı
SELECT f.frmIadeKural, f.frmVadeTur, COUNT(*) AS tedarikci_sayi,
       AVG(CONVERT(float, f.frmVade)) AS ort_vade
FROM dbo.frm f WITH(NOLOCK)
WHERE f.frmTip = 0
GROUP BY f.frmIadeKural, f.frmVadeTur
ORDER BY COUNT(*) DESC;

-- 5) urn.alimIadeYok gerçekten kullanılıyor mu? (tek değer dönerse ÖLÜ KOLON)
SELECT u.alimIadeYok, COUNT(*) AS urun_sayi
FROM dbo.urn u WITH(NOLOCK)
JOIN DerinSISBkm.bkm.UrunBilgi b WITH(NOLOCK) ON b.stkID = u.stkID AND b.Kat3ID IN (10,12,16)
WHERE u.urnTip = 0
GROUP BY u.alimIadeYok
ORDER BY COUNT(*) DESC;

/* ---------------------------------------------------------------------------
   6) HESAP HİJYENİ + GÜVENİLİR PENCERE (2026-08-18 kullanıcı teyidi)
   hakan.cetin = YAZILIMCI, alıcı DEĞİL → atıftan çıkar. Kanıtı: talebinin %96'sı
   Mayıs 2024'te 3 mağazaya birden (809 talep/24.354 adet), bir kayıt 'Deneme Amaçlı'.
   Devreye alma: 2024-03/04 tek kullanıcı · 2024-05 test yükü · 2024-08/09/10 KAYIT YOK
   · 2025-02'den itibaren istikrarlı (8-16 kullanıcı) → ATIF PENCERESİ >= 2025-02-01.
--------------------------------------------------------------------------- */
SELECT CONVERT(varchar(7), t.Tarih, 126) AS ay,
       COUNT(*)                                  AS talep,
       COUNT(DISTINCT t.EkleyenKullanici)        AS kullanici,
       SUM(t.SiparisMiktar)                      AS adet,
       SUM(CASE WHEN t.EkleyenKullanici = 'hakan.cetin' THEN 1 ELSE 0 END) AS hakan_talep
FROM DerinSISBkm.bkm.OneriSiparisTalep t WITH(NOLOCK)
GROUP BY CONVERT(varchar(7), t.Tarih, 126)
ORDER BY 1;

-- 7) Yazılımcı/test hesabının imzası: ay × mekan yoğunlaşması + açıklama
SELECT CONVERT(varchar(7), t.Tarih, 126) AS ay, t.MekanId,
       COUNT(*) AS talep, SUM(t.SiparisMiktar) AS adet, MAX(t.SiparisMiktar) AS max_tek,
       COUNT(DISTINCT t.Aciklama) AS farkli_aciklama, MIN(t.Aciklama) AS ornek_aciklama
FROM DerinSISBkm.bkm.OneriSiparisTalep t WITH(NOLOCK)
WHERE t.EkleyenKullanici = 'hakan.cetin'
GROUP BY CONVERT(varchar(7), t.Tarih, 126), t.MekanId
ORDER BY 1 DESC;

/* ---------------------------------------------------------------------------
   8) ŞUBE BENİMSEME ASİMETRİSİ (kullanıcı teyidi: ilk canlı test İST.YOLU, uzun süre tek kullanan)
   İST YOLU 82.202 talep (%70, 11 kullanıcı) · ÖZLÜCE 22.940 (%20) · FSM 12.376 (%10).
   2025-02 SONRASI da aynı oran (79.523/22.029/11.949) → kalıcı benimseme farkı.
   => ATIF ADALET KURALI: mutlak talep/adet sayısıyla alıcı kıyaslanAMAZ; yalnız ORAN/İSABET
      (talep başına isabet, fazla-oranı) kullanılır. Talep yokluğu karar yokluğu DEĞİLDİR.
--------------------------------------------------------------------------- */
SELECT t.MekanId, m.mekanAd,
       COUNT(*)                                AS talep,
       COUNT(DISTINCT t.EkleyenKullanici)       AS kullanici,
       CONVERT(varchar, MIN(t.Tarih), 104)      AS ilk_talep,
       CONVERT(varchar, MAX(t.Tarih), 104)      AS son_talep,
       SUM(CASE WHEN t.Tarih >= '20250201' THEN 1 ELSE 0 END) AS talep_2025_02_sonrasi
FROM DerinSISBkm.bkm.OneriSiparisTalep t WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.mekan_vw m WITH(NOLOCK) ON m.mekanID = t.MekanId
GROUP BY t.MekanId, m.mekanAd
ORDER BY COUNT(*) DESC;

/* ---------------------------------------------------------------------------
   9) İSİMLİ HESAP → ROL/ŞUBE EŞLEŞMESİ (kullanıcı teyidi 2026-08-18)
   eren.boran2 = İst.Yolu md yrd (29.253 talep, %99,5, 131 aktif gün) ·
   eren.boran = AYNI KİŞİ (778 talep, 6 gün → atıfta BİRLEŞTİR) ·
   sirac.yigit = Özlüce md yrd (441 talep 2 GÜNDE, yalnız 62 onaylı) ·
   seyda.cindan = Özlüce (15.231, %100, 52 gün) · omerfaruk.kirmaci = İst.Yolu (358, TEK gün).
   HARİÇ: hakan.cetin (yazılımcı) · kubra.kulaksizoglu (iç denetim/iş geliştirme).
   DERS: 'düşük onay = alıcı değil' hipotezi ÇÜRÜK (sirac md yrd ama %14 onay).
   DERS: metrik AKTİF GÜNE normalize edilmeli — 358 talep/1 gün ≠ 358 talep/131 gün.
--------------------------------------------------------------------------- */
SELECT t.EkleyenKullanici, t.MekanId, m.mekanAd,
       COUNT(*)                                              AS talep,
       SUM(CASE WHEN t.Onay = 1 THEN 1 ELSE 0 END)            AS onayli,
       COUNT(DISTINCT CONVERT(varchar(10), t.Tarih, 112))     AS farkli_gun,
       CONVERT(varchar, MIN(t.Tarih), 104)                    AS ilk,
       CONVERT(varchar, MAX(t.Tarih), 104)                    AS son
FROM DerinSISBkm.bkm.OneriSiparisTalep t WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.mekan_vw m WITH(NOLOCK) ON m.mekanID = t.MekanId
GROUP BY t.EkleyenKullanici, t.MekanId, m.mekanAd
ORDER BY COUNT(*) DESC;
