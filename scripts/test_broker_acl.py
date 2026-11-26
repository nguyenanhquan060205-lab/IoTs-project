#!/usr/bin/env python3
"""
KIỂM TRA TÀI KHOẢN VÀ PHÂN QUYỀN (ACL) CỦA BROKER RIÊNG
Đăng nhập broker bằng từng tài khoản rồi thử việc được phép và việc bị cấm:
- Không có tài khoản hoặc sai mật khẩu thì bị từ chối.
- soil_station gửi telemetry tới App, soil_app gửi lệnh tới trạm.
- soil_app không gửi được số đo giả, soil_station không tự gửi lệnh được, không ai đọc được mọi topic bằng '#'.
- soil_web (nếu có mật khẩu) chỉ đọc được telemetry, không gửi được lệnh.

Broker và mật khẩu lấy từ firmware/src/secrets.h (soil_station) và mobile/mqtt_config.json (soil_app),
mật khẩu soil_web lấy từ biến môi trường MQTT_WEB_PASSWORD hoặc --web-password. Script không in mật khẩu.
TLS chỉ tin Root CA trong firmware/src/root_ca.h, giống ESP32.
Bản tin thử là chữ thường, không phải JSON, nên App, trạm và trang web đang chạy đều bỏ qua.

Chạy: python scripts/test_broker_acl.py
"""

import argparse
import json
import os
import re
import ssl
import sys
import time
import uuid
from pathlib import Path

# Windows in ra pipe/file bằng bảng mã cp1252, gặp tiếng Việt có dấu là lỗi UnicodeEncodeError
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("\n[!] Chưa cài thư viện paho-mqtt.")
    print("    Vui lòng chạy: pip3 install paho-mqtt\n")
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
TELEMETRY = "soil_station/1/telemetry"
COMMAND = "soil_station/1/command"
STATUS = "soil_station/1/status"
WAIT_SECONDS = 3


def read_station_config():
    path = ROOT / "firmware" / "src" / "secrets.h"
    if not path.exists():
        sys.exit(f"Chưa có {path}. Chép secrets.example.h thành secrets.h và điền mật khẩu soil_station.")
    text = path.read_text(encoding="utf-8")

    def macro(name):
        match = re.search(rf'#define\s+{name}\s+(?:"([^"]*)"|(\S+))', text)
        if not match:
            sys.exit(f"secrets.h thiếu {name}")
        return match.group(1) if match.group(1) is not None else match.group(2)

    return macro("MQTT_HOST"), int(macro("MQTT_PORT")), (macro("MQTT_USERNAME"), macro("MQTT_PASSWORD"))


def read_app_config():
    path = ROOT / "mobile" / "mqtt_config.json"
    if not path.exists():
        sys.exit(f"Chưa có {path}. Chép mqtt_config.example.json thành mqtt_config.json và điền mật khẩu soil_app.")
    cfg = json.loads(path.read_text(encoding="utf-8"))
    return cfg["MQTT_HOST"], (cfg["MQTT_USERNAME"], cfg["MQTT_PASSWORD"])


def firmware_tls_context():
    # Ghép lại chuỗi PEM từ các dòng "...\n" trong root_ca.h
    text = (ROOT / "firmware" / "src" / "root_ca.h").read_text(encoding="utf-8")
    pem = "\n".join(re.findall(r'"([^"]*)\\n"', text)) + "\n"
    context = ssl.create_default_context(cadata=pem)
    return context


class Session:
    """Một client MQTT đã đăng nhập (hoặc bị từ chối), ghi lại bản tin nhận được và kết quả SUBSCRIBE."""

    def __init__(self, host, port, creds, tag, tls_context, will=None):
        self.result = None
        self.messages = []
        self.subacks = {}
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,
                                  client_id=f"acl_test_{tag}_{uuid.uuid4().hex[:6]}")
        self.client.tls_set_context(tls_context)
        if creds:
            self.client.username_pw_set(*creds)
        if will:
            self.client.will_set(will[0], will[1], qos=1, retain=False)
        self.client.on_connect = lambda c, u, flags, rc, props: setattr(self, "result", rc)
        self.client.on_message = lambda c, u, m: self.messages.append((m.topic, m.payload.decode(errors="replace")))
        self.client.on_subscribe = lambda c, u, mid, rcs, props: self.subacks.update({mid: rcs[0]})
        try:
            self.client.connect(host, port, 30)
        except Exception as e:
            self.result = f"lỗi kết nối: {e}"
            return
        self.client.loop_start()
        deadline = time.time() + 10
        while self.result is None and time.time() < deadline:
            time.sleep(0.05)

    @property
    def connected(self):
        return self.result is not None and not isinstance(self.result, str) and not self.result.is_failure

    def subscribe(self, topic):
        _, mid = self.client.subscribe(topic, qos=1)
        deadline = time.time() + 5
        while mid not in self.subacks and time.time() < deadline:
            time.sleep(0.05)
        return self.subacks.get(mid)

    def publish(self, topic, text):
        self.client.publish(topic, text, qos=1)

    def received(self, topic, text):
        return any(t == topic and p == text for t, p in self.messages)

    def drop(self):
        # Đóng socket mà không gửi DISCONNECT, giống trạm bị rút điện: broker phải đăng LWT
        self.client.loop_stop()
        self.client.socket().close()

    def close(self):
        self.client.loop_stop()
        self.client.disconnect()


