#!/usr/bin/env python3
"""
ĐO SỐ LIỆU CHO BÁO CÁO TRÊN TRẠM THẬT
Đọc Serial và MQTT của trạm ESP32 để lấy số đo cho Chương 4 của báo cáo.
Mỗi lệnh ghi log thô kèm giờ máy tính vào tệp --out (đã che tên Wi-Fi và địa chỉ IP) và in bảng tóm tắt.

Cần paho-mqtt và pyserial, cài trong scripts/.venv:
    python -m venv scripts/.venv
    scripts\\.venv\\Scripts\\python -m pip install paho-mqtt pyserial

Ví dụ (chạy từ thư mục gốc dự án):
    scripts\\.venv\\Scripts\\python scripts\\report_measure.py boot --count 10 --out docs\\thuc-nghiem\\log\\khoi-dong-10-lan.txt
    scripts\\.venv\\Scripts\\python scripts\\report_measure.py offset --count 5
    scripts\\.venv\\Scripts\\python scripts\\report_measure.py soil-types
    scripts\\.venv\\Scripts\\python scripts\\report_measure.py calibrate --point dry
    scripts\\.venv\\Scripts\\python scripts\\report_measure.py offline --hold 60 --count 3
    scripts\\.venv\\Scripts\\python scripts\\report_measure.py serial-log --minutes 3

Trạm được đặt lại qua chân RTS của cổng Serial (nối vào EN). Giữ RTS ở mức tích cực thì ESP32 đứng yên
ở trạng thái reset: Wi-Fi tắt, broker không nhận gói DISCONNECT, về phía broker giống rút nguồn.
"""

import argparse
import json
import os
import queue
import random
import re
import socket
import statistics
import struct
import sys
import threading
import time
from datetime import datetime

# Windows in ra pipe/file bằng bảng mã cp1252, gặp emoji hoặc tiếng Việt có dấu là lỗi UnicodeEncodeError
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

BROKER = "broker.emqx.io"
MQTT_PORT = 8883
TELEMETRY_TOPIC = "soil_station/1/telemetry"
COMMAND_TOPIC = "soil_station/1/command"
STATUS_TOPIC = "soil_station/1/status"
SOIL_TYPES = ("potting", "garden", "barren")
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SECRETS = os.path.join(REPO_ROOT, "firmware", "src", "secrets.h")

# ---------------------------------------------------------------------------
# Hàm thuần: không cần pyserial hay paho-mqtt, kiểm thử trong test_report_measure.py
# ---------------------------------------------------------------------------

NTP_RE = re.compile(r"\[NTP\] Da co gio sau (\d+) ms")
MQTT_OK_RE = re.compile(r"Thanh cong! \((\d+) ms, heap trong (\d+) byte\)")
MQTT_FAIL_RE = re.compile(r"That bai sau (\d+) ms, rc=(-?\d+)")
IPV4_RE = re.compile(r"\b\d{1,3}(?:\.\d{1,3}){3}\b")
SSID_LINE_RE = re.compile(r"SSID: (.+?)\s*$")
SECRETS_SSID_RE = re.compile(r'#define\s+WIFI_SSID\s+"([^"]*)"')
NTP_EPOCH_OFFSET = 2208988800  # Số giây từ 1900-01-01 (gốc thời gian của NTP) tới 1970-01-01 (gốc Unix)


def parse_ntp_ms(line):
    """Số ms trong dòng `[NTP] Da co gio sau ... ms`, không phải dòng đó thì trả về None"""
    match = NTP_RE.search(line)
    return int(match.group(1)) if match else None


def parse_mqtt_result(line):
    """Kết quả một lần kết nối MQTT: {"ok", "ms", "heap"} khi thành công, {"ok", "ms", "rc"} khi thất bại"""
    match = MQTT_OK_RE.search(line)
    if match:
        return {"ok": True, "ms": int(match.group(1)), "heap": int(match.group(2))}
    match = MQTT_FAIL_RE.search(line)
    if match:
        return {"ok": False, "ms": int(match.group(1)), "rc": int(match.group(2))}
    return None


