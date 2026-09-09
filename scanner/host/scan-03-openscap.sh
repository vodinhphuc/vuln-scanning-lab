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
# KHÔNG pipe qua head: head đóng pipe sớm -> SIGPIPE giết oscap trước khi ghi results.xml.
# Chạy trọn (oscap trả mã != 0 khi có rule fail — bình thường), rồi đọc kết quả qua sudo.
on_target_sudo "oscap xccdf eval --profile '$PROFILE' --results /tmp/host-03-results.xml --report /tmp/host-03-report.html '$DS'" >/dev/null 2>&1

RES="$EVID/host-03-results-$TS.xml"
on_target_sudo "cat /tmp/host-03-results.xml" > "$RES" 2>/dev/null
if [[ -s "$RES" ]]; then
  p=$(grep -c '<result>pass</result>' "$RES" 2>/dev/null)
  f=$(grep -c '<result>fail</result>' "$RES" 2>/dev/null)
  ok "Điểm tuân thủ: pass=$p  fail=$f  (fail = baseline để so sau remediation)"
  info "Vài rule FAIL đầu tiên:"
  grep -B1 '<result>fail</result>' "$RES" 2>/dev/null | grep -oE 'idref="[^"]+"' | sed 's/idref="//;s/"//' | head -8 | sed 's/^/    /'
else warn "không đọc được results.xml — kiểm oscap/sudo trên target"; fi

on_target_sudo "cat /tmp/host-03-report.html" > "$EVID/host-03-openscap-$TS.html" 2>/dev/null
[[ -s "$EVID/host-03-openscap-$TS.html" ]] \
  && ok "report HTML (mở bằng trình duyệt): $EVID/host-03-openscap-$TS.html" \
  || warn "chưa kéo được HTML report"
ok "Số fail = baseline; chạy lại sau remediation để thấy score tăng"
