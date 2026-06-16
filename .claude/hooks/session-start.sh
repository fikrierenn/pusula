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

# Son journal girdisi (proje alt-dizini docs/journal/bkm/ — flat değil!)
if [ -d docs/journal ]; then
    last=$(ls -t docs/journal/bkm/*.md docs/journal/*.md 2>/dev/null | grep -v README | head -1)
    if [ -n "$last" ]; then
        echo "### En son journal girdisi — $last"
        tail -40 "$last"
        echo ""
    fi
fi

# Curator-check vadesi (plan-12 WS-1): son curator-check'ten >=7 gun gectiyse hatirlat
if [ -d docs/journal/bkm ]; then
    lastcur=$(grep -rh "curator-check:" docs/journal/bkm/*.md 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | tail -1)
    if [ -n "$lastcur" ]; then
        days=$(( ( $(date +%s) - $(date -d "$lastcur" +%s 2>/dev/null || echo 0) ) / 86400 ))
        if [ "$days" -ge 7 ] 2>/dev/null; then
            echo "### ⚠️ CURATOR-CHECK VADESI"
            echo "Son curator-check: $lastcur ($days gun once). Handoff'ta stale sema + TODO taramasi yap (>=7g)."
            echo ""
        fi
    fi
fi

# Curator hafif yuzey (her oturum): sema teyit-bekliyor + superseded duran kayit + son rapor
if [ -d sema ]; then
    teyit=$(grep -rl "status:.*teyit bekliyor\|status: teyit" sema/*.yaml 2>/dev/null | wc -l | tr -d ' ')
    sup=$(grep -rc "SÜPERSEDED\|süperseded" sema/*.yaml 2>/dev/null | grep -v ':0' | wc -l | tr -d ' ')
    if [ "$teyit" != "0" ] || [ "$sup" != "0" ]; then
        echo "### Curator yuzey (sema)"
        echo "- teyit-bekliyor kayit iceren dosya: $teyit · superseded-duran iceren dosya: $sup"
        lastrep=$(ls -t docs/curator/REPORT-*.md 2>/dev/null | head -1)
        [ -n "$lastrep" ] && echo "- son curator raporu: $lastrep"
        echo ""
    fi
fi

# Arsivlenmemis kesif SQL uyarisi (semantic-layer.md ikiz yukumluluk): bugun MCP kesif yapildiysa sorgular/ kontrol
echo "### Aktif disiplinler (mekanik + ben-uygular)"
echo "- Commit: 15-dosya esigi (yukarida) · pre-commit antipattern hook (guvenlik blok)"
echo "- Kesif SQL → sorgular/YYYY-MM-DD-*.sql ARSIVLE + sema/*.yaml yaz (semantic-layer ikiz yukumluluk)"
echo "- Musteri raporu = FIS bazli (DocType=1 sayim / (1,3) ciro; Fatura/Sinav haric)"
echo "- Yeni yetenek → footprint-ladder en dar basamak · Tier-3 → plan-first"
echo ""

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
