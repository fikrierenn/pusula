#!/usr/bin/env bash
# Sipariş backtest karar günleri (4 haftada bir Pazartesi; hafta indeksi w → 2021-06-07 + 7w) → $OUT/durum.csv (D,w,...)
set -u -o pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd); OUT=${OUT:-$ROOT/.cache/talep-tahmin}; cd "$ROOT"
SQL=$(grep -v '^\s*--' sorgular/06-operasyon/2026-10-13-siparis-backtest-durum.sql)
echo "w,stk,stok,bakiye,mn,mx,oneri,fiyat" > "$OUT/durum.csv"
for w in $(seq ${1:-188} 4 ${2:-274}); do
  D=$(date -d "2021-06-07 + $((7*w)) days" +%F)
  sqlcli query --profile erp --read-only --format csv --max-rows 100000 --timeout 300 --retry 2 --param "D=$D" "$SQL" > "$OUT/q.tmp" 2>&1 || { echo "KOŞAMADI $D"; head -3 "$OUT/q.tmp"; exit 2; }
  r=$(tail -n +3 "$OUT/q.tmp" | sed "s/^/$w,/" | tee -a "$OUT/durum.csv" | wc -l); [ "$r" -ge 99999 ] && { echo "SATIR SINIRI $D"; exit 2; }
  echo "w=$w D=$D satır=$r"
done
rm -f "$OUT/q.tmp"; wc -l "$OUT/durum.csv"
