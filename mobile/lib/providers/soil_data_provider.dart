import 'package:flutter/material.dart';
import '../models/soil_telemetry.dart';
import '../services/agronomic_engine.dart';
import '../services/mqtt_service.dart';

class SoilDataProvider extends ChangeNotifier {
  final MqttService _mqttService = MqttService();

  SoilTelemetry _currentTelemetry = SoilTelemetry.initial();
  final List<SoilTelemetry> _history = [];
  AppMqttState _connectionState = AppMqttState.disconnected;

  SoilTelemetry get currentTelemetry => _currentTelemetry;
  List<SoilTelemetry> get history => _history;
  AppMqttState get connectionState => _connectionState;

  AgronomicDiagnosis get currentDiagnosis => AgronomicEngine.evaluate(
        telemetry: _currentTelemetry,
      );

  SoilDataProvider() {
    _history.add(_currentTelemetry);
    _initMqtt();
  }

  void _initMqtt() {
    _mqttService.stateStream.listen((state) {
      _connectionState = state;
      notifyListeners();
    });

    _mqttService.telemetryStream.listen((telemetry) {
      _currentTelemetry = telemetry;
      _history.add(telemetry);
      if (_history.length > 30) {
        _history.removeAt(0);
      }
      notifyListeners();
    });

    // Tự động kết nối MQTT khi khởi tạo
    _mqttService.connect();
  }

  Future<void> togglePump() async {
    final newState = !_currentTelemetry.pumpActive;
    _currentTelemetry = _currentTelemetry.copyWith(pumpActive: newState);
    notifyListeners();

    await _mqttService.publishCommand(action: 'SET_PUMP', state: newState);
  }

  Future<void> toggleValve() async {
    final newState = !_currentTelemetry.valveActive;
    _currentTelemetry = _currentTelemetry.copyWith(valveActive: newState);
    notifyListeners();

    await _mqttService.publishCommand(action: 'SET_VALVE', state: newState);
  }

  void reconnect() {
    _mqttService.connect();
  }

  // Dùng để test mô phỏng dữ liệu khi cần
  void simulateRandomReading() {
    _currentTelemetry = SoilTelemetry(
      nitrogen: (40 + (DateTime.now().second % 40)).toDouble(),
      phosphorus: (20 + (DateTime.now().second % 35)).toDouble(),
      potassium: (70 + (DateTime.now().second % 60)).toDouble(),
      ph: (5.2 + ((DateTime.now().second % 20) / 10)).toDouble(),
      ec: (400 + (DateTime.now().second * 15)).toDouble(),
      moisture: (45 + (DateTime.now().second % 30)).toDouble(),
      temperature: (25 + ((DateTime.now().second % 50) / 10)).toDouble(),
      timestamp: DateTime.now(),
      pumpActive: _currentTelemetry.pumpActive,
      valveActive: _currentTelemetry.valveActive,
    );
    _history.add(_currentTelemetry);
    if (_history.length > 30) {
      _history.removeAt(0);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _mqttService.dispose();
    super.dispose();
  }
}
