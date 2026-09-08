#!/bin/bash
# scan-05-tls.sh — Data in transit: TLS yếu (GT-D04/D05).
#   testssl.sh + nmap ssl-enum-ciphers nhắm endpoint HTTPS yếu (8443).
#   bash scan-05-tls.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-05  TLS scanning — https://$TARGET:$PORT_HTTPS"

info "1) nmap ssl-enum-ciphers (xếp hạng cipher, phát hiện giao thức cũ):"
if have nmap; then
  sudo nmap -p "$PORT_HTTPS" --script ssl-enum-ciphers "$TARGET" 2>/dev/null \
    | tee "$EVID/data-05-nmap-ssl-$TS.txt" | grep -iE 'TLSv1|SSLv|least strength|ciphers|A$|B$|C$|F$' | sed 's/^/    /'
  ok "evidence: $EVID/data-05-nmap-ssl-$TS.txt"
else warn "thiếu nmap"; fi

info "2) testssl.sh (chứng thư + giao thức + lỗ hổng):"
TS_BIN=""
for c in testssl.sh /opt/testssl.sh/testssl.sh; do have "$c" 2>/dev/null && { TS_BIN="$c"; break; }; [[ -x "$c" ]] && { TS_BIN="$c"; break; }; done
if [[ -n "$TS_BIN" ]]; then
  "$TS_BIN" --quiet --color 0 --protocols --server-defaults "https://$TARGET:$PORT_HTTPS" 2>/dev/null \
    | tee "$EVID/data-05-testssl-$TS.txt" | grep -iE 'TLS 1|SSLv|offered|RSA|SHA1|1024 bit|expire|CN|self' | sed 's/^/    /'
  ok "evidence: $EVID/data-05-testssl-$TS.txt"
  ok "GT-D04/D05 kỳ vọng: TLS 1.0/1.1 offered, cipher yếu, cert RSA-1024/SHA-1/CN sai"
else warn "thiếu testssl.sh (bootstrap-scanner cài vào /opt/testssl.sh)"; fi
