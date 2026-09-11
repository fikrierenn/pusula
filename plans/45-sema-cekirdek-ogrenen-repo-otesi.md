# Plan 45 — `sema` çekirdeği: öğrenen, repo-ötesi semantik katman

**Tarih:** 2026-09-11
**Proje:** `crossproject`
**Yazan:** Claude (oturum `2bc97e22`)
**Durum:** `Taslak — onay bekliyor`
**Önkoşul:** plan-44 (sözleşme + denetçi) F1-F2 tamam

---

## 1. Problem

İki ayrı problem, tek kök.

### 1a. Sema öğrenmiyor — biriktiriyor

Bugünkü döngü: bir gerçek keşfedilir → elle YAML'a yazılır → orada **durur**. Yaşlanma bir
bayraktır ama kimse bakmaz; `queries.yaml` doğrulanmış SQL saklar ama (2026-09-03'te koşucu
yazılana kadar) kimse koşturmazdı. Kayıt yazıldığı andan itibaren bozulmaya başlar ve
bozulduğunu **ancak yanlış rakam üretince** öğreniriz.

Ölçülmüş bedel (bu depo): `stkKod = barkod` varsayımı → Oyuncak cirosu 700K göründü, gerçek
10,96M. `ehTip=1 alış` (ADR-004) → gerçeğin tam tersi, 201 kanıtla düzeltildi.
`SaleDate` kolonu → yok, doğrusu `Date`; `entities.yaml` bunu **zaten yazmıştı**, katalog
sorgusu yine de bayat kaldı çünkü iki kayıt birbirini denetlemiyordu.

### 1b. Sema çatallandı — üç repo, üç ayrı şekil (ÖLÇÜLDÜ 2026-09-11)

| repo | dosyalar | koşucu | tek taraflı icat |
|---|---|---|---|
| `pusula` | bridges·codes·entities·metrics·**queries**·degismezler | `sema_degismez.py` · `sema_sorgu_dumani.py` · (bugün) `sema_denetim.py` · `sema_goc.py` | sözleşme · göç · sorgu kataloğu+dumanı |
| `bel` | bridges·codes·entities·metrics·degismezler + **`canli-degismezler.json`** | **yok** | `kardinalite` (bridges) · canlı-değişmez ayrımı |
| `fifo` | yalnız degismezler | yok | — |

