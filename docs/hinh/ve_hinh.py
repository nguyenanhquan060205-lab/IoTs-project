"""Vẽ 5 hình sơ đồ cho báo cáo giai đoạn 2 (Hình 3.1, 3.2, 3.3, 3.4, 3.6) dưới dạng HTML + SVG.

Chạy: python docs/hinh/ve_hinh.py
Sinh ra các tệp hinh-3-*.html cạnh tệp này. Xuất PNG bằng Chrome hoặc Edge chạy ẩn, ví dụ:
  chrome --headless=new --hide-scrollbars --force-device-scale-factor=2 \
         --window-size=<rộng>,<cao> --screenshot=hinh-3-1-kien-truc.png hinh-3-1-kien-truc.html
Kích thước từng hình in ở cuối khi chạy. Nội dung lấy theo firmware/src/main.cpp, soil_estimator.h,
mobile/lib/services/agronomic_engine.dart, web/evaluation.html và HARDWARE_CHECKLIST.md (Hình 3.2).
"""
from html import escape
from pathlib import Path

OUT = Path(__file__).resolve().parent
FONT = "'Segoe UI', Arial, sans-serif"
INK = "#222222"
MUTED = "#555555"


class Svg:
    def __init__(self, width, height):
        self.w, self.h = width, height
        self.parts = []

    def add(self, s):
        self.parts.append(s)

    def text(self, x, y, s, size=17, weight="normal", anchor="start", color=INK, halo=False):
        extra = ' stroke="#ffffff" stroke-width="5" paint-order="stroke"' if halo else ""
        self.add(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" '
                 f'fill="{color}"{extra}>{escape(s)}</text>')

    def box(self, x, y, w, h, title=None, lines=(), fill="#ffffff", stroke=INK, rx=8, align="left",
            size=16, title_size=17, dash=None):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" '
                 f'stroke-width="1.6"{d}/>')
        rows = ([(title, title_size, "bold")] if title else []) + [(l, size, "normal") for l in lines]
        line_h = [s + 7 for _, s, _ in rows]
        total = sum(line_h) - 7
        cy = y + (h - total) / 2
        for (s, sz, wt), lh in zip(rows, line_h):
            cy += sz - 3
            if align == "center":
                self.text(x + w / 2, cy, s, sz, wt, "middle")
            else:
                self.text(x + 14, cy, s, sz, wt)
            cy += lh - sz + 3

    def diamond(self, cx, cy, w, h, lines, fill="#fffbea"):
        pts = f"{cx},{cy - h / 2} {cx + w / 2},{cy} {cx},{cy + h / 2} {cx - w / 2},{cy}"
        self.add(f'<polygon points="{pts}" fill="{fill}" stroke="{INK}" stroke-width="1.6"/>')
        start = cy - (len(lines) - 1) * 10 + 5
        for i, s in enumerate(lines):
            self.text(cx, start + i * 20, s, 16, "normal", "middle")

    def path(self, points, label=None, label_at=None, anchor="start", dashed=False, head=True):
        d = "M " + " L ".join(f"{x},{y}" for x, y in points)
        dash = ' stroke-dasharray="7 5"' if dashed else ""
        marker = ' marker-end="url(#arrow)"' if head else ""
        self.add(f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="1.6"{dash}{marker}/>')
        if label:
            lx, ly = label_at
            self.text(lx, ly, label, 15, "normal", anchor, MUTED, halo=True)

    def html(self, title):
        body = "\n".join(self.parts)
        return f"""<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><title>{escape(title)}</title>
<style>html,body{{margin:0;background:#ffffff}} svg{{display:block}}</style></head>
<body>
<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" viewBox="0 0 {self.w} {self.h}"
     font-family="{FONT}" role="img" aria-label="{escape(title)}">
<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="9" markerHeight="9" orient="auto-start-reverse">
<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker></defs>
<rect width="100%" height="100%" fill="#ffffff"/>
{body}
</svg>
</body></html>
"""


def hinh_3_1():
    s = Svg(1000, 950)
    bands = [(10, "TẦNG ỨNG DỤNG", 250), (300, "TẦNG TRUYỀN THÔNG", 210), (550, "TẦNG THIẾT BỊ ĐO", 390)]
    for y, label, h in bands:
        s.add(f'<rect x="10" y="{y}" width="980" height="{h}" rx="10" fill="#f4f4f1" stroke="#c9c9c4" stroke-width="1.2"/>')
        s.text(26, y + 26, label, 15, "bold", color=MUTED)

    s.box(40, 50, 440, 190, "Ứng dụng Flutter (điện thoại)", [
        "Tổng quan · Chỉ số · Mẫu đất · Lịch sử · Hiệu chuẩn",
        "Hệ chuyên gia: điểm sức khỏe đất, khuyến nghị",
        "Lịch sử SQLite: 1 bản ghi/phút, giữ 30 ngày",
        "MQTT qua TLS cổng 8883, gửi lệnh QoS 1",
    ], fill="#eaf6f1")
    s.box(520, 50, 440, 190, "Trang web đánh giá sai số (trình duyệt)", [
        "MAE, RMSE, MAPE theo từng chỉ số",
        "Đo nhiễu bộ lọc, trạng thái online / offline",
        "WebSocket có TLS cổng 8084",
        "Chỉ nhận bản tin, không gửi lệnh",
    ], fill="#eaf6f1")

    s.box(40, 340, 640, 150, "Broker MQTT broker.emqx.io", [
        "soil_station/1/telemetry: trạm → app, web (4 giây/lần)",
        "soil_station/1/command: app → trạm (SET_SOIL_TYPE, CALIBRATE)",
        "soil_station/1/status: online, LWT offline (giữ lại)",
    ], fill="#fdf1e8")
    s.box(720, 340, 240, 150, "Máy chủ NTP", ["pool.ntp.org", "time.google.com", "UDP cổng 123"], fill="#fdf1e8")

    s.box(40, 600, 230, 120, "Cảm biến độ ẩm", ["module LM393", "nguồn 3,3 V", "AO → GPIO34 (ADC1)"])
    s.box(320, 590, 360, 330, "ESP32 (firmware)", [
        "1. Đọc 21 mẫu ADC, lọc cắt tỉa",
        "2. ADC → độ ẩm theo mốc khô / ướt",
        "3. Độ ẩm → EC theo loại đất",
        "4. EC → N, P, K; độ ẩm → pH",
        "5. So N, P, K với mức chuẩn ±20%",
        "6. JSON có timestamp → MQTT",
        "TLS kiểm tra Root CA",
    ], fill="#eaf1fb")
    for i, (title, line) in enumerate([
        ("OLED SSD1306", "I2C: GPIO21 / GPIO22"),
        ("LED đỏ / vàng / xanh", "GPIO32 / GPIO19 / GPIO33"),
        ("Còi", "GPIO25, phát bằng PWM"),
        ("Bộ nhớ NVS", "loại đất, mốc khô / ướt"),
    ]):
        y = 590 + i * 84
        s.box(720, y, 240, 72, title, [line], size=15, title_size=16)
        s.path([(680, y + 36), (718, y + 36)])

    s.path([(270, 660), (318, 660)])
    s.path([(420, 590), (420, 492)], "telemetry, status", (412, 540), "end")
    s.path([(580, 492), (580, 588)], "command", (590, 540))
    s.path([(840, 492), (840, 560), (660, 560), (660, 588)], "giờ thực (SNTP)", (850, 535))
    s.path([(240, 340), (240, 242)], "telemetry", (232, 292), "end")
    s.path([(400, 242), (400, 338)], "command (QoS 1)", (410, 292))
    s.path([(600, 340), (600, 242)], "telemetry, status", (610, 292))
    return s, "Hình 3.1: Sơ đồ kiến trúc 3 tầng của hệ thống giai đoạn 2"


def hinh_3_3():
    s = Svg(1100, 1230)
    s.text(210, 24, "setup(): chạy một lần", 16, "bold", "middle", MUTED)
    s.text(640, 24, "loop(): lặp liên tục", 16, "bold", "middle", MUTED)

    setup = [
        ("Cấp nguồn, chạy setup()", 56, True),
        ("Khởi tạo Serial, chân LED, còi PWM", 60, False),
        ("Đọc NVS: loại đất, mốc khô / ướt", 60, False),
        ("Khởi động OLED|(không thấy thì bỏ qua)", 70, False),
        ("Kết nối WiFi (WiFiMulti)|thử tối đa 2 lần, khoảng 25 giây", 70, False),
        ("configTzTime(\"ICT-7\", pool.ntp.org,|time.google.com): SNTP chạy nền,|tự đồng bộ lại mỗi giờ", 94, False),
        ("Nạp Root CA, chờ bắt tay TLS 10 giây,|bộ đệm MQTT 768 byte", 70, False),
        ("Sang loop()", 56, True),
    ]
    y = 40
    prev = None
    for label, h, terminal in setup:
        if prev is not None:
            s.path([(210, prev), (210, y - 2)])
        s.box(30, y, 360, h, None, label.split("|"), fill="#eaf1fb" if terminal else "#ffffff",
              rx=28 if terminal else 6, align="center")
        prev = y + h
        y += h + 26
    # "Sang loop()" nhập vào đường quay về đầu vòng lặp (x = 430) thay vì vắt qua tiêu đề
    end_y = prev - 28
    s.path([(390, end_y), (428, end_y)])

    # Vòng lặp
    s.box(450, 40, 380, 56, None, ["Đầu vòng loop()"], fill="#eaf1fb", rx=28, align="center")
    s.path([(640, 96), (640, 118)])
    s.diamond(640, 168, 260, 96, ["Có WiFi?"])
    s.path([(770, 168), (858, 168)], "Không", (790, 160))
    s.box(860, 134, 220, 68, None, ["Cứ 15 giây", "dò lại WiFi 1 lần"], align="center", size=15)
    s.path([(1080, 168), (1090, 168), (1090, 520), (762, 520)])
    s.path([(640, 216), (640, 246)], "Có", (650, 236))
    s.diamond(640, 296, 260, 96, ["Đã nối broker?"])
    s.path([(770, 296), (858, 296)], "Không", (790, 288))
    s.box(860, 252, 220, 92, None, ["Cứ 5 giây: connect", "TLS cổng 8883,", "kèm LWT offline"], align="center", size=15)
    s.path([(970, 344), (970, 364)])
    s.box(860, 366, 220, 72, None, ["Đăng ký command,", "gửi online (giữ lại)"], align="center", size=15)
    s.path([(860, 402), (832, 402)])
    s.path([(640, 344), (640, 370)], "Có", (650, 362))
    s.box(450, 372, 380, 60, None, ["mqtt.loop(); cứ 30 giây gửi lại online"], align="center", size=15)
    s.path([(640, 432), (640, 470)])
    s.diamond(640, 520, 260, 96, ["Đủ 4 giây?"])
    s.path([(510, 520), (430, 520), (430, 68), (448, 68)], "Không", (500, 510), "end")
    s.path([(640, 568), (640, 598)], "Có", (650, 590))

    steps = [
        ("Đọc 21 mẫu ADC (3 ms/mẫu),|lọc cắt tỉa: bỏ 5 thấp nhất, 5 cao nhất", 70),
        ("Độ ẩm → EC → N, P, K, pH theo loại đất,|so N, P, K với mức chuẩn", 70),
        ("Bật đèn, cập nhật OLED, in Serial", 56),
    ]
    y = 600
    for label, h in steps:
        s.box(450, y, 380, h, None, label.split("|"), align="center", size=15)
        s.path([(640, y + h), (640, y + h + 24)])
        y += h + 26
    s.diamond(640, y + 46, 260, 96, ["Đang nối broker?"])
    s.path([(640, y + 94), (640, y + 120)], "Có", (650, y + 112))
    s.box(450, y + 122, 380, 70, None, ["Gửi telemetry, thêm timestamp", "nếu đã có giờ NTP"], align="center", size=15)
    s.path([(770, y + 46), (870, y + 46), (870, y + 240), (832, y + 240)], "Không", (790, y + 38))
    s.path([(640, y + 192), (640, y + 210)])
    s.box(450, y + 212, 380, 60, None, ["Còi 3 tiếng nếu độ ẩm vừa ra", "ngoài khoảng 35 – 80%"], align="center", size=15)
    s.path([(640, y + 272), (640, y + 300), (430, y + 300), (430, 520)], head=False)
    return s, "Hình 3.3: Lưu đồ khởi động và vòng lặp của firmware"


def hinh_3_4():
    s = Svg(1100, 830)
    actors = [("Người dùng", 110), ("Ứng dụng Flutter", 340), ("Broker MQTT", 570), ("ESP32", 800), ("NVS", 1000)]
    for name, x in actors:
        s.box(x - 90, 20, 180, 52, None, [name], fill="#eaf1fb", align="center", size=16)
        s.add(f'<line x1="{x}" y1="72" x2="{x}" y2="765" stroke="#888888" stroke-width="1.2" stroke-dasharray="6 5"/>')
    X = dict(actors)

    def msg(a, b, y, label, dashed=False):
        s.path([(X[a], y), (X[b] + (-4 if X[b] > X[a] else 4), y)], dashed=dashed)
        s.text((X[a] + X[b]) / 2, y - 8, label, 15, "normal", "middle", INK, halo=True)

    def note(actor, y, lines, w=230):
        h = 22 * len(lines) + 14
        s.box(X[actor] - w / 2, y, w, h, None, lines, fill="#fffbea", align="center", size=15, rx=4)

    msg("Người dùng", "Ứng dụng Flutter", 120, "Chọn loại đất")
    note("Ứng dụng Flutter", 140, ["Hiện “Đang gửi tới trạm...”"])
    msg("Ứng dụng Flutter", "Broker MQTT", 215, "command SET_SOIL_TYPE (QoS 1)")
    msg("Broker MQTT", "ESP32", 265, "command")
    note("ESP32", 285, ["parseSoilType():", "mã có hợp lệ?"], w=200)

    s.add('<rect x="250" y="355" width="830" height="390" fill="none" stroke="#888888" stroke-width="1.2"/>')
    s.add('<rect x="250" y="355" width="60" height="26" fill="#eeeeee" stroke="#888888" stroke-width="1.2"/>')
    s.text(280, 373, "alt", 14, "bold", "middle")
    s.text(320, 373, "[hợp lệ: potting / garden / barren]", 14, "normal", "start", MUTED, halo=True)
    msg("ESP32", "NVS", 415, "lưu loại đất")
    note("ESP32", 435, ["Gửi bản tin ngay,", "không chờ hết 4 giây"], w=210)
    msg("ESP32", "Broker MQTT", 525, "telemetry có soil_type mới")
    msg("Broker MQTT", "Ứng dụng Flutter", 570, "telemetry")
    note("Ứng dụng Flutter", 588, ["soil_type khớp:", "hiện “Trạm đã nhận”"])
    s.add('<line x1="250" y1="660" x2="1080" y2="660" stroke="#888888" stroke-width="1.2" stroke-dasharray="6 5"/>')
    s.text(260, 680, "[mã không hợp lệ]", 14, "normal", "start", MUTED, halo=True)
    note("ESP32", 690, ["Giữ loại đất cũ, in Serial"], w=240)

    s.text(40, 805, "Nếu ứng dụng đang mất kết nối lúc chọn, lệnh được gửi lại ngay khi ứng dụng nối lại broker.",
           15, "normal", "start", MUTED)
    return s, "Hình 3.4: Sơ đồ tuần tự khi người dùng đổi loại đất trên ứng dụng"


def hinh_3_6():
    s = Svg(1100, 640)
    s.box(20, 250, 180, 110, "Bản tin", ["telemetry", "N, P, K, pH,", "EC, độ ẩm"], fill="#eaf1fb", align="center")
    s.path([(200, 305), (238, 305)])
    s.box(240, 20, 420, 600)
    s.text(254, 52, "1. Đối chiếu ngưỡng chuẩn", 17, "bold")
    s.text(646, 52, "điểm trừ", 15, "normal", "end", MUTED)
    rules = [
        ("pH < 5,5: đất chua phèn", "−25"),
        ("pH > 7,5: đất kiềm", "−15"),
        ("EC < 300 µS/cm: nghèo dinh dưỡng", "−25"),
        ("EC > 2000 µS/cm: mặn, dư phân", "−35"),
        ("N < 50 mg/kg: thiếu đạm", "−15"),
        ("N > 150 mg/kg: dư đạm", "−10"),
        ("P < 30 mg/kg: thiếu lân", "−15"),
        ("K < 80 mg/kg: thiếu kali", "−15"),
        ("Độ ẩm < 50%: khô hạn", "−15"),
        ("Độ ẩm > 80%: ngập úng", "−15"),
    ]
    for i, (rule, points) in enumerate(rules):
        y = 100 + i * 46
        s.text(254, y, rule, 16)
        s.text(646, y, points, 16, "bold", "end")
        s.add(f'<line x1="254" y1="{y + 16}" x2="646" y2="{y + 16}" stroke="#dddddd" stroke-width="1"/>')
    s.text(254, 590, "Một bộ ngưỡng chung cho mọi loại đất", 15, "normal", "start", MUTED)
    s.path([(660, 320), (698, 320)])
    s.box(700, 220, 180, 200, "2. Điểm", ["100 − tổng", "điểm trừ,", "giới hạn", "0 – 100"], fill="#fdf1e8", align="center")
    s.path([(880, 320), (918, 320)])
    s.box(920, 110, 160, 420, "3. Kết luận", [
        "≥ 80: tốt",
        "50 – 79:",
        "trung bình",
        "< 50: kém",
        "",
        "Danh sách",
        "vấn đề và",
        "phân bón cần",
        "bổ sung",
    ], fill="#eaf6f1", align="center")
    return s, "Hình 3.6: Quy trình vận hành của hệ chuyên gia trên ứng dụng"


def hinh_3_2():
    """Sơ đồ nối chân theo PIN_* trong firmware/src/main.cpp và HARDWARE_CHECKLIST.md (không còn rơ-le)"""
    s = Svg(1150, 620)
    s.box(400, 30, 300, 540, fill="#eaf1fb")
    s.text(550, 62, "ESP32 DevKit", 18, "bold", "middle")
    s.text(550, 86, "ESP32-WROOM-32, nguồn USB 5 V", 15, "normal", "middle", MUTED)

    # Cảm biến độ ẩm bên trái, nối thẳng vào 3V3, GND và GPIO34
    s.box(60, 100, 240, 150, "Cảm biến độ ẩm", ["module LM393"], fill="#ffffff")
    for y, pin_sensor, pin_esp in [(140, "VCC", "3V3"), (180, "GND", "GND"), (220, "AO", "GPIO34 (ADC1)")]:
        s.text(290, y + 5, pin_sensor, 15, "bold", "end")
        s.path([(300, y), (400, y)], head=False)
        s.text(412, y + 5, pin_esp, 15, "bold")
    s.box(60, 300, 300, 130, None, [
        "VCC chỉ nối 3V3, không nối 5V",
        "(chân ADC chịu tối đa 3,3 V).",
        "GPIO34 thuộc ADC1 nên vẫn đọc",
        "được khi Wi-Fi đang bật.",
    ], fill="#fffbea", dash="6 4", size=15)

    # OLED: SDA, SCL nối GPIO21, GPIO22; nguồn ghi bằng nhãn để hình đỡ rối
    s.text(830, 50, "OLED SSD1306 (I2C, địa chỉ 0x3C)", 16, "bold")
    s.box(830, 70, 270, 120, fill="#ffffff")
    for y, pin_oled, pin_esp, power in [(110, "SDA", "GPIO21", "VCC → 3V3"), (150, "SCL", "GPIO22", "GND → GND")]:
        s.text(688, y + 5, pin_esp, 15, "bold", "end")
        s.path([(700, y), (830, y)], head=False)
        s.text(842, y + 5, pin_oled, 15, "bold")
        s.text(1088, y + 5, power, 15, "normal", "end", MUTED)

    # 3 LED qua điện trở 220 Ω, còi; cực âm nối GND
    for y, label, pin, fill in [(260, "LED đỏ", "GPIO32", "#fde8e8"), (330, "LED vàng", "GPIO19", "#fff6d6"),
                                (400, "LED xanh", "GPIO33", "#e6f4ea")]:
        s.text(688, y + 5, pin, 15, "bold", "end")
        s.path([(700, y), (760, y)], head=False)
        s.box(760, y - 17, 80, 34, None, ["220 Ω"], align="center", size=14, rx=4)
        s.path([(840, y), (880, y)], head=False)
        s.box(880, y - 20, 120, 40, None, [label], fill=fill, align="center", size=15)
        s.path([(1000, y), (1040, y)], head=False)
        s.text(1046, y + 5, "GND", 15, "bold")
    s.text(688, 495, "GPIO25", 15, "bold", "end")
    s.path([(700, 490), (880, 490)], head=False)
    s.text(790, 482, "PWM 2,7 kHz", 14, "normal", "middle", MUTED)
    s.box(880, 470, 120, 40, None, ["Còi (+)"], fill="#f4f4f1", align="center", size=15)
    s.path([(1000, 490), (1040, 490)], head=False)
    s.text(1046, 495, "GND", 15, "bold")
    s.text(575, 603, "Mọi cực âm và chân GND của linh kiện nối chung GND của ESP32", 14, "normal", "middle", MUTED)
    return s, "Hình 3.2: Sơ đồ đấu nối mạch trạm đo (cảm biến LM393, OLED, LED cảnh báo)"


if __name__ == "__main__":
    for name, build in [("hinh-3-1-kien-truc", hinh_3_1), ("hinh-3-2-so-do-noi-chan", hinh_3_2),
                        ("hinh-3-3-luu-do-khoi-dong", hinh_3_3),
                        ("hinh-3-4-tuan-tu-doi-loai-dat", hinh_3_4), ("hinh-3-6-he-chuyen-gia", hinh_3_6)]:
        svg, title = build()
        (OUT / f"{name}.html").write_text(svg.html(title), encoding="utf-8")
        print(f"{name}.html {svg.w}x{svg.h}")
