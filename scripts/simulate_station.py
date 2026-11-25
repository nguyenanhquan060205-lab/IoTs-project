#!/usr/bin/env python3
"""
SIMULATE SOIL STATION (ESP32 MOCK)
Script giả lập vi điều khiển ESP32 và cảm biến nước/độ ẩm gửi telemetry lên MQTT Broker.
Dùng để kiểm thử kết nối với App Flutter mà không cần cắm phần cứng vật lý.
N, P, K, EC, pH là số ước lượng từ độ ẩm theo loại đất, giống firmware.
"""

import json
import os
import random
import time
import sys

# Windows in ra pipe/file bằng bảng mã cp1252, gặp emoji hoặc tiếng Việt có dấu là lỗi UnicodeEncodeError
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("\n[!] Chưa cài thư viện paho-mqtt.")
    print("    Vui lòng chạy: pip3 install paho-mqtt\n")
    sys.exit(1)

# Cấu hình MQTT (Khớp với Mobile App): mặc định broker công cộng qua TLS cổng 8883
BROKER = "broker.emqx.io"
PORT = 8883
TELEMETRY_TOPIC = "soil_station/1/telemetry"
COMMAND_TOPIC = "soil_station/1/command"
STATUS_TOPIC = "soil_station/1/status"
CLIENT_ID = f"mock_esp32_station_{random.randint(1000, 9999)}"

# Hệ số theo loại đất (khớp với SoilEstimator::profile trong firmware).
# nitrogen / phosphorus / potassium là mức N, P, K bình thường của loại đất, chỉ để so sánh và thông báo
SOIL_PROFILES = {
    "potting": {"label": "Đất dinh dưỡng đóng bao", "ec_per_moisture": 20.0, "ph_base": 6.2,
                "nitrogen": 95.0, "phosphorus": 50.0, "potassium": 135.0},
    "garden": {"label": "Đất vườn", "ec_per_moisture": 13.5, "ph_base": 6.5,
               "nitrogen": 65.0, "phosphorus": 33.0, "potassium": 90.0},
    "barren": {"label": "Đất bạc màu / bãi đất trống", "ec_per_moisture": 4.0, "ph_base": 5.8,
               "nitrogen": 20.0, "phosphorus": 10.0, "potassium": 30.0},
}
# N, P, K dễ tiêu (mg/kg) trên mỗi 1 µS/cm EC, chung cho mọi loại đất (khớp N_PER_EC / P_PER_EC / K_PER_EC).
# Ở độ ẩm lý tưởng 60%, mỗi loại đất cho đúng mức N, P, K bình thường của nó
N_PER_EC = 0.08
P_PER_EC = 0.04
K_PER_EC = 0.11
# Lệch quá 20% so với mức bình thường của loại đất thì báo thấp / cao (khớp NORMAL_TOLERANCE)
NORMAL_TOLERANCE = 0.20
soil_type = "garden"  # Loại đất đang đo, App đổi qua lệnh SET_SOIL_TYPE

# Đầu dò độ ẩm ảo: ADC khi khô hẳn / ngâm nước, dùng để sinh tín hiệu thô theo độ ẩm
PROBE_DRY_ADC = 200
PROBE_WET_ADC = 3000
MIN_CALIBRATION_GAP = 300
# Mốc hiệu chuẩn đang lưu trên trạm, App đổi qua lệnh CALIBRATE
adc_dry = PROBE_DRY_ADC
adc_wet = PROBE_WET_ADC
# Mốc đã được đo thật hay vẫn là số mặc định (giống dryCalibrated / wetCalibrated của firmware)
dry_calibrated = False
wet_calibrated = False

# Giá trị mô phỏng nền (Base values)
current_moisture = 55.0  # %

def calculate_nutrients_from_moisture(moisture, soil_type="garden"):
    """
    Thuật toán ước lượng dinh dưỡng đất (Heuristic Soil Nutrition Estimation)
    EC tăng theo độ ẩm, N, P, K dễ tiêu tính từ EC (nên đổi theo độ ẩm),
    pH dao động quanh pH gốc của loại đất
    """
    profile = SOIL_PROFILES[soil_type]

    # EC (µS/cm): Nước hòa tan muối khoáng có sẵn nên EC tăng theo độ ẩm
    ec = (moisture * profile["ec_per_moisture"]) + random.uniform(-15, 15)
    ec = max(150.0, min(2200.0, ec))

    # Đạm, Lân, Kali dễ tiêu (mg/kg): dinh dưỡng hòa tan trong nước của đất, cũng là thứ làm EC tăng
    n = max(10.0, ec * N_PER_EC)
    p = max(5.0, ec * P_PER_EC)
    k = max(15.0, ec * K_PER_EC)

    # pH: Dao động quanh pH gốc của loại đất, khô quá thì kiềm nhẹ, ẩm quá thì hơi chua
    ph = profile["ph_base"] - ((moisture - 50.0) * 0.012) + random.uniform(-0.1, 0.1)
    ph = max(4.5, min(8.5, round(ph, 1)))

    return round(n, 1), round(p, 1), round(k, 1), ph, round(ec, 1)

