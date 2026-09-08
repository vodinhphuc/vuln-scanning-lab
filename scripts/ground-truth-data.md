# Ground truth — Tầng DATA (container trên VM Target 172.16.50.20)

> Lỗ hổng **cố tình tạo** bởi `target/data/make-*.sh` (orchestrator `make-all.sh`).
> Tổ chức theo **ba trạng thái dữ liệu** của slide 46: at rest · in transit · in use.
> Toàn bộ PII là **dữ liệu BỊA** sinh bởi `gen_pii.py` (seed cố định) — không của ai thật.

| Mã | Lỗ hổng cố ý | Trạng thái | Scanner | Bằng chứng |
|---|---|---|---|---|
| GT-D01 | MongoDB không `--auth`, `--bind_ip_all` (27017) | at rest | scan-01 — nmap mongodb-info, mongosh | `mongosh mongodb://172.16.50.20:27017` |
| GT-D02 | Redis `--protected-mode no`, không `requirepass` (6379) | at rest | scan-01 — nmap redis-info, redis-cli | `redis-cli -h 172.16.50.20 GET app:db:password` |
| GT-D03 | MinIO bucket `hocvien-backup` policy public-read (9000) | at rest | scan-03 — curl | `curl http://172.16.50.20:9000/hocvien-backup/pii.csv` |
| GT-D04 | HTTPS bật TLS 1.0/1.1 + cipher yếu `@SECLEVEL=0` (8443) | in transit | scan-05 — testssl.sh, nmap ssl-enum-ciphers | `testssl.sh https://172.16.50.20:8443` |
| GT-D05 | Cert self-signed RSA-1024, SHA-1, CN sai, key quyền 644 | in transit | scan-05 — testssl.sh; Lynis (perm key) | `openssl x509 -in weak.crt -noout -subject` |
| GT-D06 | PII giả rải ở Mongo/Redis/web `/backup`/filesystem, không mã hoá | at rest | scan-03 — mini DLP (dlp_scan.py) | `dlp_scan.py --fs … --mongo …` |
| GT-D07 | Đăng nhập HTTP plaintext (mật khẩu bay qua mạng) | in transit | scan-06 — tcpdump/Wireshark | Follow HTTP Stream thấy `password=` |
| GT-D08 | Connection string + secret hardcode (chồng lấn GT-A06) | at rest | scan-02 — gitleaks, trivy secret | `gitleaks dir lab/` |
| GT-D-enc | Đĩa target KHÔNG mã hoá (không LUKS) | at rest | scan-04 — lsblk, cryptsetup | `lsblk` không thấy `crypt` |
| GT-D-use | Secret lộ qua tiến trình (`/proc`, `ps`) — data in use | in use | dlp_scan.py `--proc` (agent sensor) | `/proc/<pid>/environ` |

## Script tạo ↔ script quét

| Nhóm GT | Script TẠO (target/data/) | Script QUÉT (scanner/data/) |
|---|---|---|
| D01·D02·D03·D04 | `make-datastores.sh` | scan-01-datastore, scan-03-storage, scan-05-tls |
| D05 | `make-tls.sh` | scan-05-tls |
| D06·D-use | `make-seed.sh` | scan-03-storage, dlp_scan.py --proc |
| D07 | `make-datastores` (HTTP) + login | scan-06-capture |
| D08 | (source .env sẵn có) | scan-02-secrets |
| D-enc | (không có script — đĩa VM mặc định) | scan-04-encryption |

Quét mạng (datastore/TLS/bucket) chạy **từ Kali**; DLP filesystem, kiểm mã hoá đĩa, bắt gói
chạy **trên target** (scan script tự SSH vào).

## Ba sensor DLP (slide 48) → ba phép quét

| Sensor | Trạng thái | Ở đâu | Script |
|---|---|---|---|
| Network | in transit | Kali/target | scan-06-capture (tcpdump) |
| Storage | at rest | target | scan-03-storage (dlp_scan.py --fs/--mongo) |
| Agent | in use | target | dlp_scan.py --proc |

## Kết quả DLP mẫu (bộ seed cố định) — số để lên slide

| Loại | Ground truth | Tìm thấy (uniq) | FN | FP |
|---|---:|---:|---:|---:|
| cccd | 1000 | 1240 | 0 | **240** |
| sdt | 1000 | 1000 | 0 | 0 |
| email | 1000 | 1000 | 0 | 0 |
| the_ngan_hang | 1000 | 1000 | 0 | 0 |

240 FP từ `bao-cao-kho.csv` (mã đơn 12 số vượt cả regex lẫn hậu kiểm mã tỉnh) — minh hoạ
đánh đổi slide 47: content inspection thấy dữ liệu mới nhưng đẻ FP; index matching sạch FP nhưng mù dữ liệu mới.

## Sau remediation phải đảo trạng thái

Bật auth Mongo (`--auth` + user), `requirepass` cho Redis, bucket MinIO về private,
cert RSA-2048/SHA-256/CN đúng + `chmod 600` key, tắt TLS 1.0/1.1 (`ssl_protocols TLSv1.2 TLSv1.3`),
ép HTTPS (HSTS + redirect). Chạy lại `scan-01/03/05/06` → đóng.
