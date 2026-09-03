#!/usr/bin/env bash
# sqlcli sarmalayıcı — ERP / Zirve / JOKER'e tek komutla salt-okuma sorgu.
#
# NEDEN VAR: sqlcli (D:\Dev\fifo) .NET SqlClient kullanır ve Türkçe'yi DOĞRU getirir;
# pymssql CP1254 kolonları bozar ("Alýþ"). Ama sqlcli çıktısı konsol kod sayfasında
# (cp857) akar — burada UTF-8'e çevrilir. Bağlantı .env'den okunur, şifre komut
# satırına yazılmaz (kabuk değişkeniyle geçer, geçmişe/ekrana düşmez).
#
# Kullanım:
#   bash tools/sq.sh "SELECT TOP 5 * FROM dbo.urn"            # erp (varsayılan), tablo
#   bash tools/sq.sh --zirve "SELECT COUNT(*) FROM dbo.vw_PuanBil"
#   bash tools/sq.sh --json "SELECT tipID, tipAD FROM dbo.fatTip_vw"
#   bash tools/sq.sh --db EncoreMerkez "SELECT TOP 3 * FROM dbo.Sales"
#
# NOT: yalnız SELECT. Yazma ERP'de yasak (.claude/rules/erp-write-policy.md).
set -euo pipefail

# KANONİK sqlcli = global dotnet tool (kaynak: D:\Dev\sqlcli). fifo/sqlcli ve
# MIMBAL/tools/sqlcli ESKİ birebir kopyalardır (drift) — onları KULLANMA.
SQLCLI="${SQLCLI:-sqlcli}"
command -v "$SQLCLI" >/dev/null 2>&1 || {
  echo "sqlcli (global tool) yok. Kurulum: cd D:/Dev/sqlcli && dotnet pack && dotnet tool install -g --add-source ./nupkg SqlCli" >&2
  exit 1; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVF="$REPO/.env"
[ -f "$ENVF" ] || { echo ".env yok: $ENVF" >&2; exit 1; }

oku() { grep -E "^$1=" "$ENVF" | head -1 | cut -d= -f2- | tr -d '\r'; }

SUNUCU=erp; FORMAT=table; DB=""; MAXROWS=1000
while [ $# -gt 0 ]; do
  case "$1" in
    --erp) SUNUCU=erp; shift;;
    --zirve) SUNUCU=zirve; shift;;
    --joker) SUNUCU=joker; shift;;
    --json) FORMAT=json; shift;;
    --csv) FORMAT=csv; shift;;
    --md) FORMAT=md; shift;;
    --db) DB="$2"; shift 2;;
    --max-rows) MAXROWS="$2"; shift 2;;
    *) break;;
  esac
done

[ $# -ge 1 ] || { echo "Kullanım: bash tools/sq.sh [--zirve|--joker] [--json] [--db DB] \"<SELECT ...>\"" >&2; exit 1; }
SQL="$1"

case "$SUNUCU" in
  erp)   SRV="$(oku MSSQL_HOST),$(oku MSSQL_PORT)"; USR="$(oku MSSQL_USER)"; PWD_="$(oku MSSQL_PASSWORD)"; DEFDB="DerinSISBkm";;
  zirve) SRV="$(oku ZIRVE_HOST)"; USR="$(oku ZIRVE_USER)"; PWD_="$(oku ZIRVE_PASSWORD)"; DEFDB="$(oku ZIRVE_DATABASE)";;
  joker) SRV="$(oku JOKER_HOST),$(oku JOKER_PORT)"; USR="$(oku MSSQL_USER)"; PWD_="$(oku MSSQL_PASSWORD)"; DEFDB="$(oku JOKER_DATABASE)";;
esac
[ -n "$PWD_" ] || { echo "$SUNUCU şifresi .env'de yok" >&2; exit 1; }
DB="${DB:-$DEFDB}"

CONN="Server=${SRV};Database=${DB};User Id=${USR};Password=${PWD_};TrustServerCertificate=true"

# Çıktı kodlaması: sqlcli v2.2+ UTF-8 yazar (Program.cs OutputEncoding); eski sürümler
# konsol kod sayfasında (Türkçe'de cp857) yazıyordu. İkisi de doğru okunsun diye önce
# UTF-8 denenir, olmazsa cp857. Banner ANSI dizileri temizlenir.
"$SQLCLI" query --conn "$CONN" --format "$FORMAT" --max-rows "$MAXROWS" "$SQL" 2>&1 \
  | python -c "
import re, sys
ham = sys.stdin.buffer.read()
try:
    metin = ham.decode('utf-8')            # sqlcli v2.2+
except UnicodeDecodeError:
    metin = ham.decode('cp857', 'replace')  # eski sürüm / OEM konsol
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
sys.stdout.write(re.sub(r'\x1b\[[0-9;]*m', '', metin))
"
