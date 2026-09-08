#!/bin/bash
# make-fileperm.sh — GT-H08a/b: file quyền quá rộng + SUID root thừa.
# Chạy TRÊN Target Ubuntu, cần sudo. Idempotent.
#   sudo bash make-fileperm.sh
# Scanner bắt bằng: scan-02-lynis (file perm + SUID), scan-03-openscap, scan-05-gvm.
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh
require_root; lab_safety_guard

hd "GT-H08  File quyền quá rộng + SUID không cần thiết"
echo "credential lab bịa: DB_PW=P@ssw0rd-lab-2026" > /root/secret.txt
chmod 777 /root/secret.txt                    # GT-H08a
cp /bin/find /usr/local/bin/labfind 2>/dev/null || cp /usr/bin/find /usr/local/bin/labfind
chmod 4755 /usr/local/bin/labfind             # GT-H08b: SUID root thừa
ok "/root/secret.txt = 777 ; /usr/local/bin/labfind SUID root"
ok "kiểm chứng: stat -c '%a' /root/secret.txt ; find / -perm -4000 2>/dev/null | grep labfind"