def describe(values):
    """Nhỏ nhất, trung vị, trung bình, lớn nhất của một dãy số; dãy rỗng thì trả về None"""
    values = [v for v in values if v is not None]
    if not values:
        return None
    return {
        "n": len(values),
        "min": min(values),
        "median": statistics.median(values),
        "mean": statistics.mean(values),
        "max": max(values),
    }


def format_stats(name, values, unit="", digits=0):
    stats = describe(values)
    if stats is None:
        return f"{name}: không có số đo"

    def fmt(x):
        return f"{x:.{digits}f}{unit}"

    return (f"{name}: n = {stats['n']}, nhỏ nhất {fmt(stats['min'])}, trung vị {fmt(stats['median'])}, "
            f"trung bình {fmt(stats['mean'])}, lớn nhất {fmt(stats['max'])}")


def build_sntp_request():
    """Gói SNTP 48 byte: LI = 0, phiên bản 4, chế độ 3 (client)"""
    return bytes([0x23]) + bytes(47)


def ntp_to_unix(seconds, fraction):
    return seconds - NTP_EPOCH_OFFSET + fraction / 2 ** 32


def clock_offset_from_sntp(packet, sent_at, received_at):
    """Độ lệch đồng hồ máy tính so với máy chủ NTP (giây, dương là máy tính chậm hơn) và độ trễ khứ hồi.

    sent_at, received_at: giờ máy tính (Unix) lúc gửi và lúc nhận gói.
    Công thức chuẩn của NTP: lệch = ((T2 - T1) + (T3 - T4)) / 2, trễ = (T4 - T1) - (T3 - T2).
    """
    if len(packet) < 48:
        raise ValueError("Gói SNTP ngắn hơn 48 byte")
    rx_sec, rx_frac, tx_sec, tx_frac = struct.unpack("!IIII", packet[32:48])
    server_rx = ntp_to_unix(rx_sec, rx_frac)
    server_tx = ntp_to_unix(tx_sec, tx_frac)
    offset = ((server_rx - sent_at) + (server_tx - received_at)) / 2
    delay = (received_at - sent_at) - (server_tx - server_rx)
    return offset, delay


def read_wifi_name(secrets_path):
    """Tên Wi-Fi trong secrets.h, chỉ dùng để che trong log. Không có tệp thì trả về None"""
    try:
        with open(secrets_path, encoding="utf-8", errors="replace") as f:
            match = SECRETS_SSID_RE.search(f.read())
    except OSError:
        return None
    return match.group(1) if match else None


class Masker:
    """Che tên Wi-Fi thành <wifi> và địa chỉ IPv4 thành <ip> trước khi ghi log vào repo công khai"""

    def __init__(self, names=()):
        self.names = {name for name in names if name}

    def mask(self, line):
        match = SSID_LINE_RE.search(line)
        if match:
            self.names.add(match.group(1))
        for name in sorted(self.names, key=len, reverse=True):
            line = line.replace(name, "<wifi>")
        return IPV4_RE.sub("<ip>", line)


# ---------------------------------------------------------------------------
# Serial, MQTT và tệp log
# ---------------------------------------------------------------------------

def now_text():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]


class Recorder:
    """Ghi từng dòng (đã che) kèm giờ máy tính vào tệp log và in ra màn hình"""

    def __init__(self, path, masker, echo=True):
        self.masker = masker
        self.echo = echo
        self.file = None
        if path:
            os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
            self.file = open(path, "w", encoding="utf-8", newline="\n")

    def _write(self, text):
        if self.file:
            self.file.write(text + "\n")
            self.file.flush()
        if self.echo:
            print(text)

    def line(self, text, tag=""):
        self._write(f"{now_text()} {tag}{self.masker.mask(text)}")

    def note(self, text):
        self._write(f"# {self.masker.mask(text)}")

    def close(self):
        if self.file:
            self.file.close()


