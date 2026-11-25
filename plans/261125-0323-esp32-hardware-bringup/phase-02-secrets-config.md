---
phase: 2
title: "Cấu hình WiFi và broker (secrets.h)"
status: completed
priority: P1
effort: "15m"
dependencies: []
---

# Phase 2: Cấu hình WiFi và broker (secrets.h)

## Goal

Firmware biết WiFi nào để vào mạng và broker MQTT nào để gửi số đo, trùng broker với App.

## Files to Create / Modify

- Create: `firmware/src/secrets.h` (đã có trong `.gitignore`, mật khẩu không lên git)

## Tasks & Steps

1. `firmware/src/secrets.h` **đã được tạo sẵn** (2026-11-25) với broker cách A. Mở file, điền `WIFI_SSID` và `WIFI_PASSWORD`, rồi xóa dòng `#error`. Chưa xóa thì build dừng ở dòng đó để không nạp nhầm WiFi mẫu vào mạch.
2. Điền WiFi. ESP32 **chỉ bắt được WiFi 2.4 GHz**:
   - WiFi nhà: dùng tên mạng 2.4 GHz.
   - Hotspot iPhone: bật *Tối đa hóa tương thích* (Maximize Compatibility). Hotspot Android: chọn băng tần 2.4 GHz.
3. Chọn broker. `main.cpp` lấy **cả 6 macro** từ `secrets.h` khi file này tồn tại, nên phải điền đủ:
   - **Cách A, nhanh (broker công cộng, khớp App mặc định)**:
     ```c
     #define WIFI_SSID      "TenWiFi24GHz"
     #define WIFI_PASSWORD  "matkhauwifi"
     #define MQTT_HOST      "broker.emqx.io"
     #define MQTT_PORT      8883
     #define MQTT_USERNAME  ""
     #define MQTT_PASSWORD  ""
     ```
     App không cần cấu hình gì thêm. Nhược điểm: ai biết topic `soil_station/1/...` cũng đọc được dữ liệu và gửi lệnh được. Nhóm khác chạy cùng code trên broker này thì số liệu sẽ lẫn vào nhau.
   - **Cách B, có tài khoản (HiveMQ Cloud Free)**: tạo cluster, vào *Access Management* tạo 2 tài khoản (một cho trạm, một cho App). Điền host `xxxx.s1.eu.hivemq.cloud`, cổng 8883 và tài khoản trạm vào `secrets.h`. Chép `mobile/mqtt_config.example.json` thành `mobile/mqtt_config.json` và điền tài khoản App. Root CA của HiveMQ (ISRG Root X1) đã có trong `root_ca.h`.
4. Không đổi tên topic ở một phía: firmware (`main.cpp`) và App (`mqtt_constants.dart`) đang dùng cùng 3 topic.

## Verification

- `firmware/src/secrets.h` tồn tại, có đủ 6 `#define`.
- `git status` không hiện `secrets.h` (đã bị bỏ qua).
