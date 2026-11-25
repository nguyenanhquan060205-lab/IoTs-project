---
phase: 5
title: "Nối App, hiệu chuẩn và đo thử"
status: pending
priority: P1
effort: "40m"
dependencies: [2, 4]
---

# Phase 5: Nối App, hiệu chuẩn và đo thử

## Goal

App trên điện thoại nhận số đo thật từ trạm, hiệu chuẩn 2 mốc, đổi loại đất và bật/tắt rơ-le được.

## Files to Create / Modify

- Create (chỉ với cách B ở phase 2): `mobile/mqtt_config.json`

## Tasks & Steps

1. **Nâng cấp Flutter**: project cần Dart ≥ 3.13.2, máy này đang có Flutter 3.38.6 (Dart 3.10.7) nên `flutter pub get` sẽ báo lỗi `version solving failed`.
   ```powershell
   flutter upgrade
   flutter --version    # Dart phải từ 3.13.2 trở lên
   ```
2. **Chạy App lên điện thoại Android** (bật *Tùy chọn nhà phát triển* → *Gỡ lỗi USB*, cắm điện thoại vào máy):
   ```powershell
   cd mobile
   flutter pub get
   flutter run                                            # cách A: broker.emqx.io
   flutter run --dart-define-from-file=mqtt_config.json   # cách B: HiveMQ có tài khoản
   ```
   Điện thoại chỉ cần có Internet, không cần chung WiFi với ESP32, vì cả hai cùng nối tới broker trên mạng. Điện thoại vừa phát hotspot cho ESP32 vừa chạy App vẫn được. Mở App lúc chưa có mạng cũng không sao: App tự thử kết nối lại mỗi 5 giây.
3. **Xem số đo**: tab *Tổng quan* hiện "Trực tuyến" và cập nhật mỗi 4 giây. Nhúng đầu dò vào nước thì độ ẩm trên App tăng.
4. **Hiệu chuẩn** (tab *Hiệu chuẩn*):
   - Bước 1: rút đầu dò khỏi đất, lau khô, chờ số đứng yên, bấm **Lưu mốc khô**. Serial in `=> DA LUU MOC KHO: ADC ...`.
   - Bước 2: nhúng đầu dò vào cốc nước tới vạch giới hạn, chờ số đứng yên, bấm **Lưu mốc ướt**. Serial in `=> DA LUU MOC UOT: ADC ...`.
   - Mốc được lưu vào flash (NVS) của ESP32, rút điện vẫn còn. Serial in `Bo qua: ... qua gan moc ... da luu` nghĩa là đầu dò chưa được lau khô hoặc chưa nhúng nước, làm lại bước đó.
5. **Chọn loại đất** (tab *Mẫu đất*): chọn Đóng bao / Đất vườn / Bạc màu. Serial in `=> LOAI DAT DANG DO: ...`, App hiện "Trạm đã nhận".
6. **Thử rơ-le** (tab *Tổng quan* → *Điều khiển trạm*): gạt công tắc **Máy bơm tưới**. App hiện "Đang gửi lệnh tới trạm..." rồi "Đang chạy", relay kêu "tách", Serial in `RO-LE BOM NUOC: DA BAT (ON)`. Nếu độ ẩm trên 85% (ví dụ đầu dò đang nhúng nước), trạm tự ngắt bơm ngay và công tắc trên App tự về tắt.
7. **Đo mẫu đất**: cắm đầu dò ngập vào mẫu đất, chờ khoảng 1 phút, đo ít nhất 3 vị trí. Xem lại ở tab *Lịch sử*. App lưu 1 bản ghi/phút, chỉ khi App đang mở.

## Verification

- App hiện "Trực tuyến", số đo mới mỗi 4 giây, giờ đo đúng giờ thực (trạm đồng bộ NTP).
- Sau hiệu chuẩn: khô ngoài không khí cho độ ẩm gần 0%, nhúng nước cho gần 100%.
- Đổi loại đất trên App thì N, P, K trên App và OLED đổi theo (Đóng bao > Đất vườn > Bạc màu).
- Công tắc bơm/van trên App bật/tắt được rơ-le, và trạng thái trên App khớp dòng `Bom: ON/OFF` trên Serial.
