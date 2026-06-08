# Dosya Boyutu Disiplini

## Kural

**Yeni yazılan/düzenlenen dosyalar 300 satırın altında kalmalı.**
**500 satır kırmızı çizgi — bir sonraki PR'da split zorunlu.**

Tip bazlı yumuşak hedefler (300'den daha sıkı olanlar):

| Dosya tipi | Hedef |
|------------|-------|
| API route / Controller action | 200 satır |
| Util / helper | 150 satır |

Migration, JSON config, generated code ve büyük prompt sabitleri istisna — gerekçe dosya başına yorum olarak yazılır.

## Neden

Tek dosyada iç içe 5+ feature → merge conflict, test zorluğu, yeni geliştirici onboarding yükü, AI agent okurken context tüketimi. Solo dev için bile context switch maliyeti.

## Uygulama

- **Yeni dosya:** Şüpheliysen önce parçala, sonra yaz.
- **Mevcut büyük dosya (legacy):** TODO backlog'a + "Known debt" notu + faz planla. Touch ettikçe azalt — yeni satır eklerken ilgisiz 30 satırı çıkar/böl.
- **Touch kuralı:** Dokunduğun büyük dosyada **en az** çevre 50 satır iyileşmesi yapılabiliyorsa yap (kullanıcı onayıyla). Yapamıyorsan TODO'ya not düş.

## Bölme Stratejileri

**Component / View:**
- Alt component çıkar (tekrar kullanılmasa bile okunabilirlik için)
- State mantığını `useFeatureName.ts` custom hook'a taşı
- Type/constants ayrı dosya (`*.types.ts`, `*.constants.ts`)

**Servis / İş Mantığı:**
- Tek sorumluluk başına dosya (örn: `userService.ts` → `userQueries.ts` + `userMutations.ts` + `userValidation.ts`)
- Pure fonksiyonları utils'e çıkar
- Class büyükse composition pattern

**API Route / Controller:**
- Handler logic'i servise taşı — route sadece auth + validation + response
- Validation şemalarını ayrı dosyaya

## Periyodik Tarama

```bash
# 300+ satır dosyalar, sıralı
find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.cs" -o -name "*.py" \) \
  -not -path "./node_modules/*" -not -path "./.next/*" -not -path "./bin/*" -not -path "./obj/*" \
  -exec wc -l {} \; | awk '$1 > 300' | sort -rn | head -20
```

Çıktıdaki dosyalar `TODO.md` backlog'una düşer. 500+ olanlar **kırmızı çizgi** — sonraki PR'da split.

## Snapshot (Mevcut Büyük Dosyalar)

> Bu bölümü her proje kendi durumuna göre günceller. Touch edilince güncelle.

- (proje başına doldurulur)

## Anti-Pattern

- ❌ "Zaten 800 satır, sorun değil" → bir satır daha ekle
- ❌ Plan yapmadan dosyayı parçala → referans kırılır
- ❌ Drive-by refactor — kullanıcı istemediği halde 5 dosya böl
- ❌ "İlerde bölerim" → TODO'ya yazmazsan kaybolur
