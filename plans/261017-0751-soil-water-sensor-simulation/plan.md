---
title: "Triển khai Hệ thống Dinh dưỡng Đất IoT: Giả lập An toàn & Cảm biến Nước Ước lượng NPK/pH"
description: "Kế hoạch 5 giai đoạn triển khai từ kiểm thử giả lập phần mềm, mô phỏng vi điều khiển trên Wokwi, đến nạp code an toàn lên ESP32 thật và chuẩn bị kịch bản bảo vệ đồ án."
status: completed
priority: P1
effort: "6h"
tags: [iot, esp32, simulation, wokwi, mqtt, flutter, heuristic-agronomy]
created: 2026-10-17
---

# KẾ HOẠCH TRIỂN KHAI DỰ ÁN DINH DƯỠNG ĐẤT IOT (ESP32)
## Phương pháp: Giả lập An toàn trước -> Nạp Phần cứng Thật -> Thuật toán Ước lượng NPK/pH

## 1. Tổng quan Dự án (Executive Summary)
Dự án xây dựng trạm IoT giám sát sức khỏe đất trồng nông nghiệp thông minh:
* **Vi điều khiển**: ESP32 kết nối mạng WiFi/MQTT.
* **Cảm biến đầu vào**: Cảm biến nước / độ ẩm đất chi phí thấp (đọc điện áp Analog ADC).
* **Thuật toán lõi**: Bộ lọc trung bình trượt + Mô hình suy diễn tương quan nông học (Heuristic Agronomic Estimation) ước lượng 7 chỉ số: Độ ẩm, Nhiệt độ, EC (độ phì/mặn), pH, Đạm (N), Lân (P), Kali (K).
* **Đầu ra ngoại vi**: Hỗ trợ linh hoạt cấu hình tối giản (ESP32 + Cảm biến độ ẩm + Điện thoại) và mở rộng OLED/Relay.
* **Tầng Ứng dụng**: Mobile App Flutter trực quan hóa radar NPK, chẩn đoán bệnh đất và điều khiển relay thời gian thực.
* **Tiêu chí an toàn**: **100% kiểm thử giả lập (Simulation First)** chạy mượt trước khi cắm dây nạp vào ESP32 thật để chống chập cháy mạch.

---

## 2. Mục tiêu Cốt lõi (Core Goals)

| # | Mục tiêu | Độ ưu tiên | Đo lường hoàn thành |
|---|---|:---:|---|
| 1 | **Giả lập luồng MQTT & App Flutter (0 linh kiện)** | P1 | Script giả lập gửi JSON lên `broker.emqx.io`, App Flutter hiển thị chuẩn 7 chỉ số (100% Passed) |
| 2 | **Mô phỏng vi điều khiển ESP32 trên Wokwi** | P1 | Code C++ chạy ảo trên Wokwi, firmware biên dịch PlatformIO 100% thành công |
| 3 | **Đấu nối dây phần cứng an toàn & Cài đặt môi trường** | P1 | Sơ đồ 3 dây tối giản (3V3, GND, GPIO34), script `flash_esp32.sh` nạp tự động |
| 4 | **Nạp Firmware lên ESP32 thật & Hiệu chuẩn cảm biến** | P1 | Hiệu chuẩn 2 mốc `SoilEstimator` đạt 100% pass trên cả cảm biến điện trở và điện dung |
| 5 | **Điều khiển Relay 2 chiều & Chuẩn bị kịch bản bảo vệ đồ án** | P1 | Điều khiển 2 chiều qua MQTT + Tự ngắt khi úng nước + Kịch bản vấn đáp 3 phút hoàn chỉnh |

---

## 3. Lộ trình Triển khai (Execution Roadmap)

| Giai đoạn | Tên Giai đoạn | File Chi tiết | Trạng thái |
|:---:|---|---|:---:|
| **P1** | [Kiểm thử Giả lập App Flutter & Pipeline MQTT](./phase-01-mqtt-app-simulation.md) | `phase-01-mqtt-app-simulation.md` | Completed |
| **P2** | [Mô phỏng Vi điều khiển ESP32 trên Wokwi (Virtual Circuit)](./phase-02-firmware-wokwi-simulation.md) | `phase-02-firmware-wokwi-simulation.md` | Completed |
| **P3** | [Thiết lập Môi trường Nạp code & Đấu nối Mạch thật](./phase-03-hardware-wiring-environment.md) | `phase-03-hardware-wiring-environment.md` | Completed |
| **P4** | [Nạp Firmware lên ESP32 & Hiệu chuẩn Mẫu đất/nước](./phase-04-flash-firmware-calibration.md) | `phase-04-flash-firmware-calibration.md` | Completed |
| **P5** | [Điều khiển Ngoại vi (Relay) & Kịch bản Báo cáo Hội đồng](./phase-05-relay-and-defense-prep.md) | `phase-05-relay-and-defense-prep.md` | Completed |

---

## 4. Quản trị Rủi ro & Giải pháp (Risk Management)

| Rủi ro tiềm ẩn | Mức độ | Biện pháp ngăn chặn / Xử lý |
|---|:---:|---|
| Chập chân nguồn hoặc cháy cổng ADC ESP32 | **Cao** | Cấp nguồn cảm biến nước ở chân **3V3** (TUYỆT ĐỐI không nối chân 5V vào chân Analog ADC); test mạch ảo trên Wokwi trước |
| Mất WiFi / Không gửi được MQTT khi dùng chân ADC2 | **Trung bình** | ESP32 bị ngắt ADC2 khi bật WiFi. Giải pháp: Chỉ cắm cảm biến vào nhóm chân **ADC1** (`GPIO34`, `GPIO35`, `GPIO32`, `GPIO33`) |
| Giảng viên hỏi vặn về cơ sở đo NPK từ cảm biến nước | **Cao** | Không tuyên bố "cảm biến đo trực tiếp NPK", mà trình bày theo hướng **"Mô hình suy diễn thực nghiệm chi phí thấp (Low-cost Heuristic Estimation)"** |
| Cảm biến nước bị oxi hóa điện phân sau thời gian dài cắm đất | **Thấp** | Chỉ bật nguồn đo xung nhịp định kỳ (pulse power) hoặc lau khô sau khi demo |

---

## 5. Tiêu chí Nghiệm thu Toàn diện (Success Criteria)

- [x] Script giả lập gửi dữ liệu đẩy App Flutter nhảy số và vẽ radar NPK mượt mà (Đã kiểm chứng với 13 tests Flutter và MQTT test live).
- [x] Code C++ chạy trơn tru trên Wokwi mô phỏng: OLED hiển thị, Relay đóng cắt ảo, MQTT publish đều đặn 4s/lần.
- [x] Đấu nối mạch phần cứng thật theo cấu hình tối giản 3 dây an toàn (nguồn 3V3, GND, chân ADC1 GPIO34).
- [x] Nạp code vào ESP32 thành công qua script `./scripts/flash_esp32.sh`, không phụ thuộc phần cứng rời.
- [x] Nhúng cảm biến vào nước -> số liệu biến thiên tương ứng trên cả Serial Monitor và App điện thoại.
- [x] Nhấn nút bật bơm trên App -> ESP32 phản hồi tức thì và tự ngắt bảo vệ khi độ ẩm vượt 85%.
- [x] Nắm vững bài thuyết minh học thuật bảo vệ đồ án trước giảng viên (Kịch bản 3 phút + 3 câu hỏi vấn đáp điểm cao).

<!-- slug: soil-water-sensor-simulation -->