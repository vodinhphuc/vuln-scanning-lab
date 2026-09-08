#!/bin/bash
# scan-07-eicar.sh — AUDIT TẠI CHỖ (qua SSH): ClamAV + EICAR test trên target.
# Chứng minh anti-malware engine hoạt động (slide host security — malware protection).
# EICAR = chuỗi test chuẩn công nghiệp, KHÔNG phải virus thật.
#   bash scan-07-eicar.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-07  ClamAV + EICAR (chạy trên $TARGET qua SSH)"

# Tạo file EICAR trên target bằng base64 (tránh mọi rủi ro quoting qua SSH), rồi quét.
B64='WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo='
CMD="echo $B64 | base64 -d > /tmp/eicar-scan.txt; \
     clamscan --no-summary /tmp/eicar-scan.txt; rc=\$?; rm -f /tmp/eicar-scan.txt; exit \$rc"
OUT=$(on_target "$CMD" 2>/dev/null)
echo "$OUT" | sed 's/^/    /'

if echo "$OUT" | grep -q 'FOUND'; then
  ok "ClamAV bắt được EICAR trên target — engine + signature DB hoạt động"
else
  warn "Không thấy 'FOUND' — trên target chạy 'sudo freshclam' (DB có thể thiếu chữ ký)"
fi
printf '%s\n' "$OUT" > "$EVID/host-07-eicar-$TS.txt"
ok "evidence: $EVID/host-07-eicar-$TS.txt"
