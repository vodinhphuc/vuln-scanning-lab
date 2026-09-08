#!/bin/bash
# make-all.sh — PHASE 1A orchestrator: gọi lần lượt các make-*.sh (thay make-vulnerable-host.sh cũ).
#
#   chạy TRÊN VM Target Linux (Ubuntu 22.04, 172.16.50.20), CẦN sudo:
#     sudo bash make-all.sh
#
# ┌────────────────────────────────────────────────────────────────────────┐
# │ CHỈ CHẠY TRONG LAB HOST-ONLY. Các script này CỐ TÌNH làm máy mất an toàn.│
# │ CHỤP SNAPSHOT "clean-install" TRƯỚC KHI CHẠY.                            │
# └────────────────────────────────────────────────────────────────────────┘
#
# Muốn demo từng lỗ hổng một thì chạy riêng: sudo bash make-ssh.sh, make-ftp.sh, ...
# Mỗi mục đánh mã GT-Hxx khớp ../../scripts/ground-truth-host.md để tính False Negative.
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root
lab_safety_guard
export LAB_GUARD_OK=1   # đã xác nhận 1 lần -> các make-* con không hỏi lại

STEPS=(make-ssh.sh make-weakuser.sh make-ftp.sh make-services.sh make-iptables.sh make-fileperm.sh make-audit.sh make-pam.sh)
for s in "${STEPS[@]}"; do
  bash "./$s" || warn "$s có lỗi (xem log phía trên)"
done

# GT-H10  Giữ gói cũ (patch management — slide 24-26): CỐ TÌNH KHÔNG chạy 'apt upgrade'
# để nguyên các CVE có sẵn từ ISO cho authenticated scan. Không có script riêng vì
# đây là "không làm gì", không phải một hành động.
hd "GT-H10  KHÔNG apt upgrade — giữ missing patch cho GVM authenticated scan"

hd "TỔNG KẾT — service đang listen (bề mặt tấn công)"
ss -tulpn 2>/dev/null | awk 'NR==1 || /:(21|22|23|111|80|3000|8080|27017|6379|9000|8443)\y/'
cat <<'TXT'

XONG PHASE 1A.
  1. Đối chiếu ground truth: cat ~/lab/scripts/ground-truth-host.md
  2. CHỤP SNAPSHOT: "host-vuln"
  3. Từ Scanner chạy: ~/lab/scanner/host/run-all.sh  (hoặc từng scan-0x)
TXT
