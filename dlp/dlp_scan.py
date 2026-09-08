#!/usr/bin/env python3
"""
dlp_scan.py — mini DLP scanner tự viết (content inspection + index matching).

Ánh xạ giáo trình Chapter 4:
  slide 45  DLP là gì
  slide 47  DLP hoạt động bằng CONTENT INSPECTION và INDEX MATCHING
            -> script này cài đặt CẢ HAI để cho thấy khác nhau ở đâu
  slide 48  Ba loại sensor:
              --fs      thư mục/file  ≈ STORAGE sensor  (data at rest)
              --mongo   datastore     ≈ STORAGE sensor  (data at rest)
              --proc    ps / /proc    ≈ AGENT   sensor  (data in use)
            (NETWORK sensor không nằm ở đây — đó là tcpdump/Zeek ở data-06)

Luận điểm để trình bày:
  - CONTENT INSPECTION (regex) tìm được dữ liệu CHƯA TỪNG THẤY, nhưng đẻ ra
    false positive: một số 12 chữ số bất kỳ trông y hệt CCCD.
  - INDEX MATCHING đối chiếu với danh sách giá trị ĐÃ BIẾT nên gần như không
    có FP, nhưng mù hoàn toàn với dữ liệu mới -> false negative.
  - "FP làm bạn mệt. FN làm bạn bị hack."

Dùng:
  python3 dlp_scan.py --fs /srv/shared /home --fs /var/www
  python3 dlp_scan.py --mongo mongodb://172.16.50.20:27017
  python3 dlp_scan.py --proc
  python3 dlp_scan.py --fs /srv/shared --index ../data/seed/out/pii.json \
                      --truth ../data/seed/out/ground-truth-pii.json --json report.json

Dữ liệu trong lab là DỮ LIỆU GIẢ. Không chạy script này lên hệ thống thật
của người khác.
"""
import argparse
import json
import os
import re
import sys
from collections import Counter, defaultdict

# ── CONTENT INSPECTION: bộ mẫu ────────────────────────────────────────────────
# Mỗi mẫu kèm một "bộ lọc xác nhận" (validator) để giảm false positive.
# Đây chính là chỗ sản phẩm DLP thương mại khác nhau: regex thì ai cũng viết
# được, phần khó là hậu kiểm.

PATTERNS = {
    # CCCD Việt Nam: đúng 12 chữ số, 3 số đầu là mã tỉnh hợp lệ, số thứ 4 là 0-3
    "cccd": re.compile(r"(?<!\d)\d{12}(?!\d)"),
    # Di động Việt Nam: 10 số bắt đầu bằng 0, hoặc dạng +84
    "sdt": re.compile(r"(?<!\d)(?:0|\+84)(?:3[2-9]|5[2689]|7[06-9]|8[1-9]|9[0-46-9])\d{7}(?!\d)"),
    "email": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    # Thẻ ngân hàng: 16 chữ số, có thể phân cách bằng space/gạch
    "the_ngan_hang": re.compile(r"(?<!\d)(?:\d{4}[ -]?){3}\d{4}(?!\d)"),
    # Secret lẫn trong cấu hình — chồng lấn với gitleaks, cố ý, để so kết quả
    "secret": re.compile(
        r"(?i)(?:password|passwd|secret|api[_-]?key|token|signing[_-]?key)"
        r"\s*[:=]\s*[\"']?([^\s\"',;]{8,})"
    ),
}

MA_TINH_HOP_LE = {
    "001", "002", "004", "006", "008", "010", "011", "012", "014", "015", "017",
    "019", "020", "022", "024", "025", "026", "027", "030", "031", "033", "034",
    "035", "036", "037", "038", "040", "042", "044", "045", "046", "048", "049",
    "051", "052", "054", "056", "058", "060", "062", "064", "066", "067", "068",
    "070", "072", "074", "075", "077", "079", "080", "082", "083", "084", "086",
    "087", "089", "091", "092", "093", "094", "095", "096",
}


