# Cẩm nang trình bày — Host & Data (đọc khi demo)

Mở file này trên **máy khác** (điện thoại/tablet) trong lúc demo. Mỗi bước có đủ:
**Lệnh · Ý nghĩa · Bản chất công cụ · Câu nói**. Bản chất trích từ chính hộp giải
thích trên slide, nên nói khớp với thứ khán giả nhìn thấy.

- Deep-dive host = **172.16.50.21** · Scanner (Kali) = .10 · fleet breadth = .21–.23
- Trên Kali trước khi chạy (Kali dùng zsh — KHÔNG source 00-env.sh): `export T=172.16.50.21 TARGET=172.16.50.21`
  (`$T` dùng cho các lệnh tay bên dưới; `TARGET` cho `scan-*.sh`. Quên đặt `$T` thì nmap chạy **không có target** → tưởng lỗi `--script`.)
- Cred SSH lab: `labadmin / LabOnly!2026`
- Vòng đời 7 bước: Asset discovery → Scanning → Validation → Prioritization → Remediation → Verification → Reporting

---

# MỞ ĐẦU (slide)

**Nói:** "Chương 4 trả lời *cần bảo vệ những gì*. Buổi này trả lời *làm sao biết
mình chưa bảo vệ được* — và **tại sao cần rà quét lỗ hổng**: có control không đảm bảo
nó đang chạy đúng; cấu hình lệch, vá sót, CVE mới mỗi ngày. Rà quét là cách tự động,
lặp lại được để liên tục kiểm chứng."
Nhấn Scope: chỉ quét tài sản tự dựng, mạng host-only, không NAT, PII bịa.

---

# TẦNG HOST

## 1. Asset discovery — nmap
**Lệnh** `[Kali]`
```bash
nmap -sn 172.16.50.21-23
sudo nmap -sV -sC -p- --open $T
```
**Ý nghĩa:** vẽ bản đồ mạng — có máy nào, mở cổng gì, chạy service gì. "Không bảo vệ được thứ mình không biết đang tồn tại."
**Bản chất:** gửi gói TCP SYN tới từng cổng (SYN/ACK = mở, RST = đóng, im lặng = bị lọc); `-sV` bắt tay đầy đủ rồi so banner với thư viện fingerprint. Không có checklist CVE — chỉ nhận diện.
**Vì sao sai:** banner sửa/tắt được; firewall làm cổng mở trông như bị lọc; version là suy đoán từ banner.
**Nói:** "Thấy telnet, FTP, rpcbind đang chạy — đúng những service Chương 4 khuyên loại bỏ. Và ba máy .21/.22/.23 cùng lên — một mạng nhiều host, giống thật."

## 2. Baseline hardening — Lynis
**Lệnh** `[Target qua SSH]`
```bash
sudo lynis audit system --quick
grep hardening_index /var/log/lynis-report.dat
```
**Ý nghĩa:** audit hardening tại chỗ, ra **Hardening Index** (điểm sức khoẻ cấu hình).
**Bản chất:** Lynis chạy trên chính máy, đọc hàng trăm điểm cấu hình (SSH, PAM, service, quyền file) rồi chấm — không quét mạng.
**Nói:** "Đây là góc nhìn từ bên trong máy, bổ sung cho nmap nhìn từ ngoài."

## 3. Chấm điểm CIS — OpenSCAP
**Lệnh** `[Target qua SSH]`
```bash
DS=$(ls /usr/share/xml/scap/ssg/content/ssg-ubuntu2*-ds.xml | head -1)
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis_level1_server \
  --results /tmp/oscap.xml --report /tmp/oscap-report.html "$DS"
grep -c '<result>fail</result>' /tmp/oscap.xml
```
**Ý nghĩa:** chấm máy theo **CIS Benchmark**, ra score % + danh sách rule fail. Số fail = baseline để so sau remediation.
**Bản chất:** file datastream `ssg-ubuntu2204-ds.xml` (dự án ComplianceAsCode) đóng gói CIS. Bên trong là XCCDF (danh sách rule) + OVAL (cách máy đọc kiểm từng rule). OpenSCAP đọc cấu hình/package/sysctl rồi so trạng thái thật với mong đợi. **Hoàn toàn cục bộ, không gửi gói ra mạng.**
**Lưu ý:** score = tỷ lệ rule pass **có trọng số** → đổi profile là đổi điểm dù máy không đổi.
**Nói:** "CIS Benchmark là đề bài, OpenSCAP là người chấm."

## 4. Config baseline "tự viết"
**Lệnh** `[Target qua SSH]`
```bash
grep -E '^\s*minlen' /etc/security/pwquality.conf          # độ mạnh mật khẩu (PAM)
grep pam_pwquality.so /etc/pam.d/common-password
grep -E 'pam_faillock.so|pam_tally2.so' /etc/pam.d/common-auth   # lockout
sudo iptables -S | grep -E '^-P|dport 22'                  # firewall default policy + SSH mở
sudo sshd -T | grep -Ei 'permitrootlogin|passwordauthentication|allowusers'
```
**Ý nghĩa:** kiểm bộ "baseline nội bộ" mà công ty tự viết ngoài Lynis/OpenSCAP: PAM (độ mạnh + lockout), firewall, least-privilege SSH.
**Bản chất:** chỉ là đọc file cấu hình rồi so với chuẩn mong đợi — chứng minh "config scanning" không nhất thiết cần tool lớn.
**Nói:** "minlen thấp, thiếu faillock, policy ACCEPT, AllowUsers có cả root/test — mỗi dòng FAIL là một điều khoản baseline chưa đạt."

