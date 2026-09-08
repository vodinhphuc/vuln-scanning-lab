#!/bin/bash
# _lib.sh — helper chung cho scanner/app (chạy TRÊN Kali).
# Source code lab CÓ SẴN trên Kali (repo scp về) -> config/SCA/SAST/secret quét CỤC BỘ, offline.
# DAST và kiểm header quét vào app ĐANG CHẠY trên Target.
# KHÔNG 'set -e'. Nạp: source "$(dirname "$0")/_lib.sh"

ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # -> thư mục lab/
TARGET="${TARGET:-172.16.50.20}"
URL_DVWA="${URL_DVWA:-http://$TARGET:8080}"
URL_NGINX="${URL_NGINX:-http://$TARGET}"
EVID="${EVID:-$HOME/lab/evidence}"; mkdir -p "$EVID"
TS="$(date +%Y%m%d-%H%M%S)"; export TS

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
hd()   { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