def compare_to_normal(value, normal):
    """'low' nếu thấp hơn 80% mức bình thường, 'high' nếu cao hơn 120%, còn lại 'normal' (khớp compareToNormal)"""
    if value < normal * (1.0 - NORMAL_TOLERANCE):
        return "low"
    if value > normal * (1.0 + NORMAL_TOLERANCE):
        return "high"
    return "normal"

def npk_levels(n, p, k, soil_type):
    """N, P, K so với mức bình thường của loại đất"""
    profile = SOIL_PROFILES[soil_type]
    return {
        "nitrogen": compare_to_normal(n, profile["nitrogen"]),
        "phosphorus": compare_to_normal(p, profile["phosphorus"]),
        "potassium": compare_to_normal(k, profile["potassium"]),
    }

def simulate_adc(moisture):
    """Tín hiệu ADC thô của đầu dò ảo (đã lọc) và mức nhiễu tương ứng"""
    raw = PROBE_DRY_ADC + moisture / 100.0 * (PROBE_WET_ADC - PROBE_DRY_ADC) + random.uniform(-8, 8)
    return int(round(raw)), round(random.uniform(3, 8), 1)

def build_payload(moisture, soil_type):
    """Bản tin telemetry cùng cấu trúc với firmware"""
    n, p, k, ph, ec = calculate_nutrients_from_moisture(moisture, soil_type)
    raw, noise = simulate_adc(moisture)
    profile = SOIL_PROFILES[soil_type]
    return {
        "device_id": "esp32_soil_station_01",
        "timestamp": int(time.time()),
        "soil_type": soil_type,
        "telemetry": {
            "nitrogen": n,
            "phosphorus": p,
            "potassium": k,
            "ph": ph,
            "ec": ec,
            "moisture": round(moisture, 1)
        },
        "npk_normal": {
            "nitrogen": profile["nitrogen"],
            "phosphorus": profile["phosphorus"],
            "potassium": profile["potassium"]
        },
        "npk_level": npk_levels(n, p, k, soil_type),
        "adc": {"raw": raw, "noise": noise, "dry": adc_dry, "wet": adc_wet}
    }

def on_connect(client, userdata, flags, rc, properties=None):
    # Support both v1 integer code and v2 ReasonCode
    is_success = (rc == 0 or getattr(rc, "is_failure", False) is False)
    if is_success:
        print(f"\n✅ [MQTT] Đã kết nối thành công tới Broker")
        print(f"📡 Lắng nghe lệnh từ App Mobile tại: {COMMAND_TOPIC}")
        print(f"📤 Bắn dữ liệu cảm biến định kỳ tại: {TELEMETRY_TOPIC}")
        print("-" * 60)
        client.subscribe(COMMAND_TOPIC)
        # Báo Online
        client.publish(STATUS_TOPIC, json.dumps({"status": "online", "device": CLIENT_ID}), qos=1)
    else:
        print(f"❌ [MQTT] Kết nối thất bại với mã lỗi: {rc}")

def on_message(client, userdata, msg):
    global soil_type, adc_dry, adc_wet, dry_calibrated, wet_calibrated
    try:
        payload = json.loads(msg.payload.decode())
        action = payload.get("action", "")

        print(f"\n📩 [LỆNH TỪ APP MOBILE] Topic: {msg.topic}")

        if action == "SET_SOIL_TYPE":
            new_type = payload.get("soil_type")
            if new_type in SOIL_PROFILES:
                soil_type = new_type
                print(f"   🪴 [LOẠI ĐẤT ĐANG ĐO] Đã chuyển sang: {SOIL_PROFILES[soil_type]['label']}")
            else:
                print(f"   ❌ Mã loại đất không hợp lệ: {new_type}, giữ nguyên loại đất cũ")
            return

        if action == "CALIBRATE":
            point = payload.get("point")
            if point not in ("dry", "wet"):
                print(f"   ❌ Mốc hiệu chuẩn không hợp lệ: {point}")
                return
            raw, _ = simulate_adc(current_moisture)
            # Chỉ so với mốc còn lại khi mốc đó đã được đo thật, mốc mặc định chưa phải số đo
            other = adc_wet if point == "dry" else adc_dry
            other_calibrated = wet_calibrated if point == "dry" else dry_calibrated
            if other_calibrated and abs(raw - other) < MIN_CALIBRATION_GAP:
                print(f"   ❌ Bỏ qua: ADC {raw} quá gần mốc còn lại đã lưu ({other})")
                return
            if point == "dry":
                adc_dry = raw
                dry_calibrated = True
            else:
                adc_wet = raw
                wet_calibrated = True
            print(f"   🎛️ [HIỆU CHUẨN] Đã lưu mốc {'KHÔ' if point == 'dry' else 'ƯỚT'}: ADC {raw}")
            return

        print(f"   ❌ Lệnh không hỗ trợ: {action}")
    except Exception as e:
        print(f"❌ Lỗi parse lệnh JSON: {e}")

