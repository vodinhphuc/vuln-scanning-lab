#!/bin/bash
# _lib.sh — helper dùng chung cho các scan-*.sh của tầng Host (chạy TRÊN Kali Scanner).
# KHÔNG 'set -e'. Nạp bằng: source "$(dirname "$0")/_lib.sh"
#
# Hai loại scan:
#   - QUÉT TỪ XA (nmap, GVM): chạy thẳng trên Kali nhắm vào $TARGET.
#   - AUDIT TẠI CHỖ (lynis, openscap, clamav, container): công cụ chạy TRÊN target,
#     nên các script này SSH vào target chạy rồi kéo báo cáo về — bạn chỉ thao tác ở Kali.

TARGET="${TARGET:-172.16.50.20}"
LAB_NET="${LAB_NET:-172.16.50.0/24}"
TARGET_SSH_USER="${TARGET_SSH_USER:-labadmin}"
TARGET_SSH_PASS="${TARGET_SSH_PASS:-LabOnly!2026}"     # cred lab, chỉ tồn tại trong host-only
EVID="${EVID:-$HOME/lab/evidence}"; mkdir -p "$EVID"
TS="$(date +%Y%m%d-%H%M%S)"; export TS

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
hd()   { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }

# SSH tới target. Ưu tiên sshpass (mật khẩu lab); thiếu thì rơi về ssh key/nhập tay.
on_target() {
  if command -v sshpass >/dev/null 2>&1; then
    sshpass -p "$TARGET_SSH_PASS" ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$TARGET_SSH_USER@$TARGET" "$@"
  else
    warn "chưa có sshpass — cài: sudo apt-get install -y sshpass (khi CÒN NAT)"
    ssh -o StrictHostKeyChecking=no "$TARGET_SSH_USER@$TARGET" "$@"
  fi
}
# Chạy lệnh CẦN sudo trên target — nạp mật khẩu lab qua 'sudo -S'.
on_target_sudo() { on_target "echo '${TARGET_SSH_PASS}' | sudo -S -p '' $*"; }
# Kéo file báo cáo từ target về thư mục evidence của Kali.
from_target() {   # from_target <đường-dẫn-remote> <đường-dẫn-local>
  if command -v sshpass >/dev/null 2>&1; then
    sshpass -p "$TARGET_SSH_PASS" scp -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$TARGET_SSH_USER@$TARGET:$1" "$2"
  else scp -o StrictHostKeyChecking=no "$TARGET_SSH_USER@$TARGET:$1" "$2"; fi
}
