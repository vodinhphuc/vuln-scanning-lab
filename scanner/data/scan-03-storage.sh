#!/bin/bash
# scan-03-storage.sh — Data at rest: bucket public + mini DLP storage sensor (GT-D03/D06).
#   (a) curl bucket MinIO public-read từ Kali -> tải được file backup không cần credential.
#   (b) chạy dlp_scan.py TRÊN target (SSH) quét filesystem + Mongo, chấm FP/FN theo ground truth.
#   bash scan-03-storage.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-03  Storage — bucket public + content inspection ($TARGET)"

info "1) MinIO bucket public-read (GT-D03) — tải file không cần credential:"
code=$(curl -s -o "$EVID/data-03-pii-$TS.csv" -w '%{http_code}' "$URL_MINIO/hocvien-backup/pii.csv" 2>/dev/null)
if [[ "$code" == 200 ]]; then
  ok "tải được $URL_MINIO/hocvien-backup/pii.csv (HTTP 200) -> bucket public!"
  head -3 "$EVID/data-03-pii-$TS.csv" | sed 's/^/    /'
else warn "bucket không trả 200 (http=$code) — đã chạy make-datastores/seed chưa?"; fi

info "2) Mini DLP storage sensor (chạy trên target qua SSH) — content inspection + chấm FP/FN:"
DLP="cd ~/lab && python3 dlp/dlp_scan.py \
  --fs /srv/shared /home/labadmin/tailieu \
  --mongo mongodb://127.0.0.1:27017 \
  --index data/seed/out/pii.json --truth data/seed/out/ground-truth-pii.json \
  --json reports/dlp-report.json"
on_target "$DLP" 2>/dev/null | tee "$EVID/data-03-dlp-$TS.txt" | sed 's/^/    /' \
  && ok "evidence: $EVID/data-03-dlp-$TS.txt" \
  || warn "DLP lỗi — kiểm python3/pymongo trên target + đã seed chưa"
ok "Đây là 'storage sensor' của DLP (slide 48). Network sensor: scan-06-capture; agent sensor: dlp_scan.py --proc"
