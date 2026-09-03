# Ölçtüm mü, Çıkardım mı — Her Sayının Arkasında Komut Olsun

> **Rule katmanı:** core (her oturum birincil). `paths:` yok — compact sonrası survive.
>
> Belinza deposundan (`D:\Dev\bel/.claude/rules/olctum-mu-cikardim-mi.md`) uyarlandı
> (03.09.2026). Orada Odoo/ETL vakalarından doğmuştu; buradaki vakalar BKM'nin kendi
> ölçülmüş hatalarıdır. Kural aynı, kanıt yerli.

## Ortak mekanizma

> Ölçümün yerine **makul bir çıkarım** koymak ve onu ölçümmüş gibi sunmak.

Bu sınıf sinsi: çıkarım yanlış olduğunda sonuç **saçma değil, makul** çıkar. Saçma
sayı fark edilir; makul sayı kabul edilir ve CFO kararına dayanak olur.

## BKM'de ölçülmüş vakalar

| İddia | Nasıl "biliniyordu" | Gerçek |
|---|---|---|
| `SalesProducts.BarcodeNo = urn.stkKod` ürünü eşler | `stkKod` "kod" adını taşıyor → barkod **sanıldı** | eşleşmiyor; Oyuncak cirosu 700K göründü, gerçek **10,96M** |
| `ehTip=1` alış (ADR-004) | bir kez yazılmış, kimse yeniden ölçmedi | 201 kanıt: `1` **satış**; alış `0` ve adet **pozitif** — tam tersi |
| Personel sayısı = bordro satırı | satır sayısı kişi sanıldı | ay içinde 1 gün çalışan da 1 sayılıyor: 211 kayıt = **168,9** tam gün karşılığı |
| Sezon = Temmuz–Ağustos | takvim sezgisi | ölçüm: Eyl **313,0M**, Ağu 186,9M → sezon Temmuz–**Ekim** |
| Dapper 8. kolon map ediliyor | 7 kolonda çalıştı → 8'de de çalışır **sanıldı** | `Alacak` sessizce **0**; hata yok, rakam yanlış |
| `OBJECT_DEFINITION('dbo.X')` NULL → şifreli | tek olasılık varsayıldı | obje `mhs` şemasındaydı; şifreli değildi |
| "MCP'de doğrulandı, app'te çalışır" | ölçüm kapsamı ≠ kod kapsamı | app `master` bağlamında; 2-parçalı isim Err 208 |

Yedi vakanın hiçbiri saçma sayı üretmedi. Hepsi makul görünüp karara girdi.

## Kural

**1. Her olgusal cümle etiketli olmalı.**

- **ÖLÇÜLDÜ** — yanında sorgu/komut ve sayı var.
- **ÇIKARIM** — ölçülmedi, benzer bir yerden türetildi. Bu etiket olmadan söylenmez.

Etiketleyemiyorsam cümleyi kurmam; önce ölçerim. Sunuma/rapora giren her rakam
ÖLÇÜLDÜ sınıfında olmak zorunda (bkz. `veri-dogrula` skill).

**2. Ölçümün KAPSAMI, kodun kapsamıyla aynı olmalı.**

En pahalı hata burada. Ölçüm doğru koştu ama süzgeç farklıydı:
- Denetim 3 POS mağazasını ölçtü, kadro 5 mağazayı sayıyordu.
- `DocumentsTypeId` filtresi raporda 1,2,3,6,7,8; doğrulamada yalnız 1.

Sınama: *"bu ölçümün süzgeci, koddaki süzgecin AYNISI mı?"*

**3. Liste elle yazılmaz.** Kolon listesi `sys.columns`tan, tablo listesi
`sys.tables`tan, kod kümesi `GROUP BY`dan gelir. Elle yazılan liste eksik olur ve
eksikliği ancak patlayınca (ya da hiç) görülür. Sema'ya liste değil **kural** yazılır
(`semantic-layer.md` § ŞEMA GERÇEĞİ ≠ SATIR VERİSİ).

**4. Kopyalanan desende gerekçe de kopyalanmaz.** `WHERE IsValid=1`, `urnTip=0`,
`COLLATE Turkish_CI_AS` üç sorguda doğruydu diye dördüncüde doğru değildir. Gerekçe
her hedefte yeniden kurulur (`before-major-change.md` § İlk Dokunuş).

## BULGUYU ölçüp KARARI tahmin etme

"Ertelendi / uygulanmaz / gerek yok" **bir karardır ve ölçüm ister**. Denetim
tablosunun geri kalanı ölçülü olduğu için, tahmin olan satır da ölçülü sanılır.
Gerekçesi ÖLÇÜLDÜ diye etiketlenemiyorsa erteleme değil, **açık soru** olarak yazılır
(TODO'da "teyit bekliyor" — ör. K-06 OYUN ALANI, norm tablosundaki 2 boş satır).

## İki yardımcı kural

**Sessizlik kanıt değil.** Bir ölçümün BOŞ dönmesi ile KOŞMAMASI ekranda aynı görünür.
ERP kesintisinde (10053) sorgular boş döndü; "veri yok" değil "ölçmedik" demekti.
`tools/sema_degismez.py` bu yüzden bağlanamazsa **patlar**, yeşil demez.

**Değeri gördüm, tarihini görmedim.** Bir ölçümün DEĞERİ kadar **ne zamanı** da
ölçümün parçasıdır. `irs.eTip=100` gün içinde yeniden yazılır → bugünün satırı ölçüm
sanılırsa rakam akşam değişir. Bordro son kapanan aya kadar gerçektir; ötesi tahmindir.

## Düzeltmeden sonra da ölç

Bir düzeltmenin **tuttuğu** ayrıca ölçülür. FTE'ye geçtikten sonra tutarlılık
kontrolüne `fte = prim_gun/30` ve `fte <= kayit_sayisi` kontrolleri eklendi; o
kontroller koşmasaydı sapma bir sonraki sunumda çıkardı.

## Sınır testi

> *"Bu cümlenin arkasında bir komut çıktısı var mı, yoksa 'olması gereken' mi?"*

İkincisiyse ya ölç, ya **ÇIKARIM** diye yaz.

## İlişkili
- `.claude/rules/before-major-change.md` § Fact-Force Gate — ilk dokunuş öncesi keşif.
- `.claude/rules/semantic-layer.md` § DEĞİŞMEZ — öğrenilen gerçek komutla yeniden koşar.
- `.claude/skills/veri-dogrula/SKILL.md` — bağımsız rakam mutabakatı.
- `sema/degismezler.json` · `tools/sema_degismez.py` — koşulan değişmezler.
