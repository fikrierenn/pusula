#!/usr/bin/env bash
# Pre-commit antipattern scan — Claude Code PreToolUse hook (generic).
#
# Tetikleyici: settings.json PreToolUse, matcher = "Bash".
# Script stdin'den JSON okur, yalnizca `git commit` komutlarinda staged
# dosyalari tarar. Projeye bagimli degildir; stack pattern'leri env ile
# acilip kapanabilir.
#
# Cikis kodlari:
#   0 -> commit devam etsin (check passed veya git commit komutu degil)
#   2 -> commit BLOKLA (antipattern bulundu, stderr mesaji user'a gider)
#
# Bu hook iki farkli amaca birden hizmet ederse kontrol guc olur; her stack
# icin ayri bir hook dosyasi tercih edilebilir. Bu script genel tarama
# icin bir baslangic noktasidir — gercek projede kurallari kendi stack'ine
# gore adapte et.
#
# Env override (opsiyonel):
#   CLAUDE_PRECOMMIT_SKIP=1  -> hic tarama yapmadan cik
#   CLAUDE_PRECOMMIT_STACKS="dotnet,node,python"  -> hangi stack tarayicilari
#                                                    aktif (default: hepsi)

set -e

[ "${CLAUDE_PRECOMMIT_SKIP:-0}" = "1" ] && exit 0

cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
else
  cmd=$(echo "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# Sadece `git commit` komutlari
if ! echo "$cmd" | grep -qE '(^|[[:space:]&;])git[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

staged=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
[ -z "$staged" ] && exit 0

# Hangi stack taramalarini acalim
stacks="${CLAUDE_PRECOMMIT_STACKS:-dotnet,node,python,generic}"

# BKM adaptasyonu (16.06): BLOK = guvenlik/korelasyon (sifre, ex.Message sizinti, bare except, async void).
# UYAR (bloklamaz) = stil (DateTime.Now=yerel display kasitli, print()=CLI script legit, console.log, any).
block_issues=()
warn_issues=()

for f in $staged; do
  [ -f "$f" ] || continue

  # Hardcoded password — BLOK (tum stack)
  if echo "$f" | grep -qE '\.(cs|cshtml|json|ps1|ts|tsx|js|jsx|py|java|rb|go|rs|yml|yaml|env|ini|config|xml)$'; then
    if grep -E 'password[[:space:]]*[=:][[:space:]]*["'"'"'][A-Za-z0-9!@#$%^&*+._-]{4,}' "$f" 2>/dev/null \
       | grep -qviE 'password[[:space:]]*[=:][[:space:]]*["'"'"']?(\s|$|;|"|'"'"'|\{|\$)'; then
      block_issues+=("$f: hardcoded sifre (env var / secret manager kullan)")
    fi
  fi

  # .NET
  if echo ",$stacks," | grep -q ",dotnet," && [[ "$f" == *.cs ]]; then
    # grep -q ile son komut kuralı: eşleşme varsa exit 0 (true), yoksa exit 1 (false)
    if grep -E 'async void\b' "$f" 2>/dev/null | grep -v 'event' | grep -qv '^\s*//'; then
      block_issues+=("$f: async void (event handler harici yasak)")
    fi
    if grep 'new HttpClient()' "$f" 2>/dev/null | grep -qv '^\s*//'; then
      block_issues+=("$f: new HttpClient() -> IHttpClientFactory")
    fi
    if grep -E '(TempData\[.*\]|ViewBag\.|Json\(\s*new\s*\{[^}]*message).*ex\.Message' "$f" 2>/dev/null | grep -q .; then
      block_issues+=("$f: ex.Message user'a sizintili (logger'a yaz, generic mesaj)")
    fi
    # DateTime.Now → UYAR (BKM tek-TZ yerel display kasitli; UtcNow tercih ama bloklamaz)
    if grep -E 'DateTime\.Now\b' "$f" 2>/dev/null | grep -qv '^\s*//'; then
      warn_issues+=("$f: DateTime.Now (yerel display ise OK; persist/hesap ise UtcNow)")
    fi
  fi

  # Python — bare except BLOK (error-handling.md), print() UYAR (CLI script legit)
  if echo ",$stacks," | grep -q ",python," && [[ "$f" == *.py ]]; then
    if grep -qE 'except[[:space:]]*:' "$f" 2>/dev/null; then
      block_issues+=("$f: bare 'except:' (yakalanan tipi belirt — sessiz hata yasak)")
    fi
  fi
done

# ── PANEL KOLON/KAYIT DENETIMI (derleyicinin gormedigi iki sessiz hata sinifi) ──
# Tetik: Satis Analizi katmaninda degisiklik staged ise. Bu denetim ELLE kosulmaz
# diye hook'a baglandi: (A) Dapper pozisyonel record sirasi, (B) kolon anahtari
# catallanmasi. Ikisi de 10.09.2026'da IKI KEZ oldu ve build yesil kaldi.
# Ayrinti: tools/panel_kolon_denetimi.py basligi.
# Tetik GENIS: 'SatisAnalizi' ile baslayan her dosya. Eski desen
# (Queries|Models|Hucre|Tablo) SatisAnaliziTabanService.cs ve SatisAnalizi.razor'u
# KACIRIYORDU -> tabana kolon eklenen commit denetimsiz geciyordu (10.09.2026 bulgusu).
# GENISLETILDI 19.09.2026: 'Vardiya|Vrd' eklendi. VrdSatir 27 alanli pozisyonel
# record ve denetim cifti 19.09'da eklendi; tetik yalniz 'SatisAnalizi' kalsaydi
# vardiya dosyasina kolon eklenen commit denetimsiz gecerdi -- kapinin kendisi
# kurulu ama CAGRILMIYOR olurdu (test-discipline: yazili kural != uygulanan kural).
if echo "$staged" | grep -qE 'SatisAnalizi|Vardiya|Vrd'; then
  if command -v python >/dev/null 2>&1 && [ -f tools/panel_kolon_denetimi.py ]; then
    if ! kolon_out=$(python tools/panel_kolon_denetimi.py 2>&1); then
      echo "=== PANEL KOLON DENETIMI: BLOKLANDI ===" >&2
      echo "$kolon_out" | grep -E '^(KIRIK|KOSAMADI)' >&2
      echo "" >&2
      echo "Dapper pozisyonel sira ya da kolon anahtari catallanmasi var." >&2
      echo "Ikisi de SESSIZ hata uretir: bos kolon veya kaymis deger." >&2
      echo "Gecici bypass: CLAUDE_PRECOMMIT_SKIP=1 git commit ..." >&2
      exit 2
    fi
  else
    warn_issues+=("panel kolon denetimi KOSMADI (python ya da script yok) - sessizlik kanit degil")
  fi
fi

# ── MESAI ESIGI CATALLANMA DENETIMI (C# <-> Python) ──────────────────────────
# Tetik: mesai esigi tasiyan iki kaynaktan biri staged ise. Ayni esikler iki dilde
# iki kopya halinde yasiyor; kod bir yorumla "ayni olmali" diyordu ama yorum kapi
# degildir. Sapma SESSIZDIR: panel ile Python kapisi farkli sayi uretir ve ikisi de
# kendi icinde tutarli gorunur. Ayrinti: tools/mesai_esik_denetimi.py basligi.
if echo "$staged" | grep -qE 'VrdSabit|mesai_mevzuat_kapisi|VardiyaQueries'; then
  if command -v python >/dev/null 2>&1 && [ -f tools/mesai_esik_denetimi.py ]; then
    if ! esik_out=$(python tools/mesai_esik_denetimi.py 2>&1); then
      echo "=== MESAI ESIGI DENETIMI: BLOKLANDI ===" >&2
      echo "$esik_out" | grep -E '^(KIRIK|KOSAMADI)' >&2
      echo "" >&2
      echo "Mevzuat esigi C# ve Python arasinda catallanmis: biri bayatlamis." >&2
      echo "Gecici bypass: CLAUDE_PRECOMMIT_SKIP=1 git commit ..." >&2
      exit 2
    fi
  else
    warn_issues+=("mesai esik denetimi KOSMADI (python ya da script yok) - sessizlik kanit degil")
  fi
fi


# ── TODO KAPISI (madde sessizce kaybolmasin) ─────────────────────────────────
# NEDEN: 19.09.2026'da TODO duzenlemesi V-02..V-05'i BIRLIKTE SILDI ve hicbir sey
# uyarmadi. Silinen madde ekranda YOKTUR, yani "yapilmis" gibi gorunur; acik borc
# kapanmis borctan ayirt edilemez hale gelir. Iki commit sonra "V-05 yap" denince
# madde BULUNAMADI. Ayrinti: tools/todo_denetimi.py basligi (yakalama sozlesmesi).
#
# TETIK GENIS: TODO.md staged ISE degil, HER commit'te kosar -- cunku madde kaybi
# TODO.md'yi degistiren commit'te olur ve o commit zaten TODO.md'yi stage ediyordur;
# ama bir birlestirme/kismi stage durumunda kayip baska bir commit'e sizabilir.
if command -v python >/dev/null 2>&1 && [ -f tools/todo_denetimi.py ]; then
  if ! todo_out=$(python tools/todo_denetimi.py 2>&1); then
    echo "=== TODO KAPISI: BLOKLANDI ===" >&2
    echo "$todo_out" | grep -E '^(KIRIK|KOSAMADI|KOŞAMADI)' >&2
    echo "" >&2
    echo "Madde SILINMEZ: bittiyse [x], gereksizse ARSIV'e tasinir." >&2
    echo "Gecici bypass: CLAUDE_PRECOMMIT_SKIP=1 git commit ..." >&2
    exit 2
  fi
else
  warn_issues+=("TODO kapisi KOSMADI (python ya da script yok) - sessizlik kanit degil")
fi

# ── TURKCE TANIMLAYICI KAPISI (kod Ingilizce, UI/yorum Turkce) ───────────────
# Tetik: vardiya-app / lib / tests altinda staged .cs veya .cshtml varsa.
# NEDEN: 19.09.2026'da GMY DORT KEZ ayni seyi soylemek zorunda kaldi ("hala
# turkce isim kullaniyorsun"). Kural yaziliydi ve okunmustu; cigneyeni goren
# yoktu. Ayrinti: tools/turkce_tanimlayici_denetimi.py basligi (yakalama sozlesmesi).
if echo "$staged" | grep -qE '^(vardiya-app|lib/Bkm\.Shared|tests)/.*\.(cs|cshtml)$'; then
  if command -v python >/dev/null 2>&1 && [ -f tools/turkce_tanimlayici_denetimi.py ]; then
    if ! tr_out=$(python tools/turkce_tanimlayici_denetimi.py 2>&1); then
      echo "=== TURKCE TANIMLAYICI: BLOKLANDI ===" >&2
      echo "$tr_out" | grep -E '^(KIRIK|KOSAMADI)| satir ' >&2
      echo "" >&2
      echo "Kod Ingilizce olmali (turkish-ui.md). Yorum ve UI metni Turkce KALIR." >&2
      echo "Gecici bypass: CLAUDE_PRECOMMIT_SKIP=1 git commit ..." >&2
      exit 2
    fi
  else
    warn_issues+=("turkce tanimlayici denetimi KOSMADI - sessizlik kanit degil")
  fi
fi

# UYARILAR (bloklamaz)
if [ ${#warn_issues[@]} -gt 0 ]; then
  echo "=== PRE-COMMIT UYARI (bloklamaz) ===" >&2
  for w in "${warn_issues[@]}"; do echo "  ! $w" >&2; done
fi

# BLOKLAR
if [ ${#block_issues[@]} -gt 0 ]; then
  echo "=== PRE-COMMIT ANTIPATTERN: BLOKLANDI ===" >&2
  for issue in "${block_issues[@]}"; do echo "  X $issue" >&2; done
  echo "" >&2
  echo "Commit iptal. Once duzelt. Gecici bypass: CLAUDE_PRECOMMIT_SKIP=1 git commit ..." >&2
  exit 2
fi

exit 0
