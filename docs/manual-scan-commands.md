# Lệnh chạy tay — vuln scan Host & Data (không dùng scan-*.sh)

Gõ trực tiếp lúc demo cho minh bạch ("đây là lệnh nmap/lynis/testssl thật").
Trích đúng lệnh trong các `scanner/*/scan-*.sh`.

## Quy ước

- **[Kali]** = gõ trên máy Scanner (`172.16.50.10`).
- **[Target]** = gõ TRÊN máy đích qua SSH. Mở sẵn một cửa sổ:
  ```bash
  ssh labadmin@172.16.50.21      # mật khẩu: LabOnly!2026
  ```
- Biến dùng chung (deep-dive host):
  ```bash
  T=172.16.50.21
  ```

---

# TẦNG HOST

### 1. Asset discovery — nmap [Kali]
```bash
nmap -sn 172.16.50.21-23                                   # sweep: thấy cả fleet
sudo nmap -sV -sC -p- --open $T                            # service + version + script mặc định
```
→ FTP(21), telnet(23), rpcbind(111) hiện ra = service thừa (GT-H05/H06).

### 2. Baseline hardening — Lynis [Target]
```bash
sudo lynis audit system --quick
grep 'hardening_index' /var/log/lynis-report.dat           # lấy Hardening Index
```

### 3. Chấm điểm CIS — OpenSCAP [Target]
```bash
DS=$(ls /usr/share/xml/scap/ssg/content/ssg-ubuntu2*-ds.xml | head -1)
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/oscap.xml --report /tmp/oscap-report.html "$DS"
grep -c '<result>fail</result>' /tmp/oscap.xml             # số rule FAIL = baseline
```
→ mở `/tmp/oscap-report.html` bằng trình duyệt để chiếu score %.

### 4. Config baseline "tự viết" [Target]
```bash
# PAM — độ mạnh mật khẩu + lockout (GT-H11)
grep -E '^\s*minlen' /etc/security/pwquality.conf
grep pam_pwquality.so /etc/pam.d/common-password
grep -E 'pam_faillock.so|pam_tally2.so' /etc/pam.d/common-auth
# iptables default policy + rule mở SSH (GT-H07)
sudo iptables -S | grep -E '^-P|dport 22'
# SSH AllowUsers thừa (GT-H03)
sudo sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|allowusers'
```
→ minlen thấp / thiếu faillock / policy ACCEPT / AllowUsers có root,test = FAIL.

### 5. FTP anonymous (GT-H05) [Kali]
```bash
nmap --script ftp-anon -p21 $T                             # "Anonymous FTP login allowed"
```

### 6. Unauth ↔ Authenticated (showpiece)
```bash
# [Kali] unauth: chỉ đoán qua banner version
nmap -sV $T
# [Target] auth: đọc được cấu hình/gói -> thấy sâu hơn hẳn
sudo lynis audit system --quick
```
→ (nếu GVM lên: quét 1 lần không cred, 1 lần có SSH cred `labadmin/LabOnly!2026`, so số finding.)

### 7. Antimalware — ClamAV + EICAR [Target]
```bash
# tạo file test EICAR (KHÔNG phải virus thật) qua base64 để tránh lỗi quoting, rồi quét
echo 'WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo=' \
  | base64 -d > /tmp/eicar.txt
clamscan /tmp/eicar.txt ; rm -f /tmp/eicar.txt
```
→ báo `Eicar-Test-Signature FOUND` = engine + signature hoạt động.

---

# TẦNG DATA (theo 3 trạng thái)

### 1. At rest — datastore không auth (GT-D01/D02) [Kali]
```bash
sudo nmap -sV -p 27017,6379,9000 \
  --script mongodb-info,mongodb-databases,redis-info $T
mongosh "mongodb://$T:27017" --quiet --eval \
  'db.getSiblingDB("hocvien").hoc_vien.countDocuments()'   # vào thẳng, không cần auth
redis-cli -h $T GET app:db:password                        # đọc key không cần pass
```

### 2. At rest — bucket public rò PII (GT-D03) ⭐ [Kali]
```bash
curl -s "http://$T:9000/hocvien-backup/pii.csv" | head -3
```
→ tải PII giả (CCCD, số thẻ NH) **không cần đăng nhập** = MinIO bucket public-read.

### 3. At rest — secret hardcode (GT-D08) [Kali]
```bash
gitleaks dir ~/lab                                         # tìm .env / connection string bị commit
trivy image --scanners secret lab/bad-app:demo            # (nếu image có sẵn) secret trong layer
```

### 4. At rest — đĩa không mã hoá [Target]
```bash
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
lsblk -o TYPE,FSTYPE | grep -iE 'crypt|LUKS' || echo "KHÔNG có LUKS -> đĩa không mã hoá"
```

### 5. In transit — TLS yếu (GT-D04/D05) [Kali]
```bash
sudo nmap -p 8443 --script ssl-enum-ciphers $T            # liệt kê giao thức/cipher + xếp hạng
testssl.sh --protocols --server-defaults "https://$T:8443"   # (hoặc /opt/testssl.sh/testssl.sh)
```
→ kỳ vọng: TLS 1.0/1.1 offered, cipher yếu, cert RSA-1024 / SHA-1 / CN sai.

### 6. In transit — bắt gói plaintext (GT-H05c/D07) ⭐ — 2 cửa sổ
Dùng **FTP** (plaintext, thuộc Host/Data — không cần App):
```bash
# [Terminal A — Target] nghe cổng 21, lọc user/pass
sudo tcpdump -i any -A 'tcp port 21' | grep -iE 'USER|PASS'
# [Terminal B — Kali] đăng nhập FTP để sinh traffic
curl "ftp://test:123456@$T/"
```
→ Terminal A hiện `USER test` / `PASS 123456` nguyên văn.
Muốn chiếu đẹp: `sudo tcpdump -i any -w /tmp/ftp.pcap 'tcp port 21'` → mở Wireshark → **Follow TCP Stream**.
*(Nếu App tier đang chạy, có thể bắt qua DVWA HTTP `tcp port 8080` thay cho FTP.)*

### 7. Mini DLP — content inspection + 3 sensor [Target]
```bash
cd ~/lab
python3 dlp/dlp_scan.py \
  --fs /srv/shared /home/labadmin/tailieu \
  --mongo mongodb://127.0.0.1:27017 \
  --index data/seed/out/pii.json \
  --truth data/seed/out/ground-truth-pii.json \
  --json reports/dlp-report.json          # storage sensor + chấm FP/FN (240 FP)
python3 dlp/dlp_scan.py --proc            # agent sensor (data in use)
```
→ 3 sensor slide 48: network = tcpdump (#6) · storage = lệnh trên · agent = `--proc`.

---

# Validation → Verification (chốt)

```bash
# Validation: đối chiếu ground truth, tính FN/FP
cat ~/lab/scripts/ground-truth-host.md
cat ~/lab/scripts/ground-truth-data.md
# Verification (thủ công, vì ansible chưa có): sửa 1 mục rồi quét lại thấy finding mất
#   ví dụ [Target]: sudo rm /etc/ssh/sshd_config.d/00-lab-weak.conf && sudo systemctl restart ssh
#   rồi chạy lại mục HOST-4 (sshd -T) -> AllowUsers/PermitRootLogin đã sạch.
```
