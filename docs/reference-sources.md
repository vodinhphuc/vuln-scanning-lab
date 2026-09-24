# Nguồn dữ liệu phục vụ rà quét (để chiếu cho lớp)

Rà quét không tự "biết" lỗ hổng — nó **tải tri thức từ các bên khác**. Đây là những
nguồn đó, kèm vai trò và công cụ nào trong lab dùng chúng.

## A. Định danh & chấm điểm lỗ hổng (CVE ecosystem)
| Nguồn | Cung cấp gì | URL |
|---|---|---|
| CVE Program (MITRE) | **Định danh** toàn cầu cho mỗi lỗ hổng (CVE-YYYY-NNNN) | https://www.cve.org |
| NVD (NIST) | Chi tiết + điểm CVSS cho từng CVE; DB mà Trivy/Grype tải về | https://nvd.nist.gov |
| CVSS (FIRST) | Thang điểm 0–10 đo **mức nghiêm trọng kỹ thuật** | https://www.first.org/cvss/ |
| EPSS (FIRST) | **Xác suất bị khai thác** trong 30 ngày tới | https://www.first.org/epss/ |
| CISA KEV | Danh sách lỗ hổng **đã bị khai thác thực tế** | https://www.cisa.gov/known-exploited-vulnerabilities-catalog |

> Câu chốt: "CVSS nói nguy hiểm cỡ nào · EPSS nói khả năng bị dùng · KEV nói đã có người dùng rồi."

## B. Chuẩn cấu hình (config / baseline scanning)
| Nguồn | Cung cấp gì | Tool lab dùng | URL |
|---|---|---|---|
| CIS Benchmarks | Checklist hardening chuẩn (Ubuntu, Docker, Nginx…) | OpenSCAP, baseline | https://www.cisecurity.org/cis-benchmarks |
| SCAP (NIST) | Định dạng chuẩn để máy đọc checklist | OpenSCAP | https://csrc.nist.gov/projects/security-content-automation-protocol |
| ComplianceAsCode / SCAP Security Guide | File **datastream** `ssg-ubuntu2204-ds.xml` (đóng gói CIS) | OpenSCAP | https://github.com/ComplianceAsCode/content |
| OpenSCAP | Công cụ chạy & chấm điểm SCAP | oscap | https://www.open-scap.org |
| OVAL | Ngôn ngữ mô tả "cách máy đọc kiểm từng rule" (nằm trong datastream) | OpenSCAP | https://oval.mitre.org/repository/ *(archive; nay CIS bảo trì)* |

> "CIS Benchmark là đề bài, OpenSCAP là người chấm, SCAP là ngôn ngữ chung."

## C. Feed cho network scanner (GVM / OpenVAS)
| Nguồn | Cung cấp gì | URL |
|---|---|---|
| Greenbone Community Feed | Hàng chục nghìn script **NVT/NASL**, mỗi script gắn CVE | https://github.com/greenbone/greenbone-feed-sync · rsync: `feed.community.greenbone.net` |
| Greenbone | Nhà phát hành GVM (nhánh mở tách từ Nessus 2005) | https://www.greenbone.net |

## D. CVE cho dependency & image (SCA — Trivy / Grype / Syft)
| Nguồn | Cung cấp gì | URL |
|---|---|---|
| OSV | CSDL lỗ hổng mã nguồn mở (theo package) | https://osv.dev |
| GitHub Advisory Database | Advisory cho thư viện npm/PyPI/… | https://github.com/advisories |
| Ubuntu Security Notices (USN) | Advisory theo gói của Ubuntu | https://ubuntu.com/security/notices |
| Trivy DB | Tổng hợp NVD + advisory distro/OSV | https://github.com/aquasecurity/trivy-db |
| Grype (Anchore) | Scanner + DB đối chiếu SBOM ↔ CVE | https://github.com/anchore/grype |

## E. Anti-malware & file test
| Nguồn | Cung cấp gì | URL |
|---|---|---|
| ClamAV | Engine + signature database | https://www.clamav.net |
| EICAR | Chuỗi test chuẩn (KHÔNG phải virus thật) | https://www.eicar.org/download-anti-malware-testfile/ |

## F. Dữ liệu công cụ nhận diện
| Nguồn | Cung cấp gì | URL |
|---|---|---|
| Nmap — service/version detection & NSE | Thư viện fingerprint `nmap-service-probes` + script NSE (Lua) | https://nmap.org/book/vscan.html · https://nmap.org/nsedoc/ |
| testssl.sh | Kiểm TLS version/cipher/chứng thư | https://testssl.sh |

## G. Phương pháp & pháp lý
| Nguồn | Cung cấp gì | URL |
|---|---|---|
| NIST SP 800-115 | Quy trình chuẩn kiểm thử/đánh giá an ninh | https://csrc.nist.gov/pubs/sp/800/115/final |
| OWASP Top 10 | Phân loại lỗ hổng ứng dụng web | https://owasp.org/www-project-top-ten/ |
| Nghị định 13/2023/NĐ-CP | Nghĩa vụ bảo vệ dữ liệu cá nhân (VN) — tầng Data | tra công báo Chính phủ (chinhphu.vn) |

---

*URL kiểm ở thời điểm chuẩn bị; nếu chiếu live nên bấm thử trước. Dữ liệu PII trong
lab là bịa hoàn toàn.*
