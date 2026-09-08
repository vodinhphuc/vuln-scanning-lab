#!/bin/bash
# scan-01-datastore.sh — Data at rest: datastore không xác thực (GT-D01/D02/D03).
#   nmap NSE hỏi chính giao thức của Mongo/Redis; nếu trả lời không cần credential -> chưa bật auth.
#   bash scan-01-datastore.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
have nmap || { warn "thiếu nmap"; exit 1; }

hd "scan-01  Datastore không auth ($TARGET)"
OUT="$EVID/data-01-nmap-$TS"
sudo nmap -sV -p "$PORT_MONGO,$PORT_REDIS,$PORT_MINIO" \
  --script mongodb-info,mongodb-databases,redis-info -oA "$OUT" "$TARGET" 2>/dev/null \
  | grep -iE 'open|mongodb|redis|version|databases|no password|auth' | sed 's/^/    /'
ok "evidence: ${OUT}.nmap"

info "Xác minh thủ công (không cần credential):"
if have mongosh; then
  timeout 10 mongosh "mongodb://$TARGET:$PORT_MONGO" --quiet --eval \
    'db.getSiblingDB("hocvien").hoc_vien.countDocuments()' 2>/dev/null \
    | sed 's/^/    hoc_vien count = /' && ok "Mongo vào thẳng không cần auth (GT-D01)" || warn "mongosh không kết nối được"
else info "    (không có mongosh) mongosh mongodb://$TARGET:$PORT_MONGO"
fi
if have redis-cli; then
  timeout 8 redis-cli -h "$TARGET" -p "$PORT_REDIS" GET app:db:password 2>/dev/null \
    | sed 's/^/    redis GET app:db:password = /' && ok "Redis đọc được không cần pass (GT-D02)" || warn "redis-cli không kết nối"
else info "    (không có redis-cli) redis-cli -h $TARGET GET app:db:password"
fi
ok "GT-D03 (MinIO public) — xem scan-03-storage.sh"
