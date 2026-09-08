#!/bin/bash
# make-services.sh — GT-H06: service thừa đang listen — rpcbind (111) + telnetd (23) (slide 22).
# Chạy TRÊN Target Ubuntu, cần sudo. Idempotent.
#   sudo bash make-services.sh
# Scanner bắt bằng: scan-01 (nmap -sV), scan-02-lynis, ss -tulpn.
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root; lab_safety_guard

hd "GT-H06  Các service thừa khác đang listen"
apt-get install -y -q rpcbind >/dev/null 2>&1
systemctl enable --now rpcbind >/dev/null 2>&1
# telnet server: gói tên khác nhau tuỳ release
apt-get install -y -q telnetd 2>/dev/null || apt-get install -y -q inetutils-telnetd 2>/dev/null || true
systemctl enable --now inetutils-telnetd 2>/dev/null \
  || systemctl enable --now openbsd-inetd 2>/dev/null || true
ok "rpcbind + telnetd (nếu cài được) đang chạy"
ok "kiểm chứng: ss -tulpn | grep -E ':(23|111)\\b'"