def luhn_ok(so: str) -> bool:
    """Kiểm tra checksum Luhn — cách chuẩn để loại FP cho số thẻ."""
    ds = [int(c) for c in re.sub(r"\D", "", so)][::-1]
    tong = 0
    for i, d in enumerate(ds):
        if i % 2:
            d *= 2
            if d > 9:
                d -= 9
        tong += d
    return tong % 10 == 0


def xac_nhan(loai: str, gt: str) -> bool:
    """Hậu kiểm để giảm FP. Trả False -> coi là false positive, bỏ."""
    if loai == "cccd":
        return gt[:3] in MA_TINH_HOP_LE and gt[3] in "0123"
    if loai == "the_ngan_hang":
        return luhn_ok(gt)
    return True


def che(gt: str) -> str:
    """Che bớt khi in ra màn chiếu — báo cáo DLP không được tự làm lộ dữ liệu."""
    if len(gt) <= 6:
        return gt[0] + "*" * (len(gt) - 1)
    return gt[:3] + "*" * (len(gt) - 6) + gt[-3:]


class KetQua:
    def __init__(self):
        self.hits = defaultdict(list)      # loai -> [(nguon, gia_tri)]
        self.fp_bi_loai = Counter()        # loai -> so lan validator loai bo
        self.nguon_da_quet = 0
        self.byte_da_quet = 0

    def them(self, loai, nguon, gia_tri):
        self.hits[loai].append((nguon, gia_tri))


# ── STORAGE SENSOR (a): filesystem ───────────────────────────────────────────
BO_QUA_DUOI = {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".zip", ".gz", ".xz",
               ".so", ".bin", ".mp4", ".woff", ".woff2", ".ico", ".pyc"}
BO_QUA_THU_MUC = {".git", "node_modules", "__pycache__", "/proc", "/sys", "/dev"}
MAX_BYTES = 8 * 1024 * 1024  # bỏ qua file > 8MB cho demo chạy nhanh


def quet_filesystem(paths, kq: KetQua, verbose=False):
    for root_path in paths:
        for dirpath, dirnames, filenames in os.walk(root_path, onerror=lambda e: None):
            dirnames[:] = [d for d in dirnames if d not in BO_QUA_THU_MUC]
            for fn in filenames:
                p = os.path.join(dirpath, fn)
                if os.path.splitext(fn)[1].lower() in BO_QUA_DUOI:
                    continue
                try:
                    if os.path.getsize(p) > MAX_BYTES or os.path.islink(p):
                        continue
                    with open(p, "r", encoding="utf-8", errors="ignore") as fh:
                        noi_dung = fh.read()
                except (OSError, PermissionError):
                    continue
                kq.nguon_da_quet += 1
                kq.byte_da_quet += len(noi_dung)
                quet_van_ban(noi_dung, p, kq)
                if verbose:
                    print(f"  quet {p}", file=sys.stderr)


def quet_van_ban(noi_dung: str, nguon: str, kq: KetQua):
    for loai, rx in PATTERNS.items():
        for m in rx.finditer(noi_dung):
            gt = m.group(1) if rx.groups else m.group(0)
            gt_sach = re.sub(r"[ -]", "", gt) if loai == "the_ngan_hang" else gt
            if not xac_nhan(loai, gt_sach):
                kq.fp_bi_loai[loai] += 1
                continue
            kq.them(loai, nguon, gt_sach)


