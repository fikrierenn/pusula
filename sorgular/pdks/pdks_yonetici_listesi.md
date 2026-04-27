# PDKS · Yönetici (Kart Basmayan) Kadro

**Son güncelleme:** 15 Nisan 2026

## Tespit

Vardiya planında var ama GecoTime `TPerInd` tablosunda TC eşleşmesi yok — çünkü **yönetici kadrosu kart basmıyor**, PDKS sisteminde bilerek tanımlı değiller. Plan-fiili karşılaştırmasında "gelmedi" olarak işaretlenmemeliler.

## Liste (15.04.2026 Çarşamba vardiyasından tespit)

| TC | Ad Soyad | Mağaza | Bölüm | Planlı Vardiya |
|---|---|---|---|---|
| 38275002344 | ENVER CAN | FSM | KÜLTÜR | 10:00-18:30 |
| 30721195334 | MEHMET KELEŞ | FSM | MAĞAZA | 10:00-18:30 |
| 59323266860 | MUHAMMED ENES KILIÇ | HEYKEL | MAĞAZA | 13:00-21:30 |
| 31787185550 | RECEP ÖZCAN | HEYKEL | MAĞAZA | 09:00-17:30 |
| 23959422174 | EREN BORAN | İST. YOLU | MAĞAZA | 13:30-22:00 |
| 52342013538 | ABDURRAHMAN UĞURLU | ÖZLÜCE | MAĞAZA | 11:00-23:00 |

## Panoya Yansıtma

Dashboard'ın `D` veri dizisinde bu TC'ler için **ayrı etiket** (`mazeret = 'YÖNETİCİ'`) konmalı; "gelmedi" listesinden çıkarılmalı. İleride genişleyebilir → kalıcı bir `bkm.YoneticiKadro (TC, Unvan, Aktif)` tablosu tutulması önerilir.

## Sorgulama

```sql
-- Vardiya planında var ama GecoTime'da yok (kart basmayan aday listesi)
SELECT DISTINCT vd.SicilNo AS TC, vd.Personel, s.SubeAd, vd.Bolum
FROM vrd.VardiyaDetay vd
INNER JOIN vrd.Vardiya v   ON v.VardiyaNo = vd.VardiyaNo
INNER JOIN vrd.SubeListe s ON s.SubeNo    = v.SubeNo
WHERE v.Tarih = CONVERT(datetime, '13.04.2026', 104)
  AND vd.SicilNo NOT IN (
    SELECT TC FROM OPENQUERY([PDKS], '
      SELECT PIn_SteuerNr AS TC FROM TPerInd WHERE PIn_SteuerNr IS NOT NULL
    ')
  );
```