def open_serial(port):
    import serial

    ser = serial.Serial()
    ser.port = port
    ser.baudrate = 115200
    ser.timeout = 0.2
    # Đặt trước khi mở cổng để lúc mở không làm trạm khởi động lại
    ser.dtr = False
    ser.rts = False
    ser.open()
    return ser


def reset_station(ser):
    ser.rts = True
    time.sleep(0.1)
    ser.rts = False


class LineReader:
    def __init__(self, ser):
        self.ser = ser
        self.buffer = b""

    def poll(self):
        """Các dòng đầy đủ đọc được trong khoảng 0,2 giây"""
        data = self.ser.read(self.ser.in_waiting or 1)
        if not data:
            return []
        self.buffer += data
        *lines, self.buffer = self.buffer.split(b"\n")
        return [raw.decode("utf-8", "replace").rstrip("\r") for raw in lines]


class Mqtt:
    """Client MQTT qua TLS: mọi bản tin nhận được đưa vào hàng đợi (giờ nhận, topic, payload)"""

    def __init__(self, broker, port, topics):
        import paho.mqtt.client as mqtt

        self.messages = queue.Queue()
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2,
                                  client_id=f"report_measure_{random.randint(1000, 9999)}")
        self.client.tls_set()  # Xác thực chứng chỉ broker bằng kho CA của hệ điều hành
        connected = threading.Event()

        def on_connect(client, userdata, flags, reason_code, properties=None):
            for topic in topics:
                client.subscribe(topic, qos=1)
            connected.set()

        def on_message(client, userdata, msg):
            self.messages.put((time.time(), msg.topic, msg.payload))

        self.client.on_connect = on_connect
        self.client.on_message = on_message
        self.client.connect(broker, port, 30)
        self.client.loop_start()
        if not connected.wait(20):
            raise SystemExit(f"Không kết nối được {broker}:{port}")

    def publish(self, topic, payload):
        self.client.publish(topic, json.dumps(payload), qos=1).wait_for_publish(10)

    def get(self, timeout):
        try:
            return self.messages.get(timeout=max(timeout, 0.01))
        except queue.Empty:
            return None

    def drain(self):
        while not self.messages.empty():
            self.messages.get_nowait()

    def wait_for(self, predicate, timeout):
        """Bản tin đầu tiên thỏa predicate(topic, data) trong thời gian chờ: (giờ nhận, topic, data, payload)"""
        deadline = time.time() + timeout
        while time.time() < deadline:
            item = self.get(deadline - time.time())
            if item is None:
                break
            received_at, topic, payload = item
            try:
                data = json.loads(payload)
            except ValueError:
                continue
            if predicate(topic, data):
                return received_at, topic, data, payload
        return None

    def close(self):
        self.client.loop_stop()
        self.client.disconnect()


def sntp_offset(server):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(3)
        sent_at = time.time()
        sock.sendto(build_sntp_request(), (server, 123))
        packet, _ = sock.recvfrom(512)
        received_at = time.time()
    return clock_offset_from_sntp(packet, sent_at, received_at)


# ---------------------------------------------------------------------------
# Các lệnh đo
# ---------------------------------------------------------------------------

