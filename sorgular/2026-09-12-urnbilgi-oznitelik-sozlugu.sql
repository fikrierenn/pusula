/* ============================================================================
   `dbo.urnBilgi` — ÜRÜN ÖZNİTELİK SÖZLÜĞÜ (EAV)                 2026-09-12
   DB: DerinSISBkm (profil: erp)

   Çıkış noktası: `ent.odakFiyatAktarim` içinde `urnBilgi` 220/228 bayraklarıyla
   ürün hariç tutuluyordu. Kullanıcı amacını bildirdi:
     "urnBilgi 228 ODAK'tan gelen fiyatlar baskın olmasın diye atılan bayrak"
   ve tanım tablosunun sema'ya işlenmesini istedi. İşte o sözlük.
   ============================================================================ */

/* ── 1) YAPI — üç tablo ─────────────────────────────────────────────────────── */
SELECT s.name+'.'+o.name AS tablo,
       MAX(CASE WHEN p.index_id IN (0,1) THEN p.rows END) AS satir,
       (SELECT COUNT(*) FROM DerinSISBkm.sys.columns c WHERE c.object_id=o.object_id) AS kolon
FROM   DerinSISBkm.sys.objects o JOIN DerinSISBkm.sys.schemas s ON s.schema_id=o.schema_id
JOIN   DerinSISBkm.sys.partitions p ON p.object_id=o.object_id
WHERE  o.name IN ('urnBilgi','urnBilgiTnm','urnBilgiGrp')
GROUP BY s.name,o.name,o.object_id;
/* dbo.urnBilgi     **10.433.109 satır** · 3 kolon (bVeriID · bBilgiID · bDeger)  ← EAV
   dbo.urnBilgiTnm          68 satır · 7 kolon  ← TANIM SÖZLÜĞÜ
   dbo.urnBilgiGrp           9 satır · 4 kolon  ← grup (grupID · grupAd · …)

   ⚠ `bDeger` **varchar** — boolean öznitelikler `'True'`/`'False'` METNİ taşır.
     `bDeger='True'` yazılır; `=1` ÇALIŞMAZ.
   ⚠ Bir öznitelik için hem True hem False satırı olabilir (220: 781 True + 744 False)
     ⇒ `bBilgiID=X` VARLIĞI yeterli değil, DEĞERİ de süzülür. */

/* ── 2) ★ TAM SÖZLÜK + CANLI KULLANIM ──────────────────────────────────────── */
SELECT t.BilgiID, t.BilgiAd, g.grupAd, t.bilgiKolonTip AS tip, t.bilgiZorunlu AS zor,
       ISNULL(k.satir,0) AS canli, k.ornek
FROM   DerinSISBkm.dbo.urnBilgiTnm t WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.urnBilgiGrp g WITH(NOLOCK) ON g.grupID = t.bilgiGrup
OUTER APPLY (SELECT COUNT_BIG(*) AS satir, MAX(b.bDeger) AS ornek
             FROM DerinSISBkm.dbo.urnBilgi b WITH(NOLOCK) WHERE b.bBilgiID = t.BilgiID) k
ORDER BY t.BilgiID;
/* ⚠ KOLON ADI TUZAĞI: grup tablosunun anahtarı `grupID`/`grupAd` (bilgiGrupID DEĞİL).
     İlk denemede tahmin edildi → Err 207. Önce `sys.columns` okunmalıydı.

   FİYAT/MARJ KARARINI DOĞRUDAN ETKİLEYENLER:
     **228 "Odak Alış Fiyat Güncellenmesin"  114.977 True**
          ⇒ odakFiyatAktarim bu üründe fTur=1 (Son Alış) satırını YAZMAZ.
            Kanonik maliyet yolu fytOzl fTur=1/fTip=1 olduğu için MALİYET BAYATLAR
            (ölçüldü: taze maliyet %24,9 vs bayraksız %35,6).
     220 "Odak Fiyat Güncellenmesin"           1.525 True  ⇒ aktarımın TAMAMEN dışında
     225 "Piyasa Marjı Değişmeyecek Ürün"        449 True  ⇒ web indirim oranı dondurulur
     205 "Takip Edilecek Rakip"               11.860 satır
     206 "Rakip Fiyat Takibi Yapılsın Mı"      5.124 True

   DİĞER İŞ KURALLARI:
     169 Stok Kontrolü Yok 541.994 · 204 Tsoft Stok Güncellemesin 99.121 ·
     168 Odak Stoğunu Sat 93.180 · 222 Mağaza Bulunurluk Takibi 59.126 ·
     234 Basım Yılı Gönderilmesin 51.299 · 224 Odak Sevkiyat Ürün 26.993 ·
     223 Kapıda Ödeme Yasakla 17.887 · 252 Sahaf Grup 4.239 · 11 Riskli Ürün 1.659 ·
     233 İstoç Ürünleri 1.467 · 226 Sınav Ürünü 700 · 221 Orjinal Set 265 ·
     227 Sınav Okul Teslim 260 · 229 Sepete Ek Ürün 103 · 230 Sıralama Dışı 67

   KİMLİK KÖPRÜLERİ EAV İÇİNDE SAKLI:
     173 "Tsoft Ürün ID" 753.953 · **174 "Odak Ürün ID" 647.776**

   KİTAP KÜNYESİ `urn`DE DEĞİL BURADA:
     175 Ürün Web Açıklama 659.610 · 189 Kağıt Cinsi 654.743 · 192 Basım Sayısı 654.479 ·
     190 Cilt Tipi 641.881 · 191 Sayfa Sayısı 622.357 · 193 Basım Yılı 570.914 ·
     194 Basım Ayı 293.416 · 181 Editör 124.588 · 183 Çevirmen 107.713 ·
     177 Ürün Alt Başlık 98.846 · 176 Orjinal Başlık 40.406

   TANIMLI AMA HİÇ KULLANILMAMIŞ (0 satır): 197 Görsel URL · 201 Raf Ömrü ·
     202 Kabul Edilebilir Raf Ömrü Yüzdesi · 231 "100 Temel Eser" ·
     250 Hazırlık Yeni Ürün StokId · 253 Öneri Sip. Ort. Gün Sayısı */

