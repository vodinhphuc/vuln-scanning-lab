#!/usr/bin/env python3
"""
gen_pii.py — sinh ~1000 bản ghi PII GIẢ cho tầng Data.

╔══════════════════════════════════════════════════════════════════════════╗
║  DỮ LIỆU BỊA HOÀN TOÀN. Sinh bằng random với seed cố định.                ║
║  Không lấy từ bất kỳ nguồn dữ liệu thật nào. Không tương ứng với bất kỳ   ║
║  người thật nào. Chỉ dùng trong mạng lab host-only.                       ║
╚══════════════════════════════════════════════════════════════════════════╝

Ánh xạ giáo trình: slide 45–48 (Big Data, DLP, ba trạng thái dữ liệu).
Đây là "kho báu" mà mini DLP scanner (dlp/dlp_scan.py) phải tìm ra, và là
ground truth để tính False Negative của scanner đó.

Xuất ra thư mục ./out/ :
  pii.json              — nạp vào MongoDB (data-01)
  pii.csv               — file phẳng trên filesystem, mồi cho storage sensor
  hocvien-backup.sql    — backup KHÔNG mã hoá, upload lên MinIO public + web root
  ground-truth-pii.json — đếm chính xác từng loại PII, để chấm FP/FN

Dùng:  python3 gen_pii.py [--count 1000] [--out ./out]
"""
import argparse
import csv
import json
import os
import random
import unicodedata

SEED = 20260906  # seed cố định -> chạy lại cho ra đúng bộ dữ liệu cũ

HO = ["Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Huỳnh", "Phan", "Vũ", "Võ",
      "Đặng", "Bùi", "Đỗ", "Hồ", "Ngô", "Dương", "Lý", "Đinh", "Mai", "Chu", "Tạ"]
DEM_NAM = ["Văn", "Hữu", "Đức", "Quang", "Minh", "Thành", "Xuân", "Bá", "Công", "Tuấn"]
DEM_NU = ["Thị", "Thu", "Ngọc", "Thanh", "Kim", "Mỹ", "Hoài", "Diệu", "Khánh", "Phương"]
TEN_NAM = ["An", "Bình", "Cường", "Dũng", "Hải", "Hùng", "Khoa", "Long", "Nam", "Phúc",
           "Quân", "Sơn", "Thắng", "Trung", "Tùng", "Việt", "Vinh", "Đạt", "Hiếu", "Kiên"]
TEN_NU = ["Anh", "Chi", "Dung", "Giang", "Hà", "Hằng", "Hoa", "Lan", "Linh", "Mai",
          "Nga", "Ngân", "Nhung", "Oanh", "Phượng", "Quỳnh", "Thảo", "Trang", "Vân", "Yến"]

# Mã tỉnh dùng cho 3 số đầu CCCD (định dạng thật, dữ liệu bên trong là bịa)
MA_TINH = ["001", "002", "004", "006", "008", "010", "011", "012", "014", "015",
           "017", "019", "020", "022", "024", "025", "026", "027", "030", "031",
           "033", "034", "035", "036", "037", "038", "040", "042", "044", "045",
           "046", "048", "049", "051", "052", "054", "056", "058", "060", "062",
           "064", "066", "067", "068", "070", "072", "074", "075", "077", "079",
           "080", "082", "083", "084", "086", "087", "089", "091", "092", "093",
           "094", "095", "096"]

# Đầu số di động Việt Nam (định dạng thật, số bên trong là bịa)
DAU_SO = ["032", "033", "034", "035", "036", "037", "038", "039",
          "070", "076", "077", "078", "079",
          "081", "082", "083", "084", "085", "088", "091", "094",
          "056", "058", "092", "059", "099", "090", "093", "089"]

MAIL_DOMAIN = ["gmail.com", "yahoo.com", "outlook.com", "hocvien.edu.vn",
               "sinhvien.hocvien.edu.vn", "example.org"]

KHOA = ["CNTT", "Điện tử", "Cơ khí", "Hoá lý", "Vô tuyến", "Điều khiển", "An toàn thông tin"]

BANK_PREFIX = ["9704", "4532", "5412"]  # định dạng thẻ, số bịa


def khong_dau(s: str) -> str:
    """Bỏ dấu tiếng Việt để sinh email — cũng là cách VOCAB gọi là normalization."""
    s = s.replace("đ", "d").replace("Đ", "D")
    return "".join(c for c in unicodedata.normalize("NFD", s)
                   if unicodedata.category(c) != "Mn")


