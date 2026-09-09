#!/bin/bash
# scan-08-baseline.sh — AUDIT TẠI CHỖ (qua SSH): config baseline kiểu doanh nghiệp.
# Mô phỏng "bộ baseline nội bộ": kiểm 3 nhóm trong một lần chạy —
#   1) PAM   : pam_pwquality (độ mạnh) + pam_faillock (lockout)      -> GT-H11
#   2) iptables@base : service active + default policy + base.rule    -> GT-H07
#   3) SSH   : AllowUsers so với danh sách tối thiểu (root/test thừa)  -> GT-H03
# Đây là ví dụ "custom config scanning" — thứ mà nhiều công ty tự viết ngoài Lynis/OpenSCAP.
#   bash scan-08-baseline.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

BASELINE_SSH_USERS="${BASELINE_SSH_USERS:-labadmin}"   # user ĐƯỢC PHÉP SSH theo baseline
MIN_PWLEN="${MIN_PWLEN:-12}"

pass=0; fail=0
p(){ printf '  \033[32m[PASS]\033[0m %s\n' "$*"; pass=$((pass+1)); }
f(){ printf '  \033[31m[FAIL]\033[0m %s\n' "$*"; fail=$((fail+1)); }

hd "scan-08  Config baseline (PAM · iptables@base · SSH) trên $TARGET"

# ── 1) PAM ──────────────────────────────────────────────────────────────────
hd "1) PAM — độ mạnh mật khẩu + lockout (GT-H11)"
PWLEN=$(on_target "grep -E '^[[:space:]]*minlen' /etc/security/pwquality.conf 2>/dev/null | grep -oE '[0-9]+' | head -1")
if [[ -n "$PWLEN" && "$PWLEN" -ge "$MIN_PWLEN" ]]; then p "pwquality minlen=$PWLEN (>= $MIN_PWLEN)"
else f "pwquality minlen=${PWLEN:-<không đặt>} < $MIN_PWLEN"; fi
if on_target "grep -q pam_pwquality.so /etc/pam.d/common-password 2>/dev/null"; then p "common-password ép pam_pwquality"
else f "common-password KHÔNG ép pam_pwquality"; fi
if on_target "grep -qE 'pam_faillock.so|pam_tally2.so' /etc/pam.d/common-auth 2>/dev/null"; then p "common-auth có lockout (faillock/tally2)"
else f "common-auth KHÔNG khoá sau nhiều lần sai"; fi

# ── 2) iptables@base ─────────────────────────────────────────────────────────
hd "2) iptables@base + base.rule (GT-H07)"
if on_target "systemctl is-active iptables@base 2>/dev/null" | grep -qx active; then p "service iptables@base đang chạy"
else f "iptables@base không active (baseline nạp rule qua service này)"; fi
IPT=$(on_target_sudo "iptables -S 2>/dev/null")
if echo "$IPT" | grep -qE '^-P INPUT DROP'; then p "default policy INPUT = DROP"
else f "default policy INPUT không phải DROP (mở — GT-H07a)"; fi
# iptables -S bỏ '-s 0.0.0.0/0' mặc định và thêm '-m tcp' -> phát hiện: có rule dport 22
# ACCEPT nhưng KHÔNG có '-s' giới hạn nguồn = mở toàn dải.
ssh22=$(echo "$IPT" | grep -E 'dport 22' | grep 'ACCEPT')
if [[ -n "$ssh22" ]] && ! echo "$ssh22" | grep -q -- ' -s '; then
  f "SSH(22) mở ra toàn dải (rule ACCEPT không giới hạn -s) (GT-H07b)"
elif [[ -n "$ssh22" ]]; then
  p "SSH(22) có rule nhưng đã giới hạn source (-s)"
else
  p "không có rule mở SSH(22) rộng"
fi

# ── 3) SSH AllowUsers ────────────────────────────────────────────────────────
hd "3) SSH AllowUsers — least-privilege (GT-H03)"
AU=$(on_target_sudo "/usr/sbin/sshd -T 2>/dev/null | sed -n 's/^allowusers //p'")
if [[ -z "$AU" ]]; then
  f "SSH KHÔNG có AllowUsers -> mọi user đăng nhập được"
else
  extra=""
  for u in $AU; do case " $BASELINE_SSH_USERS " in *" $u "*) : ;; *) extra="$extra $u";; esac; done
  if [[ -n "$extra" ]]; then f "AllowUsers có user THỪA:$extra  (baseline chỉ cho: $BASELINE_SSH_USERS)"
  else p "AllowUsers khớp baseline ($AU)"; fi
fi

# ── Kết quả ──────────────────────────────────────────────────────────────────
hd "KẾT QUẢ BASELINE"
printf '  PASS=%d   FAIL=%d\n' "$pass" "$fail"
REP="$EVID/host-08-baseline-$TS.txt"
{ echo "scan-08 baseline @ $TS  target=$TARGET"; echo "PASS=$pass FAIL=$fail"; echo "AllowUsers=$AU"; } > "$REP"
ok "evidence: $REP"
((fail)) && warn "$fail mục LỆCH baseline (đối chiếu ~/lab/scripts/ground-truth-host.md)" \
         || ok "khớp baseline (sau remediation kỳ vọng thấy trạng thái này)"
