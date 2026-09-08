# vuln-scanning-lab — Rà quét lỗ hổng (Host · Application · Data)

Lab thực hành **rà quét lỗ hổng** (vulnerability scanning) đi kèm bài thuyết trình 60
phút, nối tiếp Chapter 4 *Host, Application, and Data Security*. Ý tưởng: mỗi lỗ hổng
được **cố tình tạo** ở tầng Host/App/Data (`target/`), rồi **rà quét lại** bằng công cụ
tương ứng (`scanner/`) để minh hoạ "rà quét = hàm verification của mỗi security control".

> ## ⛔ CẢNH BÁO — máy này CỐ TÌNH mất an toàn
> Mọi cấu hình ở đây **cố ý sai** (SSH yếu, iptables policy mở, DB không auth, TLS yếu,
> secret lộ…). **CHỈ** dựng trong máy ảo mạng **host-only `172.16.50.0/24`, KHÔNG nối
> Internet/production.** Mọi credential (`LabOnly!2026`, `test/123456`…) và mọi PII đều
> **bịa hoàn toàn** cho mục đích học tập — không của hệ thống/người thật nào, đừng dùng lại.

**Dùng cho lớp học:** clone repo, làm theo *Thứ tự thực hiện* bên dưới — vừa nghe giảng
vừa tự dựng lại được. License **MIT** (xem `LICENSE`): tự do dùng/sửa/chia sẻ.

---

## ⏱ VIỆC ĐẦU TIÊN — kick GVM sync chạy nền NGAY

Feed sync mất **1–3 tiếng wall-clock** nhưng gần như không tốn thời gian của bạn.
Chạy lệnh này trên VM Scanner **trước khi làm bất cứ việc gì khác**, rồi quay lại
làm phần còn lại trong lúc nó tải:

```bash
docker run -d --name gvmd -p 9392:9392 \
  -e PASSWORD=labadmin -v gvm-data:/data immauss/openvas:latest
docker logs -f gvmd          # theo dõi tiến độ; Ctrl-C thoát log (KHÔNG giết container)
```

**Biết khi nào sync xong** (cả hai phải đúng):
```bash
sudo docker logs gvmd 2>&1 | grep -iE 'now ready'   # phải CÓ: "... container is now ready to use!"
sudo docker exec gvmd pgrep rsync                     # phải RỖNG (hết tải feed)
```

**Vào Web UI**: `http://127.0.0.1:9392` — **HTTP, không phải https** (gsad bản GVM 26.x
phục vụ HTTP trần; `https://` sẽ báo `PR_END_OF_FILE_ERROR`). Đăng nhập `admin` / `labadmin`.
Nếu đã "ready" mà web chưa vào được: `sudo docker restart gvmd; sleep 60` rồi thử lại.

> ⚠️ **Đừng rút NAT khi feed chưa sync xong** — cắt mạng giữa lúc tải NASL/SCAP làm
> hỏng feed, phải sync lại từ đầu. Volume `gvm-data` là persistent nên tải một lần
> là xong, khởi động lại VM không phải tải lại.

Trong lúc chờ, làm luôn phần "còn Internet" của PHASE 0.5:
```bash
trivy image --download-db-only
grype db update
semgrep --config=p/owasp-top-ten --version
docker pull vulnerables/web-dvwa bkimminich/juice-shop nginx:1.21 \
            mongo:6.0 redis:7.0 minio/minio minio/mc python:3.9-slim-bullseye
```

---

## Thứ tự thực hiện (PHASE 0)

