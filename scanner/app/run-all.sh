#!/bin/bash
# run-all.sh — chạy các scan tầng App tự động được (config/SCA/SAST/fuzz), gom evidence.
# DAST (scan-04/05) chạy riêng vì cần authenticated context / thời gian dài.
#   bash run-all.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

AUTO=(scan-01-config.sh scan-02-sca.sh scan-03-sast.sh scan-06-fuzz.sh)
for s in "${AUTO[@]}"; do
  hd "===> $s"; bash "./$s" || warn "$s có lỗi (xem trên)"
done

hd "DAST — chạy riêng"
info "  bash scan-04-dast-baseline.sh   (baseline, live, cần authenticated context)"
info "  bash scan-05-dast-full.sh       (full scan — chạy TRƯỚC ở nhà, chỉ chiếu report)"
hd "XONG"
info "evidence: $EVID   ·   đối chiếu: ~/lab/scripts/ground-truth-app.md"