def cmd_boot(args, rec):
    """Khởi động lại trạm N lần, lấy thời gian có giờ NTP, thời gian kết nối MQTT và bộ nhớ trống"""
    ser = open_serial(args.port)
    reader = LineReader(ser)
    ntp_ms, connect_ms, heaps, failures = [], [], [], []
    try:
        for run in range(1, args.count + 1):
            rec.note(f"Lần {run}/{args.count}: đặt lại trạm qua chân EN")
            reset_station(ser)
            started = time.time()
            got_ntp = got_mqtt = None
            while time.time() - started < args.timeout:
                for line in reader.poll():
                    rec.line(line, f"[{run}] ")
                    value = parse_ntp_ms(line)
                    if value is not None and got_ntp is None:
                        got_ntp = value
                    result = parse_mqtt_result(line)
                    if result and result["ok"] and got_mqtt is None:
                        got_mqtt = result
                    elif result and not result["ok"]:
                        failures.append(result)
                if got_ntp is not None and (got_mqtt is not None or not args.need_mqtt):
                    break
            if got_ntp is None:
                rec.note(f"Lần {run}: không thấy dòng [NTP] sau {args.timeout} giây")
            if got_mqtt is None and args.need_mqtt:
                rec.note(f"Lần {run}: không kết nối được MQTT sau {args.timeout} giây")
            ntp_ms.append(got_ntp)
            if got_mqtt:
                connect_ms.append(got_mqtt["ms"])
                heaps.append(got_mqtt["heap"])
            rec.note(f"Lần {run}: NTP {got_ntp} ms, MQTT {got_mqtt['ms'] if got_mqtt else None} ms, "
                     f"heap {got_mqtt['heap'] if got_mqtt else None} byte")
    finally:
        ser.close()
    rec.note("Tóm tắt")
    rec.note(format_stats("Thời gian có giờ NTP kể từ khi có Wi-Fi", ntp_ms, " ms"))
    rec.note(format_stats("Thời gian kết nối MQTT (gồm bắt tay TLS nếu có)", connect_ms, " ms"))
    rec.note(format_stats("Bộ nhớ trống sau khi kết nối", heaps, " byte"))
    rec.note(f"Số lần kết nối thất bại: {len(failures)}"
             + (f", rc = {sorted({f['rc'] for f in failures})}" if failures else ""))


def cmd_offset(args, rec):
    """Độ lệch timestamp của trạm so với giờ máy tính (đã bù độ lệch máy tính so với NTP) và kích thước bản tin"""
    offset, delay = sntp_offset(args.ntp_server)
    rec.note(f"Đồng hồ máy tính lệch {offset * 1000:+.0f} ms so với {args.ntp_server} "
             f"(trễ khứ hồi {delay * 1000:.0f} ms), các số dưới đây đã bù độ lệch này")
    mq = Mqtt(args.broker, args.mqtt_port, [TELEMETRY_TOPIC])
    diffs, sizes = [], []
    try:
        for run in range(1, args.count + 1):
            mq.drain()
            found = mq.wait_for(lambda topic, data: "timestamp" in data, 30)
            if found is None:
                rec.note(f"Lần {run}: không nhận được bản tin có timestamp trong 30 giây")
                continue
            received_at, _, data, payload = found
            diff = received_at + offset - data["timestamp"]
            diffs.append(diff)
            sizes.append(len(payload))
            rec.line(f"[{run}] timestamp {data['timestamp']} | nhận lúc {received_at + offset:.3f} (đã bù) | "
                     f"lệch {diff:+.3f} s | {len(payload)} byte")
            if run < args.count:
                time.sleep(args.interval)
    finally:
        mq.close()
    offset_end, _ = sntp_offset(args.ntp_server)
    rec.note(f"Đo lại lúc kết thúc: đồng hồ máy tính lệch {offset_end * 1000:+.0f} ms")
    rec.note("Tóm tắt")
    rec.note(format_stats("Giờ nhận trừ timestamp của trạm", diffs, " s", 3))
    rec.note("timestamp chỉ chính xác tới giây (trạm cắt phần lẻ), nên số trên gồm phần lẻ bị cắt (0 - 1 s) "
             "cộng độ trễ mạng")
    rec.note(format_stats("Kích thước bản tin telemetry", sizes, " byte"))


