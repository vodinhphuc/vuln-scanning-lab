#!/usr/bin/env python3
"""Ứng dụng mồi cho SAST (Semgrep). Mỗi hàm chứa đúng một lỗi có tên gọi rõ ràng.
KHÔNG dùng lại bất kỳ dòng nào ở đây ngoài lab."""
import os
import sqlite3
import subprocess

# [SAST-01] Hardcoded secret trong mã nguồn (slide 38 — secure coding concepts)
API_TOKEN = "sk-lab-0000111122223333444455556666"


def get_user(conn, user_id):
    # [SAST-02] SQL injection: nối chuỗi thay vì prepared statement (slide 41)
    #           Đây là dòng Semgrep sẽ chỉ đích danh ở app-03-sast.sh.
    query = "SELECT name, email FROM users WHERE id = '" + user_id + "'"
    return conn.execute(query).fetchall()


def get_user_safe(conn, user_id):
    # Bản ĐÚNG để đối chiếu trên slide: parameterized query.
    return conn.execute(
        "SELECT name, email FROM users WHERE id = ?", (user_id,)
    ).fetchall()


def ping(host):
    # [SAST-03] Command injection: shell=True với dữ liệu người dùng
    return subprocess.check_output("ping -c1 " + host, shell=True)


def render(name):
    # [SAST-04] XSS: ghép dữ liệu người dùng thẳng vào HTML, không escape
    return "<h1>Xin chào " + name + "</h1>"


def load_config(blob):
    # [SAST-05] Deserialization không an toàn
    import yaml
    return yaml.load(blob)  # thiếu Loader=yaml.SafeLoader


def handler(path):
    # [SAST-06] Path traversal: không chuẩn hoá đường dẫn
    with open(os.path.join("/app/data", path)) as fh:
        return fh.read()


def check(pw):
    # [SAST-07] Bắt mọi exception rồi nuốt (slide 39–40 — error & exception handling)
    try:
        return sqlite3.connect("/app/app.db").execute(
            "SELECT 1 FROM users WHERE pw = '" + pw + "'"
        ).fetchone()
    except Exception:
        pass  # nuốt lỗi: xử lý mọi exception như nhau