def sinh_cccd(rng, nam_sinh: int, gioi: str) -> str:
    """12 số: [3 mã tỉnh][1 thế kỷ+giới][2 năm sinh][6 ngẫu nhiên]."""
    tinh = rng.choice(MA_TINH)
    # thế kỷ 20: nam=0 nữ=1 ; thế kỷ 21: nam=2 nữ=3
    if nam_sinh < 2000:
        tk = "0" if gioi == "Nam" else "1"
    else:
        tk = "2" if gioi == "Nam" else "3"
    return f"{tinh}{tk}{nam_sinh % 100:02d}{rng.randrange(0, 10**6):06d}"


def sinh_sdt(rng) -> str:
    return rng.choice(DAU_SO) + f"{rng.randrange(0, 10**7):07d}"


def _luhn_check_digit(so: str) -> int:
    """Chữ số kiểm tra Luhn — số thẻ thật luôn thoả, nên DLP dùng nó lọc FP."""
    ds = [int(c) for c in so][::-1]
    tong = 0
    for i, d in enumerate(ds):
        if i % 2 == 0:      # vị trí sẽ bị nhân đôi sau khi thêm check digit
            d *= 2
            if d > 9:
                d -= 9
        tong += d
    return (10 - tong % 10) % 10


def sinh_the(rng) -> str:
    """16 chữ số, HỢP LỆ Luhn — để bộ lọc Luhn của dlp_scan.py không loại nhầm."""
    than = rng.choice(BANK_PREFIX) + f"{rng.randrange(0, 10**11):011d}"
    return than + str(_luhn_check_digit(than))


def sinh_ban_ghi(rng, i: int) -> dict:
    gioi = rng.choice(["Nam", "Nữ"])
    ho = rng.choice(HO)
    dem = rng.choice(DEM_NAM if gioi == "Nam" else DEM_NU)
    ten = rng.choice(TEN_NAM if gioi == "Nam" else TEN_NU)
    ho_ten = f"{ho} {dem} {ten}"
    nam_sinh = rng.randint(1975, 2005)
    slug = khong_dau(f"{ten}{dem}{ho}").lower()
    return {
        "_id": i,
        "ma_hoc_vien": f"HV{i:05d}",
        "ho_ten": ho_ten,
        "gioi_tinh": gioi,
        "nam_sinh": nam_sinh,
        "cccd": sinh_cccd(rng, nam_sinh, gioi),
        "so_dien_thoai": sinh_sdt(rng),
        "email": f"{slug}{rng.randint(1, 999)}@{rng.choice(MAIL_DOMAIN)}",
        "khoa": rng.choice(KHOA),
        "the_ngan_hang": sinh_the(rng),
        "dia_chi": f"Số {rng.randint(1, 300)}, đường {rng.choice(TEN_NU)}, "
                   f"quận {rng.randint(1, 12)}, Hà Nội",
        "ghi_chu": "DU LIEU GIA - SYNTHETIC LAB DATA - KHONG PHAI NGUOI THAT",
    }


def viet_sql(path: str, rows: list) -> None:
    """Backup .sql KHÔNG mã hoá — mồi cho data-03-storage.sh."""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("-- hocvien-backup.sql\n")
        fh.write("-- DU LIEU GIA HOAN TOAN, sinh boi gen_pii.py, chi dung trong lab.\n")
        fh.write("-- Backup nay CO TINH khong ma hoa va de o noi doc duoc qua HTTP.\n\n")
        fh.write("CREATE TABLE hoc_vien (\n"
                 "  id INT PRIMARY KEY,\n"
                 "  ma_hoc_vien VARCHAR(16),\n"
                 "  ho_ten VARCHAR(128),\n"
                 "  cccd CHAR(12),\n"
                 "  so_dien_thoai VARCHAR(16),\n"
                 "  email VARCHAR(128),\n"
                 "  the_ngan_hang VARCHAR(20)\n"
                 ");\n\n")
        for r in rows:
            ho_ten = r["ho_ten"].replace("'", "''")
            fh.write(
                "INSERT INTO hoc_vien VALUES ("
                f"{r['_id']}, '{r['ma_hoc_vien']}', '{ho_ten}', "
                f"'{r['cccd']}', '{r['so_dien_thoai']}', "
                f"'{r['email']}', '{r['the_ngan_hang']}');\n"
            )


