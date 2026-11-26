# Mobile App (Flutter)

Ứng dụng di động giám sát dinh dưỡng đất và điều khiển trạm IoT:
- **Framework**: Flutter (Dart) - Hỗ trợ cả Android và iOS
- **Thư viện chính**:
  - `mqtt_client`: Kết nối hai chiều với MQTT Broker thời gian thực (nhận telemetry, gửi lệnh chọn loại đất và hiệu chuẩn).
  - `fl_chart`: Vẽ biểu đồ Radar phân bố N-P-K và biểu đồ lịch sử đường theo thời gian.
  - `syncfusion_flutter_gauges` hoặc `percent_indicator`: Hiển thị đồng hồ đo độ ẩm, pH, EC trực quan.
  - `provider` / `bloc`: Quản lý trạng thái ứng dụng.
- **Tính năng nổi bật**:
  - Giám sát thời gian thực 7 chỉ số đất (N, P, K, pH, EC, Ẩm, Nhiệt).
  - Hệ chuyên gia nông học tích hợp: Đưa ra cảnh báo (đất chua, mặn, nghèo chất) và khuyến nghị phân bón theo cây trồng được chọn.
  - Cảnh báo âm thanh / rung khi đất chạm ngưỡng nguy hiểm.

## Chạy với broker riêng

Chép `mqtt_config.example.json` thành `mqtt_config.json` (file này nằm trong `.gitignore`), điền mật khẩu tài khoản `soil_app`, rồi chạy:

```
flutter run --dart-define-from-file=mqtt_config.json
flutter build apk --release --dart-define-from-file=mqtt_config.json
```

Tài khoản `soil_app` chỉ được nhận telemetry, status và gửi lệnh. Chạy không kèm file cấu hình thì App nối broker công cộng `broker.emqx.io` và không thấy số đo của trạm đang nối broker riêng.
