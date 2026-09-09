#!/bin/bash
# scan-06-container-vs-vm.sh — AUDIT TẠI CHỖ (qua SSH): so bề mặt audit container vs VM.
# Ý tưởng: chạy Lynis TRONG một container tối giản rồi so số test với Lynis trên VM.
# Container ít service/ít cấu hình -> Lynis chạy được ít test hơn -> minh hoạ "thu hẹp
# attack surface" của container so với full VM (slide host security).
#   bash scan-06-container-vs-vm.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-06  Container vs VM — số test Lynis"

info "1) Lynis trên VM (host đầy đủ) — lấy 'Tests performed':"
VM_TESTS=$(on_target_sudo "lynis audit system --quick --no-colors 2>/dev/null | grep 'Tests performed' | grep -oE '[0-9]+' | head -1")
info "    số test đã chạy trên VM: ${VM_TESTS:-?}"

info "2) Lynis trong container tối giản (cần image + mạng để cài lynis):"
CTEST=""
if on_target "docker image inspect ubuntu:22.04 >/dev/null 2>&1"; then
  CTEST=$(on_target_sudo "docker run --rm ubuntu:22.04 bash -c \
    'apt-get update -qq >/dev/null 2>&1 && apt-get install -y -q lynis >/dev/null 2>&1 && \
     lynis audit system --quick --no-colors 2>/dev/null | grep \"Tests performed\" | grep -oE \"[0-9]+\" | head -1'" 2>/dev/null)
  info "    số test trong container: ${CTEST:-? (cài lynis trong container cần NAT)}"
else
  warn "target chưa có image ubuntu:22.04 — bỏ qua phần container (kéo khi CÒN NAT: docker pull ubuntu:22.04)"
fi

cat <<TXT

  Ý NGHĨA: container thường chạy ÍT test hơn (không có bootloader, ít service,
  không kernel-module riêng...) -> bề mặt cấu hình cần hardening nhỏ hơn VM.
  Đây là góc nhìn "cùng một công cụ, hai môi trường" cho slide host security.
TXT
ok "Ghi cả hai số vào evidence/slide: VM=${VM_TESTS:-?}  container=${CTEST:-?}"
