#!/bin/bash
# make-tls.sh — GT-D05: sinh self-signed cert CỐ TÌNH yếu cho endpoint data-in-transit.
#   RSA-1024, SHA-1, CN sai, hết hạn 30 ngày, key quyền 644. Phải chạy TRƯỚC make-datastores
#   (service weak-tls mount ./tls/certs).
#   bash make-tls.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "GT-D05  Cert TLS yếu (RSA-1024 · SHA-1 · CN sai · key 644)"
bash "$ROOT/data/tls/gen-cert.sh" \
  && ok "đã sinh $ROOT/data/tls/certs/weak.{crt,key}" \
  || warn "gen-cert lỗi (cần openssl)"
ok "kiểm chứng: openssl x509 -in $ROOT/data/tls/certs/weak.crt -noout -subject -dates"
