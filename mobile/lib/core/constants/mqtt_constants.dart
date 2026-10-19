class MqttConstants {
  // Mặc định dùng Broker công cộng kiểm thử nhanh (không cần tạo acc)
  // Khi chạy chính thức có thể thay bằng HiveMQ Cloud / EMQX Serverless
  static const String defaultBroker = 'broker.emqx.io';
  static const int defaultPort = 1883;
  static const String clientIdPrefix = 'flutter_soil_client_';

  // Topic cấu trúc chuẩn
  static const String telemetryTopic = 'soil_station/1/telemetry';
  static const String commandTopic = 'soil_station/1/command';
  static const String statusTopic = 'soil_station/1/status';
}
