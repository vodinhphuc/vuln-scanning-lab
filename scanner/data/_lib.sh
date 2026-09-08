#!/bin/bash
# _lib.sh — helper chung cho scanner/data (chạy TRÊN Kali).
# Quét mạng (datastore, TLS, bucket) từ Kali vào Target. Các phép cần đứng TRÊN target
# (DLP filesystem, kiểm mã hoá đĩa, bắt gói) thì SSH vào target chạy.
# KHÔNG 'set -e'. Nạp: source "$(dirname "$0")/_lib.sh"

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # -> thư mục lab/
TARGET="${TARGET:-172.16.50.20}"
TARGET_SSH_USER="${TARGET_SSH_USER:-labadmin}"
TARGET_SSH_PASS="${TARGET_SSH_PASS:-LabOnly!2026}"
PORT_MONGO="${PORT_MONGO:-27017}"; PORT_REDIS="${PORT_REDIS:-6379}"
PORT_MINIO="${PORT_MINIO:-9000}"; PORT_HTTPS="${PORT_HTTPS:-8443}"
URL_MINIO="${URL_MINIO:-http://$TARGET:$PORT_MINIO}"
EVID="${EVID:-$HOME/lab/evidence}"; mkdir -p "$EVID"
TS="$(date +%Y%m%d-%H%M%S)"; export TS

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
hd()   { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

on_target() {
  if have sshpass; then
    sshpass -p "$TARGET_SSH_PASS" ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR "$TARGET_SSH_USER@$TARGET" "$@"
  else
    warn "chưa có sshpass — cài: sudo apt-get install -y sshpass"
    ssh -o StrictHostKeyChecking=no "$TARGET_SSH_USER@$TARGET" "$@"
  fi
}
on_target_sudo() { on_target "echo '${TARGET_SSH_PASS}' | sudo -S -p '' $*"; }
