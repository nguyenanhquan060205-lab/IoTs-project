# Soil Nutrient Analysis and Monitoring System (IoT)

> **Dự án**: Hệ thống giám sát và phân tích dinh dưỡng đất thông minh  
> **Nền tảng**: ESP32, cảm biến độ ẩm đất, MQTT qua TLS, Flutter Mobile App (Android/iOS)  
> **Tài liệu đặc tả chi tiết**: Xem tại [SPECIFICATION.md](./SPECIFICATION.md)

---

## 📌 Tổng quan kiến trúc 3 tầng (3-Tier IoT Architecture)

1. **Tầng Thiết bị (Perception Layer)**:
   - Vi điều khiển **ESP32** đọc **cảm biến độ ẩm đất** (ADC) và ước lượng N, P, K, pH, EC theo loại đất được chọn trên App.
   - Hiển thị trực tiếp tại trạm đo qua **OLED 0.96" I2C**.
   - Cảnh báo tại chỗ bằng **Buzzer/LED** và điều khiển thiết bị qua **Relay 2 kênh**.
   - Cấp nguồn độc lập bằng **Sạc dự phòng** (Powerbank).

2. **Tầng Truyền thông (Network Layer)**:
   - Giao thức **MQTT** chuẩn IoT qua **HiveMQ Cloud Free Tier** (0đ, bảo mật TLS).
   - ESP32 kết nối mạng qua WiFi nhà hoặc điểm phát sóng 4G (Personal Hotspot) từ điện thoại.

3. **Tầng Ứng dụng & Dịch vụ (Application Layer)**:
   - **Ứng dụng di động (Flutter Mobile App)**:
     - Giám sát thời gian thực: điểm sức khỏe đất, N-P-K, độ ẩm, pH, EC so với mức chuẩn; lịch sử đo theo ngày; hiệu chuẩn cảm biến từng bước.
     - Tích hợp **Hệ chuyên gia Nông học (Rule Engine)**: Chẩn đoán điểm sức khỏe đất (Soil Health Score) và xuất khuyến nghị cải tạo đất theo chuẩn thổ nhưỡng nông nghiệp.
     - Điều khiển Relay máy bơm/van xả trực tiếp từ điện thoại với độ trễ < 1 giây.

---

## 📂 Cấu trúc thư mục (Project Structure)

```
soil-nutrient-analysis-system/
├── README.md              # Giới thiệu & tổng quan dự án
├── SPECIFICATION.md       # Đặc tả kỹ thuật, sơ đồ nối chân, thuật toán ước lượng, Rule Engine
├── docs/                  # Tài liệu sơ đồ mạch, hướng dẫn chi tiết
├── firmware/              # Mã nguồn C++ cho ESP32 (PlatformIO / Arduino)
├── backend/               # Dịch vụ Backend (tùy chọn lưu CSDL lịch sử)
└── mobile/                # Ứng dụng di động Flutter (Android & iOS)
```

---

## 🚀 Hướng dẫn bắt đầu nhanh

Chi tiết sơ đồ nối chân ESP32, thuật toán ước lượng theo loại đất, giao thức MQTT, công thức đánh giá nông học và danh mục linh kiện xem tại [SPECIFICATION.md](./SPECIFICATION.md).
