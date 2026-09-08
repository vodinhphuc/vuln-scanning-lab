#!/bin/bash
# bootstrap-scanner.sh — chạy TRÊN VM Scanner (Kali, 172.16.50.10) KHI CÒN NAT.
#
#   sudo -v && bash bootstrap-scanner.sh
#
# Việc đầu tiên script làm là kick GVM feed sync chạy nền, vì đó là đường
# găng (1-3 tiếng wall-clock). Mọi thứ còn lại tải trong lúc nó sync.
# Chạy lại được nhiều lần: mỗi bước tự kiểm tra trước khi cài.
set -uo pipefail        # KHÔNG dùng -e: một tool lỗi không nên chặn các tool sau

GVM_PASS="${GVM_PASS:-labadmin}"
BIN=/usr/local/bin
FAILED=()

step()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
have()  { command -v "$1" >/dev/null 2>&1; }
skip()  { printf '    Đã có: %s\n' "$*"; }
fail()  { printf '\033[1;31m    LỖI: %s\033[0m\n' "$*"; FAILED+=("$*"); }

# ─────────────────────────────────────────────────────────────────────────────
step "[0/8] Kiểm tra có Internet không (script này CẦN NAT đang bật)"
if ! curl -sfI --max-time 8 https://github.com >/dev/null; then
  echo "    Không ra được Internet. Bật lại Network Adapter NAT rồi chạy lại."
  exit 1
fi
echo "    OK"

# ─────────────────────────────────────────────────────────────────────────────
step "[1/8] Docker (cần cho GVM container)"
if have docker; then skip docker; else
  sudo apt-get update -qq
  # Kali: docker.io là gói chính (KHÔNG phải docker-ce). Cài RIÊNG để một gói phụ
  # thiếu/đổi tên (docker-compose-v2 khác nhau giữa các bản Kali) không kéo đổ luôn
  # docker.io — đây chính là nguyên nhân "Unit docker.service does not exist".
  sudo apt-get install -y docker.io || fail "docker.io"
  sudo apt-get install -y docker-compose-v2 2>/dev/null \
    || sudo apt-get install -y docker-compose-plugin 2>/dev/null \
    || sudo apt-get install -y docker-compose 2>/dev/null \
    || echo "    (compose plugin chưa cài — GVM chỉ dùng 'docker run', không bắt buộc)"
  if have docker; then
    sudo systemctl enable --now docker || fail "bật docker.service"
    sudo usermod -aG docker "$USER"
    echo "    !! Đăng xuất/đăng nhập lại (hoặc: newgrp docker) để nhóm docker có hiệu lực."
  else
    fail "docker chưa cài được — bước GVM phía dưới sẽ lỗi; xử lý rồi chạy lại"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
step "[2/8] GVM / Greenbone — KICK SYNC NGAY, chạy nền"
if sudo docker ps -a --format '{{.Names}}' | grep -qx gvmd; then
  skip "container gvmd (đã tạo trước đó)"
  sudo docker start gvmd >/dev/null 2>&1
else
  sudo docker run -d --name gvmd \
    -p 9392:9392 \
    -e PASSWORD="$GVM_PASS" \
    -v gvm-data:/data \
    immauss/openvas:latest || fail "gvm container"
