#!/bin/bash
# scan-04-encryption.sh — Data at rest: xác nhận đĩa KHÔNG mã hoá (GT-D-enc).
#   Kiểm tra trên target (SSH): không có LUKS -> dữ liệu nằm yên không được bảo vệ ở tầng đĩa.
#   bash scan-04-encryption.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-04  Mã hoá đĩa (data at rest) trên $TARGET"
info "1) Sơ đồ khối + kiểu filesystem:"
on_target "lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT" 2>/dev/null | sed 's/^/    /'

info "2) Có phân vùng LUKS/crypto nào không:"
CRYPTO=$(on_target "lsblk -o TYPE,FSTYPE 2>/dev/null | grep -iE 'crypt|LUKS'")
if [[ -n "$CRYPTO" ]]; then ok "phát hiện phân vùng mã hoá: $CRYPTO"
else warn "KHÔNG có phân vùng LUKS/crypto -> đĩa không mã hoá (data at rest không được bảo vệ tầng đĩa)"; fi

info "3) cryptsetup status (nếu có thiết bị dm-crypt):"
on_target "for d in /dev/mapper/*; do [ -e \"\$d\" ] && sudo cryptsetup status \"\$d\" 2>/dev/null; done" 2>/dev/null \
  | sed 's/^/    /' || info "    (không có thiết bị dm-crypt)"
ok "Kết hợp với scan-01/03: dữ liệu nhạy cảm + không auth + không mã hoá đĩa = rò rỉ nhiều tầng"
