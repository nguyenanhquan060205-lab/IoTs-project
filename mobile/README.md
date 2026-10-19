# Mobile App (Flutter)

Ứng dụng di động giám sát dinh dưỡng đất và điều khiển trạm IoT:
- **Framework**: Flutter (Dart) - Hỗ trợ cả Android và iOS
- **Thư viện chính**:
  - `mqtt_client`: Kết nối hai chiều với MQTT Broker thời gian thực (nhận telemetry, gửi lệnh bật/tắt Relay).
  - `fl_chart`: Vẽ biểu đồ Radar phân bố N-P-K và biểu đồ lịch sử đường theo thời gian.
  - `syncfusion_flutter_gauges` hoặc `percent_indicator`: Hiển thị đồng hồ đo độ ẩm, pH, EC trực quan.
  - `provider` / `bloc`: Quản lý trạng thái ứng dụng.
- **Tính năng nổi bật**:
  - Giám sát thời gian thực 7 chỉ số đất (N, P, K, pH, EC, Ẩm, Nhiệt).
  - Hệ chuyên gia nông học tích hợp: Đưa ra cảnh báo (đất chua, mặn, nghèo chất) và khuyến nghị phân bón theo cây trồng được chọn.
  - Điều khiển thiết bị: Nút gạt bật/tắt bơm nước và van dinh dưỡng tức thì.
  - Cảnh báo âm thanh / rung khi đất chạm ngưỡng nguy hiểm.
