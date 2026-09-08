#!/bin/bash
# scan-03-openscap.sh — AUDIT TẠI CHỖ (qua SSH): OpenSCAP eval hồ sơ CIS trên target.
# Cho ra SCORE (%) + HTML report -> dùng cho slide "score trước/sau remediation".
# Bắt: GT-H01/02 (ssh), GT-H07 (firewall), GT-H08 (perm), GT-H09 (audit).
#   bash scan-03-openscap.sh            (override hồ sơ: PROFILE=xccdf_..._profile_cis_level1_server)
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

DS_GLOB='/usr/share/xml/scap/ssg/content/ssg-ubuntu2*-ds.xml'
PROFILE="${PROFILE:-xccdf_org.ssgproject.content_profile_cis_level1_server}"

hd "scan-03  OpenSCAP CIS eval (chạy trên $TARGET qua SSH)"
DS=$(on_target "ls $DS_GLOB 2>/dev/null | head -1")
[[ -n "$DS" ]] && ok "datastream: $DS" || { warn "target không có SCAP datastream — chạy bootstrap-target.sh"; exit 1; }

info "Đang eval hồ sơ: ${PROFILE##*_profile_} (có thể mất ~1 phút)..."
on_target_sudo "oscap xccdf eval --profile '$PROFILE' \
   --results /tmp/host-03-results.xml --report /tmp/host-03-report.html '$DS' \
   2>/dev/null | grep -E 'Title|Result|Rule' | head -40" | sed 's/^/    /'

info "Điểm tuân thủ (pass/fail):"
on_target_sudo "grep -cE '<result>pass' /tmp/host-03-results.xml 2>/dev/null; \
                grep -cE '<result>fail' /tmp/host-03-results.xml 2>/dev/null" \
  | paste -sd'/' | sed 's#^#    pass/fail = #'

from_target /tmp/host-03-report.html "$EVID/host-03-openscap-$TS.html" 2>/dev/null \
  && ok "evidence (mở bằng trình duyệt): $EVID/host-03-openscap-$TS.html" \
  || warn "chưa kéo được HTML report"
ok "Số fail bây giờ = baseline; chạy lại sau remediation để thấy score tăng"
