#!/bin/bash
# make-datastores.sh — GT-D01/D02/D03/D04: dựng datastore CỐ TÌNH hở.
#   Mongo no-auth bind_ip_all(27017) · Redis no-pass(6379) · MinIO bucket public-read(9000)
#   · weak-tls nginx(8443, TLS 1.0/1.1 + cipher yếu). minio-init cần seed/out -> sinh PII trước.
#   bash make-datastores.sh   (chạy make-tls.sh trước để có cert cho weak-tls)
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
need_docker

hd "GT-D01/D02/D03/D04  Datastore hở (Mongo · Redis · MinIO · weak-TLS)"

# minio-init upload file backup từ seed/out lúc 'up' -> phải có PII trước
if [[ ! -f "$ROOT/data/seed/out/pii.json" ]]; then
  echo "  sinh PII giả trước (minio-init cần)..."
  python3 "$ROOT/data/seed/gen_pii.py" --count 1000 && ok "đã sinh data/seed/out/*" || warn "gen_pii lỗi (cần python3)"
fi
[[ -f "$ROOT/data/tls/certs/weak.crt" ]] || warn "chưa có cert — chạy make-tls.sh trước, weak-tls sẽ không lên"

docker compose -f "$ROOT/data/docker-compose.yml" up -d \
  && ok "đã up: lab-mongo(27017) · lab-redis(6379) · lab-minio(9000/9001) · lab-weak-tls(8443)" \
  || { warn "compose up lỗi — kiểm image đã pull chưa"; exit 1; }

sleep 4
ok "minio-init đã mở bucket hocvien-backup public-read (xem: docker logs lab-minio-init)"
ok "kiểm chứng: nmap --script mongodb-info,redis-info -p27017,6379 172.16.50.20"
