---
phase: 2
title: "Thêm log đo thời gian trong firmware"
status: completed
priority: P2
effort: "30m"
dependencies: []
---

# Phase 2: Thêm log đo thời gian trong firmware

## Goal

Serial Monitor in ra đủ số để điền Bảng 4.2 và 4.3 bằng số đo thật: thời gian từ lúc có Wi-Fi tới lúc có giờ NTP, thời gian bắt tay TLS cộng CONNECT, và bộ nhớ trống sau khi kết nối.

## Bối cảnh từ code

- Báo cáo (Bảng 4.2) đo "từ dòng Wi-Fi connected đến dòng có giờ", nhưng firmware hiện không in dòng nào khi đồng bộ được giờ. `configTzTime("ICT-7", "pool.ntp.org", "time.google.com")` chạy nền (`firmware/src/main.cpp`, hàm `setup()`).
- `tryConnectMqtt()` in `Thanh cong!` nhưng không in thời gian kết nối hay bộ nhớ.
- Phase này không đổi bản tin MQTT hay hành vi đo.

## Files to Create / Modify

- Modify: `firmware/src/main.cpp`
- Modify: `firmware/README.md` (mục log Serial, nếu có liệt kê các dòng log)

## Tasks & Steps

1. Thêm biến `unsigned long wifiConnectedAt = 0;` và `bool ntpLogged = false;`. Gán `wifiConnectedAt = millis()` khi Wi-Fi vừa nối được, cả trong `setupWiFi()` lẫn lúc dò lại trong `loop()`.
2. Ghi mốc lúc SNTP đặt giờ lần đầu bằng `sntp_set_time_sync_notification_cb()` (gọi trước `configTzTime`). Callback chạy trong tác vụ SNTP nên không bị lệch khi `loop()` đang bận bắt tay TLS. Trong `loop()` chỉ in một lần
   `[NTP] Da co gio sau %lu ms ke tu khi co WiFi: %Y-%m-%d %H:%M:%S (ICT)` rồi đặt `ntpLogged = true`.
   (Đã đổi khi thực hiện: bản đầu so `time(nullptr)` trong `loop()` sẽ cộng thêm thời gian `loop()` bị chặn.)
3. Trong `tryConnectMqtt()`: ghi `millis()` ngay trước `mqttClient.connect(...)`. Thành công thì in `Thanh cong! (%lu ms, heap trong %u byte)` với `ESP.getFreeHeap()`. Thất bại thì in thêm số ms vào dòng `That bai, rc=...`.
4. Không đổi gì khác. Chuỗi log để không dấu như các dòng hiện có.

## Todo

- [x] Ghi `wifiConnectedAt` mỗi khi Wi-Fi vừa nối được
- [x] In dòng `[NTP] Da co gio sau ... ms` một lần mỗi lần khởi động
- [x] In thời gian kết nối MQTT và `ESP.getFreeHeap()` khi thành công, thời gian khi thất bại
- [x] Build không cảnh báo (`PLATFORMIO_BUILD_FLAGS="-Wall -Wextra" pio run`, 2026-11-26: SUCCESS, Flash 84.8%)
- [x] Nạp vào board và xem Serial (2026-11-26, COM7: in `[NTP] Da co gio sau 15349 ms ke tu khi co WiFi` và `Thanh cong! (1533 ms, heap trong 167056 byte)`; lần nạp thứ hai in 15412 ms, 2503 ms, 167076 byte)

## Verification

- Build bằng `scripts\flash_esp32.ps1` (hoặc `pio run` trong `firmware/`) không có cảnh báo với `-Wall -Wextra`.
- Kiểm thử native của `soil_estimator.h` vẫn qua (cách chạy như phase 3 của kế hoạch `261125-0323-esp32-hardware-bringup`).
- Nạp vào board: Serial in dòng `[NTP] Da co gio sau ... ms` đúng một lần sau mỗi lần khởi động, và dòng `Thanh cong! (... ms, heap trong ... byte)`.
- Trên Wokwi (cổng 1883, không TLS) cũng in đủ hai dòng. Chênh thời gian kết nối và bộ nhớ giữa có TLS và không TLS dùng cho dòng "Chi phí của TLS" ở Bảng 4.3.
