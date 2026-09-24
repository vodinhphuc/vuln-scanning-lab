#!/bin/bash
# make-ftp.sh — GT-H05a/b/c: vsftpd anonymous + upload + plaintext (slide 22 + 46).
# Chạy TRÊN Target Ubuntu, cần sudo. Idempotent.
#   sudo bash make-ftp.sh
# Vừa là ground truth service thừa/plaintext, VỪA là kênh upload file vào VM.
# Scanner bắt bằng: scan-01 (cổng 21), scan-04-gvm (ftp-anon), data-06 pcap (plaintext).
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root; lab_safety_guard

hd "GT-H05  FTP yếu — vsftpd: anonymous + local upload không mã hoá"
apt-get install -y -q vsftpd >/dev/null 2>&1
# vsftpd KHÔNG chấp nhận comment cùng dòng với value (bad bool value) — mỗi
# ghi chú phải nằm trên dòng riêng, nếu không daemon chết ngay khi start.
cat > /etc/vsftpd.conf <<'FTP'
# LAB-WEAK vsftpd — cố tình không an toàn (slide 22 service thừa + data-in-transit).
listen=YES
listen_ipv6=NO
# GT-H05a: cho anonymous
anonymous_enable=YES
# cho user local đăng nhập (dùng để upload code)
local_enable=YES
# GT-H05b: cho ghi -> upload file vào VM
write_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
local_umask=022
dirmessage_enable=YES
# GT-H05c: KHÔNG bật ssl_enable -> credential + file đi PLAINTEXT
ssl_enable=NO
pam_service_name=vsftpd
allow_writeable_chroot=YES
FTP
mkdir -p /srv/ftp/upload && chmod 777 /srv/ftp/upload
systemctl enable --now vsftpd >/dev/null 2>&1
systemctl restart vsftpd
ok "vsftpd: anonymous+upload, plaintext"
ok "upload code từ host: curl -T lab.tgz ftp://${WEAK_USER}:${WEAK_PASS}@172.16.50.21/"
ok "kiểm chứng: nmap --script ftp-anon -p21 172.16.50.21"