# ── STORAGE SENSOR (b): MongoDB ──────────────────────────────────────────────
def quet_mongo(uri: str, kq: KetQua):
    try:
        from pymongo import MongoClient
    except ImportError:
        print("!! Thieu pymongo:  pip install pymongo", file=sys.stderr)
        return
    cli = MongoClient(uri, serverSelectionTimeoutMS=4000)
    for db_name in cli.list_database_names():
        if db_name in ("admin", "config", "local"):
            continue
        db = cli[db_name]
        for coll in db.list_collection_names():
            n = 0
            for doc in db[coll].find({}, limit=5000):
                n += 1
                quet_van_ban(json.dumps(doc, default=str, ensure_ascii=False),
                             f"mongo://{db_name}.{coll}", kq)
            kq.nguon_da_quet += 1
            print(f"  mongo {db_name}.{coll}: {n} document", file=sys.stderr)


# ── AGENT SENSOR: data in use (ps + /proc/<pid>/environ) ─────────────────────
def quet_tien_trinh(kq: KetQua):
    """Chứng minh vì sao slide 48 cần AGENT sensor: dữ liệu đang nằm trong RAM
    và trên dòng lệnh thì network sensor lẫn storage sensor đều không thấy."""
    for pid in filter(str.isdigit, os.listdir("/proc")):
        for what in ("cmdline", "environ"):
            p = f"/proc/{pid}/{what}"
            try:
                with open(p, "rb") as fh:
                    raw = fh.read().replace(b"\0", b"\n").decode("utf-8", "ignore")
            except (OSError, PermissionError):
                continue
            kq.nguon_da_quet += 1
            quet_van_ban(raw, f"proc://{pid}/{what}", kq)


# ── INDEX MATCHING (slide 47, vế thứ hai) ────────────────────────────────────
def nap_index(path: str) -> set:
    """Nạp tập giá trị nhạy cảm ĐÃ BIẾT (mô phỏng index của DLP thương mại)."""
    with open(path, encoding="utf-8") as fh:
        rows = json.load(fh)
    idx = set()
    for r in rows:
        for k in ("cccd", "so_dien_thoai", "email", "the_ngan_hang"):
            if r.get(k):
                idx.add(str(r[k]))
    return idx


def in_bao_cao(kq: KetQua, index: set, truth: dict, che_du_lieu=True):
    print("\n" + "=" * 66)
    print("  BÁO CÁO MINI-DLP — content inspection + index matching")
    print("=" * 66)
    print(f"Nguồn đã quét : {kq.nguon_da_quet}")
    print(f"Dữ liệu đọc   : {kq.byte_da_quet/1024/1024:.2f} MB")

    print("\n-- CONTENT INSPECTION (regex + hậu kiểm) --")
    print(f"{'Loại PII':<18}{'Khớp':>8}{'Duy nhất':>10}{'FP loại bỏ':>13}")
    print("-" * 49)
    tong = 0
    for loai in PATTERNS:
        hits = kq.hits.get(loai, [])
        uniq = len({v for _, v in hits})
        tong += len(hits)
        print(f"{loai:<18}{len(hits):>8}{uniq:>10}{kq.fp_bi_loai[loai]:>13}")
    print("-" * 49)
    print(f"{'TỔNG':<18}{tong:>8}")

    if index:
        print("\n-- INDEX MATCHING (đối chiếu tập giá trị đã biết) --")
        tat_ca = {v for hits in kq.hits.values() for _, v in hits}
        trung = tat_ca & index
        moi = tat_ca - index
        print(f"Kích thước index      : {len(index)}")
        print(f"Khớp index (chắc chắn): {len(trung)}")
        print(f"Ngoài index (chưa rõ) : {len(moi)}  <- content inspection tìm ra,"
              " index matching thì KHÔNG")

    if truth:
        print("\n-- ĐỐI CHIẾU GROUND TRUTH (FP / FN) --")
        anh_xa = {"cccd": "so_cccd", "sdt": "so_sdt", "email": "so_email",
                  "the_ngan_hang": "so_the_ngan_hang"}
        # File mà ground truth khẳng định KHÔNG chứa PII -> mọi hit ở đó là FP
        file_sach = tuple(truth.get("file_khong_chua_pii", []))
        print(f"{'Loại':<18}{'Ground truth':>14}{'Tìm thấy (uniq)':>18}{'FN':>6}{'FP':>6}")
        print("-" * 62)
        for loai, key in anh_xa.items():
            gt_n = truth.get(key, 0)
            hits = kq.hits.get(loai, [])
            found = len({v for _, v in hits})
            fp = len({v for n, v in hits if file_sach and n.endswith(file_sach)})
            fn = max(gt_n - (found - fp), 0)
            print(f"{loai:<18}{gt_n:>14}{found:>18}{fn:>6}{fp:>6}")
        if file_sach:
            print(f"\nFP đến từ: {', '.join(file_sach)} — mã đơn hàng/mã lô 12 chữ số,")
            print("vượt qua cả regex lẫn hậu kiểm mã tỉnh. Đây là giới hạn cố hữu của")
            print("content inspection, và là lý do index matching tồn tại (slide 47).")

    print("\n-- MẪU BẰNG CHỨNG (đã che) --")
    for loai in PATTERNS:
        for nguon, v in kq.hits.get(loai, [])[:2]:
            hien = che(v) if che_du_lieu else v
            print(f"  [{loai}] {hien}   <- {nguon}")

    print("\n-- ÁNH XẠ BA LOẠI SENSOR (slide 48) --")
    print("  storage sensor (at rest) : --fs, --mongo   [script này]")
    print("  agent   sensor (in use)  : --proc          [script này]")
    print("  network sensor (in transit): tcpdump/Zeek  [data-06-capture.sh]")
    print("=" * 66 + "\n")


