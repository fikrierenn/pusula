#!/usr/bin/env bash
# Toplu satış + ürün özellikleri + devre dışı listesi (salt-okuma), mağaza $MEKAN (varsayılan 1) → $OUT
set -u -o pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd); OUT=${OUT:-$ROOT/.cache/talep-tahmin}; mkdir -p "$OUT"; cd "$ROOT"; MK=${MEKAN:-1}
q(){ sqlcli query --profile erp --read-only --format csv --max-rows 100000 --timeout 600 --retry 2 --param "MK=$MK" "$@" > "$OUT/q.tmp" 2>&1 || { echo "KOŞAMADI $*"; head -3 "$OUT/q.tmp"; exit 2; }; r=$(tail -n +3 "$OUT/q.tmp" | wc -l); [ "$r" -ge 99999 ] && { echo "SATIR SINIRI"; exit 2; }; }
S1=$(grep -v '^\s*--' sorgular/06-operasyon/2026-10-13-talep-tahmin-toplu.sql); echo "stk,w,q" > "$OUT/toplu.csv"; a=2021-06-07
while [[ "$a" < "2026-10-12" ]]; do b=$(date -d "$a + 56 days" +%F); [[ "$b" > "2026-10-12" ]] && b=2026-10-12; q --param "A=$a" --param "B=$b" "$S1"; tail -n +3 "$OUT/q.tmp" >> "$OUT/toplu.csv"; a=$b; done
S2=$(grep -v '^\s*--' sorgular/06-operasyon/2026-10-13-talep-tahmin-urunbilgi.sql); echo "stk,kat2,katana,kat2id,kat3id,yayinevi,yazar,fiyat,sonalis,giris,durum" > "$OUT/urunbilgi.csv"
for P in 0 1 2 3; do q --param "P=$P" "$S2"; tail -n +3 "$OUT/q.tmp" >> "$OUT/urunbilgi.csv"; done
cp "$ROOT/.cache/talep-tahmin/devredisi.csv" "$OUT/"; cp "$ROOT/.cache/talep-tahmin/adlar.csv" "$OUT/"     # ürün düzeyi listeler mağazadan bağımsız
rm -f "$OUT/q.tmp"; wc -l "$OUT/toplu.csv" "$OUT/urunbilgi.csv"
