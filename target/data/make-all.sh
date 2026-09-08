#!/bin/bash
# make-all.sh — dựng toàn bộ lỗ hổng tầng DATA, đúng thứ tự phụ thuộc.
#   tls (cert) -> datastores (Mongo/Redis/MinIO/weak-TLS + sinh PII) -> seed (nạp dữ liệu).
#   chạy TRÊN Target, cần quyền docker:  bash make-all.sh
# Mã GT-Dxx khớp ../../scripts/ground-truth-data.md.
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
need_docker

for s in make-tls.sh make-datastores.sh make-seed.sh; do
  hd "==> $s"; bash "./$s" || warn "$s có lỗi (xem trên)"
done

hd "TỔNG KẾT — container tầng Data đang chạy"
docker ps --filter name=lab- --format '  {{.Names}}\t{{.Ports}}' 2>/dev/null | grep -E 'mongo|redis|minio|weak-tls'
cat <<'TXT'

XONG tầng Data. Từ Scanner chạy: ~/lab/scanner/data/run-all.sh
Đối chiếu: ~/lab/scripts/ground-truth-data.md
TXT
