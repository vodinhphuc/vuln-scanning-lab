# Ground truth — Tầng APPLICATION (container trên VM Target 172.16.50.20)

> Lỗ hổng **cố tình tạo** bởi `target/app/make-*.sh` (orchestrator `make-all.sh`).
> Chân lý nền để tính False Negative/Positive khi quét. **Đừng "sửa hộ".**

Bốn ống kính: **Config · SCA · SAST · DAST** — mỗi ống nhìn một artifact khác nhau.

| Mã | Lỗ hổng cố ý | Slide Ch.4 | Ống kính / scanner | Bằng chứng |
|---|---|---|---|---|
| GT-A01 | nginx thiếu security header (CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy) | 37 | Config — `curl -I`, nikto, ZAP | `curl -sI http://172.16.50.20/` |
| GT-A02 | nginx `server_tokens on` (lộ version) + `autoindex` `/backup/` (liệt kê file) | 37 | Config — nikto, ffuf | `curl -s http://172.16.50.20/backup/` |
| GT-A03 | Dockerfile BAD-01..10: `:latest`, USER root, secret trong ENV, apt không pin, COPY ., no HEALTHCHECK, shell ENTRYPOINT | 37, 43-44 | Config — `trivy config` | `trivy config app/bad-image` |
| GT-A04 | Dependency dính CVE: Flask 0.12.2, Jinja2 2.10, urllib3 1.24.1, PyYAML 5.1, requests 2.19.1 + CVE OS base image | 43-44 | SCA — syft+grype, trivy image | `syft dir:app/bad-image \| grype` |
| GT-A05 | Mã nguồn `app.py` SAST-01..07: hardcoded secret, SQLi nối chuỗi, command injection (shell=True), XSS, `yaml.load`, path traversal, nuốt exception | 38-41 | SAST — semgrep | `semgrep --config semgrep-lab.yaml app.py` |
| GT-A06 | Secret `.env` (DB_PASSWORD, AWS key, MINIO) bị COPY vào image + commit | 38 | Config/secret — gitleaks, `trivy --scanners secret` | `gitleaks dir app/` |
| GT-A07 | DVWA + Juice Shop cố ý dễ tổn thương (SQLi, XSS, …) | 36-42 | DAST — OWASP ZAP | ZAP baseline/full report |
| GT-A08 | `clientside.html`: form chỉ validate bằng JavaScript → bypass được | 42 | DAST/thủ công — DevTools/Burp | tắt JS, submit payload |

## Script tạo ↔ script quét

| Nhóm GT | Script TẠO (target/app/) | Script QUÉT (scanner/app/) |
|---|---|---|
| A01·A02·A07·A08 | `make-webstack.sh` | scan-01-config, scan-04/05-dast, scan-06-fuzz |
| A03·A04·A05·A06 | `make-badimage.sh` | scan-01-config, scan-02-sca, scan-03-sast |

Config/SCA/SAST/secret quét **cục bộ trên Kali** (source repo scp về, offline). DAST + kiểm
header quét vào app **đang chạy** trên Target.

## Ma trận độ phủ — điểm chốt của tầng App

| Lỗ hổng | Config | SCA | SAST | DAST | Thủ công |
|---|:-:|:-:|:-:|:-:|:-:|
| Thiếu security header (A01) | ✓ | ✕ | ✕ | ✓ | – |
| Dependency CVE (A04) | ✕ | ✓ | ✕ | ~ | – |
| SQLi trong code (A05) | ✕ | ✕ | ✓ | ✓ | ✓ |
| Bypass client-side (A08) | ✕ | ✕ | ✕ | ~ | ✓ |
| Container chạy root (A03) | ✓ | ✕ | ✕ | ✕ | – |
| Lỗi logic nghiệp vụ | ✕ | ✕ | ✕ | ✕ | ✓ |

Hàng cuối không scanner nào chạm tới → application security là quy trình xuyên suốt, không phải một công cụ.

## Sau remediation phải đảo trạng thái

Thêm security header vào nginx, pin base image + tạo user thường + bỏ secret khỏi ENV,
nâng cấp dependency, thay SQL nối chuỗi bằng prepared statement (`get_user_safe`), xoá `.env`
khỏi image. Chạy lại `scan-01/02/03` → finding giảm; ZAP baseline → hết alert header.
