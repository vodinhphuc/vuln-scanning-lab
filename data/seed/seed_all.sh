#!/bin/bash
# seed_all.sh — nạp dữ liệu PII giả vào MongoDB, Redis và web root.
# Chạy TRÊN VM Target Linux, SAU khi `docker compose -f data/docker-compose.yml up -d`.
#
#   bash data/seed/seed_all.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/out"
APP_WEBROOT="$(cd "$HERE/../../app/nginx/webroot" && pwd)"

[[ -f "$OUT/pii.json" ]] || python3 "$HERE/gen_pii.py" --count 1000

echo "==> [1/4] Nap 1000 ban ghi PII vao MongoDB (khong auth)"
docker cp "$OUT/pii.json" lab-mongo:/tmp/pii.json
docker exec lab-mongo mongoimport \
  --db hocvien --collection hoc_vien --jsonArray --drop --file /tmp/pii.json
docker exec lab-mongo mongosh --quiet --eval \
  'print("  hoc_vien: " + db.getSiblingDB("hocvien").hoc_vien.countDocuments() + " ban ghi")'

echo "==> [2/4] Nap mot phan vao Redis (khong requirepass)"
docker exec lab-redis redis-cli SET app:db:password 'P@ssw0rd-lab-2026' >/dev/null
docker exec lab-redis redis-cli SET app:jwt:key 'b7f3c1e9a4d25086f1c3b7a9e2d4c608' >/dev/null
python3 - "$OUT/pii.json" <<'PY' | docker exec -i lab-redis redis-cli --pipe >/dev/null
import json, sys
rows = json.load(open(sys.argv[1], encoding="utf-8"))
for r in rows[:200]:
    print(f'SET hv:{r["ma_hoc_vien"]} "{r["ho_ten"]}|{r["cccd"]}|{r["so_dien_thoai"]}"')
PY
echo "  redis keys: $(docker exec lab-redis redis-cli DBSIZE)"

echo "==> [3/4] Dat backup .sql khong ma hoa vao web root (autoindex dang bat)"
mkdir -p "$APP_WEBROOT/backup"
cp "$OUT/hocvien-backup.sql" "$APP_WEBROOT/backup/"
cp "$OUT/pii.csv"            "$APP_WEBROOT/backup/"
chmod 644 "$APP_WEBROOT/backup/"*
echo "  -> http://172.16.50.20/backup/"

echo "==> [4/4] Rai file PII tren filesystem cho storage sensor quet"
sudo mkdir -p /srv/shared/hosokhoahoc /home/labadmin/tailieu
sudo cp "$OUT/pii.csv" /srv/shared/hosokhoahoc/danhsach-hocvien.csv
sudo cp "$OUT/hocvien-backup.sql" /home/labadmin/tailieu/backup-2026.sql
sudo chmod 777 /srv/shared/hosokhoahoc/danhsach-hocvien.csv   # quyen qua rong, co tinh
echo "  -> /srv/shared/hosokhoahoc/ va /home/labadmin/tailieu/"

echo
echo "Xong. Nho: minio-init da tu dong upload backup len bucket public-read."
echo "Kiem chung nhanh:"
echo "  mongosh --host 172.16.50.20 --eval 'db.getSiblingDB(\"hocvien\").hoc_vien.findOne()'"
echo "  curl -s http://172.16.50.20:9000/hocvien-backup/pii.csv | head -3"
