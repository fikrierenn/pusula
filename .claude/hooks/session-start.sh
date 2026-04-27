#!/usr/bin/env bash
# SessionStart hook â€” multi-project + oturum farkindaligi (ADR-002).
#
# v2 davranisi:
#   1. .claude/locks/<session-id>.lock yaratir (PID + started_at + last_activity)
#   2. Hook ciktisinin EN USTUNDE buyuk "SESSION ID" basligi -> Claude context'e isler
#   3. Aktif paralel oturum varsa uyarir
#   4. Stale lock cleanup (4h+ eski silinir)

set -e

REPO="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$REPO" 2>/dev/null || exit 0

PROJECT_NAME=$(basename "$REPO")

# ===== Lock + Session ID =====
LOCKS_DIR=".claude/locks"
mkdir -p "$LOCKS_DIR"

# Stale cleanup (4 saatten eski lock)
find "$LOCKS_DIR" -name "*.lock" -mmin +240 -delete 2>/dev/null || true

# Mevcut aktif oturumlari say (kendimiz haric)
ACTIVE_BEFORE=$(ls -1 "$LOCKS_DIR"/*.lock 2>/dev/null | wc -l | tr -d ' ')

# Yeni session ID
SESSION_ID="$(date +%Y%m%d-%H%M%S)-$(printf '%04x' $((RANDOM % 65536)))"
LOCK_FILE="$LOCKS_DIR/$SESSION_ID.lock"
NOW="$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)"

cat > "$LOCK_FILE" <<EOF
{
  "session_id": "$SESSION_ID",
  "started_at": "$NOW",
  "last_activity": "$NOW",
  "pid": $$,
  "cwd": "$REPO",
  "shell": "${SHELL:-unknown}",
  "user": "${USER:-${USERNAME:-unknown}}"
}
EOF

# .current dosyasi: SADECE bu shell process icin tracking. Paralel oturumda
# son acilan ustune yazar â€” bu ozellik ile NIYET edilmis (handoff fallback).
# Claude AYRICA hook ciktisinda gordugu SESSION_ID'yi kendi context'inde tutmali.
echo "$SESSION_ID" > "$LOCKS_DIR/.current"

# ===== Cikti =====

echo "## $PROJECT_NAME â€” Oturum Basi Ozet"
echo ""
echo "================================================================"
echo "  >>> BU OTURUMUN ID'SI: $SESSION_ID <<<"
echo "================================================================"
echo ""
echo "  CLAUDE talimatlari:"
echo "  - Bu ID'yi context'inde tut. Handoff'ta lock silmek icin lazim."
echo "  - /compact yaparsan ID'yi yeni context'e tasi."
echo "  - Handoff'ta: rm -f .claude/locks/$SESSION_ID.lock"
echo ""

# Paralel oturum uyarisi
if [ "$ACTIVE_BEFORE" -gt 0 ] 2>/dev/null; then
    echo "================================================================"
    echo "  UYARI: $ACTIVE_BEFORE PARALEL AKTIF OTURUM"
    echo "================================================================"
    echo "  Diger oturum(lar):"
    ls -1 "$LOCKS_DIR"/*.lock 2>/dev/null | grep -v "$SESSION_ID" | head -5 | while read -r lf; do
        oid=$(basename "$lf" .lock)
        ostarted=$(grep -o '"started_at":[^,]*' "$lf" 2>/dev/null | cut -d'"' -f4)
        echo "    - $oid (basladi: $ostarted)"
    done
    echo ""
    echo "  Disiplin (ADR-002):"
    echo "  - TODO.md veya ayni proje journal yazimi oncesi: git fetch && git status"
    echo "  - Conflict olasiligi varsa kullaniciya sor (overwrite/merge/iptal)"
    echo "  - Kendi journal'in farkli proje/dosyada ise sorun yok"
    echo ""
fi

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
                echo "#### $proj â€” $last"
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