def main():
    parser = argparse.ArgumentParser(description="Kiểm tra tài khoản và ACL của broker riêng")
    parser.add_argument("--web-password", default=os.environ.get("MQTT_WEB_PASSWORD", ""),
                        help="Mật khẩu soil_web (hoặc biến môi trường MQTT_WEB_PASSWORD). Bỏ trống thì không thử soil_web")
    args = parser.parse_args()

    host, port, station_creds = read_station_config()
    app_host, app_creds = read_app_config()
    if app_host != host:
        sys.exit(f"secrets.h ({host}) và mqtt_config.json ({app_host}) đang trỏ tới 2 broker khác nhau")
    tls = firmware_tls_context()
    web_creds = ("soil_web", args.web_password) if args.web_password else None

    results = []

    def check(name, ok, detail=""):
        results.append(ok)
        print(f"[{'ĐẠT' if ok else 'KHÔNG ĐẠT'}] {name}{' - ' + detail if detail else ''}")

    def granted(rc):
        return rc is not None and not rc.is_failure

    def refused(rc):
        return rc is not None and rc.is_failure

    print(f"Broker: {host}:{port}, TLS chỉ tin Root CA trong firmware/src/root_ca.h\n")

    # 1. Đăng nhập
    for name, creds in [("Không có tài khoản", None), ("Đúng username soil_app, sai mật khẩu", (app_creds[0], app_creds[1] + "x"))]:
        s = Session(host, port, creds, "reject", tls)
        check(f"{name}: bị từ chối", not s.connected, f"broker trả: {s.result}")
        s.close()

    station = Session(host, port, station_creds, "station", tls)
    check(f"{station_creds[0]} đăng nhập qua TLS", station.connected, str(station.result))
    app = Session(host, port, app_creds, "app", tls)
    check(f"{app_creds[0]} đăng nhập qua TLS", app.connected, str(app.result))
    web = None
    if web_creds:
        web = Session(host, port, web_creds, "web", tls)
        check("soil_web đăng nhập qua TLS", web.connected, str(web.result))
    if not (station.connected and app.connected and (web is None or web.connected)):
        sys.exit("\nCó tài khoản không đăng nhập được nên dừng các bước sau. Kiểm tra lại mật khẩu trên EMQX.")

    # 2. Đăng ký nhận bản tin
    check("Trạm đăng ký nhận command", granted(rc := station.subscribe(COMMAND)), str(rc))
    check("App đăng ký nhận telemetry", granted(rc := app.subscribe(TELEMETRY)), str(rc))
    check("App đăng ký nhận status", granted(rc := app.subscribe(STATUS)), str(rc))
    check("Trạm KHÔNG đăng ký nhận telemetry được", refused(rc := station.subscribe(TELEMETRY)), str(rc))
    check("App KHÔNG đăng ký '#' (đọc mọi topic) được", refused(rc := app.subscribe("#")), str(rc))
    if web:
        check("Web đăng ký nhận telemetry", granted(rc := web.subscribe(TELEMETRY)), str(rc))
        check("Web đăng ký nhận status", granted(rc := web.subscribe(STATUS)), str(rc))
        check("Web KHÔNG đăng ký nhận command được", refused(rc := web.subscribe(COMMAND)), str(rc))
    time.sleep(0.5)

    # 3. Gửi bản tin: việc được phép và việc bị cấm
    marker = uuid.uuid4().hex[:8]
    msg = {name: f"ACL_TEST {name}-{marker}" for name in ("telemetry", "status", "command", "forged", "selfcmd", "webcmd")}
    station.publish(TELEMETRY, msg["telemetry"])
    station.publish(STATUS, msg["status"])
    app.publish(COMMAND, msg["command"])
    app.publish(TELEMETRY, msg["forged"])
    station.publish(COMMAND, msg["selfcmd"])
    if web:
        web.publish(COMMAND, msg["webcmd"])
    time.sleep(WAIT_SECONDS)

    check("App nhận được telemetry của trạm", app.received(TELEMETRY, msg["telemetry"]))
    check("App nhận được status của trạm", app.received(STATUS, msg["status"]))
    check("Trạm nhận được lệnh của App", station.received(COMMAND, msg["command"]))
    check("Số đo giả do soil_app gửi bị chặn", not app.received(TELEMETRY, msg["forged"]))
    check("Lệnh do soil_station tự gửi bị chặn", not station.received(COMMAND, msg["selfcmd"]))
    if web:
        check("Web nhận được telemetry của trạm", web.received(TELEMETRY, msg["telemetry"]))
        check("Web nhận được status của trạm", web.received(STATUS, msg["status"]))
        check("Lệnh do soil_web gửi bị chặn", not station.received(COMMAND, msg["webcmd"]))
    else:
        print("[BỎ QUA] Chưa có mật khẩu soil_web (MQTT_WEB_PASSWORD) nên không thử tài khoản web")

    # 4. LWT: trạm mất kết nối đột ngột thì broker đăng bản tin di chúc lên status thay trạm.
    # Thử không giữ lại (retain) để không đè lên bản tin online/offline thật của trạm
    will_text = f"ACL_TEST will-{marker}"
    dying = Session(host, port, station_creds, "will", tls, will=(STATUS, will_text))
    if dying.connected:
        dying.drop()
        deadline = time.time() + 10
        while not app.received(STATUS, will_text) and time.time() < deadline:
            time.sleep(0.1)
    check("Trạm mất kết nối đột ngột thì App nhận được LWT trên status", app.received(STATUS, will_text))

    for s in (station, app, web):
        if s:
            s.close()

    print(f"\n{sum(results)}/{len(results)} mục đạt")
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