## 5. FTP anonymous
**Lệnh** `[Kali]`
```bash
nmap --script ftp-anon -p21 $T
```
**Ý nghĩa:** kiểm FTP cho đăng nhập nặc danh (service thừa + kênh rò).
**Nói:** "'Anonymous FTP login allowed' — ai cũng vào được, và (phần Data) mật khẩu FTP đi plaintext."

## 6. Unauthenticated ↔ Authenticated (SHOWPIECE) — GVM
**Cách làm:** chạy trước, lưu 2 report, demo chỉ chiếu. Chi tiết Web UI: `docs/gvm-guide.md`.
Fallback không cần GVM:
```bash
nmap -sV $T                                   # unauth: chỉ version qua banner
sudo lynis audit system --quick   # (SSH) auth: thấy sâu hơn hẳn
```
**Ý nghĩa:** cùng máy, cùng tool, chỉ khác có SSH credential hay không → chứng minh **patch management (GT-H10)**.
**Bản chất:** GVM có feed NVT (hàng chục nghìn script NASL, mỗi script gắn CVE). Unauth: dò cổng/service rồi so version → suy luận CVE. Auth: đăng nhập SSH, chạy `dpkg -l` lấy danh sách gói chính xác, đối chiếu advisory distro → thấy toàn bộ missing patch.
**Vì sao sai:** distro **backport** bản vá nhưng giữ nguyên version → scanner tưởng chưa vá, báo nhầm (FP kinh điển → dẫn sang Validation).
**Nói:** "Báo cáo 'sạch' có khi chỉ vì scanner chưa được cho nhìn đủ. Greenbone là nhánh mở tách từ Nessus (2005); doanh nghiệp thường dùng Nessus/InsightVM/Qualys — cùng cơ chế, khác feed."

## 7. Antimalware — ClamAV + EICAR
**Lệnh** `[Target qua SSH]`
```bash
echo 'WDVPIVAlQEFQWzRcUFpYNTQoUF4pN0NDKTd9JEVJQ0FSLVNUQU5EQVJELUFOVElWSVJVUy1URVNULUZJTEUhJEgrSCo=' \
  | base64 -d > /tmp/eicar.txt
clamscan /tmp/eicar.txt ; rm -f /tmp/eicar.txt
```
**Ý nghĩa:** chứng minh engine anti-malware + signature DB hoạt động.
**Bản chất:** EICAR là chuỗi test chuẩn công nghiệp (KHÔNG phải virus thật); ClamAV so nội dung file với chữ ký.
**Nói:** "`Eicar-Test-Signature FOUND` — engine chạy. Nhưng signature chỉ bắt được cái đã biết; đây cũng là giới hạn của antivirus."

---

# TẦNG DATA (3 trạng thái)

## 1. At rest — datastore không auth
**Lệnh** `[Kali]`
```bash
sudo nmap -sV -p 27017,6379,9000 --script mongodb-info,mongodb-databases,redis-info $T
mongosh "mongodb://$T:27017" --quiet --eval 'db.getSiblingDB("hocvien").hoc_vien.countDocuments()'
redis-cli -h $T GET app:db:password
```
**Ý nghĩa:** kiểm database có bật xác thực không.
**Bản chất:** script NSE gửi lệnh của **chính giao thức** — Mongo `buildInfo`, Redis `INFO`. Server trả lời mà không đòi credential = chưa bật auth.
**Nói:** "Vào thẳng Mongo, đọc được key trong Redis — không cần một mật khẩu nào."

## 2. At rest — bucket public rò PII ⭐ (money shot)
**Lệnh** `[Kali]`
```bash
curl -s "http://$T:9000/hocvien-backup/pii.csv" | head -3
```
**Ý nghĩa:** bucket MinIO đặt policy **public-read** → tải file backup không cần đăng nhập.
**Nói:** "Đây là dữ liệu cá nhân — CCCD, số điện thoại, số thẻ ngân hàng — tải về từ Internet-facing bucket mà không cần bất kỳ credential nào. (Dữ liệu bịa hoàn toàn.)"

## 3. At rest — secret hardcode
**Lệnh** `[Kali]`
```bash
gitleaks dir ~/lab        # bản cũ: gitleaks detect --no-git -s ~/lab
```
**Ý nghĩa:** tìm credential bị commit vào source/image.
**Bản chất:** gitleaks duyệt cả **lịch sử git**, dùng regex cho từng loại key + điểm **entropy Shannon** bắt chuỗi ngẫu nhiên đáng ngờ.
**Vì sao FP:** chuỗi entropy cao có thể chỉ là hash vô hại; `trufflehog` còn gọi API nhà cung cấp xác minh key còn sống → ít FP hơn.
**Nói:** "Bạn xoá file .env ở commit sau, nhưng nó vẫn nằm trong lịch sử git — gitleaks vẫn tìm ra."

