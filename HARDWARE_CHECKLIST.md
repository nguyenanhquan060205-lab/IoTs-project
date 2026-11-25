# DANH SÁCH LINH KIỆN & HƯỚNG DẪN ĐẤU NỐI PHẦN CỨNG
## ĐỀ TÀI: HỆ THỐNG IoT PHÂN TÍCH DINH DƯỠNG ĐẤT: ƯỚC LƯỢNG NPK TỪ ĐỘ ẨM ĐẤT

---

### PHẦN 1: TẬN DỤNG 100% TỪ BỘ KIT SẴN CÓ (CHI PHÍ 0 VNĐ)
Bạn mở hộp kit Starter Kit / ESP32 có sẵn ra và sử dụng đúng các món sau:

| STT | Tên linh kiện trong hộp | Số lượng | Vai trò trong đề tài |
|:---:|---|:---:|---|
| 1 | **Board ESP32 (WROOM-32)** | 1 cái | "Bộ não" trung tâm: Đọc cảm biến ADC, chạy thuật toán ước lượng NPK, phát WiFi/MQTT, điều khiển Relay |
| 2 | **Cảm biến độ ẩm đất / Cảm biến nước** | 1 cái | Đầu dò cắm vào đất/nước để đo điện trở/điện dung tương quan |
| 3 | **Màn hình OLED 0.96 inch I2C (SSD1306)** | 1 cái | Hiển thị tức thời các chỉ số: Ẩm, EC, N-P-K, pH và trạng thái Bơm |
| 4 | **Module Relay 2 kênh 5V** | 1 cái | Đóng/ngắt thiết bị ngoại vi (Mô phỏng máy bơm tưới nước / van dinh dưỡng) |
| 5 | **Còi Buzzer + Đèn LED (Đỏ/Vàng/Xanh)** | 1 bộ | Còi kêu 3 tiếng ngắn khi đất vừa chuyển sang quá khô (< 35%) hoặc ngập úng (> 80%); đèn đỏ nguy hiểm, vàng cần chú ý, xanh tốt |
| 6 | **Breadboard MB102 & Bó dây cắm** | 1 bộ | Cắm mạch thử nghiệm không cần hàn |
| 7 | **Cáp Micro-USB / Type-C nạp code** | 1 sợi | Cắm vào máy tính nạp firmware C++ vào ESP32 |

> 📌 **Ưu điểm lớn nhất**: **KHÔNG CẦN MUA THÊM CẢM BIẾN 7-IN-1 RS485 ĐẮT TIỀN**. Đề tài tập trung vào sức mạnh thuật toán xử lý tín hiệu và mô hình suy diễn nông học trên vi điều khiển.

---

### PHẦN 2: SƠ ĐỒ ĐẤU NỐI DÂY AN TOÀN (WIRING PINOUT)

```
[ CẢM BIẾN ĐỘ ẨM / NƯỚC ]
   - Chân VCC  ------------> Chân 3V3 trên ESP32  <--- (BẮT BUỘC 3V3 ĐỂ AN TOÀN ADC!)
   - Chân GND  ------------> Chân GND trên ESP32
   - Chân SIG / AO -------> Chân GPIO34 trên ESP32 (Nhóm ADC1, không bị WiFi ngắt)
   - Chân DO (nếu có) ----> Để trống, firmware không dùng

[ MÀN HÌNH OLED 0.96" I2C ]
   - Chân VCC  ------------> Chân 3V3 trên ESP32
   - Chân GND  ------------> Chân GND trên ESP32
   - Chân SDA  ------------> Chân GPIO21 trên ESP32
   - Chân SCL  ------------> Chân GPIO22 trên ESP32

[ MODULE RELAY 2 KÊNH ]
   - Chân VCC  ------------> Chân Vin (5V) trên ESP32
   - Chân GND  ------------> Chân GND trên ESP32
   - Chân IN1  ------------> Chân GPIO26 (Điều khiển Máy bơm tưới)
   - Chân IN2  ------------> Chân GPIO27 (Điều khiển Van dinh dưỡng)
   - Kích mức THẤP (LOW = rơ-le đóng), giữ nguyên jumper JD-VCC trên module

[ CÒI BUZZER & ĐÈN LED ]
   - Cực Dương (+) Buzzer -> Chân GPIO25 trên ESP32 (Âm nối GND; còi chủ động hay thụ động đều được)
   - Cực Dương (+) LED Đỏ -> Chân GPIO32 trên ESP32 (qua trở 220Ω, Âm nối GND)
   - Cực Dương (+) LED Vàng-> Chân GPIO19 trên ESP32 (qua trở 220Ω, Âm nối GND)
   - Cực Dương (+) LED Xanh-> Chân GPIO33 trên ESP32 (qua trở 220Ω, Âm nối GND)
```

> [!CAUTION]
> **2 NGUYÊN TẮC BẢO VỆ CHIP**:
> 1. Dây VCC của cảm biến độ ẩm **CHỈ NỐI VÀO CHÂN 3V3** của ESP32. Nếu cắm vào chân 5V sẽ gây quá áp làm cháy cổng đọc Analog ADC của ESP32!
> 2. Luôn cắm cảm biến vào chân **GPIO34** (thuộc bộ ADC1). Tuyệt đối không cắm vào các chân thuộc ADC2 (GPIO2, 4, 12, 13, 14, 15, 25, 26, 27) để tránh bị vô hiệu hóa khi bật WiFi.
>
> Rút cáp USB trước khi cắm hoặc rút dây. Khi demo, không nối rơ-le vào thiết bị điện lưới 220V.

#### Nạp code
Nạp code khi board **chưa đấu gì** để tách lỗi USB/driver khỏi lỗi đấu dây, rồi mới rút USB và đấu cảm biến:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1`
- macOS, Linux, Git Bash: `./scripts/flash_esp32.sh`

Chi tiết và cách xử lý lỗi xem [`firmware/README.md`](firmware/README.md).

---

### PHẦN 3: NÂNG CẤP ĐỢT 2

#### 3.1. Quy trình đo trên đất thật
1. Mở App, vào **Hiệu chuẩn**. Bước 1: rút đầu dò khỏi đất, lau khô, chờ số tín hiệu đứng yên rồi bấm **Lưu mốc khô**.
2. Bước 2: nhúng đầu dò vào cốc nước tới vạch giới hạn, chờ số tín hiệu đứng yên rồi bấm **Lưu mốc ướt**.
3. Xem dòng trạng thái tín hiệu: "Tín hiệu ổn định" là đạt; "Nhiễu nhiều" thì kiểm tra lại dây cắm và nguồn.
4. Ở màn hình chính, chọn đúng loại đất, cắm đầu dò ngập vào mẫu đất, chờ khoảng 1 phút. Mỗi mẫu đo ít nhất 3 vị trí.
5. Xem lại kết quả theo ngày ở màn **Lịch sử đo** (App chỉ ghi khi đang mở).

#### 3.2. Bảo mật broker (tùy chọn)
Mặc định trạm và App đã kết nối qua TLS cổng 8883 (có mã hóa). Muốn có tài khoản riêng: tạo cluster HiveMQ Cloud Free, tạo 2 tài khoản (trạm và App), chép `firmware/src/secrets.example.h` thành `secrets.h`, chép `mobile/mqtt_config.example.json` thành `mqtt_config.json`, điền thông tin rồi chạy App bằng `flutter run --dart-define-from-file=mqtt_config.json`.
