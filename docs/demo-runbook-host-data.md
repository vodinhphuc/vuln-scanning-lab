# Kịch bản demo — Host + Data (rà quét lỗ hổng)

Runbook để **tổng duyệt** buổi thực hành. Chỉ gồm tầng **Host** và **Data**
(App do người khác trình bày). Bám vòng đời 7 bước:
`Asset discovery → Scanning → Validation → Prioritization → Remediation → Verification → Reporting`.

Lab hiện tại: deep-dive host = **lab-01 = 172.16.50.21**; clone breadth = `.22`, `.23`.
Scanner (Kali) = `.10`. Mạng host-only, không NAT lúc demo.

---

## Pre-flight — làm 1 lần TRƯỚC khi có khán giả

```bash
# trên Kali
source ~/lab/00-env.sh && export TARGET=172.16.50.21
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9392   # GVM phải 200/302
```

- [ ] **Snapshot .21** = `host+data-vuln` (revert 10s nếu live hỏng).
- [ ] **GVM: quét sẵn unauth + auth, LƯU 2 report** (phòng live fail).
- [ ] Font terminal to, tắt notification, tắt screensaver.
- [ ] Mở sẵn tab: GVM Web UI (`http://127.0.0.1:9392`, admin/labadmin) + Wireshark.
- [ ] Kiểm cả 3 máy sống: `nmap -sn 172.16.50.21-23`.

---

## Phần 0 — Khung (slide, ~3′)

Title → **slide "Tại sao cần rà quét"** → Scope/RoE → **vòng đời 7 bước**
(chỉ vào Validation + Verification: "hai bước hay bị bỏ nhất").

---

## Phần 1 — HOST (~12′) — đi theo vòng đời

| # | Lệnh | Money shot / nói gì |
|---|---|---|
| 1. Asset discovery | `bash ~/lab/scanner/host/scan-01-discovery.sh` | Sweep thấy **.21/.22/.23 = một mạng nhiều máy** + service thừa 21/23/111 |
| 2. Baseline score | `bash ~/lab/scanner/host/scan-03-openscap.sh` | CIS score % + danh sách rule fail |
| 3. Config baseline tự viết | `bash ~/lab/scanner/host/scan-08-baseline.sh` | PASS/FAIL PAM · iptables · SSH AllowUsers thừa — "thứ công ty tự viết ngoài Lynis/OpenSCAP" |
| 4. **Unauth ↔ Auth** (showpiece) | 2 report GVM đã lưu | Số finding **nhảy vọt** khi có SSH cred. *Fallback nếu GVM chưa lên:* `nmap -sV` (unauth) vs `bash ~/lab/scanner/host/scan-02-lynis.sh` (auth) |
| 5. FTP anonymous | `nmap --script ftp-anon -p21 172.16.50.21` | Anonymous login được — GT-H05 |
| 6. Antimalware | `bash ~/lab/scanner/host/scan-07-eicar.sh` | ClamAV bắt EICAR |

---

## Phần 2 — DATA (~12′) — theo 3 trạng thái dữ liệu

| # | Lệnh | Money shot |
|---|---|---|
| 1. At rest — datastore no-auth | `bash ~/lab/scanner/data/scan-01-datastore.sh` | Mongo/Redis trả lời **không cần credential** |
| 2. At rest — **bucket public** ⭐ | `curl -s http://172.16.50.21:9000/hocvien-backup/pii.csv \| head` | Tải **PII giả** (CCCD, số thẻ NH) không cần đăng nhập — đỉnh nhất tầng Data |
| 3. At rest — secrets | `bash ~/lab/scanner/data/scan-02-secrets.sh` | gitleaks/trivy tìm credential hardcode |
| 4. In transit — TLS yếu | `bash ~/lab/scanner/data/scan-05-tls.sh` | TLS 1.0/1.1 + cipher yếu (8443) |
| 5. In transit — **bắt gói plaintext** ⭐ | `bash ~/lab/scanner/data/scan-06-capture.sh` + sinh traffic `curl ftp://test:123456@172.16.50.21/` → Wireshark **Follow TCP/HTTP Stream** | Thấy **user/pass nguyên văn** trên màn chiếu |
| 6. Mini DLP + 3 sensor | `python3 ~/lab/dlp/dlp_scan.py --fs data/seed/out --index data/seed/out/pii.json --truth data/seed/out/ground-truth-pii.json` | 240 FP có sẵn → đánh đổi content-inspection vs index-matching (slide 47) |

Ba sensor DLP (slide 48): network = scan-06 · storage = scan-03 · agent = `dlp_scan.py --proc` (trên target).

---

## Phần 3 — Validation → Remediation → Verification (~4′)

- **Validation**: đối chiếu `scripts/ground-truth-host.md` + `scripts/ground-truth-data.md`
  → tính FN (scanner bỏ sót) / FP (báo thừa). FP nổi tiếng: 240 của DLP.
- **Remediation + Verification** — ⚠️ `ansible/remediate-host.yml` **chưa có**, nên
  làm **thủ công 1 mục live** để chứng minh vòng lặp: ví dụ bật auth MongoDB
  (hoặc `rm` sshd drop-in + restart ssh) → **chạy lại** scan tương ứng →
  **finding biến mất**. Đó chính là bước Verification.
- **Reporting** (bước 7): gom vào report NIST SP 800-115.

---

## 3 khoảnh khắc phải tập ≥ 3 lần (dễ vấp)

1. **MinIO bucket rò PII** (đã verify chạy ✅).
2. **tcpdump + Wireshark Follow Stream** ra user/pass — canh thời điểm login, khó nhất.
3. **Unauth ↔ Auth số nhảy** (hoặc fallback nmap-vs-lynis).

---

## Gap đã biết (nói thẳng nếu bị hỏi)

- `ansible/remediate-host.yml` chưa viết → Verification làm thủ công.
- GVM feed sync 1–3h → phải quét & lưu report TRƯỚC, không chạy sync live.
- Clone `.22/.23` clone trước khi fix bug vsftpd/sshd → chỉ dùng cho sweep breadth,
  không có FTP/SSH-weak. Deep-dive đầy đủ chỉ ở `.21`.
