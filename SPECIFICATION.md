# SOIL NUTRIENT ANALYSIS AND MONITORING SYSTEM
## BẢN ĐẶC TẢ KỸ THUẬT VÀ KIẾN TRÚC DỰ ÁN (PROJECT SPECIFICATION)
### Đề tài: Hệ thống IoT Phân tích Dinh dưỡng Đất - Ước lượng NPK từ Độ ẩm Đất bằng Thuật toán Thực nghiệm

---

### 1. TỔNG QUAN DỰ ÁN (EXECUTIVE SUMMARY)
* **Tên đề tài**: Hệ thống IoT phân tích dinh dưỡng đất: Ước lượng NPK từ độ ẩm đất (Smart Soil Nutrient Analysis System: Heuristic NPK Estimation from Soil Moisture).
* **Nền tảng công nghệ**: Vi điều khiển ESP32, Cảm biến độ ẩm đất điện dung/nước, Giao thức MQTT (EMQX/HiveMQ Cloud), Ứng dụng di động Flutter (Android/iOS/macOS).
* **Bối cảnh & Tính cấp thiết**:
  - Cảm biến NPK chuyên dụng trên thị trường có giá thành rất cao (hàng triệu đồng) và điện cực đo nhanh bị oxy hóa, ăn mòn khi cắm lâu trong đất; phân tích hóa nghiệm phòng lab thì tốn kém và mất nhiều ngày.
  - Cảm biến độ ẩm đất có giá thành rất rẻ (15.000đ – 30.000đ), bền bỉ, dễ triển khai đo liên tục theo thời gian thực.
* **Mục tiêu cốt lõi**:
  - Chế tạo trạm đo IoT giá rẻ (Edge Node) sử dụng vi điều khiển **ESP32** và **cảm biến độ ẩm đất**.
  - Ứng dụng **Thuật toán suy diễn thực nghiệm (Empirical Heuristic Estimation Algorithm)** chạy trực tiếp trên chip ESP32 (Edge Computing) để ước lượng các chỉ số: **Độ ẩm (%), EC (độ dẫn điện/độ phì), Đạm (N), Lân (P), Kali (K) và pH**.
  - Hiển thị thông số trực tiếp tại chỗ qua màn hình **OLED 0.96 inch SSD1306**.
  - Truyền dữ liệu hai chiều thời gian thực qua giao thức mạng **MQTT** với định dạng **JSON**.
  - Tích hợp **Hệ chuyên gia Nông học (Rule-based Agronomic Engine)** trên ứng dụng di động **Flutter**: hiển thị N, P, K, độ ẩm, pH, EC so với mức chuẩn, chẩn đoán độ màu mỡ của đất và tự động xuất khuyến nghị cải tạo đất theo Ngưỡng Đất Màu Mỡ Chuẩn Nông Nghiệp.
  - Hỗ trợ **Điều khiển thiết bị ngoại vi hai chiều**: Bật/tắt máy bơm tưới nước và van xả dinh dưỡng từ xa qua điện thoại.

---

### 2. DANH MỤC PHẦN CỨNG & SƠ ĐỒ KẾT NỐI (HARDWARE BOM & PINOUT)

#### 2.1. Danh sách linh kiện (Hardware BOM - Tận dụng 100% từ Starter Kit)
| STT | Tên linh kiện | Vai trò trong hệ thống | Ghi chú an toàn |
|:---:|---|---|---|
| 1 | **Board ESP32-WROOM-32** (30/38 chân) | Bộ xử lý trung tâm (Edge Node): Đọc ADC, chạy giải thuật ước lượng, phát WiFi/MQTT | Cấp nguồn qua cổng USB 5V |
| 2 | **Cảm biến độ ẩm đất / Cảm biến nước** | Đầu dò cảm biến đo điện trở/điện dung đất | **Cấp nguồn 3V3** (TUYỆT ĐỐI không cắm 5V vào chân ADC) |
| 3 | **Màn hình OLED 0.96 inch I2C** (SSD1306) | Hiển thị thông số đất tức thời tại trạm đo | Giao tiếp I2C (địa chỉ `0x3C`) |
| 4 | **Module Relay 2 kênh 5V** | Đóng ngắt thiết bị ngoại vi (Mô phỏng máy bơm tưới / van dinh dưỡng) | Kích hoạt mức Cao (High) hoặc Thấp (Low) |
| 5 | **Còi Buzzer + LED đỏ/xanh** | Cảnh báo ngưỡng nguy hiểm (đất khô cằn / ngập úng / ngộ độc phân) | Nối chân GPIO25 và GPIO32 |
| 6 | **Breadboard MB102 & Dây cắm đực-cái** | Kết nối mạch cắm không cần dùng mỏ hàn | Dễ tháo lắp khi thử nghiệm |

