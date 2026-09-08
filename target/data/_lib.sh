#!/bin/bash
# _lib.sh — helper chung cho target/data (chạy TRÊN Target, dựng lỗ hổng tầng Data qua Docker).
# KHÔNG 'set -e'. Nạp: source "$(dirname "$0")/_lib.sh"
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # -> thư mục lab/
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
hd()   { printf '\n\033[1;33m== %s ==\033[0m\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
need_docker() {
  command -v docker >/dev/null 2>&1 || { echo "Cần Docker — chạy bootstrap-target.sh trước."; exit 1; }
  docker info >/dev/null 2>&1 || warn "docker cần quyền (nhóm docker / sudo)."
}
