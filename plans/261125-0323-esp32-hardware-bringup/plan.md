---
title: "Đưa trạm ESP32 thật vào hoạt động trên Windows: cài môi trường, nạp firmware, đấu cảm biến, nối App"
description: "Hướng dẫn từng bước nạp firmware PlatformIO vào ESP32 từ máy Windows, đấu cảm biến độ ẩm vào GPIO34, rồi nối trạm với App Flutter qua MQTT và hiệu chuẩn."
status: in-progress
priority: P1
effort: "2h10m"
branch: main
tags: [iot, esp32, platformio, firmware, mqtt, flutter, hardware, windows]
blockedBy: []
blocks: []
created: 2026-11-25
---

# Đưa trạm ESP32 thật vào hoạt động trên Windows

## Overview

Hướng dẫn từng bước nạp firmware PlatformIO vào ESP32 từ máy Windows, đấu cảm biến độ ẩm vào GPIO34, rồi nối trạm với App Flutter qua MQTT và hiệu chuẩn.

Lưu ý: code được nạp vào **ESP32**, không nạp vào cảm biến. Cảm biến độ ẩm chỉ là module analog: nó xuất ra một điện áp 0 - 3.3V, ESP32 đọc điện áp đó qua ADC rồi tự tính mọi chỉ số.

## Tóm tắt hệ thống (đọc từ code)

```
 Cảm biến độ ẩm ──AO──> GPIO34 (ADC1)
                          │
                    ┌─────▼──────────────────────────────┐
                    │ ESP32 (firmware/src/main.cpp)      │
                    │ 21 mẫu ADC → lọc trimmed mean      │
                    │ → % ẩm (2 mốc khô/ướt, lưu NVS)    │
                    │ → ước lượng EC, N, P, K, pH        │
                    │   theo loại đất (soil_estimator.h) │
                    │ → LED đỏ/vàng/xanh, OLED, relay    │
                    └─────┬──────────────────────▲───────┘
         publish 4 giây/lần│ telemetry           │ command
                           ▼                     │
                MQTT broker (mặc định broker.emqx.io:8883, TLS)
                           │                     ▲
                           ▼                     │ SET_SOIL_TYPE, CALIBRATE, SET_PUMP, SET_VALVE
                    ┌──────────────────────────────────────┐
                    │ App Flutter (mobile/)                │
                    │ Tổng quan · Chỉ số · Mẫu đất ·       │
                    │ Lịch sử (SQLite) · Hiệu chuẩn        │
                    │ AgronomicEngine: điểm sức khỏe đất   │
                    └──────────────────────────────────────┘
```

- **Topic**: `soil_station/1/telemetry` (trạm → App), `soil_station/1/command` (App → trạm), `soil_station/1/status` (trạm báo online khi kết nối).
- **Lệnh firmware nhận**: `SET_SOIL_TYPE` (`potting`/`garden`/`barren`), `CALIBRATE` (`dry`/`wet`), `SET_PUMP`, `SET_VALVE`. App gửi cả 4 lệnh (công tắc bơm/van ở tab Tổng quan).
- **Chỉ đo thật độ ẩm**. EC, N, P, K, pH là số ước lượng từ độ ẩm và loại đất chọn trên App.
- **Kết nối mạng**: WiFiMulti thử `Wokwi-GUEST` (chỉ có trong mô phỏng) và WiFi trong `secrets.h`. Mạng thật luôn dùng TLS cổng 8883 và xác thực broker bằng Root CA trong `root_ca.h`.

## Goals

| # | Goal | Priority |
|---|------|----------|
| 1 | Máy Windows build được firmware và thấy ESP32 thành một cổng COM | P1 |
| 2 | Nạp firmware thành công, Serial Monitor in log `[SENSOR]` 4 giây/lần | P1 |
| 3 | Cảm biến đấu đúng (3V3, GND, GPIO34), ADC thay đổi khi nhúng nước | P1 |
| 4 | App nhận số đo thật, hiệu chuẩn 2 mốc và đổi loại đất được | P1 |

## Phases

| # | Phase | Status |
|---|-------|--------|
| 1 | [Phase 1: Cài môi trường nạp code trên Windows](./phase-01-windows-toolchain.md) | Completed: PlatformIO 6.2.0, driver CP210x, ESP32 ở COM7 |
| 2 | [Phase 2: Cấu hình WiFi và broker (secrets.h)](./phase-02-secrets-config.md) | Completed: đã điền WiFi, broker `broker.emqx.io:8883` |
| 3 | [Phase 3: Build và nạp firmware vào ESP32](./phase-03-build-flash.md) | Completed: nạp qua COM7, trạm vào WiFi, MQTT TLS `Thanh cong!`, gửi telemetry mỗi 4 giây |
| 4 | [Phase 4: Đấu nối cảm biến và ngoại vi](./phase-04-wiring.md) | In progress: đã đấu cảm biến, ADC đổi theo đầu dò, MQTT nhận đúng số của trạm. Còn đo khô/ướt chênh > 300 |
| 5 | [Phase 5: Nối App, hiệu chuẩn và đo thử](./phase-05-app-calibration.md) | Pending |

