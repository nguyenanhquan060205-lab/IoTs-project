import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../core/constants/mqtt_constants.dart';
import '../models/soil_telemetry.dart';

enum AppMqttState { disconnected, connecting, connected, error }

class MqttService {
  /// Kết nối lần đầu thất bại (chưa có mạng, broker lỗi) thì chờ bao lâu rồi thử lại
  final Duration retryDelay;

  MqttService({this.retryDelay = const Duration(seconds: 5)});

  MqttServerClient? _client;
  AppMqttState _state = AppMqttState.disconnected;
  Timer? _retryTimer;
  bool _disposed = false;

  final StreamController<SoilTelemetry> _telemetryController =
      StreamController<SoilTelemetry>.broadcast();
  final StreamController<AppMqttState> _stateController =
      StreamController<AppMqttState>.broadcast();

  Stream<SoilTelemetry> get telemetryStream => _telemetryController.stream;
  Stream<AppMqttState> get stateStream => _stateController.stream;
  AppMqttState get state => _state;

  Future<void> connect({
    String broker = MqttConstants.defaultBroker,
    int port = MqttConstants.defaultPort,
  }) async {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_disposed) return;

    // Bỏ kết nối cũ (nếu có) để không có 2 client cùng nhận một bản tin
    final previous = _client;
    _client = null;
    previous?.disconnect();

    _updateState(AppMqttState.connecting);

    final clientId = '${MqttConstants.clientIdPrefix}${Random().nextInt(100000)}';
    final client = MqttServerClient(broker, clientId);
    _client = client;
    client.port = port;
    client.keepAlivePeriod = 20;
    client.logging(on: false);
    // Rớt mạng sau khi đã kết nối thì thư viện tự nối lại và đăng ký lại topic
    client.autoReconnect = true;
    client.onAutoReconnect = () {
      if (identical(_client, client)) _updateState(AppMqttState.connecting);
    };
    client.onAutoReconnected = () {
      if (identical(_client, client)) _updateState(AppMqttState.connected);
    };
    // TLS: mã hóa đường truyền và xác thực chứng chỉ broker bằng kho CA của hệ điều hành
    client.secure = MqttConstants.useTls;

    var connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();
    if (MqttConstants.username.isNotEmpty) {
      connMessage = connMessage.authenticateAs(MqttConstants.username, MqttConstants.password);
    }
    client.connectionMessage = connMessage;

    try {
      debugPrint('[MQTT] Đang kết nối tới $broker:$port${MqttConstants.useTls ? ' (TLS)' : ''}...');
      await client.connect();
    } catch (e) {
      debugPrint('[MQTT] Lỗi kết nối: $e');
      _failAndRetry(client, broker, port);
      return;
    }

    // Trong lúc chờ đã có lệnh connect() / dispose() khác thay client này
    if (!identical(_client, client)) return;

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint('[MQTT] Đã kết nối thành công!');
      _updateState(AppMqttState.connected);

      // Subscribe telemetry topic
      _subscribe(MqttConstants.telemetryTopic);

      // Lắng nghe bản tin
      client.updates?.listen(_onMessageReceived);
    } else {
      debugPrint('[MQTT] Kết nối thất bại: ${client.connectionStatus?.returnCode}');
      _failAndRetry(client, broker, port);
    }
  }

  // Lần kết nối đầu chưa thành công thì thư viện không tự nối lại, nên tự hẹn giờ thử lại
  void _failAndRetry(MqttServerClient client, String broker, int port) {
    if (!identical(_client, client)) return;
    client.disconnect();
    _updateState(AppMqttState.error);
    if (_disposed) return;
    debugPrint('[MQTT] Thử kết nối lại sau ${retryDelay.inSeconds} giây');
    _retryTimer = Timer(retryDelay, () => connect(broker: broker, port: port));
  }

  void _subscribe(String topic) {
    debugPrint('[MQTT] Đang lắng nghe topic: $topic');
    _client?.subscribe(topic, MqttQos.atLeastOnce);
  }

  void _onMessageReceived(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final raw in messages) {
      final recMess = raw.payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      debugPrint('[MQTT] Nhận từ topic ${raw.topic}: $payload');

      try {
        final Map<String, dynamic> data = jsonDecode(payload);
        final telemetry = SoilTelemetry.fromJson(data);
        if (!_telemetryController.isClosed) _telemetryController.add(telemetry);
      } catch (e) {
        debugPrint('[MQTT] Lỗi parse JSON telemetry: $e');
      }
    }
  }

  /// Gửi lệnh xuống trạm ESP32, ví dụ {'action': 'SET_SOIL_TYPE', 'soil_type': 'garden'}.
  /// Trả về false nếu chưa kết nối MQTT.
  bool publishCommand(Map<String, dynamic> command) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] Chưa kết nối, chưa gửi được lệnh ${command['action']}');
      return false;
    }

    final payload = jsonEncode({
      ...command,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);

    _client?.publishMessage(
      MqttConstants.commandTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    debugPrint('[MQTT] Đã gửi lệnh tới ${MqttConstants.commandTopic}: $payload');
    return true;
  }

  void disconnect() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final client = _client;
    _client = null;
    client?.disconnect();
    _updateState(AppMqttState.disconnected);
  }

  void _updateState(AppMqttState newState) {
    _state = newState;
    if (!_stateController.isClosed) _stateController.add(newState);
  }

  void dispose() {
    _disposed = true;
    // Đóng stream trước để lúc ngắt kết nối không báo trạng thái tới provider đã bị hủy
    _telemetryController.close();
    _stateController.close();
    disconnect();
  }
}
