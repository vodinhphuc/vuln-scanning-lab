#!/bin/bash
# scan-02-sca.sh — SCA / SBOM tầng App (GT-A04: dependency CVE bạn không tự viết).
#   syft sinh SBOM từ source (requirements.txt) -> grype khớp CVE. Chạy CỤC BỘ trên Kali, offline.
#   Nếu image lab/bad-app:demo có sẵn trên Kali -> thêm trivy image (OS + lib CVE).
#   bash scan-02-sca.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

SRC="$ROOT/app/bad-image"
hd "scan-02  SCA / SBOM (source: $SRC)"

info "1) syft — sinh SBOM (đọc requirements.txt, không cần chạy app):"
if have syft; then
  syft "dir:$SRC" -o json > "$EVID/app-02-sbom-$TS.json" 2>/dev/null \
    && ok "SBOM: $EVID/app-02-sbom-$TS.json ($(grep -oc '"name"' "$EVID/app-02-sbom-$TS.json") mục)" \
    || warn "syft lỗi"
else warn "thiếu syft"; fi

info "2) grype — khớp SBOM với CSDL lỗ hổng (offline, DB đã tải):"
if have grype; then
  grype "sbom:$EVID/app-02-sbom-$TS.json" 2>/dev/null | tee "$EVID/app-02-grype-$TS.txt" | sed 's/^/    /'
  ok "GT-A04 kỳ vọng: Flask 0.12.2 · Jinja2 2.10 · urllib3 1.24.1 · PyYAML 5.1 · requests 2.19.1"
  ok "evidence: $EVID/app-02-grype-$TS.txt"
else warn "thiếu grype (grype db update khi CÒN NAT)"; fi

info "3) trivy image (nếu image build sẵn trên Kali) — thêm CVE tầng OS:"
if have trivy && docker image inspect lab/bad-app:demo >/dev/null 2>&1; then
  trivy image --quiet --skip-db-update --severity HIGH,CRITICAL lab/bad-app:demo 2>/dev/null \
    | tee "$EVID/app-02-trivyimage-$TS.txt" | tail -n 20 | sed 's/^/    /'
  ok "evidence: $EVID/app-02-trivyimage-$TS.txt"
else
  info "    (bỏ qua — image chưa build trên Kali; SCA qua source ở trên đã đủ cho demo)"
fi
