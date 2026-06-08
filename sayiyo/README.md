# Kapı Sayıcı (Mağaza Trafiği) — Veri

Kapı sayıcı sisteminin export'u. **G8 Dönüşüm Oranı** raporunun trafik kaynağı.

## Dosyalar
- `sayiyo_*.xlsx` — ham export (geniş format: her tarih 6 kolon — Giriş/Mağaza Önü Trafiği/Fiş/Dönüşüm/Gidiş/Dönüş). Sistem POS'a bağlı değil → Fiş/Dönüşüm kolonları 0.
- `fsm_gunluk_trafik.csv` — tidy (Tarih ISO, Giriş). xlsx'ten parse edildi.

## Kapsam
- **Sadece FSM** (Bursa Nilüfer FSM) — tek kapı sayıcı kurulu. Özlüce + İst.Yolu bekliyor (B-22).
- Dönem: 08.04.2026 → güncel (günlük).

## Kullanım
```
python scripts/donusum_orani.py
```
Trafik CSV (Giriş) + EncoreMerkez POS (Fiş/Ciro) → günlük Dönüşüm % + ₺/ziyaret.
Doğrulama: 02-08.06 hafta %51,0 (dashboard 10.738 giriş ile birebir).

## Yeni export geldiğinde
1. Yeni `.xlsx`'i bu klasöre koy.
2. Tidy CSV'yi yenile (parse: FSM satırı → Tarih,Giriş).
3. `donusum_orani.py` çalıştır.

## Uzun vade (B-22)
Trafiği SQL tabloya yükle (`bkm.MagazaTrafik`: tarih, mekanID, giris) → dönüşüm native SQL join, günlük brief'e KPI kolonu.
