#!/bin/bash
# make-iptables.sh — GT-H07: firewall kiểu enterprise CẤU HÌNH SAI (thay make-firewall.sh/ufw).
# Mô phỏng baseline công ty: iptables nạp bằng service template iptables@base ->
# load /etc/iptables/base.rule bằng iptables-restore. Ở đây base.rule CỐ TÌNH vi phạm:
#   (a) GT-H07a: default policy ACCEPT  -> firewall coi như vô hiệu
#   (b) GT-H07b: mở SSH(22) ra 0.0.0.0/0 -> cổng quản trị hở toàn dải thay vì mạng quản trị
# Chạy TRÊN Target Ubuntu, cần sudo. Idempotent.
#   sudo bash make-iptables.sh
# Scanner bắt bằng: scan-08-baseline (default policy + service iptables@base + base.rule).
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root; lab_safety_guard

hd "GT-H07  iptables@base — policy mở + rule hở (baseline enterprise, cố tình sai)"
apt-get install -y -q iptables >/dev/null 2>&1

mkdir -p /etc/iptables
cat > /etc/iptables/base.rule <<'RULE'
# LAB-WEAK base.rule — CỐ TÌNH sai. Nạp bởi service iptables@base (iptables-restore).
# Baseline đúng lẽ ra: default policy DROP, chỉ mở cổng cần thiết, SSH giới hạn mạng quản trị.
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp --dport 22 -s 0.0.0.0/0 -j ACCEPT
COMMIT
RULE

# Service template kiểu công ty: iptables@<name> nạp /etc/iptables/<name>.rule.
# Dùng dạng '< file' (sh -c) cho tương thích rộng giữa các bản iptables-restore.
cat > /etc/systemd/system/iptables@.service <<'UNIT'
[Unit]
Description=iptables ruleset %i (lab enterprise-style)
After=network-pre.target
Before=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c '/sbin/iptables-restore < /etc/iptables/%i.rule'
ExecReload=/bin/sh -c '/sbin/iptables-restore < /etc/iptables/%i.rule'
ExecStop=/sbin/iptables -F
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now iptables@base >/dev/null 2>&1 || warn "không enable được iptables@base"
/sbin/iptables-restore < /etc/iptables/base.rule 2>/dev/null || warn "iptables-restore lỗi"
ok "iptables@base active, base.rule: default policy ACCEPT + SSH(22) hở 0.0.0.0/0"
ok "kiểm chứng: systemctl is-active iptables@base ; iptables -S | grep -E '^-P|dport 22'"
