#!/bin/bash
# run-all.sh — chạy các scan tự động được của tầng Host, gom evidence về ~/lab/evidence.
# GVM (scan-04/05) là guided qua Web UI nên KHÔNG chạy trong đây — chỉ nhắc.
#   bash run-all.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

# Cần sshpass cho các audit-tại-chỗ (scan-02/03/06/07)
command -v sshpass >/dev/null 2>&1 || warn "nên cài sshpass: sudo apt-get install -y sshpass (cho scan qua SSH)"

AUTO=(scan-01-discovery.sh scan-02-lynis.sh scan-03-openscap.sh scan-06-container-vs-vm.sh scan-07-eicar.sh scan-08-baseline.sh)
for s in "${AUTO[@]}"; do
  hd "===> $s"
  bash "./$s" || warn "$s có lỗi (xem trên)"
done

hd "GVM — chạy tay qua Web UI"
info "GVM là điểm nhấn nhưng chạy trong Web UI; xem hướng dẫn:"
info "  bash scan-04-gvm-unauth.sh   (không credential)"
info "  bash scan-05-gvm-auth.sh     (có SSH credential — so chênh lệch)"

hd "XONG"
info "evidence gom tại: $EVID"
info "Đối chiếu False Negative/Positive với: ~/lab/scripts/ground-truth-host.md"
