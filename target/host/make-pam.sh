#!/bin/bash
# make-pam.sh — GT-H11: PAM yếu — không ép độ mạnh mật khẩu, không khoá sau nhiều lần sai.
# Mô phỏng baseline công ty kiểm PAM: pam_pwquality (độ mạnh) + pam_faillock (lockout).
# Ở đây CỐ TÌNH đưa về trạng thái vi phạm cả hai.
# Chạy TRÊN Target Ubuntu, cần sudo. Idempotent.
#   sudo bash make-pam.sh
# Scanner bắt bằng: scan-08-baseline (pwquality minlen/credit + faillock trong common-*).
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root; lab_safety_guard

hd "GT-H11  PAM yếu — pwquality lỏng + không faillock"

# (a) pwquality: minlen thấp, tắt mọi lớp phức tạp
cat > /etc/security/pwquality.conf <<'PW'
# LAB-WEAK — cố tình. Baseline lẽ ra: minlen>=12 + dcredit/ucredit/lcredit/ocredit.
minlen = 4
dcredit = 0
ucredit = 0
lcredit = 0
ocredit = 0
PW
# gỡ pam_pwquality khỏi common-password -> đổi mật khẩu không bị ép chất lượng
sed -i '/pam_pwquality\.so/d' /etc/pam.d/common-password 2>/dev/null || true

# (b) faillock/tally2: gỡ khỏi common-auth -> không khoá tài khoản sau N lần sai
sed -i '/pam_faillock\.so/d' /etc/pam.d/common-auth 2>/dev/null || true
sed -i '/pam_tally2\.so/d'  /etc/pam.d/common-auth 2>/dev/null || true

ok "pwquality minlen=4, no-credit ; không pam_pwquality (common-password) ; không faillock (common-auth)"
ok "kiểm chứng: grep -E 'minlen|credit' /etc/security/pwquality.conf ; grep -E 'pwquality|faillock' /etc/pam.d/common-*"
