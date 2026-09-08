#!/bin/bash
# make-all.sh — dựng toàn bộ lỗ hổng tầng APPLICATION.
#   chạy TRÊN Target, cần quyền docker:  bash make-all.sh
# Muốn demo riêng: bash make-webstack.sh  /  bash make-badimage.sh
# Mã GT-Axx khớp ../../scripts/ground-truth-app.md.
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
need_docker

for s in make-webstack.sh make-badimage.sh; do
  hd "==> $s"; bash "./$s" || warn "$s có lỗi (xem trên)"
done

hd "TỔNG KẾT — container tầng App đang chạy"
docker ps --filter name=lab- --format '  {{.Names}}\t{{.Ports}}' 2>/dev/null
docker images lab/bad-app:demo --format '  image: {{.Repository}}:{{.Tag}} ({{.Size}})' 2>/dev/null
cat <<'TXT'

XONG tầng App. Từ Scanner chạy: ~/lab/scanner/app/run-all.sh
Đối chiếu: ~/lab/scripts/ground-truth-app.md
TXT