fi
cat <<TXT
    Web UI : http://127.0.0.1:9392    (admin / $GVM_PASS)  — HTTP, KHÔNG phải https!
             (gsad bản GVM 26.x phục vụ HTTP trần; https:// sẽ báo PR_END_OF_FILE_ERROR)
    Theo dõi : sudo docker logs -f gvmd
    Xong khi : log hiện "... container is now ready to use!"  VÀ  'pgrep rsync' rỗng
    Nếu web chưa vào được dù đã 'ready': sudo docker restart gvmd; sleep 60
    ĐỪNG chờ ở đây — để nó chạy nền, làm tiếp phần dưới.
TXT

# ─────────────────────────────────────────────────────────────────────────────
step "[3/8] Công cụ có sẵn trong Kali — chỉ kiểm tra"
for t in nmap nikto ffuf tcpdump wireshark sqlmap; do
  if have "$t"; then skip "$t"; else
    sudo apt-get install -y "$t" || fail "$t"
  fi
done
if have zaproxy || have zap.sh || [[ -d /usr/share/zaproxy ]]; then
  skip "OWASP ZAP"
else
  sudo apt-get install -y zaproxy || fail "zaproxy"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "[4/8] Trivy (config + image + secret scanning)"
if have trivy; then skip trivy; else
  sudo apt-get install -y wget gnupg lsb-release
  wget -qO- https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y trivy || fail "trivy"
fi

step "[5/8] Syft + Grype (SBOM + SCA)"
have syft  && skip syft  || curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh  | sudo sh -s -- -b "$BIN" || fail "syft"
have grype && skip grype || curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b "$BIN" || fail "grype"

step "[6/8] Semgrep (SAST) + gitleaks (secret) + testssl.sh (TLS)"
if have semgrep; then skip semgrep; else
  sudo apt-get install -y pipx && pipx install semgrep && pipx ensurepath || fail "semgrep"
  export PATH="$HOME/.local/bin:$PATH"
fi
if have gitleaks; then skip gitleaks; else
  GL_VER=$(curl -sf https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
           | grep -Po '"tag_name": "v\K[^"]+') 
  if [[ -n "${GL_VER:-}" ]]; then
    curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VER}/gitleaks_${GL_VER}_linux_x64.tar.gz" \
      | sudo tar -xz -C "$BIN" gitleaks || fail "gitleaks"
  else fail "gitleaks (không lấy được version)"; fi
fi
if [[ -x /opt/testssl.sh/testssl.sh ]]; then skip testssl.sh; else
  sudo git clone --depth 1 https://github.com/testssl/testssl.sh.git /opt/testssl.sh \
    && sudo ln -sf /opt/testssl.sh/testssl.sh "$BIN/testssl.sh" || fail "testssl.sh"
fi

# ─────────────────────────────────────────────────────────────────────────────
step "[7/8] Tải TOÀN BỘ vulnerability database (bắt buộc — lúc demo không có mạng)"
have trivy  && { trivy image --download-db-only          || fail "trivy db"; }
have trivy  && { trivy image --download-java-db-only     || true; }
have grype  && { grype db update                          || fail "grype db"; }
if have semgrep || [[ -x "$HOME/.local/bin/semgrep" ]]; then
  # Ép semgrep tải và cache ruleset về máy
  SG=$(command -v semgrep || echo "$HOME/.local/bin/semgrep")
  echo 'x=1' > /tmp/_sg.py
  "$SG" --config=p/owasp-top-ten --config=p/php --config=p/python \
        --quiet --metrics=off /tmp/_sg.py >/dev/null 2>&1 || fail "semgrep ruleset"
  rm -f /tmp/_sg.py
fi
sudo nmap --script-updatedb >/dev/null 2>&1

# ─────────────────────────────────────────────────────────────────────────────
step "[8/8] Wordlist cho ffuf (SecLists)"
if [[ -d /usr/share/seclists ]] || [[ -d /usr/share/wordlists/seclists ]]; then
  skip SecLists
else
  sudo apt-get install -y seclists || fail "seclists"
fi

# ─────────────────────────────────────────────────────────────────────────────
printf '\n\033[1;36m════════ TỔNG KẾT ════════\033[0m\n'
for t in nmap nikto ffuf trivy syft grype gitleaks semgrep testssl.sh tcpdump; do
  printf '  %-12s %s\n' "$t" "$(have "$t" && echo ✅ || echo ❌)"
done
echo "  gvmd         $(sudo docker ps --format '{{.Names}}' | grep -qx gvmd && echo '🔄 đang sync' || echo ❌)"
if ((${#FAILED[@]})); then
  printf '\n\033[1;31mCÁC BƯỚC LỖI: %s\033[0m\n' "${FAILED[*]}"
  echo "Chạy lại script này sau khi xử lý — các bước đã xong sẽ được bỏ qua."
fi
cat <<'TXT'

TIẾP THEO:
  1. sudo docker logs -f gvmd     # chờ "now ready" (có thể để qua đêm)
  2. Chụp snapshot VM: "scanner-tools-ready"
TXT
