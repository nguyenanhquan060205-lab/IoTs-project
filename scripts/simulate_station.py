#!/usr/bin/env python3
"""
SIMULATE SOIL STATION (ESP32 MOCK)
Script giả lập vi điều khiển ESP32 và cảm biến nước/độ ẩm gửi telemetry lên MQTT Broker.
Dùng để kiểm thử kết nối với App Flutter mà không cần cắm phần cứng vật lý.
"""

import json
import random
import time
import sys

try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("\n[!] Chưa cài thư viện paho-mqtt.")
    print("    Vui lòng chạy: pip3 install paho-mqtt\n")
    sys.exit(1)

# Cấu hình MQTT (Khớp với Mobile App)
BROKER = "broker.emqx.io"
PORT = 1883
TELEMETRY_TOPIC = "soil_station/1/telemetry"
COMMAND_TOPIC = "soil_station/1/command"
STATUS_TOPIC = "soil_station/1/status"
CLIENT_ID = f"mock_esp32_station_{random.randint(1000, 9999)}"

# Trạng thái thiết bị ngoại vi
pump_state = False
valve_state = False

# Giá trị mô phỏng nền (Base values)
current_moisture = 55.0  # %
current_temp = 27.5      # °C

def calculate_nutrients_from_moisture(moisture):
    """
    Thuật toán ước lượng dinh dưỡng đất (Heuristic Soil Nutrition Estimation)
    Ánh xạ từ Độ ẩm -> Độ dẫn điện EC -> N, P, K và pH
    """
    # EC (µS/cm): Độ phì nhiêu tổng quát tỉ lệ với ion hòa tan trong dung dịch ẩm
    ec = (moisture * 13.5) + random.uniform(-15, 15)
    ec = max(150.0, min(2200.0, ec))

    # Đạm (Nitơ - N): Nhu cầu 70 - 120 mg/kg
    n = (ec * 0.085) + random.uniform(-3, 3)
    n = max(10.0, n)

    # Lân (Photpho - P): 25 - 55 mg/kg
    p = (ec * 0.042) + random.uniform(-2, 2)
    p = max(5.0, p)

    # Kali (K): 60 - 140 mg/kg
    k = (ec * 0.115) + random.uniform(-4, 4)
    k = max(15.0, k)

    # pH: Đất bình thường 6.0 - 6.8, khô quá thì kiềm nhẹ, ẩm quá thì hơi chua
    ph = 6.5 - ((moisture - 50.0) * 0.012) + random.uniform(-0.1, 0.1)
    ph = max(4.5, min(8.5, round(ph, 1)))

    return round(n, 1), round(p, 1), round(k, 1), ph, round(ec, 1)

def on_connect(client, userdata, flags, rc, properties=None):
    # Support both v1 integer code and v2 ReasonCode
    is_success = (rc == 0 or getattr(rc, "is_failure", False) is False)
    if is_success:
        print(f"\n✅ [MQTT] Đã kết nối thành công tới Broker: {BROKER}:{PORT}")
        print(f"📡 Lắng nghe lệnh từ App Mobile tại: {COMMAND_TOPIC}")
        print(f"📤 Bắn dữ liệu cảm biến định kỳ tại: {TELEMETRY_TOPIC}")
        print("-" * 60)
        client.subscribe(COMMAND_TOPIC)
        # Báo Online
        client.publish(STATUS_TOPIC, json.dumps({"status": "online", "device": CLIENT_ID}), qos=1)
    else:
        print(f"❌ [MQTT] Kết nối thất bại với mã lỗi: {rc}")

def on_message(client, userdata, msg):
    global pump_state, valve_state
    try:
        payload = json.loads(msg.payload.decode())
        action = payload.get("action", "")
        state = payload.get("state", False)

        print(f"\n📩 [LỆNH TỪ APP MOBILE] Topic: {msg.topic}")
        print(f"   -> Hành động: {action} | Trạng thái mới: {'BẬT (ON)' if state else 'TẮT (OFF)'}")

        if action == "SET_PUMP":
            pump_state = state
            print(f"   ⚙️ [RƠ-LE BƠM NƯỚC] Đã chuyển sang: {'HOẠT ĐỘNG' if pump_state else 'DỪNG'}")
        elif action == "SET_VALVE":
            valve_state = state
            print(f"   ⚙️ [VAN DINH DƯỠNG] Đã chuyển sang: {'MỞ' if valve_state else 'ĐÓNG'}")
    except Exception as e:
        print(f"❌ Lỗi parse lệnh JSON: {e}")

def main():
    global current_moisture, current_temp, pump_state

    import argparse
    parser = argparse.ArgumentParser(description="Soil Station IoT Simulator (ESP32 Mock)")
    parser.add_argument("--broker", default=BROKER, help="MQTT Broker host")
    parser.add_argument("--port", type=int, default=PORT, help="MQTT Broker port")
    parser.add_argument("--cycles", type=int, default=0, help="Number of telemetry cycles to run (0 for infinite)")
    parser.add_argument("--interval", type=float, default=4.0, help="Interval between telemetry reports (seconds)")
    parser.add_argument("--moisture", type=float, default=55.0, help="Initial soil moisture percentage (0-100)")
    parser.add_argument("--once", action="store_true", help="Send a single telemetry message and exit")
    args = parser.parse_args()

    current_moisture = args.moisture
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

    print(f"🚀 Khởi động Trạm Giả lập ESP32 (Client ID: {CLIENT_ID})...")
    print(f"   Broker: {args.broker}:{args.port} | Chu kỳ gửi: {args.interval}s | Độ ẩm ban đầu: {current_moisture}%")
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

            # Mô phỏng hiệu ứng: Nếu bơm đang bật -> độ ẩm tăng dần
            if pump_state:
                current_moisture = min(88.0, current_moisture + 2.5)
            else:
                # Nếu bơm tắt -> đất khô dần rất chậm
                current_moisture = max(35.0, current_moisture - 0.3)

            # Dao động nhiệt độ nhẹ
            current_temp = round(27.0 + random.uniform(-0.4, 0.4), 1)

            # Tính toán 7 chỉ số
            n, p, k, ph, ec = calculate_nutrients_from_moisture(current_moisture)

            payload = {
                "device_id": "esp32_soil_station_01",
                "timestamp": int(time.time()),
                "telemetry": {
                    "nitrogen": n,
                    "phosphorus": p,
                    "potassium": k,
                    "ph": ph,
                    "ec": ec,
                    "moisture": round(current_moisture, 1),
                    "temperature": current_temp
                },
                "actuators": {
                    "pump": pump_state,
                    "nutrient_valve": valve_state
                }
            }

            json_data = json.dumps(payload, indent=2)
            client.publish(TELEMETRY_TOPIC, json_data, qos=0)

            print(f"\n[Chu kỳ #{cycle}] Đã gửi Telemetry lên Cloud:")
            print(f"   💧 Độ ẩm: {payload['telemetry']['moisture']}% | 🌡️ Nhiệt độ: {payload['telemetry']['temperature']}°C | ⚡ EC: {ec} µS/cm")
            print(f"   🧪 NPK: Đạm(N)={n} mg/kg | Lân(P)={p} mg/kg | Kali(K)={k} mg/kg | pH={ph}")
            print(f"   🔌 Rơ-le Bơm: {'[BẬT]' if pump_state else '[TẮT]'}")

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