| # | Việc | Ở đâu | Cần NAT? |
|---|---|---|---|
| 0 | Thêm NIC host-only, đặt IP tĩnh: `sudo bash bootstrap/set-lab-ip.sh 20` (Target) / `10` (Kali). Chi tiết: `bootstrap/network-hostonly.md` | cả 2 VM | — |
| 1 | `bash bootstrap/bootstrap-scanner.sh` — **kick GVM sync trước tiên** (Kali: docker.io) | Kali `.10` | ✅ |
| 2 |  `bash bootstrap/bootstrap-target.sh` — tạo user `labadmin`+SSH, docker, image, lynis, oscap, clamav | Ubuntu `.20` | ✅ |
| 3 | Copy `lab/` lên cả 2 VM (mục dưới) | — | — |
| 4 | **Test tool chạy được**: `bash bootstrap/smoke-scanner.sh` (Kali) · `bash bootstrap/smoke-target.sh` (Target) — phải exit 0 | cả 2 VM | — |
| 5 | **Snapshot** khi smoke-test xanh: Kali=`scanner-tools-ready`, Target=`clean-install` | cả 2 VM | — |
| 6 | PHASE 1A: `sudo bash target/host/make-all.sh` (hoặc từng `make-*.sh`) → snapshot `host-vuln` | Ubuntu `.20` | — |
| 7 | Rà quét: `bash scanner/host/run-all.sh` (nmap/lynis/oscap/eicar) + `scan-04/05-gvm` (Web UI) | Kali `.10` | — |

Bước 5 phải xong **trước** bước 6, nếu không sẽ không quay lại được trạng thái sạch.
Smoke-test (bước 4) gọi thật từng tool (offline) và exit≠0 nếu có tool lỗi — snapshot
một trạng thái *đã kiểm chứng*, tránh phát hiện tool hỏng lúc demo khi không còn NAT để sửa.
PHASE 1A tạo đúng các lỗ hổng liệt kê trong `scripts/ground-truth-host.md`
(SSH yếu, FTP anonymous+plaintext, service thừa, firewall tắt, SUID, no auditd,
giữ CVE cho authenticated scan).

## Cấu trúc

```
lab/
├── 00-env.sh                     # source đầu mọi script: IP, cổng, EVIDENCE_DIR, banner()
├── bootstrap/
│   ├── network-hostonly.md       # 2 NIC: NAT để tải + host-only để demo
│   ├── set-lab-ip.sh             # đặt IP tĩnh host-only (netplan/nmcli tự nhận), giữ default route qua NAT
│   ├── bootstrap-scanner.sh      # Kali: docker.io + GVM sync + trivy/syft/grype/semgrep/gitleaks/testssl
│   ├── bootstrap-target.sh       # Ubuntu: labadmin+SSH, docker, pull image, lynis, oscap+SCAP, clamav
│   ├── smoke-scanner.sh          # test MỌI tool Kali chạy được (offline) TRƯỚC khi snapshot
│   └── smoke-target.sh           # test tool/dịch vụ Target chạy được TRƯỚC khi snapshot
├── app/
│   ├── docker-compose.yml        # DVWA + Juice Shop + nginx (thiếu security header)
│   ├── nginx/default.conf        # CỐ TÌNH thiếu CSP/HSTS/X-Frame-Options, server_tokens on
│   ├── nginx/webroot/index.html
│   ├── nginx/webroot/clientside.html   # form chỉ validate bằng JS -> showpiece slide 42
│   └── bad-image/                # Dockerfile "xấu" + requirements cũ dính CVE + app.py mồi SAST
├── data/
│   ├── docker-compose.yml        # Mongo no-auth · Redis no-pass · MinIO public · TLS yếu
│   ├── tls/gen-cert.sh           # self-signed RSA-1024 SHA-1 CN sai
│   ├── tls/weak-tls.conf         # TLS 1.0/1.1 + cipher yếu (@SECLEVEL=0)
│   └── seed/gen_pii.py           # sinh 1000 bản ghi PII GIẢ + ground truth
│       seed/seed_all.sh          # nạp vào Mongo/Redis/web root/filesystem
├── dlp/dlp_scan.py               # mini DLP: content inspection + index matching (slide 47–48)
├── target/host/                  # scp sang Target — "cố tình tạo lỗ hổng" (theo defect)
│   ├── _lib.sh                    # helper chung (guard IP lab, ok/hd)
│   ├── make-all.sh                # orchestrator PHASE 1A (thay make-vulnerable-host.sh cũ)
│   └── make-{ssh,weakuser,ftp,services,iptables,fileperm,audit,pam}.sh  # 1 script / defect (GT-Hxx)
│       #   iptables@base policy mở (GT-H07) · PAM yếu (GT-H11) · SSH AllowUsers thừa (GT-H03)
├── scanner/host/                 # scp sang Kali — "rà quét" (theo công cụ)
│   ├── _lib.sh                    # helper chung + SSH-orchestration (on_target/on_target_sudo)
│   ├── run-all.sh                 # chạy các scan tự động được, gom evidence
│   ├── scan-01-discovery.sh       # nmap từ Kali  (GT-H05/H06 + bề mặt)
│   ├── scan-02-lynis.sh           # lynis (SSH vào target)  → Hardening Index
│   ├── scan-03-openscap.sh        # oscap CIS (SSH)         → score + HTML
│   ├── scan-04-gvm-unauth.sh      # GVM không cred (Web UI guided)
│   ├── scan-05-gvm-auth.sh        # GVM có SSH cred (Web UI guided) — điểm nhấn
│   ├── scan-06-container-vs-vm.sh # lynis container vs VM
│   ├── scan-07-eicar.sh           # ClamAV + EICAR (SSH)
│   └── scan-08-baseline.sh        # baseline kiểu công ty: PAM + iptables@base + SSH AllowUsers (SSH)
├── scripts/
│   ├── ground-truth-host.md      # ma trận GT-Hxx ↔ make-*.sh ↔ scan-*.sh + slide/bằng chứng
│   └── app-0x / data-0x          (App/Data CHƯA VIẾT — Host làm mẫu trước)
├── ansible/                      # remediation playbook tầng Host  (CHƯA VIẾT)
├── evidence/  reports/           # đầu ra
```

