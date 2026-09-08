#!/bin/bash
# 00-env.sh — khai báo môi trường lab. MỌI script khác đều `source` file này.
# Dùng: source ~/lab/00-env.sh
set -euo pipefail

# --- Mạng lab (VMnet Host-only, không NAT ra Internet trong lúc demo) --------
export LAB_NET="172.16.50.0/24"
export SCANNER_IP="172.16.50.10"
export TARGET_LINUX="172.16.50.20"
export TARGET_WIN="172.16.50.30"
export TARGET_MSF="172.16.50.40"          # Metasploitable2 (tuỳ chọn)

# --- Credential cho authenticated scan (chỉ tồn tại trong lab) --------------
export TARGET_SSH_USER="labadmin"
export TARGET_SSH_PASS="LabOnly!2026"       # dữ liệu lab, không dùng ở nơi khác

# --- Cổng dịch vụ trên VM Target Linux --------------------------------------
export PORT_NGINX=80                        # reverse proxy (thiếu security header)
export PORT_DVWA=8080
export PORT_JUICE=3000
export PORT_HTTPS=8443                      # TLS yếu, self-signed
export PORT_MONGO=27017
export PORT_REDIS=6379
export PORT_MINIO=9000
export PORT_MINIO_CONSOLE=9001

export URL_DVWA="http://${TARGET_LINUX}:${PORT_DVWA}"
export URL_JUICE="http://${TARGET_LINUX}:${PORT_JUICE}"
export URL_NGINX="http://${TARGET_LINUX}:${PORT_NGINX}"

# --- Thư mục bằng chứng ------------------------------------------------------
export LAB_ROOT="${LAB_ROOT:-$HOME/lab}"
export EVIDENCE_DIR="${LAB_ROOT}/evidence"
export REPORT_DIR="${LAB_ROOT}/reports"
export SCRIPT_DIR="${LAB_ROOT}/scripts"
mkdir -p "$EVIDENCE_DIR" "$REPORT_DIR"

# --- Tiện ích in tiêu đề (mỗi script gọi `banner` để màn chiếu sạch) --------
banner() {
  printf '\n\033[1;36m%s\033[0m\n' "════════════════════════════════════════════════════════════"
  printf '\033[1;36m  %s\033[0m\n' "$*"
  printf '\033[1;36m%s\033[0m\n\n' "════════════════════════════════════════════════════════════"
}
export -f banner

# Dấu thời gian dùng đặt tên file bằng chứng
export TS="$(date +%Y%m%d-%H%M%S)"
