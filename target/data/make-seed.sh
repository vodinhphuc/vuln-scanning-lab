#!/bin/bash
# make-seed.sh — GT-D06: nạp PII giả vào datastore + web root + filesystem (data at rest).
#   Cần datastore ĐÃ UP (make-datastores.sh) vì seed_all nạp vào lab-mongo/lab-redis.
#   Có bước ghi /srv/shared + /home/labadmin nên seed_all tự dùng sudo.
#   bash make-seed.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
need_docker

hd "GT-D06  Nạp PII giả (Mongo · Redis · web /backup · filesystem)"
if ! docker ps --format '{{.Names}}' | grep -qx lab-mongo; then
  warn "lab-mongo chưa chạy — chạy make-datastores.sh trước."; exit 1
fi
bash "$ROOT/data/seed/seed_all.sh" \
  && ok "đã nạp PII (dữ liệu BỊA hoàn toàn — gen_pii.py seed cố định)" \
  || warn "seed_all lỗi (xem log)"
ok "kiểm chứng: curl -s http://172.16.50.20:9000/hocvien-backup/pii.csv | head -3"
