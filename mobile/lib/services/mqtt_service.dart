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
  MqttServerClient? _client;
  AppMqttState _state = AppMqttState.disconnected;

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
    _updateState(AppMqttState.connecting);

    final clientId = '${MqttConstants.clientIdPrefix}${Random().nextInt(100000)}';
    _client = MqttServerClient(broker, clientId);
    _client!.port = port;
    _client!.keepAlivePeriod = 20;
    _client!.logging(on: false);
    _client!.autoReconnect = true;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean();
    _client!.connectionMessage = connMessage;


    try {
      debugPrint('[MQTT] Đang kết nối tới $broker:$port...');
      await _client!.connect();
    } catch (e) {
      debugPrint('[MQTT] Lỗi kết nối: $e');
      _updateState(AppMqttState.error);
      _client?.disconnect();
      return;
    }

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint('[MQTT] Đã kết nối thành công!');
      _updateState(AppMqttState.connected);

      // Subscribe telemetry topic
      _subscribe(MqttConstants.telemetryTopic);

      // Lắng nghe bản tin
      _client!.updates?.listen(_onMessageReceived);
    } else {
      debugPrint('[MQTT] Kết nối thất bại: ${_client?.connectionStatus?.returnCode}');
      _updateState(AppMqttState.error);
    }
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
        _telemetryController.add(telemetry);
      } catch (e) {
        debugPrint('[MQTT] Lỗi parse JSON telemetry: $e');
      }
    }
  }

  Future<void> publishCommand({
    required String action, // e.g. "SET_PUMP" hoặc "SET_VALVE"
    required bool state,
  }) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] Chưa kết nối, không thể gửi lệnh');
      return;
    }

    final payload = jsonEncode({
      'action': action,
      'state': state,
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
  }

  void disconnect() {
    _client?.disconnect();
    _updateState(AppMqttState.disconnected);
  }

  void _updateState(AppMqttState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _telemetryController.close();
    _stateController.close();
    _client?.disconnect();
  }
}
