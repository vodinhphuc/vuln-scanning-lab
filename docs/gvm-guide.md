# GVM / Greenbone — khởi động & kịch bản demo

Chạy trên **Kali Scanner** (`172.16.50.10`). Container `gvmd` (image `immauss/openvas`),
feed lưu trong volume `gvm-data` (đã sync trước → không cần tải lại).

---

## 1. Khởi động GVM

### Cách khuyến nghị (nhanh, chạy offline) — bỏ qua sync
Feed đã nằm trong volume `gvm-data`, nên **bỏ sync** để lên "ready" trong ~1–3 phút,
không phụ thuộc Internet:

```bash
sudo docker rm -f gvmd 2>/dev/null
sudo docker run -d --name gvmd -p 9392:9392 \
  -e SKIPSYNC=true -e PASSWORD=labadmin \
  -v gvm-data:/data immauss/openvas:latest

sudo docker logs -f gvmd        # chờ dòng "container is now ready to use!" -> Ctrl-C
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9392   # mong 200/302
```

> `Ctrl-C` chỉ thoát xem log, **không** giết container.

### Nếu container đã có sẵn (chỉ bị tắt)
```bash
sudo docker start gvmd
```
⚠️ Cách này khiến entrypoint **cố sync lại feed từ Internet** — không còn NAT thì nó
**treo và gsad không lên** (curl mãi `000`). Gặp vậy thì quay lại "Cách khuyến nghị"
(recreate với `SKIPSYNC=true`) — volume giữ nguyên feed nên không mất gì.

### Vào Web UI
- Địa chỉ: `http://127.0.0.1:9392` — **HTTP, KHÔNG https** (gsad phục vụ HTTP trần;
  gõ `https://` sẽ lỗi `PR_END_OF_FILE_ERROR`).
- Đăng nhập: `admin` / `labadmin`.

### Xử lý sự cố nhanh
| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `curl :9392` = `000` | gsad chưa lên / đang sync | đợi thêm; nếu kẹt sync → recreate `SKIPSYNC=true` |
| Log dừng ở "Downloading … rsync://…" | đang sync feed (thừa vì đã current) | recreate `SKIPSYNC=true` |
| Ready rồi mà web không vào | gsad chưa sẵn | `sudo docker restart gvmd; sleep 60` rồi thử lại |
| `https://` báo `PR_END_OF_FILE_ERROR` | gõ nhầm https | dùng `http://` |

---

## 2. Mục tiêu phần GVM

Showpiece **unauthenticated ↔ authenticated scan**: cùng một máy, cùng một công cụ,
khác **duy nhất** ở chỗ có SSH credential hay không. Chứng minh **patch management
(GT-H10)** — quét không đăng nhập chỉ thấy bề mặt; quét có đăng nhập đọc được danh
sách gói → thấy **toàn bộ missing patch**. Số finding nhảy vọt = money shot.

## 3. ⚠️ Chạy TRƯỚC, đừng quét live
Mỗi lần quét ~5–20 phút. **Chạy cả hai trước demo, lưu 2 report**, lúc demo chỉ chiếu
kết quả + kể chuyện.

## 4. Các bước trong Web UI

**Lần 1 — Unauthenticated**
1. `Configuration → Targets → New Target`: Name `lab-unauth`, Hosts `172.16.50.21`,
   Port List `All IANA assigned TCP`, Credentials SSH **để trống**.
2. `Scans → Tasks → New Task`: chọn target `lab-unauth`, Scan Config `Full and fast` → ▶.

**Lần 2 — Authenticated**
3. `Configuration → Credentials → New Credential`: Type `Username + Password`,
   Username `labadmin`, Password `LabOnly!2026`.
4. `Configuration → Targets → New Target`: Name `lab-auth`, Hosts `172.16.50.21`,
   **SSH Credential = credential vừa tạo (cổng 22)**.
5. `Scans → Tasks → New Task`: target `lab-auth` → ▶.
6. Chờ cả hai `Done` → `Scans → Reports`, ghi lại **số vulnerability** mỗi lần.

## 5. Lời nói từng phần

**A — Unauth (chiếu report `lab-unauth`):**
> "Không credential, Greenbone chỉ thấy thứ lộ ra mạng: cổng mở, version qua banner,
> rồi **suy luận** CVE từ khoảng version. Được **N** finding — chưa biết bên trong đã vá gì."

**B — Auth (chiếu report `lab-auth`):**
> "Thêm đúng một SSH credential. Scanner đăng nhập, chạy `dpkg -l` lấy danh sách gói
> chính xác, đối chiếu advisory Ubuntu → thấy **toàn bộ missing patch**. **M** finding —
> gấp nhiều lần. Cùng máy, cùng tool, chỉ thêm credential."

**C — Bài học (chốt):**
> "Báo cáo 'sạch' có khi chỉ vì scanner **chưa được cho nhìn đủ**. Authenticated scan
> mới cho bức tranh thật về patch management (GT-H10)."
> FP: "Ubuntu hay **backport** bản vá nhưng giữ nguyên version → scanner báo nhầm.
> Đó chính là lý do bước sau là **Validation**."

## 6. Fallback nếu GVM không kịp
```bash
nmap -sV 172.16.50.21                       # unauth: chỉ version qua banner
ssh labadmin@172.16.50.21 sudo lynis audit system --quick   # auth: thấy sâu hơn hẳn
```
Cùng luận điểm unauth↔auth, không cần GVM.
