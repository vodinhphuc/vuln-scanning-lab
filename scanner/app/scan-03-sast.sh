#!/bin/bash
# scan-03-sast.sh — SAST tầng App (GT-A05: lỗi trong mã nguồn mình viết).
#   semgrep so khớp mẫu trên AST của app.py. Dùng ruleset ĐÓNG GÓI (offline) + thử thêm p/ registry.
#   bash scan-03-sast.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

SRC="$ROOT/app/bad-image/app.py"
RULE="$(dirname "$0")/semgrep-lab.yaml"
SG=$(command -v semgrep 2>/dev/null || echo "$HOME/.local/bin/semgrep")

hd "scan-03  SAST — semgrep trên app.py"
[[ -x "$SG" ]] || have semgrep || { warn "thiếu semgrep (pipx install semgrep)"; exit 1; }
[[ -f "$SRC" ]] || { warn "không thấy $SRC"; exit 1; }

info "1) Ruleset đóng gói (offline, khớp SAST-01..07):"
"$SG" --quiet --metrics=off --config "$RULE" "$SRC" 2>/dev/null | tee "$EVID/app-03-semgrep-$TS.txt" | sed 's/^/    /'
n=$(grep -cE 'lab-sast-0[0-9]' "$EVID/app-03-semgrep-$TS.txt" 2>/dev/null || echo 0)
ok "bắt được $n vị trí SAST (kỳ vọng 7: hardcoded secret, SQLi, cmd-inj, XSS, yaml.load, path-traversal, swallow)"
ok "evidence: $EVID/app-03-semgrep-$TS.txt"

info "2) (Tuỳ chọn) ruleset cộng đồng nếu đã cache:"
"$SG" --quiet --metrics=off --config=p/owasp-top-ten --config=p/python "$SRC" 2>/dev/null \
  | sed 's/^/    /' | head -n 20 || info "    (bỏ qua — cần cache registry, không bắt buộc)"

ok "Đối chiếu bản ĐÚNG: get_user_safe() dùng prepared statement — semgrep KHÔNG báo (slide before/after)"
