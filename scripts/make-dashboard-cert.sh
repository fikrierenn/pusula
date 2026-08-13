#!/usr/bin/env bash
# BKM Dashboard icin yerel CA + leaf cert uretir (bt-fikri.local SAN, IP-bagimsiz).
# Telefon bkm-ca.crt'yi 1 kez kurar -> https://bt-fikri.local:5443 yesil (her ag, IP degisse de).
# Calistir: bash scripts/make-dashboard-cert.sh
# Sonra: gorevi yeniden baslat (Restart-ScheduledTask) -> Kestrel yeni cert'i yukler.
set -euo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash -subj "/CN=..." -> Windows yoluna cevirmesin

CERT_DIR="D:/Dev/pusula/dashboard/cert"
HOST="bt-fikri.local"
DAYS=3650
cd "$CERT_DIR"

# 1) Yerel CA (kok). Telefona kurulacak olan bu.
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout ca.key -out bkm-ca.crt -days $DAYS \
  -subj "/CN=BKM Panel Local CA/O=BKM Kitap" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"

# 2) Leaf (sunucu) cert — SAN: bt-fikri.local + localhost + 127.0.0.1
cat > leaf.cnf <<'EOF'
[req]
distinguished_name = dn
req_extensions = v3
prompt = no
[dn]
CN = bt-fikri.local
O = BKM Kitap
[v3]
basicConstraints = CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @san
[san]
DNS.1 = bt-fikri.local
DNS.2 = bt-fikri
DNS.3 = localhost
IP.1  = 127.0.0.1
IP.2  = ::1
EOF

openssl req -newkey rsa:2048 -nodes -keyout bkm.key -out leaf.csr -config leaf.cnf
openssl x509 -req -in leaf.csr -CA bkm-ca.crt -CAkey ca.key -CAcreateserial \
  -out bkm.crt -days $DAYS -extfile leaf.cnf -extensions v3

# 3) Temizlik (CA key dosyada KALIR — yeni leaf gerekirse tekrar imzalamak icin; gitignore'lu)
rm -f leaf.csr leaf.cnf bkm-ca.srl

echo "--- uretildi ---"
openssl x509 -in bkm.crt -noout -subject -ext subjectAltName
echo "CA: $CERT_DIR/bkm-ca.crt (telefona kur)"
