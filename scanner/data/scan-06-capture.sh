#!/bin/bash
# scan-06-capture.sh — Data in transit: bắt mật khẩu đi PLAINTEXT (GT-D07, network sensor slide 48).
#   tcpdump PHẢI chạy trên target (nghe NIC của target). Vì cần canh thời điểm login, script
#   chạy bán tự động: bật tcpdump nền trên target -> gửi login plaintext từ Kali -> kéo pcap về.
#   Cũng in hướng dẫn 2-terminal thủ công (chắc chắn nhất cho lúc demo live).
#   bash scan-06-capture.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-06  Bắt gói plaintext — HTTP login trên $TARGET:8080"
PCAP_REMOTE=/tmp/data06-$TS.pcap
PCAP_LOCAL="$EVID/data-06-plaintext-$TS.pcap"

info "1) Bật tcpdump nền trên target (~18s)..."
on_target_sudo "nohup timeout 18 tcpdump -i any -U -w $PCAP_REMOTE 'tcp port 8080' >/dev/null 2>&1 &" 2>/dev/null
sleep 3

info "2) Gửi login PLAINTEXT tới DVWA từ Kali (username/password đi trần):"
curl -s -c /tmp/c6 "http://$TARGET:8080/login.php" >/dev/null 2>&1
tok=$(curl -s -b /tmp/c6 "http://$TARGET:8080/login.php" | grep -oE "user_token'[^a-f0-9]*[a-f0-9]{32}" | grep -oE '[a-f0-9]{32}' | head -1)
curl -s -b /tmp/c6 --data "username=admin&password=P@ssw0rd-lab-2026&Login=Login&user_token=${tok:-x}" \
  "http://$TARGET:8080/login.php" >/dev/null 2>&1
rm -f /tmp/c6
info "   (đã gửi username=admin password=P@ssw0rd-lab-2026 qua HTTP)"
sleep 6

info "3) Kéo pcap về Kali và tìm chuỗi plaintext:"
if have sshpass; then
  sshpass -p "$TARGET_SSH_PASS" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR "$TARGET_SSH_USER@$TARGET:$PCAP_REMOTE" "$PCAP_LOCAL" 2>/dev/null
fi
if [[ -f "$PCAP_LOCAL" ]] && have tcpdump; then
  tcpdump -r "$PCAP_LOCAL" -A 2>/dev/null | grep -iE 'password|username=' | head | sed 's/^/    /' \
    && ok "thấy username/password đi PLAINTEXT trong pcap (GT-D07)" \
    || warn "chưa thấy chuỗi — thử lại (canh thời điểm) hoặc dùng cách thủ công dưới"
  ok "evidence: $PCAP_LOCAL  (mở Wireshark -> Follow HTTP Stream để chiếu lớp)"
else
  warn "chưa lấy được pcap tự động — dùng cách 2-terminal thủ công:"
fi

cat <<TXT

  CÁCH THỦ CÔNG (chắc chắn nhất khi demo live) — 2 cửa sổ:
    [Terminal A, trên target qua SSH]
        ssh $TARGET_SSH_USER@$TARGET
        sudo tcpdump -i any -A 'tcp port 8080' | grep -iE 'password|username'
    [Terminal B, trên Kali] — đăng nhập DVWA qua trình duyệt http://$TARGET:8080
  Rồi chiếu Terminal A: username=... password=... hiện nguyên văn.
  Hoặc: sudo tcpdump ... -w a.pcap  ->  Wireshark  ->  Follow HTTP Stream.
TXT
