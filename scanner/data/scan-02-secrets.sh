#!/bin/bash
# scan-02-secrets.sh — Secret rải trong source/image (GT-D08, chồng lấn GT-A06).
#   gitleaks quét source (cục bộ trên Kali) + trivy image --scanners secret nếu image có sẵn.
#   bash scan-02-secrets.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-02  Secret trong source & image"

info "1) gitleaks trên toàn repo lab (source):"
if have gitleaks; then
  gitleaks dir "$ROOT" -r "$EVID/data-02-gitleaks-$TS.json" >/dev/null 2>&1; rc=$?
  [[ $rc -gt 1 ]] && { gitleaks detect --no-git -s "$ROOT" -r "$EVID/data-02-gitleaks-$TS.json" >/dev/null 2>&1; rc=$?; }
  case $rc in
    1) ok "gitleaks phát hiện secret (app/bad-image/.env, connection string)";;
    0) warn "gitleaks không thấy secret";;
    *) warn "gitleaks lỗi (rc=$rc)";;
  esac
  info "    evidence: $EVID/data-02-gitleaks-$TS.json"
else warn "thiếu gitleaks"; fi

info "2) trivy image --scanners secret (nếu image build sẵn trên Kali):"
if have trivy && docker image inspect lab/bad-app:demo >/dev/null 2>&1; then
  trivy image --quiet --scanners secret lab/bad-app:demo 2>/dev/null \
    | tee "$EVID/data-02-trivy-secret-$TS.txt" | tail -n 15 | sed 's/^/    /'
  ok "evidence: $EVID/data-02-trivy-secret-$TS.txt (ENV DB_PASSWORD/AWS trong layer)"
else info "    (bỏ qua — image chưa có trên Kali; gitleaks ở trên đã chứng minh secret bị commit)"
fi
