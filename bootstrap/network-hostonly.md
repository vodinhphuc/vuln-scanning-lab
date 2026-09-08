# Mạng lab: giữ CẢ HAI adapter, không chuyển qua lại

Sai lầm tốn thời gian nhất là cấu hình NAT để tải, rồi đổi sang host-only để
demo, rồi lại đổi về NAT vì thiếu một gói. Mỗi lần đổi là một lần sửa netplan
và một lần mất IP tĩnh.

**Cách làm đúng: mỗi VM có 2 card mạng.**

| Adapter | Loại | Vai trò | Trạng thái lúc demo |
|---|---|---|---|
| Network Adapter 1 | NAT | tải gói, sync feed | **bỏ tick "Connected"** |
| Network Adapter 2 | Host-only (VMnet1) | mạng lab `172.16.50.0/24` | luôn bật |

Lúc demo chỉ cần bỏ tick *Connected* của Adapter 1 trong VM Settings —
không cần shutdown, không cần sửa file nào. Slide scope vẫn nói đúng sự thật:
"không có đường ra Internet trong lúc demo".

> 💡 **Đặt IP tĩnh tự động thay vì làm tay các mục 2–3 bên dưới:**
> `sudo bash set-lab-ip.sh 20` (Target) · `sudo bash set-lab-ip.sh 10` (Kali).
> Script tự nhận card host-only, tự chọn netplan (Ubuntu) hay nmcli (Kali), và
> giữ default route qua NAT. Ép card nếu tự nhận sai: `sudo IFACE=ens37 bash set-lab-ip.sh 20`.
> Các mục 2–3 dưới đây là bản làm tay để hiểu script làm gì.

## 1. VMware: host-only đã có sẵn — chỉ cần gắn vào VM

Máy này **đã có** vmnet1 host-only `172.16.50.0/24` (host = `172.16.50.1`),
nên KHÔNG cần tạo mới hay đổi subnet. Kiểm chứng trên máy thật:

```bash
ip -br addr show vmnet1        # -> 172.16.50.1/24
```

DHCP của vmnet1 cấp dải `.128–.254`. Ta đặt IP tĩnh `.10`/`.20`/`.30` nằm
**dưới** dải đó nên không đụng DHCP — không cần tắt DHCP.

Với **từng VM** (khi VM đang tắt): `VM > Settings > Add > Network Adapter >
Custom (VMnet1: Host-only)`. Giữ luôn adapter NAT (VMnet8) đang có để còn tải gói.

## 2. Ubuntu 22.04 — đặt IP tĩnh cho NIC thứ hai (netplan)

Xem tên card trước (NIC2 thường là `ens37` / `ens192`, cái KHÔNG có IP DHCP):

```bash
ip -br addr
```

Tạo file mới, **không** sửa file cấu hình NAT có sẵn:

```bash
sudo tee /etc/netplan/99-lab-hostonly.yaml >/dev/null <<'YAML'
network:
  version: 2
  ethernets:
    ens37:                      # <-- ĐỔI thành tên NIC2 thật
      dhcp4: false
      addresses: [172.16.50.20/24]     # Target Linux; Scanner dùng .10
      # KHÔNG khai gateway4 / nameservers ở đây:
      # default route phải đi qua NAT, không đi qua host-only.
YAML
sudo chmod 600 /etc/netplan/99-lab-hostonly.yaml
sudo netplan apply
ip -br addr show ens37
```

## 3. Kali (Scanner) — cũng 2 NIC, IP `.10`

Kali dùng NetworkManager:

```bash
NIC2=eth1        # kiểm tra bằng: ip -br addr
sudo nmcli con add type ethernet ifname $NIC2 con-name lab-hostonly \
     ipv4.method manual ipv4.addresses 172.16.50.10/24 ipv4.never-default yes
sudo nmcli con up lab-hostonly
```

`ipv4.never-default yes` là mấu chốt — nếu thiếu, NetworkManager có thể đẩy
default route sang card host-only và Kali mất Internet giữa lúc đang tải.

## 4. Kiểm chứng (từ Scanner)

```bash
ping -c2 172.16.50.20      # thấy target qua host-only
ping -c2 8.8.8.8            # vẫn ra được Internet qua NAT
ip route | head -3          # default route phải đi qua NIC NAT
```

## 5. Lúc demo

- VM Settings > Network Adapter 1 (NAT) > **bỏ tick Connected** trên cả 2 VM
- Chạy lại `ping -c1 8.8.8.8` cho cả lớp thấy nó fail → đó là bằng chứng scope
