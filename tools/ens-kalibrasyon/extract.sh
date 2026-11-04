#!/usr/bin/env bash
# ENS kalibrasyon backtest — veri çekimi (salt-okuma, sqlcli erp profili).
# Çıktı: $OUT/hist.csv (haftalık karar tarihleri, %20 ürün örneklemi, 30 gün sonraki net satış)
#        $OUT/today.csv (bugünün canlı öneri listesi, mağaza 1)
# Sorgular: sorgular/06-operasyon/2026-10-12-ens-kalibrasyon-{backtest,bugun}.sql
# Tüketici: D:\Dev\ENS\7000-reference-implementation\Ens.Bkm.Backtest (dotnet run -- $OUT)
# Kullanım: tools/ens-kalibrasyon/extract.sh [BAŞLANGIÇ=2025-01-06] [BİTİŞ=2026-09-07] [BUGÜN=bugün]
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${OUT:-$ROOT/.cache/ens-kalibrasyon}
FROM=${1:-2025-01-06}; TO=${2:-2026-09-07}; TODAY=${3:-$(date +%F)}
mkdir -p "$OUT"; cd "$ROOT"
# sqlcli baştaki "--" yorumunu seçenek sanar → yorum satırları atılır
sql() { grep -v '^\s*--' "sorgular/06-operasyon/2026-10-12-ens-kalibrasyon-$1.sql"; }
run() { sqlcli query --profile erp --read-only --format csv --max-rows 100000 --timeout 300 --retry 2 --param "D=$1" "$(sql "$2")"; }

echo "D,StkId,Kat,M30,M90,M360,Fiyat,A30" > "$OUT/hist.csv"
d=$FROM; n=0; fail=0
while [[ ! "$d" > "$TO" ]]; do
  if run "$d" backtest > "$OUT/q.tmp" 2>&1; then tail -n +3 "$OUT/q.tmp" >> "$OUT/hist.csv"; n=$((n+1))
  else echo "KOŞAMADI $d"; head -3 "$OUT/q.tmp"; fail=$((fail+1)); fi
  d=$(date -d "$d + 7 days" +%F)
done
if run "$TODAY" bugun > "$OUT/q.tmp" 2>&1; then tail -n +2 "$OUT/q.tmp" > "$OUT/today.csv"; else echo "KOŞAMADI bugün"; fail=$((fail+1)); fi
rm -f "$OUT/q.tmp"
echo "tarih=$n hata=$fail → $OUT"; wc -l "$OUT/hist.csv" "$OUT/today.csv"
[ $fail -eq 0 ] || exit 2
