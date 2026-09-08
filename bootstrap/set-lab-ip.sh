#!/bin/bash
# set-lab-ip.sh — đặt IP TĨNH cho card host-only của VM lab (172.16.50.0/24).
#
# Dùng (CẦN sudo):
#   sudo bash set-lab-ip.sh 20          # -> 172.16.50.20  (Target Linux)
#   sudo bash set-lab-ip.sh 10          # -> 172.16.50.10  (Kali Scanner)
#   sudo bash set-lab-ip.sh 172.16.50.30
#   sudo IFACE=ens37 bash set-lab-ip.sh 20   # ép tên card nếu tự dò sai
#
# Tự dò: card host-only = card KHÔNG mang default route (default route là NAT).
# Tự nhận: có netplan -> Ubuntu; có nmcli -> Kali.
# KHÔNG đụng card NAT nên VM vẫn ra Internet để tải gói.
set -uo pipefail

SUBNET="172.16.50"
HOST_IP="172.16.50.1"       # máy thật trên mạng host-only
CIDR=24

[[ $EUID -eq 0 ]] || { echo "Cần sudo:  sudo bash $0 <last-octet-hoặc-IP>"; exit 1; }

# ── Tham số IP ───────────────────────────────────────────────────────────────
ARG="${1:-}"
[[ -n "$ARG" ]] || { echo "Thiếu tham số. Ví dụ: sudo bash $0 20"; exit 1; }
if [[ "$ARG" =~ ^[0-9]+$ ]]; then
  IP="${SUBNET}.${ARG}"
elif [[ "$ARG" =~ ^${SUBNET//./\\.}\.[0-9]+$ ]]; then
  IP="$ARG"
else
  echo "IP không hợp lệ: '$ARG' (phải là last-octet, hoặc ${SUBNET}.x)"; exit 1
fi

# ── Card mang default route = card NAT (KHÔNG đụng vào) ──────────────────────
NAT_IF=$(ip route show default 2>/dev/null | awk '/default/{print $5; exit}')

# ── Tự dò card host-only ─────────────────────────────────────────────────────
if [[ -n "${IFACE:-}" ]]; then
  HOIF="$IFACE"
else
  # ưu tiên card đã có IP 172.16.50.x (DHCP host-only đã cấp)
  HOIF=$(ip -o -4 addr show | awk -v s="$SUBNET" '$4 ~ s"\\." {print $2; exit}')
  # nếu chưa, lấy card ethernet đang UP, không phải lo, không phải card NAT, chưa có IPv4
  if [[ -z "$HOIF" ]]; then
    while read -r _ name _; do
      name="${name%:}"
      [[ "$name" == "lo" || "$name" == "$NAT_IF" ]] && continue
      [[ "$name" == v* || "$name" == docker* || "$name" == br-* ]] && continue
      if ! ip -4 addr show "$name" | grep -q 'inet '; then HOIF="$name"; break; fi
    done < <(ip -o link show up)
  fi
fi

if [[ -z "${HOIF:-}" ]]; then
  echo "!! Không tìm ra card host-only."
  echo "   Card hiện có:"; ip -br addr show | sed 's/^/     /'
  echo "   -> Đã 'Add Network Adapter (VMnet1 Host-only)' cho VM chưa?"
  echo "   -> Nếu rồi, ép tên:  sudo IFACE=<ten> bash $0 $ARG"
  exit 1
fi

echo "================================================================"
echo "  Card NAT (giữ nguyên) : ${NAT_IF:-<không có default route?>}"
echo "  Card host-only        : $HOIF"
echo "  Sẽ đặt IP tĩnh        : ${IP}/${CIDR}   (gateway/DNS: KHÔNG — đi qua NAT)"
echo "================================================================"

apply_netplan() {
  local f=/etc/netplan/99-lab-hostonly.yaml
  cat > "$f" <<YAML
# LAB host-only — sinh bởi set-lab-ip.sh. KHÔNG khai gateway/nameservers:
# default route phải đi qua card NAT, không đi qua host-only.
network:
  version: 2
  ethernets:
    ${HOIF}:
      dhcp4: false
      addresses: [${IP}/${CIDR}]
YAML
  chmod 600 "$f"
  echo "Đã ghi $f"
  netplan apply
}

apply_nmcli() {
  nmcli con delete lab-hostonly >/dev/null 2>&1 || true
  nmcli con add type ethernet ifname "$HOIF" con-name lab-hostonly \
    ipv4.method manual ipv4.addresses "${IP}/${CIDR}" ipv4.never-default yes \
    connection.autoconnect yes
  nmcli con up lab-hostonly
}

# ── Chọn backend ─────────────────────────────────────────────────────────────
if command -v netplan >/dev/null 2>&1 && [[ -d /etc/netplan ]]; then
  echo "-> Dùng netplan (Ubuntu)"; apply_netplan
elif command -v nmcli >/dev/null 2>&1; then
  echo "-> Dùng NetworkManager (Kali)"; apply_nmcli
else
  echo "!! Không có netplan lẫn nmcli. Cấu hình tay giúp:"
  echo "   ip addr add ${IP}/${CIDR} dev ${HOIF} && ip link set ${HOIF} up"
  exit 1
fi

sleep 2
# ── Kiểm chứng ───────────────────────────────────────────────────────────────
echo; echo "== Kết quả =="
ip -br addr show "$HOIF"
echo -n "Default route vẫn qua NAT ($NAT_IF): "
[[ "$(ip route show default | awk '{print $5;exit}')" == "$NAT_IF" ]] && echo "✓ OK" || echo "⚠ KIỂM TRA LẠI"
echo -n "Ping máy thật $HOST_IP (host-only): "
ping -c1 -W2 "$HOST_IP" >/dev/null 2>&1 && echo "✓ OK" || echo "✗ chưa thấy (host đã bật VMnet1?)"
echo -n "Ping 8.8.8.8 (Internet qua NAT)   : "
ping -c1 -W2 8.8.8.8 >/dev/null 2>&1 && echo "✓ OK" || echo "✗ (chưa cần lúc demo)"
echo
echo "Xong. IP tĩnh của máy này: ${IP}"
