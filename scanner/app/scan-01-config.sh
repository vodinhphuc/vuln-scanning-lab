#!/bin/bash
# scan-01-config.sh — Config scanning tầng App (GT-A01/A02/A03/A06).
#   - Security header thiếu (nginx đang chạy)      -> curl -I, nikto
#   - Dockerfile misconfig (BAD-01..10)            -> trivy config (source cục bộ trên Kali)
#   - Secret .env bị commit / trong ENV layer      -> gitleaks (source cục bộ)
#   bash scan-01-config.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-01  Config scanning ($TARGET)"

info "1) Security header (nginx $URL_NGINX) — thiếu = finding:"
hdrs=$(curl -sI "$URL_NGINX/" 2>/dev/null)
for h in Content-Security-Policy Strict-Transport-Security X-Frame-Options X-Content-Type-Options Referrer-Policy; do
  if echo "$hdrs" | grep -qi "^$h:"; then ok "$h có"; else warn "THIẾU $h (GT-A01)"; fi
done
echo "$hdrs" | grep -qi '^Server: nginx/[0-9]' && warn "Server header lộ version nginx (GT-A02, server_tokens on)" || info "Server header đã ẩn version"

info "2) Dockerfile misconfig — trivy config (source cục bộ):"
if have trivy; then
  trivy config --quiet "$ROOT/app/bad-image" 2>/dev/null | tee "$EVID/app-01-trivyconfig-$TS.txt" | tail -n 25 | sed 's/^/    /'
  ok "evidence: $EVID/app-01-trivyconfig-$TS.txt (GT-A03: latest tag, root, ENV secret, no HEALTHCHECK…)"
else warn "thiếu trivy"; fi

info "3) Secret bait — gitleaks trên source:"
if have gitleaks; then
  gitleaks dir "$ROOT/app" -r "$EVID/app-01-gitleaks-$TS.json" >/dev/null 2>&1; rc=$?
  [[ $rc -gt 1 ]] && { gitleaks detect --no-git -s "$ROOT/app" -r "$EVID/app-01-gitleaks-$TS.json" >/dev/null 2>&1; rc=$?; }
  case $rc in
    1) ok "gitleaks phát hiện secret (GT-A06: .env DB_PASSWORD/AWS/MINIO)";;
    0) warn "gitleaks không thấy secret — kiểm app/bad-image/.env còn không";;
    *) warn "gitleaks lỗi (rc=$rc)";;
  esac
  info "    chi tiết: $EVID/app-01-gitleaks-$TS.json"
else warn "thiếu gitleaks"; fi

info "4) nikto (tuỳ chọn, chậm) — cấu hình sai + file mặc định:"
if have nikto; then
  info "    chạy nền: nikto -h $URL_NGINX -o $EVID/app-01-nikto-$TS.txt -maxtime 60s"
  nikto -h "$URL_NGINX" -maxtime 60s -o "$EVID/app-01-nikto-$TS.txt" >/dev/null 2>&1 \
    && ok "nikto xong: $EVID/app-01-nikto-$TS.txt" || warn "nikto lỗi/quá giờ (không chặn)"
else warn "thiếu nikto"; fi
