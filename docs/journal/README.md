# Oturum Günlükleri (Multi-Project)

Bu klasörde her çalışma gününün notu, **proje başına** ayrı klasörde:

```
journal/
├── bkm/                # BKM Kitap (DerinSIS, EncoreMerkez, JOKER e-ticaret)
├── yonetiq/            # YonetIQ (boş başlangıç)
└── _crossproject/      # MCP server kodu, infra, multi-proje işler
```

Dosya formatı: `YYYY-MM-DD.md`. Aynı gün ikinci oturum: dosyaya `## Oturum 2` bölümü append edilir.

## Neden burada?

CLAUDE.md'nin şişmesini önlemek için. Session journal'ı CLAUDE.md'de yaşamaz (bağlam anayasası § İlke 3).

## Nasıl yazılır?

`/handoff` skill'i otomatik üretir:
- Hangi projede çalışıldıysa o klasöre.
- Çoklu proje değiştiren oturum: her proje için ayrı dosya.
- Belirsizse `_crossproject/` veya kullanıcıya sor.

Manuel iskelet:

```markdown
# Oturum Günlüğü — YYYY-MM-DD (<proje>)

## Ana Konu
## Tamamlananlar
## Build / Test Durumu
## Commit Durumu
## Yarım Kalan
## Kararlar
## Konuşulan ek konular
## Dikkat Edilmesi Gerekenler
## Yarına Başlangıç Noktası
```

## Nasıl okunur?

SessionStart hook, oturum başında her projenin en son dosyasının son 25 satırını Claude'a enjekte eder. Ayrıca `grep -r "karar" docs/journal/bkm/` ile geçmiş arama yapılabilir.

## Ne zaman archive?

3 ay sonra `docs/journal/<proje>/archive/YYYY-QN/` altına taşı. SessionStart sadece en son dosyayı okur, eskiler arşivlenebilir.

## Cross-project oturum

Tek oturumda hem BKM raporu hem MCP server bug fix yapıldıysa:
- BKM raporu → `bkm/YYYY-MM-DD.md`
- MCP fix → `_crossproject/YYYY-MM-DD.md`

İkisi ayrı dosya, ayrı commit. Karışmasın.