def viet_moi_fp(path: str, rng) -> int:
    """File MỒI: chuỗi 12 chữ số KHÔNG phải CCCD (mã đơn hàng, mã lô, timestamp).

    Chúng cố tình có 3 số đầu trùng mã tỉnh và số thứ 4 trong 0-3, nên vượt
    qua được cả regex lẫn hậu kiểm của dlp_scan.py => FALSE POSITIVE thật sự.
    Đây là bằng chứng cho câu "FP làm bạn mệt" khi trình bày.
    """
    n = 0
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("# bao-cao-kho.csv — KHONG chua PII. Toan bo la ma noi bo.\n")
        fh.write("ma_don_hang,ma_lo,so_luong,ngay\n")
        for _ in range(120):
            don = rng.choice(MA_TINH) + str(rng.randint(0, 3)) + f"{rng.randrange(0, 10**8):08d}"
            lo = rng.choice(MA_TINH) + str(rng.randint(0, 3)) + f"{rng.randrange(0, 10**8):08d}"
            fh.write(f"{don},{lo},{rng.randint(1, 500)},2026-0{rng.randint(1,9)}-{rng.randint(10,28)}\n")
            n += 2
    return n


def main() -> None:
    ap = argparse.ArgumentParser(description="Sinh dữ liệu PII giả cho lab")
    ap.add_argument("--count", type=int, default=1000)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "out"))
    args = ap.parse_args()

    rng = random.Random(SEED)
    os.makedirs(args.out, exist_ok=True)
    rows = [sinh_ban_ghi(rng, i) for i in range(1, args.count + 1)]

    with open(os.path.join(args.out, "pii.json"), "w", encoding="utf-8") as fh:
        json.dump(rows, fh, ensure_ascii=False, indent=1)

    cols = ["ma_hoc_vien", "ho_ten", "gioi_tinh", "nam_sinh", "cccd",
            "so_dien_thoai", "email", "khoa", "the_ngan_hang", "dia_chi"]
    with open(os.path.join(args.out, "pii.csv"), "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)

    viet_sql(os.path.join(args.out, "hocvien-backup.sql"), rows)

    so_moi_fp = viet_moi_fp(os.path.join(args.out, "bao-cao-kho.csv"), rng)

    # Ground truth: đếm chính xác từng loại PII để chấm FP/FN của dlp_scan.py
    gt = {
        "_canh_bao": "DU LIEU GIA HOAN TOAN - SYNTHETIC ONLY",
        "seed": SEED,
        "so_ban_ghi": len(rows),
        "so_cccd": len(rows),
        "so_sdt": len(rows),
        "so_email": len(rows),
        "so_the_ngan_hang": len(rows),
        "cccd_duy_nhat": len({r["cccd"] for r in rows}),
        "sdt_duy_nhat": len({r["so_dien_thoai"] for r in rows}),
        "email_duy_nhat": len({r["email"] for r in rows}),
        "file_chua_pii": ["pii.json", "pii.csv", "hocvien-backup.sql"],
        "file_khong_chua_pii": ["bao-cao-kho.csv"],
        "so_chuoi_12_so_KHONG_phai_cccd": so_moi_fp,
        "ghi_chu_fp": ("bao-cao-kho.csv chua chuoi 12 so vuot qua duoc regex + hau kiem "
                       "cua dlp_scan.py => moi hit CCCD trong file nay la FALSE POSITIVE"),
    }
    with open(os.path.join(args.out, "ground-truth-pii.json"), "w", encoding="utf-8") as fh:
        json.dump(gt, fh, ensure_ascii=False, indent=2)

    print(f"Da sinh {len(rows)} ban ghi PII GIA vao {args.out}/")
    for name in ("pii.json", "pii.csv", "hocvien-backup.sql", "bao-cao-kho.csv",
                 "ground-truth-pii.json"):
        p = os.path.join(args.out, name)
        print(f"  {name:24s} {os.path.getsize(p):>9,} bytes")
    print(f"  CCCD duy nhat: {gt['cccd_duy_nhat']}/{len(rows)}  "
          f"SDT duy nhat: {gt['sdt_duy_nhat']}/{len(rows)}")


if __name__ == "__main__":
    main()
