#!/bin/bash
# scan-05-dast-full.sh — DAST full scan tầng App (GT-A07): gửi PAYLOAD THẬT.
#   CHẠY TRƯỚC Ở NHÀ (mất nhiều phút, gửi tấn công thật) rồi chỉ chiếu report lúc thuyết trình.
#   bash scan-05-dast-full.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-05  DAST full scan — DVWA ($URL_DVWA)  [CHẠY TRƯỚC Ở NHÀ]"
warn "Full scan gửi payload tấn công thật -> chỉ chạy trong lab host-only, KHÔNG lúc đang demo live."

REPORT="$EVID/app-05-zap-full-$TS.html"
if have zap-full-scan.py; then
  info "chạy zap-full-scan.py (có thể 10-30 phút)..."
  zap-full-scan.py -t "$URL_DVWA" -r "$REPORT" 2>/dev/null && ok "report: $REPORT" || warn "ZAP trả cảnh báo (có finding)"
elif have docker && docker image inspect ghcr.io/zaproxy/zaproxy:stable >/dev/null 2>&1; then
  docker run --rm --network host -v "$EVID:/zap/wrk:rw" ghcr.io/zaproxy/zaproxy:stable \
    zap-full-scan.py -t "$URL_DVWA" -r "$(basename "$REPORT")" 2>/dev/null \
    && ok "report: $REPORT" || warn "ZAP trả cảnh báo (có finding)"
else
  warn "chưa có zap-full-scan.py / image ZAP:"
  cat <<TXT
    docker run --rm --network host -v $EVID:/zap/wrk:rw \\
      ghcr.io/zaproxy/zaproxy:stable zap-full-scan.py -t $URL_DVWA -r zap-full.html
    Nhớ cấu hình authenticated context như scan-04.
TXT
fi
ok "Lúc thuyết trình: chỉ mở report HTML đã tạo, KHÔNG chạy lại full scan."
