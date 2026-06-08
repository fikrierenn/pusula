# Muhasebe Modülü (DerinSIS `mhs`) — Çalışma Klasörü

> Bu klasör DerinSIS muhasebe modülünün **anlama + haritalama** çalışması.
> Hedef: BKM Kitap muhasebe akışını tablo bazında ortaya çıkarmak, iş
> kurallarını yazılı hale getirmek, gerektiğinde raporlama / kontrol
> sorgularına temel olacak referans haline getirmek.
>
> Kök doküman haritası: [`../00-INDEX.md`](../00-INDEX.md)

## Çalışma Sırası

| Sıra | Dosya | İçerik |
|---|---|---|
| 01 | [`01-mhsFis_sil-kaynak.sql`](./01-mhsFis_sil-kaynak.sql) | `mhs.mhsFis_sil` SP'sinin formatlı kaynağı |
| 02 | [`02-fis-silme-akisi.md`](./02-fis-silme-akisi.md) | Silme SP analizi: parametreler, akış, iş kuralları, açık sorular |
| 03 | [`03-mhs-CRUD-sp-kaynak.sql`](./03-mhs-CRUD-sp-kaynak.sql) | mhsFis_vw, mhsSonYevmiyeNo, mhsFisB_ekle, mhsFis_ekle, mhsFis_onay kaynakları |
| 04 | [`04-tablo-semasi.md`](./04-tablo-semasi.md) | 17 tablonun canlı şeması, FK haritası, enum lookup'ları, gerçek dağılımlar |
| 05 | [`05-CRUD-onay-akisi.md`](./05-CRUD-onay-akisi.md) | CRUD + onay analizi: signed convention, drn2 islem sözlüğü, tasarım gözlemleri |
| 06 | [`06-disaridan-fis-yazma-rehberi.md`](./06-disaridan-fis-yazma-rehberi.md) | Dış sistemden fiş kaydı: adım adım T-SQL, çalışan örnek, yaygın hatalar |
| 07 | [`07-mhs-objeleri.md`](./07-mhs-objeleri.md) | mhs schema'daki 92 objenin tam envanteri (CRUD/Workflow/Raporlama/Entegrasyon/Kontrol) |
| 08 | [`08-hesap-plani-gdr-merkez.md`](./08-hesap-plani-gdr-merkez.md) | TDHP, BKM hesap planı dağılımı, 32 gider merkezi, atanmamış %99 gözlemi |
| 09 | [`09-mhsFis_cikar-kaynak.sql`](./09-mhsFis_cikar-kaynak.sql) | mhsFis_cikar SP'sinin formatlı kaynağı |
| 10 | [`10-fis-cikar-analizi.md`](./10-fis-cikar-analizi.md) | mhsFis_cikar analizi: sil-vs-çıkar, idempotent re-entegrasyon, alt cari yakalama |
| 11 | [`11-mhsKapanis-kaynak.sql`](./11-mhsKapanis-kaynak.sql) | mhsKapanis SP'sinin formatlı kaynağı |
| 12 | [`12-yil-sonu-kapanis-analizi.md`](./12-yil-sonu-kapanis-analizi.md) | Yıl-sonu kapanış: islem=14, ters bakiye yöntemi, klasik TDHP zincirinin EKSİK olması, risk listesi |
| 13 | [`13-cariIsle_oto-kaynak.sql`](./13-cariIsle_oto-kaynak.sql) | cariIsle_oto SP'sinin formatlı kaynağı |
| 14 | [`14-cariIsle_oto-analizi.md`](./14-cariIsle_oto-analizi.md) | Günlük e-fatura → cari → mhs robot pipeline'ı; drn2ayar (920/154); cgTarih=bugün riski |
| 15 | [`15-drn2-audit-sozlugu.md`](./15-drn2-audit-sozlugu.md) | drn2 audit sözlüğü tam haritası, mhsSirket şirket-yıl mapping, encrypted SP listesi, yıl atlama pattern'ı |
| 16 | _planlanıyor_ — `16-mhsEnt_car-analizi.md` | Cari → mhs gerçek entegrasyon SP (cariIsle_oto'nun çağırdığı) |
| 17 | _planlanıyor_ — `17-veri-saglik-kontrolu.md` | 8 kontrol view'ının canlı çıktıları |

## Şu an netleşmiş çekirdek

- **Master:** `mhs.mhsFisBaslik` (15M satır, fisbID)
- **Detay:** `mhs.mhsFis` (39M satır, signed fisTutar — negatif=Borç, pozitif=Alacak)
- **Dönem:** `mhs.mhsSirket` — BKM'de **6 şirket = 6 mali yıl**, aktif sirketID=6 (2026)
- **Hesap Planı:** `mhs.mhsHsp` (24K, per-şirket); `mhs.mhsAnaHsp` (10 ana grup)
- **Arşiv:** `sil.mhsFis` (760K silinen fiş snapshot'ı)
- **Audit:** `dbo.drn2` (59M, izProgID=55 mhs, islem sözlüğü 2=Kaydet/3=Değiştir/4=Sil veya Çıkar/5=Onay/6=Onay kaldır/**14=Sistemli muhasebe operasyonu — Kapanış + Sıralama + Yıl başı açılış**, detay [`15-drn2-audit-sozlugu.md`](./docs/muhasebe/15-drn2-audit-sozlugu.md))
- **Entegrasyon hedefleri:** `dbo.fat`, `dbo.car`, `dbo.carNot`, `dbo.ith`,
  `dbo.posOzetMagazaGun`, `dbo.posOzetOdemeZ`
- **Lookup'lar:** `mhsEntTip` (6 satır: Kullanıcı/Fatura/Cari/POS/Mağaza Kasası/Cari Fiş),
  `mhsFisTip` (4 satır: Tahsil/Tediye/Mahsup/Yansıtma), `carTipF` (73 satır)

## Operasyonel Resim (BKM 2021-2026)

- fisEntTipID dağılımı: **%52 Cari (2)**, %44 Fatura (1), %0.15 POS (3),
  %0.01 Kullanıcı (0). EntTip 4 ve 5 hiç kullanılmamış (SP'de defansif kod).
- fisTip: virtually all **Mahsup (2)**. Tahsil/Tediye/Yansıtma neredeyse hiç.
- cFatTip top: 103=Kredi Kartı (13.2M), 1=Satış (6.7M), 100=Nakit (2.4M),
  122=Banka Ekstresi (804K).

## Sözleşmeler

- Tarih literal: DMY (`dd.MM.yyyy` / `CONVERT(..., 104)`) — `yyyy-MM-dd` YOK.
- DerinSIS field adı: `urn.stkAd` / `urn.stkID` (urnAd/urnID hata).
- Genel kurallar: [`../../.claude/rules/sql-server-conventions.md`](../../.claude/rules/sql-server-conventions.md)
