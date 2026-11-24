#ifndef SECRETS_H
#define SECRETS_H

/**
 * MẪU CẤU HÌNH BÍ MẬT CỦA TRẠM ĐO
 * Sao chép file này thành secrets.h (cùng thư mục) rồi điền thông tin thật.
 * secrets.h đã nằm trong .gitignore nên mật khẩu không bị đưa lên git.
 * Chưa có secrets.h thì firmware dùng broker công cộng broker.emqx.io qua TLS (có mã hóa, chưa có tài khoản).
 */

// WiFi nhà hoặc điểm phát 4G từ điện thoại
#define WIFI_SSID      "iPhone"
#define WIFI_PASSWORD  "password"

// Broker riêng có tài khoản, ví dụ HiveMQ Cloud (gói Free): Clusters -> Access Management -> tạo tài khoản cho trạm
#define MQTT_HOST      "xxxxxxxxxxxxxxxx.s1.eu.hivemq.cloud"
#define MQTT_PORT      8883
#define MQTT_USERNAME  "soil_station_01"
#define MQTT_PASSWORD  "doi-mat-khau-nay"

#endif // SECRETS_H
