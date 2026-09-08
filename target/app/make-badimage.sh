#!/bin/bash
# make-badimage.sh — GT-A03/A04/A05/A06: build image "xấu" lab/bad-app:demo.
#   Đây là ARTIFACT cho config scan (Dockerfile BAD-01..10), SCA (dependency CVE),
#   SAST (app.py SAST-01..07) và secret scan (.env + ENV secret trong layer).
# Chạy TRÊN Target, cần quyền docker. Base image python:3.9-slim-bullseye phải đã pull.
#   bash make-badimage.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
need_docker

hd "GT-A03/A04/A05/A06  Build image xấu lab/bad-app:demo"
if docker build -t lab/bad-app:demo "$ROOT/app/bad-image"; then
  ok "đã build lab/bad-app:demo"
else
  warn "build lỗi — nếu offline: base image python:3.9-slim-bullseye phải được pull lúc CÒN NAT"
fi
ok "kiểm chứng secret trong layer: docker history --no-trunc lab/bad-app:demo | grep -i secret"
ok "kiểm chứng misconfig: trivy config $ROOT/app/bad-image  (chạy trên Kali cũng được)"
