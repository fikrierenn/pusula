#!/usr/bin/env bash
# SessionStart hook — Claude'a son durumu oturum basinda otomatik enjekte eder.

set -e

REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$REPO" 2>/dev/null || exit 0

PROJECT_NAME=$(basename "$REPO")

echo "## $PROJECT_NAME — Oturum Basi Ozet"
echo ""

echo "### Son 3 gun commit'ler"
git log --since='3 days ago' --oneline 2>/dev/null | head -10
echo ""

echo "### Uncommitted dosya sayisi"
count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "$count dosya"
if [ "$count" -gt 15 ] 2>/dev/null; then
    echo ""
    echo "UYARI: 15 dosya esigi asildi. Yeni is baslamadan once commit-split gerek."
fi
echo ""

if [ -f TODO.md ]; then
    echo "### Aktif TODO basliklari (ilk 20)"
    grep -E '^### |^- \[ \]|^## ' TODO.md 2>/dev/null | head -20
    echo ""
fi

# Son journal girdisi
if [ -d docs/journal ]; then
    last=$(ls -t docs/journal/*.md 2>/dev/null | grep -v README | head -1)
    if [ -n "$last" ]; then
        echo "### En son journal girdisi — $last"
        tail -40 "$last"
        echo ""
    fi
fi

echo "### Kritik dosyalar / kurallar"
[ -f docs/CONTEXT_MANAGEMENT.md ] && echo "- Baglam yonetimi: docs/CONTEXT_MANAGEMENT.md"
[ -f docs/00-INDEX.md ] && echo "- Konu indeksi: docs/00-INDEX.md"
[ -d .claude/rules ] && {
    for f in .claude/rules/session-protocol.md \
             .claude/rules/session-memory.md \
             .claude/rules/commit-discipline.md; do
        [ -f "$f" ] && echo "- $f"
    done
}

exit 0
