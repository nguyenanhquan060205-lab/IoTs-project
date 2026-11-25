---
phase: 3
title: "Build và nạp firmware vào ESP32"
status: completed
priority: P1
effort: "20m"
dependencies: [1, 2]
---

# Phase 3: Build và nạp firmware vào ESP32

## Goal

Nạp firmware vào ESP32 (chưa đấu cảm biến) và thấy trạm vào được WiFi và MQTT qua Serial Monitor.

## Files to Create / Modify

- Không sửa file. Build sinh ra `firmware/.pio/` (đã có trong `.gitignore`).

## Tasks & Steps

1. **Chạy script nạp code** từ thư mục gốc dự án (PowerShell):
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1
   ```
   Script tự tìm `pio` (trong PATH, trong `%USERPROFILE%\.platformio\penv`, hoặc `py -m platformio`), build, tìm cổng COM của ESP32 theo chip USB (CP210x, CH340, CH9102, FTDI), bỏ qua cổng Bluetooth, nạp code rồi mở Serial Monitor 115200.
   - Chỉ build, chưa cần cắm board: thêm `-BuildOnly`.
   - Chọn cổng: thêm `-Port COM7`. Xem các cổng: `-ListPorts`.
   - Lần đầu PlatformIO tải toolchain (khoảng 4 GB sau giải nén), mất 5 - 15 phút. Máy này đã tải sẵn khi build thử nên sẽ nhanh hơn.
2. **Cách chạy tay** (nếu không dùng script):
   ```powershell
   cd firmware
   pio run
   pio run -t upload --upload-port COM7
   pio device monitor -p COM7 -b 115200
   ```
3. Bấm nút **EN/RST** trên board để xem log từ đầu. `Ctrl+C` để thoát Serial Monitor.
4. **Log đúng** trông như sau:
   ```
     HE THONG DINH DUONG DAT IOT (ESP32)
   Loai dat dang do: DAT VUON | Hieu chuan ADC: kho=200 (mac dinh), uot=3000 (mac dinh)
   [CANH BAO] Khong tim thay OLED -> ...        (bình thường nếu chưa cắm OLED)
   Dang ket noi WiFi "TenWiFi" (hoac "Wokwi-GUEST" khi mo phong).
   ✅ WiFi da ket noi!  SSID: ...  Dia chi IP: ...
   Dang ket noi MQTT broker.emqx.io:8883 (TLS)... Thanh cong!
   Da dang ky lang nghe: soil_station/1/command
   [SENSOR] Dat: DAT VUON | ADC: .... | Am: ...% | ...
   => Da gui MQTT thanh cong len topic: soil_station/1/telemetry
   ```
   Chưa cắm cảm biến thì GPIO34 bỏ trống, ADC nhảy lung tung, còi (nếu đã cắm) có thể kêu 3 tiếng. Điều này bình thường.

## Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| `Khong thay ESP32` (script) | Cáp chỉ sạc, hoặc thiếu driver CP210x/CH340 (phase 1) |
| `Failed to connect to ESP32: Timed out waiting for packet header` | Giữ nút **BOOT** khi thấy `Connecting....`, nhả khi bắt đầu `Writing at ...` |
| Nạp hay đứt giữa chừng | Thêm `upload_speed = 115200` vào `firmware/platformio.ini` |
| `could not open port 'COM7'` / `PermissionError` | Đóng Serial Monitor, Arduino IDE hay chương trình khác đang giữ cổng |
| `Chua vao duoc WiFi` | Sai mật khẩu hoặc mạng 5 GHz (phase 2). Trạm tự dò lại mỗi 15 giây |
| `[CANH BAO] Chua co secrets.h` | Chưa làm phase 2, trạm đang thử WiFi mẫu `iPhone` |
| `That bai, rc=-2` | Không mở được kết nối: sai host/cổng, mạng chặn cổng 8883, hoặc chứng chỉ TLS không khớp `root_ca.h` |
| `That bai, rc=4` hoặc `rc=5` | Sai tài khoản MQTT (chỉ gặp ở cách B) |
| Trạm khởi động lại liên tục, có `Backtrace` | Serial Monitor đã bật `esp32_exception_decoder`, chụp lại tên hàm/dòng code trong log |

## Verification

- Script in `Nap code thanh cong!` (hoặc `pio run -t upload` kết thúc bằng `SUCCESS`).
- Serial Monitor có `Thanh cong!` sau dòng MQTT và dòng `[SENSOR]` lặp lại mỗi 4 giây.
