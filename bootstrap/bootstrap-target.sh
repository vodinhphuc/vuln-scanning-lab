#!/bin/bash
# bootstrap-target.sh — chạy TRÊN VM Target Linux (Ubuntu 22.04 LTS, 172.16.50.20)
# KHI CÒN NAT.
#
#   sudo -v && bash bootstrap-target.sh
#
# Script này CHỈ tải và cài công cụ + image. Nó KHÔNG tạo lỗ hổng —
# việc đó là PHASE 1A, làm SAU khi đã snapshot "clean-install".
# Chạy lại được nhiều lần.
set -uo pipefail

FAILED=()
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
skip() { printf '    Đã có: %s\n' "$*"; }
fail() { printf '\033[1;31m    LỖI: %s\033[0m\n' "$*"; FAILED+=("$*"); }

step "[0/7] Kiểm tra Internet (script này CẦN NAT đang bật)"
curl -sfI --max-time 8 https://github.com >/dev/null || {
  echo "    Không ra được Internet. Bật Network Adapter NAT rồi chạy lại."; exit 1; }
echo "    OK  —  $(lsb_release -ds 2>/dev/null)"

# ─────────────────────────────────────────────────────────────────────────────
# labadmin PHẢI tồn tại: 00-env.sh và seed_all.sh đều trỏ tới nó (SSH + /home/labadmin).
# Khai tay ở đây vì 00-env.sh dùng `set -e`, source vào sẽ phá `set -uo` của script này.
LAB_USER="labadmin"
LAB_PASS="LabOnly!2026"      # == 00-env.sh TARGET_SSH_USER / TARGET_SSH_PASS
step "[1/7] Tài khoản lab '${LAB_USER}' + SSH (để scan/thao tác reproducible, thoát console đen)"
if id "$LAB_USER" >/dev/null 2>&1; then
  skip "user $LAB_USER"
else
  sudo useradd -m -s /bin/bash "$LAB_USER" || fail "useradd $LAB_USER"
  echo "${LAB_USER}:${LAB_PASS}" | sudo chpasswd || fail "chpasswd $LAB_USER"
  sudo usermod -aG sudo "$LAB_USER"
  echo "    Đã tạo $LAB_USER (mật khẩu yếu + trong nhóm sudo = hardening ground truth)"
fi
if dpkg -l openssh-server 2>/dev/null | grep -q '^ii'; then skip "openssh-server"; else
  sudo apt-get install -y openssh-server || fail "openssh-server"
fi
sudo systemctl enable --now ssh 2>/dev/null || fail "bật ssh"
echo "    SSH sẵn sàng — từ máy thật: ssh ${LAB_USER}@172.16.50.20"

# ─────────────────────────────────────────────────────────────────────────────
step "[2/7] Docker Engine (repo chính thức, KHÔNG dùng snap)"
if have docker && docker compose version >/dev/null 2>&1; then
  skip "docker + compose plugin"
else
  sudo apt-get update -qq
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -qq
  # Ubuntu -> docker-ce (repo chính chủ). Nếu lỗi (distro không phải Ubuntu, vd Debian/Kali
  # không có codename trên download.docker.com) -> rơi về docker.io của kho hệ điều hành.
  if ! sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
         docker-buildx-plugin docker-compose-plugin; then
    echo "    docker-ce không cài được -> thử docker.io (Debian/Kali)"
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo apt-get update -qq
    sudo apt-get install -y docker.io docker-compose-v2 \
      || sudo apt-get install -y docker.io docker-compose \
      || fail "docker"
  fi
  sudo usermod -aG docker "$USER"
  echo "    !! Đăng xuất/đăng nhập lại (hoặc: newgrp docker) để dùng docker không cần sudo."
fi
# Luôn đảm bảo service bật (idempotent) — tránh 'Unit docker.service does not exist'
sudo systemctl enable --now docker >/dev/null 2>&1 \
  || fail "docker.service không bật được (kiểm tra bước cài docker phía trên)"

# ─────────────────────────────────────────────────────────────────────────────
step "[3/7] Kéo TOÀN BỘ image (bắt buộc — lúc demo không có mạng)"
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
for img in "${IMAGES[@]}"; do
  if sudo docker image inspect "$img" >/dev/null 2>&1; then skip "$img"; else
    echo "    pull $img"
    sudo docker pull -q "$img" || fail "pull $img"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
step "[4/7] Lynis (audit hardening, chạy tại chỗ trên host)"
if have lynis; then skip "lynis $(lynis show version 2>/dev/null)"; else
  sudo apt-get install -y lynis || fail "lynis"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Bám đúng phiên bản Ubuntu đang chạy thay vì đoán (22.04 -> "2204").
UB_VER=$(. /etc/os-release && echo "${VERSION_ID//./}")   # 22.04 -> 2204
step "[5/7] OpenSCAP + SCAP content cho Ubuntu ${UB_VER}"

# 22.04 (jammy): binary `oscap` nằm trong libopenscap8.
# 24.04 trở đi: libopenscap8 bị bỏ, `oscap` chuyển sang openscap-scanner.
if have oscap; then skip "oscap $(oscap --version 2>/dev/null | head -1)"; else
  sudo apt-get install -y libopenscap8 \
    || sudo apt-get install -y openscap-scanner openscap-common \
    || fail "openscap (libopenscap8 / openscap-scanner)"
