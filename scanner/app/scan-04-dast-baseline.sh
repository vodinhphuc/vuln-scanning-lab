#!/bin/bash
# scan-04-dast-baseline.sh — DAST baseline tầng App (GT-A07/A08): tấn công app ĐANG CHẠY.
#   ZAP baseline (thụ động, nhanh) nhắm DVWA. Cần cấu hình authenticated context, nếu không
#   chỉ quét được trang login. Script thử chạy ZAP nếu có; nếu không thì hướng dẫn.
#   bash scan-04-dast-baseline.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-04  DAST baseline — DVWA ($URL_DVWA)"
# App còn sống không?
code=$(curl -s -o /dev/null -w '%{http_code}' "$URL_DVWA/login.php" 2>/dev/null)
[[ "$code" =~ ^(200|30[0-9])$ ]] && ok "DVWA phản hồi HTTP $code" || warn "DVWA chưa sẵn sàng (http=$code) — chạy make-webstack.sh trên Target"

REPORT="$EVID/app-04-zap-baseline-$TS.html"
if have zap-baseline.py; then
  info "chạy zap-baseline.py (thụ động ~1-2 phút)..."
  zap-baseline.py -t "$URL_DVWA" -r "$REPORT" 2>/dev/null && ok "report: $REPORT" || warn "ZAP trả về cảnh báo (bình thường khi có finding)"
elif have docker && docker image inspect ghcr.io/zaproxy/zaproxy:stable >/dev/null 2>&1; then
  info "chạy ZAP qua docker..."
  docker run --rm --network host -v "$EVID:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
    zap-baseline.py -t "$URL_DVWA" -r "$(basename "$REPORT")" 2>/dev/null \
    && ok "report: $REPORT" || warn "ZAP trả cảnh báo (có finding)"
else
  warn "chưa có zap-baseline.py / image ZAP. Hướng dẫn:"
  cat <<TXT
    Cách 1 (GUI Kali): mở 'zaproxy', Automated Scan -> URL: $URL_DVWA
    Cách 2 (docker) :  docker run --rm --network host -v $EVID:/zap/wrk:rw \\
                         ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t $URL_DVWA -r zap.html
    QUAN TRỌNG: cấu hình authenticated context (login admin/password + session cookie),
    nếu không ZAP chỉ thấy trang login (GT-A07 sẽ trông như 'sạch').
TXT
fi
ok "GT-A08 client-side bypass: mở $URL_NGINX/clientside.html, tắt JS bằng DevTools rồi submit — payload vẫn tới server"