def summarize_telemetry(items):
    """Trung bình các chỉ số của vài bản tin cùng loại đất"""
    def mean_of(get):
        return statistics.mean(get(d) for d in items)

    last = items[-1]
    return {
        "soil_type": last.get("soil_type"),
        "n": len(items),
        "adc_raw": mean_of(lambda d: d["adc"]["raw"]),
        "moisture": mean_of(lambda d: d["telemetry"]["moisture"]),
        "ec": mean_of(lambda d: d["telemetry"]["ec"]),
        "nitrogen": mean_of(lambda d: d["telemetry"]["nitrogen"]),
        "phosphorus": mean_of(lambda d: d["telemetry"]["phosphorus"]),
        "potassium": mean_of(lambda d: d["telemetry"]["potassium"]),
        "ph": mean_of(lambda d: d["telemetry"]["ph"]),
        "npk_normal": last.get("npk_normal"),
        "npk_level": last.get("npk_level"),
    }


def cmd_soil_types(args, rec):
    """Đổi lần lượt 3 loại đất với cùng một đầu dò, ghi bản tin của từng loại rồi trả lại loại đất ban đầu"""
    mq = Mqtt(args.broker, args.mqtt_port, [TELEMETRY_TOPIC])
    results = []
    try:
        first = mq.wait_for(lambda topic, data: "telemetry" in data, 30)
        if first is None:
            raise SystemExit("Không nhận được bản tin telemetry nào trong 30 giây")
        initial = first[2].get("soil_type", "garden")
        rec.note(f"Loại đất ban đầu: {initial}")
        for soil in SOIL_TYPES:
            mq.drain()
            sent_at = time.time()
            mq.publish(COMMAND_TOPIC, {"action": "SET_SOIL_TYPE", "soil_type": soil})
            rec.note(f"Đã gửi SET_SOIL_TYPE {soil}")
            items = []
            while len(items) < args.samples:
                found = mq.wait_for(lambda topic, data: data.get("soil_type") == soil and "telemetry" in data, 60)
                if found is None:
                    raise SystemExit(f"Trạm không gửi bản tin loại đất {soil} trong 60 giây")
                received_at, _, data, payload = found
                if not items:
                    rec.note(f"Bản tin xác nhận đầu tiên sau {received_at - sent_at:.1f} giây")
                rec.line(payload.decode("utf-8", "replace"), f"[{soil}] ")
                items.append(data)
            results.append(summarize_telemetry(items))
        mq.drain()
        mq.publish(COMMAND_TOPIC, {"action": "SET_SOIL_TYPE", "soil_type": initial})
        back = mq.wait_for(lambda topic, data: data.get("soil_type") == initial, 60)
        rec.note(f"Đã trả lại loại đất {initial}" + ("" if back else " (chưa thấy bản tin xác nhận)"))
    finally:
        mq.close()
    rec.note("Tóm tắt (trung bình mỗi loại đất)")
    rec.note("Loại đất | n | ADC | Độ ẩm % | EC | N | P | K | pH | Mức chuẩn N/P/K | Mức N/P/K")
    for r in results:
        normal = r["npk_normal"] or {}
        level = r["npk_level"] or {}
        rec.note(f"{r['soil_type']} | {r['n']} | {r['adc_raw']:.0f} | {r['moisture']:.1f} | {r['ec']:.0f} | "
                 f"{r['nitrogen']:.1f} | {r['phosphorus']:.1f} | {r['potassium']:.1f} | {r['ph']:.2f} | "
                 f"{normal.get('nitrogen')}/{normal.get('phosphorus')}/{normal.get('potassium')} | "
                 f"{level.get('nitrogen')}/{level.get('phosphorus')}/{level.get('potassium')}")


