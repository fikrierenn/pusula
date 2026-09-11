#!/usr/bin/env bash
# BKM yerel git pre-commit — panel kolon/kayit denetimi.
# Kurulum: bash tools/git-hook-kur.sh   (.git/hooks izlenmez, klonda yeniden kurulur)
# Cikis: 0 gecti · 2 BLOK (KIRIK ya da KOSAMADI). Bypass: PANEL_DENETIM_SKIP=1
set -e
[ "${PANEL_DENETIM_SKIP:-0}" = "1" ] && exit 0
cd "$(git rev-parse --show-toplevel)"
staged=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
echo "$staged" | grep -qE 'SatisAnalizi' || exit 0
if ! command -v python >/dev/null 2>&1; then
  echo "! panel kolon denetimi KOSMADI (python yok) — sessizlik kanit degil" >&2
  exit 0
fi
if [ ! -f tools/panel_kolon_denetimi.py ]; then
  echo "! panel kolon denetimi KOSMADI (script yok)" >&2
  exit 0
fi
if ! out=$(python tools/panel_kolon_denetimi.py 2>&1); then
  echo "=== PANEL KOLON DENETIMI: COMMIT BLOKLANDI ===" >&2
  echo "$out" | grep -E '^(KIRIK|KOSAMADI)' >&2
  echo "Dapper pozisyonel sira ya da kolon anahtari catallanmasi — SESSIZ hata sinifi." >&2
  echo "Bypass: PANEL_DENETIM_SKIP=1 git commit ..." >&2
  exit 2
fi
exit 0