/* ── 3) ★★★ 205 "TAKİP EDİLECEK RAKİP" — İKİ RAKİP DE ÖLÜ ─────────────────── */
SELECT bDeger AS rakip, COUNT_BIG(*) AS urun
FROM   DerinSISBkm.dbo.urnBilgi WITH(NOLOCK)
WHERE  bBilgiID = 205 GROUP BY bDeger ORDER BY urun DESC;
/* "Fiyat Değişmeyecek"  5.423   ← rakip değil, DONDURMA değeri (alan çift amaçlı)
   **"Kitap Yurdu"       4.874**
   **"Kitap Seç"         1.563**
   ⚠⚠ İKİ GERÇEK RAKİBİN DE BESLEMESİ **2025-12-15'te DURDU**
     (bkz. `entities:rakip_fiyat_motoru_korlesmis` · `bkmdata.list_has_price` ölçümü)
   ⇒ Ürün bazında atanmış rakip takibi, işaret ettiği kaynağa ULAŞAMIYOR.
     6.437 ürün için "şu rakibi izle" yazılı ve o rakip artık gelmiyor. */

/* ── 4) 206 BAYRAĞI ile GERÇEK TAKİP LİSTESİ ARASINDAKİ FARK ───────────────── */
SELECT (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.urnBilgi WITH(NOLOCK)
        WHERE bBilgiID=206 AND bDeger='True')                      AS bayrak_206_true,
       (SELECT COUNT_BIG(*) FROM DerinSISBkm.ent.tsoft_rakip_takip) AS takip_listesi,
       (SELECT COUNT_BIG(*) FROM DerinSISBkm.dbo.urnBilgi WITH(NOLOCK)
        WHERE bBilgiID=205)                                         AS rakip_atanmis;
/* 5.124 · 3.701 · 11.860
   ⇒ **1.423 ürün takip için işaretli ama listede YOK.** Sebebi ÖLÇÜLMEDİ (açık soru). */

/* ── 5) 225 "PİYASA MARJI DEĞİŞMEYECEK" gerçekten donmuş mu ────────────────── */
SELECT COUNT_BIG(*) AS urun_225, COUNT(DISTINCT u.piyasaMarj) AS ayri_marj_degeri,
       CONVERT(decimal(10,1), AVG(CONVERT(decimal(10,2),u.piyasaMarj))) AS ort_marj
FROM   DerinSISBkm.dbo.urnBilgi b WITH(NOLOCK)
JOIN   DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = b.bVeriID
WHERE  b.bBilgiID = 225 AND b.bDeger = 'True';
/* 449 ürün · 11 ayrı marj değeri · ortalama %21,3
   ⇒ Bayrak "değişmeyecek" diyor ama ürünler farklı oranlarda DONDURULMUŞ — yani
     bayrak bir DEĞER dayatmıyor, yalnız GÜNCELLEMEYİ durduruyor. */

/* ============================================================================
   ÖZET — ÜÇ KATMANLI MANUEL MÜDAHALE SİSTEMİ
   ODAK otomasyonu fiyatı/maliyeti yazıyor; `urnBilgi` bayrakları ürün ürün
   İSTİSNA tanımlıyor:
     220 → fiyat aktarımı hiç çalışmasın        (1.525)
     228 → yalnız ALIŞ fiyatı güncellenmesin  (114.977)  ← maliyet bayatlamasının kaynağı
     225 → web indirim oranı dondurulsun          (449)
     205/206 → hangi rakip izlensin / izlensin mi (11.860 / 5.124)
   ⇒ Otomasyonun DAVRANIŞI bu bayraklar okunmadan anlaşılamaz; ve bayrakların
     bedeli (bayat maliyet) ölçülebiliyor.
   ============================================================================ */
