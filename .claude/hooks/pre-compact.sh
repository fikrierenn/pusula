#!/usr/bin/env bash
# PreCompact hook — /compact öncesi aktif TODO + son commitler journal'a eklenir.
# Bağlamdan önce ne üzerinde çalışıldığının snapshot'ı otomatik kaydedilir.
# Multi-project repo: journal docs/journal/bkm/ altına yazılır (varsayılan proje bkm).
# Tetik: settings.json PreCompact eventi. Operax pre-compact.sh'tan uyarlandı.

set -e
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

today=$(date +%Y-%m-%d)
journal="docs/journal/bkm/$today.md"
mkdir -p docs/journal/bkm

if [ ! -f "$journal" ]; then
  echo "# Oturum Günlüğü --- $today" > "$journal"
  echo "" >> "$journal"
fi

ts=$(date +%H:%M)

{
  echo ""
  echo "## Compact Snapshot --- $ts"
  echo ""
  echo "### Son 5 Commit"
  echo ""
  git log --oneline -5 2>/dev/null | sed 's/^/- /' || echo "- (git log başarısız)"
  echo ""
  echo "### Uncommitted Dosya Sayısı"
  echo ""
  count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "- $count uncommitted dosya"
  echo ""
  echo "### Aktif Planlar"
  echo ""
  for plan in plans/[0-9]*.md; do
    [ -f "$plan" ] && echo "- $(basename "$plan")"
  done
  echo ""
  echo "### Aktif TODO (ilk 15 açık madde)"
  echo ""
  if [ -f TODO.md ]; then
    grep '^\- \[ \]' TODO.md 2>/dev/null | head -15 | sed 's/^/- /' || echo "- (TODO.md okunamadı)"
  else
    echo "- (TODO.md yok)"
  fi
  echo ""
} >> "$journal"

exit 0
