#!/bin/bash
# scan-06-fuzz.sh — Content/param fuzzing tầng App (GT-A02: autoindex /backup/, đường dẫn ẩn).
#   ffuf duyệt đường dẫn trên nginx, làm nổi /backup/ đang bật autoindex (lộ file backup).
#   bash scan-06-fuzz.sh
set -uo pipefail
cd "$(dirname "$0")" || exit 1; source ./_lib.sh

hd "scan-06  Directory fuzzing — nginx ($URL_NGINX)"
have ffuf || { warn "thiếu ffuf"; exit 1; }

# chọn wordlist SecLists nếu có, không thì fallback nhỏ
WL=""
for c in /usr/share/seclists/Discovery/Web-Content/common.txt \
         /usr/share/wordlists/seclists/Discovery/Web-Content/common.txt \
         /usr/share/wordlists/dirb/common.txt; do
  [[ -f "$c" ]] && { WL="$c"; break; }
done
if [[ -z "$WL" ]]; then
  WL="$(mktemp)"; printf '%s\n' backup admin login setup.php config .git .env uploads phpinfo.php robots.txt > "$WL"
  warn "không thấy SecLists — dùng wordlist tối giản"
fi
info "wordlist: $WL"

OUT="$EVID/app-06-ffuf-$TS.json"
ffuf -u "$URL_NGINX/FUZZ" -w "$WL" -mc 200,301,302,403 -o "$OUT" -of json 2>/dev/null | sed 's/^/    /'
ok "evidence: $OUT"

info "Kiểm /backup/ có autoindex (GT-A02) — liệt kê file lộ:"
curl -s "$URL_NGINX/backup/" 2>/dev/null | grep -oE 'href="[^"]+"' | head | sed 's/^/    /' \
  && ok "nếu thấy danh sách file .sql/.csv -> autoindex đang bật (lộ dữ liệu)" \
  || info "    (/backup/ trống hoặc chưa seed data tier)"
