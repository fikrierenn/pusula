#!/usr/bin/env bash
# v5 stok hareketleri (salt-okuma) → $OUT/stokhareket.csv ; 2 haftalık parça; satır sınırına takılırsa ürün koduna göre 8'e böl; ilk hatada dur
set -u -o pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd); OUT=${OUT:-$ROOT/.cache/talep-tahmin}; cd "$ROOT"
SQL=$(grep -v '^\s*--' sorgular/06-operasyon/2026-10-13-talep-tahmin-stok-hareket.sql)
q(){ sqlcli query --profile erp --read-only --param "MK=${MEKAN:-1}" --format csv --max-rows 100000 --timeout 300 --retry 2 --param "A=$1" --param "B=$2" --param "M=$3" --param "R=$4" "$SQL" > "$OUT/q.tmp" 2>&1 || { echo "KOŞAMADI $1 M=$3 R=$4"; head -3 "$OUT/q.tmp"; exit 2; }; tail -n +3 "$OUT/q.tmp" | wc -l; }
END=${1:-2026-10-12}; echo "stk,w,q" > "$OUT/stokhareket.csv"; a=2021-05-31; n=0
while [[ "$a" < "$END" ]]; do
  b=$(date -d "$a + 14 days" +%F); [[ "$b" > "$END" ]] && b=$END
  r=$(q $a $b 1 0)
  if [ "$r" -ge 99999 ]; then
    for R in 0 1 2 3 4 5 6 7; do r2=$(q $a $b 8 $R); [ "$r2" -ge 99999 ] && { echo "SATIR SINIRI (8'e bölünce de) $a R=$R"; exit 2; }; tail -n +3 "$OUT/q.tmp" >> "$OUT/stokhareket.csv"; done
    echo "$a: 8 parçaya bölündü"
  else tail -n +3 "$OUT/q.tmp" >> "$OUT/stokhareket.csv"; fi
  n=$((n+1)); a=$b
done
rm -f "$OUT/q.tmp"; echo "parça=$n"; wc -l "$OUT/stokhareket.csv"