def main():
    ap = argparse.ArgumentParser(description="Mini DLP scanner cho lab An ninh mạng")
    ap.add_argument("--fs", nargs="+", action="extend", default=[],
                    metavar="DIR", help="thư mục cần quét (storage sensor)")
    ap.add_argument("--mongo", metavar="URI", help="URI MongoDB (storage sensor)")
    ap.add_argument("--proc", action="store_true",
                    help="quét ps/proc (agent sensor, data in use)")
    ap.add_argument("--index", metavar="PII_JSON",
                    help="file pii.json để làm index matching")
    ap.add_argument("--truth", metavar="GT_JSON",
                    help="ground-truth-pii.json để tính FN")
    ap.add_argument("--json", metavar="OUT", help="ghi báo cáo JSON ra file")
    ap.add_argument("--no-mask", action="store_true",
                    help="in nguyên giá trị (CHỈ dùng khi không chiếu màn hình)")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    if not (args.fs or args.mongo or args.proc):
        ap.error("cần ít nhất một trong --fs / --mongo / --proc")

    kq = KetQua()
    if args.fs:
        print("==> STORAGE SENSOR: filesystem", file=sys.stderr)
        quet_filesystem(args.fs, kq, args.verbose)
    if args.mongo:
        print("==> STORAGE SENSOR: MongoDB", file=sys.stderr)
        quet_mongo(args.mongo, kq)
    if args.proc:
        print("==> AGENT SENSOR: /proc (data in use)", file=sys.stderr)
        quet_tien_trinh(kq)

    index = nap_index(args.index) if args.index else set()
    truth = json.load(open(args.truth, encoding="utf-8")) if args.truth else {}
    in_bao_cao(kq, index, truth, che_du_lieu=not args.no_mask)

    if args.json:
        out = {
            "nguon_da_quet": kq.nguon_da_quet,
            "byte_da_quet": kq.byte_da_quet,
            "fp_bi_loai": dict(kq.fp_bi_loai),
            "ket_qua": {
                loai: [{"nguon": n, "gia_tri": che(v)} for n, v in hits]
                for loai, hits in kq.hits.items()
            },
        }
        with open(args.json, "w", encoding="utf-8") as fh:
            json.dump(out, fh, ensure_ascii=False, indent=2)
        print(f"Da ghi bao cao JSON: {args.json}")


if __name__ == "__main__":
    main()
