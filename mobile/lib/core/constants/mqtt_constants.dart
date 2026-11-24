class MqttConstants {
  // Broker và tài khoản đọc từ --dart-define-from-file=mqtt_config.json (xem mqtt_config.example.json).
  // Không truyền file cấu hình thì dùng broker công cộng qua TLS: đã mã hóa nhưng chưa có tài khoản.
  static const String defaultBroker =
      String.fromEnvironment('MQTT_HOST', defaultValue: 'broker.emqx.io');
  static const int defaultPort = int.fromEnvironment('MQTT_PORT', defaultValue: 8883);
  static const bool useTls = bool.fromEnvironment('MQTT_TLS', defaultValue: true);
  static const String username = String.fromEnvironment('MQTT_USERNAME');
  static const String password = String.fromEnvironment('MQTT_PASSWORD');
  static const String clientIdPrefix = 'flutter_soil_client_';

  // Topic cấu trúc chuẩn
  static const String telemetryTopic = 'soil_station/1/telemetry';
  static const String commandTopic = 'soil_station/1/command';
  static const String statusTopic = 'soil_station/1/status';
}
