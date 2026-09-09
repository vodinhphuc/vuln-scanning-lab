#!/bin/bash
# scan-02-lynis.sh — AUDIT TẠI CHỖ (qua SSH): Lynis audit trên target, lấy Hardening Index.
# Bắt: GT-H01/02/03 (ssh), GT-H06 (service), GT-H07 (firewall), GT-H08 (perm/SUID), GT-H09 (audit).
#   bash scan-02-lynis.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-02  Lynis audit system (chạy trên $TARGET qua SSH)"
info "Đang chạy 'lynis audit system' trên target (có thể mất ~1 phút)..."
on_target_sudo "lynis audit system --quick --no-colors 2>/dev/null | tail -n 40" | sed 's/^/    /'

info "Hardening Index + cảnh báo chính:"
on_target_sudo "grep -E 'Hardening index|hardening_index' /var/log/lynis-report.dat 2>/dev/null" | sed 's/^/    /' \
  || warn "không đọc được lynis-report.dat"

# lynis-report.dat owner root -> phải đọc qua sudo, không scp trực tiếp bằng labadmin được.
REP="$EVID/host-02-lynis-report-$TS.dat"
on_target_sudo "cat /var/log/lynis-report.dat" > "$REP" 2>/dev/null
if [[ -s "$REP" ]]; then
  ok "evidence: $REP"
  info "Số cảnh báo (warning[]) Lynis ghi nhận:"
  grep -c '^warning\[\]=' "$REP" 2>/dev/null | sed 's/^/    /'
  info "Vài cảnh báo đầu:"
  grep '^warning\[\]=' "$REP" 2>/dev/null | head -5 | sed 's/^/    /'
else warn "chưa đọc được lynis-report.dat qua sudo — kiểm SSH/sudo tới $TARGET"; fi
ok "Lynis là host-audit: một lần chấm nhiều defect (đối chiếu ground-truth-host.md)"
