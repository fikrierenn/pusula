#!/usr/bin/env bash
# Ürün özellikleri + bugünkü proc önerisi (salt-okuma) → $OUT/items.csv
set -u -o pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd); OUT=${OUT:-$ROOT/.cache/talep-tahmin}; mkdir -p "$OUT"; cd "$ROOT"
D=${1:-$(date +%F)}
SQL=$(grep -v '^\s*--' sorgular/06-operasyon/2026-10-13-talep-tahmin-urun.sql)
echo "stk,kat,fiyat,stok,mn,mx,oneri,m90,m360" > "$OUT/items.csv"
for P in 0 1; do
  sqlcli query --profile erp --read-only --format csv --max-rows 100000 --timeout 300 --retry 2 --param "D=$D" --param "P=$P" "$SQL" > "$OUT/q.tmp" 2>&1 || { echo "KOŞAMADI P=$P"; head -3 "$OUT/q.tmp"; exit 2; }
  r=$(tail -n +3 "$OUT/q.tmp" | tee -a "$OUT/items.csv" | wc -l); [ "$r" -ge 99999 ] && { echo "SATIR SINIRI P=$P ($r)"; exit 2; }
done
rm -f "$OUT/q.tmp"; echo "D=$D"; wc -l "$OUT/items.csv"
