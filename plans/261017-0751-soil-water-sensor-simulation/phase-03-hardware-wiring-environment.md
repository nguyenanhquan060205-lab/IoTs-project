---
title: "Phase 3: Thiết lập Môi trường Nạp code & Đấu nối Mạch thật An toàn"
status: completed
---

# Phase 3: Thiết lập Môi trường Nạp code & Đấu nối Mạch thật An toàn

## 1. Mục tiêu (Objective)
Cài đặt môi trường lập trình (Arduino IDE hoặc PlatformIO), cài đặt driver giao tiếp cổng USB với chip ESP32, và đấu nối phần cứng vật lý trên Breadboard theo **quy tắc an toàn tuyệt đối** nhằm chống đoản mạch (ngắn mạch), chống cấp quá áp làm cháy chân vi điều khiển.

---

## 2. Quy tắc Sống còn khi Đấu nối Phần cứng (Hardware Safety Rules)

> [!CAUTION]
> **3 NGUYÊN TẮC BẢO VỆ CHIP ESP32 CHỐNG CHÁY**:
> 1. **Tuyệt đối không cấp điện áp 5V vào chân tín hiệu Analog (ADC)**:
>    - Các chân ADC trên ESP32 chỉ chịu được mức điện áp tối đa **3.3V**.
>    - Dây VCC của cảm biến nước **BẮT BUỘC cắm vào chân 3V3 của ESP32**, không được cắm vào chân Vin/5V.
> 2. **Chỉ cắm cảm biến vào nhóm chân ADC1**:
>    - ESP32 có 2 bộ ADC: ADC1 và ADC2. Khi kích hoạt WiFi (để chạy MQTT), **toàn bộ các chân ADC2 sẽ bị ngắt nội bộ**.
>    - Vì vậy, cảm biến bắt buộc cắm vào nhóm chân **ADC1**: `GPIO34` (khuyến nghị), `GPIO35`, `GPIO32` hoặc `GPIO33`.
> 3. **Rút cáp USB trước khi cắm dây trên Breadboard**:
>    - Luôn ngắt nguồn máy tính trước khi di dời dây cắm để tránh cắm nhầm dây nguồn chạm mass làm nổ chip USB-UART (CP2102/CH340).

---

## 3. Sơ đồ Đấu nối Dây Thực tế (Pinout Mapping)

### ⭐ CẤU HÌNH TỐI GIẢN (CORE MINIMUM SETUP - CHỈ 3 SỢI DÂY):
```
[ CẢM BIẾN NƯỚC / ĐỘ ẨM ]
   - Chân VCC  ------------> Chân 3V3 trên ESP32 (BẮT BUỘC 3V3 ĐỂ AN TOÀN ADC!)
   - Chân GND  ------------> Chân GND trên ESP32
   - Chân SIG (Signal) ----> Chân GPIO34 trên ESP32 (ADC1)
```
*(Chỉ cần cắm đúng 3 sợi này là hệ thống hoạt động 100%, gửi dữ liệu về App điện thoại bình thường)*

---

### 🎁 CÁC MÔ-ĐUN BỔ SUNG KHI ĐI BÁO CÁO / CHẤM THI (OPTIONAL):
```
[ MÀN HÌNH OLED 0.96" I2C - TÙY CHỌN ]
   - Chân VCC  ------------> Chân 3V3 trên ESP32
   - Chân GND  ------------> Chân GND trên ESP32
   - Chân SDA  ------------> Chân GPIO21 trên ESP32
   - Chân SCL  ------------> Chân GPIO22 trên ESP32

[ MODULE RELAY 2 KÊNH 5V - TÙY CHỌN ]
   - Chân VCC  ------------> Chân Vin (5V) trên ESP32
   - Chân GND  ------------> Chân GND trên ESP32
   - Chân IN1  ------------> Chân GPIO26 (Điều khiển Bơm tưới)
   - Chân IN2  ------------> Chân GPIO27 (Tùy chọn van dinh dưỡng)

[ CÒI BUZZER + LED - TÙY CHỌN ]
   - Còi Buzzer Dương (+) -> Chân GPIO25 trên ESP32 (Âm nối GND)
   - LED Đỏ Dương (+)    -> Chân GPIO32 (qua điện trở 220Ω, Âm nối GND)
```

---

## 4. Các bước Thực hiện & Script Nạp 1-Click

### Bước 3.1: Xác thực Môi trường PlatformIO & Toolchain
- PlatformIO Core 6.2.0 đã cài đặt hoàn tất trên máy Mac.
- Toolchain `xtensa-esp32-elf` và Framework `arduinoespressif32` đã biên dịch thành công 100%.
- Các thư viện phụ thuộc (`PubSubClient`, `ArduinoJson`, `Adafruit SSD1306`, `Adafruit GFX`) đã được tự động cài đặt.

### Bước 3.2: Nạp code cực dễ với Script 1-Click
Chỉ cần cắm cáp USB nối ESP32 với máy Mac và chạy:
```bash
./scripts/flash_esp32.sh
```
Script sẽ tự động tìm cổng USB, nạp firmware và bật ngay Serial Monitor để xem thông số cảm biến!

---

## 5. Danh sách Công việc & Kiểm chứng (Checklist & Evidence)

- [x] Môi trường PlatformIO Core 6.2.0 sẵn sàng biên dịch không thiếu thư viện.
- [x] Sơ đồ chân an toàn 3 dây (VCC -> 3V3, GND -> GND, SIG -> GPIO34) được kiểm chứng không xung đột WiFi ADC2.
- [x] Script nạp code tự động `scripts/flash_esp32.sh` đã sẵn sàng và cấp quyền thực thi.
- [x] Code firmware không phụ thuộc OLED, tự động chạy trơn tru chế độ tối giản (Core Setup).

---

## 6. Tiêu chí Hoàn thành (Success Criteria)
- [x] Đấu nối tối giản an toàn, không lo cháy nổ vi điều khiển.
- [x] Môi trường biên dịch và script nạp code sẵn sàng 100%.