#### 2.2. Sơ đồ kết nối chân vi điều khiển (ESP32 Pinout Mapping)

```
       +----------------------------------------------------+
       |                    ESP32 BOARD                     |
       +----------------------------------------------------+
            |
            | GPIO34 (ADC1) <----  Chân SIG (Cảm biến nước / độ ẩm đất)
            | 3V3           ---->  Chân VCC (Cảm biến độ ẩm) [AN TOÀN!]
            | GND           ---->  Chân GND (Cảm biến độ ẩm)
            |
            | GPIO21 (SDA)  <--->  SDA (Màn hình OLED 0.96" I2C)
            | GPIO22 (SCL)  ---->  SCL (Màn hình OLED 0.96" I2C)
            | 3V3 / GND     ---->  Cấp nguồn nuôi OLED
            |
            | GPIO26        ---->  IN1 (Module Relay) -> Điều khiển Máy bơm
            | GPIO27        ---->  IN2 (Module Relay) -> Điều khiển Van dinh dưỡng
            | 5V (Vin) / GND---->  Cấp nguồn nuôi Module Relay
            |
            | GPIO25        ---->  Cực Dương (+) Còi Buzzer (Cực âm nối GND)
            | GPIO32        ---->  LED Đỏ cảnh báo (qua điện trở 220Ω, âm nối GND)
            | GPIO33        ---->  LED Xanh báo bình thường
            +----------------------------------------------------+
```

> [!IMPORTANT]
> **QUY TẮC AN TOÀN SỐNG CÒN**:
> 1. Chân tín hiệu cảm biến **bắt buộc nối vào chân ADC1 (GPIO34)**. Không cắm vào các chân ADC2 (như GPIO2, GPIO4, GPIO12...) vì ADC2 bị ngắt nội bộ khi ESP32 kích hoạt WiFi.
> 2. Cấp nguồn cảm biến bằng chân **3V3** để bảo vệ bộ chuyển đổi ADC 12-bit của ESP32 không bị quá áp.

---

### 3. THUẬT TOÁN SUY DIỄN THỰC NGHIỆM ƯỚC LƯỢNG NPK (ALGORITHM DESIGN)

Thay vì dùng mô hình học máy "hộp đen" phức tạp đòi hỏi máy chủ cấu hình cao, hệ thống sử dụng **Thuật toán suy diễn thực nghiệm biên (Edge Heuristic Estimation Algorithm)** chạy trực tiếp trên vi điều khiển ESP32 với độ phức tạp $O(1)$:

```mermaid
flowchart TD
    A[Tín hiệu Analog thô từ cảm biến GPIO34] --> B[Giai đoạn 1: Lọc trung bình cắt tỉa 21 mẫu]
    B --> C[Giai đoạn 2: Chuẩn hóa 2 điểm ADC_DRY và ADC_WET]
    C --> D[Tính toán Độ ẩm thực tế Moisture %]
    
    D --> E[Giai đoạn 3: Tính toán Độ dẫn điện tương quan EC]
    S[Loại đất chọn trên App] --> E
    S --> F1[Đạm N, Lân P, Kali K theo loại đất]
    D --> F4[Ước lượng biến thiên pH theo độ bão hòa nước]
    S --> F4
    
    F1 & F4 & D & E --> G[Đóng gói JSON Telemetry]
    G --> H1[Hiển thị OLED 0.96 inch]
    G --> H2[Gửi MQTT lên Cloud Broker]
    H2 --> I[App Mobile Flutter & Hệ chuyên gia Nông học]
```

#### Công thức toán học của Thuật toán:

1. **Lọc nhiễu trung bình cắt tỉa (Trimmed Mean Filter)**: Đọc 21 mẫu, sắp xếp tăng dần, bỏ 5 mẫu thấp nhất và 5 mẫu cao nhất rồi lấy trung bình 11 mẫu giữa, nhờ đó các gai nhiễu do chạm dây hay relay đóng cắt bị loại hẳn:
   $$ADC_{filtered} = \frac{1}{11} \sum_{i=6}^{16} ADC_{sorted}(i)$$
   Trạm gửi kèm độ lệch chuẩn của 21 mẫu thô (`adc.noise`) để đánh giá mức nhiễu thật khi đo ngoài đất.