Thứ tự cố ý: nạp code khi **chưa cắm gì** vào ESP32 (phase 3) để tách lỗi USB/driver khỏi lỗi đấu dây, sau đó mới rút USB và đấu cảm biến (phase 4).

## Hiện trạng máy này (kiểm tra ngày 2026-11-25)

| Thành phần | Tình trạng |
|---|---|
| PlatformIO (`pio`) | **Đã có**: extension PlatformIO IDE trong VS Code đã cài Core 6.2.0 vào `%USERPROFILE%\.platformio\penv`. `scripts\flash_esp32.ps1` tự tìm thấy và build được. Toolchain ESP32 (khoảng 4 GB) đã tải sẵn |
| Driver USB-UART | Chưa có driver CP210x / CH340 riêng trong máy. Windows thường tự cài khi cắm board lần đầu (cần Internet) |
| Python | Có, `C:\Python314\python.exe` |
| Flutter | Có, 3.38.6 (Dart 3.10.7): **quá cũ**, App cần Dart ≥ 3.13.2. Chạy `flutter upgrade` trước phase 5 |
| ESP32 qua USB | **Đã nhận**: board dùng chip CP2102, đã cài driver CP210x, ESP32 ở **COM7** (`Silicon Labs CP210x USB to UART Bridge`) |
| `firmware/src/secrets.h` | **Đã điền WiFi**, đã xóa `#error`. Broker `broker.emqx.io:8883` (cách A) |

## Rủi ro

| Rủi ro | Mức | Cách tránh |
|---|:---:|---|
| Cấp 5V cho cảm biến làm tín hiệu AO vượt 3.3V, hỏng ADC | Cao | VCC cảm biến chỉ nối 3V3 |
| Cắm cảm biến vào chân ADC2 (GPIO 2, 4, 12-15, 25-27), ADC không đọc được khi WiFi bật | Trung bình | Chỉ dùng GPIO34 như firmware |
| Cáp USB chỉ sạc, không truyền dữ liệu, máy không thấy cổng COM | Trung bình | Thử cáp khác, xem Device Manager |
| WiFi 5 GHz, ESP32 không thấy mạng | Trung bình | Dùng mạng 2.4 GHz; hotspot iPhone bật "Tối đa hóa tương thích" |
| Broker công cộng: ai biết topic cũng đọc được và gửi lệnh được | Thấp (demo) | Dùng HiveMQ Cloud có tài khoản (phase 2, tùy chọn) |

## Đã sửa ngày 2026-11-25

Firmware (build thử thành công với platform 8.0.0 / Arduino-ESP32 3.3.12, `-Wall -Wextra` không có cảnh báo):
- `platformio.ini` ghim platform và thư viện. Trước đó platform không ghim nên tự nhảy lên Arduino-ESP32 3.x, và SSD1306 kéo thêm GFX 2.0.0 nằm song song với GFX 1.13.0.
- Hiệu chuẩn: chỉ so khoảng cách 300 với mốc đã đo thật. Trước đó đầu dò điện dung (ADC khô khoảng 2800) bị từ chối ngay bước 1 vì quá gần mốc ướt mặc định 3000.
- Còi GPIO25 kêu 3 tiếng (phát bằng PWM) khi đất vừa chuyển sang quá khô hoặc ngập úng, có trễ 3% để không kêu liên tục.
- WiFi: khởi động chỉ chặn tối đa khoảng 25 giây thay vì vài phút khi sai mật khẩu; mất WiFi thì 15 giây dò lại 1 lần, giữa các lần vẫn đo và báo đèn.
- Rơ-le chốt mức tắt trước khi bật chân OUTPUT (không đóng thoáng qua lúc khởi động). Lệnh `SET_PUMP`/`SET_VALVE` gửi ngay bản tin xác nhận.
- Topic `status` có LWT `offline` và bản tin `online` được giữ lại trên broker, đúng như SPECIFICATION mô tả.
- Có `#warning` lúc build và cảnh báo trên Serial khi chưa có `secrets.h`.

