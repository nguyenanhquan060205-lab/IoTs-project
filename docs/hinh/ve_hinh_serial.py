"""Dựng Hình 4.1 (Serial Monitor khi ESP32 đồng bộ giờ) từ log thật của report_measure.py.

Chạy: python docs/hinh/ve_hinh_serial.py [log] [lần]
Mặc định lấy lần 4 trong docs/thuc-nghiem/log/khoi-dong-10-lan.txt (16,0 giây, gần trung vị của 10 lần).
Hình chỉ gồm các dòng ESP32 in ra (bỏ giờ máy tính mà script ghi kèm), từ dòng tiêu đề tới dòng [NTP].
Log đã che tên Wi-Fi và địa chỉ IP. Xuất PNG bằng Chrome chạy ẩn như ve_hinh.py, kích thước in ở cuối.
"""
import re
import sys
from html import escape
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parent.parent
LOG = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs" / "thuc-nghiem" / "log" / "khoi-dong-10-lan.txt"
RUN = sys.argv[2] if len(sys.argv) > 2 else "4"
PREFIX = re.compile(r"^\d{4}-\d{2}-\d{2} [\d:.]+ \[" + re.escape(RUN) + r"\] ?")


def lines_of_run():
    lines, started = [], False
    for raw in LOG.read_text(encoding="utf-8").splitlines():
        match = PREFIX.match(raw)
        if not match:
            continue
        text = raw[match.end():]
        if "=====" in text:
            started = True
        if started:
            lines.append(text)
        if text.startswith("[NTP]"):
            break
    return lines


def render(lines):
    rows = []
    for text in lines:
        cls = ""
        if text.startswith("[NTP]"):
            cls = "ntp"
        elif "Thanh cong!" in text:
            cls = "tls"
        rows.append(f'<div class="{cls}">{escape(text) or "&nbsp;"}</div>')
    body = "".join(rows)  # Mỗi dòng đã là một khối div, thêm "\n" trong <pre> sẽ giãn dòng gấp đôi
    return f"""<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><title>Hình 4.1: Serial Monitor khi ESP32 đồng bộ giờ</title>
<style>
html,body{{margin:0;background:#ffffff}}
.win{{margin:14px;border:1px solid #3c3c3c;border-radius:8px;overflow:hidden;width:1180px}}
.bar{{background:#2d2d2d;color:#cccccc;font:14px 'Segoe UI',Arial,sans-serif;padding:8px 14px}}
pre{{margin:0;background:#1e1e1e;color:#d4d4d4;font:14.5px/1.55 Consolas,'Cascadia Mono',monospace;padding:12px 14px;white-space:pre}}
.ntp{{background:#5a4a00;color:#ffe680;font-weight:bold}}
.tls{{background:#0f3d2a;color:#9de3bd}}
</style></head><body>
<div class="win"><div class="bar">Serial Monitor · COM7 · 115200 baud · trạm đo thật, khởi động lại lần {escape(RUN)}</div>
<pre>{body}</pre></div>
</body></html>
"""


if __name__ == "__main__":
    lines = lines_of_run()
    if not lines or not lines[-1].startswith("[NTP]"):
        raise SystemExit(f"Không tìm thấy đủ dòng của lần {RUN} trong {LOG}")
    (OUT / "hinh-4-1-serial-ntp.html").write_text(render(lines), encoding="utf-8")
    # Mỗi dòng cao 14,5 px × 1,55 = 22,5 px; cộng thanh tiêu đề, lề trong và lề ngoài khoảng 92 px
    print(f"hinh-4-1-serial-ntp.html 1210x{round(len(lines) * 22.5) + 92} ({len(lines)} dòng)")