def cmd_calibrate(args, rec):
    """Gửi lệnh CALIBRATE, ghi dòng Serial xác nhận và khối adc của bản tin gửi ngay sau đó"""
    ser = open_serial(args.port)
    reader = LineReader(ser)
    mq = Mqtt(args.broker, args.mqtt_port, [TELEMETRY_TOPIC])
    try:
        mq.drain()
        mq.publish(COMMAND_TOPIC, {"action": "CALIBRATE", "point": args.point})
        rec.note(f"Đã gửi CALIBRATE {args.point}")
        confirmed_at, outcome = None, None
        deadline = time.time() + 20
        while time.time() < deadline and outcome is None:
            for line in reader.poll():
                rec.line(line)
                if "DA LUU MOC" in line or "Bo qua" in line or "khong hop le" in line:
                    confirmed_at, outcome = time.time(), line.strip()
        if outcome is None:
            rec.note("Không thấy dòng xác nhận trên Serial trong 20 giây")
            return
        found = mq.wait_for(lambda topic, data: "adc" in data, 15)
        while found and found[0] < confirmed_at:
            found = mq.wait_for(lambda topic, data: "adc" in data, 15)
        if found:
            rec.line(found[3].decode("utf-8", "replace"), "[ban tin] ")
            adc = found[2]["adc"]
            rec.note(f"Kết quả: {outcome} | adc.raw {adc['raw']}, adc.noise {adc['noise']}, "
                     f"mốc khô {adc['dry']}, mốc ướt {adc['wet']}")
        else:
            rec.note(f"Kết quả: {outcome} | không nhận được bản tin sau đó")
    finally:
        mq.close()
        ser.close()


def cmd_offline(args, rec):
    """Giữ trạm ở trạng thái reset (giống mất nguồn), đo thời gian tới khi broker đăng offline rồi online lại"""
    ser = open_serial(args.port)
    mq = Mqtt(args.broker, args.mqtt_port, [STATUS_TOPIC, TELEMETRY_TOPIC])
    to_offline, to_online, to_telemetry = [], [], []
    try:
        for run in range(1, args.count + 1):
            if mq.wait_for(lambda topic, data: topic == TELEMETRY_TOPIC, 60) is None:
                rec.note(f"Lần {run}: trạm chưa gửi telemetry, bỏ qua")
                continue
            mq.drain()
            held_at = time.time()
            ser.rts = True
            rec.note(f"Lần {run}: giữ chân EN ở mức thấp (trạm dừng như mất nguồn)")
            found = mq.wait_for(lambda topic, data: topic == STATUS_TOPIC and data.get("status") == "offline",
                                args.hold + 60)
            if found:
                to_offline.append(found[0] - held_at)
                rec.line(f"[{run}] status offline sau {found[0] - held_at:.1f} s")
            else:
                rec.note(f"Lần {run}: không thấy status offline")
            remaining = args.hold - (time.time() - held_at)
            if remaining > 0:
                time.sleep(remaining)
            mq.drain()
            released_at = time.time()
            ser.rts = False
            rec.note(f"Lần {run}: nhả chân EN sau {released_at - held_at:.0f} s")
            online = mq.wait_for(lambda topic, data: topic == STATUS_TOPIC and data.get("status") == "online", 120)
            if online:
                to_online.append(online[0] - released_at)
                rec.line(f"[{run}] status online sau {online[0] - released_at:.1f} s")
            telemetry = mq.wait_for(lambda topic, data: topic == TELEMETRY_TOPIC, 120)
            if telemetry:
                to_telemetry.append(telemetry[0] - released_at)
                rec.line(f"[{run}] bản tin telemetry đầu tiên sau {telemetry[0] - released_at:.1f} s")
            if run < args.count:
                time.sleep(args.gap)
    finally:
        ser.rts = False
        ser.close()
        mq.close()
    rec.note("Tóm tắt")
    rec.note(format_stats("Từ lúc trạm dừng tới status offline", to_offline, " s", 1))
    rec.note(format_stats("Từ lúc cấp lại tới status online", to_online, " s", 1))
    rec.note(format_stats("Từ lúc cấp lại tới bản tin telemetry đầu tiên", to_telemetry, " s", 1))