## 4. At rest — đĩa không mã hoá
**Lệnh** `[Target qua SSH]`
```bash
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT
lsblk -o TYPE,FSTYPE | grep -iE 'crypt|LUKS' || echo "KHÔNG có LUKS -> đĩa không mã hoá"
```
**Ý nghĩa:** xác nhận data at rest không được bảo vệ ở tầng đĩa.
**Nói:** "Không auth + không mã hoá đĩa + dữ liệu nhạy cảm = rò rỉ nhiều tầng."

## 5. In transit — TLS yếu
**Lệnh** `[Kali]`
```bash
sudo nmap -p 8443 --script ssl-enum-ciphers $T
testssl.sh --protocols --server-defaults "https://$T:8443"
```
**Ý nghĩa:** kiểm giao thức/cipher/chứng thư của endpoint HTTPS.
**Bản chất:** bắt tay TLS thử nhiều tổ hợp, xếp hạng cipher, đọc cert.
**Nói:** "TLS 1.0/1.1 vẫn bật, cipher yếu, cert RSA-1024/SHA-1 — kênh 'mã hoá' nhưng bẻ được."

## 6. In transit — bắt gói plaintext ⭐ (2 cửa sổ)
**Lệnh**
```bash
# [Terminal A — Target] nghe cổng FTP, lọc user/pass
sudo tcpdump -i any -A 'tcp port 21' | grep -iE 'USER|PASS'
# [Terminal B — Kali] sinh traffic login FTP
curl "ftp://test:123456@$T/"
```
**Ý nghĩa:** chứng minh mật khẩu đi **trần** trên mạng khi không mã hoá.
**Bản chất:** tcpdump chụp gói tại NIC; FTP không TLS nên `USER`/`PASS` nằm nguyên văn trong payload.
**Chiếu đẹp:** `sudo tcpdump -i any -w /tmp/ftp.pcap 'tcp port 21'` → Wireshark → **Follow TCP Stream**.
**Nói:** "Username, password hiện nguyên văn. Đây là lý do 'data in transit' phải mã hoá." *(Nếu App tier chạy, có thể bắt qua DVWA HTTP port 8080 như slide.)*

## 7. Mini DLP — content inspection + 3 sensor
**Lệnh** `[Target qua SSH]`
```bash
cd ~/lab
python3 dlp/dlp_scan.py --fs /srv/shared /home/labadmin/tailieu \
  --mongo mongodb://127.0.0.1:27017 \
  --index data/seed/out/pii.json --truth data/seed/out/ground-truth-pii.json \
  --json reports/dlp-report.json     # storage sensor + chấm FP/FN
python3 dlp/dlp_scan.py --proc       # agent sensor (data in use)
```
**Ý nghĩa:** thu nhỏ DLP của Chương 4 thành 3 phép quét theo 3 sensor (slide 48): network = tcpdump (#6) · storage = lệnh trên · agent = `--proc`.
**Bản chất:** **content inspection** (regex tìm CCCD/SĐT/email) bắt được dữ liệu mới nhưng đẻ FP; **index matching** (so với danh sách đã biết) sạch FP nhưng mù dữ liệu mới. Kết quả mẫu: 240 FP từ mã đơn hàng 12 số.
**Nói:** "Đây chính là đánh đổi của slide 47 — không có phép quét nào vừa bắt hết vừa không báo nhầm."

---

# CHỐT — Validation → Verification

```bash
cat ~/lab/scripts/ground-truth-host.md ~/lab/scripts/ground-truth-data.md   # đối chiếu FN/FP
```
- **Validation:** finding nào thật, cái nào FP (ví dụ 240 FP của DLP, hoặc CVE bị backport).
- **Verification (thủ công — ansible chưa có):** sửa 1 mục rồi quét lại thấy finding mất, ví dụ:
  ```bash
  # [Target] bật auth Mongo, hoặc:
  sudo rm /etc/ssh/sshd_config.d/00-lab-weak.conf && sudo systemctl restart ssh
  ```
  rồi chạy lại bước tương ứng → finding biến mất = vòng lặp khép kín.
- **Reporting:** gom toàn bộ vào report theo NIST SP 800-115.

**Câu kết:** "Rà quét không dừng ở phát hiện. Nhiều bài mất điểm vì bỏ Validation và
Verification — hai bước chúng tôi cố ý đi đủ."

---

# Nhắc nhanh khi kẹt
- Kali zsh: `export TARGET=172.16.50.21`, **đừng** `source 00-env.sh`.
- GVM 000 / kẹt sync → `docs/gvm-guide.md` (recreate `SKIPSYNC=true`).
- Docker network lỗi trên .21 (do defect iptables) → `sudo systemctl restart docker`.
- Reset máy nhanh → VMware snapshot `host+data-vuln`.
