#ifndef SECRETS_H
#define SECRETS_H

/**
 * MẪU CẤU HÌNH BÍ MẬT CỦA TRẠM ĐO
 * Sao chép file này thành secrets.h (cùng thư mục) rồi điền 3 chỗ: tên WiFi, mật khẩu WiFi, mật khẩu soil_station.
 * secrets.h đã nằm trong .gitignore nên mật khẩu không bị đưa lên git. Mật khẩu soil_station hỏi người quản lý broker.
 * Chưa có secrets.h thì firmware dùng broker công cộng broker.emqx.io (có mã hóa, chưa có tài khoản),
 * App và trang web đang nối broker riêng sẽ không thấy số đo của trạm.
 */

// WiFi nhà hoặc điểm phát 4G từ điện thoại (ESP32 chỉ bắt được WiFi 2.4 GHz)
#define WIFI_SSID      "iPhone"
#define WIFI_PASSWORD  "password"

// Broker riêng EMQX Serverless: chỉ mở cổng TLS 8883 (WebSocket TLS 8084), không cho đăng nhập ẩn danh.
// Tài khoản soil_station chỉ được gửi telemetry, status và nhận command (ACL trên EMQX)
#define MQTT_HOST      "y0601019.ala.asia-southeast1.emqxsl.com"
#define MQTT_PORT      8883
#define MQTT_USERNAME  "soil_station"
#define MQTT_PASSWORD  "doi-mat-khau-nay"

#endif // SECRETS_H
