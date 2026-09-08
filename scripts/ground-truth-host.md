# Ground truth — Tầng HOST (VM Target Linux 172.16.50.20)

> Danh sách lỗ hổng **cố tình tạo** bởi các script `target/host/make-*.sh`
> (orchestrator: `target/host/make-all.sh`). Đây là chân lý
> nền để tính **False Negative** (scanner bỏ sót mục nào) và **False Positive**
> (scanner báo mục không có trong bảng này → kiểm tra thủ công).
>
> Nguyên tắc brief mục 5: *dựng target → cố tình tạo lỗ hổng → quét → so với
> ground truth*. Bước "cố tình tạo" chính là bảng dưới đây.

Ubuntu 22.04.5 LTS · cài mặc định · **không** hardening.

| Mã | Lỗ hổng cố ý | Slide Ch.4 | Kỳ vọng scanner nào bắt được | Bằng chứng |
|---|---|---|---|---|
| GT-H01 | `PermitRootLogin yes` | 21 | Lynis, GVM auth, `nmap`+thủ công | `sshd -T \| grep permitrootlogin` |
| GT-H02 | `PasswordAuthentication yes` (không ép key) | 21 | Lynis, OpenSCAP | `sshd -T \| grep passwordauth` |
| GT-H03 | `AllowUsers root test labadmin` — cho user THỪA (root/test) SSH, vi phạm least-privilege | 21 | scan-08-baseline, Lynis, audit thủ công | `sshd -T \| grep allowusers` |
| GT-H04 | User `test` mật khẩu `123456`, trong `sudo`, không hết hạn | 21 | GVM (brute/weak-cred), thủ công, `john` | `chage -l test` |
| GT-H05a | vsftpd cho **anonymous** | 22 | `nmap -sV`, `nmap --script ftp-anon`, GVM | `nmap --script ftp-anon -p21` |
| GT-H05b | vsftpd `write_enable` (upload được) | 22 | thủ công (đây cũng là kênh copy code) | `curl -T f ftp://test:123456@…/` |
| GT-H05c | FTP **plaintext**, không TLS | 22, 46 | `nmap ssl`, tcpdump (bắt user/pass) | data-06 pcap |
| GT-H06 | Service thừa listen: `rpcbind` (111), `telnetd` (23) | 22 | `nmap -sV`, `ss -tulpn`, Lynis | `ss -tulpn` |
| GT-H07a | iptables `base.rule` default policy `ACCEPT` (nạp qua service `iptables@base`) | 22 | scan-08-baseline, Lynis, OpenSCAP | `iptables -S \| grep '^-P'` |
| GT-H07b | `base.rule` mở SSH(22) ra `0.0.0.0/0` (cổng quản trị hở toàn dải) | 22 | scan-08-baseline | `iptables -S \| grep 'dport 22'` |
| GT-H08a | `/root/secret.txt` quyền `777` | — | Lynis (file perm), OpenSCAP | `stat -c '%a' /root/secret.txt` |
| GT-H08b | SUID root thừa: `/usr/local/bin/labfind` | — | Lynis (SUID), GVM | `find / -perm -4000` |
| GT-H09 | Không `auditd`; AppArmor teardown | 20-22 | Lynis, OpenSCAP | `systemctl is-active auditd`; `aa-status` |
| GT-H10 | Không patch (giữ CVE từ ISO) | 24-26 | **GVM authenticated** (điểm nhấn) | so unauth vs auth |
| GT-H11a | PAM: `pwquality` lỏng (minlen=4, không credit) + không ép trong common-password | 21 | scan-08-baseline, Lynis | `grep minlen /etc/security/pwquality.conf` |
| GT-H11b | PAM: không `faillock`/`tally2` → không khoá sau nhiều lần sai | 21 | scan-08-baseline, Lynis | `grep faillock /etc/pam.d/common-auth` |

## Script tạo ↔ script quét (quan hệ NHIỀU-NHIỀU)

Một defect bị nhiều scanner bắt, một scanner bắt nhiều defect — nên không ghép 1:1.
Bảng này là "cầu nối" giữa `target/host/make-*.sh` và `scanner/host/scan-*.sh`.

| GT | Script TẠO (target/host/) | Script QUÉT bắt được (scanner/host/) |
|---|---|---|
| H01/H02 | `make-ssh.sh` | scan-02-lynis, scan-03-openscap, scan-04/05-gvm, scan-01 (cổng 22) |
| H03 | `make-ssh.sh` (AllowUsers thừa) | **scan-08-baseline**, scan-02-lynis |
| H04 | `make-weakuser.sh` | scan-05-gvm-auth (weak cred) |
| H05a/b/c | `make-ftp.sh` | scan-01 (cổng 21), scan-04-gvm (ftp-anon), data-06 pcap |
| H06 | `make-services.sh` | scan-01 (nmap -sV), scan-02-lynis |
| H07a/b | `make-iptables.sh` (iptables@base) | **scan-08-baseline**, scan-02-lynis, scan-03-openscap |
| H08a/b | `make-fileperm.sh` | scan-02-lynis, scan-03-openscap, scan-05-gvm |
| H09 | `make-audit.sh` | scan-02-lynis, scan-03-openscap |
| H10 | (không có script — cố tình không `apt upgrade`) | scan-05-gvm-auth (điểm nhấn) |
| H11a/b | `make-pam.sh` | **scan-08-baseline**, scan-02-lynis |

## Cách chấm sau khi quét

```bash
# FN: mục nào trong bảng mà KHÔNG scanner nào báo?
# FP: finding nào scanner báo mà KHÔNG có trong bảng? -> kiểm tra thủ công 3-5 cái.
```

Điểm nhấn của tầng Host là **GT-H10 + chênh lệch unauth↔auth**: quét không
credential chỉ thấy service lộ ra (GT-H05, H06); quét có SSH credential đọc được
danh sách gói nên thấy toàn bộ missing patch. Chênh lệch số finding giữa hai lần
= một slide đắt giá (brief mục 4.3).

## Bản đồ demo → verification cho từng control Chapter 4

| Control slide 20-22 nói "phải làm" | Ground truth ở đây chứng minh "chưa làm" | Rà quét = hàm verification |
|---|---|---|
| Đổi insecure default | GT-H01, H02 | Lynis/OpenSCAP chấm fail |
| Loại bỏ service thừa | GT-H05, H06 | `nmap -sV` liệt kê |
| Bật firewall | GT-H07 | scan-08-baseline: default policy ≠ DROP → fail |
| PAM policy (độ mạnh + lockout) | GT-H11 | scan-08-baseline: thiếu pwquality/faillock → fail |
| Least-privilege SSH | GT-H03 | scan-08-baseline: AllowUsers có user thừa → fail |
| Patch management | GT-H10 | GVM auth đếm missing patch |

## Sau remediation, các mục này phải đảo trạng thái

`remediate-host` (Ansible/oscap) xoá `/etc/ssh/sshd_config.d/00-lab-weak.conf`,
sửa `base.rule` (default policy DROP + bỏ rule hở SSH), purge vsftpd/telnetd/rpcbind,
`chmod 700 /root/secret.txt`, gỡ SUID, cài auditd, khôi phục pam_pwquality+faillock,
thu hẹp `AllowUsers` còn `labadmin`, `apt upgrade`.
Chạy lại `scan-02`/`scan-03`/`scan-05`/`scan-08` → score tăng, baseline PASS,
CVE giảm. Đó là bước **Verification** mà brief mục 9 nói nhiều bài bị mất điểm vì bỏ.
