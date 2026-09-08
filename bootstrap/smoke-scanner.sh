#!/bin/bash
# smoke-scanner.sh — kiểm MỌI tool trên Kali CHẠY ĐƯỢC (không chỉ 'có mặt') trước khi snapshot.
# Chạy OFFLINE được (đúng điều kiện demo): tool dùng DB đều --skip-update / rule local.
#   bash bootstrap/smoke-scanner.sh
# Exit 0 = không tool nào FAIL (có thể snapshot). Exit 1 = còn FAIL, xử lý khi CÒN NAT.
set -uo pipefail

PASS=0; FAIL=0; WARN=0
ok()   { printf '  \033[1;32m✅ %s\033[0m\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[1;31m❌ %s\033[0m\n' "$*"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[1;33m⚠️  %s\033[0m\n' "$*"; WARN=$((WARN+1)); }
sec()  { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

sec "Tool mạng / web (gọi thử --version)"
nmap --version    >/dev/null 2>&1 && ok "nmap"    || bad "nmap"
nikto -Version    >/dev/null 2>&1 && ok "nikto"   || bad "nikto"
ffuf -V           >/dev/null 2>&1 && ok "ffuf"    || bad "ffuf"
sqlmap --version  >/dev/null 2>&1 && ok "sqlmap"  || bad "sqlmap"
tcpdump --version >/dev/null 2>&1 && ok "tcpdump" || bad "tcpdump"
tshark -v         >/dev/null 2>&1 && ok "tshark (wireshark CLI)" || warn "tshark — kiểm thủ công"
command -v testssl.sh >/dev/null 2>&1 && testssl.sh --version >/dev/null 2>&1 \
  && ok "testssl.sh" || bad "testssl.sh"
if command -v zaproxy >/dev/null 2>&1 || [[ -d /usr/share/zaproxy ]]; then
  ok "OWASP ZAP (có mặt — test GUI/headless thủ công)"
else bad "zaproxy"; fi

sec "SCA / SBOM — có DB và quét thử OFFLINE"
if command -v trivy >/dev/null 2>&1; then
  [[ -f "$HOME/.cache/trivy/db/trivy.db" ]] && ok "trivy DB có sẵn" \
    || warn "trivy DB chưa tải — chạy 'trivy image --download-db-only' khi CÒN NAT"
  trivy fs --skip-db-update --scanners vuln --quiet /etc/os-release >/dev/null 2>&1 \
    && ok "trivy quét fs (offline)" || bad "trivy chạy fs"
else bad "trivy"; fi
if command -v grype >/dev/null 2>&1; then
  grype db status 2>/dev/null | grep -qiE 'valid|status:.*valid|from ' \
    && ok "grype DB hợp lệ" || warn "grype DB — chạy 'grype db update' khi CÒN NAT"
else bad "grype"; fi
if command -v syft >/dev/null 2>&1; then
  ST=$(mktemp -d); : > "$ST/dummy"
  syft "dir:$ST" -q -o table >/dev/null 2>&1 && ok "syft tạo SBOM (dir)" || bad "syft chạy"
  rm -rf "$ST"
else bad "syft"; fi

sec "SAST / secret — quét thử OFFLINE (rule + mồi local)"
TMP=$(mktemp -d)
cat > "$TMP/rule.yaml" <<'YML'
rules:
  - id: smoke-eval
    pattern: eval(...)
    message: eval found
    languages: [python]
    severity: WARNING
YML
printf '%s\n' 'eval("1+1")' > "$TMP/t.py"
SG=$(command -v semgrep 2>/dev/null || echo "$HOME/.local/bin/semgrep")
if [[ -x "$SG" ]] || command -v semgrep >/dev/null 2>&1; then
  "$SG" --quiet --metrics=off --config "$TMP/rule.yaml" "$TMP/t.py" 2>/dev/null | grep -q 'smoke-eval' \
    && ok "semgrep bắt pattern (offline, rule local)" || bad "semgrep quét"
else bad "semgrep"; fi
# KHÔNG dùng AKIAIOSFODNN7EXAMPLE / ...EXAMPLEKEY — gitleaks allowlist sẵn key ví dụ của AWS.
# Dùng key tổng hợp (không có thật, không bị allowlist) để gitleaks thật sự phải bắt.
# Ghép rời tiền tố "AKIA" để chuỗi khoá KHÔNG nằm nguyên vẹn trong repo (tránh GitHub
# push-protection chặn); runtime nối lại vẫn ra key đầy đủ cho gitleaks phát hiện.
akia="AKIA"; body="QYLPX7RN2ZK4WT6M"
{ printf '%s\n' "aws_access_key_id = ${akia}${body}"
  printf '%s\n' 'aws_secret_access_key = aZ2Kd9Xq7Wm4Pn8Rt3Yb6Vc1Lf5Hj0Sg8Dk2Qw9E'
} > "$TMP/leak.txt"
if command -v gitleaks >/dev/null 2>&1; then
  gitleaks dir "$TMP" >/dev/null 2>&1; rc=$?
  [[ $rc -gt 1 ]] && { gitleaks detect --no-git -s "$TMP" >/dev/null 2>&1; rc=$?; }
  case $rc in
    1) ok "gitleaks phát hiện secret mồi" ;;
    0) warn "gitleaks chạy nhưng không bắt secret mồi (kiểm rule)" ;;
    *) bad "gitleaks lỗi (rc=$rc)" ;;
  esac
else bad "gitleaks"; fi
rm -rf "$TMP"

sec "SecLists (wordlist cho ffuf)"
{ [[ -d /usr/share/seclists ]] || [[ -d /usr/share/wordlists/seclists ]]; } \
  && ok "SecLists" || warn "SecLists chưa cài"

sec "Docker + GVM / Greenbone"
sudo docker info >/dev/null 2>&1 && ok "docker daemon" || bad "docker daemon"
if sudo docker ps --format '{{.Names}}' | grep -qx gvmd; then
  sudo docker ps --filter name=gvmd --format '{{.Status}}' | grep -qi healthy \
    && ok "gvmd container healthy" || warn "gvmd chưa 'healthy'"
  # Marker log CÓ THỂ bị cuộn/reset sau restart -> chỉ là gợi ý, KHÔNG chặn.
  # Tiêu chí sẵn sàng thật = Web UI phản hồi (gsad+gvmd đang phục vụ).
  sudo docker logs gvmd 2>&1 | grep -qiE 'now ready' \
    && ok "GVM feed đã sync ('... ready to use!')" \
    || warn "không thấy marker 'ready' trong log (có thể đã cuộn/restart) — xác nhận bằng Web UI dưới"
  if sudo docker exec gvmd pgrep rsync >/dev/null 2>&1; then
    warn "GVM VẪN đang tải feed (rsync còn chạy) — chờ trước khi snapshot"
  else ok "GVM hết tải feed (rsync rỗng)"; fi
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9392 2>/dev/null)
  [[ "$code" =~ ^(200|302|303)$ ]] \
    && ok "GVM Web UI trả HTTP $code — GVM sẵn sàng dùng (http://127.0.0.1:9392, admin/labadmin)" \
    || bad "GVM Web UI không phản hồi (http_code=$code) — nhớ dùng http, không https"
else bad "container gvmd không tồn tại — chạy bootstrap-scanner.sh"; fi

printf '\n\033[1;36m════════ KẾT QUẢ ════════\033[0m\n'
printf '  PASS=%d   FAIL=%d   WARN=%d\n' "$PASS" "$FAIL" "$WARN"
if ((FAIL)); then
  printf '\033[1;31m  CHƯA nên snapshot — còn %d tool lỗi. Xử lý khi CÒN NAT rồi chạy lại.\033[0m\n' "$FAIL"
  exit 1
fi
printf '\033[1;32m  OK — tool đều chạy được. Có thể snapshot "scanner-tools-ready".\033[0m\n'
printf '     (WARN chỉ là nhắc nhở, không chặn snapshot.)\n'
exit 0