2. **Hiệu chuẩn độ ẩm thể tích $\theta$ (%)**:
   $$\theta = \text{constrain}\left( \frac{ADC_{filtered} - ADC_{DRY}}{ADC_{WET} - ADC_{DRY}} \times 100, \ 0, \ 100 \right)$$
   *(Trong đó $ADC_{DRY}$ là mốc khô trong không khí, $ADC_{WET}$ là mốc ngâm nước. Giá trị mặc định 200 / 3000 chỉ để chạy thử; với cảm biến thật, hai mốc được đo lại bằng màn **Hiệu chuẩn** trên App (lệnh `CALIBRATE`) và lưu vào flash. Module LM393/FC-28 cho ADC giảm khi ướt nên $ADC_{DRY} > ADC_{WET}$, công thức tự đảo chiều).*

3. **Ước lượng Độ dẫn điện dung dịch đất (Pore Solution EC - $\mu S/cm$)**:
   Theo định luật vật lý đất, khi độ ẩm tăng, các muối khoáng ion hòa tan linh động hơn. Tốc độ tăng phụ thuộc loại đất đang đo (chọn trên App):
   $$EC = \theta \times k_{EC}$$

   | Loại đất (mã MQTT) | Dự đoán dinh dưỡng | $k_{EC}$ ($\mu S/cm$ mỗi 1% ẩm) | $pH_{0}$ | $N_0$ | $P_0$ | $K_0$ (mg/kg) |
   |---|---|---|---|---|---|---|
   | Đất dinh dưỡng đóng bao (`potting`) | Cao | 20.0 | 6.2 | 95 | 50 | 135 |
   | Đất vườn - đất thịt (`garden`, mặc định) | Trung bình | 13.5 | 6.5 | 65 | 33 | 90 |
   | Đất bạc màu / bãi đất trống (`barren`) | Thấp | 4.0 | 5.8 | 20 | 10 | 30 |

4. **Ước lượng N, P, K (mg/kg)**: N, P, K là lượng dinh dưỡng có sẵn trong mẫu đất, tưới thêm nước không làm đất giàu dinh dưỡng hơn, nên lấy theo loại đất và không phụ thuộc độ ẩm:
   $$N = N_0, \quad P = P_0, \quad K = K_0$$
   Vì loại đất là đầu vào quyết định N, P, K, kết quả Cao / Trung bình / Thấp của 3 mẫu đất là do loại đất được chọn, không phải số đo độc lập. Muốn có N, P, K đo thật cần cảm biến NPK chuyên dụng, nằm ngoài phạm vi đề tài (đề tài chọn hướng ước lượng bằng thuật toán).
5. **Độ chua (pH)**: Dao động quanh $pH_{0}$ của loại đất, hơi chua khi úng nước và kiềm hóa khi khô hạn:
   $$pH = pH_{0} - ((\theta - 50.0) \times 0.012)$$

---

### 4. GIAO THỨC TRUYỀN THÔNG MQTT CLOUD

* **Broker**: Mặc định `broker.emqx.io` cổng `8883` qua **TLS** (mã hóa đường truyền, ESP32 xác thực chứng chỉ broker bằng Root CA trong [`root_ca.h`](firmware/src/root_ca.h)). Broker công cộng không có tài khoản nên ai biết topic vẫn đọc hoặc gửi được; để chặn việc này, tạo broker riêng có tài khoản (ví dụ HiveMQ Cloud Free), điền vào `firmware/src/secrets.h` (mẫu: [`secrets.example.h`](firmware/src/secrets.example.h)) và `mobile/mqtt_config.json` (mẫu: [`mqtt_config.example.json`](mobile/mqtt_config.example.json)), rồi chạy App bằng `flutter run --dart-define-from-file=mqtt_config.json`. Hai file thật đã nằm trong `.gitignore`.
* **Topic Telemetry** (`soil_station/1/telemetry`): ESP32 gửi dữ liệu định kỳ mỗi 3–5 giây.
* **Topic Command** (`soil_station/1/command`): Lệnh bật/tắt Relay (`{"action": "SET_PUMP", "state": true}`), lệnh chọn loại đất đang đo (`{"action": "SET_SOIL_TYPE", "soil_type": "garden"}`, giá trị `potting` / `garden` / `barren`) và lệnh hiệu chuẩn (`{"action": "CALIBRATE", "point": "dry"}` hoặc `"wet"`: trạm lấy ADC đang đọc làm mốc, từ chối nếu hai mốc cách nhau dưới 300). ESP32 lưu loại đất và mốc hiệu chuẩn vào flash (NVS) nên khởi động lại vẫn giữ.
* **Topic Status** (`soil_station/1/status`): Bản tin LWT kiểm tra trạng thái Online/Offline của thiết bị.

