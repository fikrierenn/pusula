#!/usr/bin/env bash
# SessionStart hook Ã¢â‚¬â€ multi-project son journal'lari enjekte eder.

set -e

REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$REPO" 2>/dev/null || exit 0

PROJECT_NAME=$(basename "$REPO")

echo "## $PROJECT_NAME Ã¢â‚¬â€ Oturum Basi Ozet"
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

if [ -d docs/journal ]; then
    echo "### Tum projelerin son journal girdisi"
    echo ""
    for proj in bkm belinza yonetiq _crossproject; do
        proj_dir="docs/journal/$proj"
        if [ -d "$proj_dir" ]; then
            last=$(ls -t "$proj_dir"/*.md 2>/dev/null | grep -v README | grep -v '_archive' | head -1)
            if [ -n "$last" ]; then
                echo "#### $proj Ã¢â‚¬â€ $last"
                tail -25 "$last"
                echo ""
            fi
        fi
    done
fi

echo "### Kritik dosyalar / kurallar"
[ -f docs/CONTEXT_MANAGEMENT.md ] && echo "- Baglam yonetimi: docs/CONTEXT_MANAGEMENT.md"
[ -f docs/00-INDEX.md ] && echo "- Konu indeksi: docs/00-INDEX.md"
[ -d .claude/rules ] && {
    for f in .claude/rules/session-protocol.md \
             .claude/rules/session-memory.md \
             .claude/rules/commit-discipline.md \
             .claude/rules/sql-server-conventions.md; do
        [ -f "$f" ] && echo "- $f"
    done
}

exit 0
