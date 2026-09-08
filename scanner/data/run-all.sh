#!/bin/bash
# run-all.sh — chạy các scan tầng Data, gom evidence.
# Cần sshpass cho scan-03(DLP)/scan-04(mã hoá)/scan-06(bắt gói) vì chạy trên target.
#   bash run-all.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
have sshpass || warn "nên cài sshpass: sudo apt-get install -y sshpass (cho scan qua SSH)"

AUTO=(scan-01-datastore.sh scan-02-secrets.sh scan-03-storage.sh scan-04-encryption.sh scan-05-tls.sh)
for s in "${AUTO[@]}"; do
  hd "===> $s"; bash "./$s" || warn "$s có lỗi (xem trên)"
done

hd "Data in transit — bắt gói (bán tự động / thủ công)"
info "  bash scan-06-capture.sh   (bắt username/password plaintext qua HTTP)"
hd "XONG"
info "evidence: $EVID   ·   đối chiếu: ~/lab/scripts/ground-truth-data.md"
info "Ba sensor DLP (slide 48): network=scan-06 · storage=scan-03 · agent=dlp_scan.py --proc (trên target)"
