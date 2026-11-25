---
phase: 4
title: "Đấu nối cảm biến và ngoại vi"
status: in-progress
priority: P1
effort: "20m"
dependencies: [3]
---

# Phase 4: Đấu nối cảm biến và ngoại vi

## Goal

Cảm biến độ ẩm đấu đúng vào GPIO34 và ADC thay đổi rõ khi nhúng đầu dò vào nước.

## Files to Create / Modify

- Không sửa file. Chân GPIO lấy từ `firmware/src/main.cpp` (dòng 45-51).

## Tasks & Steps

1. **Rút cáp USB trước khi đấu dây.**
2. **Cảm biến độ ẩm (bắt buộc), 3 dây**:

   | Chân cảm biến | Chân ESP32 | Ghi chú |
   |---|---|---|
   | VCC | **3V3** | Không nối 5V: tín hiệu AO có thể vượt 3.3V và làm hỏng ADC |
   | GND | GND | |
   | AO (hoặc AOUT) | **GPIO34** (in trên board là `D34`, `IO34` hoặc `34`) | Chân ADC1, vẫn đọc được khi WiFi bật |
   | DO (nếu có) | Để trống | Firmware không dùng |

   Module điện trở (đầu dò 2 càng + mạch LM393, kiểu FC-28/YL-69) và module điện dung v1.2 đều cho ADC **giảm khi ướt**. Firmware tự xử lý cả hai chiều nhờ 2 mốc hiệu chuẩn.
3. **Ngoại vi tùy chọn** (firmware tự bỏ qua nếu không cắm OLED):

   | Linh kiện | Nối vào ESP32 |
   |---|---|
   | OLED SSD1306 0.96" I2C (địa chỉ 0x3C) | VCC→3V3, GND→GND, SDA→GPIO21, SCL→GPIO22 |
   | Relay 2 kênh 5V, kích mức thấp | VCC→VIN (5V), GND→GND, IN1→GPIO26 (bơm), IN2→GPIO27 (van). Giữ nguyên jumper JD-VCC |
   | LED đỏ / vàng / xanh | GPIO32 / GPIO19 / GPIO33, mỗi LED qua điện trở 220Ω xuống GND |
   | Còi buzzer (chủ động hay thụ động đều được) | (+)→GPIO25, (−)→GND. Kêu 3 tiếng khi đất vừa chuyển sang quá khô (< 35%) hoặc ngập úng (> 80%) |

   Khi demo, không nối relay vào máy bơm chạy điện lưới 220V. Nếu dùng bơm thật, cấp nguồn riêng cho bơm.
4. Cắm lại USB, mở Serial Monitor mà không nạp lại code: `powershell -ExecutionPolicy Bypass -File scripts\flash_esp32.ps1 -MonitorOnly` (hoặc bấm biểu tượng ổ cắm *Serial Monitor* ở thanh dưới của VS Code).
5. Để đầu dò khô ngoài không khí, đọc `ADC`. Nhúng đầu dò vào cốc nước tới vạch giới hạn, đọc lại `ADC`.

## Verification

- Giá trị `ADC` khi khô và khi nhúng nước chênh nhau **hơn 300**. Firmware từ chối lưu mốc hiệu chuẩn nếu hai mốc gần nhau hơn 300 (`MIN_CALIBRATION_GAP`).
- Phần `(+-x.x)` sau ADC (độ nhiễu) dưới 15 khi để yên. Từ 50 trở lên: kiểm tra lại dây cắm và nguồn.
- Có OLED: màn hình hiện loại đất, `WIFI OK`, độ ẩm, EC, NPK, pH.
