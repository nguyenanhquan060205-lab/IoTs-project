---
title: Plan nạp firmware ESP32 trên Windows
date: 2026-11-25
summary: "Đọc firmware + App, lập plan 5 phase đưa trạm ESP32 thật vào hoạt động từ máy Windows"
---

# Plan nạp firmware ESP32 trên Windows

## What happened
- Đọc firmware: ADC GPIO34 → lọc trimmed mean 21 mẫu → % ẩm theo 2 mốc khô/ướt lưu NVS → ước lượng EC/N/P/K/pH theo loại đất → MQTT TLS 8883 (mặc định broker.emqx.io), topic `soil_station/1/{telemetry,command,status}`.
- Đọc App Flutter: 5 tab, chỉ gửi `SET_SOIL_TYPE` và `CALIBRATE`.
- Kiểm tra máy Windows: chưa cài PlatformIO, chưa cắm ESP32 (chỉ có COM3-COM6 Bluetooth). Đã có Python 3.14 và Flutter 3.38.6.

## Decision
- Lập `plans/261125-0323-esp32-hardware-bringup`: toolchain Windows → secrets.h → build/flash khi board chưa đấu gì → đấu cảm biến → nối App + hiệu chuẩn.
- Trên Windows dùng `pio` trực tiếp, không dùng `scripts/flash_esp32.sh`.

## Findings (chưa sửa)
- `scripts/flash_esp32.sh` chỉ tìm cổng macOS `/dev/cu.*`.
- `firmware/README.md` còn ghi Modbus RS485.
- Buzzer GPIO25 chỉ `pinMode`, chưa bao giờ được bật.
- App chưa có nút `SET_PUMP`/`SET_VALVE`.
- `mobile/android/app/src/main/AndroidManifest.xml` thiếu quyền INTERNET, APK release sẽ không kết nối MQTT được.

## Next steps
- Người dùng làm theo phase 1-5. Sửa các điểm trên nếu cần.

> Historical work record — not durable authority. Prefer docs/specs/ADRs for current decisions.

## Cập nhật (kiểm tra lại cùng ngày)
- Người dùng hỏi lại cách nạp code. Dùng lại plan cũ, không lập plan mới.
- Máy vẫn chưa cắm ESP32 (chỉ có COM3-COM6 Bluetooth). PlatformIO Core 6.2.0 chạy được.
- `secrets.h` vẫn còn `#error` và SSID mẫu, nên `firmware/.pio/build/esp32dev/` chưa có `firmware.bin`. Đã sửa dòng phase 3 trong `plan.md` cho đúng.
