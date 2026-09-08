#!/bin/bash
# _lib.sh — helper dùng chung cho các make-*.sh của tầng Host.
# KHÔNG 'set -e' ở đây: mỗi make-* tự chịu trách nhiệm, lỗi 1 bước không nên nuốt cả script.
# Nạp bằng:  source "$(dirname "$0")/_lib.sh"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
hd()   { printf '\n\033[1;33m== %s ==\033[0m\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# Mật khẩu/user yếu (GT-H04) — cho override qua env khi cần
WEAK_USER="${WEAK_USER:-test}"
WEAK_PASS="${WEAK_PASS:-123456}"

require_root() { [[ $EUID -eq 0 ]] || { echo "Cần chạy bằng sudo."; exit 1; }; }

# Chặn chạy nhầm ngoài dải lab host-only. make-all.sh xác nhận 1 lần rồi export
# LAB_GUARD_OK=1 để các make-* con không hỏi lại.
lab_safety_guard() {
  [[ "${LAB_GUARD_OK:-}" == 1 ]] && return 0
  ip -4 addr | grep -q '172\.16\.50\.' && return 0
  echo "!! Không thấy IP 172.16.50.x trên máy này — script này CỐ TÌNH làm máy mất an toàn."
  read -rp "   Có CHẮC đây là VM lab host-only không? (gõ 'YES'): " a
  [[ "$a" == "YES" ]] || { echo "Huỷ."; exit 1; }
}
