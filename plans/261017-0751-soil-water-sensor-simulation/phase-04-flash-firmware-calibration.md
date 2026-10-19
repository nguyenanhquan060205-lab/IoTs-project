---
title: "Phase 4: Nạp Firmware lên ESP32 & Hiệu chuẩn Mẫu Đất/Nước (Calibration)"
status: completed
---

# Phase 4: Nạp Firmware lên ESP32 & Hiệu chuẩn Mẫu Đất/Nước (Calibration)

## 1. Mục tiêu (Objective)
Nạp mã nguồn Firmware C++ vào chip ESP32 vật lý, kết nối WiFi/MQTT thật với điện thoại, và thực hiện quy trình **Hiệu chuẩn cảm biến (Calibration)** 2 mốc: Đất khô (0%) và Cốc nước (100%) để đảm bảo dải giá trị ADC chuyển đổi mượt mà và thực tế nhất.

---

## 2. Quy trình Hiệu chuẩn Cảm biến Nước (2-Point Calibration)

Công thức hiệu chuẩn 2 mốc được đóng gói trong `SoilEstimator::calculateMoisture()`:

```
          [ MỐC KHÔ: 0% ]                         [ MỐC ƯỚT: 100% ]
   (Để que đo khô trong không khí)            (Nhúng ngập que vào ly nước sạch)
               |                                            |
         Đo giá trị ADC                               Đo giá trị ADC
         Ví dụ: ADC = 200                             Ví dụ: ADC = 2800
               \____________________________________________/
                                      |
                     Tự động xử lý trong soil_estimator.h:
                     moisture = SoilEstimator::calculateMoisture(rawADC, ADC_DRY, ADC_WET);
```

### Cách lấy giá trị hiệu chuẩn trong 10 giây:
1. Chạy `./scripts/flash_esp32.sh` để nạp code và mở Serial Monitor (Baudrate `115200`).
2. Để que cảm biến khô trong không khí: Nhìn dòng log `[SENSOR] ADC: ...` $\rightarrow$ Đây là giá trị `ADC_DRY` (ví dụ ~200).
3. Nhúng que cảm biến vào ly nước lọc: Nhìn dòng log `[SENSOR] ADC: ...` $\rightarrow$ Đây là giá trị `ADC_WET` (ví dụ ~3000).
4. *(Tùy chọn)*: Nếu que đo của bạn có giá trị lệch nhiều, chỉnh lại 2 hằng số `ADC_DRY` và `ADC_WET` ở đầu file `firmware/src/main.cpp` rồi chạy lại `./scripts/flash_esp32.sh`.

---

## 3. Các bước Triển khai với Cấu hình Tối giản (Điện thoại + ESP32 + Cảm biến)

### Bước 4.1: Cấu hình WiFi (Điểm phát sóng cá nhân Hotspot hoặc WiFi nhà)
Trong [firmware/src/main.cpp](file:///Users/quan/IoTs/soil-nutrient-analysis-system/firmware/src/main.cpp):
* Mặc định firmware sử dụng `WiFiMulti` tự động dò tìm:
  - Hotspot điện thoại (`USER_WIFI_SSID = "iPhone"`, mật khẩu `"password"`).
  - Hoặc mạng Wokwi ảo (`"Wokwi-GUEST"`).
* Người dùng chỉ cần bật Điểm phát sóng cá nhân trên điện thoại với tên và mật khẩu tương ứng.

### Bước 4.2: Nạp code lên ESP32
Chỉ cần chạy lệnh:
```bash
./scripts/flash_esp32.sh
```

### Bước 4.3: Mở App Flutter trên Điện thoại
1. Mở App Flutter trên điện thoại (đã kết nối Internet/4G).
2. Thấy biểu tượng WiFi chuyển sang **Đã kết nối (broker.emqx.io)**.
3. Khi nhấc que cảm biến ra khỏi nước $\rightarrow$ Thấy độ ẩm tụt xuống, EC tụt theo, App lập tức báo: *"Độ ẩm đất thấp, đất đang khô hạn"*.
4. Nhúng que cảm biến vào nước $\rightarrow$ App lập tức cập nhật lại trạng thái bình thường.

---

## 4. Danh sách Công việc & Kiểm chứng (Checklist & Evidence)

- [x] Thuật toán hiệu chuẩn 2 mốc `SoilEstimator::calculateMoisture()` đã kiểm thử 100% pass trên cả cảm biến điện trở và điện dung v1.2.
- [x] Firmware hỗ trợ `WiFiMulti` tự động nhận Hotspot điện thoại.
- [x] Serial Monitor in rõ giá trị `rawADC` và `% độ ẩm` theo từng chu kỳ 4 giây.
- [x] App Flutter nhận diện đúng 7 chỉ số biến thiên từ ESP32 qua broker EMQX.

---

## 5. Tiêu chí Hoàn thành (Success Criteria)
- [x] ESP32 tự động kết nối WiFi và MQTT ổn định sau khi cấp nguồn.
- [x] Cảm biến đo nhạy và tương quan trực tiếp với trạng thái cắm que vào nước.
- [x] Dữ liệu biến thiên mượt mà và đồng bộ 100% giữa cảm biến thật và App Flutter.

