import 'package:flutter/material.dart';
import '../models/soil_telemetry.dart';
import '../models/soil_type.dart';
import '../services/agronomic_engine.dart';
import '../services/history_repository.dart';
import '../services/mqtt_service.dart';

class SoilDataProvider extends ChangeNotifier {
  final MqttService _mqttService = MqttService();
  final HistoryRepository historyRepository;

  SoilTelemetry _currentTelemetry = SoilTelemetry.initial();
  final List<SoilTelemetry> _history = [];
  AppMqttState _connectionState = AppMqttState.disconnected;
  SoilType? _pendingSoilType; // Loại đất vừa chọn trên App, đang chờ trạm xác nhận

  SoilTelemetry get currentTelemetry => _currentTelemetry;
  List<SoilTelemetry> get history => _history;
  AppMqttState get connectionState => _connectionState;

  /// Loại đất hiển thị là đang chọn: ưu tiên lựa chọn chờ xác nhận, sau đó tới loại trạm báo về
  SoilType get selectedSoilType =>
      _pendingSoilType ?? _currentTelemetry.soilType ?? SoilType.garden;

  /// true khi trạm chưa gửi về số liệu đo theo loại đất vừa chọn
  bool get isSoilTypeSyncing => _pendingSoilType != null;

  AgronomicDiagnosis get currentDiagnosis => AgronomicEngine.evaluate(
        telemetry: _currentTelemetry,
      );

  SoilDataProvider({HistoryRepository? historyRepository})
      : historyRepository = historyRepository ?? HistoryRepository() {
    _history.add(_currentTelemetry);
    _initMqtt();
  }

  void _initMqtt() {
    _mqttService.stateStream.listen((state) {
      _connectionState = state;
      // Mất mạng lúc vừa chọn loại đất thì gửi lại khi kết nối xong
      if (state == AppMqttState.connected && _pendingSoilType != null) {
        _publishSoilType(_pendingSoilType!);
      }
      notifyListeners();
    });

    _mqttService.telemetryStream.listen((telemetry) {
      _currentTelemetry = telemetry;
      if (telemetry.soilType == _pendingSoilType) {
        _pendingSoilType = null;
      }
      _history.add(telemetry);
      if (_history.length > 30) {
        _history.removeAt(0);
      }
      // Chỉ lưu số đo thật từ trạm, không lưu dữ liệu nút Demo
      historyRepository.save(telemetry);
      notifyListeners();
    });

    // Tự động kết nối MQTT khi khởi tạo
    _mqttService.connect();
  }

  void selectSoilType(SoilType type) {
    if (type == selectedSoilType) return;
    _pendingSoilType = type;
    notifyListeners();
    _publishSoilType(type);
  }

  bool _publishSoilType(SoilType type) =>
      _mqttService.publishCommand({'action': 'SET_SOIL_TYPE', 'soil_type': type.code});

  /// Yêu cầu trạm lấy ADC hiện tại làm mốc khô / ướt. Trả về false nếu chưa kết nối MQTT.
  bool calibrate(CalibrationPoint point) =>
      _mqttService.publishCommand({'action': 'CALIBRATE', 'point': point.code});

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
      soilType: _currentTelemetry.soilType,
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
    historyRepository.close();
    super.dispose();
  }
}
