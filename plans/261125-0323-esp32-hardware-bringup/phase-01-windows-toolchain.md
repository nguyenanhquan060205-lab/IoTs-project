---
phase: 1
title: "Cài môi trường nạp code trên Windows"
status: completed
priority: P1
effort: "45m"
dependencies: []
---

# Phase 1: Cài môi trường nạp code trên Windows

## Goal

Máy Windows có lệnh `pio` và nhận ESP32 thành một cổng COM.

## Files to Create / Modify

- Không sửa file nào trong repo.

## Tasks & Steps

1. **Cài PlatformIO** (chọn 1 trong 2 cách):
   - Cách A, khuyên dùng: cài VS Code, vào Extensions, cài **PlatformIO IDE**, đợi cài xong rồi khởi động lại VS Code. Lệnh `pio` nằm ở `%USERPROFILE%\.platformio\penv\Scripts\pio.exe` và dùng được ngay trong terminal của PlatformIO (biểu tượng con kiến → *New Terminal*).
   - Cách B, chỉ dòng lệnh: `py -m pip install -U platformio`, sau đó dùng `py -m platformio` thay cho `pio`.
   - PlatformIO tự tạo môi trường Python riêng. Nếu bước cài báo lỗi liên quan tới Python 3.14 (máy đang có `C:\Python314`), cài thêm Python 3.12 rồi mở lại VS Code để PlatformIO cài lại.
2. **Chọn cáp USB truyền dữ liệu**. Nhiều cáp micro-USB/Type-C chỉ sạc được, cắm vào máy tính sẽ không hiện cổng COM.
3. **Cắm ESP32 (chưa đấu gì vào board) và xem Device Manager** → *Ports (COM & LPT)*:
   - Thấy `Silicon Labs CP210x USB to UART Bridge (COMx)` hoặc `USB-SERIAL CH340 (COMx)` là được. Ghi lại số `COMx`.
   - Chỉ thấy *Unknown device* hoặc mục có dấu chấm than: cài driver theo con chip USB in trên board (CP2102 → driver **CP210x VCP** của Silicon Labs; CH340/CH9102 → driver **CH341SER** của WCH), rút ra cắm lại.
   - Máy này đang có sẵn COM3-COM6 là cổng **Bluetooth**, không phải ESP32. Đừng chọn nhầm.
4. **(Tùy chọn) Cài extension Wokwi** nếu muốn chạy thử firmware trên mạch ảo trước (`firmware/diagram.json` và `firmware/wokwi.toml` đã có sẵn).

## Verification

- `pio --version` (hoặc `py -m platformio --version`) in ra số phiên bản.
- `pio device list` liệt kê cổng COM của ESP32 với mô tả CP210x/CH340.
