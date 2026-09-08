# Dockerfile "XẤU" CÓ CHỦ ĐÍCH — target của config scanning (slide 37, 43–44).
#
# Build:  docker build -t lab/bad-app:demo app/bad-image
# Quét :  trivy config app/bad-image      (misconfig từ chính Dockerfile)
#         trivy image  lab/bad-app:demo   (CVE trong OS package + thư viện)
#         syft lab/bad-app:demo -o spdx-json | grype sbom:-
#
# Mỗi lỗi dưới đây được đánh số để đối chiếu với ground-truth-app.md.
# ĐỪNG "sửa hộ" — đây là ground truth để tính False Negative.

# [BAD-01] Base image không pin digest, dùng tag :latest -> build không tái lập được
# [BAD-02] Chọn bản phát hành cũ để chắc chắn có CVE cho SCA tìm thấy
FROM python:3.9-slim-bullseye

# [BAD-03] Chạy toàn bộ build và runtime bằng root, không tạo user thường
USER root

# [BAD-04] Secret nhét thẳng vào ENV -> nằm vĩnh viễn trong image layer,
#          đọc được bằng `docker history` / `trivy image --scanners secret`
ENV DB_PASSWORD="P@ssw0rd-lab-2026" \
    AWS_SECRET_ACCESS_KEY="AKIAFAKELABKEYEXAMPLE0000" \
    APP_ENV=production

# [BAD-05] apt-get install không pin version, không xoá apt lists -> image phình
RUN apt-get update && apt-get install -y \
      curl \
      netcat \
      telnet \
      vim

# [BAD-06] Thư viện Python pin ở phiên bản có CVE đã biết.
#          Đây là luận điểm tầng SCA: CVE không nằm trong code mình viết.
#            - Flask 0.12.2      -> CVE-2018-1000656 (DoS)
#            - Jinja2 2.10       -> CVE-2019-10906 (sandbox escape)
#            - urllib3 1.24.1    -> CVE-2019-11324 (CRLF / cert verify)
#            - PyYAML 5.1        -> CVE-2020-1747  (arbitrary code exec)
#            - requests 2.19.1   -> CVE-2018-18074 (leak Authorization header)
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# [BAD-07] COPY cả thư mục, kéo theo file .env chứa credential vào image
COPY . /app
WORKDIR /app

# [BAD-08] Không có HEALTHCHECK -> orchestrator không biết container chết
# [BAD-09] Mở cổng đặc quyền, và vẫn đang là root khi chạy
EXPOSE 80

# [BAD-10] ENTRYPOINT dạng shell -> không nhận SIGTERM, PID 1 là /bin/sh
ENTRYPOINT python3 -m http.server 80
