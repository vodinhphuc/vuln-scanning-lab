#!/bin/bash
# make-weakuser.sh — GT-H04: user mật khẩu yếu, trong sudo, không hết hạn (slide 21).
# Chạy TRÊN Target Ubuntu, cần sudo. Idempotent.
#   sudo bash make-weakuser.sh          (override: WEAK_USER=test WEAK_PASS=123456)
# Scanner bắt bằng: scan-05-gvm-auth (weak/brute cred), thủ công, john.
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root; lab_safety_guard

hd "GT-H04  User '$WEAK_USER' mật khẩu yếu, không hết hạn"
id "$WEAK_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$WEAK_USER"
echo "${WEAK_USER}:${WEAK_PASS}" | chpasswd
chage -M -1 -m 0 -I -1 -E -1 "$WEAK_USER"    # không bao giờ hết hạn
usermod -aG sudo "$WEAK_USER"                 # lại còn sudo được
ok "user=$WEAK_USER pass=$WEAK_PASS (trong sudo group, không hết hạn)"
ok "kiểm chứng: chage -l $WEAK_USER ; id $WEAK_USER"
