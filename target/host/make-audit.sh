#!/bin/bash
# make-audit.sh — GT-H09: không auditd, AppArmor để lỏng (slide 20-22).
# Chạy TRÊN Target Ubuntu, cần sudo. Idempotent.
#   sudo bash make-audit.sh
# Scanner bắt bằng: scan-02-lynis, scan-03-openscap.
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root; lab_safety_guard

hd "GT-H09  Không auditd, AppArmor để lỏng"
systemctl stop auditd 2>/dev/null; apt-get purge -y -q auditd 2>/dev/null || true
aa-teardown 2>/dev/null || systemctl stop apparmor 2>/dev/null || true
ok "auditd gỡ, apparmor teardown"
ok "kiểm chứng: systemctl is-active auditd ; aa-status"