App (34 test, cộng 1 test kết nối lại MQTT, đều qua; chạy trên bản sao với Flutter 3.38 sau khi hạ tạm ràng buộc SDK):
- Thẻ **Điều khiển trạm** ở tab Tổng quan có công tắc máy bơm và van; chờ trạm xác nhận rồi mới hiện trạng thái thật.
- MQTT tự thử lại mỗi 5 giây khi lần kết nối đầu thất bại (trước đó mở App lúc chưa có mạng thì không bao giờ kết nối), và cập nhật trạng thái khi tự nối lại.
- `AndroidManifest.xml` chính đã có quyền `INTERNET`, APK release kết nối được MQTT.

Script và tài liệu:
- Thêm `scripts/flash_esp32.ps1` cho Windows. `scripts/flash_esp32.sh` chạy được trên macOS, Linux và Git Bash. Cả hai tự tìm cổng ESP32 theo chip USB, bỏ qua cổng Bluetooth.
- `.gitattributes` giữ `*.sh` ở dạng LF. `simulate_station.py` không còn lỗi in emoji khi xuất ra pipe trên Windows, và dùng cùng quy tắc hiệu chuẩn với firmware.
- Viết lại `firmware/README.md`. Cập nhật `HARDWARE_CHECKLIST.md` (LED vàng GPIO19, rơ-le kích mức thấp, cách nạp code) và `SPECIFICATION.md`.
- Đã kiểm tra Root CA: `broker.emqx.io:8883` xác thực được bằng DigiCert Global Root G2 trong `root_ca.h`.

Đã chạy trên mạch thật (2026-11-25): nạp code qua COM7 (chip CP2102), Flash dùng 84.8%, trạm vào WiFi và kết nối MQTT TLS thành công. Chưa kiểm tra: còi, rơ-le.

Lỗi tìm thấy khi chạy thật (chưa sửa): `main.cpp` dùng client ID ngẫu nhiên (`ESP32_Soil_` + số ngẫu nhiên). Trạm khởi động lại mà không ngắt kết nối thì phiên cũ vẫn treo trên broker khoảng 20 giây rồi broker đăng LWT `offline` (giữ lại), đè lên `online` của phiên mới. Topic `status` báo `offline` trong khi trạm vẫn gửi số đo. App không đọc topic `status` nên App không bị ảnh hưởng, chỉ người xem bằng MQTT client thấy sai. Cách sửa: client ID cố định theo MAC, và gửi lại `online` sau khi kết nối vài giây.

## Đổi cách tính N, P, K (2026-11-25, theo yêu cầu người dùng)

- N, P, K không còn cố định theo loại đất. Firmware tính từ EC: `N = 0.08 × EC`, `P = 0.04 × EC`, `K = 0.11 × EC`, mà EC = độ ẩm × hệ số loại đất, nên N, P, K đổi theo độ ẩm đo được. Ở độ ẩm 60%, mỗi loại đất cho đúng mức bình thường của nó.
- Mức cũ của từng loại đất (đóng bao 95/50/135, đất vườn 65/33/90, bạc màu 20/10/30) giờ là **mức bình thường** để so sánh: lệch quá 20% thì báo thấp / cao. OLED thêm dòng `Chuan:65/33/90 OK|THAP|CAO`, MQTT thêm `npk_normal` và `npk_level`, đèn vàng sáng khi N/P/K thấp hơn mức bình thường.
- Kèm sửa topic `status`: gửi lại `online` 30 giây 1 lần để LWT `offline` của phiên cũ không đè mãi.
- Đã kiểm tra: build firmware không cảnh báo (`-Wall -Wextra`), test C++ của firmware qua (biên dịch bằng MSVC), 11 test của `simulate_station.py` qua. Đã nạp vào board lúc 19:28 và kiểm tra trên MQTT: bản tin có `npk_normal`, `npk_level` (khoảng 420 byte), N, P, K đổi theo độ ẩm, topic `status` giữ `online` và gửi lại 30 giây 1 lần. App chưa hiện mức bình thường của loại đất.

## Success Criteria

- [ ] `pio --version` chạy được và Device Manager có cổng `Silicon Labs CP210x` hoặc `USB-SERIAL CH340`
- [ ] `pio run -t upload` báo `SUCCESS`
- [ ] Serial Monitor in `WiFi da ket noi`, `Dang ket noi MQTT ... (TLS)... Thanh cong!` và dòng `[SENSOR]` mỗi 4 giây
- [ ] Nhúng đầu dò vào nước làm `ADC` và `Am` đổi rõ rệt
- [ ] App hiện số đo mới, lưu được mốc khô/ướt, đổi loại đất và trạm xác nhận

<!-- slug: esp32-hardware-bringup -->
