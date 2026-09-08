#!/bin/bash
# make-webstack.sh — GT-A01/A02/A07/A08: dựng web stack CỐ TÌNH dễ tổn thương.
#   dvwa(8080) target SAST/DAST · juice-shop(3000) · nginx(80) thiếu security header,
#   server_tokens on, autoindex /backup/, phục vụ form clientside.html chỉ validate bằng JS.
# Chạy TRÊN Target, cần quyền docker.
#   bash make-webstack.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
need_docker

hd "GT-A01/A02/A07/A08  Web stack (DVWA · Juice Shop · nginx thiếu header)"
docker compose -f "$ROOT/app/docker-compose.yml" up -d \
  && ok "đã up: lab-dvwa(8080) · lab-juice(3000) · lab-nginx(80)" \
  || { warn "compose up lỗi — kiểm tra image đã pull chưa (bootstrap-target.sh)"; exit 1; }

# DVWA cần bấm Create/Reset Database một lần (có CSRF token)
echo "  khởi tạo DVWA database..."
sleep 6
tok=$(curl -s -c /tmp/dvwa.cookie "http://localhost:8080/setup.php" \
      | grep -oE "user_token'[^a-f0-9]*[a-f0-9]{32}" | grep -oE '[a-f0-9]{32}' | head -1)
if [[ -n "${tok:-}" ]]; then
  curl -s -b /tmp/dvwa.cookie \
    --data "create_db=Create+%2F+Reset+Database&user_token=${tok}" \
    "http://localhost:8080/setup.php" >/dev/null 2>&1 \
    && ok "DVWA database đã khởi tạo" || warn "khởi tạo DVWA lỗi — vào setup.php bấm tay"
else
  warn "không lấy được CSRF token — vào http://172.16.50.20:8080/setup.php bấm 'Create / Reset Database' tay"
fi
rm -f /tmp/dvwa.cookie
ok "kiểm chứng header: curl -sI http://172.16.50.20/ | grep -iE 'server:|content-security|x-frame'"
ok "kiểm chứng autoindex: curl -s http://172.16.50.20/backup/  (sau khi seed data tier)"