fi

SSG_DIR=/usr/share/xml/scap/ssg/content
# ssg-debderived = SCAP content cho Debian/Ubuntu (nằm ở universe)
sudo apt-get install -y ssg-debderived ssg-base 2>/dev/null \
  || sudo apt-get install -y scap-security-guide 2>/dev/null || true

DS=$(ls "$SSG_DIR"/ssg-ubuntu${UB_VER}-ds.xml 2>/dev/null | head -1)
if [[ -z "${DS:-}" ]]; then
  echo "    Repo không có ssg-ubuntu${UB_VER}-ds.xml -> tải từ ComplianceAsCode"
  SSG_VER=$(curl -sf https://api.github.com/repos/ComplianceAsCode/content/releases/latest \
            | grep -Po '"tag_name": "v\K[^"]+')
  SSG_VER="${SSG_VER:-0.1.76}"
  TMP=$(mktemp -d)
  if curl -sSfL -o "$TMP/ssg.zip" \
      "https://github.com/ComplianceAsCode/content/releases/download/v${SSG_VER}/scap-security-guide-${SSG_VER}.zip"; then
    sudo apt-get install -y unzip >/dev/null
    unzip -qo "$TMP/ssg.zip" -d "$TMP"
    sudo mkdir -p "$SSG_DIR"
    sudo cp "$TMP"/scap-security-guide-*/ssg-ubuntu*.xml "$SSG_DIR"/ 2>/dev/null \
      || fail "không thấy ssg-ubuntu*.xml trong bản tải về"
    echo "    Đã cài SCAP content v$SSG_VER"
  else
    fail "tải SCAP content"
  fi
  rm -rf "$TMP"
fi

DS=$(ls "$SSG_DIR"/ssg-ubuntu${UB_VER}-ds.xml 2>/dev/null \
     || ls "$SSG_DIR"/ssg-ubuntu2*-ds.xml 2>/dev/null | head -1)
if [[ -n "${DS:-}" ]]; then
  echo "    Datastream: $DS"
  echo "    Các profile dùng được (chọn 1 cho host-03-openscap.sh):"
  oscap info "$DS" 2>/dev/null | grep -A100 'Profiles:' | grep 'Id:' | sed 's/^/      /'
else
  fail "KHÔNG có SCAP datastream — demo 'score trước/sau' sẽ hỏng, xử lý sớm"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "[6/7] ClamAV (cho màn EICAR) + tải sẵn .deb cho PHASE 1A"
if have clamscan; then skip clamav; else
  sudo apt-get install -y clamav clamav-freshclam || fail "clamav"
fi
sudo systemctl stop clamav-freshclam 2>/dev/null
sudo freshclam 2>&1 | tail -2 || echo "    (freshclam có thể báo 'already up to date')"
sudo systemctl start clamav-freshclam 2>/dev/null

# Tải trước .deb cho các service thừa sẽ cài ở PHASE 1A, để lúc mất mạng vẫn cài được
echo "    Tải trước gói cho PHASE 1A (chưa cài):"
sudo apt-get install -y --download-only \
     vsftpd rpcbind telnetd inetutils-telnetd apache2 2>/dev/null | tail -1
echo "    .deb nằm ở /var/cache/apt/archives/ — cài offline bằng: sudo dpkg -i <file>.deb"

# ─────────────────────────────────────────────────────────────────────────────
step "[7/7] Tiện ích client để tự kiểm chứng"
sudo apt-get install -y curl jq net-tools redis-tools python3-pip python3-venv \
     openssl ca-certificates >/dev/null 2>&1 || fail "tiện ích"
python3 -m pip install --break-system-packages --quiet pymongo 2>/dev/null \
  || pipx install pymongo 2>/dev/null || echo "    (pymongo: cài sau trong venv nếu cần)"

# ─────────────────────────────────────────────────────────────────────────────
printf '\n\033[1;36m════════ TỔNG KẾT ════════\033[0m\n'
printf '  %-12s %s\n' labadmin "$(id labadmin >/dev/null 2>&1 && echo ✅ || echo ❌)"
printf '  %-12s %s\n' ssh "$(systemctl is-active ssh >/dev/null 2>&1 && echo ✅ || echo ❌)"
for t in docker lynis oscap clamscan curl jq; do
  printf '  %-12s %s\n' "$t" "$(have "$t" && echo ✅ || echo ❌)"
done
printf '  %-12s %s image\n' images "$(sudo docker images -q | sort -u | wc -l)"
printf '  %-12s %s\n' SCAP "$(ls /usr/share/xml/scap/ssg/content/ssg-ubuntu2*-ds.xml 2>/dev/null | head -1 || echo ❌)"
if ((${#FAILED[@]})); then
  printf '\n\033[1;31mCÁC BƯỚC LỖI: %s\033[0m\n' "${FAILED[*]}"
fi
cat <<'TXT'

TIẾP THEO:
  1. Copy thư mục lab/ sang máy này (xem README)
  2. Chụp snapshot VM: "clean-install"   <-- LÀM TRƯỚC KHI TẠO LỖ HỔNG
  3. Rồi mới chạy PHASE 1A (tạo lỗ hổng có chủ đích)
TXT