def main():
    global current_moisture, soil_type

    import argparse
    parser = argparse.ArgumentParser(description="Soil Station IoT Simulator (ESP32 Mock)")
    parser.add_argument("--broker", default=BROKER, help="MQTT Broker host")
    parser.add_argument("--port", type=int, default=PORT, help="MQTT Broker port (8883 = TLS, 1883 = plain)")
    parser.add_argument("--no-tls", action="store_true", help="Connect without TLS (use with --port 1883)")
    parser.add_argument("--username", default=os.environ.get("MQTT_USERNAME", ""),
                        help="MQTT username (or env MQTT_USERNAME)")
    parser.add_argument("--password", default=os.environ.get("MQTT_PASSWORD", ""),
                        help="MQTT password (or env MQTT_PASSWORD)")
    parser.add_argument("--cycles", type=int, default=0, help="Number of telemetry cycles to run (0 for infinite)")
    parser.add_argument("--interval", type=float, default=4.0, help="Interval between telemetry reports (seconds)")
    parser.add_argument("--moisture", type=float, default=55.0, help="Initial soil moisture percentage (0-100)")
    parser.add_argument("--once", action="store_true", help="Send a single telemetry message and exit")
    parser.add_argument("--soil-type", choices=list(SOIL_PROFILES), default="garden",
                        help="Initial soil sample type (the app can change it via SET_SOIL_TYPE)")
    args = parser.parse_args()

    current_moisture = args.moisture
    soil_type = args.soil_type
    max_cycles = 1 if args.once else args.cycles

    try:
        if hasattr(mqtt, "CallbackAPIVersion"):
            client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id=CLIENT_ID)
        else:
            client = mqtt.Client(client_id=CLIENT_ID)
    except Exception:
        client = mqtt.Client(client_id=CLIENT_ID)
    client.on_connect = on_connect
    client.on_message = on_message
    if not args.no_tls:
        client.tls_set()  # Xác thực chứng chỉ broker bằng kho CA của hệ điều hành
    if args.username:
        client.username_pw_set(args.username, args.password)

    print(f"🚀 Khởi động Trạm Giả lập ESP32 (Client ID: {CLIENT_ID})...")
    print(f"   Broker: {args.broker}:{args.port} ({'không mã hóa' if args.no_tls else 'TLS'}"
          f"{', có tài khoản' if args.username else ''}) | Chu kỳ gửi: {args.interval}s | Độ ẩm ban đầu: {current_moisture}%")
    print(f"   Loại đất: {SOIL_PROFILES[soil_type]['label']}")
    try:
        client.connect(args.broker, args.port, 60)
    except Exception as e:
        print(f"❌ Không thể kết nối tới broker {args.broker}: {e}")
        return

    client.loop_start()

    cycle = 0
    try:
        while True:
            cycle += 1

            # Mô phỏng hiệu ứng: Đất khô dần rất chậm
            current_moisture = max(35.0, current_moisture - 0.3)

            payload = build_payload(current_moisture, soil_type)
            tel = payload["telemetry"]

            json_data = json.dumps(payload, indent=2)
            client.publish(TELEMETRY_TOPIC, json_data, qos=0)

            print(f"\n[Chu kỳ #{cycle}] Đã gửi Telemetry lên Cloud ({SOIL_PROFILES[soil_type]['label']}):")
            print(f"   💧 Độ ẩm: {tel['moisture']}% | ADC: {payload['adc']['raw']} | ⚡ EC: {tel['ec']} µS/cm")
            print(f"   🧪 NPK ước lượng: Đạm(N)={tel['nitrogen']} mg/kg | Lân(P)={tel['phosphorus']} mg/kg | "
                  f"Kali(K)={tel['potassium']} mg/kg | pH={tel['ph']}")
            normal, level = payload["npk_normal"], payload["npk_level"]
            print(f"   📏 Mức bình thường của loại đất: N={normal['nitrogen']:g} P={normal['phosphorus']:g} "
                  f"K={normal['potassium']:g} -> N {level['nitrogen']}, P {level['phosphorus']}, K {level['potassium']}")

            if max_cycles > 0 and cycle >= max_cycles:
                print(f"\n🎯 Đã hoàn thành {cycle} chu kỳ kiểm thử. Dừng trạm an toàn.")
                break

            time.sleep(args.interval)

    except KeyboardInterrupt:
        print("\n🛑 Đang dừng trạm mô phỏng...")
    finally:
        client.publish(STATUS_TOPIC, json.dumps({"status": "offline", "device": CLIENT_ID}), qos=1)
        client.loop_stop()
        client.disconnect()
        print("✅ Đã ngắt kết nối an toàn.")

if __name__ == "__main__":
    main()
