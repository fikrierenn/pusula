#!/usr/bin/env bash
# Post-commit journal hook â€” commit scope'una gore docs/journal/<proje>/YYYY-MM-DD.md'ye yazar.

set -e
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
  exit_code=$(echo "$input" | jq -r '.tool_response.exit_code // 1')
else
  cmd=$(echo "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  exit_code=$(echo "$input" | sed -n 's/.*"exit_code"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
  [ -z "$exit_code" ] && exit_code=1
fi

if ! echo "$cmd" | grep -qE '(^|[[:space:]&;])git[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi
[ "$exit_code" != "0" ] && exit 0

hash=$(git rev-parse --short HEAD 2>/dev/null || exit 0)
subject=$(git log -1 --format='%s' 2>/dev/null || exit 0)
files=$(git log -1 --name-only --format='' 2>/dev/null | grep -v '^$' | head -10)
file_count=$(echo "$files" | grep -c '.' || echo 0)

proj=$(echo "$subject" | sed -n 's/^[a-z]*(\([a-z_]*\)).*/\1/p')
case "$proj" in
  bkm|belinza|yonetiq) ;;
  *) proj="_crossproject" ;;
esac

today=$(date +%Y-%m-%d)
journal_dir="docs/journal/$proj"
journal="$journal_dir/$today.md"
mkdir -p "$journal_dir"

if [ ! -f "$journal" ]; then
  echo "# Oturum Gunlugu â€” $today ($proj)" > "$journal"
  echo "" >> "$journal"
fi

if ! grep -q '^## Commit'"'"'ler' "$journal"; then
  echo "" >> "$journal"
  echo "## Commit'ler" >> "$journal"
  echo "" >> "$journal"
fi

{
  echo "### \`$hash\` â€” $subject"
  echo ""
  echo "Dosyalar ($file_count):"
  echo "$files" | sed 's/^/- /'
  echo ""
} >> "$journal"

exit 0
