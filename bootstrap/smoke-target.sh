#!/bin/bash
# smoke-target.sh — kiểm tool/dịch vụ trên Target Ubuntu CHẠY ĐƯỢC trước khi snapshot.
# Trạng thái đúng để chạy: SAU bootstrap-target.sh, TRƯỚC target/host/make-all.sh (PHASE 1A)
# (các container app/data CHƯA cần bật ở bước này).
#   bash bootstrap/smoke-target.sh
# Exit 0 = không FAIL (snapshot 'clean-install' được). Exit 1 = còn FAIL, xử lý khi CÒN NAT.
set -uo pipefail

PASS=0; FAIL=0; WARN=0
ok()   { printf '  \033[1;32m✅ %s\033[0m\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[1;31m❌ %s\033[0m\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[1;33m⚠️  %s\033[0m\n' "$*"; WARN=$((WARN+1)); }
sec()  { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

sec "Tài khoản lab + SSH"
id labadmin >/dev/null 2>&1 && ok "user labadmin tồn tại" || bad "labadmin chưa tạo"
systemctl is-active ssh >/dev/null 2>&1 && ok "sshd đang chạy" || bad "sshd không active"
ip -4 addr | grep -q '172\.16\.50\.' && ok "có IP host-only 172.16.50.x" || warn "chưa thấy IP host-only"

sec "Docker + image (lúc demo không có mạng nên phải đủ image)"
sudo docker info >/dev/null 2>&1 && ok "docker daemon" || bad "docker daemon"
IMAGES=(
  vulnerables/web-dvwa:latest
  bkimminich/juice-shop:latest
  nginx:1.21
  mongo:6.0
  redis:7.0
  minio/minio:RELEASE.2023-05-04T21-44-30Z
  minio/mc:RELEASE.2023-05-04T18-10-16Z
  python:3.9-slim-bullseye
)
miss=0
for img in "${IMAGES[@]}"; do
  sudo docker image inspect "$img" >/dev/null 2>&1 || { warn "thiếu image: $img"; miss=$((miss+1)); }
done
((miss==0)) && ok "đủ 8 image lab" || bad "thiếu $miss image — kéo khi CÒN NAT"
if sudo docker image inspect python:3.9-slim-bullseye >/dev/null 2>&1; then
  sudo docker run --rm python:3.9-slim-bullseye python -c "print('ok')" 2>/dev/null | grep -q ok \
    && ok "docker chạy container (từ image local)" || bad "docker không chạy được container"
fi

sec "Lynis (audit hardening)"
lynis show version >/dev/null 2>&1 && ok "lynis $(lynis show version 2>/dev/null)" || bad "lynis"

sec "OpenSCAP + SCAP content — chạy thử 1 eval thật"
oscap --version >/dev/null 2>&1 && ok "oscap" || bad "oscap"
DS=$(find /usr/share/xml/scap/ssg/content -name 'ssg-ubuntu2*-ds.xml' 2>/dev/null | head -1)
if [[ -n "$DS" ]]; then
  ok "SCAP datastream: $(basename "$DS")"
  PID=$(oscap info "$DS" 2>/dev/null | grep -A300 'Profiles:' | awk '/Id:/{print $2; exit}')
  if [[ -n "$PID" ]]; then
    sudo oscap xccdf eval --profile "$PID" --results /tmp/oscap-smoke.xml "$DS" >/dev/null 2>&1
    # oscap trả != 0 khi CÓ rule fail -> vẫn là 'chạy được'; chỉ hỏng nếu không ra file kết quả
    [[ -s /tmp/oscap-smoke.xml ]] \
      && ok "oscap eval chạy được (profile: ${PID##*_profile_})" \
      || bad "oscap eval không ra kết quả — content/oscap không khớp"
    sudo rm -f /tmp/oscap-smoke.xml   # file do 'sudo oscap' tạo -> owner root, cần sudo mới xoá
  else warn "không tách được profile id để test eval"; fi
else bad "thiếu SCAP datastream — demo 'score trước/sau' sẽ hỏng"; fi

sec "ClamAV + EICAR (chuỗi test chuẩn, KHÔNG phải virus thật)"
clamscan --version >/dev/null 2>&1 && ok "clamscan" || bad "clamscan"
ls /var/lib/clamav/*.c[lv]d >/dev/null 2>&1 && ok "ClamAV DB có sẵn" \
  || warn "ClamAV DB trống — chạy 'sudo freshclam' khi CÒN NAT"
EIC=/tmp/eicar-smoke.txt
# Viết EICAR qua base64 để tránh MỌI rủi ro quoting của shell (%, \, $, ! trong chuỗi gốc)
base64 -d > "$EIC" <<'B64'
WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo=
B64
# clamscan THOÁT MÃ 1 khi tìm thấy virus -> KHÔNG đặt trong 'if cmd | grep' vì
# pipefail sẽ coi cả pipeline là lỗi. Hứng output ra biến rồi grep tách riêng.
clam_out=$(clamscan --no-summary "$EIC" 2>/dev/null)
if printf '%s' "$clam_out" | grep -q 'FOUND'; then
  ok "clamscan bắt được EICAR (engine + DB hoạt động)"
else bad "clamscan KHÔNG bắt EICAR — chạy 'sudo freshclam' (DB có thể thiếu chữ ký)"; fi
rm -f "$EIC"

sec "Tiện ích client để tự kiểm chứng"
for t in curl jq redis-cli openssl; do
  command -v "$t" >/dev/null 2>&1 && ok "$t" || warn "$t chưa cài"
done
python3 -c "import pymongo" 2>/dev/null && ok "python3 + pymongo (cho DLP/mongo)" \
  || warn "pymongo chưa có — cài trong venv khi cần"

printf '\n\033[1;36m════════ KẾT QUẢ ════════\033[0m\n'
printf '  PASS=%d   FAIL=%d   WARN=%d\n' "$PASS" "$FAIL" "$WARN"
if ((FAIL)); then
  printf '\033[1;31m  CHƯA nên snapshot — còn %d mục lỗi. Xử lý khi CÒN NAT rồi chạy lại.\033[0m\n' "$FAIL"
  exit 1
fi
printf '\033[1;32m  OK — tool/dịch vụ đều chạy. Snapshot "clean-install" được (TRƯỚC PHASE 1A).\033[0m\n'
printf '     (WARN chỉ là nhắc nhở, không chặn snapshot.)\n'
exit 0