def cmd_serial_log(args, rec):
    """Chép Serial kèm giờ máy tính, dùng khi tắt router hoặc khi chạy bản nạp tạm"""
    ser = open_serial(args.port)
    reader = LineReader(ser)
    ntp, results = [], []
    try:
        if args.reset:
            rec.note("Đặt lại trạm qua chân EN")
            reset_station(ser)
        deadline = time.time() + args.minutes * 60
        while time.time() < deadline:
            for line in reader.poll():
                rec.line(line)
                ntp.append(parse_ntp_ms(line))
                result = parse_mqtt_result(line)
                if result:
                    results.append(result)
    finally:
        ser.close()
    ok = [r for r in results if r["ok"]]
    failed = [r for r in results if not r["ok"]]
    rec.note("Tóm tắt")
    rec.note(format_stats("Thời gian có giờ NTP", ntp, " ms"))
    rec.note(f"Kết nối MQTT thành công {len(ok)} lần, thất bại {len(failed)} lần"
             + (f" (rc = {sorted({r['rc'] for r in failed})})" if failed else ""))
    if ok:
        rec.note(format_stats("Thời gian kết nối MQTT thành công", [r["ms"] for r in ok], " ms"))
    if failed:
        rec.note(format_stats("Thời gian tới khi thất bại", [r["ms"] for r in failed], " ms"))


def main():
    parser = argparse.ArgumentParser(description="Đo số liệu cho báo cáo trên trạm ESP32 thật")
    parser.add_argument("--port", default="COM7", help="Cổng Serial của ESP32 (mặc định COM7)")
    parser.add_argument("--broker", default=BROKER)
    parser.add_argument("--mqtt-port", type=int, default=MQTT_PORT)
    parser.add_argument("--out", help="Tệp log (thường đặt trong docs/thuc-nghiem/log/)")
    parser.add_argument("--secrets", default=DEFAULT_SECRETS, help="secrets.h, chỉ đọc tên Wi-Fi để che trong log")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("boot", help="Khởi động lại trạm N lần")
    p.add_argument("--count", type=int, default=10)
    p.add_argument("--timeout", type=float, default=60, help="Giây chờ mỗi lần")
    p.add_argument("--no-mqtt", dest="need_mqtt", action="store_false",
                   help="Không chờ kết nối MQTT (dùng cho bản nạp không kết nối được)")
    p.set_defaults(func=cmd_boot)

    p = sub.add_parser("offset", help="Độ lệch timestamp và kích thước bản tin")
    p.add_argument("--count", type=int, default=5)
    p.add_argument("--interval", type=float, default=60, help="Giây giữa 2 lần đo")
    p.add_argument("--ntp-server", default="time.google.com")
    p.set_defaults(func=cmd_offset)

    p = sub.add_parser("soil-types", help="Đổi lần lượt 3 loại đất")
    p.add_argument("--samples", type=int, default=3, help="Số bản tin ghi cho mỗi loại đất")
    p.set_defaults(func=cmd_soil_types)

    p = sub.add_parser("calibrate", help="Lưu mốc khô hoặc ướt")
    p.add_argument("--point", choices=["dry", "wet"], required=True)
    p.set_defaults(func=cmd_calibrate)

    p = sub.add_parser("offline", help="Giữ trạm ở trạng thái reset, đo thời gian offline / online")
    p.add_argument("--hold", type=float, default=60, help="Giây giữ trạm dừng")
    p.add_argument("--count", type=int, default=3)
    p.add_argument("--gap", type=float, default=40, help="Giây nghỉ giữa 2 lần")
    p.set_defaults(func=cmd_offline)

    p = sub.add_parser("serial-log", help="Chép Serial trong N phút")
    p.add_argument("--minutes", type=float, default=3)
    p.add_argument("--reset", action="store_true", help="Đặt lại trạm lúc bắt đầu")
    p.set_defaults(func=cmd_serial_log)

    args = parser.parse_args()
    rec = Recorder(args.out, Masker([read_wifi_name(args.secrets)]))
    rec.note(f"{now_text()} | lệnh: {args.command} | cổng {args.port} | broker {args.broker}:{args.mqtt_port}")
    try:
        args.func(args, rec)
    finally:
        rec.close()


if __name__ == "__main__":
    main()
