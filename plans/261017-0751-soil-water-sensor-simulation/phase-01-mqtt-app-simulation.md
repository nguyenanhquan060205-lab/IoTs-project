---
title: "Phase 1: Kiểm thử Giả lập App Mobile & Pipeline MQTT (Zero Hardware)"
status: completed
---

# Phase 1: Kiểm thử Giả lập App Mobile & Pipeline MQTT (Zero Hardware)

## 1. Mục tiêu (Objective)
Xác thực 100% tầng phần mềm, mạng truyền thông MQTT và ứng dụng di động Flutter **mà không cần cắm bất kỳ sợi dây hay thiết bị phần cứng nào**.
Đảm bảo khi có dữ liệu cảm biến được gửi lên Cloud, App Flutter sẽ hiển thị đầy đủ, vẽ biểu đồ Radar NPK, kích hoạt Hệ chuyên gia nông học và phản hồi lệnh điều khiển máy bơm.

---

## 2. Các bước Thực hiện (Implementation Steps)

### Bước 1.1: Tạo Script Giả lập Trạm Đo bằng Python (`simulate_station.py`)
Tạo một file Python chạy độc lập trên máy tính, đóng vai trò như một chiếc ESP32 ảo:
1. Kết nối tới MQTT Broker công cộng: `broker.emqx.io:1883`.
2. Định kỳ mỗi 3 - 5 giây gửi một bản tin JSON lên topic: `soil_station/1/telemetry`.
3. Lắng nghe topic lệnh từ điện thoại: `soil_station/1/command` để phản hồi trạng thái Bật/Tắt máy bơm (Relay).

### Bước 1.2: Khởi chạy và Kiểm thử với App Flutter
1. Khởi chạy App Flutter trên máy ảo (Simulator/Emulator) hoặc máy thật bằng lệnh:
   ```bash
   cd mobile && flutter run
   ```
2. Chạy script giả lập Python:
   ```bash
   python3 simulate_station.py
   ```
3. Quan sát trên màn hình điện thoại:
   - Thẻ trạng thái kết nối chuyển sang màu xanh lá: **Đã kết nối (broker.emqx.io)**.
   - Các thẻ đo **Nitơ (N), Photpho (P), Kali (K), pH, EC, Độ ẩm, Nhiệt độ** nhảy số mượt mà theo từng chu kỳ gửi.
   - Biểu đồ mạng nhện (Radar Chart) cân bằng NPK tự động vẽ lại theo dữ liệu mới.
   - Thẻ chẩn đoán Nông học xuất khuyến nghị (Ví dụ: "Đất đang chua phèn", "Cần bón thêm Lân Super...").

### Bước 1.3: Kiểm thử luồng điều khiển Relay hai chiều (Bidirectional Command)
1. Trên màn hình App Mobile, bấm nút công tắc **"BẬT BƠM"**.
2. Kiểm tra cửa sổ dòng lệnh Terminal đang chạy `simulate_station.py`:
   - Phải xuất hiện log: `[MQTT LỆNH NHẬN ĐƯỢC] Đã nhận yêu cầu: SET_PUMP = True`.
   - Script phản hồi cập nhật trạng thái `pump: true` trong chu kỳ gửi kế tiếp.
   - Nút bơm trên điện thoại chuyển sang trạng thái sáng xanh/cam thành công.

---

## 3. Danh sách Công việc (Todo Checklist)

- [x] Tạo file Python test giả lập trạm đo `scripts/simulate_station.py` (Hỗ trợ CLI args `--cycles`, `--interval`, `--moisture`, `--once`).
- [x] Cài đặt thư viện Python `paho-mqtt` (Đã cài v2.1.0 trong `scripts/.venv`).
- [x] Chạy script và xác nhận kết nối thành công tới `broker.emqx.io` (Đã kiểm chứng qua `scripts/test_simulate_station.py` & `scripts/test_mqtt_e2e.py`).
- [x] Chạy App Flutter và kiểm tra hiển thị 7 thông số dinh dưỡng đất (13/13 Flutter unit & widget tests passed: `SoilTelemetry`, `CropProfile`, `AgronomicEngine`, `DashboardScreen`).
- [x] Thử nghiệm thay đổi chỉ số (ví dụ tăng EC lên 2200 hoặc hạ pH xuống 4.8) để xem cảnh báo chuông/đèn trên App (Đã kiểm thử tự động với `agronomic_engine_test.dart`).
- [x] Bấm nút bật/tắt bơm trên App và kiểm tra log phản hồi trên Terminal (Đã kiểm chứng roundtrip qua `test_mqtt_e2e.py`).

---

## 4. Tiêu chí Hoàn thành (Success Criteria)
- App Flutter nhận dữ liệu trơn tru không bị crash hay lag giật.
- Luồng gửi lệnh từ điện thoại tới trạm đo (và phản hồi ngược lại) có độ trễ dưới 1 giây.
- Khẳng định 100% tầng Cloud và Ứng dụng đã sẵn sàng tiếp nhận phần cứng.
