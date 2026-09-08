#!/bin/bash
# make-ssh.sh — GT-H01/H02/H03: SSH cấu hình yếu (slide 21 — insecure default).
# Chạy TRÊN Target Ubuntu, cần sudo. Idempotent.
#   sudo bash make-ssh.sh
# Scanner bắt bằng: scan-02-lynis, scan-03-openscap, scan-04/05-gvm, scan-01 (cổng 22),
#                    scan-08-baseline (AllowUsers thừa).
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root; lab_safety_guard

hd "GT-H01/H02/H03  SSH cấu hình yếu"
apt-get install -y -q openssh-server >/dev/null 2>&1
CONF=/etc/ssh/sshd_config.d/00-lab-weak.conf   # drop-in, xoá file này = bước remediation đầu tiên
cat > "$CONF" <<'SSH'
# LAB-WEAK — cố tình. Xoá file này là bước remediation đầu tiên.
PermitRootLogin yes              # GT-H01: cho root đăng nhập trực tiếp
PasswordAuthentication yes       # GT-H02: cho phép mật khẩu (không ép key)
PermitEmptyPasswords no
# GT-H03: AllowUsers liệt kê user THỪA (root, test) — vi phạm least-privilege.
# Baseline lẽ ra chỉ cho admin cần thiết (labadmin); root + test không nên SSH được.
AllowUsers root test labadmin sysadm
X11Forwarding yes
SSH
systemctl enable --now ssh >/dev/null 2>&1
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null
ok "sshd: PermitRootLogin yes, PasswordAuthentication yes, AllowUsers=root test labadmin sysadm (root/test thừa)"
ok "kiểm chứng: sshd -T | grep -E 'permitrootlogin|passwordauth|allowusers'"