`bel/sema/README.md` kendi ağzıyla: _"Pusula'daki mekanizmanın Belinza uyarlaması."_ Yani
**elle kopya**. bel'in `kardinalite` fikri pusula'ya, pusula'nın sözleşmesi bel'e gitmiyor.
Bu, `sqlcli`'de yaşanmış ve CLAUDE.md'ye yazılmış hatanın tekrarı
(`MIMBAL/tools/sqlcli` + `fifo/sqlcli` = drift olmuş fork'lar; README "kaynağı fork'lamayın" diyor).

38 repoda `.claude/` var; sema ihtiyacı üçte çıkmış durumda ve artacak.

## 2. Araştırma — neyden esinlenildi (2026-09-11)

| Kaynak | Alınan fikir | Bizdeki karşılığı |
|---|---|---|
| **GATE** — _Bootstrapping Semantic Layer from Execution for Text-to-SQL_ (arXiv 2606.05634) | Eksik anlamlandırma **yürütme geri beslemesinden** öğrenilir: birden çok hipotez tutulur, kısmî sorgu koşturulur, yalnız gözlemle tutarlı hipotez "execution-grounded memory"ye yazılır | **Yürütme temellendirmesi** — hipotez otomatik sınanır; elle `sqlcli lookup --count-from` yaptığımız şeyin döngüye bağlanmış hâli |
| **Zep / Graphiti** — temporal knowledge graph (arXiv 2501.13956) | **Bi-temporal**: her gerçek iki zaman ekseni taşır — `valid` (dünyada ne zaman doğruydu) ve `ingestion` (biz ne zaman öğrendik). Çelişen gerçek **silinmez, geçersizleştirilir** (t_invalid) | **Geçersizleştirme, silme değil** — `ehTip=1 alış` gibi çürüyen gerçek dursun ki aynı hataya ikinci kez düşülmesin |
| **A-MEM** — Agentic Memory (arXiv 2502.12110, NeurIPS'25) | Zettelkasten: **atomiklik + bağlam-güdümlü bağ + notların sürekli evrimi**. Yeni not gelince sistem ilgili eski notlara bağ kurar VE eskilerin bağlamını günceller. 6× çok-adımlı akıl yürütme, %85-93 daha az token | **Bağ evrimi** — "öğrendikçe öğrenen"in tam tanımı. Bizim `kullanir:` grafı + curator bunun elle hâli |
| **dbt 2026 benchmark** | Semantik katman doğruluğu 90,0→**98,2%** ve 84,1→**100%** (iki frontier model) | Yatırımın gerekçesi — bu iş kozmetik değil |
| **Cube semantic-layer-benchmark** | 4 KB semantik markdown **+17..23 puan**, eşleştirilmiş McNemar p<0,002 | Sema'nın BOYUTU değil KALİTESİ kazandırıyor |
| **Spider2-snow** | Ara semantik modelden geçirme → %94,15 yürütme doğruluğu | Sorgunun sema'dan geçmesi (bizde `queries.yaml`) |
| **power-platform-skills** (microsoft) | `shared/skills/` + `SKILL.template.md` + repo başına wrapper; path-filtreli CI; "sessiz no-op suite asla koşmaz" | Repo-ötesi dağıtım deseni + bizim exit-2 sözleşmemizin bağımsız doğrulaması |
| **sqlcli** (kendi deposu) | Tek kanonik motor + repo-yerel profil (`sqlcli.json`, `${ENV}`) + dört sözleşme | **Mimarinin birebir modeli** — tekerleği yeniden icat etmiyoruz, kendi kanıtlanmış desenimizi uyguluyoruz |

**Reddedilen esin:** Semantic Kernel / Microsoft Agent Framework (isim çakışması; SK
maintenance-only), dbt/Cube'u ürün olarak kurmak (dönüşüm motoru getiriyor, BKM'de dönüşüm
katmanı yok, `erp-write-policy` salt-okuma), vektör/embedding tabanlı sema arama (4.100 satır
prompt'a sığıyor — RAG sema 10× büyürse konuşulur).

## 3. Mimari

### 3.1 Üç katman — neyin nerede durduğu

| Katman | Nerede | Paylaşılır mı |
|---|---|---|
| **Çekirdek** — sözleşme şeması, koşucular, öğrenme döngüsü, CLI | `D:\Dev\sema` (tek kanonik depo) | **EVET** — tek kopya, sqlcli gibi |
| **Veri** — o repoya ait gerçekler | `<repo>/sema/*.yaml` | **HAYIR** — BKM ERP gerçeği Belinza'nın işi değil |
| **Profil** — hangi sunucu/DB/sürücü/adaptör | `<repo>/sema.json` (`${ENV}` yer tutucu) | **HAYIR** — repo-yerel |

Kimlik yalnız `.env`'den. `sqlcli.json` deseni birebir: karşılığı olmayan yer tutucu **hata
verir**, sessizce boş bağlanmaz.

### 3.2 Adaptör sınırı — sqlcli'nin öğrettiği hata YAPILMAYACAK

sqlcli'ye Odoo yeteneği **eklenmedi**, çünkü `ISqlDialect` dikişi SQL lehçeleri içindi ve
`search_read` oraya sokulursa soyutlama yalan söyler. Aynı disiplin:

> **Çekirdek SQL bilmez.** Çekirdek "bir iddiayı koştur, sonucu döndür" bilir.
> SQL'i `mssql` adaptörü, Odoo'yu `odoo` adaptörü bilir.

bel'in kaynağı Odoo, pusula'nınki MSSQL, fifo'nunki MSSQL. Adaptör arayüzü üç metot:
`baglan()` · `olc(iddia) -> sayi|satirlar` · `katalog(nesne) -> kolonlar`. Başkası yok.

### 3.3 Öğrenme döngüsü — dört sinyal, dördü de otomatik

```
        ┌──────────────────────── 4. KULLANIM ────────────────────────┐
        │  hangi kayıt okundu · hangi değişmez kırmızı verdi          │
        ▼                                                             │
   ┌─────────┐   1. YÜRÜTME      ┌──────────┐   2. BİTEMPORAL   ┌────┴─────┐
   │ hipotez │ ───────────────▶  │  gerçek  │ ────────────────▶ │ geçersiz │
   │ (aday)  │  canlı sınanır    │ (kayıtlı)│  çelişki çıkınca  │ (durur)  │
   └─────────┘  yalnız tutarlı   └────┬─────┘  silinmez         └──────────┘
                olan geçer             │
                                       │ 3. BAĞ EVRİMİ
                                       ▼
                            ilgili kayıtlara `kullanir:` bağı kurulur
                            + etkilenen kaydın bağlamı güncellenir
```

**1. Yürütme temellendirmesi (GATE).** `aday` durumundaki bir kayıt (`kanit_durumu:
teyit_bekliyor`) çekirdek tarafından canlı sınanır. Tutarsa `confidence` yükselir +
`last_verified` bugüne çekilir; tutmazsa **geçersizleştirilir**, silinmez. Hipotez elle değil,
kayıttaki `sinama:` alanından gelir (bir SQL/ölçüm ifadesi).

**2. Bi-temporal geçersizleştirme (Graphiti).** Her kayıt dört damga taşır:
`gecerli_bas`/`gecerli_bit` (dünyada ne zaman doğruydu) ve `ogrenildi`/`gecersizlendi` (biz ne
zaman öğrendik/çürüttük). `status: superseded` + `yerine: <yeni id>`. Bugün elle yaptığımız
"eskiyi düşür" işlemi mekanikleşir ve **tarih korunur** — `ehTip=1 alış` hatasının kendisi de
bir ders olarak sema'da kalır.

**3. Bağ evrimi (A-MEM).** Yeni kayıt yazılırken çekirdek: (a) metinde geçen mevcut id'leri
bulur → `kullanir:` önerir, (b) aynı tabloya/kavrama dokunan eski kayıtları bulur → çelişki
var mı diye sorar, (c) etkilenen kaydın `note`'unu güncellemeyi önerir. **Öneri — otomatik
yazma yok**, onay kullanıcıda (`consolidate-sema` dry-run deseni).

**4. Kullanım geri beslemesi.** Yerel `sema/.kullanim.jsonl` (git'te değil): hangi kayıt kaç
kez okundu, hangi değişmez kaç kez kırmızı verdi, hangi katalog sorgusu kaç kez koştu.
Türetilen: hiç okunmamış + hiç koşmamış kayıt → **arşiv adayı**; sık kırılan kayıt →
**inceleme adayı**; sık okunan kayıt → ttl kısalır (değerli olan taze tutulur).
Telemetri **yerel**, dışarı çıkmaz.

### 3.4 CLI yüzeyi

```
sema denetle                # sözleşme + referans bütünlüğü      (0/1/2)
sema kostur [--sadece id]   # değişmezler + katalog dumanı       (0/1/2)
sema ogren "<gerçek>"       # bağ evrimi + çelişki taraması → öneri, onayla yaz
sema temellendir <entity>   # canlı katalogdan kolon çek + drift
sema curator                # stale · hiç-kullanılmayan · çelişen → dry-run rapor
sema goc                    # eş-anlamlı alan katlaması (eşdeğerlik kapılı)
```

Dört sözleşme her komutta geçerli: tek kimlik yolu · izin-listesi salt-okuma guard ·
**çıkış 0/1/2** · görünür retry.

## 4. Alternatifler

### A: Her repo kendi kopyasını sürdürsün (bugünkü durum)
**Reddetme sebebi:** Çatallanma ÖLÇÜLDÜ ve bedeli somut — bel'in `kardinalite`'si ve
`canli-degismezler`'i pusula'ya gelmiyor, pusula'nın sözleşmesi bel'e gitmiyor. sqlcli'de aynı
şey yaşandı ve CLAUDE.md'ye "fork'lamayın" diye yazıldı. Aynı hatayı üçüncü kez yapmak.

### B: Sema'yı tek merkezî depoda BİRLEŞTİR (veri dahil)
**Reddetme sebebi:** BKM ERP gerçekleri ile Belinza/Odoo gerçekleri aynı dosyada durmaz —
kapsam karışır, "bu köprü hangi sistemde?" sorusu her okumada sorulur, üstelik erişim/gizlilik
sınırları farklı. Veri repo-yerel kalmalı; paylaşılan şey **motor**.

### C: Hazır ürün al (Graphiti/Zep · dbt · Cube · mem0)
**Reddetme sebebi:** Graphiti Neo4j + LLM çıkarım servisi ister (tek-kullanıcı/tek-makine için
ağır, `plans/12` §5 gerekçesiyle aynı); dbt/Cube dönüşüm motoru getirir; hiçbirinde
`confidence`+`evidence`+`olcum` ayrımımız ve "koşulan değişmez" mekanizmamız yok. **Fikirleri
al, ürünü alma** — zaten yaptığımız şey (README'deki dbt/Cube/Wren/Vanna esin listesi).

### D — SEÇİLEN: Tek kanonik motor (`D:\Dev\sema`) + repo-yerel veri/profil + adaptör sınırı
**Sebep:** sqlcli deseni bu depoda **kanıtlanmış**. Veri ayrı kalır (kapsam karışmaz), motor
tek kopya (kazanım herkese gider), adaptör sınırı yeni kaynağı (Odoo) soyutlamayı yalancı
yapmadan alır. Öğrenme döngüsü motorun içindedir — üç repo da aynı anda öğrenmeye başlar.

## 5. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Yeni depo = yeni bakım yükü; kimse bakmazsa üçüncü fork olur | yüksek | orta | sqlcli ile aynı kurulum yolu (global araç) + CLAUDE.md'ye "kanonik kopya" satırı + fork uyarısı. Üç repodan biri (pusula) referans tüketici |
| Otomatik öğrenme YANLIŞ gerçek yazar | **çok yüksek** | orta | **Otomatik YAZMA YOK.** Döngü öneri üretir, yazma onaya bağlı (`consolidate-sema` dry-run deseni). Yürütme temellendirmesi yalnız `confidence`/`last_verified` günceller — yeni gerçek İCAT ETMEZ |
| Bağ evrimi gürültü üretir (40 gömülü referansın hepsi anlamlı değil) | orta | yüksek | Eşik: yalnız id uzunluğu ≥8 + aynı dosya-içi kendine referans hariç. Öneri listesi, otomatik bağ değil |
| Kullanım telemetrisi gizlilik/gürültü | düşük | düşük | Yerel jsonl, `.gitignore`, dışarı çıkmaz, kapatılabilir |
| Adaptör soyutlaması sızar (SQL çekirdeğe kaçar) | yüksek | orta | Çekirdek testinde SQL string'i aranır — bulunursa KIRIK. sqlcli dersinin koşulabilir hâli |
| Göç sırasında üç repodan biri kırılır | orta | orta | Motor geriye-uyumlu okur (bugünkü şekli de kabul eder); repo başına ayrı göç, ayrı commit |

## 6. Fazlar

| Faz | İş | Done |
|---|---|---|
| **G0** | plan-44 F3-F6 bitir (referans grafı · canlı kolon · metrik semantiği · atomiklik) — motor bunların üstüne kurulur | `sema_denetim.py` KIRIK 0 |
| **G1** | `D:\Dev\sema` kur: çekirdek + `mssql` adaptörü + CLI. pusula'nın 4 aracı buraya taşınır, pusula onu çağırır | pusula'da `sema denetle`/`kostur` aynı sonucu veriyor (regresyon yok) |
| **G2** | bel + fifo motora bağlanır; bel'in `kardinalite` + `canli-degismezler` fikri çekirdeğe alınır | Üç repo aynı motoru koşuyor; bel'in kazanımı pusula'da da var |
| **G3** | Bi-temporal damga + geçersizleştirme (`status: superseded` + `yerine:` + 4 damga) | Çürüyen gerçek silinmiyor, tarihçesi okunabiliyor |
| **G4** | Yürütme temellendirmesi (`sinama:` alanı + otomatik teyit döngüsü) | `teyit_bekliyor` kayıtlar kendi kendine sınanıyor |
| **G5** | Bağ evrimi (`sema ogren` — çelişki taraması + bağ önerisi) | Yeni kayıt yazarken ilgili eskiler öneriliyor |
| **G6** | Kullanım geri beslemesi + curator entegrasyonu | Hiç-okunmayan/sık-kırılan kayıt raporlanıyor |
| **G7** | `odoo` adaptörü (bel) | bel'in değişmezleri motor üstünden koşuyor |

## 7. Done Criteria

- [ ] `D:\Dev\sema` kanonik; üç repo da oradan koşuyor, hiçbirinde kopya motor yok.
- [ ] Çekirdekte SQL string'i yok (adaptör sınırı koşulabilir testle korunuyor).
- [ ] Üç repoda `sema denetle` exit 0; herhangi biri bozulunca exit 1, bağlanamayınca exit 2.
- [ ] Otomatik yazma yok — her öğrenme çıktısı dry-run + onay.
- [ ] Geçersizleştirilen gerçek silinmiyor; `yerine:` zinciri izlenebiliyor.
- [ ] CLAUDE.md (üç repo) "kanonik kopya `D:\Dev\sema`, fork'lamayın" satırını taşıyor.
- [ ] Her fazın kırılabilirliği kanıtlandı (bilerek boz → kırmızı gör → geri al).

## 8. Rollback

Motor ayrı depo → repo'lar eski `tools/sema_*.py`'yi bir faz boyunca **yanında** tutar
(paralel koşum), motor yeşil verince eskisi silinir. Veri dosyalarına dokunulmuyor.
Geri dönüş = motoru çağırmayı bırakmak.

## 9. Kararlar (kullanıcı onayı 2026-09-11)

1. **Konum:** `D:\Dev\sema` — ONAYLANDI. sqlcli (`D:\Dev\sqlcli`) ile simetrik, aynı kurulum
   deseni (`dotnet pack` → `dotnet tool update -g`).
2. **Dil: .NET** — ONAYLANDI. İlk öneri Python'du (5 araç hazır), **değiştirildi.** Belirleyici
   olan tutarlılık değil, ÖLÇÜLMÜŞ bir hata oldu: `sema_kolon_cek.py` sqlcli'yi alt-süreç
   olarak çağırıp stdout'undan JSON ayıklıyor ve 2026-09-11'de sqlcli'nin ANSI renk kodundaki
   `[` karakteri JSON başlangıcı sanıldığı için patladı. **Bu hata dil sınırının semptomu.**
   .NET'te alt-süreç/stdout ayrıştırma/ANSI temizleme yok; sqlcli'nin profil + `${ENV}` +
   salt-okuma guard + retry kodu DOĞRUDAN paylaşılır → dört sözleşme iki dilde iki kez değil,
   tek yerde uygulanır.
   Python'un tek gerçek üstünlüğü sanılan Odoo/XML-RPC kolaylığı da geçersiz çıktı: Odoo
   `/jsonrpc` sunuyor, HttpClient + System.Text.Json yeter. İstatistik tarafı MathNet.Numerics
   (Wilson kapalı formül, Cochran-Armitage = ki-kare 1sd).
3. **Sıra: G0 önce** — plan-44 bitirilip motora taşınacak.

### Port kapısı (regresyon ölçülebilir olmalı)

| Sıra | Araç | Kapı |
|---|---|---|
| 1 | `denetim` · `goc` · `kolon_cek` | Bugün yazıldılar, kırılabilirlik kanıtları var → .NET sürümü AYNI kanıtları geçmeli (sahte referans → KIRIK, sözleşme gizli → KOŞAMADI, bozuk dönüştürücü → eşdeğerlik reddi) |
| 2 | `degismez` (43 kayıt) · `sorgu_dumani` (15 sorgu) | Python'da KALIR; .NET sürümü aynı veriyle **birebir aynı çıktıyı** verene kadar paralel koşar. Kapı: 43/43 ve 15/15 aynı sonuç. Eşleşince Python silinir |

Python araçlar bir faz boyunca yanında durur (§8 rollback).
