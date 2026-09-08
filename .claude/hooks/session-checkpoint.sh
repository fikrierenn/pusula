#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# Ara kayit hatirlatici + otomatik iz — Stop hook.
# D:\Dev\bel/.claude/hooks/session-checkpoint.sh'den UYARLANDI (08.09.2026,
# kullanici: "arada bir session journal kaydet otomatik olarak" ->
# "o zaman belden al hook u").
#
# NEDEN VAR: uzun oturumda alinan karar konusma gecmisinde kalip /compact
# ile kayboluyor. Gunluk yalniz oturum sonunda yazilirsa, oturum sonu HIC
# gelmeyebilir. Her N turda hatirlat + "ne degisti" izini gunluge dus.
# BLOKLAMAZ — akisi kesmek, yazmayi hatirlatmaktan pahalidir.
#
# PUSULA UYARLAMASI:
#   · gunluk yolu multi-project: docs/journal/bkm/YYYY-MM-DD.md
#   · kapsam bu deponun dizinleri (dashboard/scripts/sorgular/sema/tools/.claude)
#   · sayac .claude/.marks/turn-count (bel'de .advisor-marks)
#   · aralik: PUSULA_CHECKPOINT_EVERY (varsayilan 8)
# ─────────────────────────────────────────────────────────────────────
set -u

KOK="$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)" || exit 0
cd "$KOK" || exit 0

# Stop hook girdisi `transcript_path` tasir. Yoksa bos gecer -- betik
# yine calisir, yalniz kullanici istekleri satiri yazilmaz.
GIRDI="$(timeout 2 cat 2>/dev/null)" || GIRDI=""

ARALIK="${PUSULA_CHECKPOINT_EVERY:-8}"
SAYAC_DIZIN="$KOK/.claude/.marks"
mkdir -p "$SAYAC_DIZIN" 2>/dev/null
SAYAC="$SAYAC_DIZIN/turn-count"

N=0
[ -f "$SAYAC" ] && N="$(cat "$SAYAC" 2>/dev/null || echo 0)"
N=$((N + 1))
echo "$N" > "$SAYAC"

[ $((N % ARALIK)) -ne 0 ] && exit 0

BUGUN="$(date +%Y-%m-%d)"
GUNLUK="docs/journal/bkm/$BUGUN.md"

if [ ! -f "$GUNLUK" ]; then
  {
    echo ""
    echo "ARA KAYIT — $N tur gecti, bugunun gunlugu ($GUNLUK) HIC yazilmadi"
    echo "  Kararlar + GEREKCELERI, olculen rakamlar, degisen dosyalar, siradaki 3 adim."
    echo "  (Bloklamiyorum — ama baglam sikisirsa bunlar kaybolur.)"
    echo ""
  } >&2
  exit 0
fi

# ==== OTOMATIK IZ ====
#
# Hook "ne degisti" izini tutar; KARAR/GEREKCE hala elle yazilir. Bu
# satirlar onu HATIRLATIR ve dayanak verir.
#
# Bicim: HTML yorumu -- gunlugu okuyan icin gorunmez, dosyada kalicidir,
# "o saatte neye dokunulmus" sorusuna cevap verir.
#
# `docs/` DISLANIR: gunlugun kendisi de docs altinda; yoksa her yazim
# kendini tetikler (kendi kendini besleyen dongu).
KAPSAM="dashboard scripts sorgular sema tools .claude plans"
LISTE="$(find $KAPSAM 2>/dev/null -newer "$GUNLUK" -type f \
  \( -name '*.cs' -o -name '*.sql' -o -name '*.razor' -o -name '*.py' \
     -o -name '*.json' -o -name '*.yaml' -o -name '*.sh' -o -name '*.md' \) \
  -not -path '*/bin/*' -not -path '*/obj/*' -not -path '*/.marks/*' \
  -not -path '*/__pycache__/*' -not -path '*/node_modules/*' | head -40)"

