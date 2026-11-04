#!/usr/bin/env bash
# Fazla/hareketsiz stok çekimi (salt-okuma): 4 mekan × M parça → .cache/talep-tahmin-ortak/fazla-<mekan>.csv
set -u -o pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd); OUT=$ROOT/.cache/talep-tahmin-ortak; mkdir -p "$OUT"; cd "$ROOT"
SQL=$(grep -v '^\s*--' sorgular/06-operasyon/2026-10-14-fazla-hareketsiz-stok.sql); A=${A:-2025-10-13}; P=${P:-2024-10-14}; M=${M:-4}
for MK in ${MEKANLAR:-1 4477 4478 12}; do
  echo "stk,stok,son_hareket,son_gercek,son_satis,son_giris,satis52,satis52p,sevk52,sevk52p" > "$OUT/fazla-$MK.csv"
  for R in $(seq 0 $((M-1))); do
    sqlcli query --profile erp --read-only --format csv --max-rows 100000 --timeout 900 --retry 2 --param "MK=$MK" --param "M=$M" --param "R=$R" --param "A=$A" --param "P=$P" "$SQL" > "$OUT/q-$MK.tmp" 2>&1 \
      || { echo "KOŞAMADI $MK/$R"; head -3 "$OUT/q-$MK.tmp"; exit 2; }
    r=$(tail -n +3 "$OUT/q-$MK.tmp" | tee -a "$OUT/fazla-$MK.csv" | wc -l); echo "mekan $MK parça $R: $r"; [ "$r" -ge 99999 ] && { echo "SATIR SINIRI $MK/$R"; exit 2; }
  done; rm -f "$OUT/q-$MK.tmp"
done
wc -l "$OUT"/fazla-*.csv
