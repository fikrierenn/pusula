#!/usr/bin/env bash
# .git/hooks izlenmez -> klonda hook yok. Bu script onu geri kurar.
# Kosum: bash tools/git-hook-kur.sh
set -e
cd "$(git rev-parse --show-toplevel)"
src=".claude/hooks/git-pre-commit-panel.sh"
[ -f "$src" ] || { echo "kaynak yok: $src"; exit 1; }
cp "$src" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
echo "kuruldu: .git/hooks/pre-commit  (bypass: PANEL_DENETIM_SKIP=1)"