## Đưa code lên VM

**Khi clipboard/drag-drop chưa hoạt động** (chưa cài open-vm-tools) — không cần
cài gì trên VM, chỉ dùng mạng host-only. Trên **máy thật**:

```bash
cd .../lab && tar czf /tmp/lab.tgz --exclude=data/seed/out --exclude=data/tls/certs .
cd /tmp && python3 -m http.server 8000
```

Trên **mỗi VM** (python3 luôn có sẵn, `172.16.50.1` = máy thật qua host-only):

```bash
python3 -c "import urllib.request;urllib.request.urlretrieve('http://172.16.50.1:8000/lab.tgz','lab.tgz')"
mkdir -p ~/lab && tar xzf lab.tgz -C ~/lab && cd ~/lab
```

Thư mục phải là `~/lab` vì `00-env.sh` mặc định `LAB_ROOT=$HOME/lab`.

> **Thao tác qua SSH, không dùng console đen của VMware.** Console text của VMware
> không hiển thị được tiếng Việt có dấu (font console chỉ ~512 glyph) và không
> paste được. Sau khi `bootstrap-target.sh` bật sshd + tạo `labadmin`, từ **máy thật**:
> `ssh labadmin@172.16.50.20` (Kali: `ssh kali@172.16.50.10`) — tiếng Việt hiện đúng,
> copy-paste chạy bình thường.

**Đồng bộ một file đã sửa** (sau khi VM đã có SSH) — nhanh hơn đóng gói lại cả lab:
```bash
scp bootstrap/bootstrap-target.sh labadmin@172.16.50.20:~/lab/bootstrap/
```

Sau khi PHASE 1A dựng vsftpd, cũng có thể upload thêm file bằng chính FTP yếu đó
(ground truth GT-H05): `curl -T <file> ftp://test:123456@172.16.50.20/`.

## Khởi động lab (trên VM Target Linux `172.16.50.20`)

```bash
source 00-env.sh

# 1) Tầng Application
docker compose -f app/docker-compose.yml up -d
docker build -t lab/bad-app:demo app/bad-image      # image "xấu" cho config/SCA scanning
# DVWA cần bấm Create/Reset Database một lần:
curl -s -c /tmp/c http://localhost:8080/setup.php >/dev/null
curl -s -b /tmp/c -d 'create_db=Create / Reset Database' http://localhost:8080/setup.php >/dev/null

# 2) Tầng Data
bash data/tls/gen-cert.sh
python3 data/seed/gen_pii.py --count 1000
docker compose -f data/docker-compose.yml up -d
bash data/seed/seed_all.sh
```

