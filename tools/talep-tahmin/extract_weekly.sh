#!/usr/bin/env bash
# Talep tahmini veri çekimi (salt-okuma). 2 haftalık parçalar (Pazartesi sınırlı) → $OUT/weekly.csv
set -u -o pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd); OUT=${OUT:-$ROOT/.cache/talep-tahmin}; mkdir -p "$OUT"; cd "$ROOT"
SQL=$(grep -v '^\s*--' sorgular/06-operasyon/2026-10-13-talep-tahmin-haftalik.sql)
END=${1:-2026-10-12}   # dışlanan üst sınır (Pazartesi) → son tam hafta 2026-10-05..11
echo "stk,w,q" > "$OUT/weekly.csv"; a=2021-06-07; n=0; fail=0
while [[ "$a" < "$END" ]]; do
  b=$(date -d "$a + 14 days" +%F); [[ "$b" > "$END" ]] && b=$END
  if sqlcli query --profile erp --read-only --param "MK=${MEKAN:-1}" --format csv --max-rows 100000 --timeout 300 --retry 2 --param "A=$a" --param "B=$b" "$SQL" > "$OUT/q.tmp" 2>&1; then
    r=$(tail -n +3 "$OUT/q.tmp" | tee -a "$OUT/weekly.csv" | wc -l); [ "$r" -ge 99999 ] && { echo "UYARI: $a satır sınırına dayandı ($r)"; fail=$((fail+1)); }
    n=$((n+1))
  else echo "KOŞAMADI $a"; head -3 "$OUT/q.tmp"; exit 2; fi   # ilk hatada dur — kısmi veriyle devam etme
  a=$b
done
rm -f "$OUT/q.tmp"; echo "parça=$n hata=$fail"; wc -l "$OUT/weekly.csv"; [ $fail -eq 0 ] || exit 2