#### Cấu trúc Payload mẫu (JSON):
`timestamp` là giờ thực Unix lấy từ NTP (`pool.ntp.org`, múi giờ UTC+7); khi trạm chưa đồng bộ được giờ thì bỏ trống và App dùng giờ nhận bản tin. Trạm chưa có cảm biến nhiệt nên không gửi `temperature`. Khối `adc` phục vụ màn Hiệu chuẩn.
```json
{
  "device_id": "esp32_soil_station_01",
  "timestamp": 1764000000,
  "soil_type": "garden",
  "telemetry": {
    "nitrogen": 65.0,
    "phosphorus": 33.0,
    "potassium": 90.0,
    "ph": 6.4,
    "ec": 742.5,
    "moisture": 55.0
  },
  "adc": {
    "raw": 1740,
    "noise": 6.2,
    "dry": 200,
    "wet": 3000
  },
  "actuators": {
    "pump": false,
    "nutrient_valve": false
  }
}
```

---

### 5. HỆ CHUYÊN GIA NÔNG HỌC (AGRONOMIC RULE ENGINE) TRÊN APP

Hệ chuyên gia được tích hợp sẵn trong Mobile App Flutter ([`AgronomicEngine`](../mobile/lib/services/agronomic_engine.dart)), đối chiếu số liệu ước lượng với Ngưỡng Đất Màu Mỡ Chuẩn Thổ Nhưỡng Nông Nghiệp (pH 6.0-7.2, EC 500-1500, N 50-100, P 30-70, K 80-150, Độ ẩm 50-70%):

* **Đất chua phèn ($pH < 5.5$)**: Cảnh báo rễ khó hấp thu Lân $\rightarrow$ Gợi ý bón vôi nông nghiệp / dolomite.
* **Đất ngộ độc muối ($EC > 1800 \ \mu S/cm$)**: Cảnh báo cháy rễ $\rightarrow$ Khuyến nghị ngừng bón phân, tưới xả nước ngọt.
* **Đất khô cằn ($\theta < 40\%$)**: Cảnh báo thiếu ẩm $\rightarrow$ Tự động đề xuất kích hoạt bơm tưới.
* **Thiếu Đạm/Lân/Kali**: Tính độ chênh lệch $\Delta N, \Delta P, \Delta K$ và gợi ý công thức phân bón tương ứng (Urê, Super Lân, Kali Sunfat hoặc NPK cân đối).

**Lịch sử đo**: App lưu số đo vào SQLite trên điện thoại ([`HistoryRepository`](mobile/lib/services/history_repository.dart)), mỗi phút 1 bản ghi, giữ 30 ngày. Màn Lịch sử vẽ biểu đồ từng chỉ số theo 24 giờ / 7 ngày / 30 ngày (kèm dải ngưỡng chuẩn) và bảng trung bình theo ngày, tách theo loại đất. App chỉ ghi khi đang mở và nhận được dữ liệu; muốn ghi liên tục 24/7 cần một máy chủ đăng ký topic telemetry và lưu vào CSDL.

---

### 6. CẤU TRÚC THƯ MỤC DỰ ÁN

```
soil-nutrient-analysis-system/
├── README.md              # Giới thiệu & tổng quan dự án
├── SPECIFICATION.md       # Bản đặc tả kỹ thuật chi tiết (file này)
├── HARDWARE_CHECKLIST.md  # Danh mục linh kiện và sơ đồ đấu nối
├── plans/                 # Kế hoạch 5 giai đoạn triển khai chi tiết
├── firmware/              # Mã nguồn C++ cho ESP32 (Arduino / PlatformIO)
│   ├── src/main.cpp       # Code nhúng: ADC, Thuật toán ước lượng, OLED, MQTT
│   ├── diagram.json       # Sơ đồ mạch ảo mô phỏng trên Wokwi
│   └── wokwi.toml         # Cấu hình Wokwi
├── simulator/             # Trình giả lập trạm đo Web UI chạy trực tiếp trên máy
│   └── index.html         # Giao diện OLED ảo + Cảm biến nước Slider + Relay
├── scripts/               # Script giả lập Python kiểm thử mạng MQTT
│   └── simulate_station.py
└── mobile/                # Ứng dụng di động Flutter (Android, iOS, macOS)
```