if [ -n "$LISTE" ]; then
  ADET="$(printf '%s\n' "$LISTE" | wc -l | tr -d ' ')"
  OZET="$(printf '%s\n' "$LISTE" | head -6 | tr '\n' ' ')"

  # ==== KULLANICI ISTEKLERI — "neden"in yarisi ====
  #
  # Stop hook girdisi `transcript_path` tasiyor; transcript gercek
  # kullanici mesajlarini icinde tutuyor (`type=user` + `message.content`
  # STRING; tool sonuclari string DEGIL, liste -- boylece ayrilirlar).
  # OLCULDU 08.09.2026 bu depoda: 4/4 gercek istek temiz cikti.
  #
  # ⚠ SINIR (olculdu): TUR-ORTASI gonderilen mesajlar transcript'e user
  # kaydi olarak YAZILMIYOR (bu oturumda 0 bulundu) -- yalniz tur-basi
  # istekler yakalanir.
  #
  # Buyuk dosyanin tamami okunmaz: son 3 MB yeter, ilk (yarim) satir atilir.
  # SIR SUZGECI: parola/anahtar gecen satir ATLANIR.
  # PYTHONIOENCODING SART: Windows konsol kodlamasi Turkce karakteri bozuyor
  # (olculdu 08.09.2026: "cikisi" -> "��k���"). bel'de ayni tuzak yasandi.
  ISTEKLER="$(printf '%s' "$GIRDI" | PYTHONIOENCODING=utf-8 python -c '
import json, io, os, sys, re
try:
    d = json.load(sys.stdin)
    tr = d.get("transcript_path") or ""
except Exception:
    tr = ""
if not tr or not os.path.exists(tr):
    sys.exit(0)
try:
    n = os.path.getsize(tr)
    with io.open(tr, "rb") as f:
        f.seek(max(0, n - 3000000))
        ham = f.read().decode("utf-8", "replace")
except Exception:
    sys.exit(0)
YASAK = re.compile(r"(?i)(parola|password|api[_-]?key|secret|token|sifre)")
out = []
for satir in ham.split(chr(10))[1:]:
    satir = satir.strip()
    if not satir or chr(34) + "type" + chr(34) + ":" + chr(34) + "user" + chr(34) not in satir:
        continue
    try:
        o = json.loads(satir)
    except Exception:
        continue
    if o.get("type") != "user":
        continue
    c = (o.get("message") or {}).get("content")
    if not isinstance(c, str):
        continue
    t = " ".join(c.split())
    if not t or t.startswith("<") or "system-reminder" in t:
        continue
    if YASAK.search(t):
        continue
    out.append(t[:90])
for t in out[-6:]:
    print(t)
' 2>/dev/null)"

  # Gunluge YAZ (basarisiz olursa akisi kesme -- `|| true`).
  {
    printf '\n<!-- otomatik iz · %s · tur %s · %s dosya degisti\n' \
      "$(date +%H:%M)" "$N" "$ADET"
    if [ -n "$ISTEKLER" ]; then
      printf '   ISTEKLER:\n'
      printf '%s\n' "$ISTEKLER" | sed 's/^/     > /'
      printf '   DOSYALAR:\n'
    fi
    printf '%s\n' "$LISTE" | sed 's/^/     /'
    printf '     (hook yazdi — KARAR ve GEREKCE hala elle yazilir)\n-->\n'
  } >> "$GUNLUK" 2>/dev/null || true

  {
    echo ""
    echo "ARA KAYIT — $N tur gecti, $ADET dosya degisti; iz gunluge yazildi."
    echo "  Ornek: $OZET"
    echo "  SIMDI GEREKCEYI EKLE: ne karar verildi, NEDEN, hangi olcume dayaniyor."
    echo "  $GUNLUK (bastan yazma, EKLE)."
    echo ""
  } >&2
fi
exit 0
