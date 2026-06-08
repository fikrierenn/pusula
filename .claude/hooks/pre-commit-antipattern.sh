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

found_issues=()

for f in $staged; do
  [ -f "$f" ] || continue

  # Hardcoded password (tum stack'lerde)
  if echo "$f" | grep -qE '\.(cs|cshtml|json|ps1|ts|tsx|js|jsx|py|java|rb|go|rs|yml|yaml|env|ini|config|xml)$'; then
    if grep -HnE 'password[[:space:]]*[=:][[:space:]]*["'\''][A-Za-z0-9!@#$%^&*+._-]{4,}' "$f" 2>/dev/null | grep -viE 'password[[:space:]]*[=:][[:space:]]*["'\'']?(\s|$|;|"|'\''|\{|\$)' | head -3; then
      found_issues+=("$f: hardcoded sifre tespit (env var / secret manager kullan)")
    fi
  fi

  # .NET
  if echo ",$stacks," | grep -q ",dotnet," && [[ "$f" == *.cs ]]; then
    if grep -Hn 'DateTime\.Now\b' "$f" 2>/dev/null | grep -v '^\s*//' | head -3; then
      found_issues+=("$f: DateTime.Now -> DateTime.UtcNow kullan (timezone sorunu)")
    fi
    if grep -Hn 'async void\b' "$f" 2>/dev/null | grep -v 'event' | grep -v '^\s*//' | head -3; then
      found_issues+=("$f: async void (event handler harici yasak)")
    fi
    if grep -Hn 'new HttpClient()' "$f" 2>/dev/null | grep -v '^\s*//' | head -3; then
      found_issues+=("$f: new HttpClient() -> IHttpClientFactory")
    fi
    if grep -HnE '(TempData\[.*\]|ViewBag\.|Json\(\s*new\s*\{[^}]*message).*ex\.Message' "$f" 2>/dev/null | head -3; then
      found_issues+=("$f: ex.Message user'a sizintili (logger'a yaz, user'a generic mesaj)")
    fi
  fi

  # Node / TS
  if echo ",$stacks," | grep -q ",node," && echo "$f" | grep -qE '\.(ts|tsx|js|jsx|mjs|cjs)$'; then
    if grep -HnE 'console\.log\(' "$f" 2>/dev/null | grep -v '^\s*//' | head -3; then
      found_issues+=("$f: console.log production kod icinde (logger kullan)")
    fi
    if grep -HnE '(any[[:space:]]*[,;)=]|:[[:space:]]*any[[:space:]]*[,;)=])' "$f" 2>/dev/null | head -3; then
      found_issues+=("$f: 'any' kullanimi (strict tip ver)")
    fi
  fi

  # Python
  if echo ",$stacks," | grep -q ",python," && [[ "$f" == *.py ]]; then
    if grep -HnE 'print\(' "$f" 2>/dev/null | grep -v '^\s*#' | head -3; then
      found_issues+=("$f: print() production kod icinde (logging kullan)")
    fi
    if grep -HnE 'except[[:space:]]*:' "$f" 2>/dev/null | head -3; then
      found_issues+=("$f: bare except (yakalayacagin tipi belirt)")
    fi
  fi
done

if [ ${#found_issues[@]} -gt 0 ]; then
  echo "=== PRE-COMMIT ANTIPATTERN SCAN: BLOKLANDI ===" >&2
  for issue in "${found_issues[@]}"; do
    echo "  X $issue" >&2
  done
  echo "" >&2
  echo "Commit iptal edildi. Once issue'lari duzelt, sonra tekrar commit'le." >&2
  echo "Gecici bypass: CLAUDE_PRECOMMIT_SKIP=1 git commit ..." >&2
  echo "Kural guncellemek icin: .claude/hooks/pre-commit-antipattern.sh" >&2
  exit 2
fi

exit 0
