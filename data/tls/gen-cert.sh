#!/bin/bash
# Sinh self-signed certificate CỐ TÌNH yếu cho endpoint data-in-transit.
# Chạy MỘT LẦN trước `docker compose up`:  bash data/tls/gen-cert.sh
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p certs

# CỐ TÌNH: RSA 1024-bit (dưới ngưỡng khuyến nghị 2048), SHA-1, hết hạn sau 30 ngày,
# CN không khớp hostname thật -> testssl.sh sẽ báo cả 4 vấn đề.
openssl req -x509 -nodes \
  -newkey rsa:1024 \
  -sha1 \
  -days 30 \
  -keyout certs/weak.key \
  -out    certs/weak.crt \
  -subj "/C=VN/ST=Hanoi/L=Hanoi/O=Lab Only/CN=wrong-hostname.lab.invalid" \
  2>/dev/null

chmod 644 certs/weak.key   # [DATA-05] private key quyền quá rộng — Lynis sẽ báo
echo "Da sinh certs/weak.crt va certs/weak.key (RSA-1024, SHA-1, CN sai, 30 ngay)"
openssl x509 -in certs/weak.crt -noout -subject -dates
