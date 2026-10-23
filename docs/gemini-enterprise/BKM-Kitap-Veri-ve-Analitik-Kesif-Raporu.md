# BKM Kitap — GCP & Gemini Enterprise Ön Bilgi Notu

**Tarih:** 1 Ekim 2026

## 1. Mevcut Altyapı ve Veri Büyüklüğü

Operasyonel sistemlerimiz (ERP, POS, E-Ticaret, Depo Yönetimi) şirket içi (on-premise) **MS SQL Server** üzerinde çalışmaktadır.

| Başlık | Büyüklük / Hacim |
|---|---|
| **Analitik Veri Büyüklüğü (Yapısal)** | **100 – 150 GB** |
| **Günlük Veri Artışı** | **50 – 100 MB / gün** |
| **Kurumsal Doküman Hacmi** | **< 50 GB** (PDF, Word, Excel) |
| **Tarihsel Veri Derinliği** | **11 Yıl** (2014 – 2026) |
| **Ürün Kataloğu** | ~840.000 SKU |
| **Mağaza POS Satış Hareketleri** | ~7,8 milyon fiş · ~45,5 milyon satır (yıllık +1M fiş) |
| **E-Ticaret Sipariş Hacmi** | ~1,3 milyon sipariş / yıl |
| **ERP Stok Hareketleri** | ~60 milyon satır (yıllık +3–4M satır) |
| **Fatura / İrsaliye & Muhasebe** | ~41 milyon fatura satırı · ~40 milyon muhasebe satırı |
| **Fiyat Tarihçesi** | ~158 milyon satır |

## 2. Kullanıcı Büyüklüğü (Gemini Enterprise)

| Kullanıcı Grubu | Kişi Sayısı | Kullanım Amacı |
|---|---|---|
| **Yönetim ve Analitik Ekibi** | **10 – 15 kişi** | Doğal dilde veri sorgulama (NL→SQL), raporlama, derin analiz |
| **Saha / Mağaza Operasyon** *(2. Faz)* | **~200 kişi** | Prosedür arama, ürün ve stok bilgisi sorgulama |

## 3. Öncelikli Kullanım Senaryoları

1. **Talep Tahmini ve Sipariş Önerisi:** Ürün × mağaza × hafta bazında satış tahmini ve stok optimizasyonu.
2. **Doğal Dilde Veri Sorgulama (NL→SQL):** BigQuery ve Gemini Enterprise üzerinden yönetim ekibinin doğal dilde anlık rapor/veri sorgulaması.
3. **Kurumsal Bilgi Arama (RAG):** Şirket içi doküman ve prosedürlerin doğal dilde sorgulanması.