## Kiểm chứng nhanh (mỗi dòng là một finding sẽ demo)

```bash
curl -sI http://172.16.50.20/ | grep -icE 'content-security|strict-transport|x-frame'   # => 0
mongosh --host 172.16.50.20 --quiet --eval 'db.getSiblingDB("hocvien").hoc_vien.countDocuments()'
redis-cli -h 172.16.50.20 GET app:db:password
curl -s http://172.16.50.20:9000/hocvien-backup/pii.csv | head -3
curl -s http://172.16.50.20/backup/                                                    # autoindex
echo | openssl s_client -connect 172.16.50.20:8443 -tls1 2>/dev/null | grep Protocol
```

## Mini DLP scanner

```bash
# Storage sensor (data at rest) + chấm FP/FN theo ground truth
python3 dlp/dlp_scan.py \
  --fs /srv/shared /home/labadmin/tailieu \
  --mongo mongodb://172.16.50.20:27017 \
  --index data/seed/out/pii.json \
  --truth data/seed/out/ground-truth-pii.json \
  --json reports/dlp-report.json

# Agent sensor (data in use)
python3 dlp/dlp_scan.py --proc
```

Kết quả trên bộ dữ liệu mẫu (`--fs data/seed/out`) — **đây là số để lên slide**:

| Loại | Ground truth | Tìm thấy (uniq) | FN | FP |
|---|---:|---:|---:|---:|
| cccd | 1000 | 1240 | 0 | **240** |
| sdt | 1000 | 1000 | 0 | 0 |
| email | 1000 | 1000 | 0 | 0 |
| the_ngan_hang | 1000 | 1000 | 0 | 0 |

240 FP đến từ `bao-cao-kho.csv` — mã đơn hàng 12 chữ số vượt qua cả regex lẫn
hậu kiểm mã tỉnh. Index matching bắt đúng 4000/4000 giá trị đã biết và đánh dấu
240 giá trị "ngoài index". **Đó chính là đánh đổi của slide 47**: content
inspection thấy dữ liệu mới nhưng đẻ FP; index matching sạch FP nhưng mù dữ liệu mới.

## Ground truth — đừng "sửa hộ" các lỗi cố ý

Mỗi lỗi cố tình đều được đánh mã trong comment ngay tại file:

| Mã | Ở đâu | Nội dung |
|---|---|---|
| `BAD-01..10` | `app/bad-image/Dockerfile` | latest tag, root, secret trong ENV, apt không pin, không HEALTHCHECK… |
| `SAST-01..07` | `app/bad-image/app.py` | hardcoded secret, SQLi, command injection, XSS, unsafe yaml, path traversal, nuốt exception |
| `DATA-01..05` | `data/docker-compose.yml`, `data/tls/` | Mongo no-auth, Redis no-pass, MinIO public, TLS yếu, key quyền 644 |
| (thiếu header) | `app/nginx/default.conf` | CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy |

## Còn phải làm

- [x] **Host tier (làm mẫu)**: `target/host/make-*.sh` (7 defect + make-all) ↔ `scanner/host/scan-01..07` + `run-all` + `ground-truth-host.md` (ma trận)
- [ ] **App tier**: `target/app/make-*.sh` ↔ `scanner/app/scan-01..06` + `ground-truth-app.md` (nhân từ khuôn Host)
- [ ] **Data tier**: `target/data/make-*.sh` ↔ `scanner/data/scan-01..06` + `ground-truth-data.md`
- [ ] `ansible/remediate-host.yml`
- [ ] ZAP authenticated context cho DVWA (rủi ro #2 của brief — làm sớm)
- [ ] Slide + báo cáo NIST SP 800-115

## Lưu ý về git

`app/bad-image/.env` **là credential bịa** và được commit có chủ đích để
`gitleaks` / `trivy --scanners secret` có mồi quét. Không phải rò rỉ thật.
