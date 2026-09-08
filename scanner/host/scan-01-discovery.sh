#!/bin/bash
# scan-01-discovery.sh — QUÉT TỪ XA (Kali): phát hiện host + service/version bằng nmap.
# Bắt bề mặt tấn công: GT-H05 (21), GT-H06 (23,111), + mọi cổng app/data đang mở.
#   bash scan-01-discovery.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
command -v nmap >/dev/null 2>&1 || { warn "thiếu nmap"; exit 1; }

hd "scan-01  Host discovery + service/version ($TARGET)"
info "1) Ping-sweep toàn dải lab (xem máy nào sống):"
nmap -sn "$LAB_NET" | grep -E 'Nmap scan report|host up' | sed 's/^/    /'

info "2) Quét cổng + nhận diện dịch vụ + script mặc định -> lưu evidence:"
OUT="$EVID/host-01-nmap-$TS"
sudo nmap -sV -sC -p- --open -oA "$OUT" "$TARGET" | tail -n +5 | sed 's/^/    /'
ok "evidence: ${OUT}.{nmap,gnmap,xml}"

info "3) Đối chiếu nhanh cổng ground-truth:"
grep -E '/(tcp|udp) +open' "${OUT}.nmap" 2>/dev/null \
  | grep -E ':?(21|22|23|111|80|3000|8080|27017|6379|9000|8443)\b|^(21|22|23|111|80|3000|8080|27017|6379|9000|8443)/' \
  | sed 's/^/    /' || info "    (xem đầy đủ trong ${OUT}.nmap)"
ok "GT-H05 (ftp/21), GT-H06 (telnet/23, rpcbind/111) phải xuất hiện ở trên"
