#!/bin/bash
# scan-05-gvm-auth.sh — QUÉT TỪ XA (Kali): Greenbone/GVM CÓ SSH credential.
# Đọc được danh sách gói -> thấy TOÀN BỘ missing patch (GT-H10) + GT-H04 (weak cred).
# Chênh lệch số finding so với scan-04 = slide đắt giá nhất tầng Host (brief mục 4.3).
#   bash scan-05-gvm-auth.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-05  GVM authenticated ($TARGET, SSH cred)"
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9392 2>/dev/null)
[[ "$code" =~ ^(200|302|303)$ ]] && ok "GVM Web UI sống: http://127.0.0.1:9392 (admin/labadmin)" \
  || warn "GVM chưa sẵn sàng (http_code=$code)."

# Kiểm SSH cred dùng được trước khi cắm vào GVM (đỡ mất công tạo task rồi fail auth)
if on_target "echo SSH-OK" 2>/dev/null | grep -q SSH-OK; then
  ok "SSH tới $TARGET_SSH_USER@$TARGET dùng được — cred hợp lệ để GVM authenticated"
else warn "SSH thử thất bại — kiểm tra user/pass trong _lib.sh trước khi cắm vào GVM"; fi

cat <<TXT

  TẠO CREDENTIAL trong Web UI → Configuration → Credentials → New:
    • Type      : Username + Password  (SSH)
    • Username  : $TARGET_SSH_USER
    • Password  : $TARGET_SSH_PASS

  TẠO TASK giống scan-04 NHƯNG gắn credential SSH vừa tạo vào Target ($TARGET).
    • Scan Config : Full and fast
    • SSH Cred    : $TARGET_SSH_USER  ← khác biệt duy nhất so với scan-04

  KỲ VỌNG: số lỗ hổng TĂNG MẠNH — GVM đăng nhập, liệt kê gói, đối chiếu CVE ->
  thấy missing patch (GT-H10) mà bản unauth (scan-04) mù hoàn toàn.

  Export về ~/lab/evidence/host-05-gvm-auth.*  và điền bảng:
    | Lần quét   | Cổng/service | Missing patch | Tổng finding |
    | unauth(04) |      ✓       |      ✗        |    (ghi)     |
    | auth  (05) |      ✓       |      ✓        |    (ghi)     |
TXT
ok "Chênh lệch auth − unauth = 'giá trị của credential' — verification cho patch mgmt"
