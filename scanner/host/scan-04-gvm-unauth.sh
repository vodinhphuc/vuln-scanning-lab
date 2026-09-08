#!/bin/bash
# scan-04-gvm-unauth.sh — QUÉT TỪ XA (Kali): Greenbone/GVM KHÔNG credential.
# Chỉ thấy thứ lộ ra mạng: GT-H05 (ftp-anon), GT-H06 (telnet/rpcbind), version cũ.
# GVM chạy trong container + điều khiển qua Web UI, nên script này KIỂM TRA sẵn sàng
# rồi HƯỚNG DẪN tham số quét — không cố tự động hoá GUI (giữ cho demo chắc chắn chạy).
#   bash scan-04-gvm-unauth.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-04  GVM unauthenticated ($TARGET)"
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9392 2>/dev/null)
[[ "$code" =~ ^(200|302|303)$ ]] && ok "GVM Web UI sống: http://127.0.0.1:9392 (admin/labadmin)" \
  || { warn "GVM chưa sẵn sàng (http_code=$code). Xem bootstrap-scanner.sh / docker logs gvmd"; }

cat <<TXT

  THAM SỐ QUÉT (nhập trong Web UI → Scans → Tasks → New Task):
    • Target host      : $TARGET
    • Port list        : All IANA assigned TCP
    • Scan Config      : Full and fast
    • Credential (SSH) : (ĐỂ TRỐNG — đây là bản unauthenticated)

  KỲ VỌNG: GVM chỉ báo lỗ hổng nhìn thấy từ ngoài — service thừa, phiên bản cũ,
  ftp anonymous. KHÔNG thấy missing-patch cấp gói (cần credential — xem scan-05).

  Sau khi task xong: Reports → export PDF/XML về ~/lab/evidence/host-04-gvm-unauth.*
  GHI LẠI số lỗ hổng (theo mức) để so với scan-05.
TXT
ok "Đây là 'trước' của cặp so sánh unauth ↔ auth (điểm nhấn tầng Host)"
