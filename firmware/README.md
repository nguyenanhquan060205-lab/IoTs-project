# Firmware (ESP32)

Mã nguồn trạm đo: ESP32 đọc cảm biến độ ẩm đất analog ở **GPIO34**, lọc nhiễu, đổi ra % độ ẩm theo 2 mốc hiệu chuẩn, ước lượng EC và pH theo loại đất chọn trên App, tính N, P, K từ EC rồi so với mức bình thường của loại đất, sau đó gửi MQTT qua TLS (cổng 8883) 4 giây một lần.

Chỉ độ ẩm là số đo thật. EC, N, P, K, pH là số ước lượng (`src/soil_estimator.h`).

## Cấu trúc

| File | Nội dung |
|---|---|
| `src/main.cpp` | WiFi, MQTT, đọc cảm biến, đèn LED, còi, OLED, xử lý lệnh từ App |
| `src/soil_estimator.h` | Đổi ADC → % độ ẩm (2 mốc), ước lượng EC, pH, tính N, P, K từ EC (`N = 0.08 × EC`, `P = 0.04 × EC`, `K = 0.11 × EC`) và so với mức bình thường của loại đất (±20%) |
| `src/adc_filter.h` | Lọc trung bình cắt tỉa: 21 mẫu, bỏ 5 thấp nhất và 5 cao nhất |
| `src/root_ca.h` | Root CA để xác thực broker TLS (DigiCert Global Root G2, ISRG Root X1) |
| `src/secrets.example.h` | Mẫu cấu hình WiFi và broker, chép thành `secrets.h` |
| `platformio.ini` | Ghim platform `espressif32 @ 8.0.0` (Arduino-ESP32 3.3.12) và phiên bản thư viện |
| `diagram.json`, `wokwi.toml` | Mạch mô phỏng Wokwi |

## Chân GPIO

| Chân | Nối với |
|---|---|
| GPIO34 | AO của cảm biến độ ẩm (VCC cảm biến nối **3V3**, không nối 5V) |
| GPIO21 / GPIO22 | SDA / SCL của OLED SSD1306 (0x3C), không cắm thì firmware tự bỏ qua |
| GPIO32 / GPIO19 / GPIO33 | LED đỏ / vàng / xanh, mỗi LED qua điện trở 220Ω xuống GND |
| GPIO25 | Còi (+). Còi chủ động hay thụ động đều kêu vì được phát bằng PWM |

## Nạp code

1. Chép `src/secrets.example.h` thành `src/secrets.h`, điền WiFi **2.4 GHz** và broker. Không có `secrets.h` thì build vẫn chạy nhưng báo `#warning`, và trạm chỉ thử WiFi mẫu `iPhone`.
2. Cắm ESP32 bằng cáp USB truyền dữ liệu, rồi chạy từ thư mục gốc dự án:
   - Windows PowerShell: `powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1`
   - macOS, Linux, Git Bash: `./scripts/flash_esp32.sh`

   Script tự build, tìm cổng của ESP32 (bỏ qua cổng Bluetooth), nạp code và mở Serial Monitor 115200. Thêm `-Port COM7` / `--port COM7` để chọn cổng, `-BuildOnly` / `--build-only` để chỉ build, `-MonitorOnly` (PowerShell) để chỉ mở Serial Monitor mà không nạp lại.
3. Hoặc chạy tay: `pio run -t upload --upload-port COM7` rồi `pio device monitor -p COM7 -b 115200`.

Lần đầu build, PlatformIO tải toolchain ESP32 (chiếm khoảng 4 GB ổ đĩa sau khi giải nén), mất 5 - 15 phút tùy mạng. Các lần sau build mất khoảng 20 giây.

## Hoạt động

- **WiFi**: lúc khởi động thử tối đa 2 lần (khoảng 25 giây). Mất WiFi thì cứ 15 giây dò lại 1 lần; giữa các lần trạm vẫn đo, báo đèn, còi và OLED bình thường.
- **MQTT**: broker trong `secrets.h`, mất kết nối thì 5 giây thử lại. Topic `soil_station/1/status` nhận `online` (giữ lại trên broker) khi trạm kết nối và cứ 30 giây gửi lại 1 lần, và `offline` qua LWT khi trạm mất kết nối đột ngột. Trên mạng ảo `Wokwi-GUEST` trạm dùng cổng 1883 không mã hóa.
- **Lệnh từ App** (`soil_station/1/command`): `SET_SOIL_TYPE`, `CALIBRATE` (`dry` / `wet`). Sau mỗi lệnh trạm gửi ngay một bản tin để App xác nhận.
- **Hiệu chuẩn**: loại đất và 2 mốc lưu trong NVS, rút điện vẫn giữ. Mốc mới bị từ chối nếu cách mốc còn lại dưới 300 ADC, nhưng chỉ khi mốc còn lại đã được đo thật (không so với số mặc định 200 / 3000).
- **Còi**: kêu 3 tiếng ngắn khi đất vừa chuyển sang quá khô (dưới 35%) hoặc ngập úng (trên 80%). Phải về hẳn khoảng 38 - 77% mới hết báo, nên độ ẩm dao động quanh ngưỡng không làm còi kêu liên tục. Trước khi hiệu chuẩn, còi có thể kêu một lần lúc khởi động vì độ ẩm tính theo mốc mặc định.

## Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| `Failed to connect to ESP32: Timed out waiting for packet header` | Giữ nút BOOT khi thấy `Connecting....`, nhả khi bắt đầu ghi |
| Nạp hay đứt giữa chừng (board CH340, cáp dài) | Thêm `upload_speed = 115200` vào `platformio.ini` |
| `could not open port` | Đóng Serial Monitor hoặc Arduino IDE đang giữ cổng |
| `Chua vao duoc WiFi` | Sai tên/mật khẩu trong `secrets.h`, hoặc mạng 5 GHz |
| `That bai, rc=-2` | Không mở được kết nối tới broker: sai host/cổng, mạng chặn 8883, hoặc Root CA không khớp |
| `That bai, rc=4` / `rc=5` | Sai tài khoản MQTT |
| `Bo qua: ADC ... qua gan moc ... da luu` | Đầu dò chưa được lau khô hoặc chưa nhúng vào nước khi lưu mốc |

Sơ đồ đấu nối đầy đủ xem [`HARDWARE_CHECKLIST.md`](../HARDWARE_CHECKLIST.md), giao thức và thuật toán xem [`SPECIFICATION.md`](../SPECIFICATION.md).
